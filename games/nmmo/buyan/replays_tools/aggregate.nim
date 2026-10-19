## Observational summary of extract JSONL action reports, grouped by player.

import
  std/[json, os, sequtils, sets, strutils, tables]

type
  AggregateError* = object of CatchableError
  PlayerRow = object
    name: string
    originalNames: seq[string]
    seatEpisodes: int
    totalTicks: int
    actionCounts: array[26, int]
    walk, run, attack, noop, inventory, buy, sell, other: int
    attackBursts, longestAttack, longestMove, deaths: int

proc fail(message: string) {.noReturn.} =
  ## Raise AggregateError with a useful message.
  raise newException(AggregateError, message)

proc requireInt(node: JsonNode, label: string): int =
  ## Return a non-negative JSON integer or reject the record.
  if node.isNil or node.kind != JInt:
    fail(label & " must be a non-negative integer")
  result = node.getInt
  if result < 0:
    fail(label & " is negative")

proc baseName(name: string): string =
  ## Strip only a trailing space-plus-(digits) duplicate suffix such as ` (2)`.
  result = name
  if name.len < 4 or name[^1] != ')':
    return
  var i = name.len - 2
  if i < 0 or name[i] notin {'0' .. '9'}:
    return
  while i >= 0 and name[i] in {'0' .. '9'}:
    dec i
  if i >= 1 and name[i] == '(' and name[i - 1] == ' ':
    result = name[0 ..< i - 1]

proc groupCount(seat: JsonNode, key: string): int =
  ## Read one named action-group count from a seat report.
  requireInt(seat{"groups"}{key}{"count"}, key & " count")

proc addName(row: var PlayerRow, name: string) =
  ## Keep each original seat name once for attribution.
  if not row.originalNames.contains(name):
    row.originalNames.add name

proc ingestSeat(row: var PlayerRow, report, seat: JsonNode) =
  ## Add one seat's ticks, actions, bursts, and hosted agent_stats deaths.
  let
    name = seat{"playerName"}
    counts = seat{"actionCounts"}
    stats = report{"result"}{"agent_stats"}
  if name.isNil or name.kind != JString or name.getStr.len < 1:
    fail("seat playerName must be a nonempty string")
  if counts.isNil or counts.kind != JArray or counts.len != 26:
    fail("seat actionCounts must have 26 integers")
  if stats.isNil or stats.kind != JArray:
    fail("result.agent_stats must be an array")
  let
    tickCount = requireInt(seat{"tickCount"}, "tickCount")
    numAgents = requireInt(seat{"numAgents"}, "numAgents")
    index = requireInt(seat{"index"}, "seat index")
  if numAgents > 0 and tickCount > high(int) div numAgents:
    fail("tickCount * numAgents overflows")
  addName(row, name.getStr)
  inc row.seatEpisodes
  row.totalTicks += tickCount * numAgents
  for i in 0 ..< 26:
    row.actionCounts[i] += requireInt(counts[i], "actionCounts")
  row.walk += groupCount(seat, "walk")
  row.run += groupCount(seat, "run")
  row.attack += groupCount(seat, "attack")
  row.noop += groupCount(seat, "noop")
  row.inventory += groupCount(seat, "inventoryKeys")
  row.buy += groupCount(seat, "buy")
  row.sell += groupCount(seat, "sell")
  row.other += groupCount(seat, "other")
  row.attackBursts += requireInt(seat{"attackBurstCount"}, "attackBurstCount")
  let
    burst = requireInt(seat{"longestAttackBurst"}, "longestAttackBurst")
    move = requireInt(
      seat{"longestSameMovementActionRun"}, "longestSameMovementActionRun")
  if burst > row.longestAttack:
    row.longestAttack = burst
  if move > row.longestMove:
    row.longestMove = move
  for j in 0 ..< numAgents:
    let pid = index * numAgents + j
    if pid < 0 or pid >= stats.len:
      fail("agent_stats missing index " & $pid)
    row.deaths += requireInt(stats[pid]{"deaths"}, "agent_stats.deaths")

proc pct(n, d: int): string =
  ## Format n/d as a percent with one decimal place.
  if d <= 0: "0.0" else: formatFloat(100.0 * n.float / d.float, ffDecimal, 1)

