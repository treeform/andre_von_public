## Hosted NMMO replay reconstruction: recorded actions only, no scoring.
import
  std/[os, json, strutils],
  crunchy/sha256,
  runtimes,
  ../replays

const
  Source = "softmax-hosted-replay-reconstruction"
  ObsSize = 1707
  SelfOffset = 1650
  SelfBytes = 47
  AnimOff = 4
  UiOff = 8
  InCombatOff = 12
  EquipOff = 13
  EquipSlots = 5
  HeldOff = 16
  InvOff = 18
  InvSlots = 12
  HistoryCap = 20
  ActAttack = 5
  ActWalkHi = 3
  ActRunLo = 22
  ActRunHi = 25
  ToolMod = 17
  ToolKind = 6
  StatCumMin = 0'i32
  StatDeaths = 1'i32
  StatComb = 2'i32
  StatProf = 3'i32
  StatGold = 5'i32
  StatTimeAlive = 6'i32
  StatHp = 7'i32
  HostedWhich = [StatCumMin, StatDeaths, StatComb, StatProf,
    StatGold, StatTimeAlive]
  LimitLegacy =
    "Reconstruction uses the runtime default legacy observation " &
    "layout. Self scalars and sim stats are invariant to clean-obs " &
    "opt-in and are the only observation fields used. This does not " &
    "claim full clean observation equality."
  LimitEntity =
    "Legacy entity bytes can be stale. Nearby enemy liveness is not " &
    "reported from observation bytes. Terminal flags and agent_stat " &
    "HP are authoritative for death and HP."
  LimitAttack =
    "attack_animation means find_target set attack animation before " &
    "target search. It does not prove a target existed, contact, or " &
    "damage."
  LimitMove =
    "walk_fired and run_fired mean movement animation was set after " &
    "destination checks, only on alive, nonterminal, play-mode " &
    "(ui==0) intervals. walk_no_anim and run_no_anim mean no " &
    "matching movement animation, not inferred coordinates."
  LimitHp =
    "net_hp_lost is net HP delta, not raw attack damage; regen and " &
    "healing can offset losses."
  LimitScore =
    "scoring_evidence is false. This output is not scoring evidence " &
    "and contains no score, winner, rank, or local delta."

type
  Stats = object
    cumMin: int
    deaths: int
    comb: int
    prof: int
    gold: int
    timeAlive: int
    hp: int
  SelfSnap = object
    stats: Stats
    scalars: array[SelfBytes, uint8]
  StepRec = object
    pre: SelfSnap
    action: int
    postHp: int
    terminal: bool
    runNoAnim: bool
    attackAnimation: bool
    combat: bool
  DeathRec = object
    tickAfterStep: int
    cause: string
    preHp: int
    preComb: int
    preProf: int
    preGold: int
    preTimeAlive: int
    preEquip: array[EquipSlots, int]
    preInv: array[InvSlots, int]
    lastActions: seq[int]
    hpLossTicks: int
    netHpLost: int
    runFailures: int
    attackAnimation: int
    combatTicks: int
  AgentAcc = object
    hist: array[HistoryCap, StepRec]
    histLen: int
    histNext: int
    preTerm: bool
    timeToFirstTool: int
    actionCounts: array[ActionCount, int]
    aliveTicks: int
    attackIssued: int
    attackAnimation: int
    attackNoAnim: int
    runIssued: int
    runFired: int
    runNoAnim: int
    walkIssued: int
    walkFired: int
    walkNoAnim: int
    failStreak: int
    maxFailStreak: int
    hpLossTicks: int
    netHpLost: int
    combatTicks: int
    nakedTicks: int
    toolHeldTicks: int
    invFullTicks: int
    maxInvOcc: int
    professionGains: int
    combatGains: int
    goldChangeTicks: int
    netGoldChange: int
    invChangeTicks: int
    equipChangeTicks: int
    deaths: seq[DeathRec]
    deathAttack: int
    deathStagnation: int

