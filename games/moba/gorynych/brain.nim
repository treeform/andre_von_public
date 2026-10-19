## Zmey Gorynych brain — ancient snipe.
##
## Sim facts this rests on (vendor/upstream/moba.h, coworld 0.1.3):
## - Towers scan a chebyshev-5 square around their integer cell every
##   3 ticks and shoot the nearest scanned creep/hero by L1 for 110-175
##   every 5 ticks (step_towers / attack). Ancients have TOWER_DAMAGE 0.
## - A hero scans its own chebyshev-5 square and auto-attacks the
##   nearest scanned entity; attack() only requires L1 <= 12.
## - Hence every cell at chebyshev 5 from an ancient on the side away
##   from its two tier-4 guards is outside every tower square yet in
##   attack range of the ancient: a hero standing there hits the
##   ancient and nothing can shoot it back. Killing the ancient ends
##   the episode (c_step), no tower needs to fall first.
## - Heroes regenerate 2 health and 2 mana per tick.
##
## Strategy: every hero walks a penalised-Dijkstra route from wherever
## it is to its own blind snipe cell (routes brush at most 2-3 tower
## covered cells), then holds there with the heroes+towers target
## filter so basic attacks and nukes land on the ancient. Deterministic:
## a pure function of (obs bytes, per-hero state). No RNG, no clocks.

import
  std/[base64, deques, heapqueue, sets, tables]

## Wire constants

const
  observationSize* = 510
  cropTiles = 121          ## reliable prefix of the 484-byte crop region
  cropWidth = 11
  visionRange = 5          ## sim/shim_common.h:17
  selfOffset = 484         ## 11*11*4
  mapWidth = 128

## Tile ids (moba.h:28-43)

const
  emptyTile = 0
  wallTile = 1
  towerTile = 2
  radiantCreepTile = 3
  direCreepTile = 4
  neutralTile = 5

## Hero roles and static tables (init_moba, moba.h:1661-1744)

const
  supportHero = 0
  assassinHero = 1
  burstHero = 2
  tankHero = 3
  carryHero = 4
  manaTable = [(250, 50), (300, 65), (300, 90), (200, 50), (250, 50)]
  spawns = [(113, 12), (15, 116)]  ## team -> fountain (y, x), moba.h:1636
  towerVision = 5                  ## moba.h:45
  attackReach = 12.0               ## attack(), L1 on float positions

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

## Lane polylines (WAYPOINTS, moba.h:71-72), used only to keep routes
## out of creep vision (CREEP_VISION 7) where the map allows.
const waypoints: array[6, seq[(float, float)]] = [
  @[(96.262, 14.046), (93.615, 14.292), (58.231, 16.077),
    (43.4, 16.015), (32.108, 17.585), (24.938, 19.123),
    (22.969, 20.446), (21.062, 25.308), (20.2, 30.477),
    (19.4, 35.892), (18.477, 43.523), (18.046, 50.723),
    (20.508, 94.662), (27.677, 105.946)],
  @[(99.523, 26.477), (98.662, 27.646), (86.046, 41.123),
    (71.338, 57.492), (66.969, 62.231), (64.077, 66.354),
    (60.2, 72.015), (51.892, 84.877), (34.662, 99.4),
    (28.169, 105.946)],
  @[(112.015, 36.938), (112.015, 32.508), (116.2, 68.692),
    (113.738, 80.754), (113.554, 90.538), (113.215, 95.985),
    (111.492, 100.938), (109.062, 108.077), (107.185, 111.369),
    (101.738, 114.662), (90.538, 111.769), (39.4, 113.738),
    (28.169, 106.438)],
  @[(20.446, 89.369), (20.631, 94.662), (18.785, 50.6),
    (22.292, 24.508), (22.815, 18.815), (27.523, 17.031),
    (35.031, 15.954), (93.615, 14.415), (103.646, 21.992)],
  @[(37.431, 96.508), (34.538, 99.277), (51.708, 84.385),
    (59.831, 71.646), (63.831, 66.108), (66.723, 61.985),
    (70.846, 57.246), (98.538, 27.523), (103.646, 22.485)],
  @[(36.938, 113.246), (39.4, 113.615), (62.292, 114.6),
    (83.646, 114.6), (90.662, 109.8), (94.877, 112.015),
    (104.262, 112.292), (109.308, 107.831), (112.231, 105.862),
    (114.446, 72.969), (111.892, 32.508), (104.138, 22.485)],
]

