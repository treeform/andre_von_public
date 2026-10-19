# Agricogla — Mikula Selyaninovich

Policy: **Mikula Selyaninovich** (`mikula`) — the plowman bogatyr — farming.

Coworld: `cow_aa589437-53aa-46d9-9041-f74f017215eb` (coworld name `agricogla`)

A four-player worker-placement farming benchmark: agents place family members on action spaces to gather resources, build a farm, raise animals, and grow a family. Most victory points after 14 rounds wins.

## Leagues

- `league_b81baeb4-0e1b-4e71-b162-08f46b2b6a45` — Agricogla

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `agricogla-scripted` — Agricogla Scripted Baseline: Deterministic no-LLM heuristic (the engine's candidate scorer). Certifies the contract offline. (run: `node dist-server/game/baseline-player.js`)
- `agricogla-llm` — Agricogla LLM Baseline: A Bedrock-driven policy that plays the seat through the game's autopilot (system prompt + per-phase tool). (run: `node dist-server/game/llm-player.js`)

## Local baseline

~/p/cogame-agricogla — local repo.

## Baseline

- Default and strongest example: `agricogla-scripted` (node baseline-player.js),
  the engine's candidate scorer replayed over `cogweb.player.v1`; the
  `agricogla-llm` seat wraps the same autopilot in Bedrock. Timed-out or
  absent seats fall back to the scripted baseline (or random once the 300s
  chess clock is spent), so the scripted heuristic IS the field to beat.
- Protocol note: the manifest doc (docs/protocol_player.md, cogweb.player.v1)
  is authoritative — observation {id, seat, turn, view, reason, timeLeftMs},
  reply {type:"reply", id, decision}; `view` is a redacted engine GameState.
  The local repo ~/p/cogame-agricogla speaks an OLDER wire shape
  (state/options/choices, place/feed frames) — do not port from it. The
  deployed source is ~/p/metta packages/cogweb/games/agricogla @ fa0682f5.
- Our policy `mikula` is now the vendored terra champion from ~/p/terra
  (commit 8869f83, the lineage submitted as terra:v268 — ranked #1 in this
  league at 2373 MMR). The earlier Nim port of the deployed baseline's
  candidate scorer was replaced entirely by this vendoring. Terra is a
  full game-model MCTS command player: it simulates Agricogla in
  terra/nodes.nim, guides rollouts with the heuristic in terra/policy.nim,
  and runs a time-budgeted multi-threaded solver (~6s/move, 100k
  iterations default) with a large set of "protect" gates that veto MCTS
  moves against the heuristic plan when the edge is thin. Tunable via
  TERRA_SOLVER_ENABLED / _ITERATIONS / _MAX_MOVES / _TIME_MS / _THREADS
  envs (defaults are the champion settings — leave them alone).
- Upload: no secret-envs needed (fully scripted command player, no LLM
  seat, no Bedrock).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

1. Fences and pastures: port suggestFencePlans (rectangular plans over empty
   cells) — pastures are big endgame points and unlock real animal capacity;
   the baseline builds them and we currently concede that whole category.
2. Occupations: play `lessons` with a static per-card value table for the
   occupation deck (cards in engine/cards/occupations.ts); the first
   occupation is free and the baseline weights them highly early.
3. Endgame category sweep: from round ~11 value moves by marginal victory
   points per the scoring tiers (engine/scoring.ts) instead of the economy
   wants table — e.g. grab the missing vegetable/animal type to escape -1s.
4. Opponent denial: read other farms' public state (resources, farms) and
   raise the value of taking the accumulation pile or improvement the current
   leader most obviously needs next turn.
5. Renovation + hearth line: port renovationCost and the clay-to-stone path
   for the r_renovate_improve VP swing the baseline already values (22 late).
6. Talk channel: replies may carry cheap-talk `messages`; post baseline-style
   round-gated lines (or targeted misdirection) — zero engine effect, but
   LLM opponents read the inbox and may be steerable.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | chess-clock budget | Cap per-move MCTS think time from observation.timeLeftMs and remaining placements so the 300s bank lasts to round 14 instead of random endgame moves | | | |
