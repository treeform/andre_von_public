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

## Backlog

- Status 2026-10-09 ~07:30Z: champion v13, ladder #1 (1628 MMR, 46-2); 0.1.4 is viewer only.
- Small tweaks around v13 keep losing 1-6k (the deterministic economy is timing sensitive):
  extensions, extra haulers, hauler hysteresis, early upgraders, no-overflow miners,
  fullest-miner targeting, lifecycle. Next tries should be structural.
- Remaining leaks (ledger, v13): loose pile decay 20-26k per seat (persistent overflow piles
  under home miners, ~1/tick each), upgrade-pile decay 4-8k, tombstones ~3.6k.
- W3N3 home source: north spot (13,8) is walled off from the station (14,11); its pile is
  swept only by a ~12 tile detour.
- W2N2 ramp: no upgrading until ~t1000 while ~2.9k energy idles on the piles.
- If a stronger rival appears: shared rooms W2N3 and W3N2 hold our remotes; add flee or defense.

- Remote mining: local runs (mirror and vs colony) give v5 82,540 / 77,732 but hosted gives 78,064 / 58,675. Find the hosted-only difference first.
- W9N9 pile layout: (11,5) door (12,6) and (8,5) door (9,4) keep a 2-wide corridor at x 13-14.


- Remote mining in neighbor rooms (5/tick per neutral source).
- Faster opening (time to saturate home sources).
- End game: drain every pile and hauler into the controller by tick 6000.
- Pulled upgraders/miners without MOVE parts (pull mechanics).

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
