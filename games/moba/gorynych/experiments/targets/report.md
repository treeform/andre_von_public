# Combat focus filter (heroes over creeps)

Candidate relative to frozen gorynych:v1
(`games/moba/gorynych/baseline/gorynych.nim`, blob
`11128e2bcee0ea9695b762bb248266cfc6d567b2`). Sim 0.1.3 /
`moba_sim.wasm` sha256
`b76a9c4cdcc7e4a47c973d4029737a832e0b678646c6a512f5653d3e98f1b8c8`.
No hosted XP, no score, no keep/reject verdict. Reconstruction matched
hosted `final_tick`, `winner`, `end_reason`, all 10x11 `agent_stats`,
and both `ancient_healths` before any action comparison was trusted.

## Scope

Combat target choice only. Movement, siege standoff, waypoint
navigation, retreat, and skill flags are unchanged.

## Frozen v1 is an exact replica of hosted v1 on this dimension

Same-state `heroAction` on reconstructed observations, five heroes in
hosted order so shared tower memory matches. Full 6-int action match
including filter:

| Replay | Seat | Focal | Ticks | Hero-calls | Filter match | Vel match | Full match |
|---|---|---|---|---|---|---|---|
| ereq_82528dd3 (v1 radiant vs daveey, winner dire) | 0 | v1 | 2576 | 12880 | 100.0% | 100.0% | 100.0% |
| ereq_9b896a79 (daveey radiant vs v1, winner radiant) | 1 | v1 | 2901 | 14505 | 100.0% | 100.0% | 100.0% |

v1 always uses filter 0 iff a hostile creep is in the crop, else 2.
That is also `scripted_player.py` and richard's filter: richard vs
daveey is 100.0% filter match in both r3730-g4 (seat 1) and r3728-g9
(seat 0). Filter-2-always is not the leader rule.

## Daveey discrepancy: mixed hero+creep vision

Creep-only ticks: Daveey filter matches v1 at 100.0% in every file
below. The exception is ticks where an enemy hero and a hostile creep
are both in the 11x11 crop. Engine `nearest_scanned_target` then picks
the closest scanned entity (moba.h:976-995). Filter 0 last-hits the
creep; filter 2 focuses the hero (or a tower). Attack range is L1<=12,
so every visible hero is already in auto range.

| Replay | Side | Hero+creep ticks | Filter match | Daveey filter2 / v1 filter0 | Hero-vis hold while v1 moves |
|---|---|---|---|---|---|
| r3730-g4 daveey radiant vs richard (winner radiant) | daveey | 202 | 64.9% | 71 | 253 / 645 |
| r3728-g9 richard vs daveey dire (winner dire) | daveey | 161 | 78.3% | 35 | 40 / 428 |
| ereq_82528dd3 v1 vs daveey dire (winner dire) | daveey | 203 | 77.3% | 46 | 39 / 407 |
| ereq_9b896a79 daveey radiant vs v1 (winner radiant) | daveey | 258 | 89.9% | 26 | 54 / 605 |

Examples (reconstructed obs, exact actions `[vy,vx,filter,q,w,e]`):

- r3730-g4 tick 1059 burst pid 2 hp=5 heroD=2 creepD=5:
  daveey `[0,6,2,0,0,1]`, v1 `[3,6,0,0,0,1]`. Same E, filter 2 vs 0.
- r3730-g4 tick 1064 support pid 0 hp=9 heroD=5 creepD=1:
  daveey `[3,3,2,1,0,1]`, v1 `[3,0,0,1,0,1]`. Same Q+E, filter 2 vs 0.
- ereq_82528dd3 tick 2220 dire support pid 5 hp=10 heroD=5 creepD=3:
  daveey `[6,3,2,1,0,1]`, v1 `[6,3,0,1,0,1]`. Vel and skills identical.
- ereq_9b896a79 tick 2773 support pid 0 hp=9 heroD=2 creepD=5:
  daveey `[3,3,2,1,0,1]`, v1 `[6,3,0,1,0,1]`.

Support hook/stun and burst nuke/stun all take the nearest scanned
entity. With filter 0 that is often a creep, so the hero skill fails
and falls through to a last-hit.

## Rejected alternatives (same reconstructions)

- **Always filter 2, even without a hero.** Creep-only already matches
  100%. Richard is 100% on the v1 creep/no-creep rule. Not supported.
- **Kite-away as the lane-pressure rule.** Daveey away-rate in
  hero-visible ticks is at or below v1 (r3730: 148 vs 251; vs v1:
  138 vs 156 and 205 vs 213). Not the difference.
- **Hold whenever a hero is visible.** Extra Daveey holds are mostly
  *not* combat: r3730 `baseMove-actHold` is 2099 overall but only 253
  with a hero in crop. The rest is siege/waypoint, out of scope.
  Combat-hold is real (9-39% of hero-visible ticks) but mixed with
  siege. Filter is the clean target-choice delta.
- **Topstack / first5.** Out of scope; already tested.

Counterexample to clone-Daveey: 65-90% of mixed ticks Daveey still
uses filter 0. The candidate *always* focuses when a hero is visible,
amplifying the minority Daveey focus rather than matching his mixed
last-hit rate.

## Strategy change

v1:

```
targetFilter = if creepDistance >= 0: 0 else: 2
```

Candidate:

```
v1Filter = if creepDistance >= 0: 0 else: 2
targetFilter = if heroDistance >= 0: 2 else: v1Filter
```

Theory: Daveey keeps split-lane pressure by actually hitting the
contesting hero during a wave instead of dumping nearest-target
skills and autos into creeps. Prediction: more hero-targeted skill
landings and autos on heroes in mixed vision; movement and siege
unchanged.

## Triggers

Counters never feed back into the action. `v1Filter` is computed from
the same crop scan; `changedActions` is incremented only when the
issued filter byte differs from that v1 value.

- `heroCalls`: every `heroAction`.
- `focusFilters`: issued filter 2 while v1 would have issued 0
  (enemy hero and hostile creep both visible).
- `changedActions` / `triggers`: same test on the final 6-int action.
  Equal to `focusFilters` because the filter column is the only
  change.

`MOBA_TRIAL` JSON `{idea: targets, heroCalls, triggers, changedActions,
focusFilters}` on the first trigger, every 1000 hero calls, and done.

## Commands

```
nim check --hints:off --nimcache:games/moba/gorynych/experiments/targets/nimcache/review \
  games/moba/gorynych/experiments/targets/candidate.nim

nim r --hints:off -d:policyTest \
  --nimcache:games/moba/gorynych/experiments/targets/nimcache/review \
  games/moba/gorynych/experiments/targets/tests.nim
```

`builds.nim` does not list `targets`; Dockerfile uses the same COPY
substitution that tool applies to the other experiment names.

No keep/reject claim. Hosted XP significance is a supervisor gate.
