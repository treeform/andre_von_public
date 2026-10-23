# Screeps PW: Mokosh

Policy: Mokosh (`mokosh`), the earth mother who keeps the harvest.
One self-contained JavaScript file (`mokosh/mokosh.js`, the user allowed
JavaScript for this game), uploaded with
`tools/auto_player upload games/screeps-pw/mokosh/mokosh.js mokosh`.

Coworld: `cow_d7adf8df-331e-4ced-9def-8a0bd6af4574` (Screeps PW 0.1.0,
owner monofuel, game-hosted file players, engine Screeps revision 7ff9722).
League: `league_ac545b38-4caa-4873-a202-769697261f26` (dash slug
`screeps-pw`), one Competition division, paired duels, Elo 1500/K32,
rounds every 30 minutes. Dash:
https://softmaxdash-nginx.tail0f4a29.ts.net/league/screeps-pw

## Game versions

- 0.1.0/0.1.1 (to ~2026-10-09 01:45Z): official 121-room world, seat 0 W1N1, seat 1 W9N9.
- 0.1.2 (~01:50Z): fixed 4x4 world W1-W4 / N1-N4, sealed outer border, 3-wide carved
  entrances between neighbors; seat 0 W1N1, seat 1 W2N2.
- 0.1.3 (~02:55Z, current): same 4x4 world; seat 0 W3N3 (37,31) with ONE source
  (14,9, only 2 open spots), seat 1 W2N2 (17,40) with two sources. Spawns are 69
  steps apart; W2N3 and W3N2 neighbor both starts. Source: github.com/monofuel/screeps_pw
  (open source; clone in references/screeps_pw). tools/world.js rebuilds the map.
- Trials v5 and v6 ran on 0.1.2 and v4 on 0.1.1 while v2 was measured on 0.1.1: their
  verdicts compare different maps and must be redone on 0.1.3.

## Rules that matter (read from the image)

- Two accounts on the official 121 room default world. Seat 0 spawns in
  W1N1 at (37,31), seat 1 in W9N9 at (17,40). 6000 ticks.
- Score = account GCL points earned = energy put into upgradeController
  (boosts count; nothing else adds GCL). Higher score wins the episode.
- `bots.spawn` sets `safeMode: gameTime + 20000`, so both home rooms are
  in safe mode for the whole match: no attacks at home. Remote rooms are
  open.
- CPU: limit 20, bucket starts at 0, per tick limit = 20 + bucket (cap
  500), bucket cap 10000. Overspending makes the bucket negative and the
  next ticks are skipped.
- Spawn regenerates +1 energy per tick while the room holds under 300
  energy (`spawns/tick.js`). Keep the spawn under 300: free ~6000 energy.
- Dropped energy decays ceil(amount / 1000) per tick, so any pile costs at
  least 1 per tick. Containers cost 5000, extensions 3000, roads 300.
- Neutral sources hold 1500 per 300 ticks (5 per tick), owned or reserved
  3000 (10 per tick). Reserving needs CLAIM (650 energy body), so RCL3.
- RCL2 at 200 progress, RCL3 at 45,200 total.
- Intent order: drop, transfer, withdraw, pickup, ..., harvest, move, ...,
  upgradeController. upgradeController conflicts with nothing, so an
  upgrader can pick up and upgrade in one tick.

## Rooms (tools/map.js)

- W1N1: controller (42,22) is 6 steps from the spawn, sources (30,27)
  4 spots and (29,41) 3 spots, 9 steps each. Easy room.
- W9N9: controller (10,7) is 32 steps from the spawn and ~38 from both
  sources (8,41) 4 spots and (23,44) 4 spots. Every energy unit is hauled
  far. Neighbors W8N9, W9N8, W8N8, W7N9 have two sources each.
- Baseline colony (README): 32,416 from W1N1, 16,792 from W9N9.

