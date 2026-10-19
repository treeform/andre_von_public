## Pure CATAN simulator for the Domovoy solver — the cogtan analogue of
## terra/nodes.nim (the Agricogla champion's game model). Ports the
## deployed engine exactly (Metta-AI/metta packages/cogweb/games/cogtan
## src/engine.ts + rules.ts + game.ts): the two-round setup snake, roll →
## production with the bank-shortage rule, discard queue + robber, builds,
## development cards, bank trades, longest road / largest army transfer
## semantics, the 180-roll cap, and win-on-your-own-turn. Chance (dice,
## robber steals, dev draws) flows through the Rng embedded in GameState,
## so each solver worker is one determinization of the hidden information.

import std/hashes

when defined(release):
  {.push checks: off.}

const
  NumHexes* = 19
  NumVertices* = 54
  NumEdges* = 72
  NumPorts* = 9
  MaxSeats* = 4
  WinVp* = 10
  MaxRolls* = 180
  DiscardThreshold* = 7
  LongestRoadMin* = 5
  LargestArmyMin* = 3
  MaxRoads* = 15
  MaxSettlements* = 5
  MaxCities* = 4
  BankPerResource* = 19
  MaxTradeOffersPerTurn* = 3
  DevDeckSize* = 25
  MaxLegalMoves* = 128
  NoSeat* = -1

type
  SolverError* = object of CatchableError

  Resource* = enum
    Brick, Lumber, Ore, Grain, Wool

  Bundle* = array[Resource, int16]

  DevCard* = enum
    Knight, RoadBuilding, YearOfPlenty, Monopoly, VictoryPoint

  Phase* = enum
    SetupPhase, PrerollPhase, DiscardPhase, RobberPhase, MainPhase,
    TradePhase, Finished

  PortKind* = enum
    PortBrick, PortLumber, PortOre, PortGrain, PortWool, PortAny

  MoveKind* = enum
    SetupMove, RollMove, DiscardMove, RobberMove, BuildRoadMove,
    BuildSettlementMove, BuildCityMove, BuyDevMove, PlayKnightMove,
    PlayRoadBuildingMove, PlayYearOfPlentyMove, PlayMonopolyMove,
    BankTradeMove, RespondTradeMove, EndTurnMove

  Move* = object
    kind*: MoveKind
    ## SetupMove: a=vertex b=edge. RobberMove: a=hex b=victim(-1 none).
    ## Build*: a=vertex/edge. PlayRoadBuilding: a,b=edges (b=-1 single).
    ## PlayYearOfPlenty: a,b=resources. PlayMonopoly/BankTrade: a=give
    ## b=receive. RespondTrade: a=1 accept / 0 decline.
    a*: int8
    b*: int8
    give*: Bundle ## DiscardMove only.

  MoveBuffer* = object
    len*: int
    moves*: array[MaxLegalMoves, Move]

  Rng* = object
    state: uint64

  DevCardInHand* = object
    card*: DevCard
    bought*: int16 ## roll serial; playable only when bought < rolls

  GameState* = object
    playerCount*: int8
    hexToken*: array[NumHexes, int8]      ## 0 on the desert
    hexResource*: array[NumHexes, int8]   ## -1 desert, else Resource.ord
    portEdge*: array[NumPorts, int8]
    portKind*: array[NumPorts, PortKind]
    robber*: int8
    buildingSeat*: array[NumVertices, int8] ## -1 empty
    buildingCity*: array[NumVertices, bool]
    roads*: array[NumEdges, int8]           ## -1 empty
    hands*: array[MaxSeats, Bundle]
    bank*: Bundle
    devDeck*: array[DevDeckSize, DevCard]   ## drawn from devDeckLen-1 down
    devDeckLen*: int8
    devHandCards*: array[MaxSeats, array[DevDeckSize, DevCardInHand]]
    devHandLen*: array[MaxSeats, int8]
    playedKnights*: array[MaxSeats, int8]
    largestArmy*: int8 ## -1 none
    longestRoad*: int8 ## -1 none
    first*: int8
    current*: int8
    phase*: Phase
    setupIdx*: int8
    rolls*: int16
    devPlayedThisTurn*: bool
    discardQueue*: array[MaxSeats, int8]
    discardQueueLen*: int8
    phaseAfterRobber*: Phase
    pendingFrom*, pendingTo*: int8
    pendingGive*, pendingReceive*: Bundle
    tradeOffersThisTurn*: int8
    winner*: int8
    finalVp*: array[MaxSeats, int16]
    rng*: Rng

## Rng — splitmix64; embedded in the state so every chance event in one
## worker's tree is a fixed determinization of that worker's seed.

proc initRng*(seed: int): Rng =
  result.state = uint64(seed) xor 0x9E3779B97F4A7C15'u64

proc nextU64(rng: var Rng): uint64 =
  rng.state = rng.state + 0x9E3779B97F4A7C15'u64
  var z = rng.state
  z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9'u64
  z = (z xor (z shr 27)) * 0x94D049BB133111EB'u64
  z xor (z shr 31)

proc randInt*(rng: var Rng, limit: int): int =
  if limit <= 1:
    return 0
  int(rng.nextU64() mod uint64(limit))

