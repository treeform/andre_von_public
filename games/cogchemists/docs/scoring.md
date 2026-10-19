# Scoring

Every seat starts on **reputation 10** and **coin 4**.

```
score(seat) = reputation(seat) + 0.2 * coin(seat)
```

**Higher is better.** Reputation is the point; coin is the tiebreaker at one fifth of a reputation
point per coin - enough to make selling and royalties matter, never enough to beat a true
publication. A score is a float and **may be negative**: a seat that publishes three false theories
and gets burned lands below zero, and that is intended. The league ranks by **mean episode score**,
and `results.scores[]` carries exactly this number per seat, attributed by policy name.

## Every reputation move, in one table

| event | author | debunker | endorser | actor |
|---|---|---|---|---|
| `publish` | +2 (+3 with the Press) | - | - | - |
| `sell` hit | - | - | - | +1 |
| `sell` miss | - | - | - | -1 |
| drink a positive potion | - | - | - | +1 |
| drink a negative potion | - | - | - | -2 |
| successful debunk (seal burns) | -4 | +3 | -1 each | - |
| failed debunk (seal stands) | +1 | -2 | - | - |
| exhibition, standing seal TRUE | +5 | - | +2 each | - |
| exhibition, standing seal FALSE | -6 | - | -3 each | - |

Nothing else moves reputation. Coin moves: `pass` +1, `transmute` +2, `sell` +6 (hit) or +2 (miss),
royalties +1 per standing seal per round open (+2 with the Press), `test_student` -1, `publish` -1,
`endorse` -1 (paid to the author, who gains it), `debunk` -1, `buy mortar` -4, `buy press` -5.

## The worked landmark

Sprocket runs `test_student` in round 0's lab (coin 4 -> 3), publishes Nightcap in round 0's market
(coin 3 -> 2, reputation 10 -> 12). Royalties at the opens of rounds 1-5 pay 5 coin (2 -> 7). In
round 1 it forages, then sells a hit (+6 coin -> 13, reputation -> 13). Rounds 2-5 it passes eight
times (+8 coin -> 21). The exhibition proves Nightcap true (+5 reputation -> 18). Final: reputation
18, coin 21, **score = 18 + 0.2 x 21 = 22.2**.

## The do-nothing floor

A seat that passes all twelve phases and does nothing else finishes on reputation 10, coin 16,
**score 13.2** - safe, mediocre, and exactly the number a real policy has to beat. Publishing one
true theory is worth about seven points; publishing one false theory is worth about minus five. That
gap, eleven points on a single wax seal, is the game.
