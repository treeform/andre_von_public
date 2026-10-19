## Pryatki — Hide And Seek policy for Andre von Auto.
## The hide-and-seek player container is deliberately thin: it dials its
## seat, sends one Sprite v1 chat frame (0x81) carrying its registration,
## then only receives — answering every binary board frame with the Ready
## packet (0x85). The game server runs the LLM and computes every actuator
## mask, so the crafted operator prompt IS the strategy (docs/rules.md,
## docs/objects.md).
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (burrow | scatter)
## Upload note: the platform injects the anthropic_api_key secret into the
## GAME pod (manifest runnable env), so the seat needs no LLM secret-env.

import std/[json, options, os], whisky

const
  connectAttempts = 240      ## 240 x 500 ms = 2 minutes of dialling.
  connectRetryMs = 500
  registrationResends = 10   ## re-sends after the first, ~1 s apart.
  resendEveryFrames = 24     ## ~1 s of frames at 24 Hz.
  reconnectAttempts = 6

const defaultPrompt = """
You are Pryatki, the game itself, playing both roles across the swap.
Every hunt tick when ANY hider is inside ANY seeker cone pays the seekers;
every all-hidden tick pays the hiders. One seen hider is as bad as three.

HIDING (4 prep turns, then 8 hunt turns):
1. Split jobs by alias on the turn-1 radio: alpha walls the chosen
   pocket's doorway (push the nearest panel - a panel covers a door with
   room to spare - else a crate), beta drags ramp1 then ramp2 to the far
   corner away from the fort and locks them, gamma pushes a second crate
   to the fort mouth.
2. LOCK everything you place the moment it stands (intent lock, its
   object id). Seekers cannot unlock your locks - they can only shove
   what you forgot to lock.
3. Locked ramps far from the fort are the seal: a ramp is the only way
   over a locked wall. Never leave one within reach of the fort.
4. All three hiders inside the same walled pocket before release, intent
   hide facing the gap, then hold still and say nothing - a shout is
   audible to seekers within 144 px.
5. Do not try to wall the seeker pads: 96 px keep-clear discs refuse the
   push. Wall your fort, not their door.
6. If the fort is breached mid-hunt, scatter: their cone is a 70-degree
   340 px torch carried by their aim - break line of sight behind
   furniture and keep an occluder between you and every torch.

SEEKING (8 hunt turns):
1. Radio a three-way split on turn 1: alpha sweeps the left half, beta
   the right, gamma goes straight at the obvious fort. Your torch is your
   aim - point it where you search.
2. Push every unlocked object out of doorways. If a wall refuses
   (lock_refused), find a ramp: an unlocked ramp pushed to the wall is a
   door - vault with its object id. You are visible while airborne; vault
   into the fort, not around it.
3. The moment anyone sees a hider, radio the position; the finder parks
   on it (watch, face at the hider) and never lets the cone slip - one
   hider held in a cone pays every remaining tick. The other two keep
   hunting the rest.
4. A locked fort you can see into is already losing for them: press the
   cone through the gap they left rather than shoving a locked wall.

Reply with one JSON order: intent
(move_to|hide|watch|chase|push|lock|unlock|vault), object (box1..box4,
pan1, pan2, ramp1, ramp2 when the intent needs one), to [x,y], at (a
published anchor or door id - at wins over to), face, say (<=10 runes),
radio (<=96 runes), notes (<=160 runes).
"""

proc spriteChatBlob(text: string): string =
  ## Sprite v1 chat frame: type byte 0x81, u16 little-endian length,
  ## then the payload (bitworld spriteprotocol framing).
  result = newString(3 + text.len)
  result[0] = char(0x81)
  result[1] = char(text.len and 0xff)
  result[2] = char((text.len shr 8) and 0xff)
  for i, ch in text:
    result[3 + i] = ch

proc readyBlob(): string =
  ## The Sprite v1 player-ready packet (0x85). This seat sends no inputs
  ## (the server computes every actuator mask), so acknowledging each frame
  ## is safe and lets a fastMode server advance the tick.
  result = newString(1)
  result[0] = char(0x85)

proc registrationBlob(prompt, scripted: string): string =
  ## The one registration message. scripted is JSON null for an LLM seat so
  ## the server can tell "no baseline named" from "burrow named".
  var frame = %*{"type": "register", "prompt": prompt, "policy": "Pryatki"}
  if scripted.len > 0:
    frame["scripted"] = %scripted
  else:
    frame["scripted"] = newJNull()
  spriteChatBlob($frame)

proc main() =
  let url = getEnv("COWORLD_PLAYER_WS_URL")
  if url == "":
    quit("pryatki: COWORLD_PLAYER_WS_URL is not set", 1)
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "")

  proc dial(attempts: int): WebSocket =
    ## Bounded dialling: the game bakes its board render caches before
    ## opening the listener, so the first dial usually lands closed.
    for attempt in 0 ..< attempts:
      try:
        return newWebSocket(url)
      except CatchableError:
        if attempt == 0:
          echo "pryatki: game not listening yet, retrying"
        sleep(connectRetryMs)
    nil

  var socket = dial(connectAttempts)
  if socket == nil:
    quit("pryatki: game never accepted a connection", 1)
  echo "pryatki: connected"

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
      echo "pryatki: socket closed (", getCurrentExceptionMsg(), ")"
    if sessionFrames == 0 or reconnects >= reconnectAttempts:
      break
    inc reconnects
    echo "pryatki: re-dialling the seat (attempt ", reconnects, ")"
    socket = dial(reconnectAttempts)
    if socket == nil:
      echo "pryatki: game is no longer listening, exiting cleanly"
      break
    echo "pryatki: reconnected, re-registering"
  quit(0)

main()
