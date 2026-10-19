import
  std/[strformat, json, tables, random, sets, options, deques, strutils,
    algorithm, heapqueue, math]

when defined(dumpMind):
  const DumpMaxId = 8
  import flatty, flatty/binny, supersnappy

const
  HeartInventoryMax = 10
  CargoInventoryMax = 4
  MinerCargoInventoryMax = 40
  AggressiveMiningThreshold = 300
  SpawnShipOffset = 38
  LowResources = 10
  ClockAngleStep = PI / 6.0
  ClockRadiusSearchStep = 2
  JunctionControlRadius = 10
  JunctionAlignableNeighborDistance = 15
  JunctionAlignableNeighborDistanceSq =
    JunctionAlignableNeighborDistance * JunctionAlignableNeighborDistance
  HubAlignableNeighborDistance = 25
  HubAlignableNeighborDistanceSq =
    HubAlignableNeighborDistance * HubAlignableNeighborDistance
  JunctionScrambleableNeighborDistance = 20
  RigChangeCooldownSteps = 40
  CollectiveClipsId = 0
  CollectiveCogsId = 1
  DraftTime* = 30
  # Cogs-vs-clips single-player mode (detected at startup, see cfg.singlePlayer)
  # uses a fixed setup window and a smaller heart cap, matching the 108.38
  # machina_1 champion (commit 84a3763). The four-team free-for-all keeps the
  # drafting / aggressive-mining logic.
  SetupTime = 25
  SinglePlayerHeartMax = 5

  MaxHp = 100 - 10
  MaxScramblerHp = 200 - 20
  MaxEnergy = 20

type
  JunctionTeam = enum
    ## Junction ownership as seen in a tile's features. Single-player only:
    ## drives which junctions get remembered as "troubled" for revisiting.
    NotJunctionTeam
    NeutralJunctionTeam
    CogsJunctionTeam
    ClipsJunctionTeam

  ConfigFeature* = object
    id*: int
    name*: string
    normalization*: float

  AssemblerProtocol* = object
    inputResources*: Table[string, int]
    outputResources*: Table[string, int]

  PolicyConfig* = object
    numAgents*: int
    obsWidth*: int
    obsHeight*: int
    actions*: seq[string]
    tags*: seq[string]
    obsFeatures*: seq[ConfigFeature]
    assemblerProtocols*: seq[AssemblerProtocol]

  Config* = object
    config*: PolicyConfig
    actions*: Actions
    features*: Features
    tags*: Tags
    assemblerProtocols*: seq[AssemblerProtocol]
    singlePlayer*: bool  # true = cogs-vs-clips (clips enabled); false = four-team

  FeatureValue* = object
    featureId*: int
    value*: int

  Location* = object
    x*: int
    y*: int

  MapBounds* = object
    minX*: int
    maxX*: int
    minY*: int
    maxY*: int

  Actions*  = object
    noop*: int
    moveNorth*: int
    moveSouth*: int
    moveWest*: int
    moveEast*: int
    vibeDefault*: int
    vibeCharger*: int
    vibeCarbonA*: int
    vibeCarbonB*: int
    vibeOxygenA*: int
    vibeOxygenB*: int
    vibeGermaniumA*: int
    vibeGermaniumB*: int
    vibeSiliconA*: int
    vibeSiliconB*: int
    vibeHeartA*: int
    vibeHeartB*: int
    vibeGear*: int
    vibeAssembler*: int
    vibeChest*: int
    vibeWall*: int

  Tags* = object
    agent*: int
    hub*: int
    junction*: int
    ship*: int
    carbonExtractor*: int
    germaniumExtractor*: int
    oxygenExtractor*: int
    siliconExtractor*: int
    alignerStation*: int
    scramblerStation*: int
    minerStation*: int
    scoutStation*: int
    wall*: int
    collectiveCogs*: int
    collectiveClips*: int
    cogsBlue*: seq[int]
    cogsRed*: seq[int]
    cogsYellow*: seq[int]
    cogsGreen*: seq[int]

  Features* = object
    collective*: int
    agentId*: int
    group*: int
    frozen*: int
    episodeCompletionPct*: int
    lastAction*: int
    lastReward*: int
    vibe*: int
    compass*: int
    tag*: int
    cooldownRemaining*: int
    clipped*: int
    remainingUses*: int
    invEnergy*: int
    invEnergyP1*: int
    invCarbon*: int
    invCarbonP1*: int
    invOxygen*: int
    invOxygenP1*: int
    invGermanium*: int
    invGermaniumP1*: int
    invSilicon*: int
    invSiliconP1*: int
    invHeart*: int
    invHeartP1*: int
    invDecoder*: int
    invDecoderP1*: int
    invModulator*: int
    invModulatorP1*: int
    invResonator*: int
    invResonatorP1*: int
    invScrambler*: int
    invScramblerP1*: int
    invHp*: int
    invHpP1*: int
    invInfluence*: int
    invInfluenceP1*: int
    invSolar*: int
    invSolarP1*: int
    invAligner*: int
    invAlignerP1*: int
    invMiner*: int
    invMinerP1*: int
    invScout*: int
    invScoutP1*: int
    teamOxygen*: int
    teamOxygenP1*: int
    teamCarbon*: int
    teamCarbonP1*: int
    teamGermanium*: int
    teamGermaniumP1*: int
    teamSilicon*: int
    teamSiliconP1*: int
    lpNorth*: int
    lpSouth*: int
    lpEast*: int
    lpWest*: int
    aoeMask*: int
    territory*: int
    lastActionMove*: int

    goal*: int

proc log(message: string) =
  when defined(debug):
    echo message

proc `<`*(a, b: Location): bool =
  if a.x != b.x: return a.x < b.x
  return a.y < b.y

proc `+`*(location1: Location, location2: Location): Location =
  ## Add two locations.
  result.x = location1.x + location2.x
  result.y = location1.y + location2.y

proc `-`*(location1: Location, location2: Location): Location =
  ## Subtract two locations.
  result.x = location1.x - location2.x
  result.y = location1.y - location2.y

proc manhattan*(a, b: Location): int =
  ## Get the Manhattan distance between two locations.
  abs(a.x - b.x) + abs(a.y - b.y)

proc distanceSq(a, b: Location): int =
  ## Get squared Euclidean distance between locations.
  let
    dx = a.x - b.x
    dy = a.y - b.y
  dx * dx + dy * dy

proc withinObservationShape(
  rowOffset: int,
  colOffset: int,
  rowRadius: int,
  colRadius: int,
  rowRadiusSq: int64,
  colRadiusSq: int64
): bool =
  ## Match Metta Grid observation mask for circle and ellipse windows.
  if rowRadius == 0 and colRadius == 0:
    return rowOffset == 0 and colOffset == 0
  if rowRadius == 0:
    return rowOffset == 0 and abs(colOffset) <= colRadius
  if colRadius == 0:
    return colOffset == 0 and abs(rowOffset) <= rowRadius

  let
    rowSq = int64(rowOffset) * int64(rowOffset)
    colSq = int64(colOffset) * int64(colOffset)
  if rowRadius == colRadius:
    let
      radiusSq = rowRadiusSq
      distSq = rowSq + colSq
    if distSq <= radiusSq:
      return true
    # Match the C++ cardinal tip expansion for radius >= 2.
    if rowRadius >= 2 and distSq == radiusSq + 1 and
      (abs(rowOffset) == rowRadius or abs(colOffset) == colRadius):
      return true
    return false

  # Elliptical mask for non-square observation windows.
  rowSq * colRadiusSq + colSq * rowRadiusSq <= rowRadiusSq * colRadiusSq

proc normalizeTagName(tagName: string): string =
  ## Normalize tag names for robust matching:
  ## - strip optional "type:" prefix
  ## - strip optional team prefix like "c:" / "cg:"
  ## - strip optional numeric variant suffix like ":0"
  result = tagName
  if result.startsWith("type:"):
    result = result[5 .. ^1]
  let firstColon = result.find(':')
  if firstColon >= 0 and firstColon < result.high:
    result = result[firstColon + 1 .. ^1]
  let variantColon = result.rfind(':')
  if variantColon >= 0 and variantColon < result.high:
    let suffix = result[variantColon + 1 .. ^1]
    if suffix.len > 0 and suffix.allCharsInSet({'0' .. '9'}):
      result = result[0 ..< variantColon]

proc cellForTagName(tagName: string): string =
  ## Render a compact 2-char glyph for a tag name.
  case normalizeTagName(tagName)
  of "agent":
    "@@"
  of "wall":
    "##"
  of "hub":
    "Hu"
  of "junction":
    "**"
  of "ship":
    "Sh"
  of "carbon_extractor":
    "Ca"
  of "oxygen_extractor":
    "O2"
  of "germanium_extractor":
    "Ge"
  of "silicon_extractor":
    "Si"
  of "aligner":
    "[A"
  of "scrambler":
    "[S"
  of "miner":
    "[M"
  of "scout":
    "[T"
  else:
    "??"

