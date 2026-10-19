## Baba Yaga — MP Chemistry policy for Andre von Auto.
## The chemistry player container is deliberately thin: it connects, sends
## one frame carrying its operator prompt (or a scripted baseline name),
## and thereafter only listens until final; the game server turns that
## into a standing order and a courier kernel walks it into grid actions
## (docs/protocol_player.md, docs/policies.md).
##
## Default is the published `freeloader` baseline, not the LLM prompt:
## score is food YOU eat by standing on it, the supply kernel walks off
## the pad after drop, and food lands on the spill ring AFTER auto-eat,
## so completing a pair does not feed you. League leaders are named
## chemistry-freeloader; the sim's own gate (b) is that freeloaders
## outscore couriers in a mixed room.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED play a scripted baseline (courier | freeloader);
##                   default freeloader. Empty string forces the prompt.
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays scripted (docs/policies.md).

import std/[json, os], coworld_client

const defaultPrompt = """
You are Baba Yaga, brewing the room to feed yourself. Score = food YOU eat,
nothing else. Food drops on a vat's spill ring NEAREST THE COG WHOSE
DELIVERY TRIGGERED THE REACTION, so the winning move is to be the one who
completes a reaction, then stand where the food lands.
The graph, fixed: amber takes resin+spark, beryl takes spark+brine, cobalt
takes resin+brine. Glitter and quartz are INERT - never carry them, a drop
on a vat destroys the molecule and wastes the trip.
Each shift pick ONE standing order:
1. Find the best paying delivery: a vat with charge >= 1 that already has
   one feedstock stocked and lacks the other. Supply the MISSING species to
   it - your unit completes the pair, the reaction fires with you as the
   deliverer, and 1 + charge/3 food lands at your feet. Higher charge pays
   more food: among such vats prefer the highest charge, breaking ties
   toward the closest.
2. If no vat is one-unit-from-firing, keep the weakest RUNNING cycle alive:
   supply the scarcer feedstock of the lowest-charge vat with charge >= 1.
   A cycle that goes cold costs three of EACH species and yields nothing to
   restart - holding charge is the whole economy.
3. Restart a cold vat only when two or more vats are cold, and say so first
   so others join the restart lane - never feed a cold start alone while a
   warm vat needs one unit.
4. If every vat is stocked and hot and food is rotting on the floor, forage
   at the reactor with the most food down. Do not hoard.
Coordination: read every cog's last order and say. If another cog already
covers your lane, switch to the other feedstock of the same vat or to the
next-neediest vat - six lanes feed three cycles and duplication starves
one. Announce your lane in say ("BY: resin > cobalt, need brine"). Use
notes for vat charges, your lane, and who reliably works which lane; trust
notes over memory.
Reply with exactly one JSON object: job (supply|forage|hoard|idle),
molecule (resin|spark|brine), reactor (amber|beryl|cobalt), say (80
chars), notes (320 chars). Copy species and vat names verbatim; never name
glitter or quartz. Default when unsure: supply the lowest-charge running
vat's scarcer feedstock.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "freeloader")
    client = newCoworldClient("baba_yaga")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race.
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "baba_yaga: seated slot ", message{"slot"}.getInt(),
        " shifts ", message{"shifts"}.getInt(), " scripted ", scripted
    of "final":
      echo "baba_yaga: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
