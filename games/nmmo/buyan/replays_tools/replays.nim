## NMMO hosted replay v1 parser and action-summary reports.
## Binary layout is magic NMMO, u8 version 1, u32le header length,
## UTF-8 header JSON, then tick-major post-clamp action bytes.

import
  std/[algorithm, intsets, json, strutils, tables]

const
  Magic = "NMMO"
  FormatVersion = 1'u8
  PrefixLen = 9
  ActionCount* = 26
  MaxAction = 25
  AttackAction = 5
  EvidenceLimitations* =
    "Replay bodies store post-clamp action ids only; observations are " &
    "not present. Inventory keys 8-16 can select a market entry or " &
    "price in buy/sell UI modes and can also attempt item use in play " &
    "mode. Action ids alone cannot establish a successful attack, " &
    "harvest, item use, market purchase or sale, traversal distance, " &
    "or score delta."

type
  NmmoReplayError* = object of CatchableError
  ActionGroup* = enum
    WalkGroup
    RunGroup
    AttackGroup
    NoopGroup
    InventoryKeysGroup
    BuyGroup
    SellGroup
    OtherGroup
  GroupStats* = object
    count*: int
    fraction*: float
    firstTick*: int
  AgentStats* = object
    index*: int
    tickCount*: int
    actionCounts*: array[ActionCount, int]
    groups*: array[ActionGroup, GroupStats]
    adjacentRepeatedAttackCount*: int
    attackBurstCount*: int
    longestAttackBurst*: int
    longestSameMovementActionRun*: int
  SeatStats* = object
    index*: int
    playerName*: string
    numAgents*: int
    tickCount*: int
    actionCounts*: array[ActionCount, int]
    groups*: array[ActionGroup, GroupStats]
    agents*: seq[AgentStats]
  Replay* = object
    header*: JsonNode
    body*: string
    numAgents*: int
    tickCount*: int
    heroesPerSeat*: int
  AgentLogStats* = object
    agent*: int
    activatedEventCount*: int
    distinctActivatedTicks*: int
  StrategyLogStats* = object
    strategy*: string
    eventCount*: int
    activatedEventCount*: int
    agents*: seq[AgentLogStats]
  LogSummary* = object
    lineCount*: int
    markerCount*: int
    activatedEventCount*: int
    strategies*: seq[StrategyLogStats]
  AgentAcc = object
    events: int
    ticks: IntSet
  StratAcc = object
    eventCount: int
    activatedEventCount: int
    agents: Table[int, AgentAcc]

const
  GroupKeys: array[ActionGroup, string] = [
    WalkGroup: "walk",
    RunGroup: "run",
    AttackGroup: "attack",
    NoopGroup: "noop",
    InventoryKeysGroup: "inventoryKeys",
    BuyGroup: "buy",
    SellGroup: "sell",
    OtherGroup: "other"
  ]
  GroupLabels: array[ActionGroup, string] = [
    WalkGroup: "walk 0-3",
    RunGroup: "run 22-25",
    AttackGroup: "attack 5 (attempt only; success is not in the body)",
    NoopGroup: "noop 4",
    InventoryKeysGroup:
      "inventory keys 8-16 (item use or market entry/price select)",
    BuyGroup: "buy 20 (opens buy UI; not a completed purchase)",
    SellGroup: "sell 21 (opens sell UI; not a completed sale)",
    OtherGroup: "other 6/7/17/18/19"
  ]

proc fail(message: string) {.noReturn, raises: [NmmoReplayError].} =
  ## Raise NmmoReplayError with a useful message.
  raise newException(NmmoReplayError, message)

proc readU32Le(data: string, offset: int): uint32 {.raises: [].} =
  ## Read a little-endian u32 at offset. Caller must bound-check.
  uint32(uint8(data[offset])) or
    (uint32(uint8(data[offset + 1])) shl 8) or
    (uint32(uint8(data[offset + 2])) shl 16) or
    (uint32(uint8(data[offset + 3])) shl 24)

