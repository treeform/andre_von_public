# Mindustry Survival

Two BASIC policies defend identical Ground Zero survival worlds. Each seat gets
its own Java process, native player flyer, starting inventory, rules and seed. Policy
code runs in the bounded Nim/Bassy host used by Polyworld and Gods of the Arena.
Only BASIC files execute. Submitted files cannot load Java mods or native code.

The simulation runs at 60 ticks per simulated second. Policies decide every six
ticks. A match ends when the core dies or the configured tick limit is reached.
The ten-minute limit is 36,000 ticks. Waves spawn every 3,600 ticks by default.
The score is `clearedWaves * 2 * maxTicks + ticksSurvived`. Wave completion
therefore takes priority over survival time. Seats run sequentially with fresh
engine globals. The current scenario uses native Dagger waves that grow over time.

## Run locally

Install Nim 2.2.10, Java 17 and Python 3. Clone Mindustry next to this repository: `git clone https://github.com/Anuken/Mindustry ../mindustry`.
Check out the revision with `git -C ../mindustry checkout "$(cat coworld/mindustry/engine.commit)"`.
The engine revision is pinned in `engine.commit`. The build script applies the
evaluation-only determinism patch and builds the server and sprite atlas.
The patch settles pathfinding, orders building adjacency by tile, and disables
wall-clock construction audio in evaluation runs. Desktop gameplay is unchanged.

From the coworld-mindustry repository:

```sh
# Set JAVA_HOME if the portable JDK in ../mindustry/.local is unavailable.
coworld/mindustry/tools/build_adapter.sh
nim r --hints:off --nimcache:tmp/coworld/tool-cache/deps coworld/tools/sync_dependencies.nim
export POLYWORLD_DEPS="$PWD/tmp/coworld/deps"
nim c --hints:off --nimcache:tmp/mindustry/nimcache \
  -o:tmp/mindustry/mindustry examples/mindustry/mindustry.nim
tmp/mindustry/mindustry --bot coworld/mindustry/players/base.bas:2 \
  --ticks 36000 --seed 2026 --record tmp/mindustry/demo.replay
coworld/mindustry/tools/build_replay_viewer.sh "$PWD/tmp/mindustry/viewer"
mkdir -p tmp/mindustry/viewer/replays
cp tmp/mindustry/demo.replay tmp/mindustry/viewer/replays/demo.replay
python3 -m http.server 8769 --bind 127.0.0.1 --directory tmp/mindustry/viewer
```

Open `http://127.0.0.1:8769/index.html?replay=replays/demo.replay`.
The viewer shows the map and a bottom playback bar. Use play/pause, frame
stepping, beginning/end, looping, the timeline, and 1x/2x/4x/16x speed. The
camera buttons fit the map or follow the flyer. Drag to pan and scroll to zoom.
The gold ring marks the player-controlled unit. Add `&seat=1` to the URL to
watch the second policy seat (seat indices start at zero).

`MINDUSTRY_DIR`, `MINDUSTRY_JAVA`, `MINDUSTRY_JAR` and `MINDUSTRY_CLASSES`
can select installed engine artifacts. The Docker image sets these automatically.
`--wave-spacing` accepts 120 to 3,600 ticks. `--wave-units` accepts 1 to 200
starting Daggers. These are local stress-test controls, not competition overrides.

## BASIC API

