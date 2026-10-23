import
  std/[algorithm, json, math, os, sha1, strutils],
  common

const
  MaximumSpend = 2.0
  MaximumInputTokens = 272_000
  MaximumPressScan = 512
  # These cold priors are empirical assumptions, not maximum request costs.
  SolPriorUsd* = 0.02
  LunaPriorUsd* = 0.0015
  SolWarmPriorUsd* = 0.010
  EmpiricalReserveUsd* = 0.05

type
  BudgetMode* = enum
    ConservativeBudget, EmpiricalBudget

  PacingContext* = enum
    OrdinaryRequest, WarmSolContinuation

  BudgetConfig* = object
    mode*: BudgetMode
    toolLoop*: bool
    limitUsd*: float
    reserveUsd*: float
    pressModel*: string
    maxPhaseCalls*: int
    maxPressCalls*: int
    maxPressCharacters*: int
    maxOpponentCharacters*: int
    maxMessageCharacters*: int
    maxMessagesPerOpponent*: int
    maxContextBytes*: int

  ModelRates* = object
    inputUsd*: float
    cachedUsd*: float
    cacheWriteUsd*: float
    outputUsd*: float

  ModelCost* = object
    largestUsd*: float
    meanUsd*: float
    observed*: int

  Budget* = object
    mode*: BudgetMode
    uncertainUsd*: float
    uncertainCalls*: int
    modelCosts*: array[2, ModelCost]
    warmSolCost*: ModelCost
    spentUsd*: float
    authoritativeSpentUsd*: float
    reservedUsd*: float

  PressContext* = object
    messages*: JsonNode
    omitted*: int
    signature*: string

proc nonnegative(value: float): bool {.raises: [].} =
  ## Checks that a monetary value is finite and nonnegative.
  value >= 0.0 and classify(value) notin {fcNan, fcInf, fcNegInf}

proc modelRates*(model: string): ModelRates {.raises: [KutuzovError].} =
  ## Returns verified per-million-token rates for an exact model name.
  case model
  of "gpt-6.1-sol", "openai/gpt-6.1-sol":
    ModelRates(
      inputUsd: 2.0,
      cachedUsd: 0.10,
      cacheWriteUsd: 2.5,
      outputUsd: 10.0
    )
  of "gpt-6-luna", "openai/gpt-6-luna":
    ModelRates(
      inputUsd: 0.10,
      cachedUsd: 0.01,
      cacheWriteUsd: 0.125,
      outputUsd: 0.50
    )
  else:
    raise newException(KutuzovError, "Unknown model pricing: " & model)

proc defaultBudgetConfig*(): BudgetConfig {.raises: [].} =
  ## Returns a capped budget with money reserved for the final year.
  BudgetConfig(
    mode: ConservativeBudget,
    toolLoop: false,
    limitUsd: 1.85,
    reserveUsd: 0.30,
    maxPhaseCalls: 4,
    maxPressCalls: 2,
    maxPressCharacters: 5_000,
    maxOpponentCharacters: 800,
    maxMessageCharacters: 400,
    maxMessagesPerOpponent: 2,
    maxContextBytes: 60_000
  )

proc validate*(config: BudgetConfig) {.raises: [KutuzovError].} =
  ## Rejects unsafe budgets and unbounded context settings.
  if not nonnegative(config.limitUsd) or
    config.limitUsd > MaximumSpend or
    not nonnegative(config.reserveUsd) or
    config.reserveUsd > config.limitUsd:
      raise newException(
        KutuzovError,
        "Budget must satisfy 0 <= reserve <= limit <= 2"
      )
  if config.maxPhaseCalls < 1 or config.maxPhaseCalls > 32 or
    config.maxPressCalls < 0 or
    config.maxPressCalls > config.maxPhaseCalls:
      raise newException(KutuzovError, "Invalid per-phase model call limits")
  if config.toolLoop and
    (config.maxPhaseCalls > 12 or config.maxPressCalls > 1):
      raise newException(
        KutuzovError,
        "Tool-loop budgets allow at most twelve calls and one press wake"
      )
  if not config.toolLoop and config.mode == EmpiricalBudget and
    (config.maxPhaseCalls > 4 or config.maxPressCalls > 2):
      raise newException(
        KutuzovError,
        "Empirical budgets allow at most four phase calls and two press calls"
      )
  if config.maxContextBytes < 1 or config.maxContextBytes > 200_000 or
    config.maxPressCharacters < 0 or config.maxPressCharacters > 45_000 or
    config.maxOpponentCharacters < 0 or
    config.maxOpponentCharacters > 45_000 or
    config.maxMessageCharacters < 0 or config.maxMessageCharacters > 45_000 or
    config.maxMessagesPerOpponent < 0 or config.maxMessagesPerOpponent > 32:
      raise newException(KutuzovError, "Invalid bounded context limits")
  if config.pressModel.len > 0:
    discard modelRates(config.pressModel)

