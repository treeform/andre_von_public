import
  std/[json, monotimes, os, sha1, strutils, times],
  jsony

const
  LogPayloadLimit* = 262144
  LogCacheLimit* = 64
  LogFileLimit* = 128 * 1024 * 1024
  LogEventsLimit* = 32 * 1024 * 1024
  SecretLimit = 32
  SecretNames = [
    "WEBDIP_API_KEY", "OPENAI_API_KEY", "COWORLD_API_KEY",
    "COWORLD_TOKEN", "COWORLD_WS_URL", "COWORLD_WEBSOCKET_URL",
    "COWORLD_PLAYER_WS_URL"
  ]

type
  RequestLog* = object
    id*: int
    scope*: string
    verb*: string
    route*: string
    started: MonoTime

  ResponseLog = object
    route: string
    digest: SecureHash
    requestId: int
    repeats: int

var
  requestCount = 0
  eventCount = 0
  secrets: seq[string]
  responses: seq[ResponseLog]
  logDirectory = ""
  logInitialized = false
  logBytes: int64
  compactBytes: int64
  logLimit = LogFileLimit
  compactLimit = LogEventsLimit
  logCapped = false
  compactCapped = false
  logFailed = false

proc secretKey(name: string): bool {.raises: [].} =
  ## Recognize credentials without confusing token accounting fields.
  var normalized = ""
  for character in name:
    if character notin {'_', '-', ' '}:
      normalized.add(character.toLowerAscii())
  normalized in [
    "authorization", "proxyauthorization", "apikey", "token", "authtoken",
    "accesstoken", "refreshtoken", "idtoken", "sseauth", "secret",
    "clientsecret", "password", "passwd", "cookie", "setcookie",
    "credential", "credentials", "webdipapikey", "openaiapikey",
    "auth", "xapikey", "xauthtoken", "sessionkey", "accesskey",
    "coworldwsurl", "coworldwebsocketurl"
  ]

proc registerSecret*(secret: string) {.raises: [].} =
  ## Retain a bounded set of credential values for raw error redaction.
  if secret.len > 0 and secret notin secrets:
    if secrets.len == SecretLimit:
      secrets.delete(0)
    secrets.add(secret)

proc redactText*(value: string): string {.raises: [].} =
  ## Remove known credentials, credential assignments, and absolute URLs.
  var source = value
  for secret in secrets:
    source = source.replace(secret, "[REDACTED]")
  for name in SecretNames:
    let secret = getEnv(name)
    if secret.len > 0:
      source = source.replace(secret, "[REDACTED]")
  var i = 0
  while i < source.len:
    let prefix =
      if source[i].toLowerAscii() in {'h', 'w'}:
        source[i ..< min(i + 8, source.len)].toLowerAscii()
      else:
        ""
    if prefix.startsWith("https://") or prefix.startsWith("http://") or
      prefix.startsWith("wss://") or prefix.startsWith("ws://"):
        result.add("[REDACTED_URL]")
        while i < source.len and source[i] notin {
          ' ', '\t', '\r', '\n', '"', '\'', '<', '>'
        }:
          inc i
        continue
    if source[i] in {'a' .. 'z', 'A' .. 'Z', '_'}:
      let start = i
      while i < source.len and source[i] in {
        'a' .. 'z', 'A' .. 'Z', '0' .. '9', '_', '-'
      }:
        inc i
      let name = source[start ..< i]
      result.add(name)
      var separator = i
      if separator < source.len and source[separator] in {'"', '\''}:
        inc separator
      while separator < source.len and source[separator] in {' ', '\t'}:
        inc separator
      let bearer = name.toLowerAscii() in ["bearer", "basic"]
      if bearer and separator > i:
        result.add(" [REDACTED]")
        i = separator
        while i < source.len and source[i] notin {
          ' ', '\t', '\r', '\n', '"', '\'', ',', ';', '}', '&'
        }:
          inc i
      elif secretKey(name) and separator < source.len and
        source[separator] in {':', '='}:
          inc separator
          while separator < source.len and source[separator] in {' ', '\t'}:
            inc separator
          result.add(source[i ..< separator])
          i = separator
          if i < source.len and source[i] in {'"', '\''}:
            let quote = source[i]
            result.add(quote)
            result.add("[REDACTED]")
            inc i
            while i < source.len:
              if source[i] == '\\' and i + 1 < source.len:
                inc i, 2
              elif source[i] == quote:
                result.add(quote)
                inc i
                break
              else:
                inc i
          else:
            result.add("[REDACTED]")
            while i < source.len and source[i] notin {
              '\r', '\n', '"', '\'', ',', ';', '}', '&'
            }:
              inc i
    else:
      result.add(source[i])
      inc i

