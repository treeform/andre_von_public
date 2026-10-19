# Cooperative Hunting Rules

Six hunters share a 32x32 tile forest (12 px tiles). The border ring is rock;
11 % of the interior is obstacles, half tree and half rock, with a 7x7 block
at the centre and six random 3x3 blocks cleared. The map is generated once per
episode from `seed`; each round re-rolls the animals with `seed + roundIndex`
but keeps the same map.

## Hunters

Start at a free tile within 4 tiles of the centre with `energy = 120` and
`score = 0`. Energy caps at 200; passive recharge is +1 every 18 ticks but
only up to 100. Moving costs 2 energy and sets a 5-tick move cooldown. A
hunter with fewer than 2 energy cannot move. There is no elimination and no
negative score.

## Capture

| animal | hunters needed | sides | score | energy |
| --- | --- | --- | --- | --- |
| rabbit | 1 | any one side | 1 | 15 |
| boar | 2 | two perpendicular sides | 3 | 90 |
| stag | 2 | two opposite sides | 5 | 60 |
| moose | 3 | any three sides | 10 | 140 |
| elephant | 4 | all four sides | 18 | 220 |

The reward is paid **in full to every participant** (except in `lbf`, where
score is split). A capture leaves a corpse for 48 ticks and puts a 20-tick
yellow kill glow on the killers.

## Animals

Populations are maintained per kind, and a kind only spawns once the connected
seat count is at least its coalition size: rabbits 12, boars 6, stags 6, moose
3, elephants 2. Spawns are 60 ticks apart, dropping to 3 while a population is
four or more below target.

Animals flee within Chebyshev distance 3, at 75/50/25 % by distance, scaled per
kind. A moose cardinally adjacent to a hunter gores it 30 % of the time (5 %
diagonally): -10 energy and a one-tile shove. An elephant that steps onto a
hunter tramples it for -30 energy and slides two tiles through -- and if the
far tile is blocked it stays put, which is exactly why a complete four-side
ring can hold one.

## Turn order

Each tick, in this order: ingest input; distribute plans; hunter phase in slot
order; animal phase in prey order; stamp occupied sides; resolve captures;
resolve tags and forages (`predator-prey`); housekeeping; emit frames; round
bookkeeping; deadline guard.

## Ending

`results.reason` is one of exactly three values: `complete` (all rounds ran),
`deadline` (the wall-clock guard fired; the current round is scored as it
stands and the episode settles), or `no_players` (nobody connected inside the
connect timeout; all-zero scores). The game always exits 0.
