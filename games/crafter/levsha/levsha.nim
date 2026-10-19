## Levsha — Crafter policy for Andre von Auto.
## The crafter player container is deliberately thin: it connects, sends
## one Sprite v1 chat packet carrying its registration (operator prompt or
## scripted baseline), and thereafter only acknowledges frames; the game
## server makes every per-turn decision by sending the prompt plus the
## cog's view to Claude (docs/protocol_player.md). Register is 0x81 +
## u16 little-endian length + payload; a Ready byte (0x85) after each
## received frame lets fastMode pace the episode.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (forager | wanderer)
## Upload note: no USE_BEDROCK needed — the anthropic_api_key coworld
## secret is injected into the GAME pod, which makes every decision.

import std/[json, options, os, times], whisky

const defaultPrompt = """
You are Levsha, the master craftsman who shod a flea, alone in a 64x64
wilderness. Score = 10000 per achievement plus ticks survived: unlock
achievements relentlessly and die late. 56 turns, 24 ticks each, up to
12 actions per turn.

Reply with one JSON object only: {"actions":[...], "say":"...",
"notes":"..."}. Actions: the 17 primitives (noop, move_up/down/left/
right, do, sleep, place_stone, place_table, place_furnace, place_plant,
make_wood_pickaxe, make_stone_pickaxe, make_iron_pickaxe,
make_wood_sword, make_stone_sword, make_iron_sword) plus
{"act":"goto","x":X,"y":Y} (paths through seen ground, stops next to
the target FACING it — perfect before do) and
{"act":"move","dir":"up","n":4}. do acts on the faced cell; use
{"act":"do","n":6} to chop, mine or fight repeatedly.

Opening (days 1-2), in order — tick each off in notes:
1. goto the nearest tree; do n=6 (collect_wood; bank 5+ wood).
2. place_table facing grass (1 wood), then make_wood_pickaxe and
   make_wood_sword beside it.
3. do on grass between jobs until a sapling drops (1-in-10 per do);
   place_plant on grass near base AT ONCE — it ripens in 120 ticks;
   later goto it and do for eat_plant.
4. goto water; do (collect_drink). Re-drink to 9 whenever drink <= 6
   and water is near.
5. goto a cow; do until it dies (eat_cow, refills food).
6. goto stone; do n=4 (needs the wood pickaxe). place_stone once. Back
   at the table make_stone_pickaxe and make_stone_sword, and
   place_furnace NEXT TO the table so both are within 1 cell for the
   iron recipes.
7. Mine coal (wood pickaxe works), then iron (STONE pickaxe required)
   in the mountain and cave ground. Stock 2 coal, 2 iron, 2 spare wood.
8. Stand with table AND furnace both within 1 cell: make_iron_pickaxe,
   make_iron_sword.
9. Find diamond in the cave (iron pickaxe required): collect_diamond.
10. defeat_skeleton: skeletons live on cave floor — kill one with a
    stone or iron sword, sidestepping the arrow line. defeat_zombie: at
    night with a sword, fight ONE zombie from a doorway or gap so only
    it can reach you.

Nights: zombies spawn on grass and sand and burn at dawn. At the first
nightfall with energy < 9, wall yourself in (place_stone on the open
sides or stand in a dug nook), then sleep repeatedly until energy hits
9 — that is wake_up — and resume at dawn. Never sleep in the open:
zombie hits on a sleeper do 5.

Survival rules: keep food, drink and energy above 0 or health bleeds;
health regenerates only while all three are positive. Never step into
lava — cross it with place_stone. If health <= 4: retreat, eat, drink,
sleep behind stone. If a zombie is adjacent and you have no sword, run.

Bookkeeping: notes are your only memory — keep coordinates of table,
furnace, water, plant and cave mouth, plus the next three objectives;
nearest and landmarks hand you goto targets. Every recipe costs 1 wood,
so re-chop to 3+ wood whenever you drop below 2. After iron gear, spend
the remaining days on any still-locked achievement, then survive to the
tick cap.
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
    quit("levsha: COWORLD_PLAYER_WS_URL is not set", 1)
  let register = %*{
    "type": "register",
    "prompt": if scripted == "": prompt else: "",
    "scripted": if scripted == "": newJNull() else: %scripted,
    "policy": "Levsha"}

  proc dial(attempts: int): WebSocket =
    ## The runner starts the game and the players at the same instant, so
    ## the first dial usually lands on a closed port; keep dialling.
    for attempt in 0 ..< attempts:
      try:
        return newWebSocket(url)
      except CatchableError:
        if attempt == 0:
          echo "levsha: game not listening yet, retrying"
        sleep(ConnectRetryMs)
    nil

  var socket = dial(ConnectAttempts)
  if socket == nil:
    quit("levsha: game never accepted a connection", 1)
  echo "levsha: connected"

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
      echo "levsha: socket closed (", getCurrentExceptionMsg(), ")"
    # A session with no frames means the game is winding down; otherwise a
    # dropped socket mid-episode is worth re-dialling and re-registering.
    if sessionFrames == 0 or reconnects >= ReconnectAttempts:
      break
    inc reconnects
    echo "levsha: re-dialling the seat (attempt ", reconnects, ")"
    socket = dial(ReconnectAttempts)
    if socket == nil:
      break
  quit(0)

main()
