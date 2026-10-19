# Matrix Games — Anchutka

Policy: **Anchutka** (`anchutka`) — the mischievous imp — mind games.

Coworld: `cow_e8a973ea-c4f1-4c99-8a84-a776f1cde531` (coworld name `matrix-games`)

Eight cogs, a yard full of tokens, and one payoff matrix that changes everything. A merged port of Melting Pot's *_in_the_matrix family: your inventory mix IS your strategy, and an interaction beam resolves it against whoever you hit.

## Leagues

- `league_2d6cdf8d-1f9d-4311-80ed-13616f5a8476` — Matrix Games

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `matrix-games-player` — matrix-games-player: The reference matrix-games policy: a prompt seat. Supply PLAYER_PROMPT at upload time to field your own strategy. (run: `/bin/matrix-games-player`)
- `matrix-games-counter` — matrix-games-counter: Plays the best response to whatever the nearest eligible cog last showed. The strongest of the five baselines. (run: `/bin/matrix-games-player`)
- `matrix-games-tit-for-tat` — matrix-games-tit-for-tat: Mirrors whatever the nearest eligible cog last showed. (run: `/bin/matrix-games-player`)
- `matrix-games-fixed-pick` — matrix-games-fixed-pick: Draws one token type at episode start and commits to it forever. (run: `/bin/matrix-games-player`)
- `matrix-games-always-first` — matrix-games-always-first: Always the first token: always-C, always-dove, always-stag, always-Bach, always-rock. (run: `/bin/matrix-games-player`)
- `matrix-games-always-second` — matrix-games-always-second: Always the second token: always-D, always-hawk, always-hare, always-Stravinsky. (run: `/bin/matrix-games-player`)

## Baseline

Default example: `matrix-games-player` (a prompt seat). Strongest scripted
baseline: `matrix-games-counter` (best response to the nearest cog's last
shown mix; also the fallback move). Our `anchutka` is the thin player
rewritten in Nim carrying an operator prompt that plays counter-style best
response with hunt/avoid awareness. LLM seats need USE_BEDROCK=true at
upload.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Tune the prompt per variant: aggressive in running-with-scissors, convention-following in bach-or-stravinsky.
- Use the public resolution log to estimate each cog's mix and pre-position counters.
- Deny-starve the leader's preferred token when they camp one zone.
- Compare prompt seat vs pure scripted `counter` on hosted XP first — the LLM may underperform the deterministic counter.
- Watch replays of `richard` (current MMR leader) and extract what intents they favor.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v2 | see git history | triage batch | paired vs champion | REVERT: 0.43->-0.09 t=-1.68 |
| 1 | Field the built-in `counter` instead of the LLM prompt. Leader policy is `co-gas-matrix-games-counter-richard`. Score is the sum of resolution payoffs; gather/deny never fire, so a cog that never hunts scores 0. Counter gathers the best-response token to CommitTarget=5 then hunts the nearest eligible cog — the strongest of the five baselines, and it guarantees interactions. | default PLAYER_SCRIPTED to `counter` in anchutka.nim (env still overrides) | | | |
