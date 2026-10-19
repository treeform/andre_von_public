## Replays live league rosters on the fast XP service and scores glory.
##
##   gota_fast run <candidate.bas> <tag> --rounds A-B [--episodes 2]
##     [--server url] [--seed-offset N] [--parallel 8] [--stats /tmp/gota_stats926]
##     [--cache dir]
## --server (repeatable) defaults to both fast XP services; requests alternate
## between them and --parallel defaults to 8 per server.
## --seed-offset N adds N * 1,000,000 to every seed and records game index
## N * 100 + i, so extra batches on the same rosters accumulate in one tag.
##   gota_fast score <base tag> <cand tag>
##
## run: every completed game of those rounds in which our player took a
## seat becomes one request: the same ten policies in the same seats, our
## candidate's BASIC source in our seat. The seed depends only on the roster,
## so two arms play identical starts. Each game's replay goes through the
## stats extractor; our seat's glory (lifetime XP / minutes when our team
## won, else 0) is appended to eps/fast/<tag>.tsv. Finished rosters are
## skipped on a rerun.
## score: pairs two tags by roster and game index and reports the paired
## difference of our glory with its t statistic.

import
  std/[httpclient, json, math, os, osproc, sets, strformat, strutils, tables],
  curly, zippy/ziparchives

const
  Dash = "https://softmaxdash-nginx.tail0f4a29.ts.net/league/gods-of-the-arena.json"
  Api = "https://softmax.com/api/observatory/v2/rounds/"
  FastServers = [
    "https://fast-xp-request-staging.tail0f4a29.ts.net",
    "https://fast-xp-request.tail0f4a29.ts.net"
  ]
  Player = "Andre von Auto"
  ResultDir = "games/gods-of-the-arena/eps/fast"

type
  Roster = object
    key: string
    seat: int
    seed: int
    policies: array[10, string]

proc userToken(): string =
  ## Returns the user (not player) bearer token from the credentials file.
  var inTokens = false
  for line in readFile(getHomeDir() / ".softmax/credentials.yaml").splitLines:
    if line.startsWith("tokens:"):
      inTokens = true
    elif inTokens and "https" in line:
      return line.split(": ")[^1].strip(chars = {'"', ' '})
  quit("no user token in credentials.yaml")

proc liveRosters(first, last: int): seq[Roster] =
  ## Reads every live game our player sat in during rounds first..last.
  let
    client = newHttpClient(timeout = 60_000)
    league = parseJson(client.getContent(Dash))
  client.headers = newHttpHeaders({"Authorization": "Bearer " & userToken()})
  var numbers: seq[(int, string)]
  for round in league["rounds"]:
    numbers.add((round["number"].getInt, round["id"].getStr))
  for number in first .. last:
    var id = ""
    for (n, roundId) in numbers:
      if n == number:
        id = roundId
    if id.len == 0:
      let page = parseJson(client.getContent(
        &"https://softmaxdash-nginx.tail0f4a29.ts.net/league/gods-of-the-arena/rounds/{number}.json"))
      id = page["round"]["id"].getStr
    let body = parseJson(client.getContent(Api & id & "/episodes"))
    var game = 0
    for episode in body["entries"]:
      inc game
      if episode{"status"}.getStr != "completed":
        continue
      var
        roster = Roster(key: &"{number}_{game:02}", seat: -1,
          seed: number * 100 + game)
        seats = 0
      for p in episode["participants"]:
        let position = p["position"].getInt
        roster.policies[position] = &"{p[\"policy_name\"].getStr}:v{p[\"version\"].getInt}"
        inc seats
        if p{"player_name"}.getStr == Player:
          roster.seat = position
      if roster.seat >= 0 and seats == 10:
        result.add roster

proc requestBody(roster: Roster, source: string, episodes, offset: int): string =
  ## Builds the fast XP request: our source pinned to our seat.
  var entries = newJArray()
  for slot in 0 ..< 10:
    if slot == roster.seat:
      entries.add %*{"slot": slot, "player": {"source": source}}
    else:
      entries.add %*{"slot": slot, "player": {"policy_ref": roster.policies[slot]}}
  $(%*{"seed": roster.seed + offset * 1_000_000, "num_episodes": episodes, "roster": entries,
    "config": {"max_ticks": 28800}})

proc field(row, name: string): string =
  ## Returns one key=value field of a stats row.
  for part in row.split(' '):
    if part.startsWith(name & "="):
      return part[name.len + 1 .. ^1]
  ""

proc scoreGame(stats, replay: string, seat: int): (int, float, float, float) =
  ## Returns (won, xp, minutes, glory) for our seat in one replay.
  let (output, code) = execCmdEx(quoteShell(stats) & " " & quoteShell(replay))
  if code != 0:
    return (-1, 0.0, 0.0, 0.0)
  for line in output.splitLines:
    if line.startsWith(&"row {seat} "):
      let
        won = parseInt(line.field("won"))
        xp = parseFloat(line.field("xp"))
        minutes = parseFloat(line.field("minutes"))
        glory =
          if won == 1 and minutes > 0:
            floor(xp / minutes)
          else:
            0.0
      return (won, xp, minutes, glory)
  (-1, 0.0, 0.0, 0.0)

