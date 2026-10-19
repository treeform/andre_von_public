## Isolation tests for occupied-armor unequip. Compile with -d:buyanTest.

include candidate

const
  WornInv = 0
  BagInv = 1
  ExtraInv = 2
  HerbInv = 0
  ToolInv = 0
  BetterToolInv = 1
  ArmorWornInv = 2
  ArmorBagInv = 3
  NonKeyInv = 9
  SafeHealth = 100
  LowHealth = 30
  WireTick = 42
  AgentIdx = 4

proc makeItem(kind, tier: int): int =
  ## Encode a wire item id from kind and one-based tier.
  (tier - 1) * itemTypeCount + kind

proc blankObs(): string =
  ## Return a 1707-byte grass window with safe idle health.
  result = newString(observationSize)
  result[scalarsOffset + scalarHealth] = char(SafeHealth)
  result[scalarsOffset + 6] = char(SafeHealth)
  result[scalarsOffset + scalarCombatLevel] = char(1)
  result[scalarsOffset + scalarProfessionLevel] = char(1)

proc toPercept(obs: string): Percept =
  ## Copy observation bytes into a Percept.
  result.data = newSeq[uint8](obs.len)
  for i in 0 ..< obs.len:
    result.data[i] = obs[i].uint8

proc putItem(obs: var string; invSlot, itemId: int; equipped = false) =
  ## Write inventory slot invSlot and the matching equipped flag.
  obs[scalarsOffset + scalarInventory + invSlot] = char(itemId)
  obs[scalarsOffset + scalarIsEquipped + invSlot] =
    char(if equipped: 1 else: 0)

proc putWorn(obs: var string; wearSlot, invSlot, itemId: int) =
  ## Equip itemId in wearSlot and mark inventory invSlot worn.
  putItem(obs, invSlot, itemId, equipped = true)
  obs[scalarsOffset + scalarEquipment + wearSlot] = char(itemId)

proc putEnemy(obs: var string; r, c: int; delta = 0; healthBucket = 5) =
  ## Write a live-looking enemy imprint at window cell (r, c).
  let base = (r * windowCols + c) * tileBytes
  obs[base + entityTypeByte] = char(enemyEntity)
  obs[base + entityDeltaByte] = char(delta)
  obs[base + entityHealthByte] = char(healthBucket)
  obs[base + entityAnimByte] = char(idleAnim)

proc occupiedArmor(kind: int, wornTier = 1, bagTier = 3,
                   wornInv = WornInv, bagInv = BagInv): string =
  ## Occupied armor slot with a strictly better unequipped piece.
  result = blankObs()
  putWorn(result, armorSlotFor(kind), wornInv, makeItem(kind, wornTier))
  putItem(result, bagInv, makeItem(kind, bagTier))

proc emptyArmor(kind: int, lowTier = 1, bagTier = 3, midTier = 2): string =
  ## Empty armor slot holding unequipped low, best, and mid-tier pieces.
  result = blankObs()
  putItem(result, WornInv, makeItem(kind, lowTier))
  putItem(result, BagInv, makeItem(kind, bagTier))
  putItem(result, ExtraInv, makeItem(kind, midTier))

proc wornUpgrade(kind: int, freshTier = 3, oldTier = 1): string =
  ## Fresh equipment already showing the higher-tier piece of this kind.
  result = blankObs()
  putWorn(result, armorSlotFor(kind), BagInv, makeItem(kind, freshTier))
  putItem(result, WornInv, makeItem(kind, oldTier))

block old1New3Unequip:
  var obs = occupiedArmor(helmItem, 1, 3)
  putItem(obs, ExtraInv, makeItem(helmItem, 2))
  doAssert equipAction(toPercept(obs)) == oneAction + WornInv
  var mind = newMind(0, AgentIdx)
  doAssert mind.act(obs, WireTick) == oneAction + WornInv
  doAssert mind.wireTick == WireTick
  doAssert mind.agentIndex == AgentIdx
  doAssert mind.generation == 0
  doAssert mind.armorIssued == 1
  doAssert mind.armorConfirmed == 0
  doAssert mind.pendingArmor[helmSlot].active
  doAssert mind.pendingArmor[helmSlot].oldTier == 1
  doAssert mind.pendingArmor[helmSlot].desiredTier == 3

block emptyThenConfirmed:
  var mind = newMind(0, 0)
  var obs = occupiedArmor(helmItem, 1, 3)
  putItem(obs, ExtraInv, makeItem(helmItem, 2))
  doAssert mind.act(obs, 10) == oneAction + WornInv
  doAssert mind.armorIssued == 1
  doAssert mind.armorConfirmed == 0
  let empty = emptyArmor(helmItem)
  doAssert mind.act(empty, 11) == oneAction + BagInv
  doAssert mind.armorIssued == 1
  doAssert mind.armorConfirmed == 0
  doAssert mind.pendingArmor[helmSlot].active
  doAssert mind.wireTick == 11
  let done = wornUpgrade(helmItem, 3, 1)
  discard mind.act(done, 12)
  doAssert mind.armorConfirmed == 1
  doAssert mind.armorTierGain == 2
  doAssert not mind.pendingArmor[helmSlot].active
  doAssert mind.wireTick == 12
  discard mind.act(done, 13)
  doAssert mind.armorConfirmed == 1
  doAssert mind.armorTierGain == 2
  echoArmorUpgradeSummary(mind)

