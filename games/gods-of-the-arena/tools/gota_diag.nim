## Gods of the Arena diagnostics: isolated mechanics stages for BASIC policies.
## Build inside a polyworld worktree at the hosted engine commit (see readme).
## Usage: gota_diag [--stages A,B] [--seeds N] [--classes A,B] [--rows]
##   [--html PATH --notes PATH --build TEXT --art URL] [--tricks DIR]
##   [--trace TICKS --units --print] [--geometry] name=policy.bas ...
## Every stage places the policy's hero (Red slot 0) in a hand-built
## situation inside the real simulation, runs it for a few seconds, and
## scores the outcome 0 to 100. The table has one column per policy.
## base.bas must sit beside the binary (gank and duel opponents).

import
  std/[math, os, sequtils, strformat, strutils],
  bassy,
  polyworld/[pathing, tapes],
  content, events, maps, replays, arenas,
  sim {.all.}, bots {.all.}

const
  Scale = WorldScale
  OurSlot = 0
  EnemySlot = 5
  BenchTicks = HeroDeathTicks
  IdleSource = "x = 0\n"
  AllClasses = [Arcanist, Crossbowman, Berserker]

type
  Stage = enum
    CreepClear, LastHits, CreepPull, TowerSiege, TowerDiscipline, JungleCamp,
    PotionSurvival, GankEscape, Duel, Execute, FogChase, GroupTracking,
    SpellDodge, DummyBurst, GodPush, LaneDefense, RecallHome, Shopping,
    AbilityPoints

  Scenario = object
    game: Game
    hero: Hero
    benched: seq[int]
      ## Hero indices kept dead for the whole stage.
    immortal: seq[int]
      ## Hero indices healed to full every tick.
    ticks: int
    damageTaken: int
    damageByKind: array[7, int]
    damageDealtHeroes: int
    damageDealtBuildings: int
    kills: array[7, int]
    died: bool
    diedTick: int

  Policy = object
    name, source: string
    tricksDir: string
      ## When set, each stage runs its own one-trick script from this folder.

var
  traceEvery = 0
  traceUnits = false
  pullBack = 12.0
  printOurs = false

proc printer(): PrintProc =
  ## Forwards our hero's BASIC PRINT output to stderr.
  proc(event: PrintEvent) =
    case event.kind
    of TextPrint: stderr.write event.text
    of ValuePrint: stderr.write $event.value
    of FixedPrint: stderr.write $event.fixedValue
    of NewlinePrint: stderr.write "\n"

proc stageName(stage: Stage): string =
  ## Returns the short table label for one stage.
  case stage
  of CreepClear: "creep clear, no damage"
  of CreepPull: "creep pull into a wave stack"
  of LastHits: "last hits in a lane clash"
  of TowerSiege: "tower kill with creep support"
  of TowerDiscipline: "no tower tanking"
  of JungleCamp: "jungle camp clear"
  of PotionSurvival: "potion survival under creeps"
  of GankEscape: "escape a two-hero gank"
  of Duel: "1v1 duel vs base.bas"
  of Execute: "execute a fleeing hero"
  of FogChase: "track a hero into fog"
  of GroupTracking: "avoid a hidden group"
  of SpellDodge: "dodge telegraphed meteors"
  of DummyBurst: "burst an idle hero"
  of GodPush: "kill an exposed god"
  of LaneDefense: "defend a pushed tower"
  of RecallHome: "recall and heal"
  of Shopping: "spend gold in the keep"
  of AbilityPoints: "spend ability points"

proc tile(value: int32): int32 =
  ## Converts world units to global map tiles.
  mapCoordinate(value, RedTeam)

proc distanceTiles(a, b: WorldPoint): float =
  ## Returns planar distance in tiles.
  let
    dx = float(a.x - b.x) / Scale.float
    dz = float(a.z - b.z) / Scale.float
  sqrt(dx * dx + dz * dz)

proc standPoint(x, z: int32, team: Team): WorldPoint =
  ## Snaps a world position to the nearest open navigation tile.
  var navTile: NavTile
  doAssert nearestNavTile(
    floorWorldTile(x, team) + mapTiles() div 2,
    floorWorldTile(z, team) + mapTiles() div 2,
    0, navTile, @[], team == RedTeam
  ), "no open tile near the requested point"
  worldPoint(pathPoint(navTile.layer, navTile.x, navTile.z))

proc lanePoint(lane: int, fraction: float): WorldPoint =
  ## Returns a lane path point from Red (0.0) to Blue (1.0).
  let
    path = lanePathPoints[lane]
    index = clamp(int(round(fraction * float(path.len - 1))), 0, path.len - 1)
  worldPoint(path[index])

proc laneFraction(lane: int, point: WorldPoint): float =
  ## Returns the lane fraction of the path point nearest to a position.
  let path = lanePathPoints[lane]
  var
    best = float.high
    bestIndex = 0
  for i, pathPoint in path:
    let distance = distanceTiles(worldPoint(pathPoint), point)
    if distance < best:
      best = distance
      bestIndex = i
  bestIndex.float / float(path.len - 1)

proc offset(point: WorldPoint, dx, dz: float): WorldPoint =
  ## Shifts a point by whole or fractional tiles.
  WorldPoint(
    x: point.x + int32(dx * Scale.float),
    y: point.y,
    z: point.z + int32(dz * Scale.float)
  )

proc toward(a, b: WorldPoint, tiles: float): WorldPoint =
  ## Moves from a toward b by a number of tiles.
  let distance = max(distanceTiles(a, b), 0.001)
  a.offset(
    float(b.x - a.x) / Scale.float * tiles / distance,
    float(b.z - a.z) / Scale.float * tiles / distance
  )

proc findTower(world: World, team: Team, lane: int, tier: TowerTier): int =
  ## Returns the building index of one lane tower.
  for i, building in world.buildings:
    if building.kind == TowerBuilding and building.team == team and
        building.lane == lane and building.tier == tier:
      return i
  -1

proc newScenario(policy: string, class: HeroClass, level, seed: int): Scenario =
  ## Builds a quiet arena: no waves, no camps, every other hero benched.
  var config = GotaConfig(seed: ArenaSeed)
  config.maxTicks = 1_000_000
  let map = generateMap(int32(seed), config.mapPreset)
  result.game = newGame(
    map, config.spawnIntervalTicks, HeroClassCount, false, ReplayData(),
    drafting = false
  )
  let game = result.game
  game.recorder = initReplayRecorder(
    currentSetup(game, uint32(config.maxTicks)), map.preset
  )
  game.recorder.data.config = config
  game.world.spawnTimerTicks = int32.high div 2
  for camp in game.world.camps.mitems:
    camp.started = false
    camp.respawnTick = int32.high
  activeGame = game
  let
    limits = heroVmLimits()
    schema = initHeroHost(0)
  game.heroVms.setLen(game.world.heroes.len)
  for i, hero in game.world.heroes:
    let program = compile(if i == OurSlot: policy else: IdleSource,
      schema, limits)
    if i == 0:
      bindHeroData(program)
    game.heroVms[i] = HeroVm(
      runtime: initRuntime(program, initHeroHost(hero.id), limits),
      limits: limits,
      ready: true
    )
    if i == OurSlot and printOurs:
      game.heroVms[i].output = printer()
    if i != OurSlot:
      result.benched.add i
  result.hero = game.world.heroes[OurSlot]

proc setScript(s: var Scenario, index: int, source: string) =
  ## Replaces one hero's BASIC program.
  activeGame = s.game
  let
    limits = heroVmLimits()
    program = compile(source, initHeroHost(0), limits)
  s.game.heroVms[index] = HeroVm(
    runtime: initRuntime(
      program, initHeroHost(s.game.world.heroes[index].id), limits
    ),
    limits: limits,
    ready: true
  )

proc setupHero(hero: Hero, class: HeroClass, level: int, gold = 0) =
  ## Rebuilds a hero at a class and level with full health and mana.
  hero.class = class
  hero.level = level
  hero.xp = 0
  hero.gold = gold
  hero.maxHp = 0
  hero.hp = 0
  hero.maxMana = 0
  hero.mana = 0
  refreshHeroStats(hero)
  hero.hp = hero.maxHp
  hero.mana = hero.maxMana
  hero.state = Marching
  hero.initHeroCharges()