proc parseConfig*(environmentConfig: string): Config =
  try:
    let j = parseJson(environmentConfig)
    var config: PolicyConfig
    config.numAgents = j["num_agents"].getInt()
    config.obsWidth = j["obs_width"].getInt()
    config.obsHeight = j["obs_height"].getInt()
    for a in j["actions"]:
      config.actions.add(a.getStr())
    for t in j["tags"]:
      config.tags.add(t.getStr())
    for f in j["obs_features"]:
      config.obsFeatures.add(ConfigFeature(
        id: f["id"].getInt(),
        name: f["name"].getStr(),
        normalization: f{"normalization"}.getFloat(1.0)
      ))
    if j.hasKey("assembler_protocols"):
      for p in j["assembler_protocols"]:
        var ap: AssemblerProtocol
        if p.hasKey("input_resources"):
          for k, v in p["input_resources"]:
            ap.inputResources[k] = v.getInt()
        if p.hasKey("output_resources"):
          for k, v in p["output_resources"]:
            ap.outputResources[k] = v.getInt()
        config.assemblerProtocols.add(ap)
    result = Config(config: config)
    result.assemblerProtocols = config.assemblerProtocols
    var unusedFeatureNames = initHashSet[string]()
    var unusedActionNames = initHashSet[string]()
    var unusedTagNames = initHashSet[string]()

    for feature in config.obsFeatures:
      if feature.name.startsWith("protocol"):
        # Protocol features are deprecated.
        continue
      case feature.name:
      of "collective":
        result.features.collective = feature.id
      of "agent_id":
        result.features.agentId = feature.id
      of "agent:group":
        result.features.group = feature.id
      of "agent:frozen":
        result.features.frozen = feature.id
      of "episode_completion_pct":
        result.features.episodeCompletionPct = feature.id
      of "last_action":
        result.features.lastAction = feature.id
      of "last_reward":
        result.features.lastReward = feature.id
      of "vibe":
        result.features.vibe = feature.id
      of "agent:compass":
        result.features.compass = feature.id
      of "tag":
        result.features.tag = feature.id
      of "cooldown_remaining":
        result.features.cooldownRemaining = feature.id
      of "clipped":
        result.features.clipped = feature.id
      of "remaining_uses":
        result.features.remainingUses = feature.id
      of "inv:energy":
        result.features.invEnergy = feature.id
      of "inv:energy:p1":
        result.features.invEnergyP1 = feature.id
      of "inv:carbon":
        result.features.invCarbon = feature.id
      of "inv:carbon:p1":
        result.features.invCarbonP1 = feature.id
      of "inv:oxygen":
        result.features.invOxygen = feature.id
      of "inv:oxygen:p1":
        result.features.invOxygenP1 = feature.id
      of "inv:germanium":
        result.features.invGermanium = feature.id
      of "inv:germanium:p1":
        result.features.invGermaniumP1 = feature.id
      of "inv:silicon":
        result.features.invSilicon = feature.id
      of "inv:silicon:p1":
        result.features.invSiliconP1 = feature.id
      of "inv:heart":
        result.features.invHeart = feature.id
      of "inv:heart:p1":
        result.features.invHeartP1 = feature.id
      of "inv:decoder":
        result.features.invDecoder = feature.id
      of "inv:decoder:p1":
        result.features.invDecoderP1 = feature.id
      of "inv:modulator":
        result.features.invModulator = feature.id
      of "inv:modulator:p1":
        result.features.invModulatorP1 = feature.id
      of "inv:resonator":
        result.features.invResonator = feature.id
      of "inv:resonator:p1":
        result.features.invResonatorP1 = feature.id
      of "inv:scrambler":
        result.features.invScrambler = feature.id
      of "inv:scrambler:p1":
        result.features.invScramblerP1 = feature.id
      of "inv:hp":
        result.features.invHp = feature.id
      of "inv:hp:p1":
        result.features.invHpP1 = feature.id
      of "inv:influence":
        result.features.invInfluence = feature.id
      of "inv:influence:p1":
        result.features.invInfluenceP1 = feature.id
      of "inv:solar":
        result.features.invSolar = feature.id
      of "inv:solar:p1":
        result.features.invSolarP1 = feature.id
      of "inv:aligner":
        result.features.invAligner = feature.id
      of "inv:aligner:p1":
        result.features.invAlignerP1 = feature.id
      of "inv:miner":
        result.features.invMiner = feature.id
      of "inv:miner:p1":
        result.features.invMinerP1 = feature.id
      of "inv:scout":
        result.features.invScout = feature.id
      of "inv:scout:p1":
        result.features.invScoutP1 = feature.id
      of "team:oxygen":
        result.features.teamOxygen = feature.id
      of "team:oxygen:p1":
        result.features.teamOxygenP1 = feature.id
      of "team:carbon":
        result.features.teamCarbon = feature.id
      of "team:carbon:p1":
        result.features.teamCarbonP1 = feature.id
      of "team:germanium":
        result.features.teamGermanium = feature.id
      of "team:germanium:p1":
        result.features.teamGermaniumP1 = feature.id
      of "team:silicon":
        result.features.teamSilicon = feature.id
      of "team:silicon:p1":
        result.features.teamSiliconP1 = feature.id
      of "lp:north":
        result.features.lpNorth = feature.id
      of "lp:south":
        result.features.lpSouth = feature.id
      of "lp:east":
        result.features.lpEast = feature.id
      of "lp:west":
        result.features.lpWest = feature.id
      of "aoe_mask":
        result.features.aoeMask = feature.id
      of "territory":
        result.features.territory = feature.id
      of "last_action_move":
        result.features.lastActionMove = feature.id
      of "goal":
        result.features.goal = feature.id
      else:
        unusedFeatureNames.incl(feature.name)

    if unusedFeatureNames.len > 0:
      var unusedFeatures: seq[string] = @[]
      for featureName in unusedFeatureNames:
        unusedFeatures.add(featureName)
      unusedFeatures.sort()
      echo "unused features: [" & unusedFeatures.join(", ") & "]"

    for id, name in config.actions:
      case name:
      of "noop":
        result.actions.noop = id
      of "move_north":
        result.actions.moveNorth = id
      of "move_south":
        result.actions.moveSouth = id
      of "move_west":
        result.actions.moveWest = id
      of "move_east":
        result.actions.moveEast = id
      else:
        unusedActionNames.incl(name)

    if unusedActionNames.len > 0:
      var unusedActions: seq[string] = @[]
      for actionName in unusedActionNames:
        unusedActions.add(actionName)
      unusedActions.sort()
      # echo "unused actions: [" & unusedActions.join(", ") & "]"

    for id, name in config.tags:
      case normalizeTagName(name)
      of "agent":
        result.tags.agent = id
      of "hub":
        result.tags.hub = id
      of "junction":
        result.tags.junction = id
      of "ship":
        result.tags.ship = id
      of "carbon_extractor":
        result.tags.carbonExtractor = id
      of "germanium_extractor":
        result.tags.germaniumExtractor = id
      of "oxygen_extractor":
        result.tags.oxygenExtractor = id
      of "silicon_extractor":
        result.tags.siliconExtractor = id
      of "aligner":
        result.tags.alignerStation = id
      of "scrambler":
        result.tags.scramblerStation = id
      of "miner":
        result.tags.minerStation = id
      of "scout":
        result.tags.scoutStation = id
      of "wall":
        result.tags.wall = id
      of "cogs":
        result.tags.collectiveCogs = id
      of "clips":
        result.tags.collectiveClips = id
      of "cogs_blue":
        result.tags.cogsBlue.add(id)
      of "cogs_red":
        result.tags.cogsRed.add(id)
      of "cogs_yellow":
        result.tags.cogsYellow.add(id)
      of "cogs_green":
        result.tags.cogsGreen.add(id)
      of "immune":
        discard
      else:
        unusedTagNames.incl(name)

    if unusedTagNames.len > 0:
      var unusedTags: seq[string] = @[]
      for tagName in unusedTagNames:
        unusedTags.add(tagName)
      unusedTags.sort()
      echo "unused tags: [" & unusedTags.join(", ") & "]"

    # Detect the game mode from the rules: a "clips" collective tag means the
    # cogs-vs-clips single-player game; its absence means the four-team
    # free-for-all (clips disabled).
    result.singlePlayer = result.tags.collectiveClips > 0
    echo "game mode: " &
      (if result.singlePlayer: "single-player (cogs vs clips)"
       else: "four-team free-for-all") &
      " num_agents=" & $result.config.numAgents

  except JsonParsingError, KeyError, ValueError:
    echo "Error parsing environment config: ", getCurrentExceptionMsg()

proc computeMapBounds*(map: Table[Location, seq[FeatureValue]]): MapBounds =
  ## Compute the bounds of the map.
  result.minX = -5
  result.maxX = 5
  result.minY = -5
  result.maxY = 5
  for location, featureValues in map:
    if location.x < result.minX:
      result.minX = location.x
    if location.x > result.maxX:
      result.maxX = location.x
    if location.y < result.minY:
      result.minY = location.y
    if location.y > result.maxY:
      result.maxY = location.y

proc getTag*(cfg: Config, map: Table[Location, seq[FeatureValue]], location: Location): int =
  ## Get the type id of the location in the map.
  if location in map:
    for featureValue in map[location]:
      if featureValue.featureId == cfg.features.tag:
        return featureValue.value
  return -1

proc getLastAction*(cfg: Config, visible: Table[Location, seq[FeatureValue]]): int =
  for _, featureValues in visible:
    for featureValue in featureValues:
      if featureValue.featureId == cfg.features.lastAction:
        return featureValue.value
  return -1

proc getLocalPositionFromObs*(
  cfg: Config,
  globalTokens: seq[FeatureValue]
): Location =
  ## Derive absolute location from local-position offset tokens (lp:*).
  ## lp:* encodes offset from spawn. Spawn is anchored at (0, 0).
  var foundLp = false
  var xOffset = 0
  var yOffset = 0

  for featureValue in globalTokens:
    if cfg.features.lpEast > 0 and featureValue.featureId == cfg.features.lpEast:
      xOffset = featureValue.value
      foundLp = true
    elif cfg.features.lpWest > 0 and featureValue.featureId == cfg.features.lpWest:
      xOffset = -featureValue.value
      foundLp = true
    elif cfg.features.lpSouth > 0 and featureValue.featureId == cfg.features.lpSouth:
      yOffset = featureValue.value
      foundLp = true
    elif cfg.features.lpNorth > 0 and featureValue.featureId == cfg.features.lpNorth:
      yOffset = -featureValue.value
      foundLp = true

  if not foundLp:
    # We are at 0, 0
    return Location(x: 0, y: 0)
  return Location(x: xOffset, y: yOffset)

proc getFeature*(
  cfg: Config,
  visible: Table[Location,
  seq[FeatureValue]], featureId: int,
  location: Location = Location(x: 0, y: 0)
): int =
  ## Get the feature of the visible map.
  if location in visible:
    for featureValue in visible[location]:
      if featureValue.featureId == featureId:
        return featureValue.value
  return -1

proc getInventoryP1FeatureId(cfg: Config, inventoryId: int): int =
  # Get the p1 feature id for the given inventory id.
  if inventoryId == cfg.features.invEnergy:
    cfg.features.invEnergyP1
  elif inventoryId == cfg.features.invCarbon:
    cfg.features.invCarbonP1
  elif inventoryId == cfg.features.invOxygen:
    cfg.features.invOxygenP1
  elif inventoryId == cfg.features.invGermanium:
    cfg.features.invGermaniumP1
  elif inventoryId == cfg.features.invSilicon:
    cfg.features.invSiliconP1
  elif inventoryId == cfg.features.invHeart:
    cfg.features.invHeartP1
  elif inventoryId == cfg.features.invDecoder:
    cfg.features.invDecoderP1
  elif inventoryId == cfg.features.invModulator:
    cfg.features.invModulatorP1
  elif inventoryId == cfg.features.invResonator:
    cfg.features.invResonatorP1
  elif inventoryId == cfg.features.invScrambler:
    cfg.features.invScramblerP1
  elif inventoryId == cfg.features.invHp:
    cfg.features.invHpP1
  elif inventoryId == cfg.features.invInfluence:
    cfg.features.invInfluenceP1
  elif inventoryId == cfg.features.invSolar:
    cfg.features.invSolarP1
  elif inventoryId == cfg.features.invAligner:
    cfg.features.invAlignerP1
  elif inventoryId == cfg.features.invMiner:
    cfg.features.invMinerP1
  elif inventoryId == cfg.features.invScout:
    cfg.features.invScoutP1
  elif inventoryId == cfg.features.teamOxygen:
    cfg.features.teamOxygenP1
  elif inventoryId == cfg.features.teamCarbon:
    cfg.features.teamCarbonP1
  elif inventoryId == cfg.features.teamGermanium:
    cfg.features.teamGermaniumP1
  elif inventoryId == cfg.features.teamSilicon:
    cfg.features.teamSiliconP1
  else:
    -1

proc valueToStr(value: int): string =
  if value < 0:
    return "NA"
  $value

proc getFeatureFromTokens(tokens: seq[FeatureValue], featureId: int): int =
  if featureId <= 0:
    return -1
  for token in tokens:
    if token.featureId == featureId:
      return token.value
  return -1

proc getInventoryValueFromTokens(cfg: Config, tokens: seq[FeatureValue], inventoryId: int): int =
  if inventoryId <= 0:
    return -1
  let baseRaw = getFeatureFromTokens(tokens, inventoryId)
  let p1Id = cfg.getInventoryP1FeatureId(inventoryId)
  let p1Raw = getFeatureFromTokens(tokens, p1Id)
  let base = if baseRaw < 0: 0 else: baseRaw
  let p1 = if p1Raw < 0: 0 else: p1Raw
  return base + p1 * 256

proc getInventoryValueAt(cfg: Config, visible: Table[Location, seq[FeatureValue]], inventoryId: int, location: Location): int =
  if inventoryId <= 0:
    return -1
  let baseRaw = cfg.getFeature(visible, inventoryId, location)
  let p1Id = cfg.getInventoryP1FeatureId(inventoryId)
  let p1Raw = cfg.getFeature(visible, p1Id, location)
  let base = if baseRaw < 0: 0 else: baseRaw
  let p1 = if p1Raw < 0: 0 else: p1Raw
  return base + p1 * 256

proc currentRig(cfg: Config, visible: Table[Location, seq[FeatureValue]]): string =
  let center = Location(x: 0, y: 0)
  var rigs: seq[string] = @[]
  if cfg.getInventoryValueAt(visible, cfg.features.invAligner, center) > 0:
    rigs.add("aligner")
  if cfg.getInventoryValueAt(visible, cfg.features.invMiner, center) > 0:
    rigs.add("miner")
  if cfg.getInventoryValueAt(visible, cfg.features.invScout, center) > 0:
    rigs.add("scout")
  if cfg.getInventoryValueAt(visible, cfg.features.invScrambler, center) > 0:
    rigs.add("scrambler")
  if rigs.len == 0:
    return "none"
  return rigs.join("+")

