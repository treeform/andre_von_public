# Negotiation Games — Svakha

Policy: **Svakha** (`svakha`) — the matchmaker — deal broker.

Coworld: `cow_e3bccc46-a2fb-474b-9fc2-6e5ea91085c5` (coworld name `negotiation-games`)

Negotiation Games: a three-seat bargaining table for LLM-piloted cogs, a port of OpenSpiel's `bargaining` (Lewis et al. 2017 / DeepMind). An episode is six one-on-one matches; each match puts a pool of books, hats and balls between two of the three seats. The pool is worth exactly 10 points to each of them, but the per-item values are DIFFERENT and PRIVATE, so there is almost always a split that beats a 50/50 hack. The two seats alternate for at most ten turns: OFFER exactly how many of each item you take (your opponent gets the rest), or ACCEPT the offer standing against you. Agree and you both bank the value TO YOU of what you took, out of 10; run out of turns and BOTH of you bank zero. Every match redraws the pairing, the pool and both seats' valuations, so nothing learned about one opponent transfers, and seats play under anonymous cog aliases so nobody can meta-game who is behind a seat. Offers may carry a short message, but talk is cheap: the structured offer is the only binding channel and the only thing that is graded. Spectators see BOTH seats' hidden valuations, so every offer reads instantly as generous or greedy. The game is LLM-driven: the server sends the acting seat's policy prompt plus the pool, its own private values, the standing offer, this match's history and its private notes to Claude, so A POLICY IS JUST A PROMPT - build one by reusing the published player runnable and setting the PLAYER_PROMPT environment variable to your strategy. Two scripted baselines (a conceding `haggler` and a stubborn `hardliner`) play any seat that registers as scripted - and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_88e9052f-8e37-4f2e-aea1-ea4f5fdb20e7` — Negotiation Games

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `negotiation-player` — Negotiation Prompt Player: The reference Negotiation Games policy: delivers its PLAYER_PROMPT (or a default bargaining strategy) to the game and spectates until the final frame. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/negotiation-player`)
- `negotiation-haggler` — Negotiation Haggler Baseline: The scripted monotone-concession baseline as a fieldable policy: it opens demanding the whole pool and concedes linearly to a floor of 4/10, taking the smallest bundle that still clears its reservation, and accepts anything on its last turn rather than bank zero. (run: `/bin/negotiation-player`)
- `negotiation-hardliner` — Negotiation Hardliner Baseline: The scripted stubborn baseline as a fieldable policy: it holds a reservation of 8/10 all the way to its last turn, refusing most splits and getting its way against a conceder. (run: `/bin/negotiation-player`)

## Baseline

Default example: `negotiation-player` (a prompt seat). Strongest
scripted baseline: `negotiation-hardliner` (reservation 8 until the
last turn, then 3; it beats conceders); `negotiation-haggler` is the
monotone conceder and the universal fallback. Our `svakha` **v2
defaults `PLAYER_SCRIPTED` to `hardliner`**: score is own share of the
pie and the league leader is `reservation-gate-richard`; the v1
integrative prompt accepts 6+ anytime and ladders down to 6, which
concedes into a reservation-8 opponent. Empty `PLAYER_SCRIPTED`
restores the v1 prompt. Upload of the scripted default needs no
Bedrock secret; LLM seats still need `--secret-env USE_BEDROCK=true`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Hardliner counter: against a seat that holds at 8 (offer worth to us <= 2 every turn), the prompt's ladder concedes into it; add an explicit tit-for-tat clause - mirror their reservation until turn T-2, then split - and test both against scripted hardliner.
- Opening anchor sweep: 8-9 vs the full 10-minus-zeros open; a 10/0-looking open may trigger spite in LLM opponents but is strictly better against haggler (it concedes on schedule regardless).
- Message honesty: test naming the true throwaway item vs naming a FALSE throwaway (claiming the middle item is worthless) to poison their value inference; spectators see values, opponents never do.
- Last-turn accept floor: accept >=1 vs >=2 on turn T - with 2 matches per pairing, a reputation for accepting scraps may invite lowballs in the rematch; measure per-pairing second-match offers in replays.
- Turn parity awareness: sharpen the T-1 rule - compute whether we act last from opener parity and say so explicitly in notes at match start, so the model never counters into an unanswerable cliff.
- Prompt seat vs scripted hardliner on hosted XP first — hardliner's score against the league field is the bar; giveaway must stay near zero while score beats it.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Field the published scripted `hardliner` instead of the LLM prompt. Leader is `co-gas-negotiation-games-reservation-gate-richard` (wr 0.57, rating 1039.4); we are #6/6 at 885.8 with the integrative prompt. Score is points/(10×matchesPlayed) — own share of the pie; giveaway is unranked. Hardliner holds reservation 8 until its last turn then 3, taking the smallest bundle that still clears, and extracts 8 against conceders (LLM seats that accept 6+, and prompt-fallback haggler). The v1 prompt accepts 6+ anytime and ladders down to 6, which concedes into a reservation-8 opponent. Server plays the named baseline whenever scripted is non-empty (`src/negotiation/llm.nim`). Scripted/code A/Bs have won; prompt rewrites have lost. | default PLAYER_SCRIPTED to `hardliner` in svakha.nim (env still overrides; PLAYER_SCRIPTED="" forces the prompt) | | | |
