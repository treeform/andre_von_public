## Emelya — THE CABINET (atari-cabinet) policy for Andre von Auto.
## The cabinet player container is deliberately thin: it dials its seat,
## sends one Sprite v1 chat frame (0x81) carrying its registration, then
## only receives — answering every binary board frame with the Ready
## packet (0x85). The game server runs the LLM and compiles every command
## byte, so the crafted operator prompt IS the strategy
## (docs/protocol_player.md, docs/stances.md).
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (bulwark | spinner)
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays scripted.

import std/[json, options, os], whisky

const
  connectAttempts = 240      ## 240 x 500 ms = 2 minutes of dialling.
  connectRetryMs = 500
  registrationResends = 10   ## re-sends after the first, ~1 s apart.
  resendEveryFrames = 24     ## ~1 s of frames at 24 Hz.
  reconnectAttempts = 6

const defaultPrompt = """
You are Emelya, the sly stove-rider, playing a four-way arcade cabinet duel.
Lives are everything: 20 points each (normalised), a knockout only 2, a chip
0.5, a save 0.25. Never trade a life for damage. Priorities each turn:
1. Read the balls array. Inbound to YOU is arrive_along != null (your line);
   arrive_at is whoever is first, not always you. If any inbound ball has
   arrive_in_ticks <= 140 (or arrive_along set while arrive_at is not you):
   intercept it. `aim` is the same intercept as `guard` and never misses on
   purpose, so use stance aim at the wounded rival (fewest lives, then
   fewest bricks) when arrive_in_ticks > 24; only stance guard (lead_ticks
   16) when arrive_in_ticks <= 24 AND arrive_at is you. Target that ball.
   A miss is a decision, never physics - your bar outruns the ball.
2. If BOTH balls will reach your line this turn window, stop aiming: stance
   camp at the midpoint of the two arrive_along values, aggression 0.9.
3. Only when no ball has arrive_along set inside 140 ticks: stance aim at
   the most wounded alive rival - fewest lives first, then the one with the
   most broken castle columns. Target the ball arriving at you soonest,
   aim_at that rival, lead_ticks 12. Free saves plus 2-point knockouts, and
   one fewer gun pointed at you.
4. In the warlords ROM, when exactly one ball is live and you are safe,
   stance catch, hold and release at the weakest rival (aggression 0.6);
   while holding you cannot defend the other ball, so never catch with two
   live balls.
5. On your LAST life, drop every aim: guard or camp only, post 0,
   lead_ticks 12, aggression 0.9. Survive - placement among the living is
   lives, then bricks, then saves.
6. Protect your castle columns: if a column is breached, bias post a little
   toward the open lane. Never chase; being out of position for the second
   ball is how cabinets die.
7. When only one rival is left, keep guarding first; aim at them only on
   balls that cannot come back through your mouth quickly.
Reply with exactly one JSON object: note, stance
(guard|aim|camp|catch|chase), target_ball (B1|B2|any), aim_at (a colour
alias or none), post (-43..43), lead_ticks (8..20 is the useful band),
aggression (0..1), say (taunt for spectators). Copy aliases and ball ids
verbatim from the view. Trust arrive_at / arrive_in_ticks / arrive_along -
the engine computed them with the autopilot's own walk.
"""

proc spriteChatBlob(text: string): string =
  ## Sprite v1 chat frame: type byte 0x81, u16 little-endian length,
  ## then the ASCII payload (bitworld spriteprotocol framing).
  result = newString(3 + text.len)
  result[0] = char(0x81)
  result[1] = char(text.len and 0xff)
  result[2] = char((text.len shr 8) and 0xff)
  for i, ch in text:
    result[3 + i] = ch

proc readyBlob(): string =
  ## The Sprite v1 player-ready packet (0x85). This seat sends no inputs
  ## (the server computes every command byte), so acknowledging each frame
  ## is safe and lets a fastMode server advance the tick.
  result = newString(1)
  result[0] = char(0x85)

proc registrationBlob(prompt, scripted: string): string =
  ## The one registration message. scripted is JSON null for an LLM seat so
  ## the server can tell "no baseline named" from "bulwark named".
  var frame = %*{"type": "register", "prompt": prompt, "policy": "Emelya"}
  if scripted.len > 0:
    frame["scripted"] = %scripted
  else:
    frame["scripted"] = newJNull()
  spriteChatBlob($frame)

proc main() =
  let url = getEnv("COWORLD_PLAYER_WS_URL")
  if url == "":
    quit("emelya: COWORLD_PLAYER_WS_URL is not set", 1)
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "")

  proc dial(attempts: int): WebSocket =
    ## Bounded dialling: the game opens its listener after baking render
    ## caches, so the first dial usually lands on a closed port.
    for attempt in 0 ..< attempts:
      try:
        return newWebSocket(url)
      except CatchableError:
        if attempt == 0:
          echo "emelya: game not listening yet, retrying"
        sleep(connectRetryMs)
    nil

  var socket = dial(connectAttempts)
  if socket == nil:
    quit("emelya: game never accepted a connection", 1)
  echo "emelya: connected"

  # Joins are slot-sequential and the lobby streams frames before a seat is
  # admitted, so the registration is re-sent for the first ~10 s of frames.
  # The socket can also die on the game's own quit(0) racing its last flush;
  # exiting 0 on a dead socket after a played session is correct.
  var reconnects = 0
  while true:
    var sessionFrames = 0
    try:
      socket.send(registrationBlob(prompt, scripted), BinaryMessage)
      var resends = 0
      while true:
        let received = socket.receiveMessage()
        if received.isNone:
          continue                  ## a read timeout, not a closed socket
        inc sessionFrames
        if resends < registrationResends and
            sessionFrames mod resendEveryFrames == 1:
          inc resends
          socket.send(registrationBlob(prompt, scripted), BinaryMessage)
        socket.send(readyBlob(), BinaryMessage)
    except CatchableError:
      echo "emelya: socket closed (", getCurrentExceptionMsg(), ")"
    if sessionFrames == 0 or reconnects >= reconnectAttempts:
      break
    inc reconnects
    echo "emelya: re-dialling the seat (attempt ", reconnects, ")"
    socket = dial(reconnectAttempts)
    if socket == nil:
      echo "emelya: game is no longer listening, exiting cleanly"
      break
    echo "emelya: reconnected, re-registering"
  quit(0)

main()
