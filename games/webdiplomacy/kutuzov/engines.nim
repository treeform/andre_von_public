import
  std/[algorithm, json, os, sha1, strutils, times],
  jsony,
  budgets, common, logs, notes, prompts, protocols, requests, wakes

const
  PressAttemptLimit* = 2
  PressTextWireLimit* = 640
  RepairTextWireLimit* = 640
  RepairAttemptWireLimit* = 8192
  RepairOrderFields* = ["type", "terrID", "toTerrID", "fromTerrID",
    "viaConvoy", "convoyPath"]

type
  PhaseState* = object
    stamp*: string
    calls*, pressCalls*: int
    reviewed*, ready*: bool
    savedOrders*: JsonNode
    repairAttempt*: JsonNode
    pressSignature*, feedback*: string
    sent*: seq[string]
    transcript*: JsonNode
    seenPress*: seq[string]
    pendingSignature*: string
    pressFirstAt*, pressChangedAt*: int
    costUsd*, allowanceUsd*: float
    allowanceSet*, updatesStopped*: bool
    wake*: WakeState
    lookupFacts*: JsonNode
    continuationConfig*, continuationRequest*, continuationReply*: string
    continuationTranscript*: string

  BotState* = object
    gameId*, countryId*: int
    budget*: Budget
    phase*: PhaseState
    memory*, memoryStamp*, stopReason*: string
    memorySerial*: int
    memoryDelivery*: JsonNode
    notes*: seq[StrategicNote]
    toolDelivery*: JsonNode
    stopped*: bool
    toolLoop*: bool

  PressDelivery* = object
    confirmed*, outcomes*: JsonNode

  CallPlan* = object
    config*: RequestConfig
    reservedUsd*, allowanceUsd*: float
    requestBytes*: int
    allowed*, fallback*, reviewProtectionUnavailable*: bool
    pacing*: PacingContext
    expectedUsd*: float
    denial*, preferredDenial*: string

  PreparedInput* = object
    text*: string
    transcript*: JsonNode
    requestBytes*: int
    rebased*: bool

  Inference* = object
    text*, input*, model*: string
    deferred*: bool

proc integer*(value: JsonNode): int =
  ## Coerce upstream integer strings to explicit numeric state.
  if value.isNil or value.kind == JNull:
    return 0
  case value.kind
  of JInt:
    result = value.getInt
  of JString:
    try:
      result = parseInt(value.getStr)
    except ValueError:
      raise newException(KutuzovError, "Invalid upstream integer")
  else:
    raise newException(KutuzovError, "Expected upstream integer")

proc phaseStamp*(context: JsonNode): string =
  ## Identify a phase independently from changing messages and file versions.
  $integer(context{"game", "turn"}) & ":" &
    context{"game", "phase"}.getStr

proc repairText(value: string): JsonNode =
  ## Redact and bound untrusted diagnostic text at complete UTF-8 boundaries.
  let original = redactText(value)
  var excerpt = original
  while ($(%($(%excerpt)))).len > RepairTextWireLimit:
    var ending = excerpt.len - 1
    while ending > 0 and (ord(excerpt[ending]) and 0xC0) == 0x80:
      dec ending
    excerpt.setLen(ending)
  result = %*{"text": excerpt}
  if excerpt.len < original.len:
    result["text_truncated"] = %true
    result["original_text_bytes"] = %original.len

proc repairBytes*(attempt: JsonNode): int =
  ## Count a repair record's bytes inside a serialized observation string.
  ($(%($attempt))).len

proc trimRepairText(attempt: JsonNode) =
  ## Mark optional explanation excerpts unavailable without changing facts.
  for name in ["candidate_memory", "error"]:
    let text = attempt[name]["text"].getStr
    if text.len > 0:
      if not attempt[name].hasKey("original_text_bytes"):
        attempt[name]["original_text_bytes"] = %text.len
      attempt[name]["text"] = %""
      attempt[name]["text_truncated"] = %true

proc omitRepairOrders(attempt: JsonNode, reason: string) =
  ## Omit an oversized table as a whole while making its absence explicit.
  for field in ["order_fields", "orders", "order_absent"]:
    if attempt.hasKey(field):
      attempt.delete(field)
  attempt["orders_complete"] = %false
  attempt["orders_unavailable_reason"] = %reason

proc repairView*(phase: PhaseState): JsonNode =
  ## Return the last bounded failed attempt only in its original phase.
  if phase.repairAttempt.isNil or phase.repairAttempt.kind == JNull:
    return newJNull()
  if phase.repairAttempt{"phase"}.getStr != phase.stamp:
    return newJNull()
  result = phase.repairAttempt.copy()
  if repairBytes(result) > RepairAttemptWireLimit:
    result.trimRepairText()
  if repairBytes(result) > RepairAttemptWireLimit:
    result.omitRepairOrders("representation_limit")
  if repairBytes(result) > RepairAttemptWireLimit:
    raise newException(KutuzovError, "Invalid oversized repair metadata")

proc captureRepairAttempt*(
  phase: var PhaseState,
  decision: Decision,
  task: string,
  error: ref KutuzovError
) =
  ## Preserve one failed save without promoting its orders or model memory.
  var
    rejected = error of KutuzovOrderError
    detail = error.msg
    source = (if rejected: "OrderValidation" else: "UnknownGameOutcome")
    status = newJNull()
    reasonTruncated = false
    originalReasonBytes = 0
  if error of KutuzovHttpError:
    let http = (ref KutuzovHttpError)(error)
    source = $http.source
    status = %http.status
    rejected = http.source == GameAction and http.status == 400 and
      http.orderSubmission and
      not decision.orders.isNil and decision.orders.len > 0
    if http.reason.len > 0:
      detail = http.reason
      reasonTruncated = http.reasonTruncated
      originalReasonBytes = http.originalReasonBytes
  let
    explanation = repairText(decision.memory)
    diagnostic = repairText(detail)
    rows = newJArray()
    absent = newJArray()
    orderCount =
      if decision.orders.isNil or decision.orders.kind != JArray:
        0
      else:
        decision.orders.len
  explanation["unverified"] = %true
  diagnostic["source"] = %source
  diagnostic["http_status"] = status
  if reasonTruncated:
    diagnostic["text_truncated"] = %true
    diagnostic["original_text_bytes"] = %originalReasonBytes
  var complete = not decision.orders.isNil and
    decision.orders.kind == JArray and decision.orders.len <= 64
  if complete:
    for rowIndex in 0 ..< decision.orders.len:
      let order = decision.orders[rowIndex]
      if order.kind != JObject:
        complete = false
        break
      let row = newJArray()
      for column, name in RepairOrderFields:
        if order.hasKey(name):
          row.add order[name].copy()
        else:
          row.add newJNull()
          absent.add %*[rowIndex, column]
      rows.add row
  phase.repairAttempt = %*{
    "phase": phase.stamp,
    "call": phase.calls,
    "source_task": task,
    "outcome": (if rejected: "rejected" else: "unconfirmed"),
    "needs_repair": rejected,
    "unchanged_rejected": error of KutuzovTargetError,
    "orders_complete": complete,
    "original_order_count": orderCount,
    "candidate_memory": explanation,
    "error": diagnostic
  }
  if complete:
    phase.repairAttempt["order_fields"] = %RepairOrderFields
    phase.repairAttempt["orders"] = rows
    if absent.len > 0:
      phase.repairAttempt["order_absent"] = absent
  else:
    phase.repairAttempt["orders_unavailable_reason"] = %"invalid_order_shape"
  phase.repairAttempt = phase.repairView()
  phase.feedback = (if rejected: diagnostic["text"].getStr else: "")

