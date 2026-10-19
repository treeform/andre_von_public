## Rot hygiene: the cloud burns us too, so it goes off when no enemy is
## inside reach on our bank, and before pad healing. Run from this dir:
##   nim r --hints:off -d:myasnikTest test_rot_off.nim

include myasnik

const
  riverWest = 53.0
  riverEast = 75.0

proc pudge(slot, team: int, x, y: float, hp = 840.0, rot = false): JsonNode =
  %*{
    "id": 100 + slot, "slot": slot, "team": team, "x": x, "y": y,
    "hp": hp, "max_hp": 840.0, "alive": true, "hooked": false,
    "shield": false, "hook_ready": false, "blink_ready": false,
    "in_river": false, "rot": rot, "layer": (if x < riverWest: 0 else: 1)
  }

proc observation(me: JsonNode, others: seq[JsonNode] = @[]): JsonNode =
  var pudges = %*[]
  pudges.add me
  for other in others:
    pudges.add other
  %*{
    "type": "observation", "tick": 100.0, "slot": me{"slot"}.getInt,
    "width": 128, "height": 128, "river_west": riverWest, "river_east": riverEast,
    "self": me, "visible": {"pudges": pudges, "hooks": [], "runes": []},
    "ally_ping": newJNull()
  }

block:
  let action = decide(observation(pudge(0, 0, 41.0, 64.0, rot = true)), Memory())
  doAssert flag(action{"rot_toggle"}), "rot left burning with nobody in reach"
  echo "ok rot goes off with nobody in reach"

block:
  ## Enemy on the far bank, 30 tiles away: not a brawl, no rot.
  let action = decide(observation(pudge(0, 0, 41.0, 64.0),
    @[pudge(4, 1, 79.0, 64.0)]), Memory())
  doAssert not action.hasKey("rot_toggle"), "rot switched on for a far enemy"
  echo "ok no rot for a far enemy"

block:
  ## Low HP with rot on: rot off first, healing next.
  let memory = Memory()
  discard decide(observation(pudge(0, 0, 22.0, 40.0)), memory)
  let action = decide(observation(pudge(0, 0, 30.0, 40.0, hp = 200.0, rot = true),
    @[pudge(4, 1, 33.0, 40.0)]), memory)
  doAssert flag(action{"rot_toggle"}), "rot left on below the retreat line"
  doAssert not action.hasKey("attack_target"), "brawled below the retreat line"
  echo "ok rot off below the retreat line"