proc learnAll(hero: Hero) =
  ## Spends every ability point R, W, E, Q like base.bas.
  for pass in 0 ..< 20:
    for slot in [UltimateAbility, PrimaryAbility, SecondaryAbility,
        PassiveAbility]:
      if hero.abilityLevelError(slot) == NoActionError:
        inc hero.abilityLevels[slot]
  hero.initHeroCharges()

proc activate(s: var Scenario, index: int, class: HeroClass, level: int,
    source = IdleSource) =
  ## Brings a benched hero into the stage at its spawn with a program.
  let hero = s.game.world.heroes[index]
  s.benched.keepItIf(it != index)
  hero.setupHero(class, level)
  hero.learnAll()
  s.setScript(index, source)

proc spawnCreep(world: World, team: Team, kind: CreepKind, lane: int,
    at: WorldPoint): int32 =
  ## Adds one lane creep that then marches along its lane.
  let placed = standPoint(at.x, at.z, team)
  var navTile: NavTile
  discard navTileAt(placed, navTile, team)
  let facing =
    if team == RedTeam: heading(1, -1) else: heading(-1, 1)
  var footman = Footman(
    id: world.nextFootmanId,
    kind: kind,
    team: team,
    lane: lane,
    position: placed,
    facing: facing,
    body: bindBody(placed, facing, FootmanBodyRadius),
    hp: FootmanHp,
    state: Marching,
    animClip: runClip,
    surfaceHint: placed.y,
    navLayer: navTile.layer.int32
  )
  inc world.nextFootmanId
  var
    nearest = 0
    best = float.high
  for i in 0 ..< laneWorldPaths[lane].len:
    let distance = distanceTiles(footman.waypointAt(i), placed)
    if distance < best:
      best = distance
      nearest = i
  footman.waypointIndex = min(nearest + 1, laneWorldPaths[lane].len - 1)
  footman.advanceWaypoints()
  world.footmen.add footman
  footman.id

proc spawnWaveAt(world: World, team: Team, lane: int, at: WorldPoint,
    melee = 3, ranged = 1): seq[int32] =
  ## Adds a small creep wave in a loose line.
  for i in 0 ..< melee + ranged:
    let
      kind = if i < melee: MeleeCreep else: RangedCreep
      spot = at.offset(float(i mod 3) - 1.0, float(i div 3) * 1.0)
    result.add world.spawnCreep(team, kind, lane, spot)

proc footmanAlive(world: World, id: int32): bool =
  ## Reports whether a creep with this ID is still standing.
  for unit in world.footmen:
    if unit.id == id:
      return unit.hp > 0 and unit.state != Dying
  false

proc heroAlive(hero: Hero): bool =
  ## Reports whether a hero is alive.
  hero.hp > 0 and hero.state != Dying

proc step(s: var Scenario) =
  ## Advances one tick and gathers the stage metrics from events.
  let world = s.game.world
  for index in s.benched:
    let hero = world.heroes[index]
    hero.state = Dying
    hero.hp = 0
    hero.deaths = max(hero.deaths, 1)
    hero.deathTicks = BenchTicks
    hero.place(hero.spawnPosition)
  for index in s.immortal:
    let hero = world.heroes[index]
    if hero.heroAlive:
      hero.hp = hero.maxHp
  world.spawnTimerTicks = int32.high div 2
  let game = s.game
  tickWorld(game, proc() =
    runBotDecisions(game)
  )
  inc s.ticks
  if traceEvery > 0 and s.ticks mod traceEvery == 0:
    var line = &"t {s.ticks.float / TickRate.float:5.1f}"
    for hero in world.heroes:
      if hero.heroAlive:
        line.add &" | h{hero.id} {hero.class} {tile(hero.position.x)}," &
          &"{tile(hero.position.z)} hp {hero.hp}/{hero.maxHp} " &
          &"gold {hero.gold} tgt {hero.attackObjectId} " &
          &"err {hero.lastActionError} portal {hero.portalEnds} " &
          &"vm {s.game.heroVms[world.heroIndex(hero.id)].decisions}"
    var creeps = 0
    for unit in world.footmen:
      if unit.hp > 0 and unit.state != Dying:
        inc creeps
    line.add &" | units {creeps} dmg {s.damageTaken}"
    if traceUnits:
      for unit in world.footmen:
        if unit.hp > 0 and unit.state != Dying:
          line.add &" [{unit.id} c{unit.camp} {tile(unit.position.x)}," &
            &"{tile(unit.position.z)} {unit.hp}]"
    stderr.writeLine line
  let id = s.hero.id
  for event in world.events:
    case event.kind
    of Damage:
      if event.target.id == id:
        s.damageTaken += int(event.amount)
        s.damageByKind[clamp(event.actor.kind, 0, 6)] += int(event.amount)
      elif event.actor.id == id:
        case event.target.kind
        of HeroObjectKind:
          s.damageDealtHeroes += int(event.amount)
        of 4, 5:
          s.damageDealtBuildings += int(event.amount)
        else:
          discard
    of Death:
      if event.actor.id == id:
        inc s.kills[clamp(event.target.kind, 0, 6)]
      if event.target.id == id and not s.died:
        s.died = true
        s.diedTick = s.ticks
    else:
      discard

proc run(s: var Scenario, seconds: float) =
  ## Advances a number of simulated seconds.
  for i in 0 ..< int(seconds * TickRate.float):
    s.step()

proc hpFraction(hero: Hero): float =
  ## Returns current health as a fraction of maximum.
  if not hero.heroAlive:
    return 0.0
  hero.hp.float / max(hero.maxHp, 1).float

proc geometry() =
  ## Prints landmarks used to place stage units.
  var s = newScenario(IdleSource, Arcanist, 1, 1)
  let world = s.game.world
  echo &"map tiles {mapTiles()}"
  for lane in 0 .. 2:
    let path = lanePathPoints[lane]
    echo &"lane {lane}: {path.len} points, start " &
      &"{tile(lanePoint(lane, 0).x)},{tile(lanePoint(lane, 0).z)} mid " &
      &"{tile(lanePoint(lane, 0.5).x)},{tile(lanePoint(lane, 0.5).z)} end " &
      &"{tile(lanePoint(lane, 1).x)},{tile(lanePoint(lane, 1).z)}"
  for building in world.buildings:
    echo &"building {building.id} {building.kind} {building.team} " &
      &"lane {building.lane} {building.tier} at " &
      &"{tile(building.position.x)},{tile(building.position.z)} frac " &
      &"{laneFraction(max(building.lane, 0), building.position):.3f} " &
      &"hp {building.hp}"
  for fort in world.forts:
    echo &"god {fort.id} {fort.team} at {tile(fort.center.x)}," &
      &"{tile(fort.center.z)} hp {fort.hp}"
  for i, camp in world.camps:
    var line = &"camp {i} tier {camp.tier} count {camp.count} at " &
      &"{tile(camp.center.x)},{tile(camp.center.z)}"
    for lane in 0 .. 2:
      var best = float.high
      for point in laneWorldPaths[lane]:
        best = min(best, distanceTiles(point, camp.center))
      line.add &" lane{lane} {best:.1f}"
    echo line
  for team in Team:
    echo &"spawn {team} {tile(world.heroSpawns[team.ord].x)}," &
      &"{tile(world.heroSpawns[team.ord].z)}"

proc mapTile(point: WorldPoint): tuple[x, y: int32] =
  ## Returns the global map tile BASIC scripts use for a point.
  (tile(point.x), tile(point.z))

proc fleeSource(target: WorldPoint): string =
  ## Builds a script that walks to one tile and nothing else.
  let spot = target.mapTile
  &"accepted = walkTo({spot.x}, {spot.y})\n"

proc ambushSource(hide: WorldPoint, radius: int): string =
  ## Builds a script that hides at a tile and attacks enemy heroes nearby.
  let spot = hide.mapTile
  &"""
found = 0
for i = 0 to objectCount() - 1
  if objectKind(i) = 2 and objectTeam(i) <> selfTeam and objectAlive(i) = 1 then
    dx = objectX(i) - selfX
    dy = objectY(i) - selfY
    if dx * dx + dy * dy <= {radius * radius} then
      accepted = attackTarget(objectId(i))
      found = 1
      exit for
    end if
  end if
next
if found = 0 then
  accepted = walkTo({spot.x}, {spot.y})
end if
"""

