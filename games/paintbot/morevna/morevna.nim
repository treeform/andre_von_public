## Marya Morevna — Paintbot policy for Andre von Auto.
## Command player: a Nim rewrite of the `baseline` example player's core
## behavior ("grab the flag, run it home, shoot enemies in front") speaking
## the Bitworld Sprite v1 binary protocol with the CTF extensions
## (coworld-ctf docs/PROTOCOL.md + docs/RULES.md).
##
## The observation is a fogged full-map sprite scene. We keep a retained
## scene (the server sends define/delete diffs), decode the snappy-compressed
## `walkability map` sprite into a nav mask, erode it by the player footprint
## into an 8px cell grid, and BFS a flow field to the current objective:
##
## - not carrying: walk onto the nearest enemy `<color> flag planted` object
##   center (touch radius 34px grabs it; there is no grab button);
## - carrying (the enemy `flag carried` marker rides within ~20px of the
##   `self` marker): run the heart to our own endzone center (the
##   `endzone <color> <shape> <x0>,<y0> <x1>,<y1>` init marker);
## - no planted enemy flag in sight: press toward the nearest enemy endzone.
## - one seat in every four of ours (team-seat mod 4 == 3, from the `slot=`
##   query in the ws URL) is a home defender: hold our planted heart so a
##   steal is body-blocked, and chase `<mycolor> flag carried` if it leaves.
##   A capture of our heart eliminates us (GV32); all-rush left that free.
##
## Aim is decoupled from movement: we read the absolute `own aim <brads>`
## HUD marker every frame and dead-reckon held rotation (5 brads/tick)
## across skipped ticks between frames. The gun fires on a fresh A press
## with the aim locked at the pull, so we gate the trigger geometrically
## (perpendicular miss at target range inside the bullet corridor), check
## walkability line of sight, skip shots with a remembered teammate near the
## fire axis (friendly fire is on), and stop rotating on the tick we fire.
## Per docs/PROTOCOL.md we never send Player Ready (0x85) — it corrupts
## input timing on wall-clock-paced league servers — and we skip Sprites
## Off (0x87) because the walkability mask arrives as sprite pixels.
##
## Works on 2-team and 4-team (corner/plus) maps: the team color comes from
## the `self <color> <side>` label and the map geometry from the
## `game teams <count> map <width>x<height>` init marker.

import std/[math, options, os, strutils], whisky

## Engine constants (docs/RULES.md, docs/PROTOCOL.md)
const
  AimRatePerTick = 5        # brads a held rotate button turns per sim tick
  WindupTicks = 5           # aim locks at the pull; bullet leaves after this
  CooldownTicks = 12        # gun cooldown between shots
  GunRange = 1050.0         # fixed hitscan range on every map, map px
  FireSlack = 9.0           # allowed perpendicular miss at target range, px
  PlayerHalf = 6            # solid footprint half-extent, px
  NavCell = 8               # nav grid cell size, px
  EngageRange = 620.0       # do not rotate onto targets farther than this
  CarrierEngageRange = 140.0 # while carrying, only fight point-blank threats
  MateCorridor = 26.0       # friendly-fire guard corridor half-width, px
  TrackTtl = 96             # ticks a fogged sighting stays believed (~4s)
  FreshShotTicks = 24       # only fire at tracks seen this recently
  RepathTicks = 12          # refresh the flow field at least this often
  LookaheadCells = 5        # waypoint lookahead along the descent
  MaxSpeed = 2.75           # px/tick top speed, for target lead
  LeadTicks = 7.0           # aim ahead of a mover: windup releases late
  GrabSlack = 24.0          # walk straight at the heart inside this range
  ThiefFixTtl = 96          # ticks a stolen-heart sighting still steers us

  ButtonUp = 0x01'u8
  ButtonDown = 0x02'u8
  ButtonLeft = 0x04'u8
  ButtonRight = 0x08'u8
  ButtonSelect = 0x10'u8    # rotate aim clockwise (negative brads)
  ButtonA = 0x20'u8         # fire (edge-triggered, windup-locked)
  ButtonB = 0x40'u8         # rotate aim counter-clockwise (positive brads)

  TeamColorNames = ["red", "blue", "green", "yellow"]
  EndzoneShapes = ["column", "square", "disc", "corner", "arm"]
  WalkLabel = "walkability map"
  # PROTOCOL.md: the in-game signal is the map camera object, not a label.
  # Sprite id 1 is unlabeled chrome (addSprite default label is "").
  MapObjectId = 1
  MapSpriteId = 1

## Snappy uncompress (format: varint length, then literal/copy tags).
## Self-contained so the policy needs no compression dependency.

