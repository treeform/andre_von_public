import
  std/[algorithm, json, os, strutils, unicode, uri],
  curly, jsony,
  common, logs

const ReasonWireLimit = 640

type
  GameConfig* = object
    url*: string
    apiKey*: string
    gameId*: int
    countryId*: int
    endYear*: int
    scoring*: string
    timeoutSeconds*: int

  GameRequestSource* = enum
    GameAction, PlayerContext, PublicAsset

  KutuzovHttpError* = object of KutuzovError
    status*: int
    source*: GameRequestSource
    reason*: string
    reasonTruncated*: bool
    originalReasonBytes*: int
    orderSubmission*: bool

  KutuzovOrderError* = object of KutuzovError

  KutuzovTargetError* = object of KutuzovOrderError

proc reasonText(body: string): string {.raises: [].} =
  ## Select a plain error message without exporting response objects or HTML.
  let source = strutils.strip(body)
  if source.len == 0:
    return
  var
    selected = source
    node: JsonNode
  try:
    node = source.fromJson(JsonNode)
  except ValueError:
    if source[0] in {'{', '[', '"'}:
      return
  if not node.isNil:
    case node.kind
    of JString:
      selected = node.getStr()
    of JObject:
      let error = node{"error"}
      if not error.isNil and error.kind == JString:
        selected = error.getStr()
      elif not error.isNil and error.kind == JObject and
        not error{"message"}.isNil and error{"message"}.kind == JString:
          selected = error{"message"}.getStr()
      elif not node{"message"}.isNil and node{"message"}.kind == JString:
        selected = node{"message"}.getStr()
      else:
        return
    else:
      return
  selected = strutils.strip(redactText(selected))
  if selected.len == 0 or validateUtf8(selected) >= 0:
    return
  let lower = selected.toLowerAscii()
  if '<' in selected or '>' in selected or "&lt;" in lower or
    "&gt;" in lower:
      return
  var headerLines = 0
  for line in selected.splitLines():
    let text = strutils.strip(line).toLowerAscii()
    if text.startsWith("http/"):
      return
    let colon = text.find(':')
    if colon > 0:
      let field = text[0 ..< colon]
      var header = true
      for character in field:
        if character notin {'a' .. 'z', '0' .. '9', '-'}:
          header = false
      if header:
        inc headerLines
      if headerLines >= 2:
        return
      if field in [
        "authorization", "proxy-authorization", "cookie", "set-cookie",
        "content-type", "content-length", "content-encoding", "connection",
        "www-authenticate", "server", "date", "location", "retry-after"
      ] or field.startsWith("x-"):
          return
  selected

proc setReason(error: ref KutuzovHttpError, body: string) {.raises: [].} =
  ## Bound a redacted message by its size after two JSON string encodings.
  let text = reasonText(body)
  error.originalReasonBytes = text.len
  var length = 0
  while length < text.len:
    let
      next = length + runeLenAt(text, length)
      candidate = text[0 ..< next]
    if ($(%($(%candidate)))).len > ReasonWireLimit:
      break
    length = next
  error.reason = text[0 ..< length]
  error.reasonTruncated = length < text.len

proc number(node: JsonNode): int {.raises: [KutuzovError].} =
  ## Read an integer API field, including upstream numeric strings.
  if node.isNil or node.kind == JNull:
    return 0
  case node.kind
  of JInt:
    result = node.getInt()
  of JString:
    try:
      result = parseInt(node.getStr())
    except ValueError:
      raise newException(KutuzovError, "Invalid integer in game response.")
  else:
    raise newException(KutuzovError, "Invalid integer in game response.")

proc integerEnv(name: string, fallback = 0): int
    {.raises: [KutuzovError].} =
  ## Read a numeric game setting without printing its contents.
  try:
    result = parseInt(getEnv(name, $fallback))
  except ValueError:
    raise newException(KutuzovError, name & " must be an integer.")

proc loadGameConfig*(): GameConfig {.raises: [KutuzovError].} =
  ## Read the game credentials supplied by the upstream websocket launcher.
  result = GameConfig(
    url: getEnv("WEBDIP_URL").strip(chars = {'/'}),
    apiKey: getEnv("WEBDIP_API_KEY"),
    gameId: integerEnv("WEBDIP_GAME_ID"),
    countryId: integerEnv("WEBDIP_COUNTRY_ID"),
    endYear: integerEnv("WEBDIP_END_YEAR", 1910),
    scoring: getEnv("WEBDIP_SCORING", "sum_of_squares"),
    timeoutSeconds: integerEnv("KUTUZOV_GAME_TIMEOUT_SECONDS", 10)
  )
  if result.url.len == 0 or result.apiKey.len == 0:
    raise newException(KutuzovError,
      "WEBDIP_URL and WEBDIP_API_KEY must be supplied by the launcher.")
  if not (result.url.startsWith("http://") or
      result.url.startsWith("https://")):
    raise newException(KutuzovError, "WEBDIP_URL must be an HTTP base URL.")
  if result.gameId < 1 or result.countryId notin 1 .. 7:
    raise newException(KutuzovError, "Invalid game or country ID.")
  if result.endYear < 1901:
    raise newException(KutuzovError, "WEBDIP_END_YEAR must be at least 1901.")
  if result.timeoutSeconds notin 1 .. 30:
    raise newException(KutuzovError,
      "KUTUZOV_GAME_TIMEOUT_SECONDS must be between 1 and 30.")