proc casterSource(slot, interval: int, hold: WorldPoint): string =
  ## Builds a script that holds a tile and drops a ground spell on enemies.
  let spot = hold.mapTile
  &"""
accepted = walkTo({spot.x}, {spot.y})
for i = 0 to objectCount() - 1
  if objectKind(i) = 2 and objectTeam(i) <> selfTeam and objectAlive(i) = 1 then
    if worldTick >= nextCast then
      accepted = castPoint({slot}, objectX(i), objectY(i))
      if accepted = 1 then
        nextCast = worldTick + {interval}
      end if
    end if
    exit for
  end if
next
"""

proc put(s: Scenario, hero: Hero, at: WorldPoint) =
  ## Teleports a hero and replans any walk it had in progress.
  hero.place(standPoint(at.x, at.z, hero.team))
  hero.applyBody()
  if hero.hasMoveTarget:
    let
      targetX = hero.moveTileX
      targetY = hero.moveTileY
    hero.hasMoveTarget = false
    navigationWorld = s.game.world
    discard hero.setHeroDestination(
      targetX, targetY, hero.position.y, hero.moveOffset
    )

proc warmup(s: var Scenario) =
  ## Runs the first decision at the spawn so policies record their home.
  s.step()
  s = Scenario(
    game: s.game, hero: s.hero, benched: s.benched, immortal: s.immortal
  )

proc jitter(seed: int): float =
  ## Returns a small per-seed placement shift in tiles.
  float(seed mod 3 - 1)

proc heroStart(seed: int, fraction: float): WorldPoint =
  ## Returns a middle lane point with a per-seed sideways shift.
  lanePoint(1, fraction).offset(jitter(seed) * 0.7, -jitter(seed) * 0.7)

proc give(hero: Hero, slot: int, item: Item, count: int) =
  ## Puts a stack of one item into an inventory slot.
  hero.inventory[slot] = item
  hero.itemCounts[slot] = int32(count)
  refreshHeroStats(hero)

proc damageFraction(s: Scenario, amount: int): float =
  ## Returns damage as a fraction of our maximum health, clamped to 1.
  clamp(amount.float / max(s.hero.maxHp, 1).float, 0.0, 1.0)

proc survivalScore(s: Scenario, seconds: float): float =
  ## Scores 100 for surviving, otherwise the share of the stage survived.
  if not s.died:
    100.0
  else:
    100.0 * s.diedTick.float / (seconds * TickRate.float)

proc runUntilCleared(s: var Scenario, ids: seq[int32], seconds: float): int =
  ## Runs until every listed unit dies or time ends; returns the dead count.
  for i in 0 ..< int(seconds * TickRate.float):
    s.step()
    result = 0
    for id in ids:
      if not s.game.world.footmanAlive(id):
        inc result
    if result == ids.len:
      return

proc begin(policy: string, class: HeroClass, level, seed: int): Scenario =
  ## Creates a stage with our hero ready at its spawn.
  result = newScenario(policy, class, level, seed)
  result.hero.setupHero(class, level)

proc stageCreepClear(policy: string, class: HeroClass, seed: int): float =
  ## Four enemy creeps walk into a lone hero; kill them all unhurt.
  var s = begin(policy, class, 3, seed)
  s.warmup()
  s.put(s.hero, heroStart(seed, 0.45))
  let ids = s.game.world.spawnWaveAt(BlueTeam, 1, lanePoint(1, 0.56))
  let killed = s.runUntilCleared(ids, 30)
  100.0 * killed.float / ids.len.float * (1.0 - s.damageFraction(s.damageTaken))

proc stageCreepPull(policy: string, class: HeroClass, seed: int): float =
  ## Pull a camp into our passing wave so the next wave catches it up.
  const
    CampIndex = 4
    Lane = 0
  var s = begin(policy, class, 8, seed)
  s.warmup()
  let world = s.game.world
  world.camps[CampIndex].respawnTick = 0
  world.spawnCamp(CampIndex)
  world.camps[CampIndex].respawnTick = int32.high
  let center = world.camps[CampIndex].center
  var
    nearest = 0
    best = float.high
  let path = laneWorldPaths[Lane]
  for i, point in path:
    if distanceTiles(point, center) < best:
      best = distanceTiles(point, center)
      nearest = i
  var back = nearest
  while back > 0 and distanceTiles(path[back], path[nearest]) < pullBack:
    dec back
  let
    laneSpot = path[nearest]
    waveStart = path[back]
  s.put(s.hero, center.toward(laneSpot, 6.0 + jitter(seed) * 0.5))
  let first = world.spawnWaveAt(RedTeam, Lane, waveStart)
  var
    second: seq[int32]
    pullDamage = 0
    stacked = 0
  block run:
    for i in 0 ..< 30 * TickRate:
      if i == 6 * TickRate:
        second = world.spawnWaveAt(RedTeam, Lane, waveStart)
      s.step()
      for event in world.events:
        if event.kind == Damage and event.actor.kind == 6 and
            event.target.kind == 3 and event.target.team == RedTeam.ord:
          pullDamage += int(event.amount)
      # Judge the stack when the second wave reaches the camp's lane spot.
      for unit in world.footmen:
        if unit.id in second and unit.hp > 0 and
            distanceTiles(unit.position, laneSpot) <= 3.0:
          for held in world.footmen:
            if held.id in first and held.hp > 0 and held.state != Dying and
                distanceTiles(held.position, laneSpot) <= 8.0:
              inc stacked
          break run
  let pulled = min(1.0, pullDamage.float / 100.0)
  50.0 * pulled + 50.0 * stacked.float / first.len.float

proc stageLastHits(policy: string, class: HeroClass, seed: int): float =
  ## Two full waves clash; score the share of enemy creeps we last-hit.
  var s = begin(policy, class, 3, seed)
  s.warmup()
  s.put(s.hero, heroStart(seed, 0.46))
  discard s.game.world.spawnWaveAt(RedTeam, 1, lanePoint(1, 0.38), 6, 2)
  let enemies = s.game.world.spawnWaveAt(BlueTeam, 1, lanePoint(1, 0.62), 6, 2)
  s.run(45)
  100.0 * min(1.0, s.kills[3].float / enemies.len.float)

proc stageTowerSiege(policy: string, class: HeroClass, seed: int): float =
  ## Our waves push the enemy outer tower; deal half its health unhurt.
  var s = begin(policy, class, 6, seed)
  s.warmup()
  s.put(s.hero, heroStart(seed, 0.58))
  let
    world = s.game.world
    tower = world.findTower(BlueTeam, 1, OuterTower)
    maxHp = world.buildings[tower].maxHp
  block siege:
    for wave in 0 ..< 3:
      discard world.spawnWaveAt(RedTeam, 1, lanePoint(1, 0.57), 6, 2)
      for i in 0 ..< 20 * TickRate:
        s.step()
        if world.buildings[tower].hp <= 0:
          break siege
  let share = min(1.0, s.damageDealtBuildings.float / (0.25 * maxHp.float))
  100.0 * share * (1.0 - s.damageFraction(s.damageByKind[4]))

proc stageTowerDiscipline(policy: string, class: HeroClass, seed: int): float =
  ## Alone in front of an enemy tower with no creeps: never tank it.
  var s = begin(policy, class, 4, seed)
  s.warmup()
  let tower = s.game.world.findTower(BlueTeam, 1, OuterTower)
  s.put(s.hero, s.game.world.buildings[tower].position.toward(
    lanePoint(1, 0.4), 12.0))
  s.run(30)
  100.0 * (1.0 - s.damageFraction(s.damageByKind[4]))

proc stageJungleCamp(policy: string, class: HeroClass, seed: int): float =
  ## A two-unit camp beside the hero; clear it unhurt.
  const CampIndex = 9
  var s = begin(policy, class, 3, seed)
  s.warmup()
  let world = s.game.world
  world.camps[CampIndex].respawnTick = 0
  world.spawnCamp(CampIndex)
  world.camps[CampIndex].respawnTick = int32.high
  let center = world.camps[CampIndex].center
  s.put(s.hero, center.toward(lanePoint(1, 0.4), 4.0))
  var ids: seq[int32]
  for unit in world.footmen:
    if unit.camp == CampIndex + 1:
      ids.add unit.id
  let killed = s.runUntilCleared(ids, 40)
  100.0 * killed.float / max(ids.len, 1).float *
    (1.0 - s.damageFraction(s.damageTaken))

