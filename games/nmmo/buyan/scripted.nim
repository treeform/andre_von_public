## Scripted decision engine for Buyan, distilled from the pretrained
## MMONet's behaviour on hosted replays (replays_tools/reconstruct/
## behavior_stats.nim over 1.2M argmax decisions) plus the sim rules in
## sims/nmmo/vendor/upstream/nmmo3.h. No weights: rules only.
##
## What the network does, as rules:
## - Fight adjacent enemies at or near its own level (delta byte 0) and
##   finish wounded ones; flee (run, not walk) from enemies four or more
##   levels above, and leave their row/column (bow lanes, level 15+ shoot
##   four tiles along an axis).
## - Approach same-level enemies within a few tiles while healthy; combat
##   levels only come from kills of enemies at or above its own level.
## - Hold a sword between fights (its idle action is a free attack press),
##   switch to a tool to harvest, equip every better armor piece.
## - Harvest resources whose tier levels the profession (8 * 2^(tier-1)
##   must exceed prof) and, with a tier-2 tool, ore/hilt/wood for tier-2
##   armor, swords and bows.
## - Hammer the market: BUY, tier 2, then armor slots or a tool, whenever
##   it has gold and inventory space.
## - Explore in long runs; almost never eat herbs (we do, below 40 hp).
##
## Additions the network cannot have: truthful entity bytes (obs=clean),
## dead-reckoned memory of where strong enemies and useful resources were
## seen, junk selling when the inventory is full (a full inventory blocks
## harvest level-ups), and a stagnation push toward the lagging skill.

import std/[math]

## Observation layout (compute_all_obs, nmmo3.h:926-1020)

const
  Rows = 11
  Cols = 15
  TileBytes = 10
  CenterRow = 5
  CenterCol = 7
  ScalarsOffset = Rows * Cols * TileBytes
  ObservationSize* = ScalarsOffset + 47 + 10

const
  TerrainByte = 1
  ItemTypeByte = 2
  ItemTierByte = 3
  EntityTypeByte = 4
  EntityElementByte = 5
  EntityDeltaByte = 6
  EntityHpByte = 7
  EntityAnimByte = 8

const
  ScalarComb = 1
  ScalarAnim = 4
  ScalarHp = 5
  ScalarHpMax = 6
  ScalarProf = 7
  ScalarUi = 8
  ScalarGold = 11
  ScalarInCombat = 12
  ScalarEquipment = 13
  ScalarInventory = 18
  ScalarEquipped = 30

const
  PlayerEntity = 1
  EnemyEntity = 2
  DeathAnim = 5
  MoveAnim = 1
  RunAnim = 6
  PlayMode = 0
  BuyTierMode = 1
  BuyItemMode = 2
  SellSelectMode = 3
  SellPriceMode = 4

## Items (nmmo3.h:130-147) and equipment slots

const
  ItemTypes = 17
  HelmItem = 1
  ChestItem = 2
  LegsItem = 3
  SwordItem = 4
  BowItem = 5
  ToolItem = 6
  HerbItem = 11
  OreItem = 12
  WoodItem = 13
  HiltItem = 14
  HeldSlot = 3
  KeySlots = 9            ## only inventory slots 0-8 have keys

## Actions (nmmo3.h:46-70)

const
  DownAction = 0
  UpAction = 1
  RightAction = 2
  LeftAction = 3
  NoopAction = 4
  AttackAction = 5
  OneAction = 8
  BuyAction = 20
  SellAction = 21
  RunOffset = 22
  MoveActions = [DownAction, UpAction, RightAction, LeftAction]

## Behaviour thresholds

const
  FleeDelta = 3            ## enemy >= 6 levels above us (network profile)
  FleeRadius = 4           ## NPC_AGGRO_RANGE: inside, it is already chasing
  AggroRange = 4
  LaneRadius = 4
  HuntRadius = 5
  HealHp = 60
  HuntHp = 60
  FightHp = 35
  PauseMin = 6
  PauseMax = 16
  BuyCooldown = 60
  BuyMinGold = 5
  SwitchRadius = 2         ## equip a tool only this close to the target
  StallPhase = 300
  StagnationWindow = 500
  DangerTtl = 400
  MemoryLimit = 64
  WanderMin = 4
  WanderMax = 10

type
  Enemy = object
    r, c: int              ## window coordinates
    delta: int
    ranged: bool           ## element set: level 15+, shoots along lanes
    hp: int                ## hp / 20 bucket
    dist: int              ## chebyshev
  Item = object
    r, c: int
    kind: int
    tier: int
    dist: int              ## manhattan
  Memory = object
    r, c: int              ## world (dead-reckoned) coordinates
    value: int             ## enemy delta or resource tier
    kind: int
    tick: int
  Mind* = object
    seed: uint64
    rng: uint64
    lifeTick: int
    lastAction: int
    worldR, worldC: int
    wanderDir: int
    wanderLeft: int
    pauseLeft: int
    buyStage: int
    buyItemAction: int
    buyCooldown: int
    sellStage: int
    sellSlot: int
    sellCooldown: int
    windowMin: int
    dangers: seq[Memory]
    resources: seq[Memory]
    fights*, flees*, hunts*, harvests*, buys*, sells*, heals*, equips*: int
    branch*: string        ## last decision branch, for harness traces
    chaseTicks: int        ## ticks left of treating close enemies as chasers
    attackStreak: int      ## consecutive attack presses on the same target
    recent: array[4, int]  ## last four actions (walk direction only)
    banned: int            ## move direction banned after an A-B-A-B loop
    banTicks: int
    targetHp: int          ## that target's hp bucket when the streak began
    trace*: seq[string]    ## last 12 decisions, printed by the host on death

## Percept helpers

proc tile(obs: openArray[uint8], r, c, b: int): int =
  int(obs[(r * Cols + c) * TileBytes + b])

proc scalar(obs: openArray[uint8], i: int): int =
  int(obs[ScalarsOffset + i])

proc passable(obs: openArray[uint8], r, c: int): bool =
  r >= 0 and r < Rows and c >= 0 and c < Cols and
    obs.tile(r, c, TerrainByte) <= 1

