## Exact obs/action comparison of frozen gorynych:v1 vs hosted leaders.
## Reconstruction through the pinned wasm; never a score source.

import
  std/[json, os, strutils],
  observations, replays, runtimes, crunchy,
  baseline

const
  ExpectedWasmSha = "b76a9c4cdcc7e4a47c973d4029737a832e0b678646c6a512f5653d3e98f1b8c8"
  NeutralTile = 5
  ExampleCap = 8
  StatNames = [
    "level", "kills", "deaths", "towers_killed", "creeps_killed",
    "neutrals_killed", "xp", "damage_dealt", "damage_received",
    "healing_dealt", "healing_received"
  ]

type
  CropScan = object
    heroDist: int
    creepDist: int
    heroDy: int
    heroDx: int
    towerDist: int
    creepCount: int
    heroCount: int
  DirKind = enum
    DirHold, DirToward, DirAway, DirSide
  Example = object
    tick, pid: int
    role: string
    why: string
    health10: int
    heroDist, creepDist: int
    actual: array[6, int]
    baseline: array[6, int]
  Bucket = object
    ticks: int
    filterMatch: int
    filterMismatch: int
    base0act2: int
    base2act0: int
    velMatch: int
    fullMatch: int
    actHold: int
    actToward: int
    actAway: int
    actSide: int
    baseHold: int
    baseToward: int
    baseAway: int
    baseSide: int
    baseMoveActHold: int
    baseHoldActMove: int
    bothHold: int
    bothMove: int
  GameReport = object
    path: string
    names: seq[string]
    focal: string
    seat: int
    ticks: int
    verified: bool
    mismatch: string
    winner: string
    seed: int
    all: Bucket
    heroVis: Bucket
    bothVis: Bucket
    creepOnly: Bucket
    noHostile: Bucket
    examples: seq[Example]

proc sha256Hex(data: string): string =
  toHex(sha256(data))

proc sign(v: int): int =
  if v > 0: 1 elif v < 0: -1 else: 0

proc isEnemyHero(team, tileId: int): bool =
  if team == 0: tileId in 11 .. 15 else: tileId in 6 .. 10

proc scanCrop(view: HeroView): CropScan =
  result.heroDist = -1
  result.creepDist = -1
  result.towerDist = -1
  let hostileCreep = if view.team == 0: DireCreepTile else: RadiantCreepTile
  for dy in -VisionRange .. VisionRange:
    for dx in -VisionRange .. VisionRange:
      let tile = view.cropTile(dy, dx)
      if tile < 0:
        continue
      let d = max(abs(dy), abs(dx))
      if isEnemyHero(view.team, tile):
        inc result.heroCount
        if result.heroDist < 0 or d < result.heroDist:
          result.heroDist = d
          result.heroDy = dy
          result.heroDx = dx
      elif tile == hostileCreep:
        inc result.creepCount
        if result.creepDist < 0 or d < result.creepDist:
          result.creepDist = d
      elif tile == TowerTile:
        if result.towerDist < 0 or d < result.towerDist:
          result.towerDist = d

proc velOf(row: openArray[int]): (int, int) =
  ((row[0] - 3) div 3, (row[1] - 3) div 3)

proc classify(dy, dx, heroDy, heroDx: int): DirKind =
  if dy == 0 and dx == 0:
    return DirHold
  let dot = dy * sign(heroDy) + dx * sign(heroDx)
  if dot > 0: DirToward
  elif dot < 0: DirAway
  else: DirSide

proc toInts(row: array[6, uint8]): array[6, int] =
  for i in 0 .. 5:
    result[i] = int(row[i])

proc addExample(rep: var GameReport, tick, pid: int, role, why: string,
                view: HeroView, scan: CropScan,
                actual, base: array[6, int]) =
  if rep.examples.len >= ExampleCap:
    return
  for existing in rep.examples:
    if existing.why == why and existing.pid == pid:
      return
  rep.examples.add Example(
    tick: tick, pid: pid, role: role, why: why,
    health10: view.health10, heroDist: scan.heroDist,
    creepDist: scan.creepDist, actual: actual, baseline: base
  )

