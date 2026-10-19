include candidate

proc blankData(): seq[uint8] =
  ## All-grass window, idle, healthy, empty inventory.
  result = newSeq[uint8](observationSize)
  result[scalarsOffset + scalarHealth] = 99

proc setAnim(data: var seq[uint8], anim: int) =
  ## Set the fresh self animation scalar.
  data[scalarsOffset + scalarAnim] = uint8(anim)

proc setTerrain(data: var seq[uint8], r, c, terrain: int) =
  ## Set one tile's terrain class.
  data[(r * windowCols + c) * tileBytes + terrainByte] = uint8(terrain)

proc setGround(data: var seq[uint8], r, c, kind, tierByte: int) =
  ## Set one ground item's type and encoded tier.
  let base = (r * windowCols + c) * tileBytes
  data[base + itemTypeByte] = uint8(kind)
  data[base + itemTierByte] = uint8(tierByte)

proc toObs(data: seq[uint8]): string =
  ## Encode fixture bytes as a wire observation payload.
  result = newString(data.len)
  for i, b in data:
    result[i] = char(b)

proc toPercept(data: seq[uint8]): Percept =
  ## Wrap fixture bytes in a policy percept.
  Percept(data: data)

proc grassPercept(anim = idleAnim): Percept =
  ## Create an empty grass percept with the requested animation.
  var data = blankData()
  setAnim(data, anim)
  toPercept(data)

proc harvestObs(anim, tr, tc: int): string =
  ## Ground tool at (tr, tc) so decide reaches stepTowards via harvest.
  var data = blankData()
  setAnim(data, anim)
  setGround(data, tr, tc, toolItem, 0)
  toObs(data)

proc followObs(anim: int): string =
  ## Create the fresh observation after an issued recovery.
  var data = blankData()
  setAnim(data, anim)
  toObs(data)

proc noIssue(mind: Mind) =
  ## Assert that the decision has no changed-action diagnostic.
  doAssert mind.escapeIssued == 0
  doAssert not mind.escapePending
  doAssert mind.escapeBaselineAction == -1

block failedRunTakesAlternateAxis:
  ## Each failed run on the primary axis demotes to the other target axis.
  const Cases = [
    (downAction + runOffset, centerRow + 2, centerCol + 2, rightAction),
    (upAction + runOffset, centerRow - 2, centerCol + 2, rightAction),
    (rightAction + runOffset, centerRow + 2, centerCol + 3, downAction),
    (leftAction + runOffset, centerRow + 2, centerCol - 3, downAction)
  ]
  for (failedRun, tr, tc, altWalk) in Cases:
    let mind = newMind(0, 0)
    mind.lastAction = failedRun
    mind.tick = 10
    let p = grassPercept(idleAnim)
    let chosen = mind.stepTowards(p, @[], tr, tc)
    mind.logEscapeIssue(chosen)
    doAssert chosen == altWalk + runOffset
    doAssert mind.escapeIssued == 1
    doAssert mind.escapePending
    doAssert mind.escapePendingAction == chosen
    doAssert mind.escapeIssueTick == 10

block successfulRunsUnchanged:
  const Cases = [
    (downAction + runOffset, centerRow + 2, centerCol + 2, downAction),
    (upAction + runOffset, centerRow - 2, centerCol + 2, upAction),
    (rightAction + runOffset, centerRow + 2, centerCol + 3, rightAction),
    (leftAction + runOffset, centerRow + 2, centerCol - 3, leftAction)
  ]
  for (lastRun, tr, tc, primary) in Cases:
    let mind = newMind(0, 0)
    mind.lastAction = lastRun
    let p = grassPercept(runAnim)
    let chosen = mind.stepTowards(p, @[], tr, tc)
    doAssert chosen == primary + runOffset
    noIssue(mind)

