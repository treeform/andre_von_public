# Strict implementation restart

The previous worker was stopped because it violated the user's Nim-only
constraint by invoking `python3 -c` and wrote shell command snippets. It
also wasted time scanning the home directory and other experiments.

Read `games/nmmo/buyan/experiments/clean/task.md` for the full ONE-change
task. Implement it now. Sources have already been reviewed in
`source_review.md`. Every requirement remains in force.

ABSOLUTE EXECUTION RESTRICTION: Do not invoke any shell command except these
three exact standalone commands:

1. `cp games/nmmo/buyan/buyan.nim games/nmmo/buyan/experiments/clean/candidate.nim`
2. `nim check --hints:off games/nmmo/buyan/experiments/clean/candidate.nim`
3. `nim r --hints:off -d:buyanTest games/nmmo/buyan/experiments/clean/tests.nim`

No compound commands, separators, pipes, redirects, substitutions, shell
scripts, Python, Bash, JavaScript, find, ls, directory scans, or package
searches. No other execution commands. Use native Read/Edit/Write tools
for all inspection and code edits. Only read task.md, source_review.md,
baseline buyan.nim, and required sim sources listed in task.md. std/uri is
at `/Users/me/.nimby/nim/lib/pure/uri.nim` if needed. Build config is already
in repo root and works. No need to inspect any other project.

Do not reread worker/playbook docs or other candidates. Implement candidate
and tests first, run the two exact Nim verification commands, fix if needed,
then write report.md. All write paths must be inside clean experiment.

Telemetry needs bounded sample JSON rows containing these exact fields:
`experiment: "clean"`, `event: "activation"`, `tick`, `agent`, `action`,
`baselineAction`, `verifiedClean: true`, `clearedCells`, `extraHints`.
Only emit activation when action differs from copied-state legacy-trust
counterfactual. Counters and final summary also required as in task.md.
The counterfactual has identical clean input, so label it trust-only.
