# Mindustry 4v4 — Polkan

Policy: **Polkan** (`polkan`), the swift centaur bogatyr who strikes first.

Coworld: `cow_e89aa419-24b0-463a-9ba4-28a1c5d03014` (`Mindustry Survival`
0.2.0, owner treeform, source Metta-AI/coworld-mindustry @49bf8e6, engine
Anuken/Mindustry @beaa1da). Local checkout: `~/p/coworld-mindustry`, engine
`~/p/mindustry`.

League: `league_5473de87-a7cc-451f-9cf1-6e1a769a89a3` (Mindustry 4v4),
variant `team-pvp`, `team_n` with two teams, `distinct_teammates`,
`insufficient_players: multiple_seats`, one episode per round every 288 min,
Elo k=32 on mean round score. With two entrants every episode is four
clones of one policy against four clones of the other (blocks: slots 0-3
blue, 4-7 red). Mixed teams start at three entrants.

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/mindustry-4v4

## Rules that matter (read from the engine)

- Score: win 100, loss 0, timeout or double kill 50. 144,000 tick cap
  since 0.2.2 (was 36,000).
- Map 128 x 96, mirrored, cores (core-shard, 1,100 HP, no armor) at
  (18, 48) and (109, 48). Each team starts with 800 copper, 600 lead,
  400 silicon, 20 phase fabric.
- Each seat flies an Alpha: flying, speed 3 units/tick (22 tiles/s),
  30 item capacity, 150 HP, build speed 0.5. Its gun has
  `buildingDamageMultiplier = 0`: alphas never hurt buildings.
- `itemTransferRange` and `buildingRange` are both 220 units (27.5 tiles)
  in this engine build. Take and deposit work from far away and apply at
  once; turret deposits stack past the 30 ammo cap.
- Duo: copper 35, build time 17.5 ticks (35 for an alpha), range 160 units
  (20 tiles), 250 HP. Silicon ammo is 12 damage, 5 shots per item, 1.5x
  fire rate. A Duo reaches a core when the core center is within 21.5 tiles.
- Turrets shoot units before buildings, then by priority (core first).
- Placement is blocked within 9 tiles of an enemy core center
  (`enemyCoreBuildRadius` 64 + 8 units). No `placeRangeCheck`.
- Unit cap is 8 per unit type (one shard). Ground factory needs power
  and makes a Dagger every 15 s.

## Coworld 0.2.1 (cow_62daad73, 2026-10-06 ~17:00Z): copper-only start

Each core now starts with exactly 100 copper and nothing else
(`state.rules.loadout = ItemStack.list(Items.copper, 100)`). Everything
else must be mined or produced. v1 broke: three seats took 30 copper each,
the core fell below a Duo's 35 and they hovered forever (round 8: 36,000
tick draw, zero Duos).

Economy facts (engine source):

- Player mining offloads every item straight into the core while within
  27.5 tiles of it (`offloadImmediately` for players). Alpha mineSpeed 6.5
  against a threshold of 50 + 15 x hardness: one copper or lead every 10
  ticks, about 6 per second per seat, 24 per second for the team. Alphas
  are tier 1: copper, lead, scrap, not coal, not sand floors.
- Mechanical drill: copper 12, 2x2, tier 2 (coal ok), 600 + 50 x hardness
  ticks per item spread over its ore tiles: about 0.34 coal/s on 4 tiles.
- Graphite press: copper 75, lead 30, 2 coal -> 1 graphite per 90 ticks,
  no power. Next to the core it dumps graphite straight in.
- Silicon smelter: copper 30, lead 25, coal 1 + sand 2 + 0.5 power/tick.
  Combustion generator: copper 25, lead 15, 1 power/tick, 120 ticks/item.
- Hail: copper 40, graphite 17, range 235 units (29 tiles), ground only
  (enemy alphas cannot soak it), 33 splash per second, 260 HP.
- Duo graphite ammo: 18 damage, 4 shots per item (72 damage per graphite)
  versus copper 18 damage per item.

## Field (2026-10-06)

Only `mindustry-defender:v2` (Andre von Houck, the bundled `base.bas`):
member 0 creeps a Duo line toward us, member 1 builds factories and solar,
members 2-3 possess Daggers and Flares. Two guard Duos at
(core + 5 toward us, core y +-4). Base vs base: blue won both seeds seen,
around tick 24,000-29,000.

## Polkan v1 strategy

Turret rush. Every seat takes 30 silicon at tick 0, flies around the enemy
core through a detour waypoint (members 0-1 above, 2-3 below), and builds
three Duos behind the enemy core, 9.5 to 20 tiles from its center and more
than 21 tiles from the predicted guard Duos. It feeds the hungriest own Duo
in range, reloads at home when empty (silicon, then copper), and shoots the
nearest enemy unit. Sites are ranked over five decisions; member m owns
ranks m, m+4, m+8 (m+12 is the spare after three failed attempts).

