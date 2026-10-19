## Headshot ceiling for the local BASIC ladder. A hook that latches an
## enemy already held by another hook kills instantly. For every latch
## OUR side makes on an enemy this reads the reel duration (matching
## hook_resolved), the partner's position and cooldown from the nearest
## state snapshot, and asks whether the partner could have put a hook
## on the victim somewhere along its reel path before the dump:
##   cooldown + 9 windup + flight(distance) <= k for some reel tick k.
## Flight uses the engine ramp: 60n + 3n^2/2 >= 100 d (after n = 40:
## 4800 + 180 (n - 40)).
##
##   nim r --hints:off games/pudge-wars/bas/headshot_ops.nim <logroot> [mine=myasnik]

import std/[os, json, strutils, strformat, tables, algorithm, math]

proc flightTicks(d: float): int =
  ## Smallest tick count whose ramped travel covers d tiles.
  let need = 100.0 * d
  var n = 1
  while true:
    let travel =
      if n <= 40: 60.0 * n.float + 1.5 * n.float * n.float
      else: 4800.0 + 180.0 * (n - 40).float
    if travel >= need: return n
    inc n
    if n > 200: return n

type
  Latch = object
    game: string
    tick: int
    reel: int
    victimDist: float     # partner to victim at the latch
    partnerCd: int
    slack: int            # best (k - needed), negative = infeasible
    outcome: string       # what the reel ended as: kill / dump / lost

proc analyze(dir, mine: string, latches: var seq[Latch]) =
  var teams = initTable[int, string]()
  var mineIds: seq[int]
  var ourTeam = ""
  var events: seq[JsonNode]
  for line in lines(dir / "events.jsonl"):
    if line.len == 0: continue
    events.add parseJson(line)
  for ev in events:
    if ev{"ev"}.getStr == "match_start":
      for p in ev{"players"}:
        let id = p{"id"}.getInt
        teams[id] = p{"team"}.getStr
        if mine in p{"script"}.getStr:
          mineIds.add id
          ourTeam = p{"team"}.getStr
      break
  var states: seq[JsonNode]
  for ev in events:
    if ev{"ev"}.getStr == "state": states.add ev
  var resolved = initTable[int, int]()   # hookId -> tick
  for ev in events:
    if ev{"ev"}.getStr == "hook_resolved":
      resolved[ev{"hookId"}.getInt] = ev{"t"}.getInt
  var kills: seq[(int, int, int)]   # tick, killer, victim
  for ev in events:
    if ev{"ev"}.getStr == "kill":
      kills.add((ev{"t"}.getInt, ev{"killer"}.getInt(-1), ev{"victim"}.getInt(-1)))
  for ev in events:
    if ev{"ev"}.getStr != "hook_landed": continue
    let thrower = ev{"id"}.getInt
    let victim = ev{"victim"}.getInt
    if thrower notin mineIds or teams.getOrDefault(victim) == ourTeam: continue
    var l = Latch(game: dir.extractFilename, tick: ev{"t"}.getInt)
    let hookId = ev{"hookId"}.getInt
    l.reel = resolved.getOrDefault(hookId, l.tick) - l.tick
    var st: JsonNode = nil
    for s in states:
      if s{"t"}.getInt <= l.tick: st = s
    if st == nil: continue
    var tx, ty, px, py: float
    var partnerFound = false
    for q in st{"p"}:
      let id = q{"id"}.getInt
      if id == thrower:
        tx = q{"x"}.getFloat; ty = q{"y"}.getFloat
      elif id in mineIds and q{"alive"}.getBool(true):
        px = q{"x"}.getFloat; py = q{"y"}.getFloat
        l.partnerCd = q{"cd"}.getInt
        partnerFound = true
    if not partnerFound:
      l.slack = -999
      latches.add l
      continue
    let ax = ev{"at"}[0].getFloat
    let ay = ev{"at"}[1].getFloat
    l.victimDist = sqrt((px - ax) * (px - ax) + (py - ay) * (py - ay))
    l.slack = -999
    for k in 1 .. max(l.reel, 1):
      let f = k.float / max(l.reel, 1).float
      let vx = ax + (tx - ax) * f
      let vy = ay + (ty - ay) * f
      let d = sqrt((px - vx) * (px - vx) + (py - vy) * (py - vy))
      let needed = l.partnerCd + 9 + flightTicks(d)
      l.slack = max(l.slack, k - needed)
    l.outcome = "dump"
    for (t, killer, v) in kills:
      if v == victim and t >= l.tick and t <= l.tick + l.reel + 2:
        l.outcome = "kill"
    latches.add l

proc main() =
  if paramCount() < 1:
    quit("usage: headshot_ops <logroot> [mine=myasnik]", 2)
  let root = paramStr(1)
  let mine = if paramCount() >= 2: paramStr(2) else: "myasnik"
  var latches: seq[Latch]
  for path in walkDirRec(root):
    if path.endsWith("summary.json"):
      analyze(path.parentDir, mine, latches)
  echo &"{latches.len} latches by {mine} on enemies"
  var feasible, feasibleReady, kill = 0
  var slacks: seq[int]
  var reels: seq[int]
  var dists: seq[float]
  for l in latches:
    reels.add l.reel
    dists.add l.victimDist
    if l.outcome == "kill": inc kill
    if l.slack >= 0:
      inc feasible
      slacks.add l.slack
      if l.partnerCd == 0: inc feasibleReady
  reels.sort()
  dists.sort()
  slacks.sort()
  if latches.len > 0:
    echo &"reel ticks median {reels[reels.len div 2]} | partner-to-victim tiles median {dists[dists.len div 2]:.0f}"
    echo &"latch already a kill (200 dmg finish): {kill} | headshot feasible: {feasible} ({100 * feasible div latches.len}%), of which partner hook ready: {feasibleReady}"
    if slacks.len > 0:
      echo &"slack ticks when feasible: median {slacks[slacks.len div 2]}, min {slacks[0]}, max {slacks[^1]}"
  var bands = initCountTable[string]()
  for l in latches:
    let b =
      if l.slack < 0: "infeasible"
      elif l.slack < 5: "slack 0-4"
      elif l.slack < 15: "slack 5-14"
      else: "slack 15+"
    bands.inc b
  var parts: seq[string]
  for k, v in bands: parts.add &"{k}:{v}"
  echo parts.join("  ")

main()
