## Paintbot PW led-shot anatomy: what the target did during the windup of every led shot.
##
##   nim c -d:release -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw-0110/examples/paintbot --path:$HOME/p/paintbot-pw-0110/src \
##     --path:tools -o:tools/pw_missanat tools/pw_missanat.nim
##   tools/pw_missanat <pw_fast dirs>...
##
## For every accepted gun order (cooldown 0 or 1, no windup) the target is the enemy nearest
## the aim point; the order is "led" when the aim lies one step or more ahead of the target
## along its last step. Five ticks later, when the ray leaves, the target's displacement
## along that step says what it did: kept (3.5 steps or more), slowed (0.5 to 3.5), or
## reversed (under 0.5); "lost" when the shooter can no longer see it. A policy whose led
## shots mostly find a target that kept going times its shots to the target's leg.

import
  std/[algorithm, os, sequtils, strformat, strutils, tables],
  game, sim, fastdirs

type
  Pending = object
    shooter, target, release: int
    stepX, stepZ, speed2: float
    startX, startZ: int32
    runAge: int
  Profile = object
    led, kept, slowed, reversed, lost: int
    runAgeSum: array[4, int]
    runAgeCount: array[4, int]

proc classOf(d: float): int =
  ## 0 kept, 1 slowed, 2 reversed.
  if d >= 3.5: 0 elif d >= 0.5: 1 else: 2

proc analyze(path: string, roster: seq[string], profiles: var Table[string, Profile]) =
  ## Re-simulates one replay and resolves every led order five ticks after it was given.
  let recording = loadRecording(path)
  var
    w = newWorld(recording.seed, recording.endTick)
    previous = w.cogs
    runLength: array[MaxSeats, int]
    runX, runZ: array[MaxSeats, int32]
    pending: seq[Pending]
  for frame in recording.frames:
    let
      before = w.cogs
      tick = w.tick.int
    for i in 0 ..< Seats:
      let c = frame.commands[i]
      if not c.shoot or before[i].hp <= 0 or before[i].cooldown > 1 or w.equipment[i].windup > 0:
        continue
      var
        target = -1
        best = 250_000'i64
      for j in 0 ..< Seats:
        if team(j) != team(i) and before[j].hp > 0:
          let d = distance2(c.aim, before[j].pos)
          if d < best:
            best = d
            target = j
      if target < 0:
        continue
      let
        stepX = (before[target].pos.x - previous[target].pos.x).float
        stepZ = (before[target].pos.z - previous[target].pos.z).float
        speed2 = stepX * stepX + stepZ * stepZ
      if speed2 < 64 or speed2 > 3600:
        continue
      let lead = ((c.aim.x - before[target].pos.x).float * stepX +
        (c.aim.z - before[target].pos.z).float * stepZ) / speed2
      if lead < 1.0:
        continue
      pending.add Pending(shooter: i, target: target, release: tick + 5, stepX: stepX,
        stepZ: stepZ, speed2: speed2, startX: before[target].pos.x, startZ: before[target].pos.z,
        runAge: runLength[target])
    previous = before
    w.step(frame.commands, replayRulesVersion)
    for i in 0 ..< Seats:
      let
        dx = w.cogs[i].pos.x - before[i].pos.x
        dz = w.cogs[i].pos.z - before[i].pos.z
      if w.cogs[i].hp <= 0 or dx * dx + dz * dz < 64:
        runLength[i] = 0
      elif runLength[i] > 0 and dx * runX[i] + dz * runZ[i] > 0:
        inc runLength[i]
      else:
        runLength[i] = 1
      runX[i] = dx
      runZ[i] = dz
    var kept: seq[Pending]
    for p in pending:
      if w.tick.int < p.release:
        kept.add p
        continue
      var prof = addr profiles.mgetOrPut(roster[p.shooter], Profile())
      inc prof.led
      let bucket = min(p.runAge div 5, 3)
      inc prof.runAgeCount[bucket]
      if w.cogs[p.target].hp <= 0 or not w.visible(p.shooter, p.target):
        inc prof.lost
        continue
      let d = ((w.cogs[p.target].pos.x - p.startX).float * p.stepX +
        (w.cogs[p.target].pos.z - p.startZ).float * p.stepZ) / p.speed2
      case classOf(d)
      of 0:
        inc prof.kept
        inc prof.runAgeSum[bucket]
      of 1: inc prof.slowed
      else: inc prof.reversed
    pending = kept

proc main() =
  var replays: seq[string]
  for input in commandLineParams():
    for path in walkDirRec(input):
      if path.endsWith(".replay"):
        replays.add path
  var profiles = initTable[string, Profile]()
  for path in replays:
    let roster = fastRoster(path)
    if roster.len == 16:
      analyze(path, roster, profiles)
  var names = toSeq(profiles.keys)
  names.sort()
  echo "| policy | led shots | target kept going | slowed | reversed | lost from sight |"
  echo "|---|---:|---:|---:|---:|---:|"
  for name in names:
    let p = profiles[name]
    let n = max(p.led, 1).float
    echo &"| {name} | {p.led} | {100.0 * p.kept.float / n:.0f}% | {100.0 * p.slowed.float / n:.0f}% | {100.0 * p.reversed.float / n:.0f}% | {100.0 * p.lost.float / n:.0f}% |"
  echo ""
  echo "Share of led shots whose target kept going, by the target's run age at the order (ticks in its current direction):"
  echo "| policy | run 0-4 | run 5-9 | run 10-14 | run 15+ |"
  echo "|---|---:|---:|---:|---:|"
  for name in names:
    let p = profiles[name]
    var cells: seq[string]
    for b in 0 .. 3:
      if p.runAgeCount[b] == 0:
        cells.add "—"
      else:
        cells.add &"{100.0 * p.runAgeSum[b].float / p.runAgeCount[b].float:.0f}% of {p.runAgeCount[b]}"
    echo &"| {name} | " & cells.join(" | ") & " |"

main()
