## Plyaska — Continuous Control policy for Andre von Auto.
## The continuous-control player container is deliberately thin: it
## connects, sends one Sprite v1 BINARY chat packet (0x81 + u16le length)
## carrying its registration (operator prompt or scripted baseline), and
## thereafter only listens; the game server makes every 1.5 s gait order
## by sending that prompt plus the seat's view to the LLM — the
## anthropic_api_key coworld secret is injected into the GAME pod, so the
## player pod makes no model call (docs/PROTOCOL.md). The registration is
## re-sent for the first ~10 s of received frames because a first send
## can race the server's slot bookkeeping.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (trotter | plodder)
## Upload note: NO secret-envs needed — the game pod holds the LLM key.

import std/[json, options, os], whisky

const defaultPrompt = """
You are Plyaska, a folk dancer driving three machines down a 60 m track:
hopper (stage 1), cheetah (stage 2), walker (stage 3), 13 orders of 1.5 s
each per stage. Score is metres covered plus a small upright bonus minus
actuator cost — a fall ENDS a hopper or walker stage, the cheetah cannot
fall. Never brake on hopper or walker: brake switches the servos to pure
damping and a stiff biped under brake sags and dies in a second. Brake is
for the cheetah only, and even there distance beats stopping — never use
it.
Per body:
- HOPPER (fragile: falls past 20 deg pitch or torso under 0.70 m). Turn 1:
  crouch, power 40, cadence 40 to settle the seeded wobble. Then run,
  cadence 55, power 60. Raise power by 10 a turn toward 75 only while
  pitch stays small and no joint saturates. If pitch grows or airborne
  ticks pass 20, cut power 15 and cadence 10 immediately — a survived slow
  stage out-scores a fast fall (2.00 pts/metre, the richest body).
- CHEETAH (cannot fall — floor the throttle). Turn 1: run, cadence 70,
  power 85. If strides land and slip stays under 0.5, go power 95 then
  100, cadence 75-80. Saturated joints: lower cadence 10 before touching
  power. If distance stalls with strides counting, add lean +10. Bound
  only if run has already reached power 100 without slip; drop bound the
  turn airborne ticks pass 25.
- WALKER (heavy, tips forward; falls outside 0.80-2.00 m or past 57 deg).
  Turn 1: crouch, power 40. Turn 2: walk, cadence 45, power 55. From turn
  4: run, cadence 50, power 60, lean +8. Ceiling power 70 — the walker
  dies of greed. Any pitch warning: back to walk, cadence 45, power 50,
  lean 0 for two turns before retrying.
Every turn read the feedback before ordering: saturated -> power too high
for this cadence; slip over 0.5 -> foot skating, lower cadence or power;
airborne near 36 -> launching not running; strides with no distance ->
add lean; pitch toward the limit -> cut power NOW. Change at most two
numbers per turn on terminating bodies. phase_shift is a one-shot nudge:
use +10 once after a stumble to re-time the stride, never repeat it two
turns running.
Keep notes as your tuning ledger, format "body cadence/power/lean: result
m, what saturated" plus the best known triple per body; trust the ledger
over memory and return to the best-known triple after any experiment that
lost distance. Reply with exactly one JSON object of gait, cadence,
power, lean, stride_bias, phase_shift, say, notes.
"""

const
  SpriteClientChat = 0x81'u8
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
    quit("plyaska: COWORLD_PLAYER_WS_URL is not set", 1)
  let register = %*{
    "policy": "Plyaska",
    "prompt": if scripted == "": prompt else: "",
    "scripted": if scripted == "": newJNull() else: %scripted}
  echo "plyaska: connecting to ", url
  let ws = newWebSocket(url)
  # Send immediately, then re-send through the first ~10 s of received
  # frames: joins are slot-sequential and a first registration can land
  # before the seat has an index (docs/PROTOCOL.md).
  ws.send(chatPacket($register), BinaryMessage)
  var frames = 0
  while true:
    var received: Option[Message]
    try:
      received = ws.receiveMessage()
    except CatchableError:
      # The episode is over when the server closes the socket.
      echo "plyaska: websocket closed (", getCurrentExceptionMsg(), ")"
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
  quit(0)

main()
