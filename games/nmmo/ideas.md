# Nmmo — Buyan

Policy: **Buyan** (`buyan`) — the mythical island world.

Coworld: `cow_6272bfca-6bfa-4268-be2c-9ee35f669cfc` (coworld name `nmmo`)

PufferLib's Ocean NMMO3 (Neural MMO 3) as a Coworld: a persistent 512x512 survival world, bit-exact with the upstream training environment (same C sim compiled to wasm, same 1707-byte observations and 26-way discrete actions). Eight free-for-all agents harvest resources, fight enemies, level combat and profession skills, and equip gear; death or 500-tick stagnation respawns an agent in place. Episodes end at the tick cap; seats are ranked by score: mean min(combat, profession) level per life, summed over the seat's agents — normalizing by lives makes every death hurt, so suicide-respawn farming never pays. Replays re-simulate deterministically in a static wasm viewer from the recorded seed and per-tick action log.

## Leagues

- `league_d7e141f9-ee29-4a46-b15c-5bbdb1639a44` — Nmmo

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — baseline: Upstream PufferLib pretrained MMONet policy (nmmo3_weights.bin) run through the demo network forward pass compiled to wasm - the exact network the sim was trained with. Image placeholder is replaced at deploy time. (run: `python -m players.baseline_player`)

## Baseline

- The only packaged example is `baseline`: the upstream pretrained MMONet
  (nmmo3_weights.bin through the demo forward pass) — the bar to beat.
  The upstream repo also ships `players/scripted_player.py` (@ 96d4ce5a,
  "daveey's league entry"): a survival FSM over the 11x15 window + 47
  self scalars, whose core asset is a LIVENESS map that defuses the
  legacy encoding's window-relative stale entity bytes (imprints follow
  the agent around; raw reactions lock into attack/flee-forever loops).
- Our policy `buyan/` is a COMMAND PLAYER: a faithful Nim port of that
  scripted bot — liveness diffing shifted by the fresh anim scalar,
  corpse and ghost filters with attack-hit feedback, herb heals, rested
  delta-0 fights fought out, 20-tick tool grabs, run-away disengages,
  tool/armor equipping (never gems), prof-leveling harvest priorities,
  market junk-dumps on a full inventory, threat-biased persistent
  wander. The only deliberate deviation: the wander RNG is splitmix64
  (seeded from COGAME_PLAYER_SEED, agent index, life generation) instead
  of numpy PCG64 — any deterministic stream is equivalent here.
  Differential-tested against the Python original with the RNG unified:
  360 synthetic ticks (1- and 3-agent seats, respawn resets included),
  0 mismatches.
- Wire protocol v2: lockstep JSON per docs/protocol_player.md
  (`{"tick", "obs", "resets"}` -> `{"tick", "actions": [[a], ...]}`),
  base64 1707-byte obs, 26-way discrete action, per-agent resets
  clearing the mind. Bounded reconnects mirror players/client.py.
  Protocol confidence: high — documented verbatim. One leniency: a
  missing/short `resets` array is treated as all-false rather than a
  fatal error (the upstream client raises); flagged here in case a
  server-side protocol change ever makes that mask real resets.
- Upload secret-envs: NONE (no LLM anywhere in the player).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Opt into truthful entity bytes (patch 0003): append `&obs=clean` to
  the connect URL — zeroed empty-cell entity bytes make enemy hints
  near-perfect while the liveness machinery keeps covering static
  entities. Env-gate it (PLAYER_OBS_CLEAN=1) and A/B against legacy.
- Sweep the fight gates: FIGHT_START_HP 95 -> {85, 90} and
  FIGHT_WOUNDED_HP 60 -> {50} — kills are the only comb source and the
  score is min(comb, prof), so too much caution caps the score at prof.
- Scale healing with level: HEAL_HP 45 is tuned for 100 max hp; read
  S_HP_MAX and heal below 45% instead of 45 points, and raise HERB_STOCK
  to 3 once comb >= 4 (fights last longer at higher levels).
- Buy tools with banked gold: the bot sells junk at price 9 but never
  buys; a BUY flow for a tier-upgrade tool (ui modes 1/2) would unlock
  higher-tier harvests exactly when prof stalls at tier_level(held).
- Gang-up guard: skip starting a delta-0 fight when a second live enemy
  hint sits within 2 cells of the target — two-on-one melee trades are
  net-negative even when each is individually beatable.
- Stagnation telemetry: track ticks since min(comb, prof) last rose; if
  it approaches ~400, force long straight wander bursts (the 500-tick
  in-place reset zeroes the life's contribution).
- Water-edge bias in wander: prefer directions whose 2-3 tile lookahead
  holds passable terrain, so shoreline agents stop burning wander rolls
  against stone/water walls.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
