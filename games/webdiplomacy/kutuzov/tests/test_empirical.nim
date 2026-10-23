import
  std/[json, os, strutils],
  ../[budgets, common, engines, protocols, requests]

proc near(actual, expected: float) =
  ## Compare monetary values without depending on binary decimal equality.
  doAssert abs(actual - expected) < 0.000000001

proc settings(): BudgetConfig =
  ## Use the trial's half-dollar cap and explicit empirical opt-in.
  result = defaultBudgetConfig()
  result.mode = EmpiricalBudget
  result.limitUsd = 0.50
  result.reserveUsd = 0.10

proc request(): RequestConfig =
  ## Keep the production Sol model and maximum output allowance.
  RequestConfig(
    api: ChatApi,
    model: DefaultHostedModel,
    reasoningEffort: "low",
    maxOutputTokens: 3000
  )

echo "Testing expected phase pacing separately from call reservation"
block:
  let
    limits = settings()
    model = request()
    budget = Budget(mode: EmpiricalBudget)
    input = $ %*{"full_board": repeat("B", 40_000)}
    review = chooseCall(
      model, budget, limits, "rules", input,
      phaseSpentUsd = 0.0015,
      phaseAllowanceUsd = 0.025
    )
    update = chooseCall(
      model, budget, limits, "rules", input,
      reviewModel = model.model,
      phaseSpentUsd = 0.0015,
      phaseAllowanceUsd = 0.025,
      optionalCall = true
    )
  doAssert review.allowed and not review.fallback
  near(review.reservedUsd, 0.04)
  doAssert review.reservedUsd > 0.025
  doAssert not update.allowed
  doAssert update.config.model == model.model
  doAssert review.requestBytes > 40_000
  let tight = chooseCall(
    model, budget, limits, "rules", input,
    reviewModel = model.model,
    phaseSpentUsd = 0.005,
    phaseAllowanceUsd = 0.025,
    optionalCall = true
  )
  doAssert not tight.allowed, "Optional updates cannot downgrade to Luna"

echo "Testing front-loaded spending reduces optional Sol work"
block:
  let
    limits = settings()
    model = request()
    budget = Budget(mode: EmpiricalBudget, spentUsd: 0.30)
    phaseAllowance = budget.movementAllowance(limits, 4, 1908)
    early = chooseCall(
      model, budget, limits, "rules", "{}",
      phaseAllowanceUsd = phaseAllowance
    )
    late = chooseCall(
      model, budget, limits, "rules", "{}",
      phaseAllowanceUsd = budget.movementAllowance(limits, 13, 1908)
    )
  near(phaseAllowance, 0.01)
  doAssert early.allowed and early.fallback
  doAssert late.allowed and not late.fallback

echo "Testing optional calls cannot consume the last affordable Sol review"
block:
  let
    limits = settings()
    model = request()
    budget = Budget(mode: EmpiricalBudget, spentUsd: 0.358)
    update = chooseCall(
      model, budget, limits, "rules", "{}",
      reviewModel = model.model,
      phaseAllowanceUsd = 0.10,
      optionalCall = true
    )
    review = chooseCall(
      model, budget, limits, "rules", "{}",
      phaseAllowanceUsd = 0.10
    )
    press = PressContext(
      messages: %*[{"fromCountryID": 2, "message": "New offer"}],
      signature: "new"
    )
  doAssert not update.allowed
  doAssert review.allowed and not review.fallback
  var phase = PhaseState(
    savedOrders: %*[{"type": "Hold"}],
    calls: 1,
    updatesStopped: true
  )
  doAssert phase.nextTask("Diplomacy", press, limits, 100, 45, 1000) == "wait"
  doAssert phase.nextTask("Diplomacy", press, limits, 60, 45, 1040) == "review"
  phase.reviewed = true
  phase.updatesStopped = false
  phase.calls = 2
  doAssert phase.nextTask("Diplomacy", press, limits, 80, 45, 1040) == "update"
  let afterReview = chooseCall(
    model, Budget(mode: EmpiricalBudget), limits, "rules", "{}",
    phaseSpentUsd = 0.005,
    phaseAllowanceUsd = 0.010,
    optionalCall = true
  )
  doAssert not afterReview.allowed, "Post-review updates cannot downgrade"
  let
    required = chooseCall(
      model, Budget(mode: EmpiricalBudget, spentUsd: 0.38),
      limits, "rules", "{}", phaseAllowanceUsd = 0.10
    )
    optional = chooseCall(
      model, Budget(mode: EmpiricalBudget, spentUsd: 0.38),
      limits, "rules", "{}", phaseAllowanceUsd = 0.10,
      optionalCall = true
    )
    conservative = chooseCall(
      model, Budget(spentUsd: 0.38),
      BudgetConfig(mode: ConservativeBudget, limitUsd: 0.50,
        reserveUsd: 0.10, maxContextBytes: 60_000),
      "rules", "{}", optionalCall = true
    )
  doAssert required.allowed and required.fallback
  doAssert required.config.model == "openai/gpt-6-luna"
  doAssert not optional.allowed
  doAssert conservative.allowed and conservative.fallback

