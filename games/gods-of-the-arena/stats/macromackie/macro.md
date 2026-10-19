# macromackie macro plan: 20 replays vs khors v270 (GotA 2026.10.8.1)

macromackie won all 20 games. It keeps the 4+1 edge-lane split only until about 3:00. After that it never defends its base. Every hero then heads for our god, through mid or by portal to its most forward tower. It buys back on every death it can afford. It clears our mid lane by about 9:00 and kills the god at 12:21.

The four heroes do not stay together. By minute 4 the pack is spread across the map, so "four heroes push one edge lane" only describes the first three minutes.

## How to reproduce

- **Source:** `/private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad/recon/polyworld_108/tmp/gota_timeline/mack_macro.nim`
- **Binary:** `/tmp/claude-501/mack_macro`
- **Build**, from the worktree root `.../scratchpad/recon/polyworld_108`:
  `POLYWORLD_DEPS=/private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad/recon/deps108 nim c --hints:off --path:examples/gods_of_the_arena -d:headless -d:release -d:replayEvents --nimcache:/private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad/recon/nimcache_mack_macro -o:/tmp/claude-501/mack_macro tmp/gota_timeline/mack_macro.nim`
- **Run**, from `.../scratchpad`, two at a time:
  `awk '{sub(/\.rows$/, ".raw", $1); print $1, $2}' hmack/h2h.txt | xargs -P 2 -n 2 sh -c 'id=$(basename "$0" .raw | sed "s/ereq_//; s/-.*//"); /tmp/claude-501/mack_macro "$0" "$1" "$id" 240 > mmacro/$id.out'`
- **Collate:** `/tmp/claude-501/mack_macro collate mmacro/*.out > mmacro/collate.txt`
- **Usage:** `mack_macro REPLAY OURTEAM [LABEL [TRACK_TICKS]]`. The optional last argument prints one compact position line for all 10 heroes every N ticks.
- **Outputs:** `/private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad/mmacro/*.out` (20 files) and `.../mmacro/collate.txt`.

I only used the 20 replays already in `hmack`. Nothing was downloaded, no source was fetched, no games were run, and no more than 2 replays ran at once.

**Definitions used throughout:**
- Positions are sampled every 12 ticks.
- **Home** is within 14 tiles of a team's own god.
- A hero is **on a lane** when it is within 9 tiles of that lane's creep route; otherwise it counts as jungle.
- A **base incursion** means an enemy hero within 32 tiles of the god.
- **Lanes by mirror symmetry:** "main" is the macromackie pack edge (Red lane 2, Blue lane 0), "far" is the other edge.
- **Coordinates:** BASIC tile = world tile + 57.5.
- **Tower attack ranges** from `sim.nim`: outer 9.0, inner 9.5, gate and guard 10.0 tiles.

## 1. Lane per seat in the opening (0:20–2:30)

| Side | Pack (lane share 0.99–1.00) | Solo (lane share 0.94, home 0.06) | Games |
|---|---|---|---|
| macromackie Red | 100, 101, 102, 103 on lane 2 | 104 on lane 0 | 10/10 |
| macromackie Blue | 105, 107, 108, 109 on lane 0 | 106 on lane 2 | 10/10 |
| khors v270, both sides | all 5 on mid | — | 20/20 |

- The solo is ordinal 4 for Red and ordinal 1 for Blue. This matches the v272 lane code.
- Departure is identical in all 20 games:
  - The pack leaves the home circle at tick 324–348 and is 30 tiles out at 516–576.
  - The solo leaves at 660 and is 30 tiles out at 852.
  - khors leaves at 360–372.
- Lane corners in BASIC coordinates: lane 2 is (103.0, 104.0) and lane 0 is (12.0, 11.0). The gods are Red (104.6, 10.4) and Blue (10.4, 104.6).

## 2. When the pack turns from the corner toward our god

- **0:50 (tick 1200, all 20 games):** at least 3 pack heroes are within 10 tiles of the corner.
- **0:50 to 2:05:** the pack waits at the range edge of our outer tower on its lane. Median distance from that tower is 9.7 tiles [8.0–10.1], against a range of 9.0.
  - For a Red macromackie the tower is Blue tower 25 at BASIC (94.5, 103.8).
  - For a Blue macromackie it is Red tower 10 at (20.5, 11.2).
