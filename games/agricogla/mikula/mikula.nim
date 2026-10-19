## Mikula Selyaninovich — Agricogla policy. Vendored from ~/p/terra
## src/terra.nim at commit 8869f83 (the terra:v268 champion lineage,
## #1 in the Agricogla league at 2373 MMR). Only edits: this header and
## the module file name (terra.nim -> mikula.nim); terra/ imports kept.
import
  std/[algorithm, cpuinfo, json, math, monotimes, options, os, parseopt,
    strutils, threadpool, times],
  whisky,
  terra/policy as solverPolicy,
  terra/nodes as solver

const
  UseMctsSearch = true
  UseAnchorGoalPolicy = false
  DefaultSolverIterations = 100_000
  DefaultSolverMaxMoves = 400
  DefaultSolverTimeMs = 6_000
  MctsScanWindowMs = 6_000
  SolverMaxThreads = 16
  MinMctsTimeMs = 1_500
  SolverClockMinSearchMs = 80
  SolverClockOverheadMs = 250
  SolverClockFloorMoves = 6
  SolverExplore = 1.4
  SolverScoreScale = 20.0
  SolverRootWarmupVisits = 6
  SolverEarlyCheckEvery = 384
  SolverEarlyMinSamples = 1_024
  SolverEarlyMinRootVisits = 6
  SolverEarlyMinBestVisits = 160
  SolverEarlyStableChecks = 2
  SolverGoodAvg = 2.0
  SolverGoodWin = 55.0
  SolverDisagreeAvgDelta = 4.0
  SolverDisagreeWinDelta = 20.0
  SolverDisagreeMinVisits = 4
  SolverPlanProtectAvgEdge = 2.6
  SolverPlanProtectWinEdge = 12.0
  SolverScoreProtectAvgEdge = 6.5
  SolverScoreProtectWinLead = 8.0
  SolverFirstRoomProtectAvgEdge = 4.5
  SolverFirstRoomProtectWinEdge = 16.0
  SolverFirstRoomBuildProtectAvgEdge = 7.0
  SolverFirstRoomBuildProtectWinEdge = 40.0
  SolverFirstRoomSetupProtectAvgEdge = 12.0
  SolverFirstRoomSetupProtectWinEdge = 65.0
  SolverFirstRoomSetupDetourAvgEdge = 6.0
  SolverFirstRoomSetupDetourWinEdge = 20.0
  SolverFirstRoomFenceProtectAvgEdge = 10.0
  SolverFirstRoomFenceProtectWinEdge = 55.0
  SolverFirstRoomFenceProgress = 0.5
  SolverFirstRoomFenceDrop = 0.25
  SolverGrowthRoomProtectAvgEdge = 8.0
  SolverGrowthRoomProtectWinEdge = 45.0
  SolverFamilyProtectAvgEdge = 7.0
  SolverFamilyProtectWinEdge = 42.0
  SolverFieldCatchupProtectAvgEdge = 6.0
  SolverFieldCatchupProtectWinEdge = 36.0
  SolverFoodProtectAvgEdge = 4.5
  SolverFoodProtectWinEdge = 18.0
  SolverFoodDebtProtectAvgEdge = 5.0
  SolverFoodDebtProtectWinEdge = 32.0
  SolverSelfRolloutPolicyPct = 85
  SolverOpponentRolloutPolicyPct = 65
  SolverMaxPlayers = 4
  SolverMaxTreeNodes = 140_000
  SolverPathLimit = DefaultSolverMaxMoves + 8
  ReconnectWindowMs = 120_000
  ReconnectAttemptMs = 1_000
  DefaultHost = "127.0.0.1"
  DefaultPort = 8080
  PlayerPath = "/player"
  HarvestRounds = [4, 7, 9, 11, 13, 14]
  FarmRows = 3
  FarmCols = 5
  SimpleActions = [
    "r_improvement", "meeting_place", "r_fences", "r_family_growth",
    "farm_expansion", "r_sow_bake", "r_cultivation", "farmland",
    "grain_seeds", "fishing", "day_laborer", "forest", "reed_bank",
    "clay_pit", "lessons", "lessons_b", "r_vegetable", "r_sheep",
    "r_boar", "r_cattle", "copse", "grove", "hollow",
    "quarry_stall", "resource_market", "traveling_players",
    "r_west_quarry", "r_east_quarry", "r_urgent_family"
  ]
  WatchedSolverActions = [
    solver.FarmExpansion, solver.RFamilyGrowth, solver.RUrgentFamily,
    solver.RRenovateImprove, solver.RRedevelop, solver.RSowBake,
    solver.RFences, solver.RSheep, solver.RBoar, solver.RCattle
  ]
  CookingTerms = [
    "fireplace", "cooking hearth", "hearth", "cook", "cooking"
  ]
  FoodTerms = [
    "food", "bake", "oven", "grain", "vegetable", "sheep",
    "boar", "cattle"
  ]
  AnimalGoods = ["sheep", "boar", "cattle"]
  CropGoods = ["grain", "vegetable"]

type
  TerraError* = object of CatchableError

  BotRunConfig = object
    url: string
    address: string
    port: int
    token: string
    slot: int
    solverEnabled: bool
    solverIterations: int
    solverMaxMoves: int
    solverTimeMs: int
    solverThreads: int

  BotMind = object
    lastServerError: string
    serverErrors: int
    solverEnabled: bool
    solverIterations: int
    solverMaxMoves: int
    solverTimeMs: int
    solverThreads: int
    policyGoal: solverPolicy.SteeringGoal
    lastStrategyRound: int
    lastStrategy: string
    solverTree: SolverTree

  SolverSearchNode = object
    stateIdx: int
    move: solver.Move
    key: uint64
    parent: int
    children: seq[int]
    untried: seq[solver.Move]
    visits: int
    wins: int
    ties: int
    losses: int
    totalMargins: array[SolverMaxPlayers, float]
    bestMargin: int
    worstMargin: int

  SolverMargins = object
    count: int
    values: array[SolverMaxPlayers, int]

  SolverRootSummary = object
    move: solver.Move
    visits: int
    wins: int
    ties: int
    losses: int
    totalMargins: array[SolverMaxPlayers, float]
    bestMargin: int
    worstMargin: int

  SolverWorkerResult = object
    worker: int
    ok: bool
    error: string
    sampled: int
    nodes: int
    elapsedMs: int
    summaries: seq[SolverRootSummary]

  SolverTree = object
    nodes: seq[SolverSearchNode]
    states: seq[solver.GameState]
    nodeCount: int
    stateCount: int

  SolverBenchResult* = object
    iterations*: int
    nodes*: int
    rootMoves*: int
    rootChildren*: int
    rootUntried*: int
    rootVisits*: int
    perspective*: int
    bestMove*: string
    bestVisits*: int
    bestAverage*: float
    bestWinRate*: float

template len(tree: SolverTree): int =
  ## Returns the number of live solver nodes.
  tree.nodeCount

template `[]`(tree: SolverTree, idx: int): untyped =
  ## Returns one solver node from the flat node pool.
  tree.nodes[idx]

template nodePtr(tree: var SolverTree, idx: int): ptr SolverSearchNode =
  ## Returns a pointer to one flat node pool slot.
  addr tree.nodes[idx]

template stateAt(tree: SolverTree, idx: int): untyped =
  ## Returns one solver state from the flat state pool.
  tree.states[tree.nodes[idx].stateIdx]

proc raiseTerra(message: string) =
  ## Raises a Terra-specific error.
  raise newException(TerraError, message)

proc truthy(value: string): bool =
  ## Returns true when an environment value means yes.
  case value.strip().toLowerAscii()
  of "1", "true", "yes", "on":
    true
  else:
    false

proc requireOptionValue(key, val: string) =
  ## Raises when one command-line option is missing its value.
  if val.len == 0:
    raiseTerra("Option --" & key & " requires a value.")

proc parsePort(value: string): int =
  ## Parses a websocket port number.
  try:
    result = value.parseInt()
  except ValueError:
    raiseTerra("--port must be an integer.")
  if result <= 0 or result > 65535:
    raiseTerra("--port must be between 1 and 65535.")

proc parseSlot(value: string): int =
  ## Parses a player slot index.
  try:
    result = value.parseInt()
  except ValueError:
    raiseTerra("--slot must be an integer.")
  if result < 0:
    raiseTerra("--slot must be non-negative.")

proc parsePositive(value, name: string): int =
  ## Parses a positive integer option.
  try:
    result = value.parseInt()
  except ValueError:
    raiseTerra(name & " must be an integer.")
  if result <= 0:
    raiseTerra(name & " must be positive.")

proc solverThreadCount(value: int): int =
  ## Clamps the requested solver thread count to the local CPU budget.
  min(max(1, value), SolverMaxThreads)

proc readBotRunConfig(): BotRunConfig =
  ## Reads command-line options and Coworld websocket environment variables.
  result = BotRunConfig(
    url: getEnv("COWORLD_PLAYER_WS_URL", getEnv("COGAMES_ENGINE_WS_URL")),
    address: DefaultHost,
    port: DefaultPort,
    slot: -1,
    solverEnabled: getEnv("TERRA_SOLVER_ENABLED", "1").truthy(),
    solverIterations: parsePositive(
      getEnv("TERRA_SOLVER_ITERATIONS", $DefaultSolverIterations),
      "TERRA_SOLVER_ITERATIONS"
    ),
    solverMaxMoves: parsePositive(
      getEnv("TERRA_SOLVER_MAX_MOVES", $DefaultSolverMaxMoves),
      "TERRA_SOLVER_MAX_MOVES"
    ),
    solverTimeMs: parsePositive(
      getEnv("TERRA_SOLVER_TIME_MS", $DefaultSolverTimeMs),
      "TERRA_SOLVER_TIME_MS"
    ),
    solverThreads: solverThreadCount(
      parsePositive(
        getEnv("TERRA_SOLVER_THREADS", "1"),
        "TERRA_SOLVER_THREADS"
      )
    )
  )
  var
    addressSet = false
    portSet = false
    urlSet = result.url.len > 0
  for kind, key, val in getopt():
    case kind
    of cmdLongOption:
      case key
      of "address", "host":
        key.requireOptionValue(val)
        result.address = val
        addressSet = true
      of "port":
        key.requireOptionValue(val)
        result.port = parsePort(val)
        portSet = true
      of "url":
        key.requireOptionValue(val)
        result.url = val
        urlSet = true
      of "token":
        key.requireOptionValue(val)
        result.token = val
      of "slot":
        key.requireOptionValue(val)
        result.slot = parseSlot(val)
      of "no-solver":
        result.solverEnabled = false
      of "solver-iterations":
        key.requireOptionValue(val)
        result.solverIterations = parsePositive(val, "--solver-iterations")
      of "solver-max-moves":
        key.requireOptionValue(val)
        result.solverMaxMoves = parsePositive(val, "--solver-max-moves")
      of "solver-time-ms":
        key.requireOptionValue(val)
        result.solverTimeMs = parsePositive(val, "--solver-time-ms")
      of "solver-threads":
        key.requireOptionValue(val)
        result.solverThreads = solverThreadCount(
          parsePositive(val, "--solver-threads")
        )
      else:
        raiseTerra("Unknown option: --" & key)
    of cmdShortOption:
      raiseTerra("Unknown option: -" & key)
    of cmdArgument:
      raiseTerra("Unexpected argument: " & key)
    of cmdEnd:
      discard
  if not urlSet and (addressSet or portSet):
    result.url = ""

proc ensurePlayerPath(url: string): string =
  ## Adds the Agricogla player path to a bare websocket base URL.
  let queryIndex = url.find('?')
  let pathEnd =
    if queryIndex >= 0:
      queryIndex
    else:
      url.len
  let beforeQuery = url[0 ..< pathEnd]
  if beforeQuery.endsWith(PlayerPath):
    return url
  if beforeQuery.endsWith("/"):
    result = beforeQuery[0 .. ^2] & PlayerPath
  else:
    result = beforeQuery & PlayerPath
  if queryIndex >= 0:
    result.add url[queryIndex .. ^1]

proc withPlayerQuery(baseUrl: string, token: string, slot: int): string =
  ## Adds slot and token query parameters when a full URL was not supplied.
  if baseUrl.find('?') >= 0:
    return baseUrl
  if slot >= 0 and token.len > 0:
    return baseUrl & "?slot=" & $slot & "&token=" & token
  baseUrl

proc connectUrl(config: BotRunConfig): string =
  ## Builds the websocket URL used by the player.
  let baseUrl =
    if config.url.len > 0:
      config.url
    else:
      "ws://" & config.address & ":" & $config.port
  baseUrl.ensurePlayerPath().withPlayerQuery(config.token, config.slot)

proc redactedUrl(url: string): string =
  ## Returns a websocket URL with the seat token hidden for logs.
  let tokenStart = url.find("token=")
  if tokenStart < 0:
    return url
  let valueStart = tokenStart + "token=".len
  let amp = url.find("&", valueStart)
  if amp < 0:
    return url[0 ..< valueStart] & "***"
  url[0 ..< valueStart] & "***" & url[amp .. ^1]

proc field(node: JsonNode, key: string): JsonNode =
  ## Returns an object field or JSON null when it is absent.
  let child = node.getOrDefault(key)
  if child != nil:
    return child
  newJNull()

proc arrayLen(node: JsonNode): int =
  ## Returns the length of a JSON array or zero for any other node.
  if node != nil and node.kind == JArray:
    return node.len
  0

proc intValue(node: JsonNode, fallback = 0): int =
  ## Returns a JSON integer or a fallback value.
  if node == nil:
    return fallback
  case node.kind
  of JInt:
    node.getInt()
  of JFloat:
    node.getFloat().int
  else:
    fallback

proc numberText(node: JsonNode): string =
  ## Formats a JSON number for compact state text.
  if node == nil:
    return "0"
  case node.kind
  of JInt:
    $node.getInt()
  of JFloat:
    formatFloat(node.getFloat(), ffDecimal, 2).strip(
      chars = {'0', '.'}
    )
  else:
    "0"

proc intField(node: JsonNode, key: string, fallback = 0): int =
  ## Returns an integer object field or a fallback value.
  node.field(key).intValue(fallback)

proc strField(node: JsonNode, key: string): string =
  ## Returns a string object field or an empty string.
  let child = node.field(key)
  if child.kind == JString:
    return child.getStr()

proc boolField(node: JsonNode, key: string, fallback = false): bool =
  ## Returns a boolean object field or a fallback value.
  let child = node.field(key)
  if child.kind == JBool:
    return child.getBool()
  fallback

proc ceilDiv(a, b: int): int =
  ## Returns integer division rounded upward.
  if b <= 0:
    return 0
  (a + b - 1) div b

proc clip(text: string, limit = 220): string =
  ## Truncates long text for compact prompts.
  if text.len <= limit:
    return text
  text[0 ..< limit] & "..."

proc jsonText(node: JsonNode, limit = 500): string =
  ## Renders JSON in one compact prompt-safe string.
  if node == nil or node.kind == JNull:
    return ""
  ($node).clip(limit)

proc scalarText(node: JsonNode): string =
  ## Returns a compact scalar or JSON text for one prompt value.
  if node == nil:
    return ""
  case node.kind
  of JString:
    node.getStr()
  of JInt, JFloat:
    node.numberText()
  of JBool:
    $node.getBool()
  else:
    node.jsonText(240)

proc observationView(message: JsonNode): JsonNode =
  ## Returns the current protocol view or the message itself for legacy frames.
  let view = message.field("view")
  if view.kind == JObject:
    return view
  message

proc observationState(message: JsonNode): JsonNode =
  ## Returns the Agricogla state from either supported observation shape.
  let view = message.observationView()
  if view.field("state").kind == JObject:
    return view.field("state")
  if view.field("players").kind == JArray and view.strField("phase").len > 0:
    return view
  newJObject()

proc observationChoices(message: JsonNode): JsonNode =
  ## Returns the legal parameter choices from an observation.
  let choices = message.observationView().field("choices")
  if choices.kind == JObject:
    return choices
  newJObject()

proc observationOptions(message: JsonNode): JsonNode =
  ## Returns the action-space options from an observation.
  let options = message.observationView().field("options")
  if options.kind == JArray:
    return options
  let state = message.observationState()
  let spaces = state.field("actionSpaces")
  result = newJArray()
  if spaces.kind != JArray:
    return
  for space in spaces:
    let occupied = space.field("occupiedBy")
    let available = state.strField("phase") == "work" and
      (occupied.kind == JNull or
        (occupied.kind == JString and occupied.getStr().len == 0))
    result.add %*{
      "id": space.strField("id"),
      "title": space.strField("id"),
      "summary": "Action space from redacted game state.",
      "pile": space.field("pile"),
      "occupiedBy": occupied,
      "available": available
    }

proc observationSlot(message: JsonNode): int =
  ## Returns this bot's seat index from either supported observation shape.
  let view = message.observationView()
  result = view.intField("playerIdx", -1)
  if result >= 0:
    return
  result = message.intField("slot", -1)
  if result >= 0:
    return
  result = message.intField("seat", -1)
  if result >= 0:
    return
  let state = message.observationState()
  if state.strField("phase") == "feeding":
    let toFeed = state.field("toFeed")
    if toFeed.kind == JArray and toFeed.len > 0:
      return toFeed[0].intValue(-1)
  if state.strField("phase") == "work":
    return state.intField("currentPlayer", -1)

proc observationId(message: JsonNode): int =
  ## Returns the observation correlation id.
  result = message.intField("decisionId", -1)
  if result >= 0:
    return
  result = message.intField("id", 0)

proc observationPhase(message: JsonNode): string =
  ## Returns the current decision phase.
  result = message.strField("phase")
  if result.len > 0:
    return
  result = message.observationState().strField("phase")

