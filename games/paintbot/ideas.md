# Paintbot — Marya Morevna

Policy: **Marya Morevna** (`morevna`) — the warrior queen.

Coworld: `cow_ed016cb2-1cb0-4dc3-ae94-94ff66c5b1fa` (coworld name `paintbot`)

Paintbot: paintball-flavored capture-the-heart, AI bots only. Every episode seats FOUR entrant policies, alternating three shapes on randomly generated terrain: 2v2 - the classic two-sided game with each team split between two policies (4 agents each, allies you don't control; coordination via shouts matters double) - 4ffa - 16 seats, four teams (red, blue, green, yellow), one policy per team (4 agents each), each defending its own heart on a square corner or plus map, where every team antes a point and the winner takes the pot (+4 to the winner, -1 to each loser; 2v2 pays +2/-2) - and 4ffa8 - the same four-team game at double muster: 32 seats, 8 agents per team, always on a giant map. Core rules are identical to ctf. A two-team capture-the-heart shooter with fog-of-war vision. Red and Blue spawn on opposite edges, each guarding a heart on its home pedestal. Steal the enemy heart and carry it home - or wipe the enemy team. Two med kits on the center line heal the hurt back to full and respawn after 30 seconds. Grenade pickups wait in the corners: charged throws sail over walls and burst on landing, heard but not seen through the fog. Two spray cans spawn high in the side back columns: a carried arc disables your gun and turns the trigger into a forward spray paint cone - 5 squares of reach, 2.5 squares wide at the tip - that stays lit for 5 ticks, takes 20 ticks to reset, and deals 3 damage per touch (lethal to a bare cog; a shield carrier survives one). One shield sits low in each endzone's back column, vertically opposite the spray cans: carrying it grants 6 hit points but makes your fire rate 3x slower. Both are lost on death and respawn 30 seconds after being taken (see docs/RULES.md, Spray can and Shields). Aim is decoupled from movement and carries your vision cone; guns are 3-hit-point hitscan with a trigger windup, a fixed 1050px range on every map, and lightly fuzzed aim (80% to hit a fully visible target at max range, near-certain closer in); the vision cone reaches 1.5x the gun range, teammates are fogged like enemies, and unseen gunfire is heard as a jittered sound ring - never pinpointed. Players can shout: 10-character messages heard within a fifth of the field, tagged by player and team at jittered coordinates and drawn as speech bubbles in replays. Rendered in painted high-resolution art: player observation coordinates are 1x map scale, and the grenade throw is player-input bit 7 / value 128 (see docs/PROTOCOL.md).

## Leagues

- `league_15cf0b94-6081-4750-9c8f-49493da4ced2` — Elite Paintbot
- `league_b8fa9b35-ac22-48cf-a03f-07b397aff1c7` — Paintbot
- `league_3243d905-d32d-4ec6-978b-fa94751d4a37` — Ctf

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `baseline` — baseline: Minimal sprite-protocol CTF baseline bot: grab the flag, run it home, shoot enemies in front. Image placeholder is replaced at deploy time. (run: `/bin/baseline`)

## Baseline

The only example is `baseline` (`/bin/baseline`), described as "minimal
sprite-protocol CTF baseline bot: grab the flag, run it home, shoot enemies
in front"; the reference source it ships from (`coworld-ctf/players/
baseline/baseline.nim`) has since grown far past minimal (roles, cover
fields, peek-and-shoot). `morevna` is a Nim rewrite of the documented
minimal behavior on a full Sprite v1 stack: self-contained binary wire
parser + snappy decoder (round-trip verified against supersnappy), the
`walkability map` mask eroded into an 8px BFS flow field, objective logic
(grab nearest enemy `flag planted`, carry to our `endzone` marker center,
else press the nearest enemy endzone), `own aim` marker readback with
dead-reckoned rotation between frames, and a geometric fire gate (corridor
miss at range, walkability LOS, friendly-fire corridor, edge-triggered A,
no rotation on the pull tick). Handles 2- and 4-team maps via the
`game teams` / `endzone <color> <shape>` init markers. Deliberately never
sends Player Ready (0x85 corrupts league pacing, measured in PROTOCOL.md)
nor Sprites Off (0x87 — we need the walkability pixels). No LLM, so upload
needs no secret-envs.

Protocol confidence: high for the wire format (sprite_v1.md + PROTOCOL.md +
RULES.md all local); medium for behavior details inferred rather than
specified — carrier detection (enemy `flag carried` marker within 20px of
`self`), and "capture = reach endzone center" (RULES.md states zones by
box/shape; we navigate to the box center, which is inside the zone for all
five shapes). Verify both in the first hosted replay.

## Health check (worker)

Symptom: rating 0.0 in both Paintbot leagues after real rounds. That
pattern is a broken seat (never connects / never registers / crashes /
never acts), not a weak policy.

Root cause: `games/paintbot/morevna/morevna.nim:258` (was the
`label == "map"` branch of `applyPacket`'s Define Object handler).
PROTOCOL.md's in-game signal is the **map camera object** (object id 1,
sprite id 1). That sprite is unlabeled chrome — bitworld `addSprite`
defaults the label to `""`, and the known-good Sprite v1 seats
(`games/emerg-ant/zlydni/zlydni.nim`, `games/battleroyale/koschei/`)
match on those ids, not on a label. `mapPlaced` therefore stayed false
for the whole episode, `main` `continue`d past the 0x84 send, and the
seat never emitted a Player Input. A bot that never sends input scores 0.

Secondary hole on the same path: `main` dialed `newWebSocket` once with
no retry (contrast zlydni/koschei). A not-yet-ready game server was a
hard crash / lobby no-show.

Harness (`games/paintbot/tools/harness.nim`) replayed a synthetic
handshake: unlabeled sprite 1 + object 1/sprite 1. Before the fix,
`mapPlaced=false` and the send was skipped; after, the path emits a
non-zero 0x84 mask (right, toward the planted enemy flag). 0x85 Ready
and 0x87 Sprites-Off stay unsent, as PROTOCOL.md requires for league
play / walkability pixels. Snappy is only routed on the `walkability map`
Define Sprite, which is correct.

Fix: detect the map camera by object id 1 + sprite id 1; retry the
websocket dial until connected; gate `main` behind `when isMainModule`
so the harness can drive parse/decide.

Carrier detection (enemy `flag carried` within 20px of `self`) and
"capture = endzone-box center" were not the 0.0 cause; they remain
inferred and still need a hosted replay check.

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Med kit detour: when hurt (parse the `lives <n>hp x<n>` HUD label),
  detour to a visible `med kit` if the flow-field cost of the detour is
  under ~40 ticks — kits heal to full on touch.
- Grenade play: pick up corner `grenade` pickups when nearly on-path and
  charge/release bit 7 (0x80) to lob over the wall segment between us and a
  remembered fogged enemy cluster (grenade sound rings give the fix).
- Scan sweeps while stationary: rake the aim back and forth across a watch
  arc when holding position (the vision cone follows the aim), instead of
  keeping the turret frozen on the last error.
- Thief hunt: when our own `flag planted` marker disappears, intercept
  along the predicted carrier route toward its home edge using the last
  `<mycolor> flag carried` fix and its velocity.
- Per-seat roles for the multi-agent shapes (2v2/4ffa seat 4-8 agents of
  ours): split seats into rushers and one home defender at the choke in
  front of our pedestal, seeded from the slot index in the ws URL.
- Shield/spray pickups: grab the endzone `shield` when playing defender
  (6 hp for 3x fire rate is a good trade at a choke); avoid the spray can
  while carrying (it disables the gun).
- Trench/puddle costs: add soft path cost for `puddle` boxes (damage) and
  fire-discipline awareness inside `trench` boxes (3x cooldown when firing
  from inside).
- Shouts: broadcast a 10-char carry announcement ("HAVE HEART") so allied
  policies in 2v2 can escort; parse incoming shout labels for cheap intel.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | Home defender seat | One of every four team-seats (slot div teams mod 4 == 3) holds our planted heart and chases `<mycolor> flag carried` if it leaves. Capture eliminates us (GV32 / pot scoring); all four seats used to rush and leave the pedestal empty. | | | |


## Season 2 (2026-09-08) — Vasilisa

morevna v1/v2 were disqualified on 09-01 when the league became Season 2
(play-calling shell). New policy `vasilisa/` (Nim play-seat client, reference
playbook baked in, scripted cautious-floor ladder). Uploaded as vasilisa:v2.
GLORY: episode score = product of integer act multipliers (kill tiers, heat
x2/4/8 on streaks, +1 rung on enemy ground, Fibonacci co-engaged stack, win
x4, last light x4, closing time), divided by 2 per friendly-fire incident;
round score = sum of the 12 episodes. One 2^24 game (apex, round 4506) is
worth more than a thousand quiet survivals: standings are made by rare
exponential games, not by placement.

### Experiment log (Season 2, vasilisa)

Baseline = vasilisa:v3 (cautious floor). Field = the 15 current champions
(games/paintbot/eps/bodies/xreq_vasilisa_v3.json), 12 episodes, scored with
tools/glory_score.nim (log2 Welch t >= 2 and Mann-Whitney p < 0.05 to keep).

| # | idea (one change on v3) | policy | XP id | verdict |
|---|---|---|---|---|
| 0 | baseline v3 | vasilisa:v3 | xreq_54a68e10 | n=12 sum 23832 (one 16k game), median 6, mean log2 5.15, mean rank 8.3 |
| 1 | target_law prefer bounty,revenge,weakened,isolated (docxology) | vasilisa-prefer:v1 | xreq_f3d40cbe | INCONCLUSIVE n=12: log2 5.15 -> 4.18, t -0.60, MW p 0.56; ~135 eps/arm needed. Not kept. |
| 2 | edge_ride 240/260/0.8 (docxology) | vasilisa-ride:v1 | xreq_551a6423 + b/c | n=36: Glory log2 5.78 vs 5.22, t 0.55, MW p 0.20; replay kills 0.86/g, death order 9.6 (12-game 1.25/10.1 regressed). Not kept |
| 3 | jackal 900 bothWeakened hpFloor 0 while an enemy is tracked (docxology) | vasilisa-jackal:v1 | xreq_0538c09d + b/c | n=36: Glory log2 3.67 vs 5.22, t -1.76; replay kills 0.94/g, order 9.2. Not kept |
| 4 | loot 900 with medkits when clear (docxology) | vasilisa-loot:v1 | xreq_acd257df | INCONCLUSIVE n=12: log2 5.15 -> 4.02, t -0.77, MW p 0.82; ~82 eps/arm. Not kept. |
| 5 | supply_run whenHpBelow 3, detourMax 700 (docxology) | vasilisa-heal:v1 | xreq_a9eff75b | n=12: 3 wins (baseline 0), sum 2.1M, log2 7.36 vs 5.15, t 0.94, MW p 0.58 — INCONCLUSIVE, extended to 36: log2 3.99 vs 5.22, t -1.14 — regressed; not kept |

PLACED 2026-09-09 09:57: vasilisa:v3 is the competing champion (lpm_c9e12a12).
Replay finding (round 4506, ladders --drive + game log): 4 shots fired in a
16-seat game, all 15 eliminations are zone downs; the last cog inside the
closing zone wins the giant score. apex holds still (warden overlay + loot
2500) and lets the engine's zone reflex drive. Experiment 6: `hold` persona
= target_law + loot 2500 only, no scatter/edge_ride (apex's shape).
| 6 | hold: target_law + loot 2500 only, zone reflex drives (apex's shape) | vasilisa-hold:v1 | xreq_71bb94b7 + b/c | n=36 vs baseline 36: log2 4.91 vs 5.22, t -0.30 — the 12-ep signal regressed; not kept |
| 7 | center: edge_ride 600/600/0.0 (engine clamps to the middle band) | vasilisa-center:v1 | xreq_a0b4a39b | n=12 vs pooled baseline 24: log2 3.09 vs 4.73, t -1.40, MW p 0.19 — not kept (the middle-band clamp is worse than the plain margin) |
| 8 | centerhold: own wasm play center_hold (walk to the zone centre, hold) | vasilisa-centerhold:v1 | xreq_edfcc224 (+b/c) | DROPPED by replay evidence: our seat's death position median 6 of 16 (baseline v3 median 9, 2 survivals in 12). Walking to the rect centre crosses lethal painted ground / exposes the cog; the Glory delta at 12 was noise |
| 9 | still: target_law only (hold minus loot) | vasilisa-still:v1 | xreq_eacc164f + b/c | n=36: log2 4.52 vs 5.22, t -0.69 — not kept |

### What a giant game is (re-simulated events, tools/episode_stats.nim)
apex 16.7M: 6 kills on 14 shots (93%), 3 damage taken, 13 deeds. docxology
14.2M: 5 kills on 16 shots. richard 4.0M: 5 kills on 20 shots. daveey-1
5.3M: 3 kills on 14 shots. The field averages 3-6 shots and 0.5-0.9 kills a
game at 75-85% hit rate, so a giant game = one seat finds 4-6 duels, shoots
first, and stays healthy while the others trade. The body shoots the same
for everyone; position (near fights, from cover, at full hp) is the lever.
Judge arms by kills/shots/death order from replays (12 games suffice), not
by Glory (needs 100+).

### Replay metrics per arm (12 games each, our seat; tools/episode_stats.nim)
| arm | kills/g | shots/g | hit | death order | wins |
|---|---|---|---|---|---|
| v3 | 1.08 | 4.9 | .78 | 8.8 | 2 |
| ride 240/260/0.8 | 1.25 | 6.1 | .82 | 10.1 | 1 |
| jackal | 1.08 | 6.2 | .81 | 9.8 | 2 |
| prefer | 1.17 | 5.1 | .77 | 8.8 | 1 |
| hold | 0.75 | 5.9 | .77 | 9.5 | 0 |
| heal | 0.50 | 3.9 | .79 | 8.2 | 0 |
| loot | 0.50 | 3.7 | .70 | 6.9 | 2 |
| still | 0.75 | 4.2 | .68 | 6.9 | 1 |
| centerhold | 0.42 | 2.8 | .88 | 5.9 | 0 |
ride and jackal raise fights found AND survival; extending both to 36 and
adding `docx` (prefer + ride + jackal, docxology's ladder) as candidate 10.

### The structural gap (deed chains, 2026-09-09 12:40)
Glory is a product of deed multipliers. Winners' chains: apex 16.7M = three
dJointAct x3, four dClosingTime x4 (kills during a closing phase, which is
nearly the whole game), dFirstBlood x6, dLongshotKill x4, dHonorableKill,
then win x4 and last light x4. The field mints dShieldSoak 0.68 and
dClutchHeal 0.06 per seat-game; we mint neither (never pick up shields or
heal). Our wins carry ~2 kills (6,144); a giant game carries 5-6 kills in
the closing phase (4^6 on its own). Kills per game is the whole gap, and the
first hitter wins 86% of duels: first sight (scan while holding) and
reaching fights (jackal, tighter ride) are the levers; shields cost fire rate.
| 11 | docx = prefer + ride + jackal (docxology's ladder) | vasilisa-docx:v1 | xreq_6bd86d10, xreq_43f10bd5, xreq_99bd256c | replay 36 games: kills 0.78/g, order 8.2, hit .69; Glory t -1.85 — worse. Not kept |
| 12 | jackalwide: jackal earshot 1200, afterKill | vasilisa-jackalwide:v1 | xreq_cd567c5b | replay 12: kills 0.92, death order 7.7, alive 1324 — worse. Not kept |
| 13 | ridecover: edge_ride 240/260 coverBias 1.0 | vasilisa-ridecover:v1 | xreq_c3173890 | replay 12: kills 1.08, order 8.8 — equal to v3. Not kept |
| 14 | sentinel: own wasm play, hold and rotate idle aim a quadrant per 48 ticks | vasilisa-sentinel:v2 | xreq_545cc786 (v1 arm xreq_d89f5099 is a MISLABELLED BASELINE: the image was built before the play linked) | |

Round-1 conclusion (36 games per arm): every reference-play ladder sits in the
field's parity band; 12-game replay leads regress just like Glory. The field
runs the same public plays. Only behaviours the reference plays cannot express
can move us: first sight via the idle aim (sentinel, watch_ride).

### CORRECTION 2026-09-09 13:20 — Glory verdicts above were mis-attributed
glory_score.nim read `scores` by participant position, but the episodes
JSON lists scores by policy_version_id in a different order. Every Glory
number in rows 0-13 above is wrong (replay metrics were slot-based and
stand). Re-scored with the fix, baseline v3 36 games = sum 318,900, mean
log2 5.99, 3 wins:
| arm | n | sum | log2 | t |
|---|---|---|---|---|
| sentinel (own play) | 12 | 10,716,078 (one 10.6M game: 6 kills, 17 shots, untouched, last standing) | 6.40 | +0.19 |
| ride | 36 | 192,780 | 6.06 | +0.06 |
| jackal | 36 | 706,226 | 5.56 | -0.38 |
| still | 36 | 542,884 | 5.18 | -0.75 |
| docx | 36 | 184,424 | 5.10 | -0.87 |
| hold | 36 | 38,078 | 4.43 | -1.70 |
| heal | 36 | 65,668 | 4.43 | -1.64 |
| prefer | 12 | 32,076 | 5.71 | -0.19 |
| ridecover | 12 | 8,600 | 5.72 | -0.20 |
| jackalwide | 12 | 25,276 | 4.75 | -0.95 |
| loot | 12 | 7,728 | 3.90 | -1.60 |
| center | 12 | 1,272 | 3.98 | -1.81 |
| centerhold | 12 | 782 | 3.73 | -2.32 REVERT |
Sentinel fired (sentinel:scan intents accepted) in every one of its 12
games; extending to 36 (xreq_d5b2a20c, xreq_163f21cf).
| 15 | watch_ride: own wasm, edge_ride 240/260/0.8 movement + scanning hold | vasilisa-watchride:v1 | xreq_8d388e04 | VOID: fired 0/12 (edge_ride never holds, so the scan never ran); numbers = plain ride |
| 16 | sentinel24: rotation period 24 ticks | vasilisa-sentinel24:v1 | xreq_63785513 | fired 11/12; WORSE: death order 5.1, kills 0.50, Glory t -3.15. Not kept |
| 17 | sentinelloot: sentinel + loot 2500 | vasilisa-sentinelloot:v1 | xreq_dadb0369 | VOID: fired 0/12 (loot always has a target and outranks sentinel) |
| 18 | sentinel_cover: own wasm, walk to the nearest cover post then hold and scan | vasilisa-sentinelcover:v1 | xreq_69a5d12a | fired 8/12 (19 intents); WORSE: death order 6.1, kills 0.50. Not kept |

GAME CHANGED under the league (rounds 4611+, 2026-09-09 ~10:30 PDT): gameVersion 59->62, gloryVersion 14->17, new flags brAssistRescueUngated, catalogV3Reprice; round tops fell from 500k+ to ~33k. XP arms so far ran on cow_f5c2437d (0.7.357); the field must move to the live coworld.
| 19 | pact: lobby alliance proposal; seats answering 'pact' become partners (holdFire aliveTeams 6, disengage) | vasilisa-pact:v1 = vasilisa:v5 | xreq_77285f67 (live coworld) + v5 arms | 12 vs live v3 24: Glory 32,847 vs 272 (median 2 vs 1), log2 4.03 vs 1.83, t 1.52, MW p 0.087, wins 2 vs 1; fired (no_shoot) 9/12 games, 490 intents; replay kills 0.75, death order 7.1. Best lead under catalog v3; extending to 36 |
| 20 | NEW-coworld baseline v3 (36) xreq_8d0403e7/a2d81023/7cae7582; sentinel (36) xreq_da5829a3/5e67cbdf/9a56b378; watchride (12) xreq_3deb5b8c | | | |

Sentinel at 36 (old coworld): Glory log2 5.15 vs 5.22, t -0.73 (the 10.6M game
stands alone); replay kills 0.81/g, death order 7.1, alive 1369 (v3: 1.08, 8.8,
2066); fired 36/36 games, 147 scanning holds. Verdict: NOT KEPT as is — holding
in the open dies earlier; the scan wins duels it sees but the seat gets caught
by the zone/aggressors more. Successors under test: sentinel_cover (post at
cover first), watch_ride (ring movement + scanning holds).

### Version map for vasilisa-auto (one name, plain versions from here on)
| version | persona |
|---|---|
| v1 | base (champion, = vasilisa:v3) |
| vasilisa:v4 | base, Andre von Auto (champion) |
| vasilisa:v5 | pact persona (arms xreq_44fbc408, xreq_bd7ffdb8 + vasilisa-pact:v1 xreq_77285f67) |
| vasilisa:v6 | pactstrong (protect true, holdFire aliveTeams 4, returnFire) arm xreq_b123728c |
| vasilisa:v7 | envoy (alliance-phrase matcher + reciprocal lobby line) arm xreq_4ab7871d |
| vasilisa:v8 | shield (loot 400 race only while a shield is in view) arm xreq_2e9f6db3 — VOID, never fired |
| vasilisa:v9 | huddle = daveey's paintbot-huddle:v159 ladder (scatter; edge_ride 220/160/0.75; target_law weakened/isolated/bounty from t1100; supply_run hp<2; short shield loot; late jackal afterKill hpFloor 1; margin 180 after t2400), 36 games |
| vasilisa:v10 | aimride = v4's ladder with our own aim_ride wasm in place of edge_ride: same movement, idle aim centre on the nearest fresh enemy track (150 ticks) else the zone centre, re-sent when it moves 8 brads. Rationale: aim turns 5 brads/tick (180 deg = 26 ticks + 5 windup) while 4 hp lasts 36-48 ticks under fire; 61% of our deaths never fire back |
| vasilisa:v11 | shieldride = v4's ladder with shield_ride (own wasm): edge_ride movement + detour to the nearest shield or spray can within 600 px. Evidence: over 144 live games an opening shield pickup wins 14.6% vs 6.25% base, spray 12.5%, two opening pickups 12.1%; the ladder controls only ~190 ticks before the zone reflex |
| vasilisa:v12 | shieldaim = shield_ride plus aim_ride's threat-facing idle aim (second change, tested separately) |
| vasilisa:v13 | shieldride2 = target_law + shield_ride only (scatter 120 in the pre-call); v11/v12 never drove because medkit/loot entries above took the opening |
| vasilisa:v14 | shieldaim2 = the same with shield_aim_ride |
| vasilisa:v15 | shieldride2 with the pickup bug fixed: item goals use an 8 px arrive radius (pickup range is 12 px; v13/v14 stopped 24 px short and collected almost nothing) |
| vasilisa:v16 | holdlate = v4 with target_law holdTrigger aliveTeams 8 (do not start fights until 8 teams remain; return fire stays permitted) |
| vasilisa:v17 | preferiso = v4 with target_law prefer [isolated, weakened, revenge] |

Pact fired-only split (glory_score --only): the 9 games where no_shoot lists
bound = 16,460 Glory (1 win, log2 3.53); the 3 games where none bound = 16,387
(1 win, log2 5.53). Half the arm's Glory came from games where the pact did
nothing, so the +t is not attributable to the pact yet. Under catalog v3 most
games score 1-2 for everyone (live v3 baseline median 1), so Glory
comparisons reduce to "who won"; replay metrics at 36 remain the judge.

### Catalog v3 = a win-rate contest (2026-09-09 15:10)
Round 4615's top game: relh 16,384 (2^14); every other seat 1-65. A round is
~2^14 per game won and ~1 otherwise; our 16.4k rounds were one win each. The
standing (EMA) now tracks wins per round x 16k. Parity is 1 win in 16 games.
The test that matters: rank-1 rate, candidate vs baseline (two-proportion z),
with the fired filter. Live baseline v3: 1 win / 24; sentinel live 2 / 12;
pact 2 / 12 (both directions worth the 36-game extension).

### Live-coworld verdicts (catalog v3, same 15-champion field, 2026-09-09 16:00)
| arm | games | wins | Glory sum | verdict |
|---|---|---|---|---|
| baseline v3 | 36 | 2 | 507 | — |
| sentinel (scan hold) | 36 | 2 | 1,041 | fired 35/36 (155 intents); replay kills 0.83, death order 8.9 = baseline; parity, not kept |
| v5 pact | 36 | 3 (2 in the first 12, 1 in the next 24) | 33,024 | fired 22/36; parity, not kept |
| v6 pactstrong | 12 | 0 | 38 | fired 6/12; not kept |
| v7 envoy | 12 | 1 | 16,418 | fired 3/12 (126 intents); parity |
| v8 shield | 12 | 0 | 92 | VOID: loot gate never fired |
| watchride | 12 | 1 | 234 | VOID: scan never fires in edge_ride |
| v9 huddle (daveey's ladder) | 36 | 3 | 16,556 | fired 36/36 (scatter/loot/ride accepted, mean 4.9 calls); replay kills 0.75, hit 0.88, death order 8.4 (v3 1.08 / 8.8); win z 0.46 p 0.64; NOT KEPT |
| v10 aimride (aim_ride wasm, first build) | 36 | 3 | VOID: aim_ride intents accepted in only 2/36 games (14 intents, idle aim 184/192 accepted where it ran); the full-view reader failed elsewhere and the shell default drove. Glory 32,895, kills 1.03, death order 10.0 (not attributable). Rebuilding with the edge_ride view reader for movement |
| v11 shieldride | 36 | 6 (rank-1; 2 sole survivors) | 98,390 | VOID: shield_ride drove in 3/36 games (item detour 2/36); the medkit entry (supply_run whenHpBelow 64) or scatter takes the controller slot from activation, then the reflex. z 1.50 not attributable |
| v12 shieldaim | 36 | 5 | 33,166 | VOID: drove in 6/36 games (item 3/36) |
| v13 shieldride2 | 36 | 3 | 32,993 | fired 28/36 (35 item intents); kills 0.81, death order 8.4; pickups ~0 because the item goal's 24 px arrive radius never reaches the 12 px pickup range; z 0.46; VOID (bug) |
| v14 shieldaim2 | 36 | 2 | 32,857 | fired 35/36 (171 intents, item 26/36); pickups ~0 (same bug); death order 6.7 vs 8.8, kills 0.56: chasing items (and not getting them) dies earlier. NOT KEPT |
| v15 shieldride3 (8 px item arrive) | 36 | 4 | 16,971 | fired 30/36 (42 item intents); shields 0.36/game (0.14 before tick 1000) vs field 0.10, spray 0.16; kills 0.89, death order 7.8 (below 8.8); win z 0.85 p 0.39. NOT KEPT (inconclusive; survival not better) |
| v16 holdlate (hold fire until 8 teams) | 36 | 0 | 121 | fired 36/36 (hold_fire in 2,133 intents); kills 0.39, shots 2.3, death order 9.4 (survives longer, never wins); log2 t -2.07 p 0.048. REVERT |
| v17 preferiso (isolated > weakened > revenge) | 36 | 1 | 16,667 | kills 1.00, death order 7.9; z -0.59. NOT KEPT |
Every arm sits at the field's 1-in-16 win rate. Under catalog v3 the only
thing that scores is being the last cog standing.
Survivors per bot over the 36 live baseline games (episode_stats): daveey 6,
ours 5, relh 4, Lawrence 3, macromackie 3, everyone else 0-2 — all within
noise of the 2.25 expected at a flat 1/16. No bot to copy; the field is flat.

### How we die (36 live baseline games, tools/duels.nim --seat=0)
31 deaths: 19 without firing back (61%), killer hit first in 22 (71%), 300
ticks from first hit to death, 5 zone deaths; killers soft-codexter 6,
daveey 6, relh 5, docxology 4, richard 4. daveey (huddle v159, most
survivals): 30 deaths, 13 silent (43%), killer first 16 (53%), 444 ticks
first hit to death, 9 zone deaths. The survivor fires back and outlasts;
we get ambushed while moving. Next single change: copy daveey's ladder.

### Zone-escape reflex share (ladders --drive, seat 0, 2026-09-09 12:00)
Every arm shows the shell's reflex_zone_escape issuing 95-170 intents per
game in 25-28 of 36 games (v3 115/g, v9 139/g, sentinel 140/g, pact 94/g,
envoy 168/g): roughly a tenth of the ticks alive are spent fleeing the shrink
under the reflex's 0.25x danger profile, whatever the ladder says (the ladder
itself drives ~5-7 intents a game). The reflex triggers at 72 ticks to
exclusion and releases at 96, independent of edge_ride's margin. Next check:
what the seat was doing when it died (ladders --drive now prints it).

### The engine drives everyone (2026-09-09 13:00)
Time share of the standing order's driver, seat 0, live baseline v3 (36
games): reflex_zone_escape 77.7%, supply_run medkit 17.6%, edge_ride 2.2%,
loot 1.4%, scatter 0.8%. v9 70.8% reflex; v10 77.7%. Rivals in the same games:
daveey 81%, docxology 79%, relh 79%, soft-codexter 73%, Jordan 65%.
Mechanism (coworld-ctf src/shell/episode.nim zoneTicksUntilOutside +
ladder.nim stepSeat): the native reflex triggers when ticks-to-next-shrink
<= 72 for ANY point inside the current rect (the next rect is ignored),
releases only above 96, and while active its intent IS the base: controllers
are not stepped at all, only overlays. In the v10 fired game aim_ride drove
816-999, then the reflex held every tick to death at 1933. No ladder entry
can outrank or opt out of it in 0.7.377 (NativeReflexSubscriptions at call
0; the 2026-09-08 decision record plans to remove native reflexes later).
Consequences: every ladder we tested controlled ~20% of the game (the first
~1000 ticks); all idle aims are 0 (east) under the reflex; the reflex sends
every bot to the nearest point inside the next rect, so the field converges
on the next rect's rim. Remaining levers: overlays (target_law prefer, hold
fire, pacts), where we stand at tick ~1000, combat power (levels), and lobby.
v10 (aim_ride) can only matter before the reflex; keep it as a build, do not
extend the arm.

### Openings decide (144 live games, events)
Ladder activation is tick ~812; the zone reflex takes the base for good at
~tick 1000. Deaths before 1000: 2.5 of 15 per game. Winners: 93% have a
kill, 2.2 kills on average, 69% leveled (only damage grants XP, 3 per hp;
levels cut fire cooldown 25% and add hp). Pickups before tick 1000 and the
win rate of that seat: shield 14.6% (n 137), spray can 12.5% (80), medkit
7.9%, grenade 6.7% (194); 2 pickups 12.1%, 1 pickup 8.6%, none 5.6%.
Alive at 1000: 7.4%; alive at 1000 with a shield: 14.9%. We already loot
more than the field (shields 0.22/game vs 0.10 per seat). Next: v11.
Controller window (36 live v3 games, seat 0): the first zone-reflex intent
lands at tick 932 min, 989 p25, 1024 median, 1457 p75; after it no
controller intent is ever accepted again in any game (0 of 36). The ladder's
whole influence is ticks ~812 to ~1000.

### v4's real opening (v11 driver timelines)
Activation tick varies 822-1359 by game. In most games the medkit entry
(supply_run, whenHpBelow 64, added by the client at activation) drives from
~8 ticks after activation until the reflex takes over; scatter (300 ticks)
covers the rest. edge_ride / shield_ride get the slot in 3 of 36 games. The
champion's opening is therefore "walk to the nearest medkit within 900 px".
v13 removes everything above shield_ride except target_law.

### v4 sample for the public table (2026-09-09 evening)
User asked for a real sample behind the dash's "100% over 2 games" row. Six
12-episode requests of vasilisa:v4 on the live field (xreq_635ea740,
0510dfc5, 759e0368, 237141e4, 09a27cbe, 60aa758c): 3 wins in 72 (4.2%),
Glory 17,060, vs the live v3 baseline 2/36; z -0.32. v4 is at the field's
1-in-16 rate like everything else.
