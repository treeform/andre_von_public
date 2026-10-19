## Pudge Wars replay statistics: re-simulates hosted league tapes with
## the vendored engine and emits per-seat behaviour stats as JSON.
##
## A `.replay` (or `.replay.gz`) file is an ACTION TAPE: the recorded
## walk/hook/ping commands plus one state hash per tick. Nothing about
## positions, HP, or kills is stored, so this tool rebuilds every tick
## with `sim.tickWorld` in history-playback mode and derives the stats
## from state transitions (death causes, hook latches, river time,
## blind throws, ...). The recorded hashes are checked on the way; a
## nonzero `hashMismatches` means the vendored physics drifted from the
## image that recorded the tape and the numbers are approximate.
##
## Run from the repo root (nim.cfg beside this file wires the engine):
##   nim r --hints:off games/pudge-wars/tools/replay_stats.nim \
##     --eps /path/eps.json --out /path/stats.json --table \
##     /path/replays/*.replay.gz
##
## `--eps` joins the coworld episode metadata (episode id = replay file
## stem; participants[].position/policy_name; seats 0-2 West, 3-5 East)
## so each seat carries its policy label and league score. `--table`
## prints a markdown comparison of the policy groups (myasnik /
## blind-hook / camper / idle) averaged per seat-game.

import
  std/[algorithm, json, math, os, strformat, strutils, tables],
  zippy,
  polyworld/[pathing, tapes],
  content, maps, sim, replays, fog

const
  TargetLateralTiles = 4.0
    ## A throw counts as aimed at an enemy when a visible living enemy
    ## sits within this many tiles of the aim ray. Wider than the latch
    ## disk so velocity leads still count as targeted.
  LowHpPercent = 40
  DeepTiles = 6.0
    ## Bank strip width: inland of this counts as a deep post.
  RiverWidthTiles = float(RiverEastX - RiverWestX + 1)
  WestWaterline = float(RiverWestX)
    ## West bank land ends where tile column `RiverWestX` starts.
  EastWaterline = float(RiverEastX + 1)
    ## East bank land starts where tile column `RiverEastX` ends.

type
  DeathCause = enum
    Melee = "melee"
    Drown = "drown"
    Headshot = "headshot"
    HookHit = "hook"
    RotAura = "rot"
    Unknown = "other"

  SeatStats = object
    seat: int
    pudgeId: int32
    team: string
    policy: string
    group: string
    score: float
    kills, deaths: int
    deathsByCause: array[DeathCause, int]
    killsByCause: array[DeathCause, int]
    deathsInRiver: int
    riverDumpsTaken: int
      ## Times this butcher was dumped into the river by an enemy reel.
    hooksThrown: int
    hooksLanded: int
      ## Any latch (enemy, ally, or headshot execution).
    enemyHooksLanded: int
    allyHooksLanded: int
    allyRescues: int
      ## Ally latches where the ally was enemy-hooked or swimming.
    headshots: int
    blindHooks: int
    blindHooksLanded: int
    targetedHooksLanded: int
    blindEnemyLatches, blindAllyLatches: int
    targetedEnemyLatches, targetedAllyLatches: int
    headshotDeathsAllyHeld, headshotDeathsEnemyHeld: int
      ## Who held the chain on us when the killing second hook hit.
    headshotKillsAllyHeld, headshotKillsEnemyHeld: int
      ## Who held the victim (its own ally rescuing, or our team).
    hookedByEnemy: int
    hookedByAlly: int
    ticksHeld: int
      ## Ticks alive on somebody's chain (reel exposure).
    ticksDeep, ticksEdge, ticksEnemyBank: int
      ## Alive ticks more than `DeepTiles` inland, on the bank strip
      ## between the waterline and `DeepTiles`, and past the far
      ## waterline.
    ticksInRiverFree: int
      ## River ticks while not on a chain: voluntary swimming.
    ticksEnemyBankFree: int
      ## Enemy-bank ticks while not on a chain: voluntary crossing.
    deathsOnEnemyBank: int
    unattributedLatches: int
      ## Engine latches with no victim grab flag to attribute (a second
      ## hook re-latched the same victim in the same tick).
    nearestEnemyWhenHookedSum: float
    hookerDistanceWhenHookedSum: float
    ticksAlive, ticksInRiver, ticksBelowLowHp: int
    waterDistanceSum: float
    minWaterDistance: float
    throwWaterDistanceSum: float
    throwAimDistanceSum: float
    targetedThrowDistanceSum: float
    blindAimDistanceSum: float
    blindAimWaterDistanceSum: float
      ## Where blind throws are aimed, as the aim point's signed
      ## distance from the thrower's own waterline (negative = across).
    damageDealt, damageTaken: int

  ThrowTrack = object
    ## The most recent throw per butcher; a butcher has one live hook.
    blind: bool
    pending: bool

  Participant = object
    policy: string
    group: string
    score: float

  EpisodeMeta = object
    participants: array[PudgeCount, Participant]
    found: bool

  ReplayReport = object
    file: string
    episode: string
    mapSeed: int32
    killGoal: int32
    ticks: int32
    maximumTicks: uint32
    actions: int
    gameOver: bool
    winner: string
    teamKills: array[2, int32]
    hashMismatches: int
    firstMismatchTick: int
    seats: seq[SeatStats]

