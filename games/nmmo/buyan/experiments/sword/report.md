# Sword stance trial

Status: uploaded as buyan-sword:v1; hosted XP pending. Not kept/submitted.

- Batch A, 10 paired episodes: xreq_e5c867db-5619-49d2-b992-c68c9bf36c02.
- Batch B, 10 paired episodes: xreq_eea17af4-db65-41bc-96d7-141aed70b14a.
- Grok executed both exact Nim captures/xp-request create commands.
- Both create commands exited 0. Responses are response_a.json and
  response_b.json; each reported pending, zero completed/failed, no error.
- Docker Linux rebuild passed; upload receipt is upload.txt.
- Source commit tag: 465eb93. Receipt coworld version: 0.1.5.

One strategy: use the best key-addressable sword while profession >=
combat, then restore the best tool when combat > profession. The existing
FSM priority and in-combat equip lock remain. Fresh held scalars guide
two-step swaps. Junk sales retain one preferred sword and the baseline
best-tool protection. Existing combat targets, thresholds, armor,
harvesting and navigation are unchanged.

Grok wrote candidate.nim, telemetry and test_sword.nim. Supervisor reviewed
the diff, fixed duplicate-sword retention and added its isolation fixture.
All checks in checks.md passed. Grok's final read-only review found no
blocking bug and verified the duplicate-sale fix and telemetry scope.
candidate.nim and ready.nim are frozen at SHA256
`9f39fd4af88c7824502510b6a496ab95ede3750524b78c23c809105abd8675ec`.

Hosted activation event:

```json
{"strategy":"sword","event":"strategy_action","tick":17,"agent":0,"generation":0,"step":1,"candidateAction":9,"baselineAction":8}
```

The candidate and baseline actions are computed from the same observation
and copied Mind. The copied baseline cannot consume live RNG or mutate
policy state. This event requires an issued action difference. Group by
episode and count these events even when the equip later fails or the
agent dies. Require at least 10 hosted trigger-positive episodes before
applying the parent's statistical test against the same opponent field.

Diagnostic events use strategy, event, agent, generation and step:

- held_issued: slot, item, expected_held, op.
- held_confirmed / held_failed: held, expected_held, slot.
- attack_issued: held, target_r, target_c, combat_level, health_bucket.
- attack_feedback: held, anim, in_combat, combat_delta, target_present,
  plus health_bucket and health_bucket_delta when a non-dead enemy imprint
  remains in that cell.

Count strategy_action, sword equips requested/confirmed/failed, sword
attacks, observed SwordAnim=3, combat deltas, and diagnostic bucket drops.
Only strategy_action defines episode eligibility. Feedback after a reset
is discarded. Animation alone is not a confirmed hit. Stale entity cells
and the sword engine's diagonal scan mean hint-cell health changes do not
identify the actual target reliably. Use hosted replay state for that.

Known scope risk: heldToolTier becomes zero while holding a sword, so the
unchanged loose-tool rule may pursue duplicates. This remains for hosted
evaluation rather than mixing another targeting rule into this trial.

Mechanics checked in sims/nmmo/vendor/upstream/nmmo3.h: hilt-to-sword
conversion 1182-1184; sword scan 870 and 1326-1354; equip lock 1474;
sword attack bonus 1492; two-step held swap 1517-1545.
