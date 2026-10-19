## Compare frozen v1 retreat decisions to hosted leader/v1 actions.
## Reconstruction only: pinned wasm, exact end-state match required.
## Not a score source.

import
  std/[json, os, strutils, tables],
  crunchy,
  observations, replays, runtimes, baseline

const
  ExpectedWasmSha =
    "b76a9c4cdcc7e4a47c973d4029737a832e0b678646c6a512f5653d3e98f1b8c8"
  RoleWords = ["support", "assassin", "burst", "tank", "carry"]
  ExampleCap = 6

type
  AnalyzeError = object of CatchableError
  Example = object
    tick, pid, health10, l1Spawn: int
    role, region, kind: string
    baseMode: string
    intended, actual: (int, int)
  HeroAcc = object
    pid, team: int
    role: string
    ticks, deaths: int
    baseRetreat: int
    velMatchRetreat: int
    velMismatchRetreat: int
    actualTowardFountOnRetreat: int
    actualAwayOnRetreat: int
    actualHoldOnRetreat: int
    earlyActualRetreat: int
    earlyActualReturn: int
    skipRetreatAt3: int
    fountainTicks: int
    assignedTicks: int
    offLaneTicks: int
    enterHp: array[11, int]
    exitHp: array[11, int]
    actualStartHp: array[11, int]
    actualLeaveFountHp: array[11, int]
    prevHealth: int
    prevMode: HeroMode
    prevRegion: Region
    havePrev: bool
    inActualRetreat: bool
  GameAcc = object
    path: string
    names: seq[string]
    ticks: int
    hostedWinner, simWinner: string
    verified: bool
    mismatch: string
    digest: uint32
    heroes: array[NumHeroes, HeroAcc]
    examples: seq[Example]

proc raiseAnalyze(message: string) {.raises: [AnalyzeError].} =
  raise newException(AnalyzeError, message)

proc sha256Hex(data: string): string =
  toHex(sha256(data))

proc velOf(row: openArray[int]): (int, int) =
  ((row[0] - 3) div 3, (row[1] - 3) div 3)

proc velOfU(row: openArray[uint8]): (int, int) =
  ((int(row[0]) - 3) div 3, (int(row[1]) - 3) div 3)

proc l1Spawn(y, x, team: int): int =
  let (sy, sx) = Spawns[team]
  l1(y, x, sy, sx)

proc towardFountain(y, x, dy, dx, team: int): bool =
  if dy == 0 and dx == 0:
    return false
  l1Spawn(y + dy, x + dx, team) < l1Spawn(y, x, team)

proc modeWord(mode: HeroMode): string =
  if mode == RetreatMode: "retreat" else: "push"

proc snapshotStats(runtime: MobaRuntime): JsonNode =
  result = newJArray()
  for pid in 0 ..< NumHeroes:
    var row = newJObject()
    for which, name in StatNames:
      row[name] = %int(runtime.agentStat(pid, which))
    result.add row

proc statsEqual(hosted, reconstructed: JsonNode): string =
  if hosted.isNil or hosted.kind != JArray:
    return "hosted agent_stats missing"
  if hosted.len != NumHeroes or reconstructed.len != NumHeroes:
    return "agent_stats length mismatch"
  for pid in 0 ..< NumHeroes:
    for name in StatNames:
      let
        a = hosted[pid]{name}.getInt(high(int))
        b = reconstructed[pid]{name}.getInt(high(int) - 1)
      if a != b:
        return "pid " & $pid & " " & name & " hosted=" & $a &
          " sim=" & $b
  ""

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

proc hostedAncient(replay: Replay, team: int): (bool, float) =
  let node = replay.resultOf(){"ancient_healths"}
  if node.isNil or node.kind != JArray or team >= node.len:
    return (false, 0.0)
  (true, node[team].getFloat(0.0))

proc addExample(game: var GameAcc, ex: Example) =
  var n = 0
  for e in game.examples:
    if e.kind == ex.kind:
      inc n
  if n < ExampleCap:
    game.examples.add ex

proc histJson(h: array[11, int]): JsonNode =
  result = newJArray()
  for v in h:
    result.add(%v)

