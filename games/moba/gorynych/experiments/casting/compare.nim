## Compare frozen gorynych:v1 skill flags to hosted leader/v1 actions.
## Reconstruction through the pinned wasm; end-state must match before
## any fire count is trusted. Not a score.

import
  std/[json, os, strutils, tables],
  crunchy,
  frozen, observations, replays, runtimes

const
  WasmPath = "../../research/evidence/wasm/moba_sim.wasm"
  ExpectedWasmSha = "b76a9c4cdcc7e4a47c973d4029737a832e0b678646c6a512f5653d3e98f1b8c8"
  RoleNames = ["support", "assassin", "burst", "tank", "carry"]
  ExampleCap = 6

type
  Example* = object
    tick*: int
    pid*: int
    role*: string
    x*: int
    y*: int
    health10*: int
    mana10*: int
    qTimer*: int
    wTimer*: int
    eTimer*: int
    moveModifier*: int
    enemyHero*: int
    creep*: int
    tower*: int
    leaderQ*, leaderW*, leaderE*: int
    baseQ*, baseW*, baseE*: int
    fireQ*, fireW*, fireE*: int
    mode*: string
    note*: string
  RoleRow* = object
    ticks*: int
    leaderQ*, leaderW*, leaderE*: int
    baseQ*, baseW*, baseE*: int
    fireQ*, fireW*, fireE*: int
    skillMatch*: int
    skillDiff*: int
    qLeaderOnly*, qBaseOnly*: int
    wLeaderOnly*, wBaseOnly*: int
    eLeaderOnly*, eBaseOnly*: int
    baseQW*, leaderWDropQ*, wFireDropQ*: int
    baseQE*, leaderEDropQ*, eFireDropQ*: int
    baseWE*, leaderWDropE*: int
    wFireHp*: array[11, int]
    eFireHp*: array[11, int]
    leaderWHp*: array[11, int]
    baseWHp*: array[11, int]
    wFireAbove6*: int
    eFireHpLe3*: int
    eFireHpGt3*: int
    qFireBaseOff*: int
    wFireBaseOff*: int
    eFireBaseOff*: int
  TeamRow* = object
    name*: string
    side*: string
    roles*: array[5, RoleRow]
    examples*: seq[Example]
  GameRow* = object
    path*: string
    ticks*: int
    winner*: string
    verified*: bool
    mismatch*: string
    digest*: uint32
    teams*: array[2, TeamRow]

proc snapshotStats(runtime: MobaRuntime): JsonNode =
  ## 10x11 exported agent stats.
  result = newJArray()
  for pid in 0 ..< NumAgents:
    var row = newJObject()
    for which, name in StatNames:
      row[name] = %int(runtime.agentStat(pid, which))
    result.add row

proc statsMatch(hosted, sim: JsonNode): string =
  ## Empty if every required stat matches.
  if hosted.isNil or hosted.kind != JArray:
    return "hosted agent_stats missing"
  if hosted.len != NumAgents or sim.len != NumAgents:
    return "agent_stats length mismatch"
  for pid in 0 ..< NumAgents:
    for name in StatNames:
      let
        a = hosted[pid]{name}.getInt(high(int))
        b = sim[pid]{name}.getInt(high(int) - 1)
      if a != b:
        return "pid " & $pid & " " & name & " hosted=" & $a & " sim=" & $b
  ""

proc winnerName(replay: Replay): string =
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

proc teamLabel(name: string): string =
  ## Compact policy family for the report.
  let lower = name.toLowerAscii
  if lower.contains("daveey"): "daveey"
  elif lower.contains("andre") or lower.contains("gorynych") or
      lower.contains("auto"): "gorynych-v1"
  elif lower.contains("richard"): "richard"
  elif lower.contains("relh"): "relh"
  else: name

proc addExample(team: var TeamRow, ex: Example) =
  ## Keep a few concrete ticks per note class.
  var same = 0
  for old in team.examples:
    if old.note == ex.note:
      inc same
  if same < ExampleCap:
    team.examples.add ex

proc sha256Hex(data: string): string =
  ## Lower-hex sha256 of data.
  toHex(sha256(data))

proc here(): string =
  ## This experiment directory.
  currentSourcePath().parentDir

