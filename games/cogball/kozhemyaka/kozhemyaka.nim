## Nikita Kozhemyaka — Cogball policy for Andre von Auto.
## Cogball's player seat is thin, but its wire protocol is NOT the JSON
## text protocol most cogame seats speak: it is the Sprite v1 binary
## stream (docs/protocol.md). Registration is ONE sprite chat packet
## (0x81, u16 little-endian length, raw payload) carrying a JSON
## register frame; after that the seat only listens, answering each
## binary tick frame with a sprite Ready packet (0x85) so fastMode can
## pace the match by readiness. The game container runs the coach;
## an empty prompt plus scripted=formation IS the default strategy.
##
## Env:
##   PLAYER_PROMPT   field an LLM seat with this operator prompt
##   PLAYER_SCRIPTED play a scripted baseline (formation | swarm)
## Default (neither set): scripted `formation`. Upload note: league LLM
## seats need --secret-env USE_BEDROCK=true or the seat plays formation.

import std/[json, options, os], whisky

proc chatPacket(payload: string): string =
  ## One Sprite v1 client chat packet: 0x81, u16 LE length, raw bytes.
  result = newString(3 + payload.len)
  result[0] = char(0x81)
  result[1] = char(payload.len and 0xff)
  result[2] = char((payload.len shr 8) and 0xff)
  for i in 0 ..< payload.len:
    result[3 + i] = payload[i]

proc readyPacket(): string =
  ## One Sprite v1 client Ready packet: 0x85.
  result = newString(1)
  result[0] = char(0x85)

proc main() =
  let
    scriptedEnv = getEnv("PLAYER_SCRIPTED", "")
    promptEnv = getEnv("PLAYER_PROMPT", "")
    # PLAYER_SCRIPTED wins if set; else PLAYER_PROMPT fields an LLM seat;
    # else the measured formation baseline (empty prompt is pkScripted).
    scripted =
      if scriptedEnv != "": scriptedEnv
      elif promptEnv != "": ""
      else: "formation"
    prompt =
      if scripted != "": ""
      else: promptEnv
    register = $ %*{"type": "register", "prompt": prompt,
                    "scripted": scripted, "policy": "Nikita Kozhemyaka"}
    url = getEnv("COWORLD_PLAYER_WS_URL")
  if url == "":
    quit("kozhemyaka: COWORLD_PLAYER_WS_URL is not set", 1)
  echo "kozhemyaka: connecting to ", url
  let ws = newWebSocket(url)
  # Send immediately on connect, and once more after the first received
  # frame: the re-send guards the slot-registration race.
  ws.send(chatPacket(register), BinaryMessage)
  var resent = false
  while true:
    var received: Option[Message]
    try:
      received = ws.receiveMessage()
    except CatchableError:
      # The server closes the socket at game over; that is the exit.
      echo "kozhemyaka: websocket closed (", getCurrentExceptionMsg(), ")"
      break
    if received.isNone:
      continue
    let message = received.get()
    if message.kind == Ping:
      ws.send(message.data, Pong)
      continue
    if message.kind != BinaryMessage:
      continue
    if not resent:
      ws.send(chatPacket(register), BinaryMessage)
      resent = true
      echo "kozhemyaka: registered (",
        (if prompt.len > 0: $prompt.len & " rune prompt"
         else: "scripted " & scripted), ")"
    # A seat sends no inputs; Ready after each frame paces fastMode.
    ws.send(readyPacket(), BinaryMessage)
  quit(0)

main()
