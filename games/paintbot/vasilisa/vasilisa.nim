## Vasilisa the Wise — Paintbot Season 2 play-seat policy.
##
## v3: nil-guard every JSON lookup (v2 segfaulted on a control envelope
## without `statuses` on the 0.7.358 image and was disqualified).
##
## Season 2 seats are PLAY seats: the policy never sends input masks. It
## connects to COWORLD_PLAYER_WS_URL, uploads the reference playbook (wasm
## modules baked into the image), says one lobby line, and then drives its
## cog by sending ordered play ladders (canonical JSON) that the engine
## steps in-process. The live loop reads the 0xB1 view every 6 ticks and
## re-sends the ladder when a gate opens or closes (medkit while wounded,
## a safe pickup, a fight in earshot).
##
## Wire: docs/designs/strategy-play-calling-shell-2026-08-29.md §4.3,
## src/shell/packets.nim and src/shell/canonical.nim in coworld-ctf; the
## transcription follows policies/poc_llm_policy/wire.py. Every integer is
## little-endian, every packet begins `u8 op, u8 ver(1)`, 64-bit ids in
## JSON are decimal strings.

import std/[algorithm, json, math, options, os, strutils, tables, times], whisky

const
  OpModuleUpload = 0xA0'u8
  OpPlayCall = 0xA1'u8
  OpStatusAck = 0xA2'u8
  OpLobbyChatSend = 0xA3'u8
  OpPlayContext = 0xB0'u8
  OpPlayView = 0xB1'u8
  OpLobbyChatBroadcast = 0xB2'u8
  ProtocolVersion = 1'u8
  MaxModuleBytes = 262144
  MaxCallBytes = 4096
  LobbyChatMaxBytes = 512

## Codec

proc putU8(s: var string, v: uint8) = s.add char(v)
proc putU32(s: var string, v: uint32) =
  for i in 0 ..< 4: s.add char((v shr (8 * i)) and 0xff)
proc putU64(s: var string, v: uint64) =
  for i in 0 ..< 8: s.add char((v shr (8 * i)) and 0xff)

proc encodeModuleUpload*(uploadId: uint64, wasm: string): string =
  doAssert wasm.len <= MaxModuleBytes
  result.putU8(OpModuleUpload); result.putU8(ProtocolVersion)
  result.putU64(uploadId); result.putU32(uint32(wasm.len)); result.add wasm

proc encodePlayCall*(proposalId: uint64, call: string): string =
  doAssert call.len <= MaxCallBytes
  result.putU8(OpPlayCall); result.putU8(ProtocolVersion)
  result.putU64(proposalId); result.putU32(uint32(call.len)); result.add call

proc encodeStatusAck*(mark: uint64): string =
  result.putU8(OpStatusAck); result.putU8(ProtocolVersion)
  for i in 0 ..< 6: result.putU8(0)
  result.putU64(mark)

proc encodeLobbyChat*(text: string): string =
  var payload = text
  if payload.len > LobbyChatMaxBytes:
    payload.setLen(LobbyChatMaxBytes)
    while payload.len > 0 and (payload[^1].uint8 and 0xC0) == 0x80:
      payload.setLen(payload.len - 1)
    if payload.len > 0 and payload[^1].uint8 >= 0xC0:
      payload.setLen(payload.len - 1)
  result.putU8(OpLobbyChatSend); result.putU8(ProtocolVersion)
  result.putU32(uint32(payload.len)); result.add payload

type
  PacketKind = enum NotOurs, ContextPacket, ViewPacket, ChatPacket
  Packet = object
    kind: PacketKind
    tick: uint32
    control, payload: string
    ordinal: uint64
    seat, team: uint8

type Cursor = object
  data: string
  at: int

proc take(c: var Cursor, n: int): string =
  if n < 0 or n > c.data.len - c.at:
    raise newException(ValueError, "short packet at " & $c.at)
  result = c.data[c.at ..< c.at + n]
  c.at += n
proc u8(c: var Cursor): uint8 = uint8(c.take(1)[0])
proc u32(c: var Cursor): uint32 =
  let b = c.take(4)
  for i in 0 ..< 4: result = result or (uint32(b[i]) shl (8 * i))
proc u64(c: var Cursor): uint64 =
  let b = c.take(8)
  for i in 0 ..< 8: result = result or (uint64(b[i]) shl (8 * i))
proc payload(c: var Cursor): string =
  let n = int(c.u32())
  c.take(n)

proc decodeServerPacket*(data: string): Packet =
  ## 0xB0/0xB1/0xB2 or NotOurs (the legacy Sprite stream shares the socket).
  if data.len == 0: return
  let op = uint8(data[0])
  if op notin {OpPlayContext, OpPlayView, OpLobbyChatBroadcast}: return
  if data.len < 2 or uint8(data[1]) != ProtocolVersion:
    raise newException(ValueError, "wrong protocol version")
  var c = Cursor(data: data, at: 2)
  case op
  of OpPlayContext:
    result.kind = ContextPacket
    result.control = c.payload()
    result.payload = c.payload()
  of OpPlayView:
    result.kind = ViewPacket
    result.tick = c.u32()
    result.control = c.payload()
    result.payload = c.payload()
  else:
    result.kind = ChatPacket
    result.ordinal = c.u64()
    result.tick = c.u32()
    result.seat = c.u8()
    result.team = c.u8()
    result.payload = c.payload()
  if c.at != data.len:
    raise newException(ValueError, "trailing bytes at " & $c.at)