proc analyze(replayPath: string): GameRow =
  ## Reconstruct one hosted file and compare skill flags.
  let
    replayBytes = readFile(replayPath)
    wasmBytes = readFile(here() / WasmPath)
    replay = parseReplay(replayBytes)
  doAssert sha256Hex(wasmBytes) == ExpectedWasmSha
  doAssert replay.header{"sim_wasm_sha256"}.getStr("") == ExpectedWasmSha
  result.path = replayPath
  result.ticks = replay.tickCount
  result.winner = winnerName(replay)
  let names = replay.playerNames()
  for team in 0 .. 1:
    let raw =
      if team < names.len: names[team] else: "team" & $team
    result.teams[team].name = raw
    result.teams[team].side = if team == 0: "radiant" else: "dire"
  var runtime = newRuntime(wasmBytes, int64(replay.seedOf()))
  defer:
    runtime.close()
  var policies: array[2, GorynychPolicy]
  for team in 0 .. 1:
    policies[team] = newGorynychPolicy()
  let hostedTick = replay.resultOf(){"final_tick"}.getInt(-1)
  for tick in 0 ..< replay.tickCount:
    if runtime.fault() != 0:
      result.mismatch = "sim_fault at tick " & $tick
      return
    if runtime.tick() != int32(tick):
      result.mismatch = "sim tick mismatch at " & $tick
      return
    let obs = runtime.observations()
    var actions: array[NumAgents, array[6, uint8]]
    for pid in 0 ..< NumAgents:
      actions[pid] = replay.rowAt(tick, pid)
    var before: array[NumAgents, HeroView]
    var issued: array[NumAgents, array[6, int]]
    for team in 0 .. 1:
      for slot in 0 .. 4:
        let pid = team * 5 + slot
        before[pid] = parseView(obs[pid])
        issued[pid] = policies[team].heroAction(slot, obs[pid])
    runtime.writeActions(actions)
    runtime.step()
    if runtime.fault() != 0:
      result.mismatch = "sim_fault after tick " & $tick
      return
    let afterObs = runtime.observations()
    for pid in 0 ..< NumAgents:
      let
        after = parseView(afterObs[pid])
        team = pid div 5
        slot = pid mod 5
        leaderQ = int(actions[pid][3])
        leaderW = int(actions[pid][4])
        leaderE = int(actions[pid][5])
        baseQ = issued[pid][3]
        baseW = issued[pid][4]
        baseE = issued[pid][5]
        fireQ = leaderQ == 1 and after.qTimer > before[pid].qTimer
        fireW = leaderW == 1 and after.wTimer > before[pid].wTimer
        fireE = leaderE == 1 and after.eTimer > before[pid].eTimer
      var row = result.teams[team].roles[slot]
      inc row.ticks
      row.leaderQ += leaderQ
      row.leaderW += leaderW
      row.leaderE += leaderE
      row.baseQ += baseQ
      row.baseW += baseW
      row.baseE += baseE
      if fireQ: inc row.fireQ
      if fireW: inc row.fireW
      if fireE: inc row.fireE
      if leaderQ == baseQ and leaderW == baseW and leaderE == baseE:
        inc row.skillMatch
      else:
        inc row.skillDiff
      if leaderQ == 1 and baseQ == 0: inc row.qLeaderOnly
      if leaderQ == 0 and baseQ == 1: inc row.qBaseOnly
      if leaderW == 1 and baseW == 0: inc row.wLeaderOnly
      if leaderW == 0 and baseW == 1: inc row.wBaseOnly
      if leaderE == 1 and baseE == 0: inc row.eLeaderOnly
      if leaderE == 0 and baseE == 1: inc row.eBaseOnly
      if baseQ == 1 and baseW == 1:
        inc row.baseQW
        if leaderW == 1 and leaderQ == 0:
          inc row.leaderWDropQ
          if fireW: inc row.wFireDropQ
      if baseQ == 1 and baseE == 1:
        inc row.baseQE
        if leaderE == 1 and leaderQ == 0:
          inc row.leaderEDropQ
          if fireE: inc row.eFireDropQ
      if baseW == 1 and baseE == 1:
        inc row.baseWE
        if leaderW == 1 and leaderE == 0:
          inc row.leaderWDropE
      let hp = before[pid].health10
      if hp in 0 .. 10:
        if leaderW == 1: inc row.leaderWHp[hp]
        if baseW == 1: inc row.baseWHp[hp]
        if fireW: inc row.wFireHp[hp]
        if fireE: inc row.eFireHp[hp]
      if fireW and hp > 6: inc row.wFireAbove6
      if fireE and hp <= 3: inc row.eFireHpLe3
      if fireE and hp > 3: inc row.eFireHpGt3
      if fireQ and baseQ == 0: inc row.qFireBaseOff
      if fireW and baseW == 0: inc row.wFireBaseOff
      if fireE and baseE == 0: inc row.eFireBaseOff
      result.teams[team].roles[slot] = row
      var
        enemyHero = 0
        creep = 0
        tower = 0
      for tile in before[pid].crop:
        let t = int(tile)
        if t == TowerTile: inc tower
        elif before[pid].team == 0:
          if t in 11 .. 15: inc enemyHero
          elif t == DireCreepTile: inc creep
        else:
          if t in 6 .. 10: inc enemyHero
          elif t == RadiantCreepTile: inc creep
      var note = ""
      if fireW and baseQ == 1 and baseW == 1 and leaderQ == 0 and leaderW == 1:
        note = "heal-priority-fire"
      elif fireE and baseQ == 1 and baseE == 1 and leaderQ == 0 and leaderE == 1:
        note = "escape-priority-fire"
      elif fireQ and baseQ == 0:
        note = "leader-q-fire-baseline-off"
      elif fireW and baseW == 0:
        note = "leader-w-fire-baseline-off"
      elif fireE and baseE == 0:
        note = "leader-e-fire-baseline-off"
      elif fireW and hp > 6:
        note = "w-fire-healthy"
      if note.len > 0:
        let mode =
          if slot in policies[team].heroes:
            $policies[team].heroes[slot].mode
          else:
            ""
        result.teams[team].addExample Example(
          tick: tick, pid: pid, role: RoleNames[slot],
          x: before[pid].x, y: before[pid].y,
          health10: hp, mana10: before[pid].mana10,
          qTimer: before[pid].qTimer, wTimer: before[pid].wTimer,
          eTimer: before[pid].eTimer, moveModifier: before[pid].moveModifier,
          enemyHero: enemyHero, creep: creep, tower: tower,
          leaderQ: leaderQ, leaderW: leaderW, leaderE: leaderE,
          baseQ: baseQ, baseW: baseW, baseE: baseE,
          fireQ: int(fireQ), fireW: int(fireW), fireE: int(fireE),
          mode: mode, note: note)
  result.digest = runtime.stateDigest()
  let
    simTick = int(runtime.tick())
    simWinner =
      if runtime.winner() == 0: "radiant"
      elif runtime.winner() == 1: "dire"
      else: $runtime.winner()
    hostedStats = replay.resultOf(){"agent_stats"}
    simStats = snapshotStats(runtime)
  if simTick != hostedTick:
    result.mismatch = "final_tick hosted=" & $hostedTick & " sim=" & $simTick
  elif simWinner != result.winner:
    result.mismatch = "winner hosted=" & result.winner & " sim=" & simWinner
  else:
    result.mismatch = statsMatch(hostedStats, simStats)
    if result.mismatch.len == 0:
      let node = replay.resultOf(){"ancient_healths"}
      if not node.isNil and node.kind == JArray:
        for team in 0 .. 1:
          if team < node.len:
            let
              hostedH = node[team].getFloat(0.0)
              simH = float(runtime.ancientHealth(team))
            if abs(simH - hostedH) > 0.51:
              result.mismatch = "ancient[" & $team & "] hosted=" & $hostedH &
                " sim=" & $simH
              break
  result.verified = result.mismatch.len == 0