proc frac(n, d: int): float =
  ## Return n/d, or 0 when there are no ticks.
  if d <= 0: 0.0 else: n.float / d.float

proc rowJson(row: PlayerRow): JsonNode =
  ## Encode one grouped player as a JSON object.
  result = %*{
    "name": row.name,
    "originalNames": row.originalNames,
    "seatEpisodes": row.seatEpisodes,
    "totalTicks": row.totalTicks,
    "actionCounts": row.actionCounts.toSeq,
    "attackBurstCount": row.attackBursts,
    "longestAttackBurst": row.longestAttack,
    "longestSameMovementActionRun": row.longestMove,
    "deaths": row.deaths
  }
  result["groups"] = %*{
    "walk": {"count": row.walk, "fraction": frac(row.walk, row.totalTicks)},
    "run": {"count": row.run, "fraction": frac(row.run, row.totalTicks)},
    "attack": {"count": row.attack, "fraction": frac(row.attack, row.totalTicks)},
    "noop": {"count": row.noop, "fraction": frac(row.noop, row.totalTicks)},
    "inventoryKeys": {
      "count": row.inventory, "fraction": frac(row.inventory, row.totalTicks)
    },
    "buy": {"count": row.buy, "fraction": frac(row.buy, row.totalTicks)},
    "sell": {"count": row.sell, "fraction": frac(row.sell, row.totalTicks)},
    "other": {"count": row.other, "fraction": frac(row.other, row.totalTicks)}
  }

proc main() =
  ## Print a Markdown table and JSON detail for extract JSONL paths.
  if paramCount() < 1:
    fail("usage: aggregate FILE.jsonl ...")
  var
    paths = initHashSet[string]()
    hashes = initHashSet[string]()
    players = initOrderedTable[string, PlayerRow]()
    replayCount = 0
  for filePath in commandLineParams():
    var text: string
    try:
      text = readFile(filePath)
    except CatchableError as err:
      fail("cannot read " & filePath & ": " & err.msg)
    var lineNo = 0
    for line in text.splitLines:
      inc lineNo
      let trimmed = strip(line)
      if trimmed.len == 0:
        continue
      var report: JsonNode
      try:
        report = parseJson(trimmed)
      except CatchableError as err:
        fail(filePath & ":" & $lineNo & " JSON: " & err.msg)
      if report.kind != JObject:
        fail(filePath & ":" & $lineNo & " must be a JSON object")
      let
        path = report{"path"}
        sha = report{"simWasmSha256"}
        seats = report{"seats"}
      if path.isNil or path.kind != JString or path.getStr.len < 1:
        fail(filePath & ":" & $lineNo & " missing path")
      if path.getStr in paths:
        fail("repeated replay path " & path.getStr)
      paths.incl path.getStr
      if sha.isNil or sha.kind != JString:
        fail(filePath & ":" & $lineNo & " missing simWasmSha256")
      hashes.incl sha.getStr
      if seats.isNil or seats.kind != JArray:
        fail(filePath & ":" & $lineNo & " missing seats array")
      inc replayCount
      for seat in seats:
        if seat.kind != JObject:
          fail("seat must be an object")
        let key = baseName(seat{"playerName"}.getStr)
        var row = players.getOrDefault(key)
        row.name = key
        ingestSeat(row, report, seat)
        players[key] = row
  echo "| name | seats | run% | walk% | noop% | attack% | inv% | buy+sell% | deaths |"
  echo "|---|---:|---:|---:|---:|---:|---:|---:|---:|"
  var detail = newJArray()
  for _, row in players:
    let d = row.totalTicks
    echo "| ", row.name, " | ", row.seatEpisodes, " | ",
      pct(row.run, d), " | ", pct(row.walk, d), " | ", pct(row.noop, d), " | ",
      pct(row.attack, d), " | ", pct(row.inventory, d), " | ",
      pct(row.buy + row.sell, d), " | ", row.deaths, " |"
    detail.add rowJson(row)
  echo %*{
    "inputReplays": replayCount,
    "distinctSimHashes": hashes.len,
    "players": detail
  }

main()