## Board geometry — identical construction to the engine's src/board.ts
## (and the original domovoy port), so wire vertex/edge/hex ids line up
## by construction.

type
  Board* = object
    vertexHexes*: array[NumVertices, array[3, int8]]
    vertexHexLen*: array[NumVertices, int8]
    vertexEdges*: array[NumVertices, array[3, int8]]
    vertexEdgeLen*: array[NumVertices, int8]
    vertexAdj*: array[NumVertices, array[3, int8]]
    vertexAdjLen*: array[NumVertices, int8]
    edgeA*, edgeB*: array[NumEdges, int8]
    hexVertices*: array[NumHexes, array[6, int8]]

proc buildBoard(): Board =
  const cornerOffsets = [(0, -2), (1, -1), (1, 1), (0, 2), (-1, 1), (-1, -1)]
  const directions = [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)]
  var centers: seq[tuple[x, y: int]]
  centers.add((0, 0))
  for radius in 1 .. 2:
    var q = directions[4][0] * radius
    var r = directions[4][1] * radius
    for side in 0 .. 5:
      for step in 0 ..< radius:
        centers.add((2 * q + r, 3 * r))
        q += directions[side][0]
        r += directions[side][1]
  var
    vertexKeys: seq[tuple[x, y: int]]
    vertexCount = 0
    edgeKeys: seq[tuple[a, b: int]]
    edgeCount = 0
  for hexId, center in centers:
    var corners: array[6, int]
    for i in 0 .. 5:
      let key = (center.x + cornerOffsets[i][0],
        center.y + cornerOffsets[i][1])
      var id = -1
      for j, k in vertexKeys:
        if k == key:
          id = j
          break
      if id < 0:
        id = vertexCount
        vertexKeys.add(key)
        inc vertexCount
      corners[i] = id
      result.hexVertices[hexId][i] = int8(id)
      let slot = result.vertexHexLen[id]
      result.vertexHexes[id][slot] = int8(hexId)
      inc result.vertexHexLen[id]
    for i in 0 .. 5:
      let v1 = corners[i]
      let v2 = corners[(i + 1) mod 6]
      let key = (a: min(v1, v2), b: max(v1, v2))
      var known = false
      for k in edgeKeys:
        if k == key:
          known = true
          break
      if not known:
        edgeKeys.add(key)
        result.edgeA[edgeCount] = int8(key.a)
        result.edgeB[edgeCount] = int8(key.b)
        inc edgeCount
  doAssert vertexCount == NumVertices
  doAssert edgeCount == NumEdges
  for e in 0 ..< NumEdges:
    let a = int(result.edgeA[e])
    let b = int(result.edgeB[e])
    result.vertexEdges[a][result.vertexEdgeLen[a]] = int8(e)
    inc result.vertexEdgeLen[a]
    result.vertexEdges[b][result.vertexEdgeLen[b]] = int8(e)
    inc result.vertexEdgeLen[b]
    result.vertexAdj[a][result.vertexAdjLen[a]] = int8(b)
    inc result.vertexAdjLen[a]
    result.vertexAdj[b][result.vertexAdjLen[b]] = int8(a)
    inc result.vertexAdjLen[b]

let board* = buildBoard()

## Costs and bundles

proc bundle(brick, lumber, ore, grain, wool: int16): Bundle =
  result[Brick] = brick
  result[Lumber] = lumber
  result[Ore] = ore
  result[Grain] = grain
  result[Wool] = wool

const
  RoadCost* = bundle(1, 1, 0, 0, 0)
  SettlementCost* = bundle(1, 1, 0, 1, 1)
  CityCost* = bundle(0, 0, 3, 2, 0)
  DevCardCost* = bundle(0, 0, 1, 1, 1)

proc bundleSize*(hand: Bundle): int =
  for resource in Resource:
    result += int(hand[resource])

proc canAfford*(hand, cost: Bundle): bool =
  for resource in Resource:
    if hand[resource] < cost[resource]:
      return false
  true

proc addBundle(hand: var Bundle, other: Bundle, sign: int16) =
  for resource in Resource:
    hand[resource] += sign * other[resource]

## Board queries (rules.ts)

proc pips*(token: int): int =
  if token == 0: 0 else: 6 - abs(7 - token)

proc vertexPips*(state: GameState, vertex: int): int =
  for i in 0 ..< board.vertexHexLen[vertex]:
    result += pips(int(state.hexToken[board.vertexHexes[vertex][i]]))

proc roadsBuilt*(state: GameState, seat: int): int =
  for e in 0 ..< NumEdges:
    if int(state.roads[e]) == seat:
      inc result

proc settlementsBuilt*(state: GameState, seat: int): int =
  for v in 0 ..< NumVertices:
    if int(state.buildingSeat[v]) == seat and not state.buildingCity[v]:
      inc result

proc citiesBuilt*(state: GameState, seat: int): int =
  for v in 0 ..< NumVertices:
    if int(state.buildingSeat[v]) == seat and state.buildingCity[v]:
      inc result

proc distanceRuleOk*(state: GameState, vertex: int): bool =
  if state.buildingSeat[vertex] >= 0:
    return false
  for i in 0 ..< board.vertexAdjLen[vertex]:
    if state.buildingSeat[board.vertexAdj[vertex][i]] >= 0:
      return false
  true

