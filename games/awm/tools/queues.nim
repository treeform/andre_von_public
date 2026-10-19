import std/[json, monotimes, os, osproc, sets, strutils, tempfiles, times]

const
  PollMilliseconds = 45_000

type
  AwmError* = object of CatchableError
  QueueCommand* = enum
    CreateRequest, ReadRequest
  QueueReply* = object
    code*: int
    output*: string
  QueueTransport* = proc(
    command: QueueCommand, argument: string
  ): QueueReply {.closure.}
  QueueRequest* = object
    source*, frozen*, created*, saved*: string
    id*, label*, status*, version*: string
    episodes*, completed*, failed*, running*: int
  QueueTotals* = object
    admitted*, awaiting*, pending*, completed*, failed*: int
    completedEpisodes*, failedEpisodes*, episodes*: int

proc readText(path: string): string =
  ## Reads a saved artifact without exposing its contents in diagnostics.
  try:
    result = readFile(path)
  except IOError as error:
    raise newException(AwmError, "Cannot read " & path & ": " & error.msg)

proc saveText(path, body: string) =
  ## Atomically saves a complete response using a process-private temporary file.
  let partial = path & "." & $getCurrentProcessId() & ".partial"
  try:
    writeFile(partial, body)
    moveFile(partial, path)
  except IOError, OSError:
    raise newException(AwmError, "Cannot save " & path)

proc jsonBody(output: string): tuple[node: JsonNode, raw: string] =
  ## Accepts a complete JSON response after optional CLI installation messages.
  let
    first = output.find('{')
    last = output.rfind('}')
  if first < 0 or last < first:
    raise newException(AwmError, "CLI returned no JSON object")
  result.raw = output[first .. last]
  try:
    result.node = parseJson(result.raw)
  except JsonParsingError:
    raise newException(AwmError, "CLI returned invalid JSON")
  if result.node.kind != JObject:
    raise newException(AwmError, "CLI returned a non-object response")

proc savedBody(path: string): JsonNode =
  ## Resumes valid saved IDs while allowing old failed CLI artifacts to be retried.
  if not fileExists(path):
    return nil
  let raw = readText(path)
  try:
    result = jsonBody(raw).node
  except AwmError:
    return nil

proc requestId(node: JsonNode): string =
  ## Recognizes a saved request ID before any creation attempt.
  if node != nil and node.hasKey("id") and node["id"].kind == JString:
    let id = node["id"].getStr()
    if not id.startsWith("xreq_") or id.len != 41:
      return ""
    for i in 0 ..< 36:
      if i in [8, 13, 18, 23]:
        if id[i + 5] != '-':
          return ""
      elif id[i + 5] notin {'0' .. '9', 'a' .. 'f'}:
        return ""
    return id

proc terminal(request: QueueRequest): bool =
  ## Treats successful, failed and cancelled batches as finished work.
  request.status in ["completed", "failed", "cancelled", "canceled"]

proc count(node: JsonNode, name: string): int =
  ## Reads nonnegative episode counts without guessing malformed numbers.
  if not node.hasKey(name):
    return 0
  if node[name].kind != JInt or node[name].getInt() < 0:
    raise newException(AwmError, "Invalid request count " & name)
  node[name].getInt()

proc update(request: var QueueRequest, node: JsonNode) =
  ## Requires one stable ID and keeps all displayed status fields explicit.
  let id = requestId(node)
  if id.len == 0 or (request.id.len > 0 and request.id != id):
    raise newException(AwmError, "Missing or changed experience request ID")
  if not node.hasKey("status") or node["status"].kind != JString:
    raise newException(AwmError, "Missing request status")
  let status = node["status"].getStr()
  if status.len notin 1 .. 32:
    raise newException(AwmError, "Invalid request status")
  for character in status:
    if character notin {'a' .. 'z', '_'}:
      raise newException(AwmError, "Invalid request status")
  request.id = id
  request.status = status
  request.completed = node.count("completed_count")
  request.failed = node.count("failed_count")
  request.running = node.count("running_count")
  if node.hasKey("episode_count"):
    request.episodes = node.count("episode_count")
  if node.hasKey("coworld_version") and
    node["coworld_version"].kind == JString:
      request.version = node["coworld_version"].getStr()

proc loadQueue*(paths: seq[string], directory: string): seq[QueueRequest] =
  ## Freezes source bytes and resumes saved admissions in the requested order.
  var
    seen = initHashSet[string]()
    keys = initHashSet[string]()
  for i, path in paths:
    let
      absolute = absolutePath(path)
      parts = splitFile(absolute)
    if not parts.name.startsWith("request_") or absolute in seen:
      raise newException(AwmError, "Expected distinct request_ JSON paths")
    seen.incl(absolute)
    let
      raw = readText(absolute)
      body = jsonBody(raw).node
    if not body.hasKey("idempotency_key") or
      body["idempotency_key"].kind != JString or
      body["idempotency_key"].getStr().len == 0:
        raise newException(AwmError, "Request needs an immutable idempotency key")
    let key = body["idempotency_key"].getStr()
    if key in keys:
      raise newException(AwmError, "Duplicate request idempotency key")
    keys.incl(key)
    let suffix = parts.name["request_".len .. ^1] & parts.ext
    var request = QueueRequest(
      source: absolute,
      frozen: directory / ($i & ".json"),
      created: parts.dir / ("created_" & suffix),
      saved: parts.dir / ("status_" & suffix),
      episodes: body.count("num_episodes"),
      label: "request"
    )
    saveText(request.frozen, raw)
    if body.hasKey("roster") and body["roster"].kind == JArray and
      body["roster"].len > 0 and body["roster"][0].kind == JObject:
        let player = body["roster"][0].getOrDefault("player")
        if player != nil and player.kind == JObject:
          let reference = player.getOrDefault("policy_ref")
          if reference != nil and reference.kind == JString:
            let text = reference.getStr()
            if text.contains(":v") and '/' notin text and '\n' notin text:
              request.label = text
    let
      created = savedBody(request.created)
      saved = savedBody(request.saved)
    if requestId(created).len > 0:
      request.id = requestId(created)
      if created.hasKey("status"):
        request.update(created)
    if requestId(saved).len > 0:
      request.update(saved)
    result.add(request)

