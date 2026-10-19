# Hosted MOBA trajectory reconstruction

Nim extractor that replays recorded actions through the exact pinned
sim wasm. Twelve completed team-variant games, same files as
`report.md`. Reconstruction of hosted episodes only.
`scoring_evidence` is false everywhere. No local games, no uploads.

Positions are not stored in the replay body. They were recovered by
feeding the recorded seed and the 10x6 action log into
`sims/moba/build/moba_sim.wasm` (sha256
`b76a9c4cdcc7e4a47c973d4029737a832e0b678646c6a512f5653d3e98f1b8c8`),
matching `server/cogame_moba/sim.py`: WASI, `emscripten_notify_memory_growth`
no-op, `_initialize`, `moba_init(seed bits, 10)`, then `set_actions` +
`moba_step` once per body tick. Whisky is the player websocket client;
the sim host is the existing Wasmtime v48 C API.

Every file below matched hosted `final_tick`, `winner`, `end_reason`,
all 10x11 `agent_stats`, and both `ancient_healths` before any occupancy
number was trusted. Action-direction votes from `report.md` are not used
as positions.

Extracted x/y/health are the policy-visible observation bytes
(`obs[484]=x`, `obs[485]=y`, `obs[487]=health*10/max`): unsigned-char
casts of the sim floats. Exact floats are hashed into `state_digest`
(not stored in the replay result). Cell occupancy is enough for lanes,
tower L1, and cover.

## Proof

Pinned wasm copied from docker image `moba-wasm-pin:f06d28fd`
(`/src/build/moba_sim.wasm`, sim commit `f06d28fd`). Hash equals every
replay header.

| Round game | Radiant | Dire | Ticks | Winner | Digest | Match |
|---|---|---|---|---|---|---|
| 3721-g6 | daveey | richard | 2209 | radiant | 2307919037 | yes |
| 3724-g7 | daveey | richard | 2001 | radiant | 2932817462 | yes |
| 3726-g5 | relh | daveey | 1049 | dire | 683868212 | yes |
| 3727-g4 | daveey | richard | 2993 | dire | 1580573687 | yes |
| 3728-g9 | richard | daveey | 1177 | dire | 1990666327 | yes |
| 3729-g4 | relh | daveey | 1422 | dire | 4045685285 | yes |
| 3730-g4 | daveey | richard | 1827 | radiant | 2714423814 | yes |
| 3731-g13 | relh | daveey | 1318 | dire | 480352411 | yes |
| 3731-g16 | daveey | richard | 2554 | dire | 4265016448 | yes |
| 3731-g23 | daveey | richard | 2534 | dire | 1984658274 | yes |
| 3731-g24 | richard | daveey | 1617 | dire | 3433902790 | yes |
| 3731-g34 | daveey | richard | 1352 | radiant | 3943572935 | yes |

Opening window is the first 300 ticks (two creep waves). Region labels
are nearest waypoint polyline within L1 16, else fountain (L1 <= 8 of
spawn) or jungle (off-corridor). Jungle here is not camp farming:
header `neutrals_killed` stays 0-7. Stacked teams' "jungle" is the strip
beside the top corridor.

## Opening occupancy (cells, not direction votes)

`report.md` inferred lanes from velocity bins. Reconstruction shows
where heroes actually sat.

Daveey splits. In 3730-g4 (daveey radiant vs richard dire, daveey
takes the ancient at tick 1826):

| Hero | Assigned | Opening top | mid | bot | fountain | jungle |
|---|---|---|---|---|---|---|
| daveey tank | top | 93.7% | 0% | 0% | 3.0% | 3.3% |
| daveey assassin | mid | 6.3% | 76.3% | 0% | 17.0% | 0.3% |
| daveey burst | mid | 3.3% | 61.0% | 0% | 35.7% | 0% |
| daveey carry | bot | 0% | 0% | 84.7% | 3.0% | 12.3% |
| daveey support | bot | 0% | 15.7% | 49.0% | 2.3% | 33.0% |
| richard all five | mixed | 48-54% top | 0% mid | 0-3% bot | 0-6% | 44-46% |