echo "Testing initial primary plans protect both review admission terms"
block:
  let
    limits = settings()
    model = request()
    budget = Budget(mode: EmpiricalBudget)
    protected = chooseCall(
      model, budget, limits, "rules", "{}",
      reviewModel = model.model,
      phaseAllowanceUsd = 0.05,
      protectInitialReview = true
    )
    expectedTight = chooseCall(
      model, budget, limits, "rules", "{}",
      reviewModel = model.model,
      phaseAllowanceUsd = 0.03,
      protectInitialReview = true
    )
    reserveTight = chooseCall(
      model, Budget(mode: EmpiricalBudget, spentUsd: 0.34),
      limits, "rules", "{}",
      reviewModel = model.model,
      phaseAllowanceUsd = 0.10,
      protectInitialReview = true
    )
  doAssert protected.allowed and not protected.fallback
  doAssert protected.config.model == model.model
  doAssert not protected.reviewProtectionUnavailable
  near(protected.reservedUsd, 0.04)
  for fallback in [expectedTight, reserveTight]:
    doAssert fallback.allowed and fallback.fallback
    doAssert fallback.config.model == "openai/gpt-6-luna"
    doAssert fallback.reviewProtectionUnavailable
  var nearlySpent = Budget(mode: EmpiricalBudget, spentUsd: 0.395)
  nearlySpent.modelCosts[0] = ModelCost(
    largestUsd: 0.03, meanUsd: 0.03, observed: 1
  )
  let onlyLuna = chooseCall(
    model, nearlySpent, limits, "rules", "{}",
    reviewModel = model.model,
    phaseSpentUsd = 0.026,
    phaseAllowanceUsd = 0.025,
    protectInitialReview = true
  )
  doAssert onlyLuna.allowed and onlyLuna.fallback
  doAssert onlyLuna.reviewProtectionUnavailable
  doAssert onlyLuna.config.model == "openai/gpt-6-luna"
  near(onlyLuna.reservedUsd, 0.003)
  doAssert nearlySpent.canSpend(limits, onlyLuna.reservedUsd)

echo "Testing movement years and unchanged conservative adjustment routing"
block:
  let model = request()
  for finalYear in [false, true]:
    doAssert phaseModel(
      model, "gpt-6-luna", EmpiricalBudget, "plan", finalYear, 1901,
      "Diplomacy"
    ).model == "openai/gpt-6-luna"
    for year in [1902, 1908]:
      doAssert phaseModel(
        model, "gpt-6-luna", EmpiricalBudget, "plan", finalYear, year,
        "Diplomacy"
      ).model == model.model
    for phase in ["Retreats", "Builds"]:
      for mode in [ConservativeBudget, EmpiricalBudget]:
        doAssert phaseModel(
          model, "gpt-6-luna", mode, "plan", finalYear, 1902, phase
        ).model == (if finalYear: model.model else: "openai/gpt-6-luna")
    doAssert phaseModel(
      model, "gpt-6-luna", ConservativeBudget, "plan", finalYear, 1902,
      "Diplomacy"
    ).model == (if finalYear: model.model else: "openai/gpt-6-luna")
    for task in ["update", "review", "repair"]:
      doAssert phaseModel(
        model, "gpt-6-luna", EmpiricalBudget, task, finalYear, 1902,
        "Diplomacy"
      ).model == model.model

