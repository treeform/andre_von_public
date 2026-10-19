You are a Grok implementation worker on the MOBA leaderboard goal.
All authored code MUST be Nim. Read existing non-Nim sim source only.
Work exclusively in /Users/me/p/andre_von_auto/games/moba/gorynych/experiments/occupancy/. Do not touch other directories.
Read /Users/me/p/AGENTS.md. Follow Nim style for new code; preserve baseline formatting to keep the diff reviewable.
No commits, pushes, Docker builds, uploads, submissions, player changes,
local games for scores, secrets, Python or bash scripts. Direct ordinary CLI
commands and nim check / nim r isolation tests are allowed.

Frozen submitted policy: gorynych:v1, UUID 6a471409-9b7d-42dc-ba8c-d61ff45110e9.
Start by copying /Users/me/p/andre_von_auto/games/moba/gorynych/baseline/gorynych.nim to your candidate.nim.
This snapshot precedes the local unverified siege change; do NOT start from
/Users/me/p/andre_von_auto/games/moba/gorynych/gorynych.nim. Current sim 0.1.3 unchanged at f06d28f:
/Users/me/p/andre_von_auto/sims/moba/vendor/upstream/moba.h,
players/scripted_player.py, docs/PROTOCOL.md are read-only references.
A Grok replay analyst is working in /Users/me/p/andre_von_auto/games/moba/gorynych/research. If report.md exists,
read it for context, but keep exactly the assigned change.

Experiment: Occupancy-aware navigation
Change only navigation: when the chosen movement would enter a currently non-empty observed crop tile, choose an empty 8-neighbor step with the best existing BFS goal cost instead (same map, goals, modes, skills). Apply after detours too. If no empty useful step exists, no-op. Do not change the goal, waypoint, lane, retreat or siege policy. Verify legal direction and an occupied-cell avoidance scenario.

Instrumentation is required. Add bounded per-episode telemetry proving this
specific strategy fired and how much. Emit a JSON summary prefixed MOBA_TRIAL
when the done message arrives, including idea, heroCalls, triggers,
changedActions where demonstrable. First trigger and every 1000 hero calls
also emit cumulative counters, so incomplete logs can show real firing.
Do not claim a trigger means a changed action unless verified. Ensure
telemetry does not alter actions. If practical compare the final action to
baseline in crafted isolation fixtures. No synthetic score claims.
Use when not defined(policyTest): main() to let tests include candidate;
do not use when isMainModule. Add tests.nim with doAssert, no framework.
Run nim check on candidate.nim, inspect output, then nim r -d:policyTest
tests.nim. Write report.md with exact strategy diff, commands, checks,
trigger definition, limitations, and any concern. Never state kept: hosted
XP significance is a supervisor gate. No Dockerfile needed; supervisor builds.
