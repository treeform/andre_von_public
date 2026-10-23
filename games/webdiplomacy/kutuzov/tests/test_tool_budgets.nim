import
  ../[budgets, engines, requests]

const
  Sol = "openai/gpt-6.1-sol"
  Luna = "openai/gpt-6-luna"

proc near(actual, expected: float) {.raises: [].} =
  ## Compare accounting values without exact binary-fraction assumptions.
  doAssert abs(actual - expected) < 0.000000001

proc request(): RequestConfig {.raises: [].} =
  ## Build an offline request descriptor without an endpoint or credential.
  RequestConfig(
    api: ChatApi,
    model: Sol,
    reasoningEffort: "low",
    maxOutputTokens: 3000
  )

proc limits(): BudgetConfig {.raises: [].} =
  ## Use the hosted empirical cap with the intended tool request ceilings.
  result = defaultBudgetConfig()
  result.mode = EmpiricalBudget
  result.toolLoop = true
  result.limitUsd = 0.50
  result.reserveUsd = 0.10
  result.maxPhaseCalls = 12
  result.maxPressCalls = 1

proc observed(spent: float): Budget {.raises: [].} =
  ## Supply settled prices independently from the remaining real balance.
  result = Budget(mode: EmpiricalBudget, spentUsd: spent)
  result.modelCosts[0] = ModelCost(
    observed: 2, meanUsd: 0.01, largestUsd: 0.015
  )
  result.modelCosts[1] = ModelCost(
    observed: 2, meanUsd: 0.001, largestUsd: 0.001
  )

echo "Testing required fallback and optional tool continuation"
block:
  let
    config = request()
    ceiling = limits()
  var budget = observed(0.358)
  ceiling.validate()
  let required = chooseCall(
    config,
    budget,
    ceiling,
    "fixture rules",
    "{}",
    economyModel = Luna,
    reviewModel = Sol,
    phaseAllowanceUsd = 0.10,
    protectInitialReview = true
  )
  doAssert required.allowed and required.fallback
  doAssert required.reviewProtectionUnavailable
  doAssert required.config.model == Luna
  near(required.reservedUsd, 0.003)
  doAssert budget.reserve(ceiling, required.reservedUsd)
  budget.settleKnown(Luna, required.reservedUsd, 0.001)
  near(budget.budgetSpent(), 0.359)
  let optional = chooseCall(
    config,
    budget,
    ceiling,
    "fixture rules",
    "{}",
    economyModel = Luna,
    reviewModel = Sol,
    phaseSpentUsd = 0.001,
    phaseAllowanceUsd = 0.10,
    optionalCall = true
  )
  doAssert not optional.allowed
  let review = chooseCall(
    config,
    budget,
    ceiling,
    "fixture rules",
    "{}",
    economyModel = Luna,
    phaseSpentUsd = 0.001,
    phaseAllowanceUsd = 0.10
  )
  doAssert review.allowed and not review.fallback
  doAssert review.config.model == Sol
  near(budget.budgetSpent(), 0.359)
  near(budget.reservedUsd, 0.0)

echo "Testing opening Luna steps protect the actual Sol reviewer"
block:
  var budget = observed(0.355)
  budget.authoritativeSpentUsd = 0.355
  budget.uncertainUsd = 0.003
  budget.uncertainCalls = 1
  let
    ceiling = limits()
    opening = phaseModel(request(), Luna, EmpiricalBudget, "plan", false, 1901)
    wrongReviewer = chooseCall(
      opening,
      budget,
      ceiling,
      "fixture rules",
      "{}",
      reviewModel = Luna,
      phaseAllowanceUsd = 0.10,
      optionalCall = true
    )
    correctReviewer = chooseCall(
      opening,
      budget,
      ceiling,
      "fixture rules",
      "{}",
      reviewModel = Sol,
      phaseAllowanceUsd = 0.10,
      optionalCall = true
    )
    affordable = chooseCall(
      opening,
      observed(0.350),
      ceiling,
      "fixture rules",
      "{}",
      reviewModel = Sol,
      phaseAllowanceUsd = 0.10,
      optionalCall = true
    )
  doAssert opening.model == Luna
  doAssert wrongReviewer.allowed
  doAssert not correctReviewer.allowed
  doAssert affordable.allowed and affordable.config.model == Luna
  near(correctReviewer.allowanceUsd, 0.042)
  near(budget.empiricalCost(Sol), 0.04)
  near(budget.spentUsd, 0.355)
  near(budget.uncertainUsd, 0.003)
  near(budget.reservedUsd, 0.0)

echo "Testing soft pacing defers optional steps without a cheap downgrade"
block:
  let
    budget = observed(0.10)
    ceiling = limits()
    optional = chooseCall(
      request(),
      budget,
      ceiling,
      "fixture rules",
      "{}",
      economyModel = Luna,
      reviewModel = Sol,
      phaseSpentUsd = 0.010,
      phaseAllowanceUsd = 0.029,
      optionalCall = true
    )
    core = chooseCall(
      request(),
      budget,
      ceiling,
      "fixture rules",
      "{}",
      economyModel = Luna,
      reviewModel = Sol,
      phaseSpentUsd = 0.030,
      phaseAllowanceUsd = 0.029,
      protectInitialReview = true
    )
  doAssert not optional.allowed
  doAssert core.allowed and core.fallback
  doAssert core.reviewProtectionUnavailable and core.config.model == Luna

echo "Testing tool failures retain uncertain billing and phase cost"
block:
  let ceiling = limits()
  var state = BotState(budget: observed(0.358))
  doAssert state.budget.reserve(ceiling, 0.003)
  state.settleCall(Luna, 0.003, 0.003, false)
  near(state.budget.budgetSpent(), 0.361)
  near(state.budget.uncertainUsd, 0.003)
  near(state.phase.costUsd, 0.003)
  doAssert state.budget.uncertainCalls == 1
  doAssert state.budget.modelCosts[1].observed == 2
  doAssert not state.budget.canSpend(ceiling, 0.04)
  state.budget.updateSpend(0.3591)
  near(state.budget.budgetSpent(), 0.3621)
  near(state.budget.uncertainUsd, 0.003)
  doAssert state.budget.reserve(ceiling, 0.003)
  state.settleCall(Luna, 0.003, 0.001, true)
  near(state.budget.budgetSpent(), 0.3631)
  near(state.budget.uncertainUsd, 0.003)
  near(state.phase.costUsd, 0.004)
  doAssert state.budget.modelCosts[1].observed == 3
  doAssert not state.budget.canSpend(ceiling, 0.04)

echo "Tool budget admission checks passed."
