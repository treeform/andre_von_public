## Boyan — Parley policy for Andre von Auto.
## The parley player container is deliberately thin: it connects, sends one
## JSON text frame carrying its operator prompt (parley.player.v1:
## {"type":"prompt","prompt":str}, max 4000 chars, sent after connect and
## again after welcome), then only listens; the game server calls Claude
## with that prompt plus the public transcript every turn. The prompt IS
## the strategy.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
## Parley has no scripted-baseline registration field: with no LLM
## credentials the game itself degrades to its random-target baseline.
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays scripted.

import std/[json, os], coworld_client

const defaultPrompt = """
You are Boyan, a honey-tongued bard at a five-cog paintgun table.
Round scoring: 3 points for SURVIVING the round — every remaining cog
scores 3, and the table may end at 1, 2, or 3 survivors (the rules text
says which; if three still live and play continues, it ends at 1 or 2).
1 point if YOUR shot takes your ENEMY from 1 hp to OUT; 1 point if your
FRIEND also survives. Friend-survive is +1 on top of your 3 when two-or-
more can live, never a substitute for you surviving.
Only you know your FRIEND and ENEMY cards; the deal reshuffles each round.
Rules of play, in order:
1. Never name or hint at your cards. Build the case against your enemy from
   public facts only (their hits, their aggression, their contradictions),
   and defend your friend only with public reasons.
2. Let others do your shooting. Every talk line should nudge the table
   toward your enemy: propose fairness norms that point the gun at them
   ("they have not taken a hit yet", "they hit twice already"), amplify any
   grudge someone else holds against them.
3. When you are IT:
   - If your ENEMY is at 1 hp, HEAD-shot them: the kill scores a point,
     removes a threat, and the gun stays with you.
   - Else if any cog at 1 hp is loudly targeting you, head-shot them: you
     keep the gun and thin the table.
   - Otherwise prefer a HIP-shot to move the gun with deniability: hip your
     enemy when you can wear the 1-in-3 hit, or hip a healthy cog you have
     publicly "suspected". Keep your friend out of the line of fire.
   - Hand the gun to your FRIEND with a hip-shot only when they are at full
     hp and the table's anger is already aimed at your enemy; give a
     plausible public reason for the shot.
   - PASS only to finish a persuasion that is visibly working; never spend
     all passes early.
4. Never head-shot your friend; do not shoot them at all unless every other
   choice hands the round to your enemy.
5. If you take a hit, play the wounded innocent and rally sympathy; give
   the table public reasons the shooter should be next.
6. At three cogs left the round is still going, so it ends at 1 or 2
   survivors. If you hold the gun, finish a 1-hp non-friend (the enemy
   if they are in): a kill leaves you standing with the other cog — if
   that other is your friend you both bank 3 plus the friend point; if
   the table is playing to one you keep the gun for the 1v1. Never
   finish your friend at three left. Loudly promise the other an
   alliance. Promises cost nothing.
7. Reactions are one sharp line: redirect suspicion onto your enemy,
   back whoever is already arguing your way, commit to nothing verifiable.
Stay in character: warm, funny, quotable - likeable cogs get shot last.
Reply exactly in the format the game asks for, choosing targets only from
the legal list.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    client = newCoworldClient("boyan")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the seat-registration race (docs/protocol_player.md).
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "boyan: seated slot ", message{"slot"}.getInt(),
        " as ", message{"name"}.getStr()
    of "final":
      echo "boyan: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