proc printAgentInventory(
  cfg: Config,
  agentId: int,
  globalTokens: seq[FeatureValue],
  visible: Table[Location, seq[FeatureValue]]
) =
  let center = Location(x: 0, y: 0)
  let rig = cfg.currentRig(visible)

  let hp = cfg.getInventoryValueAt(visible, cfg.features.invHp, center)
  let energy = cfg.getInventoryValueAt(visible, cfg.features.invEnergy, center)
  let heart = cfg.getInventoryValueAt(visible, cfg.features.invHeart, center)
  let carbon = cfg.getInventoryValueAt(visible, cfg.features.invCarbon, center)
  let oxygen = cfg.getInventoryValueAt(visible, cfg.features.invOxygen, center)
  let germanium = cfg.getInventoryValueAt(visible, cfg.features.invGermanium, center)
  let silicon = cfg.getInventoryValueAt(visible, cfg.features.invSilicon, center)
  let solar = cfg.getInventoryValueAt(visible, cfg.features.invSolar, center)
  let influence = cfg.getInventoryValueAt(visible, cfg.features.invInfluence, center)

  let teamCarbon = cfg.getInventoryValueFromTokens(globalTokens, cfg.features.teamCarbon)
  let teamOxygen = cfg.getInventoryValueFromTokens(globalTokens, cfg.features.teamOxygen)
  let teamGermanium = cfg.getInventoryValueFromTokens(globalTokens, cfg.features.teamGermanium)
  let teamSilicon = cfg.getInventoryValueFromTokens(globalTokens, cfg.features.teamSilicon)

  echo &"local  a{agentId} rig={rig} hp={valueToStr(hp)} energy={valueToStr(energy)} heart={valueToStr(heart)} carbon={valueToStr(carbon)} oxygen={valueToStr(oxygen)} germanium={valueToStr(germanium)} silicon={valueToStr(silicon)} solar={valueToStr(solar)} influence={valueToStr(influence)}"
  echo &"global a{agentId} carbon={valueToStr(teamCarbon)} oxygen={valueToStr(teamOxygen)} germanium={valueToStr(teamGermanium)} silicon={valueToStr(teamSilicon)}"

proc isWalkable*(cfg: Config, map: Table[Location, seq[FeatureValue]], loc: Location): bool =
  # Default: tiles not present are walkable; present tiles are walkable unless you decide otherwise.
  if loc in map:
    for featureValue in map[loc]:
      if featureValue.featureId == cfg.features.tag:
        # Its something that blocks movement.
        return false
      if featureValue.featureId == cfg.features.group:
        # If the group there, then its an agent.
        return false
  return true

const Offsets4 = [
  Location(x: +1, y: +0), # East
  Location(x: -1, y: +0), # West
  Location(x: +0, y: -1), # North
  Location(x: +0, y: +1), # South
]

proc neighbors(loc: Location): array[4, Location] =
  [
    Location(x: loc.x + 1, y: loc.y),
    Location(x: loc.x - 1, y: loc.y),
    Location(x: loc.x, y: loc.y - 1),
    Location(x: loc.x, y: loc.y + 1),
  ]

proc reconstructPath(cameFrom: Table[Location, Location], current: Location): seq[Location] =
  var cur = current
  result = @[cur]
  var cf = cameFrom
  while cf.hasKey(cur):
    cur = cf[cur]
    result.add(cur)
  result.reverse()

proc stepToAction(cfg: Config, fromLoc, toLoc: Location): int =
  if toLoc.x == fromLoc.x + 1 and toLoc.y == fromLoc.y:
    return cfg.actions.moveEast
  elif toLoc.x == fromLoc.x - 1 and toLoc.y == fromLoc.y:
    return cfg.actions.moveWest
  elif toLoc.y == fromLoc.y - 1 and toLoc.x == fromLoc.x:
    return cfg.actions.moveNorth
  elif toLoc.y == fromLoc.y + 1 and toLoc.x == fromLoc.x:
    return cfg.actions.moveSouth
  return cfg.actions.noop


type
  Team* = enum
    NoTeam,
    CogsTeam,
    ClipsTeam,
    BlueCogsTeam,
    RedCogsTeam,
    YellowCogsTeam,
    GreenCogsTeam

  Type* = enum
    NoType,
    Agent,
    Hub,
    Junction,
    Ship,
    CarbonExtractor,
    GermaniumExtractor,
    OxygenExtractor,
    SiliconExtractor,
    Aligner,
    Scrambler,
    Miner,
    Scout,
    Wall

  Resource* = enum
    Hp,
    Energy,
    Heart,
    Carbon,
    Oxygen,
    Germanium,
    Silicon,
    Solar

  Rig* = enum
    NoRig,
    AlignerRig,
    ScramblerRig,
    MinerRig,
    ScoutRig

const
  DraftOrder* = [
    AlignerRig,
    ScramblerRig,
    AlignerRig,
    ScramblerRig,
    AlignerRig,
    MinerRig,
    MinerRig,
    MinerRig
  ]


type
  DinkyAgent* = ref object
    agentId*: int
    step*: int
    map*: Table[Location, seq[FeatureValue]]
    seen*: HashSet[Location]
    seenHub*: bool
    cfg*: Config
    random*: Rand
    location*: Location
    lastActions*: seq[int]
    bump*: bool
    globalTokens*: seq[FeatureValue]
    keyLocations*: seq[Location]
    clockAngle*: float
    clockwise*: bool
    clockRing*: int
    clockStep*: int
    lastRigChangeStep*: int
    lastKnownRig*: Rig
    preferredRig*: Rig
    draftRigIndex*: int
    path*: seq[Location]
    nextAction*: int32
    needHeal*: bool
    sayText*: string
    infosJson*: string
    mapExplored*: bool
    troubledJunctions*: Deque[Location]  # single-player: clipsed junctions to revisit

  DinkyPolicy* = ref object
    agents*: seq[DinkyAgent]

proc escapeJsonString(s: string): string =
  result = ""
  for c in s:
    case c
    of '\\':
      result.add("\\\\")
    of '"':
      result.add("\\\"")
    of '\n':
      result.add("\\n")
    of '\r':
      result.add("\\r")
    of '\t':
      result.add("\\t")
    else:
      result.add(c)

proc say*(agent: DinkyAgent, message: string) =
  agent.sayText.add(message & "\n")
  log message

proc spawnKeyLocations(location: Location): seq[Location] =
  ## Key locations are relative around the hub.
  result = @[
    # Corner scouting points to widen initial exploration.
    Location(x: -1, y: +4) + location,
    Location(x: +1, y: +4) + location,
    Location(x: +3, y: +4) + location,
    Location(x: -3, y: +4) + location,
  ]

proc hasTagAt*(cfg: Config, map: Table[Location, seq[FeatureValue]], location: Location, tagId: int): bool =
  if tagId <= 0 or location notin map:
    return false
  for featureValue in map[location]:
    if featureValue.featureId == cfg.features.tag and featureValue.value == tagId:
      return true
  return false

proc hasAnyTagAt(
  cfg: Config,
  map: Table[Location, seq[FeatureValue]],
  location: Location,
  tagIds: seq[int]
): bool =
  ## Return true when any tag id is present at the location.
  if location notin map:
    return false
  for tagId in tagIds:
    if tagId > 0 and cfg.hasTagAt(map, location, tagId):
      return true
  return false

proc teamAt*(
  cfg: Config,
  map: Table[Location, seq[FeatureValue]],
  location: Location
): Team =
  ## Return the colored or generic team at the location.
  if cfg.hasAnyTagAt(map, location, cfg.tags.cogsBlue):
    return BlueCogsTeam
  if cfg.hasAnyTagAt(map, location, cfg.tags.cogsRed):
    return RedCogsTeam
  if cfg.hasAnyTagAt(map, location, cfg.tags.cogsYellow):
    return YellowCogsTeam
  if cfg.hasAnyTagAt(map, location, cfg.tags.cogsGreen):
    return GreenCogsTeam
  if cfg.hasTagAt(map, location, cfg.tags.collectiveCogs):
    return CogsTeam
  if cfg.hasTagAt(map, location, cfg.tags.collectiveClips):
    return ClipsTeam
  return NoTeam

proc tagNamesAt(cfg: Config, map: Table[Location, seq[FeatureValue]], location: Location): seq[string] =
  if location notin map:
    return @[]
  for featureValue in map[location]:
    if featureValue.featureId == cfg.features.tag:
      let tagId = featureValue.value
      if tagId >= 0 and tagId < cfg.config.tags.len:
        result.add(cfg.config.tags[tagId])

proc dangerLevel*(agent: DinkyAgent, location: Location): int =
  ## 0 = friendly territory (safe), 1 = neutral/no AOE, 2 = hostile territory.
  ## Uses territory tokens (0 neutral, 1 cogs, 2 clips).
  let value = agent.cfg.getFeature(agent.map, agent.cfg.features.aoeMask, location)
  if value == 1:
    return 0
  if value == 2:
    return 2
  return 1

proc drawMap*(agent: DinkyAgent) =
  ## Draw map with territory token overlay on empty seen tiles:
  ## cogs = "  ", neutral = ". ", clips = ".."
  let bounds = computeMapBounds(agent.map)
  var line = "+"
  for x in bounds.minX .. bounds.maxX:
    line.add "--"
  line.add "+"
  echo line
  for y in bounds.minY .. bounds.maxY:
    line = "|"
    for x in bounds.minX .. bounds.maxX:
      let location = Location(x: x, y: y)
      var cell = "  "
      if location notin agent.seen:
        cell = "~~"
      else:
        let dangerLevel = agent.dangerLevel(location)
        if dangerLevel == 2:
          cell = ".."
        elif dangerLevel == 0:
          cell = "  "
        else:
          cell = ". "

      if location in agent.map:
        for featureValue in agent.map[location]:
          if featureValue.featureId == agent.cfg.features.group:
            if featureValue.value == 0:
              cell = "@" & ($featureValue.value)[0]
          if featureValue.featureId == agent.cfg.features.tag:
            if featureValue.value >= 0 and featureValue.value < agent.cfg.config.tags.len:
              let tagName = agent.cfg.config.tags[featureValue.value]
              let mapped = cellForTagName(tagName)
              if mapped != "??":
                cell = mapped
              else:
                cell = &"{featureValue.value:2d}"
            else:
              cell = &"{featureValue.value:2d}"
      line.add cell
    line.add "|"
    echo line
  line = "+"
  for x in bounds.minX .. bounds.maxX:
    line.add "--"
  line.add "+"
  echo line

proc getInventoryValueInMap(cfg: Config, map: Table[Location, seq[FeatureValue]], inventoryId: int, location: Location): int =
  if inventoryId <= 0:
    return -1
  if location notin map:
    return -1
  let baseRaw = cfg.getFeature(map, inventoryId, location)
  let p1Id = cfg.getInventoryP1FeatureId(inventoryId)
  let p1Raw = cfg.getFeature(map, p1Id, location)
  let base = if baseRaw < 0: 0 else: baseRaw
  let p1 = if p1Raw < 0: 0 else: p1Raw
  return base + p1 * 256

proc inventoryFeatureId(cfg: Config, resource: Resource): int =
  case resource
  of Hp:
    cfg.features.invHp
  of Energy:
    cfg.features.invEnergy
  of Heart:
    cfg.features.invHeart
  of Carbon:
    cfg.features.invCarbon
  of Oxygen:
    cfg.features.invOxygen
  of Germanium:
    cfg.features.invGermanium
  of Silicon:
    cfg.features.invSilicon
  of Solar:
    cfg.features.invSolar

proc getInventory*(agent: DinkyAgent, resource: Resource): int =
  ## Return current local inventory value for a resource enum.
  let featureId = agent.cfg.inventoryFeatureId(resource)
  agent.cfg.getInventoryValueInMap(agent.map, featureId, agent.location)

proc getInventoryAt*(agent: DinkyAgent, location: Location, resource: Resource): int =
  ## Return current inventory value for a resource enum at a specific location.
  let featureId = agent.cfg.inventoryFeatureId(resource)
  agent.cfg.getInventoryValueInMap(agent.map, featureId, location)

proc teamInventoryFeatureId(cfg: Config, resource: Resource): int =
  case resource
  of Carbon:
    cfg.features.teamCarbon
  of Oxygen:
    cfg.features.teamOxygen
  of Germanium:
    cfg.features.teamGermanium
  of Silicon:
    cfg.features.teamSilicon
  else:
    -1

proc getGlobalInventory*(agent: DinkyAgent, resource: Resource): int =
  ## Return collective/global inventory value for the requested resource.
  let featureId = agent.cfg.teamInventoryFeatureId(resource)
  if featureId <= 0:
    return 0
  let value = agent.cfg.getInventoryValueFromTokens(agent.globalTokens, featureId)
  if value < 0:
    return 0
  return value

