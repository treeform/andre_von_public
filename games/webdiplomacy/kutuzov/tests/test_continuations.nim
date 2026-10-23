import
  std/[json, net, os, strutils, times],
  jsony,
  ../[budgets, common, engines, protocols, requests, wakes]

const
  Sol = "openai/gpt-6.1-sol"
  Luna = "openai/gpt-6-luna"

proc near(actual, expected: float) =
  ## Compare financial values without binary rounding assumptions.
  doAssert abs(actual - expected) < 0.000000001, $actual & " != " & $expected

proc limits(): BudgetConfig =
  ## Match the half-dollar empirical tool-loop experiment.
  result = defaultBudgetConfig()
  result.mode = EmpiricalBudget
  result.toolLoop = true
  result.limitUsd = 0.50
  result.reserveUsd = 0.10
  result.maxPhaseCalls = 12
  result.maxPressCalls = 1

proc config(): RequestConfig =
  ## Build an isolated hosted-format request without live credentials.
  RequestConfig(api: ChatApi, model: Sol, reasoningEffort: "low",
    maxOutputTokens: 3000, cacheKey: "fixture", timeoutSeconds: 20,
    baseUrl: "http://127.0.0.1", apiKey: "fixture-key")

proc answered(model: RequestConfig, ceiling: BudgetConfig): PhaseState =
  ## Record a successful request followed by the exact reply and receipt.
  result.stamp = "5:Diplomacy"
  result.transcript = newJArray()
  result.rememberContinuation(model, "rules", "{}", "reply")
  doAssert result.continuationPacing(
    model, "rules", result.transcript
  ) == OrdinaryRequest
  result.recordExchange("{}", "reply", %*{"results": []}, ceiling)

echo "Testing warm estimates preserve pooled reservations and accounting"
block:
  var budget = Budget(mode: EmpiricalBudget)
  let ceiling = limits()
  near(budget.expectedCost(Sol), 0.020)
  near(budget.expectedCost(Sol, WarmSolContinuation), 0.010)
  near(budget.empiricalCost(Sol), 0.040)
  doAssert budget.reserve(ceiling, 0.040)
  budget.settleKnown(Sol, 0.040, 0.007, WarmSolContinuation)
  near(budget.expectedCost(Sol, WarmSolContinuation), 0.007)
  doAssert budget.warmSolCost.observed == 1
  doAssert budget.reserve(ceiling, 0.040)
  budget.settleKnown(Sol, 0.040, 0.050, WarmSolContinuation)
  near(budget.expectedCost(Sol, WarmSolContinuation), 0.0285)
  near(budget.empiricalCost(Sol), 0.100)
  near(budget.stoppingReserve(ceiling, true, true), 0.100)
  near(budget.spentUsd, 0.057)
  doAssert budget.modelCosts[0].observed == 2
  let before = budget.toJson
  for invalid in [Luna, "unknown-model"]:
    doAssertRaises KutuzovError:
      budget.settleKnown(invalid, 0.0, 0.001, WarmSolContinuation)
    doAssertRaises KutuzovError:
      discard budget.expectedCost(invalid, WarmSolContinuation)
    doAssert budget.toJson == before
  var legacy = parseJson(before)
  legacy.delete("warmSolCost")
  let restored = ($legacy).fromJson(Budget)
  near(restored.expectedCost(Sol, WarmSolContinuation), 0.010)
  near(restored.empiricalCost(Sol), 0.100)

