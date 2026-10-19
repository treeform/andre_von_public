## Usynya — Tribal Fortress policy for Andre von Auto.
## Nim rewrite of the Universal Tribal Player
## (tribal_fortress_env/coworld/player.py): one command player that detects
## which of the two shared-world surfaces it was seated on and plays it.
##
## Quest (`quest-N-adventurer`): the server streams binary sprite frames;
## we answer each with a two-byte 0x84 button-mask packet running the
## example's deterministic explore dance (phase walk + periodic select/A).
##
## Fortress (`fortress-N-town`): the /player bot socket sends compact JSON
## observations that carry NO `visible_buildings`, so the Python example's
## overseer branch never actually fires there. We go one better: after
## detecting fortress mode we reconnect with the documented `render=1`
## opt-in, read `visible_buildings` from view.init/view.delta, and keep
## every military building on program 3 (fighter_aggressive) and every
## other policy building on program 0 (gatherer_default) — the example's
## intended behavior, actually executed. Set USYNYA_RENDER=0 to stay on
## the passive bot socket instead (exact example behavior).
##
## Wire protocol: docs/protocol_player.md (player_protocol_spec.md at the
## pinned tribal_fortress revision) plus tribal_fortress_env/coworld/
## server.py and player.py at f0e3202.

import std/[json, options, os, sets, tables], whisky

const militaryBuildings = toHashSet([
  "barracks", "archery_range", "stable", "siege_workshop",
  "mangonel_workshop", "trebuchet_workshop", "monastery", "castle",
])

const
  aggressiveProgram = 3 ## fighter_aggressive
  gathererProgram = 0   ## gatherer_default

proc playerUrl(render: bool): string =
  result = getEnv("COWORLD_PLAYER_WS_URL")
  if result == "":
    quit("usynya: COWORLD_PLAYER_WS_URL is not set", 1)
  if render:
    result.add(if '?' in result: "&render=1" else: "?render=1")

proc connectWithRetry(url: string, attempts: int): WebSocket =
  ## The runner may hand us the URL before the game socket accepts, and
  ## the fortress render reconnect can race the server's cleanup of our
  ## first socket, so retry for a while before giving up.
  for attempt in 0 ..< attempts:
    try:
      return newWebSocket(url)
    except CatchableError:
      sleep(250)
  nil

proc receiveFrame(ws: WebSocket): Option[Message] =
  ## One application frame: answers pings, skips pongs, none on close.
  while true:
    var received: Option[Message]
    try:
      received = ws.receiveMessage()
    except CatchableError:
      echo "usynya: websocket closed (", getCurrentExceptionMsg(), ")"
      return none(Message)
    if received.isNone:
      continue
    let message = received.get()
    case message.kind
    of Ping:
      ws.send(message.data, Pong)
    of Pong:
      discard
    else:
      return some(message)

proc parseFrame(data: string): JsonNode =
  try:
    parseJson(data)
  except CatchableError:
    nil

## Quest adventurer

proc adventurerMask(tick: int): int =
  ## The example's deterministic legal dance: 12-tick movement phases
  ## (right, right, down, left, left, up) with periodic select and A.
  const phases = [8, 8, 2, 4, 4, 1]
  result = phases[(tick div 12) mod 6]
  if tick mod 9 == 0:
    result = result or 32
  if tick mod 37 == 0:
    result = result or 64

proc runQuest(ws: WebSocket) =
  echo "usynya: quest surface detected, running adventurer dance"
  var tick = 0
  proc answer() =
    ws.send(char(0x84) & char(adventurerMask(tick)), BinaryMessage)
    inc tick
  answer() # the sprite frame that identified the surface
  while true:
    let frame = receiveFrame(ws)
    if frame.isNone:
      quit(0)
    let message = frame.get()
    if message.kind == BinaryMessage:
      answer()
      continue
    let parsed = parseFrame(message.data)
    if parsed != nil and parsed{"type"}.getStr() == "final":
      echo "usynya: final, scores ", parsed{"scores"}
      quit(0)

## Fortress town controller

type VisibleBuilding = object
  x, y: int
  thing: string
  programId: int

proc desiredProgram(building: VisibleBuilding): int =
  if building.thing in militaryBuildings: aggressiveProgram
  else: gathererProgram

proc buildingKey(x, y: int): string =
  $x & ":" & $y