## Neutral camp centres (NEUTRAL_CAMP_X/Y, moba.h:63-64); neutrals
## respawn within +-3 of these and aggro at NEUTRAL_VISION 3.
const
  neutralCampY = [71.99, 108.15, 102.17, 102.78, 40.75, 39.92, 39.97,
                  70.78, 69.18, 59.52, 99.95, 93.98, 49.86, 31.35, 61.06,
                  69.92, 83.83, 33.98]
  neutralCampX = [44.75, 74.42, 101.68, 89.92, 73.95, 64.38, 31.66,
                  95.68, 81.11, 34.99, 50.78, 63.65, 59.49, 44.69, 98.67,
                  28.64, 64.88, 51.46]

## Engine step directions in engine order (ATN_MAP, moba.h:58-61):
## S, N, E, W, SW, NW, NE, SE as (dy, dx).
const steps = [(1, 0), (-1, 0), (0, 1), (0, -1),
               (1, -1), (-1, -1), (-1, 1), (1, 1)]

## Tuning knobs

const
  towerPenalty = 60            ## per step onto a tower-covered cell
  campPenalty = 8              ## per step within chebyshev 6 of a camp
  lanePenalty = 2              ## per step within creep vision of a lane
  campAvoid = 6
  laneAvoid = 7.0
  teleportDistance = 4         ## position jump > this = respawn
  stuckTickLimit = 4           ## unmoved ticks before detouring
  detourTickCount = 5          ## how long one detour burst lasts
  hasteFarSteps = 30           ## assassin E while this far from goal
  healAllyHealth = 6           ## support W when an ally is at/below
  tankHealHealth = 5
  crossingHealth = 8           ## health tenths required to enter a square
  spawnPenalty = 30            ## per step near an enemy creep spawn
  spawnAvoid = 8               ## chebyshev; CREEP_VISION is 7
  snipeSpawnClearance = 9      ## snipe cells this far from creep spawns
  creepWaveTicks = 150         ## step_creeps wave cadence
  waveClearStart = 30          ## wave phase window to enter a spawn zone
  waveClearEnd = 120

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

## Geometry helpers

proc chebyshev(y1, x1, y2, x2: int): int =
  max(abs(y1 - y2), abs(x1 - x2))

proc l1(y1, x1, y2, x2: int): int =
  abs(y1 - y2) + abs(x1 - x2)

proc towerCell(index: int): (int, int) =
  (int(towers[index].y), int(towers[index].x))

proc shoots(index: int): bool =
  towers[index].tier != 5

proc coveredByEnemyTower*(y, x, team: int): bool =
  ## Inside the scan square of any shooting enemy tower (all assumed
  ## live: conservative routing).
  for i, t in towers:
    if t.team == team or not shoots(i):
      continue
    let (ty, tx) = towerCell(i)
    if chebyshev(y, x, ty, tx) <= towerVision:
      return true
  false

proc nearCamp(y, x: int): bool =
  for i in 0 ..< neutralCampY.len:
    if chebyshev(y, x, int(neutralCampY[i]), int(neutralCampX[i])) <= campAvoid:
      return true
  false

proc nearEnemyCreepSpawn(y, x, team: int): bool =
  ## Enemy waves spawn at their lanes' first waypoint (+-3) and head
  ## for the second; both scan chebyshev 7 for us.
  for lane in 3 * (1 - team) .. 3 * (1 - team) + 2:
    for i in 0 .. 1:
      let (wy, wx) = waypoints[lane][i]
      if chebyshev(y, x, int(wy), int(wx)) <= spawnAvoid:
        return true
  false

