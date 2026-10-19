## Paintbot PW timing: the whole-match time course of a pw_fast set split by our win or loss,
## plus the events around our own-side hearts falling and being recaptured.
##
##   nim c -d:release -d:ssl -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw-0124/examples/paintbot --path:$HOME/p/paintbot-pw-0124/src \
##     --path:tools -o:tools/pw_timing tools/pw_timing.nim
##   tools/pw_timing [--bucket=seconds] <pw_fast dirs eps/fast/<tag>/<rival_vN_side_seed>>...
##
## Hearts are classed from our side: back (behind our home), home (our home line), lake,
## ehome (their home line), eback (behind their home). Depth bins of living cogs: our side
## (progress below 25%), middle, their side (above 75%). The meter is the engine's scoreTicks
## in heart-seconds (target 900). A raider is an enemy cog seen on our side of the map.

import
  std/[algorithm, math, os, strformat, strutils, tables],
  game, sim

const
  Buckets = 48
  Classes = 5
  ClassNames = ["back", "home", "lake", "ehome", "eback"]
  ContactRange = 2133

type
  Course = object
    samples: array[Buckets, int]
    oursAlive, theirsAlive: array[Buckets, float]
    oursDepth, theirsDepth: array[3, array[Buckets, float]]
    oursHearts, theirsHearts: array[Classes, array[Buckets, float]]
    oursMeter, theirsMeter: array[Buckets, float]
    oursProgress, theirsProgress: array[Buckets, float]
    progressSamples: array[2, array[Buckets, int]]
    squadAlive, squadDepth: array[2, array[Buckets, float]]
    squadSamples: array[2, array[Buckets, int]]
  Flip = object
    heart, tick, class: int
    oursAlive, theirsAlive: int
    nearest: float
    ownNear, enemyNear: int
    oursProgress: float
    recapture: int
  GameRow = object
    label: string
    win: bool
    endTick: int
    flips: seq[Flip]
    enemyHeldTicks, oursHeldEnemyTicks: int
    peakHearts, peakTick: int
    meterBehindTick: int
    oursMeter, theirsMeter: int
    oursAliveEnd, theirsAliveEnd: int
    firstRaiderTick, homeEmptyTick, raiders, enemiesHomeAtFlip: int
    flipPos, detail: string

var
  bucketTicks = 5 * TickRate
  outcomes = initTable[string, bool]()
  courses: array[2, Course]
  rows: seq[GameRow]

proc progressOf(side: int, p: Point): float =
  ## Share of the way from the side's home to the enemy home.
  let
    own = home(side)
    enemy = home(1 - side)
    ax = (enemy.x - own.x).float
    az = (enemy.z - own.z).float
  ((p.x - own.x).float * ax + (p.z - own.z).float * az) / (ax * ax + az * az)

proc heartClass(side: int, p: Point): int =
  ## Classes a heart by its depth from the side's home.
  let d = progressOf(side, p)
  if d < -0.45:
    0
  elif d < 0.25:
    1
  elif d <= 0.75:
    2
  elif d < 1.45:
    3
  else:
    4

proc depthBin(d: float): int =
  ## Bins a cog's progress into our side, the middle and their side.
  if d < 0.25:
    0
  elif d <= 0.75:
    1
  else:
    2

proc gameInfo(path: string, side: var int, win: var bool, label: var string): bool =
  ## Reads our side and outcome of a pw_fast replay from its path and the tag's tsv.
  let parts = path.split(DirSep)
  if parts.len < 5 or parts[^3] != "games":
    return false
  let batch = parts[^4].split('_')
  if batch.len != 4:
    return false
  let
    tag = parts[^5]
    rival = batch[0] & ":" & batch[1]
    seed = parseInt(batch[3]) + parseInt(parts[^2])
    table = parts[0 ..< ^5].join($DirSep) / tag & ".tsv"
  if fileExists(table) and (tag & "/") notin outcomes:
    outcomes[tag & "/"] = true
    for line in lines(table):
      let f = line.split('\t')
      if f.len >= 5:
        outcomes[tag & "/" & f[0] & "/" & f[1] & "/" & f[2]] =
          parseFloat(f[3]) > parseFloat(f[4])
  let key = tag & "/" & rival & "/" & batch[2] & "/" & $seed
  if key notin outcomes:
    return false
  side = (if batch[2] == "red": 0 else: 1)
  win = outcomes[key]
  label = parts[^4] & "/" & parts[^2]
  true

