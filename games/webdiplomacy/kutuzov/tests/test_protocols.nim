import
  std/[json, net, strutils],
  jsony,
  ../[common, protocols]

const
  ContextBody = """{
    "game":{"turn":0,"phase":"Diplomacy"},
    "orders":{"orders":[{},{}]},
    "files":{
      "variant":{"url":"variant.json","version":"map 1+2"},
      "game":{"url":"game.json","version":"board-1"}
    }
  }"""
  OrderBody = """[
    {"type":"Move","terrID":1,"toTerrID":2,
      "fromTerrID":0,"viaConvoy":"No"},
    {"type":"Support move","terrID":3,"toTerrID":2,
      "fromTerrID":1,"viaConvoy":"No"}
  ]"""

proc testOrderVerification() =
  ## Check semantic equality and reject silent order loss or replacement.
  let
    requested = OrderBody.fromJson(JsonNode)
    saved = %*[
      {"type": "Support move", "terrID": "3", "toTerrID": "2",
        "fromTerrID": "1", "viaConvoy": false, "id": 17},
      {"type": "Move", "terrID": "1", "toTerrID": "2",
        "fromTerrID": newJNull(), "viaConvoy": false, "id": 18}
    ]
    changed = %*[
      {"type": "Hold", "terrID": 1},
      {"type": "Support move", "terrID": 3, "toTerrID": 2,
        "fromTerrID": 1, "viaConvoy": "No"}
    ]
    waits = %*[{"type": "Wait"}]
    waitSlots = %*[{"type": "Wait"}, {"type": "Wait"}]
    build = %*[
      {"type": "Build Fleet", "terrID": 0, "toTerrID": 7},
      {"type": "Wait"}
    ]
    savedBuild = %*[
      {"type": "Build Fleet", "terrID": newJNull(), "toTerrID": 7},
      {"type": "Wait"}
    ]
    destroy = %*[{"type": "Destroy", "terrID": 7, "toTerrID": 7}]
    savedDestroy = %*[
      {"type": "Destroy", "terrID": newJNull(), "toTerrID": 7}
    ]
    convoy = %*[
      {"type": "Move", "terrID": 1, "toTerrID": 2,
        "viaConvoy": "Yes", "convoyPath": [1, 4]}
    ]
    savedConvoy = %*[
      {"type": "Move", "terrID": 1, "toTerrID": 2, "viaConvoy": true}
    ]
  verifyOrders(requested, saved)
  doAssertRaises KutuzovError:
    verifyOrders(requested, changed)
  doAssertRaises KutuzovError:
    verifyOrders(requested, %*[saved[0], saved[0]])
  doAssertRaises KutuzovError:
    verifyOrders(requested, %*[saved[0]])
  verifyOrders(waits, waitSlots, 2)
  verifyOrders(waits, waitSlots)
  doAssertRaises KutuzovError:
    verifyOrders(waits, waitSlots, 1)
  verifyOrders(build, savedBuild, 2)
  doAssertRaises KutuzovError:
    verifyOrders(build, savedBuild, 0)
  verifyOrders(destroy, savedDestroy)
  # Upstream consumes the route for validation but omits it from saved orders.
  verifyOrders(convoy, savedConvoy)
  doAssertRaises KutuzovError:
    verifyOrders(convoy, %*[
      {"type": "Move", "terrID": 1, "toTerrID": 2, "viaConvoy": false}
    ])
  doAssertRaises KutuzovError:
    verifyOrders(%*[{"type": "Unknown"}], %*[])
  doAssertRaises KutuzovError:
    verifyOrders(%*[{"type": "Hold", "terrID": "invalid"}], %*[])
  doAssertRaises KutuzovError:
    verifyOrders(newJNull(), %*[])
  doAssertRaises KutuzovError:
    verifyOrders(requested, newJObject())
  verifyOrders(newJArray(), saved)

