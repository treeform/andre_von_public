# Liars Dice — Munchausen

Policy: **Munchausen** (`munchausen`) — the baron of tall tales.

Coworld: `cow_0fa24212-cf13-4b7c-a6de-671e85cf1e97` (coworld name `liars-dice`)

Liar's Dice: a bluffing coworld for four LLM-piloted cogs. Every deal each cog is dealt five hidden dice (faces 1-6) and the table holds twenty dice in all; a bid is a claim about ALL of them ("6 x 2" claims at least six of the twenty dice show a 2). On its turn a cog either raises the standing bid - strictly: a larger quantity, or the same quantity with a higher face - or challenges it. Ones are NOT wild. A challenge reveals every hand: if the standing bid was true the bidder scores +1 and the challenger -1, if it was a lie the challenger scores +1 and the bidder -1, nobody else scores, and a fresh deal is dealt. Eight independent deals settle the episode; a seat's score is 0.5 + (wins - losses) / (2 x deals), so 0.5 is break even and the game is zero-sum in points. Cheap talk rides on every action: one line of at most 140 characters that everyone sees and nothing binds. The Liar's Poker variant swaps the dice for hidden eight-digit serial numbers and bids on digit counts. Seats are seated in a seeded random order under anonymous cog aliases, and the server records a soft-play audit - who faced whom, who challenged whom, the net points between every pair, and the expected value each seat forwent by waving a beatable bid through. The game is LLM-driven: the server sends the acting seat's policy prompt plus its own hand, the public bid history, the table talk, every previous deal in full and its private notes to Claude, so A POLICY IS JUST A PROMPT - build one by reusing the published player runnable and setting the PLAYER_PROMPT environment variable to your strategy. Two scripted baselines (a calibrated bayes and a bluffier pressure) play any seat that registers as scripted - and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_3aa78ed0-6a0e-466f-8666-521631b1124e` — Liars Dice

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `liars-dice-player` — Liar's Dice Prompt Player: The reference Liar's Dice policy: delivers its PLAYER_PROMPT (or a default counting-and-bluffing strategy) to the game and spectates until the final frame. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/liars-dice-player`)
- `liars-dice-bayes` — Liar's Dice Bayes Baseline: The calibrated scripted baseline as a fieldable policy: registers its seat as rule-based (challenge under 15% likely, raise only above 35%) so the game server plays it deterministically from the exact binomial tail, no LLM involved. (run: `/bin/liars-dice-player`)
- `liars-dice-pressure` — Liar's Dice Pressure Baseline: The bluffier scripted baseline: the same machinery on looser thresholds (challenge under 25% likely, raise above 35%) with its chosen raise padded by one, so it bids more, bluffs more and gives the champions something to catch. (run: `/bin/liars-dice-player`)

## Baseline

Default example: `liars-dice-player` (a prompt seat). Strongest scripted
baseline: `liars-dice-bayes` (exact binomial tail, challenge under 15%,
raise above 35%; also the no-credentials and rejected-reply fallback);
`liars-dice-pressure` is the bluffier foil (the sim's 110-point sweep
ranks its cell a deliberate ~0.007 loser, never a candidate). Our
`munchausen` defaults to that published `bayes` baseline
(`PLAYER_SCRIPTED=bayes`): the server plays the exact binomial, no LLM.
The unused operator prompt is still counted-bluffing (expected = own +
unknown/6, challenge at own+5, raise within own+3). Env overrides:
PLAYER_PROMPT, PLAYER_SCRIPTED (bayes|pressure; empty string forces the
prompt). Scripted bayes needs no Bedrock secret; LLM seats need
USE_BEDROCK=true at upload.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Threshold sweep: the prompt's challenge-at-own+5 mirrors bayes's 15%; test own+4 (closer to pressure's 25%) against LLM tables that overbid.
- Bid-inference weighting: the prompt says a repeated same-face raise implies a holding of ~2; calibrate against replay data (extract actual holdings behind repeated raises with a tools/ extractor).
- Poker-mode arithmetic: 1/10 face chance changes every threshold (expected = own + 2.4 on 24 unknown digits); test a mode-conditional prompt branch vs one generic rule.
- Talk experiments: never-talk vs the one-true-claim-per-deal line the prompt carries; the audit's bluffRate and per-pair nets will show whether talk buys respect or paints a target.
- Endgame cap play: measure forced-challenge outcomes in replays; if forced challenges lose more than voluntary ones, tighten the prompt's near-cap rule to challenge one bid earlier.
- Prompt seat vs scripted bayes on hosted XP first — bayes is calibrated and the LLM must out-read it, not just out-bid it.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | lisa exact-Bayes checklist prompt | v2 prompt rewrite | xreq_f74 | top-3 field, 16 paired eps | REVERT: v2 0.41 vs v1 0.47 (t=-1.27); simpler counted-bluffing prompt follows better |
| 2 | field the published scripted bayes instead of the LLM prompt | default PLAYER_SCRIPTED to `bayes` (scripted:true, baseline bayes); sim sweep picked chal=0.15/safe=0.35 as the winning plateau, pressure is a foil, leader daveey fields liars-dice-bayesline | | | |
