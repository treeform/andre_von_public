## Paintbot Season 2 ladder inspector.
##
## Reads format-2 "shell" replays written by the coworld-ctf engine
## (src/ctf/replay_codec.nim + src/shell/replay_records.nim) and prints, per
## play seat, every accepted play-call record (replay time, tick, the
## canonical ladder JSON with play names and params, entry ids and code
## identities), the lobby-chat transcript, the lifecycle records
## (disconnect/kick/rebind) and the behaviour annotations (accepted intent
## changes, clear-on-death, safe-intent installs, play faults), plus the
## roster (which seat is which policy).
##
## This is a standalone decoder: the byte layout is transcribed from the
## engine's reader procs so the tool does not pull the whole engine in. It
## understands gzip/zlib-compressed replays (the engine's
## isCompressedReplayBytes check) via zippy.
##
## Usage:
##   nim r games/paintbot/tools/ladders.nim [options] FILE.replay ...
##
## Options:
##   --meta:FILE      JSON list of {episode_request_id, policy_version_ids}
##                    (the coworld xp-request episodes dump); matched to each
##                    replay by the ereq_… id in its filename. Slot i of the
##                    list is play seat i.
##   --names:FILE     JSON object mapping policy_version_id -> "policy:vN".
##   --seat:N         Only print seat N (repeatable).
##   --policy:NAME    Only print seats whose roster name contains NAME
##                    (substring, repeatable).
##   --fired-summary  With --fired: print one line over all files (games fired /
##                    games, intents) instead of one line per replay.
##   --fired:REASON   Per selected seat, print whether any accepted intent
##                    carried this reason (e.g. sentinel:scan) and how many:
##                    the "did the change fire" line for one replay.
##   --drive          Per seat, tally accepted intent changes by the driving
##                    entry (plus the last accepted intent before death) and
##                    entry and by intent kind/reason (which play actually
##                    moved the cog, and what it asked for).
##   --summary        Print only the per-seat summary table (call counts,
##                    distinct ladders, chat lines), no record dump.
##   --no-annotations Skip the annotation dump (they are chatty).
##   --verify         Recompute the shell manifest chains (SHA-256) and
##                    report whether they match the recorded manifest.
##
## Example:
##   nim r games/paintbot/tools/ladders.nim --meta:pb_replays/meta.json \
##     --names:pb_replays/names.json --policy:apex pb_replays/*.replay
##
## Verified against the engine fixtures in
## /Users/me/p/coworld-ctf/tests/fixtures/shell/replay/*.bin (pass a .bin
## and the tool decodes it as a bare record stream).

import std/[json, os, parseopt, strutils, tables, algorithm, sequtils, sets]
import zippy
import crunchy

const
  ReplayMagic = "COWLDCTF"
  ReplayFps = 24
  ## bitworld/replays.nim record types
  ReplayTickHashRecord = 0x01'u8
  ReplayInputRecord = 0x02'u8
  ReplayJoinRecord = 0x03'u8
  ReplayLeaveRecord = 0x04'u8
  ReplayChatRecord = 0x05'u8
  ReplayDebugSpriteRecord = 0x06'u8
  ## src/shell/types.nim format-2 shell records
  RecPlayCall = 0x10'u8
  RecBehaviorAnnotation = 0x11'u8
  RecManifest = 0x12'u8
  RecLobbyChat = 0x13'u8
  RecDisconnect = 0x14'u8
  RecKick = 0x15'u8
  RecRebind = 0x16'u8
  RecVoteReserved = 0x17'u8
  FaultCodeNames = [
    "unknown", "outOfFuel", "epochDeadline", "unreachable", "stackOverflow",
    "memoryOutOfBounds", "tableOutOfBounds", "indirectCallToNull",
    "badSignature", "integerOverflow", "integerDivisionByZero",
    "badConversionToInteger", "trap", "hostError", "returnedNonzero",
    "refused", "abiViolation", "instantiateFailed", "retuneAbsent"]