Four-plus daveey heroes in one corridor: 0.0%. Richard: 46.7%.

That pattern holds across the twelve files:

- Daveey four-plus stack rate: 0-1% in every game.
- Richard four-plus: 40-63% (one game 93.7% as radiant in 3728-g9,
  occupancy 94.7% top).
- Relh four-plus: 81-87%, occupancy 85-91% top.

Richard and relh are physically on the top corridor. The direction
cosine in `report.md` was not a false alarm, but it could not prove
this. Mid and bot are empty for the stacked seat in the opening.

Gorynych today still assigns tank top, assassin/burst mid,
support/carry bot (`laneForHero`). Against this field that is daveey's
shape, not richard/relh's.

## Tower deaths

Deaths are `agent_stat(pid, towers_killed)` rising, with the tower
index filled in when a hero later sees that cell without a TOWER tile.
The killer pid is exact. The index is exact when someone had vision.

Radiant top toward the river is T1 index 7 (51, 16), T2 index 6
(71, 17), T3 index 2 (91, 14), then T4 8 or 19, ancient 23. Dire
walking that line hits 7 then 6 then 2. That is the richard/relh
opening:

- 3721-g6: dire tank kills radiant T1-7 at 240, T3-2 at 955, T4-8 at
  1598; daveey's tank still takes dire ancient 22 at 2208.
- 3730-g4: dire tank T1-7 at 201, dire carry T2-6 at 551 and T3-2 at
  899; daveey assassin takes dire T1-13 (mid T1) at 786; daveey tank
  takes dire ancient 22 at 1826.
- 3727-g4: dire assassin T1-7 at 166, burst T2-6 at 246 and T3-2 at
  537, then T4s and radiant ancient 23 at 2992 (richard wins).
- Relh radiant in 3726-g5: support takes dire T2-10 at 203; tank takes
  T4-9 at 606 and T4-18 at 956; daveey still takes radiant ancient 23
  at 1048.

Stacked teams take the outer top T1 before tick 250 in every
richard/relh file. Daveey's split gets a tower on a different lane
later (assassin or carry), then often the ancient anyway. The stack
does not always convert T1 into the ancient; 3721 and 3730 are
daveey wins after richard took the top T1-T3 chain.

First tower is almost never daveey's support (exposed 0% in several
files). First tower for the stack is tank, assassin, or burst — the
blob, not a designated laner.

## Tower-target exposure and cover

A hero is in range when L1 to a live shooting enemy tower is <= 5
(TOWER_VISION). Covered = a friendly creep is visible in the 11x11
crop and strictly closer in L1 than the hero (the soak towers
actually pick). Exposed = in range without that soak. Ancients do
not shoot.

3730-g4 rates over the whole episode:

| Hero | In range | Exposed | Covered |
|---|---|---|---|
| daveey support | ~0% | 0.0% | 0.0% |
| daveey assassin | 5.2% | 2.1% | 3.1% |
| daveey tank | low | 0.4% | 0.0% |
| daveey carry | | 0.4% | 3.0% |
| richard support | | 6.1% | 1.7% |
| richard assassin | 7.3% | 4.8% | 2.5% |
| richard tank | | 6.3% | 0.7% |

Stacked tanks sit in tower L1 without a closer creep (3728-g9 richard
tank exposed 12.9%; 3731-g23 richard tank 11.0%; 3727-g4 richard tank
10.1%). Daveey's cores more often have the wave closer than they are.
Daveey support almost never enters shooting range.

That matches the scripted siege rule already in gorynych (hold at
standoff unless a creep is strictly closer) and shows the stacked
leaders violate it: five bodies on one T1, the tank eats shots.

## Actual assassin E

Assassin E is `skill_assassin_move_buff`: mana 100, `move_modifier=2`,
`move_timer=25`, `e_timer=100`. The engine tries Q, then W, then E
(`step_players`). A flag is not a fire.

Fire = `use_e` set and `e_timer` rose across the step.