proc hpArr(a: array[11, int]): JsonNode =
  ## Health-tenth histogram.
  result = newJArray()
  for v in a:
    result.add %v

proc roleJson(row: RoleRow): JsonNode =
  ## One role tally.
  %*{
    "ticks": row.ticks,
    "leader_flags": {"q": row.leaderQ, "w": row.leaderW, "e": row.leaderE},
    "baseline_flags": {"q": row.baseQ, "w": row.baseW, "e": row.baseE},
    "actual_fires": {"q": row.fireQ, "w": row.fireW, "e": row.fireE},
    "skill_match": row.skillMatch,
    "skill_diff": row.skillDiff,
    "q_leader_only": row.qLeaderOnly,
    "q_baseline_only": row.qBaseOnly,
    "w_leader_only": row.wLeaderOnly,
    "w_baseline_only": row.wBaseOnly,
    "e_leader_only": row.eLeaderOnly,
    "e_baseline_only": row.eBaseOnly,
    "baseline_qw": row.baseQW,
    "leader_w_drop_q": row.leaderWDropQ,
    "w_fire_drop_q": row.wFireDropQ,
    "baseline_qe": row.baseQE,
    "leader_e_drop_q": row.leaderEDropQ,
    "e_fire_drop_q": row.eFireDropQ,
    "baseline_we": row.baseWE,
    "leader_w_drop_e": row.leaderWDropE,
    "w_fire_hp": hpArr(row.wFireHp),
    "e_fire_hp": hpArr(row.eFireHp),
    "leader_w_hp": hpArr(row.leaderWHp),
    "baseline_w_hp": hpArr(row.baseWHp),
    "w_fire_above_6": row.wFireAbove6,
    "e_fire_hp_le3": row.eFireHpLe3,
    "e_fire_hp_gt3": row.eFireHpGt3,
    "q_fire_baseline_off": row.qFireBaseOff,
    "w_fire_baseline_off": row.wFireBaseOff,
    "e_fire_baseline_off": row.eFireBaseOff
  }

