import
  std/[json, net, os, strutils, times],
  jsony,
  ../[engines, notes, players, protocols, tools, wakes]

type
  PlayerFixture = enum
    Normal, PartialSave, NoPlan, ChangedPhase, LateCommit,
    ReviewWithoutCommit, ReviewCommit, ReviewRepair

proc savedOrder(destination = 0): JsonNode =
  ## Build a complete native order for the local HTTP fixture.
  %*{
    "type": (if destination == 0: "Hold" else: "Move"),
    "terrID": 1, "toTerrID": destination,
    "fromTerrID": 0, "viaConvoy": "No"
  }

proc variant(): JsonNode =
  ## Supply exact territory identities without selecting any model orders.
  %*{"territories": [
    {"id": 1, "name": "Vienna", "type": "Land"},
    {"id": 2, "name": "Budapest", "type": "Land"},
    {"id": 3, "name": "Trieste", "type": "Coast"}
  ]}

proc tool(id, name: string, arguments: JsonNode): ToolCall =
  ## Build one explicit model tool invocation with an independent call ID.
  ToolCall(id: id, name: name, arguments: arguments)

proc commit(destination: JsonNode): JsonNode =
  ## Build one named complete order with explicit consistency explanations.
  %*{
    "orders": [{
      "type": (if destination.kind == JNull: "Hold" else: "Move"),
      "origin": "Vienna", "destination": destination,
      "supported_origin": nil, "via_convoy": false, "convoy_route": []
    }],
    "center_check": "Hold the owned center.",
    "support_check": "No support or convoy orders."
  }

proc serve(args: tuple[server: Socket, fixture: PlayerFixture]) {.thread.} =
  ## Check real HTTP mutations and emulate a partial rejected server save.
  defer:
    args.server.close()
  var
    orders = %*[savedOrder()]
    saves, ready, messages, contexts = 0
  while true:
    var client: Socket
    args.server.accept(client)
    defer:
      client.close()
    let line = client.recvLine(timeout = 2000)
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
      inc contexts
      response = %*{
        "game": {"turn": (if args.fixture == ChangedPhase: 16 else: 15),
          "phase": "Diplomacy", "processTime": int(epochTime()) +
            (if args.fixture == LateCommit: 9 else: 100),
          "pressType": "Regular"},
        "orders": {"orders": orders}
      }
      done = args.fixture in [NoPlan, ChangedPhase, ReviewWithoutCommit] or
        args.fixture == LateCommit and contexts == 2
    elif line.startsWith("POST /api.php?route=game/orders "):
      let payload = body.fromJson(JsonNode)
      doAssert payload["turn"].getInt == 15
      if payload["ready"].getStr == "No":
        inc saves
        if args.fixture in [PartialSave, ReviewRepair] and saves == 1:
          doAssert payload["orders"][0]["toTerrID"].getInt == 2
          orders = %*[savedOrder(3)]
        else:
          doAssert payload["orders"][0]["type"].getStr == "Hold"
          orders = payload["orders"]
      else:
        inc ready
        doAssert payload["orders"].len == 0
        doAssert orders == %*[savedOrder()]
        doAssert saves == (if args.fixture in [PartialSave, ReviewRepair]: 2 else: 1)
        doAssert messages == (if args.fixture == Normal: 1 else: 0)
        done = true
      response = orders
    elif line.startsWith("POST /api.php?route=game/sendmessage "):
      inc messages
      doAssert args.fixture == Normal
      let payload = body.fromJson(JsonNode)
      doAssert payload["message"].getStr == "PCE (AUS ITA)"
      response = %*{"sent": true}
    else:
      doAssert false, line
    let encoded = $response
    client.send("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n" &
      "Connection: close\r\nContent-Length: " & $encoded.len &
      "\r\n\r\n" & encoded)
    if done:
      doAssert ready == (if args.fixture in [Normal, PartialSave, ReviewCommit, ReviewRepair]: 1 else: 0)
      return