proc serveProtocol(server: Socket) {.thread.} =
  ## Serve real HTTP fixtures while asserting credential and write sequencing.
  defer:
    server.close()
  for i in 0 ..< 16:
    var client: Socket
    server.accept(client)
    defer:
      client.close()
    let request = client.recvLine(timeout = 2000)
    var
      contentLength = 0
      authorized = false
    while true:
      let line = client.recvLine(timeout = 2000)
      if line.len == 0 or line == "\r\n":
        break
      if line.toLowerAscii().startsWith("content-length:"):
        contentLength = parseInt(line.split(':', 1)[1].strip())
      if line.toLowerAscii().startsWith("authorization:"):
        doAssert line.split(':', 1)[1].strip() == "Bearer test-seat"
        authorized = true
    var
      body = ""
      response = ""
      status = "200 OK"
    while body.len < contentLength:
      let chunk = client.recv(contentLength - body.len, timeout = 2000)
      doAssert chunk.len > 0
      body.add(chunk)
    if i in [1, 2, 12]:
      doAssert not authorized, "Public files must not receive seat keys."
    else:
      doAssert authorized
    case i
    of 0, 4, 11:
      doAssert request.startsWith(
        "GET /api.php?route=game/playercontext&gameID=1&orders=1&messages=1 "
      )
      response = ContextBody
      if i == 11:
        response = response.replace("\"turn\":0", "\"turn\":1")
    of 1:
      doAssert request.startsWith("GET /variant.json?v=map+1%2B2 ")
      response = """{"name":"Classic"}"""
    of 2, 12:
      doAssert request.startsWith("GET /game.json?v=board-1 ")
      response = """{"turn":0,"phase":"Diplomacy"}"""
      if i == 12:
        response = """{"turn":1,"phase":"Diplomacy"}"""
    of 3, 5, 7, 8, 9, 10, 15:
      doAssert request.startsWith("POST /api.php?route=game/orders ")
      let payload = body.fromJson(JsonNode)
      doAssert payload["gameID"].getInt() == 1
      doAssert payload["countryID"].getInt() == 2
      doAssert payload["turn"].getInt() == 0
      doAssert payload["phase"].getStr() == "Diplomacy"
      if i in [5, 7, 8]:
        doAssert payload["ready"].getStr() == "Yes"
        doAssert payload["orders"].len == 0
      else:
        doAssert payload["ready"].getStr() == "No"
        doAssert payload["orders"].len > 0
      response = OrderBody
      if i == 9:
        response = """[{"type":"Hold","terrID":1}]"""
      if i == 15:
        let
          army = payload["orders"][0]
          fleet = payload["orders"][1]
        doAssert army["convoyPath"] == %*[1, 4]
        doAssert army["viaConvoy"].getStr() == "Yes"
        doAssert fleet["type"].getStr() == "Convoy"
        doAssert fleet["convoyPath"] == army["convoyPath"]
        doAssert fleet["terrID"].getInt() == 4
        doAssert fleet["fromTerrID"].getInt() == 1
        doAssert fleet["toTerrID"].getInt() == 2
        response = """[
          {"type":"Move","terrID":1,"toTerrID":2,"viaConvoy":true},
          {"type":"Convoy","terrID":4,"toTerrID":2,"fromTerrID":1}
        ]"""
    of 6:
      doAssert request.startsWith("POST /api.php?route=game/sendmessage ")
      let payload = body.fromJson(JsonNode)
      doAssert payload["toCountryID"].getInt() == 3
      doAssert payload["message"].getStr() == "PRP (PCE (FRA ITA))"
      response = """{"messages":[]}"""
    of 13:
      doAssert request.startsWith("GET /api.php?route=game/playercontext")
      status = "404 Not Found"
      response = "Game was cancelled."
    else:
      doAssert request.startsWith("GET /api.php?route=game/playercontext")
      response = "Not JSON."
    client.send(
      "HTTP/1.1 " & status & "\r\n" &
      "Content-Type: application/json\r\nConnection: close\r\n" &
      "Content-Length: " & $response.len & "\r\n\r\n" & response
    )

proc testProtocol() =
  ## Verify actual requests, rewritten orders and a phase ending during a save.
  let server = newSocket()
  server.bindAddr(Port(0), "127.0.0.1")
  server.listen()
  let
    port = server.getLocalAddr()[1]
    config = GameConfig(
      url: "http://127.0.0.1:" & $port,
      apiKey: "test-seat",
      gameId: 1,
      countryId: 2,
      timeoutSeconds: 2
    )
    requested = OrderBody.fromJson(JsonNode)
  var worker: Thread[Socket]
  createThread(worker, serveProtocol, server)
  defer:
    joinThread(worker)
  let
    context = config.fetchContext()
    variant = config.fetchVariant(context)
    board = config.fetchBoard(context)
  doAssert variant["name"].getStr() == "Classic"
  doAssert board["turn"].getInt() == 0
  discard config.saveOrdersVerified(context, requested)
  discard config.sendPress(3, "PRP (PCE (FRA ITA))")
  discard config.markReady(context)
  discard config.saveOrdersVerified(context, newJArray())
  doAssertRaises KutuzovError:
    discard config.saveOrdersVerified(context, requested)
  # The next save advances the phase before Ready, so no Ready follows it.
  discard config.saveOrdersVerified(context, requested)
  doAssertRaises KutuzovError:
    discard config.fetchBoard(context)
  var terminalStatus = 0
  try:
    discard config.fetchContext()
  except KutuzovHttpError as error:
    terminalStatus = error.status
  doAssert terminalStatus == 404
  doAssertRaises KutuzovError:
    discard config.fetchContext()
  let convoy = %*[
    {"type": "Move", "terrID": 1, "toTerrID": 2,
      "fromTerrID": 0, "viaConvoy": "Yes", "convoyPath": [1, 4]},
    {"type": "Convoy", "terrID": 4, "toTerrID": 2,
      "fromTerrID": 1, "viaConvoy": "No", "convoyPath": [1, 4]}
  ]
  discard config.saveOrdersVerified(context, convoy, ready = false)
  doAssertRaises KutuzovError:
    discard config.sendPress(config.countryId, "Self-message.")
  doAssertRaises KutuzovError:
    discard config.sendPress(0, "")
  doAssertRaises KutuzovError:
    discard config.fetchFile(%*{"url": "https://other.example/map.json"})
  doAssertRaises KutuzovError:
    discard config.saveOrdersVerified(context, %*[{"type": "Hold"}])

echo "Testing order persistence and public file isolation"
testOrderVerification()
testProtocol()
