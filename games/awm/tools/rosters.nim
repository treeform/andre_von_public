import std/[json, os, sets, strutils]

const
  League = "league_ad6dc809-4696-46f5-99a5-fc2b1c58d082"
  Player = "Andre von Auto"

type AwmError = object of CatchableError

proc readJson(path: string): JsonNode =
  ## Reads structured dashboard evidence with a game-specific diagnostic.
  try:
    result = parseJson(readFile(path))
  except JsonParsingError as error:
    raise newException(AwmError, "Invalid leaderboard JSON: " & error.msg)

proc addOpponent(
  standing: JsonNode,
  roster, opponents: JsonNode,
  seen: var HashSet[string]
) =
  ## Adds one live champion per other player to the hosted roster.
  let name = standing["player"].getStr
  if name == Player or name in seen or
    not standing["champion"].getBool or
    standing["status"].getStr != "competing":
      return
  let reference = standing["policy"].getStr & ":v" &
    $standing["version"].getInt
  roster.add %*{"slot": -1, "player": {"policy_ref": reference}}
  opponents.add %*{"player": name, "policy": reference}
  seen.incl name

proc main() =
  ## Creates a hosted request against every distinct other live champion.
  if paramCount() != 5:
    raise newException(AwmError,
      "Usage: rosters leaderboard.json policy:vN batch episodes output.json")
  let
    board = readJson(paramStr(1))
    policy = paramStr(2)
    batch = paramStr(3)
    roster = newJArray()
    opponents = newJArray()
  var
    count: int
    seen: HashSet[string]
  try:
    count = parseInt(paramStr(4))
  except ValueError as error:
    raise newException(AwmError, "Invalid episode count: " & error.msg)
  if count notin 1 .. 100:
    raise newException(AwmError, "Episode count must be between 1 and 100")
  roster.add %*{"slot": -1, "player": {"policy_ref": policy}}
  for rating in board["ratings"]:
    let name = rating["player"].getStr
    if name == Player or name in seen:
      continue
    for standing in board["standings"]:
      if standing["player"].getStr == name and
        standing["champion"].getBool and
        standing["status"].getStr == "competing":
          addOpponent(standing, roster, opponents, seen)
          break
  for standing in board["standings"]:
    addOpponent(standing, roster, opponents, seen)
  if seen.len == 0:
    raise newException(AwmError, "Need at least one other live champion")
  if roster.len > 7:
    raise newException(AwmError,
      "AWM supports at most seven players; found " & $roster.len)
  let keyPrefix =
    if seen.len == 3:
      "awm-top3-"
    else:
      "awm-all-"
  let request = %*{
    "idempotency_key": keyPrefix & policy & "-" & batch,
    "target": {"league_id": League},
    "num_episodes": count,
    "roster": roster,
    "notes": $roster.len & "-seat AWM against all " & $seen.len &
      " other live champions, in ranking order followed by unrated " &
      "players. One policy per player, random seats and classes, " &
      "distinct episode seeds. " & $opponents
  }
  writeFile(paramStr(5), request.pretty & "\n")
  echo opponents.pretty

main()