proc connectsForRoad(state: GameState, seat, vertex: int): bool =
  let owner = int(state.buildingSeat[vertex])
  if owner == seat:
    return true
  if owner >= 0:
    return false
  for i in 0 ..< board.vertexEdgeLen[vertex]:
    if int(state.roads[board.vertexEdges[vertex][i]]) == seat:
      return true
  false

proc legalRoadEdge*(state: GameState, seat, edge: int): bool =
  state.roads[edge] < 0 and
    (state.connectsForRoad(seat, int(board.edgeA[edge])) or
     state.connectsForRoad(seat, int(board.edgeB[edge])))

proc legalSettlementVertex*(state: GameState, seat, vertex: int): bool =
  if not state.distanceRuleOk(vertex):
    return false
  for i in 0 ..< board.vertexEdgeLen[vertex]:
    if int(state.roads[board.vertexEdges[vertex][i]]) == seat:
      return true
  false

proc ownsPort*(state: GameState, seat: int, kind: PortKind): bool =
  for p in 0 ..< NumPorts:
    if state.portKind[p] != kind:
      continue
    let edge = int(state.portEdge[p])
    if int(state.buildingSeat[board.edgeA[edge]]) == seat or
        int(state.buildingSeat[board.edgeB[edge]]) == seat:
      return true
  false

proc tradeRate*(state: GameState, seat: int, resource: Resource): int =
  if state.ownsPort(seat, PortKind(ord(resource))): 2
  elif state.ownsPort(seat, PortAny): 3
  else: 4

proc mustDiscard*(handSize: int): int =
  if handSize > DiscardThreshold: handSize div 2 else: 0

proc handSize*(state: GameState, seat: int): int =
  bundleSize(state.hands[seat])

proc robberVictimMask*(state: GameState, hex, mover: int): int =
  ## Bitmask of seats robbable on `hex` (adjacent building + a card).
  for i in 0 .. 5:
    let owner = int(state.buildingSeat[board.hexVertices[hex][i]])
    if owner >= 0 and owner != mover and state.handSize(owner) > 0:
      result = result or (1 shl owner)

proc longestRoadLength*(state: GameState, seat: int): int =
  ## Longest continuous single branch; may END at an opponent's building
  ## but never continue through one. Exact port of rules.ts.
  var owned: array[MaxRoads, int8]
  var ownedLen = 0
  for e in 0 ..< NumEdges:
    if int(state.roads[e]) == seat:
      owned[ownedLen] = int8(e)
      inc ownedLen
  if ownedLen == 0:
    return 0
  var used: array[NumEdges, bool]

  proc blocked(state: GameState, seat, vertex: int): bool =
    let owner = int(state.buildingSeat[vertex])
    owner >= 0 and owner != seat

  proc extend(state: GameState, used: var array[NumEdges, bool],
      seat, vertex: int): int =
    if blocked(state, seat, vertex):
      return 0
    for i in 0 ..< board.vertexEdgeLen[vertex]:
      let e = int(board.vertexEdges[vertex][i])
      if int(state.roads[e]) != seat or used[e]:
        continue
      used[e] = true
      let other =
        if int(board.edgeA[e]) == vertex: int(board.edgeB[e])
        else: int(board.edgeA[e])
      result = max(result, 1 + extend(state, used, seat, other))
      used[e] = false

  var startSeen: array[NumVertices, bool]
  for i in 0 ..< ownedLen:
    let e = int(owned[i])
    for vertex in [int(board.edgeA[e]), int(board.edgeB[e])]:
      if startSeen[vertex]:
        continue
      startSeen[vertex] = true
      # A run may START at a blocked vertex (the building caps one end).
      for j in 0 ..< board.vertexEdgeLen[vertex]:
        let se = int(board.vertexEdges[vertex][j])
        if int(state.roads[se]) != seat:
          continue
        used[se] = true
        let other =
          if int(board.edgeA[se]) == vertex: int(board.edgeB[se])
          else: int(board.edgeA[se])
        result = max(result, 1 + extend(state, used, seat, other))
        used[se] = false

proc publicVp*(state: GameState, seat: int): int =
  result = state.settlementsBuilt(seat) + 2 * state.citiesBuilt(seat)
  if int(state.longestRoad) == seat:
    result += 2
  if int(state.largestArmy) == seat:
    result += 2

proc trueVp*(state: GameState, seat: int): int =
  result = state.publicVp(seat)
  for i in 0 ..< state.devHandLen[seat]:
    if state.devHandCards[seat][i].card == VictoryPoint:
      inc result

proc largestArmyHolderAfter(state: GameState, seat: int): int =
  let count = int(state.playedKnights[seat])
  if count < LargestArmyMin:
    return int(state.largestArmy)
  let holder = int(state.largestArmy)
  if holder == NoSeat or holder == seat:
    return seat
  if count > int(state.playedKnights[holder]): seat else: holder

proc longestRoadHolderAfter(state: GameState): int =
  var lengths: array[MaxSeats, int]
  var maxLen = 0
  for seat in 0 ..< int(state.playerCount):
    lengths[seat] = state.longestRoadLength(seat)
    maxLen = max(maxLen, lengths[seat])
  if maxLen < LongestRoadMin:
    return NoSeat
  let holder = int(state.longestRoad)
  if holder != NoSeat and lengths[holder] >= LongestRoadMin and
      lengths[holder] >= maxLen:
    return holder
  var leader = NoSeat
  var leaders = 0
  for seat in 0 ..< int(state.playerCount):
    if lengths[seat] == maxLen:
      leader = seat
      inc leaders
  if leaders == 1: leader else: NoSeat