- **2:05 [2:04–2:06], 20/20:** that outer tower falls with 4 heroes and 3 creeps there. The killing blow is often a creep.
- **The turn follows the tower's death, not a clock.** At least 3 heroes are 12 or more tiles past the corner at 2:14.5 [2:13–2:16.5].
- Three heroes are within 70 tiles of our god at 2:25 and within 50 tiles at 2:40 [2:37–2:51].
- **3:26 [3:05–4:28], 17/20:** the main-lane inner tower falls.
- **The main-lane gate tower is never killed (0/20).** Three or more heroes got near it in only 5/20 games.

## 3. Objective timeline

macromackie attacking khors, median [IQR], with the number of games where it fell:

| Structure | Time | Games | Heroes present | Own creeps present |
|---|---|---|---|---|
| Main outer | 2:05 [2:04–2:06] | 20 | 4 (pack) | 3 |
| Main inner | 3:26 [3:05–4:28] | 17 | 3 | 4 |
| Far outer | 4:19 [2:40–4:57] | 19 | 1 [0.5–1] | 3 |
| Mid outer | 4:48 [4:31–5:16] | 20 | 2, including the solo in 16/20 | 5 |
| Far inner | 6:10 [5:38–6:35] | 10 | 1 | 5 |
| Mid inner | 6:30 [5:44–7:27] | 20 | 2 | 4.5 |
| **Mid gate (mid lane cleared, guards exposed)** | **8:55 [7:54–11:49]** | 19 | 4 [3.5–4.5] | 2 |
| Mid barracks (first) | 9:19 [8:07–11:52] | 19 | 4 | 4.5 |
| First guard | 11:54 [11:28–12:39] | 20 | 2 | 0 |
| Second guard | about 12:03 | 20 | 2 | 0 |
| **God** | **12:21 [11:45–13:10]** (Red side 12:21, Blue side 12:31) | 20 | 2.5 | 0 [0–8] |
| Far gate | 12:16 | 4 | — | — |

- Three macromackie heroes are within 15 tiles of our god at 10:03 [8:28–11:55].
- The shortest game ended at 9:48 and the longest at 18:05.
- 75% of macromackie hero damage on structures is dealt with one of its own creeps within 10 tiles (khors 80%).

**khors v270 objectives:**
- Mid outer at 1:01 (20/20, 5 heroes) and mid inner at 1:30 (20/20, 4 heroes).
- After that: an edge outer in 10/20 games at 8:11, the mid gate in 3/20 games at 5:57.
- khors never reached the guards with 3 or more heroes in 18 of 20 games.

## 4. Pack cohesion and team position over time

Medians across games, by minute:

| Minute | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| macromackie pack mean pairwise distance (tiles) | 1.8 | 0.9 | 15.6 | 40.6 | 63.5 | 61.1 | 50.5 | 42.2 | 43.1 | 43.6 | 37.5 | 40.6 |
| macromackie pack heroes within 8 tiles of the pack centre | 4 | 4 | 2.48 | 0.22 | 0.04 | 0.06 | 0.15 | 0.15 | 0.47 | 0.31 | 0.63 | 0.60 |
| macromackie largest group within 8 tiles (all 5) | 4.25 | 4.0 | 3.31 | 2.55 | 1.82 | 1.77 | 1.88 | 1.98 | 2.47 | 2.75 | 2.43 | 2.82 |
| khors largest group | 5.0 | 3.96 | 2.04 | 2.07 | 1.60 | 1.69 | 1.69 | 1.35 | 1.31 | 1.07 | 1.03 | 1.00 |
| macromackie heroes on main / mid / far lane | 3.0/0/0.5 | 4.0/0/1.0 | 3.8/0/1.0 | 2.9/1.2/0.3 | 1.7/1.7/1.0 | 1.1/2.0/1.2 | 0.7/2.2/1.2 | 0.8/2.7/0.7 | 0.5/2.7/0.5 | 0.1/2.6/0.1 | 0.05/2.2/0.4 | 0/2.3/0.1 |
| macromackie heroes alive | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 | 5 |
| khors heroes alive | 5 | 5 | 4.45 | 4.08 | 3.76 | 3.35 | 3.06 | 2.36 | 1.97 | 1.62 | 1.32 | 1.23 |
| Median distance to the enemy god, macromackie | 112 | 92 | 69 | 86 | 74 | 63 | 66 | 50 | 39 | 33 | 31 | 47 |
| Median distance to the enemy god, khors | 98 | 37 | 103 | 108 | 105 | 107 | 109 | 117 | 120 | 125 | 125 | 120 |

