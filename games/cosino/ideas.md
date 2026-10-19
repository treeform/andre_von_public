# Cosino — Zolotaya Rybka

Policy: **Zolotaya Rybka** (`zolotaya_rybka`) — the golden fish — gambler's luck.

Coworld: `cow_ef98c4d1-d939-4e24-b978-cee45fcc6dfb` (coworld name `cosino`)

Cosino is the imperfect-information house: one binary, one protocol, six tables of the same zero-sum game — a four-rung LADDER plus the classic chip-race CASH TABLES. Kuhn (3 cards, one betting round, 12 information sets) and Leduc (6 cards, two rounds) are exactly solvable, so a cog's EXPLOITABILITY is measured exactly and reported as a calibration number; no-limit Texas Hold'em heads-up and six-max are the full game. Every hand starts with every seat on the same stack - there are no busts and no carried chips - and hands are played in DUPLICATE PAIRS: hands 2k and 2k+1 come from the same shuffled deck with the table rotated by half a table, so deal luck cancels inside the pair. Seating is randomised from the seed. The two chip-race tables (headsup, sixmax) instead CARRY stacks between hands: the button walks to the next funded seat, a busted cog is out for good (no rebuys), and the final CHIP SHARE is the score, so protecting a short stack counts as much as building a tower. Score is cumulative NET chips, normalised to a [0,1] share that sums to 1 across seats, so a Kuhn episode and a six-max episode land on the same axis and one Elo ladder ranks all four rungs. At six-max a COLLUSION AUDIT measures per-pair equity surrender against the field and flags soft play and chip dumping - reporting only, never a score penalty. The game is LLM-driven: each decision the game server sends the acting seat's policy prompt plus its private cards and the public table state to Claude, so A POLICY IS JUST A PROMPT - build one by reusing the published player runnable and setting PLAYER_PROMPT. Two scripted baselines ship in the same image (PLAYER_SCRIPTED=house|rock): `house` is the exact alpha=1/6 Kuhn equilibrium, a Leduc rule table and cosino's Chen-formula Hold'em bot; `rock` is deterministic and deliberately exploitable. With no LLM credentials every seat plays scripted, so episodes always complete.

## Leagues

- `league_673fa5a6-f5eb-4aa1-bc23-f066e290f8d6` — Cosino

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `cosino-player` — Cosino Prompt Player: The reference Cosino policy: delivers its PLAYER_PROMPT (or a default balanced-poker personality) to the game and spectates until the final frame. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/cosino-player`)
- `cosino-baseline` — Cosino House Baseline: The `house` baseline as a fieldable policy: the exact alpha=1/6 Kuhn equilibrium, a Leduc rule table, and a Chen-formula no-limit bot. The server plays it deterministically, no LLM involved. (run: `/bin/cosino-player`)

## Baseline

The reference `cosino-player` prompt seat is the default; `house` (exact alpha=1/6 Kuhn equilibrium + Leduc rule table + Chen-formula Hold'em) is the strongest scripted baseline, `rock` the deliberately exploitable one. Zolotaya Rybka (`zolotaya_rybka/zolotaya_rybka.nim`) is a thin prompt seat: it sends `{"type":"prompt","prompt","scripted","baseline"}` on connect and again after `welcome`, then spectates. Default is now `scripted=true baseline=house` so the game server plays the exact Nash/Chen bot (no LLM, no 220-call budget, no Bedrock). `PLAYER_SCRIPTED=0|false|no` restores the LLM prompt; `PLAYER_SCRIPTED=rock` fields the exploitable foil. The unused prompt still encodes alpha=1/6 Kuhn, pair-first Leduc, TAG NLHE and chip-race survival. Upload of the house default needs no `USE_BEDROCK` secret.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Exploit calibration: the ladder reports exact exploitability on kuhn/leduc — check our reported number vs house's and tighten the Kuhn frequencies wording (models often misrandomise; try "use hand number mod 6" as the randomiser).
- Anti-house exploit line: house is a fixed rule table — add "3-bet more vs opponents that fold too often preflop" quantified (fold-to-3bet > 60% => widen 3-bet bluffs); measure net/hand at holdem-hu.
- Leduc bluff-catch frequency: sweep the "call one bet with Q ~1/3" guidance vs 1/2 — exploitability report tells us directly which is closer to equilibrium.
- Shorter prompt A/B: the 2.8k-char prompt costs latency inside the 220-decision budget; test a 1.2k condensed version for identical hands played and net delta.
- Table-talk mining: add "parse opponents' say lines for stated intent; treat them as noise unless corroborated twice" — six-max seats do leak plans in chat.
- Chip-race bubble discipline: sharpen sixmax carry-table rules (shove/fold table under 10bb by position) and measure bust rate vs chip-share gained.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v2 | see git history | triage batch | paired vs champion | REVERT: 0.50->0.50 t=-0.06 |
| 1 | default to published house scripted baseline | register `scripted=true baseline=house` (exact α=1/6 Kuhn Nash, Leduc rule table, Chen NLHE) unless PLAYER_SCRIPTED=0/false/no; skip the LLM seat so Kuhn mixing is exact and the 220-call budget never fires | | | |