proc rejectRepeatedOrders*(phase: PhaseState, orders: JsonNode) =
  ## Block a known invalid target without blocking ambiguous write recovery.
  let attempt = phase.repairView()
  if attempt.isNil or attempt.kind == JNull or
    not attempt{"needs_repair"}.getBool or
    not attempt{"unchanged_rejected"}.getBool or
    not attempt{"orders_complete"}.getBool or
    attempt{"order_fields"} != %RepairOrderFields:
      return
  var
    previous, current: seq[string]
  for row in attempt["orders"]:
    previous.add($row)
  for order in orders:
    let row = newJArray()
    for field in RepairOrderFields:
      let value = order{field}
      row.add(if value.isNil: newJNull() else: value.copy())
    current.add($row)
  previous.sort()
  current.sort()
  if previous == current:
    raise newException(
      KutuzovTargetError,
      "This exact order set was already rejected in this phase. " &
        "Change the rejected orders using current board and map facts. " &
        "Previous rejection: " & attempt{"error", "text"}.getStr()
    )

proc pressOutcomes*(messages: JsonNode): JsonNode =
  ## Initialize bounded facts without assuming a draft has been attempted.
  if messages.isNil or messages.kind != JArray or messages.len > 7:
    raise newException(KutuzovError, "Press facts need at most seven drafts")
  result = newJArray()
  for index in 0 ..< messages.len:
    let message = messages[index]
    if message.kind != JObject or message{"to"}.isNil or
      message["to"].kind != JInt or message["to"].getInt notin 0 .. 7 or
      message{"text"}.isNil or message["text"].kind != JString or
      message["text"].getStr.len > 600:
        raise newException(KutuzovError, "Invalid press delivery draft")
    result.add %*{
      "index": index, "to": message["to"], "text": message["text"],
      "status": "pending", "reason": "not_attempted"
    }

proc deliveryView*(delivery: JsonNode): JsonNode =
  ## Bound prompt text expansion while retaining exact durable delivery facts.
  if delivery.isNil or delivery.kind == JNull:
    return newJNull()
  result = delivery.copy()
  let outcomes = result{"outcomes"}
  if outcomes.isNil or outcomes.kind != JArray:
    raise newException(KutuzovError, "Invalid persisted delivery facts")
  for outcome in outcomes:
    let original = outcome["text"].getStr
    var excerpt = original
    while ($(%($(%excerpt)))).len > PressTextWireLimit:
      var ending = excerpt.len - 1
      while ending > 0 and (ord(excerpt[ending]) and 0xC0) == 0x80:
        dec ending
      excerpt.setLen(ending)
    if excerpt.len < original.len:
      outcome["text"] = %excerpt
      outcome["text_truncated"] = %true
      outcome["original_text_bytes"] = %original.len

proc rememberMovement*(
  state: var BotState,
  context: JsonNode,
  memory: string,
  press: JsonNode = nil
) =
  ## Replace verified movement memory and its exact decision's delivery facts.
  if context{"game", "phase"}.getStr == "Diplomacy":
    let
      stamp = phaseStamp(context)
      outcomes =
        if press.isNil:
          nil
        else:
          pressOutcomes(press)
    state.memory = memory
    state.memoryStamp = stamp
    inc state.memorySerial
    state.memoryDelivery =
      if outcomes.isNil:
        nil
      else:
        %*{
          "decision_id": $state.gameId & ":" & $state.countryId & ":" &
            $state.memorySerial,
          "phase": state.memoryStamp,
          "outcomes": outcomes
        }

proc pressAttempts(phase: PhaseState, recipient: int): int =
  ## Count persisted attempts, including sends with unknown delivery status.
  let prefix = $recipient & ":"
  for sent in phase.sent:
    if sent.startsWith(prefix):
      inc result

proc pressAvailability*(
  config: GameConfig,
  context: JsonNode,
  phase: PhaseState
): JsonNode =
  ## Describe current quotas without promising delivery or peer acceptance.
  let
    pressType = context{"game", "pressType"}.getStr("Regular")
    recipients = newJArray()
  for recipient in 0 .. 7:
    let
      attempts = phase.pressAttempts(recipient)
      allowed = recipient != config.countryId and pressType != "NoPress" and
        (pressType != "PublicPressOnly" or recipient == 0)
    recipients.add %*{
      "to": recipient, "allowed": allowed, "attempts": attempts,
      "remaining_attempts": max(0, PressAttemptLimit - attempts)
    }
  %*{
    "limit_per_recipient": PressAttemptLimit,
    "press_type": pressType, "recipients": recipients
  }

proc horizonReached*(turn: int, phase: string, endYear: int): bool =
  ## Stop after the configured autumn retreats rather than paying for builds.
  let year = 1901 + turn div 2
  year > endYear or (year == endYear and turn mod 2 == 1 and phase == "Builds")

proc clearContinuation*(phase: var PhaseState) =
  ## Invalidate process-local proof of an answered same-model request.
  phase.continuationConfig = ""
  phase.continuationRequest = ""
  phase.continuationReply = ""
  phase.continuationTranscript = ""

proc configuredRequest(config: RequestConfig, empirical: bool): RequestConfig =
  ## Normalize the exact model and output settings used for dispatch.
  result = config
  if empirical:
    result.maxOutputTokens = min(result.maxOutputTokens, 3_000)
  if result.api == ChatApi:
    if not result.model.startsWith("openai/"):
      result.model = "openai/" & result.model
  elif result.model.startsWith("openai/"):
    result.model = result.model[7 .. ^1]

proc continuationConfig(config: RequestConfig, instructions: string): string =
  ## Fingerprint inference settings without persisting credentials or text.
  $secureHash($(%*[
    $config.api, config.baseUrl, config.apiKey, config.model,
    config.reasoningEffort, config.cacheKey, $config.maxOutputTokens,
    instructions
  ]))

proc continuationRequest(transcript: JsonNode, input: string): string =
  ## Bind the retained messages and final user input before dispatch.
  $secureHash($transcript & "\n" & input)

