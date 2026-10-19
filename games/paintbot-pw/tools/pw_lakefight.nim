## Paintbot PW lake fight: the window from the first tick one of our cogs is within 1500 units of
## a lake heart until tick 2400 (or the end), per side: waders and wade time, deaths by victim
## place (water, shore, elsewhere), killer place, range, rise and motion, shots planted or moving,
## hits, and the hearts flipped. Split by our win and loss.
##
##   nim c -d:release -d:ssl -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw-0124/examples/paintbot --path:$HOME/p/paintbot-pw-0124/src \
##     --path:tools -o:tools/pw_lakefight tools/pw_lakefight.nim
##   tools/pw_lakefight [--game] [--near=units] [--until=ticks] <pw_fast dirs or replays>...
##
## Positions are printed in red's frame (blue games are mirrored by the half turn).

import
  std/[algorithm, math, os, sequtils, strformat, strutils, tables],
  game, sim, topography, fastdirs

const
  LakeHearts = [point(3200, 1250), point(3200, 2750)]
  PlaceLabels = ["water", "shore", "lakeside", "far"]
  StateLabels = ["windup", "cooling", "ready", "moving"]
  RegionLabels = ["our side", "middle", "their side"]
  RangeEdges = [500, 711, 1000, 1500, 2133, 100000]
  RangeLabels = ["0-5", "5-7", "7-10", "10-15", "15-21", "21+"]
  WeaponLabels = ["map", "gun", "grenade", "spray", "sniper", "selfdestruct"]
  ShoreRadius2 = 600'i64 * 600
  Reach2 = 2133'i64 * 2133

type
  Death = object
    game: string
    win: bool
    ours: bool
    tick, sinceStart: int
    victim, shooter: int
    victimPos, shooterPos: Point
    victimPlace, shooterPlace, victimState: int
    victimMoving, shooterMoving: bool
    victimHeld: bool
    victimApproaching: bool
    victimWade: int
    range, rise: int
    weapon: int
    saw: bool
    enemiesInReach, alliesNear: int
    oursAtLake, theirsAtLake: int
    hitsTaken, hitters: int
    victimHpAtStart: int
    role, squad, region: int
    range72, victimClosed, killerClosed: int
    firstArriver: bool
    killerHeartDist, victimHeartDist: int
    killerOurSide: bool
    contactRange, contactHeartDist, contactTicks: int
  Flip = object
    game: string
    win: bool
    tick: int
    toUs: bool
    heart: Point
    kind: int
  SideStats = object
    seatTicks: int
    waders: int
    wadeTicks: seq[int]
    shots, shotsPlanted, shotsMoving, shotsWet: int
    hits, hitsPlanted, hitsMoving, hitsWet: int
    shotsNear, hitsNear: int
    alive: int
  Game = object
    key: string
    win: bool
    start, finish: int
    theirFirst: int
    theirsAtStart, theirsWetAtStart, theirsHpAtStart: int
    oursAtStart: int
    lakeOwnedByThem, lakeOwnedByUs: int
    ourDeaths, theirDeaths: int
    ourWaders, theirWaders: int
    ourWade, theirWade: int
    flipsToUs, flipsToThem: int
    sides: array[2, SideStats]
    oursAliveAtStart, theirsAliveAtStart: int
    oursAliveAtEnd, theirsAliveAtEnd: int
    arrival: array[8, int]
    oursAt5, oursAt10, theirsAt10: int
    firstArriver, firstArriverDeath: int
    lakeTicksOurs, lakeTicksTheirs: int

var
  gameMode = false
  plainMode = false
  traceMode = false
  nearUnits = 1500
  untilTick = 2400
  events: seq[DamageEvent]
  shotsThisTick: seq[int]

proc wet(p: Point): bool =
  ## Whether a point lies in the lake.
  riverBlend(p.x.int, p.z.int) > 0 and terrainHeight(p.x.int, p.z.int) < RiverWaterHeight

proc lakeDist2(p: Point): int64 =
  ## Squared distance to the nearest lake heart.
  min(distance2(p, LakeHearts[0]), distance2(p, LakeHearts[1]))

proc placeOf(p: Point): int =
  ## Water, shore (dry within 600 of a lake heart) or elsewhere.
  if wet(p):
    0
  elif lakeDist2(p) <= ShoreRadius2:
    1
  elif lakeDist2(p) <= nearUnits.int64 * nearUnits.int64:
    2
  else:
    3

proc mirrored(side: int, p: Point): Point =
  ## The point in red's frame.
  if side == 0:
    p
  else:
    point(Width - p.x, Height - p.z)

proc dist(a, b: Point): int =
  ## Euclidean distance, rounded down.
  sqrt(float(distance2(a, b))).int

proc rangeBucket(d: int): int =
  ## Range bucket index for a distance in units.
  result = 0
  while d > RangeEdges[result]:
    inc result

proc moved(a, b: Point): bool =
  ## Whether a cog stepped more than 4 units between two positions.
  distance2(a, b) > 16

