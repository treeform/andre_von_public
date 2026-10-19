# Worker policy: grok as implementation labor

The supervisor (Claude, the smarter policy) picks targets, writes task
specs, reviews diffs, and owns every gate: `nim check`, docker build,
git commit, upload, submit, and hosted-XP verdicts. Grok workers (much
cheaper per token) do the implementation legwork inside the repo.

## Invoking a worker

    grok --cwd /Users/me/p/andre_von_auto \
      --prompt-file <task.md> \
      --no-plan --always-approve \
      --max-turns 60 --no-subagents

Hard-learned flags: `--prompt-file` conflicts with `-p`; plan mode (on by
default) makes a headless run stop after printing its plan, so pass
`--no-plan`; tool-permission prompts silently end headless runs too, so
use `--always-approve` and rely on a clean git tree + supervisor diff
review as the safety net.

- One task per invocation, spec written to a file (survives quoting).
- Workers NEVER commit, build docker, upload, or submit — same rule as
  policy agents in policy_conventions.md.
- Start from a clean tree so `git diff` is the whole review.
- Workers must NEVER run `coworld player ...` (use/unset) or any state-
  changing coworld command — a worker unset the active player once and a
  policy upload bound to the wrong player. Read-only coworld commands
  only, and only when the task explicitly grants them.

## Task spec shape

State: the game, the goal, the files it may touch, the verification
command that must pass, what to write where (findings go in the game's
ideas.md or a named report file), and the hard "do not" list. Include
pointers to docs/manifest/field.md so the worker doesn't wander.

## Supervisor gates, in order

1. `git status` / `git diff` — review every changed line; revert junk.
2. `nim check` (and docker build when the policy changed).
3. Playbook sanity: does the change follow tools/winning_playbook.md?
4. Commit with a message crediting the task; then upload/submit/XP as
   usual (auto.md rules).

Escalate to a Claude agent instead of grok when the task needs heavy
protocol archaeology, private-repo access decisions, or judgment about
what is worth building.
