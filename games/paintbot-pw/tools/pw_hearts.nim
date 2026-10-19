## Paintbot PW heart timeline: which hearts each team holds over time, hearts named by their
## depth (share of the way from the team's own home to the enemy home, nearest 5%).
##
##   nim c -d:release -d:ssl -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw-0124/examples/paintbot --path:$HOME/p/paintbot-pw-0124/src \
##     --path:tools -o:tools/pw_hearts tools/pw_hearts.nim
##   tools/pw_hearts [--bucket=seconds] <dirs with replays and listing JSON>...
##
## pw_fast directories (eps/fast/<tag>) work too: our team is split into "<tag> win" and
## "<tag> loss" lines from eps/fast/<tag>.tsv. Per policy and bucket: mean number of hearts
## held at each depth (mirrored pairs share a depth, so a cell can reach 2), and the total.

import
  std/[algorithm, json, math, os, sequtils, strformat, strutils, tables],
  game, sim

const
  Buckets = 24

type
  HeartLine = object
    samples: array[Buckets, int]
    owned: Table[int, array[Buckets, float]]

var
  names = initTable[string, string]()
  rosters = initTable[string, seq[string]]()
  bucketTicks = 5 * TickRate

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

proc depthKey(side: int, pos: Point): int =
  ## Depth of a point from the side's home toward the enemy home, as a percentage rounded to 5.
  let
    own = home(side)
    enemy = home(1 - side)
    ax = (enemy.x - own.x).float
    az = (enemy.z - own.z).float
    along = ((pos.x - own.x).float * ax + (pos.z - own.z).float * az) / (ax * ax + az * az)
  int(round(along * 20.0)) * 5

proc analyze(path: string, roster: seq[string], lines: var Table[string, HeartLine]) =
  ## Re-simulates one replay and samples both teams' hearts every bucket.
  let recording = loadRecording(path)
  var w = newWorld(recording.seed, recording.endTick)
  for frame in recording.frames:
    w.step(frame.commands, replayRulesVersion)
    if w.tick mod bucketTicks != 0:
      continue
    let bucket = w.tick div bucketTicks - 1
    if bucket >= Buckets:
      break
    for side in 0 .. 1:
      let name = names.getOrDefault(roster[side], roster[side])
      var t = addr lines.mgetOrPut(name, HeartLine())
      inc t.samples[bucket]
      for h in w.controlHearts:
        let key = depthKey(side, h.pos)
        discard t.owned.hasKeyOrPut(key, default(array[Buckets, float]))
        if h.owner == side.int32:
          t.owned[key][bucket] += 1.0

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
  var lines = initTable[string, HeartLine]()
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
    var keys = toSeq(t.owned.keys)
    keys.sort()
    echo &"## {name}"
    echo "| s | games | " & keys.mapIt(&"{it}%").join(" | ") & " | total |"
    echo "|---:|---:|" & keys.mapIt("---:").join("|") & "|---:|"
    for b in 0 ..< Buckets:
      let n = t.samples[b]
      if n == 0:
        continue
      var
        cells: seq[string]
        total = 0.0
      for key in keys:
        let v = t.owned[key][b] / n.float
        total += v
        cells.add &"{v:.2f}"
      echo &"| {(b + 1) * bucketTicks div TickRate} | {n} | " & cells.join(" | ") & &" | {total:.1f} |"
    echo ""

main()