proc rememberContinuation*(
  phase: var PhaseState,
  config: RequestConfig,
  instructions, input, reply: string
) =
  ## Mark a successful request pending its exact assistant and tool receipt.
  phase.clearContinuation()
  phase.continuationConfig = $secureHash(
    phase.stamp & continuationConfig(config, instructions)
  )
  phase.continuationRequest = continuationRequest(phase.transcript, input)
  phase.continuationReply = $secureHash(reply)

proc continuationPacing*(
  phase: PhaseState,
  config: RequestConfig,
  instructions: string,
  transcript: JsonNode,
  rebased = false
): PacingContext =
  ## Require an exact answered Sol prefix under unchanged inference settings.
  if rebased or config.model notin ["gpt-6.1-sol", "openai/gpt-6.1-sol"] or
    transcript.isNil or transcript.len == 0 or
    phase.continuationTranscript.len == 0:
      return OrdinaryRequest
  if phase.continuationConfig == $secureHash(
    phase.stamp & continuationConfig(config, instructions)
  ) and
    phase.continuationTranscript == $secureHash($transcript):
      return WarmSolContinuation

proc persist*(state: BotState, path: string) =
  ## Save bounded state atomically before calls and potentially ambiguous sends.
  try:
    writeFile(path & ".tmp", state.toJson)
    moveFile(path & ".tmp", path)
  except IOError, OSError:
    raise newException(KutuzovError, "Cannot persist Kutuzov state")

proc restore*(
  config: GameConfig,
  path: string,
  mode = ConservativeBudget,
  toolLoop = false
): BotState =
  ## Recover per-game spend and actions without replaying an ambiguous request.
  result.gameId = config.gameId
  result.countryId = config.countryId
  result.budget.mode = mode
  result.toolLoop = toolLoop
  if not fileExists(path):
    return
  try:
    let saved = readFile(path).fromJson(BotState)
    if saved.gameId == config.gameId and saved.countryId == config.countryId:
      if saved.budget.mode != mode:
        raise newException(KutuzovError,
          "Budget mode cannot change within a saved game")
      if saved.toolLoop != toolLoop:
        raise newException(KutuzovError,
          "Tool-loop mode cannot change within a saved game")
      result = saved
      result.phase.clearContinuation()
      validateNotes(result.notes)
      if result.budget.reservedUsd > 0:
        let pending = result.budget.reservedUsd
        result.budget.settleUnknown(pending)
        result.phase.costUsd += pending
  except IOError, jsony.JsonError:
    raise newException(KutuzovError, "Cannot restore Kutuzov state")

proc visiblePress*(context, publicMessages: JsonNode, turn: int): JsonNode =
  ## Collect a bounded tail of recent private and public press.
  result = newJArray()
  for messages in [context{"messages", "messages"}, publicMessages{"messages"}]:
    if not messages.isNil and messages.kind == JArray:
      for i in max(0, messages.len - 256) ..< messages.len:
        if messages[i]{"turn"}.isNil or
          integer(messages[i]{"turn"}) >= turn - 1:
          result.add messages[i]

proc syncSpend(
  state: var BotState,
  limits: var BudgetConfig,
  config: RequestConfig
) =
  ## Apply the hosted player's current meter and effective spending ceiling.
  let spend = config.fetchSpend()
  if spend.available:
    state.budget.updateSpend(spend.spent)
    if spend.hasLimit:
      limits.limitUsd = min(limits.limitUsd, spend.limit)
      limits.reserveUsd = min(limits.reserveUsd, limits.limitUsd * 0.30)
    logEvent("spend_sync", %*{
      "spent_usd": spend.spent, "effective_limit_usd": limits.limitUsd,
      "reserve_usd": limits.reserveUsd
    })

proc chooseCall*(
  config: RequestConfig,
  budget: Budget,
  limits: BudgetConfig,
  instructions, inputText: string,
  finalYear = false,
  remainingMovements = 1,
  economyModel = "",
  transcript: JsonNode = nil,
  reviewModel = "",
  phaseSpentUsd = 0.0,
  phaseAllowanceUsd = -1.0,
  optionalCall = false,
  protectInitialReview = false,
  finalAutumn = false,
  pacing: PacingContext = OrdinaryRequest
): CallPlan =
  ## Protect initial reviews and defer optional calls without downgrading.
  result.config = config
  result.allowanceUsd = max(
    0.0,
    limits.limitUsd - budget.budgetSpent -
      budget.stoppingReserve(limits, finalYear, finalAutumn)
  )
  if finalYear and limits.mode == ConservativeBudget:
    result.allowanceUsd /= max(1, remainingMovements).float
  var tried: seq[string]
  for model in [config.model, economyModel, "gpt-6-luna"]:
    if limits.mode == EmpiricalBudget and optionalCall and tried.len > 0:
      break
    if model.len == 0:
      continue
    var candidate = config
    candidate.model = model
    candidate = configuredRequest(candidate, limits.mode == EmpiricalBudget)
    if candidate.model in tried:
      continue
    tried.add(candidate.model)
    let
      protectReview = reviewModel.len > 0 and
        (not protectInitialReview or tried.len == 1)
      bytes = ($candidate.buildRequest(
        instructions, inputText, transcript
      )).len + 512
      reserved =
        if limits.mode == EmpiricalBudget:
          budget.empiricalCost(candidate.model)
        else:
          reserveCost(candidate.model, bytes, candidate.maxOutputTokens)
      reviewReserve =
        if limits.mode == EmpiricalBudget and protectReview:
          budget.empiricalCost(reviewModel)
        else:
          0.0
      context =
        if limits.mode == EmpiricalBudget and limits.toolLoop and tried.len == 1:
          pacing
        else:
          OrdinaryRequest
      expected = budget.expectedCost(candidate.model, context)
    result.requestBytes = bytes
    result.reservedUsd = reserved
    result.pacing = context
    result.expectedUsd = expected
    let reviewExpected =
      if protectReview:
        budget.expectedCost(reviewModel)
      else:
        0.0
    if limits.mode == EmpiricalBudget and
      (optionalCall or protectReview or
      candidate.model in ["gpt-6.1-sol", "openai/gpt-6.1-sol"]) and
      phaseAllowanceUsd >= 0.0 and
      phaseSpentUsd + expected +
      reviewExpected > phaseAllowanceUsd:
        result.denial = "phase_pacing"
        if tried.len == 1:
          result.preferredDenial = result.denial
        continue
    if bytes > min(limits.maxContextBytes, MaximumRequestBytes):
      result.denial = "context_limit"
    elif reserved + reviewReserve > result.allowanceUsd or
      not budget.canSpend(
        limits,
        reserved + reviewReserve,
        finalYear,
        finalAutumn
      ):
        result.denial = "global_reservation"
    else:
      result.config = candidate
      result.allowed = true
      result.fallback = tried.len > 1
      result.reviewProtectionUnavailable = protectInitialReview and
        result.fallback
      result.denial = ""
      return
    if tried.len == 1:
      result.preferredDenial = result.denial

