## Run the brain in lockstep with a hosted replay for the Andre von Auto
## seat: verify the brain reproduces every recorded action (proves the
## hosted binary is this source) and explain any hero that stands still
## for 60+ ticks. Research tooling, never a score.
## Usage: stalls <replay> [wasm]

import
  std/[os, strutils],
  replays, runtimes, ../brain

proc main() =
  let replay = parseReplay(readFile(paramStr(1)))
  let wasmPath =
    if paramCount() >= 2: paramStr(2)
    else: currentSourcePath().parentDir / "evidence" / "wasm" / "moba_sim.wasm"
  let names = replay.playerNames()
  var ourSeat = -1
  for i, n in names:
    if n.contains("Andre"): ourSeat = i
  doAssert ourSeat >= 0
  var runtime = newRuntime(readFile(wasmPath), int64(replay.seedOf()))
  defer: runtime.close()
  let brain = newBrain()
  var mismatches = 0
  var still: array[5, int]
  var lastPos: array[5, (int, int)]
  var reported: array[5, int]
  for tick in 0 ..< replay.tickCount:
    let obs = runtime.observations()
    let rows = obs[ourSeat * 5 ..< ourSeat * 5 + 5]
    let ours = brain.act(tick, rows)
    var actions: array[10, array[6, uint8]]
    for pid in 0 ..< 10:
      actions[pid] = replay.rowAt(tick, pid)
    for i in 0 ..< 5:
      let pid = ourSeat * 5 + i
      var same = true
      for c in 0 ..< 6:
        if int(actions[pid][c]) != ours[i][c]: same = false
      if not same:
        inc mismatches
        if mismatches <= 5:
          echo "mismatch tick ", tick, " hero ", i, " recorded ", actions[pid], " brain ", ours[i]
      let v = parseView(rows[i])
      if (v.y, v.x) == lastPos[i]: inc still[i] else: still[i] = 0
      lastPos[i] = (v.y, v.x)
      if still[i] >= 60 and tick - reported[i] >= 200:
        reported[i] = tick
        echo "STALL tick ", tick, " hero ", i, " role ", v.heroType, " ",
          brain.explain(tick, i, v)
    runtime.writeActions(actions)
    runtime.step()
  echo "ticks ", replay.tickCount, " mismatches ", mismatches
main()