proc spawnClearance(y, x, team: int): int =
  ## Chebyshev distance to the nearest enemy creep spawn waypoint.
  result = high(int)
  for lane in 3 * (1 - team) .. 3 * (1 - team) + 2:
    for i in 0 .. 1:
      let (wy, wx) = waypoints[lane][i]
      result = min(result, chebyshev(y, x, int(wy), int(wx)))

proc nearLane(y, x: int): bool =
  for lane in 0 .. 5:
    for (wy, wx) in waypoints[lane]:
      if abs(wy - float(y)) + abs(wx - float(x)) <= laneAvoid:
        return true
  false

## Perception

type HeroView* = object
  ## Decoded 510-byte observation: the reliable fields only. Self bytes
  ## are obs[484..509] (moba.h:480-503).
  x*, y*: int
  level*: int
  health10*: int         ## health * 10 / max, 0..10
  mana10*: int           ## mana * 10 / max, 0..10
  team*: int             ## 0 radiant, 1 dire
  heroType*: int         ## 0..4 support/assassin/burst/tank/carry
  valid*: bool
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

proc parseView*(observation: string): HeroView =
  ## Decode one 510-byte observation. Robust to garbage: hero_type falls
  ## back to 0 when the one-hot region is empty, team is clamped to 0/1.
  if observation.len != observationSize:
    return HeroView(valid: false)
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
    heroType: heroType, valid: true)
  for i in 0 ..< cropTiles:
    result.crop[i] = observation[i].uint8

proc isEnemyHeroTile(team, tileId: int): bool =
  if team == 0: tileId in 11 .. 15 else: tileId in 6 .. 10

proc enemyCreepTile(team: int): int =
  if team == 0: direCreepTile else: radiantCreepTile

type Threats = object
  heroDistance: int      ## chebyshev to nearest enemy hero, or -1
  creepDistance: int     ## chebyshev to nearest hostile creep, or -1
  neutralDistance: int   ## chebyshev to nearest neutral, or -1

proc scanThreats(view: HeroView): Threats =
  result = Threats(heroDistance: -1, creepDistance: -1, neutralDistance: -1)
  let hostileCreep = enemyCreepTile(view.team)
  for dy in -visionRange .. visionRange:
    for dx in -visionRange .. visionRange:
      let t = view.tile(dy, dx)
      if t == emptyTile or t == wallTile or t == towerTile:
        continue
      let d = max(abs(dy), abs(dx))
      if isEnemyHeroTile(view.team, t):
        if result.heroDistance < 0 or d < result.heroDistance:
          result.heroDistance = d
      elif t == hostileCreep:
        if result.creepDistance < 0 or d < result.creepDistance:
          result.creepDistance = d
      elif t == neutralTile:
        if result.neutralDistance < 0 or d < result.neutralDistance:
          result.neutralDistance = d

## Navigation: penalised Dijkstra fields over the static map

const unreached = high(int32)

type Node = object
  cost: int32
  cell: int32

proc `<`(a, b: Node): bool = a.cost < b.cost

type NavGrid = object
  walls: seq[bool]
  fields: Table[(int, int, int), seq[int32]]   ## (team, gy, gx)

proc initNavGrid(): NavGrid =
  result.walls = decodeWalls()
  for t in towers:
    result.walls[int(t.y) * mapWidth + int(t.x)] = true
  result.fields = initTable[(int, int, int), seq[int32]]()

proc canStep(nav: NavGrid, y, x, dy, dx: int): bool =
  ## The sim normalises a diagonal velocity to 0.707 per axis and
  ## truncates the float position, so a diagonal step from an aligned
  ## cell first lands in the orthogonal neighbour on the negative axis;
  ## if either orthogonal neighbour is a wall the move fails forever.
  ## Never plan a diagonal past a wall corner.
  let ny = y + dy
  let nx = x + dx
  if ny < 0 or ny >= mapWidth or nx < 0 or nx >= mapWidth:
    return false
  if nav.walls[ny * mapWidth + nx]:
    return false
  if dy != 0 and dx != 0:
    if nav.walls[ny * mapWidth + x] or nav.walls[y * mapWidth + nx]:
      return false
  true