proc observation*(
  config: GameConfig,
  context, board, history: JsonNode,
  press: PressContext,
  state: BotState,
  limits: BudgetConfig,
  task: string,
  variant: JsonNode = nil
): JsonNode =
  ## Assemble only game data, bounded memory and explicit resource constraints.
  let
    turn = integer(context{"game", "turn"})
    year = 1901 + turn div 2
  result = %*{
    "country_id": config.countryId,
    "end_year": config.endYear,
    "scoring": config.scoring,
    "turn": turn,
    "phase": context{"game", "phase"},
    "year": year,
    "season": (if turn mod 2 == 0: "spring" else: "autumn"),
    "final_year": year == config.endYear,
    "board": compactBoard(board, variant),
    "recent_history": recentHistory(history),
    "task": task,
    "order_slots": context{"orders", "orders"},
    "saved_orders": state.phase.savedOrders,
    "press": press.messages,
    "omitted_messages": press.omitted,
    "outgoing_press": pressAvailability(config, context, state.phase),
    "memory": state.memory,
    "memory_phase": (
      if state.memoryStamp.len == 0:
        newJNull()
      else:
        %state.memoryStamp
    ),
    "memory_delivery": deliveryView(state.memoryDelivery),
    "repair_attempt": state.phase.repairView(),
    "repair_feedback": state.phase.feedback,
    "remaining_usd": max(0.0, limits.limitUsd - state.budget.budgetSpent),
    "final_year_reserve_usd": limits.reserveUsd,
    "remaining_phase_calls": max(0, limits.maxPhaseCalls - state.phase.calls),
    "reviewed": state.phase.reviewed,
    "updates_stopped": state.phase.updatesStopped,
    "remaining_updates": max(0, limits.maxPressCalls - state.phase.pressCalls),
    "deadline_unix": integer(context{"game", "processTime"}),
    "seconds_left": max(0, integer(context{"game", "processTime"}) -
      int(epochTime()))
  }
  if limits.toolLoop:
    result["strategic_notes"] = notesView(state.notes)
    result["tool_delivery"] = deliveryView(state.toolDelivery)
    result["known_connections"] =
      if state.phase.lookupFacts.isNil:
        newJNull()
      else:
        %*{
          "scope": "latest_lookup_batch",
          "phase": state.phase.stamp,
          "facts": state.phase.lookupFacts
        }
    result["tool_wake"] = %*{
      "number": state.phase.wake.count,
      "kind": $state.phase.wake.kind,
      "requests_used": state.phase.wake.calls,
      "remaining_requests": max(
        0, MaximumWakeRequests - state.phase.wake.calls
      ),
      "remaining_wakes": max(
        0, MaximumMovementWakes - state.phase.wake.count
      ),
      "deadline_unix": state.phase.wake.deadline,
      "request_number": state.phase.calls + 1
    }

proc unreadPress*(phase: PhaseState, messages: JsonNode): JsonNode =
  ## Return distinct bounded press that has not reached a verified decision.
  result = newJArray()
  if messages.isNil or messages.kind != JArray:
    return
  for message in messages:
    if $message notin phase.seenPress:
      result.add message

proc nextTask*(
  phase: var PhaseState,
  phaseName: string,
  press: PressContext,
  limits: BudgetConfig,
  remaining, timeoutSeconds, now: int
): string =
  ## Debounce new press, reserve a review call, and keep time to verify orders.
  if remaining <= 40 or phase.calls >= limits.maxPhaseCalls:
    return "ready"
  let attempt = phase.repairView()
  if attempt{"needs_repair"}.getBool or phase.feedback.len > 0:
    return "repair"
  if phase.savedOrders.isNil or phase.savedOrders.len == 0:
    return "plan"
  if phaseName != "Diplomacy":
    return "ready"
  let unread = phase.unreadPress(press.messages)
  if unread.len > 0:
    if phase.pendingSignature.len == 0:
      phase.pendingSignature = press.signature
      phase.pressFirstAt = now
      phase.pressChangedAt = now
    elif phase.pendingSignature != press.signature:
      phase.pendingSignature = press.signature
      phase.pressChangedAt = now
  else:
    phase.pendingSignature = ""
  if not phase.reviewed and remaining <= timeoutSeconds + 25:
    return "review"
  let
    hasCall = phase.reviewed or phase.calls < limits.maxPhaseCalls - 1
    settled = now - phase.pressChangedAt >= 10 or
      now - phase.pressFirstAt >= 20
  if unread.len > 0 and hasCall and settled and
    phase.pressCalls < limits.maxPressCalls and not phase.updatesStopped:
      return "update"
  "wait"

proc prepareInput*(
  config: RequestConfig,
  instructions: string,
  input: JsonNode,
  phase: PhaseState,
  limits: BudgetConfig
): PreparedInput =
  ## Append deltas to a bounded phase transcript or rebase the complete board.
  let maximum = min(limits.maxContextBytes, MaximumRequestBytes)
  result.transcript = phase.transcript
  if result.transcript.isNil:
    result.transcript = newJArray()
  var bounded = ($input).fromJson(JsonNode)
  if result.transcript.len > 0:
    bounded = %*{
      "task": input["task"],
      "phase_update": true,
      "board_unchanged": true,
      "order_slots": input["order_slots"],
      "saved_orders": input["saved_orders"],
      "new_press": phase.unreadPress(input["press"]),
      "omitted_messages": input["omitted_messages"],
      "outgoing_press": input["outgoing_press"],
      "memory": input["memory"],
      "memory_phase": input["memory_phase"],
      "memory_delivery": input["memory_delivery"],
      "repair_attempt": (
        if input{"repair_attempt"}.isNil:
          newJNull()
        else:
          input["repair_attempt"].copy()
      ),
      "repair_feedback": input["repair_feedback"],
      "remaining_usd": input["remaining_usd"],
      "final_year_reserve_usd": input["final_year_reserve_usd"],
      "remaining_phase_calls": input["remaining_phase_calls"],
      "reviewed": input["reviewed"],
      "updates_stopped": input["updates_stopped"],
      "remaining_updates": input["remaining_updates"],
      "deadline_unix": input["deadline_unix"],
      "seconds_left": input["seconds_left"]
    }
    for field in ["strategic_notes", "tool_delivery", "tool_wake"]:
      if not input{field}.isNil:
        bounded[field] = input[field].copy()
  result.text = $bounded
  result.requestBytes = ($config.buildRequest(
    instructions, result.text, result.transcript
  )).len + 512
  if result.requestBytes > maximum and result.transcript.len > 0:
    result.rebased = true
    result.transcript = newJArray()
    bounded = ($input).fromJson(JsonNode)
    result.text = $bounded
    result.requestBytes = ($config.buildRequest(
      instructions, result.text, result.transcript
    )).len + 512
  while result.requestBytes > maximum:
    let history = bounded{"recent_history"}
    if not history.isNil and history.len > 0:
      var recent = newJArray()
      for i in 1 ..< history.len:
        recent.add history[i]
      bounded["recent_history"] = recent
      bounded["history_trimmed"] = %true
    else:
      let press = bounded{"press"}
      if press.isNil or press.len == 0:
        break
      var recent = newJArray()
      for i in 1 ..< press.len:
        recent.add press[i]
      bounded["press"] = recent
      bounded["omitted_messages"] = %(bounded["omitted_messages"].getInt + 1)
    result.text = $bounded
    result.requestBytes = ($config.buildRequest(
      instructions, result.text, result.transcript
    )).len + 512
  if result.requestBytes > maximum:
    let attempt = bounded{"repair_attempt"}
    if not attempt.isNil and attempt.kind == JObject:
      attempt.trimRepairText()
      result.text = $bounded
      result.requestBytes = ($config.buildRequest(
        instructions, result.text, result.transcript
      )).len + 512
      if result.requestBytes > maximum and attempt["orders_complete"].getBool:
        attempt.omitRepairOrders("request_context_limit")
        result.text = $bounded
        result.requestBytes = ($config.buildRequest(
          instructions, result.text, result.transcript
        )).len + 512

