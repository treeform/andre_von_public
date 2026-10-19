# Cogtan — Domovoy

Policy: **Domovoy** (`domovoy`) — house spirit — settlement builder.

Coworld: `cow_089d621a-6d14-4b79-bee3-7e15b3da306e` (coworld name `cogtan`)

A four-player CATAN (Settlers of Catan) benchmark: agents draft starting settlements, manage stochastic resource production, negotiate trades, time the robber, and race to 10 victory points.

## Leagues

- `league_26c4376a-ec17-4de8-88e9-4e8cf081721d` — Cogtan

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Architecture (v2, 2026-08-31): MCTS + steering, terra-style

Domovoy is now built like the terra Agricogla champion (vendored as
mikula, #1 in that league): a full game-model MCTS command player with
protect-gate steering. Layout mirrors mikula's `terra/`:

- `domovoy/catan/nodes.nim` — pure CATAN simulator, ported 1:1 from the
  deployed engine (~/p/metta packages/cogweb/games/cogtan src/engine.ts
  + rules.ts + game.ts). **Parity-proven**: `catan/parity.nim` replays
  TS-engine trajectory dumps (3 full games, 1169 steps, dev cards +
  trades + steals + longest-road transfers) with 0 mismatches. Chance
  (dice/steals/dev draws) flows through an Rng embedded in GameState;
  `applyRollWith`/`applyRobberWith` are the injection hooks the parity
  harness uses. Move generation is STEERED, not exhaustive: discards
  (greedy + protect-city/settlement variants), one curated road-building
  pair, year-of-plenty only to complete a cost, monopoly only at 3+
  cards, robber never on own hexes / never victimless when victims
  exist. We never offerTrade (respond only).
- `domovoy/catan/policy.nim` — the improved-baseline heuristic (city >
  settlement > road-toward-pips > dev; leader-VP-weighted robber; knight
  when the robber squats on us; protected discards). Used as rollout
  bias (85% self / 65% opponents), as the protect-gate plan, and as the
  instant answer when the clock is thin.
- `domovoy/catan/solver.nim` — root-parallel time-budgeted UCB MCTS.
  The hidden zones (opponents' dev cards + deck order) are DETERMINIZED
  per worker from the unseen pool; each of the default 8 workers greedy-
  searches its own sample and root stats merge by move key. Protect
  gates: the searched move must beat the plan by ≥0.8 avg-VP-margin or
  ≥6 win-rate points when the plan is a city/settlement build (≥0.35 /
  ≥3 otherwise) or the plan is kept.
- `domovoy/domovoy.nim` — wire client + Fischer-clock bookkeeping. The
  host gives 5s initial + 5s per own setup/preroll decision; off-turn
  decisions drain the bank. Budgets: setup ≤3.5s, main ≤2.5s, robber
  ≤2s, preroll (dev-card question only) ≤1.5s, discard ≤0.8s, trade
  ≤0.6s — always leaving a 1.2s reserve; under 250ms of headroom the
  heuristic answers instantly. Env knobs: DOMOVOY_SOLVER_ENABLED /
  _TIME_MS / _ITERATIONS / _THREADS, DOMOVOY_RESERVE_MS.

Verification (all local sim, no coworld):
- Parity: `nim r -d:release catan/parity.nim <dump.jsonl>` → 0/1169
  mismatches vs the TS engine (dump script: scratchpad dump_cogtan.ts
  over a patched-import copy of the engine; regenerate with tsx).
- Self-play: `nim c -r -d:release --threads:on catan/selfplay.nim
  boards.jsonl <games> <budgetMs>` — solver seat vs 3 heuristic seats on
  TS-dealt boards. At 300ms/decision: see experiment log.

The field: daveey's champion is `daveey-cogtan-mcts` at 9.94/10
meanScore — the #1 seat is already MCTS. Protocol caveat (unchanged):
re-requests (`reason` set) are answered statelessly with the most
conservative legal move.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Clock calibration: log the host's real re-request/timeout behavior in
  an XP run; if the bank estimate drifts, learn the actual credit timing
  and raise/lower budgets. Biggest practical risk to the MCTS build.
- Opponent model: rollouts assume improved-baseline opponents; daveey is
  MCTS. Try a defensive margin term (maximize own margin vs best rival —
  already the objective) plus robber focus on the VP leader.
- offerTrade generation: curated 1:1 surplus-for-need offers to the
  trailing seat as root moves (engine caps 3/turn). The sim already
  applies offers; movegen just never emits them.
- Largest Army race: value knights higher when playedKnights is within 1
  of the holder; currently knights only chase robber relief.
- Determinization count: 8 workers = 8 samples; try 12-16 threads if the
  league pod has the cores (DOMOVOY_SOLVER_THREADS).
- Discard candidates: add a keep-dev-cost variant (protect ore+grain+
  wool) to the 3 existing candidates.
- Setup spot cap: movegen caps setup to top-24 spots by pips; check the
  solver ever disagrees with top-8 (cheaper root).

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | MCTS+steering rewrite (this doc) | catan/ solver build | xreq_9a915536-c1eb-45ac-9f61-4ab65cb6d8c0 | daveey-cogtan-mcts:v6 + 🗡️Pizarro:v29 + domovoy:v1 (top-3) | KEEP. Sim self-play 29/32 (90.6% vs 25% par). Hosted XP 8 eps: 4/8 outright wins (par 2), avgVp 8.25, 0 failures/timeouts; 4-4 vs daveey head-to-head. Uploaded as domovoy:v2 (linux/amd64!), submitted 2026-09-01, champion active (v1 benched) |
