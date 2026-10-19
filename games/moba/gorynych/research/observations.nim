## Reliable 510-byte observation fields and static map tables (moba.h).
## Positions here are unsigned-char casts of float x/y, matching what
## policies see. Exact floats are proven only by a matching end-state.

const
  ObservationSize* = 510
  CropTiles* = 121
  CropWidth* = 11
  VisionRange* = 5
  SelfOffset* = 484
  MapWidth* = 128
  TowerCount* = 24
  TowerVision* = 5
  EmptyTile* = 0
  WallTile* = 1
  TowerTile* = 2
  RadiantCreepTile* = 3
  DireCreepTile* = 4
  AssignedLanes* = [2, 1, 1, 0, 2]
  LaneNames* = ["top", "mid", "bot"]
  RegionNames* = ["top", "mid", "bot", "fountain", "jungle"]
  RoleNames* = ["support", "assassin", "burst", "tank", "carry"]
  StatNames* = [
    "level", "kills", "deaths", "towers_killed", "creeps_killed",
    "neutrals_killed", "xp", "damage_dealt", "damage_received",
    "healing_dealt", "healing_received"
  ]
  Spawns* = [(113, 12), (15, 116)]
  AssassinECooldown* = 100
  FountainRadius* = 8
  LaneRadius* = 16
  TeleportJump* = 4

type
  TowerSite* = object
    y*: float
    x*: float
    team*: int
    tier*: int
    damage*: float
  HeroView* = object
    x*: int
    y*: int
    level*: int
    health10*: int
    mana10*: int
    moveModifier*: int
    eTimer*: int
    qTimer*: int
    wTimer*: int
    team*: int
    heroType*: int
    deathFlag*: int
    towerFlag*: int
    crop*: array[CropTiles, uint8]
  Region* = enum
    TopRegion, MidRegion, BotRegion, FountainRegion, JungleRegion

