## Myasnik — Pudge Wars policy for Andre von Auto.
## Command player rebuilt for sim 0.3.1 (polyworld-pudge-wars): 128x128
## map, river columns river_west..river_east (53..75), 840 HP butchers,
## 56-tile accelerating hooks (0.6 + 0.03/tick, cap 1.8), 9-tick rooted
## windup, 2 s cooldown, 80 hook damage, drown is a slow DoT, kills come
## from melee grinds, river strandings, and headshots. Score is the team
## kill margin: 0.5 + 0.5*(ours - theirs)/goal — a death is exactly as
## bad as a kill is good.
##
## Two principles, in priority order:
##   1. NEVER DIE. Hold a deep post (12 tiles behind the waterline),
##      juke constantly, project every visible enemy hook and dodge
##      perpendicular with a committed side, intercept point-blank
##      chains head-on (mid-air clash denies both), heal on the spawn
##      pad below 42% HP, keep the respawn shield by idling it out,
##      and never walk within 3 tiles of the drink.
##   2. Hook from safety. Exact-kinematics velocity leads through the
##      windup and the accelerating flight; headshot any visible hooked
##      enemy (a second chain on a reeling victim is an INSTANT KILL);
##      hook drowning enemies; rescue hooked or swimming allies (an
##      ally latch releases the enemy chain and heals 120); blind-hook
##      the mirrored camper posts, last-seen tracks, and ally pings
##      into the fog; sweep the rune column when nothing better shows.
##
## Protocol: JSON observations every tick; reply {walk_to, hook_to,
## halt, ping}. Empty action is sticky — and silence is how idle
## auto-acquire melee fires, so a brawl is one halt then nothing.
## Seats 0-2 West, 3-5 East; prefer self.team.

import std/[json, math], coworld_client

const
  defaultRiverWest = 53.0
  defaultRiverEast = 75.0
  islandX = 64.0
  islandY = 64.0
  islandBlock = 5.5
  playMinX = 15.0
  playMaxX = 113.0
  playMinY = 17.0
  playMaxY = 110.0
  hookBaseSpeed = 0.6
  hookAccel = 0.03
  hookSpeedMax = 1.8
  hookWindup = 9.0
  hookLatch = 5.35
  throwMax = 54.0
  engageDist = 44.0
  waterMargin = 3.0
  standoff = 12.0
  lanePitch = 24.0
  laneBase = 40.0
  dodgeScan = 48
  dodgeRadius = 8.0
  dodgeStep = 12.0
  interceptDist = 14.0
  blinkDodge = 20.0
  meleeHold = 6.5
  brawlMargin = 40.0
  retreatFrac = 0.42
  resumeFrac = 0.9
  lastSeenTicks = 192.0
  pingFresh = 96.0
  camperPost = 4.0

type
  Track = object
    x, y, vx, vy: float
    tick: float
    valid: bool

  Body = object
    slot, team: int
    x, y, hp, maxHp: float
    alive, hooked, shield, hookReady, inRiver, blinkReady: bool

  HookInfo = object
    owner, team, victim: int
    x, y, vx, vy: float

  Memory = ref object
    pudges: array[8, Track]
    hooks: array[8, Track]
    lastSeen: array[8, Track]
    spawnX, spawnY: float
    haveSpawn: bool
    dodgeSide: float
    healing: bool
    brawlHalted: bool
    blindCounter: int
    lastPingTick: float

proc num(node: JsonNode, default = 0.0): float =
  if node.isNil: default
  elif node.kind == JInt: node.getInt.float
  elif node.kind == JFloat: node.getFloat
  else: default

proc flag(node: JsonNode): bool =
  not node.isNil and node.kind == JBool and node.getBool

proc elems(node: JsonNode): seq[JsonNode] =
  if node.isNil or node.kind != JArray: @[]
  else: node.getElems

