# Bassy port checklist for zhar/cand_v55.bas

Target engine: coworld-v0.3.124 (`/Users/me/p/paintbot-pw-0124`). Source: `zhar/cand_v55.bas`
(891 lines, written for the polyworld int32 BASIC of 0.3.110). Sources checked: `docs/bassy-porting.md`,
`coworld/paintbot/guide.md` ("File policies", "Rules 49"), `examples/paintbot/{bots,observations,seat_view,
basic_states,mechanics}.nim`, the base.bas diff `coworld-v0.3.110..coworld-v0.3.124`,
`tests/test_paintbot_bassy*.nim`, `tests/test_basic.nim`, and in `/Users/me/p/bassy`: `README.md`,
`docs/language.md`, `tests/test_{booleans,fixed,records}.nim`, `src/bassy.nim`.

## 0. What changed in the runtime (the facts the rest depends on)

| Topic | Old runtime (polyworld/basic.nim, 0.3.110) | Bassy (0.3.124) |
| --- | --- | --- |
| `/` | int32 `div`, truncates toward zero | Q16.16 fixed-point division, `3 / 2 = 1.5`. Both operands must fit -32768..32767 or BasicError "range" |
| `\` | not available | int32 division toward zero over the full int32 range (exactly the old `/`). Same precedence as `*`, `/`, `mod` (bassy.nim 1640-1650), so a textual swap keeps every left-to-right grouping |
| `mod` | int32 Nim `mod` (sign of dividend) | same, but both operands must be exact integers (`3.0` ok, `3.5` is BasicError "exact int32") |
| int + fixed | n/a | the int side must be within -32768..32767 or BasicError "range"; fixed results wrap silently at 32768 |
| comparisons | 1 / 0 | -1 / 0 (widened to int64, exact for any mix of int and fixed) |
| `TRUE` | n/a | -1 |
| `not x` | `x = 0` (1 or 0) | bitwise complement: `not 1 = -2` (true in a condition), `not 0 = -1` |
| `and` `or` | logical on nonzero, result 1 / 0 | bitwise on all 32 bits, both operands always evaluated (eager, host calls too) |
| `if x then` | nonzero is true | nonzero is true (same) |
| host args | int32 | must convert exactly to int32: any fixed value with a fraction in `walkTo`, `waterAt`, `terrainHeight`, `shootAt`, `lookAt`, array index, `mod`, `\` is BasicError "exact int32" |
| budget | 20,000 instructions | 50,000 instructions and 125,000 work units per decision (bots.nim `limits()`), scaled up for more than 16 seats |
| int32 overflow | wraps | wraps (`+ - * negate`), division by zero is BasicError in both |
| globals | persist between decisions | persist (`runtime.restart()` per decision keeps globals, arrays, records; string pool is reset each decision) |
| sub params | locals | locals passed by value; every other scalar is global |
| strings | `strNew` handle pool | same `strNew("literal")` handle API, pool reset every decision, 1,024 handles / 64 KiB |
| records | none | `TYPE ... END TYPE`, `DIM x(n) AS T`, `INTEGER` fields reject fractions (BasicError) |

The host predeclares two records before our source (observations.nim `recordSource`):
`me` with `id team x y hp carrying homeX homeY heartX heartY tick ownHeartX ownHeartY ownHeartStolen hasGrenade
hasSpray armorHp livesLeft grenadeCharge trenchId seats`, and `agents(me.seats - 1)` with
`visible x y hp team carrying`. Do not redeclare them. The legacy scalar names (`selfX`, `worldTick`, ...)
and legacy queries (`visible(i)`, `playerX(i)`, ...) are still registered (bots.nim 82-97, seat_view.nim
DataNames) and `tests/test_paintbot_bassy.nim` proves they still read correctly, so renaming is not what
breaks v55. What breaks v55 is section 2 (every `/`) and section 3 (five `not` lines). Rename anyway: a
legacy query costs 4 work units per call, a record column costs 4 per seat once per decision.

## 1. Identifier map (every host name v55 uses, with use counts)

| v55 identifier (uses) | Bassy form | Status in 0.3.124 |
| --- | --- | --- |
| `selfId` (6) | `me.id` | exists, same meaning |
| `selfTeam` (14) | `me.team` | exists |
| `selfX` (35), `selfY` (35) | `me.x`, `me.y` | exists |
| `selfHp` (3) | `me.hp` | exists, now 0..10 (rules 49), was 0..3 |
| `carrying` (5) | `me.carrying` | exists, 0 / 1 (never -1) |
| `homeX` (3), `homeY` (4) | `me.homeX`, `me.homeY` | exists |
| `heartX` (1), `heartY` (1) | `me.heartX`, `me.heartY` | exists |
| `worldTick` (38) | `me.tick` | exists |
| `ownHeartStolen` (1) | `me.ownHeartStolen` | exists, 0 / 1 |
| `hasGrenade` (2) | `me.hasGrenade` | exists, 0 / 1 |
| `hasSpray` (3) | `me.hasSpray` | exists, 0 / 1 |
| `armorHp` (1) | `me.armorHp` | exists |
| `grenadeCharge` (2) | `me.grenadeCharge` | exists |
| `trenchId` (2) | `me.trenchId` | exists, -1 outside |
| `visible(i)` (4) | `agents(i).visible` | exists, 0 / 1; index must be 0 .. me.seats - 1 (section 4) |
| `playerX(i)` (12), `playerY(i)` (12) | `agents(i).x`, `agents(i).y` | exists, -1 when hidden |
| `playerHp(i)` (1) | `agents(i).hp` | exists, 0 when hidden, 0..10 now |
| `playerCarrying(i)` (1) | `agents(i).carrying` | exists, 0 / 1 |
| `teamLives(t)` (3) | unchanged | bots.nim 114, cost 4; under rules 49 one life per cog so it is the count of living cogs |
| `heartCount()` (4) | unchanged | bots.nim 112 |
| `controlX(j)` (10), `controlY(j)` (10), `controlOwner(j)` (3), `controlCaptureTeam(j)` (1) | unchanged | bots.nim 124-127, -1 for j outside 0 .. heartCount() - 1 |
| `pickupCount()` (2), `pickupVisible(i)` (2), `pickupX(i)` (1), `pickupY(i)` (1), `pickupKind(i)` (1) | unchanged | bots.nim 107-111; kinds 0 grenade 1 spray 2 medkit 3 armor 5 mister 6 sniper 7 radar; hidden reads -1 |
| `soundCount()` (3), `soundKind(j)` (2), `soundDirection(j)` (1), `soundDistance(j)` (1), `soundAge(j)` (1) | unchanged | bots.nim 76-80 |
| `terrainHeight(x, y)` (2) | unchanged, args must be exact integers | bots.nim 154, cost 4, clamps to the map |
| `waterAt(x, y)` (8) | unchanged, args must be exact integers | bots.nim 161, cost 8, 0 / 1 |
| `mapMinX()` `mapMinY()` `mapMaxX()` `mapMaxY()` (1 each) | unchanged | bots.nim 150-153 |
| `walkTo(x, y)` (3), `lookAt(x, y)` (4), `shootAt(x, y)` (1) | unchanged, exact integer args | bots.nim 168-172 |
| `chargeGrenade(held)` (1) | unchanged, host tests `a[0] != 0` so passing a comparison (-1) is fine | bots.nim 105 |
| `sneak(flag)` (1) | unchanged, `a[0] != 0` | bots.nim 72 |
| `shout(handle)` (4) | unchanged, at most 4 per decision, cost 68 work | bots.nim 63 |
| `strNew("text")` (4) | unchanged (handle string functions are registered) | bots.nim 59 |

Not used by v55 but new and relevant: `gunRange()`, `hasSniper()`, `mistingTicks()`, `playerMisting(i)`,
`radarTicks()`, `radarBoost()`, `playerRadar(i)`, `selfDestruct()`, `rnd(n)` (n >= 1 or the seat is
disabled), `me.seats`, `me.livesLeft`. None of v55's own identifiers collides with a Bassy keyword
(`clear`, `seat`, `pass`, `look`, `kind`, `score`, `step` is only used inside `stepX`/`stepY`), a string
builtin, or a host function (checked against bots.nim, oracle.nim, neural_host.nim, annotations.nim).
`i mod 2` for the team stays valid: `selfTeam` is `team(slot)` and base.bas still uses `i mod 2 = me.team`.

## 2. Every `/` must become `\` (38 sites, no exception)

`\` is exactly the old operator (toward zero, same precedence, full int32 range), so every site is a pure
textual swap. Only operators in code, never the `/` in comments (lines 89, 90, 535, 633-636). What
happens if a site is missed: F = the seat is disabled by a BasicError on the first decision that reaches
the line, S = silent wrong arithmetic (fixed-point values flow into comparisons).

| Line | Expression | If left as `/` |
| --- | --- | --- |
| 33, 37 | `guess = (root + n / root) / 2` in `isqrt` | F: `n` is a squared distance up to 57,000,000, `/` needs both operands under 32768 ("range"). Kills every caller: lines 57, 81, 120, 126, 379, 732, 863 |
| 47 | `waterAt(ax + (bx - ax) * s3 / 10, ...)` | F: operand up to 75,000 ("range"), and a fractional coordinate into `waterAt` ("exact int32") |
| 58 | `legCost = root / 100 + root / 100 * wet * (kWetCost - 1) / 10` | S: legCost fractional, only compared (detour choice drifts) |
| 86, 87 | `legX = (0 - ty) * 100 * zig / root` | F: operand up to 750,000 ("range") |
| 93 | `look = legTicks * 28 / 100` | F: `look` fractional, then line 95-96 `terrainHeight(selfX + legX * look, ...)` ("exact int32") |
| 104, 107 | `waterAt(selfX + legX * look / 2, ...)` | F: fractional coordinate into `waterAt` |
| 122, 123 | `legX = legX * 3 / 4 + fx * 100 / root` | F: `fx * 100` up to 750,000 ("range") |
| 128, 129 | `legX = legX * 28 / root` | F: legX fractional, then line 607 `moveX = selfX + legX * 4` into `walkTo` (line 701) |
| 271, 272 | `lastFoeX = foeSumX / foesSeen` | F: foeSumX up to 96,000 ("range"); otherwise fractional `lookAt` at line 515 |
| 304 | `member = (selfId / 2) mod 8` | F for every odd seat (the whole blue side): `3.5 mod 8` is "exact int32". Even seats pass (`2.0`) |
| 305 | `squad = member / 4` | S: squad becomes 0.25, 0.5 ..., `pass = squad` is never true for 6 of 8 members, objective stays -1 |
| 323, 324 | `dx = (controlX(j) - homeX) / 8` | S: `dx * dx` up to 640,000 wraps in Q16.16 (garbage heart cost) |
| 381, 382 | `goalX = hx + (ax * 3 - ay * 2 * side) * 90 / root` | F: operand up to 1,350,000 ("range") |
| 419 | `cost = cost / 4` | F: cost up to 4,840,000 ("range"), fires whenever `selfHp = 1` and a medkit is remembered |
| 442, 443 | `cx = foeSumX / foesSeen` | F: as 271 |
| 450, 451, 452, 453 | `ex = (controlX(j) - cx) / 16` ... | S: squares wrap |
| 454 | `score = ... - (mx * mx + my * my) / 2` | S: garbage retreat score |
| 665, 666 | `drMx = selfX + drDx / 2` | F: drMx fractional, feeds 669-672 |
| 669, 670 | `drCx = drMx - drDy * drF(drK) / 10` | F: operand up to 75,000 ("range"), else fractional into `waterAt(drCx, drCy)` (672) and `walkTo(drWx, drWy)` (699) |
| 716, 717 | `stepX = (tx - oldX(best)) / sightGap` | F: fractional lead, then `shootAt(tx, ty)` (757) or `lookAt(tx, ty)` (768) |
| 740, 741 | `along = (ox * sx + oy * sy) / reach` | F: operand up to 112,000,000 ("range") |
| 864 | `need = (root - 150) * 24 / 1130 + 1` | S: need fractional, `grenadeCharge < need` still compares exactly, charge runs one notch long |

`mod` sites (63, 71, 78, 145, 171, 185, 215, 304, 306, 518, 737, 783, 806, 816, 853) are all on integers
once 304 and 305 use `\`. No array index in v55 is computed with `/`. No `/` appears inside a string.

Division by zero is a BasicError in both runtimes and every divisor in v55 is guarded (`root > 0`,
`reach > 0`, `sightGap >= 1`, `foesSeen > 0` or implied by `foesNear >= 2`, `maxTicks - minTicks + 1 >= 1`).
Keep those guards.

## 3. Boolean hazards

### 3a. `not` on a 0/1 host flag (five sites, each one is a real behaviour bug under Bassy)

Every host flag is 0 or 1, never -1, so `not flag` is -1 or -2 and both are true.

| Line | Now | Effect if left | Rewrite |
| --- | --- | --- | --- |
| 405 | `if not carrying and thief < 0 then` | goes for supplies while carrying the heart | `if me.carrying = 0 and thief < 0 then` |
| 412 | `wanted = (kind = 0 and not hasGrenade) or (kind = 2 and selfHp < 3)` | wants a grenade while holding one | `wanted = (kind = 0 and me.hasGrenade = 0) or (kind = 2 and me.hp < hpCap)` (hpCap: see section 7) |
| 421 | `if cost < 10000 and not pickupVisible(j) then` | forgets a visible supply within 1 m, never equips | `if cost < 10000 and pickupVisible(j) = 0 then` |
| 441 | `if foesNear - friendsNear >= 1 and not carrying then` | retreat logic overrides the carry home | `if foesNear - friendsNear >= 1 and me.carrying = 0 then` |
| 536 | `if best >= 0 and not carrying then` | hold-in-contact plants the heart carrier in place | `if best >= 0 and me.carrying = 0 then` |

### 3b. `and` / `or` chains mixing comparisons (-1/0) with numeric flags (verified safe, keep as is)

`-1 and 1 = 1`, `-1 or 1 = -1`, `0 or 1 = 1`: a chain is correct as long as every numeric flag is 0, 1 or -1.
Checked flags and their value sets: `holding` 0/1, `drActive` 0/1, `drWalk` 0/1, `readyAim` 0/1, `neuralFoe` 1,
`longLeg` 0/1, `clear` 0/1, `safe` 0/1, `lineBlocked` 0/1, `shielded` -1/0/1 (line 224 comparison, line 237
assignment), `fresh` 1/-1/0, `bestShielded` -1/0/1, `wantShot` 0/1/-1, `inContact` -1/0, `recentFoe` -1/0,
`capturing` -1/0, `longRunFoe` -1/0, `wanted` -1/0 after the 3a fix. Safe chains: lines 211, 281, 405 and
536 (after the 3a fix), 562, 573, 580, 623, 737, 756, 761, 844, 853, 862. If any flag ever gets a value
like 2 (for example a counter), `2 and 1 = 0` breaks the chain, so never reuse these names as counters.
Optional hardening for the port: write `readyAim = 1` and `clear = 1` where they appear inside `and`
chains (573, 756), and `neuralFoe = 1` at 580, 583, 591, 623.

### 3c. Comparisons stored and reused (verified)

`shielded = worldTick < 30` (224), `fresh = ... < 30` (228), `capturing = ... = selfTeam` (359), `recentFoe`
(475), `inContact` (555), `wantShot` (573), `longRunFoe` (841) now hold -1 instead of 1. Every use is an
`if x then`, `if x = 0`, or an `and` chain (3b), so nothing changes. `bestShielded = shielded` (254) stores
-1 or 1 and is only compared with `= 0` (573, 756, 844). No comparison is added, multiplied or used as an
array index anywhere in v55 (the counters `wet`, `foesNear`, `friendsNear`, `foesSeen`, `fpMoves`,
`fpExact`, `foeRuns`, `stalled`, `idleCapture` all increment inside `if` blocks).

### 3d. `if x then` on numeric values (verified)

Lines 230, 244, 247, 280, 360, 397, 413, 476, 556, 581, 583, 591, 593, 609, 644, 694, 698, 764, 777: all
test nonzero, same in both runtimes. `chargeGrenade(grenadeCharge < need)` (869) passes -1, the host treats
any nonzero as held (bots.nim 105), and base.bas does the same.

## 4. Arrays, dim bounds and loop bounds

- `while i < 16` at lines 210, 736, 776, 852 index `visible(i)` / `playerX(i)`. With `agents(i)` the index
  must be 0 .. me.seats - 1: the host declares `DIM agents(Seats - 1)` with the match's seat count, so
  `agents(16)` in a smaller match is an array bound BasicError (seat disabled), where `visible(16)` used
  to read 0. Do what base.bas does: in the `started = 0` block set `rosterLimit = 16`, `if me.seats <
  rosterLimit then rosterLimit = me.seats`, and loop `while i < rosterLimit`. League games are 16 seats,
  local `--bot x:N` games may not be.
- `dim oldX(16)`, `oldY(16)`, `lastSeen(16)`, `sightStart(16)`, `moveRun(16)`, `dirRun(16)`, `dirX(16)`,
  `dirY(16)`, `waitStart(16)`: inclusive bound, 17 cells, indexed by `i < 16` and by `best` (a roster
  index). Fine. If these move into a record array as the guide suggests, `DIM motion(255) AS ...` covers
  every supported roster, but the loops must still stop at `rosterLimit`.
- `dim avoidUntil(64)` indexed by `objective` 0..63 (guarded at 188), `dim pickupMemory*(64)` with loops
  `< 64`, `dim drF(6)` indexed 0..5, `dim dropTick(8)` indexed `mod 8`: fine.
- `while j < heartCount() and j < 64` (232, 321, 447), `while i < pickupCount() and i < 64` (396, 409),
  `while j < soundCount() and j < 12` (484): the host functions return -1/0 for an index past the real
  count, so the caps only bound the budget. Each loop test calls the query again (4 work units).
- Eager `and`: `if i <> selfId and visible(i)` (211) evaluates `visible(selfId)` too, harmless. Never write
  `if i < me.seats and agents(i).visible`: the right side is evaluated for i >= me.seats and raises.
  Nest the `if` instead.
- Memory budget: v55 has 494 array cells plus 96 host record cells, limit 4,096; about 150 globals, limit
  512; sub depth 2 (`legTime` -> `wetLine`), limit 16.

## 5. What the stock base.bas now does purely for the runtime (from the 110..124 diff)

- Comment header: budget 20,000 -> 50,000 instructions (base.bas line 8; v55 line 7 says 20,000).
- Parallel memory arrays replaced by records: `TYPE SupplyMemory x y kind tick` with `DIM supplies(32)`
  in place of `pickupMemoryX/Y/Kind/Tick`, and `TYPE MotionMemory x y seen` with `DIM motion(16)` in place
  of `oldX/oldY/lastSeen`. Field reads `supplies(j).tick`, writes `motion(i).seen = me.tick`. Note INTEGER
  fields reject a fractional value with a BasicError, so never store a `/` result in one.
- `isqrt`: `guess = (root + n \ root) \ 2` (two sites). `wetLine`: `\ 10`. `legTime`: three `\`. `planLeg`:
  six `\`. Squad maths `member = (me.id \ 2) mod 8`, `squad = member \ 4`. Heart cost `\ 8`, cover position
  `\ root`, medkit `cost \ 4`, retreat `\ foesSeen` and `\ 16` and `\ 2`, sweep `me.tick \ 24`, dry route
  `\ 2` and `\ 10`, teammate line `\ reach`, grenade `\ 1130`.
- `rosterLimit = min(16, me.seats)` set once in the `started = 0` block, used by all four roster loops.
- Every `selfX`, `worldTick`, `visible(i)`, `playerX(i)` and friends renamed to `me.*` and `agents(i).*`.
- `not carrying` -> `(me.carrying = 0)` (two sites), `not hasGrenade` -> `(me.hasGrenade = 0)`,
  `not pickupVisible(j)` -> `(pickupVisible(j) = 0)`. These are the same five patterns as section 3a.
- Unchanged: `clear = 1` and `if clear and gunWait = 0` (numeric flag in a chain), `chargeGrenade(me.grenadeCharge
  < need)`, `shout(strNew(...))`, `sneak(1)`, `exit sub`, globals as persistent memory, `heardCount()`.
- Not runtime, rules 49 (section 7): `hpCap` tracking, `d2 <= gunRange() * gunRange()`, a mister/radar
  carrier follows its nearest teammate, `wanted` for kinds 5, 6, 7, medkit thresholds on `hpCap`, and a
  self-destruct block at the end.

## 6. What silently disables the cog, and how to see it locally

What happens (bots.nim `runSeat`, 265-288): any `BasicError` during a decision sets `b.failed = true`,
`b.error = msg`, replaces the tick's command with `Command()` (stand still, no shot) and the seat never
decides again for the rest of the match. Hosted: `playerError(slot, msg)` into the seat log. Local
headless build: one line `seat N disabled: <msg>` on stdout. `-d:pwTraining` builds (our pw_* tools)
print nothing, check `bot.failed` / `bot.error` yourself as `tests/test_paintbot_bassy.nim` does.
A compile error is terminal before the first tick: hosted it is written as "BASIC compilation failed for
player slot N" (coworld.nim `compilePlayer`) and the seat forfeits, locally `loadBots` raises and the
headless binary exits with the message and token position.

Messages to expect and their cause:

| Message | Cause in a v55 port |
| --- | --- |
| `BASIC instruction limit exceeded` | more than 50,000 instructions in one decision |
| `BASIC work limit exceeded` | more than 125,000 work units: instructions plus host costs (4 per query, 8 `waterAt`, 68 `shout`, 4 per seat per loaded `agents` column) |
| `... exact int32` | a fixed value into `walkTo` `lookAt` `shootAt` `waterAt` `terrainHeight`, an array index, `mod` or `\` (any missed `/` from section 2) |
| `... range` or `fixed-point range` | `/` with an operand beyond 32767, or int beyond 32767 mixed with a fixed value |
| `division by zero` | unguarded divisor |
| array bound (`outside`) | `agents(i)` with i >= me.seats, or a `dim` index past its inclusive bound |
| `call depth` | sub recursion past 16 |
| `rnd needs n >= 1` | `rnd(0)` |

Budget check: v55 ran inside the old 20,000 instruction budget, so 50,000 is ample. Work units are new:
the worst decision in v55 is about 2,500 units of roster and heart queries (the nested heart loop at 232
is 15 foes x 9 hearts x 3 queries x 4), plus about 1,100 for the dry route (13 `wetLine` calls x 10
`waterAt` x 8), plus one unit per instruction, well under 125,000.

How to see it, in `/Users/me/p/paintbot-pw-0124` (README lines 18-19):

```
nim c -d:headless -o:tmp/paintbot examples/paintbot/paintbot.nim
PW_BASIC_PEAKS=1 ./tmp/paintbot --bot /Users/me/p/andre_von_auto/games/paintbot-pw/zhar/cand_v58.bas:16 \
  --ticks 7200 --seed 1 --record tmp/smoke.replay