## Canonical JSON (keys sorted byte-ascending, no whitespace, canonical floats)

proc canonicalFloat(v: float): string =
  if v == 0.0: return "0.0"
  let mag = abs(v)
  if mag >= 1e-6 and mag < 1e21:
    result = $v
    if 'e' in result:
      result = formatFloat(v, ffDecimal, 6).strip(leading = false, chars = {'0'})
      if result.endsWith("."): result.add "0"
  else:
    result = formatFloat(v, ffScientific, 15)

proc canonicalString(s: string): string =
  result.add '"'
  for ch in s:
    case ch
    of '"': result.add "\\\""
    of '\\': result.add "\\\\"
    of '\b': result.add "\\b"
    of '\f': result.add "\\f"
    of '\n': result.add "\\n"
    of '\r': result.add "\\r"
    of '\t': result.add "\\t"
    else:
      if ord(ch) < 0x20: result.add "\\u" & toHex(ord(ch), 4).toLowerAscii
      else: result.add ch
  result.add '"'

proc canonical*(node: JsonNode): string =
  case node.kind
  of JNull: "null"
  of JBool: (if node.getBool: "true" else: "false")
  of JInt: $node.getInt
  of JFloat: canonicalFloat(node.getFloat)
  of JString: canonicalString(node.getStr)
  of JArray:
    var parts: seq[string]
    for item in node: parts.add canonical(item)
    "[" & parts.join(",") & "]"
  of JObject:
    var keys: seq[string]
    for k, _ in node: keys.add k
    keys.sort()
    var parts: seq[string]
    for k in keys: parts.add canonicalString(k) & ":" & canonical(node[k])
    "{" & parts.join(",") & "}"

## The seat

type
  Status = object
    kind, uploadId, proposalId, reason, name: string
    ordinal: uint64
  Seat = ref object
    socket: WebSocket
    slot: int
    nextUploadId, nextProposalId: uint64
    ackMark, highestOrdinal: uint64
    context: JsonNode
    statuses: seq[Status]
    chat: seq[string]
    chatSeats: seq[int]  ## sender seat per chat line
    view: JsonNode
    viewTick: uint32
    lastCall: string
    lastCallAt: float
    calls: int
    closed: bool

proc log(msg: string) =
  echo "vasilisa: ", msg
  stdout.flushFile()

proc slotFromUrl(url: string): int =
  let key = "slot="
  let i = url.find(key)
  if i < 0: return 0
  var j = i + key.len
  var digits = ""
  while j < url.len and url[j] in Digits:
    digits.add url[j]
    inc j
  if digits.len > 0: parseInt(digits) else: 0

proc send(seat: Seat, packet: string) =
  seat.socket.send(packet, BinaryMessage)

proc pump(seat: Seat) =
  ## Ack the highest status ordinal actually received, only when it advances.
  if seat.highestOrdinal > seat.ackMark:
    seat.ackMark = seat.highestOrdinal
    seat.send(encodeStatusAck(seat.ackMark))

proc parseOrdinal(node: JsonNode): uint64 =
  if node == nil: return 0
  if node.kind == JString:
    try: result = parseBiggestUInt(node.getStr) except ValueError: result = 0
  elif node.kind == JInt: result = uint64(node.getInt)

proc strField(node: JsonNode, key: string): string =
  let v = node{key}
  if v == nil: ""
  elif v.kind == JString: v.getStr
  else: $v

proc file(seat: Seat, packet: Packet) =
  case packet.kind
  of ContextPacket:
    seat.context = parseJson(packet.payload)
    log "0xB0 context: " & packet.payload
  of ViewPacket:
    seat.viewTick = packet.tick
    let control = parseJson(packet.control)
    let statuses = control{"statuses"}
    if statuses != nil and statuses.kind == JArray:
     for s in statuses:
       var st = Status(kind: s.strField("kind"), uploadId: s.strField("upload_id"),
                       proposalId: s.strField("proposal_id"), reason: s.strField("reason"),
                       name: s.strField("name"), ordinal: parseOrdinal(s{"ordinal"}))
       seat.highestOrdinal = max(seat.highestOrdinal, st.ordinal)
       seat.statuses.add st
       log "status " & $s
    if packet.payload.len > 0:
      seat.view = parseJson(packet.payload)
  of ChatPacket:
    seat.chat.add packet.payload
    seat.chatSeats.add int(packet.seat)
    log "0xB2 chat seat=" & $packet.seat & " " & packet.payload
  of NotOurs: discard

