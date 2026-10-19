# Escape recovery: failed-run demotion

## Idea

`stepTowards` already demotes last tick's failed walk (actions 0–3) when a
second target axis exists, so the agent routes around an occupied tile.
`maybeRun` returns run ids 22–25. Those ids never compare equal to the walk
preferences, so a failed run retries the same blocked axis. Normalize a
failed run to its base walk direction before the existing recovery. One
change only.

## Changed behavior

In `stepTowards`, `lastAction` 22–25 is reduced by `runOffset` (22) to 0–3
before the existing `in preferences` / `lastMoveBlocked` / `len > 1` trim.
Failed walks, successful runs, and one-axis targets are unchanged. When
the alternate is unavailable, normalization can make `stepTowards` return
`-1`, and existing fallback policy then chooses the final action. No
pathfinding, threshold, flee, equipment, target, or passability edits.

Each decision retains the first original reachable `baselineAction` when
normalization changes a `stepTowards` result, including `-1`. After `decide`
returns, `act` logs only actual final action differences from that baseline.
Fallback movement and nonmovement actions are included. Repeated target
attempts preserve the first baseline, where the original policy would have
returned. Secondary-axis demotion or an already-excluded primary does not
count when the issued action is unchanged.

## Mechanics evidence

Upstream `sims/nmmo/vendor/upstream/nmmo3.h`:

- Run ids: `ATN_DOWN_SHIFT` 22 … `ATN_LEFT_SHIFT` 25 (`:67-70`).
  `is_run` is `action >= 22 && action <= 25` (`:840-842`). Walks are
  `ATN_DOWN`..`ATN_LEFT` 0–3 (`:46-49`, `:837-838`).
- `dest_check` (`:1194-1198`): tile is passable terrain **and** `pids[adr]
  == -1`. Occupied grass still fails.
- `move` (`:1200-1226`): check first tile; on `run`, advance and check the
  second tile; **return before** updating `r`/`c`/`anim` if either check
  fails. Run is all-or-nothing: a blocked second tile does not walk one
  tile.
- Success anim is set only after both checks (`:1226`):
  `entity->anim = (run ? ANIM_RUN : ANIM_MOVE)`.
- `c_step` (`:1842`): every living entity gets `entity->anim = ANIM_IDLE`
  (`:1959`) before the action. Then `is_move` → `move(..., false)` and
  `is_run` → `move(..., action - ATN_DOWN_SHIFT, true)` (`:2111-2114`).
- Fresh self `ANIM_IDLE` (0) after a walk/run action therefore means no
  displacement. `ANIM_MOVE` (1) / `ANIM_RUN` (6) (`:37-43`) are the only
  success marks from `move`.
- `PASSABLE` (`:895-900`): grass/dirt yes, stone/water no. Policy
  `passable` still ignores entities; that is why recovery exists.

## Telemetry

Stdout JSON, one object per line. Wire traffic stays on the websocket.
Instrumentation is observational: primitive per-agent counters plus one
pending flag/action/issueTick. Action selection never reads them. `tick`
is the server tick from the wire JSON, passed into `act`; it does not
affect policy. Isolation tests may omit it (`tick = 0`).

Counters `issued` / `confirmed` / `failed` are per-agent and survive
respawn. Pending state is per-life: `reset` clears it so a respawn
observation cannot confirm prior-life movement and does not emit
`escape_result`.

### `escape_issue`

Emitted after `decide` when its final action differs from the first original
reachable step, caused by normalizing a failed run.
`tick` is the **action reply tick** (the tick being answered), not the
following observation.

```json
{"event":"escape_issue","tick":40,"agent":2,"generation":0,"previousRun":22,"baselineAction":22,"action":24,"issued":1}
```

| field | meaning |
|---|---|
| `event` | `escape_issue` |
| `tick` | wire tick of this action reply |
| `agent` | agent index |
| `generation` | life generation |
| `previousRun` | failed run id 22–25 |
| `baselineAction` | original `stepTowards` pick (untrimmed prefs) |
| `action` | actual final action, including fallback nonmovement |
| `issued` | per-agent issued count after this event |

### `escape_result`

Emitted on the next valid observation, before deciding a new action.
`tick` is that observation's wire tick; `issueTick` is the reply tick of
the matching `escape_issue`. `action` is the issued movement so hosted
replay bytes can be checked against fresh displacement. `success` is true
iff `ownShift` confirms nonzero displacement. A false result means no fresh
displacement (typically IDLE); for a nonmovement action it says nothing
about strategic value. At most one pending issue.

```json
{"event":"escape_result","tick":41,"issueTick":40,"agent":2,"generation":0,"action":24,"anim":6,"success":true,"dr":0,"dc":2,"issued":1,"confirmed":1,"failed":0}
```

Failed IDLE example:

```json
{"event":"escape_result","tick":8,"issueTick":7,"agent":0,"generation":0,"action":24,"anim":0,"success":false,"dr":0,"dc":0,"issued":1,"confirmed":0,"failed":1}
```

| field | meaning |
|---|---|
| `event` | `escape_result` |
| `tick` | wire tick of this observation |
| `issueTick` | reply tick of the pending issue |
| `agent` / `generation` | same agent/life ids |
| `action` | the issued movement being resolved |
| `anim` | fresh self anim scalar |
| `success` | nonzero displacement confirmed by `ownShift` |
| `dr` / `dc` | `ownShift` tile displacement |
| `issued` / `confirmed` / `failed` | per-agent counters after this event |

Malformed observations do not resolve pending. `resets[i]` calls `reset`
before `act`, so a new life cannot attribute a result.

## Verification

Commands (from this directory):

```
nim check candidate.nim
nim r -d:buyanTest tests.nim
```

Results: **PASS.** Supervisor ran `nim check` first, then all doAssert tests.
Exact outputs are `check.log` and `tests.log`. Grok wrote the strategy and
initial tests. Supervisor completed the telemetry-only fallback coverage
correction and added its regression tests. Grok secondary review verified
the frozen source and supplied passing logs in `grok_verification.md`.
Isolation tests cover:

- all four failed run directions take the other target axis and issue
- successful runs unchanged, not counted
- failed walks keep old demotion, not counted
- one-axis movement unchanged, not counted
- no remaining axis -> `-1`, final fallback action difference counted
- failed secondary preference not counted
- failed primary already absent from `safeMoves` not counted
- next MOVE / RUN / IDLE obs confirms the matching counter
- reset clears pending; a later MOVE/RUN does not confirm
- `act` tick is optional (default 0); wire tick associates issue/result
- repeated target attempts retain the first original reachable action
- final fallback equals the original action -> no issue
- fallback equipment action is counted, with zero displacement outcome

No local games. No score.

## Verdict

**PENDING HOSTED XP.** No local performance claim. No keep decision.
Source committed/pushed as 465eb93. Linux Docker build passed. Under the
user's later authorization, Grok uploaded `buyan-escape:v1` and created:

- A: `xreq_22fa03f9-33e4-4c77-93c8-566e4262bcd8`, 10 episodes.
- B: `xreq_c65bc7f9-ff37-4558-8e53-4994dca64c91`, 10 episodes.

Both requests were accepted pending on NMMO 0.1.5. Each episode contains
`buyan:v1`, `buyan-escape:v1`, and two copies each of
`relh-nmmo-consensus:v1`, `nmmo-opt:v6`, and `daveey-nmmo-nim:v11`.
Receipts: `upload_receipt.txt`, `response_a.json`, `response_b.json`.
Parent owns the statistical verdict and any league submission.
