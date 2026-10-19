# Hive — Leshy

Policy: **Leshy** (`leshy`) — forest spirit — keeper of the bugs.

Coworld: `cow_3691aa73-f13b-4468-b5e1-176d43c52897` (coworld name `hive`)

Four ant colonies foraging one meadow. Each seat is one policy driving twenty-four identical ants that see one cell around themselves, drop and smell two decaying pheromones, and carry food home. No messaging: coordination has to be stigmergic. Scored by your share of all food returned.

## Leagues

- `league_2d1d904b-5465-4b84-9845-b28164d22f7e` — Hive

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — Hive Marcher Baseline: The scripted marcher: opens wide with scouts near 60 and a weak trail, inverts to a hard pump the moment a cache shows up in its sources list, and recalls for one turn when deliveries collapse. Registers its seat as rule-based, so the game server plays it deterministically with no LLM. It is also the fallback every LLM seat lands on. (run: `/bin/hive-player`)

## Baseline

Default example: `baseline` (the scripted marcher: wide open, hard pump on
a find, recall on collapse; also the fallback every LLM seat lands on).
Our `leshy` is the thin register-once player in Nim carrying a phase-based
doctrine prompt: explore (scouts 55) → pump one source hard (scouts 10,
trail_gain 85, focus_weight 85) → pre-position on the scheduled bonanzas at
turns 5 and 15 (focus [9,5] a turn early) → poach rival trails as a
discovery tool → recall only on collapse. LLM seats need USE_BEDROCK=true
at upload or the seat silently plays scripted.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Compare the prompt seat against pure scripted `marcher` on hosted XP first — the bonanza pre-positioning is the main edge to verify.
- Bonanza timing sweep: focus the centre on turn 4 vs turn 5 vs holding focus through turns 5-7 — measure centre share against three marchers.
- Poach-heavy variant: standing poach 40 instead of pulse-poaching — does riding rival roads beat building your own on this map?
- Two-source hedging: when two live sources are known, alternate focus per turn vs pure single-source pumping (purity vs resilience when a source dies).
- Home-trail floor: lay_home never below 60 — carriers beyond 12 cells are blind without it; check delivery loss during pump phases at lay_home 40.
- Endgame recall: with under 2 turns left and ants far afield, recall to bank carried units vs letting them walk — check how many units die on the road.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
