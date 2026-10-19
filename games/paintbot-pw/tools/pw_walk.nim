## Paintbot PW walking: the walk goal each seat ordered against the step the engine took.
##
##   nim c -d:release -d:ssl -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw-0124/examples/paintbot --path:$HOME/p/paintbot-pw-0124/src \
##     --path:tools -o:tools/pw_walk tools/pw_walk.nim
##   tools/pw_walk <pw_fast dirs or replays>...
##
## Re-simulates every replay. For every living seat's tick with a walk order the goal is clamped
## as the engine clamps it, the navigator is asked for its waypoint on the pre-step world, and
## the step the engine then took is compared with the ordered direction. Rows per group
## ("ours W/L", "rival W/L"): walk ticks by outcome (a full step on the ordered line, a full step
## off it by cause, a slowed step, standing by cause), the same for in-contact dodge legs (an
## unplanted seat that sees an enemy within gun reach and orders a goal about 112 units off),
## unintended standing runs of 10+ ticks by cause, planted seats that moved, sneak ticks against
## the nearest enemy, and in-contact far goals (the policy's pathing takeover) wet and dry.

import
  std/[algorithm, math, os, sequtils, strformat, strutils, tables],
  game, sim, topography, fastdirs

const
  Still2 = 16'i64
  Full = 24
  OffDegrees = 30.0
  LegLow = 90
  LegHigh = 130
  LongStill = 10
  AvoidTicks = 72
  GunReach = 2133
  HeartFar = 400

type
  Walk = object
    seatGames: int
    aliveTicks: int
    walkTicks: int
    ownSpotTicks: int
    clampMoved: int
    plantTicks, plantMoved: int
    wantTicks: int
    fullOn, fullOff, slow, still: int
    offReroute, offYield, offOther: int
    slowWater, slowSneak, slowCarry, slowTrench, slowRadar, slowOther: int
    stillNavStart, stillNavNear, stillCog, stillWall, stillOther: int
    rerouted: int
    legTicks, legOn, legOff, legSlow, legStill, legReroute, legWet: int
    legOffReroute, legOffYield, legOffOther: int
    legStillCog, legStillWall, legStillNav: int
    contactTicks, contactPlant, contactZero, contactLeg, contactFar: int
    contactFarWet, contactShort, contactWet: int
    stillRuns, stillRunTicks: int
    stillRunsNav, stillRunsCog, stillRunsWall, stillRunsOther: int
    stillRunsSeen, stillRunsGoalBlocked, stillRunsGoalWet, stillRunsLong: int
    avoidRuns: int
    sneakTicks, sneakFoe1000, sneakFoe1800, sneakFoe3500, sneakNoFoe, sneakSeen: int
    sneakMoveDry, sneakMoveWet: int
    crawl, crawlSneakWet: int
    stillNavNear90, stillNavNear200, stillNavNearFar, stillNavNearBlocked: int
    contactFarStall, contactFarCarry, contactFarTrench, contactFarOther: int
    legSlowRadar, legSlowTrench, legSlowAxis, legSlowOther: int
    hitLeg, hitFarDry, hitFarWet, hitPlant, hitZero: int
    tickLeg, tickFarDry, tickFarWet, tickPlant, tickZero: int
    stillRunsCrawl: int
    stillNavNearWet: int
    quietDryTicks, quietDryHits, quietWetTicks, quietWetHits: int
    sneakDryHits, sneakWetHits, sneakDeaths, quietDeaths: int
  Run = object
    len: int
    nav, cog, wall, other, crawl: int
    seen: bool

var events: seq[DamageEvent]

proc wet(p: Point): bool =
  ## Whether a point lies in the lake.
  riverBlend(p.x.int, p.z.int) > 0 and terrainHeight(p.x.int, p.z.int) < RiverWaterHeight

proc groupName(ours: bool, won: bool): string =
  ## Group label for a side and our outcome.
  (if ours: "ours " else: "rival ") & (if won: "W" else: "L")

proc crowded(w: World, p: Point, slot: int): bool =
  ## The engine's occupied test: another living cog within two radii of the point.
  for other in 0 ..< Seats:
    if other != slot and w.cogs[other].hp > 0 and
        distance2(p, w.cogs[other].pos) < (2 * Radius).int64 * (2 * Radius):
      return true
  false