proc recordExchange*(
  phase: var PhaseState,
  input, reply: string,
  receipt: JsonNode,
  limits: BudgetConfig,
  consumePress = true
) =
  ## Retain exact model messages with truthful host action outcomes.
  if phase.transcript.isNil:
    phase.transcript = newJArray()
  let answered = phase.continuationRequest.len > 0 and
    phase.continuationRequest == continuationRequest(phase.transcript, input) and
    phase.continuationReply == $secureHash(reply) and not receipt.isNil
  if not answered:
    phase.clearContinuation()
  phase.transcript.add %*{"role": "user", "content": input}
  phase.transcript.add %*{"role": "assistant", "content": reply}
  phase.transcript.add %*{"role": "user", "content": $receipt}
  if phase.transcript.len > MaximumTranscriptMessages or
    ($phase.transcript).len > min(limits.maxContextBytes, MaximumRequestBytes):
      phase.transcript = newJArray()
      phase.clearContinuation()
      logEvent("conversation_reset", %*{"reason": "retained_size_limit"})
  elif answered:
    phase.continuationTranscript = $secureHash($phase.transcript)
  if consumePress:
    let observed = input.fromJson(JsonNode)
    for field in ["press", "new_press"]:
      let messages = observed{field}
      if not messages.isNil and messages.kind == JArray:
        for message in messages:
          let identity = $message
          if identity notin phase.seenPress:
            if phase.seenPress.len == 64:
              phase.seenPress.delete(0)
            phase.seenPress.add identity
  phase.pendingSignature = ""

proc requestTimeout*(configured, deadline, now: int): int =
  ## Leave thirty seconds for phase checks, verified saves and Ready.
  max(0, min(configured, deadline - now - 30))

proc actionTimeout*(configured, deadline, now: int, calls = 4): int =
  ## Divide remaining time among game requests with a five-second margin.
  max(1, min(configured, (deadline - now - 5) div max(1, calls)))

proc phaseModel*(
  config: RequestConfig,
  economy: string,
  mode: BudgetMode,
  task: string,
  finalYear: bool,
  year: int,
  phaseName = "Diplomacy"
): RequestConfig =
  ## Prefer the primary movement planner after the cheap opening year.
  result = config
  if task != "plan":
    return
  let cheap =
    if mode == EmpiricalBudget and phaseName == "Diplomacy":
      year <= 1901
    else:
      economy.len > 0 and not finalYear
  if cheap:
    result.model =
      if economy.len > 0: economy
      else: "gpt-6-luna"
    if result.api == ChatApi and not result.model.startsWith("openai/"):
      result.model = "openai/" & result.model

proc settleCall*(
  state: var BotState,
  model: string,
  reserved, cost: float,
  known: bool,
  pacing: PacingContext = OrdinaryRequest
) =
  ## Record real usage or retain an explicitly uncertain request allowance.
  if known:
    state.budget.settleKnown(model, reserved, cost, pacing)
    state.phase.costUsd += cost
  else:
    state.budget.settleUnknown(reserved)
    state.phase.costUsd += reserved

