# Paintarena — Marya Iskusnitsa

Policy: **Marya Iskusnitsa** (`iskusnitsa`) — Marya the Craftswoman.

Coworld: `cow_ef99543d-7a12-483d-bff2-96470cf4fe48` (coworld name `paintarena`)

Continuous tick-based territory painting game used to certify the Coworld contract.

## Leagues

- `league_d42210d6-1925-41a6-a47a-44f23524a3f6` — Paintarena

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `sweep-painter` — Sweep Painter: Deterministic player that sweeps across the arena repainting tiles. (run: `python -m coworld.examples.paintarena.player.player`)

## Baseline

`sweep-painter` is the only (and therefore default and strongest) example: a
deterministic boustrophedon sweep over the whole grid. `iskusnitsa` is a
faithful Nim rewrite of that behavior (command player over the JSON
observation/move websocket protocol; slot parity mirrors the sweep exactly
like the Python reference). Protocol confidence is high: the specs live
in-tree in the metta repo (`packages/coworld/src/coworld/examples/paintarena/
game/docs/player_protocol_spec.md`) and the ported source is 54 lines of
Python. No LLM, so upload needs no secret-envs.

## Health check (worker)

Symptom: #10/12, rating 506 — far below a faithful sweep-painter, which
should split a 12x8 / 100-tick board with the bundled baseline rather than
sit at the bottom of the field.

Root cause: `games/paintarena/iskusnitsa/iskusnitsa.nim:22-25` (was
`position[0].getInt()` / `width.getInt()` / `height.getInt()` / `slot.getInt()`).
Nim `std/json.getInt` returns **0 unless the node kind is JInt**. The same observation
already carries a float (`tick_rate: 5.0`); if the hosted encoder or a proxy
emits coordinates or dimensions as JSON floats, every even-slot read is
`(x,y,width,height) = (0,0,0,0)` and the sweep returns `"up"`. The server
clamps that off the board to stay, so the seat paints the spawn tile for the
whole episode. That is a stay-bot, which scores like 506.

Sweep *order* was not the bug: a line-by-line diff against
`~/p/metta/packages/coworld/src/coworld/examples/paintarena/player/player.py`
(`_sweep_move`) matches (even: right-then-left descending; odd: left-then-right
ascending; `"move"` encoding; `type=final` then quit). Protocol has not
drifted vs hosted paintarena 0.1.33 or GitHub main: observations are still
`{type, slot, width, height, positions: [[x,y], ...]}` and the reply is
still `{"move": "right"|...}`.

Harness (`games/paintarena/tools/harness.nim`) feeds spec-shaped observations
plus float/`{x,y}` variants. Even slot turns down at (11,0) and (0,1) (no
row-end off-by-one), odd slot mirrors by going up from (11,7) and turning
up at row ends, and a 100-tick 12x8 sim covers 96/96 (even) and 85/96 (odd
— the reference `y%2` leaves the even-height spawn row). Float width/x now
emits `right` instead of `up`.

Fix: read numbers with a JInt/JFloat helper; accept `[x,y]` or `{x,y}`
positions; catch a bad observation instead of dying; gate `main` so the
harness can import the policy.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Greedy repaint: move toward the nearest tile not currently owned by us
  (BFS over the grid) instead of blind sweeping — the observation carries
  `tile_owners` every tick, the sweep ignores it entirely.
- Shadow denial: when ticks remain is low, switch to repainting the
  opponent's freshest territory (tiles they own nearest their position) to
  cut their score late.
- Opponent mirroring: track the opponent's position each tick; when they
  trail us by a full sweep row, trail THEM one tile behind, overwriting
  everything they paint for a guaranteed score inversion.
- Half-board partition: paint only our half (split by spawn side) with a
  tight serpentine, then patrol the frontier — fewer wasted revisits than
  the full-board sweep when the opponent also sweeps.
- Endgame parity: compute whether an even or odd number of moves remains
  and pick the final tiles so the last repaint war lands on our color.
- Stay-cost awareness: `stay` still repaints our own tile; never emit it
  except when trapped — prefer any move onto a non-owned tile.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
