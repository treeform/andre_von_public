## Zmey Gorynych — moba policy for Andre von Auto.
## A command player: one JSON text message per tick each way
## (docs/protocol_player.md):
##   server -> {"tick": t, "obs": ["<base64 510B>", ... per hero]}
##   player -> {"tick": t, "actions": [[vy, vx, filter, q, w, e], ...]}
##   server -> {"done": true, "result": {...}} then close.
## This is a Nim port of the upstream repo's scripted reference bot
## (players/scripted_player.py @ f06d28fd): a per-hero finite-state
## lane-push machine. Ground truth for every constant is the vendored
## upstream source, moba.h (citations kept from the Python original).
##
## Observation contract: each hero gets 510 bytes, but the crop region
## has a stride-1 overlap quirk, so only bytes 0..120 (the 121 tile ids
## of the 11x11 crop) and bytes 484..509 (self scalars) are reliable.
## Tile ids: EMPTY 0, WALL 1, TOWER 2 (team resolved via the static
## tower table), RADIANT_CREEP 3, DIRE_CREEP 4, NEUTRAL 5, radiant
## heroes 6..10, dire heroes 11..15.
##
## Action contract: [vel_y, vel_x, attack_target, use_q, use_w, use_e];
## velocity decodes as (a-3)/3, the engine self-selects the NEAREST
## scanned entity, skills fall through harmlessly on cooldown/mana.
##
## Modes per hero: PUSH along the lane waypoints (BFS cost fields over
## the embedded static wall grid), SIEGE HOLD outside tower vision until
## a friendly creep wave engages (ancients cannot shoot — diving them is
## free), RETREAT to the fountain below 3/10 health with hysteresis at
## 8/10, and a 90-degree detour burst when stuck.
##
## Deterministic: a pure function of (obs bytes, per-hero state). No RNG
## and no clocks; COGAME_PLAYER_SEED is accepted for parity but unused.
## Works for 1-hero and 5-hero seats.

import
  std/[base64, deques, json, options, os, sets, tables],
  whisky

## Wire constants

const
  observationSize = 510
  cropTiles = 121          ## reliable prefix of the 484-byte crop region
  cropWidth = 11
  visionRange = 5          ## sim/shim_common.h:17
  selfOffset = 484         ## 11*11*4
  mapWidth = 128
  connectAttempts = 240    ## initial dial: 240 x 500 ms = 2 minutes
  connectRetryMs = 500
  reconnectAttempts = 5    ## consecutive failures after first contact

## Tile ids (moba.h:28-43)

const
  emptyTile = 0
  wallTile = 1
  towerTile = 2
  radiantCreepTile = 3
  direCreepTile = 4

## Hero roles and static tables (init_moba, moba.h:1661-1744)

const
  supportHero = 0
  assassinHero = 1
  burstHero = 2
  tankHero = 3
  # carryHero = 4 (the fall-through role in skillFlags)
  laneForHero = [2, 1, 1, 0, 2]
  manaTable = [(250, 50), (300, 65), (300, 90), (200, 50), (250, 50)]
  spawns = [(113, 12), (15, 116)]  ## team -> fountain (y, x), moba.h:1636
  towerVision = 5                  ## moba.h:45

type Tower = object
  y, x: float
  team, tier: int

proc tower(y, x: float, team, tier: int): Tower =
  Tower(y: y, x: x, team: team, tier: tier)

## (y, x, team, tier) per tower index; 22 = dire ancient, 23 = radiant
## ancient (moba.h:65-70; ancient pids in c_step, moba.h:1909-1952)
const towers = [
  tower(112.015, 34.6, 0, 3),
  tower(96.877, 29.308, 0, 3),
  tower(91.215, 14.292, 0, 3),
  tower(113.615, 64.2, 0, 2),
  tower(112.138, 102.877, 0, 1),
  tower(85.431, 38.292, 0, 2),
  tower(71.708, 17.615, 0, 2),
  tower(51.031, 16.877, 0, 1),
  tower(102.415, 21.062, 0, 4),
  tower(28.262, 103.031, 1, 4),
  tower(18.723, 65.0, 1, 2),
  tower(18.723, 29.062, 1, 1),
  tower(48.754, 84.2, 1, 2),
  tower(59.985, 69.031, 1, 1),
  tower(62.046, 112.754, 1, 2),
  tower(41.677, 113.738, 1, 3),
  tower(20.569, 92.323, 1, 3),
  tower(36.085, 97.862, 1, 3),
  tower(30.908, 105.615, 1, 4),
  tower(104.938, 23.523, 0, 4),
  tower(75.831, 53.123, 0, 1),
  tower(78.3, 113.223, 1, 1),
  tower(26.538, 107.523, 1, 5),   ## dire ancient
  tower(106.169, 19.462, 0, 5),   ## radiant ancient
]
const ancientIndex = [23, 22]     ## per team: own ancient tower index

