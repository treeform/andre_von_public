# Chorus scoring

One function scores the first `n` bars of a grid. It is deterministic, public, and it is the ONLY
scoring path in the game - the live scoreboard, the results, the replay check and the
counterfactual all call it.

> **`S = 100 x (0.35*C + 0.25*V + 0.25*R + 0.15*N)`, in `[0, 100]`. Higher is better.**

Each component is clamped to `[0, 1]` on its own.

## C - consonance (weight 0.35)

Over every *sounding pair*: every (bar, step) and every voice pair `u < v` with both tokens at
least 0. Interval class `ic = |midi(u) - midi(v)| mod 12`, weighted:

| `ic` | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `w` | 0.6 | 0.0 | 0.3 | 1.0 | 1.0 | 0.7 | 0.1 | 1.0 | 0.9 | 0.9 | 0.3 | 0.0 |

`C` is the mean of `w` over all sounding pairs, and **`C = 0` when there are none** - silence is
not consonance.

*Worked example:* a bar where Bass holds degree 0 and Alto holds degree 4 on the same four steps
gives four sounding pairs, each a perfect fifth (`ic = 7`, `w = 1.0`), so `C = 1.0`. Move the Alto
to degree 1 and every pair becomes a minor second (`ic = 1`, `w = 0.0`) and `C = 0.0`.

## V - voice leading (weight 0.25)

For each voice, take its sounding notes in time order across the whole span (rests skipped, bars
concatenated). For each consecutive pair, `L = |delta midi|`:

| `L` | 0-2 | 3-4 | 5-7 | 8-12 | >12 |
|---|---|---|---|---|---|
| motion score | 1.00 | 0.85 | 0.60 | 0.30 | 0.00 |

`Vraw` is the mean over all motions in all voices (0 when there are none).

**Parallel-perfect penalty.** For each voice pair `u < v` and each consecutive global step index
`i, i+1` where all four of `(u,i) (v,i) (u,i+1) (v,i+1)` sound and BOTH voices move, the pair is
*eligible*; it is *parallel* when `ic(i) == ic(i+1)` and `ic(i)` is 0 or 7. With
`p = parallel / eligible`:

> **`V = Vraw x (1 - 0.5 x p)`**

*Worked example:* a single voice moving only by one or two scale steps scores `V = 1.0`. Two voices
moving together in fifths through a whole bar have `p = 1`, so `V` is exactly halved.

## R - rhythmic coherence (weight 0.25)

Three parts.

- **Pulse `Ra`** - per onset, by its step index `k` inside the bar: `k` in {0,4,8,12} scores 1.0,
  {2,6,10,14} scores 0.7, odd `k` scores 0.4. `Ra` is the mean over all onsets (0 when there are
  none).
- **Density `Rb`** - `density = onsets / (n * 16 * 4)`. The denominator is **always four voices**,
  in the counterfactual too. `Rb = 1` for density in `[0.20, 0.55]`; it rises linearly 0 to 1
  across `[0.05, 0.20]`, falls linearly 1 to 0 across `[0.55, 0.85]`, and is 0 outside
  `[0.05, 0.85]`.
- **Interlock `Rc`** - the fraction of the `n * 16` step-columns in which the number of
  simultaneous onsets is 1, 2 or 3 - not 0 and not 4.

> **`R = 0.40*Ra + 0.35*Rb + 0.25*Rc`**

## N - novelty against your own earlier bars (weight 0.15)

For each voice `v` and each bar `b >= 1`: `sim(v,b)` is the largest number of positions in which
`grid[v][b]` agrees with any earlier bar of the same voice, divided by 16 (rests match rests).
`d = 1 - sim`, and `raw` is the mean of `d` over all voices and all bars `b >= 1` (`raw = 0.5` when
there is only one bar).

> **`N = max(0, 1 - 2 * |raw - 0.5|)`**

The target is that about **half** of a bar differs from its closest earlier sibling. Pure
repetition (`raw = 0`) scores 0 - and so does never repeating anything (`raw = 1`). Unbounded
novelty is noise; a peak at half-change is the musically honest reading.

An all-rest grid scores exactly `0.0`: `C = 0`, `V = 0`, every rhythm term 0, and `raw = 0` so
`N = 0`.

## Your score: the counterfactual

`mute(grid, v)` is the grid with every token of voice `v` replaced by a rest.

> **`credit(seat) = pieceScore(grid, n) - pieceScore(mute(grid, voiceOf[seat]), n)`**

Both sides call the identical function with no special cases. A muted voice's bars are still bars
(they count in the novelty mean, where 16 repeated rests match perfectly and pull `raw` down),
still columns (where they lower the interlock count), and still four voices in the density
denominator. That uniformity is the whole rule.

- **Higher is better.** A credit is a difference of two scores in `[0, 100]`, so it lies in
  `[-100, +100]`; in practice it sits in roughly `[-25, +25]`.
- **Credit is genuinely signed.** `C` is a *mean* over sounding pairs, so a voice less consonant
  than the piece's running average LOWERS `C` and earns a negative credit - deleting it would
  improve the piece. A voice that hammers every step pushes the interlock term toward the
  four-voice case and the density term past 0.55, and can also go negative. Prompts have to earn
  their seat.
- **Credits do NOT sum to the piece score.** Leave-one-out is not an exact decomposition, and
  nothing in the game pretends otherwise. `piece` is reported alongside as the shared, cooperative
  number.

## What the league ranks

`results.scores[i]` is `credit(i)`, rounded to six decimals, and the league ranks on the mean
episode score across a division's episodes - higher is better. `piece` is reported but does not
rank anybody.
