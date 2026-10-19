## Isolation tests for forward waypoint skip.
## Run: nim r --hints:off -d:policyTest tests.nim

include candidate

proc velStep(action: array[6, int]): (int, int) =
  ## Decode a unit-step velocity pair. Engine vel is (a-3)/3.
  doAssert action[0] in {0, 3, 6}, "vel_y is not a legal unit step"
  doAssert action[1] in {0, 3, 6}, "vel_x is not a legal unit step"
  ((action[0] - 3) div 3, (action[1] - 3) div 3)

proc cropIndex(dy, dx: int): int =
  (dy + visionRange) * cropWidth + (dx + visionRange)

proc makeCrop(nav: var NavGrid, y, x: int, hero: uint8): array[cropTiles, uint8] =
  ## Crop from the static wall mask; center is this hero's tile.
  for dy in -visionRange .. visionRange:
    for dx in -visionRange .. visionRange:
      let
        i = cropIndex(dy, dx)
        ny = y + dy
        nx = x + dx
      if ny < 0 or ny >= mapWidth or nx < 0 or nx >= mapWidth:
        result[i] = wallTile.uint8
      elif nav.walls[ny * mapWidth + nx]:
        result[i] = wallTile.uint8
      else:
        result[i] = emptyTile.uint8
  result[cropIndex(0, 0)] = hero

proc makeObs(y, x, level, health10, mana10, team, heroType: int,
             crop: array[cropTiles, uint8]): string =
  result = newString(observationSize)
  for i in 0 ..< cropTiles:
    result[i] = char(crop[i])
  result[selfOffset + 0] = char(x)
  result[selfOffset + 1] = char(y)
  result[selfOffset + 2] = char(level)
  result[selfOffset + 3] = char(health10)
  result[selfOffset + 4] = char(mana10)
  result[selfOffset + 16] = char(team)
  result[selfOffset + 17 + heroType] = char(1)

proc tankObs(nav: var NavGrid, y, x: int, health10 = 10,
             crop: array[cropTiles, uint8]): string =
  makeObs(y, x, 1, health10, 10, 0, tankHero, crop)

echo "Spawn tank matches sequential first waypoint (no skip)"
var nav = initNavGrid()
let
  spawnY = 113
  spawnX = 12
  spawnCrop = makeCrop(nav, spawnY, spawnX, uint8(6 + tankHero))
  spawnObs = tankObs(nav, spawnY, spawnX, crop = spawnCrop)
var spawnPolicy = newGorynychPolicy()
let spawnAction = spawnPolicy.heroAction(0, spawnObs)
let (spawnDy, spawnDx) = velStep(spawnAction)
doAssert spawnDy in -1 .. 1 and spawnDx in -1 .. 1
doAssert spawnDy != 0 or spawnDx != 0
doAssert spawnPolicy.triggers == 0
doAssert spawnPolicy.changedActions == 0
doAssert spawnPolicy.actualMoves == 0
doAssert spawnPolicy.heroCalls == 1
let spawnView = parseView(spawnObs)
doAssert spawnPolicy.heroes[0].waypointIndex == 0
let spawnGoal = (int(waypoints[0][0][0]), int(waypoints[0][0][1]))
doAssert nav.stepToward(spawnY, spawnX, spawnGoal) == (spawnDy, spawnDx)
echo "  spawn step=", (spawnDy, spawnDx), " wp=", spawnPolicy.heroes[0].waypointIndex

echo "Overshoot skips a farther earlier waypoint; issued step differs"
# Radiant top wp2=(58,16), wp3=(43,16) reached, wp4=(32,17) closer than wp2.
const
  overY = 43
  overX = 16
doAssert not nav.walls[overY * mapWidth + overX], "overshoot cell is a wall"
var overCrop = makeCrop(nav, overY, overX, uint8(6 + tankHero))
let overObs = tankObs(nav, overY, overX, crop = overCrop)
var overPolicy = newGorynychPolicy()
overPolicy.heroes[0] = newHeroState()
overPolicy.heroes[0].waypointIndex = 2
let overAction = overPolicy.heroAction(0, overObs)
let (overDy, overDx) = velStep(overAction)
let seqGoal = (int(waypoints[0][2][0]), int(waypoints[0][2][1]))
let seqStep = nav.stepToward(overY, overX, seqGoal)
let fwdGoal = (int(waypoints[0][4][0]), int(waypoints[0][4][1]))
let fwdStep = nav.stepToward(overY, overX, fwdGoal)
doAssert seqGoal == (58, 16)
doAssert fwdGoal == (32, 17)
doAssert seqStep != fwdStep, "fixture must change the BFS step"
doAssert (overDy, overDx) == fwdStep
doAssert (overDy, overDx) != seqStep
doAssert overPolicy.triggers == 1
doAssert overPolicy.changedActions == 1
doAssert overPolicy.actualMoves == 1
doAssert overPolicy.heroes[0].waypointIndex == 4
doAssert overAction[2] == spawnAction[2]
doAssert overAction[3] == 0 and overAction[4] == 0 and overAction[5] == 0
echo "  overshoot seq=", seqStep, " fwd=", fwdStep, " issued=", (overDy, overDx),
     " wp=", overPolicy.heroes[0].waypointIndex

