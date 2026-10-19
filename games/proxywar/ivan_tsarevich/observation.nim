## Typed accessors over the raw Proxy War decision_request JSON.
##
## The hosted game sends a large, deeply optional observation. Rather than
## mirror the whole TypeScript schema we pull the fields the brain actually
## reads, with total defaults, so a missing or renamed field degrades to a
## neutral value instead of crashing mid episode.

import std/[json, strutils, tables]

type
  Action* = object
    id*: string
    kind*: string
    label*: string
    riskLevel*: string
    riskScore*: float
    meta*: JsonNode

  Rival* = object
    playerID*: string
    name*: string
    isAlive*: bool
    troops*: float
    tiles*: float
    tileShare*: float
    sharesBorder*: bool
    isAllied*: bool
    isFriendly*: bool
    isTeammate*: bool
    canAttack*: bool
    canRequestAlliance*: bool
    underSiege*: bool
    incomingAttack*: bool
    outgoingAttack*: bool
    hasIncomingAllianceRequest*: bool
    relativeTroopRatio*: float
    spawnDistance*: float
    allyCount*: int
    bearing*: string
    distanceClass*: string
    borderTiles*: int
    borderShare*: float
    borderTerrain*: string
    borderCovered*: int
    borderUncovered*: int
    borderUnderAttack*: bool
    navalReachableShoreTiles*: int

  Observation* = object
    raw*: JsonNode
    phase*: string
    strategicPriority*: string
    strategicUrgency*: string
    turnNumber*: int
    alivePlayerCount*: int
    ownTiles*: float
    ownTileShare*: float
    troops*: float
    maxTroops*: float
    troopRatio*: float
    gold*: float
    borderTiles*: float
    incomingAttacks*: int
    outgoingAttacks*: int
    incomingAllianceRequests*: int
    hasSpawned*: bool
    spawnTile*: int
    rivals*: seq[Rival]
    rivalByID*: Table[string, int]
    canExpandIntoNeutral*: bool
    leaderTileShare*: float
    leaderID*: string
    homeDanger*: string
    unitCounts*: Table[string, int]
    ## Tactical affordances the game itself computes for us.
    openingWindow*: bool
    behindExpectedTempo*: bool
    economyRecommended*: bool
    conversionRecommended*: bool
    finishRecommended*: bool
    navalRecommended*: bool
    strikeRecommended*: bool
    survivalAllianceRecommended*: bool
    backstabRecommended*: bool
    backstabTargetID*: string
    survivalAllyTargetID*: string
    bestStrikeActionID*: string
    bestNavalActionID*: string
    recentExpansionCount*: int
    recentBuildCount*: int
    recentHoldCount*: int
    recentAcceptedExpansionSequences*: seq[int]
    ## Action ids the engine itself has flagged as repeated with no effect.
    avoidActionIDs*: seq[string]
    cityCount*: int
    factoryCount*: int
    portCount*: int
    ## Trusted schema-five spatial fields. Older observations stay neutral.
    spatialTrusted*: bool
    spatialSchemaVersion*: int
    mapName*: string
    mapWidth*: int
    mapHeight*: int
    compactness*: string
    regionCount*: int
    coastShare*: float
    largestNeighborBorderShare*: float
    landFrontAttacks*: int

proc closeFrame*(mask: string): string =
  ## An RFC 6455 client close frame: FIN + opcode 0x8, mask bit set, and a
  ## two-byte payload carrying status 1000 (normal closure), masked with the
  ## supplied four-byte key.
  ##
  ## Lives here rather than in the client so the scenario bench can check the
  ## bytes without opening a socket.
  assert mask.len == 4
  var payload = newString(2)
  payload[0] = chr(1000 shr 8)
  payload[1] = chr(1000 and 0xff)
  for index in 0 ..< payload.len:
    payload[index] = chr(payload[index].uint8 xor mask[index mod 4].uint8)
  result = newStringOfCap(8)
  result.add chr(0b1000_1000)
  result.add chr(0b1000_0000 or 2)
  result.add mask
  result.add payload

proc getFloat*(node: JsonNode, key: string, fallback = 0.0): float =
  ## Number-ish field read that tolerates null, strings and integers.
  if node == nil or node.kind != JObject: return fallback
  let value = node{key}
  if value == nil: return fallback
  case value.kind
  of JFloat: value.getFloat()
  of JInt: value.getInt().float
  of JString:
    try: parseFloat(value.getStr()) except CatchableError: fallback
  of JBool: (if value.getBool(): 1.0 else: 0.0)
  else: fallback

proc getStr*(node: JsonNode, key: string, fallback = ""): string =
  if node == nil or node.kind != JObject: return fallback
  let value = node{key}
  if value == nil or value.kind == JNull: return fallback
  if value.kind == JString: value.getStr() else: fallback

proc getBool*(node: JsonNode, key: string, fallback = false): bool =
  if node == nil or node.kind != JObject: return fallback
  let value = node{key}
  if value == nil or value.kind == JNull: return fallback
  if value.kind == JBool: value.getBool() else: fallback

