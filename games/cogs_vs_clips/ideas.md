# Cogs vs Clips — Ivan Durak

Policy: **Ivan Durak** (`ivan_durak`) — the fool who wins in the end.

Coworld: `cow_235bfa9d-27a5-48ef-8a3c-2ed1123d8e98` (coworld name `cogs_vs_clips`)

Cogs vs Clips and Four Score packaged as one Coworld backed by CogsGuard and MettaGrid.

## Leagues

- `league_4c38c53a-2cd5-4f98-8a1f-20830f733701` — Four Score
- `league_4a6999b2-6130-4489-987b-48d82ae769d2` — Cogs vs Clips

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `reference-player` — Reference Player: CogsGuard Coworld reference player for Cogs vs Clips and Four Score over coworld.player.v1. (run: `python /app/coworld_reference_player.py`)

## Local baseline

~/p/dinky — our Nim agent + coworld_player.nim wrapper (already Nim).

## Baseline

- Default example in the package: `reference-player` (Python, CogsGuard
  reference player over coworld.player.v1).
- Strongest available baseline: our own ~/p/dinky Nim bot — a scripted
  mining / junction / drafting agent that parses MettaGrid token
  observations directly. Its single-player tuning matches the 108.38
  machina_1 champion; the four-team free-for-all path keeps drafting and
  aggressive-mining logic.
- Our policy: **command player**. `ivan_durak.nim` is the coworld.player.v1
  websocket wrapper (copied from dinky's `coworld_player.nim`) and
  `dinky_agents.nim` is the verbatim dinky agent. One binary, decisions
  every step, no LLM.
- Upload secret-envs: none needed (no LLM seat, so no USE_BEDROCK).
- Runtime data: none. dinky's `minds/` dumps and `data/minimap/` PNGs are
  viewer/debug only (`-d:dumpMind` builds); the release binary reads no
  files.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Retune the single-player constants (`SetupTime`, `SinglePlayerHeartMax`,
  `AggressiveMiningThreshold`) against the current league field — they were
  frozen against the machina_1 champion and the meta may have moved.
- Junction-defense pass: track which of our junctions flip to the enemy
  team (`troubled` junctions) and bias one agent to patrol/realign them
  instead of pure mining.
- Draft-phase scouting: during `DraftTime`, send one agent wide to count
  enemy rigs and pick the counter-draft instead of the fixed rig order.
- Smarter target selection in `step`: prefer clip ships weighted by
  distance AND remaining hp so several agents do not converge on the same
  nearly-dead target.
- Energy discipline: gate scrambler attacks on `MaxEnergy` reserve so
  agents never strand themselves out of moves next to a hostile junction.
- Four Score mode detect: read `num_agents`/tags at config time and switch
  to a dedicated Four Score opening (the league packages both games in one
  coworld).

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | pin single-player roles by slot so the hub heart-factory gets miners | setup: `agentId mod 8` → 2 miners, 1 scrambler, 5 aligners (was visible-count all-aligner); gear-up before key scouting | | | |
