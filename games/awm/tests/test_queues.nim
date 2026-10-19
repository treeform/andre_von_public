import
  std/[json, os, tempfiles],
  ../tools/queues

const
  RequestIds = [
    "xreq_11111111-1111-4111-8111-111111111111",
    "xreq_22222222-2222-4222-8222-222222222222",
    "xreq_33333333-3333-4333-8333-333333333333"
  ]
  RequestKeys = [
    "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
    "cccccccc-cccc-4ccc-8ccc-cccccccccccc"
  ]

proc requestBody(index: int): string =
  ## Builds independent requests with real immutable idempotency keys.
  (%*{
    "idempotency_key": RequestKeys[index],
    "num_episodes": 10,
    "roster": [{"player": {"policy_ref": "radogost:v2"}}],
    "unknown_request_field": {"preserve": true}
  }).pretty()

proc statusBody(
  index: int, status: string, completed = 0, failed = 0
): string =
  ## Builds status replies with unknown fields that must survive storage.
  (%*{
    "id": RequestIds[index],
    "status": status,
    "episode_count": 10,
    "completed_count": completed,
    "failed_count": failed,
    "running_count": 0,
    "coworld_version": "2026.10.1.3",
    "unknown_status_field": {
      "nested": ["preserve", "every", "field"],
      "value": 123
    }
  }).pretty()