proc drain(seat: Seat, seconds: float) =
  ## Read for `seconds`, filing every shell packet. Raises on close.
  let deadline = epochTime() + seconds
  while true:
    let remaining = deadline - epochTime()
    if remaining <= 0: return
    let message = seat.socket.receiveMessage(int(remaining * 1000))
    if message.isNone: return
    case message.get.kind
    of BinaryMessage:
      try:
        let packet = decodeServerPacket(message.get.data)
        if packet.kind != NotOurs: seat.file(packet)
      except CatchableError:
        log "bad packet: " & getCurrentExceptionMsg()
      except Defect:
        log "packet defect: " & getCurrentExceptionMsg()
    of Ping: seat.socket.send(message.get.data, Pong)
    else: discard

proc awaitStatus(seat: Seat, pred: proc(s: Status): bool, seconds = 20.0): Option[Status] =
  let deadline = epochTime() + seconds
  var seen = 0
  while epochTime() < deadline:
    for i in seen ..< seat.statuses.len:
      if pred(seat.statuses[i]): return some(seat.statuses[i])
    seen = seat.statuses.len
    seat.pump()
    seat.drain(0.3)

proc upload(seat: Seat, name, blob: string): bool =
  let id = seat.nextUploadId
  inc seat.nextUploadId
  log "0xA0 upload " & name & " id=" & $id & " bytes=" & $blob.len
  seat.send(encodeModuleUpload(id, blob))
  let idText = $id
  let admitted = seat.awaitStatus(proc(s: Status): bool =
    s.uploadId == idText and s.kind in ["module_accepted", "module_rejected"])
  if admitted.isNone:
    log "upload " & name & ": no admission status"; return false
  if admitted.get.kind == "module_rejected":
    log "upload " & name & " REJECTED: " & admitted.get.reason; return false
  let ready = seat.awaitStatus(proc(s: Status): bool =
    s.uploadId == idText and s.kind in ["module_ready", "module_rejected"], 40.0)
  if ready.isNone or ready.get.kind != "module_ready":
    log "upload " & name & ": not ready (" & (if ready.isSome: ready.get.reason else: "timeout") & ")"
    return false
  log "upload " & name & " READY as " & ready.get.name
  true

proc call(seat: Seat, ladder: JsonNode, label: string): bool =
  let payload = canonical(ladder)
  if payload.len > MaxCallBytes:
    log "call too large: " & $payload.len; return false
  let id = seat.nextProposalId
  inc seat.nextProposalId
  log "0xA1 " & label & " id=" & $id & " " & payload
  seat.send(encodePlayCall(id, payload))
  let idText = $id
  let outcome = seat.awaitStatus(proc(s: Status): bool =
    s.proposalId == idText and s.kind in ["call_accepted", "call_rejected"])
  if outcome.isNone:
    log label & ": no call status"; return false
  if outcome.get.kind == "call_rejected":
    log label & " REJECTED: " & outcome.get.reason; return false
  seat.lastCall = payload
  seat.lastCallAt = epochTime()
  inc seat.calls
  log label & " ACCEPTED"
  true

## Persona: the cautious floor (richard's clone sits 6th with it) with
## early aggression released and safe pickups.

const
  TrackFreshTicks = 72
  LootClearPx = 500.0
  ScatterTicks = 300
  MinRecallSeconds = 2.0

type Facts = object
  tick: int
  pos: (float, float)
  hasPos: bool
  hp: int
  maxHp: int
  alive: bool
  zonePhase: int
  aliveTeams: int
  nearestEnemy: float  # -1 when none fresh
  medkitNear: float    # distance to the nearest medkit in view, -1 none
  shieldNear: float    # nearest shield in view, -1 none
  itemNear: float      # nearest non-medkit item, -1 none

proc dist(a, b: (float, float)): float =
  sqrt((a[0] - b[0]) * (a[0] - b[0]) + (a[1] - b[1]) * (a[1] - b[1]))

proc pairOf(node: JsonNode): (float, float) =
  (node[0].getFloat, node[1].getFloat)

proc facts(seat: Seat): Facts =
  result.nearestEnemy = -1
  result.medkitNear = -1
  result.itemNear = -1
  result.shieldNear = -1
  result.maxHp = 4
  let view = seat.view
  if view == nil: return
  result.tick = view{"tick"}.getInt
  let me = view{"self"}
  if me != nil:
    result.hp = me{"hp"}.getInt
    result.alive = me{"alive"}.getBool(true)
    let frac = me{"hp_frac"}.getFloat(1.0)
    if frac > 0 and result.hp > 0:
      result.maxHp = max(1, int(round(float(result.hp) / frac)))
    if me{"pos"} != nil and me{"pos"}.kind == JArray and me{"pos"}.len == 2:
      result.pos = pairOf(me{"pos"}); result.hasPos = true
  let mySeat = if seat.context != nil: seat.context{"self"}{"seat"}.getInt(-1) else: -1
  let myTeam = if seat.context != nil: seat.context{"self"}{"team"}.getStr else: ""
  let tracks = view{"tracks"}
  if tracks != nil and tracks.kind == JArray:
   for t in tracks:
     if t{"pos"} == nil or t{"pos"}.kind != JArray: continue
     if t{"seat"}.getInt(-2) == mySeat or (myTeam.len > 0 and t{"team"}.getStr == myTeam): continue
     let age = result.tick - t{"fresh_tick"}.getInt(result.tick)
     if age > TrackFreshTicks: continue
     if result.hasPos:
       let d = dist(result.pos, pairOf(t{"pos"}))
       if result.nearestEnemy < 0 or d < result.nearestEnemy: result.nearestEnemy = d
  let items = view{"items"}
  if items != nil and items.kind == JArray:
   for it in items:
     if not it{"present"}.getBool(true) or it{"pos"} == nil or not result.hasPos: continue
     let d = dist(result.pos, pairOf(it{"pos"}))
     if it{"kind"}.getStr == "medkit":
       if result.medkitNear < 0 or d < result.medkitNear: result.medkitNear = d
     else:
       if result.itemNear < 0 or d < result.itemNear: result.itemNear = d
  let world = view{"world"}
  if world != nil:
    result.aliveTeams = world{"alive_teams"}.getInt
    if world{"zone"} != nil: result.zonePhase = world{"zone"}{"phase"}.getInt

