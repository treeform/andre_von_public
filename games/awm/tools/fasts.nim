import
  std/[json, monotimes, os, sets, strutils, times, uri],
  curly, zippy, zippy/ziparchives,
  sim, match, replays

const
  DefaultBase = "https://fast-xp-request-staging.tail0f4a29.ts.net"
  OwnPlayer = "Andre von Auto"
  SourceLimit = 256 * 1024
  TimeoutSeconds = 1800
  SeatCount = 5

type AwmError = object of CatchableError

proc readText(path: string): string =
  ## Reads an artifact with a game-specific boundary diagnostic.
  try:
    result = readFile(path)
  except IOError as error:
    raise newException(AwmError, "Cannot read " & path & ": " & error.msg)

proc saveText(path, body: string) =
  ## Writes artifacts atomically without truncating a previous result.
  try:
    createDir(path.parentDir)
    writeFile(path & ".partial", body)
    moveFile(path & ".partial", path)
  except OSError, IOError:
    raise newException(AwmError,
      "Cannot save " & path & ": " & getCurrentExceptionMsg())

proc parseData(body, description: string): JsonNode =
  ## Converts JSON parsing failures into explicit AWM errors.
  try:
    result = parseJson(body)
  except JsonParsingError as error:
    raise newException(AwmError,
      "Invalid " & description & " JSON: " & error.msg)

proc integer(value: string, description: string): int =
  ## Parses CLI integers without an implicit fallback.
  try:
    result = parseInt(value)
  except ValueError as error:
    raise newException(AwmError, "Invalid " & description & ": " & error.msg)

proc requireInteger(node: JsonNode, key: string): int =
  ## Requires an integer field before using request or response metadata.
  if node.kind != JObject or not node.hasKey(key) or
    node[key].kind != JInt:
      raise newException(AwmError, "Missing integer field " & key)
  node[key].getInt

proc requireText(node: JsonNode, key: string): string =
  ## Requires text metadata without silently coercing malformed JSON.
  if node.kind != JObject or not node.hasKey(key) or
    node[key].kind != JString:
      raise newException(AwmError, "Missing text field " & key)
  node[key].getStr

proc request(path: string): JsonNode =
  ## Validates the batch seed and candidate identity before any network call.
  result = parseData(readText(path), "fast request")
  let
    seed = result.requireInteger("seed")
    count =
      if result.hasKey("num_episodes"):
        result.requireInteger("num_episodes")
      else:
        1
  if count notin 1 .. 10 or seed < int32.low.int or
    seed.int64 + count.int64 - 1 > int32.high.int64:
      raise newException(AwmError, "Batch needs 1..10 signed-int32 seeds")
  if not result.hasKey("roster") or result["roster"].kind != JArray or
    result["roster"].len notin 1 .. SeatCount:
      raise newException(AwmError, "Fast AWM needs 1..5 roster entries")
  let candidate = result["roster"][0]
  if candidate.requireInteger("slot") != 0 or
    not candidate.hasKey("player"):
      raise newException(AwmError, "Candidate must be roster entry 0 pinned 0")
  let player = candidate["player"]
  if player.kind != JObject or player.len != 1 or
    not player.hasKey("source"):
      raise newException(AwmError, "Candidate requires uploaded BASIC source")
  let source = player.requireText("source")
  if source.strip.len == 0 or source.len > SourceLimit or '\0' in source:
    raise newException(AwmError, "Invalid candidate source or over 256 KiB")

