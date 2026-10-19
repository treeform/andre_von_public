## Offline harness for the myasnik 0.3.1 rewrite. No sim, no sockets:
## synthetic observations through `decide`, asserting the no-die
## geometry (a bank-standing butcher never orders a walk into the
## river's drown columns) and the throw priorities the strategy leans
## on. Run: nim r --hints:off -d:myasnikTest games/pudge-wars/tools/test_myasnik.nim

include myasnik

const
  riverWest = 53.0
  riverEast = 75.0

proc pudge(slot, team: int, x, y: float, hp = 840.0, alive = true,
    hooked = false, shield = false, hookReady = true,
    inRiver = false): JsonNode =
  %*{
    "slot": slot, "team": team, "x": x, "y": y,
    "hp": hp, "max_hp": 840.0, "alive": alive, "hooked": hooked,
    "shield": shield, "hook_ready": hookReady, "in_river": inRiver
  }

proc observation(me: JsonNode, others: seq[JsonNode] = @[],
    hooks: seq[JsonNode] = @[], tick = 100.0): JsonNode =
  var pudges = %*[]
  pudges.add me
  for other in others:
    pudges.add other
  %*{
    "type": "observation", "tick": tick, "slot": me{"slot"}.getInt,
    "width": 128, "height": 128,
    "river_west": riverWest, "river_east": riverEast,
    "self": me,
    "visible": {"pudges": pudges, "hooks": %hooks},
    "ally_ping": newJNull()
  }

proc walkTarget(action: JsonNode): (bool, float, float) =
  let walk = action{"walk_to"}
  if walk.isNil or walk.kind != JArray or walk.len < 2:
    return (false, 0.0, 0.0)
  (true, walk[0].getFloat, walk[1].getFloat)

proc inDrown(x: float): bool =
  x >= riverWest and x <= riverEast

var checks = 0

proc pass(name: string) =
  inc checks
  echo "ok ", name

## 1. No-die geometry: sweep bank stances, threat dodges, and brawl
## chases — a west or east butcher must never target a river column.
block:
  for team in 0 .. 1:
    for xStep in 0 .. 40:
      for yStep in 0 .. 10:
        let
          slot = if team == 0: 0 else: 3
          x = if team == 0: 15.0 + xStep.float else: 113.0 - xStep.float
          y = 17.0 + yStep.float * 9.0
          memory = Memory()
        ## Plain hold.
        var action = decide(observation(pudge(slot, team, x, y)), memory)
        var (hasWalk, wx, _) = walkTarget(action)
        doAssert not (hasWalk and inDrown(wx)), "hold leaked into river"
        ## Enemy hook screaming in from across the river.
        let hx = if team == 0: 70.0 else: 58.0
        var hook = %*{"owner": if team == 0: 3 else: 0,
          "team": 1 - team, "x": hx, "y": y}
        var threatMemory = Memory()
        discard decide(observation(
          pudge(slot, team, x, y), hooks = @[hook], tick = 100.0),
          threatMemory)
        hook = %*{"owner": if team == 0: 3 else: 0, "team": 1 - team,
          "x": if team == 0: hx - 1.2 else: hx + 1.2, "y": y}
        action = decide(observation(
          pudge(slot, team, x, y), hooks = @[hook], tick = 101.0),
          threatMemory)
        (hasWalk, wx, _) = walkTarget(action)
        doAssert not (hasWalk and inDrown(wx)), "dodge leaked into river"
        ## Chasing a caught enemy who sits in the drink.
        var chaseMemory = Memory()
        action = decide(observation(
          pudge(slot, team, x, y),
          others = @[pudge(if team == 0: 4 else: 1, 1 - team, 64.0, y,
            hooked = true, inRiver = true)]), chaseMemory)
        (hasWalk, wx, _) = walkTarget(action)
        doAssert not (hasWalk and inDrown(wx)), "chase leaked into river"
  pass "bank walk targets never enter drown columns"

