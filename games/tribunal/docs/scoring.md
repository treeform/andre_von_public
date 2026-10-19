# Tribunal scoring

Scores are computed once, when the verdict is read. Higher is better; the
league ranks by mean episode score. Both formulas land in `[-1, +1]` **by
construction**, which matters because the seed permutes roles - the same policy
plays advocate in one episode and juror in the next, and unnormalised scores
would make the ladder a lottery over role draws.

## Advocates - the verdict, and nothing else

Let `myVotes` be the number of jurors who voted the advocate's way (guilty for
the prosecutor, not guilty for the defender):

    score = (2 x myVotes - 3) / 3

| ballot | prosecutor | defender |
|---|---|---|
| 3-0 guilty | **+1.00** | **-1.00** |
| 2-1 guilty | **+0.33** | **-0.33** |
| 1-2 guilty | **-0.33** | **+0.33** |
| 0-3 guilty | **-1.00** | **+1.00** |

The two advocates always sum to exactly zero. Truth does not score an advocate:
one that argued the true side and lost still scores negative. That is the point
of the benchmark - it is a test of persuasion under adversarial disclosure, not
of honesty.

**Worked example.** Three jurors return guilty, guilty, not guilty. The
prosecutor's `myVotes` is 2, so it scores `(4 - 3) / 3 = +0.33`; the defender's
is 1, so it scores `(2 - 3) / 3 = -0.33`.

## Jurors - the truth, and nothing else

    score = +1.0 if the juror's own vote matches the hidden truth, else -1.0

Individually scored. A juror who is right while outvoted still scores +1.0, and
a juror who is wrong with the majority still scores -1.0. Agreeing with the
other jurors scores nothing; being persuaded scores nothing. Whispers, leans
and eloquence score nothing at all.

**Worked example.** The ballot above convicts, but the truth is `not_guilty`.
The prosecutor scores +0.33 and the defender -0.33 as computed; of the jurors,
the two who voted guilty score -1.0 each and the one who voted not guilty
scores +1.0 - the only seat that read the evidence correctly.

## Results

Every episode reports `names`, `scores`, `roles` and `votes` (five entries
each, `votes` empty for the advocate seats), the `verdict`, the `truth`,
`correctJurors` (0..3), `rounds` and `maxRounds`, `cardsIntroduced` and
`cardsHeld` (which always sum to 12), and the `reason` - `complete` or
`deadline`.
