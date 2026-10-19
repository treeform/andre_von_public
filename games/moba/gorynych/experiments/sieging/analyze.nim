## Same-state v1 decisions vs hosted leader/v1 actions at live towers.
## Reconstruction through the pinned wasm is not a score.

import
  std/[json, os, strutils, tables],
  crunchy, replays, runtimes

include baseline_lib

const
  ExpectedWasmSha = "b76a9c4cdcc7e4a47c973d4029737a832e0b678646c6a512f5653d3e98f1b8c8"
  DistN = 16
  ExampleCap = 6
  NearCheb = 8
  AttackL1 = 12
  StatNames = [
    "level", "kills", "deaths", "towers_killed", "creeps_killed",
    "neutrals_killed", "xp", "damage_dealt", "damage_received",
    "healing_dealt", "healing_received"
  ]
  RoleNames = ["support", "assassin", "burst", "tank", "carry"]
  GorynychRoot = "/Users/me/p/andre_von_auto/games/moba/gorynych"

type
  Example = object
    tick, pid, cheb, l1, hp: int
    role: string
    wave: bool
    rec, base: array[6, int]
    y, x, ty, tx: int
  DistRow = object
    n: int
    recHold, recToward, recAway, recSide: int
    baseHold, velDiff, fullDiff: int
    wave, noWave: int
    hugHold, rimHold: int
  GameReport = object
    name, path, focal, radiant, dire, winner: string
    ticks: int
    verified: bool
    mismatch: string
    heroCalls, velMatch, fullMatch: int
    nearTicks: int
    v1HoldRecHold, v1HoldRecIn, v1HoldRecOut: int
    v1DiveRecHold, v1DiveRecIn, v1DiveRecOut: int
    v1OutRecStay, v1OutRecHold, v1OutRecIn: int
    recHoldAt: array[DistN, int]
    recHoldL1: array[DistN, int]
    recHoldWaveAt: array[DistN, int]
    recHoldNoWaveAt: array[DistN, int]
    diveHoldAt: array[DistN, int]
    byCheb: array[DistN, DistRow]
    towerTileOffset: CountTable[int]
    deadMemWalk: int
    examples: Table[string, seq[Example]]

proc sha256Hex(data: string): string =
  toHex(sha256(data))

proc velOf(a: array[6, int]): (int, int) =
  ((a[0] - 3) div 3, (a[1] - 3) div 3)

proc asInts(row: array[6, uint8]): array[6, int] =
  for i in 0 .. 5:
    result[i] = int(row[i])

proc cheb(y1, x1, y2, x2: int): int =
  max(abs(y1 - y2), abs(x1 - x2))

proc l1d(y1, x1, y2, x2: int): int =
  abs(y1 - y2) + abs(x1 - x2)

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

proc winnerName(replay: Replay): string =
  let node = replay.resultOf(){"winner"}
  if node.isNil or node.kind == JNull:
    return "draw"
  if node.kind == JInt:
    let value = node.getInt(-1)
    if value == 0: return "radiant"
    if value == 1: return "dire"
    return $value
  node.getStr("")

proc waveOnTower(view: HeroView, ty, tx: int): bool =
  let friendly = friendlyCreepTile(view.team)
  for dy in -visionRange .. visionRange:
    for dx in -visionRange .. visionRange:
      if int(view.crop[(dy + visionRange) * cropWidth +
          (dx + visionRange)]) != friendly:
        continue
      if cheb(view.y + dy, view.x + dx, ty, tx) <= creepEngagedDistance:
        return true
  false

proc soakL1OnTower(view: HeroView, ty, tx: int): int =
  result = -1
  let friendly = friendlyCreepTile(view.team)
  for dy in -visionRange .. visionRange:
    for dx in -visionRange .. visionRange:
      if int(view.crop[(dy + visionRange) * cropWidth +
          (dx + visionRange)]) != friendly:
        continue
      let cy = view.y + dy
      let cx = view.x + dx
      if cheb(cy, cx, ty, tx) > creepEngagedDistance:
        continue
      let d = l1d(cy, cx, ty, tx)
      if result < 0 or d < result:
        result = d

proc addExample(rep: var GameReport, key: string, ex: Example) =
  if key notin rep.examples:
    rep.examples[key] = @[]
  if rep.examples[key].len < ExampleCap:
    rep.examples[key].add ex

proc moveKind(y, x, ty, tx, dy, dx: int): string =
  if dy == 0 and dx == 0:
    return "hold"
  let oldC = cheb(y, x, ty, tx)
  let newC = cheb(y + dy, x + dx, ty, tx)
  if newC < oldC: "toward"
  elif newC > oldC: "away"
  else: "side"