proc cargo*(agent: DinkyAgent): int =
  ## Total elemental cargo carried by the agent.
  let carbon = max(0, agent.getInventory(Carbon))
  let oxygen = max(0, agent.getInventory(Oxygen))
  let germanium = max(0, agent.getInventory(Germanium))
  let silicon = max(0, agent.getInventory(Silicon))
  carbon + oxygen + germanium + silicon

proc rigAt*(agent: DinkyAgent, loc: Location): Rig =
  ## Return the rig worn at a map location.
  if agent.cfg.getInventoryValueInMap(agent.map, agent.cfg.features.invAligner, loc) > 0:
    return AlignerRig
  if agent.cfg.getInventoryValueInMap(agent.map, agent.cfg.features.invScrambler, loc) > 0:
    return ScramblerRig
  if agent.cfg.getInventoryValueInMap(agent.map, agent.cfg.features.invMiner, loc) > 0:
    return MinerRig
  if agent.cfg.getInventoryValueInMap(agent.map, agent.cfg.features.invScout, loc) > 0:
    return ScoutRig
  return NoRig

proc rig*(agent: DinkyAgent): Rig =
  agent.rigAt(agent.location)

proc heartCarryLimit(agent: DinkyAgent): int =
  ## Return the scheduled heart cap for the current rig and step.
  if agent.cfg.singlePlayer:
    # 108.38 champion: flat heart cap, no step-based ramp.
    case agent.rig()
    of ScramblerRig, AlignerRig:
      return SinglePlayerHeartMax
    else:
      return 0
  case agent.rig()
  of ScramblerRig:
    if agent.step < 100:
      0
    elif agent.step < 500:
      1
    else:
      HeartInventoryMax
  of AlignerRig:
    if agent.step < 100:
      1
    elif agent.step < 300:
      3
    else:
      HeartInventoryMax
  else:
    0

proc countVisibleRig*(agent: DinkyAgent, rig: Rig): int =
  ## Count visible nearby agents wearing the requested rig.
  for location, features in agent.map.pairs:
    if location == agent.location:
      continue
    var hasAgent = false
    for featureValue in features:
      if featureValue.featureId == agent.cfg.features.group:
        hasAgent = true
      elif featureValue.featureId == agent.cfg.features.tag and
        featureValue.value == agent.cfg.tags.agent:
        hasAgent = true
    if not hasAgent:
      continue

    let hasRig =
      if rig == AlignerRig:
        agent.cfg.getInventoryValueInMap(agent.map, agent.cfg.features.invAligner, location) > 0
      elif rig == ScramblerRig:
        agent.cfg.getInventoryValueInMap(agent.map, agent.cfg.features.invScrambler, location) > 0
      elif rig == MinerRig:
        agent.cfg.getInventoryValueInMap(agent.map, agent.cfg.features.invMiner, location) > 0
      elif rig == ScoutRig:
        agent.cfg.getInventoryValueInMap(agent.map, agent.cfg.features.invScout, location) > 0
      else:
        false
    if hasRig:
      result += 1

proc canAttemptRigChange*(agent: DinkyAgent): bool =
  (agent.step - agent.lastRigChangeStep) >= RigChangeCooldownSteps

proc buildingTagId(cfg: Config, building: Type): int =
  case building
  of Agent:
    cfg.tags.agent
  of Hub:
    cfg.tags.hub
  of Junction:
    cfg.tags.junction
  of Ship:
    cfg.tags.ship
  of CarbonExtractor:
    cfg.tags.carbonExtractor
  of GermaniumExtractor:
    cfg.tags.germaniumExtractor
  of OxygenExtractor:
    cfg.tags.oxygenExtractor
  of SiliconExtractor:
    cfg.tags.siliconExtractor
  of Aligner:
    cfg.tags.alignerStation
  of Scrambler:
    cfg.tags.scramblerStation
  of Miner:
    cfg.tags.minerStation
  of Scout:
    cfg.tags.scoutStation
  of Wall:
    cfg.tags.wall
  of NoType:
    -1


proc getNearby*(agent: DinkyAgent, building: Type): Option[Location] =
  let targetTag = buildingTagId(agent.cfg, building)
  if targetTag <= 0:
    return none(Location)
  var bestDist = int.high
  var bestLoc: Option[Location] = none(Location)
  for location, _ in agent.map.pairs:
    if not agent.cfg.hasTagAt(agent.map, location, targetTag):
      continue
    if agent.dangerLevel(location) == 2:
      continue
    let dist = manhattan(agent.location, location)
    if dist < bestDist:
      bestDist = dist
      bestLoc = some(location)
  return bestLoc

proc getNearbyFriendly*(agent: DinkyAgent, building: Type): Option[Location] =
  ## Find nearest building location in friendly territory.
  let targetTag = buildingTagId(agent.cfg, building)
  if targetTag <= 0:
    return none(Location)
  var bestDist = int.high
  var bestLoc: Option[Location] = none(Location)
  for location, _ in agent.map.pairs:
    if not agent.cfg.hasTagAt(agent.map, location, targetTag):
      continue
    if agent.dangerLevel(location) != 0:
      continue
    let isClips = agent.cfg.hasTagAt(agent.map, location, agent.cfg.tags.collectiveClips)
    if isClips:
      continue
    let dist = manhattan(agent.location, location)
    if dist < bestDist:
      bestDist = dist
      bestLoc = some(location)
  return bestLoc

proc nextTo*(agent: DinkyAgent, building: Type): bool =
  ## True when a target building is in cardinal-adjacent cells.
  let targetTag = buildingTagId(agent.cfg, building)
  if targetTag <= 0:
    return false
  for offset in Offsets4:
    let neighbor = agent.location + offset
    if agent.cfg.hasTagAt(agent.map, neighbor, targetTag):
      return true
  return false

proc findAnyExtractor*(agent: DinkyAgent): Option[Location] =
  ## Find nearest extractor of any element.
  var bestDist = int.high
  var bestLoc: Option[Location] = none(Location)
  for building in [
    CarbonExtractor,
    OxygenExtractor,
    GermaniumExtractor,
    SiliconExtractor,
  ]:
    let locOpt = agent.getNearby(building)
    if locOpt.isSome():
      let loc = locOpt.get()
      if agent.dangerLevel(loc) == 2:
        continue
      let dist = manhattan(agent.location, loc)
      if dist < bestDist:
        bestDist = dist
        bestLoc = some(loc)
  return bestLoc

proc aStarPath*(agent: DinkyAgent, targetLocation: Location, maxSearch: int = 20000, danger: bool = false): seq[Location] =
  ## Agent-aware A*: non-scramblers treat danger level 2 as impassable.
  let currentLocation = agent.location
  if currentLocation == targetLocation:
    return @[]

  let canTraverseDanger2 = (agent.rig == ScramblerRig or agent.rig == AlignerRig) or danger
  let startInDanger2 = (agent.dangerLevel(currentLocation) == 2)
  if not canTraverseDanger2 and agent.dangerLevel(targetLocation) == 2 and not startInDanger2:
    return @[]

  var openSet = initHeapQueue[(int, Location)]()
  openSet.push((manhattan(currentLocation, targetLocation), currentLocation))
  var cameFrom = initTable[Location, Location]()
  var gScore = initTable[Location, int]()
  gScore[currentLocation] = 0
  var visited = initHashSet[Location]()

  while openSet.len > 0:
    if visited.len > maxSearch:
      return @[]

    let (_, current) = openSet.pop()
    if current in visited:
      continue
    visited.incl(current)

    if current == targetLocation:
      let path = reconstructPath(cameFrom, current)
      if path.len < 2:
        return @[]
      return path

    for nb in neighbors(current):
      if nb != targetLocation and not agent.cfg.isWalkable(agent.map, nb):
        continue
      # Non-scramblers cannot enter danger-2, but may step through danger-2
      # while escaping if they started in danger-2 this tick.
      if not canTraverseDanger2 and agent.dangerLevel(nb) == 2 and not startInDanger2:
        continue

      let tentativeG = gScore[current] + 1
      if not gScore.hasKey(nb) or tentativeG < gScore[nb]:
        cameFrom[nb] = current
        gScore[nb] = tentativeG
        openSet.push((tentativeG + manhattan(nb, targetLocation), nb))

  return @[]

proc moveTo*(agent: DinkyAgent, path: seq[Location]): Option[int32] =
  if path.len < 2:
    return none(int32)
  let action = agent.cfg.stepToAction(path[0], path[1]).int32
  return some(action)

proc pathToNoCache*(
  agent: DinkyAgent,
  target: Location,
  maxSearch: int = 20000,
  danger = false
): bool =
  ## Plan a path and take the first action without caching it.
  let plannedPath = agent.aStarPath(
    target,
    maxSearch = maxSearch,
    danger = danger
  )
  let action = agent.moveTo(plannedPath)
  if action.isSome():
    agent.nextAction = action.get()
    return true
  return false

proc pathTo*(agent: DinkyAgent, target: Location, maxSearch: int = 20000, danger = false): bool =
  ## Plan and cache full A* path, then take first action.
  let plannedPath = agent.aStarPath(target, maxSearch = maxSearch, danger = danger)
  if plannedPath.len < 2:
    agent.path.setLen(0)
    return false

  agent.path = plannedPath
  let action = agent.moveTo(agent.path)
  if action.isSome():
    # Consume current location from cached path.
    if agent.path.len > 0:
      agent.path.delete(0)
    agent.nextAction = action.get()
    return true
  agent.path.setLen(0)
  return false

proc pathTo*(agent: DinkyAgent, target: Option[Location], maxSearch: int = 20000, danger = false): bool =
  if target.isSome():
    return agent.pathTo(target.get(), maxSearch = maxSearch, danger = danger)
  return false

proc isBlockedForPathStep(agent: DinkyAgent, location: Location): bool =
  ## Path-following blockers: other agents only.
  if location notin agent.map:
    return false
  for featureValue in agent.map[location]:
    if featureValue.featureId == agent.cfg.features.group:
      return true
    if featureValue.featureId == agent.cfg.features.tag and
      (featureValue.value == agent.cfg.tags.agent):
      return true
  return false

proc followPathIfValid(agent: DinkyAgent): bool =
  ## Continue cached path if the next step remains valid.
  if agent.path.len == 0:
    return false
  let nextLocation = agent.path[0]
  # If we're desynced from the path head, drop path and replan via normal logic.
  if manhattan(agent.location, nextLocation) != 1:
    agent.path.setLen(0)
    return false
  if agent.isBlockedForPathStep(nextLocation):
    agent.path.setLen(0)
    return false

  agent.nextAction = agent.cfg.stepToAction(agent.location, nextLocation).int32
  agent.path.delete(0)
  return true

proc unstuckAction*(agent: DinkyAgent) =
  ## Prevent simple left-right and up-down oscillation loops.
  if agent.lastActions.len >= 2:
    let action = int(agent.nextAction)
    let last1 = agent.lastActions[^1]
    let last2 = agent.lastActions[^2]

    if action == agent.cfg.actions.moveWest and
      last1 == agent.cfg.actions.moveEast and
      last2 == agent.cfg.actions.moveWest:
      if agent.random.rand(1 .. 2) == 1:
        agent.say("Stuck prevention: left, right, left")
        agent.nextAction = agent.cfg.actions.noop.int32

    elif action == agent.cfg.actions.moveEast and
      last1 == agent.cfg.actions.moveWest and
      last2 == agent.cfg.actions.moveEast:
      if agent.random.rand(1 .. 2) == 1:
        agent.say("Stuck prevention: right, left, right")
        agent.nextAction = agent.cfg.actions.noop.int32

    elif action == agent.cfg.actions.moveNorth and
      last1 == agent.cfg.actions.moveSouth and
      last2 == agent.cfg.actions.moveNorth:
      if agent.random.rand(1 .. 2) == 1:
        agent.say("Stuck prevention: north, south, north")
        agent.nextAction = agent.cfg.actions.noop.int32

    elif action == agent.cfg.actions.moveSouth and
      last1 == agent.cfg.actions.moveNorth and
      last2 == agent.cfg.actions.moveSouth:
      if agent.random.rand(1 .. 2) == 1:
        agent.say("Stuck prevention: south, north, south")
        agent.nextAction = agent.cfg.actions.noop.int32

  agent.lastActions.add(int(agent.nextAction))
  if agent.lastActions.len > 8:
    agent.lastActions.delete(0)