proc main() =
  ## Exercises queue transitions with callbacks and local files only.
  let directory = createTempDir("awm-queue-tests-", "")
  defer:
    removeDir(directory)
  let
    snapshot = directory / "snapshot"
    paths = @[
      directory / "request_a.json",
      directory / "request_b.json",
      directory / "request_c.json"
    ]
    bodies = [requestBody(0), requestBody(1), requestBody(2)]
    createdA = statusBody(0, "pending")
    completedA = statusBody(0, "completed", completed = 10)
    createdB = statusBody(1, "pending")
    createdC = statusBody(2, "pending")
  createDir(snapshot)
  for i, path in paths:
    writeFile(path, bodies[i])
  writeFile(directory / "created_b.json", "")
  var requests = loadQueue(paths, snapshot)
  for i, request in requests:
    doAssert request.id.len == 0
    doAssert request.label == "radogost:v2"
    doAssert request.episodes == 10
    doAssert readFile(request.frozen) == bodies[i]
  let changed = parseJson(bodies[0])
  changed["idempotency_key"] = %"dddddddd-dddd-4ddd-8ddd-dddddddddddd"
  changed["num_episodes"] = %1
  writeFile(paths[0], changed.pretty())
  doAssert readFile(requests[0].frozen) == bodies[0]
  var calls = 0
  let first: QueueTransport = proc(
    command: QueueCommand, argument: string
  ): QueueReply =
    ## Admits the first request and rate limits the second creation.
    doAssert command == CreateRequest
    doAssert calls < 2, "The third request must wait after a 429"
    doAssert argument == requests[calls].frozen
    doAssert readFile(argument) == bodies[calls]
    doAssert parseFile(argument)["idempotency_key"].getStr() ==
      RequestKeys[calls]
    inc calls
    if calls == 1:
      return QueueReply(code: 0, output: "CLI setup message\n" & createdA)
    QueueReply(code: 1, output: "HTTP 429 Too Many Requests")
  doAssert requests.queuePass(first)
  doAssert calls == 2
  doAssert requests[0].id == RequestIds[0]
  doAssert requests[1].id.len == 0
  doAssert requests[2].id.len == 0
  doAssert readFile(requests[0].created) == createdA
  doAssert readFile(requests[1].created).len == 0
  doAssert not fileExists(requests[2].created)
  let limited = requests.totals()
  doAssert limited.admitted == 1 and limited.awaiting == 2
  doAssert limited.pending == 3 and limited.completed == 0
  doAssert limited.failed == 0 and limited.episodes == 30
  echo "A 429 stops later admissions and preserves frozen request bytes."
  calls = 0
  let readLimited: QueueTransport = proc(
    command: QueueCommand, argument: string
  ): QueueReply =
    ## Rate limits status polling before any waiting request can be created.
    inc calls
    doAssert command == ReadRequest and argument == RequestIds[0]
    QueueReply(code: 1, output: "HTTP 429 Too Many Requests")
  doAssert requests.queuePass(readLimited)
  doAssert calls == 1
  doAssert requests.totals() == limited
  doAssert readFile(requests[1].created).len == 0
  doAssert not fileExists(requests[2].created)
  echo "A polling 429 blocks every waiting creation."
  calls = 0
  let second: QueueTransport = proc(
    command: QueueCommand, argument: string
  ): QueueReply =
    ## Polls the admitted request before creating the two waiting requests.
    inc calls
    case calls
    of 1:
      doAssert command == ReadRequest and argument == RequestIds[0]
      QueueReply(code: 0, output: completedA)
    of 2, 3:
      let index = calls - 1
      doAssert command == CreateRequest
      doAssert argument == requests[index].frozen
      doAssert readFile(argument) == bodies[index]
      QueueReply(code: 0, output: [createdB, createdC][index - 1])
    else:
      doAssert false, "A pass must not repeat a creation"
      QueueReply()
  doAssert not requests.queuePass(second)
  doAssert calls == 3
  doAssert readFile(requests[0].saved) == completedA
  doAssert readFile(requests[1].created) == createdB
  doAssert readFile(requests[2].created) == createdC
  doAssert parseFile(requests[0].saved)["unknown_status_field"] ==
    parseJson(completedA)["unknown_status_field"]
  let admitted = requests.totals()
  doAssert admitted.admitted == 3 and admitted.awaiting == 0
  doAssert admitted.completed == 1 and admitted.pending == 2
  doAssert admitted.completedEpisodes == 10
  echo "Successful polling precedes ordered admission and saves raw replies."
  writeFile(paths[0], bodies[0])
  let resumedSnapshot = directory / "resumed"
  createDir(resumedSnapshot)
  var resumed = loadQueue(paths, resumedSnapshot)
  for i, request in resumed:
    doAssert request.id == RequestIds[i]
    doAssert request.version == "2026.10.1.3"
  doAssert resumed[0].status == "completed"
  doAssert resumed[0].completed == 10
  doAssert resumed[1].status == "pending"
  doAssert resumed[2].status == "pending"
  let
    completedB = statusBody(1, "completed", completed = 10)
    failedC = statusBody(2, "failed", failed = 10)
  calls = 0
  let finish: QueueTransport = proc(
    command: QueueCommand, argument: string
  ): QueueReply =
    ## Resumes only outstanding reads without duplicate creation attempts.
    inc calls
    doAssert command == ReadRequest
    doAssert calls <= 2
    doAssert argument == RequestIds[calls]
    QueueReply(code: 0, output: [completedB, failedC][calls - 1])
  doAssert not resumed.queuePass(finish)
  doAssert calls == 2
  doAssert readFile(resumed[1].saved) == completedB
  doAssert readFile(resumed[2].saved) == failedC
  let finished = resumed.totals()
  doAssert finished.admitted == 3 and finished.awaiting == 0
  doAssert finished.pending == 0 and finished.completed == 2
  doAssert finished.failed == 1 and finished.episodes == 30
  doAssert finished.completedEpisodes == 20
  doAssert finished.failedEpisodes == 10
  var terminal = loadQueue(paths, resumedSnapshot)
  let idle: QueueTransport = proc(
    command: QueueCommand, argument: string
  ): QueueReply =
    ## Rejects any transport call for a fully terminal saved queue.
    doAssert false, "Terminal saved requests must not be read or recreated"
    QueueReply()
  doAssert not terminal.queuePass(idle)
  doAssert terminal.totals() == finished
  echo "Saved IDs and statuses resume without recreating admitted requests."
  let
    rejectedDirectory = directory / "rejected"
    rejectedSnapshot = rejectedDirectory / "snapshot"
  createDir(rejectedSnapshot)
  var rejectedPaths: seq[string]
  for i, path in paths:
    let rejectedPath = rejectedDirectory / path.extractFilename()
    writeFile(rejectedPath, bodies[i])
    rejectedPaths.add(rejectedPath)
  var rejected = loadQueue(rejectedPaths, rejectedSnapshot)
  calls = 0
  let denied: QueueTransport = proc(
    command: QueueCommand, argument: string
  ): QueueReply =
    ## Returns a permanent authorization failure before any admission.
    inc calls
    doAssert command == CreateRequest
    doAssert argument == rejected[0].frozen
    QueueReply(code: 1, output: "HTTP 403 Forbidden")
  var raised = false
  try:
    discard rejected.queuePass(denied)
  except AwmError:
    raised = true
  doAssert raised, "A non-rate-limit CLI error must propagate"
  doAssert calls == 1, "A 403 must stop later requests"
  doAssert rejected.totals().admitted == 0
  doAssert rejected.totals().awaiting == 3
  for request in rejected:
    doAssert not fileExists(request.created)
  echo "A 403 propagates and stops all later admissions."

main()
