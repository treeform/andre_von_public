# Cogherence — Alkonost

Policy: **Alkonost** (`alkonost`) — bird of harmony.

Coworld: `cow_aab74711-ae80-4f46-9a0d-cd6c30bbb72e` (coworld name `cogherence`)

A luminous hex-lattice, mixed-motive game for 3–6 LLM Cogs. Align tiles to mine C/O/Ge/S, convert balanced COGS sets to energy, talk to rivals asynchronously (public + private cheap talk, nothing binding), and win the single heart auctioned each turn by sealed second-price bid. Most hearts at the final turn wins.

## Leagues

- `league_c11f80e8-877e-471b-abd2-d91041ec24bf` — Cogherence

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `cogherence-baseline` — Cogherence Baseline: Deterministic no-LLM baseline: every turn it holds (no orders, no bid). Always-legal, so it certifies the contract offline. (run: `node dist-server/game/baseline-player.js`)

## Baseline

- Default (and only) example: `cogherence-baseline`
  (`node dist-server/game/baseline-player.js`) — always holds (empty order
  set, no bid). Always-legal; exists to certify the contract.
- Our policy: **Alkonost** (`alkonost/`) keeps the baseline's always-legal
  reply skeleton but plays the scripted line the engine source
  (Metta-AI/coworld-cogherence) makes obvious:
  - Only cogs HOLDING GROUND may bid (resolve.ts `holdsGround`), the
    auctioned heart is the only score, so the home tile is a bidding
    license: never abandon the last tile; self-align (force^2 energy,
    distance 0) when its coherence is drained below 7.
  - The coworld seam has NO convert order and deliberately skips the live
    server's auto-conversion (game.ts PARITY NOTE), so the 100 starting
    energy is nearly the whole budget — minerals are tiebreak wealth only.
  - Abandon any surplus tiles (coherence refunds as energy, upkeep stops).
  - Bid every turn: 2e normally (unexploitable under the seam's closed
    100e budget: a 1-tile keeper pays 1e forced upkeep whenever it has
    energy, so winning at price p costs p+1/heart), all-in when
    turnsLeft <= 12 and not ahead, nothing once lead > turnsLeft.
    Second-price means we pay the runner-up's price (1e reserve vs a
    passive field).
  - On a `reason` re-request (whole order set rejected) reply the hold.
- Protocol: `cogweb.player.v1` — observation carries `id`/`seat`/`turn`/
  `view` (redacted GameSnapshot: rivals' treasury+energy zeroed, hearts
  public) + `messages` inbox; reply echoes `id` with
  `decision:{orders:[align|exploit|abandon|transfer|bid]}` and cheap-talk
  `messages`. From packages/coworld/src/protocol.ts.
- Upload: scripted command player, NO secret-envs.
- Confidence caveat: MAX_TURNS=100 and the seam's no-conversion economics
  were read from repo main (engine constants.ts / game.ts), not observed
  live; if the hosted game auto-converts COGS sets, the tight-energy
  assumption weakens (bids could then be funded by mining — see backlog).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Verify the no-conversion assumption from a hosted replay (feed events
  would show energy rising without abandons); if conversion exists, switch
  to a mining build: expand a connected blob around the corner home
  (allied neighbors heal +1/turn) and fund bids from full COGS sets.
- Bid shading vs rival bidders: track public heart winners (and our own
  energy drop when we win, which reveals the clearing price) and bump
  the 2e default toward clearing+1 while the budget race allows.
- Late-game wealth tiebreak: hearts tie broken by energy + convertible
  sets — hold 1-2 energy back and stop bidding when tied and rich.
- Cheap talk: broadcast a truthful "I only defend my corner" line turn 1 —
  against LLM seats this may deflect aligns toward other rivals; costs
  nothing (the engine never reads messages).
- Deny-exploit: if a rival align lands on our keeper and the tug is lost
  anyway (their force > coherence + our affordable defense), exploit the
  keeper first — the windfall beats handing them a healthy tile — then
  re-align a fresh corner tile the same turn to keep the bidding license.
- Opportunistic second tile late: with a big energy lead and < 20 turns
  left, align a rich adjacent tile — the mint tiebreak wealth and the
  extra abandon refund outweigh the sqrt-scaled upkeep for a short tail.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Unexploitable Vickrey bid of 2e | Default bid `energy/6` → `2`. Seam has no conversion and no first-commit bonus, so 100e is the whole budget; 1-tile upkeep is a forced 1e whenever we have energy. Winning at price p costs p+1 per heart: bid 2 beats 0–1 bidders 50–25, ties any bid≥2 at 33–33, and still only pays the 1e reserve against a silent field. `energy/6` wins early auctions we should lose and bankrupts us against a 3–15 bidder (the likely leader). Late all-in / uncatchable-skip unchanged. | | | |
