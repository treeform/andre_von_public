## Paintbot PW duel anatomy: how each side's cogs die, hit by hit.
##
##   nim c -d:release -d:ssl -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw-0124/examples/paintbot --path:$HOME/p/paintbot-pw-0124/src \
##     --path:tools -o:tools/pw_duels tools/pw_duels.nim
##   tools/pw_duels [--game] <pw_fast dirs or replays>...
##
## Re-simulates every replay. Our side is the pw_fast tag, split by outcome ("ours W", "ours L"),
## the rival is "rival W" / "rival L" (W and L are OUR outcome). Per group: hits and kills by weapon,
## range, height, shooter and victim motion, water, place and time; the victim's state at the
## killing hit (planted in a windup, standing with the gun cooling, standing ready, moving); the
## contact seconds before death; and the share of contact ticks spent standing. --game prints every
## death of every replay on one line.

import
  std/[algorithm, deques, math, os, sequtils, strformat, strutils, tables],
  game, sim, topography, fastdirs

const
  RangeEdges = [500, 711, 1000, 1500, 2100, 3000, 100000]
  RangeLabels = ["0-5", "5-7", "7-10", "10-15", "15-21", "21-30", "30+"]
  WeaponLabels = ["map", "gun", "grenade", "spray", "sniper", "selfdestruct"]
  StateLabels = ["windup", "cooling", "ready", "moving"]
  PlaceLabels = ["lake heart", "home ring", "near heart", "open"]
  TimeEdges = [720, 1440, 2160, 2880, 100000]
  TimeLabels = ["0-30s", "30-60s", "60-90s", "90-120s", "120s+"]
  LakeHearts = [point(3200, 1250), point(3200, 2750)]

type
  Duel = object
    seatGames: int
    deaths, kills: int
    hits, hitsTaken: int
    killWeapon, hitWeapon: array[6, int]
    killRange, hitRange: array[7, int]
    killUp, killLevel, killDown: int
    hitUp, hitLevel, hitDown: int
    killShooterMoving, killVictimMoving: int
    hitShooterMoving, hitVictimMoving: int
    killVictimWet, killShooterWet, hitVictimWet, hitShooterWet: int
    deathState: array[4, int]
    hitState: array[4, int]
    deathPlace: array[4, int]
    deathTime: array[5, int]
    deathContactTicks, deathLifeHits, deathHitSpan: int
    deathFocus: int
    deathLakeDepth: int
    contactTicks, contactStanding, contactWindup: int
    aliveTicks: int
    deathSniperVictim: int
    killShooterSniper: int
    deathOutranged: int
    firstHitRange: int
    deathEnemiesNear, deathAlliesNear: int
    weaponDeaths: array[6, int]
    weaponRange72, weaponRange24: array[6, int]
    weaponVictimHp72, weaponVictimHp24: array[6, int]
    weaponKillerHp, weaponTeamHits72: array[6, int]
    weaponAmbush, weaponVictimHeld, weaponVictimRing: array[6, int]
    weaponKillerSeen72: array[6, int]

var
  gameMode = false
  events: seq[DamageEvent]

proc wet(p: Point): bool =
  ## Whether a point lies in the lake.
  riverBlend(p.x.int, p.z.int) > 0 and terrainHeight(p.x.int, p.z.int) < RiverWaterHeight

proc speed2(a, b: Point): int64 =
  ## Squared step between two positions.
  distance2(a, b)

proc rangeBucket(d: int): int =
  ## Range bucket index for a distance in units.
  result = 0
  while d > RangeEdges[result]:
    inc result

proc timeBucket(t: int): int =
  ## Time bucket index for a tick.
  result = 0
  while t > TimeEdges[result]:
    inc result

proc placeOf(w: World, p: Point): int =
  ## Where a point lies: lake heart ring, home ring, near another heart, or the open.
  for h in LakeHearts:
    if distance2(p, h) < 900'i64 * 900:
      return 0
  for side in 0 .. 1:
    if distance2(p, home(side)) < 900'i64 * 900:
      return 1
  for h in w.controlHearts:
    if distance2(p, h.pos) < 900'i64 * 900:
      return 2
  3

