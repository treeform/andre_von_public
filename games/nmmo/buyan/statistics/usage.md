# Hosted XP paired comparison

Nim library and CLI for one planned baseline seat versus one candidate
seat inside the same hosted episodes. Output is support-only. It never
authorizes submission.

All scores in `tests.nim` and any CLI fixture files are synthetic. They
are not hosted XP scores.

## Command

```
nim r compare.nim <plan.json> <activations.json> <episodes.json>...
```

No flags. Alpha, looks, and membership are fixed by the plan and the
constants below.

```
nim check comparisons.nim
nim check compare.nim
nim r tests.nim
```

Run those from this directory. The supervisor runs Nim diagnostics.

## Plan

The plan pins every identity. Results never supply a different field.

```
{
  "source": "softmax-hosted-xp",
  "experiment": "armor",
  "coworld_id": "cow_6272bfca-6bfa-4268-be2c-9ee35f669cfc",
  "coworld_version": "0.1.5",
  "synthetic": true,
  "baseline": {"policy_name":"buyan","version":1,
    "policy_version_id":"a611afbe-e669-418f-99ae-89251052d393"},
  "candidate": {"policy_name":"buyan-armor","version":1,
    "policy_version_id":"UPLOAD_ID_REQUIRED"},
  "opponents": [
    {"policy_name":"relh-nmmo-consensus","version":1,
      "policy_version_id":"87adca41-a779-43a0-addf-282af50800a8","seats":2},
    {"policy_name":"nmmo-opt","version":6,
      "policy_version_id":"a319845e-01db-4d23-a938-3f4ed55f02be","seats":2},
    {"policy_name":"daveey-nmmo-nim","version":11,
      "policy_version_id":"ee828572-195d-4318-bdbb-0b4cb2bc1295","seats":2}
  ],
  "requests": [{"xp_id":"xreq_actual","episodes_file":"episodes.json",
    "episode_count":10}]
}
```

Each request requires a positive `episode_count`. The matching episodes
file must contain exactly that many entries so a partial page cannot
become false significance.

Episode files are saved `coworld xp-request episodes <xreq> --json`
arrays, or objects with `episodes` or `entries`. An array has no XP id;
the plan supplies it. If a wrapper `id` exists it must match. Local
files cannot prove network authenticity cryptographically.

Every CLI episodes path must match a plan `episodes_file`. Extra files,
repeated files, and repeated request ids are errors.

## Design

Exactly one baseline seat and one candidate seat per episode. Six
opponent seats, multiset-matched regardless of rotation. Unexpected
identity, opponent count, source, coworld, or version is fatal, including
on failed episodes. A missing comparison seat is excluded as
`missing_participant`.

One observation is candidate minus baseline in the same completed
episode. Seats are not independent samples.

Included episodes must be completed, with finite scores for both
comparison seats, and verified positive activation evidence
(`verified`, positive `trigger_count`, nonempty `log_path` and
`metric`). Activation files are not a score source.

Exclusion reasons, one primary per episode, in order:
missing_participant, failed, cancelled, pending (all unresolved
nonterminal statuses), missing_score, missing_evidence,
unverified_evidence, not_triggered.

Failed and cancelled are terminal. Pending, running, submitted, and any
other nonterminal status are unresolved. If any registered episode is
unresolved, `gates.status` is `awaiting_completion` even when the
completed triggered subset length equals a look. That blocks selecting
only fast-completing episodes.

## Sign test and gate

P = min(1, 2 * sum_{i=0}^{min(w,l)} C(w+l, i) / 2^(w+l)).
Ties are exact zero, kept in paired n, omitted from sign-test n.

Family alpha 0.05, five hypotheses, looks [10, 30, 100, 300], per-look
two-sided alpha 0.0025. Support requires unresolved count 0, usable
triggered n exactly a look, n >= 10, wins > losses, positive mean
difference, and p <= 0.0025. Otherwise
`insufficient_data` / `off_schedule` / `inconclusive` / `negative`,
with `awaiting_completion` first when anything is unresolved. n > 300
is `off_schedule`. A significant negative direction is not support.

All valid triggered episodes are analyzed. There is no truncation to a
look and no configurable alpha. Request order then `job_index` is the
cumulative order.

Raw sums and paired differences must stay finite. Overflow is
`BuyanError`.

`dashboard_required` is always true. Dashboard significance must
separately pass the user gate on the identical field.

## Conditional activation limitation

Sign-test inference describes the triggered subset only. It does not by
itself establish unconditional league improvement.

## Implementation

`comparisons.nim` exports `compare`, `compareFiles`, `signTestP`, and
`decideGate`. I/O and JSON coercion map to `BuyanError`. `compare.nim`
prints JSON to stdout. `tests.nim` uses constructed synthetic JSON
nodes and exact p-values 0.001953125, 0.021484375, 1, and 2^-299.

This worker did not run Nim. Supervisor verification is `nim check`
then `nim r tests.nim`, then a synthetic CLI run labeled synthetic.
