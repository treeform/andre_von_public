## Heuristic policy for the Domovoy solver — the cogtan analogue of
## terra/policy.nim. One proc picks the "plan" move (the improved
## scripted-baseline line: city > settlement > road-toward-pips > dev,
## leader-seeking robber, protected discards, knight timing), used three
## ways: as the rollout bias inside playouts, as the protect-gate plan
## the MCTS choice must clearly beat, and as the instant fallback when
## the Fischer clock is too thin to search.

import nodes

type
  PolicyReason* = enum
    PolicyNone,
    PolicySetup,
    PolicyRoll,
    PolicyDiscard,
    PolicyRobber,
    PolicyCity,
    PolicySettlement,
    PolicyRoad,
    PolicyDev,
    PolicyKnight,
    PolicyProgress,
    PolicyTrade,
    PolicyRespond,
    PolicyEnd

  BasePolicyChoice* = object
    ok*: bool
    move*: Move
    reason*: PolicyReason

proc robberOnOurHex(state: GameState, seat: int): bool =
  for i in 0 .. 5:
    if int(state.buildingSeat[board.hexVertices[state.robber][i]]) == seat:
      return true
  false

proc bestRobberMove*(state: GameState, seat: int): Move =
  ## Leader-seeking: hexes scored by (opponent pips, weighted by their
  ## public VP lead), never our own hexes, rob the richest victim.
  var bestScore = low(int)
  result = Move(kind: RobberMove, a: int8(-1), b: int8(NoSeat))
  var anyVictims = false
  for h in 0 ..< NumHexes:
    if h == int(state.robber):
      continue
    if state.robberVictimMask(h, seat) != 0:
      anyVictims = true
      break
  for h in 0 ..< NumHexes:
    if h == int(state.robber):
      continue
    let mask = state.robberVictimMask(h, seat)
    if anyVictims and mask == 0:
      continue
    let hexPips = pips(int(state.hexToken[h]))
    var score = 0
    var ownHere = false
    for i in 0 .. 5:
      let owner = int(state.buildingSeat[board.hexVertices[h][i]])
      if owner == seat:
        ownHere = true
      elif owner >= 0:
        # Blocking the leader is worth more than blocking a straggler.
        score += hexPips * (2 + state.publicVp(owner))
    if ownHere:
      score -= 10_000
    if score > bestScore:
      bestScore = score
      var victim = NoSeat
      var richest = -1
      for candidate in 0 ..< int(state.playerCount):
        if (mask and (1 shl candidate)) != 0 and
            state.handSize(candidate) > richest:
          victim = candidate
          richest = state.handSize(candidate)
      result = Move(kind: RobberMove, a: int8(h), b: int8(victim))

proc bestByPips(state: GameState, kind: MoveKind,
    vertices: openArray[int]): Move =
  var best = vertices[0]
  for v in vertices:
    if state.vertexPips(v) > state.vertexPips(best):
      best = v
  Move(kind: kind, a: int8(best))

proc mainPolicyChoice(state: GameState, seat: int): BasePolicyChoice =
  let hand = state.hands[seat]
  result.ok = true
  if canAfford(hand, CityCost) and state.citiesBuilt(seat) < MaxCities:
    var cities: seq[int]
    for v in 0 ..< NumVertices:
      if int(state.buildingSeat[v]) == seat and not state.buildingCity[v]:
        cities.add(v)
    if cities.len > 0:
      result.move = state.bestByPips(BuildCityMove, cities)
      result.reason = PolicyCity
      return
  var spots: seq[int]
  if state.settlementsBuilt(seat) < MaxSettlements:
    for v in 0 ..< NumVertices:
      if state.legalSettlementVertex(seat, v):
        spots.add(v)
  if canAfford(hand, SettlementCost) and spots.len > 0:
    result.move = state.bestByPips(BuildSettlementMove, spots)
    result.reason = PolicySettlement
    return
  if canAfford(hand, RoadCost) and spots.len == 0 and
      state.roadsBuilt(seat) < MaxRoads:
    var bestEdge = -1
    var bestScore = -1
    for e in 0 ..< NumEdges:
      if state.legalRoadEdge(seat, e):
        var score = 0
        for endpoint in [int(board.edgeA[e]), int(board.edgeB[e])]:
          if state.distanceRuleOk(endpoint):
            score = max(score, 1 + state.vertexPips(endpoint))
        if score > bestScore:
          bestEdge = e
          bestScore = score
    if bestEdge >= 0:
      result.move = Move(kind: BuildRoadMove, a: int8(bestEdge))
      result.reason = PolicyRoad
      return
  # Play a knight mid-turn when the robber squats on our production.
  if state.robberOnOurHex(seat) and not state.devPlayedThisTurn:
    var holds = false
    for i in 0 ..< int(state.devHandLen[seat]):
      if state.devHandCards[seat][i].card == Knight and
          state.devHandCards[seat][i].bought < state.rolls:
        holds = true
    if holds:
      result.move = Move(kind: PlayKnightMove)
      result.reason = PolicyKnight
      return
  if state.devDeckLen > 0 and canAfford(hand, DevCardCost):
    result.move = Move(kind: BuyDevMove)
    result.reason = PolicyDev
    return
  for give in Resource:
    let rate = state.tradeRate(seat, give)
    if int(hand[give]) >= rate + 1:
      var receive = Brick
      for resource in Resource:
        if resource != give and hand[resource] < hand[receive]:
          receive = resource
      if receive != give and state.bank[receive] > 0:
        result.move = Move(kind: BankTradeMove, a: int8(ord(give)),
          b: int8(ord(receive)))
        result.reason = PolicyTrade
        return
  result.move = Move(kind: EndTurnMove)
  result.reason = PolicyEnd