## (y, x) polylines, lanes 0-2 radiant->dire, 3-5 dire->radiant
## (WAYPOINTS/WAYPOINTS_N, moba.h:71-72)
const waypoints: array[6, seq[(float, float)]] = [
  @[  # lane 0 (radiant top)
    (96.262, 14.046), (93.615, 14.292), (58.231, 16.077),
    (43.4, 16.015), (32.108, 17.585), (24.938, 19.123),
    (22.969, 20.446), (21.062, 25.308), (20.2, 30.477),
    (19.4, 35.892), (18.477, 43.523), (18.046, 50.723),
    (20.508, 94.662), (27.677, 105.946)],
  @[  # lane 1 (radiant mid)
    (99.523, 26.477), (98.662, 27.646), (86.046, 41.123),
    (71.338, 57.492), (66.969, 62.231), (64.077, 66.354),
    (60.2, 72.015), (51.892, 84.877), (34.662, 99.4),
    (28.169, 105.946)],
  @[  # lane 2 (radiant bot)
    (112.015, 36.938), (112.015, 32.508), (116.2, 68.692),
    (113.738, 80.754), (113.554, 90.538), (113.215, 95.985),
    (111.492, 100.938), (109.062, 108.077), (107.185, 111.369),
    (101.738, 114.662), (90.538, 111.769), (39.4, 113.738),
    (28.169, 106.438)],
  @[  # lane 3 (dire top)
    (20.446, 89.369), (20.631, 94.662), (18.785, 50.6),
    (22.292, 24.508), (22.815, 18.815), (27.523, 17.031),
    (35.031, 15.954), (93.615, 14.415), (103.646, 21.992)],
  @[  # lane 4 (dire mid)
    (37.431, 96.508), (34.538, 99.277), (51.708, 84.385),
    (59.831, 71.646), (63.831, 66.108), (66.723, 61.985),
    (70.846, 57.246), (98.538, 27.523), (103.646, 22.485)],
  @[  # lane 5 (dire bot)
    (36.938, 113.246), (39.4, 113.615), (62.292, 114.6),
    (83.646, 114.6), (90.662, 109.8), (94.877, 112.015),
    (104.262, 112.292), (109.308, 107.831), (112.231, 105.862),
    (114.446, 72.969), (111.892, 32.508), (104.138, 22.485)],
]

## Engine step directions in engine order (ATN_MAP, moba.h:58-61):
## S, N, E, W, SW, NW, NE, SE as (dy, dx). Reused for neighbor iteration
## so tie-breaks are deterministic and engine-like.
const steps = [(1, 0), (-1, 0), (0, 1), (0, -1),
               (1, -1), (-1, -1), (-1, 1), (1, 1)]

## Tuning knobs (same values as the Python original)

const
  retreatEnterHealth = 3       ## health tenths; <= enters RETREAT
  retreatExitHealth = 8        ## >= returns to PUSH (hysteresis)
  waypointReached = 2.5        ## chebyshev cells
  teleportDistance = 4.0       ## position jump > this = respawn
  stuckTickLimit = 4           ## unmoved ticks before detouring
  detourTickCount = 5          ## how long one detour burst lasts
  siegeStandoff = towerVision + 1
  creepEngagedDistance = 5     ## friendly creep this close = engaged

