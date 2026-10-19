# MOBA leader replay analysis

Nim extractor for hosted MOBA v1 replays. Twelve completed team-variant
games (2 seats, 5 heroes each) with `daveey-scripted:v39`,
`co-gas-moba-topstack-richard:v7`, and
`co-gas-moba-topstack-relhalpha:v3`. Round 3730 is included. Downloads
and tallies live under `research/evidence`.

Replay body is post-clamp actions only (`MOBA` + header JSON +
`tick_count * 60` bytes). Positions are not stored. Trajectories were
not recovered. Header `seed` plus actions would fully determine an
episode if the pinned wasm were re-run; that was not done.

This report does not make hosted XP or ranking claims. Winner labels
below are the replay header field `result.winner` (0 radiant, 1 dire)
for these twelve files only.

## Format

Ground truth: `sims/moba/server/cogame_moba/replay.py`,
`docs/PROTOCOL.md`, `vendor/upstream/moba.h`.

- Magic `MOBA`, u8 version 1, u32le header length, UTF-8 JSON, then
  10 x 6 uint8 per tick.
- Action columns: `vel_y`, `vel_x`, target filter, `use_q`, `use_w`,
  `use_e`. Highs `[7, 7, 3, 2, 2, 2]`.
- Velocity decodes as `(a-3)/3`. Center `(3,3)` is hold. Scripted
  policies use only bins `{0,3,6}` (full 8-direction plus hold).
- Target `0`/`1` scan every hostile in vision 5. Target `2` scans
  heroes and towers only (`step_players`, moba.h).
- Skills try Q, then W, then E, then basic attack. Failed skills
  fall through.
- Engine no-op is `[3,3,0,0,0,0]`. The same row is also a legal
  intentional idle, so per-hero "noop" is not a disconnect.
- Pids 0-4 radiant, 5-9 dire. Role order support, assassin, burst,
  tank, carry. Assigned lanes: tank top, assassin/burst mid,
  support/carry bot.

Parser checks magic, version byte, header JSON, `format_version`,
`sim_wasm_sha256`, `config`, `result`, `tick_count`, body length, and
every action against `ActHigh`. Tests in `tests.nim` cover the failure
cases.

All twelve files used wasm sha256
`b76a9c4cdcc7e4a47c973d4029737a832e0b678646c6a512f5653d3e98f1b8c8`.
Every velocity sample was discrete `{0,3,6}` (analog rate 0). All
three leaders are scripted-like, not analog neural.

## Replay IDs

Seat 0 is radiant (`player_names[0]`). Dashboard `policies` strings
are name-sorted, not seat-sorted. Trust the replay header names.

| Round game | Episode request | S3 replay | Radiant | Dire | Ticks | Header winner |
|---|---|---|---|---|---|---|
| 3721-g6 | `ereq_c7ef3e65-55ea-40db-8b80-56068bdd3b33` | `e496a96e-9ed2-4081-b3c5-4adca80fb60b.replay` | daveey | richard | 2209 | radiant |
| 3724-g7 | `ereq_136a93ff-ced0-468a-ad12-a90f2161cc35` | `8958a24b-7d37-482d-a27c-2158d0f835d3.replay` | daveey | richard | 2001 | radiant |
| 3726-g5 | `ereq_a2ffc49f-6287-4e12-8ab8-9de1e573db48` | `97b4f799-3635-4860-a69f-40e6593dbeb7.replay` | relh | daveey | 1049 | dire |
| 3727-g4 | `ereq_bf04d3dd-63c4-490a-84e7-511c069ae4b2` | `ec66a83d-cb23-48b9-9667-df13c1d59235.replay` | daveey | richard | 2993 | dire |
| 3728-g9 | `ereq_421b1472-c42e-4698-ae08-01aac6a33e77` | `dcb93b58-567f-4787-a048-a9efdc7143c5.replay` | richard | daveey | 1177 | dire |
| 3729-g4 | `ereq_a050becd-d510-49fc-8e2a-416af4b6baee` | `181f470d-fd9f-49fb-b1ce-7b9bcd9aca5b.replay` | relh | daveey | 1422 | dire |
| 3730-g4 | `ereq_cc5f0040-9852-4f3b-8f5e-1c8076a2ee33` | `8987babe-897f-450f-b2e3-eb7ab8932181.replay` | daveey | richard | 1827 | radiant |
| 3731-g13 | `ereq_21892397-6067-4e32-a93b-dbf8766b7849` | `cd13c99f-4527-456f-a9e0-81be68b159f1.replay` | relh | daveey | 1318 | dire |
| 3731-g16 | `ereq_9338f381-bd8a-4b33-a12b-6e40d958a83a` | `7287f7c3-6eac-4c39-ae34-05154c937e8b.replay` | daveey | richard | 2554 | dire |
| 3731-g23 | `ereq_9d7d2742-53ad-47e6-afb0-7e4de34db89f` | `98bea1fb-c623-444f-808d-c0d2707241df.replay` | daveey | richard | 2534 | dire |
| 3731-g24 | `ereq_535fdf79-2c12-4e4b-82c2-9cbc21f24f23` | `bc51aa17-7e47-4590-b995-ab33c7747f5e.replay` | richard | daveey | 1617 | dire |
| 3731-g34 | `ereq_ab0ee67d-2642-4140-bfab-c0936412e85d` | `18b434e3-be09-4514-b79c-9d2e0005addb.replay` | daveey | richard | 1352 | radiant |