proc observationReason(message: JsonNode): string =
  ## Returns the latest server rejection reason.
  result = message.strField("error")
  if result.len > 0:
    return
  result = message.strField("reason")

proc usesReplyEnvelope(message: JsonNode): bool =
  ## Returns true for the current cogweb.player.v1 reply protocol.
  message.field("view").kind == JObject or message.field("id").kind == JInt

proc playerNode(message: JsonNode): JsonNode =
  ## Returns this bot's player node from an observation.
  let
    state = message.observationState()
    players = state.field("players")
    slot = message.observationSlot()
  if players.kind == JArray and slot >= 0 and slot < players.len:
    return players[slot]
  newJObject()

proc resourceGood(resource: solver.Resource): string =
  ## Returns the TypeScript good name for one solver resource.
  case resource
  of solver.Wood:
    "wood"
  of solver.Clay:
    "clay"
  of solver.Reed:
    "reed"
  of solver.Stone:
    "stone"
  of solver.Grain:
    "grain"
  of solver.Vegetable:
    "vegetable"
  of solver.Food:
    "food"

proc animalFromGood(good: string): tuple[ok: bool, animal: solver.Animal] =
  ## Returns the solver animal matching one TypeScript good name.
  case good
  of "sheep":
    (true, solver.Sheep)
  of "boar":
    (true, solver.Boar)
  of "cattle":
    (true, solver.Cattle)
  else:
    (false, solver.Sheep)

proc playedCardIds(player: JsonNode): seq[string] =
  ## Returns all played card ids from one player JSON node.
  for group in ["occupations", "minors", "majors"]:
    let cards = player.field(group)
    if cards.kind != JArray:
      continue
    for card in cards:
      let id = card.scalarText()
      if id.len > 0:
        result.add id

proc familyFoodNeed(message, player: JsonNode): int =
  ## Returns the harvest food need derived from a state-only prompt.
  let
    state = message.observationState()
    perAdult =
      if state.boolField("solo"):
        3
      else:
        2
    round = state.intField("round")
    family = player.field("family")
  if family.kind != JArray:
    return 0
  for member in family:
    if member.intField("bornRound") == round:
      result += 1
    else:
      result += perAdult

proc feedingNeed(message, choices, player: JsonNode): int =
  ## Returns the food need from choices or the observed game state.
  let fromChoices = choices.field("foodNeededNow")
  if fromChoices.kind in {JInt, JFloat}:
    return fromChoices.intValue()
  message.familyFoodNeed(player)

proc addFeedingOption(
  options: JsonNode,
  via,
  name,
  good: string,
  foodEach,
  maxCount: int
) =
  ## Adds one derived legal feeding option.
  if maxCount <= 0 or foodEach <= 0:
    return
  options.add %*{
    "via": via,
    "name": name,
    "good": good,
    "foodEach": foodEach,
    "max": maxCount
  }

proc bestCookOption(
  player: JsonNode,
  good: string
): tuple[id: string, rate: int] =
  ## Returns the best played cooking card for one animal good.
  let parsed = animalFromGood(good)
  if not parsed.ok:
    return
  for id in player.playedCardIds():
    let rate = solver.cookRate(id, parsed.animal)
    if rate > result.rate:
      result = (id, rate)

proc feedingOptions(message: JsonNode): JsonNode =
  ## Returns server conversion options or derives them from visible state.
  let fromChoices = message.observationChoices().field("conversionOptions")
  if fromChoices.kind == JArray:
    return fromChoices
  let player = message.playerNode()
  result = newJArray()
  if player.kind != JObject:
    return
  let
    resources = player.field("resources")
    animals = player.field("animals")
  if resources.intField("grain") > 0:
    result.addFeedingOption(
      "raw",
      "Raw grain",
      "grain",
      1,
      resources.intField("grain")
    )
  if resources.intField("vegetable") > 0:
    result.addFeedingOption(
      "raw",
      "Raw vegetable",
      "vegetable",
      1,
      resources.intField("vegetable")
    )
  for good in AnimalGoods:
    let cook = player.bestCookOption(good)
    if cook.rate > 0 and animals.intField(good) > 0:
      result.addFeedingOption(
        cook.id,
        cook.id,
        good,
        cook.rate,
        animals.intField(good)
      )
  for id in player.playedCardIds():
    let vegRate = solver.vegetableCookRate(id)
    if vegRate > 0 and resources.intField("vegetable") > 0:
      result.addFeedingOption(
        id,
        id,
        "vegetable",
        vegRate,
        resources.intField("vegetable")
      )
    let harvest = solver.harvestFood(id)
    if harvest.food > 0 and message.observationPhase() == "feeding":
      let good = resourceGood(harvest.resource)
      result.addFeedingOption(
        id,
        id,
        good,
        harvest.food,
        min(harvest.maxCount, resources.intField(good))
      )

proc ownedCrop(player: JsonNode): string =
  ## Chooses a crop the player owns for simple sowing fallbacks.
  let resources = player.field("resources")
  if resources.intField("grain") > 0:
    return "grain"
  if resources.intField("vegetable") > 0:
    return "vegetable"

proc firstArrayInt(node: JsonNode, fallback = -1): int =
  ## Returns the first integer from one JSON array.
  if node == nil or node.kind != JArray:
    return fallback
  for item in node:
    if item.kind in {JInt, JFloat}:
      return item.intValue(fallback)
  fallback

proc affordableCard(card: JsonNode): bool =
  ## Returns true when one visible card can be played now.
  card.boolField("affordable", true) and card.boolField("prereqOk", true)

proc cardId(card: JsonNode): string =
  ## Returns one visible card id from either compact or rich card data.
  if card.kind == JString:
    return card.getStr()
  card.strField("id")

proc cardSearchText(card: JsonNode): string =
  ## Returns lowercase searchable card text.
  if card.kind == JString:
    return card.getStr().toLowerAscii()
  (
    card.strField("id") & " " &
    card.strField("name") & " " &
    card.strField("text")
  ).toLowerAscii()

proc matchesTerms(card: JsonNode, terms: openArray[string]): bool =
  ## Returns true when one card contains any search term.
  let text = card.cardSearchText()
  for term in terms:
    if text.contains(term):
      return true

proc firstMatchingCardId(
  cards: JsonNode,
  terms: openArray[string]
): string =
  ## Returns the first playable card id that matches any search term.
  if cards == nil or cards.kind != JArray:
    return ""
  for card in cards:
    if card.affordableCard() and card.matchesTerms(terms):
      let id = card.cardId()
      if id.len > 0:
        return id

proc firstCardId(cards: JsonNode): string =
  ## Returns the first affordable and prerequisite-valid card id.
  if cards == nil or cards.kind != JArray:
    return ""
  result = cards.firstMatchingCardId(CookingTerms)
  if result.len > 0:
    return
  result = cards.firstMatchingCardId(FoodTerms)
  if result.len > 0:
    return
  for card in cards:
    if card.affordableCard():
      let id = card.cardId()
      if id.len > 0:
        return id

proc makeIntArray(value: int): JsonNode =
  ## Builds a one-item integer array.
  result = newJArray()
  result.add %value

proc hasString(node: JsonNode, value: string): bool =
  ## Returns true when an array contains one string value.
  if node == nil or node.kind != JArray:
    return false
  for item in node:
    if item.kind == JString and item.getStr() == value:
      return true

proc countSpaces(player: JsonNode, kind: string): int =
  ## Counts farm spaces of one kind.
  let spaces = player.field("spaces")
  if spaces.kind != JArray:
    return
  for space in spaces:
    if space.strField("kind") == kind:
      inc result

proc isEmptySpace(player: JsonNode, index: int): bool =
  ## Returns true when one farm space can hold a new farm feature.
  let spaces = player.field("spaces")
  if spaces.kind != JArray or index < 0 or index >= spaces.len:
    return false
  spaces[index].strField("kind") == "empty"

proc firstEmptySpace(player: JsonNode): int =
  ## Returns the first empty farm space.
  let spaces = player.field("spaces")
  if spaces.kind != JArray:
    return -1
  for i in 0 ..< spaces.len:
    if player.isEmptySpace(i):
      return i
  -1

proc firstFieldSpace(message: JsonNode): int =
  ## Returns a legal or obvious empty field space.
  result = message.observationChoices().field("legalFields").firstArrayInt()
  if result >= 0:
    return
  result = message.playerNode().firstEmptySpace()

proc firstStableSpace(message: JsonNode): int =
  ## Returns a legal or obvious empty stable space.
  result = message.observationChoices().field("legalStables").firstArrayInt()
  if result >= 0:
    return
  let
    player = message.playerNode()
    resources = player.field("resources")
  if resources.intField("wood") < 2:
    return -1
  result = player.firstEmptySpace()

proc edgeArray(edges: openArray[string]): JsonNode =
  ## Builds a JSON array of fence edge ids.
  result = newJArray()
  for edge in edges:
    result.add %edge

proc cellFenceEdges(index: int): JsonNode =
  ## Builds the four fence edges around one farm cell.
  let
    row = index div FarmCols
    col = index mod FarmCols
  edgeArray([
    "h-" & $row & "-" & $col,
    "h-" & $(row + 1) & "-" & $col,
    "v-" & $row & "-" & $col,
    "v-" & $row & "-" & $(col + 1)
  ])

proc twoCellFenceEdges(row, col: int): JsonNode =
  ## Builds the six fence edges around two horizontal cells.
  edgeArray([
    "h-" & $row & "-" & $col,
    "h-" & $row & "-" & $(col + 1),
    "h-" & $(row + 1) & "-" & $col,
    "h-" & $(row + 1) & "-" & $(col + 1),
    "v-" & $row & "-" & $col,
    "v-" & $row & "-" & $(col + 2)
  ])

proc firstFenceEdges(choices: JsonNode): JsonNode =
  ## Returns the first server-suggested fence edge list.
  let plans = choices.field("fencePlans")
  if plans.kind == JArray and plans.len > 0:
    let edges = plans[0].field("edges")
    if edges.kind == JArray:
      return edges
  newJArray()

proc simpleFenceEdges(message: JsonNode): JsonNode =
  ## Returns a server-suggested or raw-state first pasture fence plan.
  result = message.observationChoices().firstFenceEdges()
  if result.arrayLen() > 0:
    return
  let
    player = message.playerNode()
    resources = player.field("resources")
    wood = resources.intField("wood")
  if player.field("fences").arrayLen() > 0:
    return newJArray()
  if wood >= 6:
    for row in 0 ..< FarmRows:
      for col in 0 ..< FarmCols - 1:
        let
          left = row * FarmCols + col
          right = left + 1
        if player.isEmptySpace(left) and player.isEmptySpace(right):
          return twoCellFenceEdges(row, col)
  if wood >= 4:
    let space = player.firstEmptySpace()
    if space >= 0:
      return cellFenceEdges(space)
  result = newJArray()

proc canAffordMajor(resources: JsonNode, id: string): bool =
  ## Returns true when resources can buy one major improvement.
  case id
  of "fireplace2":
    resources.intField("clay") >= 2
  of "fireplace3":
    resources.intField("clay") >= 3
  of "clay_oven":
    resources.intField("clay") >= 3 and resources.intField("stone") >= 1
  of "stone_oven":
    resources.intField("clay") >= 1 and resources.intField("stone") >= 3
  of "well":
    resources.intField("wood") >= 1 and resources.intField("stone") >= 3
  else:
    false

proc affordableMajorFromState(message: JsonNode): string =
  ## Returns the best raw-state major improvement id.
  let
    state = message.observationState()
    available = state.field("majorsAvailable")
    resources = message.playerNode().field("resources")
  for id in ["fireplace2", "fireplace3", "clay_oven", "stone_oven", "well"]:
    if available.hasString(id) and resources.canAffordMajor(id):
      return id

proc improvementChoice(
  choices: JsonNode,
  allowMajor,
  allowMinor: bool
): JsonNode =
  ## Builds the simplest affordable improvement choice from legal cards.
  if allowMajor:
    let major = choices.field("majors").firstMatchingCardId(CookingTerms)
    if major.len > 0:
      return %*{"kind": "major", "card": major}
  if allowMinor:
    let minor = choices.field("handMinors").firstCardId()
    if minor.len > 0:
      return %*{"kind": "minor", "card": minor}
  if allowMajor:
    let major = choices.field("majors").firstCardId()
    if major.len > 0:
      return %*{"kind": "major", "card": major}
  newJNull()

proc bestImprovementChoice(
  message: JsonNode,
  allowMajor,
  allowMinor: bool
): JsonNode =
  ## Builds the best affordable improvement choice from choices or raw state.
  result = message.observationChoices().improvementChoice(
    allowMajor,
    allowMinor
  )
  if result.kind == JObject:
    return
  if allowMajor:
    let major = message.affordableMajorFromState()
    if major.len > 0:
      return %*{"kind": "major", "card": major}
  result = newJNull()

proc sowFallback(message: JsonNode): JsonNode =
  ## Builds the simplest sow array from currently owned crops.
  let
    choices = message.observationChoices()
    space = choices.field("sowableFields").firstArrayInt()
    crop = message.playerNode().ownedCrop()
  result = newJArray()
  if space >= 0 and crop.len > 0:
    result.add %*{"space": space, "crop": crop}

proc bakeFallback(message: JsonNode): JsonNode =
  ## Builds the simplest bake array from the first bake option.
  let
    choices = message.observationChoices()
    player = message.playerNode()
    grain = player.field("resources").intField("grain")
    options = choices.field("bakeOptions")
  result = newJArray()
  if grain <= 0 or options.kind != JArray or options.len == 0:
    return
  let option = options[0]
  let card = option.strField("card")
  if card.len == 0:
    return
  let count = min(grain, max(1, option.intField("maxGrain", 1)))
  result.add %*{"card": card, "grain": count}

proc turnsToHarvest(round: int): int =
  ## Returns the number of rounds until the next harvest round.
  for harvestRound in HarvestRounds:
    if round <= harvestRound:
      return harvestRound - round
  0

proc foodShortfall(message: JsonNode): int =
  ## Returns the visible food gap for the next harvest.
  let
    choices = message.observationChoices()
    player = message.playerNode()
    food = player.field("resources").intField("food")
  max(0, choices.intField("foodNeededNow") - food)

proc hasAnyGood(node: JsonNode, goods: openArray[string]): bool =
  ## Returns true when a goods object has any positive named good.
  if node == nil or node.kind != JObject:
    return false
  for good in goods:
    if node.intField(good) > 0:
      return true

proc hasAnimals(player: JsonNode): bool =
  ## Returns true when the player has any animal.
  player.field("animals").hasAnyGood(AnimalGoods)

proc hasCrops(player: JsonNode): bool =
  ## Returns true when the player has grain or vegetables.
  player.field("resources").hasAnyGood(CropGoods)

proc hasFences(player: JsonNode): bool =
  ## Returns true when the player has any fence edge.
  player.field("fences").arrayLen() > 0

proc idMatchesTerms(id: string, terms: openArray[string]): bool =
  ## Returns true when one id contains any search term.
  let text = id.toLowerAscii()
  for term in terms:
    if text.contains(term):
      return true

proc hasCardTerm(player: JsonNode, terms: openArray[string]): bool =
  ## Returns true when played cards include one search term.
  for fieldName in ["majors", "minors", "occupations"]:
    let cards = player.field(fieldName)
    if cards.kind != JArray:
      continue
    for card in cards:
      let id = card.cardId()
      if id.idMatchesTerms(terms):
        return true

proc hasCookingEngine(player: JsonNode): bool =
  ## Returns true when played cards suggest reliable cooking.
  player.hasCardTerm(CookingTerms) or player.hasCardTerm(FoodTerms)

proc freeRooms(player: JsonNode): int =
  ## Returns the number of empty family slots in built rooms.
  max(0, player.countSpaces("room") - player.field("family").arrayLen())

proc familyGrowthOk(message: JsonNode): bool =
  ## Returns true when family growth appears legal from choices or state.
  if message.observationChoices().boolField("familyGrowthOk"):
    return true
  message.playerNode().freeRooms() > 0

proc canChooseImprovement(message: JsonNode): bool =
  ## Returns true when an improvement action has a legal card choice.
  message.bestImprovementChoice(true, true).kind == JObject

proc canFence(message: JsonNode): bool =
  ## Returns true when a legal fence plan is available.
  message.simpleFenceEdges().arrayLen() > 0

proc canBuildRoom(message: JsonNode): bool =
  ## Returns true when a legal room placement exists.
  message.observationChoices().field("legalRooms").firstArrayInt() >= 0

proc canBuildStable(message: JsonNode): bool =
  ## Returns true when a legal stable placement exists.
  message.firstStableSpace() >= 0

proc canPlow(message: JsonNode): bool =
  ## Returns true when a legal field placement exists.
  message.firstFieldSpace() >= 0

proc canSow(message: JsonNode): bool =
  ## Returns true when a simple sowing fallback can be built.
  message.sowFallback().arrayLen() > 0

proc canBake(message: JsonNode): bool =
  ## Returns true when a simple baking fallback can be built.
  message.bakeFallback().arrayLen() > 0

proc availableActionIds(message: JsonNode): seq[string] =
  ## Returns all currently open action-space IDs.
  let options = message.observationOptions()
  if options.kind != JArray:
    return
  for option in options:
    if option.boolField("available"):
      let id = option.strField("id")
      if id.len > 0:
        result.add id

proc sortedUnique(values: seq[string]): seq[string] =
  ## Returns sorted unique text values.
  result = values
  result.sort()
  var writeIdx = 0
  for value in result:
    if writeIdx == 0 or result[writeIdx - 1] != value:
      result[writeIdx] = value
      inc writeIdx
  result.setLen(writeIdx)

