# Meadow — Poludnitsa

Policy: **Poludnitsa** (`poludnitsa`) — noon spirit of the meadows.

Coworld: `cow_13d73caa-0370-4ec6-9b9b-e931c686ed04` (coworld name `meadow`)

Round-based commons game: N players share one regenerating stock that dies permanently if over-harvested. Institutional dials (public ledger, costly sanctions, posted norms, chat) are config, so one game runs the social-pressure treatment grid.

## Leagues

- `league_918134dc-1bf7-418e-833b-eb946c4cbeef` — Meadow League

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `sustainable` — Sustainable Harvester: Harvests one unit per round while the stock is healthy, rests otherwise. (run: `python -m coworld.examples.meadow.player.player sustainable`)
- `greedy` — Greedy Harvester: Always takes the maximum. The tragedy, distilled. (run: `python -m coworld.examples.meadow.player.player greedy`)
- `reciprocator` — Reciprocator: Sustainable until the aggregate shows over-harvesting, then triggers to max for a round. (run: `python -m coworld.examples.meadow.player.player reciprocator`)
- `deterrable` — Deterrable Greedy: Greedy, but each sanction received buys five contrite quota rounds. (run: `python -m coworld.examples.meadow.player.player deterrable`)
- `enforcer` — Enforcer: Sustainable harvester that pays to sanction the worst over-harvester on the public ledger. (run: `python -m coworld.examples.meadow.player.player enforcer`)
- `random` — Random Harvester: Uniform random harvests; the maximum-variance control. (run: `python -m coworld.examples.meadow.player.player random`)

## Baseline

Command player: the examples run `python -m coworld.examples.meadow.player.player <name>` (source Metta-AI/coworld-meadow `src/coworld/examples/meadow/player/policies.py`; the default is `sustainable`). The strongest *example* is `enforcer` — quota-1 plus paid sanctions — but that is the social-planner harvest, not the league objective. League score is own harvest minus sanction costs/burns; daveey `meadow-forager` at wr 0.99 is the unique max-harvester against a quota-1 field (sim: 180 vs 37, stock lives). `poludnitsa/poludnitsa.nim` now takes `max_harvest` every round and still sanctions the worst over-quota rival when the ledger is public. Quota is env-tunable (`POLUDNITSA_QUOTA`) as the sanction threshold only. No LLM, so no upload secret-envs required.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Reciprocator fallback for anonymous treatments: when the ledger is hidden, no sanction can fire; add the reciprocator's aggregate trigger (others' mean > quota + 0.5 last round → harvest max once) so defection still gets punished.
- Config-derived quota: compute the sustainable aggregate `regrowth_rate * stock_capacity / 4` from the observation and set quota to `floor(that / num_players)` instead of the hardcoded 1 — robust to non-default treatments.
- Endgame defection: in the last `ceil(stock / (num_players * max_harvest))` rounds regrowth no longer matters to us; switch to max harvest for a guaranteed score bump with no future cost.
- Sanction economics: only sanction when `sanction_burn - sanction_cost` exceeds the expected harvest reduction it buys; track per-slot response to past sanctions (deterrable seats reform, greedy ones don't — stop paying to punish the incorrigible).
- Norm-signaling chat: when `chat_enabled`, post the quota once early and call out over-harvesters by slot — free coordination pressure on LLM seats in the field.
- Collapse brinkmanship guard: harvest 0 whenever `stock - last_round_total_harvest` is within one round's plausible demand of `collapse_threshold`, even above the floor — one greedy round by others must never let our own quota tip the commons dead.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | harvest max not quota | League rank is own harvest, not welfare. Enforcer quota-1 while stock>=30 is the planner move and loses ~37-180 to a unique max-harvester (daveey meadow-forager wr 0.99; 3 of 4 variants have sanctions off). Always demand max_harvest (covers endgame and post-collapse scramble). Keep sanctioning the worst over-quota rival so a fellow forager eats the burn. | | | |
