# Emerg Ant — Zlydni

Policy: **Zlydni** (`zlydni`) — a swarm of little spirits.

Coworld: `cow_db246875-b62a-4ac8-ae63-8431dc8c9315` (coworld name `emerg-ant`)

Emerg-ant is a 1v1 artificial-life colony duel. Each submitted policy controls a colony of connected copies: a fixed winged queen and seven workers start alive by default, with eight more copies waiting as brood. Every ant smells eight randomly replenishing neutral fruit patches, and each delivery to the queen hatches another copy. Ants select scout, food, danger, or home pheromones and an emission rate from off through urgent. There are no guns or items: rivals fight only by physical contact, and killing a queen collapses her colony.

## Leagues

- `league_485b7b0a-5a52-4254-9b2b-1e10b9596941` — Emerg-ant

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — baseline: Reference bot image used for Coworld smoke certification. (run: `/bin/baseline`)

## Baseline

- Only example: `baseline` (`/bin/baseline`, opaque in the image). Its source is
  `players/baseline/baseline.nim` in github.com/Metta-AI/coworld-emerg-ant (the CTF reference
  bot; emerg-ant mode is its `decideEmergAnt` branch, selected when the own-weapon HUD label is
  `weapon mandibles`).
- **Zlydni ports `decideEmergAnt` to a standalone Sprite v1 client** (bitworld/spriteprotocol +
  whisky, labels only, Sprites Off 0x87 on connect): carriers run food home (food pheromone
  urgent), free workers chase the nearest map-wide `food patch` scent, no-scent ants run the
  slot-staggered boustrophedon sweep, the queen sits still, bites contacts, and marks danger.
  Two upgrades over the reference: nest position is LEARNED (own-queen sighting, spawn-point
  fallback) instead of the CTF flag-room constant, and steering follows a BFS distance field on
  an 8 px walkability grid (reference uses a full nav/cost-field; ours is a compact equivalent)
  so ants path around walls.
- Protocol confidence: high — PROTOCOL.md + RULES.md + EMERG_ANT.md + the full baseline source
  were read. Gotchas honored: never send Player Ready 0x85 in league play (measured accuracy
  collapse), C is edge-triggered with a release frame, inputs are level-based (send only mask
  changes, drain the frame backlog and act on the latest), map-camera object id 1 gates
  in-game vs lobby. Uncertainty: whether the server still ships walkability pixels under
  Sprites Off — if not, the bot degrades to direct steering + stuck-kick (same as pre-nav
  reference behavior).
- Upload: no secret-envs (scripted bot, no LLM).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Target claiming: all free workers chase the SAME nearest patch; hash slot -> k-th nearest
  patch (or spread by patch distance ranking) so eight ants fetch eight different patches.
- Read our own food trails: pheromone marks are public (`pheromone <color> food rate <n>`);
  a no-scent ant should walk our freshest food trail instead of the blind sweep.
- Trail sabotage: a fresh mark erases enemy trail within 18 px; send one dedicated ant to
  overwrite the enemy's food-route marks near THEIR nest approach.
- Queen-rush mode: killing the enemy queen collapses the whole colony; when we lead on food
  and outnumber them, send 2-3 workers (hold A in contact) at the enemy nest position
  (mirrored nest estimate, or danger-pheromone cluster).
- Danger avoidance for carriers: add a repulsion term from visible enemies and fresh enemy
  danger marks to the BFS steering so deliveries route around ambushes.
- Brood tempo: first deliveries hatch dormant copies (16 per colony); early game should
  hard-prioritize the closest patches to snowball worker count before contesting.
- Escort the queen: keep exactly one worker parked at the nest as a bodyguard once the enemy
  has been seen on our half (queen bites do 1 damage but she can be swarmed).
- Own-half preference: at equal distance prefer patches on our side of the map — shorter
  return legs and less enemy contact per point.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Target claiming | Free workers no longer all chase the same nearest `food patch`. Patches are ranked by nest distance (colony-shared) and each seat claims a distinct k-th patch, rotated so seat 0 (typical queen) gets the farthest and the seven starting workers cover the seven nearest. A patch within 64 px is grabbed opportunistically (first-touch scores). | | | |
