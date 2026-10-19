## Paintbot PW glory economics against one rival: per pw_fast game, who won, how it ended, the
## winner's glory by award kind (from the replay's events), the same comeback awards recomputed
## from the lives and cogs-out counts under a chosen behind_lives/behind_cogs config, and tempo
## counterfactuals (an extra heart from 30 s on, the straggler gap before an elimination).
##
##   nim c -d:release -d:ssl -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw-0124/examples/paintbot --path:$HOME/p/paintbot-pw-0124/src \
##     --path:tools -o:tools/pw_awards tools/pw_awards.nim
##   tools/pw_awards [--lives=5] [--cogs=10] [--out=games.tsv] <pw_fast dirs eps/fast/<tag>/...>
##
## One TSV row per game (our side from the directory name), then means per outcome and ending.

import
  std/[math, os, strformat, strutils, tables],
  game, sim

const
  Marks = [30, 60, 90, 120, 150]

type
  Game = object
    label: string
    side, ticks: int
    ending: string
    won: bool
    glory: float
    awards: array[2, array[GloryKind, int]]
    againLives, againCogs: array[2, int]
    configLives, configCogs: int
    aliveEnd, heartsEnd, meterEnd: array[2, int]
    heartsAt: array[2, array[Marks.len, int]]
    meanHearts: array[2, float]
    lastDeath, secondLastDeath: array[2, int]
    lastDeathDepth: array[2, float]
    firstBehind, behindCogSeconds: array[2, int]
    finishPlusOne, finishPlusOneFromStart: int
    survivorDepth: array[2, float]
    survivorSpots: array[2, string]
    firstLow: array[2, array[3, int]]
    firstHearts: array[2, array[9, int]]
    firstLake: array[2, int]

var
  behindLivesAward = 5
  behindCogsAward = 10
  outPath = ""

proc depth(side: int, pos: Point): float =
  ## Share of the way from the side's own home to the enemy home, in percent.
  let
    own = home(side)
    enemy = home(1 - side)
    ax = (enemy.x - own.x).float
    az = (enemy.z - own.z).float
  ((pos.x - own.x).float * ax + (pos.z - own.z).float * az) / (ax * ax + az * az) * 100.0

