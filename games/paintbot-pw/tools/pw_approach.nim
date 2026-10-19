## Paintbot PW lake approach: how our two squads enter the lake area of a pw_fast set, where
## the enemy stands when the first of us arrives, how strung out the squad is at first contact,
## and where our cogs die around the lake hearts, split by our win or loss.
##
##   nim c -d:release -d:ssl -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw-0124/examples/paintbot --path:$HOME/p/paintbot-pw-0124/src \
##     --path:tools -o:tools/pw_approach tools/pw_approach.nim
##   tools/pw_approach [--map] [--arrive=units] [--rows] <pw_fast dirs eps/fast/<tag>/<rival_vN_side_seed>>...
##
## Everything is in Red's frame (a blue game is turned a half turn about the map centre), so
## squad 0 always works the north lake heart (3200, 1250) and squad 1 the south one (3200, 2750),
## our home is west and the enemy home east. A cog enters the lake area when it first comes
## within --arrive units (default 2000) of a lake heart; its approach path is the stretch from
## 3500 units out to that point. First contact is the first tick a squad member inside 3500 units
## of its lake heart sees an enemy. Lake deaths are deaths within 2500 units of a lake heart.

import
  std/[algorithm, math, os, strformat, strutils, tables],
  game, sim, fastdirs

const
  Far = 2200
  LakeDeath = 1500
  Reach = 2133
  SeenMax = 2500
  Ring = 140
  Near = 1000
  LakeHearts = [point(3200, 1250), point(3200, 2750)]

type
  Death = object
    win: bool
    ours: bool
    tick: int
    squad, seat: int
    pos: Point
    wet: bool
    moving: bool
    height: int
    heartDist: int
    matesNear, matesReach, matesFar: int
    foesSeen, foesReach: int
    killer: Point
    killerWet: bool
    killerHeight: int
    range: int
    sinceArrival: int
    arrived: bool
  Squad = object
    arrivals: seq[int]
    seatArrive: array[4, int]
    seatDied: array[4, int]
    firstTick: int
    firstPos: Point
    firstWet: bool
    spread: int
    matesNear, matesReach: int
    wetShare: float
    wetArrivals: int
    quadrants: array[4, int]
    contactTick: int
    contactGuns, contactFoes: int
    contactWet: bool
    contactSeen: bool
    foesAlive, foesReach, foesRing, foesWet, foesHigh: int
    foesEast, foesWest, foesLateral: int
    foesNorth, foesSouth, foesNorthDry, foesSouthDry: int
    foesVisible: int
    foeHeight: float
    deaths70, kills70: int
  Game = object
    label: string
    win: bool
    squads: array[2, Squad]

var
  arrive = 1200
  showRows = false
  games: seq[Game]
  deaths: seq[Death]

proc wet(p: Point): bool =
  ## True when the point is in the lake (the public waterAt test).
  let
    x = clamp(p.x.int, minX(), maxX())
    z = clamp(p.z.int, minZ(), maxZ())
  terrainHeight(x, z) < RiverWaterHeight and riverBlend(x, z) > 0

proc red(side: int, p: Point): Point =
  ## Turns a point into Red's frame.
  if side == 1:
    point(Width - p.x.int, Height - p.z.int)
  else:
    p

proc dist(a, b: Point): int =
  ## Distance in units.
  int(sqrt(float(distance2(a, b))))

proc quadrant(heart, p: Point): int =
  ## 0 west (our side), 1 east, 2 north, 3 south of the heart in Red's frame.
  let
    dx = p.x.int - heart.x.int
    dz = p.z.int - heart.z.int
  if abs(dx) >= abs(dz):
    if dx < 0: 0 else: 1
  else:
    if dz < 0: 2 else: 3