type SnappyError = object of CatchableError

proc snappyUncompress(compressed: string): string =
  var pos = 0
  template need(n: int) =
    if pos + n > compressed.len:
      raise newException(SnappyError, "truncated snappy stream")
  template nextByte(): int =
    (need(1); let b = compressed[pos].int; inc pos; b)
  var
    expected = 0
    shift = 0
  while true:
    let b = nextByte()
    expected = expected or ((b and 0x7f) shl shift)
    if (b and 0x80) == 0:
      break
    shift += 7
  result = newStringOfCap(expected)
  while pos < compressed.len:
    let tag = nextByte()
    if (tag and 3) == 0:
      var literalLen = tag shr 2
      if literalLen >= 60:
        let extraBytes = literalLen - 59
        literalLen = 0
        for i in 0 ..< extraBytes:
          literalLen = literalLen or (nextByte() shl (8 * i))
      inc literalLen
      need(literalLen)
      for i in 0 ..< literalLen:
        result.add(compressed[pos])
        inc pos
    else:
      var copyLen, offset: int
      case tag and 3
      of 1:
        copyLen = ((tag shr 2) and 7) + 4
        offset = ((tag shr 5) shl 8) or nextByte()
      of 2:
        copyLen = (tag shr 2) + 1
        offset = nextByte() or (nextByte() shl 8)
      else:
        copyLen = (tag shr 2) + 1
        offset = nextByte() or (nextByte() shl 8) or
          (nextByte() shl 16) or (nextByte() shl 24)
      if offset <= 0 or offset > result.len:
        raise newException(SnappyError, "bad snappy copy offset")
      var source = result.len - offset
      for i in 0 ..< copyLen:
        result.add(result[source])
        inc source
  if result.len != expected:
    raise newException(SnappyError, "snappy length mismatch")

## Sprite v1 wire layer: binary reader plus a retained scene.

const
  MessageDefineSprite = 0x01'u8
  MessageDefineObject = 0x02'u8
  MessageDeleteObject = 0x03'u8
  MessageClearObjects = 0x04'u8
  MessageSetViewport = 0x05'u8
  MessageDefineLayer = 0x06'u8

type
  WireError = object of CatchableError

  Sprite = object
    defined: bool
    width: int
    height: int
    label: string

  SceneObject = object
    present: bool
    x: int
    y: int
    layer: int
    spriteId: int

  Scene = ref object
    sprites: seq[Sprite]
    objects: seq[SceneObject]
    walkReady: bool
    walkVersion: int          # bumped on every walkability decode
    walkWidth: int
    walkHeight: int
    walk: seq[bool]           # true = walkable floor
    mapPlaced: bool           # the map object is present (a match is running)
    mapLayer: int

  Reader = object
    data: string
    pos: int

proc remaining(reader: Reader): int =
  reader.data.len - reader.pos

proc u8(reader: var Reader): uint8 =
  if reader.remaining < 1:
    raise newException(WireError, "truncated u8")
  result = reader.data[reader.pos].uint8
  inc reader.pos

proc u16(reader: var Reader): int =
  if reader.remaining < 2:
    raise newException(WireError, "truncated u16")
  result = reader.data[reader.pos].int or (reader.data[reader.pos + 1].int shl 8)
  reader.pos += 2

proc i16(reader: var Reader): int =
  result = reader.u16
  if result >= 32768:
    result -= 65536

proc u32(reader: var Reader): int =
  if reader.remaining < 4:
    raise newException(WireError, "truncated u32")
  result = reader.data[reader.pos].int or
    (reader.data[reader.pos + 1].int shl 8) or
    (reader.data[reader.pos + 2].int shl 16) or
    (reader.data[reader.pos + 3].int shl 24)
  reader.pos += 4

proc bytes(reader: var Reader, n: int): string =
  if reader.remaining < n:
    raise newException(WireError, "truncated bytes")
  result = reader.data[reader.pos ..< reader.pos + n]
  reader.pos += n

proc ensureSprite(scene: Scene, id: int) =
  if id >= scene.sprites.len:
    scene.sprites.setLen(id + 1)

proc ensureObject(scene: Scene, id: int) =
  if id >= scene.objects.len:
    scene.objects.setLen(id + 1)

proc decodeWalkability(scene: Scene, width, height: int, compressed: string) =
  let raw = snappyUncompress(compressed)
  if raw.len != width * height * 4:
    raise newException(WireError, "walkability size mismatch")
  scene.walk.setLen(width * height)
  for i in 0 ..< width * height:
    scene.walk[i] = raw[i * 4 + 3].uint8 > 0  # alpha > 0 = walkable
  scene.walkWidth = width
  scene.walkHeight = height
  scene.walkReady = true
  inc scene.walkVersion