proc parseBody(node: JsonNode): Body =
  Body(
    slot: node{"slot"}.getInt,
    team: node{"team"}.getInt,
    x: num(node{"x"}),
    y: num(node{"y"}),
    hp: num(node{"hp"}),
    maxHp: num(node{"max_hp"}, 840.0),
    alive: flag(node{"alive"}),
    hooked: flag(node{"hooked"}),
    shield: flag(node{"shield"}),
    hookReady: flag(node{"hook_ready"}),
    inRiver: flag(node{"in_river"}) or node{"layer"}.getInt(-1) == 2,
    blinkReady: flag(node{"blink_ready"}))

proc dist(ax, ay, bx, by: float): float =
  hypot(ax - bx, ay - by)

proc updateTrack(track: var Track, x, y, tick: float) =
  ## One-tick velocity from consecutive sightings; teleports (respawn,
  ## dump) and stale gaps reset the estimate.
  let dt = tick - track.tick
  if track.valid and dt >= 1.0 and dt <= 4.0 and
      dist(track.x, track.y, x, y) < 3.0 * dt:
    track.vx = (x - track.x) / dt
    track.vy = (y - track.y) / dt
  else:
    track.vx = 0.0
    track.vy = 0.0
  track.x = x
  track.y = y
  track.tick = tick
  track.valid = true

proc flightTicks(span: float): float =
  ## Ticks for the hook head to fly `span` tiles: v0 + accel ramp to the
  ## cap, then constant. distance(t) = v0*t + a*t^2/2 until vmax.
  let
    rampTicks = (hookSpeedMax - hookBaseSpeed) / hookAccel
    rampSpan = hookBaseSpeed * rampTicks + 0.5 * hookAccel * rampTicks * rampTicks
  if span <= rampSpan:
    let inner = hookBaseSpeed * hookBaseSpeed + 2.0 * hookAccel * span
    (sqrt(inner) - hookBaseSpeed) / hookAccel
  else:
    rampTicks + (span - rampSpan) / hookSpeedMax

proc leadPoint(fromX, fromY, x, y, vx, vy: float): (float, float) =
  ## Iterated intercept through the rooted windup plus the flight.
  var
    aimX = x
    aimY = y
  for _ in 0 .. 3:
    let ticks = hookWindup + flightTicks(dist(fromX, fromY, aimX, aimY))
    aimX = clamp(x + vx * ticks, 1.0, 127.0)
    aimY = clamp(y + vy * ticks, 1.0, 127.0)
  (aimX, aimY)

proc islandClear(fromX, fromY, toX, toY: float): bool =
  ## The fountain rocks at the river center bounce hooks; refuse throws
  ## whose line passes within `islandBlock` of it.
  let
    dx = toX - fromX
    dy = toY - fromY
    len2 = dx * dx + dy * dy
  if len2 <= 0.0:
    return true
  let t = ((islandX - fromX) * dx + (islandY - fromY) * dy) / len2
  if t <= 0.0 or t >= 1.0:
    ## The rocks sit behind us or beyond the victim: the latch happens
    ## first, so the line is clear.
    return true
  dist(fromX + dx * t, fromY + dy * t, islandX, islandY) > islandBlock

proc onHomeBank(team: int, x, riverWest, riverEast: float): bool =
  if team == 0: x < riverWest else: x > riverEast

proc clampToBank(team: int, x, y, riverWest, riverEast: float): (float, float) =
  ## Hard no-go zone: stay `waterMargin` land-side of the waterline.
  let safeX =
    if team == 0: clamp(x, playMinX, riverWest - waterMargin)
    else: clamp(x, riverEast + waterMargin, playMaxX)
  (safeX, clamp(y, playMinY, playMaxY))

proc clampToRiver(x, y, riverWest, riverEast: float): (float, float) =
  (clamp(x, riverWest + 1.0, riverEast - 1.0), clamp(y, playMinY, playMaxY))

