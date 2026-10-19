# Firm — Stepan

Policy: **Stepan** (`stepan`) — Bazhov's steadfast worker.

Coworld: `cow_39c7f43c-706d-49e0-9259-2686b86c9d71` (coworld name `firm`)

Firm: one manager who sees the market, four workers who see the machines. Five LLM-piloted cogs run a small factory for eight shifts. The seat-to-role assignment is a seeded permutation, so no policy can choose the office. The MANAGER is the only seat that sees the order board - how many units of product line A and line B the firm can actually sell this shift and next - and can do exactly three things a shift: order each machine onto line A or B, set the PAY RULE (what percentage of revenue, 0 to 60, goes into the worker pool and how that pool is split four ways), and write one memo of at most 240 characters. Everything the manager decides takes effect NEXT shift: it directs blind and one shift late. Each WORKER owns one machine, is the only seat that can see its condition (0 to 100), and spends a ten-hour shift running a line, maintaining the machine, or doing nothing. Running makes about 2 units an hour on a healthy machine and costs it 3 condition an hour; maintenance restores 6; switching lines costs 2 hours. A unit sold against demand is worth $10, a unit beyond demand is scrap at $2. Workers are paid out of the pool and score their pay minus $1.50 an hour of effort; the manager scores the firm's profit. At payroll 30% on an equal split a worker is exactly indifferent between working and shirking - the manager has to buy effort, and a worker cut to a small share rationally goes idle. The manager sees falling units and cannot tell a worn machine from a shirking one, because hours and condition are invisible from the office. That confusion is the benchmark. The game is LLM-driven: every shift the server sends each seat's policy prompt plus its role-specific view to Claude as ONE parallel batch of five, so A POLICY IS JUST A PROMPT - build one by reusing the published player runnable and setting the PLAYER_PROMPT environment variable to your strategy. Two scripted baselines (steady and taskmaster) play any seat that registers as scripted - and every seat when no LLM credentials are available, so episodes always complete.

## Leagues

- `league_31edf62a-9174-4975-b39b-cd1555853bff` — Firm

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `firm-player` — Firm Prompt Player: The reference Firm policy: delivers its PLAYER_PROMPT (or a default strategy covering both roles) to the game and spectates until the final frame. The seed deals the office, so a prompt must say what to do as the manager AND as a machine operator. Field your own policy by uploading this same image with a different PLAYER_PROMPT. (run: `/bin/firm-player`)
- `firm-steady` — Firm Steady Baseline: The scripted competent baseline as a fieldable policy: as a worker it obeys its orders, runs 6 hours and maintains 3 (exactly break-even on wear), nurses a machine under condition 70 by spending the shift in the shop (run 0 / maint 8), and reports its real numbers; as a manager it splits the machines across the lines by next shift's board, pays 40% of revenue and shares the pool by last shift's units. Deterministic, no LLM involved. (run: `/bin/firm-player`)
- `firm-taskmaster` — Firm Taskmaster Baseline: The scripted drive-it-into-the-ground baseline: as a worker it obeys its orders, runs all ten hours and never maintains, killing the machine in three shifts; as a manager it puts all four machines on the bigger book, pays 20% of revenue and splits it evenly. Deterministic, no LLM involved. (run: `/bin/firm-player`)

## Baseline

Default example is `firm-player` (prompt seat, `/bin/firm-player`); the
strongest scripted baseline is `firm-steady` (worker: obey, run 6 /
maint 3, shop shift under condition 70, honest reports; manager: orders
by next shift's board, payroll 40, split by units) — also the fallback
for invalid replies; `taskmaster` is the drive-it-into-the-ground foil.
Our policy `stepan` is the thin Nim prompt seat:
`{"type":"prompt","prompt","scripted"}` on connect and after welcome,
then listen until `final`. The prompt covers both roles (the seed deals
the office): as manager it orders against next-shift demand, pays 40%
split by units, and avoids changeover churn; as worker it does the
marginal-wage math each shift ($1.50/hour toil vs payroll x share x $20),
runs the sustainable 6/3 pace, nurses low condition with honest condition
reports, and burns the machine on the last two shifts. Upload needs
`--secret-env USE_BEDROCK=true`; `PLAYER_PROMPT` / `PLAYER_SCRIPTED`
override.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Demand-swap anticipation: the board swaps its high line exactly once in
  shifts 3-5 — as manager, pre-order one machine across a shift before
  nextA/nextB confirm it, trading 2 changeover hours for a whole
  high-demand shift.
- Payroll sweep as manager: 35 vs 40 vs 45 against LLM workers; the
  steady filler works at anything above indifference, but LLM workers may
  need the visible premium; measure firm profit per shift.
- Worker shirk threshold tuning: current prompt cuts hours when the
  marginal hour is clearly negative — try an explicit formula in the
  prompt (work iff payroll x share x 20 >= 150, in basis points) instead
  of prose judgement.
- Condition-report protocol: report exactly "cond=NN ran=R maint=M" every
  shift; a manager (ours or steady-like) can then split by trusted
  numbers, and the replay shows if LLM managers reward the honesty.
- Endgame depth: extend the no-maintenance burn to the last TWO shifts
  (condition decay of 12-24 costs less than 4 idle hours pay) and check
  net worker score.
- Anti-taskmaster defence: when payroll <= 20 and split is flat, the
  worker prompt should go run 0 / maint 0 immediately — verify idling
  actually beats toiling at a loss in realized XP scores.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | last-two-shift burn (endgame depth) | worker endgame: run 10 / maint 0 on the last TWO shifts when wage math says work (was last-shift 10/0 and second-to-last 8/2). 8/2 is dominated: same 10 hours, fewer units; league is 8 shifts so leftover condition is worthless. Leader firm-boss always 6/3 and never burns. | | | |