block failedWalksRetainOldBehavior:
  const Cases = [
    (downAction, centerRow + 2, centerCol + 2, rightAction),
    (upAction, centerRow - 2, centerCol + 2, rightAction),
    (rightAction, centerRow + 2, centerCol + 3, downAction),
    (leftAction, centerRow + 2, centerCol - 3, downAction)
  ]
  for (failedWalk, tr, tc, altWalk) in Cases:
    let mind = newMind(0, 0)
    mind.lastAction = failedWalk
    let p = grassPercept(idleAnim)
    let chosen = mind.stepTowards(p, @[], tr, tc)
    doAssert chosen == altWalk + runOffset
    noIssue(mind)

block oneAxisUnchanged:
  let mind = newMind(0, 0)
  mind.lastAction = downAction + runOffset
  doAssert mind.stepTowards(grassPercept(), @[], centerRow + 2,
                            centerCol) == downAction + runOffset
  noIssue(mind)
  mind.lastAction = rightAction + runOffset
  doAssert mind.stepTowards(grassPercept(), @[], centerRow,
                            centerCol + 2) == rightAction + runOffset
  noIssue(mind)

block noAlternateNotCounted:
  var data = blankData()
  setAnim(data, idleAnim)
  setTerrain(data, centerRow, centerCol + 1, 2)  # stone: right blocked
  let mind = newMind(0, 0)
  mind.lastAction = downAction + runOffset
  let chosen = mind.stepTowards(toPercept(data), @[], centerRow + 2,
                                centerCol + 2)
  doAssert chosen == -1
  doAssert mind.escapeIssued == 0
  doAssert not mind.escapePending
  doAssert mind.escapeBaselineAction == downAction + runOffset

block failedSecondaryNotCounted:
  ## Failed run was the secondary preference; primary is still selected.
  let mind = newMind(0, 0)
  mind.lastAction = rightAction + runOffset
  let chosen = mind.stepTowards(grassPercept(), @[], centerRow + 2,
                                centerCol + 2)
  doAssert chosen == downAction + runOffset
  noIssue(mind)

block failedPrimaryAlreadyExcludedNotCounted:
  ## Down is not a safe move, so original baseline already takes right.
  var data = blankData()
  setAnim(data, idleAnim)
  setTerrain(data, centerRow + 1, centerCol, 2)  # stone: down blocked
  let mind = newMind(0, 0)
  mind.lastAction = downAction + runOffset
  let p = toPercept(data)
  let chosen = mind.stepTowards(p, @[], centerRow + 2, centerCol + 2)
  doAssert chosen == rightAction + runOffset
  noIssue(mind)

block walkDistanceAlternate:
  ## Alternate axis has distance 1, so the issued action is a walk.
  let mind = newMind(0, 0)
  mind.lastAction = downAction + runOffset
  let chosen = mind.stepTowards(grassPercept(), @[], centerRow + 1,
                                centerCol + 1)
  mind.logEscapeIssue(chosen)
  doAssert chosen == rightAction
  doAssert mind.escapeIssued == 1
  doAssert mind.escapePendingAction == rightAction

block tickActionAssociation:
  let mind = newMind(1, 2)
  mind.lastAction = downAction + runOffset
  let issued = mind.act(harvestObs(idleAnim, centerRow + 2, centerCol + 2),
                        40)
  doAssert issued == rightAction + runOffset
  doAssert mind.escapeIssued == 1
  doAssert mind.escapePending
  doAssert mind.escapePendingAction == issued
  doAssert mind.escapeIssueTick == 40
  doAssert mind.tick == 40
  doAssert mind.agentIndex == 2
  doAssert mind.generation == 0
  doAssert mind.act("short") == noopAction
  doAssert mind.escapePending
  doAssert mind.escapeConfirmed == 0
  discard mind.act(followObs(runAnim), 41)
  doAssert not mind.escapePending
  doAssert mind.tick == 41
  doAssert mind.escapeConfirmed == 1
  doAssert mind.escapeFailed == 0
  doAssert mind.escapeIssued == 1

