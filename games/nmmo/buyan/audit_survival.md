# Buyan survival audit

2026-09-12. Read-only audit after hosted baseline XP
`xreq_f3cf306a...`. No local games or local scores. No keep verdict.
Paths below are under `sims/nmmo`, except named Buyan artifacts.

## What hosted evidence proves

`baseline_episodes.json` contains 10 completed episodes. The existing Nim
`summaries` tool reproduces descriptive means: Buyan 1.1934, relh consensus
7.6837, nmmo-opt 4.7386, daveey-nmmo-nim 4.9449. These are not a paired
candidate significance result.

The full result in `baseline_logs/ereq_ae977305-1b5c-47cb-b6d9-136cee3b9d46-policy_agent_0.log`
is particularly diagnostic:

| Seat | Deaths/resets | Banked min total | Final comb/prof | Current life age |
| --- | ---: | ---: | --- | ---: |
| Buyan 0 | 55 | 75 | 1/1 | 116 |
| Buyan 1 | 69 | 80 | 1/1 | 56 |
| relh 2 | 5 | 42 | 3/8 | 276 |
| relh 3 | 6 | 27 | 14/16 | 2724 |
| nmmo-opt 4 | 3 | 18 | 9/8 | 1966 |
| nmmo-opt 5 | 6 | 22 | 1/1 | 418 |
| daveey 6 | 2 | 13 | 1/1 | 0 |
| daveey 7 | 8 | 25 | 1/1 | 445 |

- All 8 seats have zero timeout, malformed, wrong-tick, disconnected and
  host-error NOOP causes. All stayed connected. The episode reached 5000.
- At most 10 resets per agent could come from the 500-tick stagnation rule
  (`vendor/upstream/nmmo3.h:1926`). Therefore at least 45 and 59 Buyan
  deaths were attacks. This is primarily survival failure, not merely
  stagnation, timeout or transport failure.
- The first Buyan's ended lives used 4884 ticks across 55 lives, about 89
  ticks per ended life; the second used 4944 across 69, about 72 ticks.
- Each ended life starts with minimum level 1. Banked totals therefore
  imply at least 35/55 and 58/69 ended lives never exceeded min=1. Most
  lives fail before the kill → tool → harvest bootstrap pays off.

The available final logs do not identify the killer or preceding actions.
The following mechanisms are source-backed explanations to classify in
hosted replays, not claims about measured death attribution.

## Why the script is exposed

| Mechanism | Buyan behavior | Consequence and source |
| --- | --- | --- |
| Persistent exploration | `buyan.nim:462` chooses 6–14 ticks of directional wandering and upgrades clear steps to runs. | Continuously enters new aggro boxes before obtaining armor. NPC aggro is a 4-tile square (`nmmo3.h:1577`); level9 hits a fresh player for 58 (`:1289`). |
| Hazard perception disappears | `liveHints`, `buyan.nim:392`, drops unchanged cells after TTL unless already in combat. No clean request. | Stationary real enemies and moving pursuers can become invisible to avoidance; reaction then begins after damage. Legacy entity residue makes blanket trust unsafe too. |
| No ranged model | Entity element is not decoded. Strong-enemy hints share generic flee geometry (`buyan.nim:711`). | Level15+ enemies are ranged/non-neutral (`nmmo3.h:1819`). They shoot along axes and move along the shortest gap axis (`:1591`), unlike melee. |
| Action destination mismatch | Flee scores the one-step destination, then `maybeRun` changes it to two steps (`buyan.nim:721`). Terrain-only passability ignores bodies. | The actual destination may enter another bow lane or contact zone. Either occupied run tile makes the entire run fail (`nmmo3.h:1197`). |
| Survival is preempted | Healing, fighting and nearby tool grabs run before disengagement (`buyan.nim:657`). Tool grabs pass an empty threat list (`:702`). | An herb or loot move consumes the tick while a lethal attacker acts. A level20 ranged hit on unarmored level1 is 113 damage before elemental scaling. |
| Combat is not simulated | Fight is a health/delta gate with no bystander or enemy-response model (`buyan.nim:665`). | The policy can stand in contact with several enemies. Attacks resolve down/up/right/left target priority (`nmmo3.h:1338`), so the actual target can differ from the weak hint selected by the bot. |
| No recovery phase | If no immediate branch applies, the damaged player wanders. | Health regenerates one per tick (`nmmo3.h:1960`), so a quiet refuge has direct value. Moving into another fight interrupts recovery. |

