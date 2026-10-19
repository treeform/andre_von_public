## Per-player statistics from hosted replays, re-simulated in the pinned
## sim wasm so that every seat's observations, inventories and the true
## levels of nearby enemies (debug_nearby) are available. Rows are grouped
## by how directly a policy controls them:
##   A. decisions  - what the policy pressed and when (attack with a target
##      in reach or into empty air, herbs and the hp they were eaten at,
##      what is held, market presses, exposure next to stronger enemies)
##   B. steered    - what those decisions buy from the world (first tool,
##      kills, gold, level curve, engagements and their level gap)
##   C. outcomes   - lives, deaths, score at life end
## Aggregated per policy name, printed as a markdown table. Replay evidence
## only, never a score.
##
## Build (from this directory):
##   WASMTIME_C_API=$PWD/deps/wasmtime-v48.0.1-aarch64-macos-c-api \
##     nim c -d:release playerstats.nim
## Run:
##   ./playerstats nmmo3_sim.wasm [--tag=v28] <hosted.replay>... > table.md
## A --tag=NAME argument renames the Andre von Auto seats in the replays
## that follow it to "buyan NAME", so two of our versions can share a
## table while the other players pool across both batches.

import
  std/[algorithm, json, math, os, sequtils, sets, strutils, tables],
  runtimes,
  ../replays

const
  ObsSize = 1707
  Rows = 11
  Cols = 15
  TileBytes = 10
  CenterRow = 5
  CenterCol = 7
  Scalars = 1650
  ItemTypes = 17
  KindNames = ["none", "helm", "chest", "legs", "sword", "bow", "tool",
    "earth", "fire", "air", "water", "herb", "ore", "wood", "hilt", "silver",
    "gold"]
  OurSeat = "Andre von Auto"
  # find_target cell order (nmmo3.h ATTACK_*): down, up, right, left.
  BasicReach = [(1, 0), (-1, 0), (0, 1), (0, -1)]
  SwordReach = [(1, -1), (1, 0), (1, 1), (-1, -1), (-1, 0), (-1, 1),
                (-1, 1), (0, 1), (1, 1), (-1, -1), (0, -1), (1, -1)]
  BowReach = [(1, 0), (2, 0), (3, 0), (4, 0), (-1, 0), (-2, 0), (-3, 0), (-4, 0),
              (0, 1), (0, 2), (0, 3), (0, 4), (0, -1), (0, -2), (0, -3), (0, -4)]

type
  Engagement = object
    startTick: int
    length: int
    enemyLevel: int
    ownComb: int
    ranged: bool
    leveled: bool
    initiated: bool         ## our in-reach attack press opened it
    kill: bool
    hpStart: int
    hpEnd: int
    armor: int              ## armor pieces worn at the start
    weapon: bool            ## sword or bow held at the start
    attacks: int
    died: bool              ## the life ended inside it
    herbAfter: bool         ## parted without a kill, then a herb within 30 ticks
    reengaged: bool         ## parted, then a new engagement within 30 ticks
    movedAfter: int         ## chebyshev tiles moved in the 30 ticks after parting
  Life = object
    startTick: int
    endTick: int
    cause: string           ## attack, stagnation, episode-end
    combEnd, profEnd: int
    comb100, prof100, comb300, prof300: int
    maxDist: int            ## chebyshev from spawn, dead-reckoned
    moves: int
    runs: int
    noops: int
    itemKeys: int
    marketTicks: int
    attacksReach: int       ## attack pressed with an enemy in weapon reach
    attacksIdle: int        ## attack pressed into empty air
    kills: int
    exposedTicks: int       ## next to a 2+ level stronger enemy, not attacking
    engagements: seq[Engagement]
    firstItem: OrderedTable[string, int]   ## kind -> life tick first held
    sources: CountTable[string]            ## kind:source
    equips: CountTable[string]
    equipPresses: int
    herbs: int
    herbHp: int             ## sum of hp at herb presses
    herbsInCombat: int
    buyPresses: int
    bought: int
    boughtGold: int         ## sum of gold before each completed buy
    boughtKinds: CountTable[string]
    boughtPrice: int
    sellPresses: int
    sold: int
    goldEarned: int
    goldSpent: int
    hpSum: int
    lowHpTicks: int
    toolTicks, weaponTicks, bareTicks: int
    profUps: int
    firstWeapon: int        ## life tick a sword or bow was first equipped
    firstArmor: int
    firstTool: int
    firstToolPickup: int
    firstKill: int          ## life tick of the first kill
    firstToolAfterOwnKill: bool
    lastKillTick: int
    openWalk, openRun, openAttack, openIdle, openOther, openTicks: int   ## first 30 life ticks
    openEngagements: int
    towardPeer, awayPeer, towardStrong, awayStrong: int   ## moves with an enemy within 4
    expMove, expItem, expIdle, expMarket: int             ## what we did while exposed
    enemyWithin5, peerWithin5, enemyWithin2: int          ## ticks with enemies in view
    onGrass, grassInView, waterInView: int                ## enemies spawn only on grass (nmmo3.h safe_tile)
    adjResp: CountTable[string]                           ## response to an orthogonally adjacent enemy
    attackWeapon: CountTable[string]                      ## in-reach attack presses by weapon and range
    visited: HashSet[(int, int)]                          ## dead-reckoned tiles
  Seat = object
    name: string
    pid: int
    lives: seq[Life]
    live: Life
    worldR, worldC: int
    lastAction: int
    lastAttackReach: bool
    lastTarget: (int, int)  ## obs cell of the enemy the last press could hit
    lastTargetHp: int       ## its hp bucket
    prevInv: array[12, int]
    prevObs: seq[uint8]
    prevGold: int
    prevUi: int
    prevComb: int
    prevProf: int
    inFight: bool
    fight: Engagement
    pendingReset: bool
    partTick: int           ## tick the last no-kill engagement ended, else -1000
    partR, partC: int
    partIndex: int

