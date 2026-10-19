## Hosted MOBA replay extractor and action-distribution analyzer.
## Fetches public dashboard JSON and replay bytes, validates format v1,
## and writes tallies under research/evidence. Positions are not stored
## in the replay body, so trajectories are not recovered.

import
  std/[algorithm, httpclient, json, os, strutils, times],
  replays, tallies

const
  DashBase = "https://softmaxdash-nginx.tail0f4a29.ts.net"
  LeaguePath = "/league/moba.json"
  RoundPath = "/league/moba/rounds/3730.json"
  UserAgent = "gorynych-research/1.0"
  RequestTimeoutMs = 120_000
  MaxReplays = 12
  MaxExtraRounds = 8
  ResearchDir = currentSourcePath().parentDir
  EvidenceDir = ResearchDir / "evidence"
  Targets = [
    "daveey-scripted:v39",
    "co-gas-moba-topstack-richard:v7",
    "co-gas-moba-topstack-relhalpha:v3"
  ]

type
  ExtractorError = object of CatchableError
  GameRef = object
    roundNumber: int
    gameNumber: int
    episodeId: string
    status: string
    policies: string
    turns: int
    score: int
    replayUrl: string
    localJson: string
    localReplay: string

proc raiseExtract(message: string) {.raises: [ExtractorError].} =
  ## Raises ExtractorError with message.
  raise newException(ExtractorError, message)

proc firstField(node: JsonNode, names: varargs[string]): JsonNode =
  ## Returns the first present non-null field.
  if node.isNil:
    return newJNull()
  for name in names:
    let value = node{name}
    if not value.isNil and value.kind != JNull:
      return value
  newJNull()

proc textField(node: JsonNode, names: varargs[string]): string =
  ## Returns a string field, or empty.
  let value = node.firstField(names)
  if value.kind == JString: value.getStr()
  elif value.kind in {JInt, JFloat, JBool}: $value
  else: ""

proc intField(node: JsonNode, names: varargs[string]): int =
  ## Returns an int field, or 0.
  let value = node.firstField(names)
  if value.kind == JInt:
    return value.getInt()
  if value.kind == JString:
    try:
      return parseInt(value.getStr("0"))
    except ValueError:
      return 0
  0

proc targetsIn(policies: string): seq[string] =
  ## Returns target labels found in a policies string.
  result = @[]
  for t in Targets:
    if t in policies:
      result.add t

proc gameScore(policies: string): int =
  ## Ranks a game for download priority.
  let found = targetsIn(policies)
  result = 10 * found.len
  if Targets[0] in found: result += 5
  if Targets[1] in found: result += 3
  if Targets[2] in found: result += 2

proc newClient(): HttpClient =
  ## Builds a client that asks for uncompressed bodies.
  result = newHttpClient(timeout = RequestTimeoutMs)
  result.headers = newHttpHeaders({
    "User-Agent": UserAgent,
    "Accept": "*/*",
    "Accept-Encoding": "identity"
  })

proc fetchBytes(
  client: HttpClient, url: string
): string {.raises: [ExtractorError].} =
  ## GETs url and returns the body, following redirects.
  try:
    let response = client.get(url)
    if response.code != Http200:
      raiseExtract(
        "GET " & url & " -> HTTP " & $response.code
      )
    result = response.body
    if result.len >= 2 and result[0].uint8 == 0x1f and
      result[1].uint8 == 0x8b:
        raiseExtract("gzip body from " & url & "; identity encoding failed")
  except ExtractorError as error:
    raise error
  except CatchableError as error:
    raiseExtract("GET " & url & " failed: " & error.msg)
  except Exception as error:
    raiseExtract("GET " & url & " failed: " & error.msg)

proc saveBytes(
  path, data: string
) {.raises: [ExtractorError].} =
  ## Writes data, creating parent directories.
  try:
    createDir(parentDir(path))
    writeFile(path, data)
  except CatchableError as error:
    raiseExtract("write " & path & ": " & error.msg)

