# Ecos — Berendey

Policy: **Berendey** (`berendey`) — the forest tsar, steward of nature.

Coworld: `cow_796e0e49-fb08-4681-98e2-6e7854b28f41` (coworld name `ecos`)

Ecos: grass, grazers and predators on a continuous field, one seat per trophic role. Each seat is a whole species and sets a four-integer doctrine once per generation; the score is integrated biomass, and any role that crashes the others crashes itself a generation later.

## Leagues

- `league_60071522-0ef6-4ad3-b6e3-76651490c3fd` — Ecos

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `ecos-player` — Ecos Prompt Player: The reference Ecos policy: delivers its PLAYER_PROMPT (or a default steward strategy in words) to the game and spectates until the final frame. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/ecos-player`)
- `ecos-steward` — Ecos Steward Baseline: The scripted steward: the verified default doctrine plus two closed-loop corrections - recruit when thin, back off when your food is thin. Legal by construction and able to sustain ten generations on every seeded opening. (run: `/bin/ecos-player`)
- `ecos-opportunist` — Ecos Opportunist Baseline: The scripted opportunist: the same corrections over a greedier constant doctrine. It scores higher when the other two seats are cautious and wrecks the field when they are not - an honestly weaker filler. (run: `/bin/ecos-player`)

## Baseline

Default example is `ecos-player` (prompt seat, `/bin/ecos-player`); the
strongest scripted baseline is `ecos-steward` (default doctrine plus
recruit-when-thin and back-off-when-food-thin corrections); `opportunist`
is a greedier, riskier filler. Our policy `berendey` is the thin Nim
prompt-or-scripted seat: it sends `{"type":"prompt","prompt","scripted"}`
on connect and again after welcome, then listens until `final`. **Default
is `PLAYER_SCRIPTED=steward`** — the sim's verified doctrine plus two
closed-loop corrections (recruit when pop < 0.4 x cap; back off when
food pop < 0.4 x its cap; grass instead spreads when grazers > 0.6 x
cap). Score is Σ min(G(g), 2.0) and a crash zeros remaining generations
for every seat; steward is legal by construction and lasts ten
generations on every seeded opening. Relh/richard field
`co-gas-ecos-baseline-*`; an invalid LLM reply already falls back to
steward. Override with `PLAYER_SCRIPTED=` plus `PLAYER_PROMPT` to field
the LLM path (then USE_BEDROCK=true is required). Sim checked at coworld
0.1.1 / `fc34252c8c43d3f5601c7dae35d619c3388f89de`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Tune the predator seat separately: it is the fragile role — try an even
  more conservative default (rest_energy 260, birth_threshold 350) and
  see if mean score across role rotations rises.
- Use the 10x6 density grid explicitly: prompt the model to name the
  emptiest grid third and bias seed_range/hunt_range doctrine toward
  recolonizing or harvesting it.
- Exploit the 2.0 per-generation cap harder: when scoreSoFar/generation
  is near cap, instruct dumping surplus into stabilizing the level below
  (quantified thresholds instead of prose).
- Try a grass-seat greed variant: crowd_limit 4 + seed_cost 30 from
  generation 1 — grass rarely crashes first, so its cap may be reachable
  earlier than the steward pace.
- Add opponent modelling via history: if the predator seat's doctrine
  behaviour looks like `opportunist` (grazer pop sawtooth), pre-emptively
  raise grazer flee_range/herd a generation earlier.
- Shorten the prompt to ~1500 chars (numbers-only doctrine tables) and
  A/B: matrix-games experience suggests terse tables sometimes beat prose.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | field the published steward baseline instead of the LLM prompt | default PLAYER_SCRIPTED to `steward` in berendey.nim (env still overrides). Leaders relh/richard are `co-gas-ecos-baseline-*` (wr 0.54/0.52 vs our LLM at rating 809.8). Score is Σ min(G(g), 2.0) over 10 gens; a crash zeros remaining gens for all three seats. Steward is the verified default doctrine plus recruit-when-thin / back-off-when-food-thin at 0.4 x cap (population, not biomass) and lasts 10 gens on every seeded opening. The LLM prompt used half-of-reference biomass thresholds and off-default doctrines (grazer bite 8 vs 10, flee 90 vs 40, pred birth 320 vs 400); invalid replies already fall back to steward after one retry. Opportunist is the documented weaker filler. | | | |
