## Probe one-change navigation hypotheses against Daveey NAV actions.
## Uses reconstructed hosted observations. scoring_evidence is false.

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
  ## 0 retreat, 1 siege, 2 nav.
  if state.mode == RetreatMode:
    return 0
  let (towerIdx, towerDistance) = policy.nearestLiveEnemyTower(view)
  if towerIdx >= 0 and towerDistance <= siegeStandoff:
    return 1
  2

proc ancientGoal(view: HeroView): (int, int) =
  let ancient = towers[ancientIndex[1 - view.team]]
  (int(ancient.y), int(ancient.x))

proc friendlyAhead(view: HeroView, goal: (int, int)): bool =
  ## True when a visible friendly creep is strictly closer to goal.
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

proc destOccupied(view: HeroView, dy, dx: int): bool =
  if dy == 0 and dx == 0:
    return false
  let t = view.tile(dy, dx)
  t > 0

proc skipBehindGoal(
  nav: var NavGrid, view: HeroView, state: HeroState
): (int, int) =
  ## Next waypoint whose ancient-cost is strictly below the hero's.
  let
    lanePoints = view.lane()
    ancient = ancientGoal(view)
    field = nav.costField(ancient)
    here = field[view.y * mapWidth + view.x]
  var idx = state.waypointIndex
  if idx < 0:
    idx = nearestWaypoint(view, lanePoints)
  while idx < lanePoints.len:
    let
      wy = int(lanePoints[idx][0])
      wx = int(lanePoints[idx][1])
      cost = field[wy * mapWidth + wx]
    if max(abs(lanePoints[idx][0] - float(view.y)),
           abs(lanePoints[idx][1] - float(view.x))) > waypointReached and
        (here == unreached or cost < here):
      return (wy, wx)
    inc idx
  ancient

proc nearestEveryGoal(view: HeroView): (int, int) =
  ## Re-anchor to nearest waypoint every tick, then skip reached ones.
  let lanePoints = view.lane()
  var idx = nearestWaypoint(view, lanePoints)
  while idx < lanePoints.len:
    let (wy, wx) = lanePoints[idx]
    if max(abs(wy - float(view.y)), abs(wx - float(view.x))) > waypointReached:
      return (int(wy), int(wx))
    inc idx
  ancientGoal(view)

proc widerReachedGoal(view: HeroView, state: HeroState, radius: float): (int, int) =
  let lanePoints = view.lane()
  var idx = state.waypointIndex
  if idx < 0:
    idx = nearestWaypoint(view, lanePoints)
  while idx < lanePoints.len:
    let (wy, wx) = lanePoints[idx]
    if max(abs(wy - float(view.y)), abs(wx - float(view.x))) > radius:
      return (int(wy), int(wx))
    inc idx
  ancientGoal(view)

type Probe = object
  nav, hold, match: int
  destOcc, destEmpty: int
  noFriendly, friendlyAhead: int
  enemyHero, enemyCreep: int
  wpBehind: int
  waveWaitHit, skipBehindHit, reanchorHit, widerHit, occNoopHit: int
  waveWaitChange, skipBehindChange, reanchorChange, widerChange, occNoopChange: int

proc probeGame(path, focalName: string) =
  echo "Probe ", extractFilename(path)
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
  var probes: array[5, Probe]
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
      var p = probes[i]
      inc p.nav
      if iv == av:
        inc p.match
      let wpGoal =
        if state.waypointIndex >= 0 and
            state.waypointIndex < view.lane().len:
          (int(view.lane()[state.waypointIndex][0]),
           int(view.lane()[state.waypointIndex][1]))
        else:
          ancientGoal(view)
      let ahead = friendlyAhead(view, wpGoal)
      let occ = destOccupied(view, iv[0], iv[1])
      if occ: inc p.destOcc else: inc p.destEmpty
      if ahead: inc p.friendlyAhead else: inc p.noFriendly
      let (hD, cD, _) = cropScan(view)
      if hD >= 0: inc p.enemyHero
      if cD >= 0: inc p.enemyCreep
      let field = policy.nav.costField(ancientGoal(view))
      let here = field[view.y * mapWidth + view.x]
      let wpc = field[wpGoal[0] * mapWidth + wpGoal[1]]
      if here != unreached and wpc != unreached and wpc >= here:
        inc p.wpBehind
      # Candidate 1: wave-wait hold (no friendly closer to current wp).
      var wave = iv
      if not ahead and iv != (0, 0):
        wave = (0, 0)
        inc p.waveWaitChange
      if wave == av:
        inc p.waveWaitHit
      # Candidate 2: skip behind waypoints.
      let skipGoal = skipBehindGoal(policy.nav, view, state)
      var skip = policy.nav.stepToward(view.y, view.x, skipGoal)
      if skip != iv:
        inc p.skipBehindChange
      if skip == av:
        inc p.skipBehindHit
      # Candidate 3: re-anchor nearest every tick.
      let reGoal = nearestEveryGoal(view)
      var re = policy.nav.stepToward(view.y, view.x, reGoal)
      if re != iv:
        inc p.reanchorChange
      if re == av:
        inc p.reanchorHit
      # Candidate 4: wider reached radius 8.
      let wGoal = widerReachedGoal(view, state, 8.0)
      var wstep = policy.nav.stepToward(view.y, view.x, wGoal)
      if wstep != iv:
        inc p.widerChange
      if wstep == av:
        inc p.widerHit
      # Occupancy no-op (first5-like; measurement only).
      var occStep = iv
      if occ:
        occStep = (0, 0)
        inc p.occNoopChange
      if occStep == av:
        inc p.occNoopHit
      if iv != av:
        inc p.hold  # reuse as mismatch count
      probes[i] = p
    var actions: array[NumHeroes, array[6, uint8]]
    for pid in 0 ..< NumHeroes:
      actions[pid] = replay.rowAt(tick, pid)
    runtime.writeActions(actions)
    runtime.step()
  for i in 0 .. 4:
    let p = probes[i]
    echo "  ", RoleNames[i], " nav=", p.nav, " match=", p.match,
      " mismatch=", p.hold
    echo "    destOcc=", p.destOcc, " destEmpty=", p.destEmpty,
      " friendlyAhead=", p.friendlyAhead, " noFriendly=", p.noFriendly,
      " enemyHero=", p.enemyHero, " enemyCreep=", p.enemyCreep,
      " wpBehind=", p.wpBehind
    echo "    waveWait hit=", p.waveWaitHit, "/", p.nav,
      " changes=", p.waveWaitChange
    echo "    skipBehind hit=", p.skipBehindHit, "/", p.nav,
      " changes=", p.skipBehindChange
    echo "    reanchor hit=", p.reanchorHit, "/", p.nav,
      " changes=", p.reanchorChange
    echo "    wider8 hit=", p.widerHit, "/", p.nav,
      " changes=", p.widerChange
    echo "    occNoop hit=", p.occNoopHit, "/", p.nav,
      " changes=", p.occNoopChange

proc runProbe() =
  probeGame(ResearchDir / "evidence" / "replays" / "r3730-g4.moba", "daveey")
  probeGame(ResearchDir / "evidence" / "replays" / "r3728-g9.moba", "daveey")

runProbe()