proc getInt*(node: JsonNode, key: string, fallback = 0): int =
  int(getFloat(node, key, fallback.float))

proc parseActions*(node: JsonNode): seq[Action] =
  if node == nil or node.kind != JArray: return
  for item in node:
    var action = Action(
      id: getStr(item, "id"),
      kind: getStr(item, "kind"),
      label: getStr(item, "label"),
      meta: item{"metadata"},
    )
    let risk = item{"risk"}
    action.riskLevel = getStr(risk, "level", "none")
    action.riskScore = getFloat(risk, "score", 0.0)
    if action.id.len > 0:
      result.add(action)

proc parseRivals(node: JsonNode): seq[Rival] =
  if node == nil or node.kind != JArray: return
  for item in node:
    var rival = Rival(
      playerID: getStr(item, "playerID"),
      name: getStr(item, "name"),
      isAlive: getBool(item, "isAlive", true),
      troops: getFloat(item, "troops"),
      tiles: getFloat(item, "tilesOwned"),
      tileShare: getFloat(item, "tileShare"),
      sharesBorder: getBool(item, "sharesBorder"),
      isAllied: getBool(item, "isAllied"),
      isFriendly: getBool(item, "isFriendly"),
      isTeammate: getBool(item, "isTeammate"),
      canAttack: getBool(item, "canAttack"),
      canRequestAlliance: getBool(item, "canRequestAlliance"),
      underSiege: getBool(item, "underSiege"),
      incomingAttack: getBool(item, "incomingAttack"),
      outgoingAttack: getBool(item, "outgoingAttack"),
      hasIncomingAllianceRequest: getBool(item, "hasIncomingAllianceRequest"),
      relativeTroopRatio: getFloat(item, "relativeTroopRatio", 1.0),
      spawnDistance: getFloat(item, "spawnDistance", -1.0),
      bearing: getStr(item, "bearing"),
      distanceClass: getStr(item, "distanceClass"),
    )
    let border = item{"borderWithYou"}
    if border != nil and border.kind == JObject:
      rival.borderTiles = getInt(border, "tiles")
      rival.borderShare = getFloat(border, "shareOfYourBorder")
      rival.borderTerrain = getStr(border, "terrain")
      rival.borderUnderAttack = getBool(border, "underAttackHere")
      let coverage = border{"defensePostFrontCoverage"}
      rival.borderCovered = getInt(coverage, "covered")
      rival.borderUncovered = getInt(coverage, "uncovered")
    let naval = item{"navalExposure"}
    rival.navalReachableShoreTiles =
      getInt(naval, "transportReachableOwnShoreTiles")
    let allies = item{"alliedWithVisibleIds"}
    if allies != nil and allies.kind == JArray:
      rival.allyCount = allies.len
    result.add(rival)