## 2. Headshot priority: a visible hooked enemy is the throw.
block:
  let memory = Memory()
  let action = decide(observation(
    pudge(0, 0, 41.0, 64.0),
    others = @[
      pudge(3, 1, 60.0, 64.0, hooked = true, inRiver = true),
      pudge(4, 1, 79.0, 40.0)
    ]), memory)
  let aim = action{"hook_to"}
  doAssert not aim.isNil, "no throw at a hooked enemy"
  doAssert abs(aim[0].getFloat - 60.0) < 6.0 and
    abs(aim[1].getFloat - 64.0) < 6.0, "headshot aim off target"
  pass "hooked enemy draws the headshot throw"

## 3. Rescue: a drowning ally gets pulled, not a distant enemy poked.
block:
  let memory = Memory()
  let action = decide(observation(
    pudge(0, 0, 41.0, 40.0),
    others = @[
      pudge(1, 0, 60.0, 40.0, hp = 300.0, inRiver = true),
      pudge(4, 1, 80.0, 88.0)
    ]), memory)
  let aim = action{"hook_to"}
  doAssert not aim.isNil, "no rescue throw"
  doAssert abs(aim[0].getFloat - 60.0) < 6.0, "rescue aim off the ally"
  pass "drowning ally gets the rescue hook"

## 4. Point-blank intercept: an inbound chain nearby is shot head-on.
block:
  let memory = Memory()
  discard decide(observation(
    pudge(0, 0, 41.0, 64.0),
    hooks = @[%*{"owner": 3, "team": 1, "x": 53.0, "y": 64.0}],
    tick = 100.0), memory)
  let action = decide(observation(
    pudge(0, 0, 41.0, 64.0),
    hooks = @[%*{"owner": 3, "team": 1, "x": 51.8, "y": 64.0}],
    tick = 101.0), memory)
  let aim = action{"hook_to"}
  doAssert not aim.isNil, "no intercept throw"
  doAssert abs(aim[0].getFloat - 51.8) < 1.0, "intercept aim off the head"
  pass "point-blank chain is intercepted"

## 5. Spawn shield is idled out: no order while shielded and safe.
block:
  let memory = Memory()
  let action = decide(observation(
    pudge(0, 0, 22.0, 40.0, shield = true)), memory)
  doAssert action.len == 0, "shielded idle still issued an order"
  pass "respawn shield is kept by idling"

## 6. Brawl: stranded enemy in melee reach gets one halt, then silence.
block:
  let memory = Memory()
  let stranded = pudge(4, 1, 43.0, 64.0, hp = 200.0)
  var action = decide(observation(
    pudge(0, 0, 41.0, 64.0), others = @[stranded]), memory)
  doAssert flag(action{"halt"}), "no halt to arm auto-melee"
  action = decide(observation(
    pudge(0, 0, 41.0, 64.0), others = @[stranded], tick = 101.0), memory)
  doAssert not action.hasKey("halt") and not action.hasKey("walk_to"),
    "brawl silence broken"
  pass "stranded enemy is brawled via halt-then-silence"

## 7. In the river ourselves: walk targets stay inside the river band
## (the sim cannot climb banks) and hug the home edge.
block:
  let memory = Memory()
  let action = decide(observation(
    pudge(0, 0, 64.0, 64.0, inRiver = true)), memory)
  let (hasWalk, wx, _) = walkTarget(action)
  doAssert hasWalk, "no river walk order"
  doAssert wx >= riverWest and wx <= riverWest + 2.0,
    "river walk not hugging home edge"
  pass "river stance hugs the home waterline for rescue"

## 8. Hold the hook: idle at the post with nothing visible, no throw.
block:
  let memory = Memory()
  let action = decide(observation(pudge(0, 0, 41.0, 40.0)), memory)
  doAssert action{"hook_to"}.isNil, "idle post still blind-threw"
  pass "idle post holds the hook"

echo checks, " checks passed"
