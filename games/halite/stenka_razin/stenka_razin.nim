## Stepan Razin — Halite policy for Andre von Auto.
## Unlike the thin prompt seats, a halite seat is a COMMAND PLAYER: the
## server writes one `observe` frame per turn and the seat must answer
## with an `orders` frame inside the shared 400 ms deadline
## (docs/protocol_player.md -> cogame-halite/docs/PROTOCOL.md). This is a
## deterministic Nim port of the strongest shipped baseline logic,
## `server/cogame_halite/micro.py::compile_turn` — mine-richest-nearby,
## return-when-full, avoid-heavier-collisions — with both tuned
## directive sets (tidewalker and corsair) available.
##
## Env:
##   PLAYER_SCRIPTED  tidewalker (default) | corsair
## No LLM anywhere in this container, so no USE_BEDROCK is needed.

import std/[algorithm, json, options, os, sets, tables, strutils], whisky

type
  Direction = enum
    North, East, South, West

  Directive = object
    stance: string
    spawnUntil: int
    yards: int
    mineFloor: int
    returnAt: int
    focus: string

  Asset = object
    id: string
    pos: int
    cargo: int

const
  DirectionNames = ["NORTH", "EAST", "SOUTH", "WEST"]
  SpawnCost = 500
  ConvertCost = 500
  MaxShips = 24
  PatchRadius = 6
  MaxActionsPerTurn = 256
  Tidewalker = Directive(stance: "mine", spawnUntil: 200, yards: 2,
    mineFloor: 200, returnAt: 300, focus: "CENTER")
  Corsair = Directive(stance: "raid", spawnUntil: 300, yards: 2,
    mineFloor: 200, returnAt: 300, focus: "CENTER")

## Torus geometry. Board index = (size - y - 1) * size + x, so index 0 is
## the top-left cell on screen; NORTH is index - size.

proc positionXy(pos, size: int): (int, int) =
  (pos mod size, size - 1 - pos div size)

proc toIndex(x, y, size: int): int =
  let
    wrappedX = ((x mod size) + size) mod size
    wrappedY = ((y mod size) + size) mod size
  (size - wrappedY - 1) * size + wrappedX

proc stepIndex(pos: int, direction: Direction, size: int): int =
  var (x, y) = positionXy(pos, size)
  case direction
  of North: inc y
  of South: dec y
  of East: inc x
  of West: dec x
  toIndex(x, y, size)

proc torusDist(a, b, size: int): int =
  let
    (ax, ay) = positionXy(a, size)
    (bx, by) = positionXy(b, size)
    dx = abs(ax - bx)
    dy = abs(ay - by)
  min(dx, size - dx) + min(dy, size - dy)

proc quadrantCentre(focus: string, size: int): int =
  let
    quarter = size div 4
    three = (3 * size) div 4
  case focus
  of "NW": toIndex(quarter, three, size)
  of "NE": toIndex(three, three, size)
  of "SW": toIndex(quarter, quarter, size)
  of "SE": toIndex(three, quarter, size)
  else: toIndex(size div 2, size div 2, size)

proc uidKey(uid: string): (int, int, string) =
  ## Sort key for a Halite uid "<turn>-<n>" — numeric, not lexical.
  let dash = uid.find('-')
  if dash > 0:
    try:
      return (parseInt(uid[0 ..< dash]), parseInt(uid[dash + 1 .. ^1]), uid)
    except ValueError:
      discard
  (1_000_000_000, 1_000_000_000, uid)

proc sortedByUid(assets: seq[Asset]): seq[Asset] =
  result = assets
  result.sort(proc(a, b: Asset): int = cmp(uidKey(a.id), uidKey(b.id)))

## One turn of orders for our seat. A faithful port of micro.py's
## compile_turn: pure, deterministic, bounded.

