## Bogatyr — Derks Gym policy for Andre von Auto.
## Command player: a Nim port of the strongest no-network example,
## `lane-brawler` (players/scripted_player.py + the brawler draft rule in
## players/derk_player.py). One draft reply derived from the OBSERVED
## base stats, then a per-tick finite-state lane-push bot: BFS steering
## over the embedded static wall grid, lane waypoints toward the enemy
## Ancient, siege standoff outside live tower range until a friendly
## creep wave engages, retreat-to-fountain with hysteresis at low health,
## a deterministic 90-degree stuck detour, and per-role skill flags.
## Deterministic, zero model calls — no secret-envs needed at upload.
##
## Ground truth for every constant is the vendored upstream source,
## vendor/upstream/moba.h, via the reference player's own citations.

import std/[base64, deques, json, tables], coworld_client

## Tile ids (moba.h:28-43)

const
  EmptyTile = 0
  WallTile = 1
  TowerTile = 2
  RadiantCreepTile = 3
  DireCreepTile = 4

const
  ObsSize = 510
  CropTiles = 121   ## reliable prefix of the 484-byte crop region
  CropW = 11
  Vis = 5           ## vision_range (sim/shim_common.h:17)
  SelfOff = 484     ## 11*11*4
  MapW = 128

## Hero roles (init_moba, moba.h:1661-1744)

const
  SupportHero = 0
  AssassinHero = 1
  BurstHero = 2
  TankHero = 3
  # CarryHero = 4 is the table's last row; never a seat in this game.
  laneForHero = [2, 1, 1, 0, 2]  ## hero_type -> radiant lane (dire adds 3)
  manaTable = [(250, 50), (300, 65), (300, 90), (200, 50), (250, 50)]
  spawnByTeam = [(113, 12), (15, 116)]  ## fountain cells (moba.h:1636-1643)
  TowerVision = 5   ## moba.h:45

type Tower = object
  y, x: float
  team, tier: int

## (y, x, team, tier) per tower index; 22 = dire ancient, 23 = radiant
## ancient (moba.h:65-70; ancient pids in c_step, moba.h:1909-1952).
const towers = [
  Tower(y: 112.015, x: 34.6, team: 0, tier: 3),
  Tower(y: 96.877, x: 29.308, team: 0, tier: 3),
  Tower(y: 91.215, x: 14.292, team: 0, tier: 3),
  Tower(y: 113.615, x: 64.2, team: 0, tier: 2),
  Tower(y: 112.138, x: 102.877, team: 0, tier: 1),
  Tower(y: 85.431, x: 38.292, team: 0, tier: 2),
  Tower(y: 71.708, x: 17.615, team: 0, tier: 2),
  Tower(y: 51.031, x: 16.877, team: 0, tier: 1),
  Tower(y: 102.415, x: 21.062, team: 0, tier: 4),
  Tower(y: 28.262, x: 103.031, team: 1, tier: 4),
  Tower(y: 18.723, x: 65.0, team: 1, tier: 2),
  Tower(y: 18.723, x: 29.062, team: 1, tier: 1),
  Tower(y: 48.754, x: 84.2, team: 1, tier: 2),
  Tower(y: 59.985, x: 69.031, team: 1, tier: 1),
  Tower(y: 62.046, x: 112.754, team: 1, tier: 2),
  Tower(y: 41.677, x: 113.738, team: 1, tier: 3),
  Tower(y: 20.569, x: 92.323, team: 1, tier: 3),
  Tower(y: 36.085, x: 97.862, team: 1, tier: 3),
  Tower(y: 30.908, x: 105.615, team: 1, tier: 4),
  Tower(y: 104.938, x: 23.523, team: 0, tier: 4),
  Tower(y: 75.831, x: 53.123, team: 0, tier: 1),
  Tower(y: 78.3, x: 113.223, team: 1, tier: 1),
  Tower(y: 26.538, x: 107.523, team: 1, tier: 5),  # dire ancient
  Tower(y: 106.169, x: 19.462, team: 0, tier: 5)   # radiant ancient
]
const ancientIndexByTeam = [23, 22]  ## per team: OWN ancient tower index

