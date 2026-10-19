include candidate

const
  SafeHealth = 99
  WireTick = 41
  AgentIdx = 3
  OreR = centerRow
  OreC = centerCol + 1
  WoodR = centerRow
  WoodC = centerCol + 3
  ToolR = centerRow + 1
  ToolC = centerCol

proc makeItem(kind, tier: int): int =
  ## Encode a wire item id from kind and one-based tier.
  (tier - 1) * itemTypeCount + kind

proc blankObs(): string =
  ## All-grass window, idle, healthy, empty inventory.
  result = newString(observationSize)
  result[scalarsOffset + scalarHealth] = char(SafeHealth)
  result[scalarsOffset + scalarCombatLevel] = char(1)

proc toPercept(obs: string): Percept =
  ## Copy observation bytes into a Percept.
  result.data = newSeq[uint8](obs.len)
  for i in 0 ..< obs.len:
    result.data[i] = obs[i].uint8

proc toObs(p: Percept): string =
  ## Encode a percept as a raw-byte observation.
  result = newString(p.data.len)
  for i in 0 ..< p.data.len:
    result[i] = char(p.data[i])

proc putGround(obs: var string; r, c, kind, tier: int) =
  ## Place a ground item at window cell (r, c).
  let base = (r * windowCols + c) * tileBytes
  obs[base + itemTypeByte] = char(kind)
  obs[base + itemTierByte] = char(tier - 1)

proc putHeldTool(obs: var string; tier: int) =
  ## Equip a tool of the given tier in the held slot and inventory 0.
  let item = makeItem(toolItem, tier)
  obs[scalarsOffset + scalarInventory] = char(item)
  obs[scalarsOffset + scalarIsEquipped] = char(1)
  obs[scalarsOffset + scalarEquipment + heldSlot] = char(item)

proc putArmor(obs: var string; helmT, chestT, legsT: int) =
  ## Wear armor of the given one-based tiers; 0 means empty.
  for (slot, kind, t) in [
    (helmSlot, helmItem, helmT),
    (chestSlot, chestItem, chestT),
    (legsSlot, legsItem, legsT)
  ]:
    if t <= 0:
      continue
    let item = makeItem(kind, t)
    let inv = slot + 1
    obs[scalarsOffset + scalarInventory + inv] = char(item)
    obs[scalarsOffset + scalarIsEquipped + inv] = char(1)
    obs[scalarsOffset + scalarEquipment + slot] = char(item)

proc setProf(obs: var string; level: int) =
  ## Write the profession-level scalar.
  obs[scalarsOffset + scalarProfessionLevel] = char(level)

proc cappedMissingArmor(): string =
  ## Profession at tier-1 cap, harvestable ore, empty armor.
  result = blankObs()
  setProf(result, int(tierLevel(1)))
  putHeldTool(result, 1)
  putGround(result, OreR, OreC, oreItem, 1)

proc lastStrategyAction(): JsonNode =
  ## Last strategy_action event captured under -d:buyanTest.
  result = nil
  for node in gearEvents:
    if node{"event"}.getStr() == "strategy_action":
      result = node

block cappedProfessionMissingArmorSelectsOre:
  gearEvents.setLen(0)
  let obs = cappedMissingArmor()
  let p = toPercept(obs)
  doAssert harvestTarget(p) == (OreR, OreC)
  doAssert harvestTarget(p, false) == (-1, -1)
  let mind = newMind(0, AgentIdx)
  let action = mind.act(obs, WireTick)
  doAssert action == rightAction
  doAssert mind.currentTick == WireTick
  doAssert mind.agentIndex == AgentIdx
  doAssert mind.generation == 0
  let ev = lastStrategyAction()
  doAssert ev != nil
  doAssert ev{"event"}.getStr() == "strategy_action"
  doAssert ev{"experiment"}.getStr() == "gear"
  doAssert ev{"tick"}.getInt() == WireTick
  doAssert ev{"agent"}.getInt() == AgentIdx
  doAssert ev{"generation"}.getInt() == 0
  doAssert ev{"action"}.getInt() == action
  doAssert ev{"baselineAction"}.getInt() != action

block sufficientArmorIgnoresCappedOre:
  gearEvents.setLen(0)
  var obs = cappedMissingArmor()
  putArmor(obs, 1, 1, 1)
  let p = toPercept(obs)
  doAssert not p.armorNeedsOre(1)
  doAssert harvestTarget(p) == (-1, -1)
  let mind = newMind(0, AgentIdx)
  discard mind.act(obs, WireTick)
  doAssert lastStrategyAction() == nil
  doAssert mind.currentTick == WireTick

block unharvestableOreIgnored:
  gearEvents.setLen(0)
  var obs = blankObs()
  setProf(obs, int(tierLevel(1)))
  putHeldTool(obs, 1)
  putGround(obs, OreR, OreC, oreItem, 2)
  doAssert harvestTarget(toPercept(obs)) == (-1, -1)
  let mind = newMind(0, AgentIdx)
  discard mind.act(obs, 7)
  doAssert lastStrategyAction() == nil

block armorOreBeforeXpResource:
  var obs = blankObs()
  setProf(obs, 0)
  putHeldTool(obs, 1)
  putGround(obs, WoodR, WoodC, woodItem, 1)
  putGround(obs, centerRow + 4, centerCol, oreItem, 1)
  let p = toPercept(obs)
  doAssert harvestTarget(p) == (centerRow + 4, centerCol)
  doAssert harvestTarget(p, false) == (WoodR, WoodC)

block toolUpgradeBeforeArmorOre:
  var obs = cappedMissingArmor()
  putGround(obs, ToolR, ToolC, toolItem, 2)
  doAssert harvestTarget(toPercept(obs)) == (ToolR, ToolC)

block fullInventorySkipsOre:
  var obs = cappedMissingArmor()
  for i in 0 ..< inventorySlots:
    if obs[scalarsOffset + scalarInventory + i] == char(0):
      obs[scalarsOffset + scalarInventory + i] = char(makeItem(herbItem, 1))
  doAssert harvestTarget(toPercept(obs)) == (-1, -1)

block healStillFirst:
  gearEvents.setLen(0)
  var obs = cappedMissingArmor()
  obs[scalarsOffset + scalarHealth] = char(30)
  obs[scalarsOffset + scalarInventory + 2] = char(makeItem(herbItem, 1))
  let mind = newMind(0, 0)
  doAssert mind.act(obs, 3) == oneAction + 2
  doAssert lastStrategyAction() == nil

block resetClearsPerLifeTick:
  let mind = newMind(1, 2)
  discard mind.act(cappedMissingArmor(), 50)
  doAssert mind.currentTick == 50
  let gen = mind.generation
  mind.reset()
  doAssert mind.generation == gen + 1
  doAssert mind.currentTick == -1
  doAssert mind.attackStreak == 0
  doAssert not mind.hasLastAttack

echo "ok gear isolation"