proc ensureDir(path: string) {.raises: [ExtractorError].} =
  ## Creates a directory if needed.
  try:
    createDir(path)
  except CatchableError as error:
    raiseExtract("mkdir " & path & ": " & error.msg)

proc replayExists(path: string): bool {.raises: [ExtractorError].} =
  ## Reports whether a non-empty local replay is already saved.
  try:
    result = fileExists(path) and getFileSize(path) > PrefixLen
  except CatchableError as error:
    raiseExtract("stat " & path & ": " & error.msg)

proc dashUrl(path: string): string =
  ## Joins a dashboard path onto the public origin.
  if path.startsWith("http"):
    return path
  DashBase & path

proc loadJsonFile(path: string): JsonNode {.raises: [ExtractorError].} =
  ## Reads and parses a JSON file.
  try:
    result = parseJson(readFile(path))
  except CatchableError as error:
    raiseExtract("bad JSON " & path & ": " & error.msg)

proc fetchJson(
  client: HttpClient, url, path: string
): JsonNode {.raises: [ExtractorError].} =
  ## Downloads JSON to path and parses it.
  echo "fetch ", url
  let body = client.fetchBytes(url)
  saveBytes(path, body)
  try:
    result = parseJson(body)
  except CatchableError as error:
    raiseExtract("bad JSON from " & url & ": " & error.msg)

proc parseGameList(roundNode: JsonNode, roundNumber: int): seq[GameRef] =
  ## Reads game rows from a round JSON document.
  result = @[]
  let games = roundNode{"games"}
  if games.isNil or games.kind != JArray:
    return
  for game in games:
    var row = GameRef(
      roundNumber: roundNumber,
      gameNumber: game.intField("number"),
      episodeId: game.textField("id"),
      status: game.textField("status"),
      policies: game.textField("policies"),
      turns: game.intField("turns")
    )
    row.score = gameScore(row.policies)
    if row.gameNumber <= 0:
      continue
    if row.status.len > 0 and row.status != "completed":
      continue
    if row.score <= 0:
      continue
    row.localJson =
      EvidenceDir / "games" /
      "r" & $row.roundNumber & "-g" & $row.gameNumber & ".json"
    row.localReplay =
      EvidenceDir / "replays" /
      "r" & $row.roundNumber & "-g" & $row.gameNumber & ".moba"
    result.add row

proc pickGames(rows: seq[GameRef]): seq[GameRef] =
  ## Picks a small diverse set covering all three targets.
  var ranked = rows
  ranked.sort do (a, b: GameRef) -> int:
    result = cmp(b.score, a.score)
    if result == 0:
      result = cmp(a.roundNumber, b.roundNumber)
    if result == 0:
      result = cmp(a.gameNumber, b.gameNumber)
  var
    chosen: seq[GameRef]
    seen: seq[string]
    counts: array[3, int]
  proc addRow(row: GameRef) =
    if row.episodeId in seen:
      return
    if chosen.len >= MaxReplays:
      return
    chosen.add row
    seen.add row.episodeId
    for i, t in Targets:
      if t in row.policies:
        inc counts[i]
  for row in ranked:
    if targetsIn(row.policies).len >= 2:
      addRow(row)
  for i in 0 .. 2:
    for row in ranked:
      if counts[i] >= 3:
        break
      if Targets[i] in row.policies:
        addRow(row)
  for row in ranked:
    addRow(row)
  chosen

proc fillReplayUrl(
  client: HttpClient, row: var GameRef
) {.raises: [ExtractorError].} =
  ## Loads the game JSON twin and records replayDataUrl.
  let url = dashUrl(
    "/league/moba/rounds/" & $row.roundNumber & "/" &
    $row.gameNumber & ".json"
  )
  var node: JsonNode
  if fileExists(row.localJson):
    node = loadJsonFile(row.localJson)
  else:
    node = client.fetchJson(url, row.localJson)
  row.replayUrl = node.textField("replayDataUrl", "replay_url")
  if row.episodeId.len == 0:
    row.episodeId = node{"game"}.textField("id")
  if row.policies.len == 0:
    row.policies = node{"game"}.textField("policies")
  if row.turns == 0:
    row.turns = node{"game"}.intField("turns")

