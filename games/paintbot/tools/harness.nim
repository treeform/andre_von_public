## Offline parse/decide harness for morevna.
## Feeds a synthetic Sprite v1 handshake + a couple of frames through the
## bot's applyPacket/observe/decide path and prints what it would send.
##
##   nim c --hints:off -r games/paintbot/tools/harness.nim

import std/strutils

const morevnaOfflineHarness = true
include ../morevna/morevna

proc putU8(packet: var string, value: uint8) =
  packet.add(char(value))

proc putU16(packet: var string, value: int) =
  packet.add(char(value and 0xff))
  packet.add(char((value shr 8) and 0xff))

proc putI16(packet: var string, value: int) =
  var n = value
  if n < 0:
    n += 65536
  putU16(packet, n)

proc putU32(packet: var string, value: int) =
  packet.add(char(value and 0xff))
  packet.add(char((value shr 8) and 0xff))
  packet.add(char((value shr 16) and 0xff))
  packet.add(char((value shr 24) and 0xff))

proc putBytes(packet: var string, data: string) =
  packet.add(data)

proc defineLayer(packet: var string, layer, kind, flags: int) =
  putU8(packet, MessageDefineLayer)
  putU8(packet, uint8(layer))
  putU8(packet, uint8(kind))
  putU8(packet, uint8(flags))

proc setViewport(packet: var string, layer, width, height: int) =
  putU8(packet, MessageSetViewport)
  putU8(packet, uint8(layer))
  putU16(packet, width)
  putU16(packet, height)

proc defineSprite(packet: var string; id, width, height: int;
    compressed, label: string) =
  putU8(packet, MessageDefineSprite)
  putU16(packet, id)
  putU16(packet, width)
  putU16(packet, height)
  putU32(packet, compressed.len)
  putBytes(packet, compressed)
  putU16(packet, label.len)
  putBytes(packet, label)

proc defineObject(packet: var string; id, x, y, z, layer, spriteId: int) =
  putU8(packet, MessageDefineObject)
  putU16(packet, id)
  putI16(packet, x)
  putI16(packet, y)
  putI16(packet, z)
  putU8(packet, uint8(layer))
  putU16(packet, spriteId)

proc deleteObject(packet: var string, id: int) =
  putU8(packet, MessageDeleteObject)
  putU16(packet, id)

proc hexOf(data: string): string =
  result = ""
  for i, ch in data:
    if i > 0:
      result.add(' ')
    result.add(toHex(ord(ch), 2).toLowerAscii)

proc maskBits(mask: uint8): string =
  var parts: seq[string]
  if (mask and ButtonUp) != 0: parts.add("up")
  if (mask and ButtonDown) != 0: parts.add("down")
  if (mask and ButtonLeft) != 0: parts.add("left")
  if (mask and ButtonRight) != 0: parts.add("right")
  if (mask and ButtonSelect) != 0: parts.add("select")
  if (mask and ButtonA) != 0: parts.add("A")
  if (mask and ButtonB) != 0: parts.add("B")
  if parts.len == 0: "none" else: parts.join("+")

proc snappyLiteral(raw: string): string =
  ## One-literal snappy stream (raw.len <= 60).
  doAssert raw.len >= 1 and raw.len <= 60
  result = newString(1)
  result[0] = char(raw.len)          # varint length
  result.add(char(((raw.len - 1) shl 2) and 0xff))
  result.add(raw)

proc rgbaCell(r, g, b, a: uint8): string =
  result = newString(4)
  result[0] = char(r)
  result[1] = char(g)
  result[2] = char(b)
  result[3] = char(a)

