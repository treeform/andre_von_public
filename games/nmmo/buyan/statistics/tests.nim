## Structural and math fixtures for paired hosted XP comparison.
## All scores and files here are synthetic and are not hosted XP scores.

import
  std/[json, math, os, strutils],
  comparisons

const
  BaseId = "a611afbe-e669-418f-99ae-89251052d393"
  CandId = "UPLOAD_ID_REQUIRED"
  RelhId = "87adca41-a779-43a0-addf-282af50800a8"
  OptId = "a319845e-01db-4d23-a938-3f4ed55f02be"
  DaveId = "ee828572-195d-4318-bdbb-0b4cb2bc1295"
  CowId = "cow_6272bfca-6bfa-4268-be2c-9ee35f669cfc"
  CowVer = "0.1.5"
  XpId = "xreq_actual"

template expectError(body: untyped): string =
  ## Returns the BuyanError message raised by body.
  var msg = ""
  try:
    body
    doAssert false, "expected BuyanError"
  except BuyanError as err:
    msg = err.msg
  msg

proc toArray(rows: seq[JsonNode]): JsonNode =
  ## Wraps JSON objects in an array node.
  result = newJArray()
  for row in rows:
    result.add(row)

proc makeSeat(pos: int, name: string, version: int, id: string): JsonNode =
  ## Builds one synthetic participant object.
  %*{
    "position": pos,
    "kind": "policy",
    "policy_name": name,
    "version": version,
    "policy_version_id": id
  }

proc makeEpisode(
  id: string, job: int, baseScore, candScore: float, status = "completed"
): JsonNode =
  ## Builds one synthetic eight-seat episode with candidate at position 0.
  result = %*{
    "id": id,
    "job_index": job,
    "status": status,
    "coworld_id": CowId,
    "coworld_version": CowVer
  }
  var parts = newJArray()
  parts.add makeSeat(0, "buyan-armor", 1, CandId)
  parts.add makeSeat(1, "buyan", 1, BaseId)
  parts.add makeSeat(2, "relh-nmmo-consensus", 1, RelhId)
  parts.add makeSeat(3, "relh-nmmo-consensus", 1, RelhId)
  parts.add makeSeat(4, "nmmo-opt", 6, OptId)
  parts.add makeSeat(5, "nmmo-opt", 6, OptId)
  parts.add makeSeat(6, "daveey-nmmo-nim", 11, DaveId)
  parts.add makeSeat(7, "daveey-nmmo-nim", 11, DaveId)
  result["participants"] = parts
  var scores = newJArray()
  scores.add %*{"position": 0, "score": candScore}
  scores.add %*{"position": 1, "score": baseScore}
  scores.add %*{"position": 2, "score": 0.0}
  scores.add %*{"position": 3, "score": 0.0}
  scores.add %*{"position": 4, "score": 0.0}
  scores.add %*{"position": 5, "score": 0.0}
  scores.add %*{"position": 6, "score": 0.0}
  scores.add %*{"position": 7, "score": 0.0}
  result["participant_scores"] = scores

proc makePlan(
  count: int, fileName = "episodes.json", xp = XpId
): JsonNode =
  ## Builds a synthetic plan with one request and episode_count.
  %*{
    "source": SourceName,
    "experiment": "armor",
    "coworld_id": CowId,
    "coworld_version": CowVer,
    "synthetic": true,
    "baseline": {
      "policy_name": "buyan",
      "version": 1,
      "policy_version_id": BaseId
    },
    "candidate": {
      "policy_name": "buyan-armor",
      "version": 1,
      "policy_version_id": CandId
    },
    "opponents": [
      {
        "policy_name": "relh-nmmo-consensus",
        "version": 1,
        "policy_version_id": RelhId,
        "seats": 2
      },
      {
        "policy_name": "nmmo-opt",
        "version": 6,
        "policy_version_id": OptId,
        "seats": 2
      },
      {
        "policy_name": "daveey-nmmo-nim",
        "version": 11,
        "policy_version_id": DaveId,
        "seats": 2
      }
    ],
    "requests": [
      {
        "xp_id": xp,
        "episodes_file": fileName,
        "episode_count": count
      }
    ]
  }

