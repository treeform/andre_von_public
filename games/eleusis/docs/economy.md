# Eleusis economy

```
score(seat) = knowledge(seat) + credit(seat) - experimentCost x experiments(seat)
```

Higher is better, and a score may be negative: a seat that runs 24
experiments and never answers a test correctly finishes at -24. The league
ranks by mean episode score.

## Knowledge — the rivalrous half

At each prediction test, seat j with c_j correct answers earns
`knowledgePool * c_j / sum(c)` (default pool $20.00 over 6 strips). Nobody
correct pays nobody. Because it is a share, every rival you teach takes a
slice of your own pool — which is exactly why publishing is not free.

## Citation credit — the cooperative half

For each test strip x and each seat j that answered x CORRECTLY, let A(x, j)
be the set of seats a != j that authored a corkboard fact whose strip is at
Hamming distance exactly 1 from x (it differs in exactly one of the four
positions) and that was published BEFORE this test opened. If A(x, j) is
non-empty, a pot of `citePot` (default $0.50) is split equally among its
members. An author is paid at most once per (strip, confirmer) however many
of its facts support x.

**Citation rings do not pay.** Credit accrues only for a published result
that a DIFFERENT seat's passing prediction later confirms, on a strip nobody
has ever tested. Self-citation is impossible by construction, a duplicate
publication has no author, and no arrangement between seats can manufacture a
correct prediction about a strip the machine has never been shown.

## The tuned ratio

With the defaults (experimentCost 1.0, knowledgePool 20.0, citePot 0.5,
testStrips 6, five seats, four tests):

- teaching one rival one extra correct answer costs you roughly
  `20/sum(c) - 20*c_you/sum(c)^2` — about $0.6 to $1.0 of pool share per test;
- one well-placed publication sits one token away from up to 12 strips,
  realistically supports one or two of the six test strips, is confirmed by
  two to four rivals, and pays `0.5 x confirmers / authors` — about $0.5 to
  $2.0 per test.

So publishing pays precisely when your result is informative to others AND
near the frontier. The knife edge is configuration, not code: the
`open-science` variant raises citePot to $1.50 and the `closed-shop` variant
drops it to $0.10, so the league can watch the behaviour flip.