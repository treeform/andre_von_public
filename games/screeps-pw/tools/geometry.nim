## Prints the home-room layout of a Screeps PW replay: spawn, sources,
## controller, open tiles around each, and walking distances between them
## for a creep that moves one tile per tick on plain and five on swamp.
## Usage: nim r tools/geometry.nim FILE [room]

import
  std/[deques, json, os, strformat, strutils, tables],
  replays

type
  Spot = object
    name: string
    x, y: int

proc dist(terrain: string, start: Spot, range: int): seq[int] =
  ## Dijkstra over the room; returns the tick cost to every tile.
  result = newSeq[int](2500)
  for i in 0 ..< 2500: result[i] = -1
  var queue: seq[(int, int)]
  queue.add (0, start.y * 50 + start.x)
  result[start.y * 50 + start.x] = 0
  # Simple Dijkstra with a bucket queue over small integer costs.
  var buckets: Table[int, seq[int]]
  buckets[0] = @[start.y * 50 + start.x]
  var d = 0
  var done = newSeq[bool](2500)
  while d < 1000:
    if buckets.hasKey(d):
      let current = buckets[d]
      for index in current:
        if done[index]: continue
        done[index] = true
        let x = index mod 50
        let y = index div 50
        for dx in -1 .. 1:
          for dy in -1 .. 1:
            let nx = x + dx
            let ny = y + dy
            if (dx == 0 and dy == 0) or nx < 0 or ny < 0 or nx > 49 or ny > 49:
              continue
            let next = ny * 50 + nx
            let tile = terrain[next]
            if tile == '1' or tile == '3': continue
            let cost = d + (if tile == '2': 5 else: 1)
            if result[next] == -1 or cost < result[next]:
              result[next] = cost
              buckets.mgetOrPut(cost, @[]).add next
    inc d

proc main() =
  var replay = openReplay(readFile(paramStr(1)))
  let room = if paramCount() >= 2: paramStr(2) else: "W2N2"
  var terrain = ""
  for entry in replay.header["terrain"]:
    if entry.kind == JObject and entry.getOrDefault("room").getStr == room:
      terrain = entry["terrain"].getStr
  if terrain.len != 2500:
    raise newException(ValueError, "No terrain for " & room)
  let state = replay.stateAt(0)
  var spots: seq[Spot]
  for id, entity in state.objects:
    if entity.getOrDefault("room").getStr != room: continue
    let kind = entity["type"].getStr
    if kind in ["spawn", "source", "controller", "mineral"]:
      spots.add Spot(name: kind & "@" & $entity["x"].getInt & "," &
        $entity["y"].getInt, x: entity["x"].getInt, y: entity["y"].getInt)
  for s in spots:
    var open = 0
    var swampy = 0
    for dx in -1 .. 1:
      for dy in -1 .. 1:
        if dx == 0 and dy == 0: continue
        let t = terrain[(s.y + dy) * 50 + s.x + dx]
        if t != '1' and t != '3':
          inc open
          if t == '2': inc swampy
    echo &"{s.name} open={open} swamp={swampy}"
  for a in spots:
    let d = dist(terrain, a, 0)
    var line = a.name & " ->"
    for b in spots:
      if a.name == b.name: continue
      var best = -1
      for dx in -1 .. 1:
        for dy in -1 .. 1:
          let v = d[(b.y + dy) * 50 + b.x + dx]
          if v >= 0 and (best < 0 or v < best): best = v
      line.add &" {b.name}:{best}"
    echo line
  # Print the room with objects marked.
  var grid = newSeq[string](50)
  for y in 0 ..< 50:
    var row = ""
    for x in 0 ..< 50:
      let t = terrain[y * 50 + x]
      row.add (if t == '1' or t == '3': '#' elif t == '2': '~' else: '.')
    grid[y] = row
  for s in spots:
    grid[s.y][s.x] = s.name[0].toUpperAscii
  for y in 0 ..< 50: echo grid[y]

main()