proc analyze(path: string, side: int): Game =
  ## Re-simulates one replay and collects the per-game economics for our side.
  let recording = loadRecording(path)
  result.side = side
  result.configLives = recording.glory.behindLives.int
  result.configCogs = recording.glory.behindCogs.int
  var
    w = newWorld(recording.seed, recording.endTick)
    target = 0
    cumulative = 0
    cumulativeFromStart = 0
    previousScore = 0
    aliveBefore = [8, 8]
    heartSum: array[2, int]
    deadSeen = newSeq[bool](Seats)
  result.finishPlusOne = -1
  result.finishPlusOneFromStart = -1
  for s in 0 .. 1:
    result.firstBehind[s] = -1
    result.lastDeath[s] = -1
    result.secondLastDeath[s] = -1
    result.firstLake[s] = -1
    for low in 0 .. 2:
      result.firstLow[s][low] = -1
    for k in 0 .. 8:
      result.firstHearts[s][k] = -1
  for frame in recording.frames:
    w.step(frame.commands, replayRulesVersion)
    if target == 0:
      target = w.heartMeterTarget().int
    # Heart pickups are awarded before the tick advances, the other kinds after it.
    for e in w.gloryEvents:
      if (e.kind == gloryHeart and e.tick == w.tick - 1) or
        (e.kind != gloryHeart and e.tick == w.tick):
          result.awards[e.team][e.kind] += e.amount
    var alive: array[2, int]
    for i in 0 ..< Seats:
      if w.cogs[i].hp > 0:
        inc alive[team(i)]
    for s in 0 .. 1:
      if alive[s] < aliveBefore[s]:
        result.secondLastDeath[s] = result.lastDeath[s]
        result.lastDeath[s] = w.tick.int
        for i in 0 ..< Seats:
          if team(i) == s and w.cogs[i].hp <= 0 and not deadSeen[i]:
            deadSeen[i] = true
            result.lastDeathDepth[s] = depth(s, w.cogs[i].pos)
      for low in 1 .. 2:
        if alive[s] <= low and result.firstLow[s][low] < 0:
          result.firstLow[s][low] = w.tick.int
    aliveBefore = alive
    if w.tick mod (5 * TickRate) == 0:
      let
        lives = [w.teamLives(0).int, w.teamLives(1).int]
        down = [w.teamCogsOut(0).int, w.teamCogsOut(1).int]
      for s in 0 .. 1:
        let behindLives = lives[1 - s] - lives[s]
        if behindLives > 0:
          result.againLives[s] += behindLives * behindLivesAward
        let behindCogs = down[s] - down[1 - s]
        if behindCogs > 0:
          result.againCogs[s] += behindCogs * behindCogsAward
          result.behindCogSeconds[s] += behindCogs * 5
          if result.firstBehind[s] < 0:
            result.firstBehind[s] = w.tick.int
    var hearts: array[2, int]
    for h in w.controlHearts:
      if h.owner >= 0:
        inc hearts[h.owner]
        if abs(depth(0, h.pos) - 50.0) < 5.0 and result.firstLake[h.owner] < 0:
          result.firstLake[h.owner] = w.tick.int
    for s in 0 .. 1:
      heartSum[s] += hearts[s]
      for k in 5 .. 8:
        if hearts[s] >= k and result.firstHearts[s][k] < 0:
          result.firstHearts[s][k] = w.tick.int
    for m, mark in Marks:
      if w.tick == mark * TickRate:
        for s in 0 .. 1:
          result.heartsAt[s][m] = hearts[s]
    let delta = w.scoreTicks[side].int - previousScore
    previousScore = w.scoreTicks[side].int
    cumulativeFromStart += delta + 1
    if result.finishPlusOneFromStart < 0 and cumulativeFromStart >= target:
      result.finishPlusOneFromStart = w.tick.int
    if w.tick >= 30 * TickRate:
      cumulative += delta + 1
    else:
      cumulative += delta
    if result.finishPlusOne < 0 and cumulative >= target:
      result.finishPlusOne = w.tick.int
  result.ticks = w.tick.int
  let scores = w.scores()
  result.won = scores[side] > scores[1 - side]
  result.glory = max(scores[0], scores[1])
  var survivors: array[2, int]
  for i in 0 ..< Seats:
    if w.cogs[i].hp > 0:
      let s = team(i)
      inc result.aliveEnd[s]
      inc survivors[s]
      result.survivorDepth[s] += depth(s, w.cogs[i].pos)
      result.survivorSpots[s].add &"{w.cogs[i].pos.x},{w.cogs[i].pos.z}@{depth(s, w.cogs[i].pos):.0f};"
  for s in 0 .. 1:
    if survivors[s] > 0:
      result.survivorDepth[s] /= survivors[s].float
    result.meterEnd[s] = w.scoreTicks[s].int * 100 div max(target, 1)
    result.meanHearts[s] = heartSum[s].float / max(result.ticks, 1).float
  for h in w.controlHearts:
    if h.owner >= 0:
      inc result.heartsEnd[h.owner]
  result.ending =
    if result.aliveEnd[0] == 0 or result.aliveEnd[1] == 0:
      "elimination"
    elif w.tick >= w.endTick:
      "time"
    else:
      "meter"