## Mutating transitions (engine.ts)

proc updateLongestRoad(state: var GameState) =
  state.longestRoad = int8(state.longestRoadHolderAfter())

proc finishGame(state: var GameState) =
  state.phase = Finished
  var winner = int(state.first)
  for seat in 0 ..< int(state.playerCount):
    state.finalVp[seat] = int16(state.trueVp(seat))
  for k in 0 ..< int(state.playerCount):
    let seat = (int(state.first) + k) mod int(state.playerCount)
    if state.finalVp[seat] > state.finalVp[winner]:
      winner = seat
  state.winner = int8(winner)

proc checkWin(state: var GameState): bool =
  if state.phase == Finished:
    return true
  if state.trueVp(int(state.current)) >= WinVp:
    state.finishGame()
    return true
  false

proc pay(state: var GameState, seat: int, cost: Bundle) =
  state.hands[seat].addBundle(cost, -1)
  state.bank.addBundle(cost, 1)

proc setupSeatAt(state: GameState, idx: int): int =
  let n = int(state.playerCount)
  let offset = if idx < n: idx else: 2 * n - 1 - idx
  (int(state.first) + offset) mod n

proc applySetup(state: var GameState, vertex, edge: int) =
  let seat = int(state.current)
  state.buildingSeat[vertex] = int8(seat)
  state.roads[edge] = int8(seat)
  if int(state.setupIdx) >= int(state.playerCount):
    for i in 0 ..< board.vertexHexLen[vertex]:
      let hex = board.vertexHexes[vertex][i]
      let resource = int(state.hexResource[hex])
      if resource < 0:
        continue
      state.hands[seat][Resource(resource)] += 1
      state.bank[Resource(resource)] -= 1
  inc state.setupIdx
  if int(state.setupIdx) >= 2 * int(state.playerCount):
    state.phase = PrerollPhase
    state.current = state.first
  else:
    state.current = int8(state.setupSeatAt(int(state.setupIdx)))

proc applyRollWith*(state: var GameState, d1, d2: int) =
  ## Parity hook: the roll transition with the dice injected, so a test
  ## can replay a TypeScript-engine trajectory byte-for-byte.
  let roll = d1 + d2
  inc state.rolls
  if roll == 7:
    state.discardQueueLen = 0
    for k in 0 ..< int(state.playerCount):
      let who = (int(state.current) + k) mod int(state.playerCount)
      if mustDiscard(state.handSize(who)) > 0:
        state.discardQueue[state.discardQueueLen] = int8(who)
        inc state.discardQueueLen
    state.phaseAfterRobber = MainPhase
    state.phase = if state.discardQueueLen > 0: DiscardPhase else: RobberPhase
    return
  # Production with the bank-shortage rule: a short resource pays nobody
  # unless exactly one player is owed (they take what remains).
  var owed: array[MaxSeats, Bundle]
  for h in 0 ..< NumHexes:
    if int(state.hexToken[h]) != roll or h == int(state.robber):
      continue
    let resource = int(state.hexResource[h])
    if resource < 0:
      continue
    for i in 0 .. 5:
      let vertex = int(board.hexVertices[h][i])
      let seat = int(state.buildingSeat[vertex])
      if seat < 0:
        continue
      owed[seat][Resource(resource)] +=
        (if state.buildingCity[vertex]: 2'i16 else: 1'i16)
  for resource in Resource:
    var total = 0'i16
    var entitled = 0
    var lone = 0
    for seat in 0 ..< int(state.playerCount):
      if owed[seat][resource] > 0:
        total += owed[seat][resource]
        inc entitled
        lone = seat
    if entitled == 0:
      continue
    if state.bank[resource] >= total:
      for seat in 0 ..< int(state.playerCount):
        state.hands[seat][resource] += owed[seat][resource]
      state.bank[resource] -= total
    elif entitled == 1:
      state.hands[lone][resource] += state.bank[resource]
      state.bank[resource] = 0
  state.phase = MainPhase

proc applyRoll(state: var GameState) =
  state.applyRollWith(state.rng.randInt(6) + 1, state.rng.randInt(6) + 1)

proc applyDiscard(state: var GameState, give: Bundle) =
  let seat = int(state.discardQueue[0])
  state.hands[seat].addBundle(give, -1)
  state.bank.addBundle(give, 1)
  for i in 1 ..< int(state.discardQueueLen):
    state.discardQueue[i - 1] = state.discardQueue[i]
  dec state.discardQueueLen
  if state.discardQueueLen == 0:
    state.phase = RobberPhase

proc applyRobberWith*(state: var GameState, hex, victim, stealIdx: int) =
  ## Parity hook: the robber transition with the stolen-card index
  ## injected (the engine draws idx in [0, victim hand size)).
  let seat = int(state.current)
  state.robber = int8(hex)
  if victim >= 0:
    var acc = 0
    for resource in Resource:
      acc += int(state.hands[victim][resource])
      if stealIdx < acc:
        state.hands[victim][resource] -= 1
        state.hands[seat][resource] += 1
        break
  state.phase = state.phaseAfterRobber
  discard state.checkWin()