proc mergeBuilding(buildings: var Table[string, VisibleBuilding],
                   node: JsonNode) =
  if node == nil or node.kind != JObject:
    return
  var building = VisibleBuilding(
    x: node{"x"}.getInt(-1),
    y: node{"y"}.getInt(-1),
    thing: node{"thing"}.getStr(),
    programId: -1)
  if building.x < 0 or building.y < 0 or building.thing == "":
    return
  let program = node{"program"}
  if program != nil and program.kind == JObject:
    building.programId = program{"id"}.getInt(-1)
  buildings[buildingKey(building.x, building.y)] = building

proc runFortress(ws: WebSocket) =
  ## Render-socket overseer: track visible policy buildings and keep each
  ## one on its desired program, one command in flight at a time.
  echo "usynya: fortress surface, render socket up"
  var
    buildings: Table[string, VisibleBuilding]
    blocked: HashSet[string]
    pending = ""
  proc maybeCommand() =
    if pending != "":
      return
    for key, building in buildings:
      if key in blocked:
        continue
      if building.programId == building.desiredProgram():
        continue
      pending = key
      ws.send($ %*{"type": "town.set_program", "x": building.x,
                   "y": building.y, "program_id": building.desiredProgram()})
      return
  while true:
    let frame = receiveFrame(ws)
    if frame.isNone:
      quit(0)
    let message = frame.get()
    if message.kind != TextMessage:
      continue # raw i16le-binary-next cell frame after view.init
    let parsed = parseFrame(message.data)
    if parsed == nil:
      continue
    case parsed{"type"}.getStr()
    of "view.init":
      buildings.clear()
      for node in parsed{"visible_buildings"}.getElems():
        buildings.mergeBuilding(node)
      maybeCommand()
    of "view.delta":
      for node in parsed{"visible_building_updates"}.getElems():
        buildings.mergeBuilding(node)
      maybeCommand()
    of "ack":
      if parsed{"command"}.getStr() == "town.set_program":
        let key = buildingKey(parsed{"x"}.getInt(-1), parsed{"y"}.getInt(-1))
        if key in buildings:
          buildings[key].programId = parsed{"program"}{"id"}.getInt(-1)
      pending = ""
      maybeCommand()
    of "error":
      echo "usynya: server error: ", parsed{"error"}.getStr(
        parsed{"message"}.getStr())
      if pending != "":
        blocked.incl(pending)
        pending = ""
      maybeCommand()
    of "final":
      echo "usynya: final, team_score ", parsed{"team_score"}
      quit(0)
    else:
      discard

proc runFortressPassive(ws: WebSocket) =
  ## Exact example behavior on a bot socket: the compact observations
  ## carry no visible_buildings, so there is nothing legal to command;
  ## sit tight while the town's default policies play, then exit clean.
  echo "usynya: fortress surface, passive bot socket"
  while true:
    let frame = receiveFrame(ws)
    if frame.isNone:
      quit(0)
    let message = frame.get()
    if message.kind != TextMessage:
      continue
    let parsed = parseFrame(message.data)
    if parsed != nil and parsed{"type"}.getStr() == "final":
      echo "usynya: final, team_score ", parsed{"team_score"}
      quit(0)

proc main() =
  let url = playerUrl(render = false)
  echo "usynya: connecting to player socket"
  var ws = connectWithRetry(url, attempts = 40)
  if ws == nil:
    quit("usynya: could not connect", 1)
  ## The first application frame identifies the surface: binary sprite
  ## frame means quest, JSON observation means fortress.
  while true:
    let frame = receiveFrame(ws)
    if frame.isNone:
      quit("usynya: socket closed before the surface was identified", 1)
    let message = frame.get()
    if message.kind == BinaryMessage:
      runQuest(ws)
      return
    let parsed = parseFrame(message.data)
    if parsed == nil:
      continue
    case parsed{"type"}.getStr()
    of "observation":
      if getEnv("USYNYA_RENDER", "1") == "0":
        runFortressPassive(ws)
        return
      ws.close()
      let renderSocket = connectWithRetry(playerUrl(render = true),
        attempts = 40)
      if renderSocket == nil:
        ## Render reconnect lost the race for our slot; fall back to the
        ## passive bot socket rather than forfeiting the seat.
        ws = connectWithRetry(url, attempts = 40)
        if ws == nil:
          quit("usynya: could not reconnect", 1)
        runFortressPassive(ws)
        return
      runFortress(renderSocket)
      return
    of "final":
      echo "usynya: final before any step, scores ", parsed{"scores"}
      quit(0)
    else:
      discard

main()
