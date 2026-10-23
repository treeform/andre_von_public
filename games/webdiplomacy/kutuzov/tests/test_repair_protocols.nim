import
  std/[json, nativesockets, net, strutils, unicode],
  ../[common, protocols]

const
  SeatSecret = "repair-protocol-seat-secret"
  OwnershipReason = "Unknown territory ID `14` for country `3`."

type
  Action = enum
    OrdersAction, ReadyAction, PressAction

  Scenario = tuple[
    server: Socket,
    body: string,
    status: int,
    source: GameRequestSource,
    action: Action,
    disconnect: bool
  ]

proc serveFailure(args: Scenario) {.thread.} =
  ## Serve exactly one local response with finite accept and read deadlines.
  defer:
    args.server.close()
  var handles = @[args.server.getFd()]
  doAssert selectRead(handles, 3000) == 1
  var client: Socket
  args.server.accept(client)
  defer:
    client.close()
  let request = client.recvLine(timeout = 2000)
  var
    contentLength = 0
    authorization = ""
  while true:
    let header = client.recvLine(timeout = 2000)
    if header.len == 0 or header == "\r\n":
      break
    if header.toLowerAscii().startsWith("content-length:"):
      contentLength = parseInt(strutils.strip(header.split(':', 1)[1]))
    if header.toLowerAscii().startsWith("authorization:"):
      authorization = strutils.strip(header.split(':', 1)[1])
  var body = ""
  while body.len < contentLength:
    let chunk = client.recv(contentLength - body.len, timeout = 2000)
    doAssert chunk.len > 0
    body.add(chunk)
  case args.source
  of GameAction:
    doAssert authorization == "Bearer " & SeatSecret
    let payload = parseJson(body)
    case args.action
    of OrdersAction, ReadyAction:
      doAssert request.startsWith("POST /api.php?route=game/orders ")
      doAssert payload["orders"].kind == JArray
      if args.action == OrdersAction:
        doAssert payload["orders"].len > 0
        doAssert payload["ready"].getStr() == "No"
      else:
        doAssert payload["orders"].len == 0
        doAssert payload["ready"].getStr() == "Yes"
    of PressAction:
      doAssert request.startsWith("POST /api.php?route=game/sendmessage ")
      doAssert not payload.hasKey("orders")
  of PlayerContext:
    doAssert request.startsWith("GET /api.php?route=game/playercontext&")
    doAssert authorization == "Bearer " & SeatSecret
  of PublicAsset:
    doAssert request.startsWith("GET /board.json ")
    doAssert authorization.len == 0
  if args.disconnect:
    return
  client.send(
    "HTTP/1.1 " & $args.status & " Fixture\r\n" &
    "Content-Type: text/plain;charset=UTF-8\r\nConnection: close\r\n" &
    "Content-Length: " & $args.body.len & "\r\n\r\n" & args.body
  )

proc requestFailure(
  body: string,
  status = 400,
  source = GameAction,
  disconnect = false,
  action = OrdersAction
): ref KutuzovError =
  ## Return a typed failure from one loopback action, context, or asset read.
  let server = newSocket()
  server.bindAddr(Port(0), "127.0.0.1")
  server.listen()
  let
    config = GameConfig(
      url: "http://127.0.0.1:" & $server.getLocalAddr()[1],
      apiKey: SeatSecret,
      gameId: 1,
      countryId: 3,
      timeoutSeconds: 2
    )
    context = %*{
      "game": {"turn": 15, "phase": "Diplomacy"},
      "orders": {"orders": [{}]}
    }
    orders = %*[{
      "type": "Hold", "terrID": 14, "toTerrID": 0,
      "fromTerrID": 0, "viaConvoy": "No"
    }]
  var worker: Thread[Scenario]
  createThread(worker, serveFailure, (
    server: server,
    body: body,
    status: status,
    source: source,
    action: action,
    disconnect: disconnect
  ))
  defer:
    joinThread(worker)
  try:
    case source
    of GameAction:
      case action
      of OrdersAction:
        discard config.saveOrdersVerified(context, orders, ready = false)
      of ReadyAction:
        discard config.markReady(context)
      of PressAction:
        discard config.sendPress(2, "Testing invalid press.")
    of PlayerContext:
      discard config.fetchContext()
    of PublicAsset:
      discard config.fetchFile(%*{"url": "board.json"})
  except KutuzovError as error:
    result = error
  doAssert not result.isNil, "The local response must produce a failure."