proc analyzeGame(name, path, focalName, wasm: string): GameReport =
  result.name = name
  result.path = path
  result.focal = focalName
  result.examples = initTable[string, seq[Example]]()
  result.towerTileOffset = initCountTable[int]()
  let replay = parseReplay(readFile(path))
  let names = replay.playerNames()
  result.radiant = if names.len > 0: names[0] else: ""
  result.dire = if names.len > 1: names[1] else: ""
  result.ticks = replay.tickCount
  result.winner = winnerName(replay)
  var focalTeam = -1
  if result.radiant == focalName:
    focalTeam = 0
  elif result.dire == focalName:
    focalTeam = 1
  else:
    result.mismatch = "focal " & focalName & " not in " & $names
    return
  let runtime = newRuntime(wasm, int64(replay.seedOf()))
  defer:
    runtime.close()
  var policy = newGorynychPolicy()
  for tick in 0 ..< replay.tickCount:
    if runtime.fault() != 0:
      result.mismatch = "sim_fault at tick " & $tick
      return
    if runtime.tick() != int32(tick):
      result.mismatch = "sim tick mismatch at " & $tick
      return
    let obs = runtime.observations()
    var actions: array[NumHeroes, array[6, uint8]]
    for pid in 0 ..< NumHeroes:
      actions[pid] = replay.rowAt(tick, pid)
    for seat in 0 .. 4:
      let pid = focalTeam * 5 + seat
      inc result.heroCalls
      let view = parseView(obs[pid])
      let intended = policy.heroAction(seat, obs[pid])
      let recorded = asInts(actions[pid])
      var sameVel = intended[0] == recorded[0] and intended[1] == recorded[1]
      var sameFull = true
      for i in 0 .. 5:
        if intended[i] != recorded[i]:
          sameFull = false
      if sameVel:
        inc result.velMatch
      if sameFull:
        inc result.fullMatch
      let (towerIdx, towerCheb) = policy.nearestLiveEnemyTower(view)
      if towerIdx < 0 or towerCheb > NearCheb:
        continue
      inc result.nearTicks
      let ty = int(towers[towerIdx].y)
      let tx = int(towers[towerIdx].x)
      let towerL1 = l1d(view.y, view.x, ty, tx)
      let wave = waveOnTower(view, ty, tx)
      let soak = soakL1OnTower(view, ty, tx)
      let engaged = soak >= 0 and soak < towerL1
      let v1Hold = intended[0] == 3 and intended[1] == 3 and
        view.health10 > retreatEnterHealth
      var v1Branch = "push"
      if view.health10 <= retreatEnterHealth or
          policy.heroes[seat].mode == RetreatMode:
        v1Branch = "retreat"
      elif towerCheb <= siegeStandoff:
        if wave:
          v1Branch = "dive"
        elif towerCheb <= towerVision:
          v1Branch = "out"
        else:
          v1Branch = "hold"
      let (rdy, rdx) = velOf(recorded)
      let (bdy, bdx) = velOf(intended)
      let recKind = moveKind(view.y, view.x, ty, tx, rdy, rdx)
      let baseKind = moveKind(view.y, view.x, ty, tx, bdy, bdx)
      let dIdx = min(towerCheb, DistN - 1)
      let lIdx = min(towerL1, DistN - 1)
      var row = result.byCheb[dIdx]
      inc row.n
      case recKind
      of "hold": inc row.recHold
      of "toward": inc row.recToward
      of "away": inc row.recAway
      else: inc row.recSide
      if baseKind == "hold":
        inc row.baseHold
      if not sameVel:
        inc row.velDiff
      if not sameFull:
        inc row.fullDiff
      if wave: inc row.wave else: inc row.noWave
      if recKind == "hold" and towerCheb <= 1:
        inc row.hugHold
      if recKind == "hold" and towerCheb >= 2 and towerCheb <= towerVision:
        inc row.rimHold
      result.byCheb[dIdx] = row
      if recKind == "hold":
        inc result.recHoldAt[dIdx]
        inc result.recHoldL1[lIdx]
        if wave: inc result.recHoldWaveAt[dIdx]
        else: inc result.recHoldNoWaveAt[dIdx]
      if v1Branch == "dive" and recKind == "hold":
        inc result.diveHoldAt[dIdx]
      let ex = Example(
        tick: tick, pid: pid, cheb: towerCheb, l1: towerL1,
        hp: view.health10, role: RoleNames[view.heroType], wave: wave,
        rec: recorded, base: intended, y: view.y, x: view.x, ty: ty, tx: tx
      )
      if towerCheb == 7 and recKind == "hold" and not sameVel:
        result.addExample("cheb7HoldVelDiff", ex)
      if v1Branch == "hold":
        if recKind == "hold": inc result.v1HoldRecHold
        elif recKind == "toward":
          inc result.v1HoldRecIn
          result.addExample("v1HoldRecIn", ex)
        else:
          inc result.v1HoldRecOut
          result.addExample("v1HoldRecOut", ex)
      elif v1Branch == "dive":
        if recKind == "hold":
          inc result.v1DiveRecHold
          result.addExample("v1DiveRecHold", ex)
        elif recKind == "toward": inc result.v1DiveRecIn
        else:
          inc result.v1DiveRecOut
          result.addExample("v1DiveRecOut", ex)
      elif v1Branch == "out":
        if recKind == "hold":
          inc result.v1OutRecHold
          result.addExample("v1OutRecHold", ex)
        elif recKind == "toward":
          inc result.v1OutRecIn
          result.addExample("v1OutRecIn", ex)
        else:
          inc result.v1OutRecStay
      for dy in -visionRange .. visionRange:
        for dx in -visionRange .. visionRange:
          if view.tile(dy, dx) != towerTile:
            continue
          var best = 99
          for index, t in towers:
            let d = cheb(view.y + dy, view.x + dx, int(t.y), int(t.x))
            if d < best:
              best = d
          result.towerTileOffset.inc best
      if towerCheb <= 1 and recKind == "toward" and
          towerIdx in policy.deadTowers:
        inc result.deadMemWalk
    runtime.writeActions(actions)
    runtime.step()
  result.verified = true
  let hostedTick = replay.resultOf(){"final_tick"}.getInt(-1)
  let simTick = int(runtime.tick())
  if simTick != hostedTick:
    result.verified = false
    result.mismatch = "final_tick hosted=" & $hostedTick & " sim=" & $simTick
  elif winnerName(replay) != (
    if runtime.done() != 0:
      if runtime.winner() == 0: "radiant"
      elif runtime.winner() == 1: "dire"
      else: $runtime.winner()
    else: "none"):
    result.verified = false
    result.mismatch = "winner mismatch sim=" & $runtime.winner()
  else:
    let hostedStats = replay.resultOf(){"agent_stats"}
    result.mismatch = statsEqual(hostedStats, runtime.snapshotStats())
    if result.mismatch.len > 0:
      result.verified = false
    else:
      let node = replay.resultOf(){"ancient_healths"}
      if not node.isNil and node.kind == JArray:
        for team in 0 .. 1:
          if team < node.len:
            let hostedH = node[team].getFloat(0.0)
            let simH = float(runtime.ancientHealth(team))
            if abs(simH - hostedH) > 0.51:
              result.verified = false
              result.mismatch = "ancient[" & $team & "] hosted=" &
                $hostedH & " sim=" & $simH
              break