proc analyze(path: string, ourSide: int, win: bool, key: string, deaths: var seq[Death],
    flips: var seq[Flip], games: var seq[Game]) =
  ## Re-simulates one replay and records the lake window.
  let
    recording = loadRecording(path)
    enemy = 1 - ourSide
  var
    w = newWorld(recording.seed, recording.endTick)
    g = Game(key: key, win: win, start: -1, theirFirst: -1, firstArriver: -1, firstArriverDeath: -1)
    arrived: array[MaxSeats, bool]
    arrivedCount = 0
    wadeTicks: array[MaxSeats, int]
    hitsTaken: array[MaxSeats, int]
    hitters: array[MaxSeats, seq[int]]
    hpAtStart: array[MaxSeats, int]
    firstContact: array[MaxSeats, int]
    firstContactRange: array[MaxSeats, int]
    firstContactHeartDist: array[MaxSeats, int]
    owners: seq[int32]
    history: seq[seq[Cog]]
    shotPos: array[MaxSeats, Point]
    shotMoving: array[MaxSeats, bool]
    shotTick: array[MaxSeats, int]
    near2 = nearUnits.int64 * nearUnits.int64
  for h in w.controlHearts:
    owners.add h.owner
  for i in 0 ..< MaxSeats:
    shotTick[i] = -1
    firstContact[i] = -1
  damageLog = addr events
  observeShot = proc(tick: int32, slot: int) =
    shotsThisTick.add slot
  defer:
    damageLog = nil
    observeShot = nil
  proc atLake(side: int, cogs: seq[Cog]): int =
    for i in countup(side, Seats - 1, 2):
      if cogs[i].hp > 0 and lakeDist2(cogs[i].pos) <= near2:
        inc result
  proc alive(side: int, cogs: seq[Cog]): int =
    for i in countup(side, Seats - 1, 2):
      if cogs[i].hp > 0:
        inc result
  var previous = w.cogs
  for frame in recording.frames:
    let
      before = w.cogs
      prior = w
    events.setLen(0)
    shotsThisTick.setLen(0)
    w.step(frame.commands, replayRulesVersion)
    let tick = w.tick.int
    if tick > untilTick:
      break
    if g.theirFirst < 0 and atLake(enemy, w.cogs) > 0:
      g.theirFirst = tick
    if g.start < 0 and atLake(ourSide, w.cogs) > 0:
      g.start = tick
      g.oursAtStart = atLake(ourSide, w.cogs)
      for k in 0 ..< 8:
        g.arrival[k] = -1
      for i in countup(ourSide, Seats - 1, 2):
        if w.cogs[i].hp > 0 and lakeDist2(w.cogs[i].pos) <= near2 and g.firstArriver < 0:
          g.firstArriver = i
      g.oursAliveAtStart = alive(ourSide, w.cogs)
      g.theirsAliveAtStart = alive(enemy, w.cogs)
      for i in countup(enemy, Seats - 1, 2):
        if w.cogs[i].hp > 0 and lakeDist2(w.cogs[i].pos) <= near2:
          inc g.theirsAtStart
          g.theirsHpAtStart += w.cogs[i].hp.int
          if wet(w.cogs[i].pos):
            inc g.theirsWetAtStart
      for h in w.controlHearts:
        if lakeDist2(h.pos) <= 300'i64 * 300:
          if h.owner == enemy.int32:
            inc g.lakeOwnedByThem
          elif h.owner == ourSide.int32:
            inc g.lakeOwnedByUs
      for i in 0 ..< Seats:
        hpAtStart[i] = w.cogs[i].hp.int
      for idx, h in w.controlHearts:
        owners[idx] = h.owner
    if g.start < 0:
      previous = before
      history.add before
      if history.len > 80:
        history.delete(0)
      continue
    g.finish = tick
    for i in countup(ourSide, Seats - 1, 2):
      if not arrived[i] and w.cogs[i].hp > 0 and lakeDist2(w.cogs[i].pos) <= near2:
        arrived[i] = true
        g.arrival[arrivedCount] = tick - g.start
        inc arrivedCount
    if tick - g.start == 5 * TickRate:
      g.oursAt5 = atLake(ourSide, w.cogs)
    if tick - g.start == 10 * TickRate:
      g.oursAt10 = atLake(ourSide, w.cogs)
      g.theirsAt10 = atLake(enemy, w.cogs)
    g.lakeTicksOurs += atLake(ourSide, w.cogs)
    if traceMode and tick mod TickRate == 0:
      var line = &"  t{tick div TickRate:3d}s"
      for i in countup(ourSide, Seats - 1, 2):
        if w.cogs[i].hp <= 0:
          line.add &" [{i:2d} dead]"
          continue
        var
          seen = 0
          nearest = -1
        for j in countup(enemy, Seats - 1, 2):
          if w.cogs[j].hp > 0 and w.visible(i, j):
            inc seen
            let r = dist(w.cogs[i].pos, w.cogs[j].pos)
            if nearest < 0 or r < nearest:
              nearest = r
        let p = mirrored(ourSide, w.cogs[i].pos)
        line.add &" [{i:2d} ({p.x},{p.z}) {(if wet(w.cogs[i].pos): \"W\" else: \"d\")} h{sqrt(float(lakeDist2(w.cogs[i].pos))).int div 100:2d} hp{w.cogs[i].hp} s{seen}@{(if nearest < 0: 0 else: nearest div 100):2d}]"
      echo line
    for i in 0 ..< Seats:
      if firstContact[i] >= 0 or before[i].hp <= 0:
        continue
      var nearest = -1
      for j in countup(1 - team(i), Seats - 1, 2):
        if before[j].hp > 0 and prior.visible(i, j):
          let r = dist(before[i].pos, before[j].pos)
          if nearest < 0 or r < nearest:
            nearest = r
      if nearest >= 0:
        firstContact[i] = tick
        firstContactRange[i] = nearest
        firstContactHeartDist[i] = sqrt(float(lakeDist2(before[i].pos))).int
    g.lakeTicksTheirs += atLake(enemy, w.cogs)
    for slot in shotsThisTick:
      let
        side = team(slot)
        s = addr g.sides[(if side == ourSide: 0 else: 1)]
        moving = moved(before[slot].pos, w.cogs[slot].pos)
      shotPos[slot] = w.cogs[slot].pos
      shotMoving[slot] = moving
      shotTick[slot] = tick
      inc s.shots
      if moving:
        inc s.shotsMoving
      else:
        inc s.shotsPlanted
      if wet(w.cogs[slot].pos):
        inc s.shotsWet
      if lakeDist2(w.cogs[slot].pos) <= near2:
        inc s.shotsNear
    for e in events:
      if e.attacker < 0 or e.attacker == e.victim:
        continue
      let
        a = e.attacker.int
        v = e.victim.int
      if team(a) == team(v):
        continue
      let
        ours = team(v) == ourSide
        ag = addr g.sides[(if ours: 1 else: 0)]
        shooterAt =
          if shotTick[a] == tick:
            shotPos[a]
          else:
            w.cogs[a].pos
        shooterMoving =
          if shotTick[a] == tick:
            shotMoving[a]
          else:
            moved(before[a].pos, w.cogs[a].pos)
      if e.weapon == 1 or e.weapon == 4:
        inc ag.hits
        if shooterMoving:
          inc ag.hitsMoving
        else:
          inc ag.hitsPlanted
        if wet(shooterAt):
          inc ag.hitsWet
        if lakeDist2(shooterAt) <= near2:
          inc ag.hitsNear
      inc hitsTaken[v]
      if a notin hitters[v]:
        hitters[v].add a
      if e.killed == 1 and before[v].hp > 0 and w.cogs[v].hp <= 0:
        var d = Death(game: key, win: win, ours: ours, tick: tick, sinceStart: tick - g.start,
          victim: v, shooter: a, weapon: clamp(e.weapon.int, 0, 5))
        d.victimPos = mirrored(ourSide, before[v].pos)
        d.shooterPos = mirrored(ourSide, shooterAt)
        d.victimPlace = placeOf(before[v].pos)
        d.shooterPlace = placeOf(shooterAt)
        d.victimMoving = moved(previous[v].pos, before[v].pos)
        d.shooterMoving = shooterMoving
        d.range = dist(shooterAt, before[v].pos)
        d.rise = terrainHeight(shooterAt.x.int, shooterAt.z.int) -
          terrainHeight(before[v].pos.x.int, before[v].pos.z.int)
        d.saw = prior.visible(v, a)
        d.victimState =
          if d.victimMoving:
            3
          elif prior.equipment[v].windup > 0:
            0
          elif prior.cogs[v].cooldown > 0:
            1
          else:
            2
        d.victimWade = wadeTicks[v]
        d.hitsTaken = hitsTaken[v]
        d.hitters = hitters[v].len
        d.victimHpAtStart = hpAtStart[v]
        d.role = (v div 2) mod 4
        d.squad = ((v div 2) mod 8) div 4
        d.region =
          if d.victimPos.x < 2200:
            0
          elif d.victimPos.x <= 4200:
            1
          else:
            2
        d.firstArriver = v == g.firstArriver
        d.killerHeartDist = sqrt(float(lakeDist2(shooterAt))).int
        d.victimHeartDist = sqrt(float(lakeDist2(before[v].pos))).int
        d.killerOurSide = d.shooterPos.x < 3200
        if firstContact[v] >= 0:
          d.contactRange = firstContactRange[v]
          d.contactHeartDist = firstContactHeartDist[v]
          d.contactTicks = tick - firstContact[v]
        else:
          d.contactRange = -1
        if ours and v == g.firstArriver:
          g.firstArriverDeath = tick - g.start
        if history.len >= 72:
          let old = history[history.len - 72]
          d.range72 = dist(old[a].pos, old[v].pos)
          d.victimClosed = dist(old[v].pos, shooterAt) - dist(before[v].pos, shooterAt)
          d.killerClosed = dist(old[a].pos, before[v].pos) - dist(shooterAt, before[v].pos)
        else:
          d.range72 = -1
        if history.len >= 24:
          let old = history[history.len - 24][v].pos
          d.victimHeld = distance2(old, before[v].pos) < 150'i64 * 150
          d.victimApproaching = lakeDist2(old) > lakeDist2(before[v].pos) + 100 * 100
        for j in 0 ..< Seats:
          if j == v or before[j].hp <= 0:
            continue
          if team(j) == team(v):
            if distance2(before[j].pos, before[v].pos) <= 1000'i64 * 1000:
              inc d.alliesNear
          elif distance2(before[j].pos, before[v].pos) <= Reach2:
            inc d.enemiesInReach
        d.oursAtLake = atLake(ourSide, before)
        d.theirsAtLake = atLake(enemy, before)
        deaths.add d
        if ours:
          inc g.ourDeaths
        else:
          inc g.theirDeaths
        if gameMode:
          let who = (if ours: "OURS" else: "jb  ")
          echo &"  {tick div TickRate:3d}s +{d.sinceStart div TickRate:3d}s {who} seat {v:2d} r{d.role} " &
            &"{PlaceLabels[d.victimPlace]:9s} at ({d.victimPos.x},{d.victimPos.z}) " &
            &"{StateLabels[d.victimState]:7s} wade {d.victimWade:3d}t " &
            &"killed by {a:2d} {WeaponLabels[d.weapon]:7s} from {PlaceLabels[d.shooterPlace]:9s} " &
            &"({d.shooterPos.x},{d.shooterPos.z}) {(if d.shooterMoving: \"moving\" else: \"planted\")} " &
            &"{d.range div 100:2d}.{(d.range mod 100) div 10}m rise {d.rise:4d} saw={d.saw.int} " &
            &"hits {d.hitsTaken} by {d.hitters} foesReach {d.enemiesInReach} allies {d.alliesNear} " &
            &"lake ours {d.oursAtLake} theirs {d.theirsAtLake}"
    for i in 0 ..< Seats:
      if w.cogs[i].hp <= 0:
        continue
      let s = addr g.sides[(if team(i) == ourSide: 0 else: 1)]
      inc s.seatTicks
      if wet(w.cogs[i].pos):
        if wadeTicks[i] == 0:
          inc s.waders
        inc wadeTicks[i]
    for idx, h in w.controlHearts:
      if h.owner != owners[idx]:
        if h.owner >= 0:
          var f = Flip(game: key, win: win, tick: tick, toUs: h.owner == ourSide.int32,
            heart: mirrored(ourSide, h.pos))
          if lakeDist2(h.pos) <= 300'i64 * 300:
            f.kind = 0
          elif f.heart.x < 3200:
            f.kind = 1
          else:
            f.kind = 2
          flips.add f
          if f.toUs:
            inc g.flipsToUs
          else:
            inc g.flipsToThem
        owners[idx] = h.owner
    previous = before
    history.add before
    if history.len > 80:
      history.delete(0)
  if g.start >= 0:
    for i in 0 ..< Seats:
      if wadeTicks[i] > 0:
        let s = addr g.sides[(if team(i) == ourSide: 0 else: 1)]
        s.wadeTicks.add wadeTicks[i]
    g.ourWaders = g.sides[0].waders
    g.theirWaders = g.sides[1].waders
    g.ourWade = g.sides[0].wadeTicks.sum
    g.theirWade = g.sides[1].wadeTicks.sum
    g.oursAliveAtEnd = alive(ourSide, w.cogs)
    g.theirsAliveAtEnd = alive(enemy, w.cogs)
  games.add g

