## Paintbot PW opening timeline: where each policy's team is and how the
## lives trade in the first minute.
##
##   nim c -d:release -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw/examples/paintbot --path:$HOME/p/paintbot-pw/src \
##     -o:tools/pw_timeline tools/pw_timeline.nim
##   tools/pw_timeline [--bucket=seconds] <dirs with replays and listing JSON>...
##
## pw_fast directories (eps/fast/<tag>) work too: our team is split into
## "<tag> win" and "<tag> loss" lines from eps/fast/<tag>.tsv.
##
## Per policy and 5-second bucket: share of the way from own home to the
## enemy home (0 home, 100 enemy home) of the team centroid, team spread
## (mean distance of living cogs to their centroid), living cogs, lives
## taken and lives lost so far, time spent standing, and heart count.

import
  std/[algorithm, json, math, os, sequtils, strformat, strutils, tables],
  game, sim

const
  Buckets = 16

type
  Timeline = object
    samples: array[Buckets, int]
    progress, spread, alive, taken, lost, hearts, still, shots, hits, seeing: array[Buckets, float]

var
  names = initTable[string, string]()
  rosters = initTable[string, seq[string]]()
  bucketTicks = 5 * TickRate
  shotCount: array[2, int]
  hitCount: array[2, int]

proc addListing(node: JsonNode) =
  ## Records the seat roster of every episode in a listing.
  var entries: seq[JsonNode]
  if node.kind == JArray:
    entries = node.getElems
  elif node.hasKey("entries"):
    entries = node["entries"].getElems
  elif node.hasKey("episodes"):
    entries = node["episodes"].getElems
  for e in entries:
    let ids = e{"policy_version_ids"}
    if ids == nil or ids.kind != JArray:
      continue
    rosters[e["id"].getStr] = ids.getElems.mapIt(it.getStr)

proc analyze(path: string, roster: seq[string], lines: var Table[string, Timeline]) =
  ## Re-simulates one replay and samples both teams every bucket.
  let recording = loadRecording(path)
  var
    w = newWorld(recording.seed, recording.endTick)
    lives: array[2, int]
    stillTicks: array[2, int]
    aliveTicks: array[2, int]
  shotCount = [0, 0]
  hitCount = [0, 0]
  var telemetry: CombatTelemetry
  combatTelemetry = addr telemetry
  observeShot = proc(tick: int32, slot: int) =
    inc shotCount[team(slot)]
  defer:
    combatTelemetry = nil
    observeShot = nil
  for side in 0 .. 1:
    lives[side] = w.teamLives(side).int
  for frame in recording.frames:
    let before = w.cogs
    w.step(frame.commands, replayRulesVersion)
    for i in 0 ..< Seats:
      if before[i].hp > 0 and w.cogs[i].hp > 0:
        inc aliveTicks[team(i)]
        if distance2(before[i].pos, w.cogs[i].pos) <= 16:
          inc stillTicks[team(i)]
    if w.tick mod bucketTicks != 0:
      continue
    let bucket = w.tick div bucketTicks - 1
    if bucket >= Buckets:
      break
    for side in 0 .. 1:
      let
        name = names.getOrDefault(roster[side], roster[side])
        own = home(side)
        enemy = home(1 - side)
      var
        sx, sz, n = 0.0
      for i in countup(side, Seats - 1, 2):
        if w.cogs[i].hp > 0:
          sx += w.cogs[i].pos.x.float
          sz += w.cogs[i].pos.z.float
          n += 1
      var t = addr lines.mgetOrPut(name, Timeline())
      inc t.samples[bucket]
      t.alive[bucket] += n
      if n > 0:
        let
          cx = sx / n
          cz = sz / n
          ax = (enemy.x - own.x).float
          az = (enemy.z - own.z).float
          along = ((cx - own.x.float) * ax + (cz - own.z.float) * az) / (ax * ax + az * az)
        t.progress[bucket] += 100.0 * along
        var spread = 0.0
        for i in countup(side, Seats - 1, 2):
          if w.cogs[i].hp > 0:
            spread += sqrt((w.cogs[i].pos.x.float - cx) ^ 2 + (w.cogs[i].pos.z.float - cz) ^ 2)
        t.spread[bucket] += spread / n / 100.0
      t.taken[bucket] += float(lives[1 - side] - w.teamLives(1 - side))
      t.lost[bucket] += float(lives[side] - w.teamLives(side))
      var owned = 0
      for h in w.controlHearts:
        if h.owner == side.int32:
          inc owned
      t.hearts[bucket] += owned.float
      t.shots[bucket] += shotCount[side].float
      var seeing = 0
      for i in countup(side, Seats - 1, 2):
        if w.cogs[i].hp > 0:
          for j in countup(1 - side, Seats - 1, 2):
            if w.visible(i, j):
              inc seeing
              break
      t.seeing[bucket] += 100.0 * seeing.float / max(n, 1.0)
      t.hits[bucket] += float(telemetry[side].hitsEnemy + telemetry[side + 2].hitsEnemy + telemetry[side + 4].hitsEnemy + telemetry[side + 6].hitsEnemy + telemetry[side + 8].hitsEnemy + telemetry[side + 10].hitsEnemy + telemetry[side + 12].hitsEnemy + telemetry[side + 14].hitsEnemy)
      t.still[bucket] += 100.0 * stillTicks[side].float / max(aliveTicks[side], 1).float
      stillTicks[side] = 0
      aliveTicks[side] = 0