proc entry(play, id: string, params: JsonNode): JsonNode =
  %*{"play": play, "entry_id": id, "params": params}

var persona* = "base"
var pactPartners*: seq[int]  ## seats that answered the lobby pact line
  ## Selected by `--persona NAME` on the command line (the image's run argv),
  ## so one image carries every single-change experiment:
  ##   base    v3: cautious floor (edge_ride 340/300/1.0, no jackal)
  ##   prefer  target_law prefer bounty, revenge, weakened, isolated (docxology)
  ##   ride    edge_ride margin 240, enterLead 260, coverBias 0.8 (docxology)
  ##   jackal  jackal earshot 900, joinWhen bothWeakened, never exits, while an
  ##           enemy is tracked (docxology)
  ##   loot    loot detourMax 900 with medkits when clear (docxology)
  ##   heal    supply_run whenHpBelow 3, detourMax 700 (docxology)
  ##   center  edge_ride margin 600, enterLead 600, coverBias 0.0: the engine
  ##           clamps a margin past a quarter span to "hold the middle of the
  ##           band", so the cog sits near the rect centre, which every later
  ##           phase rect contains (all phases scale about one fixed centre)
  ##   centerhold  our own wasm play center_hold (games/paintbot/plays): walk
  ##           to the zone centre early and hold; target_law overlay only
  ##   centerwide  center_hold with margin 120 (looser hold, less jitter)
  ##   centerloot  center_hold + loot 400 racing (grenades for the endgame)
  ##   jackalwide  jackal earshot 1200, joinWhen afterKill (reach more fights)
  ##   ridecover   edge_ride 240/260 with coverBias 1.0
  ##   envoy   pact with a wider alliance matcher (non-aggression, no fire,
  ##           honored, never-list) and a reciprocal lobby line naming partners
  ##   pactstrong  pact with protect true, holdFire aliveTeams 4, returnFire
  ##   shieldride base with shield_ride (own wasm): edge_ride + detour to shields/spray cans
  ##   nohold   base without the hold-fire trigger; holdlate = hold fire until 8 teams remain
  ##   shieldride2/shieldaim2  the same plays directly under target_law (no medkit/loot above)
  ##   shieldaim  shield_ride with the threat-facing idle aim on top
  ##   aimride base with aim_ride (own wasm): edge_ride facing the nearest track / zone centre
  ##   huddle  daveey's paintbot-huddle:v159 ladder copied from live replays
  ##   shield  base + loot (400, race) only while a shield is in view and no
  ##           enemy is near: +3 hp layer, the field mints dShieldSoak 0.68/game
  ##   pact    base ladder + a lobby pact proposal; every seat whose lobby
  ##           line says "pact" becomes a partner (joint acts are alliance-only
  ##           under catalog v3)
  ##   docx    docxology's ladder: prefer + ride + jackal together
  ##   still   target_law only: no controller at all, the engine's default
  ##           play and zone reflex do everything (hold minus the loot walk)
  ##   hold    apex's shape: target_law + loot detourMax 2500 only, no
  ##           scatter or edge_ride; the engine's zone reflex does the moving

proc pactEntry(): JsonNode =
  var partners = newJArray()
  for seat in pactPartners: partners.add %("seat:" & $seat)
  if persona == "pactstrong":
    entry("pact", "alliance", %*{"partners": partners, "holdFire": {"aliveTeams": 4},
                                "protect": true, "onBetrayal": "returnFire"})
  else:
    entry("pact", "alliance", %*{"partners": partners, "holdFire": {"aliveTeams": 6},
                                "protect": false, "onBetrayal": "disengage"})

