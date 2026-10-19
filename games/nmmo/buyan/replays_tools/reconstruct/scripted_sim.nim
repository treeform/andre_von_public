## Closed-loop smoke test of the scripted engine in the pinned sim wasm:
## every seat is driven by scripted.nim on clean observations for a number
## of ticks, then per-agent behaviour counters, lives and repeated-action
## streaks are printed. This exists to catch loops and dead branches
## before spending hosted episodes. It prints no score and must never be
## used as one; hosted XP is the only judge.
##
## Build (from this directory):
##   WASMTIME_C_API=$PWD/deps/wasmtime-v48.0.1-aarch64-macos-c-api \
##     nim c -d:release scripted_sim.nim
## Run:
##   ./scripted_sim nmmo3_sim.wasm <seed> <ticks>

import
  std/[os, strutils, tables],
  runtimes,
  ../../scripted, ../../mmonet

const
  ObsSize = 1707
var Agents = 8   ## seats in the world; optional fifth argument (solo benchmark: 1)
const
  Names = ["down", "up", "right", "left", "noop", "attack", "6", "ui",
    "k1", "k2", "k3", "k4", "k5", "k6", "k7", "k8", "k9", "k0", "minus",
    "equals", "buy", "sell", "rdown", "rup", "rright", "rleft"]

