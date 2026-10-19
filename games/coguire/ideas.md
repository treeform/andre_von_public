# Coguire — Korobochka

Policy: **Korobochka** (`korobochka`) — Gogol's acquisitive landowner.

Coworld: `cow_806a5a3b-bcdd-4b09-a174-dfb3edd32f93` (coworld name `coguire`)

A four-player economic-strategy benchmark (Acquire): agents found and grow hotel corporations on a shared grid, time mergers to harvest shareholder bonuses, manage cash across stock buys, and finish with the most money.

## Leagues

- `league_e2b4266a-12fe-4e1e-9183-18230e6cae19` — Coguire

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `coguire-scripted` — coguire Scripted Baseline: Deterministic no-LLM baseline (plays a legal tile, founds the first free chain, buys nothing). Certifies the contract offline. (run: `node dist-server/coworld/baseline-player.js`)
- `coguire-value` — coguire Value Investor: Exact-EV heuristic (no LLM): parity-aware stock buys, bonus-led merger timing, and final-accounting-aware end declaration computed from the public holdings. The reference bar to beat. (run: `node dist-server/coworld/value-player.js`)
- `coguire-llm` — coguire LLM Baseline: A Bedrock-driven policy that plays the seat through the game's autopilot (system prompt + per-turn tool). (run: `node dist-server/coworld/llm-player.js`)

## Baseline

- Default example: `coguire-scripted` (always-legal, buys nothing). Strongest: `coguire-value`
  ("Value Investor", `src/coworld/value-policy.ts` in the local metta checkout at
  `~/p/metta/packages/cogweb/games/coguire`) — the stated "reference bar to beat".
- **Korobochka is a full Nim port of the Value Investor**: exact-EV heuristic over the public
  economy — bonus-payout arithmetic (sole/split majority/minority, $100 round-up), parity-aware
  buy combos (all multisets of ≤3 affordable shares), tier-led founding, merger timing via
  my-delta − 0.75×rival-delta edges, 2-for-1 trade vs sell EV in disposals, and declare-end only
  when the projected final accounting has us first. Weights verbatim from the source
  (RIVAL 0.75, BONUS 0.85, GROWTH 3 tiles × 0.5, CASH 0.03).
- On a host rejection (`reason` set) it answers with the scripted-baseline always-legal move so a
  validator disagreement can never loop.
- Lookahead (experiment 1) sits on top of that greedy, not inside it: a merger place
  simulates the post-merger board (paid majority/minority bonuses, same-policy 2-for-1
  disposal, our best buy, next seat's best buy) and scores trigger-vs-delay by the same
  net-vs-best-rival edge; declare-end keeps "we finish first after this buy" and enumerates
  1-ply rival buys on the projected accounting so a flip is a lock-in rather than a pass.
  Found / survivor / buyScore / disposal weights stay verbatim from value-policy.ts.
- Protocol: cogweb.player.v1 (welcome/observation/reply/final), verified against both the
  manifest protocol text and the actual TS player runtime. High confidence.
- Upload: no secret-envs (pure scripted seat, no LLM).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Lookahead on merger timing: placeScore's merge case values bonuses now; add a one-turn
  discount for mergers a rival can trigger first (their visible adjacency) so we stop handing
  the mergemaker choice away.
- Tile-denial placement: penalize grows that push a rival-dominated chain past the next price
  bracket (we currently only weigh our own vs best-rival appreciation).
- Safe-chain parking: prefer buys in chains 1-2 tiles from SAFE (11) — safe chains can never
  die, so their shares never zero out; add a safety term to buyScore's growth model.
- Endgame cash discipline: raise CASH_WEIGHT once any chain is ≥ 8 tiles (merger bonus season)
  so we hold parity-buy powder; A/B the 0.03 → 0.10 switch.
- Founder-setup chaining: the lone-tile +150 nudge ignores WHICH chain we could found; scale it
  by the top inactive tier's founder-share value.
- Second-place parity buys: buyScore treats all bonus deltas equally; add a term for cheaply
  securing exact-tie majority splits (holders.n equal) which halve the leader's payout.
- Model opponent declare-end: we keep playing while behind, but a leading rival will declare on
  their turn; when endConditionMet and we are NOT first, spend everything on the chain that
  flips the final accounting instead of the generic EV buy.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v2 | see git history | triage batch | paired vs champion | REVERT: 36258->33142 t=-0.89 5/12 |
| 1 | merger-timing + declare-end lookahead | 2-ply post-merger sim (bonuses, same-policy disposal, our buy, next-seat best buy) minus delay line, scored by net-vs-best-rival edge; declare-end 1-ply rival-buy lock-in on final accounting | | | |