proc hookThreat(memory: Memory, me: Body, hooks: seq[HookInfo]):
    (bool, float, float, float, float) =
  ## Projects every enemy hook forward with its acceleration and reports
  ## the nearest one whose path grazes us: (threat, x, y, dirX, dirY).
  var bestD = 1e18
  for hook in hooks:
    if hook.team == me.team:
      continue
    let here = dist(hook.x, hook.y, me.x, me.y)
    var
      threat = here <= dodgeRadius
      speed = hypot(hook.vx, hook.vy)
    if not threat and speed >= 0.05:
      let
        dirX = hook.vx / speed
        dirY = hook.vy / speed
      for k in 1 .. dodgeScan:
        let
          travel = speed * k.float + 0.5 * hookAccel * (k.float * k.float)
          px = hook.x + dirX * travel
          py = hook.y + dirY * travel
        if px < 0.0 or px > 128.0 or py < 0.0 or py > 128.0:
          break
        if dist(px, py, me.x, me.y) <= dodgeRadius:
          threat = true
          break
    if threat and here < bestD:
      bestD = here
      result = (true, hook.x, hook.y, hook.vx, hook.vy)

proc laneRank(slot: int): int =
  ## West seats are 0-2, east 3-5; either way rank 0..2 picks a lane.
  slot mod 3

proc juke(tick: float, slot: int): float =
  ## Deterministic triangle jitter, phase-shifted per seat so the three
  ## clones never bob in unison.
  let phase = (int(tick) div 6 + slot * 7) mod 24
  if phase < 12: (phase.float / 3.0 - 2.0) * 2.0
  else: (6.0 - phase.float / 3.0) * 2.0

proc blindTarget(memory: Memory, me: Body, tick, riverWest, riverEast: float,
    pingX, pingY, pingTick: float, havePing, fogOnly: bool): (float, float) =
  ## Fog-throw rotation: fresh last-seen tracks, then ally pings, then
  ## the mirrored camper posts on the three lanes, with a rune-column
  ## sweep every fourth throw. `fogOnly` skips the memory targets when
  ## a previous candidate was island-blocked.
  let enemyPost =
    if me.team == 0: riverEast + camperPost
    else: riverWest - camperPost
  if not fogOnly:
    var
      bestAge = lastSeenTicks
      seenX = 0.0
      seenY = 0.0
      haveSeen = false
    for track in memory.lastSeen:
      if not track.valid:
        continue
      let age = tick - track.tick
      if age < bestAge:
        bestAge = age
        seenX = clamp(track.x + track.vx * min(age, 32.0), 1.0, 127.0)
        seenY = clamp(track.y + track.vy * min(age, 32.0), 1.0, 127.0)
        haveSeen = true
    if haveSeen:
      return (seenX, seenY)
    if havePing and tick - pingTick <= pingFresh and
        not onHomeBank(me.team, pingX, riverWest, riverEast):
      return (pingX, pingY)
  inc memory.blindCounter
  if memory.blindCounter mod 4 == 3:
    let sweepY = if me.y > islandY: me.y - 48.0 else: me.y + 48.0
    return (islandX + 2.0, clamp(sweepY, playMinY, playMaxY))
  let
    lane = (memory.blindCounter + laneRank(me.slot)) mod 3
    wobble = juke(tick, me.slot + 3) * 2.5
  (enemyPost, clamp(laneBase + lane.float * lanePitch + wobble, playMinY, playMaxY))

