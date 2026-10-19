import std/[json, os, strformat, tables]

type
  BuyanError = object of CatchableError
  Scores = object
    total: float
    episodes: int

proc main() =
  ## Describe hosted episodes without issuing a statistical verdict.
  if paramCount() != 1:
    raise newException(BuyanError, "Expected hosted episodes JSON path.")
  let data = parseJson(readFile(paramStr(1)))
  var
    policies: OrderedTable[string, Scores]
    completed = 0
  for episode in data:
    if episode{"status"}.getStr() != "completed":
      continue
    inc completed
    var
      bySeat: Table[int, float]
      totals: OrderedTable[string, float]
      counts: Table[string, int]
    for score in episode["participant_scores"]:
      bySeat[score["position"].getInt()] = score["score"].getFloat()
    for participant in episode["participants"]:
      let
        policy = participant["policy_name"].getStr() & ":v" &
          $participant["version"].getInt()
        seat = participant["position"].getInt()
      if not bySeat.hasKey(seat):
        raise newException(BuyanError, "Missing completed seat score.")
      totals.mgetOrPut(policy, 0.0) += bySeat[seat]
      counts.mgetOrPut(policy, 0) += 1
    for policy, total in totals:
      policies.mgetOrPut(policy, Scores()).total +=
        total / float(counts[policy])
      inc policies[policy].episodes
  echo "Completed hosted episodes: ", completed, " / ", data.len
  for policy, scores in policies:
    echo &"{policy}: n={scores.episodes}, mean=" &
      &"{scores.total / float(scores.episodes):.4f}"
  echo "Descriptive only. No keep or submission verdict."

main()
