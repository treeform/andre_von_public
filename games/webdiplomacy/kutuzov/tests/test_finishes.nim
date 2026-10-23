import
  std/[json, nativesockets, net, os, strutils, times],
  ../[budgets, common, engines, prompts, protocols]

const
  Verified = """[
    {"type":"Move","terrID":65,"toTerrID":11,
      "fromTerrID":0,"viaConvoy":"No"},
    {"type":"Support move","terrID":64,"toTerrID":11,
      "fromTerrID":65,"viaConvoy":"No"}
  ]"""
  Mixed = """[
    {"type":"Move","terrID":65,"toTerrID":11,
      "fromTerrID":0,"viaConvoy":"No"},
    {"type":"Support hold","terrID":64,"toTerrID":12,
      "fromTerrID":0,"viaConvoy":"No"}
  ]"""

type
  FinishFixture = enum
    CleanPlan, RestorePlan, RestoreRejected, NoPlan,
    StalePhase, RacingPhase, UnchangedRejection

proc serve(args: tuple[server: Socket, fixture: FinishFixture]) {.thread.} =
  ## Assert finite HTTP sequences without allowing Ready on a failed restore.
  defer:
    args.server.close()
  let count =
    case args.fixture
    of CleanPlan, RestoreRejected:
      2
    of RestorePlan:
      4
    of NoPlan, StalePhase:
      1
    of RacingPhase, UnchangedRejection:
      3
  for i in 0 ..< count:
    var handles = @[args.server.getFd()]
    doAssert selectRead(handles, 3000) == 1
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
    var
      body = ""
      status = 200
      response: JsonNode
    while body.len < length:
      body.add client.recv(length - body.len, timeout = 2000)
    if line.startsWith("GET /api.php?route=game/playercontext"):
      let changed = args.fixture == StalePhase or
        (args.fixture == RacingPhase and i == 2)
      response = %*{
        "game": {"turn": 13,
          "phase": (if changed: "Builds" else: "Diplomacy"),
          "processTime": int(epochTime()) + 90},
        "orders": {"orders": parseJson(
          if args.fixture in [RestorePlan, RestoreRejected] and i == 0:
            Mixed
          else:
            Verified
        )}
      }
    else:
      doAssert line.startsWith("POST /api.php?route=game/orders ")
      let payload = parseJson(body)
      if args.fixture in [RestorePlan, RestoreRejected] and i == 1:
        doAssert payload["ready"].getStr == "No"
        doAssert payload["orders"] == parseJson(Verified)
      else:
        doAssert payload["ready"].getStr == "Yes"
        doAssert payload["orders"].len == 0
      response = parseJson(
        if args.fixture == RestoreRejected: Mixed else: Verified
      )
      if args.fixture in [RacingPhase, UnchangedRejection]:
        status = 400
        response = %"Invalid phase, expected `Builds`, got `Diplomacy`."
    let encoded = $response
    client.send("HTTP/1.1 " & $status & " Fixture\r\n" &
      "Content-Type: application/json\r\nConnection: close\r\n" &
      "Content-Length: " & $encoded.len & "\r\n\r\n" & encoded)

proc check(fixture: FinishFixture) =
  ## Replay a mixed save, transition or persistent rejection through real HTTP.
  let
    server = newSocket()
    path = getTempDir() / ("kutuzov-finish-" &
      $getCurrentProcessId() & "-" & $fixture & ".json")
    context = %*{
      "game": {"turn": 13, "phase": "Diplomacy",
        "processTime": int(epochTime()) + 90},
      "orders": {"orders": parseJson(Verified)}
    }
  server.bindAddr(Port(0), "127.0.0.1")
  server.listen()
  let game = GameConfig(
    url: "http://127.0.0.1:" & $server.getLocalAddr()[1],
    apiKey: "local-finish-fixture", gameId: 1, countryId: 6,
    timeoutSeconds: 2
  )
  var
    worker: Thread[tuple[server: Socket, fixture: FinishFixture]]
    state = BotState(
      gameId: 1, countryId: 6, memory: "Preserve verified intentions.",
      phase: PhaseState(stamp: "13:Diplomacy", calls: 4,
        savedOrders: parseJson(Verified))
    )
    returned = false
    failed = false
  if fixture == NoPlan:
    state.phase.savedOrders = newJArray()
    state.phase.feedback = "The last requested set was not accepted."
    state.phase.repairAttempt = %*{
      "phase": state.phase.stamp, "needs_repair": true
    }
  createThread(worker, serve, (server, fixture))
  try:
    returned = game.readyLegacy(state, context, path, "phase_call_limit")
  except KutuzovError:
    failed = true
  finally:
    joinThread(worker)
    if fileExists(path):
      removeFile(path)
  doAssert failed ==
    (fixture in [RestoreRejected, NoPlan, UnchangedRejection])
  doAssert returned == (fixture in [CleanPlan, RestorePlan])
  doAssert state.phase.ready == returned
  doAssert state.memory == "Preserve verified intentions."
  if fixture != NoPlan:
    doAssert state.phase.savedOrders == parseJson(Verified)

echo "Testing verified Ready restoration and phase races"
for fixture in FinishFixture:
  check(fixture)

echo "Testing rejected retreat classification and unchanged repair prevention"
block:
  let
    orders = %*[{
      "type": "Retreat", "terrID": 21, "toTerrID": 28,
      "fromTerrID": 0, "viaConvoy": "No"
    }]
    saved = %*[{
      "type": "Retreat", "terrID": 21, "toTerrID": newJNull()
    }]
  var
    phase = PhaseState(stamp: "1:Retreats", calls: 1)
    failure: ref KutuzovError
  try:
    verifyOrders(orders, saved)
  except KutuzovError as error:
    failure = error
  doAssert not failure.isNil
  phase.captureRepairAttempt(Decision(orders: orders), "plan", failure)
  doAssert phase.repairView()["needs_repair"].getBool
  doAssert phase.nextTask(
    "Retreats", PressContext(), defaultBudgetConfig(), 55, 10, 0
  ) == "repair"
  doAssertRaises KutuzovOrderError:
    phase.rejectRepeatedOrders(orders)
  let alternative = orders.copy()
  alternative[0]["toTerrID"] = %22
  phase.rejectRepeatedOrders(alternative)
  phase.captureRepairAttempt(
    Decision(orders: orders), "repair",
    newException(KutuzovError, "Save transport outcome is unknown.")
  )
  phase.rejectRepeatedOrders(orders)
  phase.stamp = "2:Diplomacy"
  phase.rejectRepeatedOrders(orders)

echo "Testing self support rejection before native writes"
block:
  let
    game = GameConfig()
    context = %*{"game": {"turn": 3, "phase": "Diplomacy"}}
  for kind in ["Support hold", "Support move"]:
    let orders = %*[{
      "type": kind, "terrID": 21, "toTerrID": 21,
      "fromTerrID": 21, "viaConvoy": "No"
    }]
    doAssertRaises KutuzovOrderError:
      discard game.saveOrdersVerified(context, orders, ready = false)
