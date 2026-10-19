## Plans Polkan's industry for each built-in PvP map and team, offline.
##
## nim r -d:release --hints:off tools/mplan.nim <brain.bas> <out.bas>
##   <replay> [<replay> ...]
##
## The BASIC API cannot see floors, so sand fields are found here from the
## replay terrain. For each core the planner puts a silicon smelter against
## the core, a straight conveyor trunk out to the best sand field with 2x2
## mechanical drills on both sides, one combustion generator touching the
## smelter, and a ground factory with two generators touching it. The orders
## replace the line "' BLUEPRINT" in the brain and are written to <out.bas>.

import
  std/[algorithm, heapqueue, json, math, os, sequtils, strutils],
  zippy

type
  Kind = enum
    ConveyorKind, DrillKind, SmelterKind, GeneratorKind, FactoryKind, ScatterKind,
    DuoKind
  Order = object
    kind: Kind
    x, y, rotation: int
  Map = object
    width, height: int
    floors, overlays, walls: seq[string]
    cores: seq[(int, int)]
  Plan = object
    orders: seq[Order]
    used: seq[bool]
    drills: int

const
  Steps = [(1, 0), (0, 1), (-1, 0), (0, -1)]
  Rays = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)]

proc fail(message: string) =
  ## Stops with a planner error.
  quit("mplan: " & message, 1)

proc readMap(path: string): Map =
  ## Loads the terrain and the core positions of one replay.
  let data = readFile(path)
  if data.len < 8 or data[0 ..< 4] != "MDR1":
    fail("not an MDR1 replay: " & path)
  var size = 0
  for i in 0 ..< 4:
    size = size or (ord(data[4 + i]) shl (i * 8))
  let
    header = parseJson(data[8 ..< 8 + size])
    map = header["map"]
  result.width = map["width"].getFloat.int
  result.height = map["height"].getFloat.int
  for i in countup(0, map["runs"].len - 2, 2):
    let parts = map["palette"][map["runs"][i + 1].getFloat.int].getStr.split(':')
    for j in 0 ..< map["runs"][i].getFloat.int:
      result.floors.add parts[0]
      result.overlays.add parts[1]
      result.walls.add parts[2]
  let
    chunk = header["chunks"][0]
    start = 8 + size + chunk["offset"].getInt
    frames = parseJson(uncompress(data[start ..< start + chunk["length"].getInt],
      dataFormat = dfGzip))
  for building in frames[0]["buildings"]:
    if building[1].getStr.startsWith("core"):
      result.cores.add (building[2].getFloat.int, building[3].getFloat.int)
  if result.cores.len != 2:
    fail("expected two cores in " & path)

proc index(map: Map, x, y: int): int =
  ## Flattens a tile position.
  y * map.width + x

proc buildable(map: Map, x, y: int): bool =
  ## Tells whether a tile is dry, open ground.
  if x < 0 or y < 0 or x >= map.width or y >= map.height:
    return false
  let
    i = map.index(x, y)
    floor = map.floors[i]
  # Boulders vary by seed and any building replaces them.
  (map.walls[i] == "air" or map.walls[i].contains("boulder")) and
    not floor.contains("water") and
    not floor.contains("tar") and not floor.contains("slag") and
    not floor.contains("cryofluid") and floor != "empty" and
    not floor.contains("space")

proc sandy(map: Map, x, y: int): bool =
  ## Tells whether a tile is a sand floor (ores vary by seed; the bot skips
  ## drills that land on copper, lead or coal at run time).
  map.buildable(x, y) and map.floors[map.index(x, y)].contains("sand")

proc free(map: Map, plan: Plan, x, y: int): bool =
  ## Tells whether a tile is open and not yet claimed by the plan.
  map.buildable(x, y) and not plan.used[map.index(x, y)]

proc fits(map: Map, plan: Plan, x, y, size: int): bool =
  ## Tells whether a block fits at an anchor (Mindustry offset rules).
  let offset = -(size - 1) div 2
  for j in 0 ..< size:
    for i in 0 ..< size:
      if not map.free(plan, x + offset + i, y + offset + j):
        return false
  true

proc claim(map: Map, plan: var Plan, x, y, size: int) =
  ## Marks a block's footprint as used.
  let offset = -(size - 1) div 2
  for j in 0 ..< size:
    for i in 0 ..< size:
      plan.used[map.index(x + offset + i, y + offset + j)] = true

