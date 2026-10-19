include candidate

proc blankData(): seq[uint8] =
  ## All-grass window, idle, healthy, empty inventory.
  result = newSeq[uint8](observationSize)
  result[scalarsOffset + scalarHealth] = 99
  result[scalarsOffset + scalarCombatLevel] = 1
  result[scalarsOffset + scalarProfessionLevel] = 1

proc setAnim(data: var seq[uint8], anim: int) =
  ## Set the fresh self animation scalar.
  data[scalarsOffset + scalarAnim] = uint8(anim)

proc setEnemy(data: var seq[uint8], r, c: int, delta = 1, healthBucket = 5) =
  ## Place a live-looking enemy imprint.
  let base = (r * windowCols + c) * tileBytes
  data[base + entityTypeByte] = uint8(enemyEntity)
  data[base + entityDeltaByte] = uint8(delta)
  data[base + entityHealthByte] = uint8(healthBucket)

proc toObs(data: seq[uint8]): string =
  ## Encode fixture bytes as a wire observation payload.
  result = newString(data.len)
  for i, b in data:
    result[i] = char(b)

proc toPercept(data: seq[uint8]): Percept =
  ## Wrap fixture bytes in a policy percept.
  Percept(data: data)

block ordinaryWanderWalksNotRuns:
  ## Grass wander maps old maybeRun 22..25 onto walk 0..3.
  let p = toPercept(blankData())
  let mind = newMind(11, 0)
  let walked = mind.wander(p, @[])
  doAssert isWalk(walked)
  doAssert walked == mind.wanderAction
  let base = newMind(11, 0)
  let ran = base.wander(p, @[], wanderRun = true)
  doAssert isRun(ran)
  doAssert ran - runOffset == walked
  doAssert ran in 22 .. 25
  doAssert walked in 0 .. 3
  doAssert mind.rng.state == base.rng.state
  doAssert mind.wanderAction == base.wanderAction
  doAssert mind.wanderLeft == base.wanderLeft

block stepTowardsStillRuns:
  ## Harvest approach is unchanged: two-tile axis still maybeRuns.
  let mind = newMind(0, 0)
  let p = toPercept(blankData())
  let chosen = mind.stepTowards(p, @[], centerRow + 2, centerCol)
  doAssert chosen == downAction + runOffset

block emergencyFleeStillRuns:
  ## Stronger adjacent imprint after a liveness change still maybeRuns.
  var first = blankData()
  var second = blankData()
  setEnemy(second, centerRow, centerCol + 1, 1)
  let mind = newMind(3, 0)
  discard mind.act(toObs(first), 1)
  let issuedBefore = mind.walkingIssued
  let action = mind.act(toObs(second), 2)
  doAssert isRun(action)
  doAssert action in 22 .. 25
  doAssert mind.walkingIssued == issuedBefore

block wireMarkerOnChangedWander:
  ## Actual wire action is the walk; baseline is the run; tick is the reply.
  let mind = newMind(19, 1)
  let action = mind.act(toObs(blankData()), 40)
  doAssert isWalk(action)
  doAssert mind.walkingIssued == 1
  doAssert mind.walkingPending
  doAssert mind.walkingPendingAction == action
  doAssert mind.walkingBaselineAction == action + runOffset
  doAssert isRun(mind.walkingBaselineAction)
  doAssert mind.walkingIssueTick == 40
  doAssert mind.currentTick == 40
  doAssert mind.agentIndex == 1
  doAssert mind.generation == 0

block cloneDoesNotMutateCandidateRng:
  ## Counterfactual decide runs on a copy; candidate RNG matches solo wander.
  let viaAct = newMind(7, 0)
  let viaWander = newMind(7, 0)
  let p = toPercept(blankData())
  let a = viaAct.act(toObs(blankData()), 8)
  let w = viaWander.wander(p, @[])
  doAssert a == w
  doAssert viaAct.rng.state == viaWander.rng.state
  doAssert viaAct.wanderAction == viaWander.wanderAction

block motionFeedbackSeparateFromIssue:
  ## Next observation logs motion from fresh anim; issuance already counted.
  let mind = newMind(5, 0)
  discard mind.act(toObs(blankData()), 10)
  doAssert mind.walkingIssued == 1
  doAssert mind.walkingPending
  var follow = blankData()
  setAnim(follow, moveAnim)
  discard mind.act(toObs(follow), 11)
  doAssert mind.walkingIssued == 2  # continued wander still a changed walk
  doAssert mind.walkingIssueTick == 11
  doAssert mind.currentTick == 11

block resetClearsPerLifeWalkingState:
  let mind = newMind(0, 0)
  discard mind.act(toObs(blankData()), 5)
  doAssert mind.walkingPending
  let gen = mind.generation
  let issued = mind.walkingIssued
  mind.reset()
  doAssert not mind.walkingPending
  doAssert mind.walkingPendingAction == 0
  doAssert mind.walkingIssueTick == 0
  doAssert mind.walkingBaselineAction == -1
  doAssert mind.generation == gen + 1
  doAssert mind.walkingIssued == issued
  var follow = blankData()
  setAnim(follow, runAnim)
  discard mind.act(toObs(follow), 6)
  doAssert mind.walkingIssueTick == 6

block defaultTickIsOptional:
  let mind = newMind(0, 0)
  let issued = mind.act(toObs(blankData()))
  doAssert isWalk(issued)
  doAssert mind.currentTick == 0
  doAssert mind.walkingIssueTick == 0
  doAssert mind.walkingIssued == 1
