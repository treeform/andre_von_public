## Isolation tests for occupancy-aware navigation.
## Run: nim r -d:policyTest tests.nim

include candidate

proc velStep(action: array[6, int]): (int, int) =
  ## Decode a unit-step velocity pair. Engine vel is (a-3)/3.
  doAssert action[0] in {0, 3, 6}, "vel_y is not a legal unit step"
  doAssert action[1] in {0, 3, 6}, "vel_x is not a legal unit step"
  ((action[0] - 3) div 3, (action[1] - 3) div 3)

proc cropIndex(dy, dx: int): int =
  ## Return the crop offset of a relative cell.
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
  ## Encode a synthetic observation for navigation isolation.
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

proc isOpen8(nav: NavGrid, y, x: int): bool =
  ## Check whether a cell and all eight neighbors are walkable.
  if nav.walls[y * mapWidth + x]:
    return false
  for (dy, dx) in steps:
    let ny = y + dy
    let nx = x + dx
    if ny < 0 or ny >= mapWidth or nx < 0 or nx >= mapWidth:
      return false
    if nav.walls[ny * mapWidth + nx]:
      return false
  true

proc tankObs(nav: var NavGrid, y, x: int,
             crop: array[cropTiles, uint8]): string =
  ## Encode a healthy radiant tank fixture.
  makeObs(y, x, 1, 10, 10, 0, tankHero, crop)

proc findOpenMover(): (int, int, array[6, int], array[cropTiles, uint8]) =
  ## Radiant tank cell with 8 walkable neighbors and a non-zero PUSH step.
  var nav = initNavGrid()
  for y in 90 .. 110:
    for x in 14 .. 36:
      if not isOpen8(nav, y, x):
        continue
      var crop = makeCrop(nav, y, x, uint8(6 + tankHero))
      let obs = tankObs(nav, y, x, crop)
      var policy = newGorynychPolicy()
      let action = policy.heroAction(0, obs)
      let (dy, dx) = velStep(action)
      if (dy != 0 or dx != 0) and policy.triggers == 0:
        return (y, x, action, crop)
  doAssert false, "no open tank cell with a baseline step"

echo "Legal direction and occupied-cell avoidance"
let (y, x, baselineAction, emptyCrop) = findOpenMover()
let (baseDy, baseDx) = velStep(baselineAction)
doAssert baseDy in -1 .. 1 and baseDx in -1 .. 1
doAssert baseDy != 0 or baseDx != 0
echo "  baseline cell=", (y, x), " step=", (baseDy, baseDx)

var occupiedCrop = emptyCrop
occupiedCrop[cropIndex(baseDy, baseDx)] = radiantCreepTile.uint8
var nav = initNavGrid()
let occupiedObs = tankObs(nav, y, x, occupiedCrop)
var occPolicy = newGorynychPolicy()
let occAction = occPolicy.heroAction(0, occupiedObs)
let (occDy, occDx) = velStep(occAction)
doAssert occDy in -1 .. 1 and occDx in -1 .. 1
doAssert occAction[0] in {0, 3, 6} and occAction[1] in {0, 3, 6}
doAssert occPolicy.triggers == 1, "occupied dest must trigger"
doAssert occPolicy.changedActions == 1, "verified step change"
doAssert (occDy, occDx) != (baseDy, baseDx)
if occDy != 0 or occDx != 0:
  doAssert occupiedCrop[cropIndex(occDy, occDx)] == emptyTile.uint8
# Skills and target filter must match baseline (friendly creep, no tower).
doAssert occAction[2] == baselineAction[2]
doAssert occAction[3] == baselineAction[3]
doAssert occAction[4] == baselineAction[4]
doAssert occAction[5] == baselineAction[5]
# Chosen empty neighbor is the min existing BFS cost among empty cells.
let occView = parseView(occupiedObs)
let occGoal = pushGoal(occView, occPolicy.heroes[0])
let expected = occupancyReroute(occPolicy.nav, occView, occGoal)
doAssert (occDy, occDx) == expected
echo "  occupancy step=", (occDy, occDx), " triggers=", occPolicy.triggers,
     " changed=", occPolicy.changedActions

echo "Occupancy reroute is a legal 8-neighbor or no-op"
var legalFound = false
for (dy, dx) in steps:
  if (occDy, occDx) == (dy, dx):
    legalFound = true
if occDy == 0 and occDx == 0:
  legalFound = true
doAssert legalFound

echo "Empty dest matches baseline (no trigger)"
var emptyPolicy = newGorynychPolicy()
let emptyObs = tankObs(nav, y, x, emptyCrop)
let emptyAction = emptyPolicy.heroAction(0, emptyObs)
doAssert emptyAction == baselineAction
doAssert emptyPolicy.triggers == 0
doAssert emptyPolicy.changedActions == 0
doAssert velStep(emptyAction) == (baseDy, baseDx)

echo "Occupying a non-dest neighbor does not change the step"
var sideCrop = emptyCrop
var sidePlaced = false
for (dy, dx) in steps:
  if (dy, dx) == (baseDy, baseDx):
    continue
  if sideCrop[cropIndex(dy, dx)] == emptyTile.uint8:
    sideCrop[cropIndex(dy, dx)] = radiantCreepTile.uint8
    sidePlaced = true
    break
