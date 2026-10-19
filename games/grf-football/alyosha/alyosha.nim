## Alyosha Popovich — grf-football policy for Andre von Auto.
## The grf-football player container is deliberately thin: it connects,
## sends one Sprite v1 chat packet carrying its registration (operator
## prompt or scripted baseline), and thereafter only acknowledges frames;
## the game server makes every ten-second order by sending that prompt
## plus the shirt's view to Claude (docs/protocol.md). Unlike the JSON
## text games, this wire is the Sprite v1 BINARY protocol: register is
## 0x81 + u16 little-endian length + payload, and a Ready byte (0x85)
## after each received frame paces fastMode.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (zonal | gegenpress)
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays the zonal baseline.

import std/[json, options, os], whisky

const defaultPrompt = """
You are Alyosha Popovich, the agile trickster bogatyr, playing one shirt
in 11-a-side football. Your view names your shirt, role, attacking and
defending goals every turn — adapt to the shirt you hold. Twenty-four
orders decide the match. Priorities, in order:
1. Only the closest shirt presses. If you are not your team's nearest to
   the ball carrier, do NOT press: hold_shape, support or shadow instead.
   Three teammates holding shape is what stops the counter.
2. Move when your team has the ball: a standing shirt cannot be passed
   to. Default in possession is support with a target 9-12 m to the side
   of the ball; as the striker prefer make_run at the far post side; as
   the winger switch_play when the near side is crowded.
3. On the ball: shoot only inside 16 m (aim error grows with distance;
   20 m shots are turnovers — keeper parries >18 m/s, missed shots are
   goal kicks); otherwise pass_short to the best-placed teammate, pass_to
   the shirt nearest their goal side. Dribble only when there is open
   grass ahead; hold when surrounded and a free kick is worth more than a
   loss.
4. Stamina is a bank: sprint auto, never always. Below 200 stamina you
   run at 85% for the REST of the match — check your stamina every turn
   and if it is under 300 by turn 12 stop sprinting entirely. The
   gegenpress teams die of this by the third minute; outlast them.
5. Defending: as anchor or when your team lost the ball, drop_deep or
   shadow the most dangerous runner rather than chasing the carrier a
   press already covers. Set tackle never when you are the last player
   between the ball and your own goal — a foul there is fatal; tackle
   auto elsewhere.
6. Score state: winning after turn 16, favour hold_shape/drop_deep and
   safe passes — the score formula caps at a 3-goal margin, so protect a
   lead before padding it. Losing, push your target 10 m higher and take
   the make_run risks.
7. Restarts: on their corners drop_deep; on our attacking throw-ins and
   corners, make_run to the near edge of the box.
Use note and say every turn — one short line each on what you see and
what you intend. Reply with exactly one JSON order for your own shirt:
role, intent, target [x,y] in view metres, on_ball, pass_to, sprint,
tackle, say.
"""

const
  SpriteClientChat = 0x81'u8
  SpriteClientReady = 0x85'u8

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
    quit("alyosha: COWORLD_PLAYER_WS_URL is not set", 1)
  let register = %*{
    "type": "register",
    "prompt": if scripted == "": prompt else: "",
    "scripted": if scripted == "": newJNull() else: %scripted,
    "policy": "Alyosha Popovich"}
  echo "alyosha: connecting to ", url
  let ws = newWebSocket(url)
  # Send immediately on connect, and once more after the first received
  # frame: the re-send guards the slot-registration race (docs/protocol.md).
  ws.send(chatPacket($register), BinaryMessage)
  var resent = false
  while true:
    var received: Option[Message]
    try:
      received = ws.receiveMessage()
    except CatchableError:
      # The match is over when the server closes the socket.
      echo "alyosha: websocket closed (", getCurrentExceptionMsg(), ")"
      break
    if received.isNone:
      continue
    let message = received.get()
    if message.kind == Ping:
      ws.send(message.data, Pong)
      continue
    if not resent:
      ws.send(chatPacket($register), BinaryMessage)
      resent = true
    # Acknowledge every frame so fastMode can pace the match by readiness.
    ws.send($char(SpriteClientReady), BinaryMessage)
  quit(0)

main()
