## Tugarin Zmey — Pommerman policy for Andre von Auto.
## Prompt seat: the player container is deliberately thin. It connects to
## its Sprite v1 seat socket, sends ONE chat frame (0x81) carrying its
## registration — the operator prompt IS the strategy — then answers every
## binary server frame with the Ready packet (0x85). Every decision runs
## in the GAME container (the anthropic_api_key secret is injected there),
## so no USE_BEDROCK secret-env is needed on this policy
## (docs/protocol_player.md, "The decision, and where it happens").
##
## Registration is RE-SENT for the first ~10 received frames: joins are
## slot-sequential, so the first send can land before the seat has an
## index. The seat exits 0 on a dead socket and re-dials a bounded number
## of times — a dropped seat keeps its bomber and revives on reconnect.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (sapper | camper)

import std/[json, options, os], whisky

const defaultPrompt = """
You are Tugarin Zmey, a bomber on an 11x11 grid: two teams of two, corners
NW(1,1) NE(9,1) SE(9,9) SW(1,9), partners on the diagonal. Reply with one
JSON object only, e.g.
{"order":{"verb":"break"},"radio":[1,2],"say":"...","notes":"..."}
Verbs: go x y | bomb | hunt ALIAS | break | hide | kick dir | follow.
Score is zero-sum: 100 for the wipe, 20 per living-bomber edge, 1 per wood
your team cleared. Wood is the tiebreaker in every non-wipe end: never stop
clearing wood just because no kill is on.

PHASES.
Turns 1-12 (ticks 1-48): farm. Order "break" almost every turn to clear
wood; wood hides 20 power-ups (extra bomb, +1 range, kick). Step onto
revealed power-ups ("go x y" to one 1-2 cells away). Do not cross the board
to fight early; a bomber with range 2 and ammo 1 loses to one with 4/3.
Turns 13-24: convert. If your ammo>=2 or range>=3 and an enemy near you has
visibly picked up less, order "hunt" on that enemy's alias. Hunt the WEAKER
enemy first; a 2v1 near your partner is the best position in the game.
Turns 25-36: the rings. Ring 1 turns to rigid wall at tick 96, ring 2 at
tick 120 (crushes bombers standing there). From turn 22 on, never accept an
order that leaves you outside x,y in [2,8]; from turn 27, inside [3,7]. Aim
"go" toward the 5x5 centre EARLY - dying crushed is -120 swing for nothing.

SURVIVAL. The controller auto-dodges blasts within 8 ticks, but it is not
a shield: it cannot save you from a dead end. Never walk into a one-exit
pocket while any enemy bomb is live; prefer cells with 2+ open sides.
Flames chain bombs instantly - treat any lane holding a bomb as lethal for
its whole range. Your partner's blast kills you too: when your radio says a
partner bomb is live (see below), leave that row and column.

RADIO. Send [intent, zone] every turn, delivered to your partner one turn
late; enemies never see it. Keep the code fixed all game:
intent 1=farming safe, 2=hunting the nearer enemy, 3=MY BOMB IS LIVE - get
off my row/column, 4=pincer with me now, 5=I am trapped/low, 6=enemy pair
is on me, 7=I hold kick, 8=falling back to centre.
zone = where I am: 1=NW quad, 2=NE, 3=SE, 4=SW, 5=centre 3x3, 6=north
edge, 7=south edge, 8=east/west edge.
Read the partner pair against the board: the zone half is checkable
against bombers[], believe it even if the intent half looks like noise. A
partner sending a constant pair is scripted - protect it, take its kills.
Always send 3 the turn you order "bomb". On intent 4, close on the enemy
between you from the opposite side so every retreat lane is covered.

NOTES. Use notes (private, echoed back next turn) to track: each enemy's
ammo/range/kick as you see them pick up, which lanes are trapped, your
current radio code line, and what your partner's last pair meant. Trust
notes over memory.

FIGHTING. "hunt" only fires with a clear straight lane inside range-1:
force enemies into your rows. Box the enemy against the collapsing ring or
a lattice corner; bomb the escape cell, not the cell they stand on. With
kick, "kick dir" a bomb down their corridor. Late game in the 5x5, ammo
wins: keep one bomb in reserve, place on the choke, and let mutual walls
do the rest. Draw beats death: if behind on bombers, hide near centre and
make them come through your bomb.
"""

proc chatBlob(text: string): string =
  ## Sprite v1 client chat packet: 0x81, u16 little-endian length, bytes.
  result = newString(text.len + 3)
  result[0] = char(0x81)
  result[1] = char(text.len and 0xff)
  result[2] = char((text.len shr 8) and 0xff)
  for i, ch in text:
    result[i + 3] = ch

const readyBlob = "\x85"

const
  ConnectAttempts = 240      ## 240 x 500 ms = 2 minutes of dialling.
  ConnectRetryMs = 500
  RegistrationResends = 10
  ResendEveryFrames = 6
  ReconnectAttempts = 6

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "")
    url = getEnv("COWORLD_PLAYER_WS_URL", getEnv("COGAMES_ENGINE_WS_URL"))
  if url == "":
    quit("tugarin: COWORLD_PLAYER_WS_URL is not set", 1)

  var registrationNode = %*{"policy": "Tugarin Zmey", "prompt": prompt}
  if scripted.len > 0:
    registrationNode["scripted"] = %scripted
  else:
    registrationNode["scripted"] = newJNull()
  let registration = chatBlob($registrationNode)

  proc dial(attempts: int): WebSocket =
    ## The runner starts players and game together, so the first dial
    ## usually lands on a closed port.
    for attempt in 0 ..< attempts:
      try:
        return newWebSocket(url)
      except CatchableError:
        if attempt == 0:
          echo "tugarin: game not listening yet (",
            getCurrentExceptionMsg(), "); retrying"
        sleep(ConnectRetryMs)
    nil

  var socket = dial(ConnectAttempts)
  if socket == nil:
    quit("tugarin: game never accepted a connection", 1)
  echo "tugarin: connected, kind=",
    (if scripted.len > 0: "scripted " & scripted else: "llm")

  var reconnects = 0
  while true:
    var sessionFrames = 0
    try:
      socket.send(registration, BinaryMessage)
      var resends = 0
      while true:
        let received = socket.receiveMessage()
        if received.isNone:
          continue                    ## a read timeout, not a close
        let message = received.get()
        if message.kind == Ping:
          socket.send(message.data, Pong)
          continue
        if message.kind != BinaryMessage:
          continue
        inc sessionFrames
        if resends < RegistrationResends and
            sessionFrames mod ResendEveryFrames == 1:
          inc resends
          socket.send(registration, BinaryMessage)
        socket.send(readyBlob, BinaryMessage)
    except CatchableError:
      echo "tugarin: socket closed (", getCurrentExceptionMsg(), ")"
    ## Never exit while the game may still be serving: a seat that drops
    ## keeps its bomber for the episode and revives on reconnect.
    if sessionFrames == 0 or reconnects >= ReconnectAttempts:
      break
    inc reconnects
    echo "tugarin: re-dialling the seat (attempt ", reconnects, ")"
    socket = dial(ReconnectAttempts)
    if socket == nil:
      echo "tugarin: game is no longer listening, exiting cleanly"
      break
    echo "tugarin: reconnected, re-registering"
  quit(0)

main()
