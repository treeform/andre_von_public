## Throw and latch analytics for the local BASIC ladder (duel logs from
## `ladder.nim --log DIR`). One tool, one subcommand per question:
##
##   nim r --hints:off games/pudge-wars/bas/throws.nim <sub> <logroot> [<logroot2>]
##
##   denies      outcome mix of OUR launches: denied (mid-air clash) / hit / miss
##   misses      closest-enemy distance at our misses (was anybody there?)
##   aim         |aim.y - nearest enemy y| at launch for our far pokes
##   posts       where enemy butchers stand on their own bank (depth, y by seat)
##   onus        enemy latches on us per game by thrower distance
##   latchstate  our state when a far enemy poke lands (windup, just threw, deep, ...)
##   allies      our latches on our own partner: rescue-aimed vs crossfire
##   returnleg   latches on us by flight ticks (return-leg catches exceed 46)
##   farbank     deaths on the enemy bank after a dump: survival ticks, our actions
##
## Scripts whose name contains "myasnik" are OUR side; set MINE=name to
## pick a side in a mirror match (MINE=myasnik_v83).

import std/[os, json, strutils, strformat, tables, algorithm, math]

let mineName = getEnv("MINE", "myasnik")

proc run_denies() =
  # Our hook launches: outcome mix and ticks-to-resolution for denied ones.
  var games = 0
  var outcomes = initCountTable[string]()
  var denyTicks: seq[int]
  var launches = 0
  var farLaunches = 0
  var farOutcomes = initCountTable[string]()
  for path in walkDirRec(paramStr(2)):
    if not path.endsWith("events.jsonl"): continue
    inc games
    var mine = initTable[int, bool]()
    var launched = initTable[int, JsonNode]()
    for line in lines(path):
      if line.len == 0: continue
      if "\"match_start\"" in line:
        for p in parseJson(line){"players"}:
          mine[p{"id"}.getInt] = mineName in p{"script"}.getStr
      elif "\"hook_launched\"" in line:
        let e = parseJson(line)
        if mine[e{"id"}.getInt]:
          launched[e{"hookId"}.getInt] = e
          inc launches
          let tg = e{"target"}
          if tg == nil or tg.kind == JNull or tg{"dist"}.getFloat(0) > 40: inc farLaunches
      elif "\"hook_resolved\"" in line:
        let e = parseJson(line)
        let h = e{"hookId"}.getInt
        if h in launched:
          let r = e{"result"}.getStr
          outcomes.inc r
          let L = launched[h]
          let tg = L{"target"}
          let far = tg == nil or tg.kind == JNull or tg{"dist"}.getFloat(0) > 40
          if far: farOutcomes.inc r
          if r.startsWith("den"): denyTicks.add(e{"t"}.getInt - L{"t"}.getInt)
  denyTicks.sort()
  var a, b: seq[string]
  for k, v in outcomes: a.add &"{k}:{v}"
  for k, v in farOutcomes: b.add &"{k}:{v}"
  echo &"{games} games, our launches {launches} ({launches.float/games.float:.0f}/game): {a.join(\"  \")}"
  echo &"far launches (target > 40 tiles or none) {farLaunches}: {b.join(\"  \")}"
  if denyTicks.len > 0:
    echo &"ticks from launch to deny: q1 {denyTicks[denyTicks.len div 4]} median {denyTicks[denyTicks.len div 2]} q3 {denyTicks[3*denyTicks.len div 4]}  (river spans ticks ~13-27 of a 45-tick flight from the standoff)"


proc run_misses() =
  # Our hook_missed events: distance to the closest enemy at the miss, in bands.
  var games = 0
  var bands = initCountTable[string]()
  var n = 0
  var ds: seq[float]
  for path in walkDirRec(paramStr(2)):
    if not path.endsWith("events.jsonl"): continue
    inc games
    var mine = initTable[int, bool]()
    for line in lines(path):
      if line.len == 0: continue
      if "\"match_start\"" in line:
        for p in parseJson(line){"players"}:
          mine[p{"id"}.getInt] = mineName in p{"script"}.getStr
      elif "\"hook_missed\"" in line:
        let e = parseJson(line)
        if not mine[e{"id"}.getInt]: continue
        let c = e{"closest"}
        if c == nil or c.kind == JNull: bands.inc("no enemy near"); inc n; continue
        let d = c{"dist"}.getFloat
        ds.add d
        inc n
        bands.inc(if d < 6: "<6 (a hair)" elif d < 10: "6-10 (a sidestep)" elif d < 15: "10-15" elif d < 25: "15-25" else: "25+ (nobody there)")
  ds.sort()
  var parts: seq[string]
  for k in ["<6 (a hair)", "6-10 (a sidestep)", "10-15", "15-25", "25+ (nobody there)", "no enemy near"]:
    parts.add &"{k}: {100 * bands.getOrDefault(k) div max(n,1)}%"
  echo &"{games} games, {n} misses by us ({n.float/games.float:.0f}/game): {parts.join(\"  \")}"
  if ds.len > 0: echo &"closest-enemy distance at the miss: q1 {ds[ds.len div 4]:.1f} median {ds[ds.len div 2]:.1f} q3 {ds[3*ds.len div 4]:.1f}"


