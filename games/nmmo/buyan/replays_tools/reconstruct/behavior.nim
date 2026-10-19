## Behaviour extractor: re-simulates a hosted replay in the pinned sim wasm
## and writes one CSV row per tick for the selected seats, pairing the
## situation (decoded from the TRUTHFUL clean observation) with the action
## the seat actually played. On argmax MMONet seats the recorded action is
## the network's preferred action, so the rows are on-policy (situation,
## network decision) samples for distilling a scripted policy.
## Isolation evidence only, never a score.
##
## Build (from this directory):
##   WASMTIME_C_API=$PWD/deps/wasmtime-v48.0.1-aarch64-macos-c-api \
##     nim c -d:release behavior.nim
## Run:
##   ./behavior nmmo3_sim.wasm <hosted.replay> <out.csv> [player-prefix]

import
  std/[json, os, strutils],
  runtimes,
  ../replays

const
  ObsSize = 1707
  Rows = 11
  Cols = 15
  TileBytes = 10
  CenterRow = 5
  CenterCol = 7
  ScalarsOffset = 1650
  EnemyEntity = 2
  PlayerEntity = 1
  DeathAnim = 5
  ItemTypeCount = 17
  ToolItem = 6
  SwordItem = 4
  BowItem = 5
  HerbItem = 11
  HelmItem = 1
  ChestItem = 2
  LegsItem = 3

type Agent = object
  lifeTick: int
  prevAction: int
  pendingReset: bool

proc tile(obs: string, base, r, c, b: int): int =
  int(uint8(obs[base + (r * Cols + c) * TileBytes + b]))

proc scalar(obs: string, base, i: int): int =
  int(uint8(obs[base + ScalarsOffset + i]))

proc passable(obs: string, base, r, c: int): int =
  if r < 0 or r >= Rows or c < 0 or c >= Cols:
    return 0
  if obs.tile(base, r, c, 1) <= 1: 1 else: 0

proc itemKind(id: int): int = id mod ItemTypeCount
proc itemTier(id: int): int = (if id == 0: 0 else: id div ItemTypeCount + 1)

proc seatName(header: JsonNode, replay: Replay, pid: int): string =
  let players = header{"config"}{"players"}
  let seat = pid div max(replay.heroesPerSeat, 1)
  if players.isNil or seat >= players.len:
    return "seat" & $seat
  players[seat]{"name"}.getStr("seat" & $seat)

const Header = "episode,pid,tick,lifeTick,action,prevAction,anim,hp,hpMax," &
  "comb,prof,gold,ui,inCombat,heldKind,heldTier,eqAtk,eqDef,helmTier," &
  "chestTier,legsTier,herbs,invFree,invToolTier,invSwordTier,invBowTier," &
  "nEnemy1,nEnemy2,nEnemy4,e1dr,e1dc,e1dist,e1delta,e1hp,e1anim," &
  "e2dr,e2dc,e2dist,e2delta,nPlayer4,p1dr,p1dc,p1delta," &
  "iKind,iTier,idr,idc,tdr,tdc,tTier,hdr,hdc,rdr,rdc,rKind,rTier," &
  "udr,udc,uKind,uTier,passUp,passDown,passLeft,passRight," &
  "pass2Up,pass2Down,pass2Left,pass2Right," &
  "inv0,inv1,inv2,inv3,inv4,inv5,inv6,inv7,inv8,inv9,inv10,inv11," &
  "eq0,eq1,eq2,eq3,eq4,eq5,eq6,eq7,eq8,eq9,eq10,eq11,element,marketTier," &
  "sellIdx,goal"