proc downloadReplay(
  client: HttpClient, row: GameRef
) {.raises: [ExtractorError].} =
  ## Downloads one replay body if missing.
  if replayExists(row.localReplay):
    echo "have ", row.localReplay
    return
  if row.replayUrl.len == 0:
    raiseExtract(
      "no replay URL for round " & $row.roundNumber &
      " game " & $row.gameNumber
    )
  echo "replay ", row.replayUrl
  let body = client.fetchBytes(row.replayUrl)
  if body.len < PrefixLen or body[0 .. 3] != Magic:
    raiseExtract(
      "replay for " & row.episodeId & " is not MOBA v1 (" &
      $body.len & " bytes)"
    )
  saveBytes(row.localReplay, body)
  echo "saved ", body.len, " bytes ", row.localReplay

proc seatPolicyMap(replay: Replay): seq[string] =
  ## Maps each pid to the seat's recorded player name.
  result = newSeq[string](NumHeroes)
  let
    names = replay.playerNames()
    perSeat = replay.heroesPerSeat()
  for pid in 0 ..< NumHeroes:
    let seat = pid div perSeat
    if seat < names.len:
      result[pid] = names[seat]

proc analyzeOne(row: GameRef): JsonNode {.raises: [ReplayError, ExtractorError].} =
  ## Parses one local replay and writes its tally JSON.
  var bytes: string
  try:
    bytes = readFile(row.localReplay)
  except CatchableError as error:
    raiseExtract("read " & row.localReplay & ": " & error.msg)
  let
    replay = parseReplay(bytes)
    tally = tallyReplay(replay)
    outPath = EvidenceDir / "summaries" /
      "r" & $row.roundNumber & "-g" & $row.gameNumber & ".json"
  var node = tallyJson(tally)
  node["round"] = %row.roundNumber
  node["game"] = %row.gameNumber
  node["episode_id"] = %row.episodeId
  node["dashboard_policies"] = %row.policies
  node["replay_path"] = %row.localReplay
  node["byte_length"] = %bytes.len
  var seats = newJArray()
  for label in seatPolicyMap(replay):
    seats.add %label
  node["pid_policies"] = seats
  saveBytes(outPath, pretty(node))
  echo "analyzed ", row.episodeId, " ticks=", tally.ticks,
    " winner=", tally.winner
  node

proc extraRoundNumbers(league: JsonNode): seq[int] =
  ## Recent completed round numbers besides 3730.
  result = @[]
  let rounds = league{"rounds"}
  if rounds.isNil or rounds.kind != JArray:
    return
  for row in rounds:
    if row.textField("status") != "completed":
      continue
    let number = row.intField("number")
    if number == 3730 or number <= 0:
      continue
    result.add number
    if result.len >= MaxExtraRounds:
      break

proc fetchAll(client: HttpClient): seq[GameRef] {.raises: [ExtractorError].} =
  ## Downloads league, round, game, and replay files.
  ensureDir(EvidenceDir)
  ensureDir(EvidenceDir / "rounds")
  ensureDir(EvidenceDir / "games")
  ensureDir(EvidenceDir / "replays")
  ensureDir(EvidenceDir / "summaries")
  let league = client.fetchJson(
    dashUrl(LeaguePath),
    EvidenceDir / "league-moba.json"
  )
  var rows = parseGameList(
    client.fetchJson(
      dashUrl(RoundPath),
      EvidenceDir / "rounds" / "3730.json"
    ),
    3730
  )
  for number in extraRoundNumbers(league):
    let path = EvidenceDir / "rounds" / $number & ".json"
    let node =
      if fileExists(path): loadJsonFile(path)
      else:
        client.fetchJson(
          dashUrl("/league/moba/rounds/" & $number & ".json"),
          path
        )
    rows.add parseGameList(node, number)
  result = pickGames(rows)
  echo "selected ", result.len, " games"
  for i, row in result.mpairs:
    fillReplayUrl(client, row)
    downloadReplay(client, row)
    result[i] = row

