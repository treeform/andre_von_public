## Buyan — nmmo policy for Andre von Auto.
## A command player speaking wire protocol v2 (docs/protocol_player.md):
##   server -> {"tick": t, "obs": ["<base64 1707B>", ...], "resets": [...]}
##   player -> {"tick": t, "actions": [[a], ... one int per agent]}
##   server -> {"done": true, "result": {...}} then close.
## This is a Nim port of the upstream repo's scripted survival bot
## (players/scripted_player.py @ 96d4ce5a, "daveey's league entry"): a
## per-agent finite-state machine over the egocentric 11x15 tile window
## and the 47 self scalars. Ground truth for every constant is the
## vendored upstream source, nmmo3.h (citations kept from the original).
##
## Observation trust model: tile bytes 0-3 (terrain, ground item) are
## reliable; entity bytes 4-9 are STALE-PRONE and the staleness is
## window-relative (the imprint follows the agent around). The bot keeps
## a liveness map from consecutive-obs diffs: a changed cell was
## necessarily rewritten this tick, so an entity is there right now.
## The decaying trust map is shifted by our own movement (the fresh anim
## scalar proves whether the last move/run landed); while the fresh
## in_combat scalar says someone is hitting us, adjacent imprints are
## trusted regardless; a killed enemy's imprint freezes on ANIM_DEATH
## and is never a target; a missed attack (in_combat still 0) zeroes
## the target cell's liveness, and an attack-streak cap backstops it.
##
## Behavior priority: exit foreign market UI modes; finish our own
## inventory-dump sale; eat a herb when low; fight adjacent beatable
## (delta-comb 0) live enemies — started rested, fought out; grab
## dropped tools before they despawn; RUN from live enemies we are not
## fighting; equip best tool + armor (never gems); harvest tool
## upgrades, prof-leveling resources, then herb stock; threat-biased
## persistent wander against the 500-tick stagnation reset.
##
## Deterministic: pure function of (obs history, per-agent splitmix64
## RNG seeded from COGAME_PLAYER_SEED, agent index, life generation).
## On a resets[j] flag the agent's mind restarts from scratch.

import
  std/[base64, json, options, os],
  whisky

## Obs layout (compute_all_obs, nmmo3.h:926-1020)

const
  windowRows = 11
  windowCols = 15
  tileBytes = 10
  centerRow = 5
  centerCol = 7
  numScalars = 47
  scalarsOffset = windowRows * windowCols * tileBytes   # 1650
  observationSize = scalarsOffset + numScalars + 10     # 1707

## Tile-cell byte indices (nmmo3.h:948-973)

const
  terrainByte = 1        ## terrain / 4: 0 grass, 1 dirt, 2 stone, 3 water
  itemTypeByte = 2       ## item id mod 17 (0 = empty)
  itemTierByte = 3       ## item id div 17 (tier - 1)
  entityTypeByte = 4     ## stale-prone from here down
  entityDeltaByte = 6    ## clamp((seen comb - my comb) / 2, 0, 4)
  entityHealthByte = 7   ## hp / 20
  entityAnimByte = 8

const
  grassTerrain = 0
  dirtTerrain = 1

## Self-scalar offsets within the 47 (nmmo3.h:980-1006)

const
  scalarCombatLevel = 1
  scalarAnim = 4
  scalarHealth = 5
  scalarProfessionLevel = 7
  scalarUiMode = 8
  scalarInCombat = 12
  scalarEquipment = 13     ## 5 slots: helm, chest, legs, held, gem
  scalarInventory = 18     ## 12 slots of raw item ids
  scalarIsEquipped = 30    ## 12 parallel bools

const
  inventorySlots = 12
  numKeySlots = 9          ## only ATN_ONE..ATN_NINE exist: slots 0-8

## Equipment slot indices (nmmo3.h:152-156)

const
  helmSlot = 0
  chestSlot = 1
  legsSlot = 2
  heldSlot = 3

## Actions (nmmo3.h:46-70)

const
  downAction = 0
  upAction = 1
  rightAction = 2
  leftAction = 3
  noopAction = 4
  attackAction = 5
  oneAction = 8            ## use/select inventory slot 0; ..NINE = slot 8
  nineAction = 16
  sellAction = 21
  runOffset = 22           ## run ids are the move ids shifted by this

const moveActions = [downAction, upAction, rightAction, leftAction]

proc moveDelta(action: int): (int, int) =
  ## DELTAS (nmmo3.h:856): action -> (dr, dc).
  case action
  of downAction: (1, 0)
  of upAction: (-1, 0)
  of rightAction: (0, 1)
  else: (0, -1)