proc scalar(obs: openArray[uint8], base, i: int): int = int(obs[base + Scalars + i])
proc tile(obs: openArray[uint8], base, r, c, b: int): int =
  int(obs[base + (r * Cols + c) * TileBytes + b])
proc kindOf(id: int): int = id mod ItemTypes
proc tierOf(id: int): int = (if id == 0: 0 else: id div ItemTypes + 1)

proc newLife(tick: int): Life =
  Life(startTick: tick, firstWeapon: -1, firstArmor: -1, firstTool: -1,
       firstToolPickup: -1, firstKill: -1, lastKillTick: -1000, comb100: -1, prof100: -1, comb300: -1, prof300: -1)

proc closeLife(s: var Seat, tick: int, cause: string) =
  if s.inFight:
    if cause == "pending": s.fight.died = true
    s.live.engagements.add(s.fight)
    s.inFight = false
  s.live.endTick = tick
  s.live.cause = cause
  s.lives.add(s.live)

proc seatName(header: JsonNode, replay: Replay, pid: int): string =
  let players = header{"config"}{"players"}
  let seat = pid div max(replay.heroesPerSeat, 1)
  if players.isNil or seat >= players.len:
    return "seat" & $seat
  var name = players[seat]{"name"}.getStr("seat" & $seat)
  let paren = name.find(" (")
  if paren > 0: name = name[0 ..< paren]
  name

proc reachTarget(obs: openArray[uint8], base, heldKind: int): (int, int, int) =
  ## First enemy an attack press would hit (find_target order), as
  ## (row, col, hp bucket); row -1 when nothing is in reach.
  template scan(cells: untyped) =
    for (dr, dc) in cells:
      let r = CenterRow + dr
      let c = CenterCol + dc
      if r >= 0 and r < Rows and c >= 0 and c < Cols and obs.tile(base, r, c, 4) == 2:
        return (r, c, obs.tile(base, r, c, 7))
  if heldKind == 5: scan(BowReach)
  elif heldKind == 4: scan(SwordReach)
  else: scan(BasicReach)
  (-1, -1, 0)