echo "Testing exact-prefix eligibility and invalidation boundaries"
block:
  let
    model = config()
    ceiling = limits()
    phase = answered(model, ceiling)
  doAssert phase.continuationPacing(
    model, "rules", phase.transcript
  ) == WarmSolContinuation
  var changed = model
  changed.timeoutSeconds = 5
  doAssert phase.continuationPacing(
    changed, "rules", phase.transcript
  ) == WarmSolContinuation
  for field in 0 ..< 7:
    changed = model
    case field
    of 0: changed.model = Luna
    of 1: changed.baseUrl = "http://different.invalid"
    of 2: changed.apiKey = "rotated-key"
    of 3: changed.reasoningEffort = "high"
    of 4: changed.maxOutputTokens = 2000
    of 5: changed.cacheKey = "other"
    else: changed.api = ResponsesApi
    doAssert phase.continuationPacing(
      changed, "rules", phase.transcript
    ) == OrdinaryRequest
  doAssert phase.continuationPacing(
    model, "new rules", phase.transcript
  ) == OrdinaryRequest
  doAssert phase.continuationPacing(
    model, "rules", phase.transcript, rebased = true
  ) == OrdinaryRequest
  var edited = phase.transcript.copy()
  edited[0]["content"] = %"changed input"
  doAssert phase.continuationPacing(model, "rules", edited) == OrdinaryRequest
  edited = phase.transcript.copy()
  edited.add %*{"role": "user", "content": "unrecorded extra exchange"}
  doAssert phase.continuationPacing(model, "rules", edited) == OrdinaryRequest
  var switched = answered(changed, ceiling)
  doAssert switched.continuationPacing(
    model, "rules", switched.transcript
  ) == OrdinaryRequest
  switched = phase
  switched.stamp = "6:Diplomacy"
  doAssert switched.continuationPacing(
    model, "rules", switched.transcript
  ) == OrdinaryRequest
  switched = phase
  switched.clearContinuation()
  doAssert switched.continuationPacing(
    model, "rules", switched.transcript
  ) == OrdinaryRequest
  switched = PhaseState(stamp: "5:Diplomacy", transcript: newJArray())
  switched.rememberContinuation(model, "rules", "{}", "reply")
  switched.recordExchange("{}", "different reply", %*{}, ceiling)
  doAssert switched.continuationPacing(
    model, "rules", switched.transcript
  ) == OrdinaryRequest
  switched = phase
  var tiny = ceiling
  tiny.maxContextBytes = 1
  switched.recordExchange("{}", "reply", %*{}, tiny)
  doAssert switched.transcript.len == 0
  doAssert switched.continuationTranscript.len == 0
  let path = getTempDir() / ("kutuzov-continuation-restore-" &
    $getCurrentProcessId() & ".json")
  defer:
    if fileExists(path):
      removeFile(path)
  let state = BotState(gameId: 81, countryId: 5, toolLoop: true,
    budget: Budget(mode: EmpiricalBudget), phase: phase)
  state.persist(path)
  let loaded = restore(GameConfig(gameId: 81, countryId: 5), path,
    EmpiricalBudget, toolLoop = true)
  doAssert loaded.phase.transcript == phase.transcript
  doAssert loaded.phase.continuationPacing(
    model, "rules", loaded.phase.transcript
  ) == OrdinaryRequest

echo "Testing captured Austria pacing without relaxing global reservation"
block:
  var budget = Budget(mode: EmpiricalBudget, spentUsd: 0.154703885)
  budget.modelCosts[0] = ModelCost(observed: 4,
    meanUsd: 0.021376028125, largestUsd: 0.030901)
  let
    ceiling = limits()
    model = config()
    cold = chooseCall(model, budget, ceiling, "rules", "{}",
      phaseSpentUsd = 0.018028715, phaseAllowanceUsd = 0.029258314444)
    warm = chooseCall(model, budget, ceiling, "rules", "{}",
      phaseSpentUsd = 0.018028715, phaseAllowanceUsd = 0.029258314444,
      pacing = WarmSolContinuation)
  doAssert cold.fallback and cold.preferredDenial == "phase_pacing"
  doAssert warm.allowed and not warm.fallback and warm.config.model == Sol
  near(warm.reservedUsd, 0.061802)
  near(warm.expectedUsd, 0.010)
  budget.spentUsd = 0.35
  let tight = chooseCall(model, budget, ceiling, "rules", "{}",
    phaseAllowanceUsd = 1.0, pacing = WarmSolContinuation)
  doAssert tight.fallback and tight.preferredDenial == "global_reservation"
  var expensive = budget
  expensive.warmSolCost = ModelCost(observed: 1, meanUsd: 0.050,
    largestUsd: 0.050)
  let denied = chooseCall(model, expensive, ceiling, "rules", "{}",
    phaseAllowanceUsd = 0.040, optionalCall = true,
    pacing = WarmSolContinuation)
  doAssert not denied.allowed and denied.denial == "phase_pacing"

