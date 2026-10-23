## League-like screens on the fast-XP server: every candidate plays the
## same seeded seatings (five seats: ours plus four of the live rivals,
## drawn and shuffled per batch) against the real submitted policies.
##
##   fastfield TAG SEED BATCHES A.bas [B.bas ...]
##
## One batch is one ten-episode request per candidate. ZIPs, replays and an
## index.tsv per candidate land under `eps/fast/TAG/` so the replay
## extractors (suffered, rivalstats, fit) can read them. Set AWM_OPPONENTS
## to a comma list of policy refs (default: the current league rivals) and
## AWM_FAST_BASE to another server, AWM_FAST_SEATS to the seat count (5).

import
  std/[json, math, os, random, strformat, strutils, tables],
  curly, zippy, zippy/ziparchives,
  sim, replays

const
  DefaultBase = "https://fast-xp-k8s-prod.tail0f4a29.ts.net"
  DefaultOpponents = "stilt:v15,greenshank:v21," &
    "richard-awm-deckwarden-body-deck:v1,relh-awm-deckwarden-body-deck:v1," &
    "AWM Baseline:v2"
  Episodes = 10

let Seats = if getEnv("AWM_FAST_SEATS").len > 0: parseInt(getEnv("AWM_FAST_SEATS")) else: 5
  ## Seats per game: ours plus Seats - 1 rivals (AWM_FAST_SEATS=6 seats every rival).

type
  Seating = object
    labels: seq[string]  ## Per seat: "ours" or a policy ref.

proc seating(opponents: seq[string], seed, batch: int): Seating =
  ## Four rivals drawn without replacement and a shuffled seat order.
  var rng = initRand(seed * 1000 + batch)
  var pool = opponents
  rng.shuffle(pool)
  var labels = @["ours"]
  for k in 0 ..< Seats - 1:
    labels.add pool[k mod pool.len]
  rng.shuffle(labels)
  Seating(labels: labels)

proc winnerOf(bytes: string): int =
  ## Replays a recorded match and returns the winning seat, or -1.
  var raw = bytes
  if raw.len > 2 and raw[0] == '\x1f' and raw[1] == '\x8b':
    raw = uncompress(raw, dfGzip)
  let data = decodeReplayFile(ReplayGame, ReplayGameVersion, raw, ReplayData)
  var game = newGame(data.header.setup)
  for action in data.actions:
    if not game.applyAction(action):
      break
  if game.gameOver: game.winner else: -1

proc rawReplay(bytes: string): string =
  ## The uncompressed replay bytes.
  result = bytes
  if result.len > 2 and result[0] == '\x1f' and result[1] == '\x8b':
    result = uncompress(result, dfGzip)

proc manifestOk(zipBytes: string): bool =
  ## Whether a response ZIP holds a manifest without failed games.
  let path = getTempDir() / "fastfield_check_" & $getCurrentProcessId() & ".zip"
  writeFile(path, zipBytes)
  try:
    let reader = openZipArchive(path)
    defer:
      reader.close()
    let manifest = parseJson(reader.extractFile("manifest.json"))
    for game in manifest["games"]:
      if game["status"].getStr != "completed":
        return false
    true
  except CatchableError:
    false

proc signTest(gained, lost: int): float =
  ## One-sided sign test that gains exceed losses by chance.
  let n = gained + lost
  if n == 0:
    return 1.0
  for k in gained .. n:
    result += exp(lgamma((n + 1).float) - lgamma((k + 1).float) -
      lgamma((n - k + 1).float) - n.float * ln(2.0))