proc httpFailure(
  body: string,
  status = 400,
  source = GameAction,
  action = OrdersAction
): ref KutuzovHttpError =
  ## Check the unchanged status message and preserve typed source metadata.
  let error = requestFailure(body, status, source, action = action)
  doAssert error of KutuzovHttpError
  doAssert not (error of KutuzovOrderError)
  result = (ref KutuzovHttpError)(error)
  doAssert result.msg == "Game request returned HTTP " & $status & "."
  doAssert result.status == status
  doAssert result.source == source
  doAssert result.orderSubmission ==
    (source == GameAction and action == OrdersAction)

proc testAcceptedReasons() =
  ## Preserve the ownership rejection across each allowed response shape.
  let bodies = @[
    OwnershipReason,
    $(%OwnershipReason),
    $(%*{"error": OwnershipReason}),
    $(%*{"message": OwnershipReason}),
    $(%*{"error": {"message": OwnershipReason}})
  ]
  for body in bodies:
    let error = httpFailure(body)
    doAssert error.reason == OwnershipReason
    doAssert error.originalReasonBytes == OwnershipReason.len
    doAssert not error.reasonTruncated
  let
    reason = OwnershipReason & " Credential " & SeatSecret & "."
    safe = OwnershipReason & " Credential [REDACTED]."
    error = httpFailure($(%*{
      "message": reason,
      "details": {"request_headers": {"Authorization": SeatSecret}}
    }))
  doAssert error.reason == safe
  doAssert error.originalReasonBytes == safe.len
  doAssert not error.reasonTruncated
  doAssert SeatSecret notin error.reason
  doAssert "request_headers" notin error.reason

proc testRejectedReasons() =
  ## Omit HTML, header dumps, and JSON without a permitted message field.
  let bodies = @[
    "",
    "Invalid UTF-8: \xC3\x28",
    "<html><body>" & OwnershipReason & "</body></html>",
    "<!DOCTYPE html><title>400</title>" & OwnershipReason,
    "HTTP/1.1 400 Bad Request\r\nAuthorization: Bearer " & SeatSecret &
      "\r\n\r\n" & OwnershipReason,
    "Header-One: first\r\nHeader-Two: second\r\n\r\n" & OwnershipReason,
    $(%*{"error": "<html>" & OwnershipReason & "</html>"}),
    $(%*{"message": "HTTP/1.1 400 Bad Request\r\nContent-Type: text/plain"}),
    $(%*{"details": OwnershipReason}),
    $(%*{"error": {"details": OwnershipReason}}),
    $(%*{"message": [OwnershipReason]}),
    $(%*[OwnershipReason]),
    "null",
    "true",
    "false",
    "42",
    "{broken json"
  ]
  for body in bodies:
    let error = httpFailure(body)
    doAssert error.reason.len == 0, "Unsafe response: " & body
    doAssert error.originalReasonBytes == 0
    doAssert not error.reasonTruncated

proc testBoundedReasons() =
  ## Bound escaped and multibyte reasons after redaction and two encodings.
  let
    reason = "Credential " & SeatSecret & ". " &
      repeat("é🙂\"\\", 160)
    safe = "Credential [REDACTED]. " & repeat("é🙂\"\\", 160)
    error = httpFailure($(%*{"error": {"message": reason}}))
  doAssert error.reason.len > 0
  doAssert error.reasonTruncated
  doAssert error.originalReasonBytes == safe.len
  doAssert error.reason.len < safe.len
  doAssert unicode.validateUtf8(error.reason) == -1
  doAssert ($(%($(%error.reason)))).len <= 640
  doAssert SeatSecret notin error.reason
  let
    boundary = repeat("x", 634)
    boundaryError = httpFailure($(%boundary))
  doAssert ($(%($(%boundary)))).len == 640
  doAssert boundaryError.reason == boundary
  doAssert boundaryError.originalReasonBytes == boundary.len
  doAssert not boundaryError.reasonTruncated