proc row(g: Game): string =
  ## One TSV row for a game.
  let
    s = g.side
    t = 1 - s
    winner = if g.won: s else: t
  var cells: seq[string]
  cells.add g.label
  cells.add (if s == 0: "red" else: "blue")
  cells.add $g.ticks
  cells.add g.ending
  cells.add (if g.won: "win" else: "loss")
  cells.add &"{g.glory:.0f}"
  cells.add $g.awards[winner][gloryQuietSupplies]
  cells.add $g.awards[winner][gloryHeart]
  cells.add $g.awards[winner][gloryBehindLives]
  cells.add $g.awards[winner][gloryBehindCogs]
  cells.add $g.againLives[s]
  cells.add $g.againCogs[s]
  cells.add $g.againLives[t]
  cells.add $g.againCogs[t]
  cells.add $g.configLives
  cells.add $g.configCogs
  cells.add $g.aliveEnd[s]
  cells.add $g.aliveEnd[t]
  cells.add $g.heartsEnd[s]
  cells.add $g.heartsEnd[t]
  cells.add $g.meterEnd[s]
  cells.add $g.meterEnd[t]
  for m in 0 ..< Marks.len:
    cells.add $g.heartsAt[s][m]
  for m in 0 ..< Marks.len:
    cells.add $g.heartsAt[t][m]
  cells.add &"{g.meanHearts[s]:.2f}"
  cells.add &"{g.meanHearts[t]:.2f}"
  cells.add $g.lastDeath[s]
  cells.add $g.secondLastDeath[s]
  cells.add $g.lastDeath[t]
  cells.add $g.secondLastDeath[t]
  cells.add $g.firstBehind[s]
  cells.add $g.firstBehind[t]
  cells.add $g.behindCogSeconds[s]
  cells.add $g.behindCogSeconds[t]
  cells.add $g.finishPlusOne
  cells.add $g.finishPlusOneFromStart
  cells.add &"{g.survivorDepth[s]:.0f}"
  cells.add &"{g.survivorDepth[t]:.0f}"
  cells.add &"{g.lastDeathDepth[s]:.0f}"
  cells.add &"{g.lastDeathDepth[t]:.0f}"
  cells.add $g.firstLow[t][2]
  cells.add $g.firstLow[t][1]
  cells.add $g.firstLow[s][2]
  cells.add $g.firstLow[s][1]
  for k in 5 .. 8:
    cells.add $g.firstHearts[s][k]
  for k in 5 .. 8:
    cells.add $g.firstHearts[t][k]
  cells.add $g.firstLake[s]
  cells.add $g.firstLake[t]
  cells.add g.survivorSpots[s]
  cells.add g.survivorSpots[t]
  cells.join("\t")

const
  Header = "label\tside\tticks\tending\tresult\tglory\twQuiet\twHeart\twLives\twCogs\t" &
    "oursAgainLives\toursAgainCogs\ttheirsAgainLives\ttheirsAgainCogs\tcfgLives\tcfgCogs\t" &
    "ourAlive\ttheirAlive\tourHearts\ttheirHearts\tourMeter\ttheirMeter\t" &
    "ourH30\tourH60\tourH90\tourH120\tourH150\ttheirH30\ttheirH60\ttheirH90\ttheirH120\ttheirH150\t" &
    "ourMeanHearts\ttheirMeanHearts\tourLastDeath\tour2ndLastDeath\ttheirLastDeath\ttheir2ndLastDeath\t" &
    "ourFirstBehind\ttheirFirstBehind\tourBehindCogS\ttheirBehindCogS\tfinishPlus1\tfinishPlus1From0\t" &
    "ourSurvivorDepth\ttheirSurvivorDepth\tourLastDeathDepth\ttheirLastDeathDepth\t" &
    "theirLow2\ttheirLow1\tourLow2\tourLow1\tour5\tour6\tour7\tour8\ttheir5\ttheir6\ttheir7\ttheir8\t" &
    "ourFirstLake\ttheirFirstLake\tourSpots\ttheirSpots"