proc policyChoice*(state: GameState, seat: int): BasePolicyChoice =
  case state.phase
  of SetupPhase:
    var best = -1
    var bestPips = -1
    for v in 0 ..< NumVertices:
      if not state.distanceRuleOk(v):
        continue
      if state.bestSetupEdge(v) < 0:
        continue
      let vp = state.vertexPips(v)
      if vp > bestPips:
        best = v
        bestPips = vp
    if best >= 0:
      result.ok = true
      result.move = Move(kind: SetupMove, a: int8(best),
        b: int8(state.bestSetupEdge(best)))
      result.reason = PolicySetup
  of PrerollPhase:
    # Knight before the roll when the robber blocks us (frees production
    # this very roll and chases Largest Army).
    if state.robberOnOurHex(seat) and not state.devPlayedThisTurn:
      for i in 0 ..< int(state.devHandLen[seat]):
        if state.devHandCards[seat][i].card == Knight and
            state.devHandCards[seat][i].bought < state.rolls:
          result.ok = true
          result.move = Move(kind: PlayKnightMove)
          result.reason = PolicyKnight
          return
    result.ok = true
    result.move = Move(kind: RollMove)
    result.reason = PolicyRoll
  of DiscardPhase:
    var give: array[3, Bundle]
    let count = state.discardCandidates(seat, give)
    if count > 0:
      # The candidates are ordered plain-greedy first, then the guarded
      # variants; prefer the last (most protective) one that exists.
      result.ok = true
      result.move = Move(kind: DiscardMove, give: give[count - 1])
      result.reason = PolicyDiscard
  of RobberPhase:
    let move = state.bestRobberMove(seat)
    if move.a >= 0:
      result.ok = true
      result.move = move
      result.reason = PolicyRobber
  of MainPhase:
    result = state.mainPolicyChoice(seat)
  of TradePhase:
    let gain = bundleSize(state.pendingGive) -
      bundleSize(state.pendingReceive)
    let accept = gain > 0 and
      canAfford(state.hands[seat], state.pendingReceive)
    result.ok = true
    result.move = Move(kind: RespondTradeMove,
      a: if accept: 1'i8 else: 0'i8)
    result.reason = PolicyRespond
  of Finished:
    discard

proc findInOptions(options: MoveBuffer, move: Move): int =
  let key = move.moveKey()
  for i in 0 ..< options.len:
    if options.moves[i].moveKey() == key:
      return i
  -1

const
  SelfRolloutPolicyPct* = 85
  OpponentRolloutPolicyPct* = 65

proc biasedPlayoutMove*(state: GameState, options: MoveBuffer,
    perspective: int, rng: var Rng): Move =
  ## Rollout move: mostly the policy line (heavier for our own seat),
  ## otherwise uniform over the steered legal set.
  let mover = state.playerToMove()
  let pct =
    if mover == perspective: SelfRolloutPolicyPct
    else: OpponentRolloutPolicyPct
  if rng.randInt(100) < pct:
    let choice = state.policyChoice(mover)
    if choice.ok:
      let idx = options.findInOptions(choice.move)
      if idx >= 0:
        return options.moves[idx]
  options.moves[rng.randInt(options.len)]
