## Zlydni — Emerg-ant policy for Andre von Auto.
## A command player speaking BitWorld Sprite v1 over websocket (the CTF
## engine's emerg-ant mode; see docs/protocol_player.md ->
## coworld-emerg-ant/docs/PROTOCOL.md). The reference example player is
## the opaque `/bin/baseline` binary; its source is
## players/baseline/baseline.nim in github.com/Metta-AI/coworld-emerg-ant,
## whose `decideEmergAnt` this ports: a scent-driven forage loop.
##
## Per living ant, each frame:
##   - carrying food  -> run it home to the nest (food pheromone, urgent);
##   - else           -> claimed `food patch` (nest-distance rank, slot-spread);
##   - no patches     -> slot-staggered boustrophedon sweep of the field;
##   - queen          -> immobile; bites an enemy in contact, marks danger.
## Improvements over the reference: the nest position is learned (own
## queen sighting, falling back to our spawn point) instead of a
## hard-coded CTF flag-room constant, and steering runs over a BFS
## distance field on an 8 px walkability grid instead of the raw direct
## vector, so ants path around walls instead of hugging them.
##
## League notes: never send Player Ready (0x85) — it corrupts input
## timing on wall-clock-paced league servers (measured, PROTOCOL.md).
## Sprites Off (0x87) is sent on connect: we consume labels only.

import
  std/[algorithm, math, net, os, random, strutils],
  bitworld/spriteprotocol,
  supersnappy,
  whisky

const
  ## Emerg-ant control scheme (PROTOCOL.md): C+direction selects the
  ## pheromone kind, bare C advances the emission rate 0..3.
  PheromoneScout = 0
  PheromoneFood = 1
  PheromoneDanger = 2
  PheromoneHome = 3
  AimBrads = 256
  AimRate = 5                 # brads/tick a held rotate button turns aim
  CruiseDeadband = 8
  CarrySelfRadius = 26.0      # the carried-food marker rides its carrier
  ClaimGrabRadius = 64.0      # take a patch this close even if it is not ours
  MateSpacing = 40.0          # soft repulsion radius between teammates
  QueenBiteRange = 18.0
  QueenAlarmRange = 100.0
  WorkerAlarmRange = 80.0
  MapObjectId = 1
  MapSpriteId = 1
  NavCell = 8                 # nav grid cell size in map pixels
  PlayerHalf = 6              # solid footprint half-extent (sim constant)
  MaxFrameDrain = 128
  DefaultMapWidth = 1235
  DefaultMapHeight = 659
  TeamColorNames = ["red", "blue", "green", "yellow"]
  LabelFoodPatch = "food patch"
  LabelFoodCarried = "food carried"
  LabelWalkabilityMap = "walkability map"
  LabelPrefixOwnAim = "own aim "
  LabelPrefixGameParams = "game teams "

type
  Vec = object
    x, y: float

  SpriteMeta = object
    defined: bool
    width, height: int
    label: string

  SpriteObject = object
    present: bool
    x, y: int
    spriteId: int

  Client = ref object
    sprites: seq[SpriteMeta]
    objects: seq[SpriteObject]
    mapCameraReady: bool
    mapCameraX, mapCameraY: int
    walkabilityReady: bool
    walkabilityWidth, walkabilityHeight: int
    walkabilityMask: seq[bool]
    packetBytes: seq[uint8]

  Bot = ref object
    slot: int
    tick: int
    gameStart: int
    myColor: string
    colorLocked: bool
    estAim: int
    rotSign: int
    lastPos: Vec
    stuckTicks: int
    nestKnown: bool
    nestPos: Vec
    pheromoneKind: int
    pheromoneRate: int
    pheromoneRelease: bool
    ## Nav grid: BFS distance-to-target per walkable cell.
    navBuilt: bool
    gridWidth, gridHeight: int
    cellWalkable: seq[bool]
    navDistance: seq[int32]
    navTargetCell: int
    navAge: int

proc vec(x, y: float): Vec = Vec(x: x, y: y)
proc `+`(a, b: Vec): Vec = vec(a.x + b.x, a.y + b.y)
proc `-`(a, b: Vec): Vec = vec(a.x - b.x, a.y - b.y)
proc `*`(a: Vec, s: float): Vec = vec(a.x * s, a.y * s)
proc length(a: Vec): float = sqrt(a.x * a.x + a.y * a.y)
proc dist(a, b: Vec): float = (a - b).length()
proc norm(a: Vec): Vec =
  let l = a.length()
  if l < 1e-9: vec(0, 0) else: vec(a.x / l, a.y / l)

