import
  std/[json, os, sets, strutils],
  ../research/replays

const
  TrialMark = "MOBA_TRIAL"
  MaxTrialBytes = 8192
  MinQualify = 10

type
  MobaError = object of CatchableError
  Snapshot = object
    heroCalls, triggers, changedActions, trials: int

proc fail(message: string) =
  ## Raise MobaError with message.
  raise newException(MobaError, message)

proc isBlank(node: JsonNode): bool =
  ## True when a JSON field is missing, null, or empty text.
  node.isNil or node.kind == JNull or
    (node.kind == JString and node.getStr.len == 0)

proc hexNibble(c: char): int =
  ## Parse one hex digit, or -1.
  case c
  of '0' .. '9': ord(c) - ord('0')
  of 'a' .. 'f': 10 + ord(c) - ord('a')
  of 'A' .. 'F': 10 + ord(c) - ord('A')
  else: -1

proc unescapePython(inner: string): string =
  ## Decode a Python bytes-repr payload, including literal backslash-n.
  result = newStringOfCap(inner.len)
  var i = 0
  while i < inner.len:
    if inner[i] != '\\' or i + 1 >= inner.len:
      result.add inner[i]
      inc i
      continue
    let c = inner[i + 1]
    case c
    of 'n':
      result.add '\n'
      inc i, 2
    of 'r':
      result.add '\r'
      inc i, 2
    of 't':
      result.add '\t'
      inc i, 2
    of '\\', '\'', '"':
      result.add c
      inc i, 2
    of 'x':
      if i + 3 >= inner.len:
        fail("Truncated hex escape in log")
      let
        hi = hexNibble(inner[i + 2])
        lo = hexNibble(inner[i + 3])
      if hi < 0 or lo < 0:
        fail("Invalid hex escape in log")
      result.add char((hi shl 4) or lo)
      inc i, 4
    else:
      result.add c
      inc i, 2

proc decodeLog(raw: string): string =
  ## Unwrap a coworld CLI Python bytes repr, or return text unchanged.
  let s = raw.strip()
  if s.len >= 3 and s[0] == 'b' and s[1] in {'\'', '"'}:
    let quote = s[1]
    if s[^1] == quote:
      return unescapePython(s[2 .. ^2])
  raw

proc boundedObject(text: string, openCurly: int): string =
  ## Slice one JSON object starting at `{`, capped at MaxTrialBytes.
  if openCurly < 0 or openCurly >= text.len or text[openCurly] != '{':
    fail("MOBA_TRIAL JSON does not start with '{'")
  var
    depth = 0
    i = openCurly
    inStr = false
    escape = false
  while i < text.len and i - openCurly < MaxTrialBytes:
    let c = text[i]
    if inStr:
      if escape:
        escape = false
      elif c == '\\':
        escape = true
      elif c == '"':
        inStr = false
    else:
      if c == '"':
        inStr = true
      elif c == '{':
        inc depth
      elif c == '}':
        dec depth
        if depth == 0:
          return text[openCurly .. i]
    inc i
  fail("Unterminated or oversized MOBA_TRIAL JSON")

proc extractTrials*(text: string): seq[JsonNode] =
  ## Collect bounded MOBA_TRIAL objects from decoded or raw log text.
  let body = decodeLog(text)
  var start = 0
  while true:
    let at = body.find(TrialMark, start)
    if at < 0:
      break
    var i = at + TrialMark.len
    while i < body.len and body[i] in {' ', '\t', '\r', '\n'}:
      inc i
    if i >= body.len or body[i] != '{':
      start = at + 1
      continue
    let raw = boundedObject(body, i)
    try:
      let node = parseJson(raw)
      if node.kind != JObject:
        fail("MOBA_TRIAL payload is not an object")
      result.add node
    except MobaError:
      raise
    except CatchableError as error:
      fail("Invalid MOBA_TRIAL JSON: " & error.msg)
    start = i + raw.len

