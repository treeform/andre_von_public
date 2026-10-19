## Paintbot PW fight extractor: why one policy wins the gunfights.
##
##   nim c -d:release -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw/examples/paintbot --path:$HOME/p/paintbot-pw/src \
##     -o:tools/pw_fights tools/pw_fights.nim
##   tools/pw_fights [--split] <dirs with replays and listing JSON>...
##
## pw_fast directories (eps/fast/<tag>) work too; --split names our side
## "<tag> win" or "<tag> loss" from eps/fast/<tag>.tsv.
##
## Re-simulates each replay and, per policy, reports gun accuracy by range,
## by whether the shooter and the target were moving when the ray left, and
## by height advantage; how often a cog fires while an enemy is in view; the
## local numbers (allies and enemies within 20 m) at every death and kill;
## and whether the victim of a kill had been hit by one or several enemies.

import
  std/[algorithm, json, math, os, sequtils, strformat, strutils, tables],
  game, sim, fastdirs

const
  Local = 2000
  RangeEdges = [1000, 2000, 3000, 4500, 100000]

type
  Fight = object
    shots, hits: array[5, int]
    movingShots, movingHits, stillShots, stillHits: int
    targetMovingShots, targetMovingHits, targetStillShots, targetStillHits: int
    upShots, upHits, levelShots, levelHits, downShots, downHits: int
    noTargetShots: int
    viewTicks, viewShots: int
    deaths, kills: int
    deathAllies, deathEnemies, killAllies, killEnemies: int
    outnumberedDeaths, outnumberingKills: int
    focusKills, soloKills: int
    firstBloodWins, firstBloodGames: int
    games: int
    missBlocked, missDodged, missAim, missTrench, missFriendly, missNothing: int
    sightings, reactions, reactionTicks, neverShot: int
    sightBusy, busyReactions, busyReactionTicks, readyReactions, readyReactionTicks: int
    wounded, woundedDied, woundedAway, woundedShots, woundedCover: int
    firstLives, firstLifeTicks, firstLifeAllies, laterLives, laterLifeTicks, laterLifeAllies: int
    disguisedKills, allKills, disguisedTicks: int
    ledShots, ledHits, unledShots, unledHits, overLead, underLead: int

var
  names = initTable[string, string]()
  rosters = initTable[string, seq[string]]()
  hitThisTick: array[MaxSeats, bool]
  hitters: array[MaxSeats, seq[int]]

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

proc observeDamage(w: World, victim, attacker: int, removed: int32, killed: bool) {.nimcall, gcsafe.} =
  ## Marks gun hits this tick and who has hit each victim this life.
  {.cast(gcsafe).}:
    if attacker < 0 or attacker == victim or team(attacker) == team(victim):
      return
    if damageWeapon == dwGun:
      hitThisTick[attacker] = true
    if attacker notin hitters[victim]:
      hitters[victim].add attacker

proc speed(a, b: Point): int =
  ## Returns the squared step length between two positions.
  int(distance2(a, b))

proc localCounts(w: World, slot: int, p: Point): (int, int) =
  ## Returns (living allies other than slot, living enemies) within Local of p.
  var allies, enemies = 0
  for j in 0 ..< Seats:
    if j == slot or w.cogs[j].hp <= 0:
      continue
    if distance2(w.cogs[j].pos, p) <= Local.int64 * Local:
      if team(j) == team(slot):
        inc allies
      else:
        inc enemies
  (allies, enemies)

proc classifyMiss(w: World, slot: int, aim: Point, ordered: seq[Point], f: var Fight) =
  ## Explains one miss: cover in the way, a teammate first, the nearest enemy in a
  ## trench, the target moving off the line during the windup, or plain bad aim.
  let
    origin = w.cogs[slot].pos
    length = sqrt(float(aim.x) ^ 2 + float(aim.z) ^ 2)
  if length < 1:
    inc f.missNothing
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
        inc f.missFriendly
        return
      continue
    if across < nearestAcross:
      nearest = j
      nearestAcross = across
      nearestAlong = along
  if nearest < 0 or nearestAcross > 600:
    inc f.missNothing
    return
  var step = 20.0
  while step < nearestAlong - Radius.float:
    let p = point(origin.x.int + int(ux * step), origin.z.int + int(uz * step))
    if w.blocked(p, 0):
      inc f.missBlocked
      return
    step += 20
  if nearestAcross <= Radius.float:
    inc f.missTrench
    return
  if slot < ordered.len and nearest < ordered.len and
      distance2(ordered[nearest], w.cogs[nearest].pos) > 900:
    inc f.missDodged
  else:
    inc f.missAim