## Sprite protocol client (labels-only port of players/baseline/protocols.nim).

proc decodeWalkability(client: Client, width, height: int,
    compressed: string) =
  ## The walkability sprite's alpha channel is the walkable bit per pixel.
  var raw = ""
  try:
    raw = supersnappy.uncompress(compressed)
  except CatchableError:
    return
  if width <= 0 or height <= 0 or raw.len != width * height * 4:
    return
  client.walkabilityMask.setLen(width * height)
  for i in 0 ..< width * height:
    client.walkabilityMask[i] = raw[i * 4 + 3].uint8 > 0
  client.walkabilityReady = true
  client.walkabilityWidth = width
  client.walkabilityHeight = height

proc applyPacket(client: Client, packet: string) =
  blobToBytes(packet, client.packetBytes)
  for message in parseSpritePacket(client.packetBytes):
    case message.kind
    of spkSprite:
      let sprite = message.sprite
      if sprite.label == LabelWalkabilityMap and
          sprite.compressedPixels.len > 0:
        client.decodeWalkability(sprite.width, sprite.height,
          blobFromBytes(sprite.compressedPixels))
      if sprite.id >= client.sprites.len:
        client.sprites.setLen(sprite.id + 1)
      client.sprites[sprite.id] = SpriteMeta(defined: true,
        width: sprite.width, height: sprite.height, label: sprite.label)
    of spkObject:
      let objectDef = message.objectDef
      if objectDef.id >= client.objects.len:
        client.objects.setLen(objectDef.id + 1)
      client.objects[objectDef.id] = SpriteObject(present: true,
        x: objectDef.x, y: objectDef.y, spriteId: objectDef.spriteId)
      if objectDef.id == MapObjectId and objectDef.spriteId == MapSpriteId:
        client.mapCameraReady = true
        client.mapCameraX = -objectDef.x
        client.mapCameraY = -objectDef.y
    of spkDeleteObject:
      if message.objectId >= 0 and message.objectId < client.objects.len:
        client.objects[message.objectId].present = false
      if message.objectId == MapObjectId:
        client.mapCameraReady = false
    of spkClearObjects:
      for item in client.objects.mitems:
        item.present = false
      client.mapCameraReady = false
    of spkViewport, spkLayer:
      discard

proc reset(client: Client) =
  client.sprites.setLen(0)
  client.objects.setLen(0)
  client.mapCameraReady = false
  client.walkabilityReady = false
  client.walkabilityMask.setLen(0)

proc receiveLatestFrame(client: Client, ws: WebSocket): int =
  ## Blocks for one message, then drains the backlog; acts on the LATEST
  ## retained scene (inputs are level-based, stale frames mislead).
  ## Returns the number of frames advanced (0 on timeout/noise).
  proc accept(client: Client, ws: WebSocket, message: Message): bool =
    case message.kind
    of BinaryMessage:
      client.applyPacket(message.data)
      true
    of Ping:
      ws.send(message.data, Pong)
      false
    else:
      false

  let first = ws.receiveMessage(-1)
  if first.isSome and client.accept(ws, first.get()):
    inc result
  var drained = 0
  while drained < MaxFrameDrain:
    let message = ws.receiveMessage(0)
    if message.isNone:
      break
    if client.accept(ws, message.get()):
      inc result
    inc drained

iterator presentObjects(client: Client):
    tuple[x, y, width, height: int, label: string] =
  for objectState in client.objects:
    if not objectState.present:
      continue
    if objectState.spriteId < 0 or objectState.spriteId >= client.sprites.len:
      continue
    let sprite = client.sprites[objectState.spriteId]
    if not sprite.defined:
      continue
    yield (objectState.x, objectState.y, sprite.width, sprite.height,
      sprite.label)

proc mapPos(client: Client, x, y, width, height: int): Vec =
  vec(float(x + width div 2 + client.mapCameraX),
    float(y + height div 2 + client.mapCameraY))

proc objectsWithLabel(client: Client, label: string): seq[Vec] =
  for o in client.presentObjects():
    if o.label == label:
      result.add(client.mapPos(o.x, o.y, o.width, o.height))

proc findSelf(client: Client, color: string): tuple[alive: bool, pos: Vec] =
  for side in ["right", "left"]:
    for label in ["self " & color & " " & side,
        "self queen " & color & " " & side]:
      let hits = client.objectsWithLabel(label)
      if hits.len > 0:
        return (true, hits[0])