proc cogDetail(w: World, side, i: int, heart: Point, prev: Point): string =
  ## Describes one of our cogs at a flip: progress, metres to the heart, nearest visible
  ## enemy in metres (- when none), m when it moved this tick, and hp.
  var nearest = int64.high
  for j in 0 ..< Seats:
    if team(j) != side and w.cogs[j].hp > 0 and w.visible(i, j):
      nearest = min(nearest, distance2(w.cogs[i].pos, w.cogs[j].pos))
  let
    seen = (if nearest == int64.high: "-" else: &"{sqrt(nearest.float) / 100.0:.0f}")
    moving = (if distance2(prev, w.cogs[i].pos) > 16: "m" else: "s")
  &"{100.0 * progressOf(side, w.cogs[i].pos):.0f}%/{sqrt(distance2(w.cogs[i].pos, heart).float) / 100.0:.0f}m/{seen}/{moving}/{w.cogs[i].hp}"

proc analyze(path: string) =
  ## Re-simulates one replay, sampling the course and recording own-side heart flips.
  var
    side: int
    win: bool
    label: string
  if not gameInfo(path, side, win, label):
    return
  let
    recording = loadRecording(path)
    enemy = 1 - side
    outcome = (if win: 1 else: 0)
  var
    w = newWorld(recording.seed, recording.endTick)
    row = GameRow(label: label, win: win, meterBehindTick: -1, firstRaiderTick: -1,
      homeEmptyTick: -1)
    classes: seq[int]
    prevOwner: seq[int]
    openFlip: seq[int]
    raiderSeen = newSeq[bool](Seats)
    prevPos = newSeq[Point](Seats)
  for h in w.controlHearts:
    classes.add heartClass(side, h.pos)
    prevOwner.add h.owner.int
    openFlip.add -1
  for i in 0 ..< Seats:
    prevPos[i] = w.cogs[i].pos
  var c = addr courses[outcome]
  for frame in recording.frames:
    w.step(frame.commands, replayRulesVersion)
    var
      oursAlive, theirsAlive, oursOwned, onOurSide, enemiesOnOurSide = 0
      sx, sz, n = 0.0
    for i in 0 ..< Seats:
      if w.cogs[i].hp > 0:
        let d = progressOf(side, w.cogs[i].pos)
        if team(i) == side:
          inc oursAlive
          sx += w.cogs[i].pos.x.float
          sz += w.cogs[i].pos.z.float
          n += 1
          if d < 0.25:
            inc onOurSide
        else:
          inc theirsAlive
          if d < 0.25:
            inc enemiesOnOurSide
            if not raiderSeen[i]:
              raiderSeen[i] = true
              inc row.raiders
              if row.firstRaiderTick < 0:
                row.firstRaiderTick = w.tick.int
    if w.tick > 20 * TickRate and onOurSide == 0 and row.homeEmptyTick < 0:
      row.homeEmptyTick = w.tick.int
    var oursProgress = -9.0
    if n > 0:
      oursProgress = progressOf(side, point(int32(sx / n), int32(sz / n)))
    for k, h in w.controlHearts:
      let owner = h.owner.int
      if owner == side:
        inc oursOwned
      if classes[k] <= 1:
        if owner == enemy:
          inc row.enemyHeldTicks
        if owner == enemy and prevOwner[k] != enemy and openFlip[k] < 0:
          var f = Flip(heart: k, tick: w.tick.int, class: classes[k], oursAlive: oursAlive,
            theirsAlive: theirsAlive, oursProgress: oursProgress, recapture: -1)
          var best = int64.high
          for i in 0 ..< Seats:
            if w.cogs[i].hp > 0:
              let d2 = distance2(w.cogs[i].pos, h.pos)
              if team(i) == side:
                best = min(best, d2)
                if d2 <= 1500 * 1500:
                  inc f.ownNear
              elif d2 <= 1500 * 1500:
                inc f.enemyNear
          f.nearest = (if best == int64.high: -1.0 else: sqrt(best.float) / 100.0)
          if row.flips.len == 0:
            row.flipPos = &"({h.pos.x},{h.pos.z})"
            row.enemiesHomeAtFlip = enemiesOnOurSide
            for i in 0 ..< Seats:
              if team(i) == side and w.cogs[i].hp > 0:
                if row.detail.len > 0:
                  row.detail.add " "
                row.detail.add cogDetail(w, side, i, h.pos, prevPos[i])
          openFlip[k] = row.flips.len
          row.flips.add f
        elif owner == side and openFlip[k] >= 0:
          row.flips[openFlip[k]].recapture = w.tick.int
          openFlip[k] = -1
      elif classes[k] >= 3 and owner == side:
        inc row.oursHeldEnemyTicks
      prevOwner[k] = owner
    for i in 0 ..< Seats:
      prevPos[i] = w.cogs[i].pos
    if oursOwned > row.peakHearts:
      row.peakHearts = oursOwned
      row.peakTick = w.tick.int
    if row.meterBehindTick < 0 and w.tick >= 30 * TickRate and
      w.scoreTicks[enemy] > w.scoreTicks[side]:
        row.meterBehindTick = w.tick.int
    if w.tick mod bucketTicks != 0:
      continue
    let b = w.tick div bucketTicks - 1
    if b >= Buckets:
      continue
    inc c.samples[b]
    c.oursAlive[b] += oursAlive.float
    c.theirsAlive[b] += theirsAlive.float
    c.oursMeter[b] += w.scoreTicks[side].float / TickRate.float
    c.theirsMeter[b] += w.scoreTicks[enemy].float / TickRate.float
    if n > 0:
      c.oursProgress[b] += 100.0 * oursProgress
      inc c.progressSamples[0][b]
    var tx, tz, tn = 0.0
    for i in 0 ..< Seats:
      if w.cogs[i].hp > 0:
        let d = progressOf(side, w.cogs[i].pos)
        if team(i) == side:
          c.oursDepth[depthBin(d)][b] += 1
          let squad = (i div 2) div 4
          c.squadAlive[squad][b] += 1
          c.squadDepth[squad][b] += 100.0 * d
          inc c.squadSamples[squad][b]
        else:
          c.theirsDepth[depthBin(d)][b] += 1
          tx += w.cogs[i].pos.x.float
          tz += w.cogs[i].pos.z.float
          tn += 1
    if tn > 0:
      c.theirsProgress[b] += 100.0 * progressOf(enemy, point(int32(tx / tn), int32(tz / tn)))
      inc c.progressSamples[1][b]
    for k, h in w.controlHearts:
      if h.owner == side.int32:
        c.oursHearts[classes[k]][b] += 1
      elif h.owner == enemy.int32:
        c.theirsHearts[classes[k]][b] += 1
  row.endTick = w.tick.int
  row.oursMeter = w.scoreTicks[side].int div TickRate
  row.theirsMeter = w.scoreTicks[enemy].int div TickRate
  for i in 0 ..< Seats:
    if w.cogs[i].hp > 0:
      if team(i) == side:
        inc row.oursAliveEnd
      else:
        inc row.theirsAliveEnd
  rows.add row