## Geometry

proc tileX(point: WorldPoint): float =
  float(point.x) / float(WorldScale) + float(GridTiles div 2)

proc tileZ(point: WorldPoint): float =
  float(point.z) / float(WorldScale) + float(GridTiles div 2)

proc tilesBetween(a, b: WorldPoint): float =
  hypot(tileX(a) - tileX(b), tileZ(a) - tileZ(b))

proc waterDistance(team: Team, point: WorldPoint): float =
  ## Signed tiles between a butcher and the near waterline: positive
  ## inland on the home bank, negative once in (or across) the water.
  if team == WestTeam:
    WestWaterline - tileX(point)
  else:
    tileX(point) - EastWaterline

proc teamName(team: Team): string =
  if team == WestTeam: "west" else: "east"

proc nearestLivingEnemy(world: World, index: int): int =
  result = -1
  var best = high(int64)
  let me = world.pudges[index]
  for i, other in world.pudges:
    if other.team == me.team or other.state != Alive:
      continue
    let d = distanceSquared(me.position, other.position)
    if d < best:
      best = d
      result = i

proc visibleTargetDistance(
    world: World, index: int, aim: WorldPoint
): float =
  ## Distance to the visible living enemy nearest the aim ray, or -1
  ## when nothing the thrower's team can see sits along it (a blind
  ## throw). Visibility is the host's fog rule (`fogCanSeeTeam`).
  let
    me = world.pudges[index]
    origin = me.position
    dx = tileX(aim) - tileX(origin)
    dz = tileZ(aim) - tileZ(origin)
    span = hypot(dx, dz)
  if span <= 0.0:
    return -1.0
  let
    ux = dx / span
    uz = dz / span
    reach = float(hookRange(me.upgrades[UpgradeDistance])) /
      float(WorldScale)
  result = -1.0
  for other in world.pudges:
    if other.team == me.team or other.state != Alive:
      continue
    if not fogCanSeeTeam(world, me.team.ord, other.position):
      continue
    let
      ex = tileX(other.position) - tileX(origin)
      ez = tileZ(other.position) - tileZ(origin)
      along = ex * ux + ez * uz
      lateral = abs(ex * uz - ez * ux)
    if along < 0.0 or along > reach or lateral > TargetLateralTiles:
      continue
    let distance = hypot(ex, ez)
    if result < 0.0 or distance < result:
      result = distance

## Death causes

proc deathCause(
    world: World, index: int, previousHookedBy: int32,
    previousInRiver: bool
): (DeathCause, int) =
  ## Classifies one Alive -> Dying transition from this tick's
  ## transient flags. Returns the cause and the killer roster index.
  let victim = world.pudges[index]
  if previousHookedBy != 0:
    for i, other in world.pudges:
      if other.team != victim.team and other.justHeadshot:
        return (Headshot, i)
  let hurter = world.pudgeIndex(victim.lastHurtBy)
  if victim.justGrabbed:
    return (HookHit, hurter)
  for i, other in world.pudges:
    if other.damageLanded and other.attackTargetId == victim.id:
      return (Melee, i)
  if hurter >= 0:
    let source = world.pudges[hurter]
    if source.rotOn and
        distanceSquared(victim.position, source.position) <=
          int64(RotRadius) * int64(RotRadius):
      return (RotAura, hurter)
  if victim.lastHurtBy == victim.id:
    return (RotAura, hurter)
  if victim.inRiver or previousInRiver:
    return (Drown, hurter)
  (Unknown, hurter)

## Simulation

proc loadTape(path: string): ReplayData =
  var bytes = readFile(path)
  if bytes.len >= 2 and bytes[0] == '\x1f' and bytes[1] == '\x8b':
    bytes = uncompress(bytes, dfGzip)
  decodeReplay(bytes)

proc initSeatStats(world: World): seq[SeatStats] =
  for i, pudge in world.pudges:
    result.add SeatStats(
      seat: i,
      pudgeId: pudge.id,
      team: teamName(pudge.team),
      group: "unknown",
      minWaterDistance: 1.0e9
    )

