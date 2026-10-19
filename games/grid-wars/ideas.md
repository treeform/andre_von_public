# Grid Wars — Perun

Policy: **Perun** (`perun`) — god of thunder and war.

Coworld: `cow_f009d83c-de26-4ab4-8e56-742cbdb4a124` (coworld name `grid-wars`)

Grid Wars: Core Wars on a 30x30 toroidal grid, for four LLM-piloted cogs. A seat does not move a warrior - it WRITES one. Every round all four seats simultaneously submit a complete program in GWL, a small Nim-like, integer-only DSL (check(dx,dy), who(dx,dy), move, place, bomb, wait, while/if/for/proc), the four scripts are sealed and compiled, and the engine fights them for up to 400 ticks on an empty board. Tiles are claimed by standing on them and calling place(); bombs cost energy, are walls for five ticks and then scorch a plus of five cells, chaining into any bomb they touch; corpses are permanent walls; 50 ticks without moving kills you; and a fault - a divide by zero, an index out of range, an undefined name - kills you on the spot with the line number reported back to you before the next round. When a warrior dies every tile it owned reverts to unclaimed, so elimination is decisive and the board visibly un-paints. Scoring is symmetric zero-sum: raw = tiles + 100 if alive + 50 per kill - 50 per self-kill, and a seat's score is its mean deviation from the four-seat average, so the four scores sum to zero. Seats see the board, never each other's code. The game is LLM-driven and A POLICY IS JUST A PROMPT: field one by reusing the published grid-wars-player runnable with PLAYER_PROMPT set to your strategy. Three scripted warriors (painter, bomber, sentry) play any seat that registers as scripted - and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_f07f6eeb-bdd2-49ec-82bd-a3fa2bb568e5` — Grid Wars

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `grid-wars-player` — Grid Wars Prompt Player: The reference Grid Wars policy: delivers its PLAYER_PROMPT (or a default warrior-writing strategy in words) to the game and spectates until the final frame. The game server turns the prompt into a warrior program every round. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/gridwars-player`)
- `grid-wars-painter` — Grid Wars Painter Baseline: The scripted spiral painter as a fieldable policy: registers its seat as rule-based so the game server plays the built-in painter warrior deterministically, no LLM involved. It claims every cell it stands on, turns away from walls, and bombs a rival that steps next to it. (run: `/bin/gridwars-player`)
- `grid-wars-bomber` — Grid Wars Bomber Baseline: The scripted aggressive baseline: mines the ground it leaves every third action, fencing itself in and painting inside the fence. Fewer tiles than the painter, far more chain reactions. (run: `/bin/gridwars-player`)

## Local baseline

~/p/gridwars — our nimmy interpreter + decoded rules from dkrause.org.

## Baseline

- Default example: `grid-wars-player` — the reference prompt seat with a
  generic warrior-writing prompt. `grid-wars-painter` and
  `grid-wars-bomber` field the scripted built-ins; of the three shipped
  warriors painter out-paints, bomber trades tiles for chain kills, and
  sentry is the always-legal fallback every LLM seat is shown round 1.
- Strongest available knowledge: ~/p/gridwars, our lab for the
  dkrause.org original. Its ladder put raster painters on top (honest
  `sweeper` beat every example warrior ~94% 1v1); the two stronger
  entries above it were VM exploits the coworld engine's design
  (actions suspend the VM, 2000-instruction stall rule) already
  neutralizes. The coworld GWL also differs materially: one-step moves
  only (no teleports), a 9x9 vision window with FOG, one action per
  tick — so scripts do not port, doctrine does.
- Perun: prompt seat on the anchutka pattern. The embedded prompt IS
  the policy: round 1 copies a complete skip-owned spiral GWL warrior
  (painter run==22 so the torus does not loop one column; place only
  when check(0,0)!=ID; diagonal flee after bomb). Later rounds patch
  faults from diagnostics, do not rewrite.
- Upload: MUST pass `--secret-env USE_BEDROCK=true` or the seat
  silently plays scripted. `PLAYER_PROMPT` overrides the prompt and
  `PLAYER_SCRIPTED=painter|bomber|sentry` fields a built-in, so one
  image serves prompt A/Bs and scripted controls.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

1. Ship a complete round-1 script inside the prompt (an exact GWL
   serpentine painter, line by line) instead of a described one: removes
   round-1 authoring variance and compile-retry risk, and rounds 2+
   become pure patching. A/B against the descriptive prompt.
2. Anti-bomber trail-head rule from sweeper: before stepping onto a
   cell, if its sweep-backward neighbour is enemy paint and the cell
   ahead is empty, a row-walking bomber is probably standing there —
   sidestep a row early. Encode as one extra elif and measure deaths
   per series.
3. Corner-band sizing: the four spawns are fixed, so a ~15x15 home
   quadrant never contests spawn-adjacent ground. Test 12-wide vs
   15-wide vs full-board sweep bands for tiles at horizon and death
   rate against hunty fields.
4. Fence-kill play: when diagnostics show a rival repeatedly adjacent,
   switch one round to a lure-and-fence script — retreat through a
   corridor of our paint, mining it on cooldown, since a kill also
   un-paints the victim's whole territory in zero-sum scoring.
5. Idle-rule griefing resistance: stalls count as wait() — keep the
   per-tick decision under ~200 VM instructions (no big scans), and
   verify via the stalls diagnostic that we never burn the 2000 budget.
6. Notes-driven meta across the series: persist per-alias aggression
   (bombs seen near us, kills in the series table) and pick script
   variant round-by-round — painter into passive fields, fence-miner
   into hunters, pure-survival shuffle when holding a big round lead.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Ship a complete round-1 GWL warrior: the torus has no walls so a described column-sweep with "flip at band edges using y()" loops one column (~30 tiles) unless it counts steps; Haiku-authored serpentines also drop the run counter and trail-mine (scorch) own paint. Exact script: painter spiral (run==22) + skip owned + diagonal bomb-flee, submit unchanged round 1. | defaultPrompt: replace the 8-point English serpentine with a compiling skip-owned spiral warrior and "submit unchanged; patch faults only" | | | |
