## Probe forward waypoint skip and stuck-skip vs Daveey NAV vel.
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

proc sha256Hex(data: string): string =
  toHex(sha256(data))

proc velOf(row: array[6, int] | array[6, uint8]): (int, int) =
  ((int(row[0]) - 3) div 3, (int(row[1]) - 3) div 3)

proc isNav(policy: GorynychPolicy, view: HeroView, state: HeroState): bool =
  if state.mode == RetreatMode:
    return false
  let (towerIdx, towerDistance) = policy.nearestLiveEnemyTower(view)
  not (towerIdx >= 0 and towerDistance <= siegeStandoff)

proc ancientGoal(view: HeroView): (int, int) =
  let ancient = towers[ancientIndex[1 - view.team]]
  (int(ancient.y), int(ancient.x))

proc forwardGoal(view: HeroView, state: HeroState): (int, int) =
  ## Nearest remaining waypoint at or after the current index.
  let lanePoints = view.lane()
  var start = state.waypointIndex
  if start < 0:
    start = nearestWaypoint(view, lanePoints)
  var
    best = -1
    bestD = 0.0
  for i in start ..< lanePoints.len:
    let (wy, wx) = lanePoints[i]
    let d = max(abs(wy - float(view.y)), abs(wx - float(view.x)))
    if d <= waypointReached:
      continue
    if best < 0 or d < bestD:
      best = i
      bestD = d
  if best < 0:
    return ancientGoal(view)
  (int(lanePoints[best][0]), int(lanePoints[best][1]))

proc nextGoal(view: HeroView, state: HeroState): (int, int) =
  ## Skip the current waypoint and take the following one.
  let lanePoints = view.lane()
  var idx = state.waypointIndex + 1
  if state.waypointIndex < 0:
    idx = nearestWaypoint(view, lanePoints) + 1
  while idx < lanePoints.len:
    let (wy, wx) = lanePoints[idx]
    if max(abs(wy - float(view.y)), abs(wx - float(view.x))) > waypointReached:
      return (int(wy), int(wx))
    inc idx
  ancientGoal(view)

type Row = object
  nav, match: int
  fwdHit, fwdChange: int
  skipHit, skipChange: int
  ## Among baseline detour ticks.
  detourTicks, detourMatch, skipOnDetourHit, fwdOnDetourHit: int

proc probe(path, focalName: string) =
  echo "Probe2 ", extractFilename(path)
  let
    replay = parseReplay(readFile(path))
    wasm = readFile(WasmPath)
  doAssert sha256Hex(wasm) == ExpectedWasmSha
  var team = -1
  for i, name in replay.playerNames():
    if name.toLowerAscii.contains(focalName.toLowerAscii):
      team = i
  var runtime = newRuntime(wasm, int64(replay.seedOf()))
  defer: runtime.close()
  var policy = newGorynychPolicy()
  var rows: array[5, Row]
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
      if not policy.isNav(view, state):
        continue
      var r = rows[i]
      inc r.nav
      if iv == av:
        inc r.match
      let
        fg = forwardGoal(view, state)
        ng = nextGoal(view, state)
      var fs = policy.nav.stepToward(view.y, view.x, fg)
      var ns = policy.nav.stepToward(view.y, view.x, ng)
      # Re-apply active detour so the candidate is a goal change, not a
      # detour deletion.
      if state.detourLeft > 0:
        fs = rotate90(fs[0], fs[1], state.detourSide)
        ns = rotate90(ns[0], ns[1], state.detourSide)
      if fs != iv:
        inc r.fwdChange
      if fs == av:
        inc r.fwdHit
      if ns != iv:
        inc r.skipChange
      if ns == av:
        inc r.skipHit
      if state.detourLeft > 0:
        inc r.detourTicks
        if iv == av:
          inc r.detourMatch
        if ns == av:
          inc r.skipOnDetourHit
        if fs == av:
          inc r.fwdOnDetourHit
      rows[i] = r
    var actions: array[NumHeroes, array[6, uint8]]
    for pid in 0 ..< NumHeroes:
      actions[pid] = replay.rowAt(tick, pid)
    runtime.writeActions(actions)
    runtime.step()
  for i in 0 .. 4:
    let r = rows[i]
    echo "  ", RoleNames[i], " nav=", r.nav, " baseMatch=", r.match
    echo "    forwardNearest hit=", r.fwdHit, " changes=", r.fwdChange
    echo "    skipCurrent hit=", r.skipHit, " changes=", r.skipChange
    echo "    detourTicks=", r.detourTicks, " detourMatch=", r.detourMatch,
      " skipOnDetour=", r.skipOnDetourHit, " fwdOnDetour=", r.fwdOnDetourHit

proc runProbe2() =
  probe(ResearchDir / "evidence" / "replays" / "r3730-g4.moba", "daveey")
  probe(ResearchDir / "evidence" / "replays" / "r3728-g9.moba", "daveey")

runProbe2()