proc analyze(path: string) =
  ## Re-simulates one replay and records both squads' approach and every lake death.
  let roster = fastRoster(path, true)
  if roster.len != 16:
    return
  let
    side = (if roster[0].endsWith(" win") or roster[0].endsWith(" loss"): 0 else: 1)
    win = roster[side].endsWith(" win")
    recording = loadRecording(path)
    parts = path.split(DirSep)
  var
    w = newWorld(recording.seed, recording.endTick)
    g = Game(label: parts[^4] & "/" & parts[^2], win: win)
    arriveTick = newSeq[int](Seats)
    farTick = newSeq[int](Seats)
    wetTicks = newSeq[int](Seats)
    pathTicks = newSeq[int](Seats)
    tags: seq[(int, int)]
  for i in 0 ..< Seats:
    arriveTick[i] = -1
    farTick[i] = -1
  for s in 0 .. 1:
    g.squads[s].firstTick = -1
    g.squads[s].contactTick = -1
    for k in 0 .. 3:
      g.squads[s].seatArrive[k] = -1
  observeTag = proc(tick: int32, victim, attacker: int, pos: Point) =
    tags.add((victim, attacker))
  defer:
    observeTag = nil
  proc squadOf(i: int): int =
    ## Squad of one of our cogs by the lake2.bas rule.
    ((i div 2) mod 8) div 4
  proc seatOf(i: int): int =
    ## Seat inside the squad by the lake2.bas rule.
    ((i div 2) mod 8) mod 4
  proc heartOf(s: int): Point =
    ## The lake heart squad s works, in Red's frame.
    LakeHearts[s]
  var prev = w.cogs
  for frame in recording.frames:
    let before = w.cogs
    tags.setLen(0)
    w.step(frame.commands, replayRulesVersion)
    let tick = w.tick.int
    defer:
      prev = before
    for (victim, attacker) in tags:
      let
        v = red(side, before[victim].pos)
        a = red(side, before[attacker].pos)
        ours = team(victim) == side
      var hd = int.high
      for h in LakeHearts:
        hd = min(hd, dist(v, h))
      if hd > LakeDeath:
        continue
      var d = Death(win: win, ours: ours, tick: tick, pos: v, wet: wet(before[victim].pos),
        height: terrainHeight(before[victim].pos.x.int, before[victim].pos.z.int),
        heartDist: hd, killer: a, killerWet: wet(before[attacker].pos),
        killerHeight: terrainHeight(before[attacker].pos.x.int, before[attacker].pos.z.int),
        range: dist(v, a), sinceArrival: -1)
      d.moving = distance2(prev[victim].pos, before[victim].pos) > 16
      let victimTeam = team(victim)
      for j in 0 ..< Seats:
        if j == victim or before[j].hp <= 0:
          continue
        let dj = distance2(before[victim].pos, before[j].pos)
        if team(j) == victimTeam:
          if dj <= Near * Near:
            inc d.matesNear
          if dj <= Reach * Reach:
            inc d.matesReach
          elif ours and squadOf(j) == squadOf(victim):
            inc d.matesFar
        else:
          if dj <= Reach * Reach:
            inc d.foesReach
          if w.visible(victim, j):
            inc d.foesSeen
      if ours:
        d.squad = squadOf(victim)
        d.seat = seatOf(victim)
        d.arrived = arriveTick[victim] >= 0
        if not d.arrived:
          inc g.squads[d.squad].seatDied[d.seat]
        if d.arrived:
          d.sinceArrival = tick - arriveTick[victim]
        if tick <= 70 * TickRate:
          inc g.squads[d.squad].deaths70
      else:
        d.squad = (if v.z.int < Height div 2: 0 else: 1)
        if tick <= 70 * TickRate:
          inc g.squads[d.squad].kills70
      deaths.add d
    for i in 0 ..< Seats:
      if team(i) != side or w.cogs[i].hp <= 0 or arriveTick[i] >= 0:
        continue
      let
        s = squadOf(i)
        heart = heartOf(s)
        p = red(side, w.cogs[i].pos)
        d = dist(p, heart)
      if d <= Far and farTick[i] < 0:
        farTick[i] = tick
      if farTick[i] >= 0 and d > arrive:
        inc pathTicks[i]
        if wet(w.cogs[i].pos):
          inc wetTicks[i]
      var sq = addr g.squads[s]
      if sq.contactTick < 0 and d <= Far:
        for j in 0 ..< Seats:
          if team(j) != side and w.cogs[j].hp > 0 and w.visible(i, j) and
            distance2(w.cogs[i].pos, w.cogs[j].pos) <= SeenMax * SeenMax:
            sq.contactTick = tick
            sq.contactWet = wet(w.cogs[i].pos)
            sq.contactSeen = true
            for k in 0 ..< Seats:
              if w.cogs[k].hp > 0 and distance2(w.cogs[i].pos, w.cogs[k].pos) <= Reach * Reach:
                if team(k) == side:
                  inc sq.contactGuns
                else:
                  inc sq.contactFoes
            break
      if d > arrive:
        continue
      arriveTick[i] = tick
      sq.arrivals.add tick
      sq.seatArrive[seatOf(i)] = tick
      if wet(w.cogs[i].pos):
        inc sq.wetArrivals
      if pathTicks[i] > 0:
        sq.wetShare += wetTicks[i] / pathTicks[i]
      inc sq.quadrants[quadrant(heart, p)]
      if sq.firstTick >= 0:
        continue
      sq.firstTick = tick
      sq.firstPos = p
      sq.firstWet = wet(w.cogs[i].pos)
      var heightSum = 0
      for j in 0 ..< Seats:
        if j == i or w.cogs[j].hp <= 0:
          continue
        let dj = distance2(w.cogs[i].pos, w.cogs[j].pos)
        if team(j) == side:
          if squadOf(j) != s:
            continue
          sq.spread = max(sq.spread, int(sqrt(dj.float)))
          if dj <= Near * Near:
            inc sq.matesNear
          if dj <= Reach * Reach:
            inc sq.matesReach
        else:
          inc sq.foesAlive
          let
            q = red(side, w.cogs[j].pos)
            hd = dist(q, heart)
          if hd > Reach:
            continue
          inc sq.foesReach
          if hd <= Ring:
            inc sq.foesRing
          if wet(w.cogs[j].pos):
            inc sq.foesWet
          let h = terrainHeight(w.cogs[j].pos.x.int, w.cogs[j].pos.z.int)
          heightSum += h
          if h >= HighGroundHeight:
            inc sq.foesHigh
          let dryFoe = not wet(w.cogs[j].pos)
          case quadrant(heart, q)
          of 0:
            inc sq.foesWest
          of 1:
            inc sq.foesEast
          of 2:
            inc sq.foesLateral
            inc sq.foesNorth
            if dryFoe:
              inc sq.foesNorthDry
          else:
            inc sq.foesLateral
            inc sq.foesSouth
            if dryFoe:
              inc sq.foesSouthDry
          if w.visible(i, j):
            inc sq.foesVisible
      if sq.foesReach > 0:
        sq.foeHeight = heightSum / sq.foesReach
  games.add g

