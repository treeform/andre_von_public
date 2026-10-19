# Grok task: one sword stance experiment

You implement and verify one NMMO policy change. Follow tools/workers.md,
/Users/me/p/AGENTS.md, and read sims/nmmo/AGENTS.md. The shared tree contains
other workers' changes. You may only write files under
games/nmmo/buyan/experiments/sword/. Do not edit baseline buyan.nim.

Copy games/nmmo/buyan/buyan.nim to this directory as candidate.nim.
Implement exactly one strategy: use the best key-addressable sword in the
held slot when profession level >= combat level, otherwise use the best
tool. Combat is the score bottleneck when profession >= combat. If no
usable sword exists, retain baseline tool handling. Equip remains at its
current FSM priority and never attempts while in combat. Preserve best
usable sword and best tool during junk sales. Sword is item kind 4. Hilt
becomes sword during harvesting; do not change harvesting targets or
priorities. Do not add bow, gems, armor upgrades, diagonal attack targets,
navigation changes, or change any existing threshold. Keep existing
orthogonal enemy engagement checks entirely unchanged. Retain harvesting
by re-equipping tool when profession falls below combat. Choose best
key-addressable inventory slots using fresh scalar data, including already
equipped item. Ensure two-tick unequip/equip swaps cannot cycle. A sword
already equipped must not be unequipped just because bestSlotOfType skips
equipped slots. A sword in slots 9-11 is not actionable. Keep baseline
behavior when no usable sword exists.

Sources to read: sims/nmmo/vendor/upstream/nmmo3.h lines 1135-1195,
1300-1405, 1450-1565. Weapon switching requires slot empty first;
fresh equipment scalar offsets are 13+heldSlot. Sword attack animation
is ANIM_SWORD (read exact constant). find_target sets attack animation
even if no target, so distinguish issued attack, observed sword animation,
inCombat feedback, and target health/level changes. Do not claim guaranteed
damage from animation alone. Baseline acts on protocol obs byte array;
stdout is available for hosted evidence.

Add compact structured JSON stdout events under strategy="sword" with
agent index, life generation, local observation step, event name and
appropriate fresh fields. Log every issued held-slot equip/unequip with
expected held item and next-observation confirmed/failed. Log issued sword
attacks and next-observation feedback including fresh held, anim,
inCombat, combatLevel delta and enemy bucket change when the same target
cell is still present. Keep event data bounded and do not store histories.
No flood of logs on uninteresting ticks. Reset all pending state on life
reset. Main can be gated by when not defined(buyanTest) for include tests;
no when isMainModule in tests. New procs all have short doc comments.
New constants PascalCase. Do not restyle baseline broadly.

Write simple doAssert Nim isolation tests in test_sword.nim with synthetic
observation fixtures (not local game scores). Cover selecting sword on
equal levels, retained equipped sword with no cycling, tool->empty->sword
fresh observations, re-equipping tool after combat > profession,
inCombat equip lock, no-sword fallback, unusable slot 9 sword fallback,
best-sword protection from junk sale, reset pending feedback, and issued
versus confirmed attack feedback. Tests must check actual decide/act
behavior as far as practical. Run nim check first, then nim r tests using
--path:/Users/me/p/whisky/src if whisky is not on the default path.
All new code must be Nim. No Python, bash, JavaScript or other scripts.

Write report.md describing exact strategy, changed files, checks and
activation fields needed from hosted real XP. No local game simulations
for scoring. Do not run coworld commands, git commit/push, Docker, upload,
submit, alter simulator/vendor, configs, credentials, or other experiments.
Parent owns hosted testing, and candidate is NOT kept before hosted
statistically significant improvement against current submitted policy.
