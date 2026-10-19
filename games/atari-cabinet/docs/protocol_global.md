# THE CABINET — wire protocol

## The player socket

`ws://<game>:8080/player?slot=<N>&token=<T>` — a bad slot or token is a **403
before the upgrade**.

A seat sends exactly **one kind of message it authors**: its registration, as a
Sprite v1 chat frame (`0x81`), re-sent on the first ~10 s of frames because
joins are slot-sequential and the lobby streams frames to a socket before it is
admitted (the server holds an unappliable registration rather than dropping
it):

```json
{"type":"register","prompt":"<strategy text or empty>",
 "scripted":"bulwark"|"spinner"|null,"policy":"<free label>"}
```

`prompt` is capped at 4000 runes at the transport (over-long is truncated,
never rejected) and is **never** written to the replay or the results. A seat
that never registers, or registers with neither field, is `bulwark`.

After that the seat only **receives**: one binary Sprite v1 frame per tick, and
it answers each with the Ready packet (`0x85`). **SEATS SEND NO INPUTS.** The
server computes every command byte, so any input mask arriving on a player
socket is discarded — which is also why the Ready packet is legitimate here in
a way it is not for an ordinary client: there is no dead-reckoned input to
corrupt.

The per-seat frame carries the **whole board**: the arena, all four mouths
(open or welded), every paddle, every brick and every ball with its trail.
The cabinet is a CRT and the physics is public. Board labels carry only the
colour aliases (`showPlayerLabels` is forced false on the player stream), so no
real policy name is ever on a seat's screen.

## The board view a policy is asked about

Every 5 s of sim time (120 ticks) the server composes this object, appends it
to the seat's `PLAYER_PROMPT` under a "GUIDANCE FROM YOUR OPERATOR" heading,
and asks Claude for a stance. All numbers are in **cabinet coordinates**
(0..100 from the bottom-left corner, x right, y up), rounded to 2 decimals,
with `along`/`depth` in the seat's own side-local frame.

```json
{"turn": 11, "of": 24,
 "clock": {"tick": 1320, "of": 2880, "left_s": 65.0},
 "rom": "warlords",
 "you": {"alias": "GREEN", "side": "NORTH", "lives": 2, "out": false,
         "paddle": {"along": -6.40, "vel": 0.80, "half": 7.00, "depth": 14.00,
                    "travel_half": 43.00},
         "far_paddle": null, "holding": null,
         "mouth": {"half": 18.00, "open": true},
         "bricks": {"left": 5, "of": 9, "cols": [false, true, "…9…"]},
         "score": 41.750},
 "balls": [{"id": "B1", "state": "live", "pos": [62.10, 71.44],
            "vel": [0.61, -0.42], "speed": 0.74, "deg": 325.4,
            "last_touch": "BLUE", "held_by": null,
            "arrive_at": "GREEN", "arrive_in_ticks": 31,
            "arrive_along": 3.20}, "… ballCount entries …"],
 "rivals": ["… exactly three, alias / side / lives / out / bricks_left / paddle_along / score …"],
 "neighbours": {"plus_along": "YELLOW", "minus_along": "BLUE"},
 "rules": {"starting_lives": 3, "ball_count": 2, "brick_rows": 1,
           "catch_enabled": true, "far_paddle": false,
           "points": {"per_life_kept": 20.0, "crown": 15.0, "knockout": 2.0,
                      "chip": 0.5, "save": 0.25}},
 "your_last_stance": {"…": "the stance this seat set last turn, or null"}}
```

`arrive_along` is `null` when that ball will not reach **this** seat's line
inside the prediction bound; `arrive_at` names whichever cabinet's line it
reaches first. The `arrive_*` triple is computed by **the same walk the
autopilot uses**, so a policy never has to guess at a quantity the engine
already knows.

**Hidden from every seat, with no exception:** which entrant holds any other
seat; any other seat's stance, note, say, prompt, latency, policy label or
fallback state; `perm`; `config.seed`; the RNG state; every future serve
direction; every real player name; and any host or wall-clock fact.

## The stance reply

```json
{"note": "BLUE is on 1 life and its wall is down to 2; take the free shot",
 "stance": "aim", "target_ball": "B1", "aim_at": "BLUE",
 "post": 0.0, "lead_ticks": 12, "aggression": 0.8, "say": "BLUE first"}
```

