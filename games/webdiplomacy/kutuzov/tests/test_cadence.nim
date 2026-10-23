import
  std/[json, net, os, strutils, times],
  jsony,
  ../[budgets, engines, logs, protocols, requests]

const
  SeatSecret = "local-cadence-fixture-seat"
  OldMemory = "Preserve the negotiated Rome defense until the review."
  NewMemory = "Reviewed the new offer and retained the Rome defense."
  SeenPress = "previously-consumed-fixture-message"
  ContextRoute = "/api.php?route=game/playercontext&gameID=703" &
    "&orders=1&messages=1"
  EnvironmentNames = [
    "WEBDIP_URL", "WEBDIP_API_KEY", "WEBDIP_GAME_ID", "WEBDIP_COUNTRY_ID",
    "WEBDIP_END_YEAR", "WEBDIP_SCORING", "OPENAI_API_KEY", "OPENAI_BASE_URL",
    "COWORLD_LLM_ENDPOINT", "COWORLD_LLM_MODEL", "KUTUZOV_MODEL",
    "AWS_ENDPOINT_URL_BEDROCK_RUNTIME", "BEDROCK_MODEL", "KUTUZOV_REASONING",
    "KUTUZOV_TIMEOUT_SECONDS", "KUTUZOV_MAX_OUTPUT_TOKENS",
    "KUTUZOV_GAME_TIMEOUT_SECONDS", "KUTUZOV_STATE_PATH",
    "KUTUZOV_BUDGET_USD", "KUTUZOV_RESERVE_USD", "KUTUZOV_BUDGET_MODE",
    "KUTUZOV_PRESS_MODEL", "KUTUZOV_ECONOMY_MODEL",
    "KUTUZOV_MAX_PHASE_CALLS", "KUTUZOV_MAX_PRESS_CALLS",
    "KUTUZOV_MAX_PRESS_CHARACTERS", "KUTUZOV_MAX_OPPONENT_CHARACTERS",
    "KUTUZOV_MAX_MESSAGE_CHARACTERS", "KUTUZOV_MAX_MESSAGES_PER_OPPONENT",
    "KUTUZOV_MAX_CONTEXT_BYTES"
  ]

type
  CadenceCase = enum
    DeferredReview, RequiredFallback, FundedPlan

  Scenario = tuple[server: Socket, path: string, kind: CadenceCase]

proc near(actual, expected: float) =
  ## Compare accounting without exact binary decimal equality.
  doAssert abs(actual - expected) < 0.000000001

proc settings(): BudgetConfig =
  ## Match the empirical half-dollar limit and reserved final-year funds.
  result = defaultBudgetConfig()
  result.mode = EmpiricalBudget
  result.limitUsd = 0.50
  result.reserveUsd = 0.10

proc request(): RequestConfig =
  ## Describe the primary model for pure admission checks.
  RequestConfig(
    api: ChatApi, model: DefaultHostedModel, reasoningEffort: "low",
    timeoutSeconds: 45, maxOutputTokens: 3000
  )

proc orders(): JsonNode =
  ## Supply one valid existing order that optional deferral must preserve.
  %*[{"type": "Hold", "terrID": 1, "toTerrID": 0,
    "fromTerrID": 0, "viaConvoy": "No"}]

proc newPress(): JsonNode =
  ## Supply an unread offer with stable sender, recipient and phase labels.
  %*[{
    "fromCountryID": 1, "toCountryID": 3, "turn": 2,
    "phase": "Diplomacy", "message": "Please keep the agreed Rome defense."
  }]

proc decision(memory: string): JsonNode =
  ## Return a complete model decision without outgoing press or a stop request.
  %*{"orders": orders(), "press": [], "memory": memory,
    "stop_spending": false, "stop_reason": ""}

proc transcript(): JsonNode =
  ## Represent a previously verified plan without the newly arrived offer.
  %*[
    {"role": "user", "content": "{\"task\":\"plan\",\"press\":[]}"},
    {"role": "assistant", "content": $decision(OldMemory)},
    {"role": "user", "content": "{\"orders_verified\":true}"}
  ]