proc textList(values: seq[string], limit = 16): string =
  ## Formats a compact list for log output.
  if values.len == 0:
    return "none"
  var parts: seq[string]
  for i in 0 ..< min(values.len, limit):
    parts.add values[i]
  if values.len > limit:
    parts.add "..."
  parts.join(",")

proc missingText(left, right: seq[string]): seq[string] =
  ## Returns values present in left and absent from right.
  for value in left:
    var found = false
    for other in right:
      if value == other:
        found = true
        break
    if not found:
      result.add value

proc isAvailable(message: JsonNode, action: string): bool =
  ## Returns true when one action-space id is currently legal.
  for id in message.availableActionIds():
    if id == action:
      return true

proc bestPileAction(message: JsonNode, good: string): string =
  ## Returns the open pile action with the largest amount of one good.
  let options = message.observationOptions()
  var bestAmount = 0
  if options.kind != JArray:
    return ""
  for option in options:
    if not option.boolField("available"):
      continue
    let amount = option.field("pile").intField(good)
    if amount > bestAmount:
      bestAmount = amount
      result = option.strField("id")

proc bestFoodAction(message: JsonNode): string =
  ## Returns the best visible open food action for emergency feeding.
  result = message.bestPileAction("food")
  if result.len > 0:
    return
  for action in ["fishing", "day_laborer", "traveling_players"]:
    if message.isAvailable(action):
      return action

proc firstOccupation(message: JsonNode): string =
  ## Returns the first playable occupation id from choices or raw hand state.
  result = message.observationChoices().field("handOccupations").firstCardId()
  if result.len > 0:
    return
  let hand = message.playerNode().field("handOccupations")
  result = hand.firstMatchingCardId(CookingTerms)
  if result.len > 0:
    return
  result = hand.firstMatchingCardId(FoodTerms)
  if result.len > 0:
    return
  result = hand.firstCardId()

proc canFallbackAction(message: JsonNode, action: string): bool =
  ## Returns true when Terra can build required parameters for an action.
  case action
  of "farm_expansion":
    message.canBuildRoom() or message.canBuildStable()
  of "farmland":
    message.canPlow()
  of "lessons", "lessons_b":
    message.firstOccupation().len > 0
  of "r_improvement":
    message.canChooseImprovement()
  of "r_fences":
    message.canFence()
  of "r_sow_bake":
    message.canSow() or message.canBake()
  of "r_cultivation":
    message.canPlow() or message.canSow()
  else:
    true

proc firstAvailableAny(message: JsonNode): string =
  ## Returns the first open action-space id.
  let available = message.availableActionIds()
  if available.len > 0:
    return available[0]

proc priorityAction(message: JsonNode): string =
  ## Returns a high-confidence strategic action when one is available.
  let
    player = message.playerNode()
    resources = player.field("resources")
    round = message.observationState().intField("round")
    urgentFood = message.foodShortfall() > 0 and round.turnsToHarvest() <= 1
    foodSafe = message.foodShortfall() == 0
  if urgentFood:
    if message.isAvailable("r_improvement") and
      message.canChooseImprovement() and player.hasAnimals():
        return "r_improvement"
    if message.isAvailable("meeting_place") and
      message.canChooseImprovement() and player.hasAnimals():
        return "meeting_place"
    result = message.bestFoodAction()
    if result.len > 0:
      return
  if message.isAvailable("r_improvement") and
    message.canChooseImprovement() and
    (round <= 8 or player.hasAnimals()):
      return "r_improvement"
  if message.isAvailable("meeting_place") and
    message.canChooseImprovement() and round <= 6:
      return "meeting_place"
  if message.isAvailable("r_fences") and
    message.canFence() and
    not player.hasFences() and resources.intField("wood") >= 4:
      return "r_fences"
  if message.isAvailable("r_family_growth") and
    message.familyGrowthOk() and
    foodSafe and
    (player.hasCookingEngine() or player.hasFences() or round >= 10):
      return "r_family_growth"

proc firstAvailableAction(message: JsonNode): string =
  ## Chooses an open action using Terra's emergency priorities.
  let
    player = message.playerNode()
    resources = player.field("resources")
    round = message.observationState().intField("round")
    foodSafe = message.foodShortfall() == 0
  result = message.priorityAction()
  if result.len > 0:
    return
  if message.isAvailable("farm_expansion") and
    (message.canBuildRoom() or message.canBuildStable()) and
    (foodSafe or round <= 5):
      return "farm_expansion"
  if message.isAvailable("r_sow_bake") and
    (message.canSow() or message.canBake()):
      return "r_sow_bake"
  if message.isAvailable("r_cultivation") and
    (message.canPlow() or message.canSow()):
      return "r_cultivation"
  if message.isAvailable("farmland") and message.canPlow():
    return "farmland"
  if message.isAvailable("lessons") and
    message.firstOccupation().len > 0:
      return "lessons"
  if message.isAvailable("lessons_b") and
    message.firstOccupation().len > 0:
      return "lessons_b"
  if message.foodShortfall() > 0:
    result = message.bestFoodAction()
    if result.len > 0:
      return
  if not player.hasFences() and resources.intField("wood") < 6:
    result = message.bestPileAction("wood")
    if result.len > 0:
      return
  if not player.hasCrops() and message.isAvailable("grain_seeds"):
    return "grain_seeds"
  for simple in SimpleActions:
    if message.isAvailable(simple) and message.canFallbackAction(simple):
      return simple
  return message.firstAvailableAny()

proc fallbackPlacementForAction(message: JsonNode, action: string): JsonNode =
  ## Builds the simplest placement Terra can form for one action.
  let
    choices = message.observationChoices()
  result = newJObject()
  result["action"] = %action
  case action
  of "farm_expansion":
    let room = choices.field("legalRooms").firstArrayInt()
    if room >= 0:
      result["rooms"] = room.makeIntArray()
    else:
      let stable = message.firstStableSpace()
      if stable >= 0:
        result["stables"] = stable.makeIntArray()
  of "farmland":
    let space = message.firstFieldSpace()
    if space >= 0:
      result["spaces"] = space.makeIntArray()
  of "lessons", "lessons_b":
    let occupation = message.firstOccupation()
    if occupation.len > 0:
      result["occupation"] = %occupation
  of "meeting_place":
    let improvement = message.bestImprovementChoice(true, true)
    if improvement.kind == JObject:
      result["improvement"] = improvement
  of "r_improvement":
    let improvement = message.bestImprovementChoice(true, true)
    if improvement.kind == JObject:
      result["improvement"] = improvement
  of "r_renovate_improve":
    let improvement = message.bestImprovementChoice(true, true)
    if improvement.kind == JObject:
      result["improvement"] = improvement
  of "r_family_growth":
    let improvement = message.bestImprovementChoice(false, true)
    if improvement.kind == JObject:
      result["improvement"] = improvement
  of "r_fences":
    result["edges"] = message.simpleFenceEdges()
  of "r_sow_bake":
    let
      sow = message.sowFallback()
      bake = message.bakeFallback()
    if sow.len > 0:
      result["sow"] = sow
    if bake.len > 0:
      result["bake"] = bake
  of "r_cultivation":
    let plow = message.firstFieldSpace()
    if plow >= 0:
      result["plow"] = %plow
    let sow = message.sowFallback()
    if sow.len > 0:
      result["sow"] = sow
  of "r_redevelop":
    result["edges"] = message.simpleFenceEdges()
  else:
    discard

proc fallbackPlacement(message: JsonNode): JsonNode =
  ## Builds the simplest placement Terra can form from server choices.
  message.fallbackPlacementForAction(message.firstAvailableAction())

proc addFeedingConversion(
  conversions: JsonNode,
  option: JsonNode,
  count: int
) =
  ## Adds one legal feeding conversion.
  if count <= 0:
    return
  conversions.add %*{
    "via": option.strField("via"),
    "good": option.strField("good"),
    "count": count
  }

proc useFeedingOption(
  conversions: JsonNode,
  options: JsonNode,
  used: var seq[int],
  good,
  via: string,
  shortfall: var int,
  maxAllowed = high(int)
) =
  ## Uses one kind of feeding option while tracking consumed option capacity.
  if shortfall <= 0 or options.kind != JArray:
    return
  var allowed = maxAllowed
  for i in 0 ..< options.len:
    if shortfall <= 0 or allowed <= 0:
      return
    let option = options[i]
    if option.strField("good") != good:
      continue
    if via.len > 0 and option.strField("via") != via:
      continue
    let
      foodEach = max(1, option.intField("foodEach"))
      remaining = max(0, option.intField("max") - used[i])
      available = min(remaining, allowed)
      count = min(available, shortfall.ceilDiv(foodEach))
    if count <= 0:
      continue
    conversions.addFeedingConversion(option, count)
    used[i] += count
    allowed -= count
    shortfall = max(0, shortfall - count * foodEach)

proc goodCount(player: JsonNode, good: string): int =
  ## Returns the visible count for one resource or animal good.
  if good in AnimalGoods:
    return player.field("animals").intField(good)
  player.field("resources").intField(good)

proc useHarvestFeeding(
  conversions: JsonNode,
  options: JsonNode,
  used: var seq[int],
  player: JsonNode,
  shortfall: var int
) =
  ## Uses TypeScript auto-feed harvest resource conversions first.
  if shortfall <= 0 or options.kind != JArray:
    return
  for i in 0 ..< options.len:
    if shortfall <= 0:
      return
    let
      option = options[i]
      good = option.strField("good")
    if good in CropGoods or good in AnimalGoods:
      continue
    let spare = max(0, player.goodCount(good) - 2)
    conversions.useFeedingOption(
      options,
      used,
      good,
      option.strField("via"),
      shortfall,
      spare
    )

proc fallbackFeeding(message: JsonNode): JsonNode =
  ## Builds a feeding decision matching the TypeScript auto-feed order.
  let
    choices = message.observationChoices()
    player = message.playerNode()
    options = message.feedingOptions()
  var shortfall = max(
    0,
    message.feedingNeed(choices, player) -
      player.field("resources").intField("food")
  )
  result = newJObject()
  result["conversions"] = newJArray()
  var used: seq[int]
  used.setLen(options.arrayLen())
  result["conversions"].useHarvestFeeding(
    options,
    used,
    player,
    shortfall
  )
  result["conversions"].useFeedingOption(
    options,
    used,
    "grain",
    "raw",
    shortfall
  )
  for good in AnimalGoods:
    result["conversions"].useFeedingOption(
      options,
      used,
      good,
      "",
      shortfall,
      max(0, player.goodCount(good) - 2)
    )
  result["conversions"].useFeedingOption(
    options,
    used,
    "vegetable",
    "raw",
    shortfall
  )
  for good in AnimalGoods:
    result["conversions"].useFeedingOption(
      options,
      used,
      good,
      "",
      shortfall
    )

proc newBotMind(
  solverEnabled: bool,
  solverIterations,
  solverMaxMoves,
  solverTimeMs,
  solverThreads: int
): BotMind =
  ## Creates bot state for native solver decisions.
  result.solverEnabled = solverEnabled
  result.solverIterations = solverIterations
  result.solverMaxMoves = solverMaxMoves
  result.solverTimeMs = solverTimeMs
  result.solverThreads = solverThreadCount(solverThreads)
  result.policyGoal = solverPolicy.GoalBalance
  result.lastStrategyRound = -1

proc recordServerError(mind: var BotMind, message: string) =
  ## Records one server validation error.
  if message.len == 0:
    return
  mind.lastServerError = message
  inc mind.serverErrors

proc clearServerError(mind: var BotMind) =
  ## Clears server validation state after progress is accepted.
  mind.lastServerError = ""
  mind.serverErrors = 0

proc validatePlacement(
  message: JsonNode,
  args: JsonNode
): tuple[ok: bool, error: string] =
  ## Validates the basic placement shape and server action availability.
  if args.kind != JObject:
    return (false, "placement arguments must be an object")
  let action = args.strField("action")
  if action.len == 0:
    return (false, "placement.action is required")
  if not message.isAvailable(action):
    return (false, "action is not available: " & action)
  case action
  of "farm_expansion":
    if args.field("rooms").arrayLen() == 0 and
      args.field("stables").arrayLen() == 0:
        return (false, "farm_expansion needs rooms or stables")
  of "farmland":
    if args.field("spaces").arrayLen() == 0:
      return (false, "farmland needs spaces")
  of "lessons", "lessons_b":
    if args.strField("occupation").len == 0:
      return (false, action & " needs occupation")
  of "r_improvement":
    if args.field("improvement").kind != JObject:
      return (false, "r_improvement needs improvement")
  of "r_fences":
    if args.field("edges").arrayLen() == 0:
      return (false, "r_fences needs edges")
  of "r_sow_bake":
    if args.field("sow").arrayLen() == 0 and
      args.field("bake").arrayLen() == 0:
        return (false, "r_sow_bake needs sow or bake")
  of "r_cultivation":
    if args.field("plow").kind notin {JInt, JFloat} and
      args.field("sow").arrayLen() == 0:
        return (false, "r_cultivation needs plow or sow")
  else:
    discard
  (true, "")

proc validateFeeding(args: JsonNode): tuple[ok: bool, error: string] =
  ## Validates the basic feeding decision shape.
  if args.kind != JObject:
    return (false, "feeding arguments must be an object")
  if args.field("conversions").kind != JArray:
    return (false, "conversions must be an array")
  for conversion in args.field("conversions"):
    if conversion.kind != JObject:
      return (false, "each conversion must be an object")
    if conversion.strField("via").len == 0:
      return (false, "conversion.via is required")
    if conversion.strField("good").len == 0:
      return (false, "conversion.good is required")
    if conversion.field("count").kind notin {JInt, JFloat}:
      return (false, "conversion.count is required")
  (true, "")

proc stringItems(node: JsonNode): seq[string] =
  ## Returns all string-like values from a JSON array.
  if node == nil or node.kind != JArray:
    return
  for item in node:
    let value = item.scalarText()
    if value.len > 0:
      result.add value

proc cardItems(node: JsonNode): seq[solver.CardId] =
  ## Returns known solver card ids from a JSON array.
  for value in node.stringItems():
    let id = value.parseCardId()
    if id != solver.NoCard:
      result.add id

proc parseSolverEdges(node: JsonNode): seq[solver.EdgeId] =
  ## Parses server fence edge strings for the solver.
  for value in node.stringItems():
    let parsed = solver.parseEdgeId(value)
    if parsed.ok:
      result.add parsed.edge

proc parseSolverResource(name: string):
    tuple[ok: bool, value: solver.Resource] =
  ## Parses one resource name for the solver.
  case name
  of "wood":
    (true, solver.Wood)
  of "clay":
    (true, solver.Clay)
  of "reed":
    (true, solver.Reed)
  of "stone":
    (true, solver.Stone)
  of "grain":
    (true, solver.Grain)
  of "vegetable":
    (true, solver.Vegetable)
  of "food":
    (true, solver.Food)
  else:
    (false, solver.Wood)

proc parseSolverAnimal(name: string): tuple[ok: bool, value: solver.Animal] =
  ## Parses one animal name for the solver.
  case name
  of "sheep":
    (true, solver.Sheep)
  of "boar":
    (true, solver.Boar)
  of "cattle":
    (true, solver.Cattle)
  else:
    (false, solver.Sheep)

proc parseSolverAction(id: string): tuple[ok: bool, value: solver.ActionId] =
  ## Parses one Agricogla action-space id for the solver.
  case id
  of "farm_expansion":
    (true, solver.FarmExpansion)
  of "meeting_place":
    (true, solver.MeetingPlace)
  of "grain_seeds":
    (true, solver.GrainSeeds)
  of "farmland":
    (true, solver.Farmland)
  of "lessons":
    (true, solver.Lessons)
  of "day_laborer":
    (true, solver.DayLaborer)
  of "forest":
    (true, solver.Forest)
  of "clay_pit":
    (true, solver.ClayPit)
  of "reed_bank":
    (true, solver.ReedBank)
  of "fishing":
    (true, solver.Fishing)
  of "copse":
    (true, solver.Copse)
  of "grove":
    (true, solver.Grove)
  of "hollow":
    (true, solver.Hollow)
  of "quarry_stall":
    (true, solver.QuarryStall)
  of "resource_market":
    (true, solver.ResourceMarket)
  of "traveling_players":
    (true, solver.TravelingPlayers)
  of "lessons_b":
    (true, solver.LessonsB)
  of "r_improvement":
    (true, solver.RImprovement)
  of "r_sheep":
    (true, solver.RSheep)
  of "r_fences":
    (true, solver.RFences)
  of "r_sow_bake":
    (true, solver.RSowBake)
  of "r_west_quarry":
    (true, solver.RWestQuarry)
  of "r_renovate_improve":
    (true, solver.RRenovateImprove)
  of "r_family_growth":
    (true, solver.RFamilyGrowth)
  of "r_vegetable":
    (true, solver.RVegetable)
  of "r_boar":
    (true, solver.RBoar)
  of "r_east_quarry":
    (true, solver.REastQuarry)
  of "r_cattle":
    (true, solver.RCattle)
  of "r_urgent_family":
    (true, solver.RUrgentFamily)
  of "r_cultivation":
    (true, solver.RCultivation)
  of "r_redevelop":
    (true, solver.RRedevelop)
  else:
    (false, solver.DayLaborer)

proc isRoundAction(action: solver.ActionId): bool =
  ## Returns true when an action is a round-card action.
  for stage in 1 .. 6:
    for card in solver.roundCardsForStage(stage):
      if card == action:
        return true

proc removeAction(actions: var seq[solver.ActionId], action: solver.ActionId) =
  ## Removes one action from a small action list.
  for i in 0 ..< actions.len:
    if actions[i] == action:
      actions.delete(i)
      return