proc occupied(obs: openArray[uint8], r, c: int): bool =
  obs.tile(r, c, EntityTypeByte) != 0 and
    obs.tile(r, c, EntityAnimByte) != DeathAnim

proc cellDanger(obs: openArray[uint8], r, c: int): int =
  ## How lethal a window cell is right now: stronger enemies shoot four
  ## tiles along their row/column (level 15+ are ranged) and melee
  ## chasers reach two tiles; 3 or more means never step there.
  for er in 0 ..< Rows:
    for ec in 0 ..< Cols:
      if obs.tile(er, ec, EntityTypeByte) != EnemyEntity:
        continue
      if obs.tile(er, ec, EntityAnimByte) == DeathAnim:
        continue
      let delta = obs.tile(er, ec, EntityDeltaByte)
      if delta == 0:
        continue
      let cheb = max(abs(er - r), abs(ec - c))
      let lane = (er == r or ec == c) and cheb <= LaneRadius
      let farLane = (er == r or ec == c) and cheb <= LaneRadius + 2
      if delta >= FleeDelta:
        if farLane or cheb <= AggroRange:
          result += 3             # inside its aggro box: it will chase
      else:
        if lane:
          result += 2
        elif cheb <= 1:
          result += 1

proc duelMargin(comb, hp, attack, defense: int, e: Enemy): int =
  ## Hits we can take minus hits we need, from the sim's damage formula
  ## (nmmo3.h:1289-1310) with the enemy level read pessimistically from
  ## the delta byte (level ~ comb + 2 delta, clamped bucket of hp / 20).
  ## Positive means we kill it first with hits to spare; -99 means our
  ## hits do nothing.
  # The delta byte is (enemy level - ours) div 2: bucket d covers
  # comb + 2d .. comb + 2d + 1. Read the ceiling (v55: chosen-fight deaths
  # 9% -> 1% of attack deaths, +0.17 alone over 90 episodes).
  let level = comb + 2 * e.delta + 1
  let ourDamage = 40 + 2 * comb + attack - 5 * level
  if ourDamage <= 0:
    return -99
  let enemyDamage = max(15 + 5 * level - 2 * comb - defense, 0)
  let enemyHp = 20 * e.hp + 19        # bucket upper bound: it strikes first
  let hitsToKill = (enemyHp + ourDamage - 1) div ourDamage
  if enemyDamage == 0:
    return 9
  let hitsToDie = (hp + enemyDamage - 1) div enemyDamage
  hitsToDie - hitsToKill

proc itemKind(id: int): int = id mod ItemTypes
proc itemTier(id: int): int = (if id == 0: 0 else: id div ItemTypes + 1)

proc tierLevel(tier: int): int = 8 * (1 shl (tier - 1))

proc moveDelta(action: int): (int, int) =
  case action
  of DownAction: (1, 0)
  of UpAction: (-1, 0)
  of RightAction: (0, 1)
  else: (0, -1)

proc isWalk(action: int): bool = action >= DownAction and action <= LeftAction
proc isRun(action: int): bool =
  action >= RunOffset + DownAction and action <= RunOffset + LeftAction

proc reverses(mind: Mind, action: int): bool =
  ## Does this move undo the last one? (down<->up, right<->left)
  var last = mind.lastAction
  if isRun(last): last -= RunOffset
  if not isWalk(last): return false
  let (lr, lc) = moveDelta(last)
  let (dr, dc) = moveDelta(action)
  lr == -dr and lc == -dc

proc enemies(obs: openArray[uint8]): seq[Enemy] =
  for r in 0 ..< Rows:
    for c in 0 ..< Cols:
      if obs.tile(r, c, EntityTypeByte) != EnemyEntity:
        continue
      if obs.tile(r, c, EntityAnimByte) == DeathAnim:
        continue
      result.add(Enemy(r: r, c: c, delta: obs.tile(r, c, EntityDeltaByte),
                       ranged: obs.tile(r, c, EntityElementByte) != 0,
                       hp: obs.tile(r, c, EntityHpByte),
                       dist: max(abs(r - CenterRow), abs(c - CenterCol))))

proc items(obs: openArray[uint8]): seq[Item] =
  for r in 0 ..< Rows:
    for c in 0 ..< Cols:
      let kind = obs.tile(r, c, ItemTypeByte)
      if kind == 0 or (r == CenterRow and c == CenterCol):
        continue
      result.add(Item(r: r, c: c, kind: kind,
                      tier: obs.tile(r, c, ItemTierByte) + 1,
                      dist: abs(r - CenterRow) + abs(c - CenterCol)))

## Mind

proc newMind*(seed: uint64, index: int): Mind =
  result.seed = seed * 1_000_003'u64 + uint64(index) * 7919'u64 + 17
  result.rng = result.seed
  result.lastAction = NoopAction
  result.windowMin = 1
  result.banned = -1
  result.recent = [-1, -1, -1, -1]

proc reset*(mind: var Mind) =
  ## New life: fresh position, no memory of the old neighbourhood.
  let seed = mind.seed
  let counters = (mind.fights, mind.flees, mind.hunts, mind.harvests,
                  mind.buys, mind.sells, mind.heals, mind.equips)
  mind = Mind(seed: seed, rng: seed + 1, lastAction: NoopAction,
              windowMin: 1, banned: -1, recent: [-1, -1, -1, -1])
  (mind.fights, mind.flees, mind.hunts, mind.harvests, mind.buys,
   mind.sells, mind.heals, mind.equips) = counters

proc nextRandom(mind: var Mind): uint64 =
  mind.rng += 0x9E3779B97F4A7C15'u64
  var z = mind.rng
  z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9'u64
  z = (z xor (z shr 27)) * 0x94D049BB133111EB'u64
  z xor (z shr 31)

proc below(mind: var Mind, n: int): int =
  int(mind.nextRandom() mod uint64(max(n, 1)))

proc remember(list: var seq[Memory], m: Memory) =
  for i in 0 ..< list.len:
    if list[i].r == m.r and list[i].c == m.c:
      list[i] = m
      return
  if list.len >= MemoryLimit:
    list.delete(0)
  list.add(m)

