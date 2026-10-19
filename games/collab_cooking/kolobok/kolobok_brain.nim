## The Collab Cooking scripted brain and plan executor, ported to Nim from
## Metta-AI/cogame-collab-cooking `src/collab_cooking/agent/brain/*` and
## `kitchens/layouts.py` (MIT). The four baselines (brigade / runner /
## passer / courier) are the same brain with one parameter changed; the
## plan directive — station / recipe / zone / handoff / yield_to — is what
## an LLM plan turn hands down, and this executor turns it into exactly one
## legal mettagrid action per tick.

import std/[algorithm, deques, hashes, heapqueue, json, sets, strutils,
  tables]

type Vec* = tuple[row, col: int]

## Resource names (the game's inventory vocabulary).
const
  Veg = "veg"
  Meat = "meat"
  ChoppedVeg = "chopped_veg"
  ChoppedMeat = "chopped_meat"
  ChopVegProgress = "chop_veg_progress"
  ChopMeatProgress = "chop_meat_progress"
  CleanPlate = "clean_plate"
  DirtyPlate = "dirty_plate"
  WashProgress = "wash_progress"
  DishSalad = "dish_salad"
  DishSoup = "dish_soup"
  DishFries = "dish_fries"
  QueueSalad = "queue_salad"
  QueueSoup = "queue_soup"
  QueueFries = "queue_fries"
  PotSoupCooking = "pot_soup_cooking"
  PotSoupReady = "pot_soup_ready"
  PotSoupBurned = "pot_soup_burned"
  FryerFriesCooking = "fryer_fries_cooking"
  FryerFriesReady = "fryer_fries_ready"
  FryerFriesBurned = "fryer_fries_burned"

  BaseAgentResources = [
    Veg, Meat, ChoppedVeg, ChoppedMeat, CleanPlate, DirtyPlate,
    DishSalad, DishSoup, DishFries
  ]
  RecipePriority = ["soup", "fries", "salad"]

  ## A cog whose tile AND inventory are unchanged this long is hammering a
  ## station that cannot accept what it holds.
  StallTicks = 20

  BaselineNames* = ["brigade", "runner", "passer", "courier"]
  DefaultBaseline* = "brigade"

proc queueResource(recipe: string): string =
  case recipe
  of "soup": QueueSoup
  of "fries": QueueFries
  else: QueueSalad

proc dishResource(recipe: string): string =
  case recipe
  of "soup": DishSoup
  of "fries": DishFries
  else: DishSalad

## The eight kitchens (hand-authored fixed grids; docs/kitchens.md).
proc kitchenGrid(layout: string): seq[string] =
  case layout
  of "cramped": @[
    "###V#M###",
    "#...@...#",
    "#B.....X#",
    "#.@...@.#",
    "#L.....O#",
    "#...@...#",
    "###W#S#F#"]
  of "forced": @[
    "##V#M########",
    "#.....#.....#",
    "#..@..#..@..#",
    "#X....#....O#",
    "#.....B.....#",
    "#L....#....F#",
    "#..@..#..@..#",
    "#.....#.....#",
    "####W####S###"]
  of "crowded": @[
    "##V#M##B###",
    "#.@..#..@.#",
    "#X...#...O#",
    "#.........#",
    "#L...#...F#",
    "#.@..#..@.#",
    "##W####S###"]
  of "asymmetric": @[
    "###V#M#####B###",
    "#.............#",
    "#..@..###..@..#",
    "#X....###....O#",
    "#.....###....F#",
    "#L....###....S#",
    "#..@..###..@..#",
    "#.............#",
    "#####W#########"]
  of "circuit": @[
    "###V#M###B#####",
    "#.............#",
    "#..@.......@..#",
    "#X..#######..O#",
    "#..@.......@..#",
    "#.............#",
    "####L###W#S#F##"]
  of "ring": @[
    "###V#M#B###",
    "#..@...@..#",
    "#.#######.#",
    "X.#######.O",
    "#.#######.#",
    "L.#######.F",
    "#.#######.#",
    "#..@...@..#",
    "###W#S#####"]
  of "figure-eight": @[
    "####V#M#B######",
    "#.@.........@.#",
    "#.#####.#####.#",
    "X.#####.#####.O",
    "#.#####.#####.#",
    "L.#####.#####.#",
    "#.#####.#####.#",
    "#.@.........@.#",
    "####W###S######"]
  else: @[
    "#####V#M#####",
    "#...........#",
    "#..@.....@..#",
    "#B..#####..X#",
    "#...#####...#",
    "#L..#####..O#",
    "#..@.....@..#",
    "#...........#",
    "#####W#S#F###"]

const stationByPlanName = {
  "veg": "veg_station",
  "meat": "meat_station",
  "plate": "plate_station",
  "chop": "chopping_station",
  "pot": "cooking_station",
  "fryer": "fryer_station",
  "pass": "serving_station",
  "sink": "wash_station",
  "board": "order_board"
}.toTable

proc layoutDimensions(layout: string): tuple[width, height: int] =
  let rows = kitchenGrid(layout)
  (rows[0].len, rows.len)

proc openTiles(layout: string): HashSet[Vec] =
  let rows = kitchenGrid(layout)
  for r, row in rows:
    for c, ch in row:
      if ch in {'.', '@'}:
        result.incl((r, c))

proc layoutSpawns(layout: string): seq[Vec] =
  let rows = kitchenGrid(layout)
  for r, row in rows:
    for c, ch in row:
      if ch == '@':
        result.add((r, c))

proc layoutCounters(layout: string): HashSet[Vec] =
  let rows = kitchenGrid(layout)
  for r, row in rows:
    for c, ch in row:
      if ch == '#':
        result.incl((r, c))

proc dividerCounters(layout: string): HashSet[Vec] =
  ## Counter cells with an open tile on BOTH sides — in `forced` and
  ## `crowded` exactly the divider, the only way an item crosses.
  let tiles = openTiles(layout)
  for pos in layoutCounters(layout):
    let (r, c) = pos
    if ((r - 1, c) in tiles and (r + 1, c) in tiles) or
        ((r, c - 1) in tiles and (r, c + 1) in tiles):
      result.incl(pos)

proc passCounters(layout: string): HashSet[Vec] =
  ## The `zone: "pass"` target set: the divider plus every interior counter
  ## with an open tile beside it. Empty for `cramped`.
  let (width, height) = layoutDimensions(layout)
  let tiles = openTiles(layout)
  result = dividerCounters(layout)
  for pos in layoutCounters(layout):
    let (r, c) = pos
    if r == 0 or r == height - 1 or c == 0 or c == width - 1:
      continue
    for neighbour in [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)]:
      if neighbour in tiles:
        result.incl(pos)
        break

proc zoneOf(layout: string, pos: Vec): string =
  let (width, _) = layoutDimensions(layout)
  if pos.col < width div 2: "left" else: "right"

proc inZone(layout: string, pos: Vec, zone: string): bool =
  if zone == "any":
    return true
  if zone == "pass":
    let staging = passCounters(layout)
    return staging.len == 0 or pos in staging
  zoneOf(layout, pos) == zone

## Sparse entity map.
type
  Entity* = object
    entityType*: string
    properties*: Table[string, int]
    lastSeen*: int

  EntityMap* = object
    entities*: Table[Vec, Entity]
    explored*: HashSet[Vec]
    step: int

proc isWithinObsShape(dr, dc, hr, hc: int): bool =
  ## Elliptical observation mask matching mettagrid's C++ implementation.
  if hr == 0 and hc == 0:
    return dr == 0 and dc == 0
  if hr == 0:
    return dr == 0 and abs(dc) <= hc
  if hc == 0:
    return dc == 0 and abs(dr) <= hr
  let
    r2 = dr * dr
    c2 = dc * dc
    hr2 = hr * hr
    hc2 = hc * hc
  if hr == hc:
    let d2 = r2 + c2
    if d2 <= hr2:
      return true
    return hr >= 2 and d2 == hr2 + 1 and (abs(dr) == hr or abs(dc) == hc)
  r2 * hc2 + c2 * hr2 <= hr2 * hc2