proc sampledScenarioRoundDeck(
  state: solver.GameState,
  seed: int
): seq[solver.ActionId] =
  ## Samples a plausible future round-card scenario from revealed spaces.
  var rng = solver.initRng(seed)
  for stage in 1 .. 6:
    var cards = solver.roundCardsForStage(stage)
    for space in state.actionSpaces:
      if space.id.isRoundAction():
        cards.removeAction(space.id)
    result.add rng.shuffled(cards)

proc hiddenScenarioSeed(message, source: JsonNode): int =
  ## Returns a seed for sampled hidden-deck scenarios only.
  result = 0x51A3CE
  result = result xor message.observationId()
  result = result xor (source.intField("round") shl 8)
  result = result xor (source.intField("currentPlayer") shl 16)
  result = result xor (source.intField("startingPlayer") shl 20)
  result = result xor (source.intField("numPlayers", 2) shl 24)

proc parseSolverGoods(node: JsonNode): solver.Goods =
  ## Parses resources and animals from one JSON goods object.
  if node == nil or node.kind != JObject:
    return
  for key, value in node.pairs:
    let count = value.intValue()
    if count <= 0:
      continue
    let resource = key.parseSolverResource()
    if resource.ok:
      result.resources[resource.value] = count
      continue
    let animal = key.parseSolverAnimal()
    if animal.ok:
      result.animals[animal.value] = count

proc parseSolverFarmSpace(node: JsonNode): solver.FarmSpace =
  ## Parses one farmyard space into the solver representation.
  result.kind =
    case node.strField("kind")
    of "room":
      solver.Room
    of "field":
      solver.Field
    else:
      solver.Empty
  result.stable = node.boolField("stable")
  result.crop =
    case node.strField("crop")
    of "grain":
      solver.GrainCrop
    of "vegetable":
      solver.VegetableCrop
    else:
      solver.NoCrop
  result.cropCount = node.intField("cropCount")

proc parseSolverHouseMaterial(value: string): solver.HouseMaterial =
  ## Parses one house material.
  case value
  of "clay":
    solver.HouseClay
  of "stone":
    solver.HouseStone
  else:
    solver.HouseWood

proc parseSolverPhase(value: string): solver.Phase =
  ## Parses one game phase.
  case value
  of "feeding":
    solver.Feeding
  of "finished":
    solver.Finished
  else:
    solver.Work

proc solverHandsVisible(node: JsonNode, idx, perspective: int): bool =
  ## Returns true when a player hand is honestly visible.
  if idx == perspective:
    return true
  if node.boolField("handVisible") or
      node.boolField("handsVisible") or
      node.boolField("handRevealed") or
      node.boolField("publicHand"):
    return true
  let visibility = node.strField("handVisibility")
  visibility in ["public", "visible", "revealed"]

proc parseSolverPlayer(
  node: JsonNode,
  idx,
  perspective: int
): solver.PlayerState =
  ## Parses one player state from the server observation.
  let handsVisible = node.solverHandsVisible(idx, perspective)
  var
    handOccupations: seq[solver.CardId]
    handMinors: seq[solver.CardId]
  if handsVisible:
    handOccupations = node.field("handOccupations").cardItems()
    handMinors = node.field("handMinors").cardItems()
  result = solver.PlayerState(
    idx: node.intField("idx", idx),
    resources: node.field("resources").parseSolverGoods().resources,
    animals: node.field("animals").parseSolverGoods().animals,
    fences: node.field("fences").parseSolverEdges(),
    fencesBuilt: node.intField("fencesBuilt"),
    houseMaterial: node.strField("houseMaterial").parseSolverHouseMaterial(),
    beggingCards: node.intField("beggingCards"),
    startingPlayerMarker: node.boolField("startingPlayerMarker"),
    handOccupations: handOccupations,
    handMinors: handMinors,
    occupations: node.field("occupations").cardItems(),
    minors: node.field("minors").cardItems(),
    majors: node.field("majors").cardItems()
  )
  let spaces = node.field("spaces")
  if spaces.kind == JArray:
    for i in 0 ..< min(solver.NumSpaces, spaces.len):
      result.spaces[i] = spaces[i].parseSolverFarmSpace()
  let family = node.field("family")
  if family.kind == JArray:
    for member in family:
      result.family.add solver.FamilyMember(
        bornRound: member.intField("bornRound"),
        placed: member.boolField("placed")
      )

proc parseSolverActionSpace(node: JsonNode):
    tuple[ok: bool, value: solver.ActionSpace] =
  ## Parses one action-space state.
  let parsed = node.strField("id").parseSolverAction()
  if not parsed.ok:
    return (false, solver.ActionSpace())
  var occupiedBy = solver.NoPlayer
  let occupied = node.field("occupiedBy")
  if occupied.kind in {JInt, JFloat}:
    occupiedBy = occupied.intValue(solver.NoPlayer)
  (true, solver.ActionSpace(
    id: parsed.value,
    occupiedBy: occupiedBy,
    pile: node.field("pile").parseSolverGoods()
  ))

proc parseSolverScheduled(node: JsonNode):
    tuple[ok: bool, value: solver.ScheduledGoods] =
  ## Parses one future scheduled good record.
  var goods: solver.Goods
  let count = node.intField("count")
  let resource = node.strField("good").parseSolverResource()
  if resource.ok:
    goods.resources[resource.value] = count
  else:
    let animal = node.strField("good").parseSolverAnimal()
    if not animal.ok:
      return (false, solver.ScheduledGoods())
    goods.animals[animal.value] = count
  (true, solver.ScheduledGoods(
    round: node.intField("round"),
    playerIdx: node.intField("playerIdx"),
    goods: goods
  ))

proc parseSolverState(message: JsonNode, perspective: int):
    tuple[ok: bool, state: solver.GameState, error: string] =
  ## Converts the server observation into native solver state.
  let source = message.observationState()
  if source.kind != JObject:
    return (false, solver.GameState(), "missing observation state")
  let rawSeed = source.intField("seed", 0)
  let seed =
    if rawSeed != 0:
      rawSeed
    else:
      message.observationId() xor
        (source.intField("round") shl 8) xor
        (source.intField("currentPlayer") shl 16)
  result.state = solver.GameState(
    seed: seed,
    numPlayers: source.intField("numPlayers", 2),
    solo: source.boolField("solo"),
    round: source.intField("round"),
    phase: source.strField("phase").parseSolverPhase(),
    startingPlayer: source.intField("startingPlayer"),
    currentPlayer: source.intField("currentPlayer"),
    majorsAvailable: source.field("majorsAvailable").cardItems()
  )
  let toFeed = source.field("toFeed")
  if toFeed.kind == JArray:
    for item in toFeed:
      result.state.toFeed.add item.intValue()
  let spaces = source.field("actionSpaces")
  if spaces.kind == JArray:
    for space in spaces:
      let parsed = space.parseSolverActionSpace()
      if parsed.ok:
        result.state.actionSpaces.add parsed.value
      else:
        echo "B11 id=",
          space.strField("id")
  var hiddenDeck = false
  let deck = source.field("roundDeck")
  if deck.kind == JArray:
    for card in deck:
      let parsed = card.scalarText().parseSolverAction()
      if parsed.ok:
        result.state.roundDeck.add parsed.value
      else:
        hiddenDeck = true
  if hiddenDeck or (
    result.state.roundDeck.len == 0 and
    result.state.round < solver.TotalRounds
  ):
    result.state.roundDeck = result.state.sampledScenarioRoundDeck(
      message.hiddenScenarioSeed(source)
    )
    echo "B12 len=",
      result.state.roundDeck.len
  let scheduled = source.field("scheduled")
  if scheduled.kind == JArray:
    for item in scheduled:
      let parsed = item.parseSolverScheduled()
      if parsed.ok:
        result.state.scheduled.add parsed.value
  let players = source.field("players")
  if players.kind != JArray or players.len == 0:
    return (false, solver.GameState(), "missing players")
  for i in 0 ..< players.len:
    result.state.players.add players[i].parseSolverPlayer(i, perspective)
  if result.state.numPlayers != result.state.players.len:
    echo "B13 numPlayers=",
      result.state.numPlayers,
      " playersLen=",
      result.state.players.len,
      " using playersLen"
    result.state.numPlayers = result.state.players.len
    result.state.solo = result.state.numPlayers == 1
  result.ok = true

proc remainingDecisionMs(started: MonoTime, maxMs: int): int =
  ## Returns the remaining solver decision budget.
  let elapsed = inMilliseconds(getMonoTime() - started)
  if elapsed >= maxMs.int64:
    return 0
  max(0, maxMs - elapsed.int)

proc observationTimeLeftMs(message: JsonNode): int =
  ## Returns remaining chess-clock ms, or -1 when the host sent no clock.
  let child = message.field("timeLeftMs")
  case child.kind
  of JInt, JFloat:
    max(0, child.intValue())
  else:
    -1

proc estimatedRemainingPlacements(
  state: solver.GameState,
  perspective: int
): int =
  ## Overestimates remaining worker placements so think-time stays conservative.
  if perspective < 0 or perspective >= state.players.len:
    return SolverClockFloorMoves
  let
    player = state.players[perspective]
    family = max(1, player.family.len)
    roundsAfter = max(0, solver.TotalRounds - state.round)
    futureFamily = min(solver.MaxFamily, family + 1)
  var unplaced = 0
  for member in player.family:
    if not member.placed:
      inc unplaced
  if unplaced <= 0:
    unplaced = family
  max(SolverClockFloorMoves, unplaced + roundsAfter * futureFamily)

proc clockSearchBudgetMs(
  message: JsonNode,
  state: solver.GameState,
  perspective,
  defaultMs: int
): int =
  ## Caps this move's search so the episode chess clock lasts until round 14.
  let timeLeft = message.observationTimeLeftMs()
  if timeLeft < 0:
    return defaultMs
  if timeLeft <= SolverClockOverheadMs:
    return 0
  let
    remaining = state.estimatedRemainingPlacements(perspective)
    usable = timeLeft - SolverClockOverheadMs
  max(0, min(defaultMs, usable div remaining))

proc estimateMctsScans(sampled, elapsedMs: int): int =
  ## Estimates sampled MCTS iterations for a six-second scan.
  if sampled <= 0:
    return 0
  if elapsedMs <= 0:
    return sampled
  int((sampled.int64 * MctsScanWindowMs.int64) div elapsedMs.int64)

proc intArray(values: seq[int]): JsonNode =
  ## Builds a JSON integer array.
  result = newJArray()
  for value in values:
    result.add %value

proc solverEdgeArray(values: seq[solver.EdgeId]): JsonNode =
  ## Builds a JSON edge array from solver edge ids.
  result = newJArray()
  for value in values:
    result.add %value.edgeName()

proc solverSowArray(choices: seq[solver.SowChoice]): JsonNode =
  ## Builds a JSON sow array from solver choices.
  result = newJArray()
  for choice in choices:
    let crop =
      case choice.crop
      of solver.GrainCrop:
        "grain"
      of solver.VegetableCrop:
        "vegetable"
      of solver.NoCrop:
        ""
    if crop.len > 0:
      result.add %*{"space": choice.space, "crop": crop}

proc solverBakeArray(choices: seq[solver.BakeChoice]): JsonNode =
  ## Builds a JSON bake array from solver choices.
  result = newJArray()
  for choice in choices:
    result.add %*{"card": choice.card.cardName(), "grain": choice.grain}

proc solverImprovementJson(choice: solver.ImprovementChoice): JsonNode =
  ## Builds a JSON improvement choice.
  case choice.kind
  of solver.MajorImprovement:
    result = %*{"kind": "major", "card": choice.card.cardName()}
  of solver.MinorImprovement:
    result = %*{"kind": "minor", "card": choice.card.cardName()}
  of solver.NoImprovement:
    return newJNull()
  if choice.bake.len > 0:
    result["bake"] = choice.bake.solverBakeArray()

proc solverMovePlacement(move: solver.Move): JsonNode =
  ## Converts one solver move into server placement JSON.
  result = newJObject()
  result["action"] = %solver.actionName(move.action)
  case move.action
  of solver.FarmExpansion:
    if move.rooms.len > 0:
      result["rooms"] = move.rooms.intArray()
    if move.stables.len > 0:
      result["stables"] = move.stables.intArray()
  of solver.Farmland:
    result["spaces"] = move.fields.intArray()
  of solver.Lessons, solver.LessonsB:
    result["occupation"] = %move.occupation.cardName()
  of solver.MeetingPlace, solver.RImprovement,
      solver.RRenovateImprove, solver.RFamilyGrowth:
    let improvement = move.improvement.solverImprovementJson()
    if improvement.kind == JObject:
      result["improvement"] = improvement
  of solver.RFences, solver.RRedevelop:
    if move.edges.len > 0:
      result["edges"] = move.edges.solverEdgeArray()
  of solver.RSowBake:
    if move.sow.len > 0:
      result["sow"] = move.sow.solverSowArray()
    if move.bake.len > 0:
      result["bake"] = move.bake.solverBakeArray()
  of solver.RCultivation:
    if move.plow != solver.NoSpace:
      result["plow"] = %move.plow
    if move.sow.len > 0:
      result["sow"] = move.sow.solverSowArray()
  else:
    discard

when defined(release):
  {.push checks: off.}

proc solverMargins(state: solver.GameState): SolverMargins =
  ## Returns final score margins for every player.
  result.count = min(state.players.len, SolverMaxPlayers)
  var scores: array[SolverMaxPlayers, int]
  for i in 0 ..< result.count:
    scores[i] = state.scorePlayer(state.players[i])
  for i in 0 ..< result.count:
    if result.count <= 1:
      result.values[i] = scores[i]
      continue
    var bestOther = low(int)
    for j in 0 ..< result.count:
      if i != j:
        bestOther = max(bestOther, scores[j])
    result.values[i] = scores[i] - bestOther

proc solverPlayerToMove(state: solver.GameState): int =
  ## Returns the player expected to choose at one solver state.
  case state.phase
  of solver.Work:
    state.currentPlayer
  of solver.Feeding:
    if state.toFeed.len > 0:
      state.toFeed[0]
    else:
      solver.NoPlayer
  of solver.Finished:
    solver.NoPlayer

proc solverBiasedPlayoutMove(
  state: solver.GameState,
  options: var solver.MoveBuffer,
  perspective: int,
  goal: solverPolicy.SteeringGoal,
  rng: var solver.Rng
): solver.Move {.raises: [solver.SolverError].} =
  ## Chooses a rollout move with base-policy bias and random exploration.
  if options.len == 0:
    raise newException(solver.SolverError, "No legal moves.")
  let mover = state.solverPlayerToMove()
  if mover != solver.NoPlayer and
      options.moves[0].kind == solver.PlacementMove:
    let bias =
      if mover == perspective:
        SolverSelfRolloutPolicyPct
      else:
        SolverOpponentRolloutPolicyPct
    if rng.randInt(100) < bias:
      let choice = solverPolicy.chooseBasePolicyMove(
        state,
        mover,
        options.moves.toOpenArray(0, options.len - 1),
        if mover == perspective: goal else: solverPolicy.GoalBalance
      )
      if choice.ok:
        return choice.move
  options.moves[rng.randInt(options.len)]

when defined(release):
  {.pop.}

proc solverOpenActions(state: solver.GameState): seq[string] =
  ## Returns open action names from the parsed solver board.
  for space in state.actionSpaces:
    if space.occupiedBy == solver.NoPlayer:
      result.add solver.actionName(space.id)
  result = result.sortedUnique()

proc solverMoveActions(moves: openArray[solver.Move]): seq[string] =
  ## Returns unique action names from solver moves.
  for move in moves:
    if move.kind == solver.PlacementMove:
      result.add solver.actionName(move.action)
  result = result.sortedUnique()

proc solverMoveActions(moves: var solver.MoveBuffer): seq[string] =
  ## Returns unique action names from buffered solver moves.
  for i in 0 ..< moves.len:
    let move = moves.moves[i]
    if move.kind == solver.PlacementMove:
      result.add solver.actionName(move.action)
  result = result.sortedUnique()

proc houseText(material: solver.HouseMaterial): string =
  ## Returns a compact house material label.
  case material
  of solver.HouseWood:
    "wood"
  of solver.HouseClay:
    "clay"
  of solver.HouseStone:
    "stone"

proc goodsText(resources: solver.ResourceCounts): string =
  ## Formats resource counts for solver logs.
  var goods: solver.Goods
  goods.resources = resources
  goods.goodsText()

proc goodsText(animals: solver.AnimalCounts): string =
  ## Formats animal counts for solver logs.
  var goods: solver.Goods
  goods.animals = animals
  goods.goodsText()

proc countKind(player: solver.PlayerState, kind: solver.FarmKind): int =
  ## Counts farm spaces of one kind.
  for space in player.spaces:
    if space.kind == kind:
      inc result

proc stableCount(player: solver.PlayerState): int =
  ## Counts stables in one farmyard.
  for space in player.spaces:
    if space.stable:
      inc result

proc logSolverPlayer(state: solver.GameState, playerIdx: int) =
  ## Logs a compact player state before one solver decision.
  if playerIdx < 0 or playerIdx >= state.players.len:
    return
  let
    player = state.players[playerIdx]
    rooms = player.roomCount()
    freeRooms = max(0, rooms - player.family.len)
    fields = player.countKind(solver.Field)
    empty = player.countKind(solver.Empty)
  var pastures = 0
  try:
    pastures = solver.computePastures(
      player.spaces,
      player.fences
    ).pastureCount
  except CatchableError:
    discard
  echo "B21 p=", playerIdx,
    " family=", player.family.len, "/", solver.MaxFamily,
    " rooms=", rooms,
    " freeRooms=", freeRooms,
    " house=", player.houseMaterial.houseText(),
    " fields=", fields,
    " empty=", empty,
    " pastures=", pastures,
    " stables=", player.stableCount(),
    " fences=", player.fencesBuilt,
    " res=", player.resources.goodsText(),
    " animals=", player.animals.goodsText(),
    " occ=", player.occupations.len,
    " minors=", player.minors.len,
    " majors=", player.majors.len

