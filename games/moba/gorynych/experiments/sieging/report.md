# Sieging trial: hold one cell further from live towers

Candidate is based on `games/moba/gorynych/baseline/gorynych.nim`
(gorynych:v1, ea38e03), not the post-submit local `gorynych.nim`.
Only the siege approach-stop distance changed. Reconstruction is not a
score. Soak's strictly-closer-L1 cover was not reused.

Pinned wasm sha256
`b76a9c4cdcc7e4a47c973d4029737a832e0b678646c6a512f5653d3e98f1b8c8`.
Every compared episode matched hosted `final_tick`, `winner`, all
10x11 `agent_stats`, and both `ancient_healths`.

## Same-state method

Hosted actions plus observations recovered by replaying seed+body
through the pinned wasm. Frozen v1 is a local library copy with
`main()` disabled. Each tick, the focal seat's five observations are
fed in hosted order `0..4` so shared `deadTowers` matches the player.
Intended v1 actions are then compared to the recorded 6-int row.
v1 vs Daveey games match 100% vel and 100% full row, so the compare
is exact on that policy.

Games (one Daveey each side, one v1 each side):

| Game | Focal | Side | Ticks | Header winner | Verified | velMatch |
|---|---|---|---|---|---|---|
| r3730-g4 | daveey | radiant | 1827 | radiant | true | 50.3% |
| r3728-g9 | daveey | dire | 1177 | dire | true | 53.3% |
| ereq_82528dd3 | gorynych:v1 | radiant | 2576 | dire | true | 100.0% |
| ereq_9b896a79 | gorynych:v1 | dire | 2901 | radiant | true | 100.0% |

## Tower geometry (live shooting enemy, chebyshev <= 8)

v1 siege (frozen): enter at chebyshev `towerVision+1 = 6`. No wave:
hold at 6, retreat at <=5. Wave: dive until `stepToward` stops at
chebyshev <= 1 of the tower cell. Hero auto-attack scans vision 5, so
chebyshev 6 cannot hit the tower. Attack() L1 gate is 12; every
chebyshev-5 cell is already inside it. There is no safe out-of-shot
attack ring.

Recorded holds at live towers:

| Seat | cheb 1 (hug) | cheb 6 | cheb 7 | other |
|---|---|---|---|---|
| Daveey radiant | 156, all wave | 749, no wave | 265, no wave | 0 |
| Daveey dire | 157, all wave | 270, no wave | 131, no wave | 0 |
| v1 radiant | 462, all wave | 3600, no wave | 0 | 0 |
| v1 dire | 407, all wave | 3898, no wave | 0 | 0 |

v1 never holds at chebyshev 7 (velDiff 0 on its own games). Daveey
holds there while same-state v1 still walks: 305/351 ticks radiant,
274/296 dire.

Exact examples (recorded hold, v1 walks, no wave, crop TOWER offset 0):

- r3730-g4 t=1233 pid=3 tank pos=(21,102) tower=(28,103) cheb=7 l1=8
  hp10=9 rec=`[3,3,2,0,0,0]` v1=`[3,0,2,0,0,0]`
- r3728-g9 t=1041 pid=8 tank pos=(101,14) tower=(102,21) cheb=7 l1=8
  hp10=9 rec=`[3,3,2,0,0,0]` v1=`[0,3,2,0,0,0]`

## Rejected alternatives (this boundary)

- Strictly closer L1 cover / wave-surf: soak, already nonsignificant.
  Daveey also hugs chebyshev 1 once a wave is in the tower square
  (156 and 157 holds, matching v1's arrived-dive hold).
- Rim hold at chebyshev 2-5: 0 ticks for Daveey and for v1.
- Hold inside vision with no wave: `v1OutRecHold` = 0 both Daveey
  seats. They leave, same as v1.
- Dead-tower memory: every visible TOWER tile sits on the truncated
  static cell (offset `{0: 615, 556, 830, 802}`). Walking onto a
  remembered-dead tower cell: 0. Not a memory bug.
- Walking in from v1's standoff 6: only 18 and 5 ticks. Daveey mostly
  also holds at 6.
- L1 standoff: Daveey holds at cheb 7 across L1 8-12, and never at
  cheb 8. The extra stop is chebyshev 7, not an L1 cutoff.

Counterexample to a hard rule: at cheb 7 Daveey holds 265/351 (75.5%)
radiant and 131/296 (44.3%) dire, not 100%. The extra holds are still
the largest near-tower velDiff vs v1.

## One change

`siegeStandoff = towerVision + 2` (7). Frozen v1 is `+ 1` (6).
Unchanged: any-creep engage, retreat at vision 5 without a wave, dive
to the tower cell when engaged, waypoints, skills, dead-tower memory.

Prediction: stop one cell further while the wave is not yet in the
tower square, then dive the same way. Fewer unsoaked steps from 7
into 6/5 before the wave. Not a cover-target change.

## Trigger and counters

`triggers` increments when push-mode siege runs at chebyshev exactly
7 (the new cell). `changedActions` increments only when the issued
6-int row differs from a same-tick reconstruction of v1 standoff 6
(same detour snapshot). `holdAtSeven` increments when that difference
is candidate hold vs v1 walk.

A trigger is not a changed action. Cheb 7 with a visible soak creep
can dive on the same step v1 already took toward the waypoint
(`changedActions == 0`). The no-wave fixture is the proof of a
different issued action: `[3,3,2,0,0,0]` vs a nonzero v1 velocity.

Stdout: `MOBA_TRIAL {...}` on the first trigger, every 1000
`heroAction` calls, and on done. Fields: `idea` (`sieging`), `event`,
`heroCalls`, `triggers`, `changedActions`, `holdAtSeven`.

## Checks

```
cd games/moba/gorynych/experiments/sieging
nim check --nimcache:nimcache/check candidate.nim
nim r -d:policyTest --nimcache:nimcache/tests tests.nim
```

Isolation: cheb 7 no-wave hold vs v1 walk; cheb 6 both hold; cheb 5
both leave; cheb 8 both push; retreat ignores the new cell; assassin
Q/W/E unchanged when the hold changes velocity; two policies on one
obs match.
