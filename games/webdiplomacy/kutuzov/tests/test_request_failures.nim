import
  std/[json, net, os, strutils, times],
  jsony,
  ../[budgets, engines, logs, protocols, requests]

const
  SeatSecret = "local-request-fixture-seat"
  RealFeedback = "Server changed orders. Requested: Move; saved: Hold."
  ContextRoute = "/api.php?route=game/playercontext&gameID=702" &
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
  Fault = enum
    HttpFailure, HttpHeaderFailure, TransportFailure, RefusalFailure,
    IncompleteFailure,
    DecisionFailure, SpendHttpFailure, SpendJsonFailure, SpendRealFeedbackFailure

  Scenario = tuple[server: Socket, fault: Fault, deadline: int]

proc near(actual, expected: float) =
  ## Compare monetary accounting without exact binary decimal equality.
  doAssert abs(actual - expected) < 0.000000001

proc context(deadline: int, ready: bool): JsonNode =
  ## Keep one movement phase active until the bot marks default orders Ready.
  %*{
    "game": {"turn": 0,
      "phase": (if ready: "Finished" else: "Diplomacy"),
      "processTime": deadline, "pressType": "Regular"},
    "member": {"status": "Playing"},
    "orders": {"orders": [{"type": "Hold", "terrID": 1,
      "toTerrID": 0, "fromTerrID": 0, "viaConvoy": "No"}]},
    "messages": {"messages": []},
    "files": {
      "game": {"url": "board.json", "version": "1"},
      "history": {"url": "history.json", "version": "1"},
      "messages": {"url": "messages.json", "version": "1"},
      "variant": {"url": "variant.json", "version": "1"}
    }
  }

proc board(): JsonNode =
  ## Supply one required unit on a complete small local board.
  %*{
    "turn": 0, "phase": "Diplomacy", "units": [
      {"id": 1, "type": "Army", "terrID": 1, "countryID": 3}],
    "territories": [{"id": 1, "ownerCountryID": 3, "occupiedBy": 3}],
    "members": [{"countryID": 3, "status": "Playing", "supplyCenterNo": 1}]
  }

proc variant(): JsonNode =
  ## Supply the static names and borders required by production prompting.
  %*{
    "name": "Local fixture", "countries": [{"id": 3, "name": "Italy"}],
    "territories": [{"id": 1, "name": "Rome", "type": "Land",
      "supply": "Yes", "homeCountryID": 3, "coast": "No",
      "coastParentID": 0, "borders": [], "coastalBorders": []}]
  }

proc requestFault(fault: Fault): bool =
  ## Identify unavailable inference or spend requests without valid decisions.
  fault in [HttpFailure, HttpHeaderFailure, TransportFailure,
    SpendHttpFailure, SpendJsonFailure, SpendRealFeedbackFailure]

proc expectedTask(fault: Fault, call: int): string =
  ## Keep request retries on their task and preserve genuine repair feedback.
  if fault == SpendRealFeedbackFailure:
    "repair"
  elif requestFault(fault) or call == 1:
    "plan"
  else:
    "repair"

proc expectedModel(fault: Fault, call: int): string =
  ## Require admission behavior after the preceding failed attempt.
  if fault == SpendRealFeedbackFailure:
    if call == 1:
      DefaultHostedModel
    else:
      "openai/gpt-6-luna"
  elif requestFault(fault) or call == 1:
    "openai/gpt-6-luna"
  else:
    DefaultHostedModel

proc completion(fault: Fault): JsonNode =
  ## Retain billable usage for semantic errors in otherwise valid HTTP replies.
  result = %*{
    "choices": [{"finish_reason": "stop", "message": {
      "role": "assistant", "content": "{malformed-decision"
    }}],
    "usage": {"prompt_tokens": 100, "completion_tokens": 10,
      "prompt_tokens_details": {"cached_tokens": 0}}
  }
  case fault
  of RefusalFailure:
    result["choices"][0]["message"]["refusal"] = %"Fixture refusal."
  of IncompleteFailure:
    result["choices"][0]["finish_reason"] = %"length"
  else:
    discard

