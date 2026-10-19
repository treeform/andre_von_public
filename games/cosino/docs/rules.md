# Cosino rules

Four ladder rungs of the same zero-sum imperfect-information game, plus the two chip-race cash tables. One episode is one rung.

## What is the same on every LADDER rung

- **Hands, not a chip race.** Every hand starts with every seat holding exactly `startingStack` chips. There are no busts, no rebuys and no seats sitting out; a seat that loses its whole hand-stack gets a cosmetic `stackOff` event and is full again next hand.
- **Duplicate decks.** Hands are played in pairs. Hands `2k` and `2k+1` are dealt from the *same* shuffled deck; in the mirror hand the whole table rotates by half a table, so each seat gets the cards *and* the position its counterpart had. Deal luck cancels inside the pair. The mirror is invisible to the seats - an observation carries only the current hand.
- **Randomised seating.** A seed-derived permutation maps table positions to slots, so a colluding pair cannot count on a fixed relative position.
- **One actor at a time.** Poker is sequential: exactly one seat is on decision at any moment and one decision costs one model call.
- **Anonymous aliases.** Seats play as Sprocket, Gizmo, Ratchet... No policy name ever enters a prompt.
- **Table talk.** Every decision may carry one short public line (`say`, <= 120 runes).

## Rung 1 - `kuhn` (2 seats)

OpenSpiel `kuhn_poker`, exactly. Deck: J, Q, K of spades. Both seats ante 1. One private card each, dealt to position 0 then position 1. ONE betting round, bet size fixed at 1, AT MOST ONE wager (a bet; no raise). Position 0 (the button) acts first. Payoffs: `pp` showdown for 2 (+/-1); `pbp` the bettor takes 2 (+/-1); `pbb` showdown for 4 (+/-2); `bp` (+/-1); `bb` (+/-2). The three cards are distinct, so there is no split.

## Rung 2 - `leduc` (2 seats)

OpenSpiel `leduc_poker` defaults, exactly. Deck: J, Q, K in two suits. Both seats ante 1. One private card each. Round 1: fixed bet 2, at most 2 wagers (a bet and one raise). If both seats are live, ONE public board card is turned. Round 2: fixed bet 4, at most 2 wagers. Position 0 acts first in BOTH rounds - OpenSpiel does not switch the first actor between rounds, and the calibration rungs follow OpenSpiel so exploitability numbers are comparable with published ones. Showdown: a private card matching the board's rank is a pair and beats any unpaired hand; otherwise the higher rank wins; identical ranks split, odd chip to position 0.

## Rung 3 - `holdem-hu` (2 seats) and `holdem-6max` (6 seats)

Standard no-limit Texas Hold'em: min-raise rules, a short all-in that does not re-open the betting unless short increments accumulate to a full raise, side pots by commitment level, split pots with the odd chip clockwise from the button, uncalled bets returned. Blinds 1/2, never escalating; heads-up the button posts the small blind and acts first preflop, last afterwards.

## Ending

`results.reason` is exactly one of `complete` (the hand limit was reached), `deadline` (a wall-clock guard fired) or `budget` (the 220-decision allowance ran out). A hand abandoned by the hard deadline is refunded in full, recorded as `handVoid` and not scored, so the nets still sum to zero.

## The chip-race tables

`headsup` and `sixmax` are the classic Cosino cash game: the same no-limit Hold'em rules, but stacks CARRY between hands. The button walks clockwise to the next funded seat, a cog that loses its last chip is OUT for good (no rebuys), and the match ends at the hand limit or when one cog holds every chip. There are no duplicate pairs here — variance is part of the table — and the final CHIP SHARE is the score: `scores[i] = stack[i] / (n * startingStack)`, still exactly [0, 1] and summing to 1. The six-max collusion audit runs on the chip-race table too.