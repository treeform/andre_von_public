import std/[json, os, osproc, strutils]

proc run(arguments: varargs[string]): tuple[output: string, exitCode: int] =
  ## Runs a compiled evaluation tool with quoted filesystem arguments.
  var command = ""
  for argument in arguments:
    if command.len > 0:
      command.add " "
    command.add quoteShell(argument)
  execCmdEx(command)

proc request(
  rosters, boardPath, requestPath: string
): tuple[output: string, exitCode: int] =
  ## Builds a fixture request with the existing three-opponent batch key.
  run(rosters, boardPath, "radogost:v3", "a", "10", requestPath)

proc main() =
  ## Checks roster completeness and score accounting using hosted fixtures.
  doAssert paramCount() == 7,
    "Usage: test_tools rosters scores leaderboard.json status.json " &
      "old-release-status.json same-release-status.json pending-status.json"
  let
    rosters = paramStr(1)
    scores = paramStr(2)
    board = parseJson(readFile(paramStr(3)))
    directory = getTempDir() / ("awm-tools-" & $getCurrentProcessId())
    boardPath = directory / "leaderboard.json"
    requestPath = directory / "request.json"
    summaryPath = directory / "summary.json"
  createDir(directory)
  defer:
    removeDir(directory)

  echo "Testing the unchanged ranked roster"
  writeFile(boardPath, $board)
  let ranked = request(rosters, boardPath, requestPath)
  doAssert ranked.exitCode == 0, ranked.output
  let original = parseJson(readFile(requestPath))
  doAssert original["roster"].len == 4
  doAssert original["idempotency_key"].getStr == "awm-top3-radogost:v3-a"
  var rankedPosition = 1
  for rating in board["ratings"]:
    let name = rating["player"].getStr
    if name == "Andre von Auto":
      continue
    var reference = ""
    for standing in board["standings"]:
      if standing["player"].getStr == name and
        standing["champion"].getBool and
        standing["status"].getStr == "competing":
          reference = standing["policy"].getStr & ":v" &
            $standing["version"].getInt
          break
    if reference.len == 0:
      continue
    doAssert rankedPosition < original["roster"].len
    let player = original["roster"][rankedPosition]["player"]
    doAssert player["policy_ref"].getStr == reference
    inc rankedPosition
  doAssert rankedPosition == original["roster"].len

  echo "Testing unrated champions and duplicate player rows"
  board["standings"].add %*{
    "player": "Unrated fixture player",
    "policy": "unrated-fixture",
    "version": 1,
    "champion": true,
    "status": "competing"
  }
  board["standings"].add %*{
    "player": "Andrew Brower",
    "policy": "duplicate-fixture",
    "version": 1,
    "champion": true,
    "status": "competing"
  }
  writeFile(boardPath, $board)
  let unrated = request(rosters, boardPath, requestPath)
  doAssert unrated.exitCode == 0, unrated.output
  let complete = parseJson(readFile(requestPath))
  doAssert complete["roster"].len == 5
  doAssert complete["idempotency_key"].getStr == "awm-all-radogost:v3-a"
  doAssert complete["roster"][4]["player"]["policy_ref"].getStr ==
    "unrated-fixture:v1"
  doAssert "5-seat AWM against all 4" in complete["notes"].getStr

  echo "Testing the seven-player roster limit"
  for i in 0 ..< 3:
    board["standings"].add %*{
      "player": "Extra fixture player " & $i,
      "policy": "extra-fixture-" & $i,
      "version": 1,
      "champion": true,
      "status": "competing"
    }
  writeFile(boardPath, $board)
  let excessive = request(rosters, boardPath, requestPath)
  doAssert excessive.exitCode != 0
  doAssert "at most seven players" in excessive.output
  board["standings"] = %*[{
    "player": "Andre von Auto",
    "policy": "radogost",
    "version": 3,
    "champion": true,
    "status": "competing"
  }]
  writeFile(boardPath, $board)
  let empty = request(rosters, boardPath, requestPath)
  doAssert empty.exitCode != 0
  doAssert "at least one other live champion" in empty.output

  echo "Testing unchanged hosted scoring and release provenance"
  let existing = run(scores, paramStr(4), summaryPath)
  doAssert existing.exitCode == 0, existing.output
  let summary = parseJson(readFile(summaryPath))
  doAssert summary["games"].getInt == 100
  doAssert summary["wins"].getInt == 16
  doAssert summary["players"].getInt == 4
  doAssert summary["seat_games"].len == 4
  doAssert summary["pair_wins"].getInt == 48
  doAssert summary["pair_losses"].getInt == 84
  doAssert summary["pair_ties"].getInt == 168
  doAssert summary["coworld_id"].getStr ==
    "cow_a8499615-b37a-4b92-84c5-a81acf8ed5d4"
  doAssert summary["coworld_version"].getStr == "2026.10.1.2"

  echo "Testing source release comparison gates"
  let
    previousPath = directory / "previous.json"
    old = run(scores, paramStr(5), previousPath)
  doAssert old.exitCode == 0, old.output
  let oldSummary = parseJson(readFile(previousPath))
  doAssert oldSummary["coworld_version"].getStr == "2026.10.1.1"
  let mismatch = run(scores, paramStr(4), summaryPath, previousPath)
  doAssert mismatch.exitCode != 0
  doAssert "Cannot compare different source releases" in mismatch.output
  let mixed = run(
    scores,
    paramStr(4),
    summaryPath,
    previousPath,
    paramStr(5)
  )
  doAssert mixed.exitCode != 0
  doAssert "Cannot combine different source releases" in mixed.output
  oldSummary.delete("coworld_version")
  writeFile(previousPath, $oldSummary)
  let missing = run(scores, paramStr(4), summaryPath, previousPath)
  doAssert missing.exitCode != 0
  doAssert "Missing source release metadata" in missing.output
  let current = run(scores, paramStr(6), previousPath)
  doAssert current.exitCode == 0, current.output
  let comparable = run(scores, paramStr(4), summaryPath, previousPath)
  doAssert comparable.exitCode == 0, comparable.output
  let compared = parseJson(readFile(summaryPath))
  doAssert compared.hasKey("one_sided_fisher_p")
  doAssert compared["previous_wins"].getInt == 23
  doAssert compared["previous_games"].getInt == 100

  echo "Testing same-policy aggregation without a Fisher comparison"
  let
    first = parseJson(readFile(paramStr(4)))
    second = parseJson(readFile(paramStr(4)))
    episodes = first["episodes"]
    firstPath = directory / "first.json"
    secondPath = directory / "second.json"
  first["id"] = %(first["id"].getStr & "-first")
  second["id"] = %(second["id"].getStr & "-second")
  first["episodes"] = newJArray()
  second["episodes"] = newJArray()
  first["episode_count"] = %50
  second["episode_count"] = %50
  first["completed_count"] = %50
  second["completed_count"] = %50
  for i in 0 ..< episodes.len:
    let episode = episodes[i]
    if i < 50:
      first["episodes"].add episode
    else:
      second["episodes"].add episode
  writeFile(firstPath, $first)
  writeFile(secondPath, $second)
  let aggregated = run(scores, firstPath, summaryPath, "-", secondPath)
  doAssert aggregated.exitCode == 0, aggregated.output
  let total = parseJson(readFile(summaryPath))
  doAssert total["games"].getInt == 100
  doAssert total["wins"].getInt == 16
  doAssert total["episode_count"].getInt == 100
  doAssert total["ids"].len == 2
  doAssert not total.hasKey("one_sided_fisher_p")

  echo "Testing pending and partially completed batch rejection"
  let pending = run(scores, paramStr(7), summaryPath, previousPath)
  doAssert pending.exitCode != 0
  doAssert "Hosted batch is not complete" in pending.output
  doAssert "different opponents" notin pending.output
  let incompleteAggregation = run(
    scores,
    paramStr(4),
    summaryPath,
    previousPath,
    paramStr(7)
  )
  doAssert incompleteAggregation.exitCode != 0
  doAssert "Hosted batch is not complete" in incompleteAggregation.output
  let progress = run(scores, paramStr(7), summaryPath)
  doAssert progress.exitCode == 0, progress.output
  let progressSummary = parseJson(readFile(summaryPath))
  doAssert progressSummary["status"].getStr == "pending"
  doAssert progressSummary["games"].getInt == 0
  doAssert not progressSummary.hasKey("one_sided_fisher_p")
  let
    partial = parseJson(readFile(paramStr(4)))
    partialPath = directory / "partial.json"
  partial["episodes"][0]["status"] = %"running"
  writeFile(partialPath, $partial)
  let incomplete = run(scores, partialPath, summaryPath, previousPath)
  doAssert incomplete.exitCode != 0
  doAssert "Hosted batch is not complete" in incomplete.output
  let partialSummary = parseJson(readFile(previousPath))
  partialSummary["games"] = %99
  writeFile(previousPath, $partialSummary)
  let incompletePrior = run(scores, paramStr(4), summaryPath, previousPath)
  doAssert incompletePrior.exitCode != 0
  doAssert "Hosted batch is not complete" in incompletePrior.output

  echo "Testing inconsistent episode release rejection"
  let
    inconsistent = parseJson(readFile(paramStr(4)))
    inconsistentPath = directory / "inconsistent.json"
  inconsistent["episodes"][0]["coworld_id"] = oldSummary["coworld_id"]
  writeFile(inconsistentPath, $inconsistent)
  let wrongEpisode = run(scores, inconsistentPath, summaryPath)
  doAssert wrongEpisode.exitCode != 0
  doAssert "Episode source release does not match" in wrongEpisode.output

  echo "Testing seven-seat score accounting"
  let
    status = parseJson(readFile(paramStr(4)))
    episode = status["episodes"][0]
    statusPath = directory / "status-seven.json"
  status["episodes"] = newJArray()
  status["episodes"].add episode
  for i in 4 .. 6:
    episode["participants"].add %*{
      "position": i,
      "policy_name": "fixture-" & $i,
      "policy_version_id": "fixture-version-" & $i
    }
    episode["participant_scores"].add %*{"position": i, "score": 0.0}
  var position = -1
  for player in episode["participants"]:
    if player["policy_name"].getStr == "radogost":
      position = player["position"].getInt
      player["position"] = %6
    elif player["position"].getInt == 6:
      player["position"] = %position
  doAssert position >= 0
  for score in episode["participant_scores"]:
    if score["position"].getInt == position:
      score["position"] = %6
    elif score["position"].getInt == 6:
      score["position"] = %position
  writeFile(statusPath, $status)
  let seven = run(scores, statusPath, summaryPath)
  doAssert seven.exitCode == 0, seven.output
  let larger = parseJson(readFile(summaryPath))
  doAssert larger["players"].getInt == 7
  doAssert larger["seat_games"].len == 7
  doAssert larger["seat_wins"].len == 7
  doAssert larger["seat_games"][6].getInt == 1
  doAssert larger["pair_wins"].getInt + larger["pair_losses"].getInt +
    larger["pair_ties"].getInt == 6
  echo "Evaluation tool fixtures passed"

main()