Numeric queries use parentheses. Variables and DIM arrays persist across
six-tick decisions. DIM arrays use `array(index)`. `/` performs fractional
division. Use `\` for integer tile arithmetic. PRINT is private in hosted games.
Unknown function names can be interpreted as array indexing by BASIC, so use
only the documented API and compile-check your policy.

| Query | Meaning |
| --- | --- |
| `tick()`, `wave()`, `cleared()` | Simulation tick, current wave and waves cleared. |
| `coreX()`, `coreY()`, `coreHealth()` | Own core tile and current health. |
| `pending()`, `planCount()`, `plan(i, field)` | Queued plans: x, y, rotation, native block ID (-1 breaks). |
| `controlled()`, `flyerX()`, `flyerY()`, `flyerHealth()` | Current player-controlled unit ID, tile position and health. |
| `carriedItem()`, `carried()` | Carried item ID (-1 empty) and amount. |
| `blockId("duo")`, `itemId("copper")`, `unitTypeId("alpha")`, `liquidId("water")` | Native content IDs by name, -1 if absent. |
| `commandId("move")`, `stanceId("stop")` | Native RTS command and stance IDs by name. |
| `contentAt(x, y)`, `configAt(x, y, field)` | Native block ID and tagged configuration fields. |
| `mapWidth()`, `mapHeight()` | Map dimensions in tiles. |
| `oreAt(x, y)` | 1 copper, 2 lead, 3 coal, 0 otherwise. |
| `blockAt(x, y)` | Palette ID, -1 empty, -2 other structure or boundary. |
| `stock(itemId)` | Core inventory in pinned Mindustry item order. |
| `buildingCount()`, `unitCount()`, `projectileCount()` | Full visible snapshot counts. |
| `building(i, field)`, `unit(i, field)`, `projectile(i, field)` | Numeric fields in flat recorded rows. Positions preserve fractional values. |
| `build(blockId, x, y, rotation)` | Queue an order. -1 breaks a native interactable tile. |

| Block ID | Block |
| --- | --- |
| 0 | Mechanical drill, 2 by 2 tiles. |
| 1 | Conveyor. |
| 2 | Router. |
| 3 | Junction. |
| 4 | Copper wall. |
| 5 | Duo. |
| 6 | Graphite press, 2 by 2 tiles. |

Item IDs include copper 0, lead 1, graphite 3 and coal 5. The replay catalog
contains all pinned item names and exact construction recipes.

Building fields are ID 0, x 2, y 3, size 4, team 5, health 6, orientation 7,
turret angle 8, construction fraction 9, turret ammo 11 and enabled flag 13.
Field 12 is a configuration row read through `configAt`, starting with a type
tag: 0 integer, 1 boolean, 2 item, 3 liquid, 4 block, 5 unit type, 6 point,
7 text, 8 bytes, 9 point pairs, -1 empty. Replay field 14 contains conveyor item
rows `[itemId, lateralPosition, forwardProgress]`. Field 15 contains the native
conveyor visual row `[variant, xScale, yScale, branchMask, effectiveSpeed, clogHeat]`.
These nested replay fields are not scalar BASIC queries. Unit fields are ID 0,
x 2, y 3, angle 4, health 5, team 6, mining tile x/y 7/8, velocity x/y
9/10 in tiles per tick, native unit type 11 and firing flag 12. Projectile fields are ID 0, x 1, y 2,
angle 3 and team 4. Invalid indexes and nonnumeric fields return zero. The host
exposes all entities, including enemies, without fog. Replays preserve fractional
coordinates and construction progress in both the replay and BASIC queries.

Rotation is native Mindustry orientation: 0 east, 1 north, 2 west, 3 south.
`build` returns 1 when the host queues an order, or 0 after eight orders in a
decision. The Java adapter then applies native placement validation and reports
accepted, invalid-place, invalid-break, invalid-order, queue-full or builder-dead
in the replay. Acceptance does not guarantee completion. A maximum of 64 native
plans can wait. Native resource costs, build time, terrain restrictions and build range remain
active. The player respawns through Mindustry's normal core-spawn mechanism.

The policy controls a native Player entity, just as a human controls a unit.
The adapter never chooses targets, presses fire, starts mining, or flies toward
a build plan for it. Movement, aim, firing, boosting and mining inputs are
released at each decision; repeat a command to hold it for the next six ticks.
Native momentum decays when movement is released. Queued construction continues
within build range, as in the human client; the policy must fly into range.

Friendly AI units, factories and unpossessed turrets retain Mindustry's normal
automation. Turrets select targets and fire when supplied. Friendly units use
their native controllers and stances. Possess a unit or turret to control it
with player inputs. Other units receive the same RTS orders available in the
human client. The API does not offer remote direct weapon control of arbitrary
friendly units or turrets. Native passive abilities and mining delivery remain
normal game mechanics.

Each command returns 1 when queued in the host, or 0 if a host limit rejects it.
Native ownership, capability, range and placement checks run afterward; inspect
recorded command statuses for acceptance. Coordinates use tiles, angles use
degrees, booleans use 0/1. The command budget is 32 per decision and 48 KiB,
in addition to the eight legacy `build` orders.

| Player input | Meaning |
| --- | --- |
| `move(dx, dy)` | Direction, clamped to length 1, multiplied by native speed. |
| `aim(x, y)`, `shoot(enabled)`, `boost(enabled)` | Aim point, weapon input and boost input. |
| `mine(x, y)`, `stopMine()` | Mine a native valid tile within mining range, or stop. |
| `buildBlock(nativeId, x, y, rotation)`, `breakBlock(x, y)` | Queue native construction or deconstruction. |
| `buildEnable(enabled)`, `clearPlans()`, `removePlan(x, y, breaking)` | Pause, clear or remove construction plans. |
| `rotate(x, y, direction)`, `tap(x, y)` | Rotate a building (positive adds one rotation step) or use its native tap action. |
| `take(x, y, itemId, amount)`, `deposit(x, y)`, `dropItem(angle)` | Native inventory interactions within range. |
| `controlUnit(id)`, `controlBuilding(x, y)`, `leaveUnit()` | Possess an eligible friendly unit/building, or leave it. |
| `pickupUnit(id)`, `pickupBuilding(x, y)`, `dropPayload(x, y)`, `enterPayload(x, y)` | Native payload actions on capable units/buildings. |
| `commandMove(id, x, y, queue)`, `commandAttackUnit(id, targetId, queue)`, `commandAttackBuilding(id, x, y, queue)` | Human RTS movement and attack orders to a friendly AI unit. |
| `unitCommand(id, commandId)`, `unitStance(id, stanceId, enabled)` | Select a supported native AI command or stance. |
| `commandBuilding(x, y, targetX, targetY)` | Set the rally point of a commandable factory. |
| `unitMove(id, dx, dy)`, `unitAim(id, x, y)`, `unitShoot(id, enabled)`, `unitBoost(id, enabled)`, `unitMine(id, x, y)`, `unitBuild(id, nativeId, x, y, rotation)` | Explicit aliases restricted to the currently possessed unit. |

Configuration uses the native building handlers. `configure(x, y, kind, value)`
accepts kinds 0 integer, 1 boolean, 2 item ID, 3 liquid ID, 4 block ID and
5 unit type ID. `configurePoint(x, y, dx, dy)` passes a native relative point.
`configureText(x, y, "text")` handles message blocks. `configureCode(x, y, "mlog")`
compresses processor code while preserving existing links.
`configureReset(x, y)` clears a configuration. `configurePoints(x, y, array)`
passes flat relative x/y pairs; `configureBytes(x, y, array)` passes raw byte
configuration. Arrays are DIM handles, limited to 1,024 numeric cells. Text is
limited to 4,096 characters. Unsupported configuration types are rejected.

Empty tiles can still be unsuitable terrain or outside the core's placement
area. Observe the replay's order statuses when designing a construction plan.
The reference `base.bas` scans the terrain near the core, reserves an exposed
copper tile for player mining, and builds four drills. A reverse breadth-first
search routes their conveyors into the core around obstacles and drill footprints.
The planner spreads work across decisions to stay within the BASIC budget.
It then builds a spaced Duo ring and a northern copper wall. The flyer explicitly
moves, mines, takes copper from the core, refills low-ammo turrets, leads nearby
enemies and fires. Native turrets target enemies automatically. The policy
revisits its blueprint to rebuild destroyed structures and reserves copper for
ammo. `starter.bas` preserves the original short drill-and-Duo example.

This policy targets the current Ground Zero scenario and copper-based defense.
It does not yet build advanced factories, power, research or unit production.
Run `python3 coworld/mindustry/tools/check_bot.py` to measure survival, verify
four directed drill-to-core paths, check copper income with player mining disabled,
and compare all recorded states and hashes against a fresh Java simulation.

Limits per policy: 64 KiB source, 20,000 compiled instructions, 2 MiB memory,
4,096 array cells, 256 globals, 16 call depth, 100,000 instructions and 250,000
work units per decision. Printing has a 1,024-byte and 128-event decision budget.
A runtime failure stops that policy's subsequent commands and is reported to
its private log. Existing shared annotation functions remain available.

## Replay and determinism

MDR1 is a little-endian four-byte magic, a 32-bit JSON-header byte count, the
UTF-8 header, then independently gzip-compressed JSON frame chunks. Each index
entry gives slot, ticks, byte offset, compressed length, frame count and final
native state digest. The outer replay uses Coworld `identity` compression.

The header stores static terrain as palette-indexed runs, a block/item catalog,
seat names, seed and final scores. Each five-second chunk starts with the full
building state. Later frames contain changed and removed buildings. Units,
turret directions, visible projectiles, core health, inventory, order results
and native state digests are sampled at 10 Hz. The browser interpolates motion
and never runs the simulation. It loads byte ranges when the server supports
Range and keeps at most three decoded chunks. Servers without Range fall back
to downloading the compressed file once.

Sprite artwork is shipped once in the viewer bundle, with exported atlas
coordinates and native terrain metadata. Floors blend using neighboring edge
stencils, native blend groups and layer priority. Matching walls use aligned
2 by 2 patches, and autotile sprites use the native eight-neighbor masks.
Tile variants and wall patches use the same coordinate RNG as the Java client.
These choices are cached when a map loads and do not enlarge replay files.
Mining beams use the native laser sprites, source offsets and moving endpoints.
Drill particles, unit mining particles, fire animation, burning status, muzzle
flashes, flame effects, shell casings and supported weapon impacts use recorded
native events. Packaging samples the native Java particle geometry into reusable
browser animations. Events include birth/lifetime, position, color and active
parent motion, so seeking restores them without resimulation. Burning and drill
visual-only events use a separate deterministic seed, preserving gameplay RNG.
Building beams and interpolated native bullet sprites make player actions visible.
Conveyors record native blend variants, mirrored corners, animation speed,
clog state and each item's lateral/forward position. The browser interpolates
recorded ore positions across belt boundaries and uses the native item icons.
Recordings made before conveyor positions were added need to be regenerated to
show moving cargo. Earlier files still open and infer turns from nearby buildings.
The renderer still simplifies destruction effects and sprite lighting. At overview scale, tiny units and particles use colored markers;
zooming in restores their native sprites and geometry. Lighting and campaign UI
are outside this viewer. The existing desktop client remains available for human play.

Native digests cover serialized buildings and units, bullets, builder plans,
wave timing and the engine RNG. They are validation fingerprints, not saved
states that can restore a JVM. Determinism is checked by running fresh JVMs and
comparing every sample. Cross-architecture floating-point equivalence is not
promised. The evaluation patch settles pathfinding in explicit tick phases and stabilizes
building adjacency, construction sound randomness and overlapping-unit collision
randomness. Sleeping native buildings
remain in observations and replays until they are actually removed.

## Checks and Coworld packaging

```sh
export POLYWORLD_DEPS="$PWD/tmp/coworld/deps"
nim check examples/mindustry/mindustry.nim
nim check tests/test_mindustry.nim
nim r --nimcache:tmp/mindustry/testcache --out:tmp/mindustry/test tests/test_mindustry.nim
python3 coworld/mindustry/tools/check_adapter.py
python3 coworld/mindustry/tools/verify_runs.py
node tests/test_mindustry_replay.mjs tmp/mindustry/baseline.replay \
  tmp/mindustry/busy-factory.replay tmp/mindustry/heavy-combat.replay
