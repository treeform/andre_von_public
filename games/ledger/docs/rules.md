# Ledger rules

## The table

Eight seats, each under a permanent public alias drawn from the episode seed (Sprocket, Gizmo, Ratchet, Widget, Bolt, Piston, Flywheel, Rivet, Tinker, Gasket - eight of the ten). An alias is permanent for the whole episode and its complete meeting record is public to every seat from round 1. Real policy names never reach the table; they ride alongside for spectators only.

## The schedule

Round pairings come from the standard circle-method 1-factorization of eight positions, relabelled once by a seeded permutation. Rounds are generated in passes of seven (one complete round robin); each pass shuffles the order of the seven matchings and resamples until no pair would meet in two consecutive rounds. Consequences, both asserted by tests:

- over 14 rounds every unordered pair meets EXACTLY twice - a perfect double round robin;
- over any number of rounds no pair meets more than ceil(rounds / 7) times. That is the "same-partner cap" the design asks for, and it is structural rather than a filter.

Every seat plays in every round, so a seat's meeting count equals the rounds played.

## The three games

Per pairing, per round, the seed draws: 50% DILEMMA, 30% TRUST, 20% ULTIMATUM. DILEMMA is symmetric; TRUST and ULTIMATUM have a first mover (investor / proposer) and a second mover (trustee / responder). All eight seats decide SIMULTANEOUSLY: the second mover commits a contingent rule before seeing the first mover's move (the experimental-economics strategy method), so a whole round is one decision per seat.

Every payoff is a whole number of coins in 0..14, and fair play pays 6 in all three games.

### DILEMMA

|                  | partner cooperates | partner defects |
|------------------|--------------------|-----------------|
| you cooperate    | 6 / 6              | 0 / 10          |
| you defect       | 10 / 0             | 2 / 2           |

### TRUST

Investor endowment 6 coins, trustee endowment 2 coins, multiplier 2. The investor sends `s` (0..6); the trustee receives `2s`; the trustee's committed return percent is `p` (0..100), so `returned = round(2s * p / 100)` (half up), clamped to `0..2s`.

- investor ends with `6 - s + returned`
- trustee ends with `2 + 2s - returned`

Landmarks: `s = 4, p = 50` gives 6 / 6 (the pot is `8 + s` coins, so an even 6 / 6 split is reachable only at `s = 4`); `s = 6, p = 50` gives 6 / 8; `s = 6, p = 0` gives 0 / 14; `s = 0` gives 6 / 2. Coin invariant: `investor + trustee == 8 + s`.

### ULTIMATUM

A 12-coin pie. The proposer offers `o` (0..12); the responder's committed minimum acceptable offer is `m` (0..12). If `o >= m` the proposer keeps `12 - o` and the responder gets `o`; otherwise the deal breaks and both get 0.

Landmarks: `o = 6` gives 6 / 6; `o = 2, m = 0` gives 10 / 2; `o = 2, m = 5` gives 0 / 0. Coin invariant: the total is 12 or 0.

## Conduct and the halo

Each meeting classifies each seat as kind or harsh. DILEMMA: cooperate is kind, defect is harsh. TRUST: investor `s >= 3` is kind, trustee `p >= 50` is kind. ULTIMATUM: proposer `o >= 5` is kind, responder `m <= 5` is kind. `halo = kind / (kind + harsh)`, and exactly 0.5 before a seat's first meeting. The halo is drawn as a ring around each avatar. It is a display and observation statistic and never a score input.

## Gossip

Every reply may carry a `note` of at most 120 characters. A note reviews the partner from the seat's PREVIOUS round's meeting - the last outcome the seat has actually seen - and the observation names that alias explicitly. In round 1 there is no target and any note is discarded. Accepted notes go on one public board, attributed by alias, that every seat reads (the last 12) and the viewer shows (the last 5). Gossip is cheap talk: it never changes a payoff or a score.

## Scoring: why the median

A seat's score is the MEDIAN of its per-meeting payoffs in coins, and it is maximized. Sort the seat's payoffs; an odd count takes the middle, an even count takes the mean of the two middles, and no meetings at all scores 0.0. At the default 14 rounds the score is `(sorted[6] + sorted[7]) / 2`.

Nothing else is ranked. Mean payoff, total coins, kind/harsh counts and ring flags are all reported for the record and none of them enters `scores`. This is the anti-collusion ranking: a ring can pump the MEAN of an alias it feeds, but with at most 2 of 14 meetings inside the ring it cannot move that alias's MEDIAN, which is set by its meetings with strangers.

## Ring detection: measured, published, never scored

For every unordered pair that met at least twice, `inMean` is the mean of `(payoff_a + payoff_b) / 2` over their mutual meetings and `outMean` is the mean of the two members' own payoffs over all their OTHER meetings. The pair is flagged when it met at least twice, `inMean >= 6.0` and `inMean - outMean >= 3.0`. A ring is a connected component of three or more in the flagged graph. Flagged pairs are drawn as red threads in the replay and counted in `results.ringPairs`. Nothing is disqualified, penalised or rescored.

## How an episode ends

`results.reason` has exactly two legal values. `complete` means every round was played. `deadline` means the play budget (60% of the episode timeout, 720 s of 1200 s) came within the round reserve of the next round's start; play stops between rounds and scores use the rounds actually played. A `deadline` ending is a legitimate, scored episode. There is no resignation, no elimination and no draw.
