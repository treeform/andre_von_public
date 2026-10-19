# Pistonball — Vakula

Policy: **Vakula** (`vakula`) — Gogol's smith — pistons and iron.

Coworld: `cow_768730a3-282a-4d75-9cff-01eea560e260` (coworld name `pistonball`)

Pistonball: twenty LLM-piloted pistons and one ball. The pistons stand shoulder to shoulder in a bank across the floor of a long, shallow box; the ball is dropped against the right wall and rolls down whatever slope the bank happens to be making under it. Get it to the left wall. The catch is sight: a piston sees only one metre either side of itself, so for most of the run nobody can see the ball at all - you steer from your last sighting, your two visible neighbours' heights, and a single shared number saying whether the bank as a whole gained ground. A travelling wave is the only thing that works and no seat can see the whole wave. Fully cooperative: every seat scores the same, progress toward the goal wall minus a per-tick penalty, so speed is the only tiebreak. Seat-to-piston assignment is reshuffled every episode, so a policy cannot memorise a position.

## Leagues

- `league_6789db33-ab0a-4b15-b572-b3ea39c614fd` — Pistonball

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — Pistonball Wavebot Baseline: Reactive scripted piston: lift behind the ball, clear in front. No LLM. (run: `/bin/pistonball-player`)
- `metronome` — Pistonball Metronome Filler: Blind two-second ripple: never looks at the ball. No LLM. (run: `/bin/pistonball-player`)

## Baseline

Default example: `baseline` = the scripted `wavebot` (mode wave,
trigger 1.0, lead 6, up 1.45, down 0.10, idle 0.25, blind hold) — the
strongest published baseline, the certification player, the per-turn
fallback, and the driver of any seat that never registers; `metronome`
is the blind ripple filler. Our `vakula` is the Sprite v1 thin player
in Nim: registration re-sent over the first ~10 s of frames (joins are
slot-sequential), a ready packet after every frame, no inputs ever.
**Default is `PLAYER_SCRIPTED=wavebot`** (empty prompt so the server's
`isLlm = prompt.len > 0` actually honours the baseline). Empty
`PLAYER_SCRIPTED` restores the operator prompt (speed-scaled lead,
stay-high behind, stay-low ahead, catch). Env still overrides
(`wavebot` | `metronome` | empty). Upload secret-envs: none for the
wavebot default. LLM override needs `--secret-env USE_BEDROCK=true`.
Sim checked at coworld 0.1.3 /
`30964b3d16bffe6a4df164e7c13b1c581f1a48e4`.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- A/B the stay-high-behind rule (hold at 1.45 after the ball passes) against wavebot's blind hold — it should steepen the slope but may trap a bounced-back ball.
- Tune idle_m for left-half pistons: 0.05 vs 0.15 vs 0.25 — how low must the runway be before the wave outruns the ball?
- lead_ticks sweep: fixed 6 (wavebot) vs the prompt's speed-scaled 5/8/11 — measure delivery tick on hosted XP.
- Add a launch assist: pistons that start within 2 m of the right wall could open with a ripple to unstick the ball from the wall drop.
- Try trigger_m 0.7 (act later, sharper wave) vs 1.0 — a narrow wave may waste fewer strokes on distant sightings.
- Test whether an all-LLM bank beats 1 LLM + 19 wavebots at all — if not, the prompt should converge exactly to wavebot behaviour with tuned constants.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Field built-in `wavebot` instead of the LLM prompt. Field leaders include `co-gas-pistonball-wavebot-relhalpha` and `co-gas-pistonball-wavebot-richard`; we are #5/6 at 1000.0. Score is shared: +100 for delivery minus 0.010/tick (speed is the only tiebreak; wall-clock 660s ends as deadline with partial progress). Server sets `isLlm` from `prompt.len > 0` (src/pistonball/server.nim), so our compiled defaultPrompt made every upload an LLM seat. Wavebot is the grid-swept default (lead 6, up 1.45 m, idle 0.25 m; tests/test_baselines.nim: >=18/20 delivered, mean >60 vs metronome). LLM seats pay 45s batch spacing (20-seat Bedrock at 30 rpm) and already fall back to wavebot on parse/throttle/budget_guard. Our prompt also fights the sweep (lead 8 vs 6, idle 0.15 vs 0.25, stay-high hold, catch). Scripted/code A/Bs have won; prompt rewrites have lost. | default PLAYER_SCRIPTED to `wavebot` and send an empty prompt while a baseline is named (env still overrides; empty PLAYER_SCRIPTED restores the operator prompt) | | | |