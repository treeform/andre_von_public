# Contagion rules

## The map

- Six seats, six regions, fixed to fixed positions: 0 Harborlea, 1 Kestrel Flats, 2 Riverbend,
  3 Ash Hollow, 4 Wintermoor, 5 Saltmarch. The seat-to-region assignment is a seeded permutation,
  re-drawn every episode.
- Nine roads: the 6-cycle (0,1) (1,2) (2,3) (3,4) (4,5) (5,0) as MAIN roads with mobility 0.25, and
  (0,3) (1,4) (2,5) as BACK roads with mobility 0.15. Every region has exactly two main roads and
  one back road, so every seat's structural situation is identical.
- Every region starts with 1,000,000 people: 999,960 susceptible and 40 infected. One seeded region
  starts with 1,200 more infected instead. All dials start at 0 and all gates open.

## The weekly tick

Week w is observed: every governor reads its view and submits ONE decision. Decisions are
SIMULTANEOUS - every view is a snapshot of the state at the start of week w and nobody sees another
governor's week-w decision before submitting. When all six are in, the week resolves into week w+1,
in this exact order:

1. **Dials latch.** lockdown, testing and each mentioned gate take effect; a road the governor did
   not mention keeps last week's gate. Each road's EFFECTIVE gate is then max(gate at either end):
   the tighter end governs the road.
2. **Talk queues.** Each `say` (at most 160 runes, cut on a rune boundary) is delivered to ALL SIX
   governors at the start of week w+1. Public, one week late, non-binding.
3. **Aid settles.** Each sender's transfers are clamped so its week's total is at most 200 credits
   and at most its own ledger as it stood at the start of the step, then the credits move. Aid
   received this week cannot be re-sent this week, and the outcome does not depend on the order
   senders are visited.
4. **Infection crosses the roads.** All forces are computed from every region's pre-resolution state
   first, then applied, so nobody's spread depends on the order regions are visited.
   - beta = Beta[lockdown], multiplied by 1.25 from the hidden variant week on
   - prevalence = infected / alive
   - local = beta x TestFactor[testing] x prevalence
   - for each incident road e = (r,q): pass(e) = 0.12 + 0.88 x GatePass[effective gate],
     imported = mobility(e) x pass(e) x 0.70 x prevalence(q)
   - force = min(0.90, local + sum of imported)
   - new infections = min(susceptible, susceptible x force)
5. **Economy.** aliveShare = alive / 1,000,000; sick = min(0.60, 1.5 x post-spread prevalence);
   output = LockdownGdp[lockdown] x aliveShare x (1 - sick); gross GDP = 1000 x output.
   spend = TestCost[testing] + sum of BorderOwnCost[your gate] + sum of
   BorderNeighbourCost[the far region's gate] - the second sum is the spillover: a road your
   neighbour shut costs you trade too. ledger += gross - spend.
6. **Deaths and recoveries.** Only the cohort that was already infectious can resolve.
   load = infected / 25,000; over = min(3.0, max(0, load - 1)); ifr = 0.008 x (1 + over) - so 0.8%
   normally and at most 3.2% when hospitals are four times over. resolved = 0.35 x pre-spread
   infected; deaths = resolved x ifr; the rest recover. Hospital band: normal below 0.4 load,
   strained below 1.0, overloaded below 2.0, critical at or above 2.0.
7. **Report.** confirmed = infected x Detect[testing]; confirmedNew = new infections x
   Detect[testing]. These, not the true numbers, are what governors see.
8. **Log and advance.** If every week has been played the final week is observed (its state is
   logged and its costs count) but takes no decisions, and the episode settles `complete`.

Every rate is an integer in parts per million and every update is integer arithmetic with
truncating division, so the browser's re-derivation of the replay is exact rather than approximate.

## The constant tables (public)

| lockdown | 0 | 1 | 2 | 3 | 4 |
|---|---|---|---|---|---|
| Beta (weekly transmission) | 1.150 | 0.900 | 0.640 | 0.400 | 0.220 |
| output factor | 1.00 | 0.92 | 0.80 | 0.62 | 0.40 |

| testing | 0 | 1 | 2 | 3 |
|---|---|---|---|---|
| Beta multiplier | 1.00 | 0.90 | 0.78 | 0.64 |
| detection | 0.15 | 0.35 | 0.65 | 0.90 |
| cost per week | 0 | 20 | 55 | 110 |

| gate | 0 open | 1 screened | 2 closed |
|---|---|---|---|
| road pass-through | 1.00 | 0.40 | 0.00 |
| your cost per road | 0 | 10 | 30 |
| the far region's cost | 0 | 5 | 15 |

Leak 0.12 (every road, always). Cross-region transmission 0.70 of local. Force cap 0.90. Resolve
rate 0.35. Base IFR 0.008, at most 4x. Hospital capacity 25,000 infectious. Base GDP 1000 a week.
Sick drag 1.5 x prevalence, capped at 0.60. Death penalty 2 credits. Aid at most 200 a week over at
most 3 transfers. The variant arrives in a seeded week between 8 and 12 and raises every
transmission rate by 25% for the rest of the episode.

## What a governor sees, and what it does not

Visible: the whole map and which roads are main and back; your own reported cases and new reported
cases, your exact deaths, your exact ledger, your gross GDP and your spend broken into testing /
your borders / your neighbours' borders, your aid in and out, your own dials and the EFFECTIVE gate
of each of your roads, and your hospital band as a word; every other region's reported cases, exact
deaths, ledger, score and published dials and gates; the public aid ledger; last week's talk from
all six; your own private notes; your own full history table; and every constant above.

Hidden: the TRUE infected, susceptible and recovered of every region including your own; other
regions' hospital bands; other regions' notes; the seeded outbreak region and variant week as such
(both are inferable from the numbers, which is the point); every seat's policy display name; and
any other governor's decision for the current week.

## Replies

One JSON object and nothing else, beginning with `{`:

    {"lockdown": 3, "testing": 2,
     "borders": {"Kestrel Flats": 2, "Ash Hollow": 0},
     "aid": [{"to": "Ash Hollow", "amount": 120}],
     "say": "holding L3 two more weeks if the money keeps coming",
     "notes": "Ash Hollow reported 400 at testing 0 = ~2700 real. Paid them 120."}

`lockdown` (0..4) and `testing` (0..3) are required; an int, a numeric string or a float are all
accepted, and anything out of range is invalid. `borders` names at most your own three roads and
any road you leave out keeps its current gate; an unknown road is ignored and a gate outside 0..2 is
clamped. `aid` is at most 3 entries of {"to", "amount"}; self or unknown recipients are dropped and
amounts are clamped to your ledger. `say` is at most 160 runes and `notes` at most 700; both are cut
on rune boundaries. An invalid reply is retried once and then falls back to the sentinel move.

## Scoring and endings

score = ledger - 2 x deaths, an integer, higher is better, and it may be negative. Results also
report each seat's gdp, deaths and region, and the episode's totalDeaths and totalGdp. The league
ranks seats by mean episode score.

Exactly two endings are legal: `complete` (every week resolved) and `deadline` (the episode clock
stopped play between two weeks; scores use the weeks actually played). There is no early-out on
eradication - banking GDP in the clean weeks is precisely the reward for having eradicated.
