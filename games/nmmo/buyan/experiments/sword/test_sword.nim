## Isolation tests for the sword-stance candidate.
##   nim r --hints:off -d:buyanTest --path:/Users/me/p/whisky/src test_sword.nim

include candidate

proc makeItem(kind, tier: int): int =
  ## Raw inventory id for kind at 1-based tier.
  (tier - 1) * itemTypeCount + kind

proc blankData(): seq[uint8] =
  ## Zeroed obs with enough health to skip healing.
  result = newSeq[uint8](observationSize)
  result[scalarsOffset + scalarHealth] = 100'u8

proc setSc(data: var seq[uint8], i, v: int) =
  ## Write a self-scalar byte.
  data[scalarsOffset + i] = uint8(v)

proc setLevels(data: var seq[uint8], combat, profession: int) =
  ## Fresh combat and profession scalars.
  setSc(data, scalarCombatLevel, combat)
  setSc(data, scalarProfessionLevel, profession)

proc setInv(data: var seq[uint8], slot, item: int, equipped = false) =
  ## Inventory slot and optional equipped flag.
  setSc(data, scalarInventory + slot, item)
  if equipped:
    setSc(data, scalarIsEquipped + slot, 1)

proc setHeld(data: var seq[uint8], item: int) =
  ## Fresh held equipment scalar (offset 13+heldSlot).
  setSc(data, scalarEquipment + heldSlot, item)

proc putEnemy(data: var seq[uint8], r, c: int, delta = 0, bucket = 5,
              anim = 0) =
  ## Orthogonal-adjacent enemy imprint on a window cell.
  let base = (r * windowCols + c) * tileBytes
  data[base + entityTypeByte] = uint8(enemyEntity)
  data[base + entityDeltaByte] = uint8(delta)
  data[base + entityHealthByte] = uint8(bucket)
  data[base + entityAnimByte] = uint8(anim)

proc asObs(data: seq[uint8]): string =
  ## Protocol obs byte array as the act() string.
  result = newString(data.len)
  for i, b in data:
    result[i] = char(b)

proc perceptOf(data: seq[uint8]): Percept =
  ## Percept over a synthetic obs buffer.
  Percept(data: data)

proc countEvent(name: string): int =
  ## How many captured events use this name.
  for e in swordEvents:
    if e["event"].getStr() == name:
      inc result

proc findEvent(name: string): JsonNode =
  ## Last captured event with this name, or nil.
  result = nil
  for e in swordEvents:
    if e["event"].getStr() == name:
      result = e

proc fillGems(data: var seq[uint8], startSlot: int) =
  ## Fill remaining inventory with earth gems so the bag is full.
  for i in startSlot ..< inventorySlots:
    setInv(data, i, makeItem(gemItems[0], 1))

block selectSwordOnEqualLevels:
  clearSwordEvents()
  var data = blankData()
  setLevels(data, 5, 5)
  setInv(data, 0, makeItem(toolItem, 1))
  setInv(data, 1, makeItem(SwordItem, 1))
  var mind = newMind(0, 0)
  let action = mind.act(asObs(data), 17)
  doAssert action == oneAction + 1, "equal levels must equip the sword"
  doAssert equipAction(perceptOf(data)) == oneAction + 1
  let ev = findEvent("strategy_action")
  doAssert ev != nil, "sword equip must log strategy_action"
  doAssert ev["strategy"].getStr() == "sword"
  doAssert ev["event"].getStr() == "strategy_action"
  doAssert ev["tick"].getInt() == 17
  doAssert ev["agent"].getInt() == 0
  doAssert ev["generation"].getInt() == 0
  doAssert ev["step"].getInt() == 1
  doAssert ev["candidateAction"].getInt() == oneAction + 1
  doAssert ev["baselineAction"].getInt() == oneAction + 0
  echo "ok select sword on equal levels ", $ev

