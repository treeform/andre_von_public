## `sentinel_cover` — sentinel that first walks to the nearest cover post.
##
## Re-simulated replays show the first hitter wins 86% of duels and 77% of
## victims never fire back: first sight decides. The body sweeps the idle
## aim ±45° around `idle_aim_center_brads`, and every reference play leaves
## that centre at 0 (east), so a holding cog is blind to three quarters of
## the map. This play holds in place and rotates the idle aim centre a
## quarter turn every `enterLead` ticks (default 48), so the cog watches all
## four quadrants every four periods. Zone reflexes still move it. `margin`
## and `coverBias` are accepted for schema parity and ignored.

import "../../../../coworld-ctf/play_sdk/play"

const
  ManifestBytes =
    "{\"abi\":1,\"class\":\"controller\",\"doc\":\"hold and rotate the idle aim through every quadrant for first sight\",\"modes\":[\"br\"],\"name\":\"sentinel_cover\",\"params\":{\"coverBias\":{\"default\":0.0,\"kind\":\"number\",\"max\":1.0,\"min\":0.0},\"enterLead\":{\"default\":48,\"integer\":true,\"kind\":\"number\",\"max\":600,\"min\":0},\"margin\":{\"default\":60,\"integer\":true,\"kind\":\"number\",\"max\":600,\"min\":40}},\"retune\":true}"
  InitLog = "sentinel_cover initialized"

const CoverRadiusPx = 331'i32

var
  params: EdgeRideParams
  lastCentre: int32 = -1
  posted: bool
  postX, postY: int32
  havePost: bool

proc play_manifest*() {.exportc, cdecl.} =
  discard emitRaw(ManifestBytes)

const
  Prefix = "{\"arrive_radius\":0.0,\"idle_aim_center_brads\":"
  Suffix = ",\"kind\":\"hold\",\"reason\":\"sentinel_cover:scan\",\"schema\":\"intent\",\"v\":1}"

var scanBuffer: array[160, byte]

proc emitScanHold(centre: int32): int32 =
  ## Canonical intent JSON (keys in byte order) built in a fixed buffer:
  ## the standalone wasm target has no string runtime.
  var n = 0
  for ch in Prefix:
    scanBuffer[n] = byte(ch)
    inc n
  var digits: array[4, byte]
  var count = 0
  var v = centre
  if v == 0:
    digits[0] = byte('0')
    count = 1
  while v > 0:
    digits[count] = byte(ord('0') + int(v mod 10))
    v = v div 10
    inc count
  while count > 0:
    dec count
    scanBuffer[n] = digits[count]
    inc n
  for ch in Suffix:
    scanBuffer[n] = byte(ch)
    inc n
  emitRaw(scanBuffer.toOpenArray(0, n - 1))

proc loadParams(dataPtr, dataLen: int32): int32 =
  let decoded = readEdgeRideParams(context(dataPtr, dataLen))
  if not decoded.valid:
    return 1
  params = decoded
  lastCentre = -1
  posted = false
  havePost = false
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
  # Once: find the nearest cover post around the spawn and walk to it;
  # hold and scan from there. If no post resolves, scan in place.
  if not posted and decoded.selfPos.present:
    if not havePost:
      let cover = nearestCover(decoded.selfPos.x, decoded.selfPos.y, CoverRadiusPx)
      if cover.ok:
        postX = cover.x
        postY = cover.y
        havePost = true
        lastCentre = -1
        let code = emitNavigateController(cover, "24.0", "sentinel_cover:post")
        if code < 0: return code
        resetArena()
        return 0
      posted = true
    else:
      let dx = int64(decoded.selfPos.x - postX)
      let dy = int64(decoded.selfPos.y - postY)
      if dx * dx + dy * dy <= int64(params.margin) * int64(params.margin):
        posted = true
      else:
        resetArena()
        return 0
  let period = if params.enterLead <= 0: 48'i32 else: params.enterLead
  let tick = if decoded.tickPresent: decoded.tick else: 0'i32
  let centre = ((tick div period) mod 4) * 64
  if centre == lastCentre:
    resetArena()
    return 0
  let code = emitScanHold(centre)
  if code < 0:
    return code
  lastCentre = centre
  resetArena()
  0

proc play_retune*(oldPtr, oldLen, newPtr, newLen: int32): int32 {.
    exportc, cdecl.} =
  discard oldPtr
  discard oldLen
  resetArena()
  loadParams(newPtr, newLen)