proc jsonCount(node: JsonNode, key: string, where: string): int =
  ## Read a non-negative integer telemetry counter.
  let field = node{key}
  if field.isNil or field.kind != JInt:
    fail("Missing integer " & key & " in " & where)
  result = field.getInt
  if result < 0:
    fail("Negative " & key & " in " & where)

proc snapshotOf(trials: seq[JsonNode], idea, where: string): Snapshot =
  ## Check idea and monotonic counters; keep done or latest totals.
  result.trials = trials.len
  if trials.len == 0:
    return
  var
    prevCalls = -1
    prevTriggers = -1
    prevChanged = -1
    latest = trials[^1]
  for node in trials:
    let marker = node{"idea"}
    if marker.isNil or marker.kind != JString:
      fail("Missing idea in " & where)
    if marker.getStr != idea:
      fail("Idea mismatch in " & where & ": " & marker.getStr)
    let
      calls = jsonCount(node, "heroCalls", where)
      triggers = jsonCount(node, "triggers", where)
      changed = jsonCount(node, "changedActions", where)
    if prevCalls >= 0 and (calls < prevCalls or
        triggers < prevTriggers or changed < prevChanged):
      fail("Non-monotonic counters in " & where)
    prevCalls = calls
    prevTriggers = triggers
    prevChanged = changed
    let event = node{"event"}
    let reason = node{"reason"}
    if (not event.isNil and event.getStr == "done") or
        (not reason.isNil and reason.getStr == "done"):
      latest = node
  result.heroCalls = jsonCount(latest, "heroCalls", where)
  result.triggers = jsonCount(latest, "triggers", where)
  result.changedActions = jsonCount(latest, "changedActions", where)

proc focalSeat(episode: JsonNode, label, where: string): int =
  ## Require two real distinct policies and exactly one focal seat.
  let players = episode{"participants"}
  if players.isNil or players.kind != JArray or players.len != 2:
    fail("Expected two participants: " & where)
  var
    versions: HashSet[string]
    seats: seq[int]
  for player in players:
    if player{"kind"}.getStr != "policy":
      fail("Participant is not a policy: " & where)
    let filler = player{"is_filler"}
    if not filler.isNil and filler.kind == JBool and filler.getBool:
      fail("Filler participant: " & where)
    let version = player{"policy_version_id"}.getStr
    if version.len == 0:
      fail("Missing policy version: " & where)
    if version in versions:
      fail("Duplicate policy participants: " & where)
    versions.incl version
    if player{"label"}.getStr == label:
      seats.add player{"position"}.getInt
  if seats.len != 1:
    fail("Expected exactly one focal seat: " & where)
  seats[0]

proc headerCount(resultNode: JsonNode, field: string, seat: int): int =
  ## Read one per-seat integer from the replay header result.
  let arr = resultNode{field}
  if arr.isNil or arr.kind != JArray or seat < 0 or seat >= arr.len:
    return 0
  if arr[seat].kind == JInt:
    return arr[seat].getInt
  0

proc headerDead(resultNode: JsonNode, seat: int): bool =
  ## Read one per-seat dead_seats flag from the replay header.
  let arr = resultNode{"dead_seats"}
  if arr.isNil or arr.kind != JArray or seat < 0 or seat >= arr.len:
    return false
  arr[seat].kind == JBool and arr[seat].getBool

proc headerCauses(resultNode: JsonNode, seat: int): JsonNode =
  ## Copy focal noop_causes from the replay header, or an empty object.
  let arr = resultNode{"noop_causes"}
  if arr.isNil or arr.kind != JArray or seat < 0 or seat >= arr.len:
    return newJObject()
  if arr[seat].kind == JObject:
    return arr[seat]
  newJObject()

proc loadReplay(path: string): Replay =
  ## Parse a v1 MOBA replay; positions are not stored in the body.
  if not fileExists(path):
    fail("Missing replay: " & path)
  try:
    result = parseReplay(readFile(path))
  except MobaError:
    raise
  except CatchableError as error:
    fail("Replay unreadable: " & path & ": " & error.msg)

