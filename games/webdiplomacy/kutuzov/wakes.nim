import common

const
  MaximumWakeRequests* = 4
  MaximumMovementWakes* = 3
  MaximumWakeSeconds* = 120
  MinimumSaveSeconds* = 30

type
  WakeKind* = enum
    NoWake, InitialWake, PressWake, ReviewWake, RepairWake

  WakeEnd* = enum
    ModelFinished, TimeLimit, RequestLimit, BudgetLimit, PhaseChanged

  WakeConfig* = object
    maxRequests*, maxWakes*, durationSeconds*: int
    quietSeconds*, maxDebounceSeconds*, saveSeconds*: int

  WakeState* = object
    active*, completed*, reviewed*, reviewStarted*, pressUsed*: bool
    kind*: WakeKind
    ending*: WakeEnd
    calls*, totalCalls*, count*: int
    startedAt*, deadline*: int
    pendingSignature*: string
    firstAt*, changedAt*: int

proc defaultWakeConfig*(): WakeConfig {.raises: [].} =
  ## Return the verified movement cadence with time reserved for saving.
  WakeConfig(
    maxRequests: MaximumWakeRequests,
    maxWakes: MaximumMovementWakes,
    durationSeconds: MaximumWakeSeconds,
    quietSeconds: 20,
    maxDebounceSeconds: 40,
    saveSeconds: MinimumSaveSeconds
  )

proc validate*(config: WakeConfig) {.raises: [KutuzovError].} =
  ## Reject settings that expand the request, wake, or action-time limits.
  if config.maxRequests < 1 or config.maxRequests > MaximumWakeRequests or
    config.maxWakes < 1 or config.maxWakes > MaximumMovementWakes or
    config.durationSeconds < 1 or
    config.durationSeconds > MaximumWakeSeconds or
    config.quietSeconds < 0 or
    config.maxDebounceSeconds < config.quietSeconds or
    config.maxDebounceSeconds > MaximumWakeSeconds or
    config.saveSeconds < MinimumSaveSeconds:
      raise newException(KutuzovError, "Invalid bounded wake configuration")

proc validateClock(now, phaseDeadline: int) {.raises: [KutuzovError].} =
  ## Require nonnegative explicit timestamps without consulting a real clock.
  if now < 0 or phaseDeadline < 0:
    raise newException(KutuzovError, "Wake timestamps must be nonnegative")

proc remainingSeconds*(
  state: WakeState,
  config: WakeConfig,
  now, phaseDeadline: int
): int {.raises: [KutuzovError].} =
  ## Bound active inference time by the wake and the current phase deadline.
  config.validate()
  validateClock(now, phaseDeadline)
  if not state.active or now < state.startedAt:
    return 0
  max(0, min(state.deadline, phaseDeadline - config.saveSeconds) - now)

proc finishWake*(
  state: var WakeState,
  reason = ModelFinished
) {.raises: [].} =
  ## End this wake without disabling a later scheduled review or repair.
  if not state.active:
    return
  state.active = false
  state.completed = reason == ModelFinished
  state.ending = reason
  if state.kind == ReviewWake and state.completed:
    state.reviewed = true

proc canStart(state: WakeState, config: WakeConfig, kind: WakeKind): bool
    {.raises: [].} =
  ## Reserve the final optional slot for review while bounding required wakes.
  if state.active or state.count >= config.maxWakes or
    state.totalCalls >= config.maxRequests * config.maxWakes:
      return false
  case kind
  of NoWake:
    false
  of InitialWake:
    state.count == 0
  of PressWake:
    state.count > 0 and not state.pressUsed and not state.reviewStarted and
      state.count < config.maxWakes - 1
  of ReviewWake:
    state.count > 0 and not state.reviewStarted
  of RepairWake:
    true

proc startWake*(
  state: var WakeState,
  config: WakeConfig,
  kind: WakeKind,
  now, phaseDeadline: int
): bool {.raises: [KutuzovError].} =
  ## Start one bounded wake only when its model requests can leave save time.
  config.validate()
  validateClock(now, phaseDeadline)
  if not state.canStart(config, kind) or
    phaseDeadline - now <= config.saveSeconds:
      return false
  state.deadline =
    if phaseDeadline - now > config.durationSeconds + config.saveSeconds:
      now + config.durationSeconds
    else:
      phaseDeadline - config.saveSeconds
  state.active = true
  state.completed = false
  state.kind = kind
  state.calls = 0
  state.startedAt = now
  inc state.count
  if kind == PressWake:
    state.pressUsed = true
  if kind == ReviewWake:
    state.reviewStarted = true
  true

proc takeRequest*(
  state: var WakeState,
  config: WakeConfig,
  now, phaseDeadline: int
): bool {.raises: [KutuzovError].} =
  ## Count one admitted model request before transport, including failures.
  config.validate()
  validateClock(now, phaseDeadline)
  if not state.active:
    return false
  if state.remainingSeconds(config, now, phaseDeadline) == 0:
    state.finishWake(TimeLimit)
    return false
  if state.calls >= config.maxRequests or
    state.totalCalls >= config.maxRequests * config.maxWakes:
      state.finishWake(RequestLimit)
      return false
  inc state.calls
  inc state.totalCalls
  true

proc observePress(state: var WakeState, signature: string, now: int)
    {.raises: [].} =
  ## Debounce only caller-supplied unread press without retaining its contents.
  if signature.len == 0:
    state.pendingSignature = ""
    state.firstAt = 0
    state.changedAt = 0
  elif state.pendingSignature.len == 0:
    state.pendingSignature = signature
    state.firstAt = now
    state.changedAt = now
  elif state.pendingSignature != signature:
    state.pendingSignature = signature
    state.changedAt = now

proc nextWake*(
  state: var WakeState,
  config: WakeConfig,
  now, phaseDeadline: int,
  hasOrders, needsRepair: bool,
  unreadSignature: string,
  reviewDue: bool
): WakeKind {.raises: [KutuzovError].} =
  ## Select required work, a due review, or one debounced press wake.
  config.validate()
  validateClock(now, phaseDeadline)
  state.observePress(unreadSignature, now)
  if state.active:
    if state.remainingSeconds(config, now, phaseDeadline) == 0:
      state.finishWake(TimeLimit)
    elif state.calls >= config.maxRequests:
      state.finishWake(RequestLimit)
    else:
      return NoWake
  if phaseDeadline - now <= config.saveSeconds:
    return NoWake
  let required =
    if needsRepair:
      RepairWake
    elif state.count == 0:
      InitialWake
    elif not hasOrders:
      RepairWake
    else:
      NoWake
  if required != NoWake:
    if state.canStart(config, required):
      return required
    return NoWake
  if reviewDue and state.canStart(config, ReviewWake):
    return ReviewWake
  let settled = state.pendingSignature.len > 0 and
    (now - state.changedAt >= config.quietSeconds or
    now - state.firstAt >= config.maxDebounceSeconds)
  if settled and state.canStart(config, PressWake):
    return PressWake
  NoWake

proc requiresCenterCheck*(finalYear, autumn: bool): bool {.raises: [].} =
  ## Require the center-horizon check before initial or later commits alike.
  finalYear or autumn
