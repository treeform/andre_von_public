## Paintbot PW raids: every change of owner of a heart on our side after a tick, with the enemy
## party in the 140-unit ring, our living cogs and our nearest cog at the moment of capture.
##
##   nim c -d:release -d:ssl -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw-0124/examples/paintbot --path:$HOME/p/paintbot-pw-0124/src \
##     --path:tools -o:tools/pw_raid tools/pw_raid.nim
##   tools/pw_raid [--after=ticks] [--depth=units] <pw_fast dirs (eps/fast/<tag>/<rival>_<side>_<seed>)>...
##
## A heart is on our side when its x is within --depth (1500) of our home line or behind it.
## Heart positions are printed in red's frame (blue games are mirrored by the half turn).

import
  std/[algorithm, math, os, sequtils, strformat, strutils, tables],
  game, sim

const
  Ring2 = 140'i64 * 140
  GunReach2 = 2133'i64 * 2133

type
  Raid = object
    game: string
    win: bool
    tick: int
    heart: Point
    byUs: bool
    party: seq[int]
    partyHp: seq[int]
    enemyAlive: int
    ourAlive: int
    nearest: int
    nearestHp: int
    inReach: int
    within1500: int
    claimTicks: int
    contestedTicks: int
    nearestAtStart: int
    recentDeaths: int
    atLake: int
    nearestPos: Point
    meanX: int
    deep: int
  Outcome = object
    game: string
    win: bool
    endTick: int
    ourAlive, enemyAlive: int
    ourMeter, enemyMeter: int
    raids, recaptures: int

var
  afterTick = 1200
  depth = 1500
  outcomeTables = initTable[string, Table[string, bool]]()

proc outcomeOf(path: string): (string, int, bool, bool) =
  ## Game key, our side, our win and validity of a pw_fast replay path.
  let parts = path.split(DirSep)
  if parts.len < 6 or parts[^3] != "games":
    return
  let batch = parts[^4].split('_')
  if batch.len != 4:
    return
  let
    tag = parts[^5]
    rival = batch[0] & ":" & batch[1]
    side = batch[2]
    seed = parseInt(batch[3]) + parseInt(parts[^2])
    table = parts[0 ..< ^5].join($DirSep) / tag & ".tsv"
  if table notin outcomeTables:
    var outcomes = initTable[string, bool]()
    if fileExists(table):
      for line in lines(table):
        let f = line.split('\t')
        if f.len >= 5:
          outcomes[f[0] & "/" & f[1] & "/" & f[2]] = parseFloat(f[3]) > parseFloat(f[4])
    outcomeTables[table] = outcomes
  let key = rival & "/" & side & "/" & $seed
  if key notin outcomeTables[table]:
    return
  let ourSide =
    if side == "red":
      0
    else:
      1
  (key, ourSide, outcomeTables[table][key], true)

proc mirrored(side: int, p: Point): Point =
  ## The point in red's frame.
  if side == 0:
    p
  else:
    point(Width - p.x, Height - p.z)

proc dist(a, b: Point): int =
  ## Euclidean distance, rounded down.
  var
    n = distance2(a, b)
    x = n
    y = (x + 1) div 2
  if n == 0:
    return 0
  while y < x:
    x = y
    y = (x + n div x) div 2
  x.int

proc touching(w: World, i: int, h: Point): bool =
  ## Whether a living cog touches the heart the way updateTerritory counts it.
  w.cogs[i].hp > 0 and distance2(w.cogs[i].pos, h) <= Ring2 and w.traversable(w.cogs[i].pos, h)