proc degreesOff(a, b: Point): float =
  ## Angle in degrees between two vectors, 180 for a zero vector.
  let
    la = sqrt(float(a.x) * float(a.x) + float(a.z) * float(a.z))
    lb = sqrt(float(b.x) * float(b.x) + float(b.z) * float(b.z))
  if la < 1 or lb < 1:
    return 180.0
  let c = clamp((float(a.x) * float(b.x) + float(a.z) * float(b.z)) / (la * lb), -1.0, 1.0)
  arccos(c) * 180.0 / PI

proc closeRun(m: var Walk, r: var Run, w: World, pos, goal: Point) =
  ## Books a finished standing run of LongStill or more ticks.
  if r.len >= LongStill:
    inc m.stillRuns
    m.stillRunTicks += r.len
    if r.nav >= r.cog and r.nav >= r.wall and r.nav >= r.other:
      inc m.stillRunsNav
    elif r.cog >= r.wall and r.cog >= r.other:
      inc m.stillRunsCog
    elif r.wall >= r.other:
      inc m.stillRunsWall
    else:
      inc m.stillRunsOther
    if r.seen:
      inc m.stillRunsSeen
    if w.blocked(goal):
      inc m.stillRunsGoalBlocked
    if wet(goal):
      inc m.stillRunsGoalWet
    if r.crawl * 2 > r.len:
      inc m.stillRunsCrawl
    if r.len >= AvoidTicks:
      inc m.stillRunsLong
      var near = int64.high
      for h in w.controlHearts:
        near = min(near, distance2(pos, h.pos))
      if near > HeartFar.int64 * HeartFar:
        inc m.avoidRuns
  r = Run()