S3 prefix: `https://softmax-public.s3.amazonaws.com/replays/`.
Every episode ended `end_reason: "ancient"`. Tick counts 1049..2993,
far under the 40000 cap. `final_tick` matched body `tick_count`.

Sample bias: picker preferred daveey, so every game includes
`daveey-scripted:v39`. Richard appears in 9 games, relh in 3. No
richard-versus-relh file was downloaded.

## Results

### Stacking versus split

Intra-team cosine of the 9-bin direction histograms (including hold):

- `co-gas-moba-topstack-*`: 0.91 .. 0.99
- `daveey-scripted:v39`: 0.53 .. 0.80

Four-of-five hold-together rate is also higher on the topstack
policies (often 0.14 .. 0.44) than on daveey (often under 0.14, twice
exactly 0).

That matches the policy names. Richard and relh move the five heroes
as one blob. Daveey does not.

Round 3730 game 4 (`ereq_cc5f0040-9852-4f3b-8f5e-1c8076a2ee33`),
daveey radiant versus richard dire, shows the split on daveey's
non-hold motion:

- Tank: north 16%, hold 50% (assigned top).
- Assassin: northeast 26%, hold 15% (assigned mid).
- Carry: northeast 28%, east 21%, hold 14%. Early third is 45% east
  (bot corridor), late third 58% northeast (bot lane turning toward
  the dire base).
- Support: hold 71%.
- Burst: hold 56%.

Richard's dire support in the same game: hold 36%, west 28%, south
23%. West is the dire bot axis, south the dire top axis. The five
dire histograms still match each other (cosine 0.968), so the group
is on one mixed push, not three assigned lanes.

Lane votes that include hold mostly read `retreat_or_hold`. That is
hold dominating the vote, not a fountain path. Non-hold bins are the
useful lane signal.

### Hold, no-op, target filter

Hold is the most common "direction" on supports, bursts, and tanks.
Daveey support hold is often 60-71%. Daveey assassin/carry hold is
often 8-16%. Topstack seats hold more uniformly across all five
roles.

Per-hero rows equal to `[3,3,0,0,0,0]` are 0-18% of ticks, highest on
support and burst. Max run was 87 on one burst. Because a seat sends
five rows, a single hero idling is not the strike-rule seat no-op.

Target filter 2 (heroes+towers) is 70-95% of ticks. Scan-all is the
remainder. That matches the scripted rule "scan everything only when
creeps are up, otherwise do not aggro neutrals" (`moba.h` scan flags).
Header `agent_stats.neutrals_killed` is usually 0-7; creeps and
towers dominate.

### Skills

Rates as fraction of ticks, typical bands across the twelve games:

| Role | Q | W | E | Mechanic (moba.h) |
|---|---|---|---|---|
| Tank | 15-27% | 5-16% | 4-11% | Q aoe-dot costs 5 mana, so it can fire almost every off-CD tick |
| Assassin | 3-22% | 0-8% | 3-35% | E is the move buff; Q is creep aoe |
| Burst | 1-8% | 2-13% | 1-13% | Hero-target nukes, so they fire less often than tank Q |
| Support | 3-8% | 0-7% | 4-12% | Hook / aoe heal / stun, all gated on mana 75-100 |
| Carry | 0-5% | 1-11% | 5-21% | E is creep aoe; Q is retreat slow |

