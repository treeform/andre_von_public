# Nim hosted XP paired comparison tool

You are Grok, the implementation worker. Work only in
`/Users/me/p/andre_von_auto/games/nmmo/buyan/statistics/`.
Read `/Users/me/p/andre_von_auto/tools/workers.md` and user AGENTS Nim style.
All code must be Nim. No shell scripts, Python, JavaScript, or other code.
Do not run games. Do not commit, push, build Docker, upload, submit, mutate
coworld state, or change any files outside your folder. Do not spawn workers.

Write a small importable `comparisons.nim`, CLI `compare.nim`,
`tests.nim` containing plain doAssert structural/math fixtures, and
`usage.md`. Use std/json for strict validation pragmatically, map I/O and
JSON/coercion errors to `BuyanError`. All functions need concise doc comments.
Nim is installed. Run nim check first, then nim r tests.nim. Build and exercise
CLI with synthetic fixture inputs. These fixtures must be labeled synthetic
and never claimed to be hosted XP score.

CLI: `nim r compare.nim <plan.json> <activations.json> <episodes.json>...`.
Read saved `coworld xp-request episodes <xreq> --json` episode arrays or
objects with `episodes` or `entries`. Parent saves hosted CLI outputs.
`/Users/me/p/andre_von_auto/games/nmmo/buyan/baseline_response.json` has real
schema but no candidate or scores yet, use only as schema example. Actual
completed entries have participant_scores entries `{position, score}`.
Do not use the loose old tools/xp_score.nim significance logic.

Plan JSON pins all membership, never infer a different field from results:
```
{
  "source": "softmax-hosted-xp",
  "experiment": "armor",
  "coworld_id": "cow_6272bfca-6bfa-4268-be2c-9ee35f669cfc",
  "coworld_version": "0.1.5",
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
  "requests": [{"xp_id":"xreq_actual","episodes_file":"episodes.json"}]
}
```
Pin current design exactly one baseline and one candidate seat per episode,
six expected opponent seats (multiset matched irrespective of rotation).
Every input file must match a plan requests file path. Array itself has no
XP id, so the plan supplies provenance; if wrapper id exists require match.
Explain local files cannot prove network authenticity cryptographically.
Reject extra input file, repeated file/request IDs, mismatched source,
candidate identities, opponent identities/counts, coworld/version, duplicate
episode IDs or duplicate positions with BuyanError. Membership checks must
occur even for a failed episode; a missing comparison seat is excluded with
an explicit missing_participant count, whereas an unexpected identity/field
is fatal. Do not silently pool different candidates or fields. If schema is
missing metadata needed for these checks, fail closed and explain it.

Activation JSON exact schema (a separate hosted replay/log extractor writes):
```
{
  "source":"softmax-hosted-xp",
  "experiment":"armor",
  "coworld_id":"cow_6272bfca-6bfa-4268-be2c-9ee35f669cfc",
  "coworld_version":"0.1.5",
  "candidate_policy_version_id":"UPLOAD_ID_REQUIRED",
  "episodes":[
    {"xp_id":"xreq_actual","episode_id":"ereq_actual",
      "candidate_position":0,"verified":true,"trigger_count":12,
      "log_path":"path/to/hosted/log/or/replay",
      "metric":"Actual emitted armor action differs from baseline choice"}
  ]
}
```
Require source/experiment/coworld/version/candidate matches plan. Duplicate
activation episode IDs fatal. Unknown episode evidence fatal (all planned
episode files must be provided), wrong xp ID/position fatal. Missing evidence,
verified false, empty log_path/metric, or nonpositive trigger_count exclude
explicitly. Validate data types and nonnegative integer counts. Only include
completed episodes with finite numeric scores for both seats, all metadata
valid, and verified positive candidate activation evidence. Exclude failed,
pending, missing_participant, missing_score, missing_evidence,
unverified_evidence, not_triggered separately; one primary exclusion reason
per episode with clear priority. Sum trigger_count of included episodes and
show how much the strategy fired. Do not read score from activation files.

Output JSON to stdout with episode ids and per-episode differences, n,
baseline mean, candidate mean, paired mean diff, wins/losses/ties, non-ties,
exact paired sign-test two-sided p-value, exclusion counts, total activations,
and gates. One independent observation is candidate minus baseline within
the SAME completed hosted episode. Do not treat seats as independent.
Ties use exact zero and are omitted from sign-test n but retained in
descriptive paired n. P = min(1,2*sum_{i=0}^{min(w,l)} choose(w+l,i)/2^(w+l)).
Compute stably at n <=300; no t>=2 heuristic, no unsupported mean CI.
No output can say KEEP or authorize submission. Output support only.

Constants: family alpha0.05, five hypotheses, four fixed cumulative looks
[10,30,100,300], per-look two-sided alpha0.0025. Gate requires usable
triggered n exactly one of these values, n>=10, wins>losses, positive mean
diff and p<=0.0025. Otherwise status insufficient_data/off_schedule/
inconclusive/negative. At n>300 status off_schedule. A significant negative
direction is not support. Emit `dashboard_required:true` always and state
dashboard significance must separately pass user gate on identical field.
Do not select first N by score or allow configurable alpha. Plan request
ordering and input episode order establish cumulative order; sort episodes
within a request by numeric job_index, not outcome. Always analyze all valid
triggered episodes; never silently truncate to an allowed look. No CLI flags
to alter fixed experiment design. Re-running does not change alpha; human
must predeclare requests and retain no ad hoc peeking decisions.

Tests need exact known sign p values (10 wins =>0.001953125, 9 wins1 loss
=>0.021484375, ties10 =>1, 300wins =>2^-299), all schedule boundaries,
mean-direction gate, nonfinite score rejection/exclusion, fields/source/
identities/version error paths, duplicate evidence/episode/positions,
missing/failed/nontriggered exclusions, and one observation per episode.
Fixtures are pure constructed JSON nodes and synthetic scores only.

Report implementation and verification in usage.md, including conditional
activation selection limitation: sign-test inference describes triggered
subset and does not by itself establish unconditional league improvement.
If exact schema ambiguity prevents safe implementation, ask supervisor.