proc redactJson*(node: JsonNode, depth = 0): JsonNode {.raises: [].} =
  ## Copy JSON while redacting nested credentials and untrusted strings.
  if node.isNil:
    return newJNull()
  if depth >= 64:
    return %"[DEPTH_LIMIT]"
  case node.kind
  of JObject:
    result = newJObject()
    for key, value in node:
      if secretKey(key):
        result[key] = %"[REDACTED]"
      else:
        result[key] = redactJson(value, depth + 1)
  of JArray:
    result = newJArray()
    for value in node:
      result.add(redactJson(value, depth + 1))
  of JString:
    result = %redactText(node.getStr())
  else:
    result = node

proc logBody*(body: string): JsonNode {.raises: [].} =
  ## Preserve response content with explicit bounds after credential removal.
  if body.len == 0:
    return %""
  var safe: JsonNode
  try:
    safe = redactJson(body.fromJson(JsonNode))
  except ValueError:
    safe = %redactText(body)
  let serialized = $safe
  if serialized.len <= LogPayloadLimit:
    return safe
  %*{
    "truncated": true,
    "original_bytes": body.len,
    "redacted_bytes": serialized.len,
    "preview": serialized[0 ..< LogPayloadLimit]
  }

proc logFailure(event: string) {.raises: [].} =
  ## Report unavailable logging without exposing filesystem or error details.
  try:
    stderr.writeLine("{\"event\":\"" & event & "\"}")
    stderr.flushFile()
  except CatchableError:
    discard

proc configureLogs*(
  directory: string,
  limitBytes = LogFileLimit,
  eventBytes = LogEventsLimit
) {.raises: [].} =
  ## Configure bounded durable files before emitting the first policy event.
  logDirectory = directory
  logInitialized = true
  logLimit = max(2048, min(LogFileLimit, limitBytes))
  compactLimit = max(2048, min(LogEventsLimit, eventBytes))
  logBytes = 0
  compactBytes = 0
  logCapped = false
  compactCapped = false
  logFailed = false
  if directory.len == 0:
    return
  try:
    createDir(directory)
    let
      full = directory / "details.jsonl"
      compact = directory / "events.jsonl"
    if fileExists(full):
      logBytes = getFileSize(full)
    if fileExists(compact):
      compactBytes = getFileSize(compact)
    logCapped = logBytes >= logLimit
    compactCapped = compactBytes >= compactLimit
  except CatchableError:
    logFailed = true
    logFailure("artifact_log_init_failed")

proc compactRecord(record: JsonNode): JsonNode {.raises: [].} =
  ## Keep console and durable summaries small while hashing omitted payloads.
  result = newJObject()
  for key, value in record:
    if key in ["body", "orders", "press", "memory", "text", "stack", "preview"]:
      let serialized = $value
      result[key & "_logged_bytes"] = %serialized.len
      result[key & "_sha1"] = %($secureHash(serialized))
      result[key & "_omitted"] = %true
    elif value.kind == JString and value.getStr().len > 2048:
      result[key] = %(value.getStr()[0 ..< 2048])
      result[key & "_truncated"] = %true
    else:
      result[key] = value
  if record{"event"}.getStr() == "http_response":
    let body = record{"body"}
    if body != nil and body.kind == JObject:
      for key in ["usage", "model", "error"]:
        let value = body.getOrDefault(key)
        if value != nil:
          let serialized = $value
          result["response_" & key] =
            if serialized.len <= 4096:
              value
            else:
              %*{
                "omitted": true, "bytes": serialized.len,
                "sha1": $secureHash(serialized)
              }

proc appendLog(
  path, line: string,
  written: var int64,
  limit: int,
  capped: var bool,
  marker: string
): bool {.raises: [IOError].} =
  ## Append and flush until the cap, preserving space for an explicit marker.
  if capped:
    return false
  let output = open(path, fmAppend)
  defer:
    output.close()
  if written + line.len + 1 + 1024 > limit:
    if written + marker.len + 1 <= limit:
      output.writeLine(marker)
      output.flushFile()
      written += marker.len + 1
    capped = true
    return false
  output.writeLine(line)
  output.flushFile()
  written += line.len + 1
  result = true