proc hasPlayedAny(
  player: solver.PlayerState,
  cards: openArray[solver.CardId]
): bool =
  ## Returns true when any listed card has been played.
  for card in cards:
    if player.hasPlayed(card):
      return true

proc hasAnimalCooking(player: solver.PlayerState): bool =
  ## Returns true when one animal type can be cooked.
  for animal in solver.Animal:
    if player.bestCookRate(animal) > 0:
      return true

proc leadingOpponent(
  state: solver.GameState,
  perspective: int
): tuple[player: int, margin: int] {.raises: [solver.SolverError].} =
  ## Returns the current leading opponent and score margin over us.
  result.player = solver.NoPlayer
  if perspective < 0 or perspective >= state.players.len:
    return
  let ownScore = state.scorePlayer(state.players[perspective])
  var bestScore = low(int)
  for i, player in state.players:
    if i == perspective:
      continue
    let score = state.scorePlayer(player)
    if result.player == solver.NoPlayer or score > bestScore:
      bestScore = score
      result.player = i
  if result.player != solver.NoPlayer:
    result.margin = bestScore - ownScore

proc strategyText(
  state: solver.GameState,
  perspective: int,
  anchorGoal,
  activeGoal: solverPolicy.SteeringGoal
): string {.raises: [solver.SolverError].} =
  ## Returns the current high-level strategy declaration.
  if perspective < 0 or perspective >= state.players.len:
    return "unknown"
  let
    player = state.players[perspective]
    rooms = player.roomCount()
    family = player.family.len
    risk = state.feedingRisk(perspective)
    need = solverPolicy.activeBalanceNeed(state, perspective)
    anchorAhead = solverPolicy.anchorGoalAhead(
      state,
      perspective,
      anchorGoal
    )
    fields = solverPolicy.countKind(player, solver.Field)
    unused = solverPolicy.unusedScoringSpaces(player)
    needsRoom = family < 3 and rooms <= family
    hasRanch = player.hasAnimalCooking()
    hasBaking = player.bestBakePower().perGrain >= 3 or
      player.hasPlayedAny([
        solver.OccBaker, solver.OccMiller, solver.MinDoughTrough,
        solver.MinThreshingBoard, solver.MinGrainLoft
      ])
    foodPlan =
      if hasRanch:
        "ranch"
      elif hasBaking:
        "bake"
      else:
        "food_setup"
    backbone =
      if needsRoom:
        "first_room_growth"
      elif family < 4 and state.round <= 11:
        "grow_more"
      elif state.round >= 10:
        "late_score"
      else:
        "balanced_score"
    target = state.leadingOpponent(perspective)
    targetText =
      if target.player == solver.NoPlayer or target.margin <= 0:
        "none"
      else:
        "p" & $target.player & "+" & $target.margin
  "S1 round=" & $state.round &
    " anchor=" & anchorGoal.goalName() &
    " active=" & activeGoal.goalName() &
    " balance=" & need.balanceNeedName() &
    " anchorAhead=" & (if anchorAhead: "1" else: "0") &
    " backbone=" & backbone &
    " food=" & foodPlan &
    " target=" & targetText &
    " family=" & $family &
    " rooms=" & $rooms &
    " fields=" & $fields &
    " unused=" & $unused &
    " fences=" & $player.fencesBuilt &
    " harvest=" & $state.round.turnsToHarvest() &
    " foodGap=" & $risk.foodGap &
    " begging=" & $risk.begging &
    " roomProgress=" & formatFloat(
      player.roomProgress(),
      ffDecimal,
      2
    )

proc ensurePolicyGoal(
  mind: var BotMind,
  state: solver.GameState,
  perspective: int
) =
  ## Chooses the persistent game-level steering goal once.
  if mind.policyGoal != solverPolicy.GoalBalance:
    return
  mind.policyGoal = solverPolicy.chooseOpeningGoal(state, perspective)
  echo "S0 goal=", mind.policyGoal.goalName()

proc activePolicyGoal(mind: BotMind): solverPolicy.SteeringGoal =
  ## Returns the goal currently allowed to steer decisions.
  if UseAnchorGoalPolicy:
    mind.policyGoal
  else:
    solverPolicy.GoalBalance

proc logStrategy(
  mind: var BotMind,
  state: solver.GameState,
  perspective: int
) {.raises: [solver.SolverError].} =
  ## Logs the current strategy when a round begins or the plan changes.
  let text = state.strategyText(
    perspective,
    mind.policyGoal,
    mind.activePolicyGoal()
  )
  if mind.lastStrategyRound == state.round and mind.lastStrategy == text:
    return
  mind.lastStrategyRound = state.round
  mind.lastStrategy = text
  echo text

proc moveCount(moves: openArray[solver.Move], action: solver.ActionId): int =
  ## Counts placement moves using one action.
  for move in moves:
    if move.kind == solver.PlacementMove and move.action == action:
      inc result

proc moveCount(moves: var solver.MoveBuffer, action: solver.ActionId): int =
  ## Counts buffered placement moves using one action.
  for i in 0 ..< moves.len:
    let move = moves.moves[i]
    if move.kind == solver.PlacementMove and move.action == action:
      inc result

proc containsText(values: seq[string], value: string): bool =
  ## Returns true when a text sequence contains a value.
  for item in values:
    if item == value:
      return true

proc isWatchedAction(action: solver.ActionId): bool =
  ## Returns true when an action should always be logged by rank.
  for watched in WatchedSolverActions:
    if action == watched:
      return true

proc logSolverWatchPool(
  serverActions: seq[string],
  legalMoves: var solver.MoveBuffer,
  rootMoves: seq[solver.Move]
) =
  ## Logs availability counts for high-impact solver actions.
  for action in WatchedSolverActions:
    let
      name = solver.actionName(action)
      server = serverActions.containsText(name)
      legal = legalMoves.moveCount(action)
      root = rootMoves.moveCount(action)
    if server or legal > 0 or root > 0:
      echo "B37 action=", name,
        " server=", server,
        " legal=", legal,
        " root=", root

proc missingActionReason(
  state: solver.GameState,
  playerIdx: int,
  action: solver.ActionId
): string {.raises: [solver.SolverError].} =
  ## Explains why one server-open action may be absent from Nim moves.
  if playerIdx < 0 or playerIdx >= state.players.len:
    return "bad player index"
  let player = state.players[playerIdx]
  case action
  of solver.FarmExpansion:
    let
      rooms = player.legalRoomSpaces()
      roomCost = player.roomCost()
      stables = player.legalStableSpaces()
    var stableCost: solver.Goods
    stableCost.resources[solver.Wood] = 2
    result = "roomSpaces=" & $rooms.len &
      " roomCost=" & roomCost.goodsText() &
      " canRoom=" & $player.canAfford(roomCost) &
      " stableSpaces=" & $stables.len &
      " stableCost=" & stableCost.goodsText() &
      " canStable=" & $player.canAfford(stableCost) &
      " stables=" & $player.stableCount() & "/" & $solver.MaxStables
  of solver.RFamilyGrowth:
    result = "family=" & $player.family.len & "/" & $solver.MaxFamily &
      " rooms=" & $player.roomCount() &
      " freeRooms=" & $max(0, player.roomCount() - player.family.len) &
      " ok=" & $player.familyGrowthOk()
  of solver.RUrgentFamily:
    result = "family=" & $player.family.len & "/" & $solver.MaxFamily &
      " ok=" & $player.urgentGrowthOk()
  of solver.RRenovateImprove, solver.RRedevelop:
    if player.houseMaterial == solver.HouseStone:
      return "already stone"
    let cost = player.renovationCost()
    result = "house=" & player.houseMaterial.houseText() &
      " cost=" & cost.goodsText() &
      " canAfford=" & $player.canAfford(cost)
  of solver.RSowBake:
    let power = player.bestBakePower()
    result = "sowable=" & $player.sowableFields().len &
      " sowChoices=" & $player.simpleSowChoices().len &
      " grain=" & $player.resources[solver.Grain] &
      " vegetable=" & $player.resources[solver.Vegetable] &
      " bakeRate=" & $power.perGrain &
      " bakeMax=" & $power.maxGrain
  of solver.RFences:
    let plans = player.suggestFencePlans(8)
    var affordable = 0
    for plan in plans:
      var cost: solver.Goods
      cost.resources[solver.Wood] = plan.cost
      if player.canAfford(cost):
        inc affordable
    result = "plans=" & $plans.len &
      " affordable=" & $affordable &
      " wood=" & $player.resources[solver.Wood] &
      " fences=" & $player.fencesBuilt & "/" & $solver.MaxFences
  else:
    result = "no detailed reason"

proc logMissingSolverActions(
  state: solver.GameState,
  playerIdx: int,
  actions: seq[string]
) =
  ## Logs detailed reasons for important server-open missing actions.
  for actionName in actions:
    let parsed = actionName.parseSolverAction()
    if not parsed.ok or not parsed.value.isWatchedAction():
      continue
    try:
      echo "B38 action=", actionName,
        " reason=", state.missingActionReason(playerIdx, parsed.value)
    except CatchableError as e:
      echo "B39 action=", actionName,
        " reason-error=", e.msg

proc logSolverDiff(
  serverActions,
  openActions,
  legalActions,
  rootActions,
  rejected: seq[string]
) =
  ## Logs how the native solver model differs from the server view.
  echo "B40 server=", serverActions.textList(),
    " open=", openActions.textList(),
    " legal=", legalActions.textList(),
    " usable=", rootActions.textList()
  let missingOpen = serverActions.missingText(openActions)
  if missingOpen.len > 0:
    echo "B41 actions=",
      missingOpen.textList()
  let missingLegal = serverActions.missingText(legalActions)
  if missingLegal.len > 0:
    echo "B42 actions=",
      missingLegal.textList()
  let extraLegal = legalActions.missingText(serverActions)
  if extraLegal.len > 0:
    echo "B43 actions=",
      extraLegal.textList()
  if rejected.len > 0:
    echo "B44 moves=",
      rejected.textList(8)

when defined(release):
  {.push checks: off.}

template solverAverage(node: untyped, playerIdx: int): float =
  ## Returns one node's average sampled margin.
  block:
    let visits = node.visits
    if visits == 0 or
        playerIdx < 0 or
        playerIdx >= SolverMaxPlayers:
      0.0
    else:
      node.totalMargins[playerIdx] / visits.float

template solverWinRate(node: untyped): float =
  ## Returns one node's sampled win rate.
  block:
    let visits = node.visits
    if visits == 0:
      0.0
    else:
      node.wins.float * 100 / visits.float

proc assignSolverMoves(
  dest: var seq[solver.Move],
  source: seq[solver.Move]
) =
  ## Copies moves into an existing buffer.
  dest.setLen(0)
  for move in source:
    dest.add move

proc mixKey(key: var uint64, value: int) =
  ## Mixes one integer into a deterministic search key.
  let x = cast[uint64](value.int64)
  key = key xor (
    x + 0x9E37_79B9_7F4A_7C15'u64 + (key shl 6) + (key shr 2)
  )

proc mixGoodsKey(key: var uint64, goods: solver.Goods) =
  ## Mixes one goods bundle into a deterministic search key.
  for resource in Resource:
    key.mixKey(goods.resources[resource])
  for animal in Animal:
    key.mixKey(goods.animals[animal])

proc mixCardSeqKey(key: var uint64, cards: seq[CardId]) =
  ## Mixes a card sequence into a deterministic search key.
  key.mixKey(cards.len)
  for card in cards:
    key.mixKey(ord(card))

proc mixActionSeqKey(key: var uint64, actions: seq[ActionId]) =
  ## Mixes an action sequence into a deterministic search key.
  key.mixKey(actions.len)
  for action in actions:
    key.mixKey(ord(action))

proc mixIntSeqKey(key: var uint64, values: seq[int]) =
  ## Mixes an integer sequence into a deterministic search key.
  key.mixKey(values.len)
  for value in values:
    key.mixKey(value)

proc mixFarmSpaceKey(key: var uint64, space: FarmSpace) =
  ## Mixes one farm space into a deterministic search key.
  key.mixKey(ord(space.kind))
  key.mixKey(ord(space.crop))
  key.mixKey(space.cropCount)
  key.mixKey(if space.stable: 1 else: 0)

proc mixPlayerKey(key: var uint64, player: solver.PlayerState) =
  ## Mixes one player state into a deterministic search key.
  key.mixKey(player.idx)
  for resource in Resource:
    key.mixKey(player.resources[resource])
  for animal in Animal:
    key.mixKey(player.animals[animal])
  for i in 0 ..< NumSpaces:
    key.mixFarmSpaceKey(player.spaces[i])
  key.mixIntSeqKey(player.fences)
  key.mixKey(player.fencesBuilt)
  key.mixKey(ord(player.houseMaterial))
  key.mixKey(player.family.len)
  for member in player.family:
    key.mixKey(member.bornRound)
    key.mixKey(if member.placed: 1 else: 0)
  key.mixKey(player.beggingCards)
  key.mixKey(if player.startingPlayerMarker: 1 else: 0)
  key.mixCardSeqKey(player.handOccupations)
  key.mixCardSeqKey(player.handMinors)
  key.mixCardSeqKey(player.occupations)
  key.mixCardSeqKey(player.minors)
  key.mixCardSeqKey(player.majors)

proc mixMoveKey(key: var uint64, move: solver.Move) =
  ## Mixes one solver move into a deterministic search key.
  key.mixKey(ord(move.kind))
  key.mixKey(move.playerIdx)
  key.mixKey(ord(move.action))
  key.mixIntSeqKey(move.rooms)
  key.mixIntSeqKey(move.stables)
  key.mixIntSeqKey(move.fields)
  key.mixKey(move.plow)
  key.mixKey(move.sow.len)
  for sow in move.sow:
    key.mixKey(sow.space)
    key.mixKey(ord(sow.crop))
  key.mixKey(move.bake.len)
  for bake in move.bake:
    key.mixKey(ord(bake.card))
    key.mixKey(bake.grain)
  key.mixIntSeqKey(move.edges)
  key.mixKey(ord(move.occupation))
  key.mixKey(ord(move.improvement.kind))
  key.mixKey(ord(move.improvement.card))
  key.mixKey(move.improvement.bake.len)
  for bake in move.improvement.bake:
    key.mixKey(ord(bake.card))
    key.mixKey(bake.grain)
  key.mixKey(move.feed.conversions.len)
  for conversion in move.feed.conversions:
    key.mixKey(ord(conversion.via))
    key.mixKey(ord(conversion.resource))
    key.mixKey(ord(conversion.animal))
    key.mixKey(if conversion.usesAnimal: 1 else: 0)
    key.mixKey(conversion.count)

proc moveKey(move: solver.Move): uint64 =
  ## Returns a deterministic key for one solver move.
  result = 0xCBF2_9CE4_8422_2325'u64
  result.mixMoveKey(move)

proc stateKey(state: solver.GameState): uint64 =
  ## Returns a deterministic key for one solver game state.
  result = 0xCBF2_9CE4_8422_2325'u64
  result.mixKey(state.seed)
  result.mixKey(state.numPlayers)
  result.mixKey(if state.solo: 1 else: 0)
  result.mixKey(state.round)
  result.mixKey(ord(state.phase))
  result.mixKey(state.startingPlayer)
  result.mixKey(state.currentPlayer)
  result.mixIntSeqKey(state.toFeed)
  result.mixKey(state.actionSpaces.len)
  for space in state.actionSpaces:
    result.mixKey(ord(space.id))
    result.mixKey(space.occupiedBy)
    result.mixGoodsKey(space.pile)
  result.mixActionSeqKey(state.roundDeck)
  result.mixCardSeqKey(state.majorsAvailable)
  result.mixKey(state.scheduled.len)
  for scheduled in state.scheduled:
    result.mixKey(scheduled.round)
    result.mixKey(scheduled.playerIdx)
    result.mixGoodsKey(scheduled.goods)
  result.mixKey(state.players.len)
  for player in state.players:
    result.mixPlayerKey(player)
  result.mixIntSeqKey(state.scores)

proc initSolverTree(capacity: int): SolverTree =
  ## Builds an empty flat solver node pool.
  let cap = min(max(1, capacity), SolverMaxTreeNodes)
  result.nodes = newSeq[SolverSearchNode](cap)
  result.states = newSeq[solver.GameState](cap)

proc ensureSolverCapacity(
  tree: var SolverTree,
  required: int
) =
  ## Grows flat solver pools while preserving existing slots.
  if required <= tree.nodes.len and required <= tree.states.len:
    return
  let nextCap = min(
    SolverMaxTreeNodes,
    max(required, max(4, max(tree.nodes.len, tree.states.len) * 2))
  )
  if tree.nodes.len < nextCap:
    tree.nodes.setLen(nextCap)
  if tree.states.len < nextCap:
    tree.states.setLen(nextCap)

proc addSolverState(
  tree: var SolverTree,
  gameState: solver.GameState
): int =
  ## Adds one state to the flat solver state pool.
  tree.ensureSolverCapacity(tree.stateCount + 1)
  result = tree.stateCount
  inc tree.stateCount
  tree.states[result] = gameState

proc addSolverChildState(
  tree: var SolverTree,
  parentIdx: int,
  move: solver.Move
): int {.raises: [solver.SolverError].} =
  ## Copies one parent state slot and applies a child move in place.
  if tree.stateCount >= SolverMaxTreeNodes:
    return solver.NoPlayer
  tree.ensureSolverCapacity(tree.stateCount + 1)
  result = tree.stateCount
  inc tree.stateCount
  tree.states[result] = tree.stateAt(parentIdx)
  tree.states[result].applyMoveInPlace(move)