proc fail(msg: string) {.noReturn, raises: [NmmoReconstructionError].} =
  ## Raise NmmoReconstructionError with msg.
  raise newException(NmmoReconstructionError, msg)

proc requireObject(node: JsonNode, what: string): JsonNode
    {.raises: [NmmoReconstructionError].} =
  ## Return node when it is a JSON object.
  if node.isNil or node.kind != JObject:
    fail(what & " must be a JSON object")
  node

proc requireInt(node: JsonNode, what: string): int
    {.raises: [NmmoReconstructionError].} =
  ## Return a JSON integer as int.
  if node.isNil or node.kind != JInt:
    fail(what & " must be an integer")
  let v = node.getBiggestInt()
  if v < BiggestInt(low(int)) or v > BiggestInt(high(int)):
    fail(what & " is out of int range")
  int(v)

proc requireU32Bits(node: JsonNode, what: string): uint32
    {.raises: [NmmoReconstructionError].} =
  ## Read a JSON int as a uint32 bit pattern.
  if node.isNil or node.kind != JInt:
    fail(what & " must be an integer")
  let v = node.getBiggestInt()
  if v < BiggestInt(low(int32)):
    fail(what & " is below int32 bitpattern range")
  if v > BiggestInt(high(uint32)):
    fail(what & " is above uint32 range")
  if v < 0:
    result = cast[uint32](int32(v))
  else:
    result = uint32(v)

proc maskU32(node: JsonNode, what: string): uint32
    {.raises: [NmmoReconstructionError].} =
  ## Mask a JSON int to a uint32 bit pattern.
  if node.isNil or node.kind != JInt:
    fail(what & " must be an integer")
  cast[uint32](node.getBiggestInt())

proc hexLower(digest: array[32, uint8]): string {.raises: [].} =
  ## Format SHA-256 bytes as 64-char lowercase hex.
  result = newStringOfCap(64)
  for b in digest:
    result.add b.toHex(2).toLowerAscii

proc ptrInt(v: int32): int {.raises: [].} =
  ## Zero-extend a wasm i32 pointer to a host offset.
  int(cast[uint32](v))

proc jU32(v: uint32): JsonNode {.raises: [].} =
  ## Encode uint32 as a non-negative JSON integer.
  newJInt(BiggestInt(v))

proc intsJson(values: openArray[int]): JsonNode {.raises: [].} =
  ## Encode integers as a JSON array.
  result = newJArray()
  for v in values:
    result.add %v

proc isTool(item: int): bool {.raises: [].} =
  ## True when a nonzero item id has tool kind (id % 17 == 6).
  item != 0 and item mod ToolMod == ToolKind

proc isWalk(action: int): bool {.raises: [].} =
  ## True for walk action ids 0..3.
  action in 0 .. ActWalkHi

proc isRun(action: int): bool {.raises: [].} =
  ## True for run action ids 22..25.
  action in ActRunLo .. ActRunHi

proc validPlay(pre: SelfSnap, postTerm: bool): bool {.raises: [].} =
  ## Alive, nonterminal, play-mode (ui==0) interval.
  pre.stats.hp > 0 and not postTerm and pre.scalars[UiOff] == 0'u8

proc invOccupied(pre: SelfSnap): int {.raises: [].} =
  ## Count nonzero inventory slots in a self snapshot.
  for i in 0 ..< InvSlots:
    if pre.scalars[InvOff + i] != 0'u8:
      inc result

proc equipEq(a, b: SelfSnap): bool {.raises: [].} =
  ## True when the five equipment bytes match.
  for i in 0 ..< EquipSlots:
    if a.scalars[EquipOff + i] != b.scalars[EquipOff + i]:
      return false
  true

proc invEq(a, b: SelfSnap): bool {.raises: [].} =
  ## True when the twelve inventory bytes match.
  for i in 0 ..< InvSlots:
    if a.scalars[InvOff + i] != b.scalars[InvOff + i]:
      return false
  true