proc context(remaining: int, ready: bool): JsonNode =
  ## Advance the deadline into the review window after optional deferral.
  %*{
    "game": {"turn": 2,
      "phase": (if ready: "Finished" else: "Diplomacy"),
      "processTime": int(epochTime()) + remaining, "pressType": "Regular"},
    "member": {"status": "Playing"}, "orders": {"orders": orders()},
    "messages": {"messages": newPress()},
    "files": {
      "game": {"url": "board.json", "version": "1"},
      "history": {"url": "history.json", "version": "1"},
      "messages": {"url": "messages.json", "version": "1"},
      "variant": {"url": "variant.json", "version": "1"}
    }
  }

proc board(): JsonNode =
  ## Supply matching public board data for the existing order.
  %*{
    "turn": 2, "phase": "Diplomacy", "units": [
      {"id": 1, "type": "Army", "terrID": 1, "countryID": 3}],
    "territories": [{"id": 1, "ownerCountryID": 3, "occupiedBy": 3}],
    "members": [{"countryID": 3, "status": "Playing", "supplyCenterNo": 1}]
  }

proc variant(): JsonNode =
  ## Supply enough named map data for normal production prompting.
  %*{
    "name": "Local fixture", "countries": [
      {"id": 1, "name": "England"}, {"id": 3, "name": "Italy"}],
    "territories": [{"id": 1, "name": "Rome", "type": "Land",
      "supply": "Yes", "homeCountryID": 3, "coast": "No",
      "coastParentID": 0, "borders": [], "coastalBorders": []}]
  }

proc checkDeferral(path: string) =
  ## Prove an unaffordable optional update leaves decisions and input intact.
  let
    state = readFile(path).fromJson(BotState)
    press = trimPress(newPress(), 3, settings())
  doAssert state.phase.calls == 1 and state.phase.pressCalls == 0
  doAssert state.phase.updatesStopped and not state.phase.reviewed
  doAssert not state.phase.ready and not state.stopped
  doAssert state.phase.savedOrders == orders()
  doAssert state.memory == OldMemory and state.memoryStamp == "2:Diplomacy"
  doAssert state.phase.transcript == transcript()
  doAssert state.phase.seenPress == @[SeenPress]
  doAssert state.phase.unreadPress(press.messages).len == 1
  near(state.budget.spentUsd, 0.35)
  near(state.budget.reservedUsd, 0.0)
  near(state.budget.uncertainUsd, 0.0)
  near(state.phase.costUsd, 0.01)

