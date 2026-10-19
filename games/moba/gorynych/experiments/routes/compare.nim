## Reconstruct hosted observations and compare frozen-baseline movement
## with the recorded seat actions. Navigation only: retreat and siege
## ticks are counted then excluded from the movement mismatch tally.
## scoring_evidence is false. Never a hosted score.

import
  std/[json, os, strutils],
  crunchy,
  replays, runtimes

include baseline

const
  RoutesDir = currentSourcePath().parentDir
  ResearchDir = RoutesDir / ".." / ".." / "research"
  EvidenceDir = ResearchDir / ".." / "evidence"
  WasmPath = ResearchDir / "evidence" / "wasm" / "moba_sim.wasm"
  ExpectedWasmSha = "b76a9c4cdcc7e4a47c973d4029737a832e0b678646c6a512f5653d3e98f1b8c8"
  PythonWallsPath = RoutesDir / "python_walls.bin"
  RoleNames = ["support", "assassin", "burst", "tank", "carry"]
  StatNames = [
    "level", "kills", "deaths", "towers_killed", "creeps_killed",
    "neutrals_killed", "xp", "damage_dealt", "damage_received",
    "healing_dealt", "healing_received"
  ]
  ExampleCap = 8

type
  Kind = enum
    RetreatTick, SiegeTick, NavTick
  MismatchKind = enum
    MatchMove, LeaderHold, BaselineHold, DetourPlus, DetourMinus,
    SkipAhead, GoBack, GreedySign, IntendedBlocked, OtherMove
  Example = object
    tick, pid, y, x, wp: int
    intended, actual: (int, int)
    destTile: int
    note: string
  HeroTally = object
    ticks, retreat, siege, nav: int
    velMatch, velMismatch: int
    navMatch, navMismatch: int
    filterMatch, skillMatch: int
    intendedBlocked, actualBlocked: int
    stayWanted, stayActual: int
    progress, regress, sameGoal: int
    reanchorTeleport, reanchorRetreat: int
    kinds: array[MismatchKind, int]
    examples: seq[Example]
  GameTally = object
    path, focal, opponent: string
    team, ticks: int
    verified: bool
    mismatch: string
    winner: string
    heroes: array[5, HeroTally]

proc velOf(row: array[6, int] | array[6, uint8]): (int, int) =
  ## Decode unit-step velocity.
  ((int(row[0]) - 3) div 3, (int(row[1]) - 3) div 3)

proc cropAt(view: HeroView, dy, dx: int): int =
  ## Crop tile of a unit step, or -1 if outside vision.
  view.tile(dy, dx)

proc kindOf(policy: GorynychPolicy, view: HeroView, state: HeroState): Kind =
  ## Classify the tick the way the frozen policy picks a goal.
  if state.mode == RetreatMode:
    return RetreatTick
  let (towerIdx, towerDistance) = policy.nearestLiveEnemyTower(view)
  if towerIdx >= 0 and towerDistance <= siegeStandoff:
    return SiegeTick
  NavTick

proc rotateOf(dy, dx, side: int): (int, int) =
  rotate90(dy, dx, side)

proc classifyMismatch(
  nav: var NavGrid, view: HeroView, state: HeroState,
  intended, actual: (int, int)
): (MismatchKind, string) =
  ## Label one NAV velocity disagreement.
  if intended == actual:
    return (MatchMove, "")
  if actual == (0, 0) and intended != (0, 0):
    return (LeaderHold, "leader held, baseline stepped")
  if intended == (0, 0) and actual != (0, 0):
    return (BaselineHold, "baseline held, leader stepped")
  if actual == rotateOf(intended[0], intended[1], 1):
    return (DetourPlus, "actual is +90 of baseline")
  if actual == rotateOf(intended[0], intended[1], -1):
    return (DetourMinus, "actual is -90 of baseline")
  let dest = view.tile(intended[0], intended[1])
  if dest > 0:
    result = (IntendedBlocked, "baseline dest tile=" & $dest)
  let lanePoints = view.lane()
  var hit = -1
  for i, (wy, wx) in lanePoints:
    let step = nav.stepToward(view.y, view.x, (int(wy), int(wx)))
    if step == actual:
      hit = i
      break
  if hit >= 0:
    if hit > state.waypointIndex:
      return (SkipAhead, "actual matches waypoint " & $hit &
        " baseline wp=" & $state.waypointIndex)
    if hit < state.waypointIndex:
      return (GoBack, "actual matches waypoint " & $hit &
        " baseline wp=" & $state.waypointIndex)
  var gy, gx = 0
  if state.waypointIndex >= 0 and state.waypointIndex < lanePoints.len:
    gy = int(lanePoints[state.waypointIndex][0])
    gx = int(lanePoints[state.waypointIndex][1])
  if actual == (sign(gy - view.y), sign(gx - view.x)):
    return (GreedySign, "actual is greedy sign to current waypoint")
  if dest > 0:
    return (IntendedBlocked, "baseline dest tile=" & $dest)
  return (OtherMove, "unclassified")

