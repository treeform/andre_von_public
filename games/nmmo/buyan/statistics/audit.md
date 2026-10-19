# Statistical audit

Five hypotheses and four planned cumulative looks consume alpha
0.05 / (5 * 4) = 0.0025 per two-sided test. The union bound controls
the probability of any false positive across the declared family without
requiring independence across looks or ideas. This does not justify adding
new looks or ideas to the same budget.

The paired sign statistic counts positive and negative candidate-minus-
baseline episode score differences. Under a symmetric sign null, the number
of positive signs among nonzero differences is binomial with p = 0.5.
The exact two-sided p value is twice its smaller tail, capped at one.
Zero differences stay in episode means but contribute no sign information.
This tests the sign tendency, not a confidence interval for mean advantage.

Independent arithmetic anchors:

- Ten wins, zero losses: 2 / 1024 = 0.001953125.
- Nine wins, one loss: 2 * (1 + 10) / 1024 = 0.021484375.
- All ties: no sign information, p = 1.
- Three hundred wins: p = 2^-299, no underflow in float64.

Required integration review:

- Pin network source, co-world version, every policy version and opponent
  seat count. Never infer a permissive field from the first episode.
- One episode gives one score difference. Repeated seats are not samples.
- A verified strategy trigger is an issued action change, not surviving
  long enough to confirm its later result.
- Excluding untriggered games makes this conditional evidence. Triggered
  games can differ from the full league population, so conditional support
  cannot alone authorize submission.
- Wait until all registered requests have resolved before support can pass.
  A subset selected by which episodes completed first can bias a result.
- Failure exclusions and missing telemetry can also select a subset. Show
  counts, audit the failures, and require the dashboard gate separately.
- A source label on a local JSON file is provenance bookkeeping. Authentic
  CLI captures and their XP links remain necessary external evidence.

The independent `signs.nim` module passed `nim check` and its synthetic
tests, including all four looks and integer overflow rejection. Grok
reviewed the recurrence and received the supervisor's results.

The first full parser pass is written. Its compiler and input-boundary
fixes are pending. No hosted score or policy decision has been made by
this tool.
