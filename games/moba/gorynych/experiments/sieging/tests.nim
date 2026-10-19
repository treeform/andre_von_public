## Isolation tests for chebyshev-7 siege standoff.
## Crafted observations only; no sim scores.

import std/[json, strutils]

include candidate

const
  RadiantTeam = 0
  TankType = tankHero
  AssassinType = assassinHero
  FullHealth = 10
  RetreatHealth = 3
  TrialPrefix = "MOBA_TRIAL "
  HeroY = 21
  HeroX = 102
  TowerY = 28
  TowerX = 103

proc makeObs(y, x, team, heroType, health10: int): string =
  ## 510-byte observation with self scalars and an empty crop.
  result = newString(observationSize)
  result[selfOffset + 0] = chr(x)
  result[selfOffset + 1] = chr(y)
  result[selfOffset + 2] = chr(1)
  result[selfOffset + 3] = chr(health10)
  result[selfOffset + 4] = chr(10)
  result[selfOffset + 16] = chr(team)
  result[selfOffset + 17 + heroType] = chr(1)
  result[visionRange * cropWidth + visionRange] = chr(6 + heroType + 5 * team)

proc putTile(obs: var string, heroY, heroX, y, x, tileId: int) =
  ## Write a crop tile at a world cell. The cell must sit in vision.
  let
    dy = y - heroY
    dx = x - heroX
  doAssert abs(dy) <= visionRange and abs(dx) <= visionRange
  obs[(dy + visionRange) * cropWidth + (dx + visionRange)] = chr(tileId)

proc velOf(action: array[6, int]): (int, int) =
  ((action[0] - 3) div 3, (action[1] - 3) div 3)

proc v1HeroAction(policy: GorynychPolicy, index: int,
                  observation: string): array[6, int] =
  ## Frozen v1 siege: standoff chebyshev 6, any-creep engage, no extra hold.
  if observation.len != observationSize:
    return [3, 3, 0, 0, 0, 0]
  let view = parseView(observation)
  if index notin policy.heroes:
    policy.heroes[index] = newHeroState()
  let state = policy.heroes[index]
  policy.updateTowerMemory(view)
  let position = (view.y, view.x)
  if state.hasLastPos and
      max(abs(position[0] - state.lastPos[0]),
          abs(position[1] - state.lastPos[1])) > int(teleportDistance):
    state.waypointIndex = -1
    state.stuckTicks = 0
    state.detourLeft = 0
  if state.mode == PushMode and view.health10 <= retreatEnterHealth:
    state.mode = RetreatMode
  elif state.mode == RetreatMode and view.health10 >= retreatExitHealth:
    state.mode = PushMode
    state.waypointIndex = -1
  let (heroDistance, creepDistance, friendlyCreeps) = cropScan(view)
  var hold = false
  var goal: (int, int)
  if state.mode == RetreatMode:
    goal = spawns[view.team]
  else:
    goal = pushGoal(view, state)
    let (towerIdx, towerDistance) = policy.nearestLiveEnemyTower(view)
    if towerIdx >= 0 and towerDistance <= baselineStandoff:
      let ty = int(towers[towerIdx].y)
      let tx = int(towers[towerIdx].x)
      var engaged = false
      for (cy, cx) in friendlyCreeps:
        if max(abs(cy - ty), abs(cx - tx)) <= creepEngagedDistance:
          engaged = true
          break
      if engaged:
        goal = (ty, tx)
      elif towerDistance <= towerVision:
        goal = spawns[view.team]
      else:
        hold = true
  var (dy, dx) = if hold: (0, 0)
                 else: policy.nav.stepToward(view.y, view.x, goal)
  if state.triedMove and state.hasLastPos and state.lastPos == position and
      (dy != 0 or dx != 0):
    inc state.stuckTicks
  else:
    state.stuckTicks = 0
  if state.detourLeft > 0:
    dec state.detourLeft
    (dy, dx) = rotate90(dy, dx, state.detourSide)
  elif state.stuckTicks >= stuckTickLimit:
    state.detourLeft = detourTickCount
    state.detourSide = -state.detourSide
    state.stuckTicks = 0
    (dy, dx) = rotate90(dy, dx, state.detourSide)
  state.triedMove = dy != 0 or dx != 0
  state.lastPos = position
  state.hasLastPos = true
  let targetFilter = if creepDistance >= 0: 0 else: 2
  let (useQ, useW, useE) = skillFlags(view, state.mode,
                                      heroDistance, creepDistance)
  [3 + 3 * dy, 3 + 3 * dx, targetFilter, useQ, useW, useE]

echo "Testing cheb 7 of dire T4 is the live shooting tower"
block:
  let obs = makeObs(HeroY, HeroX, RadiantTeam, TankType, FullHealth)
  let view = parseView(obs)
  var policy = newGorynychPolicy()
  policy.updateTowerMemory(view)
  let (idx, dist) = policy.nearestLiveEnemyTower(view)
  doAssert idx >= 0
  doAssert dist == 7
  doAssert int(towers[idx].y) == TowerY
  doAssert int(towers[idx].x) == TowerX
  doAssert dist == siegeStandoff
  doAssert dist == baselineStandoff + 1

echo "Testing cheb 7 no-wave hold differs from v1 walk"
block:
  let obs = makeObs(HeroY, HeroX, RadiantTeam, TankType, FullHealth)
  let
    candidate = newGorynychPolicy()
    baseline = newGorynychPolicy()
    got = candidate.heroAction(0, obs)
    want = v1HeroAction(baseline, 0, obs)
  doAssert got == [3, 3, 2, 0, 0, 0], $got
  doAssert want != got
  let (bdy, bdx) = velOf(want)
  doAssert bdy != 0 or bdx != 0, "v1 must still walk at cheb 7"
  doAssert candidate.trial.triggers == 1
  doAssert candidate.trial.changedActions == 1
  doAssert candidate.trial.holdAtSeven == 1
  doAssert candidate.trial.heroCalls == 1
  doAssert want[2] == got[2] and want[3] == got[3] and
    want[4] == got[4] and want[5] == got[5]