| field | cap / legal values | repair when violated |
|---|---|---|
| `note` | ≤ 160 runes | truncated to 160 runes |
| `stance` | `guard, aim, camp, catch, chase` | unrecognised → last turn's, else `guard`; `catch` without `catchEnabled` → `guard` |
| `target_ball` | ≤ 4 runes, `B1`…`B<ballCount>` or `any` | an id outside the set, or a ball not currently live → `any` |
| `aim_at` | ≤ 8 runes, a colour alias or `none`; never my own, never an out cabinet | unrecognised / missing / self / out → `none` (the autopilot then behaves as `guard`) |
| `post` | finite, clamped ±43.0, quantised to µu | non-finite / missing → last turn's, else `0.0`; a value beyond ±43 is read as a percent and rescaled |
| `lead_ticks` | integer, clamped 0..48 | non-finite / missing → `12` |
| `aggression` | finite, clamped 0..1, quantised to 0..255 | a value above 1 is divided by 100; missing → `0.8` |
| `say` | ≤ 48 runes | truncated to 48 runes, then the printable-ASCII shout sanitiser (which strips a leading `{`) |

Parsing is deliberately tolerant: markdown fences are stripped, the outermost
balanced `{…}` is taken (so prose before or after the object is fine), numeric
strings are accepted, `stance`/`target_ball`/`aim_at` are matched
case-insensitively and inside prose (`"the red cabinet"`, `"ball 2"`), and the
documented synonyms (`defend`→`guard`, `shoot`/`attack`→`aim`,
`hold`/`sit`→`camp`, `grab`→`catch`, `rush`→`chase`) are accepted. Only when no
object with at least one usable field can be recovered does the single retry
fire, and then the `bulwark` fallback.

**Every recorded string is truncated on RUNE boundaries**, never bytes: a
byte-truncated multi-byte character renders in a browser and then fails a
strict UTF-8 parser.

## The results document

`COGAME_RESULTS_URI` receives exactly these 22 keys — the manifest's
`results_schema` is `additionalProperties: false`, so adding or removing one
here means editing `coworld_manifest_template.json` in the same commit. Every
per-seat array is in **seat order** and has exactly 4 entries; `names` are the
real policy names, `aliases` are the in-game ones, `cabinets` is `perm`.

```json
{"names": [], "aliases": [], "cabinets": [], "policyKinds": [], "scores": [],
 "win": [], "placements": [], "rom": "warlords", "startingLives": 3,
 "livesLeft": [], "concedes": [], "knockouts": [], "chips": [], "saves": [],
 "catches": [], "bricksLeft": [], "llmTurns": [], "fallbackTurns": [],
 "finalTick": 2604, "reason": "complete", "endRule": "last_standing",
 "seed": 5140913}
```

## The `/global` spectator snapshot and the replay

