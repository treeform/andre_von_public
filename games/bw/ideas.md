# Bw — Svyatogor

Policy: **Svyatogor** (`svyatogor`) — the giant warrior — macro war.

Coworld: `cow_03bf6e4d-fcf2-4e06-83e6-f1bdd164f33e` (coworld name `bw`)

Four-player OpenBW StarCraft: Brood War free-for-all over the bitworld sprite protocol. Each slot picks its own race. Build an army, eliminate the other players, and be the last one standing within 45 minutes.

## Leagues

- `league_803e98eb-1e5a-4b09-bf96-0f15b326e26a` — Bw

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `sleepyterran` — Sleepy Terran: Uses a one-barracks opening, produces Marines, and attacks rotating enemy start locations. (run: `/bin/sleepyterran`)
- `lazyterran` — Lazy Terran: Neutral baseline: keeps its starting SCVs mining and never trains, builds or attacks. Use it as a punching bag opponent. (run: `/bin/lazyterran`)
- `sleepyzerg` — Sleepy Zerg: Zerg swarm for a slot with race zerg: morphs Drones and Overlords from Larvae, builds a Spawning Pool and extra Hatcheries, expands to the corner minerals, and sends Zergling waves through the gate walls. (run: `/bin/sleepyzerg`)
- `sleepyprotos` — Sleepy Protoss: Two-Gateway Zealot build for a slot with race protoss: warps Pylons and Gateways, expands to the corner minerals, and sends Zealot waves through the gate walls. (run: `/bin/sleepyprotos`)

## Local baseline

~/p/coworld-bw* — our own bots: players/protoss zealot bot, sleepyzerg mods, marines kill recipe. Platform examples: sleepyterran/lazyterran/sleepyzerg/sleepyprotos.

## Baseline

- Platform default example: `sleepyterran` (one-barracks Marine rush).
  `lazyterran` is a punching bag; `sleepyzerg`/`sleepyprotos` need a
  race-mirror variant or a race request to get their race.
- Strongest known bot: OUR forked sleepyterran from
  `~/p/coworld-bw/players/sleepyterran/sleepyterran.nim` (marine-rush
  branch) — v22 recorded 4 outright victories and a kill-or-win in
  12/12 games at 43200 ticks vs 3x sleepyterran:v4. It mines hard,
  freezes SCV production while banking the first Depot, breaks the
  neutral 4000 HP Psi Disrupter gate with SCV helpers plus
  camera-click targeting (attack-move never hits neutral buildings),
  and sends 10+ Marine waves at rotating enemy bases. It requests
  race terran over the 0x89 lobby message (bw >= 0.2.27).
- Our policy: **Svyatogor** (`svyatogor/`) is that bot verbatim with
  its own protocol modules (`bwprotocol.nim`, `profiles.nim`) copied
  in; compile-time knobs: `-d:economyOnly`, `-d:maxWorkers=N`,
  `-d:gas`, `-d:expansionVetting`, `-d:expansionSweep`,
  `-d:firstAttackTick=N` (pass via docker `--build-arg
  SVYATOGOR_FLAGS=...`).
- Upload: command player, no secret-envs needed. Run path
  `/bin/policy_player`.
- Scoring: score = unit_score + building_score + current minerals +
  gas, ±1,000,000 for victory/defeat; standard variant now runs 64800
  ticks, so victories are reachable and dominate. Refuted levers (do
  not retry without new evidence): vespene gas (−428), >20 workers,
  idle-mining tweaks, economy-vs-army reallocation.
- Measurement: rotate seats (`"slot": -1`), report per (slot, policy),
  never compare across XP requests, both arms from the same commit.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

1. Reliable expansion Command Center — the only lever that adds NEW
   income instead of reallocating it (still open per prior work).
   `-d:expansionVetting` (server-vetted spots) vs `-d:expansionSweep`
   (tight dense sweep near the corner minerals); measure each alone.
2. Earlier gate breakout: winning games broke the home gate at
   t≈10194, single-kill games at t≈14154. Tune `GateHelpers` (SCVs
   chip the weaponless Psi Disrupter in complete safety) and
   `-d:firstAttackTick` so the +1,000,000 victory bonus lands more
   often inside 64800 ticks.
3. Wave economics at 45 minutes: 6-Marine waves lose to 12-SCV worker
   defense, 10+ are lethal. Retune `WaveSize`/`AttackInterval`/
   `MaxBarracks` for the longer standard episode (Marines convert
   minerals to unit_score roughly 1:1, so a big army is score-neutral
   until it wins).
4. Kill-order focus: keep hammering one dying base until eliminated
   instead of rotating targets each wave — advance only on positive
   evidence (our Marines present AND zero enemy buildings visible),
   never on "I see nothing" (neutral/enemy sprites are camera-local).
5. Home defense: detect enemy Marines/Zerglings near our mineral line
   and respond (pull SCVs to fight or hold new Marines home) — today
   every Marine leaves with the wave while raids hit the workers that
   produce the actual score.
6. Write a replay extractor for the current top players (e.g.
   docxology's daf-conqueror) and copy whatever they do better —
   required before expecting small tweaks to close a big MMR gap.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Protect gate-helper SCVs from the mining loop | Skip mining/build reassignment for SCVs not on the mineral line (HelperHomeCc=176 / HelperHomeMineral=112). The 9 wall-chippers walk inward, opposite the line; a gather order cancels that walk, and gateHelpersSent counts sends not arrivals so stolen helpers are never replaced. Breakout time is what wins at 64800 (+1e6 victory). Not the idle-mining skip (workers AT a patch), which was null. | | | |
