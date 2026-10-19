## Paired fast-XP screens: every candidate plays the same seeds in the
## league's five-seat format against the live champions and the filler.
##
##   fastxp TAG SEED BATCHES A.bas [B.bas...]
##
## Each batch is one ten-episode request per candidate. ZIPs are saved under
## `eps/fast/TAG/`. Winners come from the returned replays' final states.

import
  std/[json, math, os, random, strformat, strutils, tables],
  curly, zippy, zippy/ziparchives,
  sim, match, replays

const
  Bases = [
    "https://fast-xp-request-staging.tail0f4a29.ts.net",
    "https://fast-xp-request.tail0f4a29.ts.net"
  ]
  DefaultOpponents = ["stilt:v3", "greenshank:v7", "AWM Baseline:v1",
    "AWM Baseline Filler:v1"]
  Episodes = 10

var Opponents = @DefaultOpponents  ## Overridden by AWM_OPPONENTS (comma list).

type
  Outcome = object
    errors: int  ## BASIC error lines in our bot's log.
    won: bool
    heroClass: HeroClass
    winner: int  ## Roster entry that won, or -1.

var layouts: seq[seq[int]]  ## Real league seat orders, when loaded.

proc seatOrder(seed, batch: int): seq[int] =
  ## Seat order for one batch: a real league layout when AWM_LAYOUTS names
  ## a league status file, else a seeded shuffle. Entry 0 is ours.
  if layouts.len > 0:
    return layouts[batch mod layouts.len]
  result = @[0, 1, 2, 3, 4]
  var rng = initRand(seed + batch * 7919)
  rng.shuffle(result)

proc loadLayouts(path: string) =
  ## Reads league episodes' seatings as roster entry orders.
  const names = ["", "stilt", "greenshank", "AWM Baseline",
    "AWM Baseline Filler"]
  for episode in parseJson(readFile(path))["episodes"]:
    var order = newSeq[int](episode["participants"].len)
    for p in episode["participants"]:
      let name = p["policy_name"].getStr
      order[p["position"].getInt] = max(0, names.find(name))
    layouts.add order

proc winnerOf(bytes: string): tuple[winner: int, classes: seq[HeroClass]] =
  ## Applies a replay's recorded actions and returns the winning seat.
  var raw = bytes
  if raw.len > 2 and raw[0] == '\x1f' and raw[1] == '\x8b':
    raw = uncompress(raw, dfGzip)
  let data = decodeReplayFile(ReplayGame, ReplayGameVersion, raw, ReplayData)
  var game = newGame(data.header.setup.heroClasses, data.header.setup.seed)
  for action in data.actions:
    discard game.applyAction(action)
  result.classes = data.header.setup.heroClasses
  result.winner = if game.gameOver: game.winner else: -1

var exported: Table[string, JsonNode]  ## Status-like episodes per candidate.

proc exportBatch(name, zipPath, outdir: string, entries: seq[int], batch: int) =
  ## Writes a batch's replays and seat labels for the stats extractor.
  let reader = openZipArchive(zipPath)
  defer:
    reader.close()
  let manifest = parseJson(reader.extractFile("manifest.json"))
  if name notin exported:
    exported[name] = %*{"episodes": []}
  for game in manifest["games"]:
    let
      index = game["index"].getInt
      job = name & "_" & $batch & "_" & $index
    writeFile(outdir / job & ".replay",
      reader.extractFile("games/" & align($index, 3, '0') & "/replay.replay"))
    var participants = newJArray()
    var position = 0
    for entry in game["roster_entries_by_slot"]:
      let id = entries[entry.getInt]
      let label = if id == 0: "radogost:" & name else: Opponents[id - 1]
      participants.add %*{"position": position, "label": label}
      inc position
    exported[name]["episodes"].add %*{"job_id": job, "status": "completed",
      "participants": participants}

proc parse(zipPath: string, entries: seq[int]): seq[Outcome] =
  ## Reads one response ZIP into per-episode outcomes for roster entry 0.
  let reader = openZipArchive(zipPath)
  defer:
    reader.close()
  let manifest = parseJson(reader.extractFile("manifest.json"))
  for game in manifest["games"]:
    if game["status"].getStr != "completed":
      raise newException(ValueError, "fast-XP game failed: " & $game)
    var slots: seq[int]
    for entry in game["roster_entries_by_slot"]:
      slots.add entries[entry.getInt]
    let
      index = game["index"].getInt
      path = "games/" & align($index, 3, '0') & "/replay.replay"
      (winner, classes) = winnerOf(reader.extractFile(path))
    var outcome = Outcome(winner: -1, heroClass: classes[slots.find(0)])
    let log = "games/" & align($index, 3, '0') & "/logs/slot-" &
      $slots.find(0) & ".txt"
    try:
      outcome.errors = reader.extractFile(log).count("BASIC error")
    except CatchableError:
      discard
    if winner >= 0:
      outcome.winner = slots[winner]
      outcome.won = slots[winner] == 0
    result.add outcome

proc manifestText(zipBytes: string): string =
  ## Returns a response ZIP's manifest text, or a failure marker.
  let path = getTempDir() / "fastxp_check.zip"
  writeFile(path, zipBytes)
  try:
    let reader = openZipArchive(path)
    defer:
      reader.close()
    result = $parseJson(reader.extractFile("manifest.json"))
  except CatchableError:
    result = "\"status\":\"failed\""

