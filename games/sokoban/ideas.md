# Sokoban — Gruzchik

Policy: **Gruzchik** (`gruzchik`) — the warehouse porter.

Coworld: `cow_71631422-adaa-43fd-b234-5f1aa8a08b43` (coworld name `sokoban`)

SA Sokoban: one cog alone in a 10x10 walled room with four crates and four marked squares. It can walk, and when it walks into a crate the crate slides one square ahead of it. It can NEVER pull. A crate shoved into a corner is there forever; two crates shoved side by side against a wall are there forever; the level is over the instant the position becomes unwinnable, and the replay says so out loud with a DEADLOCK CREATED marker on the scrubber. An episode is a ladder of six levels, each generated fresh from the episode's secret seed by reverse play from the solved position, each labelled with the tier it was built to (unfiltered, medium, hard) and its EXACT optimal push count, each with a hard budget of 200 moves. Sokoban is PSPACE-complete and has no useful local signal: there is no gradient toward the goal, and the difference between a solved level and a dead one is usually a single push made in the wrong order. The league reads one number: the tier-weighted count of levels solved, with crates parked as the tie-break and moves saved as the tie-break after that.

## Leagues

- `league_81761ec5-88ed-4a94-b9b5-89d8b93b90fe` — Sokoban

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `pusher` — pusher: The reference Sokoban policy: a bounded best-first search over push space that prunes every deadlocking successor, matches crates to marked squares greedily and re-plans from scratch every turn. Same image as the game, selected with PLAYER_SCRIPTED=pusher. (run: `/bin/sokoban-player`)

## Baseline

The only published example is `pusher`, a bounded best-first search over
push space that prunes deadlocking successors — the same image as the game,
selected with `PLAYER_SCRIPTED=pusher` (a weaker `nudger` also exists in
the image). `pusher` is also the fallback that drives a silent seat. The
seat is a **prompt seat**: the player container registers one Sprite v1
binary chat blob (`{"policy", "prompt", "scripted"}` — note: NO "type"
field, unlike the other cogames) re-sent for the first ~10 s, then only
listens to JSON `welcome`/`turn`/`done` text frames.

**Gruzchik** (`gruzchik/`) embeds a crafted operator prompt: plan the whole
level before the first push, order boxes so no parked box blocks a later
approach, check every landing against `dead_squares`, freeze-block and
wall-run rules, use `opt_pushes` as a plan sanity check, and park boxes for
credit only when the level is truly dead. Upload secret-envs: **none
needed** — the `anthropic_api_key` secret lives in the game pod; no
USE_BEDROCK (docs/actions.md says so explicitly), prompt compiled in.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Beating `pusher` (a real search) with a prompt is the open question:
  try a prompt that emulates retrograde analysis — reason from targets
  backward ("which box must land LAST on this wall-run target?").
- Add an explicit corridor rule: a box between two parallel walls can only
  travel along the corridor — commit it to the target on that line first.
- Turn-1 budget experiment: allow one pure-planning turn (empty actions,
  full notes plan) on hard-tier levels only; measure whether the 20 lost
  moves pay for fewer deadlocks.
- Encode the "never push into a square whose opposite side is
  wall-adjacent-to-wall" 2x2 pre-check as a numbered checklist item — the
  model skips prose caveats under pressure.
- Tie-break farming: when solved-weight is capped by a dead hard level,
  instruct re-walking cheap levels' saved moves (moves_left) harder —
  verify movesSaved actually moves league rank before spending prompt on
  it.
- Try naming the box-target assignment as a bipartite matching by
  Manhattan distance with conflicts resolved by push-path overlap, and see
  if the model follows the recipe more reliably than freeform planning.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
