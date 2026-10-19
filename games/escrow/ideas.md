# Escrow — Vasily Buslaev

Policy: **Vasily Buslaev** (`buslaev`) — Novgorod merchant-brawler — hard bargains.

Coworld: `cow_9b73db59-4be9-4a59-9e56-5eed9151a871` (coworld name `escrow`)

Escrow: binding contracts as a coworld, for four LLM-piloted cogs. A trading floor with three goods (ORE, GRAIN, TIMBER), one currency (HEARTS), and private comparative advantage: each seat is dealt one of four profiles - Mason, Farmer, Forester, Factor (the deal is drawn from the seed) - that produces a lopsided bundle every turn and pays 10 or 12 hearts for a commission made of the goods it does NOT produce. Filling commissions is the only source of new hearts; everything else is a transfer. The whole action space is a tiny contract DSL the game itself executes: OFFER <cog> / LOCK <bundle> / ASK <bundle> / DUE <turn> / IF <ALWAYS | [NOT] HOLDS <cog> <n> <good> | [NOT] PAID <cog> <n> <good>> / THEN <payout> / ELSE <payout>, with payouts SWAP, KEEP, PROPOSER or ACCEPTOR. BREACH IS IMPOSSIBLE because contracts are pre-funded: posting an offer moves the proposer's LOCK bundle into escrow, signing moves the acceptor's ASK bundle in, and settlement only redistributes what is already locked - non-performance is the ELSE branch firing, not a refusal to pay. Escrowed stock is visible but unusable: it cannot be given away, cannot fill a commission, and does not count toward a HOLDS condition, which is the engine of the loophole game. The floor is open outcry - every profile, stock and live contract is public - so the skill is drafting, pricing, and reading the other side's ELSE branch. Most hearts at the horizon wins; leftover goods are worth nothing. The game is LLM-driven: every turn the server sends each seat's policy prompt plus the floor, the escrow board, the ledger and its private notes to Claude (one parallel batch per turn), so A POLICY IS JUST A PROMPT - build one by reusing the published player runnable and setting the PLAYER_PROMPT environment variable to your strategy. Two scripted baselines (trader and hoarder) play any seat that registers as scripted - and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_cc074076-5938-403e-81db-d278c031db6d` — Escrow

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `escrow-player` — Escrow Prompt Player: The reference Escrow policy: delivers its PLAYER_PROMPT (or a default trading-floor strategy in words) to the game and spectates until the final frame. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/escrow-player`)
- `escrow-trader` — Escrow Trader Baseline: The scripted trading baseline as a fieldable policy: registers its seat as rule-based (value everything at a flat house price, sign the best-valued affordable offers addressed to it, and post one one-for-one swap of its largest surplus for its largest deficit) so the game server plays it deterministically, no LLM involved. It is also the universal fallback whenever a model reply cannot be parsed or validated. (run: `/bin/escrow-player`)
- `escrow-hoarder` — Escrow Hoarder Baseline: The autarky foil: produces, fills commissions, and does nothing else - no offers, no signings, no gives, no talk. It is the floor any trading policy has to beat, and it makes "what is a contract worth?" measurable. (run: `/bin/escrow-player`)

## Baseline

Default example is `escrow-player` (prompt seat, `/bin/escrow-player`);
the strongest scripted baseline is `escrow-trader` (flat house price,
signs best-valued affordable offers, posts one one-for-one swap) — it is
also the per-turn fallback for invalid replies; `hoarder` is the autarky
floor. Our policy `buslaev` is the thin Nim prompt seat:
`{"type":"prompt","prompt","scripted"}` on connect and after welcome, then
listen until `final`. The prompt targets two commission fills per turn,
prices in the 2.0-2.5 hearts/unit band, drafts simple ALWAYS/SWAP/KEEP
sales plus PAID-conditioned performance bonds, refuses ELSE-pays-PROPOSER
bets outside its control, knows the HOLDS-reads-free-stock loophole both
ways, and dumps goods for anything above zero in the last two turns.
Upload needs `--secret-env USE_BEDROCK=true`; `PLAYER_PROMPT` /
`PLAYER_SCRIPTED` override.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Exploit the trader fillers mechanically: they value at a flat house
  price, so include one deliberately mispriced-by-their-lights offer per
  turn (sell surplus slightly above band) and measure sign rate.
- Insurance-clause offense: post NOT HOLDS bets against seats visibly
  short of commission inputs (their ELSE forfeits to us) and log whether
  LLM rivals sign them.
- Give-first reputation play: open turn 1 with a small unconditional give
  to the seat that needs our bulk good, then trade with them at the top
  of the band; A/B hearts vs the cold-open prompt.
- Escrow-lock defence drill: add an explicit rule to lock surplus stock
  in a self-serving offer whenever a rival's signed contract carries a
  HOLDS-us clause whose ELSE pays them.
- Endgame tuning: try starting the convert-everything scramble three
  turns out instead of two (offers take a turn to be signable, so the
  real liquidation window is earlier than it looks).
- Factor-profile special-case: when dealt Factor (needs all three goods,
  12-heart commission), prompt a hub strategy — post two-sided swaps and
  act as the floor's market maker.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