proc loadHosted(path: string): Replay
    {.raises: [NmmoReconstructionError].} =
  ## Load a hosted replay; map parser/IO errors.
  try:
    result = loadReplay(path)
  except NmmoReplayError as err:
    fail(err.msg)
  except CatchableError as err:
    fail("cannot load replay " & path & ": " & err.msg)

proc replayAction(replay: Replay, tick, agent: int): int
    {.raises: [NmmoReconstructionError].} =
  ## Recorded action id; map parser errors.
  try:
    result = action(replay, tick, agent)
  except NmmoReplayError as err:
    fail(err.msg)
  except CatchableError as err:
    fail("replay action: " & err.msg)

proc readWasm(path: string): string
    {.raises: [NmmoReconstructionError].} =
  ## Read wasm bytes; map IO errors.
  try:
    result = readFile(path)
  except CatchableError as err:
    fail("cannot read wasm " & path & ": " & err.msg)

proc parseHostedStats(node: JsonNode, n: int): seq[array[6, int]]
    {.raises: [NmmoReconstructionError].} =
  ## Parse the six named counters in each hosted final agent record.
  const Keys = ["cum_min_comb_prof", "deaths", "comb_lvl", "prof_lvl",
    "gold", "time_alive"]
  if node.isNil or node.kind != JArray:
    fail("result.agent_stats must be an array")
  if node.len != n:
    fail("result.agent_stats length must equal numAgents")
  result = newSeq[array[6, int]](n)
  for pid in 0 ..< n:
    let row = node[pid]
    if row.isNil or row.kind != JObject:
      fail(
        "result.agent_stats[" & $pid &
        "] must be an object of named counters"
      )
    for j in 0 ..< 6:
      result[pid][j] = requireInt(
        row{Keys[j]},
        "result.agent_stats[" & $pid & "]." & Keys[j]
      )

proc seatName(replay: Replay, seat: int): string {.raises: [].} =
  ## Return config.players[seat].name, or empty if missing.
  let players = replay.header{"config"}{"players"}
  if players.isNil or players.kind != JArray or seat < 0 or
      seat >= players.len:
    return ""
  let node = players[seat]
  if node.isNil or node.kind != JObject:
    return ""
  let name = node{"name"}
  if name.isNil or name.kind != JString:
    return ""
  name.getStr

proc stat(runtime: var Runtime, pid: int, which: int32): int =
  ## Read one agent_stat export for pid.
  int(callI32(runtime, "agent_stat", [int32(pid), which]))

proc readSnap(runtime: var Runtime, obs: string, pid: int): SelfSnap =
  ## Stats via agent_stat plus 47 self scalar bytes from obs.
  let off = pid * ObsSize + SelfOffset
  if off < 0 or off + SelfBytes > obs.len:
    fail("obs too short for pid " & $pid)
  for i in 0 ..< SelfBytes:
    result.scalars[i] = uint8(obs[off + i])
  result.stats.cumMin = stat(runtime, pid, StatCumMin)
  result.stats.deaths = stat(runtime, pid, StatDeaths)
  result.stats.comb = stat(runtime, pid, StatComb)
  result.stats.prof = stat(runtime, pid, StatProf)
  result.stats.gold = stat(runtime, pid, StatGold)
  result.stats.timeAlive = stat(runtime, pid, StatTimeAlive)
  result.stats.hp = stat(runtime, pid, StatHp)

proc readObs(runtime: var Runtime, n: int): string =
  ## Read all agents' obs bytes once.
  let
    p = ptrInt(callI32(runtime, "obs_ptr"))
    want = n * ObsSize
  result = readBytes(runtime, p, want)
  if result.len != want:
    fail("obs length " & $result.len & " want " & $want)