proc makeAct(
  id: string, pos = 0, verified = true, triggers = 1,
  logPath = "synthetic/log", metric = "synthetic metric", xp = XpId
): JsonNode =
  ## Builds one synthetic activation row. Scores are never placed here.
  %*{
    "xp_id": xp,
    "episode_id": id,
    "candidate_position": pos,
    "verified": verified,
    "trigger_count": triggers,
    "log_path": logPath,
    "metric": metric
  }

proc makeActs(ids: seq[string], xp = XpId): JsonNode =
  ## Builds a synthetic activation document for the given episode ids.
  result = %*{
    "source": SourceName,
    "experiment": "armor",
    "coworld_id": CowId,
    "coworld_version": CowVer,
    "candidate_policy_version_id": CandId
  }
  var rows = newJArray()
  for id in ids:
    rows.add makeAct(id, xp = xp)
  result["episodes"] = rows

proc runCompare(
  plan, acts: JsonNode, episodes: seq[JsonNode], path = "episodes.json"
): JsonNode =
  ## Compares constructed synthetic JSON nodes.
  compare(plan, acts, @[(path, toArray(episodes))])

echo "Testing exact sign-test p-values"
doAssert signTestP(10, 0) == 0.001953125
doAssert signTestP(9, 1) == 0.021484375
doAssert signTestP(0, 0) == 1.0
doAssert signTestP(300, 0) == pow(2.0, -299.0)
doAssert signTestP(0, 300) == pow(2.0, -299.0)
block:
  let err = expectError:
    discard signTestP(301, 0)
  doAssert "300" in err
block:
  let err = expectError:
    discard signTestP(0, 301)
  doAssert "300" in err

echo "Testing schedule boundary gates"
doAssert decideGate(0, 0, 0, 0, 0.0, 1.0) == "insufficient_data"
doAssert decideGate(9, 9, 0, 0, 1.0, signTestP(9, 0)) ==
  "insufficient_data"
doAssert decideGate(10, 10, 0, 0, 1.0, signTestP(10, 0)) == "support"
doAssert decideGate(11, 11, 0, 0, 1.0, signTestP(11, 0)) == "off_schedule"
doAssert decideGate(29, 29, 0, 0, 1.0, signTestP(29, 0)) == "off_schedule"
doAssert decideGate(30, 30, 0, 0, 1.0, signTestP(30, 0)) == "support"
doAssert decideGate(31, 31, 0, 0, 1.0, signTestP(31, 0)) == "off_schedule"
doAssert decideGate(99, 99, 0, 0, 1.0, signTestP(99, 0)) == "off_schedule"
doAssert decideGate(100, 100, 0, 0, 1.0, signTestP(100, 0)) == "support"
doAssert decideGate(101, 101, 0, 0, 1.0, signTestP(101, 0)) == "off_schedule"
doAssert decideGate(299, 299, 0, 0, 1.0, signTestP(299, 0)) == "off_schedule"
doAssert decideGate(300, 300, 0, 0, 1.0, signTestP(300, 0)) == "support"
doAssert decideGate(301, 301, 0, 0, 1.0, 0.0) == "off_schedule"

echo "Testing mean-direction and negative gates"
doAssert decideGate(10, 10, 0, 0, 0.0, signTestP(10, 0)) == "inconclusive"
doAssert decideGate(10, 0, 10, 0, -1.0, signTestP(0, 10)) == "negative"
doAssert decideGate(10, 6, 4, 0, 0.5, signTestP(6, 4)) == "inconclusive"
doAssert decideGate(10, 10, 0, 1, 1.0, signTestP(10, 0)) ==
  "awaiting_completion"
block:
  let err = expectError:
    discard decideGate(10, 6, 4, 0, 0.5, 0.0)
  doAssert "p-value" in err
block:
  let err = expectError:
    discard decideGate(10, -1, 0, 0, 1.0, 1.0)
  doAssert "nonnegative" in err
block:
  let err = expectError:
    discard decideGate(3, 2, 2, 0, 1.0, 1.0)
  doAssert "wins+losses" in err