proc envFloat(name: string, fallback: float): float
    {.raises: [KutuzovError].} =
  ## Reads a finite nonnegative floating-point setting.
  let value = getEnv(name)
  if value.len == 0:
    return fallback
  try:
    result = parseFloat(value)
  except ValueError:
    raise newException(KutuzovError, "Invalid number in " & name)
  if not nonnegative(result):
    raise newException(KutuzovError, "Invalid nonnegative number in " & name)

proc envInt(name: string, fallback: int): int {.raises: [KutuzovError].} =
  ## Reads an integer setting and maps parse failures to KutuzovError.
  let value = getEnv(name)
  if value.len == 0:
    return fallback
  try:
    result = parseInt(value)
  except ValueError:
    raise newException(KutuzovError, "Invalid integer in " & name)

proc envBool(name: string, fallback: bool): bool {.raises: [KutuzovError].} =
  ## Read an explicit boolean setting without accepting misspelled values.
  case getEnv(name)
  of "":
    fallback
  of "true", "1":
    true
  of "false", "0":
    false
  else:
    raise newException(KutuzovError, "Invalid boolean in " & name)

proc loadBudgetConfig*(): BudgetConfig {.raises: [KutuzovError].} =
  ## Loads and validates optional KUTUZOV budget environment settings.
  result = defaultBudgetConfig()
  case getEnv("KUTUZOV_BUDGET_MODE")
  of "", "conservative":
    result.mode = ConservativeBudget
  of "empirical":
    result.mode = EmpiricalBudget
  else:
    raise newException(KutuzovError, "Unknown KUTUZOV_BUDGET_MODE")
  result.toolLoop = envBool("KUTUZOV_TOOL_LOOP", false)
  if result.toolLoop:
    result.maxPhaseCalls = 12
    result.maxPressCalls = 1
  result.limitUsd = envFloat("KUTUZOV_BUDGET_USD", result.limitUsd)
  result.reserveUsd = envFloat("KUTUZOV_RESERVE_USD", result.reserveUsd)
  result.pressModel = getEnv("KUTUZOV_PRESS_MODEL")
  result.maxPhaseCalls = envInt("KUTUZOV_MAX_PHASE_CALLS", result.maxPhaseCalls)
  result.maxPressCalls = envInt("KUTUZOV_MAX_PRESS_CALLS", result.maxPressCalls)
  result.maxPressCharacters = envInt(
    "KUTUZOV_MAX_PRESS_CHARACTERS",
    result.maxPressCharacters
  )
  result.maxOpponentCharacters = envInt(
    "KUTUZOV_MAX_OPPONENT_CHARACTERS",
    result.maxOpponentCharacters
  )
  result.maxMessageCharacters = envInt(
    "KUTUZOV_MAX_MESSAGE_CHARACTERS",
    result.maxMessageCharacters
  )
  result.maxMessagesPerOpponent = envInt(
    "KUTUZOV_MAX_MESSAGES_PER_OPPONENT",
    result.maxMessagesPerOpponent
  )
  result.maxContextBytes = envInt(
    "KUTUZOV_MAX_CONTEXT_BYTES",
    result.maxContextBytes
  )
  validate(result)

