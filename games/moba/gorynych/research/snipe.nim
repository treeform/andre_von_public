## Ancient-snipe feasibility: which cells can hit an enemy ancient
## (chebyshev <= 5 for the scan, L1 <= 12 for attack()) while sitting
## outside every enemy tower's chebyshev-5 scan square, and can a hero
## walk there from its own fountain without crossing any live enemy
## tower square? Pure map geometry from the vendored game_map.h and the
## static tower table. Not a score source.

import
  std/[deques, os, strutils],
  observations

const
  MapPath = "/Users/me/p/andre_von_auto/sims/moba/vendor/upstream/game_map.h"
  Steps = [(1, 0), (-1, 0), (0, 1), (0, -1),
           (1, -1), (-1, -1), (-1, 1), (1, 1)]
  NeutralCampY = [71.99, 108.15, 102.17, 102.78, 40.75, 39.92, 39.97, 70.78,
                  69.18, 59.52, 99.95, 93.98, 49.86, 31.35, 61.06, 69.92,
                  83.83, 33.98]
  NeutralCampX = [44.75, 74.42, 101.68, 89.92, 73.95, 64.38, 31.66, 95.68,
                  81.11, 34.99, 50.78, 63.65, 59.49, 44.69, 98.67, 28.64,
                  64.88, 51.46]
  AncientIndex = [23, 22]   ## own ancient per team

proc loadWalls(): seq[bool] =
  ## Parses the C byte array; nonzero = wall.
  let text = readFile(MapPath)
  result = newSeq[bool](MapWidth * MapWidth)
  var i = 0
  var pos = text.find('{')
  while true:
    let hexPos = text.find("0x", pos + 1)
    if hexPos < 0 or i >= result.len:
      break
    let value = parseHexInt(text[hexPos .. hexPos + 3])
    result[i] = value != 0
    inc i
    pos = hexPos + 3
  doAssert i == MapWidth * MapWidth, "parsed " & $i & " cells"

proc inTowerSquare(y, x, index: int): bool =
  let (ty, tx) = towerCell(index)
  chebyshev(y, x, ty, tx) <= TowerVision

proc coveredByEnemy(y, x, team: int): bool =
  ## Inside any live shooting enemy tower square (all towers alive).
  for i, tower in Towers:
    if tower.team == team or not shoots(i):
      continue
    if inTowerSquare(y, x, i):
      return true
  false

proc nearCamp(y, x: int, radius: int): bool =
  for i in 0 ..< NeutralCampY.len:
    if chebyshev(y, x, int(NeutralCampY[i]), int(NeutralCampX[i])) <= radius:
      return true
  false

proc bfs(walls: seq[bool], blocked: seq[bool], start: (int, int)): seq[int] =
  result = newSeq[int](MapWidth * MapWidth)
  for i in 0 ..< result.len:
    result[i] = -1
  let s = start[0] * MapWidth + start[1]
  result[s] = 0
  var queue = initDeque[int]()
  queue.addLast(s)
  while queue.len > 0:
    let a = queue.popFirst()
    let y = a div MapWidth
    let x = a mod MapWidth
    for (dy, dx) in Steps:
      let ny = y + dy
      let nx = x + dx
      if ny < 0 or ny >= MapWidth or nx < 0 or nx >= MapWidth:
        continue
      let n = ny * MapWidth + nx
      if result[n] >= 0 or walls[n] or blocked[n]:
        continue
      result[n] = result[a] + 1
      queue.addLast(n)