proc tally(b: var Bucket, scan: CropScan, actual, base: array[6, int]) =
  inc b.ticks
  if actual[2] == base[2]:
    inc b.filterMatch
  else:
    inc b.filterMismatch
    if base[2] == 0 and actual[2] == 2:
      inc b.base0act2
    elif base[2] == 2 and actual[2] == 0:
      inc b.base2act0
  if actual[0] == base[0] and actual[1] == base[1]:
    inc b.velMatch
  if actual == base:
    inc b.fullMatch
  let
    (ady, adx) = velOf(actual)
    (bdy, bdx) = velOf(base)
    aKind = classify(ady, adx, scan.heroDy, scan.heroDx)
    bKind = classify(bdy, bdx, scan.heroDy, scan.heroDx)
  case aKind
  of DirHold: inc b.actHold
  of DirToward: inc b.actToward
  of DirAway: inc b.actAway
  of DirSide: inc b.actSide
  case bKind
  of DirHold: inc b.baseHold
  of DirToward: inc b.baseToward
  of DirAway: inc b.baseAway
  of DirSide: inc b.baseSide
  if aKind == DirHold and bKind == DirHold:
    inc b.bothHold
  elif aKind == DirHold and bKind != DirHold:
    inc b.baseMoveActHold
  elif aKind != DirHold and bKind == DirHold:
    inc b.baseHoldActMove
  else:
    inc b.bothMove

proc pct(n, d: int): string =
  if d <= 0: "n/a"
  else: formatFloat(100.0 * float(n) / float(d), ffDecimal, 1) & "%"

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
        return "pid " & $pid & " " & name & " hosted=" & $a & " sim=" & $b
  ""

proc verifyEnd(replay: Replay, runtime: MobaRuntime, rep: var GameReport) =
  let hostedTick = replay.resultOf(){"final_tick"}.getInt(-1)
  let simTick = int(runtime.tick())
  var simWinner = "none"
  var simEnd = "not_done"
  if runtime.done() != 0:
    simEnd = "ancient"
    simWinner =
      if runtime.winner() == 0: "radiant"
      elif runtime.winner() == 1: "dire"
      else: $runtime.winner()
  var mismatch = ""
  if simTick != hostedTick:
    mismatch = "final_tick hosted=" & $hostedTick & " sim=" & $simTick
  elif simWinner != hostedWinnerName(replay):
    mismatch = "winner hosted=" & hostedWinnerName(replay) & " sim=" & simWinner
  elif simEnd != replay.resultOf(){"end_reason"}.getStr(""):
    mismatch = "end_reason mismatch"
  else:
    mismatch = statsEqual(replay.resultOf(){"agent_stats"}, snapshotStats(runtime))
    if mismatch.len == 0:
      let node = replay.resultOf(){"ancient_healths"}
      if not node.isNil and node.kind == JArray:
        for team in 0 .. 1:
          if team < node.len:
            let hostedH = node[team].getFloat(0.0)
            let simH = float(runtime.ancientHealth(team))
            if abs(simH - hostedH) > 0.51:
              mismatch = "ancient[" & $team & "] hosted=" & $hostedH &
                " sim=" & $simH
              break
  rep.mismatch = mismatch
  rep.verified = mismatch.len == 0
  if not rep.verified:
    raiseRecon("end-state mismatch: " & mismatch)

proc classifyFocal(name: string): string =
  let n = name.toLowerAscii
  if n.contains("daveey"):
    "daveey"
  elif n.contains("andre") or n.contains("gorynych") or n.contains("auto"):
    "v1"
  elif n.contains("richard"):
    "richard"
  elif n.contains("relh"):
    "relh"
  else:
    name

