# Recovery experiment: recover near the front

Candidate is a single-change fork of frozen `gorynych:v1`
(`6a471409-9b7d-42dc-ba8c-d61ff45110e9`). Source snapshot:
`games/moba/gorynych/baseline/gorynych.nim`. That file precedes the
local unverified siege edit in `games/moba/gorynych/gorynych.nim`.
Sim 0.1.3 / upstream `f06d28f` was read only. `research/report.md`
was not present; the assigned retreat-destination change was kept.

No hosted XP, no local games for scores, no synthetic score claims.

## Strategy diff

Baseline `RetreatMode` always set `goal = spawns[view.team]` and
walked the BFS field to fountain.

Candidate changes only that destination:

1. Threats are enemy heroes and enemy creeps in the reliable 121-tile
   crop, plus live shooting towers from the static table (ancients
   skipped: `TOWER_DAMAGE` is 0; remembered-dead towers skipped).
2. If min Chebyshev distance to that set is already `> towerVision`
   (5), hold (`dy, dx = 0, 0`) and regenerate in place. Passive regen
   is `+2` health per tick everywhere (`moba.h:1472-1475`).
3. Else choose an 8-neighbor in engine `steps` order that is on-map,
   not a static wall, crop-empty, and strictly increases min threat
   distance. Among those, take the largest min distance.
4. If no such neighbor exists, fall back to the original fountain
   `stepToward`.

Unchanged: enter at health tenths `<= 3`, exit at `>= 8`, push
waypoints, siege hold/soak, lanes, skill flags, target filter, stuck
detour, nav grid.

## Trigger definition

- `triggers`: `RetreatMode` ticks where the local chooser returned
  hold or a local step, not fountain fallback.
- `changedIntents`: those triggers whose pre-detour `(dy, dx)`
  differs from fountain `stepToward`. Intent only; not an issued
  action.
- `changedActions`: those triggers whose **issued** velocity differs
  from original fountain steering after the **same** stuck/detour
  tick, replayed from a snapshot taken before this tick writes hero
  state. A trigger is not counted as a changed action unless that
  issued comparison succeeds.
- `holdTriggers` / `stepTriggers`: split of `triggers`.
- `fountainFallbacks`: retreat ticks that used the original fountain
  walk. Not a trigger.
- `heroCalls`: every `heroAction` invocation, including malformed
  no-ops.

Hold at the fountain is a trigger with `changedActions == 0` and
`changedIntents == 0` (fountain steering is already `(0, 0)`).
Verified in isolation. Active-detour fixtures compare rotated
candidate velocity to rotated fountain velocity, not to unrotated
`stepToward`.

## Telemetry

Bounded integer counters on the policy object. Compact one-line JSON
prefixed `MOBA_TRIAL` on:

- first trigger
- every 1000 hero calls (`reason=periodic`)
- `done` message (`reason=done`)

Fields: `idea=recover-near-front`, `reason`, `heroCalls`, `triggers`,
`changedActions`, `changedIntents`, `holdTriggers`, `stepTriggers`,
`fountainFallbacks`. Echoes happen after the action is fixed.
Detour replay for the fountain baseline is a pure function of the
snapshot; it does not write hero state. Isolation: two policies on
the same obs return the same action.

## Commands and checks

```
cd /Users/me/p/andre_von_auto/games/moba/gorynych/experiments/recovery
nim check candidate.nim
nim r -d:policyTest tests.nim
```

`nim check candidate.nim`: SuccessX, no warnings.

`nim r -d:policyTest tests.nim`: `all tests passed`. Expected hint
only: `main` unused under `-d:policyTest`. First-trigger and
periodic `MOBA_TRIAL` lines printed during the suite.

Fixtures (synthetic 510-byte obs, no sim score):

- Enemy hero in crop: local step increases Chebyshev distance and
  differs from fountain `stepToward`; `changedActions == 1`.
- Live dire T1 in crop: step increases tower distance.
- No visible enemies, nearest shooting tower beyond vision: hold;
  fountain would still walk; `changedActions == 1`.
- All 8 neighbors crop-walls: fountain fallback; `triggers == 0`.
- Hold at radiant spawn: `triggers == 1`, `changedActions == 0`.
- Health 4 stays PUSH, 3 enters, 7 stays RETREAT, 8 exits.
- Full-health PUSH velocity matches baseline waypoint `stepToward`.
- Enemy creep in crop is a threat.
- Assassin E still flags on retreat (skills untouched).
- Active `detourLeft=1`: emitted velocity is the rotated local step;
  `changedActions` matches issued candidate vs issued fountain+detour,
  not unrotated fountain `stepToward` (which a post-update snapshot
  would use once `detourLeft` is already 0).
- Safe hold with the same active detour: issued `(0, 0)` compared to
  rotated fountain velocity.

## Limitations

- Hero crop range is 5; creep scan range is 7. A hold after the
  creep leaves the crop can still be inside creep reach.
- Unseen enemy heroes (outside the crop) are not threats. Chase
  after disengage is invisible until they re-enter.
- Neutrals are not threats. Holding on a camp can aggro it.
- `updateTowerMemory` marks a known tower dead when its cell is
  visible without a `TOWER` tile. That is baseline world-model
  behavior; a live tower must still appear as tile 2 in crop.
- `changedIntents` can disagree with `changedActions` when one
  branch rotates and the other does not (hold vs moving fountain
  under a newly triggered detour). Only `changedActions` is an
  issued-action counter.
- Local steps require a currently empty crop neighbor. Allies or
  creeps blocking every improving cell force fountain fallback.
- Fountain fallback still uses baseline occupancy-blind BFS.
- Isolation tests are crafted obs, not full episodes.

## Concern

Holding just outside tower vision recovers without the fountain
round trip, which is the point, but a false "safe" (creep at
distance 6-7, or a hero that stepped out of crop) leaves a low-HP
hero standing still. Fountain fallback still exists when no local
improving empty cell is found. Whether this helps on hosted XP is
outside this experiment.