proc updateFromObservation*(
  map: var EntityMap,
  agentPos: Vec,
  obsHalfH, obsHalfW: int,
  visible: Table[Vec, Entity],
  step: int
) =
  map.step = step
  var observed: HashSet[Vec]
  for dr in -obsHalfH .. obsHalfH:
    for dc in -obsHalfW .. obsHalfW:
      if not isWithinObsShape(dr, dc, obsHalfH, obsHalfW):
        continue
      let pos = (agentPos.row + dr, agentPos.col + dc)
      map.explored.incl(pos)
      observed.incl(pos)
  var stale: seq[Vec]
  for pos in map.entities.keys:
    if pos in observed and pos notin visible:
      stale.add(pos)
  for pos in stale:
    map.entities.del(pos)
  for pos, entity in visible:
    var updated = entity
    updated.lastSeen = step
    map.entities[pos] = updated

proc find*(map: EntityMap, typeName: string): seq[(Vec, Entity)] =
  for pos, entity in map.entities:
    if entity.entityType == typeName:
      result.add((pos, entity))

proc manhattan*(a, b: Vec): int =
  abs(a.row - b.row) + abs(a.col - b.col)

proc findNearest*(
  map: EntityMap, fromPos: Vec, typeName: string
): tuple[found: bool, pos: Vec] =
  var bestDist = high(int)
  for pos, entity in map.entities:
    if entity.entityType != typeName:
      continue
    let dist = manhattan(pos, fromPos)
    if dist < bestDist:
      bestDist = dist
      result = (true, pos)

proc isWall(map: EntityMap, pos: Vec): bool =
  pos in map.entities and map.entities[pos].entityType == "wall"

proc isStructure(map: EntityMap, pos: Vec): bool =
  pos in map.entities and
    map.entities[pos].entityType notin ["wall", "agent"]

proc isFree(map: EntityMap, pos: Vec): bool =
  pos in map.explored and pos notin map.entities

proc hasAgent(map: EntityMap, pos: Vec): bool =
  pos in map.entities and map.entities[pos].entityType == "agent" and
    map.step - map.entities[pos].lastSeen <= 2

## Deterministic A* navigator.
const
  MoveNames = ["north", "east", "south", "west"]
  MoveDeltas: array[4, Vec] = [(-1, 0), (0, 1), (1, 0), (0, -1)]

proc deltaOf(direction: string): Vec =
  for i, name in MoveNames:
    if name == direction:
      return MoveDeltas[i]
  (0, 0)

type Navigator* = object
  cachedPath: seq[Vec]
  cachedTarget: Vec
  hasCachedTarget: bool
  history: seq[Vec]
  preferredDirection*: string

proc moveActionName(current, target: Vec): string =
  let dr = target.row - current.row
  let dc = target.col - current.col
  if dr == -1 and dc == 0: return "move_north"
  if dr == 1 and dc == 0: return "move_south"
  if dr == 0 and dc == 1: return "move_east"
  if dr == 0 and dc == -1: return "move_west"
  "noop"

proc moveToward*(current, target: Vec): string =
  let dr = target.row - current.row
  let dc = target.col - current.col
  if dr == 1 and dc == 0: return "move_south"
  if dr == -1 and dc == 0: return "move_north"
  if dr == 0 and dc == 1: return "move_east"
  if dr == 0 and dc == -1: return "move_west"
  if abs(dr) >= abs(dc):
    return (if dr > 0: "move_south" else: "move_north")
  (if dc > 0: "move_east" else: "move_west")

proc orderedDirections(navigator: Navigator, bias: string): seq[string] =
  var preferred = bias
  if preferred notin MoveNames:
    preferred = navigator.preferredDirection
  if preferred notin MoveNames:
    preferred = "east"
  result.add(preferred)
  for direction in MoveNames:
    if direction != preferred:
      result.add(direction)

proc track(navigator: var Navigator, pos: Vec) =
  navigator.history.add(pos)
  if navigator.history.len > 30:
    navigator.history.delete(0)

proc isStuck(navigator: Navigator): bool =
  let history = navigator.history
  if history.len >= 6:
    var recent: HashSet[Vec]
    for i in history.len - 6 ..< history.len:
      recent.incl(history[i])
    if recent.len <= 2:
      return true
  if history.len >= 20:
    var count = 0
    for i in 0 ..< history.len - 10:
      if history[i] == history[^1]:
        inc count
    if count >= 2:
      return true
  false

proc walkable(
  navigator: Navigator, pos: Vec, map: EntityMap, allowUnknown: bool
): bool =
  if map.isWall(pos) or map.isStructure(pos) or map.hasAgent(pos):
    return false
  if pos in map.explored:
    return pos notin map.entities or map.entities[pos].entityType == "agent"
  allowUnknown

proc fallbackMove(
  navigator: var Navigator, pos: Vec, map: EntityMap, bias: string
): string =
  for direction in navigator.orderedDirections(bias):
    let delta = deltaOf(direction)
    let next = (pos.row + delta.row, pos.col + delta.col)
    if navigator.walkable(next, map, false):
      return "move_" & direction
  "noop"

proc breakStuck(
  navigator: var Navigator, pos: Vec, map: EntityMap
): string =
  navigator.cachedPath = @[]
  navigator.hasCachedTarget = false
  navigator.history = @[]
  navigator.fallbackMove(pos, map, "")

proc goalCells(
  navigator: Navigator, target: Vec, map: EntityMap, reachAdjacent: bool
): seq[Vec] =
  if not reachAdjacent:
    return @[target]
  for delta in MoveDeltas:
    let cell = (target.row + delta.row, target.col + delta.col)
    if map.isWall(cell) or map.isStructure(cell) or map.hasAgent(cell):
      continue
    result.add(cell)

proc astar(
  navigator: Navigator,
  start: Vec,
  goals: seq[Vec],
  map: EntityMap,
  allowUnknown: bool
): seq[Vec] =
  var goalSet: HashSet[Vec]
  for goal in goals:
    goalSet.incl(goal)

  proc heuristic(pos: Vec): int =
    result = high(int)
    for goal in goals:
      result = min(result, manhattan(pos, goal))

  var
    tieBreaker = 0
    heap = initHeapQueue[(int, int, int, int)]()
    cameFrom: Table[Vec, Vec]
    hasParent: Table[Vec, bool]
    gScore: Table[Vec, int]
  heap.push((heuristic(start), 0, start.row, start.col))
  hasParent[start] = false
  gScore[start] = 0

  for iteration in 0 ..< 5000:
    if heap.len == 0:
      break
    let entry = heap.pop()
    let current: Vec = (entry[2], entry[3])
    if current in goalSet:
      var path: seq[Vec]
      var cursor = current
      while hasParent.getOrDefault(cursor, false):
        path.add(cursor)
        cursor = cameFrom[cursor]
      path.reverse()
      return path
    let currentG = gScore.getOrDefault(current, 9999999)
    for delta in MoveDeltas:
      let neighbour: Vec = (current.row + delta.row, current.col + delta.col)
      if neighbour notin goalSet and
          not navigator.walkable(neighbour, map, allowUnknown):
        continue
      let nextG = currentG + 1
      if nextG < gScore.getOrDefault(neighbour, 9999999):
        cameFrom[neighbour] = current
        hasParent[neighbour] = true
        gScore[neighbour] = nextG
        inc tieBreaker
        heap.push((nextG + heuristic(neighbour), tieBreaker,
          neighbour.row, neighbour.col))
  @[]