node tests/test_mindustry_belts.mjs tmp/mindustry/defender.replay
node tests/test_mindustry_terrain.mjs tmp/mindustry/viewer/assets
python3 coworld/mindustry/tools/check_controls.py
python3 coworld/mindustry/tools/check_bot.py
node tests/test_mindustry_effects.mjs tmp/mindustry/heavy-combat.replay
coworld build --project coworld/mindustry --version 0.2.0
coworld certify coworld/mindustry/dist/coworld_manifest.json --no-open-report
```

The measurement script compares both identical BASIC seats and replays recorded
orders through another fresh JVM. Every restored building state, unit, shot,
visual event, fire, player plan, core value, outcome and hash must match. It writes real compressed sizes and
peak entity counts to `tmp/mindustry/measurements.json`. Set an upload limit only
after reviewing these results and longer representative factory policies.

The package follows GotA's game-hosted seat schema, private logs, annotations,
health endpoint, static replay viewer hook and atomic result finalization.
Survival requires two seats and shared PvP requires eight seats. No player
containers or gameplay WebSockets are used.

## License

Mindustry code and artwork are distributed under the upstream GPL-3.0 license.
The viewer bundle includes that license. The container carries the adapter and
host source, engine revision, patch and
a source archive. The matching full upstream engine source is also available
at `https://github.com/Anuken/Mindustry` at the pinned revision. Preserve those
notices and provide corresponding source when redistributing modified binaries.
The original desktop build and launch wrappers are in the sibling Mindustry
checkout. This package implements a renderer, not a WebAssembly port.