proc totals*(requests: seq[QueueRequest]): QueueTotals =
  ## Counts requests and episodes separately for an exact bounded-run report.
  for request in requests:
    result.episodes += request.episodes
    result.completedEpisodes += request.completed
    result.failedEpisodes += request.failed
    if request.id.len > 0:
      inc result.admitted
    else:
      inc result.awaiting
    if request.status == "completed":
      inc result.completed
    elif request.terminal():
      inc result.failed
    else:
      inc result.pending

proc limited(reply: QueueReply): bool =
  ## Identifies explicit rate-limit responses without retrying unrelated errors.
  reply.code != 0 and (reply.output.contains("429") or
    reply.output.toLowerAscii().contains("too many undispatched"))

proc show(request: QueueRequest) =
  ## Prints only request identity, versions, status and episode counts.
  echo request.id, " ", request.label, " game=", request.version,
    " ", request.status, " complete=", request.completed, "/",
    request.episodes, " running=", request.running, " failed=", request.failed

proc queuePass*(
  requests: var seq[QueueRequest], transport: QueueTransport
): bool =
  ## Polls admitted requests then admits in order, stopping the pass on a 429.
  for request in requests.mitems:
    if request.id.len == 0 or request.terminal():
      continue
    let reply = transport(ReadRequest, request.id)
    if reply.limited():
      return true
    if reply.code != 0:
      raise newException(AwmError, "Request status CLI failed for " & request.id)
    let body = jsonBody(reply.output)
    request.update(body.node)
    saveText(request.saved, body.raw)
    request.show()
  for request in requests.mitems:
    if request.id.len > 0:
      continue
    let reply = transport(CreateRequest, request.frozen)
    if reply.limited():
      return true
    if reply.code != 0:
      raise newException(AwmError, "Request creation CLI failed")
    let body = jsonBody(reply.output)
    request.update(body.node)
    saveText(request.created, body.raw)
    request.show()

proc execute(command: QueueCommand, argument: string): QueueReply =
  ## Uses the stable CLI while retaining raw output only for saved JSON artifacts.
  let verb = if command == CreateRequest: "create" else: "get"
  let reply = execCmdEx(
    "uvx --from " &
      quoteShell("/Users/me/p/metta-coworld-cli/packages/coworld[auth]") &
      " coworld --elevated xp-request " & verb & " " &
      quoteShell(argument) & " --json",
    options = {poUsePath, poStdErrToStdOut, poEvalCommand}
  )
  QueueReply(code: reply.exitCode, output: reply.output)

proc main() =
  ## Runs until its deadline or all supplied batches reach a terminal state.
  if paramCount() < 2:
    raise newException(AwmError,
      "Usage: queues DEADLINE_SECONDS request_NAME.json [...]")
  let seconds =
    try:
      parseInt(paramStr(1))
    except ValueError:
      raise newException(AwmError, "Invalid deadline seconds")
  if seconds < 1 or seconds > 86_400:
    raise newException(AwmError, "Deadline must be 1..86400 seconds")
  var paths: seq[string]
  for i in 2 .. paramCount():
    paths.add(paramStr(i))
  let
    directory = createTempDir("awm-queue-", "")
    deadline = getMonoTime() + initDuration(seconds = seconds)
  defer:
    removeDir(directory)
  var requests = loadQueue(paths, directory)
  let transport: QueueTransport = proc(
    command: QueueCommand, argument: string
  ): QueueReply =
    if getMonoTime() >= deadline:
      raise newException(AwmError, "Queue deadline reached before CLI call")
    execute(command, argument)
  while getMonoTime() < deadline:
    let counts = requests.totals()
    if counts.pending == 0:
      break
    try:
      if requests.queuePass(transport):
        echo "Rate limited; admission paused until the next pass"
    except AwmError as error:
      if error.msg == "Queue deadline reached before CLI call":
        break
      raise
    let remaining = (deadline - getMonoTime()).inMilliseconds
    if remaining <= 0 or requests.totals().pending == 0:
      break
    sleep(min(PollMilliseconds.int64, remaining).int)
  let counts = requests.totals()
  echo "Queue totals: admitted=", counts.admitted,
    " awaiting=", counts.awaiting, " pending=", counts.pending,
    " completed=", counts.completed, " failed=", counts.failed,
    " episodes=", counts.completedEpisodes, "/", counts.episodes,
    " failedEpisodes=", counts.failedEpisodes

when isMainModule:
  main()