proc huddleLadder(f: Facts, opening: bool): JsonNode =
  ## daveey's (paintbot-huddle:v159) ladder as read from live replays:
  ## scatter, edge_ride 220/160/0.75, target_law prefer weakened/isolated/
  ## bounty from ~tick 1100, supply_run at hp < 2, a short shield loot,
  ## and a late jackal (after a kill, hp floor 1) with the margin at 180.
  var plays = newJArray()
  if f.tick >= 1100:
    plays.add entry("target_law", "filter",
      %*{"prefer": ["weakened", "isolated", "bounty"], "holdTrigger": {"zonePhase": 1}})
  if f.hp < 2 and f.medkitNear >= 0 and f.medkitNear <= 500:
    plays.add entry("supply_run", "heal",
      %*{"whenHpBelow": 2, "detourMax": 500, "contested": "avoid"})
  let clear = f.nearestEnemy < 0 or f.nearestEnemy > LootClearPx
  if f.tick < 1500 and clear and f.itemNear >= 0 and f.itemNear <= 400:
    plays.add entry("loot", "arm", %*{"detourMax": 400, "contested": "race", "medkits": false})
  elif f.shieldNear >= 0 and f.shieldNear <= 100:
    plays.add entry("loot", "shield", %*{"detourMax": 100, "contested": "race", "medkits": false})
  if f.tick >= 2400 and f.nearestEnemy >= 0:
    plays.add entry("jackal", "chain",
      %*{"earshot": 900, "joinWhen": "afterKill", "exitAfter": {"hpFloor": 1}})
  if opening or f.tick < 340:
    plays.add entry("scatter", "scatter", %*{"distance": 320, "ticks": 340})
  plays.add entry("edge_ride", "ride",
    %*{"margin": (if f.tick >= 2400: 180 else: 220), "enterLead": 160, "coverBias": 0.75})
  %*{"plays": plays}

