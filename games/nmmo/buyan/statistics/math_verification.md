# Sign-test math verification

Independent review of `statistics/signs.nim` recurrence and thresholds, plus
supervisor-reported outcomes. Post-fix `nim check` / `nim r` remains the
supervisor's responsibility; this note does not claim a compiler run after
the overflow-bound change.

## Recurrence

Two-sided exact sign test at \(p = 1/2\), ties omitted, \(n = w + \ell\),
\(k = \min(w, \ell)\):

\[
P = \min\left(1,\ 2 \sum_{i=0}^{k} \binom{n}{i} 2^{-n}\right)
\]

Start at \(\mathrm{term} = 2^{-n} = \binom{n}{0} 2^{-n}\). The step
\(\mathrm{term} \leftarrow \mathrm{term} \cdot (n-i)/(i+1)\) is the exact
ratio \(\binom{n}{i+1}/\binom{n}{i}\), so the accumulator is the lower tail
without computing factorials. For \(n \le 300\), \(2^{-n}\) is a normal
float64 (exponent well above \(-1022\)).

Independent arithmetic on the synthetic fixtures:

| wins, losses | \(n\) | tail sum | \(P\) |
| --- | --- | --- | --- |
| 10, 0 | 10 | \(2^{-10}\) | \(2 \cdot 2^{-10} = 2^{-9} = 1/512 = 0.001953125\) |
| 9, 1 | 10 | \(11 \cdot 2^{-10}\) | \(22/1024 = 0.021484375\) |
| 0, 0 | 0 | (no non-ties) | 1 |
| 5, 5 | 10 | doubled lower half including the median exceeds 1 | \(\min(1,\cdot)=1\) |
| 300, 0 | 300 | \(2^{-300}\) | \(2^{-299}\) |

These match the supervisor's independent arithmetic and the passing
`nim r statistics/signs_tests.nim` fixtures. No hosted score was measured.

## Threshold and status order

`PerLookAlpha = 0.0025`. All-wins at the first look is
\(0.001953125 \le 0.0025\), so `supporting_sign_test`. One loss at \(n=10\)
is \(0.021484375 > 0.0025\), so that branch is `inconclusive` when the mean
difference is positive and wins exceed losses.

Status order after validation: unresolved \(\to\) `awaiting_completion`;
\(n < 10\) \(\to\) `insufficient_data`; \(n \notin \{10,30,100,300\}\) \(\to\)
`off_schedule` (this includes \(n > 300\), so `signP` is not called);
`meanDiff <= 0` or `wins <= losses` \(\to\) `negative`; then the alpha cut;
else `inconclusive`.

## Overflow bounds (post-fix, not yet supervisor-run)

Adding `wins+losses` before a range check wraps or raises `OverflowDefect`
at `high(int)`. `signP` now rejects each argument `> 300` first, then
`total > 300` (and negatives). After those guards the sum is at most 600.

`supportStatus` no longer uses `n < wins+losses`. It requires nonnegative
counts, then `wins <= n`, then `losses <= n-wins`. The second compare is
not evaluated when `wins > n`; `n-wins` cannot overflow when `wins <= n`
and both are nonnegative. `supportStatus(high(int), high(int), high(int), 1.0)`
therefore maps to `BuyanMathError` without an overflow defect.

Both procs declare `{.raises: [BuyanMathError].}`.

## Supervisor outcomes (pre-fix run)

- `nim check statistics/signs_tests.nim` passed.
- `nim r statistics/signs_tests.nim` passed every synthetic fixture.
- Independent arithmetic agreed on \(p=0.001953125\) (10 wins),
  \(p=0.021484375\) (9 wins, 1 loss), all-ties \(P=1\), and
  300 wins \(= 2^{-299}\).
- No hosted score measured.

The high-int error fixtures and overflow-safe guards were added after that
run. Confirming them is a supervisor compiler/test job.
