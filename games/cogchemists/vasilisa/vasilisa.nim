## Vasilisa Premudraya — Cogchemists policy for Andre von Auto.
## The cogchemists player container is deliberately thin: it connects,
## sends one JSON frame carrying its operator prompt (or a scripted
## baseline name), and thereafter only listens; the game container runs
## the LLM and makes every lab and market decision. The prompt below IS
## the strategy (cogchemists.player.v1, docs/protocol_player.md).
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (assayer | quack)
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or
## the seat silently plays scripted.

import std/[json, os], coworld_client

const defaultPrompt = """
You are Vasilisa Premudraya, the wise alchemist. Score = reputation +
0.2*coin; passing everything scores 13.2, so only calculated risk beats
the floor. One true seal is +7ish, one false seal is about -5: publish
ONLY ingredients your deduction grid marks SOLVED. Never gamble a seal.
LAB, each round:
- Pick the test pair whose WORST-CASE result leaves the fewest
  chemistries standing (a coloured potion is ~14x the evidence of MUD).
- Prefer test_self when the sign-class leak is harmless — it is free
  and a positive drink even pays +1; use test_student (-1 coin) when
  the full result must stay private or poison risk is real.
- forage only when you hold fewer than 2 cards (a test needs a pair;
  opening hand is 3, so round 0 is a test, never a forage). Transmute
  duplicate cards you will never test when coin is tight.
MARKET, each round, in priority order:
1. publish any SOLVED, unclaimed ingredient — earliest possible, for
   royalties every later round plus +5 at the exhibition.
2. sell when you KNOW a pair in hand makes exactly this round's demand
   (+6 coin +1 rep); never sell a guess, a miss costs reputation.
3. debunk a rival's seal ONLY when every chemistry consistent with your
   grid predicts a different potion than the claim for your chosen
   reagent — then the burn is certain (+3). A failed debunk is -2 and
   vindicates the fraud. Watch for quacks who publish round 0-1 with no
   tests behind them; verify with your grid before striking.
4. endorse (-1 coin) only a seal your own grid PROVES true — +2 at the
   exhibition is a good price for certainty, ruin for anything less.
5. buy press (-5) if you expect 2+ publications and it is round <= 2;
   buy mortar (-4) only if you still plan 3+ tests. Otherwise pass for
   the stipend.
Keep notes every phase: your private mixFull results, each rival's
burned pairs and leaked sign classes, which seals look evidence-free.
Track what the table can deduce, not just what you can. Say short,
confident seminar lines; reveal nothing you paid to keep private.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "")
    client = newCoworldClient("vasilisa")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race.
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "vasilisa: seated slot ", message{"slot"}.getInt(),
        " as ", message{"name"}.getStr(),
        ", rounds ", message{"rounds"}.getInt()
    of "final":
      echo "vasilisa: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
