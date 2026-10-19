## Paintbot PW duel micro: planted versus moving gunnery, plant exposure and dodge footwork.
##
##   nim c -d:release -d:ssl -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw-0124/examples/paintbot --path:$HOME/p/paintbot-pw-0124/src \
##     --path:tools -o:tools/pw_micro tools/pw_micro.nim
##   tools/pw_micro <pw_fast dirs or replays>...
##
## Re-simulates every replay. A gun shot (sniper shots left out) is credited to the nearest
## visible enemy at its release and is a hit when the shooter dealt gun damage on that tick.
## Groups are "ours W", "ours L", "rival W", "rival L" (W and L are our outcome). Rows: accuracy
## by range and, inside 15 m, by water, height, shooter and target motion; the shooter's drift
## over the five-tick windup and whether the ray passes within a cog radius of the target from the
## release and from the order position; damage density on planted, standing and moving contact
## ticks; dodge runs in contact (lengths, reversals, stops, step consistency); the calm-target
## filter (target moved under 100 units in the 3 ticks before the order); and gun time to kill.

import
  std/[algorithm, deques, math, os, sequtils, strformat, strutils, tables],
  game, sim, topography, fastdirs

const
  RangeEdges = [500, 711, 1000, 1500, 2133, 100000]
  RangeLabels = ["0-5", "5-7", "7-10", "10-15", "15-21", "21+"]
  DriftEdges = [0, 60, 120, 100000]
  DriftLabels = ["0", "1-60", "61-120", "121+"]
  RunEdges = [2, 4, 8, 16, 100000]
  RunLabels = ["1-2", "3-4", "5-8", "9-16", "17+"]
  Windup = 5
  Near = 1500
  Calm2 = 30'i64 * 30
  Slow2 = 60'i64 * 60
  Moving2 = 16'i64
  Early = 1440

type
  Micro = object
    seatGames: int
    shots, hits: int
    rangeShots, rangeHits: array[6, int]
    nearShots, nearHits: int
    nearDryDryShots, nearDryDryHits: int
    nearDryWetShots, nearDryWetHits: int
    nearWetDryShots, nearWetDryHits: int
    nearWetWetShots, nearWetWetHits: int
    nearUpShots, nearUpHits, nearLevelShots, nearLevelHits: int
    nearDownShots, nearDownHits: int
    nearMovingShots, nearMovingHits, nearStillShots, nearStillHits: int
    nearTargetMovingShots, nearTargetMovingHits: int
    nearTargetStillShots, nearTargetStillHits: int
    # Target motion in the 3 ticks before the order: under 30 units (stopped or wading), 30 to 59,
    # 60 and over (a dry walker covers 84).
    calmShots, calmHits, slowShots, slowHits, busyShots, busyHits: int
    calmWetShots, calmWetHits, calmDryShots, calmDryHits: int
    busyWetShots, busyWetHits, busyDryShots, busyDryHits: int
    earlyWindupTicks, earlyContactTicks, earlyStandingTicks: int
    longRuns: int
    # Duel ticks: the nearest visible enemy inside 15 m. Hits by weapon per state.
    duelWindupTicks, duelStandingTicks, duelMovingTicks: int
    duelWindupHits, duelStandingHits, duelMovingHits: int
    windupGrenadeHits, standingGrenadeHits, movingGrenadeHits: int
    windupSprayHits, standingSprayHits, movingSprayHits: int
    # Constant-velocity self prediction over five steps for runs that last six.
    predictRuns, predictWithin28, predictWithin55: int
    # Target in water by range, and dry-target shots with a wading enemy also in reach.
    rangeWetShots, rangeWetHits, rangeDryShots, rangeDryHits: array[6, int]
    dryWithWetAltShots, dryWithWetAltHits: int
    wetAltRange: array[6, int]
    driftShots, driftHits: array[4, int]
    driftSum: int
    acrossRelease55, acrossOrder55, acrossShots: int
    acrossReleaseSum, acrossOrderSum: int
    plants, plantsHit, plantsGunHit: int
    windupTicks, windupHits, windupGunHits: int
    movingTicks, movingHits, movingGunHits: int
    standingTicks, standingHits, standingGunHits: int
    runs: array[5, int]
    runTicks, runCount: int
    reversals, turns, stops: int
    contactTicks, contactMoving, contactWet: int
    stepPairs, stepPairsWithin4, stepPairsWithin10: int
    readyTicks, readyCalmTicks, readySlowTicks, readyCalmWetTicks, readyBusyWetTicks: int
    kills, gunKills, gunDeaths, gunDeathTicks: int
    killShotsAt, killHitsAt: int

