include candidate

const
  DireBotTowerIndex = 21
  RadiantTeam = 0
  CarryType = 4
  FullHealth = 10
  RetreatHealth = 3
  TrialPrefix = "MOBA_TRIAL "

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

proc putTile(obs: var string, heroY, heroX, y, x, tileId: int) =
  ## Write a crop tile at a world cell. The cell must sit in vision.
  let
    dy = y - heroY
    dx = x - heroX
  doAssert abs(dy) <= visionRange and abs(dx) <= visionRange
  obs[(dy + visionRange) * cropWidth + (dx + visionRange)] = chr(tileId)

proc baselineHeroAction(policy: GorynychPolicy, index: int,
                        observation: string): array[6, int] =
  ## Pre-change siege: any chebyshev-5 creep is engaged; no wave-surf.
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
    if towerIdx >= 0 and towerDistance <= siegeStandoff:
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

proc parseTrial(line: string): JsonNode =
  ## JSON object after the MOBA_TRIAL prefix.
  doAssert line.len > TrialPrefix.len
  doAssert line[0 ..< TrialPrefix.len] == TrialPrefix
  parseJson(line[TrialPrefix.len .. ^1])

proc sameAction(a, b: array[6, int]): bool =
  ## Component-wise equality for a 6-int action row.
  a == b

echo "Testing observation no-op on malformed input"
block:
  let policy = newGorynychPolicy()
  let action = policy.heroAction(0, "short")
  doAssert action == [3, 3, 0, 0, 0, 0]
  doAssert policy.trial.heroCalls == 1
  doAssert policy.trial.triggers == 0
  doAssert policy.trial.changedActions == 0

let
  towerY = int(towers[DireBotTowerIndex].y)
  towerX = int(towers[DireBotTowerIndex].x)
doAssert towerY == 78 and towerX == 113

echo "Testing no-creep standoff matches baseline hold"
block:
  let
    heroY = towerY + 6
    heroX = towerX
  var obs = makeObs(heroY, heroX, RadiantTeam, CarryType, FullHealth)
  let
    candidate = newGorynychPolicy()
    baseline = newGorynychPolicy()
    got = candidate.heroAction(0, obs)
    want = baselineHeroAction(baseline, 0, obs)
  doAssert sameAction(got, want)
  doAssert got == [3, 3, 2, 0, 0, 0]
  doAssert candidate.trial.triggers == 0
  doAssert candidate.trial.changedActions == 0
  doAssert not candidate.trial.sawFirstTrigger

echo "Testing creep in tower chebyshev but not closer L1 holds at standoff"
block:
  let
    heroY = towerY + 6
    heroX = towerX
    creepY = towerY + 1
    creepX = towerX + 5
  doAssert l1(heroY, heroX, towerY, towerX) == 6
  doAssert max(abs(creepY - towerY), abs(creepX - towerX)) == 5
  doAssert l1(creepY, creepX, towerY, towerX) == 6
  var obs = makeObs(heroY, heroX, RadiantTeam, CarryType, FullHealth)
  putTile(obs, heroY, heroX, creepY, creepX, radiantCreepTile)
  let
    candidate = newGorynychPolicy()
    baseline = newGorynychPolicy()
    got = candidate.heroAction(0, obs)
    want = baselineHeroAction(baseline, 0, obs)
  doAssert got == [3, 3, 2, 0, 0, 0], $got
  doAssert not sameAction(got, want)
  doAssert want != [3, 3, 2, 0, 0, 0]
  doAssert candidate.trial.triggers == 1
  doAssert candidate.trial.changedActions == 1
  doAssert candidate.trial.sawFirstTrigger
  let payload = parseTrial(trialLine(candidate, "first"))
  doAssert payload["idea"].getStr() == trialIdea
  doAssert payload["heroCalls"].getInt() == 1
  doAssert payload["triggers"].getInt() == 1
  doAssert payload["changedActions"].getInt() == 1

echo "Testing equal L1 inside vision retreats instead of diving"
block:
  let
    heroY = towerY + 5
    heroX = towerX
    creepY = towerY
    creepX = towerX + 5
  doAssert l1(heroY, heroX, towerY, towerX) == 5
  doAssert l1(creepY, creepX, towerY, towerX) == 5
  var obs = makeObs(heroY, heroX, RadiantTeam, CarryType, FullHealth)
  putTile(obs, heroY, heroX, towerY, towerX, towerTile)
  putTile(obs, heroY, heroX, creepY, creepX, radiantCreepTile)
  let
    candidate = newGorynychPolicy()
    baseline = newGorynychPolicy()
    got = candidate.heroAction(0, obs)
    want = baselineHeroAction(baseline, 0, obs)
  doAssert not sameAction(got, want)
  doAssert got != [3, 3, 2, 0, 0, 0]
  doAssert want != [3, 3, 2, 0, 0, 0]
  doAssert got[2] == want[2] and got[3] == want[3]
  doAssert got[4] == want[4] and got[5] == want[5]
  doAssert candidate.trial.triggers == 1
  doAssert candidate.trial.changedActions == 1

