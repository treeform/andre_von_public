# Cooperative Hunting — Seryi Volk

Policy: **Seryi Volk** (`seryi_volk`) — the Grey Wolf — pack hunter.

Coworld: `cow_d5e3a72d-bae0-4418-bb3e-e39f2c5cc81d` (coworld name `cooperative_hunting`)

Six hunters share a 32x32 tile forest. A rabbit falls to one hunter, a boar to two on perpendicular sides, a stag to two on opposite sides, a moose to any three and an elephant only to all four at once -- and everyone on a side when it falls scores the full value. Four variants turn the same capture predicate into cooperative mining, level-based foraging and an asymmetric predator-prey hunt.

## Leagues

- `league_500b6882-6374-43f4-a82b-5e2d0522d9fd` — Cooperative Hunting

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `pack-caller` — Pack Caller: The reference prompt policy: an LLM decides which animal to commit to, from which side and with whom every 15 s, and a controller walks the hunter there tile by tile. (run: `/bin/cooperative-hunting-player`)
- `big-game-hunter` — Big Game Hunter: Coalition-aware baseline: counts nearby allies, derives which animals are catchable at that coalition size, and picks the highest-reward catchable animal, distance-penalised. (run: `/bin/cooperative-hunting-player`)
- `sidekick` — Sidekick: Follows the nearest ally and takes the complementary flank of whatever that ally is standing next to. (run: `/bin/cooperative-hunting-player`)
- `modeler` — Modeler: Expected-value bot: scores every animal by reward x learned per-ally cooperation probability x distance penalty. (run: `/bin/cooperative-hunting-player`)

## Baseline

NOT a thin prompt seat: the sprite_v1 player walks its own hunter every tick — the game only sends one `0x91` plan per 120-tick turn to prompt seats, and both registration (`0x90`) and per-tick input (`[0x84, mask]`) live client-side. `big-game-hunter` (coalition-aware, distance-penalised, and the universal fallback) is the strongest scripted baseline; `pack-caller` is the reference prompt seat. Seryi Volk (`seryi_volk/seryi_volk.nim`) vendors the reference player wholesale: `hunting_bots.nim` carries the full scene parser (camera from background tiles, self via the 0x07 identity packet, energy from HUD digits at y=7) plus all eight scripted baselines, `hunting_shared.nim` the id layout and tile BFS, and the main registers our crafted pack-hunting prompt (kept under the 1200-rune cap) while executing plans with the same `findKillSpot`/`bestCaptureSide`/`navigate` feet as the bundled bots; between plans, and as soon as a named target vanishes, it plays big_game_hunter. `PLAYER_PROMPT` / `PLAYER_SCRIPTED` / `PLAYER_FALLBACK_SCRIPTED` env overrides supported. Upload needs `--secret-env USE_BEDROCK=true` or the seat plays scripted.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Fallback baseline sweep: between plans we play big_game_hunter; try modeler as `PLAYER_FALLBACK_SCRIPTED` (it learns which alias-colours actually cooperate) and measure score across the four variants.
- Prompt elephant bias: 18-each elephants dominate when four commit; test a harder line ("with 4+ hunters visible, elephant is ALWAYS the target") vs the current soft preference, watching for trample losses on half rings.
- Plan persistence: DONE in exp 1 — executor now falls back instead of holding when the target vanishes.
- Side claiming from say: the prompt tells seats to call open sides in `say`; verify in replays whether other seats' plans actually complement (they see say lines one turn late) or whether `with` names do the work.
- Rest-gate tuning: the vendored 30/60 hysteresis was tuned for scripted play; a prompt seat can plan `intent: rest` proactively — test removing the client-side gate for prompt seats so the LLM owns energy.
- predator-prey forager play: the executor treats forage plans via generic navigation; consider a small client-side berry-seeking routine for forager rounds instead of leaning on the 15 s plan cadence.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | plan persistence: don't idle after a kill | when the named target vanishes, executor plays fallback (big_game_hunter) immediately instead of holding until the next 120-tick plan |  |  |  |
