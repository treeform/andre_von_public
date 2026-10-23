import
  std/[json, net, os, strutils, times],
  jsony,
  ../[budgets, engines, players, protocols, wakes]

const
  EnvironmentNames = [
    "WEBDIP_URL", "WEBDIP_API_KEY", "WEBDIP_GAME_ID", "WEBDIP_COUNTRY_ID",
    "WEBDIP_END_YEAR", "OPENAI_API_KEY", "OPENAI_BASE_URL",
    "COWORLD_LLM_ENDPOINT", "COWORLD_LLM_MODEL", "KUTUZOV_MODEL",
    "AWS_ENDPOINT_URL_BEDROCK_RUNTIME", "BEDROCK_MODEL", "KUTUZOV_REASONING",
    "KUTUZOV_TIMEOUT_SECONDS", "KUTUZOV_MAX_OUTPUT_TOKENS",
    "KUTUZOV_GAME_TIMEOUT_SECONDS", "KUTUZOV_STATE_PATH",
    "KUTUZOV_BUDGET_USD", "KUTUZOV_RESERVE_USD", "KUTUZOV_BUDGET_MODE",
    "KUTUZOV_ECONOMY_MODEL", "KUTUZOV_MAX_PHASE_CALLS",
    "KUTUZOV_MAX_PRESS_CALLS", "KUTUZOV_TOOL_LOOP"
  ]

type
  RuntimeFixture = enum
    MultipleSteps, DeadlineEnd, BudgetEnd, RequestEnd, ProtectedContinuation

proc order(): JsonNode =
  ## Return the initial server default and explicitly chosen fixture Hold.
  %*{"type": "Hold", "terrID": 1, "toTerrID": 0,
    "fromTerrID": 0, "viaConvoy": "No"}

proc modelReply(fixture: RuntimeFixture, calls: int): string =
  ## Return fixed tool text without performing inference or choosing tactics.
  if fixture == RequestEnd:
    return "{malformed"
  if calls == 1:
    return $ %*{"calls": [{"id": "map", "name": "connections",
      "arguments": {"territories": ["Vienna"]}}]}
  $ %*{"calls": [
    {"id": "save", "name": "commit_orders", "arguments": {
      "orders": [{"type": "Hold", "origin": "Vienna",
        "destination": nil, "supported_origin": nil,
        "via_convoy": false, "convoy_route": []}],
      "center_check": "Keep Vienna.", "support_check": "No supports."
    }},
    {"id": "note", "name": "notes", "arguments": {"updates": [
      {"op": "upsert", "key": "defense", "text": "Keep Vienna."}]}},
    {"id": "finish", "name": "finish", "arguments": {
      "stop_spending": false, "reason": ""}}
  ]}

