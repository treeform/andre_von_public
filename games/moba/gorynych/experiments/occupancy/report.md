# Occupancy-aware navigation

Candidate: `games/moba/gorynych/experiments/occupancy/candidate.nim`
Base: `games/moba/gorynych/baseline/gorynych.nim` (gorynych:v1 snapshot).
Not started from `gorynych/gorynych.nim` (local unverified siege change).
Research `report.md` was not present.

## Strategy diff

Navigation only, applied after BFS steering and after the 90-degree
detour. Goal, waypoint, lane, retreat, siege, skills, and target
filter are unchanged.

When the chosen unit step `(dy, dx)` is non-zero and the destination
crop tile is currently observed and non-empty (`tile != EMPTY`, including
walls, towers, creeps, neutrals, and heroes), replace the step with the
empty 8-neighbor that has the lowest existing BFS cost toward the same
goal, tie-broken in engine `steps` order. A neighbor is useful only if
it is in bounds, the crop tile is `EMPTY`, and the cached cost field is
not `unreached`. If no such neighbor exists, the step is `(0, 0)`.

`move_to` (moba.h:561-566) already fails silently into non-empty cells.
This change avoids issuing that doomed step when the crop shows the
blocker.

Telemetry is echo-only. Counters are updated after the step is chosen.
`changedActions` is incremented only when the post-occupancy `(dy, dx)`
differs from the pre-occupancy pair.

## Commands

```
cd games/moba/gorynych/experiments/occupancy
nim check --hints:off candidate.nim
nim r --hints:off -d:policyTest tests.nim
```

## Checks

`nim check --hints:off candidate.nim` exited 0 with no diagnostics.

`nim r --hints:off -d:policyTest tests.nim` exited 0.

Isolation fixtures (doAssert, no framework):

- Legal direction: occupancy vel is `{0, 3, 6}` on each axis (unit
  steps only). At radiant tank cell `(90, 16)`, baseline stepped
  `(1, 0)`; occupying that dest with a friendly creep produced
  `(1, -1)`, an empty 8-neighbor matching `occupancyReroute`.
- Occupied-cell avoidance: dest crop tile was `RADIANT_CREEP`; the
  chosen dest after occupancy was `EMPTY`. Target filter and skill
  flags matched the empty-crop baseline action.
- Empty dest: same action as baseline, `triggers == 0`.
- Occupied non-dest neighbor: step unchanged, `triggers == 0`.
- No empty useful neighbor: all 8 neighbors occupied -> `[3, 3, ...]`,
  `triggers == 1`, `changedActions == 1`, `occupancyNoops == 1`.
- After detours: occupying the post-detour dest triggers; occupying
  only the pre-detour BFS dest does not, and the emitted step is the
  detour.
- Telemetry: first trigger emits `MOBA_TRIAL` JSON; call 1000 with no
  occupancy emits cumulative counters with `triggers == 0`.
  `emitTrial` does not change counters or the action.

## Trigger definition

A trigger is one `heroAction` whose chosen movement after detours would
enter a currently non-empty observed crop tile.

A changed action is a trigger whose final `(dy, dx)` is not that chosen
movement, verified by comparing the pair before and after
`occupancyReroute`. A trigger is not counted as a changed action unless
that comparison is true. In these fixtures every trigger also changed
the step (occupied dest is never re-selected; boxed-in becomes a no-op).

`occupancyNoops` counts triggers whose reroute was `(0, 0)`.

JSON fields: `idea`, `heroCalls`, `triggers`, `changedActions`,
`occupancyNoops`. Prefix `MOBA_TRIAL` on first trigger, every 1000
hero calls, and the done message.

## Limitations

- Only the 11x11 crop is used. Occupancy outside vision is invisible.
- "Useful" means empty and BFS-reached, not strict cost descent. A
  side-step may have equal or worse cost than the blocked dest.
- After a detour, the replacement is still best BFS-toward-goal among
  empty neighbors, not best along the detour heading.
- If occupancy no-ops, `triedMove` becomes false, so stuck-detour may
  not fire while the hero is boxed in.
- Friendly-creep occupancy can also feed siege `friendlyCreeps` if a
  live enemy tower is in standoff range. The isolation cell was far
  from enemy towers so filter and skills stayed matched.
- No hosted XP. No score claim.

## Concern

Walking around a wave can leave the hero beside the lane instead of
inside it, and a no-op in a packed cell wastes a tick that the engine
would have wasted anyway. Whether that helps the ancient race is a
hosted comparison, not a local claim.
