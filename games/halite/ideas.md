# Halite — Stepan Razin

Policy: **Stepan Razin** (`stenka_razin`) — the river fleet ataman — ships and halite.

Coworld: `cow_29bc2ed0-089b-4087-98fe-d9876fd51d0a` (coworld name `halite`)

A bit-exact port of Kaggle's Halite IV (kaggle-environments 1.32.7). Four fleets mine a 21x21 wrap-around board of halite, haul it home to their shipyards and ram each other: when two ships end a turn on the same cell the one carrying LESS survives and takes the other's cargo, and equal cargo kills both. Halite in a hold is worth nothing and is stealable; halite in the bank is worth everything and can never be lost. Mining longer earns more but makes you heavier, and heavy loses every collision. Most banked halite at turn 400 wins. Turn resolution is the vendored upstream code itself, not a re-implementation, and a differential fidelity gate proves it every CI run. Policies issue a 20-turn fleet directive; a deterministic micro layer moves every ship.

## Leagues

- `league_82571537-04b2-4611-8200-59349283a022` — Halite

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `tidewalker` — tidewalker: The published scripted baseline and the executor of every LLM directive: mine the richest cell nearby, come home when full, never end a turn beside a lighter enemy. (run: `python -m players.halite_player`)
- `corsair` — corsair: The raider baseline: light hulls, a lower return threshold and hunting always on, so the cargo-theft collision rule is exercised in every episode including the all-scripted CI smoke. (run: `python -m players.halite_player`)

## Baseline

`tidewalker` is the published default (and the server-side fallback for any
seat that misses a deadline); `corsair` is the raider variant whose only
edges are `spawnUntil` 300 and always-on hunting. Both are one pure function,
`server/cogame_halite/micro.py::compile_turn`, with tuned directive constants
(`mineFloor` 200, `returnAt` 300, the grid-sweep winners).

**Stepan Razin** (`stenka_razin/`) is a COMMAND PLAYER — this game's seats
answer every `observe` with an `orders` frame inside the shared 400 ms
deadline, and an LLM seat would have to run its own Bedrock sidecar
player-side. The policy is a faithful Nim port of `compile_turn`
(mine-richest-nearby, return-when-full, avoid-lighter-collisions, yard
guard, second yard, spawn ladder), playing the tidewalker constants by
default and the corsair constants with `PLAYER_SCRIPTED=corsair`.

Upload secret-envs: none — no LLM in the container.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Turn-indexed directive schedule: expand constants early (`spawnUntil` high,
  `returnAt` low) then switch to defensive mining after turn 300 — the port
  makes the directive a function of `turn` instead of a constant.
- End-game cash-out: force `returnAt` to 1 in the last ~30 turns so nothing
  dies holding cargo, and stop spawning when a spawn can no longer repay 500.
- Smarter patch scoring: account for the 0.25 collect rate over an expected
  2-3 turn stay and the 0.02 regen, instead of raw `value/(1+2d)`.
- Guard the yard: keep one deliberately-empty ship parked on the busiest
  shipyard once any enemy ship comes within 4 cells (yard-ram insurance).
- Hunt tuning sweep: `PLAYER_SCRIPTED=corsair` vs tidewalker in the same XP
  request, then try hunt thresholds (cargo <= 50, range 5) as a third arm.
- Avoid-crowd rule from anchutka: never step to a cell adjacent to two or
  more lighter enemies even when the cell itself is halite-rich.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Leader `co-gas-halite-bank-cycle-richard:v1` (richard, #1, MMR 1170, 82% WR, mean ~2265) banks cargo every short trip; we sit until a flat `returnAt` 300. Score is banked only — hold cargo is 0 and stealable, and corsair-style hunters fire at enemyCargo >= cargo+200, so a 300-hull is food. Dash 2026-09-01 (no field.md): us #5/5, 707.3, mean 824, 9% WR, 16-92 vs bank-cycle, 23-85 vs `halite-example`. Grid sweep never tried returnAt < 300. | Distance-aware bank-cycle: `cycleAt = min(returnAt, 50*max(1, homeDist))` instead of flat 300. 50 ≈ one mineFloor collect per step home. | | | |