proc applyPacket(scene: Scene, packet: string) =
  ## Applies one frame's sprite messages to the retained scene.
  var reader = Reader(data: packet)
  while reader.remaining > 0:
    let kind = reader.u8
    case kind
    of MessageDefineSprite:
      let
        id = reader.u16
        width = reader.u16
        height = reader.u16
        compressedLen = reader.u32
        compressed = reader.bytes(compressedLen)
        labelLen = reader.u16
        label = reader.bytes(labelLen)
      scene.ensureSprite(id)
      scene.sprites[id] = Sprite(
        defined: true, width: width, height: height, label: label)
      if label == WalkLabel and compressed.len > 0:
        scene.decodeWalkability(width, height, compressed)
    of MessageDefineObject:
      let
        id = reader.u16
        x = reader.i16
        y = reader.i16
        z = reader.i16
        layer = reader.u8.int
        spriteId = reader.u16
      discard z
      scene.ensureObject(id)
      scene.objects[id] = SceneObject(
        present: true, x: x, y: y, layer: layer, spriteId: spriteId)
      if id == MapObjectId and spriteId == MapSpriteId:
        scene.mapPlaced = true
        scene.mapLayer = layer
    of MessageDeleteObject:
      let id = reader.u16
      if id < scene.objects.len and scene.objects[id].present:
        scene.objects[id].present = false
      if id == MapObjectId:
        scene.mapPlaced = false
    of MessageClearObjects:
      for sceneObject in scene.objects.mitems:
        sceneObject.present = false
      scene.mapPlaced = false
    of MessageSetViewport:
      discard reader.u8
      discard reader.u16
      discard reader.u16
    of MessageDefineLayer:
      discard reader.u8
      discard reader.u8
      discard reader.u8
    else:
      raise newException(WireError, "unknown message kind " & $kind)

iterator presentObjects(scene: Scene):
    tuple[id, x, y, width, height, layer: int, label: string] =
  for id in 0 ..< scene.objects.len:
    let sceneObject = scene.objects[id]
    if not sceneObject.present:
      continue
    if sceneObject.spriteId >= scene.sprites.len:
      continue
    let sprite = scene.sprites[sceneObject.spriteId]
    if not sprite.defined:
      continue
    yield (id, sceneObject.x, sceneObject.y, sprite.width, sprite.height,
      sceneObject.layer, sprite.label)

proc inputPacket(mask: uint8): string =
  result = newString(2)
  result[0] = char(0x84)
  result[1] = char(mask)

const MaxDrain = 128

proc pumpFrames(scene: Scene, socket: WebSocket): int =
  ## Blocks for at least one frame, drains any backlog, applies every packet,
  ## and returns the number of frames applied (= sim ticks elapsed for us).
  ## Acting on the latest frame only keeps held inputs honest (PROTOCOL.md).
  var applied = 0
  let first = socket.receiveMessage(-1)
  if first.isNone:
    raise newException(WireError, "socket closed")
  var messages = @[first.get()]
  while messages.len < MaxDrain:
    let more = socket.receiveMessage(0)
    if more.isNone:
      break
    messages.add(more.get())
  for message in messages:
    case message.kind
    of BinaryMessage:
      scene.applyPacket(message.data)
      inc applied
    of Ping:
      socket.send(message.data, Pong)
    else:
      discard
  applied

## Geometry helpers

proc distance(ax, ay, bx, by: float): float =
  sqrt((ax - bx) * (ax - bx) + (ay - by) * (ay - by))

proc bradsOf(dx, dy: float): int =
  ## Brads: 256 per turn, 0 = east, counter-clockwise on screen (y is down).
  let turns = arctan2(-dy, dx) / (2.0 * PI)
  result = int(round(turns * 256.0))
  result = ((result mod 256) + 256) mod 256

proc bradsError(desired, current: int): int =
  ## Shortest signed arc from current to desired, in -128 .. 127.
  ((desired - current + 384) mod 256) - 128

proc octantBits(dx, dy: float): uint8 =
  ## D-pad bits for the octant nearest the direction (22.5 degree split).
  const Split = 0.4142
  result = 0
  if dx > Split * abs(dy):
    result = result or ButtonRight
  elif -dx > Split * abs(dy):
    result = result or ButtonLeft
  if dy > Split * abs(dx):
    result = result or ButtonDown
  elif -dy > Split * abs(dx):
    result = result or ButtonUp