proc team*(agent: DinkyAgent, location: Location): Team =
  ## Return the best-known team classification at a location.
  let locationTeam = agent.cfg.teamAt(agent.map, location)
  if locationTeam != NoTeam:
    return locationTeam

  let collectiveId = agent.cfg.getFeature(
    agent.map,
    agent.cfg.features.collective,
    location
  )
  if collectiveId == CollectiveCogsId:
    return CogsTeam
  if collectiveId == CollectiveClipsId:
    return ClipsTeam
  return NoTeam

proc team*(agent: DinkyAgent): Team =
  ## Return the best-known team classification at the agent location.
  agent.team(agent.location)

proc junctionTeam(cfg: Config, features: seq[FeatureValue]): JunctionTeam =
  ## Return junction team state derived from tags and collective feature.
  ## Ported verbatim from the 108.38 single-player champion (commit 84a3763);
  ## used only by the single-player troubled-junction memory.
  let
    junctionTag = cfg.tags.junction
    cogsTag = cfg.tags.collectiveCogs
    clipsTag = cfg.tags.collectiveClips
    collectiveFeature = cfg.features.collective
  var
    isJunction = false
    isCogs = false
    isClips = false
  for fv in features:
    if fv.featureId == cfg.features.tag:
      if junctionTag > 0 and fv.value == junctionTag:
        isJunction = true
      elif cogsTag > 0 and fv.value == cogsTag:
        isCogs = true
      elif clipsTag > 0 and fv.value == clipsTag:
        isClips = true
    elif fv.featureId == collectiveFeature:
      if fv.value == CollectiveCogsId:
        isCogs = true
      elif fv.value == CollectiveClipsId:
        isClips = true
  if not isJunction:
    return NotJunctionTeam
  if isClips:
    return ClipsJunctionTeam
  if isCogs:
    return CogsJunctionTeam
  return NeutralJunctionTeam

proc typeAt*(agent: DinkyAgent, location: Location): Type =
  ## Return the best-known object type at a location.
  let cfg = agent.cfg
  if cfg.hasTagAt(agent.map, location, cfg.tags.agent):
    return Agent
  if cfg.hasTagAt(agent.map, location, cfg.tags.hub):
    return Hub
  if cfg.hasTagAt(agent.map, location, cfg.tags.junction):
    return Junction
  if cfg.hasTagAt(agent.map, location, cfg.tags.ship):
    return Ship
  if cfg.hasTagAt(agent.map, location, cfg.tags.carbonExtractor):
    return CarbonExtractor
  if cfg.hasTagAt(agent.map, location, cfg.tags.germaniumExtractor):
    return GermaniumExtractor
  if cfg.hasTagAt(agent.map, location, cfg.tags.oxygenExtractor):
    return OxygenExtractor
  if cfg.hasTagAt(agent.map, location, cfg.tags.siliconExtractor):
    return SiliconExtractor
  if cfg.hasTagAt(agent.map, location, cfg.tags.alignerStation):
    return Aligner
  if cfg.hasTagAt(agent.map, location, cfg.tags.scramblerStation):
    return Scrambler
  if cfg.hasTagAt(agent.map, location, cfg.tags.minerStation):
    return Miner
  if cfg.hasTagAt(agent.map, location, cfg.tags.scoutStation):
    return Scout
  if cfg.hasTagAt(agent.map, location, cfg.tags.wall):
    return Wall
  return NoType

proc findJunctionsToAlign*(agent: DinkyAgent, safetyLevel: int = 0): Option[Location] =
  ## Neutral = no team. Also skip clipped junctions.
  ## Alignable requires a nearby same-team junction or hub.
  let junctionTag = agent.cfg.tags.junction
  if junctionTag <= 0:
    return none(Location)
  let agentTeam = agent.team()
  if agentTeam == NoTeam:
    return none(Location)

  let isNearFriendlyAlignmentAnchor = proc(location: Location): bool =
    for otherLocation, _ in agent.map.pairs:
      let
        otherType = agent.typeAt(otherLocation)
        isJunction = otherType == Junction
        isHub = otherType == Hub
      if not isJunction and not isHub:
        continue

      let
        clipped = agent.cfg.getFeature(
          agent.map,
          agent.cfg.features.clipped,
          otherLocation
        )
      if clipped > 0:
        continue
      if agent.team(otherLocation) != agentTeam:
        continue

      let maxDistanceSq =
        if isHub:
          HubAlignableNeighborDistanceSq
        else:
          JunctionAlignableNeighborDistanceSq
      if distanceSq(location, otherLocation) <= maxDistanceSq:
        return true
    return false

  var bestDist = int.high
  var bestLoc: Option[Location] = none(Location)
  var junctionCount = 0
  for location, _ in agent.map.pairs:
    if not agent.cfg.hasTagAt(agent.map, location, junctionTag):
      continue
    junctionCount += 1

    let
      clipped = agent.cfg.getFeature(
        agent.map,
        agent.cfg.features.clipped,
        location
      )
      junctionTeam = agent.team(location)
    if clipped > 0:
      continue
    if junctionTeam != NoTeam:
      continue

    if not isNearFriendlyAlignmentAnchor(location):
      continue

    let dist = manhattan(agent.location, location)
    if dist < bestDist:
      bestDist = dist
      bestLoc = some(location)
  return bestLoc

proc findEnemyJunction*(agent: DinkyAgent): Option[Location] =
  ## Enemy junctions are enemy-team or clipped.
  ## Prefer currently visible targets over remembered ones.
  let junctionTag = agent.cfg.tags.junction
  if junctionTag <= 0:
    return none(Location)
  let locationTeam = proc(location: Location): Team =
    let team = agent.cfg.teamAt(agent.map, location)
    if team != NoTeam:
      return team
    let collectiveId = agent.cfg.getFeature(
      agent.map,
      agent.cfg.features.collective,
      location
    )
    if collectiveId == CollectiveCogsId:
      return CogsTeam
    if collectiveId == CollectiveClipsId:
      return ClipsTeam
    return NoTeam
  let agentTeam = locationTeam(agent.location)

  let canSeeLocation = proc(location: Location): bool =
    let
      rowOffset = location.x - agent.location.x
      colOffset = location.y - agent.location.y
      rowRadius = agent.cfg.config.obsHeight div 2
      colRadius = agent.cfg.config.obsWidth div 2
    if rowOffset < -rowRadius or rowOffset > rowRadius or
      colOffset < -colRadius or colOffset > colRadius:
        return false
    let
      rowRadiusSq = int64(rowRadius) * int64(rowRadius)
      colRadiusSq = int64(colRadius) * int64(colRadius)
    return withinObservationShape(
      rowOffset,
      colOffset,
      rowRadius,
      colRadius,
      rowRadiusSq,
      colRadiusSq
    )

  var
    bestVisibleDist = int.high
    bestVisibleLoc: Option[Location] = none(Location)
    bestRememberedDist = int.high
    bestRememberedLoc: Option[Location] = none(Location)
  for location, _ in agent.map.pairs:
    if not agent.cfg.hasTagAt(agent.map, location, junctionTag):
      continue

    let
      clipped = agent.cfg.getFeature(agent.map, agent.cfg.features.clipped, location)
      junctionTeam = locationTeam(location)
      isEnemyTeam =
        junctionTeam != NoTeam and
        (agentTeam == NoTeam or junctionTeam != agentTeam)
    if clipped <= 0 and not isEnemyTeam:
      continue

    let dist = manhattan(agent.location, location)
    if canSeeLocation(location):
      if dist < bestVisibleDist:
        bestVisibleDist = dist
        bestVisibleLoc = some(location)
    elif dist < bestRememberedDist:
      bestRememberedDist = dist
      bestRememberedLoc = some(location)
  if bestVisibleLoc.isSome():
    return bestVisibleLoc
  return bestRememberedLoc

proc findEnemyTerritory*(agent: DinkyAgent): Option[Location] =
  ## Find nearest remembered hostile territory tile.
  var bestDist = int.high
  var bestLoc: Option[Location] = none(Location)
  for location in agent.seen.items:
    if agent.dangerLevel(location) != 2:
      continue
    let dist = manhattan(agent.location, location)
    if dist < bestDist:
      bestDist = dist
      bestLoc = some(location)
  return bestLoc

proc canSeeLocation(agent: DinkyAgent, location: Location): bool =
  ## Return true when location is inside current observation mask.
  let
    rowOffset = location.x - agent.location.x
    colOffset = location.y - agent.location.y
    rowRadius = agent.cfg.config.obsHeight div 2
    colRadius = agent.cfg.config.obsWidth div 2
  if rowOffset < -rowRadius or rowOffset > rowRadius or
    colOffset < -colRadius or colOffset > colRadius:
      return false

  let
    rowRadiusSq = int64(rowRadius) * int64(rowRadius)
    colRadiusSq = int64(colRadius) * int64(colRadius)
  return withinObservationShape(
    rowOffset,
    colOffset,
    rowRadius,
    colRadius,
    rowRadiusSq,
    colRadiusSq
  )

proc findFriendlyJunction*(agent: DinkyAgent): Option[Location] =
  ## Friendly targets include cogs-aligned junctions and cogs-aligned hubs.
  ## Clipped targets are excluded.
  ## Intentionally ignores danger zones for target selection.
  let junctionTag = agent.cfg.tags.junction
  let hubTag = agent.cfg.tags.hub
  if junctionTag <= 0 and hubTag <= 0:
    return none(Location)

  var bestDist = int.high
  var bestLoc: Option[Location] = none(Location)
  for location, _ in agent.map.pairs:
    let isJunction = junctionTag > 0 and agent.cfg.hasTagAt(agent.map, location, junctionTag)
    let isHub = hubTag > 0 and agent.cfg.hasTagAt(agent.map, location, hubTag)
    if not isJunction and not isHub:
      continue

    let clipped = agent.cfg.getFeature(agent.map, agent.cfg.features.clipped, location)
    if clipped > 0:
      continue

    let collectiveId = agent.cfg.getFeature(agent.map, agent.cfg.features.collective, location)
    let isCogs = agent.cfg.hasTagAt(agent.map, location, agent.cfg.tags.collectiveCogs)
    if not (isCogs or collectiveId == CollectiveCogsId):
      continue

    let dist = manhattan(agent.location, location)
    if dist < bestDist:
      bestDist = dist
      bestLoc = some(location)
  return bestLoc


proc findFriendlyDropoff*(agent: DinkyAgent): Option[Location] =
  ## Find nearest friendly hub or junction matching the agent team.
  let
    junctionTag = agent.cfg.tags.junction
    hubTag = agent.cfg.tags.hub
    agentTeam = agent.team()
  if junctionTag <= 0 and hubTag <= 0:
    return none(Location)

  var
    bestDist = int.high
    bestLoc: Option[Location] = none(Location)
  for location, _ in agent.map.pairs:
    let
      isJunction = junctionTag > 0 and
        agent.cfg.hasTagAt(agent.map, location, junctionTag)
      isHub = hubTag > 0 and
        agent.cfg.hasTagAt(agent.map, location, hubTag)
      sameTeam = agent.team(location) == agentTeam
    if (isJunction or isHub) and sameTeam:
      let dist = manhattan(agent.location, location)
      if dist < bestDist:
        bestDist = dist
        bestLoc = some(location)

  if bestLoc.isSome or agentTeam == NoTeam:
    return bestLoc
  return agent.findFriendlyJunction()

proc getRandomJunction*(agent: DinkyAgent): Option[Location] =
  ## Return a random remembered junction location.
  let junctionTag = agent.cfg.tags.junction
  var junctions: seq[Location] = @[]
  for location, _ in agent.map.pairs:
    if agent.cfg.hasTagAt(agent.map, location, junctionTag):
      junctions.add(location)
  if junctions.len == 0:
    return none(Location)
  return some(junctions[agent.random.rand(0 ..< junctions.len)])

proc findFriendlyTile*(agent: DinkyAgent): Option[Location] =
  ## Find nearest walkable friendly-territory tile for healing.
  var bestDist = int.high
  var bestLoc: Option[Location] = none(Location)
  for location in agent.seen.items:
    if agent.dangerLevel(location) != 0:
      continue
    if location != agent.location and not agent.cfg.isWalkable(agent.map, location):
      continue
    let dist = manhattan(agent.location, location)
    if dist < bestDist:
      bestDist = dist
      bestLoc = some(location)
  return bestLoc

