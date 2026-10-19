## Offline harness for the camper-clone variant of myasnik (experiment 7).
## The clone deliberately drops v3's brawl/shield/dodge behaviors, so the
## v3 harness does not apply; this one asserts the clone's own contract:
## a bank-standing butcher never walks into the river, it hooks a chained
## enemy, it fog-pokes when idle at its post, and a river-stranded butcher
## orders a walk home. Run:
##   nim r --hints:off -d:myasnikTest games/pudge-wars/tools/test_camper_clone.nim

include ../myasnik/myasnik

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

## 1. Bank stances never walk into the river, either side, any lane.
block:
  for team in 0 .. 1:
    for xStep in 0 .. 36:
      for yStep in 0 .. 10:
        let
          slot = if team == 0: 1 else: 4
          x = if team == 0: 15.0 + xStep.float else: 113.0 - xStep.float
          y = 20.0 + yStep.float * 9.0
          memory = Memory()
          enemyX = if team == 0: 100.0 else: 28.0
          action = decide(observation(pudge(slot, team, x, y),
            @[pudge(slot + (if team == 0: 3 else: -3), 1 - team, enemyX, 64.0)]), memory)
          (hasWalk, wx, _) = walkTarget(action)
        doAssert hasWalk, "clone issued no walk order"
        doAssert not inDrown(wx), "clone walk leaked into river"
  pass "bank stances never target the river"

## 2. A chained enemy is hooked (headshot priority).
block:
  let memory = Memory()
  let action = decide(observation(pudge(0, 0, 45.0, 64.0),
    @[pudge(3, 1, 70.0, 64.0, hooked = true)]), memory)
  let aim = action{"hook_to"}
  doAssert not aim.isNil, "clone did not throw at a hooked enemy"
  doAssert abs(aim[0].getFloat - 70.0) < 1.0, "hooked-enemy aim off target"
  pass "hooked enemy is thrown at"

## 3. Idle at post with no visible enemy: fog poke past the enemy edge.
block:
  let memory = Memory()
  let action = decide(observation(pudge(0, 0, 49.0, 64.0), tick = 50.0), memory)
  let aim = action{"hook_to"}
  doAssert not aim.isNil, "no fog poke when idle"
  doAssert aim[0].getFloat > riverEast, "fog poke aimed short of the enemy bank"
  pass "idle post fog-pokes the enemy bank"

## 4. Stranded in the river: the walk order heads home, never deeper.
block:
  let memory = Memory()
  let action = decide(observation(pudge(0, 0, 60.0, 64.0, inRiver = true)), memory)
  let (hasWalk, wx, _) = walkTarget(action)
  doAssert hasWalk, "no walk order while in river"
  doAssert wx < riverWest, "river walk did not head home"
  pass "river stance walks home"

echo checks, " checks passed"
