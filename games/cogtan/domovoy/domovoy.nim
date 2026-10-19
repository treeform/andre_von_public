## Domovoy — Cogtan policy for Andre von Auto.
## Command player on the cogweb.player.v1 wire, now built like the terra
## Agricogla champion: catan/nodes.nim simulates the full engine
## (ported 1:1 from Metta-AI/metta packages/cogweb/games/cogtan
## src/engine.ts + rules.ts + game.ts), catan/policy.nim is the improved
## scripted-baseline heuristic, and this file runs a root-parallel,
## time-budgeted MCTS over determinized hidden information (opponent dev
## cards + deck order + future dice are sampled per worker) with protect
## gates: the searched move must clearly beat the heuristic plan or the
## plan is kept. The Fischer chess clock (5s initial + 5s per own
## setup/preroll decision, off-turn decisions drain the bank) is tracked
## locally; thin banks answer straight from the heuristic.
##
## Env knobs: DOMOVOY_SOLVER_ENABLED (default on), DOMOVOY_SOLVER_TIME_MS
## (per-decision cap), DOMOVOY_SOLVER_ITERATIONS, DOMOVOY_SOLVER_THREADS,
## DOMOVOY_RESERVE_MS (clock safety floor).

import
  std/[json, math, monotimes, os, strutils, threadpool, times],
  coworld_client,
  catan/nodes,
  catan/policy,
  catan/solver

const
  DefaultReserveMs = 1_200.0
  InitialBankMs = 5_000.0
  TurnCreditMs = 5_000.0

let resourceNames: array[Resource, string] = [
  "brick", "lumber", "ore", "grain", "wool"]

## View parsing -> solver Observation

proc parseResource(name: string): int =
  for resource in Resource:
    if resourceNames[resource] == name:
      return ord(resource)
  -1

proc parseBundle(node: JsonNode): Bundle =
  if node == nil or node.kind != JObject:
    return
  for resource in Resource:
    result[resource] = int16(node{resourceNames[resource]}.getInt(0))

proc parsePhase(name: string): Phase =
  case name
  of "setup": SetupPhase
  of "preroll": PrerollPhase
  of "discard": DiscardPhase
  of "robber": RobberPhase
  of "main": MainPhase
  of "trade": TradePhase
  else: Finished

proc parseObservation(message: JsonNode, mySlot: int): Observation =
  let view = message{"view"}
  if view == nil or view.kind != JObject:
    return
  result.you = message{"seat"}.getInt(mySlot)
  var state: GameState
  state.playerCount = int8(view{"playerCount"}.getInt(4))
  let hexes = view{"hexes"}
  if hexes != nil and hexes.kind == JArray:
    for h in 0 ..< min(NumHexes, hexes.len):
      state.hexToken[h] = int8(hexes[h]{"token"}.getInt(0))
      state.hexResource[h] = case hexes[h]{"terrain"}.getStr()
        of "hills": int8(ord(Brick))
        of "forest": int8(ord(Lumber))
        of "mountains": int8(ord(Ore))
        of "fields": int8(ord(Grain))
        of "pasture": int8(ord(Wool))
        else: int8(-1)
  let ports = view{"ports"}
  if ports != nil and ports.kind == JArray:
    for p in 0 ..< min(NumPorts, ports.len):
      state.portEdge[p] = int8(ports[p]{"edge"}.getInt(0))
      let kind = ports[p]{"kind"}.getStr()
      let resource = parseResource(kind)
      state.portKind[p] = if resource >= 0: PortKind(resource) else: PortAny
  state.robber = int8(view{"robber"}.getInt(0))
  for v in 0 ..< NumVertices:
    state.buildingSeat[v] = int8(NoSeat)
  let buildings = view{"buildings"}
  if buildings != nil and buildings.kind == JArray:
    for v in 0 ..< min(NumVertices, buildings.len):
      if buildings[v] != nil and buildings[v].kind == JObject:
        state.buildingSeat[v] = int8(buildings[v]{"seat"}.getInt(NoSeat))
        state.buildingCity[v] = buildings[v]{"city"}.getBool(false)
  for e in 0 ..< NumEdges:
    state.roads[e] = int8(NoSeat)
  let roads = view{"roads"}
  if roads != nil and roads.kind == JArray:
    for e in 0 ..< min(NumEdges, roads.len):
      if roads[e].kind == JInt:
        state.roads[e] = int8(roads[e].getInt())
  let hands = view{"hands"}
  if hands != nil and hands.kind == JArray:
    for seat in 0 ..< min(int(state.playerCount), hands.len):
      state.hands[seat] = parseBundle(hands[seat])
  state.bank = parseBundle(view{"bank"})
  state.devDeckLen = int8(view{"devDeckCount"}.getInt(0))
  let devCounts = view{"devCounts"}
  if devCounts != nil and devCounts.kind == JArray:
    for seat in 0 ..< min(int(state.playerCount), devCounts.len):
      result.devCounts[seat] = devCounts[seat].getInt(0)
  let devHands = view{"devHands"}
  if devHands != nil and devHands.kind == JArray and
      result.you < devHands.len:
    let own = devHands[result.you]
    if own != nil and own.kind == JArray:
      for card in own:
        let kind = case card{"card"}.getStr()
          of "knight": Knight
          of "roadBuilding": RoadBuilding
          of "yearOfPlenty": YearOfPlenty
          of "monopoly": Monopoly
          else: VictoryPoint
        state.devHandCards[result.you][state.devHandLen[result.you]] =
          DevCardInHand(card: kind, bought: int16(card{"bought"}.getInt(0)))
        inc state.devHandLen[result.you]
  let knights = view{"playedKnights"}
  if knights != nil and knights.kind == JArray:
    for seat in 0 ..< min(int(state.playerCount), knights.len):
      state.playedKnights[seat] = int8(knights[seat].getInt(0))
  state.largestArmy = int8(view{"largestArmy"}.getInt(NoSeat))
  state.longestRoad = int8(view{"longestRoad"}.getInt(NoSeat))
  state.first = int8(view{"first"}.getInt(0))
  state.current = int8(view{"current"}.getInt(result.you))
  state.phase = parsePhase(view{"phase"}.getStr())
  state.setupIdx = int8(view{"setupIdx"}.getInt(0))
  state.rolls = int16(view{"rolls"}.getInt(0))
  state.devPlayedThisTurn = view{"devPlayedThisTurn"}.getBool(false)
  let queue = view{"discardQueue"}
  if queue != nil and queue.kind == JArray:
    for entry in queue:
      if state.discardQueueLen < int8(MaxSeats):
        state.discardQueue[state.discardQueueLen] = int8(entry.getInt(0))
        inc state.discardQueueLen
  state.phaseAfterRobber = parsePhase(
    view{"phaseAfterRobber"}.getStr("main"))
  state.pendingFrom = int8(NoSeat)
  state.pendingTo = int8(NoSeat)
  let trade = view{"pendingTrade"}
  if trade != nil and trade.kind == JObject:
    state.pendingFrom = int8(trade{"from"}.getInt(NoSeat))
    state.pendingTo = int8(trade{"to"}.getInt(NoSeat))
    state.pendingGive = parseBundle(trade{"give"})
    state.pendingReceive = parseBundle(trade{"receive"})
  state.tradeOffersThisTurn = int8(view{"tradeOffersThisTurn"}.getInt(0))
  state.winner = int8(NoSeat)
  result.state = state
  result.parsedOk = state.playerCount > 0