proc sandBlock(map: Map, x, y: int): bool =
  ## Tells whether a 2x2 drill anchored here sits fully on sand.
  map.sandy(x, y) and map.sandy(x + 1, y) and map.sandy(x, y + 1) and
    map.sandy(x + 1, y + 1)

proc trunkPlan(map: Map, base: Plan, sx, sy, face, lane: int): Plan =
  ## Lays one straight trunk out of a smelter face, keeping the best length.
  let
    (fx, fy) = Steps[face]
    (nx, ny) = Steps[(face + 1) mod 4]
    into = (face + 2) mod 4
  var tx, ty: int
  case face
  of 0: (tx, ty) = (sx + 2, sy + lane)
  of 1: (tx, ty) = (sx + lane, sy + 2)
  of 2: (tx, ty) = (sx - 1, sy + lane)
  else: (tx, ty) = (sx + lane, sy - 1)
  var
    trial = base
    trunk: seq[(int, int)]
    drills: seq[(Order, int)]
    x = tx
    y = ty
  while trunk.len < 40 and map.free(trial, x, y):
    map.claim(trial, x, y, 1)
    trunk.add (x, y)
    if trunk.len mod 2 == 0:
      let
        pair = trunk.len div 2 - 1
        (ax, ay) = trunk[^2]
        (bx, by) = trunk[^1]
      for sign in [1, 2]:
        # Side one: tiles one and two steps along +n; side two: along -n.
        let
          s1 = if sign == 1: 1 else: -1
          s2 = if sign == 1: 2 else: -2
          dx = min(min(ax + nx * s1, bx + nx * s1), min(ax + nx * s2, bx + nx * s2))
          dy = min(min(ay + ny * s1, by + ny * s1), min(ay + ny * s2, by + ny * s2))
        if map.sandBlock(dx, dy) and map.fits(trial, dx, dy, 2):
          map.claim(trial, dx, dy, 2)
          drills.add (Order(kind: DrillKind, x: dx, y: dy), pair)
    x += fx
    y += fy
  # Keep the trunk length with the most drills per tile laid.
  var
    bestLength = 0
    bestScore = -1
  for length in countup(2, trunk.len, 2):
    var count = 0
    for (order, pair) in drills:
      if pair * 2 + 1 < length:
        inc count
    let score = count * 100 - length
    if count > 0 and score > bestScore:
      bestScore = score
      bestLength = length
  result = base
  result.drills = 0
  for i in 0 ..< bestLength:
    let (px, py) = trunk[i]
    map.claim(result, px, py, 1)
    result.orders.add Order(kind: ConveyorKind, x: px, y: py, rotation: into)
  for (order, pair) in drills:
    if pair * 2 + 1 < bestLength:
      map.claim(result, order.x, order.y, 2)
      result.orders.add order
      inc result.drills

proc distances(map: Map, plan: Plan, sx, sy, cx, cy, reach: int): seq[int] =
  ## Breadth-first step counts from one tile over free tiles near the core.
  result = newSeq[int](map.width * map.height)
  for i in 0 ..< result.len:
    result[i] = -1
  if not map.free(plan, sx, sy):
    return
  var queue = @[(sx, sy)]
  result[map.index(sx, sy)] = 0
  var head = 0
  while head < queue.len:
    let (x, y) = queue[head]
    inc head
    for (dx, dy) in Steps:
      let
        nx = x + dx
        ny = y + dy
      if abs(nx - cx) > reach or abs(ny - cy) > reach:
        continue
      if map.free(plan, nx, ny) and result[map.index(nx, ny)] < 0:
        result[map.index(nx, ny)] = result[map.index(x, y)] + 1
        queue.add (nx, ny)

proc combDrills(map: Map, plan: var Plan, comb: seq[(int, int)], f: int,
    commit: bool): seq[Order] =
  ## Claims (or only counts) drills on both sides of a comb, pair by pair.
  let (nx, ny) = Steps[(f + 1) mod 4]
  var k = 0
  while k + 1 < comb.len:
    let
      (ax, ay) = comb[k]
      (bx, by) = comb[k + 1]
    for side in [1, -1]:
      let
        s1 = side
        s2 = 2 * side
        dx = min(min(ax + nx * s1, bx + nx * s1), min(ax + nx * s2, bx + nx * s2))
        dy = min(min(ay + ny * s1, by + ny * s1), min(ay + ny * s2, by + ny * s2))
      if map.sandBlock(dx, dy) and map.fits(plan, dx, dy, 2):
        map.claim(plan, dx, dy, 2)
        result.add Order(kind: DrillKind, x: dx, y: dy)
    k += 2
  discard commit