## (y, x) polylines, lanes 0-2 radiant->dire, 3-5 dire->radiant
## (WAYPOINTS/WAYPOINTS_N, moba.h:71-72).
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
    (114.446, 72.969), (111.892, 32.508), (104.138, 22.485)]
]

## Engine step directions in engine order (ATN_MAP, moba.h:58-61):
## S, N, E, W, SW, NW, NE, SE as (dy, dx). Reused for neighbor iteration
## so tie-breaks are deterministic and engine-like.
const steps = [(1, 0), (-1, 0), (0, 1), (0, -1),
               (1, -1), (-1, -1), (-1, 1), (1, 1)]

## Tuning knobs (reference player's values)

const
  RetreatEnterHp = 3       ## health tenths; <= enters retreat
  RetreatExitHp = 8        ## >= returns to push (hysteresis)
  WaypointReached = 2.5    ## chebyshev cells
  TeleportDist = 4.0       ## position jump > this = respawn/displacement
  StuckTickLimit = 4       ## unmoved ticks before detouring
  DetourTickCount = 5      ## how long one detour burst lasts
  SiegeStandoff = TowerVision + 1
  CreepEngagedDist = 5     ## friendly creep within this of tower = engaged

## The 128x128 wall mask from vendor/upstream/game_map.h (raw grid
## sha256 ec17403c...), bit-packed LSB-first, 2048 bytes, base64.
const wallsPacked =
  "////////////////////////////////////////////////////////////////" &
  "////////////////////////////////////////////////////////////////" &
  "//8AAAD+AwAAAOD///////9/AAAA/AEAAADg////////PwAAAAAAAAAA4P//////" &
  "/x8AAAAAAAAAAMD///////8PAAAAAAAAAADAAAAAvv//BwAAAAAAAAAAwAAAAD7/" &
  "/wMAAAAAAAAAAMAAAAA6/v8BAAAAAAAAAIDWAAAAEvz/AAAAAAAAAAAAwAAAAALw" &
  "/wAAAAAAAAAAAMAAAAAD8P8AAAAAAAAAAAAAAAAAAPj/AAAAAAAAAAAAAAAAAAD8" &
  "/wAAAAAAAAAAAAAAAAAA+P8AAAAAAAAAAAAAAAAA4P//AAAAAAAAAAAAAAAAABD4" &
  "/wAAAAAAAAAAAAAAAAAA+P8AAAAAAAAAQgDAAAAAAPj/AAAAAACA/8MHwAAAAAD4" &
  "fwAAAAAAgAAADMAAAAAA+H8AAAAAgAEA4A/AAAAAAPg/AAAAAIACAOAOwAAAAAD4" &
  "HwAAAACAHQDAF8AAAAAA+A8AAACCgQAAADDAAAAAAPhvAAAEAYAAGAAAgAEAAAD4" &
  "XwAABgCAAAgAAIADAAAA+B8AAAAAgAAAAAAAAwAAAPg/AAAAAICAAAAAAAMAAAD4" &
  "PwAAAAAAwAEAAAAGAAAA+D8AAAAAAAAAADAADAAAAPj/AAAAAAAAAIAfABAAAAD4" &
  "/wAAAAAhAACAAAAAAAAA+P8AAACAJwYAgAAAAAAAAPj/AAAAgisPAIAAAAAAAAD4" &
  "/w8A/mPwHwCAAAAAAgAA+P8PAAMAAAgAgBAAAAMAAPj/DwAAAACAAMAAAAAGAAD4" &
  "/w8AAAADwAAAAAAADAAA+P8PAACAD6DAAQAAAPgBAPj/DwAHwB+gAAEAAACAQwD4" &
  "/whgHMBjwACAAAAAAH/g//8AoCDAQIAAgAAAAAAswP//AEAAwACAYGAAAAAAAADw" &
  "PwAAAIEBgKBxAAAAAAAA8D8AAIEDD4DgEQAAAAAAAPA/AIAABw6AIAAAAAAAAAD4" &
  "PwAAgAcAgB8AAAAAAAAA+D8AAIAIAIAAAAAAAAAIAPg/AACAEAAAAwAAAID/BwD4" &
  "PwAAgCAAAAAAAADEAEAA+D8AAIBgAAAAAAAARgAgAPg/AACAIAAAAAAAAAIAIAD4" &
  "PwAAYAACAAcAAIABgCEA+D8AADAAAwAIAACAAIAiAPg/AAAAgAcACAAAgAAAGQD4" &
  "PwAABACJAAgAAIAAAAgA+D8AAAaA9xgIAACAAAAGAPg/AAACgAEgCAAAgAAAAgD4" &
  "PwCAAYAAIBAAAAAAAAMA+D8AwADAACAAAAAAAAAAAPg/AOAAAIBBAAAAGAAAAAD4" &
  "PwDgAAyAwwABAAgAAAAA+D8A4AAAgIOBHgAIAAAGAPg/AOAAwIADAKAACAAACAD4" &
  "PwDgAACBAwDA+AcAAAYA+D8A4AAAggMQAKACAAACAPg/AOD4AfwDeAAgAQB+BAD4" &
  "PwDgqAL8A5AAIAAAwggA+D8AYPAB9gEAB8AHAEAJAPg/ACAAAAIAAAgADgAACgD4" &
  "PwAgAAABAAAQAAZgAAQA+D8AIAAAAAAAAAACIAAAAPg/AAAAAAAAAIAA4P8BAAD4" &
  "fwAAAQAAAADAAPBgAgAA+H8AgAEYAAAAAAF4AAAAAPh/AAACDAAAAAACAAAQAAD4" &
  "fwAG/AcAAADgBwAAeAAA+P8ADgAAAAAAoAgAAKAAAPj/AAQAAAAAAGAAAABAAAD4" &
  "/wAAAAAAAAAgSAQAwAAA+H8AAAAAAAAAEHD8AQAA4P9/AgEAAAAAAABgjAMAAOD/" &
  "/wMfAAAAAHgAQAQGAADA9w8AIAAAAACIAgAAOsEAAPAPAMAHAAAABgEAgDl+AADw" &
  "DwAADAAAAAIAAMAAAAAA4A8AABgAAAAEAAAAAAAAAOAPAAAAAAAACAAAAAAAAADg" &
  "DwAAAAAAAAQAAIAAAAAA4A8AAAAAAAAAAACAAAAAAOAPAAAAAgAAAOAHYBgAAADg" &
  "DwAAAAMAgADgDiA4AAAA+A8AAAAGAGAAwAdAEAAAAOAPAAAADAAgAAAAgAAAAADg" &
  "DwAAAAgAGOABAH4AAAAA8A8AAAAIAAggAgACAAAAAOAPAAAACAAGwAEAAMCAAADg" &
  "DwAAAAgACgAAAADAYAAA4A8AAAAQAAQAAGAAAAAAAPgPAAAAIAAIAAAgAAAAAAD4" &
  "DwAAADAAAAAAIAAAAAAA+A8AAAAwAEAARCAAAAAAAPgPAAAAIADggccZAAAAAAD4" &
  "DwAAADAAAIMACgAAAAAA+P8HAAAAgAF+AAQAAAAAAPh/AAAAAIADAAAAAAAAAAD4" &
  "fwAAAAAAAQAAAAAAAAAA+H8AAAAAAAAAAAAAAAAAAPh/gAAAAAAAAAAAAAAAAAD+" &
  "P8AAAAAAAAAAAAAAAAAA/j+AAAAgAAAAAAAAAAAAgP8/wAAAMAAAAAAAAAAAAID/" &
  "f8AAADD4DwAAAAAAAADg///AAAAg+A8AAAAAAAAA4P//8AAA4P//AOB+OPgAAP7/" &
  "//sBAOD/////////////////////////////////////////////////////////" &
  "////////////////////////////////////////////////////////////////" &
  "//////////////////////////////////////////8="

