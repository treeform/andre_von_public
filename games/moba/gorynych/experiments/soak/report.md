# Soak trial: tower cover based on actual targeting

Candidate is based on `games/moba/gorynych/baseline/gorynych.nim`
(gorynych:v1), not the post-submit local `gorynych.nim`. Only siege-wave
safety changed. No hosted XP was run here.

## Engine mechanism

`step_towers` (`moba.h:1414`) scans with `scan_aoe(..., TOWER_VISION, ...)`
then attacks `nearest_scanned_target`.

- `TOWER_VISION` is 5 (`moba.h:45`).
- `scan_aoe` (`moba.h:918`) walks a square `y,x in [pos-r, pos+r]`,
  which is chebyshev radius 5, not L1.
- `nearest_scanned_target` (`moba.h:976`) picks the scanned entity with
  the smallest `l1_distance`.
- `attack` (`moba.h:682`) also gates on L1 `> 12`. A chebyshev-5 cell
  has L1 at most 10, so every scanned target is in attack range.
- Ancients have `TOWER_DAMAGE` 0 (`moba.h:65`) and remain exempt.

So a friendly creep covers the hero only if it is inside that chebyshev-5
square and strictly closer in L1 than the hero. A creep on the vision
edge can be in the square while farther in L1; the old any-creep test
treated that as soak and walked onto the tower.

## Strategy diff

Old siege (baseline / scripted_player.py):

- If a live enemy tower is within chebyshev `siegeStandoff` (6):
  - `engaged` if any friendly crop creep is within chebyshev 5 of the
    tower cell.
  - engaged: goal = tower; else if inside vision 5: retreat to spawn;
    else hold.
- No post-steer clamp.

New siege:

- Same standoff / vision / ancient skip.
- Among friendly crop creeps in that chebyshev-5 square, keep the
  smallest L1 to the tower (`soakL1`).
- `engaged` only if `soakL1 >= 0 and soakL1 < heroL1`.
- After nav + detour, if `soakL1 >= 0` and the chosen step would land
  at L1 `<= soakL1`, zero velocity (do not overtake the soak).

Unchanged: retreat hysteresis, waypoints, stuck detour, skills, target
filter, dead-tower memory.

## Commands and checks

```
cd games/moba/gorynych/experiments/soak
nim check candidate.nim
nim r -d:policyTest tests.nim
```

`nim check candidate.nim`: SuccessX, no warnings.

`nim r -d:policyTest tests.nim`: `All soak tests passed`.

Isolation fixtures (independent copy of the old siege path vs candidate):

- No-creep standoff: both hold `[3,3,2,0,0,0]`; triggers 0, changed 0.
- Creep in tower chebyshev, L1 not strictly closer, standoff: candidate
  holds, baseline dives; trigger 1, changedActions 1.
- Equal L1 inside vision: candidate retreats, baseline dives;
  skills/filter match; changedActions 1.
- Strictly closer creep at standoff, step stays farther than soak:
  actions match; trigger 1, changedActions 0.
- Wave-surf: step onto the soak cell is zeroed; baseline still walks
  `vel_y=0`; changedActions 1.
- Retreat mode with a closer creep: both retreat; triggers 0.
- Assassin Q/W/E unchanged when soak changes movement.
- Two policies on one obs return the same action (telemetry is
  counters only).
- Every 1000 hero calls emits cumulative JSON; done payload has
  `idea`, `heroCalls`, `triggers`, `changedActions`.

## Trigger definition

`triggers` increments when, in push-mode siege standoff, at least one
friendly crop creep is inside the tower's chebyshev-5 square. That is
when the L1-strict cover rule runs.

A trigger is not a changed action. `changedActions` increments only
when the encoded 6-int row differs from a same-tick reconstruction of
the old any-creep / no-wave-surf steering (same detour snapshot, no
wave-surf). The closer-creep dive fixture is a trigger with
`changedActions == 0`.

Stdout:

- `MOBA_TRIAL {...}` on the first trigger, every 1000 `heroAction`
  calls, and on the done message.
- Fields: `idea` (`tower-cover-targeting`), `event`
  (`first` / `tick` / `done`), `heroCalls`, `triggers`,
  `changedActions`.

## Limitations

- Crop vision only: a covering creep inside the tower square but
  outside the hero 11x11 crop is invisible, same as baseline.
- Strict `<` on L1: equal L1 does not dive. The engine tie-break is
  scan order, so a tie can still hit the hero.
- Wave-surf applies whenever `soakL1 >= 0`, including ticks that are
  not L1-engaged. A retreat step that stays at L1 `<= soakL1` is
  zeroed.
- Live `changedActions` after the first divergence uses the
  candidate's stuck/detour history, not a fully forked baseline
  state. First-tick isolation fixtures are exact.
- No hosted episode, no replay score, no synthetic MMR.

## Concern

The local unverified root `gorynych.nim` siege patch is the same rule.
This trial isolates it on the v1 baseline with proof of firing. Whether
it is worth promoting is a hosted XP / significance gate, not something
this directory can answer.