proc serve(args: tuple[server: Socket, fixture: RuntimeFixture]) {.thread.} =
  ## Drive the actual runtime through model replies and terminal resource paths.
  defer:
    args.server.close()
  var
    calls, saves, ready = 0
    orders = %*[order()]
    deadline = int(epochTime()) + 180
  let turn = if args.fixture == ProtectedContinuation: 0 else: 14
  while true:
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
      response = newJObject()
      done = false
    if line.startsWith("GET /api.php?route=game/playercontext"):
      response = %*{
        "game": {"turn": turn, "phase": (if ready > 0: "Finished" else: "Diplomacy"),
          "processTime": deadline, "pressType": "Regular"},
        "member": {"status": "Playing"}, "orders": {"orders": orders},
        "messages": {"messages": []},
        "files": {
          "game": {"url": "board.json", "version": "1"},
          "history": {"url": "history.json", "version": "1"},
          "messages": {"url": "messages.json", "version": "1"},
          "variant": {"url": "variant.json", "version": "1"}}
      }
      done = ready > 0
    elif line.startsWith("GET /board.json?"):
      response = %*{"turn": turn, "phase": "Diplomacy",
        "units": [{"id": 1, "type": "Army", "terrID": 1, "countryID": 5}],
        "territories": [{"id": 1, "ownerCountryID": 5, "occupiedBy": 5}],
        "members": [{"countryID": 5, "status": "Playing", "supplyCenterNo": 1}]}
    elif line.startsWith("GET /variant.json?"):
      response = %*{"name": "Fixture", "countries": [{"id": 5, "name": "Austria"}],
        "territories": [{"id": 1, "name": "Vienna", "type": "Land",
          "supply": "Yes", "homeCountryID": 5, "coast": "No",
          "coastParentID": 0, "borders": [], "coastalBorders": []}]}
    elif line.startsWith("GET /history.json?"):
      response = %*{"phases": []}
    elif line.startsWith("GET /messages.json?"):
      response = %*{"messages": []}
    elif line.startsWith("GET /spend "):
      let spent =
        if args.fixture == BudgetEnd: 2.0
        elif args.fixture == ProtectedContinuation: 0.355
        else: 0.0
      response = %*{"spend_usd": spent,
        "spend_limit_usd": 2.0}
    elif line.startsWith("POST /v1/chat/completions "):
      doAssert args.fixture notin [BudgetEnd, ProtectedContinuation]
      let payload = body.fromJson(JsonNode)
      if calls == 1 and args.fixture == MultipleSteps:
        let receipt = payload["messages"][^2]["content"].getStr.fromJson(JsonNode)
        doAssert receipt["results"][0]["id"].getStr == "map"
        doAssert receipt["results"][0]["output"]["status"].getStr == "ok"
        doAssert payload["messages"][^1]["content"].getStr.contains("tool_wake")
      if args.fixture == RequestEnd:
        let input = payload["messages"][^1]["content"].getStr.fromJson(JsonNode)
        doAssert input["tool_wake"]["number"].getInt == calls div 4 + 1
        doAssert input["tool_wake"]["requests_used"].getInt == calls mod 4
      inc calls
      doAssert calls <= (if args.fixture == RequestEnd: 12 else: 2)
      response = %*{"choices": [{"finish_reason": "stop", "message": {
        "role": "assistant", "content": modelReply(args.fixture, calls)}}],
        "usage": {"prompt_tokens": 100, "completion_tokens": 100}}
      if args.fixture == DeadlineEnd:
        deadline = int(epochTime()) + 20
    elif line.startsWith("POST /api.php?route=game/orders "):
      let payload = body.fromJson(JsonNode)
      if payload["ready"].getStr == "No":
        doAssert args.fixture == MultipleSteps
        inc saves
        orders = payload["orders"]
        doAssert orders == %*[order()]
      else:
        inc ready
        doAssert payload["orders"].len == 0
        doAssert saves == (if args.fixture == MultipleSteps: 1 else: 0)
      response = orders
    else:
      doAssert false, line
    let encoded = $response
    client.send("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n" &
      "Connection: close\r\nContent-Length: " & $encoded.len &
      "\r\n\r\n" & encoded)
    if done:
      doAssert ready == 1
      doAssert calls == (case args.fixture
        of MultipleSteps: 2
        of DeadlineEnd: 1
        of BudgetEnd: 0
        of RequestEnd: 12
        of ProtectedContinuation: 0)
      return

