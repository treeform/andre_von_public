# Rules 49 mechanics brief for the zhar port

Engine coworld-v0.3.124 (LiveRules 49, sim.nim:247), checkout /Users/me/p/paintbot-pw-0124.
Sources: examples/paintbot/mechanics.nim, examples/paintbot/sim.nim, examples/paintbot/seat_view.nim,
examples/paintbot/bots.nim, coworld/paintbot/guide.md (Combat and equipment, File policies,
Rules 49, Score for cogs out, Match score, Score hearts), docs/bassy-porting.md,
examples/paintbot/players/base.bas, and the commits between coworld-v0.3.110 and v0.3.124 that
touch mechanics.nim and seat_view.nim: 4d670ec (rules 49), 985a394 (own timers, neural only),
1fc2d95, 244dc62, 0a617aa (training library only), 28030de (Bassy runtime).

## 1. Unchanged basics

| Thing | Value | Where |
| --- | --- | --- |
| Tick rate | 24 ticks per second, 100 units = 1 m, arena 6400 x 4000 | sim.nim:10, 15-16 |
| Match length | 14400 ticks (10 min, HeartMeterMatchTicks) | sim.nim:12 |
| Body radius | 55 | sim.nim:17 |
| Move speed | 28 units per tick (6.72 m/s). Carrying 70% (19). Sneak 50%. Water 25%. Radar carrier 60% (16). Leaving a trench 1/5 per axis | mechanics.nim:879-886 |
| Spawn shield | 36 ticks after spawn, no damage while shield > 0. First shot order that can land is tick 30 (ray leaves at tick 35) | sim.nim:948, 977, mechanics.nim:865 |
| Gun windup | 5 ticks, aim locked at the order, ray leaves from where you stand on tick 5 | mechanics.nim:13, 954-1016 |
| Gun cooldown | 24 ticks, tripled (72) with armor, carrying or in a trench. Being hit without those caps the cooldown back to 24 (96 for a sniper) | sim.nim:19, mechanics.nim:568, 1015-1016 |
| Gun damage | 1 per hit (2 when the shooter is radar boosted) | mechanics.nim:468-472, 1026 |
| Trench | 70% of outside shots pass over a cog in a trench, same-trench shots and spray ignore that | mechanics.nim:991-993 |
| Spray | reach 850, cone half width 4/5 of the distance, burst 5 ticks, recovery 8 (next burst 13 ticks later), 3 damage per victim per burst, blocked by a spawn shield | mechanics.nim:6-9, 12, 96-101, 946-950, 1030-1036 |
| Grenade | charge up to 24 ticks, reach 150 + 1130 * charge / 24 (max 1280), flight 10 ticks, blast 360 + 55 body = 415, 3 damage (6 in the landing trench, 2 in another trench), allies and self included | mechanics.nim:3-5, 11, 623-647 |
| Pickups | taken within 120 units in seat order, grenades refill in 120 ticks, everything else in 720 (30 s) | mechanics.nim:743-796 |
| Medkit | sets HP to max (10 now) if below it. Armor pickup sets armor to 3 if below 3 | mechanics.nim:762, 768-769 |
| Pickup kinds | 0 grenade, 1 spray, 2 medkit, 3 armor, 4 uniform, 5 mister, 6 sniper, 7 radar | sim.nim:118-122 |
| Heart capture | within 140 and a traversable line, 72 ticks (3 s) with only your team touching, both teams touching pauses it, the owner alone resets it | sim.nim:25, 71, mechanics.nim:424-450 |
| Sounds | footsteps 1000 every 12 ticks unless sneaking, gun 3500, grenade 5000, spray 1800 | mechanics.nim:916, 948, 960, 632 |

## 2. What rules 49 changed

### Gun (mechanics.nim:16-25, 56-70, 954-1000)