proc run_aim() =
  # Per far poke by us: min |aim.y - enemy.y| over enemies standing on their bank at launch,
  # and the min |aim.x - enemy.x| for the closest-y enemy.
  var dys: seq[float]
  var dxs: seq[float]
  var noEnemy = 0
  var pokes = 0
  for path in walkDirRec(paramStr(2)):
    if not path.endsWith("events.jsonl"): continue
    var mine = initTable[int, bool]()
    var team = initTable[int, string]()
    var states: seq[JsonNode]
    var launches: seq[JsonNode]
    for line in lines(path):
      if line.len == 0: continue
      if "\"match_start\"" in line:
        for p in parseJson(line){"players"}:
          mine[p{"id"}.getInt] = mineName in p{"script"}.getStr
          team[p{"id"}.getInt] = p{"team"}.getStr
      elif "\"ev\":\"state\"" in line: states.add parseJson(line)
      elif "\"hook_launched\"" in line:
        let e = parseJson(line)
        if not mine[e{"id"}.getInt]: continue
        let tg = e{"target"}
        if tg != nil and tg.kind != JNull and tg{"dist"}.getFloat(0) <= 40: continue
        launches.add e
    var si = 0
    for L in launches:
      let t = L{"t"}.getInt
      while si + 1 < states.len and states[si + 1]{"t"}.getInt <= t: inc si
      let st = states[si]
      let ay = L{"aim"}[1].getFloat
      let ax = L{"aim"}[0].getFloat
      var best = 1e9
      var bestDx = 0.0
      for q in st{"p"}:
        let id = q{"id"}.getInt
        if mine[id] or not q{"alive"}.getBool(true): continue
        let lay = q{"lay"}.getInt
        let west = team[id] == "west"
        if not ((lay == 0 and west) or (lay == 1 and not west)): continue
        let dy = abs(q{"y"}.getFloat - ay)
        if dy < best:
          best = dy
          bestDx = abs(q{"x"}.getFloat - ax)
      inc pokes
      if best > 1e8: inc noEnemy
      else:
        dys.add best
        dxs.add bestDx
  dys.sort(); dxs.sort()
  echo &"{pokes} far pokes; no enemy on its bank at launch: {noEnemy} ({100*noEnemy div max(pokes,1)}%)"
  var bands = initCountTable[string]()
  for d in dys: bands.inc(if d < 5: "<5" elif d < 10: "5-10" elif d < 20: "10-20" elif d < 40: "20-40" else: "40+")
  var parts: seq[string]
  for k in ["<5", "5-10", "10-20", "20-40", "40+"]: parts.add &"{k}: {100 * bands.getOrDefault(k) div max(dys.len,1)}%"
  echo "min |aim.y - enemy.y| at launch: ", parts.join("  "), &"   (median {dys[dys.len div 2]:.1f})"
  echo &"|aim.x - that enemy's x|: q1 {dxs[dxs.len div 4]:.1f} median {dxs[dxs.len div 2]:.1f} q3 {dxs[3*dxs.len div 4]:.1f}"