proc checkRuntime(fixture: RuntimeFixture, path: string) =
  ## Run the full bot against a local fixture with bounded model-call counts.
  var environment: seq[tuple[name, value: string, present: bool]]
  for name in EnvironmentNames:
    environment.add((name, getEnv(name), existsEnv(name)))
    delEnv(name)
  defer:
    for entry in environment:
      if entry.present:
        putEnv(entry.name, entry.value)
      else:
        delEnv(entry.name)
  let server = newSocket()
  server.bindAddr(Port(0), "127.0.0.1")
  server.listen()
  let endpoint = "http://127.0.0.1:" & $server.getLocalAddr()[1]
  putEnv("WEBDIP_URL", endpoint)
  putEnv("WEBDIP_API_KEY", "local-fixture")
  putEnv("WEBDIP_GAME_ID", "71")
  putEnv("WEBDIP_COUNTRY_ID", "5")
  putEnv("WEBDIP_END_YEAR", "1908")
  putEnv("COWORLD_LLM_ENDPOINT", endpoint)
  putEnv("COWORLD_LLM_MODEL", "openai/gpt-6.1-sol")
  putEnv("KUTUZOV_TOOL_LOOP", "true")
  putEnv("KUTUZOV_BUDGET_USD", "2.0")
  putEnv("KUTUZOV_STATE_PATH", path)
  putEnv("KUTUZOV_MAX_PHASE_CALLS",
    if fixture == RequestEnd: "12" else: "4")
  putEnv("KUTUZOV_MAX_OUTPUT_TOKENS", "1000")
  if fileExists(path):
    removeFile(path)
  if fixture == ProtectedContinuation:
    putEnv("KUTUZOV_BUDGET_MODE", "empirical")
    putEnv("KUTUZOV_BUDGET_USD", "0.5")
    putEnv("KUTUZOV_RESERVE_USD", "0.10")
    putEnv("KUTUZOV_ECONOMY_MODEL", "gpt-6-luna")
    var prior = BotState(
      gameId: 71, countryId: 5, toolLoop: true,
      budget: Budget(mode: EmpiricalBudget, spentUsd: 0.355,
        authoritativeSpentUsd: 0.355, uncertainUsd: 0.003, uncertainCalls: 1,
        modelCosts: [
          ModelCost(observed: 2, meanUsd: 0.010, largestUsd: 0.015),
          ModelCost(observed: 2, meanUsd: 0.001, largestUsd: 0.001)
        ]),
      phase: PhaseState(stamp: "0:Diplomacy", calls: 1,
        savedOrders: %*[order()], transcript: newJArray(),
        allowanceSet: true, allowanceUsd: 0.10, costUsd: 0.001)
    )
    doAssert prior.phase.wake.startWake(
      defaultWakeConfig(), InitialWake, int(epochTime()), int(epochTime()) + 180
    )
    doAssert prior.phase.wake.takeRequest(
      defaultWakeConfig(), int(epochTime()), int(epochTime()) + 180
    )
    prior.persist(path)
  var worker: Thread[tuple[server: Socket, fixture: RuntimeFixture]]
  createThread(worker, serve, (server, fixture))
  runToolBot()
  joinThread(worker)
  let state = restore(
    loadGameConfig(), path,
    (if fixture == ProtectedContinuation: EmpiricalBudget else: ConservativeBudget),
    toolLoop = true
  )
  doAssert state.phase.ready
  doAssert state.phase.calls == state.phase.wake.totalCalls
  doAssert state.phase.calls == (case fixture
    of MultipleSteps: 2
    of DeadlineEnd: 1
    of BudgetEnd: 0
    of RequestEnd: 12
    of ProtectedContinuation: 1)
  if fixture == MultipleSteps:
    doAssert state.phase.savedOrders == %*[order()]
    doAssert state.notes.len == 1
    doAssert state.phase.lookupFacts{"source"}.getStr == "latest_connections_lookup"
  elif fixture == ProtectedContinuation:
    doAssert state.phase.savedOrders == %*[order()]
    doAssert abs(state.budget.uncertainUsd - 0.003) < 0.000000001
    doAssert state.budget.uncertainCalls == 1
    doAssert state.budget.reservedUsd == 0.0
    doAssert abs(state.budget.budgetSpent - 0.358) < 0.000000001
    doAssert state.phase.wake.ending == BudgetLimit
    doAssert state.budget.canSpend(loadBudgetConfig(), 0.040)
  else:
    doAssert state.phase.savedOrders.len == 0
  if fixture == RequestEnd:
    doAssert state.phase.wake.ending == RequestLimit
    doAssert state.phase.wake.count == 3
    doAssert state.phase.wake.calls == 4

echo "Testing real tool wakes, request accounting, and resource endings"
block:
  let path = getTempDir() / ("kutuzov-tool-runtime-test-" &
    $getCurrentProcessId() & ".json")
  defer:
    for file in [path, path & ".tmp"]:
      if fileExists(file):
        removeFile(file)
  for fixture in RuntimeFixture:
    checkRuntime(fixture, path)
