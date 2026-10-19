## Paintbot PW standing spots: where a policy's cogs stand, and what they see from there.
##
##   nim c -d:release -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw/examples/paintbot --path:$HOME/p/paintbot-pw/src \
##     -o:tools/pw_spots tools/pw_spots.nim
##   tools/pw_spots [--from=S] [--to=S] [--cell=M] [--top=N] [--split] <dirs with replays and listing JSON>...
##
## pw_fast directories work too; --split names our side "<tag> win" or "<tag> loss".
##
## Samples every living cog once a second between --from and --to seconds, in Red's frame (a
## Blue cog is turned a half turn about the map centre, so every spot reads as the Red side).
## Per policy it prints the most occupied cells (--cell metres square): share of samples, share
## of those samples with an enemy in view, and the mean terrain height. The cell centre is in
## world units on Red's side, ready to use as a station for a Red cog.

import
  std/[algorithm, json, math, os, sequtils, strformat, strutils, tables],
  game, sim, fastdirs

type
  Cell = object
    samples, seeing: int
    height: float

  Spots = object
    total: int
    cells: Table[(int, int), Cell]

var
  names = initTable[string, string]()
  rosters = initTable[string, seq[string]]()
  fromTick = 5 * TickRate
  toTick = 20 * TickRate
  cellSize = 400
  top = 15
  killsMode = false
  killLines: seq[string]

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

proc cellOf(p: Point): (int, int) =
  ## Returns the grid cell of a point.
  ((p.x.int + 100_000) div cellSize - 100_000 div cellSize,
    (p.z.int + 100_000) div cellSize - 100_000 div cellSize)

proc analyze(path: string, roster: seq[string], spots: var Table[string, Spots]) =
  ## Re-simulates one replay and samples standing spots for both teams.
  let recording = loadRecording(path)
  var w = newWorld(recording.seed, recording.endTick)
  var tags: seq[(int, int)]
  observeTag = proc(tick: int32, victim, attacker: int, pos: Point) =
    tags.add((victim, attacker))
  defer:
    observeTag = nil
  for frame in recording.frames:
    let before = w.cogs
    tags.setLen(0)
    w.step(frame.commands, replayRulesVersion)
    let tick = w.tick.int
    if killsMode and tick >= fromTick and tick <= toTick:
      for (victim, attacker) in tags:
        var
          a = before[attacker].pos
          v = before[victim].pos
        if team(attacker) == 1:
          a = point(Width - a.x.int, Height - a.z.int)
          v = point(Width - v.x.int, Height - v.z.int)
        let range = sqrt(float(distance2(a, v))) / 100
        killLines.add(names.getOrDefault(roster[attacker], roster[attacker]) & " killed " &
          names.getOrDefault(roster[victim], roster[victim]) & " at " & $(tick div TickRate) &
          " s: shooter (" & $(a.x div 100 * 100) & ", " & $(a.z div 100 * 100) & ") h " &
          $terrainHeight(before[attacker].pos.x.int, before[attacker].pos.z.int) & ", victim (" &
          $(v.x div 100 * 100) & ", " & $(v.z div 100 * 100) & ") h " &
          $terrainHeight(before[victim].pos.x.int, before[victim].pos.z.int) & ", " &
          formatFloat(range, ffDecimal, 1) & " m")
    if tick > toTick:
      break
    if tick < fromTick or tick mod TickRate != 0:
      continue
    for i in 0 ..< Seats:
      if w.cogs[i].hp <= 0:
        continue
      var p = w.cogs[i].pos
      if team(i) == 1:
        p = point(Width - p.x.int, Height - p.z.int)
      var seen = false
      for j in countup(1 - team(i), Seats - 1, 2):
        if w.visible(i, j):
          seen = true
          break
      let name = names.getOrDefault(roster[i], roster[i])
      var s = addr spots.mgetOrPut(name, Spots())
      inc s.total
      var c = addr s.cells.mgetOrPut(cellOf(p), Cell())
      inc c.samples
      if seen:
        inc c.seeing
      c.height += terrainHeight(w.cogs[i].pos.x.int, w.cogs[i].pos.z.int).float

proc main() =
  var
    replays: seq[string]
    split = false
  if fileExists("eps/names.txt"):
    for line in lines("eps/names.txt"):
      let parts = line.splitWhitespace
      if parts.len == 2:
        names[parts[0]] = parts[1]
  for argument in commandLineParams():
    if argument.startsWith("--from="):
      fromTick = parseInt(argument[7 .. ^1]) * TickRate
    elif argument.startsWith("--to="):
      toTick = parseInt(argument[5 .. ^1]) * TickRate
    elif argument.startsWith("--cell="):
      cellSize = parseInt(argument[7 .. ^1]) * 100
    elif argument.startsWith("--top="):
      top = parseInt(argument[6 .. ^1])
    elif argument == "--kills":
      killsMode = true
    elif argument == "--split":
      split = true
    else:
      for path in walkDirRec(argument):
        if path.endsWith(".json"):
          try:
            addListing(parseJson(readFile(path)))
          except CatchableError:
            discard
        elif path.endsWith(".replay"):
          replays.add path
  var spots = initTable[string, Spots]()
  for path in replays:
    let id = path.extractFilename.changeFileExt("")
    if id in rosters:
      analyze(path, rosters[id], spots)
    else:
      let roster = fastRoster(path, split)
      if roster.len == 16:
        analyze(path, roster, spots)
  if killsMode:
    for line in killLines:
      echo line
    return
  var order = toSeq(spots.keys)
  order.sort()
  for name in order:
    let s = spots[name]
    var cells = toSeq(s.cells.pairs)
    cells.sort(proc(a, b: ((int, int), Cell)): int = cmp(b[1].samples, a[1].samples))
    var seeing = 0
    for (_, c) in cells:
      seeing += c.seeing
    echo &"## {name}: {s.total} samples, seeing an enemy {100.0 * seeing.float / max(s.total, 1).float:.0f}%"
    echo "| cell centre (Red frame) | share % | seeing % | height |"
    echo "|---|---:|---:|---:|"
    for k in 0 ..< min(top, cells.len):
      let
        (key, c) = cells[k]
        cx = key[0] * cellSize + cellSize div 2
        cz = key[1] * cellSize + cellSize div 2
      echo &"| ({cx}, {cz}) | {100.0 * c.samples.float / s.total.float:.1f} | " &
        &"{100.0 * c.seeing.float / c.samples.float:.0f} | {c.height / c.samples.float:.0f} |"
    echo ""

main()
