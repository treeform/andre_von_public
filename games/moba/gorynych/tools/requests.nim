import std/[json, os, strutils]

const
  League = "league_becba59f-4201-43a5-9cd6-970bd92857d9"
  Opponents = [
    "daveey-scripted:v39",
    "co-gas-moba-topstack-richard:v7",
    "co-gas-moba-topstack-relhalpha:v3"
  ]

type MobaError = object of CatchableError

proc main() =
  ## Generate a frozen, balanced opponent field for hosted XP.
  if paramCount() < 4:
    raise newException(MobaError, "Usage: requests policy trial batch count [opponents]")
  let
    policy = paramStr(1)
    trial = paramStr(2)
    batch = paramStr(3)
    count = parseInt(paramStr(4))
    opponents = if paramCount() >= 5: paramStr(5).split(",") else: @Opponents
    directory = "games/moba/gorynych/requests" / trial / batch
  if count < 10 or count mod 2 != 0:
    raise newException(MobaError, "Require an even count of at least ten")
  createDir(directory)
  for i, opponent in opponents:
    let
      key = "moba-20260912-" & trial & "-" & batch & "-" & $i
      body = %*{
        "idempotency_key": key,
        "target": {"league_id": League, "variant_id": "team"},
        "roster": [
          {"player": {"policy_ref": policy}, "slot": -1},
          {"player": {"policy_ref": opponent}, "slot": -1}
        ],
        "num_episodes": count,
        "notes": "MOBA Grok single-change " & trial & "; batch " & batch &
          "; frozen top-three-other-players field 20260912; opponent " & opponent &
          "; compare to submitted gorynych:v1. Hosted scores only."
      }
    writeFile(directory / ($i & ".json"), body.pretty & "\n")
    echo directory / ($i & ".json")

main()
