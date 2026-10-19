# Final sword adapter schema

After implementing the current task, add the now-final sword adapter.
The source marker is JSON:

```
{"strategy":"sword","event":"strategy_action","tick":17,"agent":0,"generation":0,"step":18,"candidateAction":9,"baselineAction":2}
```

Count only candidateAction != baselineAction. All fields tick, agent,
candidateAction, baselineAction have the same strict bounds as other
adapters. Match candidateAction with actual replay action. Do not require
an experiment field since this marker uses strategy. Diagnostics
held_issued/held_confirmed/held_failed/attack_issued/attack_feedback do not
count as additional activations. Counterfactual is unchanged action
choice on a copied current Mind, not a separate baseline trajectory.
Add synthetic valid/mismatch/zero-difference sword tests.

Escape issue markers may contain nonmovement actions after a fallback.
Accept any action in 0..25 and require difference/matching replay, as
specified. Do not restrict escape to 22..25 or movement-only actions.

Armor exact format is in adapter_implement_now.md, not generic JSON.

Clean final marker format has exact prefix `buyan-clean ` before the JSON:

```
buyan-clean {"experiment":"clean","event":"activation","tick":1,"agent":0,"action":5,"baselineAction":25,"verifiedClean":true,"clearedCells":1,"extraHints":1,"counterfactual":"trust-only"}
```

Strip only that exact prefix. Clean logs only the first eight differing
actions per policy episode plus later summary counters. Count only the
individually replay-verified markers. Metric must explicitly state that
trigger_count is a verified lower bound, not all clean changes. Summary
counters cannot add trigger_count without individual replay tick proof.

Hosted coworld CLI log downloads have a bytes-repr wrapper, for example:

```
b'buyan: connected\narmor_upgrade event=issued tick=42 agent=0 life=0 action=8 slot=helm oldTier=1 desiredTier=3 freshTier=1 issued=1 confirmed=0 tierGain=0\n'
```

Before splitting lines, strictly decode one entire optional `b'...'` or
`b"..."` bytes-repr wrapper in Nim. Support `\\`, `\'`, `\"`, `\n`,
`\r`, `\t`, and `\xHH` escapes. Validate closing quote/trailing whitespace
and reject unknown or malformed escapes. Plain real-newline text remains
unchanged. Do not execute Python. Add tests for wrapper and malformed
hex/trailing bytes. Actual reference:
`../baseline_logs/ereq_ae977305-1b5c-47cb-b6d9-136cee3b9d46-policy_agent_0.log`.