proc updatePosition(mind: var Mind, obs: openArray[uint8]) =
  ## Dead reckoning: the fresh anim scalar proves whether the last
  ## move or run landed (nmmo3.h sets ANIM_MOVE/RUN only on success).
  var walk = mind.lastAction
  if isRun(walk):
    walk -= RunOffset
  if not isWalk(walk):
    return
  let (dr, dc) = moveDelta(walk)
  let anim = obs.scalar(ScalarAnim)
  if anim == MoveAnim:
    mind.worldR += dr
    mind.worldC += dc
  elif anim == RunAnim:
    mind.worldR += 2 * dr
    mind.worldC += 2 * dc

proc observeMemory(mind: var Mind, obs: openArray[uint8],
                   foes: seq[Enemy], ground: seq[Item], tick: int) =
  for e in foes:
    if e.delta >= FleeDelta:
      remember(mind.dangers, Memory(r: mind.worldR + e.r - CenterRow,
        c: mind.worldC + e.c - CenterCol, value: e.delta, tick: tick))
  for it in ground:
    if it.kind in [OreItem, WoodItem, HiltItem, HerbItem, ToolItem] or
        it.kind >= 12:
      remember(mind.resources, Memory(r: mind.worldR + it.r - CenterRow,
        c: mind.worldC + it.c - CenterCol, value: it.tier, kind: it.kind,
        tick: tick))
  # Forget stale dangers and resources we have just stood on.
  var kept: seq[Memory]
  for d in mind.dangers:
    if tick - d.tick <= DangerTtl:
      kept.add(d)
  mind.dangers = kept
  kept = @[]
  for m in mind.resources:
    let wr = m.r - mind.worldR + CenterRow
    let wc = m.c - mind.worldC + CenterCol
    if wr >= 0 and wr < Rows and wc >= 0 and wc < Cols:
      if obs.tile(wr, wc, ItemTypeByte) == 0:
        continue           # gone (harvested by someone)
    kept.add(m)
  mind.resources = kept

## Movement

proc dangerAt(mind: Mind, r, c: int): int =
  ## Remembered strong-enemy weight for a window cell.
  for d in mind.dangers:
    let wr = d.r - mind.worldR + CenterRow
    let wc = d.c - mind.worldC + CenterCol
    if max(abs(wr - r), abs(wc - c)) <= 2:
      inc result
  result

proc runnable(obs: openArray[uint8], action: int, safe = true): bool =
  ## Both tiles passable and free of bodies (either occupied tile fails
  ## the whole run, nmmo3.h:1197); with safe, neither tile is lethal.
  let (dr, dc) = moveDelta(action)
  let r1 = CenterRow + dr
  let c1 = CenterCol + dc
  let r2 = CenterRow + 2 * dr
  let c2 = CenterCol + 2 * dc
  result = obs.passable(r1, c1) and not obs.occupied(r1, c1) and
    obs.passable(r2, c2) and not obs.occupied(r2, c2)
  if result and safe:
    # The window is 5 rows tall each way but 7 columns wide: a vertical
    # run lands within aggro range of rows it has never seen, so only
    # horizontal runs are safe outside a flee.
    result = dr == 0 and obs.cellDanger(r1, c1) < 3 and
      obs.cellDanger(r2, c2) < 3

proc laneFreeFrom(obs: openArray[uint8], fromR, fromC, action: int): int =
  ## Consecutive passable, unoccupied, non-lethal cells from a window cell
  ## along the move direction (a kite needs two behind it for the run back).
  let (dr, dc) = moveDelta(action)
  for k in 1 .. 4:
    let r = fromR + k * dr
    let c = fromC + k * dc
    if not obs.passable(r, c) or obs.occupied(r, c) or obs.cellDanger(r, c) >= 3:
      return
    inc result

proc laneFree(obs: openArray[uint8], action: int): int =
  obs.laneFreeFrom(CenterRow, CenterCol, action)

proc exits(obs: openArray[uint8], r, c: int): int =
  ## Passable, unoccupied neighbours of a window cell: a flee destination
  ## with none ahead is a dead end.
  for action in MoveActions:
    let (dr, dc) = moveDelta(action)
    if obs.passable(r + dr, c + dc) and not obs.occupied(r + dr, c + dc):
      inc result

proc walkable(obs: openArray[uint8], action: int, safe = true): bool =
  let (dr, dc) = moveDelta(action)
  result = obs.passable(CenterRow + dr, CenterCol + dc) and
    not obs.occupied(CenterRow + dr, CenterCol + dc)
  if result and safe:
    result = obs.cellDanger(CenterRow + dr, CenterCol + dc) < 3

proc canLeave(obs: openArray[uint8], e: Enemy): bool =
  ## Is there any move that ends farther from this enemy? A melee chaser
  ## spends its tick closing the gap instead of hitting, so walking away
  ## is free until we are cornered; a run breaks contact outright.
  for action in MoveActions:
    let (dr, dc) = moveDelta(action)
    if obs.runnable(action, safe = false) and
        max(abs(CenterRow + 2 * dr - e.r), abs(CenterCol + 2 * dc - e.c)) >= 3:
      return true
    if obs.walkable(action, safe = false) and
        max(abs(CenterRow + dr - e.r), abs(CenterCol + dc - e.c)) >= 2:
      return true
  false

proc stepToward(mind: var Mind, obs: openArray[uint8], tr, tc: int,
                allowRun: bool): int =
  ## Move that most reduces the manhattan distance to window cell
  ## (tr, tc); runs when the two-tile move is clear and still helps.
  ## -1 when no move helps.
  let here = abs(tr - CenterRow) + abs(tc - CenterCol)
  var best = -1
  var bestScore = -1_000_000
  for action in MoveActions:
    if not obs.walkable(action):
      continue
    let (dr, dc) = moveDelta(action)
    var d = abs(tr - CenterRow - dr) + abs(tc - CenterCol - dc)
    var candidate = action
    if allowRun and here >= 3 and obs.runnable(action):
      let d2 = abs(tr - CenterRow - 2 * dr) + abs(tc - CenterCol - 2 * dc)
      if d2 < d:
        d = d2
        candidate = action + RunOffset
    let score = (here - d) * 10 - mind.dangerAt(CenterRow + dr,
                                                 CenterCol + dc) * 15 +
      mind.below(3) - (if mind.reverses(action): 12 else: 0) - (if mind.banned == action: 40 else: 0)
    if d < here and score > bestScore:
      bestScore = score
      best = candidate
  best