## Four versus four PvP

Run eight BASIC players in one shared native world:

```sh
tmp/mindustry/mindustry --pvp --ticks 36000 \
  --bot coworld/mindustry/players/base.bas:4 \
  --bot coworld/mindustry/players/base.bas:4 \
  --record tmp/mindustry/pvp.replay
```

Slots 0 through 3 are blue, and slots 4 through 7 are red. The mirrored
128 by 96 arena uses Mindustry's native Serpulo generator with the match seed
and sector 144. Native biomes, cliffs and ore veins surround cleared starting
areas and a ground route between the cores. Mirroring gives both teams the
same terrain, copper and lead deposits, core health and starting materials.
Each team starts with 800 copper,
600 lead, 400 silicon and 20 phase fabric. These materials support an early
powered factory. The enemy core has an eight-tile construction exclusion
radius. Waves are disabled. Native production, costs, construction, combat,
mining, unit possession and respawning remain active.

Each seat owns a native player and starts with its own Alpha flyer. Policies
observe the same decision boundary before any actions are applied. The engine
applies all eight input batches, rotating their priority every decision, then
advances the world by six ticks. Teammates share their core inventory and can
cooperate on construction. A player cannot possess a teammate's controlled
unit. Unpossessed friendly units and turrets keep their native automation.

