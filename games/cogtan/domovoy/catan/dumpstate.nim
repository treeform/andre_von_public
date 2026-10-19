## Shared parser for full TypeScript-engine state dumps (parity and
## self-play boards) plus the canonical state text used for comparisons.

import std/[json, strutils], nodes

proc parseResource*(name: string): Resource =
  case name
  of "brick": Brick
  of "lumber": Lumber
  of "ore": Ore
  of "grain": Grain
  of "wool": Wool
  else: raise newException(ValueError, "bad resource " & name)

proc parseCard*(name: string): DevCard =
  case name
  of "knight": Knight
  of "roadBuilding": RoadBuilding
  of "yearOfPlenty": YearOfPlenty
  of "monopoly": Monopoly
  of "victoryPoint": VictoryPoint
  else: raise newException(ValueError, "bad card " & name)

proc parseBundle*(node: JsonNode): Bundle =
  for resource in Resource:
    let name = case resource
      of Brick: "brick"
      of Lumber: "lumber"
      of Ore: "ore"
      of Grain: "grain"
      of Wool: "wool"
    result[resource] = int16(node{name}.getInt(0))

proc parsePhase*(name: string): Phase =
  case name
  of "setup": SetupPhase
  of "preroll": PrerollPhase
  of "discard": DiscardPhase
  of "robber": RobberPhase
  of "main": MainPhase
  of "trade": TradePhase
  else: Finished

proc parseFullState*(node: JsonNode): GameState =
  result.playerCount = int8(node{"playerCount"}.getInt(4))
  let hexes = node{"hexes"}
  for h in 0 ..< NumHexes:
    result.hexToken[h] = int8(hexes[h]{"token"}.getInt(0))
    result.hexResource[h] = case hexes[h]{"terrain"}.getStr()
      of "hills": int8(ord(Brick))
      of "forest": int8(ord(Lumber))
      of "mountains": int8(ord(Ore))
      of "fields": int8(ord(Grain))
      of "pasture": int8(ord(Wool))
      else: int8(-1)
  let ports = node{"ports"}
  for p in 0 ..< NumPorts:
    result.portEdge[p] = int8(ports[p]{"edge"}.getInt(0))
    let kind = ports[p]{"kind"}.getStr()
    result.portKind[p] =
      if kind == "any": PortAny
      else: PortKind(ord(parseResource(kind)))
  result.robber = int8(node{"robber"}.getInt(0))
  for v in 0 ..< NumVertices:
    result.buildingSeat[v] = int8(NoSeat)
  let buildings = node{"buildings"}
  for v in 0 ..< NumVertices:
    if buildings[v].kind == JObject:
      result.buildingSeat[v] = int8(buildings[v]{"seat"}.getInt(NoSeat))
      result.buildingCity[v] = buildings[v]{"city"}.getBool(false)
  let roads = node{"roads"}
  for e in 0 ..< NumEdges:
    result.roads[e] =
      if roads[e].kind == JInt: int8(roads[e].getInt()) else: int8(NoSeat)
  let hands = node{"hands"}
  for seat in 0 ..< int(result.playerCount):
    result.hands[seat] = parseBundle(hands[seat])
  result.bank = parseBundle(node{"bank"})
  let deck = node{"devDeck"}
  result.devDeckLen = int8(deck.len)
  for i in 0 ..< deck.len:
    result.devDeck[i] = parseCard(deck[i].getStr())
  let devHands = node{"devHands"}
  for seat in 0 ..< int(result.playerCount):
    for card in devHands[seat]:
      result.devHandCards[seat][result.devHandLen[seat]] = DevCardInHand(
        card: parseCard(card{"card"}.getStr()),
        bought: int16(card{"bought"}.getInt(0)))
      inc result.devHandLen[seat]
  let knights = node{"playedKnights"}
  for seat in 0 ..< int(result.playerCount):
    result.playedKnights[seat] = int8(knights[seat].getInt(0))
  result.largestArmy = int8(node{"largestArmy"}.getInt(NoSeat))
  result.longestRoad = int8(node{"longestRoad"}.getInt(NoSeat))
  result.first = int8(node{"first"}.getInt(0))
  result.current = int8(node{"current"}.getInt(0))
  result.phase = parsePhase(node{"phase"}.getStr())
  result.setupIdx = int8(node{"setupIdx"}.getInt(0))
  result.rolls = int16(node{"rolls"}.getInt(0))
  result.devPlayedThisTurn = node{"devPlayedThisTurn"}.getBool(false)
  let queue = node{"discardQueue"}
  if queue != nil and queue.kind == JArray:
    for entry in queue:
      result.discardQueue[result.discardQueueLen] = int8(entry.getInt(0))
      inc result.discardQueueLen
  result.phaseAfterRobber = parsePhase(
    node{"phaseAfterRobber"}.getStr("main"))
  result.pendingFrom = int8(NoSeat)
  result.pendingTo = int8(NoSeat)
  let trade = node{"pendingTrade"}
  if trade != nil and trade.kind == JObject:
    result.pendingFrom = int8(trade{"from"}.getInt(NoSeat))
    result.pendingTo = int8(trade{"to"}.getInt(NoSeat))
    result.pendingGive = parseBundle(trade{"give"})
    result.pendingReceive = parseBundle(trade{"receive"})
  result.tradeOffersThisTurn = int8(node{"tradeOffersThisTurn"}.getInt(0))
  result.winner = int8(node{"winner"}.getInt(NoSeat))
  let finalVp = node{"finalVp"}
  if finalVp != nil and finalVp.kind == JArray:
    for seat in 0 ..< int(result.playerCount):
      result.finalVp[seat] = int16(finalVp[seat].getInt(0))

