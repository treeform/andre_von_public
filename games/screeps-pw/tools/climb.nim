## Hill-climbs the per-room build orders on fast-XP. Each run tests one
## W3N3 neighbour (scored on seat 0) and one W2N2 neighbour (seat 1) at
## once; a neighbour that beats its room's best becomes that room's base.
## Neighbours: adjacent swaps, CCMM <-> CCCMMM, one hauler dropped, one
## CCMM inserted. Results go to eps/climb.tsv.
## Usage: nim r tools/climb.nim <rounds>

import
  std/[os, osproc, streams, strformat, strutils]

const
  Root = currentSourcePath().parentDir.parentDir
  Base = Root / "mokosh" / "mokosh.js"
  Rooms = ["W3N3", "W2N2"]

proc orderOf(source, key: string): seq[string] =
  ## Reads one order array from the policy source.
  let start = source.find(key & ": [")
  if start < 0: return
  let stop = source.find("]", start)
  for item in source[start + key.len + 3 ..< stop].split(","):
    let cleaned = item.strip().strip(chars = {'"'})
    if cleaned.len > 0: result.add cleaned

proc orderValue(order: seq[string]): string =
  ## Formats an order as a sweep override value.
  var items: seq[string]
  for item in order: items.add "\"" & item & "\""
  "[" & items.join(", ") & "]"

proc neighbours(base: seq[string]): seq[(string, seq[string])] =
  ## Lists the one-step edits of an order.
  for j in 0 ..< base.len - 1:
    var order = base
    swap(order[j], order[j + 1])
    if order != base: result.add (&"swap{j}", order)
  for j in 2 ..< base.len:
    if not base[j].startsWith("h:"): continue
    var order = base
    order[j] = if base[j] == "h:CCMM": "h:CCCMMM" else: "h:CCMM"
    result.add (&"body{j}", order)
    var shorter = base
    shorter.delete(j)
    result.add (&"drop{j}", shorter)
  for j in 3 .. base.len:
    var order = base
    order.insert("h:CCMM", j)
    result.add (&"add{j}", order)

proc run(tag: string, orders: array[2, seq[string]]): (float, float) =
  ## Runs one sweep with both room orders and returns both seats' scores.
  let process = startProcess(Root / "tools" / "sweep",
    args = [Base, tag, "orderW3N3=" & orderValue(orders[0]),
      "orderW2N2=" & orderValue(orders[1])], options = {poStdErrToStdOut})
  let output = process.outputStream.readAll()
  discard process.waitForExit()
  process.close()
  var scores: seq[float]
  for line in output.splitLines:
    if line.startsWith("seat "): scores.add parseFloat(line.split(" ")[^1])
  if scores.len == 2: (scores[0], scores[1]) else: (0.0, 0.0)

proc main() =
  let rounds = parseInt(paramStr(1))
  let source = readFile(Base)
  var bases: array[2, seq[string]]
  for r in 0 .. 1:
    bases[r] = orderOf(source, "order" & Rooms[r])
    if bases[r].len == 0: bases[r] = orderOf(source, "order")
  var best = run("climb-base", bases)
  let log = Root / "eps" / "climb.tsv"
  var sink = open(log, fmAppend)
  sink.writeLine(&"base\t{best[0]}\t{best[1]}\t{bases[0].join(\" \")}\t{bases[1].join(\" \")}")
  sink.flushFile()
  for round in 0 ..< rounds:
    var improved = false
    let lists = [neighbours(bases[0]), neighbours(bases[1])]
    let count = max(lists[0].len, lists[1].len)
    var i = 0
    while i < count:
      # Two runs at a time, each testing one neighbour per room.
      var processes: seq[Process]
      var tags: seq[string]
      var tried: seq[array[2, (string, seq[string])]]
      for k in 0 .. 1:
        let j = i + k
        if j >= count: break
        var pair: array[2, (string, seq[string])]
        for r in 0 .. 1:
          pair[r] = if j < lists[r].len: lists[r][j] else: ("base", bases[r])
        let tag = &"climb-r{round}-{j}"
        tags.add tag
        tried.add pair
        processes.add startProcess(Root / "tools" / "sweep",
          args = [Base, tag, "orderW3N3=" & orderValue(pair[0][1]),
            "orderW2N2=" & orderValue(pair[1][1])], options = {poStdErrToStdOut})
      for k in 0 ..< processes.len:
        let output = processes[k].outputStream.readAll()
        discard processes[k].waitForExit()
        processes[k].close()
        var scores: seq[float]
        for line in output.splitLines:
          if line.startsWith("seat "): scores.add parseFloat(line.split(" ")[^1])
        if scores.len != 2: scores = @[0.0, 0.0]
        for r in 0 .. 1:
          let name = tried[k][r][0]
          if name == "base": continue
          let current = if r == 0: best[0] else: best[1]
          let keep = scores[r] > current
          sink.writeLine(&"{tags[k]}\t{Rooms[r]}\t{name}\t{scores[r]}\t" &
            (if keep: "KEEP" else: "no") & &"\t{tried[k][r][1].join(\" \")}")
          sink.flushFile()
          if keep:
            if r == 0: best[0] = scores[r] else: best[1] = scores[r]
            bases[r] = tried[k][r][1]
            improved = true
      i += 2
    if not improved: break
  sink.writeLine(&"final\t{best[0]}\t{best[1]}\t{bases[0].join(\" \")}\t{bases[1].join(\" \")}")
  sink.close()
  echo &"final {best[0]} {best[1]}"

main()
