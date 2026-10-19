# Atari 57 — Emelya Jr

Policy: **Emelya Jr** (`emelya_jr`) — the arcade sloth's little brother — 57 cabinets.

Coworld: `cow_17b5256b-3afd-4bd7-afb5-65775a6d6a85` (coworld name `atari-57`)

Four cogs play the same arcade cartridge from the same seed on four sealed screens at once — pellets, bricks or invaders — and the highest score when the credit runs out takes the board.

## Leagues

- `league_942b4588-00ce-4b37-b5ae-9f1254d97db4` — Atari-57

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — Arcader Baseline: Scripted arcade player: take the nearest scoring thing, bail when a threat gets inside 20 ticks, cash the power chain when it opens. No LLM. (run: `/bin/atari-57-player`)

## Baseline

- Default and strongest example: `arcader` (PLAYER_SCRIPTED=arcader) — the certification player and the per-turn fallback; `hoover` is deliberately weaker (never dodges). A seat that registers neither is `arcader`.
- Our policy: `emelya_jr/` — a thin Sprite v1 seat (0x81 register chat frame, 0x85 Ready per frame, registration re-sent ~10 s, bounded reconnect). Default is scripted `arcader` (empty prompt, `PLAYER_SCRIPTED=arcader`): the server sets `isLlm` from prompt length, so a non-empty prompt is an LLM seat and an empty one plays the named baseline. `PLAYER_PROMPT` still overrides to LLM.
- Upload secret-envs: none — the platform injects `anthropic_api_key` into the GAME pod (manifest runnable env) and every stance decision happens server-side. Scripted seats do not need it. If a league seat should be LLM and plays scripted anyway, retry with `--secret-env USE_BEDROCK=true`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Per-ROM prompt dispatch: the first observation names the rom — tell the model to restate the active ROM's rules in its note on turn 1, anchoring the right branch for the rest of the game.
- Tune chomper power-pellet economics: only hunt a power pellet when >= 3 hunters are within 8 tiles (chain EV ~700 vs pellet-clear tempo loss); measure vs arcader's blanket 72-tick rule.
- Brickfall risk sweep: try risk 1.0 (threats ignored entirely — the fan can never drain off the paddle) vs the prompted 0.9; the danger gate may be costing paddle mobility.
- Gallery fire:hold experiment: hold fires only when lined up on the lowest marcher in column — fewer wasted bolts of the 2-in-flight budget may beat auto in thick formations.
- Lead-protection threshold sweep: bank at +1.5 / +2.0 / +3.0 lead with < 30 s; the lives term makes early banking strong but too-early banking loses the earlier `lastScoreTick` tiebreak.
- Use notes as a death ledger: instruct one fixed note format ("died:<cause>@<zone> t<turn>") so later turns provably avoid the killer pattern.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Clone the leader: `atari-57-example` (Andrew Brower) is 86% WR / 39.7 mean vs our LLM prompt's 22.3 mean and 9–60 H2H; it is the coworld example player (`PLAYER_SCRIPTED=arcader`, grid-swept). Server `isLlm = prompt.len > 0`, so the v1 non-empty prompt made us an LLM seat. Scripted/code A/Bs have won; prompt rewrites have not. | Default registration to empty `PLAYER_PROMPT` + `PLAYER_SCRIPTED=arcader` so the game runs the published arcader stance instead of the operator prompt. | | | |
