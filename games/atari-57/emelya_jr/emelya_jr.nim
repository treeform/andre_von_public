## Emelya Jr — Atari 57 policy for Andre von Auto.
## The atari-57 player container is deliberately thin: it dials its seat,
## sends one Sprite v1 chat frame (0x81) carrying its registration, then
## only receives — answering every binary lane frame with the Ready packet
## (0x85). The game server computes every action byte from the registered
## policy. Default is the published `arcader` baseline (grid-swept; the
## league leader `atari-57-example` is this example player). A non-empty
## PLAYER_PROMPT still makes the seat an LLM seat (docs/protocol.md,
## docs/stances.md).
##
## Env:
##   PLAYER_PROMPT   non-empty -> LLM seat with this operator prompt
##   PLAYER_SCRIPTED play a scripted baseline (arcader | hoover); default
##                   arcader. Server: isLlm = prompt.len > 0, so an empty
##                   prompt is required to actually play scripted.
## Upload note: the platform injects the anthropic_api_key secret into the
## GAME pod (manifest runnable env), so the seat needs no LLM secret-env.

import std/[json, options, os], whisky

const
  connectAttempts = 240      ## 240 x 500 ms = 2 minutes of dialling.
  connectRetryMs = 500
  registrationResends = 10   ## re-sends after the first, ~1 s apart.
  resendEveryFrames = 24     ## ~1 s of frames at 24 Hz.
  reconnectAttempts = 6

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
  ## (the server computes every action byte), so acknowledging each frame
  ## is safe and lets a fastMode server advance the tick.
  result = newString(1)
  result[0] = char(0x85)

proc registrationBlob(prompt, scripted: string): string =
  ## The one registration message. scripted is JSON null for an LLM seat so
  ## the server can tell "no baseline named" from "arcader named".
  var frame = %*{"type": "register", "prompt": prompt, "policy": "Emelya Jr"}
  if scripted.len > 0:
    frame["scripted"] = %scripted
  else:
    frame["scripted"] = newJNull()
  spriteChatBlob($frame)

proc main() =
  let url = getEnv("COWORLD_PLAYER_WS_URL")
  if url == "":
    quit("emelya_jr: COWORLD_PLAYER_WS_URL is not set", 1)
  # Empty prompt + scripted=arcader: isLlm is false and the server runs the
  # grid-swept baseline. A non-empty PLAYER_PROMPT still wins (isLlm = true).
  let
    prompt = getEnv("PLAYER_PROMPT", "")
    scripted = getEnv("PLAYER_SCRIPTED", "arcader")

  proc dial(attempts: int): WebSocket =
    ## Bounded dialling: the game bakes render caches before opening its
    ## listener, so the first dial usually lands on a closed port.
    for attempt in 0 ..< attempts:
      try:
        return newWebSocket(url)
      except CatchableError:
        if attempt == 0:
          echo "emelya_jr: game not listening yet, retrying"
        sleep(connectRetryMs)
    nil

  var socket = dial(connectAttempts)
  if socket == nil:
    quit("emelya_jr: game never accepted a connection", 1)
  echo "emelya_jr: connected"

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
      echo "emelya_jr: socket closed (", getCurrentExceptionMsg(), ")"
    if sessionFrames == 0 or reconnects >= reconnectAttempts:
      break
    inc reconnects
    echo "emelya_jr: re-dialling the seat (attempt ", reconnects, ")"
    socket = dial(reconnectAttempts)
    if socket == nil:
      echo "emelya_jr: game is no longer listening, exiting cleanly"
      break
    echo "emelya_jr: reconnected, re-registering"
  quit(0)

main()