proc quartiles(xs: seq[int]): string =
  ## "q1 / median / q3" of a list.
  if xs.len == 0:
    return "-"
  var s = xs
  s.sort()
  &"{s[s.len div 4]} / {s[s.len div 2]} / {s[s.len * 3 div 4]}"

proc mean(xs: seq[int]): float =
  ## Arithmetic mean, 0 when empty.
  if xs.len == 0:
    return 0.0
  xs.sum.float / xs.len.float

proc pct(a, b: int): string =
  ## Percentage string, a dash for no observations.
  if b == 0:
    "-"
  else:
    &"{int(round(100.0 * a.float / b.float))}% ({a})"

proc deathTable(label: string, ds: seq[Death], games: int) =
  ## Prints the anatomy of one group of deaths.
  echo &"### {label}: {ds.len} deaths in {games} windows ({ds.len.float / max(games, 1).float:.2f} per game)"
  if ds.len == 0:
    return
  echo &"seconds into the window q1/med/q3: {quartiles(ds.mapIt(it.sinceStart div TickRate))}; game second: {quartiles(ds.mapIt(it.tick div TickRate))}"
  var byVictimPlace, byKillerPlace: array[4, int]
  var byState: array[4, int]
  var byWeapon: array[6, int]
  var byRange: array[6, int]
  for d in ds:
    inc byVictimPlace[d.victimPlace]
    inc byKillerPlace[d.shooterPlace]
    inc byState[d.victimState]
    inc byWeapon[d.weapon]
    inc byRange[rangeBucket(d.range)]
  var cells: seq[string]
  for k in 0 .. 3:
    cells.add &"{PlaceLabels[k]} {pct(byVictimPlace[k], ds.len)}"
  echo "victim place: " & cells.join(", ")
  cells.setLen(0)
  for k in 0 .. 3:
    cells.add &"{PlaceLabels[k]} {pct(byKillerPlace[k], ds.len)}"
  echo "killer place: " & cells.join(", ")
  var cross = initCountTable[string]()
  for d in ds:
    cross.inc PlaceLabels[d.victimPlace] & " <- " & PlaceLabels[d.shooterPlace]
  var keys = toSeq(cross.keys)
  keys.sort()
  echo "victim <- killer: " & keys.mapIt(&"{it} {cross[it]}").join(", ")
  var
    byRegion: array[3, int]
    byRole: array[4, int]
    regionWeapon = initCountTable[string]()
    placeWeapon = initCountTable[string]()
  for d in ds:
    inc byRegion[d.region]
    inc byRole[d.role]
    regionWeapon.inc RegionLabels[d.region] & " " & WeaponLabels[d.weapon]
    placeWeapon.inc PlaceLabels[d.victimPlace] & " " & WeaponLabels[d.weapon]
  cells.setLen(0)
  for k in 0 .. 2:
    cells.add &"{RegionLabels[k]} {pct(byRegion[k], ds.len)}"
  echo "victim region (red frame x): " & cells.join(", ")
  keys = toSeq(regionWeapon.keys)
  keys.sort()
  echo "region x weapon: " & keys.mapIt(&"{it} {regionWeapon[it]}").join(", ")
  keys = toSeq(placeWeapon.keys)
  keys.sort()
  echo "place x weapon: " & keys.mapIt(&"{it} {placeWeapon[it]}").join(", ")
  cells.setLen(0)
  for k in 0 .. 3:
    cells.add &"seat {k} {pct(byRole[k], ds.len)}"
  echo "victim squad role (0-1 ring, 2-3 cover): " & cells.join(", ") & &"; first arriver {pct(ds.filterIt(it.firstArriver).len, ds.len)}"
  echo &"victim within 1100 of a lake heart {pct(ds.filterIt(it.victimHeartDist <= 1100).len, ds.len)}; first enemy sighting in the window: range q1/med/q3 {quartiles(ds.filterIt(it.contactRange >= 0).mapIt(it.contactRange))}, victim heart distance then {quartiles(ds.filterIt(it.contactRange >= 0).mapIt(it.contactHeartDist))}, seconds from that sighting to death {quartiles(ds.filterIt(it.contactRange >= 0).mapIt(it.contactTicks div TickRate))}, never saw one {pct(ds.filterIt(it.contactRange < 0).len, ds.len)}"
  echo &"victim distance to the nearest lake heart q1/med/q3: {quartiles(ds.mapIt(it.victimHeartDist))}; killer distance: {quartiles(ds.mapIt(it.killerHeartDist))}; killer within 600 {pct(ds.filterIt(it.killerHeartDist <= 600).len, ds.len)}, 600-1100 {pct(ds.filterIt(it.killerHeartDist > 600 and it.killerHeartDist <= 1100).len, ds.len)}, 1100-1500 {pct(ds.filterIt(it.killerHeartDist > 1100 and it.killerHeartDist <= 1500).len, ds.len)}, beyond {pct(ds.filterIt(it.killerHeartDist > 1500).len, ds.len)}; killer on our side of the heart line (x < 3200) {pct(ds.filterIt(it.killerOurSide).len, ds.len)}"
  let withHistory = ds.filterIt(it.range72 >= 0)
  echo &"range 3 s before death q1/med/q3: {quartiles(withHistory.mapIt(it.range72))}; killer closed in those 3 s: {quartiles(withHistory.mapIt(it.killerClosed))} (killer closed 2 m+ {pct(withHistory.filterIt(it.killerClosed >= 200).len, withHistory.len)}); victim closed: {quartiles(withHistory.mapIt(it.victimClosed))} (victim closed 2 m+ {pct(withHistory.filterIt(it.victimClosed >= 200).len, withHistory.len)}); neither {pct(withHistory.filterIt(it.killerClosed < 200 and it.victimClosed < 200).len, withHistory.len)}"
  cells.setLen(0)
  for k in 0 .. 5:
    if byWeapon[k] > 0:
      cells.add &"{WeaponLabels[k]} {byWeapon[k]}"
  echo "weapon: " & cells.join(", ")
  cells.setLen(0)
  for k in 0 .. 5:
    cells.add &"{RangeLabels[k]} m {pct(byRange[k], ds.len)}"
  let rangeLine = cells.join(", ")
  echo &"killer planted {pct(ds.filterIt(not it.shooterMoving).len, ds.len)}, moving {pct(ds.filterIt(it.shooterMoving).len, ds.len)}"
  cells.setLen(0)
  for k in 0 .. 3:
    cells.add &"{StateLabels[k]} {pct(byState[k], ds.len)}"
  echo "victim state: " & cells.join(", ")
  echo &"victim still {pct(ds.filterIt(not it.victimMoving).len, ds.len)}, moving {pct(ds.filterIt(it.victimMoving).len, ds.len)}; held ground over 1 s {pct(ds.filterIt(it.victimHeld).len, ds.len)}; approaching the lake {pct(ds.filterIt(it.victimApproaching).len, ds.len)}"
  echo "kill range: " & rangeLine & &"; q1/med/q3 {quartiles(ds.mapIt(it.range))}"
  echo &"killer above (+50) {pct(ds.filterIt(it.rise > 50).len, ds.len)}, level {pct(ds.filterIt(it.rise >= -50 and it.rise <= 50).len, ds.len)}, below {pct(ds.filterIt(it.rise < -50).len, ds.len)}; rise q1/med/q3 {quartiles(ds.mapIt(it.rise))}"
  echo &"victim saw the killer {pct(ds.filterIt(it.saw).len, ds.len)}"
  echo &"victim wade ticks in the window before death q1/med/q3: {quartiles(ds.mapIt(it.victimWade))}; victims that waded at all {pct(ds.filterIt(it.victimWade > 0).len, ds.len)}; waded 48+ ticks {pct(ds.filterIt(it.victimWade >= 48).len, ds.len)}"
  echo &"hits taken in the window before dying q1/med/q3: {quartiles(ds.mapIt(it.hitsTaken))}; distinct hitters {quartiles(ds.mapIt(it.hitters))}; hit by 2+ {pct(ds.filterIt(it.hitters >= 2).len, ds.len)}; hp at window start {quartiles(ds.mapIt(it.victimHpAtStart))}"
  echo &"enemies within 21 m at death q1/med/q3: {quartiles(ds.mapIt(it.enemiesInReach))} (mean {mean(ds.mapIt(it.enemiesInReach)):.2f}); allies within 10 m: {quartiles(ds.mapIt(it.alliesNear))} (mean {mean(ds.mapIt(it.alliesNear)):.2f})"
  echo &"our cogs within {nearUnits} of a lake heart at the death: {quartiles(ds.mapIt(it.oursAtLake))} (mean {mean(ds.mapIt(it.oursAtLake)):.2f}); theirs: {quartiles(ds.mapIt(it.theirsAtLake))} (mean {mean(ds.mapIt(it.theirsAtLake)):.2f})"
  var vcells = initCountTable[string]()
  var kcells = initCountTable[string]()
  for d in ds:
    vcells.inc &"({d.victimPos.x div 400 * 400 + 200},{d.victimPos.z div 400 * 400 + 200})"
    kcells.inc &"({d.shooterPos.x div 400 * 400 + 200},{d.shooterPos.z div 400 * 400 + 200})"
  var vk = toSeq(vcells.pairs)
  vk.sort(proc(a, b: (string, int)): int = cmp(b[1], a[1]))
  var kk = toSeq(kcells.pairs)
  kk.sort(proc(a, b: (string, int)): int = cmp(b[1], a[1]))
  echo "victim cells (red frame, 4 m): " & vk[0 ..< min(8, vk.len)].mapIt(&"{it[0]} {it[1]}").join(", ")
  echo "killer cells (red frame, 4 m): " & kk[0 ..< min(8, kk.len)].mapIt(&"{it[0]} {it[1]}").join(", ")
  echo ""

