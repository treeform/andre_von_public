## Paintbot PW diagnostics: isolated skill stages for BASIC policies.
##
##   nim c -d:release -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw/examples/paintbot --path:$HOME/p/paintbot-pw/src \
##     -o:tools/pw_diag tools/pw_diag.nim
##   tools/pw_diag [--stages a,b] [--variants N] [--md PATH] [--html PATH]
##     [--base PATH] name=policy.bas ...
##
## Every stage builds a hand-made situation inside the real simulation on
## Heartwick: the policy's cogs (Red, even seats) take their first decision
## at the real spawn, then the stage benches every cog it does not use
## (dead, with a respawn far in the future, so no team is eliminated),
## teleports the rest into place and runs a few seconds. Opponents are the
## live baseline (base.bas), tiny scripted cogs, or idle cogs. Each variant
## scores 0 to 100; a cell is the mean over variants (different spots on
## the map and different headings). Deterministic: the same inputs give the
## same table.

import
  std/[json, math, os, sequtils, strformat, strutils],
  polyworld/cli,
  game, sim, bots

const
  OurSlot = 0
  EnemySlot = 1
  Metre = 100
  BenchTicks = 1_000_000'i32
  LeagueGlory = GloryConfig(
    quietSupplies: GloryQuietSupplies,
    quietSupplySeconds: GloryQuietSupplyTicks div TickRate,
    behindLives: 5,
    behindLivesSeconds: GloryBehindLivesTicks div TickRate,
    heart: GloryHeartAward,
    behindCogs: 10,
    behindCogsSeconds: GloryBehindCogsTicks div TickRate
  )

type
  Stage = enum
    IdleAim, StrafeAim, LongShot, Duel, Ambush, Outnumbered, Advantage,
    TeamFight, Grenade, Medkit, Armor, Capture, Defend, GloryHeartStage,
    FriendlyFire, FullMatch

  Policy = object
    name, source, path: string

  Scenario = object
    w: World
    bots: seq[Bot]
    enemyDamage: array[MaxSeats, int]
    friendlyDamage: array[MaxSeats, int]
    grenadeDamage: array[MaxSeats, int]
    sprayKills: array[MaxSeats, int]
    sprayFriendly: array[MaxSeats, int]
    deaths: array[MaxSeats, int]
    wading: array[MaxSeats, int]
    alive: array[MaxSeats, int]

var
  baseSource = ""
  current: ptr Scenario
  traceShots = false
  traceSapper = false
  sapperSlot = 0

proc stageName(stage: Stage): string =
  ## Returns the table label of one stage.
  case stage
  of IdleAim: "kill an idle cog at 25 m"
  of StrafeAim: "hit a strafing cog at 25 m"
  of LongShot: "kill an idle cog at 45 m"
  of Duel: "1v1 duel vs base.bas, face to face"
  of Ambush: "1v1 vs base.bas shooting from behind"
  of Outnumbered: "survive 1v2 vs base.bas"
  of Advantage: "win 2v1 vs base.bas without a loss"
  of TeamFight: "4v4 team fight vs base.bas"
  of Grenade: "grenade a cluster of three"
  of Medkit: "heal at a medkit when hurt"
  of Armor: "pick up nearby armor"
  of Capture: "capture a neutral heart alone"
  of Defend: "stop a capture of our heart"
  of GloryHeartStage: "collect a glory heart"
  of FriendlyFire: "hold fire through a teammate"
  of FullMatch: "8v8 match vs base.bas"