The five active trials each repair one issue. Clean observations could
materially improve hazard awareness, but armor/sword logic cannot help
the many lives that die before obtaining a usable tool and gear.

## What stronger public source does differently

The fetched `origin/sol/nmmo-scripted-20260813` branch is not proven to be
the source of the currently submitted daveey policy. It is useful design
evidence, not an exact identity match or hosted performance result.

Its `players/nimagent/executive.nim` contains:

- `wander`: long NOOP overwatch, rare 3–5-step walks, explicit bow and
  melee-entry vetoes, and a stagnation-urgency escape from idling.
- `bowDanger`/`flee`: element-specific bow handling, one-step-to-alignment
  hazards, and walking destinations checked against occupancy.
- `decide`: early engagement around radius6, recovery state, bystander
  checks, weapon-aware damage estimates and a bounded melee planner.
- `players/nimagent/planner.nim`: players-before-NPCs, exact melee pursuit,
  all nearby bodies, catastrophic death cost and depth5 action search.
- `players/nimagent/astar.nim`: walk-only routing around bow funnels and
  melee contact, rather than a greedy direction plus automatic run.

These are meaningful missing capabilities. They are also many changes at
once. The branch's historical local results must not be treated as our
score, and its comments acknowledge continuing bootstrap failures.

The other public policy is fundamentally different: the documented
PufferLib seed entry uses a pretrained recurrent MMONet
(`players/baseline_player.py`, `sim/brain_shim.c:1`, and the saved
`replays_tools/hosted/coworld014.json` baseline manifest). Buyan has none
of that network, its weights, or learned temporal state. Buyan is a port
of an early scripted example, not a port of the pretrained baseline.
The observed names `relh-nmmo-consensus` and `nmmo-opt` do not establish
their internals; no claim is made that their implementations were read.

## Recommended next single large experiment

**Replace the decision engine with the public pretrained MMONet in Nim.**
Use the unchanged published weights and standard categorical sampler.
Keep the current wire loop and reset semantics. Treat this as one explicit
policy-family replacement, not a bundle of five heuristic winners.

This is the most direct available reproduction of a documented strong
league participant. It tests whether learned survival and gear progression
solve the catastrophic bootstrap failure before we spend more trials
tuning isolated thresholds. No gain is assumed until hosted XP says so.

Implementation/verification constraints for a later worker:

- All new implementation remains Nim. Read the 4,430,976-float weights
  from `vendor/upstream/resources/nmmo3/nmmo3_weights.bin`.
- Follow tensor construction and ordering exactly (`nmmo3.c:30`,
  `sim/brain_shim.c:8`): 59-channel map encoding, two convolutions,
  scalar embedding plus raw scalars, projection, four MinGRU layers,
  decoder and categorical sampling. An argmax policy is another trial.
- Keep legacy observation encoding for the trained network. The pretrained
  model was trained on residue; combining clean mode changes its inputs.
- Reset only the affected agent's recurrent state on wire resets. Verify
  multi-tick logits/state against the reference inference on recorded
  hosted observations. Those isolation checks are not local games/scores.
- Instrument selected neural actions, differences from the submitted
  FSM shadow, recurrent reset counts, and inference latency/timeout causes.
  Count activated hosted episodes, then require matched-field significance.

Before interpreting the next XP, complete leader replay classification:
movement/NOOP rates, time to first kill/tool/armor, first300-life-tick
death share, ranged versus melee killing blow, blocked runs, deaths during
heal/loot, and entering an aggro box versus being approached. Use pinned
wasm reconstruction and matching final digest for state-level claims.
Historical action histograms alone cannot prove any of those outcomes.
