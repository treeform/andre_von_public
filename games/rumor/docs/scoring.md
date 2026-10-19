# Rumor scoring

Computed once, at the tally. **Higher is better everywhere; the league ranks by mean episode
score.** Let `H` be the honest seats (7 or 8), `correct` how many of them voted the truth, and

    accuracy  A = correct / |H|       in [0, 1]

## Honest seat `i`

    score_i = 0.6 x (2A - 1) + 0.4 x (vote_i == truth ? +1 : -1)      in [-1, +1]

0.6 of the score is the whole honest bloc's accuracy - the collective-accuracy pool - and 0.4
is the seat's own vote. A seat that is right while the network fails still beats a seat that is
wrong, and no seat can score well by being right alone while everybody around it is misled.

## Saboteur seat `j`

    score_j = 0.6 x (1 - 2A) + 0.4 x (2 x localWrong_j - 1)           in [-1, +1]

where `localWrong_j` is the fraction of `j`'s **honest graph neighbours** who voted wrong, or
`1 - A` when `j` has no honest neighbour. The collective half is the exact mirror of the honest
one; the local half stops a lazy saboteur free-riding on an active partner's work - a lie has
to land where the saboteur actually spoke.

**Saboteur votes never enter `A`.** If they did, a saboteur could bank a guaranteed slice of
wrongness simply by voting wrong itself, and the game would be over before anyone spoke.
Saboteurs still cast a recorded vote so that the room's headline verdict is a real ten-cog
vote; it scores them nothing.

`verdict` - the majority of all ten votes, `split` on a tie - is **display only**.

## Worked table (2 saboteurs, 8 honest)

| situation | honest, voted right | honest, voted wrong | saboteur |
|---|---|---|---|
| all 8 honest right (A = 1) | +1.0 | - | -1.0 |
| 6 of 8 right (A = 0.75), 1 of the saboteur's 3 honest neighbours wrong | +0.7 | -0.1 | -0.43 |
| 4 of 8 right (A = 0.5) | +0.4 | -0.4 | 0.4 x (2 x localWrong - 1) |
| 0 of 8 right (A = 0) | - | -1.0 | +1.0 |

## Why both ranges are [-1, +1]

Roles are dealt from the seed, so a policy that plays a hundred episodes plays both sides. If
one role's range were wider than the other's, the ladder would rank luck of the draw rather
than play. Both halves of both formulas are normalised to [-1, +1] and both are maximised by
playing that role well.

## The headroom the ladder measures

Measured over 6,000 seeds of the reference model:

- voting your own clue and ignoring the network: **0.675** collective accuracy;
- the majority of all ten *claims* - perfect relaying, no saboteur detection: **0.717**;
- the majority of the honest seats' *clues* - perfect relaying **and** perfect discounting:
  **0.925**.

The scripted baselines sit at the bottom of that band: an all-`gossip` table scores about
**0.68**, an all-`herd` table about **0.62** - below the ignore-everyone floor, because herd is
the seat a lie propagates through. Everything between 0.68 and 0.93 is what a prompt can win.
