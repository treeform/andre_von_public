# Garble scoring

## The formula

At the horizon, with `F[c]` the last opened turn's price for commodity `c`:

```
portfolio[s] = cash[s]
             + sum over c of units[s][c] * F[c]
             + premium[s] * min(units[s][dem[s]], quota[s])

hold[s]      = the SAME formula applied to the seat's STARTING cash and inventory
               at the SAME F[c] - what the seat would be worth had it never traded

score[s]     = portfolio[s] / hold[s]
```

**Higher is better.** `1.00` means the seat traded to no effect. `hold[s] >= 180`
always (120 cash plus 20 units at a floor price of 3), so the division is total;
`portfolio[s]` can never be negative, because the coverage rule keeps cash and
units non-negative, so `score[s] >= 0`. The results schema bounds it `0 .. 10`.

**The league ranks by mean episode `score`** - the ratio, not the raw credits, so
episodes with different seeded price levels are comparable. `results.portfolio`
also reports the raw credits for readability.

## Not zero-sum

A good trade lifts **both** sides above 1.00: the buyer pays less than the demand
commodity is worth to it with its premium, and the seller receives more than its
surplus is worth on the market. A mishearing lifts one and sinks the other, and
nobody's score is anybody's mirror image. There is nothing to collude around -
your counterparty gains when you lose on a mishear, so an out-of-band shared
convention is a gift to whoever defects from it first.

## A worked mishearing

Seat 0 holds 20 ORE and says, once, terse:

```
SELL 5 ORE AT 12          (kQty = 1, kCom = 1, kPrice = 1)
```

It means: five units, twelve credits each, sixty credits in. Seat 1 confirms

```
{"ticket":7,"side":"SELL","qty":50,"commodity":"ORE","price":1}
```

`50` is a near-neighbour of `5` (append a zero) and `1` is a near-neighbour of
`12` (drop the last digit), and both fields were said exactly once, so the confirm
is **admissible**. The exchange enforces it. Coverage caps the fill at the
seller's 20 units, so:

- seat 0 loses **20 ORE** - its entire holding, not 5 - and receives **20 credits**
  instead of the 60 it asked for;
- seat 1 gains 20 ORE for 20 credits;
- the `deal` event stamps both versions, `misheard: true` and `partial: true`, and
  it is published on the public tape the same turn, so the robbed offerer knows.

Had seat 0 spent six more characters of airtime:

```
SELL 5 5 ORE ORE AT 12 12 (kQty = 2, kCom = 2, kPrice = 2)
```

the same confirm would have **voided** as `inadmissible` and seat 1 would have
wasted its turn. That is the whole game: protocol robustness costs airtime, and
airtime is the budget that decides how much protocol you can afford.