The BASIC queries `team()`, `member()`, `enemyCoreX()`, `enemyCoreY()` and
`enemyCoreHealth()` identify the team, its member number from 0 through 3,
and the opposing core. Unit field 13 is the controlling seat, or -1 for an
unpossessed unit. Building inventories can be inspected with
`buildingItem(index, itemId)`. There is full map visibility for both teams.

The default `base.bas` policy detects the opposing core and assigns members
0 and 1 to engineering, defense and supply. Member 0 advances a line of Duo
turrets and copper walls toward the opposing core, delivering copper ammo
by hand. It advances eight tiles after its latest turret is built, supplied
and has held for three seconds. Member 1 builds ground and air factories,
a solar grid, and delivers lead and silicon. The factories produce Dagger
mechs and Flare fighters with rally points at the enemy core. Members 2 and
3 possess Daggers and Flares respectively, while member 3 also gives attack
orders to unclaimed combat units. Controlled Flares keep flying around their
targets to meet their native weapon's movement requirement. Alpha's native
weapons cannot damage buildings, so combat units or turrets must destroy the
opposing core. A destroyed core ends the match. All four winning players
score 100, losers score 0, and a timeout with both cores intact scores 50 for
everyone. Simultaneous core destruction is also a draw.

The `team-pvp` Coworld variant has eight seats. The survival variant retains
two independent seats. Eight staged policy files select shared PvP in the
hosted runner. For a league with eight distinct entrants, use the platform
`team_n` scheduler with `team_count: 2`, `team_layout: "blocks"`,
`distinct_teammates: true` and `insufficient_players: "do_not_run"`.
Omitting distinct teammates instead lets each of two entrants field four
copies of its policy. The game's team mapping stays the same in both cases.

PvP replays store the world once and include each player's personal state,
inputs and command results. Click a controlled unit to follow its player
while preserving the current playback time. Player names appear above their
controlled units. Space toggles play and pause. Playback starts following the
selected player's unit with looping enabled. Every builder's construction
beam and all recorded shots, mining and fire effects remain visible.

Validate native team ownership, factory production, core destruction and
repeatability with `python3 coworld/mindustry/tools/check_pvp.py`. The check
compares every shared hash across two fresh Java processes. Inspect a recorded
match with `node tests/test_mindustry_replay.mjs tmp/mindustry/pvp.replay`.
Run `python3 coworld/mindustry/tools/check_pvp_bot.py` to verify that both teams
connect drills to their core, build supplied weapon factories, possess combat
units and fire, with identical visual states across repeated matches.
Run `python3 coworld/mindustry/tools/check_hosted_pvp.py` to check eight staged
policies, a winning weapon-building squad, isolated policy failures and private
logs through the hosted runner.
Set `MINDUSTRY_CONTAINER_IMAGE=coworld-mindustry:pvp` to run that check against
a locally built container. The certification fixture runs four default bots
against four idle opponents for up to 6,000 ticks in the shared world.
