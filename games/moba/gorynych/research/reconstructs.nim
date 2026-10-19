## Replay recorded hosted actions through the pinned sim and tally
## reconstructed occupancy, tower events, exposure/cover, assassin E.
## Never a score source. Output is written only after an end-state match.

import
  std/json,
  crunchy,
  observations, replays, runtimes

const
  OpeningTicks* = 300
  SampleStride* = 50
  AssassinPids* = [1, 6]
  ExpectedWasmSha* = "b76a9c4cdcc7e4a47c973d4029737a832e0b678646c6a512f5653d3e98f1b8c8"

type
  SkillFire* = object
    tick*: int
    pid*: int
    health10*: int
    region*: string
    nearFountain*: bool
  TowerDeath* = object
    tick*: int
    pid*: int
    towerIndex*: int
    towerTeam*: int
    towerTier*: int
  HeroPath* = object
    pid*: int
    team*: int
    role*: string
    assigned*: string
    opening*: array[5, int]
    all*: array[5, int]
    deaths*: int
    eFlags*: int
    eFires*: int
    eBlocked*: int
    eOnRetreat*: int
    eOnFountain*: int
    inTowerRange*: int
    exposed*: int
    covered*: int
    sampled*: seq[JsonNode]
  Reconstruction* = object
    replayPath*: string
    wasmPath*: string
    wasmSha*: string
    seed*: int64
    ticks*: int
    hostedWinner*: string
    hostedEnd*: string
    hostedTick*: int
    simWinner*: string
    simEnd*: string
    simTick*: int
    simDigest*: uint32
    simAncients*: array[2, float32]
    verified*: bool
    mismatch*: string
    scoringEvidence*: bool
    openingWindow*: int
    heroes*: array[NumHeroes, HeroPath]
    towerDeaths*: seq[TowerDeath]
    eFires*: seq[SkillFire]
    teamOpening*: array[2, array[5, int]]
    teamStackOpening*: array[2, int]
    hostedStats*: JsonNode
    simStats*: JsonNode

proc sha256Hex*(data: string): string =
  ## Lower-hex sha256 of data.
  toHex(sha256(data))

proc hostedWinnerName(replay: Replay): string =
  ## Header winner as radiant/dire/draw.
  let node = replay.resultOf(){"winner"}
  if node.isNil or node.kind == JNull:
    return "draw"
  if node.kind == JInt:
    let value = node.getInt(-1)
    if value == 0: return "radiant"
    if value == 1: return "dire"
    return $value
  node.getStr("")

proc hostedEndReason(replay: Replay): string =
  ## Header end_reason.
  replay.resultOf(){"end_reason"}.getStr("")

proc hostedFinalTick(replay: Replay): int =
  ## Header final_tick, or -1.
  let node = replay.resultOf(){"final_tick"}
  if node.isNil: -1 else: node.getInt(-1)

proc hostedAncient(replay: Replay, team: int): (bool, float) =
  ## Header ancient health, if present.
  let node = replay.resultOf(){"ancient_healths"}
  if node.isNil or node.kind != JArray or team >= node.len:
    return (false, 0.0)
  (true, node[team].getFloat(0.0))

proc initHeroPath(pid: int): HeroPath =
  ## Empty per-hero reconstruction tally.
  HeroPath(
    pid: pid,
    team: teamOf(pid),
    role: roleName(pid),
    assigned: LaneNames[AssignedLanes[roleOf(pid)]],
    sampled: @[]
  )

proc snapshotStats(runtime: MobaRuntime): JsonNode =
  ## Reads all 10 x 11 exported agent stats.
  result = newJArray()
  for pid in 0 ..< NumHeroes:
    var row = newJObject()
    for which, name in StatNames:
      row[name] = %int(runtime.agentStat(pid, which))
    result.add row

proc statsEqual(hosted, reconstructed: JsonNode): string =
  ## Empty if every required stat matches; else a mismatch note.
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

proc samplePoint(tick: int, view: HeroView, region: Region): JsonNode =
  ## One compact occupancy sample.
  %*{
    "tick": tick,
    "x": view.x,
    "y": view.y,
    "hp10": view.health10,
    "region": regionName(region)
  }

