## Vodyanoy — Walker Waterworld policy for Andre von Auto.
## The seat is deliberately thin: it connects to the Sprite v1 player
## socket, sends ONE chat frame (0x81) carrying its registration — the
## operator prompt IS the strategy — and thereafter only answers every
## binary frame with the Ready packet (0x85). The game server composes
## the sensor view every 72 ticks and asks the seat's LLM for one intent;
## seats send no inputs (docs/protocol_player.md).
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (shoal | drifter)
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays scripted.

import std/[json, options, os], whisky

const defaultPrompt = """
You are Vodyanoy, the water spirit, one skimmer of a silent pod of four.
Reply with one JSON object: note, mode, target, partner, waypoint,
lead_ticks, standoff_m, throttle, say. A catch needs TWO skimmers touching
one plankton in the same tick and is worth +10; a lone nibble is +0.05 once;
poison is -2 plus a stun; thrust costs points, so coast when you can.
The whole game is rendezvous with partners who cannot hear you. Your
convention, every turn: your partner is the skimmer whose number differs
from yours only in the last bit (SKIM-1 with SKIM-2, SKIM-3 with SKIM-4).
Never switch to the nearest skimmer: nearest-neighbour is not symmetric,
so two seats who both "pick nearest" can pair three ways and catch nothing.
1. If you sense a plankton and your partner is within about 3 m of it: mode
   hunt, target that plankton (prefer the one nearest the midpoint between
   you and your partner), lead_ticks 12, throttle 0.8, standoff_m 0.6.
2. If you sense a plankton but your partner is far: mode hold ON the
   plankton's position - park there and wait; your partner's escort rule
   will bring them, and their arrival makes the catch. Do not chase it
   alone at speed; drift with throttle 0.4.
3. If you sense no plankton: mode escort, partner = that fixed pair mate,
   throttle 0.5, standoff_m 1.2. Escort auto-diverts you to any plankton
   sensed within 1.5 m of the partner - this is the designed rendezvous.
4. Poison overrides: if poison is within 1.0 m and closing, mode avoid for
   one turn, throttle 0.7. While hunting keep standoff_m 0.6 (wide enough
   to swing, narrow enough to still close on food); never above 2.0 when
   closing on a plankton.
Throttle discipline: 0.8 only on a final approach to a catch; 0.4-0.5
otherwise; the pod loses 6.9 points to full-throttle sprinting. All four
seats share one score, so never fight another pair for the same plankton:
if two other skimmers are closer to a plankton than your pair is, leave it
to them and escort your own partner elsewhere.
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

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "")
    url = getEnv("COWORLD_PLAYER_WS_URL")
  if url == "":
    quit("vodyanoy: COWORLD_PLAYER_WS_URL is not set", 1)
  echo "vodyanoy: connecting to ", url
  let ws = newWebSocket(url)
  let registration = $ %*{"type": "register", "prompt": prompt,
    "scripted": scripted, "policy": "Vodyanoy"}
  # Joins are slot-sequential: re-send the registration over the first
  # ~10 s of frames so a held slot still picks it up when it lands.
  ws.send(chatBlob(registration), BinaryMessage)
  var frames = 0
  while true:
    var received: Option[Message]
    try:
      received = ws.receiveMessage()
    except CatchableError:
      echo "vodyanoy: websocket closed (", getCurrentExceptionMsg(), ")"
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
    if frames <= 240:
      ws.send(chatBlob(registration), BinaryMessage)
    ws.send(readyBlob, BinaryMessage)
  quit(0)

main()
