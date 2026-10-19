## Seryi Volk — Cooperative Hunting policy for Andre von Auto.
## Unlike the pure prompt seats, this player is NOT thin: it registers an
## operator prompt over the sprite_v1 websocket (0x90), and then walks the
## hunter itself, tick by tick — the game only hands back one plan (0x91)
## per 120-tick planning turn. The executor and the eight scripted
## baselines are vendored from the reference player (hunting_bots.nim), so
## a Seryi Volk seat walks with the same feet as the bundled bots and
## degrades to big_game_hunter whenever no usable plan is in force.
##
## Env:
##   PLAYER_PROMPT            override the built-in operator prompt
##   PLAYER_SCRIPTED          play a compiled baseline instead (rabbiteer |
##                            nearest_hunter | stag_hunter | moose_hunter |
##                            elephant_hunter | big_game_hunter | sidekick |
##                            modeler)
##   PLAYER_FALLBACK_SCRIPTED what a prompt seat plays between plans
##                            (default big_game_hunter)
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays scripted.

import std/[json, options, os, parseopt, strutils, unicode]
import whisky
import hunting_bots

const defaultPrompt = """
You are Seryi Volk, the grey wolf who hunts as a pack. Only captures
score, and every hunter on a side is paid IN FULL - shared kills are free
money, so commit with allies, never alone.
Take the richest target your visible party can finish: count hunters
within 6 tiles including you; 1 = rabbits, 2 = stag (opposite sides) or
boar (perpendicular), 3 = moose, 4 = elephant (all four sides, 18 each -
always call it when four are close). One big kill beats two small ones;
discount far targets.
Name partners in "with", claim your side, and KEEP the same target until
it is dead or gone - flip-flopping wastes the window. Use say to rally:
the animal, its coords, which sides are open.
Rest before you are stranded (moving costs 2 energy). Flee a moose or
elephant you cannot finish - half rings get gored.
coop-mining: gold needs two hunters within 3 ticks - pair up and call the
node; mine iron solo between pairings.
lbf: join pickups where adjacent levels sum to the food level; biggest
unlockable food first.
predator-prey: hunting, pair on OPPOSITE sides of a forager; foraging,
eat berries, hide in tall grass, avoid paired hunters.
Note: track who kept commitments; prefer reliable partners.
"""

const
  PlayerWebSocketPath = "/player"
  ConnectRetryDelayMs = 250
  MaxConnectAttempts = 240   ## 60 s of retries, then give up and exit 0
  ## Every wait is bounded: 5 s is 40 frames at the 8 Hz tick, so it never
  ## fires during play; 120 s of total silence is longer than any
  ## legitimate quiet stretch (the roster wait before the first frame is
  ## 45 s).
  ReceiveTimeoutMs = 5_000
  MaxIdleReceiveMs = 120_000

type
  Policy = object
    isPrompt: bool
    prompt: string
    baseline: BaselineKind

  ActivePlan = object
    valid: bool
    turn: int
    intent: string
    target: string
    side: string
    targetX: int
    targetY: int
    hasCoords: bool

## Policy selection

proc resolvePolicy(): Policy =
  let prompt = getEnv("PLAYER_PROMPT", defaultPrompt).strip()
  let scripted = getEnv("PLAYER_SCRIPTED").strip()
  let fallback = getEnv("PLAYER_FALLBACK_SCRIPTED").strip()
  # PLAYER_SCRIPTED selects a scripted seat outright; the fallback is what
  # a PROMPT seat plays between plans and when a plan is unusable.
  result.baseline =
    if scripted.len > 0: parseBaselineKind(scripted)
    elif fallback.len > 0: parseBaselineKind(fallback)
    else: BigGameHunterBot
  if scripted.len == 0 and prompt.len > 0:
    result.isPrompt = true
    result.prompt = runeCap(prompt, MaxPromptRunes)

proc registrationBody(policy: Policy): string =
  if policy.isPrompt:
    $(%*{"kind": "prompt", "prompt": policy.prompt})
  else:
    $(%*{"kind": "scripted", "baseline": baselineName(policy.baseline)})

