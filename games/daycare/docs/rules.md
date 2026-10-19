# Daycare rules

## The yard
A fixed 24x14 grid, 48 board px per cell, inside an impassable fence ring. Eight TALL TREES (4 apple, 4 banana) and 2-4 SHRUBS (half apple, half banana) are impassable; a four-cell woven BASKET MAT in the middle is walkable and fruit resting on it never rots. The layout is species-congruent by construction: the reflection x -> 23 - x maps the apple source set exactly onto the banana set, and a mirror bit drawn from the layout RNG decides which species sits nearer the spawns, so no species is favoured and 'apples live on the left' is not a learnable prior.

## Who can harvest what
| source | capacity | initial ripe | regrow | parent | child |
|---|---|---|---|---|---|
| tall tree | 3 | 2 | +1 ripe every 24 ticks | always | NEVER -- the attempt is the 'reach' |
| shrub | 1 | 1 | +1 ripe every 240 ticks | always | 25% of attempts (15% in the sparse variant); a failed shrub pick costs 6 ticks |
| ground fruit | 1 per cell | - | - | always | always |

Ground fruit ages: ttl starts at 120 ticks off the mat and the fruit is removed at 0, so a delivery has to land NEAR the child.

## The nine-step tick
1 regrow, 2 kernel intent, 3 pick, 4 drop, 5 eat, 6 moves, 7 ground ageing, 8 behaviour accounting, 9 record. Within a step seats resolve in ascending slot order and sources in the fixed order tall trees then shrubs, each by (row, col). A move is legal only every 2 ticks and only into a free grass or mat cell; an illegal action degrades to `wait`.

## Standing orders
A seat does not author 720 actions. Once per TURN (60 ticks) each seat submits ONE standing order and a deterministic kernel turns it into the per-tick grid action stream for the whole turn.

PARENT jobs: `provide <fruit>` (fetch it and drop it beside the child), `stock <fruit>` (fetch it and put it on the mat), `watch` (stand near the child and observe -- it feeds nobody), `idle`. The parent must also send a `guess` every turn.

CHILD jobs: `seek <fruit>` (go eat that species, refusing the other), `show <fruit>` (stand under a tall tree of that species and reach for it over and over -- it can never yield food; it is the only way to say what you want), `graze` (eat whatever is nearest, either species -- it says nothing), `beg` (stand next to the parent), `idle`.

## Scoring
The child scores 3 for eating the fruit it prefers and 0 for the other; the parent's score is EXACTLY THE SAME NUMBER. A parent that eats a fruit itself destroys it for 0. Higher is better. `win[i] = scores[i] >= par` with par = 2 x turns = 30: Daycare is cooperative, so the platform's boolean means 'the pair beat par'.

## End conditions
The FIRST of: 15 turns played (`complete` / `turn_limit`); the wall clock passes 60% of the episode timeout (`deadline` / `deadline`); no seat connected within 120 s (`forfeit` / `forfeit`). A MISSING seat does not end the episode -- it plays the `caretaker` baseline and the game runs.