proc stepCost(nav: NavGrid, team, y, x: int): int32 =
  result = 1
  if coveredByEnemyTower(y, x, team): result += towerPenalty
  if nearCamp(y, x): result += campPenalty
  if nearLane(y, x): result += lanePenalty
  if nearEnemyCreepSpawn(y, x, team): result += spawnPenalty

proc costField(nav: var NavGrid, team: int, goal: (int, int)): lent seq[int32] =
  ## Dijkstra distances from goal over the penalised grid; cached.
  let key = (team, goal[0], goal[1])
  if key notin nav.fields:
    var distance = newSeq[int32](mapWidth * mapWidth)
    for i in 0 ..< distance.len:
      distance[i] = unreached
    let g = goal[0] * mapWidth + goal[1]
    distance[g] = 0
    var heap = initHeapQueue[Node]()
    heap.push(Node(cost: 0, cell: int32(g)))
    while heap.len > 0:
      let top = heap.pop()
      if top.cost > distance[top.cell]:
        continue
      let y = int(top.cell) div mapWidth
      let x = int(top.cell) mod mapWidth
      for (dy, dx) in steps:
        if not nav.canStep(y, x, dy, dx):
          continue
        let ny = y + dy
        let nx = x + dx
        let n = ny * mapWidth + nx
        let c = top.cost + nav.stepCost(team, ny, nx)
        if c < distance[n]:
          distance[n] = c
          heap.push(Node(cost: c, cell: int32(n)))
    nav.fields[key] = distance
  nav.fields[key]

proc sign(v: int): int =
  if v > 0: 1 elif v < 0: -1 else: 0

proc stepToward(nav: var NavGrid, team, y, x: int, goal: (int, int)): (int, int) =
  ## Best (dy, dx) unit step from (y, x) toward goal, descending the
  ## penalised field; deterministic tie-break in steps order.
  if (y, x) == goal:
    return (0, 0)
  let field = nav.costField(team, goal)
  let here =
    if y >= 0 and y < mapWidth and x >= 0 and x < mapWidth:
      field[y * mapWidth + x]
    else:
      unreached
  var best = (0, 0)
  var bestCost = unreached
  var found = false
  for (dy, dx) in steps:
    if not nav.canStep(y, x, dy, dx):
      continue
    let ny = y + dy
    let nx = x + dx
    let d = field[ny * mapWidth + nx]
    if d == unreached:
      continue
    if not found or d < bestCost:
      best = (dy, dx)
      bestCost = d
      found = true
  if found and (here == unreached or bestCost < here):
    return best
  (sign(goal[0] - y), sign(goal[1] - x))

## Snipe cells: blind to every shooting enemy tower, in the hero's own
## scan square of the enemy ancient and inside attack() reach.

proc snipeCells(nav: var NavGrid, team: int): seq[(int, int)] =
  ## Blind cells ordered by penalised walking cost from the fountain.
  let ancient = towers[ancientIndex[1 - team]]
  let (ay, ax) = (int(ancient.y), int(ancient.x))
  var candidates: seq[(int32, (int, int))]
  let field = nav.costField(team, spawns[team])
  for y in ay - visionRange .. ay + visionRange:
    for x in ax - visionRange .. ax + visionRange:
      if y < 0 or x < 0 or y >= mapWidth or x >= mapWidth:
        continue
      if nav.walls[y * mapWidth + x] or coveredByEnemyTower(y, x, team):
        continue
      if abs(float(y) - ancient.y) + abs(float(x) - ancient.x) > attackReach - 0.5:
        continue
      var c = field[y * mapWidth + x]
      if c == unreached:
        continue
      # creep waves would otherwise chew on the snipers every 150 ticks
      if spawnClearance(y, x, team) < snipeSpawnClearance:
        c += 10_000
      # enemy heroes respawn within +-7 of their fountain at full health
      # and auto-attack whatever is nearest; keep the nest out of that
      # zone and preferably out of a respawner's scan square
      let (fy, fx) = spawns[1 - team]
      let fountain = chebyshev(y, x, fy, fx)
      if fountain <= 7:
        c += 5_000
      elif fountain <= 9:
        c += 2_000
      elif fountain <= 11:
        c += 800
      elif fountain <= 12:
        c += 300
      candidates.add((c, (y, x)))
  proc order(cs: var seq[(int32, (int, int))]) =
    for i in 1 ..< cs.len:
      var j = i
      while j > 0 and cs[j][0] < cs[j - 1][0]:
        swap(cs[j], cs[j - 1])
        dec j
  order(candidates)
  if candidates.len > 1:
    # keep the team together: cells far from the best cell rank lower
    let (ay0, ax0) = candidates[0][1]
    for i in 1 ..< candidates.len:
      if chebyshev(candidates[i][1][0], candidates[i][1][1], ay0, ax0) > 2:
        candidates[i][0] += 1_000
    order(candidates)
  for (_, cell) in candidates:
    result.add cell