proc decodeWalls(): seq[bool] =
  let packed = decode(wallsPacked)
  doAssert packed.len == MapW * MapW div 8, "embedded wall grid wrong size"
  result = newSeq[bool](MapW * MapW)
  for i in 0 ..< MapW * MapW:
    result[i] = (ord(packed[i div 8]) shr (i mod 8) and 1) != 0

## Perception

type HeroObs = object
  x, y, level: int
  health10, mana10: int   ## health * 10 / max, 0..10
  team: int               ## 0 radiant, 1 dire
  heroType: int           ## 0..4 support/assassin/burst/tank/carry
  crop: array[CropTiles, int]

proc tile(s: HeroObs, dy, dx: int): int =
  ## Crop tile id at offset (dy, dx) from self; -1 if outside.
  if abs(dy) > Vis or abs(dx) > Vis:
    return -1
  s.crop[(dy + Vis) * CropW + (dx + Vis)]

proc maxMana(s: HeroObs): int =
  let (base, gain) = manaTable[s.heroType]
  base + s.level * gain

proc manaAtLeast(s: HeroObs, cost: int): bool =
  ## Conservative: mana10 floor-scaled, so mana >= mana10/10*max.
  s.mana10 * s.maxMana() >= cost * 10

proc parseObs(obs: string): HeroObs =
  ## Decode one 510-byte observation row (compute_observations,
  ## moba.h:460-533). Bytes 0..120 are the 121 reliable crop tile ids;
  ## the self block starts at byte 484.
  doAssert obs.len == ObsSize, "obs must be 510 bytes"
  template selfByte(i: int): int = ord(obs[SelfOff + i])
  result.x = selfByte(0)
  result.y = selfByte(1)
  result.level = selfByte(2)
  result.health10 = selfByte(3)
  result.mana10 = selfByte(4)
  result.team = if selfByte(16) == 1: 1 else: 0
  # Hero one-hot at self bytes 17..21; fall back to support when empty.
  result.heroType = 0
  var bestOneHot = 0
  for i in 0 .. 4:
    if selfByte(17 + i) > bestOneHot:
      bestOneHot = selfByte(17 + i)
      result.heroType = i
  for i in 0 ..< CropTiles:
    result.crop[i] = ord(obs[i])

