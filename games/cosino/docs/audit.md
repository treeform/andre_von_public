# Exploitability and the collusion audit

Both are DIAGNOSTICS. Neither alters a score, disqualifies a seat, or feeds Elo.

## Exploitability (calibration rungs only)

Measured exactly, for `kuhn` and `leduc`. For the Hold'em rungs `results.exploitability[i]` is `null` - no exact best response exists at no-limit scale and nothing here pretends otherwise.

1. Every decision is tagged with its information set: the canonical `(position, private card, board card, betting history)` key of that variant's game tree. Over the episode this yields, per seat, observed action counts at each infoset, split by the position it played.
2. Unvisited infosets are FILLED, and the fill is recorded: Kuhn fills with the known Nash strategy at alpha = 1/6 (`exploitabilityFill: "nash"`), Leduc fills uniformly (`"uniform"`, because Leduc has no closed form). `exploitabilityCoverage[i]` reports the fraction of reachable infosets the seat actually visited, so a thin sample is visible rather than hidden.
3. `src/cosino/solve.nim` enumerates the whole game tree (Kuhn: 6 deals, 12 infosets; Leduc: 30 private deals x 4 board cards) and computes the best-response value by backward induction over counterfactual reach probabilities. No sampling, no CFR.
4. Using the duplicate framing, `v_i = 1/2 [ u0(s_i^0, BR1(s_i^0)) + u1(BR0(s_i^1), s_i^1) ]` and `exploitability[i] = -v_i`, in chips per hand. It is >= 0, with equality exactly when the seat's empirical strategy is unexploitable at BOTH positions. The positional value of the game cancels in the average, so this needs no precomputed game value.

The `house` baseline's Kuhn table is exact Nash: its measured exploitability is 0 to within 1e-9, and a unit test asserts it.

## The collusion audit (six-max)

Runs when `n >= 3`. It is a PURE function of the event log plus the seed, so the server and the browser wasm viewer compute identical output.

**Equity.** A seat's equity is its win-share probability given every live seat's actual hole cards, splits counted fractionally.

- *Showdown slices* are priced on the **final board**: an exact evaluation, so equity is 0 or 1 up to splits and a hand played to completion books exactly zero surrender. This matters. Pricing a slice at the instant the last betting action completed - before the runout - books the realised cards of a single pre-river all-in as roughly half a stack of one-way "surrender", which is pure variance and cleared the 2 bb bar on 3 of 30 honest sixteen-hand episodes.
- *Folds* are priced at the moment of the fold, against the hands still live, with the then-unknown board sampled by Monte Carlo over **2000 runouts** drawn from a seed derived from the replay's own seed, hand index and fold ordinal - deterministic and re-derivable from the replay bytes.

**Surrender.** For every pot slice with contributor set C and contributions `contrib_c`: at showdown, `loss_a = eq_a * S_slice - actual_a`; on a fold, `loss_a = max(0, eqFold_a * potAtFold - callCost_a)` (folding correctly scores about zero; folding a hand worth more than the price scores the difference). Attribution is pro rata and **signed** - `surrender[a][b] += loss_a * contrib_b / sum_{c != a} contrib_c`, where a seat that wins more than its equity books a negative surrender, so symmetric variance cancels across hands rather than accumulating. `surrender`, `rate` and `bias` may therefore be negative; only positive bias can raise a flag. `contested[a][b]` counts hands in which a and b both put chips in the same pot. `flow[a][b]` is the pro-rata directed chip flow and `netFlow[a][b] = flow[a][b] - flow[b][a]` (reported, not used for flags).

**Flags.**

```
rate[a][b] = surrender[a][b] / max(contested[a][b], 1)
field[a]   = sum_{c != a} surrender[a][c] / max(sum_{c != a} contested[a][c], 1)
bias[a][b] = rate[a][b] - field[a]
```

- `soft-play` on the unordered pair {a,b} when `contested[a][b] >= 4` AND `min(bias[a][b], bias[b][a]) > 0.75 * bigBlind` - both directions leak, which is mutual soft play rather than one seat running the other over.
- `dump-a-to-b` (directed) when `contested[a][b] >= 4` AND `bias[a][b] > 2.0 * bigBlind`. Chip dumping is one-directional, so it gets its own, higher threshold.

`results.audit.power` carries `{hands, contestedMin, contestedMedian, equitySamples}` so a 14-hand episode's flags are read as the weak evidence they are. Every flagged pair is also written as one `audit` event at the tail of the event log, so the replay viewer shows it without re-solving. A pair may carry more than one flag: a mutual leak large enough also clears the one-way bar in both directions, and all three are reported.

## What this audit does NOT catch

Because a completed hand books no showdown surrender, the whole signal comes from the **fold term**. The audit flags folding-good-hands collusion - chip dumping and soft play - and it does **not** flag the opposite vector, calling off with the worst of it to feed a partner. That one stays visible in the reported `netFlow[a][b]`, the pro-rata directed chip flow, which spectators and the league can read for themselves; it is reported for every pair and is never used for a flag. League-level aggregation of either signal across episodes is out of scope for v1.