proc sideTable(label: string, gs: seq[Game], side: int) =
  ## Prints the shots, hits and wading of one side across a group of games.
  var
    s: SideStats
    wadersPerGame: seq[int]
  for g in gs:
    let x = g.sides[side]
    s.seatTicks += x.seatTicks
    s.waders += x.waders
    s.wadeTicks.add x.wadeTicks
    s.shots += x.shots
    s.shotsPlanted += x.shotsPlanted
    s.shotsMoving += x.shotsMoving
    s.shotsWet += x.shotsWet
    s.shotsNear += x.shotsNear
    s.hits += x.hits
    s.hitsPlanted += x.hitsPlanted
    s.hitsMoving += x.hitsMoving
    s.hitsWet += x.hitsWet
    s.hitsNear += x.hitsNear
    wadersPerGame.add x.waders
  echo &"### {label}"
  echo &"waders per game q1/med/q3: {quartiles(wadersPerGame)} (mean {mean(wadersPerGame):.2f}); wade ticks per wader q1/med/q3: {quartiles(s.wadeTicks)} (mean {mean(s.wadeTicks):.0f}); wade share of seat time {pct(s.wadeTicks.sum, s.seatTicks)}"
  echo &"gun shots {s.shots} ({s.shots.float / max(gs.len, 1).float:.1f} per game): planted {pct(s.shotsPlanted, s.shots)}, moving {pct(s.shotsMoving, s.shots)}, from water {pct(s.shotsWet, s.shots)}, within {nearUnits} of a lake heart {pct(s.shotsNear, s.shots)}"
  echo &"gun hits {s.hits}: accuracy {pct(s.hits, s.shots)}; planted {pct(s.hitsPlanted, s.shotsPlanted)}, moving {pct(s.hitsMoving, s.shotsMoving)}, from water {pct(s.hitsWet, s.shotsWet)}, near the lake {pct(s.hitsNear, s.shotsNear)}"
  echo ""

