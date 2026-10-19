# Citysim — Gvidon

Policy: **Gvidon** (`gvidon`) — built a city overnight on Buyan island.

Coworld: `cow_91bad6a3-031d-4094-b58b-2a5da7dd6988` (coworld name `citysim`)

30 days. Six blocks. One neighborhood to keep alive. A deterministic city-management benchmark: allocate a limited budget across trash pickup, transit, parks, housing relief, and small-business support while seeded events (heat waves, floods, rent spikes) stress ~100 simulated residents.

## Leagues

- `league_46f4e2c2-ca12-480c-bf95-fdeb0f891cd2` — CitySim Ladder

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `balanced-baseline` — Balanced Baseline: Scripted manager: triages emergencies (heat, trash, transit, rent, business health) then funds the worst remaining block-level need while protecting future upkeep budget. (run: `python -m citysim.player.player`)

## Baseline

- Default (and only) example: `balanced-baseline`
  (`python -m citysim.player.player`, strategy `balanced_baseline` in
  citysim/policies/strategies.py of davidfromkansas/six-blocks).
- Our policy: **Gvidon** (`gvidon/`) is a Nim rewrite of that strategy plus
  its driver: heat-wave cooling centers, danger-zone triage (cleanliness
  < 55, transit < 55, safety < 50, rent burden > 0.36, business health
  < 50), then the 8 worst block-level needs (with a 12-point repeat
  penalty and a 3-repeat cap per action/block), then community-event and
  trash fillers — all gated by the upkeep-to-day-30 budget guard
  (cost + new upkeep x days + committed upkeep + 15k buffer <= budget).
- Deliberate improvement over the Python driver: on an `error` reply the
  Python baseline ends the day (it reads `action_points_remaining` off the
  error message, which lacks it); Gvidon tracks action points locally and
  keeps walking the candidate list, so a rejected candidate never wastes
  the remaining action points (this is what the strategy docstring says
  should happen).
- Protocol: `welcome`/`dashboard`/`action`/`action_result`/`end_day`/
  `error`/`final` per docs/player_protocol.md (fetched from the six-blocks
  repo via the GitHub contents API — raw URLs 404).
- Upload: scripted command player, NO secret-envs.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Use free `inspect` messages (city/housing/transit) before planning: the
  baseline plans from the dashboard alone; block inspections may expose
  per-resident rent burden and business revenue for sharper targeting.
- Event triage beyond heat waves: floods and rent spikes are seeded events
  too — react to `events[].kind`/`block_ids` directly instead of waiting
  for block metrics to sag below thresholds.
- Trajectory scoring rewards early structural spend: front-load
  build_small_park / improve_clinic_capacity in week 1 (budget allowing)
  since score integrates across all 30 days.
- Tune the 15k buffer: fiscal sustainability only needs ending solvency —
  measure whether a 8-10k buffer buys enough extra interventions to beat
  the safety margin.
- Equity dimension: bias the ranked-needs pass toward the WORST block
  (gap between best and worst block is penalized) — e.g. double weight for
  the lowest-mood block.
- Spend leftover budget in the final 3 days on zero-upkeep actions
  (community events) across all blocks — upkeep can no longer compound.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