proc analyzeReplay(path: string): ReplayReport =
  let data = loadTape(path)
  let setup = data.header.setup
  let gameMap = generateMap(setup.mapSeed)
  if gameMap.hash != setup.mapHash:
    raise newException(
      ReplayError, "map generation differs from the recording host"
    )
  let game = newGame(
    gameMap, int32(setup.maximumTicks), true, data
  )
  game.replayPlayer = initReplayPlayer(data)
  game.historyPlayback = true
  let world = game.world
  result.file = path
  result.episode = path.extractFilename.split(".")[0]
  result.mapSeed = setup.mapSeed
  result.killGoal = setup.killGoal
  result.maximumTicks = setup.maximumTicks
  result.actions = data.actions.len
  result.seats = initSeatStats(world)
  let count = world.pudges.len
  var
    previousHp = newSeq[int32](count)
    previousState = newSeq[PudgeState](count)
    previousHookedBy = newSeq[int32](count)
    previousInRiver = newSeq[bool](count)
    previousThrown = newSeq[int32](count)
    previousLanded = newSeq[int32](count)
    matchedLatches = newSeq[int](count)
    throws = newSeq[ThrowTrack](count)
  for i, pudge in world.pudges:
    previousHp[i] = pudge.hp
    previousState[i] = pudge.state
    previousHookedBy[i] = pudge.hookedBy
    previousInRiver[i] = pudge.inRiver
    previousThrown[i] = pudge.hooksThrown
    previousLanded[i] = pudge.hooksLanded
  while not world.gameOver and uint32(world.tick) < setup.maximumTicks:
    tickWorld(game, proc() = discard)
    # Throws first: the aim point and fog state belong to this tick.
    for i in 0 ..< count:
      let pudge = world.pudges[i]
      if pudge.hooksThrown > previousThrown[i]:
        let aim = worldAtFine(pudge.windupAimX, pudge.windupAimY)
        let target = visibleTargetDistance(world, i, aim)
        inc result.seats[i].hooksThrown
        result.seats[i].throwWaterDistanceSum +=
          waterDistance(pudge.team, pudge.position)
        result.seats[i].throwAimDistanceSum +=
          tilesBetween(pudge.position, aim)
        throws[i] = ThrowTrack(blind: target < 0.0, pending: true)
        if target < 0.0:
          inc result.seats[i].blindHooks
          result.seats[i].blindAimDistanceSum +=
            tilesBetween(pudge.position, aim)
          result.seats[i].blindAimWaterDistanceSum +=
            waterDistance(pudge.team, aim)
        else:
          result.seats[i].targetedThrowDistanceSum += target
    # Latches: the victim's transient grab flag names the hooker.
    for i in 0 ..< count:
      let victim = world.pudges[i]
      if not victim.justGrabbed:
        continue
      # A lethal latch clears `hookedBy` in the kill; the damage path
      # still names the hooker in `lastHurtBy`.
      let holder =
        if victim.hookedBy != 0: victim.hookedBy
        elif victim.state == Dying: victim.lastHurtBy
        else: 0'i32
      let owner = world.pudgeIndex(holder)
      if owner < 0:
        continue
      inc matchedLatches[owner]
      let allyLatch = world.pudges[owner].team == victim.team
      if throws[owner].pending:
        throws[owner].pending = false
        if throws[owner].blind:
          inc result.seats[owner].blindHooksLanded
          if allyLatch: inc result.seats[owner].blindAllyLatches
          else: inc result.seats[owner].blindEnemyLatches
        else:
          inc result.seats[owner].targetedHooksLanded
          if allyLatch: inc result.seats[owner].targetedAllyLatches
          else: inc result.seats[owner].targetedEnemyLatches
      if allyLatch:
        inc result.seats[owner].allyHooksLanded
        inc result.seats[i].hookedByAlly
        var enemyHeld = false
        if previousHookedBy[i] != 0:
          let holder = world.pudgeIndex(previousHookedBy[i])
          enemyHeld = holder >= 0 and
            world.pudges[holder].team != victim.team
        if enemyHeld or previousInRiver[i]:
          inc result.seats[owner].allyRescues
      else:
        inc result.seats[owner].enemyHooksLanded
        inc result.seats[i].hookedByEnemy
        let nearest = nearestLivingEnemy(world, i)
        if nearest >= 0:
          result.seats[i].nearestEnemyWhenHookedSum +=
            tilesBetween(victim.position, world.pudges[nearest].position)
        result.seats[i].hookerDistanceWhenHookedSum +=
          tilesBetween(victim.position, world.pudges[owner].position)
    # Headshot executions latch and kill in one step: no grab flag.
    for i in 0 ..< count:
      if world.pudges[i].justHeadshot:
        inc result.seats[i].headshots
        inc matchedLatches[i]
        inc result.seats[i].enemyHooksLanded
        if throws[i].pending:
          throws[i].pending = false
          if throws[i].blind:
            inc result.seats[i].blindHooksLanded
            inc result.seats[i].blindEnemyLatches
          else:
            inc result.seats[i].targetedHooksLanded
            inc result.seats[i].targetedEnemyLatches
    # Damage, deaths, and the per-tick occupancy counters.
    for i in 0 ..< count:
      let pudge = world.pudges[i]
      let landed = int(pudge.hooksLanded - previousLanded[i])
      result.seats[i].hooksLanded += landed
      if landed > matchedLatches[i]:
        result.seats[i].unattributedLatches += landed - matchedLatches[i]
      matchedLatches[i] = 0
      let wasAlive = previousState[i] == Alive
      if wasAlive:
        let delta = previousHp[i] - pudge.hp
        if delta > 0 and pudge.state == Alive or
            delta > 0 and pudge.state == Dying and not pudge.justHeadshot:
          result.seats[i].damageTaken += int(delta)
          let dealer = world.pudgeIndex(pudge.lastHurtBy)
          if dealer >= 0 and dealer != i:
            result.seats[dealer].damageDealt += int(delta)
        if pudge.state == Dying:
          let (cause, killer) =
            deathCause(world, i, previousHookedBy[i], previousInRiver[i])
          inc result.seats[i].deaths
          inc result.seats[i].deathsByCause[cause]
          if cause == Headshot:
            let holder = world.pudgeIndex(previousHookedBy[i])
            let allyHeld =
              holder >= 0 and world.pudges[holder].team == pudge.team
            if allyHeld:
              inc result.seats[i].headshotDeathsAllyHeld
              if killer >= 0:
                inc result.seats[killer].headshotKillsAllyHeld
            else:
              inc result.seats[i].headshotDeathsEnemyHeld
              if killer >= 0:
                inc result.seats[killer].headshotKillsEnemyHeld
          if pudge.inRiver or previousInRiver[i]:
            inc result.seats[i].deathsInRiver
          if waterDistance(pudge.team, pudge.position) < -RiverWidthTiles:
            inc result.seats[i].deathsOnEnemyBank
          if killer >= 0 and world.pudges[killer].team != pudge.team:
            inc result.seats[killer].kills
            inc result.seats[killer].killsByCause[cause]
      if pudge.state == Alive:
        inc result.seats[i].ticksAlive
        if pudge.inRiver:
          inc result.seats[i].ticksInRiver
          if pudge.hookedBy == 0:
            inc result.seats[i].ticksInRiverFree
        if pudge.hookedBy != 0:
          inc result.seats[i].ticksHeld
        if pudge.enteredRiver:
          inc result.seats[i].riverDumpsTaken
        if pudge.hp * 100 < pudge.maxHp * LowHpPercent:
          inc result.seats[i].ticksBelowLowHp
        let water = waterDistance(pudge.team, pudge.position)
        result.seats[i].waterDistanceSum += water
        if water > DeepTiles:
          inc result.seats[i].ticksDeep
        elif water >= 0.0:
          inc result.seats[i].ticksEdge
        elif water < -RiverWidthTiles:
          inc result.seats[i].ticksEnemyBank
          if pudge.hookedBy == 0:
            inc result.seats[i].ticksEnemyBankFree
        if water < result.seats[i].minWaterDistance:
          result.seats[i].minWaterDistance = water
      previousHp[i] = pudge.hp
      previousState[i] = pudge.state
      previousHookedBy[i] = pudge.hookedBy
      previousInRiver[i] = pudge.inRiver
      previousThrown[i] = pudge.hooksThrown
      previousLanded[i] = pudge.hooksLanded
  result.ticks = world.tick
  result.gameOver = world.gameOver
  result.winner =
    if world.gameOver: teamName(world.winner) else: ""
  result.teamKills = world.teamKills
  result.hashMismatches = int(game.hashCheck.mismatches)
  result.firstMismatchTick = int(game.hashCheck.firstTick)
  for i in 0 ..< count:
    # The engine's own counters are the ground truth for kills.
    result.seats[i].kills = int(world.pudges[i].kills)
    doAssert result.seats[i].hooksThrown == int(world.pudges[i].hooksThrown)
    doAssert result.seats[i].headshots == int(world.pudges[i].headshotCount)
    if result.seats[i].minWaterDistance > 1.0e8:
      result.seats[i].minWaterDistance = 0.0

