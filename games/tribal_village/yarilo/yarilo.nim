## Yarilo — Tribal Village policy for Andre von Auto.
##
## Tribal Village observations carry no world state (only slot, tick, and
## the episode seed), so the only informed play is the bundled villager
## pattern: rebuild the episode in a deterministic local mirror seeded by
## the first observation and replay the game's own role-based scripted AI
## (src/ai.nim, vendored from coworld-tribal-village @ 7a5f6a21) for this
## slot. Every slot runs the same mirror, so all mirrors stay in lockstep
## with the server as long as everyone plays the built-in AI.
##
## Run against a local server:
##   COWORLD_PLAYER_WS_URL='ws://127.0.0.1:8080/player?slot=0&token=...' \
##   nim r games/tribal_village/yarilo/yarilo.nim

import std/[json, options, os]
import whisky
import src/[ai, environment]

const
  InitialConnectWindowMs = 60_000
  ReconnectWindowMs = 8_000
  ReconnectAttemptMs = 1_000

type
  Mirror = ref object
    env: Environment
    controller: Controller
    lastTick: int
    lastAction: int

proc newMirror(firstMessage: JsonNode): Mirror =
  ## Builds the deterministic episode mirror the same way the game server
  ## builds its environment: custom config, reset, then a fresh controller.
  let
    gameConfig = firstMessage{"game_config"}
    seed =
      if gameConfig != nil: gameConfig{"seed"}.getInt(1)
      else: 1
    teamCount =
      if gameConfig != nil: gameConfig{"team_count"}.getInt(MaxTeamCount)
      else: MaxTeamCount
    maxSteps = firstMessage{"max_steps"}.getInt(0)
  var config = defaultEnvironmentConfig()
  if maxSteps > 0:
    config.maxSteps = maxSteps
  if seed > 0:
    config.seed = seed
  config.teamCount = teamCount
  result = Mirror(
    env: newEnvironment(config),
    controller: newController(if seed > 0: seed else: 1),
    lastTick: -1
  )
  result.env.reset()

proc builtinActions(mirror: Mirror): array[MapAgents, uint8] =
  ## Computes actions for the active teams inside the fixed 48-agent ABI.
  for agentId in 0 ..< mirror.env.agents.len:
    result[agentId] = mirror.controller.decideAction(mirror.env, agentId)
  mirror.controller.updateController()

proc chooseAction(mirror: Mirror, slot, tick: int): int =
  ## Catches the mirror up to the server tick and picks this slot's action.
  ## The server re-sends the current tick on every (re)connect, so duplicate
  ## observations must not advance the mirror.
  if tick <= mirror.lastTick:
    return mirror.lastAction
  while mirror.env.currentStep < tick:
    var actions = mirror.builtinActions()
    mirror.env.step(addr actions)
  var actions = mirror.builtinActions()
  result =
    if slot >= 0 and slot < MapAgents: actions[slot].int
    else: 0
  mirror.env.step(addr actions)
  mirror.lastTick = tick
  mirror.lastAction = result

proc playEpisode(
  url: string,
  mirror: var Mirror,
  connected: var bool
): bool =
  ## Runs the message loop on one connection. Returns true when the episode
  ## reports it is done.
  let ws = newWebSocket(url)
  echo "yarilo: connected"
  connected = true
  while true:
    let received = ws.receiveMessage()
    if received.isNone:
      continue
    let message = received.get
    if message.kind == Ping:
      ws.send(message.data, Pong)
      continue
    if message.kind != TextMessage:
      continue
    let node = parseJson(message.data)
    if node{"done"}.getBool(false) or node{"type"}.getStr() == "final":
      return true
    if node{"type"}.getStr() != "observation":
      continue
    if mirror == nil:
      mirror = newMirror(node)
    let action = mirror.chooseAction(
      node{"slot"}.getInt(0),
      node{"tick"}.getInt(0)
    )
    ws.send( $ %*{"type": "action", "action": action})

proc runPlayer() =
  ## Connects with retry windows: tournament player containers can start
  ## before the game server accepts connections.
  let url = getEnv("COWORLD_PLAYER_WS_URL")
  if url.len == 0:
    quit("yarilo: COWORLD_PLAYER_WS_URL is required", 1)
  var
    mirror: Mirror = nil
    everConnected = false
    waitedMs = 0
  while true:
    var connectedThisAttempt = false
    try:
      if playEpisode(url, mirror, connectedThisAttempt):
        echo "yarilo: episode finished"
        return
    except CatchableError as e:
      echo "yarilo: connection error: ", e.msg
    if connectedThisAttempt:
      everConnected = true
      waitedMs = 0
    let windowMs =
      if everConnected: ReconnectWindowMs
      else: InitialConnectWindowMs
    if waitedMs >= windowMs:
      quit("yarilo: cannot connect after " & $(windowMs div 1000) &
        "s; exiting", 1)
    sleep(ReconnectAttemptMs)
    waitedMs += ReconnectAttemptMs

when isMainModule:
  runPlayer()