`ws://<game>:8080/global` streams the same binary sprite protocol plus the
broadcast chrome JSON, which rides as the **label of a reserved never-drawn
1×1 sprite** (id 4090) — the only channel that survives a hosted replay. The
state frame keeps the starter's key names (`t, mt, ph, lob, pl, sp, mx, st, lp,
sk, ff, en, mm, bs, pov, teams, roster, events, lead, beats, lulls, over,
hold`) so the byte-identical `chrome_common.js` runs unmodified; everything
cabinet-specific lives under `cab` and `stances`.

The replay is the starter's **binary `COWLDCAB`** format:

| content | carries |
|---|---|
| header | magic `COWLDCAB`, format version, `gameName` `atari-cabinet`, `gameVersion` |
| config JSON | `seed`, `rom`, the fully resolved ROM preset, `perm`, `num_agents`, `maxTicks`, `turnTicks`, the whole geometry table, the reward constants, `players[].name` (real names), `slots[].alias`, `fastMode` |
| joins / leaves | per seat: name, slot, token |
| inputs | **the action log**: one command byte per seat per tick, written on change only |
| chats | `register` / `stance` / `fallback` / `budget_guard` / `result` control records |
| hashes | one `gameHash` per tick |

`tools/replay_summary.py` (Python 3 stdlib only) turns those bytes into one
strict-UTF-8 JSON object for forensics, and `/replay-data` serves them back
from a replay-mode server.

## Runtime contract

`COGAME_CONFIG_URI`, `COGAME_RESULTS_URI`, `COGAME_SAVE_REPLAY_URI`,
`COGAME_LOAD_REPLAY_URI`, `COGAME_PLAYER_FAILURE_URI`, `COGAME_EVENTS_URI`,
`COGAME_METRICS_URI`, `COGAME_HOST`, `COGAME_PORT` — the starter's, unchanged.
`GET /healthz` and `GET /global` keep answering for a bounded ~20 s after the
artifacts are written, because the episode runner pings `/global` with a 2 s
deadline *after* the player pods start and a short episode can already be gone.


---

# THE CABINET — rules

Four cabinets, one square CRT, two balls, two minutes.

The arena is a **100 × 100** box. Each of the four sides belongs to one
cabinet. In the middle of your side is your **mouth** — a gap in the wall. In
front of it, 14 units into the arena, is your **paddle**: a bar that slides
left and right along your own side and nothing else. Between them, in the
`warlords` ROM, is your **castle**: nine bricks across the mouth.

The ball bounces off the solid parts of every wall, off every paddle, and off
every brick — chipping the brick away. When a ball crosses your mouth line
inside the gap you **lose a life** and the ball is re-served from the centre.
Lose your last life and your mouth is welded shut, your paddle and castle are
removed, and the other cabinets fight on in a smaller box. **The last cabinet
with lives standing wins.**

Every deflection speeds the ball up. Where the ball leaves your paddle depends
on **where on the bar it landed** and **which way the bar was moving** —
thirteen outgoing angles, 11.25° apart. That is the whole strategy: a paddle is
not only a shield, it is a **gun**, and every rally is a choice about **whom to
shoot at**.

## Seats and sides

`num_agents` is **4**, in every variant and in the certification fixture. One
seat = one cabinet = one side of the box.

| side `k` | wall | alias | chrome key |
|---|---|---|---|
| 0 | SOUTH (`Y = 0`) | **RED** | `red` |
| 1 | EAST (`X = 100`) | **BLUE** | `blue` |
| 2 | NORTH (`Y = 100`) | **GREEN** | `green` |
| 3 | WEST (`X = 0`) | **YELLOW** | `yellow` |

Seat `s` drives cabinet `perm[s]`, where `perm` is a permutation of `0..3`
drawn once at `t = 0` from `config.seed`. In-game a cabinet is called by its
**colour alias** and nothing else; real policy names are spectator-side only.
`perm` is written into the replay config JSON and into `results.cabinets`, and
is never visible to any seat. Your **+along** end touches the next cabinet
counter-clockwise: RED → BLUE → GREEN → YELLOW → RED.

## The ROM preset table (the rotation)

One engine, three presets, applied `defaults → the named preset → any
explicitly supplied key`.

| config key | `warlords` | `quadrapong` | `foozpong` | meaning |
|---|---|---|---|---|
| `startingLives` | **3** | **5** | **3** | lives per cabinet |
| `ballCount` | **2** | **2** | **2** | balls live at once |
| `brickRows` | **1** | **0** | **0** | rows of 9 bricks across each mouth |
| `catchEnabled` | **true** | false | false | a paddle may grip and hold a ball |
| `farPaddle` | false | false | **true** | a second paddle row at depth 34 |
| `goalHalfCu` | **18** | **22** | **18** | half-width of the mouth |
| `paddleHalfCu` | **7** | **6** | **6** | half-length of the near paddle |
| `farPaddleHalfCu` | — | — | **5** | half-length of the far paddle |
| `ballSpeed0Milli` | **550** | **650** | **600** | serve speed, thousandths of a cu/tick |

Everything else — arena size, depths, brick geometry, the speed ramp, the
timings, the decision cadence, the wall-clock budget and `num_agents` — is
identical across all three ROMs, which is what makes one score scale and one
wall-clock budget correct for all of them.

## Geometry and constants (fixed in every ROM and every episode)

```
ArenaSide         = 1 000 000 µu  (100.00 cu, 1 cu = 10 000 µu)
BallHalf          =    12 000 µu  (  1.20 cu)  -- an axis-aligned square
PaddleDepth       =   140 000 µu  ( 14.00 cu)
PaddleThickHalf   =     8 000 µu  (  0.80 cu)
FarPaddleDepth    =   340 000 µu  ( 34.00 cu)  -- foozpong only
PaddleTravelHalf  =   430 000 µu  ( 43.00 cu)
PaddleStepSpeed   =     4 000 µu/tick (0.40 cu/tick)  -- one drive level
PaddleMaxSpeed    =    16 000 µu/tick (1.60 cu/tick)  -- level 4
BrickRowDepthLo   =    80 000 µu  (  8.00 cu)
BrickRowDepthHi   =   105 000 µu  ( 10.50 cu)
BricksPerRow      = 9             -- centres at along -16, -12, … +16 cu
BrickHalfWidth    =    18 000 µu  (  1.80 cu)  -- 3.60 cu wide, 0.40 cu gaps
BallSpeedStep     =       350 µu/tick per deflection
BallSpeedMax      =    13 000 µu/tick (1.30 cu/tick = 31.2 cu/s)
ServeDelayTicks   = 24            -- 1.0 s of dead air after a concede
HoldTicksMax      = 48            -- 2.0 s, the longest a catch may hold
OutfanAngles      = 13            -- 22.5° … 157.5°, 11.25° apart
maxTicks          = 2880  (120.0 s)   -- 24 decision turns
turnTicks         =  120  (  5.0 s)   -- the decision cadence
```

`PaddleMaxSpeed` exceeds `BallSpeedMax`, so a paddle can always out-run the
ball along its own side: **a miss is a decision, never a physics limitation.**

## Resolution order (every tick, no exceptions)

1. **Turn boundary.** At `t mod 120 == 0` the stances collected for this turn
   become each seat's standing stance and one `stance` record per seat is
   written into the replay.
2. **Autopilot compile**, in cabinet index order, into a **command byte**
   `cmd ∈ 0 … 242`: `near = cmd mod 9`, `far = (cmd div 9) mod 9`,
   `grip = cmd div 81`, paddle velocity `= (level − 4) × PaddleStepSpeed`.
   `cmd >= 243` is repaired to `40` in both the server and the replay runtime.
3. **Paddle motion**, cabinet order, near then far; a paddle that hits its
   travel limit simply stops.
4. **Ball motion and contacts**, ball order, at most **one contact per ball
   per tick**, earliest first, ties broken **paddles → bricks → mouth lines →
   solid walls**.
5. **Score**, folded into a running total.
6. **Hash** — one `gameHash` per tick, the integrity chain the browser checks.
7. **End checks**: last standing → `complete/last_standing`; the wall-clock
   stop → `deadline/wall_clock`; `maxTicks` → `complete/full_time`; an
   invariant guard → `fault/sim_fault`.

**The deflection fan.** In side `k`'s local frame,
`j = clamp(round(offset × 6 / paddleHalf) + spin, −6, +6)` and
`dl' = 16 − 2j`, so `dl'` is always in `4 … 28`: **a paddle can never deflect a
ball into its own mouth.** `spin` is `±2` above 1.20 cu/tick of bar speed,
`±1` above 0.40, else 0. A gripped ball is **aimed by the drive level in the
byte that releases it** (`j = near − 4`), so the release rides the same
recorded byte as everything else.

## Scoring

Every term is non-negative, so the minimum score is `0.000` and higher is
always better. Conceding is punished by *not earning* the lives term.

```
score[k] = 20.00 × livesLeft[k] / startingLives × 3   (60.000 max, ROM-independent)
         + 15.000 if placement == 1                   (the crown)
         +  2.000 × knockouts[k]                      (rival lives you took)
         +  0.500 × chips[k]                          (rival bricks your ball broke)
         +  0.250 × saves[k]                          (balls your paddles deflected)
