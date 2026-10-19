# Walking: wander one tile

## Idea

Ordinary wander `maybeRun`s whenever both tiles are grass, so ~90% of
actions are runs 22–25. The agent crosses more dangerous tiles than it
progresses. Issue the persistent walk 0–3 instead. `stepTowards` and
combat disengage still `maybeRun`.

## Change

`wander` returns `wanderAction` (0–3). RNG draws, option filtering, and
direction persistence are unchanged. Baseline counterfactual is a Mind
copy that `decide`s with `wanderRun = true` (`maybeRun` of the same
direction) so candidate RNG is not consumed twice.

## Telemetry

Stdout JSON. Count only actual wire actions that differ from the clone.

`{"event":"strategy_action","experiment":"walking","tick":T,"agent":A,"action":0,"baselineAction":22,"generation":G}`

`tick` is the wire reply tick. Diagnostics `walking_issue` / `walking_motion`
are separate; motion success is not required to count issuance. `reset`
clears pending per-life fields.

## Tests

`nim check -d:buyanTest candidate.nim` then `nim r -d:buyanTest tests.nim`.
Wander maps 22–25 → 0–3; flee and `stepTowards` still run; wire marker
records the changed walk.
