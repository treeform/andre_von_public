# Continuous Control — Plyaska

Policy: **Plyaska** (`plyaska`) — the folk dance — continuous smooth motion.

Coworld: `cow_39456c26-cffa-4d99-9be9-b2b49454143c` (coworld name `continuous-control`)

One cog, three planar machines, sixty metres of track, three times. Every 1.5 seconds the cog names a gait and tunes five numbers; a deterministic pattern generator and PD servos run that order on every joint 240 times a second. The score is the return: metres covered, plus a bonus per second upright, minus the cost of slamming the actuators.

## Leagues

- `league_62a1e77b-c464-41ba-90df-702fc0d9d3db` — Continuous Control

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `trotter` — trotter: The published scripted baseline and the server-side fallback: settle, then ramp the cadence until the body is moving, then cruise. It is the certification player. (run: `/bin/continuous-control-player`)

## Baseline

The only bundled example is `trotter` (settle, ramp cadence, cruise) —
the certification player, the server-side fallback, and what an
unregistered seat plays; `plodder` is the weaker scripted alternative.
Our policy **Plyaska** (`plyaska/plyaska.nim`) is a Nim prompt seat over
the Sprite v1 BINARY protocol: one 0x81 chat packet carrying
`{"policy","prompt","scripted"}` (no `"type"` field — this game's
registration blob differs from the other cogames), re-sent through the
first ~10 s of received frames, then it only listens — the seat is not
required to answer and sends no Ready packets (docs/protocol_player.md
never grants 0x85 here). The prompt is per-morphology gait scheduling:
settle-then-ramp on the fragile hopper (crouch 40/40, run 55/60, +10
power per clean turn), full-throttle on the unfallable cheetah (run
70/85 -> 100), a hard power-70 ceiling on the tipping walker, never
`brake` on a terminating body (pure damping = a sag and a fall), plus
the doc's feedback table (saturation -> power, slip -> cadence, no
distance -> lean) and a notes tuning ledger. `PLAYER_PROMPT` overrides,
`PLAYER_SCRIPTED=trotter|plodder` fields a baseline. NO upload
secret-envs: the anthropic_api_key secret is injected into the GAME pod
and the player pod makes no model call (docs/protocol_player.md).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Tune the hopper opening: skip the settle turn (walk 45/55 on turn 1)
  and measure fall rate vs distance — the settle costs 1.5 s of the
  13-turn stage and the seeded wobble may not need a full crouch.
- Cheetah `bound` ladder: allow bound at power 100 from turn 6 when
  slip < 0.3 and measure whether it beats run 80/100 on mean distance.
- Walker lean sweep: the prompt pins lean +8; try +12 and +4 variants —
  the walker's 57 deg pitch limit is generous and lean is the main
  anti-march knob.
- Exploit `phase_shift` after stumbles: the one-shot +10 re-time is in
  the prompt but unquantified; log `last_turn.repaired` and falls with
  and without it.
- Encode a best-known-triple warm start per morph in the prompt
  (hopper 55/65, cheetah 78/100, walker 50/62) once XP runs confirm
  them, cutting the exploration turns each stage spends re-learning.
- Shrink the prompt toward the two worked champions' style (short
  numbered rules, no prose) — order quality degrades when the view plus
  prompt runs long.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
