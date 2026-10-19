import std/[json, os, osproc, strutils]

const Artifacts = [
  "request.json", "request.json.meta.json", "summary.json",
  "manifest.json", "response.json"
]

proc run(arguments: varargs[string]): tuple[output: string, exitCode: int] =
  ## Runs the offline scorer with quoted file paths.
  var command = ""
  for argument in arguments:
    if command.len > 0:
      command.add " "
    command.add quoteShell(argument)
  execCmdEx(command)

proc copyBatch(source, target: string) =
  ## Copies only saved JSON metadata without touching hosted artifacts.
  createDir(target)
  for name in Artifacts:
    copyFile(source / name, target / name)

proc save(path: string, data: JsonNode) =
  ## Writes a temporary malformed or synthetic JSON fixture.
  writeFile(path, data.pretty & "\n")

proc load(path: string): JsonNode =
  ## Parses a fixture copy for isolated field mutations.
  parseJson(readFile(path))

proc requireRejected(
  scorer, baseline, candidate, count, output, diagnostic: string
) =
  ## Requires a specific boundary rejection from the scorer.
  let scored = run(scorer, baseline, candidate, count, output)
  doAssert scored.exitCode != 0, "Expected rejection: " & diagnostic
  doAssert diagnostic in scored.output, scored.output

