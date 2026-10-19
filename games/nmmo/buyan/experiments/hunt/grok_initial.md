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

I'll start by reading the required worker and NMMO agent docs, then inspect source only as needed to implement the hunt strategy.

## Tools

- Read: /Users/me/p/andre_von_auto/tools/workers.md
- Read: /Users/me/p/andre_von_auto/sims/nmmo/AGENTS.md
- ListDir: games/nmmo/buyan/experiments/hunt

## Assistant

Next I’ll read the hunt task spec and Buyan source, then look up melee entity bytes and liveness.

## Tools

- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/hunt/task.md
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/buyan.nim
- ListDir: games/nmmo/buyan
- ListDir: games/nmmo/buyan/experiments

## Assistant

I’ll look at existing experiments, entity-type bytes, and the public scripted bot for melee vs ranged classification.

## Tools

- ListDir: games/nmmo/buyan/experiments/sword
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/ideas.md (1-21)
- Search: entityType|ENTITY_|melee|ranged|bow|enemyEntity
- ListDir: sims/nmmo
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/armor/candidate.nim (2-81)
- Search: ENTITY_|E_ENEMY|E_PLAYER|melee|ranged|bow|entity.?type
- Read: /Users/me/p/andre_von_auto/sims/nmmo/vendor/upstream/nmmo3.h (2-181)
- Read: /Users/me/p/andre_von_auto/sims/nmmo/players/scripted_player.py (1-200)
- Execute: git branch -a | rg -i 'nmmo-scripted|sol' | head -50; echo '---'; git log --oneline origin/sol/nmmo-scripted-20260813 -5 2>/dev/null || git log --oneline --all --grep='scripted' -10 (Find public scripted bot branch)
- Read: /Users/me/p/andre_von_auto/sims/nmmo/vendor/upstream/nmmo3.h (921-1030)
- Read: /Users/me/p/andre_von_auto/sims/nmmo/vendor/upstream/nmmo3.h (1561-1650)
- Read: /Users/me/p/andre_von_auto/sims/nmmo/vendor/upstream/nmmo3.h (1771-1850)
- Execute: git -C /Users/me/p/andre_von_auto/sims/nmmo remote -v; echo '---branches---'; git -C /Users/me/p/andre_von_auto/sims/nmmo branch -a | head -80; echo '---origin sol---'; git -C /Users/me/p/andre_von_auto/sims/nmmo branch -a | rg -i 'sol|scripted' (Find origin/sol scripted branch in sims/nmmo)

## Assistant

I’ll inspect the public scripted branch for melee classification and hunt-approach logic.

## Tools

- Execute: git -C /Users/me/p/andre_von_auto/sims/nmmo ls-tree -r --name-only origin/sol/nmmo-scripted-20260813 | head -80 (List files on scripted inspiration branch)
- Read: /Users/me/p/andre_von_auto/sims/nmmo/docs/PROTOCOL.md (2-151)
- Search: melee|ranged|P_RANGED|entityAnim|ANIM_SWORD|ANIM_BOW|entityElement
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/progress.md (1-9)
- Execute: git -C /Users/me/p/andre_von_auto/sims/nmmo grep -n -i 'melee\|hunt\|approach\|ranged\|isolated\|proactive' origin/sol/nmmo-scripted-20260813 -- 'players/scripted_player*.py' 'players/nimagent/*.nim' | head -120 (Search scripted branch for hunt/melee logic)
- Read: /Users/me/p/andre_von_auto/games/nmmo/ideas.md (2-81)
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/audit_rules.md (1-22)
- Execute: git -C /Users/me/p/andre_von_auto/sims/nmmo show origin/sol/nmmo-scripted-20260813:players/nimagent/world.nim (Show world.nim melee classification from obs)
- Execute: git -C /Users/me/p/andre_von_auto/sims/nmmo show origin/sol/nmmo-scripted-20260813:players/nimagent/executive.nim | sed -n '430,730p' (Show hunt and combat decision section)
- ListDir: games/nmmo/buyan/experiments/armor
- ListDir: games/nmmo/buyan/experiments/clean
- Search: entityElement|TbEntElement|entityTypeByte
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/armor/grok_task.md (1-18)
- Search: when not defined\(buyanTest\)|include candidate
- Search: armor_upgrade|when not defined
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/build.sh
- ListDir: games/nmmo/buyan/experiments/armor
- Search: nim r|nim c|whisky
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/clean/task.md (1-75)
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/sword/task.md
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/escape/task.md
- Read: /Users/me/p/andre_von_auto/games/nmmo/buyan/Dockerfile
- ListDir: /Users/me/p/whisky
- Search: nimable|whisky
- Read: /Users/me/p/AGENTS.md (1-80)