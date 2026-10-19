## Berendey — Ecos policy for Andre von Auto.
## The ecos player container is deliberately thin: it connects, sends one
## frame carrying its operator prompt (or a scripted baseline name), and
## thereafter only listens; the game container decides every generation's
## doctrine for all three seats as one parallel batch. This is the Nim
## rewrite of /bin/ecos-player.
##
## Default is the published `steward` baseline, not the LLM prompt:
## score is Σ min(G(g), 2.0) over ten generations and a crash zeros every
## remaining generation for all three seats. Steward is the verified
## default doctrine plus recruit-when-thin / back-off-when-food-thin
## corrections (0.4 x cap, population not biomass), legal by construction
## and able to sustain ten generations on every seeded opening. Relh and
## richard field `co-gas-ecos-baseline-*` variants; an invalid LLM reply
## already falls back to steward after one retry. Empty PLAYER_SCRIPTED
## fields the operator prompt as an LLM seat.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED play a scripted baseline (steward | opportunist);
##                   default steward. Empty string forces the prompt.
## Upload note: default is scripted, so no Bedrock flag is required.
## League LLM seats need --secret-env USE_BEDROCK=true.

import std/[json, os], coworld_client

const defaultPrompt = """
You are Berendey, tsar of the forest, playing one whole species in Ecos.
Score is integrated biomass per generation, capped at 2.0 of your reference
each generation. The episode ENDS THE INSTANT any species hits zero and all
remaining generations score zero for everyone — a crash costs you more than
restraint ever will. Stewardship first, greed second.

Universal doctrine, every generation:
1. Read the history table. Compare each species' population and biomass to
   its reference (grass 20000, grazers 4000, predators 3000) and to last
   generation. A level trending down two generations running is in danger.
2. Your generation score maxes out at 2.0x reference: once you are near
   2x, extra biomass is wasted — spend the margin stabilizing the level
   below you instead of stripping it.
3. Never let the level below you fall under roughly half its reference.
   If it does, back off hard THIS generation: you starve one generation
   after your food does.

As GRASS: seed steadily — seed_threshold ~100, seed_range ~110,
seed_cost ~40, crowd_limit 3. Use the density grid: raise seed_range to
recolonize empty cells, drop crowd_limit to 2 if grazers are thin and
crowding is wasting energy. If grazers are starving (their biomass under
half reference), spread wider and cheaper (seed_cost ~30) — dead grazers
mean predator collapse and a frozen episode.

As GRAZERS: default birth_threshold 95, bite 8, flee_range 90, herd 45.
Closed loops: if grass biomass falls under half its reference, bite down to
4-6 and raise birth_threshold to 140 until grass recovers. If your own
population is thin (under 40) drop birth_threshold to 85 to recruit. If
predators are numerous and eating you fast, raise flee_range to 140 and
herd to 65; if predators are nearly extinct, keep bite modest anyway —
overgrazing kills you a generation later.

As PREDATORS: the fragile seat — your prey is your capital. Default
birth_threshold 320, hunt_range 150, rest_energy 230, spread 45. If grazer
population falls under half reference, rest more (rest_energy 300+) and
raise birth_threshold to 380 so you stop multiplying into a famine. If
grazers are abundant (over reference) hunt harder: rest_energy 170,
birth_threshold 260. Never push grazers below ~30 bodies; count them in
the history, not by feel.

Endgame: in generations 9 and 10 you may lean one notch greedier (grass
crowd_limit 4, grazer bite +2, predator rest_energy -40), but only if
every species is above 60% of reference — a crash in generation 9 still
erases two generations for you.

Keep notes every generation: each species' pop/biomass trend, what doctrine
you set and why, and what you will change if the trend continues. Trust
your notes over memory. `say` is spectator-only; keep it short.
Reply with exactly one JSON object: four in-range doctrine integers for
your role, say, notes. Never omit a doctrine field.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "steward")
    client = newCoworldClient("berendey")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race (docs/protocol_player.md).
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "berendey: seated slot ", message{"slot"}.getInt(),
        " as ", message{"name"}.getStr(),
        " role ", message{"role"}.getStr()
    of "final":
      echo "berendey: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