proc mean(xs: seq[float]): float =
  ## Arithmetic mean, 0 when empty.
  if xs.len == 0: 0.0 else: xs.sum / xs.len.float

proc median(xs: seq[float]): float =
  ## Median, 0 when empty.
  if xs.len == 0:
    return 0.0
  var s = xs
  s.sort()
  s[s.len div 2]

proc pct(a, b: int): string =
  ## Percentage string.
  &"{100.0 * a.float / max(b, 1).float:.0f}%"

proc printSquads(name: string, win: bool) =
  ## Aggregates both squads' approach for one outcome.
  echo &"## approach when {name}"
  for s in 0 .. 1:
    var
      n, arrivedAny, four, wetArr, arrivals = 0
      first, fourth, gap, spread, near, reach, wetShare: seq[float]
      q: array[4, int]
      contact, guns, foes, contactWetN, contactN = 0
      gunsS, foesS: seq[float]
      foesAlive, foesReach, foesRing, foesWet, foesHigh, foesEast, foesWest, foesLat, foesVis: seq[float]
      foesNorthS, foesSouthS, foesNorthDryS, foesSouthDryS: seq[float]
      foeHeight: seq[float]
      d70, k70 = 0
      edge: array[4, int]
      seatTimes: array[4, seq[float]]
      seatDied: array[4, int]
    for g in games:
      if g.win != win:
        continue
      inc n
      let sq = g.squads[s]
      d70 += sq.deaths70
      k70 += sq.kills70
      if sq.contactTick >= 0:
        inc contact
        gunsS.add sq.contactGuns.float
        foesS.add sq.contactFoes.float
        if sq.contactWet:
          inc contactWetN
        edge[clamp(sq.contactGuns, 1, 4) - 1].inc
      if sq.firstTick < 0:
        continue
      inc arrivedAny
      first.add sq.firstTick / TickRate
      for k in 0 .. 3:
        seatDied[k] += sq.seatDied[k]
        if sq.seatArrive[k] >= 0:
          seatTimes[k].add sq.seatArrive[k] / TickRate
      arrivals += sq.arrivals.len
      wetArr += sq.wetArrivals
      wetShare.add sq.wetShare / max(sq.arrivals.len, 1).float
      if sq.arrivals.len >= 4:
        inc four
        fourth.add sq.arrivals[3] / TickRate
        gap.add (sq.arrivals[3] - sq.arrivals[0]) / TickRate
      spread.add sq.spread / 100
      near.add sq.matesNear.float
      reach.add sq.matesReach.float
      for k in 0 .. 3:
        q[k] += sq.quadrants[k]
      foesAlive.add sq.foesAlive.float
      foesReach.add sq.foesReach.float
      foesRing.add sq.foesRing.float
      foesWet.add sq.foesWet.float
      foesHigh.add sq.foesHigh.float
      foesEast.add sq.foesEast.float
      foesWest.add sq.foesWest.float
      foesLat.add sq.foesLateral.float
      foesNorthS.add sq.foesNorth.float
      foesSouthS.add sq.foesSouth.float
      foesNorthDryS.add sq.foesNorthDry.float
      foesSouthDryS.add sq.foesSouthDry.float
      foesVis.add sq.foesVisible.float
      if sq.foesReach > 0:
        foeHeight.add sq.foeHeight
    echo &"### squad {s} ({n} games)"
    echo &"- reached the lake area in {arrivedAny} games; first cog at s mean {mean(first):.1f} median {median(first):.1f}; all four arrived in {four} games, fourth at s mean {mean(fourth):.1f} median {median(fourth):.1f}, first-to-fourth gap s mean {mean(gap):.1f} median {median(gap):.1f}"
    echo &"- at first arrival: squad spread (farthest living mate) m mean {mean(spread):.1f} median {median(spread):.1f}; mates within 10 m {mean(near):.2f}, within gun reach {mean(reach):.2f}"
    echo &"- arrivals {arrivals}: wading at arrival {pct(wetArr, arrivals)}; wet share of the approach path mean {100.0 * mean(wetShare):.0f}%; entry quadrant W/E/N/S {q[0]}/{q[1]}/{q[2]}/{q[3]}"
    echo &"- enemies at first arrival: alive {mean(foesAlive):.2f}; within 21 m of the heart {mean(foesReach):.2f} (in ring {mean(foesRing):.2f}, wading {mean(foesWet):.2f}, high ground {mean(foesHigh):.2f}, west/east/lateral {mean(foesWest):.2f}/{mean(foesEast):.2f}/{mean(foesLat):.2f}, visible to the arriver {mean(foesVis):.2f}); north {mean(foesNorthS):.2f} (dry {mean(foesNorthDryS):.2f}), south {mean(foesSouthS):.2f} (dry {mean(foesSouthDryS):.2f}); their mean height {mean(foeHeight):.0f}"
    echo &"- first contact in {contact} games: our guns within reach of the spotter {mean(gunsS):.2f} vs enemy guns {mean(foesS):.2f}; spotter wading {pct(contactWetN, contact)}; spotter with 1/2/3/4 own guns: {edge[0]}/{edge[1]}/{edge[2]}/{edge[3]}"
    echo &"- arrival s by seat 0/1/2/3: mean {mean(seatTimes[0]):.1f}/{mean(seatTimes[1]):.1f}/{mean(seatTimes[2]):.1f}/{mean(seatTimes[3]):.1f} (arrived {seatTimes[0].len}/{seatTimes[1].len}/{seatTimes[2].len}/{seatTimes[3].len}, died near the lake before arriving {seatDied[0]}/{seatDied[1]}/{seatDied[2]}/{seatDied[3]})"
    echo &"- lake deaths by 70 s: ours {d70} ({d70.float / max(n, 1).float:.2f} per game), theirs {k70} ({k70.float / max(n, 1).float:.2f})"
  echo ""

