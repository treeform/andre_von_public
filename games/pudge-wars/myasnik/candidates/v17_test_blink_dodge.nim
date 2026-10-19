## Isolation test for the 0.3.2 blink dodge: an enemy hook grazing us
## with a ready blink draws a blink_to along our own bank (never into
## the river); with the blink cooling the v3 walked sidestep remains.
## Run from this directory: nim r --hints:off -d:myasnikTest test_blink_dodge.nim

include myasnik

const
  riverWest = 53.0
  riverEast = 75.0

proc pudge(slot, team: int, x, y: float, blinkReady = false): JsonNode =
  %*{
    "id": 100 + slot, "slot": slot, "team": team, "x": x, "y": y,
    "hp": 840.0, "max_hp": 840.0, "alive": true, "hooked": false,
    "shield": false, "hook_ready": false, "blink_ready": blinkReady,
    "in_river": false, "layer": (if x < riverWest: 0 else: 1)
  }

proc observation(me: JsonNode, hooks: JsonNode): JsonNode =
  %*{
    "type": "observation", "tick": 100.0, "slot": me{"slot"}.getInt,
    "width": 128, "height": 128, "river_west": riverWest, "river_east": riverEast,
    "self": me, "visible": {"pudges": [me], "hooks": hooks, "runes": []},
    "ally_ping": newJNull()
  }

let graze = %*[{"owner": 4, "team": 1, "victim": 0, "x": 47.0, "y": 64.0, "flying": true}]

block:
  let action = decide(observation(pudge(1, 0, 41.0, 64.0, blinkReady = true), graze), Memory())
  let hop = action{"blink_to"}
  doAssert not hop.isNil, "grazing hook drew no blink dodge"
  doAssert hop[0].getFloat < riverWest - 2.0, "dodge hop toward the river: " & $hop
  doAssert abs(hop[1].getFloat - 64.0) >= 15.0, "dodge hop not perpendicular: " & $hop
  echo "ok grazing hook draws a bank-side blink dodge"

block:
  let action = decide(observation(pudge(1, 0, 41.0, 64.0), graze), Memory())
  doAssert action{"blink_to"}.isNil, "blinked with the blink cooling"
  doAssert not action{"walk_to"}.isNil, "no walked sidestep while cooling"
  echo "ok cooling blink keeps the walked sidestep"

block:
  let action = decide(observation(pudge(4, 1, 87.0, 64.0, blinkReady = true),
    %*[{"owner": 1, "team": 0, "victim": 0, "x": 81.0, "y": 64.0, "flying": true}]), Memory())
  let hop = action{"blink_to"}
  doAssert not hop.isNil and hop[0].getFloat > riverEast + 2.0, "east dodge wrong: " & $hop
  echo "ok east-team mirror"
