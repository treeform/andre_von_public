## Strategy-activation proof for hosted replays of the ancient-snipe
## policy: replay through the pinned wasm and, for the Andre von Auto
## seat, report per hero the first tick on a tower-blind snipe cell, the
## ticks spent there, ticks inside enemy tower squares, deaths, and the
## tick the enemy ancient fell. Activation evidence only, never a score.
## Usage: snipeproof <replay> [wasm]

import
  std/[os, strutils],
  replays, runtimes, ../brain
from observations import towerCell, chebyshev

proc main() =
  if paramCount() < 1:
    quit("Usage: snipeproof <replay.moba|.replay> [wasm]", 1)
  let replay = parseReplay(readFile(paramStr(1)))
  let wasmPath =
    if paramCount() >= 2: paramStr(2)
    else: currentSourcePath().parentDir / "evidence" / "wasm" / "moba_sim.wasm"
  let names = replay.playerNames()
  var ourSeat = -1
  for i, n in names:
    if n.contains("Andre"): ourSeat = i
  echo "players ", names, " ourSeat=", ourSeat, " ticks=", replay.tickCount
  var runtime = newRuntime(readFile(wasmPath), int64(replay.seedOf()))
  defer: runtime.close()
  var
    firstNest: array[10, int]
    nestTicks: array[10, int]
    squareTicks: array[10, int]
    deaths: array[10, int]
    lastPos: array[10, (int, int)]
    lastCrop: array[10, string]
    creepSeen: array[10, int]
    creepShot: array[10, int]
    ancientFall = -1
    ourTeam = ourSeat
  for i in 0 ..< 10: firstNest[i] = -1
  for tick in 0 ..< replay.tickCount:
    let obs = runtime.observations()
    if tick mod 100 == 0 and getEnv("TRACE") != "":
      var line = "trace tick " & $tick
      for pid in 0 ..< 10:
        let v = parseView(obs[pid])
        if (pid < 5) == (ourSeat == 0):
          line.add " " & $pid & ":(" & $v.y & "," & $v.x & ")h" & $v.health10
      echo line
    for pid in 0 ..< 10:
      let v = parseView(obs[pid])
      if not v.valid: continue
      let team = if pid < 5: 0 else: 1
      let enemyAncient = towerCell(if team == 0: 22 else: 23)
      let inNest = chebyshev(v.y, v.x, enemyAncient[0], enemyAncient[1]) <= 5 and
        not coveredByEnemyTower(v.y, v.x, team)
      if inNest:
        inc nestTicks[pid]
        if firstNest[pid] < 0: firstNest[pid] = tick
      if coveredByEnemyTower(v.y, v.x, team): inc squareTicks[pid]
      if tick > 0 and chebyshev(v.y, v.x, lastPos[pid][0], lastPos[pid][1]) > 4:
        inc deaths[pid]
        if (pid < 5) == (ourSeat == 0):
          echo "  death pid ", pid, " tick ", tick, " at ", lastPos[pid],
            (if coveredByEnemyTower(lastPos[pid][0], lastPos[pid][1], team): " (tower square)" else: ""),
            " crop: ", lastCrop[pid]
      lastPos[pid] = (v.y, v.x)
      block:
        var heroes = 0
        var creeps = 0
        var neutrals = 0
        let enemyCreep = if team == 0: 4 else: 3
        for i in 0 ..< 121:
          let t = int(obs[pid][i].uint8)
          if (team == 0 and t in 11 .. 15) or (team == 1 and t in 6 .. 10): inc heroes
          elif t == enemyCreep: inc creeps
          elif t == 5: inc neutrals
        lastCrop[pid] = "enemyHeroes=" & $heroes & " enemyCreeps=" & $creeps & " neutrals=" & $neutrals & " hp10=" & $v.health10
    var actions: array[10, array[6, uint8]]
    for pid in 0 ..< 10:
      actions[pid] = replay.rowAt(tick, pid)
      if lastCrop[pid].contains("enemyCreeps=") and not lastCrop[pid].contains("enemyCreeps=0 "):
        inc creepSeen[pid]
        if actions[pid][2] == 0: inc creepShot[pid]
    runtime.writeActions(actions)
    runtime.step()
    if ancientFall < 0 and ourTeam >= 0 and
        runtime.ancientHealth(1 - ourTeam) <= 0.0:
      ancientFall = tick
  echo "end winner=", runtime.winner(), " ancients radiant=",
    runtime.ancientHealth(0), " dire=", runtime.ancientHealth(1),
    " enemyAncientFellAt=", ancientFall
  for pid in 0 ..< 10:
    let seat = if pid < 5: 0 else: 1
    echo (if seat == ourSeat: "OURS " else: "them "), "pid ", pid,
      " firstNest=", firstNest[pid], " nestTicks=", nestTicks[pid],
      " squareTicks=", squareTicks[pid], " deaths=", deaths[pid],
      " level=", runtime.agentStat(pid, 0),
      " damageDealt=", runtime.agentStat(pid, 7),
      " damageReceived=", runtime.agentStat(pid, 8),
      " creepSeenTicks=", creepSeen[pid], " filter0=", creepShot[pid]

main()