proc infer*(
  state: var BotState,
  limits: var BudgetConfig,
  config: RequestConfig,
  instructions: string,
  input: JsonNode,
  finalYear: bool,
  path, economyModel: string,
  toolStep = false,
  reviewModelName = ""
): Inference =
  ## Reserve by the chosen accounting mode and retain usage or uncertainty.
  if toolStep and state.phase.calls >= limits.maxPhaseCalls:
    logEvent("inference_skipped", %*{
      "reason": "phase_request_limit", "phase": state.phase.stamp
    })
    return
  try:
    state.syncSpend(limits, config)
  except KutuzovError as error:
    raise newException(KutuzovRequestError, error.msg)
  if limits.mode == EmpiricalBudget and not state.phase.allowanceSet:
    state.phase.allowanceUsd = state.budget.movementAllowance(
      limits, input["turn"].getInt(), input["end_year"].getInt()
    )
    state.phase.allowanceSet = true
  var timed = config
  timed.timeoutSeconds = requestTimeout(
    config.timeoutSeconds,
    input["deadline_unix"].getInt(),
    int(epochTime())
  )
  if toolStep:
    timed.timeoutSeconds = min(
      timed.timeoutSeconds,
      state.phase.wake.remainingSeconds(
        defaultWakeConfig(),
        int(epochTime()),
        input["deadline_unix"].getInt()
      )
    )
  if timed.timeoutSeconds < 5:
    logEvent("inference_skipped", %*{
      "reason": "deadline_after_spend_sync", "phase": state.phase.stamp
    })
    return
  let
    prepared = prepareInput(timed, instructions, input, state.phase, limits)
    text = prepared.text
    bytes = prepared.requestBytes
  if bytes > min(limits.maxContextBytes, MaximumRequestBytes):
    logEvent("inference_skipped", %*{
      "reason": "context_limit", "bytes": bytes,
      "limit_bytes": limits.maxContextBytes, "phase": state.phase.stamp
    })
    return
  if prepared.rebased:
    state.phase.clearContinuation()
    logEvent("conversation_rebased", %*{
      "phase": state.phase.stamp, "bytes": bytes,
      "previous_messages": state.phase.transcript.len
    })
  let
    movements =
      if finalYear and input["season"].getStr() == "spring": 2
      else: 1
    finalAutumn = finalYear and input["season"].getStr() == "autumn"
    optionalToolPlan = toolStep and input["task"].getStr() == "plan" and
      not state.phase.savedOrders.isNil and state.phase.savedOrders.len > 0
    optionalCall = input["task"].getStr() == "update" or optionalToolPlan
    protectInitialReview = limits.mode == EmpiricalBudget and
      input["task"].getStr() == "plan" and
      input["phase"].getStr() == "Diplomacy" and
      input["year"].getInt() >= 1902
    reviewModel =
      if limits.mode == EmpiricalBudget and
        ((optionalCall and not state.phase.reviewed) or
        protectInitialReview):
          if toolStep and reviewModelName.len > 0:
            reviewModelName
          else:
            config.model
      else:
        ""
    pacing =
      if toolStep and limits.mode == EmpiricalBudget and limits.toolLoop:
        state.phase.continuationPacing(
          configuredRequest(timed, true), instructions,
          prepared.transcript, prepared.rebased
        )
      else:
        OrdinaryRequest
    plan = chooseCall(
      timed,
      state.budget,
      limits,
      instructions,
      text,
      finalYear,
      movements,
      economyModel,
      prepared.transcript,
      reviewModel,
      state.phase.costUsd,
      state.phase.allowanceUsd,
      optionalCall,
      protectInitialReview,
      finalAutumn,
      pacing
    )
    selected = plan.config
    reserved = plan.reservedUsd
    admitted = plan.allowed and state.budget.reserve(
      limits,
      reserved,
      finalYear,
      finalAutumn
    )
  if not admitted:
    logEvent("inference_skipped", %*{
      "reason": "budget_reserve", "phase": state.phase.stamp,
      "spent_usd": state.budget.budgetSpent, "call_reserve_usd": reserved,
      "limit_usd": limits.limitUsd, "final_year": finalYear,
      "final_autumn": finalAutumn,
      "call_allowance_usd": plan.allowanceUsd,
      "denial": plan.denial, "preferred_denial": plan.preferredDenial,
      "pacing": $plan.pacing, "expected_cost_usd": plan.expectedUsd
    })
    result.deferred = limits.mode == EmpiricalBudget and optionalCall
    return
  if toolStep and not state.phase.wake.takeRequest(
    defaultWakeConfig(),
    int(epochTime()),
    input["deadline_unix"].getInt()
  ):
    state.budget.settle(reserved, 0.0)
    state.persist(path)
    logEvent("inference_skipped", %*{
      "reason": "wake_request_or_time_limit", "phase": state.phase.stamp
    })
    return
  if plan.reviewProtectionUnavailable:
    logEvent("initial_review_unprotected", %*{
      "phase": state.phase.stamp, "preferred_model": config.model,
      "selected_model": selected.model, "call_reserve_usd": reserved,
      "phase_cost_usd": state.phase.costUsd,
      "phase_allowance_usd": state.phase.allowanceUsd,
      "reason": "required_plan_fallback"
    })
  if plan.fallback:
    logEvent("economy_fallback", %*{
      "phase": state.phase.stamp, "preferred_model": config.model,
      "selected_model": selected.model, "call_reserve_usd": reserved,
      "call_allowance_usd": plan.allowanceUsd,
      "remaining_movements": movements, "final_year": finalYear,
      "preferred_denial": plan.preferredDenial,
      "preferred_pacing": $pacing,
      "preferred_expected_usd": state.budget.expectedCost(config.model, pacing)
    })
  inc state.phase.calls
  if input["task"].getStr() == "update" and not toolStep:
    inc state.phase.pressCalls
  state.phase.transcript = prepared.transcript
  state.persist(path)
  logEvent("inference_start", %*{
    "phase": state.phase.stamp, "call": state.phase.calls,
    "tool_loop": toolStep,
    "wake": state.phase.wake.count,
    "wake_call": state.phase.wake.calls,
    "task": input["task"], "model": selected.model,
    "call_reserve_usd": reserved, "request_bytes": plan.requestBytes,
    "timeout_seconds": selected.timeoutSeconds,
    "conversation_messages": prepared.transcript.len,
    "budget_mode": $limits.mode,
    "final_autumn": finalAutumn,
    "stopping_reserve_usd": state.budget.stoppingReserve(
      limits,
      finalYear,
      finalAutumn
    ),
    "reservation_is_estimate": limits.mode == EmpiricalBudget,
    "uncertain_usd": state.budget.uncertainUsd,
    "uncertain_calls": state.budget.uncertainCalls,
    "phase_cost_usd": state.phase.costUsd,
    "phase_allowance_usd": state.phase.allowanceUsd,
    "pacing": $plan.pacing, "expected_cost_usd": plan.expectedUsd,
    "deadline_unix": input["deadline_unix"],
    "seconds_left_after_spend": input["deadline_unix"].getInt() -
      int(epochTime())
  })
  var completion: Completion
  state.phase.clearContinuation()
  try:
    completion = selected.completeResult(
      instructions, text, prepared.transcript
    )
  except KutuzovError as error:
    state.settleCall(selected.model, reserved, reserved, false)
    state.persist(path)
    logError("inference_transport", error)
    raise
  var
    cost = reserved
    known = false
  if completion.usage.hasInput and completion.usage.hasOutput:
    let writes =
      if completion.usage.hasCacheWrite:
        completion.usage.cacheWrite
      else:
        max(0, completion.usage.input - completion.usage.cached)
    try:
      cost = estimateCost(
        selected.model,
        completion.usage.input,
        completion.usage.output,
        completion.usage.cached,
        writes
      )
      known = true
    except KutuzovError:
      cost = reserved
  state.settleCall(selected.model, reserved, cost, known, plan.pacing)
  if completion.hasSpend:
    state.budget.updateSpend(completion.spendUsd)
  if completion.hasLimit:
    limits.limitUsd = min(limits.limitUsd, completion.limitUsd)
    limits.reserveUsd = min(limits.reserveUsd, limits.limitUsd * 0.30)
  state.persist(path)
  logEvent("llm_call", %*{
    "model": selected.model,
    "phase": state.phase.stamp, "input_tokens": completion.usage.input,
    "output_tokens": completion.usage.output,
    "cached_tokens": completion.usage.cached,
    "cache_reported": completion.usage.hasCached,
    "estimated_spend_usd": state.budget.budgetSpent,
    "sidecar_spend_usd": state.budget.authoritativeSpentUsd,
    "budget_mode": $limits.mode,
    "cost_known": known,
    "pacing": $plan.pacing, "expected_cost_usd": plan.expectedUsd,
    "actual_cost_usd": (if known: %cost else: newJNull()),
    "uncertain_usd": state.budget.uncertainUsd,
    "uncertain_calls": state.budget.uncertainCalls,
    "status": completion.httpStatus, "error": completion.error,
    "cache_write_tokens": completion.usage.cacheWrite,
    "cache_write_reported": completion.usage.hasCacheWrite,
    "text_bytes": completion.text.len
  })
  if completion.error.len > 0:
    if completion.httpStatus notin 200 .. 299:
      raise newException(KutuzovRequestError, completion.error)
    raise newException(KutuzovError, completion.error)
  if toolStep and limits.mode == EmpiricalBudget and limits.toolLoop:
    state.phase.rememberContinuation(
      selected, instructions, text, completion.text
    )
  result.text = completion.text
  result.input = text
  result.model = selected.model

