# Casting: ability selection vs leaders

Frozen baseline `games/moba/gorynych/baseline/gorynych.nim`
(gorynych:v1). Reconstruction through pinned
`moba_sim.wasm` sha256
`b76a9c4cdcc7e4a47c973d4029737a832e0b678646c6a512f5653d3e98f1b8c8`.
Every file below matched hosted `final_tick`, `winner`, all 10x11
`agent_stats`, and both `ancient_healths`. Not a score.

Local `frozen.nim` is that baseline with `main()` gated on
`isMainModule` and the policy/heroAction symbols exported. No strategy
edit. All five seat observations are fed in hosted pid order so shared
tower memory matches a 5-hero seat.

Fire = the issued `use_q`/`use_w`/`use_e` bit and the matching timer
rose across the step (`q_timer`/`w_timer`/`e_timer`). Tank Q does not
set a timer; it is never counted as a confirmed fire.

## Games

| File | Focal | Side | Ticks | Winner | Verified |
|---|---|---|---|---|---|
| r3730-g4.moba | daveey | radiant | 1827 | radiant | yes, digest 2714423814 |
| r3721-g6.moba | daveey | radiant | 2209 | radiant | yes |
| r3728-g9.moba | daveey | dire | 1177 | dire | yes |
| r3726-g5.moba | daveey | dire | 1049 | dire | yes |
| ereq_82528dd3 (t1 vs daveey) | gorynych:v1 | radiant | 2576 | dire | yes |
| ereq_5beeab20 (t1 vs daveey) | gorynych:v1 | dire | 5033 | dire | yes |

## Instrumentation check

On both v1 seats, issued Q/W/E matched frozen `heroAction` on every
tick of every role (2576/2576 and 5033/5033). The comparison is
same-state.

Richard and relh seats in the leader files also matched frozen flags
100%. Stacked leaders use the same skill rules as the scripted port.

## Healing

Support W is `skill_support_aoe_heal` (mana 100, `w_timer=50`, radius 5).
Baseline flags it at `health10 <= 6`.

Daveey support flags equal baseline in every file. Confirmed W fires
at `health10 > 6`: 0. Dual-flag Q+W ticks exist (18, 20, 15, 5, 1, 94)
and daveey never cleared Q to let W through (`leader_w_drop_q = 0`,
`w_fire_drop_q = 0`).

Tank W (`skill_tank_self_heal`, `health10 <= 5`) flags match 100% in
every file. Confirmed tank W fires at `health10 > 6`: 0.

The one `heal-priority-fire` in the sample is carry, not support:
ereq_5beeab20 tick 4958 pid 4, `health10=4`, leader `[0,1,0]` vs
baseline `[1,1,0]`, W fired. One tick in 5033. Not a support rule.

**Refuted:** efficient-heal priority (drop Q/E so support or tank W
lands).

## Escape

Assassin E is panic haste. Confirmed daveey assassin E fires:

| Game | E fires | hp<=3 | hp>3 | fires with baseline E=0 |
|---|---|---|---|---|
| r3730 radiant | 10 | 8 | 2 | 0 |
| r3721 radiant | 13 | 11 | 2 | 0 |
| r3728 dire | 5 | 4 | 1 | 0 |
| r3726 dire | 8 | 8 | 0 | 0 |
| ereq_82528dd3 dire | 13 | 7 | 6 | 0 |
| ereq_5beeab20 radiant | 37 | 20 | 17 | 0 |

No assassin E fire occurs unless frozen v1 also flagged E. Dual-flag
Q+E on retreat is common (135 ticks in r3730); daveey never dropped Q
to force E (`e_fire_drop_q = 0`). Push-E was already rejected; this
is the same panic-E the baseline already issues.

Daveey flags fewer assassin E than v1 (r3730: 493 vs 878; r3721: 660
vs 906). The extras are retreat ticks with `e_timer` still high. They
cannot fire. Clearing them would change the issued bit and not the
cast.

Carry dropped Q for E once with a confirmed fire: r3721-g6 tick 1769
pid 4, `health10=7`, leader `[0,0,1]` vs baseline `[1,0,1]`. 57 such
flag drops in that game, 1 fire. r3730 had 10 flag drops and 0 E
fires. Not a rule.

**Refuted:** escape priority by suppressing Q/W when E is set.

## Remaining flag noise (not a keep)

Dire daveey seats show a handful of confirmed fires v1 would not
flag (assassin W at `health10 < 5`, burst Q at conservative mana).
Radiant daveey wins do not: r3730 and r3721 have
`q/w/e_fire_baseline_off = 0/0/0` on every role except that single
carry E. The winning daveey shape is the v1 skill table.

v1 itself, given its own obs, is bit-identical to frozen flags. v1
support W-flags 283 vs daveey 34 in ereq_82528dd3 because v1 is at
`health10 <= 6` more often, not because the W rule differs.

## Decision

Ability selection is not the discrepancy. Same-state Q/W/E flags and
confirmed fires match the frozen scripted table on the roles that
heal or haste. No candidate, no image, no upload. Supervisor can
redirect the lane.

Exact quantities: `experiments/casting/evidence/compare.json`.
`scoring_evidence` is false.
