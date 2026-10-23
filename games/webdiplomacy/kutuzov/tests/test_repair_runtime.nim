import
  std/[json, net, os, strutils, times],
  jsony,
  ../[budgets, engines, logs, prompts, protocols, requests], boards

const
  ItalyFixture = staticRead("fixtures/italy_repair.json")
  SeatSecret = "local-repair-fixture-seat"
  RepairedMemory = "Verified final autumn repair accepted."
  StartingSpend = 0.41140056
  ContextRoute = "/api.php?route=game/playercontext&gameID=1" &
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
    SemanticRewrite, OrderHttp400, ModelHttpFailure,
    Unknown500ThenReady400, UnknownTransport

  Scenario = tuple[
    server: Socket, fault: Fault, deadline: int, path: string
  ]

proc repairedDecision(fixture: JsonNode): JsonNode =
  ## Replace the rejected fleet support with the recorded saved fleet move.
  result = fixture["rejected_decision"].copy()
  for order in result["orders"]:
    if order["terrID"].getInt == 23:
      order["type"] = %"Move"
      order["toTerrID"] = %22
  result["memory"] = %RepairedMemory

proc restoredVariant(fixture: JsonNode): JsonNode =
  ## Restore the public map objects needed by the real prompt builder.
  let compact = parseJson(fixture["map_text"].getStr)
  result = newJObject()
  for key, value in compact:
    if key notin ["territory_fields", "territories"]:
      result[key] = value.copy()
  result["territories"] = newJArray()
  for row in compact["territories"]:
    let territory = newJObject()
    for column in 0 ..< compact["territory_fields"].len:
      let key = compact["territory_fields"][column].getStr
      if key in ["borders", "coastalBorders"]:
        territory[key] = newJArray()
        for border in row[column]:
          territory[key].add %*{
            "id": border[0], "army": border[1], "fleet": border[2]
          }
      else:
        territory[key] = row[column].copy()
    result["territories"].add territory
  doAssert compactMap(result) == compact

proc currentSlots(fixture, orders: JsonNode): JsonNode =
  ## Retain native slot identities while reflecting simulated saved orders.
  result = fixture["current_input"]["order_slots"].copy()
  for slot in result:
    var found = false
    for order in orders:
      if slot["terrID"] == order["terrID"]:
        found = true
        for field in ["type", "toTerrID", "fromTerrID"]:
          slot[field] = order[field].copy()
        slot["viaConvoy"] = %(order{"viaConvoy"}.getStr == "Yes")
    doAssert found

proc context(deadline: int, slots: JsonNode, finished: bool): JsonNode =
  ## Keep the final autumn active until the scenario has observed its outcome.
  %*{
    "game": {"turn": 15,
      "phase": (if finished: "Finished" else: "Diplomacy"),
      "processTime": deadline, "pressType": "Regular"},
    "member": {"status": "Playing"},
    "orders": {"orders": slots},
    "messages": {"messages": []},
    "files": {
      "game": {"url": "board.json", "version": "1"},
      "history": {"url": "history.json", "version": "1"},
      "messages": {"url": "messages.json", "version": "1"},
      "variant": {"url": "variant.json", "version": "1"}
    }
  }

proc assertVerified(state: BotState, fixture: JsonNode) =
  ## Require failed candidates to leave the last verified memory intact.
  let verified = fixture["verified_state"]
  doAssert state.phase.savedOrders == verified["saved_orders"]
  doAssert state.memory == verified["memory"].getStr
  doAssert state.memoryStamp == verified["memory_phase"].getStr
  doAssert state.memoryDelivery == verified["memory_delivery"]
  doAssert state.memorySerial == 33
  doAssert not state.phase.ready and not state.stopped

