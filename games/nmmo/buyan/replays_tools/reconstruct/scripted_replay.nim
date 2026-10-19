## Branch replay: re-simulates a hosted replay in the pinned sim wasm and
## drives our own scripted Mind (../../scripted.nim, seed 0 like the hosted
## runner, index = agent pid) over the Andre von Auto seats' clean
## observations. Agreement between the Mind's action and the recorded one
## proves the reconstruction; then every hosted tick of ours carries a
## decision branch, which playerstats cannot see. Prints per-phase branch
## histograms (no tool yet / tool but no weapon held yet / later) and the
## branch mix of the 20 ticks before each attack death. Evidence only.
##
## Build (from this directory):
##   WASMTIME_C_API=$PWD/deps/wasmtime-v48.0.1-aarch64-macos-c-api \
##     nim c -d:release scripted_replay.nim
## Run:
##   ./scripted_replay nmmo3_sim.wasm <hosted.replay>...

import
  std/[algorithm, json, os, strutils, tables],
  runtimes,
  ../replays,
  ../../scripted, ../../mmonet

## Divergence against the network (NET_WEIGHTS=<nmmo3_weights.bin>): the
## MMONet port sees the same observations as our Mind; its argmax action
## is classified and cross-tabulated with our decision branch, overall and
## in the 20 ticks before our attack deaths.
var
  netWeightsPath = getEnv("NET_WEIGHTS")
  netBranch: CountTable[string]      ## "branch|netclass"
  netBranchTotal: CountTable[string] ## branch
  netDeath: CountTable[string]
  netDeathTotal = 0
  netAgree: CountTable[string]
  recentNet = newSeq[seq[string]](16)

proc actionClass(a: int, obsBytes: seq[uint8], base: int): string =
  ## walk/run toward or away from the nearest enemy, attack, noop, item,
  ## market.
  if a == 5: return "attack"
  if a == 4: return "noop"
  if a >= 8 and a <= 16: return "item"
  if a == 20 or a == 21: return "market"
  if a <= 3 or (a >= 22 and a <= 25):
    var w = a
    if w >= 22: w -= 22
    let (mr, mc) = (case w
      of 0: (1, 0)
      of 1: (-1, 0)
      of 2: (0, 1)
      else: (0, -1))
    var best = 99
    var er, ec = 0
    for r in 0 ..< 11:
      for c in 0 ..< 15:
        let t = base + (r * 15 + c) * 10
        if obsBytes[t + 4] != 2'u8 or obsBytes[t + 8] == 5'u8: continue
        let d = max(abs(r - 5), abs(c - 7))
        if d < best:
          best = d; er = r; ec = c
    let kind = (if a >= 22: "run" else: "walk")
    if best > 5: return kind & " (no enemy near)"
    let dot = mr * (er - 5) + mc * (ec - 7)
    if dot > 0: return kind & " toward enemy"
    if dot < 0: return kind & " away from enemy"
    return kind & " aside"
  "other"

const
  ObsSize = 1707
  Scalars = 1650
  OurSeat = "Andre von Auto"

proc seatName(header: JsonNode, replay: Replay, pid: int): string =
  let players = header{"config"}{"players"}
  let seat = pid div max(replay.heroesPerSeat, 1)
  if players.isNil or seat >= players.len:
    return "seat" & $seat
  var name = players[seat]{"name"}.getStr("seat" & $seat)
  let paren = name.find(" (")
  if paren > 0: name = name[0 ..< paren]
  name

type Phase = enum
  NoTool, ToolNoWeapon, Later

var
  agree, total = 0
  phaseTicks: array[Phase, int]
  phaseBranches: array[Phase, CountTable[string]]
  deathBranches: CountTable[string]
  deaths = 0
  disagreeBranches: CountTable[string]
  wanderContext: CountTable[string]
  wanderTicks = 0
  toolWander: CountTable[string]
  toolWanderTicks = 0
  deathContext: CountTable[string]
  highComb: CountTable[string]
  highCombTicks = 0
  lastContext = newSeq[string](16)
  pendingDeath = newSeq[string](16)
  killerType, killerBranch, killerHp: CountTable[string]
  attackDeaths, stagnations = 0
  traces = newSeq[seq[string]](16)
  examples = 0
  # Stagnation context: the last 300 ticks before a stagnation reset,
  # classed by the best enemy in view (duel margin from the same model
  # as scripted.nim) and by our branch while a fightable one was in view.
  stagWindow = newSeq[seq[string]](16)
  stagBranchWindow = newSeq[seq[string]](16)
  stagClass, stagBranch, stagBinding: CountTable[string]
  stagTicks, stagFightableTicks = 0
  lifeTicks = newSeq[int](16)
  lastComb = newSeq[int](16)
  lastProf = newSeq[int](16)
  earlyDeath, deathByLifeTick, stagByComb: CountTable[string]
  lateNoTool: CountTable[string]      ## lives past tick 400 with no tool yet: branch and nearest enemy
  lateNoToolTicks = 0
  fleeDest: CountTable[string]        ## where a flee lands relative to shooters in view
  fleeDestTicks = 0
  lastFleeDest = newSeq[string](16)
  fleeDeathDest: CountTable[string]
  lifeBranches = newSeq[CountTable[string]](16)
  lifeToolTicks = newSeq[int](16)
  lifeResourceTicks = newSeq[int](16)
  lifeHeldTool = newSeq[int](16)
  prevWindow = newSeq[seq[uint8]](16)
  prevMoveKey = newSeq[string](16)
  stuck: CountTable[string]
  moveTicks = 0
  flowStart: CountTable[string]
  flowStarts = 0
  pauseCtx: CountTable[string]
  pauseTicks = 0
  capShooter: CountTable[string]
  capShooterTicks = 0
  gemCtx: CountTable[string]
  gemTicks = 0
  cornerCtx: CountTable[string]
  cornerTicks = 0
  trueLevel: CountTable[string]      ## true enemy levels near us (debug_nearby) by comb band and branch
  trueLevelTicks = 0
  delta0Pay: CountTable[string]      ## delta-0 melee in view: share whose true level >= comb, by comb band

