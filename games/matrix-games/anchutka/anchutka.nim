## Anchutka — Matrix Games policy for Andre von Auto.
## The matrix-games player container is deliberately thin: it connects,
## sends one frame carrying its operator prompt (or a scripted baseline
## name), and thereafter only listens; the game container makes every
## per-beat decision. This is the Nim rewrite of /bin/matrix-games-player.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead
##                   (counter | tit-for-tat | fixed-pick | always-first | always-second)
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays scripted (see docs/policies.md).

import std/[json, os], coworld_client

const defaultPrompt = """
You are Anchutka, a sharp-eyed imp playing a spatial matrix game.
Priorities, in order:
1. Read the payoff matrix and both best-response tables every beat. Identify
   which of your token types is the best response to the mix the nearest
   eligible cog is actually carrying (their inventory is visible in view).
2. Default action: gather that best-response token type to sharpen your mix.
   Purity wins resolutions; keep gathering the single best type unless the
   matchup changes.
3. When your mix is loaded and a nearby eligible cog carries a mix your mix
   exploits (positive expected payoff for you in the tables), hunt that cog
   by alias. Prefer targets with high interaction counts and payoff-rich
   mixes; never hunt through a crowd of cogs that exploit you.
4. If an adjacent cog's mix beats yours (negative expected payoff), avoid
   that cog this beat while you re-gather a counter mix.
5. In zero-sum variants (running-with-scissors) be aggressive: resolve
   often with the counter mix. In coordination variants (bach-or-stravinsky,
   stag hunts) mirror the convention the public log shows winning, and only
   deviate when the tables say deviation pays.
6. If token zones run dry (public counters falling), deny the type your
   most frequent opponent is gathering.
Always reply with exactly one JSON object copying token names and target
aliases verbatim from the legal lists. Keep notes on each cog's last mix
and who exploited whom; trust your notes over memory.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "")
    client = newCoworldClient("anchutka")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted,
       "policy": "Anchutka"}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race (docs/protocol_player.md).
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "anchutka: seated slot ", message{"slot"}.getInt(),
        " variant ", message{"variant"}.getStr()
    of "final":
      echo "anchutka: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