proc stageDefinition(stage: Stage): string =
  ## Returns how one stage is built and scored.
  case stage
  of IdleAim: "An idle enemy 25 m away in the open, facing away. Score: share of its 3 HP removed in 6 s."
  of StrafeAim: "An enemy 25 m away walking side to side (2 s legs), never shooting. Score: share of its 3 HP removed in 8 s."
  of LongShot: "An idle enemy 45 m away in view. Score: share of its 3 HP removed in 8 s."
  of Duel: "One base.bas cog 25 m away, both facing each other, full HP. Score: 100 kill without dying, 50 a trade, 0 death; a timeout scores 50 plus the HP difference."
  of Ambush: "As the duel, but we face away and the base.bas cog starts behind us. Same score."
  of Outnumbered: "Two base.bas cogs 25 m away facing us. Score: 100 alive after 10 s, 0 dead; +25 per kill, capped at 100."
  of Advantage: "Two of our cogs 4 m apart vs one base.bas cog 25 m away. Score: 100 enemy dead and no loss, 50 enemy dead with a loss, 0 otherwise."
  of TeamFight: "Four of ours vs four base.bas 30 m apart, 20 s, no respawns counted. Score: 50 + 12.5 per enemy death - 12.5 per own death."
  of Grenade: "We hold a grenade; three idle enemies stand together 14 m away in view. Score: grenade damage dealt over the 9 HP in reach, in 6 s."
  of Medkit: "At 1 HP, a ready medkit 10 m away, no enemies. Score: 100 healed within 10 s."
  of Armor: "Full HP, ready armor 8 m away, no enemies. Score: 100 armored within 10 s."
  of Capture: "15 m from a neutral heart, no enemies. Score: 100 captured within 15 s."
  of Defend: "An idle enemy starts capturing our heart; we stand 20 m away. Score: 100 capture stopped for 6 s."
  of GloryHeartStage: "A glory heart 10 m away, no enemies. Score: 100 picked up within 10 s."
  of FriendlyFire: "An idle enemy 30 m away with an idle teammate halfway on the line. Score: 50 for no friendly damage, 50 more for any enemy damage, in 8 s."
  of FullMatch: "Full 8v8 on Heartwick vs base.bas, 3 minute cap, sides alternate. Score: 100 win, 50 draw or unfinished, 0 loss."

proc observeDamage(w: World, victim, attacker: int, removed: int32, killed: bool) {.nimcall, gcsafe.} =
  ## Records damage by attacker for the running scenario.
  {.cast(gcsafe).}:
    if current == nil or attacker < 0 or attacker == victim:
      return
    if team(attacker) == team(victim):
      current[].friendlyDamage[attacker] += removed
      if damageWeapon == dwSpray:
        current[].sprayFriendly[attacker] += removed
    else:
      current[].enemyDamage[attacker] += removed
      if damageWeapon == dwGrenade:
        current[].grenadeDamage[attacker] += removed
      if damageWeapon == dwSpray and killed:
        inc current[].sprayKills[attacker]

proc inWater(p: Point): bool =
  ## Returns true when a point is in wading water.
  riverBlend(p.x.int, p.z.int) > 0 and
    terrainHeight(p.x.int, p.z.int) < RiverWaterHeight

proc open(w: World, p: Point): bool =
  ## Returns true for a dry, unblocked standing point inside the map.
  p.x > minX() + 200 and p.z > minZ() + 200 and p.x < maxX() - 200 and
    p.z < maxZ() - 200 and not w.blocked(p) and not inWater(p)

proc offset(p: Point, angle: float, distance: int): Point =
  ## Moves a point by a distance along a heading in radians.
  point(
    p.x.int + int(round(cos(angle) * distance.float)),
    p.z.int + int(round(sin(angle) * distance.float))
  )

proc arena(w: World, variant: int, distance: int): (Point, float) =
  ## Picks an anchor and heading with open ground and a clear line of the
  ## given length, rotating through dry control hearts by variant.
  var anchors: seq[Point]
  for h in w.controlHearts:
    if not inWater(h.pos):
      anchors.add h.pos
  for attempt in 0 ..< 400:
    let
      k = variant * 7 + attempt
      anchor = anchors[k mod anchors.len]
      start = anchor.offset(float(k * 37 mod 360) * PI / 180, 250 + (k mod 5) * 150)
      angle = float((variant * 83 + attempt * 29) mod 360) * PI / 180
      finish = start.offset(angle, distance)
    if w.open(start) and w.open(finish) and w.lineClear(start, finish) and
        w.walkClear(start, finish):
      return (start, angle)
  quit("pw_diag: no open arena found")