- Four or more macromackie heroes regroup within 8 tiles after 5:00 at 8:02 [6:42–9:37] in 19/20 games. This is at the mid gate siege.
- Team deaths per minute: macromackie about 1 until minute 11, khors 4 to 6 from minute 2.
- **Fraction of alive time at home:** khors 0.28 [0.23–0.33], macromackie 0.08.
- **Time at each distance from the nearest live enemy tower** (fraction of alive time):

  | Distance | under 8 | 8–9 | 9–10 | 10–11 | 11–12 | 12–14 | 14–20 | 20 or more |
  |---|---|---|---|---|---|---|---|---|
  | macromackie | 0.06 | 0.02 | 0.04 | 0.11 | 0.09 | 0.03 | 0.08 | 0.54 |
  | khors | 0.04 | 0.02 | 0.01 | 0.01 | 0.01 | 0.01 | 0.05 | 0.86 |

## 5. How macromackie reacts when we push its base

| Phase | Episodes (5 s or longer) | Our heroes in | macromackie heroes that came | Our heroes lost | Its structures lost |
|---|---|---|---|---|---|
| Our opening mid dive, 1:33–1:39 | 20 (one per game) | 3.5 | **0 of 5 alive, in 20/20.** All 5 stayed 86–95 tiles away at the corner. | 1.4 per episode, to towers | 0 |
| 2:30–6:00 | 4 | 2.0 | 1.8 involved, 0.8 came from more than 40 tiles away | 2.2 | 2 episodes |
| After 6:00 | 8 | 2.2 | 1.0 involved, 0.5 came from more than 40 tiles away | 0.8 | 4 episodes |

khors, for contrast: every alive defender came in 72 of 101 episodes. khors still lost structures in 47 of those episodes and lost 3.5–5.4 heroes per episode.

## 6. The solo hero

- Leaves home at 0:27.5 and is 30 tiles out at 0:35.
- **Minutes 1–2:**
  - On its lane 97–100% of the time.
  - It moves out to about 96 tiles along the lane, roughly 20 tiles short of our outer tower.
  - It then stands at about 89.5 tiles from its own god, just short of the corner, until about 2:00.
  - In minute 2 it is pushed back to about 78 tiles.
- **Walks home at 3:29 [3:25–3:49] in 20/20 games**, with high HP (0.92) and no enemy hero within 15 tiles.
- After that it behaves like the pack heroes:
  - On its own lane only 0–28% of the time.
  - About 28–45 tiles from the pack centre.
  - Present at the mid outer, mid gate, barracks and god kills.
- Per game: 2.5 deaths, 8 kills, level 9.5 at the end.

## 7. Trips home, portals and buybacks

### Buybacks

- macromackie buys back 12.5 [9.75–14.25] times per game. khors buys back 0 [0–1.25] times.
- macromackie buys back 1 tick after death in **230 of 230 deaths where it could afford it** (the price is 100 × deaths so far).
- Gold carried at death, by death number:

  | Death | 1st | 2nd | 3rd | 4th | 5th | 6th | 7th or later |
  |---|---|---|---|---|---|---|---|
  | macromackie gold, median | 370 | 430 | 535 | 340 | 270 | 285 | 200 |
  | macromackie share it could afford | 1.00 | 0.84 | 0.78 | 0.42 | 0.26 | 0.19 | 0.04 |

- khors carries 25–65 gold at death. It could afford 87 of 969 buybacks and took only 15.
- A death that is not bought back costs 9 s + 5 s per earlier death, up to 60 s.

### Forward portals (191)