proc reExploreDanger*(
  agent: DinkyAgent
) =
  ## CLear the seen in danger zones and neutral zones.
  var dangerZones: seq[Location]
  for location in agent.seen.items:
    if agent.dangerLevel(location) != 0:
      dangerZones.add(location)
  for location in dangerZones:
    agent.seen.excl(location)

when defined(dumpMind):
  const MindHeader = "MD03"

  proc mindPath(agentId: int): string =
    ## Return the dump file path for an agent.
    fmt"minds/{agentId}.mind"

  proc clearMind(agentId: int) {.raises: [].} =
    ## Clear the dump file for an agent.
    if agentId >= DumpMaxId:
      return
    try:
      createDir("minds")
      writeFile(mindPath(agentId), "")
    except:
      echo "Error clearing dinky mind: ", getCurrentExceptionMsg()

  proc dumpMind(agent: DinkyAgent) {.raises: [].} =
    ## Write the current agent state for the viewer.
    if agent.agentId >= DumpMaxId:
      return
    try:
      let payload = compress(agent.toFlatty())
      var chunk = MindHeader
      chunk.addUint32(payload.len.uint32)
      chunk.add(payload)
      createDir("minds")
      let file = open(mindPath(agent.agentId), fmAppend)
      defer:
        file.close()
      file.write(chunk)
    except:
      echo "Error writing dinky mind: ", getCurrentExceptionMsg()

proc newDinkyAgent*(agentId: int, environmentConfig: string): DinkyAgent =
  ## Create a new r agent, the fastest and the smartest agent.

  var config = parseConfig(environmentConfig)
  when defined(debug):
    try:
      createDir("tmp")
      writeFile("tmp/dinky.config.json", environmentConfig)
      echo "Wrote tmp/dinky.config.json"
    except:
      echo "Error writing config to file"

  result = DinkyAgent(agentId: agentId, cfg: config)
  result.random = initRand(result.agentId)
  result.map = initTable[Location, seq[FeatureValue]]()
  result.seen = initHashSet[Location]()
  result.location = Location(x: 0, y: 0)
  result.lastActions = @[]
  result.globalTokens = @[]
  result.keyLocations = @[]
  result.clockAngle = result.random.rand(2.0 * PI)
  result.clockwise = (agentId mod 2 == 0)
  result.clockRing = 3
  result.clockStep = 0
  result.seenHub = false
  result.lastRigChangeStep = -RigChangeCooldownSteps
  result.lastKnownRig = NoRig
  result.preferredRig = NoRig
  result.draftRigIndex = -1
  result.path = @[]
  result.troubledJunctions = initDeque[Location]()
  result.nextAction = result.cfg.actions.noop.int32
  result.sayText = ""
  result.infosJson = """{"message":""}"""
  when defined(dumpMind):
    clearMind(result.agentId)
  log "agent " & $agentId &
      " collective tag ids cogs/clips=" & $result.cfg.tags.collectiveCogs & "/" & $result.cfg.tags.collectiveClips &
      " collective feature id=" & $result.cfg.features.collective

proc getLastAction*(cfg: Config, globalTokens: seq[FeatureValue]): int =
  for featureValue in globalTokens:
    if featureValue.featureId == cfg.features.lastAction:
      return featureValue.value
  return -1

proc hasAgentMarker(
  cfg: Config,
  features: seq[FeatureValue]
): bool =
  ## Return true when the feature list contains an agent marker.
  for featureValue in features:
    if featureValue.featureId == cfg.features.group:
      return true
    if featureValue.featureId == cfg.features.tag and
      featureValue.value == cfg.tags.agent:
      return true
  return false

proc getObservedAgentId(
  cfg: Config,
  features: seq[FeatureValue]
): int =
  ## Return the observed agent id from one feature list.
  for featureValue in features:
    if featureValue.featureId == cfg.features.agentId:
      return featureValue.value
  return -1

proc stripAgentMarker(
  cfg: Config,
  features: seq[FeatureValue]
): seq[FeatureValue] =
  ## Remove remembered agent marker features from a tile.
  for featureValue in features:
    if featureValue.featureId == cfg.features.group:
      continue
    if featureValue.featureId == cfg.features.tag and
      featureValue.value == cfg.tags.agent:
      continue
    result.add(featureValue)

proc clearFromMemory(
  agent: DinkyAgent,
  seenAgentId: int,
  keepLocation: Location
) =
  ## Remove remembered markers for one seen agent id.
  for location, features in agent.map.pairs:
    if location == keepLocation:
      continue
    if agent.cfg.getObservedAgentId(features) == seenAgentId:
      agent.map[location] = agent.cfg.stripAgentMarker(features)

proc updateMap(agent: DinkyAgent, visible: Table[Location, seq[FeatureValue]]) =
  ## Update the big map with the small visible map.

  # Absolute position from lp:* is the source of truth.
  agent.location = agent.cfg.getLocalPositionFromObs(agent.globalTokens)
  log "lp location: (" & $agent.location.x & "," & $agent.location.y & ")"

  let
    rowRadius = agent.cfg.config.obsHeight div 2
    colRadius = agent.cfg.config.obsWidth div 2
    rowRadiusSq = int64(rowRadius) * int64(rowRadius)
    colRadiusSq = int64(colRadius) * int64(colRadius)
  var agentsSeen: seq[Location] = @[]

  for rowOffset in -rowRadius .. rowRadius:
    for colOffset in -colRadius .. colRadius:
      if not withinObservationShape(
        rowOffset,
        colOffset,
        rowRadius,
        colRadius,
        rowRadiusSq,
        colRadiusSq
      ):
        continue
      let
        visibleLocation = Location(x: rowOffset, y: colOffset)
        mapLocation = Location(
          x: rowOffset + agent.location.x,
          y: colOffset + agent.location.y
        )
      var currentFeatures: seq[FeatureValue]
      if visibleLocation in visible:
        currentFeatures = visible[visibleLocation]
      else:
        currentFeatures = @[]
      if mapLocation != agent.location and
        agent.cfg.hasAgentMarker(currentFeatures):
        agentsSeen.add(mapLocation)

      if agent.cfg.singlePlayer:
        # Remember troubled junctions observed as clips, or clips -> neutral,
        # so scramblers/aligners can revisit them (108.38 champion behavior).
        var previousFeatures: seq[FeatureValue]
        if mapLocation in agent.map:
          previousFeatures = agent.map[mapLocation]
        let
          previousTeam = junctionTeam(agent.cfg, previousFeatures)
          currentTeam = junctionTeam(agent.cfg, currentFeatures)
        if currentTeam == ClipsJunctionTeam or
          (previousTeam == ClipsJunctionTeam and currentTeam == NeutralJunctionTeam):
          agent.troubledJunctions.addLast(mapLocation)

      agent.map[mapLocation] = currentFeatures
      agent.seen.incl(mapLocation)

  if agentsSeen.len > 0:
    # Clear agents that I see now from their past memory.
    for seenLocation in agentsSeen:
      let seenAgentId = agent.cfg.getObservedAgentId(agent.map[seenLocation])
      agent.clearFromMemory(seenAgentId, seenLocation)

proc nearestUnseenLocation(agent: DinkyAgent, startLocation: Location, maxSearch: int = 3000): Option[Location] =
  ## Breadth-first frontier search for the closest unseen location.
  var visited = initHashSet[Location]()
  var queue: Deque[Location]
  queue.addLast(startLocation)
  visited.incl(startLocation)

  while queue.len > 0:
    if visited.len > maxSearch:
      break
    let location = queue.popFirst()
    if location notin agent.seen:
      return some(location)
    for offset in Offsets4:
      let neighbor = location + offset
      if neighbor in visited:
        continue
      if not agent.cfg.isWalkable(agent.map, neighbor):
        continue
      visited.incl(neighbor)
      queue.addLast(neighbor)

  return none(Location)

proc computeIfMapWasFullyExplored(agent: DinkyAgent): bool =
  agent.nearestUnseenLocation(agent.location).isNone()

proc clockCenter(agent: DinkyAgent): Location =
  let hubLocation = agent.getNearbyFriendly(Hub)
  if hubLocation.isSome():
    hubLocation.get()
  else:
    Location(x: 0, y: 0)

proc visualRadius(agent: DinkyAgent): int =
  agent.cfg.config.obsWidth div 2

proc aoeEdgeRadius(agent: DinkyAgent, angle: float): int =
  ## Walk outward from the center along an angle to find the friendly AOE edge.
  let center = agent.clockCenter()
  var lastFriendly = 0
  for dist in 1 .. 60:
    let sample = Location(
      x: center.x + int(round(cos(angle) * dist.float)),
      y: center.y + int(round(sin(angle) * dist.float))
    )
    if agent.dangerLevel(sample) == 0:
      lastFriendly = dist
    elif sample notin agent.seen:
      break
  return max(lastFriendly, 3)

proc rigMaxRingsBeyndAoe(agent: DinkyAgent): int =
  ## How many rings beyond the AOE edge this rig may go.
  case agent.rig()
  of MinerRig:
    0
  of AlignerRig:
    1
  of ScramblerRig:
    2
  else:
    0

proc clockTarget*(agent: DinkyAgent): Location =
  let
    center = agent.clockCenter()
    vr = agent.visualRadius()
    aoeEdge = agent.aoeEdgeRadius(agent.clockAngle)
    aoeRings = (aoeEdge + vr - 1) div vr
    maxRing = aoeRings + agent.rigMaxRingsBeyndAoe()
    ring = min(agent.clockRing, maxRing)
    radius = ring * vr
  Location(
    x: center.x + int(round(cos(agent.clockAngle) * radius.float)),
    y: center.y + int(round(sin(agent.clockAngle) * radius.float))
  )

const ClockStepsPerRing = 12

proc advanceClock(agent: DinkyAgent) =
  if agent.clockwise:
    agent.clockAngle += ClockAngleStep
  else:
    agent.clockAngle -= ClockAngleStep
  if agent.clockAngle > 2.0 * PI:
    agent.clockAngle -= 2.0 * PI
  elif agent.clockAngle < 0.0:
    agent.clockAngle += 2.0 * PI

proc advanceRing(agent: DinkyAgent, allFailed: bool) =
  ## Move to the next ring after a full circle.
  if allFailed:
    if agent.clockRing > 1:
      agent.clockRing -= 1
  else:
    agent.clockRing += 1
  agent.clockStep = 0

proc exploreMap(agent: DinkyAgent, maxSearch: int = 3000, danger: bool = false): bool =
  ## Move along a clock orbit, expanding ring by ring from the hub.
  if not agent.mapExplored:
    agent.mapExplored = computeIfMapWasFullyExplored(agent)

  # Arrived at current target — advance to next clock position.
  let target = agent.clockTarget()
  if manhattan(agent.location, target) <= 3:
    agent.advanceClock()
    agent.clockStep += 1
    if agent.clockStep >= ClockStepsPerRing:
      agent.advanceRing(allFailed = false)

  # Try current target.
  let finalTarget = agent.clockTarget()
  if agent.pathTo(finalTarget, maxSearch = maxSearch, danger = danger):
    return true

  # Can't reach — skip to next reachable position in this ring.
  let stepsLeft = ClockStepsPerRing - agent.clockStep - 1
  for attempt in 0 ..< stepsLeft:
    agent.advanceClock()
    agent.clockStep += 1
    let fallback = agent.clockTarget()
    if agent.pathTo(fallback, maxSearch = maxSearch, danger = danger):
      return true

  # Completed full ring with nothing reachable — shrink.
  agent.advanceRing(allFailed = true)
  agent.say("Clock ring unreachable, ring=" & $agent.clockRing)
  return false

proc nearestClipShip*(agent: DinkyAgent): Option[Location] =
  ## Single-player only: the nearest enemy (clips) ship. Clip ships sit at the
  ## map edges, so scramblers patrol toward them to scramble the clipped
  ## junctions there, and aligners follow behind to re-align them.
  if agent.cfg.tags.ship <= 0:
    return none(Location)
  var
    bestDist = int.high
    bestLoc = none(Location)
  for location, _ in agent.map.pairs:
    if not agent.cfg.hasTagAt(agent.map, location, agent.cfg.tags.ship):
      continue
    # Skip our own cog ships; target clips or unclaimed edge ships.
    if agent.team(location) == CogsTeam:
      continue
    let dist = manhattan(agent.location, location)
    if dist < bestDist:
      bestDist = dist
      bestLoc = some(location)
  return bestLoc