## Nav grid: walkability eroded by the player footprint, BFS flow field.

type Nav = object
  ready: bool
  builtVersion: int
  gridWidth: int
  gridHeight: int
  open: seq[bool]
  field: seq[int]           # BFS distance to goal, -1 = unreached
  goalCell: int
  fieldTick: int

proc walkableAt(scene: Scene, x, y: int): bool =
  if x < 0 or y < 0 or x >= scene.walkWidth or y >= scene.walkHeight:
    return false
  scene.walk[y * scene.walkWidth + x]

proc footprintFits(scene: Scene, x, y: int): bool =
  ## The player's solid box must fit: sample the footprint corners and edges.
  for offsetY in [-PlayerHalf, 0, PlayerHalf]:
    for offsetX in [-PlayerHalf, 0, PlayerHalf]:
      if not scene.walkableAt(x + offsetX, y + offsetY):
        return false
  true

proc buildNav(nav: var Nav, scene: Scene) =
  nav.gridWidth = max(1, scene.walkWidth div NavCell)
  nav.gridHeight = max(1, scene.walkHeight div NavCell)
  nav.open.setLen(nav.gridWidth * nav.gridHeight)
  for cellY in 0 ..< nav.gridHeight:
    for cellX in 0 ..< nav.gridWidth:
      let
        centerX = cellX * NavCell + NavCell div 2
        centerY = cellY * NavCell + NavCell div 2
      nav.open[cellY * nav.gridWidth + cellX] =
        scene.footprintFits(centerX, centerY)
  nav.field.setLen(nav.open.len)
  nav.goalCell = -1
  nav.fieldTick = -1000
  nav.builtVersion = scene.walkVersion
  nav.ready = true

proc cellOf(nav: Nav, x, y: float): int =
  let
    cellX = clamp(int(x) div NavCell, 0, nav.gridWidth - 1)
    cellY = clamp(int(y) div NavCell, 0, nav.gridHeight - 1)
  cellY * nav.gridWidth + cellX

proc cellCenter(nav: Nav, cell: int): (float, float) =
  let
    cellX = cell mod nav.gridWidth
    cellY = cell div nav.gridWidth
  (float(cellX * NavCell + NavCell div 2), float(cellY * NavCell + NavCell div 2))

proc nearestOpenCell(nav: Nav, start: int): int =
  ## BFS ring search over the whole grid for the closest open cell.
  if nav.open[start]:
    return start
  var
    visited = newSeq[bool](nav.open.len)
    queue = @[start]
    head = 0
  visited[start] = true
  while head < queue.len:
    let cell = queue[head]
    inc head
    if nav.open[cell]:
      return cell
    let
      cellX = cell mod nav.gridWidth
      cellY = cell div nav.gridWidth
    for stepY in -1 .. 1:
      for stepX in -1 .. 1:
        if stepX == 0 and stepY == 0:
          continue
        let
          nextX = cellX + stepX
          nextY = cellY + stepY
        if nextX < 0 or nextY < 0 or
            nextX >= nav.gridWidth or nextY >= nav.gridHeight:
          continue
        let next = nextY * nav.gridWidth + nextX
        if not visited[next]:
          visited[next] = true
          queue.add(next)
  start

proc computeField(nav: var Nav, goal, tick: int) =
  ## Uniform-cost BFS flow field from the goal over open cells; diagonals
  ## only when both orthogonal neighbors are open (no corner cutting).
  nav.goalCell = goal
  nav.fieldTick = tick
  for value in nav.field.mitems:
    value = -1
  if not nav.open[goal]:
    return
  var
    queue = @[goal]
    head = 0
  nav.field[goal] = 0
  while head < queue.len:
    let cell = queue[head]
    inc head
    let
      cellX = cell mod nav.gridWidth
      cellY = cell div nav.gridWidth
    for stepY in -1 .. 1:
      for stepX in -1 .. 1:
        if stepX == 0 and stepY == 0:
          continue
        let
          nextX = cellX + stepX
          nextY = cellY + stepY
        if nextX < 0 or nextY < 0 or
            nextX >= nav.gridWidth or nextY >= nav.gridHeight:
          continue
        let next = nextY * nav.gridWidth + nextX
        if not nav.open[next] or nav.field[next] >= 0:
          continue
        if stepX != 0 and stepY != 0:
          let
            sideA = cellY * nav.gridWidth + nextX
            sideB = nextY * nav.gridWidth + cellX
          if not nav.open[sideA] or not nav.open[sideB]:
            continue
        nav.field[next] = nav.field[cell] + 1
        queue.add(next)