proc summary(games: seq[Game]) =
  ## Means per outcome and ending.
  echo &"{games.len} games, awards recomputed at lives {behindLivesAward} cogs {behindCogsAward}"
  echo "| group | n | ticks | s | glory | base | quiet | heart | bLives | bCogs | recomputed winner bLives | bCogs | loser recomputed bLives | bCogs | our alive | their alive | our meter | their meter | our mean hearts | their mean hearts | our h30 | h60 | h90 | h120 | their h30 | h60 | h90 | h120 | finish+1 s saved | straggler gap s | loser survivor depth |"
  echo "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"
  for group in ["win elimination", "win meter", "win time", "loss elimination", "loss meter", "loss time", "win all", "loss all"]:
    var
      n = 0
      ticks, glory, quiet, heart, lives, cogs, rLives, rCogs, lLives, lCogs: float
      ourAlive, theirAlive, ourMeter, theirMeter, ourMean, theirMean: float
      ourH, theirH: array[4, float]
      saved, savedN, gap, gapN, depthSum, depthN: float
    for g in games:
      let
        outcome = if g.won: "win" else: "loss"
        key = outcome & " " & g.ending
      if key != group and (outcome & " all") != group:
        continue
      let
        s = g.side
        t = 1 - s
        winner = if g.won: s else: t
        loser = 1 - winner
      inc n
      ticks += g.ticks.float
      glory += g.glory
      quiet += g.awards[winner][gloryQuietSupplies].float
      heart += g.awards[winner][gloryHeart].float
      lives += g.awards[winner][gloryBehindLives].float
      cogs += g.awards[winner][gloryBehindCogs].float
      rLives += g.againLives[winner].float
      rCogs += g.againCogs[winner].float
      lLives += g.againLives[loser].float
      lCogs += g.againCogs[loser].float
      ourAlive += g.aliveEnd[s].float
      theirAlive += g.aliveEnd[t].float
      ourMeter += g.meterEnd[s].float
      theirMeter += g.meterEnd[t].float
      ourMean += g.meanHearts[s]
      theirMean += g.meanHearts[t]
      for m in 0 ..< 4:
        ourH[m] += g.heartsAt[s][m].float
        theirH[m] += g.heartsAt[t][m].float
      if g.won:
        savedN += 1
        if g.finishPlusOne > 0 and g.finishPlusOne < g.ticks:
          saved += (g.ticks - g.finishPlusOne).float / TickRate.float
      if g.won and g.ending == "elimination" and g.secondLastDeath[t] > 0:
        gap += (g.lastDeath[t] - g.secondLastDeath[t]).float / TickRate.float
        gapN += 1
      if g.aliveEnd[loser] > 0:
        depthSum += g.survivorDepth[loser]
        depthN += 1
    if n == 0:
      continue
    let f = n.float
    echo &"| {group} | {n} | {ticks / f:.0f} | {ticks / f / TickRate.float:.0f} | {glory / f:.0f} | {600 - ticks / f / TickRate.float:.0f} | " &
      &"{quiet / f:.0f} | {heart / f:.0f} | {lives / f:.0f} | {cogs / f:.0f} | {rLives / f:.0f} | {rCogs / f:.0f} | {lLives / f:.0f} | {lCogs / f:.0f} | " &
      &"{ourAlive / f:.1f} | {theirAlive / f:.1f} | {ourMeter / f:.0f}% | {theirMeter / f:.0f}% | {ourMean / f:.2f} | {theirMean / f:.2f} | " &
      &"{ourH[0] / f:.1f} | {ourH[1] / f:.1f} | {ourH[2] / f:.1f} | {ourH[3] / f:.1f} | " &
      &"{theirH[0] / f:.1f} | {theirH[1] / f:.1f} | {theirH[2] / f:.1f} | {theirH[3] / f:.1f} | " &
      &"{saved / max(savedN, 1):.1f} | {gap / max(gapN, 1):.1f} | {depthSum / max(depthN, 1):.0f} |"

proc main() =
  var inputs: seq[string]
  for argument in commandLineParams():
    if argument.startsWith("--lives="):
      behindLivesAward = parseInt(argument["--lives=".len .. ^1])
    elif argument.startsWith("--cogs="):
      behindCogsAward = parseInt(argument["--cogs=".len .. ^1])
    elif argument.startsWith("--out="):
      outPath = argument["--out=".len .. ^1]
    else:
      inputs.add argument
  var games: seq[Game]
  for input in inputs:
    for path in walkDirRec(input):
      if not path.endsWith(".replay"):
        continue
      let parts = path.split(DirSep)
      if parts.len < 4 or parts[^3] != "games":
        continue
      let batch = parts[^4].split('_')
      if batch.len != 4:
        continue
      let side = if batch[2] == "red": 0 else: 1
      var g = analyze(path, side)
      g.label = parts[^4] & "/" & parts[^2]
      games.add g
  var rows = @[Header]
  for g in games:
    rows.add row(g)
  if outPath.len > 0:
    writeFile(outPath, rows.join("\n") & "\n")
  else:
    for r in rows:
      echo r
  summary(games)

main()
