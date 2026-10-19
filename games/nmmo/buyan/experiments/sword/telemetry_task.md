# Sword telemetry follow-up

Continue implementing the original sword candidate NOW, then apply this
telemetry addendum as part of the same implementation. Research is complete.
Do not read other experiment directories. Baseline is already copied to
candidate.nim. Use only native read_file/search_replace file tools for
edits. Terminal tools are disabled, so do not try to run code or commands;
the supervisor will run nim check and isolation tests and send output to
you for fixes. Write the tests and report without claiming they passed.

Work only in games/nmmo/buyan/experiments/sword/. Follow original task.md.
All new code must be Nim; CLI commands are fine but no shell scripts,
Python, JavaScript, or inline code in any non-Nim language.

Parent needs trigger logs from actual issued differences, even if the
equipment action fails or the agent dies afterward. Add one JSON event:

{"strategy":"sword","event":"strategy_action","tick":17,
 "agent":0,"generation":0,"step":18,"candidateAction":9,
 "baselineAction":2}

Set tick from actual incoming server message tick (pass into act using
default tick=-1 for isolation tests). Agent is wire observation row index.
Add candidateAction and baselineAction from the SAME fresh observation
and same pre-decision Mind state. Calculate the baseline counterfactual
using exact baseline equipment/junk handling on a copied Mind; the copy
must not change real RNG, selling, attack state, telemetry, or liveness.
No duplicate or spurious logs from counterfactual evaluation. It is fine
to add strategyEnabled=true parameter to decide/equipAction/junkSlot and
keep exact original helper branches for false. Mind fields are flat
arrays and primitives, so copy its object value into a fresh Mind ref
before invoking baseline decide. Check final action is what gets sent.
Only emit strategy_action when the actually returned candidate action
differs from baselineAction. Leave equipment/attack confirmation and
feedback events as separate diagnostics. Add a Nim isolation test proving
counterfactual RNG/mind don't change live state and strategy_action fires
for a differing sword equip action; prove no event for baseline-equivalent
actions and rejected equips still count as issued action changes.

Do not change strategy to repair unrelated policy weaknesses. In report,
document that baseline heldToolTier=0 when holding a sword may cause
extra loose-tool pursuits; parent will judge any later integration fix.

Run nim check then test_sword.nim, update report.md with exact schema
and one real test sample. No local score games, coworld commands,
commit/push, Docker, upload or submit. Candidate remains unkept.
