## Paintbot PW grenades, throw by throw: where the lob lands against where the victim is.
##
##   nim c -d:release -d:ssl -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw-0124/examples/paintbot --path:$HOME/p/paintbot-pw-0124/src \
##     --path:tools -o:tools/pw_lobs tools/pw_lobs.nim
##   tools/pw_lobs <pw_fast dirs or replays>...
##
## Re-simulates every replay. A throw's victim is the living enemy nearest to the landing point
## when the lob leaves (within 15 m). Rows per group ("ours W/L", "rival W/L"): throws, the
## victim's distance from the landing point at release and at the blast (the blast reaches 415
## units), whether the thrower saw an enemy at release, the implied charge against the victim's
## range, how far the victim moved during the ten-tick flight, enemy hits per throw, and the
## counterfactual of a landing point led by the victim's current step times the flight.

import
  std/[algorithm, math, os, sequtils, strformat, strutils, tables],
  game, sim, topography, fastdirs

const
  Reach = 415
  Flight = 10
  FindRadius = 1500

type
  Throw = object
    owner, victim: int
    target, victimAt, start: Point
    step: Point
    landsAt: int
    seen: bool
  Lobs = object
    seatGames: int
    throws, blind, seenNone: int
    inReachAtRelease, inReachAtBlast: int
    walkedOut, walkedIn: int
    hitsEnemy, hitsTeam, throwsHittingEnemy: int
    victimMoved: int
    victimMovedOver300: int
    rangeSum, chargeDistSum: int
    shortCount, longCount, wideCount: int
    ledInReach, ledHalfInReach: int
    bothInReach, onlyLedInReach, onlyPlainInReach: int
    victimWet: int
    seenVictim, shortSeen, shortUnseen, chargeMatched: int
    distReleaseSum, distBlastSum: int

var
  events: seq[DamageEvent]

proc wet(p: Point): bool =
  ## Whether a point lies in the lake.
  riverBlend(p.x.int, p.z.int) > 0 and terrainHeight(p.x.int, p.z.int) < RiverWaterHeight

proc groupName(ours: bool, won: bool): string =
  ## Group label for a side and our outcome.
  (if ours: "ours " else: "rival ") & (if won: "W" else: "L")

proc dist(a, b: Point): int =
  ## Euclidean distance between two points.
  sqrt(float(distance2(a, b))).int