- 0.1.5 through 0.1.11 (2026-10-09 to 2026-10-22, current 0.1.11): W3N3 is W2N2 rotated 180
  degrees (both homes: two sources with three open spots each, controller 21-25 steps
  from the sources, spawn 21-23 steps from both); matches are 1500 ticks; ZIP/WASM
  policies allowed; safeMode is nil (combat possible, nobody uses it). Scores are
  deterministic per seat (sd 0) and fast-XP == local == hosted exactly.
- Fast-XP: POST https://fast-xp-k8s-prod.tail0f4a29.ts.net/v1/games/screeps-pw/run with
  the JS source in both seats runs a full match in ~11 s (tools/fastxp.nim, tools/sweep.nim
  for Tune overrides, two requests at a time). Hosted XP remains the verdict.
- Rules confirmed from the engine source: the spawn regenerates 1/tick only while room
  energy < 300; a source's 300-tick timer starts at its first harvest and resets it to
  3000 (owned room); drops decay ceil(amount/1000) per pile per tick, so every dropping
  miner costs 1/tick.

## Backlog

- Status 2026-10-22 23:30Z: field is Andrew Brower's lyrebird:v11 / bowerbird:v12 (14,149 W3N3 /
  13,711 W2N2, richard's co-gas design with a faster ramp), richard/relh reservations (13,015 /
  13,344), us mokosh:v14 13,430 / 13,392 (submitted, beats richard both seats, loses to lyrebird
  and bowerbird). Old v13 scored 7,585 / 8,814 (6000-tick build order).
- Ledger vs lyrebird (W3N3, tools/stats.nim): harvest -600 (2-WORK CARRY miners arrive later than
  WWW drop miners), bodies +1,050 (12 upgraders, 10 haulers, 1,250 of miners), decay -1,233
  (CARRY miners, hand-over at piles). Net -719.
- Remaining leaks (v14 W3N3): source decay 2,600 (the WW opener alone 1,122, each WWC 270-590
  from store overflow between hauler visits), pile decay 400-800, end inventory ~1,100 (haulers
  in flight, full spawn), bodies 6,750.
- Knob changes move a seat by +-200 chaotically (traffic); judge ideas on both seats, prefer
  structural changes.
- Untested: hauler route shortening (piles toward the sources), two piles instead of three,
  no sweeping, WWW on one source only, replacing the opener late (t>900), combat (safeMode off).
- Source regen phase does not matter: with 5 WORK a source yields exactly 10/tick regardless.

## Trials

Uploads that are not candidates: mokosh:v7 = v5 plus reset, hostile and death logging (diagnostic, one hosted episode per seat).