proc canonical*(state: GameState): string =
  var parts: seq[string]
  parts.add("phase=" & $state.phase)
  parts.add("current=" & $state.current)
  parts.add("first=" & $state.first)
  parts.add("setupIdx=" & $state.setupIdx)
  parts.add("rolls=" & $state.rolls)
  parts.add("robber=" & $state.robber)
  parts.add("devPlayed=" & $state.devPlayedThisTurn)
  parts.add("offers=" & $state.tradeOffersThisTurn)
  parts.add("bank=" & $state.bank)
  for seat in 0 ..< int(state.playerCount):
    parts.add("hand" & $seat & "=" & $state.hands[seat])
    var cards: seq[string]
    for i in 0 ..< int(state.devHandLen[seat]):
      cards.add($state.devHandCards[seat][i].card & "@" &
        $state.devHandCards[seat][i].bought)
    parts.add("dev" & $seat & "=" & cards.join(","))
    parts.add("knights" & $seat & "=" & $state.playedKnights[seat])
  var deck: seq[string]
  for i in 0 ..< int(state.devDeckLen):
    deck.add($state.devDeck[i])
  parts.add("deck=" & deck.join(","))
  var built: seq[string]
  for v in 0 ..< NumVertices:
    if state.buildingSeat[v] >= 0:
      built.add($v & ":" & $state.buildingSeat[v] &
        (if state.buildingCity[v]: "C" else: "S"))
  parts.add("buildings=" & built.join(","))
  var laid: seq[string]
  for e in 0 ..< NumEdges:
    if state.roads[e] >= 0:
      laid.add($e & ":" & $state.roads[e])
  parts.add("roads=" & laid.join(","))
  parts.add("largestArmy=" & $state.largestArmy)
  parts.add("longestRoad=" & $state.longestRoad)
  var queue: seq[string]
  for i in 0 ..< int(state.discardQueueLen):
    queue.add($state.discardQueue[i])
  parts.add("discardQueue=" & queue.join(","))
  parts.add("phaseAfterRobber=" & $state.phaseAfterRobber)
  if state.pendingTo >= 0:
    parts.add("trade=" & $state.pendingFrom & ">" & $state.pendingTo &
      " " & $state.pendingGive & " for " & $state.pendingReceive)
  else:
    parts.add("trade=none")
  if state.phase == Finished:
    parts.add("winner=" & $state.winner)
    var vps: seq[string]
    for seat in 0 ..< int(state.playerCount):
      vps.add($state.finalVp[seat])
    parts.add("finalVp=" & vps.join(","))
  parts.join("\n")