echo "Testing ten synthetic wins, one observation per episode"
block:
  var
    episodes: seq[JsonNode]
    ids: seq[string]
  for i in countdown(9, 0):
    ids.insert("ereq_" & $i, 0)
    episodes.add makeEpisode("ereq_" & $i, i, 1.0, 2.0)
  let report = runCompare(makePlan(10), makeActs(ids), episodes)
  doAssert report["synthetic"].getBool
  doAssert report["score_claim"].getStr == "none"
  doAssert report["n"].getInt == 10
  doAssert report["wins"].getInt == 10
  doAssert report["losses"].getInt == 0
  doAssert report["ties"].getInt == 0
  doAssert report["non_ties"].getInt == 10
  doAssert report["sign_test_p"].getFloat == 0.001953125
  doAssert report["baseline_mean"].getFloat == 1.0
  doAssert report["candidate_mean"].getFloat == 2.0
  doAssert report["paired_mean_diff"].getFloat == 1.0
  doAssert report["total_activations"].getInt == 10
  doAssert report["gates"]["status"].getStr == "support"
  doAssert report["dashboard_required"].getBool
  doAssert report["episodes"].len == 10
  doAssert report["episodes"][0]["episode_id"].getStr == "ereq_0"
  doAssert report["episodes"][9]["episode_id"].getStr == "ereq_9"
  doAssert "KEEP" notin report.pretty
  doAssert report["unresolved_episodes"].getInt == 0

echo "Testing ten synthetic ties"
block:
  var episodes: seq[JsonNode]
  var ids: seq[string]
  for i in 0 ..< 10:
    let id = "ereq_tie_" & $i
    ids.add(id)
    episodes.add makeEpisode(id, i, 3.0, 3.0)
  let report = runCompare(makePlan(10), makeActs(ids), episodes)
  doAssert report["n"].getInt == 10
  doAssert report["ties"].getInt == 10
  doAssert report["non_ties"].getInt == 0
  doAssert report["sign_test_p"].getFloat == 1.0
  doAssert report["gates"]["status"].getStr == "inconclusive"

echo "Testing nine wins and one loss"
block:
  var episodes: seq[JsonNode]
  var ids: seq[string]
  for i in 0 ..< 9:
    let id = "ereq_w_" & $i
    ids.add(id)
    episodes.add makeEpisode(id, i, 1.0, 2.0)
  ids.add("ereq_loss")
  episodes.add makeEpisode("ereq_loss", 9, 5.0, 4.0)
  let report = runCompare(makePlan(10), makeActs(ids), episodes)
  doAssert report["wins"].getInt == 9
  doAssert report["losses"].getInt == 1
  doAssert report["sign_test_p"].getFloat == 0.021484375
  doAssert report["gates"]["status"].getStr == "inconclusive"

echo "Testing awaiting_completion blocks support on a look-sized subset"
block:
  var episodes: seq[JsonNode]
  var ids: seq[string]
  for i in 0 ..< 10:
    let id = "ereq_ok_" & $i
    ids.add(id)
    episodes.add makeEpisode(id, i, 1.0, 2.0)
  ids.add("ereq_pending")
  episodes.add makeEpisode("ereq_pending", 10, 1.0, 2.0, "pending")
  let report = runCompare(makePlan(11), makeActs(ids), episodes)
  doAssert report["n"].getInt == 10
  doAssert report["unresolved_episodes"].getInt == 1
  doAssert report["unresolved_requests"].getInt == 1
  doAssert report["exclusions"]["pending"].getInt == 1
  doAssert report["gates"]["status"].getStr == "awaiting_completion"

echo "Testing running and submitted are unresolved"
block:
  var episodes: seq[JsonNode]
  var ids: seq[string]
  for i in 0 ..< 8:
    let id = "ereq_r_" & $i
    ids.add(id)
    episodes.add makeEpisode(id, i, 1.0, 2.0)
  ids.add("ereq_run")
  episodes.add makeEpisode("ereq_run", 8, 1.0, 2.0, "running")
  ids.add("ereq_sub")
  episodes.add makeEpisode("ereq_sub", 9, 1.0, 2.0, "submitted")
  let report = runCompare(makePlan(10), makeActs(ids), episodes)
  doAssert report["n"].getInt == 8
  doAssert report["unresolved_episodes"].getInt == 2
  doAssert report["gates"]["status"].getStr == "awaiting_completion"

echo "Testing cancelled is terminal and does not await"
block:
  var episodes: seq[JsonNode]
  var ids: seq[string]
  for i in 0 ..< 10:
    let id = "ereq_c_" & $i
    ids.add(id)
    episodes.add makeEpisode(id, i, 1.0, 2.0)
  ids.add("ereq_cancelled")
  episodes.add makeEpisode("ereq_cancelled", 10, 1.0, 2.0, "cancelled")
  let report = runCompare(makePlan(11), makeActs(ids), episodes)
  doAssert report["n"].getInt == 10
  doAssert report["unresolved_episodes"].getInt == 0
  doAssert report["exclusions"]["cancelled"].getInt == 1
  doAssert report["gates"]["status"].getStr == "support"

