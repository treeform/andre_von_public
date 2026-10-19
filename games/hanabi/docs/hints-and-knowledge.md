# Hints, knowledge and what your prompt actually sees

## What a card knows about itself

Every card in every hand carries, from its holder's point of view: the positive colour hint and the positive rank hint it has received; the colours and ranks that hints have PROVEN it is not (because a hint marks every matching card, so an untouched card is not that colour/rank); and the turn a hint last touched it.

From those the game derives a **candidate set**: every (colour, rank) consistent with the positive hints, not excluded by the negative information, and with at least one copy the holder cannot already see. `remainingCopies` counts the copies of a card the holder cannot see: the total minus the fireworks, minus the discard pile, minus the other seats' hands, minus its own cards that are already pinned to a single identity by hints alone. This is ONE pass, no fixpoint: there is no multi-card constraint propagation and no reasoning about what a partner would have hinted. If you want that, do it in your prompt.

Two predicates fall out and appear on every slot:

- **knownPlayable** - every candidate is playable on its stack right now. Playing one of these can never misplay.
- **knownDead** - every candidate is already played, or is stranded above a rank whose copies are all in the discard pile. Discarding one of these costs nothing.

And one table fact, used by the spectator annotation and the baselines: a card is **critical** when it is the last copy still in play and not dead.

**Chop** = the highest-numbered slot with no positive hint of either kind; if every slot carries a hint, the highest-numbered known-dead slot; failing that the oldest card. The chop is a derived quantity shown to you and drawn in the viewer - nothing forces you to discard it.

## What your observation contains

Every turn, your prompt carries exactly:

- The turn number and the cap, the score, the hint tokens, the fuses, the deck count and the endgame countdown when it is armed.
- The five fireworks and the whole discard pile, grouped.
- The other three seats' hands FACE-UP in slot order, each card as `red 3` plus what that holder knows about it.
- YOUR hand as knowledge only: per slot the positive hints, the negative information, the candidate set (listed at six or fewer, otherwise counted), the knownPlayable/knownDead flags, the chop marker and the turn it was last touched.
- The complete public move log, one line per turn since turn 0, with the revealed identity of every card played or discarded.
- `LEGAL MOVES`: every legal move, numbered, each printed as the exact JSON object to copy.
- Your own private note from earlier turns, verbatim.
- Your operator's prompt.

It never contains: the identity of any of your own cards, the deck, another seat's note or banner, the mapping from alias to policy name, or the seed. There is no chat channel - a hint is the only thing you can say.

## The reply

One flat JSON object, copied from LEGAL MOVES, optionally with `note` (400 runes, private, fed back to you next turn) and `banner` (80 runes, shown to SPECTATORS only - your partners never see it, which is exactly why it cannot become a side channel):

```json
{"action":"hint","target":2,"hintType":"rank","hintValue":"3","note":"...","banner":"..."}
{"action":"play","slot":1}
{"action":"discard","slot":4}
```

The parser is tolerant: markdown fences, a trailing sentence, `{"move":"play 2"}`, an alias instead of a seat number, `color`/`number` spellings and numeric strings all normalise. Anything else is rejected with a specific reason, retried ONCE with that reason quoted, and then the `conventions` baseline moves for you and the turn is recorded with `origin: fallback`.

## The two scripted baselines

**conventions** (also the fallback move, and every seat when there are no credentials) plays the first rule that fires:

1. Play the lowest-numbered knownPlayable slot.
2. If the next seat to act has a critical card on its chop, hint that card's RANK to that seat.
3. Otherwise give the legal hint that makes the most of the receiver's cards NEWLY knownPlayable (at least one); ties break by the seat acting soonest, then rank before colour, then the lower value, then the lower seat.
4. Otherwise discard the chop.
5. Otherwise (only at 8 tokens with nothing to say) give the legal hint touching the fewest cards of the next seat.

**cautious** never misplays:

1. Play only a slot whose candidate set is a single card that is playable now.
2. Otherwise hint the rank of a currently-playable card that carries no positive hint at all, preferring the next seat to act.
3. Otherwise discard the chop.
4. Otherwise hint the rank of the next seat's oldest card.

Both are deterministic pure functions of the position and neither ever proposes a move outside the legal list. `conventions` beats `cautious` on mean score; a prompt that cannot beat `conventions` is not yet a policy.