proc prepare() =
  ## Freezes a local candidate and live champions in a five-seat request.
  if paramCount() != 6:
    raise newException(AwmError,
      "Usage: fasts request SOURCE LEADERBOARD SEED EPISODES OUTPUT_JSON")
  let
    sourcePath = paramStr(2)
    boardPath = paramStr(3)
    source = readText(sourcePath)
    board = parseData(readText(boardPath), "leaderboard")
    seed = integer(paramStr(4), "seed")
    count = integer(paramStr(5), "episodes")
    output = paramStr(6)
    roster = %*[{"slot": 0, "player": {"source": source}}]
    opponents = newJArray()
  var
    seen: HashSet[string]
    baseline = ""
  if board.kind != JObject or not board.hasKey("standings") or
    board["standings"].kind != JArray:
      raise newException(AwmError, "Leaderboard lacks standings")
  for standing in board["standings"]:
    let name = standing.requireText("player")
    if name == OwnPlayer or name in seen or
      not standing.hasKey("champion") or
      not standing["champion"].getBool or
      standing.requireText("status") != "competing":
        continue
    let
      label = standing.requireText("policy") & ":v" &
        $standing.requireInteger("version")
      reference =
        if standing.hasKey("policy_version_id"):
          standing.requireText("policy_version_id")
        else:
          label
    roster.add %*{"slot": -1, "player": {"policy_ref": reference}}
    opponents.add %*{"player": name, "label": label, "policy_ref": reference}
    seen.incl name
    if standing.requireText("policy") == "AWM Baseline":
      baseline = reference
  if seen.len notin 3 .. 4:
    raise newException(AwmError,
      "Fast AWM supports three or four distinct live opponents; found " &
      $seen.len)
  if seen.len == 3:
    if baseline.len == 0:
      raise newException(AwmError,
        "Three-opponent diagnostics require an AWM Baseline filler")
    roster.add %*{"slot": -1, "player": {"policy_ref": baseline}}
  let
    duplicatedBaseline = seen.len == 3
    scope =
      if duplicatedBaseline:
        "Five-seat diagnostic with duplicated baseline; " &
          "separate from four-seat standard XP against unique players"
      else:
        "Five-seat fast-XP against all four distinct other live players"
    data = %*{"seed": seed, "num_episodes": count, "roster": roster}
  saveText(output, data.pretty & "\n")
  discard request(output)
  saveText(output & ".meta.json", (%*{
    "service": "fast-xp",
    "game": "awm",
    "players": SeatCount,
    "candidate_slot": 0,
    "candidate_source": absolutePath(sourcePath),
    "leaderboard": absolutePath(boardPath),
    "opponents": opponents,
    "extra_seat_policy_ref":
      (if duplicatedBaseline: %baseline else: newJNull()),
    "scoring_scope": scope
  }).pretty & "\n")
  echo "Saved fast AWM request: ", count, " games, seed ", seed,
    ", candidate pinned 0, ", seen.len, " distinct opponents",
    (if duplicatedBaseline: " plus baseline filler." else: ".")

proc safePath(path: string): bool =
  ## Rejects absolute paths and archive traversal before extracting any file.
  if path.len == 0 or path.isAbsolute or '\\' in path:
    return false
  for part in path.split('/'):
    if part.len == 0 or part in [".", ".."]:
      return false
    for character in part:
      if character notin {'a' .. 'z', 'A' .. 'Z', '0' .. '9', '-', '.', '_'}:
        return false
  true

proc seating(data: JsonNode, episode: int): seq[int] =
  ## Reproduces documented cyclic seating when a single game has no manifest.
  result = newSeq[int](SeatCount)
  var
    open: seq[int]
    pinned: set[0 .. SeatCount - 1]
  for index in 0 ..< data["roster"].len:
    let entry = data["roster"][index]
    let slot = if entry.hasKey("slot"): entry.requireInteger("slot") else: -1
    if slot == -1:
      open.add index
    elif slot in 0 ..< SeatCount and slot notin pinned:
      result[slot] = index
      pinned.incl slot
    else:
      raise newException(AwmError, "Invalid or duplicated pinned roster slot")
  var next = 0
  for slot in 0 ..< SeatCount:
    if slot in pinned:
      continue
    if open.len == 0:
      raise newException(AwmError, "Unfilled seat requires an unpinned entry")
    result[slot] = open[((next - episode) mod open.len + open.len) mod open.len]
    inc next

proc inspectReplay(path: string, expectedSeed: int): JsonNode =
  ## Verifies every state hash and counts only actual last-survivor wins.
  var bytes = readText(path)
  if bytes.len > 2 and bytes[0] == '\x1f' and bytes[1] == '\x8b':
    try:
      bytes = uncompress(bytes, dfGzip)
    except ZippyError as error:
      raise newException(AwmError, "Replay gzip failed: " & error.msg)
  let data = decodeReplayFile(ReplayGame, ReplayGameVersion, bytes, ReplayData)
  data.validate()
  if data.header.setup.seed.int != expectedSeed:
    raise newException(AwmError, "Replay seed disagrees with request")
  if data.header.setup.classes.len != SeatCount:
    raise newException(AwmError, "Fast AWM replay must have five seats")
  var
    game = newGame(data.header.setup.heroClasses, data.header.setup.seed)
    check: ReplayHashCheck
    tick = 0'u32
    living: seq[int]
  for action in data.actions:
    if not game.applyAction(action):
      raise newException(AwmError, "Replay action refused at tick " & $action.tick)
    discard game.takeVisualEvents()
    tick = action.tick
    data.hashes.checkReplayHash(tick, game.stateHash, check)
  check.requireReplayComplete(tick, data.hashes.len)
  for seat in 0 ..< game.playerCount:
    if not game.players[seat].dead:
      living.add seat
  result = %*{
    "seed": expectedSeed,
    "verified_ticks": tick,
    "classes": data.header.setup.classes,
    "game_over": game.gameOver,
    "engine_winner": game.winner,
    "living_seats": living,
    "candidate_win": game.gameOver and living == @[0] and game.winner == 0,
    "engine_candidate_win": game.gameOver and game.winner == 0
  }