proc serve(args: tuple[server: Socket, fail: bool]) {.thread.} =
  ## Serve two real inference requests while checking their exact prefix.
  defer:
    args.server.close()
  var
    calls = 0
    previous: JsonNode
  while calls < 2:
    var client: Socket
    args.server.accept(client)
    defer:
      client.close()
    let line = client.recvLine(timeout = 5000)
    var length = 0
    while true:
      let header = client.recvLine(timeout = 2000)
      if header.len == 0 or header == "\r\n":
        break
      if header.toLowerAscii.startsWith("content-length:"):
        length = parseInt(header.split(':', 1)[1].strip())
    var body = ""
    while body.len < length:
      body.add client.recv(length - body.len, timeout = 2000)
    var
      response: JsonNode
      status = "200 OK"
    if line.startsWith("GET /spend "):
      response = %*{"spend_usd": 0.137703885, "spend_limit_usd": 0.50}
    else:
      doAssert line.startsWith("POST /v1/chat/completions "), line
      let payload = body.fromJson(JsonNode)
      doAssert payload["model"].getStr == Sol
      if calls == 0:
        previous = payload["messages"].copy()
      else:
        doAssert payload["messages"].len == previous.len + 3
        for i in 0 ..< previous.len:
          doAssert payload["messages"][i] == previous[i]
        doAssert payload["messages"][^2]["content"].getStr == "{\"results\":[]}"
      inc calls
      response = %*{"choices": [{"finish_reason": "stop", "message": {
        "role": "assistant", "content": "{\"calls\":[]}"}}],
        "usage": {"prompt_tokens": 0,
          "completion_tokens": (if calls == 1: 1700 else: 700)}}
      if calls == 2 and args.fail:
        status = "500 Internal Server Error"
        response = %*{"error": {"message": "Fixture model failure"}}
    let encoded = $response
    client.send("HTTP/1.1 " & status & "\r\nContent-Type: application/json\r\n" &
      "Connection: close\r\nContent-Length: " & $encoded.len &
      "\r\n\r\n" & encoded)

proc checkInference(failure: bool) =
  ## Exercise actual admission, HTTP completion, settlement and failure reset.
  let
    ceiling = limits()
    server = newSocket()
    path = getTempDir() / ("kutuzov-continuation-runtime-" &
      $getCurrentProcessId() & ".json")
  defer:
    if fileExists(path):
      removeFile(path)
  server.bindAddr(Port(0), "127.0.0.1")
  server.listen()
  var
    model = config()
    settings = ceiling
    state = BotState(gameId: 81, countryId: 5, toolLoop: true,
      budget: Budget(mode: EmpiricalBudget, spentUsd: 0.137703885),
      phase: PhaseState(stamp: "5:Diplomacy", transcript: newJArray(),
        costUsd: 0.001028715, allowanceSet: true,
        allowanceUsd: 0.029258314444))
  model.baseUrl = "http://127.0.0.1:" & $server.getLocalAddr()[1]
  state.budget.modelCosts[0] = ModelCost(observed: 3,
    meanUsd: 0.02575205625, largestUsd: 0.030901)
  state.phase.wake.count = 1
  doAssert state.phase.wake.startWake(defaultWakeConfig(), ReviewWake,
    int(epochTime()), int(epochTime()) + 180)
  let input = %*{
    "turn": 5, "end_year": 1908, "year": 1903, "season": "autumn",
    "phase": "Diplomacy", "task": "review", "order_slots": [],
    "saved_orders": [], "press": [], "omitted_messages": 0,
    "outgoing_press": [], "memory": "", "memory_phase": "",
    "memory_delivery": nil, "repair_feedback": "", "remaining_usd": 0.25,
    "final_year_reserve_usd": 0.10, "remaining_phase_calls": 10,
    "reviewed": false, "updates_stopped": false, "remaining_updates": 1,
    "deadline_unix": int(epochTime()) + 180, "seconds_left": 180
  }
  var worker: Thread[tuple[server: Socket, fail: bool]]
  createThread(worker, serve, (server, failure))
  let first = state.infer(settings, model, "rules", input, false, path, Luna,
    toolStep = true, reviewModelName = Sol)
  doAssert first.model == Sol
  near(state.phase.costUsd, 0.018028715)
  state.phase.recordExchange(first.input, first.text, %*{"results": []}, ceiling)
  if failure:
    doAssertRaises KutuzovRequestError:
      discard state.infer(settings, model, "rules", input, false, path, Luna,
        toolStep = true, reviewModelName = Sol)
    doAssert state.phase.continuationPacing(
      model, "rules", state.phase.transcript
    ) == OrdinaryRequest
    doAssert state.budget.warmSolCost.observed == 0
    doAssert state.budget.uncertainCalls == 1
  else:
    let second = state.infer(settings, model, "rules", input, false, path, Luna,
      toolStep = true, reviewModelName = Sol)
    doAssert second.model == Sol and second.text.len > 0
    doAssert state.budget.warmSolCost.observed == 1
    near(state.budget.warmSolCost.meanUsd, 0.007)
    near(state.budget.spentUsd, 0.161703885)
  joinThread(worker)
  near(state.budget.empiricalCost(Sol), 0.061802)
  doAssert state.budget.reservedUsd == 0.0
  doAssert state.phase.calls == 2

echo "Testing real two-step Sol continuation across admission and settlement"
checkInference(false)
echo "Testing failed continuation invalidates the process-local predecessor"
checkInference(true)

echo "Continuation tests passed"
