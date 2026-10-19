## Coworld-BW extensions to BitWorld's sprite protocol.

import
  supersnappy,
  bitworld/spriteprotocol

export spriteprotocol

const
  BwMessageResources* = 0x20'u8
  BwMessageFrame* = 0x21'u8
  BwMessageObject* = 0x22'u8
  BwMessageClear* = 0x23'u8
  BwMessageDelete* = 0x24'u8
  BwMessageVision* = 0x26'u8
  BwMessageStatus* = 0x27'u8
  BwClientKey* = 0x85'u8
  BwClientSpritesOff* = 0x86'u8
  ## 0x87 is SpriteClientSpritesOff in newer BitWorld protocols;
  ## the status opt-in stays clear of it.
  BwClientStatusOn* = 0x88'u8
  ## Player-chosen race, sent once right after connect. The race a slot
  ## plays is the player's decision, not the map's or the commissioner's:
  ## a request received before the game starts wins over any race in the
  ## episode config. One payload byte: 0 terran, 1 zerg, 2 protoss.
  BwClientRaceRequest* = 0x89'u8
  BwClientKeyBytes* = 8
  BwLightTableCount* = 7
  BwPlayerColorCount* = 16
  BwPlayerRampSize* = 8
  BwPaletteBytes* = 256 * 3
  BwCloakBytes* = 256
  BwDarkRows* = 32
  BwTableWidth* = 256

type
  BwMapResources* = object
    ## Shared indexed palette and mixing tables for one map layer.
    layer*: uint8
    palette*: seq[uint8]
    playerColors*: seq[uint8]
    cloakSelector*: seq[uint8]
    darkTable*: seq[uint8]
    lightRows*: array[BwLightTableCount, int]
    lightTables*: array[BwLightTableCount, seq[uint8]]

  BwIndexedFrame* = object
    ## One validated, independently cacheable indexed RLE frame.
    id*, width*, height*: int
    rowOffsets*: seq[int]
    rle*: seq[uint8]

  BwIndexedObject* = object
    ## One indexed draw command.
    id*, frameId*, x*, y*, z*, layer*: int
    nameIndex*: int
    flipped*: bool
    mode*, color*, data1*, data2*, colorShift*: uint8
    auxFrameId*: int

  BwKeyInput* = object
    ## One physical browser key transition for OpenBW.
    down*: bool
    sym*, scancode*: int

  BwVisionObject* = object
    ## One compact bot-visible object in viewport coordinates.
    nameIndex*, x*, y*, width*, height*: int
    mode*: uint8

proc addBytes(packet: var seq[uint8], bytes: openArray[uint8]) =
  ## Appends bytes without changing their representation.
  for value in bytes:
    packet.addU8(value)

proc addBwResources*(packet: var seq[uint8], resources: BwMapResources) =
  ## Appends one compressed BW map-resource packet.
  doAssert resources.palette.len == BwPaletteBytes
  doAssert resources.playerColors.len ==
    BwPlayerColorCount * BwPlayerRampSize
  doAssert resources.cloakSelector.len == BwCloakBytes
  doAssert resources.darkTable.len == BwDarkRows * BwTableWidth
  var raw: seq[uint8]
  raw.addBytes(resources.palette)
  raw.addBytes(resources.playerColors)
  raw.addBytes(resources.cloakSelector)
  raw.addBytes(resources.darkTable)
  for i in 0 ..< BwLightTableCount:
    doAssert resources.lightRows[i] >= 0
    doAssert resources.lightTables[i].len ==
      resources.lightRows[i] * BwTableWidth
    raw.addU16(resources.lightRows[i])
    raw.addBytes(resources.lightTables[i])
  let compressed = supersnappy.compress(raw)
  packet.addU8(BwMessageResources)
  packet.addU8(resources.layer)
  packet.addU32(raw.len)
  packet.addU32(compressed.len)
  packet.addBytes(compressed)

proc addBwFrame*(packet: var seq[uint8], frame: BwIndexedFrame) =
  ## Appends one compressed indexed RLE frame packet.
  doAssert frame.width > 0 and frame.width <= uint16.high.int
  doAssert frame.height > 0 and frame.height <= uint16.high.int
  doAssert frame.rowOffsets.len == frame.height + 1
  var raw: seq[uint8]
  for offset in frame.rowOffsets:
    raw.addU32(offset)
  raw.addBytes(frame.rle)
  let compressed = supersnappy.compress(raw)
  packet.addU8(BwMessageFrame)
  packet.addU32(frame.id)
  packet.addU16(frame.width)
  packet.addU16(frame.height)
  packet.addU32(raw.len)
  packet.addU32(compressed.len)
  packet.addBytes(compressed)