proc combPlan(map: Map, base: Plan, sx, sy, cx, cy: int): Plan =
  ## Lays a comb of drills in the best sand field and routes a belt from it
  ## to the smelter around obstacles (breadth-first search).
  result = base
  result.drills = 0
  var bestScore = -1
  for face in 0 ..< 4:
    for lane in 0 .. 1:
      var tx, ty: int
      case face
      of 0: (tx, ty) = (sx + 2, sy + lane)
      of 1: (tx, ty) = (sx + lane, sy + 2)
      of 2: (tx, ty) = (sx - 1, sy + lane)
      else: (tx, ty) = (sx + lane, sy - 1)
      if abs(tx - cx) <= 2 and abs(ty - cy) <= 2:
        continue
      let into = (face + 2) mod 4
      let reach = 50
      let dist = map.distances(base, tx, ty, cx, cy, reach)
      # Rough pass: score every comb start and direction with the free-map
      # distance, keep the best few for an exact pass.
      var rough: seq[(int, int, int, int)]
      for y in cy - reach .. cy + reach:
        for x in cx - reach .. cx + reach:
          if x < 0 or y < 0 or x >= map.width or y >= map.height:
            continue
          let d = dist[map.index(x, y)]
          if d < 0:
            continue
          for f in 0 ..< 4:
            let (fx, fy) = Steps[f]
            var trial = base
            var comb: seq[(int, int)]
            var px = x
            var py = y
            while comb.len < 24 and map.free(trial, px, py):
              map.claim(trial, px, py, 1)
              comb.add (px, py)
              px -= fx
              py -= fy
            if comb.len < 2:
              continue
            let drills = map.combDrills(trial, comb, f, false).len
            if drills >= 2:
              rough.add (drills * 100 - d - comb.len, x, y, f)
      rough.sort(proc (a, b: (int, int, int, int)): int = cmp(b[0], a[0]))
      for r in 0 ..< min(rough.len, 40):
        let (_, x0, y0, f) = rough[r]
        let (fx, fy) = Steps[f]
        var trial = base
        var comb: seq[(int, int)]
        var px = x0
        var py = y0
        while comb.len < 24 and map.free(trial, px, py):
          map.claim(trial, px, py, 1)
          comb.add (px, py)
          px -= fx
          py -= fy
        let drills = map.combDrills(trial, comb, f, true)
        if drills.len < 2:
          continue
        # Exact route from the smelter's input tile to the comb head,
        # avoiding the comb and its drills.
        var routeBase = trial
        routeBase.used[map.index(x0, y0)] = false
        let exact = map.distances(routeBase, tx, ty, cx, cy, reach)
        let steps = exact[map.index(x0, y0)]
        if steps < 0:
          continue
        # Walk from the comb head down the distance field to the smelter.
        var path = @[(x0, y0)]
        var hx = x0
        var hy = y0
        while (hx, hy) != (tx, ty):
          var moved = false
          for (dx, dy) in Steps:
            let
              nx = hx + dx
              ny = hy + dy
            if nx >= 0 and ny >= 0 and nx < map.width and ny < map.height and
              exact[map.index(nx, ny)] == exact[map.index(hx, hy)] - 1 and
              not moved:
                hx = nx
                hy = ny
                moved = true
          if not moved:
            break
          path.add (hx, hy)
        if (hx, hy) != (tx, ty):
          continue
        let score = drills.len * 100 - path.len - comb.len
        if score <= bestScore:
          continue
        bestScore = score
        var plan = base
        # Route conveyors: each points to the next tile, the last into the
        # smelter. The comb head is path[0].
        for i, (px2, py2) in path:
          var rotation = into
          if i + 1 < path.len:
            let (qx, qy) = path[i + 1]
            for s, (dx, dy) in Steps:
              if qx - px2 == dx and qy - py2 == dy:
                rotation = s
          map.claim(plan, px2, py2, 1)
          plan.orders.add Order(kind: ConveyorKind, x: px2, y: py2,
            rotation: rotation)
        for i in 1 ..< comb.len:
          let (px2, py2) = comb[i]
          map.claim(plan, px2, py2, 1)
          plan.orders.add Order(kind: ConveyorKind, x: px2, y: py2, rotation: f)
        for drill in drills:
          map.claim(plan, drill.x, drill.y, 2)
          plan.orders.add drill
        plan.drills = drills.len
        result = plan