proc analyze(path: string, roster: seq[string], fights: var Table[string, Fight]) =
  ## Re-simulates one replay and adds its fights to the per-policy table.
  let recording = loadRecording(path)
  var
    w = newWorld(recording.seed, recording.endTick)
    shotsThisTick: seq[int]
    telemetry: CombatTelemetry
    firstKillTeam = -1
    orderAim: array[MaxSeats, Point]
    orderPositions: array[MaxSeats, seq[Point]]
    seenSince: array[MaxSeats, array[MaxSeats, int]]
    unseenFor: array[MaxSeats, array[MaxSeats, int]]
    waiting: array[MaxSeats, int]
    waitStart: array[MaxSeats, int]
    waitBusy: array[MaxSeats, bool]
    woundTick: array[MaxSeats, int]
    woundGap: array[MaxSeats, float]
    lifeStart: array[MaxSeats, int]
    lifeIndex: array[MaxSeats, int]
    disguisedUntil: array[MaxSeats, int]
    tagged: seq[(int, int)]
  combatTelemetry = addr telemetry
  damageObserver = observeDamage
  observeShot = proc(tick: int32, slot: int) =
    shotsThisTick.add slot
  observeTag = proc(tick: int32, victim, attacker: int, pos: Point) =
    tagged.add((victim, attacker))
  defer:
    combatTelemetry = nil
    damageObserver = nil
    observeShot = nil
    observeTag = nil
  for i in 0 ..< Seats:
    hitters[i].setLen(0)
    for j in 0 ..< Seats:
      unseenFor[i][j] = 1000
  var previous = w.cogs
  for frame in recording.frames:
    let before = w.cogs
    shotsThisTick.setLen(0)
    for i in 0 ..< Seats:
      let c = frame.commands[i]
      if c.shoot and before[i].hp > 0 and before[i].cooldown == 0 and
          w.equipment[i].windup == 0 and not w.equipment[i].sprayCan:
        orderAim[i] = point(c.aim.x - before[i].pos.x, c.aim.z - before[i].pos.z)
        orderPositions[i] = before.mapIt(it.pos)
    for i in 0 ..< Seats:
      hitThisTick[i] = false
    w.step(frame.commands, replayRulesVersion)
    for slot in shotsThisTick:
      var f = addr fights.mgetOrPut(names.getOrDefault(roster[slot], roster[slot]), Fight())
      let shooter = before[slot].pos
      var
        target = -1
        best = int64.high
      for j in 0 ..< Seats:
        if team(j) != team(slot) and before[j].hp > 0 and w.visible(slot, j):
          let d = distance2(shooter, before[j].pos)
          if d < best:
            best = d
            target = j
      let hit = hitThisTick[slot]
      if slot < orderPositions.len and orderPositions[slot].len > 0:
        let
          at = orderAim[slot]
          shooterAt = orderPositions[slot][slot]
        var
          nearestEnemy = -1
          nearestD = int64.high
        for j in countup(1 - team(slot), Seats - 1, 2):
          let d = distance2(orderPositions[slot][j], point(shooterAt.x.int + at.x.int, shooterAt.z.int + at.z.int))
          if d < nearestD:
            nearestD = d
            nearestEnemy = j
        if nearestEnemy >= 0:
          let aimPoint = point(shooterAt.x.int + at.x.int, shooterAt.z.int + at.z.int)
          let offset = sqrt(float(distance2(aimPoint, orderPositions[slot][nearestEnemy])))
          if offset > 100:
            inc f.ledShots
            if hit: inc f.ledHits
            let moved = sqrt(float(distance2(orderPositions[slot][nearestEnemy], w.cogs[nearestEnemy].pos)))
            if moved < offset * 0.5:
              inc f.overLead
            elif moved > offset * 1.5:
              inc f.underLead
          else:
            inc f.unledShots
            if hit: inc f.unledHits
      if not hit:
        classifyMiss(w, slot, orderAim[slot], orderPositions[slot], f[])
      if target < 0:
        inc f.noTargetShots
        continue
      let
        range = sqrt(best.float).int
        bucket = block:
          var k = 0
          while range > RangeEdges[k]:
            inc k
          k
      inc f.shots[bucket]
      if hit:
        inc f.hits[bucket]
      if speed(previous[slot].pos, shooter) > 16:
        inc f.movingShots
        if hit: inc f.movingHits
      else:
        inc f.stillShots
        if hit: inc f.stillHits
      if speed(previous[target].pos, before[target].pos) > 16:
        inc f.targetMovingShots
        if hit: inc f.targetMovingHits
      else:
        inc f.targetStillShots
        if hit: inc f.targetStillHits
      let rise = terrainHeight(shooter.x.int, shooter.z.int) -
        terrainHeight(before[target].pos.x.int, before[target].pos.z.int)
      if rise > 50:
        inc f.upShots
        if hit: inc f.upHits
      elif rise < -50:
        inc f.downShots
        if hit: inc f.downHits
      else:
        inc f.levelShots
        if hit: inc f.levelHits
    for i in 0 ..< Seats:
      if before[i].hp <= 0:
        continue
      var seen = false
      for j in 0 ..< Seats:
        if team(j) != team(i) and before[j].hp > 0 and w.visible(i, j):
          seen = true
          break
      if seen:
        var f = addr fights.mgetOrPut(names.getOrDefault(roster[i], roster[i]), Fight())
        inc f.viewTicks
        if i in shotsThisTick:
          inc f.viewShots
    for victim in 0 ..< Seats:
      if before[victim].hp > 0 and w.cogs[victim].hp <= 0:
        let
          name = names.getOrDefault(roster[victim], roster[victim])
          (allies, enemies) = localCounts(w, victim, before[victim].pos)
        var f = addr fights.mgetOrPut(name, Fight())
        inc f.deaths
        f.deathAllies += allies
        let lived = w.tick.int - lifeStart[victim]
        if lifeIndex[victim] == 0:
          inc f.firstLives
          f.firstLifeTicks += lived
          f.firstLifeAllies += allies
        else:
          inc f.laterLives
          f.laterLifeTicks += lived
          f.laterLifeAllies += allies
        inc lifeIndex[victim]
        f.deathEnemies += enemies
        if enemies > allies + 1:
          inc f.outnumberedDeaths
        let killerTeam = 1 - team(victim)
        if firstKillTeam < 0:
          firstKillTeam = killerTeam
        var killerSlot = -1
        for s in 0 ..< Seats:
          if team(s) == killerTeam:
            killerSlot = s
            break
        let killerName = names.getOrDefault(roster[killerSlot], roster[killerSlot])
        var k = addr fights.mgetOrPut(killerName, Fight())
        inc k.kills
        k.killAllies += enemies
        k.killEnemies += allies + 1
        if enemies > allies + 1:
          inc k.outnumberingKills
        if hitters[victim].len >= 2:
          inc k.focusKills
        else:
          inc k.soloKills
        hitters[victim].setLen(0)
    for i in 0 ..< Seats:
      let name = names.getOrDefault(roster[i], roster[i])
      if w.cogs[i].hp <= 0:
        waiting[i] = 0
        continue
      if waiting[i] > 0 and frame.commands[i].shoot:
        var f = addr fights.mgetOrPut(name, Fight())
        inc f.reactions
        f.reactionTicks += w.tick.int - waitStart[i]
        if waitBusy[i]:
          inc f.busyReactions
          f.busyReactionTicks += w.tick.int - waitStart[i]
        else:
          inc f.readyReactions
          f.readyReactionTicks += w.tick.int - waitStart[i]
        waiting[i] = 0
      elif waiting[i] > 0 and w.tick.int - waitStart[i] > 72:
        var f = addr fights.mgetOrPut(name, Fight())
        inc f.neverShot
        waiting[i] = 0
      for j in 0 ..< Seats:
        if team(j) == team(i):
          continue
        if w.visible(i, j):
          if unseenFor[i][j] >= 48 and waiting[i] == 0:
            var f = addr fights.mgetOrPut(name, Fight())
            inc f.sightings
            waiting[i] = 1
            waitStart[i] = w.tick.int
            waitBusy[i] = w.cogs[i].cooldown > 0 or w.equipment[i].windup > 0
            if waitBusy[i]:
              inc f.sightBusy
          unseenFor[i][j] = 0
        else:
          inc unseenFor[i][j]
    for i in 0 ..< Seats:
      let name = names.getOrDefault(roster[i], roster[i])
      if before[i].hp > 1 and w.cogs[i].hp == 1:
        woundTick[i] = w.tick.int
        var gap = 1e9
        for j in countup(1 - team(i), Seats - 1, 2):
          if w.cogs[j].hp > 0:
            gap = min(gap, sqrt(float(distance2(w.cogs[i].pos, w.cogs[j].pos))))
        woundGap[i] = gap
        var f = addr fights.mgetOrPut(name, Fight())
        inc f.wounded
      if woundTick[i] > 0:
        var f = addr fights.mgetOrPut(name, Fight())
        if w.cogs[i].hp <= 0:
          inc f.woundedDied
          woundTick[i] = 0
        elif i in shotsThisTick:
          inc f.woundedShots
        if woundTick[i] > 0 and w.tick.int - woundTick[i] == 48:
          var gap = 1e9
          var covered = true
          for j in countup(1 - team(i), Seats - 1, 2):
            if w.cogs[j].hp > 0:
              gap = min(gap, sqrt(float(distance2(w.cogs[i].pos, w.cogs[j].pos))))
              if w.visible(j, i):
                covered = false
          if gap > woundGap[i] + 200:
            inc f.woundedAway
          if covered:
            inc f.woundedCover
        if woundTick[i] > 0 and w.tick.int - woundTick[i] >= 120:
          woundTick[i] = 0
    for i in 0 ..< Seats:
      if before[i].hp <= 0 and w.cogs[i].hp > 0:
        lifeStart[i] = w.tick.int
    for i in 0 ..< Seats:
      if w.uniforms[i]:
        disguisedUntil[i] = w.tick.int + 72
        var f = addr fights.mgetOrPut(names.getOrDefault(roster[i], roster[i]), Fight())
        inc f.disguisedTicks
    for (victim, attacker) in tagged:
      var f = addr fights.mgetOrPut(names.getOrDefault(roster[attacker], roster[attacker]), Fight())
      inc f.allKills
      if disguisedUntil[attacker] >= w.tick.int:
        inc f.disguisedKills
    previous = before
  let scores = w.scores()
  for side in 0 .. 1:
    let name = names.getOrDefault(roster[side], roster[side])
    var f = addr fights.mgetOrPut(name, Fight())
    inc f.games
    if firstKillTeam == side:
      inc f.firstBloodGames
      if scores[side] > 0:
        inc f.firstBloodWins