echo "Same cell with sequential index already nearest does not trigger"
var samePolicy = newGorynychPolicy()
samePolicy.heroes[0] = newHeroState()
samePolicy.heroes[0].waypointIndex = 4
let sameAction = samePolicy.heroAction(0, overObs)
doAssert velStep(sameAction) == fwdStep
doAssert samePolicy.triggers == 0
doAssert samePolicy.changedActions == 0
doAssert samePolicy.heroes[0].waypointIndex == 4

echo "Retreat still walks to fountain; no skip trigger"
var retPolicy = newGorynychPolicy()
retPolicy.heroes[0] = newHeroState()
retPolicy.heroes[0].waypointIndex = 2
retPolicy.heroes[0].mode = RetreatMode
let retObs = tankObs(nav, overY, overX, health10 = 2, crop = overCrop)
let retAction = retPolicy.heroAction(0, retObs)
let retStep = nav.stepToward(overY, overX, spawns[0])
doAssert velStep(retAction) == retStep
doAssert retPolicy.triggers == 0
doAssert retPolicy.changedActions == 0
doAssert retPolicy.heroes[0].mode == RetreatMode

echo "Siege hold is unchanged when a live enemy tower is at standoff"
# Dire T1 top ~ (18, 29). Stand at chebyshev 6 with no friendly creeps.
const
  siegeY = 18
  siegeX = 29 + 6
var siegeNav = initNavGrid()
doAssert not siegeNav.walls[siegeY * mapWidth + siegeX]
var siegeCrop = makeCrop(siegeNav, siegeY, siegeX, uint8(6 + tankHero))
# Mark the tower cell in-crop so memory does not declare it dead.
let tdy = 18 - siegeY
let tdx = 29 - siegeX
if abs(tdy) <= visionRange and abs(tdx) <= visionRange:
  siegeCrop[cropIndex(tdy, tdx)] = towerTile.uint8
let siegeObs = tankObs(siegeNav, siegeY, siegeX, crop = siegeCrop)
var siegePolicy = newGorynychPolicy()
let siegeAction = siegePolicy.heroAction(0, siegeObs)
doAssert velStep(siegeAction) == (0, 0), "standoff without wave must hold"
doAssert siegeAction[0] == 3 and siegeAction[1] == 3
# Skills/filter still come from crop scan, not from the skip.

echo "Telemetry does not alter the action"
var telPolicy = newGorynychPolicy()
telPolicy.heroes[0] = newHeroState()
telPolicy.heroes[0].waypointIndex = 2
let telAction = telPolicy.heroAction(0, overObs)
let telTriggers = telPolicy.triggers
let telChanged = telPolicy.changedActions
let telMoves = telPolicy.actualMoves
emitTrial(telPolicy)
telPolicy.heroes[0].waypointIndex = 2
telPolicy.heroes[0].hasLastPos = false
telPolicy.heroes[0].stuckTicks = 0
telPolicy.heroes[0].detourLeft = 0
let telAction2 = telPolicy.heroAction(0, overObs)
doAssert telAction2 == telAction
doAssert telPolicy.triggers == telTriggers + 1
doAssert telPolicy.changedActions == telChanged + 1
doAssert telPolicy.actualMoves == telMoves + 1
doAssert telAction == overAction

echo "Every 1000 hero calls still counts"
var countPolicy = newGorynychPolicy()
for i in 1 .. 1000:
  discard countPolicy.heroAction(0, spawnObs)
doAssert countPolicy.heroCalls == 1000
doAssert countPolicy.triggers == 0
doAssert countPolicy.changedActions == 0
doAssert countPolicy.actualMoves == 0

echo "Malformed obs is a no-op and does not trigger"
var badPolicy = newGorynychPolicy()
let badAction = badPolicy.heroAction(0, "short")
doAssert badAction == [3, 3, 0, 0, 0, 0]
doAssert badPolicy.heroCalls == 1
doAssert badPolicy.triggers == 0

echo "All routes isolation tests passed"