proc bench(s: var Scenario, slot: int) =
  ## Keeps one cog dead for the stage without eliminating its team.
  s.w.cogs[slot].hp = 0
  s.w.cogs[slot].respawn = BenchTicks
  s.w.equipment[slot] = Equipment(lives: 1)

proc place(s: var Scenario, slot: int, p, facing: Point, hp = 3) =
  ## Teleports one living cog, fresh, looking at a point.
  s.w.cogs[slot].pos = p
  s.w.cogs[slot].goal = p
  s.w.cogs[slot].aim = facing
  s.w.cogs[slot].hp = hp.int32
  s.w.cogs[slot].shield = 0
  s.w.cogs[slot].cooldown = 0
  s.w.cogs[slot].respawn = 0
  s.w.cogs[slot].carrying = false
  s.w.equipment[slot] = Equipment(lives: 3)
  s.w.uniforms[slot] = false

proc policyBot(policy: Policy, slot: int): Bot =
  ## Loads one seat of a policy file the way a hosted match does: plain
  ## BASIC, or BASIC with a neural model beside it (<path>.model.bin).
  let all = loadBots(@[BotGroup(path: policy.path, count: Seats)])
  all[slot]

proc newScenario(policy: Policy, seed: int, ourSlots: seq[int]): Scenario =
  ## Builds a live-rules world where our policy takes its first decision at spawn.
  configureRules(LiveRules)
  configureMap("")
  configureVision("")
  configureGlory(LeagueGlory)
  result.w = newLiveWorld(int32(seed), HeartMeterMatchTicks.int32)
  result.bots = newSeq[Bot](Seats)
  for slot in ourSlots:
    result.bots[slot] = policyBot(policy, slot)
  let commands = decide(result.bots, result.w)
  result.w.step(commands, LiveRules)
  deliverSpeech(result.w)
  for slot in 0 ..< Seats:
    result.bench(slot)
  result.w.nextGloryHeart = BenchTicks
  result.w.gloryHearts.setLen(0)

proc script(s: var Scenario, slot: int, source: string) =
  ## Gives one seat a BASIC program.
  s.bots[slot] = loadScriptBot(source, slot)

proc run(s: var Scenario, ticks: int, stop: proc(s: Scenario): bool = nil) =
  ## Advances the scenario, tracking deaths, alive time and wading.
  current = addr s
  damageObserver = observeDamage
  defer:
    damageObserver = nil
    current = nil
  var
    orderTick = -1
    orderAim, orderTarget: Point
  for t in 0 ..< ticks:
    let before = s.w.cogs
    let commands = decide(s.bots, s.w)
    if traceShots and commands[OurSlot].shoot and before[OurSlot].hp > 0 and
        before[OurSlot].cooldown == 0 and s.w.equipment[OurSlot].windup == 0:
      orderTick = s.w.tick
      orderAim = point(commands[OurSlot].aim.x - before[OurSlot].pos.x,
        commands[OurSlot].aim.z - before[OurSlot].pos.z)
      orderTarget = before[EnemySlot].pos
    let sapperBefore = (s.w.equipment[sapperSlot].sprayCan, s.w.uniforms[sapperSlot], s.w.cogs[sapperSlot].hp)
    let windup = s.w.equipment[OurSlot].windup
    s.w.step(commands, LiveRules)
    if traceShots and windup == 1 and orderTick >= 0:
      let
        origin = s.w.cogs[OurSlot].pos
        target = s.w.cogs[EnemySlot].pos
        length = sqrt(float(orderAim.x) ^ 2 + float(orderAim.z) ^ 2)
        dx = float(target.x - origin.x)
        dz = float(target.z - origin.z)
        miss = abs(dx * float(orderAim.z) - dz * float(orderAim.x)) / max(length, 1.0)
      stderr.writeLine &"shot tick {orderTick}: range {sqrt(dx * dx + dz * dz) / 100:.1f} m, target moved {sqrt(float(distance2(orderTarget, target))) / 100:.2f} m, shooter moved {sqrt(float(distance2(before[OurSlot].pos, origin))) / 100:.2f} m, miss {miss:.0f} (radius 55)"
      orderTick = -1
    if traceSapper:
      let now = (s.w.equipment[sapperSlot].sprayCan, s.w.uniforms[sapperSlot], s.w.cogs[sapperSlot].hp)
      if now != sapperBefore or s.w.equipment[sapperSlot].burst == SprayTicks:
        let p = s.w.cogs[sapperSlot].pos
        stderr.writeLine &"  tick {s.w.tick}: sapper can {now[0]} uniform {now[1]} hp {now[2]} at ({p.x}, {p.z}) burst {s.w.equipment[sapperSlot].burst}"
    deliverSpeech(s.w)
    for i in 0 ..< Seats:
      if before[i].hp > 0 and s.w.cogs[i].hp <= 0:
        inc s.deaths[i]
      if s.w.cogs[i].hp > 0:
        inc s.alive[i]
        if inWater(s.w.cogs[i].pos):
          inc s.wading[i]
    if s.w.winner != -1:
      break
    if stop != nil and stop(s):
      break

