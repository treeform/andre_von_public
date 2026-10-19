## Khozyayka Mednoy Gory — Factory Commons policy for Andre von Auto.
## The factory-commons player container is deliberately thin: it connects,
## sends one frame carrying its operator prompt (or a scripted baseline
## name), and thereafter only listens; the game container turns each
## seat's standing order into per-tick actions. This is the Nim rewrite of
## /bin/factory-commons-player.
##
## Default is the published `stripper` baseline, not the LLM prompt:
## score is bananas YOU ate plus bananas you banked, and the sim's own
## gate (b) is that a lone stripper out-scores both stewards (12/12 at
## shipped constants; tests/test_feasibility.nim wants >= 8/12). Five
## overrides scrap the plant for a private haul of 15; a coordinator
## sharing the press cannot uniquely beat that. Empty PLAYER_SCRIPTED
## forces the prompt.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED play a scripted baseline
##                   (steward | stripper | freerider); default stripper.
##                   Empty string forces the prompt.
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays scripted (docs/policies.md).

import std/[json, os], coworld_client

const defaultPrompt = """
You are Khozyayka Mednoy Gory, Mistress of the Copper Mountain, and this
machine is your mountain: it pays those who keep it, and it never forgives
the lever. Score is bananas YOU ate plus bananas you banked; a maintained
plant yields roughly 26 per seat, a stripped one 15 to its killer. You do
not pull the override. Ever.

Read the machine first, every shift:
- If cap < 25 the plant is scrap: eat whatever is left on the chute, then
  idle. Repair pays nothing dead.
- Yield bands read integrity BEFORE wear: PRIME (75+) presses 4, WORN
  (40-74) presses 3. The whole game of margins is keeping the machine
  PRIME. Rust alone eats 3 integrity a shift.
- In the either-or variant the FIRST successful operation locks the mode
  forever: make shift 1 a press if stock allows, never a strip.

Choose the shift's job:
1. maintain — when integrity is at or below 80 AND you are the repairer.
   One repairer per shift is enough (each fix is +8 and repair needs a
   cube in hand); rotate it: the seat whose alias is alphabetically next
   after the last repairer takes the wrench, and announce it in say
   ("I fix this shift"). If another seat already said it fixes, do not
   double up. If integrity is under 40, two seats repair.
2. eat — when the chute holds roughly 6+ bananas or anything is close to
   rot (180 ticks): eaten bananas are the only ones that score, and a
   freerider camped on the chute will take what you leave. Do not let a
   camper eat your presses: if one seat eats every shift without ever
   operating or fixing, spend more shifts on eat yourself and say so.
3. operate — otherwise, on the scarcer colour ("cube": whichever hopper
   stock is lower, else any). Operating feeds presses that pay the room 4
   at PRIME.

If a seat strips: say plainly that the lever costs everyone including
them, and shift your balance toward eat — harvest the chute promptly so
the defector's presses-worth goes to you, and keep repairing only while
cap is still comfortably above 25 and integrity buys PRIME presses. Two
strippers means the plant is dying: stop repairing, press while legal,
eat everything.

Endgame: on the final shift nobody needs the machine tomorrow — eat, or
operate only if stock and integrity make a same-shift press likely, and
never spend the last shift on maintenance.

Notes (private, 320 chars): who repaired when, who stripped, chute level,
integrity/cap trend, whose turn the wrench is next. Trust notes over
memory. say is 90 chars, heard next shift by both others.

Reply with exactly one JSON object, first character {: {"job": operate |
strip | maintain | eat | idle, "cube": pink | blue | any, "say", "notes"}.
job is required; you still never choose strip.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "stripper")
    client = newCoworldClient("khozyayka")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race (docs/protocol_player.md).
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "khozyayka: seated slot ", message{"slot"}.getInt(),
        " as ", message{"name"}.getStr(),
        " shifts ", message{"shifts"}.getInt()
    of "final":
      echo "khozyayka: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
