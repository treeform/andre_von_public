# Supervisor validation, 2026-09-12

- `nim check games/nmmo/buyan/experiments/sword/candidate.nim`: PASS.
- `nim check -d:buyanTest games/nmmo/buyan/experiments/sword/test_sword.nim`: PASS.
- `nim r --hints:off -d:buyanTest games/nmmo/buyan/experiments/sword/test_sword.nim`: PASS.
- Output ended with `ok duplicate sword can be sold` and
  `all sword isolation tests reached the end` (exit 0).
- All original Grok tests passed. The supervisor added one duplicate-sale
  fixture and changed sword junk preservation to retain one preferred
  slot instead of every equal-tier sword. No other behavioral edit.
- Immutable ready.nim SHA256:
  `9f39fd4af88c7824502510b6a496ab95ede3750524b78c23c809105abd8675ec`.
- Parent was handed ready.nim for CPUX. Do not edit ready.nim.
- At freeze, candidate had not run hosted XP and was not kept or submitted.
  Later uploads and request IDs are recorded in report.md.
- Grok final read-only verification: no blocking bug; confirmed one-slot
  sword retention, unchanged tool behavior and trigger/diagnostic split.

Actual isolation stdout sample:

```json
{"strategy":"sword","event":"strategy_action","tick":17,"agent":0,"generation":0,"step":1,"candidateAction":9,"baselineAction":8}
{"strategy":"sword","event":"held_issued","agent":0,"generation":0,"step":1,"slot":1,"item":4,"expected_held":4,"op":"equip"}
```

Held failure test logs a changed action before failed confirmation, and
the failed action remains eligible for the activation count. Sword attack
feedback distinguishes anim=3,in_combat=0,health_bucket_delta=0 from a
fixture with anim=3,in_combat=5,health_bucket_delta=-2. These are isolation
proofs, not hosted score or guaranteed engine target attribution.

Code review risks for hosted analysis:

- Engine sword auto-targets diagonal cells before some orthogonal cells,
  so feedback on the hint cell need not describe the actual engine target.
- Holding sword makes baseline heldToolTier zero; loose-tool pursuits can
  therefore include duplicate tools. This behavior was left unchanged.
- Only strategy_action selects trigger-positive episodes. Confirmation
  and combat feedback provide diagnostic counts, not inclusion criteria.
