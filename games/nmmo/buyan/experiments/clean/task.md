# One experiment: verified clean observations

You are the Grok implementation and verification worker. Work only in
`/Users/me/p/andre_von_auto/games/nmmo/buyan/experiments/clean/`.
Read `/Users/me/p/andre_von_auto/tools/workers.md` and the Nim style
instructions in `/Users/me/p/AGENTS.md` if present. Read
`sims/nmmo/AGENTS.md` before inspecting sim source. Do not edit sim source.

Copy `games/nmmo/buyan/buyan.nim` into `candidate.nim` in this directory.
Implement exactly one strategy: request optional truthful entity observations
with `obs=clean`, then use directly observed enemy presence once evidence
proves the server honored it. Keep ALL combat health, item, navigation,
inventory, healing, RNG, and unrelated thresholds unchanged. Minimal diff.

Protocol sources (read only):
- `sims/nmmo/docs/PROTOCOL.md` optional obs=clean section.
- `sims/nmmo/server/cogame_nmmo/server.py` request flag handling.
- `sims/nmmo/server/cogame_nmmo/sim.py` set_obs_clean fallback.
- `sims/nmmo/sim/patches/0003-obs-clean-optin.patch`.
- `sims/nmmo/vendor/upstream/nmmo3.h` compute_all_obs.

The server can log obs=clean despite old WASM ignoring it. Never equate
URL request or connection success with confirmed support. Keep baseline
liveness behavior until one SAME WINDOW cell changes from nonzero entity
type to zero entity type AND all entity bytes 4..9 zero, compared between
two observations within the same life (exclude reset/first observation).
Legacy observations never write zero entity type on an empty tile, so this
is a positive clean support witness. Track/log number of cleared cells.
Reset observation history on death as baseline does. You may retain already
confirmed support per connection or re-prove per mind/life; keep explicit.

After verification, all nondeath enemy hints are current. Bypass stale
liveness rejection, missed-hit invalidation, and ghost attack-streak cap
only in verified clean mode. This is one coherent observation-trust change.
Without proof, output and state must remain baseline-compatible, aside from
telemetry and obs=clean request. Preserve all numerical thresholds.

Use std/uri for query modification preserving slot/token, handling no query,
existing obs parameter (replace), and fragment correctly. Never log URL/token.
Add small testable free procs as useful. Nim only for all implementation,
tests and extractors. No Python/Bash/JavaScript scripts. Direct `cp`, `nim`,
`git diff --no-index` CLI invocations are allowed, no shell scripts.

Telemetry: compact stdout JSON (prefix allowed) at episode end and occasional
bounded intervals, aggregating per-process or per-mind verified steps,
positive support cleared-cell witnesses, added direct hints, and actual
action changes. Compute a diagnostic legacy-trust counterfactual from a
COPY of pre-decision Mind state over the same observed input: never let it
mutate live state/RNG. Label this as trust-only counterfactual, not true
submitted-policy replay (clean input differs). Log short first examples of
tick/agent/chosen action/counterfactual action/extra enemy count/proof counts
to make hosted activation auditable. Counters should persist over resets so
final totals are useful. Avoid per-tick spam. Do not call this hosted score.

Verification: Add tests.nim with `doAssert`, no unittest. Guard candidate
main with `when not defined(buyanTest)` (never when isMainModule) so tests
can include candidate. Tests must exercise (a) URL preservation/replacement,
(b) unsupported/static legacy retains baseline liveness and actions,
(c) same-window clear witness arms clean trust, (d) reset boundary cannot
fake witness, (e) verified static enemy stays target beyond legacy TTL and
ghost streak while health thresholds stay identical, (f) corpse filtered,
(g) telemetry action deltas do not mutate live RNG/state twice. Tests are
isolation tests only; do not run local scored games.

Run `nim check --hints:off games/nmmo/buyan/experiments/clean/candidate.nim`
from repo root, inspect it, then
`nim r --hints:off -d:buyanTest games/nmmo/buyan/experiments/clean/tests.nim`.
Write report.md with exact files changed, commands/results, source support
proof, expected hosted telemetry fields and required server log evidence.
Report candidate as UNTESTED ON HOSTED XP, not kept or better.

Do not commit, push, Docker build, upload, submit, edit ideas/progress outside
this directory, run coworld commands, modify credentials/config, or touch
baseline buyan.nim. No local game scores. No broad reformatting.