proc printDeaths(name: string, win: bool) =
  ## Aggregates lake deaths for one outcome.
  for ours in [true, false]:
    var
      n, wetN, movingN, uphill, killerWetN, arrivedN, notArrived = 0
      times, heartDist, matesNear, matesReach, foesSeen, foesReach, range, height, killerHeight, since: seq[float]
      killerQ: array[4, int]
      victimQ: array[4, int]
      sinceHist: array[6, int]
      timeHist: array[8, int]
      window, outnumbered, strung, both, windowWet, windowDry: int
      seatDeaths: array[4, int]
      seatWindow: array[4, int]
      odds: seq[float]
      station: array[2, array[4, int]]
      stationWet: array[2, array[4, int]]
      stationEast: array[2, array[4, int]]
      stationOut: array[2, array[4, int]]
      heartN: array[2, int]
      killerShore: array[2, array[4, int]]
      killerWetQ: array[2, array[4, int]]
      victimShore: array[2, array[4, int]]
      victimWetQ: array[2, array[4, int]]
    for d in deaths:
      if d.win != win or d.ours != ours:
        continue
      inc n
      if ours:
        inc seatDeaths[d.seat]
      if d.tick >= 30 * TickRate and d.tick <= 90 * TickRate:
        inc window
        let
          heartIndex = (if d.pos.z.int < Height div 2: 0 else: 1)
          heartPos = LakeHearts[heartIndex]
          kq = quadrant(heartPos, d.killer)
          vq = quadrant(heartPos, d.pos)
        inc heartN[heartIndex]
        if d.killerWet:
          inc killerWetQ[heartIndex][kq]
        else:
          inc killerShore[heartIndex][kq]
        if d.wet:
          inc victimWetQ[heartIndex][vq]
        else:
          inc victimShore[heartIndex][vq]
        if ours:
          inc seatWindow[d.seat]
          inc station[d.squad][d.seat]
          if d.wet:
            inc stationWet[d.squad][d.seat]
          if vq == 1:
            inc stationEast[d.squad][d.seat]
          if d.foesReach > d.matesReach + 1:
            inc stationOut[d.squad][d.seat]
        if d.wet:
          inc windowWet
        else:
          inc windowDry
        odds.add (d.matesReach + 1).float - d.foesReach.float
        let outnum = d.foesReach > d.matesReach + 1
        if outnum:
          inc outnumbered
        if d.matesFar > 0:
          inc strung
        if outnum and d.matesFar > 0:
          inc both
      times.add d.tick / TickRate
      heartDist.add d.heartDist / 100
      matesNear.add d.matesNear.float
      matesReach.add d.matesReach.float
      foesSeen.add d.foesSeen.float
      foesReach.add d.foesReach.float
      range.add d.range / 100
      height.add d.height.float
      killerHeight.add d.killerHeight.float
      if d.wet:
        inc wetN
      if d.moving:
        inc movingN
      if d.killerWet:
        inc killerWetN
      if d.killerHeight > d.height + 20:
        inc uphill
      let heart = (if d.pos.z.int < Height div 2: LakeHearts[0] else: LakeHearts[1])
      inc killerQ[quadrant(heart, d.killer)]
      inc victimQ[quadrant(heart, d.pos)]
      timeHist[min(d.tick div (15 * TickRate), 7)].inc
      if ours:
        if d.arrived:
          inc arrivedN
          since.add d.sinceArrival / TickRate
          sinceHist[min(d.sinceArrival div (5 * TickRate), 5)].inc
        else:
          inc notArrived
    let who = (if ours: "our" else: "their")
    echo &"## {who} lake deaths when {name}: {n}"
    echo &"- at s mean {mean(times):.1f} median {median(times):.1f}; by 15 s bins 0-15/15-30/30-45/45-60/60-75/75-90/90-105/105+: {timeHist[0]}/{timeHist[1]}/{timeHist[2]}/{timeHist[3]}/{timeHist[4]}/{timeHist[5]}/{timeHist[6]}/{timeHist[7]}"
    echo &"- victim: {pct(wetN, n)} wading, {pct(movingN, n)} moving, {mean(heartDist):.1f} m from the heart (median {median(heartDist):.1f}), height mean {mean(height):.0f}, quadrant W/E/N/S {victimQ[0]}/{victimQ[1]}/{victimQ[2]}/{victimQ[3]}; mates within 10 m {mean(matesNear):.2f}, within reach {mean(matesReach):.2f}; enemies in view {mean(foesSeen):.2f}, within reach {mean(foesReach):.2f}"
    echo &"- killer: {pct(killerWetN, n)} wading, height mean {mean(killerHeight):.0f}, uphill of the victim {pct(uphill, n)}, quadrant W/E/N/S {killerQ[0]}/{killerQ[1]}/{killerQ[2]}/{killerQ[3]}, range m mean {mean(range):.1f} median {median(range):.1f}"
    echo &"- in the 30-90 s window: {window} deaths ({windowWet} wading, {windowDry} dry); own guns minus enemy guns within reach of the victim mean {mean(odds):.2f}; outnumbered within reach {outnumbered} ({pct(outnumbered, window)}), a squad mate alive beyond reach {strung} ({pct(strung, window)}), both {both} ({pct(both, window)})"
    for k in 0 .. 1:
      let hn = (if k == 0: "N heart" else: "S heart")
      echo &"- {hn} window deaths {heartN[k]}: victim dry W/E/N/S {victimShore[k][0]}/{victimShore[k][1]}/{victimShore[k][2]}/{victimShore[k][3]}, wading {victimWetQ[k][0]}/{victimWetQ[k][1]}/{victimWetQ[k][2]}/{victimWetQ[k][3]}; killer dry W/E/N/S {killerShore[k][0]}/{killerShore[k][1]}/{killerShore[k][2]}/{killerShore[k][3]}, wading {killerWetQ[k][0]}/{killerWetQ[k][1]}/{killerWetQ[k][2]}/{killerWetQ[k][3]}"
    if ours:
      echo &"- deaths by seat 0/1/2/3: {seatDeaths[0]}/{seatDeaths[1]}/{seatDeaths[2]}/{seatDeaths[3]}; in the window {seatWindow[0]}/{seatWindow[1]}/{seatWindow[2]}/{seatWindow[3]}"
      for sq in 0 .. 1:
        echo &"- squad {sq} window deaths by seat 0/1/2/3: {station[sq][0]}/{station[sq][1]}/{station[sq][2]}/{station[sq][3]} (wading {stationWet[sq][0]}/{stationWet[sq][1]}/{stationWet[sq][2]}/{stationWet[sq][3]}, east of the heart {stationEast[sq][0]}/{stationEast[sq][1]}/{stationEast[sq][2]}/{stationEast[sq][3]}, outnumbered {stationOut[sq][0]}/{stationOut[sq][1]}/{stationOut[sq][2]}/{stationOut[sq][3]})"
      echo &"- {arrivedN} after entering the lake area (s since arrival mean {mean(since):.1f} median {median(since):.1f}; 0-5/5-10/10-15/15-20/20-25/25+ s: {sinceHist[0]}/{sinceHist[1]}/{sinceHist[2]}/{sinceHist[3]}/{sinceHist[4]}/{sinceHist[5]}), {notArrived} on the way in (outside {arrive} units)"
    echo ""