var
  events: seq[DamageEvent]
  shotsThisTick: seq[int]

proc wet(p: Point): bool =
  ## Whether a point lies in the lake.
  riverBlend(p.x.int, p.z.int) > 0 and terrainHeight(p.x.int, p.z.int) < RiverWaterHeight

proc bucket(edges: openArray[int], v: int): int =
  ## Index of the first edge at or above v.
  result = 0
  while v > edges[result]:
    inc result

proc groupName(ours: bool, won: bool): string =
  ## Group label for a side and our outcome.
  (if ours: "ours " else: "rival ") & (if won: "W" else: "L")

proc across(origin, dir, target: Point): int =
  ## Perpendicular distance from the target to the ray, or a large number behind the origin.
  let
    dx = float(target.x - origin.x)
    dz = float(target.z - origin.z)
    len = sqrt(float(dir.x) * float(dir.x) + float(dir.z) * float(dir.z))
  if len < 1:
    return 100000
  let
    ux = float(dir.x) / len
    uz = float(dir.z) / len
    along = dx * ux + dz * uz
  if along <= 0:
    return 100000
  int(abs(dx * uz - dz * ux))

proc analyze(path: string, roster: seq[string], micros: var Table[string, Micro]) =
  ## Re-simulates one replay and adds its micro numbers to the per-group table.
  let recording = loadRecording(path)
  var
    w = newWorld(recording.seed, recording.endTick)
    history = initDeque[seq[Cog]]()
    orderPos: array[MaxSeats, Point]
    orderTick: array[MaxSeats, int]
    plantHit, plantGunHit: array[MaxSeats, bool]
    runDir: array[MaxSeats, Point]
    runLen: array[MaxSeats, int]
    runStart: array[MaxSeats, Point]
    lastStep: array[MaxSeats, Point]
    lastGunHit: array[MaxSeats, int]
    engageStart: array[MaxSeats, int]
    shotsAt: array[MaxSeats, int]
    hitsAt: array[MaxSeats, int]
  let
    oursEven = roster[0].startsWith("ours")
    won = roster[0].endsWith("W")
  for i in 0 ..< MaxSeats:
    orderTick[i] = -1
    lastGunHit[i] = -1000
  damageLog = addr events
  observeShot = proc(tick: int32, slot: int) =
    shotsThisTick.add slot
  defer:
    damageLog = nil
    observeShot = nil
  for side in 0 .. 1:
    let ours = (side == 0) == oursEven
    var m = addr micros.mgetOrPut(groupName(ours, won), Micro())
    m.seatGames += Seats div 2
  var previous = w.cogs
  for frame in recording.frames:
    let
      before = w.cogs
      beforeEq = w.equipment
    events.setLen(0)
    shotsThisTick.setLen(0)
    var seen: array[MaxSeats, bool]
    for i in 0 ..< Seats:
      if before[i].hp <= 0:
        continue
      for j in 0 ..< Seats:
        if team(j) != team(i) and before[j].hp > 0 and w.visible(i, j):
          seen[i] = true
          break
    w.step(frame.commands, replayRulesVersion)
    let tick = w.tick.int
    var
      damaged: array[MaxSeats, bool]
      gunDamaged: array[MaxSeats, bool]
      grenadeDamaged: array[MaxSeats, bool]
      sprayDamaged: array[MaxSeats, bool]
      gunHitBy: array[MaxSeats, bool]
    for e in events:
      if e.health <= 0 or e.attacker < 0 or e.attacker == e.victim:
        continue
      if team(e.attacker.int) == team(e.victim.int):
        continue
      damaged[e.victim] = true
      if e.weapon == 2:
        grenadeDamaged[e.victim] = true
      if e.weapon == 3:
        sprayDamaged[e.victim] = true
      if e.weapon == 1:
        gunDamaged[e.victim] = true
        gunHitBy[e.attacker] = true
        inc hitsAt[e.victim]
        if tick - lastGunHit[e.victim] > 72:
          engageStart[e.victim] = tick
        lastGunHit[e.victim] = tick
    # Contact states and plant exposure, judged on the positions the step started from.
    for i in 0 ..< Seats:
      if before[i].hp <= 0:
        continue
      let
        ours = (team(i) == 0) == oursEven
        m = addr micros.mgetOrPut(groupName(ours, won), Micro())
        moving = distance2(previous[i].pos, before[i].pos) > Moving2
      var duel = false
      if seen[i]:
        for j in 0 ..< Seats:
          if team(j) != team(i) and before[j].hp > 0 and w.visible(i, j) and
              distance2(before[i].pos, before[j].pos) <= int64(Near) * Near:
            duel = true
            break
      if beforeEq[i].windup > 0 and not w.sniper[i]:
        if grenadeDamaged[i]: inc m.windupGrenadeHits
        if sprayDamaged[i]: inc m.windupSprayHits
        if duel:
          inc m.duelWindupTicks
          if damaged[i]: inc m.duelWindupHits
      elif seen[i] and moving:
        if grenadeDamaged[i]: inc m.movingGrenadeHits
        if sprayDamaged[i]: inc m.movingSprayHits
        if duel:
          inc m.duelMovingTicks
          if damaged[i]: inc m.duelMovingHits
      elif seen[i]:
        if grenadeDamaged[i]: inc m.standingGrenadeHits
        if sprayDamaged[i]: inc m.standingSprayHits
        if duel:
          inc m.duelStandingTicks
          if damaged[i]: inc m.duelStandingHits
      if tick <= Early:
        if beforeEq[i].windup > 0 and not w.sniper[i]:
          inc m.earlyWindupTicks
        elif seen[i] and not moving:
          inc m.earlyStandingTicks
        if seen[i]:
          inc m.earlyContactTicks
      if beforeEq[i].windup > 0 and not w.sniper[i]:
        inc m.windupTicks
        if damaged[i]:
          inc m.windupHits
          plantHit[i] = true
        if gunDamaged[i]:
          inc m.windupGunHits
          plantGunHit[i] = true
        if beforeEq[i].windup == 1:
          inc m.plants
          if plantHit[i]:
            inc m.plantsHit
          if plantGunHit[i]:
            inc m.plantsGunHit
          plantHit[i] = false
          plantGunHit[i] = false
      elif seen[i]:
        if moving:
          inc m.movingTicks
          if damaged[i]:
            inc m.movingHits
          if gunDamaged[i]:
            inc m.movingGunHits
        else:
          inc m.standingTicks
          if damaged[i]:
            inc m.standingHits
          if gunDamaged[i]:
            inc m.standingGunHits
      # Dodge runs in contact.
      if seen[i]:
        inc m.contactTicks
        if wet(before[i].pos):
          inc m.contactWet
        let step = point(before[i].pos.x.int - previous[i].pos.x.int,
          before[i].pos.z.int - previous[i].pos.z.int)
        if moving:
          inc m.contactMoving
          let dot = int64(step.x) * runDir[i].x + int64(step.z) * runDir[i].z
          if runLen[i] > 0 and dot > 0:
            inc runLen[i]
            if runLen[i] == 6:
              # Five steps after the first: where a leg-compensated ray would have left from.
              let
                predicted = point(runStart[i].x.int + 6 * runDir[i].x.int,
                  runStart[i].z.int + 6 * runDir[i].z.int)
                err2 = distance2(predicted, before[i].pos)
              inc m.predictRuns
              if err2 <= 28 * 28:
                inc m.predictWithin28
              if err2 <= 55 * 55:
                inc m.predictWithin55
            inc m.stepPairs
            let d2 = distance2(step, lastStep[i])
            if d2 <= 16:
              inc m.stepPairsWithin4
            if d2 <= 100:
              inc m.stepPairsWithin10
          else:
            if runLen[i] > 0:
              inc m.runs[bucket(RunEdges, runLen[i])]
              m.runTicks += runLen[i]
              inc m.runCount
              if runLen[i] >= 6:
                inc m.longRuns
              if dot < 0:
                inc m.reversals
              else:
                inc m.turns
            runLen[i] = 1
            runDir[i] = step
            runStart[i] = previous[i].pos
          lastStep[i] = step
        else:
          if runLen[i] > 0:
            inc m.runs[bucket(RunEdges, runLen[i])]
            m.runTicks += runLen[i]
            inc m.runCount
            if runLen[i] >= 6:
              inc m.longRuns
            inc m.stops
          runLen[i] = 0
      else:
        runLen[i] = 0
      # Gun order: the windup starts this step.
      if beforeEq[i].windup == 0 and w.equipment[i].windup == Windup:
        orderPos[i] = w.cogs[i].pos
        orderTick[i] = tick
      # Calm-target opportunity for a ready gun in contact.
      if seen[i] and beforeEq[i].windup == 0 and before[i].cooldown == 0 and
          not w.sniper[i] and not beforeEq[i].sprayCan and history.len >= 4:
        var
          target = -1
          best = int64.high
        for j in 0 ..< Seats:
          if team(j) != team(i) and before[j].hp > 0 and w.visible(i, j):
            let d = distance2(before[i].pos, before[j].pos)
            if d < best:
              best = d
              target = j
        if target >= 0 and best <= int64(Near) * Near:
          inc m.readyTicks
          let
            old = history[history.len - 4]
            moved2 = distance2(old[target].pos, before[target].pos)
          if moved2 < Calm2:
            inc m.readyCalmTicks
            if wet(before[target].pos):
              inc m.readyCalmWetTicks
          else:
            if moved2 < Slow2:
              inc m.readySlowTicks
            if wet(before[target].pos):
              inc m.readyBusyWetTicks
    # Shots released this step.
    for slot in shotsThisTick:
      if w.sniper[slot]:
        continue
      let
        ours = (team(slot) == 0) == oursEven
        m = addr micros.mgetOrPut(groupName(ours, won), Micro())
        origin = w.cogs[slot].pos
      var
        target = -1
        best = int64.high
      for j in 0 ..< Seats:
        if team(j) != team(slot) and before[j].hp > 0 and w.visible(slot, j):
          let d = distance2(origin, w.cogs[j].pos)
          if d < best:
            best = d
            target = j
      if target < 0:
        continue
      let
        hit = gunHitBy[slot]
        range = sqrt(best.float).int
        tpos = w.cogs[target].pos
        shooterMoving = distance2(before[slot].pos, origin) > Moving2
        targetMoving = distance2(before[target].pos, tpos) > Moving2
        rise = terrainHeight(origin.x.int, origin.z.int) -
          terrainHeight(tpos.x.int, tpos.z.int)
      inc shotsAt[target]
      inc m.shots
      inc m.rangeShots[bucket(RangeEdges, range)]
      if hit:
        inc m.hits
        inc m.rangeHits[bucket(RangeEdges, range)]
      if wet(tpos):
        inc m.rangeWetShots[bucket(RangeEdges, range)]
        if hit: inc m.rangeWetHits[bucket(RangeEdges, range)]
      else:
        inc m.rangeDryShots[bucket(RangeEdges, range)]
        if hit: inc m.rangeDryHits[bucket(RangeEdges, range)]
        var altRange = -1
        for j in 0 ..< Seats:
          if j != target and team(j) != team(slot) and before[j].hp > 0 and
              w.visible(slot, j) and wet(w.cogs[j].pos):
            let d = sqrt(float(distance2(origin, w.cogs[j].pos))).int
            if d <= 2133 and (altRange < 0 or d < altRange):
              altRange = d
        if altRange >= 0:
          inc m.dryWithWetAltShots
          if hit: inc m.dryWithWetAltHits
          inc m.wetAltRange[bucket(RangeEdges, altRange)]
      if range <= Near:
        inc m.nearShots
        if hit:
          inc m.nearHits
        let
          sw = wet(origin)
          tw = wet(tpos)
        if not sw and not tw:
          inc m.nearDryDryShots
          if hit: inc m.nearDryDryHits
        elif not sw and tw:
          inc m.nearDryWetShots
          if hit: inc m.nearDryWetHits
        elif sw and not tw:
          inc m.nearWetDryShots
          if hit: inc m.nearWetDryHits
        else:
          inc m.nearWetWetShots
          if hit: inc m.nearWetWetHits
        if rise > 50:
          inc m.nearUpShots
          if hit: inc m.nearUpHits
        elif rise < -50:
          inc m.nearDownShots
          if hit: inc m.nearDownHits
        else:
          inc m.nearLevelShots
          if hit: inc m.nearLevelHits
        if shooterMoving:
          inc m.nearMovingShots
          if hit: inc m.nearMovingHits
        else:
          inc m.nearStillShots
          if hit: inc m.nearStillHits
        if targetMoving:
          inc m.nearTargetMovingShots
          if hit: inc m.nearTargetMovingHits
        else:
          inc m.nearTargetStillShots
          if hit: inc m.nearTargetStillHits
      # Drift over the windup and the ray from both origins.
      if orderTick[slot] == tick - Windup and history.len >= Windup + 3:
        let
          drift = sqrt(float(distance2(orderPos[slot], origin))).int
          db = bucket(DriftEdges, drift)
          dir = w.equipment[slot].gunAim
        inc m.driftShots[db]
        m.driftSum += drift
        if hit:
          inc m.driftHits[db]
        let
          ar = across(origin, dir, tpos)
          ao = across(orderPos[slot], dir, tpos)
        inc m.acrossShots
        m.acrossReleaseSum += min(ar, 600)
        m.acrossOrderSum += min(ao, 600)
        if ar <= Radius:
          inc m.acrossRelease55
        if ao <= Radius:
          inc m.acrossOrder55
        # The target's motion in the 3 ticks before the order.
        let
          atOrder = history[history.len - Windup]
          beforeOrder = history[history.len - Windup - 3]
          moved2 = distance2(beforeOrder[target].pos, atOrder[target].pos)
          tw = wet(tpos)
        if moved2 < Calm2:
          inc m.calmShots
          if hit: inc m.calmHits
          if tw:
            inc m.calmWetShots
            if hit: inc m.calmWetHits
          else:
            inc m.calmDryShots
            if hit: inc m.calmDryHits
        elif moved2 < Slow2:
          inc m.slowShots
          if hit: inc m.slowHits
        else:
          inc m.busyShots
          if hit: inc m.busyHits
          if tw:
            inc m.busyWetShots
            if hit: inc m.busyWetHits
          else:
            inc m.busyDryShots
            if hit: inc m.busyDryHits
    # Gun deaths and time to kill.
    for e in events:
      if e.killed != 1 or e.attacker < 0 or e.attacker == e.victim:
        continue
      let v = e.victim.int
      if before[v].hp <= 0 or w.cogs[v].hp > 0 or team(e.attacker.int) == team(v):
        continue
      let
        victimOurs = (team(v) == 0) == oursEven
        vg = addr micros.mgetOrPut(groupName(victimOurs, won), Micro())
        ag = addr micros.mgetOrPut(groupName(not victimOurs, won), Micro())
      if e.weapon == 1:
        inc vg.gunDeaths
        inc ag.gunKills
        vg.gunDeathTicks += tick - engageStart[v]
      inc ag.kills
      ag.killShotsAt += shotsAt[v]
      ag.killHitsAt += hitsAt[v]
    previous = before
    history.addLast w.cogs
    if history.len > 16:
      history.popFirst()