proc groupName(ours: bool, won: bool): string =
  ## Group label for a side and our outcome.
  (if ours: "ours " else: "rival ") & (if won: "W" else: "L")

proc analyze(path: string, roster: seq[string], duels: var Table[string, Duel]) =
  ## Re-simulates one replay and adds its duels to the per-group table.
  let recording = loadRecording(path)
  var
    w = newWorld(recording.seed, recording.endTick)
    contactStart: array[MaxSeats, int]
    lastContact: array[MaxSeats, int]
    lifeHits: array[MaxSeats, int]
    firstHit: array[MaxSeats, int]
    firstHitRange: array[MaxSeats, int]
    hitters: array[MaxSeats, seq[int]]
    history = initDeque[seq[Cog]]()
    recentHits: array[MaxSeats, seq[int]]
    seenEnemy: array[MaxSeats, seq[int]]
  let
    oursEven = roster[0].startsWith("ours")
    won = roster[0].endsWith("W")
  for i in 0 ..< MaxSeats:
    contactStart[i] = -1
    lastContact[i] = -1
    firstHit[i] = -1
  damageLog = addr events
  defer:
    damageLog = nil
  for side in 0 .. 1:
    let ours = (side == 0) == oursEven
    var d = addr duels.mgetOrPut(groupName(ours, won), Duel())
    d.seatGames += Seats div 2
  var previous = w.cogs
  for frame in recording.frames:
    let
      before = w.cogs
      beforeEq = w.equipment
    events.setLen(0)
    w.step(frame.commands, replayRulesVersion)
    let tick = w.tick.int
    for e in events:
      if e.health <= 0 or e.attacker < 0 or e.attacker == e.victim:
        continue
      let
        a = e.attacker.int
        v = e.victim.int
      if team(a) == team(v):
        continue
      let
        victimOurs = (team(v) == 0) == oursEven
        vg = addr duels.mgetOrPut(groupName(victimOurs, won), Duel())
        ag = addr duels.mgetOrPut(groupName(not victimOurs, won), Duel())
        range = sqrt(float(distance2(before[a].pos, before[v].pos))).int
        rb = rangeBucket(range)
        rise = terrainHeight(before[a].pos.x.int, before[a].pos.z.int) -
          terrainHeight(before[v].pos.x.int, before[v].pos.z.int)
        shooterMoving = speed2(previous[a].pos, before[a].pos) > 16
        victimMoving = speed2(previous[v].pos, before[v].pos) > 16
        weapon = clamp(e.weapon.int, 0, 5)
      var state = 3
      if not victimMoving:
        if beforeEq[v].windup > 0:
          state = 0
        elif before[v].cooldown > 0:
          state = 1
        else:
          state = 2
      inc vg.hitsTaken
      inc ag.hits
      inc ag.hitWeapon[weapon]
      inc ag.hitRange[rb]
      if rise > 50:
        inc ag.hitUp
      elif rise < -50:
        inc ag.hitDown
      else:
        inc ag.hitLevel
      if shooterMoving:
        inc ag.hitShooterMoving
      if victimMoving:
        inc ag.hitVictimMoving
      if wet(before[v].pos):
        inc ag.hitVictimWet
      if wet(before[a].pos):
        inc ag.hitShooterWet
      inc vg.hitState[state]
      inc lifeHits[v]
      if firstHit[v] < 0:
        firstHit[v] = tick
        firstHitRange[v] = range
      if a notin hitters[v]:
        hitters[v].add a
      recentHits[v].add tick
      if recentHits[v].len > 64:
        recentHits[v].delete(0)
      if e.killed == 1 and before[v].hp > 0 and w.cogs[v].hp <= 0:
        let
          old72 = (if history.len >= 72: history[history.len - 72] elif history.len > 0: history[0] else: before)
          old24 = (if history.len >= 24: history[history.len - 24] elif history.len > 0: history[0] else: before)
          range72 = sqrt(float(distance2(old72[a].pos, old72[v].pos))).int
          range24 = sqrt(float(distance2(old24[a].pos, old24[v].pos))).int
          held = distance2(old24[v].pos, before[v].pos) < 150'i64 * 150
        var teamHits = 0
        for t in recentHits[a]:
          if t >= tick - 72:
            inc teamHits
        var seenTicks = 0
        for t in seenEnemy[v]:
          if t >= tick - 72:
            inc seenTicks
        var ring = false
        for h in w.controlHearts:
          if distance2(before[v].pos, h.pos) < 300'i64 * 300:
            ring = true
        inc vg.weaponDeaths[weapon]
        vg.weaponRange72[weapon] += range72
        vg.weaponRange24[weapon] += range24
        vg.weaponVictimHp72[weapon] += old72[v].hp.int
        vg.weaponVictimHp24[weapon] += old24[v].hp.int
        vg.weaponKillerHp[weapon] += before[a].hp.int
        vg.weaponTeamHits72[weapon] += teamHits
        vg.weaponKillerSeen72[weapon] += seenTicks
        if contactStart[v] < 0 or tick - contactStart[v] <= 72:
          inc vg.weaponAmbush[weapon]
        if held:
          inc vg.weaponVictimHeld[weapon]
        if ring:
          inc vg.weaponVictimRing[weapon]
        inc vg.deaths
        inc ag.kills
        inc ag.killWeapon[weapon]
        inc ag.killRange[rb]
        if rise > 50:
          inc ag.killUp
        elif rise < -50:
          inc ag.killDown
        else:
          inc ag.killLevel
        if shooterMoving:
          inc ag.killShooterMoving
        if victimMoving:
          inc ag.killVictimMoving
        if wet(before[v].pos):
          inc ag.killVictimWet
        if wet(before[a].pos):
          inc ag.killShooterWet
        if w.sniper[a]:
          inc ag.killShooterSniper
        if w.sniper[v]:
          inc vg.deathSniperVictim
        if range > 2100 and not w.sniper[v]:
          inc vg.deathOutranged
        inc vg.deathState[state]
        let place = placeOf(w, before[v].pos)
        inc vg.deathPlace[place]
        inc vg.deathTime[timeBucket(tick)]
        if lastContact[v] >= 0 and tick - lastContact[v] <= 48 and contactStart[v] >= 0:
          vg.deathContactTicks += tick - contactStart[v]
        vg.deathLifeHits += lifeHits[v]
        vg.deathHitSpan += tick - firstHit[v]
        vg.firstHitRange += firstHitRange[v]
        if hitters[v].len >= 2:
          inc vg.deathFocus
        var allies, enemies = 0
        for j in 0 ..< Seats:
          if j == v or before[j].hp <= 0:
            continue
          if distance2(before[j].pos, before[v].pos) <= 2000'i64 * 2000:
            if team(j) == team(v):
              inc allies
            else:
              inc enemies
        vg.deathAlliesNear += allies
        vg.deathEnemiesNear += enemies
        if gameMode:
          let who = (if victimOurs: "OURS" else: "jb  ")
          echo &"  {tick div 24:3d}s t{tick:5d} {who} seat {v:2d} killed by {a:2d} {WeaponLabels[weapon]:12s} " &
            &"{range div 100:2d}.{(range mod 100) div 10}m rise {rise:5d} victim {StateLabels[state]:7s} " &
            &"shooter {(if shooterMoving: \"moving\" else: \"still \")} " &
            &"wet v={wet(before[v].pos).int} a={wet(before[a].pos).int} {PlaceLabels[place]:10s} " &
            &"hits {lifeHits[v]} over {tick - firstHit[v]} ticks by {hitters[v].len} hitters, " &
            &"contact {(if contactStart[v] >= 0: (tick - contactStart[v]) div 24 else: 0)}s, " &
            &"near allies {allies} enemies {enemies} at ({before[v].pos.x},{before[v].pos.z}) " &
            &"killer at {range72 div 100}m/-3s {range24 div 100}m/-1s hp {before[a].hp} " &
            &"took {teamHits} hits/3s; victim hp {old72[v].hp}/-3s {old24[v].hp}/-1s held={held.int} ring={ring.int}"
    for i in 0 ..< Seats:
      if before[i].hp <= 0:
        continue
      let
        ours = (team(i) == 0) == oursEven
        g = addr duels.mgetOrPut(groupName(ours, won), Duel())
      inc g.aliveTicks
      var seen = false
      for j in 0 ..< Seats:
        if team(j) != team(i) and before[j].hp > 0 and w.visible(i, j):
          seen = true
          break
      if seen:
        if lastContact[i] < 0 or tick - lastContact[i] > 48:
          contactStart[i] = tick
        lastContact[i] = tick
        seenEnemy[i].add tick
        if seenEnemy[i].len > 80:
          seenEnemy[i].delete(0)
        inc g.contactTicks
        if speed2(previous[i].pos, before[i].pos) <= 16:
          inc g.contactStanding
        if beforeEq[i].windup > 0:
          inc g.contactWindup
    previous = before
    history.addLast before
    if history.len > 80:
      history.popFirst()

