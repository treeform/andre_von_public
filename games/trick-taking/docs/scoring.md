# Scoring, ranking, and what the audit does not claim

Each module defines, per hand `h`, a zero-sum per-slot quantity `net_h[i]` with `sum_i net_h[i] = 0`,
and a **swing cap** `swingCap(module, h) >= max_i |net_h[i]|` proven for that module's rules. Over
the hands actually SCORED (a hand voided by the hard deadline is not scored):

    net[i]    = sum over scored hands of net_h[i]      # zero-sum: sum_i net[i] == 0
    NORM      = sum over scored hands of swingCap      # > 0 whenever a hand was scored
    scores[i] = 0.5 + net[i] / (2 * NORM)              # in [0, 1]; no clamp is needed
    win[i]    = (net[i] == max(net))                   # ties: every tied slot true

**Higher is better.** A seat that breaks even scores exactly 0.5, and the four scores sum to exactly
2.0 in every module. `|net[i]| <= NORM` by construction, so the score lands in [0, 1] with no
clamping and no special cases. If no hand was scored, every seat scores 0.5.

Per-module swing caps: euchre 4 (tight, proven by the lone march); spades 460 (proven by
130 + 100 on each side); hearts 19.5 (tight, proven by the moon); oh-hell 0.75 * (10 + cards).

**What the league ranks by:** the platform's Elo over `scores`, in one league across all four
variants, equally weighted, round-robin. The score is unit-free - a share of the same normalised
swing whatever the module - so a Euchre episode and a Hearts episode move Elo by the same amount,
and one leaderboard is what makes this a family rather than four unrelated boards. `results` also
carries the raw legible numbers (`points`, `teamPoints`, `tricks`, `bidsMade`) for the endcard.

Known and accepted: Spades' proven swing cap is far above typical play, so Spades scores cluster
nearer 0.5 than Euchre's do. Elo ranks by ordering, `win` is reported alongside, and the endcard
shows raw points, so the compression costs legibility nothing. A tighter, tuned normaliser would be
a free parameter with no principled value; a proven bound is not.

## The soft-play audit

`results.audit` is non-null for `hearts` and `oh-hell` and null for `euchre` and `spades` - in a
partnership game, letting your partner win IS the correct play and there is nothing to audit. It is
a pure function of the recorded event log, computed identically by the server and by the wasm replay
viewer, from the legal set recorded on every `play` event, so it cannot drift from the engine.

For each ordered pair of slots (a, b): `chance[a][b]` counts the tricks in which, at the moment a
played, b's card was the current best on the table and a's legal set contained a card that would have
beaten it; `yield[a][b]` counts those in which a declined to beat it; `yieldRate` is the ratio.
`field[a]` is the same rate against everyone. For hearts, `discards[a][b]` counts tricks won by b on
which a was void in the led suit, and `gift[a][b]` sums the penalty points a's thrown card carried
into them.

**No flags, no thresholds, no penalties.** The audit reports the matrices, the per-seat field rate,
and a `power` block (`hands`, `chanceMin`, `chanceMedian`) so a four-hand episode's numbers are read
as the weak evidence they are. It is a diagnostic and is NEVER an input to the ranking: it never
flags a pair, never adjusts a score and never disqualifies a seat.