proc fastRoster(path: string, outcomes: var Table[string, bool]): seq[string] =
  ## Names both teams of a pw_fast replay, splitting ours by win or loss.
  let parts = path.split(DirSep)
  if parts.len < 5 or parts[^3] != "games":
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
  if fileExists(table) and (tag & "/") notin outcomes:
    outcomes[tag & "/"] = true
    for line in lines(table):
      let f = line.split('\t')
      if f.len >= 5:
        outcomes[tag & "/" & f[0] & "/" & f[1] & "/" & f[2]] =
          parseFloat(f[3]) > parseFloat(f[4])
  let key = tag & "/" & rival & "/" & side & "/" & $seed
  if key notin outcomes:
    return
  let
    outcome =
      if outcomes[key]:
        " win"
      else:
        " loss"
    ours = tag & outcome
    theirs = rival & " when " & tag & outcome
  if side == "red":
    @[ours, theirs]
  else:
    @[theirs, ours]

proc main() =
  var
    replays: seq[string]
    outcomes = initTable[string, bool]()
  if fileExists("eps/names.txt"):
    for line in lines("eps/names.txt"):
      let parts = line.splitWhitespace
      if parts.len == 2:
        names[parts[0]] = parts[1]
  var inputs: seq[string]
  for argument in commandLineParams():
    if argument.startsWith("--bucket="):
      bucketTicks = parseInt(argument["--bucket=".len .. ^1]) * TickRate
    else:
      inputs.add argument
  for input in inputs:
    for path in walkDirRec(input):
      if path.endsWith(".json"):
        try:
          addListing(parseJson(readFile(path)))
        except CatchableError:
          discard
      elif path.endsWith(".replay"):
        replays.add path
  var lines = initTable[string, Timeline]()
  for path in replays:
    let id = path.extractFilename.changeFileExt("")
    if id in rosters:
      analyze(path, rosters[id], lines)
    else:
      let roster = fastRoster(path, outcomes)
      if roster.len == 2:
        analyze(path, roster, lines)
  var order = toSeq(lines.keys)
  order.sort()
  for name in order:
    let t = lines[name]
    echo &"## {name}"
    echo "| s | games | progress % | spread m | alive | lives taken | lives lost | hearts | standing % | shots | hits | seeing % |"
    echo "|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"
    for b in 0 ..< Buckets:
      let n = t.samples[b]
      if n == 0:
        continue
      let
        m = n.float
        living = t.alive[b] / m
      echo &"| {(b + 1) * bucketTicks div TickRate} | {n} | {t.progress[b] / m:.0f} | {t.spread[b] / m:.1f} | " &
        &"{living:.1f} | {t.taken[b] / m:.1f} | {t.lost[b] / m:.1f} | {t.hearts[b] / m:.1f} | {t.still[b] / m:.0f} | {t.shots[b] / m:.1f} | {t.hits[b] / m:.1f} | {t.seeing[b] / m:.0f} |"
    echo ""

main()