proc parseHeaderJson(text: string): JsonNode {.raises: [NmmoReplayError].} =
  ## Parse header UTF-8 as JSON and map failures to NmmoReplayError.
  try:
    result = parseJson(text)
  except JsonParsingError as err:
    fail("header is not valid JSON: " & err.msg)
  except ValueError as err:
    fail("header is not valid JSON: " & err.msg)
  except IOError as err:
    fail("header is not valid JSON: " & err.msg)
  except OSError as err:
    fail("header is not valid JSON: " & err.msg)

proc requireObject(node: JsonNode, message: string): JsonNode
    {.raises: [NmmoReplayError].} =
  ## Return node when it is a JSON object, otherwise raise.
  if node.isNil or node.kind != JObject:
    fail(message)
  node

proc groupIds(group: ActionGroup): seq[int] {.raises: [].} =
  ## Return the action ids that belong to group.
  result =
    case group
    of WalkGroup:
      @[0, 1, 2, 3]
    of RunGroup:
      @[22, 23, 24, 25]
    of AttackGroup:
      @[5]
    of NoopGroup:
      @[4]
    of InventoryKeysGroup:
      @[8, 9, 10, 11, 12, 13, 14, 15, 16]
    of BuyGroup:
      @[20]
    of SellGroup:
      @[21]
    of OtherGroup:
      @[6, 7, 17, 18, 19]

proc classifyAction(action: int): ActionGroup {.raises: [].} =
  ## Map one 26-way action id onto a named report group.
  case action
  of 0 .. 3:
    WalkGroup
  of 4:
    NoopGroup
  of 5:
    AttackGroup
  of 8 .. 16:
    InventoryKeysGroup
  of 20:
    BuyGroup
  of 21:
    SellGroup
  of 22 .. 25:
    RunGroup
  else:
    OtherGroup

proc isMovementAction(action: int): bool {.raises: [].} =
  ## Return true for walk ids 0-3 or run ids 22-25.
  action in 0 .. 3 or action in 22 .. 25

proc parseReplay*(data: string): Replay {.raises: [NmmoReplayError].} =
  ## Parse and validate NMMO v1 binary replay bytes.
  if data.len < PrefixLen:
    fail("replay too short (" & $data.len & " bytes)")
  if data[0 .. 3] != Magic:
    fail("bad magic, expected NMMO")
  if uint8(data[4]) != FormatVersion:
    fail("unsupported format version " & $uint8(data[4]) & ", expected 1")
  let headerLen = int(readU32Le(data, 5))
  if PrefixLen + headerLen > data.len:
    fail("header extends past end of file")
  let header = parseHeaderJson(data[PrefixLen ..< PrefixLen + headerLen])
  if header.kind != JObject:
    fail("header is not a JSON object")
  let tickNode = header{"tick_count"}
  if tickNode.isNil or tickNode.kind != JInt:
    fail("header missing integer tick_count")
  let tickCount = tickNode.getInt
  if tickCount < 0:
    fail("header tick_count must be a non-negative integer")
  let config = requireObject(header{"config"}, "header missing config object")
  let players = config{"players"}
  let heroesNode = config{"heroes_per_seat"}
  if players.isNil or players.kind != JArray or players.len < 1 or
      heroesNode.isNil or heroesNode.kind != JInt or heroesNode.getInt < 1:
    fail("header config must carry a non-empty players array and a " &
      "positive integer heroes_per_seat (they set the body stride)")
  let heroes = heroesNode.getInt
  for i in 0 ..< players.len:
    let player = players[i]
    if player.isNil or player.kind != JObject:
      fail("header config players[" & $i & "] must be an object")
    let name = player{"name"}
    if name.isNil or name.kind != JString or name.getStr.len < 1:
      fail("header config players[" & $i &
        "] must have a nonempty string name")
  discard requireObject(header{"result"}, "header missing result object")
  let sha = header{"sim_wasm_sha256"}
  if sha.isNil or sha.kind != JString:
    fail("header missing sim_wasm_sha256 string")
  if players.len > high(int) div heroes:
    fail("players.len * heroes_per_seat overflows")
  let numAgents = players.len * heroes
  let body = data[PrefixLen + headerLen .. ^1]
  if numAgents > 0 and tickCount > high(int) div numAgents:
    fail("tick_count * num_agents overflows")
  let expected = tickCount * numAgents
  if body.len != expected:
    fail("body is " & $body.len & " bytes, expected " & $expected &
      " (" & $tickCount & " ticks x " & $numAgents & " agents)")
  for i in 0 ..< body.len:
    let act = int(uint8(body[i]))
    if act > MaxAction:
      let tick = i div numAgents
      let agent = i mod numAgents
      fail("action " & $act & " at tick " & $tick & " agent " & $agent &
        " out of range 0.." & $MaxAction)
  result.header = header
  result.body = body
  result.numAgents = numAgents
  result.tickCount = tickCount
  result.heroesPerSeat = heroes

