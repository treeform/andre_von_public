# Variants

All four variants are the same simulation with a different capture predicate
and a little per-variant furniture. `num_agents` is 6 in every one.

## `staghunt` -- 3 rounds x 960 ticks

The base world, unchanged. Capture rule `sides`.

## `coop-mining` -- 3 rounds x 960 ticks

No animals. 18 iron nodes and 8 gold nodes, immobile, respawning on the same
60-tick cadence at random free tiles.

- **Iron:** one adjacent hunter on any side -> +1 score / +10 energy.
- **Gold:** two *different* hunters on any two sides **within a 3-tick
  window** -> +8 score / +40 energy each.

The window is the only new mechanic: the sim stamps `sideSeen[side] = (tick,
slot)` and a side counts as occupied while `tick - sideSeen.tick <=
windowTicks - 1`. `windowTicks = 1` reproduces base staghunt exactly, so the
base game runs through the same code path.

## `lbf` -- Level-Based Foraging, 3 rounds x 960 ticks

Each seat gets `level = 1 + (slot mod 4)`, drawn as a digit over its head.
Food items carry `level` 1..6, drawn the same way, with 14 items maintained.
A pickup succeeds when the sum of the levels of the hunters cardinally
adjacent to the food is at least the food's level.

Reward: `score = 2 x level`, `energy = 20 x level`. Score is **split**: each
participant gets `floor(score / n)` and the integer remainder goes to the
participant with the lowest slot. Energy is not split.

## `predator-prey` -- 4 rounds x 720 ticks

No animals. Seats split by role each round:
`role = hunter if (slot + roundIndex) mod 2 == 0 else forager`. With six seats
and four rounds every seat hunts twice and forages twice, so the asymmetry
cancels in the ranking.

40 berry tiles and 120 tall-grass tiles are placed from the seed. A forager
standing on a berry tile consumes it at end of tick (+1 score, +12 energy;
the tile regrows after 90 ticks). Two hunters on opposite cardinal sides of a
forager tag it: +6 score each, the forager loses 30 energy and respawns 24
ticks later near the map edge.

**Tall grass hides foragers:** a forager on a tall-grass tile is not drawn in
a hunter's per-seat frame unless that hunter is within Chebyshev distance 2.
It is always in the global/replay stream, and the viewer carries a grass
opacity toggle -- the spectator sees the ambush the hunter could not.
