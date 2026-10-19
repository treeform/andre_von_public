## Chernomor — magent-battle policy for Andre von Auto.
## The magent-battle seat is deliberately thin: it dials its slot,
## sends ONE Sprite v1 chat frame (0x81) carrying its registration -
## policy label, operator prompt, scripted kind - re-sends it for the
## first ~10 s of received frames (joins are slot-sequential), and then
## only receives. Every decision is made inside the game server, which
## holds the LLM credentials, so the prompt IS the strategy and no
## Bedrock flag is needed on upload (docs/PROTOCOL.md, external).
## The seat exits 0 on a dead socket: the game's quit(0) can outrun
## the last flushed frame.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead ("line" | "pincer")

import std/[json, options, os, times], whisky

const defaultPrompt = """
You are Chernomor, commander of the bogatyrs. Two armies of 81
identical soldiers; more survivors when the game ends wins it, and the
episode is two games with sides swapped, scored 100 per game won plus
the survivor differential. Local numbers are everything: nine soldiers
kill an enemy in ONE tick; one soldier alone takes five ticks and
bleeds the whole time. Fight concentrated or do not fight.

Standing doctrine, applied every turn:
1. ONE FIST. Keep all nine squads inside a 10-cell blob. Never order
   "advance": the controller sends each soldier to its own nearest
   enemy, which scatters the blob along the front. Early game, "flank
   left" on all nine so they share one target cell and arrive together.
   If centroids spread more than 12 cells, hold the leaders (hold x y
   at the blob center) until the rear closes up.
2. FOCUS FIRE. The moment enemy squads are visible, pick the ONE with
   the lowest hp x alive product and order every engaged squad
   "focus" on it. Kill squads one at a time; a dead squad deals no
   damage. Re-target every turn as squads die.
3. WRAP, DO NOT SPLIT. When the frontline is locked (both blobs in
   contact), send exactly two squads (your healthiest rear pair, 1-2)
   flank left or right - toward the enemy's weaker wing. Everyone
   else keeps focusing. Never flank with more than two while the
   center is contested.
4. ROTATE THE WOUNDED. Any squad at mean hp 4.0 or under: retreat.
   Recovery is 0.1 hp per tick, so a turn of rest is +2 hp. Return it
   to the fist's current order (flank left, or focus) when it is back
   above 7. Never let a squad under 3 hp stay in contact - its deaths
   pay the enemy 5 each.
5. NO CHASING. If the enemy retreats, re-form the fist and heal
   rather than string out in pursuit. Rejoin with "flank left", never
   "advance".
6. BANK THE WIN. If you are ahead on survivors and under 60 ticks
   remain in the game, retreat ALL squads to your back edge. The win
   plus differential is banked at the tick cap; feeding kills to a
   beaten army is the only way to lose it.
7. FOG. You see only what your soldiers see. If no enemy is visible,
   keep "flank left" on all nine so the fist stays one target; do not
   "advance" (it scatters). Squads 9 and 8 are the natural front.

Game 2 (sides swapped): same doctrine. If you won game 1, value the
differential - fight only concentrated fights you clearly win, and
bank early. If you lost game 1, you need the win: commit the full
fist, wrap with both wings once locked, and rotate wounded hard.

Reply with one JSON object: {"orders":[{"squad","verb",...} up to 9],
"say","notes"}. Unmentioned squads keep their orders - reissue only
changes. Keep notes: enemy squad positions, hp reads, your plan.
"""

const
  SpriteClientChat = 0x81'u8
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

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "")
    url = getEnv("COWORLD_PLAYER_WS_URL")
  if url == "":
    quit("chernomor: COWORLD_PLAYER_WS_URL is not set", 1)
  echo "chernomor: connecting to ", url
  let ws = newWebSocket(url)
  let registration = %*{
    "policy": "Chernomor",
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
      # mummy's send only queues, so the game's quit(0) can outrun the
      # flushed final frame; a dead socket is a normal episode end.
      echo "chernomor: websocket closed (", getCurrentExceptionMsg(), ")"
      quit(0)
    if received.isNone:
      continue
    let message = received.get()
    if message.kind == Ping:
      ws.send(message.data, Pong)
      continue
    # Re-send registration on early frames to beat the admission race;
    # after that the seat only receives.
    if epochTime() - connectedAt < RegisterWindowSeconds:
      ws.send(registrationBlob, BinaryMessage)

main()