proc main() =
  if paramCount() < 3:
    quit("usage: scripted_sim <sim.wasm> <seed> <ticks>", 1)
  let
    seed = uint32(parseInt(paramStr(2)))
    ticks = parseInt(paramStr(3))
    engine = (if paramCount() >= 4: paramStr(4) else: "scripted")
    wasmBytes = readFile(paramStr(1))
  if paramCount() >= 5: Agents = parseInt(paramStr(5))
  var runtime = newRuntime(wasmBytes, seed, Agents)
  defer:
    close(runtime)
  var minds = newSeq[Mind](Agents)
  var brains: seq[Brain]
  var cleanNet = false
  if engine == "mmonet":
    ## MMONET_WEIGHTS picks the file; the PufferLib 5.0 net wants clean obs.
    let weights = loadWeights(getEnv("MMONET_WEIGHTS",
      "/Users/me/p/andre_von_auto/sims/nmmo/vendor/upstream/resources/nmmo3/nmmo3_weights.bin"))
    cleanNet = weights.cleanObservations
    for pid in 0 ..< Agents:
      brains.add(newBrain(weights, uint64(pid) + 3))
  for pid in 0 ..< Agents:
    if engine != "mmonet" or cleanNet:
      callVoid(runtime, "nmmo_set_obs_clean", [int32(pid), 1'i32])
    minds[pid] = newMind(uint32(seed).uint64, pid)
  var
    pending = newSeq[bool](Agents)
    acts = newSeq[int](Agents)
    bytes = newSeq[uint8](ObsSize)
    counts: CountTable[string]
    lives = newSeq[int](Agents)
    lastAct = newSeq[int](Agents)
    streak = newSeq[int](Agents)
    longestStreak = newSeq[int](Agents)
    uiTicks = 0
    deaths = 0
    totalDeaths = 0
    oneShot = 0
    lostFight = 0
    maxComb = 0
    maxProf = 0
    history = newSeq[seq[int]](Agents)
    branches = newSeq[seq[string]](Agents)
    branchCounts: CountTable[string]
    adjacentPeer = 0
    adjacentPeerAttack = 0
    levelUps = 0
    lastComb = newSeq[int](Agents)
    bankedMin = newSeq[int](Agents)
    lastMin = newSeq[int](Agents)
  for pid in 0 ..< Agents:
    lives[pid] = 1
    lastAct[pid] = -1
  for tick in 0 ..< ticks:
    let obsPtr = int(uint32(callI32(runtime, "obs_ptr")))
    let obs = readBytes(runtime, obsPtr, Agents * ObsSize)
    for pid in 0 ..< Agents:
      if pending[pid]:
        minds[pid].reset()
        if engine == "mmonet": brains[pid].reset()
        pending[pid] = false
        inc lives[pid]
      for i in 0 ..< ObsSize:
        bytes[i] = uint8(obs[pid * ObsSize + i])
      if bytes[1650 + 8] != 0'u8:
        inc uiTicks
      maxComb = max(maxComb, int(bytes[1650 + 1]))
      block:
        var adj0 = false
        for r in 4 .. 6:
          for c in 6 .. 8:
            let t = (r * 15 + c) * 10
            if (r != 5 or c != 7) and bytes[t + 4] == 2'u8 and bytes[t + 8] != 5'u8 and bytes[t + 6] == 0'u8: adj0 = true
        if adj0:
          inc adjacentPeer
        if int(bytes[1650 + 1]) > lastComb[pid]: inc levelUps
        lastComb[pid] = int(bytes[1650 + 1])
        lastMin[pid] = min(int(bytes[1650 + 1]), int(bytes[1650 + 7]))
      maxProf = max(maxProf, int(bytes[1650 + 7]))
      var a: int
      if engine == "mmonet":
        brains[pid].forward(bytes)
        a = brains[pid].argmax()
      else:
        a = minds[pid].decide(bytes, tick)
      acts[pid] = a
      block:
        var adj0 = false
        for r in 4 .. 6:
          for c in 6 .. 8:
            let t = (r * 15 + c) * 10
            if (r != 5 or c != 7) and bytes[t + 4] == 2'u8 and bytes[t + 8] != 5'u8 and bytes[t + 6] == 0'u8: adj0 = true
        if adj0 and a == 5: inc adjacentPeerAttack
      history[pid].add(a)
      if engine != "mmonet":
        branches[pid].add(minds[pid].branch)
        branchCounts.inc(minds[pid].branch)
        if branches[pid].len > 10: branches[pid].delete(0)
      if history[pid].len > 10: history[pid].delete(0)
      counts.inc(Names[a])
      if a == lastAct[pid]:
        inc streak[pid]
        longestStreak[pid] = max(longestStreak[pid], streak[pid])
      else:
        streak[pid] = 1
      lastAct[pid] = a
    if (tick + 1) mod 500 == 0:
      var combSum, profSum, minSum = 0
      var held: CountTable[string]
      for pid in 0 ..< Agents:
        let b = pid * ObsSize + 1650
        let cb = int(uint8(obs[b + 1]))
        let pf = int(uint8(obs[b + 7]))
        combSum += cb
        profSum += pf
        minSum += min(cb, pf)
        let h = int(uint8(obs[b + 16]))
        held.inc((if h == 0: "none" else: "k" & $(h mod 17) & "t" & $(h div 17 + 1)))
      var atkSum, defSum = 0
      for pid in 0 ..< Agents:
        atkSum += int(uint8(obs[pid * ObsSize + 1650 + 45]))
        defSum += int(uint8(obs[pid * ObsSize + 1650 + 46]))
      var livesSum = 0
      for pid in 0 ..< Agents: livesSum += lives[pid]
      echo "progress tick ", tick + 1, " mean comb ", formatFloat(combSum / Agents, ffDecimal, 1), " prof ", formatFloat(profSum / Agents, ffDecimal, 1), " min ", formatFloat(minSum / Agents, ffDecimal, 1), " lives ", livesSum, " atk ", formatFloat(atkSum / Agents, ffDecimal, 1), " def ", formatFloat(defSum / Agents, ffDecimal, 1), " held ", held
    writeActions(runtime, acts)
    callVoid(runtime, "nmmo_step")
    let termPtr = int(uint32(callI32(runtime, "term_ptr")))
    let raw = readBytes(runtime, termPtr, Agents * 4)
    for pid in 0 ..< Agents:
      if uint8(raw[pid * 4 + 3]) == 0x3f'u8 and
          uint8(raw[pid * 4 + 2]) == 0x80'u8:
        pending[pid] = true
        inc totalDeaths
        bankedMin[pid] += lastMin[pid]
        block:
          let b = pid * ObsSize
          let hpNow = int(uint8(obs[b + 1650 + 5]))
          if hpNow >= 90: inc oneShot
          if uint8(obs[b + 1650 + 12]) != 0'u8 and hpNow < 40: inc lostFight
        if deaths < 40:
          inc deaths
          let b = pid * ObsSize
          var near = "none"
          for r in 0 ..< 11:
            for c in 0 ..< 15:
              let t = (r * 15 + c) * 10
              if uint8(obs[b + t + 4]) == 2'u8 and uint8(obs[b + t + 8]) != 5'u8:
                let d = max(abs(r - 5), abs(c - 7))
                if near == "none" or d < parseInt(near.split(":")[0]):
                  near = $d & ":" & $int(uint8(obs[b + t + 6])) & ":" &
                    $int(uint8(obs[b + t + 7]))
          if uint8(obs[b + 1650 + 12]) != 0'u8 and int(uint8(obs[b + 1650 + 5])) < 40 and deaths <= 30:
            for r in 0 ..< 11:
              var line = "    "
              for c in 0 ..< 15:
                let t = b + (r * 15 + c) * 10
                if r == 5 and c == 7: line.add("@")
                elif uint8(obs[t + 4]) == 2'u8 and uint8(obs[t + 8]) != 5'u8: line.add($int(uint8(obs[t + 6])))
                elif uint8(obs[t + 4]) == 1'u8: line.add("P")
                elif uint8(obs[t + 1]) > 1'u8: line.add("#")
                elif uint8(obs[t + 2]) != 0'u8: line.add("i")
                else: line.add(".")
              echo line
          var shooters = ""
          for r in 0 ..< 11:
            for c in 0 ..< 15:
              let t = (r * 15 + c) * 10
              if uint8(obs[b + t + 4]) == 2'u8 and uint8(obs[b + t + 8]) != 5'u8 and uint8(obs[b + t + 5]) != 0'u8:
                let d = max(abs(r - 5), abs(c - 7))
                if d <= 6: shooters.add($d & ":e" & $int(uint8(obs[b + t + 5])) & (if r == 5 or c == 7: "L " else: " "))
          echo "death pid ", pid, " tick ", tick, " life ", minds[pid].fights, "f ", minds[pid].flees, "fl hp ", uint8(obs[b + 1650 + 5]), "gem ", int(uint8(obs[b + 1650 + 17])) mod 17, " shooters[", shooters, "] ", " comb ", uint8(obs[b + 1650 + 1]), " prof ", uint8(obs[b + 1650 + 7]), " combat ", uint8(obs[b + 1650 + 12]), " held ", uint8(obs[b + 1650 + 16]), " near(d:delta:hp) ", near, " last ", history[pid], " branches ", branches[pid]
  var scoreSum = 0.0
  for pid in 0 ..< Agents:
    scoreSum += float(bankedMin[pid] + lastMin[pid]) / float(lives[pid])
  var branchLine = ""
  for k, v in branchCounts: branchLine.add(k & " " & $v & "  ")
  echo "branches ", branchLine
  echo "scoreproxy ", formatFloat(scoreSum / float(Agents), ffDecimal, 2), " (mean over agents of mean min per life; harness only, not a score)"
  echo "ticks ", ticks, " agents ", Agents, " ui ticks ", uiTicks, " deaths ", totalDeaths, " oneshot(hp>=90) ", oneShot, " lostfight(combat>0,hp<40) ", lostFight, " maxcomb ", maxComb, " maxprof ", maxProf, " adjacentPeerTicks ", adjacentPeer, " attackedThem ", adjacentPeerAttack, " combLevelUps ", levelUps
  echo "action mix:"
  for name in Names:
    let n = counts.getOrDefault(name)
    if n > 0:
      echo "  ", name.alignLeft(8), ($n).align(8), "  ",
        formatFloat(100.0 * n.float / float(ticks * Agents), ffDecimal, 1), "%"
  for pid in 0 ..< Agents:
    let m = minds[pid]
    echo "pid ", pid, " lives ", lives[pid], " longest streak ",
      longestStreak[pid], " fights ", m.fights, " flees ", m.flees,
      " hunts ", m.hunts, " harvests ", m.harvests, " buys ", m.buys,
      " sells ", m.sells, " heals ", m.heals, " equips ", m.equips

main()
