# Hunt candidate verification

**Verdict: isolation PASS; PENDING HOSTED XP.** No local games or score claims.

Supervisor-reported `nim check draft.nim` and `nim r -d:buyanTest -d:huntDraft reviewer_tests.nim` both PASS; draft copied byte-identically to `candidate.nim`. This review read only `candidate.nim` 630–850, `reviewer_tests.nim`, and the task prompt.

## Spec vs `decide` hunt branch (756–808)

| Requirement | Finding |
|---|---|
| One strategy, one live hint | `hints.len == 1` on `mind.liveHints(p)` |
| Neutral `byte5==0`, `delta==0` | `tileByte(..., 5) == 0` and `hint.deltaCombat == 0` |
| `health>=95`, not in combat, inventory not full, `equipAction<0` | `health >= fightStartHealth`, `not p.inCombat`, `not p.inventoryFull()`, `equipAction(p) < 0` |
| Manhattan 2..4 only | `distance in 2 .. 4` |
| Walk 3/4 → remain ≥ 2, never run | `moveActions` only; `passable` and `remaining >= 2 and remaining < distance` |
| At 2, wait at most 2 consecutive | `noop` while `huntWaits < 2`; increment on issue; reset on walk or ineligible |
| Gates preserved | Hunt sits after UI / heal / adjacent attack / tool-grab, before disengage / equip / harvest |
| Combat thresholds untouched | Adjacent fight still uses `fightStartHealth` / wounded / keep / streak (712–734) |
| Copy Mind baseline | `copy[] = mind[]` then `copy.decide(p, false)` before mutating waits |
| Log tick, agent, action, baselineAction | JSON `issued` includes those plus generation, kind, changed, r, c |
| Issued drives activation regardless of success | `huntRemaining = 10` and `return action` whenever `action >= 0`; `changed` is logged only |
| 10-decision telemetry bound | `huntRemaining = 10`; `observeHunt` decrements and returns when `<= 0` |

Walk loop takes the first qualifying walk in `moveActions` order. Isolation at distance 3 asserts `rightAction` with the enemy at `centerCol+3`, which matches a toward-step that leaves Manhattan 2.

`tick: -1` is the isolation fixture (`newMind`); production `act` is stated to pass parsed wire tick. Not re-checked here (no other sources).

## Observed isolation output vs tests

Output matches `reviewer_tests.nim`:

1. **Approach outside first-hit range** — one `issued` walk `action=2` (`kind=walk`), `baselineAction=25`, `changed=true`, target `(5,10)`. Assert `decide == rightAction`; RNG unchanged.
2. **Distance-two wait** — two `issued` `action=4` (`kind=stage`) at `(5,9)`, then third `decide` equals `baseline` (no third issue). Caps consecutive waits at 2.
3. **Dangerous/untrusted retain baseline** — death anim, not live, `delta=1`, `element=1`, two live hints, health 70, in-combat. No extra `issued` lines.
4. **Original priorities** — heal (`oneAction`), adjacent attack, tool-grab `downAction`, sell-price `nineAction`. Hunt does not preempt those gates.

`observeHunt` is not invoked from the focused `decide` slice; the 10-step bound is armed on issue. Call site is outside the allowed read window.

## Gaps (not isolation failures)

- No isolation case for Manhattan 4 walk, `changed==false` still-issue, or a full 10-tick `observeHunt` window.
- Third wait at distance 2 falls through to existing disengage (`maybeRun`); tests only require equality with hunt-disabled baseline, which is the same fall-through.

Hosted XP is required for any performance claim.
