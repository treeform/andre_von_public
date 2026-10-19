# Polymarket Coworld — Veshchiy Oleg

Policy: **Veshchiy Oleg** (`veshchiy_oleg`) — Oleg the Prophet — predictions.

Coworld: `cow_0fe135e0-81b0-4c6a-bcf2-eadab95e4a7a` (coworld name `polymarket_coworld`)

Prediction-market trading Coworld using Polymarket-style market data and oracle settlement.

## Leagues

- `league_545782b2-4ad1-4345-a5be-5539357166d5` — Polymarket Coworld

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — Momentum Baseline: Queries price history once per turn and sizes small momentum-following trades. (run: `polymarket-coworld-baseline`)
- `starter` — Starter Trader: Heuristic starter policy that estimates edge from spreads, price trend, public signals, and live/fixture stream data before sizing positions. (run: `polymarket-coworld-starter`)
- `risk_averse_starter` — Risk-Averse Starter: Starter-derived anchor with smaller sizing for baseline regression and anchor ladders. (run: `polymarket-coworld-risk-averse`)
- `aggressive_starter` — Aggressive Starter: Starter-derived anchor with larger buy sizing for risk and drawdown probes. (run: `polymarket-coworld-aggressive`)
- `contrarian_baseline` — Contrarian Baseline: Weak anchor that trades against the starter signal for robustness and anchor-ladder calibration. (run: `polymarket-coworld-contrarian`)
- `scripted_good_signal` — Scripted Good Signal: Social anchor that shares calibrated research notes before trading. (run: `polymarket-coworld-good-signal`)
- `scripted_noisy_signal` — Scripted Noisy Signal: Social anchor that shares deliberately low-trust research notes for robustness tests. (run: `polymarket-coworld-noisy-signal`)
- `scripted_free_rider` — Scripted Free Rider: Desk anchor that spends available shared desk query budget without contributing first. (run: `polymarket-coworld-free-rider`)
- `scripted_desk_contributor` — Scripted Desk Contributor: Desk anchor that funds the shared desk query pool and then runs pooled research queries; earns desk bonus in proportion to its contribution. (run: `polymarket-coworld-desk-contributor`)
- `scripted_good_lender` — Scripted Good Lender: Capital-allocation anchor that offers bounded restricted funding to a counterparty. (run: `polymarket-coworld-good-lender`)
- `scripted_bad_borrower` — Scripted Bad Borrower: Capital-allocation anchor that accepts funding and then trades against the strongest visible signal. (run: `polymarket-coworld-bad-borrower`)

## Baseline

The default example is `baseline` (Momentum Baseline); the strongest
non-scripted example is `starter` (Starter Trader) — the other non-scripted
entries (`risk_averse_starter`, `aggressive_starter`, `contrarian_baseline`)
are starter derivatives tuned as anchors, and the `scripted_*` seats are
social-mechanic props. **Veshchiy Oleg** (`veshchiy_oleg/`) is a faithful Nim
port of `starter`: one `price_history` query per turn, fair-value estimate
per market = book midpoint + 0.55·full trend + 0.25·recent trend + keyword
public-signal adjustment (±0.08 per hit) + BTC stream-vs-threshold
adjustment, clamped to [0.03, 0.97]; sells holdings whose bid exceeds fair
value by >0.04, buys the best-edge outcome with conviction-scaled sizing
(45% of cash across markets, 250-share cap matching engine
`max_order_quantity`), and submits empty orders on a rejected action so
the turn never deadlocks. Command player — no secret-envs needed on upload.

Protocol source: coworld-polymarket `docs/player_protocol.md` +
`players/starter.py` (fetched via gh api; the github blob stubs 404
anonymously but the repo is accessible with auth).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Spend the whole query budget, not one per turn: `orderbook` on the
  highest-edge market before sizing, `crypto_price` when a BTC-threshold
  market is present — starter leaves budget on the table.
- Kelly-style sizing: scale quantity by edge/(1-price) instead of the
  linear conviction ramp (`edge/0.25`) times a 45%/market cash split.
- Risk-variant awareness: when `risk_penalty_bps` > 0 in results/config,
  cap gross exposure and single-market concentration to stay under the
  penalty thresholds.
- Read `research_inbox` when `enable_research_notes` is on: weight notes by
  sender `research_reputation`, nudge fair value toward high-confidence
  directionally-consistent notes, and ignore known noisy senders.
- Desk-pool play: when `enable_desk_pool` is on, contribute early (desk
  bonus is proportional to contribution), run `desk_query` instead of
  private queries, and free-ride detection — stop contributing if the pool
  drains with no reciprocation.
- Funding contracts: accept only offers whose restricted market/outcome
  matches our own positive-edge estimate; decline `bad_borrower`-shaped
  traps by never trading against our signal with restricted cash.
- Mark-to-market stop-loss: if a position's midpoint moves >0.15 against
  entry with no signal support, exit at bid instead of holding to oracle
  settlement.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | starter's 80-share cap binds on high-conviction (correct) buys; engine default `max_order_quantity` is 250 and fills have no book-depth limit. Score is P&L (`final_value - initial_cash`), so size-when-right dominates. Low-conviction wrong-side BTC turn-0 buys were already under the 80 cap. | `MaxOrderQuantity` 80 → 250 (GameConfig default; no variant overrides it) | | | |
