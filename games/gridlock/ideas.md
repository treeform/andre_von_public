# Gridlock — Solovei Razboinik

Policy: **Solovei Razboinik** (`solovei`) — Nightingale the Robber — blocks the road.

Coworld: `cow_698b5853-7860-4b4f-b59c-a618e558faee` (coworld name `gridlock`)

Gridlock: four parcel fleets share one signalised 9x9 city. Each seat is a single policy routing fifty vans; a fleet scores one point per parcel its OWN vans deliver. Intersections have hard capacity and lanes spill back into the intersections behind them, so the fastest, greediest routing plan is the one that builds the jam everybody - including its author - then sits in. Nobody controls the lights. A policy is just a prompt.

## Leagues

- `league_4c0f039e-3a99-48ad-9d72-c3f85a110ea8` — Gridlock

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — dispatcher: Congestion-aware shortest-path dispatcher with jam-triggered fleet metering. The bundled certification player: it registers its seat as scripted, so the game server plays it deterministically with no LLM in the loop. Field your own policy by uploading this same image with a PLAYER_PROMPT instead. (run: `/bin/gridlock-player`)

## Baseline

Default example: `baseline` (the dispatcher, a scripted certification seat).
Strongest scripted baseline: `dispatcher` (congestion-aware shortest path
with jam-triggered metering; also the fallback plan). Our `solovei` is the
thin register-once player in Nim. **v2 defaults `PLAYER_SCRIPTED` to
`dispatcher`** and sends an empty prompt while a baseline is named
(server `effectiveScript` honours a named kind even with a prompt; empty
prompt also plays dispatcher). Dispatcher is sweep-tuned
(`src/gridlock/baselines.nim`: weightBase 30+jam, dispatch 100/80/60/45
on jam_index, corridor null, priority far when backlog>55) and is what
relh/richard field as `co-gas-gridlock-baseline-*`. `PLAYER_SCRIPTED=""`
restores the v1 operator prompt as an LLM seat. LLM seats need
USE_BEDROCK=true at upload.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Compare the prompt seat against pure scripted `dispatcher` on hosted XP first — the LLM must beat the deterministic dispatcher to earn its seat.
- Tune the metering thresholds: try dispatch 55/spread 60 as the *baseline* (permanent restraint) instead of a jam reaction.
- Corridor discipline experiment: corridor own quadrant every turn vs corridor null — does the 60% discount overload the home arterials?
- Exploit rival collapse: when fleets[] shows a rival's on_road count ballooning with flat deliveries, raise own congestion_weight to 100 and avoid CENTRE for two turns.
- Use next_orders[<=6] to pick priority: if most next orders are in one district, corridor that district for a turn.
- Turn-0 special case: city is empty, so open with dispatch 90, congestion_weight 40 to bank cheap early deliveries before the first jam forms.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Field built-in `dispatcher` instead of the LLM prompt. We are 6/6 (rating 815.5). Relh/richard field `co-gas-gridlock-baseline-*` (dispatcher) at 993.9/971.0 wr 0.39/0.35; daveey-1's `gridlock-backstreet` leads at 1038.6. Score is raw own deliveries; an LLM table can deadline-cut at 660s (minTurnSpacing 10s × 20 turns plus 14+6s attempts) and every failed reply already falls back to dispatcher. Dispatcher is sweep-tuned (weightBase 30+jam, dispatch 100/80/60/45, corridor null, priority far when backlog>55). Our v1 prompt always-corridored the home district (60% cost discount on home arterials), capped calm dispatch at 70, and locked priority near. Server `effectiveScript` honours a named scripted kind even with a prompt. Scripted/code A/Bs have won; prompt rewrites have lost. | default PLAYER_SCRIPTED to `dispatcher` and send empty prompt while a baseline is named (env still overrides; empty PLAYER_SCRIPTED restores the operator prompt) | | | |