proc isWalk(action: int): bool =
  action >= downAction and action <= leftAction

proc isRun(action: int): bool =
  action - runOffset >= downAction and action - runOffset <= leftAction

## Animations (nmmo3.h:37-43)

const
  idleAnim = 0
  moveAnim = 1
  deathAnim = 5
  runAnim = 6

## UI modes (nmmo3.h:30-34)

const
  playMode = 0
  sellSelectMode = 3
  sellPriceMode = 4

const enemyEntity = 2      ## entity types (nmmo3.h:73-75)

## Item types (nmmo3.h:130-147)

const
  helmItem = 1
  chestItem = 2
  legsItem = 3
  toolItem = 6
  gemItems = [7, 8, 9, 10]
  herbItem = 11
  oreItem = 12
  woodItem = 13
  hiltItem = 14
  itemTypeCount = 17

proc armorSlotFor(itemKind: int): int =
  ## Armor item type -> equipment slot; -1 for non-armor.
  case itemKind
  of helmItem: helmSlot
  of chestItem: chestSlot
  of legsItem: legsSlot
  else: -1

proc tierLevel(tier: int): float =
  ## Level equivalent of an item tier (nmmo3.h:884): 8 * 2^(tier-1).
  ## A harvest levels prof while prof < tierLevel(resource tier).
  8.0 * float(1 shl (tier - 1))

proc itemKind(itemId: int): int =
  itemId mod itemTypeCount     ## 0 = empty slot

proc itemTier(itemId: int): int =
  itemId div itemTypeCount + 1

## Behavior thresholds (same values as the Python original)

const
  healHealth = 45          ## eat a herb below this (herb restores >= 60)
  fightStartHealth = 95    ## only START a full-hp-enemy fight rested
  fightWoundedHealth = 60  ## cheap kills: start on a wounded enemy at 60+
  fightKeepHealth = 25     ## once committed, fight it out
  toolGrabDistance = 3     ## tools despawn in 20 ticks — worth a hit
  herbStock = 2            ## keep this many herbs in inventory
  avoidRadius = 5          ## keep stronger-enemy hints outside this ring
  attackStreakMax = 8      ## longer than any real kill = ghost
  liveTtl = 3              ## ticks a changed entity cell stays trusted

## Wire constants

const
  connectAttempts = 240    ## initial dial: 240 x 500 ms = 2 minutes
  connectRetryMs = 500
  reconnectAttempts = 5

## Deterministic RNG (splitmix64) — any deterministic stream works here;
## the Python original used numpy PCG64, this port uses splitmix64.

type WanderRng = object
  state: uint64