- Reach 2133 (21.3 m) instead of 5250. FFA keeps 2000. BASIC `gunRange()` returns the live value: 2133, or 4800 while you carry the sniper.
- Aim jitter: two draws of +-300 (was +-32) summed, so a triangular error of +-600 measured per 5250 of ray. Sideways error at distance d is up to 600 * d / 5250. Elevation still scales it (spread = 100 - (yourHeight - targetHeight) / 4 percent, clamped 50 to 150).
- Duds: a ball that reaches a cog farther than 711 (GunDudStart) may land without bursting. Chance = (d - 711) * 50 / 1422 percent, so 10% at 1000, 17% at 1200, 27% at 1500, 38% at 1800, 50% at 2133. A dud still stops the ray.
- Hit chance on level ground, still target, perfect aim (guide numbers, interpolations from the formula in brackets): 100% at 500, [96% at 600], [90% at 711], [82% at 800], 67% at 1000, [53% at 1200], 39% at 1500, [29% at 1800], 20% at 2133.
- A moving target adds lead error on top. Practical engagement band for a 1 damage gun against 10 HP: inside 1200, and inside 800 when you can afford to close.

### HP and lives (sim.nim:65, 72-74, 358-362, mechanics.nim:193, 228, 579-590)

- Every cog spawns with 10 HP (maxHp = FfaMaxHp) and ONE life. A dead cog never respawns (`equipment.lives` goes 1 -> 0, the respawn branch at mechanics.nim:843 needs lives > 0).
- A kill therefore takes 10 gun hits, 4 spray bursts, 4 grenades, or one self-destruct from a 10 HP bomber.
- `livesLeft` is 1 while alive and 0 when dead. `teamLives(t)` now equals the team's living cogs, `teamCogsOut(t)` its dead cogs, and the two sum to 8.
- Spawn shield still exists but only matters for the opening 36 ticks.

### Sniper rifle, pickup kind 6 (mechanics.nim:34-41, 756-758, 964, 995, 1015)

- Replaces the gun until death. Same 5 tick windup and 1 damage. Reach 4800. Old tight jitter (+-32 per draw, effectively always on a still target) and no duds.
- Cooldown 96 ticks (4 s), tripled to 288 with armor, carrying or trench. A hit caps it back to 96.
- Shares the spray slot: you cannot take a sniper while holding spray or spray while holding a sniper. `hasSniper()` returns 1 while carried. `gunRange()` returns 4800.
- Island spot (1100, 3700) and mirror (5300, 300), nudged to dry ground. Generated maps carry their own mirrored pair.

### Windex-mister, pickup kind 5 (mechanics.nim:26-33, 770-776, 798-821)

- For 1440 ticks (60 s) the carrier cannot attack at all (gun, sniper, spray, grenade, self-destruct) and any windup, burst or charge in progress is dropped on pickup.
- Every 360 ticks (at 15, 30, 45 and 60 s after pickup) it heals 1 HP to every living cog within 500 of the carrier, itself and enemies included, up to max HP. Four heals total. Death ends it. A misting cog cannot take another mister.
- BASIC `mistingTicks()` (ticks left, 0 when not misting), `playerMisting(i)` (fog gated).
- Island spot (2300, 2700) and mirror (4100, 1300).

### Radar, pickup kind 7 (mechanics.nim:45-52, 83-96, 472, 759-760, 777-783, 882)

- For 1440 ticks, or until the carrier takes ANY other pickup or dies, every living cog within 800 of the carrier deals double damage with every weapon, any team (enemies inside the ring are boosted too, several radars do not stack).
- The carrier cannot attack and moves at 60% speed. Taking a radar while carrying one restarts the minute and drops the attack in progress.
- BASIC `radarTicks()`, `radarBoost()` (1 while your own damage is doubled), `playerRadar(i)` (fog gated).
- Island spot (3000, 500) and mirror (3400, 3500).

### Self-destruct (mechanics.nim:42-44, 649-666, 1019-1023, bots.nim:74)

- `selfDestruct()` blows the cog up on that tick: every OTHER living cog within 415 (grenade blast 360 + body 55), allies included, takes the bomber's current HP as damage (armor absorbs as usual, walls and trenches do not matter). The bomber dies whatever its shield or armor.
- Goes off in seat order before that tick's gunfire lands, so a cog you shoot this tick can still explode on you. Ignored while misting or carrying a radar.
- A radar boosted bomber deals double.