proc main() =
  ## Sends the requests, retries refusals, exports replays and scores.
  if paramCount() < 4:
    quit("Usage: fastfield TAG SEED BATCHES A.bas [B.bas ...]", 1)
  let
    tag = paramStr(1)
    seed = parseInt(paramStr(2))
    batches = parseInt(paramStr(3))
    base = if getEnv("AWM_FAST_BASE").len > 0: getEnv("AWM_FAST_BASE") else: DefaultBase
    directory = absolutePath(currentSourcePath().parentDir.parentDir / "eps" / "fast" / tag)
  var opponents: seq[string]
  for reference in (if getEnv("AWM_OPPONENTS").len > 0: getEnv("AWM_OPPONENTS") else: DefaultOpponents).split(','):
    opponents.add reference.strip
  createDir(directory)
  var names: seq[string]
  var bodies = initOrderedTable[string, string]()
  for k in 4 .. paramCount():
    let name = paramStr(k).splitFile.name
    names.add name
    let source = readFile(paramStr(k))
    for b in 0 ..< batches:
      let order = seating(opponents, seed, b)
      var roster = newJArray()
      for slot, label in order.labels:
        if label == "ours":
          roster.add %*{"slot": slot, "player": {"source": source}}
        else:
          roster.add %*{"slot": slot, "player": {"policy_ref": label}}
      bodies[name & "_" & $b] = $(%*{"seed": seed + b * Episodes,
        "roster": roster, "num_episodes": Episodes})
  let curl = newCurly(8)
  defer:
    curl.close()
  var pending: seq[string]
  for key in bodies.keys:
    if not fileExists(directory / key & ".zip"):
      pending.add key
  var attempt = 0
  while pending.len > 0:
    inc attempt
    if attempt > 15:
      quit("fastfield: requests still failing: " & $pending, 1)
    var batch: RequestBatch
    var headers: HttpHeaders
    headers["Content-Type"] = "application/json"
    for key in pending:
      batch.post(base & "/v1/games/awm/run", headers, bodies[key], key)
    let responses = curl.makeRequests(batch, timeout = 2400)
    var retry: seq[string]
    for i, (response, error) in responses:
      let key = pending[i]
      if error.len == 0 and response.code == 200 and manifestOk(response.body):
        writeFile(directory / key & ".zip", response.body)
      else:
        echo key, ": HTTP ", response.code, " ", error, " ",
          response.body[0 ..< min(160, response.body.len)]
        if error.len == 0 and response.code in 400 .. 499 and
            response.code != 429:
          quit("fastfield: request rejected, not retrying", 1)
        retry.add key
    pending = retry
    if pending.len > 0:
      sleep(min(60_000, 2_000 * attempt * attempt))
  # Score and export.
  var
    wins = initTable[string, seq[int]]()  # name -> per game 1/0
    rivalWins = initTable[string, CountTable[string]]()
    errors = initCountTable[string]()
  for name in names:
    let replayDir = directory / "replays_" & name
    createDir(replayDir)
    var index = ""
    var games: seq[int]
    for b in 0 ..< batches:
      let order = seating(opponents, seed, b)
      let reader = openZipArchive(directory / name & "_" & $b & ".zip")
      defer:
        reader.close()
      let manifest = parseJson(reader.extractFile("manifest.json"))
      for game in manifest["games"]:
        let idx = game["index"].getInt
        let folder = "games/" & align($idx, 3, '0')
        let bytes = reader.extractFile(folder & "/replay.replay")
        let winner = winnerOf(bytes)
        let gameName = "g" & $(b * Episodes + idx)
        writeFile(replayDir / gameName & ".raw", rawReplay(bytes))
        var labels, scores: seq[string]
        for slot, label in order.labels:
          labels.add (if label == "ours": "radogost:" & name else: label)
          scores.add (if winner == slot: "1.0" else: "0.0")
        index.add gameName & "\t-\t" & labels.join("|") & "\t" & scores.join("|") & "\n"
        let ourSlot = order.labels.find("ours")
        games.add (if winner == ourSlot: 1 else: 0)
        if winner >= 0 and winner != ourSlot:
          rivalWins.mgetOrPut(name, initCountTable[string]()).inc order.labels[winner]
        try:
          errors.inc name, reader.extractFile(folder & "/logs/slot-" & $ourSlot & ".txt").count("error")
        except CatchableError:
          discard
    writeFile(replayDir / "index.tsv", index)
    wins[name] = games
  for name in names:
    let total = wins[name].len
    var w = 0
    for g in wins[name]:
      w += g
    var rivals = ""
    if name in rivalWins:
      for reference, n in rivalWins[name]:
        rivals.add &" {reference.split(':')[0]} {n}"
    echo &"{name}: {w}/{total} ({100.0 * w.float / max(total, 1).float:.1f}%) log errors {errors[name]} | rivals{rivals}"
  for k in 1 ..< names.len:
    var gained, lost = 0
    for g in 0 ..< min(wins[names[0]].len, wins[names[k]].len):
      if wins[names[k]][g] == 1 and wins[names[0]][g] == 0: inc gained
      if wins[names[k]][g] == 0 and wins[names[0]][g] == 1: inc lost
    echo &"  {names[k]} vs {names[0]}: gained {gained} lost {lost} sign p {signTest(gained, lost):.3f}"

main()