proc getPath(
  navigator: var Navigator,
  start, target: Vec,
  map: EntityMap,
  reachAdjacent: bool
): seq[Vec] =
  if navigator.cachedPath.len > 0 and navigator.hasCachedTarget and
      navigator.cachedTarget == target:
    return navigator.cachedPath
  let goals = navigator.goalCells(target, map, reachAdjacent)
  if goals.len == 0:
    return @[]
  var path = navigator.astar(start, goals, map, false)
  if path.len == 0:
    path = navigator.astar(start, goals, map, true)
  navigator.cachedPath = path
  navigator.cachedTarget = target
  navigator.hasCachedTarget = true
  path

proc sidestep(
  navigator: Navigator,
  current, blocked, target: Vec,
  map: EntityMap
): tuple[found: bool, pos: Vec] =
  let currentDist = manhattan(current, target)
  var candidates: seq[(int, int, Vec)]
  for i, delta in MoveDeltas:
    let pos: Vec = (current.row + delta.row, current.col + delta.col)
    if pos == blocked:
      continue
    if navigator.walkable(pos, map, true):
      candidates.add((manhattan(pos, target) - currentDist, i, pos))
  if candidates.len > 0:
    candidates.sort()
    if candidates[0][0] <= 2:
      return (true, candidates[0][2])
  (false, (0, 0))

proc greedy(
  navigator: var Navigator, current, target: Vec, map: EntityMap
): string =
  let dr = target.row - current.row
  let dc = target.col - current.col
  var primary, secondary: string
  if abs(dr) >= abs(dc):
    primary = (if dr > 0: "south" else: "north")
    secondary = (if dc > 0: "east" else: "west")
  else:
    primary = (if dc > 0: "east" else: "west")
    secondary = (if dr > 0: "south" else: "north")
  for direction in [primary, secondary]:
    let delta = deltaOf(direction)
    let pos = (current.row + delta.row, current.col + delta.col)
    if not map.isWall(pos) and not map.isStructure(pos) and
        not map.hasAgent(pos):
      return "move_" & direction
  navigator.fallbackMove(current, map, "")

proc getAction*(
  navigator: var Navigator,
  pos, target: Vec,
  map: EntityMap,
  reachAdjacent = false
): string =
  navigator.track(pos)
  if navigator.isStuck():
    return navigator.breakStuck(pos, map)
  if pos == target and not reachAdjacent:
    return "noop"
  if reachAdjacent and manhattan(pos, target) == 1:
    return "noop"
  let path = navigator.getPath(pos, target, map, reachAdjacent)
  if path.len == 0:
    return navigator.greedy(pos, target, map)
  let next = path[0]
  if map.hasAgent(next):
    let side = navigator.sidestep(pos, next, target, map)
    if side.found:
      navigator.cachedPath = @[]
      return moveActionName(pos, side.pos)
    return "noop"
  navigator.cachedPath = path[1 .. ^1]
  moveActionName(pos, next)

proc frontier(
  navigator: Navigator, pos: Vec, map: EntityMap, bias: string
): tuple[found: bool, pos: Vec] =
  var deltas: seq[Vec]
  for direction in navigator.orderedDirections(bias):
    deltas.add(deltaOf(direction))
  var visited: HashSet[Vec]
  visited.incl(pos)
  var queue = initDeque[(Vec, int)]()
  queue.addLast((pos, 0))
  while queue.len > 0:
    let (current, dist) = queue.popFirst()
    if dist > 50:
      continue
    for delta in deltas:
      let p: Vec = (current.row + delta.row, current.col + delta.col)
      if p in visited:
        continue
      visited.incl(p)
      if p notin map.explored:
        for delta2 in deltas:
          let adjacent: Vec = (p.row + delta2.row, p.col + delta2.col)
          if adjacent in map.explored and map.isFree(adjacent):
            return (true, p)
        continue
      if map.isFree(p):
        queue.addLast((p, dist + 1))
  (false, (0, 0))

proc explore*(
  navigator: var Navigator, pos: Vec, map: EntityMap, bias = ""
): string =
  navigator.track(pos)
  if navigator.isStuck():
    return navigator.breakStuck(pos, map)
  let front = navigator.frontier(pos, map, bias)
  if front.found:
    return navigator.getAction(pos, front.pos, map)
  navigator.fallbackMove(pos, map, bias)

## The brain.
type
  PlanDirective* = object
    turn*: int
    station*: string
    recipe*: string
    zone*: string
    handoff*: string
    yieldTo*: string
    say*: string
    src*: string

  KitchenBrain* = object
    agentId: int
    numAgents: int
    layout: string
    baseline*: string
    role: string
    obsHalfH, obsHalfW: int
    featureNames: Table[int, string]
    tagNames: seq[string]
    origin: Vec
    passStaging: HashSet[Vec]   ## divider counters, spawn-relative
    ## Mutable per-episode state.
    step: int
    position: Vec
    inventory: Table[string, int]
    entityMap: EntityMap
    navigator: Navigator
    recipePreference: string
    boardLastSeenStep: int
    hasLastPos: bool
    lastPos: Vec
    lastAction: string
    failedMoves: int
    friesBootstrapDone: bool
    activeStationTask: string   ## "", "chop_veg", "chop_meat", "wash"
    currentTask*: string
    hasPlan: bool
    plan: PlanDirective
    idleTicks: int
    lastInventoryKey: string

proc assignRole(agentId, numAgents: int): string =
  if numAgents <= 1:
    return "all_rounder"
  if numAgents == 2:
    return (if agentId == 0: "cook" else: "server")
  if numAgents == 3:
    return ["prep", "cook", "server"][agentId]
  case agentId
  of 0: "prep"
  of 1: "cook"
  of 2: "server"
  else: "all_rounder"

proc baselineRole(baseline: string, agentId, numAgents: int): string =
  if baseline == "runner":
    return "all_rounder"
  if baseline == "courier":
    return "server"
  assignRole(agentId, numAgents)

proc preferredDirection(agentId: int): string =
  ["east", "west", "north", "north"][agentId mod 4]

proc toAbsolute(brain: KitchenBrain, pos: Vec): Vec =
  (pos.row + brain.origin.row, pos.col + brain.origin.col)

proc toRelative(brain: KitchenBrain, pos: Vec): Vec =
  (pos.row - brain.origin.row, pos.col - brain.origin.col)

proc initKitchenBrain*(
  playerConfig: JsonNode, agentId: int, baseline: string
): KitchenBrain =
  result.agentId = agentId
  result.baseline =
    if baseline in BaselineNames: baseline else: DefaultBaseline
  result.layout = playerConfig{"layout"}.getStr("open-kitchen")
  let policyEnv = playerConfig{"policy_env"}
  result.numAgents = policyEnv{"num_agents"}.getInt(4)
  let shape = policyEnv{"egocentric_shape"}
  result.obsHalfH = shape{0}.getInt(13) div 2
  result.obsHalfW = shape{1}.getInt(13) div 2
  for spec in policyEnv{"obs_features"}.getElems():
    result.featureNames[spec{"id"}.getInt()] = spec{"name"}.getStr()
  for tag in policyEnv{"tags"}.getElems():
    result.tagNames.add(tag.getStr())
  result.role = baselineRole(result.baseline, agentId, result.numAgents)
  # mettagrid's `local_position` is the displacement from this seat's
  # SPAWN, so the whole brain lives in a spawn-relative frame; spawns are
  # assigned in the kitchen's reading order.
  let spawnList = layoutSpawns(result.layout)
  result.origin = spawnList[agentId mod spawnList.len]
  for pos in dividerCounters(result.layout):
    result.passStaging.incl(result.toRelative(pos))
  result.navigator.preferredDirection = preferredDirection(agentId)
  result.recipePreference = "salad"
  result.lastAction = "noop"