## Per-hero state

type HeroState = ref object
  hasLastPos: bool
  lastPos: (int, int)
  triedMove: bool
  stuckTicks: int
  detourLeft: int
  detourSide: int

proc newHeroState(): HeroState =
  HeroState(detourSide: 1)

proc rotate90(dy, dx, side: int): (int, int) =
  (side * dx, -side * dy)

## The brain

type Brain* = ref object
  nav: NavGrid
  heroes: Table[int, HeroState]
  goals: Table[(int, int), (int, int)]   ## (team, heroType) -> cell
  cellsByTeam: Table[int, seq[(int, int)]]
  deadTowers: HashSet[int]
  ticks*: int

proc newBrain*(): Brain =
  Brain(nav: initNavGrid(),
        heroes: initTable[int, HeroState](),
        goals: initTable[(int, int), (int, int)](),
        cellsByTeam: initTable[int, seq[(int, int)]](),
        deadTowers: initHashSet[int]())

proc goalFor(brain: Brain, team, heroType: int): (int, int) =
  let key = (team, heroType)
  if key notin brain.goals:
    if team notin brain.cellsByTeam:
      brain.cellsByTeam[team] = brain.nav.snipeCells(team)
    let cells = brain.cellsByTeam[team]
    doAssert cells.len >= 5, "fewer than five blind snipe cells"
    # spread roles over the five cheapest cells; tank takes the
    # nearest (it is first to arrive and hardest to kill)
    const order = [tankHero, supportHero, burstHero, carryHero, assassinHero]
    for i, role in order:
      brain.goals[(team, role)] = cells[i]
  brain.goals[key]

proc updateTowerMemory(brain: Brain, view: HeroView) =
  for index, t in towers:
    if index in brain.deadTowers:
      continue
    let dy = int(t.y) - view.y
    let dx = int(t.x) - view.x
    if abs(dy) <= visionRange and abs(dx) <= visionRange:
      if view.tile(dy, dx) != towerTile:
        brain.deadTowers.incl(index)

proc skillFlags(view: HeroView, threats: Threats, atGoal: bool,
                allyLowNearby: bool, farFromGoal: bool): (int, int, int) =
  ## (use_q, use_w, use_e). Never fire a skill that moves us or the
  ## target: support Q hook (pulls the ancient), assassin W (teleports
  ## next to the ancient, into tier-4 range), tank E (same), carry Q
  ## (pushes the target away).
  template flag(condition: bool): int = (if condition: 1 else: 0)
  let enemyHero = threats.heroDistance >= 0
  let adjacentHostile =
    (threats.heroDistance >= 0 and threats.heroDistance <= 2) or
    (threats.creepDistance >= 0 and threats.creepDistance <= 2)
  case view.heroType
  of supportHero:      # hook / aoe heal / stun
    (0,
     flag(allyLowNearby and view.manaAtLeast(100)),
     flag((atGoal or enemyHero) and view.manaAtLeast(175)))
  of assassinHero:     # aoe minions / tp nuke / haste
    (flag(threats.creepDistance >= 0 and threats.creepDistance <= 3 and
          view.manaAtLeast(100)),
     0,
     flag(farFromGoal and not atGoal and view.manaAtLeast(100)))
  of burstHero:        # nuke / aoe / aoe stun
    (flag((atGoal or enemyHero) and view.manaAtLeast(200)),
     flag(adjacentHostile and view.manaAtLeast(100)),
     flag(threats.heroDistance >= 0 and threats.heroDistance <= 2 and
          view.manaAtLeast(75)))
  of tankHero:         # aoe dot / self heal / engage
    (flag(adjacentHostile and view.mana10 >= 1),
     flag(view.health10 <= tankHealHealth and view.manaAtLeast(100)),
     0)
  else:                # carry: retreat slow / slow nuke / aoe
    (0,
     flag((atGoal or enemyHero) and view.manaAtLeast(150)),
     flag(adjacentHostile and view.manaAtLeast(100)))

