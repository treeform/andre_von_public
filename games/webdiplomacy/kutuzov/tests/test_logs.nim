import
  std/[json, os, strutils],
  jsony,
  ../logs

proc testRedaction() =
  ## Keep diagnostics useful without exposing nested or echoed credentials.
  let
    original = %*{
      "Authorization": "Bearer hidden-auth",
      "nested": [{
        "api_key": "hidden-key",
        "apiKey": "hidden-camel",
        "sseAuth": {"value": "hidden-sse"},
        "token": 12345,
        "headers": {"Cookie": "hidden-cookie"},
        "prompt_tokens": 200,
        "orders": [{"type": "Move", "terrID": 8, "toTerrID": 9}]
      }],
      "message": "token=hidden-query&code=429",
      "raw": "Authorization: Bearer hidden-header\nHTTP 429",
      "quoted": "{\"api_key\":\"hidden-embedded\",\"code\":401}",
      "url": "wss://user:hidden-pass@example.invalid?token=hidden-url",
      "transport": "Unable to POST https://user:pass@host/path?auth=secret",
      "usage": {"input_tokens": 200, "cached_tokens": 100},
      "spend_usd": 0.75
    }
    redacted = redactJson(original)
    serialized = $redacted
  doAssert "hidden-" notin serialized
  doAssert "12345" notin serialized
  doAssert "user:" notin serialized
  doAssert "code=429" in serialized
  doAssert "HTTP 429" in serialized
  doAssert redacted["usage"]["input_tokens"].getInt() == 200
  doAssert redacted["usage"]["cached_tokens"].getInt() == 100
  doAssert redacted["spend_usd"].getFloat() == 0.75
  doAssert redacted["nested"][0]["prompt_tokens"].getInt() == 200
  doAssert redacted["nested"][0]["orders"] == original["nested"][0]["orders"]
  doAssert original["Authorization"].getStr() == "Bearer hidden-auth"
  doAssert redactText("Bearer hidden-value denied") ==
    "Bearer [REDACTED] denied"
  doAssert redactText("Failed HTTPS://secret@host/token") ==
    "Failed [REDACTED_URL]"
  let
    saved = getEnv("OPENAI_API_KEY")
    present = existsEnv("OPENAI_API_KEY")
  putEnv("OPENAI_API_KEY", "secret-environment-credential")
  defer:
    if present:
      putEnv("OPENAI_API_KEY", saved)
    else:
      delEnv("OPENAI_API_KEY")
  registerSecret("secret-configuration-credential")
  let raw = logBody(
    "Rejected secret-environment-credential and " &
    "secret-configuration-credential with HTTP 401."
  ).getStr()
  doAssert "secret-environment-credential" notin raw
  doAssert "secret-configuration-credential" notin raw
  doAssert "HTTP 401" in raw
  doAssert logBody("{broken: token=hidden-broken}").getStr() ==
    "{broken: token=[REDACTED]}"
  registerSecret("sidecar")
  let accounting = redactJson(%*{
    "sidecar_spend_usd": 0.75,
    "sidecar": "sidecar",
    "api_key": "sidecar"
  })
  doAssert accounting.hasKey("sidecar_spend_usd")
  doAssert accounting["sidecar_spend_usd"].getFloat() == 0.75
  doAssert accounting["sidecar"].getStr() == "[REDACTED]"
  doAssert accounting["api_key"].getStr() == "[REDACTED]"

proc testBounds() =
  ## Truncate only after redaction and retain normal model request bodies.
  let
    normal = "Model context " & repeat('x', 60000)
    bounded = logBody(repeat('x', LogPayloadLimit + 100))
  doAssert logBody(normal).getStr() == normal
  doAssert bounded["truncated"].getBool()
  doAssert bounded["original_bytes"].getInt() == LogPayloadLimit + 100
  doAssert bounded["preview"].getStr().len == LogPayloadLimit
  let
    oversized = "token=hidden-value\n" & repeat('x', LogPayloadLimit + 100)
    safe = logBody(oversized)
  doAssert safe["truncated"].getBool()
  doAssert "hidden-value" notin $safe

