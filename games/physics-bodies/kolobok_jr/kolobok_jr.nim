## Kolobok Jr — Physics Bodies (THE RING) policy for Andre von Auto.
## The physics-bodies player container is deliberately thin: it connects,
## sends one Sprite v1 BINARY chat packet (0x81 + u16le length) carrying
## its registration (operator prompt or scripted baseline), and
## thereafter only acknowledges frames; the game server makes every 1.5 s
## tactical order by sending that prompt plus the seat's view to the LLM
## — llm.nim and the anthropic_api_key secret live in the GAME pod, so
## the player pod makes no model call (docs/protocol_player.md). Seats
## send NO inputs; after each received frame the seat sends the Sprite v1
## Ready packet (0x85) so a fastMode server can pace ticks by readiness.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (pusher | anchor)
## Upload note: NO secret-envs needed — the game pod holds the LLM key.

import std/[json, options, os], whisky

const defaultPrompt = """
You are Kolobok Jr, a round little bug in a shrinking sumo ring. Best of
five rounds; win by ring-out (their torso over the rim), knockout (three
falls) or holding the centre at the clock. Read dist_to_rim for BOTH bugs
every turn: whoever is closer to the rim is losing that moment, whatever
the tally says.
Rules, strictly in this order:
1. If YOUR dist_to_rim is under 0.60, stance "retreat", aim "centre",
   aggression 8 for one turn — you are one shove from losing the round
   and nothing else matters.
2. If YOUR tilt_pct is above 55, stance "brace", posture_bias "low",
   aggression 3 until it drops below 35 — braced on four legs you take
   less tilt and a charger bounces off you.
3. If the other bug's dist_to_rim is under 0.90 AND you are in contact,
   stance "charge", aim "foe", aggression 10, lead_ticks 2, posture_bias
   "auto" — the all-in ring-out, worth the halved rim guard.
4. If the other bug is DOWN (down_ticks above 0), stance "charge",
   aim "foe", aggression 10, lead_ticks 0 — only a prone bug cannot
   shove (tilt_pct 55 still can plant); 1.5 s of free pushing, drive it
   at the nearest rim.
5. If it is charging you at speed (closing fast, aggression written in
   its motion), stance "brace", posture_bias "low": a well-planted
   four-leg brace takes zero recoil and its momentum loads tilt on it.
6. Otherwise manoeuvre: stance "circle", aim "foe", circle_dir toward
   the side that puts the ring centre behind YOU and the rim behind IT,
   aggression 6, posture_bias "even", lead_ticks 4. Never circle
   yourself between the foe and the rim.
7. Late round (after the shrink starts, round clock past 6 s): if you
   lead the round on knockdowns or it sits nearer the rim, stance
   "centre", aggression 5, posture_bias "low" — the shrinking ring does
   the pushing and the centre wins any decision.
8. Match state: if you lead the match 2 rounds, take rules 3 and 4 only
   at aggression 9 instead of 10 — never hand back a round by
   self-ring-out; if you trail 0-2, take rule 3 from dist_to_rim 1.10.
Keep note as your ledger: its last stance, what your last order achieved,
which circle_dir gained rim on it. Reply with exactly one JSON object of
note, stance, aim, bearing_deg, aggression, posture_bias, lead_ticks,
circle_dir, say.
"""

const
  SpriteClientChat = 0x81'u8
  SpriteClientReady = 0x85'u8
  registerResendFrames = 240 ## ~10 s of 24 Hz frames
  registerResendEvery = 12

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
    url = getEnv("COWORLD_PLAYER_WS_URL")
  if url == "":
    quit("kolobok_jr: COWORLD_PLAYER_WS_URL is not set", 1)
  let register = %*{
    "type": "register",
    "prompt": if scripted == "": prompt else: "",
    "scripted": if scripted == "": newJNull() else: %scripted,
    "policy": "Kolobok Jr"}
  echo "kolobok_jr: connecting to ", url
  let ws = newWebSocket(url)
  # Send immediately, then re-send on a bounded schedule: joins are
  # slot-sequential and the lobby can hand a socket frames before it is
  # admitted; the server HOLDS an unappliable registration
  # (docs/protocol_player.md).
  ws.send(chatPacket($register), BinaryMessage)
  var frames = 0
  while true:
    var received: Option[Message]
    try:
      received = ws.receiveMessage()
    except CatchableError:
      # The match is over when the server closes the socket.
      echo "kolobok_jr: websocket closed (", getCurrentExceptionMsg(), ")"
      break
    if received.isNone:
      continue
    let message = received.get()
    if message.kind == Ping:
      ws.send(message.data, Pong)
      continue
    inc frames
    if frames <= registerResendFrames and frames mod registerResendEvery == 1:
      ws.send(chatPacket($register), BinaryMessage)
    # Acknowledge every frame so fastMode can pace the tick by readiness.
    ws.send($char(SpriteClientReady), BinaryMessage)
  quit(0)

main()