proc heroAction(brain: Brain, tick, index: int, view: HeroView,
                allyLowNearby, teammateCrossing: bool): array[6, int] =
  if index notin brain.heroes:
    brain.heroes[index] = newHeroState()
  let state = brain.heroes[index]
  brain.updateTowerMemory(view)

  let position = (view.y, view.x)
  if state.hasLastPos and
      chebyshev(position[0], position[1], state.lastPos[0], state.lastPos[1]) >
      teleportDistance:
    state.stuckTicks = 0
    state.detourLeft = 0

  let goal = brain.goalFor(view.team, view.heroType)
  let atGoal = position == goal
  let threats = scanThreats(view)
  let remaining = brain.nav.costField(view.team, goal)[view.y * mapWidth + view.x]
  let farFromGoal = remaining == unreached or int(remaining) > hasteFarSteps

  var (dy, dx) = if atGoal: (0, 0)
                 else: brain.nav.stepToward(view.team, view.y, view.x, goal)

  # stuck detection -> deterministic 90-degree detour (blocked cells:
  # creeps, heroes, a teammate queueing on the same route)
  if state.triedMove and state.hasLastPos and state.lastPos == position and
      (dy != 0 or dx != 0):
    inc state.stuckTicks
  else:
    state.stuckTicks = 0
  let insideNow = coveredByEnemyTower(view.y, view.x, view.team)
  if insideNow:
    # blocked inside a tower square: step to the cheapest uncovered
    # neighbour (out of the square) rather than spinning under fire
    if state.stuckTicks >= 2:
      let field = brain.nav.costField(view.team, goal)
      var best = (0, 0)
      var bestCost = unreached
      for (sy, sx) in steps:
        if not brain.nav.canStep(view.y, view.x, sy, sx):
          continue
        let ny = view.y + sy
        let nx = view.x + sx
        if coveredByEnemyTower(ny, nx, view.team):
          continue
        let c = field[ny * mapWidth + nx]
        if c < bestCost:
          bestCost = c
          best = (sy, sx)
      (dy, dx) = best
      state.stuckTicks = 0
    state.detourLeft = 0
  elif state.detourLeft > 0:
    dec state.detourLeft
    (dy, dx) = rotate90(dy, dx, state.detourSide)
  elif state.stuckTicks >= stuckTickLimit:
    state.detourLeft = detourTickCount
    state.detourSide = -state.detourSide
    state.stuckTicks = 0
    (dy, dx) = rotate90(dy, dx, state.detourSide)
  # never improvise into a tower square or a wall; enter a square only
  # single file (one teammate inside at a time: the tower fires once per
  # 5 ticks at its nearest target) and only at near-full health; enter
  # an enemy creep spawn zone only while the current wave has walked off
  if dy != 0 or dx != 0:
    let ny = view.y + dy
    let nx = view.x + dx
    let enteringSquare = coveredByEnemyTower(ny, nx, view.team) and not insideNow
    let enteringSpawn = nearEnemyCreepSpawn(ny, nx, view.team) and
      not nearEnemyCreepSpawn(view.y, view.x, view.team)
    let wavePhase = tick mod creepWaveTicks
    let waveClear = wavePhase >= waveClearStart and wavePhase <= waveClearEnd
    if not brain.nav.canStep(view.y, view.x, dy, dx) or
        (enteringSquare and (state.detourLeft > 0 or teammateCrossing or
                             view.health10 < crossingHealth)) or
        (enteringSpawn and not waveClear):
      dy = 0
      dx = 0
      state.stuckTicks = 0

  state.triedMove = dy != 0 or dx != 0
  state.lastPos = position
  state.hasLastPos = true

  # target filter: heroes+towers so the ancient (or a nearer enemy
  # hero) is the auto-attack target; everything only when a hostile
  # creep is close enough to be worth the swing, never near a camp
  var targetFilter = 2
  if threats.creepDistance >= 0 and threats.creepDistance <= 2 and
      (threats.neutralDistance < 0 or threats.neutralDistance > 2):
    targetFilter = 0
  let (useQ, useW, useE) = skillFlags(view, threats, atGoal,
                                      allyLowNearby, farFromGoal)
  [3 + 3 * dy, 3 + 3 * dx, targetFilter, useQ, useW, useE]

