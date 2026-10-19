## Isolation tests for local recovery retreat (recover-near-front).
## Crafted observations only; no sim scores.

import std/strutils

include candidate

proc makeObs(
    posX, posY, health10: int, team = 0, heroType = 1,
    crop: seq[(int, int, int)] = @[]
): string =
  ## Synthetic 510-byte obs: reliable crop tiles and self scalars.
  result = newString(observationSize)
  result[selfOffset + 0] = chr(posX)
  result[selfOffset + 1] = chr(posY)
  result[selfOffset + 2] = chr(1)
  result[selfOffset + 3] = chr(health10)
  result[selfOffset + 4] = chr(10)
  result[selfOffset + 5] = chr(1)
  result[selfOffset + 6] = chr(1)
  result[selfOffset + 7] = chr(1)
  result[selfOffset + 16] = chr(team)
  result[selfOffset + 17 + heroType] = chr(1)
  let selfTile = 6 + heroType + 5 * team
  result[visionRange * cropWidth + visionRange] = chr(selfTile)
  for (dy, dx, tile) in crop:
    result[(dy + visionRange) * cropWidth + (dx + visionRange)] =
      chr(tile)

proc vel(action: array[6, int]): (int, int) =
  ## Decode unit step (dy, dx) from velocity action slots.
  ((action[0] - 3) div 3, (action[1] - 3) div 3)

proc chebyshev(y1, x1, y2, x2: int): int =
  max(abs(y1 - y2), abs(x1 - x2))

echo "Testing walkable fixture cells"
block:
  let nav = initNavGrid()
  doAssert not nav.walls[90 * mapWidth + 40], "y=90 x=40 should be open"
  doAssert not nav.walls[62 * mapWidth + 69], "y=62 x=69 should be open"
  doAssert not nav.walls[99 * mapWidth + 26], "y=99 x=26 should be open"
  doAssert not nav.walls[113 * mapWidth + 12], "radiant fountain open"
  for (dy, dx) in steps:
    doAssert not nav.walls[(90 + dy) * mapWidth + (40 + dx)],
      "neighbor of y=90 x=40 should be open"

echo "Testing threat disengage increases distance vs fountain"
block:
  var policy = newGorynychPolicy()
  # Radiant assassin in our half; dire hero one cell SE.
  const
    posY = 90
    posX = 40
    edy = 1
    edx = 1
  let enemyTile = 11
  let obs = makeObs(posX, posY, 3, crop = @[(edy, edx, enemyTile)])
  let action = policy.heroAction(0, obs)
  let (ady, adx) = vel(action)
  let view = parseView(obs)
  doAssert view.health10 == 3
  doAssert policy.heroes[0].mode == RetreatMode
  doAssert ady != 0 or adx != 0, "must step away, not hold"
  let oldD = chebyshev(posY, posX, posY + edy, posX + edx)
  let newD = chebyshev(posY + ady, posX + adx, posY + edy, posX + edx)
  doAssert newD > oldD, "local retreat must increase threat distance"
  let (fdy, fdx) = policy.nav.stepToward(posY, posX, spawns[0])
  doAssert (ady, adx) != (fdy, fdx), "must not be the fountain step"
  doAssert policy.triggers == 1
  doAssert policy.stepTriggers == 1
  doAssert policy.holdTriggers == 0
  doAssert policy.changedActions == 1
  doAssert policy.changedIntents == 1
  doAssert policy.fountainFallbacks == 0
  # Assassin E haste still fires in RetreatMode (skills unchanged).
  doAssert action[5] == 1

echo "Testing tower threat disengage"
block:
  var policy = newGorynychPolicy()
  # Live dire T1 mid at (59, 69); stand at chebyshev 3 south of it.
  const
    posY = 62
    posX = 69
    towerY = 59
    towerX = 69
  doAssert chebyshev(posY, posX, towerY, towerX) == 3
  # Crop must show the tower or updateTowerMemory marks it dead.
  let obs = makeObs(posX, posY, 3,
                    crop = @[(towerY - posY, towerX - posX, towerTile)])
  let action = policy.heroAction(0, obs)
  let (ady, adx) = vel(action)
  doAssert policy.heroes[0].mode == RetreatMode
  doAssert ady != 0 or adx != 0, "must step away from the tower"
  let oldD = chebyshev(posY, posX, towerY, towerX)
  let newD = chebyshev(posY + ady, posX + adx, towerY, towerX)
  doAssert newD > oldD, "tower retreat must increase tower distance"
  doAssert policy.triggers == 1
  doAssert policy.stepTriggers == 1