proc analyzeReplay(replayPath, wasmPath: string): GameAcc =
  let
    replayBytes = readFile(replayPath)
    wasmBytes = readFile(wasmPath)
  let replay = parseReplay(replayBytes)
  if sha256Hex(wasmBytes) != ExpectedWasmSha:
    raiseAnalyze("wasm hash mismatch")
  let want = replay.header{"sim_wasm_sha256"}.getStr("")
  if want != ExpectedWasmSha:
    raiseAnalyze("replay wasm hash " & want)
  result.path = replayPath
  result.names = replay.playerNames()
  result.ticks = replay.tickCount
  result.hostedWinner = hostedWinnerName(replay)
  for pid in 0 ..< NumHeroes:
    result.heroes[pid] = HeroAcc(
      pid: pid,
      team: teamOf(pid),
      role: RoleWords[roleOf(pid)],
      prevRegion: FountainRegion,
      prevMode: PushMode
    )
  var runtime = newRuntime(wasmBytes, int64(replay.seedOf()))
  defer:
    runtime.close()
  var
    policies: array[2, GorynychPolicy]
    prevViews: array[NumHeroes, HeroView]
    havePrev = false
  policies[0] = newGorynychPolicy()
  policies[1] = newGorynychPolicy()
  for tick in 0 ..< replay.tickCount:
    if runtime.fault() != 0:
      raiseAnalyze("sim_fault at tick " & $tick)
    if runtime.tick() != int32(tick):
      raiseAnalyze("sim tick mismatch at " & $tick)
    let obs = runtime.observations()
    var actions: array[NumHeroes, array[6, uint8]]
    for pid in 0 ..< NumHeroes:
      actions[pid] = replay.rowAt(tick, pid)
    var views: array[NumHeroes, HeroView]
    for pid in 0 ..< NumHeroes:
      views[pid] = parseView(obs[pid])
    var intended: array[NumHeroes, array[6, int]]
    var modes: array[NumHeroes, HeroMode]
    for team in 0 .. 1:
      for local in 0 .. 4:
        let pid = team * 5 + local
        intended[pid] = policies[team].heroAction(local, obs[pid])
        modes[pid] = policies[team].heroes[local].mode
    for pid in 0 ..< NumHeroes:
      var hero = result.heroes[pid]
      let
        view = views[pid]
        region = classifyRegion(view.y, view.x, view.team)
        (idy, idx) = velOf(intended[pid])
        (ady, adx) = velOfU(actions[pid])
        actualToward = towardFountain(
          view.y, view.x, ady, adx, view.team
        )
        spawnL1 = l1Spawn(view.y, view.x, view.team)
        atFountain = region == FountainRegion
      inc hero.ticks
      if atFountain:
        inc hero.fountainTicks
      if region == assignedRegion(pid):
        inc hero.assignedTicks
      else:
        inc hero.offLaneTicks
      if havePrev:
        let jump = chebyshev(
          view.y, view.x, prevViews[pid].y, prevViews[pid].x
        )
        if jump >= TeleportJump and spawnL1 <= FountainRadius:
          inc hero.deaths
          hero.inActualRetreat = false
      if hero.havePrev:
        if hero.prevMode == PushMode and modes[pid] == RetreatMode:
          inc hero.enterHp[view.health10]
        if hero.prevMode == RetreatMode and modes[pid] == PushMode:
          inc hero.exitHp[view.health10]
      if modes[pid] == RetreatMode:
        inc hero.baseRetreat
        if idy == ady and idx == adx:
          inc hero.velMatchRetreat
        else:
          inc hero.velMismatchRetreat
        if actualToward:
          inc hero.actualTowardFountOnRetreat
        elif ady == 0 and adx == 0:
          inc hero.actualHoldOnRetreat
        else:
          inc hero.actualAwayOnRetreat
        if view.health10 >= 4 and view.health10 <= 7 and
            not actualToward and not atFountain:
          inc hero.earlyActualReturn
        if view.health10 <= 3 and not actualToward and
            not atFountain and (ady != 0 or adx != 0):
          inc hero.skipRetreatAt3
        if idy != ady or idx != adx:
          let kind =
            if ady == 0 and adx == 0: "retreat-hold-mismatch"
            elif actualToward: "retreat-path-mismatch"
            else: "retreat-away-mismatch"
          result.addExample Example(
            tick: tick, pid: pid, health10: view.health10,
            l1Spawn: spawnL1, role: hero.role,
            region: regionName(region), kind: kind,
            baseMode: "retreat",
            intended: (idy, idx), actual: (ady, adx)
          )
      else:
        if actualToward and view.health10 >= 4 and
            view.health10 <= 6 and not atFountain:
          inc hero.earlyActualRetreat
        if (idy != ady or idx != adx) and actualToward and
            view.health10 <= 6 and not atFountain:
          result.addExample Example(
            tick: tick, pid: pid, health10: view.health10,
            l1Spawn: spawnL1, role: hero.role,
            region: regionName(region), kind: "push-toward-fount-mismatch",
            baseMode: "push",
            intended: (idy, idx), actual: (ady, adx)
          )
      if actualToward and not hero.inActualRetreat and
          view.health10 <= 6 and not atFountain:
        inc hero.actualStartHp[view.health10]
        hero.inActualRetreat = true
      if hero.inActualRetreat and not actualToward and
          not atFountain and view.health10 >= 4:
        hero.inActualRetreat = false
      if hero.havePrev and hero.prevRegion == FountainRegion and
          not atFountain:
        inc hero.actualLeaveFountHp[view.health10]
        hero.inActualRetreat = false
        if view.health10 < 10:
          result.addExample Example(
            tick: tick, pid: pid, health10: view.health10,
            l1Spawn: spawnL1, role: hero.role,
            region: regionName(region), kind: "leave-fountain",
            baseMode: modeWord(modes[pid]),
            intended: (idy, idx), actual: (ady, adx)
          )
      hero.prevHealth = view.health10
      hero.prevMode = modes[pid]
      hero.prevRegion = region
      hero.havePrev = true
      result.heroes[pid] = hero
    runtime.writeActions(actions)
    runtime.step()
    if runtime.fault() != 0:
      raiseAnalyze("sim_fault after tick " & $tick)
    prevViews = views
    havePrev = true
  let
    simTick = int(runtime.tick())
    simA0 = runtime.ancientHealth(0)
    simA1 = runtime.ancientHealth(1)
    hostedTick = replay.resultOf(){"final_tick"}.getInt(-1)
    hostedEnd = replay.resultOf(){"end_reason"}.getStr("")
    simStats = runtime.snapshotStats()
  result.digest = runtime.stateDigest()
  if runtime.done() != 0:
    result.simWinner =
      if runtime.winner() == 0: "radiant"
      elif runtime.winner() == 1: "dire"
      else: $runtime.winner()
  else:
    result.simWinner = "none"
  var mismatch = ""
  if simTick != hostedTick:
    mismatch = "final_tick hosted=" & $hostedTick & " sim=" & $simTick
  elif result.simWinner != result.hostedWinner:
    mismatch = "winner hosted=" & result.hostedWinner &
      " sim=" & result.simWinner
  elif hostedEnd.len > 0 and runtime.done() == 0:
    mismatch = "end_reason hosted=" & hostedEnd & " sim not done"
  else:
    mismatch = statsEqual(replay.resultOf(){"agent_stats"}, simStats)
    if mismatch.len == 0:
      for team in 0 .. 1:
        let (haveH, hostedH) = hostedAncient(replay, team)
        let simH = if team == 0: float(simA0) else: float(simA1)
        if haveH and abs(simH - hostedH) > 0.51:
          mismatch = "ancient[" & $team & "]"
          break
  result.mismatch = mismatch
  result.verified = mismatch.len == 0
  if not result.verified:
    raiseAnalyze("end-state mismatch " & replayPath & ": " & mismatch)