proc assertAttempt(attempt, decision: JsonNode, rejected: bool, call: int) =
  ## Decode the production table and compare every exact attempted order.
  doAssert attempt.kind == JObject
  doAssert attempt["phase"].getStr == "15:Diplomacy"
  doAssert attempt["call"].getInt == call
  doAssert attempt["source_task"].getStr == "review"
  doAssert attempt["outcome"].getStr ==
    (if rejected: "rejected" else: "unconfirmed")
  doAssert attempt["needs_repair"].getBool == rejected
  doAssert attempt["orders_complete"].getBool
  doAssert attempt["original_order_count"].getInt == decision["orders"].len
  doAssert attempt["candidate_memory"]["unverified"].getBool
  doAssert attempt["candidate_memory"]["text"] == decision["memory"]
  let orders = newJArray()
  for rowIndex in 0 ..< attempt["orders"].len:
    let order = newJObject()
    for column in 0 ..< attempt["order_fields"].len:
      var absent = false
      if attempt.hasKey("order_absent"):
        for pair in attempt["order_absent"]:
          if pair[0].getInt == rowIndex and pair[1].getInt == column:
            absent = true
      if not absent:
        order[attempt["order_fields"][column].getStr] =
          attempt["orders"][rowIndex][column].copy()
    orders.add order
  doAssert orders == decision["orders"]

proc completion(decision: JsonNode): JsonNode =
  ## Use explicit synthetic tiny usage so two final autumn reservations fit.
  %*{
    "choices": [{"finish_reason": "stop", "message": {
      "role": "assistant", "content": $decision
    }}],
    "usage": {"prompt_tokens": 100, "completion_tokens": 10,
      "prompt_tokens_details": {"cached_tokens": 0}}
  }

