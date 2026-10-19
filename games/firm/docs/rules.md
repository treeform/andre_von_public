# Firm rules

## Seats and roles

- Exactly five seats. `RoleNames = ["Manager", "Worker"]`: one Manager and four
  Workers, dealt by a **seeded permutation** of `[0, 1, 1, 1, 1]`. A policy
  cannot choose to be the manager, and no slot is structurally stuck on the
  floor.
- Machines are numbered **1 to 4** for humans and belong to the four worker
  seats in ascending seat order.
- Every seat plays under an anonymous cog alias drawn from the seed. Policy
  names are spectator-side only.

## The floor

Two product lines, A and B. Each machine is *set to* one line at a time and
starts at `condition 100`, with machines 1-3 set to A and machine 4 to B.

| field | who sees it |
|---|---|
| `setup` (the line the machine is on) | everyone |
| `order` (the line the manager ordered) | everyone |
| `units` delivered last shift | everyone |
| `pay` last shift | everyone |
| `condition` 0..100 | its worker only |
| `run` / `maint` hours | its worker only |
| `toil` (the worker's effort cost) | its worker only |

The **order board** is the manager's private information: `demandA` and
`demandB` per shift. One level is high (30..36), the other low (12..18), and
they swap once at a seeded `switchShift` in 3..5. The manager sees this shift's
and next shift's numbers, and the whole realized history - never further ahead.
A unit sold against demand pays `Price = $10`; a unit made beyond demand is
scrap at `SalvagePrice = $2`.

## A shift, in order

1. **Open.** The orders, payroll and split the manager announced last shift come
   into force; last shift's worker reports reach the manager; a `shift` event is
   recorded. At shift 0 the orders are each machine's own setup, `payroll = 30`,
   `split = [25,25,25,25]` and the standing directive is
   "Standing order: machines 1-3 on line A, machine 4 on line B. Six hours
   running, three on maintenance."
2. **Deadline check**, before the batch, never mid-shift.
3. **Collect.** All five seats decide **simultaneously**, in one parallel LLM
   batch. Nothing decided in shift `s` is visible to any other seat before
   shift `s + 1`.
4. **The manager's memo** is applied first: `orders`, `payroll` (0..60) and
   `split` are stored **for shift s+1**; the directive is stripped, newlines
   collapsed and truncated at 240 runes; an empty directive leaves the standing
   one unchanged.
5. **The four workers** are applied in machine order. `run` and `maint` are each
   0..10 and together at most 10; the line is A or B; the report is capped at
   120 runes.
6. **Resolve**, per machine, deterministically:
   - changing line costs `ChangeoverHours = 2` of the running hours;
     `hours = max(0, run - changeover)`;
   - `q = 0.5 + 0.5 x condition/100`, on the condition at the START of the shift;
   - `units = floor(2.0 x hours x q)`;
   - `condition = clamp(condition - 3 x hours + 6 x maint, 0, 100)`;
   - `toil = 1.50 x (run + maint)`.
7. **Sell.** `sold = min(produced, demand)` per line; the rest is scrap.
   `revenue = 10 x sold + 2 x scrap`.
8. **Pay.** `pool = revenue x payroll/100`; `pay[machine] = pool x share/100`;
   `profit = revenue - pool`.
9. **Score.** `workerNet += pay - toil`; `firmProfit += profit`.
10. A `settle` event records the whole settlement, then the next shift opens.

The manager acts on every shift including the last; the last memo is recorded and
rendered but governs nothing.

## What each seat sees

- **The manager** sees the board (this shift and next, plus the realized
  history), the prices, every machine's number, operator alias, setup, order,
  units and pay, the share table, the ledger, last shift's reports, and its own
  notes. It **never** sees any machine's condition, any worker's hours or effort,
  or demand more than one shift ahead.
- **A worker** sees its own machine's condition, setup, order, hours, units, pay
  and effort, the standing directive, the pay rule in force including all four
  shares, the public shop floor (every machine's setup, order and units last
  shift), its own pay history, and its own notes. It **never** sees the order
  board, the prices, the firm's revenue or profit, another machine's condition,
  or another worker's report.

## Replies

Manager: `{"orders": ["B","B","A","A"], "payroll": 40, "split": [30,30,20,20],
"directive": "...", "notes": "..."}`. An unrecognised or missing order keeps that
machine's previous order; a split that does not sum to 100 is renormalized by
largest remainder; a missing or out-of-range payroll is invalid.

Worker: `{"line": "B", "run": 7, "maint": 3, "report": "...", "notes": "..."}`. An
unrecognised or missing line keeps the machine's current setup; a missing or
out-of-range `run`, or `run + maint > 10`, is invalid.

Invalid means one retry with a hint, then the `steady` scripted baseline. Every
recorded string is truncated on RUNE boundaries.

## Endings

- `complete` - all shifts resolved.
- `deadline` - the play deadline (60% of `episodeTimeoutSeconds`) was reached
  between shifts. Scores are normalized by the shifts actually played, so a short
  honest episode is on the same scale as a full one. There is no other ending.
