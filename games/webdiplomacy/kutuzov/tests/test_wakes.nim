import
  std/os,
  ../[budgets, common, wakes]

template expectError(body: untyped) =
  ## Require invalid configuration to use the project exception type.
  block:
    var raised = false
    try:
      body
    except KutuzovError:
      raised = true
    doAssert raised

echo "Testing bounded wake defaults and configuration"
block:
  let config = defaultWakeConfig()
  config.validate()
  doAssert config.maxRequests == 4
  doAssert config.maxWakes == 3
  doAssert config.durationSeconds == 120
  doAssert config.quietSeconds == 20
  doAssert config.maxDebounceSeconds == 40
  doAssert config.saveSeconds == 30
  for field in 0 .. 5:
    var invalid = config
    case field
    of 0:
      invalid.maxRequests = 5
    of 1:
      invalid.maxWakes = 4
    of 2:
      invalid.durationSeconds = 121
    of 3:
      invalid.saveSeconds = 29
    of 4:
      invalid.quietSeconds = 41
    else:
      invalid.maxDebounceSeconds = -1
    expectError:
      invalid.validate()

echo "Testing four requests per wake and twelve per movement phase"
block:
  let config = defaultWakeConfig()
  var state: WakeState
  doAssert not state.takeRequest(config, 100, 1000)
  doAssert state.nextWake(
    config, 100, 1000, false, false, "", false
  ) == InitialWake
  doAssert state.startWake(config, InitialWake, 100, 1000)
  doAssert state.deadline == 220
  doAssert not state.startWake(config, InitialWake, 100, 1000)
  for i in 0 ..< 4:
    doAssert state.takeRequest(config, 100 + i, 1000)
    doAssert state.count == 1
    doAssert state.calls == i + 1
    doAssert state.totalCalls == i + 1
  doAssert state.active, "The fourth response can still execute its tools"
  doAssert not state.takeRequest(config, 105, 1000)
  doAssert not state.active and not state.completed
  doAssert state.ending == RequestLimit
  doAssert state.nextWake(
    config, 105, 1000, true, false, "offer", false
  ) == NoWake
  doAssert state.nextWake(
    config, 124, 1000, true, false, "offer", false
  ) == NoWake
  doAssert state.nextWake(
    config, 125, 1000, true, false, "offer", false
  ) == PressWake
  doAssert state.startWake(config, PressWake, 125, 1000)
  for i in 0 ..< 4:
    doAssert state.takeRequest(config, 125 + i, 1000)
  state.finishWake()
  doAssert state.completed and state.pressUsed
  doAssert state.count == 2 and state.totalCalls == 8
  doAssert state.nextWake(
    config, 150, 1000, true, false, "new offer", false
  ) == NoWake
  doAssert state.nextWake(
    config, 190, 1000, true, false, "new offer", false
  ) == NoWake
  doAssert not state.startWake(config, PressWake, 190, 1000)
  doAssert state.nextWake(
    config, 200, 1000, true, false, "new offer", true
  ) == ReviewWake
  doAssert state.startWake(config, ReviewWake, 200, 1000)
  for i in 0 ..< 4:
    doAssert state.takeRequest(config, 200 + i, 1000)
  state.finishWake()
  doAssert state.reviewed and state.reviewStarted
  doAssert state.count == 3 and state.totalCalls == 12
  doAssert not state.startWake(config, RepairWake, 210, 1000)
  doAssert not state.takeRequest(config, 210, 1000)
  doAssert state.nextWake(
    config, 210, 1000, false, true, "urgent", true
  ) == NoWake

echo "Testing quiet and maximum press debounce without call padding"
block:
  let config = defaultWakeConfig()
  var state: WakeState
  doAssert state.startWake(config, InitialWake, 0, 1000)
  doAssert state.takeRequest(config, 0, 1000)
  state.finishWake()
  for item in [(0, "first"), (19, "second"), (39, "third")]:
    doAssert state.nextWake(
      config, item[0], 1000, true, false, item[1], false
    ) == NoWake
  doAssert state.nextWake(
    config, 40, 1000, true, false, "fourth", false
  ) == PressWake
  doAssert state.count == 1 and state.totalCalls == 1
  doAssert state.nextWake(
    config, 41, 1000, true, false, "", false
  ) == NoWake
  doAssert state.pendingSignature.len == 0
  doAssert state.nextWake(
    config, 42, 1000, true, false, "fifth", false
  ) == NoWake
  doAssert state.nextWake(
    config, 61, 1000, true, false, "fifth", false
  ) == NoWake
  doAssert state.nextWake(
    config, 62, 1000, true, false, "fifth", false
  ) == PressWake
  doAssert state.totalCalls == 1