## Episode metadata

proc policyGroup(policy: string): string =
  let lowered = policy.toLowerAscii
  if "myasnik" in lowered: "myasnik"
  elif "blind-hook" in lowered: "blind-hook"
  elif "camper" in lowered: "camper"
  elif "idle" in lowered: "idle"
  else: "other"

proc loadEpisodes(path: string): Table[string, EpisodeMeta] =
  for episode in parseJson(readFile(path)):
    var meta = EpisodeMeta(found: true)
    for participant in episode{"participants"}:
      let position = participant{"position"}.getInt
      if position < 0 or position >= PudgeCount:
        continue
      let policy = participant{"policy_name"}.getStr
      meta.participants[position] = Participant(
        policy: policy & ":v" & $participant{"version"}.getInt,
        group: policyGroup(policy)
      )
    for entry in episode{"participant_scores"}:
      let position = entry{"position"}.getInt
      if position >= 0 and position < PudgeCount:
        meta.participants[position].score = entry{"score"}.getFloat
    result[episode{"id"}.getStr] = meta

proc joinEpisode(report: var ReplayReport, meta: EpisodeMeta) =
  for seat in report.seats.mitems:
    if seat.seat < PudgeCount:
      let participant = meta.participants[seat.seat]
      seat.policy = participant.policy
      seat.group = participant.group
      seat.score = participant.score

## JSON output

proc ratio(numerator: float, denominator: float): float =
  if denominator <= 0.0: 0.0 else: numerator / denominator

proc rounded(value: float, digits = 3): float =
  round(value, digits)

proc causeNode(counts: array[DeathCause, int]): JsonNode =
  result = newJObject()
  for cause in DeathCause:
    result[$cause] = %counts[cause]

proc minutes(ticks: int): float =
  float(ticks) / float(TickRate) / 60.0

