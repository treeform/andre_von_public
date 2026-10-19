## Ognevushka — Hanabi policy for Andre von Auto.
## The hanabi player container is deliberately thin: it connects, sends one
## frame carrying its operator prompt (or a scripted baseline name) right
## after connecting and again after welcome, then only listens until final;
## the game server makes every per-turn decision (docs/protocol_player.md).
##
## Default is the published `conventions` baseline, not the LLM prompt:
## field leaders are `co-gas-hanabi-conventions-*`, the docs say a prompt
## that cannot beat conventions is not yet a policy, and decideAll plays
## scripted whenever scripted != none (prompt is ignored). Score is the
## team stack total; LLM seats gamble on "play signals" that conventions
## partners actually use as chop-saves, burn fuses, and can deadline the
## 60% play budget. Empty PLAYER_SCRIPTED restores the LLM path.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED conventions (default) | cautious | empty for the prompt
## Upload note: default is scripted, so no Bedrock flag is required.
## League LLM seats need --secret-env USE_BEDROCK=true.

import std/[json, os, strutils], coworld_client

const defaultPrompt = """
You are Ognevushka, a fire sprite playing four-seat Hanabi. The score is the
TEAM's stack total, 0-25; you win or lose together. Fuses are the team's
life: three misplays score whatever is banked and stop.
Each turn, apply the first rule that fits:
1. Play the lowest-numbered knownPlayable slot. These can never misplay.
2. Read fresh hints as intent, not just information: a hint that touched
   exactly ONE of your cards - especially your newest slot - is usually a
   play signal. If its candidate set is consistent with the next needed
   rank on some stack and most candidates are playable, play it, but only
   while 0 or 1 fuse is burnt. With 2 fuses burnt, gamble on nothing.
3. Save criticals: if the NEXT seat's chop card is critical (last copy
   still in play) and they show no sign of knowing it, hint that card's
   RANK now. Losing a critical caps the whole game.
4. Otherwise give the hint that makes the most cards in a partner's hand
   newly knownPlayable, preferring the seat acting soonest; prefer rank
   over colour, lower value, lower seat. A hint that makes nothing
   playable and saves nothing is a wasted token - do not give it.
5. Otherwise discard: a knownDead slot if you have one, else your chop.
   Never discard a slot whose candidates are all critical.
6. Token economy: under 2 tokens, bias toward discarding; at 7-8 tokens,
   bias toward hinting. Discarding at 8 tokens is illegal - then give the
   legal hint touching the fewest cards of the next seat.
7. Endgame: when the deck is under 5 or the countdown is armed, count what
   is still reachable. Holding a card a stack needs? Play it over
   discarding even at moderate risk (majority-playable candidates, fuses
   permitting). A turn that neither plays nor sets up a play is a turn
   the countdown eats.
8. note: every turn record what each of your slots must be (from hints,
   negative information and the discard pile), what your last hint to each
   partner was meant to say, and which partner is set up to play. Trust
   your note over re-deriving.
Reply with exactly one JSON object copied verbatim from LEGAL MOVES, plus
your note.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "conventions").strip()
    client = newCoworldClient("ognevushka")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Sent right after connecting and again after welcome: the re-send guards
  # the slot-registration race (docs/protocol_player.md).
  client.send(helloFrame())
  echo "ognevushka: scripted=", (if scripted.len > 0: scripted else: "llm")
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "ognevushka: seated slot ", message{"slot"}.getInt(),
        " as ", message{"name"}.getStr(),
        " scripted ", (if scripted.len > 0: scripted else: "llm")
    of "final":
      echo "ognevushka: final, team score ", message{"score"}.getInt(),
        " (", message{"endReason"}.getStr(), ")"
      quit(0)
    else:
      discard

main()