proc readTerms(runtime: var Runtime, n: int): string =
  ## Decode the simulator's float32 terminal flags as one byte per agent.
  let
    p = ptrInt(callI32(runtime, "term_ptr"))
    raw = readBytes(runtime, p, n * 4)
  result = newString(n)
  for index in 0 ..< n:
    var bits = 0'u32
    for byte in 0 ..< 4:
      bits = bits or (uint32(uint8(raw[index * 4 + byte])) shl (byte * 8))
    if bits == 0x3f800000'u32:
      result[index] = char(1)
    elif bits != 0:
      fail("Unexpected nonbinary float32 terminal flag")

proc expectI32(
    runtime: var Runtime, name: string, want: int32, what: string
) =
  ## Require a no-arg i32 export to equal want.
  let got = callI32(runtime, name)
  if got != want:
    fail(what & ": got " & $got & " want " & $want)

proc pushHist(acc: var AgentAcc, rec: StepRec) {.raises: [].} =
  ## Append one step to the fixed-20 ring.
  acc.hist[acc.histNext] = rec
  acc.histNext = (acc.histNext + 1) mod HistoryCap
  if acc.histLen < HistoryCap:
    inc acc.histLen

proc histAt(acc: AgentAcc, k: int): StepRec {.raises: [].} =
  ## Ring record k, 0 oldest.
  var idx = acc.histNext - acc.histLen + k
  if idx < 0:
    idx += HistoryCap
  acc.hist[idx]

proc addDeath(acc: var AgentAcc, tickAfter: int, postHp: int)
    {.raises: [].} =
  ## Record one death from the current ring and post HP.
  var d: DeathRec
  d.tickAfterStep = tickAfter
  if postHp == 0:
    d.cause = "attack"
    inc acc.deathAttack
  else:
    d.cause = "stagnation"
    inc acc.deathStagnation
  if acc.histLen > 0:
    let last = histAt(acc, acc.histLen - 1)
    d.preHp = last.pre.stats.hp
    d.preComb = last.pre.stats.comb
    d.preProf = last.pre.stats.prof
    d.preGold = last.pre.stats.gold
    d.preTimeAlive = last.pre.stats.timeAlive
    for i in 0 ..< EquipSlots:
      d.preEquip[i] = int(last.pre.scalars[EquipOff + i])
    for i in 0 ..< InvSlots:
      d.preInv[i] = int(last.pre.scalars[InvOff + i])
  for k in 0 ..< acc.histLen:
    let rec = histAt(acc, k)
    d.lastActions.add rec.action
    if rec.pre.stats.hp > 0 and rec.postHp < rec.pre.stats.hp:
      inc d.hpLossTicks
      d.netHpLost += rec.pre.stats.hp - rec.postHp
    if rec.runNoAnim:
      inc d.runFailures
    if rec.attackAnimation:
      inc d.attackAnimation
    if rec.combat:
      inc d.combatTicks
  acc.deaths.add d