proc addExample(hero: var HeroTally, ex: Example) =
  if hero.examples.len < ExampleCap:
    hero.examples.add ex

proc sha256Hex(data: string): string =
  toHex(sha256(data))

proc compareWalls() =
  echo "Wall grid: Nim packed vs Python zlib (sha256 ec17403c...)"
  let
    nimWalls = decodeWalls()
    python = readFile(PythonWallsPath)
  doAssert python.len == mapWidth * mapWidth
  var
    differ = 0
    nimCount = 0
    pyCount = 0
    first = (-1, -1)
  for y in 0 ..< mapWidth:
    for x in 0 ..< mapWidth:
      let i = y * mapWidth + x
      let n = nimWalls[i]
      let p = python[i].uint8 != 0
      if n: inc nimCount
      if p: inc pyCount
      if n != p:
        inc differ
        if first[0] < 0:
          first = (y, x)
  echo "  python sha256 ", sha256Hex(python)
  echo "  python walls ", pyCount, " nim walls ", nimCount,
    " cell mismatches ", differ
  if first[0] >= 0:
    echo "  first mismatch cell (y,x)=", first
  var nav = initNavGrid()
  echo "  tower cells marked as walls in Nim nav:"
  var towerMarked = 0
  for t in towers:
    let y = int(t.y)
    let x = int(t.x)
    if nav.walls[y * mapWidth + x]:
      inc towerMarked
  echo "  ", towerMarked, " / ", towers.len
  # Spawn-to-first-waypoint BFS steps for each radiant role.
  echo "  spawn BFS first step by role (radiant 113,12):"
  for heroType in 0 .. 4:
    let wp = waypoints[laneForHero[heroType]][0]
    let step = nav.stepToward(113, 12, (int(wp[0]), int(wp[1])))
    echo "    ", RoleNames[heroType], " lane ", laneForHero[heroType],
      " goal ", (int(wp[0]), int(wp[1])), " step ", step

proc hostedWinnerName(replay: Replay): string =
  let node = replay.resultOf(){"winner"}
  if node.isNil or node.kind == JNull:
    return "draw"
  if node.kind == JInt:
    let value = node.getInt(-1)
    if value == 0: return "radiant"
    if value == 1: return "dire"
    return $value
  node.getStr("")

proc verifyEnd(
  runtime: MobaRuntime, replay: Replay
): (bool, string, string) =
  ## Match hosted winner/tick/stats/ancients. Not a score.
  let
    simTick = int(runtime.tick())
    hostedTick = replay.resultOf(){"final_tick"}.getInt(-1)
    hostedWinner = hostedWinnerName(replay)
    hostedEnd = replay.resultOf(){"end_reason"}.getStr("")
  var simWinner = "none"
  var simEnd = "not_done"
  if runtime.done() != 0:
    simEnd = "ancient"
    simWinner =
      if runtime.winner() == 0: "radiant"
      elif runtime.winner() == 1: "dire"
      else: $runtime.winner()
  if simTick != hostedTick:
    return (false, "final_tick hosted=" & $hostedTick & " sim=" & $simTick,
      simWinner)
  if simTick != replay.tickCount:
    return (false, "sim tick != body tick_count", simWinner)
  if simWinner != hostedWinner:
    return (false, "winner hosted=" & hostedWinner & " sim=" & simWinner,
      simWinner)
  if simEnd != hostedEnd:
    return (false, "end_reason hosted=" & hostedEnd & " sim=" & simEnd,
      simWinner)
  let hostedStats = replay.resultOf(){"agent_stats"}
  if hostedStats.isNil or hostedStats.kind != JArray or
      hostedStats.len != NumHeroes:
    return (false, "hosted agent_stats missing", simWinner)
  for pid in 0 ..< NumHeroes:
    for which, name in StatNames:
      let
        a = hostedStats[pid]{name}.getInt(high(int))
        b = int(runtime.agentStat(pid, which))
      if a != b:
        return (false, "pid " & $pid & " " & name & " hosted=" & $a &
          " sim=" & $b, simWinner)
  let ancients = replay.resultOf(){"ancient_healths"}
  if not ancients.isNil and ancients.kind == JArray:
    for team in 0 .. 1:
      if team < ancients.len:
        let hostedH = ancients[team].getFloat(0.0)
        let simH = float(runtime.ancientHealth(team))
        if abs(simH - hostedH) > 0.51:
          return (false, "ancient[" & $team & "] hosted=" & $hostedH &
            " sim=" & $simH, simWinner)
  (true, "", simWinner)