proc serve(args: Scenario) {.thread.} =
  ## Exercise real request routing using loopback responses and no provider.
  defer:
    args.server.close()
  var
    ready = false
    models, spends, actions, requests = 0
    trace = newJArray()
  while true:
    inc requests
    doAssert requests <= 40
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
      status = 200
      raw = ""
      extraHeaders = ""
      finished = false
    if line == "GET " & ContextRoute & " HTTP/1.1":
      doAssert authorization == "Bearer " & SeatSecret
      response = context(args.deadline, ready)
      finished = ready
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
      response = %*{"spend_usd": 0.0, "spend_limit_usd": 0.50}
      if spends == 1 and
        args.fault in [SpendHttpFailure, SpendRealFeedbackFailure]:
          status = 500
          response = %*{"error": "Local spend service failure"}
      elif spends == 1 and args.fault == SpendJsonFailure:
        raw = "{invalid-spend-json"
    elif line == "POST /v1/chat/completions HTTP/1.1":
      inc models
      doAssert models <= 4
      doAssert authorization == "Bearer coworld"
      let
        payload = body.fromJson(JsonNode)
        messages = payload["messages"]
        input = messages[messages.len - 1]["content"].getStr.fromJson(JsonNode)
        task = input["task"].getStr
        model = payload["model"].getStr
      doAssert task == expectedTask(args.fault, models),
        $args.fault & " call " & $models & " task " & task
      doAssert model == expectedModel(args.fault, models),
        $args.fault & " call " & $models & " model " & model
      doAssert payload["max_completion_tokens"].getInt == 3000
      trace.add(%*{"call": models, "task": task, "model": model})
      if args.fault == TransportFailure:
        continue
      elif requestFault(args.fault):
        status = 502
        response = %*{"error": "Local upstream unavailable"}
        if args.fault == HttpHeaderFailure:
          extraHeaders = "X-Coworld-Spend-Usd: bad\r\n"
      else:
        response = completion(args.fault)
    elif line == "POST /api.php?route=game/orders HTTP/1.1":
      inc actions
      let payload = body.fromJson(JsonNode)
      doAssert authorization == "Bearer " & SeatSecret
      doAssert models == 4 and actions == 1
      doAssert payload["orders"].len == 0
      doAssert payload["ready"].getStr == "Yes"
      ready = true
      response = newJArray()
    else:
      doAssert false, "Unexpected local fixture request: " & line
    let encoded = if raw.len > 0: raw else: $response
    client.send(
      "HTTP/1.1 " & $status & " Fixture\r\n" &
      "Content-Type: application/json\r\nConnection: close\r\n" &
      extraHeaders & "Content-Length: " & $encoded.len & "\r\n\r\n" & encoded
    )
    if finished:
      doAssert models == 4 and actions == 1
      let expectedSpends =
        if args.fault in [
          SpendHttpFailure, SpendJsonFailure, SpendRealFeedbackFailure
        ]:
          5
        else:
          4
      doAssert spends == expectedSpends
      echo $(%*{
        "event": "request_failure_http_trace", "scenario": $args.fault,
        "model_requests": models, "spend_requests": spends,
        "ready_actions": actions, "trace": trace
      })
      return

proc test(fault: Fault) =
  ## Assert persisted accounting and bounded calls after actual runtime retries.
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
    name = $fault & "-" & $getCurrentProcessId()
    path = getTempDir() / "kutuzov-request-failure-" & name & ".json"
    server = newSocket()
  if fileExists(path):
    removeFile(path)
  defer:
    if fileExists(path):
      removeFile(path)
  server.bindAddr(Port(0), "127.0.0.1")
  server.listen()
  let endpoint = "http://127.0.0.1:" & $server.getLocalAddr()[1]
  putEnv("WEBDIP_URL", endpoint)
  putEnv("WEBDIP_API_KEY", SeatSecret)
  putEnv("WEBDIP_GAME_ID", "702")
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
  if fault == SpendRealFeedbackFailure:
    let previous = BotState(
      gameId: 702,
      countryId: 3,
      budget: Budget(mode: EmpiricalBudget),
      phase: PhaseState(
        stamp: "0:Diplomacy",
        savedOrders: newJArray(),
        transcript: newJArray(),
        feedback: RealFeedback
      )
    )
    previous.persist(path)
  var worker: Thread[Scenario]
  createThread(worker, serve, (server, fault, int(epochTime()) + 300))
  runBot()
  joinThread(worker)
  let state = restore(loadGameConfig(), path, EmpiricalBudget)
  doAssert state.phase.calls == 4 and state.phase.pressCalls == 0
  doAssert state.phase.ready and not state.stopped
  doAssert state.phase.savedOrders.len == 0
  near(state.budget.authoritativeSpentUsd, 0.0)
  near(state.budget.reservedUsd, 0.0)
  if requestFault(fault):
    near(state.budget.spentUsd, 0.0)
    let expectedUncertain =
      if fault != SpendRealFeedbackFailure:
        0.012
      else:
        0.049
    near(state.budget.uncertainUsd, expectedUncertain)
    doAssert state.budget.uncertainCalls == 4
    doAssert state.budget.modelCosts[0].observed == 0
    doAssert state.budget.modelCosts[1].observed == 0
    if fault == SpendRealFeedbackFailure:
      doAssert state.phase.feedback == RealFeedback
    else:
      doAssert state.phase.feedback.len == 0
  else:
    let expected = estimateCost("gpt-6-luna", 100, 10, 0, 100) +
      3.0 * estimateCost(DefaultHostedModel, 100, 10, 0, 100)
    near(state.budget.spentUsd, expected)
    near(state.phase.costUsd, expected)
    near(state.budget.uncertainUsd, 0.0)
    doAssert state.budget.uncertainCalls == 0
    doAssert state.budget.modelCosts[0].observed == 3
    doAssert state.budget.modelCosts[1].observed == 1
    doAssert state.phase.feedback.len > 0
  echo $(%*{
    "event": "request_failure_runtime_result", "scenario": $fault,
    "passed": true,
    "calls": state.phase.calls, "known_spend_usd": state.budget.spentUsd,
    "uncertain_usd": state.budget.uncertainUsd,
    "uncertain_calls": state.budget.uncertainCalls,
    "ready_defaults": state.phase.ready, "external_calls": 0
  })

echo "Testing request failures, repair feedback, and paid-call limits"
configureLogs("")
for fault in Fault:
  test(fault)
