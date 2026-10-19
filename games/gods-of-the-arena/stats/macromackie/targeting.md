# macromackie targeting and spells: 20 khors v270 head-to-head replays

The biggest gap is the R dodge. macromackie sidesteps every R that has one of its heroes in the footprint, and only 2 of 154 such casts hit (1.3%). Our heroes are hit 61% of the time by its R. The second gap is when we take fights: it attacks a hero almost only when it outnumbers the defenders locally, and 70% of its targets die within 3 s. Ours die 12% of the time, because khors scores targets up to 30 tiles away.

Last-hit timing, stutter-stepping and the level-up order are the same in both bots, so they need no change.

## Data and how to reproduce
- **Replays:** the 20 files in `scratchpad/hmack/*.raw`, listed in `hmack/h2h.txt`. They contain 1228.8 alive hero-minutes for macromackie and 807.7 for khors. All rates below are per alive hero-minute.
- **Extractor:** `/private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad/recon/polyworld_108/tmp/gota_timeline/mack_targeting.nim`, built to `/tmp/claude-501/mack_targeting`.
- **Geometry debug helper:** `.../tmp/gota_timeline/mack_rdebug.nim`, built to `/tmp/claude-501/mack_rdebug`. Usage: `mack_rdebug PATH SLOT`.
- **Output:** per-game records in `scratchpad/mtgt/*.tgt`; the full collated report in `/private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad/mtgt/report.txt`.
- **How it reads a replay:** the extractor looks at the world state just before the tick each order applies, then steps the sim with hash checks. Rejected orders are matched from `ActionRejected` events. Spell hits come from `Damage` events with cause `AbilityEffect`.

```
cd .../recon/polyworld_108
POLYWORLD_DEPS=.../recon/deps108 nim c --hints:off --path:examples/gods_of_the_arena -d:headless -d:release -d:replayEvents --nimcache:.../recon/nimcache_mack_targeting -o:/tmp/claude-501/mack_targeting tmp/gota_timeline/mack_targeting.nim
cd .../scratchpad
awk '{f=$1; sub(/\.rows$/,".raw",f); print f,$2}' hmack/h2h.txt | xargs -P 2 -n 2 sh -c 'b=$(basename "$0" .raw); /tmp/claude-501/mack_targeting "$0" "$1" > mtgt/$b.tgt'
/tmp/claude-501/mack_targeting --collate mtgt/*.tgt > mtgt/report.txt
```
A full run takes about 31 s with 2 processes.

## Engine facts that explain the numbers
- **Basic attacks:** a Crossbowman hits 13 ticks into its swing and the cycle is 30 ticks. There is no projectile delay and no armor. A lane creep has 60 HP. Hero damage is 19 + 12×(level−1), plus items.
- **Q, slot 0:** Final Measure. It is castable, costs 0 mana, has a 216-tick cooldown and 7-tile range, and is a homing projectile.
- **W, slot 1:** Siege Scarab. Homing projectile with 3 charges, costs 22 mana, range 6.67 tiles. Damage by rank is 23, 47, 91, 130.
- **E, slot 2:** Lodestone Surge. A 90° cone from the caster with 6-tile radius, landing 12 ticks after the cast, costs 40 mana. Damage by rank is 31, 63, 122, 175.
- **R, slot 3:** Clockwork Charge. A capsule from the caster, 7.5 tiles long with a 0.75-tile half-width, landing 24 ticks after the cast, costs 70 mana. Damage by rank is 106, 240, 470.
- **Area spells can be dodged.** They resolve at impact against where heroes are then, and they also miss targets more than 1 tile higher or lower than the caster.
- **What BASIC can see:** `spells(i)` gives `abilityId` (E = 26, R = 27), `casterId`, `impactTick`, `hostile` and `position`. For E and R the position is the caster's origin. The caster's facing is set to the cast direction, and it can be read from `objects().facing`.
- **Area casts by target fail where point casts do not.** `castTarget` with an area spell fails with OutOfRange beyond range. `castPoint` clamps the point to range instead.
- **Attack-move pulls neutral camps.** An attack-moving hero auto-acquires the nearest enemy within 6 tiles, and that includes resting neutral camps.

## 1. Hero targeting

**Fresh switches onto an enemy hero:**

