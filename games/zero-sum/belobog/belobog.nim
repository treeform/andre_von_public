## Belobog — Zero Sum (battle royale, 16 agents / 8 teams) policy for
## Andre von Auto. Nim port of the bundled reference player
## `/app/zero_sum_baseline` (player/baseline.nim in arisklar6/battle-royal
## @ master), with the local-play coach mode stripped and the default
## survival knobs inlined as constants.
##
## Doctrine (unchanged from upstream): kills pay little next to placement,
## so outlive — obey the ring first, keep distance, heal early, fight only
## when cornered / to finish an adjacent critical / at the finale, loot
## and forage opportunistically, and use the open chat to talk out of
## fights. Protocol: zero_sum.player.v1 JSON over websocket — allocate
## stats during the countdown, then one action per observation tick.
## No LLM, no secrets.

import std/json, coworld_client

const
  ## Speed-max survival alloc: move cd = 16-SPD is paid every step this
  ## ladder takes; INT 5 is the vision-8 breakpoint that matches heal-clear
  ## radius 8; STR is melee-only and we almost never swing; ATH 4 matches
  ## ATH 5 on stage-7 zone pulse count (both die on the 5th pulse).
  statSpeed = 10
  statStrength = 1
  statIntelligence = 5
  statAthleticism = 4
  ## Behavior knobs (upstream defaults).
  aggression = 3            # 0..10; >=5 chases criticals at weapon range
  healBelowHp = 70          # heal when hp below this and nobody is close
  fleeBelowHp = 55          # flee visible enemies below this hp
  ringMargin = 2            # stay this far inside the NEXT ring radius

  directionNames = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
  deltaX = [0, 1, 1, 1, 0, -1, -1, -1]
  deltaY = [-1, -1, 0, 1, 1, 1, 0, -1]

type Bot = object
  slot: int
  numPlayers: int
  aliveEstimate: int        # numPlayers minus death fireworks seen
  arenaSize: int
  staticMap: seq[string]
  finaleOn: bool
  ## Talk bookkeeping — the transcript is the match's public record.
  lastTalkTick: int
  lastContactTick: int
  lastHurtTick: int
  lastGiftTick: int
  saidPlan: bool
  saidFinale: bool
  saidPodium: bool

proc blockedAt(bot: Bot, x, y: int): bool =
  if x < 0 or y < 0 or x >= bot.arenaSize or y >= bot.arenaSize:
    return true
  bot.staticMap[y][x] in {'#', 'R', 'F'}

proc stepToward(bot: Bot, fromX, fromY, toX, toY: int): int =
  ## Greedy 8-direction step toward the target; the unblocked direction
  ## minimizing remaining distance. -1 when boxed in.
  result = -1
  var bestDistance2 = int.high
  for direction in 0 .. 7:
    let nextX = fromX + deltaX[direction]
    let nextY = fromY + deltaY[direction]
    if bot.blockedAt(nextX, nextY):
      continue
    let distance2 = (nextX - toX) * (nextX - toX) +
      (nextY - toY) * (nextY - toY)
    if distance2 < bestDistance2:
      bestDistance2 = distance2
      result = direction

proc stepAway(bot: Bot, fromX, fromY, awayX, awayY: int): int =
  result = -1
  var bestDistance2 = -1
  for direction in 0 .. 7:
    let nextX = fromX + deltaX[direction]
    let nextY = fromY + deltaY[direction]
    if bot.blockedAt(nextX, nextY):
      continue
    let distance2 = (nextX - awayX) * (nextX - awayX) +
      (nextY - awayY) * (nextY - awayY)
    if distance2 > bestDistance2:
      bestDistance2 = distance2
      result = direction

proc stepAwaySafe(bot: Bot, fromX, fromY, enemyX, enemyY,
    centerX, centerY, maxRadius: int): int =
  ## Evade WITHOUT backing into the fire: of the unblocked steps that stay
  ## within maxRadius of the zone center, take the one that opens the most
  ## distance from the enemy. Plain stepAway walked bots into the ring.
  result = -1
  var bestDistance2 = -1
  for direction in 0 .. 7:
    let nextX = fromX + deltaX[direction]
    let nextY = fromY + deltaY[direction]
    if bot.blockedAt(nextX, nextY):
      continue
    if (nextX - centerX) * (nextX - centerX) +
        (nextY - centerY) * (nextY - centerY) > maxRadius * maxRadius:
      continue
    let distance2 = (nextX - enemyX) * (nextX - enemyX) +
      (nextY - enemyY) * (nextY - enemyY)
    if distance2 > bestDistance2:
      bestDistance2 = distance2
      result = direction
  if result < 0:
    result = bot.stepAway(fromX, fromY, enemyX, enemyY)

