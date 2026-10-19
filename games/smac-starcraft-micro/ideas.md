# Smac Starcraft Micro — Peresvet

Policy: **Peresvet** (`peresvet`) — the warrior monk — single combat micro.

Coworld: `cow_ea5a7b7a-be6a-4354-b164-ed0f4773f0c1` (coworld name `smac-starcraft-micro`)

Five cogs, one unit each, fight a scripted enemy army three times on a fixed arena. The whole squad shares ONE score: how much of the army you destroy, whether you wipe it out, and how much of your own health survives. Focus fire is the whole game.

## Leagues

- `league_f42b4821-882b-428e-b803-630671e86726` — Smac Starcraft Micro

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — Focus Fire Baseline: Scripted unit: the whole squad derives one kill order from state, rangers kite when a melee enemy closes, blades screen the rangers. (run: `/bin/smac-starcraft-micro-player`)

## Baseline

The only example player is `baseline` (Focus Fire Baseline), which registers the scripted `focusfire` policy — also the per-turn LLM fallback, the no-show driver, and the default for an empty registration. `charge` is the second, deliberately weaker scripted filler. Our `peresvet` is a thin Sprite v1 seat (0x81 registration, Ready 0x85, no inputs). It now **defaults to scripted `focusfire`**: the server sets `isLlm := prompt.len > 0`, so we send an empty prompt with `"scripted":"focusfire"` so all five seats derive the same kill order from state. The unused prompt still encodes threatened-then-lowest-hp, ranger kite at 200 px, blade screen at 260 px. `PLAYER_SCRIPTED=""` restores the LLM seat; `"charge"` is the weaker filler. The focusfire default needs no Bedrock secret.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Tune the ranger kite trigger: the enemy swarm reaches 40 px and moves ~86 px/s, so a 200 px panic radius may kite too early and waste ranger uptime; try 150 px (the focusfire baseline's panicPx) vs 250 px.
- Add a corridor-scenario branch: on the `corridor` map tell blades to hold the 104 px doorway (`hold` at the channel centre) instead of screening, and rangers to stand behind them.
- Exploit enemy retarget hysteresis: a kiting ranger keeps its attacker leashed (1.5x-closer rule blocks retargets), so tell one ranger to deliberately drag melee enemies away from the volley.
- Use `focused_by` arithmetic: skip to the next kill-order target when the current one is already focused by 4+ and nearly dead, to stop overkill (damage is clipped to remaining hp).
- Outnumbered scenarios: prompt the blades to fight at the squad centroid rather than walking into the swarm, using the chase cap intentionally to stay compact.
- Endgame clock math: when `won` is out of reach, have all seats maximise `dmgFrac` explicitly (attack the highest-hp-remaining cluster) instead of trying to win late.
- Check `results.fallbackTurns` after each XP run; if fallbacks are high, shorten the prompt (board is already in the message) before touching strategy.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | play the published winning policy (scripted focusfire) | default PLAYER_SCRIPTED to "focusfire" and send empty prompt (server isLlm := prompt.len > 0); five LLM seats split the kill order, focusfire derives one target from state |  |  |  |
