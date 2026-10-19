# The four modules

Each module is one `game_config.module` value: the same institutions, different resource physics.

## `cleanup` — Clean Up

One apple stock (starts 60, capacity 100) and one river. `harvest` takes apples; `clean` clears
silt. Apples regrow by `0.35 x (1 - pollution) x apples x (1 - apples/100)`. Pollution rises 0.12
every round and each clean unit removes 0.05, so holding it steady costs 2.4 units a round —
13 % of the society's whole effort, permanently, paid by whoever volunteers. Below 10 apples the
orchard is dead forever. Cleaning pays the cleaner nothing.

## `harvest` — Commons Harvest (open / closed / partnership)

Six patches, each up to 20 apples, starting at 12, regrowing at 0.40. Name one `patch`, demand
`harvest` from it. A patch left with less than one apple is DEAD FOREVER. Sustainable is 2.0 per
patch per round against a cap of 3 per cog — the temptation is exactly one unit wide.

- `open` — anyone may name any patch.
- `closed` — one patch per cog, publicly assigned; a demand by a non-owner yields nothing.
- `partnership` — two patches per pair, publicly dealt; a patch pays only if BOTH partners name
  it this round (either may demand 0 — naming it is holding it).

## `allelopathic` — Allelopathic Harvest

Sixty plant slots in red, green and blue, starting 20/20/20 with 6 ripe of each. `eat` ripe
berries of a colour, `plant` to convert a slot from the largest other colour. Each colour ripens
by `0.5 x planted^2 / 60` — quadratic in its own share, which is the inhibition: an even split
yields 10 berries a round for six cogs with 18 units of demand, a monoculture yields 30. Every
cog has a SECRET favourite colour that pays it 2.0 instead of 1.0, exactly two cogs per colour.
The good outcome needs four of six to eat a colour that pays them half as much.

## `mushrooms` — Externality Mushrooms

Red, green and blue mushrooms, 8 of each, three new ones a round weighted by what has been
eaten. Red pays +1.0 to the eater. Green pays +2.0 split among all six. Blue pays +3.0 split
among the five who did NOT eat it — the eater gets nothing. Eating k mushrooms freezes you for
k rounds. Blue is worth three times red to the group and nothing at all to you.