proc serve(args: Scenario) {.thread.} =
  ## Require zero optional calls and one later Sol review over local HTTP.
  defer:
    args.server.close()
  var
    reads, spends, models, saves, requests = 0
    ready, deferred = false
  while true:
    inc requests
    doAssert requests <= 24
    var client: Socket
    args.server.accept(client)
    defer:
      client.close()
    let line = client.recvLine(timeout = 2000)
    var
      authorization = ""
      length = 0
    while true:
      let header = client.recvLine(timeout = 2000)
      if header.len == 0 or header == "\r\n":
        break
      if header.toLowerAscii.startsWith("authorization:"):
        authorization = header.split(':', 1)[1].strip()
      if header.toLowerAscii.startsWith("content-length:"):
        length = parseInt(header.split(':', 1)[1].strip())
    var body = ""
    while body.len < length:
      let chunk = client.recv(length - body.len, timeout = 2000)
      doAssert chunk.len > 0
      body.add(chunk)
    var
      response = newJObject()
      finished = false
    if line == "GET " & ContextRoute & " HTTP/1.1":
      inc reads
      doAssert authorization == "Bearer " & SeatSecret
      if reads == 2 and args.kind == DeferredReview:
        doAssert spends == 1 and models == 0 and saves == 0
        checkDeferral(args.path)
        deferred = true
      let remaining =
        if reads == 1: 100
        elif saves > 0: 35
        else: 60
      finished = ready or (args.kind != DeferredReview and saves > 0)
      response = context(remaining, finished)
    elif line.startsWith("GET /board.json?"):
      doAssert authorization.len == 0
      response = board()
    elif line.startsWith("GET /history.json?"):
      doAssert authorization.len == 0
      response = %*{"phases": []}
    elif line.startsWith("GET /variant.json?"):
      doAssert authorization.len == 0
      response = variant()
    elif line.startsWith("GET /messages.json?"):
      doAssert authorization.len == 0
      response = %*{"messages": []}
    elif line == "GET /spend HTTP/1.1":
      inc spends
      doAssert authorization.len == 0
      response = %*{
        "spend_usd": (
          case args.kind
          of DeferredReview: 0.35
          of RequiredFallback: 0.395
          of FundedPlan: 0.02
        ),
        "spend_limit_usd": 0.50
      }
    elif line == "POST /v1/chat/completions HTTP/1.1":
      inc models
      doAssert models == 1
      if args.kind != DeferredReview:
        doAssert spends == 1
      else:
        doAssert deferred and spends == 2
      doAssert authorization == "Bearer coworld"
      let
        payload = body.fromJson(JsonNode)
        messages = payload["messages"]
        input = messages[messages.len - 1]["content"].getStr.fromJson(JsonNode)
      if args.kind != DeferredReview:
        let expectedModel =
          if args.kind == FundedPlan: DefaultHostedModel
          else: "openai/gpt-6-luna"
        doAssert payload["model"].getStr == expectedModel
        doAssert input["task"].getStr == "plan"
        doAssert input["press"] == newPress()
        doAssert input["saved_orders"].len == 0
        doAssert input["memory"].getStr.len == 0
      else:
        doAssert payload["model"].getStr == DefaultHostedModel
        doAssert input["task"].getStr == "review"
        doAssert input["new_press"] == newPress()
        doAssert input["saved_orders"] == orders()
        doAssert input["memory"].getStr == OldMemory
      response = %*{
        "choices": [{"finish_reason": "stop", "message": {
          "role": "assistant", "content": $decision(NewMemory)
        }}],
        "usage": {"prompt_tokens": 100, "completion_tokens": 10,
          "prompt_tokens_details": {"cached_tokens": 0}}
      }
    elif line == "POST /api.php?route=game/orders HTTP/1.1":
      inc saves
      doAssert authorization == "Bearer " & SeatSecret
      doAssert models == 1 and saves <= 2
      let payload = body.fromJson(JsonNode)
      if saves == 1:
        doAssert payload["orders"] == orders()
        doAssert payload["ready"].getStr == "No"
        response = orders()
      else:
        doAssert payload["orders"].len == 0
        doAssert payload["ready"].getStr == "Yes"
        ready = true
        response = orders()
    else:
      doAssert false, "Unexpected local cadence request: " & line
    let encoded = $response
    client.send(
      "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n" &
      "Connection: close\r\nContent-Length: " & $encoded.len &
      "\r\n\r\n" & encoded
    )
    if finished:
      doAssert models == 1
      if args.kind != DeferredReview:
        doAssert spends == 1 and saves == 1
      else:
        doAssert deferred and spends == 2 and saves == 2
      return

proc testOptionalAfterReview() =
  ## Reject unaffordable optional updates without paying for an economy model.
  let
    config = settings()
    model = request()
    empty = Budget(mode: EmpiricalBudget)
    tight = Budget(mode: EmpiricalBudget, spentUsd: 0.365)
    budgetLimited = chooseCall(
      model, tight, config, "rules", "{}",
      economyModel = "gpt-6-luna", phaseAllowanceUsd = 0.10,
      optionalCall = true
    )
    paceLimited = chooseCall(
      model, empty, config, "rules", "{}",
      economyModel = "gpt-6-luna", phaseSpentUsd = 0.012,
      phaseAllowanceUsd = 0.025, optionalCall = true
    )
    affordable = chooseCall(
      model, empty, config, "rules", "{}",
      economyModel = "gpt-6-luna", phaseSpentUsd = 0.001,
      phaseAllowanceUsd = 0.05, optionalCall = true
    )
  doAssert not budgetLimited.allowed
  doAssert not paceLimited.allowed
  doAssert affordable.allowed and not affordable.fallback
  doAssert affordable.config.model == DefaultHostedModel