proc analyze(path: string, roster: seq[string], walks: var Table[string, Walk]) =
  ## Re-simulates one replay and adds its walking numbers to the per-group table.
  let recording = loadRecording(path)
  var
    w = newWorld(recording.seed, recording.endTick)
    runs: array[MaxSeats, Run]
    stallish: array[MaxSeats, int]
    pathStart: array[MaxSeats, int]
  for i in 0 ..< MaxSeats:
    pathStart[i] = -1000
  damageLog = addr events
  defer:
    damageLog = nil
  let
    oursEven = roster[0].startsWith("ours")
    won = roster[0].endsWith("W")
  for side in 0 .. 1:
    let ours = (side == 0) == oursEven
    var m = addr walks.mgetOrPut(groupName(ours, won), Walk())
    m.seatGames += Seats div 2
  for frame in recording.frames:
    let
      before = w.cogs
      beforeEq = w.equipment
    var
      seen: array[MaxSeats, bool]
      nearFoe: array[MaxSeats, int64]
      goalC: array[MaxSeats, Point]
      dest: array[MaxSeats, Point]
      speed: array[MaxSeats, int]
      want: array[MaxSeats, bool]
      axisCog: array[MaxSeats, bool]
      axisWall: array[MaxSeats, bool]
      bothBlocked: array[MaxSeats, bool]
    events.setLen(0)
    for i in 0 ..< Seats:
      if before[i].hp <= 0:
        continue
      nearFoe[i] = int64.high
      for j in 0 ..< Seats:
        if team(j) != team(i) and before[j].hp > 0:
          let d = distance2(before[i].pos, before[j].pos)
          nearFoe[i] = min(nearFoe[i], d)
          if d <= GunReach.int64 * GunReach and w.visible(i, j):
            seen[i] = true
      let cmd = frame.commands[i]
      if not cmd.walk:
        continue
      goalC[i] = Point(x: clamp(cmd.goal.x, (minX() + 100).int32, (maxX() - 100).int32),
        z: clamp(cmd.goal.z, (minZ() + 100).int32, (maxZ() - 100).int32))
      var s = if before[i].carrying: MoveSpeed * 7 div 10 else: MoveSpeed
      if w.hasRadar(i):
        s = s * RadarSpeedPercent div 100
      if cmd.sneak:
        s = s div 2
      if wet(before[i].pos):
        s = s div 4
      speed[i] = s
      want[i] = distance2(before[i].pos, goalC[i]) > s.int64 * s
      if want[i]:
        dest[i] = w.waypointFor(i, before[i].pos, goalC[i])
        # The engine's two axis moves, judged on the pre-step positions.
        let v = direction(before[i].pos, dest[i], s)
        var p = before[i].pos
        p.x += v.x
        let
          wall1 = w.blocked(p) or (distance2(before[i].pos, p) < 10000 and
            not w.traversable(before[i].pos, p))
          cog1 = not wall1 and w.crowded(p, i)
        var q = if wall1 or cog1: before[i].pos else: p
        q.z += v.z
        let
          wall2 = w.blocked(q) or (distance2(before[i].pos, q) < 10000 and
            not w.traversable(before[i].pos, q))
          cog2 = not wall2 and w.crowded(q, i)
        axisCog[i] = cog1 or cog2
        axisWall[i] = wall1 or wall2
        bothBlocked[i] = (wall1 or cog1) and (wall2 or cog2)
    w.step(frame.commands, replayRulesVersion)
    let tick = w.tick.int
    var hurt: array[MaxSeats, int]
    for e in events:
      if e.health <= 0 or e.attacker < 0 or e.attacker == e.victim:
        continue
      if team(e.attacker.int) == team(e.victim.int):
        continue
      inc hurt[e.victim]
    for i in 0 ..< Seats:
      if before[i].hp <= 0:
        continue
      let
        ours = (team(i) == 0) == oursEven
        m = addr walks.mgetOrPut(groupName(ours, won), Walk())
        cmd = frame.commands[i]
        stepV = point(w.cogs[i].pos.x.int - before[i].pos.x.int,
          w.cogs[i].pos.z.int - before[i].pos.z.int)
        step2 = distance2(before[i].pos, w.cogs[i].pos)
        stepLen = sqrt(float(step2))
        moved = step2 > Still2
        planted = beforeEq[i].windup > 0
      inc m.aliveTicks
      if planted:
        inc m.plantTicks
        if moved:
          inc m.plantMoved
      if cmd.sneak:
        inc m.sneakTicks
        if w.cogs[i].hp <= 0:
          inc m.sneakDeaths
        if cmd.walk and want[i]:
          if wet(before[i].pos):
            inc m.sneakMoveWet
            m.sneakWetHits += hurt[i]
          else:
            inc m.sneakMoveDry
            m.sneakDryHits += hurt[i]
        if seen[i]:
          inc m.sneakSeen
        if nearFoe[i] <= 1000'i64 * 1000:
          inc m.sneakFoe1000
        elif nearFoe[i] <= 1800'i64 * 1800:
          inc m.sneakFoe1800
        elif nearFoe[i] <= 3500'i64 * 3500:
          inc m.sneakFoe3500
        else:
          inc m.sneakNoFoe
      elif not seen[i] and cmd.walk and want[i]:
        # Walking out of contact without sneaking: the comparison for the sneak rows.
        if w.cogs[i].hp <= 0:
          inc m.quietDeaths
        if wet(before[i].pos):
          inc m.quietWetTicks
          m.quietWetHits += hurt[i]
        else:
          inc m.quietDryTicks
          m.quietDryHits += hurt[i]
      if seen[i]:
        inc m.contactTicks
        if wet(before[i].pos):
          inc m.contactWet
      if not cmd.walk:
        if runs[i].len > 0:
          closeRun(m[], runs[i], w, before[i].pos, goalC[i])
        continue
      inc m.walkTicks
      if cmd.goal == before[i].pos and goalC[i] != before[i].pos:
        inc m.clampMoved
      let goalDist = sqrt(float(distance2(before[i].pos, goalC[i]))).int
      if seen[i]:
        if planted:
          inc m.contactPlant
          inc m.tickPlant
          m.hitPlant += hurt[i]
        elif not want[i]:
          inc m.contactZero
          inc m.tickZero
          m.hitZero += hurt[i]
        elif goalDist >= LegLow and goalDist <= LegHigh:
          inc m.contactLeg
          inc m.tickLeg
          m.hitLeg += hurt[i]
        elif goalDist > LegHigh:
          inc m.contactFar
          if wet(before[i].pos):
            inc m.contactFarWet
            inc m.tickFarWet
            m.hitFarWet += hurt[i]
          else:
            inc m.tickFarDry
            m.hitFarDry += hurt[i]
            if tick - pathStart[i] <= 26:
              inc m.contactFarStall
            elif before[i].carrying:
              inc m.contactFarCarry
            elif w.trenchAt(before[i].pos) >= 0:
              inc m.contactFarTrench
            else:
              inc m.contactFarOther
        else:
          inc m.contactShort
      # The policy's stall detector: three leg ticks in a row with a step under 8 units.
      if seen[i] and not planted and want[i] and goalDist >= LegLow and goalDist <= LegHigh and
          step2 < 64:
        inc stallish[i]
        if stallish[i] >= 3:
          pathStart[i] = tick
          stallish[i] = 0
      else:
        stallish[i] = 0
      if not want[i]:
        inc m.ownSpotTicks
        if runs[i].len > 0:
          closeRun(m[], runs[i], w, before[i].pos, goalC[i])
        continue
      inc m.wantTicks
      let
        rerouted = dest[i] != goalC[i]
        destNear = distance2(before[i].pos, dest[i]) <= speed[i].int64 * speed[i]
        toGoal = point(goalC[i].x.int - before[i].pos.x.int, goalC[i].z.int - before[i].pos.z.int)
        off = degreesOff(stepV, toGoal) > OffDegrees
        leg = seen[i] and not planted and goalDist >= LegLow and goalDist <= LegHigh
      if rerouted:
        inc m.rerouted
      if leg:
        inc m.legTicks
        if rerouted:
          inc m.legReroute
        if wet(before[i].pos):
          inc m.legWet
      var cause = ""
      if stepLen < 4:
        inc m.still
        if step2 > 0:
          inc m.crawl
          inc runs[i].crawl
          if wet(before[i].pos) and cmd.sneak:
            inc m.crawlSneakWet
        if destNear:
          if dest[i] == before[i].pos:
            inc m.stillNavStart
          else:
            inc m.stillNavNear
            if goalDist <= 90:
              inc m.stillNavNear90
            elif goalDist <= 200:
              inc m.stillNavNear200
            else:
              inc m.stillNavNearFar
            if w.blocked(goalC[i]):
              inc m.stillNavNearBlocked
            if wet(goalC[i]):
              inc m.stillNavNearWet
          cause = "nav"
        elif axisCog[i] and not axisWall[i]:
          inc m.stillCog
          cause = "cog"
        elif axisWall[i]:
          inc m.stillWall
          cause = "wall"
        else:
          inc m.stillOther
          cause = "other"
        if leg:
          inc m.legStill
          if cause == "cog":
            inc m.legStillCog
          elif cause == "wall":
            inc m.legStillWall
          elif cause == "nav":
            inc m.legStillNav
        inc runs[i].len
        case cause
        of "nav": inc runs[i].nav
        of "cog": inc runs[i].cog
        of "wall": inc runs[i].wall
        else: inc runs[i].other
        if seen[i]:
          runs[i].seen = true
      else:
        if runs[i].len > 0:
          closeRun(m[], runs[i], w, before[i].pos, goalC[i])
        if stepLen < Full.float:
          inc m.slow
          if leg:
            inc m.legSlow
            if w.hasRadar(i):
              inc m.legSlowRadar
            elif w.trenchAt(before[i].pos) >= 0:
              inc m.legSlowTrench
            elif axisCog[i] or axisWall[i]:
              inc m.legSlowAxis
            else:
              inc m.legSlowOther
          if wet(before[i].pos):
            inc m.slowWater
          elif cmd.sneak:
            inc m.slowSneak
          elif before[i].carrying:
            inc m.slowCarry
          elif w.trenchAt(before[i].pos) >= 0:
            inc m.slowTrench
          elif w.hasRadar(i):
            inc m.slowRadar
          else:
            inc m.slowOther
        elif off:
          inc m.fullOff
          if leg:
            inc m.legOff
          if rerouted:
            inc m.offReroute
            if leg:
              inc m.legOffReroute
          elif bothBlocked[i]:
            inc m.offYield
            if leg:
              inc m.legOffYield
          else:
            inc m.offOther
            if leg:
              inc m.legOffOther
        else:
          inc m.fullOn
          if leg:
            inc m.legOn
    for i in 0 ..< Seats:
      if before[i].hp > 0 and w.cogs[i].hp <= 0 and runs[i].len > 0:
        let
          ours = (team(i) == 0) == oursEven
          m = addr walks.mgetOrPut(groupName(ours, won), Walk())
        closeRun(m[], runs[i], w, before[i].pos, goalC[i])