proc estimateCost*(
  rates: ModelRates,
  inputTokens: int,
  outputTokens: int,
  cachedTokens = 0,
  cacheWriteTokens = 0
): float {.raises: [KutuzovError].} =
  ## Prices total input tokens, including any cached or newly cached subset.
  if inputTokens < 0 or outputTokens < 0 or
    cachedTokens < 0 or cacheWriteTokens < 0 or
    cachedTokens > inputTokens or
    cacheWriteTokens > inputTokens - cachedTokens or
    inputTokens >= MaximumInputTokens:
      raise newException(KutuzovError, "Invalid token counts for cost estimate")
  if not nonnegative(rates.inputUsd) or not nonnegative(rates.cachedUsd) or
    not nonnegative(rates.cacheWriteUsd) or not nonnegative(rates.outputUsd):
      raise newException(
        KutuzovError,
        "Model rates must be finite and nonnegative"
      )
  let freshTokens = inputTokens - cachedTokens - cacheWriteTokens
  result = (
    freshTokens.float * rates.inputUsd +
    cachedTokens.float * rates.cachedUsd +
    cacheWriteTokens.float * rates.cacheWriteUsd +
    outputTokens.float * rates.outputUsd
  ) / 1_000_000.0

proc estimateCost*(
  model: string,
  inputTokens: int,
  outputTokens: int,
  cachedTokens = 0,
  cacheWriteTokens = 0
): float {.raises: [KutuzovError].} =
  ## Prices a request using the verified rates for its exact model name.
  estimateCost(
    modelRates(model),
    inputTokens,
    outputTokens,
    cachedTokens,
    cacheWriteTokens
  )

proc reserveCost*(
  model: string,
  inputBytes: int,
  maxOutputTokens: int
): float {.raises: [KutuzovError].} =
  ## Reserves one input token per byte at the highest input rate.
  var rates = modelRates(model)
  rates.inputUsd = max(
    rates.inputUsd,
    max(rates.cachedUsd, rates.cacheWriteUsd)
  )
  estimateCost(rates, inputBytes, maxOutputTokens)

proc modelIndex(model: string): int {.raises: [KutuzovError].} =
  ## Maps supported provider names to the flat Sol and Luna cost records.
  case model
  of "gpt-6.1-sol", "openai/gpt-6.1-sol":
    0
  of "gpt-6-luna", "openai/gpt-6-luna":
    1
  else:
    raise newException(KutuzovError, "Unknown model cost history: " & model)

proc coldPrior(index: int): float {.raises: [].} =
  ## Returns the empirical starting estimate for a supported model index.
  if index == 0:
    SolPriorUsd
  else:
    LunaPriorUsd

proc validatePacing(index: int, context: PacingContext)
    {.raises: [KutuzovError].} =
  ## Restricts the warm continuation estimate to the supported Sol model.
  if context == WarmSolContinuation and index != 0:
    raise newException(
      KutuzovError,
      "Warm continuation pacing requires gpt-6.1-sol"
    )

proc expectedCost*(
  budget: Budget,
  model: string,
  context: PacingContext = OrdinaryRequest
): float {.raises: [KutuzovError].} =
  ## Uses a separate warm Sol estimate while preserving ordinary pacing.
  let index = modelIndex(model)
  validatePacing(index, context)
  if context == WarmSolContinuation:
    return
      if budget.warmSolCost.observed > 0:
        budget.warmSolCost.meanUsd
      else:
        SolWarmPriorUsd
  let
    history = budget.modelCosts[index]
  if index == 0 and history.observed == 1:
    min(history.meanUsd, SolPriorUsd)
  elif history.observed > 0:
    history.meanUsd
  else:
    coldPrior(index)

proc empiricalCost*(budget: Budget, model: string): float
    {.raises: [KutuzovError].} =
  ## Returns an empirical allowance that does not bound actual request cost.
  let index = modelIndex(model)
  2.0 * max(coldPrior(index), budget.modelCosts[index].largestUsd)

proc budgetSpent*(budget: Budget): float {.raises: [].} =
  ## Includes known spend, uncertain charges, and outstanding reservations.
  max(budget.spentUsd, budget.authoritativeSpentUsd) +
    budget.uncertainUsd + budget.reservedUsd

proc stoppingReserve*(
  budget: Budget,
  config: BudgetConfig,
  finalYear = false,
  finalAutumn = false
): float {.raises: [].} =
  ## Preserves the final-year fund and an empirical stopping cushion.
  result =
    if finalYear:
      0.0
    else:
      config.reserveUsd
  if config.mode == EmpiricalBudget:
    let floor =
      if finalYear and finalAutumn:
        2.0 * SolPriorUsd
      else:
        EmpiricalReserveUsd
    result = max(result, floor)
    for history in budget.modelCosts:
      result = max(result, 2.0 * history.largestUsd)

