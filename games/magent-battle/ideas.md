# Magent Battle — Chernomor

Policy: **Chernomor** (`chernomor`) — commander of the thirty-three bogatyrs — mass battle.

Coworld: `cow_da8b1057-4a00-4492-a7b8-ccc155a517bf` (coworld name `magent-battle`)

A port of MAgent2's battle_v4. Two armies of 81 identical soldiers meet on an open 45x45 integer grid. Nobody plays a soldier: each of the two seats is an ARMY COMMANDER that issues one order to each of its nine squads every 20 simulation ticks, and a deterministic squad controller turns those orders into the MAgent actions its soldiers actually take. A commander sees only what its own soldiers can see. The army with more soldiers standing when the game ends wins it; an episode is two games with the sides swapped, so upstream's own two-column spawn asymmetry is neutralised, and the seat that wins the pair wins the episode. Scoring is exactly zero-sum.

## Leagues

- `league_b56ff3be-1f0f-4b2a-b2e7-c44d17839134` — Magent-Battle

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `pincer` — magent-battle-pincer: The published scripted default and the server-side fallback: squads below 4.0 mean hp retreat to heal, squads with a visible enemy centroid within 3 cells focus it, and the rest split into a left wing, a centre and a right wing. (run: `/bin/magent-battle-player`)
- `line` — magent-battle-line: Every squad advances, every turn, forever. A mass charge beats a badly split commander, so it is a real opponent and the control against which a commander is measured. (run: `/bin/magent-battle-player`)

## Baseline

Default example: `pincer` (scripted; also the server-side fallback and
the no-show driver - retreat under 4.0 mean hp, focus within 3 cells,
three-wing split). `line` is the mass-charge control. Our `chernomor`
is a thin Nim seat registrar speaking the bitworld sprite protocol: one
0x81 chat frame with {"policy","prompt","scripted"}, re-sent for the
first ~10 s (slot-sequential joins), then receive-only, exiting 0 on a
dead socket. The prompt is concentration doctrine: keep all nine squads
one fist (nine soldiers kill in one tick, one takes five), never order
advance (each soldier homes to its own nearest enemy and the blob
scatters), flank left together so they share one target, focus-fire
the weakest visible enemy squad and re-target as they die, wrap with
exactly two rear squads once locked, retreat any squad at mean hp <= 4
to heal (0.1/tick), never chase, and bank a won game by retreating
everything in the last 60 ticks. Env overrides: PLAYER_PROMPT,
PLAYER_SCRIPTED (line|pincer). NO Bedrock flag: decisions are made
inside the game server, which holds the anthropic_api_key secret.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Beat line first: a full-line charge against our fist tests whether focus-fire alone out-trades an equal mass; if not, add a refuse-the-flank clause (hold squads 1-3 back-left, overload right) and re-run.
- Target-selection metric: lowest hp x alive vs nearest vs isolated-squad preference; the controller's focus order already prefers members of the named squad, so isolating stragglers may out-trade shooting the weakest.
- Retreat threshold sweep: pincer retreats under 4.0 mean hp; our prompt matches it - test 3.0 (fight longer, fewer rotations) and 5.0 (rotate early, always healthy) against pincer on hosted XP.
- Bank-the-win window: 60 ticks (~3 turns) of end-game retreat concedes board position; measure in replays whether pincer punishes it, and shrink to 40 if the differential drops.
- Fog probing: when nothing is visible the prompt advances toward last-seen; test a fixed opening (flank left with 8-9 to widen initial vision) against the default straight advance - upstream's spawn asymmetry may reward one wing.
- Order-churn discipline: unmentioned squads keep orders; measure ordersRejected/llmTurns in results and tighten the prompt's reply-format section if repairs show up.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | never order advance (controller scatters the fist) | doctrine 1+7: `advance` homes each soldier to its own nearest enemy, so the 9-squad blob arrives as a line and loses local numbers to vanguard's 6-squad same-target flank/focus; all nine `flank left` instead so they share one target cell | | | |