proc rowFromReplay(replay: Replay, tick, pid: int): array[6, uint8] =
  ## One hero action row.
  replay.rowAt(tick, pid)

proc matrixFromReplay(replay: Replay, tick: int): array[NumHeroes, array[6, uint8]] =
  ## 10-hero action matrix at tick.
  for pid in 0 ..< NumHeroes:
    result[pid] = replay.rowFromReplay(tick, pid)

proc updateDeadTowers(
  views: openArray[HeroView], dead: var array[TowerCount, bool]
) =
  ## Marks towers whose cell is visible without a TOWER tile.
  for view in views:
    for i in 0 ..< TowerCount:
      if dead[i]:
        continue
      if view.visibleTowerDead(i):
        dead[i] = true

proc majorityLane(counts: array[5, int]): int =
  ## Index of the densest opening region for one team-tick.
  result = 0
  for i in 1 .. 2:
    if counts[i] > counts[result]:
      result = i

proc reconstruct*(
  replayPath, wasmPath: string
): Reconstruction {.raises: [ReconstructionError, ReplayError].} =
  ## Replays one hosted file through the pinned wasm.
  result.scoringEvidence = false
  result.replayPath = replayPath
  result.wasmPath = wasmPath
  var
    replayBytes: string
    wasmBytes: string
  try:
    replayBytes = readFile(replayPath)
    wasmBytes = readFile(wasmPath)
  except CatchableError as error:
    raiseRecon("read failed: " & error.msg)
  let replay = parseReplay(replayBytes)
  result.wasmSha = sha256Hex(wasmBytes)
  let want = replay.header{"sim_wasm_sha256"}.getStr("")
  if result.wasmSha != want:
    result.mismatch =
      "wasm sha256 " & result.wasmSha & " != replay " & want
    raiseRecon(result.mismatch)
  result.seed = int64(replay.seedOf())
  result.ticks = replay.tickCount
  result.hostedWinner = hostedWinnerName(replay)
  result.hostedEnd = hostedEndReason(replay)
  result.hostedTick = hostedFinalTick(replay)
  result.hostedStats = replay.resultOf(){"agent_stats"}
  result.openingWindow = min(OpeningTicks, replay.tickCount)
  for pid in 0 ..< NumHeroes:
    result.heroes[pid] = initHeroPath(pid)
  var runtime: MobaRuntime
  try:
    runtime = newRuntime(wasmBytes, result.seed)
  except ReconstructionError as error:
    raise error
  except CatchableError as error:
    raiseRecon("wasm init failed: " & error.msg)
  defer:
    runtime.close()
  var
    prevViews: array[NumHeroes, HeroView]
    havePrev: bool
    prevTowers: array[NumHeroes, int]
    dead: array[TowerCount, bool]
  for pid in 0 ..< NumHeroes:
    prevTowers[pid] = 0
  for tick in 0 ..< replay.tickCount:
    if runtime.fault() != 0:
      raiseRecon("sim_fault at tick " & $tick)
    if runtime.done() != 0 and tick < replay.tickCount:
      raiseRecon("sim done before consuming tick " & $tick)
    if runtime.tick() != int32(tick):
      raiseRecon(
        "sim tick " & $runtime.tick() & " != replay index " & $tick
      )
    let
      obs = runtime.observations()
      actions = replay.matrixFromReplay(tick)
    var views: array[NumHeroes, HeroView]
    for pid in 0 ..< NumHeroes:
      if obs[pid].len != ObservationSize:
        raiseRecon("obs size " & $obs[pid].len)
      views[pid] = parseView(obs[pid])
    updateDeadTowers(views, dead)
    var teamLane: array[2, array[5, int]]
    for pid in 0 ..< NumHeroes:
      var hero = result.heroes[pid]
      let
        view = views[pid]
        region = classifyRegion(view.y, view.x, view.team)
        useE = int(actions[pid][5])
      inc hero.all[ord(region)]
      if tick < result.openingWindow:
        inc hero.opening[ord(region)]
        inc result.teamOpening[hero.team][ord(region)]
        inc teamLane[hero.team][ord(region)]
      if havePrev:
        let jump = chebyshev(
          view.y, view.x, prevViews[pid].y, prevViews[pid].x
        )
        if jump >= TeleportJump:
          let (sy, sx) = Spawns[view.team]
          if l1(view.y, view.x, sy, sx) <= FountainRadius:
            inc hero.deaths
      if useE == 1:
        inc hero.eFlags
      let (towerIdx, towerL1) = nearestShootingEnemy(
        view.y, view.x, view.team, dead
      )
      if towerIdx >= 0 and towerL1 <= TowerVision:
        inc hero.inTowerRange
        let (ty, tx) = towerCell(towerIdx)
        let soak = soakL1(view, ty, tx)
        if soak >= 0 and soak < towerL1:
          inc hero.covered
        else:
          inc hero.exposed
      if tick mod SampleStride == 0:
        hero.sampled.add samplePoint(tick, view, region)
      result.heroes[pid] = hero
    if tick < result.openingWindow:
      for team in 0 .. 1:
        if teamLane[team][majorityLane(teamLane[team])] >= 4:
          inc result.teamStackOpening[team]
    runtime.writeActions(actions)
    runtime.step()
    if runtime.fault() != 0:
      raiseRecon("sim_fault after tick " & $tick)
    let afterObs = runtime.observations()
    var after: array[NumHeroes, HeroView]
    for pid in 0 ..< NumHeroes:
      after[pid] = parseView(afterObs[pid])
    var newlyDead: seq[int]
    for i in 0 ..< TowerCount:
      if dead[i]:
        continue
      var nowDead = false
      for view in after:
        if view.visibleTowerDead(i):
          nowDead = true
      if nowDead:
        newlyDead.add i
        dead[i] = true
    for pid in 0 ..< NumHeroes:
      let
        useE = int(actions[pid][5])
        fired = useE == 1 and after[pid].eTimer > views[pid].eTimer
      if useE == 1 and not fired:
        inc result.heroes[pid].eBlocked
      if fired:
        inc result.heroes[pid].eFires
        let region = classifyRegion(
          views[pid].y, views[pid].x, views[pid].team
        )
        let (sy, sx) = Spawns[views[pid].team]
        let nearFount = l1(
          views[pid].y, views[pid].x, sy, sx
        ) <= FountainRadius
        if views[pid].health10 <= 3:
          inc result.heroes[pid].eOnRetreat
        if nearFount:
          inc result.heroes[pid].eOnFountain
        if pid in AssassinPids:
          result.eFires.add SkillFire(
            tick: tick,
            pid: pid,
            health10: views[pid].health10,
            region: regionName(region),
            nearFountain: nearFount
          )
      let towersNow = int(runtime.agentStat(pid, 3))
      if towersNow > prevTowers[pid]:
        var found = -1
        if newlyDead.len > 0:
          found = newlyDead[0]
          newlyDead.delete(0)
        result.towerDeaths.add TowerDeath(
          tick: tick,
          pid: pid,
          towerIndex: found,
          towerTeam:
            if found >= 0: Towers[found].team else: -1,
          towerTier:
            if found >= 0: Towers[found].tier else: -1
        )
        prevTowers[pid] = towersNow
    prevViews = after
    havePrev = true
  result.simTick = int(runtime.tick())
  result.simDigest = runtime.stateDigest()
  result.simAncients[0] = runtime.ancientHealth(0)
  result.simAncients[1] = runtime.ancientHealth(1)
  if runtime.done() != 0:
    result.simEnd = "ancient"
    result.simWinner =
      if runtime.winner() == 0: "radiant"
      elif runtime.winner() == 1: "dire"
      else: $runtime.winner()
  else:
    result.simEnd = "not_done"
    result.simWinner = "none"
  result.simStats = runtime.snapshotStats()
  var mismatch = ""
  if result.simTick != result.hostedTick:
    mismatch = "final_tick hosted=" & $result.hostedTick &
      " sim=" & $result.simTick
  elif result.simTick != result.ticks:
    mismatch = "sim tick " & $result.simTick &
      " != body tick_count " & $result.ticks
  elif result.simWinner != result.hostedWinner:
    mismatch = "winner hosted=" & result.hostedWinner &
      " sim=" & result.simWinner
  elif result.simEnd != result.hostedEnd:
    mismatch = "end_reason hosted=" & result.hostedEnd &
      " sim=" & result.simEnd
  else:
    mismatch = statsEqual(result.hostedStats, result.simStats)
    if mismatch.len == 0:
      for team in 0 .. 1:
        let (haveH, hostedH) = hostedAncient(replay, team)
        if haveH:
          if abs(float(result.simAncients[team]) - hostedH) > 0.51:
            mismatch = "ancient[" & $team & "] hosted=" & $hostedH &
              " sim=" & $result.simAncients[team]
            break
  result.mismatch = mismatch
  result.verified = mismatch.len == 0
  if not result.verified:
    raiseRecon("end-state mismatch: " & mismatch)

