## Local mechanics harness: drive the pinned sim wasm with the brain on
## one side (or both) and report when an ancient falls and how much
## tower damage the snipers took. Isolation evidence only, never a
## score: hosted experience requests decide.
## Usage: snipetest <wasm> <seed> <brainTeam: 0|1|2(both)> [maxTicks]

import
  std/[os, strutils],
  runtimes, ../brain

const
  StatNames = ["level", "kills", "deaths", "towers_killed", "creeps_killed",
               "neutrals_killed", "xp", "damage_dealt", "damage_received",
               "healing_dealt", "healing_received"]

proc main() =
  if paramCount() < 3:
    quit("Usage: snipetest <wasm> <seed> <brainTeam 0|1|2> [maxTicks]", 1)
  let
    wasm = readFile(paramStr(1))
    seed = parseInt(paramStr(2))
    brainTeam = parseInt(paramStr(3))
    maxTicks = if paramCount() >= 4: parseInt(paramStr(4)) else: 3000
  var runtime = newRuntime(wasm, int64(seed))
  defer: runtime.close()
  var brains = [newBrain(), newBrain()]
  var tick = 0
  var arrived: array[10, int]
  var squareTicks: array[10, int]
  var deaths: seq[string]
  var lastHealth: array[10, int]
  var lastPos: array[10, (int, int)]
  for i in 0 ..< 10: arrived[i] = -1
  while tick < maxTicks and runtime.done() == 0:
    let obs = runtime.observations()
    var actions: array[10, array[6, uint8]]
    for pid in 0 ..< 10:
      actions[pid] = [3'u8, 3, 0, 0, 0, 0]
    for team in 0 .. 1:
      if brainTeam != 2 and brainTeam != team:
        continue
      let rows = obs[team * 5 ..< team * 5 + 5]
      let acts = brains[team].act(tick, rows)
      for i, a in acts:
        for c in 0 ..< 6:
          actions[team * 5 + i][c] = uint8(a[c])
    if tick mod 50 == 0:
      var line = "tick " & align($tick, 5)
      for pid in 0 ..< 10:
        let v = parseView(obs[pid])
        line.add " " & $pid & ":(" & $v.y & "," & $v.x & ")h" & $v.health10
      echo line
    for pid in 0 ..< 10:
      let v = parseView(obs[pid])
      if coveredByEnemyTower(v.y, v.x, v.team): inc squareTicks[pid]
      if tick > 0 and max(abs(v.y - lastPos[pid][0]), abs(v.x - lastPos[pid][1])) > 4:
        deaths.add("pid " & $pid & " respawned at tick " & $tick & " from " & $lastPos[pid] & " h" & $lastHealth[pid])
      lastHealth[pid] = v.health10
      lastPos[pid] = (v.y, v.x)
      if arrived[pid] < 0 and actions[pid][0] == 3 and actions[pid][1] == 3 and
          actions[pid][2] == 2 and tick > 20:
        arrived[pid] = tick
    runtime.writeActions(actions)
    runtime.step()
    inc tick
    if runtime.fault() != 0:
      quit("sim fault at tick " & $tick, 1)
  echo "ended tick=", tick, " done=", runtime.done(), " winner=", runtime.winner(),
    " ancients radiant=", runtime.ancientHealth(0), " dire=", runtime.ancientHealth(1)
  for d in deaths: echo d
  for pid in 0 ..< 10:
    var line = "pid " & $pid & " arrived=" & $arrived[pid] & " squareTicks=" & $squareTicks[pid]
    for which, name in StatNames:
      line.add " " & name & "=" & $runtime.agentStat(pid, which)
    echo line

main()
