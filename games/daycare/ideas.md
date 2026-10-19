# Daycare — Snegurochka

Policy: **Snegurochka** (`snegurochka`) — the snow maiden, gentle with children.

Coworld: `cow_5b944b41-3f2f-4f84-a96b-c484811d7d55` (coworld name `daycare`)

Daycare: one cog can reach the fruit, the other one knows which fruit it wants, and neither can say a word. A parent and a child in a walled yard; the child cannot reach the tall trees and its preference is never shown to the parent, who is paid only when the child eats. Caregiving as a game: read another agent's goals from its actions and provide for them, with no explicit channel.

## Leagues

- `league_b3316d91-3a90-41b6-9370-4c6644e51b9c` — Daycare

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `daycare-caretaker` — Daycare Caretaker Baseline: The working scripted baseline as a fieldable policy, role-aware: as the PARENT it reads the child's cumulative behaviour summary (failed reaches first, then refusals, then adjacency, then meals), guesses the species and provides it; as the CHILD it seeks its own species when it can and otherwise stands under a tall tree of that species and reaches, over and over, so the parent has something to read. Deterministic, no LLM. This is also the order every failed LLM decision falls back to. (run: `/bin/daycare-player`)
- `daycare-stubborn` — Daycare Stubborn Baseline: The anti-theory-of-mind foil: as the PARENT it provides apples and guesses apple every turn forever, ignoring the child entirely; as the CHILD it grazes -- eats whatever is nearest, never reaches at a tall tree, and therefore emits no species signal at all. One exception keeps a stubborn pair off a guaranteed zero: after four turns without a meal the child begs for one turn. (run: `/bin/daycare-player`)

## Baseline

`daycare-caretaker` (role-aware scripted reader: failed reaches first, then refusals, then adjacency, then meals; child shows its species) is the working baseline and the fallback for every failed LLM turn; `daycare-stubborn` is the anti-theory-of-mind foil. Snegurochka (`snegurochka/snegurochka.nim`) is a thin prompt-or-scripted seat: it sends `{"type":"prompt","prompt","scripted"}` on connect and again after `welcome`, then spectates. **Default is `PLAYER_SCRIPTED=caretaker`** — the published winning policy (leader richard's `co-gas-daycare-caretaker-richard`, wr 0.86). Override with `PLAYER_SCRIPTED=` plus `PLAYER_PROMPT` to field the LLM path (then USE_BEDROCK=true is required). The unused operator prompt covers BOTH roles: as child, show-first signalling then seek; as parent, evidence ranking plus a two-turn experiment. Sim checked at coworld 0.1.0 / `948d5de5ca5d9a09b612b5eca0fea922cb8cc853`: `rewardOther` is 1 (docs/rules.md wrongly says 0), `fruitLifetime` is 96 (docs say 120).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Skip the two-turn experiment: caretaker partners' children usually show immediately, so "provide the species with any failed reach from turn 1" may commit a turn earlier; measure turns-to-first-preferred-meal.
- Child anti-stubborn line: vs a stubborn parent (always apples), test adding "if turn 4+ and still only wrong fruit arrives, eat one wrong fruit every third turn" — 0 points but keeps... actually scores 0; instead test beg cadence (beg every other turn) to break stubborn parents' watch loop.
- Mat-stocking ratio: sweep "stock every time child has 2+ pieces adjacent" vs never stocking — mat fruit never rots, but stock trips cost delivery turns.
- Parent shrub avoidance: quantify "prefer tall trees, shrubs cost 6 ticks per failed pick" as a hard rule vs soft preference in delivered-fruit-per-turn.
- Guess hygiene: the guess is REQUIRED and independent — test always guessing the current evidence leader even while delivering the other species (the schema explicitly allows disagreement).
- Sparse variant: shrub success drops to 15% — check whether the prompt should name the variant and forbid child shrub attempts entirely there.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | field the published caretaker baseline instead of the LLM prompt | default `PLAYER_SCRIPTED` to `caretaker` (leader richard is `co-gas-daycare-caretaker-richard` at wr 0.86; LLM prompt scored other-fruit as 0 vs sim `rewardOther=1`, fruitLifetime 120 vs 96, and two-turn-experiments while caretaker commits on first reachFails) | | | |
