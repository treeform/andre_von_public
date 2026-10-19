# Escape candidate verification

**Verified.** Isolation gates pass. Hosted XP is still pending. No local
performance claim. Frozen source SHA256 (supervisor):
`c7ed761bb1827616610f92ad26aeb0b46465faa0bbe4c8c9bf7e542eb45704de`.

## Gates

- `check.log`: `nim check candidate.nim` → SuccessX.
- `tests.log`: `nim r -d:buyanTest tests.nim` → SuccessX, then
  `Escape isolation assertions passed.`

## Policy vs instrumentation

The only decision change is run-id normalization before the existing trim
(`candidate.nim:528-539`). `pickPreferred` (`:492-503`) is the original
first-allowed axis/run pick. Telemetry writes `escapeBaselineAction` and
counters only; `decide` does not read them.

## First reachable baseline

`act` clears `escapeBaselineAction = -1` at the start of each valid
observation (`:854`). `stepTowards` records only the first original
reachable baseline (`:544-547`): `isRun(lastAction)`, `baselineAction >= 0`,
`chosen != baselineAction` (including `chosen == -1`), and
`escapeBaselineAction < 0`. A later `stepTowards` in the same decision
cannot overwrite it. `tests.nim:238-254` asserts the first `-1` keeps
baseline 22, the second pick is `leftAction`, `logEscapeIssue(22)` does
not count, and `logEscapeIssue(leftAction)` does.

## Deferred attribution

`stepTowards` does not emit. `act` calls `logEscapeIssue` on the final
`decide` action (`:864-865`). Issue JSON (`:800-809`) is the required
schema: `event,tick,agent,generation,previousRun,baselineAction,action,issued`.
`previousRun` is still `lastAction` because `lastAction` is assigned after
the log (`:872`). `tests.log` shows fallthrough `action` 25 (tick 50) and
nonmovement `action` 8 (tick 60). Equal-to-baseline final actions are not
issued (`tests.nim:249-251`). Failed secondary and unsafe-primary paths
leave `escapeBaselineAction == -1` (`:125-144`).

## Outcome, reset, tick

`maybeLogEscapeResult` runs on the next valid obs, before `decide`
(`:856`). Success is nonzero `ownShift` (`:822-824`), so MOVE/RUN
displacement confirms and IDLE/nonmovement are `dr=0,dc=0` failed
results (`tests.log` ticks 8/41/61). Malformed obs returns noop without
clearing pending (`:847-848`, `tests.nim:170-171`). `reset` clears
pending/issueTick/pendingAction/baseline and not `escapeIssued`
(`:346-349`, `tests.nim:199-215`). Wire `tick` is passed into `act`
(`:947`).

Doc nit only: `report.md` result table still says success is MOVE/RUN
anim; the frozen code uses displacement. Same outcomes on the logged
tests.
