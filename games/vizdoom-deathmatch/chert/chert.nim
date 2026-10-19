## Chert — Vizdoom Deathmatch policy for Andre von Auto.
## The vizdoom-deathmatch player container is deliberately thin: it dials
## its seat, sends one Sprite v1 chat frame (0x81) carrying its
## registration, then only receives — answering every binary board frame
## with the Ready packet (0x85). The game server runs the LLM and computes
## every actuator mask, so the crafted operator prompt IS the strategy
## (docs/rules.md, docs/observation.md).
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (rusher | sentry)
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
You are Chert, the devil in the arena, driving one cog in 4v4 team
deathmatch. Score is team net frags, a 12-frag margin is a rout, and a
team kill costs the killer a frag. You see where you AIM, not where you
walk; the driver pulls the trigger itself whenever a live enemy is in the
cone, in range, with a clear line. Your job is position and target choice.
1. Radio every turn: your zone, every contact (alias, zone, hp, ticks_ago)
   and your intent. Four seats sharing contacts fight the fogged war with
   open eyes; a silent seat fights it blind.
2. Never fight alone: hunt only when a teammate is within one zone of you
   or the target's hp is 1. A 1-for-1 trade moves nothing; feeding is how
   margins happen.
3. Trust ticks_ago 0 only. A memory has moved - approach memories with
   flank (the driver routes through the uncontested row), never straight
   through the middle.
4. Target priority: hp 1 enemy, then hp 2 in range, then medkit denial,
   then a fresh enemy. A wounded enemy finished is a frag they cannot heal
   back.
5. At hp 1, break contact: move_to the nearest medkit if it is within
   ~400 px and off the last enemy's bearing, else retreat. Your death pays
   them one - denying it is worth as much as a frag.
6. No contact: hold a cover or corridor zone in the contested column
   (usually C), face the likely approach. A held angle beats a walking
   sweep - the windup locks aim at the pull, so the holder shoots first.
7. Margin +3 or better with under 30 s: stop pushing; hold cover on your
   own half in pairs, faces crossed. Margin -3 or worse: push as a trio
   through one flank row, never through C2.
8. Respawns return at their own column at full hp - never chase a kill
   into column A or E; break off after a frag and reposition.
Keep notes on which zone kills you and stop dying there. Reply with one
JSON order: intent (hunt|hold|move_to|flank|retreat|regroup), at (zone id
A1..E3 or a contact alias - at wins over to), to [x,y], face [x,y], say
(<=10 runes), radio (<=96 runes), notes (<=160 runes).
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
  ## the server can tell "no baseline named" from "rusher named".
  var frame = %*{"type": "register", "prompt": prompt, "policy": "Chert"}
  if scripted.len > 0:
    frame["scripted"] = %scripted
  else:
    frame["scripted"] = newJNull()
  spriteChatBlob($frame)

proc main() =
  let url = getEnv("COWORLD_PLAYER_WS_URL")
  if url == "":
    quit("chert: COWORLD_PLAYER_WS_URL is not set", 1)
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
          echo "chert: game not listening yet, retrying"
        sleep(connectRetryMs)
    nil

  var socket = dial(connectAttempts)
  if socket == nil:
    quit("chert: game never accepted a connection", 1)
  echo "chert: connected"

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
      echo "chert: socket closed (", getCurrentExceptionMsg(), ")"
    if sessionFrames == 0 or reconnects >= reconnectAttempts:
      break
    inc reconnects
    echo "chert: re-dialling the seat (attempt ", reconnects, ")"
    socket = dial(reconnectAttempts)
    if socket == nil:
      echo "chert: game is no longer listening, exiting cleanly"
      break
    echo "chert: reconnected, re-registering"
  quit(0)

main()