proc stagePotionSurvival(policy: string, class: HeroClass, seed: int): float =
  ## At 30% health with a full enemy wave on top of us, holding potions.
  const Seconds = 40.0
  var s = begin(policy, class, 4, seed)
  s.warmup()
  s.hero.give(0, VitalityElixir, 2)
  s.hero.give(1, HealthPotion, 2)
  s.hero.hp = s.hero.maxHp * 30 div 100
  let start = heroStart(seed, 0.44)
  s.put(s.hero, start)
  var ids: seq[int32]
  for wave in 0 ..< 3:
    ids.add s.game.world.spawnWaveAt(BlueTeam, 1,
      start.toward(lanePoint(1, 1.0), 3.0), 6, 2)
    if wave < 2:
      s.run(6)
  discard s.runUntilCleared(ids, Seconds - 12)
  if s.died:
    50.0 * s.diedTick.float / (Seconds * TickRate.float)
  else:
    50.0 + 50.0 * s.hero.hpFraction

proc stageGankEscape(policy: string, class: HeroClass, seed: int): float =
  ## Two enemy bruisers charge from 9 tiles at 70% health: survive 20 s.
  var s = begin(policy, class, 5, seed)
  let base = readFile(getAppDir() / "base.bas")
  s.activate(EnemySlot, VanguardKnight, 5, base)
  s.activate(EnemySlot + 1, DeathKnight, 5, base)
  s.warmup()
  let start = heroStart(seed, 0.5)
  s.hero.hp = s.hero.maxHp * 7 div 10
  s.put(s.hero, start)
  let world = s.game.world
  s.put(world.heroes[EnemySlot], start.toward(lanePoint(1, 1.0), 9.0))
  s.put(world.heroes[EnemySlot + 1],
    start.toward(lanePoint(1, 1.0), 9.0).offset(1, 1))
  s.run(20)
  s.survivalScore(20)

proc stageDuel(policy: string, class: HeroClass, seed: int): float =
  ## Mirror 1v1 against base.bas at level 6, no creeps.
  var s = begin(policy, class, 6, seed)
  s.activate(EnemySlot, class, 6, readFile(getAppDir() / "base.bas"))
  s.warmup()
  let start = heroStart(seed, 0.47)
  s.put(s.hero, start)
  let enemy = s.game.world.heroes[EnemySlot]
  s.put(enemy, start.toward(lanePoint(1, 1.0), 8.0))
  var enemyDied = false
  for i in 0 ..< 60 * TickRate:
    s.step()
    if not enemy.heroAlive:
      enemyDied = true
    if enemyDied or s.died:
      break
  if enemyDied and not s.died:
    100.0
  elif s.died:
    0.0
  else:
    clamp(50.0 + 50.0 * (s.hero.hpFraction - enemy.hpFraction), 0.0, 100.0)

proc parScore(ticks: int, par, seconds: float): float =
  ## Scores a kill 100 within par time, then down to 50 at the time limit.
  let t = ticks.float / TickRate.float
  if t <= par:
    100.0
  else:
    100.0 - 50.0 * (t - par) / (seconds - par)

proc stageExecute(policy: string, class: HeroClass, seed: int): float =
  ## A 35% health Death Knight runs home from 3 tiles away: kill it fast.
  const Seconds = 15.0
  var s = begin(policy, class, 5, seed)
  let world = s.game.world
  s.activate(EnemySlot, DeathKnight, 5,
    fleeSource(world.heroSpawns[BlueTeam.ord]))
  s.warmup()
  let start = heroStart(seed, 0.47)
  s.put(s.hero, start)
  let enemy = world.heroes[EnemySlot]
  s.put(enemy, start.toward(lanePoint(1, 1.0), 3.0))
  enemy.hp = enemy.maxHp * 35 div 100
  let startHp = enemy.hp
  for i in 0 ..< int(Seconds * TickRate.float):
    s.step()
    if not enemy.heroAlive:
      return parScore(s.ticks, 8.0, Seconds)
  50.0 * (1.0 - enemy.hp.float / startHp.float)

proc stageFogChase(policy: string, class: HeroClass, seed: int): float =
  ## A low enemy hero slips into the jungle fog: keep it in sight, kill it.
  const Seconds = 20.0
  var s = begin(policy, class, 5, seed)
  let world = s.game.world
  s.activate(EnemySlot, Lich, 5, fleeSource(world.camps[2].center))
  s.warmup()
  let start = heroStart(seed, 0.47)
  s.put(s.hero, start)
  let enemy = world.heroes[EnemySlot]
  s.put(enemy, start.toward(lanePoint(1, 1.0), 7.5))
  enemy.hp = enemy.maxHp * 35 div 100
  var seen = 0
  for i in 0 ..< int(Seconds * TickRate.float):
    s.step()
    if not enemy.heroAlive:
      return 100.0
    if world.visible(RedTeam, enemy.position):
      inc seen
  80.0 * seen.float / s.ticks.float

proc stageGroupTracking(policy: string, class: HeroClass, seed: int): float =
  ## Three enemy heroes show themselves, then hide beside the lane: live.
  const Seconds = 40.0
  var s = begin(policy, class, 5, seed)
  let
    world = s.game.world
    classes = [Berserker, DemonHunter, VanguardKnight]
    hide = lanePoint(1, 0.58).toward(world.camps[2].center, 6.0)
  for k in 0 ..< 3:
    s.activate(EnemySlot + k, classes[k], 6,
      ambushSource(hide.offset(float(k) - 1.0, 0), 6))
  s.warmup()
  let start = heroStart(seed, 0.45)
  s.put(s.hero, start)
  for k in 0 ..< 3:
    s.put(world.heroes[EnemySlot + k],
      start.toward(lanePoint(1, 1.0), 9.5).offset(float(k) - 1.0, 0))
  s.run(Seconds)
  s.survivalScore(Seconds)

proc stageSpellDodge(policy: string, class: HeroClass, seed: int): float =
  ## An untouchable enemy Arcanist drops a meteor on us every 2.5 s.
  var s = begin(policy, class, 5, seed)
  let
    start = heroStart(seed, 0.5)
    hold = start.toward(lanePoint(1, 1.0), 5.0)
  s.activate(EnemySlot, Arcanist, 3,
    casterSource(ord(SecondaryAbility), 60, hold))
  s.immortal.add EnemySlot
  s.warmup()
  s.put(s.hero, start)
  let caster = s.game.world.heroes[EnemySlot]
  s.put(caster, hold)
  var casts, hits = 0
  for i in 0 ..< 30 * TickRate:
    caster.cooldowns[SecondaryAbility] = 0
    caster.charges[SecondaryAbility] = 1
    caster.recharges[SecondaryAbility] = 0
    caster.mana = caster.maxMana
    s.step()
    for event in s.game.world.events:
      if event.kind == SpellReleased and event.actor.id == caster.id:
        inc casts
      if event.kind == Damage and event.target.id == s.hero.id and
          event.actor.id == caster.id and event.cause == AbilityEffect:
        inc hits
    if s.died:
      break
  if casts == 0:
    return 100.0
  100.0 * (1.0 - min(1.0, hits.float / casts.float))

proc stageDummyBurst(policy: string, class: HeroClass, seed: int): float =
  ## A Druid stands idle 4 tiles away: deal its health within 8 s.
  var s = begin(policy, class, 6, seed)
  s.activate(EnemySlot, DruidWarden, 6)
  s.warmup()
  let start = heroStart(seed, 0.5)
  s.put(s.hero, start)
  let enemy = s.game.world.heroes[EnemySlot]
  s.put(enemy, start.toward(lanePoint(1, 1.0), 4.0))
  s.run(8)
  if not enemy.heroAlive:
    return 100.0
  100.0 * min(1.0, s.damageDealtHeroes.float / enemy.maxHp.float)

proc stageGodPush(policy: string, class: HeroClass, seed: int): float =
  ## The enemy god stands exposed 9 tiles away: kill it.
  const Seconds = 30.0
  var s = begin(policy, class, 8, seed)
  let world = s.game.world
  for building in world.buildings.mitems:
    if building.team == BlueTeam and building.kind == TowerBuilding and
        (building.lane == 1 or building.guardsGod):
      building.hp = 0
  s.warmup()
  let god = world.forts[BlueTeam.ord]
  s.put(s.hero, god.center.toward(lanePoint(1, 0.5), 9.0))
  for i in 0 ..< int(Seconds * TickRate.float):
    s.step()
    if world.forts[BlueTeam.ord].hp <= 0:
      return parScore(s.ticks, 12.0, Seconds)
  50.0 * (1.0 - world.forts[BlueTeam.ord].hp.float / FortHp.float)