block retainedEquippedSwordNoCycle:
  clearSwordEvents()
  var data = blankData()
  setLevels(data, 8, 8)
  let sword = makeItem(SwordItem, 1)
  setInv(data, 0, sword, equipped = true)
  setHeld(data, sword)
  setInv(data, 1, makeItem(toolItem, 1))
  var mind = newMind(0, 0)
  let first = mind.act(asObs(data))
  let second = mind.act(asObs(data))
  doAssert first != oneAction + 0, "must not unequip the held sword"
  doAssert second != oneAction + 0, "second tick must not cycle"
  doAssert equipAction(perceptOf(data)) == -1
  echo "ok retained equipped sword with no cycling"

block toolEmptySwordFreshObs:
  clearSwordEvents()
  var mind = newMind(0, 0)
  let tool = makeItem(toolItem, 1)
  let sword = makeItem(SwordItem, 1)
  var heldTool = blankData()
  setLevels(heldTool, 4, 4)
  setInv(heldTool, 0, tool, equipped = true)
  setHeld(heldTool, tool)
  setInv(heldTool, 1, sword)
  let unequip = mind.act(asObs(heldTool))
  doAssert unequip == oneAction + 0, "first tick unequips the tool"
  doAssert findEvent("held_issued")["op"].getStr() == "unequip"
  var emptyHeld = blankData()
  setLevels(emptyHeld, 4, 4)
  setInv(emptyHeld, 0, tool)
  setInv(emptyHeld, 1, sword)
  let equip = mind.act(asObs(emptyHeld))
  doAssert equip == oneAction + 1, "empty held equips the sword"
  doAssert findEvent("held_issued")["op"].getStr() == "equip"
  doAssert findEvent("held_confirmed") != nil
  var heldSword = blankData()
  setLevels(heldSword, 4, 4)
  setInv(heldSword, 0, tool)
  setInv(heldSword, 1, sword, equipped = true)
  setHeld(heldSword, sword)
  let keep = mind.act(asObs(heldSword))
  doAssert keep != oneAction + 1, "must not unequip the sword"
  doAssert findEvent("held_confirmed")["held"].getInt() == sword
  echo "ok tool -> empty -> sword fresh observations"

block reequipToolWhenCombatAhead:
  clearSwordEvents()
  var mind = newMind(0, 0)
  let tool = makeItem(toolItem, 1)
  let sword = makeItem(SwordItem, 1)
  var heldSword = blankData()
  setLevels(heldSword, 10, 5)
  setInv(heldSword, 0, sword, equipped = true)
  setHeld(heldSword, sword)
  setInv(heldSword, 1, tool)
  let unequip = mind.act(asObs(heldSword))
  doAssert unequip == oneAction + 0, "combat > profession unequips sword"
  var emptyHeld = blankData()
  setLevels(emptyHeld, 10, 5)
  setInv(emptyHeld, 0, sword)
  setInv(emptyHeld, 1, tool)
  let equip = mind.act(asObs(emptyHeld))
  doAssert equip == oneAction + 1, "then equips the tool"
  echo "ok re-equip tool after combat > profession"

block inCombatEquipLock:
  clearSwordEvents()
  var data = blankData()
  setLevels(data, 5, 5)
  setInv(data, 0, makeItem(toolItem, 1), equipped = true)
  setHeld(data, makeItem(toolItem, 1))
  setInv(data, 1, makeItem(SwordItem, 1))
  setSc(data, scalarInCombat, 5)
  var mind = newMind(0, 0)
  let action = mind.act(asObs(data))
  doAssert action < oneAction or action > nineAction,
    "inCombat must not issue an equip key"
  doAssert countEvent("held_issued") == 0
  echo "ok inCombat equip lock"

block noSwordFallback:
  clearSwordEvents()
  var data = blankData()
  setLevels(data, 3, 9)
  setInv(data, 0, makeItem(toolItem, 1))
  var mind = newMind(0, 0)
  let action = mind.act(asObs(data))
  doAssert action == oneAction + 0, "no sword keeps baseline tool equip"
  doAssert countEvent("strategy_action") == 0
  echo "ok no-sword fallback"