proc parseObservation*(node: JsonNode): Observation =
  result.raw = node
  result.phase = getStr(node, "phase", "unknown")
  let strategic = node{"strategic"}
  result.strategicPriority = getStr(strategic, "priority")
  result.strategicUrgency = getStr(strategic, "urgency")
  result.turnNumber = getInt(node, "turnNumber")
  result.alivePlayerCount = getInt(node, "alivePlayerCount", 2)

  let mapInfo = node{"mapInfo"}
  result.mapName = getStr(mapInfo, "name")
  result.mapWidth = getInt(mapInfo, "width")
  result.mapHeight = getInt(mapInfo, "height")

  let spatial = node{"spatial"}
  result.spatialSchemaVersion = getInt(spatial, "schemaVersion")
  result.spatialTrusted =
    result.spatialSchemaVersion == 5 and
    getStr(spatial, "visibilityModel") ==
      "global-lockstep-public-map-v1"
  let ownShape = spatial{"ownShape"}
  result.compactness = getStr(ownShape, "compactness")
  result.regionCount = getInt(ownShape, "regionCount")
  result.coastShare = getFloat(ownShape, "coastShare")
  result.largestNeighborBorderShare =
    getFloat(ownShape, "largestNeighborBorderShare")

  let own = node{"ownState"}
  if own != nil and own.kind == JObject:
    result.ownTiles = getFloat(own, "tilesOwned")
    result.ownTileShare = getFloat(own, "tileShare")
    result.troops = getFloat(own, "troops")
    result.maxTroops = getFloat(own, "maxTroops", 1.0)
    result.troopRatio = getFloat(own, "troopRatio")
    result.gold = getFloat(own, "gold")
    result.borderTiles = getFloat(own, "borderTiles")
    result.incomingAttacks = getInt(own, "incomingAttacks")
    result.outgoingAttacks = getInt(own, "outgoingAttacks")
    result.incomingAllianceRequests = getInt(own, "incomingAllianceRequests")
    result.hasSpawned = getBool(own, "hasSpawned")
    result.spawnTile = getInt(own, "spawnTile", -1)
    let units = own{"unitCounts"}
    if units != nil and units.kind == JObject:
      for key, value in units:
        result.unitCounts[key] = value.getInt()

  result.rivals = parseRivals(node{"visiblePlayers"})
  for index, rival in result.rivals:
    result.rivalByID[rival.playerID] = index
    if rival.borderUnderAttack:
      inc result.landFrontAttacks

  let combat = node{"combat"}
  result.canExpandIntoNeutral = getBool(combat, "canExpandIntoNeutral")

  let endgame = node{"endgame"}
  if endgame != nil and endgame.kind == JObject:
    result.leaderTileShare = getFloat(endgame, "leaderTileShare")
    result.leaderID = getStr(endgame, "leaderID")

  let tactics = node{"tacticalAffordances"}
  if tactics != nil and tactics.kind == JObject:
    let banking = tactics{"transportTroopBanking"}
    result.homeDanger = getStr(banking, "homeDanger", "low")

    let opening = tactics{"openingExpansionTempo"}
    if opening != nil:
      result.openingWindow = getBool(opening, "openingWindow")
      result.behindExpectedTempo = getBool(opening, "behindExpectedTempo")
      if result.homeDanger.len == 0:
        result.homeDanger = getStr(opening, "homeDanger", "low")

    let economy = tactics{"economyCadence"}
    if economy != nil:
      result.economyRecommended = getBool(economy, "recommended")
      result.recentExpansionCount = getInt(economy, "recentExpansionCount")
      result.recentBuildCount = getInt(economy, "recentBuildCount")
      result.cityCount = getInt(economy, "cityCount")
      result.factoryCount = getInt(economy, "factoryCount")
      result.portCount = getInt(economy, "portCount")

    let conversion = tactics{"frontierConversionTiming"}
    if conversion != nil:
      result.conversionRecommended = getBool(conversion, "recommended")

    let finish = tactics{"frontierFinishPressure"}
    if finish != nil:
      result.finishRecommended = getBool(finish, "recommended")

    let naval = tactics{"navalControl"}
    if naval != nil:
      result.navalRecommended = getBool(naval, "recommended")
      result.bestNavalActionID = getStr(naval, "bestNavalActionID")

    let strike = tactics{"lateGameStrikeTargeting"}
    if strike != nil:
      result.strikeRecommended = getBool(strike, "recommended")
      result.bestStrikeActionID = getStr(strike, "bestStrikeActionID")

    let survival = tactics{"survivalAlliance"}
    if survival != nil:
      result.survivalAllianceRecommended = getBool(survival, "recommended")
      result.survivalAllyTargetID = getStr(survival, "bestAllyTargetID")

    let backstab = tactics{"backstabAlly"}
    if backstab != nil:
      result.backstabRecommended = getBool(backstab, "recommended")
      result.backstabTargetID = getStr(backstab, "backstabTargetID")

  let memory = node{"memory"}
  if memory != nil:
    if result.recentExpansionCount == 0:
      result.recentExpansionCount = getInt(memory, "recentExpansionCount")
    if result.recentBuildCount == 0:
      result.recentBuildCount = getInt(memory, "recentBuildCount")
    result.recentHoldCount = getInt(memory, "recentHoldCount")
    let recentActions = memory{"recentActions"}
    if recentActions != nil and recentActions.kind == JArray:
      for action in recentActions:
        let sequence = getInt(action, "sequence", -1)
        if sequence >= 0 and
            getBool(action, "accepted") and
            getBool(action, "expansion") and
            getStr(action, "actionKind") == "attack":
          result.recentAcceptedExpansionSequences.add(sequence)
    let avoid = memory{"avoidActionIDs"}
    if avoid != nil and avoid.kind == JArray:
      for entry in avoid:
        if entry.kind == JString: result.avoidActionIDs.add(entry.getStr())

  if result.homeDanger.len == 0:
    result.homeDanger = "low"
  if result.maxTroops <= 0:
    result.maxTroops = max(1.0, result.troops)
  if result.troopRatio <= 0 and result.maxTroops > 0:
    result.troopRatio = result.troops / result.maxTroops

proc rival*(observation: Observation, playerID: string): Rival =
  if playerID.len > 0 and observation.rivalByID.hasKey(playerID):
    return observation.rivals[observation.rivalByID[playerID]]
  Rival(relativeTroopRatio: 1.0)

proc unitCount*(observation: Observation, unit: string): int =
  observation.unitCounts.getOrDefault(unit, 0)

proc aliveRivals*(observation: Observation): int =
  for rival in observation.rivals:
    if rival.isAlive: inc result

proc strongestBorderThreat*(observation: Observation): float =
  ## How much stronger the toughest hostile neighbour is than us, as
  ## `theirTroops / ourTroops`. 1.0 means parity, 2.0 means twice our pool.
  ## Only non-allied bordering rivals can actually march on us.
  result = 0.0
  for rival in observation.rivals:
    if not rival.isAlive or rival.isAllied or rival.isTeammate: continue
    if not rival.sharesBorder: continue
    let ratio = if rival.relativeTroopRatio > 0.0001:
        1.0 / rival.relativeTroopRatio
      else: 1.0
    if ratio > result: result = ratio