proc ladder(f: Facts, opening: bool): JsonNode =
  ## Overlays first, gated controllers, then the always-on base.
  if persona == "huddle": return huddleLadder(f, opening)
  var plays = newJArray()
  if persona in ["pact", "pactstrong", "envoy"] and pactPartners.len > 0:
    plays.add pactEntry()
  if persona == "hold":
    plays.add entry("target_law", "discipline",
      %*{"prefer": ["weakened", "isolated"], "holdTrigger": {"zonePhase": 1}})
    plays.add entry("loot", "loot", %*{"detourMax": 2500, "contested": "avoid", "medkits": false})
    return %*{"plays": plays}
  if persona == "watchride":
    plays.add entry("target_law", "discipline",
      %*{"prefer": ["weakened", "isolated"], "holdTrigger": {"zonePhase": 1}})
    if opening or f.tick < ScatterTicks:
      plays.add entry("scatter", "scatter", %*{"distance": 320, "ticks": ScatterTicks})
    plays.add entry("watch_ride", "shelter",
      %*{"margin": 240, "enterLead": 260, "coverBias": 0.8})
    return %*{"plays": plays}
  if persona in ["nohold", "holdlate", "preferiso"]:
    ## v4's ladder with only the target_law overlay changed: nohold fires
    ## from the first sight; holdlate holds fire until 8 teams remain;
    ## preferiso reorders the target preference.
    if persona == "nohold":
      plays.add entry("target_law", "discipline", %*{"prefer": ["weakened", "isolated"]})
    elif persona == "preferiso":
      plays.add entry("target_law", "discipline",
        %*{"prefer": ["isolated", "weakened", "revenge"], "holdTrigger": {"zonePhase": 1}})
    else:
      plays.add entry("target_law", "discipline",
        %*{"prefer": ["weakened", "isolated"], "holdTrigger": {"aliveTeams": 8}})
    if f.hp < f.maxHp and f.medkitNear >= 0 and f.medkitNear <= 900:
      plays.add entry("supply_run", "medkit",
        %*{"whenHpBelow": 64, "detourMax": 900, "contested": "avoid"})
    let clearHere = f.nearestEnemy < 0 or f.nearestEnemy > LootClearPx
    if clearHere and f.itemNear >= 0 and f.itemNear <= 300:
      plays.add entry("loot", "loot", %*{"detourMax": 300, "contested": "avoid", "medkits": false})
    if opening or f.tick < ScatterTicks:
      plays.add entry("scatter", "scatter", %*{"distance": 320, "ticks": ScatterTicks})
    plays.add entry("edge_ride", "shelter",
      %*{"margin": 340, "enterLead": 300, "coverBias": 1.0})
    return %*{"plays": plays}
  if persona in ["shieldride2", "shieldaim2", "nohold", "holdlate", "preferiso"]:
    ## shield_ride directly under target_law: v11/v12 never drove because
    ## the medkit and loot entries above it took the controller slot for the
    ## whole ~190-tick opening. Nothing but scatter (pre-call only) outranks it.
    plays.add entry("target_law", "discipline",
      %*{"prefer": ["weakened", "isolated"], "holdTrigger": {"zonePhase": 1}})
    if opening:
      plays.add entry("scatter", "scatter", %*{"distance": 320, "ticks": 120})
    plays.add entry((if persona == "shieldaim2": "shield_aim_ride" else: "shield_ride"), "shelter",
      %*{"margin": 340, "enterLead": 300, "coverBias": 1.0})
    return %*{"plays": plays}
  if persona in ["shieldride", "shieldaim"]:
    ## v4's ladder with shield_ride (own wasm) in place of edge_ride: same
    ## movement plus a detour to shields and spray cans within 600 px.
    ## shieldaim = the same play with aim_ride's threat-facing idle aim.
    plays.add entry("target_law", "discipline",
      %*{"prefer": ["weakened", "isolated"], "holdTrigger": {"zonePhase": 1}})
    if f.hp < 64 and f.medkitNear >= 0 and f.medkitNear <= 900:
      plays.add entry("supply_run", "medkit",
        %*{"whenHpBelow": 64, "detourMax": 900, "contested": "avoid"})
    let clearHere = f.nearestEnemy < 0 or f.nearestEnemy > LootClearPx
    if clearHere and f.itemNear >= 0 and f.itemNear <= 300:
      plays.add entry("loot", "loot", %*{"detourMax": 300, "contested": "avoid", "medkits": false})
    if opening or f.tick < ScatterTicks:
      plays.add entry("scatter", "scatter", %*{"distance": 320, "ticks": ScatterTicks})
    plays.add entry((if persona == "shieldaim": "shield_aim_ride" else: "shield_ride"), "shelter",
      %*{"margin": 340, "enterLead": 300, "coverBias": 1.0})
    return %*{"plays": plays}
  if persona == "aimride":
    ## v4's ladder with aim_ride (own wasm) in place of edge_ride: same
    ## movement, idle aim on the nearest fresh track or the zone centre.
    plays.add entry("target_law", "discipline",
      %*{"prefer": ["weakened", "isolated"], "holdTrigger": {"zonePhase": 1}})
    if f.hp < 64 and f.medkitNear >= 0 and f.medkitNear <= 900:
      plays.add entry("supply_run", "medkit",
        %*{"whenHpBelow": 64, "detourMax": 900, "contested": "avoid"})
    let clearHere = f.nearestEnemy < 0 or f.nearestEnemy > LootClearPx
    if clearHere and f.itemNear >= 0 and f.itemNear <= 300:
      plays.add entry("loot", "loot", %*{"detourMax": 300, "contested": "avoid", "medkits": false})
    if opening or f.tick < ScatterTicks:
      plays.add entry("scatter", "scatter", %*{"distance": 320, "ticks": ScatterTicks})
    plays.add entry("aim_ride", "shelter",
      %*{"margin": 340, "enterLead": 300, "coverBias": 1.0})
    return %*{"plays": plays}
  if persona == "sentinelcover":
    plays.add entry("target_law", "discipline",
      %*{"prefer": ["weakened", "isolated"], "holdTrigger": {"zonePhase": 1}})
    plays.add entry("sentinel_cover", "scan",
      %*{"margin": 60, "enterLead": 48, "coverBias": 0.0})
    return %*{"plays": plays}
  if persona in ["sentinel", "sentinel24", "sentinelloot", "sentinelcover", "pact", "pactstrong", "envoy", "shield", "huddle", "aimride", "shieldride", "shieldaim", "shieldride2", "shieldaim2", "nohold", "holdlate", "preferiso"]:
    plays.add entry("target_law", "discipline",
      %*{"prefer": ["weakened", "isolated"], "holdTrigger": {"zonePhase": 1}})
    if persona == "sentinelloot":
      plays.add entry("loot", "loot", %*{"detourMax": 2500, "contested": "avoid", "medkits": false})
    plays.add entry("sentinel", "scan",
      %*{"margin": 60, "enterLead": (if persona == "sentinel24": 24 else: 48), "coverBias": 0.0})
    return %*{"plays": plays}
  if persona == "still":
    plays.add entry("target_law", "discipline",
      %*{"prefer": ["weakened", "isolated"], "holdTrigger": {"zonePhase": 1}})
    return %*{"plays": plays}
  if persona in ["centerhold", "centerwide", "centerloot", "docx", "jackalwide", "ridecover", "sentinel", "watchride", "sentinel24", "sentinelloot", "sentinelcover", "pact", "pactstrong", "envoy", "shield", "huddle", "aimride", "shieldride", "shieldaim", "shieldride2", "shieldaim2", "nohold", "holdlate", "preferiso"]:
    plays.add entry("target_law", "discipline",
      %*{"prefer": ["weakened", "isolated"], "holdTrigger": {"zonePhase": 1}})
    if persona == "centerloot" and (f.nearestEnemy < 0 or f.nearestEnemy > LootClearPx) and
        f.itemNear >= 0 and f.itemNear <= 400:
      plays.add entry("loot", "loot", %*{"detourMax": 400, "contested": "race", "medkits": false})
    plays.add entry("center_hold", "centre",
      %*{"margin": (if persona == "centerwide": 120 else: 60), "enterLead": 600, "coverBias": 0.0})
    return %*{"plays": plays}
  if persona in ["prefer", "docx"]:
    plays.add entry("target_law", "discipline",
      %*{"prefer": ["bounty", "revenge", "weakened", "isolated"], "holdTrigger": {"zonePhase": 1}})
  else:
    plays.add entry("target_law", "discipline",
      %*{"prefer": ["weakened", "isolated"], "holdTrigger": {"zonePhase": 1}})
  if persona == "heal":
    if f.hp < 3 and f.medkitNear >= 0 and f.medkitNear <= 700:
      plays.add entry("supply_run", "medkit",
        %*{"whenHpBelow": 3, "detourMax": 700, "contested": "avoid"})
  elif f.hp < f.maxHp and f.medkitNear >= 0 and f.medkitNear <= 900:
    plays.add entry("supply_run", "medkit",
      %*{"whenHpBelow": 64, "detourMax": 900, "contested": "avoid"})
  if persona in ["jackal", "docx"] and f.nearestEnemy >= 0 and not (opening or f.tick < ScatterTicks):
    plays.add entry("jackal", "hunt",
      %*{"earshot": 900, "joinWhen": "bothWeakened", "exitAfter": {"hpFloor": 0}})
  if persona == "jackalwide" and f.nearestEnemy >= 0 and not (opening or f.tick < ScatterTicks):
    plays.add entry("jackal", "hunt",
      %*{"earshot": 1200, "joinWhen": "afterKill", "exitAfter": {"hpFloor": 0}})
  let clear = f.nearestEnemy < 0 or f.nearestEnemy > LootClearPx
  if persona == "shield":
    if clear and f.shieldNear >= 0 and f.shieldNear <= 400:
      plays.add entry("loot", "loot", %*{"detourMax": 400, "contested": "race", "medkits": false})
  elif persona == "loot":
    if clear and ((f.itemNear >= 0 and f.itemNear <= 900) or (f.medkitNear >= 0 and f.medkitNear <= 900)):
      plays.add entry("loot", "loot", %*{"detourMax": 900, "contested": "avoid", "medkits": true})
  elif clear and f.itemNear >= 0 and f.itemNear <= 300:
    plays.add entry("loot", "loot", %*{"detourMax": 300, "contested": "avoid", "medkits": false})
  if opening or f.tick < ScatterTicks:
    plays.add entry("scatter", "scatter", %*{"distance": 320, "ticks": ScatterTicks})
  if persona in ["ride", "docx"]:
    plays.add entry("edge_ride", "shelter",
      %*{"margin": 240, "enterLead": 260, "coverBias": 0.8})
  elif persona == "ridecover":
    plays.add entry("edge_ride", "shelter",
      %*{"margin": 240, "enterLead": 260, "coverBias": 1.0})
  elif persona == "center":
    plays.add entry("edge_ride", "shelter",
      %*{"margin": 600, "enterLead": 600, "coverBias": 0.0})
  else:
    plays.add entry("edge_ride", "shelter",
      %*{"margin": 340, "enterLead": 300, "coverBias": 1.0})
  %*{"plays": plays}