proc fetch(
  config: GameConfig,
  path: string,
  body: JsonNode = nil,
  authorized = true,
  source = GameAction
): JsonNode {.raises: [KutuzovError].} =
  ## Make one bounded request without replaying potentially accepted writes.
  var
    response: Response
    headers = @[ ("Content-Type", "application/json") ]
  if authorized:
    headers.add(("Authorization", "Bearer " & config.apiKey))
  registerSecret(config.apiKey)
  let
    verb =
      if body.isNil:
        "GET"
      else:
        "POST"
    serialized =
      if body.isNil:
        ""
      else:
        $body
    request = logHttpRequest(
      "game",
      verb,
      path,
      serialized,
      config.timeoutSeconds,
      %*{
        "game_id": config.gameId,
        "country_id": config.countryId,
        "authorized": authorized,
        "request_source": $source
      }
    )
  try:
    let client = newCurly()
    defer:
      client.close()
    if body.isNil:
      response = client.get(
        config.url & path,
        headers,
        timeout = config.timeoutSeconds
      )
    else:
      response = client.post(
        config.url & path,
        headers,
        body = serialized,
        timeout = config.timeoutSeconds
      )
  except CatchableError as error:
    logHttpError(request, error)
    raise newException(KutuzovError,
      "Game request failed or timed out; refresh context before retrying.")
  logHttpResponse(
    request,
    response.code,
    response.body,
    %*{
      "content-type": response.headers["Content-Type"],
      "x-request-id": response.headers["X-Request-Id"],
      "retry-after": response.headers["Retry-After"]
    },
    deduplicate = body.isNil
  )
  if response.code < 200 or response.code >= 300:
    let error = newException(KutuzovHttpError,
      "Game request returned HTTP " & $response.code & ".")
    error.status = response.code
    error.source = source
    error.orderSubmission = path == "/api.php?route=game/orders" and
      not body.isNil and body.kind == JObject and
      not body{"orders"}.isNil and body{"orders"}.kind == JArray and
      body{"orders"}.len > 0
    if source == GameAction and response.code == 400:
      error.setReason(response.body)
    raise error
  try:
    result = fromJson(response.body)
  except CatchableError as error:
    logError("game_response_parse", error)
    raise newException(KutuzovError, "Game response was not valid JSON.")
  logEvent("game_return", %*{
    "request_id": request.id,
    "route": path,
    "json_kind": $result.kind,
    "items": result.len
  })

proc fetchContext*(config: GameConfig): JsonNode
    {.raises: [KutuzovError].} =
  ## Fetch current private context, order slots and visible press.
  result = config.fetch(
    "/api.php?route=game/playercontext&gameID=" & $config.gameId &
      "&orders=1&messages=1",
    source = PlayerContext
  )
  if result.kind != JObject or result{"game"}.isNil:
    raise newException(KutuzovError, "Game context is missing its game.")

proc fetchFile*(config: GameConfig, reference: JsonNode): JsonNode
    {.raises: [KutuzovError].} =
  ## Fetch a referenced public snapshot without forwarding seat credentials.
  let
    path = reference{"url"}.getStr()
    version = reference{"version"}.getStr()
  if path.len == 0 or path.contains("://") or path.startsWith("//") or
      path.contains('\\') or path.contains(".."):
    raise newException(KutuzovError, "Invalid public game file reference.")
  var target = "/" & path.strip(chars = {'/'})
  if version.len > 0:
    target.add(if '?' in target: "&v=" else: "?v=")
    target.add(encodeUrl(version))
  config.fetch(target, authorized = false, source = PublicAsset)

proc fetchVariant*(config: GameConfig, context: JsonNode): JsonNode
    {.raises: [KutuzovError].} =
  ## Fetch the static map and its territory identifiers and borders.
  config.fetchFile(context{"files", "variant"})

proc fetchBoard*(config: GameConfig, context: JsonNode): JsonNode
    {.raises: [KutuzovError].} =
  ## Fetch the public board and reject a snapshot from another phase.
  result = config.fetchFile(context{"files", "game"})
  if number(result{"turn"}) != number(context{"game", "turn"}) or
      result{"phase"}.getStr() != context{"game", "phase"}.getStr():
    raise newException(KutuzovError,
      "Game phase changed while fetching the board; refresh context.")