echo "Testing final-spring required fallback preserves the available review"
block:
  let
    limits = settings()
    model = request()
    preferred = phaseModel(
      model, "gpt-6-luna", EmpiricalBudget, "plan", true, 1908,
      "Diplomacy"
    )
  var state = BotState(budget: Budget(mode: EmpiricalBudget, spentUsd: 0.40))
  let
    allowance = state.budget.movementAllowance(limits, 14, 1908)
    plan = chooseCall(
      preferred, state.budget, limits, "rules", "{}", true, 2,
      reviewModel = model.model,
      phaseAllowanceUsd = allowance,
      protectInitialReview = true
    )
  near(allowance, 0.025)
  doAssert plan.allowed and plan.fallback
  doAssert plan.config.model == "openai/gpt-6-luna"
  doAssert state.budget.reserve(limits, plan.reservedUsd, true)
  state.settleCall(plan.config.model, plan.reservedUsd, 0.001, true)
  let
    update = chooseCall(
      model, state.budget, limits, "rules", "{}", true, 2,
      reviewModel = model.model,
      phaseSpentUsd = state.phase.costUsd,
      phaseAllowanceUsd = allowance,
      optionalCall = true
    )
    review = chooseCall(
      model, state.budget, limits, "rules", "{}", true, 2,
      phaseSpentUsd = state.phase.costUsd,
      phaseAllowanceUsd = allowance
    )
  doAssert not update.allowed
  doAssert review.allowed and not review.fallback
  near(state.phase.costUsd, 0.001)
  doAssert review.reservedUsd > allowance

echo "Testing failed-call estimates, live meters and restart"
block:
  let
    limits = settings()
    model = request()
    game = GameConfig(gameId: 9201, countryId: 2, endYear: 1908)
    path = getTempDir() / "kutuzov-empirical-fixture-state.json"
  var state = BotState(
    gameId: game.gameId,
    countryId: game.countryId,
    budget: Budget(mode: EmpiricalBudget),
    phase: PhaseState(stamp: "13:Diplomacy")
  )
  defer:
    if fileExists(path):
      removeFile(path)
  state.budget.updateSpend(0.22558241)
  for name in [model.model, "gpt-6-luna", "gpt-6-luna", "gpt-6-luna"]:
    let estimate = state.budget.empiricalCost(name)
    doAssert state.budget.reserve(limits, estimate)
    state.settleCall(name, estimate, estimate, false)
  near(state.budget.uncertainUsd, 0.049)
  doAssert state.budget.uncertainCalls == 4
  state.budget.updateSpend(0.22558241)
  state.persist(path)
  state = restore(game, path, EmpiricalBudget)
  near(state.budget.uncertainUsd, 0.049)
  near(state.budget.budgetSpent, 0.27458241)
  let review = chooseCall(
    model, state.budget, limits, "rules", "{}",
    phaseSpentUsd = state.phase.costUsd,
    phaseAllowanceUsd = state.budget.movementAllowance(limits, 13, 1908)
  )
  doAssert review.allowed and not review.fallback
  state.budget.updateSpend(0.24)
  near(state.budget.budgetSpent, 0.289)
  near(state.budget.uncertainUsd, 0.049)
  doAssert state.budget.reserve(limits, 0.04)
  state.persist(path)
  state = restore(game, path, EmpiricalBudget)
  near(state.budget.uncertainUsd, 0.089)
  near(state.budget.reservedUsd, 0.0)
  doAssert state.budget.uncertainCalls == 5
  state.persist(path)
  state = restore(game, path, EmpiricalBudget)
  near(state.budget.uncertainUsd, 0.089)
  doAssert state.budget.uncertainCalls == 5
  var rejected = false
  try:
    discard restore(game, path, ConservativeBudget)
  except KutuzovError:
    rejected = true
  doAssert rejected

echo "Testing known call history and bounded request size"
block:
  let
    limits = settings()
    model = request()
  var state = BotState(budget: Budget(mode: EmpiricalBudget))
  doAssert state.budget.reserve(limits, 0.04)
  state.settleCall(model.model, 0.04, 0.012, true)
  near(state.budget.expectedCost(model.model), 0.012)
  near(state.phase.costUsd, 0.012)
  near(state.budget.uncertainUsd, 0.0)
  var oversizedOutput = model
  oversizedOutput.maxOutputTokens = 5000
  let
    capped = chooseCall(
      oversizedOutput, state.budget, limits, "rules", "{}"
    )
    oversized = chooseCall(
      model, state.budget, limits, "rules", repeat("B", 60_000)
    )
  doAssert capped.allowed
  doAssert capped.config.maxOutputTokens == 3000
  doAssert not oversized.allowed

