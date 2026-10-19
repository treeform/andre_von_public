## Shared constants and navigation for the Seryi Volk hunter.
## Vendored from Metta-AI/cogame-cooperative-hunting `sim_types.nim` and
## Metta-AI/bitworld `pathfinding.nim` (MIT), trimmed to exactly what a
## player-side bot needs: the sprite/object id layout of the wire protocol,
## the prey tables, the input mask bits and the tile BFS.

import std/unicode

## Input mask bits (sprite_v1 [0x84, mask]; bit 0 up .. bit 3 right).
const
  ButtonUp* = 1'u8 shl 0
  ButtonDown* = 1'u8 shl 1
  ButtonLeft* = 1'u8 shl 2
  ButtonRight* = 1'u8 shl 3

## World geometry.
const
  StagTileSize* = 12
  WorldWidthTiles* = 32
  WorldHeightTiles* = 32

## Sprite ids.
const
  TreeSpriteId* = 1
  RockSpriteId* = 2
  BackgroundSpriteId* = 3
  CorpseSpriteId* = 4
  KillGlowSpriteId* = 5
  PreySpriteBase* = 10        ## + PreyKind.ord (0..4)
  IndicatorSpriteBase* = 20   ## 20, 21, 22 for 1-dot, 2-dot, 3-dot
  IndicatorSpriteSize* = 4
  DigitSpriteBase* = 30       ## ids 30-39 for digits 0-9
  DigitSpriteWidth* = 3
  IronSpriteId* = 50
  GoldSpriteId* = 51
  BerryRipeSpriteId* = 53
  BerryPickedSpriteId* = 54
  FoodSpriteId* = 56
  NumPlayerColors* = 20
  PlayerSpriteBase* = 100     ## + colorSlot * 4 + facing (0..79)

## Object id bases.
const
  TileObjectBase* = 1000
  PlayerObjectBase* = 5000
  KillGlowObjectBase* = 7000
  BackgroundObjectBase* = 8000
  IndicatorObjectBase* = 9000
  PreyObjectBase* = 10000
  ItemObjectBase* = 13000
  BerryObjectBase* = 14000

## Registration caps.
const
  MaxPromptRunes* = 1200
  MaxRegistrationBytes* = 4096

## Prey tables.
type PreyKind* = enum
  Rabbit
  Boar
  Stag
  Moose
  Elephant

proc preyMinPlayers*(kind: PreyKind): int =
  case kind
  of Rabbit: 1
  of Boar: 2
  of Stag: 2
  of Moose: 3
  of Elephant: 4

proc preyScore*(kind: PreyKind): int =
  case kind
  of Rabbit: 1
  of Boar: 3
  of Stag: 5
  of Moose: 10
  of Elephant: 18

proc preyLabel*(kind: PreyKind): string =
  case kind
  of Rabbit: "rabbit"
  of Boar: "boar"
  of Stag: "stag"
  of Moose: "moose"
  of Elephant: "elephant"

proc runeCap*(text: string, limit: int): string =
  ## Truncate on a rune boundary, never a byte boundary.
  if limit <= 0:
    return ""
  if text.runeLen <= limit:
    return text
  text.runeSubStr(0, limit)

proc blobFromBytes*(bytes: openArray[uint8]): string =
  ## Converts packet bytes to a websocket binary string.
  result = newString(bytes.len)
  for i, value in bytes:
    result[i] = char(value)

## Tile BFS navigation (bitworld/pathfinding, verbatim logic).
const
  MapWidth* = 32
  MapHeight* = 32
  MapSize = MapWidth * MapHeight

type
  TileStatus* = enum
    TileUnknown
    TileClear
    TileBlocked

  ObstacleMap* = object
    cells*: array[MapSize, TileStatus]

  BfsEntry = object
    x, y: int16

proc tileIndex*(x, y: int): int {.inline.} =
  y * MapWidth + x

proc inBounds*(x, y: int): bool {.inline.} =
  x >= 0 and x < MapWidth and y >= 0 and y < MapHeight

