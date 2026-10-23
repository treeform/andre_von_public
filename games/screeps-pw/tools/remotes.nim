## Ranks the sources outside each home room by walking cost from that
## home's controller, over the real 0.1.11 terrain stored in a replay.
## The 4x4 world becomes one 200x200 grid (W4N4 top left); plain costs 1,
## swamp 5, walls block, matching a creep with one MOVE per other part.
## Usage: nim r tools/remotes.nim <replay>

import
  std/[algorithm, heapqueue, json, os, strformat, strutils, tables],
  replays

const
  Size = 200

proc roomXY(room: string): (int, int) =
  ## Returns the grid origin of a room name like W3N2.
  let w = parseInt(room[1 .. room.find('N') - 1])
  let n = parseInt(room[room.find('N') + 1 .. ^1])
  ((4 - w) * 50, (4 - n) * 50)

proc main() =
  var replay = openReplay(readFile(paramStr(1)))
  var grid = newSeq[char](Size * Size)
  for i in 0 ..< grid.len: grid[i] = '1'
  for entry in replay.header["terrain"]:
    let room = entry["room"].getStr
    let (ox, oy) = roomXY(room)
    let tiles = entry["terrain"].getStr
    for y in 0 ..< 50:
      for x in 0 ..< 50:
        grid[(oy + y) * Size + ox + x] = tiles[y * 50 + x]
  let state = replay.stateAt(0)
  var sources: seq[(string, int, int, int)]
  var controllers: Table[string, (int, int)]
  for id, entity in state.objects:
    let kind = entity.getOrDefault("type").getStr
    let room = entity.getOrDefault("room").getStr
    if kind == "source":
      sources.add (room, entity["x"].getInt, entity["y"].getInt,
        entity["energyCapacity"].getInt)
    if kind == "controller":
      controllers[room] = (entity["x"].getInt, entity["y"].getInt)
  for home in ["W3N3", "W2N2"]:
    let (ox, oy) = roomXY(home)
    let (cx, cy) = controllers[home]
    var dist = newSeq[int](Size * Size)
    for i in 0 ..< dist.len: dist[i] = high(int)
    var queue = initHeapQueue[(int, int)]()
    let start = (oy + cy) * Size + ox + cx
    dist[start] = 0
    queue.push (0, start)
    while queue.len > 0:
      let (d, index) = queue.pop()
      if d > dist[index]: continue
      let x = index mod Size
      let y = index div Size
      for dx in -1 .. 1:
        for dy in -1 .. 1:
          if dx == 0 and dy == 0: continue
          let nx = x + dx
          let ny = y + dy
          if nx < 0 or ny < 0 or nx >= Size or ny >= Size: continue
          let tile = grid[ny * Size + nx]
          if tile == '1' or tile == '3': continue
          let cost = d + (if tile == '2': 5 else: 1)
          let next = ny * Size + nx
          if cost < dist[next]:
            dist[next] = cost
            queue.push (cost, next)
    var rows: seq[(int, string)]
    for (room, sx, sy, capacity) in sources:
      if room == home: continue
      let (rx, ry) = roomXY(room)
      var best = high(int)
      var spots = 0
      for dx in -1 .. 1:
        for dy in -1 .. 1:
          if dx == 0 and dy == 0: continue
          let index = (ry + sy + dy) * Size + rx + sx + dx
          let tile = grid[index]
          if tile == '1' or tile == '3': continue
          inc spots
          best = min(best, dist[index])
      if best == high(int): continue
      rows.add (best, &"{room} ({sx},{sy}) cost={best} spots={spots} capacity={capacity}")
    rows.sort()
    echo home, " controller ", cx, ",", cy
    for (cost, line) in rows[0 ..< min(6, rows.len)]: echo "  ", line

main()