proc mean(xs: seq[float]): float =
  ## Arithmetic mean, 0 when empty.
  if xs.len == 0:
    0.0
  else:
    xs.sum / xs.len.float

proc median(xs: seq[float]): float =
  ## Median, 0 when empty.
  if xs.len == 0:
    return 0.0
  var s = xs
  s.sort()
  s[s.len div 2]

proc printCourse(name: string, c: Course) =
  ## Prints one outcome's time course.
  echo &"## {name}"
  echo "| s | n | ours alive | theirs alive | ours prog % | theirs prog % | ours side/mid/their | theirs on our side/mid/their | our hearts back/home/lake/ehome/eback | their hearts back/home/lake/ehome/eback | ours meter | theirs meter | sq0 alive | sq0 depth | sq1 alive | sq1 depth |"
  echo "|---:|---:|---:|---:|---:|---:|---|---|---|---|---:|---:|---:|---:|---:|---:|"
  for b in 0 ..< Buckets:
    let n = c.samples[b]
    if n == 0:
      continue
    let m = n.float
    var ours, theirs: string
    for k in 0 ..< Classes:
      if k > 0:
        ours.add "/"
        theirs.add "/"
      ours.add &"{c.oursHearts[k][b] / m:.2f}"
      theirs.add &"{c.theirsHearts[k][b] / m:.2f}"
    let
      p0 = max(c.progressSamples[0][b], 1).float
      p1 = max(c.progressSamples[1][b], 1).float
      s0 = max(c.squadSamples[0][b], 1).float
      s1 = max(c.squadSamples[1][b], 1).float
    echo &"| {(b + 1) * bucketTicks div TickRate} | {n} | {c.oursAlive[b] / m:.1f} | {c.theirsAlive[b] / m:.1f} | " &
      &"{c.oursProgress[b] / p0:.0f} | {c.theirsProgress[b] / p1:.0f} | " &
      &"{c.oursDepth[0][b] / m:.1f}/{c.oursDepth[1][b] / m:.1f}/{c.oursDepth[2][b] / m:.1f} | " &
      &"{c.theirsDepth[0][b] / m:.1f}/{c.theirsDepth[1][b] / m:.1f}/{c.theirsDepth[2][b] / m:.1f} | " &
      &"{ours} | {theirs} | {c.oursMeter[b] / m:.0f} | {c.theirsMeter[b] / m:.0f} | " &
      &"{c.squadAlive[0][b] / m:.1f} | {c.squadDepth[0][b] / s0:.0f} | {c.squadAlive[1][b] / m:.1f} | {c.squadDepth[1][b] / s1:.0f} |"
  echo ""