proc pixelRayClear(scene: Scene, ax, ay, bx, by: float): bool =
  ## Walkability line of sight, sampled every 4px.
  let length = distance(ax, ay, bx, by)
  if length < 1.0:
    return true
  let steps = max(1, int(length / 4.0))
  for step in 1 ..< steps:
    let
      t = float(step) / float(steps)
      x = int(ax + (bx - ax) * t)
      y = int(ay + (by - ay) * t)
    if not scene.walkableAt(x, y):
      return false
  true

## World model

type
  Track = object
    x, y: float
    vx, vy: float
    lastSeen: int

  Endzone = object
    known: bool
    centerX, centerY: float

  Bot = ref object
    scene: Scene
    nav: Nav
    tick: int
    slot: int                            # from COWORLD_PLAYER_WS_URL ?slot=
    myColor: string
    teams: int
    alive: bool
    meX, meY: float
    carrying: bool
    estimatedAim: int
    aimMarkerSeen: bool
    rotationSign: int
    fireReadyTick: int
    previousFire: bool
    endzones: array[4, Endzone]          # by TeamColorNames index
    plantedSeen: array[4, bool]          # a planted flag is visible this frame
    plantedX, plantedY: array[4, float]
    sawOwnPlanted: bool                  # own heart has been on its pedestal
    thiefKnown: bool                     # saw our heart on a carrier
    thiefX, thiefY: float
    thiefLastSeen: int
    enemyTracks: seq[Track]
    mateTracks: seq[Track]

proc colorIndex(color: string): int =
  for i, name in TeamColorNames:
    if name == color:
      return i
  -1

proc slotFromUrl(url: string): int =
  ## Reads the `slot` query parameter from the player websocket URL.
  let key = "slot="
  let at = url.find(key)
  if at < 0:
    return 0
  var i = at + key.len
  var digits = ""
  while i < url.len and url[i] in {'0' .. '9'}:
    digits.add(url[i])
    inc i
  if digits.len == 0: 0 else: digits.parseInt()

proc isHomeDefender(slot, teams: int): bool =
  ## One seat in every four of our team-seats holds home. Team seat is
  ## `slot div teams` (2v2 red = even slots; 4ffa color = slot mod 4), so
  ## a 4-agent policy gets exactly one defender and an 8-agent 4ffa8 gets two.
  let n = max(teams, 2)
  (slot div n) mod 4 == 3

proc updateTrack(tracks: var seq[Track], x, y: float, tick: int) =
  var
    bestIndex = -1
    bestDistance = 40.0
  for i, track in tracks:
    let d = distance(track.x, track.y, x, y)
    if d < bestDistance:
      bestDistance = d
      bestIndex = i
  if bestIndex >= 0:
    let elapsed = float(max(1, tick - tracks[bestIndex].lastSeen))
    let
      newVx = clamp((x - tracks[bestIndex].x) / elapsed, -MaxSpeed, MaxSpeed)
      newVy = clamp((y - tracks[bestIndex].y) / elapsed, -MaxSpeed, MaxSpeed)
    tracks[bestIndex].vx = tracks[bestIndex].vx * 0.5 + newVx * 0.5
    tracks[bestIndex].vy = tracks[bestIndex].vy * 0.5 + newVy * 0.5
    tracks[bestIndex].x = x
    tracks[bestIndex].y = y
    tracks[bestIndex].lastSeen = tick
  else:
    tracks.add(Track(x: x, y: y, lastSeen: tick))
    if tracks.len > 12:
      var oldest = 0
      for i, track in tracks:
        if track.lastSeen < tracks[oldest].lastSeen:
          oldest = i
      tracks.delete(oldest)

proc pruneTracks(tracks: var seq[Track], tick: int) =
  var i = 0
  while i < tracks.len:
    if tick - tracks[i].lastSeen > TrackTtl:
      tracks.delete(i)
    else:
      inc i

proc parseIntOr(text: string, fallback: int): int =
  result = fallback
  try:
    result = parseInt(text)
  except ValueError:
    discard

proc parsePoint(token: string): (float, float) =
  let parts = token.split(',')
  if parts.len == 2:
    (float(parseIntOr(parts[0], 0)), float(parseIntOr(parts[1], 0)))
  else:
    (0.0, 0.0)

proc resetTransient(bot: Bot) =
  ## Lobby / interstitial: the map object is gone. Keep the nav grid (the
  ## walkability mask is static per map) but drop all per-match state.
  bot.alive = false
  bot.carrying = false
  bot.rotationSign = 0
  bot.previousFire = false
  bot.sawOwnPlanted = false
  bot.thiefKnown = false
  bot.enemyTracks.setLen(0)
  bot.mateTracks.setLen(0)
  for i in 0 ..< 4:
    bot.plantedSeen[i] = false

