import
  std/[algorithm, json, os, osproc, strutils],
  zippy,
  replays

type AwmError = object of CatchableError

proc readJson(path: string): JsonNode =
  ## Reads saved data through a game-specific error boundary.
  try:
    result = parseJson(readFile(path))
  except IOError as error:
    raise newException(AwmError, "Cannot read fixture: " & error.msg)
  except JsonParsingError as error:
    raise newException(AwmError, "Invalid fixture JSON: " & error.msg)

proc writeText(path, content: string) =
  ## Saves temporary fixture data with an explicit boundary error.
  try:
    writeFile(path, content)
  except IOError as error:
    raise newException(AwmError, "Cannot save fixture: " & error.msg)

proc readReplay(path: string): ReplayData =
  ## Loads the real hosted tape used by the seat and hash fixtures.
  var bytes: string
  try:
    bytes = readFile(path)
  except IOError as error:
    raise newException(AwmError, "Cannot read replay fixture: " & error.msg)
  if bytes.len > 2 and bytes[0] == '\x1f' and bytes[1] == '\x8b':
    try:
      bytes = uncompress(bytes, dfGzip)
    except ZippyError as error:
      raise newException(AwmError, "Invalid compressed fixture: " & error.msg)
  try:
    result = decodeReplayFile(ReplayGame, ReplayGameVersion, bytes, ReplayData)
    result.validate()
  except ReplayError as error:
    raise newException(AwmError, "Invalid replay fixture: " & error.msg)

proc run(arguments: varargs[string]): tuple[output: string, exitCode: int] =
  ## Runs the compiled CLI using explicitly quoted filesystem arguments.
  var command = ""
  for argument in arguments:
    if command.len > 0:
      command.add " "
    command.add argument.quoteShell
  try:
    result = execCmdEx(command)
  except OSError as error:
    raise newException(AwmError, "Cannot run class CLI: " & error.msg)

proc call(
    binary, directory, replays: string,
    node: JsonNode
): tuple[output: string, exitCode: int] =
  ## Saves one isolated status fixture and invokes the real CLI boundary.
  let path = directory / "status.json"
  path.writeText(node.pretty)
  run(binary, path, replays, directory / "summary.json")

proc fixture(request: JsonNode, episodes: openArray[JsonNode]): JsonNode =
  ## Deep-copies real episodes and reconciles their hosted count fields.
  result = parseJson($request)
  result["episodes"] = newJArray()
  for episode in episodes:
    result["episodes"].add parseJson($episode)
  result["episode_count"] = %episodes.len
  result["completed_count"] = %episodes.len
  result["failed_count"] = %0

