# macromackie v14 in our league seat: study of 34 rosters (2026-10-09)

34 league rosters of rounds 1382-1389, seed 11000, one game each, five occupants of our seat (fast XP). Seat table: stats/stats_seats_2026-10-09.html. Analysis by workflow wf_b16be858 (5 analysts, 23 findings, each re-checked by a skeptic; numbers below are the verified ones).

# macromackie v14 seat vs our seats: study14 synthesis

**Data:** 34 real league rosters from rounds 1382-1389, one fast-XP game each at seed 11000. Only our seat changes occupant.
- `.rows` and `.seat` files cover all 34 rosters.
- Fight detail covers fewer games:
  - seat_fights: 15 mack14, 12 v307, 12 v303
  - early_lane: 14 / 14 / 10
  - seat_econ: 26 / 7 / 7
  - macro_seat: 22 / 9 / 8
  - warlock_siege: 27 v303 + 5 james23
- The 40-run replay budget was spent by the analysts. All verification recomputed saved outputs.
- 6 of the 34 v307 replays are byte-identical to v303, because our seat drafted Warlock there: 1383_06, 1384_05, 1386_09, 1386_23, 1388_06, 1389_24. Crossbowman figures below use the other 28 where stated.

## Results (W=1, D=0.5, n=34)

| occupant | W-D-L | score | paired vs v303 |
|---|---|---|---|
| mack14 | 30-2-2 | 0.912 | +0.265 (t 3.58; 15 rosters up, 1 down) |
| v303 (Warlock) | 17-10-7 | 0.647 | - |
| james23 (Warlock) | 19-5-10 | 0.632 | -0.015 (t -0.15) |
| pres | - | 0.471 | -0.176 (t -2.17) |
| v307 (Crossbowman) | 11-9-14 | 0.456 | -0.191 (t -1.98) |

9 of the 15 rosters that move toward mack are v303 draws. In 7 of those 9 the guards were damaged but left at 1312-5029 HP.

## Seat profile (means per game; collate tables)

| metric | mack14 (34) | v303 (34) | v307 Crossbowman (28) |
|---|---|---|---|
| hero kills | 16.18 | 0.82 | 4.96 |
| deaths | 6.24 | 5.32 | 10.29 |
| dead minutes | 1.29 | 1.86 | 4.93 |
| end level | 12.79 | 7.44 | 9.32 |
| gold earned | 3957 | 879 | 2471 |
| buybacks | 3.85 | 0.09 | 0.82 |
| neutral kills | 5.44 | 8.09 | 22.21 |
| seat guard+god damage | 3593 | 41.5 | 399 |
| poison bought | 19.7 | 0 | 0 |
| heal given | 0 | 7483 | 0 |

**What tracks the result.** Pearson r between the paired differences and the result difference, over 34 pairs, for v303 and v307:
- enemy guards down: 0.90 and 0.80
- team guard+god hero damage: 0.83 and 0.78
- seat level: 0.44 and 0.56
- seat dead minutes: -0.45 and -0.33
- seat kills: only 0.16 and 0.06
- the seat's own guard damage: 0.23 and 0.11

Mack's seat wins games through level, staying alive and being at the siege, not through its kill count.

## What macromackie does (verified)

1. **Poison executes.**
   - Opening: 3 Poison + 1 Health Potion, exactly the 150 starting gold, in 34 of 34 games. Our seats buy Dagger + Health in 34 of 34.
   - In 15 games it threw 89 poison bursts (77 heroes, 9 towers, 2 god, 1 barracks). All 89 killed.
   - Every hero burst was thrown in a single tick, within 6.1 tiles, right after an explicit attackTarget. The count was n = ceil(hp/35) in 76 of 77.
   - Poison finished 30-31% of its hero kills (77/258; 122/392 in the 26 econ games).
   - Restock: it holds 3 before minute 5 and goes up to 8 only from leftover gold.
   - Kills before minute 5: 2.97 per game, against 0.91 for v307 and 0.38 for v303.
2. **Short-lane tower-edge opening.**
   - Opens in the short lane in 26 of 34 games (p0 short share 0.58).
   - Holds 0-2 tiles outside enemy tower range for 20.9% of its alive time in minutes 0-5, against 0.9% for v307.
   - Median hold point (102.2, 97.4) in Red's frame. It rotates to mid by minutes 4-5.
   - At minute 5 (28 Crossbowman rosters): level 6.07 vs 3.50 and XP 1553 vs 622. Over 14 rosters: last hits 38.1 vs 12.2.
   - The lane itself explains little: mack's minute-5 XP is 1608 short, 1572 long and 1483 mid.