proc main() =
  var walls = loadWalls()
  var wallCount = 0
  for w in walls:
    if w: inc wallCount
  echo "walls ", wallCount, " of ", walls.len
  for i in 0 ..< TowerCount:
    let (ty, tx) = towerCell(i)
    walls[ty * MapWidth + tx] = true
  let campRadius = if paramCount() >= 1: parseInt(paramStr(1)) else: 6
  for team in 0 .. 1:
    let enemy = 1 - team
    let (ay, ax) = towerCell(AncientIndex[enemy])
    echo "team ", team, " enemy ancient cell (", ay, ",", ax, ")"
    var blocked = newSeq[bool](MapWidth * MapWidth)
    var campBlocked = newSeq[bool](MapWidth * MapWidth)
    for y in 0 ..< MapWidth:
      for x in 0 ..< MapWidth:
        if coveredByEnemy(y, x, team):
          blocked[y * MapWidth + x] = true
          campBlocked[y * MapWidth + x] = true
        elif nearCamp(y, x, campRadius):
          campBlocked[y * MapWidth + x] = true
    let spawn = Spawns[team]
    let plain = bfs(walls, newSeq[bool](MapWidth * MapWidth), spawn)
    let safe = bfs(walls, blocked, spawn)
    let safest = bfs(walls, campBlocked, spawn)
    echo "  plain distance spawn->ancient cell neighbourhood:"
    var found = 0
    for y in ay - 5 .. ay + 5:
      for x in ax - 5 .. ax + 5:
        if y < 0 or x < 0 or y >= MapWidth or x >= MapWidth:
          continue
        let n = y * MapWidth + x
        if walls[n] or coveredByEnemy(y, x, team):
          continue
        if l1(y, x, ay, ax) > 12:
          continue
        inc found
        echo "  snipe cell (", y, ",", x, ") l1=", l1(y, x, ay, ax),
          " plain=", plain[n], " towerSafe=", safe[n],
          " towerAndCampSafe=", safest[n]
    echo "  blind snipe cells: ", found
    # ascii view around the ancient: # wall, T tower, A ancient,
    # . covered empty, o safe empty, * safe snipe cell
    for y in ay - 12 .. ay + 12:
      var line = ""
      for x in ax - 14 .. ax + 14:
        if y < 0 or x < 0 or y >= MapWidth or x >= MapWidth:
          line.add ' '
          continue
        var c = '.'
        let n = y * MapWidth + x
        if walls[n]:
          c = '#'
        for i in 0 ..< TowerCount:
          if towerCell(i) == (y, x):
            c = if Towers[i].tier == 5: 'A' else: 'T'
        if c == '.' and not coveredByEnemy(y, x, team):
          c = 'o'
          if chebyshev(y, x, ay, ax) <= 5 and l1(y, x, ay, ax) <= 12:
            c = '*'
        line.add c
      echo "  ", line

if paramCount() < 1 or paramStr(1) != "grid": main()

## Minimum-exposure route: 0-1 BFS where a tower-covered cell costs 1.

proc exposurePath(walls: seq[bool], team: int, goal: (int, int)): (int, seq[(int, int)], seq[int]) =
  var cost = newSeq[int](MapWidth * MapWidth)
  var parent = newSeq[int](MapWidth * MapWidth)
  for i in 0 ..< cost.len:
    cost[i] = high(int)
    parent[i] = -1
  let start = Spawns[team][0] * MapWidth + Spawns[team][1]
  cost[start] = 0
  var queue = initDeque[int]()
  queue.addLast(start)
  while queue.len > 0:
    let a = queue.popFirst()
    let y = a div MapWidth
    let x = a mod MapWidth
    for (dy, dx) in Steps:
      let ny = y + dy
      let nx = x + dx
      if ny < 0 or ny >= MapWidth or nx < 0 or nx >= MapWidth:
        continue
      let n = ny * MapWidth + nx
      if walls[n]:
        continue
      let w = if coveredByEnemy(ny, nx, team): 1 else: 0
      if cost[a] + w < cost[n]:
        cost[n] = cost[a] + w
        parent[n] = a
        if w == 0: queue.addFirst(n) else: queue.addLast(n)
  var path: seq[(int, int)]
  var node = goal[0] * MapWidth + goal[1]
  let total = cost[node]
  while node >= 0:
    path.add((node div MapWidth, node mod MapWidth))
    node = parent[node]
  var coveringTowers: seq[int]
  for (y, x) in path:
    for i, tower in Towers:
      if tower.team == team or not shoots(i): continue
      if inTowerSquare(y, x, i) and i notin coveringTowers:
        coveringTowers.add i
  (total, path, coveringTowers)

proc routes() =
  var walls = loadWalls()
  for i in 0 ..< TowerCount:
    let (ty, tx) = towerCell(i)
    walls[ty * MapWidth + tx] = true
  for team in 0 .. 1:
    let (ay, ax) = towerCell(AncientIndex[1 - team])
    var best = (high(int), (0, 0))
    for y in ay - 5 .. ay + 5:
      for x in ax - 5 .. ax + 5:
        if walls[y * MapWidth + x] or coveredByEnemy(y, x, team) or l1(y, x, ay, ax) > 12:
          continue
        let (c, _, _) = exposurePath(walls, team, (y, x))
        if c < best[0]:
          best = (c, (y, x))
    let (c, path, covering) = exposurePath(walls, team, best[1])
    echo "team ", team, " best snipe cell ", best[1], " covered cells on route=", c,
      " route length=", path.len - 1, " towers touched=", covering
    var line = ""
    for i in countdown(path.len - 1, 0):
      let (y, x) = path[i]
      let mark = if coveredByEnemy(y, x, team): "!" else: ""
      line.add "(" & $y & "," & $x & mark & ") "
    echo "  ", line

if paramCount() < 1 or paramStr(1) != "grid": routes()

## Weighted route: 1 per step, +TowerPenalty per covered cell,
## +CampPenalty within cheb 6 of a neutral camp centre.