proc checkFixture(fixture: PlayerFixture, path: string) =
  ## Exercise tool receipts, persisted claims, restoration, and stale-phase skips.
  let server = newSocket()
  server.bindAddr(Port(0), "127.0.0.1")
  server.listen()
  let game = GameConfig(
    url: "http://127.0.0.1:" & $server.getLocalAddr()[1],
    apiKey: "local-player-fixture", gameId: 71, countryId: 5,
    endYear: 1908, timeoutSeconds: 2
  )
  var
    state = BotState(gameId: 71, countryId: 5,
      phase: PhaseState(stamp: "15:Diplomacy", calls: 1,
        transcript: newJArray(), savedOrders: newJArray()))
    worker: Thread[tuple[server: Socket, fixture: PlayerFixture]]
  if fixture in [ReviewWithoutCommit, ReviewCommit, ReviewRepair]:
    state.phase.wake.count = 1
  doAssert state.phase.wake.startWake(
    defaultWakeConfig(),
    (if fixture in [ReviewWithoutCommit, ReviewCommit, ReviewRepair]:
      ReviewWake else: InitialWake),
    int(epochTime()),
    int(epochTime()) + 100
  )
  if fixture in [PartialSave, ReviewWithoutCommit, ReviewCommit, ReviewRepair]:
    state.phase.savedOrders = %*[savedOrder()]
  let finish = tool("done", "finish", %*{
    "stop_spending": false, "reason": ""
  })
  var calls: seq[ToolCall]
  case fixture
  of Normal:
    calls = @[
      tool("note", "notes", %*{"updates": [{
        "op": "upsert", "key": "alliance", "text": "Italy offered peace."
      }]}),
      tool("orders", "commit_orders", commit(newJNull())),
      tool("press", "send_press", %*{"messages": [
        {"to": 3, "text": "PCE (AUS ITA)"}
      ]}),
      finish,
      tool("after", "notes", %*{"updates": [{
        "op": "delete", "key": "alliance"
      }]})
    ]
  of PartialSave, ReviewRepair:
    calls = @[tool("bad", "commit_orders", commit(%"Budapest")), finish]
  of NoPlan, ReviewWithoutCommit:
    calls = @[finish]
  of ReviewCommit:
    calls = @[tool("review", "commit_orders", commit(newJNull())), finish]
  of LateCommit:
    calls = @[tool("late", "commit_orders", commit(newJNull())), finish]
  of ChangedPhase:
    calls = @[
      tool("old", "notes", %*{"updates": [{
        "op": "upsert", "key": "wrong_phase", "text": "Do not persist."
      }]}), finish
    ]
  createThread(worker, serve, (server, fixture))
  let batch = executeTools(
    game, state, variant(), calls, path, "gpt-6.1-sol", "review"
  )
  if fixture == PartialSave:
    doAssert not batch.finished and not state.phase.ready
    doAssert game.readyVerified(state, path, "wake_resource_end")
  elif fixture == ReviewRepair:
    doAssert not batch.finished and not state.phase.ready
    inc state.phase.calls
    let repaired = executeTools(
      game, state, variant(),
      @[tool("repair", "commit_orders", commit(newJNull())), finish],
      path, "gpt-6.1-sol", "repair"
    )
    doAssert repaired.finished and state.phase.reviewed and state.phase.ready
    doAssert state.phase.repairAttempt.isNil
  joinThread(worker)
  let results = batch.receipt["results"]
  doAssert results.len == calls.len
  for index in 0 ..< calls.len:
    doAssert results[index]["id"].getStr == calls[index].id
  case fixture
  of Normal:
    doAssert batch.finished and state.phase.ready
    doAssert state.notes.len == 1
    doAssert state.notes[0].originModel == "gpt-6.1-sol"
    doAssert state.notes[0].originPhase == "15:Diplomacy"
    doAssert state.notes[0].originDecision == "71:5:1:note"
    doAssert results[4]["output"]["status"].getStr == "skipped"
    doAssert state.toolDelivery["outcomes"][0]["status"].getStr == "confirmed"
    doAssert state.memoryDelivery.isNil
    let restored = restore(game, path)
    doAssert notesView(restored.notes) == notesView(state.notes)
    doAssert restored.toolDelivery == state.toolDelivery
  of PartialSave, ReviewRepair:
    doAssert results[0]["output"]["status"].getStr == "error"
    doAssert not batch.finished and state.phase.ready
    doAssert results[1]["output"]["status"].getStr == "error"
    doAssert state.phase.savedOrders == %*[savedOrder()]
  of ReviewCommit:
    doAssert batch.finished and state.phase.ready and state.phase.reviewed
  of ReviewWithoutCommit:
    doAssert not batch.finished and not state.phase.ready
    doAssert results[0]["output"]["error"].getStr.contains("Review finish")
  of NoPlan:
    doAssert not batch.finished and not state.phase.ready
    doAssert results[0]["output"]["status"].getStr == "error"
  of LateCommit:
    doAssert not batch.finished and not state.phase.ready
    doAssert results[0]["output"]["status"].getStr == "error"
    doAssert results[0]["output"]["error"].getStr.contains("Too little time")
    doAssert results[1]["output"]["status"].getStr == "error"
  of ChangedPhase:
    doAssert batch.phaseChanged and not batch.finished
    doAssert state.notes.len == 0 and not state.phase.ready
    for entry in results:
      doAssert entry["output"]["status"].getStr == "skipped"

echo "Testing explicit tools, truthful receipts, and final order restoration"
block:
  let path = getTempDir() / ("kutuzov-players-test-" &
    $getCurrentProcessId() & ".json")
  defer:
    for file in [path, path & ".tmp"]:
      if fileExists(file):
        removeFile(file)
  for fixture in PlayerFixture:
    checkFixture(fixture, path)

echo "Testing optional press preserves the review window"
block:
  var phase = PhaseState(wake: WakeState(count: 1))
  let cadence = defaultWakeConfig()
  doAssert not phase.startPhaseWake(cadence, PressWake, 100, 191, 90)
  doAssert phase.wake.count == 1 and not phase.wake.active
  doAssert phase.startPhaseWake(cadence, PressWake, 100, 300, 90)
  doAssert phase.wake.deadline == 210
  doAssert phase.wake.remainingSeconds(cadence, 210, 300) == 0
  phase.wake.finishWake(TimeLimit)
  doAssert phase.wake.nextWake(
    cadence, 210, 300, true, false, "", true
  ) == ReviewWake
  doAssert phase.startPhaseWake(cadence, ReviewWake, 210, 300, 90)
  doAssert phase.wake.count == 3

echo "Testing post-commit initial continuation preserves review time"
block:
  let cadence = defaultWakeConfig()
  var phase = PhaseState(savedOrders: newJArray())
  doAssert phase.startPhaseWake(cadence, InitialWake, 100, 300, 90)
  doAssert phase.wake.deadline == 220
  doAssert not phase.protectReviewTime(300, 90)
  phase.savedOrders = %*[savedOrder()]
  doAssert phase.protectReviewTime(300, 90)
  doAssert phase.wake.deadline == 210
  doAssert phase.wake.remainingSeconds(cadence, 206, 300) < 5
  doAssert not phase.protectReviewTime(300, 90)