proc fleeMove(mind: var Mind, obs: openArray[uint8],
              threats: seq[Enemy]): int =
  ## Move that maximises the distance to the nearest threat, leaving its
  ## row/column when possible; runs when clear. -1 when nothing helps.
  proc score(mind: Mind, r, c: int): int =
    ## Lanes and contact dominate: a lane within range is a likely
    ## one-shot, so leaving it beats any distance gained elsewhere.
    var nearest = 99
    var penalty = 0
    for t in threats:
      let cheb = max(abs(r - t.r), abs(c - t.c))
      nearest = min(nearest, cheb)
      # A cell on a shooter's row or column within its reach is a certain
      # shot of 40-90 hp at its next turn (hosted v49 flee option scores at
      # shooter deaths: such cells scored within 5 of the alternatives and
      # the reversal penalty picked them), so it outweighs everything else.
      if (r == t.r or c == t.c) and cheb <= LaneRadius and t.delta >= 1:
        penalty += (if t.ranged: 100 else: 25)
      if cheb <= 1: penalty += 30
      elif cheb <= 2: penalty += 15
      elif cheb <= AggroRange: penalty += 8
    nearest * 3 - penalty - mind.dangerAt(r, c) * 6
  let here = score(mind, CenterRow, CenterCol)
  when defined(scriptedDebug):
    for t in threats:
      echo "  threat r", t.r, " c", t.c, " d", t.delta, " ranged ", t.ranged, " hp", t.hp, " dist", t.dist
    for action in MoveActions:
      let (dr, dc) = moveDelta(action)
      echo "  flee option ", action, " walkable ", obs.walkable(action, safe = false), " score ", score(mind, CenterRow + dr, CenterCol + dc), " here ", here
  var best = -1
  var bestScore = here
  for action in MoveActions:
    if not obs.walkable(action, safe = false):
      continue
    let (dr, dc) = moveDelta(action)
    # Mobility: a destination with exits keeps the next flee possible;
    # hosted v45 traces show two-tile runs into dead ends followed by the
    # only scoring move, back beside the chaser, one hit per cycle.
    var s = score(mind, CenterRow + dr, CenterCol + dc) -
      (if mind.reverses(action): 20 else: 0) - (if mind.banned == action: 40 else: 0) +
      4 * obs.exits(CenterRow + dr, CenterCol + dc)
    when defined(scriptedDebug):
      echo "  flee final ", action, " s ", s, " exits ", obs.exits(CenterRow + dr, CenterCol + dc), " reverses ", mind.reverses(action), " banned ", mind.banned == action
    var candidate = action
    if obs.runnable(action, safe = false):
      # v78: the run variant carries the same reversal and ban penalties
      # as the step; without them a two-tile run back beside a shooter
      # that has just re-aligned scores fresh every other tick (18.5% of
      # v71 flee ticks reversed the previous flee, 94% of them run-run).
      let s2 = score(mind, CenterRow + 2 * dr, CenterCol + 2 * dc) +
        4 * obs.exits(CenterRow + 2 * dr, CenterCol + 2 * dc) -
        (if mind.reverses(action): 20 else: 0) - (if mind.banned == action: 40 else: 0)
      if s2 > s:
        s = s2
        candidate = action + RunOffset
    if s > bestScore:
      bestScore = s
      best = candidate
  when defined(scriptedDebug):
    echo "  flee chosen ", best, " bestScore ", bestScore
  best

proc wander(mind: var Mind, obs: openArray[uint8], idle: int, rush = false): int =
  ## Persistent exploration like the network's: a run segment, then a
  ## pause (its idle is a free attack press), prefer open ground, avoid
  ## remembered danger. A rush skips the pauses and runs longer segments.
  if mind.pauseLeft > 0 and not rush:
    dec mind.pauseLeft
    return idle
  if mind.wanderLeft <= 0 or not obs.walkable(mind.wanderDir):
    # v82: no pauses between segments (they were 50% of wander ticks, a
    # quarter of mature ticks; v68 shortened them and v74 dropped them
    # before the first tool, both +0.2-0.3 below resolution; a pause with
    # a stronger melee inside its aggro box invites the chase).
    if mind.wanderLeft <= 0 and mind.wanderDir >= 0 and not rush:
      mind.wanderDir = -1
    var candidates: seq[int]
    var bestScore = -1_000_000
    for action in MoveActions:
      if not obs.walkable(action):
        continue
      let (dr, dc) = moveDelta(action)
      var open = 0
      for k in 1 .. 4:
        if obs.passable(CenterRow + k * dr, CenterCol + k * dc):
          inc open
      let s = open * 4 - mind.dangerAt(CenterRow + 2 * dr, CenterCol + 2 * dc) * 10 +
        mind.below(4)
      if s > bestScore:
        bestScore = s
        candidates = @[action]
      elif s == bestScore:
        candidates.add(action)
    if candidates.len == 0:
      return NoopAction
    mind.wanderDir = candidates[mind.below(candidates.len)]
    mind.wanderLeft = WanderMin + mind.below(WanderMax - WanderMin + 1) + (if rush: WanderMax else: 0)
  dec mind.wanderLeft
  if obs.runnable(mind.wanderDir):
    mind.wanderDir + RunOffset
  else:
    mind.wanderDir

## Inventory helpers

proc inventory(obs: openArray[uint8], slot: int): int =
  obs.scalar(ScalarInventory + slot)

proc equipped(obs: openArray[uint8], slot: int): bool =
  obs.scalar(ScalarEquipped + slot) != 0

proc equipmentId(obs: openArray[uint8], slot: int): int =
  obs.scalar(ScalarEquipment + slot)

