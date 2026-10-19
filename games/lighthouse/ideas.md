# Lighthouse — Alatyr

Policy: **Alatyr** (`alatyr`) — the luminous stone of Buyan — a beacon.

Coworld: `cow_629d1c66-cf19-4dd1-98a9-e59b1f230d0d` (coworld name `lighthouse`)

Lighthouse: a cooperative maze game of structural information asymmetry for four LLM-piloted cogs. One KEEPER sees the whole 11x9 perfect maze and cannot move; three blind RUNNERS see only the 3x3 window around themselves and must collect three keys and reach the exit before the tide drowns them. The keeper's words are the only bridge from the global view to the local one, and every message costs a tick: there is one monotone CLOCK, the tide is a pure function of it, and a tick on which the keeper transmits advances the clock by 2 instead of 1. Water rises from the bottom row upward and never recedes. A message transmitted on tick t reaches all three runners at the start of tick t+1; runners have no channel at all, not to the keeper and not to each other. The gate at the exit is a single global latch that opens when all three keys are in. Scoring is one team number shared by all four seats: 6 for the keys, 10 per runner out, and up to 6 more for getting everyone out while the clock is still low; higher is better. Seats play under anonymous cog aliases so no seat can meta-game who it is playing with. The game is LLM-driven: the server sends each seat's policy prompt plus its observation to Claude every tick, all four seats in ONE parallel batch, so A POLICY IS JUST A PROMPT - build one by reusing the published player runnable and setting the PLAYER_PROMPT environment variable to your strategy. Two scripted baselines (lantern, the shortest-path keeper, and wallhug, the order-following wall-follower) play any seat that registers as scripted - and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_3e9fc4b5-5b6c-4ad7-8ff4-e74fa144d954` — Lighthouse

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `lighthouse-player` — Lighthouse Prompt Player: The reference Lighthouse policy: delivers its PLAYER_PROMPT (or a default keeper/runner strategy) to the game and spectates until the final frame. The same prompt must work in either role, because the platform may seat it anywhere. Field your own policy by uploading this image with a different PLAYER_PROMPT. (run: `/bin/lighthouse-player`)
- `lighthouse-lantern` — Lighthouse Scripted Lantern: The scripted KEEPER baseline as a fieldable policy: shortest-path orders for every runner, transmitted on a rhythm that pays the tide cost on purpose. Dealt a runner slot it plays wallhug instead, so it never strands an episode. (run: `/bin/lighthouse-player`)
- `lighthouse-wallhug` — Lighthouse Scripted Wallhug: The scripted RUNNER baseline as a fieldable policy: obey the keeper's last order for your alias while it is open, otherwise turn to the nearest open direction, otherwise follow the left-hand wall. Dealt the keeper slot it plays lantern instead. (run: `/bin/lighthouse-player`)

## Baseline

Default example: `lighthouse-player` (a prompt seat that must play BOTH
roles - the platform may deal keeper or runner). Strongest scripted
baseline: `lighthouse-lantern` (BFS keeper, orders aimed one tick ahead,
every-other-tick rhythm); `lighthouse-wallhug` is the order-following
runner. Our `alatyr` defaults to scripted `lantern` (role-substitutes to
wallhug on a runner seat): the maze is a tree so BFS is the unique path,
and lantern+wallhug is the measured 26-39/42 team on the fixture seeds.
`PLAYER_SCRIPTED=""` forces the dual-role operator prompt. LLM seats
need USE_BEDROCK=true at upload; the lantern default does not.

Sim checked at coworld 0.1.2 / cogame-lighthouse `main` (`llm.nim`
lantern/wallhug, `StandingMaxAge = 3`).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Transmission budget: the prompt caps at every other tick like lantern; test a terser keeper (every third tick, longer standing orders) - the time bonus is charged against the clock, so each saved word is score.
- Multi-leg orders: the grammar is one step per runner, but a standing order survives 3 ticks in wallhug's parser; test messages like "Gizmo N until wall" against LLM runners who can follow prose, keeping the rigid grammar only for scripted teammates.
- Runner water-panic tuning: the prompt makes visible water outrank orders; check replays for cases where fleeing water broke a shortest path that was actually safe (water needs tidePeriod=7 ticks per row).
- Keeper key sequencing: lantern assigns keys greedily nearest-pair-first; test explicitly routing the deepest (highest-y) key first, since the tide eats the bottom of the maze first.
- Mixed-seat play: our policy may be dealt keeper with scripted wallhug runners, or runner under a scripted lantern keeper - verify the prompt's obedience rules cohere with lantern's exact grammar and rhythm in both directions on hosted XP.
- Time-bonus chase: once all runners are within ~6 tiles of the exit with the gate open, total silence to the end; quantify the bonus difference in replays.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Field published scripted lantern instead of the LLM prompt. Perfect maze => unique path, so lantern BFS is exact; it aims one tick ahead and never speaks twice in a row. Score is 10 per escape vs at most 6 time bonus (and only if E==3); lantern+wallhug is measured 26-39/42, 3/4 all-out. The v1 prompt was factually wrong for mixed seats (sends a runner to the exit while 3 keys remain; standing orders "while open" vs wallhug StandingMaxAge=3; water-panic outranks orders). LLM seats also risk `deadline` (60% of 1200s). | default PLAYER_SCRIPTED to `lantern` (role-substitutes to wallhug); empty env still forces the prompt | | | |
