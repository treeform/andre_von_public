## Paintbot PW gun interface audit: the policy's gun orders against the engine's windup, cooldown,
## aim lock and ray rules, read from the recorded per-tick commands.
##
##   nim c -d:release -d:ssl -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw-0124/examples/paintbot --path:$HOME/p/paintbot-pw-0124/src \
##     --path:tools -o:tools/pw_gunlock tools/pw_gunlock.nim
##   tools/pw_gunlock <pw_fast dirs or replays>...
##
## Re-simulates every replay. For each gun order (a windup start) it records the gap since the
## cog's previous order, how many ticks the gun had already been ready with an enemy in reach,
## the order's aim against the policy's own lead formula (unled, led five steps, other), whether
## the shooter held a grenade with the target inside the grenade window (the policy's grenade
## lookAt then overwrites the gun aim), the target's travel over the windup in steps, the ray
## from the order position against the target at release for leads 4 to 7 (no jitter), whether
## the target was behind cover or out of view at release, and the hit. Ready-but-silent ticks
## are attributed to the one-tick cooldown slack, the hit cap on a slowed cooldown, a fresh
## sighting, or other causes. Shoot orders sent during a cooldown or windup are counted too.

import
  std/[algorithm, math, os, sequtils, strformat, strutils, tables],
  game, sim, topography, fastdirs

const
  Windup = 5
  Reach = 2133
  NadeNear = 160000'i64
  NadeFar = 1562500'i64

type
  Audit = object
    seatGames: int
    orders, sniperOrders, hits: int
    gap: Table[int, int]
    gapSlow: Table[int, int]
    gapSniper: Table[int, int]
    readyBefore: array[5, int]
    readySilent, silentOffByOne, silentHitCap, silentFresh, silentOther: int
    silentBlocked, silentShield: int
    led5Window, led5WindowHits, led5WindowMover, led5WindowMoverHits: int
    along: array[9, int]
    coverLed, coverUnled: int
    sprayDamage: int
    ordersFromRivalAim: int
    atDisguisedMate, atDisguisedMateLed: int
    friendlyGunHits, friendlyGunHitsDisguised: int
    disguiseTicks, aliveTicks, disguisePickups: int
    silentOnlyDisguised: int
    wastedOrders, wastedCooldown, wastedWindup: int
    hitCapEvents, hitCapTicksSaved: int
    unled, led5, ledGap, other: int
    unledHits, led5Hits, ledGapHits, otherHits: int
    unledMoving, unledMovingHits, unledMovingTwo, unledMovingTwoHits: int
    clobbered, clobberedHits, clobberedMoving, clobberedMovingHits: int
    nadeHeld, nadeHeldWindow: int
    travelSteps: float
    travelCount: int
    constantRuns: int
    within: array[4, int]
    withinConstant: array[4, int]
    coverAtRelease, coverAtReleaseHits, unseenAtRelease, unseenAtReleaseHits: int
    released: int
    sprayBursts: int
    sprayGap: Table[int, int]
    spraySilent: int
    plantMoved: int

var
  events: seq[DamageEvent]
  dumpOther = 12
  dumpSilent = 12

proc bump(t: var Table[int, int], k: int) =
  ## Adds one to a histogram bucket.
  t[k] = t.getOrDefault(k) + 1

proc groupName(ours: bool): string =
  ## Group label for a side.
  if ours: "ours" else: "rival"

proc across(origin, aim, target: Point): float =
  ## Perpendicular distance from the target to the ray from origin through aim, or a large number
  ## when the target is behind the origin.
  let
    dx = float(aim.x - origin.x)
    dz = float(aim.z - origin.z)
    len = sqrt(dx * dx + dz * dz)
  if len < 1:
    return 100000
  let
    ux = dx / len
    uz = dz / len
    tx = float(target.x - origin.x)
    tz = float(target.z - origin.z)
    along = tx * ux + tz * uz
  if along <= 0:
    return 100000
  abs(tx * uz - tz * ux)