proc stageLaneDefense(policy: string, class: HeroClass, seed: int): float =
  ## An enemy wave marches on our outer mid tower while we stand in the keep.
  var s = begin(policy, class, 5, seed)
  s.warmup()
  s.hero.give(0, PortalScroll, 1)
  let world = s.game.world
  let tower = world.findTower(RedTeam, 1, OuterTower)
  let ids = world.spawnWaveAt(BlueTeam, 1,
    world.buildings[tower].position.toward(lanePoint(1, 0.6), 18.0), 6, 2)
  s.run(60)
  100.0 * min(1.0, s.kills[3].float / ids.len.float)

proc stageRecallHome(policy: string, class: HeroClass, seed: int): float =
  ## At 12% health deep in enemy land with a portal scroll: get home.
  var s = begin(policy, class, 5, seed)
  s.warmup()
  s.hero.give(0, PortalScroll, 1)
  s.hero.hp = s.hero.maxHp * 12 div 100
  s.put(s.hero, heroStart(seed, 0.62))
  s.run(30)
  if s.died:
    return 0.0
  100.0 * s.hero.hpFraction

proc stageShopping(policy: string, class: HeroClass, seed: int): float =
  ## Level 5 in the spawn room with 1,500 gold: turn it into items.
  var s = begin(policy, class, 5, seed)
  s.hero.gold = 1_500
  s.run(10)
  100.0 * min(1.0, float(1_500 - s.hero.gold) / 1_000.0)

proc stageAbilityPoints(policy: string, class: HeroClass, seed: int): float =
  ## Level 7 with seven banked points in the spawn room: spend them.
  var s = begin(policy, class, 7, seed)
  s.run(3)
  100.0 * float(7 - s.hero.abilityPoints) / 7.0

type
  AbilityUse = object
    casts, good: array[HeroAbilitySlot, int]

const SlotKeys: array[HeroAbilitySlot, string] = ["Q", "W", "E", "R"]

proc abilityRun(policy: string, class: HeroClass, seed: int): AbilityUse =
  ## Counts casts and correct casts per slot against an unkillable dummy.
  var s = begin(policy, class, 7, seed)
  let
    start = heroStart(seed, 0.5)
    hold = start.toward(lanePoint(1, 1.0), 4.0)
  s.activate(EnemySlot, VanguardKnight, 7, fleeSource(hold))
  s.immortal.add EnemySlot
  s.warmup()
  s.put(s.hero, start)
  s.put(s.game.world.heroes[EnemySlot], hold)
  s.hero.hp = s.hero.maxHp * 6 div 10
  var effects: array[HeroAbilitySlot, seq[int]]
  let world = s.game.world
  for i in 0 ..< 20 * TickRate:
    s.step()
    for event in world.events:
      if event.actor.id != s.hero.id or event.cause != AbilityEffect:
        continue
      var slot = -1
      for candidate in HeroAbilitySlot:
        if heroAbility(class, candidate).ord == event.detail:
          slot = candidate.ord
      if slot < 0:
        continue
      let key = HeroAbilitySlot(slot)
      case event.kind
      of SpellReleased:
        inc result.casts[key]
      of Damage:
        if event.target.team != RedTeam.ord and event.amount > 0 and
            s.ticks notin effects[key]:
          effects[key].add s.ticks
      of Healing, ManaChanged:
        if event.after > event.before and s.ticks notin effects[key]:
          effects[key].add s.ticks
      else:
        discard
    if s.died:
      break
  for slot in HeroAbilitySlot:
    result.good[slot] = min(effects[slot].len, result.casts[slot])

proc abilityScore(use: AbilityUse): float =
  ## Mean over the four slots of correct casts per cast (0 when never cast).
  for slot in HeroAbilitySlot:
    if use.casts[slot] > 0:
      result += 25.0 * use.good[slot].float / use.casts[slot].float

proc runStage(stage: Stage, policy: string, class: HeroClass,
    seed: int): float =
  ## Dispatches one stage run.
  case stage
  of CreepClear: stageCreepClear(policy, class, seed)
  of CreepPull: stageCreepPull(policy, class, seed)
  of LastHits: stageLastHits(policy, class, seed)
  of TowerSiege: stageTowerSiege(policy, class, seed)
  of TowerDiscipline: stageTowerDiscipline(policy, class, seed)
  of JungleCamp: stageJungleCamp(policy, class, seed)
  of PotionSurvival: stagePotionSurvival(policy, class, seed)
  of GankEscape: stageGankEscape(policy, class, seed)
  of Duel: stageDuel(policy, class, seed)
  of Execute: stageExecute(policy, class, seed)
  of FogChase: stageFogChase(policy, class, seed)
  of GroupTracking: stageGroupTracking(policy, class, seed)
  of SpellDodge: stageSpellDodge(policy, class, seed)
  of DummyBurst: stageDummyBurst(policy, class, seed)
  of GodPush: stageGodPush(policy, class, seed)
  of LaneDefense: stageLaneDefense(policy, class, seed)
  of RecallHome: stageRecallHome(policy, class, seed)
  of Shopping: stageShopping(policy, class, seed)
  of AbilityPoints: stageAbilityPoints(policy, class, seed)

proc parseClass(name: string): HeroClass =
  ## Parses a hero class name.
  for class in HeroClass:
    if ($class).toLowerAscii == name.toLowerAscii:
      return class
  quit("unknown class: " & name)

proc stageSetup(stage: Stage): tuple[setup, score: string] =
  ## Describes one stage's situation and scoring for the report.
  case stage
  of CreepClear:
    ("L3 hero; 3 melee and 1 ranged enemy creep walk in on the middle lane.",
      "Killed share times (1 - damage taken / max hp). " &
      "Ends when the wave dies.")
  of CreepPull:
    ("L8 hero 6 tiles from a four-mob high camp that sits 7 tiles off " &
      "our side of lane 0; our 4-creep wave walks past, a second wave " &
      "follows 6 s later.",
      "50 x camp damage to our creeps (pull, full at 100) + 50 x share of " &
      "the first wave still within 8 tiles of the camp's lane spot when " &
      "the second wave arrives (stack).")
  of LastHits:
    ("L3 hero beside two 8-creep waves clashing.",
      "Our last hits out of the 8 enemy creeps.")
  of TowerSiege:
    ("L6 hero near the Blue outer mid tower; three friendly waves 20 s apart.",
      "Our tower damage over 25% of its hp, times (1 - tower damage taken). " &
      "Ends when the tower falls.")
  of TowerDiscipline:
    ("L4 hero alone 12 tiles from the enemy outer tower, no creeps, 30 s.",
      "1 - tower damage taken / max hp.")
  of JungleCamp:
    ("L3 hero 4 tiles from a two-unit tier 1 camp.",
      "Killed share times (1 - damage taken).")
  of PotionSurvival:
    ("L4 hero at 30% hp with 2 vitality elixirs and 2 health potions; " &
      "three 8-creep waves 6 s apart.",
      "Alive: 50 + 50 x end hp share. Dead: 50 x share of time alive.")
  of GankEscape:
    ("L5 hero at 70% hp; base.bas Vanguard and Death Knight charge from " &
      "9 tiles, 20 s.",
      "Share of the stage alive.")
  of Duel:
    ("L6 mirror class against base.bas from 8 tiles, no creeps, 60 s.",
      "Win 100, loss 0, otherwise 50 + 50 x hp lead.")
  of Execute:
    ("L5 Death Knight at 35% hp runs home from 3 tiles, 15 s.",
      "Kill within 8 s scores 100, later kills down to 50, " &
      "otherwise 50 x hp removed.")
  of FogChase:
    ("L5 Lich at 35% hp runs into the west jungle from 7.5 tiles, 20 s.",
      "Kill 100, otherwise 80 x share of ticks it stayed visible.")
  of GroupTracking:
    ("Three L6 heroes seen 9.5 tiles ahead walk into fog beside the lane " &
      "and attack anything within 6 tiles, 40 s.",
      "Share of the stage alive.")
  of SpellDodge:
    ("An untouchable enemy Arcanist 5 tiles away drops Meteor Strike " &
      "(1.5 s telegraph) on us every 2.5 s, 30 s.",
      "1 - meteor hits / casts.")
  of DummyBurst:
    ("An idle L6 Druid 4 tiles away, 8 s.",
      "Damage dealt over its max hp.")
  of GodPush:
    ("L8 hero; the Blue god exposed 9 tiles away, 30 s.",
      "Kill within 12 s scores 100, later kills down to 50, " &
      "otherwise 50 x hp removed.")
  of LaneDefense:
    ("L5 hero in the spawn with a portal scroll; an 8-creep enemy wave " &
      "marches on our outer mid tower from 18 tiles out, 60 s.",
      "Enemy creeps we kill out of 8.")
  of RecallHome:
    ("L5 hero at 12% hp deep in enemy land with a portal scroll, 30 s.",
      "End hp share, 0 if dead.")
  of Shopping:
    ("L5 hero in the spawn with 1,500 gold, 10 s.",
      "Gold spent over 1,000.")
  of AbilityPoints:
    ("L7 hero with seven banked points in the spawn, 3 s.",
      "Points spent out of 7.")