proc main() =
  ## Exercises actual paired fast batches and malformed offline fixtures.
  doAssert paramCount() == 4,
    "Usage: test_fast_scores SCORER BASELINE_PREFIX CANDIDATE_PREFIX BATCHES"
  let
    scorer = paramStr(1)
    directory = getTempDir() / ("awm-fast-scores-" & $getCurrentProcessId())
    baseline = directory / "baseline_"
    candidate = directory / "candidate_"
    output = directory / "score.json"
  createDir(directory)
  defer:
    removeDir(directory)

  echo "Testing the actual 200-game saved paired screening"
  let actual = run(scorer, paramStr(2), paramStr(3), paramStr(4), output)
  doAssert actual.exitCode == 0, actual.output
  let score = load(output)
  doAssert score["games_per_arm"].getInt == 100
  doAssert score["total_games"].getInt == 200
  doAssert score["baseline_wins"].getInt == 17
  doAssert score["candidate_wins"].getInt == 19
  doAssert score["gained"].getInt == 2
  doAssert score["lost"].getInt == 0
  doAssert score["both_won"].getInt == 17
  doAssert score["both_lost"].getInt == 81
  doAssert score["own_class"] == %*{
    "Archer": {
      "class": 0, "games_per_arm": 37,
      "baseline_wins": 5, "candidate_wins": 5
    },
    "Warrior": {
      "class": 1, "games_per_arm": 27,
      "baseline_wins": 5, "candidate_wins": 5
    },
    "Mage": {
      "class": 2, "games_per_arm": 36,
      "baseline_wins": 7, "candidate_wins": 9
    }
  }
  doAssert abs(score["one_sided_paired_binomial_p"].getFloat - 0.25) < 1e-12
  doAssert score["baseline_source_sha256"].getStr ==
    "c95a236f55329783a1c97bb32cdcda8f9830e5b77204f5c732e740a92a00be00"
  doAssert score["candidate_source_sha256"].getStr ==
    "e512464b4e4e869bb0bee2a8c51e4b3a233bbb4c061ccfa86c2dc6572c458c7a"
  doAssert score["batches"].len == 10
  doAssert score["batches"][0]["baseline"]["endpoint_attribution"].getStr ==
    "directory-only"

  for i in 0 ..< 2:
    copyBatch(paramStr(2) & $i, baseline & $i)
    copyBatch(paramStr(3) & $i, candidate & $i)
  echo "Testing disjoint cohorts and global provenance guards"
  let
    extraBaseline = directory / "extra_baseline_"
    extraCandidate = directory / "extra_candidate_"
  copyBatch(baseline & "1", extraBaseline & "0")
  copyBatch(candidate & "1", extraCandidate & "0")
  let disjoint = run(
    scorer,
    baseline,
    candidate,
    "1",
    output,
    extraBaseline,
    extraCandidate,
    "1"
  )
  doAssert disjoint.exitCode == 0, disjoint.output
  let combined = load(output)
  doAssert combined["games_per_arm"].getInt == 20
  doAssert combined["num_batches"].getInt == 2
  doAssert combined["num_cohorts"].getInt == 2
  doAssert combined["batches"].len == 2
  doAssert combined["cohorts"].len == 2
  for i in 0 ..< 2:
    let
      previous = load(baseline & $i / "summary.json")
      current = load(candidate & $i / "summary.json")
      cohort = combined["cohorts"][i]
    doAssert cohort["games_per_arm"].getInt == 10
    doAssert cohort["baseline_wins"] == previous["wins"]
    doAssert cohort["candidate_wins"] == current["wins"]
  doAssert combined["pairs"][10]["cohort_index"].getInt == 1
  let overlap = run(
    scorer,
    baseline,
    candidate,
    "1",
    output,
    baseline,
    candidate,
    "1"
  )
  doAssert overlap.exitCode != 0
  doAssert "Duplicate paired seed" in overlap.output, overlap.output
  let
    extraRequestPath = extraCandidate & "0" / "request.json"
    originalExtraRequest = readFile(extraRequestPath)
    extraSource = parseJson(originalExtraRequest)
  extraSource["roster"][0]["player"]["source"] =
    %(extraSource["roster"][0]["player"]["source"].getStr & "\nREM fixture\n")
  save(extraRequestPath, extraSource)
  let changedCohort = run(
    scorer,
    baseline,
    candidate,
    "1",
    output,
    extraBaseline,
    extraCandidate,
    "1"
  )
  doAssert changedCohort.exitCode != 0
  doAssert "Cannot mix candidate source hashes per arm" in changedCohort.output,
    changedCohort.output
  writeFile(extraRequestPath, originalExtraRequest)
  let
    extraMetaPath = extraCandidate & "0" / "request.json.meta.json"
    originalExtraMeta = readFile(extraMetaPath)
    extraOpponent = parseJson(originalExtraRequest)
    extraMeta = parseJson(originalExtraMeta)
  extraOpponent["roster"][4]["player"]["policy_ref"] = %"different:v1"
  extraMeta["extra_seat_policy_ref"] = %"different:v1"
  save(extraRequestPath, extraOpponent)
  save(extraMetaPath, extraMeta)
  let differentCohort = run(
    scorer,
    baseline,
    candidate,
    "1",
    output,
    extraBaseline,
    extraCandidate,
    "1"
  )
  doAssert differentCohort.exitCode != 0
  doAssert(
    "Cannot pair different opponent policy_refs" in differentCohort.output,
    differentCohort.output
  )
  writeFile(extraRequestPath, originalExtraRequest)
  writeFile(extraMetaPath, originalExtraMeta)
  let
    summaryPath = candidate & "0" / "summary.json"
    manifestPath = candidate & "0" / "manifest.json"
    responsePath = candidate & "0" / "response.json"
    requestPath = candidate & "0" / "request.json"
    originalSummary = readFile(summaryPath)
    originalManifest = readFile(manifestPath)
    originalResponse = readFile(responsePath)
    originalRequest = readFile(requestPath)

  echo "Testing complete and healthy five-seat games"
  for active in [-1, 4, 6]:
    let summary = parseJson(originalSummary)
    summary["episodes"][0]["active_bots"] = %active
    save(summaryPath, summary)
    requireRejected(scorer, baseline, candidate, "1", output,
      "Verified game is incomplete or failed")
  let missingActive = parseJson(originalSummary)
  missingActive["episodes"][0].delete("active_bots")
  save(summaryPath, missingActive)
  requireRejected(scorer, baseline, candidate, "1", output,
    "Missing integer field: active_bots")
  let incomplete = parseJson(originalSummary)
  incomplete["episodes"][0]["game_over"] = %false
  save(summaryPath, incomplete)
  requireRejected(scorer, baseline, candidate, "1", output,
    "Verified game is incomplete or failed")
  let failed = parseJson(originalSummary)
  failed["episodes"][0]["candidate_failure_detected"] = %true
  save(summaryPath, failed)
  requireRejected(scorer, baseline, candidate, "1", output,
    "Verified game is incomplete or failed")
  writeFile(summaryPath, originalSummary)
  let disabled = parseJson(originalManifest)
  disabled["games"][0]["active_bots"] = %4
  save(manifestPath, disabled)
  requireRejected(scorer, baseline, candidate, "1", output,
    "Fast game is incomplete or disabled")
  let status = parseJson(originalManifest)
  status["games"][0]["status"] = %"failed"
  save(manifestPath, status)
  requireRejected(scorer, baseline, candidate, "1", output,
    "Fast game is incomplete or disabled")
  writeFile(manifestPath, originalManifest)
  let gateway = parseJson(originalResponse)
  gateway["http_status"] = %502
  save(responsePath, gateway)
  requireRejected(scorer, baseline, candidate, "1", output,
    "Fast response or manifest failed")
  writeFile(responsePath, originalResponse)
  writeFile(candidate & "0" / "response-error.json", "{}")
  requireRejected(scorer, baseline, candidate, "1", output,
    "Fast batch has a saved error response")
  removeFile(candidate & "0" / "response-error.json")

  echo "Testing paired classes, seating, source and opponents"
  let classes = parseJson(originalSummary)
  classes["episodes"][0]["classes"].elems[0] =
    %((classes["episodes"][0]["classes"][0].getInt + 1) mod 3)
  save(summaryPath, classes)
  requireRejected(scorer, baseline, candidate, "1", output,
    "Paired seed, classes or seatings differ")
  writeFile(summaryPath, originalSummary)
  let
    summarySeats = parseJson(originalSummary)
    manifestSeats = parseJson(originalManifest)
  for data in [summarySeats["episodes"][0], manifestSeats["games"][0]]:
    swap(
      data["roster_entries_by_slot"].elems[1],
      data["roster_entries_by_slot"].elems[2]
    )
  save(summaryPath, summarySeats)
  save(manifestPath, manifestSeats)
  requireRejected(scorer, baseline, candidate, "1", output,
    "Paired seed, classes or seatings differ")
  writeFile(summaryPath, originalSummary)
  writeFile(manifestPath, originalManifest)
  let
    secondRequest = candidate & "1" / "request.json"
    originalSecondRequest = readFile(secondRequest)
    changedSource = parseJson(originalSecondRequest)
  changedSource["roster"][0]["player"]["source"] =
    %(changedSource["roster"][0]["player"]["source"].getStr & "\nREM fixture\n")
  save(secondRequest, changedSource)
  requireRejected(scorer, baseline, candidate, "2", output,
    "Cannot mix candidate source hashes per arm")
  writeFile(secondRequest, originalSecondRequest)
  let
    changedOpponent = parseJson(originalRequest)
    metaPath = candidate & "0" / "request.json.meta.json"
    originalMeta = readFile(metaPath)
    changedMeta = parseJson(originalMeta)
  changedOpponent["roster"][4]["player"]["policy_ref"] = %"different:v1"
  changedMeta["extra_seat_policy_ref"] = %"different:v1"
  save(requestPath, changedOpponent)
  save(metaPath, changedMeta)
  requireRejected(scorer, baseline, candidate, "1", output,
    "Cannot pair different opponent policy_refs")
  writeFile(requestPath, originalRequest)
  writeFile(metaPath, originalMeta)

  echo "Testing accounting, unknown sources and duplicate seeds"
  let accounting = parseJson(originalSummary)
  accounting["wins"] = %(accounting["wins"].getInt + 1)
  save(summaryPath, accounting)
  requireRejected(scorer, baseline, candidate, "1", output,
    "Summary wins disagree with verified games")
  let malformed = parseJson(originalSummary)
  malformed["episodes"][0]["candidate_win"] = %"false"
  save(summaryPath, malformed)
  requireRejected(scorer, baseline, candidate, "1", output,
    "Missing boolean field: candidate_win")
  writeFile(summaryPath, originalSummary)
  let unknown = parseJson(originalRequest)
  unknown["roster"][0]["player"] = %*{"policy_ref": "unfrozen:v1"}
  save(requestPath, unknown)
  requireRejected(scorer, baseline, candidate, "1", output,
    "Missing text field: source")
  writeFile(requestPath, originalRequest)
  copyBatch(baseline & "0", baseline & "1")
  copyBatch(candidate & "0", candidate & "1")
  requireRejected(scorer, baseline, candidate, "2", output,
    "Duplicate paired seed")

  echo "Testing exact paired tail and reordered record arrays"
  let allWins = parseJson(originalSummary)
  allWins["wins"] = %10
  for episode in allWins["episodes"]:
    episode["engine_winner"] = %0
    episode["living_seats"] = %*[0]
    episode["candidate_win"] = %true
    episode["engine_candidate_win"] = %true
  save(summaryPath, allWins)
  let improved = run(scorer, baseline, candidate, "1", output)
  doAssert improved.exitCode == 0, improved.output
  let exact = load(output)
  doAssert exact["gained"].getInt == 8
  doAssert exact["lost"].getInt == 0
  doAssert abs(exact["one_sided_exact_mcnemar_p"].getFloat - 1.0 / 256) < 1e-12
  let reverse = run(scorer, candidate, baseline, "1", output)
  doAssert reverse.exitCode == 0, reverse.output
  doAssert abs(load(output)["one_sided_exact_mcnemar_p"].getFloat - 1.0) < 1e-12
  writeFile(summaryPath, originalSummary)
  let reordered = parseJson(originalSummary)
  swap(reordered["episodes"].elems[0], reordered["episodes"].elems[9])
  save(summaryPath, reordered)
  let permuted = run(scorer, baseline, candidate, "1", output)
  doAssert permuted.exitCode == 0, permuted.output
  doAssert abs(load(output)["one_sided_exact_mcnemar_p"].getFloat - 1.0) < 1e-12
  echo "All fast paired score fixtures passed."

main()