proc analyze(path: string, roster: seq[string], audits: var Table[string, Audit]) =
  ## Re-simulates one replay and adds its gun orders to the per-group table.
  let recording = loadRecording(path)
  var
    w = newWorld(recording.seed, recording.endTick)
    lastOrder: array[MaxSeats, int]
    lastOrderSlow: array[MaxSeats, bool]
    lastOrderCooldown: array[MaxSeats, int]
    readyRun: array[MaxSeats, int]
    lastSpray: array[MaxSeats, int]
    # The shooter's view of each enemy: last tick seen and position then (the policy's lastSeen
    # and oldX/oldY), plus the two steps before that for the run test.
    seenTick: array[MaxSeats, array[MaxSeats, int]]
    seenPos: array[MaxSeats, array[MaxSeats, Point]]
    prevStep: array[MaxSeats, array[MaxSeats, Point]]
    # Pending orders: tick, shooter, target, aim, lead class, order position, target position and
    # step at the order.
    pending: seq[tuple[tick, shooter, target: int, aim, origin, tpos, step: Point,
      cls: int, clob: bool, moving, movingTwo, near: bool]]
    lastSeenAny: array[MaxSeats, int]
    sightStart: array[MaxSeats, array[MaxSeats, int]]
    uniformsBefore: seq[bool]
    seenTickMate: array[MaxSeats, array[MaxSeats, int]]
    seenPosMate: array[MaxSeats, array[MaxSeats, Point]]
  let
    oursEven = roster[0].startsWith("ours")
  for i in 0 ..< MaxSeats:
    lastOrder[i] = -1000
    lastSpray[i] = -1000
    lastSeenAny[i] = -1000
    for j in 0 ..< MaxSeats:
      seenTick[i][j] = -1000
  damageLog = addr events
  defer:
    damageLog = nil
  for side in 0 .. 1:
    let ours = (side == 0) == oursEven
    var a = addr audits.mgetOrPut(groupName(ours), Audit())
    a.seatGames += Seats div 2
  for frame in recording.frames:
    let
      before = w.cogs
      beforeEq = w.equipment
      tick = w.tick.int
    events.setLen(0)
    # Visibility on the pre-step world, as the policies saw it this tick.
    var vis: array[MaxSeats, array[MaxSeats, bool]]
    for i in 0 ..< Seats:
      if before[i].hp <= 0:
        continue
      for j in 0 ..< Seats:
        if j != i and team(j) != team(i) and before[j].hp > 0 and w.visible(i, j):
          vis[i][j] = true
          lastSeenAny[i] = tick
    # Nearest visible enemy in gun reach per seat, and whether every visible enemy wears a
    # uniform (the policy then sees no enemy at all).
    var
      nearest: array[MaxSeats, int]
      allDisguised: array[MaxSeats, bool]
    for i in 0 ..< Seats:
      nearest[i] = -1
      allDisguised[i] = true
      var best = int64(Reach) * Reach
      for j in 0 ..< Seats:
        if vis[i][j]:
          if not w.uniforms[j]:
            allDisguised[i] = false
          let d = distance2(before[i].pos, before[j].pos)
          if d <= best:
            best = d
            nearest[i] = j
      if before[i].hp > 0:
        let a = addr audits.mgetOrPut(groupName((team(i) == 0) == oursEven), Audit())
        inc a.aliveTicks
        if w.uniforms[i]:
          inc a.disguiseTicks
    # Ready-but-silent ticks and wasted orders, judged before the step.
    for i in 0 ..< Seats:
      if before[i].hp <= 0:
        continue
      let
        ours = (team(i) == 0) == oursEven
        a = addr audits.mgetOrPut(groupName(ours), Audit())
        cmd = frame.commands[i]
        gun = not beforeEq[i].sprayCan and not w.sniper[i] and not w.disarmed(i)
      # Did the hit cap release a slowed cooldown? The cooldown dropped by more than one tick.
      if lastOrderCooldown[i] > 0 and before[i].cooldown.int < lastOrderCooldown[i] - 1:
        inc a.hitCapEvents
        a.hitCapTicksSaved += lastOrderCooldown[i] - 1 - before[i].cooldown.int
      lastOrderCooldown[i] = before[i].cooldown.int
      # The engine decrements the cooldown before it reads the shoot order, so a pre-step
      # cooldown of 1 still fires this tick.
      if gun and before[i].cooldown <= 1 and beforeEq[i].windup == 0 and nearest[i] >= 0:
        if cmd.shoot:
          readyRun[i] = 0
        else:
          inc a.readySilent
          inc readyRun[i]
          if tick == lastOrder[i] + 24 or (lastOrderSlow[i] and tick == lastOrder[i] + 72):
            inc a.silentOffByOne
          elif lastOrderSlow[i] and tick < lastOrder[i] + 72:
            inc a.silentHitCap
          elif tick < 30:
            inc a.silentShield
          elif tick - seenTick[i][nearest[i]] > 1 or
              (seenTick[i][nearest[i]] == tick - 1 and tick - sightStart[i][nearest[i]] <= 1):
            inc a.silentFresh
          elif allDisguised[i]:
            inc a.silentOnlyDisguised
          else:
            # A teammate within 95 units of the line to the nearest enemy, as the policy tests.
            var blocked = false
            let
              sx = float(before[nearest[i]].pos.x - before[i].pos.x)
              sz = float(before[nearest[i]].pos.z - before[i].pos.z)
              len = sqrt(sx * sx + sz * sz)
            if len > 0:
              for k in 0 ..< Seats:
                if k != i and team(k) == team(i) and before[k].hp > 0 and w.visible(i, k):
                  let
                    ox = float(before[k].pos.x - before[i].pos.x)
                    oz = float(before[k].pos.z - before[i].pos.z)
                    along = (ox * sx + oz * sz) / len
                    acr = abs(ox * sz - oz * sx) / len
                  if along > 0 and along < len and acr < 95:
                    blocked = true
            if blocked:
              inc a.silentBlocked
            else:
              inc a.silentOther
              if ours and dumpSilent > 0:
                dec dumpSilent
                let j = nearest[i]
                stderr.writeLine(&"silent tick {tick} seat {i} pos ({before[i].pos.x},{before[i].pos.z}) " &
                  &"cooldown {before[i].cooldown} sinceOrder {tick - lastOrder[i]} nearest {j} at " &
                  &"({before[j].pos.x},{before[j].pos.z}) d {int(sqrt(float(distance2(before[i].pos, before[j].pos))))} " &
                  &"seenGap {tick - seenTick[i][j]} sightAge {tick - sightStart[i][j]} " &
                  &"trench {w.trenchAt(before[i].pos)} walk {cmd.walk} goal ({cmd.goal.x},{cmd.goal.z}) " &
                  &"aim ({cmd.aim.x},{cmd.aim.z}) nade {beforeEq[i].grenade} charge {beforeEq[i].charge} " &
                  &"uniforms {toSeq(0 ..< Seats).filterIt(w.uniforms[it])}")
      elif gun and cmd.shoot and (before[i].cooldown > 1 or beforeEq[i].windup > 0):
        inc a.wastedOrders
        if beforeEq[i].windup > 0:
          inc a.wastedWindup
        else:
          inc a.wastedCooldown
      if beforeEq[i].windup > 0 and cmd.walk and cmd.goal != before[i].pos:
        inc a.plantMoved
      if beforeEq[i].sprayCan and beforeEq[i].sprayCooldown == 0 and not cmd.shoot and
          nearest[i] >= 0 and distance2(before[i].pos, before[nearest[i]].pos) <= 640000:
        inc a.spraySilent
    w.step(frame.commands, replayRulesVersion)
    var gunHitBy: array[MaxSeats, bool]
    for i in 0 ..< Seats:
      if before[i].hp > 0 and w.uniforms[i] and
          not (i < uniformsBefore.len and uniformsBefore[i]):
        inc audits.mgetOrPut(groupName((team(i) == 0) == oursEven), Audit()).disguisePickups
    uniformsBefore = w.uniforms
    for e in events:
      if e.attacker < 0 or e.attacker == e.victim:
        continue
      if team(e.attacker.int) == team(e.victim.int):
        if e.weapon == 1:
          let a = addr audits.mgetOrPut(groupName((team(e.attacker.int) == 0) == oursEven), Audit())
          inc a.friendlyGunHits
          if w.uniforms[e.victim]:
            inc a.friendlyGunHitsDisguised
        continue
      if e.weapon == 1:
        gunHitBy[e.attacker] = true
      if e.weapon == 3:
        let ours = (team(e.attacker.int) == 0) == oursEven
        inc audits.mgetOrPut(groupName(ours), Audit()).sprayDamage
    # Releases this step: the pending orders from five ticks ago.
    var keep: typeof(pending)
    for p in pending:
      if p.tick + Windup != tick:
        keep.add p
        continue
      let
        ours = (team(p.shooter) == 0) == oursEven
        a = addr audits.mgetOrPut(groupName(ours), Audit())
        hit = gunHitBy[p.shooter]
      if w.cogs[p.shooter].hp <= 0:
        continue
      inc a.released
      if hit:
        inc a.hits
      case p.cls
      of 0:
        inc a.unled
        if hit: inc a.unledHits
        if p.moving:
          inc a.unledMoving
          if hit: inc a.unledMovingHits
        if p.movingTwo:
          inc a.unledMovingTwo
          if hit: inc a.unledMovingTwoHits
      of 1:
        inc a.led5
        if hit: inc a.led5Hits
        if p.near:
          inc a.led5Window
          if hit: inc a.led5WindowHits
          if p.movingTwo:
            inc a.led5WindowMover
            if hit: inc a.led5WindowMoverHits
      of 2:
        inc a.ledGap
        if hit: inc a.ledGapHits
      else:
        inc a.other
        if hit: inc a.otherHits
      if p.clob:
        inc a.clobbered
        if hit: inc a.clobberedHits
        if p.movingTwo:
          inc a.clobberedMoving
          if hit: inc a.clobberedMovingHits
      if p.target >= 0 and w.cogs[p.target].hp > 0:
        let tnow = w.cogs[p.target].pos
        if not w.lineClear(p.origin, tnow):
          inc a.coverAtRelease
          if hit: inc a.coverAtReleaseHits
          if p.cls == 1: inc a.coverLed
          if p.cls == 0: inc a.coverUnled
        elif not w.visible(p.shooter, p.target):
          inc a.unseenAtRelease
          if hit: inc a.unseenAtReleaseHits
        # Travel over the windup in units of the step at the order, along that step.
        let s2 = int64(p.step.x) * p.step.x + int64(p.step.z) * p.step.z
        if s2 > 64 and s2 < 3600:
          let
            tx = float(tnow.x - p.tpos.x)
            tz = float(tnow.z - p.tpos.z)
            along = (tx * float(p.step.x) + tz * float(p.step.z)) / float(s2)
          a.travelSteps += along
          inc a.travelCount
          inc a.along[clamp(int(floor(along)) + 1, 0, 8)]
          let constant = abs(along - 6.0) < 0.5 and
            abs(tx * float(p.step.z) - tz * float(p.step.x)) / sqrt(float(s2)) < 30
          if constant:
            inc a.constantRuns
          for k in 0 .. 3:
            let
              lead = 4 + k
              aim = Point(x: int32(p.tpos.x + p.step.x * lead), z: int32(p.tpos.z + p.step.z * lead))
            if across(p.origin, aim, tnow) <= float(Radius):
              inc a.within[k]
              if constant:
                inc a.withinConstant[k]
    pending = keep
    # Orders this step: windup starts, and spray bursts.
    for i in 0 ..< Seats:
      if before[i].hp <= 0:
        continue
      let
        ours = (team(i) == 0) == oursEven
        a = addr audits.mgetOrPut(groupName(ours), Audit())
        cmd = frame.commands[i]
      if beforeEq[i].sprayCan and beforeEq[i].burst == 0 and w.equipment[i].burst > 0:
        inc a.sprayBursts
        if lastSpray[i] > -1000:
          a.sprayGap.bump(tick - lastSpray[i])
        lastSpray[i] = tick
      if beforeEq[i].windup == 0 and w.equipment[i].windup == Windup:
        if w.sniper[i]:
          inc a.sniperOrders
          if lastOrder[i] > -1000:
            a.gapSniper.bump(tick - lastOrder[i])
        else:
          inc a.orders
          if lastOrder[i] > -1000:
            if lastOrderSlow[i]:
              a.gapSlow.bump(tick - lastOrder[i])
            else:
              a.gap.bump(tick - lastOrder[i])
          inc a.readyBefore[min(readyRun[i], 4)]
        lastOrder[i] = tick
        lastOrderSlow[i] = w.cogs[i].cooldown > 30
        readyRun[i] = 0
        if not w.sniper[i]:
          # Match the aim to the policy's formulas over the visible enemies.
          var
            target = -1
            cls = 3
            bestErr = int64.high
            tstep: Point
            tpos: Point
          for j in 0 ..< Seats:
            if not vis[i][j]:
              continue
            let
              pos = before[j].pos
              gap = tick - seenTick[i][j]
            var step: Point
            if gap >= 1 and gap <= 6 and seenTick[i][j] > -1000:
              step = Point(x: int32((pos.x - seenPos[i][j].x) div int32(gap)),
                z: int32((pos.z - seenPos[i][j].z) div int32(gap)))
            let
              e0 = distance2(cmd.aim, pos)
              led = Point(x: pos.x + step.x * 5, z: pos.z + step.z * 5)
              e1 = distance2(cmd.aim, led)
            if e0 <= 4 and e0 < bestErr:
              bestErr = e0; target = j; cls = 0; tstep = step; tpos = pos
            if e1 <= 4 and e1 < bestErr and (step.x != 0 or step.z != 0):
              bestErr = e1; target = j; cls = (if gap == 1: 1 else: 2); tstep = step; tpos = pos
          if target < 0:
            # Nearest enemy to the aim point.
            var bestD = int64.high
            for j in 0 ..< Seats:
              if vis[i][j]:
                let d = distance2(cmd.aim, before[j].pos)
                if d < bestD:
                  bestD = d; target = j; tpos = before[j].pos
                  let gap = tick - seenTick[i][j]
                  if gap >= 1 and gap <= 6 and seenTick[i][j] > -1000:
                    tstep = Point(x: int32((tpos.x - seenPos[i][j].x) div int32(gap)),
                      z: int32((tpos.z - seenPos[i][j].z) div int32(gap)))
          var clob = false
          var moving = false
          var movingTwo = false
          var near = false
          if target >= 0:
            let
              d2 = distance2(before[i].pos, tpos)
              s2 = int64(tstep.x) * tstep.x + int64(tstep.z) * tstep.z
              p2 = int64(prevStep[i][target].x) * prevStep[i][target].x +
                int64(prevStep[i][target].z) * prevStep[i][target].z
            moving = s2 > 64 and s2 < 3600 and tick - seenTick[i][target] == 1
            movingTwo = moving and p2 > 64
            near = d2 > NadeNear and d2 < NadeFar
            if beforeEq[i].grenade:
              inc a.nadeHeld
              if near:
                inc a.nadeHeldWindow
                clob = cls == 0
          # Orders aimed at a disguised teammate (seen under an enemy identity).
          for j in 0 ..< Seats:
            if j != i and team(j) == team(i) and before[j].hp > 0 and w.uniforms[j] and
                w.visible(i, j):
              let step = Point(x: before[j].pos.x - seenPosMate[i][j].x,
                z: before[j].pos.z - seenPosMate[i][j].z)
              if distance2(cmd.aim, before[j].pos) <= 4:
                inc a.atDisguisedMate
                break
              if seenTickMate[i][j] == tick - 1 and distance2(cmd.aim,
                  Point(x: before[j].pos.x + step.x * 5, z: before[j].pos.z + step.z * 5)) <= 4:
                inc a.atDisguisedMate
                inc a.atDisguisedMateLed
                break
          if cls == 3 and ours and dumpOther > 0:
            dec dumpOther
            var foes: seq[string]
            for j in 0 ..< Seats:
              if vis[i][j]:
                let gap = tick - seenTick[i][j]
                foes.add(&"{j}@({before[j].pos.x},{before[j].pos.z}) gap {gap} " &
                  &"old ({seenPos[i][j].x},{seenPos[i][j].z}) hp {before[j].hp} uni {w.uniforms[j]}")
            var mates: seq[string]
            for j in 0 ..< Seats:
              if j != i and team(j) == team(i) and before[j].hp > 0 and w.uniforms[j]:
                mates.add(&"{j}@({before[j].pos.x},{before[j].pos.z})")
            stderr.writeLine(&"other aim tick {tick} seat {i} pos ({before[i].pos.x},{before[i].pos.z}) " &
              &"aim ({cmd.aim.x},{cmd.aim.z}) walk {cmd.walk} goal ({cmd.goal.x},{cmd.goal.z}) " &
              &"nade {beforeEq[i].grenade} charge {beforeEq[i].charge} foes [{foes.join(\"; \")}] " &
              &"disguised mates [{mates.join(\"; \")}]")
          pending.add((tick, i, target, cmd.aim, w.cogs[i].pos, tpos, tstep, cls, clob,
            moving, movingTwo, near))
    # The shooter's memory of each enemy, updated as the policy does at the end of its tick.
    for i in 0 ..< Seats:
      for j in 0 ..< Seats:
        if j != i and team(j) == team(i) and before[i].hp > 0 and before[j].hp > 0 and
            w.visible(i, j):
          seenTickMate[i][j] = tick
          seenPosMate[i][j] = before[j].pos
        if vis[i][j]:
          if seenTick[i][j] == tick - 1:
            prevStep[i][j] = Point(x: before[j].pos.x - seenPos[i][j].x,
              z: before[j].pos.z - seenPos[i][j].z)
          else:
            prevStep[i][j] = Point()
            sightStart[i][j] = tick
          seenTick[i][j] = tick
          seenPos[i][j] = before[j].pos