proc loadReplay*(path: string): Replay {.raises: [NmmoReplayError].} =
  ## Read a path from disk and parse it as an NMMO v1 replay.
  var data: string
  try:
    data = readFile(path)
  except IOError as err:
    fail("cannot read " & path & ": " & err.msg)
  except OSError as err:
    fail("cannot read " & path & ": " & err.msg)
  parseReplay(data)

proc action*(replay: Replay, tick, agent: int): int
    {.raises: [NmmoReplayError].} =
  ## Return the post-clamp action id at tick-major (tick, agent).
  if tick < 0 or tick >= replay.tickCount or
      agent < 0 or agent >= replay.numAgents:
    fail("tick/agent out of range")
  int(uint8(replay.body[tick * replay.numAgents + agent]))

proc makeGroups(
    counts: array[ActionCount, int],
    first: array[ActionGroup, int],
    denom: int
): array[ActionGroup, GroupStats] {.raises: [].} =
  ## Build named group counts, fractions, and first-activation ticks.
  for g in ActionGroup:
    var n = 0
    for id in groupIds(g):
      n += counts[id]
    result[g].count = n
    if denom > 0:
      result[g].fraction = n.float / denom.float
    result[g].firstTick = first[g]

proc analyzeAgent(replay: Replay, agent: int): AgentStats
    {.raises: [NmmoReplayError].} =
  ## Count actions and streaks for one agent timeline; never crosses agents.
  result.index = agent
  result.tickCount = replay.tickCount
  var
    first: array[ActionGroup, int]
    prevAttack = false
    attackRun = 0
    moveRun = 0
    moveId = -1
  for g in ActionGroup:
    first[g] = -1
  for tick in 0 ..< replay.tickCount:
    let act = action(replay, tick, agent)
    inc result.actionCounts[act]
    let g = classifyAction(act)
    if first[g] < 0:
      first[g] = tick
    if act == AttackAction:
      if prevAttack:
        inc result.adjacentRepeatedAttackCount
        inc attackRun
      else:
        inc result.attackBurstCount
        attackRun = 1
      prevAttack = true
      if attackRun > result.longestAttackBurst:
        result.longestAttackBurst = attackRun
    else:
      prevAttack = false
      attackRun = 0
    if isMovementAction(act):
      if act == moveId:
        inc moveRun
      else:
        moveId = act
        moveRun = 1
      if moveRun > result.longestSameMovementActionRun:
        result.longestSameMovementActionRun = moveRun
    else:
      moveId = -1
      moveRun = 0
  result.groups = makeGroups(result.actionCounts, first, replay.tickCount)

proc playerName(replay: Replay, seat: int): string {.raises: [].} =
  ## Read config.players[seat].name, or empty when the field is missing.
  let players = replay.header{"config"}{"players"}
  if players.isNil or players.kind != JArray or seat < 0 or
      seat >= players.len:
    return ""
  let node = players[seat]
  if node.kind == JObject:
    result = node{"name"}.getStr

proc summarize*(replay: Replay): seq[SeatStats]
    {.raises: [NmmoReplayError].} =
  ## Build per-seat reports with nested per-agent streak stats.
  let players = replay.header{"config"}{"players"}
  let numSeats = players.len
  let heroes = replay.heroesPerSeat
  for seat in 0 ..< numSeats:
    var row: SeatStats
    row.index = seat
    row.playerName = playerName(replay, seat)
    row.numAgents = heroes
    row.tickCount = replay.tickCount
    var first: array[ActionGroup, int]
    for g in ActionGroup:
      first[g] = -1
    for j in 0 ..< heroes:
      let stats = analyzeAgent(replay, seat * heroes + j)
      row.agents.add stats
      for i in 0 ..< ActionCount:
        row.actionCounts[i] += stats.actionCounts[i]
      for g in ActionGroup:
        let t = stats.groups[g].firstTick
        if t >= 0 and (first[g] < 0 or t < first[g]):
          first[g] = t
    let denom = replay.tickCount * heroes
    row.groups = makeGroups(row.actionCounts, first, denom)
    result.add row

