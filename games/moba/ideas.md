# Moba — Zmey Gorynych

Policy: **Zmey Gorynych** (`gorynych`) — three heads for three lanes.

Coworld: `cow_bfffc533-8517-4d65-9ed2-c461cdceac02` (coworld name `moba`)

PufferLib's Ocean MOBA as a Coworld: a 5v5 lane-pushing battle arena, bit-exact with the upstream training environment (same C sim compiled to wasm, same 510-byte observations and [7,7,3,2,2,2] MultiDiscrete actions). Radiant and Dire each field five heroes (support, assassin, burst, tank, carry) that push three creep-wave lanes through enemy towers to destroy the opposing Ancient. Heroes level up on experience, respawn on death, and carry three skills on cooldown. An episode ends when an Ancient falls or at the tick cap (tick-cap ties break by remaining Ancient health; equal health is a draw). Two variants: ten seats of one hero each, or two seats of five (one full team per seat). Replays re-simulate deterministically in a static wasm viewer from the recorded seed and per-tick action log.

## Leagues

- `league_becba59f-4201-43a5-9cd6-970bd92857d9` — Moba

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — baseline: Upstream PufferLib pretrained policy (moba_weights.bin) run through the vendored puffernet forward pass compiled to wasm - the exact network the sim was trained with. Image placeholder is replaced at deploy time. (run: `python -m players.baseline_player`)

## Baseline

- The only packaged example is `baseline`: the upstream PufferLib
  pretrained policy (moba_weights.bin through puffernet) — the exact net
  the sim was trained with, and the bar to beat. The upstream repo also
  ships a hand-written reference, `players/scripted_player.py`
  (@ f06d28fd): a per-hero finite-state lane-push bot that only trusts
  the reliably-decodable obs bytes (the 121 crop tile ids + 26 self
  scalars; the crop's stride-1 overlap quirk makes entity health/mana/
  level bytes garbage).
- Our policy `gorynych/` (Zmey Gorynych) is a COMMAND PLAYER: a faithful
  Nim port of that scripted bot — lane waypoints, BFS cost fields over
  the embedded 128x128 wall grid (sha256-matched to upstream game_map.h),
  siege standoff outside tower vision until a creep wave engages,
  fountain retreat with hysteresis, stuck detours, per-role skill gating.
  Differential-tested against the Python original: 240 synthetic ticks
  (1-hero and 5-hero seats), 0 mismatches. Deterministic, no RNG.
- Wire protocol: lockstep JSON per docs/protocol_player.md
  (`{"tick", "obs"}` -> `{"tick", "actions"}`), base64 510-byte obs, one
  6-int MultiDiscrete row per hero, bounded reconnects mirroring the
  upstream players/client.py (403 fatal, drops retried, progress resets
  the budget). Protocol confidence: high — documented verbatim.
- Upload secret-envs: NONE (no LLM anywhere in the player).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Sweep the siege knobs: SIEGE_STANDOFF 6 -> {5, 7} and
  CREEP_ENGAGED_DIST 5 -> {3, 4} — the bot's deaths are mostly tower
  dives where a wave "engaged" but had already melted.
- Wave-surfing: in PUSH, cap forward progress so the hero never leads
  its nearest friendly creep cell by more than ~2 cells toward the next
  waypoint — creeps soak tower and skill damage that currently lands on
  us.
- Kiting retreat: while in RETREAT with an enemy hero adjacent, alternate
  perpendicular steps (the detour machinery, forced) instead of the
  straight BFS descent, so equal-speed chasers lose contact at corners.
- 5-hero seat teamwork: gate each hero's lane commitment so at least two
  heroes share the currently most-broken lane (most dead enemy towers in
  the shared dead-tower memory) for the endgame push instead of three
  solo lanes.
- Earlier skill use for burst/assassin: the mana gates (200/150) suppress
  all level-0/1 skirmishing; try halving the gates below level 3 and
  measure lane control.
- Ancient rush trigger: once BOTH tier-4 towers of a team are remembered
  dead, retarget every hero's goal straight to the enemy ancient (skip
  remaining waypoints) — ancients cannot shoot and ties break on ancient
  health.