proc reelAim(memory: Memory, me, enemy: Body, hooks: seq[HookInfo]):
    (bool, float, float) =
  ## Experiment 12: execution shot on a chained enemy. The victim rides
  ## the hook head toward its owner at the reel speed, which the pudge
  ## track lags, so lead the hook head with its own tracked velocity.
  ## If our windup plus flight would outlast the remaining reel, aim at
  ## the dump point one tile in front of the hooker instead. Never
  ## refuses the shot (exp 3's refusal skipped held enemies entirely);
  ## with no visible holding hook the caller keeps the plain lead.
  for hook in hooks:
    if hook.victim != enemy.slot:
      continue
    let (aimX, aimY) = leadPoint(me.x, me.y, hook.x, hook.y, hook.vx, hook.vy)
    let arrival = hookWindup + flightTicks(dist(me.x, me.y, aimX, aimY))
    let owner = memory.pudges[min(max(hook.owner, 0), 7)]
    if owner.valid:
      let speed = max(hypot(hook.vx, hook.vy), hookBaseSpeed)
      let remaining = dist(hook.x, hook.y, owner.x, owner.y) / speed
      if arrival > remaining:
        let span = dist(owner.x, owner.y, hook.x, hook.y)
        if span > 0.5:
          return (true,
            owner.x + (hook.x - owner.x) / span * 1.5,
            owner.y + (hook.y - owner.y) / span * 1.5)
        return (true, owner.x, owner.y)
    return (true, aimX, aimY)
  (false, 0.0, 0.0)

proc chooseTarget(memory: Memory, me: Body, allies, enemies: seq[Body],
    hooks: seq[HookInfo], riverWest, riverEast: float): (bool, float, float, bool) =
  ## Best aimed throw right now: (found, aimX, aimY, isRescue).
  ## Headshots (hooked enemies) beat everything: a second chain on a
  ## reeling victim kills instantly regardless of HP.
  var
    bestScore = -1e18
    found = false
    aimX, aimY: float
    rescue = false
  for enemy in enemies:
    if not enemy.alive or enemy.shield:
      continue
    let track = memory.pudges[min(enemy.slot, 7)]
    var (px, py) = leadPoint(me.x, me.y, enemy.x, enemy.y, track.vx, track.vy)
    if enemy.hooked:
      let (onChain, rx, ry) = reelAim(memory, me, enemy, hooks)
      if onChain:
        px = rx
        py = ry
    let reach = dist(me.x, me.y, px, py)
    if reach > throwMax:
      continue
    if not islandClear(me.x, me.y, px, py):
      continue
    var score = 100.0 - reach
    if enemy.hooked:
      score += 4000.0
    if enemy.inRiver:
      score += 900.0
    if onHomeBank(me.team, enemy.x, riverWest, riverEast):
      score += 700.0
    if enemy.hp <= 240.0:
      score += 120.0
    if reach > engageDist and not (enemy.hooked or enemy.inRiver):
      continue
    if score > bestScore:
      bestScore = score
      found = true
      aimX = px
      aimY = py
      rescue = false
  ## Rescue throws: pull a hooked or drowning ally home (the latch
  ## breaks the enemy chain and heals 120). Only from a dry stance so
  ## the one-tile dump lands them on our bank.
  if onHomeBank(me.team, me.x, riverWest, riverEast) and
      abs(me.x - (if me.team == 0: riverWest else: riverEast)) >= waterMargin:
    for ally in allies:
      if ally.slot == me.slot or not ally.alive:
        continue
      if not (ally.hooked or ally.inRiver):
        continue
      let track = memory.pudges[min(ally.slot, 7)]
      let (px, py) = leadPoint(me.x, me.y, ally.x, ally.y, track.vx, track.vy)
      let reach = dist(me.x, me.y, px, py)
      if reach > throwMax or not islandClear(me.x, me.y, px, py):
        continue
      let score = (if ally.hooked: 2000.0 else: 500.0) - reach
      if score > bestScore:
        bestScore = score
        found = true
        aimX = px
        aimY = py
        rescue = true
  (found, aimX, aimY, rescue)