proc applyRobber(state: var GameState, hex, victim: int) =
  let stealIdx =
    if victim >= 0: state.rng.randInt(state.handSize(victim)) else: 0
  state.applyRobberWith(hex, victim, stealIdx)

proc applyBuildRoad(state: var GameState, edge: int) =
  state.pay(int(state.current), RoadCost)
  state.roads[edge] = state.current
  state.updateLongestRoad()
  discard state.checkWin()

proc applyBuildSettlement(state: var GameState, vertex: int) =
  state.pay(int(state.current), SettlementCost)
  state.buildingSeat[vertex] = state.current
  state.buildingCity[vertex] = false
  # A new settlement can break an opponent's continuous road.
  state.updateLongestRoad()
  discard state.checkWin()

proc applyBuildCity(state: var GameState, vertex: int) =
  state.pay(int(state.current), CityCost)
  state.buildingCity[vertex] = true
  discard state.checkWin()

proc applyBuyDev(state: var GameState) =
  let seat = int(state.current)
  state.pay(seat, DevCardCost)
  dec state.devDeckLen
  let card = state.devDeck[state.devDeckLen]
  state.devHandCards[seat][state.devHandLen[seat]] =
    DevCardInHand(card: card, bought: state.rolls)
  inc state.devHandLen[seat]
  # A Victory Point card may win the moment it is drawn.
  discard state.checkWin()

proc spendDevCard(state: var GameState, seat: int, card: DevCard): bool =
  if state.devPlayedThisTurn:
    return false
  for i in 0 ..< int(state.devHandLen[seat]):
    if state.devHandCards[seat][i].card == card and
        state.devHandCards[seat][i].bought < state.rolls:
      for j in i + 1 ..< int(state.devHandLen[seat]):
        state.devHandCards[seat][j - 1] = state.devHandCards[seat][j]
      dec state.devHandLen[seat]
      state.devPlayedThisTurn = true
      return true
  false

proc applyPlayKnight(state: var GameState) =
  let seat = int(state.current)
  if not state.spendDevCard(seat, Knight):
    raise newException(SolverError, "No playable knight.")
  inc state.playedKnights[seat]
  state.largestArmy = int8(state.largestArmyHolderAfter(seat))
  if state.checkWin():
    return
  state.phaseAfterRobber = state.phase
  state.phase = RobberPhase

proc applyPlayRoadBuilding(state: var GameState, edgeA, edgeB: int) =
  let seat = int(state.current)
  if not state.spendDevCard(seat, RoadBuilding):
    raise newException(SolverError, "No playable road building.")
  if state.legalRoadEdge(seat, edgeA):
    state.roads[edgeA] = int8(seat)
  if edgeB >= 0 and state.legalRoadEdge(seat, edgeB):
    state.roads[edgeB] = int8(seat)
  state.updateLongestRoad()
  discard state.checkWin()

proc applyPlayYearOfPlenty(state: var GameState, first, second: int) =
  let seat = int(state.current)
  if not state.spendDevCard(seat, YearOfPlenty):
    raise newException(SolverError, "No playable year of plenty.")
  for resource in [Resource(first), Resource(second)]:
    if state.bank[resource] > 0:
      state.bank[resource] -= 1
      state.hands[seat][resource] += 1

proc applyPlayMonopoly(state: var GameState, resource: int) =
  let seat = int(state.current)
  if not state.spendDevCard(seat, Monopoly):
    raise newException(SolverError, "No playable monopoly.")
  for who in 0 ..< int(state.playerCount):
    if who == seat:
      continue
    state.hands[seat][Resource(resource)] +=
      state.hands[who][Resource(resource)]
    state.hands[who][Resource(resource)] = 0

proc applyBankTrade(state: var GameState, give, receive: int) =
  let seat = int(state.current)
  let rate = int16(state.tradeRate(seat, Resource(give)))
  state.hands[seat][Resource(give)] -= rate
  state.bank[Resource(give)] += rate
  state.bank[Resource(receive)] -= 1
  state.hands[seat][Resource(receive)] += 1

proc applyOfferTrade*(state: var GameState, to: int,
    give, receive: Bundle) =
  ## Not generated by the solver's move set (we never offer), but part of
  ## the engine contract: applied when replaying/observing others' offers.
  state.pendingFrom = state.current
  state.pendingTo = int8(to)
  state.pendingGive = give
  state.pendingReceive = receive
  inc state.tradeOffersThisTurn
  state.phase = TradePhase

proc applyRespondTrade(state: var GameState, accept: bool) =
  let offerFrom = int(state.pendingFrom)
  let offerTo = int(state.pendingTo)
  state.pendingFrom = int8(NoSeat)
  state.pendingTo = int8(NoSeat)
  state.phase = MainPhase
  if not accept:
    return
  state.hands[offerFrom].addBundle(state.pendingGive, -1)
  state.hands[offerFrom].addBundle(state.pendingReceive, 1)
  state.hands[offerTo].addBundle(state.pendingReceive, -1)
  state.hands[offerTo].addBundle(state.pendingGive, 1)