| | macromackie | khors |
|---|---|---|
| Rate | 2.22/min | 4.58/min |
| Distance to target, median (p75, p90), tiles | 8.95 (10.4, 14.6) | 14.4 (22.5, 28.1) |
| Target HP share, median | 1.00 (69% of targets at full HP) | 0.73 |
| Target moving at the time | 74% | 55% |
| Local edge ≥ +1 | 69% (+2: 45%) | 21% (−1: 48%, 0: 31%) |
| Target died within 3 s | 70% (ally kill 1196, own kill 699) | 12% |
| 2+ own heroes ordering on the same hero within 1 s | 80% (3+: 52%) | 58% (3+: 26%) |
| With 2+ visible candidates: picked lowest HP / nearest | 81% / 47% | 60% / 56% |
| Target within 7 tiles of one of its own towers | 45% | 0.7% |

- **Local edge** here means our heroes within 8 tiles of the attacker (including itself) minus their heroes within 8 tiles of the target (including the target).
- **Kill conversion by edge:**
  - macromackie: +2 gives 83%, +1 gives 67%, 0 gives 55%, −1 gives 45%.
  - khors: +2 gives 38%, +1 gives 21%, 0 gives 11%, −1 gives 6%.
- **Across all hero attack orders,** including re-issues, macromackie picks the lowest-HP candidate 90% of the time and the nearest 60%.
- **Opening spell:** 42% of macromackie's switches have a W from the same hero within ±1 s (median 12 ticks after the attack order). khors does this in 25%.
- **Total hero damage per alive minute is similar.** Basic: macromackie 150, khors 211. Spells: 142 vs 139. So the difference is which fights we take, not how hard we hit.

**Rules:**
- Only consider enemy heroes within 10 tiles, never more than 14 tiles.
- Engage only when (own heroes within 8 tiles of self) − (enemy heroes within 8 tiles of the target) ≥ +1.
- Pick the lowest-HP visible hero inside that radius, so every teammate converges on the same target.
- Open with W.
- With an edge of +2, it is fine to dive a target standing near its own tower.
- Drop khors' current `distance <= 900` (30 tiles) scoring for heroes and creeps.

## 2. Creep targeting and last hits

**Switches onto a lane creep:**

| | macromackie | khors |
|---|---|---|
| Rate | 6.16/min | 13.13/min |
| Distance, median (p75, p90), tiles | 6.0 (7.8, 10.3) | 9.4 (19.3, 26.7) |
| Share of switches beyond 10 tiles | — | 48% |
| With 2+ creeps in range: picked lowest-HP creep | 89% | 93% |
| Creep HP ≤ hero damage at order, all levels | 65% | 54% |
| Early game only (damage below 60): creep HP / damage, median | 1.37 | 1.22 |
| Early game only: HP ≤ damage | 25% | 26% |
| Who killed the creep | ally 3174, self 3003, creep 1335 | ally 3714, self 2483, tower 2288 |
| 2+ own heroes ordering the same creep within 1 s | 64% | 68% |

- The all-levels gap in the HP ≤ damage row comes from macromackie being higher level. The early-game rows show the last-hit timing is the same.
- **Lane hits that kill:** macromackie 76–78%, khors 71% on explicit orders and 50% on auto-acquired targets.
- **Lane last hits per alive minute:** macromackie 5.57, khors 4.95.

**Rule:** only order attacks on creeps within 7 tiles (8 at most), and keep the lowest-HP choice.

**Neutral camps (the jungling the user flagged):**
- Attack orders on neutrals: khors 5254 (6.5/min, 18% of all its attack orders), macromackie 1870 (1.5/min, 8%).
- W on neutrals: khors 713 (20% of its W casts), macromackie 264 (6%).
- About half of macromackie's hits on neutrals are auto-acquired by attack-move, not ordered.
- Rule: no explicit neutral targets, and no W on neutrals, unless the camp is hitting us.

## 3. Spells

| | macromackie | khors |
|---|---|---|
| Q released | 0.12/min; 48% of orders rejected OutOfRange | 0.07/min |
| W released | 3.75/min (17% of orders OutOfRange) | 4.32/min |
| W target mix | lane creeps 58%, heroes 32% | heroes 41%, lane 33%, neutrals 20%, towers 6% |
| E | castPoint 1.61/min, 100% accepted | castTarget 2.27/min ordered, 1.64/min released |
| R | castPoint 0.57/min, 99.6% accepted | castTarget 0.40/min ordered, 0.27/min released |
| R casts that hit a hero | 21% (148/699); 40 hero-kills... see below | **1.8% (4/219)** |
| R hero damage over 20 games | 16,261 damage, 26 kills | 511 damage |

- **Q:** macromackie targets heroes 78 times and lane creeps 43 times.
- **W, macromackie:**
  - On lane creeps it is a last-hit tool: 70% of those casts have creep HP ≤ W damage.
  - On heroes it opens the fight: target HP share median 0.94, and 85% of those targets die within 3 s.
  - Mana at cast: median 49, p10 25. It spends down to the cost.
  - W is the main spell: 127k hero damage and 194 kills (khors W: 86k and 88). It is homing and cannot be dodged.