proc processReplay(wasmBytes, path, tag: string, seats: var Table[string, seq[Life]]) =
  let
    replay = loadReplay(path)
    header = replay.header
    seed = uint32(header["config"]["seed"].getBiggestInt() and 0xFFFFFFFF)
    n = replay.numAgents
  var runtime = newRuntime(wasmBytes, seed, n)
  defer:
    close(runtime)
  for pid in 0 ..< n:
    callVoid(runtime, "nmmo_set_obs_clean", [int32(pid), 1'i32])
  var agents = newSeq[Seat](n)
  for pid in 0 ..< n:
    var name = seatName(header, replay, pid)
    if name == OurSeat and tag.len > 0: name = "buyan " & tag
    agents[pid] = Seat(name: name, pid: pid, live: newLife(0), lastAction: 4, partTick: -1000)
  var acts = newSeq[int](n)
  var obs: string
  for tick in 0 ..< replay.tickCount:
    obs = readBytes(runtime, int(uint32(callI32(runtime, "obs_ptr"))), n * ObsSize)
    let obsBytes = cast[seq[uint8]](obs)
    for pid in 0 ..< n:
      var s = addr agents[pid]
      let base = pid * ObsSize
      let hp = obsBytes.scalar(base, 5)
      if s.pendingReset:
        # Attack deaths sit three ticks at hp 0 with the old gear still in
        # the obs (nmmo3.h respawn branch); a stagnation reset respawns at
        # once. Skip the dead ticks and read the cause off the first obs.
        if hp == 0:
          if s.lives.len > 0 and s.lives[^1].cause == "pending":
            s.lives[^1].cause = "attack"
          acts[pid] = action(replay, tick, pid)
          continue
        if s.lives.len > 0 and s.lives[^1].cause == "pending":
          s.lives[^1].cause = "stagnation"
        s.pendingReset = false
        s.live = newLife(tick)
        s.worldR = 0
        s.worldC = 0
        s.lastAction = 4
        s.lastAttackReach = false
        s.prevObs = @[]
        s.inFight = false
        s.partTick = -1000
      let lifeTick = tick - s.live.startTick
      let comb = obsBytes.scalar(base, 1)
      let prof = obsBytes.scalar(base, 7)
      let ui = obsBytes.scalar(base, 8)
      let gold = obsBytes.scalar(base, 11)
      let inCombat = obsBytes.scalar(base, 12) > 0
      let anim = obsBytes.scalar(base, 4)
      if lifeTick == 100:
        s.live.comb100 = comb; s.live.prof100 = prof
      if lifeTick == 300:
        s.live.comb300 = comb; s.live.prof300 = prof
      if lifeTick > 0:
        if prof > s.prevProf: inc s.live.profUps
        if gold > s.prevGold: s.live.goldEarned += gold - s.prevGold
        elif gold < s.prevGold: s.live.goldSpent += s.prevGold - gold
      if s.partTick >= 0 and tick - s.partTick <= 30:
        let moved = max(abs(s.worldR - s.partR), abs(s.worldC - s.partC))
        s.live.engagements[s.partIndex].movedAfter = max(s.live.engagements[s.partIndex].movedAfter, moved)
      s.live.hpSum += hp
      s.live.visited.incl((s.worldR, s.worldC))
      block:
        var near5, peer5, near2 = false
        for r in 0 ..< Rows:
          for c in 0 ..< Cols:
            if obsBytes.tile(base, r, c, 4) != 2 or obsBytes.tile(base, r, c, 8) == 5: continue
            let d = max(abs(r - CenterRow), abs(c - CenterCol))
            if d <= 5:
              near5 = true
              if obsBytes.tile(base, r, c, 6) <= 1: peer5 = true
            if d <= 2: near2 = true
        if near5: inc s.live.enemyWithin5
        if peer5: inc s.live.peerWithin5
        if near2: inc s.live.enemyWithin2
        if obsBytes.tile(base, CenterRow, CenterCol, 1) == 0: inc s.live.onGrass
        for r in 0 ..< Rows:
          for c in 0 ..< Cols:
            let t = obsBytes.tile(base, r, c, 1)
            if t == 0: inc s.live.grassInView
            elif t == 3: inc s.live.waterInView
      if hp < 40: inc s.live.lowHpTicks
      if ui != 0: inc s.live.marketTicks
      # Dead reckoning from the previous action and the fresh anim.
      var walk = s.lastAction
      if walk >= 22 and walk <= 25: walk -= 22
      if walk >= 0 and walk <= 3:
        let (dr, dc) = (case walk
          of 0: (1, 0)
          of 1: (-1, 0)
          of 2: (0, 1)
          else: (0, -1))
        if anim == 1:
          s.worldR += dr; s.worldC += dc
        elif anim == 6:
          s.worldR += 2 * dr; s.worldC += 2 * dc
        s.live.maxDist = max(s.live.maxDist, max(abs(s.worldR), abs(s.worldC)))
      # A kill pays gold in the same step as the killing press.
      var killed = false
      if lifeTick > 0 and s.lastAttackReach and s.prevUi == 0 and ui == 0:
        if gold > s.prevGold:
          killed = true
        elif s.prevGold == 99 and s.lastTargetHp == 0 and
            obsBytes.tile(base, s.lastTarget[0], s.lastTarget[1], 4) != 2:
          killed = true            # gold capped: the low target vanished
      if killed:
        inc s.live.kills
        s.live.lastKillTick = tick
        if s.live.firstKill < 0: s.live.firstKill = lifeTick
        if s.inFight: s.fight.kill = true
      # Inventory changes: first appearance and source.
      var soldNow = false
      for slot in 0 ..< 12:
        let id = obsBytes.scalar(base, 18 + slot)
        if id == 0 and s.prevInv[slot] != 0 and s.prevUi == 4:
          soldNow = true
        if id != 0 and s.prevInv[slot] == 0:
          let kind = KindNames[kindOf(id)] & "t" & $tierOf(id)
          if not s.live.firstItem.hasKey(kind):
            s.live.firstItem[kind] = lifeTick
          if kindOf(id) == 6 and s.live.firstToolPickup < 0:
            s.live.firstToolPickup = lifeTick
            if tick - s.live.lastKillTick <= 3: s.live.firstToolAfterOwnKill = true
          var source = "other"
          if s.prevUi == 2 and gold < s.prevGold:
            source = "bought"
            inc s.live.bought
            s.live.boughtGold += s.prevGold
            s.live.boughtKinds.inc(KindNames[kindOf(id)] & "t" & $tierOf(id))
            s.live.boughtPrice += s.prevGold - gold
          elif s.prevObs.len > 0 and (s.lastAction <= 3 or (s.lastAction >= 22 and s.lastAction <= 25)):
            # Stepped onto a ground item last tick: what lay there?
            var w = s.lastAction
            if w >= 22: w -= 22
            let (dr, dc) = (case w
              of 0: (1, 0)
              of 1: (-1, 0)
              of 2: (0, 1)
              else: (0, -1))
            let steps = (if anim == 6: 2 else: 1)
            let gr = CenterRow + steps * dr
            let gc = CenterCol + steps * dc
            if gr >= 0 and gr < Rows and gc >= 0 and gc < Cols:
              let groundKind = s.prevObs.tile(0, gr, gc, 2)
              if groundKind == 6: source = "loot-pickup"
              elif groundKind in [12, 13, 14, 11, 15, 16, 7, 8, 9, 10]:
                source = "harvest"
          s.live.sources.inc(KindNames[kindOf(id)] & ":" & source)
        s.prevInv[slot] = id
      if soldNow: inc s.live.sold
      # Equipment firsts and what is in hand.
      let held = obsBytes.scalar(base, 16)
      let heldKind = (if held == 0: 0 else: kindOf(held))
      if held != 0:
        if (heldKind == 4 or heldKind == 5) and s.live.firstWeapon < 0:
          s.live.firstWeapon = lifeTick
        if heldKind == 6 and s.live.firstTool < 0:
          s.live.firstTool = lifeTick
      if heldKind == 6: inc s.live.toolTicks
      elif heldKind == 4 or heldKind == 5: inc s.live.weaponTicks
      else: inc s.live.bareTicks
      if s.live.firstArmor < 0 and (obsBytes.scalar(base, 13) != 0 or
          obsBytes.scalar(base, 14) != 0 or obsBytes.scalar(base, 15) != 0):
        s.live.firstArmor = lifeTick
      # Exposure: a 2+ level stronger enemy adjacent (chebyshev 1).
      var strongerAdjacent = false
      for dr in -1 .. 1:
        for dc in -1 .. 1:
          if (dr != 0 or dc != 0) and
              obsBytes.tile(base, CenterRow + dr, CenterCol + dc, 4) == 2 and
              obsBytes.tile(base, CenterRow + dr, CenterCol + dc, 6) >= 1:
            strongerAdjacent = true
      # Action of this tick.
      let a = action(replay, tick, pid)
      acts[pid] = a
      let (tr, tc, thp) = obsBytes.reachTarget(base, heldKind)
      var attackReach = false
      if a <= 3: inc s.live.moves
      elif a >= 22 and a <= 25:
        inc s.live.moves
        inc s.live.runs
      elif a == 4: inc s.live.noops
      elif a == 5 and ui == 0:
        if tr >= 0:
          inc s.live.attacksReach
          attackReach = true
          let td = max(abs(tr - CenterRow), abs(tc - CenterCol))
          s.live.attackWeapon.inc((if heldKind == 5: (if td >= 2: "bow at range" else: "bow point-blank") elif heldKind == 4: "sword" else: "bare/tool"))
        else:
          inc s.live.attacksIdle
      elif a >= 8 and a <= 16 and ui == 0:
        inc s.live.itemKeys
        let id = obsBytes.scalar(base, 18 + (a - 8))
        if id != 0:
          if kindOf(id) == 11:
            inc s.live.herbs
            s.live.herbHp += hp
            if inCombat: inc s.live.herbsInCombat
            if s.partTick >= 0 and tick - s.partTick <= 30:
              s.live.engagements[s.partIndex].herbAfter = true
          else:
            s.live.equips.inc(KindNames[kindOf(id)])
            inc s.live.equipPresses
      elif a == 20 and ui == 0: inc s.live.buyPresses
      elif a == 21 and ui == 0: inc s.live.sellPresses
      if strongerAdjacent and not attackReach: inc s.live.exposedTicks
      # Response to an orthogonally adjacent melee enemy (it hits us next tick
      # unless we leave): by its level bucket, what did we press?
      block:
        var adjR, adjC = -1
        var adjDelta = 0
        for (dr, dc) in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
          let r = CenterRow + dr
          let c = CenterCol + dc
          if obsBytes.tile(base, r, c, 4) == 2 and obsBytes.tile(base, r, c, 8) != 5 and obsBytes.tile(base, r, c, 5) == 0:
            if adjR < 0 or obsBytes.tile(base, r, c, 6) > adjDelta:
              adjR = r; adjC = c; adjDelta = obsBytes.tile(base, r, c, 6)
        if adjR >= 0 and ui == 0:
          var resp = "other"
          if a == 5: resp = "attack"
          elif a <= 3 or (a >= 22 and a <= 25):
            var w = a
            if w >= 22: w -= 22
            let (mr, mc) = (case w
              of 0: (1, 0)
              of 1: (-1, 0)
              of 2: (0, 1)
              else: (0, -1))
            let before = abs(adjR - CenterRow) + abs(adjC - CenterCol)
            let after = abs(adjR - CenterRow - mr) + abs(adjC - CenterCol - mc)
            resp = (if after > before: (if a >= 22: "run away" else: "step away") elif after == before: "step aside" else: "step in")
          elif a >= 8 and a <= 16: resp = "item key"
          elif a == 4: resp = "noop"
          let bucket = (if adjDelta == 0: "peer" elif adjDelta <= 2: "d1-2" else: "d3-4")
          s.live.adjResp.inc(bucket & ": " & resp)
      if strongerAdjacent and not attackReach:
        if a <= 3 or (a >= 22 and a <= 25): inc s.live.expMove
        elif a >= 8 and a <= 16 and ui == 0: inc s.live.expItem
        elif ui != 0 or a == 20 or a == 21: inc s.live.expMarket
        else: inc s.live.expIdle
      # Movement relative to the nearest enemy within 4 tiles.
      if a <= 3 or (a >= 22 and a <= 25):
        var w = a
        if w >= 22: w -= 22
        let (mr, mc) = (case w
          of 0: (1, 0)
          of 1: (-1, 0)
          of 2: (0, 1)
          else: (0, -1))
        var bestD = 99
        var er, ec, edelta = 0
        for r in 0 ..< Rows:
          for c in 0 ..< Cols:
            if obsBytes.tile(base, r, c, 4) != 2: continue
            let d = max(abs(r - CenterRow), abs(c - CenterCol))
            if d < bestD:
              bestD = d; er = r; ec = c; edelta = obsBytes.tile(base, r, c, 6)
        if bestD >= 1 and bestD <= 4:
          let dot = mr * (er - CenterRow) + mc * (ec - CenterCol)
          if dot > 0:
            if edelta >= 1: inc s.live.towardStrong else: inc s.live.towardPeer
          elif dot < 0:
            if edelta >= 1: inc s.live.awayStrong else: inc s.live.awayPeer
      if lifeTick < 30:
        inc s.live.openTicks
        if a <= 3: inc s.live.openWalk
        elif a >= 22 and a <= 25: inc s.live.openRun
        elif attackReach: inc s.live.openAttack
        elif a == 4 or (a == 5 and ui == 0): inc s.live.openIdle
        else: inc s.live.openOther
      # Engagements: in_combat runs, with the nearest enemy's true level.
      if inCombat and not s.inFight:
        s.inFight = true
        s.fight = Engagement(startTick: tick, ownComb: comb, enemyLevel: -1,
                             initiated: s.lastAttackReach, hpStart: hp)
        for slot in 13 .. 15:
          if obsBytes.scalar(base, slot) != 0: inc s.fight.armor
        s.fight.weapon = heldKind == 4 or heldKind == 5
        if lifeTick < 30: inc s.live.openEngagements
        if s.partTick >= 0 and tick - s.partTick <= 30:
          s.live.engagements[s.partIndex].reengaged = true
        let count = int(callI32(runtime, "debug_nearby", [int32(pid), 2'i32]))
        if count > 0:
          let bufPtr = int(uint32(callI32(runtime, "debug_buf_ptr")))
          let raw = readBytes(runtime, bufPtr, count * 5 * 4)
          var bestDist = 99
          for i in 0 ..< count:
            var vals: array[5, int32]
            for j in 0 ..< 5:
              var v: int32
              copyMem(addr v, unsafeAddr raw[(i * 5 + j) * 4], 4)
              vals[j] = v
            let d = max(abs(int(vals[0])), abs(int(vals[1])))
            if d < bestDist:
              bestDist = d
              s.fight.enemyLevel = int(vals[2])
              s.fight.ranged = vals[3] != 0
      if s.inFight:
        inc s.fight.length
        if attackReach: inc s.fight.attacks
        if comb > s.prevComb:
          s.fight.leveled = true
        if not inCombat:
          s.fight.hpEnd = hp
          s.live.engagements.add(s.fight)
          s.inFight = false
          if not s.fight.kill:
            s.partTick = tick
            s.partR = s.worldR
            s.partC = s.worldC
            s.partIndex = s.live.engagements.high
      s.prevGold = gold
      s.prevUi = ui
      s.prevComb = comb
      s.prevProf = prof
      s.lastAction = a
      s.lastAttackReach = attackReach
      s.lastTarget = (tr, tc)
      s.lastTargetHp = thp
      s.live.combEnd = comb
      s.live.profEnd = prof
      s.prevObs = obsBytes[base ..< base + ObsSize]
    writeActions(runtime, acts)
    callVoid(runtime, "nmmo_step")
    let termPtr = int(uint32(callI32(runtime, "term_ptr")))
    let raw = readBytes(runtime, termPtr, n * 4)
    for pid in 0 ..< n:
      if uint8(raw[pid * 4 + 3]) == 0x3f'u8 and uint8(raw[pid * 4 + 2]) == 0x80'u8:
        agents[pid].closeLife(tick + 1, "pending")
        agents[pid].pendingReset = true
  for pid in 0 ..< n:
    agents[pid].closeLife(replay.tickCount, "episode-end")
    seats.mgetOrPut(agents[pid].name, @[]).add(agents[pid].lives)
  if getEnv("PER_SEAT") == "1":
    for pid in 0 ..< n:
      var endedSum, allSum = 0.0
      var endedN, allN = 0
      var lastMin = 0.0
      for l in agents[pid].lives:
        let m = float(min(l.combEnd, l.profEnd))
        allSum += m
        inc allN
        lastMin = m
        if l.cause != "episode-end":
          endedSum += m
          inc endedN
      let meanEnded = (if endedN == 0: 0.0 else: endedSum / float(endedN))
      let meanAll = (if allN == 0: 0.0 else: allSum / float(allN))
      echo "SEAT ", path.extractFilename, " pid ", pid, " ", agents[pid].name,
        " lives ", allN, " ended ", endedN,
        " meanEnded ", formatFloat(meanEnded, ffDecimal, 3),
        " meanAll ", formatFloat(meanAll, ffDecimal, 3),
        " sum ", formatFloat(allSum, ffDecimal, 1),
        " lastMin ", formatFloat(lastMin, ffDecimal, 1)

## Aggregation

proc mean(xs: seq[float]): float =
  if xs.len == 0: 0.0 else: (var t = 0.0; (for x in xs: t += x); t / float(xs.len))

proc median(xs: seq[float]): float =
  if xs.len == 0: return 0.0
  var s = xs
  s.sort()
  s[s.len div 2]

proc fmt(x: float, digits = 1): string = formatFloat(x, ffDecimal, digits)

proc pct(a, b: int): string = fmt(100.0 * float(a) / float(max(b, 1))) & "%"

proc episodes(lives: seq[Life]): int =
  for l in lives:
    if l.startTick == 0: inc result

proc ticks(lives: seq[Life]): int =
  for l in lives: result += l.endTick - l.startTick

proc per100(lives: seq[Life], f: proc(l: Life): int): float =
  var total = 0
  for l in lives: total += f(l)
  100.0 * float(total) / float(max(ticks(lives), 1))

proc perLife(lives: seq[Life], f: proc(l: Life): int): float =
  var total = 0
  for l in lives: total += f(l)
  float(total) / float(max(lives.len, 1))

proc countCause(lives: seq[Life], cause: string): int =
  for l in lives:
    if l.cause == cause: inc result

proc lifeLengths(lives: seq[Life]): seq[float] =
  for l in lives: result.add(float(l.endTick - l.startTick))

proc minsAtEnd(lives: seq[Life]): seq[float] =
  for l in lives: result.add(float(min(l.combEnd, l.profEnd)))

proc combsAtEnd(lives: seq[Life]): seq[float] =
  for l in lives: result.add(float(l.combEnd))

proc profsAtEnd(lives: seq[Life]): seq[float] =
  for l in lives: result.add(float(l.profEnd))

proc earlyAttackDeaths(lives: seq[Life]): (int, int) =
  for l in lives:
    if l.cause == "attack":
      inc result[1]
      if l.endTick - l.startTick < 300: inc result[0]

proc maxDists(lives: seq[Life]): seq[float] =
  for l in lives: result.add(float(l.maxDist))

proc engagementsPerLife(lives: seq[Life]): seq[float] =
  for l in lives: result.add(float(l.engagements.len))

proc engagementLengths(lives: seq[Life]): seq[float] =
  for l in lives:
    for e in l.engagements: result.add(float(e.length))

proc levelGaps(lives: seq[Life]): seq[float] =
  for l in lives:
    for e in l.engagements:
      if e.enemyLevel >= 0: result.add(float(e.enemyLevel - e.ownComb))

proc gapHistogram(lives: seq[Life]): string =
  ## Share of engagements by enemy level minus ours: below, equal, above.
  var below, equal, above = 0
  for l in lives:
    for e in l.engagements:
      if e.enemyLevel < 0: continue
      let gap = e.enemyLevel - e.ownComb
      if gap < 0: inc below
      elif gap == 0: inc equal
      else: inc above
  let total = below + equal + above
  pct(below, total) & " / " & pct(equal, total) & " / " & pct(above, total)

proc engagementFlags(lives: seq[Life]): (int, int, int, int) =
  ## (initiated, killed, leveled, total)
  for l in lives:
    for e in l.engagements:
      inc result[3]
      if e.initiated: inc result[0]
      if e.kill: inc result[1]
      if e.leveled: inc result[2]

proc outcomes(lives: seq[Life]): string =
  ## kill / we died / parted, as shares of engagements.
  var kill, died, parted, total = 0
  for l in lives:
    for e in l.engagements:
      inc total
      if e.kill: inc kill
      elif e.died: inc died
      else: inc parted
  pct(kill, total) & " / " & pct(died, total) & " / " & pct(parted, total)

proc afterParting(lives: seq[Life]): string =
  ## Of engagements parted without a kill (and survived): herb within 30
  ## ticks / re-engaged within 30 ticks / moved 3+ tiles; and hp at parting.
  var herb, again, moved, total = 0
  var hpSum = 0
  for l in lives:
    for e in l.engagements:
      if e.kill or e.died: continue
      inc total
      hpSum += e.hpEnd
      if e.herbAfter: inc herb
      if e.reengaged: inc again
      if e.movedAfter >= 3: inc moved
  pct(herb, total) & " / " & pct(again, total) & " / " & pct(moved, total) & " / hp " & fmt(float(hpSum) / float(max(total, 1)))

proc boughtDetail(lives: seq[Life]): string =
  var ct: CountTable[string]
  var price, count = 0
  for l in lives:
    for k, v in l.boughtKinds: ct.inc(k, v)
    price += l.boughtPrice
    count += l.bought
  ct.sort()
  var parts: seq[string]
  for k, v in ct:
    if parts.len >= 5: break
    parts.add(k & " " & $v)
  "mean price " & fmt(float(price) / float(max(count, 1))) & ": " & parts.join(", ")

proc outcomesByGear(lives: seq[Life]): string =
  ## kill / died / parted shares for engagements started with no gear,
  ## partial gear, and full gear (weapon plus three armor pieces).
  var kill, died, total: array[3, int]
  for l in lives:
    for e in l.engagements:
      let g = (if e.armor == 0 and not e.weapon: 0 elif e.armor == 3 and e.weapon: 2 else: 1)
      inc total[g]
      if e.kill: inc kill[g]
      elif e.died: inc died[g]
  var parts: seq[string]
  for g, name in ["none", "partial", "full"]:
    parts.add(name & " " & $total[g] & ": " & pct(kill[g], total[g]) & " / " & pct(died[g], total[g]))
  parts.join("; ")

proc hpAtFightStart(lives: seq[Life]): seq[float] =
  for l in lives:
    for e in l.engagements: result.add(float(e.hpStart))

proc pressesPerEngagement(lives: seq[Life]): seq[float] =
  for l in lives:
    for e in l.engagements: result.add(float(e.attacks))

proc firsts(lives: seq[Life]): (seq[float], seq[float], seq[float], seq[float]) =
  for l in lives:
    if l.firstToolPickup >= 0: result[0].add(float(l.firstToolPickup))
    if l.firstTool >= 0: result[1].add(float(l.firstTool))
    if l.firstWeapon >= 0: result[2].add(float(l.firstWeapon))
    if l.firstArmor >= 0: result[3].add(float(l.firstArmor))

proc firstKills(lives: seq[Life]): string =
  var ticks: seq[float]
  var own, tools = 0
  for l in lives:
    if l.firstKill >= 0: ticks.add(float(l.firstKill))
    if l.firstToolPickup >= 0:
      inc tools
      if l.firstToolAfterOwnKill: inc own
  fmt(median(ticks), 0) & " (" & pct(ticks.len, lives.len) & " of lives) / " & pct(own, tools)

proc adjacentResponse(lives: seq[Life], bucket: string): string =
  var ct: CountTable[string]
  var total = 0
  for l in lives:
    for k, v in l.adjResp:
      if k.startsWith(bucket & ": "):
        ct.inc(k[bucket.len + 2 .. ^1], v)
        total += v
  ct.sort()
  var parts: seq[string]
  for k, v in ct:
    parts.add(k & " " & pct(v, total))
  $total & " ticks: " & parts.join(", ")

proc opening(lives: seq[Life]): string =
  var walk, run, attack, idle, other, ticks, eng = 0
  for l in lives:
    walk += l.openWalk; run += l.openRun; attack += l.openAttack
    idle += l.openIdle; other += l.openOther; ticks += l.openTicks
    eng += l.openEngagements
  pct(walk, ticks) & " / " & pct(run, ticks) & " / " & pct(attack, ticks) & " / " & pct(idle, ticks) & " / " & pct(other, ticks) & " / " & fmt(float(eng) / float(max(lives.len, 1)), 2)

proc levelsAt(lives: seq[Life], at: int): string =
  var combs, profs: seq[float]
  for l in lives:
    let (c, p) = (if at == 100: (l.comb100, l.prof100) else: (l.comb300, l.prof300))
    if c >= 0:
      combs.add(float(c)); profs.add(float(p))
  fmt(mean(combs)) & " / " & fmt(mean(profs)) & " (" & $combs.len & " lives)"

proc topSources(lives: seq[Life]): string =
  var ct: CountTable[string]
  for l in lives:
    for k, v in l.sources: ct.inc(k, v)
  ct.sort()
  var parts: seq[string]
  for k, v in ct:
    if parts.len >= 6: break
    parts.add(k & " " & $v)
  parts.join(", ")

proc firstItems(lives: seq[Life]): string =
  var ticks: Table[string, seq[float]]
  for l in lives:
    for k, t in l.firstItem: ticks.mgetOrPut(k, @[]).add(float(t))
  var items: seq[(string, float, int)]
  for k, v in ticks:
    items.add((k, median(v), v.len))
  items.sort(proc(x, y: (string, float, int)): int = cmp(x[1], y[1]))
  var parts: seq[string]
  for it in items:
    if it[2] >= max(lives.len div 4, 1) and parts.len < 6:
      parts.add(it[0] & "@" & fmt(it[1], 0))
  parts.join(", ")

proc topEquips(lives: seq[Life]): string =
  var ct: CountTable[string]
  for l in lives:
    for k, v in l.equips: ct.inc(k, v)
  ct.sort()
  var parts: seq[string]
  for k, v in ct:
    if parts.len >= 4: break
    parts.add(k & " " & fmt(float(v) / float(max(lives.len, 1)), 2))
  parts.join(", ")

proc main() =
  if paramCount() < 2:
    quit("usage: playerstats <sim.wasm> [--tag=NAME] <hosted.replay>...", 1)
  let wasmBytes = readFile(paramStr(1))
  var seats: Table[string, seq[Life]]
  var tag = ""
  for i in 2 .. paramCount():
    let arg = paramStr(i)
    if arg.startsWith("--tag="):
      tag = arg[6 .. ^1]
      continue
    try:
      processReplay(wasmBytes, arg, tag, seats)
    except CatchableError as e:
      stderr.writeLine("skip " & arg & ": " & e.msg)
  var names: seq[string]
  for k in seats.keys: names.add(k)
  names.sort()
  # Our columns first.
  var ours, others: seq[string]
  for name in names:
    if name.startsWith("buyan") or name == OurSeat: ours.add(name) else: others.add(name)
  names = ours & others
  var rows: seq[(string, seq[string])]
  proc add(label: string, cells: seq[string]) = rows.add((label, cells))
  proc section(title: string) = rows.add(("**" & title & "**", newSeq[string]()))
  var cells: seq[string]
  template collect(body: untyped) =
    cells = @[]
    for name in names:
      let lives {.inject.} = seats[name]
      cells.add(body)

  section("A. decisions (directly controlled)")
  collect(fmt(per100(lives, proc(l: Life): int = l.moves - l.runs)) & " / " &
    fmt(per100(lives, proc(l: Life): int = l.runs)) & " / " &
    fmt(per100(lives, proc(l: Life): int = l.noops)) & " / " &
    fmt(per100(lives, proc(l: Life): int = l.itemKeys)))
  add("walk / run / noop / item keys per 100 ticks", cells)
  collect(fmt(per100(lives, proc(l: Life): int = l.attacksReach)) & " / " &
    fmt(per100(lives, proc(l: Life): int = l.attacksIdle)))
  add("attack presses per 100 ticks: enemy in reach / empty air", cells)
  collect((var ct: CountTable[string]; var total = 0; (for l in lives: (for k, v in l.attackWeapon: (ct.inc(k, v); total += v))); ct.sort(); var parts: seq[string]; (for k, v in ct: parts.add(k & " " & pct(v, total))); parts.join(", ")))
  add("in-reach attack presses by weapon", cells)
  collect(fmt(mean(pressesPerEngagement(lives))))
  add("attack presses (in reach) per engagement", cells)
  collect((let f = engagementFlags(lives); pct(f[0], f[3])))
  add("engagements opened by our own press", cells)
  collect(fmt(mean(hpAtFightStart(lives))))
  add("hp when an engagement starts (mean)", cells)
  collect(gapHistogram(lives))
  add("engagements vs enemy below / at / above our level", cells)
  collect(outcomes(lives))
  add("engagement outcome: kill / we died / parted", cells)
  collect(outcomesByGear(lives))
  add("engagements by gear at start (count: kill share / died share)", cells)
  collect(afterParting(lives))
  add("after parting: herb within 30 ticks / re-engaged within 30 / moved 3+ tiles / hp at parting", cells)
  collect(fmt(perLife(lives, proc(l: Life): int = l.herbs), 2) & " / " &
    fmt(float(sum(lives.mapIt(it.herbHp))) / float(max(sum(lives.mapIt(it.herbs)), 1))) & " / " &
    pct(sum(lives.mapIt(it.herbsInCombat)), sum(lives.mapIt(it.herbs))))
  add("herbs eaten per life / hp when eaten / share eaten in combat", cells)
  collect(pct(sum(lives.mapIt(it.toolTicks)), ticks(lives)) & " / " &
    pct(sum(lives.mapIt(it.weaponTicks)), ticks(lives)) & " / " &
    pct(sum(lives.mapIt(it.bareTicks)), ticks(lives)))
  add("ticks holding tool / weapon / nothing", cells)
  collect(fmt(perLife(lives, proc(l: Life): int = l.equipPresses)))
  add("equip presses per life", cells)
  collect(fmt(perLife(lives, proc(l: Life): int = l.buyPresses), 2) & " / " &
    fmt(perLife(lives, proc(l: Life): int = l.bought), 2) & " / " &
    fmt(float(sum(lives.mapIt(it.boughtGold))) / float(max(sum(lives.mapIt(it.bought)), 1))))
  add("buy presses / completed buys per life / gold before a buy", cells)
  collect(fmt(perLife(lives, proc(l: Life): int = l.sellPresses), 2) & " / " &
    fmt(perLife(lives, proc(l: Life): int = l.sold), 2))
  add("sell presses / completed sells per life", cells)
  collect(pct(sum(lives.mapIt(it.marketTicks)), ticks(lives)))
  add("ticks spent in market menus", cells)
  collect(fmt(per100(lives, proc(l: Life): int = l.exposedTicks), 2))
  add("ticks per 100 next to a 2+ level stronger enemy without attacking", cells)
  collect((let t = sum(lives.mapIt(it.exposedTicks)); pct(sum(lives.mapIt(it.expMove)), t) & " / " & pct(sum(lives.mapIt(it.expItem)), t) & " / " & pct(sum(lives.mapIt(it.expMarket)), t) & " / " & pct(sum(lives.mapIt(it.expIdle)), t)))
  add("while exposed: moving / item key / market / idle", cells)
  collect(adjacentResponse(lives, "peer"))
  add("response to an orthogonally adjacent melee peer (delta 0)", cells)
  collect(adjacentResponse(lives, "d1-2"))
  add("response to an orthogonally adjacent melee 2-5 levels up (delta 1-2)", cells)
  collect(adjacentResponse(lives, "d3-4"))
  add("response to an orthogonally adjacent melee 6+ levels up (delta 3-4)", cells)
  collect(fmt(per100(lives, proc(l: Life): int = l.towardPeer), 2) & " / " & fmt(per100(lives, proc(l: Life): int = l.awayPeer), 2) & " / " & fmt(per100(lives, proc(l: Life): int = l.towardStrong), 2) & " / " & fmt(per100(lives, proc(l: Life): int = l.awayStrong), 2))
  add("moves per 100 ticks with an enemy within 4: toward peer / away from peer / toward stronger / away from stronger", cells)

  section("B. steered (decisions meet the world)")
  collect((let f = firsts(lives); fmt(median(f[0]), 0) & " / " & fmt(median(f[1]), 0) & " / " &
    fmt(median(f[2]), 0) & " / " & fmt(median(f[3]), 0)))
  add("first tool picked up / tool held / weapon held / armor worn (median life tick)", cells)
  collect((let f = firsts(lives); pct(f[0].len, lives.len) & " / " & pct(f[2].len, lives.len) & " / " & pct(f[3].len, lives.len)))
  add("lives that ever had a tool / weapon / armor", cells)
  collect(opening(lives))
  add("first 30 life ticks: walk / run / attack in reach / idle / other, engagements per life", cells)
  collect(firstKills(lives))
  add("first kill (median life tick, share of lives with one) / first tool that was our own kill's drop", cells)
  collect(fmt(perLife(lives, proc(l: Life): int = l.kills), 2) & " / " &
    fmt(per100(lives, proc(l: Life): int = l.kills), 2))
  add("kills per life / per 100 ticks", cells)
  collect(fmt(per100(lives, proc(l: Life): int = l.goldEarned), 2) & " / " &
    fmt(per100(lives, proc(l: Life): int = l.goldSpent), 2))
  add("gold earned / spent per 100 ticks", cells)
  collect(fmt(mean(engagementsPerLife(lives)), 2) & " / " & fmt(mean(engagementLengths(lives))))
  add("engagements per life / length (ticks)", cells)
  collect(fmt(mean(levelGaps(lives)), 2))
  add("enemy level minus own comb (mean)", cells)
  collect((let f = engagementFlags(lives); pct(f[2], f[3])))
  add("engagements that leveled combat", cells)
  collect(fmt(perLife(lives, proc(l: Life): int = l.profUps), 2))
  add("profession level-ups per life", cells)
  collect(levelsAt(lives, 100))
  add("comb / prof at life tick 100", cells)
  collect(levelsAt(lives, 300))
  add("comb / prof at life tick 300", cells)
  collect(fmt(per100(lives, proc(l: Life): int = l.moves)) & " / " & fmt(mean(maxDists(lives))))
  add("moves per 100 ticks / max distance from spawn", cells)
  collect(fmt(per100(lives, proc(l: Life): int = l.visited.len)))
  add("distinct tiles visited per 100 ticks", cells)
  collect(pct(sum(lives.mapIt(it.enemyWithin5)), ticks(lives)) & " / " & pct(sum(lives.mapIt(it.peerWithin5)), ticks(lives)) & " / " & pct(sum(lives.mapIt(it.enemyWithin2)), ticks(lives)))
  add("ticks with an enemy within 5 / a peer (delta 0-1) within 5 / an enemy within 2", cells)
  collect(pct(sum(lives.mapIt(it.onGrass)), ticks(lives)) & " / " & pct(sum(lives.mapIt(it.grassInView)), ticks(lives) * Rows * Cols) & " / " & pct(sum(lives.mapIt(it.waterInView)), ticks(lives) * Rows * Cols))
  add("ticks standing on grass / grass share of the window / water share (enemies spawn on grass only)", cells)
  collect(fmt(float(sum(lives.mapIt(it.hpSum))) / float(max(ticks(lives), 1))) & " / " &
    pct(sum(lives.mapIt(it.lowHpTicks)), ticks(lives)))
  add("mean hp / share of ticks below 40 hp", cells)

  section("C. outcomes")
  collect($lives.len & " / " & fmt(float(lives.len) / float(max(1, episodes(lives))), 2))
  add("seat-lives analysed / lives per seat-episode", cells)
  collect($countCause(lives, "attack") & " / " & $countCause(lives, "stagnation"))
  add("deaths by attack / stagnation", cells)
  collect((let e = earlyAttackDeaths(lives); $e[0] & " of " & $e[1]))
  add("attack deaths in first 300 ticks", cells)
  collect(fmt(mean(lifeLengths(lives))))
  add("mean life length (ticks)", cells)
  collect(fmt(mean(minsAtEnd(lives)), 2))
  add("mean min(comb,prof) at life end", cells)
  collect(fmt(mean(combsAtEnd(lives))) & " / " & fmt(mean(profsAtEnd(lives))))
  add("mean comb / prof at life end", cells)

  section("D. item detail")
  collect(topSources(lives))
  add("item sources (top 6)", cells)
  collect(firstItems(lives))
  add("first items (kind@median life tick)", cells)
  collect(topEquips(lives))
  add("equip presses per life (top 4)", cells)
  collect(boughtDetail(lives))
  add("bought items (count over all lives)", cells)

  echo "| statistic | " & names.join(" | ") & " |"
  echo "|---|" & "---|".repeat(names.len)
  for r in rows:
    if r[1].len == 0:
      echo "| " & r[0] & " |" & " |".repeat(names.len)
    else:
      echo "| " & r[0] & " | " & r[1].join(" | ") & " |"

main()