proc run_posts() =
  # Where enemy butchers stand while on their own bank: depth from their lip, and y, per seat rank.
  var depth = initCountTable[int]()
  var ys = initTable[int, CountTable[int]]()   # rank -> y band counts
  var n = 0
  for path in walkDirRec(paramStr(2)):
    if not path.endsWith("events.jsonl"): continue
    var mine = initTable[int, bool]()
    var team = initTable[int, string]()
    var enemyIds: seq[int]
    for line in lines(path):
      if line.len == 0: continue
      if "\"match_start\"" in line:
        for p in parseJson(line){"players"}:
          let id = p{"id"}.getInt
          mine[id] = mineName in p{"script"}.getStr
          team[id] = p{"team"}.getStr
          if not mine[id]: enemyIds.add id
        enemyIds.sort()
      elif "\"ev\":\"state\"" in line:
        let s = parseJson(line)
        for q in s{"p"}:
          let id = q{"id"}.getInt
          if mine.getOrDefault(id): continue
          let lay = q{"lay"}.getInt
          let west = team[id] == "west"
          if not ((lay == 0 and west) or (lay == 1 and not west)): continue
          let x = q{"x"}.getFloat
          let d = if west: 52.0 - x else: x - 76.0
          depth.inc(int(d) div 4 * 4)
          let rank = enemyIds.find(id)
          if rank notin ys: ys[rank] = initCountTable[int]()
          ys[rank].inc(int(q{"y"}.getFloat) div 4 * 4)
          inc n
  echo &"{n} enemy-on-own-bank samples"
  var keys: seq[int]
  for k in depth.keys: keys.add k
  keys.sort()
  var parts: seq[string]
  for k in keys:
    if depth[k] * 100 div n >= 2: parts.add &"{k}-{k+3}:{depth[k] * 100 div n}%"
  echo "depth from their lip: ", parts.join("  ")
  for rank in 0 .. 1:
    if rank notin ys: continue
    var ks: seq[int]
    for k in ys[rank].keys: ks.add k
    ks.sort()
    var ps: seq[string]
    var tot = 0
    for k in ks: tot += ys[rank][k]
    for k in ks:
      if ys[rank][k] * 100 div tot >= 3: ps.add &"{k}-{k+3}:{ys[rank][k] * 100 div tot}%"
    echo &"seat rank {rank} y: ", ps.join("  ")


proc run_onus() =
  # Enemy latches ON our butchers by thrower distance band, per game.
  for root in commandLineParams()[1 .. ^1]:
    var games = 0
    var bands = initCountTable[string]()
    var kills = 0
    for path in walkDirRec(root):
      if not path.endsWith("events.jsonl"): continue
      inc games
      var teams = initTable[int, string]()
      var mine = initTable[int, bool]()
      for line in lines(path):
        if line.len == 0: continue
        if "\"match_start\"" in line:
          for p in parseJson(line){"players"}:
            teams[p{"id"}.getInt] = p{"team"}.getStr
            mine[p{"id"}.getInt] = mineName in p{"script"}.getStr
        elif "\"hook_landed\"" in line:
          let e = parseJson(line)
          let id = e{"id"}.getInt
          let v = e{"victim"}.getInt
          if mine[id] or not mine[v]: continue
          let d = e{"dist"}.getFloat
          bands.inc(if d < 15: "0-15" elif d < 30: "15-30" elif d < 45: "30-45" elif d < 60: "45-60" else: "60+")
    var parts: seq[string]
    for k in ["0-15", "15-30", "30-45", "45-60", "60+"]:
      parts.add &"{k}: {bands.getOrDefault(k).float / games.float:.2f}"
    echo &"{root} ({games} games) enemy latches on us per game by thrower distance: {parts.join(\"  \")}"


proc run_latchstate() =
  # For each enemy latch on us from 40+ tiles: our state at the nearest snapshot before it.
  var n = 0
  var windup, justThrew, river, deep, nearLip, enemyBank = 0
  var cds: seq[int]
  for path in walkDirRec(paramStr(2)):
    if not path.endsWith("events.jsonl"): continue
    var mine = initTable[int, bool]()
    var team = initTable[int, string]()
    var states: seq[JsonNode]
    var landed: seq[JsonNode]
    for line in lines(path):
      if line.len == 0: continue
      if "\"match_start\"" in line:
        for p in parseJson(line){"players"}:
          mine[p{"id"}.getInt] = mineName in p{"script"}.getStr
          team[p{"id"}.getInt] = p{"team"}.getStr
      elif "\"ev\":\"state\"" in line: states.add parseJson(line)
      elif "\"hook_landed\"" in line:
        let e = parseJson(line)
        if mine[e{"id"}.getInt] or not mine[e{"victim"}.getInt]: continue
        if e{"dist"}.getFloat < 40: continue
        landed.add e
    var si = 0
    for e in landed:
      let t = e{"t"}.getInt
      while si + 1 < states.len and states[si + 1]{"t"}.getInt <= t: inc si
      let v = e{"victim"}.getInt
      for q in states[si]{"p"}:
        if q{"id"}.getInt != v: continue
        inc n
        if q{"windup"}.getInt > 0: inc windup
        let cd = q{"cd"}.getInt
        cds.add cd
        if cd >= 50: inc justThrew
        let lay = q{"lay"}.getInt
        let west = team[v] == "west"
        let x = q{"x"}.getFloat
        let depth = if west: 52.0 - x else: x - 76.0
        if lay == 2: inc river
        elif (lay == 0 and west) or (lay == 1 and not west):
          if depth > 20: inc deep
          elif depth < 8: inc nearLip
        else: inc enemyBank
  cds.sort()
  echo &"{n} far enemy latches on us: in windup {windup} ({100*windup div max(n,1)}%), threw within ~15 ticks (cd>=50) {justThrew} ({100*justThrew div max(n,1)}%), in river {river}, deep (>20) {deep}, near lip (<8) {nearLip}, on enemy bank {enemyBank}; cooldown median {cds[cds.len div 2]}"