- Neutral-camp avoidance in pathing: add a soft cost around NEUTRAL
  tiles in stepToward (not just the target filter) so lane rotations
  stop leaking health to camps.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | League score is only ancient-fall / ancient-HP tiebreak (win 1 / draw 0.5 / loss 0). Primary death cause is tower dives: towers deal 110-175 (ancients 0) vs hero HP 300-700, scan chebyshev 5, then pick nearest by L1 (attack(), moba.h @ c5d3c637 / coworld 0.1.3). Current chebyshev "any friendly creep within 5 of the tower" counted a melting edge creep as cover while we pathed onto the tower cell and ate the shots — each death is a fountain walk that cedes the ancient race. daveey-scripted leads at wr 0.72 on the same FSM; this is the sim-grounded soak the public reference gets wrong. | Siege engaged := a friendly creep in the tower scan square with strictly smaller L1 than us; after steering, cancel any PUSH step that would land at L1 <= that soak creep (stay behind the wave, still in vision to auto the tower). | | | |
| 2 | **Ancient snipe.** Sim geometry (moba.h): towers scan a chebyshev-5 square around their integer cell and shoot the nearest creep/hero by L1; heroes scan their own chebyshev-5 square and attack() only needs L1 <= 12; ancients cannot shoot. So the cells at chebyshev 5 from an ancient on the side away from its two tier-4 guards (radiant: (21..22,102..108) etc., 44 cells; dire: (101..111,14..24), 44 cells) are outside every tower square yet hit the ancient. research/snipe.nim proves 44 blind cells per side and a penalised-Dijkstra route from the fountain that brushes only 2 (radiant) / 3 (dire) tower-covered cells. Leaders need 1000-2500 ticks to kill an ancient (60 reconstructed baseline games, research/losses.nim: richard median 1703, relh 1759, daveey 4157); local wasm harness research/snipetest.nim (mechanics only, not a score) kills the ancient at tick 345-655 from either side with a no-op opponent. | Full rewrite of the decision core (brain.nim): every hero walks a penalised-Dijkstra route (tower squares +60, creep spawn zones +30, camps +8, lanes +2) to its own blind snipe cell, single-file tower-square crossing at >= 8/10 health, wave-phase gate on entering creep spawn zones, then holds with the heroes+towers target filter; nukes on the ancient (burst Q, carry W, support E), support W heals allies <= 6/10 using the seat's other rows, no skills that move us or the target. gorynych.nim is now only the wire loop. | gorynych:v9 (commit 5e2f30d): xreq_f022af57-9019-4172-9a49-02c8a6bf4da7 (vs daveey), xreq_b67d17b7-f86a-4f49-abbb-38a0acce49a3 (vs richard), xreq_6f3f3f33-0ed4-407c-ba3d-3d92b455d079 (vs relh), 10 episodes each, sides rotate | daveey-scripted:v39; co-gas-moba-topstack-richard:v7; co-gas-moba-topstack-relhalpha:v3 | **KEEP.** 28-2-0 (93%) vs v1 baseline t1 cohort 2/30; stratified exact one-sided p = 3.0e-12 (evidence/stats-snipe-t1.json). 10-0 richard, 10-0 relh, 8-2 daveey. Activation (research/snipeproof.nim over all 30 replays): heroes on blind nest cells in every game; enemy ancient fell at tick 300-1242 in all 28 wins. Both daveey losses: our ancient fell at tick ~810 while our heroes died on the route and reached the nest at tick 530+. Submitted to the league 2026-09-12. |
| 3 | **Fight visible creeps on the move.** Death attribution over the 10 v9-vs-daveey replays (research/snipeproof.nim crop snapshots): ~18 of ~50 deaths had 2-9 hostile creeps in the crop and no enemy hero, mostly while queued at the tower-16 crossing (16,86) or walking the far-left corridor (85..94, 5..13) beside the radiant top lane. v9 only used target filter 0 (everything) when a creep was within chebyshev 2, so chasing waves were never shot back. Movement and auto-attack are independent in step_players, so shooting costs no travel time. | Target filter 0 whenever any hostile creep is visible and no neutral is within 2 (was: creep within 2). One line in brain.nim. | gorynych:v10 (commit c937c5f): xreq_11ca1d62-240a-401c-b111-676ad503ae2c (daveey), xreq_12beff61-dbc6-4507-94fe-e1d20428bf45 (richard), xreq_1e56f9ce-a4d7-4d44-82e3-538ba7d32e30 (relh), 10 each | daveey-scripted:v39; co-gas-moba-topstack-richard:v7; co-gas-moba-topstack-relhalpha:v3 vs the v9 snipe t1 cohort | First look 29-1-0 (9-1 daveey, 10-0, 10-0) vs v9 28-2-0: stratified exact p = 0.5 (evidence/stats-creepfight-t1.json), inconclusive; second look (t2, 30 more per opponent for both): cumulative v10 115/120 vs v9 114/120 (daveey 35-5 vs 34-6), p = 0.5 (evidence/stats-creepfight-t2.json). Activation confirmed (v10 answers 90-100% of creep-visible ticks with filter 0 vs 40-75% for v9). **Final look inconclusive: DISCARD v10, v9 remains champion.** |
| 4 | **No diagonal corner-cutting (stall fix).** Lockstep replay of the v9/v10 daveey losses (research/stalls.nim + brain.explain) showed 2-3 heroes per loss parked at full health for 600+ ticks at (46-47,21-23): the sim normalises diagonal velocity to 0.707 per axis and truncates the float position (step_players/move_to), so a diagonal step from an aligned cell first lands in the orthogonal neighbour on the negative axis; when that neighbour is a wall the move fails forever. The v9 planner allowed such squeezes (also the (16,87)->(15,88) tower-16 crossing, explaining the (16,86) death cluster). | brain.nim canStep(): a diagonal step is planned only when both orthogonal neighbours are open, applied in the Dijkstra, step choice, square escape and the guard; nest ranking re-tiered (fountain 7/9/11/12 tiers, +1000 for cells farther than 2 from the best cell) so all five cells cluster. v10 filter change reverted (v11 = v9 + this). Local harness: radiant ancient at 317-374 (was 345-617), no stalled heroes. | gorynych:v11 (commit c6b7d5c): xreq_3218c9f8-2f10-4566-b9a7-fedc721438fb (daveey), xreq_f6df4df3-aa68-486e-bc84-669a9b2f6bc3 (richard), xreq_83bba703-96a2-4c3e-aed7-b310e48e39f6 (relh), 40 each | daveey-scripted:v39; co-gas-moba-topstack-richard:v7; co-gas-moba-topstack-relhalpha:v3, 40 per opponent vs the v9 t1+t2 cohort | First look: v11 120-0-0 (40-0 each) vs v9 114/120: stratified exact p = 0.0101 (evidence/stats-corners-t1.json), above the 0.001 gate; extension launched: v9 snipe t3 (xreq_07d171d6, xreq_feb9b5ee, xreq_8bd591cb) and v11 corners t2 (xreq_1d0e5250, xreq_8703e139, xreq_dbe5aa71), 40 more per opponent each. Activation: research/stalls.nim replays six hosted v11 games with the brain in lockstep and reproduces every recorded action (0 mismatches); the only 60-tick stationary spells are heroes holding on their goal cells. Extension: cumulative v11 240-0-0 vs v9 229/240 (daveey 74-6... see ledger), stratified exact p = 2.2e-4 (evidence/stats-corners-t2.json), score gate passed. **KEEP. Submitted 2026-09-12 as champion; v9 benched.** |
| 5 | **Dash-field check (not an experiment).** The dash's "top 3" is picked by recent overall win rate, not MMR; after ~500 hosted episodes against daveey/richard/relh today their 24h win rates collapsed and the dash field became docxology-ply_176e1e1a:v1, pufferlib-baseline:v1, moba-example:v1, which v9-v11 had never played (blank win-rate column). By MMR the top 3 others are still daveey, richard, relh. | No policy change; gorynych:v11 played against the dash field so the table populates. | xreq_3cbc41ec-a2a7-4c17-b4e4-424bb5769828 (docxology), xreq_50c746ee-1540-4717-98c5-125052a149e5 (pufferlib), xreq_56367d80-5602-453a-9b72-6a20bccc90bd (moba-example), 20 each | docxology-ply_176e1e1a-7af8-40f7-9ee3-a67b96690ad6:v1; pufferlib-baseline:v1; moba-example:v1 | 20-0-0 against each (60/60); dash frontier row now gorynych v11: 300 games, 100%. |
| 6 | **Top-3 refresh (user request, not an experiment).** MMR top 3 others re-checked via tools/fields.nim: unchanged (daveey-scripted:v39, richard topstack:v7, relhalpha topstack:v3). | No policy change; fresh gorynych:v11 batch against them. | xreq_73275c74-399f-4953-a8d6-d4127b7b89eb (daveey), xreq_6f579be6-f0ea-4306-a3c5-bc1099b6a943 (richard), xreq_7944ff63-f5ec-4d85-ba16-e7b714a9f35c (relh), 10 each | daveey-scripted:v39; co-gas-moba-topstack-richard:v7; co-gas-moba-topstack-relhalpha:v3 | 30/30 completed; dash frontier: gorynych v11 330 games, 100% (daveey 90-0 cumulative today). |