const
  Towers*: array[TowerCount, TowerSite] = [
    TowerSite(y: 112.01538461538462, x: 34.6, team: 0, tier: 3, damage: 175.0),
    TowerSite(y: 96.87692307692308, x: 29.307692307692307, team: 0, tier: 3, damage: 175.0),
    TowerSite(y: 91.21538461538461, x: 14.292307692307695, team: 0, tier: 3, damage: 175.0),
    TowerSite(y: 113.61538461538461, x: 64.2, team: 0, tier: 2, damage: 175.0),
    TowerSite(y: 112.13846153846154, x: 102.87692307692308, team: 0, tier: 1, damage: 110.0),
    TowerSite(y: 85.43076923076923, x: 38.29230769230769, team: 0, tier: 2, damage: 175.0),
    TowerSite(y: 71.70769230769231, x: 17.615384615384613, team: 0, tier: 2, damage: 175.0),
    TowerSite(y: 51.03076923076923, x: 16.876923076923077, team: 0, tier: 1, damage: 110.0),
    TowerSite(y: 102.41538461538462, x: 21.06153846153846, team: 0, tier: 4, damage: 175.0),
    TowerSite(y: 28.261538461538464, x: 103.03076923076924, team: 1, tier: 4, damage: 175.0),
    TowerSite(y: 18.723076923076924, x: 65.0, team: 1, tier: 2, damage: 175.0),
    TowerSite(y: 18.723076923076924, x: 29.06153846153846, team: 1, tier: 1, damage: 110.0),
    TowerSite(y: 48.753846153846155, x: 84.2, team: 1, tier: 2, damage: 175.0),
    TowerSite(y: 59.98461538461538, x: 69.03076923076924, team: 1, tier: 1, damage: 110.0),
    TowerSite(y: 62.04615384615384, x: 112.75384615384615, team: 1, tier: 2, damage: 175.0),
    TowerSite(y: 41.676923076923075, x: 113.73846153846154, team: 1, tier: 3, damage: 175.0),
    TowerSite(y: 20.56923076923077, x: 92.32307692307693, team: 1, tier: 3, damage: 175.0),
    TowerSite(y: 36.08461538461539, x: 97.86153846153846, team: 1, tier: 3, damage: 175.0),
    TowerSite(y: 30.907692307692308, x: 105.61538461538461, team: 1, tier: 4, damage: 175.0),
    TowerSite(y: 104.93846153846154, x: 23.52307692307692, team: 0, tier: 4, damage: 175.0),
    TowerSite(y: 75.83076923076923, x: 53.12307692307692, team: 0, tier: 1, damage: 110.0),
    TowerSite(y: 78.3, x: 113.22307692307692, team: 1, tier: 1, damage: 110.0),
    TowerSite(y: 26.53846153846154, x: 107.52307692307693, team: 1, tier: 5, damage: 0.0),
    TowerSite(y: 106.16923076923078, x: 19.46153846153846, team: 0, tier: 5, damage: 0.0)
  ]
  Waypoints*: array[6, seq[(float, float)]] = [
    @[  # radiant top
      (96.262, 14.046), (93.615, 14.292), (58.231, 16.077),
      (43.4, 16.015), (32.108, 17.585), (24.938, 19.123),
      (22.969, 20.446), (21.062, 25.308), (20.2, 30.477),
      (19.4, 35.892), (18.477, 43.523), (18.046, 50.723),
      (20.508, 94.662), (27.677, 105.946)],
    @[  # radiant mid
      (99.523, 26.477), (98.662, 27.646), (86.046, 41.123),
      (71.338, 57.492), (66.969, 62.231), (64.077, 66.354),
      (60.2, 72.015), (51.892, 84.877), (34.662, 99.4),
      (28.169, 105.946)],
    @[  # radiant bot
      (112.015, 36.938), (112.015, 32.508), (116.2, 68.692),
      (113.738, 80.754), (113.554, 90.538), (113.215, 95.985),
      (111.492, 100.938), (109.062, 108.077), (107.185, 111.369),
      (101.738, 114.662), (90.538, 111.769), (39.4, 113.738),
      (28.169, 106.438)],
    @[  # dire top
      (20.446, 89.369), (20.631, 94.662), (18.785, 50.6),
      (22.292, 24.508), (22.815, 18.815), (27.523, 17.031),
      (35.031, 15.954), (93.615, 14.415), (103.646, 21.992)],
    @[  # dire mid
      (37.431, 96.508), (34.538, 99.277), (51.708, 84.385),
      (59.831, 71.646), (63.831, 66.108), (66.723, 61.985),
      (70.846, 57.246), (98.538, 27.523), (103.646, 22.485)],
    @[  # dire bot
      (36.938, 113.246), (39.4, 113.615), (62.292, 114.6),
      (83.646, 114.6), (90.662, 109.8), (94.877, 112.015),
      (104.262, 112.292), (109.308, 107.831), (112.231, 105.862),
      (114.446, 72.969), (111.892, 32.508), (104.138, 22.485)]
  ]

proc l1*(y1, x1, y2, x2: int): int =
  ## Integer L1 used by towers to pick a target (moba.h:543).
  abs(y1 - y2) + abs(x1 - x2)

proc l1f*(y1, x1: int, y2, x2: float): int =
  ## L1 from an integer cell to a truncated tower cell.
  l1(y1, x1, int(y2), int(x2))

proc chebyshev*(y1, x1, y2, x2: int): int =
  ## Chebyshev distance.
  max(abs(y1 - y2), abs(x1 - x2))

proc towerCell*(index: int): (int, int) =
  ## Truncated (y, x) cell of a static tower.
  (int(Towers[index].y), int(Towers[index].x))

proc shoots*(index: int): bool =
  ## Ancients have TOWER_DAMAGE 0 and cannot shoot.
  Towers[index].damage > 0.0

