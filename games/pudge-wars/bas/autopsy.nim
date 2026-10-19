## Death autopsy for the local BASIC ladder. For every death of one of
## OUR butchers (script name contains `mine`) it reconstructs the 200
## ticks before the kill from the 4 Hz state snapshots and the events:
## where we stood relative to our post and lip, whether we were held or
## in the river, who latched us and from how far, how far the partner
## was, and the damage that arrived by cause. Then it buckets the deaths
## so the dominant way we die is explicit.
##
##   nim r --hints:off games/pudge-wars/bas/autopsy.nim <logroot> [mine=myasnik]

import std/[os, json, strutils, strformat, tables, algorithm, math]

type
  Death = object
    game: string
    tick: int
    cause: string
    layer: string          # home / river / enemy
    heldAtDeath: bool
    lipDist: float         # tiles from our bank lip (negative = beyond it)
    partnerDist: float
    latchTicksBefore: int  # ticks from the last enemy latch on us to death (-1 none)
    latchDist: float       # thrower distance at that latch
    damage: CountTable[string]
    hpAt200: float

proc analyze(dir, mine: string, deaths: var seq[Death]) =
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
  let lipX = if ourTeam == "west": 52.0 else: 76.0
  var states: seq[JsonNode]
  for ev in events:
    if ev{"ev"}.getStr == "state": states.add ev
  for ev in events:
    if ev{"ev"}.getStr != "kill": continue
    let victim = ev{"victim"}.getInt(-1)
    if victim notin mineIds: continue
    var d = Death(game: dir.extractFilename, tick: ev{"t"}.getInt, cause: ev{"cause"}.getStr)
    d.damage = initCountTable[string]()
    d.latchTicksBefore = -1
    # last snapshot before death
    var last: JsonNode = nil
    var at200: JsonNode = nil
    for s in states:
      if s{"t"}.getInt <= d.tick: last = s
      if s{"t"}.getInt <= d.tick - 200: at200 = s
    if last != nil:
      for q in last{"p"}:
        if q{"id"}.getInt == victim:
          let lay = q{"lay"}.getInt(-1)
          d.layer =
            if lay == 2: "river"
            elif (lay == 0 and ourTeam == "west") or (lay == 1 and ourTeam == "east"): "home"
            else: "enemy"
          d.heldAtDeath = q{"hooked"}.getBool(false)
          let x = q{"x"}.getFloat
          d.lipDist = if ourTeam == "west": lipX - x else: x - lipX
          var px, py, vx, vy: float
          vx = x; vy = q{"y"}.getFloat
          for r in last{"p"}:
            if r{"id"}.getInt != victim and r{"id"}.getInt in mineIds:
              px = r{"x"}.getFloat; py = r{"y"}.getFloat
          d.partnerDist = sqrt((px - vx) * (px - vx) + (py - vy) * (py - vy))
    if at200 != nil:
      for q in at200{"p"}:
        if q{"id"}.getInt == victim: d.hpAt200 = q{"hp"}.getFloat
    for e in events:
      let t = e{"t"}.getInt
      if t < d.tick - 200 or t > d.tick: continue
      case e{"ev"}.getStr
      of "damage":
        if e{"victim"}.getInt == victim:
          d.damage.inc(e{"cause"}.getStr, e{"amount"}.getInt)
      of "hook_landed":
        if e{"victim"}.getInt == victim and teams.getOrDefault(e{"id"}.getInt) != ourTeam:
          d.latchTicksBefore = d.tick - t
          d.latchDist = e{"dist"}.getFloat
      else: discard
    deaths.add d

proc main() =
  if paramCount() < 1:
    quit("usage: autopsy <logroot> [mine=myasnik]", 2)
  let root = paramStr(1)
  let mine = if paramCount() >= 2: paramStr(2) else: "myasnik"
  var deaths: seq[Death]
  for path in walkDirRec(root):
    if path.endsWith("summary.json"):
      analyze(path.parentDir, mine, deaths)
  deaths.sort(proc(a, b: Death): int = cmp(a.game & $a.tick, b.game & $b.tick))
  echo &"{deaths.len} deaths of {mine}"
  echo "game | tick | cause | layer | held | tiles behind lip | partner dist | last enemy latch (ticks before, thrower dist) | hp 200t before | damage last 200t"
  for d in deaths:
    var dmg: seq[string]
    for k, v in d.damage: dmg.add &"{k}:{v}"
    let latch = if d.latchTicksBefore < 0: "none" else: &"{d.latchTicksBefore}t @ {d.latchDist:.0f}"
    echo &"{d.game} | {d.tick} | {d.cause} | {d.layer} | {d.heldAtDeath} | {d.lipDist:.0f} | {d.partnerDist:.0f} | {latch} | {d.hpAt200:.0f} | {dmg.join(\" \")}"
  var byLayer = initCountTable[string]()
  var byCause = initCountTable[string]()
  var latched = 0
  var held = 0
  var farPartner = 0
  var deepPost = 0
  for d in deaths:
    byLayer.inc d.layer
    byCause.inc d.cause
    if d.latchTicksBefore >= 0: inc latched
    if d.heldAtDeath: inc held
    if d.partnerDist > 30: inc farPartner
    if d.layer == "home" and d.lipDist > 10: inc deepPost
  var l, c: seq[string]
  for k, v in byLayer: l.add &"{k}:{v}"
  for k, v in byCause: c.add &"{k}:{v}"
  echo &"\nlayer {l.join(\" \")} | cause {c.join(\" \")} | preceded by an enemy latch within 200t: {latched}/{deaths.len} | held at death: {held} | partner >30 tiles away: {farPartner} | died at home >10 tiles behind the lip: {deepPost}"

main()
