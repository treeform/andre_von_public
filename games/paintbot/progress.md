# Paintbot Season 2 — progress

Updated 2026-09-09 14:06 PDT. Every trial with numbers: ideas.md. Field ladders: tools/field_ladders.md.

## Status
- Champion: **vasilisa:v4** (Andre von Auto, lpm_1c7b9f0a, placed 11:00 PDT). Base persona: target_law weakened/isolated, supply_run 900 at hp<64, loot 300 avoid, edge_ride 340/300/1.0.
- Board: 17th of 18 by standing (17,987). Standing is a 5%-weight EMA of round Glory; the leaders' 100k–200k ratings are decaying toward their new means. Catalog v3 (since round 4611, 10:25 PDT) pays ~16,384 per game won and ~1 otherwise, so the board is a win-rate contest.
- Recent form, rounds 4611–4617 (mean Glory per round): **Andre von Auto 24,732 (6 game wins in 4 rounds)**, Ari Sklar 11,772, Jordan/daveey/richard ~9,470, five players ~7,100, the rest 2,400–4,800. First by recent mean; the leaders need roughly 40–50 more rounds (~7 h at 10 min/round) to decay below us if this holds.
- v4 on a real sample (user request, 72 hosted games against the live field): 3 wins, 4.2%, the field's 1-in-16 rate. The dash's 100%-over-2-games row was noise.

## The engine drives everyone (found ~12:00)
- The shell's zone-escape reflex triggers when the next shrink is 72 ticks away for any cog inside the rectangle, releases only above 96, and while active its intent IS the standing order: controllers are not stepped, only overlays. It held our seat 78% of its alive time; daveey 81%, relh 79%, docxology 79%, Jordan 65%. There is no ladder position or opt-out in 0.7.377.
- The ladder activates at tick ~812 and the reflex takes over for good at ~1000: a controller gets ~190 ticks. Everything we tested changed those 190 ticks only. After that the field converges on the next rectangle's rim facing east (the reflex sets no idle aim).
- What still matters: the opening (position and pickups at tick 1000), overlays (target choice, hold fire, pacts), and combat power (levels from damage dealt).
- Openings decide (144 live games): a seat with a shield picked up before tick 1000 wins 14.6% (base 6.25%), a spray can 12.5%, two pickups 12.1%, none 5.6%. Alive at 1000 with a shield 14.9% vs 7.4% without. Winners average 2.2 kills and are leveled 69% of the time. Hence v11.

## Rules we play by
- Naming: one policy, `vasilisa:vN`, no descriptive names. Version → idea map in ideas.md.
- Identity: `coworld player use ply_3d22435e` before every upload (v3 landed under Andre von Houck and was retired).
- Keep rule: (1) the change fired in ≥10 of 12 games (ladders --fired); (2) replay kills/game and death order not below v4's; (3) win rate on the live coworld, same 15-champion field, two-proportion z ≥ 2 at ≥36 games. Only then submit. Inconclusive = not kept.

## What we learned
- The game: 16 solo seats, 4 hp, no respawns, closing zone. Deaths are gun kills (61 gun vs 2 zone per game). The first hitter wins 86% of duels; 77% of victims never fire back.
- The field is flat: every bot lands 0.5–0.9 kills a game at 75–85% hit; survivors over 36 games are all within noise of 1/16 (daveey 6, ours 5, relh 4).
- Our deaths (36 live games): 61% without firing back, killer hit first 71%, 300 ticks from first hit to death. daveey (best survivor): 43% silent, 444 ticks, more zone deaths. The survivor fires back and outlasts; we get ambushed while moving. Hence v9.
- Why v10: the aim turns 5 brads a tick, so answering a shot from behind takes ~30 ticks (180 degrees plus windup) while 4 hp lasts 36-48 ticks under fire at one shot per 12 ticks. The reference plays leave the idle aim facing east. Also universal: the shell's zone-escape reflex drives every bot ~100-170 intents a game whatever the ladder says.
- The lobby matters: bots negotiate in plain English before the drop ("non-aggression from the drop", "hold fire on our clones"). Our pact/envoy personas joined 22/36 and 3/12 games' alliances but won no more.
- Glory variance under the old catalog (one game = 10^4..10^7) made 12-game deltas meaningless; two "strong at 12" arms regressed at 36. Never read a 12-game Glory delta.

