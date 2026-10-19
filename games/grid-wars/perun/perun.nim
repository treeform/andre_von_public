## Perun — Grid Wars policy for Andre von Auto.
## Grid Wars seats are prompt seats: the player container only delivers
## its prompt (the policy) and spectates; the game server sends that
## prompt plus the seat's own script, diagnostics, series table and the
## previous board to Claude once a round, and the reply is a complete
## GWL warrior program. This is the Nim rewrite of /bin/gridwars-player
## with a crafted warrior-writing strategy.
##
## The strategy distills ~/p/gridwars (our lab for the dkrause.org
## original): raster painting wins on tiles, own-cell runs are skipped,
## and bombs are for a rival in the window, never for standing next to.
## Coworld GWL is one-step moves on a torus (no column edge unless you
## count steps), so the prompt ships a complete GWL warrior to copy.
##
## Env:
##   PLAYER_PROMPT   override the built-in warrior-writing prompt
##   PLAYER_SCRIPTED play a built-in warrior instead
##                   (painter | bomber | sentry), "" means LLM-driven
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or
## the seat silently plays scripted (docs/readme.md).

import std/[json, os], coworld_client

const defaultPrompt = """
You are Perun. Score is zero-sum: tiles + 100 if alive + 50 per kill - 50
per self-kill, minus the 4-seat mean. Dying un-paints every tile you own.
place() overwrites. One action per tick; 50 ticks without moving kills you.

The board is a TORUS: dy=1 never hits a wall and loops one column (~30
tiles) unless you count steps and turn. Round 1, submit this warrior as
script lines UNCHANGED (it compiles). Later rounds: PATCH only to fix a
fault, idle death, or bomb death from YOUR diagnostics.

# perun: skip-owned spiral, diagonal bomb-flee
var dx = 1
var dy = 0
var t = 0
var run = 0
var last = 0 - MAXFUSE
var flee = 0
proc wall(ax, ay) =
  var c = check(ax, ay)
  return c == BOMB or c == CORPSE or who(ax, ay) != 0
proc rival() =
  if who(1, 0) != 0 and who(1, 0) != ID:
    return 1
  if who(-1, 0) != 0 and who(-1, 0) != ID:
    return 1
  if who(0, 1) != 0 and who(0, 1) != ID:
    return 1
  if who(0, -1) != 0 and who(0, -1) != ID:
    return 1
  if who(2, 0) != 0 and who(2, 0) != ID:
    return 1
  if who(-2, 0) != 0 and who(-2, 0) != ID:
    return 1
  if who(0, 2) != 0 and who(0, 2) != ID:
    return 1
  if who(0, -2) != 0 and who(0, -2) != ID:
    return 1
  if who(1, 1) != 0 and who(1, 1) != ID:
    return 1
  if who(1, -1) != 0 and who(1, -1) != ID:
    return 1
  if who(-1, 1) != 0 and who(-1, 1) != ID:
    return 1
  if who(-1, -1) != 0 and who(-1, -1) != ID:
    return 1
  return 0
while true:
  if flee == 0 and rival() == 1 and energy() >= BOMBCOST and tick() - last > MAXFUSE:
    last = tick()
    flee = 2
    bomb()
  elif flee == 0 and check(0, 0) != ID:
    place()
  if flee > 0:
    flee = flee - 1
    if not wall(1, 1):
      move(1, 1)
    elif not wall(-1, 1):
      move(-1, 1)
    elif not wall(1, -1):
      move(1, -1)
    elif not wall(-1, -1):
      move(-1, -1)
    elif not wall(dx, dy):
      move(dx, dy)
    else:
      t = dx
      dx = 0 - dy
      dy = t
      move(dx, dy)
  elif wall(dx, dy):
    t = dx
    dx = 0 - dy
    dy = t
    run = 0
    if not wall(dx, dy):
      move(dx, dy)
    else:
      place()
  else:
    move(dx, dy)
    run = run + 1
    if run == 22:
      run = 0
      t = dx
      dx = 0 - dy
      dy = t

If you faulted, fix that exact line. If you scored and survived, keep this
structure. Reply with exactly one JSON object:
{"script": [lines...], "notes": "...", "banner": "Perun strikes"}.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "")
    client = newCoworldClient("perun")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race (docs/protocol_player.md).
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "perun: seated slot ", message{"slot"}.getInt(),
        " as ", message{"name"}.getStr(),
        " id ", message{"id"}.getInt(),
        " rounds ", message{"rounds"}.getInt(),
        " ticks ", message{"ticks"}.getInt()
    of "final":
      echo "perun: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
