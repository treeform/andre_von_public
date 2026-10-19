# Liar's Dice rules

## Resolution, in order

1. **Deal opens.** Every seat is dealt a fresh hidden hand from the seed (5 dice in `dice` mode, an 8-digit serial number in `poker` mode). The opener of deal `d` (0-based) is table position `d mod 4`; the table order is a seeded random permutation of the slots, so a pair of policies does not sit in the same relation every episode.
2. **A seat acts.** Exactly one seat acts at a time - this is a strictly sequential turn game. The acting seat plays either BID `(quantity, face)` or CHALLENGE, optionally attaching `say` (when talk is on) and `notes` (always private).
3. **Opening bid.** With no standing bid the acting seat MUST bid; a challenge is illegal. A legal opening bid has `1 <= quantity <= 20` (seats x handSize) and a face in the mode's range.
4. **Strict raise.** With a standing bid `(q0, f0)`, a bid `(q, f)` is legal iff `q > q0`, or `q == q0 and f > f0`. Equal bids and equal-quantity-lower-face bids are illegal. Ones are NOT wild: a symbol counts only for its own face.
5. **Turn advance.** After a legal bid the turn moves to the next table position, wrapping.
6. **Challenge.** With a standing bid the acting seat may challenge instead. Every hand is revealed and `actual` is the count of `f0` across ALL hands. If `actual >= q0` the bidder was truthful: bidder +1, challenger -1. If `actual < q0` the bid was a lie: challenger +1, bidder -1. Nobody else scores.
7. **Deal ends** the moment a challenge resolves.
8. **Bid cap.** Once `maxBidsPerDeal` (default 12) bids have been made the acting seat may not bid: the sim forces a challenge on its behalf, resolved exactly as rule 6 with `forced: true`. A deal is therefore at most 13 decisions.
9. **Next deal.** After `deals` deals the episode settles `complete`; the episode clock may settle it `deadline` at a deal boundary instead, scored on the deals actually played.
10. **Talk.** `say` rides on the acting seat's own action - there is no separate talk phase and no extra model call. It is published to every seat the instant the action applies and shows up in the next prompt of the same deal. Talk does not carry across deals. It is cheap talk: nothing said binds anyone.
11. **Illegal actions never stall the table.** Any reply that is unparseable, out of range, not a strict raise, a challenge with no standing bid, or a bid the cap forbids is rejected; the server retries the model once with the reason and, on a second failure, applies the `bayes` baseline's move for that seat.

## Scoring

```
points[s] = wins[s] - losses[s]
score[s]  = 0.5 + points[s] / (2 * dealsPlayed)     (0.5 when no deal was played)
```

Higher is better, 0.5 is break even, and `sum(points) == 0` over any completed set of deals, so the game is zero-sum in points and the mean score across the table is always 0.5. The league ranks by mean episode score.

## Liar's Poker variant

`mode: "poker"` swaps the six dice faces for the ten digits 0-9 and the five-dice hand for an eight-digit hidden serial number (leading zeros allowed), giving 32 digits on the table at a symbol probability of 1/10. Bid ordering, challenge resolution, scoring, talk and the audit are identical. Digits are rendered and spoken as digits, never as letters.

## Soft-play audit

Recorded server-side from full information, reported in `results.audit`, and never shown to any seat in-game. For every ordered pair of slots `(a, b)`:

- `faced[a][b]` - times `a` was on turn with `b`'s bid standing.
- `challenged[a][b]` - of those, how many `a` challenged.
- `net[a][b]` - points `a` took from `b`; antisymmetric.
- `expLoss[a][b]` - the expected value `a` forwent by NOT challenging `b`, averaged over the facings: for each facing where `a` did not challenge, `max(0, 1 - 2 * pTrue)` where `pTrue` is the exact binomial tail computed from `a`'s own hand alone. A seat that repeatedly waves through clearly beatable bids from one specific opponent shows a high `expLoss` against that opponent and a low one elsewhere; that asymmetry is the audit's read.
- `bluffRate[s]` - the fraction of `s`'s bids that were false at the moment they were made.

## The two scripted baselines

Both emit exactly one legal action per turn, never talk and never write notes, and both are selected with `PLAYER_SCRIPTED`.

- **`bayes`** (`chal = 0.15`, `safe = 0.35`) - challenges when the standing bid is under 15% likely to be true from its own hand; otherwise enumerates the raises `q0 .. q0+2` on every face, keeps those at least 35% likely, and bids the likeliest (ties: lower quantity, then the face it holds most of, then the seeded RNG). With nothing safe to bid it challenges. It opens on the face it holds most of, at its own count plus the table's expected share. It is also the no-credentials fallback and the fallback for a rejected LLM reply.
- **`pressure`** (`chal = 0.25`, `safe = 0.35`) - the same machinery, calling a standing bid sooner than the tuned line, and it pads its chosen raise by one whenever that stays legal. It bids past its own read, bluffs more, and gives the LLM champions something to catch.

## The meta

Every decision is made by Claude from a per-seat policy prompt plus the seat's own hand, the bid history, the table talk, every previous deal in full (bid, challenger, real count and all revealed hands) and its private notes. Prompts that count their own hand honestly, keep a per-opponent record of who bluffs, and use talk they can cash later tend to score; the scripted baselines fill the remaining seats and are fieldable policies in their own right.