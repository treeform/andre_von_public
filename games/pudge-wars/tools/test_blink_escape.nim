## Isolation test for the 0.3.2 river escape: a butcher dumped in the
## river with a ready blink hops straight home; without one it keeps the
## v3 river stance (home waterline, ping). Run from this directory:
##   nim r --hints:off -d:myasnikTest test_blink_escape.nim

include ../myasnik/myasnik

const
  riverWest = 53.0
  riverEast = 75.0

proc pudge(slot, team: int, x, y: float, inRiver = false,
    blinkReady = false): JsonNode =
  %*{
    "id": 100 + slot, "slot": slot, "team": team, "x": x, "y": y,
    "hp": 840.0, "max_hp": 840.0, "alive": true, "hooked": false,
    "shield": false, "hook_ready": true, "blink_ready": blinkReady,
    "in_river": inRiver, "layer": (if inRiver: 2 elif x < riverWest: 0 else: 1)
  }

proc observation(me: JsonNode): JsonNode =
  %*{
    "type": "observation", "tick": 100.0, "slot": me{"slot"}.getInt,
    "width": 128, "height": 128, "river_west": riverWest, "river_east": riverEast,
    "self": me, "visible": {"pudges": [me], "hooks": [], "runes": []},
    "ally_ping": newJNull()
  }

block:
  let west = decide(observation(pudge(1, 0, 60.0, 64.0, inRiver = true,
    blinkReady = true)), Memory())
  let hop = west{"blink_to"}
  doAssert not hop.isNil, "west river stance did not blink"
  doAssert hop[0].getFloat < riverWest, "west escape not aimed home: " & $hop
  let east = decide(observation(pudge(4, 1, 68.0, 40.0, inRiver = true,
    blinkReady = true)), Memory())
  doAssert not east{"blink_to"}.isNil and east{"blink_to"}[0].getFloat > riverEast,
    "east escape wrong: " & $east{"blink_to"}
  echo "ok river escape blinks home on both banks"

block:
  let action = decide(observation(pudge(1, 0, 60.0, 64.0, inRiver = true)), Memory())
  doAssert action{"blink_to"}.isNil, "blinked with the blink cooling"
  let walk = action{"walk_to"}
  doAssert not walk.isNil and walk[0].getFloat >= riverWest and
    walk[0].getFloat <= riverWest + 2.0, "cooling blink lost the river stance"
  echo "ok cooling blink keeps the waterline stance"

block:
  ## Layer 2 alone (no in_river flag) still counts as the river.
  var me = pudge(2, 0, 60.0, 64.0, blinkReady = true)
  me["layer"] = %2
  let action = decide(observation(me), Memory())
  doAssert not action{"blink_to"}.isNil, "layer 2 was not treated as river"
  echo "ok layer 2 counts as the river"
