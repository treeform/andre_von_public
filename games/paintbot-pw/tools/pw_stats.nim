## Paintbot PW player statistics from hosted replays.
##
##   nim c -d:release -d:ssl -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw-0124/examples/paintbot --path:$HOME/p/paintbot-pw-0124/src \
##     -o:tools/pw_stats tools/pw_stats.nim
##   tools/pw_stats [--md PATH] [--html PATH] [--title TEXT] <dirs or json files>...
##   tools/pw_stats --grouped --ours zhar:v48 --columns zhar:v48,a:v1,b:v2,c:v3 --md P <pw_fast dirs>
##
## --grouped prints the three groups the user asked for (controlled directly, controlled
## indirectly, outcomes) with the rivals' mean, our gap to it and a flag, plus a list of
## the largest gaps in what we control. --ours names every pw_fast tag (our side) with one
## label so several tags merge into one column; --columns fixes the column order.
##
## pw_fast directories (eps/fast/<tag>) work too: seats are the tag on our
## side and the rival named in each batch directory.
##
## Every *.replay under the given directories is re-simulated with the
## engine (state hash checked each tick). Seats are joined to policies
## through any episode listing JSON found among the inputs (`coworld
## replays --json` output, or cached `xp-request get` JSON), and labels
## come from eps/names.txt (policy version id, label). Every row is a mean
## over the policy's seat-games (one cog for one match), except the league
## rows which count each team-game once. Policies are grouped by player
## label prefix only when --by-version is absent: versions stay separate.

import
  std/[algorithm, json, math, os, sequtils, strformat, strutils, tables],
  game, sim

const
  NoTeammate = 99_999.0
  RangeEdges = [1000, 2000, 3000, 4500, 100000]

type
  Seat = object
    ## One cog's counters for one match.
    won, drew, lost: bool
    glory, seconds: float
    gunShots, gunHits, gunKills: int
    grenadeThrows, grenadeHits, grenadeKills: int
    selfDestructs: int
    sprayBursts, sprayHits, sprayKills: int
    friendlyDamage, damageDealt, damageTaken: int
    kills, deaths: int
    deathsInWater, deathsInTrench, deathsOnHigh: int
    hitsFromHigh, hitsFromWater, hitsFromTrench: int
    livesLeft: int
    firstShotTick, firstDeathTick: int
    pickups: array[PickupKind, int]
    misterHeals: int
    gloryHearts: int
    captures: int
    aliveTicks, wadingTicks, sneakTicks, trenchTicks, highTicks: int
    movingTicks, ringTicks, enemyInViewTicks: int
    travelled: float
    teammateSum: float
    teammateSamples: int
    walkOrders, shootOrders, directOrders, grenadeCharges: int
    rangeShots, rangeHits: array[5, int]
    stillShots, stillHits, movingShots, movingHits: int
    upShots, upHits, levelShots, levelHits, downShots, downHits: int
    blindShots, blindHits: int
    missCover, missDodged, missAim, missInRadius, missTeammate, missNothing: int
    contactTicks, contactStand, contactReversals, contactStops, runTicks, runCount: int
    leadOrders, leadZeroOrders: int
    targetOrders, targetInView, targetTracked: int
    seenPairTicks, sightings: int
    compassSteps: int
    leadSum: float

  Stat = object
    ## Running sums for one policy.
    seats: seq[Seat]
    games, wins, draws: int
    gloryWins: seq[float]

  Row = object
    section, label, unit, definition: string
    value: proc(s: Stat): float
    digits: int

var
  names = initTable[string, string]()
  rosters = initTable[string, seq[string]]()
  hashFailures = 0
  current: ptr seq[Seat]
  gunHit: array[MaxSeats, bool]
  shotsThisTick: seq[int]
  oursLabel = ""

proc loadNames() =
  ## Reads policy version id to label pairs.
  for path in ["eps/names.txt"]:
    if fileExists(path):
      for line in lines(path):
        let parts = line.splitWhitespace
        if parts.len == 2:
          names[parts[0]] = parts[1]

proc addListing(node: JsonNode) =
  ## Records the seat roster of every episode in a listing.
  var entries: seq[JsonNode]
  if node.kind == JArray:
    entries = node.getElems
  elif node.hasKey("entries"):
    entries = node["entries"].getElems
  elif node.hasKey("episodes"):
    entries = node["episodes"].getElems
  for e in entries:
    let ids = e{"policy_version_ids"}
    if ids == nil or ids.kind != JArray:
      continue
    rosters[e["id"].getStr] = ids.getElems.mapIt(it.getStr)
    for p in e{"participants"}.getElems:
      names[p["policy_version_id"].getStr] =
        p["policy_name"].getStr & ":v" & $p["version"].getInt

proc label(id: string): string =
  ## Returns a policy label for a policy version id.
  names.getOrDefault(id, id[0 ..< min(8, id.len)])

proc inWater(p: Point): bool =
  ## Returns true when a point is in wading water.
  riverBlend(p.x.int, p.z.int) > 0 and
    terrainHeight(p.x.int, p.z.int) < RiverWaterHeight

proc onHigh(p: Point): bool =
  ## Returns true on high ground as the training telemetry defines it.
  terrainHeight(p.x.int, p.z.int) >= HighGroundHeight

proc distance(a, b: Point): float =
  ## Returns the planar distance in world units.
  sqrt(distance2(a, b).float)

proc misted(cogs: openArray[Cog], misterUntil: openArray[int32], i: int): bool =
  ## Whether a living windex-mister stood within its heal radius of cog i (rules 49).
  for r in 0 ..< misterUntil.len:
    if misterUntil[r] > 0 and cogs[r].hp > 0 and
      distance2(cogs[r].pos, cogs[i].pos) <= MisterRadius.int64 * MisterRadius:
        return true
  false

proc observeDamage(w: World, victim, attacker: int, removed: int32, killed: bool) {.nimcall, gcsafe.} =
  ## Splits enemy damage by weapon and records friendly damage.
  {.cast(gcsafe).}:
    if attacker < 0 or attacker == victim:
      return
    if team(attacker) == team(victim):
      current[][attacker].friendlyDamage += removed
      return
    current[][attacker].damageDealt += removed
    current[][victim].damageTaken += removed
    case damageWeapon
    of dwGun:
      inc current[][attacker].gunHits
      gunHit[attacker] = true
    of dwGrenade:
      inc current[][attacker].grenadeHits
    of dwSpray:
      inc current[][attacker].sprayHits
    of dwNone:
      discard