## 128x128 wall mask from vendor/upstream/game_map.h (raw grid sha256
## ec17403cd2c93547f0d9da4da8d0d89ab08160153dc3a68e680e8dc9cc430478),
## bit-packed LSB-first (bit i of byte i div 8 = cell i), then base64.
const wallsPackedBase64 =
  "////////////////////////////////////////////////////////////////////////" &
  "//////////////////////////////////////////////////////////8AAAD+AwAAAOD/" &
  "//////9/AAAA/AEAAADg////////PwAAAAAAAAAA4P///////x8AAAAAAAAAAMD///////8P" &
  "AAAAAAAAAADAAAAAvv//BwAAAAAAAAAAwAAAAD7//wMAAAAAAAAAAMAAAAA6/v8BAAAAAAAA" &
  "AIDWAAAAEvz/AAAAAAAAAAAAwAAAAALw/wAAAAAAAAAAAMAAAAAD8P8AAAAAAAAAAAAAAAAA" &
  "APj/AAAAAAAAAAAAAAAAAAD8/wAAAAAAAAAAAAAAAAAA+P8AAAAAAAAAAAAAAAAA4P//AAAA" &
  "AAAAAAAAAAAAABD4/wAAAAAAAAAAAAAAAAAA+P8AAAAAAAAAQgDAAAAAAPj/AAAAAACA/8MH" &
  "wAAAAAD4fwAAAAAAgAAADMAAAAAA+H8AAAAAgAEA4A/AAAAAAPg/AAAAAIACAOAOwAAAAAD4" &
  "HwAAAACAHQDAF8AAAAAA+A8AAACCgQAAADDAAAAAAPhvAAAEAYAAGAAAgAEAAAD4XwAABgCA" &
  "AAgAAIADAAAA+B8AAAAAgAAAAAAAAwAAAPg/AAAAAICAAAAAAAMAAAD4PwAAAAAAwAEAAAAG" &
  "AAAA+D8AAAAAAAAAADAADAAAAPj/AAAAAAAAAIAfABAAAAD4/wAAAAAhAACAAAAAAAAA+P8A" &
  "AACAJwYAgAAAAAAAAPj/AAAAgisPAIAAAAAAAAD4/w8A/mPwHwCAAAAAAgAA+P8PAAMAAAgA" &
  "gBAAAAMAAPj/DwAAAACAAMAAAAAGAAD4/w8AAAADwAAAAAAADAAA+P8PAACAD6DAAQAAAPgB" &
  "APj/DwAHwB+gAAEAAACAQwD4/whgHMBjwACAAAAAAH/g//8AoCDAQIAAgAAAAAAswP//AEAA" &
  "wACAYGAAAAAAAADwPwAAAIEBgKBxAAAAAAAA8D8AAIEDD4DgEQAAAAAAAPA/AIAABw6AIAAA" &
  "AAAAAAD4PwAAgAcAgB8AAAAAAAAA+D8AAIAIAIAAAAAAAAAIAPg/AACAEAAAAwAAAID/BwD4" &
  "PwAAgCAAAAAAAADEAEAA+D8AAIBgAAAAAAAARgAgAPg/AACAIAAAAAAAAAIAIAD4PwAAYAAC" &
  "AAcAAIABgCEA+D8AADAAAwAIAACAAIAiAPg/AAAAgAcACAAAgAAAGQD4PwAABACJAAgAAIAA" &
  "AAgA+D8AAAaA9xgIAACAAAAGAPg/AAACgAEgCAAAgAAAAgD4PwCAAYAAIBAAAAAAAAMA+D8A" &
  "wADAACAAAAAAAAAAAPg/AOAAAIBBAAAAGAAAAAD4PwDgAAyAwwABAAgAAAAA+D8A4AAAgIOB" &
  "HgAIAAAGAPg/AOAAwIADAKAACAAACAD4PwDgAACBAwDA+AcAAAYA+D8A4AAAggMQAKACAAAC" &
  "APg/AOD4AfwDeAAgAQB+BAD4PwDgqAL8A5AAIAAAwggA+D8AYPAB9gEAB8AHAEAJAPg/ACAA" &
  "AAIAAAgADgAACgD4PwAgAAABAAAQAAZgAAQA+D8AIAAAAAAAAAACIAAAAPg/AAAAAAAAAIAA" &
  "4P8BAAD4fwAAAQAAAADAAPBgAgAA+H8AgAEYAAAAAAF4AAAAAPh/AAACDAAAAAACAAAQAAD4" &
  "fwAG/AcAAADgBwAAeAAA+P8ADgAAAAAAoAgAAKAAAPj/AAQAAAAAAGAAAABAAAD4/wAAAAAA" &
  "AAAgSAQAwAAA+H8AAAAAAAAAEHD8AQAA4P9/AgEAAAAAAABgjAMAAOD//wMfAAAAAHgAQAQG" &
  "AADA9w8AIAAAAACIAgAAOsEAAPAPAMAHAAAABgEAgDl+AADwDwAADAAAAAIAAMAAAAAA4A8A" &
  "ABgAAAAEAAAAAAAAAOAPAAAAAAAACAAAAAAAAADgDwAAAAAAAAQAAIAAAAAA4A8AAAAAAAAA" &
  "AACAAAAAAOAPAAAAAgAAAOAHYBgAAADgDwAAAAMAgADgDiA4AAAA+A8AAAAGAGAAwAdAEAAA" &
  "AOAPAAAADAAgAAAAgAAAAADgDwAAAAgAGOABAH4AAAAA8A8AAAAIAAggAgACAAAAAOAPAAAA" &
  "CAAGwAEAAMCAAADgDwAAAAgACgAAAADAYAAA4A8AAAAQAAQAAGAAAAAAAPgPAAAAIAAIAAAg" &
  "AAAAAAD4DwAAADAAAAAAIAAAAAAA+A8AAAAwAEAARCAAAAAAAPgPAAAAIADggccZAAAAAAD4" &
  "DwAAADAAAIMACgAAAAAA+P8HAAAAgAF+AAQAAAAAAPh/AAAAAIADAAAAAAAAAAD4fwAAAAAA" &
  "AQAAAAAAAAAA+H8AAAAAAAAAAAAAAAAAAPh/gAAAAAAAAAAAAAAAAAD+P8AAAAAAAAAAAAAA" &
  "AAAA/j+AAAAgAAAAAAAAAAAAgP8/wAAAMAAAAAAAAAAAAID/f8AAADD4DwAAAAAAAADg///A" &
  "AAAg+A8AAAAAAAAA4P//8AAA4P//AOB+OPgAAP7///sBAOD/////////////////////////" &
  "////////////////////////////////////////////////////////////////////////" &
  "//////////////////////////////////////////////////////////////////8="

