## Gruzchik — Sokoban policy for Andre von Auto.
## The sokoban player container is deliberately thin: it connects, sends
## one Sprite v1 chat packet (0x81 + u16 little-endian length + payload)
## carrying its registration blob, and thereafter only listens; the game
## server makes every per-turn decision by sending the prompt plus the
## board view to Claude (docs/actions.md). Unlike the other cogames this
## registration blob has NO "type" field, and the server pushes JSON text
## frames (welcome, turn, done) that need no reply.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (pusher | nudger)
## Upload note: no USE_BEDROCK needed — the anthropic_api_key coworld
## secret is injected into the GAME pod, which makes every decision.

import std/[json, options, os, times], whisky

const defaultPrompt = """
You are Gruzchik, a warehouse porter solving a ladder of six 10x10
Sokoban levels. Pushes are irreversible: you can never pull. One wrong
push kills the level, so THINK FIRST, THEN PUSH.

Reply with one JSON object only: {"actions":[...], "say":"...",
"notes":"..."}. Actions (max 8; 20 moves execute per turn):
{"do":"push","box":B,"dir":"U|D|L|R","times":N} walks to the approach
square and pushes box B N times; {"do":"goto","x":X,"y":Y};
{"do":"moves","seq":"UDLR"}; {"do":"wait"}. Prefer push: it validates
the walk. A push reported unreachable means the approach square is
blocked — often by another box, a sign your ORDER is wrong.

Method, every level:
1. Before the first push, solve the whole level in your head. Assign
   each box a target and a push path, then find an ORDER such that no
   parked box ever blocks a later box's push path or approach square.
   Write the full plan in notes (e.g. "b2->(7,3) push R,R,U; then
   b0->(3,3) ...") and follow it, re-verifying every turn.
2. Never push a box onto a square listed in dead_squares unless that
   square is a target. Check EVERY planned landing square against
   dead_squares before sending the push.
3. Freeze check: never let an off-target box complete a 2x2 block of
   walls and boxes, and never park two boxes side by side against a
   wall run that has no targets on it. After each planned push, picture
   the new board before committing.
4. Pushing a box along a wall is only safe if a target lies on that
   wall run — otherwise it can never leave the wall.
5. The border ring is wall, so rows and columns 1 and 8 are the danger
   lanes and the four inner corners are death.
6. opt_pushes is the exact optimum. If your plan needs far more pushes
   than opt_pushes, your box-to-target matching is wrong; rethink
   before pushing, not after.
7. pushes_available is the legal move list; cross its "to" square
   against dead_squares yourself — the game will not warn you.

Budget: 200 moves and 10 turns per level. One careful turn of two or
three verified pushes beats twenty blind moves, but an empty reply
still burns 20 moves, so always send the next verified chunk. Scoring:
solved levels (tier-weighted) dominate everything; then the maximum
boxes ever on targets; then moves saved. If the level is truly dead,
park every box you still safely can on targets, then wait it out — but
never create a deadlock to park one more box while a solve is still
possible.
"""

const
  SpriteClientChat = 0x81'u8
  ConnectAttempts = 240      ## 240 x 500 ms = 2 minutes of dialling.
  ConnectRetryMs = 500
  ReRegisterSeconds = 10.0

proc chatPacket(payload: string): string =
  ## One Sprite v1 chat packet: 0x81, u16 little-endian length, raw bytes.
  result = newStringOfCap(payload.len + 3)
  result.add(char(SpriteClientChat))
  result.add(char(payload.len and 0xff))
  result.add(char((payload.len shr 8) and 0xff))
  result.add(payload)

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "")
    url = getEnv("COWORLD_PLAYER_WS_URL", getEnv("COGAMES_ENGINE_WS_URL"))
  if url == "":
    quit("gruzchik: COWORLD_PLAYER_WS_URL is not set", 1)
  let register = %*{
    "policy": "Gruzchik",
    "prompt": if scripted == "": prompt else: "",
    "scripted": if scripted == "": newJNull() else: %scripted}

  var socket: WebSocket = nil
  for attempt in 0 ..< ConnectAttempts:
    try:
      socket = newWebSocket(url)
      break
    except CatchableError:
      if attempt == 0:
        echo "gruzchik: game not listening yet, retrying"
      sleep(ConnectRetryMs)
  if socket == nil:
    quit("gruzchik: game never accepted a connection", 1)
  echo "gruzchik: connected"

  # Registration is RE-SENT for the first ~10 s of received frames: a first
  # send can race the server's slot bookkeeping and the seat then silently
  # plays the pusher baseline for the whole episode. Exit 0 on a dead
  # socket — the game's own exit can outrun its final flushed frame.
  socket.send(chatPacket($register), BinaryMessage)
  let started = epochTime()
  while true:
    var received: Option[Message]
    try:
      received = socket.receiveMessage()
    except CatchableError:
      echo "gruzchik: socket closed (", getCurrentExceptionMsg(), ")"
      break
    if received.isNone:
      continue                        ## a read timeout, not a closed socket
    let message = received.get()
    if message.kind == Ping:
      socket.send(message.data, Pong)
      continue
    if epochTime() - started < ReRegisterSeconds:
      socket.send(chatPacket($register), BinaryMessage)
    if message.kind != TextMessage:
      continue
    var payload: JsonNode
    try:
      payload = parseJson(message.data)
    except CatchableError:
      continue
    if payload{"done"}.getBool():
      echo "gruzchik: final score ", payload{"result"}{"scores"}
      break
    if payload{"type"}.getStr() == "welcome":
      echo "gruzchik: seated at slot ", payload{"slot"}.getInt(),
        " as ", payload{"alias"}.getStr()
      socket.send(chatPacket($register), BinaryMessage)
  quit(0)

main()
