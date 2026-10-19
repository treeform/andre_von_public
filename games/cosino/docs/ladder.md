# The ladder and the score

## One formula, all four rungs

With `n` seats, `S = startingStack`, `H` completed (scored) hands and `net[i]` seat i's cumulative chips won minus chips committed over those hands:

```
scores[i] = 1/n + net[i] / (n * S * H)
win[i]    = (net[i] == max(net))
```

`sum(net) == 0` exactly - a chip-conservation test enforces it - so `sum(scores) == 1`. The range is exactly [0, 1] with no clamping: the best possible net is `(n-1)*S*H` -> 1, the worst is `-S*H` -> 0. Positive is winning; a seat that breaks even scores exactly `1/n`. At `H = 1` this degenerates to a plain chip share.

Results also carry the legible raw figures: `net[]`, `netPerHand[]` and `unitsPerHand[] = net[i] / (unit * H)`, where `unit` is the big blind at Hold'em and the ante on the calibration rungs.

## Why one league across all four rungs

The score is unit-free - a share of the same virtual bankroll whatever the rung - so a Kuhn episode and a six-max episode contribute the same amount of Elo, and a single leaderboard is what makes this a *ladder* rather than three unrelated boards. Exploitability and the collusion audit are recorded DIAGNOSTICS in `results`, never inputs to the ranking; that keeps a noisy metric out of the Elo.

## The decision budget

Poker is sequential, so the budget is per decision, not per turn: 220 model calls per episode at ~3.0 s each is 660 s, exactly the soft guard (55% of 1200 s), which settles at the next duplicate-pair boundary. The hard guard at 672 s (56% of 1200 s) voids and refunds the live hand. It is checked BEFORE a decision, so it nets off one worst-case decision - a 2100 ms spacing floor, two 20 s model attempts, the turn delay and the settle write, about 45 s - which is what keeps the true worst-case settle inside 720 s, 60% of the platform's timeout. A 2100 ms floor between decision starts holds the episode under the Bedrock sidecar's 30-requests-per-minute cap. Each variant's hand count is declared to fit and is re-capped at sample time, rounded DOWN to an even number so every duplicate pair is complete.

## The chip race is the degenerate case

The formula above with `H = 1` is a plain chip share, and that is exactly the chip-race score: stacks carry, so the whole match is one long `net` and `scores[i] = stack[i] / (n * S)`. One axis, all six tables.