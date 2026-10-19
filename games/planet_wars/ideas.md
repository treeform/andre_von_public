# Planet Wars — Zvezdochet

Policy: **Zvezdochet** (`zvezdochet`) — the astrologer of the Golden Cockerel — stars.

Coworld: `cow_451d9eae-7ef0-4a17-b025-4ab7d48ac315` (coworld name `planet_wars`)

A BitWorld strategy game where players conquer planets and launch ships across a tiny star map.

## Leagues

- `league_074c818a-fe56-42a4-a2de-1a79202f281a` — Planet Wars

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `skurge` — Skurge: Planet Wars attacker that ranks every source and target on the board each tick and clicks the best affordable capture. (run: `/bin/skurge`)

## Local baseline

~/p/coworld-planet-wars (submit-tournament branch) — our tournament bot; skurge is the platform base.

## Baseline

- Platform default/example: `skurge`, the bundled attacker that ranks
  every source and target each tick and clicks the best affordable
  capture.
- The league runs game version 0.2.1, the MOUSE-control redesign (full
  map visible, click source then target, number keys set send
  percent). The old submit-tournament and master branches of
  ~/p/coworld-planet-wars hold d-pad-era bots (incl. `kudzu`) that
  speak the wrong input protocol for 0.2.1; ~/p/planetwars is a local
  sim AI with no sprite protocol at all. The strongest 0.2.1 source is
  `players/skurge/skurge.nim` on the `waiting-for-players` branch
  (tip d406f09): phase machine (opening pool -> big planets -> snake)
  that sweeps all 47 planets on 6 of 6 benchmark maps in ~70s.
- Zvezdochet is a straight port of that bot with the bitworld and
  game-source dependencies inlined; deps are whisky + supersnappy
  only.
- Command player: no upload secret-envs needed (no LLM seat, no
  USE_BEDROCK).
- **Qualification gate**: a submitted policy only becomes champion
  after a self-play episode (8 identical clones) where one seat ends
  owning all 47 planets — one failure disqualifies immediately, and
  `max_attempts` does not grant retries. A bot that merely beats the
  field but cannot wipe its own clones never plays a round. The
  verdict text lands in the membership `notes` field, not the
  episodes API. The 47/47 solo sweep is why this port should clear
  it.
- Score is ownedPlanets^2 per second; ships contribute nothing
  directly. Neutrals never regrow; owned planets grow 1 ship per
  interval (faster for larger planets).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Anti-clone opener for the gate: in self-play all 8 seats run the
  same opening; bias the first captures away from the map centroid
  (seeded by starting planet position) so clones do not contest the
  same neutrals and stall the wipeout.
- Enemy-stream awareness: the bot estimates garrison growth but not
  inbound enemy waves; track enemy ship sprites heading at a target
  and add them to the capture cost so bursts stop landing one wave
  short.
- Defense reflex: when an enemy wave is inbound at one of ours, the
  snake keeps expanding; try a reinforcement send from the nearest
  fat planet when the defender's garrison is below the inbound count.
- Percent granularity: FleetPercent=100 sends everything; late game a
  90% send from the stack often funds the same capture while leaving
  a seed garrison — sweep FleetPercent 80/90/100 against the live
  field.
- Solo-sweep speed came out economy-bound, not travel-bound (repo
  experiment log): try capture-order scoring by growth-rate-per-ship
  (prefer planets that grow faster sooner) instead of pure
  cost-plus-distance.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
