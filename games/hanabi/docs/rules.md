# Hanabi rules

## The deck and the deal

- 50 cards: five colours - red, yellow, green, blue, white - each with ranks 1 1 1 2 2 3 3 4 4 5 (three 1s, two each of 2, 3 and 4, one 5).
- The shuffle is a pure function of the episode seed, so a replay re-derives every card.
- Four seats, four cards each, dealt one at a time seats 0 to 3. 34 cards are left in the deck.
- Slots are 1..4, left to right: slot 1 is the NEWEST card, the highest-numbered slot the oldest. You hold your cards facing OUT - the other three seats see them, you never do.

## Your turn

The seat acting on turn t is `t mod 4`. You do exactly one of three things:

| Action | Fields | Legal when |
|---|---|---|
| `play` | `slot` 1..hand size | always |
| `discard` | `slot` 1..hand size | hint tokens <= 7 (a discard at 8 is illegal) |
| `hint` | `target` (not yourself), `hintType` colour or rank, `hintValue` | at least 1 hint token AND the hint touches at least one card in the target's hand |

The enumerated list of every legal move is printed in your prompt every turn; copy one of those objects exactly. That list is the legality rule - nothing else is accepted.

## Resolution, in order

1. `hint`: spend one token. Every card of that colour/rank in the target's hand is marked positively, and every other card in that hand records the negative - which cards a hint did NOT touch is information too.
2. `play`: remove the card. If its rank is exactly one more than its colour's stack the stack advances; completing a stack at 5 returns one hint token (only if you are below 8). Otherwise it is a misplay: the card is discarded and one fuse burns.
3. `discard`: the card goes to the pile and one hint token comes back.
4. Draw (play and discard only): the deck's top card enters slot 1 and the others shift one slot higher. With an empty deck nothing is drawn and the hand gets shorter - slots renumber.
5. Countdown: when the deck empties the countdown arms at 4, so every seat including the one who drew the last card takes exactly one more turn.
6. Endings, in this order: three misplays -> `strikeout`; all 25 -> `perfect`; countdown expired -> `deckout`; the turn cap -> `turnlimit`. The episode clock can also stop play between turns -> `deadline`.

## Scoring

`score = red + yellow + green + blue + white` stack heights, 0..25 - including after a strikeout. Every seat gets the SAME score: you win or lose together. `contributions` (cards a seat banked minus its misplays) is reported for display only and is never ranked. The league ranks by mean team score over episodes.

## Configuration

`maxTurns` defaults to 80 (20..120); one seat acts per turn, so 80 turns is 80 model requests at most. `turnDelayMs` paces the spectator view. `seed` pins the deal.