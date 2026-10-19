# Supervisor review: complete activation coverage and verify

Your candidate passes `nim check` and all isolation assertions. Logs are
`check.log` and `tests.log` in this directory. Read those for verification.
Continue with your current candidate, no further game/source research.
Only Nim code, write/read tools, no terminal tool, same directory-only limits.
The supervisor will rerun Nim gates and give the final logs for your review.

Critical diagnostic correction (NO BEHAVIOR CHANGE): deferring issue logging
to act is needed. Current logging ignores chosen == -1 in stepTowards, yet
normalization can make the policy fall through to wander, flee, equipment,
or another stepTowards call. Excluding those changed actual actions omits
failed recoveries and biases the hosted activation cohort. Count all actual
changed issued actions caused by this normalization, including fallthrough.

Use bounded per-decision observational fields initialized at the start of
act. stepTowards should record the first original reachable baselineAction
when normalization makes its chosen result differ from baselineAction
(including chosen == -1), but should not emit an issue itself. Only record
when original baselineAction >= 0. Preserve the FIRST such baseline action
if decide later invokes stepTowards again; baseline would have returned at
the first original successful step. After decide returns, act emits
escape_issue only if the actual final action differs from the saved
baselineAction. Keep exact existing schema event,tick,agent,generation,
previousRun,baselineAction,action,issued. Result remains separate pending
issue measured on next observation. If fallthrough returns a nonmovement
action, still count activation; the outcome only measures displacement,
so success is false absent MOVE/RUN displacement and this does not itself
mean the action was strategically bad. No candidate action, threshold, RNG,
pathfinding, or fallback behavior should change for this instrumentation.

Tests must add fallthrough where alternate blocked but baseline would move,
two stepTowards calls preserve first original baseline, final action equals
saved baseline -> no issue, failed secondary and unsafe-primary remain
uncounted, and nonmovement final action is included and has zero displacement.
Adjust direct step tests to check pending diagnostic, or call a narrow
log-issued helper used by act, rather than expecting pre-return issue logs.
Retain all prior tests for normalized behavior, timing, outcome, resets.

Style only for new/edited code: every new proc/test helper has a <=4-line
doc comment; new adjacent lets/vars grouped; const Cases PascalCase; use
let instead of var for ref Mind handles that themselves are not reassigned;
new comments start uppercase and end in periods. Avoid unrelated cleanup.
Update report: describe that stepTowards may newly fall through to -1 when
alternate is unavailable, while fallback policy remains unchanged, and
all actual action differences are included. Replace pending execution with
review of supplied successful logs, marking final edits pending rerun.