proc pct(a, b: int): string =
  ## Percentage string, a dash for no observations.
  if b == 0:
    "-"
  else:
    $int(round(100.0 * a.float / b.float)) & "%"

proc mean(a, b: int, scale = 1.0, digits = 1): string =
  ## Mean a / b scaled, a dash for no observations.
  if b == 0:
    "-"
  else:
    formatFloat(a.float / b.float * scale, ffDecimal, digits)

proc main() =
  var replays: seq[string]
  for input in commandLineParams():
    if input == "--game":
      gameMode = true
      continue
    if input.endsWith(".replay"):
      replays.add input
      continue
    for path in walkDirRec(input):
      if path.endsWith(".replay"):
        replays.add path
  replays.sort()
  var duels = initTable[string, Duel]()
  for path in replays:
    let raw = fastRoster(path, true)
    if raw.len != 16:
      continue
    var roster: seq[string]
    for slot in 0 ..< 16:
      let r = raw[slot]
      if r.endsWith(" win"):
        roster.add "ours W"
      elif r.endsWith(" loss"):
        roster.add "ours L"
      else:
        roster.add "rival"
    let won = roster.anyIt(it == "ours W")
    for slot in 0 ..< 16:
      if roster[slot] == "rival":
        roster[slot] = "rival " & (if won: "W" else: "L")
    if gameMode:
      echo path
    analyze(path, roster, duels)
  var order = toSeq(duels.keys)
  order.sort()
  echo "| stat | " & order.join(" | ") & " |"
  echo "|---|" & order.mapIt("---:").join("|") & "|"
  template row(label: string, body: untyped) =
    var cells: seq[string]
    for name in order:
      let d {.inject.} = duels[name]
      cells.add body
    echo "| " & label & " | " & cells.join(" | ") & " |"
  row("seat-games"): $d.seatGames
  row("deaths per seat-game"): &"{d.deaths / d.seatGames:.2f}"
  row("kills per seat-game"): &"{d.kills / d.seatGames:.2f}"
  row("hits dealt per seat-game"): &"{d.hits / d.seatGames:.2f}"
  row("hits taken per seat-game"): &"{d.hitsTaken / d.seatGames:.2f}"
  for k in 0 ..< 6:
    row("kills by " & WeaponLabels[k]): pct(d.killWeapon[k], d.kills) & &" ({d.killWeapon[k]})"
  for k in 0 ..< 6:
    row("hits by " & WeaponLabels[k]): pct(d.hitWeapon[k], d.hits)
  for k in 0 ..< 7:
    row("kills at " & RangeLabels[k] & " m"): pct(d.killRange[k], d.kills) & &" ({d.killRange[k]})"
  for k in 0 ..< 7:
    row("hits at " & RangeLabels[k] & " m"): pct(d.hitRange[k], d.hits)
  row("kills from above"): pct(d.killUp, d.kills)
  row("kills level"): pct(d.killLevel, d.kills)
  row("kills from below"): pct(d.killDown, d.kills)
  row("hits from above"): pct(d.hitUp, d.hits)
  row("hits level"): pct(d.hitLevel, d.hits)
  row("hits from below"): pct(d.hitDown, d.hits)
  row("kills with shooter moving"): pct(d.killShooterMoving, d.kills)
  row("kills with victim moving"): pct(d.killVictimMoving, d.kills)
  row("hits with shooter moving"): pct(d.hitShooterMoving, d.hits)
  row("hits with victim moving"): pct(d.hitVictimMoving, d.hits)
  row("kills with victim in water"): pct(d.killVictimWet, d.kills)
  row("kills with shooter in water"): pct(d.killShooterWet, d.kills)
  row("hits with victim in water"): pct(d.hitVictimWet, d.hits)
  row("hits with shooter in water"): pct(d.hitShooterWet, d.hits)
  row("kills by a sniper carrier"): pct(d.killShooterSniper, d.kills)
  for k in 0 ..< 4:
    row("own deaths while " & StateLabels[k]): pct(d.deathState[k], d.deaths) & &" ({d.deathState[k]})"
  for k in 0 ..< 4:
    row("hits taken while " & StateLabels[k]): pct(d.hitState[k], d.hitsTaken)
  for k in 0 ..< 4:
    row("own deaths at " & PlaceLabels[k]): pct(d.deathPlace[k], d.deaths) & &" ({d.deathPlace[k]})"
  for k in 0 ..< 5:
    row("own deaths in " & TimeLabels[k]): pct(d.deathTime[k], d.deaths) & &" ({d.deathTime[k]})"
  row("own deaths beyond 21 m without a sniper"): pct(d.deathOutranged, d.deaths)
  row("own deaths carrying a sniper"): pct(d.deathSniperVictim, d.deaths)
  row("own deaths hit by 2+ enemies"): pct(d.deathFocus, d.deaths)
  row("contact seconds before death"): (if d.deaths == 0: "-" else: &"{d.deathContactTicks / d.deaths / 24:.1f}")
  row("hits taken per death"): (if d.deaths == 0: "-" else: &"{d.deathLifeHits / d.deaths:.1f}")
  row("seconds from first hit to death"): (if d.deaths == 0: "-" else: &"{d.deathHitSpan / d.deaths / 24:.1f}")
  row("range of the first hit taken, m"): (if d.deaths == 0: "-" else: &"{d.firstHitRange / d.deaths / 100:.1f}")
  row("allies near at death"): (if d.deaths == 0: "-" else: &"{d.deathAlliesNear / d.deaths:.2f}")
  row("enemies near at death"): (if d.deaths == 0: "-" else: &"{d.deathEnemiesNear / d.deaths:.2f}")
  row("contact seconds per seat-game"): &"{d.contactTicks / d.seatGames / 24:.1f}"
  row("contact share of alive time"): pct(d.contactTicks, d.aliveTicks)
  row("standing share of contact"): pct(d.contactStanding, d.contactTicks)
  row("windup share of contact"): pct(d.contactWindup, d.contactTicks)
  for k in 1 ..< 5:
    let wl = WeaponLabels[k]
    row("own deaths by " & wl): $d.weaponDeaths[k]
    row(wl & " death: killer range 3 s before, m"): mean(d.weaponRange72[k], d.weaponDeaths[k], 0.01)
    row(wl & " death: killer range 1 s before, m"): mean(d.weaponRange24[k], d.weaponDeaths[k], 0.01)
    row(wl & " death: victim hp 3 s before"): mean(d.weaponVictimHp72[k], d.weaponDeaths[k])
    row(wl & " death: victim hp 1 s before"): mean(d.weaponVictimHp24[k], d.weaponDeaths[k])
    row(wl & " death: killer hp at the kill"): mean(d.weaponKillerHp[k], d.weaponDeaths[k])
    row(wl & " death: hits the killer took in the last 3 s"): mean(d.weaponTeamHits72[k], d.weaponDeaths[k], 1.0, 2)
    row(wl & " death: victim saw an enemy in the last 3 s, ticks"): mean(d.weaponKillerSeen72[k], d.weaponDeaths[k], 1.0, 0)
    row(wl & " death: ambush (contact under 3 s)"): pct(d.weaponAmbush[k], d.weaponDeaths[k])
    row(wl & " death: victim held ground (moved under 1.5 m in 1 s)"): pct(d.weaponVictimHeld[k], d.weaponDeaths[k])
    row(wl & " death: victim within 3 m of a heart"): pct(d.weaponVictimRing[k], d.weaponDeaths[k])

main()
