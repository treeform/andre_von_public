import
  std/[json, net, os, strutils, times],
  jsony,
  ../[budgets, engines, logs, protocols, requests]

const
  SeatSecret = "local-only-fixture-secret"
  ContextRoute = "/api.php?route=game/playercontext&gameID=701" &
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
    BoardFault, HistoryFault, MessagesFault, LookalikeFault,
    ActionFault, ContextFault, HistoryServerFault, MalformedHistoryFault

  Scenario = tuple[server: Socket, fault: Fault, status: int]

proc context(version: int, fault: Fault): JsonNode =
  ## Return a live private context with required orders and a short deadline.
  let boardPath = if fault == LookalikeFault: ContextRoute else: "board.json"
  %*{
    "game": {"turn": 4, "phase": "Diplomacy",
      "processTime": int(epochTime()) + 35, "pressType": "Regular"},
    "member": {"status": "Playing"},
    "orders": {"orders": [{"type": "Hold", "terrID": 1,
      "toTerrID": 0, "fromTerrID": 0, "viaConvoy": "No"}]},
    "messages": {"messages": []},
    "files": {
      "game": {"url": boardPath, "version": $version},
      "history": {"url": "history.json", "version": $version},
      "messages": {"url": "messages.json", "version": $version},
      "variant": {"url": "variant.json", "version": "1"}
    }
  }

proc board(): JsonNode =
  ## Return a complete small board for the active context.
  %*{
    "turn": 4, "phase": "Diplomacy", "units": [
      {"id": 1, "type": "Army", "terrID": 1, "countryID": 3}],
    "territories": [{"id": 1, "ownerCountryID": 3, "occupiedBy": 3}],
    "members": [{"countryID": 3, "status": "Playing", "supplyCenterNo": 1}]
  }

proc variant(): JsonNode =
  ## Return matching static names and map topology without network access.
  %*{
    "name": "Local fixture", "countries": [{"id": 3, "name": "Italy"}],
    "territories": [{"id": 1, "name": "Rome", "type": "Land",
      "supply": "Yes", "homeCountryID": 3, "coast": "No",
      "coastParentID": 0, "borders": [], "coastalBorders": []}]
  }

proc serve(args: Scenario) {.thread.} =
  ## Inject one HTTP failure and assert credentials and subsequent recovery.
  defer:
    args.server.close()
  var
    failed = false
    reads, boards, histories, actions = 0
    requests = 0
  while true:
    inc requests
    doAssert requests <= 20
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
      inject = false
      malformed = false
    let authoritative = line == "GET " & ContextRoute & " HTTP/1.1"
    if authoritative:
      inc reads
      doAssert authorization == "Bearer " & SeatSecret
      response = context(if failed: 2 else: 1, args.fault)
      inject = args.fault == ContextFault
      if failed and (args.fault == ActionFault or actions > 0):
        response["game"]["phase"] = %"Finished"
        finished = true
    elif line.startsWith("GET /board.json?") or
      line.startsWith("GET " & ContextRoute & "&v="):
        doAssert authorization.len == 0
        inc boards
        response = board()
        inject = args.fault in [BoardFault, LookalikeFault]
    elif line.startsWith("GET /history.json?"):
      doAssert authorization.len == 0
      inc histories
      response = %*{"phases": []}
      inject = args.fault in [
        HistoryFault, HistoryServerFault, MalformedHistoryFault
      ]
    elif line.startsWith("GET /variant.json?"):
      doAssert authorization.len == 0
      response = variant()
    elif line.startsWith("GET /messages.json?"):
      doAssert authorization.len == 0
      response = %*{"messages": []}
      inject = args.fault == MessagesFault
    elif line == "POST /api.php?route=game/orders HTTP/1.1":
      doAssert authorization == "Bearer " & SeatSecret
      doAssert body.fromJson(JsonNode)["ready"].getStr == "Yes"
      inc actions
      doAssert actions == 1, "Do not replay a possibly accepted action."
      response = newJArray()
      inject = args.fault == ActionFault
    else:
      doAssert false, "No provider call is allowed: " & line
    if inject and not failed:
      failed = true
      status = args.status
      response = %*{"error": "Local fixture missing resource"}
      malformed = args.fault == MalformedHistoryFault
      if args.fault == ContextFault:
        finished = true
    let encoded = if malformed: "{invalid-json" else: $response
    client.send(
      "HTTP/1.1 " & $status & " Fixture\r\n" &
      "Content-Type: application/json\r\nConnection: close\r\n" &
      "Content-Length: " & $encoded.len & "\r\n\r\n" & encoded
    )
    if finished:
      doAssert failed
      if args.fault == ContextFault:
        doAssert reads == 1 and requests == 1
      elif args.fault == ActionFault:
        doAssert reads == 3 and actions == 1
      else:
        doAssert reads == 4 and actions == 1
        doAssert boards == 2
        if args.fault in [HistoryFault, MessagesFault,
          HistoryServerFault, MalformedHistoryFault]:
            doAssert histories == 2
      return

proc test(fault: Fault, status: int) =
  ## Compare a missing asset or action with an authoritative missing game.
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
    name = $fault & "-" & $status & "-" & $getCurrentProcessId()
    path = getTempDir() / "kutuzov-http-authority-" & name & ".json"
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
  putEnv("WEBDIP_GAME_ID", "701")
  putEnv("WEBDIP_COUNTRY_ID", "3")
  putEnv("WEBDIP_END_YEAR", "1908")
  putEnv("COWORLD_LLM_ENDPOINT", endpoint)
  putEnv("COWORLD_LLM_MODEL", DefaultHostedModel)
  putEnv("KUTUZOV_STATE_PATH", path)
  putEnv("KUTUZOV_MAX_OUTPUT_TOKENS", "3000")
  putEnv("KUTUZOV_BUDGET_MODE", "empirical")
  var worker: Thread[Scenario]
  createThread(worker, serve, (server, fault, status))
  runBot()
  joinThread(worker)
  let state = restore(loadGameConfig(), path, EmpiricalBudget)
  doAssert state.phase.calls == 0 and not state.stopped
  doAssert state.phase.ready == (fault notin [ContextFault, ActionFault])
  echo $(%*{
    "event": "fault_fixture_result", "scenario": name,
    "passed": true, "provider_calls": 0, "ready": state.phase.ready
  })

configureLogs("")
test(BoardFault, 404)
test(HistoryFault, 410)
test(MessagesFault, 404)
test(LookalikeFault, 404)
test(ActionFault, 404)
test(ContextFault, 404)
test(ContextFault, 410)
test(HistoryServerFault, 500)
test(MalformedHistoryFault, 200)

echo "HTTP authority tests passed"