proc observe(bot: Bot, advance: int) =
  ## Reads the retained scene into the world model for this decision.
  let scene = bot.scene
  bot.alive = false
  bot.aimMarkerSeen = false
  for i in 0 ..< 4:
    bot.plantedSeen[i] = false
  var
    carriedSeen: array[4, bool]
    carriedX, carriedY: array[4, float]
    enemySightings: seq[(float, float)]
    mateSightings: seq[(float, float)]
  for (id, objectX, objectY, width, height, layer, label) in
      scene.presentObjects():
    discard id
    if label.len == 0:
      continue
    let
      centerX = float(objectX) + float(width) / 2.0
      centerY = float(objectY) + float(height) / 2.0
      tokens = label.split(' ')
      onMap = layer == scene.mapLayer
    case tokens[0]
    of "self":
      if not onMap:
        continue
      bot.alive = true
      bot.meX = centerX
      bot.meY = centerY
      if tokens.len >= 2 and colorIndex(tokens[1]) >= 0:
        bot.myColor = tokens[1]
    of "player":
      if not onMap or tokens.len < 2:
        continue
      if tokens[1] == bot.myColor:
        mateSightings.add((centerX, centerY))
      elif colorIndex(tokens[1]) >= 0:
        enemySightings.add((centerX, centerY))
    of "own":
      # own aim <brads>: absolute turret readback for the rendered tick
      if tokens.len >= 3 and tokens[1] == "aim":
        bot.estimatedAim = ((parseIntOr(tokens[2], bot.estimatedAim) mod 256) +
          256) mod 256
        bot.aimMarkerSeen = true
    of "game":
      # game teams <count> map <width>x<height>
      if tokens.len >= 3 and tokens[1] == "teams":
        bot.teams = parseIntOr(tokens[2], bot.teams)
    of "endzone":
      # endzone <color> <shape> <x0>,<y0> <x1>,<y1>; skip the spectator-only
      # "endzone <color> power <n>" glow by validating the shape token
      if tokens.len >= 5 and tokens[2] in EndzoneShapes:
        let index = colorIndex(tokens[1])
        if index >= 0:
          let
            (x0, y0) = parsePoint(tokens[3])
            (x1, y1) = parsePoint(tokens[4])
          bot.endzones[index] = Endzone(
            known: true,
            centerX: (x0 + x1) / 2.0,
            centerY: (y0 + y1) / 2.0)
    of "red", "blue", "green", "yellow":
      # capture object: heart in the fiction, `flag` in the label
      if not onMap or tokens.len < 2 or tokens[1] != "flag":
        continue
      let index = colorIndex(tokens[0])
      if index < 0:
        continue
      if tokens.len >= 3 and tokens[2] == "planted":
        bot.plantedSeen[index] = true
        bot.plantedX[index] = centerX
        bot.plantedY[index] = centerY
      elif tokens.len >= 3 and tokens[2] == "carried":
        # Own vs enemy is decided after the loop: `self` may arrive later
        # in the same packet than the flag objects.
        carriedSeen[index] = true
        carriedX[index] = centerX
        carriedY[index] = centerY
    else:
      discard

  # Dead-reckon the aim across the ticks we skipped when no marker resyncs.
  if not bot.aimMarkerSeen:
    bot.estimatedAim = ((bot.estimatedAim +
      bot.rotationSign * AimRatePerTick * advance) mod 256 + 256) mod 256

  # Carrying: the enemy heart's carried marker rides on its carrier.
  # Our own heart on a carrier is a thief fix (pedestals are never fogged).
  let myIndex = colorIndex(bot.myColor)
  bot.carrying = false
  if myIndex >= 0 and bot.plantedSeen[myIndex]:
    bot.sawOwnPlanted = true
  if myIndex >= 0 and carriedSeen[myIndex]:
    bot.thiefKnown = true
    bot.thiefX = carriedX[myIndex]
    bot.thiefY = carriedY[myIndex]
    bot.thiefLastSeen = bot.tick
  if bot.alive:
    for i in 0 ..< 4:
      if i != myIndex and carriedSeen[i] and
          distance(carriedX[i], carriedY[i], bot.meX, bot.meY) < 20.0:
        bot.carrying = true
        break

  for (x, y) in enemySightings:
    updateTrack(bot.enemyTracks, x, y, bot.tick)
  for (x, y) in mateSightings:
    updateTrack(bot.mateTracks, x, y, bot.tick)
  pruneTracks(bot.enemyTracks, bot.tick)
  pruneTracks(bot.mateTracks, bot.tick)