proc alignedDirection(fromX, fromY, toX, toY: int): int =
  ## Straight 8-direction line from source to target, or -1.
  let dx = toX - fromX
  let dy = toY - fromY
  if dx == 0 and dy == 0:
    return -1
  if dx == 0 or dy == 0 or abs(dx) == abs(dy):
    let signX = (if dx > 0: 1 elif dx < 0: -1 else: 0)
    let signY = (if dy > 0: 1 elif dy < 0: -1 else: 0)
    for direction in 0 .. 7:
      if deltaX[direction] == signX and deltaY[direction] == signY:
        return direction
  -1

proc weaponRank(id: string): int =
  case id
  of "sword": 6
  of "spear": 5
  of "bow": 4
  of "knives": 3
  of "blowgun": 2
  of "net": 1
  else: 0

proc maybeTalk(bot: var Bot, message: JsonNode, client: CoworldClient) =
  ## Event-driven chatter: negotiate, don't narrate. The sim rate-limits
  ## to 1 msg/s; we stay sparser so the transcript reads as intent.
  let tick = message{"tick"}.getInt(0)
  if tick - bot.lastTalkTick < 96:
    return
  let you = message["you"]
  let x = you["pos"][0].getInt()
  let y = you["pos"][1].getInt()
  let hp = you["hp"].getInt()

  template say(channelArg: string, toArg: int, textArg: string) =
    client.send(%*{"type": "talk", "channel": channelArg, "to": toArg,
                   "text": textArg})
    bot.lastTalkTick = tick
    return

  for event in message{"events"}.getElems():
    case event{"type"}.getStr()
    of "ignition":
      if not bot.saidPlan:
        bot.saidPlan = true
        say("broadcast", -1,
            "blood pays little here. stay out of my way and we all place")
    of "finale":
      if not bot.saidFinale:
        bot.saidFinale = true
        say("broadcast", -1, "two of us left. no hard feelings")
    of "gift_landed":
      if tick - bot.lastGiftTick > 240 and event{"pos"} != nil:
        let giftX = event["pos"][0].getInt()
        let giftY = event["pos"][1].getInt()
        if (giftX - x) * (giftX - x) + (giftY - y) * (giftY - y) <= 144:
          bot.lastGiftTick = tick
          say("broadcast", -1, "the drop at (" & $giftX & "," & $giftY &
              ") is spoken for. contest it and we both lose points")
    else:
      discard

  if bot.aliveEstimate == 3 and not bot.saidPodium:
    bot.saidPodium = true
    say("broadcast", -1,
        "podium locked. every fight now is minus points - let the ring settle it")
  if hp < 25 and tick - bot.lastHurtTick > 480:
    bot.lastHurtTick = tick
    say("broadcast", -1,
        "im no threat to anyone. finishing me buys you nothing")
  if tick - bot.lastContactTick > 240:
    for agent in message["visible"]["agents"]:
      let slot = agent["slot"].getInt()
      bot.lastContactTick = tick
      say("dm", slot, "i see you P" & $slot &
          ". a kill is one point - walk away and outlive someone else")

