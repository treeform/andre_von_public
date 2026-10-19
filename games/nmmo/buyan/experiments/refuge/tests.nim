## Isolation tests for recovery-NOOP fallback. Compile with -d:buyanTest.

include candidate

const
  SafeHealth = 100
  InjuredHealth = 80
  WireTick = 42
  AgentIdx = 3

proc blankObs(health = SafeHealth): string =
  ## Grass window, idle, empty inventory.
  result = newString(observationSize)
  result[scalarsOffset + scalarHealth] = char(health)
  result[scalarsOffset + scalarCombatLevel] = char(1)
  result[scalarsOffset + scalarProfessionLevel] = char(1)

proc putEnemy(obs: var string; r, c: int; delta = 0; healthBucket = 5) =
  ## Write a live-looking enemy imprint at window cell (r, c).
  let base = (r * windowCols + c) * tileBytes
  obs[base + entityTypeByte] = char(enemyEntity)
  obs[base + entityDeltaByte] = char(delta)
  obs[base + entityHealthByte] = char(healthBucket)
  obs[base + entityAnimByte] = char(idleAnim)

proc putHerb(obs: var string, invSlot = 0) =
  ## Put a herb in inventory slot 0.
  obs[scalarsOffset + scalarInventory + invSlot] = char(herbItem)

proc lastStrategy(): JsonNode =
  ## Last strategy_action event, or nil.
  result = nil
  for node in refugeEvents:
    if node{"event"}.getStr() == "strategy_action":
      result = node

proc lastHp(): JsonNode =
  ## Last refuge_hp diagnostic, or nil.
  result = nil
  for node in refugeEvents:
    if node{"event"}.getStr() == "refuge_hp":
      result = node

block injuredSafeFallbackRests:
  refugeEvents.setLen(0)
  var obs = blankObs(InjuredHealth)
  let mind = newMind(11, AgentIdx)
  let action = mind.act(obs, WireTick)
  doAssert action == noopAction
  doAssert mind.restIssued == 1
  let ev = lastStrategy()
  doAssert ev != nil
  doAssert ev{"event"}.getStr() == "strategy_action"
  doAssert ev{"experiment"}.getStr() == "refuge"
  doAssert ev{"tick"}.getInt() == WireTick
  doAssert ev{"agent"}.getInt() == AgentIdx
  doAssert ev{"action"}.getInt() == noopAction
  doAssert ev{"baselineAction"}.getInt() != noopAction
  doAssert ev{"generation"}.getInt() == 0
  doAssert mind.restPending
  doAssert mind.restHealth == InjuredHealth

block subsequentHpDeltaSeparate:
  refugeEvents.setLen(0)
  var obs = blankObs(InjuredHealth)
  let mind = newMind(11, AgentIdx)
  doAssert mind.act(obs, 10) == noopAction
  obs[scalarsOffset + scalarHealth] = char(InjuredHealth + 1)
  doAssert mind.act(obs, 11) == noopAction
  let hp = lastHp()
  doAssert hp != nil
  doAssert hp{"event"}.getStr() == "refuge_hp"
  doAssert hp{"tick"}.getInt() == 11
  doAssert hp{"hpDelta"}.getInt() == 1
  doAssert hp{"priorHealth"}.getInt() == InjuredHealth
  doAssert hp{"health"}.getInt() == InjuredHealth + 1
  var sawIssue = false
  for node in refugeEvents:
    if node{"event"}.getStr() == "strategy_action" and
        node{"tick"}.getInt() == 10:
      sawIssue = true
  doAssert sawIssue

block healthyFallbackUnchanged:
  refugeEvents.setLen(0)
  var obs = blankObs(SafeHealth)
  let mind = newMind(7, 0)
  let copy = copyMind(mind)
  copy.updateLiveness(Percept(data: block:
    var d = newSeq[uint8](obs.len)
    for i in 0 ..< obs.len:
      d[i] = obs[i].uint8
    d))
  let baseline = copy.decide(Percept(data: block:
    var d = newSeq[uint8](obs.len)
    for i in 0 ..< obs.len:
      d[i] = obs[i].uint8
    d), false)
  let action = mind.act(obs, 3)
  doAssert action == baseline
  doAssert action != noopAction
  doAssert lastStrategy() == nil
  doAssert mind.restIssued == 0

block nearbyThreatOriginalLogic:
  refugeEvents.setLen(0)
  var first = blankObs(InjuredHealth)
  let mind = newMind(5, 1)
  discard mind.act(first, 1)
  refugeEvents.setLen(0)
  mind.restIssued = 0
  var obs = blankObs(InjuredHealth)
  putEnemy(obs, centerRow, centerCol + 4)
  let p = Percept(data: block:
    var d = newSeq[uint8](obs.len)
    for i in 0 ..< obs.len:
      d[i] = obs[i].uint8
    d)
  let before = copyMind(mind)
  before.updateLiveness(p)
  let base = before.decide(p, false)
  let action = mind.act(obs, 2)
  doAssert action == base
  doAssert lastStrategy() == nil
  doAssert mind.restIssued == 0

block inCombatDoesNotRest:
  refugeEvents.setLen(0)
  var obs = blankObs(InjuredHealth)
  obs[scalarsOffset + scalarInCombat] = char(1)
  let mind = newMind(3, 0)
  let action = mind.act(obs, 8)
  doAssert action != noopAction or lastStrategy() == nil
  doAssert lastStrategy() == nil

block healPriorityUnchanged:
  refugeEvents.setLen(0)
  var obs = blankObs(30)
  putHerb(obs)
  let mind = newMind(2, 0)
  doAssert mind.act(obs, 4) == oneAction
  doAssert lastStrategy() == nil

block resetClearsPending:
  var obs = blankObs(InjuredHealth)
  let mind = newMind(9, 0)
  doAssert mind.act(obs, 5) == noopAction
  doAssert mind.restPending
  mind.reset()
  doAssert not mind.restPending
  doAssert mind.restHealth == 0
  doAssert mind.generation == 1

echo "ok refuge isolation"