proc printFlips(name: string, win: bool) =
  ## Summarises own-side heart flips for one outcome.
  var
    games, withFlip, recaptured, lostForGood, flipsTotal = 0
    firstTimes, firstAlive, firstTheirs, firstNearest, firstOwnNear, firstEnemyNear, firstProgress: seq[float]
    recaptureTimes, heldSeconds, heldEnemySeconds, peakTimes, peakCounts, behindTimes: seq[float]
    raiderTimes, emptyTimes, emptyGaps, raiderCounts, enemiesHome: seq[float]
    byClass: array[2, int]
    classFirst: array[2, seq[float]]
    classRecapture: array[2, seq[float]]
    classRecaptured: array[2, int]
    histogram: array[24, int]
    nearestHist: array[6, int]
    positions = initCountTable[string]()
  for r in rows:
    if r.win != win:
      continue
    inc games
    heldSeconds.add r.enemyHeldTicks / TickRate
    heldEnemySeconds.add r.oursHeldEnemyTicks / TickRate
    peakTimes.add r.peakTick / TickRate
    peakCounts.add r.peakHearts.float
    raiderCounts.add r.raiders.float
    if r.meterBehindTick >= 0:
      behindTimes.add r.meterBehindTick / TickRate
    if r.firstRaiderTick >= 0:
      raiderTimes.add r.firstRaiderTick / TickRate
    if r.homeEmptyTick >= 0:
      emptyTimes.add r.homeEmptyTick / TickRate
    if r.flips.len > 0:
      inc withFlip
      let f = r.flips[0]
      positions.inc r.flipPos
      enemiesHome.add r.enemiesHomeAtFlip.float
      if r.homeEmptyTick >= 0:
        emptyGaps.add (f.tick - r.homeEmptyTick) / TickRate
      firstTimes.add f.tick / TickRate
      firstAlive.add f.oursAlive.float
      firstTheirs.add f.theirsAlive.float
      if f.nearest >= 0:
        firstNearest.add f.nearest
        nearestHist[min(int(f.nearest / 10.0), 5)].inc
      firstOwnNear.add f.ownNear.float
      firstEnemyNear.add f.enemyNear.float
      firstProgress.add 100.0 * f.oursProgress
      histogram[min(f.tick div (10 * TickRate), 23)].inc
    for f in r.flips:
      inc flipsTotal
      inc byClass[f.class]
      classFirst[f.class].add f.tick / TickRate
      if f.recapture >= 0:
        inc recaptured
        inc classRecaptured[f.class]
        recaptureTimes.add (f.recapture - f.tick) / TickRate
        classRecapture[f.class].add (f.recapture - f.tick) / TickRate
      else:
        inc lostForGood
  echo &"## own-side heart flips when {name} ({games} games)"
  echo &"- games with an own-side heart taken: {withFlip} ({100 * withFlip div max(games, 1)}%); flips {flipsTotal} (back {byClass[0]}, home {byClass[1]}); recaptured {recaptured}, never {lostForGood}"
  echo &"- first flip at s: mean {mean(firstTimes):.1f}, median {median(firstTimes):.1f}; ours alive then {mean(firstAlive):.2f}, theirs {mean(firstTheirs):.2f}; our centroid progress {mean(firstProgress):.0f}%"
  echo &"- first flip heart: {positions}"
  echo &"- at first flip: nearest own cog {mean(firstNearest):.1f} m (median {median(firstNearest):.1f}); own cogs within 15 m {mean(firstOwnNear):.2f}; enemy cogs within 15 m {mean(firstEnemyNear):.2f}; enemies on our side {mean(enemiesHome):.2f}"
  echo &"- nearest own cog histogram (0-10/10-20/20-30/30-40/40-50/50+ m): {nearestHist[0]}/{nearestHist[1]}/{nearestHist[2]}/{nearestHist[3]}/{nearestHist[4]}/{nearestHist[5]}"
  echo &"- first raider on our side at s: {raiderTimes.len} games, mean {mean(raiderTimes):.1f} median {median(raiderTimes):.1f}; distinct raiders per game {mean(raiderCounts):.2f}"
  echo &"- our side first empty (no own cog below 25%) at s: {emptyTimes.len} games, mean {mean(emptyTimes):.1f} median {median(emptyTimes):.1f}; empty to first flip gap s mean {mean(emptyGaps):.1f} median {median(emptyGaps):.1f}"
  echo &"- recapture s (recaptured flips): mean {mean(recaptureTimes):.1f}, median {median(recaptureTimes):.1f}; home flips at s mean {mean(classFirst[1]):.1f} recaptured {classRecaptured[1]}/{byClass[1]} in {mean(classRecapture[1]):.1f} s; back flips at s mean {mean(classFirst[0]):.1f} recaptured {classRecaptured[0]}/{byClass[0]} in {mean(classRecapture[0]):.1f} s"
  echo &"- enemy-held seconds of our own-side hearts per game: mean {mean(heldSeconds):.1f}; our held seconds of their own-side hearts: mean {mean(heldEnemySeconds):.1f}"
  echo &"- our heart count peak: mean {mean(peakCounts):.2f} at s mean {mean(peakTimes):.1f} median {median(peakTimes):.1f}"
  echo &"- meter first behind after 30 s: {behindTimes.len} games, at s mean {mean(behindTimes):.1f} median {median(behindTimes):.1f}"
  var hist = ""
  for i in 0 ..< 24:
    if histogram[i] > 0:
      hist.add &" {i * 10}-{i * 10 + 10}s:{histogram[i]}"
  echo &"- first flip time histogram:{hist}"
  echo ""