```

Read stdout for `seat N disabled:` lines (none means every seat ran all 7200 ticks), then
`peak_instructions=` and `peak_work=` (one value per seat, game.nim 726-731) against 50,000 and 125,000.
`ticks=7200 captures=...` confirms the match ran. Two bot groups (`--bot ours:8 --bot base.bas:8`) fill
seats 0-7 then 8-15, so both groups are on both teams, fine for a smoke test. This is the one headless game
allowed: compile, move, shoot, no scoring.

Compile-only check without a game: a 10-line Nim program built with `-d:pwTraining --path:examples/paintbot
--path:src` that calls `loadScriptBot(readFile(path), 0)` (bots.nim 237, same host, limits and
`recordSource()` prefix as a hosted seat) and prints the `BasicError` message, or runs 240 decisions as
`tests/test_paintbot_bassy.nim` does and asserts `not bot.failed`.

## 7. Rules 49 constants v55 carries that must come from the host (not runtime, listed for the same pass)

- 251 `d2 <= 27562500` (5250 squared): now `gunRange() * gunRange()` (2133, or 4800 with a sniper).
- 216 `cost = d2 - (3 - playerHp(i)) * 160000`: HP is 0..10; the ordering is still linear in hp, the
  offset shifts by up to 1,120,000. Decide knowingly.
- 412, 417, 433 `selfHp < 3`, `selfHp = 1`: use `hpCap` as base.bas does (`if me.hp > hpCap then hpCap =
  me.hp`, medkit wanted at `me.hp < hpCap`, critical at `me.hp * 3 <= hpCap`).
- 150-182 and 222-246 (respawn windows, `dropTick`, `shieldEnd`, `teamLives` deltas): one life per cog,
  there are no respawns, so `shieldEnd` stays 30 and the block is dead weight (about 100 instructions).
  `teamLives(t)` is now the number of living cogs on team t.
- 154-160 (teleport check "a respawn teleports us"): dead, harmless.
- 573, 752-766: `gunWait = 25` is the gun cycle. With `hasSniper()` the cooldown is 96 ticks (4 s), and a
  misting or radar cog cannot attack at all, so `wantShot` should also require `mistingTicks() = 0 and
  radarTicks() = 0` or the cog plants for a shot that never leaves.
- 411-412 `wanted`: kinds 5, 6, 7 fall through as not wanted (safe). Any pickup ends a radar.
- Everything else (aim lead, dodge legs, dry route, squads) is rules neutral.