| v | idea | change | XP | opponents | verdict |
| --- | --- | --- | --- | --- | --- |
| v1 | first working bot | miners hand off to haulers, two upgrade piles, spawn regen kept on | xreq_7596766d, xreq_1a2089b6 (colony), xreq_5eeb80cd, xreq_88b3f798 (idle) | colony:v1, idle-b:v1 | W1N1 71,437 (14/14 wins), W9N9 12,787 (loses to colony 32,416; beats idle). Deterministic, sd 0. Submitted as first champion (sub_9ceac2d3). |
| v2 | unjam W9N9 | piles must stay reachable with every slot full (in v1 the second pile sealed the first one off in the W9N9 nook); posted creeps are walls for paths, idle creeps get swapped aside | xreq_d632a2a6, xreq_60fb1126 (colony), xreq_f07de92e, xreq_9ca4a3d1 (idle) | colony:v1, idle-b:v1 | W1N1 77,422 (+5,985), W9N9 66,095 (+53,308), sd 0 both, 29/29 wins vs colony. Kept, submitted (champion). |
| v3 | remote mining | 7 neutral remote sources (3 W1N1, 4 W9N9) after home saturates, third upgrade pile | xreq_7948ecba, xreq_e6d30340 (colony), xreq_47377020, xreq_53caecfd (colony-b) | colony:v1, colony-b:v1 | W1N1 72,761 (-4,661 vs v2), W9N9 60,797 (-5,298), sd 0. Worse in both seats: reverted. |
| v4 | pile-driven upgraders | upgraders jump the spawn queue while piles hold >300 idle energy; target grows by pile/300 (remotes off) | xreq_c67f33a9, xreq_9e8556b0 (colony), xreq_850b40c3, xreq_83d3902e (colony-b) | colony:v1, colony-b:v1 | W1N1 76,706 (-716 vs v2), W9N9 64,620 (-1,475), sd 0. Worse: reverted. Early upgraders slow the ramp more than pile decay costs. |
| v5 | remote mining, retry | v2 ramp unchanged; after home saturates: pile upgraders, then remote haulers, upgraders to target, then remote miners (open only with drained piles and spare slots); third pile | xreq_fc33b3b9, xreq_ad712ca6 (colony), xreq_bce9b356, xreq_2d1091e8 (colony-b) | colony:v1, colony-b:v1 | W1N1 78,064 (+642 vs v2), W9N9 58,675 (-7,420), sd 0. Worse overall: reverted. |
| v6 | drop-miner opening | opener and early miners are [W,W,M] (250, drop mining); body budget floor 250 | xreq_60792006, xreq_fdd5104c (colony), xreq_068a6fd3, xreq_8de1bb5a (colony-b) | colony:v1, colony-b:v1 | W1N1 76,076 (-1,346 vs v2), W9N9 58,413 (-7,682), sd 0. Worse: reverted. (Local 1500-tick proxy said +509/+1,489: short local proxies mislead.) |
| v2 @0.1.3 | baseline re-measure | none (champion) | xreq_1bfb6f5d, xreq_22152098 (colony), xreq_d371ea79, xreq_e7d136c3 (colony-b) | colony:v1, colony-b:v1 | W3N3 14,586, W2N2 58,828, sd 0, 40/40 wins. Local 0.1.3 mirror matches exactly. |
| v8 | remote mining in the 4x4 world | v5 logic (remotes after home saturates, 3 piles) with remote tables for W3N3 (7 sources) and W2N2 (6 sources) | xreq_f06fbe7d, xreq_85bbd837 (colony), xreq_fab6d3a2, xreq_0e47be32 (colony-b) | colony:v1, colony-b:v1 | W3N3 28,604 (+14,018), W2N2 59,914 (+1,086), sd 0, 40/40 wins. Kept, submitted (sub_25bbc83a). |
| v11a (local only) | two extensions (400 bodies, 3 WORK miners and upgraders) | on v8: extension sites near the spawn in upgrader build range | local vs colony, deterministic | colony baseline file | W3N3 28,604 (=v8, extensions never built there), W2N2 51,820 (-8,094). Rejected before upload. |
| v9 | remote miners vs upgraders balance | upgraders first only below 75% of their WORK target, then remote miners, then the rest of the upgraders | xreq_b2089bc3, xreq_92ef479f (colony), xreq_2e9d7b12, xreq_c28284c2 (colony-b) | colony:v1, colony-b:v1 | W3N3 30,203 (+1,599 vs v8), W2N2 61,871 (+1,957), sd 0, 40/40 wins. Kept, submitted (sub_9184a75b). |
| v10 | replace small miners | at spot-limited sources a full miner replaces the 1-WORK opener (old one retires when the new one arrives) | xreq_d47d22f7, xreq_0dfbed5e (colony), xreq_4b6f073d, xreq_4da83b99 (colony-b) | colony:v1, colony-b:v1 | W3N3 30,508 (+305 vs v9), W2N2 61,871 (=), sd 0, 40/40 wins. Kept, submitted. |
| v11 | sweep loose energy | haulers in fill walk to the biggest drop (>= 40) near their source that no other hauler is taking, else wait at the station | xreq_8b8481c1, xreq_d4802715 (colony), xreq_e841aa41, xreq_43294b83 (colony-b) | colony:v1, colony-b:v1 | W3N3 36,549 (+6,041 vs v10), W2N2 62,802 (+931), sd 0, 40/40 wins. Kept, submitted. |
| v12 | drain source piles | a miner standing on its own overflow pile stops handing energy to haulers, so haulers pick the pile up; haulers take the biggest adjacent pile first (ledger: W2N2 lost 27k energy to loose-pile decay, 25% of harvest) | xreq_cd9165a1, xreq_0f8e16f9 (colony), xreq_b6b9eb09, xreq_0b3eeacf (colony-b) | colony:v1, colony-b:v1 | W3N3 40,623 (+4,074 vs v11), W2N2 63,543 (+741), sd 0, 40/40 wins. Kept, submitted. |
| v13a/v15x (local only) | extra haulers on backlog | spawn haulers up to 1.3-1.6x need while >300 energy lies at sources | local vs colony | colony baseline file | Worse both times (v15x on v14x: W3N3 -5,370, W2N2 -4,806). Rejected. |
| v13 | fill the spawn, skip the detour | a hauler sent to the spawn unloads all the spawn takes and heads back to its source when under 50 energy is left (W2N2 spawn sits far from both sources and piles; partial loads cost ~29 extra steps each) | xreq_4ef0d3ce, xreq_dd7c6c4d (colony), xreq_66b1df5e, xreq_e8c4c825 (colony-b) | colony:v1, colony-b:v1 | W3N3 44,715 (+4,092 vs v12), W2N2 70,911 (+7,368), sd 0, 40/40 wins. Kept, submitted. |
| v16x (local only) | serve the fullest miner | haulers walk next to the miner with the most energy instead of the source station | local vs colony | colony baseline file | W3N3 43,661 (-1,054 vs v13), W2N2 68,398 (-2,513). Rejected. |
| v17x (local only) | no-overflow miners | miners harvest only into free store space, so no piles form under them | local vs colony | colony baseline file | W3N3 28,930 (-15,785 vs v13), W2N2 66,431 (-4,480). Rejected: overflow piles are a cheap buffer (decay ~1/tick per pile) compared to unharvested source energy. |
| v18x (local only) | hauler hysteresis | remote hauler top-ups only below 90% of need, to give new remotes spawn windows | local vs colony | colony baseline file | W3N3 44,082 (-633 vs v13), W2N2 66,241 (-4,670). Rejected: the economy is hauler limited. |
| v19x (local only) | early pile upgraders | upgrader ahead of home miners while piles hold >800 idle energy | local vs colony | colony baseline file | W3N3 44,715 (=), W2N2 67,769 (-3,142 vs v13). Rejected. |
| v20x (local only) | extensions where a home source is spot limited | v13 plus two extensions in W3N3 only (built at 32,36 and 33,36), 3 WORK home miners there | local vs colony | colony baseline file | W3N3 38,949 (-5,766 vs v13). Rejected: 6000 energy and 400-energy spawn waits cost more than the extra 2/tick. |
| v21x (local only) | creep lifecycle | old haulers deliver early; no upgraders in the last 150 ticks unless energy idles | local vs colony | colony baseline file | W3N3 43,099 (-1,616 vs v13), W2N2 67,112 (-3,799). Rejected. |
| v14 | 1500-tick rewrite | immobile towed miners (WW opener, WWC/WWC/WC per source) and WWC upgraders, lyrebird's scripted opening (CM, CCCMMM, miners, 8 haulers), haulers hand energy to the hungriest upgrader on the pile tile, spawn-first delivery, 12 upgrader cap; fast-XP sweeps s01-s12 chose the order and caps | xreq_0493defd, xreq_3cbb97e0 (lyrebird:v11), xreq_48e88c1e, xreq_69abde45 (bowerbird:v12), xreq_f1e814cb, xreq_cbe205e9 (richard) | lyrebird:v11, bowerbird:v12, co-gas-screeps-pw-reservations-richard:v1 | W3N3 13,430, W2N2 13,392, sd 0 (12 episodes); wins 4/12 (richard both seats), loses to lyrebird 14,149/13,711 and bowerbird 14,034/13,716. Beats v13 (7,585/8,814) deterministically: kept, submitted 2026-10-22 23:25Z. |
| fast-XP rejects (local only, both seats) | drop miners WW/WWW like lyrebird: 12,984/12,558 (decay 4,051); WWCC miners: 12,924/13,163 (slower ramp); earlier miners o3/o4: 12,999/11,298, 13,061/13,477; replace the WW opener at t=400/600 with WWC: 12,698/13,175, 12,733/13,175 (tow starves stations, decay rises); CARRY buffer creeps at stations: 11,932/12,273, 11,899/12,733; 10 upgraders: 12,783/13,128; 14 cap = 12 built; WWCC upgraders with 10 cap: 12,669/13,281; small pile buffer: 11,803/13,575 then 13,454/13,132 without holding; early CCMM hauler: 13,005/12,525; early upgraders in the order: 12,793/12,849; free late upgraders (freeStop 60): 13,454/13,392 (kept in the file, +24). | | | all rejected except freeStop |
| g1-g4 (fast-XP) | shorter hauler trips | piles chosen on the controller side facing the sources (g1: 13,881/13,424), no drop sweeping at stations (g2: 13,691/13,523), both plus two piles instead of three (g4: 13,930/13,716) | | | kept as the new base |
| h1-h6 (fast-XP) | hauler count | nine haulers minus one: 12,822/12,701; tenth CCMM hauler (h4): 14,457/14,206; eleventh: 13,982/13,777; h4 plus opener replacement at t=900: 14,323/14,061 | | | h4 kept |
| v15 | tenth hauler and source-facing piles | h4 configuration: order ends with CCCMMM, CCCMMM, CCMM; PileCount 2; piles scored by distance to the sources; sweepMin 1000 | xreq_5061cd48, xreq_9469c61d (lyrebird:v11), xreq_1644d20d, xreq_40e7b885 (bowerbird:v12), xreq_ef925244, xreq_820be0b6 (richard) | lyrebird:v11, bowerbird:v12, co-gas-screeps-pw-reservations-richard:v1 | W3N3 14,457, W2N2 14,206, sd 0, 12/12 wins (lyrebird 14,149/13,711, bowerbird 14,034/13,716, richard 13,344/13,015). Beats v14 (13,430/13,392) deterministically: kept, submitted 2026-10-22 23:50Z. |
| i1-i2 (fast-XP) | pile buffer | pileBuffer 200: 14,183/14,040; 60: 14,408/14,354 (mixed) | | | 120 kept |
| i3-i4, j1-j2, k1-k4 (fast-XP, on v15) | knobs and order permutations | handOver 4: 14,355/14,312; fillDone 30: 13,978/14,343; upgraderStop 150 or 220: unchanged; tenth hauler CCCMMM: 14,054/13,978; tenth hauler before the WC miners: 14,237/14,431; WC miners before the ninth hauler: 14,047/11,919; hauler-first opener: 14,194/14,091 | | | all rejected (mixed or worse on a seat); v15 stays |
| m1-m2, n1-n4, q, w, s20-s21, t, f0 (fast-XP) | post-v15 structural probes | self-walking WWCM upgraders: 14,316/13,884 and 14,254/14,017; WWC opener: 13,812/13,686; freeStop 250 (no free upgraders in the last 250 ticks): 14,495/14,226 kept; hand-over burn cap: 14,513/14,248 kept; wait tiles 2-3 per source: 14,388/14,121, 14,150/14,041; handOver 2: 14,235/14,054; pileBase 50: 14,331/14,248; tug slow weight 10/50: no gain; jitter in tug ties: no effect (ties are rare) | | | freeStop 250 and burn cap kept |
| v16 | freeStop 250, burn cap | v15 plus no free upgraders in the last 250 ticks and haulers never hand an upgrader more than it can burn | xreq_8a8f09f7, xreq_3ffc1062 (lyrebird:v11), xreq_e15d9c67, xreq_76efacc0 (bowerbird:v12), xreq_c443c789, xreq_26f39a53 (richard) | lyrebird:v11, bowerbird:v12, richard | W3N3 14,513, W2N2 14,248, sd 0, 12/12 wins. Kept but superseded by v17 before submission. |
| v17 | climbed build order | tools/climb.nim adjacent-swap hill climb on fast-XP (both seats must improve): the sixth entry becomes h:CCMM before the second WWC miner (order: WW, CM, CCCMMM, WWC, CCCMMM, CCMM, WWC, CCMM, WWC, CCCMMM, CCMM, WC, WC, CCCMMM, CCCMMM, CCMM); a second pass with a relaxed rule found nothing | xreq_8ce6df82, xreq_c0192126 (lyrebird:v11), xreq_ad906f1c, xreq_0e9a93fc (bowerbird:v12), xreq_96feac6c, xreq_710339cc (richard) | lyrebird:v11, bowerbird:v12, richard | W3N3 14,783, W2N2 14,853, sd 0, 12/12 wins (+270/+605 over v16). Kept, submitted 2026-10-23 ~00:45Z. |
| climb passes 2-4 (fast-XP) | deeper build-order search | climb.nim extended with hauler body swaps (CCMM <-> CCCMMM), one hauler dropped, one CCMM inserted; relaxed rule (sum +80, no seat -40). From v17 nothing kept; best sum body4 (fifth entry CCCMMM -> CCMM): 15,066/14,789 (W3N3 +283, W2N2 -64). Climbing from body4 kept nothing; no order beat v17 on both seats (closest: swap0 14,974/14,704, drop9 14,837/14,773). | | | v17 stays; body4 is a one-seat candidate kept in the backlog |
| stats 2026-10-23 | policy-vs-top-3 table | tools/compare.nim over v17 (fast-XP, both seats) and round 354 replays of lyrebird:v11, bowerbird:v12, richard; stats/stats_2026-10-23.html. Red rows: we spawn the miner before the hauler, 5 CARRY miners vs 0, haulers idle 1,296 ticks at stations vs 550-840, road jams 503 vs 208-507, controller decay 450 vs 0, spawn full 231 ticks vs 24; our wins: source decay 1,836 vs 4,330-4,590, hauled 20,967 vs 18,730-19,665. Deficit: harvest 22,967 vs 23,250-23,392 (left at regen 4,013 vs 3,370). | | | stuckLimit 2/3 (faster repath): 14,867/14,845, 14,659/14,855, mixed |
| v18 | hand-over while walking, faster repath | haulers feed the hungriest adjacent upgrader on their way to the pile (handWalk) and repath around crowds after 2 stuck ticks instead of 4; alone each is mixed (14,921/14,787 and 14,867/14,845), together both seats rise | xreq_2e2257ee, xreq_4ce5c526 (lyrebird:v11), xreq_d45eeeb9, xreq_e9d46d7b (bowerbird:v12), xreq_1b8bd1bb, xreq_c188d039 (richard) | lyrebird:v11, bowerbird:v12, richard | W3N3 14,907, W2N2 14,950, sd 0, 12/12 wins (+124/+97 over v17). Kept, superseded by v19 before submission. |
| v19 | per-room build orders | the homes are rotated copies but PathFinder tie-breaks differ per room, so Tune.orderW3N3 / orderW2N2 pick each seat's best climber neighbour (W3N3: fifth entry CCMM; W2N2: the first WC miner before the ninth hauler) | xreq_ (eps/v19_ids.txt) | lyrebird:v11, bowerbird:v12, richard | W3N3 15,203, W2N2 15,084, sd 0, 12/12 wins (+296/+134 over v18). Kept, submitted 2026-10-23. League rounds resumed 2026-10-23: v17 won all 21 rounds since 355, MMR 1,016 -> 1,494 (Browers 1,865). |
| v20 | drain the idle spawn | after drainAfter, and only while the spawn has nothing to build, the smallest hauler withdraws full loads from the spawn and hauls them to the piles (spawn regen is 1/tick only below 300, so a full idle spawn wastes it). Sweep: drainAfter 1250: 15,427/15,211; 1000: 15,664/15,303; 900: 15,537/15,448; 800: 15,610/15,468; 700: 15,620/15,506 (best on both seats); 600: 15,583/15,506; two drainers lose (15,190/15,193). Stats: spawn-full ticks 231 -> 16, upgrader idle 9% -> 1.8%. | xreq_280ed571, xreq_dc25565c (lyrebird:v11), xreq_3ab14761, xreq_671756eb (bowerbird:v12), xreq_14d763d7, xreq_8f1669c3 (richard) | lyrebird:v11, bowerbird:v12, richard | W3N3 15,620, W2N2 15,506, sd 0, 12/12 wins (+417/+422 over v19). Kept, submitted 2026-10-23. |
| fast-XP rejects (on v20) | cheaper ramp miners | WWWC miners: impossible, a 350 body exceeds the 300 spawn capacity at RCL1-2 (opening stalls, score 0); one WWW drop miner replacing WWC+WC: 14,498/14,666 (first WWC) and 15,018/14,938 (second WWC) | | | rejected; CARRY miners stay |
| v21 | eleventh hauler in W3N3 | per-room climb from v20 added a CCMM hauler at the end of the W3N3 order (the drainer takes one hauler off source duty) | xreq_7e4f958c xreq_3187d1ee xreq_30e9555c xreq_2d05f872 xreq_0d42541e xreq_90e2d874 | lyrebird:v11, bowerbird:v12, richard | W3N3 15,714 (+94), W2N2 15,506 (=), sd 0, 12/12 wins. Submitted 2026-10-23. |
| tools/remotes.nim | remote source map | ranks neutral sources by path cost from each home controller over the 0.1.11 replay terrain: W3N3: W3N4 (13,42) 43, W4N3 (46,4) 45, W4N2 (45,23) 49; W2N2: W2N1 (17,18) 51, W2N3 (30,7) 60 (the 49-53 entries are the opponent's home sources) | | | |
| v22 | remote mining in W3N3 | after remoteAt, one WWCM miner walks to W3N4 (13,42) (tows break at room edges: the first try left the miner stuck at 26,1 for 450 ticks while haulers idled at the remote); haulers count only posted remote WORK; drops scanned in the remote room. Sweep (W2N2 off): remoteAt 600: 14,010; 650: 16,116; 700: 16,152; 800: 16,061; 900: 15,821. W2N2 remote W2N1: -236 to -379, so off. Second W3N3 remote W4N3: 15,842; WWMM miner: 15,338. | xreq_9c643f7e xreq_81e4e623 xreq_9483b3d6 xreq_8c706079 xreq_db614df9 xreq_a169d2b5 | lyrebird:v11, bowerbird:v12, richard | W3N3 16,152 (+438 over v21), W2N2 15,506 (=), sd 0, 12/12 wins; remote mining behaves on the hosted engine exactly as on fast-XP. Submitted 2026-10-23. |
| fast-XP rejects (on v22) | other remotes, caps | W2N2 remote W2N3 (30,7) at 60 steps: 14,694 / 14,613 (tick 700 / 650); upgrader cap 14: no change (the income target binds first) | | | rejected |
| v23 | W3N3 order with remote haulers | per-room climb from v22: twelfth hauler and the last one CCCMMM in W3N3 (the remote needs its own haulers); W2N2 unchanged | xreq_fa076f69 xreq_199860a8 xreq_0220d3f3 xreq_ebae55f1 xreq_83f215b1 xreq_86192257 | lyrebird:v11, bowerbird:v12, richard | W3N3 16,620 (+468 over v22), W2N2 15,506 (=), sd 0, 12/12 wins. Submitted 2026-10-23. |