proc applyEndTurn(state: var GameState) =
  if state.rolls >= MaxRolls:
    state.finishGame()
    return
  state.current = int8((int(state.current) + 1) mod int(state.playerCount))
  state.devPlayedThisTurn = false
  state.tradeOffersThisTurn = 0
  state.pendingFrom = int8(NoSeat)
  state.pendingTo = int8(NoSeat)
  state.phase = PrerollPhase
  # A player who reached 10 VP off-turn wins at the start of their turn.
  discard state.checkWin()

proc applyMoveInPlace*(state: var GameState, move: Move) =
  case move.kind
  of SetupMove: state.applySetup(int(move.a), int(move.b))
  of RollMove: state.applyRoll()
  of DiscardMove: state.applyDiscard(move.give)
  of RobberMove: state.applyRobber(int(move.a), int(move.b))
  of BuildRoadMove: state.applyBuildRoad(int(move.a))
  of BuildSettlementMove: state.applyBuildSettlement(int(move.a))
  of BuildCityMove: state.applyBuildCity(int(move.a))
  of BuyDevMove: state.applyBuyDev()
  of PlayKnightMove: state.applyPlayKnight()
  of PlayRoadBuildingMove: state.applyPlayRoadBuilding(int(move.a), int(move.b))
  of PlayYearOfPlentyMove: state.applyPlayYearOfPlenty(int(move.a), int(move.b))
  of PlayMonopolyMove: state.applyPlayMonopoly(int(move.a))
  of BankTradeMove: state.applyBankTrade(int(move.a), int(move.b))
  of RespondTradeMove: state.applyRespondTrade(move.a == 1)
  of EndTurnMove: state.applyEndTurn()

## Legal move generation. Deliberately STEERED, not exhaustive: the huge
## combinatorial phases (discards, road-building pairs, year-of-plenty
## picks) enumerate a small curated candidate set — the guard-rail half
## of the MCTS+steering loop. Every emitted move is legal by the engine's
## validator.

proc clear*(moves: var MoveBuffer) =
  moves.len = 0

proc toSeq*(moves: MoveBuffer): seq[Move] =
  for i in 0 ..< moves.len:
    result.add(moves.moves[i])

proc add(moves: var MoveBuffer, move: Move) =
  if moves.len < MaxLegalMoves:
    moves.moves[moves.len] = move
    inc moves.len

proc playerToMove*(state: GameState): int =
  case state.phase
  of DiscardPhase:
    if state.discardQueueLen > 0: int(state.discardQueue[0]) else: NoSeat
  of TradePhase:
    if state.pendingTo >= 0: int(state.pendingTo) else: NoSeat
  of Finished:
    NoSeat
  else:
    int(state.current)

proc holdsPlayable(state: GameState, seat: int, card: DevCard): bool =
  if state.devPlayedThisTurn:
    return false
  for i in 0 ..< int(state.devHandLen[seat]):
    if state.devHandCards[seat][i].card == card and
        state.devHandCards[seat][i].bought < state.rolls:
      return true
  false

proc bestSetupEdge*(state: GameState, vertex: int): int =
  ## Aim the setup road at the most productive neighboring expansion.
  result = -1
  var bestPips = -1
  for i in 0 ..< board.vertexEdgeLen[vertex]:
    let e = int(board.vertexEdges[vertex][i])
    if state.roads[e] >= 0:
      continue
    let other =
      if int(board.edgeA[e]) == vertex: int(board.edgeB[e])
      else: int(board.edgeA[e])
    let op = state.vertexPips(other)
    if op > bestPips:
      result = e
      bestPips = op

proc addSetupMoves(state: GameState, moves: var MoveBuffer) =
  ## Top spots by pips (all positive-pip spots, capped), each with the
  ## heuristically-aimed road.
  var order: array[NumVertices, int8]
  var count = 0
  for v in 0 ..< NumVertices:
    if not state.distanceRuleOk(v):
      continue
    if state.bestSetupEdge(v) < 0:
      continue
    order[count] = int8(v)
    inc count
  # Insertion sort by descending pips.
  for i in 1 ..< count:
    var j = i
    while j > 0 and state.vertexPips(int(order[j])) >
        state.vertexPips(int(order[j - 1])):
      swap(order[j], order[j - 1])
      dec j
  let cap = min(count, 24)
  for i in 0 ..< cap:
    let v = int(order[i])
    moves.add(Move(kind: SetupMove, a: int8(v),
      b: int8(state.bestSetupEdge(v))))

proc discardCandidates*(state: GameState, seat: int,
    give: var array[3, Bundle]): int =
  ## Guard-railed discard bundles: greedy most-held, plus variants that
  ## protect a complete city / settlement cost sitting in hand.
  let owed = mustDiscard(state.handSize(seat))
  if owed <= 0:
    return 0

  proc greedy(hand: Bundle, protect: Bundle, owed: int): tuple[ok: bool,
      give: Bundle] =
    var hand = hand
    var owed = owed
    for resource in Resource:
      if hand[resource] < protect[resource]:
        return (false, result.give)
    while owed > 0:
      var top = Brick
      var found = false
      for resource in Resource:
        if hand[resource] - protect[resource] > 0 and
            (not found or hand[resource] > hand[top]):
          top = resource
          found = true
      if not found:
        return (false, result.give)
      hand[top] -= 1
      result.give[top] += 1
      dec owed
    result.ok = true

  let hand = state.hands[seat]
  var count = 0
  let plain = greedy(hand, bundle(0, 0, 0, 0, 0), owed)
  if plain.ok:
    give[count] = plain.give
    inc count
  for protect in [CityCost, SettlementCost]:
    let guarded = greedy(hand, protect, owed)
    if guarded.ok:
      var dup = false
      for i in 0 ..< count:
        if give[i] == guarded.give:
          dup = true
      if not dup:
        give[count] = guarded.give
        inc count
  count