proc serve(args: Scenario) {.thread.} =
  ## Drive real runtime HTTP paths entirely through a local fixture server.
  defer:
    args.server.close()
  let
    fixture = parseJson(ItalyFixture)
    candidate = fixture["rejected_decision"]
    repaired = repairedDecision(fixture)
    nativeBoard = restoredBoard(fixture["current_input"]["board"])
    nativeVariant = restoredVariant(fixture)
    initialAttempt = restore(
      loadGameConfig(), args.path, EmpiricalBudget
    ).phase.repairAttempt
  var
    ready = false
    models, spends, saves, readyPosts, requests, terminalReads = 0
    slots = currentSlots(fixture, fixture["verified_state"]["saved_orders"])
    failedAttempt: JsonNode
    trace = newJArray()
  while true:
    inc requests
    doAssert requests <= 35
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
      finished = false
    if line == "GET " & ContextRoute & " HTTP/1.1":
      doAssert authorization == "Bearer " & SeatSecret
      let state = restore(loadGameConfig(), args.path, EmpiricalBudget)
      if (saves == 1 and models == 1) or
        (args.fault == ModelHttpFailure and models == 1):
          state.assertVerified(fixture)
          if args.fault == ModelHttpFailure:
            doAssert state.phase.repairAttempt == initialAttempt
            finished = true
          else:
            let rejected = args.fault in [SemanticRewrite, OrderHttp400]
            state.phase.repairAttempt.assertAttempt(
              candidate, rejected,
              (if args.fault == Unknown500ThenReady400: 4 else: 3)
            )
            if failedAttempt.isNil:
              failedAttempt = state.phase.repairAttempt.copy()
            else:
              doAssert state.phase.repairAttempt == failedAttempt
            if rejected:
              doAssert state.phase.feedback.len > 0
            else:
              doAssert state.phase.feedback.len == 0
            finished = args.fault == UnknownTransport or readyPosts > 0
      finished = finished or ready
      response = context(args.deadline, slots, finished)
      if finished and args.fault == Unknown500ThenReady400:
        inc terminalReads
        # The Ready guard reads the transition before the main loop does.
        if terminalReads == 1:
          finished = false
    elif line.startsWith("GET /board.json?"):
      doAssert authorization.len == 0
      response = nativeBoard
    elif line.startsWith("GET /history.json?"):
      doAssert authorization.len == 0
      response = %*{"phases": []}
    elif line.startsWith("GET /variant.json?"):
      doAssert authorization.len == 0
      response = nativeVariant
    elif line.startsWith("GET /messages.json?"):
      doAssert authorization.len == 0
      response = %*{"messages": []}
    elif line == "GET /spend HTTP/1.1":
      inc spends
      doAssert authorization.len == 0
      response = %*{"spend_usd": StartingSpend, "spend_limit_usd": 0.50}
    elif line == "POST /v1/chat/completions HTTP/1.1":
      inc models
      doAssert models <= 2
      doAssert authorization == "Bearer coworld"
      let
        payload = body.fromJson(JsonNode)
        messages = payload["messages"]
        input = parseJson(messages[messages.len - 1]["content"].getStr)
        fullInput =
          if input.hasKey("board"):
            input
          else:
            parseJson(messages[1]["content"].getStr)
        expectedTask =
          if models == 2 or args.fault == ModelHttpFailure:
            "repair"
          else:
            "review"
        verified = fixture["verified_state"]
      doAssert payload["model"].getStr == DefaultHostedModel
      doAssert payload["max_completion_tokens"].getInt == 3000
      doAssert input["task"].getStr == expectedTask
      doAssert fullInput["final_year"].getBool
      doAssert fullInput["season"].getStr == "autumn"
      doAssert fullInput["turn"].getInt == 15
      doAssert input["saved_orders"] == verified["saved_orders"]
      doAssert input["memory"] == verified["memory"]
      doAssert input["memory_phase"] == verified["memory_phase"]
      doAssert input["memory_delivery"] == verified["memory_delivery"]
      doAssert input["order_slots"] == slots
      if expectedTask == "repair":
        input["repair_attempt"].assertAttempt(candidate, true, 3)
        doAssert input["repair_feedback"].getStr.len > 0
      else:
        doAssert input["repair_attempt"].kind == JNull
      trace.add %*{
        "call": models, "task": expectedTask, "model": payload["model"]
      }
      if args.fault == ModelHttpFailure:
        status = 502
        response = %*{"error": "Local model unavailable"}
      else:
        response = completion(if models == 1: candidate else: repaired)
    elif line == "POST /api.php?route=game/orders HTTP/1.1":
      doAssert authorization == "Bearer " & SeatSecret
      let payload = body.fromJson(JsonNode)
      doAssert payload["turn"].getInt == 15
      doAssert payload["phase"].getStr == "Diplomacy"
      if payload["orders"].len == 0:
        inc readyPosts
        doAssert payload["ready"].getStr == "Yes"
        doAssert readyPosts == 1
        if args.fault == Unknown500ThenReady400:
          doAssert saves == 1 and models == 1
          status = 400
          response = %*{"error": "Local Ready request rejected"}
        else:
          doAssert saves == 2 and models == 2
          ready = true
          response = newJArray()
      else:
        inc saves
        doAssert payload["ready"].getStr == "No"
        doAssert payload["orders"] ==
          (if saves == 1: candidate["orders"] else: repaired["orders"])
        if saves == 2:
          doAssert args.fault in [SemanticRewrite, OrderHttp400]
          slots = currentSlots(fixture, repaired["orders"])
          response = repaired["orders"].copy()
        else:
          case args.fault
          of SemanticRewrite:
            slots = currentSlots(fixture, fixture["server_saved_orders"])
            response = fixture["server_saved_orders"].copy()
          of OrderHttp400:
            status = 400
            response = %*{"error": "Local submitted order rejected"}
          of Unknown500ThenReady400:
            status = 500
            response = %*{"error": "Local save outcome unknown"}
          of UnknownTransport:
            continue
          of ModelHttpFailure:
            doAssert false
    else:
      doAssert false, "Unexpected repair fixture request: " & line
    let encoded = $response
    client.send(
      "HTTP/1.1 " & $status & " Fixture\r\n" &
      "Content-Type: application/json\r\nConnection: close\r\n" &
      "Content-Length: " & $encoded.len & "\r\n\r\n" & encoded
    )
    if finished:
      let repaired = args.fault in [SemanticRewrite, OrderHttp400]
      doAssert models == (if repaired: 2 else: 1)
      doAssert spends == models
      doAssert saves ==
        (if repaired: 2 elif args.fault == ModelHttpFailure: 0 else: 1)
      doAssert readyPosts ==
        (if repaired or args.fault == Unknown500ThenReady400: 1 else: 0)
      echo $(%*{
        "event": "repair_runtime_http_trace", "scenario": $args.fault,
        "model_requests": models, "order_saves": saves,
        "ready_posts": readyPosts, "trace": trace
      })
      return