proc logEvent*(event: string, fields: JsonNode = nil) {.raises: [].} =
  ## Flush redacted payloads to artifacts and compact metadata to stdout.
  try:
    if not logInitialized:
      configureLogs(getEnv(
        "KUTUZOV_LOG_DIR", getTempDir() / "kutuzov" / "logs"
      ))
    inc eventCount
    let record = %*{
      "timestamp": now().utc.format("yyyy-MM-dd'T'HH:mm:ss'.'fff'Z'"),
      "event": redactText(event),
      "sequence": eventCount,
      "pid": getCurrentProcessId()
    }
    if fields != nil and fields.kind == JObject:
      for key, value in redactJson(fields):
        record[key] = value
    var serialized = $record
    if serialized.len > LogPayloadLimit + 4096:
      serialized = $(%*{
          "timestamp": record["timestamp"],
          "event": record["event"],
          "sequence": eventCount,
          "pid": getCurrentProcessId(),
          "truncated": true,
          "original_bytes": serialized.len,
          "preview": serialized[0 ..< LogPayloadLimit]
        })
    let compact = compactRecord(record)
    compact["artifact_detail_available"] = %false
    if logDirectory.len > 0 and not logFailed:
      try:
        let
          fullMarker = $(%*{
            "event": "artifact_body_limit", "limit_bytes": logLimit,
            "timestamp": record["timestamp"], "sequence": eventCount,
            "pid": getCurrentProcessId()
          })
          compactMarker = $(%*{
            "event": "artifact_event_limit", "limit_bytes": compactLimit,
            "timestamp": record["timestamp"], "sequence": eventCount,
            "pid": getCurrentProcessId()
          })
        compact["artifact_detail_available"] = %appendLog(
          logDirectory / "details.jsonl",
          serialized,
          logBytes,
          logLimit,
          logCapped,
          fullMarker
        )
        compact["artifact_body_limit_reached"] = %logCapped
        discard appendLog(
          logDirectory / "events.jsonl",
          $compact,
          compactBytes,
          compactLimit,
          compactCapped,
          compactMarker
        )
      except CatchableError:
        logFailed = true
        logFailure("artifact_log_write_failed")
    compact["artifact_event_limit_reached"] = %compactCapped
    stdout.writeLine($compact)
    stdout.flushFile()
  except CatchableError:
    logFailure("log_write_failed")

proc logError*(scope: string, error: ref Exception) {.raises: [].} =
  ## Record the original exception type, message, and available stack trace.
  if error.isNil:
    return
  logEvent("error", %*{
    "scope": scope,
    "error_type": $error.name,
    "error": error.msg,
    "stack": getStackTrace(error)
  })

proc logHttpRequest*(
  scope, verb, route, body: string,
  timeoutSeconds: int,
  fields: JsonNode = nil
): RequestLog {.raises: [].} =
  ## Start a correlated request without logging credentials or host URLs.
  inc requestCount
  result = RequestLog(
    id: requestCount,
    scope: scope,
    verb: verb,
    route: redactText(route),
    started: getMonoTime()
  )
  let payload = %*{
    "request_id": result.id,
    "scope": scope,
    "method": verb,
    "route": result.route,
    "timeout_seconds": timeoutSeconds,
    "body_bytes": body.len,
    "body": logBody(body)
  }
  if fields != nil:
    payload["context"] = fields
  logEvent("http_request", payload)

proc logHttpResponse*(
  request: RequestLog,
  status: int,
  body: string,
  headers: JsonNode = nil,
  deduplicate = false
) {.raises: [].} =
  ## Log all statuses and timing, omitting only identical polling bodies.
  let payload = %*{
    "request_id": request.id,
    "scope": request.scope,
    "method": request.verb,
    "route": request.route,
    "status": status,
    "elapsed_ms": (getMonoTime() - request.started).inMilliseconds,
    "body_bytes": body.len
  }
  var unchanged = false
  if deduplicate and status >= 200 and status < 300:
    let
      route = request.scope & ":" & request.route
      digest = secureHash(body)
    var found = -1
    for i in 0 ..< responses.len:
      if responses[i].route == route:
        found = i
        break
    if found >= 0:
      if responses[found].digest == digest:
        unchanged = true
        inc responses[found].repeats
        payload["body_reference_request_id"] = %responses[found].requestId
        payload["unchanged_count"] = %responses[found].repeats
      else:
        responses[found] = ResponseLog(
          route: route, digest: digest, requestId: request.id
        )
    else:
      if responses.len == LogCacheLimit:
        responses.delete(0)
      responses.add(ResponseLog(
        route: route, digest: digest, requestId: request.id
      ))
  payload["body_unchanged"] = %unchanged
  if not unchanged:
    payload["body"] = logBody(body)
  if headers != nil:
    payload["headers"] = headers
  logEvent("http_response", payload)

proc logHttpError*(request: RequestLog, error: ref Exception) {.raises: [].} =
  ## Preserve transport errors and elapsed time before wrapping exceptions.
  logEvent("http_transport_error", %*{
    "request_id": request.id,
    "scope": request.scope,
    "method": request.verb,
    "route": request.route,
    "elapsed_ms": (getMonoTime() - request.started).inMilliseconds,
    "error_type": $error.name,
    "error": error.msg,
    "stack": getStackTrace(error)
  })