proc analyze(path: string, raids: var seq[Raid], outcomes: var seq[Outcome]) =
  ## Re-simulates one replay and records every owner change of a heart on our side.
  let (key, ourSide, win, ok) = outcomeOf(path)
  if not ok:
    return
  let
    recording = loadRecording(path)
    enemy = 1 - ourSide
    ourHome = home(ourSide)
  var
    w = newWorld(recording.seed, recording.endTick)
    owners: seq[int32]
    claimTeam: seq[int32]
    claimStart: seq[int]
    contested: seq[int]
    nearestAtStart: seq[int]
    deathTick = newSeq[int](w.cogs.len)
    deathPos = newSeq[Point](w.cogs.len)
    outcome = Outcome(game: key, win: win)
  for i in 0 ..< w.cogs.len:
    deathTick[i] = -1
  for h in w.controlHearts:
    owners.add h.owner
    claimTeam.add -1
    claimStart.add -1
    contested.add 0
    nearestAtStart.add -1
  proc onOurSide(p: Point): bool =
    if ourSide == 0:
      p.x <= ourHome.x + depth
    else:
      p.x >= ourHome.x - depth
  proc nearestOurs(h: Point): (int, int) =
    var
      best = -1
      hp = 0
    for i in countup(ourSide, w.cogs.len - 1, 2):
      if w.cogs[i].hp > 0:
        let d = dist(w.cogs[i].pos, h)
        if best < 0 or d < best:
          best = d
          hp = w.cogs[i].hp.int
    (best, hp)
  for frame in recording.frames:
    let before = w.cogs
    w.step(frame.commands, replayRulesVersion)
    for i in countup(ourSide, w.cogs.len - 1, 2):
      if before[i].hp > 0 and w.cogs[i].hp <= 0:
        deathTick[i] = w.tick
        deathPos[i] = w.cogs[i].pos
    for idx, h in w.controlHearts:
      if h.owner != owners[idx] and w.tick > afterTick and onOurSide(h.pos):
        var r = Raid(game: key, win: win, tick: w.tick, heart: mirrored(ourSide, h.pos))
        r.byUs = h.owner == ourSide.int32
        let capturer =
          if r.byUs:
            ourSide
          else:
            enemy
        for i in countup(capturer, w.cogs.len - 1, 2):
          if w.touching(i, h.pos):
            r.party.add i
            r.partyHp.add w.cogs[i].hp.int
        for i in 0 ..< w.cogs.len:
          if w.cogs[i].hp > 0:
            if team(i) == ourSide:
              inc r.ourAlive
              r.meanX += mirrored(ourSide, w.cogs[i].pos).x.int
              if mirrored(ourSide, w.cogs[i].pos).x > 3800:
                inc r.deep
              let d2 = distance2(w.cogs[i].pos, h.pos)
              if d2 <= GunReach2:
                inc r.inReach
              if d2 <= 1500'i64 * 1500:
                inc r.within1500
              if abs(w.cogs[i].pos.x.int - 3200) <= 600:
                inc r.atLake
            else:
              inc r.enemyAlive
        let near = nearestOurs(h.pos)
        r.nearest = near[0]
        r.nearestHp = near[1]
        if r.ourAlive > 0:
          r.meanX = r.meanX div r.ourAlive
        for i in countup(ourSide, w.cogs.len - 1, 2):
          if w.cogs[i].hp > 0 and dist(w.cogs[i].pos, h.pos) == r.nearest:
            r.nearestPos = mirrored(ourSide, w.cogs[i].pos)
        if claimTeam[idx] == h.owner and claimStart[idx] >= 0:
          r.claimTicks = w.tick - claimStart[idx]
          r.contestedTicks = contested[idx]
          r.nearestAtStart = nearestAtStart[idx]
        else:
          r.claimTicks = -1
          r.nearestAtStart = -1
        for i in countup(ourSide, w.cogs.len - 1, 2):
          if deathTick[i] >= 0 and w.tick - deathTick[i] <= 240 and
            distance2(deathPos[i], h.pos) <= 800'i64 * 800:
              inc r.recentDeaths
        raids.add r
        if r.byUs:
          inc outcome.recaptures
        else:
          inc outcome.raids
      owners[idx] = h.owner
      let cap = w.heartCaptures[idx]
      if cap.team != claimTeam[idx]:
        claimTeam[idx] = cap.team
        if cap.team >= 0:
          claimStart[idx] = w.tick
          contested[idx] = 0
          nearestAtStart[idx] = nearestOurs(h.pos)[0]
        else:
          claimStart[idx] = -1
      elif cap.team >= 0 and cap.contested:
        inc contested[idx]
  outcome.endTick = w.tick
  for i in 0 ..< w.cogs.len:
    if w.cogs[i].hp > 0:
      if team(i) == ourSide:
        inc outcome.ourAlive
      else:
        inc outcome.enemyAlive
  outcome.ourMeter = w.scoreTicks[ourSide].int div TickRate
  outcome.enemyMeter = w.scoreTicks[enemy].int div TickRate
  outcomes.add outcome

