## Paintbot PW aim and footwork extractor: how far each policy leads a moving target,
## and how its own cogs move while an enemy is in sight.
##
##   nim c -d:release -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw-0100/examples/paintbot --path:$HOME/p/paintbot-pw-0100/src \
##     --path:tools -o:tools/pw_aim tools/pw_aim.nim
##   tools/pw_aim <pw_fast dirs>...
##
## Lead: at every accepted gun order (cooldown 0 or 1), the target is the enemy nearest
## the aim point; the aim offset from the target is projected on the target's last step,
## giving the lead in ticks (offset / step). Still targets (step under 8 units) are
## counted apart with their mean miss of the aim point.
## Footwork: for every cog with an enemy in sight, each tick is a move or a stand
## (step under 8 units); consecutive moves in the same direction form a run, and a
## run ends by reversing (the new step points back) or by standing.

import
  std/[algorithm, math, os, sequtils, strformat, strutils, tables],
  game, sim, fastdirs

const
  LeadBins = 10
  RunBins = 25

type
  Profile = object
    orders, stillOrders, movingOrders: int
    leadHistogram: array[LeadBins + 1, int]
    stillMiss: float
    contactTicks, standTicks: int
    runHistogram: array[RunBins + 1, int]
    reversals, stops: int

proc leadBin(lead: float): int =
  ## Maps a lead in ticks to a histogram bin; bin 0 holds leads below half a tick.
  clamp(int(round(lead)), 0, LeadBins)

proc analyze(path: string, roster: seq[string], profiles: var Table[string, Profile]) =
  ## Re-simulates one replay and records each seat's orders and footwork.
  let recording = loadRecording(path)
  var
    w = newWorld(recording.seed, recording.endTick)
    previous: array[Seats, Point]
    runLength: array[Seats, int]
    runX, runZ: array[Seats, int]
  for i in 0 ..< Seats:
    previous[i] = w.cogs[i].pos
  for frame in recording.frames:
    let before = w.cogs
    for i in 0 ..< Seats:
      let c = frame.commands[i]
      if not c.shoot or before[i].hp <= 0 or before[i].cooldown > 1:
        continue
      var
        target = -1
        best = int64.high
      for j in 0 ..< Seats:
        if j mod 2 == i mod 2 or before[j].hp <= 0:
          continue
        let d = distance2(c.aim, before[j].pos)
        if d < best:
          best = d
          target = j
      if target < 0 or best > 250_000:
        continue
      var p = addr profiles.mgetOrPut(roster[i], Profile())
      inc p.orders
      let
        stepX = (before[target].pos.x - previous[target].x).float
        stepZ = (before[target].pos.z - previous[target].z).float
        speed2 = stepX * stepX + stepZ * stepZ
        offsetX = (c.aim.x - before[target].pos.x).float
        offsetZ = (c.aim.z - before[target].pos.z).float
      if speed2 < 64:
        inc p.stillOrders
        p.stillMiss += sqrt(offsetX * offsetX + offsetZ * offsetZ)
      else:
        inc p.movingOrders
        inc p.leadHistogram[leadBin((offsetX * stepX + offsetZ * stepZ) / speed2)]
    for i in 0 ..< Seats:
      previous[i] = before[i].pos
    w.step(frame.commands, replayRulesVersion)
    for i in 0 ..< Seats:
      if before[i].hp <= 0 or w.cogs[i].hp <= 0:
        runLength[i] = 0
        continue
      var seen = false
      for j in 0 ..< Seats:
        if j mod 2 != i mod 2 and w.cogs[j].hp > 0 and w.visible(i, j):
          seen = true
          break
      if not seen:
        runLength[i] = 0
        continue
      var p = addr profiles.mgetOrPut(roster[i], Profile())
      inc p.contactTicks
      let
        dx = w.cogs[i].pos.x - before[i].pos.x
        dz = w.cogs[i].pos.z - before[i].pos.z
      if dx * dx + dz * dz < 64:
        inc p.standTicks
        if runLength[i] > 0:
          inc p.stops
          inc p.runHistogram[min(runLength[i], RunBins)]
        runLength[i] = 0
      elif runLength[i] > 0 and dx * runX[i] + dz * runZ[i] > 0:
        inc runLength[i]
        runX[i] = dx
        runZ[i] = dz
      else:
        if runLength[i] > 0:
          inc p.reversals
          inc p.runHistogram[min(runLength[i], RunBins)]
        runLength[i] = 1
        runX[i] = dx
        runZ[i] = dz

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
  for name in names:
    let p = profiles[name]
    echo &"## {name}"
    echo &"gun orders {p.orders}: at a still target {p.stillOrders} (mean miss of the aim point {p.stillMiss / max(p.stillOrders, 1).float:.0f} units), at a moving target {p.movingOrders}"
    var lead: seq[string]
    for b in 0 .. LeadBins:
      lead.add &"{b}:{100.0 * p.leadHistogram[b].float / max(p.movingOrders, 1).float:.0f}%"
    echo "lead in ticks (moving targets): " & lead.join(" ")
    echo &"in sight: {p.contactTicks} ticks, standing {100.0 * p.standTicks.float / max(p.contactTicks, 1).float:.0f}%; runs ended by reversing {p.reversals}, by standing {p.stops}"
    var runs: seq[string]
    let total = max(p.reversals + p.stops, 1).float
    for b in 1 .. RunBins:
      if p.runHistogram[b] > 0:
        runs.add &"{b}:{100.0 * p.runHistogram[b].float / total:.0f}%"
    echo "run length in ticks: " & runs.join(" ")
    echo ""

main()
