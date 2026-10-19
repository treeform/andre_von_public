include candidate

proc observation(): Percept =
  ## Rested player on empty grass with shop gold and a free slot.
  result = Percept(data: newSeq[uint8](observationSize))
  result.data[scalarsOffset + scalarHealth] = 99
  result.data[scalarsOffset + scalarCombatLevel] = 1
  result.data[scalarsOffset + scalarGold] = 9

proc enemy(p: var Percept, mind: Mind, r, c: int, live = true) =
  ## Place one live enemy hint at window (r, c).
  let base = (r * windowCols + c) * tileBytes
  p.data[base + entityTypeByte] = enemyEntity.uint8
  p.data[base + entityHealthByte] = 4
  p.data[base + entityAnimByte] = moveAnim.uint8
  if live:
    mind.live[r * windowCols + c] = liveTtl.int8

proc wire(p: Percept): string =
  ## Encode an isolation observation into the raw-byte act input.
  result = newString(p.data.len)
  for i in 0 ..< p.data.len:
    result[i] = char(p.data[i])

proc baseline(mind: Mind, p: Percept): int =
  ## Original branch result without changing the live mind.
  let copy = copyMind(mind)
  copy.decide(p, false)

proc lastEvent(name: string): JsonNode =
  for i in countdown(marketEvents.high, 0):
    if marketEvents[i]{"event"}.getStr() == name:
      return marketEvents[i]
  nil

proc hasEvent(name: string): bool =
  lastEvent(name) != nil

proc clearEvents() =
  marketEvents.setLen(0)

echo "Testing complete successful bounded buy flow."
block:
  clearEvents()
  let mind = newMind(7, 0)
  var p = observation()
  let rng = mind.rng.state
  doAssert mind.act(p.wire(), 10) == buyAction
  doAssert mind.currentTick == 10
  doAssert mind.rng.state == rng
  let issued = lastEvent("strategy_action")
  doAssert issued != nil
  doAssert issued{"tick"}.getInt() == 10
  doAssert issued{"agent"}.getInt() == 0
  doAssert issued{"action"}.getInt() == buyAction
  doAssert issued{"baselineAction"}.getInt() != buyAction
  doAssert issued{"generation"}.getInt() == 0
  doAssert lastEvent("attempt"){"step"}.getStr() == "buy"
  p.data[scalarsOffset + scalarUiMode] = buyTierMode.uint8
  doAssert mind.act(p.wire(), 11) == oneAction
  doAssert lastEvent("attempt"){"step"}.getStr() == "tier"
  p.data[scalarsOffset + scalarUiMode] = buyItemMode.uint8
  doAssert mind.act(p.wire(), 12) == oneAction
  doAssert lastEvent("attempt"){"step"}.getStr() == "item"
  p.data[scalarsOffset + scalarUiMode] = playMode.uint8
  p.data[scalarsOffset + scalarInventory] = helmItem.uint8
  p.data[scalarsOffset + scalarGold] = 0
  discard mind.act(p.wire(), 13)
  doAssert hasEvent("acquired")
  doAssert not hasEvent("failed")
  doAssert mind.buyPhase == 0
  doAssert not mind.buying

echo "Testing failed gold/inventory confirmation and cooldown."
block:
  clearEvents()
  let mind = newMind(7, 0)
  var p = observation()
  doAssert mind.act(p.wire(), 20) == buyAction
  p.data[scalarsOffset + scalarUiMode] = buyTierMode.uint8
  doAssert mind.act(p.wire(), 21) == oneAction
  p.data[scalarsOffset + scalarUiMode] = buyItemMode.uint8
  doAssert mind.act(p.wire(), 22) == oneAction
  p.data[scalarsOffset + scalarUiMode] = playMode.uint8
  discard mind.act(p.wire(), 23)
  doAssert hasEvent("failed")
  doAssert not hasEvent("acquired")
  doAssert mind.buyFailUntil == 23 + buyFailCooldown
  doAssert mind.act(p.wire(), 24) != buyAction
  doAssert mind.act(p.wire(), 23 + buyFailCooldown - 1) != buyAction
  doAssert mind.act(p.wire(), 23 + buyFailCooldown) == buyAction

echo "Testing emergency abort of an open buy UI."
block:
  clearEvents()
  let mind = newMind(7, 0)
  var p = observation()
  doAssert mind.act(p.wire(), 30) == buyAction
  p.data[scalarsOffset + scalarUiMode] = buyTierMode.uint8
  p.enemy(mind, centerRow, centerCol + 4)
  let action = mind.act(p.wire(), 31)
  doAssert action != oneAction
  doAssert action != buyAction
  doAssert hasEvent("abort")
  doAssert not mind.buying
  doAssert mind.currentTick == 31

echo "Testing original action priorities."
block:
  let mind = newMind(7, 0)
  var p = observation()
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
  p.data[scalarsOffset + scalarUiMode] = sellPriceMode.uint8
  mind.selling = true
  doAssert mind.decide(p) == nineAction
block:
  let mind = newMind(7, 0)
  var p = observation()
  p.data[scalarsOffset + scalarGold] = 8
  doAssert mind.decide(p) == mind.baseline(p)
block:
  let mind = newMind(7, 0)
  var p = observation()
  p.data[scalarsOffset + scalarEquipment] = helmItem.uint8
  p.data[scalarsOffset + scalarEquipment + 1] = chestItem.uint8
  p.data[scalarsOffset + scalarEquipment + 2] = legsItem.uint8
  doAssert mind.decide(p) == mind.baseline(p)

echo "Testing reset clears per-life shop state."
block:
  let mind = newMind(7, 0)
  var p = observation()
  discard mind.act(p.wire(), 40)
  mind.reset()
  doAssert not mind.buying
  doAssert mind.buyPhase == 0
  doAssert mind.buyFailUntil == 0
  doAssert mind.currentTick == -1

echo "Market isolation checks passed."