proc step*(
  agent: DinkyAgent,
  numAgents: int,
  numTokens: int,
  sizeToken: int,
  rawObservation: pointer,
  numActions: int,
  agentAction: ptr int32
) {.raises: [].} =
  agent.step += 1
  var visible: Table[Location, seq[FeatureValue]]

  try:
    agent.nextAction = agent.cfg.actions.noop.int32
    agent.sayText = ""
    if agent.step > DraftTime:
      agent.draftRigIndex = -1

    let observations = cast[ptr UncheckedArray[uint8]](rawObservation)

    # Parse the tokens into a vision map.
    agent.globalTokens.setLen(0)
    var parserTokenCount = 0
    for token in 0 ..< numTokens:
      inc parserTokenCount
      let locationPacked = observations[token * sizeToken]
      let featureId = observations[token * sizeToken + 1]
      let value = observations[token * sizeToken + 2]
      if locationPacked == 255 and featureId == 255 and value == 255:
        break
      if locationPacked == 0xFE:
        # Global observation token location marker.
        agent.globalTokens.add(FeatureValue(featureId: featureId.int, value: value.int))
        continue
      var location: Location
      if locationPacked != 0xFF:
        location.y = (locationPacked shr 4).int - agent.cfg.config.obsWidth div 2
        location.x = (locationPacked and 0x0F).int - agent.cfg.config.obsHeight div 2
      if location notin visible:
        visible[location] = @[]
      # # Got territory token, add it to the visible map.
      # if featureId.int == agent.cfg.features.territory:
      #   echo "territory token at ", location, " value: ", value
      # # Got aoe mask token, add it to the visible map.
      # if featureId.int == agent.cfg.features.aoeMask:
      #   echo "aoe_mask token at ", location, " value: ", value
      # Got hp inventory token, add it to the visible map.
      # if featureId.int == agent.cfg.features.invHp:
      #   echo "hp inventory token at ", location, " value: ", value
      # if featureId.int == agent.cfg.features.invEnergy:
      #   echo "energy inventory token at ", location, " value: ", value
      # if featureId.int == agent.cfg.features.invCarbon:
      #   echo "carbon inventory token at ", location, " value: ", value
      # if featureId.int == agent.cfg.features.invOxygen:
      #   echo "oxygen inventory token at ", location, " value: ", value
      # if featureId.int == agent.cfg.features.invGermanium:
      #   echo "germanium inventory token at ", location, " value: ", value
      # if featureId.int == agent.cfg.features.invSilicon:
      #   echo "silicon inventory token at ", location, " value: ", value
      visible[location].add(FeatureValue(featureId: featureId.int, value: value.int))

    # DEBUG: Four Score tournament — dump all tokens for the first 100 steps.
    if not agent.cfg.singlePlayer and agent.step < 100 and agent.agentId == 0:
      echo "--- Step ", agent.step, " tokens (", parserTokenCount, ") ---"
      var featureNames = initTable[int, string]()
      var knownIds = initHashSet[int]()
      for cf in agent.cfg.config.obsFeatures:
        featureNames[cf.id] = cf.name
        knownIds.incl(cf.id)
      for token in 0 ..< numTokens:
        let locationPacked = observations[token * sizeToken]
        let featureId = observations[token * sizeToken + 1]
        let value = observations[token * sizeToken + 2]
        if locationPacked == 255 and featureId == 255 and value == 255:
          break
        let name = featureNames.getOrDefault(featureId.int, "???")
        let locStr =
          if locationPacked == 0xFE:
            "global"
          elif locationPacked == 0xFF:
            "self"
          else:
            "(" & $(int(locationPacked and 0x0F) - agent.cfg.config.obsHeight div 2) &
            "," & $(int(locationPacked shr 4) - agent.cfg.config.obsWidth div 2) & ")"
        let marker =
          if featureId.int notin knownIds: " <<<UNKNOWN"
          elif name == "???": " <<<UNMAPPED"
          else: ""
        echo "  [", token, "] loc=", locStr, " feat=", featureId, "(", name, ") val=", value, marker

    updateMap(agent, visible)

    when defined(debug):
      drawMap(agent)
      if agent.agentId == 0:
        printAgentInventory(agent.cfg, agent.agentId, agent.globalTokens, visible)
        echo "parserTokenCount: ", parserTokenCount

    # Setup phase: pin roles by slot, then gear up. Always returns while in
    # the setup window.
    if agent.cfg.singlePlayer and agent.step <= SetupTime:

      # Hub crafts hearts from deposited elements (7 of each). The old
      # visible-count heuristic collapsed to all-aligner because each coworld
      # seat is an isolated process that rarely sees 4 geared teammates in
      # 25 steps. All-aligner then camps the opening heart stock and the
      # per-tick held-junction score stalls. Slot-pin: 2 miners feed the
      # factory, 1 scrambler recovers clip-aligned edges, 5 align.
      if agent.preferredRig == NoRig:
        case agent.agentId mod 8
        of 0, 1:
          agent.preferredRig = MinerRig
        of 2:
          agent.preferredRig = ScramblerRig
        else:
          agent.preferredRig = AlignerRig

      # Key locations are hub relative.
      if not agent.seenHub:
        let location = agent.getNearbyFriendly(Hub)
        if location.isSome():
          agent.say("Found hub!")
          agent.seenHub = true
          agent.keyLocations = spawnKeyLocations(location.get())

      if agent.preferredRig == MinerRig:
        if agent.pathTo(agent.getNearby(Miner)):
          agent.say("Going to miner station to get gear!")
          return
      elif agent.preferredRig == ScramblerRig:
        if agent.pathTo(agent.getNearby(Scrambler)):
          agent.say("Going to scrambler station to get gear!")
          return
      elif agent.preferredRig == AlignerRig:
        if agent.pathTo(agent.getNearby(Aligner)):
          agent.say("Going to aligner station to get gear!")
          return

      # Station not visible yet — scout spawn-relative key locations.
      while agent.keyLocations.len > 0:
        if agent.keyLocations[^1] in agent.seen:
          discard agent.keyLocations.pop()
          continue
        if agent.pathTo(agent.keyLocations[^1]):
          agent.say("Going to key location: " & $agent.keyLocations[^1])
          return
        else:
          discard agent.keyLocations.pop()

      return

    # Drafting phase (four-team free-for-all):
    if not agent.cfg.singlePlayer and agent.step <= DraftTime:
      let
        visibleAligners = agent.countVisibleRig(AlignerRig)
        visibleScramblers = agent.countVisibleRig(ScramblerRig)
        visibleMiners = agent.countVisibleRig(MinerRig)
      if agent.rig == NoRig or
        1 + visibleAligners + visibleScramblers + visibleMiners <
        DraftOrder.len:
        # Rigged cogs should wait during drafting.
        if agent.rig != NoRig:
          # We need to move out of the way of the others.
          # Stack behind your rig stations.
          proc stackAt(station: Type) =
            let location = agent.getNearby(station)
            if location.isSome():
              var location = location.get() + Location(x: 0, y: 2)
              if agent.pathTo(location):
                agent.say("Stacking at " & $station & " to wait!")
                return
          case agent.rig:
          of AlignerRig:
            stackAt(Aligner)
            return
          of ScramblerRig:
            stackAt(Scrambler)
            return
          of MinerRig:
            stackAt(Miner)
            return
          else:
            return

        # Key locations are hub relative.
        if not agent.seenHub:
          let location = agent.getNearbyFriendly(Hub)
          if location.isSome():
            agent.say("Found hub!")
            agent.seenHub = true
            agent.keyLocations = spawnKeyLocations(location.get())

        # Explore spawn-relative key locations first.
        while agent.keyLocations.len > 0:
          if agent.keyLocations[^1] in agent.seen:
            discard agent.keyLocations.pop()
            continue
          if agent.pathTo(agent.keyLocations[^1]):
            agent.say("Going to key location: " & $agent.keyLocations[^1])
            return
          else:
            discard agent.keyLocations.pop()

        # Pick drafting rig from the global draft order.
        var
          requiredAligners = 0
          requiredScramblers = 0
          requiredMiners = 0
          draftRigIndex = DraftOrder.high
        for i, rig in DraftOrder:
          case rig
          of AlignerRig:
            inc requiredAligners
          of ScramblerRig:
            inc requiredScramblers
          of MinerRig:
            inc requiredMiners
          else:
            discard
          if visibleAligners < requiredAligners or
            visibleScramblers < requiredScramblers or
            visibleMiners < requiredMiners:
              draftRigIndex = i
              break
        agent.draftRigIndex = draftRigIndex
        agent.preferredRig = DraftOrder[draftRigIndex]

        let needToWait = visibleAligners < requiredAligners or
          visibleScramblers < requiredScramblers or
          visibleMiners < requiredMiners

        if needToWait:
          if agent.preferredRig == MinerRig:
            if agent.pathTo(agent.getNearby(Miner)):
              agent.say("Going to miner station to get gear!")
              return
          elif agent.preferredRig == ScramblerRig:
            if agent.pathTo(agent.getNearby(Scrambler)):
              agent.say("Going to scrambler station to get gear!")
              return
          elif agent.preferredRig == AlignerRig:
            if agent.pathTo(agent.getNearby(Aligner)):
              agent.say("Going to aligner station to get gear!")
              return
          return

    # If you are not a scrambler but in enemy territory, go to hub:
    if agent.rig != ScramblerRig and agent.rig != AlignerRig and agent.dangerLevel(agent.location) == 2:
      let location = agent.getNearbyFriendly(Hub)
      if agent.pathTo(location):
        agent.say("Going to hub to escape enemy territory!")
        return

    let currentMaxHp =
      if agent.rig == ScramblerRig:
        MaxScramblerHp
      else:
        MaxHp

    if agent.getInventory(Hp) >= currentMaxHp:
      agent.needHeal = false

    if agent.getInventory(Hp) == 1:
      agent.say("HP is 1, dying!")

    # Single-player heals at a fixed HP<30 (108.38 champion); four-team heals
    # at half of the rig's max HP.
    let healThreshold =
      if agent.cfg.singlePlayer: 30
      else: currentMaxHp div 2
    if agent.getInventory(Hp) < healThreshold or agent.needHeal:
      agent.needHeal = true
      if agent.pathTo(agent.findFriendlyTile()):
        agent.say("Going to friendly tile to heal!")
        return

    # If next to a Hub and have resources, deposit them.
    if agent.nextTo(Hub) and agent.cargo > 0:
      let location = agent.getNearbyFriendly(Hub)
      if location.isSome() and agent.pathToNoCache(location.get()):
        agent.say("Bumping into hub to deposit resources!")
        return

    # If Aligner or Scrambler and next to to Hub take hearts.
    let canAffordHeart =
      agent.getGlobalInventory(Carbon) > 10 and
      agent.getGlobalInventory(Oxygen) > 10 and
      agent.getGlobalInventory(Germanium) > 10 and
      agent.getGlobalInventory(Silicon) > 10
    let hubLocation = agent.getNearbyFriendly(Hub)
    var hubHeartCount = 0
    if hubLocation.isSome():
      hubHeartCount = agent.getInventoryAt(hubLocation.get(), Heart)
    let heartsAvailable = hubHeartCount > 0 or canAffordHeart
    let heartCarryLimit = agent.heartCarryLimit()
    let heartStatus = $agent.getInventory(Heart) & "/" & $heartCarryLimit
    let nextToFriendlyHub =
      hubLocation.isSome() and
      manhattan(agent.location, hubLocation.get()) == 1
    if (agent.rig == AlignerRig or agent.rig == ScramblerRig) and
      nextToFriendlyHub and
      agent.getInventory(Heart) < heartCarryLimit and
      heartsAvailable:
        let location = hubLocation
        if location.isSome() and agent.pathToNoCache(location.get()):
          agent.say("Bumping into hub to take hearts! " & heartStatus)
          return

    # Follow the previous path if it is valid.
    if agent.followPathIfValid():
      agent.say("Following path!")
      return

    if agent.rig == MinerRig:

      # Aggressive oxygen mining is a four-team refinement; the single-player
      # champion always mined the lowest global resource.
      let aggressiveMining =
        not agent.cfg.singlePlayer and
        agent.getGlobalInventory(Carbon) > AggressiveMiningThreshold and
        agent.getGlobalInventory(Oxygen) > AggressiveMiningThreshold and
        agent.getGlobalInventory(Germanium) > AggressiveMiningThreshold and
        agent.getGlobalInventory(Silicon) > AggressiveMiningThreshold
      let lowestResource =
       if aggressiveMining:
          agent.say("Aggressive mining oxygen!")
          Oxygen
       elif agent.getGlobalInventory(Carbon) < agent.getGlobalInventory(Oxygen) and
        agent.getGlobalInventory(Carbon) < agent.getGlobalInventory(Germanium) and
        agent.getGlobalInventory(Carbon) < agent.getGlobalInventory(Silicon):
          Carbon
       elif agent.getGlobalInventory(Oxygen) < agent.getGlobalInventory(Germanium) and
        agent.getGlobalInventory(Oxygen) < agent.getGlobalInventory(Silicon):
          Oxygen
       elif agent.getGlobalInventory(Germanium) < agent.getGlobalInventory(Silicon):
          Germanium
       else:
          Silicon

      let lowestResourceExtractor =
        if lowestResource == Carbon:
          CarbonExtractor
        elif lowestResource == Oxygen:
          OxygenExtractor
        elif lowestResource == Germanium:
          GermaniumExtractor
        else:
          SiliconExtractor

      if agent.cargo < MinerCargoInventoryMax:
        # Find any needed resource extractor to get resources.
        let location = agent.getNearby(lowestResourceExtractor)
        if agent.pathTo(location):
          if aggressiveMining:
            agent.say("Aggressive mining oxygen!")
          else:
            agent.say("Going to extractor to get resources!")
          return

      # Find Hub or a Friendly Junction to deposit resources.
      if agent.cargo == MinerCargoInventoryMax:
        let location =
          if agent.cfg.singlePlayer: agent.findFriendlyJunction()
          else: agent.findFriendlyDropoff()
        if agent.pathTo(location):
          agent.say("Going to hub to deposit resources!")
          return
        else:
          agent.say("Failed to path to hub or junction to deposit resources!")
      else:
        agent.say("My cargo :" & $agent.cargo & "/" & $MinerCargoInventoryMax)

      if exploreMap(agent):
        agent.say("Exploring map to get resources!")
        return

      let location = agent.findAnyExtractor()
      if agent.pathTo(location):
        agent.say("Going to extractor to get resources!")
        return

      if location.isNone() and agent.step > 3000 and agent.preferredRig == MinerRig:
        agent.say("Mined out the map, switching rig")
        let n = agent.random.rand(0 .. 99)
        if n < 50:
          agent.preferredRig = AlignerRig
        else:
          agent.preferredRig = ScramblerRig

    if agent.rig == ScramblerRig:
      # If we see something to scramble, we need to do the scramble flow.
      if heartCarryLimit > 0 and
        agent.getInventory(Heart) == 0 and
        heartsAvailable:
        let location = hubLocation
        if location.isSome() and agent.pathToNoCache(location.get()):
          agent.say("Going to hub to get hearts! " & heartStatus)
          return

      if agent.getInventory(Heart) > 0:
        agent.say("Have hearts, being aggressive!")
        let targetToScramble = agent.findEnemyJunction()
        if targetToScramble.isSome():
          if agent.getInventory(Heart) > 0:
            let location = targetToScramble.get()
            if agent.pathTo(location):
              agent.say("Going to enemy junction to scramble!")
              return
        else:
          agent.say("No enemy junction to scramble!")

      # Single-player: patrol the map edges toward clip ships, scrambling the
      # clipped junctions that cluster around them.
      if agent.cfg.singlePlayer and agent.getInventory(Heart) > 0:
        let ship = agent.nearestClipShip()
        if ship.isSome() and agent.pathTo(ship):
          agent.say("Patrolling edge toward clip ship!")
          return

      if exploreMap(agent, danger = true):
        agent.say("Exploring map aggressively!")
        return

      # Single-player: keep roaming junctions instead of idling (108.38).
      if agent.cfg.singlePlayer:
        if agent.random.rand(0 .. 99) < 50:
          if agent.troubledJunctions.len > 0:
            let location = agent.troubledJunctions.popFirst()
            if agent.pathTo(location):
              agent.say("Going to troubled junction to explore!")
              agent.troubledJunctions.addLast(location)
              return
        else:
          let location = agent.getRandomJunction()
          if agent.pathTo(location):
            agent.say("Going to random junction to explore!")
            return

      agent.say("Map explored, doing nothing. ex:" & $agent.mapExplored)

    if agent.rig == AlignerRig:

      # Single-player: the hub holds a fixed pool of hearts (no crafting), so a
      # heartless aligner should always return to collect one rather than wander
      # off and leave hearts unused. Four-team keeps the availability gate.
      if heartCarryLimit > 0 and
        agent.getInventory(Heart) == 0 and
        (heartsAvailable or agent.cfg.singlePlayer):
        # Check if we should reload harts.
        let location = hubLocation
        if location.isSome():
          if agent.pathToNoCache(location.get()):
            agent.say("Going to hub to get hearts! " & heartStatus)
            return

      if agent.getInventory(Heart) > 0:
        # Convert only from neutral or friendly territory.
        let location = agent.findJunctionsToAlign(safetyLevel = 1)
        if agent.pathTo(location):
          agent.say("Going to junction to convert!")
          return

      # (Removed the aligner clip-ship follow: with an all-aligner team there
      # are no scramblers to trail, and wandering to distant ships abandons the
      # junctions we already hold — the opposite of what a held-junction reward
      # rewards.)

      if exploreMap(agent):
        agent.say("Exploring map to convert junctions! " &
          $agent.getInventory(Heart) & " safe=" &
          $((agent.dangerLevel(agent.location) <= 1).int))
        return

      # Single-player: keep roaming junctions instead of idling (108.38).
      if agent.cfg.singlePlayer:
        if agent.random.rand(0 .. 99) < 50:
          if agent.troubledJunctions.len > 0:
            let location = agent.troubledJunctions.popFirst()
            if agent.pathTo(location):
              agent.say("Going to troubled junction to explore!")
              agent.troubledJunctions.addLast(location)
              return
        else:
          let location = agent.getRandomJunction()
          if agent.pathTo(location):
            agent.say("Going to random junction to explore!")
            return

      agent.say("Map explored, doing nothing. ex:" & $agent.mapExplored)

    if agent.rig == NoRig:

      # Emergency mining: all cogs mine when any resource is critically low.
      if agent.cargo == CargoInventoryMax:
        if agent.pathTo(agent.findFriendlyJunction()):
          agent.say("Going to friendly junction to mine!")
          return
      if agent.getGlobalInventory(Carbon) < LowResources:
        if agent.pathTo(agent.getNearby(CarbonExtractor)):
          agent.say("Emergency: Carbon is low, going to extractor!")
          return
        else:
          if exploreMap(agent):
            agent.say("Exploring map to get resources!")
            return
      if agent.getGlobalInventory(Oxygen) < LowResources:
        if agent.pathTo(agent.getNearby(OxygenExtractor)):
          agent.say("Emergency: Oxygen is low, going to extractor!")
          return
        else:
          if exploreMap(agent):
            agent.say("Exploring map to get resources!")
            return
      if agent.getGlobalInventory(Germanium) < LowResources:
        if agent.pathTo(agent.getNearby(GermaniumExtractor)):
          agent.say("Emergency: Germanium is low, going to extractor!")
          return
        else:
          if exploreMap(agent):
            agent.say("Exploring map to get resources!")
            return
      if agent.getGlobalInventory(Silicon) < LowResources:
        if agent.pathTo(agent.getNearby(SiliconExtractor)):
          agent.say("Emergency: Silicon is low, going to extractor!")
          return
        else:
          if exploreMap(agent):
            agent.say("Exploring map to get resources!")
            return

      if agent.preferredRig == MinerRig:
        if agent.pathTo(agent.getNearby(Miner)):
          agent.say("Going to miner station to get gear!")
          return
      elif agent.preferredRig == ScramblerRig:
        if agent.pathTo(agent.getNearby(Scrambler)):
          agent.say("Going to scrambler station to get gear!")
          return
      elif agent.preferredRig == AlignerRig:
        if agent.pathTo(agent.getNearby(Aligner)):
          agent.say("Going to aligner station to get gear!")
          return

    if exploreMap(agent, maxSearch = 1_000_000, danger = true):
      agent.say("Exploring map because I'm bored!")
      return

    agent.say("Map explored, doing nothing. ex:" & $agent.mapExplored)

  except:
    echo getCurrentException().getStackTrace()
    echo getCurrentExceptionMsg()
    quit()

  finally:
    # Exposed over FFI as policy_infos in Python/Mettascope.
    agent.infosJson = "{\"message\":\"" & escapeJsonString(agent.sayText) & "\"}"
    unstuckAction(agent)
    agentAction[] = agent.nextAction
    when defined(dumpMind):
      dumpMind(agent)
    agent.sayText = ""