echo "Testing cheb 6 no-wave both hold (v1 standoff unchanged)"
block:
  let
    y = TowerY - 6
    x = TowerX
  doAssert max(abs(y - TowerY), abs(x - TowerX)) == 6
  let obs = makeObs(y, x, RadiantTeam, TankType, FullHealth)
  let
    candidate = newGorynychPolicy()
    baseline = newGorynychPolicy()
    got = candidate.heroAction(0, obs)
    want = v1HeroAction(baseline, 0, obs)
  doAssert got == [3, 3, 2, 0, 0, 0], $got
  doAssert want == got
  doAssert candidate.trial.triggers == 0
  doAssert candidate.trial.changedActions == 0
  doAssert candidate.trial.holdAtSeven == 0

echo "Testing cheb 5 no-wave both leave vision"
block:
  let
    y = TowerY - 5
    x = TowerX
  doAssert max(abs(y - TowerY), abs(x - TowerX)) == 5
  var obs = makeObs(y, x, RadiantTeam, TankType, FullHealth)
  putTile(obs, y, x, TowerY, TowerX, towerTile)
  let
    candidate = newGorynychPolicy()
    baseline = newGorynychPolicy()
    got = candidate.heroAction(0, obs)
    want = v1HeroAction(baseline, 0, obs)
  doAssert got == want
  doAssert got != [3, 3, 2, 0, 0, 0]
  doAssert candidate.trial.triggers == 0
  doAssert candidate.trial.changedActions == 0

echo "Testing cheb 8 is outside both standoffs"
block:
  let
    y = TowerY - 8
    x = TowerX
  doAssert max(abs(y - TowerY), abs(x - TowerX)) == 8
  let obs = makeObs(y, x, RadiantTeam, TankType, FullHealth)
  let
    candidate = newGorynychPolicy()
    baseline = newGorynychPolicy()
    got = candidate.heroAction(0, obs)
    want = v1HeroAction(baseline, 0, obs)
  doAssert got == want
  doAssert candidate.trial.triggers == 0
  doAssert candidate.trial.changedActions == 0

echo "Testing retreat at cheb 7 ignores the new standoff"
block:
  let obs = makeObs(HeroY, HeroX, RadiantTeam, TankType, RetreatHealth)
  let
    candidate = newGorynychPolicy()
    baseline = newGorynychPolicy()
    got = candidate.heroAction(0, obs)
    want = v1HeroAction(baseline, 0, obs)
  doAssert got == want
  doAssert got != [3, 3, 2, 0, 0, 0]
  doAssert candidate.trial.triggers == 0
  doAssert candidate.trial.changedActions == 0
  doAssert candidate.trial.holdAtSeven == 0

echo "Testing cheb 7 with visible soak creep dives, not hold"
block:
  var obs = makeObs(HeroY, HeroX, RadiantTeam, TankType, FullHealth)
  let
    creepY = HeroY + 3
    creepX = TowerX
  doAssert max(abs(creepY - TowerY), abs(creepX - TowerX)) <=
    creepEngagedDistance
  putTile(obs, HeroY, HeroX, creepY, creepX, radiantCreepTile)
  let
    candidate = newGorynychPolicy()
    baseline = newGorynychPolicy()
    got = candidate.heroAction(0, obs)
    want = v1HeroAction(baseline, 0, obs)
  doAssert got != [3, 3, 2, 0, 0, 0]
  doAssert candidate.trial.triggers == 1
  doAssert candidate.trial.holdAtSeven == 0
  doAssert got[2] == want[2]
  if got != want:
    doAssert candidate.trial.changedActions == 1
  else:
    doAssert candidate.trial.changedActions == 0

echo "Testing assassin skills unchanged when standoff hold changes movement"
block:
  var obs = makeObs(HeroY, HeroX, RadiantTeam, AssassinType, FullHealth)
  putTile(obs, HeroY, HeroX, HeroY, HeroX - 1, 11)
  let
    candidate = newGorynychPolicy()
    baseline = newGorynychPolicy()
    got = candidate.heroAction(0, obs)
    want = v1HeroAction(baseline, 0, obs)
  doAssert got != want
  doAssert got[2] == want[2]
  doAssert got[3] == want[3] and got[4] == want[4] and got[5] == want[5]
  doAssert got[0] == 3 and got[1] == 3
  doAssert candidate.trial.holdAtSeven == 1

echo "Testing two policies on one obs return the same action"
block:
  let obs = makeObs(HeroY, HeroX, RadiantTeam, TankType, FullHealth)
  let
    a = newGorynychPolicy()
    b = newGorynychPolicy()
  doAssert a.heroAction(0, obs) == b.heroAction(0, obs)

echo "Testing trial JSON shape"
block:
  let obs = makeObs(HeroY, HeroX, RadiantTeam, TankType, FullHealth)
  let policy = newGorynychPolicy()
  discard policy.heroAction(0, obs)
  let line = policy.trialLine("first")
  doAssert line.startsWith(TrialPrefix)
  let payload = parseJson(line[TrialPrefix.len .. ^1])
  doAssert payload["idea"].getStr() == "sieging"
  doAssert payload["event"].getStr() == "first"
  doAssert payload["heroCalls"].getInt() == 1
  doAssert payload["triggers"].getInt() == 1
  doAssert payload["changedActions"].getInt() == 1
  doAssert payload["holdAtSeven"].getInt() == 1

echo "All sieging tests passed"