proc decodeWalls(): seq[bool] =
  let packed = decode(wallsPackedBase64)
  doAssert packed.len == mapWidth * mapWidth div 8
  result = newSeq[bool](mapWidth * mapWidth)
  for i in 0 ..< result.len:
    result[i] = (packed[i div 8].uint8 shr (i mod 8) and 1) != 0

## Perception

type HeroView = object
  ## Decoded 510-byte observation: the reliable fields only (module
  ## docstring). Self bytes are obs[484..509] (moba.h:480-503).
  x, y: int
  level: int
  health10: int          ## health * 10 / max, 0..10
  mana10: int            ## mana * 10 / max, 0..10
  team: int              ## 0 radiant, 1 dire
  heroType: int          ## 0..4 support/assassin/burst/tank/carry
  crop: array[cropTiles, uint8]   ## the 121 reliable tile ids, row-major

proc tile(view: HeroView, dy, dx: int): int =
  ## Crop tile id at offset (dy, dx) from self; -1 if outside.
  if abs(dy) > visionRange or abs(dx) > visionRange:
    return -1
  int(view.crop[(dy + visionRange) * cropWidth + (dx + visionRange)])

proc maxMana(view: HeroView): int =
  let (base, gain) = manaTable[view.heroType]
  base + view.level * gain

proc manaAtLeast(view: HeroView, cost: int): bool =
  ## Conservative: mana10 floor-scaled, so mana >= mana10/10*max.
  view.mana10 * view.maxMana() >= cost * 10

proc parseView(observation: string): HeroView =
  ## Decode one 510-byte observation. Robust to garbage: hero_type falls
  ## back to 0 when the one-hot region is empty, team is clamped to 0/1.
  doAssert observation.len == observationSize
  template selfByte(i: int): int = int(observation[selfOffset + i].uint8)
  var heroType = 0
  var bestHot = 0
  for i in 0 ..< 5:
    if selfByte(17 + i) > bestHot:
      bestHot = selfByte(17 + i)
      heroType = i
  result = HeroView(
    x: selfByte(0), y: selfByte(1), level: selfByte(2),
    health10: selfByte(3), mana10: selfByte(4),
    team: if selfByte(16) == 1: 1 else: 0,
    heroType: heroType)
  for i in 0 ..< cropTiles:
    result.crop[i] = observation[i].uint8

proc isEnemyHeroTile(team, tileId: int): bool =
  if team == 0: tileId in 11 .. 15 else: tileId in 6 .. 10

proc enemyCreepTile(team: int): int =
  if team == 0: direCreepTile else: radiantCreepTile

proc friendlyCreepTile(team: int): int =
  if team == 0: radiantCreepTile else: direCreepTile

## Navigation: BFS cost fields over the embedded static map

const unreached = 0xFFFF'u16

