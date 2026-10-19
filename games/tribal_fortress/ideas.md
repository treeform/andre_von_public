# Tribal Fortress — Usynya

Policy: **Usynya** (`usynya`) — the giant who dams rivers with his moustache — fortifications.

Coworld: `cow_9e96eb8e-33f8-4c6a-803f-5638d89a9af7` (coworld name `tribal_fortress`)

One shared Tribal world with strategy and adventure leagues that scale from two to eight entrants. Both modes run the same native Fortress simulation revision.

## Leagues

- `league_e5a2e816-7b65-41f5-9ff0-e74ada0d9d3d` — Tribal Quest
- `league_37dc6573-071c-4c6b-a6c5-301a006ad20b` — Tribal Fortress

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `tribal-player` — Universal Tribal Player: A certification player that detects the Fortress JSON or Quest binary protocol and takes deterministic legal actions. (run: `python -m tribal_fortress_env.coworld.player`)

## Baseline

The only example is `tribal-player` (Universal Tribal Player), which is both
the default and the strongest — a certification command player, not an LLM
seat. Its actual behavior (player.py at pinned rev f0e3202):

- Quest (`quest-N-adventurer`, binary sprite protocol): answers every binary
  frame with a 2-byte `0x84`+mask packet running a deterministic dance —
  12-tick phases (right, right, down, left, left, up), `select` every 9
  ticks, `A` every 37. Score = survival_ticks + 10 * explored_tiles.
- Fortress (`fortress-N-town`, JSON): its "overseer" branch reads
  `visible_buildings` from observations — but the non-render bot socket
  never includes that field (server.py `player_observation`), so the example
  is effectively PASSIVE in fortress mode and the town plays its built-in
  default programs. Score = per-tick tint-owned territory tiles.

Our policy `usynya/` is the Nim rewrite plus one real upgrade: after
detecting the fortress surface from the first JSON observation it reconnects
with the documented `&render=1` opt-in, reads `visible_buildings` from
`view.init`/`view.delta`, and keeps military buildings (barracks,
archery_range, stable, siege/mangonel/trebuchet workshops, monastery,
castle) on program 3 `fighter_aggressive`, town_center on program 4
`settler_expand`, and remaining policy buildings (dock) on program 0
`gatherer_default`. One `town.set_program` in flight at a time;
errors blacklist the building. `USYNYA_RENDER=0` forces exact-example
passive behavior. Quest dance is ported verbatim.

Upload: no secret-envs required (command player, no LLM seat).

Protocol confidence: high — read from `player_protocol_spec.md` and the
pinned server.py/player.py sources (fetched via `gh api`; the repo is
private, raw.githubusercontent 404s). Residual uncertainty: whether the
hosted runner's URL tolerates the `render=1` reconnect race (we retry, then
fall back to the passive bot socket), and the quest surface's exact frame
cadence (we simply answer every binary frame, like the example).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Fortress: set town_center to program 4 `settler_expand` instead of 0 —
  score is territory tint, so expansion may beat pure economy.
- Fortress: keep a couple of military buildings on program 2 `fighter_guard`
  (home defense) instead of all-aggressive, protecting territory tint from
  raids while others attack.
- Fortress: author a custom behavior via `town.save_behavior` /
  `town.save_program` (the DSL is Python-shaped, interpreted in Nim) that
  prioritizes territory expansion — e.g. builders that favor
  `defense=True` sites toward the map center.
- Quest: replace the fixed dance with a wall-following / spiral explorer
  driven by the sprite frames (decode the local view instead of ignoring
  it) to maximize unique explored tiles; survival ticks dominate early,
  exploration (x10) dominates score.
- Quest: avoid death — bias movement away from goblin/NPC agents when the
  sprite frame shows adjacent hostiles; a dead adventurer stops scoring
  entirely.
- Fortress: parse `stockpiles` from view.delta and switch programs by game
  phase (gather-heavy early, aggressive after a resource threshold).
- Use `town.select_citizen` to rotate the 11x11 PiP view over citizens and
  build a coarse threat map that informs program switches.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| - | fleet/triage candidate v2 | see git history | triage batch | paired vs champion | REVERT: 7723->6879 t=-1.18 |
| 1 | Town-center settlers for territory tint. Score is per-tick count of tint-owned non-water tiles (agents r=2, lanterns r=2); more pop and more TCs paint more tiles for more ticks. Engine default for town_center is builder_default (1) — houses + DesiredTownCentersPerTeam=4. We were forcing gatherer_default (0), locking new TC villagers as gatherers (`programRevision>0` skips role rebalance). daveey `castellan` beat us last round 6.47M vs 5.17M; likely kept the builder/expand TC path. | `desiredProgram`: town_center 0→4 `settler_expand` (Builder role + BehaviorSettlerMigrate first; military stays 3, dock stays 0). Pinned sim still f0e3202. | | | |