proc pct(a, b: int): string =
  ## Percentage string with the count, a dash for no observations.
  if b == 0:
    "-"
  else:
    formatFloat(100.0 * a.float / b.float, ffDecimal, 1) & &"% ({b})"

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
  var walks = initTable[string, Walk]()
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
    analyze(path, roster, walks)
  var order = toSeq(walks.keys)
  order.sort()
  echo "| stat | " & order.join(" | ") & " |"
  echo "|---|" & order.mapIt("---:").join("|") & "|"
  template row(label: string, body: untyped) =
    var cells: seq[string]
    for name in order:
      let m {.inject.} = walks[name]
      cells.add body
    echo "| " & label & " | " & cells.join(" | ") & " |"
  row("seat-games"): $m.seatGames
  row("alive ticks"): $m.aliveTicks
  row("walk orders"): pct(m.walkTicks, m.aliveTicks)
  row("walk orders to our own spot (plant or hold)"): pct(m.ownSpotTicks, m.walkTicks)
  row("own-spot orders the edge clamp moved"): pct(m.clampMoved, m.ownSpotTicks)
  row("planted ticks (windup)"): $m.plantTicks
  row("planted ticks that moved 4+ units"): pct(m.plantMoved, m.plantTicks)
  row("walk orders more than a step away"): $m.wantTicks
  row("  navigator rerouted (waypoint != goal)"): pct(m.rerouted, m.wantTicks)
  row("  full step on the ordered line"): pct(m.fullOn, m.wantTicks)
  row("  full step off the line (>30 deg)"): pct(m.fullOff, m.wantTicks)
  row("    off: rerouted"): pct(m.offReroute, m.fullOff)
  row("    off: yielded around a cog"): pct(m.offYield, m.fullOff)
  row("    off: other (one axis blocked)"): pct(m.offOther, m.fullOff)
  row("  slowed step (4-23 units)"): pct(m.slow, m.wantTicks)
  row("    slow: water"): pct(m.slowWater, m.slow)
  row("    slow: sneak"): pct(m.slowSneak, m.slow)
  row("    slow: carrying"): pct(m.slowCarry, m.slow)
  row("    slow: trench"): pct(m.slowTrench, m.slow)
  row("    slow: radar"): pct(m.slowRadar, m.slow)
  row("    slow: other"): pct(m.slowOther, m.slow)
  row("  standing (under 4 units)"): pct(m.still, m.wantTicks)
  row("    still: navigator returned start"): pct(m.stillNavStart, m.still)
  row("    still: navigator waypoint within a step"): pct(m.stillNavNear, m.still)
  row("    still: blocked by a cog"): pct(m.stillCog, m.still)
  row("    still: blocked by wall or slope"): pct(m.stillWall, m.still)
  row("    still: other"): pct(m.stillOther, m.still)
  row("    still ticks that crawled 1-3 units"): pct(m.crawl, m.still)
  row("      crawl: sneaking in water"): pct(m.crawlSneakWet, m.crawl)
  row("    nav-near still: goal within 90"): pct(m.stillNavNear90, m.stillNavNear)
  row("    nav-near still: goal 91-200"): pct(m.stillNavNear200, m.stillNavNear)
  row("    nav-near still: goal over 200"): pct(m.stillNavNearFar, m.stillNavNear)
  row("    nav-near still: goal inside a wall"): pct(m.stillNavNearBlocked, m.stillNavNear)
  row("    nav-near still: goal in the lake"): pct(m.stillNavNearWet, m.stillNavNear)
  row("contact ticks (enemy visible within 21 m)"): $m.contactTicks
  row("  contact: in water"): pct(m.contactWet, m.contactTicks)
  row("  contact walk: planted"): pct(m.contactPlant, m.contactTicks)
  row("  contact walk: own spot, unplanted (zero leg)"): pct(m.contactZero, m.contactTicks)
  row("  contact walk: leg goal 90-130 units"): pct(m.contactLeg, m.contactTicks)
  row("  contact walk: goal under 90 units"): pct(m.contactShort, m.contactTicks)
  row("  contact walk: far goal over 130 units"): pct(m.contactFar, m.contactTicks)
  row("    far goal while in water"): pct(m.contactFarWet, m.contactFar)
  row("    far goal dry: within 26 ticks of a 3-tick leg stall"): pct(m.contactFarStall, m.contactFar - m.contactFarWet)
  row("    far goal dry: carrying"): pct(m.contactFarCarry, m.contactFar - m.contactFarWet)
  row("    far goal dry: in a trench"): pct(m.contactFarTrench, m.contactFar - m.contactFarWet)
  row("    far goal dry: other"): pct(m.contactFarOther, m.contactFar - m.contactFarWet)
  row("  enemy damage events per 100 contact ticks: leg"): mean(m.hitLeg, m.tickLeg, 100.0)
  row("  enemy damage events per 100 contact ticks: far goal dry"): mean(m.hitFarDry, m.tickFarDry, 100.0)
  row("  enemy damage events per 100 contact ticks: far goal wet"): mean(m.hitFarWet, m.tickFarWet, 100.0)
  row("  enemy damage events per 100 contact ticks: planted"): mean(m.hitPlant, m.tickPlant, 100.0)
  row("  enemy damage events per 100 contact ticks: zero leg"): mean(m.hitZero, m.tickZero, 100.0)
  row("dodge leg ticks"): $m.legTicks
  row("  leg: rerouted by the navigator"): pct(m.legReroute, m.legTicks)
  row("  leg: in water"): pct(m.legWet, m.legTicks)
  row("  leg: full step on line"): pct(m.legOn, m.legTicks)
  row("  leg: full step off line"): pct(m.legOff, m.legTicks)
  row("    leg off: rerouted"): pct(m.legOffReroute, m.legOff)
  row("    leg off: yielded around a cog"): pct(m.legOffYield, m.legOff)
  row("    leg off: other"): pct(m.legOffOther, m.legOff)
  row("  leg: slowed"): pct(m.legSlow, m.legTicks)
  row("    leg slow: radar"): pct(m.legSlowRadar, m.legSlow)
  row("    leg slow: trench"): pct(m.legSlowTrench, m.legSlow)
  row("    leg slow: one axis blocked"): pct(m.legSlowAxis, m.legSlow)
  row("    leg slow: other"): pct(m.legSlowOther, m.legSlow)
  row("  leg: standing"): pct(m.legStill, m.legTicks)
  row("    leg still: cog"): pct(m.legStillCog, m.legStill)
  row("    leg still: wall or slope"): pct(m.legStillWall, m.legStill)
  row("    leg still: navigator"): pct(m.legStillNav, m.legStill)
  row("unintended standing runs of 10+ ticks"): $m.stillRuns
  row("  per seat-game"): mean(m.stillRuns, m.seatGames)
  row("  ticks in them per seat-game"): mean(m.stillRunTicks, m.seatGames)
  row("  mean run, ticks"): mean(m.stillRunTicks, m.stillRuns)
  row("  runs: navigator"): pct(m.stillRunsNav, m.stillRuns)
  row("  runs: blocked by a cog"): pct(m.stillRunsCog, m.stillRuns)
  row("  runs: blocked by wall or slope"): pct(m.stillRunsWall, m.stillRuns)
  row("  runs: other"): pct(m.stillRunsOther, m.stillRuns)
  row("  runs that were crawls (1-3 units a tick)"): pct(m.stillRunsCrawl, m.stillRuns)
  row("  runs with an enemy in sight"): pct(m.stillRunsSeen, m.stillRuns)
  row("  runs whose goal is inside a wall"): pct(m.stillRunsGoalBlocked, m.stillRuns)
  row("  runs whose goal is in the lake"): pct(m.stillRunsGoalWet, m.stillRuns)
  row("  runs of 72+ ticks"): $m.stillRunsLong
  row("  runs of 72+ ticks with every heart over 4 m away"): $m.avoidRuns
  row("sneak ticks"): $m.sneakTicks
  row("  sneak per seat-game"): mean(m.sneakTicks, m.seatGames)
  row("  sneak: enemy within 10 m"): pct(m.sneakFoe1000, m.sneakTicks)
  row("  sneak: enemy within 10-18 m"): pct(m.sneakFoe1800, m.sneakTicks)
  row("  sneak: enemy within 18-35 m"): pct(m.sneakFoe3500, m.sneakTicks)
  row("  sneak: no enemy within 35 m"): pct(m.sneakNoFoe, m.sneakTicks)
  row("  sneak: enemy visible within gun reach"): pct(m.sneakSeen, m.sneakTicks)
  row("  sneak while walking on dry ground"): $m.sneakMoveDry
  row("  sneak while wading"): $m.sneakMoveWet
  row("  sneak walking ticks per seat-game"): mean(m.sneakMoveDry + m.sneakMoveWet, m.seatGames)
  row("  enemy damage per 100 ticks: sneak walking dry"): mean(m.sneakDryHits, m.sneakMoveDry, 100.0)
  row("  enemy damage per 100 ticks: sneak wading"): mean(m.sneakWetHits, m.sneakMoveWet, 100.0)
  row("  enemy damage per 100 ticks: walking dry, no sneak, no enemy in sight"): mean(m.quietDryHits, m.quietDryTicks, 100.0)
  row("  enemy damage per 100 ticks: wading, no sneak, no enemy in sight"): mean(m.quietWetHits, m.quietWetTicks, 100.0)
  row("  deaths on a sneak tick"): $m.sneakDeaths
  row("  deaths on a no-sneak out-of-sight walking tick"): $m.quietDeaths

main()