- **The destination is always the own standing tower nearest our god:** rank 0 in 189 of 191.
- 87% happen within 2 s of a respawn or buyback.
- Destinations are 94 [94–103.5] tiles from our god, which is its far-lane or main-lane outer tower.
- khors portals forward too (80% within 2 s of a respawn or buyback), but to towers of rank 1 [0–2]: rank 0 only 97 times out of 211.

### Home portals (106)

- HP 0.15 [0.07–0.21], never above 0.34.
- Nearest enemy hero 85 [36.5–101] tiles away.
- Started 21.8 [21.4–81] tiles from its own god, which is about at its gate tower.

### Walking trips out

- After a walk home, macromackie walks out down mid in 160 of 161 trips after 3:00 (pack 118 of 119, solo 42 of 42).
- Its first trip home: 46 of 80 pack heroes come back by buyback at 3:25 [3:01–4:02]; 34 walk home at 4:35 [3:21–5:04].
- Walking home has no clean HP trigger. The retreat drifts back over about 56 s and starts at HP 0.72 [0.44–0.97], so I give no threshold for it.

## 8. How the games end

- macromackie wins 20/20 by killing the god at 12:21 [11:45–13:10].
- Total team deaths per game: macromackie 13 [9–19], khors 47 [44–52]. Kills: 39 against 11.
- 23% of macromackie deaths happen within 14 tiles of our god, in the final siege.
- Our heroes die mostly on mid (524 of 969 deaths) and at home (154).

## 9. Minimal macro rules that reproduce macromackie's plan

1. **Opening lanes.**
   - Red: ordinals 0–3 attack-move to the lane 2 corner (103.0, 104.0); ordinal 4 goes to the lane 0 corner (12.0, 11.0).
   - Blue: ordinals 0, 2, 3, 4 go to (12.0, 11.0); ordinal 1 goes to (103.0, 104.0).
   - The pack is out by tick ~340 and the solo by tick 660.
2. **Corner hold.** Once at the corner, stay 9.5–10 tiles from the enemy main-lane outer tower (range 9). Fight only creeps and heroes until the tower falls, which happens at about 2:05 with creeps.
3. **Push the lane after the outer falls.** Kill the inner tower with creeps there (3:26). Never siege that lane's gate tower.
4. **Every later trip heads for the enemy god.**
   - On respawn or buyback with a portal ready, portal to the own standing tower nearest the enemy god.
   - Otherwise walk from home toward the god, which takes the hero down mid.
   - Stop 10–12 tiles from a live tower unless own creeps are within about 10 tiles of it.
   - Attack guards and the god once exposed, even without creeps.
   - Do not wait to group up. Four or more meet at the mid gate around 8:00 anyway.
5. **Never go back to defend** while away from home. The early dive is left to the gate and guard towers.
6. **Buy back on the tick of death** whenever gold ≥ 100 × deaths, and keep a reserve of about 300–500 gold.
7. **Low HP:** portal home when HP is at or below 0.3 and no enemy hero is within about 35 tiles. Otherwise walk home.

**Where v272 differs, from the parts of `candidates/khors_v272.bas` I read:**
- It portals ordinals 0–1 home when the god is threatened.
- It sets the goal to home when there is a home threat within 20 tiles.
- It picks the forward portal tower as the one nearest the lane waypoint, not the one nearest the enemy god.

All three contradict rules 4 and 5.

## Note on the XP numbers in the request

Per team-game in these head-to-heads, median:

| XP source | khors | macromackie |
|---|---|---|
| Neutral (jungle) | 726 | 963 |
| Last hit | 1979 | 3689 |
| Hero kill | 1650 | 5850 |
| Building | 400 | 1600 |
| God kill | 0 | 5000 |

Time in the jungle is 5–6% of khors alive time against 3–4% for macromackie. **So against macromackie the XP gap is not jungling.** It comes from dying at the mid gate and from spending 28% of alive time at home. This is from head-to-heads only, not the league rounds your numbers come from.

## Caveats

- All 20 games are against v270, which dives mid at 1:01–1:41. That dive kills macromackie's own mid towers early, which is why its most forward towers are the edge outers.
- Rule 4's "head for the enemy god" fits the trip data, but these replays cannot separate it from "always go mid".
- Lanes for trips out are read where the hero first gets 30 tiles from its own god.