proc enemyHeroTile(team, tileId: int): bool =
  if team == 0: tileId in 11 .. 15 else: tileId in 6 .. 10

proc enemyCreepTile(team: int): int =
  if team == 0: DireCreepTile else: RadiantCreepTile

proc friendlyCreepTile(team: int): int =
  if team == 0: RadiantCreepTile else: DireCreepTile

## Navigation: BFS cost fields over the embedded static map, cached per
## goal cell (all goals are static). Known tower cells are treated as
## walls: towers block move_to, and avoiding a dead tower's cell is
## harmless. A wall goal cell is force-opened by BFS from it anyway.

const Unreached = high(int32)

type NavGrid = object
  walls: seq[bool]
  fields: Table[(int, int), seq[int32]]

proc initNavGrid(): NavGrid =
  result.walls = decodeWalls()
  for tower in towers:
    result.walls[int(tower.y) * MapW + int(tower.x)] = true
  result.fields = initTable[(int, int), seq[int32]]()

proc field(nav: var NavGrid, goal: (int, int)): seq[int32] =
  if goal notin nav.fields:
    var dist = newSeq[int32](MapW * MapW)
    for i in 0 ..< dist.len:
      dist[i] = Unreached
    let
      gy = clamp(goal[0], 0, MapW - 1)
      gx = clamp(goal[1], 0, MapW - 1)
      start = gy * MapW + gx
    dist[start] = 0
    var queue = initDeque[int]()
    queue.addLast(start)
    while queue.len > 0:
      let
        address = queue.popFirst()
        d1 = dist[address] + 1
        y = address div MapW
        x = address mod MapW
      for (dy, dx) in steps:
        let
          ny = y + dy
          nx = x + dx
        if ny < 0 or ny >= MapW or nx < 0 or nx >= MapW:
          continue
        let nAddress = ny * MapW + nx
        if dist[nAddress] != Unreached or nav.walls[nAddress]:
          continue
        dist[nAddress] = d1
        queue.addLast(nAddress)
    nav.fields[goal] = dist
  nav.fields[goal]

proc sign(v: int): int =
  if v > 0: 1 elif v < 0: -1 else: 0

