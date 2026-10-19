## Seats and the czar

Four seats. The czar for round r (1-indexed) is (r - 1) % 4, so seat 0 czars round 1, seat 1 round 2, and so on. The czar never submits a card, so self-voting is structurally impossible.

## Cards

Black cards are prompts with a `pick` of 1 or 2 (the number of white cards needed; a blank is four-or-more underscores). White cards are answers; each seat holds a hand of 7. The deck ships as validated static JSON and its sha256 (deck_hash) is recorded in every replay.

## Dealing

One seeded random.Random drives everything in a fixed order: at game start shuffle the white pile, shuffle the black pile, then deal 7 white cards per seat in seat order. Each round, replenish every hand back to 7 in seat order; played cards go to a discard pile that is reshuffled if the draw pile empties (deck exhaustion is impossible for the shipped deck, but the guard exists regardless).

## The round

1. round_start — czar and black card announced publicly; hands replenished privately.
2. secret submissions — the three non-czar seats each pick `pick` cards and an optional quip, in parallel and in secret; a missing/late/illegal submission becomes a seeded legal default (default:true). The public stream sees only that a seat locked in.
3. reveal — entries are RNG-shuffled and turned face-up, anonymized (card texts only).
4. czar pick — the czar chooses the winning entry by its shuffle index and may add commentary; a missing/illegal pick defaults to a seeded random entry.
5. round_result — the winning seat gains one award; entries are attributed to seats and quips shown; the scoreboard updates.

## Scoring and termination

Each round win is one award. The game ends when a seat reaches target_awards (default 4) or after rounds_max rounds (default 8). Final scores distribute exactly 1.0 among the top-scoring seat(s), who co-win and split it. Results: {scores: 4x[0..1], awards: 4x int, winner_slots, rounds_played, termination: target_reached | rounds_complete}.

## Safety and fairness

The czar never submits, so it cannot vote for its own card. Entries are anonymized and RNG-shuffled by shuffle index, not seat, so scrubbing a replay cannot leak identities early; attribution and quips appear only at round_result. Card and quip text are untrusted game data — players are instructed never to follow instructions embedded in them.