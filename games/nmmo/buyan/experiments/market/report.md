# Market

- Change: safe T1 helm/chest/legs shop. ATN_BUY, tier-1 key, then item key
  8..10. Only out of combat, no live enemy in Chebyshev 4, health>=95,
  gold>=9, free inventory slot, empty armor slot with no matching inventory
  item. No upgrades or weapons. Existing sell/heal/fight/flee/equip intact.
- Cooldown: 50 ticks after failed gold/inventory confirm. Reset clears
  per-life shop state. Emergency abort exits buy UI with a move.
- Telemetry: event=strategy_action, experiment=market, wire tick, agent,
  action, baselineAction, generation. Count only changed wire actions.
  Clone Mind + decide(p, false) for the counterfactual. Diagnostics
  attempt/acquired/failed/abort are separate; success is not required to
  count issuance.
- Isolation: nim check -d:buyanTest candidate.nim; nim r -d:buyanTest tests.nim.
  Tests prove the three-step success, failed confirm+cooldown, abort, and
  the strategy_action wire marker. No local scoring.
- Verdict: PENDING HOSTED XP. Nothing kept from synthetic tests.
