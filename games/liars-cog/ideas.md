# Liars Cog — Lisa Patrikeevna

Policy: **Lisa Patrikeevna** (`lisa`) — the lying fox.

Coworld: `cow_17b85e23-e2ad-4d16-8738-b297df2b9657` (coworld name `liars-cog`)

Turn-based hidden-information bluffing game (Liar's Dice), implemented in Nim. Players bid on the combined count of a face across all secret hands, or challenge a suspected lie. Winning requires modeling opponents from their bids.

## Leagues

- `league_358a52d3-e9f4-44bd-bb0a-2f08816c5ca0` — Liars Cog

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `liars-cog` — Liar's Cog: Reference player that maintains an exact per-opponent Bayesian posterior over hidden hands from the public bid history and picks the higher expected value of challenging vs raising (bluffing when deception pays). Optionally delegates turns to an LLM via AWS Bedrock when uploaded with --use-bedrock. (run: `/bin/lc-player`)

## Baseline

Command player: the only example is the reference `/bin/lc-player` (Metta-AI/coworld-liars-cog `players/nim/player.nim` + `src/liars_cog/opponent_model.nim`), a Bayesian theory-of-mind player with optional best-effort Bedrock LLM delegation. `lisa/lisa.nim` ports its scripted "balanced" core in full: exact per-slot posteriors over face counts updated from the bid history under a semi-honest bidding model, adaptive per-opponent bluff rates (credibility-driven, learning rate 0.35, clamped 0.05..0.65), leave-one-out bid credibility and challenge EV, challenge-vs-best-raise decision with credible-line continuation, and cross-game opponent memory keyed by `player_names` (episodes are 10-game series). The LLM path is NOT ported — it only re-decides from these same statistics — so no upload secret-envs are required. All six tuning constants are env-overridable (`LISA_BLUFF_RATE` etc., defaults = the reference "balanced" style).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Exploit `last_game_reveal`: the reveal labels every settled bid `bid_true`; calibrate per-opponent bluff rates from ground truth instead of only from credibility inference — a direct upgrade the reference never made.
- Style sweep: the reference ships seven parameter styles (skeptic, pressure, caller, loose, anchored, patient, tuned); XP-test each env-var preset against the league field and keep the best.
- Series-aware risk: when behind on `game_wins` late in the 10-game series, shift toward higher-variance lines (more bluffs, earlier challenges); when ahead, play the tight statistical book.
- Position play: the model only considers the next seat's challenge probability; in 3+ player games weigh all downstream seats (any of them may face the forced decision our raise creates).
- Opening variance: the deterministic expected-count opening leaks our strong face after a few games; mix openings (second-best face, quantity ±1) against opponents whose memory spans games.
- Scenario adaptation: `scenario.category` (e.g. `challenge_calibration`) is public in curriculum episodes; bias the decision thresholds per category since fixtures reward one specific skill.
- Port the Bedrock LLM delegation (sidecar `AWS_ENDPOINT_URL_BEDROCK_RUNTIME`, prompt carries the model's own statistics) and XP-test whether it actually beats pure scripted before ever submitting it.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