proc duelScore(s: Scenario, ours, theirs: int): float =
  ## 100 a clean kill, 50 a trade, 0 a death, HP difference on a timeout.
  let
    weDied = s.deaths[ours] > 0
    theyDied = s.deaths[theirs] > 0
  if theyDied and not weDied:
    100.0
  elif theyDied and weDied:
    50.0
  elif weDied:
    0.0
  else:
    clamp(50.0 + 50.0 * float(s.w.cogs[ours].hp - s.w.cogs[theirs].hp) / 3.0, 0.0, 100.0)

proc strafeScript(dx, dz: int): string =
  ## A cog that walks side to side along one axis in two second legs.
  &"""if worldTick mod 96 < 48 then
  walkTo(selfX + {dx}, selfY + {dz})
else
  walkTo(selfX - {dx}, selfY - {dz})
end if
"""

proc runStage(stage: Stage, policy: Policy, variant: int): float =
  ## Builds and scores one variant of one stage.
  let seed = 2026 + variant
  case stage
  of IdleAim, LongShot:
    let range =
      if stage == IdleAim:
        25 * Metre
      else:
        45 * Metre
    var s = newScenario(policy, seed, @[OurSlot])
    let (start, angle) = s.w.arena(variant, range)
    let target = start.offset(angle, range)
    s.place(OurSlot, start, target)
    s.place(EnemySlot, target, target.offset(angle, 500))
    s.run(if stage == IdleAim: 144 else: 192,
      proc(s: Scenario): bool = s.deaths[EnemySlot] > 0)
    100.0 * min(s.enemyDamage[OurSlot], 3).float / 3.0
  of StrafeAim:
    var s = newScenario(policy, seed, @[OurSlot])
    let (start, angle) = s.w.arena(variant, 25 * Metre)
    let target = start.offset(angle, 25 * Metre)
    s.place(OurSlot, start, target)
    s.place(EnemySlot, target, start)
    let side = point(0, 0).offset(angle + PI / 2, 600)
    s.script(EnemySlot, strafeScript(side.x.int, side.z.int))
    s.run(192, proc(s: Scenario): bool = s.deaths[EnemySlot] > 0)
    100.0 * min(s.enemyDamage[OurSlot], 3).float / 3.0
  of Duel, Ambush:
    var s = newScenario(policy, seed, @[OurSlot])
    let (start, angle) = s.w.arena(variant, 25 * Metre)
    let enemy = start.offset(angle, 25 * Metre)
    let facing =
      if stage == Duel:
        enemy
      else:
        start.offset(angle + PI, 500)
    s.place(OurSlot, start, facing)
    s.place(EnemySlot, enemy, start)
    s.script(EnemySlot, baseSource)
    s.run(240, proc(s: Scenario): bool = s.deaths[OurSlot] > 0 or s.deaths[EnemySlot] > 0)
    s.duelScore(OurSlot, EnemySlot)
  of Outnumbered:
    var s = newScenario(policy, seed, @[OurSlot])
    let (start, angle) = s.w.arena(variant, 25 * Metre)
    let enemy = start.offset(angle, 25 * Metre)
    s.place(OurSlot, start, enemy)
    s.place(1, enemy, start)
    s.place(3, enemy.offset(angle + PI / 2, 300), start)
    s.script(1, baseSource)
    s.script(3, baseSource)
    s.run(240, proc(s: Scenario): bool = s.deaths[OurSlot] > 0)
    if s.deaths[OurSlot] > 0:
      0.0
    else:
      min(100.0, 75.0 + 25.0 * float(s.deaths[1] + s.deaths[3]))
  of Advantage:
    var s = newScenario(policy, seed, @[0, 2])
    let (start, angle) = s.w.arena(variant, 25 * Metre)
    let enemy = start.offset(angle, 25 * Metre)
    s.place(0, start, enemy)
    s.place(2, start.offset(angle + PI / 2, 400), enemy)
    s.place(EnemySlot, enemy, start)
    s.script(EnemySlot, baseSource)
    s.run(240, proc(s: Scenario): bool = s.deaths[EnemySlot] > 0)
    if traceShots:
      stderr.writeLine &"2v1 variant {variant}: enemy dead {s.deaths[EnemySlot]}, our deaths {s.deaths[0] + s.deaths[2]}, damage dealt {s.enemyDamage[0] + s.enemyDamage[2]}"
    if s.deaths[EnemySlot] == 0:
      0.0
    elif s.deaths[0] + s.deaths[2] == 0:
      100.0
    else:
      50.0
  of TeamFight:
    let ours = @[0, 2, 4, 6]
    var s = newScenario(policy, seed, ours)
    let (start, angle) = s.w.arena(variant, 30 * Metre)
    let enemy = start.offset(angle, 30 * Metre)
    for k in 0 ..< 4:
      let lateral = (k - 1) * 350 - 175
      s.place(ours[k], start.offset(angle + PI / 2, lateral), enemy)
      s.place(ours[k] + 1, enemy.offset(angle + PI / 2, lateral), start)
      s.script(ours[k] + 1, baseSource)
    s.run(480)
    var ourDeaths, theirDeaths = 0
    for k in 0 ..< 4:
      ourDeaths += s.deaths[ours[k]]
      theirDeaths += s.deaths[ours[k] + 1]
    clamp(50.0 + 12.5 * float(theirDeaths - ourDeaths), 0.0, 100.0)
  of Grenade:
    var s = newScenario(policy, seed, @[OurSlot])
    let (start, angle) = s.w.arena(variant, 14 * Metre)
    let center = start.offset(angle, 14 * Metre)
    s.place(OurSlot, start, center)
    s.w.equipment[OurSlot].grenade = true
    s.place(1, center, center.offset(angle, 500))
    s.place(3, center.offset(angle + PI / 2, 130), center.offset(angle, 500))
    s.place(5, center.offset(angle - PI / 2, 130), center.offset(angle, 500))
    s.run(144)
    100.0 * min(s.grenadeDamage[OurSlot], 9).float / 9.0
  of Medkit, Armor:
    var s = newScenario(policy, seed, @[OurSlot])
    let range =
      if stage == Medkit:
        10 * Metre
      else:
        8 * Metre
    let (start, angle) = s.w.arena(variant, range)
    let spot = start.offset(angle, range)
    let kind =
      if stage == Medkit:
        medkitPickup
      else:
        armorPickup
    s.place(OurSlot, start, spot, hp = (if stage == Medkit: 1 else: 3))
    for p in s.w.pickups.mitems:
      if p.kind == kind:
        p.pos = spot
        p.readyAt = 0
        break
    s.run(240, proc(s: Scenario): bool =
      if kind == medkitPickup: s.w.cogs[OurSlot].hp > 1
      else: s.w.equipment[OurSlot].armor > 0)
    if stage == Medkit:
      (if s.w.cogs[OurSlot].hp > 1: 100.0 else: 0.0)
    else:
      (if s.w.equipment[OurSlot].armor > 0: 100.0 else: 0.0)
  of Capture:
    var s = newScenario(policy, seed, @[OurSlot])
    var neutral: seq[int]
    for i, h in s.w.controlHearts:
      if not inWater(h.pos) and h.pos != home(0) and h.pos != home(1):
        neutral.add i
    let index = neutral[variant mod neutral.len]
    let heart = s.w.controlHearts[index].pos
    var start = heart
    for attempt in 0 ..< 72:
      let candidate = heart.offset(float(variant * 61 + attempt * 5) * PI / 180, 15 * Metre)
      if s.w.open(candidate) and s.w.walkClear(candidate, heart):
        start = candidate
        break
    for i, h in s.w.controlHearts.mpairs:
      if i == index:
        h.owner = -1
      elif h.owner == -1:
        h.owner = 1
    s.place(OurSlot, start, heart)
    s.run(360, proc(s: Scenario): bool = s.w.controlHearts[index].owner == 0)
    if s.w.controlHearts[index].owner == 0: 100.0 else: 0.0
  of Defend:
    var s = newScenario(policy, seed, @[OurSlot])
    var index = -1
    for i, h in s.w.controlHearts:
      if h.owner == 0 and not inWater(h.pos):
        index = i
    let heart = s.w.controlHearts[index].pos
    var start = heart
    for attempt in 0 ..< 72:
      let candidate = heart.offset(float(variant * 61 + attempt * 5) * PI / 180, 20 * Metre)
      if s.w.open(candidate) and s.w.walkClear(candidate, heart):
        start = candidate
        break
    s.place(OurSlot, start, start.offset(float(variant * 90) * PI / 180, 500))
    s.place(EnemySlot, heart.offset(float(variant) * 1.3, 60), heart)
    s.run(144)
    if s.w.controlHearts[index].owner == 0: 100.0 else: 0.0
  of GloryHeartStage:
    var s = newScenario(policy, seed, @[OurSlot])
    let (start, angle) = s.w.arena(variant, 10 * Metre)
    let spot = start.offset(angle, 10 * Metre)
    s.place(OurSlot, start, start.offset(angle + PI / 2, 500))
    s.w.gloryHearts = @[GloryHeart(pos: spot, expiresAt: s.w.tick + 30 * TickRate)]
    s.run(240, proc(s: Scenario): bool = s.w.gloryHearts.len == 0)
    if s.w.gloryHearts.len == 0: 100.0 else: 0.0
  of FriendlyFire:
    var s = newScenario(policy, seed, @[OurSlot])
    let (start, angle) = s.w.arena(variant, 30 * Metre)
    let enemy = start.offset(angle, 30 * Metre)
    s.place(OurSlot, start, enemy)
    s.place(2, start.offset(angle, 15 * Metre), enemy)
    s.place(EnemySlot, enemy, enemy.offset(angle, 500))
    s.run(192)
    if traceShots:
      stderr.writeLine &"friendly fire variant {variant}: friendly {s.friendlyDamage[OurSlot]}, enemy {s.enemyDamage[OurSlot]}"
    (if s.friendlyDamage[OurSlot] == 0: 50.0 else: 0.0) +
      (if s.enemyDamage[OurSlot] > 0: 50.0 else: 0.0)
  of FullMatch:
    configureRules(LiveRules)
    configureMap("")
    configureVision("")
    configureGlory(LeagueGlory)
    var s = Scenario(w: newLiveWorld(int32(seed), 3 * 60 * TickRate))
    s.bots = newSeq[Bot](Seats)
    let ourParity = variant mod 2
    sapperSlot = ourParity
    for slot in 0 ..< Seats:
      s.bots[slot] = (if slot mod 2 == ourParity: policyBot(policy, slot) else: loadScriptBot(baseSource, slot))
    s.run(3 * 60 * TickRate)
    let scores = s.w.scores()
    if traceShots:
      var kills, friendly, uniforms = 0
      for slot in countup(ourParity, Seats - 1, 2):
        kills += s.sprayKills[slot]
        friendly += s.sprayFriendly[slot]
        if s.w.uniforms[slot]:
          inc uniforms
      stderr.writeLine &"full match {variant}: our spray kills {kills}, spray damage to our own {friendly}, disguised at the end {uniforms}, scores {scores[ourParity]:.0f} vs {scores[1 - ourParity]:.0f}"
    if scores[ourParity] > 0:
      100.0
    elif scores[1 - ourParity] > 0:
      0.0
    else:
      50.0