proc movementAllowance*(
  budget: Budget,
  config: BudgetConfig,
  turn: int,
  endYear: int
): float {.raises: [].} =
  ## Divides available funds across movement phases for soft call pacing.
  if turn < 0 or endYear < 1901:
    return 0.0
  let year = 1901 + turn div 2
  if year > endYear:
    return 0.0
  let
    finalYear = year == endYear
    finalAutumn = finalYear and turn mod 2 == 1
    remaining =
      if finalYear:
        2 - turn mod 2
      else:
        (endYear - year) * 2 - turn mod 2
    available = min(config.limitUsd, MaximumSpend) - budgetSpent(budget) -
      stoppingReserve(budget, config, finalYear, finalAutumn)
  max(0.0, available) / remaining.float

proc canSpend*(
  budget: Budget,
  config: BudgetConfig,
  cost: float,
  finalYear = false,
  finalAutumn = false
): bool {.raises: [].} =
  ## Preserves the final-year reserve until the final year is reached.
  if not nonnegative(cost) or not nonnegative(budget.spentUsd) or
    not nonnegative(budget.authoritativeSpentUsd) or
    not nonnegative(budget.reservedUsd) or
    not nonnegative(budget.uncertainUsd) or
    not nonnegative(config.limitUsd) or
    not nonnegative(config.reserveUsd) or
    config.reserveUsd > config.limitUsd:
      return false
  let ceiling = min(config.limitUsd, MaximumSpend) -
    stoppingReserve(budget, config, finalYear, finalAutumn)
  budgetSpent(budget) + cost <= ceiling

proc charge*(budget: var Budget, cost: float) {.raises: [KutuzovError].} =
  ## Charges a known or conservatively estimated completed request.
  if not nonnegative(cost):
    raise newException(
      KutuzovError,
      "Request cost must be finite and nonnegative"
    )
  budget.spentUsd = max(budget.spentUsd, budget.authoritativeSpentUsd) + cost

proc updateSpend*(budget: var Budget, authoritativeSpentUsd: float)
    {.raises: [KutuzovError].} =
  ## Applies a monotonic authoritative spend update without reducing estimates.
  if not nonnegative(authoritativeSpentUsd):
    raise newException(
      KutuzovError,
      "Reported spend must be finite and nonnegative"
    )
  budget.authoritativeSpentUsd = max(
    budget.authoritativeSpentUsd,
    authoritativeSpentUsd
  )
  budget.spentUsd = max(budget.spentUsd, budget.authoritativeSpentUsd)

proc reserve*(
  budget: var Budget,
  config: BudgetConfig,
  cost: float,
  finalYear = false,
  finalAutumn = false
): bool {.raises: [].} =
  ## Holds the selected cost allowance before dispatching a request.
  if not canSpend(budget, config, cost, finalYear, finalAutumn):
    return false
  budget.reservedUsd += cost
  true

proc settle*(budget: var Budget, reservedUsd: float, actualUsd: float)
    {.raises: [KutuzovError].} =
  ## Replaces a reservation with actual spend or its worst-case estimate.
  if not nonnegative(reservedUsd) or not nonnegative(actualUsd) or
    reservedUsd > budget.reservedUsd + 0.000000001:
      raise newException(KutuzovError, "Invalid request reservation settlement")
  budget.reservedUsd = max(0.0, budget.reservedUsd - reservedUsd)
  charge(budget, actualUsd)

proc observeCost(history: var ModelCost, actualUsd: float) {.raises: [].} =
  ## Records every known cost without discounting expensive cache misses.
  history.largestUsd = max(history.largestUsd, actualUsd)
  history.meanUsd =
    if history.observed == 0:
      actualUsd
    else:
      0.5 * history.meanUsd + 0.5 * actualUsd
  inc history.observed

proc settleKnown*(
  budget: var Budget,
  model: string,
  reservedUsd: float,
  actualUsd: float,
  context: PacingContext = OrdinaryRequest
) {.raises: [KutuzovError].} =
  ## Settles known costs and updates pooled and applicable warm histories.
  let index = modelIndex(model)
  validatePacing(index, context)
  settle(budget, reservedUsd, actualUsd)
  observeCost(budget.modelCosts[index], actualUsd)
  if context == WarmSolContinuation:
    observeCost(budget.warmSolCost, actualUsd)