proc applyTick(
    acc: var AgentAcc,
    pre: SelfSnap,
    action: int,
    post: SelfSnap,
    postTerm: bool,
    tick: int
) {.raises: [].} =
  ## Update one agent from a pre/action/post step.
  let
    preAlive = pre.stats.hp > 0
    play = validPlay(pre, postTerm)
    postAnim = int(post.scalars[AnimOff])
    walkIss = isWalk(action)
    runIss = isRun(action)
    atkIss = action == ActAttack
    walkAnim = postAnim == 1
    runAnim = postAnim == 6
    atkAnim = postAnim == 2 or postAnim == 3 or postAnim == 4
    preCombat = pre.scalars[InCombatOff] != 0'u8
    held = int(pre.scalars[HeldOff])
  inc acc.actionCounts[action]
  if walkIss:
    inc acc.walkIssued
  if runIss:
    inc acc.runIssued
  if atkIss:
    inc acc.attackIssued
  if preAlive:
    inc acc.aliveTicks
    if held == 0:
      inc acc.nakedTicks
    if isTool(held):
      inc acc.toolHeldTicks
    let occ = invOccupied(pre)
    if occ > acc.maxInvOcc:
      acc.maxInvOcc = occ
    if occ == InvSlots:
      inc acc.invFullTicks
    if preCombat:
      inc acc.combatTicks
    if acc.timeToFirstTool < 0 and isTool(held):
      acc.timeToFirstTool = tick
  if play:
    if walkAnim:
      inc acc.walkFired
    if runAnim:
      inc acc.runFired
    if atkAnim:
      inc acc.attackAnimation
    if walkIss and not walkAnim:
      inc acc.walkNoAnim
    if runIss and not runAnim:
      inc acc.runNoAnim
    if atkIss and not atkAnim:
      inc acc.attackNoAnim
  if not preAlive:
    acc.failStreak = 0
  elif walkIss or runIss:
    let success =
      play and ((walkIss and walkAnim) or (runIss and runAnim))
    if success:
      acc.failStreak = 0
    elif play:
      inc acc.failStreak
      if acc.failStreak > acc.maxFailStreak:
        acc.maxFailStreak = acc.failStreak
  else:
    acc.failStreak = 0
  if postTerm:
    acc.failStreak = 0
  if preAlive and post.stats.hp < pre.stats.hp:
    inc acc.hpLossTicks
    acc.netHpLost += pre.stats.hp - post.stats.hp
  if preAlive and not postTerm:
    if post.stats.comb > pre.stats.comb:
      acc.combatGains += post.stats.comb - pre.stats.comb
    if post.stats.prof > pre.stats.prof:
      acc.professionGains += post.stats.prof - pre.stats.prof
  if post.stats.gold != pre.stats.gold:
    inc acc.goldChangeTicks
    acc.netGoldChange += post.stats.gold - pre.stats.gold
  if not equipEq(pre, post):
    inc acc.equipChangeTicks
  if not invEq(pre, post):
    inc acc.invChangeTicks
  if acc.timeToFirstTool < 0 and isTool(int(post.scalars[HeldOff])):
    acc.timeToFirstTool = tick + 1
  var rec: StepRec
  rec.pre = pre
  rec.action = action
  rec.postHp = post.stats.hp
  rec.terminal = postTerm
  rec.runNoAnim = play and runIss and not runAnim
  rec.attackAnimation = play and atkAnim
  rec.combat = preAlive and preCombat
  pushHist(acc, rec)
  let died = post.stats.deaths > pre.stats.deaths
  if died:
    addDeath(acc, tick + 1, post.stats.hp)
  acc.preTerm = postTerm

proc deathJson(d: DeathRec): JsonNode {.raises: [].} =
  ## Encode one death record, including preceding-20 totals.
  result = newJObject()
  result["tick_after_step"] = %d.tickAfterStep
  result["cause"] = %d.cause
  result["pre_hp"] = %d.preHp
  result["pre_comb"] = %d.preComb
  result["pre_prof"] = %d.preProf
  result["pre_gold"] = %d.preGold
  result["pre_time_alive"] = %d.preTimeAlive
  result["pre_equipment"] = intsJson(d.preEquip)
  result["pre_inventory"] = intsJson(d.preInv)
  result["last_actions"] = intsJson(d.lastActions)
  var prec = newJObject()
  prec["hp_loss_ticks"] = %d.hpLossTicks
  prec["net_hp_lost"] = %d.netHpLost
  prec["run_failures"] = %d.runFailures
  prec["attack_animation"] = %d.attackAnimation
  prec["combat_ticks"] = %d.combatTicks
  result["preceding20"] = prec

