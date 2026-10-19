## Experiment 11 isolation test: the ally-free corridor gate. A hooked
## enemy straight across the river draws the headshot throw when the
## lane is clear, and is refused when a living teammate stands on the
## flight line. Run from this directory:
##   nim r --hints:off -d:myasnikTest test_corridor.nim

include myasnik

proc pudge(slot, team: int, x, y: float, hooked = false): JsonNode =
  %*{
    "slot": slot, "team": team, "x": x, "y": y,
    "hp": 840.0, "max_hp": 840.0, "alive": true, "hooked": hooked,
    "shield": false, "hook_ready": true, "in_river": false
  }

proc observation(me: JsonNode, others: seq[JsonNode]): JsonNode =
  var pudges = %*[]
  pudges.add me
  for other in others:
    pudges.add other
  %*{
    "type": "observation", "tick": 100.0, "slot": me{"slot"}.getInt,
    "width": 128, "height": 128, "river_west": 53.0, "river_east": 75.0,
    "self": me, "visible": {"pudges": pudges, "hooks": %[]},
    "ally_ping": newJNull()
  }

block:
  let clear = decide(observation(pudge(0, 0, 41.0, 64.0),
    @[pudge(3, 1, 70.0, 64.0, hooked = true)]), Memory())
  doAssert not clear{"hook_to"}.isNil, "clear lane did not draw the throw"
  let blocked = decide(observation(pudge(0, 0, 41.0, 64.0),
    @[pudge(1, 0, 50.0, 65.0), pudge(3, 1, 70.0, 64.0, hooked = true)]), Memory())
  let aim = blocked{"hook_to"}
  doAssert aim.isNil or abs(aim[1].getFloat - 64.0) > 3.0,
    "throw went through the teammate on the flight line"
  echo "ok corridor gate refuses throws through a teammate"