proc testRuntime(kind: CadenceCase) =
  ## Exercise optional deferral or a required opening through the real runtime.
  var saved: seq[tuple[name, value: string, present: bool]]
  for name in EnvironmentNames:
    saved.add((name, getEnv(name), existsEnv(name)))
    delEnv(name)
  defer:
    for entry in saved:
      if entry.present:
        putEnv(entry.name, entry.value)
      else:
        delEnv(entry.name)
  let
    path = getTempDir() / "kutuzov-cadence-" & $kind & "-" &
      $getCurrentProcessId() & ".json"
    server = newSocket()
    press = trimPress(newPress(), 3, settings())
    previous = BotState(
      gameId: 703, countryId: 3,
      budget: Budget(mode: EmpiricalBudget, spentUsd: 0.35,
        authoritativeSpentUsd: 0.35),
      phase: PhaseState(
        stamp: "2:Diplomacy", calls: 1, savedOrders: orders(),
        transcript: transcript(), seenPress: @[SeenPress],
        pendingSignature: press.signature,
        pressFirstAt: int(epochTime()) - 30,
        pressChangedAt: int(epochTime()) - 30,
        costUsd: 0.01, allowanceUsd: 0.10, allowanceSet: true
      ),
      memory: OldMemory, memoryStamp: "2:Diplomacy"
    )
  if fileExists(path):
    removeFile(path)
  defer:
    if fileExists(path):
      removeFile(path)
  if kind == DeferredReview:
    previous.persist(path)
  elif kind == FundedPlan:
    var funded = BotState(
      gameId: 703, countryId: 3,
      budget: Budget(mode: EmpiricalBudget, spentUsd: 0.02,
        authoritativeSpentUsd: 0.02),
      phase: PhaseState(stamp: "2:Diplomacy",
        savedOrders: newJArray(), transcript: newJArray())
    )
    funded.budget.modelCosts[0] = ModelCost(
      meanUsd: 0.01, largestUsd: 0.01, observed: 1
    )
    funded.persist(path)
  server.bindAddr(Port(0), "127.0.0.1")
  server.listen()
  let endpoint = "http://127.0.0.1:" & $server.getLocalAddr()[1]
  putEnv("WEBDIP_URL", endpoint)
  putEnv("WEBDIP_API_KEY", SeatSecret)
  putEnv("WEBDIP_GAME_ID", "703")
  putEnv("WEBDIP_COUNTRY_ID", "3")
  putEnv("WEBDIP_END_YEAR", "1908")
  putEnv("COWORLD_LLM_ENDPOINT", endpoint)
  putEnv("COWORLD_LLM_MODEL", DefaultHostedModel)
  putEnv("KUTUZOV_STATE_PATH", path)
  putEnv("KUTUZOV_MAX_OUTPUT_TOKENS", "3000")
  putEnv("KUTUZOV_ECONOMY_MODEL", "gpt-6-luna")
  putEnv("KUTUZOV_BUDGET_MODE", "empirical")
  putEnv("KUTUZOV_BUDGET_USD", "0.50")
  putEnv("KUTUZOV_RESERVE_USD", "0.10")
  var worker: Thread[Scenario]
  createThread(worker, serve, (server, path, kind))
  runBot()
  joinThread(worker)
  let state = restore(loadGameConfig(), path, EmpiricalBudget)
  doAssert state.phase.pressCalls == 0 and not state.stopped
  doAssert state.phase.savedOrders == orders()
  doAssert state.memory == NewMemory and state.memoryStamp == "2:Diplomacy"
  doAssert state.phase.unreadPress(press.messages).len == 0
  near(state.budget.reservedUsd, 0.0)
  near(state.budget.uncertainUsd, 0.0)
  case kind
  of RequiredFallback:
    doAssert state.phase.calls == 1
    doAssert not state.phase.reviewed and not state.phase.ready
    near(state.budget.spentUsd, 0.3950175)
    doAssert state.budget.modelCosts[0].observed == 0
    doAssert state.budget.modelCosts[1].observed == 1
  of FundedPlan:
    doAssert state.phase.calls == 1
    doAssert not state.phase.reviewed and not state.phase.ready
    near(state.phase.allowanceUsd, 0.38 / 12.0)
    near(state.budget.spentUsd, 0.02035)
    doAssert state.budget.modelCosts[0].observed == 2
    doAssert state.budget.modelCosts[1].observed == 0
  of DeferredReview:
    doAssert state.phase.calls == 2
    doAssert state.phase.reviewed and state.phase.ready
    doAssert SeenPress in state.phase.seenPress
    near(state.budget.spentUsd, 0.35035)
    doAssert state.budget.modelCosts[0].observed == 1
    doAssert state.budget.modelCosts[1].observed == 0

echo "Testing optional updates retain Sol and preserve the later review"
configureLogs("")
testOptionalAfterReview()
testRuntime(DeferredReview)
echo "Testing required 1902 fallback still saves a complete decision"
testRuntime(RequiredFallback)
echo "Testing funded 1902 initial planning uses Sol"
testRuntime(FundedPlan)
echo "Cadence tests passed"
