# Hanabi — Ognevushka

Policy: **Ognevushka** (`ognevushka`) — Bazhov's dancing fire sprite — fireworks.

Coworld: `cow_4c005d78-ebb2-4095-83da-cde90519f53b` (coworld name `hanabi`)

Hanabi for four LLM-piloted cogs: the canonical ad-hoc-teamwork benchmark. Each seat holds four cards FACING OUT - everyone can see them except their owner - and the table builds five colour-ordered firework stacks out of a seeded 50-card deck (five colours, ranks 1 1 1 2 2 3 3 4 4 5). On your turn you do exactly one of three things: play a card, discard one (which returns a hint token), or spend one of the eight hint tokens to tell another seat every card of one colour or one rank they hold. Three misplays end the game; so does finishing all five fireworks; when the last card is drawn every seat takes one more turn. The score is the sum of the five stack heights, 0 to 25, and it is the SAME number for every seat - this game is fully cooperative, so read the division leaderboard's mean SCORE, not the Elo spread, which cannot separate two champions who always tie. The whole skill is the theory of mind around hints: what did that hint mean, and what does the partner think it meant? The game is LLM-driven: on a seat's turn the server sends that seat's policy prompt plus the partners' hands, its own hand as KNOWLEDGE ONLY (positive hints, negative information, the candidate set), the full public move log and an enumerated list of every legal move to Claude, so A POLICY IS JUST A PROMPT - build one by reusing the published player runnable and setting the PLAYER_PROMPT environment variable to your conventions. Two scripted baselines (conventions and cautious) play any seat that registers as scripted - and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_332c17c5-b6bf-4341-98c7-3161dd58e6d8` — Hanabi

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `hanabi-player` — Hanabi Prompt Player: The reference Hanabi policy: delivers its PLAYER_PROMPT (or a default convention-light strategy in words) to the game and spectates until the final frame. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/hanabi-player`)
- `hanabi-conventions` — Hanabi Conventions Baseline: The scripted convention-following baseline as a fieldable policy: play what you can prove, save a partner's last copy off its chop, otherwise give the hint that makes the most cards newly playable, otherwise discard your chop. Deterministic, no LLM involved. (run: `/bin/hanabi-player`)
- `hanabi-cautious` — Hanabi Cautious Baseline: The deliberately simpler partner of the cross-play story: it plays only a card it can name exactly, hints ranks of playable cards nobody has been told about, and otherwise discards its chop. It never misplays, and it never takes a risk that would score either. (run: `/bin/hanabi-player`)

## Baseline

Default example: `hanabi-player` (a prompt seat with a convention-light
default). Strongest scripted baseline: `conventions` (play provable, save
criticals, most-newly-playable hints; also the per-turn fallback) — the docs
say a prompt that cannot beat `conventions` is not yet a policy. Our
`ognevushka` is the thin Nim seat: one `{"type":"prompt"}` frame on connect
and again after welcome. **v2 defaults `PLAYER_SCRIPTED` to `conventions`**
(env still overrides; empty string restores the v1 operator prompt). Field
leaders are `co-gas-hanabi-conventions-*`; `decideAll` plays scripted
whenever `scripted != none`. Default is scripted, so no Bedrock flag is
required. LLM override needs `--secret-env USE_BEDROCK=true`. League ranks
by mean team score, not MMR. Sim checked at coworld 0.1.1 /
`282dc8c6bfb340d5f9c72b879eb9219229c0f023`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Cross-play calibration: XP the prompt seated with three `conventions` partners vs three `cautious` partners — the league fields unknown partners, so optimize for the mix actually seated.
- Compare against pure scripted `conventions` on hosted XP — if the LLM cannot beat the baseline mean, field the scripted seat instead. (now experiment 1)
- Tune the endgame gamble threshold (deck < 5, majority-playable candidates): try never-gamble vs 2/3 vs 1/2 candidate-playable cutoffs.
- Add an explicit finesse/prompt-read paragraph: when a partner hints a card that is one-away, check whether the connecting card sits on YOUR newest slot.
- Note-format experiment: a rigid per-slot table ("slot1: r3? from hint t12") vs free prose — measure fallback rate and misplays.
- Token-floor experiment: forbid hinting below 2 tokens unless it saves a critical, freeing discards for the endgame draw.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Field the published scripted `conventions` baseline instead of the LLM prompt. Field leaders are `co-gas-hanabi-conventions-richard` / `relhalpha`; we are #5/6 at 919.8 (below the 1000 default). Score is the team stack total 0-25; mixed seating with conventions partners is the league's cross-play. The v1 prompt treats a single-touch hint as a play signal, but `conventionsMove` uses a rank hint on the next seat's chop to SAVE a critical — playing that card is a misplay. LLM turns also risk `deadline` (60% of episode timeout, 45s reserve/turn, Haiku-first Bedrock). `decideAll` honours `scripted` even with a non-empty prompt; `cautious` never misplays and never scores either. | default PLAYER_SCRIPTED to `conventions` in ognevushka.nim (env still overrides; empty string restores the operator prompt) | | | |
