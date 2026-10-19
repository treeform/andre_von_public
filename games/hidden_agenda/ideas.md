# Hidden Agenda — Chernobog

Policy: **Chernobog** (`chernobog`) — the hidden dark god.

Coworld: `cow_962d0488-144c-48f6-b0c7-08a19ac5ed89` (coworld name `hidden_agenda`)

Five cogs mine a sealed station for a central grate. One of them is an impostor with a freeze beam, frozen crew stay on the floor as evidence, and a meeting fires the instant a freeze happens inside somebody's field of view.

## Leagues

- `league_9c44cf05-76f9-4ca5-8299-0c16a5e41ed9` — Hidden Agenda

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `hidden-agenda-miner` — Hidden Agenda miner: The working baseline: mine, deposit, watch whoever you have gone longest without seeing, and vote a deterministic suspicion score. As the impostor it hunts only when its own view is empty. (run: `/bin/hidden-agenda-player`)
- `hidden-agenda-lurker` — Hidden Agenda lurker: The foil: head-down crew that works one seam all episode, and an impostor that fires the instant the beam is legal, witnesses or not. (run: `/bin/hidden-agenda-player`)

## Baseline

Default example: `hidden-agenda-miner` (the working baseline and the
per-decision fallback); `hidden-agenda-lurker` is the deliberately loud
foil. Our `chernobog` is the thin prompt-or-scripted player in Nim (hello frame
sent on connect and re-sent after welcome). Default is `PLAYER_SCRIPTED=miner`
— the published working baseline and the per-decision LLM fallback. League
leaders (`co-gas-hidden-agenda-miner-relhalpha`, `…-richard`) field miner
variants at wr 0.32 vs LLM seats at wr ~0.12; a failed LLM reply already
plays miner, so the prompt seat was a slower, noisier miner. Override with
`PLAYER_SCRIPTED=` plus `PLAYER_PROMPT` to field the LLM path (then
USE_BEDROCK=true is required). Sim checked at coworld 0.1.2 /
`731ab43ebbd6fcb3908b583855cc1c75270763c7`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- XP the prompt against four `miner` seats and against a `lurker` impostor separately — crew skill and impostor skill move independently.
- Voting-threshold experiment: current prompt skips without hard evidence; try adding the miner's numeric suspicion score (witnessed 20, body-in-room 3, fake-deposit 6) as a tie-breaker.
- Impostor pacing: one kill per cooldown vs a deliberate no-kill first 500 ticks (build trust, then isolate stragglers when seams dry up).
- Crew buddy-system strength: always stay within another cog's view vs only after the first body — measure deposit-rate cost of pairing.
- Meeting chat variant: when chat=true, add say-lines that state evidence tersely ("saw PINK at grate, counter froze") — check if crews converge faster.
- Watch-rotation tuning: watch the least-recently-seen alias vs watching whoever is nearest the grate (fake-deposit catcher).

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v2 | see git history | triage batch | paired vs champion | REVERT: -0.80->-0.80 flat |
| 1 | field the published miner baseline instead of the LLM prompt | default `PLAYER_SCRIPTED` to `miner` (leaders relh/richard are miner variants at wr 0.32 vs LLM wr ~0.12; invalid LLM replies already fall back to miner) | | | |