echo "Testing one known Sol sample changes pacing without changing charges"
block:
  let limits = settings()
  var budget = Budget(mode: EmpiricalBudget)
  near(budget.expectedCost("gpt-6.1-sol"), SolPriorUsd)
  near(budget.expectedCost("gpt-6-luna"), LunaPriorUsd)
  for cost in [0.0, 0.01, 0.02, 0.032236, 0.07]:
    budget.modelCosts[0] = ModelCost(
      largestUsd: cost, meanUsd: cost, observed: 1
    )
    let before = budget
    for model in ["gpt-6.1-sol", "openai/gpt-6.1-sol"]:
      near(budget.expectedCost(model), min(cost, SolPriorUsd))
      near(budget.empiricalCost(model), 2.0 * max(cost, SolPriorUsd))
    doAssert budget == before
  for count in [2, 3, 100]:
    budget.modelCosts[0] = ModelCost(
      largestUsd: 0.07, meanUsd: 0.035, observed: count
    )
    near(budget.expectedCost("gpt-6.1-sol"), 0.035)
  budget.modelCosts[1] = ModelCost(
    largestUsd: 0.006, meanUsd: 0.006, observed: 1
  )
  for model in ["gpt-6-luna", "openai/gpt-6-luna"]:
    near(budget.expectedCost(model), 0.006)
  var settled = Budget(mode: EmpiricalBudget)
  doAssert settled.reserve(limits, 0.04)
  settled.settleKnown("gpt-6.1-sol", 0.04, 0.06)
  near(settled.spentUsd, 0.06)
  near(settled.modelCosts[0].meanUsd, 0.06)
  near(settled.expectedCost("gpt-6.1-sol"), SolPriorUsd)
  doAssert settled.reserve(limits, 0.12)
  settled.settleKnown("gpt-6.1-sol", 0.12, 0.01)
  doAssert settled.modelCosts[0].observed == 2
  near(settled.modelCosts[0].largestUsd, 0.06)
  near(settled.expectedCost("gpt-6.1-sol"), 0.035)
  near(settled.budgetSpent, 0.07)
  near(settled.empiricalCost("gpt-6.1-sol"), 0.12)

echo "Testing only empirical final autumn lowers the stopping floor"
block:
  let
    limits = settings()
    budget = Budget(mode: EmpiricalBudget, spentUsd: 0.30)
  near(budget.stoppingReserve(limits), 0.10)
  near(budget.stoppingReserve(limits, false, true), 0.10)
  near(budget.stoppingReserve(limits, true), 0.05)
  near(budget.stoppingReserve(limits, true, false), 0.05)
  near(budget.stoppingReserve(limits, true, true), 2.0 * SolPriorUsd)
  near(budget.movementAllowance(limits, 13, 1908), 0.10)
  near(budget.movementAllowance(limits, 14, 1908), 0.075)
  near(budget.movementAllowance(limits, 15, 1908), 0.16)
  var lowReserve = limits
  lowReserve.reserveUsd = 0.01
  near(budget.stoppingReserve(lowReserve, false, true), 0.05)
  var conservative = limits
  conservative.mode = ConservativeBudget
  for finalAutumn in [false, true]:
    near(budget.stoppingReserve(conservative, false, finalAutumn), 0.10)
    near(budget.stoppingReserve(conservative, true, finalAutumn), 0.0)
    doAssert budget.canSpend(conservative, 0.19, true, finalAutumn)
  near(budget.movementAllowance(conservative, 14, 1908), 0.10)
  near(budget.movementAllowance(conservative, 15, 1908), 0.20)

echo "Testing large calls and unknown charges survive both budget changes"
block:
  let
    limits = settings()
    expensiveCall = estimateCost("gpt-6.1-sol", 20_000, 3_000)
  near(expensiveCall, 0.07)
  var budget = Budget(mode: EmpiricalBudget)
  doAssert budget.reserve(limits, 0.04)
  budget.settleKnown("gpt-6.1-sol", 0.04, expensiveCall)
  near(budget.spentUsd, 0.07)
  near(budget.modelCosts[0].meanUsd, 0.07)
  near(budget.modelCosts[0].largestUsd, 0.07)
  near(budget.expectedCost("gpt-6.1-sol"), SolPriorUsd)
  near(budget.stoppingReserve(limits, true, true), 0.14)
  doAssert budget.reserve(limits, 0.14, true, true)
  budget.settleUnknown(0.14)
  near(budget.uncertainUsd, 0.14)
  doAssert budget.uncertainCalls == 1
  doAssert budget.modelCosts[0].observed == 1
  budget.updateSpend(0.11)
  budget.updateSpend(0.09)
  near(budget.authoritativeSpentUsd, 0.11)
  near(budget.spentUsd, 0.11)
  near(budget.budgetSpent, 0.25)
  near(budget.uncertainUsd, 0.14)
  near(budget.modelCosts[0].meanUsd, 0.07)
  near(budget.stoppingReserve(limits, true, true), 0.14)
  budget.modelCosts[1] = ModelCost(
    largestUsd: 0.09, meanUsd: 0.09, observed: 1
  )
  near(budget.expectedCost("gpt-6-luna"), 0.09)
  near(budget.stoppingReserve(limits, true, true), 0.18)
  doAssert not budget.canSpend(limits, 0.08, true, true)
  var unknown = Budget(mode: EmpiricalBudget)
  doAssert unknown.reserve(limits, 0.04, true, true)
  unknown.settleUnknown(0.04)
  doAssert unknown.modelCosts[0].observed == 0
  near(unknown.expectedCost("gpt-6.1-sol"), SolPriorUsd)
  near(unknown.budgetSpent, 0.04)