proc lobbyLine(): string =
  if persona == "envoy":
    "Vasilisa: non-aggression from the drop with anyone who names us back. Say pact or no fire and we hold fire on you until 6 teams remain."
  elif persona == "pactstrong":
    "pact: I will not shoot anyone who says pact, and I will defend you, until 4 teams remain. Say pact to join."
  elif persona == "pact":
    "Vasilisa proposes a pact: hold fire on each other until 6 teams remain. Reply with the word pact to join."
  else:
    "Vasilisa here. No heroes: riding the wide line, shooting what comes to me. Good luck all."

const AllianceWords = ["pact", "non-aggression", "no fire", "hold fire", "honored",
                       "honour", "not fire on", "never-list", "no shoot"]

proc alliancePhrase(text: string): bool =
  let lower = text.toLowerAscii
  for w in AllianceWords:
    if lower.contains(w): return true
  false

proc updatePartners(seat: Seat) =
  ## pact/pactstrong: every seat whose lobby line mentions a pact joins ours.
  ## envoy: any alliance phrasing counts, and we answer by name.
  if persona notin ["pact", "pactstrong", "envoy", "shield", "huddle", "aimride", "shieldride", "shieldaim", "shieldride2", "shieldaim2", "nohold", "holdlate", "preferiso"]: return
  var found: seq[int]
  for i, text in seat.chat:
    let sender = seat.chatSeats[i]
    if sender == seat.slot: continue
    let ok = if persona == "envoy": alliancePhrase(text) else: text.toLowerAscii.contains("pact")
    if ok and sender notin found: found.add sender
  found.sort()
  if found.len > 8: found.setLen(8)
  pactPartners = found

## Main

proc loadPlaybook(dir: string): seq[(string, string)] =
  for path in walkFiles(dir / "*.wasm"):
    result.add (path.splitFile.name, readFile(path))
  result.sort(proc(a, b: (string, string)): int =
    cmp((if a[0] == "edge_ride": 0 else: 1), (if b[0] == "edge_ride": 0 else: 1)))
  if result.len == 0: quit("vasilisa: no .wasm modules in " & dir, 1)