type NavGrid = object
  ## 8-connected uniform-cost BFS from each goal (same connectivity as
  ## the engine's own bfs, moba.h:242-320), cached per goal cell. Known
  ## tower cells are treated as walls (towers block move_to; avoiding a
  ## dead tower's cell is harmless). A wall goal cell is force-opened so
  ## fields toward the enemy ancient still resolve.
  walls: seq[bool]
  fields: Table[(int, int), seq[uint16]]

proc initNavGrid(): NavGrid =
  result.walls = decodeWalls()
  for t in towers:
    result.walls[int(t.y) * mapWidth + int(t.x)] = true
  result.fields = initTable[(int, int), seq[uint16]]()

proc costField(nav: var NavGrid, goal: (int, int)): lent seq[uint16] =
  if goal notin nav.fields:
    var distance = newSeq[uint16](mapWidth * mapWidth)
    for i in 0 ..< distance.len:
      distance[i] = unreached
    let
      gy = clamp(goal[0], 0, mapWidth - 1)
      gx = clamp(goal[1], 0, mapWidth - 1)
      start = gy * mapWidth + gx
    distance[start] = 0
    var queue = initDeque[int]()
    queue.addLast(start)
    while queue.len > 0:
      let address = queue.popFirst()
      let d1 = distance[address] + 1
      let y = address div mapWidth
      let x = address mod mapWidth
      for (dy, dx) in steps:
        let ny = y + dy
        let nx = x + dx
        if ny < 0 or ny >= mapWidth or nx < 0 or nx >= mapWidth:
          continue
        let neighbor = ny * mapWidth + nx
        if distance[neighbor] != unreached or nav.walls[neighbor]:
          continue
        distance[neighbor] = d1
        queue.addLast(neighbor)
    nav.fields[goal] = distance
  nav.fields[goal]

proc sign(v: int): int =
  if v > 0: 1 elif v < 0: -1 else: 0

proc stepToward(nav: var NavGrid, y, x: int, goal: (int, int)): (int, int) =
  ## Best (dy, dx) unit step from (y, x) toward goal. Descends the
  ## goal's cost field; deterministic tie-break in steps order. Falls
  ## back to the greedy sign step when the current cell is unreachable
  ## from the goal.
  let (gy, gx) = goal
  if abs(y - gy) <= 1 and abs(x - gx) <= 1:
    return (0, 0)
  let field = nav.costField(goal)
  let here =
    if y >= 0 and y < mapWidth and x >= 0 and x < mapWidth:
      field[y * mapWidth + x]
    else:
      unreached
  var best = (0, 0)
  var bestDistance = unreached
  var found = false
  for (dy, dx) in steps:
    let ny = y + dy
    let nx = x + dx
    if ny < 0 or ny >= mapWidth or nx < 0 or nx >= mapWidth:
      continue
    let d = field[ny * mapWidth + nx]
    if d == unreached:
      continue
    if not found or d < bestDistance:
      best = (dy, dx)
      bestDistance = d
      found = true
  if found and (here == unreached or bestDistance < here):
    return best
  (sign(gy - y), sign(gx - x))

proc occupancyReroute(nav: var NavGrid, view: HeroView,
                      goal: (int, int)): (int, int) =
  ## Best empty 8-neighbor by existing BFS goal cost, or (0, 0).
  ## Used when the chosen step would enter a non-empty crop tile.
  ## Unreached cells (walls, dead-tower cells in the nav mask) are
  ## not useful; if no empty reached neighbor exists this is a no-op.
  let field = nav.costField(goal)
  var best = (0, 0)
  var bestDistance = unreached
  var found = false
  for (dy, dx) in steps:
    if view.tile(dy, dx) != emptyTile:
      continue
    let ny = view.y + dy
    let nx = view.x + dx
    if ny < 0 or ny >= mapWidth or nx < 0 or nx >= mapWidth:
      continue
    let d = field[ny * mapWidth + nx]
    if d == unreached:
      continue
    if not found or d < bestDistance:
      best = (dy, dx)
      bestDistance = d
      found = true
  if found:
    return best
  (0, 0)

## Per-hero state machine

type HeroMode = enum
  PushMode, RetreatMode

type HeroState = ref object
  mode: HeroMode
  waypointIndex: int       ## next waypoint to visit; -1 = unset
  hasLastPos: bool
  lastPos: (int, int)
  triedMove: bool          ## did LAST tick want to move?
  stuckTicks: int
  detourLeft: int
  detourSide: int          ## +1 / -1, alternates