doAssert sidePlaced
var sidePolicy = newGorynychPolicy()
let sideAction = sidePolicy.heroAction(0, tankObs(nav, y, x, sideCrop))
doAssert velStep(sideAction) == (baseDy, baseDx)
doAssert sidePolicy.triggers == 0
doAssert sidePolicy.changedActions == 0
doAssert sideAction[2] == baselineAction[2]
doAssert sideAction[3] == baselineAction[3]
doAssert sideAction[4] == baselineAction[4]
doAssert sideAction[5] == baselineAction[5]

echo "No empty useful step is a no-op"
var boxedCrop = emptyCrop
for (dy, dx) in steps:
  boxedCrop[cropIndex(dy, dx)] = radiantCreepTile.uint8
var boxedPolicy = newGorynychPolicy()
let boxedAction = boxedPolicy.heroAction(0, tankObs(nav, y, x, boxedCrop))
doAssert velStep(boxedAction) == (0, 0)
doAssert boxedAction[0] == 3 and boxedAction[1] == 3
doAssert boxedPolicy.triggers == 1
doAssert boxedPolicy.changedActions == 1
doAssert boxedPolicy.occupancyNoops == 1

echo "Apply after detours: occupied detour dest triggers"
var detourPolicy = newGorynychPolicy()
discard detourPolicy.heroAction(0, emptyObs)
detourPolicy.heroes[0].detourLeft = 3
detourPolicy.heroes[0].detourSide = 1
let detourView = parseView(emptyObs)
let detourGoal = pushGoal(detourView, detourPolicy.heroes[0])
let (steerDy, steerDx) = detourPolicy.nav.stepToward(y, x, detourGoal)
let (detourDy, detourDx) = rotate90(steerDy, steerDx, 1)
doAssert detourDy != 0 or detourDx != 0
var detourCrop = emptyCrop
detourCrop[cropIndex(detourDy, detourDx)] = radiantCreepTile.uint8
# Reset counters after the setup call; keep hero state (detourLeft).
detourPolicy.heroCalls = 0
detourPolicy.triggers = 0
detourPolicy.changedActions = 0
detourPolicy.occupancyNoops = 0
detourPolicy.trialEmitted = false
let detourAction = detourPolicy.heroAction(0, tankObs(nav, y, x, detourCrop))
let (outDy, outDx) = velStep(detourAction)
doAssert detourPolicy.triggers == 1
doAssert detourPolicy.changedActions == 1
doAssert (outDy, outDx) != (detourDy, detourDx)
if outDy != 0 or outDx != 0:
  doAssert detourCrop[cropIndex(outDy, outDx)] == emptyTile.uint8

echo "Apply after detours: occupied pre-detour dest does not trigger"
var prePolicy = newGorynychPolicy()
discard prePolicy.heroAction(0, emptyObs)
prePolicy.heroes[0].detourLeft = 3
prePolicy.heroes[0].detourSide = 1
let preView = parseView(emptyObs)
let preGoal = pushGoal(preView, prePolicy.heroes[0])
let (preSteerDy, preSteerDx) = prePolicy.nav.stepToward(y, x, preGoal)
let (preDetourDy, preDetourDx) = rotate90(preSteerDy, preSteerDx, 1)
doAssert (preSteerDy, preSteerDx) != (preDetourDy, preDetourDx)
var preCrop = emptyCrop
preCrop[cropIndex(preSteerDy, preSteerDx)] = radiantCreepTile.uint8
doAssert preCrop[cropIndex(preDetourDy, preDetourDx)] == emptyTile.uint8
prePolicy.heroCalls = 0
prePolicy.triggers = 0
prePolicy.changedActions = 0
prePolicy.occupancyNoops = 0
prePolicy.trialEmitted = false
let preAction = prePolicy.heroAction(0, tankObs(nav, y, x, preCrop))
doAssert prePolicy.triggers == 0, "post-detour dest is empty"
doAssert velStep(preAction) == (preDetourDy, preDetourDx)

echo "Telemetry does not alter the action"
var telPolicy = newGorynychPolicy()
let telAction = telPolicy.heroAction(0, occupiedObs)
let telTriggers = telPolicy.triggers
let telChanged = telPolicy.changedActions
let telCalls = telPolicy.heroCalls
emitTrial(telPolicy)
doAssert telPolicy.heroAction(0, occupiedObs)[0] in {0, 3, 6}
doAssert telPolicy.triggers == telTriggers + 1
doAssert telPolicy.changedActions == telChanged + 1
doAssert telPolicy.heroCalls == telCalls + 1
# emitTrial itself is echo-only.
doAssert telAction[2] == occAction[2]
doAssert telAction == occAction

echo "Every 1000 hero calls still counts"
var countPolicy = newGorynychPolicy()
for i in 1 .. 1000:
  discard countPolicy.heroAction(0, emptyObs)
doAssert countPolicy.heroCalls == 1000
doAssert countPolicy.triggers == 0
doAssert countPolicy.changedActions == 0

echo "Malformed obs is a no-op and does not trigger"
var badPolicy = newGorynychPolicy()
let badAction = badPolicy.heroAction(0, "short")
doAssert badAction == [3, 3, 0, 0, 0, 0]
doAssert badPolicy.heroCalls == 1
doAssert badPolicy.triggers == 0

echo "All occupancy isolation tests passed"
