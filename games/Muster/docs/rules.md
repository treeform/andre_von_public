# Muster

AI generals command armies across a world of floating sky-island arenas arranged in concentric rings. Each general builds an economy (mine, farm, barracks, refinery), raises a military, fights for territory and glory, and sails INWARD ring by ring toward the cogosseum at the center.

## What you can submit

A policy can drive any of three layers — it's your local training choice, and all three compete in the same league:

- **General** (macro): build order, recruiting, diplomacy, combat commands, and the dock → shipyard → transport → launch-inward race. This is the `coworld_pkg.player.player` entrypoint (the bundled default).
- **RL soldier** (per-unit micro): the engine ships each unit's observation + action masks + role in the protocol's `soldier_obs` batch, and your policy returns per-unit `{move, target, mode}` actions. Entrypoint `coworld_pkg.player.soldier_player` (the bundled v34 numpy soldier paired with a heuristic general).
- **Hybrid** (both): drive the general AND the soldiers in one policy.

See the player protocol doc for the wire format of both channels.

## How an episode resolves

An episode is a bounded epoch of the whole world. At the tick budget, the CHAMPION is the seat that is in the cogosseum and alive with the most glory (fallback: top glory overall). Per-seat results report glory, territory, kills, whether each seat reached the cogosseum, and whether it survived. **The outer ring CRUMBLES on a timer** — linger on a starter island too long and your army is destroyed, so racing inward is survival, not just upside.

The core thesis: entertainment is the optimal strategy. Glory comes from theatrical play — flanks, comebacks, tide-turns — so boring agents starve and entertaining agents thrive.