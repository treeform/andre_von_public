# Forward remaining-waypoint skip

Candidate: `games/moba/gorynych/experiments/routes/candidate.nim`
Base: `games/moba/gorynych/baseline/gorynych.nim` (gorynych:v1, ea38e03).
Not started from `gorynych/gorynych.nim` (local unverified siege change).
Local `baseline.nim` is that freeze with `main()` gated by `policyTest`.

Reconstruction used the pinned sim
`b76a9c4cdcc7e4a47c973d4029737a832e0b678646c6a512f5653d3e98f1b8c8`.
Every cited game matched hosted `final_tick`, `winner`, `end_reason`,
all 10x11 `agent_stats`, and both `ancient_healths`. Not a score.

## Wall / BFS port check

Python `scripted_player.py` zlib wall grid sha256
`ec17403cd2c93547f0d9da4da8d0d89ab08160153dc3a68e680e8dc9cc430478`,
4300 wall cells. Nim packed grid: 4300 walls, **0 cell mismatches**.
All 24 tower cells marked as walls. Radiant spawn BFS first steps:
support/carry `(0,1)`, assassin/burst/tank `(-1,0)`.

Hosted gorynych:v1 vs the freeze, same-state, all five seat obs in
hosted order:

| Replay | Seat | Ticks | NAV vel match | Any-mode vel |
|---|---|---|---|---|
| ereq_82528dd3 (v1 radiant vs daveey) | Andre | 2576 | 4524/4524 **100%** | 12880/12880 **100%** |
| ereq_9b896a79 (v1 dire vs daveey) | Andre | 2901 | 6031/6031 **100%** | 14505/14505 **100%** |

The Nim port's walls, BFS, waypoint follow, retreat, siege, and skills
match hosted v1 exactly. The discrepancy is Daveey vs that scripted
machine, not a wall/BFS translation bug.

## Daveey vs freeze (exact obs/actions)

NAV = not retreat and not live-enemy-tower standoff. Vel is the issued
`(dy,dx)`, not a direction average.

| Game | Seat | NAV match | LeaderHold | Skip-ahead | Detour ± | Other |
|---|---|---|---|---|---|---|
| r3730-g4 daveey radiant vs richard, winner radiant, 1827 ticks | daveey | 1742/5711 **30.5%** | 2072 | 202 | 497 | 936 |
| r3728-g9 daveey dire vs richard, winner dire, 1177 ticks | daveey | 1629/4227 **38.5%** | 705 | 256 | 401 | 775 |

Filter match 89-99%, skill match ~100% except radiant assassin 78.9%
(out of scope). Combat/retreat/siege flags are not the NAV gap.

v1 support on ereq_82528dd3: **1016 siege ticks**. Daveey support:
**0 siege ticks** both games. Daveey support LeaderHold is far from
towers (radiant holds at tower chebyshev 49, wp chebyshev >=16, e.g.
t287 pid0 at `(99,20)` wp=0 dest empty hp=9, freeze steps `(0,1)`).
That is not a 1-cell extra standoff.

Daveey tank LeaderHold is **all** at tower chebyshev 7 (standoff+1):
238 ticks r3730, 131 ticks r3728. That is siege distance, left to
the sieging lane.

Rejected inside this scope (NAV hit vs freeze match):

- Global wave-wait hold: radiant support 1257/1699 vs 158, but
  assassin 54/747 vs 361 and dire carry 6/731 vs 275. Freezes cores.
- Occupancy no-op (first5 family): dest-occupied is only 245/1272 of
  radiant support holds; dest empty is the rest.
- Re-anchor nearest every tick: worse than freeze on every role.
- Wider `waypointReached=8`: no core gain.
- Ancient-cost "behind" skip: noisy because the bot polyline is not
  monotonic in ancient cost.
- Static walls / BFS mismatch: 0 cells.

## Chosen change

In `pushGoal`, among unreached waypoints at or after the current
index, go to the **closest** one instead of the first. Never decrease
the index. Retreat, siege hold/soak, lanes, skills, target filter,
and the 90-degree stuck detour are unchanged.

Same-state proof: on entry `waypointIndex=i`, freeze targets the
first unreached `j>=i`; candidate may jump to a closer `k>j` and
steer at `k`. `changedActions` counts only when the post-detour
`(dy,dx)` differs from steering at `j` with the same detour.

Theory: after a detour or overshoot the freeze walks **back** to a
missed earlier waypoint (radiant tank at `(43,16)` with wp=2 targets
`(58,16)` step `(1,0)`). Daveey cores continue to the nearer remaining
waypoint (that fixture: wp=4 `(32,17)` step `(-1,0)`). Walking back
drops lane pressure. Daveey NAV match vs freeze rises on cores under
this rule (probe, same reconstructed obs, goal change then same
detour):

| Role | r3730 freeze → forward | r3728 freeze → forward |
|---|---|---|
| assassin | 361 → 373 | 425 → 456 |
| burst | 347 → 337 | 276 → 294 |
| tank | 299 → 340 | 542 → 575 |
| carry | 577 → 605 | 275 → 350 |
| support | 158 → 156 | 111 → 110 |

Support holds are not a waypoint-index bug; this change does not
pretend to fix them. Cores are the split-lane pressure.

Prediction: fewer reverse walks on assigned lanes, more time advancing
the polyline, better ancient race against daveey and the topstack
field. Isolation cannot score that.

## Trigger definition

A trigger is one `heroAction` whose closest remaining forward
waypoint is not the sequential first-unreached waypoint.

A changed action is a trigger whose final `(dy,dx)` is not the
sequential-goal step after the same detour. `actualMoves` is a
changed action with a non-zero step (the issued movement differs,
not merely branch entry). Siege hold after a skip is a trigger with
`changedActions==0`.

JSON fields: `idea=routes`, `heroCalls`, `triggers`, `changedActions`,
`actualMoves`. Prefix `MOBA_TRIAL` on first trigger, every 1000 hero
calls, and the done message.

## Checks

```
cd games/moba/gorynych/experiments/routes
nim check --hints:off -d:policyTest --nimcache:./nimcache/candidate candidate.nim
nim r --hints:off -d:policyTest --nimcache:./nimcache/tests tests.nim
```

Both exited 0. Isolation:

- Spawn tank `(113,12)`: step `(-1,0)` to top wp0, `triggers==0`.
- Overshoot tank `(43,16)` wp=2: freeze `(1,0)` to `(58,16)`,
  candidate `(-1,0)` to `(32,17)`, `triggers==1`,
  `changedActions==1`, `actualMoves==1`, index becomes 4.
- Already at the closest remaining index: no trigger.
- Retreat hp=2 from the overshoot cell: fountain BFS, no trigger.
- Standoff without wave: hold `[3,3,...]`.
- Telemetry echo-only; malformed obs no-op; 1000 spawn calls
  `triggers==0`.

## Limitations

- Forward skip does not make Daveey support hold; that remains a
  counterexample to "this matches Daveey support navigation".
- Tank holds at tower distance 7 are siege, not this change.
- Closest-remaining can skip a waypoint the polyline still needs if
  the hero cut the jungle. Hosted XP decides whether that helps.
- No hosted score in this report.
