## `center_hold` — Vasilisa's Season 2 controller play.
##
## Every zone phase rectangle is scaled about ONE centre drawn per game, so
## the centre of the current rectangle lies inside every later rectangle.
## Walk to that centre early and hold there; once the next rectangle is
## announced and the shrink is within `enterLead` ticks, walk to the next
## rectangle's centre instead. `margin` is the arrival radius (px);
## `coverBias` is accepted for schema parity with edge_ride and ignored.
## One nearest_reachable host query per step at most.

import "../../../../coworld-ctf/play_sdk/play"

const
  ManifestBytes =
    "{\"abi\":1,\"class\":\"controller\",\"doc\":\"walk to the zone centre early and hold; every later rectangle contains it\",\"modes\":[\"br\"],\"name\":\"center_hold\",\"params\":{\"coverBias\":{\"default\":0.0,\"kind\":\"number\",\"max\":1.0,\"min\":0.0},\"enterLead\":{\"default\":600,\"integer\":true,\"kind\":\"number\",\"max\":600,\"min\":0},\"margin\":{\"default\":60,\"integer\":true,\"kind\":\"number\",\"max\":600,\"min\":40}},\"retune\":true}"
  InitLog = "center_hold initialized"

var
  params: EdgeRideParams
  holding: bool
  lastX, lastY: int32
  haveGoal: bool

proc play_manifest*() {.exportc, cdecl.} =
  discard emitRaw(ManifestBytes)

proc minI(a, b: int32): int32 {.inline.} = (if a < b: a else: b)
proc maxI(a, b: int32): int32 {.inline.} = (if a > b: a else: b)

proc centre(rect: SdkRect): tuple[x, y: int32] =
  ((minI(rect.x1, rect.x2) + maxI(rect.x1, rect.x2)) div 2,
   (minI(rect.y1, rect.y2) + maxI(rect.y1, rect.y2)) div 2)

proc within(ax, ay, bx, by, radius: int32): bool =
  let dx = int64(ax - bx)
  let dy = int64(ay - by)
  dx * dx + dy * dy <= int64(radius) * int64(radius)

proc reset() =
  holding = false
  haveGoal = false
  lastX = 0
  lastY = 0

proc loadParams(dataPtr, dataLen: int32): int32 =
  let decoded = readEdgeRideParams(context(dataPtr, dataLen))
  if not decoded.valid:
    return 1
  params = decoded
  reset()
  0

proc play_init*(paramsPtr, paramsLen, ctxPtr, ctxLen: int32): int32 {.
    exportc, cdecl.} =
  discard ctxPtr
  discard ctxLen
  resetArena()
  result = loadParams(paramsPtr, paramsLen)
  if result == 0:
    log(1, InitLog.toOpenArrayByte(0, InitLog.high))

proc play_step*(viewPtr, viewLen: int32): int32 {.exportc, cdecl.} =
  var decoded: EdgeRideView
  if not readEdgeRideBinaryViewInto(view(viewPtr, viewLen), decoded):
    return 1
  if not decoded.selfPos.present or not decoded.current.present:
    if not holding:
      let code = emitHoldController("center_hold:blind")
      if code < 0: return code
      holding = true
      haveGoal = false
    resetArena()
    return 0
  var target = decoded.current.centre
  if decoded.next.present and decoded.ticksToShrinkPresent and
      decoded.ticksToShrink <= params.enterLead:
    target = decoded.next.centre
  if within(decoded.selfPos.x, decoded.selfPos.y, target.x, target.y, params.margin):
    if not holding:
      let code = emitHoldController("center_hold:hold")
      if code < 0: return code
      holding = true
      haveGoal = false
    resetArena()
    return 0
  let goal = nearestReachable(target.x, target.y)
  if not goal.ok:
    resetArena()
    return 0
  if haveGoal and goal.x == lastX and goal.y == lastY:
    resetArena()
    return 0
  let code = emitNavigateController(goal, "24.0", "center_hold:centre")
  if code < 0: return code
  holding = false
  haveGoal = true
  lastX = goal.x
  lastY = goal.y
  resetArena()
  0

proc play_retune*(oldPtr, oldLen, newPtr, newLen: int32): int32 {.
    exportc, cdecl.} =
  discard oldPtr
  discard oldLen
  resetArena()
  loadParams(newPtr, newLen)