echo "Testing safe-hold regenerates in place"
block:
  var policy = newGorynychPolicy()
  const
    posY = 90
    posX = 40
  let obs = makeObs(posX, posY, 3)
  let action = policy.heroAction(0, obs)
  let (ady, adx) = vel(action)
  doAssert policy.heroes[0].mode == RetreatMode
  doAssert (ady, adx) == (0, 0), "safe retreat holds to regen"
  let (fdy, fdx) = policy.nav.stepToward(posY, posX, spawns[0])
  doAssert (fdy, fdx) != (0, 0), "baseline would still walk to fountain"
  doAssert (ady, adx) != (fdy, fdx)
  doAssert policy.triggers == 1
  doAssert policy.holdTriggers == 1
  doAssert policy.stepTriggers == 0
  doAssert policy.changedActions == 1
  doAssert policy.changedIntents == 1
  doAssert action[0] == 3 and action[1] == 3

echo "Testing fountain fallback when no local safe move"
block:
  var policy = newGorynychPolicy()
  const
    posY = 90
    posX = 40
  var crop: seq[(int, int, int)]
  for (dy, dx) in steps:
    crop.add((dy, dx, wallTile))
  crop.add((1, 1, 11))
  let obs = makeObs(posX, posY, 3, crop = crop)
  let action = policy.heroAction(0, obs)
  let (ady, adx) = vel(action)
  let (fdy, fdx) = policy.nav.stepToward(posY, posX, spawns[0])
  doAssert policy.heroes[0].mode == RetreatMode
  doAssert (ady, adx) == (fdy, fdx), "fallback matches fountain steering"
  doAssert policy.triggers == 0, "fallback is not a local-retreat trigger"
  doAssert policy.changedActions == 0
  doAssert policy.changedIntents == 0
  doAssert policy.fountainFallbacks == 1

echo "Testing hold at fountain is a trigger but not a changed action"
block:
  var policy = newGorynychPolicy()
  let obs = makeObs(12, 113, 3)
  let action = policy.heroAction(0, obs)
  doAssert vel(action) == (0, 0)
  doAssert policy.triggers == 1
  doAssert policy.holdTriggers == 1
  doAssert policy.changedActions == 0,
    "trigger must not imply a changed action"
  doAssert policy.changedIntents == 0

echo "Testing entry and exit health thresholds unchanged"
block:
  var policy = newGorynychPolicy()
  discard policy.heroAction(0, makeObs(40, 90, 4))
  doAssert policy.heroes[0].mode == PushMode, "4/10 stays PUSH"
  discard policy.heroAction(0, makeObs(40, 90, 3))
  doAssert policy.heroes[0].mode == RetreatMode, "3/10 enters RETREAT"
  discard policy.heroAction(0, makeObs(40, 90, 7))
  doAssert policy.heroes[0].mode == RetreatMode, "7/10 stays RETREAT"
  discard policy.heroAction(0, makeObs(40, 90, 8))
  doAssert policy.heroes[0].mode == PushMode, "8/10 exits to PUSH"

echo "Testing push navigation unchanged at full health"
block:
  var policy = newGorynychPolicy()
  let obs = makeObs(26, 99, 10)
  let view = parseView(obs)
  var st = newHeroState()
  let goal = pushGoal(view, st)
  let expected = policy.nav.stepToward(view.y, view.x, goal)
  let action = policy.heroAction(0, obs)
  doAssert policy.heroes[0].mode == PushMode
  doAssert vel(action) == expected, "PUSH steering must match baseline"
  doAssert policy.triggers == 0