Multi-skill flags (two or more of Q/W/E set) occur. The engine still
only executes the first success in Q-W-E order.

### End-state stats (header, not positions)

Tanks show the highest `creeps_killed` and often `towers_killed` and
`level` (examples in 3721-g6: radiant tank 39 creeps / level 7, dire
tank 36 creeps / 4 towers / level 7). Supports show the healing
columns. Ancients go to 0 on the losing side (`ancient_healths`).

These are terminal counters from `result.agent_stats`. They are not
paths.

## Limitations

- No positions, no occupancy grid, no trajectory. Claiming a hero
  "was in top lane" is a velocity-bin vote, not a cell.
- Direction cosine includes hold, so a team that idles together
  scores stacked even if the residual motion is mixed.
- `[3,3,0,0,0,0]` cannot be split into missed-tick fallback versus
  chosen idle.
- Sample is twelve games, all versus daveey, no gorynych files, no
  richard-versus-relh files.
- Dashboard game JSON `turns` was 0 on 3730-g4 while the replay had
  1827 ticks. Dashboard `policies[].agents` said 1; the replay
  `heroes_per_seat` was 5. Replay bytes win.
- Wasm resimulation was not run, so observation crops and true (x,y)
  were not reconstructed.
- Header winners are not hosted experience-request scores.

## Five strategy ideas

Isolated changes to try on gorynych, each grounded in these
distributions and in `moba.h` / the scripted reference. Not ranked
by hosted score.

1. **Five-hero stack on one corridor.** Richard and relh keep
   intra-team direction cosine above 0.91. Gorynych today assigns
   tank top, assassin/burst mid, support/carry bot (`laneForHero`).
   One experiment: send all five along tank's top polyline (lane 0 /
   3) and siege that ancient path together.

2. **Hold as the default siege action.** Leaders hold 30-70% of ticks
   on supports, bursts, and tanks. Towers deal 110-175 through vision
   5 and pick nearest L1 target. Walking while the wave is not
   soaking is the death the scripted bot already tries to avoid.
   Raise the standoff: hold outside tower vision until a friendly
   creep is strictly closer in L1, and stay held longer than the
   current 5-cell engage window.

3. **Asymmetric mobility.** Daveey's cores (assassin, carry) hold
   8-16% and spend the rest on the assigned axis (east then
   northeast for radiant carry; northeast for assassin). Support
   holds ~70%. Keep cores moving; do not make support escort them.

4. **Tank Q spam and assassin E-haste.** Tank Q costs 5 mana and
   shows 15-27% tick occupancy in every leader file. Assassin E
   (move buff) is the assassin's most-used flag, 16-35% on daveey.
   Fire tank Q whenever any hostile is scanned; fire assassin E on
   push and retreat, not only on retreat.

5. **Wait on blocked cells instead of spinning.** `move_to` fails
   into occupied cells. Gorynych's 90-degree detour after 4 stuck
   ticks can walk into a worse L1 versus a tower. Leaders' high
   hold rate is consistent with "stop and let the creep or ally
   move" rather than rotating. If the desired step did not change
   position, hold for a wave instead of detouring.

## Commands and paths

```
cd /Users/me/p/andre_von_auto/games/moba/gorynych/research
nim check replays.nim
nim check tallies.nim
nim check tests.nim
nim check extractors.nim
nim r tests.nim
nim c -d:ssl --out:extractors extractors.nim
./extractors
```

| Path | What |
|---|---|
| `research/replays.nim` | v1 parser and action-range checks |
| `research/tallies.nim` | direction, hold, skill, stack tallies |
| `research/extractors.nim` | dashboard fetch + analysis CLI |
| `research/tests.nim` | format validation |
| `research/extractors` | compiled CLI (`-d:ssl`) |
| `research/evidence/league-moba.json` | `/league/moba.json` |
| `research/evidence/rounds/3730.json` | `/league/moba/rounds/3730.json` |
| `research/evidence/games/r*-g*.json` | per-game dashboard twins |
| `research/evidence/replays/r*-g*.moba` | raw MOBA v1 bytes |
| `research/evidence/summaries/r*-g*.json` | per-game tallies |
| `research/evidence/summary.json` | rollup |
| `research/report.md` | this file |