proc verifyEpisode(
  episode: JsonNode,
  label, idea, directory: string
): JsonNode =
  ## Verify one completed episode from log telemetry and replay header.
  if episode{"status"}.getStr != "completed":
    fail("Episode incomplete: " & episode{"id"}.getStr)
  if not isBlank(episode{"error"}) or not isBlank(episode{"error_type"}):
    fail("Episode error: " & episode{"id"}.getStr)
  let
    id = episode["id"].getStr
    where = id
    seat = focalSeat(episode, label, where)
    logPath = directory / (id & ".log")
    replayPath = directory / (id & ".replay")
  if not fileExists(logPath):
    fail("Missing log: " & logPath)
  let
    snap = snapshotOf(extractTrials(readFile(logPath)), idea, where)
    replay = loadReplay(replayPath)
    header = resultOf(replay)
    noopTicks = headerCount(header, "noop_ticks", seat)
    deadSeat = headerDead(header, seat)
  %*{
    "id": id,
    "seat": seat,
    "heroCalls": snap.heroCalls,
    "triggers": snap.triggers,
    "changedActions": snap.changedActions,
    "trials": snap.trials,
    "noopTicks": noopTicks,
    "deadSeat": deadSeat,
    "noopCauses": headerCauses(header, seat),
    "activated": snap.triggers > 0,
    "changed": snap.changedActions > 0
  }

proc verifyFiles*(
  label, idea: string,
  paths: openArray[string]
): JsonNode =
  ## Verify candidate XP current.json files. Not proof of improvement.
  if label.len == 0 or idea.len == 0 or paths.len == 0:
    fail("Usage: telemetry label idea current.json [current.json ...]")
  var
    seen = initHashSet[string]()
    episodes = newJArray()
    triggeredGames = 0
    changedActions = 0
    qualifyGames = 0
    totalCalls = 0
    noopTicks = 0
    deadSeats = 0
  for path in paths:
    let request = parseFile(path)
    if request{"status"}.getStr != "completed":
      fail("Request incomplete: " & path)
    if not isBlank(request{"error"}):
      fail("Request error: " & path)
    let cohort = request{"episodes"}
    if cohort.isNil or cohort.kind != JArray or
        cohort.len != request{"episode_count"}.getInt:
      fail("Episode count mismatch: " & path)
    let
      requestId = request["id"].getStr
      directory = parentDir(path) / requestId
    for episode in request["episodes"]:
      let id = episode["id"].getStr
      if id in seen:
        fail("Duplicate episode: " & id)
      seen.incl id
      var row = verifyEpisode(episode, label, idea, directory)
      row["request"] = %requestId
      if row["activated"].getBool:
        inc triggeredGames
      changedActions += row["changedActions"].getInt
      if row["activated"].getBool and row["changed"].getBool:
        inc qualifyGames
      totalCalls += row["heroCalls"].getInt
      noopTicks += row["noopTicks"].getInt
      if row["deadSeat"].getBool:
        inc deadSeats
      episodes.add row
  let count = episodes.len
  %*{
    "label": label,
    "idea": idea,
    "requests": paths.len,
    "episodes": count,
    "perEpisode": episodes,
    "triggeredGames": triggeredGames,
    "changedActions": changedActions,
    "totalCalls": totalCalls,
    "noopTicks": noopTicks,
    "deadSeats": deadSeats,
    "qualifyGames": qualifyGames,
    "triggerGate": count >= MinQualify and qualifyGames == count,
    "notProofOfImprovement": true
  }

proc main() =
  ## Print trigger evidence for hosted candidate XP. Not a score claim.
  let args = commandLineParams()
  if args.len < 3:
    fail("Usage: telemetry label idea current.json [current.json ...]")
  echo verifyFiles(args[0], args[1], args[2 .. ^1]).pretty

when not defined(telemetryTest):
  main()