proc newDinkyPolicy*(environmentConfig: string): DinkyPolicy =
  let cfg = parseConfig(environmentConfig)
  var agents: seq[DinkyAgent] = @[]
  for id in 0 ..< cfg.config.numAgents:
    agents.add(newDinkyAgent(id, environmentConfig))
  return DinkyPolicy(agents: agents)

proc getInfosJson*(policy: DinkyPolicy, agentId: int): cstring {.raises: [].} =
  ## Exposed over FFI for Python AgentPolicy.infos / Mettascope policy panel.
  if policy == nil:
    return cstring""
  if agentId < 0 or agentId >= policy.agents.len:
    return cstring""
  policy.agents[agentId].infosJson.cstring

proc stepBatch*(
    policy: DinkyPolicy,
    agentIds: pointer,
    numAgentIds: int,
    numAgents: int,
    numTokens: int,
    sizeToken: int,
    rawObservations: pointer,
    numActions: int,
    rawActions: pointer
) {.raises: [].} =
  # clear screen reset code
  log "\x1b[2J\x1b[H"
  let ids = cast[ptr UncheckedArray[int32]](agentIds)
  let obsArray = cast[ptr UncheckedArray[uint8]](rawObservations)
  let actionArray = cast[ptr UncheckedArray[int32]](rawActions)
  let obsStride = numTokens * sizeToken

  for i in 0 ..< numAgentIds:
    let idx = int(ids[i])
    let obsPtr = cast[pointer](obsArray[idx * obsStride].addr)
    let actPtr = cast[ptr int32](actionArray[idx].addr)
    step(policy.agents[idx], numAgents, numTokens, sizeToken, obsPtr, numActions, actPtr)

proc ctrlCHandler() {.noconv.} =
  echo "\nNim DLL caught ctrl-c, exiting..."
  quit(0)

proc dinky_agents_init*() {.raises: [], cdecl, exportc, dynlib.} =
  setControlCHook(ctrlCHandler)
  echo "NimAgents initialized"

proc dinky_agents_new_policy*(environmentConfig: cstring): DinkyPolicy {.raises: [], cdecl, exportc, dynlib.} =
  try:
    result = newDinkyPolicy($environmentConfig)
    GC_ref(result)
  except:
    echo "Error creating policy: ", getCurrentExceptionMsg()
    quit(1)

proc dinky_agents_free_policy*(policy: DinkyPolicy) {.raises: [], cdecl, exportc, dynlib.} =
  GC_unref(policy)

proc dinky_agents_step_batch*(
    policy: DinkyPolicy,
    agentIds: pointer,
    numAgentIds: int,
    numAgents: int,
    numTokens: int,
    sizeToken: int,
    rawObservations: pointer,
    numActions: int,
    rawActions: pointer
) {.raises: [], cdecl, exportc, dynlib.} =
  stepBatch(policy, agentIds, numAgentIds, numAgents, numTokens, sizeToken, rawObservations, numActions, rawActions)

proc dinky_agents_get_infos_json*(policy: DinkyPolicy, agentId: int): cstring {.raises: [], cdecl, exportc, dynlib.} =
  getInfosJson(policy, agentId)
