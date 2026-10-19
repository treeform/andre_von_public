# Grf Football — Alyosha Popovich

Policy: **Alyosha Popovich** (`alyosha`) — the agile trickster bogatyr.

Coworld: `cow_60738189-36bb-4365-9dd0-61fe4e23c742` (coworld name `grf-football`)

Eleven-a-side association football in a continuous 2D physics world: 22 cogs, one ball, throw-ins, corners and goal kicks. A policy is just a prompt — every ten seconds you issue ONE order for your shirt and a deterministic controller executes it.

## Leagues

- `league_973d55af-1df6-49b5-bb86-f3939993f65b` — Grf-Football

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — GRF Football Zonal Baseline: The bundled certification seat: registers as the scripted `zonal` baseline (hold the zone, support the ball, press when it is close, go and win a loose ball) so an episode always completes without LLM credentials. (run: `/bin/grf-football-player`)

## Baseline

The only bundled example is `baseline` — the scripted `zonal` seat (hold
the zone, support the ball, press when close, win a loose ball), which is
also the double-failure fallback and what an LLM seat plays without
credentials; `gegenpress` (press everywhere, sprint always, fades on
stamina by minute three) is the weaker second filler. Two shipped
champion prompts, `grf-football-tiki` (possession) and
`grf-football-counter` (counter-attack), live in the game repo's
`tools/ci/policies.json`. Our policy **Alyosha Popovich**
(`alyosha/alyosha.nim`) is a Nim prompt seat over the Sprite v1 BINARY
protocol (NOT JSON text frames): one 0x81 chat packet carrying
`{"type":"register","prompt",...}` on connect, re-sent once after the
first received frame, then a 0x85 Ready byte per frame to pace fastMode,
exiting when the server closes the socket. The prompt plays role-adaptive
disciplined football: closest-only pressing, move-in-possession support,
shoot inside 16 m, sprint-auto stamina banking, tackle-never as last
man, lead protection after turn 16. `PLAYER_PROMPT` overrides,
`PLAYER_SCRIPTED=zonal|gegenpress` fields a baseline. Upload MUST carry
`--secret-env USE_BEDROCK=true` or the seat silently plays zonal.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Read the shipped champions: fetch `tools/ci/policies.json` from the
  game repo and A/B our prompt against tiki and counter phrasing —
  especially their target coordinates per role.
- Role-split prompts: the seat learns its shirt only at runtime — test a
  prompt with four explicit per-shirt playbooks (10/9/7/6) vs the current
  adaptive prose.
- Turn-indexed stamina budget: give the prompt a concrete sprint
  schedule (auto until turn 8, never 9-16 unless within 15 m of either
  box, auto after) and check stamina at turn 12 stays over 300.
- Pass_to exploitation: the built-in AI yields to seated cogs near loose
  balls and passes to the best-placed teammate — test always naming the
  built-in winger on the weak side as pass_to to bend the AI's shape.
- Set-piece book: explicit corner/throw-in targets (near-post edge of
  the box attacking, zonal spots defending) instead of generic intents.
- Margin management: score caps at +/-3 goals — when 3 up, full
  hold_shape lockdown; measure whether that concedes fewer than pushing
  for a fourth.
- Counter trigger: when the ball turns over in our half and our stamina
  is above 400, one make_run order with a target behind their last man —
  quantify goals per counter across an XP batch.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | shoot from 16 m, not 20 m — 20 m is the empirically worst range | prompt item 3: "shoot only inside 20 m" → "16 m" (zonal grid 12/16/1.5 train gd +5 holdout +8 vs 12/20/1.5 train −3; 20 m shots are keeper-parry/goal-kick turnovers) |  |  |  |
