# Fruit Market — Zhar-Ptitsa

Policy: **Zhar-Ptitsa** (`zhar_ptitsa`) — the Firebird, stealer of golden apples.

Coworld: `cow_4a33390e-40e5-4bfc-826a-d2987347d8a8` (coworld name `fruit-market`)

Apple farmers who crave bananas, banana farmers who crave apples, and offers that only clear when they mirror. Eight cogs, two concentric rivers, no words.

## Leagues

- `league_758061e3-46cb-49db-aef0-a28fb10ba80e` — Fruit Market

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `fruit-market-player` — Fruit Market Prompt Player: The reference Fruit Market policy: delivers its PLAYER_PROMPT to the game and spectates until the final frame. Every decision is made in the game container, which asks the model for all eight seats' standing orders as one parallel batch per round. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/fruit-market-player`)
- `fruit-market-hauler` — Fruit Market Hauler Baseline: The scripted market maker: bank three of your own fruit, walk to the round's rendezvous stall and post the book price -- three of your own fruit for two of theirs, which is the exact mirror of what the other guild posts. Deterministic, no LLM. (run: `/bin/fruit-market-player`)
- `fruit-market-homesteader` — Fruit Market Homesteader Baseline: The scripted autarky foil: never posts an offer, harvests its own grove and treks across both rivers to pick the fruit it craves itself. The reason the rivers exist. Deterministic, no LLM. (run: `/bin/fruit-market-player`)

## Baseline

Default example is `fruit-market-player` (prompt seat); a seat that sets
neither prompt nor scripted plays `hauler` — the scripted market maker
(bank three own fruit, rendezvous stall, post the book price), which is
the stronger baseline; `homesteader` is the autarky foil. Our policy
**Zhar-Ptitsa** (`zhar_ptitsa/zhar_ptitsa.nim`) defaults to the published
`hauler` scripted baseline (`PLAYER_SCRIPTED=hauler`): apple farmers post
give 3 apple / want 2 banana, banana farmers post the exact mirror, both
walk to the round's rendezvous stall (two rounds per stall, N→E→S→W).
v1 was an LLM prompt that defaulted to 2-for-2, which never mirrors the
hauler book. `PLAYER_PROMPT` / `PLAYER_SCRIPTED` overrides; empty
`PLAYER_SCRIPTED` restores the v1 prompt. Upload secret-envs: none for
the default (scripted hauler). LLM override still needs
`--secret-env USE_BEDROCK=true` or the seat silently plays hauler.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Exploit the hauler book: verify the exact give/want numbers the hauler
  posts (replay a league episode) and hard-code its exact mirror as the
  default offer instead of 2-for-2.
- Price laddering: when no trade clears in a round, sweeten by one unit
  (give+1) next round; when a trade clears, try give-1 the round after —
  a one-line bargaining loop in the prompt.
- Stall selection from the tape: instruct the seat to compute the modal
  stall of the last eight executed trades and stand there, rather than
  the nearest stall.
- Rescue trades: when a visible cog stops moving (exhausted), walk to it
  and post the mirror of its standing offer — a guaranteed clear at any
  price is worth 5 points.
- Two-offer rhythm: alternate rounds of give-heavy offers (build craved
  stock) and small 1-for-1 offers (keep the 1-trade-per-round slot always
  clearing).
- Famine endgame: in the last two rounds stop banking and eat everything
  craved immediately (no cooldown waste), switching job to harvest only
  if inventory is empty.
- Trek fallback tuning: quantify when homesteading actually pays (dead
  market: zero tape entries for N rounds) and set N from replays.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Field the published scripted `hauler` instead of the LLM prompt. Leaders are `co-gas-fruit-market-hauler-richard` / `relhalpha` (wr 0.75/0.76). Score is 5×craved eaten + 1×own; matching requires an EXACT mirror. The sim's book is apple give-3/want-2 ↔ banana give-2/want-3 at the round rendezvous stall (two rounds per stall). v1 prompt defaulted to 2-for-2, which is not that mirror and never clears against haulers; nearest-stall vs rendezvous is 10 vs 34 fills in the sim. Failed LLM replies already fall back to hauler. | default PLAYER_SCRIPTED to `hauler` in zhar_ptitsa.nim (env still overrides; PLAYER_SCRIPTED="" forces the prompt) | | | |