# Vizdoom Deathmatch — Chert

Policy: **Chert** (`chert`) — the devil in the doom arena.

Coworld: `cow_237166ae-6cef-4586-8ae2-15eee2dea457` (coworld name `vizdoom-deathmatch`)

Eight cogs, four RED against four BLUE, in one walled arena with cover, glass windows, med kits and nothing to capture. Each cog carries a hitscan gun that kills in three hits and sees only what is inside its 90-degree forward cone (out to 1575px, walls blocking) or its 90px bubble - its aim carries its vision, so it sees where it points, not where it walks. Every 4.5 seconds each seat is handed a first-person report of its cog: a sixteen-ray depth strip across the cone, a labelled list of every contact in it with bearing and distance, its own health and fire clock, what it heard, and the scoreboard. The seat replies with ONE order - hunt, hold, move_to, flank, retreat or regroup, aimed at a lettered zone (A1..E3) or at a contact's alias - and a deterministic driver executes it tick by tick: it steers, it turns, and it pulls the trigger when a live enemy is in the cone, in range, with a clear line and no teammate in the bullet corridor. Kill an enemy, take a frag. Die, lose one. A team kill costs the killer a frag, which is what stops friendly fire from being a free way to deny one. After 108 seconds the two teams' net frags are compared and the margin is the score, with a 12-frag lead the maximum win and a level game an honest draw. This is the ViZDoom multiplayer benchmark's SHAPE - eight agents, one map, an egocentric observation, frags minus deaths - not a ZDoom port: what ViZDoom's depth and labels buffers carry, this game carries as text, on an engine that compiles to WebAssembly so every replay is a static file the browser re-simulates tick for tick.

## Leagues

- `league_00dcb926-7f23-4507-8a2d-6684cb0e7c4b` — Vizdoom Deathmatch

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `rusher` — rusher: Pressure. Hunts any live enemy known within 520px, heals at 360px when down to one hit point, and otherwise walks at the contested zone - the zone with the most enemy contacts in the last 72 ticks. Also the server-side fallback whenever an LLM seat misses its call, because a degraded episode must still be a legible deathmatch. (run: `/bin/vizdoom-deathmatch-player`)
- `sentry` — sentry: Posting. Never crosses the map's centre line unless it is already hunting, commits only inside 260px, and otherwise holds an assigned post on its own half facing the middle. Deliberately weaker than rusher and different in SHAPE, so the ladder gets a spread rather than two versions of one bot. (run: `/bin/vizdoom-deathmatch-player`)

## Baseline

- Default and strongest example: `rusher` (PLAYER_SCRIPTED=rusher) — hunts known enemies within 520 px, heals at 1 hp, walks at the contested zone; also the per-turn fallback and the default for an unregistered seat. `sentry` is deliberately weaker (never crosses the centre line).
- Our policy: `chert/` — a thin Sprite v1 prompt seat (0x81 register chat frame, 0x85 Ready per frame). The crafted prompt IS the strategy: mandatory per-turn radio contact-sharing, no solo fights, ticks_ago-0 discipline, wounded-target priority, hp-1 disengage, held angles over walking sweeps, margin-aware push/hold endgame, no spawn-column chases.
- Upload secret-envs: none — the platform injects `anthropic_api_key` into the GAME pod and every order decision happens server-side. If a league seat ever plays scripted anyway, retry with `--secret-env USE_BEDROCK=true`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Radio protocol contract: a fixed schema ("c:<alias>@<zone>hp<h>t<ticks_ago> me:<zone> do:<intent>") so four Chert seats parse each other's radio reliably — the team_net radio lines are the only cross-cog channel.
- Crossfire pairs: instruct even/odd identity pairing (alpha+gamma, beta+delta) with hold positions one zone apart facing the same corridor — two locked angles on one approach beat four sweeps.
- Medkit-cycle awareness: kits respawn 30 s after taken; note the take time in notes and time hp-2 rotations to arrive as they respawn.
- Windup exploitation: the aim locks at the pull (5 ticks) — prompt a strafe order (move_to perpendicular, face at the shooter) when a fresh contact already faces you, then re-engage.
- Sound intel: `heard` gives shout positions to both teams — prompt to treat enemy shouts as contacts for zone-pressure math (they cost nothing to exploit, sentries never shout).
- Fallback-turn hygiene: rusher takes over on any missed call; keep the reply short (order first, radio second) to cut latency-driven fallbacks — compare fallbackTurns across XPs.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v2 | see git history | triage batch | paired vs champion | REVERT: 0.65->0.45 t=-1.02 |
| 1 | walk-at-contested, not hold-empty | rule 6: no-contact default is `move_to` contested zone (72-tick contact count, ties C2); drop the false "held angle beats walking" claim. Sim source `baselines.nim` + `tools/ci/baseline_tuning.json` (v0.1.1 / 8731788): rusher (walk contested, hunt 120px) beats sentry (hold posts) 4/6 at +6; a long chase leash also loses. | | | |