## Polkan v2 strategy (copper-only)

- Opening: all four seats mine the copper ore nearest the core until the
  core holds 300 copper (about tick 530), or tick 900.
- Army (members 1-3): take 30 copper each and leave together, detour as
  v1, queue three Duos each behind the enemy core, feed copper ammo,
  return home to reload (or mine) when empty. Once the core holds 30
  graphite, a returning seat builds a Hail on a 27-tile ring around the
  enemy core (the ring point farthest from enemy turrets, at least 22
  tiles from them) and carries graphite to it.
- Industry (member 0): mines copper until six Duos stand (or tick 1500),
  then mines lead to 30, builds a graphite press against the core on the
  far side from the enemy, ranks 2x2 coal footprints within 22 tiles and
  builds up to four mechanical drills, and every decision takes coal from
  a drill and deposits it in the press (both 27.5-tile instant transfers).
- Local, seed 2026: v2 beats base at tick 1390; 16/16 over 8 seeds and
  both sides, 1251-1430 ticks. Industry alone (rush disabled, scratch
  copy): press and 3 drills by tick 2100, ~0.4 graphite/s, first Hail at
  6600, the Hail killed the red core at 16055.

## Self-play (user request, 2026-10-06)

The ladder has one rival, so the user asked for self-play and set the goal
"beat polkan:v2 100% of the time, use XP requests". For this goal the
auto.md rule against comparing our own versions is lifted: candidates play
the champion head-to-head in seat-swapped hosted XP arms.

Local mirrors of v2 are races (seeds 2026, 7, 11: blue at 4182 and 4113,
red at 2504), so a faster rush alone cannot be 100%.

## Polkan v3: rush denial

v2 ranks its 16 Duo sites once, at ticks 0-24, from the empty map, and
drops a site after three failed placements. v3 runs that exact ranking
from the enemy's side (enemy core = ours, direction reversed, predicted
guards at five tiles in front of our core) to predict the 16 sites behind
our core. After its own site scan (ticks 30-54, to stay under the BASIC
instruction budget) member 0 covers those tiles with copper walls (6
copper each), then builds a guard Duo six tiles behind our core and keeps
it loaded with copper by take + deposit. v2's army arrives, fails every
placement, and hovers with 30 copper forever; alphas cannot hurt walls.
Everything else is v2.

Local (design only): v3 beat v2 on 16/16 seeds and sides (ticks
1942-5374, our core never touched); still beats base 8/8 (1870-2081,
about 600 ticks slower than v2 because of the walls).

## Field at 2026-10-06 ~18:15Z and how each rival attacks

Sources: SQL `policy_versions.player_file_content_hash` (elevated), bytes
from `s3://observatory-private/policies/files/<sha256>` (`aws --profile
softmax`). Copies in `others/`.

| policy | file | attack, in our core's frame (C, dir toward them) |
|---|---|---|
| mindustry-defender:v2, mono-mindustry-goshawk:v1 | base.bas (sha 2211f023) | guard Duos at their core - 5 dir, y +-4; creep line advances 8 tiles at a time, last step at C + 14 dir, cy - 3 (the step before is 22 tiles out, beyond Duo reach) |
| mono-mindustry-merlin:v1 | base variant (240-tick hold) | same creep as base |
| mono-mindustry-merlin:v2 | rear siege | three raiders mine to 190, detour 24 wide, build 6 Duos 14 tiles behind C (first empty tile per ring dy 0,-1,1,-2,2,-3; depth 14..10), station 17 behind; member 3 mines |
| relh-mindustry:v1, richard-mindustry:v1 | same file | every seat builds and feeds one Duo at C + 12 dir on the axis, mines when the core is low |
| polkan:v1/v2/v3 | ours | v2-ranked 16 sites behind C (v1 fails on copper-only); v3 also walls its own predicted sites and keeps a guard Duo 6 behind its core |
| mindustry-defender:v1 (benched) | survival-only base | no PvP attack; Duo ring 6 tiles around its core (its refill loop hardcodes team 1) |

Round 10 (mixed, 6 entrants): goshawk, merlin, goshawk, relh beat polkan:v3,
richard, richard, defender at tick 68129. Our one seat was member 0, which
in v3 only walls and builds industry.

## Field counter (uploaded as polkan-next:v1-v2, submitted as polkan:v4)

- Predict every rival's tiles from the empty map at tick 0-54 (v2 ranking,
  merlin slots, relh tile, base creep's last step) and have every seat wall
  them (copper walls, at most 8 orders a decision, budgeted by stock).
- Pause building while the core holds under 12 copper (`buildEnable(0)`,
  resume at 40): an alpha with live plans cannot mine, and four seats
  queueing walls at once deadlocked the economy at 0 copper.