proc report(deaths: seq[Death], flips: seq[Flip], games: seq[Game]) =
  ## Prints the per-game table and the grouped summary.
  echo "## Games"
  echo "| game | result | start s | jb first s | jb at lake | jb wet | jb hp | lake jb/us | ours at lake | alive us/jb | our deaths | jb deaths | our waders | our wade t | jb waders | jb wade t | flips us/jb | alive end us/jb |"
  echo "|---|---|---:|---:|---:|---:|---:|---|---:|---|---:|---:|---:|---:|---:|---:|---|---|"
  for g in games:
    let tag =
      if g.win:
        "win"
      else:
        "loss"
    if g.start < 0:
      echo &"| {g.key} | {tag} | - | {g.theirFirst div TickRate} | | | | | | | | | | | | | | |"
      continue
    echo &"| {g.key} | {tag} | {g.start div TickRate} | {g.theirFirst div TickRate} | {g.theirsAtStart} | {g.theirsWetAtStart} | {g.theirsHpAtStart} | {g.lakeOwnedByThem}/{g.lakeOwnedByUs} | {g.oursAtStart} | {g.oursAliveAtStart}/{g.theirsAliveAtStart} | {g.ourDeaths} | {g.theirDeaths} | {g.ourWaders} | {g.ourWade} | {g.theirWaders} | {g.theirWade} | {g.flipsToUs}/{g.flipsToThem} | {g.oursAliveAtEnd}/{g.theirsAliveAtEnd} |"
  echo ""
  for win in [true, false]:
    let
      label =
        if win:
          "WINS"
        else:
          "LOSSES"
      gs = games.filterIt(it.win == win and it.start >= 0)
      none = games.filterIt(it.win == win and it.start < 0).len
    echo &"## {label}: {gs.len} games with a lake window, {none} without"
    echo &"window start s q1/med/q3: {quartiles(gs.mapIt(it.start div TickRate))}; jb first at the lake s: {quartiles(gs.filterIt(it.theirFirst >= 0).mapIt(it.theirFirst div TickRate))}; window end s: {quartiles(gs.mapIt(it.finish div TickRate))}"
    echo &"at our arrival: jb cogs within {nearUnits} q1/med/q3 {quartiles(gs.mapIt(it.theirsAtStart))} (mean {mean(gs.mapIt(it.theirsAtStart)):.2f}), of them wet {mean(gs.mapIt(it.theirsWetAtStart)):.2f}, their hp sum {mean(gs.mapIt(it.theirsHpAtStart)):.1f}; lake hearts jb-owned {mean(gs.mapIt(it.lakeOwnedByThem)):.2f}, ours {mean(gs.mapIt(it.lakeOwnedByUs)):.2f}; our cogs within {nearUnits} {quartiles(gs.mapIt(it.oursAtStart))}"
    echo &"alive at start us/jb: {mean(gs.mapIt(it.oursAliveAtStart)):.2f}/{mean(gs.mapIt(it.theirsAliveAtStart)):.2f}; alive at the window end us/jb: {mean(gs.mapIt(it.oursAliveAtEnd)):.2f}/{mean(gs.mapIt(it.theirsAliveAtEnd)):.2f}"
    var arrivalCells: seq[string]
    for k in 1 ..< 8:
      let xs = gs.filterIt(it.arrival[k] >= 0).mapIt(it.arrival[k] div TickRate)
      arrivalCells.add &"#{k + 1} +{quartiles(xs)} s ({xs.len})"
    echo "our arrivals within " & $nearUnits & " after the first (q1/med/q3 s, games): " & arrivalCells.join("; ")
    echo &"our cogs within {nearUnits} at +5 s: {quartiles(gs.mapIt(it.oursAt5))} (mean {mean(gs.mapIt(it.oursAt5)):.2f}); at +10 s: {quartiles(gs.mapIt(it.oursAt10))} (mean {mean(gs.mapIt(it.oursAt10)):.2f}) vs jb at +10 s {mean(gs.mapIt(it.theirsAt10)):.2f}; mean presence over the window ours {mean(gs.mapIt(it.lakeTicksOurs div max(it.finish - it.start, 1))):.2f}, jb {mean(gs.mapIt(it.lakeTicksTheirs div max(it.finish - it.start, 1))):.2f}"
    let fa = gs.filterIt(it.firstArriverDeath >= 0)
    echo &"first arriver died in the window: {pct(fa.len, gs.len)}; its death at +{quartiles(fa.mapIt(it.firstArriverDeath div TickRate))} s; within 15 s {pct(fa.filterIt(it.firstArriverDeath <= 15 * TickRate).len, gs.len)}"
    echo &"deaths in the window per game: ours {mean(gs.mapIt(it.ourDeaths)):.2f}, jb {mean(gs.mapIt(it.theirDeaths)):.2f}; games where we lost more than jb {gs.filterIt(it.ourDeaths > it.theirDeaths).len}, fewer {gs.filterIt(it.ourDeaths < it.theirDeaths).len}, equal {gs.filterIt(it.ourDeaths == it.theirDeaths).len}"
    let fs = flips.filterIt(it.win == win)
    echo &"hearts flipped in the window: to us {fs.filterIt(it.toUs).len} (lake {fs.filterIt(it.toUs and it.kind == 0).len}, our side {fs.filterIt(it.toUs and it.kind == 1).len}, their side {fs.filterIt(it.toUs and it.kind == 2).len}); to jb {fs.filterIt(not it.toUs).len} (lake {fs.filterIt(not it.toUs and it.kind == 0).len}, our side {fs.filterIt(not it.toUs and it.kind == 1).len}, their side {fs.filterIt(not it.toUs and it.kind == 2).len})"
    echo ""
    sideTable(label & " ours", gs, 0)
    sideTable(label & " jb", gs, 1)
    deathTable(label & " our deaths", deaths.filterIt(it.win == win and it.ours), gs.len)
    deathTable(label & " jb deaths", deaths.filterIt(it.win == win and not it.ours), gs.len)
    deathTable(label & " our deaths at the lake (water, shore, lakeside)", deaths.filterIt(it.win == win and it.ours and it.victimPlace <= 2), gs.len)
    deathTable(label & " jb deaths at the lake (water, shore, lakeside)", deaths.filterIt(it.win == win and not it.ours and it.victimPlace <= 2), gs.len)
  echo "## ALL our deaths by victim place and the killer's state"
  let ours = deaths.filterIt(it.ours)
  for place in 0 .. 3:
    let ds = ours.filterIt(it.victimPlace == place)
    if ds.len == 0:
      continue
    echo &"{PlaceLabels[place]}: {ds.len} deaths; killer planted {pct(ds.filterIt(not it.shooterMoving).len, ds.len)}; killer in water {pct(ds.filterIt(it.shooterPlace == 0).len, ds.len)}, on the shore {pct(ds.filterIt(it.shooterPlace == 1).len, ds.len)}; range med {quartiles(ds.mapIt(it.range))}; rise med {quartiles(ds.mapIt(it.rise))}; victim moving {pct(ds.filterIt(it.victimMoving).len, ds.len)}; saw killer {pct(ds.filterIt(it.saw).len, ds.len)}; enemies in reach mean {mean(ds.mapIt(it.enemiesInReach)):.2f}; allies near mean {mean(ds.mapIt(it.alliesNear)):.2f}; wins {ds.filterIt(it.win).len} losses {ds.filterIt(not it.win).len}"
  echo ""
  echo "## ALL jb deaths by victim place and the killer's state"
  let theirs = deaths.filterIt(not it.ours)
  for place in 0 .. 3:
    let ds = theirs.filterIt(it.victimPlace == place)
    if ds.len == 0:
      continue
    echo &"{PlaceLabels[place]}: {ds.len} deaths; killer planted {pct(ds.filterIt(not it.shooterMoving).len, ds.len)}; killer in water {pct(ds.filterIt(it.shooterPlace == 0).len, ds.len)}, on the shore {pct(ds.filterIt(it.shooterPlace == 1).len, ds.len)}; range med {quartiles(ds.mapIt(it.range))}; rise med {quartiles(ds.mapIt(it.rise))}; victim moving {pct(ds.filterIt(it.victimMoving).len, ds.len)}; saw killer {pct(ds.filterIt(it.saw).len, ds.len)}; enemies in reach mean {mean(ds.mapIt(it.enemiesInReach)):.2f}; allies near mean {mean(ds.mapIt(it.alliesNear)):.2f}; wins {ds.filterIt(it.win).len} losses {ds.filterIt(not it.win).len}"
  echo ""
  echo "## Our deaths by 10 s bucket of the window"
  var byTime = initCountTable[int]()
  var byTimeJb = initCountTable[int]()
  for d in deaths:
    if d.ours:
      byTime.inc d.sinceStart div (TickRate * 10) * 10
    else:
      byTimeJb.inc d.sinceStart div (TickRate * 10) * 10
  var times = toSeq(byTime.keys)
  for t in byTimeJb.keys:
    if t notin times:
      times.add t
  times.sort()
  echo "ours: " & times.mapIt(&"+{it}s:{byTime.getOrDefault(it)}").join(" ")
  echo "jb:   " & times.mapIt(&"+{it}s:{byTimeJb.getOrDefault(it)}").join(" ")

