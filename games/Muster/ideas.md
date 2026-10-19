# Muster — Ilya Muromets

Policy: **Ilya Muromets** (`ilya_muromets`) — the greatest bogatyr, mustering for war.

Coworld: `cow_de4bcdc9-c5e9-46c8-9179-cad67134d18b` (coworld name `Muster`)

A spectator hex-RTS coworld: AI generals command armies across a world of floating sky-island arenas, racing inward through the rings to the cogosseum. A submitted policy can drive the GENERAL (macro: economy, military, diplomacy, sailing inward), the per-unit RL SOLDIERS (micro: movement, targeting, retreat), or BOTH (hybrid) — the protocol carries a general-action channel AND a per-unit soldier_obs batch. One episode is a bounded epoch of the multi-arena world; the champion is the seat that reaches the cogosseum alive with the most glory. Entertainment is the optimal strategy — boring agents starve, entertaining agents thrive.

## Leagues

- `league_d0f34381-669e-4f6a-9e7a-28ab16ce42e3` — Muster

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `muster-default` — Muster Default General: Creds-free heuristic general mirroring Muster's scripted-general priorities: mine-first economy, concentrate fire on the lowest-HP enemy only when locally favorable, then run the full naval chain (dock → shipyard → escorted transport → launch inward toward the cogosseum). A COMPETENT-BUT-BEATABLE baseline — held to the strong scripted general's level, not a weak shadow — and the default a submitted optimizer is expected to beat. (run: `python -m coworld_pkg.player.player`)
- `muster-rl-soldier` — Muster RL Soldier: Trained per-unit RL soldier micro (the v34 hybrid multi-head policy, run as a dependency-light numpy forward pass) paired with the bundled heuristic general. It exists to DEMONSTRATE the RL-soldier submission shape — the engine ships each unit's observation + action masks + role in the per-seat protocol's soldier_obs batch, and this policy returns per-unit move/target/mode actions — NOT as a co-equal winner: the soldier fights its units well, but as a whole-army driver at full scale it underperforms the bundled general (it doesn't drive economy/the inward race), so it is a SHAPE EXAMPLE, not a strong baseline. A submitted policy image can drive the general, the soldiers, or both (hybrid). (run: `python -m coworld_pkg.player.soldier_player`)

## Baseline

- Default example: `muster-default` (`coworld_pkg.player.player`) — the
  competent creds-free heuristic GENERAL. Strongest example too: the
  `muster-rl-soldier` is explicitly a shape demo that underperforms the
  general at full scale.
- Our policy: **Ilya Muromets** (`ilya_muromets/`) is a Nim command-player
  rewrite of that default general's `_decide` priorities: mine-first economy
  on explicit coords from `available_building_positions`, favorable-only
  focus fire on the lowest-HP military target, worker/military recruiting,
  the full escorted naval chain (dock → shipyard → transport + fighter →
  embark general-first → launch inward), ring-2 honor hunting/search, and
  every bounded recovery/finale verb (emergency_commission,
  beachhead_extract, beachhead_regroup, last_signal relay routing,
  apex_last_stand). It answers only the `observation` channel (general
  shape); `soldier_obs` is deliberately never answered so the engine micro
  drives units. Same env tunables as the Python baseline
  (MUSTER_DEFAULT_NAVAL_AT etc.).
- Protocol: `muster.player.v1` — replies are a single Muster action dict,
  NO envelope; host repairs/falls back on absent ticks. Spec fetched from
  Metta-AI/muster `coworld_pkg/game/docs/player_protocol_spec.md` (the
  `main`-branch raw URL 404s; use the GitHub contents API).
- Upload: scripted command player, NO secret-envs (no USE_BEDROCK needed).
- Omitted vs Python baseline: the `_intent`/`_event_plan` observability
  block (engine-ignored planner narration); decisions are identical.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Raise MUSTER_DEFAULT_FIGHTERS to 2 escorts before the first crossing —
  the docs call the unescorted hull a "death convoy"; check whether the
  extra crystal delay costs more than interceptions do.
- Bank glory more aggressively: gate `launch_boat` on a glory threshold so
  we never sit at ring 3's 1x patronage once the company is shippable
  (lower NAVAL_AT from 3 to 2 and measure arrival tick).
- Ring-2 honor campaign tuning: the baseline hunts with `honors < 3`;
  try HONORS_MIN=4 (the docstring mentions apex ticket gates at >= 4) to
  avoid a refused ring2→cogosseum launch.
- Hybrid shape: answer `soldier_obs` for FIGHTER escorts only (kite with
  ATTACK_MOVE mode) while leaving ground units on engine micro — the
  soldier channel opt-in is per-unit, so this is low-risk.
- Crumble-window rush: when `crumble_countdown <= 90` the baseline still
  requires 2 crew; try allowing a general-only escape launch (crew >= 1)
  and compare survival/forfeited_glory.
- Entertainment meta: glory mints from theatrical deeds (flanks,
  comebacks); try `general_stance` frontline earlier in the cogosseum with
  focus "enemy_general" to farm duel glory once military >= 2 instead
  of 3.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Ring-2 honor campaign is one honor short of the engine's apex ticket (docstring gates ring2→cogosseum at battle_honors >= 4). At honors=3 we set ticketComplete, stop fighting, and spam a refused launch — idle until wipe, which forfeits unbanked glory (standing is all-time-high banked glory; daveey/muster-outpost-general peaks 5.9M by actually entering). | Default MUSTER_COGOSSEUM_BATTLE_HONORS_MIN 3→4 so we keep the ring-2 frontline hunt until the launch is legal. | | | |
