## Ivan Da Marya — Nethack policy for Andre von Auto.
## The nethack player container is deliberately thin: it connects, sends
## one Sprite v1 chat packet carrying its registration (operator prompt or
## scripted baseline), and thereafter only acknowledges frames; the game
## server makes every per-turn decision (docs/protocol_player.md). Register
## is 0x81 + u16 little-endian length + payload; a Ready byte (0x85) after
## each received frame is acknowledged and ignored by this game's server.
##
## Default is the published `delver` baseline, not the LLM prompt: the
## server sets isLlm from prompt.len > 0 (src/nethack/server.nim), so a
## non-empty prompt would ignore the baseline. We are #5/5 (rating 824.3).
## Score is 100000*(deepest-1) plus tiny gold/xp/deed tie-breaks; delver
## is the sweep-tuned crawler (eat-if-weak, dive known `>` immediately,
## never melee the floating eye, travel then walk into the dark). LLM
## seats also pay turnSpacingMs=2600 and fall back to this same delver
## on timeout/parse/budget_guard.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED play a scripted baseline (delver | bumbler).
##                   Defaults to delver. Empty string forces the prompt.
## Upload note: default is scripted, so no Bedrock flag is required. The
## anthropic_api_key coworld secret is injected into the GAME pod.

import std/[json, options, os, strutils, times], whisky

const defaultPrompt = """
You are Ivan da Marya, a one-life dungeon delver. Score is
overwhelmingly DEPTH: find the down staircase > on every level and take
it. Gold, fights and loot are only worth doing on the way to >.

Reply with one JSON object only: {"actions":[...], "say":"...",
"notes":"..."}. Up to 10 actions:
{"do":"move","dir":"n|s|e|w|ne|nw|se|sw"}, {"do":"travel","x":X,"y":Y},
down, up, pickup, {"do":"eat","item":"b"}, quaff, wield, wear,
{"do":"kick","dir":"n"}, search, {"do":"chat","dir":"e"}, wait. travel
walks only through cells you have SEEN; to explore, travel to the
frontier of the known map, then 4-6 moves in one heading into the dark.
Moving into a monster attacks it; moving into a closed door opens it.

Every turn: 1) if > is on the remembered map, travel to it and go down;
2) else explore the nearest unexplored exit — doorways, corridor
mouths, dark room edges — one region at a time; 3) log in notes: depth,
positions of < and >, unexplored exits, food left, gold. Notes are your
only memory.

Combat doctrine:
- Fight only what blocks the path or is already adjacent; never chase
  xp.
- NEVER melee the floating eye e — hit or miss, it paralyses you for 12
  ticks. Walk around it; it never moves.
- Jackals d hunt in packs: back into a corridor or doorway so only one
  can reach you, then fight.
- If hp is below a third: retreat toward explored ground, quaff a
  potion if you carry one, or put a corridor between you and the pack.
  hp regenerates 1 per 12 ticks while hunger is better than Weak — a
  few searches in a safe corner is a cheap heal, but the clock is 2200
  ticks, so rest only when hurt.
- Depth 4+ monsters (orcs, dwarves, mummies) hit hard: by then wield
  the best weapon found (long sword > mace > short sword > dagger) and
  wear the best armour (plate > ring mail > leather). pickup every )
  and [ you cross and wield/wear upgrades immediately.

Hunger: nutrition drops 1 per tick. Eat ration b the turn the status
line says Hungry — Weak costs to-hit, regeneration and kicking. pickup
every food % you pass; you need at least one food beyond the starting
ration to use the whole clock. Starvation is a real death.

Hazards: lava } is instant death — never move or travel onto it. A +
that will not open is locked: kick it (never while Weak). Unknown
potions are a gamble (healing, confusion or sleep) — quaff only when
dying anyway or completely safe. A discovered trap ^ never fires again.

Dead ends: if a level seems to have no >, hunt secret doors — stand at
suspicious dead-end corridors or blank wall runs and search 3 times
(the third search next to a hidden thing always finds it). With 50+
gold and the Oracle O adjacent, chat toward it: it names the compass
octant of >. Grab $ piles you pass — 500 carried earns the hoard deed.

Never take < up on level 1: that ends the run. Go down, go down, go
down.
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
    scripted = getEnv("PLAYER_SCRIPTED", "delver").strip()
    ## Server: isLlm = prompt.len > 0, even when scripted is named. Empty
    ## the prompt whenever a baseline is set so the seat actually plays it.
    prompt =
      if scripted.len > 0: ""
      else: getEnv("PLAYER_PROMPT", defaultPrompt)
    url = getEnv("COWORLD_PLAYER_WS_URL", getEnv("COGAMES_ENGINE_WS_URL"))
  if url == "":
    quit("ivan_da_marya: COWORLD_PLAYER_WS_URL is not set", 1)
  let register = %*{
    "type": "register",
    "prompt": prompt,
    "scripted": if scripted.len > 0: %scripted else: newJNull(),
    "policy": "Ivan Da Marya"}
  echo "ivan_da_marya: kind=", (if scripted.len > 0: "scripted" else: "llm"),
    " baseline=", (if scripted.len > 0: scripted else: "none")

  proc dial(attempts: int): WebSocket =
    ## The runner starts the game and the players at the same instant, so
    ## the first dial usually lands on a closed port; keep dialling.
    for attempt in 0 ..< attempts:
      try:
        return newWebSocket(url)
      except CatchableError:
        if attempt == 0:
          echo "ivan_da_marya: game not listening yet, retrying"
        sleep(ConnectRetryMs)
    nil

  var socket = dial(ConnectAttempts)
  if socket == nil:
    quit("ivan_da_marya: game never accepted a connection", 1)
  echo "ivan_da_marya: connected"

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
      echo "ivan_da_marya: socket closed (", getCurrentExceptionMsg(), ")"
    # A session with no frames means the game is winding down; otherwise a
    # dropped socket mid-episode is worth re-dialling and re-registering.
    if sessionFrames == 0 or reconnects >= ReconnectAttempts:
      break
    inc reconnects
    echo "ivan_da_marya: re-dialling the seat (attempt ", reconnects, ")"
    socket = dial(ReconnectAttempts)
    if socket == nil:
      break
  quit(0)

main()