proc heroJson(h: HeroAcc): JsonNode =
  %*{
    "pid": h.pid,
    "team": h.team,
    "role": h.role,
    "ticks": h.ticks,
    "deaths": h.deaths,
    "baseline_retreat_ticks": h.baseRetreat,
    "vel_match_on_retreat": h.velMatchRetreat,
    "vel_mismatch_on_retreat": h.velMismatchRetreat,
    "actual_toward_fountain_on_retreat": h.actualTowardFountOnRetreat,
    "actual_away_on_retreat": h.actualAwayOnRetreat,
    "actual_hold_on_retreat": h.actualHoldOnRetreat,
    "early_actual_retreat_hp4to6": h.earlyActualRetreat,
    "early_actual_return_hp4to7": h.earlyActualReturn,
    "skip_retreat_at_hp3": h.skipRetreatAt3,
    "fountain_ticks": h.fountainTicks,
    "assigned_lane_ticks": h.assignedTicks,
    "off_assigned_ticks": h.offLaneTicks,
    "baseline_enter_hp": histJson(h.enterHp),
    "baseline_exit_hp": histJson(h.exitHp),
    "actual_start_hp": histJson(h.actualStartHp),
    "actual_leave_fountain_hp": histJson(h.actualLeaveFountHp)
  }

proc gameJson(g: GameAcc): JsonNode =
  result = %*{
    "scoring_evidence": false,
    "path": g.path,
    "players": g.names,
    "ticks": g.ticks,
    "hosted_winner": g.hostedWinner,
    "sim_winner": g.simWinner,
    "verified": g.verified,
    "state_digest": g.digest.int
  }
  var heroes = newJArray()
  for h in g.heroes:
    heroes.add heroJson(h)
  result["heroes"] = heroes
  var examples = newJArray()
  for e in g.examples:
    examples.add %*{
      "kind": e.kind,
      "tick": e.tick,
      "pid": e.pid,
      "role": e.role,
      "health10": e.health10,
      "region": e.region,
      "l1_spawn": e.l1Spawn,
      "baseline_mode": e.baseMode,
      "intended_dy_dx": [e.intended[0], e.intended[1]],
      "actual_dy_dx": [e.actual[0], e.actual[1]]
    }
  result["examples"] = examples

proc main() =
  if paramCount() < 2:
    raiseAnalyze("usage: analyze wasm replay [replay...]")
  let wasmPath = paramStr(1)
  var games = newJArray()
  for i in 2 .. paramCount():
    echo "analyzing ", paramStr(i)
    let g = analyzeReplay(paramStr(i), wasmPath)
    echo "  verified ", g.names, " ticks=", g.ticks,
      " winner=", g.hostedWinner, " digest=", g.digest
    games.add gameJson(g)
  let outPath = "evidence/retreat-compare.json"
  writeFile(outPath, pretty(%*{
    "scoring_evidence": false,
    "games": games
  }))
  echo "wrote ", outPath

main()
