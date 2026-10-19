# MOBA progress

- Goal: first in the league. Current: Andre von Auto sixth, 1287 MMR.
- Champion: gorynych:v1, submitted 2026-09-01 00:35 UTC.
- Identity: always Andre von Auto, ply_3d22435e-30a2-4f2a-b037-a5c249583788.
- Rules checked: hosted 0.1.3, upstream f06d28f, unchanged.
- Baseline audit: local siege change postdates champion; isolate it.
- Baseline: 30 hosted games completed. Two opposing policies in every game.
- Identity correction: original four candidate uploads were on wrong player.
- Versions: v2 occupancy, v3 topstack, v4 haste, v5 soak, v6 recovery.
- Top-three t1: all 180 games complete, all candidates activated 30/30.
- v2 occupancy: reject, p=.889. v3 topstack: reject, p=.704.
- v4 haste: reject, p=.694. v5 soak: reject, p=.889.
- v6 recovery: reject after 60 games, 5 wins versus v1 4/60, p=.50.
- Now: five Grok lanes testing a theory of sustained split-lane pressure.
- Lanes: routes, tower positioning, retreat, skill casts, combat targeting.
- Earlier occupancy 30 games: p=0.50, not kept. Wrong-player trials archived
  as audit evidence and excluded from corrected candidate comparisons.
- All five candidate checks passed. Haste and recovery counter fixes done.
- Leader research: 12 hosted replays reconstructed with exact end-state checks.
- Theory: Daveey keeps lanes split; Richard/Relh rush five heroes down top.
- Replication: compare original v1 decisions to leader actions on same obs.
- Audit: five distinct source hashes; isolated compiler caches used.
- Dashboard bug: selecting only us wrongly labels the game as solo.
- Workflow correction: lanes launch XP on passing checks, no supervisor wait.
- Field: always top three other players, one live policy per player.
- Current: daveey-scripted:v39, richard topstack:v7, relhalpha topstack:v3.
- No matches between our versions. Nearest-rating trials are historical.
- Gate: at least 10 triggered hosted episodes, dashboard significance,
  matched opponents and replay/log proof. Inconclusive is not kept.
- Submitted improvements: none.
- 2026-09-12 (later): leaders' source found public (Metta-AI/co-gas,
  players/users/relh/co-gas/moba): same scripted FSM, five-hero top stack,
  300-tick bounded standoff then breakthrough, safe-retreat hold. Daveey
  v39 source not public.
- Sim geometry finding: towers scan chebyshev 5 around their int cell;
  cells at chebyshev 5 from an ancient on its far side are outside every
  tower square and inside attack() reach (L1 <= 12). 44 blind cells per
  side (research/snipe.nim). Local wasm harness kills an ancient by tick
  345-655 from either side (research/snipetest.nim; mechanics only).
- brain.nim rewrite = ancient snipe; uploaded gorynych:v9 (commit 5e2f30d);
  snipe t1 requests created (see ideas.md ledger). Verdict pending.
- v9 kept and submitted (28-2 vs top 3, p=3e-12); champion. League rounds
  15-0 then 36-0; MMR 1263 -> 1410 -> 1524; daveey 1948 -> 1831.
- v10 (fight visible creeps) discarded: 115/120 vs 114/120, p=0.5.
- Stall bug found via lockstep replay (research/stalls.nim): diagonal
  corner-cutting fails in the sim. v11 (canStep + clustered nest) 240-0
  vs v9 229/240, p=2.2e-4: kept, submitted.
- 2026-09-12 17:54 UTC round: Andre von Auto 1725 MMR, rank 1 (daveey 1539,
  relh 1531). gorynych:v11 champion, unbeaten in rounds and 330-0 in
  hosted XP today. Top spot reached.
