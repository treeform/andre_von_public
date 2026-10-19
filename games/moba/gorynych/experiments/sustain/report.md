# Sustain: assassin returns at 6/10 health

Candidate is a single-change fork of frozen `gorynych:v1`
(`6a471409-9b7d-42dc-ba8c-d61ff45110e9`). Source snapshot:
`games/moba/gorynych/baseline/gorynych.nim`. Root `gorynych.nim` was
not used. Sim 0.1.3 / pinned wasm
`b76a9c4cdcc7e4a47c973d4029737a832e0b678646c6a512f5653d3e98f1b8c8`.
`scoring_evidence` is false. No local games, no scores.

## Reconstruction

Hosted actions were replayed through the pinned wasm. Every file below
matched hosted `final_tick`, `winner`, `end_reason`, all 10x11
`agent_stats`, and both `ancient_healths` before any retreat number
was trusted. Five observations per seat were fed to a local frozen
baseline copy in hosted order (support..carry) so shared tower memory
matched the 5-hero seat.

| File | Seats | Ticks | Winner | Digest | Match |
|---|---|---|---|---|---|
| r3730-g4.moba | daveey / richard | 1827 | radiant | 2714423814 | yes |
| r3728-g9.moba | richard / daveey | 1177 | dire | 1990666327 | yes |
| r3726-g5.moba | relh / daveey | 1049 | dire | 683868212 | yes |
| ereq_82528dd3 (v1 t1 vs daveey) | Auto radiant / daveey | 2576 | dire | 1526298342 | yes |
| ereq_9b896a79 (v1 t1 vs daveey) | daveey / Auto dire | 2901 | radiant | 4228019895 | yes |

Leader digests match `research/trajectories.md`. This is not a score.

## v1 is a faithful 3/8 fountain retreat

On both Auto seats, every RetreatMode tick issued the same velocity as
frozen baseline (0 mismatches / 4021 and 0 / 3801). Enter health is
always 0-3; fountain leaves are almost all 8-10. The instrumented
baseline copy is the submitted policy.

## Daveey enter threshold matches v1

Baseline-reconstructed enter-health histograms on Daveey's five heroes
(all games): counts live only in bins 0-3. Daveey does not start the
v1 retreat flag at 4+. Role-specific enter is not supported.

## Daveey return: assassin sometimes leaves before 8

v1 exit is `health10 >= 8`. When Daveey actually reaches fountain and
leaves (`classifyRegion` fountain -> not fountain, hp < 10):

| Game | Daveey assassin leave hp < 8 | leave hp >= 8 | fountain ticks | Auto assassin fountain |
|---|---|---|---|---|
| r3730-g4 (daveey radiant) | 2 (hp 4 and 6) | 5 | 221 | n/a |
| r3728-g9 (daveey dire) | 0 | 3 | 71 | n/a |
| r3726-g5 (daveey dire) | 0 | 4 | 26 | n/a |
| ereq_82528dd3 | 3 | 9 | 440 | 1265 |
| ereq_9b896a79 | 2 | 8 | 1145 | 521 |

Concrete mismatch, r3730-g4 daveey assassin pid 1 (verified digest
2714423814):

- tick 904, hp 6, fountain, L1 spawn 2: baseline hold `(0,0)`, Daveey
  `(-1,0)` (walks out).
- tick 905-906, hp 6, L1 3-4: baseline toward spawn, Daveey away.
- tick 909: leaves fountain at hp 6 into top, actual `(-1,1)`.

Same game, daveey burst/support/tank/carry fountain leaves are all
hp >= 8. Auto never leaves below 8 except one carry tick at hp 5 in
ereq_82528dd3.

ereq_82528dd3 (Auto radiant loss): Auto assassin spends 1265/2576
ticks in the fountain region (retreat 1531); Daveey assassin 440/2576
(retreat 1102). Auto burst 1083 fountain vs Daveey burst 612. That is
time away from lanes, not a reconstruction score.

## Counterexamples

- r3728-g9 daveey vs richard: retreat velocity match 1009/1048
  (96.3%). Assassin 168/170. In this win Daveey mostly *is* v1
  retreat, including fountain leave at 8-10.
- Most Daveey fountain leaves are still 8-10, including assassin
  (29 of 36 across five games). A global exit of 6 would overshoot
  the typical Daveey trip.
- Stacked richard/relh barely fountain-walk (fountain fraction
  0.015-0.021 vs Daveey 0.053-0.116). Sustain vs the stack is the
  split itself (already rejected as topstack), not a shallower
  retreat. Daveey retreats *more* than the stack.
- Direction mismatches at hp 2-3 are often later-tick detour desync
  after an earlier different step, not a second rule. First-class
  evidence is the fountain leave at hp 6 with intended hold.

## Not recovery v6

Recovery v6 changes retreat *destination* (local hold / step away
from crop threats, fountain fallback). Enter 3 / exit 8 stay. This
candidate does not touch destination, soak, occupancy, haste, or
lane assignment. It only lowers assassin hysteresis exit 8 -> 6, so
the issued goal becomes the lane waypoint while v1 still BFS-walks
to fountain.

## One change

`retreatExitFor(assassin) = 6`, other roles 8. Enter stays 3.

Prediction: Auto's mid assassin (and only that role) stops sitting
the 8/10 fountain tail. Issued velocity on assassin ticks at health
6-7 after a real retreat becomes the push waypoint step instead of
the fountain step. Burst/support/tank/carry remain v1. That cuts
the 1265-tick fountain sit seen in ereq_82528dd3 without cloning
first5 (occupancy / topstack / soak / haste / recovery).

## Trigger definition

Bounded `MOBA_TRIAL` JSON, idea `sustain`. Echo after the action is
fixed. Isolation: two policies, same obs, same action.

- `heroCalls`: every `heroAction`, including malformed no-ops.
- `triggers`: ticks where candidate mode != frozen v1 mode (assassin
  health 6-7 after a 3/10 enter; v1 still Retreat).
- `earlyExits`: those triggers that are assassin Push vs v1 Retreat.
- `changedActions`: those triggers whose **issued** `(dy,dx)` after
  the same stuck/detour snapshot differs from v1 fountain steering.
  Branch entry alone is not counted.
- `actualMoves`: changedActions where the candidate step is nonzero.

Skills are unchanged. Assassin E remains the v1 RetreatMode flag, so
the new push-at-6 tick has `use_e = 0` (not haste).

## Checks

```
nim check --nimcache:.../sustain/nimcache/check candidate.nim
nim r -d:policyTest --nimcache:.../sustain/nimcache/tests tests.nim
```

Isolation fixtures (synthetic 510-byte obs, no sim score): assassin
hp 3 enters and walks to fountain; hp 5 stays; hp 6 issues a
different velocity than the same-state fountain step and
`changedActions == 1`; fountain hp 6 walks off spawn where v1 holds;
burst/support/tank/carry hp 6-7 stay retreat; burst hp 8 exits with
no trigger; hp 4 never enters; siege hold unchanged; Q still flags
on creeps in the new push; E is not added; two policies match.

## Limitations

- Assassin early fountain leaves are a minority (7/36). The change
  will fire more often than Daveey does.
- r3728 is a real counterexample to "Daveey always returns at 6".
- Time-at-fountain also tracks how often the hero hit hp 3, which is
  not only the exit knob.
- Tower-death index from research was not used.