proc test(fault: Fault) =
  ## Check durable state after real inference, save, repair, and Ready paths.
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
    fixture = parseJson(ItalyFixture)
    verified = fixture["verified_state"]
    name = $fault & "-" & $getCurrentProcessId()
    path = getTempDir() / "kutuzov-repair-runtime-" & name & ".json"
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
  putEnv("WEBDIP_GAME_ID", "1")
  putEnv("WEBDIP_COUNTRY_ID", "3")
  putEnv("WEBDIP_END_YEAR", "1908")
  putEnv("COWORLD_LLM_ENDPOINT", endpoint)
  putEnv("COWORLD_LLM_MODEL", DefaultHostedModel)
  putEnv("KUTUZOV_STATE_PATH", path)
  putEnv("KUTUZOV_MAX_OUTPUT_TOKENS", "3000")
  putEnv("KUTUZOV_TIMEOUT_SECONDS", "40")
  putEnv("KUTUZOV_ECONOMY_MODEL", "gpt-6-luna")
  putEnv("KUTUZOV_BUDGET_MODE", "empirical")
  putEnv("KUTUZOV_BUDGET_USD", "0.50")
  putEnv("KUTUZOV_RESERVE_USD", "0.10")
  var previous = BotState(
    gameId: 1,
    countryId: 3,
    budget: Budget(
      mode: EmpiricalBudget,
      spentUsd: StartingSpend,
      authoritativeSpentUsd: StartingSpend,
      modelCosts: [
        ModelCost(observed: 31, meanUsd: 0.01595036474280609,
          largestUsd: 0.0193835),
        ModelCost(observed: 9, meanUsd: 0.00081569880859375,
          largestUsd: 0.0011018)
      ]
    ),
    phase: PhaseState(
      stamp: "15:Diplomacy",
      calls: (if fault == Unknown500ThenReady400: 3 else: 2),
      savedOrders: verified["saved_orders"].copy(),
      transcript: newJArray()
    ),
    memory: verified["memory"].getStr,
    memoryStamp: verified["memory_phase"].getStr,
    memorySerial: 33,
    memoryDelivery: verified["memory_delivery"].copy()
  )
  if fault == ModelHttpFailure:
    previous.phase.calls = 3
    previous.phase.captureRepairAttempt(
      readDecision($fixture["rejected_decision"]),
      "review",
      newException(KutuzovOrderError, fixture["failure"]["error"].getStr)
    )
  previous.persist(path)
  var worker: Thread[Scenario]
  createThread(worker, serve, (server, fault, int(epochTime()) + 60, path))
  runBot()
  joinThread(worker)
  let
    state = restore(loadGameConfig(), path, EmpiricalBudget)
    repaired = fault in [SemanticRewrite, OrderHttp400]
  doAssert not state.stopped
  doAssert state.phase.calls ==
    (if fault == UnknownTransport: 3 else: 4)
  if repaired:
    doAssert state.phase.ready
    doAssert state.phase.feedback.len == 0
    doAssert state.phase.repairAttempt.isNil or
      state.phase.repairAttempt.kind == JNull
    doAssert state.phase.savedOrders == repairedDecision(fixture)["orders"]
    doAssert state.memory == RepairedMemory
    doAssert state.memoryStamp == "15:Diplomacy"
    doAssert state.memorySerial == 34
    doAssert state.memoryDelivery == %*{
      "decision_id": "1:3:34", "phase": "15:Diplomacy", "outcomes": []
    }
  else:
    state.assertVerified(fixture)
    if fault == ModelHttpFailure:
      doAssert state.phase.repairAttempt == previous.phase.repairAttempt
      doAssert state.phase.feedback == previous.phase.feedback
      doAssert state.budget.uncertainCalls == 1
      doAssert abs(state.budget.uncertainUsd - 0.04) < 0.000000001
    else:
      state.phase.repairAttempt.assertAttempt(
        fixture["rejected_decision"], false,
        (if fault == Unknown500ThenReady400: 4 else: 3)
      )
      doAssert state.phase.feedback.len == 0
      doAssert state.budget.uncertainCalls == 0
  doAssert state.budget.modelCosts[1].observed == 9
  doAssert state.budget.modelCosts[0].observed ==
    (if repaired: 33 elif fault == ModelHttpFailure: 31 else: 32)
  echo $(%*{
    "event": "repair_runtime_result", "scenario": $fault, "passed": true,
    "calls": state.phase.calls, "ready": state.phase.ready,
    "known_spend_usd": state.budget.spentUsd,
    "uncertain_usd": state.budget.uncertainUsd, "external_calls": 0
  })

echo "Testing persisted repair candidates through the production runtime"
configureLogs("")
for fault in Fault:
  test(fault)