proc clearSolverTree(tree: var SolverTree) =
  ## Clears live pool entries while keeping allocated storage.
  tree.nodeCount = 0
  tree.stateCount = 0

proc resetSolverSearchNode(
  node: var SolverSearchNode,
  stateIdx: int,
  gameState: solver.GameState,
  parent: int,
  move: solver.Move,
  untried: seq[solver.Move]
): void =
  ## Resets one flat node slot for a new search state.
  node.stateIdx = stateIdx
  node.move = move
  node.key = gameState.stateKey()
  node.parent = parent
  node.children.setLen(0)
  node.untried.assignSolverMoves(untried)
  node.visits = 0
  node.wins = 0
  node.ties = 0
  node.losses = 0
  for i in 0 ..< SolverMaxPlayers:
    node.totalMargins[i] = 0
  node.bestMargin = low(int)
  node.worstMargin = high(int)

proc addSolverSearchNodeAt(
  tree: var SolverTree,
  stateIdx: int,
  parent: int,
  move: solver.Move,
  untried: seq[solver.Move]
): int =
  ## Adds one node for an existing flat solver state slot.
  if tree.nodeCount >= SolverMaxTreeNodes:
    return solver.NoPlayer
  result = tree.nodeCount
  inc tree.nodeCount
  let node = tree.nodePtr(result)
  node[].resetSolverSearchNode(
    stateIdx,
    tree.states[stateIdx],
    parent,
    move,
    untried
  )

proc addSolverSearchNode(
  tree: var SolverTree,
  gameState: solver.GameState,
  parent: int,
  move: solver.Move,
  untried: seq[solver.Move]
): int =
  ## Adds one node and state to the flat solver pools.
  if tree.nodeCount >= SolverMaxTreeNodes:
    return solver.NoPlayer
  let stateIdx = tree.addSolverState(gameState)
  result = tree.addSolverSearchNodeAt(
    stateIdx,
    parent,
    move,
    untried
  )

proc solverRandomPlayout(
  start: solver.GameState,
  rng: var solver.Rng,
  perspective: int,
  maxMoves: int,
  goal: solverPolicy.SteeringGoal
): SolverMargins {.raises: [solver.SolverError].} =
  ## Plays random solver moves to game end and returns final margins.
  var
    state = start
    options: solver.MoveBuffer
    moves = 0
  while state.phase != solver.Finished:
    state.legalMoves(options)
    if options.len == 0:
      raise newException(solver.SolverError, "No legal moves.")
    let move = state.solverBiasedPlayoutMove(
      options,
      perspective,
      goal,
      rng
    )
    state.applyMoveInPlace(move)
    inc moves
    if moves > maxMoves:
      raise newException(solver.SolverError, "Playout limit hit.")
  state.solverMargins()

proc solverUcbScore(
  tree: SolverTree,
  parentIdx,
  childIdx,
  perspective: int
): float =
  ## Scores one child using UCB.
  if tree[childIdx].visits == 0:
    return Inf
  let mover = tree.stateAt(parentIdx).solverPlayerToMove()
  let scorer =
    if mover == solver.NoPlayer:
      perspective
    else:
      mover
  let exploit = tree[childIdx].solverAverage(scorer) / SolverScoreScale
  exploit + SolverExplore *
    sqrt(
      ln(max(1, tree[parentIdx].visits).float) /
        tree[childIdx].visits.float
    )

proc selectSolverChild(
  tree: SolverTree,
  parentIdx,
  perspective: int,
  rng: var solver.Rng
): int =
  ## Selects one search child.
  if parentIdx == 0:
    var coldCount = 0
    for childIdx in tree[parentIdx].children:
      if tree[childIdx].visits < SolverRootWarmupVisits:
        inc coldCount
    if coldCount > 0:
      let choice = rng.randInt(coldCount)
      var seen = 0
      for childIdx in tree[parentIdx].children:
        if tree[childIdx].visits < SolverRootWarmupVisits:
          if seen == choice:
            return childIdx
          inc seen
  var
    bestScore = -Inf
    tieCount = 0
  for childIdx in tree[parentIdx].children:
    let score = tree.solverUcbScore(parentIdx, childIdx, perspective)
    if score > bestScore + 0.000_001:
      bestScore = score
      tieCount = 1
    elif abs(score - bestScore) <= 0.000_001:
      inc tieCount
  if tieCount == 0:
    return solver.NoPlayer
  let choice = rng.randInt(tieCount)
  var seen = 0
  for childIdx in tree[parentIdx].children:
    let score = tree.solverUcbScore(parentIdx, childIdx, perspective)
    if abs(score - bestScore) <= 0.000_001:
      if seen == choice:
        return childIdx
      inc seen
  solver.NoPlayer

proc expandSolverNode(
  tree: var SolverTree,
  nodeIdx: int,
  rng: var solver.Rng
): int {.raises: [solver.SolverError].} =
  ## Expands one untried move.
  if tree[nodeIdx].untried.len == 0:
    return nodeIdx
  let moveIndex = rng.randInt(tree[nodeIdx].untried.len)
  let move = tree[nodeIdx].untried[moveIndex]
  let lastIndex = tree[nodeIdx].untried.high
  if moveIndex != lastIndex:
    tree[nodeIdx].untried[moveIndex] = tree[nodeIdx].untried[lastIndex]
  tree[nodeIdx].untried.setLen(lastIndex)
  if tree.nodeCount >= SolverMaxTreeNodes:
    return nodeIdx
  let stateIdx = tree.addSolverChildState(nodeIdx, move)
  if stateIdx == solver.NoPlayer:
    return nodeIdx
  var childMoves: seq[solver.Move]
  if tree.states[stateIdx].phase != solver.Finished:
    var childBuffer: solver.MoveBuffer
    tree.states[stateIdx].legalMoves(childBuffer)
    childMoves = childBuffer.toSeq()
  let childIdx = tree.addSolverSearchNodeAt(
    stateIdx,
    nodeIdx,
    move,
    childMoves
  )
  if childIdx == solver.NoPlayer:
    return nodeIdx
  tree[nodeIdx].children.add childIdx
  childIdx

proc recordSolverResult(
  node: var SolverSearchNode,
  margins: SolverMargins,
  perspective: int
) =
  ## Records one sampled playout result.
  inc node.visits
  for i in 0 ..< margins.count:
    node.totalMargins[i] += margins.values[i].float
  let margin =
    if perspective >= 0 and perspective < margins.count:
      margins.values[perspective]
    else:
      0
  node.bestMargin = max(node.bestMargin, margin)
  node.worstMargin = min(node.worstMargin, margin)
  if margin > 0:
    inc node.wins
  elif margin == 0:
    inc node.ties
  else:
    inc node.losses

proc runSolverIteration(
  tree: var SolverTree,
  rng: var solver.Rng,
  perspective,
  maxMoves: int,
  goal: solverPolicy.SteeringGoal = solverPolicy.GoalBalance
) {.raises: [solver.SolverError].} =
  ## Runs one MCTS iteration.
  var
    nodeIdx = 0
    path: array[SolverPathLimit, int]
    pathLen = 1
  path[0] = 0
  while tree[nodeIdx].untried.len == 0 and tree[nodeIdx].children.len > 0:
    nodeIdx = tree.selectSolverChild(nodeIdx, perspective, rng)
    if nodeIdx == solver.NoPlayer:
      return
    if pathLen >= path.len:
      raise newException(solver.SolverError, "Search path limit hit.")
    path[pathLen] = nodeIdx
    inc pathLen
  if tree[nodeIdx].untried.len > 0:
    nodeIdx = tree.expandSolverNode(nodeIdx, rng)
    if pathLen >= path.len:
      raise newException(solver.SolverError, "Search path limit hit.")
    path[pathLen] = nodeIdx
    inc pathLen
  let margins = solverRandomPlayout(
    tree.stateAt(nodeIdx),
    rng,
    perspective,
    maxMoves,
    goal
  )
  for i in 0 ..< pathLen:
    tree[path[i]].recordSolverResult(margins, perspective)

proc solverRootMoves(
  message: JsonNode,
  moves: var solver.MoveBuffer,
  rejected: var seq[string]
): seq[solver.Move] =
  ## Returns solver moves accepted by Terra's placement validator.
  for i in 0 ..< moves.len:
    let move = moves.moves[i]
    if move.kind != solver.PlacementMove:
      continue
    let placement = move.solverMovePlacement()
    let valid = message.validatePlacement(placement)
    if valid.ok:
      result.add move
    elif rejected.len < 16:
      rejected.add move.moveText() & " -> " & valid.error

proc bestSolverRootChild(
  tree: SolverTree,
  perspective: int
): int =
  ## Selects the most visited root child.
  result = solver.NoPlayer
  for childIdx in tree[0].children:
    if result == solver.NoPlayer or
      tree[childIdx].visits > tree[result].visits or
      (tree[childIdx].visits == tree[result].visits and
        tree[childIdx].solverAverage(perspective) >
          tree[result].solverAverage(perspective)):
      result = childIdx

proc findSolverRootChild(
  tree: SolverTree,
  move: solver.Move
): int =
  ## Finds the root child matching one move.
  result = solver.NoPlayer
  if tree.len == 0:
    return
  let key = move.moveKey()
  for childIdx in tree[0].children:
    if tree[childIdx].move.moveKey() == key:
      return childIdx

proc protectedSolverRootChild(
  tree: SolverTree,
  perspective: int,
  policyChoice: solverPolicy.BasePolicyChoice,
  mctsIdx: int
): int =
  ## Keeps strategic growth plans when MCTS only barely disagrees.
  result = mctsIdx
  if not policyChoice.ok or mctsIdx == solver.NoPlayer:
    return
  var
    scoreWinProtection = false
    foodWinProtection = false
  case policyChoice.reason
  of solverPolicy.PolicyFood:
    foodWinProtection = true
  of solverPolicy.PolicyField, solverPolicy.PolicyFamily,
      solverPolicy.PolicyRoomBuild, solverPolicy.PolicyRoomSetup,
      solverPolicy.PolicyFarmExpansion:
    discard
  of solverPolicy.PolicyScore:
    scoreWinProtection = true
  else:
    return
  let baseIdx = tree.findSolverRootChild(policyChoice.move)
  if baseIdx == solver.NoPlayer or baseIdx == mctsIdx:
    return
  let rootState = tree.stateAt(0)

  proc riskAfter(move: solver.Move):
      tuple[ok: bool, begging, foodGap: int] =
    ## Returns projected feeding risk after one root move.
    try:
      var projected = rootState.copy()
      projected.applyMoveInPlace(move)
      let risk = projected.feedingRisk(perspective)
      (true, risk.begging, risk.foodGap)
    except CatchableError:
      (false, high(int), high(int))

  proc roomProgressAfter(
    move: solver.Move,
    fallback: float
  ): float =
    ## Returns first-room progress after one root move.
    try:
      var projected = rootState.copy()
      projected.applyMoveInPlace(move)
      if perspective >= 0 and perspective < projected.players.len:
        return projected.players[perspective].roomProgress()
    except CatchableError:
      discard
    fallback

  let
    baseRisk = riskAfter(tree[baseIdx].move)
    mctsRisk = riskAfter(tree[mctsIdx].move)
    mctsMove = tree[mctsIdx].move
    player =
      if perspective >= 0 and perspective < rootState.players.len:
        rootState.players[perspective]
      else:
        solver.PlayerState()
    beforeRoomProgress = player.roomProgress()
    baseRoomProgress = roomProgressAfter(
      policyChoice.move,
      beforeRoomProgress
    )
    mctsRoomProgress = roomProgressAfter(mctsMove, beforeRoomProgress)
    mctsFenceBreaksRoom =
      mctsMove.kind == solver.PlacementMove and
        mctsMove.action == solver.RFences and
        (mctsRoomProgress < SolverFirstRoomFenceProgress or
          mctsRoomProgress + SolverFirstRoomFenceDrop < beforeRoomProgress)
    firstRoomPlan =
      perspective >= 0 and
        perspective < rootState.players.len and
        rootState.round <= 8 and
        player.family.len < 3 and
        player.roomCount() <= player.family.len and
        policyChoice.reason in {
          solverPolicy.PolicyRoomBuild,
          solverPolicy.PolicyRoomSetup,
          solverPolicy.PolicyFarmExpansion
        }
    firstRoomBuildPlan =
      firstRoomPlan and
        policyChoice.reason in {
          solverPolicy.PolicyRoomBuild,
          solverPolicy.PolicyFarmExpansion
        }
    firstRoomSetupPlan =
      perspective >= 0 and
        perspective < rootState.players.len and
        rootState.round <= 8 and
        player.family.len < 3 and
        player.roomCount() <= player.family.len and
        baseRoomProgress > beforeRoomProgress + 0.02 and
        mctsRoomProgress + 0.02 < baseRoomProgress
    growthRoomPlan =
      perspective >= 0 and
        perspective < rootState.players.len and
        rootState.round <= 12 and
        player.family.len >= 3 and
        player.family.len < 4 and
        player.roomCount() <= player.family.len and
        policyChoice.reason in {
          solverPolicy.PolicyRoomBuild,
          solverPolicy.PolicyRoomSetup,
          solverPolicy.PolicyFarmExpansion
        }
    familyPlan =
      policyChoice.reason == solverPolicy.PolicyFamily and
        player.family.len < 4
    fieldCatchupPlan =
      policyChoice.reason == solverPolicy.PolicyField and
        rootState.round >= 9 and
        rootState.round <= 12 and
        player.family.len >= 3 and
        player.countKind(solver.Field) < 2
    mctsBackbone =
      mctsMove.kind == solver.PlacementMove and
        ((mctsMove.action == solver.FarmExpansion and
          mctsMove.rooms.len > 0) or
        mctsMove.action in {
          solver.RFamilyGrowth,
          solver.RUrgentFamily
        })
    lateMctsZeroFieldRepair =
      foodWinProtection and
        perspective >= 0 and
        perspective < rootState.players.len and
        rootState.round >= 12 and
        player.family.len >= 3 and
        player.countKind(solver.Field) == 0 and
        mctsMove.kind == solver.PlacementMove and
        mctsMove.action in {solver.Farmland, solver.RCultivation} and
        baseRisk.ok and
        mctsRisk.ok and
        baseRisk.begging == 0 and
        mctsRisk.begging == 0
    firstRoomFenceDetour =
      perspective >= 0 and
        perspective < rootState.players.len and
        rootState.round <= 11 and
        player.houseMaterial == solver.HouseWood and
        player.family.len < 3 and
        player.roomCount() <= player.family.len and
        (player.canAfford(player.roomCost()) or
          beforeRoomProgress >= SolverFirstRoomFenceProgress) and
        mctsFenceBreaksRoom and
        not (
          policyChoice.move.kind == solver.PlacementMove and
            policyChoice.move.action == solver.RFences
        )
    foodPlan =
      foodWinProtection and
        not lateMctsZeroFieldRepair and
        not mctsBackbone and
        rootState.round.turnsToHarvest() <= 2 and
        baseRisk.ok and
        mctsRisk.ok and
        (baseRisk.begging < mctsRisk.begging or
          baseRisk.foodGap < mctsRisk.foodGap)
    strategicPlan = firstRoomBuildPlan or growthRoomPlan or familyPlan or
      fieldCatchupPlan or firstRoomFenceDetour or firstRoomSetupPlan
  if not strategicPlan and
      (tree[baseIdx].visits < SolverDisagreeMinVisits or
        tree[mctsIdx].visits < SolverDisagreeMinVisits):
    return
  let
    avgEdge = tree[mctsIdx].solverAverage(perspective) -
      tree[baseIdx].solverAverage(perspective)
    winEdge = tree[mctsIdx].solverWinRate() -
      tree[baseIdx].solverWinRate()
    mctsSafeSetupDetour =
      firstRoomSetupPlan and
        not mctsBackbone and
        baseRisk.ok and
        mctsRisk.ok and
        mctsRisk.begging <= baseRisk.begging and
        mctsRisk.foodGap <= baseRisk.foodGap and
        avgEdge >= SolverFirstRoomSetupDetourAvgEdge and
        winEdge >= SolverFirstRoomSetupDetourWinEdge
    protect =
      if firstRoomFenceDetour:
        avgEdge <= SolverFirstRoomFenceProtectAvgEdge and
          winEdge <= SolverFirstRoomFenceProtectWinEdge
      elif firstRoomBuildPlan and not mctsBackbone:
        avgEdge <= SolverFirstRoomBuildProtectAvgEdge and
          winEdge <= SolverFirstRoomBuildProtectWinEdge
      elif firstRoomSetupPlan and not mctsBackbone:
        not mctsSafeSetupDetour and
          avgEdge <= SolverFirstRoomSetupProtectAvgEdge and
            winEdge <= SolverFirstRoomSetupProtectWinEdge
      elif firstRoomPlan and not mctsBackbone:
        avgEdge <= SolverFirstRoomProtectAvgEdge and
          winEdge <= SolverFirstRoomProtectWinEdge
      elif growthRoomPlan and not mctsBackbone:
        avgEdge <= SolverGrowthRoomProtectAvgEdge and
          winEdge <= SolverGrowthRoomProtectWinEdge
      elif familyPlan and not mctsBackbone:
        avgEdge <= SolverFamilyProtectAvgEdge and
          winEdge <= SolverFamilyProtectWinEdge
      elif fieldCatchupPlan and not mctsBackbone:
        avgEdge <= SolverFieldCatchupProtectAvgEdge and
          winEdge <= SolverFieldCatchupProtectWinEdge
      elif foodPlan:
        if baseRisk.begging < mctsRisk.begging:
          avgEdge <= SolverFoodDebtProtectAvgEdge and
            winEdge <= SolverFoodDebtProtectWinEdge
        else:
          avgEdge <= SolverFoodProtectAvgEdge and
            winEdge <= SolverFoodProtectWinEdge
      elif scoreWinProtection:
        avgEdge <= SolverScoreProtectAvgEdge and
          tree[baseIdx].solverWinRate() >=
            tree[mctsIdx].solverWinRate() + SolverScoreProtectWinLead
      else:
        avgEdge <= SolverPlanProtectAvgEdge and
          winEdge <= SolverPlanProtectWinEdge
  if protect:
    echo "F18 reason=", ord(policyChoice.reason),
      " base=", tree[baseIdx].move.moveText(),
      " mcts=", tree[mctsIdx].move.moveText(),
      " baseAvg=", formatFloat(
        tree[baseIdx].solverAverage(perspective),
        ffDecimal,
        2
      ),
      " mctsAvg=", formatFloat(
        tree[mctsIdx].solverAverage(perspective),
        ffDecimal,
        2
      ),
      " baseWin=", formatFloat(
        tree[baseIdx].solverWinRate(),
        ffDecimal,
        1
      ),
      " mctsWin=", formatFloat(
        tree[mctsIdx].solverWinRate(),
        ffDecimal,
        1
      )
    result = baseIdx

