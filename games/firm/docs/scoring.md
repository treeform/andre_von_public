# Firm scoring

Computed once, when the episode settles. Let `n` be the shifts actually played.
If `n == 0` every score is `0.0`. **Higher is better everywhere.**

- **Worker seat**: `score = workerNet / (n x 30.0)`, where
  `workerNet = sum over shifts of (pay - toil)`. A worker scores its take-home
  pay net of the effort it cost - negative if it toiled for less than nothing.
- **Manager seat**: `score = firmProfit / (n x 300.0)`, where
  `firmProfit = sum over shifts of (revenue - pool)`.

**The league ranks by `results.scores[seat]`** - that normalized per-shift net -
and the ladder ranks seats by mean episode score. There is exactly one ladder
statistic and both roles are on it.

## Why the scales

Raw profit runs in the hundreds a shift and raw worker pay in the tens. Since the
seed permutes roles, an un-normalized score would make the ladder a lottery over
role draws. The scales are calibrated on a competently run firm: four machines at
run 6 / maint 3 with fresh condition make 12 units each (48 total); against a
board of A 33 / B 15 with three machines on A and one on B that is 45 sold and 3
scrapped, so `revenue = 10 x 45 + 2 x 3 = $456`. At payroll 40 the pool is
$182.40, each worker is paid $45.60 against $13.50 of effort (net $32.10, score
**1.07**) and the firm keeps $273.60 (score **0.91**). At payroll 30 the same
floor gives the worker 0.69 and the manager 1.06. Both roles land near +1 when the
firm is run well, and the payroll dial is a visible tug between them.

## The marginal hour

One extra running hour on a healthy machine makes 2 units, worth **$20** if they
are sellable. Of that, `payroll%` goes to the pool and the worker keeps its
`share%` of the pool: at payroll 30 and an equal 25% split that is
`0.25 x 0.30 x 20 = $1.50` - exactly `ToilPerHour`. **At the default pay rule a
worker is precisely indifferent between working and shirking.** The manager has to
buy effort: at payroll 40 the same hour pays the worker $2.00 against $1.50 of
toil and the manager still keeps $12. A worker cut to a 10% share earns $0.80 an
hour at payroll 40 and rationally goes idle - that is the mutiny, and it is
mechanical, not scripted.

Units made on the *wrong* line fetch salvage $2, so an hour on a mis-directed
machine yields $4 of revenue and pays almost nobody: a bad directive destroys the
incentive to work at all.

## Maintenance, the hidden half

`3 x run` of wear against `6 x maint` of repair makes **run 6 / maint 3** the
sustainable pace (net zero, one hour idle). Run 7 / maint 3 drifts down 3 a shift;
run 10 / maint 0 burns 30 a shift and halves a machine's output in three shifts.
Maintenance costs the worker effort now and pays back in future output, most of
which the firm keeps - so an underpaid worker rationally lets the machine die. The
manager sees the falling units and cannot tell that from shirking, because hours
and condition are invisible from the office. That confusion is the benchmark.

## What results report

`names` (policy names), `scores`, `roles`, `pay` (each worker's NET, 0.0 on the
manager seat), `units` (0 on the manager seat), the firm's `revenue`, `wages` and
`profit`, `shifts`, `maxShifts` and `reason`.