## Inventory helpers.
proc get(inventory: Table[string, int], key: string): int =
  inventory.getOrDefault(key, 0)

proc holdingAnyItem(inventory: Table[string, int]): bool =
  for resource in BaseAgentResources:
    if inventory.get(resource) > 0:
      return true
  false

proc heldItemResource(inventory: Table[string, int]): string =
  for resource in BaseAgentResources:
    if inventory.get(resource) > 0:
      return resource
  ""

proc holdingServableDish(inventory: Table[string, int]): bool =
  for recipe in RecipePriority:
    if inventory.get(dishResource(recipe)) > 0:
      return true
  false

proc heldDishRecipe(inventory: Table[string, int]): string =
  for recipe in ["salad", "soup", "fries"]:
    if inventory.get(dishResource(recipe)) > 0:
      return recipe
  ""

proc visibleTicketRecipe(boardInventory: Table[string, int]): string =
  ## The earliest live ticket's recipe, from `ticket_<idx>_<recipe>` keys.
  var bestIndex = high(int)
  for name, value in boardInventory:
    if value <= 0 or not name.startsWith("ticket_"):
      continue
    let parts = name.split('_')
    if parts.len < 3:
      continue
    var index: int
    try:
      index = parseInt(parts[1])
    except ValueError:
      continue
    if parts[2] in ["soup", "fries", "salad"] and index < bestIndex:
      bestIndex = index
      result = parts[2]

proc activeRecipe(
  boardInventory: Table[string, int], fallback: string
): string =
  let visible = visibleTicketRecipe(boardInventory)
  if visible != "":
    return visible
  var best = ""
  var bestCount = 0
  for recipe in RecipePriority:
    let count = boardInventory.get(queueResource(recipe))
    if count > bestCount:
      bestCount = count
      best = recipe
  if bestCount > 0:
    return best
  fallback

proc shouldPrioritizeSalad(
  activeRecipeName: string, boardInventory: Table[string, int]
): bool =
  if boardInventory.get(QueueSalad) <= 0:
    return false
  if activeRecipeName == "salad":
    return true
  boardInventory.get(QueueSoup) <= 0 and boardInventory.get(QueueFries) <= 0

proc pendingOrders(boardInventory: Table[string, int]): int =
  for recipe in RecipePriority:
    result += boardInventory.get(queueResource(recipe))

proc recipeHasActiveTicket(
  boardInventory: Table[string, int], recipe: string
): bool =
  boardInventory.get(queueResource(recipe)) > 0

proc boardRefreshInterval(role: string, numAgents: int): int =
  ## -1 means never.
  if numAgents == 1:
    return 18
  if role == "server":
    return 24
  -1

## Task labels.
proc stationDisplayName(stationType: string): string =
  if stationType == "order_board":
    return "order board"
  if stationType.endsWith("_station"):
    return stationType[0 ..< stationType.len - "_station".len]
      .replace("_", " ")
  stationType.replace("_", " ")

proc stationTaskLabel(
  brain: KitchenBrain,
  stationType: string,
  cookInventory, fryerInventory: Table[string, int]
): string =
  let inventory = brain.inventory
  case stationType
  of "order_board": "check orders"
  of "serving_station": "serve order"
  of "plate_station": "grab plate"
  of "wash_station": "wash plate"
  of "veg_station": "fetch veg"
  of "meat_station": "fetch meat"
  of "chopping_station":
    if brain.activeStationTask == "chop_meat": "chop meat"
    elif brain.activeStationTask == "chop_veg": "chop veg"
    elif inventory.get(Meat) > 0 and inventory.get(ChoppedMeat) == 0 and
        inventory.get(Veg) == 0: "chop meat"
    elif inventory.get(Veg) > 0 and inventory.get(ChoppedVeg) == 0:
      "chop veg"
    elif inventory.get(ChoppedVeg) > 0: "stage veg"
    elif inventory.get(CleanPlate) > 0: "plate salad"
    else: "prep ingredients"
  of "cooking_station":
    if cookInventory.get(PotSoupBurned) > 0: "clear burned soup"
    elif cookInventory.get(PotSoupReady) > 0 and
        inventory.get(CleanPlate) > 0: "plate soup"
    elif inventory.get(ChoppedVeg) > 0 or inventory.get(ChoppedMeat) > 0:
      "load soup"
    elif cookInventory.get(ChoppedVeg) > 0 or
        cookInventory.get(ChoppedMeat) > 0: "start soup"
    else: "check soup"
  of "fryer_station":
    if fryerInventory.get(FryerFriesBurned) > 0: "clear burned fries"
    elif fryerInventory.get(FryerFriesReady) > 0 and
        inventory.get(CleanPlate) > 0: "plate fries"
    elif inventory.get(ChoppedVeg) > 0: "start fries"
    else: "check fries"
  else:
    stationDisplayName(stationType)

proc actionTaskLabel(actionName: string): string =
  if actionName == "noop":
    return "wait"
  actionName.replace("_", " ")

## Observation parsing.
proc accumInventory(
  inventory: var Table[string, int], suffix: string, value: int
) =
  let powerAt = suffix.rfind(":p")
  if powerAt >= 0:
    let base = suffix[0 ..< powerAt]
    var power = 0
    try:
      power = parseInt(suffix[powerAt + 2 .. ^1])
    except ValueError:
      inventory[suffix] = inventory.get(suffix) + value
      return
    var scaled = value
    for i in 0 ..< power:
      scaled *= 256
    inventory[base] = inventory.get(base) + scaled
  else:
    inventory[suffix] = inventory.get(suffix) + value

proc resolveType(brain: KitchenBrain, tagIds: seq[int]): string =
  for tagId in tagIds:
    if tagId >= 0 and tagId < brain.tagNames.len:
      let name = brain.tagNames[tagId]
      if name.startsWith("type:"):
        return name[5 .. ^1]
  "unknown"

proc parseObservation(
  brain: KitchenBrain, rawTokens: JsonNode
): tuple[position: Vec, inventory: Table[string, int],
         visible: Table[Vec, Entity]] =
  ## Raw wire tokens [loc, featureId, value] -> spawn-relative position,
  ## own inventory and the visible entities. loc packs (row, col) in one
  ## byte (row in the high nibble); 0xFF is empty, 0xFE is global.
  result.position = brain.position
  var
    rowOffset = 0
    colOffset = 0
    hasPosition = false
  let
    centerRow = brain.obsHalfH
    centerCol = brain.obsHalfW

  proc parseLocalPosition(direction: string, value: int) =
    case direction
    of "east":
      hasPosition = true
      colOffset = value
    of "west":
      hasPosition = true
      colOffset = -value
    of "south":
      hasPosition = true
      rowOffset = value
    of "north":
      hasPosition = true
      rowOffset = -value
    else:
      discard

  for entry in rawTokens.getElems():
    if entry.len < 3:
      continue
    let
      location = entry{0}.getInt()
      featureId = entry{1}.getInt()
      value = entry{2}.getInt()
    if location == 0xff:
      continue
    let featureName = brain.featureNames.getOrDefault(featureId, "")
    if location == 0xfe:
      if featureName.startsWith("lp:"):
        parseLocalPosition(featureName[3 .. ^1], value)
      elif featureName.startsWith("inv:"):
        accumInventory(result.inventory, featureName[4 .. ^1], value)
      continue
    let row = location shr 4
    let col = location and 0xf
    if row == centerRow and col == centerCol:
      if featureName.startsWith("inv:"):
        accumInventory(result.inventory, featureName[4 .. ^1], value)
      elif featureName.startsWith("lp:"):
        parseLocalPosition(featureName[3 .. ^1], value)

  if hasPosition:
    result.position = (rowOffset, colOffset)

  var cellTags: Table[Vec, seq[int]]
  var cellInventory: Table[Vec, Table[string, int]]
  for entry in rawTokens.getElems():
    if entry.len < 3:
      continue
    let
      location = entry{0}.getInt()
      featureId = entry{1}.getInt()
      value = entry{2}.getInt()
    if location == 0xff or location == 0xfe:
      continue
    let row = location shr 4
    let col = location and 0xf
    if row == centerRow and col == centerCol:
      continue
    let worldPos: Vec = (
      row - brain.obsHalfH + result.position.row,
      col - brain.obsHalfW + result.position.col
    )
    let featureName = brain.featureNames.getOrDefault(featureId, "")
    if featureName == "tag":
      cellTags.mgetOrPut(worldPos, @[]).add(value)
    elif featureName.startsWith("inv:"):
      accumInventory(
        cellInventory.mgetOrPut(worldPos, initTable[string, int]()),
        featureName[4 .. ^1], value)
    else:
      discard cellTags.mgetOrPut(worldPos, @[])

  for worldPos, tags in cellTags:
    if tags.len == 0:
      continue
    let objectType = brain.resolveType(tags)
    if objectType == "unknown":
      continue
    result.visible[worldPos] = Entity(
      entityType: objectType,
      properties: cellInventory.getOrDefault(worldPos,
        initTable[string, int]())
    )