proc addRobberMoves(state: GameState, moves: var MoveBuffer) =
  let mover = int(state.current)
  var anyVictims = false
  for h in 0 ..< NumHexes:
    if h == int(state.robber):
      continue
    if state.robberVictimMask(h, mover) != 0:
      anyVictims = true
      break
  var emitted = 0
  for h in 0 ..< NumHexes:
    if h == int(state.robber):
      continue
    let mask = state.robberVictimMask(h, mover)
    if anyVictims and mask == 0:
      continue # Guard rail: robbing nobody while victims exist is waste.
    var ownHere = false
    for i in 0 .. 5:
      if int(state.buildingSeat[board.hexVertices[h][i]]) == mover:
        ownHere = true
    if ownHere and anyVictims:
      continue # Guard rail: never park the robber on our own hexes.
    if mask == 0:
      moves.add(Move(kind: RobberMove, a: int8(h), b: int8(NoSeat)))
      inc emitted
    else:
      for victim in 0 ..< int(state.playerCount):
        if (mask and (1 shl victim)) != 0:
          moves.add(Move(kind: RobberMove, a: int8(h), b: int8(victim)))
          inc emitted
  if emitted == 0:
    # Everything was guard-railed away (e.g. we own every hex): fall back
    # to the first legal placement.
    for h in 0 ..< NumHexes:
      if h == int(state.robber):
        continue
      let mask = state.robberVictimMask(h, mover)
      if anyVictims and mask == 0:
        continue
      var victim = NoSeat
      for candidate in 0 ..< int(state.playerCount):
        if (mask and (1 shl candidate)) != 0:
          victim = candidate
          break
      moves.add(Move(kind: RobberMove, a: int8(h), b: int8(victim)))
      return

proc roadEdgeScore(state: GameState, seat, edge: int): int =
  ## Deterministic road value: open expansion pips at either endpoint.
  for endpoint in [int(board.edgeA[edge]), int(board.edgeB[edge])]:
    if state.distanceRuleOk(endpoint):
      result = max(result, 1 + state.vertexPips(endpoint))

proc addRoadMoves(state: GameState, seat: int, moves: var MoveBuffer,
    kind: MoveKind, cap: int) =
  if state.roadsBuilt(seat) >= MaxRoads:
    return
  var edges: array[NumEdges, int8]
  var count = 0
  for e in 0 ..< NumEdges:
    if state.legalRoadEdge(seat, e):
      edges[count] = int8(e)
      inc count
  for i in 1 ..< count:
    var j = i
    while j > 0 and state.roadEdgeScore(seat, int(edges[j])) >
        state.roadEdgeScore(seat, int(edges[j - 1])):
      swap(edges[j], edges[j - 1])
      dec j
  for i in 0 ..< min(count, cap):
    moves.add(Move(kind: kind, a: edges[i], b: int8(-1)))

proc addDevPlayMoves(state: GameState, seat: int, moves: var MoveBuffer) =
  if state.holdsPlayable(seat, Knight):
    moves.add(Move(kind: PlayKnightMove))
  if state.holdsPlayable(seat, RoadBuilding) and
      state.roadsBuilt(seat) < MaxRoads:
    # One curated pair: the two best sequentially-legal edges.
    var probe = state
    var first = -1
    var bestScore = -1
    for e in 0 ..< NumEdges:
      if probe.legalRoadEdge(seat, e):
        let score = probe.roadEdgeScore(seat, e)
        if score > bestScore:
          first = e
          bestScore = score
    if first >= 0:
      probe.roads[first] = int8(seat)
      var second = -1
      bestScore = -1
      if state.roadsBuilt(seat) + 1 < MaxRoads:
        for e in 0 ..< NumEdges:
          if probe.legalRoadEdge(seat, e):
            let score = probe.roadEdgeScore(seat, e)
            if score > bestScore:
              second = e
              bestScore = score
      moves.add(Move(kind: PlayRoadBuildingMove, a: int8(first),
        b: int8(second)))
  if state.holdsPlayable(seat, YearOfPlenty):
    # Curated picks: complete the city, the settlement, or the dev card.
    let hand = state.hands[seat]
    for target in [CityCost, SettlementCost, DevCardCost]:
      var missing: array[2, int]
      var missingLen = 0
      for resource in Resource:
        var short = int(target[resource] - hand[resource])
        while short > 0 and missingLen < 2:
          missing[missingLen] = ord(resource)
          inc missingLen
          dec short
    # 2 exact misses only — otherwise the card is better saved.
      if missingLen == 2 and state.bank[Resource(missing[0])] > 0 and
          state.bank[Resource(missing[1])] > 0:
        moves.add(Move(kind: PlayYearOfPlentyMove, a: int8(missing[0]),
          b: int8(missing[1])))
        break
  if state.holdsPlayable(seat, Monopoly):
    # Guard rail: only monopolize a resource opponents hold 3+ of.
    var best = -1
    var bestCount = 2
    for resource in Resource:
      var total = 0
      for who in 0 ..< int(state.playerCount):
        if who != seat:
          total += int(state.hands[who][resource])
      if total > bestCount:
        best = ord(resource)
        bestCount = total
    if best >= 0:
      moves.add(Move(kind: PlayMonopolyMove, a: int8(best)))

