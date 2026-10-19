## Paintbot PW first-sighting aim: does a policy lead a target it has only just seen?
##
##   nim c -d:release -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw-0110/examples/paintbot --path:$HOME/p/paintbot-pw-0110/src \
##     --path:tools -o:tools/pw_firstshot tools/pw_firstshot.nim
##   tools/pw_firstshot <pw_fast dirs>...
##
## For every accepted gun order, the target is the enemy nearest the aim point. The order is
## binned by how many consecutive ticks the shooter has seen that target (1 = first frame).
## Per bin: orders, the share aimed at least one step ahead along the target's true step, and
## the mean lead in steps. A policy that leads on frame 1 knows a velocity it could not see.

import
  std/[algorithm, os, sequtils, strformat, strutils, tables],
  game, sim, fastdirs

const Bins = 6

type
  Profile = object
    orders, led: array[Bins, int]
    leadSum: array[Bins, float]

proc analyze(path: string, roster: seq[string], profiles: var Table[string, Profile]) =
  ## Re-simulates one replay and bins every gun order by sight run length.
  let recording = loadRecording(path)
  var
    w = newWorld(recording.seed, recording.endTick)
    previous = w.cogs
    sightRun: array[MaxSeats, array[MaxSeats, int]]
  for frame in recording.frames:
    let before = w.cogs
    for i in 0 ..< Seats:
      let c = frame.commands[i]
      if not c.shoot or before[i].hp <= 0 or before[i].cooldown > 1:
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
      if target < 0 or sightRun[i][target] == 0:
        continue
      let
        stepX = (before[target].pos.x - previous[target].pos.x).float
        stepZ = (before[target].pos.z - previous[target].pos.z).float
        speed2 = stepX * stepX + stepZ * stepZ
      if speed2 < 64 or speed2 > 3600:
        continue
      let
        lead = ((c.aim.x - before[target].pos.x).float * stepX +
          (c.aim.z - before[target].pos.z).float * stepZ) / speed2
        bin = min(sightRun[i][target], Bins) - 1
      var p = addr profiles.mgetOrPut(roster[i], Profile())
      inc p.orders[bin]
      if lead >= 1.0:
        inc p.led[bin]
      p.leadSum[bin] += clamp(lead, -2.0, 10.0)
    previous = before
    w.step(frame.commands, replayRulesVersion)
    for i in 0 ..< Seats:
      for j in 0 ..< Seats:
        if team(j) != team(i) and w.cogs[i].hp > 0 and w.cogs[j].hp > 0 and w.visible(i, j):
          inc sightRun[i][j]
        else:
          sightRun[i][j] = 0

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
  echo "| policy | sight run | orders at movers | led (>= 1 step) | mean lead |"
  echo "|---|---:|---:|---:|---:|"
  for name in names:
    let p = profiles[name]
    for b in 0 ..< Bins:
      if p.orders[b] == 0:
        continue
      let label = if b == Bins - 1: &"{Bins}+ ticks" else: &"{b + 1} tick(s)"
      echo &"| {name} | {label} | {p.orders[b]} | {100.0 * p.led[b].float / p.orders[b].float:.0f}% | {p.leadSum[b] / p.orders[b].float:.1f} |"

main()