## Plan handling.
proc applyPlan*(brain: var KitchenBrain, planMessage: JsonNode) =
  let station = planMessage{"station"}.getStr("")
  if station == "":
    # A fallback plan: drop the directive and run the baseline.
    brain.hasPlan = false
    return
  brain.hasPlan = true
  brain.plan = PlanDirective(
    turn: planMessage{"turn"}.getInt(),
    station: station,
    recipe: planMessage{"recipe"}.getStr("any"),
    zone: planMessage{"zone"}.getStr("any"),
    handoff: planMessage{"handoff"}.getStr("none"),
    yieldTo: planMessage{"yield_to"}.getStr("none"),
    say: planMessage{"say"}.getStr(""),
    src: planMessage{"src"}.getStr("llm")
  )
  if brain.plan.recipe in ["salad", "soup", "fries"]:
    brain.recipePreference = brain.plan.recipe

proc effectivePlan(
  brain: KitchenBrain
): tuple[hasPlan: bool, plan: PlanDirective] =
  ## The plan actually in force, baseline pins folded in: `passer` is
  ## `brigade` with the zone pinned to its own half and hand-off always on.
  if brain.baseline != "passer":
    return (brain.hasPlan, brain.plan)
  let (width, _) = layoutDimensions(brain.layout)
  let own =
    if brain.toAbsolute(brain.position).col < width div 2: "left"
    else: "right"
  if not brain.hasPlan:
    return (true, PlanDirective(
      station: "", recipe: "any", zone: own, handoff: "any",
      yieldTo: "none", src: "baseline:passer"))
  var pinned = brain.plan
  pinned.zone = own
  if pinned.handoff == "none":
    pinned.handoff = "any"
  (true, pinned)

proc planZone(brain: KitchenBrain): string =
  let (hasPlan, plan) = brain.effectivePlan()
  if not hasPlan or plan.zone notin ["left", "right", "pass", "any"]:
    return "any"
  plan.zone

## Routing.
proc latestObjectInventory(
  brain: KitchenBrain, objectType: string
): Table[string, int] =
  var bestSeen = -1
  for pos, entity in brain.entityMap.entities:
    if entity.entityType == objectType and entity.lastSeen > bestSeen:
      bestSeen = entity.lastSeen
      result = entity.properties

proc hasVisibleObject(brain: KitchenBrain, objectType: string): bool =
  for pos, entity in brain.entityMap.entities:
    if entity.entityType == objectType and entity.lastSeen == brain.step:
      return true
  false

proc nearestCounter(
  brain: KitchenBrain,
  predicate: proc(properties: Table[string, int]): bool
): tuple[found: bool, pos: Vec] =
  ## `zone` filters target selection: a goal outside the zone is replaced
  ## by the nearest in-zone counter. Falls back to unrestricted when the
  ## zone holds no candidate at all.
  let zone = brain.planZone()
  for restrict in [true, false]:
    var bestDist = high(int)
    var best: tuple[found: bool, pos: Vec]
    for pos, entity in brain.entityMap.entities:
      if entity.entityType != "wall":
        continue
      if not predicate(entity.properties):
        continue
      if restrict and zone != "any" and
          not inZone(brain.layout, brain.toAbsolute(pos), zone):
        continue
      let dist = manhattan(brain.position, pos)
      if dist < bestDist:
        bestDist = dist
        best = (true, pos)
    if best.found:
      return best
    if zone == "any":
      break
  (false, (0, 0))

proc routeToPosition(
  brain: var KitchenBrain, targetPos: Vec, label: string
): string =
  brain.currentTask = label
  if manhattan(brain.position, targetPos) == 1:
    return moveToward(brain.position, targetPos)
  brain.navigator.getAction(
    brain.position, targetPos, brain.entityMap, reachAdjacent = true)

proc routeToEmptyCounter(brain: var KitchenBrain): string =
  let counter = brain.nearestCounter(
    proc(properties: Table[string, int]): bool =
      not holdingAnyItem(properties))
  if not counter.found:
    brain.currentTask = "find counter"
    return brain.navigator.explore(brain.position, brain.entityMap, "west")
  let held = heldItemResource(brain.inventory)
  let label =
    if held == "": "stash item"
    else: "stash " & held.replace("_", " ")
  brain.routeToPosition(counter.pos, label)

proc exploreForStation(
  brain: var KitchenBrain, stationType: string
): string =
  brain.currentTask = "find " & stationDisplayName(stationType)
  brain.navigator.explore(brain.position, brain.entityMap, "north")

proc routeToStation(
  brain: var KitchenBrain, stationType: string
): string =
  brain.currentTask = brain.stationTaskLabel(
    stationType,
    brain.latestObjectInventory("cooking_station"),
    brain.latestObjectInventory("fryer_station"))
  let nearest = brain.entityMap.findNearest(brain.position, stationType)
  if not nearest.found:
    return brain.exploreForStation(stationType)
  if manhattan(brain.position, nearest.pos) == 1:
    return moveToward(brain.position, nearest.pos)
  brain.navigator.getAction(
    brain.position, nearest.pos, brain.entityMap, reachAdjacent = true)

proc routeToSource(
  brain: var KitchenBrain, stationType, resourceName: string
): string =
  let counter = brain.nearestCounter(
    proc(properties: Table[string, int]): bool =
      properties.get(resourceName) > 0)
  if counter.found:
    return brain.routeToPosition(counter.pos,
      "grab " & resourceName.replace("_", " "))
  brain.routeToStation(stationType)

proc commitStationTask(
  brain: var KitchenBrain, task, stationType: string
): string =
  brain.activeStationTask = task
  brain.routeToStation(stationType)

proc routeToChoppingStation(
  brain: var KitchenBrain, recipe: string
): string =
  let inventory = brain.inventory
  if recipe == "soup" and inventory.get(Meat) > 0 and
      inventory.get(ChoppedMeat) == 0:
    return brain.commitStationTask("chop_meat", "chopping_station")
  if inventory.get(Veg) > 0:
    return brain.commitStationTask("chop_veg", "chopping_station")
  if inventory.get(Meat) > 0:
    return brain.commitStationTask("chop_meat", "chopping_station")
  brain.routeToStation("chopping_station")