proc runGame(path, wasmPath: string): seq[GameReport] =
  let
    replayBytes = readFile(path)
    wasmBytes = readFile(wasmPath)
    replay = parseReplay(replayBytes)
    want = replay.header{"sim_wasm_sha256"}.getStr("")
    got = sha256Hex(wasmBytes)
  if got != want or got != ExpectedWasmSha:
    raiseRecon("wasm sha mismatch " & got)
  let names = replay.playerNames()
  var runtime = newRuntime(wasmBytes, int64(replay.seedOf()))
  defer:
    runtime.close()
  result = @[]
  var policies: array[2, GorynychPolicy]
  var reports: array[2, GameReport]
  for seat in 0 .. 1:
    policies[seat] = newGorynychPolicy()
    reports[seat] = GameReport(
      path: path,
      names: names,
      focal: classifyFocal(names[seat]),
      seat: seat,
      ticks: replay.tickCount,
      seed: replay.seedOf(),
      winner: hostedWinnerName(replay)
    )
  for tick in 0 ..< replay.tickCount:
    if runtime.fault() != 0:
      raiseRecon("sim_fault at tick " & $tick)
    if runtime.tick() != int32(tick):
      raiseRecon("sim tick mismatch at " & $tick)
    let obs = runtime.observations()
    var actions: array[NumHeroes, array[6, uint8]]
    for pid in 0 ..< NumHeroes:
      actions[pid] = replay.rowAt(tick, pid)
    for seat in 0 .. 1:
      let pid0 = seat * 5
      for local in 0 .. 4:
        let
          pid = pid0 + local
          view = parseView(obs[pid])
          scan = scanCrop(view)
          actual = toInts(actions[pid])
          base = policies[seat].heroAction(local, obs[pid])
        reports[seat].all.tally(scan, actual, base)
        if scan.heroDist >= 0 and scan.creepDist >= 0:
          reports[seat].bothVis.tally(scan, actual, base)
          if base[2] == 0 and actual[2] == 2:
            reports[seat].addExample(tick, pid, roleName(pid),
              "hero+creep baseline filter 0 actual 2", view, scan, actual, base)
          let (ady, adx) = velOf(actual)
          if ady == 0 and adx == 0 and (actual[0] != base[0] or actual[1] != base[1]):
            reports[seat].addExample(tick, pid, roleName(pid),
              "hero+creep actual hold baseline move", view, scan, actual, base)
        if scan.heroDist >= 0:
          reports[seat].heroVis.tally(scan, actual, base)
          let (ady, adx) = velOf(actual)
          let (bdy, bdx) = velOf(base)
          if classify(ady, adx, scan.heroDy, scan.heroDx) == DirAway and
              classify(bdy, bdx, scan.heroDy, scan.heroDx) != DirAway:
            reports[seat].addExample(tick, pid, roleName(pid),
              "hero vis actual kite-away", view, scan, actual, base)
          if ady == 0 and adx == 0 and (bdy != 0 or bdx != 0) and
              view.health10 > 3:
            reports[seat].addExample(tick, pid, roleName(pid),
              "hero vis actual hold baseline move (not retreat hp)",
              view, scan, actual, base)
        elif scan.creepDist >= 0:
          reports[seat].creepOnly.tally(scan, actual, base)
        else:
          reports[seat].noHostile.tally(scan, actual, base)
    runtime.writeActions(actions)
    runtime.step()
  for seat in 0 .. 1:
    verifyEnd(replay, runtime, reports[seat])
    result.add reports[seat]

proc bucketJson(b: Bucket): JsonNode =
  %*{
    "ticks": b.ticks,
    "filterMatch": b.filterMatch,
    "filterMismatch": b.filterMismatch,
    "filterMatchPct": pct(b.filterMatch, b.ticks),
    "base0act2": b.base0act2,
    "base2act0": b.base2act0,
    "velMatch": b.velMatch,
    "velMatchPct": pct(b.velMatch, b.ticks),
    "fullMatch": b.fullMatch,
    "fullMatchPct": pct(b.fullMatch, b.ticks),
    "actHold": b.actHold,
    "actToward": b.actToward,
    "actAway": b.actAway,
    "actSide": b.actSide,
    "baseHold": b.baseHold,
    "baseToward": b.baseToward,
    "baseAway": b.baseAway,
    "baseSide": b.baseSide,
    "baseMoveActHold": b.baseMoveActHold,
    "baseHoldActMove": b.baseHoldActMove,
    "bothHold": b.bothHold,
    "bothMove": b.bothMove
  }

