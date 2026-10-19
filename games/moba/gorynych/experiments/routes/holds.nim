## LeaderHold breakdown: tower distance, dest occupancy, wave, position.
## scoring_evidence is false.

import
  std/[os, strutils],
  crunchy,
  replays, runtimes

include baseline

const
  RoutesDir = currentSourcePath().parentDir
  ResearchDir = RoutesDir / ".." / ".." / "research"
  WasmPath = ResearchDir / "evidence" / "wasm" / "moba_sim.wasm"
  ExpectedWasmSha = "b76a9c4cdcc7e4a47c973d4029737a832e0b678646c6a512f5653d3e98f1b8c8"
  RoleNames = ["support", "assassin", "burst", "tank", "carry"]
  FriendlyCreep = [radiantCreepTile, direCreepTile]

proc sha256Hex(data: string): string =
  toHex(sha256(data))

proc velOf(row: array[6, int] | array[6, uint8]): (int, int) =
  ((int(row[0]) - 3) div 3, (int(row[1]) - 3) div 3)

proc tickKind(policy: GorynychPolicy, view: HeroView, state: HeroState): int =
  if state.mode == RetreatMode:
    return 0
  let (towerIdx, towerDistance) = policy.nearestLiveEnemyTower(view)
  if towerIdx >= 0 and towerDistance <= siegeStandoff:
    return 1
  2

proc friendlyAhead(view: HeroView, goal: (int, int)): bool =
  let
    gy = goal[0]
    gx = goal[1]
    heroD = max(abs(view.y - gy), abs(view.x - gx))
    want = FriendlyCreep[view.team]
  for dy in -visionRange .. visionRange:
    for dx in -visionRange .. visionRange:
      if view.tile(dy, dx) != want:
        continue
      let d = max(abs(view.y + dy - gy), abs(view.x + dx - gx))
      if d < heroD:
        return true
  false

type RoleHold = object
  nav, match, leaderHold: int
  holdOcc, holdEmpty: int
  holdAhead, holdNoWave: int
  holdEnemyHero: int
  towerDist: array[16, int]  ## 0..14, 15=15+
  wpDist: array[16, int]
  firstHolds: seq[string]

proc bucket(d: int): int =
  if d < 0: 15
  elif d > 14: 15
  else: d

proc analyze(path, focalName: string) =
  echo "Holds ", extractFilename(path)
  let
    replay = parseReplay(readFile(path))
    wasm = readFile(WasmPath)
  doAssert sha256Hex(wasm) == ExpectedWasmSha
  let names = replay.playerNames()
  var team = -1
  for i, name in names:
    if name.toLowerAscii.contains(focalName.toLowerAscii):
      team = i
  var runtime = newRuntime(wasm, int64(replay.seedOf()))
  defer: runtime.close()
  var policy = newGorynychPolicy()
  var roles: array[5, RoleHold]
  for tick in 0 ..< replay.tickCount:
    let obs = runtime.observations()
    for i in 0 .. 4:
      let
        pid = team * 5 + i
        view = parseView(obs[pid])
        intended = policy.heroAction(i, obs[pid])
        state = policy.heroes[i]
        iv = velOf(intended)
        av = velOf(replay.rowAt(tick, pid))
        kind = policy.tickKind(view, state)
      if kind != 2:
        continue
      var r = roles[i]
      inc r.nav
      if iv == av:
        inc r.match
      if av == (0, 0) and iv != (0, 0):
        inc r.leaderHold
        let occ = view.tile(iv[0], iv[1])
        if occ > 0: inc r.holdOcc else: inc r.holdEmpty
        let wpGoal =
          if state.waypointIndex >= 0 and
              state.waypointIndex < view.lane().len:
            (int(view.lane()[state.waypointIndex][0]),
             int(view.lane()[state.waypointIndex][1]))
          else:
            let ancient = towers[ancientIndex[1 - view.team]]
            (int(ancient.y), int(ancient.x))
        if friendlyAhead(view, wpGoal):
          inc r.holdAhead
        else:
          inc r.holdNoWave
        let (hD, _, _) = cropScan(view)
        if hD >= 0:
          inc r.holdEnemyHero
        let (_, td) = policy.nearestLiveEnemyTower(view)
        inc r.towerDist[bucket(td)]
        let wd = max(abs(wpGoal[0] - view.y), abs(wpGoal[1] - view.x))
        inc r.wpDist[bucket(wd)]
        if r.firstHolds.len < 6:
          r.firstHolds.add(
            "t" & $tick & " (" & $view.y & "," & $view.x & ") wp=" &
            $state.waypointIndex & " td=" & $td & " wd=" & $wd &
            " dest=" & $occ & " hp=" & $view.health10 &
            " base=" & $iv)
      roles[i] = r
    var actions: array[NumHeroes, array[6, uint8]]
    for pid in 0 ..< NumHeroes:
      actions[pid] = replay.rowAt(tick, pid)
    runtime.writeActions(actions)
    runtime.step()
  for i in 0 .. 4:
    let r = roles[i]
    echo "  ", RoleNames[i], " nav=", r.nav, " match=", r.match,
      " leaderHold=", r.leaderHold
    echo "    hold destOcc=", r.holdOcc, " destEmpty=", r.holdEmpty,
      " noWave=", r.holdNoWave, " waveAhead=", r.holdAhead,
      " enemyHero=", r.holdEnemyHero
    var ts = "    towerDist "
    for d in 0 .. 15:
      if r.towerDist[d] > 0:
        ts.add($d & "=" & $r.towerDist[d] & " ")
    echo ts
    var ws = "    wpDist "
    for d in 0 .. 15:
      if r.wpDist[d] > 0:
        ws.add($d & "=" & $r.wpDist[d] & " ")
    echo ws
    for s in r.firstHolds:
      echo "      ", s

proc runHolds() =
  analyze(ResearchDir / "evidence" / "replays" / "r3730-g4.moba", "daveey")
  analyze(ResearchDir / "evidence" / "replays" / "r3728-g9.moba", "daveey")
  analyze("/Users/me/p/andre_von_auto/games/moba/gorynych/evidence/xreq_798c5043-ed36-4776-8f80-158019ec0d90/ereq_82528dd3-f68f-4ba7-b27a-c3a9abf4a9a6.replay", "Andre")

runHolds()