proc newHeroState(): HeroState =
  HeroState(mode: PushMode, waypointIndex: -1, detourSide: 1)

proc rotate90(dy, dx, side: int): (int, int) =
  ## (dy, dx) rotated 90 degrees; side=+1 clockwise on screen.
  (side * dx, -side * dy)

## The policy

type GorynychPolicy = ref object
  nav: NavGrid
  heroes: Table[int, HeroState]
  deadTowers: HashSet[int]   ## shared world model across the seat's heroes
  heroCalls: int
  triggers: int
  changedActions: int
  occupancyNoops: int
  trialEmitted: bool

proc newGorynychPolicy(): GorynychPolicy =
  GorynychPolicy(nav: initNavGrid(),
                 heroes: initTable[int, HeroState](),
                 deadTowers: initHashSet[int]())

proc trialPayload(policy: GorynychPolicy): JsonNode =
  ## Bounded per-episode occupancy counters. Echo-only; no action input.
  %*{
    "idea": "occupancy-aware navigation",
    "heroCalls": policy.heroCalls,
    "triggers": policy.triggers,
    "changedActions": policy.changedActions,
    "occupancyNoops": policy.occupancyNoops
  }

proc emitTrial(policy: GorynychPolicy) =
  ## Write a MOBA_TRIAL JSON line with cumulative occupancy counters.
  echo "MOBA_TRIAL ", policy.trialPayload()

proc noteHeroCall(policy: GorynychPolicy, triggered, changed: bool) =
  ## Count one heroAction. First trigger and every 1000 calls emit.
  inc policy.heroCalls
  if triggered:
    inc policy.triggers
    if changed:
      inc policy.changedActions
    if not policy.trialEmitted:
      policy.trialEmitted = true
      emitTrial(policy)
  if policy.heroCalls mod 1000 == 0:
    emitTrial(policy)

proc updateTowerMemory(policy: GorynychPolicy, view: HeroView) =
  ## A tower whose known cell is visible in the crop without a TOWER
  ## tile is remembered dead (kill_entity zeroes the cell, moba.h:632).
  for index, t in towers:
    if index in policy.deadTowers:
      continue
    let dy = int(t.y) - view.y
    let dx = int(t.x) - view.x
    if abs(dy) <= visionRange and abs(dx) <= visionRange:
      if view.tile(dy, dx) != towerTile:
        policy.deadTowers.incl(index)

proc nearestLiveEnemyTower(policy: GorynychPolicy,
                           view: HeroView): (int, int) =
  ## (tower index, chebyshev distance) of the closest live enemy tower
  ## that can actually shoot, or (-1, 0). Ancients (tier 5) are exempt:
  ## TOWER_DAMAGE is 0 for both (moba.h:65) — diving them is free.
  result = (-1, 0)
  var bestDistance = 0
  for index, t in towers:
    if t.team == view.team or t.tier == 5 or index in policy.deadTowers:
      continue
    let d = max(abs(int(t.y) - view.y), abs(int(t.x) - view.x))
    if result[0] < 0 or d < bestDistance:
      result = (index, d)
      bestDistance = d

proc lane(view: HeroView): lent seq[(float, float)] =
  waypoints[laneForHero[view.heroType] + 3 * view.team]

proc nearestWaypoint(view: HeroView, lanePoints: seq[(float, float)]): int =
  var bestDistance = 0.0
  for i, (wy, wx) in lanePoints:
    let d = max(abs(wy - float(view.y)), abs(wx - float(view.x)))
    if i == 0 or d < bestDistance:
      result = i
      bestDistance = d

proc pushGoal(view: HeroView, state: HeroState): (int, int) =
  let lanePoints = view.lane()
  if state.waypointIndex < 0:
    state.waypointIndex = nearestWaypoint(view, lanePoints)
  while state.waypointIndex < lanePoints.len:
    let (wy, wx) = lanePoints[state.waypointIndex]
    if max(abs(wy - float(view.y)), abs(wx - float(view.x))) >
        waypointReached:
      return (int(wy), int(wx))
    inc state.waypointIndex
  let ancient = towers[ancientIndex[1 - view.team]]
  (int(ancient.y), int(ancient.x))

