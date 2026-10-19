# Negotiation Games rules

## The table

Three seats. An episode is `matches` one-on-one BARGAINING matches (default
6, legal 3 or 6), played one at a time so there is always exactly one table
to watch. Match `m` (0-based) is played by the pairing `P[m mod 3]` where
`P = [(0,1), (0,2), (1,2)]`. The opener - the seat that moves on turn 1 - is
the pairing's first seat when `(m div 3) mod 2 == 0`, otherwise the second.
Over six matches every seat plays exactly four matches and opens exactly two.
The third seat sits the match out: it is never queried, never sees the pool,
the values, the offers or the messages, and its tallies do not move.

## The pool and the valuations

Item types are fixed and ordered: books, hats, balls. For each match the seed
draws, in this order:

1. counts `c[i]`, each 1..4, redrawn as a whole triple until the pool holds
   5 to 7 items (bounded: after 32 misses it settles on `[3, 2, 2]`);
2. the value table `V(c)` - every `v` in `{0..10}^3` with
   `c[0]*v[0] + c[1]*v[1] + c[2]*v[2] == 10`, enumerated lexicographically;
3. seat A's values from `V`, then seat B's, redrawn at most 16 times until no
   item type is worthless to both.

So the whole pool is worth exactly 10 to each seat, the two seats generally
value different things (integrative trades exist), and no item is worthless
to both. Values are redrawn every match, so nothing learned about one
opponent transfers to the next match.

## The two actions

On its turn a seat takes exactly one of:

- **offer** - a `take` vector: how many of each item THIS seat takes. Legal
  iff `0 <= take[i] <= c[i]` for every item. The opponent gets the
  complement.
- **accept** - accept the standing offer (the offer made on the previous
  turn). Legal iff a standing offer exists, i.e. from turn 2 on. `accept` on
  turn 1 is illegal.

Both may carry an optional free-text `message` (at most 200 characters, seen
by the opponent) and optional private `notes` (at most 400 characters, fed
back verbatim on this seat's next turn, never shown to the opponent). Only
the structured take/accept is graded; the message is cheap talk and is never
enforced by the rules.

## The turn cliff

A match lasts at most `maxTurns` turns (default 10, legal even 2..12), turn
`t` taken by the opener when `t` is odd. If the last turn passes with no
accept, the match ends `no_deal` and both seats bank 0. There is no discount
for stalling: the cliff is the only pressure.

## Scoring - formula, sign, what the league ranks

For a settled match, seat `s` receives `recv[i]` of each item and banks
`u(s) = sum over i of recv[i] * v_s[i]`, an integer 0..10 (0 for a no-deal).
Over the episode:

    points[s]        = sum of u(s) over the matches s played
    matchesPlayed[s] = matches s played that reached a matchEnd
    deals[s]         = those that ended "deal"
    score[s]         = points[s] / (10 * matchesPlayed[s])   in [0, 1]
                     = 0.0 when matchesPlayed[s] == 0
    giveaway[s]      = mean over settled matches of (opponent's u - s's u)

**Higher is better.** `score` is a share of the pie: 1.0 means it took the
whole pool in every match, 0.0 means no deal in every match. The league ranks
seats by mean episode `score`, descending. `giveaway` is NOT ranked - it is
the mechanical softplay audit: a seat that systematically hands the pool to a
partner shows a large positive `giveaway` with a low `score`.

## How an episode ends

`results.reason` takes exactly two values and nothing else:

- **complete** - all scheduled matches reached a `matchEnd`.
- **deadline** - the play clock (60% of `episodeTimeoutSeconds`, or of
  `COWORLD_TIMEOUT_SECONDS` when the platform provides it) stopped play
  BETWEEN matches. Scores use the matches actually settled.

A match-level outcome - `deal` or `no_deal` - is a separate enum carried by
the `matchEnd` event. It never appears in `results.reason`.
