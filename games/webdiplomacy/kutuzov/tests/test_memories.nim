import
  std/[json, os, strutils],
  ../[budgets, engines, protocols, requests]

const
  RejectedMemory = "Final spring 1908: keep the supported move from " &
    "Budapest to Rumania for an immediate autumn center gain. " &
    "Turkey's new proposal conflicts with that move; no acceptance."
  RetreatMemory = "Retreated Norway army to vacant St. Petersburg. " &
    "Final spring 1908 objective: pursue an immediate autumn center gain."

proc context(turn: int, phase: string): JsonNode =
  ## Supply the native phase stamp and empty private order slots.
  %*{
    "game": {"turn": turn, "phase": phase, "processTime": 200},
    "orders": {"orders": []}
  }

proc observed(state: BotState, current: JsonNode): JsonNode =
  ## Build an observation with the same phase as the private context.
  let
    config = GameConfig(
      gameId: 1,
      countryId: 7,
      endYear: 1908,
      scoring: "sum_of_squares"
    )
    board = %*{
      "turn": current["game"]["turn"],
      "phase": current["game"]["phase"],
      "units": [],
      "territories": [],
      "members": []
    }
  observation(
    config,
    current,
    board,
    %*{"phases": []},
    PressContext(messages: newJArray()),
    state,
    defaultBudgetConfig(),
    "plan"
  )

echo "Testing verified movement memory across retreats and builds"
block:
  var state = BotState(phase: PhaseState(savedOrders: newJArray()))
  let movement = context(14, "Diplomacy")
  # These exact memories are from v106 Russia decisions 7881 and 8355.
  # The runtime calls this helper after the order save is verified.
  state.rememberMovement(movement, RejectedMemory)
  doAssert state.memory == RejectedMemory
  doAssert state.memoryStamp == "14:Diplomacy"
  state.rememberMovement(context(14, "Retreats"), RetreatMemory)
  state.rememberMovement(context(15, "Builds"), "No builds remain.")
  doAssert state.memory == RejectedMemory
  doAssert state.memoryStamp == "14:Diplomacy"
  let next = state.observed(context(15, "Diplomacy"))
  doAssert next["turn"].getInt == 15
  doAssert next["memory"].getStr == RejectedMemory
  doAssert next["memory_phase"].getStr == "14:Diplomacy"
  state.rememberMovement(
    context(15, "Diplomacy"),
    "Final autumn: no renewed Turkish Trieste commitment."
  )
  doAssert state.memory ==
    "Final autumn: no renewed Turkish Trieste commitment."
  doAssert state.memoryStamp == "15:Diplomacy"
  state.rememberMovement(context(15, "Diplomacy"), "Revised verified plan.")
  doAssert state.memory == "Revised verified plan."
  doAssert state.memoryStamp == "15:Diplomacy"

echo "Testing memory provenance in full, delta, and rebased observations"
block:
  let
    config = RequestConfig(
      api: ChatApi,
      model: DefaultHostedModel,
      reasoningEffort: "low",
      maxOutputTokens: 3000
    )
    current = context(15, "Diplomacy")
  var
    state = BotState(phase: PhaseState(savedOrders: newJArray()))
    limits = defaultBudgetConfig()
  state.rememberMovement(context(14, "Diplomacy"), RejectedMemory)
  limits.maxContextBytes = 12_000
  let
    input = state.observed(current)
    first = prepareInput(config, "rules", input, state.phase, limits)
    full = parseJson(first.text)
  doAssert full["memory"].getStr == RejectedMemory
  doAssert full["memory_phase"].getStr == "14:Diplomacy"
  state.phase.recordExchange(
    first.text,
    "{}",
    %*{"orders_verified": true, "saved_orders": [], "confirmed_press": []},
    limits
  )
  let
    following = prepareInput(config, "rules", input, state.phase, limits)
    delta = parseJson(following.text)
  doAssert delta["phase_update"].getBool
  doAssert not delta.hasKey("board")
  doAssert delta["memory"].getStr == RejectedMemory
  doAssert delta["memory_phase"].getStr == "14:Diplomacy"
  state.phase.transcript.add %*{
    "role": "assistant", "content": repeat("X", 13_000)
  }
  let
    rebased = prepareInput(config, "rules", input, state.phase, limits)
    fresh = parseJson(rebased.text)
  doAssert rebased.rebased
  doAssert rebased.transcript.len == 0
  doAssert fresh.hasKey("board")
  doAssert fresh["memory"].getStr == RejectedMemory
  doAssert fresh["memory_phase"].getStr == "14:Diplomacy"

echo "Testing legacy state and persisted movement provenance"
block:
  let
    path = getTempDir() / ("kutuzov-memory-test-" &
      $getCurrentProcessId() & ".json")
    config = GameConfig(gameId: 1, countryId: 7)
    legacy = %*{
      "gameId": 1, "countryId": 7, "memory": RejectedMemory
    }
  defer:
    if fileExists(path):
      removeFile(path)
    if fileExists(path & ".tmp"):
      removeFile(path & ".tmp")
  doAssert not legacy.hasKey("memoryStamp")
  writeFile(path, $legacy)
  var recovered = restore(config, path)
  doAssert recovered.memory == RejectedMemory
  doAssert recovered.memoryStamp == ""
  let input = recovered.observed(context(15, "Diplomacy"))
  doAssert input["memory"].getStr == RejectedMemory
  doAssert input["memory_phase"].kind == JNull
  recovered.rememberMovement(context(15, "Retreats"), RetreatMemory)
  doAssert recovered.memory == RejectedMemory
  doAssert recovered.memoryStamp == ""
  recovered.rememberMovement(context(15, "Diplomacy"), "Verified final plan.")
  recovered.persist(path)
  let saved = restore(config, path)
  doAssert saved.memory == "Verified final plan."
  doAssert saved.memoryStamp == "15:Diplomacy"
  doAssert saved.observed(context(15, "Retreats"))["memory_phase"].getStr ==
    "15:Diplomacy"
