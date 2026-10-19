# Nim XP activation adapter

You are Grok implementation worker. Read this spec and the exact references
below. Native file tools only are enabled. Write Nim files immediately;
the supervisor will run Nim checks and feed results to you for review.
No commands, no games, no network, no Python/bash/other languages. Do not
find an alternate execution route. Work ONLY new files
`games/nmmo/buyan/replays_tools/activations.nim`, `activate.nim`,
`tests/activations.nim`, and `activation_usage.md`.

Nim style: read `/Users/me/p/AGENTS.md`. Read
`games/nmmo/buyan/statistics/task.md` for activation output contract.
Another worker writes `replays.nim` in your parent directory. It will
export `Replay` with `header:JsonNode`, `body:string`, `numAgents:int`,
`tickCount:int`, `heroesPerSeat:int`; `parseReplay(data:string):Replay`,
`loadReplay(path:string):Replay`, and
`action(replay:Replay,tick,agent:int):int`. Import this module. Do not
modify it. It may not exist yet: use this pinned interface.

CLI `activate <plan.json> <evidence.json>` prints stats activation JSON.
Plan is the stats plan containing source, experiment, coworld_id,
coworld_version, candidate.policy_version_id and requests[].xp_id.
Evidence JSON is an object with `source:"softmax-hosted-xp"`, and
`episodes` array of {xp_id,episode_id,candidate_position,log_path,replay_path}.
Require exact types, no duplicates, xp IDs belong to plan, nonempty paths,
candidate_position nonnegative and valid in replay. Error class
`NmmoActivationError` wraps parsing/IO/replay failures. Require supported
experiments clean/hunt/escape/sword/armor. Resolve relative evidence paths
against evidence file directory; plan fields are copied into output.

For each local hosted log file, inspect complete stdout lines. Generic
plain status lines are ignored. Parse JSON-only lines and JSON preceded
by exact prefix `armor_upgrade ` if present. Non-JSON status lines such as
`buyan: episode done, result ...` are ignored. Malformed JSON lines fail,
do not silently ignore potentially corrupted activation evidence.

Marker adapters with actual known schemas:
- clean: experiment="clean", event="activation", tick, agent, action,
  baselineAction ints; verifiedClean=true, clearedCells>0, extraHints>=0.
  Require action != baselineAction. This is a trust-only counterfactual
  on the same clean observation, not a full baseline run.
- hunt: experiment="hunt", event="issued", tick, agent, action,
  baselineAction ints, changed bool, kind="walk" or "stage".
  Require changed equals (action!=baselineAction); only changed counts.
- escape: event="escape_issue", tick, agent, action, baselineAction
  ints; only different actions count.
- sword and armor schemas are not finalized. Fail with explicit
  unsupported-adapter error until supervisor provides exact logs. Do not
  invent an adapter or treat any generic issued event as proof for them.

For every candidate marker, require tick in replay range, local agent in
0..<heroesPerSeat, action and baselineAction in 0..25, and actual replay
action at (tick, candidate_position*heroesPerSeat+agent) equals action.
Mismatched replay marker is fatal, not an ignored event. Reject duplicate
countable (tick,agent) markers so one emitted action cannot be counted
twice. Zero differences yields verified=false, trigger_count=0.
Do not count result/confirmation events as additional activations.
No strategy success is implied by an issued changed action.

Output exact stats schema:
{source,experiment,coworld_id,coworld_version,
 candidate_policy_version_id,episodes:[{xp_id,episode_id,
 candidate_position,verified,trigger_count,log_path,metric,replay_path}]}.
`metric` describes adapter, actual action match, counterfactual limitation
where relevant, and does not claim combat/item/movement success.
No scores read or emitted. No KEEP or significance claim.

Tests in `tests/activations.nim` use synthetic fixtures and plain doAssert.
Generate replay bytes in Nim (no local games). Test each supported adapter,
actual action mismatch, action bounds, absent baseline action, zero diff,
duplicate markers, duplicate episode IDs, unknown XP ID, unsupported
sword/armor, two seats and two agents mapping. Label synthetic clearly.

Stop after creating files and reviewing code against spec. Report what
Nim commands the supervisor should run. Do not attempt tool workarounds.