proc processReplay(wasmBytes, path: string) =
  for pid in 0 ..< 16:
    lifeTicks[pid] = 0
    lifeBranches[pid] = initCountTable[string]()
    lifeToolTicks[pid] = 0
    lifeResourceTicks[pid] = 0
    lifeHeldTool[pid] = 0
    stagWindow[pid] = @[]
    stagBranchWindow[pid] = @[]
    prevMoveKey[pid] = ""
    lastFleeDest[pid] = ""
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
  var ours = newSeq[bool](n)
  var minds = newSeq[Mind](n)
  var brains = newSeq[Brain](n)
  var weightsLoaded = false
  var weights: Weights
  if netWeightsPath.len > 0:
    weights = loadWeights(netWeightsPath)
    weightsLoaded = true
  var pending = newSeq[bool](n)
  var dead = newSeq[bool](n)
  var hadTool = newSeq[bool](n)
  var hadWeapon = newSeq[bool](n)
  var recent = newSeq[seq[string]](n)
  for pid in 0 ..< n:
    ours[pid] = seatName(header, replay, pid) == OurSeat
    minds[pid] = newMind(0'u64, (if getEnv("MIND_INDEX0") == "1": 0 else: pid))
    if weightsLoaded and ours[pid]:
      brains[pid] = newBrain(weights, uint64(pid) + 1)
  var acts = newSeq[int](n)
  for tick in 0 ..< replay.tickCount:
    let obs = readBytes(runtime, int(uint32(callI32(runtime, "obs_ptr"))), n * ObsSize)
    let obsBytes = cast[seq[uint8]](obs)
    for pid in 0 ..< n:
      let recorded = action(replay, tick, pid)
      acts[pid] = recorded
      if not ours[pid]: continue
      let base = pid * ObsSize
      let hp = int(obsBytes[base + Scalars + 5])
      if pendingDeath[pid].len > 0:
        if hp == 0:
          discard
          inc attackDeaths
          let parts = pendingDeath[pid].split(" ")
          killerBranch.inc(parts[0])
          killerHp.inc(parts[1])
          killerType.inc(parts[2 .. ^1].join(" "))
          deathContext.inc(pendingDeath[pid])
          if parts[0] == "flee": fleeDeathDest.inc(lastFleeDest[pid])
          let lt = lifeTicks[pid]
          deathByLifeTick.inc(if lt < 100: "attack <100" elif lt < 300: "attack 100-299" elif lt < 600: "attack 300-599" else: "attack 600+")
          if lt < 300: earlyDeath.inc("comb" & $lastComb[pid] & " " & pendingDeath[pid])
          if getEnv("DEATH_TRACES") == "1" and pendingDeath[pid].startsWith(getEnv("TRACE_BRANCH", "")) and getEnv("TRACE_KIND", "shooter") in pendingDeath[pid] and examples < 20:
            inc examples
            echo "death pid ", pid, " ", path.extractFilename, ": ", traces[pid].join(" | ")
        else:
          inc stagnations
          let comb = int(obsBytes[base + Scalars + 1])
          let prof = int(obsBytes[base + Scalars + 7])
          stagBinding.inc(if lastComb[pid] < lastProf[pid]: "comb binding" elif lastProf[pid] < lastComb[pid]: "prof binding" else: "equal")
          stagByComb.inc("comb" & $lastComb[pid] & " prof" & $lastProf[pid])
          if lastProf[pid] <= 2:
            var parts: seq[string]
            for k, v in lifeBranches[pid]: parts.add(k & "=" & $v)
            parts.sort(proc(x, y: string): int = cmp(y.split("=")[1].parseInt, x.split("=")[1].parseInt))
            echo "LOWLIFE tick ", tick, " pid ", pid, " ", path.extractFilename, " comb", lastComb[pid], " prof", lastProf[pid], " ticks ", lifeTicks[pid], " toolInInv ", lifeToolTicks[pid], " toolHeld ", lifeHeldTool[pid], " resourceInView ", lifeResourceTicks[pid], " branches ", parts[0 ..< min(6, parts.len)].join(" ")
          deathByLifeTick.inc("stagnation at life tick " & $(lifeTicks[pid] div 500 * 500))
          for k in stagWindow[pid]:
            stagClass.inc(k)
            inc stagTicks
          for k in stagBranchWindow[pid]:
            stagBranch.inc(k)
            inc stagFightableTicks
        pendingDeath[pid] = ""
      if pending[pid]:
        # The hosted runner resets the mind on the wire's reset flag; the
        # corpse ticks (hp 0) do not reach decide as a live life.
        pending[pid] = false
        minds[pid].reset()
        if weightsLoaded: brains[pid].reset()
        recentNet[pid] = @[]
        hadTool[pid] = false
        hadWeapon[pid] = false
        recent[pid] = @[]
        stagWindow[pid] = @[]
        stagBranchWindow[pid] = @[]
        lifeTicks[pid] = 0
        lifeBranches[pid] = initCountTable[string]()
        lifeToolTicks[pid] = 0
        lifeResourceTicks[pid] = 0
        lifeHeldTool[pid] = 0
      if hp == 0:
        dead[pid] = true
        continue
      dead[pid] = false
      var bytes = obsBytes[base ..< base + ObsSize]
      let a = minds[pid].decide(bytes, tick)
      let branch = minds[pid].branch
      if weightsLoaded:
        brains[pid].forward(bytes)
        let na = brains[pid].argmax()
        let cls = actionClass(na, obsBytes, base)
        var fleeCtx = ""
        if branch == "flee" and getEnv("FLEE_DETAIL") == "1":
          var nearest = 99
          var nd = 0
          var nranged = false
          for r in 0 ..< 11:
            for c in 0 ..< 15:
              let t = base + (r * 15 + c) * 10
              if obsBytes[t + 4] != 2'u8 or obsBytes[t + 8] == 5'u8: continue
              let d = max(abs(r - 5), abs(c - 7))
              if d < nearest:
                nearest = d; nd = int(obsBytes[t + 6]); nranged = obsBytes[t + 5] != 0'u8
          fleeCtx = " [" & (if nranged: "shooter" else: "melee") & " d" & $nd & (if nearest <= 1: " adjacent" elif nearest <= 3: " near" else: " far") & (if hp < 50: " hp<50" else: " hp50+") & "]"
        netBranch.inc(branch & fleeCtx & "|" & cls)
        netBranchTotal.inc(branch & fleeCtx)
        if na == a: netAgree.inc(branch & fleeCtx)
        recentNet[pid].add(branch & "|" & cls)
        if recentNet[pid].len > 20: recentNet[pid].delete(0)
      when defined(scriptedDebug):
        echo "DECIDE ", tick, " pid ", pid, " ", branch, " a", a, " hp", hp, " ", path.extractFilename
      inc total
      if a == recorded: inc agree
      else: disagreeBranches.inc(branch & "->" & $recorded)
      for slot in 0 ..< 12:
        let id = int(obsBytes[base + Scalars + 18 + slot])
        if id != 0 and id mod 17 == 6: hadTool[pid] = true
      let held = int(obsBytes[base + Scalars + 16])
      if held != 0 and (held mod 17 == 4 or held mod 17 == 5): hadWeapon[pid] = true
      let phase = (if not hadTool[pid]: NoTool elif not hadWeapon[pid]: ToolNoWeapon else: Later)
      inc phaseTicks[phase]
      phaseBranches[phase].inc(branch)
      block:
        # Did the previous tick's move take? The window (terrain and items)
        # is unchanged when the sim refused the move.
        var window = newSeq[uint8](11 * 15 * 4)
        for i in 0 ..< 11 * 15:
          for b in 0 ..< 4: window[i * 4 + b] = obsBytes[base + i * 10 + b]
        if prevMoveKey[pid].len > 0:
          let anim = int(obsBytes[base + Scalars + 4])
          if anim == 1 or anim == 2: stuck.inc(prevMoveKey[pid] & " moved") else: stuck.inc(prevMoveKey[pid] & " stuck anim" & $anim)
          inc moveTicks
        prevWindow[pid] = window
        prevMoveKey[pid] = ""
        if (a >= 0 and a <= 3) or a >= 22:
          let baseAct = (if a >= 22: a - 22 else: a)
          var dr, dc = 0
          case baseAct
          of 0: dr = 1
          of 1: dr = -1
          of 2: dc = 1
          else: dc = -1
          let t = base + ((5 + dr) * 15 + (7 + dc)) * 10
          let ent = obsBytes[t + 4]
          let anim = obsBytes[t + 8]
          let cell = (if ent == 0'u8: "free" elif anim == 5'u8: "corpse" elif ent == 2'u8: "live enemy" else: "player")
          prevMoveKey[pid] = branch & " " & (if a >= 22: "run" else: "walk") & " into " & cell
      if branch == "flee" and a >= 0 and a <= 25 and a != 4 and a != 5 and a < 8 or (branch == "flee" and a >= 22):
        let baseAct = (if a >= 22: a - 22 else: a)
        let steps = (if a >= 22: 2 else: 1)
        var dr, dc = 0
        case baseAct
        of 0: dr = 1
        of 1: dr = -1
        of 2: dc = 1
        else: dc = -1
        let destR = 5 + steps * dr
        let destC = 7 + steps * dc
        var cls = "no shooter within 5"
        var worst = 0
        for r in 0 ..< 11:
          for c in 0 ..< 15:
            let t = base + (r * 15 + c) * 10
            if obsBytes[t + 4] != 2'u8 or obsBytes[t + 8] == 5'u8 or obsBytes[t + 5] == 0'u8: continue
            let cheb = max(abs(destR - r), abs(destC - c))
            if cheb > 5: continue
            let onLane = (destR == r or destC == c) and cheb <= 4
            let nearLane = (abs(destR - r) == 1 or abs(destC - c) == 1) and cheb <= 5
            let w = (if onLane: 3 elif nearLane: 2 else: 1)
            if w > worst: worst = w
        if worst == 3: cls = "lands on a shooter lane"
        elif worst == 2: cls = "lands one step off a shooter lane"
        elif worst == 1: cls = "shooter within 5, off lane by 2+"
        fleeDest.inc(cls)
        inc fleeDestTicks
        lastFleeDest[pid] = cls
      block:
        let comb = int(obsBytes[base + Scalars + 1])
        let band = (if comb <= 3: "comb1-3" elif comb <= 6: "comb4-6" elif comb <= 9: "comb7-9" else: "comb10+")
        let count = int(callI32(runtime, "debug_nearby", [int32(pid), 12'i32]))
        var levelUpMelee7, levelUpMelee4, anyMelee7, levelUpMelee12 = 0
        var bestDist = 99
        var bestDelta = -1
        var company = false
        if count > 0:
          let bufPtr = int(uint32(callI32(runtime, "debug_buf_ptr")))
          let raw = readBytes(runtime, bufPtr, count * 5 * 4)
          for i in 0 ..< count:
            var vals: array[5, int32]
            copyMem(addr vals[0], unsafeAddr raw[i * 20], 20)
            let dr = int(vals[0]); let dc = int(vals[1]); let lvl = int(vals[2]); let ranged = vals[3] != 0
            let cheb = max(abs(dr), abs(dc))
            if cheb <= 4 and (ranged or lvl >= comb + 6): company = true
            if ranged: continue
            if lvl >= comb and lvl < comb + 6: inc levelUpMelee12
            if cheb > 7: continue
            inc anyMelee7
            if lvl >= comb:
              inc levelUpMelee7
              if cheb <= 4: inc levelUpMelee4
              if cheb < bestDist:
                bestDist = cheb
                bestDelta = min(max((lvl - comb) div 2, 0), 4)
            # delta-0 in the window: |dr| <= 5, |dc| <= 7 and (lvl - comb) div 2 clamps to 0
            if abs(dr) <= 5 and abs(dc) <= 7 and lvl <= comb + 1:
              delta0Pay.inc(band & (if lvl >= comb: " pays" else: " no level"))
        let avail = (if levelUpMelee4 > 0: "level-up melee within 4" elif levelUpMelee7 > 0: "level-up melee at 5-7" elif levelUpMelee12 > 0: "kiteable level-up melee at 8-12 only" elif anyMelee7 > 0: "only weaker melee within 7" else: "nothing useful within 12")
        let heldId = int(obsBytes[base + Scalars + 16])
        let heldK = (if heldId == 0: "none" elif heldId mod 17 == 4: "sword" elif heldId mod 17 == 5: "bow" elif heldId mod 17 == 6: "tool" else: "other")
        let detail = (if levelUpMelee7 > 0: " d" & $bestDelta & " at" & $bestDist & " held:" & heldK & (if company: " company" else: " alone") else: "")
        trueLevel.inc(band & " | " & avail & " | " & branch & detail)
        inc trueLevelTicks
      block:
        let comb = int(obsBytes[base + Scalars + 1])
        if comb >= 12:
          let attack = int(obsBytes[base + Scalars + 45])
          let defense = int(obsBytes[base + Scalars + 46])
          var best = -100
          var bestD = 99
          var bestDelta = -1
          var onLane = false
          for r in 0 ..< 11:
            for c in 0 ..< 15:
              let t = base + (r * 15 + c) * 10
              if obsBytes[t + 4] != 2'u8 or obsBytes[t + 8] == 5'u8 or obsBytes[t + 5] == 0'u8: continue
              let delta = int(obsBytes[t + 6])
              if delta > 2: continue
              let d = max(abs(r - 5), abs(c - 7))
              if d > 6 or d >= bestD: continue
              let ehp = int(obsBytes[t + 7])
              let level = comb + 2 * delta + 1
              let ourDamage = 40 + 2 * comb + attack - 5 * level
              var margin = -99
              if ourDamage > 0:
                let enemyDamage = max(15 + 5 * level - 2 * comb - defense, 0)
                let hitsToKill = (20 * ehp + 19 + ourDamage - 1) div ourDamage
                margin = (if enemyDamage == 0: 9 else: (hp + enemyDamage - 1) div enemyDamage - hitsToKill)
              best = margin; bestD = d; bestDelta = delta; onLane = (r == 5 or c == 7)
          if bestDelta >= 0:
            let cls = "shooter d" & $bestDelta & (if onLane and bestD <= 4: " on lane<=4" elif bestD <= 4: " off lane<=4" else: " at5-6") & (if best >= 1: " margin>=1" elif best >= 0: " margin0" elif best >= -2: " margin-1..-2" else: " hopeless") & " | " & branch
            capShooter.inc(cls)
            inc capShooterTicks
      block:
        let comb = int(obsBytes[base + Scalars + 1])
        var shooterElem = 0
        var shooterD = 99
        for r in 0 ..< 11:
          for c in 0 ..< 15:
            let t = base + (r * 15 + c) * 10
            if obsBytes[t + 4] != 2'u8 or obsBytes[t + 8] == 5'u8 or obsBytes[t + 5] == 0'u8: continue
            let d = max(abs(r - 5), abs(c - 7))
            if d < shooterD:
              shooterD = d; shooterElem = int(obsBytes[t + 5])
        if shooterD <= 6 and comb >= 6:
          var gems: seq[int]
          for slot in 0 ..< 12:
            let id = int(obsBytes[base + Scalars + 18 + slot])
            if id != 0 and id mod 17 >= 7 and id mod 17 <= 10: gems.add(id mod 17)
          # counter gem kind: fire(1)<-water(10), water(2)<-earth(7), earth(3)<-air(9), air(4)<-fire(8)
          let counter = (case shooterElem
            of 1: 10
            of 2: 7
            of 3: 9
            of 4: 8
            else: 0)
          let elemName = ["neutral", "fire", "water", "earth", "air"][min(shooterElem, 4)]
          let ourGem = int(obsBytes[base + Scalars + 17])
          gemCtx.inc("shooter " & elemName & (if counter in gems: " counter gem in bag" else: " no counter gem") & (if ourGem != 0: " wearing gem" & $(ourGem mod 17) else: " no gem worn") & " | " & branch)
          inc gemTicks
      if branch == "cornered":
        inc cornerTicks
        # adjacent enemies (orthogonal or diagonal) and whether a passable,
        # unoccupied step exists that is orthogonally adjacent to none of them
        var adj: seq[(int, int)]
        for r in 0 ..< 11:
          for c in 0 ..< 15:
            let t = base + (r * 15 + c) * 10
            if obsBytes[t + 4] != 2'u8 or obsBytes[t + 8] == 5'u8: continue
            if max(abs(r - 5), abs(c - 7)) <= 1: adj.add((r, c))
        var breakMove = false
        var anyMove = false
        for (dr, dc) in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
          let nr = 5 + dr
          let nc = 7 + dc
          let t = base + (nr * 15 + nc) * 10
          if obsBytes[t + 1] > 1'u8: continue
          if obsBytes[t + 4] != 0'u8 and obsBytes[t + 8] != 5'u8: continue
          anyMove = true
          var contact = false
          for (er, ec) in adj:
            if abs(er - nr) + abs(ec - nc) == 1: contact = true
          if not contact: breakMove = true
        cornerCtx.inc((if adj.len == 0: "no adjacent enemy" elif breakMove: "contact-breaking step available" elif anyMove: "only steps that stay adjacent" else: "no step at all") & " adj" & $adj.len & (if hp < 50: " hp<50" else: " hp50+"))
      if branch == "wander":
        let isPause = (a == 4 or a == 5)
        var nearest = 99
        var nd = 0
        var nranged = false
        for r in 0 ..< 11:
          for c in 0 ..< 15:
            let t = base + (r * 15 + c) * 10
            if obsBytes[t + 4] != 2'u8 or obsBytes[t + 8] == 5'u8: continue
            let d = max(abs(r - 5), abs(c - 7))
            if d < nearest:
              nearest = d; nd = int(obsBytes[t + 6]); nranged = obsBytes[t + 5] != 0'u8
        let comb = int(obsBytes[base + Scalars + 1])
        let ctx = (if nearest > 4: "no enemy within 4" else: (if nranged: "shooter" else: "melee") & " d" & $nd & " within 4") & (if comb <= 3: " comb<=3" else: " comb4+") & (if hp < 60: " hp<60" else: "")
        pauseCtx.inc((if isPause: "pause " else: "move ") & ctx)
        inc pauseTicks
      if branch == "buy" or branch == "sell":
        inc flowStarts
        var nearest = 99
        for r in 0 ..< 11:
          for c in 0 ..< 15:
            let t = base + (r * 15 + c) * 10
            if obsBytes[t + 4] != 2'u8 or obsBytes[t + 8] == 5'u8 or obsBytes[t + 5] == 0'u8: continue
            nearest = min(nearest, max(abs(r - 5), abs(c - 7)))
        flowStart.inc(branch & (if nearest > 7: " no shooter in view" elif nearest >= 6: " shooter at 6-7" elif nearest == 5: " shooter at 5" else: " shooter within 4"))
      if phase == NoTool and lifeTicks[pid] >= 400:
        inc lateNoToolTicks
        var nearest = 99
        var nd = 0
        var nranged = false
        var toolsInView = 0
        for r in 0 ..< 11:
          for c in 0 ..< 15:
            let t = base + (r * 15 + c) * 10
            if obsBytes[t + 2] == 6'u8: inc toolsInView
            if obsBytes[t + 4] != 2'u8 or obsBytes[t + 8] == 5'u8: continue
            let d = max(abs(r - 5), abs(c - 7))
            if d < nearest:
              nearest = d; nd = int(obsBytes[t + 6]); nranged = obsBytes[t + 5] != 0'u8
        lateNoTool.inc(branch & " " & (if nearest > 6: "no enemy near" else: (if nranged: "shooter" else: "melee") & " d" & $nd & (if nearest <= 2: " at<=2" else: " at3-6")) & (if toolsInView > 0: " tool in view" else: ""))
      inc lifeTicks[pid]
      if getEnv("DUMP_PID") == $pid and getEnv("DUMP_FILE", "zzz") in path and tick mod 50 == 0:
        var free = 0
        var inv: seq[string]
        for slot in 0 ..< 12:
          let id = int(obsBytes[base + Scalars + 18 + slot])
          if id == 0: inc free else: inv.add($(id mod 17) & "t" & $(id div 17 + 1))
        var res1, resAll = 0
        for r in 0 ..< 11:
          for c in 0 ..< 15:
            let t = base + (r * 15 + c) * 10
            let k = int(obsBytes[t + 2])
            if k >= 7 and k <= 16:
              inc resAll
              if int(obsBytes[t + 3]) == 0: inc res1
        echo "DUMP t", tick, " life", lifeTicks[pid], " hp", hp, " comb", obsBytes[base + Scalars + 1], " prof", obsBytes[base + Scalars + 7], " held", int(obsBytes[base + Scalars + 16]) mod 17, "t", int(obsBytes[base + Scalars + 16]) div 17 + 1, " free", free, " inv[", inv.join(","), "] res", resAll, " res_t1 ", res1, " branch ", branch
      lifeBranches[pid].inc(branch)
      if hadTool[pid]: inc lifeToolTicks[pid]
      block:
        let heldId = int(obsBytes[base + Scalars + 16])
        if heldId != 0 and heldId mod 17 == 6: inc lifeHeldTool[pid]
        var res = false
        for r in 0 ..< 11:
          for c in 0 ..< 15:
            let k = int(obsBytes[base + (r * 15 + c) * 10 + 2])
            if k >= 7 and k <= 16: res = true
        if res: inc lifeResourceTicks[pid]
      lastComb[pid] = int(obsBytes[base + Scalars + 1])
      lastProf[pid] = int(obsBytes[base + Scalars + 7])
      block:
        let comb = int(obsBytes[base + Scalars + 1])
        let attack = int(obsBytes[base + Scalars + 45])
        let defense = int(obsBytes[base + Scalars + 46])
        var best = -100
        var seen = 0
        var shooterOnly = true
        for r in 0 ..< 11:
          for c in 0 ..< 15:
            let t = base + (r * 15 + c) * 10
            if obsBytes[t + 4] != 2'u8 or obsBytes[t + 8] == 5'u8: continue
            inc seen
            if obsBytes[t + 5] != 0'u8: continue
            shooterOnly = false
            let delta = int(obsBytes[t + 6])
            let ehp = int(obsBytes[t + 7])
            let level = comb + 2 * delta + 1
            let ourDamage = 40 + 2 * comb + attack - 5 * level
            var margin = -99
            if ourDamage > 0:
              let enemyDamage = max(15 + 5 * level - 2 * comb - defense, 0)
              let hitsToKill = (20 * ehp + 19 + ourDamage - 1) div ourDamage
              margin = (if enemyDamage == 0: 9 else: (hp + enemyDamage - 1) div enemyDamage - hitsToKill)
            if margin > best: best = margin
        let cls = (if seen == 0: "none in view" elif shooterOnly: "shooters only" elif best >= 1: "melee margin>=1 in view" elif best == 0: "melee even (margin 0) in view" elif best >= -2: "melee margin -1..-2 in view" else: "melee hopeless only")
        stagWindow[pid].add(cls & (if hp < 45: " hp<45" else: ""))
        if stagWindow[pid].len > 300: stagWindow[pid].delete(0)
        if seen > 0 and not shooterOnly and best >= 0:
          stagBranchWindow[pid].add(branch)
          if stagBranchWindow[pid].len > 300: stagBranchWindow[pid].delete(0)
      block:
        let comb = int(obsBytes[base + Scalars + 1])
        if comb >= 7:
          inc highCombTicks
          var kiteable, stronger = 0
          for r in 0 ..< 11:
            for c in 0 ..< 15:
              let t = base + (r * 15 + c) * 10
              if obsBytes[t + 4] != 2'u8 or obsBytes[t + 8] == 5'u8: continue
              let d = int(obsBytes[t + 6])
              let ranged = obsBytes[t + 5] != 0'u8
              if not ranged and d <= 2: inc kiteable
              if not ranged and d >= 1 and d <= 2: inc stronger
          let key = branch & (if stronger > 0: " +stronger(d1-2) in view" elif kiteable > 0: " +peer(d0) in view" else: " nothing kiteable")
          highComb.inc(key)
      if phase == ToolNoWeapon and branch == "wander":
        inc toolWanderTicks
        when defined(scriptedDebug):
          echo "WANDER-TNW tick ", tick, " pid ", pid
        var resources, tools = 0
        var enemy4, strong4 = false
        for r in 0 ..< 11:
          for c in 0 ..< 15:
            let t = base + (r * 15 + c) * 10
            let kind = int(obsBytes[t + 2])
            if kind >= 7 and kind <= 16: inc resources
            if kind == 6: inc tools
            if obsBytes[t + 4] == 2'u8 and obsBytes[t + 8] != 5'u8 and max(abs(r - 5), abs(c - 7)) <= 4:
              enemy4 = true
              if obsBytes[t + 6] >= 3'u8: strong4 = true
        var free = 0
        for slot in 0 ..< 12:
          if obsBytes[base + Scalars + 18 + slot] == 0'u8: inc free
        let key = (if resources == 0: "no resource in view" else: "resources in view") & (if free == 0: " inventory full" else: "") & (if strong4: " strong within 4" elif enemy4: " enemy within 4" else: "")
        toolWander.inc(key)
      when defined(scriptedDebug):
        if branch == "wander": echo "WANDER-ANY phase ", phase, " tick ", tick, " pid ", pid
      if phase == Later and branch == "wander":
        inc wanderTicks
        var nearest = 99
        var nearDelta = -1
        for r in 0 ..< 11:
          for c in 0 ..< 15:
            let t = base + (r * 15 + c) * 10
            if obsBytes[t + 4] != 2'u8 or obsBytes[t + 8] == 5'u8: continue
            let d = max(abs(r - 5), abs(c - 7))
            if d < nearest:
              nearest = d
              nearDelta = int(obsBytes[t + 6])
        let hp = int(obsBytes[base + Scalars + 5])
        let key = (if nearest > 5: "none within 5" else: "delta" & $nearDelta & (if nearest <= 2: " at<=2" else: " at3-5")) & (if hp < 50: " hp<50" else: "")
        wanderContext.inc(key)
      recent[pid].add(branch)
      block:
        var nearest = 99
        var nd, nranged = 0
        var nr, nc = 0
        for r in 0 ..< 11:
          for c in 0 ..< 15:
            let t = base + (r * 15 + c) * 10
            if obsBytes[t + 4] != 2'u8 or obsBytes[t + 8] == 5'u8: continue
            let d = max(abs(r - 5), abs(c - 7))
            if d < nearest:
              nearest = d; nd = int(obsBytes[t + 6]); nranged = (if obsBytes[t + 5] != 0'u8: 1 else: 0)
              nr = r; nc = c
        let lane = nearest < 99 and (nr == 5 or nc == 7)
        traces[pid].add("t" & $tick & " " & branch & " a" & $a & " hp" & $hp & " " & (if nearest > 6: "-" else: (if nranged == 1: "S" else: "M") & "d" & $nd & "@" & $nr & "," & $nc))
        if traces[pid].len > 6: traces[pid].delete(0)
        lastContext[pid] = branch & " hp" & (if hp >= 90: "90+" elif hp >= 50: "50-89" else: "<50") & " " & (if nearest > 6: "none near" else: (if nranged == 1: "shooter" else: "melee") & " d" & $nd & " at" & $nearest & (if lane: " lane" else: ""))
      if recent[pid].len > 20: recent[pid].delete(0)
    writeActions(runtime, acts)
    callVoid(runtime, "nmmo_step")
    let termPtr = int(uint32(callI32(runtime, "term_ptr")))
    let raw = readBytes(runtime, termPtr, n * 4)
    for pid in 0 ..< n:
      if uint8(raw[pid * 4 + 3]) == 0x3f'u8 and uint8(raw[pid * 4 + 2]) == 0x80'u8:
        pending[pid] = true
        if ours[pid]:
          inc deaths
          if weightsLoaded:
            for k in recentNet[pid]:
              netDeath.inc(k)
              inc netDeathTotal
          pendingDeath[pid] = lastContext[pid]
          for b in recent[pid]: deathBranches.inc(b)

proc histogram(ct: CountTable[string], total: int): string =
  var items: seq[(string, int)]
  for k, v in ct: items.add((k, v))
  items.sort(proc(x, y: (string, int)): int = cmp(y[1], x[1]))
  var parts: seq[string]
  for it in items:
    if parts.len >= 10: break
    parts.add(it[0] & " " & formatFloat(100.0 * float(it[1]) / float(max(total, 1)), ffDecimal, 1) & "%")
  parts.join(", ")

proc main() =
  if paramCount() < 2:
    quit("usage: scripted_replay <sim.wasm> <hosted.replay>...", 1)
  let wasmBytes = readFile(paramStr(1))
  for i in 2 .. paramCount():
    try:
      processReplay(wasmBytes, paramStr(i))
    except CatchableError as e:
      stderr.writeLine("skip " & paramStr(i) & ": " & e.msg)
  echo "our ticks ", total, " agreement ", formatFloat(100.0 * float(agree) / float(max(total, 1)), ffDecimal, 2), "%"
  echo "disagreements (branch->recorded action): ", histogram(disagreeBranches, total - agree)
  for phase in Phase:
    echo $phase, " ", phaseTicks[phase], " ticks: ", histogram(phaseBranches[phase], phaseTicks[phase])
  for k, v in phaseBranches[Later]: echo "LB ", v, " ", k
  echo "tool-but-no-weapon wander ticks ", toolWanderTicks, ": ", histogram(toolWander, toolWanderTicks)
  echo "high-comb (>=7) ticks ", highCombTicks, ": ", histogram(highComb, highCombTicks)
  echo "mature wander ticks ", wanderTicks, " by nearest enemy: ", histogram(wanderContext, wanderTicks)
  echo "attack deaths ", attackDeaths, " stagnation resets ", stagnations
  echo "stagnation resets by binding skill: ", histogram(stagBinding, stagnations)
  echo "stagnation resets by levels: ", histogram(stagByComb, stagnations)
  echo "life ends by life tick: ", histogram(deathByLifeTick, deaths)
  echo "no-tool ticks past life tick 400 (", lateNoToolTicks, "): ", histogram(lateNoTool, lateNoToolTicks)
  echo "flee destinations vs shooters (", fleeDestTicks, " flee ticks): ", histogram(fleeDest, fleeDestTicks)
  echo "move outcomes by first cell (", moveTicks, " moves): ", histogram(stuck, moveTicks)
  for k, v in stuck: echo "MO ", v, " ", k
  echo "menu flow starts (", flowStarts, ") by nearest shooter: ", histogram(flowStart, flowStarts)
  for k, v in pauseCtx: echo "PC ", v, " ", k
  for k, v in capShooter: echo "CS ", v, " ", k
  for k, v in gemCtx: echo "GC ", v, " ", k
  echo "cornered ticks ", cornerTicks, ": ", histogram(cornerCtx, cornerTicks)
  echo "comb>=6 ticks with a shooter within 6: ", gemTicks
  echo "comb>=12 ticks with a delta<=2 shooter within 6: ", capShooterTicks
  for k, v in trueLevel: echo "TL ", v, " ", k
  for k, v in delta0Pay: echo "D0 ", v, " ", k
  echo "last flee destination before flee-branch attack deaths: ", histogram(fleeDeathDest, killerBranch.getOrDefault("flee"))
  echo "early attack deaths (<300 life ticks) by comb and last decision: ", histogram(earlyDeath, attackDeaths)
  echo "300 ticks before ", stagnations, " stagnation resets, best enemy in view: ", histogram(stagClass, stagTicks)
  echo "our branch while a melee with margin >= 0 was in view (", stagFightableTicks, " ticks): ", histogram(stagBranch, stagFightableTicks)
  echo "attack deaths by branch: ", histogram(killerBranch, attackDeaths)
  echo "attack deaths by hp: ", histogram(killerHp, attackDeaths)
  echo "attack deaths by nearest enemy: ", histogram(killerType, attackDeaths)
  echo "last decision before death (branch, hp, nearest enemy): ", histogram(deathContext, deaths)
  if getEnv("DEATH_KEYS") == "1":
    for k, v in deathContext: echo "DK ", v, " ", k
  echo "20 ticks before ", deaths, " deaths (all causes): ", histogram(deathBranches, deaths * 20)
  if netWeightsPath.len > 0:
    echo "== network argmax on our observations, by our branch (share of that branch's ticks; agree = same action)"
    var branches: seq[string]
    for k in netBranchTotal.keys: branches.add(k)
    branches.sort()
    for b in branches:
      let total = netBranchTotal[b]
      if total < 200: continue
      var items: seq[(string, int)]
      for k, v in netBranch:
        if k.startsWith(b & "|"): items.add((k[b.len + 1 .. ^1], v))
      items.sort(proc(x, y: (string, int)): int = cmp(y[1], x[1]))
      var parts: seq[string]
      for it in items:
        if parts.len >= 6: break
        parts.add(it[0] & " " & formatFloat(100.0 * float(it[1]) / float(total), ffDecimal, 1) & "%")
      echo b, " (", total, " ticks, agree ", formatFloat(100.0 * float(netAgree.getOrDefault(b)) / float(total), ffDecimal, 1), "%): ", parts.join(", ")
    echo "== 20 ticks before deaths, branch|net class: ", histogram(netDeath, netDeathTotal)

main()