echo "Testing model finish allows a later review and keeps tool steps in wake"
block:
  let config = defaultWakeConfig()
  var state: WakeState
  doAssert state.startWake(config, InitialWake, 100, 1000)
  doAssert state.takeRequest(config, 100, 1000)
  doAssert state.nextWake(
    config, 101, 1000, false, true, "new offer", false
  ) == NoWake
  doAssert state.takeRequest(config, 102, 1000)
  doAssert state.count == 1 and state.calls == 2
  doAssert not state.pressUsed
  state.finishWake()
  doAssert state.completed and not state.reviewed
  doAssert not state.takeRequest(config, 103, 1000)
  doAssert state.nextWake(
    config, 104, 1000, true, false, "", false
  ) == NoWake
  doAssert state.nextWake(
    config, 200, 1000, true, false, "offer", true
  ) == ReviewWake
  doAssert state.startWake(config, ReviewWake, 200, 1000)
  doAssert state.takeRequest(config, 200, 1000)
  state.finishWake()
  doAssert state.reviewed and state.totalCalls == 3
  doAssert not state.startWake(config, ReviewWake, 201, 1000)
  doAssert not state.startWake(config, PressWake, 201, 1000)

echo "Testing wake expiry and a thirty-second save buffer"
block:
  let config = defaultWakeConfig()
  var state: WakeState
  doAssert state.startWake(config, InitialWake, 100, 230)
  doAssert state.deadline == 200
  doAssert state.remainingSeconds(config, 199, 230) == 1
  doAssert state.takeRequest(config, 199, 230)
  doAssert not state.takeRequest(config, 200, 230)
  doAssert state.ending == TimeLimit and state.totalCalls == 1
  doAssert not state.startWake(config, RepairWake, 200, 230)
  doAssert state.nextWake(
    config, 200, 230, false, true, "urgent", true
  ) == NoWake
  state = WakeState()
  doAssert state.startWake(config, InitialWake, 10, 1000)
  doAssert state.deadline == 130
  doAssert state.remainingSeconds(config, 20, 40) == 0
  doAssert not state.takeRequest(config, 20, 40)
  doAssert state.totalCalls == 0 and state.ending == TimeLimit
  expectError:
    discard state.startWake(config, InitialWake, -1, 1000)

echo "Testing required repairs cannot bypass wake or request limits"
block:
  let config = defaultWakeConfig()
  var state: WakeState
  doAssert state.startWake(config, InitialWake, 0, 1000)
  doAssert state.takeRequest(config, 0, 1000)
  state.finishWake(RequestLimit)
  for i in 1 .. 2:
    doAssert state.nextWake(
      config, i, 1000, false, true, "unread", true
    ) == RepairWake
    doAssert state.startWake(config, RepairWake, i, 1000)
    doAssert state.takeRequest(config, i, 1000)
    state.finishWake()
  doAssert state.count == 3 and state.totalCalls == 3
  doAssert state.nextWake(
    config, 3, 1000, false, true, "unread", true
  ) == NoWake
  doAssert not state.startWake(config, InitialWake, 3, 1000)
  doAssert not state.startWake(config, ReviewWake, 3, 1000)
  var lower = config
  lower.maxWakes = 2
  lower.maxRequests = 2
  state = WakeState()
  doAssert state.startWake(lower, InitialWake, 10, 1000)
  doAssert state.takeRequest(lower, 10, 1000)
  state.finishWake()
  doAssert not state.startWake(lower, PressWake, 40, 1000)
  doAssert state.startWake(lower, ReviewWake, 40, 1000)
  doAssert state.takeRequest(lower, 40, 1000)
  doAssert state.takeRequest(lower, 41, 1000)
  doAssert not state.takeRequest(lower, 42, 1000)
  doAssert state.count == 2 and state.totalCalls == 3