proc featureRow(obs: string, base: int, episode: string, pid, tick: int,
                agent: Agent, action: int): string =
  var f: seq[int]
  f.add(pid); f.add(tick); f.add(agent.lifeTick); f.add(action)
  f.add(agent.prevAction)
  f.add(obs.scalar(base, 4))                # anim
  f.add(obs.scalar(base, 5)); f.add(obs.scalar(base, 6))   # hp, hpMax
  let comb = obs.scalar(base, 1)
  let prof = obs.scalar(base, 7)
  f.add(comb); f.add(prof)
  f.add(obs.scalar(base, 11)); f.add(obs.scalar(base, 8))  # gold, ui
  f.add(obs.scalar(base, 12))               # inCombat
  let held = obs.scalar(base, 13 + 3)
  let heldKind = itemKind(held)
  let heldTier = itemTier(held)
  f.add(heldKind); f.add(heldTier)
  f.add(obs.scalar(base, 45)); f.add(obs.scalar(base, 46))
  for slot in 0 ..< 3:
    f.add(itemTier(obs.scalar(base, 13 + slot)))
  var herbs, invFree, invTool, invSword, invBow = 0
  for i in 0 ..< 12:
    let id = obs.scalar(base, 18 + i)
    if id == 0:
      inc invFree
      continue
    case itemKind(id)
    of HerbItem: inc herbs
    of ToolItem: invTool = max(invTool, itemTier(id))
    of SwordItem: invSword = max(invSword, itemTier(id))
    of BowItem: invBow = max(invBow, itemTier(id))
    else: discard
  f.add(herbs); f.add(invFree); f.add(invTool); f.add(invSword); f.add(invBow)
  # Entities.
  var n1, n2, n4, nPlayer4 = 0
  var e1 = (dr: 0, dc: 0, dist: 99, delta: 0, hp: 0, anim: 0)
  var e2 = (dr: 0, dc: 0, dist: 99, delta: 0)
  var p1 = (dr: 0, dc: 0, dist: 99, delta: 0)
  for r in 0 ..< Rows:
    for c in 0 ..< Cols:
      if r == CenterRow and c == CenterCol:
        continue
      let kind = obs.tile(base, r, c, 4)
      if kind == 0:
        continue
      if obs.tile(base, r, c, 8) == DeathAnim:
        continue
      let dr = r - CenterRow
      let dc = c - CenterCol
      let dist = max(abs(dr), abs(dc))
      let delta = obs.tile(base, r, c, 6)
      if kind == EnemyEntity:
        if dist <= 1: inc n1
        if dist <= 2: inc n2
        if dist <= 4: inc n4
        if dist < e1.dist:
          e2 = (e1.dr, e1.dc, e1.dist, e1.delta)
          e1 = (dr, dc, dist, delta, obs.tile(base, r, c, 7),
                obs.tile(base, r, c, 8))
        elif dist < e2.dist:
          e2 = (dr, dc, dist, delta)
      elif kind == PlayerEntity:
        if dist <= 4: inc nPlayer4
        if dist < p1.dist:
          p1 = (dr, dc, dist, delta)
  f.add(n1); f.add(n2); f.add(n4)
  f.add(e1.dr); f.add(e1.dc); f.add(e1.dist); f.add(e1.delta); f.add(e1.hp)
  f.add(e1.anim)
  f.add(e2.dr); f.add(e2.dc); f.add(e2.dist); f.add(e2.delta)
  f.add(nPlayer4); f.add(p1.dr); f.add(p1.dc); f.add(p1.delta)
  # Ground items: nearest any, nearest tool, herb, harvestable resource
  # (tier <= held tool tier), and nearest resource that would level prof
  # (8 * 2^(tier-1) > prof).
  var best = (kind: 0, tier: 0, dr: 0, dc: 0, dist: 99)
  var tool = (dr: 0, dc: 0, tier: 0, dist: 99)
  var herb = (dr: 0, dc: 0, dist: 99)
  var res = (dr: 0, dc: 0, kind: 0, tier: 0, dist: 99)
  var up = (dr: 0, dc: 0, kind: 0, tier: 0, dist: 99)
  for r in 0 ..< Rows:
    for c in 0 ..< Cols:
      if r == CenterRow and c == CenterCol:
        continue
      let kind = obs.tile(base, r, c, 2)
      if kind == 0:
        continue
      let tier = obs.tile(base, r, c, 3) + 1
      let dr = r - CenterRow
      let dc = c - CenterCol
      let dist = abs(dr) + abs(dc)
      if dist < best.dist:
        best = (kind, tier, dr, dc, dist)
      if kind == ToolItem and dist < tool.dist:
        tool = (dr, dc, tier, dist)
      if kind == HerbItem and dist < herb.dist:
        herb = (dr, dc, dist)
      let resource = kind >= 7 and kind <= 16 and kind != HerbItem
      if resource and tier <= heldTier and dist < res.dist:
        res = (dr, dc, kind, tier, dist)
      if resource and 8 * (1 shl (tier - 1)) > prof and dist < up.dist:
        up = (dr, dc, kind, tier, dist)
  f.add(best.kind); f.add(best.tier); f.add(best.dr); f.add(best.dc)
  f.add(tool.dr); f.add(tool.dc); f.add(tool.tier)
  f.add(herb.dr); f.add(herb.dc)
  f.add(res.dr); f.add(res.dc); f.add(res.kind); f.add(res.tier)
  f.add(up.dr); f.add(up.dc); f.add(up.kind); f.add(up.tier)
  f.add(obs.passable(base, CenterRow - 1, CenterCol))
  f.add(obs.passable(base, CenterRow + 1, CenterCol))
  f.add(obs.passable(base, CenterRow, CenterCol - 1))
  f.add(obs.passable(base, CenterRow, CenterCol + 1))
  f.add(obs.passable(base, CenterRow - 2, CenterCol))
  f.add(obs.passable(base, CenterRow + 2, CenterCol))
  f.add(obs.passable(base, CenterRow, CenterCol - 2))
  f.add(obs.passable(base, CenterRow, CenterCol + 2))
  for i in 0 ..< 12:
    f.add(obs.scalar(base, 18 + i))
  for i in 0 ..< 12:
    f.add(obs.scalar(base, 30 + i))
  f.add(obs.scalar(base, 2)); f.add(obs.scalar(base, 9))
  f.add(obs.scalar(base, 10)); f.add(obs.scalar(base, 44))
  var parts = @[episode]
  for v in f:
    parts.add($v)
  parts.join(",")