proc exampleJson(e: Example): JsonNode =
  %*{
    "tick": e.tick,
    "pid": e.pid,
    "role": e.role,
    "why": e.why,
    "health10": e.health10,
    "heroDist": e.heroDist,
    "creepDist": e.creepDist,
    "actual": [e.actual[0], e.actual[1], e.actual[2],
               e.actual[3], e.actual[4], e.actual[5]],
    "baseline": [e.baseline[0], e.baseline[1], e.baseline[2],
                 e.baseline[3], e.baseline[4], e.baseline[5]]
  }

proc reportJson(rep: GameReport): JsonNode =
  var examples = newJArray()
  for e in rep.examples:
    examples.add exampleJson(e)
  %*{
    "scoring_evidence": false,
    "path": rep.path,
    "names": rep.names,
    "focal": rep.focal,
    "seat": rep.seat,
    "ticks": rep.ticks,
    "verified": rep.verified,
    "mismatch": rep.mismatch,
    "winner": rep.winner,
    "seed": rep.seed,
    "all": bucketJson(rep.all),
    "heroVisible": bucketJson(rep.heroVis),
    "heroAndCreep": bucketJson(rep.bothVis),
    "creepOnly": bucketJson(rep.creepOnly),
    "noHostile": bucketJson(rep.noHostile),
    "examples": examples
  }

proc echoBucket(title: string, b: Bucket) =
  echo "  ", title, " ticks=", b.ticks,
    " filterMatch=", pct(b.filterMatch, b.ticks),
    " base0act2=", b.base0act2,
    " base2act0=", b.base2act0,
    " velMatch=", pct(b.velMatch, b.ticks),
    " fullMatch=", pct(b.fullMatch, b.ticks)
  echo "    actual hold/toward/away/side=",
    b.actHold, "/", b.actToward, "/", b.actAway, "/", b.actSide
  echo "    baseline hold/toward/away/side=",
    b.baseHold, "/", b.baseToward, "/", b.baseAway, "/", b.baseSide
  echo "    baseMove-actHold=", b.baseMoveActHold,
    " baseHold-actMove=", b.baseHoldActMove

proc main() =
  let
    root = currentSourcePath().parentDir.parentDir.parentDir
    wasm = root / "research" / "evidence" / "wasm" / "moba_sim.wasm"
    leaderDir = root / "research" / "evidence" / "replays"
    v1Dir = root / "evidence" / "xreq_798c5043-ed36-4776-8f80-158019ec0d90"
  let jobs = [
    leaderDir / "r3730-g4.moba",
    leaderDir / "r3728-g9.moba",
    v1Dir / "ereq_82528dd3-f68f-4ba7-b27a-c3a9abf4a9a6.replay",
    v1Dir / "ereq_9b896a79-6a0e-4ab8-8140-db1f38331610.replay"
  ]
  var all = newJArray()
  for path in jobs:
    echo "=== ", lastPathPart(path), " ==="
    let reports = runGame(path, wasm)
    for rep in reports:
      echo "  focal=", rep.focal, " verified=", rep.verified,
        " names=", rep.names, " seat=", rep.seat,
        " ticks=", rep.ticks, " winner=", rep.winner
      echoBucket("all", rep.all)
      echoBucket("heroVisible", rep.heroVis)
      echoBucket("heroAndCreep", rep.bothVis)
      echoBucket("creepOnly", rep.creepOnly)
      echoBucket("noHostile", rep.noHostile)
      for e in rep.examples:
        echo "  ex tick=", e.tick, " pid=", e.pid, " ", e.role,
          " hp=", e.health10, " heroD=", e.heroDist, " creepD=", e.creepDist,
          " actual=", e.actual, " base=", e.baseline, " ", e.why
      all.add reportJson(rep)
  let outPath = currentSourcePath().parentDir / "compare.json"
  writeFile(outPath, pretty(all) & "\n")
  echo "wrote ", outPath

main()
