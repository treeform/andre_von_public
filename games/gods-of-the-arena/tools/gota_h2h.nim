## Team head-to-heads on the fast XP service: five copies of a candidate
## against five copies of one opponent, half the games on each side.
##
##   gota_h2h <candidate.bas> <opponent policy ref> <tag> [--games 40]
##     [--seed 7000] [--spread 10] [--stats /tmp/claude-501/gota_stats108]
##     [--cache dir]
##
## Requests hold ten games each and alternate between Red and Blue. The
## seeds depend only on --seed and --spread, so two candidates run with the
## same values meet the opponent in the same starts. --spread sets how far
## apart each request's block of ten seeds starts (opponents behave very
## differently by seed, so spread blocks widely). A 429 is retried unchanged
## after its Retry-After plus a jittered backoff. Each game is scored from its replay
## (our team won, lost, or drew) and appended to eps/fast/<tag>.tsv as: side,
## seed, result, our kills, our deaths. Each game's stats rows are kept in
## the cache dir and listed in <cache>/<tag>.h2h for gota_table --h2h.

import
  std/[json, os, osproc, random, sequtils, strformat, strutils, times],
  curly, zippy/ziparchives

const
  Server = "https://fast-xp-k8s-staging.tail0f4a29.ts.net"
  ResultDir = "games/gods-of-the-arena/eps/fast"
  GamesPerRequest = 10

proc requestBody(source, opponent: string, red: bool, seed: int): string =
  ## Builds one ten-game request with our source on one whole team.
  var entries = newJArray()
  for slot in 0 ..< 10:
    let ours = (slot < 5) == red
    if ours:
      entries.add %*{"slot": slot, "player": {"source": source}}
    else:
      entries.add %*{"slot": slot, "player": {"policy_ref": opponent}}
  $(%*{"seed": seed, "num_episodes": GamesPerRequest, "roster": entries})

proc field(row, name: string): string =
  ## Returns one key=value field of a stats row.
  for part in row.split(' '):
    if part.startsWith(name & "="):
      return part[name.len + 1 .. ^1]
  ""

proc scoreGame(rows: string, red: bool): (string, int, int) =
  ## Returns (W, L or D, our kills, our deaths) from one replay's stats rows.
  if not fileExists(rows):
    return ("?", 0, 0)
  let output = readFile(rows)
  if "row " notin output:
    return ("?", 0, 0)
  var
    ourWon, theirWon = false
    kills, deaths = 0
  let ourTeam = if red: "0" else: "1"
  for line in output.splitLines:
    if not line.startsWith("row "):
      continue
    let mine = line.field("team") == ourTeam
    if line.field("won") == "1":
      if mine: ourWon = true else: theirWon = true
    if mine:
      kills += parseInt(line.field("kills"))
      deaths += parseInt(line.field("deaths"))
  let outcome =
    if ourWon: "W"
    elif theirWon: "L"
    else: "D"
  (outcome, kills, deaths)

proc retryAfter(response: Response): float =
  ## Returns the Retry-After wait in seconds, zero when missing or a date.
  try:
    parseFloat(response.headers["Retry-After"])
  except CatchableError:
    0.0

