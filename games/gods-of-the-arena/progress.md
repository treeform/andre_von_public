# Gods of the Arena — progress

Updated 2026-09-23 PDT. Every trial with numbers: ideas.md. Fourteen-round policy comparison: stats_2026-09-22.md.

## Status
- **Engine change at round 644 (08:22 PDT)**: the league now runs coworld cow_2dd9158a (2026.9.22.2, replay version 56) with a symmetric observation frame, simultaneous resolution, integer floored scores and a hero rebalance; Aaron shipped "balance0922" files (his old bot drafting the Crossbowman first). Arms since v90 ran on the old build; v92 is being re-baselined on the new one and v102 (Crossbowman first) is the first candidate tested there.
- **Board after round 666: Andre von Auto 1,839 (#1, lead 118), Aaron 1,721, Aaron's coach 1,717, richard 1,620, relh 999.** Champion **khors:v114** since 12:18 PDT: v102 (the fighter advancing straight at the enemy god, retreating at 15%, Crossbowman drafted first) plus order hygiene: damage casts only inside the ability range (from a generated engine-constants block) and the standing attack-move re-issued only on a goal change or every five seconds. Score-neutral vs v102 (1,969 vs 1,978 over 120 vs 120, t -0.03), promoted on the user's call to stop spamming rejected orders. v102 live rounds: 2,252 (top of 648), 1,974 (top of 649), 1,443 (4th of 650); v114 live rounds: 1,979 (top of 651), 2,661 (top of 652), 1,915 (top of 653), 1,290 (4th of 654), 882 (6th of 655), 1,741 (3rd of 656), 1,198 (4th of 657), 2,030 (2nd of 658), 2,234 (top of 659), 2,438 (top of 660), 1,765 (top of 661), 1,290 (3rd of 662), 1,929 (2nd of 663), 2,169 (top of 664), 2,272 (2nd of 665), 1,589 (4th of 666). Field changed at 653: aaron-gota-portals0922-coach/-r3 (new file), richard v167. Loop stopped 20:58 PDT (goal cleared): champion khors:v114, 60 candidates v115-v174 all reverted, one false positive (v166) caught by a confirmation run. Test field h (eps/field_2026-09-22h.txt, aaron bluecenter0923 starred), v114 baseline 1,147 over 240 (eps/fh_v114a-d).
- **v56 is a fighter, not a farmer**: written fresh on the rule structure of the league's best-scoring bot (aaron-gota-micro0922: six-tick think, stutter-step after each landed hit, creep/hero/god target scoring, retreat at 24% health, tower safety, dagger/armor/axe/bow/portal/heals, restock at 500 gold, portal-home defence, advance from the lane waypoint to the enemy god). League-style test: 1,634 vs the farmer v47's 967 over 120 vs 180 games, t 4.82. First live round (634): 1,063 per appearance, second of the round behind aaron's 1,405.
- Why: league games are mixed rosters (one hero per player) and the score is E[max(0, XP − 200/min)], which pays for XP that arrives before the clock and for spread; kills and towers do that, lanes cap at ~300 XP/min. Ten single changes on the farmer (v48–v55) all failed; the fighter was the first keep since v47.
- Test methodology (`tools/gota_xp.nim --league`): ten seat bodies with nine distinct round-625 rivals around our hero, six games each, two sets = 120 games, scored on our hero alone. Per-game sd ~1,200: only effects above ~300 resolve.
- The test field now mirrors the live league (round-632 participants, both aaron bots, Jordan v363); v62 scores 1,399 there. Next: keep the loop running against the refreshed field; the board is a running mean, so holding #1 needs per-round parity with Aaron's coach.

## Tried on the fighter (one change each, vs v56, 120 vs 120)
| version | change | result |
|---|---|---|
| v57 | buy back whenever affordable | −133, t −0.84, revert |
| v58 | think every three ticks | −152, t −0.96, revert |
| v59 | every seat takes mid | −115, t −0.73, revert |
| v60 | vitality elixirs instead of potions | −187, t −1.19, revert |
| v61 | retreat at 35% | −228, t −1.48, revert |
| v62 | towers and barracks beside our creeps become chosen targets | **+408, t 2.17, kept and submitted** |
| v64 | advance tower by tower | −124, t −0.78, revert |
| v65 | feeder hunting (+250 on heroes two levels below us) | −22, t −0.10, revert |
| v66 | building bonus +300 | −124, t −0.60, revert |
| v67 | kill securing (+600 on heroes at twice our damage) | +131, t 0.61, revert |
| v68 | kiting for ranged heroes (refreshed field) | +50, t 0.21, revert |
| v69 | Crossbowman drafted before Arcanist | −96, t −0.42, revert |
| v70 | non-carries avoid healthy heroes | −72, t −0.32, revert |
| v71 | every seat portals home to defend the god | −80, t −0.34, revert |
| v72 | no stutter-step after landed hits | **−770, t −3.79, revert**: the stutter-step is the fighter's biggest single mechanic |
| v73 | bow before other gear for ranged carries | −209, t −0.91, revert |
| v74 | restock gear at 300 gold | −215, t −0.94, revert |
| v75 | heal potion below half health even in fights | −66, t −0.28, revert |
| v76 | retreat at 15% | +56 at 240 vs 180, t 0.33, revert |
| v77 | stutter-step away from the target | −140, t −0.71, revert |
| v78 | the leader's object scan window | +106, t 0.48, revert |
| v79 | early aggression (+150 on heroes in the first three minutes) | +72, t 0.34, revert |
| v80 | sticky-target bonus +250 | +4, t 0.02, revert |
| v81 | attack-move every 12 ticks | +32, t 0.15, revert |
| v82 | three heal potions | +41, t 0.18, revert |
| v83 | armor before dagger | +5, t 0.02, revert |
| v84 | tower safety at 85% | −34, t −0.17, revert |
| v85 | mana potions for casters | +59, t 0.29, revert |
| v86 | focus fire on heroes an ally attacks | +31 at 240 vs 180, t 0.18, revert |
| v87 | never target the god while a guard tower stands | −51, t −0.24, revert |
| v88 | draft without the same-role penalty | −131, t −0.68, revert |
| v89 | advance past the waypoint only with an ally near | **−856, t −5.51, revert**: the lone advance is as essential as the stutter-step |
| v90 | advance at the enemy god from the first tick, no lane waypoint | **+323 at 360 vs 240, t 2.15, kept and submitted** |
| v91 | no restock trips | −129, t −0.67, revert |
| v92 | retreat at 15% (on v90) | +206 at 480 vs 480, t 1.64; promoted on the user's call |
| v93 | early aggression (on v92) | −83, t −0.38, revert |
| v94 | heal at 40 missing health | −214, t −1.05, revert |
| v95 | aaron's object scan window (on v92) | +37, t 0.19, revert |
| v96 | buildings +250 in target scoring | **−496, t −3.67, revert** |
| v97 | never buy back | −338, t −1.90, revert |
| v98 | cast only within attack reach | +16, t 0.08, revert (hygiene, no score effect) |
| v99 | leave the keep at 70% health | −217, t −1.18, revert |
| v100 | order hygiene (in-range casts, no identical re-issue) | −21, t −0.10; score-neutral, halves the spam |
| v101 | barracks above towers | −449, t −2.57, revert (old build) |
| v102 | Crossbowman drafted first (new build, new baseline) | **+589, t 2.68, kept and submitted** |
| v103 | kiting (on v102) | −22, t −0.09, revert |
| v104 | Arcanist drafted above the Ranger | −175, t −0.74, revert |
| v105 | retreat at 24% (new build) | −294, t −1.30, revert |
| v106 | bow first for the Crossbowman | −116, t −0.47, revert |
| v107 | Ranger-only retreat at 24% | −327, t −1.36, revert |
| v108 | kill securing (new build) | +142, t 0.57, revert |
| v109 | hold a tower while two own creeps stand beside it | −249, t −1.03, revert |
| v110 | Warlock drafted second (buffed totem) | −338, t −1.44, revert |
| v111 | retreat at 8% instead of 15% | −169, t −0.75, revert |
| v112 | last-hit window widened to twice hit reach | −346, t −1.49, revert |
| v113 | barracks +400 beside creeps (v101 retest, new build) | −200, t −0.92, revert |
| v114 | order hygiene + generated engine constants | −9, t −0.03, **submitted on the hygiene decision, champion since 12:18 PDT** |
| v115 | advance at the nearest seen enemy barracks (on v102) | −441, t −1.95, revert |
| v116 | buildings scored by distance alone, Aaron's rule (on v114) | −445, t −2.02, revert (significant loss) |
| v117 | no +80 base bonus on enemy heroes (on v114) | −149, t −0.62, revert |
| v118 | stutter-step half a tile instead of a quarter (on v114) | −311, t −1.28, revert |
| v119 | restock gear at 800 gold instead of 500 (on v114) | +40, t 0.23 at 240 vs 240, revert |
| v120 | enemy god bonus +500 to +1000 (on v114) | −120, t −0.56, revert |
| v121 | buy back after a 12 s wait instead of 25 s (on v114) | −31, t −0.14, revert |
| v122 | low-hero dive below 6x our damage instead of 4x (on v114) | −246, t −1.25, revert |
| v123 | stutter-step an eighth of a tile (on v114) | −126, t −0.64, revert |
| v124 | keep two portal scrolls, Aaron portals0922 rule (on v114, field d) | −5, t −0.03, revert (field d: v114 baseline 1,500 over 240, was 1,894 on field c) |
| v125 | retreat at 30% instead of 15% (on v114, field d) | −203, t −1.10, revert |
| v126 | no +80 hero base bonus (v117 retest on field d) | −65, t −0.35, revert |
| v127 | drink heal potions under threat (on v114, field d) | +19, t 0.11, revert |
| v128 | retreat at 40% when outnumbered two to one (on v114, field d) | −125, t −0.70, revert |
| v129 | always the middle lane (on v114, field d) | +147, t 1.09 at 360 vs 360 (blocks +175, +222, +43), revert |
| v130 | Lich drafted third above the Arcanist (on v114, field d) | +75, t 0.59 at 360 vs 360 (blocks +93, +239, −121), revert |
| v131 | leftover classes hold the lane waypoint instead of advancing at the god (on v114, field d) | −132, t −0.76, revert |
| v132 | no role-diversity draft penalty (on v114, field d) | −51, t −0.30, revert |
| v133 | think every four ticks instead of six (on v114, field d) | −301, t −1.93, revert |
| v134 | think every eight ticks (on v114, field d) | −135, t −0.77, revert |
| (test field e) | top five entries in every test game (gota_xp --league star lines); v114 re-baselined | v114 = 1,283 over 240 (was 1,500 on field d) |
| v136 | always the middle lane (v129 retest on field e) | −452, t −3.55, revert (significant loss) |
| v138 | never the middle lane (on v114, field e) | −205, t −1.64, revert |
| v139 | enemy-hero base bonus +80 to +160 (on v114, field e) | +85, t 0.76 at 240 vs 240, revert |
| v142 | never buy portal scrolls (on v114, field e) | −229, t −1.56, revert |
| v135 | hold the waypoint while an ally is at the enemy god (on v114, field e) | −135, t −0.99, revert |
| v137 | kill securing +600 at or below twice our damage (v108 retest on field e) | +67, t 0.59 at 240 vs 240, revert |
| v140 | creep last-hit bonus +650 to +1000 (on v114, field e) | −183, t −1.42, revert |
| v141 | sticky-target bonus +70 to +150 (on v114, field e) | +9, t 0.06, revert |
| v143 | portal home on retreat with enemies beyond 8 tiles instead of 12 (on v114, field e) | +77, t 0.50, revert |
| v145 | drink a heal potion only when 120 health is missing (on v114, field e) | −126, t −0.91, revert |
| v146 | Ranger Boots as a fifth gear item (on v114, field e) | −225, t −1.73, revert |
| v147 | axe before armor (on v114, field e) | −101, t −0.74, revert |
| v148 | drink a heal potion when 40 health is missing (on v114, field e) | −42, t −0.31, revert |
| v149 | target scan radius 12 tiles instead of 18 (on v114, field e) | −283, t −2.40, revert (significant loss) |
| v150 | target scan radius 24 tiles (on v114, field f: richard v174, v114 baseline 1,290) | +15, t 0.10, revert |
| v152 | leave tower fire below 80% instead of 65% (on v114, field f) | −65, t −0.46, revert |
| v154 | leave tower fire below 50% instead of 65% (on v114, field f) | −235, t −1.80, revert |
| v151 | leave the spawn at 70% health instead of 90% (on v114, field f) | +21, t 0.14, revert |
| v153 | side-lane waypoints at the quarter points instead of the corners (on v114, field f) | +91, t 0.65, revert |
| v155 | cross toward the enemy god only from level 4 (on v114, field f) | +79, t 0.53, revert |
| v157 | enemy god bonus +500 to +250 (on v114, field f) | +16, t 0.11, revert |
| v159 | buy back without the 200-gold reserve (on v114, field f) | −16, t −0.12, revert |
| v161 | core-buyback rule from aaron buyback0923 (on v114, field g: aaron buyback0923, v114 baseline 1,272) | +36, t 0.24, revert |
| v163 | avoid enemy heroes two levels above us (on v114, field g) | −129, t −0.95, revert |
| v165 | low-hero dive below 3x our damage instead of 4x (on v114, field g) | +72, t 0.50, revert |
| v167 | restock trip with enemies beyond 10 tiles instead of 15 (on v114, field g) | −116, t −0.82, revert |
| v168 | self-heal cast when a quarter of the heal is missing instead of half (on v114, field g) | −18, t −0.13, revert |
| v169 | no damage casts on the enemy god (on v114, field g) | −37, t −0.27, revert |
| v170 | cast on creeps whenever mana is above 80% (on v114, field g) | −220, t −1.73, revert |
| v171 | damage casts on heroes only below six times our damage (on v114, field g) | +102, t 0.73, revert |
| v172 | poison potion thrown at a killable hero (on v114, field g) | −199, t −1.52, revert |
| v173 | blue first-pick carry goes mid, aaron bluecenter rule (on v114, field h: aaron bluecenter0923, v114 baseline 1,147) | −172, t −1.37, revert |
| v174 | blue second pick takes lane 2 instead of mid (on v114, field h) | −226, t −1.88, revert |
| v156 | level the primary ability before the ultimate (on v114, field f) | −71, t −0.50, revert |
| v158 | level the passive first (on v114, field f) | −332, t −2.55, revert (significant loss) |
| v160 | level the secondary above the primary (on v114, field f) | −15, t −0.11, revert |
| v162 | ranged-creep preference +25 to +100 (on v114, field g) | −218, t −1.64, revert |
| v164 | creep base bonus +200 to +120 (on v114, field g) | −21, t −0.15, revert |
| v166 | attack-move refresh every two seconds instead of five (on v114, field g) | +148, t 1.21 at 240 vs 240 (blocks +326, −30), revert: false positive caught by the confirmation run |
| v144 | portal scroll bought before gear (on v114, field e) | −318, t −2.53, revert (significant loss) |
## Tried under the league-style test (one change each, on v47)
| version | change | result |
|---|---|---|
| v48 | every seat farms mid | +73 at 120 vs 60 (t 0.49), revert |
| v49 | Ranger-first draft, no role diversity | +42 at 180 vs 120 (t 0.36), revert |
| v50 | join the team push (buildings as targets with two allies near) | +28 at 240 vs 180 (t 0.28), revert |
| v51 | lane float to the emptiest lane (Jordan v312) | +56 at 60 vs 120 (t 0.38), revert |

## Rivals' published logic
- relh v161 = richard v153: one neural bot (source in Metta-AI/co-gas, read in full): nearest-object targeting, five-man edge-lane route, buyback whenever affordable, income from hero and tower kills.
- Jordan v317 changelog (policy store): every seat farms, lane float to the emptiest lane, pure farmer draft, no base defence, non-carries ignore healthy heroes beyond three tiles.
## Tried on the top-3 clone field before the roster discovery (all reverted)
| version | change | result |
|---|---|---|
| v38 | every seat farms, no guards | 547 vs 979 (wrong objective; retested as v47) |
| v39 | pure farmer draft | 436 |
| v40 / v42 | lane rotation on stall | 572 / 737 |
| v41 | base defence | 818 |
| v43 | escorted tower dives | 764 |
| v44 | farmers give ground to 2+ heroes | 1,057 vs 974 at 48 vs 48 (t 0.75) |
| v45 | farmers stand 3 tiles behind the wave | 992 |
| v46 | guards hold under the guard towers | 967 |
## Earlier: #1 against Jordan (00:55 to ~22:00 PDT)
- v33 (v23 plus two vitality elixirs per farmer) was kept over v23 at 1,654 vs 1,571 over 200 vs 220 head-to-head games against five Jordan v304, t 2.71, and held #1 (740 vs 677) until the neural bots arrived.
- Scoring (coworld 2026.9.21.5): each hero scores lifetime XP minus 200 per simulated minute (draft included), floored at zero; the team mean is the round score; the board is a rated mean of round scores. Victory only stops the clock.
## What the rules change did today (four engine versions in three hours)
- 15:28 PDT: drafting, ability points, buyback, keep-only shopping, doubled tower HP. Every old bot broke; v2 (new base plus god priority, no poison) went up at 15:50 because the champion was dead, not as a measured keep.
- 16:04: a full rewrite of the bundled base (scored targeting, kiting, dodging, retreating, portals).
- 16:30: win/lose scoring replaced by the XP-minus-clock score above.

## Tried on the scored rules before the field change (hosted, one change each)
| version | change | result |
|---|---|---|
| v3 | funnel: one carry farms, four escorts stay outside the creep XP radius | 508 vs v2 566, t −0.89, not kept |
| v4 | v3, carry never kills the god | 401, revert |
| v5 | v3 with two carries | 0 (broken), revert |
| v6 | v2 + regroup on the allies before marching | 525, not kept |
| v7 | the new base verbatim | 244, revert (t −5.7) |
| v8 | v2 + focus the weakest enemy hero in reach | 587, inconclusive (t +0.3) |
| v9 | v2 + no chasing under enemy towers without creeps | 496, not kept |
| v10 | v2, idle heroes attack-move at the enemy god | 572, inconclusive (t +0.1) |
| v12 | v2 + escorted building priority | 427 vs v8 615, revert |
| v13 | v2, buy back first death only | 448, revert |
| v14 | v2 + shop trips with a portal back | 481, revert |
| v15 | lane farmer (Jordan's logic on the new base) | **1,341 vs 615, t 8.2, kept and submitted** |
| v16 | v15, guard 4 shadows the mid farmer | 1,314 vs 1,354, not kept |
| v17 | v15, farmers buy the portal scroll first | 1,270, not kept |
| v18 | v15, both guards hold home | 1,333, not kept |
| v19 | v15, ranged farmers take ranged creeps first | top-3 field 1,314 (noise); **vs Jordan 1,370 vs 1,209, t 2.5, kept and submitted** |
| v20 | v15, Ranger-first draft | +77 at 72 games on the top-3 field (t 1.64), −46 vs Jordan alone; not kept |
| v21 | v15, mid farmer retreats at half health | 1,202, revert |
| v22 | v15, guards gank lone enemy farmers | 1,044 vs 1,227 head-to-head vs Jordan, revert |
| v23 | v19 + both guards hold home | **1,686 vs 1,370 vs Jordan, t 3.4, kept and submitted** |
| v24 | v19 + Ranger-first draft | 1,420, not kept |
| v25 | v23 + farmers fight the lane enemy when healthy | +54 at 40 games (t 0.75), not kept |
| v26 | v23 + farmers buy the weapon first | 1,528, not kept |
| v27 | v23 + farmers rank W first | 1,565, not kept |
| v28 | v23 + guard 3 shadows lane 0 | 1,521, not kept |
| v29 | v23 + Ranger-first draft | 1,543 at 40, not kept |
| v30 | v23 + class-earnings draft (Ranger > Lich > Berserker > Arcanist > Demon Hunter) | +59 at 140 vs 140 (t 1.5), shrinking with n; not kept |
| v31 | v23 + roles by class (best farming classes farm) | 1,479, revert |
| v32 | v23, Crossbowman demoted in the draft | 1,155, revert (t −3.6) |
| v33 | v23 + farmers carry two vitality elixirs (87% of farmer deaths are lane duels) | **+83 at 200 vs 220, t 2.7, kept and submitted** |
| v34 | v33 with four elixirs | +7 at 120 vs 200, not kept |
| v35 | v33, retreat at 35% | 1,442 vs 1,654, revert |
| v36 | v33, elixir at 60% health | 1,627, not kept |
| v37 | v33 + class-earnings draft | 1,651, not kept |

vs Jordan, 20 games each (user request): v16 1,114, v17 1,209, v18 1,348 (t 1.1), v19 1,433 (t 2.3), v20 1,285, v21 1,194 against v15's 1,227.
| v11 | v2 + Crossbowman-first draft | 478, not kept |

## Test field is now Jordan only (user, 20:35)
v15 vs five Jordan v304: 1,227 vs his 1,155, 12 of 24 games won on score. Even. The next changes target the lane duels.

## Head-to-head vs five Jordan v300 (earlier)
v15 scores 1,140 per game and out-scores Jordan in 15 of 24; every earlier version scores 2 to 228 against him. Jordan's own changelog (pulled from the policy store) drives our candidate list; his v304 adds scroll-first, home guards and ranged-creep priority, all of which we tested and none of which moved our score.

## Where the score comes from (v23 vs Jordan, 40 games)
Each lane pays at most about 360 XP a minute (eight enemy creeps every 20 seconds), so a farmer tops out near 7,500 XP by the limit; our three farmers earn 5,800 / 7,600 / 6,600, the guards about 200 and always floor to 0. Class matters: a Ranger farmer earns 7,800, a Crossbowman 5,100; a Lich 8,400, an Arcanist 6,900. Lane 0 is the only lane Jordan still wins, and he takes the Ranger 30 games in 40.

## What we learned
- Short wins beat farming: a team that ends the game by minute 8 to 10 keeps several heroes above the clock (v2: 591/1086/805/343/573 in one game); a 20-minute farm leaves one hero positive.
- Only the last hitter gets hero XP (150) and tower XP (100); creep XP (15) is shared within 6 tiles with 15% to the last hitter.
- Local seat effects are large and bot-dependent (blue won 39 of 40 base-vs-v2 games; red won 16 of 16 regroup mirrors); local ladders are design signal only.
- Rivals (Jordan, Richard Higgins, juliajerome, daveey) run 1 to 6 episode XP requests against khors continuously; v2 won 96 of 126 of those.

## Rules we play by
- Score only from hosted XP vs the current top 3 unique other players, both seats, 12 episodes each; compare team means with Welch t (tools/xp_score.nim --team). Keep only on significance; submit only a kept candidate.
- One policy name, `khors:vN`. Identity Andre von Auto. Bodies from games/gods-of-the-arena/tools/gota_xp.nim.

## 2026-09-23: god-reward build
- The league moved to cow_2cb5d47d (2026.9.22.3, replay v58) on 2026-09-22 13:42 PDT: a god kill gives every hero on the winning team +500 XP. Arms v115-v174 ran on the old build.
- Field i (eps/field_2026-09-23i.txt): Aaron and his coach both run nacre-velvet-7c2f (druid lane recovery), richard v174, relh v161, Jordan v411. v114 baseline 803 over 240.
- Replay stats (tools/gota_arm.nim): richard's team wins 90% with 8.8 kills a game; our hero's team wins 46% with 6.6 kills.
- v175 god bonus x3: did not fire, revert. v176 buildings first: -382, t -4.5 (games shorter, kills halved). **v177 heroes outrank creeps (hero bonus +80 to +1000): 996 vs 803 at 240 vs 240, t 2.12, kept and submitted.**