proc isQueen(client: Client, color: string): bool =
  for side in ["right", "left"]:
    if client.objectsWithLabel("self queen " & color & " " & side).len > 0:
      return true

proc actorsFor(client: Client, color: string): seq[Vec] =
  for side in ["right", "left"]:
    for label in ["player " & color & " " & side,
        "queen " & color & " " & side]:
      result.add(client.objectsWithLabel(label))

proc ownQueenPos(client: Client, color: string): tuple[seen: bool, pos: Vec] =
  for side in ["right", "left"]:
    for label in ["queen " & color & " " & side,
        "self queen " & color & " " & side]:
      let hits = client.objectsWithLabel(label)
      if hits.len > 0:
        return (true, hits[0])

proc ownAimBrads(client: Client): int =
  ## The engine-stated own-aim marker, or -1 when absent.
  result = -1
  for o in client.presentObjects():
    if o.label.startsWith(LabelPrefixOwnAim):
      try:
        return parseInt(o.label[LabelPrefixOwnAim.len .. ^1])
      except ValueError:
        return -1

proc mapSize(client: Client): tuple[width, height: int] =
  ## Walkability dims first, the stated game-params label second.
  if client.walkabilityReady:
    return (client.walkabilityWidth, client.walkabilityHeight)
  for o in client.presentObjects():
    if o.label.startsWith(LabelPrefixGameParams):
      ## `game teams <count> map <width>x<height>`
      let parts = o.label[LabelPrefixGameParams.len .. ^1].split(' ')
      if parts.len == 3 and parts[1] == "map":
        let size = parts[2].split('x')
        if size.len == 2:
          try:
            return (parseInt(size[0]), parseInt(size[1]))
          except ValueError:
            discard
  (DefaultMapWidth, DefaultMapHeight)

## Aim and movement math (ports from the reference baseline).

proc octantBits(d: Vec): uint8 =
  ## D-pad bits for the 8-way direction nearest to `d`.
  if d.length() < 1e-6:
    return 0
  let octant = (int(round(arctan2(d.y, d.x) / (PI / 4))) + 8) mod 8
  case octant
  of 0: ButtonRight
  of 1: ButtonRight or ButtonDown
  of 2: ButtonDown
  of 3: ButtonDown or ButtonLeft
  of 4: ButtonLeft
  of 5: ButtonLeft or ButtonUp
  of 6: ButtonUp
  else: ButtonUp or ButtonRight

proc bradsOf(d: Vec): int =
  ## Aim brads along `d`: 0 = east, counter-clockwise, y grows downward.
  if d.length() < 1e-6:
    return 0
  (int(round(arctan2(-d.y, d.x) * float(AimBrads div 2) / PI)) +
    AimBrads) mod AimBrads

proc bradsErr(desired, current: int): int =
  ## Signed shortest arc; positive means rotate counter-clockwise (B).
  (desired - current + AimBrads + AimBrads div 2) mod AimBrads -
    AimBrads div 2

## Nav: BFS distance field over the walkability grid.

proc walkableAt(client: Client, x, y: int): bool =
  if x < 0 or y < 0 or x >= client.walkabilityWidth or
      y >= client.walkabilityHeight:
    return false
  client.walkabilityMask[y * client.walkabilityWidth + x]

proc buildNavGrid(bot: Bot, client: Client) =
  ## A cell is walkable when the ant's solid footprint fits at its center.
  bot.gridWidth = (client.walkabilityWidth + NavCell - 1) div NavCell
  bot.gridHeight = (client.walkabilityHeight + NavCell - 1) div NavCell
  bot.cellWalkable = newSeq[bool](bot.gridWidth * bot.gridHeight)
  for cy in 0 ..< bot.gridHeight:
    for cx in 0 ..< bot.gridWidth:
      let
        px = cx * NavCell + NavCell div 2
        py = cy * NavCell + NavCell div 2
      var fits = true
      block footprint:
        for dy in -PlayerHalf .. PlayerHalf:
          for dx in -PlayerHalf .. PlayerHalf:
            if not client.walkableAt(px + dx, py + dy):
              fits = false
              break footprint
      bot.cellWalkable[cy * bot.gridWidth + cx] = fits
  bot.navDistance = newSeq[int32](bot.gridWidth * bot.gridHeight)
  bot.navTargetCell = -1
  bot.navBuilt = true