proc agentJson(
    acc: AgentAcc, pid, seat: int, playerName: string
): JsonNode {.raises: [].} =
  ## Encode one agent's metric summary. No score fields.
  result = newJObject()
  result["pid"] = %pid
  result["seat"] = %seat
  result["player_name"] = %playerName
  result["alive_ticks"] = %acc.aliveTicks
  result["action_histogram"] = intsJson(acc.actionCounts)
  result["attack_issued"] = %acc.attackIssued
  result["attack_animation"] = %acc.attackAnimation
  result["attack_no_anim"] = %acc.attackNoAnim
  result["run_issued"] = %acc.runIssued
  result["run_fired"] = %acc.runFired
  result["run_no_anim"] = %acc.runNoAnim
  result["walk_issued"] = %acc.walkIssued
  result["walk_fired"] = %acc.walkFired
  result["walk_no_anim"] = %acc.walkNoAnim
  result["max_consecutive_failed_moves"] = %acc.maxFailStreak
  result["hp_loss_ticks"] = %acc.hpLossTicks
  result["net_hp_lost"] = %acc.netHpLost
  result["combat_ticks"] = %acc.combatTicks
  result["naked_ticks"] = %acc.nakedTicks
  result["tool_held_ticks"] = %acc.toolHeldTicks
  result["inventory_full_ticks"] = %acc.invFullTicks
  result["max_inventory_occupied"] = %acc.maxInvOcc
  result["profession_gains"] = %acc.professionGains
  result["combat_gains"] = %acc.combatGains
  if acc.timeToFirstTool < 0:
    result["time_to_first_tool_held"] = newJNull()
  else:
    result["time_to_first_tool_held"] = %acc.timeToFirstTool
  result["gold_change_ticks"] = %acc.goldChangeTicks
  result["net_gold_change"] = %acc.netGoldChange
  result["inventory_change_ticks"] = %acc.invChangeTicks
  result["equipment_change_ticks"] = %acc.equipChangeTicks
  var deaths = newJArray()
  for d in acc.deaths:
    deaths.add deathJson(d)
  result["deaths"] = deaths
  var totals = newJObject()
  totals["attack"] = %acc.deathAttack
  totals["stagnation"] = %acc.deathStagnation
  result["death_totals"] = totals

proc limitationsJson(): JsonNode {.raises: [].} =
  ## Fixed limitation strings; not scoring evidence.
  result = newJArray()
  result.add %LimitLegacy
  result.add %LimitEntity
  result.add %LimitAttack
  result.add %LimitMove
  result.add %LimitHp
  result.add %LimitScore

proc writeOutput(path: string, doc: JsonNode)
    {.raises: [NmmoReconstructionError].} =
  ## Write verified JSON only after proof; map IO errors.
  var text: string
  try:
    text = pretty(doc)
  except CatchableError as err:
    fail("cannot encode JSON: " & err.msg)
  try:
    writeFile(path, text)
  except CatchableError as err:
    fail("cannot write " & path & ": " & err.msg)