proc parseArchive(data: JsonNode, archive, directory: string): JsonNode =
  ## Extracts logs and replays, retaining per-game failures in a separate score.
  let reader = openZipArchive(archive)
  defer:
    reader.close()
  var
    paths: HashSet[string]
    bytes = 0
  for path in reader.walkFiles:
    if not safePath(path) or path in paths or paths.len >= 61:
      raise newException(AwmError, "Unsafe or excessive ZIP entry: " & path)
    let body = reader.extractFile(path)
    bytes += body.len
    if body.len > 256 * 1024 * 1024 or bytes > 1024 * 1024 * 1024:
      raise newException(AwmError, "Fast-XP archive exceeds extraction limits")
    saveText(directory / path, body)
    paths.incl path
  let
    count =
      if data.hasKey("num_episodes"):
        data.requireInteger("num_episodes")
      else:
        1
    games = newJArray()
  var records: JsonNode
  if "manifest.json" in paths:
    let manifest = parseData(readText(directory / "manifest.json"), "manifest")
    if not manifest.hasKey("games") or manifest["games"].kind != JArray or
      manifest["games"].len != count:
        raise newException(AwmError, "Manifest game count differs from request")
    records = manifest["games"]
  elif count == 1:
    records = %*[{
      "index": 0,
      "seed": data.requireInteger("seed"),
      "http_status": 200,
      "status": "completed",
      "roster_entries_by_slot": seating(data, 0),
      "artifacts": ["replay.replay"]
    }]
  else:
    raise newException(AwmError, "A batch response requires manifest.json")
  var
    seen: HashSet[int]
    opponentReferences: HashSet[string]
    completed, failed, wins, botFailures, candidateFailures: int
  for index in 1 ..< data["roster"].len:
    let player = data["roster"][index]["player"]
    if player.hasKey("policy_ref"):
      opponentReferences.incl player.requireText("policy_ref")
  for record in records:
    let
      index = record.requireInteger("index")
      seed = record.requireInteger("seed")
      status = record.requireInteger("http_status")
      prefix = if count == 1: "" else: "games/" & align($index, 3, '0') & "/"
    if index notin 0 ..< count or index in seen or
      seed != data.requireInteger("seed") + index:
        raise newException(AwmError, "Manifest index or seed differs from request")
    seen.incl index
    if not record.hasKey("roster_entries_by_slot") or
      record["roster_entries_by_slot"].kind != JArray or
      record["roster_entries_by_slot"].len != SeatCount:
        raise newException(AwmError, "Manifest lacks five-seat roster mapping")
    var membership = newSeq[int](data["roster"].len)
    for slot in 0 ..< SeatCount:
      let entry = record["roster_entries_by_slot"][slot]
      if entry.kind != JInt or entry.getInt notin 0 ..< data["roster"].len:
        raise newException(AwmError, "Manifest names an unknown roster entry")
      inc membership[entry.getInt]
      let player = data["roster"][entry.getInt]
      if player.hasKey("slot") and player.requireInteger("slot") >= 0 and
        player.requireInteger("slot") != slot:
          raise newException(AwmError, "Manifest moved a pinned roster entry")
    if record["roster_entries_by_slot"][0].getInt != 0:
      raise newException(AwmError, "Manifest moved the pinned candidate")
    if data["roster"].len == SeatCount:
      for appearances in membership:
        if appearances != 1:
          raise newException(AwmError, "Full roster was not seated exactly once")
    if status != 200:
      inc failed
      games.add record
      continue
    let replay = prefix & "replay.replay"
    if replay notin paths:
      raise newException(AwmError, "Successful game lacks replay: " & replay)
    let episode = inspectReplay(directory / replay, seed)
    episode["index"] = %index
    episode["roster_entries_by_slot"] = record["roster_entries_by_slot"]
    episode["http_status"] = %status
    episode["predicted_rotation_matches"] =
      %(record["roster_entries_by_slot"] == %seating(data, index))
    if record.hasKey("active_bots"):
      let active = record.requireInteger("active_bots")
      episode["active_bots"] = %active
      if active in 0 ..< SeatCount:
        inc botFailures
    let log = prefix & "logs/slot-0.txt"
    if log notin paths:
      raise newException(AwmError, "Uploaded candidate lacks its log: " & log)
    let content = readText(directory / log)
    let
      lowered = content.toLowerAscii
      candidateFailed = lowered.contains("basic error:") or
        lowered.contains("script error:") or lowered.contains("runtime error") or
        lowered.contains("bot failed") or lowered.contains("basic vm disabled") or
        lowered.contains("work limit") or lowered.contains("instruction limit")
    episode["candidate_log"] = %log
    episode["candidate_log_nonempty"] = %(content.len > 0)
    episode["candidate_failure_detected"] = %candidateFailed
    if candidateFailed:
      inc candidateFailures
    inc completed
    if episode["candidate_win"].getBool:
      inc wins
    games.add episode
  result = %*{
    "service": "fast-xp",
    "players": SeatCount,
    "candidate_slot": 0,
    "seed": data.requireInteger("seed"),
    "requested": count,
    "games": completed,
    "wins": wins,
    "failed": failed,
    "games_with_disabled_bots": botFailures,
    "candidate_failures_detected": candidateFailures,
    "win_rate": (if completed > 0: wins.float / completed.float else: 0.0),
    "episodes": games,
    "scoring_scope":
      (if opponentReferences.len == 4:
        "Fast-XP five-seat against four distinct opponent policies"
      else:
        "Fast-XP five-seat diagnostic with repeated opponent policies; " &
          "separate from standard XP against unique players")
  }
  saveText(directory / "summary.json", result.pretty & "\n")
  echo "Fast AWM: ", wins, "/", completed, " last-survivor wins; failed ",
    failed, "; games with disabled bots ", botFailures,
    "; candidate log failures ", candidateFailures, "."

