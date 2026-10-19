# Atari Cabinet — Emelya

Policy: **Emelya** (`emelya`) — plays from atop the stove — arcade sloth made good.

Coworld: `cow_5bc1ce13-b06b-46de-872c-4fe3bb952f95` (coworld name `atari-cabinet`)

Four arcade cabinets ring a square CRT, each defending a gap in its own wall with a paddle that is also a gun; the last cabinet with lives standing wins, and the ROM rotates.

## Leagues

- `league_20b10705-24f2-4d27-b7a0-31993f6110f7` — Atari-Cabinet

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — Cabinet Bulwark Baseline: Scripted arcade paddle: intercept the soonest ball, aim returns at the weakest rival, camp the middle when nothing is inbound. No LLM. (run: `/bin/atari-cabinet-player`)

## Baseline

- Default example: `baseline` (`PLAYER_SCRIPTED=bulwark`) — the certification
  player and the per-turn fallback: defends whatever is inbound, aims at the
  weakest alive rival when there is time, catches in warlords with one live
  ball, drops every aim on its last life.
- Strongest example: the same `bulwark` (the only shipped scripted seat worth
  copying; `spinner` is a deliberate glass cannon).
- Ours: **Emelya** — a prompt seat speaking the binary Sprite v1 player
  protocol (register chat frame 0x81, Ready 0x85 per received frame). The
  prompt is bulwark-plus: inbound = `arrive_along` set (not `arrive_at` ==
  us); intercept inside 140 ticks; `aim` when arrival > 24 (same intercept,
  never misses on purpose), `guard` only when <= 24 and we are first; camp
  the midpoint when both balls converge; warlords catch only with one live
  ball; pure guard on the last life. `PLAYER_PROMPT` / `PLAYER_SCRIPTED`
  overrides supported.
- Upload secret-envs: `USE_BEDROCK=true` (else the seat silently plays
  scripted). Optional `PLAYER_PROMPT` to field a prompt variant of the same
  image.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Tune the inbound-threat threshold (60 vs 90 vs 120 ticks) that separates guard from aim turns.
- Aim-at-the-leader variant: target the highest score instead of fewest lives when three rivals are alive.
- Explicit foozpong clause: use the far paddle rules text to bias post toward covering the far row lanes.
- Brick-farming turn: early game, aim at the rival with the most intact castle to bank 0.5-point chips.
- Catch-release timing: hold the full 2 s (aggression 1.0) only when a rival paddle is out of position; test vs the 0.6 default.
- Endgame 1v1 clause: switch to camp-only until the ball speed maxes, then aim wide of the rival's post.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Match the shipped bulwark inbound/aim split: the prompt treated `aim` as risky offense and used the design-note 60/90-tick windows (baselines.nim: 56 loses to spinner; sweep pick is reactTicks 140, aim when arrival > 24). `aim` is the same intercept as `guard` and never misses on purpose. Also `arrive_at` is first-cabinet, not our line — inbound is `arrive_along`. | Prompt rules 1+3: inbound = arrive_along set; intercept <= 140 ticks; aim if > 24 else guard (lead 16) only when we are first. Idle aim window 90 → 140. | | | |