proc signTest(gained, lost: int): float =
  ## Exact one-sided sign test that gains exceed losses by chance.
  let n = gained + lost
  if n == 0:
    return 1.0
  for k in gained .. n:
    result += exp(lgamma((n + 1).float) - lgamma((k + 1).float) -
      lgamma((n - k + 1).float) - n.float * ln(2.0))

proc main() =
  ## Sends every request in parallel, retries refusals, and scores pairs.
  if paramCount() < 4:
    quit("Usage: fastxp TAG SEED BATCHES A.bas [B.bas...]", 1)
  let
    tag = paramStr(1)
    seed = parseInt(paramStr(2))
    batches = parseInt(paramStr(3))
    directory = absolutePath(currentSourcePath().parentDir.parentDir / "eps" / "fast" / tag)
  createDir(directory)
  if getEnv("AWM_OPPONENTS").len > 0:
    Opponents = getEnv("AWM_OPPONENTS").split(',')
    if Opponents.len != 4:
      quit("fastxp: AWM_OPPONENTS needs four policies", 1)
  if getEnv("AWM_LAYOUTS").len > 0:
    loadLayouts(getEnv("AWM_LAYOUTS"))
  var names: seq[string]
  var bodies: Table[string, string]
  for k in 4 .. paramCount():
    let name = paramStr(k).splitFile.name
    names.add name
    let source = readFile(paramStr(k))
    for b in 0 ..< batches:
      # League rounds shuffle seats, so each batch pins a seeded order
      # shared by every candidate; entry 0 is ours.
      let order = seatOrder(seed, b)
      var roster = newJArray()
      for slot, entry in order:
        if entry == 0:
          roster.add %*{"slot": slot, "player": {"source": source}}
        elif getEnv("AWM_OPPONENT_SOURCES") == "1":
          # Opponents' downloaded sources instead of their labels.
          let others = currentSourcePath().parentDir.parentDir / "others"
          let file = others / Opponents[entry - 1].replace(" ", "_").replace(":", "_") & ".bas"
          roster.add %*{"slot": slot, "player": {"source": readFile(file)}}
        else:
          roster.add %*{"slot": slot,
            "player": {"policy_ref": Opponents[entry - 1]}}
      let body = %*{"seed": seed + b * Episodes, "roster": roster,
        "num_episodes": Episodes}
      bodies[name & "_" & $b] = $body
  let curl = newCurly(8)
  defer:
    curl.close()
  var
    pending: seq[string]
    zips: Table[string, string]
  for key in bodies.keys:
    if fileExists(directory / key & ".zip"):
      zips[key] = readFile(directory / key & ".zip")
    else:
      pending.add key
  var attempt = 0
  while pending.len > 0:
    inc attempt
    if attempt > 12:
      quit("fastxp: requests still failing: " & $pending, 1)
    var batch: RequestBatch
    var headers: HttpHeaders
    headers["Content-Type"] = "application/json"
    for i, key in pending:
      batch.post(Bases[i mod Bases.len] & "/v1/games/awm/run", headers,
        bodies[key], key)
    let responses = curl.makeRequests(batch, timeout = 1800)
    var retry: seq[string]
    for i, (response, error) in responses:
      let key = pending[i]
      if error.len == 0 and response.code == 200 and
          "\"status\":\"failed\"" notin manifestText(response.body):
        writeFile(directory / key & ".zip", response.body)
        zips[key] = response.body
      else:
        if attempt == 1 or error.len > 0:
          echo key, ": HTTP ", response.code, " ", error,
            " ", response.body[0 ..< min(200, response.body.len)]
        if error.len == 0 and response.code in 400 .. 499 and
            response.code != 429:
          quit("fastxp: request rejected, not retrying", 1)
        retry.add key
    pending = retry
    if pending.len > 0:
      sleep(min(60_000, 2_000 * attempt * attempt))
  var outcomes: Table[string, seq[Outcome]]
  for name in names:
    for b in 0 ..< batches:
      let order = seatOrder(seed, b)
      outcomes.mgetOrPut(name, @[]).add parse(
        directory / name & "_" & $b & ".zip", order)
      createDir(directory / "replays")
      exportBatch(name, directory / name & "_" & $b & ".zip",
        directory / "replays", order, b)
  for name in names:
    var
      wins = 0
      errors = 0
      classWins, classGames: array[HeroClass, int]
      entryWins: array[5, int]
    for o in outcomes[name]:
      errors += o.errors
      inc classGames[o.heroClass]
      if o.won:
        inc wins
        inc classWins[o.heroClass]
      if o.winner >= 0:
        inc entryWins[o.winner]
    let games = outcomes[name].len
    var line = &"{name}: {wins}/{games} " &
      &"({100.0 * wins.float / games.float:.1f}%) errors {errors}"
    for c in HeroClass:
      line.add &" {c} {classWins[c]}/{classGames[c]}"
    line.add &" | stilt {entryWins[1]} green {entryWins[2]}" &
      &" base {entryWins[3]} filler {entryWins[4]}"
    echo line
  for name in names:
    writeFile(directory / "status_" & name & ".json", $exported[name])
  for k in 1 ..< names.len:
    var gained, lost: int
    for g in 0 ..< outcomes[names[0]].len:
      let
        a = outcomes[names[0]][g].won
        b = outcomes[names[k]][g].won
      if b and not a:
        inc gained
      if a and not b:
        inc lost
    echo &"paired {names[k]} vs {names[0]}: gained {gained}, lost {lost}, " &
      &"one-sided p {signTest(gained, lost):.4f}"

main()