proc main() =
  ## Checks the class CLI against hosted totals and invalid-input fixtures.
  if paramCount() != 4:
    raise newException(AwmError,
      "Usage: test_classes CLASSES_BINARY STATUS_JSON REPLAYDIR " &
      "SCORE_SUMMARY_JSON")
  let
    binary = paramStr(1)
    statusPath = paramStr(2)
    replays = paramStr(3)
    expected = readJson(paramStr(4))
    request = readJson(statusPath)
    directory = "/private/tmp/awm-classes-tests-" & $getCurrentProcessId()
    completePath = directory / "complete.json"
  createDir(directory)
  createDir(directory / "missing")
  createDir(directory / "corrupt")
  defer:
    removeDir(directory)
  let full = run(binary, statusPath, replays, completePath)
  doAssert full.exitCode == 0, full.output
  let complete = readJson(completePath)
  doAssert complete["games"] == expected["games"]
  doAssert complete["wins"] == expected["wins"]
  doAssert complete["players"] == expected["players"]
  doAssert complete["policy_version_id"] == expected["policy_version_id"]
  doAssert complete["opponents"] == expected["opponents"]
  doAssert complete["coworld_id"] == request["coworld_id"]
  doAssert complete["coworld_version"] == request["coworld_version"]
  doAssert complete["classified_games"] == complete["games"]
  doAssert complete["classified_wins"] == complete["wins"]
  doAssert complete["missing_replays"].len == 0
  doAssert complete["coverage_complete"].getBool
  var games, wins = 0
  for count in complete["classes"]:
    games += count["games"].getInt
    wins += count["wins"].getInt
  doAssert games == expected["games"].getInt
  doAssert wins == expected["wins"].getInt
  echo "Hosted totals and all verified class rows reconcile."
  var
    selected: JsonNode
    seat = -1
  for episode in request["episodes"]:
    for participant in episode["participants"]:
      if participant["policy_name"].getStr != "radogost":
        continue
      let position = participant["position"].getInt
      if position == 0:
        continue
      for score in episode["participant_scores"]:
        if score["position"].getInt == position and
          score["score"].getFloat == 1.0:
            selected = parseJson($episode)
            seat = position
            break
      if selected != nil:
        break
    if selected != nil:
      break
  doAssert selected != nil, "Need a real winning nonzero-seat episode."
  let
    job = selected["job_id"].getStr
    data = readReplay(replays / (job & ".replay"))
    hero = $data.header.setup.heroClasses[seat]
  var shuffled = fixture(request, [selected])
  for name in ["participants", "participant_scores", "scores"]:
    shuffled["episodes"][0][name].elems.reverse()
  let valid = call(binary, directory, replays, shuffled)
  doAssert valid.exitCode == 0, valid.output
  let summary = readJson(directory / "summary.json")
  doAssert summary["games"].getInt == 1
  doAssert summary["wins"].getInt == 1
  doAssert summary["classified_games"].getInt == 1
  doAssert summary["episodes"][0]["position"].getInt == seat
  doAssert summary["episodes"][0]["hero_class"].getStr == hero
  doAssert summary["coverage_complete"].getBool
  echo "Explicit nonzero seat survives reordered participant/score arrays."
  let absent = call(binary, directory, directory / "missing", shuffled)
  doAssert absent.exitCode == 0, absent.output
  let partial = readJson(directory / "summary.json")
  doAssert partial["games"].getInt == 1
  doAssert partial["wins"].getInt == 1
  doAssert partial["classified_games"].getInt == 0
  doAssert partial["classified_wins"].getInt == 0
  doAssert partial["missing_replays"].len == 1
  doAssert not partial["coverage_complete"].getBool
  echo "Missing replay stays unknown without changing hosted wins."
  var missingScore = fixture(request, [selected])
  missingScore["episodes"][0]["participant_scores"].elems.setLen(
    selected["participants"].len - 1
  )
  let missing = call(binary, directory, replays, missingScore)
  doAssert missing.exitCode != 0
  doAssert "score arrays must cover" in missing.output
  echo "Missing hosted score is rejected."
  var mismatch = fixture(request, [selected])
  for score in mismatch["episodes"][0]["scores"]:
    if score["score"].getFloat == 1.0:
      score["score"] = %0.0
  let disagree = call(binary, directory, replays, mismatch)
  doAssert disagree.exitCode != 0
  doAssert "scores disagree" in disagree.output
  echo "Disagreeing hosted score arrays are rejected."
  var other: JsonNode
  for episode in request["episodes"]:
    if episode["id"] != selected["id"]:
      other = episode
      break
  doAssert other != nil, "Need two real episodes for the cohort fixture."
  let mixed = fixture(request, [selected, other])
  mixed["episodes"][1]["coworld_version"] = %"fixture-other-release"
  let release = call(binary, directory, replays, mixed)
  doAssert release.exitCode != 0
  doAssert "source version" in release.output
  echo "Mixed Coworld/source cohorts are rejected."
  let corruptPath = directory / "corrupt" / (job & ".replay")
  corruptPath.writeText("invalid replay")
  let corrupt = call(binary, directory, directory / "corrupt", shuffled)
  doAssert corrupt.exitCode != 0
  doAssert "Invalid AWM replay" in corrupt.output
  echo "Corrupt available replay is rejected."
  var altered = data
  doAssert altered.hashes.len > 0
  altered.hashes[0] = altered.hashes[0] xor 1'u64
  corruptPath.writeText(
    encodeReplayFile(ReplayGame, ReplayGameVersion, altered)
  )
  let badHash = call(binary, directory, directory / "corrupt", shuffled)
  doAssert badHash.exitCode != 0
  doAssert "Replay verification failed" in badHash.output
  echo "Modified canonical replay hash is rejected."
  echo "Class CLI fixtures passed."

main()