proc savePressOutcome(
  state: BotState,
  outcomes: JsonNode,
  index: int,
  status, reason, path: string
) =
  ## Persist each fact without changing whether an attempt may be retried.
  outcomes[index]["status"] = %status
  outcomes[index]["reason"] = %reason
  state.persist(path)

proc dispatchPress*(
  config: GameConfig,
  context: JsonNode,
  messages: JsonNode,
  state: var BotState,
  path: string,
  memoryDecisionId = "",
  toolDelivery = false
): PressDelivery =
  ## Keep two attempts per peer and report outcomes for each bounded draft.
  result.confirmed = newJArray()
  result.outcomes = pressOutcomes(messages)
  if memoryDecisionId.len > 0:
    let companion =
      if toolDelivery:
        state.toolDelivery
      else:
        state.memoryDelivery
    if companion.isNil or companion.kind != JObject or
      companion{"decision_id"}.getStr != memoryDecisionId or
      companion{"phase"}.getStr != phaseStamp(context) or
      (not toolDelivery and
      context{"game", "phase"}.getStr != "Diplomacy") or
      companion{"outcomes"} != result.outcomes:
        raise newException(KutuzovError,
          "Press facts do not belong to this pending movement decision")
    result.outcomes = companion["outcomes"]
  state.persist(path)
  let pressType = context{"game", "pressType"}.getStr("Regular")
  for index in 0 ..< messages.len:
    let
      message = messages[index]
      recipient = message["to"].getInt
      key = $recipient & ":" & message["text"].getStr
      count = state.phase.pressAttempts(recipient)
      reason =
        if pressType == "NoPress":
          "no_press"
        elif recipient == config.countryId:
          "self_recipient"
        elif key in state.phase.sent:
          "duplicate"
        elif count >= PressAttemptLimit:
          "recipient_limit"
        elif pressType == "PublicPressOnly" and recipient != 0:
          "public_only"
        else:
          ""
    if reason.len > 0:
      state.savePressOutcome(result.outcomes, index, "skipped", reason, path)
      logEvent("press_skipped", %*{
        "recipient": recipient, "reason": reason,
        "phase": state.phase.stamp, "draft_index": index,
        "decision_id": memoryDecisionId
      })
      continue
    var latest: JsonNode
    try:
      latest = config.fetchContext()
    except KutuzovError as error:
      for pending in index ..< messages.len:
        state.savePressOutcome(
          result.outcomes, pending, "pending", "context_unavailable", path
        )
      raise error
    let blocked =
      if phaseStamp(latest) != state.phase.stamp:
        "phase_changed"
      elif integer(latest{"game", "processTime"}) - int(epochTime()) < 25:
        "deadline"
      else:
        ""
    if blocked.len > 0:
      for pending in index ..< messages.len:
        state.savePressOutcome(
          result.outcomes, pending, "skipped", blocked, path
        )
        logEvent("press_skipped", %*{
          "recipient": messages[pending]["to"], "reason": blocked,
          "phase": state.phase.stamp, "draft_index": pending,
          "decision_id": memoryDecisionId
        })
      return
    state.phase.sent.add key
    state.savePressOutcome(
      result.outcomes, index, "unconfirmed", "send_outcome_unknown", path
    )
    var sent = false
    try:
      discard config.sendPress(recipient, message["text"].getStr)
      sent = true
    except KutuzovError as error:
      state.savePressOutcome(
        result.outcomes, index, "unconfirmed", "send_error", path
      )
      logError("press_unconfirmed_no_retry", error)
    if sent:
      state.savePressOutcome(
        result.outcomes, index, "confirmed", "confirmed", path
      )
      result.confirmed.add %*{"to": recipient, "text": message["text"]}
      logEvent("press_confirmed", %*{
        "recipient": recipient, "phase": state.phase.stamp,
        "text": message["text"], "draft_index": index,
        "decision_id": memoryDecisionId
      })

proc readyLegacy*(
  game: GameConfig,
  state: var BotState,
  context: JsonNode,
  path, reason: string
): bool =
  ## Finalize a legacy phase without accepting partial failed revisions.
  let
    planned = not state.phase.savedOrders.isNil and
      state.phase.savedOrders.len > 0
    attempt = state.phase.repairView()
    allowDefault = attempt.isNil or attempt.kind == JNull
  var acting = game
  acting.timeoutSeconds = actionTimeout(
    game.timeoutSeconds,
    integer(context{"game", "processTime"}),
    int(epochTime()),
    calls = 6
  )
  let accepted = acting.finishOrdersVerified(
    context, state.phase.savedOrders, allowDefault
  )
  if accepted.isNil:
    return false
  state.phase.ready = true
  state.persist(path)
  logEvent("phase_ready", %*{
    "phase": state.phase.stamp, "reason": reason,
    "orders_verified": planned,
    "default_orders": not planned and accepted.len > 0,
    "calls": state.phase.calls, "orders": accepted,
    "remaining_seconds": integer(context{"game", "processTime"}) -
      int(epochTime())
  })
  true