echo "Testing failed exclusion and missing candidate on a failed episode"
block:
  var episodes: seq[JsonNode]
  var ids: seq[string]
  for i in 0 ..< 9:
    let id = "ereq_f_" & $i
    ids.add(id)
    episodes.add makeEpisode(id, i, 1.0, 2.0)
  let failed = makeEpisode("ereq_failed", 9, 1.0, 2.0, "failed")
  ids.add("ereq_failed")
  episodes.add failed
  let report = runCompare(makePlan(10), makeActs(ids), episodes)
  doAssert report["exclusions"]["failed"].getInt == 1
  doAssert report["n"].getInt == 9
  doAssert report["gates"]["status"].getStr == "insufficient_data"
  var missing = makeEpisode("ereq_miss", 0, 1.0, 2.0, "failed")
  var parts = newJArray()
  parts.add makeSeat(1, "buyan", 1, BaseId)
  parts.add makeSeat(2, "relh-nmmo-consensus", 1, RelhId)
  parts.add makeSeat(3, "relh-nmmo-consensus", 1, RelhId)
  parts.add makeSeat(4, "nmmo-opt", 6, OptId)
  parts.add makeSeat(5, "nmmo-opt", 6, OptId)
  parts.add makeSeat(6, "daveey-nmmo-nim", 11, DaveId)
  parts.add makeSeat(7, "daveey-nmmo-nim", 11, DaveId)
  missing["participants"] = parts
  let missOut = runCompare(
    makePlan(1), makeActs(@["ereq_miss"]), @[missing])
  doAssert missOut["exclusions"]["missing_participant"].getInt == 1
  doAssert missOut["exclusions"]["failed"].getInt == 0

echo "Testing missing score, evidence, unverified, and not_triggered"
block:
  var nanEp = makeEpisode("ereq_nan", 0, 1.0, 2.0)
  nanEp["participant_scores"][0]["score"] = newJFloat(NaN)
  var infEp = makeEpisode("ereq_inf", 1, 1.0, 2.0)
  infEp["participant_scores"][1]["score"] = newJFloat(Inf)
  var nullEp = makeEpisode("ereq_null", 2, 1.0, 2.0)
  nullEp["participant_scores"][0]["score"] = newJNull()
  var noEv = makeEpisode("ereq_noev", 3, 1.0, 2.0)
  var unver = makeEpisode("ereq_unver", 4, 1.0, 2.0)
  var emptyM = makeEpisode("ereq_empty", 5, 1.0, 2.0)
  var zeroT = makeEpisode("ereq_zero", 6, 1.0, 2.0)
  var ok = makeEpisode("ereq_ok", 7, 1.0, 2.0)
  var acts = makeActs(@["ereq_nan", "ereq_inf", "ereq_null", "ereq_unver",
    "ereq_empty", "ereq_zero", "ereq_ok"])
  acts["episodes"][3]["verified"] = %false
  acts["episodes"][4]["metric"] = %""
  acts["episodes"][5]["trigger_count"] = %0
  let report = runCompare(makePlan(8), acts, @[
    nanEp, infEp, nullEp, noEv, unver, emptyM, zeroT, ok])
  doAssert report["n"].getInt == 1
  doAssert report["exclusions"]["missing_score"].getInt == 3
  doAssert report["exclusions"]["missing_evidence"].getInt == 1
  doAssert report["exclusions"]["unverified_evidence"].getInt == 2
  doAssert report["exclusions"]["not_triggered"].getInt == 1
  doAssert report["total_activations"].getInt == 1

