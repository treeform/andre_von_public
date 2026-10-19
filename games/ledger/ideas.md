# Ledger — Chichikov

Policy: **Chichikov** (`chichikov`) — Gogol's accountant of souls.

Coworld: `cow_79259a28-8e2f-4593-9978-bcb162265a11` (coworld name `ledger`)

Ledger: a repeated-dilemma tournament for eight LLM-piloted cogs where your name follows you. Each seat plays under a permanent public alias for the whole episode, and every move it makes is on the record from round one. Every round the eight aliases are drawn into four pairs from a circle-method rotation (over 14 rounds every cog meets every other cog exactly twice, a full double round robin, and no pair ever meets in consecutive rounds), and each pairing draws one of three one-shot games: DILEMMA (a prisoner's dilemma, 50% of pairings), TRUST (an investment game, 30%) or ULTIMATUM (a split-the-pie game, 20%). All eight seats decide SIMULTANEOUSLY: trust and ultimatum are resolved with the experimental-economics strategy method, so the trustee commits a return percentage and the responder commits a minimum acceptable offer before seeing what the first mover did. Fair play pays 6 coins in all three games, exploitation pays 10-12 and being exploited pays 0. Every reply may carry a one-line public review of the previous round's partner; accepted reviews go on a public gossip board every seat reads, and they change no payoff. A seat's SCORE IS THE MEDIAN of its per-meeting payoffs, not the total and not the mean - the one statistic a cartel cannot pump, because a ring can feed one alias a big number twice but cannot move the median it earns against the other six strangers. Collusion is measured anyway: pairs that pay each other far more than they earn elsewhere are flagged, drawn as red threads in the replay and reported in the results, and none of it is ever rescored. The game is LLM-driven: the server sends each seat's policy prompt plus its own record, its partner's full public history, the table, the gossip board and its private memo to Claude, all eight calls in one parallel batch per round, so A POLICY IS JUST A PROMPT - build one by reusing the published player runnable and setting the PLAYER_PROMPT environment variable to your strategy. Two scripted baselines (mirror, a reciprocator with forgiveness, and shark, the greedy foil) are fieldable policies in their own right and play every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_1ad5ff34-7cf7-4940-9ef2-b7690a4bf5aa` — Ledger

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `ledger-player` — Ledger Prompt Player: The reference Ledger policy: delivers its PLAYER_PROMPT (or a default reputation strategy) to the game and spectates until the final frame. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/ledger-player`)
- `ledger-mirror` — Ledger Mirror Baseline: The scripted reciprocator as a fieldable policy: cooperates first, then plays back the partner's most recent public dilemma move, forgives a single lapse one time in five, invests 4 and returns 50% against a clean halo and 1 / 25% against a dirty one, offers 5 and holds a floor of 4. No LLM involved. (run: `/bin/ledger-player`)
- `ledger-shark` — Ledger Shark Baseline: The greedy foil reputation is supposed to punish: always defects, sends 0 and returns 0, offers 1 and accepts nearly anything. It scores well early and its record follows it. No LLM involved. (run: `/bin/ledger-player`)

## Baseline

Default example: `ledger-player` (a prompt seat). Strongest scripted
baseline: `ledger-mirror` (reciprocator with forgiveness; also the
fallback for unparseable replies); `ledger-shark` is the greedy foil.
Our `chichikov` is the thin Nim player. **v2 defaults `PLAYER_SCRIPTED`
to `mirror`** (TFT + 20% single-lapse forgiveness, send 4 / return 50%
on halo >= 0.5 else 1 / 25%, offer 5, floor 4). Score is the median of
14 payoffs — `(sorted[6]+sorted[7])/2` — so one LLM 0 (broken deal,
sucker, send-6 betrayal) or a deadline-cut episode is worse than
playing the deterministic reciprocator. Set `PLAYER_SCRIPTED=""` for the
v1 median-protection operator prompt. LLM seats need USE_BEDROCK=true
at upload.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Second-meeting endgame: against an alias you meet for the second (last) time, defection carries no future cost from THAT alias — test whether selective last-meeting defection against MIXED records lifts the median or just dirties the halo the other six read.
- Trust-investor tuning: compare always-send-0 (guaranteed 6, harsh) vs send-4-to-clean (kind, 6 or better) on hosted XP; the halo effect on how LLM opponents treat us is unmeasured.
- Responder floor sweep: m=2 vs m=3 vs m=4 — the doc recommends 3-4, but against a table of mirrors a floor of 2 never breaks a deal and the median may not need the deterrence.
- Gossip weaponisation: dedicate the note every round to naming the lowest-halo alias with its exact numbers; measure whether LLM tables actually converge on punishing it (our 6s rise) or ignore gossip entirely.
- Memo schema: replace free prose with a fixed one-line-per-alias code ("Bolt=S d0 r0 o1") so the 400-char cap always fits all seven partners; test parse-robustness across rounds.
- Prompt seat vs scripted mirror on hosted XP first — mirror is a strong reciprocator and the LLM must beat it to be worth the Bedrock spend.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v2 | see git history | triage batch | paired vs champion | REVERT: 6.00->6.00 flat |
| 1 | prompt seat vs scripted mirror | default PLAYER_SCRIPTED to mirror (TFT+forgiveness; LLM off unless env cleared) | | | |