proc countsJson(counts: array[ActionCount, int]): JsonNode {.raises: [].} =
  ## Encode 26 action counts as a JSON array.
  result = newJArray()
  for c in counts:
    result.add %c

proc fractionsJson(counts: array[ActionCount, int], denom: int): JsonNode
    {.raises: [].} =
  ## Encode 26 action fractions against denom, or zeros when denom is 0.
  result = newJArray()
  for c in counts:
    if denom <= 0:
      result.add %0.0
    else:
      result.add %(c.float / denom.float)

proc firstTickNode(value: int): JsonNode {.raises: [].} =
  ## Encode a first-activation tick, or null when the group never fired.
  if value < 0: newJNull() else: %value

proc groupsJson(groups: array[ActionGroup, GroupStats]): JsonNode
    {.raises: [].} =
  ## Encode named action groups with ids, labels, counts, and first ticks.
  result = newJObject()
  for g in ActionGroup:
    var node = newJObject()
    var ids = newJArray()
    for id in groupIds(g):
      ids.add %id
    node["ids"] = ids
    node["label"] = %GroupLabels[g]
    node["count"] = %groups[g].count
    node["fraction"] = %groups[g].fraction
    node["firstTick"] = firstTickNode(groups[g].firstTick)
    result[GroupKeys[g]] = node

proc agentJson(stats: AgentStats): JsonNode {.raises: [].} =
  ## Encode one agent's counts and per-agent streak fields.
  result = newJObject()
  result["index"] = %stats.index
  result["tickCount"] = %stats.tickCount
  result["actionCounts"] = countsJson(stats.actionCounts)
  result["actionFractions"] = fractionsJson(
    stats.actionCounts, stats.tickCount)
  result["groups"] = groupsJson(stats.groups)
  result["adjacentRepeatedAttackCount"] = %stats.adjacentRepeatedAttackCount
  result["attackBurstCount"] = %stats.attackBurstCount
  result["longestAttackBurst"] = %stats.longestAttackBurst
  result["longestSameMovementActionRun"] =
    %stats.longestSameMovementActionRun

proc seatJson(seat: SeatStats): JsonNode {.raises: [].} =
  ## Encode one seat, with streak fields nested per agent so they cannot bridge.
  result = newJObject()
  result["index"] = %seat.index
  result["playerName"] = %seat.playerName
  result["numAgents"] = %seat.numAgents
  result["tickCount"] = %seat.tickCount
  result["actionCounts"] = countsJson(seat.actionCounts)
  result["actionFractions"] = fractionsJson(
    seat.actionCounts, seat.tickCount * seat.numAgents)
  result["groups"] = groupsJson(seat.groups)
  var agents = newJArray()
  var adjacentSum = 0
  var burstSum = 0
  var longestBurst = 0
  var longestMove = 0
  for agent in seat.agents:
    agents.add agentJson(agent)
    adjacentSum += agent.adjacentRepeatedAttackCount
    burstSum += agent.attackBurstCount
    if agent.longestAttackBurst > longestBurst:
      longestBurst = agent.longestAttackBurst
    if agent.longestSameMovementActionRun > longestMove:
      longestMove = agent.longestSameMovementActionRun
  result["agents"] = agents
  result["adjacentRepeatedAttackCount"] = %adjacentSum
  result["attackBurstCount"] = %burstSum
  result["longestAttackBurst"] = %longestBurst
  result["longestSameMovementActionRun"] = %longestMove
  result["attackStreaksArePerAgent"] = %true