## Move -> wire decision

proc bundleJson(hand: Bundle): JsonNode =
  result = newJObject()
  for resource in Resource:
    result[resourceNames[resource]] = %int(hand[resource])

proc decisionJson(move: Move): JsonNode =
  case move.kind
  of SetupMove:
    %*{"kind": "setup", "vertex": int(move.a), "edge": int(move.b)}
  of RollMove:
    %*{"kind": "roll"}
  of DiscardMove:
    %*{"kind": "discard", "give": bundleJson(move.give)}
  of RobberMove:
    if move.b >= 0:
      %*{"kind": "robber", "hex": int(move.a), "victim": int(move.b)}
    else:
      %*{"kind": "robber", "hex": int(move.a), "victim": newJNull()}
  of BuildRoadMove:
    %*{"kind": "buildRoad", "edge": int(move.a)}
  of BuildSettlementMove:
    %*{"kind": "buildSettlement", "vertex": int(move.a)}
  of BuildCityMove:
    %*{"kind": "buildCity", "vertex": int(move.a)}
  of BuyDevMove:
    %*{"kind": "buyDev"}
  of PlayKnightMove:
    %*{"kind": "playKnight"}
  of PlayRoadBuildingMove:
    if move.b >= 0:
      %*{"kind": "playRoadBuilding", "edges": [int(move.a), int(move.b)]}
    else:
      %*{"kind": "playRoadBuilding", "edges": [int(move.a)]}
  of PlayYearOfPlentyMove:
    %*{"kind": "playYearOfPlenty",
       "take": [resourceNames[Resource(move.a)],
                resourceNames[Resource(move.b)]]}
  of PlayMonopolyMove:
    %*{"kind": "playMonopoly", "resource": resourceNames[Resource(move.a)]}
  of BankTradeMove:
    %*{"kind": "bankTrade", "give": resourceNames[Resource(move.a)],
       "receive": resourceNames[Resource(move.b)]}
  of RespondTradeMove:
    %*{"kind": "respondTrade", "accept": move.a == 1}
  of EndTurnMove:
    %*{"kind": "endTurn"}