const
  StageGroups = [
    ("Laning", "icons/minion.png",
      @[CreepClear, LastHits, CreepPull, JungleCamp]),
    ("Buildings", "icons/tower.png",
      @[TowerSiege, TowerDiscipline, GodPush, LaneDefense]),
    ("Fights", "icons/attack.png", @[Duel, DummyBurst, Execute]),
    ("Survival", "icons/health.png",
      @[PotionSurvival, GankEscape, SpellDodge, RecallHome]),
    ("Awareness", "icons/day.png", @[FogChase, GroupTracking]),
    ("Economy", "icons/gold.png", @[Shopping, AbilityPoints])
  ]
  ReportStyle = """
<style>
@font-face{font-family:Rubik;src:url(ARTfonts/Rubik-Regular.ttf) format('truetype');font-weight:400;font-display:swap}
@font-face{font-family:Rubik;src:url(ARTfonts/Rubik-Bold.ttf) format('truetype');font-weight:700;font-display:swap}
:root{color-scheme:dark;--bg:#0c1014;--panel:#16181e;--gold:#f7dd8f;--gold-dim:#c4a45a;
--text:#eef0f4;--muted:#a6aebf;--line:rgba(247,221,143,.18);
--good:#8fe0ad;--good-bg:#173524;--fair:#f2d472;--fair-bg:#3a3316;
--poor:#f59a8c;--poor-bg:#46211d}
*{box-sizing:border-box}
body{margin:0;color:var(--text);font:400 14px/1.5 Rubik,system-ui,sans-serif;
background:radial-gradient(1100px 550px at 20% -100px,#203e622f,transparent),
radial-gradient(900px 600px at 100% 45%,#6b29301a,transparent),var(--bg)}
a{color:var(--gold);text-decoration:none}
.wrap{width:min(1380px,calc(100% - 32px));margin-left:auto;margin-right:auto}
.site-header{display:flex;align-items:center;justify-content:space-between;gap:24px;
padding:12px 0;margin-bottom:20px;border-bottom:1px solid var(--line)}
.site-header img{display:block;width:120px;height:auto}
.site-nav{display:flex;flex-wrap:wrap;gap:8px;justify-content:flex-end}
.site-nav a{padding:10px 14px;border:1px solid transparent;border-radius:8px;color:var(--muted)}
.site-nav a:hover{color:var(--gold);background:#f7dd8f08}
.site-nav a[aria-current=page]{border-color:var(--line);background:#f7dd8f0c;color:var(--gold)}
.intro{display:flex;align-items:center;justify-content:space-between;gap:24px;margin:22px 0}
.eyebrow{color:var(--gold-dim);margin:0 0 10px;font-size:12px}
.eyebrow span{margin:0 10px;color:#6f725f}
h1{margin:0 0 12px;font:700 32px/1.2 Rubik,sans-serif}
h2{margin:0 0 12px;font:700 18px/1.3 Rubik,sans-serif;color:var(--gold)}
.lede{color:var(--muted);margin:0}
.badge{display:flex;align-items:center;gap:9px;white-space:nowrap;color:var(--gold);
border:1px solid var(--line);border-radius:24px;padding:9px 15px;background:#f7dd8f08;font-size:12px}
.badge i{width:6px;height:6px;background:var(--gold-dim);border-radius:50%}
.snapshot{display:flex;flex-wrap:wrap;gap:12px 34px;border-top:1px solid var(--line);
border-bottom:1px solid var(--line);padding:14px 0;margin-bottom:20px}
.snapshot>div{display:flex;align-items:baseline;gap:8px}
.snapshot strong{font:700 24px/1.25 Rubik,sans-serif;font-variant-numeric:tabular-nums}
.snapshot span{color:var(--muted);font-size:12px}
.snapshot .window{margin-left:auto;flex-direction:column;align-items:flex-end;gap:2px}
.snapshot .window strong{font:400 14px/1.5 Rubik,sans-serif}
.workspace{border:1px solid var(--line);border-radius:12px;overflow:hidden;background:#101419}
.toolbar{display:flex;flex-wrap:wrap;gap:10px 22px;align-items:center;padding:14px 20px;
background:#171c23;color:var(--muted);font-size:12px}
.toolbar .chip{display:inline-flex;align-items:center;gap:7px}
.toolbar .chip i{width:14px;height:14px;border-radius:3px;display:inline-block}
.chip .good{background:var(--good-bg);border:1px solid var(--good)}
.chip .fair{background:var(--fair-bg);border:1px solid var(--fair)}
.chip .poor{background:var(--poor-bg);border:1px solid var(--poor)}
.toolbar .hint{margin-left:auto}
.scroll{overflow-x:auto}
table{border-collapse:separate;border-spacing:0;width:max-content;min-width:100%;
font-variant-numeric:tabular-nums}
thead th{position:sticky;top:0;z-index:3;background:#141a21;border-bottom:1px solid #575340;
padding:14px 6px 10px;color:#c4cbd5;font-weight:400;font-size:13px;min-width:70px;vertical-align:bottom}
thead th.newest{color:var(--gold)}
thead th.ref,thead th.trick{color:#8fa6bd}
thead th small{display:block;color:#82909e;font-size:11px}
th.label{position:sticky;left:0;z-index:2;text-align:left;width:290px;min-width:290px;
background:#171d24;border-right:1px solid #3b403b;font-weight:400}
thead th.label{z-index:4;padding:16px 18px;color:var(--gold)}
thead th.label small{max-width:220px}
.group th,.group td{height:44px;background:#1c2729;border-top:1px solid #38433e;border-bottom:1px solid #38433e}
.group th.label{padding:10px 16px;color:#c8ddcf;font-weight:700}
.title{display:flex;align-items:center;gap:9px}
.title img{width:22px;height:22px;object-fit:contain}
.skills{display:flex;gap:5px;margin-top:5px}
.skills img{width:26px;height:26px;border-radius:5px;border:1px solid #3b403b}
.title .count{margin-left:auto;color:#799788;font-weight:400;font-size:12px}
.row th.label{padding:8px 15px;border-bottom:1px solid #ffffff08}
.row:nth-child(odd) th.label{background:#1a212a}
.name{display:flex;align-items:center;gap:10px;color:#c6cfda}
.name img{width:24px;height:24px;object-fit:contain;flex-shrink:0;filter:drop-shadow(0 1px 2px #0009)}
.name small{display:block;color:#82909e;font-size:12px;line-height:1.35;margin-top:2px;white-space:normal}
td{text-align:center;padding:0 6px;height:52px;border-bottom:1px solid #0c1014;
border-right:1px solid #0c1014;font-size:15px}
td.good{color:var(--good);background:var(--good-bg)}
td.fair{color:var(--fair);background:var(--fair-bg)}
td.poor{color:var(--poor);background:var(--poor-bg)}
td.ref,th.ref,td.trick,th.trick{border-left:2px solid #3b403b}
.total th.label{background:#302d20;color:var(--gold);border-bottom:1px solid #6d5d35}
.total .name{color:var(--gold);font-weight:700}
.total td{font-weight:700;font-size:17px;border-bottom:1px solid #6d5d35}
.foot{color:#8997a7;margin:0;padding:13px 18px;border-top:1px solid var(--line);font-size:12px}
.notes{margin:28px 0}
.notes ul{margin:0;padding-left:20px;max-width:900px;color:#d7dee7}
.notes li{margin:7px 0}
details{margin:24px 0;color:var(--muted);border-bottom:1px solid var(--line);padding-bottom:20px}
summary{cursor:pointer;color:var(--text);padding:6px 0}
summary span{color:#81909f;margin-left:12px;font-size:12px}
.defs{border-collapse:collapse;width:100%;min-width:0;margin-top:12px}
.defs td,.defs th{text-align:left;height:auto;padding:9px 12px;border:0;border-bottom:1px solid #ffffff0d;
font-size:13px;vertical-align:top;background:transparent;color:var(--muted)}
.defs th{color:#c6cfda;font-weight:700;white-space:nowrap}
.defs td:first-of-type{color:#d7dee7}
footer{padding:6px 0 30px;color:#758290;font-size:12px}
a:focus-visible,summary:focus-visible{outline:2px solid var(--gold);outline-offset:4px}
@media(max-width:800px){.site-header{flex-direction:column;gap:12px}.snapshot .window{margin-left:0;align-items:flex-start;width:100%}
th.label{width:200px;min-width:200px}.name small{display:none}.intro{flex-direction:column;align-items:flex-start}}
</style>
"""