proc decide(bot: var Bot, message: JsonNode): JsonNode =
  ## Survival doctrine in strict priority: the ring kills more agents than
  ## agents do, distance is the only free armour, and the only fights worth
  ## taking are the ones that end an adjacent threat.
  let you = message["you"]
  let x = you["pos"][0].getInt()
  let y = you["pos"][1].getInt()
  let hp = you["hp"].getInt()
  let handId = you["hand"]{"id"}.getStr("none")
  if message["phase"].getStr() == "countdown":
    return %*{"type": "action", "do": "none"}
  for event in message{"events"}.getElems():
    case event{"type"}.getStr()
    of "finale": bot.finaleOn = true
    of "death_fireworks": bot.aliveEstimate = max(1, bot.aliveEstimate - 1)
    else: discard

  let zone = message["zone"]
  let centerX = zone["center"][0].getInt()
  let centerY = zone["center"][1].getInt()
  let myDistance2 = (x - centerX) * (x - centerX) +
    (y - centerY) * (y - centerY)
  let currentRadius = zone["radius"].getInt()
  let nextRadius = zone["next_radius"].getInt()
  # The podium is the payday: with four left, take zero avoidable risks.
  let nearPodium = bot.aliveEstimate <= 4
  let safeRadius = max(1, nextRadius - ringMargin)

  # Nearest opponent — everyone is one.
  var enemyDistance2 = int.high
  var enemyX = -1
  var enemyY = -1
  var enemyCritical = false
  for agent in message["visible"]["agents"]:
    let agentX = agent["pos"][0].getInt()
    let agentY = agent["pos"][1].getInt()
    let distance2 = (agentX - x) * (agentX - x) + (agentY - y) * (agentY - y)
    if distance2 < enemyDistance2:
      enemyDistance2 = distance2
      enemyX = agentX
      enemyY = agentY
      enemyCritical = agent["hp_band"].getStr() == "critical"

  # 0. Never restart an active channel (heal/forage completes on its own).
  for effect in you["effects"]:
    if effect{"id"}.getStr() == "channeling":
      return %*{"type": "action", "do": "none"}
  # 1. The fire is the deadliest opponent: outside the CURRENT radius,
  # nothing else matters.
  if myDistance2 > currentRadius * currentRadius:
    let direction = bot.stepToward(x, y, centerX, centerY)
    if direction >= 0:
      return %*{"type": "action", "do": "move",
                "dir": directionNames[direction]}
  # 2. Threat response. Disengage by default, but a cornered bot with a
  # weapon swings, and an adjacent critical enemy is ended before it heals.
  let weaponRange = (case handId
                     of "bow": 8
                     of "knives": 5
                     of "blowgun": 6
                     of "spear": 2
                     else: 1)
  # The last-two showdown must END: evading into a closed ring scores a
  # double death and no winner. Fists count — no weapon requirement.
  let finaleHunt = bot.finaleOn and
    (currentRadius <= 8 or (weaponRank(handId) >= 1 and hp >= 55))
  # Terminal burn: ring fully closed, placement goes to whoever dies LAST —
  # every point of damage dealt now moves us up, pacifism stops paying here.
  let terminalBurn = currentRadius <= 2
  if enemyX >= 0:
    let threatened = enemyDistance2 <= 9
    let mustFlee = (hp < fleeBelowHp or weaponRank(handId) == 0 or
                    (nearPodium and not bot.finaleOn)) and not terminalBurn
    if threatened and mustFlee and not finaleHunt:
      let direction = bot.stepAwaySafe(x, y, enemyX, enemyY,
        centerX, centerY, safeRadius)
      if direction >= 0:
        return %*{"type": "action", "do": "move",
                  "dir": directionNames[direction]}
    if weaponRank(handId) >= 1 or finaleHunt or terminalBurn:
      let attackDirection = alignedDirection(x, y, enemyX, enemyY)
      # Finish an adjacent critical, answer an adjacent threat, hunt at the
      # finale, or race the burn — never chase across the arena.
      let engage =
        (enemyDistance2 <= 2 and (enemyCritical or hp >= fleeBelowHp)) or
        (enemyCritical and enemyDistance2 <= weaponRange * weaponRange and
         aggression >= 5) or
        finaleHunt or terminalBurn
      if engage:
        if attackDirection >= 0 and
            enemyDistance2 <= weaponRange * weaponRange:
          return %*{"type": "action", "do": "attack",
                    "dir": directionNames[attackDirection]}
        if finaleHunt or terminalBurn:
          let direction = bot.stepToward(x, y, enemyX, enemyY)
          if direction >= 0:
            return %*{"type": "action", "do": "move",
                      "dir": directionNames[direction]}
    # Armed but not engaging: open space toward the safe band.
    if threatened:
      let direction = bot.stepAwaySafe(x, y, enemyX, enemyY,
        centerX, centerY, safeRadius)
      if direction >= 0:
        return %*{"type": "action", "do": "move",
                  "dir": directionNames[direction]}
  # 3. Heal early: hp is placement. Safe means nobody within striking
  # distance, not nobody visible at all.
  if hp < healBelowHp and (enemyX < 0 or enemyDistance2 > 64):
    for slot in 0 ..< you["pack"].len:
      let packSlot = you["pack"][slot]
      if packSlot.kind != JNull and
          packSlot{"id"}.getStr() in ["first_aid", "rations"]:
        return %*{"type": "action", "do": "use", "slot": slot}
  # 4. Ring preparation: stay ringMargin inside the NEXT radius.
  if myDistance2 > safeRadius * safeRadius:
    let direction = bot.stepToward(x, y, centerX, centerY)
    if direction >= 0:
      return %*{"type": "action", "do": "move",
                "dir": directionNames[direction]}
  # 5. Loot: pick up anything on my tile; walk to the best visible item or
  # pod — inbound included. visible.pods is not fog-gated and the 120-tick
  # descent is a race SPD 10 wins from ~20 tiles out; waiting until landed
  # hands first-aid (placement) to whoever pre-walked. Never walk INTO
  # someone to do it. Hold an inbound landing tile so spacing does not
  # step off before the crate exists.
  var onMyTile = false
  var inboundOnTile = false
  for item in message["visible"]["items"]:
    if item["pos"][0].getInt() == x and item["pos"][1].getInt() == y:
      onMyTile = true
  for pod in message["visible"]["pods"]:
    if pod["pos"][0].getInt() == x and pod["pos"][1].getInt() == y:
      if pod["landed"].getBool():
        onMyTile = true
      else:
        inboundOnTile = true
  if onMyTile:
    return %*{"type": "action", "do": "pickup"}
  if inboundOnTile:
    return %*{"type": "action", "do": "none"}
  if enemyX < 0 or enemyDistance2 > 36:
    var targetX = -1
    var targetY = -1
    var bestScore = -1
    for item in message["visible"]["items"]:
      let id = item["id"].getStr()
      # Healing IS placement; a weapon is insurance for being cornered.
      let score = (case id
                   of "first_aid": 24
                   of "rations": 18
                   else: 10 + weaponRank(id))
      if score > bestScore:
        bestScore = score
        targetX = item["pos"][0].getInt()
        targetY = item["pos"][1].getInt()
    for pod in message["visible"]["pods"]:
      let mine = pod["recipient_slot"].getInt() == bot.slot
      let score = (if mine: 40 else: 20)
      if score > bestScore:
        bestScore = score
        targetX = pod["pos"][0].getInt()
        targetY = pod["pos"][1].getInt()
    if targetX >= 0:
      let direction = bot.stepToward(x, y, targetX, targetY)
      if direction >= 0:
        return %*{"type": "action", "do": "move",
                  "dir": directionNames[direction]}
  # 6. Forage when standing on a charged bush.
  for bush in message["visible"]["bushes"]:
    if bush["pos"][0].getInt() == x and bush["pos"][1].getInt() == y and
        bush["charges"].getInt() > 0:
      return %*{"type": "action", "do": "interact"}
  # 7. Movement doctrine: SPACING — the center crowd is where the pointless
  # fights happen, so hold the safe band and keep visible agents at arm's
  # length. The ring shepherds everyone together at the end.
  if enemyX >= 0 and enemyDistance2 <= 25:
    let direction = bot.stepAwaySafe(x, y, enemyX, enemyY,
      centerX, centerY, safeRadius)
    if direction >= 0:
      return %*{"type": "action", "do": "move",
                "dir": directionNames[direction]}
  if myDistance2 > safeRadius * safeRadius or
      (safeRadius <= 6 and myDistance2 > 4):
    let direction = bot.stepToward(x, y, centerX, centerY)
    if direction >= 0:
      return %*{"type": "action", "do": "move",
                "dir": directionNames[direction]}
  %*{"type": "action", "do": "none"}