type
  ReplayError = object of CatchableError

  CodeIdentity = object
    native: bool
    moduleSha256: string
    nativeName: string
    nativeGameVersion: string

  PlayCallEntry = object
    entryId: string
    code: CodeIdentity

  PlayCall = object
    timeMs: uint32
    seat: uint8
    callNumber: uint64
    ladder: string
    entries: seq[PlayCallEntry]
    rawBytes: string

  Annotation = object
    tick: uint32
    seat: uint8
    kind: uint8
    text: string
    provenance: string   ## acceptedIntentChange only: the driving entry
    intentJson: string   ## acceptedIntentChange only: canonical intent JSON
    rawBytes: string

  LobbyChat = object
    timeMs: uint32
    ordinal: uint64
    seat: uint8
    team: uint8
    text: string
    rawBytes: string

  Lifecycle = object
    kind: uint8
    timeMs: uint32
    seat: uint8

  Ballot = object
    timeMs: uint32
    ordinal: uint64
    text: string

  Join = object
    timeMs: uint32
    player: uint8
    name: string
    slot: int
    token: string

  ManifestSeat = object
    callCount: uint32
    callChain: string
    annotationCount: uint32
    annotationChain: string

  Manifest = object
    present: bool
    seats: seq[ManifestSeat]
    transcriptCount: uint32
    transcriptChain: string

  Replay = object
    path: string
    formatVersion: uint16
    gameName: string
    gameVersion: string
    openedAtMs: uint64
    configJson: string
    joins: seq[Join]
    leaves: seq[(uint32, uint8)]
    chats: seq[(uint32, uint8, string)]
    inputCount: int
    hashCount: int
    lastHashTick: uint32
    calls: seq[PlayCall]
    annotations: seq[Annotation]
    lobby: seq[LobbyChat]
    lifecycle: seq[Lifecycle]
    ballots: seq[Ballot]
    manifest: Manifest
    bareRecordStream: bool

## Byte readers (little-endian, bounds-checked like the engine's).

proc fail(message: string) {.noReturn.} =
  raise newException(ReplayError, message)

proc readU8(bytes: string, offset: var int): uint8 =
  if offset + 1 > bytes.len:
    fail("truncated at byte " & $offset)
  result = bytes[offset].uint8
  inc offset

proc readU16(bytes: string, offset: var int): uint16 =
  if offset + 2 > bytes.len:
    fail("truncated at byte " & $offset)
  result = uint16(bytes[offset].uint8) or (uint16(bytes[offset + 1].uint8) shl 8)
  offset += 2

proc readU32(bytes: string, offset: var int): uint32 =
  if offset + 4 > bytes.len:
    fail("truncated at byte " & $offset)
  for shift in countup(0, 24, 8):
    result = result or (uint32(bytes[offset].uint8) shl shift)
    inc offset

proc readU64(bytes: string, offset: var int): uint64 =
  if offset + 8 > bytes.len:
    fail("truncated at byte " & $offset)
  for shift in countup(0, 56, 8):
    result = result or (uint64(bytes[offset].uint8) shl shift)
    inc offset

proc readString16(bytes: string, offset: var int): string =
  let length = int(bytes.readU16(offset))
  if length > bytes.len - offset:
    fail("truncated string at byte " & $offset)
  result = bytes[offset ..< offset + length]
  offset += length

proc readRawHash(bytes: string, offset: var int): string =
  if bytes.len - offset < 32:
    fail("truncated hash at byte " & $offset)
  result = bytes[offset ..< offset + 32].toHex().toLowerAscii()
  offset += 32

proc skipBytes32(bytes: string, offset: var int) =
  let length = int(bytes.readU32(offset))
  if length > bytes.len - offset:
    fail("truncated byte array at byte " & $offset)
  offset += length

## Compression sniffing, transcribed from replay_codec.isCompressedReplayBytes.