proc run_allies() =
  # Classify our ally latches: rescue (aim within 8 tiles of the ally) vs crossfire.
  var rescue, cross, games = 0
  var crossDists: seq[float]
  var crossVictimSwim, crossVictimHooked = 0
  for path in walkDirRec(paramStr(2)):
    if not path.endsWith("events.jsonl"): continue
    inc games
    var teams = initTable[int, string]()
    var mine = initTable[int, bool]()
    var launched = initTable[int, JsonNode]()
    var states: seq[JsonNode]
    var landed: seq[JsonNode]
    for line in lines(path):
      if line.len == 0: continue
      if "\"match_start\"" in line:
        for p in parseJson(line){"players"}:
          teams[p{"id"}.getInt] = p{"team"}.getStr
          mine[p{"id"}.getInt] = mineName in p{"script"}.getStr
      elif "\"hook_launched\"" in line:
        let e = parseJson(line); launched[e{"hookId"}.getInt] = e
      elif "\"hook_landed\"" in line: landed.add parseJson(line)
      elif "\"state\"" in line: states.add parseJson(line)
    for e in landed:
      let id = e{"id"}.getInt
      let v = e{"victim"}.getInt
      if not mine[id] or teams[id] != teams[v]: continue
      let h = e{"hookId"}.getInt
      if h notin launched: continue
      let aim = launched[h]{"aim"}
      let at = e{"at"}
      let d = sqrt((aim[0].getFloat - at[0].getFloat)^2 + (aim[1].getFloat - at[1].getFloat)^2)
      if d <= 8: inc rescue
      else:
        inc cross
        crossDists.add e{"dist"}.getFloat
        # victim state just before the latch
        var st: JsonNode = nil
        for s in states:
          if s{"t"}.getInt <= e{"t"}.getInt: st = s
        if st != nil:
          for q in st{"p"}:
            if q{"id"}.getInt == v:
              if q{"lay"}.getInt == 2: inc crossVictimSwim
  crossDists.sort()
  echo &"{games} games: ally latches rescue-aimed {rescue.float/games.float:.1f}/game, crossfire {cross.float/games.float:.1f}/game"
  if crossDists.len > 0:
    echo &"crossfire thrower-to-ally distance: median {crossDists[crossDists.len div 2]:.1f}, min {crossDists[0]:.1f}, max {crossDists[^1]:.1f}; ally swimming at the time {crossVictimSwim}/{cross}"


proc run_returnleg() =
  # Latches ON us: flightTicks distribution (return-leg latches exceed the outbound max ~46).
  var games = 0
  var ft: seq[int]
  var late = 0
  var lateKillsFollow = 0
  for path in walkDirRec(paramStr(2)):
    if not path.endsWith("events.jsonl"): continue
    inc games
    var mine = initTable[int, bool]()
    for line in lines(path):
      if line.len == 0: continue
      if "\"match_start\"" in line:
        for p in parseJson(line){"players"}:
          mine[p{"id"}.getInt] = mineName in p{"script"}.getStr
      elif "\"hook_landed\"" in line:
        let e = parseJson(line)
        if mine[e{"id"}.getInt] or not mine[e{"victim"}.getInt]: continue
        let f = e{"flightTicks"}.getInt
        ft.add f
        if f > 46: inc late
  ft.sort()
  echo &"{games} games, {ft.len} latches on us: flightTicks median {ft[ft.len div 2]}, q3 {ft[3*ft.len div 4]}, max {ft[^1]}; return-leg (>46 ticks): {late} = {100*late div ft.len}% = {late.float/games.float:.2f}/game"
  var hist = initCountTable[int]()
  for f in ft: hist.inc(f div 10 * 10)
  var keys: seq[int]
  for k in hist.keys: keys.add k
  keys.sort()
  var parts: seq[string]
  for k in keys: parts.add &"{k}-{k+9}:{hist[k]}"
  echo parts.join("  ")