proc reconstruct(wasmPath, replayPath, outPath: string)
    {.raises: [NmmoReconstructionError].} =
  ## Replay hosted actions, prove digest/stats, then write JSON.
  let
    replay = loadHosted(replayPath)
    header = requireObject(replay.header, "replay header")
    config = requireObject(header{"config"}, "header config")
    resultNode = requireObject(header{"result"}, "header result")
    seed = maskU32(config{"seed"}, "header config.seed")
    hostedDigest = requireU32Bits(
      resultNode{"state_digest"}, "header result.state_digest"
    )
    finalTick = requireInt(
      resultNode{"final_tick"}, "header result.final_tick"
    )
    n = replay.numAgents
    hostedStats = parseHostedStats(resultNode{"agent_stats"}, n)
    shaNode = header{"sim_wasm_sha256"}
  if finalTick != replay.tickCount:
    fail(
      "header result.final_tick " & $finalTick &
      " != replay.tickCount " & $replay.tickCount
    )
  if shaNode.isNil or shaNode.kind != JString:
    fail("header sim_wasm_sha256 must be a string")
  let
    wasmBytes = readWasm(wasmPath)
    wasmSha = hexLower(sha256(wasmBytes))
    wantSha = shaNode.getStr
  if wasmSha != wantSha:
    fail(
      "wasm sha256 mismatch: got " & wasmSha &
      " expected " & wantSha
    )
  var runtime = newRuntime(wasmBytes, seed, n)
  defer:
    close(runtime)
  try:
    expectI32(runtime, "nmmo_fault", 0'i32, "nmmo_fault after init")
    expectI32(runtime, "nmmo_tick", 0'i32, "nmmo_tick after init")
    var
      accs = newSeq[AgentAcc](n)
      acts = newSeq[int](n)
    for pid in 0 ..< n:
      accs[pid].timeToFirstTool = -1
    for tick in 0 ..< replay.tickCount:
      expectI32(
        runtime, "nmmo_tick", int32(tick), "nmmo_tick before step"
      )
      expectI32(
        runtime, "nmmo_fault", 0'i32, "nmmo_fault before step"
      )
      let obs = readObs(runtime, n)
      var pres = newSeq[SelfSnap](n)
      for pid in 0 ..< n:
        pres[pid] = readSnap(runtime, obs, pid)
        acts[pid] = replayAction(replay, tick, pid)
      writeActions(runtime, acts)
      callVoid(runtime, "nmmo_step")
      expectI32(
        runtime, "nmmo_fault", 0'i32, "nmmo_fault after step"
      )
      expectI32(
        runtime, "nmmo_tick", int32(tick + 1), "nmmo_tick after step"
      )
      let
        obs2 = readObs(runtime, n)
        terms2 = readTerms(runtime, n)
      for pid in 0 ..< n:
        let
          post = readSnap(runtime, obs2, pid)
          postTerm = uint8(terms2[pid]) != 0'u8
        applyTick(
          accs[pid], pres[pid], acts[pid], post, postTerm, tick
        )
    expectI32(
      runtime, "nmmo_tick", int32(replay.tickCount), "final nmmo_tick"
    )
    expectI32(runtime, "nmmo_fault", 0'i32, "final nmmo_fault")
    let reconDigest = cast[uint32](callI32(runtime, "state_digest"))
    if reconDigest != hostedDigest:
      fail(
        "state_digest mismatch: reconstructed " & $reconDigest &
        " hosted " & $hostedDigest
      )
    for pid in 0 ..< n:
      for j in 0 ..< 6:
        let got = stat(runtime, pid, HostedWhich[j])
        if got != hostedStats[pid][j]:
          fail(
            "agent " & $pid & " end stat[" & $j & "] mismatch: " &
            "reconstructed " & $got & " hosted " &
            $hostedStats[pid][j]
          )
    var doc = newJObject()
    doc["source"] = %Source
    doc["scoring_evidence"] = %false
    doc["replay_path"] = %replayPath
    doc["wasm_path"] = %wasmPath
    doc["wasm_sha256"] = %wasmSha
    doc["verified_wasm_hash"] = %true
    doc["hosted_state_digest"] = jU32(hostedDigest)
    doc["reconstructed_state_digest"] = jU32(reconDigest)
    doc["verified_state_digest"] = %true
    doc["verified_end_stats"] = %true
    doc["tick_count"] = %replay.tickCount
    var agents = newJArray()
    let h = replay.heroesPerSeat
    for pid in 0 ..< n:
      let seat = pid div h
      agents.add agentJson(
        accs[pid], pid, seat, seatName(replay, seat)
      )
    doc["agents"] = agents
    doc["limitations"] = limitationsJson()
    writeOutput(outPath, doc)
  except NmmoReconstructionError as error:
    raise error
  except CatchableError as err:
    fail(err.msg)

proc main() =
  ## CLI entry. Reconstruction errors print and exit 1.
  if paramCount() != 3:
    stderr.writeLine(
      "usage: reconstruct <wasm> <hosted.replay> <output.json>"
    )
    quit(1)
  try:
    reconstruct(paramStr(1), paramStr(2), paramStr(3))
  except NmmoReconstructionError as err:
    stderr.writeLine(err.msg)
    quit(1)
  except CatchableError as err:
    stderr.writeLine(err.msg)
    quit(1)

main()