## Verdicts (live coworld, catalog v3, same field; details in ideas.md)
| arm | games | wins | verdict |
|---|---|---|---|
| baseline v3 | 36 | 2 | — |
| sentinel (own wasm: scanning hold) | 36 | 2 | fired 35/36; parity, not kept |
| v5 pact (lobby alliance) | 36 | 3 | fired 22/36; parity, not kept |
| v6 pactstrong | 12 | 0 | not kept |
| v7 envoy (match alliance phrasing) | 12 | 1 | fired 3/12; parity |
| v8 shield loot | 12 | 0 | void, never fired |
| watchride (own wasm) | 12 | 1 | void, never fired |
| v9 huddle (daveey's ladder) | 36 | 3 | fired 36/36; kills 0.75, death order 8.4 (below v4); z 0.46; not kept |
| v10 aim_ride | 36 | 3 | void, drove in 2/36 |
| v11 shield_ride | 36 | 6 | void, drove in 3/36 (z 1.50 not attributable) |
| v12 shield_aim_ride | 36 | 5 | void, drove in 6/36 |
| v13 shield_ride first in ladder | 36 | 3 | fired; pickup-radius bug, void |
| v14 shield_aim_ride first in ladder | 36 | 2 | fired 35/36; same bug; death order 6.7, not kept |
| v15 shield_ride, pickup fixed | 36 | 4 | fired 30/36; shields 0.36/game; z 0.85; death order 7.8; not kept |
| v16 hold fire until 8 teams | 36 | 0 | fired 36/36; t −2.07; revert |
| v17 prefer isolated first | 36 | 1 | parity; not kept |

Old-coworld arms (all not kept, replay metrics and Glory): prefer, ride, jackal, loot, heal, hold, still, docx, jackalwide, ridecover, center, centerhold, sentinel24, sentinelcover.

## Tooling (all Nim)
- vasilisa/vasilisa.nim: play-seat client, personas via `--persona`, lobby matcher, self-test `-d:vasilisaTest`.
- plays/: own wasm plays (center_hold, sentinel, sentinel_cover, watch_ride) + Dockerfile.playbuild.
- tools/ladders.nim (replay ladders, drive tallies, fired check), tools/episode_stats.nim (per-seat kills/shots/death order), tools/duels.nim (duel anatomy), ../../tools/glory_score.nim (win-rate z, log-Glory t, Mann-Whitney; scores keyed by policy_version_id).

## Assessment (14:06)
The engine plays 75-80% of every bot's game (zone reflex), and what the ladders do control (the ~190-tick opening plus targeting overlays) does not move the win rate at 36 games: 17 versions, every one inside the 1-in-16 band except hold-fire, which was worse. The board is a win-rate lottery over rounds; recent-round leaders (7 wins in 11 rounds vs our 2) are within noise of the same rate. The one thing that would change this is coworld-ctf's ratified plan to delete the native reflexes (policies author their own escape plays); when the league picks that up, every ladder matters again and our own plays (aim_ride, shield_ride) become live. Until then v4 stays champion.

## Next
- Watch coworld-ctf origin/main for the reflex removal (docs/designs/reflex-plays-decision-record-2026-09-08.md) and the league's coworld version; re-run aim_ride and shield_ride the day it lands.
- Keep v4 in; do not spend more 36-game arms on opening tweaks under the current engine.
- Watch v4's rounds; do not touch the champion unless a candidate passes the keep rule.
