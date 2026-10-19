# Escape recovery experiment

You are Grok implementing and verifying exactly one NMMO policy experiment.
Work only in `/Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/escape/`.
Read `/Users/me/p/andre_von_auto/tools/workers.md` and
`/Users/me/p/andre_von_auto/sims/nmmo/AGENTS.md` before inspecting game source.
All new code must be Nim. Do not write Python, Bash, JavaScript, or other code.
CLI invocations and Markdown reports are permitted.

Copy the current `../../buyan.nim` (relative to your directory) into
`candidate.nim`. Existing policy behavior remains identical except this fix:
in `stepTowards`, a previous failed run (actions 22 through 25) must be
compared to direction preferences as its base walk direction (0 through 3).
The existing recovery removes a failed walk preference when another target
axis exists, but run ids never match the walk preferences. Normalize the
direction before the existing recovery logic. Do not add pathfinding, alter
thresholds, flee behavior, equipment, targets, passability, or style-cleanup.
Retain the one-axis behavior and existing failed-walk behavior.

Read the actual upstream `move`, `dest_check`, and `c_step` functions in
`sims/nmmo/vendor/upstream/nmmo3.h`. Confirm run is all-or-nothing and fresh
self anim IDLE indicates no displacement. Record exact source citations.

Add compact structured JSON stdout telemetry (stdout is already a log stream,
wire messages use the websocket): only when this normalization actually
causes an alternate returned action, log event `escape_issue` with agent,
generation, previous run, chosen action, and a monotonically increasing
per-agent issued count. On the next valid observation, before deciding a new
action, log `escape_result` with fresh anim, success bool, tile displacement
from ownShift, issued count, confirmed-success count, failed count. Keep this
instrumentation observational and bounded (primitive counters and one pending
flag/action), never change policy based on counters. Avoid false attribution:
if an alternate preference is unavailable and stepTowards returns -1 do not
count an issued change. Successful run/move fresh anim confirms displacement.
Reset must clear pending so a respawn observation cannot confirm prior life
movement. Counters may be per-life if their semantics are documented.

Guard final main() call with `when not defined(buyanTest):` to permit a test
including the candidate. Never use `when isMainModule`. Write `tests.nim`
with doAssert-only isolation tests. Tests must prove all four failed run
directions take the alternate target axis, successful runs are unchanged,
failed walks retain old behavior, one-axis movement is unchanged, no
alternate is not counted, and the next fresh move/run/idle observation
confirms the right telemetry counter. Ensure reset does not misattribute.
Test only isolated policy functions/observations. Do not run local games or
compute any score. `nim check candidate.nim` first, then
`nim r -d:buyanTest tests.nim`. You own writing and executing the tests.
Include useful boundary tests if they remain restricted to this feature.

Write `report.md` with the idea, changed behavior, mechanics evidence,
verification commands/results, telemetry semantics, and verdict PENDING
HOSTED XP. There is no local performance verdict. Parent will commit, push,
upload, request hosted XP, verify triggering and dashboard significance.

Do not touch files outside the experiment directory. Do not commit, push,
build Docker, upload, submit, modify coworld/player configuration, or run
coworld commands. Shared tree has unrelated work: do not revert any of it.
Read any needed repository config and source, but make no unrelated edits.