import std/heapqueue

const
  TowerPenalty = 60
  CampPenalty = 8
  LanePenalty = 2

proc nearLane(y, x: int): bool =
  ## Within chebyshev 7 (creep vision) of any lane polyline.
  for lane in 0 .. 5:
    if minLaneDistance(y, x, lane) <= 7.0: return true
  false

type Node = object
  cost: int
  cell: int

proc `<`(a, b: Node): bool = a.cost < b.cost

proc weightedField(walls: seq[bool], team: int, goal: (int, int)): seq[int] =
  ## Dijkstra distances FROM goal over the penalised grid (symmetric costs).
  result = newSeq[int](MapWidth * MapWidth)
  for i in 0 ..< result.len:
    result[i] = high(int)
  let g = goal[0] * MapWidth + goal[1]
  result[g] = 0
  var heap = initHeapQueue[Node]()
  heap.push(Node(cost: 0, cell: g))
  while heap.len > 0:
    let top = heap.pop()
    if top.cost > result[top.cell]:
      continue
    let y = top.cell div MapWidth
    let x = top.cell mod MapWidth
    for (dy, dx) in Steps:
      let ny = y + dy
      let nx = x + dx
      if ny < 0 or ny >= MapWidth or nx < 0 or nx >= MapWidth:
        continue
      let n = ny * MapWidth + nx
      if walls[n]:
        continue
      var w = 1
      if coveredByEnemy(ny, nx, team): w += TowerPenalty
      if nearCamp(ny, nx, 6): w += CampPenalty
      if nearLane(ny, nx): w += LanePenalty
      if top.cost + w < result[n]:
        result[n] = top.cost + w
        heap.push(Node(cost: result[n], cell: n))

proc weightedRoutes() =
  var walls = loadWalls()
  for i in 0 ..< TowerCount:
    let (ty, tx) = towerCell(i)
    walls[ty * MapWidth + tx] = true
  for team in 0 .. 1:
    let goal = if team == 0: (21, 102) else: (101, 14)
    let field = weightedField(walls, team, goal)
    var grid = newSeq[char](MapWidth * MapWidth)
    for y in 0 ..< MapWidth:
      for x in 0 ..< MapWidth:
        let n = y * MapWidth + x
        grid[n] = if walls[n]: '#' elif coveredByEnemy(y, x, team): '.' elif nearCamp(y, x, 6): ',' else: ' '
    for i in 0 ..< TowerCount:
      let (ty, tx) = towerCell(i)
      grid[ty * MapWidth + tx] = if Towers[i].tier == 5: 'A' else: (if Towers[i].team == 0: 'R' else: 'D')
    # descend from spawn
    var (y, x) = Spawns[team]
    var steps = 0
    var covered = 0
    var campy = 0
    while (y, x) != goal and steps < 1000:
      var best = (y, x)
      var bestCost = field[y * MapWidth + x]
      for (dy, dx) in Steps:
        let ny = y + dy
        let nx = x + dx
        if ny < 0 or ny >= MapWidth or nx < 0 or nx >= MapWidth: continue
        let c = field[ny * MapWidth + nx]
        if c < bestCost:
          bestCost = c
          best = (ny, nx)
      if best == (y, x): break
      (y, x) = best
      inc steps
      if coveredByEnemy(y, x, team): inc covered
      if nearCamp(y, x, 6): inc campy
      grid[y * MapWidth + x] = if coveredByEnemy(y, x, team): '!' else: '*'
    echo "team ", team, " goal ", goal, " steps=", steps, " coveredCells=", covered, " campCells=", campy
    for yy in 0 ..< MapWidth:
      var line = ""
      for xx in 0 ..< MapWidth:
        line.add grid[yy * MapWidth + xx]
      echo line

if paramCount() < 1 or paramStr(1) != "grid": weightedRoutes()

## Exact wall/cover grid dump with coordinates: snipe grid y0 y1 x0 x1 team
proc gridDump() =
  if paramCount() < 6 or paramStr(1) != "grid": return
  var walls = loadWalls()
  for i in 0 ..< TowerCount:
    let (ty, tx) = towerCell(i)
    walls[ty * MapWidth + tx] = true
  let y0 = parseInt(paramStr(2)); let y1 = parseInt(paramStr(3))
  let x0 = parseInt(paramStr(4)); let x1 = parseInt(paramStr(5))
  let team = parseInt(paramStr(6))
  var header = "     "
  for x in x0 .. x1: header.add $(x mod 10)
  echo header
  for y in y0 .. y1:
    var line = align($y, 4) & " "
    for x in x0 .. x1:
      let n = y * MapWidth + x
      line.add (if walls[n]: '#' elif coveredByEnemy(y, x, team): '.' else: ' ')
    echo line
gridDump()