proc printRows() =
  ## Prints one compact line per game, with our cogs at the first flip as
  ## progress/metres to the heart/nearest visible enemy m/moving/hp.
  echo "## games"
  echo "| game | result | end s | ours alive | theirs alive | meter ours/theirs | raider s | empty s | raiders | first flip s | heart | ours alive | nearest m | recapture s | flips | enemy-held s | our cogs at the flip |"
  echo "|---|---|---:|---:|---:|---|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---|"
  for r in rows:
    var first, alive, nearest, recapture = "-"
    if r.flips.len > 0:
      let f = r.flips[0]
      first = &"{f.tick / TickRate:.0f}"
      alive = $f.oursAlive
      nearest = &"{f.nearest:.0f}"
      recapture = (if f.recapture >= 0: &"{(f.recapture - f.tick) / TickRate:.0f}" else: "never")
    let
      raider = (if r.firstRaiderTick >= 0: $(r.firstRaiderTick div TickRate) else: "-")
      empty = (if r.homeEmptyTick >= 0: $(r.homeEmptyTick div TickRate) else: "-")
    echo &"| {r.label} | {(if r.win: \"win\" else: \"loss\")} | {r.endTick div TickRate} | {r.oursAliveEnd} | {r.theirsAliveEnd} | {r.oursMeter}/{r.theirsMeter} | {raider} | {empty} | {r.raiders} | {first} | {r.flipPos} | {alive} | {nearest} | {recapture} | {r.flips.len} | {r.enemyHeldTicks div TickRate} | {r.detail} |"
  echo ""

proc main() =
  var inputs: seq[string]
  for argument in commandLineParams():
    if argument.startsWith("--bucket="):
      bucketTicks = parseInt(argument["--bucket=".len .. ^1]) * TickRate
    else:
      inputs.add argument
  var replays: seq[string]
  for input in inputs:
    for path in walkDirRec(input):
      if path.endsWith(".replay"):
        replays.add path
  replays.sort()
  for path in replays:
    analyze(path)
  printCourse("loss", courses[0])
  printCourse("win", courses[1])
  printFlips("loss", false)
  printFlips("win", true)
  printRows()

main()