proc seatNode(seat: SeatStats, gameTicks: int): JsonNode =
  let gameMinutes = minutes(gameTicks)
  %*{
    "seat": seat.seat,
    "pudgeId": seat.pudgeId,
    "team": seat.team,
    "policy": seat.policy,
    "group": seat.group,
    "score": seat.score,
    "kills": seat.kills,
    "deaths": seat.deaths,
    "killsByCause": causeNode(seat.killsByCause),
    "deathsByCause": causeNode(seat.deathsByCause),
    "deathsInRiver": seat.deathsInRiver,
    "riverDumpsTaken": seat.riverDumpsTaken,
    "hooksThrown": seat.hooksThrown,
    "hooksPerMinute": rounded(ratio(float(seat.hooksThrown), gameMinutes)),
    "hooksLanded": seat.hooksLanded,
    "enemyHooksLanded": seat.enemyHooksLanded,
    "allyHooksLanded": seat.allyHooksLanded,
    "allyRescues": seat.allyRescues,
    "headshots": seat.headshots,
    "blindHooks": seat.blindHooks,
    "blindHooksLanded": seat.blindHooksLanded,
    "targetedHooksLanded": seat.targetedHooksLanded,
    "blindEnemyLatches": seat.blindEnemyLatches,
    "blindAllyLatches": seat.blindAllyLatches,
    "targetedEnemyLatches": seat.targetedEnemyLatches,
    "targetedAllyLatches": seat.targetedAllyLatches,
    "headshotDeathsAllyHeld": seat.headshotDeathsAllyHeld,
    "headshotDeathsEnemyHeld": seat.headshotDeathsEnemyHeld,
    "headshotKillsAllyHeld": seat.headshotKillsAllyHeld,
    "headshotKillsEnemyHeld": seat.headshotKillsEnemyHeld,
    "hookedByAlly": seat.hookedByAlly,
    "ticksHeld": seat.ticksHeld,
    "heldFraction":
      rounded(ratio(float(seat.ticksHeld), float(seat.ticksAlive))),
    "deepFraction":
      rounded(ratio(float(seat.ticksDeep), float(seat.ticksAlive))),
    "edgeFraction":
      rounded(ratio(float(seat.ticksEdge), float(seat.ticksAlive))),
    "enemyBankFraction":
      rounded(ratio(float(seat.ticksEnemyBank), float(seat.ticksAlive))),
    "riverFreeFraction":
      rounded(ratio(float(seat.ticksInRiverFree), float(seat.ticksAlive))),
    "enemyBankFreeFraction": rounded(
      ratio(float(seat.ticksEnemyBankFree), float(seat.ticksAlive))
    ),
    "deathsOnEnemyBank": seat.deathsOnEnemyBank,
    "unattributedLatches": seat.unattributedLatches,
    "blindFraction":
      rounded(ratio(float(seat.blindHooks), float(seat.hooksThrown))),
    "meanThrowAimDistance":
      rounded(ratio(seat.throwAimDistanceSum, float(seat.hooksThrown))),
    "meanTargetedThrowDistance": rounded(ratio(
      seat.targetedThrowDistanceSum,
      float(seat.hooksThrown - seat.blindHooks)
    )),
    "meanBlindAimDistance":
      rounded(ratio(seat.blindAimDistanceSum, float(seat.blindHooks))),
    "meanBlindAimWaterDistance":
      rounded(ratio(seat.blindAimWaterDistanceSum, float(seat.blindHooks))),
    "meanThrowWaterDistance":
      rounded(ratio(seat.throwWaterDistanceSum, float(seat.hooksThrown))),
    "hookedByEnemy": seat.hookedByEnemy,
    "meanNearestEnemyWhenHooked": rounded(ratio(
      seat.nearestEnemyWhenHookedSum, float(seat.hookedByEnemy)
    )),
    "meanHookerDistanceWhenHooked": rounded(ratio(
      seat.hookerDistanceWhenHookedSum, float(seat.hookedByEnemy)
    )),
    "ticksAlive": seat.ticksAlive,
    "ticksInRiver": seat.ticksInRiver,
    "riverFraction":
      rounded(ratio(float(seat.ticksInRiver), float(seat.ticksAlive))),
    "ticksBelow40": seat.ticksBelowLowHp,
    "below40Fraction":
      rounded(ratio(float(seat.ticksBelowLowHp), float(seat.ticksAlive))),
    "meanWaterDistance":
      rounded(ratio(seat.waterDistanceSum, float(seat.ticksAlive))),
    "minWaterDistance": rounded(seat.minWaterDistance),
    "damageDealt": seat.damageDealt,
    "damageTaken": seat.damageTaken
  }

proc teamNode(report: ReplayReport, team: string): JsonNode =
  var
    kills, deaths, thrown, landed, headshots, rescues, blind = 0
    river, alive, dumps = 0
  for seat in report.seats:
    if seat.team != team:
      continue
    kills += seat.kills
    deaths += seat.deaths
    thrown += seat.hooksThrown
    landed += seat.enemyHooksLanded
    headshots += seat.headshots
    rescues += seat.allyRescues
    blind += seat.blindHooks
    river += seat.ticksInRiver
    alive += seat.ticksAlive
    dumps += seat.riverDumpsTaken
  let index = if team == "west": 0 else: 1
  %*{
    "team": team,
    "teamKills": report.teamKills[index],
    "kills": kills,
    "deaths": deaths,
    "hooksThrown": thrown,
    "enemyHooksLanded": landed,
    "headshots": headshots,
    "allyRescues": rescues,
    "blindHooks": blind,
    "riverDumpsTaken": dumps,
    "riverFraction": rounded(ratio(float(river), float(alive)))
  }