proc planSilicon(map: Map, cx, cy: int, base: Plan): Plan =
  ## Picks the smelter, trunk and drills with the most sand drills.
  result = base
  result.drills = 0
  var bestScore = -1
  for side in 0 ..< 4:
    for along in -3 .. 2:
      var sx, sy: int
      case side
      of 0: (sx, sy) = (cx + 3, cy + along)
      of 1: (sx, sy) = (cx + along, cy + 3)
      of 2: (sx, sy) = (cx - 4, cy + along)
      else: (sx, sy) = (cx + along, cy - 4)
      if not map.fits(base, sx, sy, 2):
        continue
      var withSmelter = base
      map.claim(withSmelter, sx, sy, 2)
      withSmelter.orders.add Order(kind: SmelterKind, x: sx, y: sy)
      var options: seq[Plan]
      for face in 0 ..< 4:
        for lane in 0 .. 1:
          options.add map.trunkPlan(withSmelter, sx, sy, face, lane)
      options.add map.combPlan(withSmelter, sx, sy, cx, cy)
      for plan in options:
        var trunkLength = 0
        for order in plan.orders:
          if order.kind == ConveyorKind:
            inc trunkLength
        let score = plan.drills * 100 - trunkLength
        if plan.drills > 0 and score > bestScore:
          bestScore = score
          result = plan

proc addGenerator(map: Map, plan: var Plan, x, y, size: int): bool =
  ## Places one combustion generator touching a block's footprint.
  let offset = -(size - 1) div 2
  for j in -1 .. size:
    for i in -1 .. size:
      let edge = (i == -1 or i == size) xor (j == -1 or j == size)
      if edge:
        let
          gx = x + offset + i
          gy = y + offset + j
        if map.free(plan, gx, gy):
          map.claim(plan, gx, gy, 1)
          plan.orders.add Order(kind: GeneratorKind, x: gx, y: gy)
          return true
  false

proc facing(x, y, ex, ey: int): int =
  ## Returns the rotation that points from a tile toward the enemy core.
  if abs(ex - x) >= abs(ey - y):
    result = if ex > x: 0 else: 2
  else:
    result = if ey > y: 1 else: 3

proc reserveFront(map: Map, plan: var Plan, x, y, rotation: int): bool =
  ## Claims the 3 x 2 strip in front of a 3x3 factory; false if it is blocked.
  let
    (fx, fy) = Steps[rotation]
    (nx, ny) = Steps[(rotation + 1) mod 4]
  for depth in 2 .. 3:
    for side in -1 .. 1:
      let
        tx = x + fx * depth + nx * side
        ty = y + fy * depth + ny * side
      if not map.free(plan, tx, ty):
        return false
  for depth in 2 .. 3:
    for side in -1 .. 1:
      map.claim(plan, x + fx * depth + nx * side, y + fy * depth + ny * side, 1)
  true

proc planFactory(map: Map, plan: var Plan, cx, cy, ex, ey: int) =
  ## Puts a ground factory close to the core with two generators touching it.
  var
    bestX = -1
    bestY = -1
    bestScore = high(int)
  for y in cy - 12 .. cy + 12:
    for x in cx - 12 .. cx + 12:
      if abs(x - cx) < 5 and abs(y - cy) < 5:
        continue
      if not map.fits(plan, x, y, 3):
        continue
      # Units leave through the face toward the enemy: keep that strip open.
      let rotation = facing(x, y, ex, ey)
      var trial = plan
      map.claim(trial, x, y, 3)
      if not map.reserveFront(trial, x, y, rotation):
        continue
      if not (map.addGenerator(trial, x, y, 3) and map.addGenerator(trial, x, y, 3)):
        continue
      let
        near = (x - cx) * (x - cx) + (y - cy) * (y - cy)
        toward = (x - ex) * (x - ex) + (y - ey) * (y - ey)
        score = near * 50 + toward div 50
      if score < bestScore:
        bestScore = score
        bestX = x
        bestY = y
  if bestX < 0:
    fail("no factory site near " & $cx & "," & $cy)
  let rotation = facing(bestX, bestY, ex, ey)
  map.claim(plan, bestX, bestY, 3)
  discard map.reserveFront(plan, bestX, bestY, rotation)
  plan.orders.add Order(kind: FactoryKind, x: bestX, y: bestY, rotation: rotation)
  discard map.addGenerator(plan, bestX, bestY, 3)
  discard map.addGenerator(plan, bestX, bestY, 3)