proc orderSignature(order: JsonNode): string {.raises: [KutuzovError].} =
  ## Compare only fields that determine an order's meaning.
  if order.isNil or order.kind != JObject:
    raise newException(KutuzovError, "Order must be a JSON object.")
  let kind = order{"type"}.getStr()
  result = kind
  case kind
  of "Wait":
    discard
  of "Build Army", "Build Fleet", "Destroy":
    result.add(":" & $number(order{"toTerrID"}))
  of "Hold", "Disband":
    result.add(":" & $number(order{"terrID"}))
  of "Move", "Retreat", "Support hold", "Support move", "Convoy":
    result.add(":" & $number(order{"terrID"}))
    result.add(":" & $number(order{"toTerrID"}))
    if kind in ["Support move", "Convoy"]:
      result.add(":" & $number(order{"fromTerrID"}))
    if kind == "Move":
      let convoy = order{"viaConvoy"}
      result.add(":" & $(convoy.getBool() or convoy.getStr() == "Yes"))
  else:
    raise newException(KutuzovError, "Unknown order type: " & kind & ".")

proc requestedSignature(order: JsonNode): string {.raises: [KutuzovError].} =
  ## Distinguish a malformed requested order from an unconfirmed server reply.
  try:
    result = orderSignature(order)
    let
      kind = order{"type"}.getStr()
      origin = number(order{"terrID"})
    if (kind == "Support hold" and
      origin == number(order{"toTerrID"})) or
      (kind == "Support move" and
      origin == number(order{"fromTerrID"})):
        raise newException(KutuzovTargetError,
          "A unit cannot support itself. Check the supporter's origin.")
  except KutuzovError as error:
    raise newException(KutuzovOrderError, error.msg)

proc savedSignature(order: JsonNode): string {.raises: [KutuzovError].} =
  ## Reject incomplete saved-order identities before comparing their meaning.
  result = orderSignature(order)
  var fields: seq[string]
  case order{"type"}.getStr()
  of "Wait":
    discard
  of "Build Army", "Build Fleet", "Destroy":
    fields = @["toTerrID"]
  of "Hold", "Disband":
    fields = @["terrID"]
  of "Move", "Retreat", "Support hold":
    fields = @["terrID", "toTerrID"]
  of "Support move", "Convoy":
    fields = @["terrID", "toTerrID", "fromTerrID"]
  else:
    discard
  for field in fields:
    if order{field}.isNil or order{field}.kind == JNull:
      if field in ["toTerrID", "fromTerrID"] and
        number(order{"terrID"}) > 0:
          raise newException(
            KutuzovTargetError,
            "Server did not accept " & order{"type"}.getStr() &
              " from " & $number(order{"terrID"}) & ": missing " &
              field & ". Check exact unit/coast adjacency and current " &
              "retreat restrictions. Change the rejected order; do not " &
              "repeat it unchanged."
          )
      raise newException(KutuzovError, "Saved order is missing " & field & ".")

proc verifyOrders*(requested, saved: JsonNode, slots = -1)
    {.raises: [KutuzovError].} =
  ## Reject silent order rewrites, including duplicate or missing orders.
  if requested.isNil or requested.kind != JArray:
    raise newException(KutuzovOrderError, "Orders must be JSON arrays.")
  if saved.isNil or saved.kind != JArray:
    raise newException(KutuzovError, "Orders must be JSON arrays.")
  if requested.len == 0:
    return
  var
    expected: seq[string]
    actual: seq[string]
    wait = false
  for order in requested:
    let signature = requestedSignature(order)
    if signature == "Wait":
      wait = true
    else:
      expected.add(signature)
  if wait:
    let count =
      if slots < 0:
        saved.len
      else:
        slots
    if expected.len > count:
      raise newException(
        KutuzovOrderError,
        "More orders than adjustment slots."
      )
    while expected.len < count:
      expected.add("Wait")
  for order in saved:
    actual.add(savedSignature(order))
  expected.sort()
  actual.sort()
  if expected != actual:
    var
      missing = expected
      unexpected: seq[string]
    for signature in actual:
      let index = missing.find(signature)
      if index < 0:
        unexpected.add(signature)
      else:
        missing.delete(index)
    raise newException(KutuzovOrderError,
      "Server changed orders. Not accepted: " & missing.join(", ") &
      "; unexpected saved: " & unexpected.join(", ") &
      ". Correct these orders against the current board and exact " &
      "unit/coast connections; do not repeat the rejected set unchanged.")