block unchangedFreshEquipment:
  let
    mind = newMind(0, 0)
    obs = occupiedArmor(helmItem)
  doAssert mind.act(obs, 20) == oneAction + WornInv
  doAssert mind.act(obs, 21) == oneAction + WornInv
  doAssert mind.armorIssued == 2
  doAssert mind.armorConfirmed == 0
  doAssert mind.armorTierGain == 0
  doAssert mind.pendingArmor[helmSlot].active
  discard mind.act(emptyArmor(helmItem), 22)
  doAssert mind.armorConfirmed == 0
  discard mind.act(wornUpgrade(helmItem), 23)
  doAssert mind.armorConfirmed == 1
  doAssert mind.armorTierGain == 2

block allThreeTypes:
  for kind in [helmItem, chestItem, legsItem]:
    let wear = armorSlotFor(kind)
    doAssert equipAction(toPercept(occupiedArmor(kind))) == oneAction + WornInv
    var mind = newMind(0, 0)
    doAssert mind.act(occupiedArmor(kind), 1) == oneAction + WornInv
    doAssert mind.pendingArmor[wear].active
    doAssert mind.armorIssued == 1
    let empty = emptyArmor(kind)
    doAssert mind.act(empty, 2) == oneAction + BagInv
    doAssert mind.armorConfirmed == 0
    discard mind.act(wornUpgrade(kind), 3)
    doAssert mind.armorConfirmed == 1
    doAssert mind.armorTierGain == 2

block equalLowerUnchanged:
  doAssert equipAction(toPercept(occupiedArmor(helmItem, 2, 2))) == -1
  doAssert equipAction(toPercept(occupiedArmor(chestItem, 3, 1))) == -1
  doAssert equipAction(toPercept(occupiedArmor(legsItem, 2, 1))) == -1
  var mind = newMind(0, 0)
  discard mind.act(occupiedArmor(helmItem, 2, 2), 7)
  doAssert mind.armorIssued == 0
  doAssert not mind.pendingArmor[helmSlot].active
  discard mind.act(occupiedArmor(helmItem, 3, 1), 8)
  doAssert mind.armorIssued == 0

block emptySlotUnchanged:
  var obs = blankObs()
  putItem(obs, BagInv, makeItem(helmItem, 3))
  doAssert equipAction(toPercept(obs)) == oneAction + BagInv
  var mind = newMind(0, 0)
  doAssert mind.act(obs, 2) == oneAction + BagInv
  doAssert mind.armorIssued == 0

block bestToolPriority:
  var obs = blankObs()
  putWorn(obs, heldSlot, ToolInv, makeItem(toolItem, 1))
  putItem(obs, BetterToolInv, makeItem(toolItem, 2))
  putWorn(obs, helmSlot, ArmorWornInv, makeItem(helmItem, 1))
  putItem(obs, ArmorBagInv, makeItem(helmItem, 3))
  doAssert equipAction(toPercept(obs)) == oneAction + ToolInv
  var mind = newMind(0, 0)
  doAssert mind.act(obs, 5) == oneAction + ToolInv
  doAssert mind.armorIssued == 0
  doAssert not mind.pendingArmor[helmSlot].active

block nonaddressableEquipped:
  var obs = blankObs()
  putWorn(obs, helmSlot, NonKeyInv, makeItem(helmItem, 1))
  putItem(obs, BagInv, makeItem(helmItem, 3))
  doAssert equipAction(toPercept(obs)) == -1
  var mind = newMind(0, 0)
  discard mind.act(obs, 6)
  doAssert mind.armorIssued == 0
  doAssert not mind.pendingArmor[helmSlot].active

block combatPriority:
  var obs = occupiedArmor(helmItem)
  obs[scalarsOffset + scalarInCombat] = char(1)
  putEnemy(obs, centerRow + 1, centerCol)
  var mind = newMind(0, 0)
  doAssert mind.act(obs, 8) == attackAction
  doAssert mind.armorIssued == 0
  doAssert not mind.pendingArmor[helmSlot].active

block healPriority:
  var obs = occupiedArmor(helmItem, wornInv = 1, bagInv = 2)
  putItem(obs, HerbInv, makeItem(herbItem, 1))
  obs[scalarsOffset + scalarHealth] = char(LowHealth)
  var mind = newMind(0, 0)
  doAssert mind.act(obs, 9) == oneAction + HerbInv
  doAssert mind.armorIssued == 0
  doAssert not mind.pendingArmor[helmSlot].active

block resetClearsPending:
  var mind = newMind(0, 1)
  doAssert mind.act(occupiedArmor(helmItem), 10) == oneAction + WornInv
  doAssert mind.pendingArmor[helmSlot].active
  doAssert mind.armorIssued == 1
  mind.reset()
  doAssert mind.generation == 1
  doAssert not mind.pendingArmor[helmSlot].active
  doAssert mind.armorIssued == 1
  discard mind.act(wornUpgrade(helmItem), 11)
  doAssert mind.armorConfirmed == 0
  doAssert mind.wireTick == 11

block defaultTick:
  var mind = newMind(0, 0)
  doAssert mind.act(occupiedArmor(legsItem)) == oneAction + WornInv
  doAssert mind.wireTick == -1
  doAssert mind.armorIssued == 1

echo "ok armor upgrade isolation"