echo "Testing telemetry does not alter the action"
block:
  var a = newGorynychPolicy()
  var b = newGorynychPolicy()
  let obs = makeObs(40, 90, 3, crop = @[(1, 1, 11)])
  let actionA = a.heroAction(0, obs)
  let actionB = b.heroAction(0, obs)
  doAssert actionA == actionB
  doAssert a.trialPayload("done")["idea"].getStr() == "recover-near-front"
  doAssert a.trialPayload("done")["heroCalls"].getInt() == 1
  doAssert a.trialPayload("done")["triggers"].getInt() == 1
  var line = "MOBA_TRIAL "
  toUgly(line, a.trialPayload("done"))
  doAssert line.startsWith("MOBA_TRIAL {")
  doAssert "recover-near-front" in line
  doAssert '\n' notin line

echo "Testing periodic emit path at 1000 hero calls"
block:
  var policy = newGorynychPolicy()
  policy.heroCalls = 999
  discard policy.heroAction(0, makeObs(40, 90, 10))
  doAssert policy.heroCalls == 1000

echo "Testing creep threat is treated as an enemy"
block:
  var policy = newGorynychPolicy()
  let obs = makeObs(40, 90, 3, crop = @[(1, 0, direCreepTile)])
  let action = policy.heroAction(0, obs)
  let (ady, adx) = vel(action)
  doAssert ady != 0 or adx != 0
  let newD = chebyshev(90 + ady, 40 + adx, 91, 40)
  doAssert newD > 1
  doAssert policy.stepTriggers == 1

echo "Testing changedActions is issued velocity with an active detour"
block:
  var policy = newGorynychPolicy()
  # Enemy west so the improving step is east; detourLeft=1 so a post-
  # update snapshot would see detourLeft=0 and skip the fountain rotate.
  const
    posY = 90
    posX = 40
    side = 1
  let obs = makeObs(posX, posY, 3, crop = @[(0, -1, 11)])
  let view = parseView(obs)
  policy.heroes[0] = newHeroState()
  let st = policy.heroes[0]
  st.mode = RetreatMode
  st.hasLastPos = true
  st.lastPos = (posY, posX)
  st.triedMove = true
  st.detourLeft = 1
  st.detourSide = side
  let picked = policy.chooseLocalRetreat(view)
  doAssert picked.kind == StepDest
  let (fdy, fdx) = policy.nav.stepToward(posY, posX, spawns[0])
  let issuedCand = rotate90(picked.dy, picked.dx, side)
  let issuedBase = rotate90(fdy, fdx, side)
  let action = policy.heroAction(0, obs)
  doAssert vel(action) == issuedCand, "emitted vel is the rotated local step"
  doAssert policy.heroes[0].detourLeft == 0
  doAssert policy.triggers == 1
  doAssert policy.stepTriggers == 1
  doAssert policy.changedIntents ==
    (if (picked.dy, picked.dx) != (fdy, fdx): 1 else: 0)
  doAssert policy.changedActions ==
    (if issuedCand != issuedBase: 1 else: 0),
    "changedActions must use fountain+detour issued velocity"
  # Using post-update detourLeft==0 would compare issuedCand to unrotated
  # fountain. That must not be what changedActions encodes.
  if issuedCand == (fdy, fdx) and issuedCand != issuedBase:
    doAssert policy.changedActions == 1,
      "must not treat unrotated fountain as the issued baseline"

echo "Testing hold plus active detour still compares issued velocities"
block:
  var policy = newGorynychPolicy()
  const
    posY = 90
    posX = 40
    side = 1
  let obs = makeObs(posX, posY, 3)
  policy.heroes[0] = newHeroState()
  let st = policy.heroes[0]
  st.mode = RetreatMode
  st.hasLastPos = true
  st.lastPos = (posY, posX)
  st.triedMove = true
  st.detourLeft = 1
  st.detourSide = side
  let (fdy, fdx) = policy.nav.stepToward(posY, posX, spawns[0])
  let issuedBase = rotate90(fdy, fdx, side)
  let action = policy.heroAction(0, obs)
  doAssert vel(action) == (0, 0)
  doAssert policy.holdTriggers == 1
  doAssert policy.changedIntents ==
    (if (0, 0) != (fdy, fdx): 1 else: 0)
  doAssert policy.changedActions ==
    (if (0, 0) != issuedBase: 1 else: 0)

echo "all tests passed"
