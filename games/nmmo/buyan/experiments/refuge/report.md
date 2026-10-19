# Refuge trial

Injured, out-of-combat fallback rest. Not kept.

One change: the final default wander is NOOP while health < 95, not in
combat, and no live enemy within Chebyshev 4. Heal, fight, tool grab,
flee, equip, harvest, and sell are unchanged. Healthy fallback still
wanders. A live enemy at Chebyshev <= 4 uses the original decide path.

`strategy_action` logs only when the copied-Mind baseline action differs
from the issued wire action. `refuge_hp` logs the next-tick health delta
separately and does not count issuance. Reset clears rest pending state.

Isolation (`nim check -d:buyanTest candidate.nim`,
`nim r -d:buyanTest tests.nim`): injured rest with wire tick 42, healthy
wander match, nearby threat match, herb heal, reset, HP delta +1.

Hosted keep is not implied by these tests.