proc cellOf(bot: Bot, p: Vec): int =
  let
    cx = clamp(int(p.x) div NavCell, 0, bot.gridWidth - 1)
    cy = clamp(int(p.y) div NavCell, 0, bot.gridHeight - 1)
  cy * bot.gridWidth + cx

proc nearestWalkableCell(bot: Bot, cell: int): int =
  ## The target itself may sit on an unwalkable cell (nest glow, patch on
  ## a border); search a small ring for the closest walkable cell.
  if bot.cellWalkable[cell]:
    return cell
  let
    cx = cell mod bot.gridWidth
    cy = cell div bot.gridWidth
  for radius in 1 .. 4:
    for dy in -radius .. radius:
      for dx in -radius .. radius:
        if max(abs(dx), abs(dy)) != radius:
          continue
        let
          nx = cx + dx
          ny = cy + dy
        if nx >= 0 and ny >= 0 and nx < bot.gridWidth and
            ny < bot.gridHeight and
            bot.cellWalkable[ny * bot.gridWidth + nx]:
          return ny * bot.gridWidth + nx
  -1

proc rebuildDistanceField(bot: Bot, targetCell: int) =
  ## Plain BFS from the target; diagonals only when both orthogonal
  ## neighbors are open (no corner cutting past a wall).
  for i in 0 ..< bot.navDistance.len:
    bot.navDistance[i] = -1
  var queue = @[targetCell]
  bot.navDistance[targetCell] = 0
  var head = 0
  while head < queue.len:
    let
      cell = queue[head]
      cx = cell mod bot.gridWidth
      cy = cell div bot.gridWidth
    inc head
    for dy in -1 .. 1:
      for dx in -1 .. 1:
        if dx == 0 and dy == 0:
          continue
        let
          nx = cx + dx
          ny = cy + dy
        if nx < 0 or ny < 0 or nx >= bot.gridWidth or ny >= bot.gridHeight:
          continue
        let next = ny * bot.gridWidth + nx
        if not bot.cellWalkable[next] or bot.navDistance[next] >= 0:
          continue
        if dx != 0 and dy != 0:
          let
            sideA = cy * bot.gridWidth + nx
            sideB = ny * bot.gridWidth + cx
          if not bot.cellWalkable[sideA] or not bot.cellWalkable[sideB]:
            continue
        bot.navDistance[next] = bot.navDistance[cell] + 1
        queue.add(next)

proc navSteer(bot: Bot, me, target: Vec): Vec =
  ## Downhill on the BFS field toward a few-cells-ahead waypoint; direct
  ## vector when nav is unavailable or disconnected.
  if not bot.navBuilt:
    return target - me
  var targetCell = bot.nearestWalkableCell(bot.cellOf(target))
  if targetCell < 0:
    return target - me
  if targetCell != bot.navTargetCell or bot.navAge > 12:
    bot.rebuildDistanceField(targetCell)
    bot.navTargetCell = targetCell
    bot.navAge = 0
  var cell = bot.cellOf(me)
  if not bot.cellWalkable[cell] or bot.navDistance[cell] < 0:
    return target - me
  ## Walk up to 4 cells downhill and aim at that waypoint. BFS distance
  ## counts diagonals as 1, so many neighbors tie; break ties by straight-
  ## line closeness to the target so open-field travel stays straight.
  for step in 0 ..< 4:
    let
      cx = cell mod bot.gridWidth
      cy = cell div bot.gridWidth
    var
      best = cell
      bestDistance = bot.navDistance[cell]
      bestCloseness = 1e18
    for dy in -1 .. 1:
      for dx in -1 .. 1:
        let
          nx = cx + dx
          ny = cy + dy
        if nx < 0 or ny < 0 or nx >= bot.gridWidth or ny >= bot.gridHeight:
          continue
        let next = ny * bot.gridWidth + nx
        if bot.navDistance[next] < 0 or bot.navDistance[next] > bestDistance:
          continue
        let closeness = dist(vec(float(nx) * NavCell + NavCell / 2,
          float(ny) * NavCell + NavCell / 2), target)
        if bot.navDistance[next] < bestDistance or
            (best != cell and closeness < bestCloseness):
          bestDistance = bot.navDistance[next]
          bestCloseness = closeness
          best = next
    if best == cell:
      break
    cell = best
  if cell == bot.cellOf(me):
    return target - me
  let waypoint = vec(
    float(cell mod bot.gridWidth) * NavCell + NavCell / 2,
    float(cell div bot.gridWidth) * NavCell + NavCell / 2)
  waypoint - me

## The forage policy (port of decideEmergAnt with learned nest + nav).