proc freeSlots(obs: openArray[uint8]): int =
  for slot in 0 ..< 12:
    if obs.inventory(slot) == 0:
      inc result

proc bestSlotOf(obs: openArray[uint8], kind: int): (int, int) =
  ## (slot, tier) of the best unequipped item of a kind among key slots.
  result = (-1, 0)
  for slot in 0 ..< KeySlots:
    let id = obs.inventory(slot)
    if id != 0 and itemKind(id) == kind and not obs.equipped(slot) and
        itemTier(id) > result[1]:
      result = (slot, itemTier(id))

proc equippedSlotOf(obs: openArray[uint8], kind: int): int =
  ## Key slot holding the currently equipped item of a kind, -1 if none
  ## or unreachable.
  result = -1
  for slot in 0 ..< KeySlots:
    let id = obs.inventory(slot)
    if id != 0 and itemKind(id) == kind and obs.equipped(slot):
      return slot

proc bestToolTier(obs: openArray[uint8]): int =
  let held = obs.equipmentId(HeldSlot)
  if held != 0 and itemKind(held) == ToolItem:
    result = itemTier(held)
  let (slot, tier) = obs.bestSlotOf(ToolItem)
  if slot >= 0:
    result = max(result, tier)

proc junkSlot(obs: openArray[uint8]): int =
  ## Lowest-value unequipped key slot to sell when the inventory is full:
  ## gems and raw resources first, then spare gear of lower tier than
  ## what we wear.
  result = -1
  var bestValue = 1_000_000
  for slot in 0 ..< KeySlots:
    let id = obs.inventory(slot)
    if id == 0 or obs.equipped(slot):
      continue
    let kind = itemKind(id)
    let tier = itemTier(id)
    var value = tier * 10
    if kind >= 7 and kind <= 10: value = tier             # gems
    elif kind == HerbItem: value = 100 + tier * 10        # keep herbs
    elif kind == ToolItem: value = 50 + tier * 20
    elif kind == SwordItem or kind == BowItem: value = 30 + tier * 20
    elif kind in [HelmItem, ChestItem, LegsItem]:
      value = 20 + tier * 20
    if value < bestValue:
      bestValue = value
      result = slot

## Decision

