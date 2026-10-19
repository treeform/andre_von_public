import std/[json, os, sets]

const Player = "ply_3d22435e-30a2-4f2a-b037-a5c249583788"

type MobaError = object of CatchableError

proc main() =
  ## Print current top three other players and their live policy records.
  if paramCount() != 1:
    raise newException(MobaError, "Usage: fields league.json")
  let league = parseFile(paramStr(1))
  var names = initHashSet[string]()
  for row in league["ratings"]:
    if row{"playerId"}.getStr == Player:
      continue
    names.incl(row["player"].getStr)
    echo row
    if names.len == 3:
      break
  for row in league["allPolicies"]:
    if row{"player"}.getStr in names and
      row{"champion"}.getBool and row{"substatus"}.getStr == "active":
        echo row

main()