- **W, khors:** 99.7% of its creep W casts are on creeps it can kill. Its hero targets die within 3 s 32% of the time.
- **E, macromackie:**
  - Aim distance median 4.56 tiles (p25 4.0, p75 5.4). Mana at cast p10 is 40, exactly the cost.
  - The aim point has a lane creep within 2 tiles 63% of the time, so E is mostly wave clear.
  - 17% of E casts hit a hero; 32% hit nothing.
- **E, khors:** 28% of orders fail (OutOfRange 296, InsufficientMana 198, TargetUnavailable 16). 23% of released casts hit a hero.
- **R, macromackie:** cast distance median 5.61 tiles. In 70% of casts no enemy hero is in the footprint (the aim is at creeps, neutrals or towers). When a hero is in the footprint at release, about half are hit.
- **R, khors:** cast distance median 6.95 tiles. 33% of orders fail (InsufficientMana 68, OutOfRange 38).
- **Level-up order is identical:** W, E, W, E, W, R, W, E, E, Q, Q, R. 100% of macromackie heroes follow it through L6, and khors' priority code produces the same order.

**Rules:**
- Cast E and R with `castPoint` at the target's tile, never `castTarget`.
- Cast at most one spell per tick, or subtract mana already spent this tick before checking the next cast.
- R against macromackie heroes is nearly worthless. Spend it on a group that cannot step out, or accept that it only forces them to stop attacking for 1 s.

## 4. Dodging (the main new finding)

When an enemy R puts one of its heroes in the footprint at release:

| | macromackie heroes | khors heroes |
|---|---|---|
| Cases | 154 | 194 |
| Walked during the 24-tick window | 100% | 71% |
| Delay before the walk | 1 tick in every case | median 11 ticks |
| Walk length, median (p10–p90), tiles | 1.41 (1.06–1.68) | — |
| Walk mostly sideways to the spell axis | 100% | — |
| Issued an attack order during the window | 3.9% | 64% |
| **Hit** | **1.3% (2/154)** | **61%** |

- macromackie's dodge walk goes to the side it already stands on 88% of the time. It ends about 1.2–1.7 tiles off the axis.
- macromackie does **not** dodge E (castTicks 12): only 8.5% of its walks in that window are sideways. It is hit by E 42% of the time; khors is hit by E 69%.

**Rule for BASIC:**
- Each tick, loop over `spells()`. Act on entries where `hostile` is set, `abilityId = 27` and `impactTick > match.tick`.
- Take the axis from the caster's `objects().facing` (unit length, in tiles) and the origin from `spells(i).position`.
- Compute `along` and `across` for our hero. If `-0.5 ≤ along ≤ 8` and `|across| ≤ 1.25`, walk 1.5 tiles perpendicular, to the side of the sign of `across` (+1 when it is 0), on that same tick.
- Do not issue attack orders until `impactTick` has passed.
- The facing and coordinate orientation still need checking with `gota_check108` before relying on it.

## 5. Stutter-step and hit cadence (same in both bots)
- Both bots hit, then walk to their own spot on the next tick, then re-attack the tick after. Re-attacking restarts the swing, so a hit lands every 14 ticks instead of every 30.
- **Hit gaps:**
  - macromackie: median 14 ticks; 62% of gaps are 16 or less, 98% of those after a walk.
  - khors: median 14 ticks; 81% are 16 or less, all after a walk.
- **Stutter walks (fight walks of 1 tile or less):** macromackie 6.89/min, khors 13.08/min.
  - Walk made after the hit landed: 95.5% vs 96.1%.
  - Ticks from hit to walk: median 1 for both; ticks from walk to next attack: median 1 for both.
  - macromackie's walk length is under 0.1 tile; khors steps about 0.25.
- **The one difference:** macromackie does not reset the swing on lane creeps. Its median gap there is 28–30 ticks, versus 15 for khors.
- No change needed here.

## 6. Other numbers
- **Attack orders:** macromackie 18.8/min, khors 36.4/min. Attack-moves: 21.3/min vs 5.6/min.
- **Explicit tower attacks:** macromackie 5915 orders (25.6% of its attack orders), with 4117 hits mostly at the 14-tick cadence. Building damage per minute is 325 vs 180. This overlaps the tower-dance area.
- **TargetUnavailable rejections on attack orders:** khors 1476 (5%), macromackie 152 (0.7%).
