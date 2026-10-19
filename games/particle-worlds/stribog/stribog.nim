## Stribog — Particle Worlds policy for Andre von Auto.
## The particle-worlds seat is a Sprite v1 client and deliberately thin:
## it dials COWORLD_PLAYER_WS_URL, sends ONE Sprite v1 chat frame (0x81)
## carrying its registration {"type":"register","prompt","scripted",
## "policy"}, re-sends it over the first ~10 s of frames (joins are
## slot-sequential and the lobby sends frames before a seat is admitted),
## answers every received frame with the Ready packet (0x85), and sends
## nothing else; the decision layer runs in the game server. The prompt
## IS the strategy. Ported from coworld-ctf's paintball_player pattern.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (drifter | beeline)
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays scripted.

import std/[json, options, os, strutils], whisky

const
  ConnectAttempts = 240      ## 240 x 500 ms = 2 minutes of dialling.
  ConnectRetryMs = 500
  RegistrationResends = 10   ## re-sends after the first, ~1 s apart.
  ResendEveryFrames = 24     ## ~1 s of frames at 24 Hz.
  ReconnectAttempts = 6

const defaultPrompt = """
You are Stribog, god of winds. Act on turn 1 of every round; a particle
in transit scores nothing, so commit early and hold. Colour rank order
for every tie-break: RED, BLUE, GREEN, YELLOW.
SPREAD: turn 1, cover the mark whose index equals your ROLE index and say
the letter at that index (A for 0 .. D for 3). If beliefs later show
another particle settled on your mark while some mark is uncovered, the
later colour rank moves to the nearest uncovered mark; the earlier stays.
Keep 40 px clear of everyone; never trade marks twice.
DECEIVE as a good agent: role 1 covers the GOAL but arrives on a bend
past a wrong mark; roles 2 and 3 cover the two marks furthest from the
goal and sit dead still - a settled decoy is the bait. Total silence all
round. As the ADVERSARY: symbols are noise; trust stillness. Turn 1
cover the mark nearest the good agents' centroid; every turn after,
cover the mark a good agent has been settled on longest (beliefs
settled_ticks); if two decoys sit far marks and one agent keeps
adjusting, follow the adjuster.
CRYPTO as speaker: hold and say the key symbol for the goal colour every
turn, no variation. As listener: decode the goal from the key, but do
not beeline - cover the wrong mark FURTHEST from the goal for the first
two turns until the eavesdroppers settle on you, then break for the goal
and stay; you are paid for the Eves being far, and their turn of lag is
your margin. Say nothing. As an eavesdropper: turn 1 shadow the
listener; the moment the listener has settled a full turn on any mark,
cover that exact mark yourself - sitting on it beats trailing 60 px
behind; if the listener is still wandering by mid-round, cover the mark
he is nearest.
TAG as evader: intent evade every turn, and place target away from
corners - open middle beats walls. As a pursuer: only the lowest colour
rank among the pursuers shadows the evader to contact; the other two go
to cut-off points about 250 px AHEAD of the evader along its velocity,
one on each flank, herding it toward the chaser or a wall. Three tails
never catch a faster runner; a wall of two does.
note: one clause, your plan this turn.
"""

proc registrationBlob(prompt, scripted, policy: string): string =
  ## One Sprite v1 chat frame: 0x81, u16 little-endian length, ASCII
  ## payload (the chat parser drops bytes outside 32..126, so the JSON
  ## and the prompt stay pure ASCII).
  var node = %*{"type": "register", "prompt": prompt, "policy": policy}
  if scripted.len > 0:
    node["scripted"] = %scripted
  else:
    node["scripted"] = newJNull()
  let text = $node
  result = newString(3 + text.len)
  result[0] = char(0x81)
  result[1] = char(text.len and 0xff)
  result[2] = char((text.len shr 8) and 0xff)
  for i in 0 ..< text.len:
    result[3 + i] = text[i]

proc readyBlob(): string =
  ## The Sprite v1 player-ready packet (0x85). Legitimate for this seat:
  ## it sends no inputs at all, so a fastMode server may advance as soon
  ## as every seat has acknowledged the frame.
  result = newString(1)
  result[0] = char(0x85)

when isMainModule:
  let url = getEnv("COWORLD_PLAYER_WS_URL")
  if url.len == 0:
    quit("stribog: COWORLD_PLAYER_WS_URL is not set", 1)
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED").strip()
    label = "Stribog"
  echo "stribog: kind=", (if scripted.len > 0: "scripted" else: "llm"),
    " baseline=", (if scripted.len > 0: scripted else: "none")

  proc dial(attempts: int): WebSocket =
    ## Bounded dialling: the first dial routinely lands on a closed port.
    for attempt in 0 ..< attempts:
      try:
        return newWebSocket(url)
      except CatchableError as error:
        if attempt == 0:
          echo "stribog: game not listening yet (", error.msg, "); retrying"
        sleep(ConnectRetryMs)
    nil

  var socket = dial(ConnectAttempts)
  if socket == nil:
    quit("stribog: game never accepted a connection", 1)
  echo "stribog: connected"

  # whisky's receiveMessage raises on a close frame, and the game's own
  # quit(0) can outrun its last flushed frame - a dead socket after frames
  # were seen is a normal episode end, so exit 0 there.
  var reconnects = 0
  while true:
    var sessionFrames = 0
    try:
      socket.send(registrationBlob(prompt, scripted, label), BinaryMessage)
      var resends = 0
      while true:
        let received = socket.receiveMessage()
        if received.isNone:
          continue                    ## a read timeout, not a closed socket
        inc sessionFrames
        if resends < RegistrationResends and
            sessionFrames mod ResendEveryFrames == 1:
          inc resends
          socket.send(registrationBlob(prompt, scripted, label),
            BinaryMessage)
        socket.send(readyBlob(), BinaryMessage)
    except CatchableError as error:
      echo "stribog: socket closed (", error.msg, ")"
    # A seat that drops mid-episode plays drifter until it revives on
    # reconnect; a session that never received a frame means the game is
    # winding down.
    if sessionFrames == 0 or reconnects >= ReconnectAttempts:
      break
    inc reconnects
    echo "stribog: re-dialling the seat (attempt ", reconnects, ")"
    socket = dial(ReconnectAttempts)
    if socket == nil:
      echo "stribog: game is no longer listening, exiting cleanly"
      break
    echo "stribog: reconnected, re-registering"
  quit(0)
