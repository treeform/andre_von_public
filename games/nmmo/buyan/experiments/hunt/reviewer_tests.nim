include candidate

proc observation(): Percept =
  ## Create a rested player on empty grass for isolation checks.
  result = Percept(data: newSeq[uint8](observationSize))
  result.data[scalarsOffset + scalarHealth] = 99
  result.data[scalarsOffset + scalarCombatLevel] = 1

proc enemy(p: var Percept, mind: Mind, r, c: int,
           element = 0, delta = 0, animation = moveAnim, live = true) =
  ## Add one enemy hint with explicit freshness for branch isolation.
  let base = (r * windowCols + c) * tileBytes
  p.data[base + entityTypeByte] = enemyEntity.uint8
  p.data[base + 5] = element.uint8
  p.data[base + entityDeltaByte] = delta.uint8
  p.data[base + entityHealthByte] = 4
  p.data[base + entityAnimByte] = animation.uint8
  if live:
    mind.live[r * windowCols + c] = liveTtl.int8

proc baseline(mind: Mind, p: Percept): int =
  ## Compute the original branch result without changing the live mind.
  let copy = Mind()
  copy[] = mind[]
  copy.decide(p, false)

echo "Testing approach stages outside NPC first-hit range."
block:
  let mind = newMind(7, 0)
  var p = observation()
  p.enemy(mind, centerRow, centerCol + 3)
  let rng = mind.rng.state
  doAssert mind.decide(p) == rightAction
  doAssert mind.rng.state == rng

echo "Testing bounded distance-two wait."
block:
  let mind = newMind(7, 0)
  var p = observation()
  p.enemy(mind, centerRow, centerCol + 2)
  doAssert mind.decide(p) == noopAction
  doAssert mind.decide(p) == noopAction
  doAssert mind.decide(p) == mind.baseline(p)

echo "Testing dangerous or untrusted targets retain baseline behavior."
for scenario in 0 ..< 7:
  let mind = newMind(7, 0)
  var p = observation()
  case scenario
  of 0:
    p.enemy(mind, centerRow, centerCol + 2, animation = deathAnim)
  of 1:
    p.enemy(mind, centerRow, centerCol + 2, live = false)
  of 2:
    p.enemy(mind, centerRow, centerCol + 2, delta = 1)
  of 3:
    p.enemy(mind, centerRow, centerCol + 2, element = 1)
  of 4:
    p.enemy(mind, centerRow, centerCol + 2)
    p.enemy(mind, centerRow + 3, centerCol)
  of 5:
    p.enemy(mind, centerRow, centerCol + 2)
    p.data[scalarsOffset + scalarHealth] = 70
  else:
    p.enemy(mind, centerRow, centerCol + 2)
    p.data[scalarsOffset + scalarInCombat] = 3
  let expected = mind.baseline(p)
  doAssert mind.decide(p) == expected, $scenario

echo "Testing original action priorities."
block:
  let mind = newMind(7, 0)
  var p = observation()
  p.enemy(mind, centerRow, centerCol + 2)
  p.data[scalarsOffset + scalarHealth] = 30
  p.data[scalarsOffset + scalarInventory] = herbItem.uint8
  doAssert mind.decide(p) == oneAction
block:
  let mind = newMind(7, 0)
  var p = observation()
  p.enemy(mind, centerRow, centerCol + 1)
  doAssert mind.decide(p) == attackAction
block:
  let mind = newMind(7, 0)
  var p = observation()
  p.enemy(mind, centerRow, centerCol + 2)
  let base = ((centerRow + 1) * windowCols + centerCol) * tileBytes
  p.data[base + itemTypeByte] = toolItem.uint8
  doAssert mind.decide(p) == downAction
block:
  let mind = newMind(7, 0)
  var p = observation()
  p.enemy(mind, centerRow, centerCol + 2)
  p.data[scalarsOffset + scalarUiMode] = sellPriceMode.uint8
  mind.selling = true
  doAssert mind.decide(p) == nineAction

echo "Reviewer isolation checks passed."

proc wire(p: Percept): string =
  ## Encode an isolation observation into the existing raw-byte input.
  result = newString(p.data.len)
  for i in 0 ..< p.data.len:
    result[i] = char(p.data[i])

echo "Testing actual wire tick and bounded diagnostic confirmation."
block:
  let mind = newMind(7, 3)
  var p = observation()
  discard mind.act(p.wire(), 40)
  p.enemy(mind, centerRow, centerCol + 3)
  doAssert mind.act(p.wire(), 41) == rightAction
  doAssert mind.currentTick == 41
  doAssert mind.huntRemaining == 10
  p.enemy(mind, centerRow, centerCol + 1)
  p.data[scalarsOffset + scalarAnim] = moveAnim.uint8
  doAssert mind.act(p.wire(), 42) == attackAction
  doAssert not mind.huntMove
  doAssert mind.huntRemaining == 9
  p.data[scalarsOffset + scalarInCombat] = 5
  p.data[scalarsOffset + scalarHealth] = 80
  p.data[scalarsOffset + scalarAnim] = 2
  doAssert mind.act(p.wire(), 43) == attackAction
  doAssert mind.huntCombat
  p.data[scalarsOffset + scalarCombatLevel] = 2
  p.data[scalarsOffset + scalarInventory] = toolItem.uint8
  discard mind.act(p.wire(), 44)
  doAssert mind.huntLevel == 2
  doAssert mind.huntTool == 1
  doAssert mind.huntRemaining == 7
  mind.reset()
  doAssert mind.huntRemaining == 0
  doAssert mind.huntWaits == 0
echo "Wire telemetry checks passed."