## The recipe/salad/role branches.
proc saladAction(
  brain: var KitchenBrain, chopInventory: Table[string, int]
): string =
  let inventory = brain.inventory
  if inventory.get(CleanPlate) > 0:
    if chopInventory.get(ChoppedVeg) > 0:
      return brain.routeToStation("chopping_station")
    return brain.routeToEmptyCounter()
  if inventory.get(ChoppedVeg) > 0:
    return brain.routeToStation("chopping_station")
  if inventory.get(Veg) > 0 or inventory.get(Meat) > 0:
    return brain.routeToChoppingStation("salad")
  if holdingAnyItem(inventory):
    return brain.routeToEmptyCounter()
  if chopInventory.get(ChoppedVeg) > 0:
    return brain.routeToSource("plate_station", CleanPlate)
  brain.routeToSource("veg_station", Veg)

proc recipeAction(
  brain: var KitchenBrain,
  recipe: string,
  chopInventory, cookInventory, fryerInventory: Table[string, int]
): string =
  let inventory = brain.inventory

  if recipe == "soup":
    if cookInventory.get(PotSoupBurned) > 0:
      return brain.routeToStation("cooking_station")
    if cookInventory.get(PotSoupReady) > 0:
      if inventory.get(CleanPlate) > 0:
        return brain.routeToStation("cooking_station")
      if holdingAnyItem(inventory):
        return brain.routeToEmptyCounter()
      return brain.routeToSource("plate_station", CleanPlate)
    if brain.numAgents == 1 and cookInventory.get(PotSoupCooking) > 0:
      if inventory.get(CleanPlate) > 0:
        return brain.routeToStation("cooking_station")
      if holdingAnyItem(inventory):
        return brain.routeToEmptyCounter()
      return brain.routeToSource("plate_station", CleanPlate)
    if inventory.get(ChoppedVeg) > 0 or inventory.get(ChoppedMeat) > 0:
      return brain.routeToStation("cooking_station")
    if cookInventory.get(ChoppedVeg) > 0 and
        cookInventory.get(ChoppedMeat) > 0:
      return brain.routeToStation("cooking_station")
    if inventory.get(Veg) > 0 or inventory.get(Meat) > 0:
      return brain.routeToChoppingStation("soup")
    if inventory.get(CleanPlate) > 0:
      if cookInventory.get(PotSoupCooking) > 0 or
          cookInventory.get(PotSoupReady) > 0 or
          cookInventory.get(ChoppedVeg) > 0 or
          cookInventory.get(ChoppedMeat) > 0:
        return brain.routeToStation("cooking_station")
      return brain.routeToEmptyCounter()
    if cookInventory.get(ChoppedVeg) > 0:
      if chopInventory.get(ChoppedMeat) > 0:
        return brain.routeToStation("chopping_station")
      return brain.routeToSource("meat_station", Meat)
    if cookInventory.get(ChoppedMeat) > 0:
      if chopInventory.get(ChoppedVeg) > 0:
        return brain.routeToStation("chopping_station")
      return brain.routeToSource("veg_station", Veg)
    if chopInventory.get(ChoppedVeg) > 0 or
        chopInventory.get(ChoppedMeat) > 0:
      return brain.routeToStation("chopping_station")
    return brain.routeToSource("veg_station", Veg)

  if recipe == "fries":
    if fryerInventory.get(FryerFriesBurned) > 0:
      return brain.routeToStation("fryer_station")
    if fryerInventory.get(FryerFriesReady) > 0:
      if inventory.get(CleanPlate) > 0:
        return brain.routeToStation("fryer_station")
      if holdingAnyItem(inventory):
        return brain.routeToEmptyCounter()
      return brain.routeToSource("plate_station", CleanPlate)
    if brain.numAgents == 1 and fryerInventory.get(FryerFriesCooking) > 0:
      if inventory.get(CleanPlate) > 0:
        return brain.routeToStation("fryer_station")
      if holdingAnyItem(inventory):
        return brain.routeToEmptyCounter()
      return brain.routeToSource("plate_station", CleanPlate)
    if inventory.get(ChoppedVeg) > 0:
      return brain.routeToStation("fryer_station")
    if inventory.get(Veg) > 0:
      return brain.routeToChoppingStation("fries")
    if inventory.get(CleanPlate) > 0:
      if fryerInventory.get(FryerFriesCooking) > 0 or
          fryerInventory.get(FryerFriesReady) > 0:
        return brain.routeToStation("fryer_station")
      return brain.routeToEmptyCounter()
    if chopInventory.get(ChoppedVeg) > 0:
      return brain.routeToStation("chopping_station")
    return brain.routeToSource("veg_station", Veg)

  brain.saladAction(chopInventory)

proc serverAction(
  brain: var KitchenBrain,
  boardInventory, chopInventory, cookInventory,
    fryerInventory: Table[string, int],
  activeRecipeName: string
): string =
  ## Returns "" when the branch has nothing to say.
  let inventory = brain.inventory
  let queueFries = boardInventory.get(QueueFries)
  let queueSoup = boardInventory.get(QueueSoup)
  let visibleTicket = visibleTicketRecipe(boardInventory)

  if holdingServableDish(inventory):
    return brain.routeToStation("serving_station")
  if inventory.get(ChoppedMeat) > 0:
    if cookInventory.get(PotSoupReady) > 0 or
        fryerInventory.get(FryerFriesReady) > 0:
      return brain.routeToEmptyCounter()
    return brain.routeToStation("cooking_station")
  if inventory.get(ChoppedVeg) > 0:
    if cookInventory.get(PotSoupReady) > 0 or
        fryerInventory.get(FryerFriesReady) > 0:
      return brain.routeToEmptyCounter()
    if visibleTicket == "salad" or
        shouldPrioritizeSalad(activeRecipeName, boardInventory):
      return brain.routeToStation("chopping_station")
    if queueFries >= queueSoup:
      return brain.routeToStation("fryer_station")
    return brain.routeToStation("cooking_station")
  if inventory.get(Veg) > 0 or inventory.get(Meat) > 0:
    if cookInventory.get(PotSoupReady) > 0 or
        fryerInventory.get(FryerFriesReady) > 0:
      return brain.routeToEmptyCounter()
    return brain.routeToChoppingStation(activeRecipeName)

  if fryerInventory.get(FryerFriesReady) > 0 and queueFries > 0:
    if inventory.get(CleanPlate) == 0:
      return brain.routeToSource("plate_station", CleanPlate)
    return brain.routeToStation("fryer_station")
  if cookInventory.get(PotSoupReady) > 0:
    if inventory.get(CleanPlate) == 0:
      return brain.routeToSource("plate_station", CleanPlate)
    return brain.routeToStation("cooking_station")
  if visibleTicket == "salad" or
      shouldPrioritizeSalad(activeRecipeName, boardInventory):
    return brain.saladAction(chopInventory)

  if queueFries > 0 and (fryerInventory.get(FryerFriesCooking) > 0 or
      fryerInventory.get(FryerFriesReady) > 0):
    return brain.routeToStation("fryer_station")
  if queueSoup > 0 and (cookInventory.get(PotSoupCooking) > 0 or
      cookInventory.get(PotSoupReady) > 0 or
      cookInventory.get(ChoppedVeg) > 0 or
      cookInventory.get(ChoppedMeat) > 0):
    return brain.routeToStation("cooking_station")

  if pendingOrders(boardInventory) > 0:
    return brain.routeToStation("order_board")
  ""