proc band(score: float): string =
  ## Returns the color band for one score.
  if score >= 75:
    "good"
  elif score >= 40:
    "fair"
  else:
    "poor"

proc escapeHtml(text: string): string =
  ## Escapes text for HTML element content and attributes.
  text.multiReplace(
    ("&", "&amp;"), ("<", "&lt;"), (">", "&gt;"), ("\"", "&quot;")
  )

proc stageIcon(stage: Stage): string =
  ## Returns the site asset used as one stage's row icon.
  case stage
  of CreepClear: "icons/minion.png"
  of LastHits: "icons/gold.png"
  of CreepPull: "abilities/lodestone_surge.png"
  of JungleCamp: "abilities/nature_talisman.png"
  of TowerSiege: "icons/tower.png"
  of TowerDiscipline: "items/steel_buckler.png"
  of GodPush: "icons/fort.png"
  of LaneDefense: "items/knight_armor.png"
  of Duel: "icons/attack.png"
  of DummyBurst: "icons/damage.png"
  of Execute: "icons/kills.png"
  of PotionSurvival: "items/vitality_elixir.png"
  of GankEscape: "items/ranger_boots.png"
  of SpellDodge: "abilities/meteor_strike.png"
  of RecallHome: "items/waystone_scroll.png"
  of FogChase: "abilities/dragon_sight.png"
  of GroupTracking: "abilities/shadow_cloak.png"
  of Shopping: "items/sunsteel_longsword.png"
  of AbilityPoints: "icons/experience.png"

proc embed(art, path: string): string =
  ## Hot links one image from the polyworld_art repository.
  art & path

proc columnClass(policy: Policy, index: int): string =
  ## Marks the newest, reference and one-trick columns.
  if policy.tricksDir.len > 0:
    "trick"
  elif policy.name.endsWith(".bas"):
    "ref"
  elif index == 0:
    "newest"
  else:
    ""

proc htmlReport(
  policies: seq[Policy],
  stages: seq[Stage],
  scores: seq[seq[float]],
  totals: seq[float],
  classes: seq[HeroClass],
  seeds: int,
  notes: seq[string],
  art, build: string,
  heroScores: seq[seq[float]],
  heroNotes: seq[seq[string]]
): string =
  ## Builds the standalone HTML report in the Polyworld Buff site style.
  var classNames: seq[string]
  for class in classes:
    classNames.add $class
  let
    style = ReportStyle.replace("ART", art)
    site = "https://metta-ai.github.io/polyworld-buff/GOTA/"
    logo = embed(art, "themes/gota/gota_logo.png")
    champion = embed(art, "icons/champion.png")
  proc cell(policy: Policy, index: int, score: float): string =
    let extra = policy.columnClass(index)
    &"<td class=\"{band(score)} {extra}\">{int(round(score))}</td>"
  result.add "<!doctype html>\n<html lang=\"en\">\n<head>\n" &
    "<meta charset=\"utf-8\">\n" &
    "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">\n" &
    "<title>Diagnostics · Gods of the Arena</title>\n" & style &
    "</head>\n<body>\n"
  result.add "<header class=\"site-header wrap\">" &
    &"<a href=\"{site}\"><img src=\"{logo}\" " &
    "alt=\"Gods of the Arena\"></a>" &
    "<nav class=\"site-nav\">" &
    &"<a href=\"{site}index.html\">Game guide</a>" &
    &"<a href=\"{site}heros/\">Hero statistics</a>" &
    &"<a href=\"{site}players/\">Players</a>" &
    "<a aria-current=\"page\">Diagnostics</a></nav></header>\n"
  result.add "<main class=\"wrap\">\n<section class=\"intro\"><div>" &
    "<p class=\"eyebrow\">Gods of the Arena <span>/</span> " &
    "Mechanics diagnostics</p><h1>Diagnostics</h1>" &
    "<p class=\"lede\">One situation, one skill. Every stage is built " &
    "inside the real simulation and scored 0 to 100.</p></div>"
  if build.len > 0:
    result.add &"<div class=\"badge\"><i></i>{escapeHtml(build)}</div>"
  result.add "</section>\n"
  result.add "<section class=\"snapshot\">" &
    &"<div><strong>{stages.len}</strong><span>stages</span></div>" &
    &"<div><strong>{policies.len}</strong><span>policies</span></div>" &
    &"<div><strong>{classes.len * seeds}</strong><span>runs per cell</span>" &
    "</div><div class=\"window\">" &
    &"<strong>{classNames.join(\", \")}</strong>" &
    &"<span>{seeds} seeds per class, newest policy first</span></div>" &
    "</section>\n"
  result.add "<div class=\"workspace\"><div class=\"toolbar\">" &
    "<span class=\"chip\"><i class=\"good\"></i>75 and up</span>" &
    "<span class=\"chip\"><i class=\"fair\"></i>40 to 74</span>" &
    "<span class=\"chip\"><i class=\"poor\"></i>under 40</span>" &
    "<span class=\"hint\">one-trick = a separate tiny script per row " &
    "that only knows that stage</span>" &
    "</div>\n<div class=\"scroll\"><table>\n<thead><tr>" &
    "<th class=\"label\">Stage<small>Hover a row name for its setup" &
    "</small></th>"
  for i, policy in policies:
    let extra = policy.columnClass(i)
    result.add &"<th class=\"{extra}\">{escapeHtml(policy.name)}</th>"
  result.add "</tr></thead>\n<tbody>\n"
  result.add "<tr class=\"total\"><th class=\"label\"><div class=\"name\">" &
    &"<img src=\"{champion}\" alt=\"\">" &
    "<div>Total<small>Mean of every stage</small></div></div></th>"
  for i, total in totals:
    result.add cell(policies[i], i, total)
  result.add "</tr>\n"
  var rowOf: array[Stage, int]
  for row, stage in stages:
    rowOf[stage] = row + 1
  for (title, icon, members) in StageGroups:
    var shown: seq[Stage]
    for stage in members:
      if rowOf[stage] > 0:
        shown.add stage
    if shown.len == 0:
      continue
    result.add "<tr class=\"group\"><th class=\"label\"><div class=\"title\">" &
      &"<img src=\"{embed(art, icon)}\" alt=\"\">{title}" &
      &"<span class=\"count\">{shown.len}</span></div></th>" &
      &"<td colspan=\"{policies.len}\"></td></tr>\n"
    for stage in shown:
      let setup = stageSetup(stage)
      result.add &"<tr class=\"row\"><th class=\"label\" " &
        &"title=\"{escapeHtml(setup.setup)}\"><div class=\"name\">" &
        &"<img src=\"{embed(art, stageIcon(stage))}\" alt=\"\">" &
        &"<div>{escapeHtml(stageName(stage))}" &
        &"<small>{escapeHtml(setup.score)}</small></div></div></th>"
      for i, score in scores[rowOf[stage] - 1]:
        result.add cell(policies[i], i, score)
      result.add "</tr>\n"
  result.add "</tbody></table></div>\n<p class=\"foot\">Each cell " &
    &"averages {classes.len * seeds} runs ({classNames.join(\", \")} by " &
    &"{seeds} seeds). Every other hero is dead unless the stage brings " &
    "one in; waves and camps are off unless the stage spawns them.</p>" &
    "</div>\n"
  if notes.len > 0:
    result.add "<section class=\"notes\"><h2>What the table says</h2><ul>\n"
    for note in notes:
      result.add &"<li>{escapeHtml(note)}</li>\n"
    result.add "</ul></section>\n"
  if heroScores.len > 0:
    result.add "<section class=\"notes\"><h2>Heroes: abilities used " &
      "correctly</h2><p class=\"lede\">Every class at level 7, 60% health " &
      "and full mana, 4 tiles from an unkillable Vanguard that holds its " &
      "tile, for 20 s. A damage " &
      "cast counts when it hits an enemy, a heal when it restores missing " &
      "health, a mana ability when it restores missing mana. Each ability " &
      "scores correct casts per cast (0 if never cast); the row is the " &
      "mean of the four. Hover a cell for Q/W/E/R counts.</p></section>\n"
    result.add "<div class=\"workspace\"><div class=\"scroll\"><table>\n" &
      "<thead><tr><th class=\"label\">Hero<small>Q W E R abilities</small>" &
      "</th>"
    for i, policy in policies:
      let extra = policy.columnClass(i)
      result.add &"<th class=\"{extra}\">{escapeHtml(policy.name)}</th>"
    result.add "</tr></thead>\n<tbody>\n"
    var heroTotals = newSeq[float](policies.len)
    for row in heroScores:
      for i, score in row:
        heroTotals[i] += score / heroScores.len.float
    result.add "<tr class=\"total\"><th class=\"label\"><div class=\"name\">" &
      &"<img src=\"{champion}\" alt=\"\"><div>Total<small>Mean of every " &
      "hero</small></div></div></th>"
    for i, total in heroTotals:
      result.add cell(policies[i], i, total)
    result.add "</tr>\n"
    for class in HeroClass:
      var icons = ""
      for slot in HeroAbilitySlot:
        let
          spec = heroAbility(class, slot).abilitySpec
          image = embed(art, "abilities" / spec.icon & ".png")
        icons.add &"<img src=\"{image}\" alt=\"{SlotKeys[slot]}\" " &
          &"title=\"{SlotKeys[slot]}: {escapeHtml(spec.name)}\">"
      result.add "<tr class=\"row\"><th class=\"label\"><div class=\"name\">" &
        &"<div>{escapeHtml(class.heroSpec.name)}<span class=\"skills\">" &
        &"{icons}</span></div></div></th>"
      for i, score in heroScores[class.ord]:
        let extra = policies[i].columnClass(i)
        result.add &"<td class=\"{band(score)} {extra}\" " &
          &"title=\"{escapeHtml(heroNotes[class.ord][i])}\">" &
          &"{int(round(score))}</td>"
      result.add "</tr>\n"
    result.add "</tbody></table></div></div>\n"
  result.add "<details open><summary>Stage definitions <span>Setup and " &
    "scoring</span></summary><table class=\"defs\"><tbody>\n"
  for stage in stages:
    let setup = stageSetup(stage)
    result.add &"<tr><th>{escapeHtml(stageName(stage))}</th>" &
      &"<td>{escapeHtml(setup.setup)}</td><td>{escapeHtml(setup.score)}" &
      "</td></tr>\n"
  result.add "</tbody></table></details>\n</main>\n" &
    "<footer class=\"wrap\">Generated by tools/gota_diag.nim in " &
    "andre_von_auto</footer>\n</body>\n</html>\n"

