import
  std/[json, os, osproc, tables],
  zippy, zippy/ziparchives,
  replays

proc call(binary, request, archive, directory: string): tuple[
  output: string, exitCode: int] =
  ## Runs only offline archive inspection with explicit shell quoting.
  execCmdEx(quoteShell(binary) & " inspect " & quoteShell(request) & " " &
    quoteShell(archive) & " " & quoteShell(directory))

proc main() =
  ## Checks archived hosted replay hashes and uploaded-log failure markers.
  if paramCount() != 2:
    raise newException(ReplayError, "Usage: test_fasts FASTS_BINARY REPLAY_FILE")
  let
    binary = paramStr(1)
    directory = "/private/tmp/awm-fast-fixtures-" & $getCurrentProcessId()
    request = directory / "request.json"
    archive = directory / "response.zip"
    source = paramStr(2)
  createDir(directory)
  var bytes = readFile(source)
  if bytes.len > 2 and bytes[0] == '\x1f' and bytes[1] == '\x8b':
    bytes = uncompress(bytes, dfGzip)
  var data = decodeReplayFile(ReplayGame, ReplayGameVersion, bytes, ReplayData)
  data.validate()
  doAssert data.header.setup.classes.len == 5
  let
    roster = %*[{"slot": 0, "player": {"source": "end\n"}}]
    body = %*{
      "seed": data.header.setup.seed,
      "num_episodes": 1,
      "roster": roster
    }
  for seat in 1 .. 4:
    roster.add %*{"slot": seat, "player": {"policy_ref": "fixture:v1"}}
  writeFile(request, body.pretty)
  var entries = initOrderedTable[string, string]()
  entries["replay.replay"] = bytes
  entries["logs/slot-0.txt"] = "\nBASIC error: Fixture VM disabled\n"
  writeFile(archive, createZipArchive(entries))
  let checked = call(binary, request, archive, directory / "valid")
  doAssert checked.exitCode == 0, checked.output
  let summary = parseFile(directory / "valid/summary.json")
  doAssert summary["games"].getInt == 1
  doAssert summary["wins"].getInt == 0
  doAssert summary["candidate_failures_detected"].getInt == 1
  doAssert summary["episodes"][0]["verified_ticks"].getInt == data.actions.len
  echo "Verified a saved hosted replay and BASIC error marker."
  data.hashes[0] = data.hashes[0] xor 1'u64
  entries["replay.replay"] = encodeReplayFile(ReplayGame, ReplayGameVersion, data)
  writeFile(directory / "bad-hash.zip", createZipArchive(entries))
  let badHash = call(binary, request, directory / "bad-hash.zip",
    directory / "bad-hash")
  doAssert badHash.exitCode != 0, "A modified state hash must fail"
  echo "Rejected a modified replay hash."
  entries["../escape.txt"] = "unsafe"
  writeFile(directory / "unsafe.zip", createZipArchive(entries))
  let unsafe = call(binary, request, directory / "unsafe.zip",
    directory / "unsafe")
  doAssert unsafe.exitCode != 0, "A traversal entry must fail"
  doAssert not fileExists(directory / "escape.txt")
  echo "Rejected an archive traversal path."
  let
    repository = currentSourcePath().parentDir.parentDir
    leaderboard = parseFile(repository / "eps/leaderboard_20261001_2036.json")
    sourcePath = directory / "candidate.bas"
    boardPath = directory / "leaderboard.json"
    preparedPath = directory / "prepared.json"
  leaderboard["standings"].add %*{
    "player": "Fixture Opponent",
    "policy": "fixture",
    "version": 1,
    "champion": true,
    "status": "competing"
  }
  writeFile(sourcePath, "end\n")
  writeFile(boardPath, leaderboard.pretty)
  let prepared = execCmdEx(quoteShell(binary) & " request " &
    quoteShell(sourcePath) & " " & quoteShell(boardPath) & " 2026 10 " &
    quoteShell(preparedPath))
  doAssert prepared.exitCode == 0, prepared.output
  let
    preparedRequest = parseFile(preparedPath)
    preparedMetadata = parseFile(preparedPath & ".meta.json")
  doAssert preparedRequest["roster"].len == 5
  doAssert preparedMetadata["opponents"].len == 4
  doAssert preparedMetadata["extra_seat_policy_ref"].kind == JNull
  var references: seq[string]
  for index in 1 .. 4:
    let reference = preparedRequest["roster"][index]["player"]["policy_ref"].getStr
    doAssert reference notin references
    references.add reference
  echo "Prepared four distinct opponent champions without a filler seat."

main()