proc registrationPacket(policy: Policy): string =
  ## `0x90 <u16 len little-endian> <len bytes UTF-8 JSON>`, len <= 4096.
  var body = policy.registrationBody()
  if body.len > MaxRegistrationBytes:
    body = $(%*{"kind": "scripted", "baseline": "big_game_hunter"})
  var bytes: seq[uint8] = @[0x90'u8]
  bytes.add(uint8(body.len and 0xff))
  bytes.add(uint8((body.len shr 8) and 0xff))
  for ch in body:
    bytes.add(uint8(ord(ch)))
  blobFromBytes(bytes)

## The executor: a plan turned into per-tick masks

proc parsePlanMessage(data: string): ActivePlan =
  ## `0x91 <u16 len> <len bytes UTF-8 JSON>`.
  if data.len < 3 or data[0].uint8 != 0x91'u8:
    return
  let length = int(data[1].uint8) or (int(data[2].uint8) shl 8)
  if length <= 0 or data.len < 3 + length:
    return
  let body = data[3 ..< 3 + length]
  if validateUtf8(body) != -1:
    return
  try:
    let node = parseJson(body)
    result.turn = node{"turn"}.getInt()
    result.intent = node{"intent"}.getStr("hunt")
    result.target = node{"target"}.getStr("none")
    result.side = node{"side"}.getStr("any")
    result.valid = true
    let at = result.target.rfind('@')
    if at > 0 and at + 1 < result.target.len:
      let coords = result.target[at + 1 .. ^1].split(',')
      if coords.len == 2:
        try:
          result.targetX = parseInt(coords[0].strip())
          result.targetY = parseInt(coords[1].strip())
          result.hasCoords = true
        except ValueError:
          result.hasCoords = false
  except CatchableError:
    result.valid = false

proc sideOffset(side: string): tuple[dx, dy: int, found: bool] =
  case side.toUpperAscii()
  of "N": (0, -1, true)
  of "S": (0, 1, true)
  of "E": (1, 0, true)
  of "W": (-1, 0, true)
  else: (0, 0, false)

proc preyKindOfTarget(target: string): PreyKind =
  ## The plan's target id starts with the thing's own name. Ore and food
  ## map onto the coalition sizes the side chooser understands.
  let head = target.split('@')[0].toLowerAscii()
  if head.startsWith("rabbit") or head.startsWith("iron") or
      head.startsWith("berries"): Rabbit
  elif head.startsWith("boar") or head.startsWith("gold") or
      head.startsWith("food"): Boar
  elif head.startsWith("stag") or head.startsWith("cog-"): Stag
  elif head.startsWith("moose"): Moose
  elif head.startsWith("elephant"): Elephant
  else: Boar

proc playFallback(
  bot: var Bot, fallback: BaselineKind, reason: string
): uint8 =
  ## Hand the tick to the scripted baseline (default big_game_hunter).
  var scripted = bot
  scripted.kind = fallback
  let mask = scripted.decideMask()
  bot = scripted
  bot.intent = reason & "; " & baselineName(fallback) & ": " & bot.intent
  mask

proc decideWithPlan(
  bot: var Bot, plan: ActivePlan, fallback: BaselineKind
): uint8 =
  ## Priority order: a capture this tick, then energy, then the plan, then
  ## the fallback baseline. A vanished target is treated as no plan: sitting
  ## idle until the next 120-tick plan wastes captures (score never goes
  ## down, so idle ticks are free points left on the table).
  bot.deriveCamera()
  if not bot.cameraKnown:
    bot.intent = "no camera"
    return 0
  let players = bot.visiblePlayers()
  bot.findSelf(players)
  if not bot.selfFound:
    bot.intent = "no self"
    return 0
  bot.updateObstacleMap()

  let killSpot = bot.findKillSpot()
  if killSpot.found:
    bot.intent = "kill spot at (" & $killSpot.x & "," & $killSpot.y & ")"
    if bot.selfTileX == killSpot.x and bot.selfTileY == killSpot.y:
      bot.updateStuckState(0)
      return 0
    return bot.navigate(killSpot.x, killSpot.y)

  if bot.restGate():
    bot.intent = "resting (energy " & $bot.energy & ")"
    bot.updateStuckState(0)
    return 0

  if not plan.valid or plan.target == "none" or not plan.hasCoords:
    return bot.playFallback(fallback, "no usable plan")

  # Is the named thing still there? The plan carries the tile it was on;
  # accept anything within one tile so a step of drift does not throw the
  # whole plan away.
  var stillThere = false
  for p in bot.visiblePrey():
    if chebyshev(p.tileX, p.tileY, plan.targetX, plan.targetY) <= 1:
      stillThere = true
      break
  if not stillThere:
    for p in players:
      if p.objectId == bot.selfObjectId:
        continue
      if chebyshev(p.tileX, p.tileY, plan.targetX, plan.targetY) <= 1:
        stillThere = true
        break
  if not stillThere:
    return bot.playFallback(fallback, "plan target gone")

  let kind = preyKindOfTarget(plan.target)
  var goalX = plan.targetX
  var goalY = plan.targetY
  let offset = sideOffset(plan.side)
  if offset.found:
    goalX = plan.targetX + offset.dx
    goalY = plan.targetY + offset.dy
  else:
    let side = bestCaptureSide(bot.selfTileX, bot.selfTileY, plan.targetX,
      plan.targetY, kind, players)
    if side.found:
      goalX = side.x
      goalY = side.y
    elif kind == Rabbit:
      # Solo capture: any cardinal side does, so walk at the thing itself
      # and let the 1-dot indicator finish the job.
      goalX = plan.targetX
      goalY = plan.targetY

  bot.intent = plan.intent & " " & plan.target & " side=" & plan.side
  if bot.selfTileX == goalX and bot.selfTileY == goalY:
    bot.updateStuckState(0)
    return 0
  bot.navigate(goalX, goalY)

## Connection

proc queryEscape(value: string): string =
  const Hex = "0123456789ABCDEF"
  for ch in value:
    if ch.isAlphaNumeric() or ch in {'-', '_', '.', '~'}:
      result.add(ch)
    else:
      let byteValue = ord(ch)
      result.add('%')
      result.add(Hex[(byteValue shr 4) and 0x0f])
      result.add(Hex[byteValue and 0x0f])

proc withPath(url, path: string): string =
  let schemePos = url.find("://")
  if schemePos < 0:
    return url
  let pathStart = url.find('/', schemePos + 3)
  if pathStart >= 0:
    return url
  url & path

proc addQueryParam(url, key, value: string): string =
  if value.len == 0:
    return url
  result = url
  if '?' in result:
    result.add('&')
  else:
    result.add('?')
  result.add(key)
  result.add('=')
  result.add(value.queryEscape())

proc connectUrl(address, url, name, token: string, port, slot: int): string =
  if url.len > 0:
    result = url.withPath(PlayerWebSocketPath)
  else:
    result = "ws://" & address & ":" & $port & PlayerWebSocketPath
  result = result.addQueryParam("name", name)
  if slot >= 0:
    result = result.addQueryParam("slot", $slot)
  if token.len > 0:
    result = result.addQueryParam("token", token)

proc playerInputBlob(mask: uint8): string =
  blobFromBytes([0x84'u8, mask and 0x7f'u8])

proc runPlayer(
  address, url, name, token: string, port, slot: int, policy: Policy
) =
  let endpoint = connectUrl(address, url, name, token, port, slot)
  var attempts = 0
  while true:
    var connected = false
    try:
      echo "seryi_volk connecting to ", endpoint,
        " policy=",
        (if policy.isPrompt: "prompt" else: baselineName(policy.baseline))
      var bot = initBot(policy.baseline, slot)
      var plan = ActivePlan()
      let ws = newWebSocket(endpoint)
      connected = true
      ws.send(registrationPacket(policy), BinaryMessage)
      var lastMask = 0xff'u8
      var idleMs = 0
      while true:
        # whisky's receiveMessage RAISES on a close frame or a truncated
        # read (only a timeout returns none); the game's quit(0) can
        # outrun the flushed frame, so catch below and exit 0.
        let first = ws.receiveMessage(ReceiveTimeoutMs)
        if first.isNone:
          idleMs += ReceiveTimeoutMs
          if idleMs >= MaxIdleReceiveMs:
            echo "seryi_volk: no frame for ",
              MaxIdleReceiveMs div 1000, " s; exiting 0"
            quit(0)
          continue
        idleMs = 0
        var applied = false
        var message = first
        var drained = 0
        while true:
          if message.isSome:
            let data = message.get.data
            if message.get.kind == BinaryMessage and data.len > 0:
              if data[0].uint8 == 0x91'u8:
                let next = parsePlanMessage(data)
                if next.valid:
                  plan = next
              elif bot.applySpritePacket(data):
                inc bot.frameTick
                applied = true
            elif message.get.kind == Ping:
              ws.send(message.get.data, Pong)
          inc drained
          if drained >= MaxDrainMessages:
            break
          message = ws.receiveMessage(0)
          if message.isNone:
            break
        if not applied:
          continue
        let mask =
          if policy.isPrompt: bot.decideWithPlan(plan, policy.baseline)
          else: bot.decideMask()
        if mask != lastMask:
          ws.send(playerInputBlob(mask), BinaryMessage)
          lastMask = mask
    except CatchableError as error:
      if connected:
        echo "seryi_volk: socket closed (", error.msg, "); exiting 0"
        quit(0)
      inc attempts
      if attempts >= MaxConnectAttempts:
        echo "seryi_volk: could not reach ", endpoint,
          " after ", attempts, " attempts; exiting 0"
        quit(0)
      sleep(ConnectRetryDelayMs)

when isMainModule:
  var
    address = "localhost"
    port = 8080
    url = getEnv("COWORLD_PLAYER_WS_URL")
    name = getEnv("PLAYER_NAME")
    token = ""
    slot = -1

  for kind, key, value in getopt():
    case kind
    of cmdLongOption:
      case key
      of "address": address = value
      of "port": port = parseInt(value)
      of "url": url = value
      of "name": name = value
      of "token": token = value
      of "slot": slot = parseInt(value)
      else: discard
    else: discard

  let policy = resolvePolicy()
  if name.len == 0:
    name =
      if policy.isPrompt: "seryi_volk"
      else: baselineName(policy.baseline)
  runPlayer(address, url, name, token, port, slot, policy)
