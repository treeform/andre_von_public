# Minecraft — Zodchiy

Policy: **Zodchiy** (`zodchiy`) — the master builder.

Coworld: `cow_8b94b3fa-1fdd-4cc4-b746-829f4daaee67` (coworld name `minecraft`)

Minecraft, in spirit: one cog alone in a seeded blocky world of four stacked 32x32 levels - surface, stone, iron depth, diamond depth - and the eleven-rung MineRL ObtainDiamond ladder to climb before the clock runs out. log -> planks -> crafting table -> wooden pickaxe -> cobblestone -> stone pickaxe -> iron ore -> furnace -> iron ingot -> iron pickaxe -> diamond. Each rung is worth double every rung beneath it put together, so getting ONE rung deeper beats any combination of the rungs below and the score is exactly the eleven-bit milestone mask times a thousand, with speed as the tie-break. The cog descends by cutting a shaft through the floor and climbs back the same hole; it sees 11x11 on the surface and only 5x5 underground, and a level it has never been to is entirely unknown. Nothing is hunting it, it never eats or sleeps, and the only lethal thing in the world is lava - which kills on a step but not on a blind dig_down. A policy sends up to twelve actions a turn from seventeen primitives and three macros (goto, move, tunnel); a deterministic driver expands them into at most twenty ticks. This is an in-spirit reimplementation of the ObtainDiamond problem as its own deterministic seeded simulator - no Malmo, no MineRL, no MineDojo code is vendored and no score here is comparable to a published benchmark number (see docs/PORTING-MINECRAFT.md).

## Leagues

- `league_390fe9da-f2a6-4001-93df-e08cc2788846` — Minecraft

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `miner` — miner: The published scripted baseline: a deterministic priority ladder that crafts what it can afford, chops the nearest known tree, walks to the best known ore it has the tier for, digs down the moment a level has nothing left it needs, and otherwise cuts straight branch-mining corridors on a three-row lattice. It never routes through lava and never walks back up a shaft. It is also the server-side fallback when an LLM seat times out twice. (run: `/bin/minecraft-player`)

## Baseline

`miner` is the published scripted baseline (priority ladder: craft what is
affordable, chop nearest tree, walk to best known ore, dig down when a level
is spent, branch-mine on a three-row lattice) and the server-side fallback
after two LLM timeouts; `scrounger` also exists in the image. A policy here
is JUST A PROMPT: the seat sends one Sprite v1 chat frame (0x81) carrying
`register` and then only acknowledges with Ready (0x85); the GAME container
holds the anthropic_api_key and computes every primitive.

**Zodchiy** (`zodchiy/`) is a prompt seat on the alyosha Sprite v1 pattern,
with registration re-sent ~1 s apart for the first ten seconds. The prompt
is a depth-first ladder plan with exact material budgets (6 logs for two
tables, 8 sticks for all three pickaxes, 12+ cobblestone for pickaxe +
furnace), a 2-3 turn surface cap, per-level workshop placement, the lava
asymmetry (never step on visible `!`, blind dig_down is safe), and
always-fill-the-20-tick-turn discipline.

Upload secret-envs: none — the game pod holds the LLM. If a league round
shows the seat silently playing miner, retry with USE_BEDROCK=true.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Coal skip test: iron needs coal to smelt, but is detouring for z1 coal
  slower than grabbing coal on z2 (80‰ there) where iron already is? Two
  prompt arms, same seeds.
- Turn-budget checkpoints in the prompt: "wooden pickaxe by turn 4, stone by
  turn 12, iron by turn 30, else abandon side-quests" — hard deadlines beat
  soft priorities for LLM drift.
- Lattice direction from region: steer branch corridors toward the biggest
  `?` sector of the 16x16 region map instead of always east.
- deepcut variant arm: 32 turns and par 5 reward a leaner script — drop the
  second table, smelt exactly 3, place the furnace next to the z2 shaft.
- notes schema discipline: a fixed one-line format ("z2 shaft(x,y) tbl(x,y)
  fce(x,y) lava:(x,y),(x,y) plan:...") — malformed notes are how multi-turn
  plans decay.
- Single-tree opening: 3 logs = 12 planks covers pick + table + sticks with
  none spare; test if skipping the second tree (and the z1 table) is worth
  two turns against the risk of re-surfacing.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