proc cookAction(
  brain: var KitchenBrain,
  boardInventory, chopInventory, cookInventory,
    fryerInventory: Table[string, int],
  activeRecipeName: string
): string =
  let inventory = brain.inventory
  let queueSoup = boardInventory.get(QueueSoup)
  let queueFries = boardInventory.get(QueueFries)
  let fryerHasActivity = fryerInventory.get(FryerFriesCooking) > 0 or
    fryerInventory.get(FryerFriesReady) > 0 or
    fryerInventory.get(FryerFriesBurned) > 0

  # Exercise the fryer flow at least once on high-pressure layouts, so a
  # soup-only local optimum cannot take hold while fries are queued.
  if not brain.friesBootstrapDone:
    if fryerHasActivity:
      brain.friesBootstrapDone = true
    elif queueFries > 0 and brain.step <= 120:
      return brain.recipeAction("fries", chopInventory, cookInventory,
        fryerInventory)
    elif queueFries > 0:
      brain.friesBootstrapDone = true

  # Ready dishes are the highest-priority service path: fetch a plate
  # immediately so ready timers do not convert into burns.
  if ((cookInventory.get(PotSoupReady) > 0 and queueSoup > 0) or
      (fryerInventory.get(FryerFriesReady) > 0 and queueFries > 0)) and
      inventory.get(CleanPlate) == 0:
    return brain.routeToSource("plate_station", CleanPlate)

  if cookInventory.get(PotSoupBurned) > 0:
    return brain.routeToStation("cooking_station")
  if fryerInventory.get(FryerFriesBurned) > 0:
    return brain.routeToStation("fryer_station")

  if fryerInventory.get(FryerFriesReady) > 0 and
      inventory.get(CleanPlate) > 0 and queueFries > 0:
    return brain.routeToStation("fryer_station")
  if cookInventory.get(PotSoupReady) > 0 and inventory.get(CleanPlate) > 0:
    return brain.routeToStation("cooking_station")
  if fryerInventory.get(FryerFriesReady) > 0 and
      inventory.get(CleanPlate) > 0:
    return brain.routeToStation("fryer_station")

  if queueFries > 0 and fryerInventory.get(FryerFriesCooking) == 0 and
      fryerInventory.get(FryerFriesReady) == 0:
    return brain.recipeAction("fries", chopInventory, cookInventory,
      fryerInventory)

  if activeRecipeName == "soup" and (queueSoup > 0 or
      cookInventory.get(PotSoupCooking) > 0 or
      cookInventory.get(PotSoupReady) > 0 or
      cookInventory.get(ChoppedVeg) > 0 or
      cookInventory.get(ChoppedMeat) > 0):
    return brain.recipeAction("soup", chopInventory, cookInventory,
      fryerInventory)
  if activeRecipeName == "fries" and (queueFries > 0 or
      fryerInventory.get(FryerFriesCooking) > 0 or
      fryerInventory.get(FryerFriesReady) > 0):
    return brain.recipeAction("fries", chopInventory, cookInventory,
      fryerInventory)

  if queueFries > queueSoup and (queueFries > 0 or
      fryerInventory.get(FryerFriesCooking) > 0):
    return brain.recipeAction("fries", chopInventory, cookInventory,
      fryerInventory)
  if queueSoup > 0 or cookInventory.get(PotSoupCooking) > 0 or
      cookInventory.get(PotSoupReady) > 0 or
      cookInventory.get(ChoppedVeg) > 0 or
      cookInventory.get(ChoppedMeat) > 0:
    return brain.recipeAction("soup", chopInventory, cookInventory,
      fryerInventory)
  if queueFries > 0 or fryerInventory.get(FryerFriesCooking) > 0:
    return brain.recipeAction("fries", chopInventory, cookInventory,
      fryerInventory)
  ""

proc prepAction(
  brain: var KitchenBrain,
  boardInventory, chopInventory, cookInventory: Table[string, int],
  activeRecipeName: string
): string =
  let inventory = brain.inventory

  if inventory.get(Veg) > 0 or inventory.get(Meat) > 0:
    return brain.routeToChoppingStation(activeRecipeName)
  if inventory.get(ChoppedMeat) > 0:
    return brain.routeToStation("cooking_station")
  if inventory.get(ChoppedVeg) > 0:
    if shouldPrioritizeSalad(activeRecipeName, boardInventory):
      return brain.routeToStation("chopping_station")
    if boardInventory.get(QueueFries) > boardInventory.get(QueueSoup):
      return brain.routeToStation("fryer_station")
    return brain.routeToStation("cooking_station")
  if inventory.get(CleanPlate) > 0:
    return brain.routeToEmptyCounter()

  let queueSalad = boardInventory.get(QueueSalad)
  let queueSoup = boardInventory.get(QueueSoup)
  let queueFries = boardInventory.get(QueueFries)
  let soupActive = cookInventory.get(PotSoupCooking) > 0 or
    cookInventory.get(PotSoupReady) > 0 or
    cookInventory.get(ChoppedVeg) > 0 or
    cookInventory.get(ChoppedMeat) > 0

  # Keep soup mechanics live: when soup is queued but no pot is active,
  # assemble soup ingredients instead of letting salad/fries dominate.
  if queueSoup > 0 and not soupActive:
    if chopInventory.get(ChoppedVeg) > 0:
      return brain.routeToStation("chopping_station")
    if queueSoup > queueSalad:
      return brain.routeToSource("veg_station", Veg)
  if cookInventory.get(ChoppedVeg) > 0 and
      cookInventory.get(ChoppedMeat) == 0:
    if chopInventory.get(ChoppedMeat) > 0:
      return brain.routeToStation("chopping_station")
    return brain.routeToSource("meat_station", Meat)
  if cookInventory.get(ChoppedMeat) > 0 and
      cookInventory.get(ChoppedVeg) == 0:
    if chopInventory.get(ChoppedVeg) > 0:
      return brain.routeToStation("chopping_station")
    return brain.routeToSource("veg_station", Veg)

  # Under fries pressure, push chopped veg to the fryer directly.
  if queueFries > queueSoup:
    if chopInventory.get(ChoppedVeg) > 0:
      return brain.routeToStation("chopping_station")
    return brain.routeToSource("veg_station", Veg)

  if shouldPrioritizeSalad(activeRecipeName, boardInventory):
    return brain.saladAction(chopInventory)
  ""

proc allRounderAction(
  brain: var KitchenBrain,
  boardInventory, chopInventory, cookInventory,
    fryerInventory: Table[string, int],
  activeRecipeName: string
): string =
  if brain.numAgents == 1:
    return ""
  if brain.inventory.get(DirtyPlate) > 0:
    return brain.commitStationTask("wash", "wash_station")

  let serverResult = brain.serverAction(boardInventory, chopInventory,
    cookInventory, fryerInventory, activeRecipeName)
  if serverResult != "":
    return serverResult

  let prepResult = brain.prepAction(boardInventory, chopInventory,
    cookInventory, activeRecipeName)
  if prepResult != "" and
      shouldPrioritizeSalad(activeRecipeName, boardInventory):
    return prepResult

  let cookResult = brain.cookAction(boardInventory, chopInventory,
    cookInventory, fryerInventory, activeRecipeName)
  if cookResult != "" and (boardInventory.get(QueueSoup) > 0 or
      boardInventory.get(QueueFries) > 0 or
      cookInventory.get(PotSoupCooking) > 0 or
      fryerInventory.get(FryerFriesCooking) > 0):
    return cookResult

  if prepResult != "":
    return prepResult
  cookResult

## Plan executor pieces.
proc yieldAction(
  brain: var KitchenBrain, hasPlan: bool, plan: PlanDirective
): string =
  ## `yield_to`: the reference player never learns ally positions (the
  ## seat only sees its own window), so like the reference this only ever
  ## fires when an ally position source exists; without one it is inert.
  discard hasPlan
  discard plan
  ""

