import
  std/[json, os, strutils],
  ../[budgets, common]

template expectError(body: untyped) =
  ## Verifies that invalid boundary input raises the library exception.
  block:
    var raised = false
    try:
      body
    except KutuzovError:
      raised = true
    doAssert raised

proc near(actual: float, expected: float) {.raises: [].} =
  ## Compares money values without relying on exact binary fractions.
  doAssert abs(actual - expected) < 0.000000001

echo "Testing model prices and conservative reservations"
block:
  near(estimateCost("gpt-6.1-sol", 100_000, 1_000), 0.21)
  near(estimateCost("openai/gpt-6.1-sol", 100_000, 1_000), 0.21)
  near(estimateCost("gpt-6.1-sol", 100_000, 1_000, 80_000), 0.058)
  near(estimateCost("gpt-6.1-sol", 100_000, 1_000, 0, 100_000), 0.26)
  near(estimateCost("gpt-6-luna", 100_000, 1_000), 0.0105)
  near(estimateCost("openai/gpt-6-luna", 100_000, 1_000), 0.0105)
  near(reserveCost("gpt-6.1-sol", 45_000, 2_000), 0.1325)
  expectError:
    discard estimateCost("gpt-future-sol", 100, 100)
  expectError:
    discard estimateCost("gpt-6.1-sol", -1, 100)
  expectError:
    discard estimateCost("gpt-6.1-sol", 100, 100, 90, 20)
  expectError:
    discard reserveCost("gpt-6.1-sol", 272_000, 100)
  let custom = ModelRates(
    inputUsd: 1,
    cachedUsd: 0.1,
    cacheWriteUsd: 1.25,
    outputUsd: 3
  )
  near(estimateCost(custom, 1_000, 1_000), 0.004)

echo "Testing the budget, final-year reserve, and authoritative spend"
block:
  let config = defaultBudgetConfig()
  var budget: Budget
  validate(config)
  doAssert canSpend(budget, config, 1.55)
  doAssert not canSpend(budget, config, 1.56)
  doAssert canSpend(budget, config, 1.85, true)
  doAssert not canSpend(budget, config, 1.86, true)
  doAssert reserve(budget, config, 1.0)
  near(budgetSpent(budget), 1.0)
  doAssert not canSpend(budget, config, 0.56)
  settle(budget, 1.0, 0.10)
  near(budgetSpent(budget), 0.10)
  updateSpend(budget, 0.25)
  near(budgetSpent(budget), 0.25)
  updateSpend(budget, 0.20)
  near(budgetSpent(budget), 0.25)
  charge(budget, 0.05)
  near(budgetSpent(budget), 0.30)
  doAssert reserve(budget, config, 1.25)
  doAssert not canSpend(budget, config, 0.01)
  doAssert canSpend(budget, config, 0.30, true)
  settle(budget, 1.25, 1.25)
  near(budgetSpent(budget), 1.55)
  doAssert not canSpend(budget, config, NaN)
  expectError:
    charge(budget, -1.0)
  expectError:
    updateSpend(budget, Inf)
  expectError:
    settle(budget, 1.0, 1.0)

echo "Testing invalid environment configuration"
block:
  const Name = "KUTUZOV_BUDGET_USD"
  let
    existed = existsEnv(Name)
    previous = getEnv(Name)
  try:
    putEnv(Name, "not a price")
    expectError:
      discard loadBudgetConfig()
    putEnv(Name, "2.01")
    expectError:
      discard loadBudgetConfig()
    putEnv(Name, "nan")
    expectError:
      discard loadBudgetConfig()
  finally:
    if existed:
      putEnv(Name, previous)
    else:
      delEnv(Name)

echo "Testing opt-in empirical configuration and bounded cadence"
block:
  const Name = "KUTUZOV_BUDGET_MODE"
  let
    existed = existsEnv(Name)
    previous = getEnv(Name)
  try:
    delEnv(Name)
    doAssert loadBudgetConfig().mode == ConservativeBudget
    putEnv(Name, "conservative")
    doAssert loadBudgetConfig().mode == ConservativeBudget
    putEnv(Name, "empirical")
    doAssert loadBudgetConfig().mode == EmpiricalBudget
    putEnv(Name, "unknown")
    expectError:
      discard loadBudgetConfig()
  finally:
    if existed:
      putEnv(Name, previous)
    else:
      delEnv(Name)
  var config = defaultBudgetConfig()
  config.maxPhaseCalls = 5
  config.maxPressCalls = 3
  validate(config)
  config.mode = EmpiricalBudget
  expectError:
    validate(config)
  config.maxPhaseCalls = 4
  expectError:
    validate(config)
  config.maxPressCalls = 2
  validate(config)