proc testEvents() =
  ## Verify flushed JSON events, correlation, error detail, and poll dedup.
  let
    path = getTempDir() /
      ("kutuzov-log-test-" & $getCurrentProcessId() & ".jsonl")
    directory = path & ".artifacts"
    previous = stdout
    capture = open(path, fmWrite)
  configureLogs(directory)
  defer:
    configureLogs("")
    removeDir(directory)
  stdout = capture
  try:
    logEvent("test", %*{
      "Authorization": "hidden-top-level",
      "status": 503
    })
    let first = logHttpRequest("test_game", "GET", "/context", "", 5)
    logHttpResponse(first, 200, "{\"turn\":1}", deduplicate = true)
    let second = logHttpRequest("test_game", "GET", "/context", "", 5)
    logHttpResponse(second, 200, "{\"turn\":1}", deduplicate = true)
    let third = logHttpRequest("test_game", "GET", "/context", "", 5)
    logHttpResponse(third, 200, "{\"turn\":2}", deduplicate = true)
    let fourth = logHttpRequest("test_game", "POST", "/orders", "[]", 5)
    logHttpResponse(
      fourth,
      429,
      "{\"error\":{\"code\":\"rate_limit\",\"api_key\":\"hidden-key\"}}"
    )
    logHttpError(fourth, newException(IOError, "curl timeout 28"))
    logError("parse", newException(ValueError, "invalid order JSON"))
    doAssert getFileSize(path) > 0, "Logs must flush before process exit."
  finally:
    stdout = previous
    capture.close()
  let
    raw = readFile(directory / "details.jsonl")
    console = readFile(path)
  removeFile(path)
  doAssert "hidden-" notin raw
  doAssert "hidden-" notin console
  doAssert "\"body\":" notin console
  doAssert "body_sha1" in console
  var events: seq[JsonNode]
  for line in raw.splitLines():
    if line.len > 0:
      events.add(line.fromJson(JsonNode))
  doAssert events.len == 11
  for event in events:
    doAssert event["timestamp"].getStr().endsWith("Z")
    doAssert event["sequence"].getInt() > 0
    doAssert event["pid"].getInt() == getCurrentProcessId()
  doAssert events[0]["status"].getInt() == 503
  doAssert events[2]["body"]["turn"].getInt() == 1
  doAssert events[2]["elapsed_ms"].getInt() >= 0
  doAssert events[4]["body_unchanged"].getBool()
  doAssert not events[4].hasKey("body")
  doAssert events[4]["body_reference_request_id"] == events[1]["request_id"]
  doAssert events[4]["unchanged_count"].getInt() == 1
  doAssert events[6]["body"]["turn"].getInt() == 2
  doAssert not events[6]["body_unchanged"].getBool()
  doAssert events[8]["status"].getInt() == 429
  doAssert events[8]["body"]["error"]["code"].getStr() == "rate_limit"
  doAssert events[9]["event"].getStr() == "http_transport_error"
  doAssert events[9]["error_type"].getStr() == "IOError"
  doAssert events[9]["error"].getStr() == "curl timeout 28"
  doAssert events[10]["error_type"].getStr() == "ValueError"

proc testArtifacts() =
  ## Keep complete model payloads in artifacts and compact events after caps.
  let
    directory = getTempDir() /
      ("kutuzov-artifacts-" & $getCurrentProcessId())
    path = directory & ".stdout"
    previous = stdout
    capture = open(path, fmWrite)
    context = "model-context-" & repeat('x', 60000)
  configureLogs(directory)
  stdout = capture
  try:
    let request = logHttpRequest(
      "model", "POST", "/responses", $(%*{"input": context}), 45
    )
    logHttpResponse(request, 200, $(%*{
      "usage": {"input_tokens": 20000, "output_tokens": 500},
      "output": "model-answer"
    }))
    doAssert getFileSize(directory / "details.jsonl") > 60000
    doAssert getFileSize(directory / "events.jsonl") < 4000
  finally:
    stdout = previous
    capture.close()
    configureLogs("")
  let
    durable = readFile(directory / "details.jsonl")
    console = readFile(path)
  doAssert context in durable
  doAssert "model-answer" in durable
  doAssert "model-context" notin console
  doAssert "model-answer" notin console
  doAssert "response_usage" in console
  removeFile(path)
  removeDir(directory)
  let limited = open(path, fmWrite)
  configureLogs(directory, limitBytes = 2048, eventBytes = 8192)
  stdout = limited
  try:
    discard logHttpRequest(
      "model", "POST", "/responses", $(%*{"input": context}), 45
    )
    logEvent("after_body_limit", %*{"status": 200})
    doAssert getFileSize(directory / "details.jsonl") <= 2048
    doAssert "artifact_body_limit" in readFile(directory / "details.jsonl")
    doAssert "after_body_limit" in readFile(directory / "events.jsonl")
    for i in 0 ..< 50:
      logEvent("compact_test", %*{"i": i})
    doAssert getFileSize(directory / "events.jsonl") <= 8192
    doAssert "artifact_event_limit" in readFile(directory / "events.jsonl")
  finally:
    stdout = previous
    limited.close()
    configureLogs("")
    removeFile(path)
    removeDir(directory)

proc testArtifactFailure() =
  ## Keep gameplay logs flowing when artifact initialization or writes fail.
  let
    base = getTempDir() / ("kutuzov-log-failure-" & $getCurrentProcessId())
    console = open(base & ".stdout", fmWrite)
    errors = open(base & ".stderr", fmWrite)
    previousOutput = stdout
    previousErrors = stderr
  writeFile(base, "A file cannot be used as a log directory.")
  stdout = console
  stderr = errors
  try:
    configureLogs(base)
    logEvent("alive_after_init_failure")
    removeFile(base)
    configureLogs(base)
    removeDir(base)
    logEvent("alive_after_write_failure")
    logEvent("alive_after_disabled_artifact")
  finally:
    configureLogs("")
    stdout = previousOutput
    stderr = previousErrors
    console.close()
    errors.close()
  let
    output = readFile(base & ".stdout")
    diagnostics = readFile(base & ".stderr")
  doAssert "alive_after_init_failure" in output
  doAssert "alive_after_write_failure" in output
  doAssert "alive_after_disabled_artifact" in output
  doAssert "artifact_log_init_failed" in diagnostics
  doAssert "artifact_log_write_failed" in diagnostics
  removeFile(base & ".stdout")
  removeFile(base & ".stderr")

echo "Testing diagnostic logging and credential redaction"
testRedaction()
testBounds()
testEvents()
testArtifacts()
testArtifactFailure()