echo "Testing strictly closer creep at standoff dives with baseline"
block:
  let
    heroY = towerY + 6
    heroX = towerX
    creepY = towerY + 2
    creepX = towerX
  doAssert l1(creepY, creepX, towerY, towerX) == 2
  doAssert 2 < l1(heroY, heroX, towerY, towerX)
  var obs = makeObs(heroY, heroX, RadiantTeam, CarryType, FullHealth)
  putTile(obs, heroY, heroX, creepY, creepX, radiantCreepTile)
  let
    candidate = newGorynychPolicy()
    baseline = newGorynychPolicy()
    got = candidate.heroAction(0, obs)
    want = baselineHeroAction(baseline, 0, obs)
  doAssert sameAction(got, want)
  doAssert got != [3, 3, 2, 0, 0, 0]
  doAssert candidate.trial.triggers == 1
  doAssert candidate.trial.changedActions == 0
  doAssert candidate.trial.sawFirstTrigger

echo "Testing wave-surf blocks a step that would overtake the soak"
block:
  let
    heroY = towerY + 3
    heroX = towerX
    creepY = towerY + 2
    creepX = towerX
  doAssert l1(heroY, heroX, towerY, towerX) == 3
  doAssert l1(creepY, creepX, towerY, towerX) == 2
  var obs = makeObs(heroY, heroX, RadiantTeam, CarryType, FullHealth)
  putTile(obs, heroY, heroX, towerY, towerX, towerTile)
  putTile(obs, heroY, heroX, creepY, creepX, radiantCreepTile)
  let
    candidate = newGorynychPolicy()
    baseline = newGorynychPolicy()
    got = candidate.heroAction(0, obs)
    want = baselineHeroAction(baseline, 0, obs)
  doAssert got == [3, 3, 2, 0, 0, 0], $got
  doAssert not sameAction(got, want)
  doAssert want[0] == 0 and want[1] == 3, $want
  doAssert candidate.trial.triggers == 1
  doAssert candidate.trial.changedActions == 1

echo "Testing retreat mode ignores siege cover"
block:
  let
    heroY = towerY + 3
    heroX = towerX
    creepY = towerY + 2
    creepX = towerX
  var obs = makeObs(heroY, heroX, RadiantTeam, CarryType, RetreatHealth)
  putTile(obs, heroY, heroX, towerY, towerX, towerTile)
  putTile(obs, heroY, heroX, creepY, creepX, radiantCreepTile)
  let
    candidate = newGorynychPolicy()
    baseline = newGorynychPolicy()
    got = candidate.heroAction(0, obs)
    want = baselineHeroAction(baseline, 0, obs)
  doAssert sameAction(got, want)
  doAssert got != [3, 3, 2, 0, 0, 0]
  doAssert candidate.trial.triggers == 0
  doAssert candidate.trial.changedActions == 0

echo "Testing assassin skills unchanged when soak changes movement"
block:
  let
    heroY = towerY + 6
    heroX = towerX
    creepY = towerY + 1
    creepX = towerX + 5
    enemyY = heroY
    enemyX = heroX - 1
  var obs = makeObs(heroY, heroX, RadiantTeam, assassinHero, FullHealth)
  putTile(obs, heroY, heroX, creepY, creepX, radiantCreepTile)
  putTile(obs, heroY, heroX, enemyY, enemyX, 11)
  let
    candidate = newGorynychPolicy()
    baseline = newGorynychPolicy()
    got = candidate.heroAction(0, obs)
    want = baselineHeroAction(baseline, 0, obs)
  doAssert not sameAction(got, want)
  doAssert got[2] == want[2]
  doAssert got[3] == want[3] and got[4] == want[4] and got[5] == want[5]
  doAssert got[3] == 0 and got[4] == 1 and got[5] == 0

echo "Testing telemetry does not alter the returned action"
block:
  let
    heroY = towerY + 3
    heroX = towerX
    creepY = towerY + 2
    creepX = towerX
  var obs = makeObs(heroY, heroX, RadiantTeam, CarryType, FullHealth)
  putTile(obs, heroY, heroX, towerY, towerX, towerTile)
  putTile(obs, heroY, heroX, creepY, creepX, radiantCreepTile)
  let
    a = newGorynychPolicy()
    b = newGorynychPolicy()
    first = a.heroAction(0, obs)
    second = b.heroAction(0, obs)
  doAssert sameAction(first, second)
  doAssert a.trial.heroCalls == b.trial.heroCalls
  doAssert a.trial.triggers == b.trial.triggers
  doAssert a.trial.changedActions == b.trial.changedActions

echo "Testing first trigger and every 1000 hero calls emit counters"
block:
  let policy = newGorynychPolicy()
  for i in 1 .. 999:
    discard policy.heroAction(0, "x")
  doAssert policy.trial.heroCalls == 999
  doAssert policy.trial.triggers == 0
  discard policy.heroAction(0, "x")
  doAssert policy.trial.heroCalls == 1000
  let tick = parseTrial(trialLine(policy, "tick"))
  doAssert tick["idea"].getStr() == trialIdea
  doAssert tick["event"].getStr() == "tick"
  doAssert tick["heroCalls"].getInt() == 1000
  doAssert tick["triggers"].getInt() == 0
  doAssert tick["changedActions"].getInt() == 0
  let done = parseTrial(trialLine(policy, "done"))
  doAssert done["event"].getStr() == "done"
  doAssert done["heroCalls"].getInt() == 1000

echo "Testing done summary includes required keys"
block:
  let policy = newGorynychPolicy()
  let node = parseTrial(trialLine(policy, "done"))
  doAssert node.hasKey("idea")
  doAssert node.hasKey("heroCalls")
  doAssert node.hasKey("triggers")
  doAssert node.hasKey("changedActions")
  doAssert node["changedActions"].getInt() == 0

echo "All soak tests passed"
