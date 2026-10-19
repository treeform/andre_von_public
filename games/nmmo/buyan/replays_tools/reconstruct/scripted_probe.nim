## Scripted-engine probe: feeds the truthful (clean) observations recovered
## from a hosted replay to the scripted engine for the selected seats and
## prints what it would do, tick by tick in aggregate, next to what the
## recorded seat did. The sim still follows the recorded actions, so this
## is an off-policy sanity check of the rules (loops, dead branches, action
## mix), never a score.
##
## Build (from this directory):
##   WASMTIME_C_API=$PWD/deps/wasmtime-v48.0.1-aarch64-macos-c-api \
##     nim c -d:release scripted_probe.nim
## Run:
##   ./scripted_probe nmmo3_sim.wasm <hosted.replay> [player-prefix]

import
  std/[json, os, strutils, tables],
  runtimes,
  ../replays,
  ../../scripted

const
  ObsSize = 1707
  Names = ["down", "up", "right", "left", "noop", "attack", "6", "ui",
    "k1", "k2", "k3", "k4", "k5", "k6", "k7", "k8", "k9", "k0", "minus",
    "equals", "buy", "sell", "rdown", "rup", "rright", "rleft"]

proc seatName(header: JsonNode, replay: Replay, pid: int): string =
  let players = header{"config"}{"players"}
  let seat = pid div max(replay.heroesPerSeat, 1)
  if players.isNil or seat >= players.len:
    return "seat" & $seat
  players[seat]{"name"}.getStr("seat" & $seat)

proc main() =
  if paramCount() < 2:
    quit("usage: scripted_probe <sim.wasm> <hosted.replay> [prefix]", 1)
  let prefix = if paramCount() >= 3: paramStr(3) else: "Andre"
  let
    replay = loadReplay(paramStr(2))
    header = replay.header
    seed = uint32(header["config"]["seed"].getBiggestInt() and 0xFFFFFFFF)
    n = replay.numAgents
    wasmBytes = readFile(paramStr(1))
  var runtime = newRuntime(wasmBytes, seed, n)
  defer:
    close(runtime)
  var selected: seq[int]
  for pid in 0 ..< n:
    if seatName(header, replay, pid).startsWith(prefix):
      selected.add(pid)
    callVoid(runtime, "nmmo_set_obs_clean", [int32(pid), 1'i32])
  var minds = newSeq[Mind](n)
  for pid in 0 ..< n:
    minds[pid] = newMind(7, pid)
  var pending = newSeq[bool](n)
  var acts = newSeq[int](n)
  var bytes = newSeq[uint8](ObsSize)
  var scriptedCounts, recordedCounts: CountTable[string]
  var agree = 0
  var total = 0
  for tick in 0 ..< replay.tickCount:
    let obsPtr = int(uint32(callI32(runtime, "obs_ptr")))
    let obs = readBytes(runtime, obsPtr, n * ObsSize)
    for pid in 0 ..< n:
      acts[pid] = action(replay, tick, pid)
    for pid in selected:
      if pending[pid]:
        minds[pid].reset()
        pending[pid] = false
      for i in 0 ..< ObsSize:
        bytes[i] = uint8(obs[pid * ObsSize + i])
      let mine = minds[pid].decide(bytes, tick)
      scriptedCounts.inc(Names[mine])
      recordedCounts.inc(Names[acts[pid]])
      if mine == acts[pid]:
        inc agree
      inc total
    writeActions(runtime, acts)
    callVoid(runtime, "nmmo_step")
    let termPtr = int(uint32(callI32(runtime, "term_ptr")))
    let raw = readBytes(runtime, termPtr, n * 4)
    for pid in 0 ..< n:
      if uint8(raw[pid * 4 + 3]) == 0x3f'u8 and
          uint8(raw[pid * 4 + 2]) == 0x80'u8:
        pending[pid] = true
  echo "decisions ", total, " exact agreement ",
    formatFloat(agree / max(total, 1), ffDecimal, 3)
  echo "action          scripted  recorded"
  for name in Names:
    let s = scriptedCounts.getOrDefault(name)
    let r = recordedCounts.getOrDefault(name)
    if s == 0 and r == 0:
      continue
    echo name.alignLeft(14), ($s).align(9), ($r).align(10)
  for pid in selected:
    let m = minds[pid]
    echo "pid ", pid, " fights ", m.fights, " flees ", m.flees, " hunts ",
      m.hunts, " harvests ", m.harvests, " buys ", m.buys, " sells ",
      m.sells, " heals ", m.heals, " equips ", m.equips

main()