proc printMap() =
  ## Prints the lake surroundings in 200-unit cells: W water, otherwise terrain height in metres
  ## (rounded), H marks a lake heart cell, red frame.
  echo "## Lake map (200-unit cells, x 1600..4800 across, z -600..4600 down; W water, digits height m, H heart)"
  var header = "      "
  for x in countup(1600, 4800, 200):
    header.add &"{x:>5}"
  echo header
  for z in countup(-600, 4600, 200):
    var line = &"{z:>5} "
    for x in countup(1600, 4800, 200):
      let p = point(x + 100, z + 100)
      var cell = ""
      for h in LakeHearts:
        if abs(h.x - p.x) <= 100 and abs(h.z - p.z) <= 100:
          cell = "H"
      if cell == "":
        if wet(p):
          cell = "W"
        else:
          cell = $(terrainHeight(p.x.int, p.z.int) div 100)
      line.add &"{cell:>5}"
    echo line
  echo ""

proc main() =
  var replays: seq[string]
  for argument in commandLineParams():
    if argument == "--game":
      gameMode = true
    elif argument == "--trace":
      traceMode = true
    elif argument == "--plain":
      plainMode = true
    elif argument == "--map":
      let recording = loadRecording(replays[0])
      discard newWorld(recording.seed, recording.endTick)
      printMap()
      echo &"vision range metres: {visionRangeMetres()} (0 = unlimited); rules {replayRulesVersion}"
      return
    elif argument.startsWith("--near="):
      nearUnits = parseInt(argument["--near=".len .. ^1])
    elif argument.startsWith("--until="):
      untilTick = parseInt(argument["--until=".len .. ^1])
    elif argument.endsWith(".replay"):
      replays.add argument
    else:
      for path in walkDirRec(argument):
        if path.endsWith(".replay"):
          replays.add path
  replays.sort()
  var
    deaths: seq[Death]
    flips: seq[Flip]
    games: seq[Game]
  for path in replays:
    let roster = fastRoster(path, true)
    if roster.len != 16 and not plainMode:
      continue
    var
      ourSide = 0
      win = true
      key = path.extractFilename
    if roster.len == 16:
      ourSide =
        if roster[0].endsWith(" win") or roster[0].endsWith(" loss"):
          0
        else:
          1
      win = roster[ourSide].endsWith(" win")
      let parts = path.split(DirSep)
      key = parts[^4].split('_')[2] & "/" & parts[^2]
    if gameMode:
      echo path
    analyze(path, ourSide, win, key, deaths, flips, games)
  report(deaths, flips, games)

main()