echo "Testing the recorded Italy final-autumn repair admission boundary"
block:
  let limits = settings()
  var budget = Budget(
    mode: EmpiricalBudget,
    spentUsd: 0.41140056,
    authoritativeSpentUsd: 0.41140016,
    modelCosts: [
      ModelCost(
        observed: 31,
        meanUsd: 0.01595036474280609,
        largestUsd: 0.0193835
      ),
      ModelCost(
        observed: 9,
        meanUsd: 0.00081569880859375,
        largestUsd: 0.0011018
      )
    ]
  )
  let
    before = budget
    reserveUsd = budget.empiricalCost("gpt-6.1-sol")
  near(reserveUsd, 0.04)
  near(budget.movementAllowance(limits, 15, 1908), 0.04859944)
  doAssert not budget.canSpend(limits, reserveUsd, true, false)
  doAssert not budget.canSpend(limits, reserveUsd, false, true)
  doAssert budget.canSpend(limits, reserveUsd, true, true)
  doAssert not budget.canSpend(limits, 0.09, true, true)
  doAssert not budget.reserve(limits, reserveUsd, true, false)
  doAssert budget == before
  doAssert budget.reserve(limits, reserveUsd, true, true)
  near(budget.spentUsd, before.spentUsd)
  near(budget.authoritativeSpentUsd, before.authoritativeSpentUsd)
  near(budget.reservedUsd, 0.04)
  near(budget.budgetSpent, 0.45140056)
  doAssert not budget.reserve(limits, 0.01, true, true)
  near(budget.reservedUsd, 0.04)
  budget.settleUnknown(reserveUsd)
  near(budget.uncertainUsd, 0.04)
  near(budget.budgetSpent, 0.45140056)
  budget.updateSpend(0.40)
  near(budget.budgetSpent, 0.45140056)
  budget.updateSpend(0.43)
  near(budget.budgetSpent, 0.47)
  near(budget.uncertainUsd, 0.04)
  doAssert not budget.canSpend(limits, 0.001, true, true)

echo "Testing final-autumn model selection preserves the full Sol reservation"
block:
  let
    limits = settings()
    model = request()
    budget = Budget(
      mode: EmpiricalBudget,
      spentUsd: 0.41140056,
      authoritativeSpentUsd: 0.41140016,
      modelCosts: [
        ModelCost(
          observed: 31,
          meanUsd: 0.01595036474280609,
          largestUsd: 0.0193835
        ),
        ModelCost(
          observed: 9,
          meanUsd: 0.00081569880859375,
          largestUsd: 0.0011018
        )
      ]
    )
    oldFloor = chooseCall(
      model,
      budget,
      limits,
      "rules",
      "{}",
      finalYear = true,
      phaseSpentUsd = 0.020356425,
      phaseAllowanceUsd = 0.058955865
    )
    finalAutumn = chooseCall(
      model,
      budget,
      limits,
      "rules",
      "{}",
      finalYear = true,
      phaseSpentUsd = 0.020356425,
      phaseAllowanceUsd = 0.058955865,
      finalAutumn = true
    )
  doAssert oldFloor.allowed and oldFloor.fallback
  doAssert oldFloor.config.model == "openai/gpt-6-luna"
  doAssert finalAutumn.allowed and not finalAutumn.fallback
  doAssert finalAutumn.config.model == "openai/gpt-6.1-sol"
  near(finalAutumn.reservedUsd, 0.04)
  near(finalAutumn.allowanceUsd, 0.04859944)
  var initialBudget = budget
  initialBudget.spentUsd = 0.391044135
  initialBudget.authoritativeSpentUsd = 0.391043735
  let initial = chooseCall(
    model,
    initialBudget,
    limits,
    "rules",
    "{}",
    finalYear = true,
    reviewModel = model.model,
    phaseAllowanceUsd = 0.068955865,
    protectInitialReview = true,
    finalAutumn = true
  )
  doAssert initial.allowed and initial.fallback
  doAssert initial.reviewProtectionUnavailable
  doAssert initial.config.model == "openai/gpt-6-luna"
  near(initial.reservedUsd, 0.003)

echo "Empirical engine tests passed"
