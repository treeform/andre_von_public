## Experiment 12 isolation test: reel-aware headshot aim. A held enemy
## whose holding hook is visible and reeling toward its owner must draw
## a throw aimed ahead of the body along the chain (toward the owner),
## not at the lagging body track; with no visible hook the plain lead
## still fires. Run from this directory:
##   nim r --hints:off -d:myasnikTest test_reel_aim.nim

include ../myasnik/myasnik

proc pudge(slot, team: int, x, y: float, hooked = false): JsonNode =
  %*{
    "slot": slot, "team": team, "x": x, "y": y,
    "hp": 840.0, "max_hp": 840.0, "alive": true, "hooked": hooked,
    "shield": false, "hook_ready": true, "in_river": false
  }

proc observation(me: JsonNode, others: seq[JsonNode], hooks: JsonNode,
    tick: float): JsonNode =
  var pudges = %*[]
  pudges.add me
  for other in others:
    pudges.add other
  %*{
    "type": "observation", "tick": tick, "slot": me{"slot"}.getInt,
    "width": 128, "height": 128, "river_west": 53.0, "river_east": 75.0,
    "self": me, "visible": {"pudges": pudges, "hooks": hooks},
    "ally_ping": newJNull()
  }

block:
  ## Enemy slot 3 (east team) is held by our ally slot 1 standing at
  ## x=45; the hook head (owner slot 1, victim slot 3) reels from x=66
  ## toward x=45 at 1.5 tiles/tick. Two ticks so the hook velocity is
  ## tracked, then the throw.
  let memory = Memory()
  let allyHolder = pudge(1, 0, 45.0, 40.0)
  let victim = pudge(3, 1, 66.0, 40.0, hooked = true)
  discard decide(observation(pudge(0, 0, 41.0, 40.0), @[allyHolder, victim],
    %*[{"owner": 1, "team": 0, "victim": 3, "x": 67.5, "y": 40.0}], 100.0), memory)
  let action = decide(observation(pudge(0, 0, 41.0, 40.0), @[allyHolder, victim],
    %*[{"owner": 1, "team": 0, "victim": 3, "x": 66.0, "y": 40.0}], 101.0), memory)
  let aim = action{"hook_to"}
  doAssert not aim.isNil, "held enemy drew no throw"
  doAssert aim[0].getFloat < 64.0, "aim not led along the chain toward the hooker: " & $aim
  echo "ok reel aim leads the held enemy along the chain"

block:
  let action = decide(observation(pudge(0, 0, 41.0, 40.0),
    @[pudge(3, 1, 66.0, 40.0, hooked = true)], %*[], 100.0), Memory())
  doAssert not action{"hook_to"}.isNil, "no visible hook: plain lead did not fire"
  echo "ok held enemy without a visible hook still draws the throw"