proc cropScan(view: HeroView): (int, int, seq[(int, int)]) =
  ## (enemy hero distance, hostile creep distance, friendly creep cells)
  ## from the reliable crop tiles; distances are chebyshev or -1.
  var heroDistance = -1
  var creepDistance = -1
  var friendlyCells: seq[(int, int)]
  let hostileCreep = enemyCreepTile(view.team)
  let friendlyCreep = friendlyCreepTile(view.team)
  for dy in -visionRange .. visionRange:
    let yy = view.y + dy
    if yy < 0 or yy >= mapWidth:
      continue
    for dx in -visionRange .. visionRange:
      let xx = view.x + dx
      if xx < 0 or xx >= mapWidth:
        continue
      let t = int(view.crop[(dy + visionRange) * cropWidth +
                            (dx + visionRange)])
      if t == emptyTile or t == wallTile:
        continue
      let d = max(abs(dy), abs(dx))
      if isEnemyHeroTile(view.team, t):
        if heroDistance < 0 or d < heroDistance:
          heroDistance = d
      elif t == hostileCreep:
        if creepDistance < 0 or d < creepDistance:
          creepDistance = d
      elif t == friendlyCreep:
        friendlyCells.add((yy, xx))
  (heroDistance, creepDistance, friendlyCells)

proc skillFlags(view: HeroView, mode: HeroMode,
                heroDistance, creepDistance: int): (int, int, int) =
  ## (use_q, use_w, use_e) per role (moba.h:1151-1362). The engine
  ## re-checks cooldown/mana/target and fails skills harmlessly, so
  ## these are intent flags, gated just enough to avoid wasting mana.
  let enemyHero = heroDistance >= 0
  let hostile = enemyHero or creepDistance >= 0
  template flag(condition: bool): int = (if condition: 1 else: 0)
  case view.heroType
  of supportHero:      # hook / aoe heal / stun
    (flag(enemyHero and view.manaAtLeast(100)),
     flag(view.health10 <= 6 and view.manaAtLeast(100)),
     flag(enemyHero and view.manaAtLeast(75)))
  of assassinHero:     # aoe minions / tp nuke / haste
    (flag(creepDistance >= 0 and view.manaAtLeast(100)),
     flag(enemyHero and view.health10 >= 5 and view.manaAtLeast(150)),
     flag(mode == RetreatMode and view.manaAtLeast(100)))
  of burstHero:        # nuke / aoe / aoe stun
    (flag(enemyHero and view.manaAtLeast(200)),
     flag(enemyHero and view.manaAtLeast(100)),
     flag(enemyHero and view.manaAtLeast(75)))
  of tankHero:         # aoe dot / self heal / engage
    (flag(hostile and view.health10 > 5 and view.manaAtLeast(5)),
     flag(view.health10 <= 5 and view.manaAtLeast(100)),
     flag(enemyHero and view.health10 > 6 and view.manaAtLeast(50)))
  else:                # carry: retreat slow / slow nuke / aoe
    (flag(mode == RetreatMode and hostile and view.manaAtLeast(25)),
     flag(enemyHero and view.manaAtLeast(150)),
     flag(creepDistance >= 0 and view.manaAtLeast(100)))

