# Lux Ai — Dazhbog

Policy: **Dazhbog** (`dazhbog`) — the sun god — light.

Coworld: `cow_85ac57ce-ce33-44dc-a00f-d74141fdd9fe` (coworld name `lux-ai`)

Lux AI Season 1 on a seeded, mirror-symmetric 16x16 island: two sides gather wood, coal and uranium, spend research to unlock the better fuels, and every ten turns the sun goes down and each city must pay its light bill or die on the spot. Most city tiles standing at turn 360 wins.

## Leagues

- `league_91cd77d4-0030-495d-81c4-37de0b298801` — Lux-Ai

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `forester` — lux-ai-forester: The published scripted default: wood until coal is researched, expand unless a city is inside sixteen nights of starving. Also the per-turn LLM fallback and the driver of a no-show seat. (run: `/bin/lux-ai-player`)
- `prospector` — lux-ai-prospector: The control: it buys the fuel ladder early and pays for it in city tiles. Deliberately a different SHAPE from forester so the ladder gets a spread rather than two versions of one bot. (run: `/bin/lux-ai-player`)

## Baseline

Default example: `forester` (scripted; also the per-turn LLM fallback
and the no-show driver). `prospector` is the control with a different
shape (early fuel ladder, fewer tiles); forester beats it at the pinned
seed. Our `dazhbog` is a thin Nim seat registrar speaking the bitworld
sprite protocol: one 0x81 chat frame with
{"type":"register","policy","prompt","scripted"}, re-sent for the first
seconds (slot-sequential joins), then a 0x85 Ready after every received
frame - the seat sends no inputs (fastMode). The prompt is a directive
strategy: night-bill triage first (survives_tonight false -> fuel/haul),
wood-first expand with focus always adjacent to the largest city
(compactness), research coal from turn 0 (production-before-research
makes leftover tile actions free) and stop at 50, uranium almost never,
contest when behind after turn 180, turtle from 340. Env overrides: PLAYER_PROMPT, PLAYER_SCRIPTED
(forester|prospector). NO Bedrock flag: the LLM call is made by the
game container, which holds the coworld secret.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Beat the shipped champions: pull `scripts/champion_prompts.json` (lumberjack, nightwatch) from the upstream repo and diff their triggers against ours; nightwatch's win-the-second-half line is the one to counter.
- Worker-count sweep: the prompt caps at 8 workers; forester's tuned numbers are in `tools/ci/baseline_tuning.json` upstream - test tile+2 vs a flat 6 against forester on hosted XP.
- Focus discipline: test focus-adjacent-to-largest-city (compactness) vs focus-on-richest-wood-cluster (income) for the first 60 turns; the 3x3-vs-scattered upkeep gap (147 vs 207) says compactness, but early income compounds.
- Research stopping rule: the prompt stops coal research at 50 points; verify the model actually reads `researched` and add an explicit "if researched.coal is true set research none" trigger if fallback records show it overshooting.
- Contest stance timing: turn 180 may be too late to contest a mirror-symmetric map; test 120 with focus on the midline coal cluster.
- Night policy: shelter (default) vs mine for workers on safe city-adjacent wood tiles at night - units on a surviving friendly tile pay nothing, so a worker parked on a city with adjacent wood loses nothing and keeps gathering.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Opening `research:"none"` idles city tiles. Micro (v0.1.4) builds workers/carts first only while under the unit cap AND below the workers/carts target; leftovers research. At the 1-tile opening you are already at cap, so `none` wastes every tile action (0 research) while lumberjack/forester bank coal points for free. Coal is 50 fuel/turn vs wood 20; score is city tiles at 360, so earlier coal is more nights the blob survives. Leader (lumberjack, field.md 17-4 vs nightwatch) researches coal from cycle 1. | Operator prompt only: opening research none→coal; drop the 4+ fed-tile gate; stop at yours.research>=50 / coal.researched. | | | |