proc compileTurn(observation: JsonNode, directive: Directive,
    baseline: string): OrderedTable[string, string] =
  let
    config = observation{"config"}
    size = config{"size"}.getInt(21)
    turn = observation{"turn"}.getInt()
    maxTurns = observation{"maxTurns"}.getInt(400)
    seat = observation{"seat"}.getInt()
    playersNode = observation["players"]
    haliteNode = observation["halite"]
  if seat >= playersNode.len:
    return

  var halite = newSeq[float](haliteNode.len)
  for i, value in haliteNode.elems:
    halite[i] = value.getFloat()

  let
    alwaysHunt = baseline == "corsair"
    huntRange = if alwaysHunt: 4 else: 3

  var
    bank = 0
    myYards: seq[Asset]
    myShips: seq[Asset]
    enemyThreat: Table[int, int]
    enemyShips: seq[(int, int)]      # (pos, cargo)
    myYardCells: HashSet[int]
    allYardCells: HashSet[int]

  for index, playerNode in playersNode.elems:
    let
      yardsNode = playerNode[1]
      shipsNode = playerNode[2]
    if index == seat:
      bank = playerNode[0].getInt()
      for id, posNode in yardsNode.pairs:
        myYards.add(Asset(id: id, pos: posNode.getInt()))
        myYardCells.incl(posNode.getInt())
      for id, shipNode in shipsNode.pairs:
        myShips.add(Asset(id: id, pos: shipNode[0].getInt(),
          cargo: shipNode[1].getInt()))
    else:
      for id, shipNode in shipsNode.pairs:
        let
          pos = shipNode[0].getInt()
          cargo = shipNode[1].getInt()
        enemyShips.add((pos, cargo))
        for cell in [pos, stepIndex(pos, North, size),
            stepIndex(pos, East, size), stepIndex(pos, South, size),
            stepIndex(pos, West, size)]:
          if cell notin enemyThreat or cargo < enemyThreat[cell]:
            enemyThreat[cell] = cargo
    for id, posNode in yardsNode.pairs:
      allYardCells.incl(posNode.getInt())

  var
    orders: OrderedTable[string, string]
    claimed: HashSet[int]

  proc cellHalite(cell: int): float =
    if cell >= 0 and cell < halite.len: halite[cell] else: 0.0

  proc unsafe(cell, myCargo: int): bool =
    if cell in myYardCells:
      return false
    cell in enemyThreat and enemyThreat[cell] <= myCargo

  proc nearestYard(pos: int): int =
    ## Nearest of our yard cells; ties break to the lowest cell index.
    result = -1
    var best = (int.high, int.high)
    for cell in myYardCells:
      let key = (torusDist(pos, cell, size), cell)
      if key < best:
        best = key
        result = cell

  proc choose(pos: int, directions: seq[Direction],
      cargo: int): Option[Direction] =
    var best = ((int.high, 0.0, int.high), North)
    var found = false
    for order, direction in directions:
      let cell = stepIndex(pos, direction, size)
      if cell in claimed:
        continue
      let key = ((if unsafe(cell, cargo): 1 else: 0), -cellHalite(cell), order)
      if not found or key < best[0]:
        best = (key, direction)
        found = true
    if found: some(best[1]) else: none(Direction)

  proc shortestDirections(pos, target: int): seq[Direction] =
    let here = torusDist(pos, target, size)
    for direction in Direction:
      if torusDist(stepIndex(pos, direction, size), target, size) < here:
        result.add(direction)

  proc stepToward(pos, target, cargo: int): Option[Direction] =
    var safeDirections: seq[Direction]
    for direction in shortestDirections(pos, target):
      if not unsafe(stepIndex(pos, direction, size), cargo):
        safeDirections.add(direction)
    choose(pos, safeDirections, cargo)

  proc stepHome(pos, home, cargo: int): Option[Direction] =
    let move = choose(pos, shortestDirections(pos, home), cargo)
    if move.isSome and not unsafe(stepIndex(pos, move.get, size), cargo):
      return move
    # Every shortest step is unsafe: take the safest step that does not
    # increase the distance by more than 1; holding is inside that set.
    let here = torusDist(pos, home, size)
    var widened: seq[Direction]
    for direction in Direction:
      if torusDist(stepIndex(pos, direction, size), home, size) <= here + 1:
        widened.add(direction)
    let safest = choose(pos, widened, cargo)
    if safest.isSome and not unsafe(stepIndex(pos, safest.get, size), cargo):
      return safest
    if pos notin claimed and not unsafe(pos, cargo):
      return none(Direction)
    if safest.isSome: safest else: move

  proc stepToPatch(pos, cargo: int): Option[Direction] =
    let focusCell = quadrantCentre(directive.focus, size)
    var
      bestCell = -1
      bestScore = 0.0
    let (px, py) = positionXy(pos, size)
    for dy in -PatchRadius .. PatchRadius:
      let span = PatchRadius - abs(dy)
      for dx in -span .. span:
        let cell = toIndex(px + dx, py + dy, size)
        if cell in claimed or unsafe(cell, cargo):
          continue
        let value = cellHalite(cell)
        if value <= 0:
          continue
        let d = abs(dx) + abs(dy)
        var score = value / (1.0 + 2.0 * float(d))
        if torusDist(cell, focusCell, size) <= size div 4:
          score *= 1.15
        if score > bestScore or
            (score == bestScore and bestCell >= 0 and cell < bestCell):
          bestScore = score
          bestCell = cell
    if bestCell >= 0 and bestCell != pos:
      let move = stepToward(pos, bestCell, cargo)
      if move.isSome:
        return move
    if bestCell == pos:
      return none(Direction)
    var everyDirection: seq[Direction]
    for direction in Direction:
      everyDirection.add(direction)
    let safest = choose(pos, everyDirection, cargo)
    if safest.isNone:
      return none(Direction)
    if unsafe(stepIndex(pos, safest.get, size), cargo) and
        not unsafe(pos, cargo):
      return none(Direction)
    safest

  let shipItems = sortedByUid(myShips)
  var converted: HashSet[string]

  ## 1. Shipyard-loss guard: no yards left means convert the best ship.
  if myYards.len == 0:
    var
      bestId = ""
      bestCargo = -1
    for ship in shipItems:
      if ship.pos in allYardCells:
        continue
      if ship.cargo + bank >= ConvertCost and ship.cargo > bestCargo:
        bestId = ship.id
        bestCargo = ship.cargo
    if bestId.len > 0:
      orders[bestId] = "CONVERT"
      converted.incl(bestId)
  # 2. Second yard once the fleet and the bank can afford it.
  elif myShips.len >= 8 and myYards.len < directive.yards and bank >= 1500:
    var
      bestId = ""
      bestFar = -1
    for ship in shipItems:
      if ship.pos in allYardCells:
        continue
      if ship.cargo + bank < ConvertCost:
        continue
      var far = int.high
      for cell in myYardCells:
        far = min(far, torusDist(ship.pos, cell, size))
      if far >= 5 and far > bestFar:
        bestId = ship.id
        bestFar = far
    if bestId.len > 0:
      orders[bestId] = "CONVERT"
      converted.incl(bestId)

  ## 3. Ships, ascending uid.
  for ship in shipItems:
    if ship.id in converted:
      continue
    let
      pos = ship.pos
      cargo = ship.cargo
      home = nearestYard(pos)
      homeDist = if home >= 0: torusDist(pos, home, size) else: 1_000_000
    # Bank-cycle: hold cargo scores 0 and is stolen on a ram. Near ships
    # dump small loads (~50 per step, one mineFloor collect); far ships
    # still fill up to returnAt. Flat 300 left ships next to a yard sitting
    # stealable, and hunters trigger at cargo+200.
    let cycleAt = min(directive.returnAt, 50 * max(1, homeDist))
    let comeHome = home >= 0 and (cargo >= cycleAt or
      turn + homeDist + 2 >= maxTurns or
      (unsafe(pos, cargo) and homeDist < 3))
    if comeHome:
      if pos == home:
        claimed.incl(pos)
        continue
      let move = stepHome(pos, home, cargo)
      if move.isSome:
        orders[ship.id] = DirectionNames[ord(move.get)]
        claimed.incl(stepIndex(pos, move.get, size))
      else:
        claimed.incl(pos)
      continue

    # b. mine in place when the cell is rich enough and safe.
    if pos notin allYardCells and cellHalite(pos) >= float(directive.mineFloor) and
        not unsafe(pos, cargo):
      claimed.incl(pos)
      continue

    # c. hunt a heavier enemy with a light hull.
    if alwaysHunt or directive.stance == "raid":
      var
        targetPos = -1
        targetDist = int.high
      if cargo <= 100:
        for (enemyPos, enemyCargo) in enemyShips:
          if enemyCargo < cargo + 200:
            continue
          let d = torusDist(pos, enemyPos, size)
          if d <= huntRange and d < targetDist:
            targetPos = enemyPos
            targetDist = d
      if targetPos >= 0:
        let move = stepToward(pos, targetPos, cargo)
        if move.isSome:
          orders[ship.id] = DirectionNames[ord(move.get)]
          claimed.incl(stepIndex(pos, move.get, size))
          continue

    # d. best halite patch within the diamond.
    let move = stepToPatch(pos, cargo)
    if move.isSome:
      orders[ship.id] = DirectionNames[ord(move.get)]
      claimed.incl(stepIndex(pos, move.get, size))
    else:
      claimed.incl(pos)

  ## 4. Shipyards, ascending uid.
  var
    spawns = 0
    occupied: HashSet[int]
  for ship in myShips:
    occupied.incl(ship.pos)
  for yard in sortedByUid(myYards):
    if turn > directive.spawnUntil:
      break
    if bank - SpawnCost * spawns < SpawnCost:
      break
    if myShips.len + spawns >= MaxShips:
      break
    if yard.pos in occupied or yard.pos in claimed:
      continue
    orders[yard.id] = "SPAWN"
    inc spawns

  if orders.len > MaxActionsPerTurn:
    var keys: seq[string]
    for key in orders.keys:
      keys.add(key)
    keys.sort(proc(a, b: string): int = cmp(uidKey(a), uidKey(b)))
    var capped: OrderedTable[string, string]
    for key in keys[0 ..< MaxActionsPerTurn]:
      capped[key] = orders[key]
    orders = capped
  orders

