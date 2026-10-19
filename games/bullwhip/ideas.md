# Bullwhip — Sadko

Policy: **Sadko** (`sadko`) — the merchant of Novgorod — supply chains.

Coworld: `cow_fc058d5c-62a6-436f-a0b3-df8bcb041346` (coworld name `bullwhip`)

Bullwhip: the MIT Beer Game for four LLM-piloted cogs. A four-stage supply chain - Retailer, Wholesaler, Distributor, Factory - where each seat is one stage (the seat-to-role assignment is drawn from the seed). Every week a stage receives an order from downstream, ships what it can from inventory (the rest becomes BACKLOG, owed until shipped), and places ONE order upstream. Orders take a week to be seen, shipments take two weeks to arrive, and the factory's orders are production requests with a two-week lead. Every stage pays $0.5 per unit held and $1.0 per unit of backlog every week; a seat's SCORE is minus its total cost. Customer demand is hidden from every seat and shifts once during the episode (spectators watch it week by week). A stage sees only its own numbers and, in the talk variant (default on), one short message a week from each neighbour - honest or not. Greedy ordering into a backlog creates the bullwhip: a demand step amplified stage by stage into an oscillation that comes back as everyone's excess inventory. The game is LLM-driven: every week the server sends each seat's policy prompt plus its role, full history table, this week's numbers, neighbours' messages and private notes to Claude (one parallel batch per week), so A POLICY IS JUST A PROMPT - build one by reusing the published player runnable and setting the PLAYER_PROMPT environment variable to your strategy. Two scripted baselines (base-stock and mirror) play any seat that registers as scripted - and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_d254cad2-3523-4441-80a2-1335af7c26ee` — Bullwhip

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `bullwhip-player` — Bullwhip Prompt Player: The reference Bullwhip policy: delivers its PLAYER_PROMPT (or a default base-stock strategy in words) to the game and spectates until the final frame. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/bullwhip-player`)
- `bullwhip-basestock` — Bullwhip Base-Stock Baseline: The scripted base-stock baseline as a fieldable policy: registers its seat as rule-based (a slow demand forecast, full supply-line accounting, gentle inventory correction) so the game server plays it deterministically, no LLM involved. (run: `/bin/bullwhip-player`)
- `bullwhip-mirror` — Bullwhip Mirror Baseline: The scripted pass-through baseline: orders exactly what it received each week. Never amplifies on its own, never rebuilds a backlog either. (run: `/bin/bullwhip-player`)

## Baseline

- Default example: `bullwhip-player` — delivers `PLAYER_PROMPT` (or a stock
  base-stock strategy in words) and spectates.
- Strongest example: `bullwhip-basestock` (`PLAYER_SCRIPTED=basestock`) —
  slow demand forecast, full supply-line accounting, gentle inventory
  correction; the partner to beat. (`mirror` never rebuilds and bleeds
  backlog cost after the demand step.)
- Ours: **Sadko** — a prompt seat running base-stock with explicit numbers:
  exponential forecast (0.75/0.25) with a step-detector (two weeks at a higher
  level jumps the forecast), inventory position counting the whole supply
  line including supplier backlog, target = 4 weeks of cover, half-gap
  correction, 3x forecast order cap, honest forecast messaging.
  `PLAYER_PROMPT` / `PLAYER_SCRIPTED` overrides supported.
- Upload secret-envs: `USE_BEDROCK=true` (else the seat silently plays
  scripted).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Tune target cover: 3 vs 4 vs 5 weeks of forecast (backlog costs 2x holding, so the optimum may sit above 4).
- Role-aware lead time: factory sees no order delay upstream - test a 3-week target for the factory seat only.
- Correction gain sweep: 0.5 half-gap vs 0.33 vs full-gap ordering; measure chain oscillation in results costs.
- Trust-downstream clause: weight a neighbour's announced forecast into ours after one confirming week instead of two.
- Order smoothing cap: limit week-over-week order change to +/- 50% of forecast; compare cost vs the plain cap.
- Silence variant: send no messages at all (some talk misleads); measure whether our own cost improves.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