proc pct(a, b: int): string =
  ## Percentage string with the count, a dash for no observations.
  if b == 0:
    "-"
  else:
    formatFloat(100.0 * a.float / b.float, ffDecimal, 1) & &"% ({b})"

proc per100(a, b: int): string =
  ## Events per 100 ticks with the tick count.
  if b == 0:
    "-"
  else:
    formatFloat(100.0 * a.float / b.float, ffDecimal, 2) & &" ({b})"

proc mean(a, b: int, scale = 1.0): string =
  ## Mean a / b scaled, a dash for no observations.
  if b == 0:
    "-"
  else:
    formatFloat(a.float / b.float * scale, ffDecimal, 2)

proc main() =
  var replays: seq[string]
  for input in commandLineParams():
    if input.endsWith(".replay"):
      replays.add input
      continue
    for path in walkDirRec(input):
      if path.endsWith(".replay"):
        replays.add path
  replays.sort()
  var micros = initTable[string, Micro]()
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
    analyze(path, roster, micros)
  var order = toSeq(micros.keys)
  order.sort()
  echo "| stat | " & order.join(" | ") & " |"
  echo "|---|" & order.mapIt("---:").join("|") & "|"
  template row(label: string, body: untyped) =
    var cells: seq[string]
    for name in order:
      let m {.inject.} = micros[name]
      cells.add body
    echo "| " & label & " | " & cells.join(" | ") & " |"
  row("seat-games"): $m.seatGames
  row("gun shots per seat-game"): mean(m.shots, m.seatGames)
  row("gun accuracy, all"): pct(m.hits, m.shots)
  for k in 0 ..< 6:
    row("gun accuracy " & RangeLabels[k] & " m"): pct(m.rangeHits[k], m.rangeShots[k])
  for k in 0 ..< 6:
    row("accuracy on a wading target " & RangeLabels[k] & " m"): pct(m.rangeWetHits[k], m.rangeWetShots[k])
  for k in 0 ..< 6:
    row("accuracy on a dry target " & RangeLabels[k] & " m"): pct(m.rangeDryHits[k], m.rangeDryShots[k])
  row("dry-target shots with a wading enemy also in reach"): pct(m.dryWithWetAltShots, m.shots)
  row("those shots: accuracy"): pct(m.dryWithWetAltHits, m.dryWithWetAltShots)
  for k in 0 ..< 6:
    row("wading alternative at " & RangeLabels[k] & " m"): pct(m.wetAltRange[k], m.dryWithWetAltShots)
  row("gun shots inside 15 m"): pct(m.nearShots, m.shots)
  row("15 m: accuracy"): pct(m.nearHits, m.nearShots)
  row("15 m: shooter dry, target dry"): pct(m.nearDryDryHits, m.nearDryDryShots)
  row("15 m: shooter dry, target wet"): pct(m.nearDryWetHits, m.nearDryWetShots)
  row("15 m: shooter wet, target dry"): pct(m.nearWetDryHits, m.nearWetDryShots)
  row("15 m: shooter wet, target wet"): pct(m.nearWetWetHits, m.nearWetWetShots)
  row("15 m: from above"): pct(m.nearUpHits, m.nearUpShots)
  row("15 m: level"): pct(m.nearLevelHits, m.nearLevelShots)
  row("15 m: from below"): pct(m.nearDownHits, m.nearDownShots)
  row("15 m: shooter moving at release"): pct(m.nearMovingHits, m.nearMovingShots)
  row("15 m: shooter still at release"): pct(m.nearStillHits, m.nearStillShots)
  row("15 m: target moving at release"): pct(m.nearTargetMovingHits, m.nearTargetMovingShots)
  row("15 m: target still at release"): pct(m.nearTargetStillHits, m.nearTargetStillShots)
  for k in 0 ..< 4:
    row("accuracy with windup drift " & DriftLabels[k]): pct(m.driftHits[k], m.driftShots[k])
  row("mean windup drift, units"): mean(m.driftSum, m.acrossShots)
  row("ray within a radius of the target, release origin"): pct(m.acrossRelease55, m.acrossShots)
  row("ray within a radius of the target, order origin"): pct(m.acrossOrder55, m.acrossShots)
  row("mean miss distance at release, units (cap 600)"): mean(m.acrossReleaseSum, m.acrossShots)
  row("mean miss distance from the order spot, units (cap 600)"): mean(m.acrossOrderSum, m.acrossShots)
  row("calm target (under 30 units in 3 ticks): shots"): pct(m.calmShots, m.calmShots + m.slowShots + m.busyShots)
  row("slow target (30-59 units in 3 ticks): shots"): pct(m.slowShots, m.calmShots + m.slowShots + m.busyShots)
  row("calm target: accuracy"): pct(m.calmHits, m.calmShots)
  row("calm dry target: accuracy"): pct(m.calmDryHits, m.calmDryShots)
  row("calm wet target: accuracy"): pct(m.calmWetHits, m.calmWetShots)
  row("slow target: accuracy"): pct(m.slowHits, m.slowShots)
  row("busy target (60+ units in 3 ticks): accuracy"): pct(m.busyHits, m.busyShots)
  row("busy dry target: accuracy"): pct(m.busyDryHits, m.busyDryShots)
  row("busy wet target: accuracy"): pct(m.busyWetHits, m.busyWetShots)
  row("ready gun in contact, target inside 15 m: ticks"): $m.readyTicks
  row("ready: target calm"): pct(m.readyCalmTicks, m.readyTicks)
  row("ready: target slow"): pct(m.readySlowTicks, m.readyTicks)
  row("ready: target calm and wet"): pct(m.readyCalmWetTicks, m.readyTicks)
  row("ready: target busy and wet"): pct(m.readyBusyWetTicks, m.readyTicks)
  row("first 60 s: contact ticks per seat-game"): mean(m.earlyContactTicks, m.seatGames)
  row("first 60 s: windup ticks per seat-game"): mean(m.earlyWindupTicks, m.seatGames)
  row("first 60 s: other standing contact ticks per seat-game"): mean(m.earlyStandingTicks, m.seatGames)
  row("runs of 6+ ticks"): pct(m.longRuns, m.runCount)
  row("plants (windups)"): $m.plants
  row("plants hit by anything"): pct(m.plantsHit, m.plants)
  row("plants hit by a gun"): pct(m.plantsGunHit, m.plants)
  row("damage events per 100 windup ticks"): per100(m.windupHits, m.windupTicks)
  row("damage events per 100 standing contact ticks"): per100(m.standingHits, m.standingTicks)
  row("damage events per 100 moving contact ticks"): per100(m.movingHits, m.movingTicks)
  row("gun hits per 100 windup ticks"): per100(m.windupGunHits, m.windupTicks)
  row("gun hits per 100 standing contact ticks"): per100(m.standingGunHits, m.standingTicks)
  row("gun hits per 100 moving contact ticks"): per100(m.movingGunHits, m.movingTicks)
  row("grenade hits per 100 windup ticks"): per100(m.windupGrenadeHits, m.windupTicks)
  row("grenade hits per 100 standing contact ticks"): per100(m.standingGrenadeHits, m.standingTicks)
  row("grenade hits per 100 moving contact ticks"): per100(m.movingGrenadeHits, m.movingTicks)
  row("spray hits per 100 windup ticks"): per100(m.windupSprayHits, m.windupTicks)
  row("spray hits per 100 standing contact ticks"): per100(m.standingSprayHits, m.standingTicks)
  row("spray hits per 100 moving contact ticks"): per100(m.movingSprayHits, m.movingTicks)
  row("duel (enemy inside 15 m): damage per 100 windup ticks"): per100(m.duelWindupHits, m.duelWindupTicks)
  row("duel: damage per 100 standing ticks"): per100(m.duelStandingHits, m.duelStandingTicks)
  row("duel: damage per 100 moving ticks"): per100(m.duelMovingHits, m.duelMovingTicks)
  row("runs reaching 6 steps"): $m.predictRuns
  row("6-step runs: five-step drift within 28 of 5 x the first step"): pct(m.predictWithin28, m.predictRuns)
  row("6-step runs: five-step drift within 55 of 5 x the first step"): pct(m.predictWithin55, m.predictRuns)
  row("contact ticks"): $m.contactTicks
  row("contact: moving"): pct(m.contactMoving, m.contactTicks)
  row("contact: in water"): pct(m.contactWet, m.contactTicks)
  row("runs per contact second"): mean(m.runCount, m.contactTicks, 24.0)
  row("mean run, ticks"): mean(m.runTicks, m.runCount)
  for k in 0 ..< 5:
    row("runs of " & RunLabels[k] & " ticks"): pct(m.runs[k], m.runCount)
  row("runs ending in a reversal"): pct(m.reversals, m.runCount)
  row("runs ending in a turn"): pct(m.turns, m.runCount)
  row("runs ending in a stop"): pct(m.stops, m.runCount)
  row("reversals per contact second"): mean(m.reversals, m.contactTicks, 24.0)
  row("within-run steps within 4 units of the last"): pct(m.stepPairsWithin4, m.stepPairs)
  row("within-run steps within 10 units of the last"): pct(m.stepPairsWithin10, m.stepPairs)
  row("gun kills"): $m.gunKills
  row("gun shots per gun kill"): mean(m.shots, m.gunKills)
  row("gun hits per gun kill"): mean(m.hits, m.gunKills)
  row("gun shots at the victim per kill (any weapon)"): mean(m.killShotsAt, m.kills)
  row("gun hits on the victim per kill (any weapon)"): mean(m.killHitsAt, m.kills)
  row("own gun deaths"): $m.gunDeaths
  row("gun death: seconds from the engagement's first gun hit"): mean(m.gunDeathTicks, m.gunDeaths, 1.0 / 24.0)

main()