proc dial(url: string, attempts: int): WebSocket =
  ## Bounded dialling: the episode runner starts the players at the same
  ## instant as the game, so the first dial can land on a closed port.
  for attempt in 0 ..< attempts:
    try:
      return newWebSocket(url)
    except CatchableError as error:
      if attempt == 0:
        echo "stenka_razin: game not listening yet (", error.msg, "); retrying"
      sleep(500)
  nil

proc main() =
  let
    url = getEnv("COWORLD_PLAYER_WS_URL", getEnv("COGAMES_ENGINE_WS_URL"))
    scripted = getEnv("PLAYER_SCRIPTED", "tidewalker")
    baseline = if scripted == "corsair": "corsair" else: "tidewalker"
    directive = if baseline == "corsair": Corsair else: Tidewalker
  if url == "":
    quit("stenka_razin: COWORLD_PLAYER_WS_URL is not set", 1)
  echo "stenka_razin: connecting to ", url, " baseline=", baseline
  let ws = dial(url, 240)
  if ws == nil:
    quit("stenka_razin: game never accepted a connection", 1)
  # The player exits 0 on a dead socket: a closed socket after play is a
  # normal end of episode, never a failure (docs/PROTOCOL.md).
  while true:
    var received: Option[Message]
    try:
      received = ws.receiveMessage()
    except CatchableError:
      echo "stenka_razin: websocket closed (", getCurrentExceptionMsg(), ")"
      break
    if received.isNone:
      continue
    let message = received.get()
    if message.kind == Ping:
      ws.send(message.data, Pong)
      continue
    if message.kind != TextMessage:
      continue
    var frame: JsonNode
    try:
      frame = parseJson(message.data)
    except CatchableError:
      continue
    case frame{"type"}.getStr()
    of "hello":
      ws.send($(%*{"type": "register", "policy": "scripted:" & baseline,
        "label": "Stepan Razin"}))
      echo "stenka_razin: seated seat ", frame{"seat"}.getInt(),
        " alias ", frame{"alias"}.getStr()
    of "observe":
      let orders = compileTurn(frame, directive, baseline)
      var actions = newJObject()
      for id, action in orders.pairs:
        actions[id] = %action
      let intent = if directive.stance == "raid": "raid" else: "mine"
      ws.send($(%*{"type": "orders", "turn": frame{"turn"}.getInt(),
        "source": "scripted", "actions": actions, "intent": intent,
        "note": "volga fleet: mine light, bank often, ram heavier holds"}))
    of "done":
      echo "stenka_razin: done, result ", frame{"result"}
      break
    else:
      discard
  quit(0)

main()