proc chooseGoal(bot: Bot): (float, float) =
  ## Grab the heart, run it home, or press the nearest enemy base.
  ## One seat holds our pedestal so a steal is not a free walk-home.
  let myIndex = colorIndex(bot.myColor)
  if bot.carrying:
    if myIndex >= 0 and bot.endzones[myIndex].known:
      return (bot.endzones[myIndex].centerX, bot.endzones[myIndex].centerY)
    if bot.plantedSeen[myIndex]:
      return (bot.plantedX[myIndex], bot.plantedY[myIndex])
    return (bot.meX, bot.meY)
  if isHomeDefender(bot.slot, bot.teams):
    let stolen = bot.sawOwnPlanted and myIndex >= 0 and
      not bot.plantedSeen[myIndex]
    if stolen and bot.thiefKnown and
        bot.tick - bot.thiefLastSeen <= ThiefFixTtl:
      return (bot.thiefX, bot.thiefY)
    if myIndex >= 0 and bot.plantedSeen[myIndex]:
      return (bot.plantedX[myIndex], bot.plantedY[myIndex])
    if myIndex >= 0 and bot.endzones[myIndex].known:
      return (bot.endzones[myIndex].centerX, bot.endzones[myIndex].centerY)
    return (bot.meX, bot.meY)
  var
    bestDistance = 1.0e18
    found = false
  for i in 0 ..< 4:
    if i == myIndex or not bot.plantedSeen[i]:
      continue
    let d = distance(bot.meX, bot.meY, bot.plantedX[i], bot.plantedY[i])
    if d < bestDistance:
      bestDistance = d
      result = (bot.plantedX[i], bot.plantedY[i])
      found = true
  if found:
    return
  for i in 0 ..< 4:
    if i == myIndex or not bot.endzones[i].known:
      continue
    let d = distance(bot.meX, bot.meY,
      bot.endzones[i].centerX, bot.endzones[i].centerY)
    if d < bestDistance:
      bestDistance = d
      result = (bot.endzones[i].centerX, bot.endzones[i].centerY)
      found = true
  if not found:
    result = (bot.meX, bot.meY)

proc steer(bot: Bot, goalX, goalY: float): (float, float) =
  ## Direction to move: flow-field descent with waypoint lookahead, or a
  ## straight line when the grid cannot help (close targets, no mask yet).
  let directDistance = distance(bot.meX, bot.meY, goalX, goalY)
  if directDistance < 1.0:
    return (0.0, 0.0)
  let direct = ((goalX - bot.meX) / directDistance,
    (goalY - bot.meY) / directDistance)
  if not bot.nav.ready or directDistance < GrabSlack:
    return direct
  let goalCell = bot.nav.nearestOpenCell(bot.nav.cellOf(goalX, goalY))
  if goalCell != bot.nav.goalCell or
      bot.tick - bot.nav.fieldTick > RepathTicks:
    bot.nav.computeField(goalCell, bot.tick)
  var myCell = bot.nav.cellOf(bot.meX, bot.meY)
  if not bot.nav.open[myCell]:
    myCell = bot.nav.nearestOpenCell(myCell)
  if bot.nav.field[myCell] < 0:
    return direct
  var current = myCell
  for step in 0 ..< LookaheadCells:
    var
      bestCell = current
      bestValue = bot.nav.field[current]
    let
      cellX = current mod bot.nav.gridWidth
      cellY = current div bot.nav.gridWidth
    for stepY in -1 .. 1:
      for stepX in -1 .. 1:
        if stepX == 0 and stepY == 0:
          continue
        let
          nextX = cellX + stepX
          nextY = cellY + stepY
        if nextX < 0 or nextY < 0 or
            nextX >= bot.nav.gridWidth or nextY >= bot.nav.gridHeight:
          continue
        let next = nextY * bot.nav.gridWidth + nextX
        if bot.nav.field[next] >= 0 and bot.nav.field[next] < bestValue:
          bestValue = bot.nav.field[next]
          bestCell = next
    if bestCell == current:
      break
    current = bestCell
  if current == myCell:
    return direct
  let (waypointX, waypointY) = bot.nav.cellCenter(current)
  let waypointDistance = distance(bot.meX, bot.meY, waypointX, waypointY)
  if waypointDistance < 1.0:
    return direct
  ((waypointX - bot.meX) / waypointDistance,
    (waypointY - bot.meY) / waypointDistance)