- Rank our Duo sites at tick 360 against the enemy turrets that exist then
  (exact reach: Duo d2 441, Hail 900), skipping walled tiles; score = safe
  x 1000 + distance from turrets / 4 + far-side bonus. The far side matters:
  alphas idle in front of their own core (polkan v1 respawns hover at
  their core + 12) and soak Duo fire, so near-side sites stalled for 8000+
  ticks. Against v3 the far side is guarded, so the near crescent wins.
- Hail ring at 29 tiles (reach 30.9 to the core center): outranges a Duo
  ring six tiles around a core (defender v1), which drew at 36000 before.
- Local (design only, 144k ticks, seeds 2026 and 7, both sides): 32/32
  wins vs base, merlin v1, merlin v2, relh, polkan v1, v2, v3, defender v1;
  1889-11992 ticks.

## Coworld 2026.10.6.1 (cow_783caaed, repo 8648413): native protected PvP maps

The arena is now a built-in Mindustry PvP map: even seeds Veins (350x200,
Nucleus cores at 61,104 and 289,104), odd seeds Glacier (150x250, cores at
81,26 and 81,224). Map loadout: 200 copper. Nucleus: 6000 HP, no armor,
unit cap +24 per type. Seats fly Gammas: mine tier 2 (copper, lead, coal by
hand, about 6/s, straight into a core within 27.5 tiles), build speed 1,
70 items, gun does no building damage. **Polygon core protection**: you can
only build where your core is the nearest, so every turret rush (v1-v4,
merlin, relh, base's creep) is dead. Units are the only way to hurt a core.
Sand floors cannot be mined by players and the API has no floor query.

Unit math: Dagger 10 silicon + 10 lead, about 83 dps, 3.75 tiles/s;
Flare 15 silicon, about 20 dps. Silicon smelter: coal 1 + sand 2 + 0.5
power/tick, 1.5 silicon/s. Mechanical drill on sand about 0.4/s. Combustion
generator 1 power/tick, burns 0.5 coal/s. Adjacent producer and consumer
share power (no nodes needed). A unit factory needs its front face open:
units leave through it.

## Polkan industry (brain.bas + tools/mplan.nim)

The user asked for conveyor belts and conversion as the norm. Floors are
invisible to BASIC, so `tools/mplan.nim` plans each map and team offline
from the terrain in `maps/*.replay`: a silicon smelter against the core, a
straight conveyor trunk out to the best sand field with 2x2 mechanical
drills on both sides, a combustion generator touching the smelter, a
ground factory (front strip kept open) with two generators, and on Veins a
second smelter module and a second factory. It writes `polkan/polkan.bas`
from `polkan/brain.bas` (the BLUEPRINT line). Regenerate with:

    nim c -d:release -o:/tmp/mplan tools/mplan.nim
    /tmp/mplan polkan/brain.bas polkan/polkan.bas maps/veins.replay maps/glacier.replay

Roles: member 0 builds the blueprint in order (pausing all building below
12 copper), hand-feeds coal to smelters and generators and silicon + lead
to factories, sets factories to Daggers with a rally point. Members 1-3 mine
by stock targets (1 coal, 2 lead, 3 copper then coal when short). Member 3
sends every unpossessed Dagger at the enemy core once 12 exist, every 120
ticks. Bugs found on the way: lead 26.9 tiles from the red Glacier core was
past a 700 d2 cutoff (now 756); generators on the factory's front face
blocked unit exit.

Local vs idle: Veins 14857 (blue), Glacier 21098 (blue) / 17882 (red).

Later fixes, from hosted draws (polkan-next:v3: 74 draws in ~160, no losses):
- Ores and boulders vary by seed (floors do not): drills on ore are skipped
  at run time, the planner treats boulders as open (buildings replace them),
  and miners rescan ore continuously (a drill built over the chosen copper
  tile froze mining at 10 copper with building paused: total deadlock).
- Some Glacier seeds have no lead within 73 tiles: the ore scan reaches 80
  tiles and far ore is mined into the gamma's own 70-item hold and carried
  home.
- Unit ids above 32767 wrapped in the BASIC host (16.16 fixed point), so
  later waves could not be commanded. Workaround: first wave at 20 Daggers,
  then factory rally points on the enemy core. The user fixed the host the
  same day (coworld-mindustry 37e64ea, cow_42bd0c77): whole numbers are int32.
- Glacier's sand is a diagonal field 25-35 tiles out: the planner now also
  lays a comb of drills inside the field and routes a belt to the smelter by
  breadth-first search (17 drills a side instead of 4-5). Local vs idle:
  Glacier 15081 / 15265, Veins about 15000.

## Tools

- `tools/mreplay.nim` — MDR1 replay reader: `summary` (core HP, Duo and unit
  counts every 300 ticks), `seat <slot> [from] [to]` (position, cargo,
  non-move command statuses), `turrets` (birth, death, peak ammo).
- Local design runs (light, sequential; ~1.5 s each when the rush works):

      cd ~/p/coworld-mindustry
      tmp/mindustry/mindustry --pvp --seed 7 \
        --bot ~/p/andre_von_auto/games/mindustry/polkan/polkan.bas:4 \
        --bot coworld/mindustry/players/base.bas:4 --record /tmp/x.replay

- `tools/mxp.nim <label> <xreqs> [<xreqs> [label]]` — XP scorer: win,
  draw, loss and mean seat score; Welch t between two groups.
- `tools/mwatch.nim` — waits for a new round, ladder entry or coworld.
- `tools/mplan.nim` — offline industry planner (see above).
- `tools/mreplay.nim ... ores` (cores and nearest ores) and `at <x> <y>`
  (one building's items and state over time).
- `tools/mfield.nim <candidate> <eps> <out.txt> <opponents...>` — launches
  seat-swapped XP arms against each opponent and logs the request ids.
- `tools/mreplay.nim <replay> map` — ASCII ore map of the blue half;
  `summary` now also prints core copper/lead/coal/graphite per team and
  our drill/press/hail counts.
- XP bodies in `eps/` (polkan blue and red arms vs the defender).

## v1 timing (seed 2026, blue, from `mreplay seat` and `turrets`)

Flight is about 0.36 tiles per tick. Seats reach build range (27.5 tiles
from their sites) around tick 220-260, the twelve Duos are born at ticks
222-348, the first deposits land around tick 324, and the core dies at
495. So roughly half the game is the flight and half is killing the core.
Some deposits come back `invalid-transfer` when a teammate filled the same
Duo earlier in the same step (harmless).

## Ideas backlog

These only matter once a rival can beat or mirror the rush. Against the
defender v1 already wins every game, so no candidate can show a
significant gain on the current field.

- Faster first strike for mirrors:
  - Assign sites by approach side (north seats take sites above the core
    axis, south seats below) so each seat is in build range sooner.
  - Front sites (about 18 tiles in front of the core) are ~25 tiles closer
    to us. Guards fire at units before buildings, so front Duos fed from
    out of guard range would still race the core down. The cost is that
    enemy alphas parked in front of their core soak the fire.
  - Four Duos per seat instead of three: about the same kill time on
    paper (164 vs 172 ticks after arrival), but more ammo is needed.
- Defense against a mirrored rush: a guard Duo or two behind our own core
  so enemy rush Duos die before they finish our core. On paper this is
  too slow against a four-seat rush (a Duo needs ~5 s per enemy Duo).
- Live threat avoidance: re-rank sites when enemy turrets appear.
- If rivals defend the rear: graphite Hail (29 tiles, ground only) from a
  coal drill and graphite press.

## Experiment log

| version | change | XP id | opponents | verdict |
|---|---|---|---|---|
| v1 | first turret rush | xreq_ee0b598a (polkan blue), xreq_89397c2d (polkan red), 10 eps each | mindustry-defender:v2 x4 | 20/20 wins, ticks 441-519; submitted, placed active |
| v2 | copper-only rewrite: mine to 300, copper Duo rush, coal drills + graphite press, Hails | xreq_23d24f20 (blue), xreq_e53fd715 (red), 10 eps each; v1 baseline xreq_c6ef2542 + xreq_abd71f12, 5 eps each | mindustry-defender:v2 x4, coworld 0.2.1 | v2 20/20 wins (ticks 1260-1535, mean 100) vs v1 0 wins 5 draws 5 losses (mean 25), Welch t 9.0; submitted sub_2593eeca |
| v3 | v2 + walls on the mirror's 16 predicted Duo sites + guard Duo | xreq_69d4163d (v3 blue), xreq_c3537062 (v3 red), 20 eps each | polkan:v2 x4 (self-play goal) | 40/40 wins (20 blue, 20 red), ticks 1842-6659; v2 never built a Duo locally; vs mindustry-defender:v2 10/10 (xreq_d4001a3b, xreq_4ab1bb0b, ticks 1935-2771); submitted |
| v4 (polkan-next:v2) | field counter: wall every rival's predicted tiles (all seats), build pause, live far-side site ranking, hail ring 29 | eps/next_v2_field.txt (22 arms, 160 eps) | whole field, both sides | 158/160 wins: 150/150 vs the active field (polkan v1-v3, defender v2, goshawk v1, merlin v1-v3, relh v1, richard v1); 8 wins 2 draws (144k cap) vs benched defender v1. Uploaded as polkan:v4, submitted sub_46fe882b on the user's call |
| polkan-next:v1 | first field counter (near-side sites, 22-tile turret margin) | eps/next_v1_field.txt (140 eps) | same field | 124/140: draws vs the base family and polkan v1 as red (near-side Duos soaked by idle alphas); superseded |
| v5 (= polkan-next:v5) | native maps: offline-planned silicon industry (routed sand belts), Daggers, remote lead hauling, inner/outer builders | eps/next_v5_field.txt (170), eps/v5_newfield.txt (80) | whole field, both sides | 162/170 + 77/80, no losses; draws = Dagger trickle after the first wave, coal miner killed by camping Gammas, polkan v3/v4 Gammas harassing the Glacier corridor. Submitted sub_0990ee1a (active) |
| v6 | 20-Dagger waves then 10s (no rally trickle), 4 lead-fed Scatters at home, member 1-3 Gamma escorts over marching columns, column leash (hold leaders 8% ahead), Q16.16 guards (a divisor above 32767 crashed member 3) | eps/v6_field.txt | whole field incl. merlin v8, goshawk v2, richard v3 | pending; local: goshawk v2 and richard v3 draw seeds now win, polkan v4 corridor seed 192962285 still draws |
| v6 (hosted) | as above | eps/v6_field.txt, eps/v6_new.txt | whole field | near-perfect vs active rivals, but old polkans 6/10 (v2), 11/20 (v3), 12/20 (v4) and v5 beat it 18/20: escorts starved coal. Not submitted |
| cand14-16 (local) | escorts and leash off; staging ring 28 tiles out; Scatter chain at 30/55/80 tiles down our half of the route, lead-supplied by member 3 | local seeds 2052951229 (polkan v3 blue), 192962285 (polkan v4 blue) | polkan v3, v4 | still draws: waves die mid-map to respawning red Gammas; route Scatters 81,56 and 81,106 stuck as unfinished sites |
| cand17-19 (local) | retry skipped orders after 30 s; escort only when rich (copper 500, lead 200; members 2-3); resume our unfinished sites (contentAt reports a started site as its finished block) | same seeds | polkan v3, v4 | all route Scatters now built and loaded, still draws: only 3 lead tiles within 40 of the core on that seed, so Daggers are lead-bound |
| v5 vs new rivals | none (champion check) | eps/v5_newrivals.txt | goshawk v4, merlin v9, merlin v10 | v5 LOSES as red: goshawk v4 5/10, merlin v10 4 wins 1 draw 5 losses, merlin v9 8-1-1; blue 29/30. Veins is point-symmetric, so the armies march mirrored lanes and never meet: the enemy kills our Scatter-only (air-only) home first. Seeds in eps/v5_losses.txt; local sim reproduces (13846 vs hosted 13848) |
| v7 (cand20) | cand19 + 8 copper-fed Duos ring the core, built right after the first factory | eps/v7_field.txt (22 arms, 220 eps) | whole field incl. goshawk v4, merlin v9/v10, polkan v3-v5 | 195 wins 8 draws 1 loss of 204 scored: top 3 59/59, goshawk v4 20/20 (v5 15/20), polkan v5 18-1-0. The loss (merlin v10, seed 1483002794): member 0 tried to hand-feed a route Scatter 83 tiles away, kept the lead in hand and starved the smelter. Submitted sub_93ea367e |
| v8 (cand21) | v7 + member 0 feeds only Scatters within 22 tiles | eps/v8_field.txt (24 arms) | whole field + polkan v7 | 193 wins 40 draws 3 losses (of 236): v7 0-16-0 (two Duo rings stalemate), v5 14-3-3. Losses: once member 0 fed Duos reliably, copper sat at the 150 mining threshold and members 1-2 flipped between ores on opposite sides of the core every decision, mining nothing. Not submitted |
| cand22-23 (local) | staging ring removed (Daggers parked 28 tiles out sat inside Gamma range 30.1, outside their own 18.25); mining choice holds 300 ticks; member 3 flies only to affordable orders and sites | richard v4 draw 1119973487, polkan v4 192962285, v5 losses 1512010152, 1653120976 | | all four now win; polkan v3 2052951229 still draws (en-route attrition by respawning Gammas) |
| v9 (cand24) | cand23 + siege: every 60 ticks Daggers within 36 tiles of the enemy core attack the nearest enemy Duo within 20 tiles, else the core | eps/v9_field.txt (26 arms) | whole field + v7, v8 | 203-41-3: active rivals 187/189, v5 20/20, but v7 2-10-3 and polkan v4 9-9-0. Top 3 59/60 = v7, not significant; not submitted |
| v10 (cand26) | v9 + waves always 20 (cap 24): the gathered army guards home while rivals trickle tens | eps/v10_field.txt | whole field + v9, v7 | 221-20-2: active rivals 119/120, polkan v3/v4 32-6-0 (v9 22-15), v7 4-6-0, v9 6-5-2. Not submitted (league is mixed, see below) |
| cand27-28 (local) | lead aim for Gamma shots (bolts 3.5 u/tick = Gamma speed); all-four strike escort | polkan v3 2052951229, v4 1198205417 | | still draws; lead aim kept, strike escort dropped |
| v11 (cand31) | kin detection: each seat idles 1 s on a signature tile (core +6, -6+4m) and counts teammates on theirs; four Polkans keep member roles, a mixed team gets a Duo guardian (lowest Polkan: Duo ring only, mines the scarcest ore within 19 tiles) and miners (scarcest of 300 Cu / 200 Pb / 100 coal); no blueprint industry in mixed teams | eps/mixed_v11.txt (12 layouts x 4) vs eps/mixed_v7.txt, mixed_v10.txt; eps/v11_field.txt | league-style mixed rosters | pending; local round-29 layout: v7 lost at 23890 in the league, guardian versions held to 41933 (no mining), draw (cand30), 142835 (cand31) |
| v11 results | | eps/mixed_v11.txt + mixed36_v11.txt vs mixed_v7b.txt + mixed36_v7.txt (same layouts, 120 eps each) | mixed | v11 67-34-19 (mean 70.0) vs v7 60-25-35 (60.4), Welch t 1.83; losses 19 vs 35 (z 2.5). Submitted sub_5e2d243d. 4v4: active rivals 77/80, polkan v3/v4 37-3-0, but v10 (blue) 0-1-5 |
| cand32-33 (local) | guardian "forge": with no friendly factory by tick 9000 the guardian builds the whole blueprint and sends waves | L8 seed 1908401738, round-29 layout | mixed | cores fell 4x sooner (16984 vs 120295, 26864 vs 142835): build trips and industry spending starve the Duos. Dropped |
| (tooling) | blueprint as one packed number per order: ((kind*4+rot)*512+dx+256)*512+dy+256; source 65.8 KB -> 34.8 KB (64 KiB limit; bassy also caps 256 string slots, so MID$ decoding failed) | | | decoded orders verified identical |
| v12 (cand35) | v11 with a half-second kin signature: 3 east of each spawn (core y-3+2m), approach speed dist/6, checks at ticks 24 and 30 | eps/v12_field.txt (vs v10, v11, goshawk v4, v7); eps/mixed36_v12.txt | 4v4 + mixed | 4v4: v10 3-5-0 (v11 had 3-4-5), v7 11-4-1, goshawk v4 20/20. Mixed 36x2: 50-14-8 (79.2) vs v11 45-20-7 (76.4), t 0.49. Not significant over v11 |
| v13 (cand36) | v12 + outer Duo ring (8 more, 9-12 tiles out, kind 7) built only by the mixed-team guardian once copper reaches 200; order arrays 160 -> 180 | eps/mixed36_v13.txt vs mixed36_v12.txt, mixed36_v11.txt | mixed | mixed 36x2: 42-25-4 (76.8) vs v11 76.4, t 0.07: fewer losses, fewer wins. Not submitted. local: L8 seed 1908401738 and round-29 layout, both v11 losses (120295, 142835), now draws |
| goshawk benchmark | goshawk v4 as the mixed candidate, polkan v11 among the rivals | eps/mixed36_goshawk.txt | mixed | 41-20-10 (71.8) vs polkan v11 45-20-7 (76.4), t -0.78: our seat is worth at least goshawk's in league layouts |
| cand37 (local) | guardian builds a 10-Duo arc facing the enemy (6 and 9 tiles, +-60 deg) after tick 1800 instead of the ring, so strangers' modules (behind the core) stay free | L23 seed 21450185, Veins 1512010152 layout 3 | mixed | no gain: on L23 goshawk and merlin stall with zero lead even with the defender in our slot (their bug); on Veins our ring did not block them (team units 18 by 11700 vs 16 with the defender, arc 16). Reverted to v12 |
| v14 (cand38) | v12 + industrialist: the second Polkan on a mixed team (rank 1) builds the whole blueprint (inner and outer), runs its logistics and sends waves with siege targeting, while rank 0 guards | eps/mixed36_v14.txt vs mixed36_v12.txt | mixed | mixed36: 50-17-2 (84.8) vs v12 79.2, v11 76.4 (t 1.47), v7 68.8 (t 2.67). Two-seat layouts only (mmixed --doubled, 24x2, merlin v15): v14 22-18-7 (66.0) vs v11 29-8-11 (68.8), t -0.35; pooled with mixed36 76.5 vs 73.3, t 0.70. Not significant, not submitted. Local two-seat layouts vs v12: L0 seeds 1374955259 loss 47690 -> loss 95147, 865758467 draw -> win, L28 570345375 win 123432 -> win 67444 |
| v15 (cand40) | v14 + waves launched with move orders, siege removed (merlin v16: attack orders lock Daggers onto buildings from 19 tiles where home Gammas at 30 kill them; a move lets them shoot units first) | eps/v15_field.txt | 4v4 field + mirrors | REJECTED: relh v1 red 1-6-0 (was 10/10), polkan v4 blue 3-4-0, v7 blue 0-2-4; vs turret defences move-order Daggers stall on units. Reverted to v14. Local cand39 (same change on v14): v7 mirror seed won at 56942 (v10 needed 116194), polkan v3/v4 hard seeds still draw |
| v14 4v4 field | none (documentation of the 4v4 goal) | eps/v14_field.txt (22 arms, 220 eps) | every non-mirror bot: goshawk v4, merlin v15/v16, richard v4/v5, relh v1/v2, defender v2, polkan v3-v5 | 214 wins 6 draws 0 losses. All six draws with Polkan blue (goshawk v4, merlin v15, richard v4, polkan v4 one each, polkan v3 two) |
| v16 (cand41) | v14 + the ore scan widens from 80 to 125 tiles (latched) once a pass misses an ore: some Glacier seeds put the nearest lead 80-105 tiles out, so nobody mined lead, no smelter, no Daggers | eps/v16_field.txt, eps/mixed36_v16.txt | 4v4 field + mixed | pending; local: v14 blue draws 737892413 (goshawk v4), 849166811 (merlin v15), 963786559 (richard v4) now win (19761, 21354, 85459); polkan v3 1117396921 still draws |
| v16 results | | eps/v16_field.txt, eps/mixed36_v16.txt | 4v4 field + mixed | 4v4 213-7-0: all draws Glacier; relh v1 1204001487 has NO lead ore on the map (unwinnable for anyone), the rest are polkan v3/v4 Gammas picking off centre-corridor waves or a home army stuck below 20. Mixed 77.1 vs v11 76.4 (t 0.13) |
| v17 (cand43) | v16 + Glacier flank: mplan finds a Dijkstra walking route between the cores that keeps 35+ tiles off the core line (left corridor), emits three waypoints; waves walk them with move orders and attack the core from the last. Plus a stalled-army launch: 12+ waiting and no new high for 3600 ticks | eps/v17_field.txt, eps/mixed36_v17.txt | 4v4 field + mixed | 4v4 219-1-0 (220 eps): the one draw (polkan v5, seed 733743415) has no lead ore on the map, so 219/219 winnable games won; polkan v3/v4 40/40. vs v16 field 98.4: t 2.15; vs v14 98.6: t 1.91. Mixed 75.0 vs v11 76.4 (t -0.25, equal). Submitted. Local: all six winnable v16 draws win (21391-32274 ticks), goshawk and merlin far-lead seeds still win |
| v17 vs merlin v21 | none (new rival: Crawlers at the Dagger cap escort its waves) | eps/v17_merlin21.txt | merlin v21 | 20/20 |
| top-3 frontier runs (user request) | none: best policies vs the leaderboard top 3 (merlin v21, goshawk v4, richard v4), 20 games each | eps/top3_v17.txt, top3_v16.txt, top3_v14.txt, top3_v11.txt, v17_merlin23.txt | top 3 + merlin v23 | v17 59-1-0 (the draw, seed 1009060765, has no lead ore) and merlin v23 20/20; v16 60/60; v14 58-2-0; v11 56-4-0. No losses in 260 |

## League rounds are mixed (2026-10-07)

Each league round is ONE 8-seat episode with all six entrants dealt into two
teams (two entrants get a second seat, on the same team). member() is the
team slot, so a lone Polkan seat ran a single role: as member 3 in round 29
it spent the shared copper on far blueprint orders and never mined. 4v4
clone XP does not measure the ladder; tools/mmixed.nim deals league-style
layouts (fixed RNG, so candidates share layouts) for hosted XP.


## League log

- 2026-10-06 round 7: polkan:v1 (blue) beat mindustry-defender:v2 at tick
  443. Official ladder: Andre von Auto #1, MMR 1516; Andre von Houck 1484.
  Watch for new entrants with `tools/mwatch.nim` (exits on a new round,
  a new entrant policy, or a new canonical coworld).
- 2026-10-06 ~17:00Z: coworld 0.2.1 (copper-only start). Round 8: v1 built
  nothing, 36,000-tick draw, MMR 1516 -> 1514.
- 2026-10-06 ~17:25Z: coworld 0.2.2 (cow_7e269485, repo 65ec87f): matches
  run forty simulated minutes (144,000 ticks); nothing else changed. A
  longer clock gives the industry time when a rush fails. polkan:v2 placed
  active, v1 benched. Sanity XP on 0.2.2: xreq_b4b3de7e (blue),
  xreq_73b6785b (red), 2 eps each: 4/4 wins, ticks 1335-1422.
- 2026-10-06 round 9: polkan:v2 (red) beat mindustry-defender:v2 at tick
  1414. Ladder: Andre von Auto #1, MMR 1529; Andre von Houck 1470.

## Naming (user, 2026-10-06)

Always upload as `polkan:vN`. The `polkan-next` name (v1-v5) was a mistake;
polkan:v5 is byte-identical to polkan-next:v5, so the polkan-next:v5 field
run (eps/next_v5_field.txt) is its evidence. Candidates from here on are
polkan:v6, v7, ...

## Drill base and campaign (2026-10-07)

Survival experiments moved from the 4v4 league to building economies.
drills/brain.bas is one flyer that builds a planned base: tools/mdrill.nim
reads a map replay and lays mechanical drill rows on every copper, lead,
scrap and coal patch, a spine belt between each pair of rows and a trunk to
its own core face (lines capped at 45 ore tiles), belts before drills,
Duos on the enemy approach. Ground Zero (seed 2026, 36,000 ticks, Dagger
waves): best gross 10,633 items with 53 buildings lost (variant H).

Ground Zero has no coal, sand or titanium, so no upgrades. The campaign is
the better benchmark: `--sector <name>` in coworld-mindustry plays a serpulo
sector with its own waves and objectives, and tools/mcampaign.nim plays them
in order into campaign.md (score: sectors cleared in a row).

- Frozen Forest holds its waves until the tutorial objectives are met
  (coal, graphite press, 5 graphite, combustion generator burning, power
  node, battery, Arc). mdrill adds a tech cell to the first coal line: the
  press replaces one coal drill (neighbours feed it, graphite rides the
  belt), the generator takes a drill's corner. All 8 objectives done by tick
  18,000.
- First Frozen Forest try lost on wave 3: building spent every copper, the
  Duos had no ammo, and Maces (armor 4) shrug off copper shots. Fix: keep 30
  copper back, feed graphite once the core has 10, and an alarm (enemy
  within 30 tiles of the core) calls the flyer home to fight and feed.
  Captured at tick 126,195.
- A plan the core cannot pay for used to strand the flyer forever (no
  mining while plans are open): plans are dropped after 600 ticks of an
  empty core.
- Sector mode now keeps each sector's own wave rules (no forced timer) and
  reports objectives, the buildable area, items gathered and buildings
  lost. Campaign Ground Zero limits building to x 90-160, y 20-80 until 25
  lead reach the core, and its tutorial wants 2 Duos, 6 copper walls and a
  Scatter with ammo before waves run. mdrill reads the objectives from the
  map replay, places walls and the Scatter on the approach and puts lines
  inside the open area first. The old bot retried belts outside the area
  205 times each and the stuck orders hid the rest of the plan (22 drills
  all game); the scan now rolls on past failing orders.
- Drills on dead belts: a line that ends on another line's belt only
  checked its own belt. Lines now open with a header naming the line they
  feed, come after it, and place drills only when the whole path to the
  core stands. Idle drills (output cannot reach the core) went from 7 of
  22 to 0 of 94 on Ground Zero.
- Faster clears: nextWave() (the campaign's skip-wave button, only with no
  enemy alive) called whenever the core is calm. Ground Zero 70,100 ticks
  -> 33,094. A decision every 6 ticks made `tick() mod 30 = 15` never fire;
  per-call checks must land on multiples of the step.
- Sectors decide every tick now (aim, shoot, steer); ore and build scans
  run every sixth tick. Mindustry is not deterministic: compare bots over
  several attempts, not one run.
- Next speed lever: waves spend most of their time walking ~196 path
  steps; a forward Duo cluster fed by copper drills just outside the
  spawn's 37.5-tile drop zone (Ground Zero: (154,170), path step 55) should
  cut that by about three quarters.

## One self-planning bot (2026-10-07)

The user wants one BASIC bot and no outside planner. tools/mdrill.nim is
gone; its planner now lives at the end of drills/brain.bas and runs at the
first decision of a sector (1-5 s on the biggest maps). Sector mode in
coworld-mindustry gives BASIC what it needs: terrainAt (every resource,
buildable ground, water, spawns), sector() (wave rules, drop zone radius,
build area), spawns, objectives, wave groups and unit stats, plus roomy
limits (4 billion operations a decision, 32M array cells, 768 MiB).

- BASIC identifiers are case-insensitive (`oX` the array is `ox` the
  scalar); there is no abs, sgn or exit while.
- Every operation is charged to both the instruction and the work budget.
- The trunk router (Dijkstra over tile and heading) was the cost: one
  search seeded from all four sides of a spine's end, and a cheap
  reachability check first that remembers walled-off areas until a new
  line is laid. A* toward the core lost joins into other lines.
- Ground Zero 9:09 (old planner 9:08), Frozen Forest 14:23 (15:58).