proc shotReport(w: World, slot: int, before, previous: seq[Cog], aim: Point,
    ordered: seq[Point], hit: bool, s: var Seat) =
  ## Files one released gun shot: range, footing, height, and why it missed
  ## (cover in the way, a teammate first, the target in radius but saved by a
  ## trench or a blocked sight line, the target moving off the line during the
  ## windup, aim off a still target, or nobody near the line).
  let origin = w.cogs[slot].pos
  var
    target = -1
    best = int64.high
  for j in 0 ..< Seats:
    if team(j) != team(slot) and before[j].hp > 0 and w.visible(slot, j):
      let d = distance2(before[slot].pos, before[j].pos)
      if d < best:
        best = d
        target = j
  if target < 0:
    inc s.blindShots
    if hit:
      inc s.blindHits
    return
  var bucket = 0
  while sqrt(best.float) > RangeEdges[bucket].float:
    inc bucket
  inc s.rangeShots[bucket]
  if hit:
    inc s.rangeHits[bucket]
  if distance2(previous[slot].pos, before[slot].pos) > 16:
    inc s.movingShots
    if hit: inc s.movingHits
  else:
    inc s.stillShots
    if hit: inc s.stillHits
  let rise = terrainHeight(origin.x.int, origin.z.int) -
    terrainHeight(before[target].pos.x.int, before[target].pos.z.int)
  if rise > 50:
    inc s.upShots
    if hit: inc s.upHits
  elif rise < -50:
    inc s.downShots
    if hit: inc s.downHits
  else:
    inc s.levelShots
    if hit: inc s.levelHits
  if hit:
    return
  let length = sqrt(float(aim.x) ^ 2 + float(aim.z) ^ 2)
  if length < 1:
    inc s.missNothing
    return
  let
    ux = float(aim.x) / length
    uz = float(aim.z) / length
  var
    nearest = -1
    nearestAcross = 1e18
    nearestAlong = 0.0
  for j in 0 ..< Seats:
    if j == slot or w.cogs[j].hp <= 0:
      continue
    let
      dx = float(w.cogs[j].pos.x - origin.x)
      dz = float(w.cogs[j].pos.z - origin.z)
      along = dx * ux + dz * uz
      across = abs(dx * uz - dz * ux)
    if along <= 0 or along > 5250:
      continue
    if team(j) == team(slot):
      if across < Radius.float:
        inc s.missTeammate
        return
      continue
    if across < nearestAcross:
      nearest = j
      nearestAcross = across
      nearestAlong = along
  if nearest < 0 or nearestAcross > 600:
    inc s.missNothing
    return
  var step = 20.0
  while step < nearestAlong - Radius.float:
    if w.blocked(point(origin.x.int + int(ux * step), origin.z.int + int(uz * step)), 0):
      inc s.missCover
      return
    step += 20
  if nearestAcross <= Radius.float:
    inc s.missInRadius
  elif nearest < ordered.len and distance2(ordered[nearest], w.cogs[nearest].pos) > 900:
    inc s.missDodged
  else:
    inc s.missAim