proc runBot*() =
  ## Run bounded LLM decisions while the upstream launcher owns the websocket.
  let
    game = loadGameConfig()
    model = loadRequestConfig()
    economy = getEnv("KUTUZOV_ECONOMY_MODEL")
    path = getEnv("KUTUZOV_STATE_PATH", getTempDir() / "kutuzov-state.json")
  var
    limits = loadBudgetConfig()
    state = restore(game, path, limits.mode)
    instructions = ""
    board, history, publicMessages, variant: JsonNode
    publicVersion = ""
    failures = 0
  discard modelRates(model.model)
  if economy.len > 0:
    discard modelRates(economy)
  if model.api == ResponsesApi and model.apiKey.len == 0:
    raise newException(
      KutuzovError,
      "OPENAI_API_KEY is required outside hosting"
    )
  logEvent("bot_start", %*{
    "game_id": game.gameId, "country_id": game.countryId,
    "end_year": game.endYear, "scoring": game.scoring,
    "model": model.model, "reasoning": model.reasoningEffort,
    "economy_model": economy,
    "budget_usd": limits.limitUsd, "reserve_usd": limits.reserveUsd,
    "budget_mode": $limits.mode,
    "max_phase_calls": limits.maxPhaseCalls,
    "max_context_bytes": limits.maxContextBytes,
    "state_restored": fileExists(path), "stopped": state.stopped
  })
  while true:
    var failedOrderSave = false
    try:
      let
        context = game.fetchContext()
        phase = context{"game", "phase"}.getStr
        turn = integer(context{"game", "turn"})
        stamp = phaseStamp(context)
        year = 1901 + turn div 2
      if phase == "Finished" or horizonReached(turn, phase, game.endYear):
        logEvent("bot_return", %*{
          "reason": "finished_or_horizon", "phase": stamp,
          "spent_usd": state.budget.budgetSpent
        })
        return
      if context{"member", "status"}.getStr in ["Defeated", "Resigned", "Left"]:
        logEvent("bot_return", %*{
          "reason": context{"member", "status"}, "phase": stamp,
          "spent_usd": state.budget.budgetSpent
        })
        return
      if phase notin ["Diplomacy", "Retreats", "Builds"]:
        sleep(1000)
        continue
      if context{"game", "processStatus"}.getStr == "Paused" or
        integer(context{"game", "processTime"}) <= 0:
          sleep(1000)
          continue
      if stamp != state.phase.stamp:
        state.phase = PhaseState(
          stamp: stamp,
          savedOrders: newJArray(),
          transcript: newJArray()
        )
        state.persist(path)
        board = nil
        logEvent("phase_start", %*{
          "phase": stamp, "year": year,
          "deadline": context{"game", "processTime"},
          "order_slots": context{"orders", "orders"}.len,
          "spent_usd": state.budget.budgetSpent
        })
      if board.isNil:
        let
          currentBoard = game.fetchBoard(context)
          currentHistory = game.fetchFile(context{"files", "history"})
        board = currentBoard
        history = currentHistory
      if instructions.len == 0:
        variant = game.fetchVariant(context)
        instructions = Policy & "\nMAP JSON:\n" & $compactMap(variant)
      let version = $context{"files", "messages"}
      if publicMessages.isNil or version != publicVersion:
        publicMessages = game.fetchFile(context{"files", "messages"})
        publicVersion = version
      let
        slots = context{"orders", "orders"}
        deadline = integer(context{"game", "processTime"})
        remaining = deadline - int(epochTime())
        press = trimPress(
          visiblePress(context, publicMessages, turn),
          game.countryId,
          limits
        )
      if state.phase.ready:
        sleep(1000)
        continue
      let task = state.phase.nextTask(
        phase, press, limits, remaining, model.timeoutSeconds, int(epochTime())
      )
      if slots.isNil or slots.len == 0 or state.stopped or task == "ready":
          discard game.readyLegacy(
            state, context, path, "nothing_to_do_or_resource_limit"
          )
          sleep(1000)
          continue
      if task == "wait":
        sleep(1000)
        continue
      var selected = phaseModel(
        model, economy, limits.mode, task, year == game.endYear, year, phase
      )
      selected.timeoutSeconds = requestTimeout(
        model.timeoutSeconds, deadline, int(epochTime())
      )
      let input = observation(
        game, context, board, history, press, state, limits, task, variant
      )
      let reply = state.infer(
        limits,
        selected,
        instructions,
        input,
        year == game.endYear,
        path,
        economy
      )
      if reply.deferred:
        state.phase.updatesStopped = true
        state.persist(path)
        logEvent("updates_stopped", %*{
          "phase": stamp, "reason": "optional_budget_admission"
        })
        sleep(1000)
        continue
      if reply.text.len == 0:
        discard game.readyLegacy(state, context, path, "inference_skipped")
        continue
      var acting = game
      acting.timeoutSeconds = actionTimeout(
        game.timeoutSeconds, deadline, int(epochTime())
      )
      if phaseStamp(acting.fetchContext()) != stamp:
        logEvent("decision_discarded", %*{
          "phase": stamp, "reason": "phase_changed"
        })
        continue
      let decision = readDecision(reply.text)
      logEvent("decision_parsed", %*{
        "phase": stamp, "task": task, "orders": decision.orders,
        "press": decision.press, "memory": decision.memory,
        "stop_spending": decision.stopSpending,
        "stop_reason": decision.stopReason
      })
      if decision.orders.len == 0:
        raise newException(KutuzovError, "Required orders cannot be empty")
      let finish = phase != "Diplomacy" or decision.stopSpending or
        state.phase.calls >= limits.maxPhaseCalls or
        deadline - int(epochTime()) <= 40
      try:
        state.phase.rejectRepeatedOrders(decision.orders)
        state.phase.savedOrders = acting.saveOrdersVerified(
          context, decision.orders, ready = finish
        )
      except KutuzovError as error:
        failedOrderSave = true
        state.phase.captureRepairAttempt(decision, task, error)
        let outcomes = pressOutcomes(decision.press)
        for outcome in outcomes:
          outcome["status"] = %"skipped"
          outcome["reason"] = %"orders_unverified"
        state.phase.recordExchange(reply.input, reply.text, %*{
          "event": "host_result",
          "orders_verified": false,
          "outcome": state.phase.repairAttempt["outcome"],
          "error": state.phase.repairAttempt{"error", "text"},
          "confirmed_press": [],
          "press_outcomes": outcomes
        }, limits, consumePress = false)
        state.persist(path)
        raise
      state.phase.repairAttempt = nil
      state.phase.ready = finish
      logEvent("orders_verified", %*{
        "phase": stamp, "orders": state.phase.savedOrders,
        "ready": finish, "task": task
      })
      state.phase.feedback = ""
      if task == "review":
        state.phase.reviewed = true
      state.rememberMovement(context, decision.memory, decision.press)
      if decision.stopSpending:
        state.stopped = true
        state.stopReason = decision.stopReason
        logEvent("inference_stopped", %*{"reason": state.stopReason})
      state.phase.pressSignature = press.signature
      state.persist(path)
      let
        memoryDecisionId =
          if phase == "Diplomacy":
            state.memoryDelivery["decision_id"].getStr
          else:
            ""
        delivery = game.dispatchPress(
          context, decision.press, state, path, memoryDecisionId
        )
      state.phase.recordExchange(reply.input, reply.text, %*{
        "event": "host_result",
        "orders_verified": true,
        "saved_orders": state.phase.savedOrders,
        "ready": state.phase.ready,
        "confirmed_press": delivery.confirmed,
        "press_outcomes": delivery.outcomes
      }, limits)
      state.persist(path)
      failures = 0
    except KutuzovHttpError as error:
      logError("game_http", error)
      if error.status in [404, 410] and error.source == PlayerContext:
        logEvent("bot_return", %*{
          "reason": "game_unavailable", "http_status": error.status,
          "request_source": $error.source
        })
        return
      if error.status in [404, 410] and error.source == PublicAsset:
        board = nil
        history = nil
        publicMessages = nil
        publicVersion = ""
      inc failures
    except KutuzovRequestError as error:
      logError("inference_request", error)
      state.persist(path)
      inc failures
    except KutuzovError as error:
      logError("tick", error)
      if not failedOrderSave:
        state.phase.feedback = error.msg[0 ..< min(1600, error.msg.len)]
      state.persist(path)
      inc failures
    if failures > 0:
      logEvent("retry_wait", %*{
        "failures": failures, "milliseconds": min(5000, 500 * failures),
        "phase": state.phase.stamp
      })
      sleep(min(5000, 500 * failures))

