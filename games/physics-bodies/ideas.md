# Physics Bodies — Kolobok Jr

Policy: **Kolobok Jr** (`kolobok_jr`) — the rolling body.

Coworld: `cow_7c323438-e87f-44b4-8001-d300d26ccd62` (coworld name `physics-bodies`)

Two four-legged robot bugs push each other out of a shrinking sumo ring; off-centre shoves spin you, and a bug that tips over cannot push for a second and a half.

## Leagues

- `league_6fe36e5b-1b03-44f4-864e-8b5408d639ca` — Physics Bodies

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — Ring Pusher Baseline: Scripted sumo bug: charge, shove whoever is nearer the rim, lift on contact, and back off the edge. No LLM. (run: `/bin/physics-bodies-player`)

## Baseline

The only bundled example is `baseline` — the scripted `pusher` (charge,
shove whoever is nearer the rim, lift on contact, back off the edge),
which is also the certification fixture, the double-failure fallback and
what an unregistered seat plays; `anchor` is the other scripted name.
Two shipped champion prompts, `physics-bodies-ringcraft` (win on
position) and `physics-bodies-toppler` (win on knockdowns), live in the
game repo's `tools/ci/policies.json` and are quoted in docs/orders.md.
Our policy **Kolobok Jr** (`kolobok_jr/kolobok_jr.nim`) is a Nim prompt
seat over the Sprite v1 BINARY protocol: one 0x81 chat packet carrying
`{"type":"register","prompt","scripted","policy"}`, re-sent on a bounded
schedule for ~10 s (the lobby holds an unappliable registration), then a
0x85 Ready byte per received frame to pace fastMode. The prompt merges
both champions and adds match-state control: rim-emergency retreat under
0.60 m, brace above 55% tilt, the all-in aggression-10 charge only on
contact with a foe under 0.90 m of rim, charge tottering/downed bugs,
brace incoming chargers (a four-leg plant takes zero recoil), otherwise
circle for rim position, centre after the shrink when ahead, and
aggression discipline at 2-0 up. `PLAYER_PROMPT` overrides,
`PLAYER_SCRIPTED=pusher|anchor` fields a baseline. NO upload
secret-envs: llm.nim and the anthropic_api_key secret live in the GAME
pod (docs/readme.md) — the seat sends no inputs at all.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Threshold sweep on the all-in trigger: 0.90 m rim + contact is the
  ringcraft champion's number; try 1.10 m (earlier commitment) vs 0.75 m
  (safer) against the pusher baseline and the toppler prompt.
- Add an explicit anti-lift counter: when the foe's stance last turn was
  lift (visible as it closing under posture high->low with low speed),
  order retreat one step then charge — lift loads self-tilt and a missed
  lift is a free shove window.
- Circle direction from spin: circle_dir opposite the foe's spin sign
  should gain angle faster; the view carries both spins, wire it into
  rule 6.
- Knockdown farming variant: swap rules 3 and 4 (prefer lift at high foe
  tilt over rim pushes) and measure round wins by knockout vs ring-out —
  +0.250 bonus is identical, but knockouts avoid rim-guard risk.
- Late-round centre discipline: rule 7 currently keys on the shrink
  clock; add "when both tallies equal and under 4 s left, centre at
  aggression 4" — decisions go to whoever is closer to the centre.
- Trim the prompt under 2000 runes (cap is 4000): shorter rule lists
  reduced fallback turns in other cogames' order parsing.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Rule 4 taught a false physics fact: "tottering (tilt_pct>55) or prone cannot shove". Only down_ticks>0 cannot shove (sim.nim: effort=0 iff down). Charging a tottering-but-upright plant is the judo victim vs league leader `centre-judo-richard` (MMR 1125, wr 0.76) and vs ringcraft (we are 1-4). Restrict the all-in to actually-down bugs; spend the 1.5 s window at aggression 10 / lead_ticks 0 (toppler's documented free-push). Tottering-upright falls through to brace/circle. | Rule 4: charge only if foe down_ticks>0, aggression 10, lead_ticks 0; drop the tilt_pct>55 charge. | | | |
