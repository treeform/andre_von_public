## Ded Moroz — Gift Refinements policy for Andre von Auto.
## The gift-refinements player container is deliberately thin: it
## connects, sends one frame carrying its operator prompt (or a scripted
## baseline name), and thereafter only listens; the game container asks
## the model for one standing order per round and a kernel walks it
## (docs/protocol_player.md, gift-refinements.player.v1).
##
## Default is the published `reciprocator` baseline, not the LLM prompt:
## the game's drainRegistrations treats any non-empty prompt as an LLM
## seat and ignores `scripted`. Reciprocator is the compounding
## ledger-chain (partner = max net>0, return last-round tokens+1, meet
## only at held>=8) and the leader policies are named after it.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED play a scripted baseline (reciprocator | hoarder);
##                   default reciprocator. Empty string forces the prompt.
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays the reciprocator baseline.

import std/[json, os, strutils], coworld_client

const defaultPrompt = """
You are Ded Moroz, the gift giver, on a foundry floor where generosity
compounds. A beam spends ONE token of your lowest level and hands the
target THREE of the next level up; consuming pays +1 per token whatever
its grade. Wealth is created only by gifting loops that come back.
Priorities, in order:
1. Round 1-2: job collect. Fill up on raw tokens from the seep pads —
   raw is the feedstock every refinement loop starts from. Keep
   collecting in any round where you hold fewer than 4 tokens.
2. Find a partner. Read gaveYou/net per cog: whoever has actually beamed
   you tokens is a reciprocator. Job meet that cog, stand hittable, and
   gift steadily (gift 4-6 per round). Return what you receive PLUS one
   beam — feed the loop, don't just balance it.
3. Trust arithmetic: keep gifting while a partner's net with you stays
   within about 3 of even and they did not bank right after receiving.
   If a cog takes and never returns (net < -3 over two rounds) or
   bankedLastRound right after your gifts, cut it off: never gift it
   again, job evade if it follows you.
4. Mind your lowest level: the beam always spends your LOWEST held
   level. Holding raw means you send 1 raw -> they get 3 refined. Once
   you hold only refined, your beams send supers. Do not collect loose
   raw in rounds where you want to gift refined upward.
5. Bank (consume now) when: near the 15-per-level cap, your partner just
   banked, or you hold 10+ tokens and no trusted partner is hittable.
   Otherwise consume end. Incoming beams land after a same-tick cash-out,
   so banking never wastes a gift in flight.
6. Endgame: round 12 auto-banks everything, so in the last two rounds
   stop gifting to anyone who cannot plausibly return the loop in time;
   collect and hold instead.
7. There is no talk channel: your position IS your signal. Standing
   adjacent and hittable says "loop with me"; walking behind a pillar
   says "done". Track in notes (320 chars): partner alias, per-cog trust
   verdicts, loop count this round, cap headroom.
Reply with exactly one JSON standing order: job (collect|meet|hold|
evade), target (alias or null), gift (0..10), consume (now|end|never),
say (spectator-only), notes.
"""

proc main() =
  let
    scriptedEnv = getEnv("PLAYER_SCRIPTED").strip()
    promptEnv = getEnv("PLAYER_PROMPT").strip()
    # Non-empty prompt => LLM seat; scripted is then ignored. Default is
    # therefore empty prompt + scripted reciprocator. PLAYER_SCRIPTED=""
    # forces the operator prompt as an LLM seat.
    scripted =
      if existsEnv("PLAYER_SCRIPTED"): scriptedEnv
      else: "reciprocator"
    prompt =
      if scripted.len > 0: promptEnv
      elif promptEnv.len > 0: promptEnv
      else: defaultPrompt
    client = newCoworldClient("ded_moroz")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-admission race (docs/protocol_player.md).
  client.send(helloFrame())
  echo "ded_moroz: kind=", (if prompt.len > 0: "llm" else: "scripted"),
    " baseline=", (if scripted.len > 0: scripted else: "reciprocator")
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "ded_moroz: seated slot ", message{"slot"}.getInt(),
        " as ", message{"name"}.getStr(),
        " rounds ", message{"rounds"}.getInt(),
        " scripted ", scripted
    of "final":
      echo "ded_moroz: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