proc conservativeDecision(observation: Observation): JsonNode =
  ## Re-request fallback: the most conservative always-legal move.
  let state = observation.state
  case state.phase
  of SetupPhase:
    for v in 0 ..< NumVertices:
      if state.distanceRuleOk(v) and state.bestSetupEdge(v) >= 0:
        return %*{"kind": "setup", "vertex": v,
          "edge": state.bestSetupEdge(v)}
    %*{"kind": "setup", "vertex": 0, "edge": 0}
  of PrerollPhase:
    %*{"kind": "roll"}
  of DiscardPhase:
    var give: array[3, Bundle]
    let count = state.discardCandidates(observation.you, give)
    if count > 0:
      %*{"kind": "discard", "give": bundleJson(give[0])}
    else:
      %*{"kind": "discard", "give": bundleJson(default(Bundle))}
  of RobberPhase:
    decisionJson(state.bestRobberMove(observation.you))
  of MainPhase:
    %*{"kind": "endTurn"}
  of TradePhase:
    %*{"kind": "respondTrade", "accept": false}
  of Finished:
    %*{"kind": "endTurn"}

## Fischer clock bookkeeping + per-decision budget

type Clock = object
  bankMs: float
  reserveMs: float
  capMs: float
  lastCreditRolls: int
  creditedSetup: int

proc initClock(): Clock =
  result.bankMs = InitialBankMs
  result.reserveMs = DefaultReserveMs
  result.capMs = 0
  result.lastCreditRolls = -1
  result.creditedSetup = -1
  let reserve = getEnv("DOMOVOY_RESERVE_MS")
  if reserve.len > 0:
    try:
      result.reserveMs = float(parseInt(reserve))
    except ValueError:
      discard
  let cap = getEnv("DOMOVOY_SOLVER_TIME_MS")
  if cap.len > 0:
    try:
      result.capMs = float(parseInt(cap))
    except ValueError:
      discard

proc credit(clock: var Clock, observation: Observation) =
  ## +5s at each of our setup placements and each of our prerolls (the
  ## host credits per decision in those phases); dedupe the repeated
  ## preroll observation after a pre-roll knight by the roll serial.
  let state = observation.state
  if state.phase == SetupPhase:
    if int(state.setupIdx) != clock.creditedSetup:
      clock.creditedSetup = int(state.setupIdx)
      clock.bankMs += TurnCreditMs
  elif state.phase == PrerollPhase:
    if int(state.rolls) != clock.lastCreditRolls:
      clock.lastCreditRolls = int(state.rolls)
      clock.bankMs += TurnCreditMs

proc budgetMs(clock: Clock, observation: Observation): int =
  let state = observation.state
  let available = clock.bankMs - clock.reserveMs
  if available <= float(MinSearchMs):
    return 0
  var budget = case state.phase
    of SetupPhase: min(available * 0.8, 3_500.0)
    of RobberPhase: min(available * 0.5, 2_000.0)
    of MainPhase: min(available * 0.5, 2_500.0)
    of PrerollPhase:
      # Search the preroll only when a dev-card decision exists.
      min(available * 0.4, 1_500.0)
    of DiscardPhase: min(available * 0.25, 800.0)
    of TradePhase: min(available * 0.25, 600.0)
    else: 0.0
  if clock.capMs > 0:
    budget = min(budget, clock.capMs)
  int(budget)

proc main() =
  let client = newCoworldClient("domovoy")
  var mySlot = -1
  var clock = initClock()
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      mySlot = message{"slot"}.getInt(-1)
      echo "domovoy: seated slot ", mySlot,
        " protocol ", message{"protocol"}.getStr()
    of "observation":
      let started = getMonoTime()
      let id = message{"id"}
      let reason = message{"reason"}.getStr("")
      let observation = message.parseObservation(mySlot)
      var decision: JsonNode
      if not observation.parsedOk:
        decision = %*{"kind": "endTurn"}
      elif reason.len > 0:
        echo "domovoy: re-request (", reason, "), playing conservative"
        decision = observation.conservativeDecision()
      else:
        clock.credit(observation)
        var budget = clock.budgetMs(observation)
        # An instant roll when there is no dev card worth considering.
        if observation.state.phase == PrerollPhase:
          var buffer: MoveBuffer
          observation.state.legalMoves(buffer)
          if buffer.len <= 1:
            budget = 0
        try:
          if budget >= MinSearchMs:
            decision = decisionJson(observation.chooseMove(budget))
          else:
            let plan = observation.state.policyChoice(observation.you)
            decision =
              if plan.ok: decisionJson(plan.move)
              else: observation.conservativeDecision()
        except CatchableError as e:
          echo "domovoy: solver error (", e.msg, "), using heuristic"
          let plan = observation.state.policyChoice(observation.you)
          decision =
            if plan.ok: decisionJson(plan.move)
            else: observation.conservativeDecision()
      client.send(%*{"type": "reply", "id": id, "decision": decision})
      let spentMs = float(inMilliseconds(getMonoTime() - started))
      clock.bankMs = max(0.0, clock.bankMs - spentMs)
      if observation.parsedOk and reason.len == 0:
        echo "domovoy: phase=", observation.state.phase,
          " spentMs=", int(spentMs), " bankMs=", int(clock.bankMs),
          " decision=", decision{"kind"}.getStr()
    of "final":
      echo "domovoy: final, scores ", message{"scores"}
      quit(0)
    else:
      discard # The wire is additive: unknown types are skipped.

main()