proc addMainMoves(state: GameState, moves: var MoveBuffer) =
  let seat = int(state.current)
  let hand = state.hands[seat]
  if canAfford(hand, CityCost) and state.citiesBuilt(seat) < MaxCities:
    for v in 0 ..< NumVertices:
      if int(state.buildingSeat[v]) == seat and not state.buildingCity[v]:
        moves.add(Move(kind: BuildCityMove, a: int8(v)))
  if canAfford(hand, SettlementCost) and
      state.settlementsBuilt(seat) < MaxSettlements:
    for v in 0 ..< NumVertices:
      if state.legalSettlementVertex(seat, v):
        moves.add(Move(kind: BuildSettlementMove, a: int8(v)))
  if canAfford(hand, RoadCost):
    state.addRoadMoves(seat, moves, BuildRoadMove, 8)
  if state.devDeckLen > 0 and canAfford(hand, DevCardCost):
    moves.add(Move(kind: BuyDevMove))
  state.addDevPlayMoves(seat, moves)
  for give in Resource:
    let rate = state.tradeRate(seat, give)
    if int(hand[give]) < rate:
      continue
    for receive in Resource:
      if receive == give or state.bank[receive] < 1:
        continue
      moves.add(Move(kind: BankTradeMove, a: int8(ord(give)),
        b: int8(ord(receive))))
  moves.add(Move(kind: EndTurnMove))

proc legalMoves*(state: GameState, moves: var MoveBuffer) =
  moves.clear()
  case state.phase
  of SetupPhase:
    state.addSetupMoves(moves)
  of PrerollPhase:
    moves.add(Move(kind: RollMove))
    state.addDevPlayMoves(int(state.current), moves)
  of DiscardPhase:
    let seat = state.playerToMove()
    var give: array[3, Bundle]
    let count = state.discardCandidates(seat, give)
    for i in 0 ..< count:
      moves.add(Move(kind: DiscardMove, give: give[i]))
  of RobberPhase:
    state.addRobberMoves(moves)
  of MainPhase:
    state.addMainMoves(moves)
  of TradePhase:
    let seat = state.playerToMove()
    if canAfford(state.hands[seat], state.pendingReceive):
      moves.add(Move(kind: RespondTradeMove, a: 1))
    moves.add(Move(kind: RespondTradeMove, a: 0))
  of Finished:
    discard

proc moveKey*(move: Move): uint64 =
  var h: Hash = 0
  h = h !& hash(ord(move.kind))
  h = h !& hash(int(move.a))
  h = h !& hash(int(move.b))
  for resource in Resource:
    h = h !& hash(int(move.give[resource]))
  uint64(!$h)

proc moveText*(move: Move): string =
  case move.kind
  of SetupMove: result = "setup v" & $move.a & " e" & $move.b
  of RollMove: result = "roll"
  of DiscardMove:
    result = "discard"
    for resource in Resource:
      if move.give[resource] > 0:
        result.add(" " & $resource & ":" & $move.give[resource])
  of RobberMove: result = "robber h" & $move.a & " victim " & $move.b
  of BuildRoadMove: result = "road e" & $move.a
  of BuildSettlementMove: result = "settlement v" & $move.a
  of BuildCityMove: result = "city v" & $move.a
  of BuyDevMove: result = "buyDev"
  of PlayKnightMove: result = "knight"
  of PlayRoadBuildingMove:
    result = "roadBuilding e" & $move.a & " e" & $move.b
  of PlayYearOfPlentyMove:
    result = "yearOfPlenty " & $Resource(move.a) & " " & $Resource(move.b)
  of PlayMonopolyMove: result = "monopoly " & $Resource(move.a)
  of BankTradeMove:
    result = "bankTrade " & $Resource(move.a) & "->" & $Resource(move.b)
  of RespondTradeMove:
    result = if move.a == 1: "acceptTrade" else: "declineTrade"
  of EndTurnMove: result = "endTurn"

## Margins: per-seat final VP edge over the best rival — the solver's
## optimization target (positive = outright win).

type SolverMargins* = object
  count*: int
  values*: array[MaxSeats, int]

proc solverMargins*(state: GameState): SolverMargins =
  result.count = int(state.playerCount)
  var vp: array[MaxSeats, int]
  for seat in 0 ..< result.count:
    vp[seat] =
      if state.phase == Finished: int(state.finalVp[seat])
      else: state.trueVp(seat)
  for seat in 0 ..< result.count:
    var bestRival = 0
    for other in 0 ..< result.count:
      if other != seat:
        bestRival = max(bestRival, vp[other])
    result.values[seat] = vp[seat] - bestRival

when defined(release):
  {.pop.}
