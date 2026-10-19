# Armor upgrade experiment

One policy change: occupied helm, chest, and legs unequip when a key-addressable
strictly higher-tier piece exists. Empty-slot fill, tools, gems, combat, heal,
flee, harvest, junk sale, wander, and priorities are unchanged.

## Strategy

`equipAction` still handles tools first, byte-identical to baseline. For each
armor kind in helm, chest, legs order it finds the best unequipped
key-addressable item. Empty equipment slot: return that key (baseline). Occupied
and best tier is strictly higher: return the equipped item's key if that item is
in slots 0-8. Missing equipped key: skip that kind. Equal or lower: never
remove. The next fresh empty slot is filled by existing empty-slot behavior.

Activation is the selected armor unequip key, including when a later obs still
shows the old piece (blocked) or never confirms. Confirmation is later
bookkeeping only.

## Telemetry

Prefix `armor_upgrade`. `act(observation, tick = -1)`; main passes the parsed
wire tick. One pending record per armor slot (`helmSlot .. legsSlot`). Pending
clears on life reset. `armorIssued` / `armorConfirmed` / `armorTierGain` persist
across lives.

Issued line fields: tick, agent, life, action, slot, oldTier, desiredTier,
freshTier, issued, confirmed, tierGain.

Confirmed: tick, agent, life, slot, oldTier, desiredTier, freshTier, issued,
confirmed, tierGain. No action field.

Summary at episode done: event=summary with agent, life, issued, confirmed,
tierGain.

Issuance fires only after decide selected the occupied-armor unequip key, and
only when not in combat, the key item is currently equipped armor, the
equipment scalar matches it, and a strictly higher replacement exists. Tool,
heal, combat, navigation, empty-slot fill, and unused upgrade opportunities
emit nothing.

## Baseline invariant

Baseline `equipAction` issued armor keys only for empty equipment slots, which
are unequipped inventory items. It never selected a key with `is_equipped` set
for helm, chest, or legs. Equipped-armor unequip keys are therefore new versus
baseline. Tool unequip keys are held-slot only. No mutating counterfactual was
run.

## Files changed

- `candidate.nim` — occupied-armor branch, passive telemetry, `act` tick, main
  gate `when not defined(buyanTest)`
- `test_armor.nim` — doAssert isolation tests via `include candidate`
- `report.md` — this file

## Checks

Supervisor-run commands from `games/nmmo/buyan/experiments/armor/`. Repo-root
`nim.cfg` resolves whisky. Both commands completed successfully in order.

| Command | Status |
|---|---|
| `nim check candidate.nim` | PASS, 79390 lines, 0.489s |
| `nim r -d:buyanTest test_armor.nim` | PASS, 79616 lines, 0.693s |

Exact output is in `nim_check.log` and `nim_test.log`. The test ends with
`ok armor upgrade isolation`. Compiler hints are the inherited unused
`combatLevel` and test-gated unused `main`.

The supervisor added the unchanged fresh equipment assertion: two selected
unequip attempts produce issued=2 and confirmed=0, an empty slot stays
unconfirmed, and a later higher tier confirms once. New-code comments and
declaration grouping were tidied and two unused telemetry fields removed.
No additional strategy change was made.

Frozen candidate SHA256:
`09b6ae81513d8e4a7792091e3abefb6e8daa01107f50ca3b7dd195f4ba722622`.

Isolation tests prove the branch, telemetry, and priorities. They are not score
or statistical evidence. No keep verdict. Hosted XP remains a parent gate
(minimum 10 episodes and significance on the matched opponent field).
