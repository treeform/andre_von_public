## User

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

## Assistant

I'll start by reading the worker notes and NMMO agent docs, then inspect only the sources needed for the hunt strategy.

## Tools

- Read: /Users/me/p/andre_von_auto/tools/workers.md
- Read: /Users/me/p/andre_von_auto/sims/nmmo/AGENTS.md
- ListDir: games/nmmo/buyan/experiments/hunt
- Read: /Users/me/p/andre_von_auto/sims/nmmo/AGENTS.md
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/hunt/task.md
- ListDir: games/nmmo/buyan
- ListDir: games/nmmo

## Assistant

I'll inspect buyan.nim, a similar experiment, and the narrow source evidence for melee and liveness.

## Tools

- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/ideas.md (1-21)
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/armor/candidate.nim (1-100)
- ListDir: games/nmmo/buyan/experiments/armor
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/buyan.nim (1-200)
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/buyan.nim (201-600)
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/armor/grok_task.md (1-18)
- Search: entityElement|entity byte 5|element
- Search: entityElement|byte 5|element
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/buyan.nim (601-870)
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/audit_rules.md
- Read: /Users/me/p/andre_von_auto/sims/nmmo/vendor/upstream/nmmo3.h (941-990)
- Read: /Users/me/p/andre_von_auto/sims/nmmo/vendor/upstream/nmmo3.h (1801-1850)
- Read: /Users/me/p/andre_von_auto/sims/nmmo/vendor/upstream/nmmo3.h (1571-1650)
- Read: /Users/me/p/andre_von_auto/sims/nmmo/vendor/upstream/nmmo3.h (1871-1990)
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/armor/candidate.nim (531-610)
- Search: hunt|approach|melee|isolated
- Read: /Users/me/p/andre_von_auto/games/nmmo/ideas.md (1-80)
- Search: NPC_AGGRO_RANGE
- Read: /Users/me/p/andre_von_auto/sims/nmmo/vendor/upstream/nmmo3.h (2-91)
- Read: /Users/me/p/andre_von_auto/sims/nmmo/players/scripted_player.py (2-151)
- Search: hunt|approach|melee|isolated|proactive
- Execute: git -C /Users/me/p/andre_von_auto/sims/nmmo show origin/sol/nmmo-scripted-20260813:players/scripted_player.py 2>/dev/null | rg -n -i "hunt|approach|melee|isolated|prey|stage|noop" | head -80 (Search scripted branch for hunt inspiration)
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/build.sh
- Search: nimble|path|whisky|--path
- ListDir: games/nmmo/buyan/experiments/clean
- Execute: git -C /Users/me/p/andre_von_auto/sims/nmmo ls-tree -r --name-only origin/sol/nmmo-scripted-20260813 | rg -i 'nim$|hunt|melee|scripted' | head -80 (List hunt-related files on scripted branch)
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/sword/task.md (1-64)
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/escape/task.md (1-59)
- Execute: git -C /Users/me/p/andre_von_auto/sims/nmmo show origin/sol/nmmo-scripted-20260813:players/nimagent/planner.nim | rg -n -i "hunt|melee|approach|isolated|prey|stage|element|ranged|fight|adjacent" | head -100 (Search planner.nim for hunt-related logic)
- Execute: git -C /Users/me/p/andre_von_auto/sims/nmmo show origin/sol/nmmo-scripted-20260813:players/nimagent/executive.nim | rg -n -i "hunt|melee|approach|isolated|prey|stage|element|ranged|fight|adjacent|noop" | head -100 (Search executive.nim for hunt-related logic)
- Execute: git -C /Users/me/p/andre_von_auto/sims/nmmo show origin/sol/nmmo-scripted-20260813:players/scripted_player_v3.py | rg -n -i "hunt|melee|approach|isolated|prey|stage|element|ranged" | head -80 (Search scripted v3 for hunt logic)
- Execute: git -C /Users/me/p/andre_von_auto/sims/nmmo show origin/sol/nmmo-scripted-20260813:players/nimagent/executive.nim | sed -n '590,720p' (Read hunt block from executive.nim)
- Execute: git -C /Users/me/p/andre_von_auto/sims/nmmo show origin/sol/nmmo-scripted-20260813:players/scripted_player_v3.py | sed -n '230,270p;400,460p' (Read hunt/approach from scripted v3)
- Read: /Users/me/p/andre_von_auto/sims/nmmo/vendor/upstream/nmmo3.h (1356-1405)
- Search: config\.nims|nim.cfg
- ListDir: /Users/me/p/whisky/src
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/captures.nim (1-37)
- Search: newSeq\[uint8\]|observationSize|blankObs|makeObs
- Read: /Users/me/p/andre_von_auto/nim.cfg
- ListDir: games/nmmo/buyan/replays_tools/tests