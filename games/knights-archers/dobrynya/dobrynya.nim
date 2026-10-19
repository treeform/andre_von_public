## Dobrynya Nikitich — Knights Archers Zombies policy for Andre von Auto.
## The seat speaks the binary Sprite v1 protocol inherited from coworld-ctf
## (docs/protocol_player.md): it receives one binary frame per tick and
## sends no inputs at all. Its only sends are one chat packet (0x81)
## carrying the registration JSON - re-sent for the first ~10 s of frames
## because joins are slot-sequential - and a ready packet (0x85) after each
## received frame. Every directive is decided server-side.
##
## Default is the published `phalanx` baseline, not the LLM prompt: the
## server sets isLlm from prompt.len > 0 (src/kaz/server.nim), so a
## non-empty prompt would ignore the baseline. League leader is
## co-gas-knights-archers-phalanx-relhalpha (wr 0.94). Phalanx is the
## grid-tuned work-splitter (KNIGHT-alpha z[0], KNIGHT-beta z[1],
## ARCHER-alpha z[0], ARCHER-beta z[2]; 493 team value vs stand's 339).
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED play a scripted baseline (phalanx | stand).
##                   Defaults to phalanx. Empty string forces the prompt.
## Upload note: default is scripted, so no Bedrock flag is required. LLM
## override needs --secret-env USE_BEDROCK=true.

import std/[json, options, os, strutils], whisky

const
  SpriteClientChat = 0x81'u8
  SpriteClientReady = 0x85'u8
  ConnectAttempts = 240      ## 240 x 500 ms = 2 minutes of dialling.
  ConnectRetryMs = 500
  RegistrationResends = 10   ## re-sends after the first, ~1 s apart.
  ResendEveryFrames = 24     ## ~1 s of frames at 24 Hz.
  ReconnectAttempts = 6

const defaultPrompt = """
You are Dobrynya Nikitich, one hero of four holding the gate. The score is
the SQUAD's: a cleared wave is worth 20 kills, and one breach or one hero
death - anyone's - ends the wave and banks only what you had. Survival
beats kills, always. Check which hero you are each turn and play the role.
AS A KNIGHT:
1. Intercept the zombie closest to the gate when it is in your half of the
   field (KNIGHT-alpha takes y < 330, KNIGHT-beta takes y >= 330). Never
   chase east of x = 820 - a dead knight ends the wave.
2. You die to one touch and swing once per 0.9 s: fight one zombie at a
   time. With three or more bodies inside 90 px, fall_back 140 px toward
   the gate for a turn and let them string out.
3. No zombies alive: hold your choke post - [560, 240] alpha,
   [560, 420] beta.
AS AN ARCHER:
1. Distance is your whole life: a zombie inside 90 px charges and covers
   144 px in one turn. Anything within 200 px of you - fall_back west
   immediately. Never walk east toward a target.
2. Stand 300-450 px west of the front - [300, 240] alpha, [300, 420]
   beta - and focus the zombie CLOSEST TO THE GATE. Both archers on the
   SAME target: two arrows inside a second is a kill, two arrows on two
   zombies is two wounded zombies still walking.
EVERYONE:
- say your lane or target every turn ("north", "south", "leader") - all
  four seats decide simultaneously and say is the only coordination.
  If a teammate called a lane last turn, take the other.
- If the line looks broken (a zombie west of the knights), everything
  targets it: knights intercept, archers focus.
- Last 10 seconds of a wave: maximum safety, give ground, bank the clear.
note: track which lane you own, the leader's position, and what each
teammate said last turn.
"""

proc registrationBlob(prompt, scripted, policy: string): string =
  ## One Sprite v1 chat packet (0x81, u16 LE length, ASCII bytes) carrying
  ## the registration JSON. scripted is JSON null for an LLM seat so the
  ## server can tell "no baseline named" from "phalanx named explicitly".
  var node = %*{"type": "register", "prompt": prompt, "policy": policy}
  node["scripted"] = if scripted.len > 0: %scripted else: newJNull()
  let text = $node
  result = newString(3 + text.len)
  result[0] = char(SpriteClientChat)
  result[1] = char(text.len and 0xff)
  result[2] = char((text.len shr 8) and 0xff)
  for i, ch in text:
    result[3 + i] = ch

proc readyBlob(): string =
  ## The Sprite v1 player-ready packet (0x85). Legitimate for this seat in
  ## a way it is not for an ordinary client: this seat sends no inputs, so
  ## the dead-reckoning hazard cannot arise.
  result = newString(1)
  result[0] = char(SpriteClientReady)

proc main() =
  let url = getEnv("COWORLD_PLAYER_WS_URL")
  if url.len == 0:
    quit("dobrynya: COWORLD_PLAYER_WS_URL is not set", 1)
  let
    scripted = getEnv("PLAYER_SCRIPTED", "phalanx").strip()
    ## Server: isLlm = prompt.len > 0, even when scripted is named. Empty
    ## the prompt whenever a baseline is set so the seat actually plays it.
    prompt =
      if scripted.len > 0: ""
      else: getEnv("PLAYER_PROMPT", defaultPrompt)
    registration = registrationBlob(prompt, scripted, "Dobrynya Nikitich")
  echo "dobrynya: kind=", (if scripted.len > 0: "scripted" else: "llm"),
    " baseline=", (if scripted.len > 0: scripted else: "none")

  proc dial(attempts: int): WebSocket =
    ## Bounded dialling: the players start at the same instant as the game,
    ## so the first dial can land on a closed port.
    for attempt in 0 ..< attempts:
      try:
        return newWebSocket(url)
      except CatchableError as error:
        if attempt == 0:
          echo "dobrynya: game not listening yet (", error.msg,
            "); retrying"
        sleep(ConnectRetryMs)
    nil

  var socket = dial(ConnectAttempts)
  if socket == nil:
    quit("dobrynya: game never accepted a connection", 1)
  echo "dobrynya: connected"

  # Registration is re-sent, not sent once: joins are slot-sequential and
  # the lobby can send frames to a socket before it is admitted, so a
  # single early registration can land while the seat has no index yet.
  # Re-registering is harmless - the server re-reads the same fields.
  var reconnects = 0
  while true:
    var sessionFrames = 0
    try:
      socket.send(registration, BinaryMessage)
      var resends = 0
      while true:
        let received = socket.receiveMessage()
        if received.isNone:
          continue                  ## a read timeout, not a closed socket
        inc sessionFrames
        if resends < RegistrationResends and
            sessionFrames mod ResendEveryFrames == 1:
          inc resends
          socket.send(registration, BinaryMessage)
        socket.send(readyBlob(), BinaryMessage)
    except CatchableError as error:
      echo "dobrynya: socket closed (", error.msg, ")"
    # A session that never received a frame means the game is winding
    # down; a dropped socket mid-episode is worth re-dialling because a
    # seat that reconnects revives its hero. Bounded on both counts.
    if sessionFrames == 0 or reconnects >= ReconnectAttempts:
      break
    inc reconnects
    echo "dobrynya: re-dialling the seat (attempt ", reconnects, ")"
    socket = dial(ReconnectAttempts)
    if socket == nil:
      echo "dobrynya: game is no longer listening, exiting cleanly"
      break
    echo "dobrynya: reconnected, re-registering"
  quit(0)

main()
