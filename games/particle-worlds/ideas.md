# Particle Worlds — Stribog

Policy: **Stribog** (`stribog`) — god of winds — particles.

Coworld: `cow_039ad60d-ae1f-4098-ab1d-4f0144e32198` (coworld name `particle-worlds`)

Four particles glide on a bounded field around four coloured landmarks and play four MPE scenarios back to back: cover the marks together, hide a goal from an adversary, smuggle a colour past two eavesdroppers, and run a three-on-one chase. Moving is nearly free; the only thing a seat can say to another seat is one symbol out of nine, once every 4.5 seconds, broadcast to the whole field.

## Leagues

- `league_2ae87c04-15f1-4116-ad6d-54e0d656ea49` — Particle Worlds

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — Drifter Baseline: Scripted particle: covers its assigned mark, speaks the key honestly as the speaker, decodes it as the listener, tails the listener as an eavesdropper, and flees or chases in tag. (run: `/bin/particle-worlds-player`)

## Baseline

Default example: `baseline` = the scripted `drifter` (mode-aware: covers
its role-index mark, honest speaker, decoding listener, shadowing Eve,
evade/chase in tag); `beeline` is the deliberately weaker second
baseline. Our `stribog` is the thin Sprite v1 registrar rewritten in Nim
(0x81 chat registration re-sent ~10 s, 0x85 ready per frame) carrying an
operator prompt: drifter-compatible spread claims (role-index mark) with
squatter resolution, decoy-heavy deceive, late-break crypto listener,
on-mark eavesdropping, and split pursuit (one chaser, two cut-offs) in
tag. Supports PLAYER_PROMPT / PLAYER_SCRIPTED (drifter | beeline)
overrides. LLM seats need USE_BEDROCK=true at upload.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Crypto listener A/B: straight run to the goal vs the current two-turn fake — measure whether the Eves' shadow lag actually pays at league level.
- Eavesdropper: try splitting the two Eves (one shadows Bob, one parks the mark nearest Bob's heading) via a colour-rank rule, instead of both converging.
- Deceive adversary: weight settled_ticks by "settled EARLY" — decoys tend to settle late, the real goal-sitter first; test against drifter tables.
- Spread: test colour-rank mark claiming (independent of role index) vs role-index claiming when the table is all-LLM — role-index only exists to match drifter fillers.
- Tag pursuers: try a third mode — two pursuers hold the two nearest corners while one chases, collapsing the evader's evade-probe space.
- Use the radio in deceive as the adversary: mimic a good agent's symbol pattern to bait a decoy into "correcting" toward the goal.
- Trim the prompt under 2000 chars (currently ~2600) and measure fallbackTurns/llmTurns — shorter judgement text may parse and decide faster.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v2 | see git history | triage batch | paired vs champion | REVERT: 0.56->0.55 t=-0.25 |
| 1 | tag pursuer score is personal contact, not a team hunt | prompt: every pursuer shadows to contact; intercept 250 px ahead only when someone is already on the tail, then stick (never herd for a chaser). Scoring: roundP[p]=min(1000, credit[p]*1000/120) |  |  |  |