proc runSeat(url: string, playbook: seq[(string, string)]) =
  let seat = Seat(socket: newWebSocket(url), slot: slotFromUrl(url),
                  nextUploadId: 1, nextProposalId: 1)
  log "connected as slot " & $seat.slot
  # Context first: nothing can be uploaded before the seat is bound.
  let deadline = epochTime() + 180.0
  while seat.context == nil and epochTime() < deadline:
    seat.drain(1.0)
    seat.pump()
  if seat.context == nil:
    log "no 0xB0 context within 180 s"; return
  for (name, blob) in playbook:
    discard seat.upload(name, blob)
    seat.pump()
    seat.drain(0.2)
  discard seat.call(ladder(seat.facts(), opening = true), "pre-call")
  seat.send(encodeLobbyChat(lobbyLine()))
  seat.pump()
  var namedBack = false
  # Live loop: re-send the ladder when the gated set changes.
  while true:
    seat.drain(0.25)
    seat.pump()
    if seat.view == nil: continue
    let f = seat.facts()
    if not f.alive: continue
    seat.updatePartners()
    if persona == "envoy" and not namedBack and pactPartners.len > 0 and f.tick < 500:
      var names: seq[string]
      for p in pactPartners: names.add("seat " & $p)
      seat.send(encodeLobbyChat("Vasilisa honors " & names.join(", ") & ": no fire on you until 6 teams remain. Name us back."))
      namedBack = true
    let wanted = canonical(ladder(f, opening = false))
    if wanted != seat.lastCall and epochTime() - seat.lastCallAt >= MinRecallSeconds:
      discard seat.call(parseJson(wanted), "re-call")

when defined(vasilisaTest):
  proc hex(s: string): string =
    for ch in s: result.add toHex(ord(ch), 2).toLowerAscii
  let dir = getEnv("SHELL_FIXTURES", getHomeDir() / "p/coworld-ctf/tests/fixtures/shell")
  # 0xA0 golden: uploadId 0x0102030405060708, 8 bytes "\0asm\1\0\0\0"
  let up = encodeModuleUpload(0x0102030405060708'u64, "\0asm\1\0\0\0")
  doAssert hex(up) == hex(readFile(dir / "packets/module_upload.bin")), "module_upload"
  let chatGolden = readFile(dir / "packets/lobby_chat_send.bin")
  doAssert hex(encodeLobbyChat("meet at center")) == hex(chatGolden), "lobby_chat_send"
  let ack = encodeStatusAck(0x0102030405060708'u64)
  doAssert hex(ack) == hex(readFile(dir / "packets/status_ack.bin")), "status_ack"
  let bc = decodeServerPacket(readFile(dir / "packets/lobby_chat_broadcast.bin"))
  doAssert bc.kind == ChatPacket and bc.payload == "pact?" and bc.seat == 3 and bc.team == 12, "broadcast"
  let pv = decodeServerPacket(readFile(dir / "packets/play_view.bin"))
  doAssert pv.kind == ViewPacket, "play_view"
  let pc = decodeServerPacket(readFile(dir / "packets/play_context.bin"))
  doAssert pc.kind == ContextPacket, "play_context"
  let callGolden = readFile(dir / "ladder_call.golden.json").strip
  doAssert canonical(parseJson(callGolden)) == callGolden, "canonical ladder"
  let floats = parseJson(readFile(dir / "floats.golden.json"))
  echo "floats golden: ", floats
  echo "codec self-test passed; view tick ", pv.tick, " view bytes ", pv.payload.len
  pactPartners = @[3, 7]
  for name in ["base", "prefer", "ride", "jackal", "loot", "heal", "hold", "center", "centerhold", "still", "centerwide", "centerloot", "docx", "jackalwide", "ridecover", "sentinel", "watchride", "sentinel24", "sentinelloot", "sentinelcover", "pact", "pactstrong", "envoy", "shield", "huddle", "aimride", "shieldride", "shieldaim", "shieldride2", "shieldaim2", "nohold", "holdlate", "preferiso"]:
    persona = name
    let f = Facts(hp: 2, maxHp: 4, medkitNear: 400, nearestEnemy: 300, itemNear: 600, tick: 800)
    let text = canonical(ladder(f, false))
    doAssert text.len <= MaxCallBytes
    echo name, ": ", text
elif isMainModule:
  let url = getEnv("COWORLD_PLAYER_WS_URL")
  if url == "": quit("vasilisa: COWORLD_PLAYER_WS_URL is not set", 1)
  for i in 1 .. paramCount():
    if paramStr(i) == "--persona" and i < paramCount(): persona = paramStr(i + 1)
  log "persona " & persona
  let playbook = loadPlaybook(getEnv("VASILISA_PLAYBOOK", "/playbook"))
  log "playbook: " & $playbook.len & " modules"
  var everConnected = false
  while true:
    try:
      runSeat(url, playbook)
      everConnected = true
      log "seat loop ended; exiting"
      quit(0)
    except CatchableError:
      if everConnected:
        log "socket closed: " & getCurrentExceptionMsg()
        quit(0)
      log "connect retry: " & getCurrentExceptionMsg()
      sleep(500)