proc printRows() =
  ## One line per game and squad.
  echo "## games"
  echo "| game | result | sq | first s | fourth s | spread m | mates 10 m | wet arr | contact s | guns:foes | foes 21 m | ring | wet | E/W/lat | deaths 70 | kills 70 |"
  echo "|---|---|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|---|---:|---:|"
  for g in games:
    for s in 0 .. 1:
      let sq = g.squads[s]
      let
        first = (if sq.firstTick >= 0: &"{sq.firstTick / TickRate:.0f}" else: "-")
        fourth = (if sq.arrivals.len >= 4: &"{sq.arrivals[3] / TickRate:.0f}" else: "-")
        contact = (if sq.contactTick >= 0: &"{sq.contactTick / TickRate:.0f}" else: "-")
      echo &"| {g.label} | {(if g.win: \"win\" else: \"loss\")} | {s} | {first} | {fourth} | {sq.spread div 100} | {sq.matesNear} | {sq.wetArrivals} | {contact} | {sq.contactGuns}:{sq.contactFoes} | {sq.foesReach} | {sq.foesRing} | {sq.foesWet} | {sq.foesEast}/{sq.foesWest}/{sq.foesLateral} | {sq.deaths70} | {sq.kills70} |"
  echo ""

proc printMap(sample: string) =
  ## ASCII map of the lake region in Red's frame: ~ water, digits height in 50-unit bands
  ## above the waterline, H heart, O home. One character per 100 units. A replay binds the map.
  let recording = loadRecording(sample)
  var w = newWorld(recording.seed, recording.endTick)
  echo &"## map bounds x {minX()}..{maxX()} z {minZ()}..{maxZ()}; vision mode '{visionMode()}' range {visionRangeMetres()} m; rules {replayRulesVersion}; hearts:"
  for h in w.controlHearts:
    echo &"  ({h.pos.x}, {h.pos.z}) wet {wet(h.pos)} h {terrainHeight(h.pos.x.int, h.pos.z.int)}"
  echo "## lake map (x 600..5800, z 0..4000, 100 units per cell; ~ water, 0-9 height band of 50 above -162, H heart, O home)"
  var z = 0
  while z <= 4000:
    var line = &"{z:5} "
    var x = 600
    while x <= 5800:
      let p = point(x, z)
      var c = '.'
      var isHeart = false
      for h in LakeHearts:
        if abs(h.x.int - x) <= 50 and abs(h.z.int - z) <= 50:
          isHeart = true
      for o in [home(0), home(1)]:
        if abs(o.x.int - x) <= 50 and abs(o.z.int - z) <= 50:
          c = 'O'
      if isHeart:
        c = 'H'
      elif c == 'O':
        discard
      elif wet(p):
        c = '~'
      else:
        let band = (terrainHeight(x, z) - RiverWaterHeight) div 50
        c = char(ord('0') + clamp(band, 0, 9))
      line.add c
      x += 100
    echo line
    z += 100
  echo ""
  echo "## dry stations around each lake heart: first dry point along each bearing, with height"
  for k, h in LakeHearts:
    var line = &"heart {k} ({h.x}, {h.z}):"
    var angle = 0
    while angle < 360:
      var r = 300
      var found = false
      while r <= 3200 and not found:
        let
          x = h.x.int + int(r.float * cos(angle.float * PI / 180.0))
          z = h.z.int + int(r.float * sin(angle.float * PI / 180.0))
        if not wet(point(x, z)):
          line.add &" {angle}deg:({x},{z})@{r div 100}m h{terrainHeight(x, z)}"
          found = true
        r += 100
      angle += 30
    echo line
  echo ""