proc analyze(path: string): seq[Seat] =
  ## Re-simulates one replay and returns one Seat per slot.
  let recording = loadRecording(path)
  var w = newWorld(recording.seed, recording.endTick)
  result = newSeq[Seat](Seats)
  for s in result.mitems:
    s.firstShotTick = -1
    s.firstDeathTick = -1
  current = addr result
  var
    telemetry: CombatTelemetry
    lastGloryTick = -1
    orderAim: array[MaxSeats, Point]
    orderPositions: array[MaxSeats, seq[Point]]
    previous = w.cogs
    runLength: array[MaxSeats, int]
    runX, runZ: array[MaxSeats, int32]
    seenNow, seenBefore: array[MaxSeats, array[MaxSeats, bool]]
  for i in 0 ..< Seats:
    for j in 0 ..< Seats:
      seenNow[i][j] = team(j) != team(i) and w.visible(i, j)
  combatTelemetry = addr telemetry
  observeShot = proc(tick: int32, slot: int) =
    inc current[][slot].gunShots
    shotsThisTick.add slot
    if current[][slot].firstShotTick < 0:
      current[][slot].firstShotTick = tick
  damageObserver = observeDamage
  defer:
    combatTelemetry = nil
    observeShot = nil
    damageObserver = nil
  for frame in recording.frames:
    let
      before = w.cogs
      equipment = w.equipment
      uniforms = w.uniforms
      sniper = w.sniper
      misterUntil = w.misterUntil
      radarUntil = w.radarUntil
    var captures: seq[int32]
    for c in w.cogs:
      captures.add c.captures
    for i in 0 ..< Seats:
      let command = frame.commands[i]
      if w.cogs[i].hp <= 0:
        continue
      if command.walk:
        inc result[i].walkOrders
      if command.shoot:
        inc result[i].shootOrders
      if command.direct:
        inc result[i].directOrders
      if command.chargeGrenade:
        inc result[i].grenadeCharges
      if command.sneak:
        inc result[i].sneakTicks
    for i in 0 ..< Seats:
      let c = frame.commands[i]
      if c.shoot and before[i].hp > 0 and before[i].cooldown == 0 and
          w.equipment[i].windup == 0 and not w.equipment[i].sprayCan:
        orderAim[i] = point(c.aim.x - before[i].pos.x, c.aim.z - before[i].pos.z)
        orderPositions[i] = before.mapIt(it.pos)
      if c.shoot and before[i].hp > 0 and before[i].cooldown <= 1 and
          w.equipment[i].windup == 0 and not w.equipment[i].sprayCan:
        # Lead: the aim offset from the enemy nearest the aim point, along its last step.
        var
          target = -1
          nearest = 250_000'i64
        for j in 0 ..< Seats:
          if team(j) != team(i) and before[j].hp > 0:
            let d = distance2(c.aim, before[j].pos)
            if d < nearest:
              nearest = d
              target = j
        if target >= 0:
          # Tracking: was the target in view now, and also on the tick before?
          inc result[i].targetOrders
          if seenNow[i][target]:
            inc result[i].targetInView
            if seenBefore[i][target]:
              inc result[i].targetTracked
          let
            stepX = (before[target].pos.x - previous[target].pos.x).float
            stepZ = (before[target].pos.z - previous[target].pos.z).float
            speed2 = stepX * stepX + stepZ * stepZ
          if speed2 >= 64 and speed2 < 3600:
            let lead = ((c.aim.x - before[target].pos.x).float * stepX +
              (c.aim.z - before[target].pos.z).float * stepZ) / speed2
            inc result[i].leadOrders
            result[i].leadSum += clamp(lead, -2.0, 10.0)
            if lead < 0.5:
              inc result[i].leadZeroOrders
      gunHit[i] = false
    shotsThisTick.setLen(0)
    w.step(frame.commands, replayRulesVersion)
    if w.stateHash() != frame.hash:
      inc hashFailures
    for slot in shotsThisTick:
      shotReport(w, slot, before, previous, orderAim[slot], orderPositions[slot], gunHit[slot], result[slot])
    previous = before
    seenBefore = seenNow
    for i in 0 ..< Seats:
      for j in 0 ..< Seats:
        seenNow[i][j] = team(j) != team(i) and w.cogs[i].hp > 0 and w.visible(i, j)
        if seenNow[i][j]:
          inc result[i].seenPairTicks
          if not seenBefore[i][j]:
            inc result[i].sightings
    let tick = w.tick.int
    for i in 0 ..< Seats:
      var s = addr result[i]
      let
        c = w.cogs[i]
        e = w.equipment[i]
      if before[i].hp > 0 and c.hp <= 0:
        inc s.deaths
        if s.firstDeathTick < 0:
          s.firstDeathTick = tick
        if inWater(before[i].pos):
          inc s.deathsInWater
        if w.trenchAt(before[i].pos) >= 0:
          inc s.deathsInTrench
        if onHigh(before[i].pos):
          inc s.deathsOnHigh
      if frame.commands[i].selfDestruct and before[i].hp > 0 and c.hp <= 0:
        inc s.selfDestructs
      if c.hp <= 0:
        continue
      if before[i].hp > 0:
        if e.grenade and not equipment[i].grenade:
          inc s.pickups[grenadePickup]
        if e.sprayCan and not equipment[i].sprayCan:
          inc s.pickups[sprayPickup]
        if e.armor > equipment[i].armor:
          inc s.pickups[armorPickup]
        if c.hp > before[i].hp:
          # Rules 49: a windex-mister heals 1 HP at a time; anything else is a medkit.
          if c.hp - before[i].hp == 1 and misted(before, misterUntil, i):
            inc s.misterHeals
          else:
            inc s.pickups[medkitPickup]
        if w.uniforms[i] and not uniforms[i]:
          inc s.pickups[uniformPickup]
        if w.sniper[i] and not sniper[i]:
          inc s.pickups[sniperPickup]
        if w.misterUntil[i] > 0 and misterUntil[i] == 0:
          inc s.pickups[misterPickup]
        if w.radarUntil[i] > 0 and radarUntil[i] == 0:
          inc s.pickups[radarPickup]
        if equipment[i].grenade and not e.grenade and e.lives == equipment[i].lives:
          inc s.grenadeThrows
        if e.burst == SprayTicks - 1 and equipment[i].burst == 0:
          inc s.sprayBursts
        let step = distance(before[i].pos, c.pos)
        s.travelled += step
        if step > 4:
          inc s.movingTicks
          let
            ax = abs(c.pos.x - before[i].pos.x)
            az = abs(c.pos.z - before[i].pos.z)
          if (ax == 28 and az == 0) or (ax == 0 and az == 28) or (ax == 19 and az == 19):
            inc s.compassSteps
        # Footwork with an enemy in sight: runs of steps in one direction, ended by a
        # reversal or by standing.
        var inSight = false
        for j in 0 ..< Seats:
          if team(j) != team(i) and w.cogs[j].hp > 0 and w.visible(i, j):
            inSight = true
            break
        if inSight:
          inc s.contactTicks
          let
            dx = c.pos.x - before[i].pos.x
            dz = c.pos.z - before[i].pos.z
          if dx * dx + dz * dz < 64:
            inc s.contactStand
            if runLength[i] > 0:
              inc s.contactStops
              s.runTicks += runLength[i]
              inc s.runCount
            runLength[i] = 0
          elif runLength[i] > 0 and dx * runX[i] + dz * runZ[i] > 0:
            inc runLength[i]
            runX[i] = dx
            runZ[i] = dz
          else:
            if runLength[i] > 0:
              inc s.contactReversals
              s.runTicks += runLength[i]
              inc s.runCount
            runLength[i] = 1
            runX[i] = dx
            runZ[i] = dz
        else:
          runLength[i] = 0
      else:
        runLength[i] = 0
      inc s.aliveTicks
      if inWater(c.pos):
        inc s.wadingTicks
      if w.trenchAt(c.pos) >= 0:
        inc s.trenchTicks
      if onHigh(c.pos):
        inc s.highTicks
      if c.captures > captures[i]:
        s.captures += c.captures - captures[i]
      for h in w.controlHearts:
        if distance2(c.pos, h.pos) <= ControlHeartRadius.int64 * ControlHeartRadius:
          inc s.ringTicks
          break
      if tick mod 12 == 0:
        var
          nearest = NoTeammate
          seen = false
        for j in 0 ..< Seats:
          if j == i or w.cogs[j].hp <= 0:
            continue
          if team(j) == team(i):
            nearest = min(nearest, distance(c.pos, w.cogs[j].pos))
          elif w.visible(i, j):
            seen = true
        if nearest < NoTeammate:
          s.teammateSum += nearest
          inc s.teammateSamples
        if seen:
          s.enemyInViewTicks += 12
    for pickup in w.gloryPickups:
      if pickup.tick > lastGloryTick:
        inc result[pickup.seat].gloryHearts
    for pickup in w.gloryPickups:
      lastGloryTick = max(lastGloryTick, pickup.tick.int)
  let
    finalScores = w.scores()
    seconds = w.tick.float / TickRate.float
  for i in 0 ..< Seats:
    var s = addr result[i]
    let t = telemetry[i]
    s.kills = t.kills
    s.gunKills = t.gunKills
    s.grenadeKills = t.grenadeKills
    s.sprayKills = t.weaponSprayKills
    s.hitsFromHigh = t.hitsFromHigh
    s.hitsFromWater = t.hitsFromWater
    s.hitsFromTrench = t.hitsFromTrench
    s.livesLeft = w.equipment[i].lives + (if w.cogs[i].hp > 0: 1 else: 0)
    s.glory = finalScores[i]
    s.seconds = seconds
    let enemy = finalScores[(i + 1) mod 2]
    s.won = s.glory > 0
    s.lost = enemy > 0
    s.drew = not s.won and not s.lost

proc findInputs(inputs: seq[string]): seq[string] =
  ## Loads listings and returns every replay path.
  for input in inputs:
    if dirExists(input):
      for path in walkDirRec(input):
        if path.endsWith(".json"):
          try:
            addListing(parseJson(readFile(path)))
          except CatchableError:
            discard
        elif path.endsWith(".replay"):
          result.add path
    elif input.endsWith(".json"):
      addListing(parseJson(readFile(input)))
    elif input.endsWith(".replay"):
      result.add input

proc per(s: Stat, f: proc(x: Seat): float): float =
  ## Returns the mean of one seat quantity.
  if s.seats.len == 0:
    return NaN
  s.seats.mapIt(f(it)).sum / s.seats.len.float

proc ratio(s: Stat, a, b: proc(x: Seat): float): float =
  ## Returns sum(a) / sum(b) over seats.
  let
    top = s.seats.mapIt(a(it)).sum
    bottom = s.seats.mapIt(b(it)).sum
  if bottom == 0:
    return NaN
  top / bottom