proc analyzeGame(path, focalName: string): GameTally =
  echo "Reconstruct ", path
  let
    replayBytes = readFile(path)
    wasmBytes = readFile(WasmPath)
    replay = parseReplay(replayBytes)
    wasmSha = sha256Hex(wasmBytes)
  doAssert wasmSha == ExpectedWasmSha, "pinned wasm hash mismatch"
  doAssert wasmSha == replay.header{"sim_wasm_sha256"}.getStr(""),
    "replay wasm hash mismatch"
  let names = replay.playerNames()
  var team = -1
  for i, name in names:
    if name.toLowerAscii.contains(focalName.toLowerAscii):
      team = i
      break
  doAssert team >= 0, "focal name not in " & $names
  result.path = path
  result.focal = names[team]
  result.opponent = if 1 - team < names.len: names[1 - team] else: ""
  result.team = team
  result.ticks = replay.tickCount
  var runtime = newRuntime(wasmBytes, int64(replay.seedOf()))
  defer:
    runtime.close()
  var policy = newGorynychPolicy()
  var lastPos: array[5, (int, int)]
  var haveLast: array[5, bool]
  var lastGoalDist: array[5, int]
  for tick in 0 ..< replay.tickCount:
    if runtime.fault() != 0:
      raiseRecon("sim_fault at tick " & $tick)
    let obs = runtime.observations()
    # Process the seat in hosted order 0..4 so tower memory matches.
    for i in 0 .. 4:
      let pid = team * 5 + i
      let view = parseView(obs[pid])
      if i notin policy.heroes:
        policy.heroes[i] = newHeroState()
      let state = policy.heroes[i]
      let beforeWp = state.waypointIndex
      let beforeMode = state.mode
      let intended = policy.heroAction(i, obs[pid])
      var actualRow: array[6, uint8]
      actualRow = replay.rowAt(tick, pid)
      let
        iv = velOf(intended)
        av = velOf(actualRow)
        kind = policy.kindOf(view, state)
      var hero = result.heroes[i]
      inc hero.ticks
      case kind
      of RetreatTick: inc hero.retreat
      of SiegeTick: inc hero.siege
      of NavTick: inc hero.nav
      if iv == av:
        inc hero.velMatch
      else:
        inc hero.velMismatch
      if intended[2] == int(actualRow[2]):
        inc hero.filterMatch
      if intended[3] == int(actualRow[3]) and
          intended[4] == int(actualRow[4]) and
          intended[5] == int(actualRow[5]):
        inc hero.skillMatch
      if iv != (0, 0):
        let dt = view.cropAt(iv[0], iv[1])
        if dt > 0:
          inc hero.intendedBlocked
      if av != (0, 0):
        let dt = view.cropAt(av[0], av[1])
        if dt > 0:
          inc hero.actualBlocked
      if haveLast[i] and lastPos[i] == (view.y, view.x):
        if iv != (0, 0):
          inc hero.stayWanted
        if av != (0, 0):
          inc hero.stayActual
      let lanePoints = view.lane()
      if state.waypointIndex >= 0 and state.waypointIndex < lanePoints.len:
        let (wy, wx) = lanePoints[state.waypointIndex]
        let d = max(abs(int(wy) - view.y), abs(int(wx) - view.x))
        if haveLast[i]:
          if d < lastGoalDist[i]:
            inc hero.progress
          elif d > lastGoalDist[i]:
            inc hero.regress
          else:
            inc hero.sameGoal
        lastGoalDist[i] = d
      if haveLast[i]:
        let jump = max(abs(view.y - lastPos[i][0]), abs(view.x - lastPos[i][1]))
        if jump > int(teleportDistance) and beforeWp >= 0 and
            state.waypointIndex != beforeWp:
          inc hero.reanchorTeleport
      if beforeMode == RetreatMode and state.mode == PushMode:
        inc hero.reanchorRetreat
      if kind == NavTick:
        if iv == av:
          inc hero.navMatch
          inc hero.kinds[MatchMove]
        else:
          inc hero.navMismatch
          let (mk, note) = classifyMismatch(
            policy.nav, view, state, iv, av)
          inc hero.kinds[mk]
          var dest = -1
          if iv != (0, 0):
            dest = view.cropAt(iv[0], iv[1])
          hero.addExample Example(
            tick: tick, pid: pid, y: view.y, x: view.x,
            wp: state.waypointIndex, intended: iv, actual: av,
            destTile: dest, note: note)
      lastPos[i] = (view.y, view.x)
      haveLast[i] = true
      result.heroes[i] = hero
    var actions: array[NumHeroes, array[6, uint8]]
    for pid in 0 ..< NumHeroes:
      actions[pid] = replay.rowAt(tick, pid)
    runtime.writeActions(actions)
    runtime.step()
  let (ok, why, winner) = runtime.verifyEnd(replay)
  result.verified = ok
  result.mismatch = why
  result.winner = winner
  echo "  verified=", ok, " ticks=", result.ticks, " team=", team,
    " focal=", result.focal, " vs ", result.opponent, " winner=", winner
  if not ok:
    echo "  MISMATCH ", why