proc solverGoodEnoughRootLeader(
  tree: SolverTree,
  perspective: int
): tuple[ok: bool, bestIdx: int] =
  ## Returns a root leader when the best sampled move is good enough.
  result.bestIdx = solver.NoPlayer
  if tree.len == 0 or tree[0].visits < SolverEarlyMinSamples:
    return
  if tree[0].untried.len > 0 or tree[0].children.len == 0:
    return
  for childIdx in tree[0].children:
    if tree[childIdx].visits < SolverEarlyMinRootVisits:
      return
    if result.bestIdx == solver.NoPlayer or
        tree[childIdx].visits > tree[result.bestIdx].visits or
        (tree[childIdx].visits == tree[result.bestIdx].visits and
          tree[childIdx].solverAverage(perspective) >
            tree[result.bestIdx].solverAverage(perspective)):
      result.bestIdx = childIdx
  if result.bestIdx == solver.NoPlayer:
    return
  if tree[result.bestIdx].visits < SolverEarlyMinBestVisits:
    return
  result.ok =
    tree[result.bestIdx].solverAverage(perspective) >= SolverGoodAvg or
    tree[result.bestIdx].solverWinRate() >= SolverGoodWin

proc containsMoveKey(moves: seq[solver.Move], key: uint64): bool =
  ## Returns true when a move key appears in a move sequence.
  for move in moves:
    if move.moveKey() == key:
      return true

proc containsChildMoveKey(
  tree: SolverTree,
  nodeIdx: int,
  key: uint64
): bool =
  ## Returns true when one node already has a child move key.
  for childIdx in tree[nodeIdx].children:
    if tree[childIdx].move.moveKey() == key:
      return true

proc addSolverCloneNode(
  newTree: var SolverTree,
  oldTree: SolverTree,
  oldIdx,
  parent: int
): int =
  ## Copies one search node into a flat pool without its children.
  if newTree.len >= SolverMaxTreeNodes:
    return solver.NoPlayer
  let stateIdx = newTree.addSolverState(oldTree.stateAt(oldIdx))
  result = newTree.nodeCount
  inc newTree.nodeCount
  let node = newTree.nodePtr(result)
  node[].stateIdx = stateIdx
  node[].move = oldTree[oldIdx].move
  node[].key = oldTree[oldIdx].key
  node[].parent = parent
  node[].children.setLen(0)
  node[].untried.assignSolverMoves(oldTree[oldIdx].untried)
  node[].visits = oldTree[oldIdx].visits
  node[].wins = oldTree[oldIdx].wins
  node[].ties = oldTree[oldIdx].ties
  node[].losses = oldTree[oldIdx].losses
  node[].totalMargins = oldTree[oldIdx].totalMargins
  node[].bestMargin = oldTree[oldIdx].bestMargin
  node[].worstMargin = oldTree[oldIdx].worstMargin

proc appendSolverSubtree(
  newTree: var SolverTree,
  oldTree: SolverTree,
  oldIdx,
  parent: int,
  rootState: solver.GameState,
  rootMoves: seq[solver.Move],
  isRoot: bool
): int =
  ## Appends one remapped reusable subtree and returns its new index.
  if oldIdx < 0 or oldIdx >= oldTree.len:
    return solver.NoPlayer
  if newTree.len >= SolverMaxTreeNodes:
    return solver.NoPlayer
  result = newTree.addSolverCloneNode(oldTree, oldIdx, parent)
  if result == solver.NoPlayer:
    return
  if isRoot:
    newTree.states[newTree[result].stateIdx] = rootState
    newTree[result].move = solver.Move()
    newTree[result].key = rootState.stateKey()
    newTree[result].parent = solver.NoPlayer
  for oldChildIdx in oldTree[oldIdx].children:
    if newTree.len >= SolverMaxTreeNodes:
      break
    if isRoot and
        not rootMoves.containsMoveKey(oldTree[oldChildIdx].move.moveKey()):
      continue
    let childIdx = newTree.appendSolverSubtree(
      oldTree,
      oldChildIdx,
      result,
      rootState,
      rootMoves,
      false
    )
    if childIdx != solver.NoPlayer:
      newTree[result].children.add childIdx
  if isRoot:
    newTree[result].untried.setLen(0)
    for move in rootMoves:
      if not newTree.containsChildMoveKey(result, move.moveKey()):
        newTree[result].untried.add move

proc findReusableSolverRoot(
  tree: SolverTree,
  key: uint64
): int =
  ## Finds the highest-visit old node matching an observed state key.
  result = solver.NoPlayer
  for i in 0 ..< tree.len:
    if tree[i].key != key:
      continue
    if result == solver.NoPlayer or tree[i].visits > tree[result].visits:
      result = i

proc prepareSolverTree(
  mind: var BotMind,
  state: solver.GameState,
  rootMoves: seq[solver.Move]
): tuple[
  tree: SolverTree,
  reused: bool,
  reusedVisits: int,
  oldNodes: int
] =
  ## Reuses a matching previous subtree or creates a fresh root tree.
  let key = state.stateKey()
  let oldIdx = mind.solverTree.findReusableSolverRoot(key)
  if oldIdx != solver.NoPlayer:
    result.tree = initSolverTree(
      min(max(mind.solverTree.len, rootMoves.len + 1), SolverMaxTreeNodes)
    )
    discard result.tree.appendSolverSubtree(
      mind.solverTree,
      oldIdx,
      solver.NoPlayer,
      state,
      rootMoves,
      true
    )
    if result.tree.len > 0:
      result.reused = true
      result.reusedVisits = result.tree[0].visits
      result.oldNodes = mind.solverTree.len
      return
  result.tree = initSolverTree(rootMoves.len + 1)
  discard result.tree.addSolverSearchNode(
    state,
    solver.NoPlayer,
    solver.Move(),
    rootMoves
  )

proc benchmarkSolverSearch*(
  iterations,
  maxMoves,
  seed,
  players: int
): SolverBenchResult {.raises: [solver.SolverError].} =
  ## Runs the native solver MCTS loop for benchmark code.
  doAssert iterations > 0, "Iterations must be positive."
  doAssert maxMoves > 0, "Max moves must be positive."
  doAssert players > 0, "Players must be positive."
  var state = solver.newGame(seed, players)
  state.startGame()
  var rootBuffer: solver.MoveBuffer
  state.legalMoves(rootBuffer)
  let
    perspective = state.solverPlayerToMove()
    rootMoves = rootBuffer.toSeq()
  var
    rng = solver.initRng(seed xor 0xC0FFEE)
    tree = initSolverTree(iterations + 1)
  discard tree.addSolverSearchNode(
    state,
    solver.NoPlayer,
    solver.Move(),
    rootMoves
  )
  for _ in 0 ..< iterations:
    tree.runSolverIteration(rng, perspective, maxMoves)
  let bestIdx = tree.bestSolverRootChild(perspective)
  result.iterations = iterations
  result.nodes = tree.len
  result.rootMoves = rootMoves.len
  result.rootChildren = tree[0].children.len
  result.rootUntried = tree[0].untried.len
  result.rootVisits = tree[0].visits
  result.perspective = perspective
  if bestIdx != solver.NoPlayer:
    result.bestMove = tree[bestIdx].move.moveText()
    result.bestVisits = tree[bestIdx].visits
    result.bestAverage = tree[bestIdx].solverAverage(perspective)
    result.bestWinRate = tree[bestIdx].solverWinRate()

proc collectSolverRootSummaries(tree: SolverTree): seq[SolverRootSummary] =
  ## Copies root child statistics out of one worker tree.
  for childIdx in tree[0].children:
    var summary = SolverRootSummary(
      move: tree[childIdx].move,
      visits: tree[childIdx].visits,
      wins: tree[childIdx].wins,
      ties: tree[childIdx].ties,
      losses: tree[childIdx].losses,
      totalMargins: tree[childIdx].totalMargins,
      bestMargin: tree[childIdx].bestMargin,
      worstMargin: tree[childIdx].worstMargin
    )
    result.add summary

proc runSolverWorker(
  worker: int,
  state: solver.GameState,
  rootMoves: seq[solver.Move],
  perspective,
  maxMoves,
  iterations,
  seed,
  timeMs: int,
  goal: solverPolicy.SteeringGoal
): SolverWorkerResult =
  ## Runs one independent root MCTS scan for parallel aggregation.
  result.worker = worker
  let searchStart = getMonoTime()
  try:
    var
      rng = solver.initRng(seed)
      tree = initSolverTree(min(iterations + rootMoves.len + 1,
        SolverMaxTreeNodes))
      searchDeadline =
        searchStart + initDuration(milliseconds = timeMs)
    discard tree.addSolverSearchNode(
      state,
      solver.NoPlayer,
      solver.Move(),
      rootMoves
    )
    for _ in 0 ..< iterations:
      if result.sampled > 0 and getMonoTime() >= searchDeadline:
        break
      if tree.len >= SolverMaxTreeNodes:
        break
      tree.runSolverIteration(rng, perspective, maxMoves, goal)
      inc result.sampled
    result.elapsedMs = inMilliseconds(getMonoTime() - searchStart).int
    result.ok = true
    result.nodes = tree.len
    result.summaries = tree.collectSolverRootSummaries()
  except CatchableError as e:
    result.elapsedMs = inMilliseconds(getMonoTime() - searchStart).int
    result.ok = false
    result.error = e.msg

proc findRootMoveIndex(
  rootMoves: seq[solver.Move],
  key: uint64
): int =
  ## Finds a root move index by stable move key.
  result = solver.NoPlayer
  for i, move in rootMoves:
    if move.moveKey() == key:
      return i

proc addSummary(total: var SolverRootSummary, summary: SolverRootSummary) =
  ## Adds one worker root summary into an aggregate summary.
  if summary.visits <= 0:
    return
  if total.visits == 0:
    total.bestMargin = summary.bestMargin
    total.worstMargin = summary.worstMargin
  else:
    total.bestMargin = max(total.bestMargin, summary.bestMargin)
    total.worstMargin = min(total.worstMargin, summary.worstMargin)
  total.visits += summary.visits
  total.wins += summary.wins
  total.ties += summary.ties
  total.losses += summary.losses
  for i in 0 ..< SolverMaxPlayers:
    total.totalMargins[i] += summary.totalMargins[i]

proc aggregateSolverWorkers(
  state: solver.GameState,
  rootMoves: seq[solver.Move],
  workers: seq[SolverWorkerResult]
): tuple[
  tree: SolverTree,
  sampled: int,
  nodes: int,
  failed: int
] =
  ## Merges independent worker root statistics into a solver tree.
  var totals = newSeq[SolverRootSummary](rootMoves.len)
  for i, move in rootMoves:
    totals[i].move = move
    totals[i].bestMargin = low(int)
    totals[i].worstMargin = high(int)
  for worker in workers:
    result.sampled += worker.sampled
    result.nodes += worker.nodes
    if not worker.ok:
      inc result.failed
      continue
    for summary in worker.summaries:
      let idx = rootMoves.findRootMoveIndex(summary.move.moveKey())
      if idx != solver.NoPlayer:
        totals[idx].addSummary(summary)
  result.tree = initSolverTree(rootMoves.len + 1)
  discard result.tree.addSolverSearchNode(
    state,
    solver.NoPlayer,
    solver.Move(),
    rootMoves
  )
  result.tree[0].visits = result.sampled
  result.tree[0].untried.setLen(0)
  var emptyMoves: seq[solver.Move]
  for total in totals:
    if total.visits <= 0:
      continue
    let childIdx = result.tree.addSolverSearchNodeAt(
      result.tree[0].stateIdx,
      0,
      total.move,
      emptyMoves
    )
    if childIdx == solver.NoPlayer:
      break
    result.tree[0].children.add childIdx
    let node = result.tree.nodePtr(childIdx)
    node[].visits = total.visits
    node[].wins = total.wins
    node[].ties = total.ties
    node[].losses = total.losses
    node[].totalMargins = total.totalMargins
    node[].bestMargin = total.bestMargin
    node[].worstMargin = total.worstMargin

proc runParallelSolverSearch(
  state: solver.GameState,
  rootMoves: seq[solver.Move],
  perspective,
  maxMoves,
  iterations,
  seed,
  timeMs,
  workerCount: int,
  goal: solverPolicy.SteeringGoal = solverPolicy.GoalBalance
): tuple[
  tree: SolverTree,
  sampled: int,
  nodes: int,
  workers: int,
  failed: int
] =
  ## Runs independent MCTS root scans and merges their root statistics.
  result.workers = solverThreadCount(workerCount)
  var flows: seq[FlowVar[SolverWorkerResult]]
  for i in 0 ..< result.workers:
    flows.add spawn runSolverWorker(
      i,
      state,
      rootMoves,
      perspective,
      maxMoves,
      iterations,
      seed xor ((i + 1) * 0x9E3779B9),
      timeMs,
      goal
    )
  var workerResults: seq[SolverWorkerResult]
  for flow in flows:
    workerResults.add ^flow
  for worker in workerResults:
    echo "F21 worker=", worker.worker,
      " ok=", if worker.ok: 1 else: 0,
      " sampled=", worker.sampled,
      " scans6s=", estimateMctsScans(worker.sampled, worker.elapsedMs),
      " elapsedMs=", worker.elapsedMs,
      " nodes=", worker.nodes,
      " root=", worker.summaries.len
  let merged = aggregateSolverWorkers(state, rootMoves, workerResults)
  result.tree = merged.tree
  result.sampled = merged.sampled
  result.nodes = merged.nodes
  result.failed = merged.failed

proc benchmarkParallelSolverSearch*(
  timeMs,
  maxMoves,
  seed,
  players,
  workers: int
): SolverBenchResult {.raises: [solver.SolverError].} =
  ## Runs a timed parallel root MCTS scan for benchmark code.
  doAssert timeMs > 0, "Time must be positive."
  doAssert maxMoves > 0, "Max moves must be positive."
  doAssert players > 0, "Players must be positive."
  doAssert workers > 0, "Workers must be positive."
  let workerCount = solverThreadCount(workers)
  setMaxPoolSize(workerCount)
  var state = solver.newGame(seed, players)
  state.startGame()
  var rootBuffer: solver.MoveBuffer
  state.legalMoves(rootBuffer)
  let
    perspective = state.solverPlayerToMove()
    rootMoves = rootBuffer.toSeq()
    scan = runParallelSolverSearch(
      state,
      rootMoves,
      perspective,
      maxMoves,
      DefaultSolverIterations,
      seed xor 0xC0FFEE,
      timeMs,
      workerCount
    )
    bestIdx = scan.tree.bestSolverRootChild(perspective)
  result.iterations = scan.sampled
  result.nodes = scan.tree.len
  result.rootMoves = rootMoves.len
  result.rootChildren = scan.tree[0].children.len
  result.rootUntried = scan.tree[0].untried.len
  result.rootVisits = scan.tree[0].visits
  result.perspective = perspective
  if bestIdx != solver.NoPlayer:
    result.bestMove = scan.tree[bestIdx].move.moveText()
    result.bestVisits = scan.tree[bestIdx].visits
    result.bestAverage = scan.tree[bestIdx].solverAverage(perspective)
    result.bestWinRate = scan.tree[bestIdx].solverWinRate()

when defined(release):
  {.pop.}

proc sortedSolverRootChildren(
  tree: SolverTree,
  perspective: int
): seq[int] =
  ## Returns root children ordered by visits and average margin.
  result = tree[0].children
  result.sort do (a, b: int) -> int:
    result = cmp(tree[b].visits, tree[a].visits)
    if result == 0:
      result = cmp(
        tree[b].solverAverage(perspective),
        tree[a].solverAverage(perspective)
      )

proc logSolverRoot(
  tree: SolverTree,
  perspective: int,
  limit = 8
) =
  ## Logs the sampled root move table.
  echo "F1"
  let ordered = tree.sortedSolverRootChildren(perspective)
  for i in 0 ..< min(ordered.len, limit):
    let childIdx = ordered[i]
    echo "F2 rank=", i,
      " visits=", tree[childIdx].visits,
      " avg=", formatFloat(
        tree[childIdx].solverAverage(perspective),
        ffDecimal,
        2
      ),
      " win=", formatFloat(
        tree[childIdx].solverWinRate(),
        ffDecimal,
        1
      ),
      "% best=", tree[childIdx].bestMargin,
      " worst=", tree[childIdx].worstMargin,
      " move=", tree[childIdx].move.moveText()