block confirmMoveRunIdle:
  proc issueThen(anim: int, expectOk: bool) =
    ## Assert a recovery issue resolves from the next fresh animation.
    let mind = newMind(0, 0)
    mind.lastAction = downAction + runOffset
    let issued = mind.act(harvestObs(idleAnim, centerRow + 2, centerCol + 2),
                          7)
    doAssert issued == rightAction + runOffset
    discard mind.act(followObs(anim), 8)
    if expectOk:
      doAssert mind.escapeConfirmed == 1
      doAssert mind.escapeFailed == 0
    else:
      doAssert mind.escapeConfirmed == 0
      doAssert mind.escapeFailed == 1
    doAssert not mind.escapePending
  issueThen(moveAnim, true)
  issueThen(runAnim, true)
  issueThen(idleAnim, false)

block resetDoesNotMisattribute:
  let mind = newMind(0, 0)
  mind.lastAction = downAction + runOffset
  discard mind.act(harvestObs(idleAnim, centerRow + 2, centerCol + 2), 5)
  doAssert mind.escapePending
  doAssert mind.escapeIssued == 1
  let gen = mind.generation
  mind.reset()
  doAssert not mind.escapePending
  doAssert mind.escapePendingAction == 0
  doAssert mind.escapeIssueTick == 0
  doAssert mind.generation == gen + 1
  doAssert mind.escapeIssued == 1  # per-agent; pending must not survive
  discard mind.act(followObs(runAnim), 6)
  doAssert mind.escapeConfirmed == 0
  doAssert mind.escapeFailed == 0
  doAssert not mind.escapePending

block defaultTickIsOptional:
  let mind = newMind(0, 0)
  mind.lastAction = downAction + runOffset
  let issued = mind.act(harvestObs(idleAnim, centerRow + 2, centerCol + 2))
  doAssert issued == rightAction + runOffset
  doAssert mind.tick == 0
  doAssert mind.escapeIssueTick == 0
  doAssert mind.escapeIssued == 1

block fallthroughActionIsCounted:
  var data = blankData()
  setGround(data, centerRow + 2, centerCol + 2, toolItem, 0)
  setTerrain(data, centerRow, centerCol + 1, 2)
  let mind = newMind(0, 0)
  mind.lastAction = downAction + runOffset
  let action = mind.act(toObs(data), 50)
  doAssert action != downAction + runOffset
  doAssert mind.escapeBaselineAction == downAction + runOffset
  doAssert mind.escapeIssued == 1
  doAssert mind.escapePendingAction == action

block firstBaselineIsPreserved:
  var data = blankData()
  setTerrain(data, centerRow, centerCol + 1, 2)
  let mind = newMind(0, 0)
  mind.lastAction = downAction + runOffset
  doAssert mind.stepTowards(toPercept(data), @[], centerRow + 2,
                            centerCol + 1) == -1
  doAssert mind.escapeBaselineAction == downAction + runOffset
  doAssert mind.stepTowards(toPercept(data), @[], centerRow + 1,
                            centerCol - 1) == leftAction
  doAssert mind.escapeBaselineAction == downAction + runOffset
  mind.logEscapeIssue(downAction + runOffset)
  doAssert mind.escapeIssued == 0
  doAssert not mind.escapePending
  mind.logEscapeIssue(leftAction)
  doAssert mind.escapeIssued == 1
  doAssert mind.escapePendingAction == leftAction

block nonmovementFallthroughIsCounted:
  var data = blankData()
  setGround(data, centerRow + 2, centerCol + 1, toolItem, 0)
  setTerrain(data, centerRow, centerCol + 1, 2)
  data[scalarsOffset + scalarInventory] = uint8(toolItem)
  let mind = newMind(0, 0)
  mind.lastAction = downAction + runOffset
  doAssert mind.act(toObs(data), 60) == oneAction
  doAssert mind.escapeBaselineAction == downAction + runOffset
  doAssert mind.escapeIssued == 1
  doAssert mind.escapePendingAction == oneAction
  discard mind.act(followObs(idleAnim), 61)
  doAssert mind.escapeConfirmed == 0
  doAssert mind.escapeFailed == 1
  doAssert not mind.escapePending

echo "Escape isolation assertions passed."
