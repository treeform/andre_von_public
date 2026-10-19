# Assassin haste for movement uptime

Candidate relative to frozen gorynych:v1
(`6a471409-9b7d-42dc-ba8c-d61ff45110e9`), copied from
`games/moba/gorynych/baseline/gorynych.nim`. Sim 0.1.3 / `moba.h` at
`f06d28f`. No hosted XP, no score, no keep/reject verdict.

## Strategy diff

The only action change is assassin E in PushMode. Retreat E is the v1
flag with no extra gates. Q, W, other roles, movement, and siege are
unchanged.

Baseline assassin E (`skillFlags`):

```
flag(mode == RetreatMode and view.manaAtLeast(100))
```

Candidate assassin E:

```
flag(baselineAssassinE or pushE)
```

where `baselineAssassinE` is exactly the v1 retreat+mana flag
(stationary, on cooldown, and already-buffed retreat still request E)
and `pushE` is the one new clause:

```
mode == PushMode and
moving and
view.eTimer <= AssassinEReadyObs and
view.moveModifier != AssassinHasteBuff and
view.manaAtLeast(AssassinHasteCost)
```

`moving` is `dy != 0 or dx != 0` after steering. New constants:
`AssassinHasteCost = 100`, `AssassinHasteBuff = 2`,
`AssassinEReadyObs = 1`, `AssassinECastNear = 90`.

## Sim E semantics (`moba.h`)

`skill_assassin_move_buff` (1223-1232): mana 100, no target, sets
`move_modifier = 2.0`, `move_timer = 25`, `e_timer = 100`.

Engine use (1537): `use_e && player->e_timer <= 0`, after
`update_cooldowns` (1478). Observations are post-step. Observed
`e_timer == 1` is ready this tick; the new push clause uses
`eTimer <= 1`. Retreat does not consult the timer, matching v1.

Skills are Q else W else E. A flagged E is skipped that tick if Q or W
succeeds. Intent is not proof of activation.

## Trigger definition

Counters never feed back into the action.

- `heroCalls`: every `heroAction` (including malformed no-ops).
- `pushEIntents`: issued `use_e == 1` on a PushMode assassin (the new
  flag). Not a trigger.
- `changedActions`: assassin issued `use_e` differs from v1
  (`RetreatMode and manaAtLeast(100)`). Retreat matches, so this is
  the count of new push-E flags actually put on the wire.
- `triggers`: the following observation confirms that a pending new
  push-E intent, issued while the timer was ready, produced
  `e_timer >= 90` and `move_modifier == 2`. Pending is per-hero and
  consumed on the next call for that hero, success or not.

Verified in fixtures:

| Situation | E | pushEIntents | changedActions | trigger |
|---|---|---|---|---|
| Push, moving, ready | 1 | +1 | +1 | no (until next obs) |
| Next obs: e=100, buff=2 | 0 | 0 | 0 | yes |
| Next obs after Q/W: no buff | 0 | 0 | 0 | no |
| Retreat stand / CD / buffed | 1 | 0 | 0 | no |
| Other roles | v1 E | 0 | 0 | no |

First confirmed trigger and every 1000 hero calls echo `MOBA_TRIAL`
plus `{idea, heroCalls, pushEIntents, triggers, changedActions}`. The
same line is emitted when the done message arrives.

## Commands and checks

```
nim check --nimcache:games/moba/gorynych/experiments/haste/nimcache/review \
  games/moba/gorynych/experiments/haste/candidate.nim

nim r -d:policyTest \
  --nimcache:games/moba/gorynych/experiments/haste/nimcache/review \
  games/moba/gorynych/experiments/haste/tests.nim
```

`nim check` returned SuccessX. Tests printed `all haste isolation tests passed`.
`when not defined(policyTest): main()` lets tests `import candidate`.

## Isolation fixtures

`tests.nim` (`doAssert` only) showed:

- Push-moving ready assassin E is 1 vs v1 0. Intent and changedAction
  increment; triggers stay 0 until the next obs.
- Confirmation obs (`e_timer=100`, `move_modifier=2`) increments
  triggers once and does not recast.
- Q/W preemption: first action has Q=W=E=1; next obs with idle CD and
  no buff leaves triggers at 0.
- Retreat E is 1 while standing, on cooldown (`e_timer=40`), and while
  already buffed. `changedActions` stays 0.
- Push `e_timer==2` and already-buffed do not add E. Slowed push still
  does. Siege hold does not. `mana10==3` at level 0 does not;
  `mana10==4` does.
- Support / burst / tank / carry E match v1, including with
  `e_timer==40`.
- Two policies on the same obs produce the same action.
- JSON includes `pushEIntents`. Repeating the same push obs 1000 times
  never confirms a trigger.

## Limitations and concerns

- Confirmation is one following observation for that hero. A delayed
  or dropped obs can miss a real cast; a crafted buff obs could count
  one without a sim.
- `AssassinECastNear = 90` is a band under the post-cast 100. A late
  confirm tick still counts while the buff is up and CD is high; it
  will not count a leftover slow (`modifier==0`).
- `manaAtLeast` is still the conservative `mana10` floor.
- No episode was played. Hosted logs need `MOBA_TRIAL` lines plus
  `triggers > 0` to prove real activations.

No keep/reject claim. Hosted XP significance is a supervisor gate.