3730-g4, daveey assassin pid 1: 493 flags, 10 fires, 483 blocked.
Richard pid 6: 34 flags, 8 fires, 26 blocked. Eight of daveey's ten
fires and all eight of richard's were at health tenths <= 3 (the
retreat threshold). Two daveey fires were on the fountain cell after
a teleport.

Across all twelve games, assassin E fires per seat are 4-23, not
hundreds. Low-health fires are 3-22 of those. Fountain fires are
0-4. The 16-35% E flag rate in `report.md` is almost entirely Q/W
priority, cooldown, or mana eating the button. Leaders use E as a
panic haste, not a push haste.

Gorynych already gates assassin E on `RetreatMode`. That matches
what the leaders actually land, not what they flag. Dual-flagging
Q+E (assassin Q is creep aoe, also mana 100) is why the flag count
is huge and the fire count is not.

## One-change policy ideas

Ranked by how directly the reconstructed cells contradict gorynych
as shipped, given a field that is always daveey / richard / relh.
Each is one isolated change. Not ranked by hosted score.

1. **Stack five on tank top.** Occupancy, not direction cosine:
   richard/relh spend the opening on top (40-93% four-plus on that
   corridor, 0% mid). Gorynych's `laneForHero` split is daveey's
   layout. One experiment already exists (`experiments/topstack`);
   this is the cell-level reason to keep that family and not treat
   the earlier cosine as enough.

2. **Do not flag Q when you want assassin E.** Actual E fires are
   ~10/game because Q is tried first and costs the same 100 mana.
   Keep the retreat-haste rule, but when `use_e` is set, leave
   `use_q` and `use_w` at 0 for that tick. That is a one-line action
   change, not a new mode.

3. **Hold the stacked tank out of L1 5 unless a creep is closer.**
   Stacked tanks are the most exposed bodies (10-13% of ticks).
   Gorynych already has this soak test; the occupancy experiment
   should not drop it when five heroes share a tower. Walking the
   blob onto T1 without a wave is the death the scripted bot was
   written to avoid.

4. **Keep daveey-style cores on assigned lanes if you do not stack.**
   When daveey wins after richard took top T1-T3 (3721, 3730), the
   reconstructed paths are still tank-top / assassin-mid / carry-bot.
   The ancient hits come from the split, not from rotating everyone
   onto the lost corridor. If a follow-up is "split harder", the
   support already contributes almost no tower-range time; do not
   escort it onto the stacked side.

## Limitations

- x/y are uchar casts, not the float bits inside `state_digest`.
- Tower index on a death needs vision of that cell; killer pid does
  not.
- Cover only sees creeps in the acting hero's 11x11 crop.
- Sample is twelve daveey-containing games. No gorynych reconstruction
  here.
- Header winners and these occupancy counts are not hosted XP scores.

## Commands and paths

```
cd /Users/me/p/andre_von_auto/games/moba/gorynych/research
nim check observations.nim
nim check reconstructs.nim
nim check test_trajectories.nim
nim check trajectories.nim
nim r tests.nim
nim r test_trajectories.nim
nim c --out:trajectories trajectories.nim
./trajectories evidence/replays/r3730-g4.moba evidence/wasm/moba_sim.wasm
```

Wasm extract (already done): `docker create moba-wasm-pin:f06d28fd`,
`docker cp <id>:/src/build/moba_sim.wasm evidence/wasm/moba_sim.wasm`,
`docker rm <id>`. Hash
`b76a9c4cdcc7e4a47c973d4029737a832e0b678646c6a512f5653d3e98f1b8c8`.

| Path | What |
|---|---|
| `research/wasmtimes.nim` | Wasmtime v48 + WASI bindings |
| `research/runtimes.nim` | Sim host matching `sim.py` |
| `research/observations.nim` | Obs decode, towers, regions |
| `research/reconstructs.nim` | Replay through wasm, match end state |
| `research/trajectories.nim` | CLI |
| `research/test_trajectories.nim` | Format + pinned r3730-g4 proof |
| `research/evidence/wasm/moba_sim.wasm` | Pinned sim |
| `research/evidence/trajectories/r*-g*.json` | Per-game occupancy JSON |
| `research/trajectories.md` | This file |