proc whole(v: float): string =
  ## Formats a score as a whole number.
  $int(round(v))

proc jsonReport(policies: seq[Policy], stages: seq[Stage], rows: seq[seq[float]], variants: int): JsonNode =
  ## Returns the table as JSON for pw_report: stage names, definitions and scores by policy.
  result = %*{"variants": variants, "stages": [], "policies": {}}
  for stage in stages:
    result["stages"].add %*{"name": stageName(stage), "definition": stageDefinition(stage)}
  for j, policy in policies:
    result["policies"][policy.name] = %rows.mapIt(it[j])

proc table(policies: seq[Policy], stages: seq[Stage], variants: int): seq[seq[float]] =
  ## Runs every stage for every policy; rows are stages, columns policies.
  for stage in stages:
    var row: seq[float]
    for policy in policies:
      var total = 0.0
      for variant in 0 ..< variants:
        total += runStage(stage, policy, variant)
      row.add total / variants.float
    stderr.writeLine &"{stageName(stage)}: " & row.mapIt(whole(it)).join(" ")
    result.add row

proc markdown(policies: seq[Policy], stages: seq[Stage], rows: seq[seq[float]], variants: int): string =
  ## Renders the stage table as markdown.
  result.add "| stage | " & policies.mapIt(it.name).join(" | ") & " |\n"
  result.add "|---|" & policies.mapIt("---:").join("|") & "|\n"
  var totals = newSeq[float](policies.len)
  for r in rows:
    for j, v in r:
      totals[j] += v / rows.len.float
  result.add "| **total** | " & totals.mapIt("**" & whole(it) & "**").join(" | ") & " |\n"
  for i, stage in stages:
    result.add &"| {stageName(stage)} | " & rows[i].mapIt(whole(it)).join(" | ") & " |\n"
  result.add &"\nEach cell is the mean of {variants} variants (map spot and heading).\n"