proc logSolverWatchRoot(
  tree: SolverTree,
  perspective: int,
  limit = 12
) =
  ## Logs ranks for high-impact root moves even outside the top table.
  let ordered = tree.sortedSolverRootChildren(perspective)
  var logged = 0
  for rank, childIdx in ordered:
    if tree[childIdx].move.kind != solver.PlacementMove or
        not tree[childIdx].move.action.isWatchedAction():
      continue
    echo "B45 rank=", rank,
      " visits=", tree[childIdx].visits,
      " avg=", formatFloat(
        tree[childIdx].solverAverage(perspective),
        ffDecimal,
        2
      ),
      " win=", formatFloat(
        tree[childIdx].solverWinRate(),
        ffDecimal,
        1
      ),
      "% best=", tree[childIdx].bestMargin,
      " worst=", tree[childIdx].worstMargin,
      " move=", tree[childIdx].move.moveText()
    inc logged
    if logged >= limit:
      return

proc logSolverDisagreement(
  state: solver.GameState,
  tree: SolverTree,
  perspective: int,
  policyChoice: solverPolicy.BasePolicyChoice,
  mctsIdx,
  sampled,
  searchMs: int,
  stoppedEarly: bool,
  searchStart,
  decisionStart: MonoTime
) =
  ## Logs large base-policy versus MCTS disagreements for later review.
  if not policyChoice.ok or mctsIdx == solver.NoPlayer:
    return
  let baseIdx = tree.findSolverRootChild(policyChoice.move)
  if baseIdx == solver.NoPlayer or baseIdx == mctsIdx:
    return
  if tree[baseIdx].visits < SolverDisagreeMinVisits or
      tree[mctsIdx].visits < SolverDisagreeMinVisits:
    return
  let
    baseAvg = tree[baseIdx].solverAverage(perspective)
    mctsAvg = tree[mctsIdx].solverAverage(perspective)
    baseWin = tree[baseIdx].solverWinRate()
    mctsWin = tree[mctsIdx].solverWinRate()
    avgDelta = mctsAvg - baseAvg
    winDelta = mctsWin - baseWin
    elapsedMs = inMilliseconds(getMonoTime() - searchStart).int
    decisionElapsedMs = inMilliseconds(getMonoTime() - decisionStart).int
    scans6s = estimateMctsScans(sampled, elapsedMs)
  if avgDelta < SolverDisagreeAvgDelta and
      winDelta < SolverDisagreeWinDelta:
    return
  echo "F16 round=", state.round,
    " phase=", $state.phase,
    " p=", perspective,
    " reason=", ord(policyChoice.reason),
    " baseVisits=", tree[baseIdx].visits,
    " baseAvg=", formatFloat(baseAvg, ffDecimal, 2),
    " baseWin=", formatFloat(baseWin, ffDecimal, 1),
    " mctsVisits=", tree[mctsIdx].visits,
    " mctsAvg=", formatFloat(mctsAvg, ffDecimal, 2),
    " mctsWin=", formatFloat(mctsWin, ffDecimal, 1),
    " avgDelta=", formatFloat(avgDelta, ffDecimal, 2),
    " winDelta=", formatFloat(winDelta, ffDecimal, 1),
    " sampled=", sampled,
    " scans6s=", scans6s,
    " early=", stoppedEarly,
    " elapsedMs=", elapsedMs,
    " decisionElapsedMs=", decisionElapsedMs,
    " searchBudgetMs=", searchMs,
    " nodes=", tree.len,
    " children=", tree[0].children.len,
    " untried=", tree[0].untried.len,
    " base=", tree[baseIdx].move.moveText(),
    " mcts=", tree[mctsIdx].move.moveText()
  echo "F17 start=", state.startingPlayer,
    " current=", state.currentPlayer,
    " deck=", state.roundDeck.len,
    " majors=", state.majorsAvailable.len
  for i in 0 ..< state.players.len:
    state.logSolverPlayer(i)

proc trySolverPlacement(mind: var BotMind, message: JsonNode): JsonNode =
  ## Tries to choose a work placement with native Monte Carlo search.
  let decisionStart = getMonoTime()
  if not mind.solverEnabled:
    return newJNull()
  let perspective = message.observationSlot()
  let parsed = message.parseSolverState(perspective)
  if not parsed.ok:
    echo "F3 error=", parsed.error
    return newJNull()
  if perspective < 0 or perspective >= parsed.state.players.len:
    echo "F4"
    return newJNull()
  try:
    let
      serverActions = message.availableActionIds().sortedUnique()
      openActions = parsed.state.solverOpenActions()
    var
      allMoves: solver.MoveBuffer
      rejected: seq[string]
    parsed.state.legalMoves(allMoves)
    let
      legalActions = allMoves.solverMoveActions()
      rootMoves = message.solverRootMoves(allMoves, rejected)
      rootActions = rootMoves.solverMoveActions()
    mind.ensurePolicyGoal(parsed.state, perspective)
    mind.logStrategy(parsed.state, perspective)
    echo "F5 id=", message.observationId(),
      " round=", parsed.state.round,
      " phase=", $parsed.state.phase,
      " player=", perspective,
      " players=", parsed.state.players.len,
      " iterations=", mind.solverIterations,
      " timeMs=", mind.solverTimeMs,
      " legalMoves=", allMoves.len,
      " rootMoves=", rootMoves.len
    parsed.state.logSolverPlayer(perspective)
    logSolverWatchPool(serverActions, allMoves, rootMoves)
    logSolverDiff(
      serverActions,
      openActions,
      legalActions,
      rootActions,
      rejected
    )
    parsed.state.logMissingSolverActions(
      perspective,
      serverActions.missingText(legalActions)
    )
    if rootMoves.len == 0:
      echo "F6"
      return newJNull()
    let policyGoal = mind.activePolicyGoal()
    let policyChoice = solverPolicy.chooseBasePolicyMove(
      parsed.state,
      perspective,
      rootMoves,
      policyGoal
    )
    when not UseMctsSearch:
      if policyChoice.ok:
        result = policyChoice.move.solverMovePlacement()
        echo "E7 reason=", ord(policyChoice.reason),
          " action=", result.strField("action"),
          " score=", formatFloat(policyChoice.score, ffDecimal, 2),
          " move=", policyChoice.move.moveText()
        return
      echo "F14"
      return newJNull()
    else:
      if policyChoice.ok:
        result = policyChoice.move.solverMovePlacement()
        echo "E7 reason=", ord(policyChoice.reason),
          " action=", result.strField("action"),
          " score=", formatFloat(policyChoice.score, ffDecimal, 2),
          " move=", policyChoice.move.moveText()
      else:
        echo "F14"
        return newJNull()
      if rootMoves.len == 1:
        result = rootMoves[0].solverMovePlacement()
        echo "F11 action=", result.strField("action")
        return
      let fallbackResult = result
      let
        clockMs = message.clockSearchBudgetMs(
          parsed.state,
          perspective,
          mind.solverTimeMs
        )
        clockLimited = message.observationTimeLeftMs() >= 0
        searchMs = remainingDecisionMs(decisionStart, clockMs)
        minSearchMs =
          if clockLimited:
            SolverClockMinSearchMs
          else:
            MinMctsTimeMs
        searchSeed = parsed.state.seed xor
          (message.observationId() + 1) xor
          (parsed.state.round shl 16)
      echo "F21 timeLeftMs=", message.observationTimeLeftMs(),
        " remaining=", parsed.state.estimatedRemainingPlacements(perspective),
        " clockMs=", clockMs,
        " searchMs=", searchMs
      if searchMs < minSearchMs:
        echo "F7 remainingMs=", searchMs
        return fallbackResult
      var
        tree: SolverTree
        searchStart = getMonoTime()
        searchDeadline = searchStart + initDuration(milliseconds = searchMs)
        softDeadline = searchDeadline
        sampled = 0
        stableIdx = solver.NoPlayer
        stableChecks = 0
        stoppedEarly = false
      if mind.solverThreads > 1:
        let parallel = runParallelSolverSearch(
          parsed.state,
          rootMoves,
          perspective,
          mind.solverMaxMoves,
          mind.solverIterations,
          searchSeed,
          searchMs,
          mind.solverThreads,
          policyGoal
        )
        tree = parallel.tree
        sampled = parallel.sampled
        echo "F20 workers=", parallel.workers,
          " failed=", parallel.failed,
          " sampled=", parallel.sampled,
          " nodes=", parallel.nodes
      else:
        let prepared = mind.prepareSolverTree(
          parsed.state,
          rootMoves
        )
        echo "F13 r=", if prepared.reused: 1 else: 0,
          " old=", prepared.oldNodes,
          " nodes=", prepared.tree.len,
          " visits=", prepared.reusedVisits
        var rng = solver.initRng(searchSeed)
        tree = prepared.tree
        for _ in 0 ..< mind.solverIterations:
          let now = getMonoTime()
          if sampled > 0 and now >= searchDeadline:
            break
          if tree.len >= SolverMaxTreeNodes:
            break
          tree.runSolverIteration(
            rng,
            perspective,
            mind.solverMaxMoves,
            policyGoal
          )
          inc sampled
          if sampled mod SolverEarlyCheckEvery == 0 and
              getMonoTime() >= softDeadline:
            let early = tree.solverGoodEnoughRootLeader(perspective)
            if early.ok:
              if early.bestIdx == stableIdx:
                inc stableChecks
              else:
                stableIdx = early.bestIdx
                stableChecks = 1
              if stableChecks >= SolverEarlyStableChecks:
                stoppedEarly = true
                break
            else:
              stableIdx = solver.NoPlayer
              stableChecks = 0
      tree.logSolverRoot(perspective)
      tree.logSolverWatchRoot(perspective)
      var childIdx = tree.bestSolverRootChild(perspective)
      if childIdx == solver.NoPlayer:
        return fallbackResult
      childIdx = tree.protectedSolverRootChild(
        perspective,
        policyChoice,
        childIdx
      )
      parsed.state.logSolverDisagreement(
        tree,
        perspective,
        policyChoice,
        childIdx,
        sampled,
        searchMs,
        stoppedEarly,
        searchStart,
        decisionStart
      )
      result = tree[childIdx].move.solverMovePlacement()
      let valid = message.validatePlacement(result)
      if not valid.ok:
        echo "F8 error=", valid.error
        mind.solverTree.clearSolverTree()
        return fallbackResult
      mind.solverTree = tree
      let
        elapsedMs = inMilliseconds(getMonoTime() - searchStart).int
        decisionElapsedMs = inMilliseconds(getMonoTime() - decisionStart).int
        scans6s = estimateMctsScans(sampled, elapsedMs)
      echo "F9 action=", result.strField("action"),
        " visits=", tree[childIdx].visits,
        " avg=", formatFloat(
          tree[childIdx].solverAverage(perspective),
          ffDecimal,
          2
        ),
        " win=", formatFloat(tree[childIdx].solverWinRate(), ffDecimal, 1),
        "% sampled=", sampled,
        " scans6s=", scans6s,
        " early=", stoppedEarly,
        " elapsedMs=", elapsedMs,
        " decisionElapsedMs=", decisionElapsedMs,
        " searchBudgetMs=", searchMs,
        " nodes=", tree.len
  except CatchableError as e:
    echo "F10 error=", e.msg
    result = newJNull()

proc placeReply(message, placement: JsonNode): JsonNode =
  ## Builds one Coworld placement reply.
  result = newJObject()
  if message.usesReplyEnvelope():
    result["type"] = %"reply"
    result["id"] = %message.observationId()
    result["decision"] = placement
  else:
    result["type"] = %"place"
    result["decisionId"] = %message.observationId()
    result["placement"] = placement

proc feedReply(message, decision: JsonNode): JsonNode =
  ## Builds one Coworld feeding reply.
  result = newJObject()
  if message.usesReplyEnvelope():
    result["type"] = %"reply"
    result["id"] = %message.observationId()
    result["decision"] = decision
  else:
    result["type"] = %"feed"
    result["decisionId"] = %message.observationId()
    result["decision"] = decision

proc decidePlacement(mind: var BotMind, message: JsonNode): JsonNode =
  ## Chooses one placement with native solver search.
  let placement = mind.trySolverPlacement(message)
  if placement.kind == JObject:
    echo "F11 action=", placement.strField("action")
    return message.placeReply(placement)
  let fallback = message.fallbackPlacement()
  echo "F12 action=", fallback.strField("action")
  message.placeReply(fallback)

proc decideFeeding(mind: var BotMind, message: JsonNode): JsonNode =
  ## Chooses one deterministic feeding decision.
  let
    choices = message.observationChoices()
    player = message.playerNode()
    options = message.feedingOptions()
    needed = message.feedingNeed(choices, player)
    food = player.field("resources").intField("food")
    decision = message.fallbackFeeding()
  let valid = validateFeeding(decision)
  if valid.ok:
    echo "G1 need=", needed,
      " food=", food,
      " options=", options.arrayLen(),
      " -> ", decision.jsonText(220)
    return message.feedReply(decision)
  echo "G2 error=", valid.error
  message.feedReply(%*{"conversions": []})

proc receiveServerMessage(ws: WebSocket, timeout = -1): JsonNode =
  ## Receives the next JSON message from the websocket.
  while true:
    let message = ws.receiveMessage(timeout)
    if message.isNone:
      return nil
    case message.get().kind
    of TextMessage:
      try:
        return parseJson(message.get().data)
      except JsonParsingError as e:
        echo "H1 error=", e.msg
    of Ping:
      ws.send(message.get().data, Pong)
    of BinaryMessage, Pong:
      discard

proc elapsedMs(start: MonoTime): int64 =
  ## Returns elapsed milliseconds since one monotonic timestamp.
  inMilliseconds(getMonoTime() - start)

proc beginOutage(outageActive: var bool, outageStart: var MonoTime) =
  ## Starts a reconnect outage window when one is not already active.
  if not outageActive:
    outageActive = true
    outageStart = getMonoTime()

proc reconnectExpired(outageStart: MonoTime): bool =
  ## Returns true when the reconnect window has elapsed.
  elapsedMs(outageStart) >= ReconnectWindowMs.int64

proc sendReply(ws: WebSocket, reply: JsonNode) =
  ## Sends one JSON text reply to the Coworld server.
  ws.send($reply, TextMessage)
  flushFile(stdout)

proc handleObservation(
  ws: WebSocket,
  mind: var BotMind,
  message: JsonNode
) =
  ## Handles one Agricogla observation message.
  let reason = message.observationReason()
  if reason.len > 0:
    echo "H2 reason=", reason
    mind.recordServerError(reason)
  else:
    mind.clearServerError()
  case message.observationPhase()
  of "work":
    ws.sendReply(mind.decidePlacement(message))
  of "feeding":
    ws.sendReply(mind.decideFeeding(message))
  else:
    echo "H3 phase=", message.observationPhase()

proc runBot(config: BotRunConfig) =
  ## Connects to Agricogla and plays one Terra episode.
  let endpoint = config.connectUrl()
  var mind = newBotMind(
    config.solverEnabled,
    config.solverIterations,
    config.solverMaxMoves,
    config.solverTimeMs,
    config.solverThreads
  )
  setMaxPoolSize(mind.solverThreads)
  echo "H1 cores=", countProcessors()
  echo "H4 iterations=", mind.solverIterations,
    " timeMs=", mind.solverTimeMs,
    " threads=", mind.solverThreads,
    " scanWindowMs=", MctsScanWindowMs
  var
    hasConnected = false
    notifiedFailure = false
    outageActive = true
    outageStart = getMonoTime()
    attempts = 0
  while true:
    var ws: WebSocket
    try:
      inc attempts
      if hasConnected or notifiedFailure:
        echo "H5 attempts=", attempts, " url=",
          endpoint.redactedUrl()
      ws = newWebSocket(endpoint)
      echo "H6 url=", endpoint.redactedUrl()
      flushFile(stdout)
      hasConnected = true
      notifiedFailure = false
      outageActive = false
      attempts = 0

      while true:
        let message = ws.receiveServerMessage()
        if message == nil:
          break
        case message.strField("type")
        of "welcome":
          let playerCount = message.intField(
            "numPlayers",
            message.field("config").intField("players")
          )
          echo "H7 slot=", message.intField("slot"),
            " of ", playerCount
        of "observation":
          ws.handleObservation(mind, message)
        of "final":
          let finalText =
            if message.field("results").kind != JNull:
              message.field("results").jsonText(500)
            else:
              message.field("scores").jsonText(500)
          echo "H8 results=", finalText
          ws.close()
          return
        of "error":
          let error = message.strField("error")
          echo "H9 error=", error
          mind.recordServerError(error)
        else:
          echo "H10 type=", message.strField("type")

      if not ws.isNil:
        ws.close()
      beginOutage(outageActive, outageStart)
      echo "H11 retryMs=",
        ReconnectAttemptMs, " ms"
      flushFile(stdout)
      if reconnectExpired(outageStart):
        echo "H12 windowMs=",
          ReconnectWindowMs, " ms; exiting"
        return
      sleep(ReconnectAttemptMs)

    except CatchableError as e:
      if not ws.isNil:
        ws.close()
      beginOutage(outageActive, outageStart)
      if notifiedFailure:
        echo "H13 error=", e.msg
      elif hasConnected:
        echo "H14 error=", e.msg
        notifiedFailure = true
      else:
        echo "H15 error=", e.msg
        notifiedFailure = true
      echo "H16 retryMs=", ReconnectAttemptMs, " ms"
      flushFile(stdout)
      if reconnectExpired(outageStart):
        echo "H12 windowMs=",
          ReconnectWindowMs, " ms; exiting"
        return
      sleep(ReconnectAttemptMs)

when isMainModule:
  let config = readBotRunConfig()
  runBot(config)