proc stepToward(nav: var NavGrid, y, x: int, goal: (int, int)): (int, int) =
  ## Best (dy, dx) unit step from (y, x) toward goal: descend the goal's
  ## cost field, deterministic tie-break in engine step order. Greedy
  ## sign step when the current cell is unreachable from the goal.
  if abs(y - goal[0]) <= 1 and abs(x - goal[1]) <= 1:
    return (0, 0)
  let costField = nav.field(goal)
  let here =
    if y >= 0 and y < MapW and x >= 0 and x < MapW:
      costField[y * MapW + x]
    else:
      Unreached
  var
    best = (0, 0)
    bestD = Unreached
    found = false
  for (dy, dx) in steps:
    let
      ny = y + dy
      nx = x + dx
    if ny < 0 or ny >= MapW or nx < 0 or nx >= MapW:
      continue
    let d = costField[ny * MapW + nx]
    if d == Unreached:
      continue
    if not found or d < bestD:
      best = (dy, dx)
      bestD = d
      found = true
  if found and (here == Unreached or bestD < here):
    return best
  # Unreachable (or already at the local minimum): greedy fallback.
  (sign(goal[0] - y), sign(goal[1] - x))

## Per-hero state machine

type HeroMode = enum
  PushMode
  RetreatMode

type HeroState = object
  mode: HeroMode
  wpIndex: int            ## next waypoint to visit; -1 = re-anchor
  lastPos: (int, int)
  hasLastPos: bool
  triedMove: bool         ## did LAST tick want to move?
  stuckTicks: int
  detourLeft: int
  detourSide: int         ## +1 / -1, alternates

proc initHeroState(): HeroState =
  HeroState(mode: PushMode, wpIndex: -1, detourSide: 1)

proc rotate90(dy, dx, side: int): (int, int) =
  ## (dy, dx) rotated 90 degrees; side = +1 clockwise on screen.
  (side * dx, -side * dy)

type Bogatyr = object
  nav: NavGrid
  heroes: Table[int, HeroState]
  deadTowers: array[towers.len, bool]

proc updateTowerMemory(bot: var Bogatyr, s: HeroObs) =
  ## A tower whose known cell is visible in the crop without a TOWER
  ## tile is remembered dead (kill_entity zeroes the cell, moba.h:632).
  for i, tower in towers:
    if bot.deadTowers[i]:
      continue
    let
      dy = int(tower.y) - s.y
      dx = int(tower.x) - s.x
    if abs(dy) <= Vis and abs(dx) <= Vis:
      if s.tile(dy, dx) != TowerTile:
        bot.deadTowers[i] = true

proc nearestLiveEnemyTower(bot: Bogatyr, s: HeroObs): (int, int) =
  ## (tower index, chebyshev distance) of the closest live enemy tower
  ## that can actually shoot, or (-1, 0). Ancients are exempt:
  ## TOWER_DAMAGE is 0 for both (moba.h:65), diving them is free.
  result = (-1, 0)
  var bestD = high(int)
  for i, tower in towers:
    if tower.team == s.team or tower.tier == 5 or bot.deadTowers[i]:
      continue
    let d = max(abs(int(tower.y) - s.y), abs(int(tower.x) - s.x))
    if d < bestD:
      bestD = d
      result = (i, d)

proc lane(s: HeroObs): seq[(float, float)] =
  waypoints[laneForHero[s.heroType] + 3 * s.team]

proc nearestWaypoint(s: HeroObs): int =
  var bestD = Inf
  for i, (wy, wx) in s.lane():
    let d = max(abs(wy - float(s.y)), abs(wx - float(s.x)))
    if d < bestD:
      bestD = d
      result = i

proc pushGoal(s: HeroObs, state: var HeroState): (int, int) =
  if state.wpIndex < 0:
    state.wpIndex = s.nearestWaypoint()
  while state.wpIndex < s.lane().len:
    let (wy, wx) = s.lane()[state.wpIndex]
    if max(abs(wy - float(s.y)), abs(wx - float(s.x))) > WaypointReached:
      return (int(wy), int(wx))
    inc state.wpIndex
  let ancient = towers[ancientIndexByTeam[1 - s.team]]
  (int(ancient.y), int(ancient.x))

