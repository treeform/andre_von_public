## Ivanushka — Tandem policy for Andre von Auto.
## The seat is deliberately thin: it connects to the Sprite v1 player
## socket, sends ONE chat frame (0x81) carrying its registration, and
## thereafter only answers every binary frame with the Ready packet
## (0x85). The game container computes both force vectors; player
## sockets contribute no input (docs/protocol_player.md).
##
## Default is the published `porter` baseline, not the LLM prompt: a
## non-empty prompt is an LLM seat and `scripted` is ignored. League
## leader is co-gas-tandem-porter-relhalpha; richard also fields porter.
## Porter is the strain-arbitrated carrier (doorway-centre drive, axis
## align, brace in gaps, yield when the felt force opposes). Score is
## fully cooperative, and the usual cross-play partner is porter.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED play a scripted baseline (porter | mule).
##                   Defaults to porter. Empty string forces the prompt.
## Upload note: default is scripted, so no Bedrock flag is required. LLM
## override needs --secret-env USE_BEDROCK=true.

import std/[json, options, os, strutils], whisky

const defaultPrompt = """
You are Ivanushka, one of two cogs gripped to opposite handles of one couch.
Reply with one JSON object: note, drive, effort, yield, twist, brace, say.
Delivering at all beats everything: score is 0.30 + 0.35*speed +
0.35*condition delivered, only 0.25*progress*condition otherwise, and a
wrecked couch scores 0.000. Condition is worth exactly as much as speed, so
never trade upholstery for pace.
Steady-state orders: aim drive at the centre of the NEXT doorway, not the
goal. Effort 0.65 in open floor; 0.35 within two metres of a door. Yield 0.15
in the open. Twist toward the corridor you are about to enter, back to 0 the
moment the couch axis is within about 15 degrees of the doorway's through
direction - get aligned BEFORE you are within 1.5 m of the door. Brace 0.85
inside any doorway or whenever strain exceeds 600 N: it halves your push and
raises your grip limit, and in a gap it is almost always right.
Your partner cannot hear you; the only channel is the strain in your hands.
If the strain pulls roughly along your intended line, they are leading well:
push the SAME line and raise yield toward 0.5. If the strain opposes your
line by more than 90 degrees, do not fight - fighting spins the couch into a
wall. Either raise yield to 0.7 and follow their line for a turn, or commit
hard to yours with effort 0.8 and yield 0.2; never split the difference two
turns running.
Damage rules: if you scraped last turn, cut effort to 0.2 and drive away from
the wall for one turn. Approaching any wall fast risks a 200-point impact:
ease effort down early. If strain sits above your grip limit, brace
immediately - at 240 slip you drop the couch. The last doorway is always
1.05 m for a 0.90 m couch: arrive slow, aligned, braced.
"""

proc chatBlob(text: string): string =
  ## Sprite v1 client chat packet: 0x81, u16 little-endian length, bytes.
  result = newString(text.len + 3)
  result[0] = char(0x81)
  result[1] = char(text.len and 0xff)
  result[2] = char((text.len shr 8) and 0xff)
  for i, ch in text:
    result[i + 3] = ch

const readyBlob = "\x85"

proc registrationJson(prompt, scripted: string): string =
  ## scripted is JSON null for an LLM seat so the server can tell "no
  ## baseline named" from "porter named".
  var node = %*{"type": "register", "prompt": prompt, "policy": "Ivanushka"}
  node["scripted"] = if scripted.len > 0: %scripted else: newJNull()
  $node

proc main() =
  let
    scripted = getEnv("PLAYER_SCRIPTED", "porter").strip()
    ## Server: a non-empty prompt is an LLM seat even when scripted is
    ## named. Empty the prompt whenever a baseline is set so the seat
    ## actually plays it.
    prompt =
      if scripted.len > 0: ""
      else: getEnv("PLAYER_PROMPT", defaultPrompt)
    url = getEnv("COWORLD_PLAYER_WS_URL")
  if url == "":
    quit("ivanushka: COWORLD_PLAYER_WS_URL is not set", 1)
  echo "ivanushka: kind=", (if scripted.len > 0: "scripted" else: "llm"),
    " baseline=", (if scripted.len > 0: scripted else: "none")
  echo "ivanushka: connecting to ", url
  let ws = newWebSocket(url)
  let registration = registrationJson(prompt, scripted)
  # Sent on connect and re-sent once after the first received frame, in
  # case the first send raced slot registration (docs/protocol_player.md).
  ws.send(chatBlob(registration), BinaryMessage)
  var frames = 0
  while true:
    var received: Option[Message]
    try:
      received = ws.receiveMessage()
    except CatchableError:
      echo "ivanushka: websocket closed (", getCurrentExceptionMsg(), ")"
      break
    if received.isNone:
      continue
    let message = received.get()
    if message.kind == Ping:
      ws.send(message.data, Pong)
      continue
    if message.kind != BinaryMessage:
      continue
    inc frames
    if frames == 1:
      ws.send(chatBlob(registration), BinaryMessage)
    ws.send(readyBlob, BinaryMessage)
  quit(0)

main()