proc run() =
  ## Posts once and saves the response before inspecting any replay or log.
  if paramCount() notin 3 .. 4:
    raise newException(AwmError,
      "Usage: fasts run REQUEST_JSON OUTPUT_DIRECTORY [BASE_URL]")
  let
    data = request(paramStr(2))
    directory = paramStr(3)
    base = if paramCount() == 4: paramStr(4).strip(chars = {'/'}) else: DefaultBase
    endpoint = base & "/v1/games/awm/run"
    address = parseUri(base)
    archive = directory / "response.zip"
  if address.scheme notin ["https", "http"] or address.hostname.len == 0 or
    address.username.len > 0 or address.password.len > 0 or
    address.query.len > 0 or address.anchor.len > 0:
      raise newException(AwmError, "Invalid service base URL")
  if fileExists(archive) or fileExists(directory / "response.json"):
    raise newException(AwmError, "Output already contains a response")
  saveText(directory / "request.json", data.pretty & "\n")
  let curl = newCurly(1)
  defer:
    curl.close()
  echo "Posting fast AWM batch once; timeout ", TimeoutSeconds, " seconds."
  let started = getMonoTime()
  var response: Response
  try:
    response = curl.post(
      endpoint,
      headers = @[("Content-Type", "application/json")],
      body = $data,
      timeout = TimeoutSeconds
    )
  except CatchableError as error:
    raise newException(AwmError,
      "Fast-XP transport failed; work may have finished: " & error.msg)
  let metadata = %*{
    "base_url": base,
    "endpoint_url": endpoint,
    "http_status": response.code,
    "request_id": response.headers["X-Request-ID"],
    "server_timing": response.headers["Server-Timing"],
    "retry_after": response.headers["Retry-After"],
    "content_type": response.headers["Content-Type"],
    "client_elapsed_ms": (getMonoTime() - started).inMilliseconds,
    "response_bytes": response.body.len
  }
  saveText(directory / "response.json", metadata.pretty & "\n")
  echo "HTTP ", response.code, "; X-Request-ID ",
    response.headers["X-Request-ID"], "; Server-Timing ",
    response.headers["Server-Timing"]
  if response.code != 200:
    saveText(directory / "response-error.json", response.body)
    raise newException(AwmError,
      "Fast-XP HTTP " & $response.code & "; error body saved, no retry")
  saveText(archive, response.body)
  if not response.headers["Content-Type"].startsWith("application/zip"):
    raise newException(AwmError, "Successful response is not application/zip")
  discard parseArchive(data, archive, directory)

proc main() =
  ## Generates requests, calls experimental fast-XP, or inspects saved ZIPs.
  if paramCount() == 0:
    raise newException(AwmError, "Usage: fasts request|run|inspect ...")
  case paramStr(1)
  of "request":
    prepare()
  of "run":
    run()
  of "inspect":
    if paramCount() != 4:
      raise newException(AwmError,
        "Usage: fasts inspect REQUEST_JSON ZIP_FILE OUTPUT_DIRECTORY")
    discard parseArchive(request(paramStr(2)), paramStr(3), paramStr(4))
  else:
    raise newException(AwmError, "Unknown command: " & paramStr(1))

main()