### New host functions (bots.nim:98-104, seat_view.nim:139-146, 298-313)

`gunRange()`, `hasSniper()`, `mistingTicks()`, `playerMisting(i)`, `radarTicks()`, `radarBoost()`, `playerRadar(i)`, `selfDestruct()`, plus `worldSeats` / `me.seats`. Everything older (`teamLives`, `teamCogsOut`, `glory`, `controlOwner`, `controlCaptureTeam`, `nearAgents`, sounds, water, terrain) is unchanged.

### Bassy runtime (28030de, docs/bassy-porting.md, guide.md:106-178)

- `/` is fixed point division (Q16.16, range -32768 to 32767). It raises BasicError when either operand is outside that range, and a fixed point value passed as a host coordinate or index is an error. Use `\` for integer division. This, not the names, is what disables cand_v55 at its first decision (isqrt line 33 divides a squared distance).
- `TRUE` and every comparison produce -1. `AND`, `OR`, `NOT` are bitwise: `NOT 1` is -2, which is truthy, so `not carrying` is true while carrying. Write `carrying = 0`.
- The old scalar names (`selfX`, `worldTick`, `visible(i)`, `playerX(i)` and so on) are still bound (bots.nim:81-97, observations.nim:65-74) and refresh when referenced, so a mechanical port may keep them. `me.*` and `agents(i).*` records are the documented path.
- Budget per decision: 50,000 instructions and 125,000 work units (was 20,000 instructions). A loaded `agents` column costs 4 work units per seat per decision.

## 3. Win condition and glory with one life

Win (mechanics.nim:1077-1094, sim.nim:1078-1083):

- Heart meter: each owned heart pays 1 tick point per tick. Target = hearts * 4320 / 2 = 21600 for ten hearts (half the hearts for three minutes). Holding 6 hearts fills it in 150 s, all 10 in 90 s, 1 heart never finishes inside the match.
- Elimination: when one team has no cog alive (and none with lives), the survivor's meter is set to the target and the match ends at once. With one life this is the common ending. Both teams out at once ranks the meters as they stand (draw if equal).
- Otherwise at tick 14400 the higher meter wins, equal is a draw (winner -2).

Glory, the ladder score (sim.nim:28-51, 1085-1125, 1142-1182, guide Match score):

- Each team starts at 600 and loses 1 per second. Only the winner keeps its glory: the loser is set to 0, a draw zeroes both.
- +10 per 30 s with no supply collected by the team (quiet_supplies, the clock restarts on any grenade, spray, medkit, armor, uniform, and the three new items).
- +20 per score heart touched (mirrored pairs from 0:20, every 10 to 20 s, 30 s lifetime, 120 reach).
- Every 5 s, behind_lives per life fewer than the enemy. With one life a "life" is a living cog, so this is paid per cog deficit. Default 1, the guide says every teams variant configures 5.
- Every 5 s, behind_cogs per cog out beyond the enemy's count (rules 47). Default 1, variants 10. The same cog deficit pays both awards, so trailing by 2 cogs pays 2 * (5 + 10) = 30 per 5 s under the variant values, or 4 per 5 s under the defaults.
- Consequence: a fast elimination win (for example 4:00 = 360 kept) beats a slow meter win, and a comeback from behind in cogs is worth more than a clean sweep. Nothing that helps you win (kills, captures, meter) pays glory.

## 4. How the bundled base.bas handles rules 49

File /Users/me/p/paintbot-pw-0124/examples/paintbot/players/base.bas.

- HP cap: tracks the most HP it has seen (`hpCap`, lines 153-156) instead of a constant, so thresholds are `me.hp * 3 <= hpCap` (one third) and `me.hp * 2 <= hpCap` (half).
- Target gate: `d2 <= gunRange() * gunRange()` (line 179), so the sniper widens it automatically. Target cost still uses `(3 - agents(i).hp) * 160000` (line 174), which is negative for 4 to 10 HP (healthy foes cost more, still a monotone preference for hurt ones).
- Disarmed (lines 316-338): while `mistingTicks() > 0 or radarTicks() > 0` and not carrying, walk to the nearest visible teammate if it is farther than 300, to keep it inside the heal (500) or boost (800) radius.
- Wanted pickups (lines 358-364): grenade when none, medkit when hp < cap, armor when armor < 3 and hp full, sniper (6) when `hasSniper() = 0 and me.hasSpray = 0`, mister (5) when `me.hp * 2 <= hpCap and mistingTicks() = 0`, radar (7) when `friendsNear >= 3 and radarTicks() = 0`. A radar carrier wants nothing except a medkit at a third HP or less (any pickup ends the radar).
- Gun (lines 652-661): gunWait 25, or 73 when slowed, no sniper case. The engine ignores extra shoot orders while cooling so this only wastes orders.
- Self-destruct (lines 722-745): at `me.hp * 3 <= hpCap`, not misting, not radar: counts visible cogs within 270 (72900). A teammate inside vetoes, a foe with hp <= own hp counts as a kill, and it fires when kills > 0. The 270 is wrong: the real blast is 415, so base misses kills at 270 to 415 and can kill a teammate standing at 270 to 415.
- Does not use `radarBoost()`, `playerMisting()` or `playerRadar()`.

## 5. cand_v55.bas: every assumption rules 49 or Bassy breaks

File /Users/me/p/andre_von_auto/games/paintbot-pw/zhar/cand_v55.bas (891 lines).

### Fatal under Bassy (seat disabled or logic inverted)

| Lines | Now | Change to |
| --- | --- | --- |
| 33, 37, 47, 58, 86, 87, 93, 104, 107, 122, 123, 128, 129, 271, 272, 304, 305, 323, 324, 381, 382, 419, 442, 443, 450, 451, 452, 453, 454, 665, 666, 669, 670, 716, 717, 740, 741, 864 | `/` (38 sites) | `\`. Line 33 raises BasicError on the first isqrt call (squared distance above 32767), line 47 would pass a fixed point coordinate to waterAt |
| 405, 441, 536 | `not carrying` | `carrying = 0` (bitwise NOT of 1 is -2, truthy) |
| 412 | `not hasGrenade` | `hasGrenade = 0` |
| 421 | `not pickupVisible(j)` | `pickupVisible(j) = 0` |
| 224, 228, 359, 475, 573, 841 | flags assigned from comparisons are now -1 | works as truth values, but normalise before adding to costs or mixing with 0/1 flags (`readyAim` 544/551, `clear` 729, `lineBlocked` 706/754, `bestShielded` 254). `-1 and 1` is 1, so the current mixes happen to work |
| 869 | `chargeGrenade(grenadeCharge < need)` passes -1 | fine, the host tests nonzero (bots.nim:105-106) |
| 2, 7 | comments: "int32 only", "20,000 instructions" | fixed point exists, budget 50,000 instructions / 125,000 work units |

### Ranges

| Line | Now | Change to |
| --- | --- | --- |
| 251 | `d2 <= 27562500` (5250 squared, 52.5 m) | `d2 <= gunRange() * gunRange()` (4549689 gun, 23040000 sniper). Add an engagement gate: shots past 1200 land under 53%, past 1500 under 39% |
| 259 | `d2 < 6760000` foesNear at 26 m | a foe at 22 to 26 m cannot hit you with a gun any more, only a sniper can. Use `gunRange()` squared or keep and know it counts foes out of reach |
| 236 | `< 360000` enemy near its own heart (respawn shield guess) | delete, nobody respawns |
| 536-540 | hold and plant at any range up to 52.5 m | plant only inside the band (about 1200), otherwise close in or refuse the fight |
| 573, 752 | `hasSpray = 0 or bestCost < 640000` | spray reach 850 unchanged, but bestCost shifts with the HP term (see 216) |
| 722 | lead `* 5` | unchanged, windup is still 5 for gun and sniper |
| 759 | `plantUntil = worldTick + 6` | unchanged |
| 760-766 | gunWait 25 / 73 | unchanged for the gun. Add `if hasSniper() then gunWait = 97` (289 when armored, carrying or in a trench) |
| 844-874 | grenade: `d2 > 160000 and d2 < 1562500`, safe radius 202500, `need = (root - 150) * 24 \ 1130 + 1` | numbers unchanged (reach 150 to 1280, blast 415). But 3 damage is no longer a kill of a 3 HP cog, it is 30% of one |

### HP thresholds (3 HP, medkit to 3)

| Line | Now | Change to |
| --- | --- | --- |
| 216 | `cost = d2 - (3 - playerHp(i)) * 160000` | `(10 - playerHp(i)) * 48000` (same 1.44M swing between full and 1 HP). As written it adds up to 1.12M cost for a full HP foe and shifts the 640000 and 1440000 gates at 433, 573 and 752 |
| 412 | `kind = 2 and selfHp < 3` | `selfHp < 10` |
| 417 | `selfHp = 1` (medkit worth a life) | `selfHp * 3 <= 10` |
| 433 | `selfHp = 1` (go for the kit even in contact) | `selfHp * 3 <= 10` |
| 412 | wants only kinds 0 and 2 | add 6 (sniper when `hasSpray = 0 and hasSniper() = 0`). Armor (3) is now +30% on 10 HP at the price of a tripled cooldown. Decide 5 and 7 explicitly, see below |

### Lives, respawn and spawn shield

| Line | Now | Change to |
| --- | --- | --- |
| 150, 159, 169-174 | `teamLives(1 - selfTeam)` drop means an enemy will respawn in 72 ticks | it now means an enemy is gone for good. teamLives = living enemy cogs |
| 165-182 | dropTick ring and `shieldEnd = dropTick + 102` | delete. Keep `shieldEnd = 30` for the opening shield (36 ticks, first landing order at tick 30) |
| 222-246 | fresh sighting near an enemy heart inside the respawn window is "shielded" and costs +100M (last target) | delete all but `shielded = worldTick < 30`. Under one life this gives every enemy near its hearts a 102 tick free pass after each enemy death |
| 154-160 | respawn teleport guard resets gunWait and prevFoeLives | harmless, never fires after tick 0 |
| none | no disarmed branch | while `mistingTicks() > 0 or radarTicks() > 0` every shootAt, chargeGrenade and selfDestruct is ignored by the engine. Either never take kinds 5 and 7, or add the base.bas stay-with-a-teammate branch (base.bas:316-338) |
| none | no self-destruct | add it with the real blast radius 415 (`d2 <= 172225`), teammate veto, and the seat order fact: it lands before this tick's gunfire |
| none | ignores `radarBoost()` and `playerRadar(i)` | an enemy radar carrier (slow, unarmed) is the best target on the field, and standing inside an enemy radar ring doubles your own damage too |

### Time budgets and loops

| Line | Now | Note |
| --- | --- | --- |
| 7 | 20,000 instructions | 50,000 instructions / 125,000 work units. The 16 seat loops at 210, 736, 776, 852 cost 4 work units per seat per loaded `agents` column if ported to records |
| 210, 736, 776, 852 | `while i < 16` | fine for the 16 seat league. `worldSeats` or `me.seats` is available |
| 396, 409 | `pickupCount()` capped at 64 | island pickup count is 18 now (rules 49 items appended at indices 12 to 17), fine |

### Strategy facts the port should carry

- One life: a death at 2:00 costs the team one eighth of its guns for eight minutes and pays the enemy 5 + 10 glory per 5 s if they win. Fleeing (lines 441-467) and medkits matter far more than before.
- Elimination ends the match at once, so killing the last enemy is worth more than any heart.
- The sniper is the only weapon that reaches past 21 m, and it hits a still target almost every time. One sniper per squad changes the cadence math: gunWait 97 ticks, not 25, with the same 5 tick windup and lead.
- Mister heals enemies within 500 as well, four times 1 HP over a minute of being unarmed. Low value unless the squad is retreating together.
