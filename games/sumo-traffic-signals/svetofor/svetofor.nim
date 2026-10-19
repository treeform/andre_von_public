## Svetofor — Sumo Traffic Signals policy for Andre von Auto.
## The sumo-traffic-signals player container is a registrar, not a
## controller: it connects, sends one Sprite v1 BINARY chat packet (0x81
## + u16le length) carrying its registration (operator prompt or scripted
## baseline), and thereafter only acknowledges frames; the game server
## makes every 8 s signal decision by sending that prompt plus the seat's
## view to the LLM — the anthropic_api_key secret is injected into the
## GAME pod, so no USE_BEDROCK flag is needed on a policy
## (docs/PROTOCOL.md). The Sprite v1 Ready packet (0x85) is explicitly
## supported and safe here: seats send no inputs and every shipped
## variant runs fastMode.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (greedy | fixedcycle)
## Upload note: NO secret-envs needed — the game pod holds the LLM key.

import std/[json, options, os], whisky

const defaultPrompt = """
You are Svetofor, the traffic-light spirit running one quadrant of a 4x4
grid city. Only cars that EXIT the city score, for everyone equally:
your green is your neighbour's queue, so throughput beats fairness and a
full downstream block beats every other consideration.
Rules, in order:
1. NEVER green into a full exit. Before every order check each exit
   link's occupancy: if the exit a phase feeds shows full (or occupancy
   = capacity), do not run that phase — hold, or serve the cross
   street. A green into a full block moves nobody and grows gridlock.
2. Spillback listed at one of your links is the emergency: gate the
   UPSTREAM feeder with hold (starve the jam) and serve the phase that
   drains the jammed link's head. Watch network_status.spillback every
   turn.
3. Blocked left-turners poison through-lanes: an approach with
   stop_line "left" and rising blocked_ticks blocks its whole avenue.
   Serve NSL/EWL there for one turn as soon as blocked_ticks passes 10,
   then return to through phases.
4. Build green waves along avenues. A car covers one cell per tick; an
   east-west block is 6 cells, north-south 4. Every phase change then
   costs 2 ticks of all-red, so delay 6 never greens this 8-tick turn
   (clearance eats k=6 and k=7). When you own consecutive intersections
   on a row, order the upstream one "phase EWG" and the downstream one
   "wave EWG delay 4" (delay 2 for columns, NSG) — delay = travel minus
   clearance. Use inbound nearest_ticks: delay = nearest_ticks - 2,
   clamped 0..6.
5. Two of the four signals on any avenue belong to another controller:
   coordinate out loud. Every turn say your offsets in the radio, short
   and exact: "C row eastbound wave, C2 EWG at +3, Delta take C3 at +6".
   READ the radio and extend a neighbour's announced wave through your
   signals with the matching delay — a completed wave scores for you
   both; an ignored one dies at your stop line.
6. Where queues are light or balanced and no wave is running, order
   "auto" — the actuator serves the longest movable queue and never
   wastes green on an empty approach. Auto is your default for the two
   signals not on the active wave.
7. Check last_order_result: "deferred" means minGreenTicks ate your
   offset — re-issue the wave with delay reduced by the turn you lost;
   "repaired" means your order was malformed, state it more plainly.
8. Late episode (turn 26+, demand ending): flush, do not store. Serve
   whichever phase discharges the most cars toward the nearest edge
   gates; abandon wave building that cannot complete before the end.
Keep notes as your ledger: active wave (row, phase, per-signal delays),
jammed links, which neighbour honours radio calls. Reply with exactly
one JSON object of orders (at/verb/phase/delay for YOUR four
intersections only), say, notes.
"""

const
  SpriteClientChat = 0x81'u8
  SpriteClientReady = 0x85'u8
  registerResendFrames = 240 ## ~10 s of received frames
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
    quit("svetofor: COWORLD_PLAYER_WS_URL is not set", 1)
  let register = %*{
    "type": "register",
    "prompt": if scripted == "": prompt else: "",
    "policy": "Svetofor",
    "scripted": if scripted == "": newJNull() else: %scripted}
  echo "svetofor: connecting to ", url
  let ws = newWebSocket(url)
  # Send immediately, then keep re-sending through the first ~10 s of
  # received frames: joins are slot-sequential, the server HOLDS an
  # unappliable registration, and registering twice is harmless
  # (docs/PROTOCOL.md).
  ws.send(chatPacket($register), BinaryMessage)
  var frames = 0
  while true:
    var received: Option[Message]
    try:
      received = ws.receiveMessage()
    except CatchableError:
      # The episode is over when the server closes the socket.
      echo "svetofor: websocket closed (", getCurrentExceptionMsg(), ")"
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
    # Ready is supported and safe here: seats send no inputs and every
    # shipped variant runs fastMode (docs/PROTOCOL.md).
    ws.send($char(SpriteClientReady), BinaryMessage)
  quit(0)

main()
