# Hunt experiment

Use Nim only. Read `/Users/me/p/andre_von_auto/tools/workers.md` and
`/Users/me/p/andre_von_auto/sims/nmmo/AGENTS.md` before source inspection.
You may write ONLY inside this directory:
`/Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/hunt/`.
The tree is shared. Never edit or revert anything elsewhere.

Copy `/Users/me/p/andre_von_auto/games/nmmo/buyan/buyan.nim` to
`candidate.nim`. Implement ONE strategy change: when rested and otherwise
ready, proactively approach a single isolated, live, beatable melee enemy
to bootstrap combat XP and tool drops. Existing bot fights only adjacent
enemies, and otherwise flees even easy nearby targets.

Read source to identify melee enemy type (entity bytes) and valid liveness.
You may read public `origin/sol/nmmo-scripted-20260813` in sims/nmmo for
inspiration with `git show`. No whole-port. Do not alter combat thresholds,
armor, clean-observation behavior, equipment, healing, or selling logic.
Preserve priority for UI exits, urgent heal, adjacent fights and tool grabs.
Stronger/ranged targets, corpses, stale ghosts, crowded enemies, wounded
self, and emergency in-combat fleeing must NOT invoke proactive hunt.
Allow approach as the narrow exception before generic close enemy flee;
once adjacent, use original fight branch. Require actual melee classification
from observed entity bytes and preserve existing trusted liveness.

Supervisor correction from independent source review: players act before
NPCs every tick. Never move from Manhattan distance 2 into adjacency because
that gives NPC a first hit and makes original rested fight gate reject it.
Use walking-only approach to stage at distance 2, then NOOP to let that single
melee enemy close adjacent (enemy_ai moves instead of attacks from distance 2).
At distance 3, walk reduces to 2 and NPC can close itself. Keep all baseline
combat gates EXACTLY unchanged. Waiting is part of this navigation strategy
and must be bounded (e.g. at most 2 waits on same target while still live).
Never trust stale target indefinitely; liveness TTL and bounded wait enforce.
Each issue telemetry should distinguish walk versus stage wait; confirmation
should distinguish own moved, enemy closed, actual combat and tool gain.

Source findings already verified: entity byte 5 = element (nmmo3.h:964).
Spawn uses safe_tile→GRASS; enemy level >=15 means ranged and nonzero element
(1819-1834), so element 0 identifies melee. Existing enemyHints excludes corpse.
Only read relevant narrow sources. Dependency whisky is expected in
`/Users/me/p/whisky/src`, with crunchy/chroma/flatty in sibling repositories.
Do not search all /Users/me or run broad find. Try nim check first to learn
whether explicit --path arguments are needed.

Add compact structured stdout telemetry for proactive hunt-issued steps,
confirmed own movement, subsequent actual combat and tool acquisition.
Avoid false attribution: report issued separately from confirmed. Correlate
using agent index, generation and monotonic decision index. Bounded state.
No policy behavior changes solely for telemetry. A replay extractor and
hosted scorer will consume logs later.

Exact activation requirements from parent: log actual wire tick (passed from
main parsed message tick into act, optional default for tests), agent index,
generation, action, baselineAction. Need baseline counterfactual from same
observation and pre-branch state. One simple implementation: add optional
huntEnabled=true to decide, then when choosing hunt copy `Mind[]` by value
into fresh Mind, call decide(copy,p,false) to get baselineAction. This runs
the unchanged original FSM and RNG on a copied mind, not the actual mind.
Emit JSON object with fields {"experiment":"hunt","event":"issued",
"tick":T,"agent":I,"generation":G,"action":A,"baselineAction":B,
"kind":"walk" or "stage","changed":A!=B,"r":R,"c":C}.
Counts for hosted activation MUST use changed=true issued actions only,
regardless of subsequent failure/death. Confirmation events are diagnostics,
NEVER conditioning the scored sample on successful combat/tool pickup.
Keep baseline counterfactual branch log-free and behavior-identical.

Avoid broad exploration and repeated source reads. Start writing candidate
now using the already verified source facts above. Normal nim check works
with repository nim.cfg (supervisor checked baseline successfully).
NO Python or shell scripts/snippets, including for file transformation.
Nim only for authored code. Use file-edit tools to copy/edit source directly.

Gate main call with `when not defined(buyanTest):`, never when isMainModule.
Write `tests.nim` using include candidate and doAssert isolation cases for
positive hunt, corpse/ghost/stronger/ranged/crowded refusal, priorities, and
telemetry confirms only movement/combat/tool change observed after issue.
Check with `nim check candidate.nim` first, then `nim r -d:buyanTest tests.nim`.
These are isolation tests, NEVER local scored games. No Python/bash/JS code.
Use simple direct CLI tools only for command execution.

Every new proc gets a <=4-line doc comment. Use 2-space indentation,
PascalCase new constants, camelCase vars/procs, grouped adjacent declarations,
and <=80 columns where practical. Keep delta minimal and explicit.

Write report.md with exact change, source evidence, tests and changed line
count, telemetry field schema, limitations. Verdict is PENDING HOSTED XP,
never keep. Parent owns at least 10 hosted episodes and dashboard significance.
No commits, pushes, Docker, coworld commands, upload, submit, config changes,
web browsing, subagents, or edits outside the experiment directory.