proc drive(label: string, packet: string) =
  echo "=== ", label, " ==="
  let bot = Bot(scene: Scene())
  try:
    bot.scene.applyPacket(packet)
  except CatchableError:
    echo "PIPELINE DIE: applyPacket raised ", getCurrentExceptionMsg()
    echo ""
    return
  echo "mapPlaced=", bot.scene.mapPlaced,
    " mapLayer=", bot.scene.mapLayer,
    " walkReady=", bot.scene.walkReady
  if bot.scene.sprites.len > MapSpriteId:
    echo "sprite1.label=", repr(bot.scene.sprites[MapSpriteId].label),
      "  (empty: a MapLabel==\"map\" detector never fires)"
  if not bot.scene.mapPlaced:
    echo "PIPELINE DIE: mapPlaced=false -> main would skip 0x84 input"
    echo ""
    return
  if bot.scene.walkReady:
    bot.nav.buildNav(bot.scene)
  bot.tick = 1
  bot.observe(1)
  echo "alive=", bot.alive, " me=", bot.meX, ",", bot.meY,
    " color=", bot.myColor, " carrying=", bot.carrying
  let mask = bot.decide()
  let blob = inputPacket(mask)
  echo "would send 0x84 mask=0x", toHex(mask, 2).toLowerAscii,
    " (", maskBits(mask), ") bytes=[", hexOf(blob), "]"
  if blob.len != 2 or blob[0].uint8 != 0x84:
    echo "PIPELINE DIE: input packet is not a 0x84 Player Input"
  echo "ready/sprites-off: not sent (correct for this game)"
  echo ""

proc lobbyFrame(): string =
  ## Layers only — the map camera object is absent (interstitial).
  defineLayer(result, 0, 0, 1)
  setViewport(result, 0, 200, 100)

proc inGameFrame(): string =
  ## Production-shaped snapshot: sprite 1 is unlabeled chrome, object 1
  ## uses sprite 1, walkability carries snappy pixels, self + enemy flag
  ## + endzones + own-aim are present.
  # sprite_v1.md 2x2 example payload (18 bytes, decompresses to 16 RGBA).
  const exampleSnappy =
    "\x10\x3c\xff\x00\x00\xff\x00\xff\x00\xff\x00\x00\xff\xff\x00\x00\x00\x00"
  var walkRaw = ""
  for i in 0 ..< 4:
    walkRaw.add(rgbaCell(0, 0, 0, 255))  # alpha>0 = walkable
  let walkSnappy = snappyLiteral(walkRaw)

  defineLayer(result, 0, 0, 1)
  setViewport(result, 0, 200, 100)
  defineSprite(result, 1, 2, 2, exampleSnappy, "")  # map camera art, no label
  defineSprite(result, 2, 2, 2, walkSnappy, WalkLabel)
  defineSprite(result, 3, 12, 12, "", "self red right")
  defineSprite(result, 4, 8, 8, "", "blue flag planted")
  defineSprite(result, 5, 1, 1, "", "endzone red column 0,0 40,100")
  defineSprite(result, 6, 1, 1, "", "endzone blue column 160,0 200,100")
  defineSprite(result, 7, 1, 1, "", "game teams 2 map 200x100")
  defineSprite(result, 8, 1, 1, "", "own aim 0")
  defineObject(result, 1, 0, 0, 0, 0, 1)       # map camera
  defineObject(result, 2, 20, 40, 0, 0, 3)     # self
  defineObject(result, 3, 170, 40, 0, 0, 4)    # blue flag
  defineObject(result, 4, 0, 0, 0, 1, 5)       # our endzone (HUD layer)
  defineObject(result, 5, 0, 0, 0, 1, 6)
  defineObject(result, 6, 0, 0, 0, 1, 7)
  defineObject(result, 7, 0, 0, 0, 1, 8)

proc objectBeforeSpriteFrame(): string =
  ## Object 1 arrives before sprite 1 is defined. Id-based detection must
  ## still mark the match running.
  defineObject(result, 1, 0, 0, 0, 0, 1)
  defineSprite(result, 1, 2, 2, "", "")
  defineSprite(result, 3, 12, 12, "", "self red left")
  defineObject(result, 2, 10, 10, 0, 0, 3)

when isMainModule:
  drive("lobby / interstitial (no map camera)", lobbyFrame())
  drive("in-game snapshot (unlabeled map sprite id 1)", inGameFrame())
  drive("object 1 before sprite 1 is defined", objectBeforeSpriteFrame())