proc parseView*(observation: string): HeroView =
  ## Decodes reliable self bytes and 121 crop tile ids.
  doAssert observation.len == ObservationSize
  template selfByte(i: int): int =
    int(observation[SelfOffset + i].uint8)
  var
    heroType = 0
    bestHot = 0
  for i in 0 ..< 5:
    if selfByte(17 + i) > bestHot:
      bestHot = selfByte(17 + i)
      heroType = i
  result = HeroView(
    x: selfByte(0),
    y: selfByte(1),
    level: selfByte(2),
    health10: selfByte(3),
    mana10: selfByte(4),
    moveModifier: selfByte(7),
    eTimer: selfByte(12),
    qTimer: selfByte(10),
    wTimer: selfByte(11),
    team: if selfByte(16) == 1: 1 else: 0,
    heroType: heroType,
    deathFlag: selfByte(22),
    towerFlag: selfByte(25)
  )
  for i in 0 ..< CropTiles:
    result.crop[i] = observation[i].uint8

proc cropTile*(view: HeroView, dy, dx: int): int =
  ## Crop tile at (dy, dx) from self, or -1 if outside vision.
  if abs(dy) > VisionRange or abs(dx) > VisionRange:
    return -1
  int(view.crop[(dy + VisionRange) * CropWidth + (dx + VisionRange)])

proc friendlyCreepTile*(team: int): int =
  ## Tile id of this team's creeps.
  if team == 0: RadiantCreepTile else: DireCreepTile

proc minLaneDistance*(y, x, lane: int): float =
  ## Minimum L1 from (y, x) to a waypoint of one corridor.
  result = 1.0e9
  for (wy, wx) in Waypoints[lane]:
    let d = abs(wy - float(y)) + abs(wx - float(x))
    if d < result:
      result = d

proc classifyRegion*(y, x, team: int): Region =
  ## Fountain, nearest assigned corridor, or jungle.
  let (sy, sx) = Spawns[team]
  if l1(y, x, sy, sx) <= FountainRadius:
    return FountainRegion
  let base = 3 * team
  var
    bestLane = 0
    bestDist = minLaneDistance(y, x, base)
  for lane in 1 .. 2:
    let d = minLaneDistance(y, x, base + lane)
    if d < bestDist:
      bestDist = d
      bestLane = lane
  if bestDist <= float(LaneRadius):
    case bestLane
    of 0: TopRegion
    of 1: MidRegion
    else: BotRegion
  else:
    JungleRegion

proc regionName*(region: Region): string =
  ## Word for a map region.
  RegionNames[ord(region)]

proc assignedRegion*(pid: int): Region =
  ## Engine lane assignment for pid, as a Region.
  case AssignedLanes[pid mod 5]
  of 0: TopRegion
  of 1: MidRegion
  else: BotRegion

proc soakL1*(
  view: HeroView, towerY, towerX: int
): int =
  ## Closest visible friendly-creep L1 to a tower cell, or -1.
  result = -1
  let friendly = friendlyCreepTile(view.team)
  for dy in -VisionRange .. VisionRange:
    for dx in -VisionRange .. VisionRange:
      if int(view.crop[(dy + VisionRange) * CropWidth +
          (dx + VisionRange)]) != friendly:
        continue
      let d = l1(view.y + dy, view.x + dx, towerY, towerX)
      if result < 0 or d < result:
        result = d

proc nearestShootingEnemy*(
  y, x, team: int, dead: openArray[bool]
): (int, int) =
  ## (tower index, L1) of the closest live shooting enemy tower.
  result = (-1, 0)
  var best = 0
  for i, tower in Towers:
    if tower.team == team or not shoots(i) or dead[i]:
      continue
    let d = l1f(y, x, tower.y, tower.x)
    if result[0] < 0 or d < best:
      result = (i, d)
      best = d

proc visibleTowerDead*(view: HeroView, index: int): bool =
  ## True when the tower cell is in vision and is not a TOWER tile.
  let (ty, tx) = towerCell(index)
  let dy = ty - view.y
  let dx = tx - view.x
  if abs(dy) > VisionRange or abs(dx) > VisionRange:
    return false
  view.cropTile(dy, dx) != TowerTile
