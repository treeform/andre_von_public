# Gear

- Change: `harvestTarget` treats harvestable ORE as armor even at the
  profession XP cap. Need: held tool can harvest the ore tier, and at
  least one helm/chest/legs slot is empty or lower tier. Priority after
  tool upgrades, before ordinary XP resources. `equipAction` unchanged.
- Vendor: `nmmo3.h:1180` converts ore to a random helm/chest/legs of
  the same tier.
- Telemetry: `event=strategy_action`, `experiment=gear`, wire `tick`,
  local `agent`, `action`, `baselineAction`, `generation`. Count only
  changed actual wire actions. Cloned Mind `decide(..., false)` is the
  counterfactual; candidate RNG is not used for it. Diagnostics are
  separate (`gear_same`). Reset clears `currentTick`.
- Isolation: capped+missing armor selects ore and emits the wire
  marker; sufficient armor does not; unharvestable tier ignored. Tool
  still beats ore; ore beats XP wood; full inventory and heal preserved.
- Verdict: PENDING HOSTED XP. Synthetic tests do not keep the policy.