proc reportNode(report: ReplayReport): JsonNode =
  var seats = newJArray()
  for seat in report.seats:
    seats.add seatNode(seat, int(report.ticks))
  %*{
    "file": report.file,
    "episode": report.episode,
    "mapSeed": report.mapSeed,
    "killGoal": report.killGoal,
    "ticks": report.ticks,
    "minutes": rounded(minutes(int(report.ticks)), 2),
    "maximumTicks": report.maximumTicks,
    "actions": report.actions,
    "gameOver": report.gameOver,
    "winner": report.winner,
    "teamKills": [report.teamKills[0], report.teamKills[1]],
    "hashMismatches": report.hashMismatches,
    "firstMismatchTick": report.firstMismatchTick,
    "teams": [teamNode(report, "west"), teamNode(report, "east")],
    "seats": seats
  }

## Group comparison table

type
  GroupAggregate = object
    seatGames: int
    scoreSum: float
    kills, deaths: int
    deathsByCause: array[DeathCause, int]
    killsByCause: array[DeathCause, int]
    deathsInRiver, riverDumpsTaken: int
    hooksThrown, enemyHooksLanded, allyHooksLanded, allyRescues: int
    headshots, blindHooks, blindHooksLanded, targetedHooksLanded: int
    blindEnemyLatches, blindAllyLatches: int
    targetedEnemyLatches, targetedAllyLatches: int
    headshotDeathsAllyHeld, headshotDeathsEnemyHeld: int
    headshotKillsAllyHeld, headshotKillsEnemyHeld: int
    hookedByEnemy, hookedByAlly: int
    ticksHeld, ticksDeep, ticksEdge, ticksEnemyBank, ticksInRiverFree: int
    ticksEnemyBankFree, deathsOnEnemyBank: int
    nearestEnemyWhenHookedSum, hookerDistanceWhenHookedSum: float
    ticksAlive, ticksInRiver, ticksBelowLowHp: int
    gameTicks: int
    waterDistanceSum, throwWaterDistanceSum, throwAimDistanceSum: float
    targetedThrowDistanceSum: float
    blindAimDistanceSum, blindAimWaterDistanceSum: float
    minWaterDistanceSum: float
    damageDealt, damageTaken: int

proc accumulate(aggregate: var GroupAggregate, seat: SeatStats,
    gameTicks: int) =
  inc aggregate.seatGames
  aggregate.scoreSum += seat.score
  aggregate.kills += seat.kills
  aggregate.deaths += seat.deaths
  for cause in DeathCause:
    aggregate.deathsByCause[cause] += seat.deathsByCause[cause]
    aggregate.killsByCause[cause] += seat.killsByCause[cause]
  aggregate.deathsInRiver += seat.deathsInRiver
  aggregate.riverDumpsTaken += seat.riverDumpsTaken
  aggregate.hooksThrown += seat.hooksThrown
  aggregate.enemyHooksLanded += seat.enemyHooksLanded
  aggregate.allyHooksLanded += seat.allyHooksLanded
  aggregate.allyRescues += seat.allyRescues
  aggregate.headshots += seat.headshots
  aggregate.blindHooks += seat.blindHooks
  aggregate.blindHooksLanded += seat.blindHooksLanded
  aggregate.targetedHooksLanded += seat.targetedHooksLanded
  aggregate.hookedByEnemy += seat.hookedByEnemy
  aggregate.hookedByAlly += seat.hookedByAlly
  aggregate.blindEnemyLatches += seat.blindEnemyLatches
  aggregate.blindAllyLatches += seat.blindAllyLatches
  aggregate.targetedEnemyLatches += seat.targetedEnemyLatches
  aggregate.targetedAllyLatches += seat.targetedAllyLatches
  aggregate.headshotDeathsAllyHeld += seat.headshotDeathsAllyHeld
  aggregate.headshotDeathsEnemyHeld += seat.headshotDeathsEnemyHeld
  aggregate.headshotKillsAllyHeld += seat.headshotKillsAllyHeld
  aggregate.headshotKillsEnemyHeld += seat.headshotKillsEnemyHeld
  aggregate.ticksHeld += seat.ticksHeld
  aggregate.ticksDeep += seat.ticksDeep
  aggregate.ticksEdge += seat.ticksEdge
  aggregate.ticksEnemyBank += seat.ticksEnemyBank
  aggregate.ticksInRiverFree += seat.ticksInRiverFree
  aggregate.ticksEnemyBankFree += seat.ticksEnemyBankFree
  aggregate.deathsOnEnemyBank += seat.deathsOnEnemyBank
  aggregate.nearestEnemyWhenHookedSum += seat.nearestEnemyWhenHookedSum
  aggregate.hookerDistanceWhenHookedSum += seat.hookerDistanceWhenHookedSum
  aggregate.ticksAlive += seat.ticksAlive
  aggregate.ticksInRiver += seat.ticksInRiver
  aggregate.ticksBelowLowHp += seat.ticksBelowLowHp
  aggregate.gameTicks += gameTicks
  aggregate.waterDistanceSum += seat.waterDistanceSum
  aggregate.throwWaterDistanceSum += seat.throwWaterDistanceSum
  aggregate.throwAimDistanceSum += seat.throwAimDistanceSum
  aggregate.targetedThrowDistanceSum += seat.targetedThrowDistanceSum
  aggregate.blindAimDistanceSum += seat.blindAimDistanceSum
  aggregate.blindAimWaterDistanceSum += seat.blindAimWaterDistanceSum
  aggregate.minWaterDistanceSum += seat.minWaterDistance
  aggregate.damageDealt += seat.damageDealt
  aggregate.damageTaken += seat.damageTaken