proc run(arguments: seq[string]) =
  ## Runs one candidate over the live rosters.
  let
    candidate = arguments[0]
    tag = arguments[1]
    source = readFile(candidate)
  var
    first, last = 0
    episodes = 2
    offset = 0
    servers: seq[string]
    parallel = 0
    stats = "/tmp/gota_stats926"
    cache = getTempDir() / "gota_fast"
    i = 2
  while i < arguments.len:
    case arguments[i]
    of "--rounds":
      let parts = arguments[i + 1].split('-')
      first = parseInt(parts[0])
      last = parseInt(parts[^1])
    of "--episodes":
      episodes = parseInt(arguments[i + 1])
    of "--server":
      servers.add arguments[i + 1]
    of "--seed-offset":
      offset = parseInt(arguments[i + 1])
    of "--parallel":
      parallel = parseInt(arguments[i + 1])
    of "--stats":
      stats = arguments[i + 1]
    of "--cache":
      cache = arguments[i + 1]
    else:
      quit("unknown option " & arguments[i])
    i += 2
  doAssert first > 0 and last >= first, "pass --rounds A-B"
  if servers.len == 0:
    servers = @FastServers
  if parallel == 0:
    parallel = 8 * servers.len
  createDir(ResultDir)
  createDir(cache)
  let tsv = ResultDir / tag & ".tsv"
  var done: HashSet[string]
  if fileExists(tsv):
    for line in readFile(tsv).splitLines:
      if line.len > 0:
        let parts = line.split('\t')
        if parseInt(parts[1]) div 100 == offset:
          done.incl parts[0]
  var pending: seq[Roster]
  for roster in liveRosters(first, last):
    if roster.key notin done:
      pending.add roster
  echo &"{tag}: {pending.len} rosters to run, {done.len} already done"
  let curl = newCurly(parallel)
  var
    position = 0
    failures = 0
  while position < pending.len:
    var
      batch: RequestBatch
      wave: seq[Roster]
    while position < pending.len and wave.len < parallel:
      let roster = pending[position]
      var headers = emptyHttpHeaders()
      headers["Content-Type"] = "application/json"
      batch.post(servers[position mod servers.len] & "/v1/games/gota/run",
        headers,
        requestBody(roster, source, episodes, offset), roster.key)
      wave.add roster
      inc position
    let responses = curl.makeRequests(batch, timeout = 1200)
    var lines = ""
    for k, (response, error) in responses:
      let roster = wave[k]
      if error.len > 0 or response.code != 200:
        let reason =
          if error.len > 0: error
          else: &"HTTP {response.code} {response.body[0 ..< min(200, response.body.len)]}"
        echo &"  {roster.key}: failed, {reason}"
        inc failures
        if response.code == 429:
          pending.add roster
        continue
      let
        zipPath = cache / &"{tag}_{roster.key}.zip"
        dir = cache / &"{tag}_{roster.key}"
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
          echo &"  {roster.key}: corrupt {path} in the response zip"
      reader.close()
      let manifest = parseJson(readFile(dir / "manifest.json"))
      for game in manifest["games"]:
        let index = game["index"].getInt
        if game["status"].getStr != "completed":
          echo &"  {roster.key} game {index}: {game[\"status\"].getStr}"
          continue
        let replay = dir / &"games/{index:03}/replay.replay"
        if not fileExists(replay):
          continue
        let
          (won, xp, minutes, glory) = scoreGame(stats, replay, roster.seat)
        if won < 0:
          echo &"  {roster.key} game {index}: stats failed"
          continue
        lines.add &"{roster.key}\t{offset * 100 + index}\t{roster.seat}\t{won}\t{xp:.0f}\t{minutes:.2f}\t{glory:.0f}\n"
      # The zip stays; the extracted replays are 10-18 MB per roster.
      removeDir(dir)
    let f = open(tsv, fmAppend)
    f.write lines
    f.close()
    echo &"  {min(position, pending.len)} of {pending.len} rosters sent, {failures} failures"
  curl.close()

proc load(tag: string): Table[string, float] =
  ## Reads one tag's glory per roster and game index.
  for line in readFile(ResultDir / tag & ".tsv").splitLines:
    let parts = line.split('\t')
    if parts.len >= 7:
      result[parts[0] & "/" & parts[1]] = parseFloat(parts[6])

proc score(base, cand: string) =
  ## Paired comparison of two tags over their shared games.
  let
    a = load(base)
    b = load(cand)
  var
    diffs: seq[float]
    sumA, sumB = 0.0
    winsA, winsB = 0
  for key, value in a:
    if key in b:
      diffs.add b[key] - value
      sumA += value
      sumB += b[key]
      if value > 0: inc winsA
      if b[key] > 0: inc winsB
  let n = diffs.len
  if n < 2:
    quit("fewer than two shared games")
  var mean, variance = 0.0
  for d in diffs:
    mean += d
  mean /= n.float
  for d in diffs:
    variance += (d - mean) * (d - mean)
  variance /= (n - 1).float
  let t =
    if variance > 0: mean / sqrt(variance / n.float)
    else: 0.0
  echo &"{n} paired games: {base} {sumA / n.float:.1f} ({winsA} wins) {cand} {sumB / n.float:.1f} ({winsB} wins)"
  echo &"paired diff {mean:+.1f} per game, t = {t:.2f}"
  echo "verdict: ", (if t >= 2.0: "KEEP" elif t <= -2.0: "REVERT (significant loss)" else: "inconclusive")

proc main() =
  let arguments = commandLineParams()
  if arguments.len >= 3 and arguments[0] == "run":
    run(arguments[1 .. ^1])
  elif arguments.len == 3 and arguments[0] == "score":
    score(arguments[1], arguments[2])
  else:
    quit("usage: gota_fast run <candidate.bas> <tag> --rounds A-B [...] | gota_fast score <base> <cand>")

main()