proc exampleJson(ex: Example): JsonNode =
  ## One concrete tick.
  %*{
    "tick": ex.tick, "pid": ex.pid, "role": ex.role,
    "x": ex.x, "y": ex.y,
    "health10": ex.health10, "mana10": ex.mana10,
    "move_modifier": ex.moveModifier,
    "enemy_hero": ex.enemyHero, "creep": ex.creep, "tower": ex.tower,
    "q_timer": ex.qTimer, "w_timer": ex.wTimer, "e_timer": ex.eTimer,
    "leader": [ex.leaderQ, ex.leaderW, ex.leaderE],
    "baseline": [ex.baseQ, ex.baseW, ex.baseE],
    "fire": [ex.fireQ, ex.fireW, ex.fireE],
    "mode": ex.mode, "note": ex.note
  }

proc gameJson(game: GameRow): JsonNode =
  ## One reconstructed comparison.
  var teams = newJArray()
  for team in game.teams:
    var roles = newJObject()
    for i, row in team.roles:
      roles[RoleNames[i]] = roleJson(row)
    var examples = newJArray()
    for ex in team.examples:
      examples.add exampleJson(ex)
    teams.add %*{
      "name": team.name,
      "family": teamLabel(team.name),
      "side": team.side,
      "roles": roles,
      "examples": examples
    }
  %*{
    "path": game.path,
    "ticks": game.ticks,
    "winner": game.winner,
    "verified": game.verified,
    "mismatch": game.mismatch,
    "digest": int(game.digest),
    "scoring_evidence": false,
    "teams": teams
  }

proc summarize(game: GameRow) =
  ## Human-readable per-game dump.
  echo "GAME ", game.path
  echo "  ticks=", game.ticks, " winner=", game.winner,
    " verified=", game.verified, " mismatch=", game.mismatch
  for team in game.teams:
    echo "  TEAM ", teamLabel(team.name), " (", team.name, " ", team.side, ")"
    for i, row in team.roles:
      echo "    ", RoleNames[i],
        " match=", row.skillMatch, "/", row.ticks,
        " flags Lqwe=", row.leaderQ, "/", row.leaderW, "/", row.leaderE,
        " Bqwe=", row.baseQ, "/", row.baseW, "/", row.baseE,
        " fire qwe=", row.fireQ, "/", row.fireW, "/", row.fireE
      echo "      Q only L/B=", row.qLeaderOnly, "/", row.qBaseOnly,
        " W only L/B=", row.wLeaderOnly, "/", row.wBaseOnly,
        " E only L/B=", row.eLeaderOnly, "/", row.eBaseOnly
      echo "      QW base=", row.baseQW, " leaderWdropQ=", row.leaderWDropQ,
        " Wfire=", row.wFireDropQ,
        " QE base=", row.baseQE, " leaderEdropQ=", row.leaderEDropQ,
        " Efire=", row.eFireDropQ
      echo "      Wfire>6=", row.wFireAbove6,
        " Efire<=3=", row.eFireHpLe3, " Efire>3=", row.eFireHpGt3,
        " fireBaseOff qwe=", row.qFireBaseOff, "/", row.wFireBaseOff, "/",
        row.eFireBaseOff
    for ex in team.examples:
      echo "      ex ", ex.note, " t=", ex.tick, " pid=", ex.pid,
        " hp=", ex.health10, " L=", ex.leaderQ, ex.leaderW, ex.leaderE,
        " B=", ex.baseQ, ex.baseW, ex.baseE,
        " F=", ex.fireQ, ex.fireW, ex.fireE, " mode=", ex.mode

proc main() =
  ## Reconstruct the required daveey/v1 sides and write JSON.
  let
    root = here()
    games = [
      root / "../../research/evidence/replays/r3730-g4.moba",
      root / "../../research/evidence/replays/r3721-g6.moba",
      root / "../../research/evidence/replays/r3728-g9.moba",
      root / "../../research/evidence/replays/r3726-g5.moba",
      root / "../../evidence/xreq_798c5043-ed36-4776-8f80-158019ec0d90/ereq_82528dd3-f68f-4ba7-b27a-c3a9abf4a9a6.replay",
      root / "../../evidence/xreq_798c5043-ed36-4776-8f80-158019ec0d90/ereq_5beeab20-894c-435d-acc9-b1cd22b2793c.replay"
    ]
    wasm = root / WasmPath
  doAssert fileExists(wasm), "missing pinned wasm"
  var all = newJArray()
  for path in games:
    echo "analyzing ", path
    let game = analyze(path)
    summarize(game)
    all.add gameJson(game)
    doAssert game.verified, "unverified reconstruction: " & game.mismatch
  let outPath = root / "evidence" / "compare.json"
  writeFile(outPath, pretty(%*{
    "source": "casting-skill-compare",
    "scoring_evidence": false,
    "games": all
  }) & "\n")
  echo "wrote ", outPath

main()
