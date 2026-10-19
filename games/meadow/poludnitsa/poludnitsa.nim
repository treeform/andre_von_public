## Poludnitsa — Meadow policy for Andre von Auto.
## Command player: the meadow container decides every round itself. League
## rank is individual score (harvest minus sanction costs/burns), not group
## welfare. The example enforcer's quota-1 harvest is the social-planner
## move and loses ~37–180 to a unique max-harvester on the default field.
## Take max_harvest every round (the individually dominant demand, including
## post-collapse scramble). Still pay to sanction the worst over-quota rival
## when the institutions treatment exposes the ledger, so a fellow forager
## eats the burn.
##
## Protocol (docs/protocol_player.md): one `observation` per settled round,
## reply `{"harvest": int, "sanction": slot?}`; the last action sent before
## the round settles wins; `final` ends the episode.
##
## Env:
##   POLUDNITSA_QUOTA  over-harvest threshold for sanctions (default 1)

import std/[json, os, strutils], coworld_client

let quota = getEnv("POLUDNITSA_QUOTA", "1").parseInt()

proc worstOffender(observation: JsonNode): int =
  ## The slot that over-harvested the most last round (ties to the lower
  ## slot, matching the reference's max over (harvest, -slot)); -1 if none.
  result = -1
  let harvests = observation{"last_round_harvests"}
  if harvests.isNil or harvests.kind != JArray:
    return
  let ownSlot = observation{"slot"}.getInt()
  var worstHarvest = quota.float
  for slot in 0 ..< harvests.len:
    if slot == ownSlot:
      continue
    let harvest = harvests[slot].getFloat()
    if harvest > quota.float and harvest > worstHarvest:
      worstHarvest = harvest
      result = slot

proc act(observation: JsonNode): JsonNode =
  result = %*{"harvest": observation{"max_harvest"}.getInt()}
  if observation{"sanctions_enabled"}.getBool():
    let offender = observation.worstOffender()
    if offender >= 0:
      result["sanction"] = %offender

proc main() =
  let client = newCoworldClient("poludnitsa")
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "observation":
      client.send(act(message))
    of "final":
      echo "poludnitsa: final, score ", message{"score"}.getFloat(),
        " collapsed ", message{"collapsed"}.getBool()
      quit(0)
    else:
      discard

main()
