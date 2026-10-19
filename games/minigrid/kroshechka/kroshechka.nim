## Kroshechka — Minigrid policy for Andre von Auto.
## The minigrid player container is deliberately thin: it connects, sends
## one Sprite v1 chat packet carrying its registration (operator prompt or
## scripted baseline), and thereafter only acknowledges frames; the game
## server makes every per-turn decision by sending the prompt plus the
## lane's view to Claude (docs/protocol_player.md). Register is 0x81 +
## u16 little-endian length + payload; a Ready byte (0x85) after each
## received frame lets fastMode pace the episode.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (scout | bumper)
## Upload note: no USE_BEDROCK needed — the anthropic_api_key coworld
## secret is injected into the GAME pod, which makes every decision.

import std/[json, options, os, times], whisky

const defaultPrompt = """
You are Kroshechka, a tiny heroine racing a five-task gauntlet alone in a
13x13 grid you see 7x7 of. Score = tasks solved, then subgoal progress,
then speed: always act, never idle.

Reply with one JSON object only: {"actions":[...], "say":"...",
"notes":"..."}. Up to 24 actions from: left right forward pickup drop
toggle wait, {"do":"goto","x":X,"y":Y}, {"do":"face","dir":"N|E|S|W"}.
goto walks a BFS path through KNOWN safe cells only and is best-effort:
aimed at an unseen cell it walks you toward it and faces it — that is how
you explore. Chain macros: goto key, pickup, goto door, toggle, goto goal
in ONE turn whenever the map allows.

Core loop each turn:
1. If the mission target is in `known`, goto it and append the finishing
   actions.
2. Else explore: goto the far side of the nearest '?' region; repeat.
3. Keep notes current: object positions with colors, door states, rules
   learned, next step. Notes are your only memory.

Family playbook:
- lavagap: a lava column with one gap. Find the gap in `known`, goto the
  gap cell, cross east, goto the green goal. goto never paths through
  lava; never send a raw forward toward '~'.
- doorkey: goto the yellow key, pickup, goto the locked yellow door,
  toggle (the key is kept), goto the goal.
- multiroom: rooms chain 0->1->2->3 through closed doors on the x=6 and
  y=6 walls. goto each door, toggle, pass, repeat, then the goal.
- keycorridor: find the red key in a side room, pickup, toggle the locked
  red door open, then DROP the key on empty floor and pickup the blue
  ball — you can carry only one thing.
- dynamic: grey balls wander but NEVER step onto you; only your own
  forward can kill you. Move in short gotos; if a grey ball sits ahead,
  wait or step around. Remembered ball positions go stale — trust only
  this turn's view.
- babyai: read the mission verb. "go to X": goto it. "pick up X": goto
  it, pickup. "put X next to Y": pickup X, goto a cell 4-adjacent to Y,
  face an empty floor cell touching Y, drop.
- xland: the rule table is hidden. Learn it: pick up an object, drop it
  4-adjacent to another, read `productions` next turn, and write every
  fired rule in notes as A+B->P. Chain: make P0 and P1, then put them
  together for the goal product. Six turns cover three rules only if
  EVERY turn tests a new pair — never waste one.

Discipline: invalid actions are dropped, never fixed — copy coordinates
from `objects` and `known` exactly; x,y are 0..12. pickup needs empty
hands and the object directly ahead; toggle and drop also act on the cell
ahead — end with face if unsure. Never forward into lava or a known
obstacle: that ends the task. Subgoals pay even when you cannot finish,
so on a hopeless task still chase the nearest subgoal, and finish fast —
every turn saved on a solved task pays speed points.
"""

const
  SpriteClientChat = 0x81'u8
  SpriteClientReady = 0x85'u8
  ConnectAttempts = 240      ## 240 x 500 ms = 2 minutes of dialling.
  ConnectRetryMs = 500
  ReRegisterSeconds = 10.0
  ReconnectAttempts = 6

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
    quit("kroshechka: COWORLD_PLAYER_WS_URL is not set", 1)
  let register = %*{
    "type": "register",
    "prompt": if scripted == "": prompt else: "",
    "scripted": if scripted == "": newJNull() else: %scripted,
    "policy": "Kroshechka"}

  proc dial(attempts: int): WebSocket =
    ## The runner starts the game and the players at the same instant, so
    ## the first dial usually lands on a closed port; keep dialling.
    for attempt in 0 ..< attempts:
      try:
        return newWebSocket(url)
      except CatchableError:
        if attempt == 0:
          echo "kroshechka: game not listening yet, retrying"
        sleep(ConnectRetryMs)
    nil

  var socket = dial(ConnectAttempts)
  if socket == nil:
    quit("kroshechka: game never accepted a connection", 1)
  echo "kroshechka: connected"

  # Registration is RE-SENT for the first ~10 s of received frames: a first
  # send can race the server's slot bookkeeping and the seat then silently
  # plays the scripted baseline for the whole episode. Exit 0 on a dead
  # socket — the game's own exit can outrun its final flushed frame.
  var reconnects = 0
  while true:
    var sessionFrames = 0
    try:
      socket.send(chatPacket($register), BinaryMessage)
      let started = epochTime()
      while true:
        let received = socket.receiveMessage()
        if received.isNone:
          continue                    ## a read timeout, not a closed socket
        let message = received.get()
        if message.kind == Ping:
          socket.send(message.data, Pong)
          continue
        inc sessionFrames
        if epochTime() - started < ReRegisterSeconds:
          socket.send(chatPacket($register), BinaryMessage)
        # Acknowledge every frame so fastMode can pace by readiness.
        socket.send($char(SpriteClientReady), BinaryMessage)
    except CatchableError:
      echo "kroshechka: socket closed (", getCurrentExceptionMsg(), ")"
    # A session with no frames means the game is winding down; otherwise a
    # dropped socket mid-episode is worth re-dialling and re-registering.
    if sessionFrames == 0 or reconnects >= ReconnectAttempts:
      break
    inc reconnects
    echo "kroshechka: re-dialling the seat (attempt ", reconnects, ")"
    socket = dial(ReconnectAttempts)
    if socket == nil:
      break
  quit(0)

main()
