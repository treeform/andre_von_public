Review correction for your recovery experiment. Continue only in
games/moba/gorynych/experiments/recovery. Preserve the strategy exactly.
The supervisor reviewed the diff. changedActions currently compares
PRE-detour vectors and is not an actual issued-action counter. Fix the
instrumentation to compute the original fountain steering plus its own
same-state detour handling from the original state BEFORE the candidate
updates that state, then compare that final baseline velocity to candidate
final velocity. Alternatively report changedIntents under that name and
only increment changedActions in cases where you can prove the actual
emitted difference (e.g. no active or newly-triggered detour in either
branch). Do not let telemetry affect state or change the strategy.
Add a regression fixture with active detours so the counter is honest.
Follow Nim style for any new code. Run nim check then the tests. Update
report.md. No commits/builds/uploads/submissions. Do not search the whole
home directory; all needed files and paths are already known.