proc resetTransient(bot: Bot) =
  bot.stuckTicks = 0
  bot.rotSign = 0
  bot.pheromoneKind = 0
  bot.pheromoneRate = 2
  bot.pheromoneRelease = false
  bot.nestKnown = false
  bot.gameStart = bot.tick
  bot.navBuilt = false
  bot.navTargetCell = -1
  bot.colorLocked = false

proc decide(bot: Bot, client: Client): uint8 =
  if not bot.colorLocked:
    for color in TeamColorNames:
      if client.findSelf(color).alive:
        bot.myColor = color
        bot.colorLocked = true
        break
  let (alive, me) = client.findSelf(bot.myColor)
  if not alive:
    bot.rotSign = 0
    return 0
  let statedAim = client.ownAimBrads()
  if statedAim >= 0:
    bot.estAim = statedAim
  if client.walkabilityReady and not bot.navBuilt:
    bot.buildNavGrid(client)
  inc bot.navAge

  let queen = client.isQueen(bot.myColor)
  ## Nest memory: our queen never moves, and we spawn beside her.
  let (queenSeen, queenPos) = client.ownQueenPos(bot.myColor)
  if queenSeen:
    bot.nestPos = queenPos
    bot.nestKnown = true
  elif not bot.nestKnown:
    bot.nestPos = me
    bot.nestKnown = true

  var carrying = false
  for carriedPos in client.objectsWithLabel(LabelFoodCarried):
    if dist(carriedPos, me) <= CarrySelfRadius:
      carrying = true
      break

  var
    target: Vec
    desiredKind = if queen: PheromoneHome else: PheromoneScout
    desiredRate = if queen: 1 else: 2
  if carrying:
    target = bot.nestPos
    desiredKind = PheromoneFood
    desiredRate = 3
  else:
    let foods = client.objectsWithLabel(LabelFoodPatch)
    if foods.len > 0:
      ## All eight patches are globally scented. Chasing the nearest one
      ## piles every free worker onto the same fruit. Rank by nest distance
      ## (shared, so every seat agrees) and claim a distinct k-th patch.
      ## Seat 0 is typically the immobile queen (lowest join-order); rotate
      ## so she is assigned the farthest patch and the seven starting
      ## workers cover the seven nearest. A patch already underfoot is
      ## taken regardless — first-touch scores.
      var nearest = foods[0]
      var nearestD = dist(nearest, me)
      for i in 1 ..< foods.len:
        let d = dist(foods[i], me)
        if d < nearestD:
          nearestD = d
          nearest = foods[i]
      if nearestD <= ClaimGrabRadius or foods.len == 1:
        target = nearest
      else:
        var ranked = foods
        let nest = bot.nestPos
        ranked.sort(proc (a, b: Vec): int =
          result = cmp(dist(a, nest), dist(b, nest))
          if result == 0:
            result = cmp(a.x, b.x)
          if result == 0:
            result = cmp(a.y, b.y))
        let claim = (bot.slot div 2 + ranked.len - 1) mod ranked.len
        target = ranked[claim]
    else:
      ## Boustrophedon sector sweep; seats start at different phase
      ## offsets so the colony covers the field instead of balling up.
      let
        (mapWidth, mapHeight) = client.mapSize()
        phase = ((bot.tick - bot.gameStart) div 240 + bot.slot * 3) mod 24
        row = phase div 6
        rawColumn = phase mod 6
        column = if row mod 2 == 0: rawColumn else: 5 - rawColumn
      target = vec(
        70.0 + float(column) * (float(mapWidth) - 140.0) / 5.0,
        55.0 + float(row) * (float(mapHeight) - 110.0) / 3.0)

  ## Workers are dedicated foragers: symmetric touch fights trade both
  ## ants while one food return scores AND hatches a dormant copy. Only
  ## the immobile queen bites, and only when already in contact.
  var bite = false
  if queen and not carrying:
    for color in TeamColorNames:
      if color == bot.myColor:
        continue
      for enemy in client.actorsFor(color):
        let d = dist(enemy, me)
        if d <= QueenBiteRange:
          target = enemy
          bite = true
        if d <= QueenAlarmRange:
          desiredKind = PheromoneDanger
          desiredRate = 3
  elif not carrying:
    block alarm:
      for color in TeamColorNames:
        if color == bot.myColor:
          continue
        for enemy in client.actorsFor(color):
          if dist(enemy, me) <= WorkerAlarmRange:
            desiredKind = PheromoneDanger
            desiredRate = 3
            break alarm

  var steer = norm(bot.navSteer(me, target))
  ## Nest traffic is expected while delivering; repulsion near the queen
  ## would leave a carrier orbiting just outside the scoring zone.
  if not carrying:
    for mate in client.actorsFor(bot.myColor):
      let d = dist(mate, me)
      if d > 0.5 and d < MateSpacing:
        steer = steer + norm(me - mate) * 0.7
  var moveMask = octantBits(steer)

  if dist(me, bot.lastPos) < 0.8:
    inc bot.stuckTicks
  else:
    bot.stuckTicks = 0
  bot.lastPos = me
  if bot.stuckTicks > 20:
    bot.stuckTicks = 0
    bot.navTargetCell = -1
    moveMask = octantBits(vec(rand(-1.0 .. 1.0), rand(-1.0 .. 1.0)))
    if moveMask == 0:
      moveMask = ButtonUp

  let
    desiredAim = bradsOf(if steer.length() > 0.1: steer else: target - me)
    err = bradsErr(desiredAim, bot.estAim)
  var mask = moveMask
  if err > CruiseDeadband:
    mask = mask or ButtonB
    bot.rotSign = 1
  elif err < -CruiseDeadband:
    mask = mask or ButtonSelect
    bot.rotSign = -1
  else:
    bot.rotSign = 0
  if bite:
    mask = mask or ButtonA

  ## Persistent pheromone controller, edge-triggered: a C command tick
  ## pauses locomotion server-side, and C must be released for one frame
  ## between commands.
  if bot.pheromoneRelease:
    bot.pheromoneRelease = false
  elif bot.pheromoneKind != desiredKind:
    bot.pheromoneKind = desiredKind
    bot.pheromoneRelease = true
    case desiredKind
    of PheromoneScout: return ButtonC or ButtonLeft
    of PheromoneFood: return ButtonC or ButtonUp
    of PheromoneDanger: return ButtonC or ButtonRight
    else: return ButtonC or ButtonDown
  elif bot.pheromoneRate != desiredRate:
    bot.pheromoneRate = (bot.pheromoneRate + 1) mod 4
    bot.pheromoneRelease = true
    return ButtonC
  mask

