## Isolation test for 0.3.2 rune hooks: idle at the post with a rune
## drifting in the river within reach, the throw goes to the rune instead
## of a blind fog poke; a visible enemy still outranks the rune; a rune
## behind the fountain rocks is skipped. Run from this directory:
##   nim r --hints:off -d:myasnikTest test_rune.nim

include myasnik

const
  riverWest = 53.0
  riverEast = 75.0

proc pudge(slot, team: int, x, y: float, hooked = false): JsonNode =
  %*{
    "id": 100 + slot, "slot": slot, "team": team, "x": x, "y": y,
    "hp": 840.0, "max_hp": 840.0, "alive": true, "hooked": hooked,
    "shield": false, "hook_ready": true, "blink_ready": false,
    "in_river": false, "layer": (if x < riverWest: 0 else: 1)
  }

proc observation(me: JsonNode, others: seq[JsonNode], runes: JsonNode): JsonNode =
  var pudges = %*[]
  pudges.add me
  for other in others:
    pudges.add other
  %*{
    "type": "observation", "tick": 100.0, "slot": me{"slot"}.getInt,
    "width": 128, "height": 128, "river_west": riverWest, "river_east": riverEast,
    "self": me, "visible": {"pudges": pudges, "hooks": [], "runes": runes},
    "ally_ping": newJNull()
  }

block:
  let action = decide(observation(pudge(0, 0, 41.0, 40.0), @[],
    %*[{"x": 60.0, "y": 44.0, "kind": 0}]), Memory())
  let aim = action{"hook_to"}
  doAssert not aim.isNil, "idle post did not throw"
  doAssert abs(aim[0].getFloat - 60.0) < 0.5 and abs(aim[1].getFloat - 44.0) < 0.5,
    "throw did not go to the rune: " & $aim
  echo "ok idle post hooks the drifting rune"

block:
  let action = decide(observation(pudge(0, 0, 41.0, 40.0),
    @[pudge(3, 1, 70.0, 40.0, hooked = true)],
    %*[{"x": 60.0, "y": 44.0, "kind": 0}]), Memory())
  let aim = action{"hook_to"}
  doAssert not aim.isNil and abs(aim[0].getFloat - 70.0) < 1.0,
    "rune outranked a held enemy: " & $aim
  echo "ok held enemy still outranks the rune"

block:
  ## Rune sitting behind the fountain rocks on our line: skipped, blind
  ## fallback fires instead (aim differs from the rune).
  let action = decide(observation(pudge(0, 0, 41.0, 64.0), @[],
    %*[{"x": 70.0, "y": 64.0, "kind": 1}]), Memory())
  let aim = action{"hook_to"}
  doAssert not aim.isNil, "no throw at all"
  doAssert not (abs(aim[0].getFloat - 70.0) < 0.5 and abs(aim[1].getFloat - 64.0) < 0.5),
    "threw through the fountain at the rune"
  echo "ok island-blocked rune is skipped"
