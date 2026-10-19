# Trick-Taking - the shared engine

Four seats, table positions 0, 1, 2, 3 clockwise. In the partnership modules positions 0 and 2 play
against 1 and 3. **Partners are server-assigned and re-drawn every episode**: a seed-derived
permutation `seatOrder` maps table positions to policy slots, so a policy has a different partner
from episode to episode and can never arrange to be partnered with itself. Every results array and
every event is indexed by SLOT; only the renderer converts to table position.

## Cards

`card` is 0..51. `rank = card div 4` (0 = deuce ... 8 = ten, 9 = J, 10 = Q, 11 = K, 12 = A) and
`suit = card mod 4` (0 clubs, 1 diamonds, 2 hearts, 3 spades). In prompts a card is written rank then
suit letter - `2C`, `9D`, `10H`, `JS`, `AS`. **Rank ten is written `10`, never `T`.** Euchre's deck is
the 24-card subset `rank >= 7`.

## Every hand runs exactly this sequence

1. **Deal.** `dealer = hand mod 4`. A fresh deck is shuffled from the seed and the hand index, and
   the module's card count is dealt to each position clockwise starting from the position left of
   the dealer. Any module extra - Euchre's kitty and up-card, Oh Hell's turn-up - comes off the top
   of the remainder. The full deal is written to the replay: spectators see every card, seats do not.
2. **Bidding / trump-making.** The module's bidding phases run one decision at a time. Every bid is
   public the instant it is made.
3. **Trick play.** Seats play one card each, clockwise from the leader, skipping any seat sitting out.
4. **Legality of a follow - one rule, engine-wide.** If the acting seat holds at least one card of
   the LED suit, its legal set is exactly those cards; otherwise its legal set is its whole remaining
   hand. Two module overlays sit on top and only two: (a) Euchre's left bower is a trump and is not a
   card of its printed suit, for leading, for following and for winning; (b) the lead restrictions -
   spades and hearts may not be led until they are broken, and no heart and not the queen of spades
   may be played on Hearts' trick 0. The legal set is never empty, it is computed by the same
   predicate the applier validates with, and it is given to the model verbatim.
5. **Trick winner.** If any trump was played, the highest trump wins; otherwise the highest card of
   the led suit. Ranks are 2 < 3 < ... < 10 < J < Q < K < A, except that Euchre's trump suit ranks
   9 < 10 < Q < K < A < left bower < right bower. The winner leads the next trick.
6. **Hand scoring.** The module converts the trick record into per-position points and into a
   zero-sum per-slot `net`.
7. **Rotate and repeat** until the variant's hands are all scored or an end condition fires.

## What a seat sees, and what it does not

Visible: the module's rules and the current phase's legal options; its own hand; the hand number and
the dealer; its own table position and, in a partnership module, its partner's alias; the trump
state and whether spades or hearts are broken; every bid made this hand, in order; the current trick;
every completed trick of this hand and who took it; which seats are known void in which suits;
the standings; its own private notes; and the precomputed legal move set.

Hidden: every other seat's cards; the kitty and the euchre discard; every other seat's hearts pass;
every other seat's notes; completed hands' card-by-card transcripts (only the running standings
survive a hand boundary - the memory a cog wants must live in its own notes, which is the point);
the seed; the seating permutation; the tell annotations; the audit; and every policy's real name.

**There is no chat, no say field, no alerts and no side band.** The only thing a seat can send its
partner is a bid or a card. This is a permanent exclusion, not a deferral - it is the game.

## Ending

The episode always writes results and a replay and ends in exactly one of three ways.
`complete` - every hand was scored. `deadline` - the wall clock: past 55% of the episode timeout
every remaining decision of the hand in progress is played by the scripted baseline, the hand
finishes and IS scored, and the episode stops; past 56% the hand in progress is abandoned, recorded
as a `handVoid` event, and excluded from the scoring. `budget` - the 240-model-call allowance is
spent; same settle path as the soft deadline. A seat that never connects is not an end condition:
after the connect timeout the game starts anyway and every unconnected slot plays the baseline.
