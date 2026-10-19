## Agreement extractor: replays a recorded hosted episode through the pinned
## sim wasm to recover every agent's true observations, then runs the pure
## Nim MMONet (../../mmonet.nim) on each seat's observation stream and
## measures how well the recorded actions fit the network's distribution.
## Seats driven by the upstream network (PufferLib's nmmo-baseline, the
## consensus bots) should fit far better than scripted seats. This is
## isolation evidence that the port sees hosted observations the way the
## league network does; it is never a score.
##
## Build (from this directory):
##   WASMTIME_C_API=$PWD/deps/wasmtime-v48.0.1-aarch64-macos-c-api \
##     nim c -d:release --passC:-ffp-contract=off agreement.nim
## Run:
##   ./agreement nmmo3_sim.wasm ../hosted/<ereq>.replay <weights.bin>

import
  std/[json, math, os, strutils],
  runtimes,
  ../replays,
  ../../mmonet

const ObsSize = 1707

type SeatFit = object
  name: string
  ticks: int
  agree: int
  probSum: float64
  logProbSum: float64
  resets: int
  noops: int

proc seatName(header: JsonNode, replay: Replay, pid: int): string =
  let players = header{"config"}{"players"}
  let seat = pid div max(replay.heroesPerSeat, 1)
  if players.isNil or seat >= players.len:
    return "seat" & $seat
  players[seat]{"name"}.getStr("seat" & $seat)

proc main() =
  if paramCount() != 3:
    quit("usage: agreement <sim.wasm> <hosted.replay> <weights.bin>", 1)
  let
    replay = loadReplay(paramStr(2))
    header = replay.header
    seed = uint32(header["config"]["seed"].getBiggestInt() and 0xFFFFFFFF)
    n = replay.numAgents
    weights = loadWeights(paramStr(3))
    wasmBytes = readFile(paramStr(1))
  var runtime = newRuntime(wasmBytes, seed, n)
  defer:
    close(runtime)
  var
    brains: seq[Brain]
    fits = newSeq[SeatFit](n)
    pendingReset = newSeq[bool](n)
    acts = newSeq[int](n)
    bytes = newSeq[uint8](ObsSize)
  for pid in 0 ..< n:
    brains.add(newBrain(weights, uint64(pid) + 1))
    fits[pid].name = seatName(header, replay, pid)
  for tick in 0 ..< replay.tickCount:
    let obsPtr = int(uint32(callI32(runtime, "obs_ptr")))
    let obs = readBytes(runtime, obsPtr, n * ObsSize)
    for pid in 0 ..< n:
      if pendingReset[pid]:
        brains[pid].reset()
        inc fits[pid].resets
        pendingReset[pid] = false
      for i in 0 ..< ObsSize:
        bytes[i] = uint8(obs[pid * ObsSize + i])
      brains[pid].forward(bytes)
      let recorded = action(replay, tick, pid)
      acts[pid] = recorded
      var best = brains[pid].logits[0]
      for i in 1 ..< NumActions:
        best = max(best, brains[pid].logits[i])
      var total = 0.0
      for i in 0 ..< NumActions:
        total += exp(float64(brains[pid].logits[i] - best))
      let probability =
        exp(float64(brains[pid].logits[recorded] - best)) / total
      fits[pid].probSum += probability
      fits[pid].logProbSum += ln(max(probability, 1e-12))
      inc fits[pid].ticks
      if brains[pid].argmax() == recorded:
        inc fits[pid].agree
      if recorded == 4:
        inc fits[pid].noops
    writeActions(runtime, acts)
    callVoid(runtime, "nmmo_step")
    let termPtr = int(uint32(callI32(runtime, "term_ptr")))
    let raw = readBytes(runtime, termPtr, n * 4)
    for pid in 0 ..< n:
      # float32 1.0 is 00 00 80 3f little-endian
      if uint8(raw[pid * 4 + 3]) == 0x3f'u8 and
          uint8(raw[pid * 4 + 2]) == 0x80'u8:
        pendingReset[pid] = true
  let digest = cast[uint32](callI32(runtime, "state_digest"))
  echo "state_digest reconstructed ", digest, " hosted ",
    header["result"]["state_digest"].getBiggestInt()
  echo "seat  name            ticks  argmax  meanP  meanLogP  resets  noops"
  for pid in 0 ..< n:
    let f = fits[pid]
    echo pid, "  ", f.name.alignLeft(16), f.ticks, "  ",
      formatFloat(f.agree / max(f.ticks, 1), ffDecimal, 3), "  ",
      formatFloat(f.probSum / max(f.ticks, 1).float64, ffDecimal, 3), "  ",
      formatFloat(f.logProbSum / max(f.ticks, 1).float64, ffDecimal, 3),
      "  ", f.resets, "  ", f.noops

main()