proc pct(n, d: int): string =
  if d == 0: "n/a" else: formatFloat(100.0 * n.float / d.float, ffDecimal, 1) & "%"

proc printHero(role: string, h: HeroTally) =
  echo "    ", role, " ticks=", h.ticks,
    " retreat=", h.retreat, " siege=", h.siege, " nav=", h.nav
  echo "      vel match ", h.velMatch, "/", h.ticks, " ", pct(h.velMatch, h.ticks),
    " nav match ", h.navMatch, "/", h.nav, " ", pct(h.navMatch, h.nav)
  echo "      filter match ", pct(h.filterMatch, h.ticks),
    " skill match ", pct(h.skillMatch, h.ticks)
  echo "      intended dest occupied ", h.intendedBlocked,
    " actual dest occupied ", h.actualBlocked
  echo "      stay-while-want-move ", h.stayWanted,
    " stay-while-leader-move ", h.stayActual
  echo "      goal progress/regress/same ", h.progress, "/", h.regress, "/",
    h.sameGoal
  echo "      reanchor teleport ", h.reanchorTeleport,
    " retreat-exit ", h.reanchorRetreat
  echo "      nav mismatch kinds:",
    " hold=", h.kinds[LeaderHold],
    " baseHold=", h.kinds[BaselineHold],
    " detour+=", h.kinds[DetourPlus],
    " detour-=", h.kinds[DetourMinus],
    " skip=", h.kinds[SkipAhead],
    " back=", h.kinds[GoBack],
    " greedy=", h.kinds[GreedySign],
    " blocked=", h.kinds[IntendedBlocked],
    " other=", h.kinds[OtherMove]
  for ex in h.examples:
    echo "        t", ex.tick, " pid", ex.pid, " (", ex.y, ",", ex.x, ")",
      " wp=", ex.wp, " base=", ex.intended, " act=", ex.actual,
      " destTile=", ex.destTile, " ", ex.note

proc printGame(g: GameTally) =
  echo "Game ", extractFilename(g.path), " verified=", g.verified,
    " ", g.focal, " team ", g.team, " vs ", g.opponent,
    " ticks ", g.ticks, " winner ", g.winner
  var
    nav, navMatch, velMatch, ticks: int
    kinds: array[MismatchKind, int]
  for i in 0 .. 4:
    printHero(RoleNames[i], g.heroes[i])
    ticks += g.heroes[i].ticks
    nav += g.heroes[i].nav
    navMatch += g.heroes[i].navMatch
    velMatch += g.heroes[i].velMatch
    for k in MismatchKind:
      kinds[k] += g.heroes[i].kinds[k]
  echo "  SEAT nav match ", navMatch, "/", nav, " ", pct(navMatch, nav),
    " any-mode vel match ", velMatch, "/", ticks, " ", pct(velMatch, ticks)
  echo "  SEAT nav mismatch kinds hold=", kinds[LeaderHold],
    " baseHold=", kinds[BaselineHold],
    " detour+=", kinds[DetourPlus],
    " detour-=", kinds[DetourMinus],
    " skip=", kinds[SkipAhead],
    " back=", kinds[GoBack],
    " greedy=", kinds[GreedySign],
    " blocked=", kinds[IntendedBlocked],
    " other=", kinds[OtherMove]

proc runCompare() =
  doAssert fileExists(WasmPath)
  doAssert fileExists(PythonWallsPath)
  compareWalls()
  let games = [
    (ResearchDir / "evidence" / "replays" / "r3730-g4.moba", "daveey"),
    (ResearchDir / "evidence" / "replays" / "r3728-g9.moba", "daveey"),
    (EvidenceDir / "xreq_798c5043-ed36-4776-8f80-158019ec0d90" /
      "ereq_82528dd3-f68f-4ba7-b27a-c3a9abf4a9a6.replay", "Andre"),
    (EvidenceDir / "xreq_798c5043-ed36-4776-8f80-158019ec0d90" /
      "ereq_9b896a79-6a0e-4ab8-8140-db1f38331610.replay", "Andre")
  ]
  var tallies: seq[GameTally]
  for (path, focal) in games:
    let g = analyzeGame(path, focal)
    printGame(g)
    tallies.add g
  echo "DONE games=", tallies.len
  for g in tallies:
    doAssert g.verified, g.path & " " & g.mismatch

runCompare()