proc passable(map: Map, x, y: int): bool =
  ## Tells whether a ground unit can walk a tile (boulders vary by seed).
  if x < 0 or y < 0 or x >= map.width or y >= map.height:
    return false
  let
    i = map.index(x, y)
    floor = map.floors[i]
  (map.walls[i] == "air" or map.walls[i].contains("boulder")) and
    not floor.contains("deep") and floor != "empty" and
    not floor.contains("space")

proc flankRoute(map: Map, cx, cy, ex, ey: int): seq[(int, int)] =
  ## Finds a walking route between the cores that keeps away from the line
  ## joining them, and returns three waypoints along it (30, 55 and 80% of
  ## its steps). A tile within 35 tiles of the line costs up to five steps.
  let
    lx = (ex - cx).float
    ly = (ey - cy).float
    length = sqrt(lx * lx + ly * ly)
  proc lineDistance(x, y: int): float =
    ## Distance from a tile to the core-to-core line.
    abs((x - cx).float * ly - (y - cy).float * lx) / length
  var
    cost = newSeq[float](map.width * map.height)
    previous = newSeq[int](map.width * map.height)
    queue: HeapQueue[(float, int)]
  for i in 0 ..< cost.len:
    cost[i] = Inf
    previous[i] = -1
  # Start from the tile beside our core that faces the enemy.
  let start = map.index(cx, cy)
  cost[start] = 0
  queue.push((0.0, start))
  let goal = map.index(ex, ey)
  while queue.len > 0:
    let (here, i) = queue.pop()
    if here > cost[i]:
      continue
    if i == goal:
      break
    let
      x = i mod map.width
      y = i div map.width
    for (sx, sy) in Steps:
      let
        nx = x + sx
        ny = y + sy
      # Cores are buildings; their own 5x5 footprints count as open.
      let open = map.passable(nx, ny) or
        (abs(nx - cx) <= 2 and abs(ny - cy) <= 2) or
        (abs(nx - ex) <= 2 and abs(ny - ey) <= 2)
      if not open or nx < 0 or ny < 0 or nx >= map.width or ny >= map.height:
        continue
      let
        near = max(0.0, 35 - lineDistance(nx, ny)) / 35
        step = 1 + 4 * near
        j = map.index(nx, ny)
      if here + step < cost[j]:
        cost[j] = here + step
        previous[j] = i
        queue.push((here + step, j))
  if previous[goal] < 0:
    return @[]
  var path: seq[int]
  var at = goal
  while at >= 0:
    path.add at
    at = previous[at]
  path.reverse()
  for fraction in [0.30, 0.55, 0.80]:
    let i = path[int(fraction * (path.len - 1).float)]
    result.add (i mod map.width, i div map.width)