proc main() =
  let arguments = commandLineParams()
  if arguments.len < 3:
    quit("usage: gota_h2h <candidate.bas> <opponent ref> <tag> [--games 40] [--seed 7000]")
  let
    source = readFile(arguments[0])
    opponent = arguments[1]
    tag = arguments[2]
  var
    games = 40
    seed = 7000
    spread = 10
    stats = "/tmp/claude-501/gota_stats108"
    cache = getTempDir() / "gota_h2h"
    i = 3
  while i < arguments.len:
    case arguments[i]
    of "--games":
      games = parseInt(arguments[i + 1])
    of "--seed":
      seed = parseInt(arguments[i + 1])
    of "--spread":
      spread = parseInt(arguments[i + 1])
    of "--stats":
      stats = arguments[i + 1]
    of "--cache":
      cache = arguments[i + 1]
    else:
      quit("unknown option " & arguments[i])
    i += 2
  createDir(ResultDir)
  createDir(cache)
  randomize()
  let requests = (games + GamesPerRequest - 1) div GamesPerRequest
  var
    bodies: seq[string]
    sides: seq[bool]
    seeds: seq[int]
  for k in 0 ..< requests:
    let red = k mod 2 == 0
    let requestSeed = seed + (k div 2) * spread
    bodies.add requestBody(source, opponent, red, requestSeed)
    sides.add red
    seeds.add requestSeed
  ## Post every request; repost the 429s unchanged until each is admitted.
  var
    results = newSeq[Response](requests)
    done = newSeq[bool](requests)
    window = 1.0
  let deadline = epochTime() + 3 * 3600
  while true:
    var
      batch: RequestBatch
      indexes: seq[int]
    for k in 0 ..< requests:
      if not done[k]:
        var headers = emptyHttpHeaders()
        headers["Content-Type"] = "application/json"
        batch.post(Server & "/v1/games/gota/run", headers, bodies[k])
        indexes.add k
    if indexes.len == 0 or epochTime() > deadline:
      break
    let curl = newCurly(indexes.len)
    let responses = curl.makeRequests(batch, timeout = 3600)
    curl.close()
    var wait = 0.0
    for j, (response, error) in responses:
      let k = indexes[j]
      if error.len == 0 and response.code == 429:
        wait = max(wait, retryAfter(response))
        continue
      done[k] = true
      if error.len > 0:
        echo &"  request {k}: failed, {error}"
      else:
        results[k] = response
    if done.allIt(it):
      break
    sleep(int((wait + rand(window)) * 1000))
    window = min(30.0, window * 2)
  var
    lines = ""
    listing = ""
    wins, losses, draws, kills, deaths = 0
  for k in 0 ..< requests:
    let response = results[k]
    if response.code != 200:
      if response.code != 0:
        echo &"  request {k}: HTTP {response.code} {response.body[0 ..< min(200, response.body.len)]}"
      continue
    let
      dir = cache / &"{tag}_{k}"
      zipPath = dir & ".zip"
    writeFile(zipPath, response.body)
    removeDir(dir)
    let reader = openZipArchive(zipPath)
    var files: seq[string]
    for path in reader.walkFiles:
      files.add path
    for path in files:
      try:
        let data = reader.extractFile(path)
        createDir(parentDir(dir / path))
        writeFile(dir / path, data)
      except ZippyError:
        echo &"  request {k}: corrupt {path}"
    reader.close()
    removeFile(zipPath)
    ## Score the request's replays four at a time and keep their rows.
    var commands: seq[string]
    for g in 0 ..< GamesPerRequest:
      let replay = dir / &"games/{g:03}/replay.replay"
      let rows = cache / &"{tag}_{seeds[k] + g}_{k}.rows"
      if fileExists(replay):
        commands.add quoteShell(stats) & " " & quoteShell(replay) & " > " &
          quoteShell(rows) & " 2>/dev/null"
    discard execProcesses(commands, n = 4, options = {poEvalCommand})
    for g in 0 ..< GamesPerRequest:
      let rows = cache / &"{tag}_{seeds[k] + g}_{k}.rows"
      let (outcome, ourKills, ourDeaths) = scoreGame(rows, sides[k])
      if outcome == "?":
        continue
      case outcome
      of "W": inc wins
      of "L": inc losses
      else: inc draws
      kills += ourKills
      deaths += ourDeaths
      let side = if sides[k]: "red" else: "blue"
      lines.add &"{side}\t{seeds[k] + g}\t{outcome}\t{ourKills}\t{ourDeaths}\n"
      listing.add &"{rows} {(if sides[k]: 0 else: 1)}\n"
    removeDir(dir)
  let f = open(ResultDir / tag & ".tsv", fmAppend)
  f.write lines
  f.close()
  let h = open(cache / tag & ".h2h", fmAppend)
  h.write listing
  h.close()
  let total = wins + losses + draws
  if total == 0:
    quit("no games scored")
  echo &"{tag} vs {opponent}: W{wins} D{draws} L{losses} of {total} " &
    &"({wins * 100 div total}% wins); our team kills {kills / total:.1f}, deaths {deaths / total:.1f} per game"

main()