proc decide(obs: JsonNode, memory: Memory): JsonNode =
  let selfNode = obs{"self"}
  if selfNode.isNil or selfNode.kind != JObject:
    return %*{}
  let
    me = parseBody(selfNode)
    tick = num(obs{"tick"})
    riverWest = num(obs{"river_west"}, defaultRiverWest)
    riverEast = num(obs{"river_east"}, defaultRiverEast)
    visible = obs{"visible"}

  if me.alive and not memory.haveSpawn:
    memory.spawnX = me.x
    memory.spawnY = me.y
    memory.haveSpawn = true
  if not me.alive:
    memory.pudges[min(me.slot, 7)].valid = false
    memory.brawlHalted = false
    memory.healing = false
    return %*{}

  var
    allies: seq[Body]
    enemies: seq[Body]
    hookInfos: seq[HookInfo]
    ownHookFlying = false
  for node in elems(visible{"pudges"}):
    let body = parseBody(node)
    if body.slot >= 0 and body.slot < 8:
      if body.alive:
        updateTrack(memory.pudges[body.slot], body.x, body.y, tick)
      else:
        memory.pudges[body.slot].valid = false
    if body.team == me.team:
      allies.add body
    else:
      enemies.add body
      if body.alive and body.slot >= 0 and body.slot < 8:
        updateTrack(memory.lastSeen[body.slot], body.x, body.y, tick)
  for node in elems(visible{"hooks"}):
    let
      owner = node{"owner"}.getInt
      team = node{"team"}.getInt
      victim = node{"victim"}.getInt(-1)
      hx = num(node{"x"})
      hy = num(node{"y"})
    if owner == me.slot:
      ownHookFlying = true
    if owner >= 0 and owner < 8:
      updateTrack(memory.hooks[owner], hx, hy, tick)
      hookInfos.add HookInfo(
        owner: owner, team: team, victim: victim, x: hx, y: hy,
        vx: memory.hooks[owner].vx, vy: memory.hooks[owner].vy)

  var
    pingX, pingY, pingTick: float
    havePing = false
  let ping = obs{"ally_ping"}
  if not ping.isNil and ping.kind == JObject:
    pingX = num(ping{"x"})
    pingY = num(ping{"y"})
    pingTick = num(ping{"tick"})
    havePing = true

  let
    (threat, threatX, threatY, threatVx, threatVy) =
      hookThreat(memory, me, hookInfos)
    canCast = me.hookReady and not ownHookFlying
    homeSide = onHomeBank(me.team, me.x, riverWest, riverEast)

  ## Hooked: orders are wiped and dodging is impossible. Spite-throw at
  ## the nearest enemy — the reel is dragging us straight to them.
  if me.hooked:
    memory.brawlHalted = false
    if canCast:
      var
        bestD = 1e18
        aimX, aimY: float
        foundSpite = false
      for enemy in enemies:
        if not enemy.alive or enemy.shield:
          continue
        let d = dist(me.x, me.y, enemy.x, enemy.y)
        if d < bestD:
          bestD = d
          aimX = enemy.x
          aimY = enemy.y
          foundSpite = true
      if foundSpite:
        return %*{"hook_to": [aimX, aimY], "ping": [me.x, me.y]}
    return %*{"ping": [me.x, me.y]}

  ## Fresh respawn shield: hooks fly straight through us and the pad
  ## trickle-heals — idle it out rather than break it with an order.
  if me.shield and not threat:
    return %*{}

  var action = newJObject()

  ## Throw selection stacks under movement.
  var threw = false
  if canCast:
    if threat and dist(me.x, me.y, threatX, threatY) <= interceptDist:
      ## Point-blank chain: shoot it out of the air (a mid-air clash
      ## breaks both hooks and nobody is grabbed).
      action["hook_to"] = %*[threatX, threatY]
      threw = true
    elif not threat:
      let (found, aimX, aimY, rescue) =
        chooseTarget(memory, me, allies, enemies, hookInfos, riverWest, riverEast)
      if found:
        action["hook_to"] = %*[aimX, aimY]
        threw = true
        if not rescue:
          action["ping"] = %*[aimX, aimY]
          memory.lastPingTick = tick
      elif homeSide and not memory.healing:
        for attempt in 0 .. 3:
          var (aimX, aimY) = blindTarget(
            memory, me, tick, riverWest, riverEast,
            pingX, pingY, pingTick, havePing, attempt > 0)
          if not islandClear(me.x, me.y, aimX, aimY):
            continue
          ## The aim point only sets the direction; the hook flies its
          ## full range regardless, so pull a far target onto the ray.
          let span = dist(me.x, me.y, aimX, aimY)
          if span > throwMax:
            let scale = throwMax / span
            aimX = me.x + (aimX - me.x) * scale
            aimY = me.y + (aimY - me.y) * scale
          action["hook_to"] = %*[aimX, aimY]
          threw = true
          break

  ## Movement, in priority order: dodge, stranded play, heal, brawl,
  ## chase a catch, hold the deep post.
  if threat:
    memory.brawlHalted = false
    let speed = hypot(threatVx, threatVy)
    if memory.dodgeSide == 0.0:
      if speed >= 0.05:
        let cross = threatVx * (me.y - threatY) - threatVy * (me.x - threatX)
        memory.dodgeSide = if cross >= 0.0: 1.0 else: -1.0
      else:
        memory.dodgeSide = if me.y >= islandY: -1.0 else: 1.0
      if me.y < playMinY + dodgeStep:
        memory.dodgeSide = 1.0
      elif me.y > playMaxY - dodgeStep:
        memory.dodgeSide = -1.0
    let
      backX =
        if me.team == 0: me.x - 3.0
        else: me.x + 3.0
      wantY = me.y + memory.dodgeSide * dodgeStep
    let (safeX, safeY) =
      if me.inRiver: clampToRiver(backX, wantY, riverWest, riverEast)
      elif homeSide: clampToBank(me.team, backX, wantY, riverWest, riverEast)
      else: clampToBank(1 - me.team, backX, wantY, riverWest, riverEast)
    ## 0.3.2 blink dodge: a ready blink clears the latch radius at once
    ## (a walked 12-tile sidestep takes ~27 ticks; the hook arrives in
    ## ~12-30). Hop 20 tiles along our bank on the committed side.
    if me.blinkReady and homeSide:
      let (hopX, hopY) = clampToBank(me.team, backX,
        me.y + memory.dodgeSide * blinkDodge, riverWest, riverEast)
      action["blink_to"] = %*[hopX, hopY]
      return action
    action["walk_to"] = %*[safeX, safeY]
    return action
  memory.dodgeSide = 0.0

  if me.inRiver:
    ## Dumped in the drink (0.3.2): Blink hops 48 tiles along a ray and
    ## river water is air for it, so a ready blink lands us straight on
    ## our deep post — no drown ticks, no rescue chain needed. Otherwise
    ## walking cannot climb a bank: hug the home-side waterline, juke,
    ## and call it in.
    if me.blinkReady:
      let postX =
        if me.team == 0: riverWest - standoff
        else: riverEast + standoff
      action["blink_to"] = %*[postX, clamp(me.y, playMinY, playMaxY)]
      return action
    let edgeX =
      if me.team == 0: riverWest + 1.0
      else: riverEast - 1.0
    let (safeX, safeY) = clampToRiver(
      edgeX, me.y + juke(tick, me.slot) * 2.0, riverWest, riverEast)
    action["walk_to"] = %*[safeX, safeY]
    if tick - memory.lastPingTick > 16.0:
      action["ping"] = %*[me.x, me.y]
      memory.lastPingTick = tick
    return action

  if not homeSide:
    ## Stranded on the enemy bank after a reel: kite away from the
    ## nearest butcher and keep throwing point-blank (handled above).
    var
      bestD = 1e18
      nearX = me.x
      nearY = me.y
    for enemy in enemies:
      if not enemy.alive:
        continue
      let d = dist(me.x, me.y, enemy.x, enemy.y)
      if d < bestD:
        bestD = d
        nearX = enemy.x
        nearY = enemy.y
    let awayY = if nearY >= me.y: me.y - 14.0 else: me.y + 14.0
    let awayX =
      if me.team == 0: me.x + 6.0
      else: me.x - 6.0
    let (safeX, safeY) = clampToBank(
      1 - me.team, awayX, awayY, riverWest, riverEast)
    action["walk_to"] = %*[safeX, safeY]
    return action

  ## Pad healing below the retreat line; stay until nearly topped up.
  if memory.healing and me.hp >= me.maxHp * resumeFrac:
    memory.healing = false
  if me.hp < me.maxHp * retreatFrac:
    memory.healing = true
  if memory.healing and memory.haveSpawn:
    if dist(me.x, me.y, memory.spawnX, memory.spawnY) <= 1.5:
      if not memory.brawlHalted:
        memory.brawlHalted = true
        return %*{"halt": true}
      return %*{}
    memory.brawlHalted = false
    let (safeX, safeY) = clampToBank(
      me.team, memory.spawnX, memory.spawnY, riverWest, riverEast)
    action["walk_to"] = %*[safeX, safeY]
    return action

  ## Brawl: an enemy stranded on our bank inside melee reach — one halt,
  ## then silence, so idle auto-acquire swings for us every tick.
  var
    brawlTarget = false
    catchX, catchY: float
    haveCatch = false
  for enemy in enemies:
    if not enemy.alive or enemy.shield:
      continue
    if enemy.hooked:
      catchX = enemy.x
      catchY = enemy.y
      haveCatch = true
    if not onHomeBank(me.team, enemy.x, riverWest, riverEast):
      continue
    let d = dist(me.x, me.y, enemy.x, enemy.y)
    if d <= meleeHold and
        (me.hp + brawlMargin >= enemy.hp or enemy.hp <= 60.0):
      brawlTarget = true
    elif d <= 20.0 and me.hp + brawlMargin >= enemy.hp:
      catchX = enemy.x
      catchY = enemy.y
      haveCatch = true
  if brawlTarget:
    if not memory.brawlHalted:
      memory.brawlHalted = true
      return %*{"halt": true}
    if threw:
      return action
    return %*{}
  memory.brawlHalted = false

  ## A victim is on a chain (ours or an ally's): close so the dump lands
  ## in melee range.
  if haveCatch and me.hp >= me.maxHp * 0.5:
    let (safeX, safeY) = clampToBank(
      me.team, catchX, catchY, riverWest, riverEast)
    action["walk_to"] = %*[safeX, safeY]
    return action

  ## Deep post: 12 tiles behind the waterline on our lane, juking. Bias
  ## toward the freshest enemy sighting so aimed throws stay short.
  let postX =
    if me.team == 0: riverWest - standoff
    else: riverEast + standoff
  var postY = laneBase + laneRank(me.slot).float * lanePitch
  var bestAge = lastSeenTicks
  for track in memory.lastSeen:
    if not track.valid:
      continue
    let age = tick - track.tick
    if age < bestAge:
      bestAge = age
      postY = clamp(track.y, postY - 12.0, postY + 12.0)
  postY += juke(tick, me.slot)
  let (safeX, safeY) = clampToBank(me.team, postX, postY, riverWest, riverEast)
  action["walk_to"] = %*[safeX, safeY]
  ## Share fresh sightings so the clones converge their fog throws.
  if not action.hasKey("ping") and tick - memory.lastPingTick > 16.0:
    var
      bestD = 1e18
      seenX, seenY: float
      seen = false
    for enemy in enemies:
      if not enemy.alive:
        continue
      let d = dist(me.x, me.y, enemy.x, enemy.y)
      if d < bestD:
        bestD = d
        seenX = enemy.x
        seenY = enemy.y
        seen = true
    if seen:
      action["ping"] = %*[seenX, seenY]
      memory.lastPingTick = tick
  return action

proc main() =
  let
    client = newCoworldClient("myasnik")
    memory = Memory()
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "observation":
      client.send(decide(message, memory))
    of "final":
      echo "myasnik: final, score ", message{"score"}
      quit(0)
    else:
      if flag(message{"done"}):
        echo "myasnik: done"
        quit(0)
      if message{"type"}.getStr() == "" and message{"self"} != nil:
        client.send(decide(message, memory))

when not defined(myasnikTest):
  main()