proc addBwObject*(packet: var seq[uint8], item: BwIndexedObject) =
  ## Appends one indexed draw-object packet.
  packet.addU8(BwMessageObject)
  packet.addU32(item.id)
  packet.addU32(item.frameId)
  packet.addI16(item.x)
  packet.addI16(item.y)
  packet.addI16(item.z)
  packet.addU8(uint8(item.layer))
  packet.addU8(if item.flipped: 1'u8 else: 0'u8)
  packet.addU8(item.mode)
  packet.addU8(item.color)
  packet.addU8(item.data1)
  packet.addU8(item.data2)
  packet.addU8(item.colorShift)
  packet.addU32(item.auxFrameId)
  packet.addI16(item.nameIndex)

proc addBwClear*(packet: var seq[uint8]) =
  ## Appends a command that clears all indexed draw objects.
  packet.addU8(BwMessageClear)

proc addBwDelete*(packet: var seq[uint8], objectId: int) =
  ## Appends one indexed draw-object deletion.
  packet.addU8(BwMessageDelete)
  packet.addU32(objectId)

proc addBwVision*(
  packet: var seq[uint8],
  objects: openArray[BwVisionObject]
) =
  ## Appends one complete compact bot-vision frame.
  doAssert objects.len <= uint16.high.int
  packet.addU8(BwMessageVision)
  packet.addU16(objects.len)
  for item in objects:
    packet.addI16(item.nameIndex)
    packet.addI16(item.x)
    packet.addI16(item.y)
    packet.addU16(item.width)
    packet.addU16(item.height)
    packet.addU8(item.mode)

proc addBwSpritesOff*(packet: var seq[uint8]) =
  ## Appends a request for names and positions without graphical sprites.
  packet.addU8(BwClientSpritesOff)

proc isBwSpritesOff*(data: string): bool =
  ## Returns true for one standalone headless-client capability packet.
  data.len == 1 and data[0].uint8 == BwClientSpritesOff

proc addBwStatusOn*(packet: var seq[uint8]) =
  ## Appends an opt-in request for numeric player-status packets.
  ## Off by default so bots built before this message never see it.
  packet.addU8(BwClientStatusOn)

proc isBwStatusOn*(data: string): bool =
  ## Returns true for one standalone status capability packet.
  data.len == 1 and data[0].uint8 == BwClientStatusOn

proc addBwRaceRequest*(packet: var seq[uint8], race: string) =
  ## Appends the player's requested race. Send once, immediately after
  ## connect: the server holds sim creation open for a short lobby and
  ## applies requests received in time. Unknown strings request terran.
  packet.addU8(BwClientRaceRequest)
  packet.addU8(
    case race
    of "zerg": 1'u8
    of "protoss": 2'u8
    else: 0'u8
  )

proc isBwRaceRequest*(data: string): bool =
  ## Returns true for one standalone race-request packet.
  data.len == 2 and data[0].uint8 == BwClientRaceRequest

proc bwRaceRequest*(data: string): string =
  ## The race named by one race-request packet.
  case data[1].uint8
  of 1'u8: "zerg"
  of 2'u8: "protoss"
  else: "terran"

proc addBwStatus*(
  packet: var seq[uint8],
  minerals, gas, supplyUsed, supplyMax: int
) =
  ## Appends one numeric player-status frame for headless clients.
  packet.addU8(BwMessageStatus)
  packet.addU32(max(0, minerals))
  packet.addU32(max(0, gas))
  packet.addU16(clamp(supplyUsed, 0, uint16.high.int))
  packet.addU16(clamp(supplyMax, 0, uint16.high.int))

proc parseBwKey*(data: string, key: var BwKeyInput): bool =
  ## Parses one fixed-size physical key transition packet.
  if data.len != BwClientKeyBytes or data[0].uint8 != BwClientKey:
    return false
  key.down = data[1].uint8 != 0
  key.sym =
    data[2].uint8.int or
    (data[3].uint8.int shl 8) or
    (data[4].uint8.int shl 16) or
    (data[5].uint8.int shl 24)
  key.scancode =
    data[6].uint8.int or
    (data[7].uint8.int shl 8)
  true