echo "Testing empirical priors, known costs, and stopping reserves"
block:
  var
    config = defaultBudgetConfig()
    budget = Budget(mode: EmpiricalBudget)
  config.mode = EmpiricalBudget
  config.limitUsd = 0.50
  config.reserveUsd = 0.10
  near(expectedCost(budget, "gpt-6.1-sol"), SolPriorUsd)
  near(expectedCost(budget, "openai/gpt-6-luna"), LunaPriorUsd)
  near(empiricalCost(budget, "openai/gpt-6.1-sol"), 0.04)
  near(empiricalCost(budget, "gpt-6-luna"), 0.003)
  near(stoppingReserve(budget, config), 0.10)
  near(stoppingReserve(budget, config, true), 0.05)
  doAssert reserve(budget, config, 0.04)
  settleKnown(budget, "openai/gpt-6.1-sol", 0.04, 0.01)
  near(expectedCost(budget, "gpt-6.1-sol"), 0.01)
  near(empiricalCost(budget, "gpt-6.1-sol"), 0.04)
  doAssert reserve(budget, config, 0.04)
  settleKnown(budget, "gpt-6.1-sol", 0.04, 0.03)
  near(expectedCost(budget, "openai/gpt-6.1-sol"), 0.02)
  near(empiricalCost(budget, "gpt-6.1-sol"), 0.06)
  doAssert budget.modelCosts[0].observed == 2
  doAssert budget.modelCosts[1].observed == 0
  near(expectedCost(budget, "gpt-6-luna"), LunaPriorUsd)
  doAssert reserve(budget, config, 0.003)
  settleKnown(budget, "gpt-6-luna", 0.003, 0.0008)
  near(expectedCost(budget, "openai/gpt-6-luna"), 0.0008)
  near(empiricalCost(budget, "gpt-6-luna"), 0.003)
  doAssert reserve(budget, config, 0.06)
  settleKnown(budget, "gpt-6.1-sol", 0.06, 0.08)
  near(budget.spentUsd, 0.1208)
  near(expectedCost(budget, "gpt-6.1-sol"), 0.05)
  near(empiricalCost(budget, "gpt-6.1-sol"), 0.16)
  near(stoppingReserve(budget, config), 0.16)
  near(stoppingReserve(budget, config, true), 0.16)
  doAssert reserve(budget, config, 0.01)
  expectError:
    settleKnown(budget, "unsupported", 0.01, 0.01)
  expectError:
    settleKnown(budget, "gpt-6.1-sol", 0.01, NaN)
  near(budget.reservedUsd, 0.01)
  doAssert budget.modelCosts[0].observed == 3
  expectError:
    discard expectedCost(budget, "unsupported")
  expectError:
    discard empiricalCost(budget, "unsupported")

echo "Testing ambiguous costs survive meter advances without becoming facts"
block:
  var
    config = defaultBudgetConfig()
    budget = Budget(mode: EmpiricalBudget)
  config.mode = EmpiricalBudget
  config.limitUsd = 0.50
  config.reserveUsd = 0.10
  updateSpend(budget, 0.22558241)
  doAssert reserve(budget, config, empiricalCost(budget, "gpt-6.1-sol"))
  settleUnknown(budget, 0.04)
  for i in 0 ..< 3:
    doAssert reserve(budget, config, empiricalCost(budget, "gpt-6-luna"))
    settleUnknown(budget, 0.003)
  near(budget.spentUsd, 0.22558241)
  near(budget.authoritativeSpentUsd, 0.22558241)
  near(budget.uncertainUsd, 0.049)
  near(budget.reservedUsd, 0.0)
  near(budgetSpent(budget), 0.27458241)
  doAssert budget.uncertainCalls == 4
  doAssert budget.modelCosts[0].observed == 0
  doAssert budget.modelCosts[1].observed == 0
  doAssert canSpend(budget, config, empiricalCost(budget, "gpt-6.1-sol"))
  updateSpend(budget, 0.24)
  near(budget.uncertainUsd, 0.049)
  near(budgetSpent(budget), 0.289)
  updateSpend(budget, 0.20)
  near(budgetSpent(budget), 0.289)
  doAssert budget.uncertainCalls == 4
  expectError:
    settleUnknown(budget, 0.01)
  doAssert budget.uncertainCalls == 4
  var conservative: Budget
  doAssert reserve(conservative, defaultBudgetConfig(), 0.14)
  settleUnknown(conservative, 0.14)
  near(conservative.spentUsd, 0.14)
  near(conservative.uncertainUsd, 0.0)
  doAssert conservative.uncertainCalls == 0

echo "Testing front-loaded spending and soft movement pacing"
block:
  var
    config = defaultBudgetConfig()
    budget = Budget(mode: EmpiricalBudget)
  config.mode = EmpiricalBudget
  config.limitUsd = 0.50
  config.reserveUsd = 0.10
  near(movementAllowance(budget, config, 0, 1908), 0.40 / 14.0)
  near(movementAllowance(budget, config, 1, 1908), 0.40 / 13.0)
  near(movementAllowance(budget, config, 12, 1908), 0.20)
  near(movementAllowance(budget, config, 13, 1908), 0.40)
  near(movementAllowance(budget, config, 14, 1908), 0.225)
  near(movementAllowance(budget, config, 15, 1908), 0.46)
  near(movementAllowance(budget, config, 16, 1908), 0.0)
  near(movementAllowance(budget, config, -1, 1908), 0.0)
  doAssert canSpend(budget, config, 0.04)
  doAssert empiricalCost(budget, "gpt-6.1-sol") >
    movementAllowance(budget, config, 0, 1908)
  updateSpend(budget, 0.38)
  doAssert not canSpend(budget, config, 0.04)
  doAssert canSpend(budget, config, 0.04, true)
  near(movementAllowance(budget, config, 0, 1908), 0.02 / 14.0)
  near(movementAllowance(budget, config, 14, 1908), 0.035)
  near(movementAllowance(budget, config, 15, 1908), 0.08)
  updateSpend(budget, 0.48)
  near(movementAllowance(budget, config, 14, 1908), 0.0)
  doAssert not canSpend(budget, config, 0.04, true)
  budget.modelCosts[0].largestUsd = 0.30
  near(stoppingReserve(budget, config), 0.60)
  doAssert not canSpend(budget, config, 0.0, true)