proc decide*(mind: var Mind, obs: openArray[uint8], tick: int): int =
  mind.updatePosition(obs)
  # Oscillation guard: A-B-A-B between opposite moves pins us in place.
  block:
    var last = mind.lastAction
    if isRun(last): last -= RunOffset
    let dir = (if isWalk(last): last else: -1)
    mind.recent = [mind.recent[1], mind.recent[2], mind.recent[3], dir]
    if mind.banTicks > 0:
      dec mind.banTicks
      if mind.banTicks == 0: mind.banned = -1
    if dir >= 0 and mind.recent[0] == mind.recent[2] and
        mind.recent[1] == mind.recent[3] and mind.recent[2] >= 0 and
        mind.recent[2] != dir:
      let (ar, ac) = moveDelta(dir)
      let (br, bc) = moveDelta(mind.recent[2])
      if ar == -br and ac == -bc:
        mind.banned = mind.recent[2]
        mind.banTicks = 4
  let
    hp = obs.scalar(ScalarHp)
    comb = obs.scalar(ScalarComb)
    prof = obs.scalar(ScalarProf)
    ui = obs.scalar(ScalarUi)
    gold = obs.scalar(ScalarGold)
    inCombat = obs.scalar(ScalarInCombat) > 0
    held = obs.equipmentId(HeldSlot)
    heldKind = itemKind(held)
    heldTier = itemTier(held)
    foes = obs.enemies()
    ground = obs.items()
    currentMin = min(comb, prof)
    phase = mind.lifeTick mod StagnationWindow
  if phase == 0:
    mind.windowMin = currentMin
  let stalled = phase >= StallPhase and currentMin <= mind.windowMin
  mind.observeMemory(obs, foes, ground, tick)
  inc mind.lifeTick
  if mind.buyCooldown > 0:
    dec mind.buyCooldown
  if mind.sellCooldown > 0:
    dec mind.sellCooldown

  template finish(actionExpr: int, tag = "other"): untyped =
    # Bind once: a template argument is re-evaluated per use, and wander
    # has side effects (RNG, pause and segment counters).
    let action = actionExpr
    mind.branch = tag
    mind.lastAction = action
    block:
      var near = "-"
      var best = 99
      for e in foes:
        if e.dist < best:
          best = e.dist
          near = $e.dist & ":" & $e.delta & ":" & $e.hp
      mind.trace.add("t" & $mind.lifeTick & " " & tag & " a" & $action &
        " hp" & $hp & " c" & $comb & "/p" & $prof & " e" & near &
        (if inCombat: " cb" else: "") & " n" & $foes.len)
      if mind.trace.len > 12:
        mind.trace.delete(0)
    return action

  # Interface modes: continue our own buy/sell flow, escape anything else.
  if ui != PlayMode:
    if ui == BuyTierMode and mind.buyStage == 1:
      mind.buyStage = 2
      finish(OneAction + 1, "ui")
    if ui == BuyItemMode and mind.buyStage == 2:
      mind.buyStage = 0
      mind.buyCooldown = BuyCooldown
      inc mind.buys
      finish(mind.buyItemAction, "ui")
    if ui == SellSelectMode and mind.sellStage == 1:
      mind.sellStage = 2
      finish(OneAction + mind.sellSlot, "ui")
    if ui == SellPriceMode and mind.sellStage == 2:
      mind.sellStage = 0
      inc mind.sells
      finish(OneAction + 8, "ui")
    mind.buyStage = 0
    mind.sellStage = 0
    finish(AttackAction)                        # any non-noop exits the ui
  mind.buyStage = 0
  mind.sellStage = 0

  # Threats: much stronger enemies close by, lane shooters, and anything
  # adjacent while we are nearly dead.
  var threats: seq[Enemy]
  var adjacent: seq[Enemy]
  for e in foes:
    if e.dist <= 1:
      adjacent.add(e)
    let onLane = (e.r == CenterRow or e.c == CenterCol) and e.dist <= LaneRadius
    let onFarLane = (e.r == CenterRow or e.c == CenterCol) and
      e.dist <= LaneRadius + 2
    if (e.delta >= FleeDelta and (e.dist <= FleeRadius or onFarLane)) or
        (e.delta >= 1 and onLane and e.dist >= 2):
      threats.add(e)
    elif e.dist <= 1:
      # Adjacent means it is hitting us: fight it or leave, never idle.
      let margin = duelMargin(comb, hp, obs.scalar(45), obs.scalar(46), e)
      let worthNow = margin >= 0 or e.hp == 0
      if not worthNow:
        threats.add(e)
      mind.chaseTicks = 8         # it will follow: keep going
    elif mind.chaseTicks > 0 and e.dist <= 3 and
        duelMargin(comb, hp, obs.scalar(45), obs.scalar(46), e) < 1:
      threats.add(e)              # still being chased
  if mind.chaseTicks > 0:
    dec mind.chaseTicks
  # Anything we would not fight, close by, cancels slow errands below.
  var unsafe = false
  var nearestFoe = 99
  for e in foes:
    nearestFoe = min(nearestFoe, e.dist)
  for e in foes:
    if e.dist <= 4 and (e.delta >= FleeDelta or
        duelMargin(comb, hp, obs.scalar(45), obs.scalar(46), e) < 1):
      unsafe = true
    elif e.dist <= 2 and comb <= 2 and e.delta >= 1:
      threats.add(e)
  when defined(scriptedDebug):
    echo "threats ", threats.len, " foes ", foes.len, " hp ", hp
  # Bow kiting v2 (combat strategy): a bow reaches four tiles along our
  # row or column and a melee enemy only attacks when it starts its turn
  # orthogonally adjacent, so shoot at 2-4, run two tiles back along the
  # lane when it closes, shoot again: it never lands a hit while the lane
  # behind us stays clear. v26 kited only horizontally (safe runs) and
  # shot point blank otherwise; this version runs on any axis, checks the
  # lane behind us before it commits, and sidesteps to a clear lane rather
  # than trading hits. Shooters (element set) and anything we cannot
  # damage are left to the flee rules; company within two tiles cancels.
  if heldKind == BowItem:
    var kite: Enemy
    var haveKite = false
    for e in foes:
      if e.ranged or e.delta >= 3 or e.dist > LaneRadius + 2:
        continue
      let level = (if e.delta == 0: comb else: comb + 2 * e.delta)
      if 40 + 2 * comb + obs.scalar(45) - 5 * level <= 0:
        continue
      if not haveKite or e.dist < kite.dist:
        kite = e
        haveKite = true
    var kiteAlone = haveKite
    if haveKite:
      for o in foes:
        if (o.r != kite.r or o.c != kite.c) and o.dist <= 2:
          kiteAlone = false
      for t in threats:
        if t.r != kite.r or t.c != kite.c:
          kiteAlone = false
    if kiteAlone:
      let onLane = kite.r == CenterRow or kite.c == CenterCol
      let dr = CenterRow - kite.r
      let dc = CenterCol - kite.c
      var back = -1
      if kite.r == CenterRow and dc != 0:
        back = (if dc > 0: RightAction else: LeftAction)
      elif kite.c == CenterCol and dr != 0:
        back = (if dr > 0: DownAction else: UpAction)
      if kite.dist <= 1:
        if back >= 0 and obs.laneFree(back) >= 2:
          inc mind.fights
          finish(back + RunOffset, "kite")
        if back < 0:
          # Diagonal: any step of ours leaves it diagonal again (it always
          # closes the larger offset), so wait; it steps beside us without
          # a hit and the run back along that lane follows (v44 traces:
          # endless up/down steps beside a diagonal chaser).
          inc mind.fights
          finish(NoopAction, "kite")
        # Orthogonal with no room behind: sidestep to the perpendicular
        # cell from which the same back lane has room; it re-aligns above
        # us next tick without a hit. Never step into orthogonal adjacency
        # (v44 traces: one 40-hp hit per such step).
        var side = -1
        var sideRoom = 1
        for action in MoveActions:
          let (mr, mc) = moveDelta(action)
          if (mr, mc) == moveDelta(back) or (mr, mc) == (-moveDelta(back)[0], -moveDelta(back)[1]):
            continue
          if not obs.walkable(action, safe = false):
            continue
          if abs(kite.r - CenterRow - mr) + abs(kite.c - CenterCol - mc) <= 1:
            continue
          let room = obs.laneFreeFrom(CenterRow + mr, CenterCol + mc, back)
          if room > sideRoom:
            sideRoom = room
            side = action
        if side >= 0:
          inc mind.flees
          finish(side, "kite")
        if duelMargin(comb, hp, obs.scalar(45), obs.scalar(46), kite) >= 0:
          inc mind.fights
          finish(AttackAction, "kite")
      elif onLane and kite.dist <= LaneRadius:
        if back >= 0 and obs.laneFree(back) >= 2 or kite.dist >= 3:
          inc mind.fights
          finish(AttackAction, "kite")
        # Two tiles away with nothing behind us: shift sideways to a cell
        # from which the back lane has room, before it closes.
        var side = -1
        var sideRoom = 1
        for action in MoveActions:
          let (mr, mc) = moveDelta(action)
          if action == back or not obs.walkable(action, safe = false):
            continue
          if abs(kite.r - CenterRow - mr) + abs(kite.c - CenterCol - mc) <= 1:
            continue
          let room = obs.laneFreeFrom(CenterRow + mr, CenterCol + mc, back)
          if room > sideRoom:
            sideRoom = room
            side = action
        if side >= 0:
          inc mind.flees
          finish(side, "kite")
        inc mind.fights
        finish(AttackAction, "kite")
      elif kite.dist >= 2:
        # Line it up: close the smaller offset, keeping two tiles between.
        var align = -1
        if abs(dc) <= abs(dr) and dc != 0:
          align = (if dc > 0: LeftAction else: RightAction)
        elif dr != 0:
          align = (if dr > 0: UpAction else: DownAction)
        if align >= 0 and obs.walkable(align):
          let (mr, mc) = moveDelta(align)
          if max(abs(CenterRow + mr - kite.r), abs(CenterCol + mc - kite.c)) >= 2:
            inc mind.hunts
            finish(align, "kite")

  if threats.len > 0:
    let move = mind.fleeMove(obs, threats)
    if move >= 0:
      inc mind.flees
      finish(move, "flee")
    if adjacent.len > 0:
      finish(AttackAction, "cornered")                      # cornered: fight back

  # Fight: attack a worthwhile adjacent enemy. Basic reach is the four
  # orthogonal cells; a sword also covers the diagonals; a bow shoots
  # four tiles along a lane.
  var target: Enemy
  var haveTarget = false
  for e in foes:
    let orthogonal = e.r == CenterRow or e.c == CenterCol
    var reachable = false
    if e.dist <= 1:
      reachable = orthogonal or heldKind == SwordItem
    elif heldKind == BowItem and orthogonal and e.dist <= LaneRadius:
      reachable = true
    if not reachable:
      continue
    # The network's thresholds (behavior_stats, adjacent-enemy tables):
    # nearly dead enemies are always finished; healthy us takes level
    # peers and slightly stronger wounded ones; below 60 hp only peers
    # that are already hurt.
    # Duel model: take the fight when we kill first with a hit to spare
    # (others may join in); a stalled combat skill accepts an even trade.
    let margin = duelMargin(comb, hp, obs.scalar(45), obs.scalar(46), e)
    # Players act before enemies each tick: an even trade ends with our
    # killing blow, and the networks average an enemy level gap of 0.
    let worth = margin >= 0 or e.hp == 0 or
      (stalled and comb <= prof and margin >= 0 and hp >= 45)
    if worth and (not haveTarget or e.hp < target.hp):
      target = e
      haveTarget = true
  if haveTarget:
    # Are our hits landing? After three presses the hp bucket must have
    # dropped, otherwise the target is out of reach or immune: break off.
    if mind.attackStreak == 0:
      mind.targetHp = target.hp
    if mind.attackStreak >= 3 and target.hp >= mind.targetHp:
      mind.attackStreak = 0
      mind.chaseTicks = 6
      let move = mind.fleeMove(obs, @[target])
      if move >= 0:
        inc mind.flees
        finish(move, "flee")
    inc mind.attackStreak
    if target.dist >= 2 and heldKind == BowItem and hp < HuntHp:
      # Kite: keep shooting from range.
      inc mind.fights
      finish(AttackAction, "kite")
    inc mind.fights
    finish(AttackAction, "fight")
  mind.attackStreak = 0
  # A worthwhile enemy sits diagonally and we cannot reach it: align.
  for e in adjacent:
    if e.delta == 0 and hp >= FightHp and heldKind != SwordItem:
      let move = mind.stepToward(obs, e.r, CenterCol, false)
      if move >= 0:
        finish(move, "align")

  # Heal before anything slow.
  if hp < HealHp and adjacent.len == 0:
    let (slot, _) = obs.bestSlotOf(HerbItem)
    if slot >= 0:
      inc mind.heals
      finish(OneAction + slot, "heal")

  # Hunt: approach a same-level enemy while healthy (combat levels only
  # come from kills of enemies at or above our level).
  if hp >= 50 or (stalled and comb <= prof and hp >= 45):
    var prey: Enemy
    var havePrey = false
    for e in foes:
      if e.dist < 2 or e.dist > HuntRadius:
        continue
      # Approach only fights we win with room to spare, and never walk
      # into a second stronger enemy's reach on the way.
      let margin = duelMargin(comb, hp, obs.scalar(45), obs.scalar(46), e)
      var ok = margin >= 1 or (stalled and comb <= prof and margin >= 0)
      for other in foes:
        if other.delta >= 1 and max(abs(other.r - e.r), abs(other.c - e.c)) <= 3:
          ok = false                # it has stronger company
      if ok and (not havePrey or e.dist < prey.dist):
        prey = e
        havePrey = true
    if havePrey:
      # Hold a weapon when closing in.
      if heldKind == ToolItem and not inCombat:
        let (sword, _) = obs.bestSlotOf(SwordItem)
        let (bow, _) = obs.bestSlotOf(BowItem)
        if sword >= 0 or bow >= 0:
          let heldSlot = obs.equippedSlotOf(ToolItem)
          if heldSlot >= 0:
            inc mind.equips
            finish(OneAction + heldSlot, "equip")          # unequip the tool first
      if heldKind == 0 and not inCombat:
        let (bow, _) = obs.bestSlotOf(BowItem)
        if bow >= 0:
          inc mind.equips
          finish(OneAction + bow, "equip")
        let (sword, _) = obs.bestSlotOf(SwordItem)
        if sword >= 0:
          inc mind.equips
          finish(OneAction + sword, "equip")
      let move = mind.stepToward(obs, prey.r, prey.c, prey.dist >= 3)
      if move >= 0:
        inc mind.hunts
        finish(move, "hunt")

  # Gear: better armor from the inventory; a weapon in the held slot
  # unless we are about to harvest.
  if not inCombat:
    for (kind, slot) in [(HelmItem, 0), (ChestItem, 1), (LegsItem, 2)]:
      let (candidate, tier) = obs.bestSlotOf(kind)
      if candidate < 0:
        continue
      let worn = obs.equipmentId(slot)
      if worn == 0:
        inc mind.equips
        finish(OneAction + candidate, "equip")
      if tier > itemTier(worn):
        let wornSlot = obs.equippedSlotOf(kind)
        if wornSlot >= 0:
          inc mind.equips
          finish(OneAction + wornSlot, "equip")            # unequip, equip next tick

  # Harvest target: nearest resource we can take with our best tool that
  # levels the profession, or tier-2+ gear resources; ground tools that
  # beat what we own are taken too.
  let toolTier = obs.bestToolTier()
  var goal: Item
  var haveGoal = false
  var goalIsTool = false
  var goalIsGear = false
  let free = obs.freeSlots()
  for it in ground:
    if it.kind == ToolItem:
      if it.tier > toolTier and free > 0 and it.dist <= 6:
        if not haveGoal or it.dist < goal.dist:
          goal = it
          haveGoal = true
          goalIsTool = true
      continue
    let resource = it.kind >= 7 and it.kind <= 16
    if not resource or it.tier > toolTier or toolTier == 0:
      continue
    let levels = tierLevel(it.tier) > prof
    # Gear we still lack (harvest turns ore into a random armor piece,
    # hilt into a sword, wood into a bow, nmmo3.h:1180-1190): armor is
    # what makes fights winnable, so it outranks distance.
    var gear = false
    if it.kind == OreItem:
      for slot in 0 ..< 3:
        if itemTier(obs.equipmentId(slot)) < it.tier:
          gear = true
    elif it.kind == HiltItem:
      gear = max(obs.bestSlotOf(SwordItem)[1],
                 (if heldKind == SwordItem: heldTier else: 0)) < it.tier
    elif it.kind == WoodItem:
      gear = max(obs.bestSlotOf(BowItem)[1],
                 (if heldKind == BowItem: heldTier else: 0)) < it.tier
    let herb = it.kind == HerbItem and obs.bestSlotOf(HerbItem)[0] < 0
    if (levels or gear or herb) and free > 0:   # pickup needs a free slot first
      let priority = it.dist - (if gear: 6 else: 0)
      let goalPriority = goal.dist - (if goalIsGear: 6 else: 0)
      if not haveGoal or priority < goalPriority:
        goal = it
        haveGoal = true
        goalIsTool = false
        goalIsGear = gear
  if haveGoal and not unsafe:
    if not goalIsTool and goal.dist <= SwitchRadius and heldKind != ToolItem and
        not inCombat:
      if held != 0:
        let heldSlot = obs.equippedSlotOf(heldKind)
        if heldSlot >= 0:
          inc mind.equips
          finish(OneAction + heldSlot, "equip")
      else:
        let (slot, _) = obs.bestSlotOf(ToolItem)
        if slot >= 0:
          inc mind.equips
          finish(OneAction + slot, "equip")
    if goal.dist == 1 and not goalIsTool and heldKind != ToolItem:
      discard                                  # wait for the switch above
    else:
      let move = mind.stepToward(obs, goal.r, goal.c, goal.dist >= 4)
      if move >= 0:
        inc mind.harvests
        finish(move, "harvest")

  # Full inventory blocks harvest level-ups: sell junk.
  if free == 0 and nearestFoe > 2 and mind.sellCooldown == 0:
    let slot = obs.junkSlot()
    if slot >= 0:
      mind.sellStage = 1
      mind.sellSlot = slot
      mind.sellCooldown = 12
      finish(SellAction, "sell")

  # Market: tier-2 armor for empty or tier-1 slots, else a better tool.
  if mind.buyCooldown == 0 and gold >= BuyMinGold and free > 0 and
      not inCombat and not unsafe and (foes.len == 0 or nearestFoe > 4):
    var want = 0
    for (kind, slot) in [(HelmItem, 0), (ChestItem, 1), (LegsItem, 2)]:
      if itemTier(obs.equipmentId(slot)) < 2 and obs.bestSlotOf(kind)[1] < 2:
        want = kind
        break
    if want == 0 and toolTier < 2:
      want = ToolItem
    if want == 0 and prof >= 16 and toolTier < 3:
      want = ToolItem
    if want == 0:
      let (_, swordTier) = obs.bestSlotOf(SwordItem)
      if max(swordTier, (if heldKind == SwordItem: heldTier else: 0)) < 2:
        want = SwordItem
    if want != 0:
      mind.buyStage = 1
      mind.buyItemAction = OneAction + want - 1
      finish(BuyAction, "buy")

  # Between fights hold the best sword (or bow) rather than a tool.
  if not inCombat and foes.len > 0 and heldKind == ToolItem:
    if obs.bestSlotOf(SwordItem)[0] >= 0 or obs.bestSlotOf(BowItem)[0] >= 0:
      let heldSlot = obs.equippedSlotOf(ToolItem)
      if heldSlot >= 0:
        inc mind.equips
        finish(OneAction + heldSlot, "equip")
  if not inCombat and held == 0:
    let (bow, _) = obs.bestSlotOf(BowItem)
    if bow >= 0:
      inc mind.equips
      finish(OneAction + bow, "equip")
    let (sword, _) = obs.bestSlotOf(SwordItem)
    if sword >= 0:
      inc mind.equips
      finish(OneAction + sword, "equip")
    let (tool, _) = obs.bestSlotOf(ToolItem)
    if tool >= 0:
      inc mind.equips
      finish(OneAction + tool, "equip")

  # Remembered resources out of view, only while profession does not
  # already lead combat: the score is min(comb, prof), our prof ends lives
  # ~3 above comb, and these walks took 10% of mature ticks (network
  # divergence: it would not make them, 4% agreement).
  if toolTier > 0 and not unsafe and prof <= comb:
    var bestMemory = -1
    var bestDist = 1_000
    for i, m in mind.resources:
      if m.value > toolTier or m.kind == ToolItem:
        continue
      let levels = tierLevel(m.value) > prof
      let gear = m.kind in [OreItem, HiltItem, WoodItem] and m.value >= 2
      if not (levels or gear):
        continue
      let d = abs(m.r - mind.worldR) + abs(m.c - mind.worldC)
      if d < bestDist and d <= 40:
        bestDist = d
        bestMemory = i
    if bestMemory >= 0:
      let m = mind.resources[bestMemory]
      let move = mind.stepToward(obs, m.r - mind.worldR + CenterRow,
                                 m.c - mind.worldC + CenterCol, true)
      if move >= 0:
        finish(move, "memory")

  # Idle like the network (a free attack press) only when nothing could be
  # hit by it: a bow reaches four tiles along a lane, a sword the ring.
  var idle = AttackAction
  for e in foes:
    if e.dist <= LaneRadius:
      idle = NoopAction
  # Stalled exploration (v58: +0.10 alone over 30 episodes): no pauses and
  # double segments once a window has stalled with combat binding.
  finish(mind.wander(obs, idle, stalled and comb <= prof), "wander")
