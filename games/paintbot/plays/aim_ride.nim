## `aim_ride` — Vasilisa's edge_ride that faces the likely threat.
##
## Movement is the reference edge_ride verbatim (ride the margin, enter the
## next rectangle before the shrink, divert to cover). The one change: every
## intent carries an idle aim centre pointed at the nearest fresh enemy track,
## or at the zone centre when nothing is tracked. The body sweeps ±32 brads
## around that centre; the reference plays leave it at 0 (east). The aim turns
## 5 brads a tick, so a cog facing the wrong way needs ~30 ticks to answer,
## while 4 hp lasts 36-48 ticks under fire. First sight wins 86% of duels.

import "../../../../coworld-ctf/play_sdk/play"

const
  ManifestBytes =
    "{\"abi\":1,\"class\":\"controller\",\"doc\":\"ride safe-zone edges early and bias toward nearby cover\",\"modes\":[\"br\"],\"name\":\"aim_ride\",\"params\":{\"coverBias\":{\"default\":0.8,\"kind\":\"number\",\"max\":1.0,\"min\":0.0},\"enterLead\":{\"default\":120,\"integer\":true,\"kind\":\"number\",\"max\":600,\"min\":0},\"margin\":{\"default\":220,\"integer\":true,\"kind\":\"number\",\"max\":600,\"min\":40}},\"retune\":true}"
  CoverRadiusMaxPx = 331'i32
  InitLog = "aim_ride initialized"
  TrackFreshTicks = 150'i32   ## a track older than this no longer steers the aim
  AimStepBrads = 8'i32        ## quantise the centre so the intent is not re-sent every tick
  AimPeriodTicks = 6'i32      ## recompute the centre this often

type
  DecisionKind = enum
    dkNone
    dkHold
    dkInside
    dkEnter
    dkMargin
    dkCover

  RawDecision = object
    kind: DecisionKind
    x, y: int32

var
  params: EdgeRideParams
  lastKind: DecisionKind
  lastX, lastY: int32
  lastAim: int32 = -1
  lastAimTick: int32 = -1000
  aimCentre: int32

proc play_manifest*() {.exportc, cdecl.} =
  discard emitRaw(ManifestBytes)

## Intent writer: fixed buffer, canonical key order, no Nim strings.
var
  outBuffer: array[200, byte]
  outLen: int

proc put(text: string) =
  for ch in text:
    outBuffer[outLen] = byte(ch)
    inc outLen

proc putInt(value: int32) =
  var v = value
  if v < 0:
    outBuffer[outLen] = byte('-')
    inc outLen
    v = -v
  var digits: array[12, byte]
  var count = 0
  if v == 0:
    digits[0] = byte('0')
    count = 1
  while v > 0:
    digits[count] = byte(ord('0') + int(v mod 10))
    v = v div 10
    inc count
  while count > 0:
    dec count
    outBuffer[outLen] = digits[count]
    inc outLen

proc emitHoldAim(aim: int32): int32 =
  outLen = 0
  put("{\"arrive_radius\":0.0,\"idle_aim_center_brads\":")
  putInt(aim)
  put(",\"kind\":\"hold\",\"reason\":\"aim_ride:hold\",\"schema\":\"intent\",\"v\":1}")
  emitRaw(outBuffer.toOpenArray(0, outLen - 1))

proc emitNavigateAim(x, y, aim: int32; kind: DecisionKind): int32 =
  outLen = 0
  put("{\"arrive_radius\":24.0,\"idle_aim_center_brads\":")
  putInt(aim)
  put(",\"kind\":\"navigate_to\",\"point\":[")
  putInt(x)
  put(",")
  putInt(y)
  put("],\"reason\":\"aim_ride:")
  case kind
  of dkInside: put("inside")
  of dkEnter: put("enter")
  of dkMargin: put("margin")
  of dkCover: put("cover")
  else: put("goal")
  put("\",\"schema\":\"intent\",\"v\":1}")
  emitRaw(outBuffer.toOpenArray(0, outLen - 1))