proc friendlyBlocked(bot: Bot, aimBrads: int, targetDistance: float): bool =
  ## Friendly fire is on and the server kills the NEAREST player in the
  ## corridor: hold fire when a remembered mate sits near the fire axis
  ## closer than the target.
  let
    angle = float(aimBrads) / 256.0 * 2.0 * PI
    dirX = cos(angle)
    dirY = -sin(angle)
  for track in bot.mateTracks:
    let
      toMateX = track.x - bot.meX
      toMateY = track.y - bot.meY
      along = toMateX * dirX + toMateY * dirY
    if along <= 0.0 or along > targetDistance:
      continue
    let across = abs(toMateX * dirY - toMateY * dirX)
    if across < MateCorridor:
      return true
  false

proc decide(bot: Bot): uint8 =
  if not bot.alive:
    bot.rotationSign = 0
    bot.previousFire = false
    return 0
  let (goalX, goalY) = bot.chooseGoal()
  let (moveX, moveY) = bot.steer(goalX, goalY)
  var mask = octantBits(moveX, moveY)

  # Target: the freshest near enemy track worth turning the turret onto.
  let engageLimit = if bot.carrying: CarrierEngageRange else: EngageRange
  var
    targetFound = false
    targetX, targetY, targetDistance: float
  var bestDistance = engageLimit
  for track in bot.enemyTracks:
    if bot.tick - track.lastSeen > FreshShotTicks:
      continue
    let d = distance(bot.meX, bot.meY, track.x, track.y)
    if d < bestDistance:
      bestDistance = d
      targetFound = true
      targetX = track.x + track.vx * LeadTicks
      targetY = track.y + track.vy * LeadTicks
      targetDistance = d
  var desiredAim = bot.estimatedAim
  if targetFound:
    desiredAim = bradsOf(targetX - bot.meX, targetY - bot.meY)
  elif moveX != 0.0 or moveY != 0.0:
    desiredAim = bradsOf(moveX, moveY)
  let aimError = bradsError(desiredAim, bot.estimatedAim)

  # Fire gate: fresh A press, cooldown done, corridor coverage, clear line,
  # no mate near the axis. The aim locks at the pull, so no rotation then.
  var firing = false
  if targetFound and bot.tick >= bot.fireReadyTick and not bot.previousFire and
      targetDistance <= GunRange:
    let perpendicularMiss =
      targetDistance * abs(sin(float(aimError) / 256.0 * 2.0 * PI))
    if perpendicularMiss < FireSlack + float(PlayerHalf) and
        pixelRayClear(bot.scene, bot.meX, bot.meY, targetX, targetY) and
        not bot.friendlyBlocked(bot.estimatedAim, targetDistance):
      firing = true
  if firing:
    mask = mask or ButtonA
    bot.fireReadyTick = bot.tick + WindupTicks + CooldownTicks
    bot.rotationSign = 0
  else:
    if aimError > 1:
      mask = mask or ButtonB
      bot.rotationSign = 1
    elif aimError < -1:
      mask = mask or ButtonSelect
      bot.rotationSign = -1
    else:
      bot.rotationSign = 0
  bot.previousFire = firing
  mask

proc main() =
  let url = getEnv("COWORLD_PLAYER_WS_URL")
  if url == "":
    quit("morevna: COWORLD_PLAYER_WS_URL is not set", 1)
  echo "morevna: connecting to ", url
  var everConnected = false
  while true:
    try:
      let socket = newWebSocket(url)
      echo "morevna: connected"
      everConnected = true
      let bot = Bot(scene: Scene(), slot: slotFromUrl(url))
      var
        lastMask = 0'u8
        sentAny = false
      while true:
        let advance = pumpFrames(bot.scene, socket)
        bot.tick += advance
        if not bot.scene.mapPlaced:
          bot.resetTransient()
          if sentAny and lastMask != 0:
            socket.send(inputPacket(0), BinaryMessage)
            lastMask = 0
          continue
        if bot.scene.walkReady and
            (not bot.nav.ready or bot.nav.builtVersion != bot.scene.walkVersion):
          bot.nav.buildNav(bot.scene)
        bot.observe(advance)
        let mask = bot.decide()
        if not sentAny or mask != lastMask:
          socket.send(inputPacket(mask), BinaryMessage)
          lastMask = mask
          sentAny = true
    except CatchableError:
      if everConnected:
        echo "morevna: game over, exiting: ", getCurrentExceptionMsg()
        quit(0)
      echo "morevna: connect retry: ", getCurrentExceptionMsg()
      sleep(250)

when isMainModule and not declared(morevnaOfflineHarness):
  main()