proc act*(brain: Brain, tick: int, observations: seq[string]): seq[array[6, int]] =
  ## One action row per observation row (1 or 5 heroes per seat). tick
  ## is the server tick (creep waves spawn when it is a multiple of 150).
  inc brain.ticks
  var views = newSeq[HeroView](observations.len)
  for i, row in observations:
    views[i] = parseView(row)
  result = newSeq[array[6, int]](observations.len)
  for i, view in views:
    if not view.valid:
      result[i] = [3, 3, 0, 0, 0, 0]
      continue
    var allyLow = view.health10 <= healAllyHealth
    for other in views:
      if other.valid and other.team == view.team and
          chebyshev(view.y, view.x, other.y, other.x) <= visionRange and
          other.health10 <= healAllyHealth:
        allyLow = true
    var crossing = false
    for j, other in views:
      if j != i and other.valid and other.team == view.team and
          coveredByEnemyTower(other.y, other.x, other.team):
        crossing = true
    result[i] = brain.heroAction(tick, i, view, allyLow, crossing)

proc explain*(brain: Brain, tick, index: int, view: HeroView): string =
  ## Read-only decision trace for one hero (research tooling).
  if index notin brain.heroes:
    return "no state"
  let state = brain.heroes[index]
  let goal = brain.goalFor(view.team, view.heroType)
  let field = brain.nav.costField(view.team, goal)
  let here = field[view.y * mapWidth + view.x]
  let (dy, dx) = brain.nav.stepToward(view.team, view.y, view.x, goal)
  let ny = view.y + dy
  let nx = view.x + dx
  var next = "next=(" & $ny & "," & $nx & ")"
  if ny >= 0 and nx >= 0 and ny < mapWidth and nx < mapWidth:
    next.add " wall=" & $brain.nav.walls[ny * mapWidth + nx]
    next.add " cost=" & $field[ny * mapWidth + nx]
    next.add " covered=" & $coveredByEnemyTower(ny, nx, view.team)
    next.add " spawnZone=" & $nearEnemyCreepSpawn(ny, nx, view.team)
    next.add " tile=" & $view.tile(dy, dx)
  result = "goal=" & $goal & " here=(" & $view.y & "," & $view.x & ") cost=" &
    $here & " step=(" & $dy & "," & $dx & ") " & next &
    " insideSquare=" & $coveredByEnemyTower(view.y, view.x, view.team) &
    " inSpawnZone=" & $nearEnemyCreepSpawn(view.y, view.x, view.team) &
    " wavePhase=" & $(tick mod creepWaveTicks) &
    " stuck=" & $state.stuckTicks & " detour=" & $state.detourLeft &
    " triedMove=" & $state.triedMove & " hp=" & $view.health10

proc routeCost*(brain: Brain, team: int, goal, cell: (int, int)): int =
  ## Penalised walking cost from cell to goal (research tooling).
  let c = brain.nav.costField(team, goal)[cell[0] * mapWidth + cell[1]]
  if c == unreached: -1 else: int(c)

proc nestCells*(brain: Brain, team: int): seq[(int, int)] =
  ## Ranked snipe cells (research tooling).
  brain.nav.snipeCells(team)

proc nextStep*(brain: Brain, team, y, x: int, goal: (int, int)): (int, int) =
  ## Planned unit step (research tooling).
  brain.nav.stepToward(team, y, x, goal)
