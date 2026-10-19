# Clean observation trial

Status: uploaded as buyan-clean:v1. Two hosted requests started by Grok.
Not kept. No hosted score or activation verdict yet.

- A: xreq_b86e9068-91aa-4d37-a621-e311560aeb89, ten episodes.
- B: xreq_31165bdb-cc10-4612-80c6-65ea9fe4da1b, ten episodes.
- Coworld: nmmo 0.1.5. Source commit: 465eb93.
- Both pair buyan-clean:v1 with buyan:v1 and the same frozen opponents.
- Linux amd64 rebuild passed. Upload and request receipts are saved in
  upload.txt, response_a.json, and response_b.json. Grok executed both
  exact XP commands and verified their receipts; see grok_xp.log.

Idea: request `obs=clean`, prove the server honored it, then trust current
enemy presence. Grok implemented the policy change and telemetry. Supervisor
review completed isolation tests, explicit activation gating, doc comments,
and connection-error mapping. Baseline buyan.nim remains unchanged.

The single strategy replaces stale-observation trust only after a same-window
nonzero entity becomes six zero entity bytes within one life. Unverified
servers retain baseline liveness, attack feedback, and streak behavior.
Confirmed servers bypass those stale-entity heuristics. All health, item,
navigation, RNG, and combat thresholds remain unchanged. Resets discard
observation history while retaining previously proven server support.

Files: candidate.nim, tests.nim, source_review.md. Grok task and correction
files record implementation instructions; Grok logs record worker runs.

Verification from repo root:

- `nim check --hints:off games/nmmo/buyan/experiments/clean/candidate.nim`
- `nim r --hints:off -d:buyanTest games/nmmo/buyan/experiments/clean/tests.nim`

Both passed. Tests verify query preservation/replacement, legacy action
agreement without support, positive and false support witnesses, reset
boundaries, static clean enemies beyond TTL/streak, unchanged health gates,
corpse filtering, and copied-state telemetry without RNG/state mutation.

Hosted activation record prefix: `buyan-clean `, followed by JSON:

```json
{"experiment":"clean","event":"activation","tick":1,"agent":0,"action":5,"baselineAction":25,"verifiedClean":true,"clearedCells":1,"extraHints":1,"counterfactual":"trust-only"}
```

This example is from isolation tests, not hosted XP. Only the first eight
action changes per process emit samples. Final and 128-tick summaries report
verifiedSteps, clearedCells, extraHints, and actionChanges. Final counters
persist over agent resets. `agent` is the local observation index.

Hosted gate: require verifiedClean=true, clearedCells>0, action !=
baselineAction, and replay agreement for the issued action. Server log
`[obs=clean]` proves only request receipt. Reject support claims when the
server says `obs=clean request ignored`. Source witness rationale is in
source_review.md. Compare the candidate and submitted policy on the same
opponent field. At least ten activated episodes plus the dashboard's
significance decision are required before a keep. The legacy-trust shadow
uses the same clean input and is diagnostic, not a full baseline replay.