proc minI(a, b: int32): int32 {.inline.} =
  if a < b: a else: b

proc maxI(a, b: int32): int32 {.inline.} =
  if a > b: a else: b

proc absI(a: int32): int32 {.inline.} =
  if a < 0: -a else: a

proc clampI(value, lo, hi: int32): int32 {.inline.} =
  if value < lo: lo
  elif value > hi: hi
  else: value

proc bradsOf(dx, dy: int32): int32 =
  ## Engine convention: 0 = east, north = -y, 256 per turn. Octant
  ## approximation atan(t) ~ 32 t, within 4 brads of the truth.
  let ny = -dy
  let ax = absI(dx)
  let ay = absI(ny)
  if ax == 0 and ay == 0:
    return 0
  var a: int32
  if ay <= ax:
    a = (32'i32 * ay) div ax
  else:
    a = 64'i32 - (32'i32 * ax) div ay
  var brads: int32
  if dx >= 0 and ny >= 0: brads = a
  elif dx < 0 and ny >= 0: brads = 128'i32 - a
  elif dx < 0 and ny < 0: brads = 128'i32 + a
  else: brads = 256'i32 - a
  ((brads mod 256) + 256) mod 256

proc rectMinX(rect: SdkRect): int32 {.inline.} = minI(rect.x1, rect.x2)
proc rectMaxX(rect: SdkRect): int32 {.inline.} = maxI(rect.x1, rect.x2)
proc rectMinY(rect: SdkRect): int32 {.inline.} = minI(rect.y1, rect.y2)
proc rectMaxY(rect: SdkRect): int32 {.inline.} = maxI(rect.y1, rect.y2)

proc inside(rect: SdkRect; x, y: int32): bool =
  rect.present and x >= rect.rectMinX and x <= rect.rectMaxX and
    y >= rect.rectMinY and y <= rect.rectMaxY

proc insetBounds(lo, hi, margin: int32): tuple[lo, hi: int32] =
  let effective = minI(margin, (hi - lo) div 4)
  (lo + effective, hi - effective)

proc marginTarget(rect: SdkRect; self: SdkPoint; margin: int32):
    tuple[x, y: int32] =
  let
    xs = insetBounds(rect.rectMinX, rect.rectMaxX, margin)
    ys = insetBounds(rect.rectMinY, rect.rectMaxY, margin)
  (clampI(self.x, xs.lo, xs.hi), clampI(self.y, ys.lo, ys.hi))

proc distanceToEdge(rect: SdkRect; x, y: int32): int32 =
  minI(minI(x - rect.rectMinX, rect.rectMaxX - x),
    minI(y - rect.rectMinY, rect.rectMaxY - y))

proc chooseRaw(selfPos: SdkPoint; zone: SdkZone): RawDecision =
  if not selfPos.present or not zone.current.present:
    return RawDecision(kind: dkHold)
  if not zone.current.inside(selfPos.x, selfPos.y):
    let target = zone.current.marginTarget(selfPos, params.margin)
    return RawDecision(kind: dkInside, x: target.x, y: target.y)
  if zone.next.present and zone.ticksToShrinkPresent and
      zone.ticksToShrink <= params.enterLead:
    let target = zone.next.marginTarget(selfPos, params.margin)
    return RawDecision(kind: dkEnter, x: target.x, y: target.y)
  if zone.current.distanceToEdge(selfPos.x, selfPos.y) < params.margin:
    let target = zone.current.marginTarget(selfPos, params.margin)
    return RawDecision(kind: dkMargin, x: target.x, y: target.y)
  RawDecision(kind: dkHold)