proc rows(): seq[Row] =
  ## The table rows, grouped by section.
  template r(sec, lab, un, def: string, d: int, body: untyped): untyped =
    result.add Row(section: sec, label: lab, unit: un, definition: def, digits: d,
      value: proc(s {.inject.}: Stat): float = body)
  r("League", "games", "", "Team-games seen in these replays.", 0):
    s.games.float
  r("League", "win rate", "%", "Team-games won, over all team-games.", 1):
    100.0 * s.wins.float / max(s.games, 1).float
  r("League", "draw rate", "%", "Team-games drawn.", 1):
    100.0 * s.draws.float / max(s.games, 1).float
  r("League", "glory per game", "", "Winner's glory, zero on a loss or draw, per team-game (the ladder input).", 0):
    s.gloryWins.sum / max(s.games, 1).float
  r("League", "glory per win", "", "Mean glory in games won: how fast the wins are.", 0):
    (if s.gloryWins.len == 0: NaN else: s.gloryWins.sum / s.gloryWins.len.float)
  r("League", "match length", "s", "Seconds until the match ended.", 0):
    s.per(proc(x: Seat): float = x.seconds)
  r("Survival", "deaths", "/cog", "Lives lost per cog per match (one life from rules 49, four before).", 2):
    s.per(proc(x: Seat): float = x.deaths.float)
  r("Survival", "lives left", "/cog", "Lives the cog still had at the end, counting the one on the field.", 2):
    s.per(proc(x: Seat): float = x.livesLeft.float)
  r("Survival", "first death", "s", "Seconds to the cog's first death (cogs that never died excluded).", 1):
    let d = s.seats.filterIt(it.firstDeathTick >= 0)
    (if d.len == 0: NaN else: d.mapIt(it.firstDeathTick.float).sum / d.len.float / 24.0)
  r("Survival", "deaths in water", "%", "Share of deaths while wading.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.deathsInWater.float, proc(x: Seat): float = x.deaths.float)
  r("Survival", "deaths in trench", "%", "Share of deaths inside a trench.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.deathsInTrench.float, proc(x: Seat): float = x.deaths.float)
  r("Survival", "damage taken", "/cog", "Enemy damage removed from this cog (armor excluded).", 2):
    s.per(proc(x: Seat): float = x.damageTaken.float)
  r("Combat", "kills", "/cog", "Enemy cogs this cog killed.", 2):
    s.per(proc(x: Seat): float = x.kills.float)
  r("Combat", "kill/death", "", "Kills over deaths.", 2):
    s.ratio(proc(x: Seat): float = x.kills.float, proc(x: Seat): float = x.deaths.float)
  r("Combat", "damage dealt", "/cog", "Health removed from enemies.", 2):
    s.per(proc(x: Seat): float = x.damageDealt.float)
  r("Combat", "gun kills", "%", "Share of kills made with the gun.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.gunKills.float, proc(x: Seat): float = x.kills.float)
  r("Combat", "grenade kills", "%", "Share of kills made with grenades.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.grenadeKills.float, proc(x: Seat): float = x.kills.float)
  r("Combat", "spray kills", "%", "Share of kills made with spray.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.sprayKills.float, proc(x: Seat): float = x.kills.float)
  r("Combat", "friendly damage", "/cog", "Health removed from teammates.", 2):
    s.per(proc(x: Seat): float = x.friendlyDamage.float)
  r("Combat", "enemy in view", "%", "Alive time with an enemy in this cog's own sight.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.enemyInViewTicks.float, proc(x: Seat): float = x.aliveTicks.float)
  r("Shooting", "gun shots", "/min", "Gun rays fired per minute alive.", 1):
    60.0 * 24.0 * s.ratio(proc(x: Seat): float = x.gunShots.float, proc(x: Seat): float = x.aliveTicks.float)
  r("Shooting", "gun accuracy", "%", "Enemy gun hits over gun shots.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.gunHits.float, proc(x: Seat): float = x.gunShots.float)
  r("Shooting", "first shot", "s", "Seconds to the cog's first gun shot.", 1):
    let d = s.seats.filterIt(it.firstShotTick >= 0)
    (if d.len == 0: NaN else: d.mapIt(it.firstShotTick.float).sum / d.len.float / 24.0)
  r("Shooting", "shots with no enemy in view", "%", "Gun shots released while no enemy was in the cog's sight.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.blindShots.float, proc(x: Seat): float = x.gunShots.float)
  r("Shooting", "accuracy with no enemy in view", "%", "Hit rate of gun shots released while no enemy was in the cog's sight (pre-aimed shots).", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.blindHits.float, proc(x: Seat): float = x.blindShots.float)
  r("Shooting", "range under 20 m", "%", "Share of aimed shots whose nearest visible enemy was under 20 m.", 1):
    100.0 * s.ratio(proc(x: Seat): float = float(x.rangeShots[0] + x.rangeShots[1]), proc(x: Seat): float = float(x.rangeShots.sum))
  r("Shooting", "accuracy 0-10 m", "%", "Hit rate of aimed shots by the range to the nearest visible enemy.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.rangeHits[0].float, proc(x: Seat): float = x.rangeShots[0].float)
  r("Shooting", "accuracy 10-20 m", "%", "Hit rate of aimed shots by range.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.rangeHits[1].float, proc(x: Seat): float = x.rangeShots[1].float)
  r("Shooting", "accuracy 20-30 m", "%", "Hit rate of aimed shots by range.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.rangeHits[2].float, proc(x: Seat): float = x.rangeShots[2].float)
  r("Shooting", "accuracy 30-45 m", "%", "Hit rate of aimed shots by range.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.rangeHits[3].float, proc(x: Seat): float = x.rangeShots[3].float)
  r("Shooting", "accuracy 45+ m", "%", "Hit rate of aimed shots by range.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.rangeHits[4].float, proc(x: Seat): float = x.rangeShots[4].float)
  r("Shooting", "shots fired standing", "%", "Aimed shots released while the shooter did not move the tick before.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.stillShots.float, proc(x: Seat): float = float(x.stillShots + x.movingShots))
  r("Shooting", "accuracy standing", "%", "Hit rate of shots fired standing.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.stillHits.float, proc(x: Seat): float = x.stillShots.float)
  r("Shooting", "accuracy moving", "%", "Hit rate of shots fired on the move.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.movingHits.float, proc(x: Seat): float = x.movingShots.float)
  r("Shooting", "shots from above", "%", "Aimed shots from at least 0.5 m above the target.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.upShots.float, proc(x: Seat): float = float(x.upShots + x.levelShots + x.downShots))
  r("Shooting", "accuracy from above", "%", "Hit rate from at least 0.5 m above the target (less spread).", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.upHits.float, proc(x: Seat): float = x.upShots.float)
  r("Shooting", "accuracy level", "%", "Hit rate within 0.5 m of the target's height.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.levelHits.float, proc(x: Seat): float = x.levelShots.float)
  r("Shooting", "accuracy from below", "%", "Hit rate from at least 0.5 m below the target (more spread).", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.downHits.float, proc(x: Seat): float = x.downShots.float)
  r("Shooting", "hits from high ground", "%", "Enemy hits dealt while standing on high ground.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.hitsFromHigh.float, proc(x: Seat): float = (x.gunHits + x.grenadeHits + x.sprayHits).float)
  r("Shooting", "hits from trench", "%", "Enemy hits dealt from inside a trench.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.hitsFromTrench.float, proc(x: Seat): float = (x.gunHits + x.grenadeHits + x.sprayHits).float)
  r("Shooting", "miss: cover in the way", "%", "Share of aimed shots stopped by cover or scenery before the nearest enemy on the line.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.missCover.float, proc(x: Seat): float = float(x.rangeShots.sum))
  r("Shooting", "miss: target moved off the line", "%", "Share of aimed shots that passed a target that moved more than 0.3 m during the windup.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.missDodged.float, proc(x: Seat): float = float(x.rangeShots.sum))
  r("Shooting", "miss: aim off a still target", "%", "Share of aimed shots that passed a target that barely moved during the windup.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.missAim.float, proc(x: Seat): float = float(x.rangeShots.sum))
  r("Shooting", "miss: in radius, no hit", "%", "Share of aimed shots that crossed an enemy but did not hit (trench cover or a blocked sight line).", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.missInRadius.float, proc(x: Seat): float = float(x.rangeShots.sum))
  r("Shooting", "miss: teammate in the way", "%", "Share of aimed shots whose line crossed a teammate first.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.missTeammate.float, proc(x: Seat): float = float(x.rangeShots.sum))
  r("Shooting", "miss: nobody near the line", "%", "Share of aimed shots that passed no cog within 6 m.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.missNothing.float, proc(x: Seat): float = float(x.rangeShots.sum))
  r("Items", "grenades picked", "/cog", "Grenade pickups.", 2):
    s.per(proc(x: Seat): float = x.pickups[grenadePickup].float)
  r("Items", "grenades thrown", "/cog", "Grenades released.", 2):
    s.per(proc(x: Seat): float = x.grenadeThrows.float)
  r("Items", "self-destructs", "/cog", "Cogs that blew themselves up.", 2):
    s.per(proc(x: Seat): float = x.selfDestructs.float)
  r("Items", "grenade hits", "/throw", "Enemy cogs damaged per grenade thrown.", 2):
    s.ratio(proc(x: Seat): float = x.grenadeHits.float, proc(x: Seat): float = x.grenadeThrows.float)
  r("Items", "spray cans", "/cog", "Spray can pickups.", 2):
    s.per(proc(x: Seat): float = x.pickups[sprayPickup].float)
  r("Items", "spray bursts", "/cog", "Spray bursts fired.", 2):
    s.per(proc(x: Seat): float = x.sprayBursts.float)
  r("Items", "armor", "/cog", "Shield (armor) pickups.", 2):
    s.per(proc(x: Seat): float = x.pickups[armorPickup].float)
  r("Items", "medkits", "/cog", "Medkit heals.", 2):
    s.per(proc(x: Seat): float = x.pickups[medkitPickup].float)
  r("Items", "mister heals", "/cog", "HP healed by a windex-mister, own or anyone's (rules 49).", 2):
    s.per(proc(x: Seat): float = x.misterHeals.float)
  r("Items", "glory hearts", "/cog", "Glory hearts picked up (+20 glory each).", 2):
    s.per(proc(x: Seat): float = x.gloryHearts.float)
  r("Items", "uniforms", "/cog", "Uniform (disguise) pickups.", 2):
    s.per(proc(x: Seat): float = x.pickups[uniformPickup].float)
  r("Items", "sniper rifles", "/cog", "Sniper rifle pickups (rules 49).", 2):
    s.per(proc(x: Seat): float = x.pickups[sniperPickup].float)
  r("Items", "windex-misters", "/cog", "Windex-mister pickups (rules 49).", 2):
    s.per(proc(x: Seat): float = x.pickups[misterPickup].float)
  r("Items", "radars", "/cog", "Radar pickups (rules 49).", 2):
    s.per(proc(x: Seat): float = x.pickups[radarPickup].float)
  r("Movement", "speed", "m/s", "Metres travelled per second alive.", 2):
    24.0 / 100.0 * s.ratio(proc(x: Seat): float = x.travelled, proc(x: Seat): float = x.aliveTicks.float)
  r("Movement", "moving", "%", "Alive ticks spent moving.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.movingTicks.float, proc(x: Seat): float = x.aliveTicks.float)
  r("Movement", "wading", "%", "Alive ticks in water.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.wadingTicks.float, proc(x: Seat): float = x.aliveTicks.float)
  r("Movement", "sneaking", "%", "Alive ticks with sneak on.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.sneakTicks.float, proc(x: Seat): float = x.aliveTicks.float)
  r("Movement", "in trench", "%", "Alive ticks inside a trench.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.trenchTicks.float, proc(x: Seat): float = x.aliveTicks.float)
  r("Movement", "high ground", "%", "Alive ticks on high ground.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.highTicks.float, proc(x: Seat): float = x.aliveTicks.float)
  r("Movement", "exact compass steps", "%", "Moving ticks whose step is exactly (28, 0), (0, 28) or (19, 19) in size: the neural decoder's 2 m compass goals.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.compassSteps.float, proc(x: Seat): float = x.movingTicks.float)
  r("Movement", "nearest teammate", "m", "Mean distance to the nearest living teammate.", 1):
    s.ratio(proc(x: Seat): float = x.teammateSum, proc(x: Seat): float = x.teammateSamples.float) / 100.0
  r("Footwork", "lead on a moving target", "ticks", "Mean aim offset from a moving target along its last step, in steps.", 1):
    s.ratio(proc(x: Seat): float = x.leadSum, proc(x: Seat): float = x.leadOrders.float)
  r("Footwork", "sight run length", "ticks", "Mean ticks an enemy stays continuously in view once seen (per enemy).", 1):
    s.ratio(proc(x: Seat): float = x.seenPairTicks.float, proc(x: Seat): float = x.sightings.float)
  r("Footwork", "new sightings", "/min", "Times an enemy comes (back) into view, per minute alive.", 1):
    60.0 * TickRate.float * s.ratio(proc(x: Seat): float = x.sightings.float, proc(x: Seat): float = x.aliveTicks.float)
  r("Footwork", "shots at a target in view", "%", "Gun orders whose target (the enemy nearest the aim point) the shooter could see.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.targetInView.float, proc(x: Seat): float = x.targetOrders.float)
  r("Footwork", "shots at a tracked target", "%", "Gun orders whose target the shooter also saw on the tick before (a step to lead from).", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.targetTracked.float, proc(x: Seat): float = x.targetOrders.float)
  r("Footwork", "unled shots at movers", "%", "Gun orders at a moving target aimed less than half a step ahead.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.leadZeroOrders.float, proc(x: Seat): float = x.leadOrders.float)
  r("Footwork", "standing with an enemy in sight", "%", "Ticks with an enemy in view spent not moving.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.contactStand.float, proc(x: Seat): float = x.contactTicks.float)
  r("Footwork", "run length in sight", "ticks", "Mean ticks moving one way before reversing or stopping.", 1):
    s.ratio(proc(x: Seat): float = x.runTicks.float, proc(x: Seat): float = x.runCount.float)
  r("Footwork", "runs ended by reversing", "%", "Runs ended by turning back rather than standing.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.contactReversals.float, proc(x: Seat): float = x.runCount.float)
  r("Footwork", "direction changes in sight", "/s", "Reversals plus stops per second with an enemy in view.", 2):
    TickRate.float * s.ratio(proc(x: Seat): float = (x.contactReversals + x.contactStops).float,
      proc(x: Seat): float = x.contactTicks.float)
  r("Territory", "captures", "/cog", "Heart captures completed by this cog.", 2):
    s.per(proc(x: Seat): float = x.captures.float)
  r("Territory", "in a heart ring", "%", "Alive ticks within 140 units of a heart.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.ringTicks.float, proc(x: Seat): float = x.aliveTicks.float)
  r("Orders", "walk orders", "%", "Alive ticks with a walk order.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.walkOrders.float, proc(x: Seat): float = x.aliveTicks.float)
  r("Orders", "shoot orders", "%", "Alive ticks with a shoot order.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.shootOrders.float, proc(x: Seat): float = x.aliveTicks.float)
  r("Orders", "direct walks", "%", "Walk orders that skip the path planner.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.directOrders.float, proc(x: Seat): float = x.walkOrders.float)
  r("Orders", "grenade charging", "%", "Alive ticks holding a grenade charge.", 1):
    100.0 * s.ratio(proc(x: Seat): float = x.grenadeCharges.float, proc(x: Seat): float = x.aliveTicks.float)

type
  Line = object
    ## One rendered row: a replay stat or a diagnostic stage, one value per column.
    section, label, unit, definition: string
    digits: int
    values: seq[float]

proc cell(value: float, digits: int): string =
  ## Formats one value, a dash for no observation.
  if value.isNaN:
    "—"
  elif digits == 0:
    $int(round(value))
  else:
    formatFloat(value, ffDecimal, digits)

proc markdown(order: seq[string], lines: seq[Line], title, note: string): string =
  ## Renders the report as markdown.
  result.add &"# {title}\n\n{note}\n\n"
  result.add "| stat | unit | " & order.join(" | ") & " |\n"
  result.add "|---|---|" & order.mapIt("---:").join("|") & "|\n"
  var section = ""
  for line in lines:
    if line.section != section:
      section = line.section
      result.add &"| **{section}** | |" & order.mapIt(" ").join("|") & "|\n"
    result.add &"| {line.label} | {line.unit} | " &
      line.values.mapIt(cell(it, line.digits)).join(" | ") & " |\n"

proc category(line: Line): int =
  ## Sorts a row into a group: 1 controlled directly, 2 indirectly, 3 outcomes, 0 none.
  case line.section
  of "Shooting", "Movement", "Orders", "Footwork":
    1
  of "Items":
    2
  of "League", "Survival", "Combat", "Territory":
    if line.label in ["friendly damage", "enemy in view", "in a heart ring"]:
      1
    else:
      3
  else:
    0

proc compare(line: Line): tuple[mean, gap: float, flagged: bool] =
  ## Compares our value (the first column) with the rivals' mean: gap in percent of the mean,
  ## flagged when at least 25% (and, for % rows, at least 2 points).
  let
    ours = line.values[0]
    others = line.values[1 .. ^1].filterIt(not it.isNaN)
  result.mean =
    if others.len > 0:
      others.sum / others.len.float
    else:
      NaN
  result.gap = NaN
  if not ours.isNaN and not result.mean.isNaN and abs(result.mean) > 1e-9:
    result.gap = 100.0 * (ours - result.mean) / abs(result.mean)
    result.flagged = abs(result.gap) >= 25 and (line.unit != "%" or abs(ours - result.mean) >= 2)

const GroupTitles = [
  "1. Controlled directly: movement, footwork, aiming, shooting",
  "2. Controlled indirectly: items picked up and used",
  "3. Outcomes: winning, killing, dying, territory"
]

proc groupedHtml(order: seq[string], lines: seq[Line], title, note: string): string =
  ## Renders the three-group report as a standalone page; rows where we are out of line
  ## with the rivals are tinted red, and the largest gaps in what we control are listed first.
  result = """<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Paintbot stats</title><style>
:root{--bg:#fbfaf7;--fg:#1d1d1b;--muted:#6b6a64;--line:#e4e1d8;--head:#f1eee6;--ours:#f6f2e8;--flag:#fbe9e7;--flagText:#9b2c1f}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#171716;--fg:#ecebe6;--muted:#9c9a92;--line:#34332f;--head:#22211f;--ours:#201f1c;--flag:#3a201c;--flagText:#f0a597}}
:root[data-theme="dark"]{--bg:#171716;--fg:#ecebe6;--muted:#9c9a92;--line:#34332f;--head:#22211f;--ours:#201f1c;--flag:#3a201c;--flagText:#f0a597}
body{background:var(--bg);color:var(--fg);font:14px/1.45 system-ui,-apple-system,sans-serif;margin:0;padding:24px 16px}
h1{font-size:22px;margin:0 0 4px}h2{font-size:17px;margin:28px 0 8px}p{color:var(--muted);max-width:90ch}
.wrap{overflow-x:auto}table{border-collapse:collapse;min-width:100%}
th,td{border-bottom:1px solid var(--line);padding:5px 10px;text-align:right;white-space:nowrap;font-variant-numeric:tabular-nums}
th:first-child,td:first-child{text-align:left}
thead th{background:var(--head);position:sticky;top:0}
td.ours,th.ours{background:var(--ours);font-weight:600}
tr.flag td{background:var(--flag)}tr.flag td.gap{color:var(--flagText);font-weight:600}
td .u{color:var(--muted);font-size:12px}abbr{text-decoration:none;cursor:help}
</style></head><body>
"""
  result.add &"<h1>{title}</h1><p>{note}</p>"
  result.add &"<p>First column: ours ({order[0]}). Gap = (ours − rivals' mean) / rivals' mean. " &
    "Rows tinted red are out of line with the rivals: a gap of at least 25% (for % rows, also at least 2 points). " &
    "Hover a stat for its definition.</p>"
  proc header(extra: string): string =
    result = "<div class=\"wrap\"><table><thead><tr><th>stat</th>"
    for k, label in order:
      result.add (if k == 0: "<th class=\"ours\">" else: "<th>") & label & "</th>"
    result.add extra & "</tr></thead><tbody>\n"
  proc row(line: Line, mean, gap: float, flagged: bool): string =
    result = (if flagged: "<tr class=\"flag\">" else: "<tr>") &
      &"<td><abbr title=\"{line.definition}\">{line.label}</abbr> <span class=\"u\">{line.unit}</span></td>"
    for k, v in line.values:
      result.add (if k == 0: "<td class=\"ours\">" else: "<td>") & cell(v, line.digits) & "</td>"
    result.add &"<td>{cell(mean, line.digits)}</td><td class=\"gap\">" &
      (if gap.isNaN: "—" else: cell(gap, 0) & "%") & "</td></tr>\n"
  var flagged: seq[(float, Line)]
  for line in lines:
    let c = compare(line)
    if c.flagged and category(line) in [1, 2]:
      flagged.add (abs(c.gap), line)
  flagged.sort(proc(a, b: (float, Line)): int = cmp(b[0], a[0]))
  result.add "<h2>Largest gaps in what we control</h2>"
  result.add header("<th>rivals' mean</th><th>gap</th>")
  for (_, line) in flagged:
    let c = compare(line)
    result.add row(line, c.mean, c.gap, true)
  result.add "</tbody></table></div>\n"
  for g in 1 .. 3:
    result.add &"<h2>{GroupTitles[g - 1]}</h2>"
    result.add header("<th>rivals' mean</th><th>gap</th>")
    for line in lines:
      if category(line) == g:
        let c = compare(line)
        result.add row(line, c.mean, c.gap, c.flagged)
    result.add "</tbody></table></div>\n"
  result.add "</body></html>\n"

proc grouped(order: seq[string], lines: seq[Line], title, note: string): string =
  ## Renders the three-group report: our policy first, then the rivals, the rivals' mean,
  ## our gap to that mean in percent, and a flag where the gap is large.
  const Groups = [
    "1. Controlled directly: movement, footwork, aiming, shooting",
    "2. Controlled indirectly: items picked up and used",
    "3. Outcomes: winning, killing, dying, territory"
  ]
  result.add &"# {title}\n\n{note}\n\n"
  result.add &"The first column is ours ({order[0]}). Gap = (ours - rivals' mean) / rivals' mean. " &
    "A row is flagged when the gap is at least 25% (and, for % rows, at least 2 points).\n\n"
  var flagged: seq[(float, string)]
  for g in 1 .. 3:
    result.add &"## {Groups[g - 1]}\n\n"
    result.add "| stat | unit | " & order.join(" | ") & " | rivals' mean | gap | flag |\n"
    result.add "|---|---|" & order.mapIt("---:").join("|") & "|---:|---:|---|\n"
    for line in lines:
      if category(line) != g:
        continue
      let
        ours = line.values[0]
        others = line.values[1 .. ^1].filterIt(not it.isNaN)
        mean =
          if others.len > 0:
            others.sum / others.len.float
          else:
            NaN
      var
        gap = NaN
        flag = ""
      if not ours.isNaN and not mean.isNaN and abs(mean) > 1e-9:
        gap = 100.0 * (ours - mean) / abs(mean)
        if abs(gap) >= 25 and (line.unit != "%" or abs(ours - mean) >= 2):
          flag =
            if gap < 0:
              "we are lower"
            else:
              "we are higher"
          if g < 3:
            flagged.add (abs(gap), &"| {line.label} | {line.unit} | {cell(ours, line.digits)} | " &
              &"{cell(mean, line.digits)} | {cell(gap, 0)}% | " & others.mapIt(cell(it, line.digits)).join(" / ") & " |")
      result.add &"| {line.label} | {line.unit} | " & line.values.mapIt(cell(it, line.digits)).join(" | ") &
        &" | {cell(mean, line.digits)} | {cell(gap, 0)}{(if gap.isNaN: \"\" else: \"%\")} | {flag} |\n"
    result.add "\n"
  flagged.sort(proc(a, b: (float, string)): int = cmp(b[0], a[0]))
  result.add "## Largest gaps in what we control (groups 1 and 2)\n\n"
  result.add "| stat | unit | ours | rivals' mean | gap | " & order[1 .. ^1].join(" / ") & " |\n"
  result.add "|---|---|---:|---:|---:|---|\n"
  for (_, row) in flagged:
    result.add row & "\n"

proc html(order: seq[string], lines: seq[Line], title, note, notes: string): string =
  ## Renders the report as a standalone themed HTML page with bars.
  result = """<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Paintbot PW report</title><style>
:root{--bg:#fbfaf7;--fg:#1d1d1b;--muted:#6b6a64;--line:#e4e1d8;--bar:#d9c7a3;--head:#f1eee6;--diag:#9fc3a8}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#171716;--fg:#ecebe6;--muted:#9c9a92;--line:#34332f;--bar:#6b5a3b;--head:#22211f;--diag:#3f6b4a}}
:root[data-theme="dark"]{--bg:#171716;--fg:#ecebe6;--muted:#9c9a92;--line:#34332f;--bar:#6b5a3b;--head:#22211f;--diag:#3f6b4a}
body{background:var(--bg);color:var(--fg);font:14px/1.45 system-ui,-apple-system,sans-serif;margin:0;padding:24px 16px}
h1{font-size:22px;margin:0 0 4px}h2{font-size:17px;margin:24px 0 8px}p,li{color:var(--muted);max-width:80ch}
.wrap{overflow-x:auto}table{border-collapse:collapse;min-width:100%}
th,td{border-bottom:1px solid var(--line);padding:5px 10px;text-align:right;white-space:nowrap}
th:first-child,td:first-child{text-align:left;position:sticky;left:0;background:var(--bg)}
thead th{background:var(--head);position:sticky;top:0}
tr.sec td{background:var(--head);font-weight:600;text-align:left}
td.v{position:relative}td.v span.b{position:absolute;left:0;top:25%;height:50%;background:var(--bar);opacity:.55;z-index:0}
tr.d td.v span.b{background:var(--diag)}
td.v span.t{position:relative;z-index:1;font-variant-numeric:tabular-nums}td .u{color:var(--muted);font-size:12px}
abbr{text-decoration:none;cursor:help}
</style></head><body>
"""
  result.add &"<h1>{title}</h1><p>{note}</p>"
  if notes.len > 0:
    result.add "<h2>What the report says</h2><ul>"
    for line in notes.splitLines:
      if line.strip.len > 0:
        result.add "<li>" & line.strip.strip(chars = {'-', ' '}) & "</li>"
    result.add "</ul>"
  result.add "<div class=\"wrap\"><table><thead><tr><th>stat</th>"
  for label in order:
    result.add &"<th>{label}</th>"
  result.add "</tr></thead><tbody>\n"
  var section = ""
  for line in lines:
    if line.section != section:
      section = line.section
      result.add &"<tr class=\"sec\"><td colspan=\"{order.len + 1}\">{section}</td></tr>\n"
    var top = 0.0
    for v in line.values:
      if not v.isNaN:
        top = max(top, abs(v))
    let rowClass =
      if line.section.startsWith("Diagnostics"):
        " class=\"d\""
      else:
        ""
    result.add &"<tr{rowClass}><td><abbr title=\"{line.definition}\">{line.label}</abbr> <span class=\"u\">{line.unit}</span></td>"
    for v in line.values:
      let width =
        if v.isNaN or top == 0:
          0.0
        else:
          100.0 * abs(v) / top
      result.add &"<td class=\"v\"><span class=\"b\" style=\"width:{width:.0f}%\"></span><span class=\"t\">{cell(v, line.digits)}</span></td>"
    result.add "</tr>\n"
  result.add "</tbody></table></div><p>Hover a row name for its definition. Bars scale each row to its largest value; a longer bar is not always better. Diagnostic rows (green bars) are 0 to 100 scores from pw_diag scenarios in the real engine; a dash means no replays for that column, or no BASIC source to run.</p></body></html>\n"

proc fastRoster(path: string): seq[string] =
  ## Seats of a pw_fast replay: the tag's policy on our side, the rival on the other.
  let parts = path.split(DirSep)
  if parts.len < 5 or parts[^3] != "games":
    return
  let batch = parts[^4].split('_')
  if batch.len != 4:
    return
  let
    ours =
      if oursLabel.len > 0:
        oursLabel
      else:
        parts[^5]
    rival = batch[0] & ":" & batch[1]
    red = batch[2] == "red"
  names[ours] = ours
  names[rival] = rival
  for slot in 0 ..< 16:
    if (slot mod 2 == 0) == red:
      result.add ours
    else:
      result.add rival

proc main() =
  var
    inputs, diagPaths: seq[string]
    mdPath, htmlPath, notesPath: string
    title = "Paintbot PW report"
    columns: seq[string]
    groupedMode = false
    i = 1
  while i <= paramCount():
    let argument = paramStr(i)
    case argument
    of "--md":
      inc i
      mdPath = paramStr(i)
    of "--html":
      inc i
      htmlPath = paramStr(i)
    of "--title":
      inc i
      title = paramStr(i)
    of "--diag":
      inc i
      diagPaths.add paramStr(i)
    of "--notes":
      inc i
      notesPath = paramStr(i)
    of "--ours":
      inc i
      oursLabel = paramStr(i)
    of "--columns":
      inc i
      columns = paramStr(i).split(',')
    of "--grouped":
      groupedMode = true
    else:
      inputs.add argument
    inc i
  loadNames()
  let replays = findInputs(inputs)
  var
    stats = initTable[string, Stat]()
    used = 0
    skipped = 0
  for path in replays:
    let
      id = path.extractFilename.changeFileExt("")
      roster =
        if id in rosters:
          rosters[id]
        else:
          fastRoster(path)
    if roster.len == 0:
      inc skipped
      continue
    var seats: seq[Seat]
    try:
      seats = analyze(path)
    except CatchableError as e:
      stderr.writeLine &"{path}: {e.msg}"
      inc skipped
      continue
    inc used
    for slot, seat in seats:
      if slot >= roster.len:
        continue
      let name = label(roster[slot])
      if name notin stats:
        stats[name] = Stat()
      stats[name].seats.add seat
    for side in 0 .. 1:
      if side > roster.high:
        continue
      let name = label(roster[side])
      let seat = seats[side]
      inc stats[name].games
      if seat.won:
        inc stats[name].wins
        stats[name].gloryWins.add seat.glory
      elif seat.drew:
        inc stats[name].draws
  var order = toSeq(stats.keys)
  let gloryRow = rows()[3]
  order.sort(proc(a, b: string): int = cmp(gloryRow.value(stats[b]), gloryRow.value(stats[a])))
  if columns.len > 0:
    order = columns.filterIt(it in stats)
  elif oursLabel.len > 0 and oursLabel in stats:
    order = @[oursLabel] & order.filterIt(it != oursLabel)
  var diags: seq[JsonNode]
  for path in diagPaths:
    let d = parseJson(readFile(path))
    diags.add d
    for name, _ in d["policies"]:
      if name notin order:
        order.add name
  var lines: seq[Line]
  for row in rows():
    lines.add Line(section: row.section, label: row.label, unit: row.unit,
      definition: row.definition, digits: row.digits,
      values: order.mapIt(if it in stats: row.value(stats[it]) else: NaN))
  for d in diags:
    let section = &"Diagnostics (0-100, mean of {d[\"variants\"].getInt} variants)"
    var totals = newSeq[float](order.len)
    for j, name in order:
      totals[j] =
        if d["policies"].hasKey(name):
          let scores = d["policies"][name].getElems.mapIt(it.getFloat)
          scores.sum / max(scores.len, 1).float
        else:
          NaN
    lines.add Line(section: section, label: "total", unit: "",
      definition: "Mean of every diagnostic stage.", digits: 0, values: totals)
    for k, stage in d["stages"].getElems:
      lines.add Line(section: section, label: stage["name"].getStr, unit: "",
        definition: stage["definition"].getStr, digits: 0,
        values: order.mapIt(
          if d["policies"].hasKey(it): d["policies"][it][k].getFloat else: NaN))
  let
    note = &"{used} replays re-simulated with the hosted engine rules ({hashFailures} state-hash " &
      &"mismatches, {skipped} replays without a roster skipped). Columns are policy versions, " &
      "ordered by glory per game. Replay rows are means over the policy's seat-games unless noted."
    notes =
      if notesPath != "" and fileExists(notesPath):
        readFile(notesPath)
      else:
        ""
    text =
      if groupedMode:
        grouped(order, lines, title, note)
      else:
        markdown(order, lines, title, note)
  echo text
  if mdPath != "":
    writeFile(mdPath, text & (if notes.len > 0: "\n## What the report says\n\n" & notes else: ""))
  if htmlPath != "":
    writeFile(htmlPath,
      if groupedMode:
        groupedHtml(order, lines, title, note)
      else:
        html(order, lines, title, note, notes))

main()
