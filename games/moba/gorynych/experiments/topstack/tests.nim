## Isolation tests for the topstack lane assignment.
## Compile: nim r -d:policyTest tests.nim

include candidate

proc makeObs(x, y, team, heroType: int;
             health10 = 10, mana10 = 10): string =
  ## 510-byte obs with empty crop and one-hot hero type.
  result = newString(observationSize)
  result[selfOffset + 0] = char(x)
  result[selfOffset + 1] = char(y)
  result[selfOffset + 2] = char(0)
  result[selfOffset + 3] = char(health10)
  result[selfOffset + 4] = char(mana10)
  result[selfOffset + 16] = char(team)
  result[selfOffset + 17 + heroType] = char(1)

proc spawnObs(team, heroType: int; health10 = 10): string =
  let (y, x) = spawns[team]
  makeObs(x, y, team, heroType, health10)

proc firstGoal(team, heroType: int, lanes: array[5, int]): (int, int) =
  let view = parseView(spawnObs(team, heroType))
  pushGoal(view, newHeroState(), lanes)

proc sameMove(a, b: array[6, int]): bool =
  a[0] == b[0] and a[1] == b[1]

echo "Testing lane tables"
doAssert baselineLaneForHero == [2, 1, 1, 0, 2]
doAssert laneForHero == [0, 0, 0, 0, 0]
for heroType in 0 .. 4:
  doAssert laneForHero[heroType] + 0 == 0
  doAssert laneForHero[heroType] + 3 == 3

echo "Testing affected heroes (baseline lane different)"
var affectedCount = 0
for heroType in 0 .. 4:
  let affected =
    baselineLaneForHero[heroType] != laneForHero[heroType]
  if heroType == tankHero:
    doAssert(not affected, "tank already walks top")
  else:
    doAssert affected, "non-tank baseline lane must differ"
    inc affectedCount
doAssert affectedCount == 4

echo "Quantifying spawn goals and first actions"
var
  goalChanges = 0
  firstActionChanges = 0
for team in 0 .. 1:
  var stackedPolicy = newGorynychPolicy()
  var baselinePolicy = newGorynychPolicy()
  var stackedMoves: seq[array[6, int]]
  for heroType in 0 .. 4:
    let obs = spawnObs(team, heroType)
    let stackedGoal = firstGoal(team, heroType, laneForHero)
    let baseGoal = firstGoal(team, heroType, baselineLaneForHero)
    let stacked = stackedPolicy.heroActionWithLanes(
      heroType, obs, laneForHero)
    let base = baselinePolicy.heroActionWithLanes(
      heroType, obs, baselineLaneForHero)
    let goalChanged = stackedGoal != baseGoal
    let actionChanged = stacked != base
    echo " team=", team, " hero=", heroType,
      " baseLane=", baselineLaneForHero[heroType] + 3 * team,
      " stackLane=", laneForHero[heroType] + 3 * team,
      " baseGoal=", baseGoal, " stackGoal=", stackedGoal,
      " stackedAction=", stacked, " baseAction=", base,
      " goalChanged=", goalChanged,
      " actionChanged=", actionChanged
    stackedMoves.add(stacked)
    if heroType == tankHero:
      doAssert(not goalChanged)
      doAssert(not actionChanged)
      doAssert stacked == base
    else:
      doAssert goalChanged, "affected hero spawn goal must change"
      inc goalChanges
      if actionChanged:
        inc firstActionChanges
      elif team == 0 and
          (heroType == assassinHero or heroType == burstHero):
        doAssert(not actionChanged)
      else:
        doAssert actionChanged,
          "dire affected and radiant bot roles change first step"
    doAssert stacked[3] == base[3]
    doAssert stacked[4] == base[4]
    doAssert stacked[5] == base[5]
  for heroType in 1 .. 4:
    doAssert sameMove(stackedMoves[0], stackedMoves[heroType]),
      "all five stacked heroes share the first top-lane step"

doAssert goalChanges == 8
doAssert firstActionChanges == 6
echo " changedGoals=", goalChanges,
  " changedFirstActions=", firstActionChanges,
  " of 10 spawn calls (8 affected, 2 tanks)"

echo "Testing telemetry matches verified first-action diffs"
var trialPolicy = newGorynychPolicy()
for team in 0 .. 1:
  for heroType in 0 .. 4:
    let index = team * 5 + heroType
    discard trialPolicy.heroAction(index, spawnObs(team, heroType))