proc chooseAim(view: SdkView): int32 =
  ## Nearest fresh enemy track wins; otherwise face the zone centre.
  let selfPos = view.self.pos
  if not selfPos.present:
    return 0
  let tick = if view.tickPresent: view.tick else: 0'i32
  var bestDist = high(int64)
  var bestDx, bestDy: int32
  for index in 0 ..< view.trackCount:
    let track = view.tracks[index]
    if not track.pos.present or track.downed:
      continue
    if track.freshTickPresent and tick - track.freshTick > TrackFreshTicks:
      continue
    let dx = track.pos.x - selfPos.x
    let dy = track.pos.y - selfPos.y
    let dist = int64(dx) * int64(dx) + int64(dy) * int64(dy)
    if dist < bestDist:
      bestDist = dist
      bestDx = dx
      bestDy = dy
  if bestDist < high(int64):
    return bradsOf(bestDx, bestDy)
  let zone = view.world.zone
  let rect = if zone.next.present: zone.next else: zone.current
  if not rect.present:
    return 0
  let cx = (rect.rectMinX + rect.rectMaxX) div 2
  let cy = (rect.rectMinY + rect.rectMaxY) div 2
  bradsOf(cx - selfPos.x, cy - selfPos.y)

proc coverRadius(): int32 =
  if params.coverBiasScaled <= 0:
    return 0
  int32((int64(CoverRadiusMaxPx) * int64(params.coverBiasScaled) +
    999_999'i64) div 1_000_000'i64)

proc sameDecision(kind: DecisionKind; x = 0'i32; y = 0'i32): bool =
  lastKind == kind and (kind == dkHold or (lastX == x and lastY == y))

proc remember(kind: DecisionKind; x = 0'i32; y = 0'i32) =
  lastKind = kind
  lastX = x
  lastY = y

proc resetDecisionCache() =
  lastKind = dkNone
  lastX = 0
  lastY = 0
  lastAim = -1
  lastAimTick = -1000

proc loadParams(dataPtr, dataLen: int32; clearCache: bool): int32 =
  let decoded = readEdgeRideParams(context(dataPtr, dataLen))
  if not decoded.valid:
    return 1
  params = decoded
  if clearCache:
    resetDecisionCache()
  0

proc play_init*(paramsPtr, paramsLen, ctxPtr, ctxLen: int32): int32 {.
    exportc, cdecl.} =
  discard ctxPtr
  discard ctxLen
  resetArena()
  result = loadParams(paramsPtr, paramsLen, true)
  if result == 0:
    log(1, InitLog.toOpenArrayByte(0, InitLog.high))

proc play_step*(viewPtr, viewLen: int32): int32 {.exportc, cdecl.} =
  var decoded: SdkView
  if not readBinaryViewInto(view(viewPtr, viewLen), decoded):
    return 1
  let tick = if decoded.tickPresent: decoded.tick else: 0'i32
  if tick - lastAimTick >= AimPeriodTicks or lastAim < 0:
    aimCentre = (chooseAim(decoded) div AimStepBrads) * AimStepBrads
    lastAimTick = tick
  let aimChanged = aimCentre != lastAim

  let raw = chooseRaw(decoded.self.pos, decoded.world.zone)
  if raw.kind == dkHold:
    if sameDecision(dkHold) and not aimChanged:
      resetArena()
      return 0
    let code = emitHoldAim(aimCentre)
    if code < 0:
      return code
    remember(dkHold)
    lastAim = aimCentre
    resetArena()
    return 0

  let reachable = nearestReachable(raw.x, raw.y)
  var goal = reachable
  var kind = raw.kind
  let radius = coverRadius()
  if reachable.ok and radius > 0:
    let cover = nearestCover(reachable.x, reachable.y, radius)
    if cover.ok:
      goal = cover
      kind = dkCover
  if not goal.ok:
    resetArena()
    return 0
  if sameDecision(kind, goal.x, goal.y) and not aimChanged:
    resetArena()
    return 0
  let code = emitNavigateAim(goal.x, goal.y, aimCentre, kind)
  if code < 0:
    return code
  remember(kind, goal.x, goal.y)
  lastAim = aimCentre
  resetArena()
  0

proc play_retune*(oldPtr, oldLen, newPtr, newLen: int32): int32 {.
    exportc, cdecl.} =
  discard oldPtr
  discard oldLen
  resetArena()
  loadParams(newPtr, newLen, true)