proc html(policies: seq[Policy], stages: seq[Stage], rows: seq[seq[float]], variants: int, title, notes: string): string =
  ## Renders the stage table as a themed standalone HTML page.
  result = """<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Paintbot PW diagnostics</title><style>
:root{--bg:#fbfaf7;--fg:#1d1d1b;--muted:#6b6a64;--line:#e4e1d8;--head:#f1eee6;--good:#3d7a4a;--bad:#b0413e}
@media (prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#171716;--fg:#ecebe6;--muted:#9c9a92;--line:#34332f;--head:#22211f;--good:#7fc08c;--bad:#e0736f}}
:root[data-theme="dark"]{--bg:#171716;--fg:#ecebe6;--muted:#9c9a92;--line:#34332f;--head:#22211f;--good:#7fc08c;--bad:#e0736f}
body{background:var(--bg);color:var(--fg);font:14px/1.45 system-ui,-apple-system,sans-serif;margin:0;padding:24px 16px}
h1{font-size:22px;margin:0 0 4px}h2{font-size:17px;margin:28px 0 8px}p,li{color:var(--muted);max-width:75ch}
.wrap{overflow-x:auto}table{border-collapse:collapse}
th,td{border-bottom:1px solid var(--line);padding:5px 12px;text-align:right;white-space:nowrap}
th:first-child,td:first-child{text-align:left}thead th{background:var(--head)}
tr.total td{font-weight:700}td.c{font-variant-numeric:tabular-nums}
dl{max-width:80ch}dt{font-weight:600;margin-top:10px}dd{margin:2px 0 0 0;color:var(--muted)}
</style></head><body>
"""
  result.add &"<h1>{title}</h1><p>Each cell is 0 to 100, the mean of {variants} variants (map spot and heading) of a hand-built situation in the real engine. Columns are policies.</p>"
  result.add "<div class=\"wrap\"><table><thead><tr><th>stage</th>"
  for p in policies:
    result.add &"<th>{p.name}</th>"
  result.add "</tr></thead><tbody>"
  var totals = newSeq[float](policies.len)
  for r in rows:
    for j, v in r:
      totals[j] += v / rows.len.float
  proc colored(v: float): string =
    let hue = int(round(v * 1.2))
    &"<td class=\"c\" style=\"background:hsla({hue},55%,50%,0.18)\">{whole(v)}</td>"
  result.add "<tr class=\"total\"><td>total</td>" & totals.mapIt(colored(it)).join("") & "</tr>"
  for i, stage in stages:
    result.add &"<tr><td>{stageName(stage)}</td>" & rows[i].mapIt(colored(it)).join("") & "</tr>"
  result.add "</tbody></table></div>"
  if notes.len > 0:
    result.add "<h2>What the table says</h2><ul>"
    for line in notes.splitLines:
      if line.strip.len > 0:
        result.add "<li>" & line.strip.strip(chars = {'-', ' '}) & "</li>"
    result.add "</ul>"
  result.add "<h2>Stages</h2><dl>"
  for stage in stages:
    result.add &"<dt>{stageName(stage)}</dt><dd>{stageDefinition(stage)}</dd>"
  result.add "</dl></body></html>\n"