```

The lives term is normalised by `startingLives`, so `quadrapong`'s five lives
and `warlords`' three are worth the same at the top of the scale and a league
board that mixes ROMs is still meaningful.

**Placement**, computed once at game over: a cabinet with lives outranks every
cabinet with none; among the living, more lives, then more bricks, then more
saves, then the lower cabinet index; among the eliminated, later `outTick`,
then more knockouts, then the lower cabinet index. The index tiebreak makes the
chain total, so `placements` is always a strict permutation of `1..4` and
exactly one seat takes the crown.

**What the league ranks by: the seat's mean `results.scores` value across its
episodes.**

## End conditions

| `reason` | `endRule` | when |
|---|---|---|
| `complete` | `last_standing` | exactly one cabinet still has lives |
| `complete` | `full_time` | 2880 ticks reached with two or more alive |
| `deadline` | `wall_clock` | the 660 s engine stop elapsed first — the board is scored as it stands |
| `fault` | `sim_fault` | an invariant guard tripped; a partial replay is written |
| `fault` | `host_error` | an unexpected server-side exception |

A seat that never connects does **not** end the episode: the lobby budget
expires, the no-show is reported to `COGAME_PLAYER_FAILURE_URI`, and its
cabinet plays the `bulwark` baseline for the whole run.

## Out of scope

No Atari emulator, no ROM image, no ALE binding and no PettingZoo dependency:
the environment names in the source idea are provenance, not a specification,
and every constant here is the cabinet's own. No pixel or RAM observations, no
team or cooperative motive, no ball–ball collision, no powerups, no inter-seat
communication of any kind, and no fog of war — the cabinet is a CRT and the
physics is public. What is hidden is *who is playing*.
