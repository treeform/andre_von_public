## Replays league rosters on the fast XP service with one seat swapped for a
## candidate's source, so a candidate is judged in mixed league teams.
##
##   gota_fast_live <candidate.bas | ref:name:vN> <bodies dir> <tag> [--seed 9500]
##     [--episodes 10] [--stats /tmp/claude-501/gota_stats108] [--cache dir]
##     [--keep]
##
## The bodies dir holds hosted xp-request bodies written by gota_live (one
## league roster each, our seat holding a khors policy ref). Each roster runs
## --episodes games from --seed with every seat pinned. A first argument of
## ref:name:vN puts a submitted policy in our seat instead of a source file, so
## a rival can be measured on the same rosters. A game is a W when our
## seat's team wins, L when the other team wins, D on a timeout. Results are
## appended to eps/fast/<tag>_live.tsv as: roster, seed, result, so
## gota_fast_score can pair two candidates on the same rosters and seeds. With
## --keep each roster's replays and stats rows stay in <cache>/<tag>_<roster>/.

import
  std/[json, os, osproc, random, sequtils, strformat, strutils, times],
  curly, zippy/ziparchives

const
  Server = "https://fast-xp-k8s-staging.tail0f4a29.ts.net"
  ResultDir = "games/gods-of-the-arena/eps/fast"

proc field(row, name: string): string =
  ## Returns one key=value field of a stats row.
  for part in row.split(' '):
    if part.startsWith(name & "="):
      return part[name.len + 1 .. ^1]
  ""

proc outcome(rows: string, seat: int): string =
  ## Returns W, L or D for our seat's team from one replay's stats rows.
  if not fileExists(rows):
    return "?"
  var
    ourTeam = ""
    winners: seq[string]
  for line in readFile(rows).splitLines:
    if not line.startsWith("row "):
      continue
    let parts = line.split(' ')
    if parseInt(parts[1]) == seat:
      ourTeam = line.field("team")
    if line.field("won") == "1":
      winners.add line.field("team")
  if ourTeam.len == 0:
    return "?"
  if ourTeam in winners: "W"
  elif winners.len > 0: "L"
  else: "D"

proc retryAfter(response: Response): float =
  ## Returns the Retry-After wait in seconds, zero when missing or a date.
  try:
    parseFloat(response.headers["Retry-After"])
  except CatchableError:
    0.0

proc main() =
  let arguments = commandLineParams()
  if arguments.len < 3:
    quit("usage: gota_fast_live <candidate.bas> <bodies dir> <tag> [--seed 9500] [--episodes 10]")
  let
    seatRef = if arguments[0].startsWith("ref:"): arguments[0][4 .. ^1] else: ""
    source = if seatRef.len > 0: "" else: readFile(arguments[0])
    bodiesDir = arguments[1]
    tag = arguments[2]
  var
    seed = 9500
    episodes = 10
    stats = "/tmp/claude-501/gota_stats108"
    cache = getTempDir() / "gota_fast_live"
    keep = false
    i = 3
  while i < arguments.len:
    case arguments[i]
    of "--seed": seed = parseInt(arguments[i + 1])
    of "--episodes": episodes = parseInt(arguments[i + 1])
    of "--stats": stats = arguments[i + 1]
    of "--cache": cache = arguments[i + 1]
    of "--keep":
      keep = true
      i -= 1
    else: quit("unknown option " & arguments[i])
    i += 2
  createDir(ResultDir)
  createDir(cache)
  randomize()
  var
    keys: seq[string]
    seats: seq[int]
    bodies: seq[string]
  for path in walkFiles(bodiesDir / "*.json"):
    let body = parseJson(readFile(path))
    var
      roster = newJArray()
      seat = -1
    for entry in body["roster"]:
      let slot = entry["slot"].getInt
      let reference = entry["player"]{"policy_ref"}.getStr
      if reference.startsWith("khors:") and seat < 0:
        seat = slot
        if seatRef.len > 0:
          roster.add %*{"slot": slot, "player": {"policy_ref": seatRef}}
        else:
          roster.add %*{"slot": slot, "player": {"source": source}}
      else:
        roster.add %*{"slot": slot, "player": {"policy_ref": reference}}
    if seat < 0:
      continue
    let key = splitFile(path).name.split('_')[^2 .. ^1].join("_")
    keys.add key
    seats.add seat
    bodies.add $(%*{"seed": seed, "num_episodes": episodes, "roster": roster})
  ## Post every roster; repost the 429s unchanged until each is admitted.
  var
    results = newSeq[Response](bodies.len)
    done = newSeq[bool](bodies.len)
    window = 1.0
  let deadline = epochTime() + 3 * 3600
  while true:
    var
      batch: RequestBatch
      indexes: seq[int]
    for k in 0 ..< bodies.len:
      if not done[k]:
        var headers = emptyHttpHeaders()
        headers["Content-Type"] = "application/json"
        batch.post(Server & "/v1/games/gota/run", headers, bodies[k])
        indexes.add k
    if indexes.len == 0 or epochTime() > deadline:
      break
    let curl = newCurly(min(indexes.len, 8))
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
        echo &"  roster {keys[k]}: failed, {error}"
      else:
        results[k] = response
    if done.allIt(it):
      break
    sleep(int((wait + rand(window)) * 1000))
    window = min(30.0, window * 2)
  var
    lines = ""
    wins, losses, draws = 0
  for k in 0 ..< bodies.len:
    let response = results[k]
    if response.code != 200:
      if response.code != 0:
        echo &"  roster {keys[k]}: HTTP {response.code} {response.body[0 ..< min(200, response.body.len)]}"
      continue
    let dir = cache / &"{tag}_{keys[k]}"
    let zipPath = dir & ".zip"
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
        echo &"  roster {keys[k]}: corrupt {path}"
    reader.close()
    removeFile(zipPath)
    var replays: seq[string]
    if episodes == 1:
      replays.add dir / "replay.replay"
    else:
      for g in 0 ..< episodes:
        replays.add dir / &"games/{g:03}/replay.replay"
    var commands: seq[string]
    for replay in replays:
      if fileExists(replay):
        commands.add quoteShell(stats) & " " & quoteShell(replay) & " > " &
          quoteShell(replay & ".rows") & " 2>/dev/null"
    discard execProcesses(commands, n = 4, options = {poEvalCommand})
    for g, replay in replays:
      let verdict = outcome(replay & ".rows", seats[k])
      if verdict == "?":
        continue
      case verdict
      of "W": inc wins
      of "L": inc losses
      else: inc draws
      lines.add &"{keys[k]}\t{seed + g}\t{verdict}\n"
    if not keep:
      removeDir(dir)
  let f = open(ResultDir / tag & "_live.tsv", fmAppend)
  f.write lines
  f.close()
  let total = wins + losses + draws
  if total == 0:
    quit("no games scored")
  echo &"{tag} live rosters: W{wins} D{draws} L{losses} of {total} ({wins * 100 div total}% wins)"

main()