proc main() =
  var
    policies: seq[Policy]
    stages = toSeq(Stage)
    variants = 6
    mdPath, htmlPath, notesPath, jsonPath: string
    title = "Paintbot PW diagnostics"
    basePath = getHomeDir() / "p/paintbot-pw/coworld/paintbot/players/base.bas"
    i = 1
  while i <= paramCount():
    let argument = paramStr(i)
    case argument
    of "--stages":
      inc i
      stages = @[]
      for name in paramStr(i).split(','):
        stages.add parseEnum[Stage](name)
    of "--variants":
      inc i
      variants = parseInt(paramStr(i))
    of "--md":
      inc i
      mdPath = paramStr(i)
    of "--html":
      inc i
      htmlPath = paramStr(i)
    of "--notes":
      inc i
      notesPath = paramStr(i)
    of "--trace":
      traceShots = true
    of "--sapper":
      traceSapper = true
    of "--json":
      inc i
      jsonPath = paramStr(i)
    of "--title":
      inc i
      title = paramStr(i)
    of "--base":
      inc i
      basePath = paramStr(i)
    else:
      let parts = argument.split('=', 1)
      if parts.len != 2:
        quit("pw_diag: policies are name=path.bas", 2)
      policies.add Policy(name: parts[0], source: readFile(parts[1]), path: parts[1])
    inc i
  if policies.len == 0:
    quit("usage: pw_diag [--stages A,B] [--variants N] [--md P] [--html P] name=policy.bas ...", 2)
  baseSource = readFile(basePath)
  let rows = table(policies, stages, variants)
  let text = markdown(policies, stages, rows, variants)
  echo text
  if mdPath != "":
    writeFile(mdPath, "# " & title & "\n\n" & text)
  if htmlPath != "":
    let notes =
      if notesPath != "" and fileExists(notesPath):
        readFile(notesPath)
      else:
        ""
    writeFile(htmlPath, html(policies, stages, rows, variants, title, notes))
  if jsonPath != "":
    writeFile(jsonPath, pretty(jsonReport(policies, stages, rows, variants)))

main()
