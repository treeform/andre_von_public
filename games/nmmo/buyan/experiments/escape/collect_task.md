# Write a bounded Nim hosted-artifact collector

No source research, no policy edits. Work only in this escape directory.
Write collect.nim using std/json, os, osproc and streams. No terminal tool,
Python, scripts, local games, score calculations, or state-changing API.
Native file editing only. Supervisor runs Nim gates. Code must be Nim only.

CLI: collect <episodes-json-path> <output-dir> <policy-version-id>.
Input is already-fetched coworld xp-request get --json, an object with an
episodes array (or accept the episodes array directly). Each episode has id,
status, and participants array with position and policy_version_id fields.
For every completed episode, find participant matching the exact policy
version argument. Do not assume slot order and do not use --mine. Membership
names differ between baseline and candidate; explicit --agent is required.
If there is no matching participant, raise BuyanError with episode id.

For each completed matching episode, create output-dir/<episode-id>/ and
run ONLY this read-only subprocess using startProcess with argument array
and poUsePath/poStdErrToStdOut, no shell invocation:

uv --project /Users/me/p/metta run coworld episode-logs EPISODE_ID --agent POSITION --download-dir OUTPUT_EPISODE_DIR

Capture output and exit code, save download.log per episode, raise BuyanError
if subprocess fails. A successfully downloaded directory can be marked with
complete.txt so reruns do not repeat successful downloads. That file is a
completion marker after exit0, not evidence of strategy activation. Emit
one compact line per episode. If episode status is not completed, skip it.
Loop only input episodes, no polling or new requests. Use bounded primitive
data and explicit loops, one doc comment per proc, grouped lets, let over
var unless changed, PascalCase constants. No when isMainModule. The replay
collector is separate CLI, policy candidate source stays frozen.

Write code immediately. No tests needed for this reversible read-only
utility; supervisor will nim check before using against hosted receipts.