proc run_farbank() =
  # For each death of ours on the enemy bank: ticks survived after the enemy latch that
  # dumped us, actions we issued in that span, hook cooldown at the latch, and blink use.
  type Row = object
    survived: int
    acts: CountTable[string]
    cdAtLatch: int
    blinkReadyAtLatch: bool
  var rows: seq[Row]
  var games = 0
  for path in walkDirRec(paramStr(2)):
    if not path.endsWith("events.jsonl"): continue
    inc games
    var teams = initTable[int, string]()
    var mine = initTable[int, bool]()
    var ourTeam = ""
    var events: seq[JsonNode]
    for line in lines(path):
      if line.len == 0: continue
      if "\"match_start\"" in line:
        for p in parseJson(line){"players"}:
          teams[p{"id"}.getInt] = p{"team"}.getStr
          mine[p{"id"}.getInt] = mineName in p{"script"}.getStr
          if mine[p{"id"}.getInt]: ourTeam = p{"team"}.getStr
      elif "\"ev\":\"state\"" in line or "\"hook_landed\"" in line or "\"ev\":\"kill\"" in line or "\"ev\":\"action\"" in line:
        events.add parseJson(line)
    for i, ev in events:
      if ev{"ev"}.getStr != "kill": continue
      let v = ev{"victim"}.getInt(-1)
      if not mine.getOrDefault(v): continue
      let t = ev{"t"}.getInt
      # last state before death: on enemy bank?
      var lay = -1
      var latchT = -1
      var cd = -1
      var blink = false
      for j in countdown(i - 1, 0):
        let e = events[j]
        let k = e{"ev"}.getStr
        if k == "state" and lay < 0:
          for q in e{"p"}:
            if q{"id"}.getInt == v: lay = q{"lay"}.getInt
        if k == "hook_landed" and e{"victim"}.getInt == v and not mine.getOrDefault(e{"id"}.getInt):
          latchT = e{"t"}.getInt
          # state nearest before the latch
          for m in countdown(j, 0):
            if events[m]{"ev"}.getStr == "state":
              for q in events[m]{"p"}:
                if q{"id"}.getInt == v:
                  cd = q{"cd"}.getInt
                  blink = q{"blinkReady"}.getBool(q{"blink"}.getInt(0) == 0)
              break
          break
        if t - e{"t"}.getInt > 600: break
      let enemyBank = (lay == 1 and ourTeam == "west") or (lay == 0 and ourTeam == "east")
      if not enemyBank or latchT < 0: continue
      var r = Row(survived: t - latchT, cdAtLatch: cd, blinkReadyAtLatch: blink)
      r.acts = initCountTable[string]()
      for e in events:
        if e{"ev"}.getStr == "action" and e{"id"}.getInt == v:
          let et = e{"t"}.getInt
          if et >= latchT and et <= t: r.acts.inc(e{"act"}.getStr)
      rows.add r
  echo &"{games} games, {rows.len} deaths on the enemy bank after an enemy latch"
  var surv: seq[int]
  var acts = initCountTable[string]()
  var cdReady = 0
  for r in rows:
    surv.add r.survived
    for k, n in r.acts: acts.inc(k, n)
    if r.cdAtLatch == 0: inc cdReady
  surv.sort()
  echo &"ticks from latch to death: median {surv[surv.len div 2]}, q1 {surv[surv.len div 4]}, q3 {surv[3*surv.len div 4]}; hook ready at the latch: {cdReady}/{rows.len}"
  var parts: seq[string]
  for k, n in acts: parts.add &"{k}:{n.float/rows.len.float:.1f}"
  echo "actions per death in that span: ", parts.join("  ")



proc main() =
  if paramCount() < 2:
    quit("usage: throws <denies|misses|aim|posts|onus|latchstate|allies|returnleg|farbank> <logroot> [logroot2]", 2)
  case paramStr(1)
  of "denies": run_denies()
  of "misses": run_misses()
  of "aim": run_aim()
  of "posts": run_posts()
  of "onus": run_onus()
  of "latchstate": run_latchstate()
  of "allies": run_allies()
  of "returnleg": run_returnleg()
  of "farbank": run_farbank()
  else: quit("unknown subcommand " & paramStr(1), 2)

main()
