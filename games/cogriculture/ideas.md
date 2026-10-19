# Cogriculture — Polevik

Policy: **Polevik** (`polevik`) — field spirit.

Coworld: `cow_d51d10f4-badc-4a6b-91fe-9d7b923d703c` (coworld name `cogriculture`)

Two-player farming and market simulation over a 30-day season. Runs the upstream Kaggle Kaggriculture simulator unmodified, so bots are portable between this Coworld and the Kaggle competition without changes.

## Leagues

- `league_e2689e15-3d2b-4fab-8ac4-f78cf7d9cb00` — Cogriculture

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — Melonrush Farmer: All-in melon opening into a day-11 bulk dump, then a six-cow ranch (fed and cared daily on bought wheat), a strawberry-heavy second wave on three of the four quadrants, fertilizer sales, and a day-29 liquidation. Scores roughly 20x the starter bot over a full season. (run: `python -m cogriculture.player --bot bots/melonrush.py`)
- `starter` — Starter Farmer: Upstream's starter_agent: a single-tile carrot loop. Deliberately weak, and stable enough to use as a fixed reference point. (run: `python -m cogriculture.player --bot bots/starter.py`)

## Baseline

- Default AND strongest example: `baseline` = **Melonrush Farmer**
  (`python -m cogriculture.player --bot bots/melonrush.py`, ~20x the
  `starter` carrot loop). Source fetched from the manifest's pinned commit
  (Metta-AI/cogame-cogriculture @ da7a123, bots/melonrush.py).
- **Polevik** is a Nim port of melonrush: all-in melon opening
  (60% of the start quadrant) harvested at age 10 so the dump sells day 11;
  eight-cow + six-sheep ranch from day 12 (fed + cared daily on bought wheat,
  care bonus banked onto production days; extra animals print fertilizer);
  land purchases capped at three quadrants; strawberry-heavy replant with a
  dedicated fertilizer courier (FERTILIZE doubles watered ongoing
  productions); day-29 liquidation with an hour-14 ferry-and-DROP sweep.
  Python-semantics details preserved: stable job sorts (insertion index
  tiebreak), first-min-by-distance target picks, half-to-even `round()`,
  JSON insertion-order seed/mix iteration.
- Protocol confidence: high — docs/protocol_player.md fully specifies
  handshake/observation/action/final, and the observation is the raw
  upstream Kaggle dict the Python bot reads; the reply is
  `{"action": {farmer, hands, market}}`.
- Upload secret-envs: **none** (fully scripted; answers well inside the
  1 s actTimeout).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Dump-race counterplay: melonrush's whole edge is selling the melon dump
  on day 11. Against a mirror opponent (both fields are public), detect an
  opposing melon field mid-opening and either harvest one day earlier at a
  small yield cost or rotate the opening toward strawberry/tomato to avoid
  selling into the shared crater.
- Price-aware selling: replace the fixed per-product daily sell caps with
  the published price curves (RULES.md gives base/T/shape per resource) —
  sell premium goods (milk, wool, strawberry) down to a computed marginal
  price instead of a flat 35%-of-base floor.
- Opponent-glut avoidance: market inventory is shared and public; when the
  opponent dumps a product, pause our sales of that product for the day
  (price recovers as the town consumes) instead of selling into the dip.
- Fourth-quadrant re-check: the $4k SE quadrant is skipped because labour
  caps at ~55 worked tiles; if hands are raised above 10 late-season the
  quadrant flips positive — sweep TARGET_HANDS 10→12 with MAX_QUADRANTS 4.
- Goose wing: cows are the measured optimum at 6, but a 2-goose coop near
  the shed adds ~2 eggs/day for one extra rancher trip; try 6 cows +
  2 geese with n_ranchers forced to 2.
- Fertilize the melon second wave: the shipped bot only fertilizes ongoing
  crops; a fertilized one-time crop banks +2/day in its water-bonus
  window — check whether second-wave melons (planted ~day 12-14) can reach
  cap earlier and free field turns.
- Hire-cost exploit on liquidation day: hands cost fib() but drop their
  inventory at day end only if there IS a day end — verify the 4-hand
  liquidation count is optimal vs 6 with the hour-14 sweep.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | expand ranch to published top-player 8-cow+6-sheep herd | `ranchBuildOrder` 6×COW → 8×COW+6×SHEEP (gytdrop heuristic mined from 72 kaggle replays scoring 100k–158k; extra animals print 1 fertilizer/day plus milk/wool). nRanchers already scales at herd≥11. | | | |