proc pct(a, b: int): string =
  ## Formats a percentage, a dash for no observations.
  if b == 0:
    "—"
  else:
    &"{100.0 * a.float / b.float:.1f}"

proc main() =
  var replays: seq[string]
  if fileExists("eps/names.txt"):
    for line in lines("eps/names.txt"):
      let parts = line.splitWhitespace
      if parts.len == 2:
        names[parts[0]] = parts[1]
  var split = false
  for input in commandLineParams():
    if input == "--split":
      split = true
      continue
    for path in walkDirRec(input):
      if path.endsWith(".json"):
        try:
          addListing(parseJson(readFile(path)))
        except CatchableError:
          discard
      elif path.endsWith(".replay"):
        replays.add path
  var fights = initTable[string, Fight]()
  for path in replays:
    let id = path.extractFilename.changeFileExt("")
    if id in rosters:
      analyze(path, rosters[id], fights)
    else:
      let roster = fastRoster(path, split)
      if roster.len == 16:
        analyze(path, roster, fights)
  var order = toSeq(fights.keys)
  order.sort()
  echo "| stat | " & order.join(" | ") & " |"
  echo "|---|" & order.mapIt("---:").join("|") & "|"
  template row(label: string, body: untyped) =
    var cells: seq[string]
    for name in order:
      let f {.inject.} = fights[name]
      cells.add body
    echo "| " & label & " | " & cells.join(" | ") & " |"
  row("games"): $f.games
  for k in 0 ..< 5:
    let lo =
      if k == 0:
        0
      else:
        RangeEdges[k - 1] div 100
    let label =
      if k == 4:
        &"accuracy {lo}+ m"
      else:
        &"accuracy {lo}-{RangeEdges[k] div 100} m"
    row(label): pct(f.hits[k], f.shots[k]) & &" ({f.shots[k]})"
  row("shot range share <20 m"): pct(f.shots[0] + f.shots[1], f.shots.sum)
  row("accuracy shooter still"): pct(f.stillHits, f.stillShots) & &" ({f.stillShots})"
  row("accuracy shooter moving"): pct(f.movingHits, f.movingShots) & &" ({f.movingShots})"
  row("accuracy target still"): pct(f.targetStillHits, f.targetStillShots)
  row("accuracy target moving"): pct(f.targetMovingHits, f.targetMovingShots)
  row("accuracy from above"): pct(f.upHits, f.upShots) & &" ({f.upShots})"
  row("accuracy level"): pct(f.levelHits, f.levelShots) & &" ({f.levelShots})"
  row("accuracy from below"): pct(f.downHits, f.downShots) & &" ({f.downShots})"
  row("shots with no enemy in view"): pct(f.noTargetShots, f.noTargetShots + f.shots.sum)
  row("shots per second in view"): (if f.viewTicks == 0: "—" else: &"{24.0 * f.viewShots.float / f.viewTicks.float:.2f}")
  row("allies near at own death"): (if f.deaths == 0: "—" else: &"{f.deathAllies / f.deaths:.2f}")
  row("enemies near at own death"): (if f.deaths == 0: "—" else: &"{f.deathEnemies / f.deaths:.2f}")
  row("deaths while outnumbered"): pct(f.outnumberedDeaths, f.deaths)
  row("allies near at kill"): (if f.kills == 0: "—" else: &"{f.killAllies / f.kills:.2f}")
  row("enemies near at kill"): (if f.kills == 0: "—" else: &"{f.killEnemies / f.kills:.2f}")
  row("kills while outnumbering"): pct(f.outnumberingKills, f.kills)
  row("kills with 2+ hitters"): pct(f.focusKills, f.focusKills + f.soloKills)
  row("misses: cover in the way"): pct(f.missBlocked, f.shots.sum)
  row("misses: target moved off the line"): pct(f.missDodged, f.shots.sum)
  row("misses: aim off a still target"): pct(f.missAim, f.shots.sum)
  row("misses: trench or other in-radius"): pct(f.missTrench, f.shots.sum)
  row("misses: teammate in the way"): pct(f.missFriendly, f.shots.sum)
  row("misses: nobody near the line"): pct(f.missNothing, f.shots.sum)
  row("reaction to a new enemy, ticks"): (if f.reactions == 0: "—" else: &"{f.reactionTicks / f.reactions:.1f}")
  row("gun busy at a new sighting"): pct(f.sightBusy, f.sightings)
  row("reaction when the gun was ready, ticks"): (if f.readyReactions == 0: "—" else: &"{f.readyReactionTicks / f.readyReactions:.1f}")
  row("reaction when the gun was busy, ticks"): (if f.busyReactions == 0: "—" else: &"{f.busyReactionTicks / f.busyReactions:.1f}")
  row("new enemies never shot within 3 s"): pct(f.neverShot, f.sightings)
  row("kills within 3 s of wearing a uniform"): pct(f.disguisedKills, f.allKills)
  row("disguised seconds per game"): (if f.games == 0: "—" else: &"{f.disguisedTicks.float / 24.0 / f.games.float:.1f}")
  row("first life: seconds to death"): (if f.firstLives == 0: "—" else: &"{f.firstLifeTicks / f.firstLives / 24:.1f}")
  row("first life: allies near at death"): (if f.firstLives == 0: "—" else: &"{f.firstLifeAllies / f.firstLives:.2f}")
  row("respawned lives: seconds to death"): (if f.laterLives == 0: "—" else: &"{f.laterLifeTicks / f.laterLives / 24:.1f}")
  row("respawned lives: allies near at death"): (if f.laterLives == 0: "—" else: &"{f.laterLifeAllies / f.laterLives:.2f}")
  row("wounded to 1 HP"): $f.wounded
  row("wounded: died within 5 s"): pct(f.woundedDied, f.wounded)
  row("wounded: 2 m further from enemies at 2 s"): pct(f.woundedAway, f.wounded)
  row("wounded: out of every enemy sight at 2 s"): pct(f.woundedCover, f.wounded)
  row("wounded: shots in the next 5 s"): (if f.wounded == 0: "—" else: &"{f.woundedShots / f.wounded:.2f}")
  row("led shots (aim 1 m+ off the target)"): pct(f.ledShots, f.ledShots + f.unledShots)
  row("accuracy led"): pct(f.ledHits, f.ledShots)
  row("accuracy unled"): pct(f.unledHits, f.unledShots)
  row("led: target moved under half the lead"): pct(f.overLead, f.ledShots)
  row("led: target moved over 1.5x the lead"): pct(f.underLead, f.ledShots)
  row("first blood rate"): pct(f.firstBloodGames, f.games)
  row("wins after first blood"): pct(f.firstBloodWins, f.firstBloodGames)

main()
