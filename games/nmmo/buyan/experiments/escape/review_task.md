# Required telemetry review

Continue the existing escape experiment session. All source/mechanics evidence
is already gathered and candidate.nim is already copied. Implement now.
Do not perform any further research, inspection of other experiments, or
repository documentation reading. Read only candidate.nim and this directory
as needed to make the edits and tests. Merge task.md requirements with the
exact schema below. Preserve the single normalization change. All code is Nim.
No shell scripts/snippets, Python, JS, local games, Docker, git mutations,
uploads, submits, or coworld commands. Read-only CLI commands are permitted.
Your terminal tool is disabled to enforce this. Write files with edit/write
tools. The supervisor will execute nim check and tests, and supply results
for your verification. State pending supervisor execution in the report.

The hosted activation extractor needs exact action-difference attribution.
Every `escape_issue` must include these JSON fields:

`event`, `tick`, `agent`, `generation`, `previousRun`, `baselineAction`,
`action`, `issued`.

tick must be the actual server tick from the wire JSON, not inferred time.
Maintain the current tests by allowing an optional tick argument on act, or
another primitive observational field. No policy behavior may depend on tick.
The main loop must pass parsed tick to act. The issue tick refers to the
action reply tick, not the observation that follows.

Count only when the normalization actually changes the issued action from
the original stepTowards behavior. A failed run that was only the secondary
axis does not count if the original primary is selected anyway. A failed
primary run whose walk direction is absent from allowed safeMoves also does
not count if the original baseline would already select the other axis.
Do not recompute decide or mutate RNG for counterfactuals. Use the bounded
preference/allowed data to establish original chosen action before demotion.
Only issue when actual returned movement differs from baselineAction.

`escape_result` must include `event`, `tick`, `issueTick`, `agent`,
`generation`, `action`, `anim`, `success`, `dr`, `dc`, `issued`, `confirmed`,
`failed`. This is mechanic outcome, distinct from activation. Keep at most
one pending issue. Include the result action so action and fresh displacement
can be checked against hosted replay bytes. Failed result means no fresh
displacement; resets clear pending without attributing a result to new life.

Extend tests for failed secondary preference not counted, failed primary
already excluded by safeMoves not counted, and exact tick/action association.
Run nim check first then doAssert tests. Update report with exact compact
sample JSON logs and final verification. No performance or keep verdict.