proc markReady*(config: GameConfig, context: JsonNode): JsonNode
    {.raises: [KutuzovError].} =
  ## Mark the supplied phase Ready without changing any saved orders.
  config.fetch("/api.php?route=game/orders", %*{
    "gameID": config.gameId,
    "countryID": config.countryId,
    "turn": number(context{"game", "turn"}),
    "phase": context{"game", "phase"}.getStr(),
    "orders": [],
    "ready": "Yes"
  })

proc saveOrdersVerified*(
  config: GameConfig,
  context: JsonNode,
  orders: JsonNode,
  ready = true
): JsonNode {.raises: [KutuzovError].} =
  ## Save without Ready, verify persisted orders, then mark the same phase Ready.
  if orders.isNil or orders.kind != JArray:
    raise newException(KutuzovOrderError, "Orders must be a JSON array.")
  if orders.len == 0 and ready:
    return config.markReady(context)
  for order in orders:
    for field in ["type", "terrID", "toTerrID", "fromTerrID", "viaConvoy"]:
      if order.kind != JObject or not order.hasKey(field):
        raise newException(KutuzovOrderError, "Order is missing " & field & ".")
    discard requestedSignature(order)
  let
    turn = number(context{"game", "turn"})
    phase = context{"game", "phase"}.getStr()
    body = %*{
      "gameID": config.gameId,
      "countryID": config.countryId,
      "turn": turn,
      "phase": phase,
      "orders": orders,
      "ready": "No"
    }
  result = config.fetch("/api.php?route=game/orders", body)
  try:
    verifyOrders(orders, result, context{"orders", "orders"}.len)
  except KutuzovError as error:
    logError("orders_verification", error)
    raise error
  logEvent("orders_verified", %*{
    "game_id": config.gameId,
    "country_id": config.countryId,
    "turn": turn,
    "phase": phase,
    "requested_count": orders.len,
    "saved_count": result.len
  })
  if ready:
    let latest = config.fetchContext()
    if number(latest{"game", "turn"}) != turn or
        latest{"game", "phase"}.getStr() != phase:
      logEvent("ready_skipped_phase_changed", %*{
        "turn": turn,
        "phase": phase,
        "current_turn": latest{"game", "turn"},
        "current_phase": latest{"game", "phase"}
      })
      return
    discard config.markReady(latest)

proc finishOrdersVerified*(
  config: GameConfig,
  context, verified: JsonNode,
  allowDefault = false
): JsonNode {.raises: [KutuzovError].} =
  ## Refresh the phase and restore the last verified set before Ready.
  let
    turn = number(context{"game", "turn"})
    phase = context{"game", "phase"}.getStr()
    planned = not verified.isNil and verified.kind == JArray and
      verified.len > 0
  var latest = config.fetchContext()
  proc changed(): bool =
    ## Detect a phase transition without substituting its orders.
    number(latest{"game", "turn"}) != turn or
      latest{"game", "phase"}.getStr() != phase
  proc logChanged() =
    ## Record a normal transition instead of reporting a failed decision.
    logEvent("ready_skipped_phase_changed", %*{
      "turn": turn, "phase": phase,
      "current_turn": latest{"game", "turn"},
      "current_phase": latest{"game", "phase"}
    })
  if changed():
    logChanged()
    return nil
  let slots = latest{"orders", "orders"}
  if slots.isNil or slots.kind != JArray:
    raise newException(KutuzovError, "Ready needs current order slots.")
  if not planned and slots.len > 0 and not allowDefault:
    raise newException(KutuzovError,
      "Ready requires a complete verified model order set.")
  if planned:
    try:
      verifyOrders(verified, slots, slots.len)
    except KutuzovError:
      logEvent("orders_restore", %*{
        "phase": $turn & ":" & phase,
        "reason": "current_set_not_verified", "orders": verified
      })
      discard config.saveOrdersVerified(latest, verified, ready = false)
      latest = config.fetchContext()
      if changed():
        logChanged()
        return nil
      verifyOrders(verified, latest{"orders", "orders"}, slots.len)
  try:
    result = config.markReady(latest)
  except KutuzovHttpError as error:
    if error.status != 400 or error.orderSubmission:
      raise error
    # A rejected Ready can race adjudication even after the fresh read.
    latest = config.fetchContext()
    if changed():
      logChanged()
      return nil
    raise error
  if planned:
    verifyOrders(verified, result, slots.len)

proc sendPress*(config: GameConfig, recipient: int, message: string): JsonNode
    {.raises: [KutuzovError].} =
  ## Send one public or private message without retrying ambiguous timeouts.
  if recipient notin 0 .. 7 or recipient == config.countryId:
    raise newException(KutuzovError, "Invalid press recipient.")
  if message.len == 0 or message.len > 65000:
    raise newException(KutuzovError, "Press must contain 1 to 65000 bytes.")
  config.fetch("/api.php?route=game/sendmessage", %*{
    "gameID": config.gameId,
    "countryID": config.countryId,
    "toCountryID": recipient,
    "message": message
  })