proc handoffAction(
  brain: var KitchenBrain, hasPlan: bool, plan: PlanDirective
): string =
  ## `handoff`: stage the carried item on a divider counter instead of
  ## walking it onward. Without ally positions only `handoff: any` (always
  ## the case for `passer`) can trigger, exactly like the reference player.
  if not hasPlan or plan.handoff == "none":
    return ""
  if not holdingAnyItem(brain.inventory):
    return ""
  if plan.handoff != "any":
    # An alias hand-off needs the ally's position, which this seat cannot
    # see; skip rather than guess.
    return ""
  if brain.passStaging.len == 0:
    # Nothing to hand over: no divider and no island (cramped).
    return ""
  var best: tuple[found: bool, pos: Vec]
  var bestDist = high(int)
  for pos, entity in brain.entityMap.entities:
    if entity.entityType != "wall":
      continue
    if holdingAnyItem(entity.properties):
      continue
    if pos notin brain.passStaging:
      continue
    let dist = manhattan(brain.position, pos)
    if dist < bestDist:
      bestDist = dist
      best = (true, pos)
  if not best.found:
    return ""
  let held = heldItemResource(brain.inventory)
  let label =
    if held == "": "hand off"
    else: "hand off " & held.replace("_", " ")
  brain.routeToPosition(best.pos, label)

proc planStationAction(
  brain: var KitchenBrain, hasPlan: bool, plan: PlanDirective
): string =
  ## `station` sets the sub-goal, overriding the brain's own choice.
  if not hasPlan:
    return ""
  if plan.station == "hold":
    if holdingServableDish(brain.inventory):
      return brain.routeToStation("serving_station")
    brain.currentTask = "hold"
    return "noop"
  if plan.station notin stationByPlanName:
    return ""
  brain.routeToStation(stationByPlanName[plan.station])

## The main per-tick decision.
proc chooseAction(brain: var KitchenBrain): string =
  let boardVisible = brain.hasVisibleObject("order_board")
  let boardInventory = brain.latestObjectInventory("order_board")
  let chopInventory = brain.latestObjectInventory("chopping_station")
  let cookInventory = brain.latestObjectInventory("cooking_station")
  let fryerInventory = brain.latestObjectInventory("fryer_station")
  let washInventory = brain.latestObjectInventory("wash_station")
  var activeRecipeName = brain.recipePreference

  if boardVisible:
    activeRecipeName = activeRecipe(boardInventory, brain.recipePreference)
    brain.recipePreference = activeRecipeName
    brain.boardLastSeenStep = brain.step
  if brain.numAgents == 1 and boardInventory.get(QueueSalad) > 0:
    activeRecipeName = "salad"
    brain.recipePreference = activeRecipeName
  let hotStationUrgent = cookInventory.get(PotSoupReady) > 0 or
    cookInventory.get(PotSoupBurned) > 0 or
    fryerInventory.get(FryerFriesReady) > 0 or
    fryerInventory.get(FryerFriesBurned) > 0

  if brain.activeStationTask == "wash":
    if washInventory.get(WashProgress) > 0 or
        brain.inventory.get(DirtyPlate) > 0:
      return brain.routeToStation("wash_station")
    brain.activeStationTask = ""
  elif brain.activeStationTask == "chop_veg":
    if hotStationUrgent and brain.inventory.get(ChoppedVeg) == 0:
      brain.activeStationTask = ""
    elif brain.inventory.get(ChoppedVeg) > 0:
      brain.activeStationTask = ""
    elif chopInventory.get(ChopVegProgress) > 0 or
        brain.inventory.get(Veg) > 0:
      return brain.routeToStation("chopping_station")
    else:
      brain.activeStationTask = ""
  elif brain.activeStationTask == "chop_meat":
    if hotStationUrgent and brain.inventory.get(ChoppedMeat) == 0:
      brain.activeStationTask = ""
    elif brain.inventory.get(ChoppedMeat) > 0:
      brain.activeStationTask = ""
    elif chopInventory.get(ChopMeatProgress) > 0 or
        brain.inventory.get(Meat) > 0:
      return brain.routeToStation("chopping_station")
    else:
      brain.activeStationTask = ""

  let refreshInterval = boardRefreshInterval(brain.role, brain.numAgents)
  let needsInitialRefresh = refreshInterval >= 0 and
    brain.boardLastSeenStep == 0
  let refreshDue = refreshInterval >= 0 and
    brain.step - brain.boardLastSeenStep > refreshInterval
  if (needsInitialRefresh or refreshDue) and
      not holdingAnyItem(brain.inventory) and not hotStationUrgent:
    return brain.routeToStation("order_board")

  if brain.inventory.get(DirtyPlate) > 0:
    return brain.commitStationTask("wash", "wash_station")
  if holdingServableDish(brain.inventory):
    let heldRecipe = heldDishRecipe(brain.inventory)
    if heldRecipe == "":
      return brain.routeToStation("serving_station")
    if not recipeHasActiveTicket(boardInventory, heldRecipe):
      return brain.routeToStation("order_board")
    return brain.routeToStation("serving_station")

  var roleResult = ""
  case brain.role
  of "server":
    roleResult = brain.serverAction(boardInventory, chopInventory,
      cookInventory, fryerInventory, activeRecipeName)
  of "cook":
    roleResult = brain.cookAction(boardInventory, chopInventory,
      cookInventory, fryerInventory, activeRecipeName)
  of "prep":
    roleResult = brain.prepAction(boardInventory, chopInventory,
      cookInventory, activeRecipeName)
  of "all_rounder":
    roleResult = brain.allRounderAction(boardInventory, chopInventory,
      cookInventory, fryerInventory, activeRecipeName)
  else:
    discard

  if roleResult != "":
    return roleResult

  if brain.numAgents >= 3 and brain.role == "prep" and
      (cookInventory.get(PotSoupReady) > 0 or
       fryerInventory.get(FryerFriesReady) > 0):
    return brain.routeToStation("order_board")

  brain.recipeAction(activeRecipeName, chopInventory, cookInventory,
    fryerInventory)

proc stepBrain*(
  brain: var KitchenBrain, rawTokens: JsonNode
): tuple[actionName, task: string] =
  inc brain.step
  brain.currentTask = ""

  let parsed = brain.parseObservation(rawTokens)
  brain.position = parsed.position
  brain.inventory = parsed.inventory
  brain.entityMap.updateFromObservation(
    brain.position, brain.obsHalfH, brain.obsHalfW, parsed.visible,
    brain.step)

  if brain.hasLastPos and brain.lastAction.startsWith("move_") and
      brain.position == brain.lastPos:
    inc brain.failedMoves
  else:
    brain.failedMoves = 0

  let inventoryKey = heldItemResource(brain.inventory)
  if brain.hasLastPos and brain.position == brain.lastPos and
      inventoryKey == brain.lastInventoryKey:
    inc brain.idleTicks
  else:
    brain.idleTicks = 0
  brain.lastInventoryKey = inventoryKey

  let (hasPlan, plan) = brain.effectivePlan()
  var action = brain.yieldAction(hasPlan, plan)
  if action == "":
    if brain.idleTicks >= StallTicks and
        holdingAnyItem(brain.inventory) and
        not holdingServableDish(brain.inventory):
      # A cog holding an item its station cannot accept walks back into
      # the same station and hammers it; putting the item down unblocks.
      brain.idleTicks = 0
      brain.activeStationTask = ""
      action = brain.routeToEmptyCounter()
      brain.currentTask = "unstick: put it down"
    elif brain.failedMoves >= 4:
      if holdingServableDish(brain.inventory):
        action = brain.routeToStation("serving_station")
      else:
        brain.currentTask = "unstick"
        action = brain.navigator.explore(brain.position, brain.entityMap,
          "south")
    else:
      action = brain.handoffAction(hasPlan, plan)
      if action == "":
        action = brain.planStationAction(hasPlan, plan)
      if action == "":
        action = brain.chooseAction()

  if brain.currentTask == "":
    brain.currentTask = actionTaskLabel(action)

  brain.hasLastPos = true
  brain.lastPos = brain.position
  brain.lastAction = action
  (action, brain.currentTask)