proc isCompressed(bytes: string): bool =
  if bytes.len > 18:
    let b0 = bytes[0].uint8
    let b1 = bytes[1].uint8
    let b2 = bytes[2].uint8
    let b3 = bytes[3].uint8
    if b0 == 31'u8 and b1 == 139'u8 and b2 == 8'u8 and (b3 and 224'u8) == 0'u8:
      return true
  if bytes.len > 6:
    let b0 = bytes[0].uint8
    let b1 = bytes[1].uint8
    if (b0 and 15'u8) == 8'u8 and (b0 shr 4) <= 7'u8 and
        ((uint16(b0) * 256'u16 + uint16(b1)) mod 31'u16) == 0'u16:
      return true

## Record decoders.

proc readCodeIdentity(bytes: string, offset: var int): CodeIdentity =
  case bytes.readU8(offset)
  of 0:
    result.moduleSha256 = bytes.readRawHash(offset)
  of 1:
    result.native = true
    result.nativeName = bytes.readString16(offset)
    result.nativeGameVersion = bytes.readString16(offset)
  else:
    fail("unknown play-call code identity")

proc decodePlayCall(bytes: string, offset: var int): PlayCall =
  let start = offset
  if bytes.readU8(offset) != RecPlayCall:
    fail("wrong play-call record type")
  result.timeMs = bytes.readU32(offset)
  result.seat = bytes.readU8(offset)
  result.callNumber = bytes.readU64(offset)
  result.ladder = bytes.readString16(offset)
  let entryCount = int(bytes.readU8(offset))
  for _ in 0 ..< entryCount:
    var entry: PlayCallEntry
    entry.entryId = bytes.readString16(offset)
    entry.code = bytes.readCodeIdentity(offset)
    result.entries.add(entry)
  result.rawBytes = bytes[start ..< offset]

proc readProvenance(bytes: string, offset: var int): string =
  case bytes.readU8(offset)
  of 0:
    let entryId = bytes.readString16(offset)
    let module = bytes.readRawHash(offset)
    let emitTick = bytes.readU32(offset)
    result = "entry " & entryId & " module " & module[0 ..< 12] &
      " emitTick " & $emitTick
  of 1:
    result = "default"
  of 2:
    result = "reflex " & bytes.readString16(offset)
  else:
    fail("unknown annotation provenance base")
  let overlayCount = int(bytes.readU8(offset))
  for _ in 0 ..< overlayCount:
    let entryId = bytes.readString16(offset)
    let module = bytes.readRawHash(offset)
    let acceptedTick = bytes.readU32(offset)
    let policy = bytes.readRawHash(offset)
    result.add(" +overlay " & entryId & " module " & module[0 ..< 12] &
      " accepted " & $acceptedTick & " policy " & policy[0 ..< 12])

proc decodeAnnotation(bytes: string, offset: var int): Annotation =
  let start = offset
  if bytes.readU8(offset) != RecBehaviorAnnotation:
    fail("wrong annotation record type")
  result.tick = bytes.readU32(offset)
  result.seat = bytes.readU8(offset)
  result.kind = bytes.readU8(offset)
  case result.kind
  of 0:
    let effective = bytes.readU64(offset)
    let provenance = bytes.readProvenance(offset)
    let intent = bytes.readString16(offset)
    result.text = "acceptedIntentChange call#" & $effective & " via " &
      provenance & " intent=" & intent.toHex().toLowerAscii()
    result.provenance = provenance
    result.intentJson = intent
  of 1:
    result.text = "clearOnDeath generation " & $bytes.readU64(offset)
  of 2:
    let generation = bytes.readU64(offset)
    let reason = bytes.readString16(offset)
    let safe = bytes.readString16(offset)
    result.text = "installSafeIntent generation " & $generation & " reason " &
      reason & " safe=" & safe.toHex().toLowerAscii()
  of 3:
    let callNumber = bytes.readU64(offset)
    let entryId = bytes.readString16(offset)
    let reason = bytes.readString16(offset)
    result.text = "playFault(legacy) call#" & $callNumber & " entry " &
      entryId & ": " & reason
  of 4:
    let callNumber = bytes.readU64(offset)
    let code = int(bytes.readU8(offset))
    let entryId = bytes.readString16(offset)
    let reason = bytes.readString16(offset)
    let codeName =
      if code < FaultCodeNames.len: FaultCodeNames[code] else: "code" & $code
    result.text = "playFault call#" & $callNumber & " entry " & entryId &
      " " & codeName & ": " & reason
  else:
    fail("unknown annotation kind " & $result.kind)
  result.rawBytes = bytes[start ..< offset]

proc decodeLobbyChat(bytes: string, offset: var int): LobbyChat =
  let start = offset
  if bytes.readU8(offset) != RecLobbyChat:
    fail("wrong lobby transcript record type")
  result.timeMs = bytes.readU32(offset)
  result.ordinal = bytes.readU64(offset)
  result.seat = bytes.readU8(offset)
  result.team = bytes.readU8(offset)
  result.text = bytes.readString16(offset)
  result.rawBytes = bytes[start ..< offset]

proc decodeLifecycle(bytes: string, offset: var int): Lifecycle =
  result.kind = bytes.readU8(offset)
  result.timeMs = bytes.readU32(offset)
  result.seat = bytes.readU8(offset)

proc decodeBallot(bytes: string, offset: var int): Ballot =
  if bytes.readU8(offset) != RecVoteReserved:
    fail("wrong ballot record type")
  result.timeMs = bytes.readU32(offset)
  let kind = bytes.readU8(offset)
  result.ordinal = bytes.readU64(offset)
  let a = bytes.readU8(offset)
  let b = bytes.readU8(offset)
  let c = bytes.readU8(offset)
  case kind
  of 0: result.text = "cast seat " & $a & " team " & $b & " option " & $c
  of 1: result.text = "resolved category " & $a & " tieBreakDrawn " & $b &
    " finalOption " & $c
  else: fail("unknown ballot record kind")

proc decodeManifest(bytes: string, offset: var int): Manifest =
  if bytes.readU8(offset) != RecManifest:
    fail("wrong manifest record type")
  result.present = true
  let seatCount = int(bytes.readU16(offset))
  for index in 0 ..< seatCount:
    let seat = bytes.readU8(offset)
    if int(seat) != index:
      fail("manifest seat arms must be contiguous")
    var arm: ManifestSeat
    arm.callCount = bytes.readU32(offset)
    arm.callChain = bytes.readRawHash(offset)
    arm.annotationCount = bytes.readU32(offset)
    arm.annotationChain = bytes.readRawHash(offset)
    result.seats.add(arm)
  result.transcriptCount = bytes.readU32(offset)
  result.transcriptChain = bytes.readRawHash(offset)

proc orderedChainHash(records: seq[string]): string =
  ## SHA256(previous raw digest || record), starting from 32 zero bytes.
  if records.len == 0:
    return repeat('0', 64)
  var state = newString(32)
  for record in records:
    let digest = sha256(state & record)
    for index in 0 ..< 32:
      state[index] = char(digest[index])
  state.toHex().toLowerAscii()

proc parseRecords(replay: var Replay, bytes: string, offset: var int) =
  var offset = offset
  while offset < bytes.len:
    let recordStart = offset
    let recordType = bytes.readU8(offset)
    case recordType
    of ReplayTickHashRecord:
      let tick = bytes.readU32(offset)
      discard bytes.readU64(offset)
      inc replay.hashCount
      replay.lastHashTick = tick
    of ReplayInputRecord:
      discard bytes.readU32(offset)
      discard bytes.readU8(offset)
      discard bytes.readU8(offset)
      inc replay.inputCount
    of ReplayJoinRecord:
      var join: Join
      join.timeMs = bytes.readU32(offset)
      join.player = bytes.readU8(offset)
      join.name = bytes.readString16(offset)
      join.slot = int(cast[int16](bytes.readU16(offset)))
      join.token = bytes.readString16(offset)
      replay.joins.add(join)
    of ReplayLeaveRecord:
      let time = bytes.readU32(offset)
      let player = bytes.readU8(offset)
      replay.leaves.add((time, player))
    of ReplayChatRecord:
      let time = bytes.readU32(offset)
      let player = bytes.readU8(offset)
      let message = bytes.readString16(offset)
      replay.chats.add((time, player, message))
    of ReplayDebugSpriteRecord:
      discard bytes.readU32(offset)
      discard bytes.readU8(offset)
      bytes.skipBytes32(offset)
    of RecPlayCall:
      offset = recordStart
      replay.calls.add(bytes.decodePlayCall(offset))
    of RecBehaviorAnnotation:
      offset = recordStart
      replay.annotations.add(bytes.decodeAnnotation(offset))
    of RecLobbyChat:
      offset = recordStart
      replay.lobby.add(bytes.decodeLobbyChat(offset))
    of RecVoteReserved:
      offset = recordStart
      replay.ballots.add(bytes.decodeBallot(offset))
    of RecDisconnect, RecKick, RecRebind:
      offset = recordStart
      replay.lifecycle.add(bytes.decodeLifecycle(offset))
    of RecManifest:
      offset = recordStart
      replay.manifest = bytes.decodeManifest(offset)
      if offset != bytes.len:
        fail("manifest is not the final record")
    else:
      fail("unknown record type 0x" & recordType.toHex() & " at byte " &
        $recordStart)

proc loadReplay(path: string): Replay =
  result.path = path
  var bytes = readFile(path)
  if not bytes.startsWith(ReplayMagic) and bytes.isCompressed():
    bytes = uncompress(bytes)
  var offset = 0
  if not bytes.startsWith(ReplayMagic):
    # Engine fixtures are bare record streams (tests/fixtures/shell/replay).
    result.bareRecordStream = true
    result.parseRecords(bytes, offset)
    return
  offset = ReplayMagic.len
  result.formatVersion = bytes.readU16(offset)
  if result.formatVersion notin [1'u16, 2'u16]:
    fail("unsupported replay format version " & $result.formatVersion)
  result.gameName = bytes.readString16(offset)
  result.gameVersion = bytes.readString16(offset)
  result.openedAtMs = bytes.readU64(offset)
  result.configJson = bytes.readString16(offset)
  result.parseRecords(bytes, offset)

proc verifyManifest(replay: Replay): string =
  if not replay.manifest.present:
    return "no manifest"
  let seatCount = replay.manifest.seats.len
  var calls = newSeq[seq[string]](seatCount)
  var annotations = newSeq[seq[string]](seatCount)
  var transcript: seq[string]
  for call in replay.calls:
    if int(call.seat) < seatCount:
      calls[int(call.seat)].add(call.rawBytes)
  for annotation in replay.annotations:
    if int(annotation.seat) < seatCount:
      annotations[int(annotation.seat)].add(annotation.rawBytes)
  for chat in replay.lobby:
    transcript.add(chat.rawBytes)
  var problems: seq[string]
  for seat in 0 ..< seatCount:
    let arm = replay.manifest.seats[seat]
    if int(arm.callCount) != calls[seat].len or
        arm.callChain != orderedChainHash(calls[seat]):
      problems.add("seat " & $seat & " call chain")
    if int(arm.annotationCount) != annotations[seat].len or
        arm.annotationChain != orderedChainHash(annotations[seat]):
      problems.add("seat " & $seat & " annotation chain")
  if int(replay.manifest.transcriptCount) != transcript.len or
      replay.manifest.transcriptChain != orderedChainHash(transcript):
    problems.add("lobby transcript chain")
  if problems.len == 0: "manifest verified (" & $seatCount & " seats)"
  else: "MANIFEST MISMATCH: " & problems.join(", ")

## Roster: which play seat is which policy.

proc tickOf(timeMs: uint32): int =
  int((uint64(timeMs) * uint64(ReplayFps)) div 1000'u64)

proc playSlots(configJson: string): seq[int] =
  ## Indices of config slots whose control is "play"; play seat i is the
  ## i-th such slot (replay_codec.playSeatsFromConfig).
  try:
    let config = parseJson(configJson)
    if config.kind == JObject and config.hasKey("slots") and
        config["slots"].kind == JArray:
      for index, slot in config["slots"].getElems():
        if slot.kind == JObject and slot{"control"}.getStr() == "play":
          result.add(index)
  except JsonParsingError:
    discard

proc ereqOf(path: string): string =
  let base = path.extractFilename()
  let start = base.find("ereq_")
  if start < 0:
    return ""
  var stop = start
  while stop < base.len and base[stop] notin {'.', '/'}:
    inc stop
  base[start ..< stop]

proc seatNames(replay: Replay, meta: Table[string, seq[string]],
               names: Table[string, string]): seq[string] =
  ## One label per play seat: "policy:vN (versionId)" when both are known.
  let seatCount =
    if replay.manifest.present: replay.manifest.seats.len
    else: max(playSlots(replay.configJson).len, 0)
  let ids = meta.getOrDefault(ereqOf(replay.path), @[])
  for seat in 0 ..< seatCount:
    var label = "seat " & $seat
    if seat < ids.len:
      let id = ids[seat]
      if names.hasKey(id):
        label = names[id] & " (" & id[0 ..< 8] & ")"
      else:
        label = id
        # The join record carries the player's display name; use it when no
        # names map resolves the version id.
        for join in replay.joins:
          if join.slot == seat and join.name.len > 0:
            label = join.name & " (" & id[0 ..< 8] & ")"
            break
    result.add(label)

## Ladder pretty-printing.

proc ladderSummary(ladder: string): string =
  ## "play(param=value,…) > play(…)" — compact one-line view of a ladder.
  try:
    let node = parseJson(ladder)
    var parts: seq[string]
    for play in node{"plays"}.getElems():
      var text = play{"play"}.getStr("?")
      var params: seq[string]
      for key, value in play.pairs:
        if key notin ["play", "entry_id"]:
          params.add(key & "=" & $value)
      if params.len > 0:
        text.add("(" & params.join(",") & ")")
      if play.hasKey("entry_id"):
        text = play["entry_id"].getStr() & ":" & text
      parts.add(text)
    parts.join(" > ")
  except JsonParsingError:
    ladder

proc codeLabel(code: CodeIdentity): string =
  if code.native: "native " & code.nativeName & "@" & code.nativeGameVersion
  else: "module " & code.moduleSha256[0 ..< 12]

## Main.

proc main() =
  var
    files: seq[string]
    metaPath, namesPath: string
    seatFilter: seq[int]
    policyFilter: seq[string]
    summaryOnly = false
    showAnnotations = true
    verify = false
    drive = false
    firedReason = ""
    firedSummary = false
    firedGames, firedTotal, firedIntents = 0
  for kind, key, value in getopt():
    case kind
    of cmdArgument:
      files.add(key)
    of cmdLongOption, cmdShortOption:
      case key
      of "meta": metaPath = value
      of "names": namesPath = value
      of "seat": seatFilter.add(parseInt(value))
      of "policy": policyFilter.add(value)
      of "summary": summaryOnly = true
      of "no-annotations": showAnnotations = false
      of "verify": verify = true
      of "drive": drive = true
      of "fired": firedReason = value
      of "fired-summary": firedSummary = true
      else:
        quit("unknown option --" & key)
    of cmdEnd:
      discard
  if files.len == 0:
    quit("usage: ladders [--meta:FILE] [--names:FILE] [--seat:N] " &
      "[--policy:NAME] [--summary] [--no-annotations] [--verify] " &
      "FILE.replay ...")

  var meta: Table[string, seq[string]]
  if metaPath.len > 0:
    for entry in parseJson(readFile(metaPath)):
      var ids: seq[string]
      for id in entry{"policy_version_ids"}.getElems():
        ids.add(id.getStr())
      meta[entry{"episode_request_id"}.getStr()] = ids
  var names: Table[string, string]
  if namesPath.len > 0:
    for key, value in parseJson(readFile(namesPath)).pairs:
      names[key] = value.getStr()

  for path in files:
    var replay: Replay
    try:
      replay = loadReplay(path)
    except ReplayError as error:
      echo "## ", path, ": ERROR ", error.msg
      continue
    echo "## ", path.extractFilename()
    if not replay.bareRecordStream:
      echo "format ", replay.formatVersion, " game ", replay.gameName, " ",
        replay.gameVersion, " openedAtMs ", replay.openedAtMs,
        " hashes ", replay.hashCount, " (last tick ", replay.lastHashTick,
        ") inputs ", replay.inputCount, " joins ", replay.joins.len,
        " leaves ", replay.leaves.len, " chats ", replay.chats.len
    if verify:
      echo verifyManifest(replay)
    let labels = replay.seatNames(meta, names)
    let slots = playSlots(replay.configJson)

    proc seatLabel(seat: int): string =
      if seat < labels.len: labels[seat] else: "seat " & $seat

    proc seatSelected(seat: int): bool =
      if seatFilter.len > 0 and seat notin seatFilter:
        return false
      if policyFilter.len > 0:
        let label = seatLabel(seat).toLowerAscii()
        for filter in policyFilter:
          if label.contains(filter.toLowerAscii()):
            return true
        return false
      true

    if labels.len > 0:
      echo "roster (", labels.len, " play seats):"
      for seat, label in labels:
        var extra = ""
        if seat < slots.len:
          extra.add(" slot " & $slots[seat])
        for join in replay.joins:
          if seat < slots.len and join.slot == slots[seat]:
            extra.add(" join@" & $join.timeMs & "ms player " & $join.player &
              " name " & join.name.escape())
        echo "  seat ", seat, ": ", label, extra
    elif replay.joins.len > 0:
      echo "joins:"
      for join in replay.joins:
        echo "  ", join.timeMs, "ms player ", join.player, " slot ",
          join.slot, " name ", join.name.escape()

    # Per-seat summary.
    var callsBySeat = initTable[int, seq[PlayCall]]()
    for call in replay.calls:
      callsBySeat.mgetOrPut(int(call.seat), @[]).add(call)
    var lobbyBySeat = initTable[int, int]()
    for chat in replay.lobby:
      inc lobbyBySeat.mgetOrPut(int(chat.seat), 0)
    var faultsBySeat = initTable[int, int]()
    var annotationsBySeat = initTable[int, int]()
    for annotation in replay.annotations:
      inc annotationsBySeat.mgetOrPut(int(annotation.seat), 0)
      if annotation.kind in [3'u8, 4'u8]:
        inc faultsBySeat.mgetOrPut(int(annotation.seat), 0)
    var seats = toSeq(callsBySeat.keys)
    for seat in lobbyBySeat.keys:
      if seat notin seats: seats.add(seat)
    for seat in annotationsBySeat.keys:
      if seat notin seats: seats.add(seat)
    seats.sort()
    echo "summary: seat calls distinct-ladders first-call last-call chat ",
      "annotations faults"
    for seat in seats:
      if not seatSelected(seat):
        continue
      let calls = callsBySeat.getOrDefault(seat, @[])
      var distinctLadders = initHashSet[string]()
      for call in calls:
        distinctLadders.incl(call.ladder)
      let first = if calls.len > 0: $tickOf(calls[0].timeMs) else: "-"
      let last = if calls.len > 0: $tickOf(calls[^1].timeMs) else: "-"
      echo "  ", seatLabel(seat), ": calls ", calls.len, " distinct ",
        distinctLadders.len, " ticks ", first, "..", last, " chat ",
        lobbyBySeat.getOrDefault(seat, 0), " annotations ",
        annotationsBySeat.getOrDefault(seat, 0), " faults ",
        faultsBySeat.getOrDefault(seat, 0)
    if firedReason.len > 0:
      for seat in seats:
        if not seatSelected(seat):
          continue
        var count = 0
        for annotation in replay.annotations:
          if int(annotation.seat) == seat and annotation.kind == 0'u8 and
              annotation.intentJson.contains(firedReason):
            inc count
        inc firedTotal
        if count > 0: inc firedGames
        firedIntents += count
        if not firedSummary:
          echo "fired ", firedReason, " seat ", seat, " ", (if count > 0: "yes" else: "no"), " ", count
    if drive:
      echo "drive: seat -> accepted intent changes by driving entry and intent kind:reason"
      for seat in seats:
        if not seatSelected(seat):
          continue
        var byEntry = initTable[string, int]()
        var byIntent = initTable[string, int]()
        for annotation in replay.annotations:
          if int(annotation.seat) != seat or annotation.kind != 0'u8:
            continue
          var entryName = "default"
          let at = annotation.provenance.find("entry ")
          if at >= 0:
            let rest = annotation.provenance[at + 6 .. ^1]
            let stop = rest.find(' ')
            entryName = if stop < 0: rest else: rest[0 ..< stop]
          inc byEntry.mgetOrPut(entryName, 0)
          var label = "?"
          try:
            let intent = parseJson(annotation.intentJson)
            label = intent{"kind"}.getStr("?") & ":" & intent{"reason"}.getStr("")
          except CatchableError:
            discard
          inc byIntent.mgetOrPut(label, 0)
        var death = "alive"
        var deathTick = high(uint32)
        for annotation in replay.annotations:
          if int(annotation.seat) == seat and annotation.kind == 1'u8:
            death = "died@" & $annotation.tick
            deathTick = annotation.tick
            break
        ## Last accepted intent before death: what the seat was doing when hit.
        var last = "none"
        for annotation in replay.annotations:
          if int(annotation.seat) != seat or annotation.kind != 0'u8:
            continue
          if annotation.tick > deathTick:
            break
          var label = "?"
          try:
            let intent = parseJson(annotation.intentJson)
            label = intent{"kind"}.getStr("?") & ":" & intent{"reason"}.getStr("")
          except CatchableError:
            discard
          last = label & "@" & $annotation.tick
        var parts: seq[string]
        parts.add(death)
        parts.add("last " & last)
        for k, v in byEntry: parts.add(k & " " & $v)
        parts.sort()
        var kinds: seq[string]
        for k, v in byIntent: kinds.add(k & " " & $v)
        kinds.sort()
        echo "  ", seatLabel(seat), ": ", parts.join(", "), " | ", kinds.join(", ")
    if summaryOnly:
      echo ""
      continue

    # Per-seat record dump.
    for seat in seats:
      if not seatSelected(seat):
        continue
      echo ""
      echo "=== ", seatLabel(seat), " ==="
      let calls = callsBySeat.getOrDefault(seat, @[])
      var previousLadder = ""
      for call in calls:
        let changed = call.ladder != previousLadder
        echo "  call#", call.callNumber, " tick ", tickOf(call.timeMs),
          " (", call.timeMs, "ms) ", (if changed: "NEW " else: "same "),
          ladderSummary(call.ladder)
        if changed:
          echo "    ladder: ", call.ladder
          for entry in call.entries:
            echo "    entry ", entry.entryId, " = ", codeLabel(entry.code)
        previousLadder = call.ladder
      for chat in replay.lobby:
        if int(chat.seat) == seat:
          echo "  chat#", chat.ordinal, " tick ", tickOf(chat.timeMs),
            " team ", chat.team, ": ", chat.text.escape()
      for record in replay.lifecycle:
        if int(record.seat) == seat:
          let kind = case record.kind
            of RecDisconnect: "disconnect"
            of RecKick: "kick"
            else: "rebind"
          echo "  lifecycle ", kind, " tick ", tickOf(record.timeMs)
      if showAnnotations:
        for annotation in replay.annotations:
          if int(annotation.seat) == seat:
            echo "  annotation tick ", annotation.tick, " ", annotation.text
    if replay.ballots.len > 0:
      echo ""
      echo "ballots:"
      for ballot in replay.ballots:
        echo "  #", ballot.ordinal, " tick ", tickOf(ballot.timeMs), " ",
          ballot.text
    if replay.chats.len > 0:
      echo ""
      echo "sprite chat (0x05):"
      for chat in replay.chats:
        echo "  ", tickOf(chat[0]), " player ", chat[1], ": ",
          chat[2].escape()
    echo ""
  if firedSummary:
    echo "fired-summary ", firedReason, ": ", firedGames, " of ", firedTotal,
      " games, ", firedIntents, " accepted intents"

main()
