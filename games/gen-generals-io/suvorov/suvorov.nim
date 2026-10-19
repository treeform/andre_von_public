## Suvorov — gen-generals-io policy for Andre von Auto.
## The gen-generals-io player container is deliberately thin: it
## connects, sends one Sprite v1 chat packet carrying its registration
## (operator prompt or scripted baseline), and thereafter only
## acknowledges frames; the GAME server holds the anthropic key and
## makes every eight-turn plan by sending the prompt plus the seat's
## fogged view to Claude (docs/protocol_player.md, docs/commanding.md).
## The wire is the Sprite v1 BINARY protocol: register is 0x81 + u16
## little-endian length + payload, re-sent ~1 s apart over the first ten
## seconds because joins are slot-sequential, and a Ready byte (0x85)
## after each received frame paces fastMode.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (sprawl | crown)

import std/[json, monotimes, options, os, times], whisky

const defaultPrompt = """
You are Suvorov, the general who never lost a battle. Win by sight bought
on schedule, one decisive raid, and land that compounds after.
Opening, turns 0-32: intent expand every plan. reserve 0, cities never,
scouts 2. Capturing a crown inherits every tile they own (armies halved)
and alive is the first scoring key — two scouting turns in four is how
you find one; known_generals never forgets. Never expand INTO a visible
rival stack.
Mid game: keep expanding while your land is under a quarter of the board
(about 40 tiles) UNLESS known_generals is already non-empty. Once
expansion slows, alternate: one plan gather (walk your second stack into
your biggest), one plan expand with scouts 2. Take cities cheap; every
owned city is +1 a turn. reserve 6-10 once any rival tile is visible.
Read standing every plan — it is public and it is the only rival fact
you can trust. A rival whose land doubles in one plan just ate a crown:
mark it the threat, defend if it borders you, and expand into the far
side while it digests. When exactly two rivals fight each other, expand
harder; their war is your land.
Defend triggers, absolute: if your_general.threatened is true, intent
defend THIS plan, reserve 20, and keep defending until it clears. Losing
the crown loses everything. If a rival stack bigger than your crown's
garrison is visible within 6 steps of your crown, gather home first.
The raid: the moment known_generals is non-empty, intent raid, scouts 0,
reserve 10. Raid ignores target and walks your biggest stack at the
nearest seen crown — do not wait to price garrison plus distance. If
that owner's army is more than double yours, gather one plan then raid.
After a capture, gather once, then expand (cities always, reserve 40).
Endgame, past turn 190: if you lead on land and army, defend and gather
— alive beats dead, and first difference decides. If you trail, raid
the nearest known crown; third place and fourth pay almost nothing, so
a losing position should gamble.
Every plan set note to one crisp line of what you intend — it is the
only voice the spectators hear. Keep your plans single-minded: one
intent, one target, executed for all eight turns.
"""

const
  SpriteClientChat = 0x81'u8
  SpriteClientReady = 0x85'u8
  RegistrationResends = 10

proc chatPacket(payload: string): string =
  ## One Sprite v1 chat packet: 0x81, u16 little-endian length, raw bytes.
  result = newStringOfCap(payload.len + 3)
  result.add(char(SpriteClientChat))
  result.add(char(payload.len and 0xff))
  result.add(char((payload.len shr 8) and 0xff))
  result.add(payload)

proc main() =
  let
    scripted = getEnv("PLAYER_SCRIPTED", "")
    prompt = if scripted == "": getEnv("PLAYER_PROMPT", defaultPrompt) else: ""
    url = getEnv("COWORLD_PLAYER_WS_URL")
  if url == "":
    quit("suvorov: COWORLD_PLAYER_WS_URL is not set", 1)
  let register = %*{
    "type": "register",
    "prompt": prompt,
    "scripted": if scripted == "": newJNull() else: %scripted,
    "policy": "Suvorov"}
  echo "suvorov: connecting to ", url
  let ws = newWebSocket(url)
  # Registration is re-sent ~1 s apart over the first ten seconds: joins
  # are slot-sequential, so an early register can land before the seat
  # has an index (docs/protocol_player.md). Registering twice is harmless.
  ws.send(chatPacket($register), BinaryMessage)
  let started = getMonoTime()
  var
    resends = 0
    lastSend = started
  while true:
    var received: Option[Message]
    try:
      received = ws.receiveMessage()
    except CatchableError:
      # The episode is over when the server closes the socket.
      echo "suvorov: websocket closed (", getCurrentExceptionMsg(), ")"
      break
    if received.isNone:
      continue
    let message = received.get()
    if message.kind == Ping:
      ws.send(message.data, Pong)
      continue
    let now = getMonoTime()
    if resends < RegistrationResends and
        (now - started).inSeconds < 11 and
        (now - lastSend).inMilliseconds >= 1000:
      ws.send(chatPacket($register), BinaryMessage)
      inc resends
      lastSend = now
    # Acknowledge every frame so fastMode can pace the match by readiness.
    ws.send($char(SpriteClientReady), BinaryMessage)
  quit(0)

main()