block slotNineSwordFallback:
  clearSwordEvents()
  var data = blankData()
  setLevels(data, 2, 6)
  setInv(data, 0, makeItem(toolItem, 1))
  setInv(data, 9, makeItem(SwordItem, 2))
  var mind = newMind(0, 0)
  let action = mind.act(asObs(data))
  doAssert action == oneAction + 0, "slot 9 sword is not actionable"
  doAssert desiredHeldSlot(perceptOf(data)) == 0
  doAssert countEvent("strategy_action") == 0
  echo "ok unusable slot 9 sword fallback"

block bestSwordJunkProtection:
  clearSwordEvents()
  var data = blankData()
  setLevels(data, 5, 5)
  let tool = makeItem(toolItem, 1)
  let sword = makeItem(SwordItem, 1)
  setInv(data, 0, tool, equipped = true)
  setHeld(data, tool)
  setInv(data, 1, sword)
  fillGems(data, 2)
  setSc(data, scalarUiMode, sellSelectMode)
  let p = perceptOf(data)
  doAssert junkSlot(p, true) == 2, "best key sword must not be junk"
  doAssert junkSlot(p, false) == 1, "baseline would sell the sword"
  var mind = newMind(0, 0)
  mind.selling = true
  let action = mind.act(asObs(data), 4)
  doAssert action == oneAction + 2
  let ev = findEvent("strategy_action")
  doAssert ev != nil
  doAssert ev["candidateAction"].getInt() == oneAction + 2
  doAssert ev["baselineAction"].getInt() == oneAction + 1
  echo "ok best-sword protection from junk sale"

block resetPendingFeedback:
  clearSwordEvents()
  var data = blankData()
  setLevels(data, 5, 5)
  setInv(data, 0, makeItem(toolItem, 1))
  setInv(data, 1, makeItem(SwordItem, 1))
  var mind = newMind(0, 0)
  discard mind.act(asObs(data))
  doAssert mind.pendingHeld, "issued held swap arms pending"
  let gen = mind.generation
  mind.reset()
  doAssert not mind.pendingHeld
  doAssert not mind.pendingAttack
  doAssert mind.obsStep == 0
  doAssert mind.generation == gen + 1
  clearSwordEvents()
  discard mind.act(asObs(data))
  doAssert countEvent("held_confirmed") == 0
  doAssert countEvent("held_failed") == 0
  echo "ok reset pending feedback"

block issuedVersusConfirmedAttack:
  clearSwordEvents()
  var base = blankData()
  setLevels(base, 5, 5)
  let sword = makeItem(SwordItem, 1)
  setInv(base, 0, sword, equipped = true)
  setHeld(base, sword)
  var mind = newMind(0, 0)
  discard mind.act(asObs(base))
  var appeared = base
  putEnemy(appeared, 4, 7, delta = 0, bucket = 5)
  clearSwordEvents()
  doAssert mind.act(asObs(appeared)) == attackAction
  doAssert findEvent("attack_issued") != nil
  var animOnly = appeared
  setSc(animOnly, scalarAnim, SwordAnim)
  clearSwordEvents()
  discard mind.act(asObs(animOnly))
  let animFb = findEvent("attack_feedback")
  doAssert animFb != nil
  doAssert animFb["anim"].getInt() == SwordAnim
  doAssert animFb["in_combat"].getInt() == 0
  doAssert animFb["combat_delta"].getInt() == 0
  doAssert animFb["target_present"].getBool()
  doAssert animFb["health_bucket_delta"].getInt() == 0
  var confirmedMind = newMind(1, 0)
  discard confirmedMind.act(asObs(base))
  doAssert confirmedMind.act(asObs(appeared)) == attackAction
  var hit = appeared
  setSc(hit, scalarAnim, SwordAnim)
  setSc(hit, scalarInCombat, 5)
  putEnemy(hit, 4, 7, delta = 0, bucket = 3)
  clearSwordEvents()
  discard confirmedMind.act(asObs(hit))
  let hitFb = findEvent("attack_feedback")
  doAssert hitFb["in_combat"].getInt() == 5
  doAssert hitFb["health_bucket_delta"].getInt() == -2
  doAssert hitFb["anim"].getInt() == SwordAnim
  echo "ok issued versus confirmed attack feedback"