proc median(xs: seq[int]): int =
  ## The middle value, 0 when empty.
  if xs.len == 0:
    return 0
  var s = xs
  s.sort()
  s[s.len div 2]

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

proc report(raids: seq[Raid], outcomes: seq[Outcome]) =
  ## Prints every owner change and the summary.
  echo "## Owner changes on our side (tick > " & $afterTick & ")"
  echo "| game | result | tick | s | heart | by | party | hp | foes | ours | nearest | nearHp | reach | <1500 | lake | claim | contested | nearStart | deaths | nearPos | meanX | deep |"
  echo "|---|---|---:|---:|---|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|"
  for r in raids:
    let
      tag =
        if r.win:
          "win"
        else:
          "loss"
      by =
        if r.byUs:
          "us"
        else:
          "jb"
    echo &"| {r.game} | {tag} | {r.tick} | {r.tick div TickRate} | ({r.heart.x},{r.heart.z}) | {by} | " &
      r.party.join(",") & " | " & r.partyHp.join(",") &
      &" | {r.enemyAlive} | {r.ourAlive} | {r.nearest} | {r.nearestHp} | {r.inReach} | {r.within1500} | {r.atLake} | {r.claimTicks} | {r.contestedTicks} | {r.nearestAtStart} | {r.recentDeaths} | ({r.nearestPos.x},{r.nearestPos.z}) | {r.meanX} | {r.deep} |"
  echo ""
  echo "## Games"
  echo "| game | result | end s | ours | foes | our meter | their meter | raids | recaptures |"
  echo "|---|---|---:|---:|---:|---:|---:|---:|---:|"
  for o in outcomes:
    let tag =
      if o.win:
        "win"
      else:
        "loss"
    echo &"| {o.game} | {tag} | {o.endTick div TickRate} | {o.ourAlive} | {o.enemyAlive} | {o.ourMeter} | {o.enemyMeter} | {o.raids} | {o.recaptures} |"
  echo ""
  echo "## Summary"
  let
    jb = raids.filterIt(not it.byUs)
    ours = raids.filterIt(it.byUs)
    wins = outcomes.filterIt(it.win)
    losses = outcomes.filterIt(not it.win)
  echo &"games {outcomes.len} (wins {wins.len}, losses {losses.len})"
  echo &"games with a jb capture on our side: {outcomes.filterIt(it.raids > 0).len} " &
    &"(wins {wins.filterIt(it.raids > 0).len}, losses {losses.filterIt(it.raids > 0).len})"
  echo &"jb captures {jb.len} (in wins {jb.filterIt(it.win).len}, in losses {jb.filterIt(not it.win).len}); our recaptures {ours.len}"
  var hearts = initCountTable[string]()
  for r in jb:
    hearts.inc &"({r.heart.x},{r.heart.z})"
  echo "jb captures by heart (red frame): " & toSeq(hearts.pairs).mapIt(&"{it[0]} {it[1]}").join(", ")
  var party = initCountTable[int]()
  for r in jb:
    party.inc r.party.len
  var sizes = toSeq(party.keys)
  sizes.sort()
  echo "party size: " & sizes.mapIt(&"{it} cogs x{party[it]}").join(", ")
  var hps: seq[int]
  var partySum: seq[int]
  for r in jb:
    hps.add r.partyHp
    partySum.add r.partyHp.sum
  echo &"party member hp q1/med/q3: {quartiles(hps)} (mean {mean(hps):.1f}); party hp total q1/med/q3: {quartiles(partySum)}"
  var hpHist = initCountTable[int]()
  for h in hps:
    hpHist.inc h
  var hpKeys = toSeq(hpHist.keys)
  hpKeys.sort()
  echo "party member hp histogram: " & hpKeys.mapIt(&"{it}:{hpHist[it]}").join(" ")
  echo &"jb alive at capture q1/med/q3: {quartiles(jb.mapIt(it.enemyAlive))}; our alive: {quartiles(jb.mapIt(it.ourAlive))} (mean {mean(jb.mapIt(it.ourAlive)):.1f})"
  echo &"our nearest cog distance q1/med/q3: {quartiles(jb.mapIt(it.nearest))}; at claim start: {quartiles(jb.filterIt(it.nearestAtStart >= 0).mapIt(it.nearestAtStart))}"
  echo &"captures with our nearest within gun reach 2133: {jb.filterIt(it.nearest >= 0 and it.nearest <= 2133).len}; within 1000: {jb.filterIt(it.nearest >= 0 and it.nearest <= 1000).len}; within 500: {jb.filterIt(it.nearest >= 0 and it.nearest <= 500).len}; beyond 3000: {jb.filterIt(it.nearest > 3000).len}"
  echo &"our cogs within 1500 of the heart q1/med/q3: {quartiles(jb.mapIt(it.within1500))}; at the lake: {quartiles(jb.mapIt(it.atLake))} (mean {mean(jb.mapIt(it.atLake)):.1f})"
  echo &"claim length ticks q1/med/q3: {quartiles(jb.filterIt(it.claimTicks >= 0).mapIt(it.claimTicks))}; claims that were contested at some point: {jb.filterIt(it.contestedTicks > 0).len}; contested ticks when contested: {quartiles(jb.filterIt(it.contestedTicks > 0).mapIt(it.contestedTicks))}"
  echo &"captures with one of our deaths within 800 units in the last 10 s: {jb.filterIt(it.recentDeaths > 0).len}"
  echo &"our living cogs mean x (red frame) q1/med/q3: {quartiles(jb.filterIt(it.ourAlive > 0).mapIt(it.meanX))}; our cogs past x 3800 (enemy side): {quartiles(jb.mapIt(it.deep))} (mean {mean(jb.mapIt(it.deep)):.1f}); nearest cog x: {quartiles(jb.filterIt(it.nearest >= 0).mapIt(it.nearestPos.x.int))}"
  var byTime = initCountTable[int]()
  for r in jb:
    byTime.inc r.tick div (TickRate * 10) * 10
  var times = toSeq(byTime.keys)
  times.sort()
  echo "jb captures by 10 s bucket: " & times.mapIt(&"{it}s:{byTime[it]}").join(" ")
  var wl = initCountTable[string]()
  for o in outcomes:
    let kind =
      if o.ourAlive == 0:
        "wiped"
      elif o.enemyAlive == 0:
        "wipeout"
      elif o.ourMeter >= 21600 div TickRate or o.enemyMeter >= 21600 div TickRate:
        "meter"
      else:
        "other"
    wl.inc (if o.win: "win " else: "loss ") & kind
  var kinds = toSeq(wl.keys)
  kinds.sort()
  echo "game ends: " & kinds.mapIt(&"{it} {wl[it]}").join(", ")
  echo &"losses: raids per game mean {mean(losses.mapIt(it.raids)):.2f}, wins: {mean(wins.mapIt(it.raids)):.2f}"
  echo &"losses with 0 jb captures on our side: {losses.filterIt(it.raids == 0).len}"

proc main() =
  var inputs: seq[string]
  for argument in commandLineParams():
    if argument.startsWith("--after="):
      afterTick = parseInt(argument["--after=".len .. ^1])
    elif argument.startsWith("--depth="):
      depth = parseInt(argument["--depth=".len .. ^1])
    else:
      inputs.add argument
  var replays: seq[string]
  for input in inputs:
    for path in walkDirRec(input):
      if path.endsWith(".replay"):
        replays.add path
  replays.sort()
  var
    raids: seq[Raid]
    outcomes: seq[Outcome]
  for path in replays:
    analyze(path, raids, outcomes)
  report(raids, outcomes)

main()