proc pct(a, b: int): string =
  ## Percentage string with the count, a dash for no observations.
  if b == 0:
    "-"
  else:
    formatFloat(100.0 * a.float / b.float, ffDecimal, 1) & &"% ({b})"

proc hist(t: Table[int, int], keys: openArray[int]): string =
  ## Selected histogram buckets as "k:n" pairs, with the rest pooled.
  var total = 0
  for v in t.values:
    total += v
  var parts: seq[string]
  var shown = 0
  for k in keys:
    let n = t.getOrDefault(k)
    shown += n
    parts.add &"{k}:{n}"
  parts.add &"rest:{total - shown}"
  parts.join(" ")

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
  var audits = initTable[string, Audit]()
  for path in replays:
    let raw = fastRoster(path, true)
    if raw.len != 16:
      continue
    var roster: seq[string]
    for slot in 0 ..< 16:
      roster.add(if raw[slot].endsWith(" win") or raw[slot].endsWith(" loss"): "ours" else: "rival")
    analyze(path, roster, audits)
  var order = toSeq(audits.keys)
  order.sort()
  echo "| stat | " & order.join(" | ") & " |"
  echo "|---|" & order.mapIt("---:").join("|") & "|"
  template row(label: string, body: untyped) =
    var cells: seq[string]
    for name in order:
      let a {.inject.} = audits[name]
      cells.add body
    echo "| " & label & " | " & cells.join(" | ") & " |"
  row("seat-games"): $a.seatGames
  row("gun orders (windup starts)"): $a.orders
  row("sniper orders"): $a.sniperOrders
  row("gun accuracy (released, shooter alive)"): pct(a.hits, a.released)
  row("gap since previous order, plain cooldown"): hist(a.gap, [24, 25, 26, 27, 28, 29, 30])
  row("gap since previous order, slowed cooldown"): hist(a.gapSlow, [72, 73, 74, 75, 76])
  row("gap since previous order, sniper"): hist(a.gapSniper, [96, 97, 98, 99, 100])
  row("ready ticks with an enemy in reach before the order: 0"): pct(a.readyBefore[0], a.orders)
  row("ready ticks before the order: 1"): pct(a.readyBefore[1], a.orders)
  row("ready ticks before the order: 2"): pct(a.readyBefore[2], a.orders)
  row("ready ticks before the order: 3"): pct(a.readyBefore[3], a.orders)
  row("ready ticks before the order: 4+"): pct(a.readyBefore[4], a.orders)
  row("ready-but-silent ticks (gun ready, enemy in reach, no shoot order)"): $a.readySilent
  row("silent: exactly one tick after the engine cooldown ended"): pct(a.silentOffByOne, a.readySilent)
  row("silent: slowed cooldown already capped by a hit"): pct(a.silentHitCap, a.readySilent)
  row("silent: opening shield (tick under 30)"): pct(a.silentShield, a.readySilent)
  row("silent: sighting of the nearest enemy began within 2 ticks (wait)"): pct(a.silentFresh, a.readySilent)
  row("silent: every visible enemy wears a uniform (policy sees none)"): pct(a.silentOnlyDisguised, a.readySilent)
  row("silent: teammate within 95 of the line"): pct(a.silentBlocked, a.readySilent)
  row("silent: other"): pct(a.silentOther, a.readySilent)
  row("hit-cap events (slowed cooldown cut by a hit)"): $a.hitCapEvents
  row("hit-cap ticks released by the engine"): $a.hitCapTicksSaved
  row("shoot orders sent while cooling or winding up"): $a.wastedOrders
  row("of which during a cooldown"): $a.wastedCooldown
  row("of which during a windup"): $a.wastedWindup
  row("walk orders away from the spot during a windup"): $a.plantMoved
  row("aim = target position (unled)"): pct(a.unled, a.released)
  row("unled accuracy"): pct(a.unledHits, a.unled)
  row("unled at a target that moved last tick"): pct(a.unledMoving, a.unled)
  row("unled at a moving target: accuracy"): pct(a.unledMovingHits, a.unledMoving)
  row("unled at a target moving two ticks running (lead rule due)"): pct(a.unledMovingTwo, a.unled)
  row("unled, two-tick mover: accuracy"): pct(a.unledMovingTwoHits, a.unledMovingTwo)
  row("aim = target + 5 x step (led, gap 1)"): pct(a.led5, a.released)
  row("led accuracy"): pct(a.led5Hits, a.led5)
  row("aim = target + 5 x step across a sight gap"): pct(a.ledGap, a.released)
  row("led across a gap: accuracy"): pct(a.ledGapHits, a.ledGap)
  row("aim matches neither formula"): pct(a.other, a.released)
  row("other aim: accuracy"): pct(a.otherHits, a.other)
  row("orders aimed at a disguised teammate (seen as an enemy)"): pct(a.atDisguisedMate, a.orders)
  row("of which led"): $a.atDisguisedMateLed
  row("friendly gun hits"): $a.friendlyGunHits
  row("friendly gun hits on a disguised teammate"): $a.friendlyGunHitsDisguised
  row("uniform pickups"): $a.disguisePickups
  row("alive ticks spent disguised"): pct(a.disguiseTicks, a.aliveTicks)
  row("orders with a grenade held"): pct(a.nadeHeld, a.orders)
  row("orders with a grenade held and the target in the 4 to 12.5 m window"): pct(a.nadeHeldWindow, a.orders)
  row("of those, aim is the unled target (grenade lookAt overwrote the gun aim)"): pct(a.clobbered, a.nadeHeldWindow)
  row("clobbered: accuracy"): pct(a.clobberedHits, a.clobbered)
  row("clobbered at a two-tick mover (a lead was due)"): $a.clobberedMoving
  row("clobbered two-tick mover: accuracy"): pct(a.clobberedMovingHits, a.clobberedMoving)
  row("led shots with the target in the 4 to 12.5 m window: accuracy"): pct(a.led5WindowHits, a.led5Window)
  row("led, window, two-tick mover: accuracy"): pct(a.led5WindowMoverHits, a.led5WindowMover)
  row("travel histogram (steps: <0, 0-1, 1-2, 2-3, 3-4, 4-5, 5-6, 6-7, 7+)"): toSeq(a.along).mapIt($it).join(" ")
  row("target travel over the windup, in steps at the order (mean)"): formatFloat(a.travelSteps / max(1, a.travelCount).float, ffDecimal, 2)
  row("moving targets that kept a constant step for all six moves"): pct(a.constantRuns, a.travelCount)
  for k in 0 .. 3:
    row("ray within a radius at release with lead " & $(4 + k) & " (no jitter), moving targets"): pct(a.within[k], a.travelCount)
  for k in 0 .. 3:
    row("same, constant-step targets, lead " & $(4 + k)): pct(a.withinConstant[k], a.constantRuns)
  row("target behind cover at release (cannot be hit)"): pct(a.coverAtRelease, a.released)
  row("behind cover: hits"): $a.coverAtReleaseHits
  row("behind cover at release: led shots"): $a.coverLed
  row("behind cover at release: unled shots"): $a.coverUnled
  row("target out of view at release (clear line)"): pct(a.unseenAtRelease, a.released)
  row("out of view at release: accuracy"): pct(a.unseenAtReleaseHits, a.unseenAtRelease)
  row("spray bursts"): $a.sprayBursts
  row("gap since previous burst"): hist(a.sprayGap, [13, 14, 15, 25, 26, 27])
  row("spray ready, enemy inside 8 m, no shoot order: ticks"): $a.spraySilent
  row("spray damage events (3 HP each) per burst"): formatFloat(a.sprayDamage.float / max(1, a.sprayBursts).float, ffDecimal, 2)

main()