proc cropScan(s: HeroObs): (int, int, seq[(int, int)]) =
  ## (enemy hero chebyshev dist or -1, hostile creep dist or -1,
  ## friendly creep cells) from the reliable crop tiles.
  var
    heroD = -1
    creepD = -1
    friendlyCells: seq[(int, int)]
  let
    creepTile = enemyCreepTile(s.team)
    friendlyTile = friendlyCreepTile(s.team)
  for dy in -Vis .. Vis:
    let yy = s.y + dy
    if yy < 0 or yy >= MapW:
      continue
    for dx in -Vis .. Vis:
      let xx = s.x + dx
      if xx < 0 or xx >= MapW:
        continue
      let t = s.crop[(dy + Vis) * CropW + (dx + Vis)]
      if t == EmptyTile or t == WallTile:
        continue
      let d = max(abs(dy), abs(dx))
      if enemyHeroTile(s.team, t):
        if heroD < 0 or d < heroD:
          heroD = d
      elif t == creepTile:
        if creepD < 0 or d < creepD:
          creepD = d
      elif t == friendlyTile:
        friendlyCells.add((yy, xx))
  (heroD, creepD, friendlyCells)

proc skillFlags(s: HeroObs, mode: HeroMode, heroD, creepD: int):
    (int, int, int) =
  ## (use_q, use_w, use_e) per role. The engine re-checks cooldown/mana/
  ## target and fails skills harmlessly, so these are intent flags gated
  ## just enough to avoid wasting mana (moba.h:1151-1362).
  let
    enemyHero = heroD >= 0
    hostile = enemyHero or creepD >= 0
  template flag(condition: bool): int = (if condition: 1 else: 0)
  case s.heroType
  of SupportHero:  # hook / aoe heal / stun
    (flag(enemyHero and s.manaAtLeast(100)),
     flag(s.health10 <= 6 and s.manaAtLeast(100)),
     flag(enemyHero and s.manaAtLeast(75)))
  of AssassinHero:  # aoe minions / tp nuke / haste
    (flag(creepD >= 0 and s.manaAtLeast(100)),
     flag(enemyHero and s.health10 >= 5 and s.manaAtLeast(150)),
     flag(mode == RetreatMode and s.manaAtLeast(100)))
  of BurstHero:  # nuke / aoe / aoe stun
    (flag(enemyHero and s.manaAtLeast(200)),
     flag(enemyHero and s.manaAtLeast(100)),
     flag(enemyHero and s.manaAtLeast(75)))
  of TankHero:  # aoe dot / self heal / engage
    (flag(hostile and s.health10 > 5 and s.manaAtLeast(5)),
     flag(s.health10 <= 5 and s.manaAtLeast(100)),
     flag(enemyHero and s.health10 > 6 and s.manaAtLeast(50)))
  else:  # carry: retreat slow / slow nuke / aoe
    (flag(mode == RetreatMode and hostile and s.manaAtLeast(25)),
     flag(enemyHero and s.manaAtLeast(150)),
     flag(creepD >= 0 and s.manaAtLeast(100)))