proc heroAction(policy: GorynychPolicy, index: int,
                observation: string): array[6, int] =
  if observation.len != observationSize:
    policy.noteHeroCall(false, false)
    return [3, 3, 0, 0, 0, 0]     ## malformed row: no-op, never crash
  let view = parseView(observation)
  if index notin policy.heroes:
    policy.heroes[index] = newHeroState()
  let state = policy.heroes[index]
  policy.updateTowerMemory(view)

  # respawn/teleport detection resets waypoint tracking
  let position = (view.y, view.x)
  if state.hasLastPos and
      max(abs(position[0] - state.lastPos[0]),
          abs(position[1] - state.lastPos[1])) > int(teleportDistance):
    state.waypointIndex = -1
    state.stuckTicks = 0
    state.detourLeft = 0

  # mode with hysteresis
  if state.mode == PushMode and view.health10 <= retreatEnterHealth:
    state.mode = RetreatMode
  elif state.mode == RetreatMode and view.health10 >= retreatExitHealth:
    state.mode = PushMode
    state.waypointIndex = -1      # re-anchor to the nearest waypoint

  let (heroDistance, creepDistance, friendlyCreeps) = cropScan(view)

  # goal selection
  var hold = false
  var goal: (int, int)
  if state.mode == RetreatMode:
    goal = spawns[view.team]
  else:
    goal = pushGoal(view, state)
    let (towerIdx, towerDistance) = policy.nearestLiveEnemyTower(view)
    if towerIdx >= 0 and towerDistance <= siegeStandoff:
      let ty = int(towers[towerIdx].y)
      let tx = int(towers[towerIdx].x)
      var engaged = false
      for (cy, cx) in friendlyCreeps:
        if max(abs(cy - ty), abs(cx - tx)) <= creepEngagedDistance:
          engaged = true
          break
      if engaged:
        goal = (ty, tx)               # push onto the tower
      elif towerDistance <= towerVision:
        goal = spawns[view.team]      # inside range, no wave: out
      else:
        hold = true                   # at standoff: wait for creeps

  # steering
  var (dy, dx) = if hold: (0, 0)
                 else: policy.nav.stepToward(view.y, view.x, goal)

  # stuck detection -> deterministic 90-degree detour. A tick only
  # counts as stuck if the PREVIOUS tick actually tried to move and the
  # position stayed put; coming out of an intentional hold must not
  # count as a phantom stuck tick.
  if state.triedMove and state.hasLastPos and state.lastPos == position and
      (dy != 0 or dx != 0):
    inc state.stuckTicks
  else:
    state.stuckTicks = 0
  if state.detourLeft > 0:
    dec state.detourLeft
    (dy, dx) = rotate90(dy, dx, state.detourSide)
  elif state.stuckTicks >= stuckTickLimit:
    state.detourLeft = detourTickCount
    state.detourSide = -state.detourSide
    state.stuckTicks = 0
    (dy, dx) = rotate90(dy, dx, state.detourSide)
  # Occupancy: if the chosen step (including a detour) would enter a
  # currently non-empty observed crop tile, step to the empty
  # 8-neighbor with the best existing BFS goal cost instead. No empty
  # useful neighbor is a no-op. Does not change the goal.
  var
    occupancyTriggered = false
    occupancyChanged = false
  if dy != 0 or dx != 0:
    let destTile = view.tile(dy, dx)
    if destTile >= 0 and destTile != emptyTile:
      occupancyTriggered = true
      let before = (dy, dx)
      (dy, dx) = occupancyReroute(policy.nav, view, goal)
      occupancyChanged = (dy, dx) != before
      if dy == 0 and dx == 0:
        inc policy.occupancyNoops
  state.triedMove = dy != 0 or dx != 0
  state.lastPos = position
  state.hasLastPos = true

  # target filter: everything while hostile creeps are around (lane
  # XP), heroes+towers otherwise (focus towers, no neutral camp aggro)
  let targetFilter = if creepDistance >= 0: 0 else: 2
  let (useQ, useW, useE) = skillFlags(view, state.mode,
                                      heroDistance, creepDistance)
  policy.noteHeroCall(occupancyTriggered, occupancyChanged)
  [3 + 3 * dy, 3 + 3 * dx, targetFilter, useQ, useW, useE]

## Wire loop (docs/protocol_player.md): lockstep JSON with bounded
## reconnects — a connection that answered at least one tick resets the
## failure budget, mirroring the upstream players/client.py.

proc main() =
  let url = getEnv("COWORLD_PLAYER_WS_URL",
                   getEnv("COGAMES_ENGINE_WS_URL"))
  if url == "":
    quit("gorynych: COWORLD_PLAYER_WS_URL is not set", 1)
  let policy = newGorynychPolicy()

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
          quit("gorynych: game never accepted a connection", 1)
      else:
        inc failures
        if failures >= reconnectAttempts:
          quit("gorynych: reconnect budget exhausted", 1)
      sleep(connectRetryMs)
      continue
    if not everConnected:
      echo "gorynych: connected"
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
          emitTrial(policy)
          echo "gorynych: episode done, result ", parsed{"result"}
          quit(0)
        if not parsed.hasKey("tick") or not parsed.hasKey("obs"):
          continue
        var actions = newJArray()
        for i, row in parsed["obs"].getElems():
          let action = policy.heroAction(i, decode(row.getStr()))
          var actionRow = newJArray()
          for v in action:
            actionRow.add(%v)
          actions.add(actionRow)
        socket.send($(%*{"tick": parsed["tick"], "actions": actions}))
        inc answered
    except CatchableError:
      echo "gorynych: socket closed (", getCurrentExceptionMsg(), ")"
    if answered > 0:
      failures = 0     # made progress: fresh reconnect budget
    inc failures
    if failures >= reconnectAttempts:
      quit("gorynych: connection closed before done, budget exhausted", 1)
    sleep(connectRetryMs)

when not defined(policyTest):
  main()