proc ratePct(value: float): string =
  ## Formats a 0..1 rate as a percentage string.
  formatFloat(value * 100.0, ffDecimal, 1) & "%"

proc writeRollup(
  nodes: seq[JsonNode], rows: seq[GameRef]
) {.raises: [ExtractorError].} =
  ## Writes the combined summary JSON.
  try:
    var
      root = newJObject()
      games = newJArray()
      byTarget = newJObject()
    root["generated_at"] = %format(
      getTime().utc,
      "yyyy-MM-dd'T'HH:mm:ss'Z'"
    )
    root["format"] = %"MOBA v1 actions-only"
    root["positions_recoverable"] = %false
    root["targets"] = %Targets
    for i, node in nodes:
      games.add node
      let policies = rows[i].policies
      for t in targetsIn(policies):
        if byTarget{t}.isNil or byTarget{t}.kind != JArray:
          byTarget[t] = newJArray()
        var brief = %*{
          "round": rows[i].roundNumber,
          "game": rows[i].gameNumber,
          "episode_id": rows[i].episodeId,
          "ticks": node{"ticks"}.getInt(),
          "winner": node{"winner"}.getStr(),
          "end_reason": node{"end_reason"}.getStr(),
          "policies": policies
        }
        byTarget[t].add brief
    root["games"] = games
    root["by_target"] = byTarget
    saveBytes(EvidenceDir / "summary.json", pretty(root))
    echo "wrote ", EvidenceDir / "summary.json"
  except ExtractorError as error:
    raise error
  except CatchableError as error:
    raiseExtract("rollup failed: " & error.msg)

proc printHeroLine(hero: JsonNode) =
  ## Prints one compact hero distribution line.
  echo "    pid ", hero{"pid"}.getInt(), " ",
    hero{"team"}.getStr(), " ",
    hero{"role"}.getStr(),
    " lane=", hero{"assigned_lane"}.getStr(),
    " dir=", hero{"primary_direction"}.getStr(),
    " vote=", hero{"primary_lane_vote"}.getStr(),
    " hold=", ratePct(hero{"hold_rate"}.getFloat()),
    " noop=", ratePct(hero{"noop_rate"}.getFloat()),
    " disc=", ratePct(hero{"discrete_vel_rate"}.getFloat()),
    " q=", ratePct(hero{"skill_q_rate"}.getFloat()),
    " w=", ratePct(hero{"skill_w_rate"}.getFloat()),
    " e=", ratePct(hero{"skill_e_rate"}.getFloat()),
    " tgt2=", ratePct(hero{"target_heroes_towers_rate"}.getFloat())

proc analyzeAll(rows: seq[GameRef]) {.raises: [ReplayError, ExtractorError].} =
  ## Analyzes every selected local replay.
  var nodes: seq[JsonNode]
  for row in rows:
    let node = analyzeOne(row)
    nodes.add node
    echo "  stack r=",
      formatFloat(node{"radiant_stack_cosine"}.getFloat(), ffDecimal, 3),
      " d=",
      formatFloat(node{"dire_stack_cosine"}.getFloat(), ffDecimal, 3),
      " holdTogether r=",
      formatFloat(node{"radiant_hold_together"}.getFloat(), ffDecimal, 3),
      " d=",
      formatFloat(node{"dire_hold_together"}.getFloat(), ffDecimal, 3)
    let heroes = node{"heroes"}
    if not heroes.isNil:
      for hero in heroes:
        printHeroLine(hero)
  writeRollup(nodes, rows)

proc main() =
  ## Fetches hosted replays and writes action tallies.
  let mode =
    if paramCount() >= 1: paramStr(1)
    else: "all"
  var rows: seq[GameRef]
  if mode in ["all", "fetch"]:
    let client = newClient()
    defer:
      client.close()
    rows = client.fetchAll()
  elif mode == "analyze":
    raiseExtract("analyze requires fetch first; use all")
  else:
    raiseExtract("Usage: extractors [all|fetch]")
  if mode in ["all", "analyze"]:
    analyzeAll(rows)

main()