echo "Testing absent or null participant_scores is missing_score"
block:
  var noKey = makeEpisode("ereq_noscores", 0, 1.0, 2.0)
  noKey.delete("participant_scores")
  let noKeyReport = runCompare(
    makePlan(1), makeActs(@["ereq_noscores"]), @[noKey])
  doAssert noKeyReport["exclusions"]["missing_score"].getInt == 1
  doAssert noKeyReport["n"].getInt == 0
  var nullArr = makeEpisode("ereq_nullarr", 0, 1.0, 2.0)
  nullArr["participant_scores"] = newJNull()
  let nullReport = runCompare(
    makePlan(1), makeActs(@["ereq_nullarr"]), @[nullArr])
  doAssert nullReport["exclusions"]["missing_score"].getInt == 1
  var badType = makeEpisode("ereq_badtype", 0, 1.0, 2.0)
  badType["participant_scores"] = %*{"position": 0, "score": 1.0}
  let errArray = expectError:
    discard runCompare(
      makePlan(1), makeActs(@["ereq_badtype"]), @[badType])
  doAssert "array" in errArray

echo "Testing duplicate score scanned before missing score return"
block:
  var dup = makeEpisode("ereq_dupscore", 0, 1.0, 2.0)
  dup["participant_scores"][0]["score"] = newJNull()
  dup["participant_scores"].add %*{"position": 0, "score": 9.0}
  let errDupScore = expectError:
    discard runCompare(
      makePlan(1), makeActs(@["ereq_dupscore"]), @[dup])
  doAssert "Duplicate score" in errDupScore

echo "Testing overflow of paired differences is rejected"
block:
  let ep = makeEpisode("ereq_ovf", 0, -1e308, 1e308)
  let msg = expectError:
    discard runCompare(makePlan(1), makeActs(@["ereq_ovf"]), @[ep])
  doAssert "Non-finite" in msg

echo "Testing source, identity, and version mismatches"
block:
  let ep = makeEpisode("ereq_x", 0, 1.0, 2.0)
  var plan = makePlan(1)
  plan["source"] = %"other-source"
  let errSrcPlan = expectError:
    discard runCompare(plan, makeActs(@["ereq_x"]), @[ep])
  doAssert "source" in errSrcPlan
  plan = makePlan(1)
  var acts = makeActs(@["ereq_x"])
  acts["source"] = %"other-source"
  let errSrcActs = expectError:
    discard runCompare(plan, acts, @[ep])
  doAssert "source" in errSrcActs
  acts = makeActs(@["ereq_x"])
  acts["coworld_version"] = %"0.0.0"
  let errCowVer = expectError:
    discard runCompare(makePlan(1), acts, @[ep])
  doAssert "coworld_version" in errCowVer
  acts = makeActs(@["ereq_x"])
  acts["candidate_policy_version_id"] = %"other"
  let errCand = expectError:
    discard runCompare(makePlan(1), acts, @[ep])
  doAssert "candidate" in errCand
  var badField = ep.copy
  badField["coworld_id"] = %"cow_other"
  let errCowId = expectError:
    discard runCompare(makePlan(1), makeActs(@["ereq_x"]), @[badField])
  doAssert "coworld_id" in errCowId
  var unexpected = ep.copy
  unexpected["participants"].elems[2] = makeSeat(
    2, "stranger", 1, "not-an-opponent")
  let errUnexp = expectError:
    discard runCompare(
      makePlan(1), makeActs(@["ereq_x"]), @[unexpected])
  doAssert "Unexpected identity" in errUnexp
  var failedUnexpected = unexpected.copy
  failedUnexpected["status"] = %"failed"
  let errUnexpFail = expectError:
    discard runCompare(
      makePlan(1), makeActs(@["ereq_x"]), @[failedUnexpected])
  doAssert "Unexpected identity" in errUnexpFail

echo "Testing empty experiment, coworld, and episode ids"
block:
  let ep = makeEpisode("ereq_x", 0, 1.0, 2.0)
  var plan = makePlan(1)
  plan["experiment"] = %""
  let errExp = expectError:
    discard runCompare(plan, makeActs(@["ereq_x"]), @[ep])
  doAssert "experiment" in errExp
  plan = makePlan(1)
  plan["coworld_id"] = %""
  let errEmptyCow = expectError:
    discard runCompare(plan, makeActs(@["ereq_x"]), @[ep])
  doAssert "coworld_id" in errEmptyCow
  var emptyId = ep.copy
  emptyId["id"] = %""
  let errEmptyId = expectError:
    discard runCompare(
      makePlan(1), makeActs(@["ereq_x"]), @[emptyId])
  doAssert "id" in errEmptyId