proc main() =
  ## Runs every requested stage for every policy and prints the table.
  var
    policies: seq[Policy]
    stages: seq[Stage]
    classes = @AllClasses
    seeds = 2
    rows = false
    heroes = false
    htmlPath = ""
    art = "https://media.githubusercontent.com/media/Metta-AI/polyworld_art/main/"
    build = ""
    notes: seq[string]
    i = 1
  while i <= paramCount():
    let argument = paramStr(i)
    case argument
    of "--geometry":
      geometry()
      return
    of "--stages":
      inc i
      for name in paramStr(i).split(','):
        stages.add parseEnum[Stage](name)
    of "--classes":
      inc i
      classes.setLen(0)
      for name in paramStr(i).split(','):
        classes.add parseClass(name)
    of "--seeds":
      inc i
      seeds = parseInt(paramStr(i))
    of "--heroes":
      heroes = true
    of "--rows":
      rows = true
    of "--trace":
      inc i
      traceEvery = parseInt(paramStr(i))
    of "--pull-back":
      inc i
      pullBack = parseFloat(paramStr(i))
    of "--tricks":
      inc i
      policies.add Policy(name: "one-trick", tricksDir: paramStr(i))
    of "--print":
      printOurs = true
    of "--units":
      traceUnits = true
    of "--html":
      inc i
      htmlPath = paramStr(i)
    of "--art":
      inc i
      art = paramStr(i)
    of "--build":
      inc i
      build = paramStr(i)
    of "--notes":
      inc i
      for line in readFile(paramStr(i)).splitLines():
        if line.strip().len > 0:
          notes.add line.strip().strip(chars = {'-', ' '})
    else:
      let parts = argument.split('=', 1)
      if parts.len == 2:
        policies.add Policy(name: parts[0], source: readFile(parts[1]))
      else:
        policies.add Policy(
          name: argument.splitFile.name,
          source: readFile(argument)
        )
    inc i
  if stages.len == 0:
    for stage in Stage:
      stages.add stage
  if policies.len == 0:
    quit("usage: gota_diag [--stages A,B] [--classes A,B] [--seeds N] " &
      "[--html PATH] [--notes PATH] name=policy.bas ...")
  var
    scores = newSeq[seq[float]](stages.len)
    totals = newSeq[float](policies.len)
  for row, stage in stages:
    for policy in policies:
      var
        total = 0.0
        count = 0
      let source =
        if policy.tricksDir.len > 0:
          readFile(policy.tricksDir / "_helpers.bas") & "\n" &
            readFile(policy.tricksDir / ($stage & ".bas"))
        else:
          policy.source
      for class in classes:
        for seed in 1 .. seeds:
          let score = runStage(stage, source, class, seed)
          if rows:
            stderr.writeLine &"row {stage} {policy.name} {class} {seed} " &
              &"{score:.1f}"
          total += score
          inc count
      scores[row].add total / count.float
  for p in 0 ..< policies.len:
    for row in 0 ..< stages.len:
      totals[p] += scores[row][p] / stages.len.float
  var
    header = "| stage |"
    rule = "|---|"
    totalLine = "| **total** |"
  for p, policy in policies:
    header.add &" {policy.name} |"
    rule.add "---:|"
    totalLine.add &" **{int(round(totals[p]))}** |"
  echo header
  echo rule
  echo totalLine
  for row, stage in stages:
    var line = &"| {stageName(stage)} |"
    for score in scores[row]:
      line.add &" {int(round(score))} |"
    echo line
  var
    heroScores: seq[seq[float]]
    heroNotes: seq[seq[string]]
  if heroes:
    echo ""
    var header = "| hero |"
    var rule = "|---|"
    for policy in policies:
      header.add &" {policy.name} |"
      rule.add "---:|"
    echo header
    echo rule
    for class in HeroClass:
      var
        line = &"| {class.heroSpec.name} |"
        scoreRow: seq[float]
        noteRow: seq[string]
      for policy in policies:
        let source =
          if policy.tricksDir.len > 0:
            readFile(policy.tricksDir / "_helpers.bas") & "\n" &
              readFile(policy.tricksDir / "Abilities.bas")
          else:
            policy.source
        var
          total = 0.0
          sum: AbilityUse
        for seed in 1 .. seeds:
          let use = abilityRun(source, class, seed)
          total += use.abilityScore
          for slot in HeroAbilitySlot:
            sum.casts[slot] += use.casts[slot]
            sum.good[slot] += use.good[slot]
        var note: seq[string]
        for slot in HeroAbilitySlot:
          note.add &"{SlotKeys[slot]} {sum.good[slot]}/{sum.casts[slot]}"
        scoreRow.add total / seeds.float
        noteRow.add note.join(" · ") & " correct/cast"
        if rows:
          stderr.writeLine &"hero {class} {policy.name} {note.join(\" \")}"
        line.add &" {int(round(total / seeds.float))} |"
      heroScores.add scoreRow
      heroNotes.add noteRow
      echo line
  if htmlPath.len > 0:
    writeFile(htmlPath, htmlReport(
      policies, stages, scores, totals, classes, seeds, notes, art, build,
      heroScores, heroNotes
    ))

main()