echo "Testing budget and phase exits do not create acknowledgement calls"
block:
  let
    config = defaultWakeConfig()
    limits = BudgetConfig(
      mode: EmpiricalBudget, limitUsd: 0.50, reserveUsd: 0.10
    )
  var
    state: WakeState
    budget = Budget(mode: EmpiricalBudget, spentUsd: 0.40)
  doAssert state.startWake(config, InitialWake, 0, 1000)
  doAssert not budget.reserve(limits, 0.04)
  state.finishWake(BudgetLimit)
  doAssert state.calls == 0 and state.totalCalls == 0
  doAssert state.ending == BudgetLimit and not state.completed
  doAssert not state.takeRequest(config, 1, 1000)
  doAssert budget.spentUsd == 0.40 and budget.reservedUsd == 0.0
  doAssert state.startWake(config, RepairWake, 2, 1000)
  state.finishWake(PhaseChanged)
  doAssert not state.active and state.totalCalls == 0
  doAssert not state.takeRequest(config, 3, 1000)
  doAssert not requiresCenterCheck(false, false)
  doAssert requiresCenterCheck(false, true)
  doAssert requiresCenterCheck(true, false)
  doAssert requiresCenterCheck(true, true)

echo "Testing opt-in tool-loop budget defaults and explicit lower caps"
block:
  const Names = [
    "KUTUZOV_BUDGET_MODE", "KUTUZOV_TOOL_LOOP", "KUTUZOV_BUDGET_USD",
    "KUTUZOV_RESERVE_USD", "KUTUZOV_PRESS_MODEL", "KUTUZOV_MAX_PHASE_CALLS",
    "KUTUZOV_MAX_PRESS_CALLS", "KUTUZOV_MAX_PRESS_CHARACTERS",
    "KUTUZOV_MAX_OPPONENT_CHARACTERS", "KUTUZOV_MAX_MESSAGE_CHARACTERS",
    "KUTUZOV_MAX_MESSAGES_PER_OPPONENT", "KUTUZOV_MAX_CONTEXT_BYTES"
  ]
  var
    existed: array[Names.len, bool]
    previous: array[Names.len, string]
  for i, name in Names:
    existed[i] = existsEnv(name)
    previous[i] = getEnv(name)
    delEnv(name)
  try:
    let defaults = loadBudgetConfig()
    doAssert not defaults.toolLoop
    doAssert defaults.maxPhaseCalls == 4 and defaults.maxPressCalls == 2
    for mode in ["conservative", "empirical"]:
      putEnv("KUTUZOV_BUDGET_MODE", mode)
      for enabled in ["true", "1"]:
        putEnv("KUTUZOV_TOOL_LOOP", enabled)
        let tools = loadBudgetConfig()
        doAssert tools.toolLoop
        doAssert tools.maxPhaseCalls == 12 and tools.maxPressCalls == 1
        doAssert tools.limitUsd == defaults.limitUsd
        doAssert tools.reserveUsd == defaults.reserveUsd
      putEnv("KUTUZOV_MAX_PHASE_CALLS", "6")
      putEnv("KUTUZOV_MAX_PRESS_CALLS", "0")
      let lower = loadBudgetConfig()
      doAssert lower.maxPhaseCalls == 6 and lower.maxPressCalls == 0
      putEnv("KUTUZOV_MAX_PHASE_CALLS", "13")
      expectError:
        discard loadBudgetConfig()
      putEnv("KUTUZOV_MAX_PHASE_CALLS", "12")
      putEnv("KUTUZOV_MAX_PRESS_CALLS", "2")
      expectError:
        discard loadBudgetConfig()
      delEnv("KUTUZOV_MAX_PHASE_CALLS")
      delEnv("KUTUZOV_MAX_PRESS_CALLS")
      for disabled in ["false", "0", ""]:
        putEnv("KUTUZOV_TOOL_LOOP", disabled)
        let legacy = loadBudgetConfig()
        doAssert not legacy.toolLoop
        doAssert legacy.maxPhaseCalls == 4 and legacy.maxPressCalls == 2
    putEnv("KUTUZOV_TOOL_LOOP", "yes")
    expectError:
      discard loadBudgetConfig()
    putEnv("KUTUZOV_TOOL_LOOP", "false")
    putEnv("KUTUZOV_MAX_PHASE_CALLS", "5")
    expectError:
      discard loadBudgetConfig()
  finally:
    for i, name in Names:
      if existed[i]:
        putEnv(name, previous[i])
      else:
        delEnv(name)

echo "Wake scheduler tests passed"