proc markTile*(map: var ObstacleMap, x, y: int, status: TileStatus) =
  if inBounds(x, y):
    map.cells[tileIndex(x, y)] = status

proc getTile*(map: ObstacleMap, x, y: int): TileStatus =
  if not inBounds(x, y):
    return TileBlocked
  map.cells[tileIndex(x, y)]

proc bfsNextStep*(map: ObstacleMap, fromX, fromY, toX, toY: int): uint8 =
  ## Button mask for the first step on the shortest path, avoiding blocked
  ## tiles; unknown tiles count as passable. 0 when already there or no path.
  if fromX == toX and fromY == toY:
    return 0
  if not inBounds(fromX, fromY) or not inBounds(toX, toY):
    return 0

  var
    visited: array[MapSize, bool]
    parent: array[MapSize, int16]
    queue: array[MapSize, BfsEntry]
    qHead = 0
    qTail = 0

  let startIndex = tileIndex(fromX, fromY)
  let goalIndex = tileIndex(toX, toY)

  visited[startIndex] = true
  parent[startIndex] = -1
  queue[qTail] = BfsEntry(x: int16(fromX), y: int16(fromY))
  inc qTail

  const dx = [0'i16, 0, -1, 1]
  const dy = [-1'i16, 1, 0, 0]

  var found = false
  while qHead < qTail:
    let cur = queue[qHead]
    inc qHead
    for i in 0 ..< 4:
      let nx = int(cur.x) + int(dx[i])
      let ny = int(cur.y) + int(dy[i])
      if not inBounds(nx, ny):
        continue
      let nIndex = tileIndex(nx, ny)
      if visited[nIndex]:
        continue
      if map.cells[nIndex] == TileBlocked:
        continue
      visited[nIndex] = true
      parent[nIndex] = int16(tileIndex(int(cur.x), int(cur.y)))
      queue[qTail] = BfsEntry(x: int16(nx), y: int16(ny))
      inc qTail
      if nIndex == goalIndex:
        found = true
        break
    if found:
      break

  if not found:
    return 0

  var cur = goalIndex
  while true:
    let p = int(parent[cur])
    if p == startIndex:
      break
    if p < 0:
      return 0
    cur = p

  let stepX = cur mod MapWidth
  let stepY = cur div MapWidth
  let sdx = stepX - fromX
  let sdy = stepY - fromY
  if sdx == 1: return ButtonRight
  if sdx == -1: return ButtonLeft
  if sdy == 1: return ButtonDown
  if sdy == -1: return ButtonUp
  0

proc greedyStep*(fromX, fromY, toX, toY: int): uint8 =
  ## Fallback greedy single step toward the target, no obstacle avoidance.
  let dx = toX - fromX
  let dy = toY - fromY
  if dx == 0 and dy == 0: return 0
  if abs(dx) >= abs(dy):
    if dx > 0: return ButtonRight
    if dx < 0: return ButtonLeft
  if dy > 0: return ButtonDown
  if dy < 0: return ButtonUp
  0

proc unstickStep*(map: ObstacleMap, fromX, fromY, tick: int): uint8 =
  ## Pick a walkable cardinal neighbour, cycling directions each tick.
  const offsets = [(0, -1, ButtonUp), (1, 0, ButtonRight),
                   (0, 1, ButtonDown), (-1, 0, ButtonLeft)]
  for i in 0 ..< 4:
    let index = (tick + i) mod 4
    let nx = fromX + offsets[index][0]
    let ny = fromY + offsets[index][1]
    if inBounds(nx, ny) and map.cells[tileIndex(nx, ny)] != TileBlocked:
      return uint8(offsets[index][2])
  0

proc pathStep*(map: ObstacleMap, fromX, fromY, toX, toY: int): uint8 =
  ## Primary navigation: BFS when possible, greedy fallback.
  let mask = bfsNextStep(map, fromX, fromY, toX, toY)
  if mask != 0:
    return mask
  greedyStep(fromX, fromY, toX, toY)