proc formatted(value: float, digits = 2): string =
  formatFloat(value, ffDecimal, digits)

proc percent(numerator, denominator: float): string =
  formatted(100.0 * ratio(numerator, denominator), 0) & "%"

proc groupRows(aggregate: GroupAggregate): seq[(string, string)] =
  let
    games = float(aggregate.seatGames)
    thrown = float(aggregate.hooksThrown)
    deaths = float(aggregate.deaths)
    kills = float(aggregate.kills)
    alive = float(aggregate.ticksAlive)
    gameMinutes = minutes(aggregate.gameTicks)
  result.add ("seat-games", $aggregate.seatGames)
  result.add ("mean league score", formatted(ratio(aggregate.scoreSum, games), 3))
  result.add ("kills / game", formatted(ratio(kills, games)))
  result.add ("deaths / game", formatted(ratio(deaths, games)))
  result.add ("kill - death / game", formatted(ratio(kills - deaths, games)))
  for cause in DeathCause:
    result.add (
      "deaths by " & $cause,
      formatted(ratio(float(aggregate.deathsByCause[cause]), games)) &
        " (" & percent(float(aggregate.deathsByCause[cause]), deaths) & ")"
    )
  for cause in DeathCause:
    result.add (
      "kills by " & $cause,
      formatted(ratio(float(aggregate.killsByCause[cause]), games)) &
        " (" & percent(float(aggregate.killsByCause[cause]), kills) & ")"
    )
  result.add ("deaths in river", percent(float(aggregate.deathsInRiver), deaths))
  result.add ("river dumps taken / game",
    formatted(ratio(float(aggregate.riverDumpsTaken), games)))
  result.add ("hooks thrown / game", formatted(ratio(thrown, games)))
  result.add ("hooks thrown / min", formatted(ratio(thrown, gameMinutes)))
  result.add ("enemy latch rate",
    percent(float(aggregate.enemyHooksLanded), thrown))
  result.add ("enemy latches / game",
    formatted(ratio(float(aggregate.enemyHooksLanded), games)))
  result.add ("headshots / game",
    formatted(ratio(float(aggregate.headshots), games)))
  result.add ("ally latches / game",
    formatted(ratio(float(aggregate.allyHooksLanded), games)))
  result.add ("ally rescues / game",
    formatted(ratio(float(aggregate.allyRescues), games)))
  result.add ("blind hooks / game",
    formatted(ratio(float(aggregate.blindHooks), games)))
  result.add ("blind hooks / min",
    formatted(ratio(float(aggregate.blindHooks), gameMinutes)))
  result.add ("blind fraction", percent(float(aggregate.blindHooks), thrown))
  let
    blind = float(aggregate.blindHooks)
    targeted = float(aggregate.hooksThrown - aggregate.blindHooks)
  result.add ("blind latch rate",
    percent(float(aggregate.blindHooksLanded), blind))
  result.add ("blind -> enemy latch rate",
    percent(float(aggregate.blindEnemyLatches), blind))
  result.add ("blind -> ally latch rate",
    percent(float(aggregate.blindAllyLatches), blind))
  result.add ("targeted latch rate",
    percent(float(aggregate.targetedHooksLanded), targeted))
  result.add ("targeted -> enemy latch rate",
    percent(float(aggregate.targetedEnemyLatches), targeted))
  result.add ("targeted -> ally latch rate",
    percent(float(aggregate.targetedAllyLatches), targeted))
  result.add ("headshot deaths while ally-held / game",
    formatted(ratio(float(aggregate.headshotDeathsAllyHeld), games)))
  result.add ("headshot deaths while enemy-held / game",
    formatted(ratio(float(aggregate.headshotDeathsEnemyHeld), games)))
  result.add ("headshot kills on ally-held victims / game",
    formatted(ratio(float(aggregate.headshotKillsAllyHeld), games)))
  result.add ("headshot kills on our-held victims / game",
    formatted(ratio(float(aggregate.headshotKillsEnemyHeld), games)))
  result.add ("hooked by ally / game",
    formatted(ratio(float(aggregate.hookedByAlly), games)))
  result.add ("held fraction (alive ticks)",
    percent(float(aggregate.ticksHeld), alive))
  result.add ("mean aim distance (tiles)",
    formatted(ratio(aggregate.throwAimDistanceSum, thrown), 1))
  result.add ("mean targeted enemy distance (tiles)", formatted(ratio(
    aggregate.targetedThrowDistanceSum,
    float(aggregate.hooksThrown - aggregate.blindHooks)
  ), 1))
  result.add ("mean blind aim distance (tiles)",
    formatted(ratio(aggregate.blindAimDistanceSum, blind), 1))
  result.add ("mean blind aim point vs own waterline (tiles)",
    formatted(ratio(aggregate.blindAimWaterDistanceSum, blind), 1))
  result.add ("mean water distance at throw (tiles)",
    formatted(ratio(aggregate.throwWaterDistanceSum, thrown), 1))
  result.add ("hooked by enemy / game",
    formatted(ratio(float(aggregate.hookedByEnemy), games)))
  result.add ("mean nearest enemy when hooked (tiles)", formatted(ratio(
    aggregate.nearestEnemyWhenHookedSum, float(aggregate.hookedByEnemy)
  ), 1))
  result.add ("mean hooker distance when hooked (tiles)", formatted(ratio(
    aggregate.hookerDistanceWhenHookedSum, float(aggregate.hookedByEnemy)
  ), 1))
  result.add ("alive fraction",
    percent(alive, float(aggregate.gameTicks)))
  result.add ("river fraction (alive ticks)",
    percent(float(aggregate.ticksInRiver), alive))
  result.add ("river fraction while free",
    percent(float(aggregate.ticksInRiverFree), alive))
  result.add ("deep post fraction (> 6 tiles inland)",
    percent(float(aggregate.ticksDeep), alive))
  result.add ("bank edge fraction (0-6 tiles inland)",
    percent(float(aggregate.ticksEdge), alive))
  result.add ("enemy bank fraction",
    percent(float(aggregate.ticksEnemyBank), alive))
  result.add ("enemy bank fraction while free",
    percent(float(aggregate.ticksEnemyBankFree), alive))
  result.add ("deaths on enemy bank",
    percent(float(aggregate.deathsOnEnemyBank), deaths))
  result.add ("below 40% HP fraction",
    percent(float(aggregate.ticksBelowLowHp), alive))
  result.add ("mean water distance (tiles)",
    formatted(ratio(aggregate.waterDistanceSum, alive), 1))
  result.add ("mean per-game min water distance (tiles)",
    formatted(ratio(aggregate.minWaterDistanceSum, games), 1))
  result.add ("damage dealt / game",
    formatted(ratio(float(aggregate.damageDealt), games), 0))
  result.add ("damage taken / game",
    formatted(ratio(float(aggregate.damageTaken), games), 0))