proc testOtherFailures() =
  ## Keep unrelated HTTP and transport failures outside order repair errors.
  for action in [ReadyAction, PressAction]:
    let error = httpFailure(OwnershipReason, action = action)
    doAssert not error.orderSubmission
    doAssert error.reason == OwnershipReason
    doAssert error.originalReasonBytes == OwnershipReason.len
    doAssert not error.reasonTruncated
  for source in [PlayerContext, PublicAsset]:
    let error = httpFailure(OwnershipReason, source = source)
    doAssert error.reason.len == 0
    doAssert error.originalReasonBytes == 0
    doAssert not error.reasonTruncated
  let error = httpFailure(OwnershipReason, status = 500)
  doAssert error.reason.len == 0
  doAssert error.originalReasonBytes == 0
  doAssert not error.reasonTruncated
  let transport = requestFailure("", disconnect = true)
  doAssert not (transport of KutuzovOrderError)
  doAssert not (transport of KutuzovHttpError)
  doAssert transport.msg ==
    "Game request failed or timed out; refresh context before retrying."

proc verificationFailure(requested, saved: JsonNode, slots = -1):
    ref KutuzovError =
  ## Return an order comparison failure for classification assertions.
  try:
    verifyOrders(requested, saved, slots)
  except KutuzovError as error:
    result = error
  doAssert not result.isNil

proc testOrderFailures() =
  ## Separate rejected requested orders from malformed server order payloads.
  let
    orders = %*[{"type": "Hold", "terrID": 1}]
    malformed = @[
      newJNull(),
      newJObject(),
      %*["not an order"],
      %*[{"type": "Unknown"}],
      %*[{"type": "Hold", "terrID": "invalid"}]
    ]
  for requested in malformed:
    doAssert verificationFailure(requested, orders) of KutuzovOrderError
  for saved in malformed:
    let error = verificationFailure(orders, saved)
    doAssert not (error of KutuzovOrderError)
    doAssert not (error of KutuzovHttpError)
  let
    missing = verificationFailure(orders, %*[{"type": "Hold"}])
    changed = verificationFailure(orders, %*[{"type": "Hold", "terrID": 2}])
    adjustment = verificationFailure(
      %*[{"type": "Build Army", "toTerrID": 7}, {"type": "Wait"}],
      newJArray(),
      0
    )
  doAssert not (missing of KutuzovOrderError)
  doAssert not (missing of KutuzovHttpError)
  doAssert changed of KutuzovOrderError
  doAssert changed.msg ==
    "Server changed orders. Not accepted: Hold:1; unexpected saved: Hold:2." &
    " Correct these orders against the current board and exact " &
    "unit/coast connections; do not repeat the rejected set unchanged."
  let missingTarget = verificationFailure(
    %*[{"type": "Retreat", "terrID": 21, "toTerrID": 28}],
    %*[{"type": "Retreat", "terrID": 21, "toTerrID": newJNull()}]
  )
  doAssert missingTarget of KutuzovOrderError
  doAssert "Retreat from 21" in missingTarget.msg
  doAssert "missing toTerrID" in missingTarget.msg
  doAssert "do not repeat" in missingTarget.msg
  doAssert adjustment of KutuzovOrderError
  doAssert adjustment.msg == "More orders than adjustment slots."
  let
    config = GameConfig()
    context = %*{"game": {"turn": 0, "phase": "Diplomacy"}}
  var missingField = ""
  try:
    discard config.saveOrdersVerified(context, %*[{"type": "Hold"}])
  except KutuzovOrderError as error:
    missingField = error.msg
  doAssert missingField == "Order is missing terrID."
  doAssertRaises KutuzovOrderError:
    discard config.saveOrdersVerified(context, newJObject())

echo "Testing bounded game rejection reasons and order error classification"
testAcceptedReasons()
testRejectedReasons()
testBoundedReasons()
testOtherFailures()
testOrderFailures()
