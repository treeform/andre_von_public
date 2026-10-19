import std/[json, math, os, sets, strutils, tables]

const
  Alpha = 0.001
  Player = "ply_3d22435e-30a2-4f2a-b037-a5c249583788"
  Opponents = [
    "daveey-scripted:v39",
    "co-gas-moba-topstack-richard:v7",
    "co-gas-moba-topstack-relhalpha:v3"
  ]

type
  MobaError = object of CatchableError
  Stratum = object
    baseline, candidate: seq[int]
  Comparison = object
    count, observed: int
    baselineMean, candidateMean, probability: float

proc choose(n, k: int): float =
  ## Compute a binomial coefficient without factorial overflow.
  if k < 0 or k > n:
    return 0
  result = 1
  for i in 1 .. min(k, n - k):
    result *= float(n - i + 1) / float(i)

proc distribution(scores: openArray[int], count: int): seq[float] =
  ## Enumerate exact score totals when selecting count pooled episodes.
  var frequencies: array[3, int]
  for score in scores:
    if score < 0 or score > 2:
      raise newException(MobaError, "Score must be zero, one or two")
    inc frequencies[score]
  result = newSeq[float](2 * count + 1)
  let denominator = choose(scores.len, count)
  if denominator == 0:
    raise newException(MobaError, "Invalid permutation sample size")
  for wins in 0 .. min(count, frequencies[2]):
    for draws in 0 .. min(count - wins, frequencies[1]):
      let losses = count - wins - draws
      if losses > frequencies[0]:
        continue
      result[2 * wins + draws] +=
        choose(frequencies[2], wins) * choose(frequencies[1], draws) *
        choose(frequencies[0], losses) / denominator

proc compare(strata: Table[string, Stratum]): Comparison =
  ## Test a candidate using exact permutations within opponent and side.
  var
    probabilities = @[1.0]
    baselineTotal = 0
  if strata.len == 0:
    raise newException(MobaError, "No strata to compare")
  for key, stratum in strata:
    if stratum.baseline.len == 0 or
      stratum.baseline.len != stratum.candidate.len:
        raise newException(MobaError, "Unmatched cohort: " & key)
    let local = distribution(
      stratum.baseline & stratum.candidate,
      stratum.candidate.len
    )
    var combined = newSeq[float](probabilities.len + local.len - 1)
    for i, weight in probabilities:
      for j, chance in local:
        combined[i + j] += weight * chance
    probabilities = move(combined)
    for score in stratum.candidate:
      result.observed += score
    for score in stratum.baseline:
      baselineTotal += score
    result.count += stratum.candidate.len
  for i in result.observed ..< probabilities.len:
    result.probability += probabilities[i]
  result.probability = min(1.0, result.probability)
  result.baselineMean = float(baselineTotal) / (2.0 * float(result.count))
  result.candidateMean = float(result.observed) / (2.0 * float(result.count))

proc load(
  paths, label: string,
  candidate: bool,
  strata: var Table[string, Stratum],
  seen: var HashSet[string]
) =
  ## Load only fully completed hosted XP cohorts with exact provenance.
  for path in paths.split(','):
    let request = parseFile(path)
    if request{"status"}.getStr != "completed":
      raise newException(MobaError, "Request incomplete: " & path)
    if request{"episodes"}.len != request{"episode_count"}.getInt:
      raise newException(MobaError, "Episode count mismatch: " & path)
    for episode in request["episodes"]:
      let id = episode["id"].getStr
      if id in seen:
        raise newException(MobaError, "Duplicate episode: " & id)
      seen.incl(id)
      if episode{"status"}.getStr != "completed":
        raise newException(MobaError, "Episode incomplete: " & id)
      if episode{"participants"}.len != 2:
        raise newException(MobaError, "Expected two teams: " & id)
      var
        seat = -1
        opponent = ""
      for participant in episode["participants"]:
        if participant["label"].getStr == label:
          if participant{"player_id"}.getStr != Player:
            raise newException(MobaError, "Wrong focal player: " & id)
          seat = participant["position"].getInt
        else:
          if participant{"label"}.getStr notin Opponents:
            raise newException(MobaError, "Opponent outside top-three field")
          opponent = participant["policy_version_id"].getStr
      if seat < 0 or opponent.len == 0:
        raise newException(MobaError, "Policy absent or ambiguous: " & id)
      var score = -1
      for entry in episode["participant_scores"]:
        if entry["position"].getInt == seat:
          let value = entry["score"].getFloat
          score = int(round(value * 2))
          if score < 0 or score > 2 or abs(float(score) - 2 * value) > 1e-8:
            raise newException(MobaError, "Invalid MOBA score: " & id)
      if score < 0:
        raise newException(MobaError, "Missing participant score: " & id)
      let key = opponent & "|" & $seat & "|" &
        episode["coworld_id"].getStr & "|" & $episode["game_config"]
      var stratum = strata.getOrDefault(key)
      if candidate:
        stratum.candidate.add(score)
      else:
        stratum.baseline.add(score)
      strata[key] = move(stratum)

proc main() =
  ## Report hosted score significance independently of the trigger gate.
  if paramCount() != 4:
    raise newException(MobaError,
      "Usage: statistics baselineLabel candidateLabel baseFiles candFiles")
  var
    strata = initTable[string, Stratum]()
    seen = initHashSet[string]()
  load(paramStr(3), paramStr(1), false, strata, seen)
  load(paramStr(4), paramStr(2), true, strata, seen)
  if strata.len != 6:
    raise newException(MobaError, "Require three opponents and both sides")
  let result = compare(strata)
  echo (%*{
    "episodesPerPolicy": result.count,
    "strata": strata.len,
    "baselineMean": result.baselineMean,
    "candidateMean": result.candidateMean,
    "effect": result.candidateMean - result.baselineMean,
    "oneSidedExactP": result.probability,
    "alpha": Alpha,
    "scoreGate": result.count >= 10 and result.probability <= Alpha and
      result.candidateMean > result.baselineMean,
    "triggerGate": "Required separately; this output cannot authorize keep"
  }).pretty

when not defined(statisticsTest):
  main()