proc pct(num, den: int): string =
  if den <= 0: "n/a"
  else: formatFloat(100.0 * float(num) / float(den), ffDecimal, 1) & "%"

proc dumpExamples(rep: GameReport, key: string): string =
  if key notin rep.examples or rep.examples[key].len == 0:
    return "  (none)\n"
  result = ""
  for ex in rep.examples[key]:
    result.add "  t=" & $ex.tick & " pid=" & $ex.pid & " " & ex.role &
      " pos=(" & $ex.y & "," & $ex.x & ") tower=(" & $ex.ty & "," &
      $ex.tx & ") cheb=" & $ex.cheb & " l1=" & $ex.l1 & " hp10=" &
      $ex.hp & " wave=" & $ex.wave & " rec=" & $ex.rec & " v1=" &
      $ex.base & "\n"

proc summarize(rep: GameReport): string =
  result = "\n## " & rep.name & "\n"
  result.add "focal=" & rep.focal & " radiant=" & rep.radiant &
    " dire=" & rep.dire & " ticks=" & $rep.ticks & " winner=" &
    rep.winner & " verified=" & $rep.verified
  if rep.mismatch.len > 0:
    result.add " mismatch=" & rep.mismatch
  result.add "\n"
  result.add "heroCalls=" & $rep.heroCalls & " velMatch=" &
    pct(rep.velMatch, rep.heroCalls) & " fullMatch=" &
    pct(rep.fullMatch, rep.heroCalls) & " nearTicks(cheb<=8)=" &
    $rep.nearTicks & "\n"
  result.add "v1-hold: recHold=" & $rep.v1HoldRecHold &
    " recWalkIn=" & $rep.v1HoldRecIn & " recWalkOut=" &
    $rep.v1HoldRecOut & "\n"
  result.add "v1-dive: recHold=" & $rep.v1DiveRecHold &
    " recWalkIn=" & $rep.v1DiveRecIn & " recWalkOut=" &
    $rep.v1DiveRecOut & "\n"
  result.add "v1-out (inside vision, no wave): recHold=" &
    $rep.v1OutRecHold & " recWalkIn=" & $rep.v1OutRecIn &
    " recWalkOut=" & $rep.v1OutRecStay & "\n"
  result.add "recorded holds by chebyshev:\n"
  for d in 0 ..< DistN:
    if rep.recHoldAt[d] > 0:
      result.add "  cheb " & $d & ": hold=" & $rep.recHoldAt[d] &
        " wave=" & $rep.recHoldWaveAt[d] & " nowave=" &
        $rep.recHoldNoWaveAt[d] & "\n"
  result.add "recorded holds by L1:\n"
  for d in 0 ..< DistN:
    if rep.recHoldL1[d] > 0:
      result.add "  l1 " & $d & ": " & $rep.recHoldL1[d] & "\n"
  result.add "v1-dive but recorded hold, by cheb:\n"
  for d in 0 ..< DistN:
    if rep.diveHoldAt[d] > 0:
      result.add "  cheb " & $d & ": " & $rep.diveHoldAt[d] & "\n"
  result.add "near-tower by chebyshev (recorded move vs v1):\n"
  for d in 0 ..< DistN:
    let row = rep.byCheb[d]
    if row.n == 0:
      continue
    result.add "  cheb " & $d & " n=" & $row.n &
      " recHold=" & $row.recHold & " toward=" & $row.recToward &
      " away=" & $row.recAway & " side=" & $row.recSide &
      " v1Hold=" & $row.baseHold & " velDiff=" & $row.velDiff &
      " hugHold=" & $row.hugHold & " rimHold=" & $row.rimHold &
      " wave=" & $row.wave & " nowave=" & $row.noWave & "\n"
  result.add "tower-tile vs truncated static cell offset: " &
    $rep.towerTileOffset & "\n"
  result.add "walk onto remembered-dead tower cell: " &
    $rep.deadMemWalk & "\n"
  result.add "examples v1HoldRecIn (v1 holds at standoff, leader walks in):\n" &
    dumpExamples(rep, "v1HoldRecIn")
  result.add "examples v1DiveRecHold (v1 dives with wave, leader holds):\n" &
    dumpExamples(rep, "v1DiveRecHold")
  result.add "examples v1OutRecHold (v1 leaves vision, leader holds inside):\n" &
    dumpExamples(rep, "v1OutRecHold")
  result.add "examples v1DiveRecOut (v1 dives, leader walks away/side):\n" &
    dumpExamples(rep, "v1DiveRecOut")
  result.add "examples cheb7HoldVelDiff (leader holds at 7, v1 still walks):\n" &
    dumpExamples(rep, "cheb7HoldVelDiff")

