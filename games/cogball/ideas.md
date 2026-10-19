# Cogball — Nikita Kozhemyaka

Policy: **Nikita Kozhemyaka** (`kozhemyaka`) — folk strongman — sports.

Coworld: `cow_6e7ee029-daee-41ff-8857-e0ab87e7cf4a` (coworld name `cogball`)

3v3 robot soccer in a continuous 2D physics world. A policy is just a prompt: every five seconds you issue ONE directive for all three of your robots and a deterministic controller executes it.

## Leagues

- `league_e87130ef-ecc6-49d4-9bc1-4014b7141df5` — Cogball

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — Cogball Formation Baseline: The bundled certification seat: registers as the scripted `formation` baseline (one keeper on the goal arc, the nearest robot on the ball, the third in the channel) so an episode always completes without LLM credentials. (run: `/bin/cogball-player`)

## Baseline

The bundled `baseline` example registers the scripted `formation` trio
(keeper on the arc, nearest robot on the ball, third in the channel);
`swarm` is the other scripted option and loses to it. Our policy
`kozhemyaka` is a prompt seat: it sends one Sprite v1 chat packet (0x81,
u16 LE length) carrying the `register` frame, then answers every binary
tick frame with a Ready packet (0x85) so fastMode can pace the match.
Default (neither env set) is scripted `formation` — the grid-tuned
baseline (2 m keeper arc, 9 m striker, screening back) that the league
leaders named `*-cogball-baseline-*` are playing. PLAYER_PROMPT fields
an LLM seat; PLAYER_SCRIPTED selects formation|swarm. LLM seats need
`--secret-env USE_BEDROCK=true` or the seat silently plays formation.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Tune the keeper arc: try target 2 m vs 4 m off the line and y-tracking
  at 1/2 instead of 1/3 of ball y; measure goals conceded per episode.
- Kick "never" on the keeper so it shepherds instead of swinging —
  coaching.md hints this reduces own-goal-adjacent clearances.
- Add an explicit mercy-hunt line: when leading by 3+ keep pressing for
  the +5 mercy end instead of parking the bus (score is margin-clamped
  at gd 3, so test whether this actually pays).
- Use last_turn possession_pct_you to switch formation: under 40 %
  possession go double-press, over 60 % go double-attacker.
- Exploit the restart rule: after conceding, the directive right at
  kickoff could pre-position the wing at ±9 m for the flank ball.
- Shorter prompt A/B: the 6 s LLM deadline is tight; test whether a
  ~120-word prompt lowers fallbackTurns vs this ~300-word one.
- Pass-lane bias: aim wing target at the far post so "pass" leads the
  receiver goal-side, not square.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | default to the measured formation baseline instead of the LLM coaching prompt | register empty prompt + scripted=formation (PLAYER_PROMPT / PLAYER_SCRIPTED still override). Field: relh/richard `*-cogball-baseline-*` lead at wr 0.56/0.54; both published LLM champions lose (cogball-total 0.45, cogball-counter 0.35). Sim grid (docs/tuning/baseline-grid.md): formation's 2 m keeper beats coaching.md's 3 m; our old prompt also pressed when defending (SupportAlwaysRuns=0 wins 63/96 vs 50) and passed from range (formation shoots in their half). | | | |