echo "Testing policy_version_id uniqueness and baseline/candidate split"
block:
  let ep = makeEpisode("ereq_x", 0, 1.0, 2.0)
  var plan = makePlan(1)
  plan["candidate"]["policy_version_id"] = %BaseId
  let errPvidCand = expectError:
    discard runCompare(plan, makeActs(@["ereq_x"]), @[ep])
  doAssert "policy_version_id" in errPvidCand
  plan = makePlan(1)
  plan["opponents"][0]["policy_version_id"] = %BaseId
  let errPvidOpp = expectError:
    discard runCompare(plan, makeActs(@["ereq_x"]), @[ep])
  doAssert "policy_version_id" in errPvidOpp

echo "Testing duplicate episode, position, evidence, and job_index"
block:
  let a = makeEpisode("ereq_dup", 0, 1.0, 2.0)
  let b = makeEpisode("ereq_dup", 1, 1.0, 2.0)
  let errDupEp = expectError:
    discard runCompare(makePlan(2), makeActs(@["ereq_dup"]), @[a, b])
  doAssert "Duplicate episode" in errDupEp
  var pos = makeEpisode("ereq_pos", 0, 1.0, 2.0)
  pos["participants"].elems[1]["position"] = %0
  let errDupPos = expectError:
    discard runCompare(makePlan(1), makeActs(@["ereq_pos"]), @[pos])
  doAssert "Duplicate position" in errDupPos
  var acts = makeActs(@["ereq_x", "ereq_x"])
  acts["episodes"][1]["episode_id"] = %"ereq_x"
  let errDupAct = expectError:
    discard runCompare(
      makePlan(1), acts, @[makeEpisode("ereq_x", 0, 1.0, 2.0)])
  doAssert "Duplicate activation" in errDupAct
  let j0 = makeEpisode("ereq_j0", 3, 1.0, 2.0)
  let j1 = makeEpisode("ereq_j1", 3, 1.0, 2.0)
  let errDupJob = expectError:
    discard runCompare(
      makePlan(2), makeActs(@["ereq_j0", "ereq_j1"]), @[j0, j1])
  doAssert "Duplicate job_index" in errDupJob

echo "Testing unknown evidence, wrong xp, and wrong position"
block:
  let ep = makeEpisode("ereq_real", 0, 1.0, 2.0)
  let errGhost = expectError:
    discard runCompare(makePlan(1), makeActs(@["ereq_ghost"]), @[ep])
  doAssert "Unknown activation" in errGhost
  var acts = makeActs(@["ereq_real"])
  acts["episodes"][0]["xp_id"] = %"xreq_other"
  let errXp = expectError:
    discard runCompare(makePlan(1), acts, @[ep])
  doAssert "xp_id" in errXp
  acts = makeActs(@["ereq_real"])
  acts["episodes"][0]["candidate_position"] = %1
  let errPos = expectError:
    discard runCompare(makePlan(1), acts, @[ep])
  doAssert "candidate_position" in errPos

echo "Testing episode_count mismatch and extra file"
block:
  let ep = makeEpisode("ereq_n", 0, 1.0, 2.0)
  let errCount = expectError:
    discard runCompare(makePlan(2), makeActs(@["ereq_n"]), @[ep])
  doAssert "episode_count" in errCount
  let errFiles = expectError:
    discard compare(makePlan(1), makeActs(@["ereq_n"]), @[
      ("episodes.json", toArray(@[ep])),
      ("extra.json", toArray(@[ep]))
    ])
  doAssert "file count" in errFiles

echo "Testing basename is not enough to match episode files"
block:
  let ep = makeEpisode("ereq_path", 0, 1.0, 2.0)
  let errMissing = expectError:
    discard compare(
      makePlan(1, "/expected/episodes.json"),
      makeActs(@["ereq_path"]),
      @[("/other/episodes.json", toArray(@[ep]))])
  doAssert "Missing episodes file" in errMissing

echo "Testing wrapper id match, entries key, and missing episode_count"
block:
  let ep = makeEpisode("ereq_w", 0, 1.0, 2.0)
  var wrap = %*{"id": XpId}
  wrap["episodes"] = toArray(@[ep])
  let ok = compare(makePlan(1), makeActs(@["ereq_w"]),
    @[("episodes.json", wrap)])
  doAssert ok["n"].getInt == 1
  var bad = wrap.copy
  bad["id"] = %"xreq_other"
  let errWrap = expectError:
    discard compare(makePlan(1), makeActs(@["ereq_w"]),
      @[("episodes.json", bad)])
  doAssert "Wrapper id" in errWrap
  var entries = newJObject()
  entries["entries"] = toArray(@[ep])
  let fromEntries = compare(makePlan(1), makeActs(@["ereq_w"]),
    @[("episodes.json", entries)])
  doAssert fromEntries["n"].getInt == 1
  var plan = makePlan(1)
  plan["requests"][0].delete("episode_count")
  let errMissingCount = expectError:
    discard runCompare(plan, makeActs(@["ereq_w"]), @[ep])
  doAssert "episode_count" in errMissingCount