proc main() =
  let wasmPath = GorynychRoot / "research" / "evidence" / "wasm" /
    "moba_sim.wasm"
  let wasm = readFile(wasmPath)
  let sha = sha256Hex(wasm)
  doAssert sha == ExpectedWasmSha, "wasm sha " & sha
  echo "wasm ", sha
  let games = [
    ("daveey-radiant-r3730-g4",
     GorynychRoot / "research" / "evidence" / "replays" / "r3730-g4.moba",
     "daveey"),
    ("daveey-dire-r3728-g9",
     GorynychRoot / "research" / "evidence" / "replays" / "r3728-g9.moba",
     "daveey"),
    ("v1-radiant-ereq_82528dd3",
     GorynychRoot / "evidence" /
       "xreq_798c5043-ed36-4776-8f80-158019ec0d90" /
       "ereq_82528dd3-f68f-4ba7-b27a-c3a9abf4a9a6.replay",
     "Andre von Auto"),
    ("v1-dire-ereq_9b896a79",
     GorynychRoot / "evidence" /
       "xreq_798c5043-ed36-4776-8f80-158019ec0d90" /
       "ereq_9b896a79-6a0e-4ab8-8140-db1f38331610.replay",
     "Andre von Auto")
  ]
  var text = "# Sieging geometry comparison\n"
  text.add "scoring_evidence=false. Pinned wasm " & sha & "\n"
  for (name, path, focal) in games:
    echo "analyzing ", name
    let rep = analyzeGame(name, path, focal, wasm)
    let summary = summarize(rep)
    echo summary
    text.add summary
  let outPath = currentSourcePath().parentDir / "evidence-geometry.txt"
  writeFile(outPath, text)
  echo "wrote ", outPath

main()
