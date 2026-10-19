# Sword focused review fixes

CURRENT FINAL TASK: Read-only verification. Do not edit ANY file.
Supervisor already applied the one-slot duplicate sword fix below and
added its isolation test. Read checks.md for actual PASS output; inspect
candidate.nim and test_sword.nim to verify focused correctness. candidate.nim
and ready.nim are frozen, identical SHA256
9f39fd4af88c7824502510b6a496ab95ede3750524b78c23c809105abd8675ec.
Parent is CPUX testing this exact version. Native read_file is your only
tool. Report review result briefly to stdout, identify any blocking bug
without editing. No further research or unrelated file reads.

Historical requested fixes for review context (already implemented):

Only edit experiments/sword using native file tools. No terminal tool.
Current junkSlot computes bestSwordTier and preserves ALL swords of that
tier. This can fill inventory with same-tier sword duplicates and block
harvesting. Preserve only the one best key-addressable sword slot selected
by bestKeySlotOfType; normal already-equipped protection still applies.
Other unequipped duplicate swords must be saleable under original tier
ordering. Add a doAssert fixture proving one duplicate sword can be sold
while the preferred sword and best tool are retained. Do not change the
baseline tool duplicate behavior because it is outside this experiment.

Review telemetry target attribution: sword engine auto-target scan sees
diagonals before orthogonal squares, even though decide eligibility stays
orthogonal. A hint-cell bucket change is diagnostic only and cannot claim
the engine hit that exact target. Keep this caveat in report.md.

Do not claim tests passed until supplied supervisor output says so.