proc heroAction(bot: var Bogatyr, index: int, obs: string): array[6, int] =
  let s = parseObs(obs)
  if index notin bot.heroes:
    bot.heroes[index] = initHeroState()
  bot.updateTowerMemory(s)
  var state = bot.heroes[index]

  # Respawn/teleport detection resets waypoint tracking.
  let pos = (s.y, s.x)
  if state.hasLastPos and
      max(abs(pos[0] - state.lastPos[0]),
          abs(pos[1] - state.lastPos[1])) > int(TeleportDist):
    state.wpIndex = -1
    state.stuckTicks = 0
    state.detourLeft = 0

  # Mode with hysteresis.
  if state.mode == PushMode and s.health10 <= RetreatEnterHp:
    state.mode = RetreatMode
  elif state.mode == RetreatMode and s.health10 >= RetreatExitHp:
    state.mode = PushMode
    state.wpIndex = -1  # re-anchor to the nearest waypoint

  let (heroD, creepD, friendlyCreeps) = s.cropScan()

  # Goal selection.
  var
    hold = false
    goal: (int, int)
  if state.mode == RetreatMode:
    goal = spawnByTeam[s.team]
  else:
    goal = pushGoal(s, state)
    let (towerIndex, towerDist) = bot.nearestLiveEnemyTower(s)
    if towerIndex >= 0 and towerDist <= SiegeStandoff:
      let
        ty = int(towers[towerIndex].y)
        tx = int(towers[towerIndex].x)
      var engaged = false
      for (cy, cx) in friendlyCreeps:
        if max(abs(cy - ty), abs(cx - tx)) <= CreepEngagedDist:
          engaged = true
          break
      if engaged:
        goal = (ty, tx)             # push onto the tower
      elif towerDist <= TowerVision:
        goal = spawnByTeam[s.team]  # inside range, no wave: get out
      else:
        hold = true                 # at standoff: wait for creeps

  # Steering.
  var (dy, dx) = if hold: (0, 0) else: bot.nav.stepToward(s.y, s.x, goal)

  # Stuck detection -> deterministic 90-degree detour. A tick only
  # counts as stuck if the PREVIOUS tick actually tried to move and the
  # position stayed put; coming out of an intentional hold must not
  # count as a phantom stuck tick.
  if state.triedMove and state.hasLastPos and state.lastPos == pos and
      (dy != 0 or dx != 0):
    inc state.stuckTicks
  else:
    state.stuckTicks = 0
  if state.detourLeft > 0:
    dec state.detourLeft
    (dy, dx) = rotate90(dy, dx, state.detourSide)
  elif state.stuckTicks >= StuckTickLimit:
    state.detourLeft = DetourTickCount
    state.detourSide = -state.detourSide
    state.stuckTicks = 0
    (dy, dx) = rotate90(dy, dx, state.detourSide)
  state.triedMove = dy != 0 or dx != 0
  state.lastPos = pos
  state.hasLastPos = true
  bot.heroes[index] = state

  # Target filter: everything while hostile creeps are around (lane
  # XP), heroes+towers otherwise (focus towers, don't aggro camps).
  let targetFilter = if creepD >= 0: 0 else: 2
  let (useQ, useW, useE) = s.skillFlags(state.mode, heroD, creepD)
  [3 + 3 * dy, 3 + 3 * dx, targetFilter, useQ, useW, useE]

proc draftPicks(message: JsonNode): JsonNode =
  ## lane-brawler's draft: derived from the OBSERVED base stats, so it
  ## adapts if upstream's role table ever changes (derk_player.py).
  let hero = message{"hero"}
  var
    health = 0.0
    hpGain = 0.0
  if hero != nil:
    health = hero{"base_health"}.getFloat(0.0)
    hpGain = hero{"hp_gain_per_level"}.getFloat(0.0)
  %*{
    "arm": if health >= 500: "arm_cleaver" else: "arm_needler",
    "tail": if hpGain >= 100: "tail_plate" else: "tail_rotor",
    "misc": if health < 500: "misc_regen" else: "misc_focus",
    "note": "brawl build"}

when defined(bogatyrTest):
  # Differential-test hook: read base64 obs rows on stdin, print the
  # action row for each (tools/, never compiled into the shipped image).
  import std/strutils

  proc testMain*() =
    var bot = Bogatyr(nav: initNavGrid(), heroes: initTable[int, HeroState]())
    var line: string
    while stdin.readLine(line):
      if line.len == 0:
        continue
      if line == "RESET":
        bot = Bogatyr(nav: initNavGrid(),
                      heroes: initTable[int, HeroState]())
        continue
      let action = bot.heroAction(0, decode(line))
      var parts: seq[string]
      for value in action:
        parts.add($value)
      echo parts.join(" ")

proc main() =
  let client = newCoworldClient("bogatyr")
  var bot = Bogatyr(nav: initNavGrid(), heroes: initTable[int, HeroState]())
  client.run proc(message: JsonNode) =
    if message{"done"}.getBool(false):
      echo "bogatyr: done, result ", message{"result"}
      quit(0)
    let phase = message{"phase"}.getStr()
    if phase == "draft":
      client.send(%*{"phase": "draft", "picks": [draftPicks(message)]})
      echo "bogatyr: drafted"
      return
    if phase != "" or message{"tick"} == nil:
      return  # draft_result and unknown phases need no reply
    let tick = message{"tick"}.getInt()
    var actions = newJArray()
    for i, row in message{"obs"}.getElems():
      var rowActions = newJArray()
      for value in bot.heroAction(i, decode(row.getStr())):
        rowActions.add(%value)
      actions.add(rowActions)
    client.send(%*{"tick": tick, "actions": actions})

when defined(bogatyrTest):
  testMain()
else:
  main()