proc slotFromUrl(url: string): int =
  let at = url.find("slot=")
  if at < 0:
    return 0
  var digits = ""
  for i in at + 5 ..< url.len:
    if url[i] in {'0' .. '9'}:
      digits.add(url[i])
    else:
      break
  if digits.len == 0: 0 else: digits.parseInt()

proc spritesOffBlob(): string =
  ## Sprite client message 0x87: strip pixel payloads server-side.
  result = newString(1)
  result[0] = char(0x87)

proc runBot(url: string) =
  let bot = Bot(slot: slotFromUrl(url), myColor: "red")
  bot.myColor = TeamColorNames[bot.slot mod 2]
  randomize(bot.slot * 7919 + 1)
  let client = Client()
  echo "zlydni: slot ", bot.slot, " -> ", url
  var
    everConnected = false
    lastMask = 0'u8
    hasSent = false
  while true:
    try:
      let ws = newWebSocket(url)
      ws.socket.setSockOpt(OptNoDelay, true, level = IPPROTO_TCP.cint)
      ws.send(spritesOffBlob(), BinaryMessage)
      echo "zlydni: connected"
      everConnected = true
      client.reset()
      bot.resetTransient()
      hasSent = false
      while true:
        let advance = client.receiveLatestFrame(ws)
        if advance == 0:
          continue
        bot.tick += advance
        bot.estAim = floorMod(bot.estAim + bot.rotSign * AimRate * advance,
          AimBrads)
        if not client.mapCameraReady:
          bot.resetTransient()            # lobby / game-over interstitial
          continue
        let mask = bot.decide(client)
        if not hasSent or mask != lastMask:
          ws.send(blobFromSpriteMask(mask), BinaryMessage)
          lastMask = mask
          hasSent = true
    except CatchableError as error:
      if everConnected:
        ## The game ended and the server went away: exit cleanly so the
        ## episode runner sees a finished player.
        echo "zlydni: game over, exiting: ", error.msg
        quit(0)
      echo "zlydni: connect retry: ", error.msg
      sleep(250)

when isMainModule:
  let url = getEnv("COWORLD_PLAYER_WS_URL")
  if url.len == 0:
    quit("zlydni: COWORLD_PLAYER_WS_URL is required", 1)
  runBot(url)