proc main() =
  if paramCount() < 3:
    quit("usage: behavior <sim.wasm> <hosted.replay> <out.csv> [prefix]", 1)
  let prefix = if paramCount() >= 4: paramStr(4) else: "Andre"
  let
    replay = loadReplay(paramStr(2))
    header = replay.header
    seed = uint32(header["config"]["seed"].getBiggestInt() and 0xFFFFFFFF)
    n = replay.numAgents
    episode = paramStr(2).extractFilename.changeFileExt("")
    wasmBytes = readFile(paramStr(1))
  var runtime = newRuntime(wasmBytes, seed, n)
  defer:
    close(runtime)
  var selected: seq[int]
  for pid in 0 ..< n:
    if seatName(header, replay, pid).startsWith(prefix):
      selected.add(pid)
    callVoid(runtime, "nmmo_set_obs_clean", [int32(pid), 1'i32])
  var agents = newSeq[Agent](n)
  for pid in 0 ..< n:
    agents[pid].prevAction = 4
  var acts = newSeq[int](n)
  var output = open(paramStr(3), fmWrite)
  defer:
    output.close()
  output.writeLine(Header)
  var cleanChecked = false
  for tick in 0 ..< replay.tickCount:
    let obsPtr = int(uint32(callI32(runtime, "obs_ptr")))
    let obs = readBytes(runtime, obsPtr, n * ObsSize)
    if not cleanChecked and tick == 5:
      # Truthful bytes: an empty cell has zeroed entity bytes.
      var stale = 0
      for pid in 0 ..< n:
        for cell in 0 ..< Rows * Cols:
          let base = pid * ObsSize + cell * TileBytes
          if uint8(obs[base + 4]) == 0'u8 and
              (uint8(obs[base + 6]) != 0'u8 or uint8(obs[base + 7]) != 0'u8):
            inc stale
      stderr.writeLine("clean-obs check at tick 5: stale cells " & $stale)
      cleanChecked = true
    for pid in 0 ..< n:
      if agents[pid].pendingReset:
        agents[pid].lifeTick = 0
        agents[pid].prevAction = 4
        agents[pid].pendingReset = false
      acts[pid] = action(replay, tick, pid)
    for pid in selected:
      output.writeLine(featureRow(obs, pid * ObsSize, episode, pid, tick,
                                  agents[pid], acts[pid]))
    writeActions(runtime, acts)
    callVoid(runtime, "nmmo_step")
    let termPtr = int(uint32(callI32(runtime, "term_ptr")))
    let raw = readBytes(runtime, termPtr, n * 4)
    for pid in 0 ..< n:
      agents[pid].prevAction = acts[pid]
      inc agents[pid].lifeTick
      if uint8(raw[pid * 4 + 3]) == 0x3f'u8 and
          uint8(raw[pid * 4 + 2]) == 0x80'u8:
        agents[pid].pendingReset = true
  let digest = cast[uint32](callI32(runtime, "state_digest"))
  let hosted = header["result"]["state_digest"].getBiggestInt()
  if int64(digest) != hosted:
    quit("state_digest mismatch: " & $digest & " vs " & $hosted, 1)
  stderr.writeLine("ok " & episode & " seats " & $selected.len &
    " digest " & $digest)

main()