echo "Testing episode-level optional metadata must match when present"
block:
  var localEp = makeEpisode("ereq_local", 0, 1.0, 2.0)
  localEp["source"] = %"local"
  let errLocalSrc = expectError:
    discard runCompare(
      makePlan(1), makeActs(@["ereq_local"]), @[localEp])
  doAssert "source" in errLocalSrc
  var xpEp = makeEpisode("ereq_xp", 0, 1.0, 2.0)
  xpEp["xp_id"] = %"xreq_other"
  let errLocalXp = expectError:
    discard runCompare(makePlan(1), makeActs(@["ereq_xp"]), @[xpEp])
  doAssert "xp_id" in errLocalXp
  var expEp = makeEpisode("ereq_exp", 0, 1.0, 2.0)
  expEp["experiment"] = %"other-exp"
  let errLocalExp = expectError:
    discard runCompare(makePlan(1), makeActs(@["ereq_exp"]), @[expEp])
  doAssert "experiment" in errLocalExp

echo "Testing activation scores are ignored"
block:
  let ep = makeEpisode("ereq_sc", 0, 4.0, 7.0)
  var acts = makeActs(@["ereq_sc"])
  acts["episodes"][0]["score"] = %999.0
  let report = runCompare(makePlan(1), acts, @[ep])
  doAssert report["episodes"][0]["diff"].getFloat == 3.0
  doAssert report["candidate_mean"].getFloat == 7.0

echo "Testing two requests preserve plan order"
block:
  var plan = makePlan(1, "first.json", "xreq_first")
  plan["requests"].add %*{
    "xp_id": "xreq_second",
    "episodes_file": "second.json",
    "episode_count": 1
  }
  let a = makeEpisode("ereq_a", 5, 1.0, 2.0)
  let b = makeEpisode("ereq_b", 1, 1.0, 3.0)
  var acts = %*{
    "source": SourceName,
    "experiment": "armor",
    "coworld_id": CowId,
    "coworld_version": CowVer,
    "candidate_policy_version_id": CandId,
    "episodes": [
      makeAct("ereq_a", xp = "xreq_first"),
      makeAct("ereq_b", xp = "xreq_second")
    ]
  }
  let report = compare(plan, acts, @[
    ("second.json", toArray(@[b])),
    ("first.json", toArray(@[a]))
  ])
  doAssert report["episodes"][0]["episode_id"].getStr == "ereq_a"
  doAssert report["episodes"][1]["episode_id"].getStr == "ereq_b"
  doAssert report["n"].getInt == 2

echo "Testing n>300 is off_schedule with null sign_test_p"
block:
  var episodes: seq[JsonNode]
  var ids: seq[string]
  for i in 0 ..< 301:
    let id = "ereq_big_" & $i
    ids.add(id)
    episodes.add makeEpisode(id, i, 1.0, 2.0)
  let report = runCompare(makePlan(301), makeActs(ids), episodes)
  doAssert report["n"].getInt == 301
  doAssert report["wins"].getInt == 301
  doAssert report["sign_test_p"].kind == JNull
  doAssert report["gates"]["status"].getStr == "off_schedule"

echo "Writing synthetic 10-win CLI fixture set"
block:
  let dir = currentSourcePath().parentDir / "synthetic"
  createDir(dir)
  var episodes: seq[JsonNode]
  var ids: seq[string]
  for i in 0 ..< 10:
    let id = "ereq_cli_" & $i
    ids.add(id)
    episodes.add makeEpisode(id, i, 1.0, 2.0)
  let plan = makePlan(10, "episodes.json", XpId)
  let acts = makeActs(ids, XpId)
  writeFile(dir / "plan.json", plan.pretty)
  writeFile(dir / "activations.json", acts.pretty)
  writeFile(dir / "episodes.json", toArray(episodes).pretty)

echo "All synthetic comparison tests passed"
