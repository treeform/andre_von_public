import std/[json, os, strutils]

const
  League = "league_ad6dc809-4696-46f5-99a5-fc2b1c58d082"
  Baseline = "c289efbb-211c-4c2d-92a1-c8a6b67cc4be"

type AwmError = object of CatchableError

proc episodes(text: string): int =
  ## Parses a positive hosted episode count with a useful diagnostic.
  try:
    result = parseInt(text)
  except ValueError as error:
    raise newException(AwmError, "Invalid episode count: " & error.msg)
  if result notin 1 .. 100:
    raise newException(AwmError, "Episode count must be between 1 and 100")

proc main() =
  ## Writes a hosted five-seat evaluation with random seat assignments.
  if paramCount() notin 2 .. 4:
    raise newException(AwmError,
      "Usage: request policy:vN output.json [episodes] [batch]")
  let
    policy = paramStr(1)
    count = if paramCount() >= 3: episodes(paramStr(3)) else: 100
    batch = if paramCount() == 4: "-" & paramStr(4) else: ""
    roster = newJArray()
  roster.add %*{"slot": -1, "player": {"policy_ref": policy}}
  for i in 0 ..< 4:
    roster.add %*{"slot": -1, "player": {"policy_ref": Baseline}}
  let request = %*{
    "idempotency_key": "awm-20261001-" & policy & "-base" & $count & batch,
    "target": {"league_id": League},
    "num_episodes": count,
    "roster": roster,
    "notes": "Radogost MCTS with steering vs four released AWM baselines. " &
      "Random seats and classes, league defaults, no LLM calls."
  }
  writeFile(paramStr(2), request.pretty & "\n")

main()