proc rate(count, ticks: int): float =
  ## count/ticks or 0.
  if ticks <= 0: 0.0 else: float(count) / float(ticks)

proc reconstructionJson*(rec: Reconstruction): JsonNode =
  ## Serializes one reconstruction. scoring_evidence is always false.
  result = %*{
    "source": "softmax-hosted-replay-reconstruction",
    "scoring_evidence": false,
    "verified": rec.verified,
    "mismatch": rec.mismatch,
    "replay_path": rec.replayPath,
    "wasm_path": rec.wasmPath,
    "wasm_sha256": rec.wasmSha,
    "verified_wasm_hash": rec.wasmSha == ExpectedWasmSha,
    "seed": rec.seed,
    "tick_count": rec.ticks,
    "hosted_final_tick": rec.hostedTick,
    "sim_final_tick": rec.simTick,
    "hosted_winner": rec.hostedWinner,
    "sim_winner": rec.simWinner,
    "hosted_end_reason": rec.hostedEnd,
    "sim_end_reason": rec.simEnd,
    "sim_state_digest": rec.simDigest.int,
    "sim_ancient_healths": [rec.simAncients[0].float, rec.simAncients[1].float],
    "opening_window": rec.openingWindow,
    "positions": "obs unsigned-char x/y after exact pinned resim",
    "health": "obs health*10/max, 0..10"
  }
  var deaths = newJArray()
  for event in rec.towerDeaths:
    deaths.add %*{
      "tick": event.tick,
      "pid": event.pid,
      "role": roleName(event.pid),
      "team": teamName(event.pid),
      "tower_index": event.towerIndex,
      "tower_team": event.towerTeam,
      "tower_tier": event.towerTier
    }
  result["tower_deaths"] = deaths
  var fires = newJArray()
  for event in rec.eFires:
    fires.add %*{
      "tick": event.tick,
      "pid": event.pid,
      "health10": event.health10,
      "region": event.region,
      "near_fountain": event.nearFountain
    }
  result["assassin_e_fires"] = fires
  var heroes = newJArray()
  for hero in rec.heroes:
    var node = %*{
      "pid": hero.pid,
      "team": teamName(hero.pid),
      "role": hero.role,
      "assigned_lane": hero.assigned,
      "deaths_teleport": hero.deaths,
      "e_flags": hero.eFlags,
      "e_fires": hero.eFires,
      "e_blocked": hero.eBlocked,
      "e_on_low_health": hero.eOnRetreat,
      "e_on_fountain": hero.eOnFountain,
      "in_tower_range_rate": rate(hero.inTowerRange, rec.ticks),
      "exposed_rate": rate(hero.exposed, rec.ticks),
      "covered_rate": rate(hero.covered, rec.ticks)
    }
    var opening = newJObject()
    var all = newJObject()
    for i, name in RegionNames:
      opening[name] = %rate(hero.opening[i], rec.openingWindow)
      all[name] = %rate(hero.all[i], rec.ticks)
    node["opening_regions"] = opening
    node["all_regions"] = all
    node["samples"] = %hero.sampled
    heroes.add node
  result["heroes"] = heroes
  var openingTeams = newJArray()
  for team in 0 .. 1:
    var row = newJObject()
    row["team"] = %TeamNames[team]
    var regions = newJObject()
    var sum = 0
    for i in 0 .. 4:
      sum += rec.teamOpening[team][i]
    for i, name in RegionNames:
      regions[name] = %rate(rec.teamOpening[team][i], sum)
    row["opening_occupancy"] = regions
    row["opening_stack_rate"] = %rate(
      rec.teamStackOpening[team], rec.openingWindow
    )
    openingTeams.add row
  result["team_opening"] = openingTeams
  result["sim_agent_stats"] = rec.simStats