block counterfactualMindAndStrategyAction:
  clearSwordEvents()
  var data = blankData()
  setLevels(data, 5, 5)
  setInv(data, 0, makeItem(toolItem, 1))
  setInv(data, 1, makeItem(SwordItem, 1))
  var mind = newMind(3, 0)
  let rng0 = mind.rng.state
  let wander0 = mind.wanderLeft
  let sell0 = mind.selling
  let streak0 = mind.attackStreak
  let live0 = mind.live[0]
  let last0 = mind.lastAction
  let action = mind.act(asObs(data), 17)
  doAssert action == oneAction + 1
  doAssert mind.rng.state == rng0, "copy decide must not consume live RNG"
  doAssert mind.wanderLeft == wander0
  doAssert mind.selling == sell0
  doAssert mind.attackStreak == streak0
  doAssert mind.live[0] == live0
  doAssert mind.lastAction == action, "sent action is the candidate action"
  doAssert last0 == noopAction
  let ev = findEvent("strategy_action")
  doAssert ev != nil
  doAssert ev["candidateAction"].getInt() == action
  doAssert ev["baselineAction"].getInt() == oneAction + 0
  doAssert ev["tick"].getInt() == 17
  echo "ok counterfactual mind intact and strategy_action on sword equip"

block equivalentActionNoStrategyEvent:
  clearSwordEvents()
  var data = blankData()
  setLevels(data, 3, 9)
  setInv(data, 0, makeItem(toolItem, 1))
  var a = newMind(7, 0)
  var b = newMind(7, 0)
  let obs = asObs(data)
  let action = a.act(obs)
  doAssert action == oneAction + 0
  doAssert countEvent("strategy_action") == 0
  let p = perceptOf(data)
  b.updateLiveness(p)
  doAssert b.decide(p, true) == action
  doAssert a.rng.state == b.rng.state
  echo "ok no strategy_action for baseline-equivalent actions"

block wanderCounterfactualDoesNotTouchLiveRng:
  clearSwordEvents()
  var data = blankData()
  setLevels(data, 3, 1)
  var a = newMind(11, 0)
  var b = newMind(11, 0)
  let obs = asObs(data)
  discard a.act(obs)
  let p = perceptOf(data)
  b.updateLiveness(p)
  discard b.decide(p, true)
  doAssert a.rng.state == b.rng.state
  doAssert a.wanderAction == b.wanderAction
  doAssert a.wanderLeft == b.wanderLeft
  doAssert countEvent("strategy_action") == 0
  echo "ok wander counterfactual does not change live RNG"

block rejectedEquipStillIssued:
  clearSwordEvents()
  var data = blankData()
  setLevels(data, 5, 5)
  setInv(data, 0, makeItem(toolItem, 1))
  setInv(data, 1, makeItem(SwordItem, 1))
  var mind = newMind(0, 0)
  let issued = mind.act(asObs(data), 17)
  doAssert issued == oneAction + 1
  doAssert countEvent("strategy_action") == 1
  doAssert findEvent("held_issued")["expected_held"].getInt() ==
    makeItem(SwordItem, 1)
  clearSwordEvents()
  let again = mind.act(asObs(data), 18)
  doAssert again == oneAction + 1, "still issues the sword equip"
  doAssert findEvent("held_failed") != nil
  doAssert findEvent("held_failed"){"held"}.getInt() == 0
  doAssert countEvent("strategy_action") == 1,
    "rejected equip still counts as an issued action change"
  echo "ok rejected equips still count as issued action changes"

block duplicateSwordCanBeSold:
  var data = blankData()
  setLevels(data, 5, 4)
  setInv(data, 0, makeItem(toolItem, 1))
  setInv(data, 1, makeItem(SwordItem, 1))
  setInv(data, 2, makeItem(SwordItem, 1))
  let p = perceptOf(data)
  doAssert junkSlot(p, true) == 2,
    "duplicate sword must be saleable while best sword/tool are retained"
  echo "ok duplicate sword can be sold"

echo "all sword isolation tests reached the end"
