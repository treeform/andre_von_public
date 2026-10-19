import std/[json, os]

const
  PlayerId = "ply_3d22435e-30a2-4f2a-b037-a5c249583788"
  BaselineId = "a611afbe-e669-418f-99ae-89251052d393"
  CoworldId = "cow_6272bfca-6bfa-4268-be2c-9ee35f669cfc"
  Trials = ["escape", "armor", "hunt", "clean", "sword"]
  CandidateIds = [
    "8d6716b8-b998-40f5-8b67-3123880c7a59",
    "78d99b9e-68c5-49c1-a398-8b09263a6c7a",
    "67cb619d-f8df-42b9-a2d2-b6c45cd15801",
    "2aa2975d-3f39-45b3-917b-de9f2e3f9a7a",
    "3f79b2b2-7096-4cd2-bd82-086153b54d28"
  ]

type BuyanError = object of CatchableError

proc policy(name: string, version: int, id: string, seats = 1): JsonNode =
  ## Encode a policy identity fixed before reading any scores.
  %*{"policy_name": name, "version": version,
    "policy_version_id": id, "seats": seats}

proc build(index: int) =
  ## Register both requests and locate completed hosted activation evidence.
  let
    trial = Trials[index]
    directory = currentSourcePath().parentDir() / "experiments" / trial
    destination = directory / "cohort"
    candidateId = CandidateIds[index]
    plan = %*{
      "source": "softmax-hosted-xp", "experiment": trial,
      "coworld_id": CoworldId, "coworld_version": "0.1.5",
      "baseline": policy("buyan", 1, BaselineId),
      "candidate": policy("buyan", index + 2, candidateId),
      "opponents": [
        policy("relh-nmmo-consensus", 1,
          "87adca41-a779-43a0-addf-282af50800a8", 2),
        policy("nmmo-opt", 6,
          "a319845e-01db-4d23-a938-3f4ed55f02be", 2),
        policy("daveey-nmmo-nim", 11,
          "ee828572-195d-4318-bdbb-0b4cb2bc1295", 2)
      ],
      "requests": []
    }
    evidence = %*{"source": "softmax-hosted-xp", "episodes": []}
  createDir(destination)
  for batch in ["a", "b"]:
    let
      responsePath = directory / ("response_version_" & batch & ".json")
      statusPath = directory / ("status_version_" & batch & ".json")
      receipt = parseJson(readFile(responsePath))
      snapshot = parseJson(readFile(statusPath))
      xpId = receipt["id"].getStr()
    if snapshot["id"].getStr() != xpId or
      snapshot["coworld_id"].getStr() != CoworldId or
      snapshot["episode_count"].getInt() != 15:
        raise newException(BuyanError, "Unexpected registered request.")
    plan["requests"].add(%*{
      "xp_id": xpId, "episodes_file": statusPath, "episode_count": 15
    })
    for episode in snapshot["episodes"]:
      var candidatePosition = -1
      for participant in episode["participants"]:
        let id = participant["policy_version_id"].getStr()
        if id == candidateId:
          candidatePosition = participant["position"].getInt()
        if id == candidateId or id == BaselineId:
          if participant["player_id"].getStr() != PlayerId:
            raise newException(BuyanError, "Wrong player identity.")
      if candidatePosition < 0:
        raise newException(BuyanError, "Candidate missing from request.")
      if episode["status"].getStr() != "completed":
        continue
      let
        id = episode["id"].getStr()
        hosted = directory / "hosted"
      evidence["episodes"].add(%*{
        "xp_id": xpId, "episode_id": id,
        "candidate_position": candidatePosition,
        "log_path": hosted / id / ("agent_" & $candidatePosition & ".log"),
        "replay_path": hosted / (id & ".replay")
      })
  let
    path = destination / "plan.json"
    serialized = pretty(plan)
  if fileExists(path) and readFile(path) != serialized:
    raise newException(BuyanError, "Refusing to alter registered plan.")
  writeFile(path, serialized)
  writeFile(destination / "evidence.json", pretty(evidence))
  echo trial, " buyan:v", index + 2, " registered=30 complete=",
    evidence["episodes"].len

proc main() =
  ## Build immutable cohort plans without inspecting hosted scores.
  try:
    for index in 0 ..< Trials.len:
      build(index)
  except BuyanError:
    raise
  except CatchableError as error:
    raise newException(BuyanError, "Cannot register cohort: " & error.msg)

main()