proc reportJson*(replay: Replay, path = ""): JsonNode
    {.raises: [NmmoReplayError].} =
  ## Build the JSON summary for one parsed replay, preserving header result.
  let seats = summarize(replay)
  result = newJObject()
  result["path"] = %path
  result["formatVersion"] = %1
  result["simWasmSha256"] = replay.header{"sim_wasm_sha256"}
  result["tickCount"] = %replay.tickCount
  result["numAgents"] = %replay.numAgents
  result["heroesPerSeat"] = %replay.heroesPerSeat
  result["numSeats"] = %seats.len
  result["observationsAvailable"] = %false
  result["evidenceLimitations"] = %EvidenceLimitations
  result["result"] = replay.header{"result"}
  var seatNodes = newJArray()
  for seat in seats:
    seatNodes.add seatJson(seat)
  result["seats"] = seatNodes

proc parseLogs*(text: string): LogSummary {.raises: [NmmoReplayError].} =
  ## Parse JSONL strategy markers with strategy, activated, optional tick/agent.
  var strategies = initOrderedTable[string, StratAcc]()
  var lineNo = 0
  for line in text.splitLines:
    inc lineNo
    inc result.lineCount
    let trimmed = strip(line)
    if trimmed.len == 0:
      continue
    var node: JsonNode
    try:
      node = parseJson(trimmed)
    except JsonParsingError as err:
      fail("log line " & $lineNo & " is not valid JSON: " & err.msg)
    except ValueError as err:
      fail("log line " & $lineNo & " is not valid JSON: " & err.msg)
    except IOError as err:
      fail("log line " & $lineNo & " is not valid JSON: " & err.msg)
    except OSError as err:
      fail("log line " & $lineNo & " is not valid JSON: " & err.msg)
    if node.kind != JObject:
      continue
    let
      stratNode = node{"strategy"}
      actNode = node{"activated"}
    if stratNode.isNil or stratNode.kind != JString or
        actNode.isNil or actNode.kind != JBool:
      continue
    inc result.markerCount
    let name = stratNode.getStr
    var acc = strategies.getOrDefault(name)
    inc acc.eventCount
    if actNode.getBool:
      inc result.activatedEventCount
      inc acc.activatedEventCount
      var agent = -1
      let agentNode = node{"agent"}
      if not agentNode.isNil and agentNode.kind == JInt:
        agent = agentNode.getInt
      var agentAcc = acc.agents.getOrDefault(agent)
      inc agentAcc.events
      let tickNode = node{"tick"}
      if not tickNode.isNil and tickNode.kind == JInt:
        agentAcc.ticks.incl tickNode.getInt
      acc.agents[agent] = agentAcc
    strategies[name] = acc
  for name, acc in strategies:
    var row: StrategyLogStats
    row.strategy = name
    row.eventCount = acc.eventCount
    row.activatedEventCount = acc.activatedEventCount
    var agentIds: seq[int]
    for agent, _ in acc.agents:
      agentIds.add agent
    agentIds.sort()
    for agent in agentIds:
      let agentAcc = acc.agents.getOrDefault(agent)
      row.agents.add AgentLogStats(
        agent: agent,
        activatedEventCount: agentAcc.events,
        distinctActivatedTicks: agentAcc.ticks.len)
    result.strategies.add row

proc parseLogFile*(path: string): LogSummary {.raises: [NmmoReplayError].} =
  ## Read a JSONL log file and summarize explicit strategy markers.
  var text: string
  try:
    text = readFile(path)
  except IOError as err:
    fail("cannot read " & path & ": " & err.msg)
  except OSError as err:
    fail("cannot read " & path & ": " & err.msg)
  parseLogs(text)

proc logReportJson*(summary: LogSummary, path = ""): JsonNode {.raises: [].} =
  ## Encode a log marker summary as JSON.
  result = newJObject()
  result["path"] = %path
  result["lineCount"] = %summary.lineCount
  result["markerCount"] = %summary.markerCount
  result["activatedEventCount"] = %summary.activatedEventCount
  var rows = newJArray()
  for strat in summary.strategies:
    var node = newJObject()
    node["strategy"] = %strat.strategy
    node["eventCount"] = %strat.eventCount
    node["activatedEventCount"] = %strat.activatedEventCount
    var agents = newJArray()
    for agent in strat.agents:
      var a = newJObject()
      a["agent"] = %agent.agent
      a["activatedEventCount"] = %agent.activatedEventCount
      a["distinctActivatedTicks"] = %agent.distinctActivatedTicks
      agents.add a
    node["agents"] = agents
    rows.add node
  result["strategies"] = rows