echo "Testing bounded press and replay-resistant signatures"
block:
  let config = defaultBudgetConfig()
  var messages = %*[
    {"fromCountryID": 2, "toCountryID": 1, "message": "old offer"},
    {"fromCountryID": 2, "toCountryID": 1, "message": "new offer"},
    {"fromCountryID": 1, "toCountryID": 2, "message": "our own reply"},
    {"fromCountryID": 3, "toCountryID": 0, "message": "public offer"},
    {"fromCountryID": 3, "toCountryID": 4, "message": "private elsewhere"},
    {"fromCountryID": 4, "message": "unknown recipient"}
  ]
  let first = trimPress(messages, 1, config)
  doAssert first.messages.len == 3
  doAssert first.omitted == 3
  messages.add(%*{
    "fromCountryID": "2",
    "toCountryID": "1",
    "message": "new offer",
    "timeSent": 999
  })
  let repeated = trimPress(messages, 1, config)
  doAssert repeated.messages.len == 3
  doAssert repeated.signature == first.signature
  messages.add(%*{
    "fromCountryID": 2,
    "toCountryID": 1,
    "message": "old offer"
  })
  doAssert trimPress(messages, 1, config).signature == first.signature
  messages.add(%*{
    "fromCountryID": 2,
    "toCountryID": 1,
    "message": "changed plan"
  })
  doAssert trimPress(messages, 1, config).signature != first.signature
  doAssert trimPress(nil, 1, config).messages.len == 0
  doAssert trimPress(nil, 1, config).signature ==
    trimPress(newJArray(), 1, config).signature

echo "Testing spam and UTF-8 bounds"
block:
  var
    config = defaultBudgetConfig()
    messages = newJArray()
  for i in 0 ..< 2_000:
    messages.add(%*{
      "fromCountryID": 2 + i mod 6,
      "toCountryID": 1,
      "message": $i & repeat("a", 4_000)
    })
  config.maxPressCharacters = 1_100
  let press = trimPress(messages, 1, config)
  var
    total = 0
    counts: array[8, int]
    lengths: array[8, int]
  for message in press.messages:
    let
      sender = message["fromCountryID"].getInt
      length = message["message"].getStr.len
    inc counts[sender]
    lengths[sender] += length
    total += length
    doAssert length <= config.maxMessageCharacters
  doAssert total <= config.maxPressCharacters
  for sender in 1 .. 7:
    doAssert counts[sender] <= config.maxMessagesPerOpponent
    doAssert lengths[sender] <= config.maxOpponentCharacters
  doAssert press.omitted == messages.len - press.messages.len
  config.maxMessageCharacters = 3
  let unicode = trimPress(
    %*[{"fromCountryID": 2, "toCountryID": 1, "message": "ééé"}],
    1,
    config
  )
  doAssert unicode.messages[0]["message"].getStr == "é"
  config.maxPressCharacters = 0
  doAssert trimPress(messages, 1, config).messages.len == 0

echo "Testing phase-labeled press and duplicate message identifiers"
block:
  let config = defaultBudgetConfig()
  var messages = %*[
    {
      "id": 1, "fromCountryID": 2, "toCountryID": 1,
      "turn": 2, "phase": "Diplomacy", "message": "Support Belgium"
    },
    {
      "id": 2, "fromCountryID": 2, "toCountryID": 1,
      "turn": "3", "phase": "Diplomacy", "message": "Support Belgium"
    }
  ]
  let first = trimPress(messages, 1, config)
  doAssert first.messages.len == 2
  doAssert first.messages[0]["turn"].getInt() == 2
  doAssert first.messages[1]["turn"].getInt() == 3
  doAssert first.messages[1]["phase"].getStr() == "Diplomacy"
  messages.add %*{
    "id": 3, "fromCountryID": 2, "toCountryID": 1,
    "turn": 3, "phase": "Diplomacy", "message": "Support Belgium"
  }
  let repeated = trimPress(messages, 1, config)
  doAssert repeated.messages.len == 2
  doAssert repeated.signature == first.signature
  let unknown = trimPress(%*[
    {"fromCountryID": 2, "toCountryID": 1, "message": "Unlabeled offer"}
  ], 1, config)
  doAssert unknown.messages[0]{"turn"}.isNil
  doAssert unknown.messages[0]{"phase"}.isNil

echo "Budget tests passed"
