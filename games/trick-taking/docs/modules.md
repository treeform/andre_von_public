# The four rule modules

## euchre - 4 seats, partnerships (0&2 vs 1&3), 8 hands

1. Deck of 24 (9, 10, J, Q, K, A of every suit). Five cards each, dealt 3-2 / 2-3 clockwise from the
   left of the dealer; the four left over are the kitty and its top card is turned face up.
2. Bidding round 1, clockwise from the left of the dealer: `pass`, `order` (make the up-card's suit
   trump) or `alone` (make it trump and play without your partner). The first non-pass ends round 1
   and that seat is the maker; the dealer then picks up the up-card and discards one card face down,
   hidden from every seat including its own partner.
3. Bidding round 2 runs only if all four passed. The up-card is turned down and each seat may pass,
   or `name`/`alone` any suit except the up-card's. **Stick the dealer is ON**: if the first three
   pass, the dealer must name a suit. There is never a throw-in and never a re-deal.
4. The jack of trump is the right bower, the highest trump; the jack of the other suit of the same
   colour is the left bower, the second-highest trump, and it is a TRUMP, not a card of its printed
   suit.
5. The seat left of the dealer leads trick 0. If the maker went alone, the maker's partner sits out
   the whole hand and is skipped in turn order.
6. Scoring: makers take 3 or 4 tricks = 1 point; all 5 = 2 (4 if alone, a lone march); makers take 2
   or fewer (euchred) = 2 points to the defenders. Swing cap 4.

## spades - 4 seats, partnerships (0&2 vs 1&3), 4 hands

1. A full 52-card deck, 13 each. Trump is always spades.
2. Each seat bids 0..13 clockwise from the left of the dealer, seeing every earlier bid. A bid of 0
   is nil. The team contract is the sum of the two partners' non-nil bids.
3. A spade may not be led until spades are broken - a spade has been played by a seat void in the
   led suit - unless the leader holds nothing but spades.
4. Scoring per team: non-nil members take at least the contract C -> 10*C plus one point per
   overtrick (a bag); short of it -> minus 10*C. A nil member scores +100 if it wins no trick and
   -100 otherwise; a failed nil's tricks count as bags but never towards the contract. There is no
   bag rollover in v1, which makes |team score| <= 230 provable. Swing cap 460.

## hearts - 4 seats, individual, 4 hands

1. A full 52-card deck, 13 each. No trump.
2. The pass direction cycles left, right, across, hold. On a passing hand every seat chooses exactly
   3 cards; nothing is revealed until all four have chosen, and a seat never learns what anyone else
   passed except by inference.
3. The holder of the two of clubs leads it to trick 0 - a forced move that costs no model call. On
   trick 0 no heart and not the queen of spades may be played unless a seat holds nothing else.
   Hearts may not be led until they are broken.
4. Penalty: every heart taken costs 1 and the queen of spades costs 13; the hand always carries
   exactly 26. **Shooting the moon**: a seat that takes all 26 scores 0 and every other seat scores
   26. Fewer penalty points is better. Swing cap 19.5.

## oh-hell - 4 seats, individual, 11 hands

1. The deal schedule is 1, 2, 3, 4, 5, 6, 5, 4, 3, 2, 1. Each hand deals that many cards from a
   fresh 52-card shuffle and turns the next card face up: its suit is trump for the hand, and the
   turn-up itself is out of play.
2. Each seat bids 0..cards clockwise from the left of the dealer, seeing every earlier bid.
   **The hook is ON**: the dealer may not bid the value that would make the four bids sum to exactly
   the number of tricks, so somebody always misses.
3. A seat that takes EXACTLY its bid scores 10 plus its bid; any other number scores zero - one over
   is as bad as three under. Swing cap 0.75 * (10 + cards).
