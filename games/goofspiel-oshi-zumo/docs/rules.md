# Goofspiel / Oshi-Zumo rules

One sim, one image, two modes selected by the `mode` field of game_config.

## Goofspiel (mode "goofspiel", 4 seats, 13 rounds)

- Every seat holds an identical hand of the cards 1..13. The prize deck is the cards 1..13, shuffled once
  from the episode seed and recorded in the replay as `config.prizeOrder`. The total pool is 91.
- Resolution order for round r (this is the order the sim executes and the order the events appear in the
  replay):
  1. `beginRound`: reveal `prize = prizeOrder[r]`; emit the `prize` event.
  2. Build every seat's observation. Scripted seats decide inline; every LLM seat's request goes out in ONE
     parallel batch.
  3. Each seat returns one integer bid, legal iff the card is still in that seat's hand. Illegal,
     unparseable or timed out -> one retry in a second batch carrying the legal set -> the `match` baseline,
     and the seat's `fallbacks` counter increments.
  4. All bids are locked server-side, then revealed simultaneously. No seat, spectator socket or player
     socket sees any bid of round r before every bid of round r is in.
  5. `top = max(bids)`, `winners = { i : bids[i] == top }`.
  6. If exactly one winner it gains `prize`; otherwise each tied seat gains `prize / |winners|`. Fractional
     scores are legal. (OpenSpiel's split convention: it keeps the pool constant at 91, which keeps the
     score formula exactly zero-sum.)
  7. Every seat removes its bid card from its hand - spent whether it won or not.
  8. `margin = top - (highest bid strictly below top)`, and 0 when the top is tied. Emit `reveal`; if
     `margin >= 6`, emit `overbid` immediately after it.
  9. After the 13th prize: `complete` / `prizes-exhausted`.

## Oshi-Zumo (mode "oshizumo", 2 seats, at most 20 rounds)

Buro's [N, K, M] parameterisation pinned to N = 20 coins, K = 3, M = 1.

- The field is 2K+1 = 7 cells, 0..6; the token starts at cell 3. Seat 0 pushes toward cell 6, seat 1 toward
  cell 0. The token is off the field at > 6 (seat 0 wins) or < 0 (seat 1 wins).
- A bid is an integer in [minBid_i, coins_i] where `minBid_i = min(M, coins_i)` - normally at least 1, but a
  seat holding 0 coins must bid 0. M = 1 makes the episode provably bounded by 20 rounds.
- Resolution order for round r:
  1. `beginRound`: publish the position and both purses (no `prize` event in this mode).
  2. Observations built; scripted seats inline; LLM seats in one parallel batch.
  3. Each seat returns one integer bid; same retry-then-fallback ladder as goofspiel.
  4. Bids locked, then revealed simultaneously.
  5. BOTH seats pay: `coins[i] -= bids[i]`, unconditionally.
  6. `bids[0] > bids[1]` -> `position += 1`; `bids[1] > bids[0]` -> `position -= 1`; EQUAL BIDS DO NOT MOVE
     THE TOKEN, and both bids are still deducted (Buro 2004).
  7. Emit `reveal`, then `overbid` when `margin = |bids[0] - bids[1]| >= 6`, then `push` (carrying
     `delta` in {-1, 0, +1} and `positionAfter`).
  8. End checks, in this order: `position > 6` -> `complete`/`pushout`, seat 0 wins; `position < 0` ->
     `complete`/`pushout`, seat 1 wins; both purses 0 -> `complete`/`coins-exhausted`, scored by position;
     `roundsPlayed == maxRounds` -> `complete`/`round-cap`, scored by position.
- Scoring by position, used for every non-pushout ending including `deadline`: `position > 3` seat 0 wins,
  `position < 3` seat 1 wins, `position == 3` is a draw.

## Scoring

One `scores` array, same meaning in both modes, higher is better, and the array sums to 0.

- Goofspiel, N seats, `pool` = the prize value awarded so far (91 for a complete episode):
  `share_i = points_i / pool`, `score_i = (N * share_i - 1) / (N - 1)`. At N = 4 that is
  `(points_i - 22.75) / 68.25`: +1 means "won every prize", 0 means "exactly the equal share".
- Oshi-Zumo: +1 for the winner, -1 for the loser, 0/0 on a draw.

Both scales top out at +1 deliberately, so a seat that dominates one variant and a seat that dominates the
other look the same to the ladder. The league ranks by mean episode `score`, higher first.

## Endings

`results.reason` has exactly two legal values, `complete` and `deadline`. The finer ending rides in
`results.ending`:

| reason | ending | when |
|---|---|---|
| complete | prizes-exhausted | goofspiel: the 13th prize resolved |
| complete | pushout | oshi-zumo: the token left the field |
| complete | coins-exhausted | oshi-zumo: both purses are 0 after a round |
| complete | round-cap | oshi-zumo: maxRounds rounds played, token still on the field |
| deadline | wall-clock | the play deadline stopped the episode between rounds |

`deadline` is an ACCEPTABLE ending for this coworld: the game is fully scored at the stop (goofspiel from
the prizes already awarded, oshi-zumo by token position), so a deadline episode is a real result. The same
`settle(reason, ending)` proc applies the ending on record and on playback, so a wall-clock stop re-derives
identically in the wasm replay viewer.

## The 'overbid' gasp

One predicate, both modes: `overbid` iff `margin >= 6`, where `margin` is the top bid minus the highest bid
strictly below it (0 when the top is tied). It is its own event, its own feed line, its own scrub beat and
its own banner.

## Anti-collusion

Sealed bids server-side; anonymous cog aliases (no prompt ever contains a policy name); and a reported,
never enforced bid-pattern audit: `results.collusionIndex[i]` is the share of goofspiel rounds in which
seat i bid its lowest remaining card while the round's margin was >= 6 - it stood aside for someone else's
blow-out. 0.5 is the threshold at which a human should look.

## The meta

Every decision is made by Claude from a per-seat policy prompt plus the prize, every seat's remaining
resource, the complete public bid history and the seat's own private notes. Prompts that price each prize
against what it costs, track what rivals have already spent, and concede the prizes two rivals will fight
over tend to score. The scripted baselines - `match` (bid the prize's rank, or the cheapest card above it)
and `hoard` (dump the lowest card on small prizes, swing the highest on big ones) - fill seats without
prompts and are fieldable policies in their own right.