proc allocateFrame(): JsonNode =
  %*{"type": "allocate_stats", "speed": statSpeed, "strength": statStrength,
     "intelligence": statIntelligence, "athleticism": statAthleticism}

proc main() =
  let client = newCoworldClient("belobog")
  var bot = Bot(numPlayers: 16, aliveEstimate: 16)
  # First valid allocation wins and is immutable; a duplicate retry is safe
  # (the server echoes what we already have), so send early and re-send
  # after player_config in case the first frame raced the seat setup.
  client.send(allocateFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "player_config":
      bot.slot = message["slot"].getInt()
      bot.numPlayers = message{"num_players"}.getInt(16)
      bot.aliveEstimate = bot.numPlayers
      bot.arenaSize = message["arena"]["size"].getInt()
      bot.staticMap = @[]
      for row in message["arena"]["static_map"]:
        bot.staticMap.add(row.getStr())
      client.send(allocateFrame())
      echo "belobog: slot ", bot.slot, " team ", message{"team"}.getStr()
    of "observation":
      if bot.staticMap.len > 0:
        bot.maybeTalk(message, client)
        client.send(bot.decide(message))
    of "final":
      echo "belobog: final, placement ", message{"placement"}.getInt(),
        " score ", message{"score"}.getInt()
      quit(0)
    else:
      discard

main()