doAssert trialPolicy.trial.heroCalls == 10
doAssert trialPolicy.trial.triggers == 8
doAssert trialPolicy.trial.changedActions == firstActionChanges
let doneNode = trialJson(trialPolicy, "done")
doAssert doneNode["idea"].getStr() == "topstack"
doAssert doneNode["event"].getStr() == "done"
doAssert doneNode["heroCalls"].getInt() == 10
doAssert doneNode["triggers"].getInt() == 8
doAssert doneNode["changedActions"].getInt() == firstActionChanges
emitTrial(trialPolicy, "done")

echo "Testing tank-only seat does not trigger"
var tankOnly = newGorynychPolicy()
discard tankOnly.heroAction(0, spawnObs(0, tankHero))
doAssert tankOnly.trial.heroCalls == 1
doAssert tankOnly.trial.triggers == 0
doAssert tankOnly.trial.changedActions == 0

echo "Testing telemetry does not alter the stacked action"
var wrapPolicy = newGorynychPolicy()
var corePolicy = newGorynychPolicy()
let probe = spawnObs(0, supportHero)
let wrapped = wrapPolicy.heroAction(0, probe)
let core = corePolicy.heroActionWithLanes(0, probe, laneForHero)
doAssert wrapped == core

echo "Testing retreat ignores lanes"
for team in 0 .. 1:
  for heroType in 0 .. 4:
    var stackedPolicy = newGorynychPolicy()
    var baselinePolicy = newGorynychPolicy()
    let obs = makeObs(40, 80, team, heroType, health10 = 2)
    let stacked = stackedPolicy.heroActionWithLanes(
      0, obs, laneForHero)
    let base = baselinePolicy.heroActionWithLanes(
      0, obs, baselineLaneForHero)
    doAssert stacked == base, "retreat must match baseline"
    doAssert stacked[0] != 3 or stacked[1] != 3,
      "retreat from mid-map must step toward the fountain"

echo "Testing first-call retreat is a trigger without a changed action"
var retreatTrial = newGorynychPolicy()
discard retreatTrial.heroAction(0, spawnObs(0, supportHero, health10 = 2))
doAssert retreatTrial.trial.triggers == 1
doAssert retreatTrial.trial.changedActions == 0

echo "Testing siege hold matches baseline"
let siegeRadiant = makeObs(29, 24, 0, supportHero)
let siegeDire = makeObs(16, 57, 1, 4)
for obs in [siegeRadiant, siegeDire]:
  var stackedPolicy = newGorynychPolicy()
  var baselinePolicy = newGorynychPolicy()
  let stacked = stackedPolicy.heroActionWithLanes(
    0, obs, laneForHero)
  let base = baselinePolicy.heroActionWithLanes(
    0, obs, baselineLaneForHero)
  doAssert stacked == base, "siege hold must match baseline"
  doAssert stacked[0] == 3 and stacked[1] == 3,
    "standoff without a wave should hold"

echo "Testing skills match baseline with an enemy in crop"
var skillObs = spawnObs(0, supportHero)
skillObs[(0 + visionRange) * cropWidth + (1 + visionRange)] = char(11)
var skillStacked = newGorynychPolicy()
var skillBaseline = newGorynychPolicy()
let skillA = skillStacked.heroActionWithLanes(
  0, skillObs, laneForHero)
let skillB = skillBaseline.heroActionWithLanes(
  0, skillObs, baselineLaneForHero)
doAssert skillA[3] == skillB[3]
doAssert skillA[4] == skillB[4]
doAssert skillA[5] == skillB[5]
doAssert skillA[3] == 1 and skillA[5] == 1
doAssert skillA != skillB, "movement still changes on topstack"

echo "Testing checkpoint emit at 1000 hero calls"
var checkpointPolicy = newGorynychPolicy()
let supportSpawn = spawnObs(0, supportHero)
for i in 1 .. 1000:
  discard checkpointPolicy.heroAction(0, supportSpawn)
doAssert checkpointPolicy.trial.heroCalls == 1000
doAssert checkpointPolicy.trial.triggers == 1000
doAssert checkpointPolicy.trial.changedActions == 1

echo "topstack isolation tests passed"