proc settleUnknown*(budget: var Budget, reservedUsd: float)
    {.raises: [KutuzovError].} =
  ## Keeps an ambiguous call allowance separate from known empirical spend.
  if budget.mode == ConservativeBudget:
    settle(budget, reservedUsd, reservedUsd)
    return
  if not nonnegative(reservedUsd) or
    reservedUsd > budget.reservedUsd + 0.000000001:
      raise newException(KutuzovError, "Invalid unknown reservation settlement")
  budget.reservedUsd = max(0.0, budget.reservedUsd - reservedUsd)
  budget.uncertainUsd += reservedUsd
  inc budget.uncertainCalls

proc countryId(node: JsonNode): int {.raises: [].} =
  ## Accepts integer and decimal-string country identifiers.
  result = -1
  if node == nil:
    return
  case node.kind
  of JInt:
    if node.getBiggestInt >= 0 and node.getBiggestInt <= 7:
      result = node.getInt
  of JString:
    let value = node.getStr
    if value.len == 1 and value[0] in {'0' .. '7'}:
      result = ord(value[0]) - ord('0')
  else:
    discard

proc bytePrefix(value: string, limit: int): string {.raises: [].} =
  ## Truncates at a UTF-8 boundary within a conservative byte limit.
  if value.len <= limit:
    return value
  var length = max(0, limit)
  while length > 0 and (ord(value[length]) and 0xC0) == 0x80:
    dec length
  value[0 ..< length]

proc pressTurn(node: JsonNode): int {.raises: [].} =
  ## Return a bounded turn label, with unknown distinct from the first turn.
  result = -1
  if node.isNil:
    return
  if node.kind == JInt:
    let value = node.getBiggestInt()
    if value >= 0 and value <= 1_000_000:
      result = value.int
  elif node.kind == JString:
    let value = node.getStr()
    if value.len == 0 or value.len > 6:
      return
    result = 0
    for digit in value:
      if digit notin {'0' .. '9'}:
        return -1
      result = result * 10 + ord(digit) - ord('0')

proc trimPress*(
  messages: JsonNode,
  ownCountry: int,
  config: BudgetConfig
): PressContext {.raises: [].} =
  ## Bounds recent incoming press and ignores replay ordering in its signature.
  result.messages = newJArray()
  if messages == nil or messages.kind != JArray:
    result.signature = $secureHash("")
    return
  var
    counts: array[8, int]
    characters: array[8, int]
    totalCharacters = 0
    retained: seq[JsonNode]
    identities: seq[string]
  let first = max(0, messages.len - MaximumPressScan)
  for i in countdown(messages.len - 1, first):
    let item = messages[i]
    if item.kind != JObject:
      continue
    let
      sender = countryId(item{"fromCountryID"})
      recipient = countryId(item{"toCountryID"})
      text = item{"message"}
    if sender <= 0 or sender == ownCountry or
      (recipient != 0 and recipient != ownCountry) or
      text == nil or text.kind != JString or
      counts[sender] >= config.maxMessagesPerOpponent:
        continue
    let allowance = min(
      config.maxMessageCharacters,
      min(
        config.maxOpponentCharacters - characters[sender],
        config.maxPressCharacters - totalCharacters
      )
    )
    if allowance <= 0:
      continue
    let body = bytePrefix(text.getStr, allowance).strip
    if body.len == 0:
      continue
    let message = %*{
        "fromCountryID": sender,
        "toCountryID": recipient,
        "message": body
      }
    let
      turn = pressTurn(item{"turn"})
      phase = item{"phase"}.getStr()
    if turn >= 0:
      message["turn"] = %turn
    if phase in ["Diplomacy", "Retreats", "Builds", "Finished"]:
      message["phase"] = %phase
    let identity = $message
    if identity in identities:
      continue
    identities.add(identity)
    retained.add(message)
    inc counts[sender]
    characters[sender] += body.len
    totalCharacters += body.len
  for i in countdown(retained.len - 1, 0):
    result.messages.add(retained[i])
  result.omitted = messages.len - result.messages.len
  identities.sort()
  result.signature = $secureHash(identities.join("\n"))
