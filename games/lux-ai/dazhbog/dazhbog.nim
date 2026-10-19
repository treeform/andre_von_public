## Dazhbog — lux-ai policy for Andre von Auto.
## The lux-ai seat is deliberately thin: it speaks the bitworld sprite
## protocol, sends ONE Sprite v1 chat frame (0x81) carrying its
## registration - policy label, operator prompt, scripted kind - and
## re-sends it over the first seconds of received frames because joins
## are slot-sequential. fastMode is on: the seat sends NO inputs, only
## the Sprite v1 Ready packet (0x85) after each received frame. The LLM
## call happens in the GAME container, so the prompt IS the strategy
## and no Bedrock flag is needed on upload (docs/protocol_player.md).
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead
##                   ("forester" | "prospector")

import std/[json, options, os, times], whisky

const defaultPrompt = """
You are Dazhbog, the sun god: you make sure your cities see every dawn.
Most city tiles standing at turn 360 wins. The night bill decides
games: each city pays 23 x tiles - 5 x touching pairs EVERY night turn,
ten a night, and a city that cannot pay dies whole, that instant.

Every directive, read these BEFORE anything else, in order:
1. city_list: any city with survives_tonight false or turns_of_fuel
   under 2? Then stance "fuel", night "haul", build "auto" - fix the
   bill before any ambition.
2. Otherwise play the opening/standing plan below.

Opening (turns 0-60): {"stance":"expand","mine":["wood","coal",
"uranium"],"research":"coal","build":"auto","workers":6,"carts":0,
"focus":<empty cell orthogonally adjacent to your largest city>,
"night":"shelter"}. Wood is the engine: 20/turn per worker, it regrows,
and it plants tiles.

Compactness is the whole midgame: ALWAYS set focus adjacent to your
largest city so every new tile touches the blob. Nine tiles in a 3x3
pay 147 a night-turn; nine scattered pay 207. Never expand into a
detached island.

Research: the micro builds workers/carts FIRST whenever you are under
the unit cap and below those targets; leftover tile actions research.
So research "coal" from turn 0 is free on idle tiles - it does not
cost workers. Stay on "coal" until yours.research >= 50 (or
resources.coal.researched), then "none". Go for uranium ONLY if by
turn 240 you already have 120+ points and a uranium cluster on your
half; otherwise never - 200 points is six cycles of tiles doing
nothing.

Workers: keep workers at about city tiles + 2, capped at 8. One cart
once you mine coal at range, else 0.

Standing triggers:
- Behind on cityTiles after turn 180: stance "contest", focus the
  richest resource cluster nearest the opponent, and keep research
  running - out-fuel what you cannot out-build.
- Ahead after turn 280: stance "fuel", night "haul", build "auto",
  research "none". Bank fuel so every tile survives nights 8 and 9;
  a tile lost at turn 350 is the game.
- Wood tiles on your half depleting (tiles_left falling fast): drop
  workers by 2 and switch mine order to put coal first if researched.
- Turn 340+: stance "turtle", everything home, pay the last bills.

Each reply is ONE JSON strategy object with stance, mine, research,
build, workers, carts, focus, night, note. Keep note under 160 chars.
Never leave a city one night short to buy a tile you cannot feed.
"""

const
  SpriteClientChat = 0x81'u8
  SpriteClientReady = 0x85'u8
  ## Keep re-sending the registration this long after connect: joins
  ## are slot-sequential and an early frame can land pre-admission.
  RegisterWindowSeconds = 10.0

proc chatBlob(text: string): string =
  ## One Sprite v1 chat frame: 0x81, u16 little-endian length, bytes.
  result = newString(3 + text.len)
  result[0] = char(SpriteClientChat)
  result[1] = char(text.len and 0xff)
  result[2] = char((text.len shr 8) and 0xff)
  for i, ch in text:
    result[3 + i] = ch

proc readyBlob(): string =
  ## One Sprite v1 client-ready frame.
  result = newString(1)
  result[0] = char(SpriteClientReady)

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "")
    url = getEnv("COWORLD_PLAYER_WS_URL")
  if url == "":
    quit("dazhbog: COWORLD_PLAYER_WS_URL is not set", 1)
  echo "dazhbog: connecting to ", url
  let ws = newWebSocket(url)
  let registration = %*{
    "type": "register",
    "policy": "Dazhbog",
    "prompt": if scripted == "": prompt else: "",
    "scripted": if scripted == "": newJNull() else: %scripted
  }
  let registrationBlob = chatBlob($registration)
  ws.send(registrationBlob, BinaryMessage)
  let connectedAt = epochTime()
  while true:
    var received: Option[Message]
    try:
      received = ws.receiveMessage()
    except CatchableError:
      # The game's own quit can outrun the final frame; a closed socket
      # after registration is a normal episode end for a fastMode seat.
      echo "dazhbog: websocket closed (", getCurrentExceptionMsg(), ")"
      quit(0)
    if received.isNone:
      continue
    let message = received.get()
    if message.kind == Ping:
      ws.send(message.data, Pong)
      continue
    # Re-send registration on early frames to beat the admission race,
    # then acknowledge every received frame with Ready.
    if epochTime() - connectedAt < RegisterWindowSeconds:
      ws.send(registrationBlob, BinaryMessage)
    ws.send(readyBlob(), BinaryMessage)

main()
