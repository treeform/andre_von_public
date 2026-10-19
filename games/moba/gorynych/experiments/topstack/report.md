# Topstack experiment

Five-hero top lane concentration on frozen gorynych:v1
(`6a471409-9b7d-42dc-ba8c-d61ff45110e9`). Candidate starts from
`games/moba/gorynych/baseline/gorynych.nim`, not the later unverified
siege tree. Sim 0.1.3 at f06d28f. `research/report.md` was not present.

Leaders richard and relh ship policies named topstack. This candidate
copies only the lane assignment: every hero walks team top. Goals,
waypoints, navigation, skills, retreat and siege are otherwise the
baseline scripted machine.

## Strategy diff

Baseline `laneForHero = [2, 1, 1, 0, 2]` (support bot, assassin mid,
burst mid, tank top, carry bot). Dire adds 3.

Candidate:

```
baselineLaneForHero = [2, 1, 1, 0, 2]
laneForHero = [0, 0, 0, 0, 0]
```

`waypoints[lane + 3*team]` is then radiant top (lane 0) or dire top
(lane 3) for all five roles. Tank is unchanged. The other four roles
are the affected set.

`lane` / `pushGoal` take an explicit lane table so isolation tests can
run the baseline table without touching production actions. Telemetry
is a wrapper around that core.

## Trigger definition

A trigger is one `heroAction` call whose `heroType` has a different
baseline lane than top:

- support (0), assassin (1), burst (2), carry (4): trigger
- tank (3): not a trigger

Triggers count affected heroes, not episodes. A 5-hero seat therefore
triggers on 4 of 5 calls. A 1-hero tank seat triggers on none.

`changedActions` is not the trigger count. It increments only when:

1. the call is a trigger,
2. `waypointIndex < 0` before the call (first push, post-retreat
   re-anchor, or post-teleport reset),
3. a cloned-state eval with `baselineLaneForHero` returns a different
   6-int action.

The clone cannot mutate production state. The production action is
computed first and returned unchanged.

## Isolation quantification

Fountain spawn, empty crop, full health. Both teams.

| team | hero | baseline lane | stacked lane | baseline goal | stacked goal | first action changed |
|---|---|---|---|---|---|---|
| 0 | 0 support | 2 | 0 | (112, 32) | (96, 14) | yes `[3,6,2,0,0,0]` -> `[0,3,2,0,0,0]` |
| 0 | 1 assassin | 1 | 0 | (99, 26) | (96, 14) | no, both `[0,3,2,0,0,0]` |
| 0 | 2 burst | 1 | 0 | (99, 26) | (96, 14) | no, both `[0,3,2,0,0,0]` |
| 0 | 3 tank | 0 | 0 | (96, 14) | (96, 14) | no |
| 0 | 4 carry | 2 | 0 | (112, 32) | (96, 14) | yes, same as support |
| 1 | 0 support | 5 | 3 | (36, 113) | (20, 94) | yes `[6,3,2,0,0,0]` -> `[3,0,2,0,0,0]` |
| 1 | 1 assassin | 4 | 3 | (34, 99) | (20, 94) | yes |
| 1 | 2 burst | 4 | 3 | (34, 99) | (20, 94) | yes |
| 1 | 3 tank | 3 | 3 | (20, 94) | (20, 94) | no |
| 1 | 4 carry | 5 | 3 | (36, 113) | (20, 94) | yes |

10 spawn calls: 8 triggers, 8 changed goals, 6 changed first actions.
Radiant assassin and burst change the nearest waypoint but the first
BFS step from (113, 12) is still north, so a trigger is not an action
change. All five stacked heroes on a team share that first top step.
Skill flags were identical in every spawn pair. Telemetry on the same
10 calls: `heroCalls=10`, `triggers=8`, `changedActions=6`.

Retreat from (40, 80) at health tenths 2 matched baseline for every
role. A support first call already at the fountain in retreat is a
trigger with `changedActions=0`. Siege hold at standoff without a
wave matched baseline for radiant support at (24, 29) and dire carry
at (57, 16). An enemy tile in crop did not change Q/W/E versus
baseline; only movement differed.

## Commands and checks

```
nim check --hints:off games/moba/gorynych/experiments/topstack/candidate.nim
nim r -d:policyTest --hints:off games/moba/gorynych/experiments/topstack/tests.nim
```

`nim check` exited 0 with no output. Tests printed the table above,
emitted `MOBA_TRIAL` on first trigger, every 1000 hero calls, and a
done summary, then `topstack isolation tests passed`.

`main()` is behind `when not defined(policyTest)`. Tests `include`
candidate. No `when isMainModule`.

## Telemetry

JSON lines prefixed `MOBA_TRIAL`, fields `idea`, `event`, `heroCalls`,
`triggers`, `changedActions`.

- `event=first_trigger` on the first affected-hero call
- `event=checkpoint` every 1000 hero calls
- `event=done` when the done message arrives

A 1000-call support loop emitted checkpoint
`heroCalls=1000, triggers=1000, changedActions=1` (only the first
re-anchor compared). Wrapping `heroAction` matched
`heroActionWithLanes` on the same observation.

## Limitations

- `changedActions` is only verified on re-anchor ticks. Later ticks
  walking top instead of mid or bot still trigger but are not counted
  as changed actions.
- Shadow comparison uses the stacked observation stream, not a
  parallel baseline episode with different positions.
- Tank-only seats produce zero triggers.
- No local games and no score claims.

## Concern

Mid and bot are empty. Enemy scripted lanes will take those towers
while five allies share one polyline and can block each other. Leaders
named topstack may do more than this lane table. Radiant mid roles
look unchanged for the first fountain step, so early logs can show
triggers without action diffs. Hosted XP significance is a supervisor
gate.