proc trace(path: string, side: int) =
  ## Prints our eight cogs every 5 s of one replay in Red's frame: squad.seat, position,
  ## metres to the squad's lake heart, w when wading, hp; and how many stand within 5 m of
  ## each rally point (2200, 1000) and (2300, 2950).
  let recording = loadRecording(path)
  var w = newWorld(recording.seed, recording.endTick)
  echo "| s | cogs (squad.seat x,z heart-m wet hp) | at rally N | at rally S | enemies alive |"
  echo "|---:|---|---:|---:|---:|"
  for frame in recording.frames:
    w.step(frame.commands, replayRulesVersion)
    if w.tick mod (5 * TickRate) != 0 or w.tick > 120 * TickRate:
      continue
    var
      line = ""
      rallyN, rallyS, foes = 0
    for i in 0 ..< Seats:
      if w.cogs[i].hp <= 0:
        continue
      if team(i) != side:
        inc foes
        continue
      let
        p = red(side, w.cogs[i].pos)
        s = ((i div 2) mod 8) div 4
        k = ((i div 2) mod 8) mod 4
      let wf = (if wet(w.cogs[i].pos): "w" else: "")
      line.add &" {s}.{k}:{p.x},{p.z} {dist(p, LakeHearts[s]) div 100}m{wf} hp{w.cogs[i].hp};"
      if dist(p, point(2200, 1000)) <= 500:
        inc rallyN
      if dist(p, point(2300, 2950)) <= 500:
        inc rallyS
    echo &"| {w.tick div TickRate} |{line} | {rallyN} | {rallyS} | {foes} |"

proc main() =
  var
    inputs: seq[string]
    showMap = false
    tracePath = ""
  for argument in commandLineParams():
    if argument == "--map":
      showMap = true
    elif argument == "--rows":
      showRows = true
    elif argument.startsWith("--arrive="):
      arrive = parseInt(argument["--arrive=".len .. ^1])
    elif argument.startsWith("--trace="):
      tracePath = argument["--trace=".len .. ^1]
    else:
      inputs.add argument
  if tracePath.len > 0:
    trace(tracePath, 0)
    return
  var replays: seq[string]
  for input in inputs:
    for path in walkDirRec(input):
      if path.endsWith(".replay"):
        replays.add path
  replays.sort()
  if showMap and replays.len > 0:
    printMap(replays[0])
    return
  for path in replays:
    analyze(path)
  if replays.len == 0:
    return
  var wins, losses = 0
  for g in games:
    if g.win: inc wins else: inc losses
  echo &"## {games.len} games: {wins} wins, {losses} losses; arrive radius {arrive} units"
  echo ""
  printSquads("loss", false)
  printSquads("win", true)
  printDeaths("loss", false)
  printDeaths("win", true)
  if showRows:
    printRows()

main()