proc main() =
  ## Plans every replay's map for both teams and writes the bot.
  let args = commandLineParams()
  if args.len < 3:
    quit("Usage: mplan <brain.bas> <out.bas> <replay>...", 2)
  var blueprint = ""
  for path in args[2 .. ^1]:
    let map = readMap(path)
    for k in 0 .. 1:
      let
        (cx, cy) = map.cores[k]
        (ex, ey) = map.cores[1 - k]
      var base = Plan(used: newSeq[bool](map.width * map.height))
      map.claim(base, cx, cy, 5)
      var plan = map.planSilicon(cx, cy, base)
      if plan.drills <= 0:
        fail("no sand field near " & $cx & "," & $cy)
      let smelter = plan.orders[0]
      if not map.addGenerator(plan, smelter.x, smelter.y, 2):
        fail("no generator room at the smelter")
      map.planFactory(plan, cx, cy, ex, ey)
      # A second silicon module and a second factory follow the first ones.
      let first = plan.drills
      let firstCount = plan.orders.len
      var second = map.planSilicon(cx, cy, plan)
      if second.drills >= 4:
        let secondSmelter = second.orders[firstCount]
        if map.addGenerator(second, secondSmelter.x, secondSmelter.y, 2):
          plan = second
          plan.drills += first
          # Only a second silicon supply can keep a second factory busy.
          map.planFactory(plan, cx, cy, ex, ey)
      # Four lead-fed Scatters (2x2 flak, air only) around the core: enemy
      # Gammas camp at our base and shred miners and gathering Daggers.
      for (gx, gy) in Steps:
        block placing:
          for reach in 6 .. 10:
            for side in [0, 1, -1, 2, -2, 3, -3]:
              let
                tx = cx + gx * reach + gy * side
                ty = cy + gy * reach + gx * side
              if map.fits(plan, tx, ty, 2):
                map.claim(plan, tx, ty, 2)
                plan.orders.add Order(kind: ScatterKind, x: tx, y: ty)
                break placing
      # Eight copper-fed Duos ring the core. Enemy waves march the mirrored
      # lane past ours and would kill an undefended core first. They are
      # placed last but built right after the first factory.
      var duos: seq[Order]
      for (gx, gy) in Rays:
        block placing:
          for reach in 4 .. 8:
            for side in [0, 1, -1, 2, -2]:
              let
                tx = cx + gx * reach - gy * side
                ty = cy + gy * reach + gx * side
              if map.fits(plan, tx, ty, 1):
                map.claim(plan, tx, ty, 1)
                duos.add Order(kind: DuoKind, x: tx, y: ty)
                break placing
      plan.orders.insert(duos, firstCount)
      # A Scatter chain down our half of the attack route: Gammas that harass
      # marching Daggers die in its 27.5-tile flak umbrella.
      let
        lx = (ex - cx).float
        ly = (ey - cy).float
        length = sqrt(lx * lx + ly * ly)
      for reachTiles in [30, 55, 80]:
        if reachTiles.float > length / 2 - 4:
          continue
        let
          tx0 = cx + int(lx / length * reachTiles.float)
          ty0 = cy + int(ly / length * reachTiles.float)
        block chain:
          for radius in 0 .. 6:
            for dy in -radius .. radius:
              for dx in -radius .. radius:
                if max(abs(dx), abs(dy)) == radius and
                  map.fits(plan, tx0 + dx, ty0 + dy, 2):
                    map.claim(plan, tx0 + dx, ty0 + dy, 2)
                    plan.orders.add Order(kind: ScatterKind, x: tx0 + dx,
                      y: ty0 + dy)
                    break chain
      stderr.writeLine("map ", map.width, "x", map.height, " core ", cx, ",",
        cy, ": smelter ", smelter.x, ",", smelter.y, ", ", plan.drills,
        " sand drills, ", plan.orders.len, " orders")
      blueprint.add "if mapWidth() = " & $map.width & " and coreX() = " & $cx &
        " and coreY() = " & $cy & " then\n"
      # One packed number an order keeps four maps under the 64 KiB source
      # limit: ((kind * 4 + rotation) * 512 + x offset + 256) * 512 +
      # y offset + 256, offsets from the core. The brain unpacks it.
      blueprint.add "  orderCount = " & $plan.orders.len & "\n"
      for i, order in plan.orders:
        let
          dx = order.x - cx + 256
          dy = order.y - cy + 256
        doAssert dx in 0 ..< 512 and dy in 0 ..< 512, "order too far out"
        let packed = ((ord(order.kind) * 4 + order.rotation) * 512 + dx) *
          512 + dy
        blueprint.add "  orderKind(" & $i & ") = " & $packed & "\n"
      # Glacier's centre corridor runs under the enemy Gammas' flight line,
      # so waves take a flank route through these waypoints.
      let flank = if map.height > map.width: map.flankRoute(cx, cy, ex, ey) else: @[]
      blueprint.add "  flankCount = " & $flank.len & "\n"
      for i, (wx, wy) in flank:
        blueprint.add "  flankX(" & $i & ") = " & $wx & "\n"
        blueprint.add "  flankY(" & $i & ") = " & $wy & "\n"
      blueprint.add "end if\n"
  let brain = readFile(args[0])
  if not brain.contains("' BLUEPRINT\n"):
    fail("brain has no BLUEPRINT line")
  writeFile(args[1], brain.replace("' BLUEPRINT\n", blueprint))

main()
