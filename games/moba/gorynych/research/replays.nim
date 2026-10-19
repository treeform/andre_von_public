## Binary MOBA replay format v1 (server/cogame_moba/replay.py).
## Layout: magic "MOBA", u8 version=1, u32le header_len, UTF-8 header JSON,
## then tick_count * 60 bytes of post-clamp actions (10 heroes x 6 uint8).
## Positions are not stored; seed + actions determine the episode.

import std/json

const
  Magic* = "MOBA"
  FormatVersion* = 1
  PrefixLen* = 9
  NumHeroes* = 10
  ActionsPerHero* = 6
  BytesPerTick* = NumHeroes * ActionsPerHero
  ActHigh* = [7, 7, 3, 2, 2, 2]
  NoopAction* = [3'u8, 3, 0, 0, 0, 0]
  HeroRoles* = [
    "support", "assassin", "burst", "tank", "carry"
  ]
  TeamNames* = ["radiant", "dire"]

type
  ReplayError* = object of CatchableError
  Replay* = object
    header*: JsonNode
    body*: string
    tickCount*: int

proc raiseReplay(message: string) {.raises: [ReplayError].} =
  ## Raises ReplayError with message.
  raise newException(ReplayError, message)

proc readU32le(data: string, offset: int): uint32 {.raises: [ReplayError].} =
  ## Reads one little-endian u32 at offset.
  if offset < 0 or offset + 4 > data.len:
    raiseReplay("u32le read past end of buffer")
  uint32(data[offset].uint8) or
    (uint32(data[offset + 1].uint8) shl 8) or
    (uint32(data[offset + 2].uint8) shl 16) or
    (uint32(data[offset + 3].uint8) shl 24)

proc writeU32le(value: uint32): string =
  ## Encodes one little-endian u32.
  result = newString(4)
  result[0] = char(value and 0xff)
  result[1] = char((value shr 8) and 0xff)
  result[2] = char((value shr 16) and 0xff)
  result[3] = char((value shr 24) and 0xff)

proc teamOf*(pid: int): int =
  ## Returns 0 radiant or 1 dire for hero pid.
  pid div 5

proc roleOf*(pid: int): int =
  ## Returns hero role 0..4 for pid.
  pid mod 5

proc roleName*(pid: int): string =
  ## Returns the role word for pid.
  HeroRoles[roleOf(pid)]

proc teamName*(pid: int): string =
  ## Returns radiant or dire for pid.
  TeamNames[teamOf(pid)]

proc isNoop*(row: openArray[uint8]): bool =
  ## Reports whether one hero row is the engine no-op.
  if row.len < ActionsPerHero:
    return false
  for i in 0 ..< ActionsPerHero:
    if row[i] != NoopAction[i]:
      return false
  true

proc validateAction*(
  pid, tick: int, row: openArray[uint8]
) {.raises: [ReplayError].} =
  ## Checks one hero action against MultiDiscrete highs.
  if row.len < ActionsPerHero:
    raiseReplay(
      "hero " & $pid & " tick " & $tick & " has " &
      $row.len & " values, expected " & $ActionsPerHero
    )
  for col in 0 ..< ActionsPerHero:
    let value = int(row[col])
    if value < 0 or value >= ActHigh[col]:
      raiseReplay(
        "hero " & $pid & " tick " & $tick & " col " & $col &
        " value " & $value & " outside 0 ..< " & $ActHigh[col]
      )

proc validateBody*(
  body: string, tickCount: int
) {.raises: [ReplayError].} =
  ## Checks body length and every packed action range.
  let expected = tickCount * BytesPerTick
  if body.len != expected:
    raiseReplay(
      "body is " & $body.len & " bytes, expected " &
      $expected & " (" & $tickCount & " ticks x " &
      $BytesPerTick & ")"
    )
  var offset = 0
  for tick in 0 ..< tickCount:
    for pid in 0 ..< NumHeroes:
      var row: array[ActionsPerHero, uint8]
      for col in 0 ..< ActionsPerHero:
        row[col] = body[offset].uint8
        inc offset
      validateAction(pid, tick, row)

proc packReplay*(header: JsonNode, body: string): string {.
    raises: [ReplayError].} =
  ## Encodes a v1 replay from header JSON and packed body bytes.
  if header.kind != JObject:
    raiseReplay("header must be a JSON object")
  let tickNode = header{"tick_count"}
  if tickNode.isNil or tickNode.kind != JInt:
    raiseReplay("header missing integer tick_count")
  let tickCount = tickNode.getInt()
  if tickCount < 0:
    raiseReplay("tick_count must be non-negative")
  validateBody(body, tickCount)
  let headerBytes = $header
  result = Magic
  result.add char(FormatVersion)
  result.add writeU32le(uint32(headerBytes.len))
  result.add headerBytes
  result.add body

proc parseReplay*(data: string): Replay {.raises: [ReplayError].} =
  ## Parses and validates a v1 MOBA replay.
  if data.len < PrefixLen:
    raiseReplay("replay too short (" & $data.len & " bytes)")
  if data[0 .. 3] != Magic:
    raiseReplay("bad magic, expected MOBA")
  if data[4].uint8 != uint8(FormatVersion):
    raiseReplay(
      "unsupported format version " & $data[4].uint8 &
      ", expected " & $FormatVersion
    )
  let headerLen = int(readU32le(data, 5))
  if headerLen < 2:
    raiseReplay("header_len too small")
  if PrefixLen + headerLen > data.len:
    raiseReplay("header extends past end of file")
  let headerSlice = data[PrefixLen ..< PrefixLen + headerLen]
  var header: JsonNode
  try:
    header = parseJson(headerSlice)
  except CatchableError as error:
    raiseReplay("header is not valid JSON: " & error.msg)
  if header.kind != JObject:
    raiseReplay("header is not a JSON object")
  let tickNode = header{"tick_count"}
  if tickNode.isNil or tickNode.kind != JInt:
    raiseReplay("header missing integer tick_count")
  let tickCount = tickNode.getInt()
  if tickCount < 0:
    raiseReplay("tick_count must be non-negative")
  let formatNode = header{"format_version"}
  if formatNode.isNil or formatNode.kind != JInt:
    raiseReplay("header missing integer format_version")
  if formatNode.getInt() != FormatVersion:
    raiseReplay(
      "header format_version " & $formatNode.getInt() &
      " != byte version " & $FormatVersion
    )
  let shaNode = header{"sim_wasm_sha256"}
  if shaNode.isNil or shaNode.kind != JString or
    shaNode.getStr().len == 0:
      raiseReplay("header missing sim_wasm_sha256")
  let config = header{"config"}
  if config.isNil or config.kind != JObject:
    raiseReplay("header missing config object")
  if header{"result"}.isNil:
    raiseReplay("header missing result")
  let bodyStart = PrefixLen + headerLen
  result = Replay(
    header: header,
    body:
      if bodyStart >= data.len: ""
      else: data[bodyStart .. ^1],
    tickCount: tickCount
  )
  validateBody(result.body, result.tickCount)

proc actionAt*(
  replay: Replay, tick, pid, col: int
): uint8 {.raises: [ReplayError].} =
  ## Returns one packed action byte.
  if tick < 0 or tick >= replay.tickCount:
    raiseReplay("tick out of range")
  if pid < 0 or pid >= NumHeroes:
    raiseReplay("pid out of range")
  if col < 0 or col >= ActionsPerHero:
    raiseReplay("column out of range")
  let offset = tick * BytesPerTick + pid * ActionsPerHero + col
  replay.body[offset].uint8

proc rowAt*(
  replay: Replay, tick, pid: int
): array[ActionsPerHero, uint8] {.raises: [ReplayError].} =
  ## Returns the 6 action values for one hero at tick.
  for col in 0 ..< ActionsPerHero:
    result[col] = replay.actionAt(tick, pid, col)

proc heroesPerSeat*(replay: Replay): int {.raises: [ReplayError].} =
  ## Reads config.heroes_per_seat, or infers it from player count.
  let node = replay.header{"config"}{"heroes_per_seat"}
  if not node.isNil and node.kind == JInt:
    let value = node.getInt()
    if value in [1, 5]:
      return value
  let players = replay.header{"config"}{"players"}
  if not players.isNil and players.kind == JArray:
    if players.len == 2:
      return 5
    if players.len == 10:
      return 1
  raiseReplay("cannot resolve heroes_per_seat")

proc playerNames*(replay: Replay): seq[string] =
  ## Returns config player names in seat order.
  result = @[]
  let players = replay.header{"config"}{"players"}
  if players.isNil or players.kind != JArray:
    return
  for player in players:
    result.add player{"name"}.getStr("")

proc seedOf*(replay: Replay): int =
  ## Returns the recorded episode seed, or -1.
  let node = replay.header{"config"}{"seed"}
  if node.isNil:
    return -1
  node.getInt(-1)

proc resultOf*(replay: Replay): JsonNode =
  ## Returns the header result object, or an empty object.
  let node = replay.header{"result"}
  if node.isNil:
    return newJObject()
  node