3. **Tower discipline (minutes 0-5).**
   - Mack spends as long inside tower range as our seats (22.8 s vs 20.0 s for v303), but a tower is on it only 0.6 s per game (v303 5.3 s, v307 3.6 s).
   - Tower damage taken: 21 per game, against 200 for v303 and 143 for v307.
4. **Fight selection.**
   - Its hero-target share falls off below an HP ratio of about 0.75.
   - Only 6% of its engagements start 2 or more levels below the target, against 51% for v307.
   - v307's 97 engagements at 2+ levels down gave 4 kills and 59 deaths.
   - Mack never switches to a hero more than 18.25 tiles away. v307 made 85 engagements from beyond 20 tiles.
5. **Buyback whenever affordable.** It bought back at 95 of 95 affordable deaths, on the next tick, with no margin. The reserve comes from income (about 1400 more gold earned by minute 8), not from capping gear.
6. **Portals.**
   - Forward-portals after 57% of respawns (v307 26%, v303 27%).
   - Goes to the tower nearest the enemy god 76 of 78 times, and lands 7.8 tiles past it, about 24.5 tiles further forward than v307.
   - Holds a scroll in 64% of minute snapshots (v303 3%).
7. **Siege.**
   - Within 20 tiles of the enemy god for 34.5% of siege time, against 5.5% (v307) and 5.6% (v303).
   - 4049 guard+god damage per game, 82% of hits from 7.5-8.5 tiles, mostly while the guard shoots mack itself.
   - Its team reaches the god 18 of 19 times vs 10 of 19 (Crossbowman rosters), and 26 of 28 vs 17 of 28 (v303 rosters).
8. **No defence and no shopping walks.** It goes home only after death, buyback or a low-HP retreat: 0 voluntary high-HP trips in 26 games.
9. **Potions.** Drinks only when missing at least 120 HP (332 of 332) and at least 36 ticks after damage (330 of 332). 12.8 drinks per game, against 4.6 for v303.

## What our seats do

**v303 (leashed Warlock).**
- Mates are as safe as with mack: mate deaths 24.0 vs 23.4, mate dead minutes 7.08 vs 7.42.
- The gap is mack's own carry output, which a healer cannot copy. Mates kill more beside v303 (26.5 vs 19.1).
- Weak spots:
  - Under-tower fights with the tower already on it: 9 of 10, giving 0 kills and 5 deaths. 13 of its 31 early deaths were inside enemy tower range.
  - Solo time: when no carry is within 30 tiles it jungles alone. Alone share in non-wins is 0.07-0.27 per phase.
  - Rarely holds a scroll. 7 of its 19 portal uses (econ games) were wasted hops from the keep to the home guard.
  - Mid presence early: games with a p0 mid share of 0.30 or more score 0.82 vs 0.47, but this is correlational.

**v307 (Crossbowman).**
- `crossed = 1` at init sends it straight down mid. Early lane: mid 25 of 28, and 2.32 deaths per game before minute 5.
- Other habits: 22.2 neutral kills per game, uphill and long hero chases, 4.93 dead minutes, rarely at the siege (within 30 tiles 14.5% vs 46.5%).

## Main gaps

- **Crossbowman seat:** level and survival. Poison executes, no uphill or long chases, and siege presence are the levers that copy mack.
- **Warlock seat:** the levers are positional only: tower aggro, which carry to stand with, and portal efficiency. Each is worth a few hundredths at most.

## Weakened or refuted ideas

- **Warlock poison.** Already tested as v306 (-0.035). For the Warlock seat, 12 of its 27 strict missed windows ended in a team kill anyway, so an execute would mostly move the bounty from an ally to our seat.
- **Gear cap to fund buybacks.** Refuted: mack spends the same on gear by minute 8 (357 vs 341). Its reserve comes from income.
- **Enemy poison as the threat.** A base-rate artefact: poison buyers make 81% of all enemy kills.
- **Base defence trigger.** Do not add one.
- **Mid-fight retreat.** Not supported: v307 still died within 5 s in 71% of samples where it was behind on HP, targeted and not attacking.

## Caveats

- One seed and 34 rosters. Fight and economy data come from 7-15 rosters per seat, and some of those subsets are selected (the v303 econ games are its weakest).
- Earlier bundled copies failed: v294 (lone-Crossbowman bundle with poison) -0.134 and v276 (replica seat) -0.075. Single changes on the Crossbowman path measured about +0.02 each (v308, v309).
- The Crossbowman seat (0.456 here) needs several stacked gains before it can challenge the leashed Warlock (0.647).