proc groupTable(reports: seq[ReplayReport]): string =
  var groups: OrderedTable[string, GroupAggregate]
  for name in ["myasnik", "blind-hook", "camper", "idle"]:
    groups[name] = GroupAggregate()
  for report in reports:
    for seat in report.seats:
      if not groups.hasKey(seat.group):
        groups[seat.group] = GroupAggregate()
      groups[seat.group].accumulate(seat, int(report.ticks))
  var
    names: seq[string]
    columns: seq[seq[(string, string)]]
  for name, aggregate in groups:
    if aggregate.seatGames == 0:
      continue
    names.add name
    columns.add groupRows(aggregate)
  if columns.len == 0:
    return "no seats matched any policy group\n"
  result.add "| stat | " & names.join(" | ") & " |\n"
  result.add "|---|" & repeat("---:|", names.len) & "\n"
  for row in 0 ..< columns[0].len:
    var line = "| " & columns[0][row][0] & " |"
    for column in columns:
      line.add " " & column[row][1] & " |"
    result.add line & "\n"

proc perGameTable(reports: seq[ReplayReport]): string =
  ## One line per replay: which seat was ours, both scores, the tally.
  result.add "| episode | ticks | west kills | east kills | winner | " &
    "hash mismatches | myasnik seat | myasnik score | myasnik K/D |\n"
  result.add "|---|---:|---:|---:|---|---:|---:|---:|---|\n"
  for report in reports:
    var seat = "-"
    var score = "-"
    var record = "-"
    for stats in report.seats:
      if stats.group == "myasnik":
        seat = $stats.seat
        score = formatted(stats.score, 2)
        record = $stats.kills & "/" & $stats.deaths
    result.add &"| {report.episode} | {report.ticks} | " &
      &"{report.teamKills[0]} | {report.teamKills[1]} | " &
      &"{report.winner} | {report.hashMismatches} | {seat} | {score} | " &
      &"{record} |\n"

## Entry point

proc usage() =
  echo "replay_stats [--eps EPISODES.json] [--out STATS.json] [--table] " &
    "REPLAY..."
  quit(1)

proc main() =
  var
    episodesPath = ""
    outputPath = ""
    printTable = false
    paths: seq[string]
  var i = 1
  while i <= paramCount():
    let argument = paramStr(i)
    case argument
    of "--eps":
      inc i
      episodesPath = paramStr(i)
    of "--out":
      inc i
      outputPath = paramStr(i)
    of "--table":
      printTable = true
    of "--help", "-h":
      usage()
    else:
      paths.add argument
    inc i
  if paths.len == 0:
    usage()
  paths.sort()
  var episodes: Table[string, EpisodeMeta]
  if episodesPath.len > 0:
    episodes = loadEpisodes(episodesPath)
  var reports: seq[ReplayReport]
  for path in paths:
    var report = analyzeReplay(path)
    if episodes.hasKey(report.episode):
      report.joinEpisode(episodes[report.episode])
    stderr.writeLine(
      &"{report.episode}: {report.ticks} ticks, {report.actions} actions, " &
      &"kills {report.teamKills[0]}-{report.teamKills[1]}, " &
      &"winner={report.winner}, hash mismatches={report.hashMismatches}"
    )
    reports.add report
  var output = newJArray()
  for report in reports:
    output.add reportNode(report)
  if outputPath.len > 0:
    writeFile(outputPath, output.pretty)
    stderr.writeLine("wrote " & outputPath)
  if printTable:
    echo perGameTable(reports)
    echo groupTable(reports)
  elif outputPath.len == 0:
    echo output.pretty

main()