proc initWanderRng(seed, agentIndex, generation: int): WanderRng =
  WanderRng(state: uint64(seed) * 0x9E3779B97F4A7C15'u64 xor
                   uint64(agentIndex + 1) * 0xBF58476D1CE4E5B9'u64 xor
                   uint64(generation + 1) * 0x94D049BB133111EB'u64)

proc next(rng: var WanderRng): uint64 =
  rng.state = rng.state + 0x9E3779B97F4A7C15'u64
  var z = rng.state
  z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9'u64
  z = (z xor (z shr 27)) * 0x94D049BB133111EB'u64
  z xor (z shr 31)

proc below(rng: var WanderRng, n: int): int =
  int(rng.next() mod uint64(n))

proc between(rng: var WanderRng, a, b: int): int =
  ## Uniform in [a, b), like numpy's integers.
  a + rng.below(b - a)

## Perception

type Percept = object
  data: seq[uint8]         ## the raw 1707 bytes

proc tileByte(p: Percept, r, c, b: int): int =
  int(p.data[(r * windowCols + c) * tileBytes + b])

proc scalar(p: Percept, i: int): int =
  int(p.data[scalarsOffset + i])

proc health(p: Percept): int = p.scalar(scalarHealth)
proc combatLevel(p: Percept): int = p.scalar(scalarCombatLevel)
proc professionLevel(p: Percept): int = p.scalar(scalarProfessionLevel)
proc uiMode(p: Percept): int = p.scalar(scalarUiMode)
proc anim(p: Percept): int = p.scalar(scalarAnim)
proc inCombat(p: Percept): bool = p.scalar(scalarInCombat) > 0

proc inventorySlot(p: Percept, i: int): int =
  p.scalar(scalarInventory + i)

proc isEquipped(p: Percept, i: int): bool =
  p.scalar(scalarIsEquipped + i) != 0

proc equipmentSlot(p: Percept, slot: int): int =
  p.scalar(scalarEquipment + slot)

proc inventoryFull(p: Percept): bool =
  for i in 0 ..< inventorySlots:
    if p.inventorySlot(i) == 0:
      return false
  true

proc heldToolTier(p: Percept): int =
  ## Tier of the held tool, 0 when the held slot is empty or holds a
  ## non-tool (nothing can be harvested then except loose tools).
  let held = p.equipmentSlot(heldSlot)
  if held != 0 and itemKind(held) == toolItem:
    itemTier(held)
  else:
    0

proc passable(p: Percept, r, c: int): bool =
  ## Terrain passability (PASSABLE, nmmo3.h:895: grass/dirt yes,
  ## stone/water no). Window coords; out-of-window counts blocked.
  if r < 0 or r >= windowRows or c < 0 or c >= windowCols:
    return false
  p.tileByte(r, c, terrainByte) in [grassTerrain, dirtTerrain]

type EnemyHint = object
  r, c: int
  deltaCombat: int         ## 0 means at most one level above us
  healthBucket: int        ## hp / 20

proc enemyHints(p: Percept): seq[EnemyHint] =
  ## Window tiles whose STALE-PRONE entity bytes claim an enemy. Hints
  ## only. Corpse imprints (anim frozen on ANIM_DEATH) filtered here;
  ## departed ghosts need the mind's liveness map.
  for r in 0 ..< windowRows:
    for c in 0 ..< windowCols:
      if p.tileByte(r, c, entityTypeByte) != enemyEntity:
        continue
      if p.tileByte(r, c, entityAnimByte) == deathAnim:
        continue
      result.add(EnemyHint(r: r, c: c,
                           deltaCombat: p.tileByte(r, c, entityDeltaByte),
                           healthBucket: p.tileByte(r, c, entityHealthByte)))

type ItemTile = object
  r, c: int
  kind: int                ## I_* item type
  tier: int

proc itemTiles(p: Percept): seq[ItemTile] =
  ## Every visible ground item (tile bytes 2-3, the reliable half),
  ## excluding our own tile (pickup already ran when we stepped on it).
  for r in 0 ..< windowRows:
    for c in 0 ..< windowCols:
      if r == centerRow and c == centerCol:
        continue
      let kind = p.tileByte(r, c, itemTypeByte)
      if kind != 0:
        result.add(ItemTile(r: r, c: c, kind: kind,
                            tier: p.tileByte(r, c, itemTierByte) + 1))

## Per-agent mind

type Mind = ref object
  seed: int
  agentIndex: int
  generation: int
  rng: WanderRng
  wanderAction: int
  wanderLeft: int
  lastAction: int
  selling: bool
  hasPrev: bool
  prevTiles: array[windowRows * windowCols * tileBytes, uint8]
  live: array[windowRows * windowCols, int8]
  hasLastAttack: bool
  lastAttackPos: (int, int)
  attackStreak: int
  wireTick: int            ## last actual wire tick, or local step
  restPending: bool        ## last issued action was recovery NOOP
  restHealth: int          ## health when recovery NOOP issued
  restIssued: int          ## changed actual wire recovery count

proc reset(mind: Mind) =
  ## Rebuilt from scratch on a respawn reset: the new life has fresh
  ## levels and a fresh location. The generation counter keeps a
  ## respawned life from replaying the previous life's wander stream.
  inc mind.generation
  mind.rng = initWanderRng(mind.seed, mind.agentIndex, mind.generation)
  mind.wanderAction = downAction
  mind.wanderLeft = 0
  mind.lastAction = noopAction
  mind.selling = false
  mind.hasPrev = false
  for i in 0 ..< mind.live.len:
    mind.live[i] = 0
  mind.hasLastAttack = false
  mind.attackStreak = 0
  mind.wireTick = -1
  mind.restPending = false
  mind.restHealth = 0
  ## restIssued is process-wide evidence, not per-life policy memory.

proc newMind(seed, agentIndex: int): Mind =
  result = Mind(seed: seed, agentIndex: agentIndex, generation: -1)
  result.reset()

proc copyMind(src: Mind): Mind =
  ## Clone mind fields for a silent baseline decide (no live RNG use).
  new result
  result[] = src[]

when defined(buyanTest):
  var refugeEvents: seq[JsonNode]

## Liveness bookkeeping

proc ownShift(mind: Mind, p: Percept): (int, int) =
  ## How far the window slid since last tick, from fresh signals: the
  ## anim scalar proves whether the last move/run succeeded (and at
  ## which speed), the remembered action gives the direction.
  var walk = mind.lastAction
  if isRun(walk):
    walk -= runOffset
  if not isWalk(walk):
    return (0, 0)
  let (dr, dc) = moveDelta(walk)
  if p.anim == moveAnim:
    (dr, dc)
  elif p.anim == runAnim:
    (2 * dr, 2 * dc)
  else:
    (0, 0)

proc updateLiveness(mind: Mind, p: Percept) =
  ## Decay-and-shift the trust map by our own movement, then re-arm
  ## every cell whose entity bytes changed at the SAME window offset —
  ## such a cell was necessarily rewritten this tick.
  if not mind.hasPrev:
    for i in 0 ..< mind.live.len:
      mind.live[i] = 0
    for i in 0 ..< mind.prevTiles.len:
      mind.prevTiles[i] = p.data[i]
    mind.hasPrev = true
    return
  let (dr, dc) = mind.ownShift(p)
  var shifted: array[windowRows * windowCols, int8]
  for r in 0 ..< windowRows:
    for c in 0 ..< windowCols:
      let sr = r + dr
      let sc = c + dc
      if sr >= 0 and sr < windowRows and sc >= 0 and sc < windowCols:
        shifted[r * windowCols + c] = mind.live[sr * windowCols + sc]
  for r in 0 ..< windowRows:
    for c in 0 ..< windowCols:
      let base = (r * windowCols + c) * tileBytes
      var changed = false
      for b in entityTypeByte ..< tileBytes:
        if p.data[base + b] != mind.prevTiles[base + b]:
          changed = true
          break
      mind.live[r * windowCols + c] =
        if changed: int8(liveTtl)
        else: max(shifted[r * windowCols + c] - 1, 0).int8
  for i in 0 ..< mind.prevTiles.len:
    mind.prevTiles[i] = p.data[i]

proc liveHints(mind: Mind, p: Percept): seq[EnemyHint] =
  ## Enemy hints on LIVE cells only. While the fresh in_combat scalar
  ## says someone is hitting us, imprints in attack position (adjacent,
  ## or on-axis within bow range 4) are trusted even if static.
  for hint in p.enemyHints():
    if mind.live[hint.r * windowCols + hint.c] <= 0:
      if not p.inCombat:
        continue
      let ar = abs(hint.r - centerRow)
      let ac = abs(hint.c - centerCol)
      let inAttackPosition = max(ar, ac) <= 1 or
        (min(ar, ac) == 0 and max(ar, ac) <= 4)
      if not inAttackPosition:
        continue
    result.add(hint)

proc threats(mind: Mind, p: Percept): seq[(int, int)] =
  ## Cells hinting a stronger enemy (delta >= 1: two or more combat
  ## levels above us) close enough to matter for avoidance.
  for hint in mind.liveHints(p):
    if hint.deltaCombat >= 1 and
        max(abs(hint.r - centerRow), abs(hint.c - centerCol)) <= avoidRadius:
      result.add((hint.r, hint.c))

proc threatDistance(r, c: int, threatCells: seq[(int, int)]): int =
  result = high(int)
  for (tr, tc) in threatCells:
    result = min(result, max(abs(r - tr), abs(c - tc)))

proc passableMoves(p: Percept, avoid = -1): seq[int] =
  for action in moveActions:
    if action == avoid:
      continue
    let (dr, dc) = moveDelta(action)
    if p.passable(centerRow + dr, centerCol + dc):
      result.add(action)

proc safeMoves(p: Percept, threatCells: seq[(int, int)],
               avoid = -1): seq[int] =
  ## Passable moves that never decrease the min chebyshev distance to a
  ## nearby stronger-enemy hint; falls back to all passable moves.
  let moves = passableMoves(p, avoid)
  if threatCells.len == 0 or moves.len == 0:
    return moves
  let here = threatDistance(centerRow, centerCol, threatCells)
  for action in moves:
    let (dr, dc) = moveDelta(action)
    if threatDistance(centerRow + dr, centerCol + dc, threatCells) >= here:
      result.add(action)
  if result.len == 0:
    result = moves

proc maybeRun(p: Percept, action: int): int =
  ## Upgrade a walk to a run (2 tiles) when both tiles are clear — the
  ## only way to break a melee chase (walkers and chasers move at the
  ## same speed).
  if not isWalk(action):
    return action
  let (dr, dc) = moveDelta(action)
  if p.passable(centerRow + dr, centerCol + dc) and
      p.passable(centerRow + 2 * dr, centerCol + 2 * dc):
    action + runOffset
  else:
    action

proc lastMoveBlocked(mind: Mind, p: Percept): bool =
  ## Did last tick's move/run fail? c_step sets anim=IDLE every tick
  ## and move() sets MOVE/RUN only on success — always fresh.
  (isWalk(mind.lastAction) or isRun(mind.lastAction)) and p.anim == idleAnim

proc wander(mind: Mind, p: Percept, threatCells: seq[(int, int)]): int =
  ## Persistent-direction random walk-or-run (anti-stagnation coverage),
  ## biased away from stronger-enemy hints.
  let blockedLast = mind.lastMoveBlocked(p)
  let options = safeMoves(p, threatCells,
                          if blockedLast: mind.wanderAction else: -1)
  if mind.wanderLeft <= 0 or blockedLast or
      mind.wanderAction notin options:
    if options.len == 0:
      return noopAction    # fully boxed in; wait for teleportitis
    mind.wanderAction = options[mind.rng.below(options.len)]
    mind.wanderLeft = mind.rng.between(6, 15)
  dec mind.wanderLeft
  maybeRun(p, mind.wanderAction)

proc stepTowards(mind: Mind, p: Percept, threatCells: seq[(int, int)],
                 r, c: int): int =
  ## One greedy step (run when 2+ tiles remain on the axis) toward
  ## window tile (r, c): larger-|delta| axis first, other axis when
  ## blocked/unsafe, -1 when neither works.
  let dr = r - centerRow
  let dc = c - centerCol
  var preferences: seq[int]
  let rowAction = if dr > 0: downAction else: upAction
  let colAction = if dc > 0: rightAction else: leftAction
  if abs(dr) >= abs(dc):
    if dr != 0:
      preferences.add(rowAction)
    if dc != 0:
      preferences.add(colAction)
  else:
    preferences.add(colAction)
    if dr != 0:
      preferences.add(rowAction)
  # last tick's exact move failed (occupied tile, most likely a
  # stale-invisible entity): demote it so we route around
  if mind.lastAction in preferences and mind.lastMoveBlocked(p) and
      preferences.len > 1:
    let keep = mind.lastAction
    var trimmed: seq[int]
    for action in preferences:
      if action != keep:
        trimmed.add(action)
    preferences = trimmed
  let allowed = safeMoves(p, threatCells)
  for action in preferences:
    if action in allowed:
      let axisDistance =
        if action == downAction or action == upAction: abs(dr)
        else: abs(dc)
      if axisDistance >= 2:
        return maybeRun(p, action)
      return action
  -1

proc herbSlot(p: Percept): int =
  for i in 0 ..< numKeySlots:
    let item = p.inventorySlot(i)
    if item != 0 and itemKind(item) == herbItem:
      return i
  -1

proc bestSlotOfType(p: Percept, kind: int): int =
  result = -1
  for i in 0 ..< numKeySlots:
    let item = p.inventorySlot(i)
    if item != 0 and itemKind(item) == kind and not p.isEquipped(i):
      if result < 0 or itemTier(item) > itemTier(p.inventorySlot(result)):
        result = i

proc equipAction(p: Percept): int =
  ## One equip/unequip keypress toward the target loadout: best tool
  ## held, best armor in every armor slot; -1 when nothing to do.
  ## Multi-step upgrades emerge one keypress per tick because this is
  ## re-derived from fresh scalars every tick. Gems are never equipped.
  let bestTool = bestSlotOfType(p, toolItem)
  let held = p.equipmentSlot(heldSlot)
  if held == 0:
    if bestTool >= 0:
      return oneAction + bestTool
  elif itemKind(held) == toolItem:
    if bestTool >= 0 and
        itemTier(p.inventorySlot(bestTool)) > itemTier(held):
      # unequip the current tool first (slot must be empty to equip,
      # use_item nmmo3.h:1544); find its inventory key
      for i in 0 ..< numKeySlots:
        if p.isEquipped(i) and p.inventorySlot(i) == held:
          return oneAction + i
  else:
    # a non-tool ended up held (e.g. picked-up sword auto-kept):
    # unequip it to make room for a tool
    if bestTool >= 0:
      for i in 0 ..< numKeySlots:
        if p.isEquipped(i) and p.inventorySlot(i) == held:
          return oneAction + i
  for armorKind in [helmItem, chestItem, legsItem]:
    if p.equipmentSlot(armorSlotFor(armorKind)) == 0:
      let slot = bestSlotOfType(p, armorKind)
      if slot >= 0:
        return oneAction + slot
  -1

proc junkSlot(p: Percept): int =
  ## Lowest-tier expendable slot for an inventory dump: not equipped,
  ## not a herb, not our best tool, not armor an empty slot is waiting
  ## for. Key-addressable slots only; -1 when nothing qualifies.
  var bestToolTier = 0
  for i in 0 ..< inventorySlots:
    let item = p.inventorySlot(i)
    if item != 0 and itemKind(item) == toolItem:
      bestToolTier = max(bestToolTier, itemTier(item))
  result = -1
  var bestKey = (0, 0)
  for i in 0 ..< numKeySlots:
    let item = p.inventorySlot(i)
    if item == 0 or p.isEquipped(i):
      continue
    let kind = itemKind(item)
    if kind == herbItem:
      continue
    if kind == toolItem and itemTier(item) >= bestToolTier:
      continue
    let armorSlot = armorSlotFor(kind)
    if armorSlot >= 0 and p.equipmentSlot(armorSlot) == 0:
      continue
    let key = (itemTier(item), i)
    if result < 0 or key < bestKey:
      result = i
      bestKey = key

proc harvestTarget(p: Percept): (int, int) =
  ## Best visible item tile to walk onto, or (-1, -1). Ranked by
  ## (priority, manhattan distance): tool upgrades, then prof-leveling
  ## resources, then herb stock.
  let heldTier = p.heldToolTier()
  var herbsHeld = 0
  for i in 0 ..< inventorySlots:
    let item = p.inventorySlot(i)
    if item != 0 and itemKind(item) == herbItem:
      inc herbsHeld
  let full = p.inventoryFull()
  result = (-1, -1)
  var bestKey = (0, 0)
  var found = false
  for tileInfo in p.itemTiles():
    var priority: int
    if tileInfo.kind == toolItem:
      # tools are picked up bare-handed (nmmo3.h:1148)
      if tileInfo.tier <= heldTier:
        continue
      priority = 0
    elif tileInfo.kind in [oreItem, woodItem, hiltItem, herbItem] or
        tileInfo.kind in gemItems:
      if tileInfo.tier > heldTier:
        continue  # our tool cannot harvest it
      if float(p.professionLevel()) < tierLevel(tileInfo.tier):
        priority = 1  # levels prof — the main objective
      elif tileInfo.kind == herbItem and herbsHeld < herbStock:
        priority = 2
      else:
        continue  # no value; do not fill inventory with it
    else:
      continue  # not a ground-harvestable type
    if full:
      continue  # pickup would fail; the dump handles this
    let distance = abs(tileInfo.r - centerRow) + abs(tileInfo.c - centerCol)
    let key = (priority, distance)
    if not found or key < bestKey:
      result = (tileInfo.r, tileInfo.c)
      bestKey = key
      found = true

## The FSM

const refugeChebyshev = 4  ## rest only with no live enemy this close

proc liveEnemyWithin(mind: Mind, p: Percept, radius: int): bool =
  ## True if any live (non-corpse) enemy imprint is within Chebyshev.
  for hint in mind.liveHints(p):
    if max(abs(hint.r - centerRow), abs(hint.c - centerCol)) <= radius:
      return true

proc emitRefugeJson(node: JsonNode) =
  ## Bounded stdout JSON; tests capture a copy.
  when defined(buyanTest):
    refugeEvents.add(node)
  echo $node

proc logRefugeHp(mind: Mind, health, delta: int) =
  ## Subsequent HP after a recovery NOOP. Not an issuance count.
  emitRefugeJson(%*{
    "experiment": "refuge",
    "event": "refuge_hp",
    "tick": mind.wireTick,
    "agent": mind.agentIndex,
    "generation": mind.generation,
    "health": health,
    "priorHealth": mind.restHealth,
    "hpDelta": delta
  })

proc logStrategyAction(mind: Mind, action, baselineAction: int) =
  ## Counted only when the actual wire action differs from baseline.
  emitRefugeJson(%*{
    "experiment": "refuge",
    "event": "strategy_action",
    "tick": mind.wireTick,
    "agent": mind.agentIndex,
    "action": action,
    "baselineAction": baselineAction,
    "generation": mind.generation
  })

proc decide(mind: Mind, p: Percept, refugeEnabled = true): int =
  let threatCells = mind.threats(p)

  # 1/2. Market UI handling. Sell mode we initiated: finish the dump
  # (select the junk slot, then price at the max key). Any other mode:
  # exit with a movement action — it leaves the mode without buying or
  # selling and without moving (c_step nmmo3.h:1989-2105).
  if p.uiMode != playMode:
    if mind.selling and not p.inCombat:
      if p.uiMode == sellSelectMode:
        let junk = junkSlot(p)
        if junk >= 0:
          return oneAction + junk
      elif p.uiMode == sellPriceMode:
        mind.selling = false
        return nineAction  # price 9, top of the key range
    mind.selling = false
    return mind.wander(p, threatCells)
  mind.selling = false

  # 3. Heal: herbs work in combat and restore >= 60 hp.
  if p.health < healHealth:
    let herb = herbSlot(p)
    if herb >= 0:
      return oneAction + herb

  # 4. Fight: ATN_ATTACK auto-targets any enemy on the 4-adjacent
  # tiles regardless of facing. delta==0 <=> at most one comb level
  # above us — beatable, and the only kind whose kill levels comb (and
  # drops the tool that unlocks all harvesting). Fights START rested
  # (or cheaply, on a wounded enemy) but are then fought OUT — aborting
  # refunds nothing. The streak cap turns a suspiciously long "fight"
  # into a dead cell so a stale imprint can never pin us to a tile.
  for hint in mind.liveHints(p):
    if hint.deltaCombat != 0:
      continue
    if abs(hint.r - centerRow) + abs(hint.c - centerCol) != 1:
      continue
    let startRested = p.health >= fightStartHealth
    let startCheap = hint.healthBucket <= 2 and p.health >= fightWoundedHealth
    let keepGoing = mind.attackStreak > 0 and p.health >= fightKeepHealth
    if not (startRested or startCheap or keepGoing):
      continue
    if mind.attackStreak >= attackStreakMax:
      mind.live[hint.r * windowCols + hint.c] = 0
      continue
    mind.lastAttackPos = (hint.r, hint.c)
    mind.hasLastAttack = true
    return attackAction

  # 5. Tool grab: dropped tools despawn after 20 ticks, and a held tool
  # gates ALL harvesting — a nearby upgrade outranks the disengage rule.
  let heldTier = p.heldToolTier()
  var bestToolDistance = high(int)
  var bestToolCell = (-1, -1)
  for tileInfo in p.itemTiles():
    if tileInfo.kind != toolItem or tileInfo.tier <= heldTier:
      continue
    let distance = abs(tileInfo.r - centerRow) + abs(tileInfo.c - centerCol)
    if distance < bestToolDistance or
        (distance == bestToolDistance and
         (tileInfo.r, tileInfo.c) < bestToolCell):
      bestToolDistance = distance
      bestToolCell = (tileInfo.r, tileInfo.c)
  if bestToolCell[0] >= 0 and not p.inventoryFull() and
      bestToolDistance <= toolGrabDistance:
    let step = mind.stepTowards(p, @[], bestToolCell[0], bestToolCell[1])
    if step >= 0:
      return step

  # 6. Disengage: EVERY enemy chases any player inside its aggro range
  # (enemy_ai, nmmo3.h:1572-1637), so lingering near a live hint we are
  # not fighting means eating hits. RUN away (2 tiles/tick; chasers
  # walk) — stronger enemies (delta >= 1, possibly ranged) get the
  # wider berth.
  var closeCells: seq[(int, int)]
  for hint in mind.liveHints(p):
    let berth = if hint.deltaCombat >= 1: 4 else: 2
    if max(abs(hint.r - centerRow), abs(hint.c - centerCol)) <= berth:
      closeCells.add((hint.r, hint.c))
  if closeCells.len > 0:
    let moves = passableMoves(p)
    if moves.len > 0:
      var bestAction = moves[0]
      var bestScore = (low(int), low(int))
      for action in moves:
        let (dr, dc) = moveDelta(action)
        let nr = centerRow + dr
        let nc = centerCol + dc
        # bows shoot only along axes: breaking row/col alignment
        # dodges ranged fire
        var aligned = 0
        for (tr, tc) in closeCells:
          if nr == tr or nc == tc:
            inc aligned
        let score = (threatDistance(nr, nc, closeCells), -aligned)
        if score > bestScore:
          bestScore = score
          bestAction = action
      return maybeRun(p, bestAction)

  # 7. Equip upgrades (blocked while in combat, use_item nmmo3.h:1474;
  # herbs above are exempt from that check).
  if not p.inCombat:
    let equip = equipAction(p)
    if equip >= 0:
      return equip

  # 8. Harvest / gear collection (move-onto-tile).
  let target = harvestTarget(p)
  if target[0] >= 0:
    let step = mind.stepTowards(p, threatCells, target[0], target[1])
    if step >= 0:
      return step
  elif p.inventoryFull() and not p.inCombat and junkSlot(p) >= 0:
    # inventory full (pickup_item drops out on a full inventory,
    # nmmo3.h:1139-1142) and we hold expendable junk: start a market
    # dump to free a slot (3-tick sell flow handled in step 2 above)
    mind.selling = true
    return sellAction

  # 9. Anti-stagnation wander (threat-biased), or recovery NOOP while
  # injured, out of combat, and no live enemy within Chebyshev 4.
  if refugeEnabled and p.health < fightStartHealth and not p.inCombat and
      not mind.liveEnemyWithin(p, refugeChebyshev):
    return noopAction
  mind.wander(p, threatCells)

proc act(mind: Mind, observation: string, tick = -1): int =
  ## Decide one action; tick is the actual wire tick when provided.
  if observation.len != observationSize:
    return noopAction     ## malformed row: no-op, never crash
  var p = Percept(data: newSeq[uint8](observationSize))
  for i in 0 ..< observationSize:
    p.data[i] = observation[i].uint8

  mind.wireTick =
    if tick >= 0:
      tick
    else:
      mind.wireTick + 1

  if mind.restPending:
    logRefugeHp(mind, p.health, p.health - mind.restHealth)
    mind.restPending = false

  mind.updateLiveness(p)
  # hit feedback: a missed attack proves the targeted cell was a stale
  # imprint — kill its liveness now
  if mind.lastAction == attackAction and not p.inCombat and
      mind.hasLastAttack:
    mind.live[mind.lastAttackPos[0] * windowCols +
              mind.lastAttackPos[1]] = 0

  let snapshot = copyMind(mind)
  let baselineAction = snapshot.decide(p, false)
  let action = mind.decide(p, true)
  if action != baselineAction:
    inc mind.restIssued
    logStrategyAction(mind, action, baselineAction)
  if action == noopAction and action != baselineAction:
    mind.restPending = true
    mind.restHealth = p.health
  else:
    mind.restPending = false

  if action == attackAction:
    inc mind.attackStreak
  else:
    mind.attackStreak = 0
    mind.hasLastAttack = false
  mind.lastAction = action
  action

## Wire loop (docs/protocol_player.md, protocol v2): lockstep JSON with
## bounded reconnects — a connection that answered at least one tick
## resets the failure budget, mirroring the upstream players/client.py.

proc main() =
  let url = getEnv("COWORLD_PLAYER_WS_URL",
                   getEnv("COGAMES_ENGINE_WS_URL"))
  if url == "":
    quit("buyan: COWORLD_PLAYER_WS_URL is not set", 1)
  var seed = 0
  try:
    let raw = getEnv("COGAME_PLAYER_SEED")
    if raw.len > 0:
      seed = parseJson(raw).getInt()
  except CatchableError:
    discard
  var minds: seq[Mind]

  var attemptsLeft = connectAttempts
  var failures = 0
  var everConnected = false
  while true:
    var socket: WebSocket
    try:
      socket = newWebSocket(url)
    except CatchableError:
      if not everConnected:
        dec attemptsLeft
        if attemptsLeft <= 0:
          quit("buyan: game never accepted a connection", 1)
      else:
        inc failures
        if failures >= reconnectAttempts:
          quit("buyan: reconnect budget exhausted", 1)
      sleep(connectRetryMs)
      continue
    if not everConnected:
      echo "buyan: connected"
    everConnected = true

    var answered = 0
    try:
      while true:
        let received = socket.receiveMessage()
        if received.isNone:
          continue
        let message = received.get()
        if message.kind == Ping:
          socket.send(message.data, Pong)
          continue
        if message.kind != TextMessage:
          continue
        var parsed: JsonNode
        try:
          parsed = parseJson(message.data)
        except CatchableError:
          continue
        if parsed{"done"}.getBool(false):
          echo "buyan: episode done, result ", parsed{"result"}
          quit(0)
        if not parsed.hasKey("tick") or not parsed.hasKey("obs"):
          continue
        let
          tick = parsed["tick"].getInt()
          rows = parsed["obs"].getElems()
          resets = parsed{"resets"}.getElems()
        var actions = newJArray()
        for i, row in rows:
          while minds.len <= i:
            minds.add(newMind(seed, minds.len))
          if i < resets.len and resets[i].getBool(false):
            minds[i].reset()   # new life: fresh levels, fresh location
          var actionRow = newJArray()
          actionRow.add(%minds[i].act(decode(row.getStr()), tick))
          actions.add(actionRow)
        socket.send($(%*{"tick": parsed["tick"], "actions": actions}))
        inc answered
    except CatchableError:
      echo "buyan: socket closed (", getCurrentExceptionMsg(), ")"
    if answered > 0:
      failures = 0     # made progress: fresh reconnect budget
    inc failures
    if failures >= reconnectAttempts:
      quit("buyan: connection closed before done, budget exhausted", 1)
    sleep(connectRetryMs)

when not defined(buyanTest):
  main()