proc analyze(path: string, roster: seq[string], lobs: var Table[string, Lobs]) =
  ## Re-simulates one replay and adds its throws to the per-group table.
  let recording = loadRecording(path)
  var
    w = newWorld(recording.seed, recording.endTick)
    pending: seq[Throw]
  let
    oursEven = roster[0].startsWith("ours")
    won = roster[0].endsWith("W")
  damageLog = addr events
  defer:
    damageLog = nil
  for side in 0 .. 1:
    let ours = (side == 0) == oursEven
    var g = addr lobs.mgetOrPut(groupName(ours, won), Lobs())
    g.seatGames += Seats div 2
  for frame in recording.frames:
    let before = w.cogs
    events.setLen(0)
    w.step(frame.commands, replayRulesVersion)
    let tick = w.tick.int
    # New lobs this step.
    for lob in w.grenades:
      if lob.releasedAt.int != tick - 1 or lob.owner < 0:
        continue
      let
        owner = lob.owner.int
        ours = (team(owner) == 0) == oursEven
        g = addr lobs.mgetOrPut(groupName(ours, won), Lobs())
      inc g.throws
      var
        victim = -1
        best = int64.high
        seenAny = false
      for j in 0 ..< Seats:
        if team(j) == team(owner) or w.cogs[j].hp <= 0:
          continue
        if w.visible(owner, j):
          seenAny = true
        let d = distance2(lob.target, w.cogs[j].pos)
        if d < best:
          best = d
          victim = j
      if not seenAny:
        inc g.seenNone
      if victim < 0 or best > int64(FindRadius) * FindRadius:
        inc g.blind
        continue
      let
        vpos = w.cogs[victim].pos
        d0 = dist(lob.target, vpos)
        range = dist(w.cogs[owner].pos, vpos)
        thrown = dist(lob.start, lob.target)
      g.distReleaseSum += d0
      g.rangeSum += range
      g.chargeDistSum += thrown
      if d0 <= Reach:
        inc g.inReachAtRelease
      else:
        # Along the owner-to-victim line: short, long, or wide.
        let
          ux = float(vpos.x - w.cogs[owner].pos.x)
          uz = float(vpos.z - w.cogs[owner].pos.z)
          len = max(1.0, sqrt(ux * ux + uz * uz))
          tx = float(lob.target.x - w.cogs[owner].pos.x)
          tz = float(lob.target.z - w.cogs[owner].pos.z)
          along = (tx * ux + tz * uz) / len
          across = abs(tx * uz - tz * ux) / len
        if across > float(Reach):
          inc g.wideCount
        elif along < len:
          inc g.shortCount
        else:
          inc g.longCount
      if wet(vpos):
        inc g.victimWet
      if w.visible(owner, victim):
        inc g.seenVictim
      if thrown * 10 >= range * 9:
        inc g.chargeMatched
      if d0 > Reach and thrown < range:
        if w.visible(owner, victim):
          inc g.shortSeen
        else:
          inc g.shortUnseen
      pending.add Throw(owner: owner, victim: victim, target: lob.target, victimAt: vpos,
        start: lob.start, step: point(vpos.x.int - before[victim].pos.x.int,
        vpos.z.int - before[victim].pos.z.int), landsAt: lob.landsAt.int,
        seen: w.visible(owner, victim))
    # Blasts this step: the engine explodes lobs whose landsAt the step's tick reached.
    var kept: seq[Throw]
    for t in pending:
      if t.landsAt > tick - 1:
        kept.add t
        continue
      let
        ours = (team(t.owner) == 0) == oursEven
        g = addr lobs.mgetOrPut(groupName(ours, won), Lobs())
      var enemyHits, teamHits = 0
      for e in events:
        if e.weapon != 2 or e.attacker.int != t.owner or e.victim == e.attacker:
          continue
        if team(e.victim.int) == team(t.owner):
          inc teamHits
        else:
          inc enemyHits
      g.hitsEnemy += enemyHits
      g.hitsTeam += teamHits
      if enemyHits > 0:
        inc g.throwsHittingEnemy
      let
        vpos = w.cogs[t.victim].pos
        d1 = dist(t.target, vpos)
        d0 = dist(t.target, t.victimAt)
        moved = dist(t.victimAt, vpos)
        led = point(t.target.x.int + Flight * t.step.x.int, t.target.z.int + Flight * t.step.z.int)
        half = point(t.target.x.int + Flight * t.step.x.int div 2, t.target.z.int + Flight * t.step.z.int div 2)
        dLed = dist(led, vpos)
        dHalf = dist(half, vpos)
      g.distBlastSum += d1
      g.victimMoved += moved
      if moved > 300:
        inc g.victimMovedOver300
      if d1 <= Reach:
        inc g.inReachAtBlast
      if d0 <= Reach and d1 > Reach:
        inc g.walkedOut
      if d0 > Reach and d1 <= Reach:
        inc g.walkedIn
      if dLed <= Reach:
        inc g.ledInReach
      if dHalf <= Reach:
        inc g.ledHalfInReach
      if dLed <= Reach and d1 <= Reach:
        inc g.bothInReach
      elif dLed <= Reach:
        inc g.onlyLedInReach
      elif d1 <= Reach:
        inc g.onlyPlainInReach
    pending = kept

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
  var lobs = initTable[string, Lobs]()
  for path in replays:
    var raw = fastRoster(path, true)
    if raw.len != 16:
      # Not a pw_fast replay (a headless smoke test): ours on the even seats, counted as a win.
      raw = newSeq[string](16)
      for slot in 0 ..< 16:
        raw[slot] = (if slot mod 2 == 0: "smoke win" else: "rival")
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
    analyze(path, roster, lobs)
  var order = toSeq(lobs.keys)
  order.sort()
  echo "| stat | " & order.join(" | ") & " |"
  echo "|---|" & order.mapIt("---:").join("|") & "|"
  template row(label: string, body: untyped) =
    var cells: seq[string]
    for name in order:
      let g {.inject.} = lobs[name]
      cells.add body
    echo "| " & label & " | " & cells.join(" | ") & " |"
  row("seat-games"): $g.seatGames
  row("throws per seat-game"): mean(g.throws, g.seatGames)
  row("throws with no enemy in the thrower's sight"): pct(g.seenNone, g.throws)
  row("throws with no enemy within 15 m of the landing point"): pct(g.blind, g.throws)
  row("aimed throws"): $(g.throws - g.blind)
  row("aimed: victim visible to the thrower at release"): pct(g.seenVictim, g.throws - g.blind)
  row("aimed: throw length at least 90% of the victim range"): pct(g.chargeMatched, g.throws - g.blind)
  row("aimed: short with the victim visible"): pct(g.shortSeen, g.throws - g.blind)
  row("aimed: short with the victim out of sight"): pct(g.shortUnseen, g.throws - g.blind)
  row("aimed: victim in water"): pct(g.victimWet, g.throws - g.blind)
  row("aimed: victim range at release, m"): mean(g.rangeSum, g.throws - g.blind, 0.01)
  row("aimed: throw length (charge), m"): mean(g.chargeDistSum, g.throws - g.blind, 0.01)
  row("aimed: victim distance from the landing point at release, units"): mean(g.distReleaseSum, g.throws - g.blind)
  row("aimed: victim inside the blast reach at release"): pct(g.inReachAtRelease, g.throws - g.blind)
  row("aimed: landing short of the victim"): pct(g.shortCount, g.throws - g.blind)
  row("aimed: landing long of the victim"): pct(g.longCount, g.throws - g.blind)
  row("aimed: landing wide of the victim"): pct(g.wideCount, g.throws - g.blind)
  row("aimed: victim moved during the flight, units"): mean(g.victimMoved, g.throws - g.blind)
  row("aimed: victim moved over 300 units"): pct(g.victimMovedOver300, g.throws - g.blind)
  row("aimed: victim distance from the landing point at the blast, units"): mean(g.distBlastSum, g.throws - g.blind)
  row("aimed: victim inside the blast reach at the blast"): pct(g.inReachAtBlast, g.throws - g.blind)
  row("aimed: walked out of the blast during the flight"): pct(g.walkedOut, g.throws - g.blind)
  row("aimed: walked into the blast during the flight"): pct(g.walkedIn, g.throws - g.blind)
  row("aimed: led landing (10 x victim step) would reach the victim"): pct(g.ledInReach, g.throws - g.blind)
  row("aimed: half-led landing (5 x victim step) would reach the victim"): pct(g.ledHalfInReach, g.throws - g.blind)
  row("aimed: both plain and led reach"): pct(g.bothInReach, g.throws - g.blind)
  row("aimed: only the led landing reaches"): pct(g.onlyLedInReach, g.throws - g.blind)
  row("aimed: only the plain landing reaches"): pct(g.onlyPlainInReach, g.throws - g.blind)
  row("enemy hits per throw"): mean(g.hitsEnemy, g.throws)
  row("throws hitting an enemy"): pct(g.throwsHittingEnemy, g.throws)
  row("team hits per throw"): mean(g.hitsTeam, g.throws)

main()
