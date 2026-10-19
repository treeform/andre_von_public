# Tower-edge positioning: macromackie vs khors v270, from 20 head-to-head replays

macromackie (written "mack" below) keeps every hero exactly one tile outside the nearest enemy tower's range. It crosses that line only when at least 3 of its own creeps are inside the tower's range and the tower is shooting a creep. It leaves again when 1 creep is left.

That line, 1 tile outside the tower's range, is where mack farms. 35% of its lane last hits come from there, at 15.2 last hits per minute spent there. khors spends 1% of its alive time at that spot.

khors does something else. Before minute 8, 30% of its tower-attack orders are issued while the tower is shooting a khors hero, and khors heroes stay under tower fire 4.5 times longer than mack's.

On your question: `xp_lasthit` 1221 vs 1910 is partly this. mack holds the tower edge and khors does not. But the biggest cause in these 20 games is time alive: khors was alive for 800 hero-minutes against mack's 1221. Per alive minute the last-hit rates are close (5.0 vs 5.6). The `xp_neutral`/jungling question belongs to another area and I did not measure it here.

## Data and how to reproduce

- **Replays:** the 20 khors v270 vs macromackie replays in `scratchpad/hmack/*.raw`, with team sides from `h2h.txt` (10 with khors as Red, 10 as Blue). macromackie won all 20.
  - Alive time: mack 1221 hero-minutes, khors 800.
  - Every replay passed the hash check.
  - Nothing was uploaded, no local games were run, and no source was fetched. I did read our own `khors.bas` to explain one finding.
- **Extractor:** `/private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad/recon/polyworld_108/tmp/gota_timeline/mack_tower.nim`, built to `/tmp/claude-501/mack_tower`.
  - For each order it records the state at the end of the tick before the order, which is what the bot saw when it decided. It also records state every 12 ticks.
  - Recorded per hero:
    - distance to the nearest living enemy tower, and the "margin": that distance minus the tower's range (negative means inside range)
    - what the tower is shooting
    - own creeps inside the tower's range, and their hp
    - hero hp, attack cooldown, what the hero is doing, nearby heroes
    - the order and its target point
  - It also logs each stretch where a tower is shooting the hero (an "aggro episode": length, damage, how it ended), each death, each hero hit on a tower, and each creep last hit.
  - The tower's range comes from `TowerAttackRanges`: outer 9.0 tiles, inner 9.5, gate and god guards 10.0.
- **Build** (from the worktree root):
  `POLYWORLD_DEPS=/private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad/recon/deps108 nim c --hints:off --path:examples/gods_of_the_arena -d:headless -d:release -d:replayEvents --nimcache:/private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad/recon/nimcache_mack_tower -o:/tmp/claude-501/mack_tower tmp/gota_timeline/mack_tower.nim`
- **Run** (two at a time, about 47 s for all 20):
  `cd /private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad && cat mack_tower_rows/list.txt | xargs -P 2 -n 2 sh -c 'id=$(basename "$0" .raw | sed "s/ereq_//" | cut -d- -f1); /tmp/claude-501/mack_tower "$0" "$1" > mack_tower_rows/$id.rows'`
  Each line of `list.txt` is `<raw path> <our team>`.
- **Pool:** `/tmp/claude-501/mack_tower --sum mack_tower_rows/*.rows > mack_tower_rows/summary.md`
  The full tables (608 lines) are in `/private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad/mack_tower_rows/summary.md`.
- **How orders are classified:**
  - **Retreat:** a walk order toward the hero's own god whose target is more than 20 tiles away. For mack this is always a walk to its own spawn tile.
  - **Step-back:** a shorter walk back. These are attack-cancel stutter steps.
  - **Attack-move forward:** an attack-move toward the enemy god (mack's always target the god's center).
- Numbers are written as median [quartile 1 .. quartile 3], with n = count.

## 1. Where the heroes stand (sampled every 12 ticks)

| Margin to the nearest enemy tower | mack share of alive time | khors share of alive time |
|---|---|---|
| inside range (≤ 0) | 10% | 7% |
| 0 to 1 tile outside | 8% | 1% |
| 1 to 2 tiles outside | 13% | 1% |
| 2 to 8 tiles outside | 8% | 4% |
| more than 8 tiles outside | 61% | 88% |

- When none of its own creeps is in the tower's range (heroes within -2 to +4 tiles of the line):
  - mack's margin is 1.1 [0.8..1.4], and it is inside range only 5% of that time.
  - khors's margin is 0.1 [-1.5..1.4], and it is inside range 49% of that time.

## 2. The edge line

This applies when the tower is idle or shooting a creep, and none of the hero's own creeps is inside the tower's range.

**The line is exactly 1.0 tile beyond the tower's range, measured from the tower's center:**

| Tower | Line (tiles from center) |
|---|---|
| Outer | 10.0 |
| Inner | 10.5 |
| Gate | 11.0 |
| God guard | 11.0 |

- **Inside the line:** in every 0.05-tile step up to 0.3 tiles inside the line, mack's orders are retreats 97–100% of the time (outer tower) or 82–95% (other tiers). The rest are mostly spell casts. Attack-move forward is 0–1%.
- **At or beyond the line:** retreats drop to 1–25% and attack-move forward rises to 29–74%. The remainder are explicit attacks on creeps and heroes, and casts.
- **Retreat order:** a walk to the hero's own spawn tile (Red (53.5,−53.5), Blue (−53.5,53.5)), about 120 tiles away. The next decision overrides it.
  - It is issued at margin 0.7 [0.5..0.9].
  - The hero moves 0.5 [0.4..1.1] tiles before its next different order, which comes 12 [12..18] ticks later at margin 1.3 [1.1..1.5].
  - That next order is attack-move forward 64% of the time, attack a creep 14%, attack a hero 8%, cast 7%.
- **Advance order:** an attack-move to the enemy god's center. Attack-move auto-targets anything within the Crossbowman's 6-tile range, so the hero stops on creeps and heroes near the line.
- **Decision rate:** mack decides every 6 ticks. Gaps between consecutive orders cluster at multiples of 6 (6 ticks 31.7k times, 12: 18.5k, 18: 8.3k, 24: 3.0k, 30: 1.8k). The 1- and 13-tick gaps are stutter steps.
  - In the edge band, attack-move then retreat makes up 17% of consecutive order pairs (gap 12 [12..18] ticks), and retreat then attack-move another 17%.
- **Timing:** retreats and attack-moves are both issued when the hero is not mid-swing (cooldown 13 [13..13], i.e. not swinging). The dance is purely about position. Stutter steps are separate and come right after a hit lands (cooldown 30).
- **Explicit attacks from the line:** these target something inside the tower's range 83–87% of the time, and 71–72% target something more than 6 tiles away. That pulls the hero in for at most 6 ticks, then the next decision sends it back.

## 3. Entering range to hit the tower

**Entry needs a tower busy with a creep and at least 3 of mack's own creeps inside its range.**

| Tower-attack orders | mack | khors |
|---|---|---|
| All, before minute 8 | 3,657, tower shooting a creep 100% | 4,678, tower shooting a creep 69%, an ally hero 22%, the attacker 8% |
| From the edge (margin ≥ −0.5), before minute 8 | 750 orders | 345 orders |
| — with 0 own creeps in range | 0% | 59% |
| — with ≥3 own creeps in range | 99% (3: 46%, 4: 12%, 5: 25%, 6+: 16%) | 36% (5: 29%, 6+: 6%) |
| — tower was shooting | a creep 100% | a hero 40%, nothing 17%, a creep 39% |

- **Stay or leave:** inside range, with the tower shooting a creep, here is the share of mack orders that are retreats. Columns are how many tower shots the creeps' hp can absorb (outer 36 damage, inner 48, gate 60).

  | Own creeps in range | < 1 shot | 1–2 shots | 2–3 shots | 3+ shots |
  |---|---|---|---|---|
  | 1 | 87% (n=277) | 59% (n=814) | – | – |
  | 2 | 46% (n=39) | 24% (n=206) | 22% (n=1,020) | 1% (n=640) |
  | 3 | – | 14% | 9% | 13% / 4% |
  | 4+ | – | – | 11% | 5% / 6% |

  The 3-creep row's last two cells are 3–4 shots and 4+ shots. The 4+ row's 3+-shots cells are 5% (3–4 shots) and 6% (4+ shots, n=5,669).
  - khors retreats 0% in every cell. Creep count never makes it leave.
  - So mack has a gap between its entry and exit rules: it goes in at 3 or more creeps and leaves at 1 or fewer, or at 2 if their hp covers fewer than 3 tower shots.
- **While hitting the tower:** both bots stand at margin −2.2 and stutter the same way: attack, then 13 ticks later a 1-tick walk, then attack again (gaps 13 and 1 ticks in both). So damage per hit is equal. mack makes 215 tower hits per game, khors 183.

## 4. When the tower shoots a hero

- **Before minute 8, against outer and inner towers, at levels 1–5:** with no own creep in range and the hero inside range, mack's orders are 57% retreat and 41% attack-move forward. Only 1% are tower attacks (n=356).
- **Late game, gate and guard towers:** mack tanks the tower and finishes it.
  - At levels 6–7 it retreats 9% of the time and attacks the tower 38%. At level 8+ it retreats 1% and attacks 45%, with the rest mostly stutter steps.
  - Below 75% tower hp, retreats are 2–6%. Above 75% they are 29%.
  - After minute 8, 50% of mack's tower-attack orders are issued while the tower is shooting a hero.
- **Tower shooting an ally**, before minute 8, no own creep in range, hero within −1.5 to +1 of the range:
  - If this hero is the nearest of its team to the tower, it retreats 76% of the time (n=17).
  - If an ally is nearer and the shot ally is at the edge of range, it attack-moves forward 60% and retreats 33% (n=283).
  - If the shot ally is deep inside range, it retreats 59%.
  - Compare an idle tower: 91–97% retreat whether or not an ally is nearer.
- **Time standing in range while the tower shoots a hero:**
  - mack: 0.57 s per alive minute before minute 8 (0.25 s as the target itself), 2.10 s after minute 8.
  - khors: 2.17 s per alive minute before minute 8 (0.88 s as the target), 1.07 s after.
- **Tower-aggro episodes, before minute 8:**
  - mack: 268 episodes, length 17 [8..27] ticks, damage 36 [0..36], which is one outer-tower shot or none. The hero died in 4%. When the hero walked out of range, that took 12 [4..24] ticks.
  - khors: 179 episodes, length 77 [52..91] ticks, damage 180 [120..216] (five shots). The hero died in 23%.
  - Overall, tower damage per alive minute is mack 30.9 vs khors 45.4. khors was already fighting when 64% of its episodes started (mack 24%).
- **Why khors does this** (`khors.bas` lines 228–232 and 538–547):
  - A tower always gets a base target score of `1000 - distance*3`. The +2000 bonus while the tower shoots a creep is extra, so khors still picks the tower when nothing else is around.
  - The tower-safety check only fires when the tower is shooting us and we are below 65% hp, or when an idle tower is within 8 tiles.
  - A tower shooting a teammate never triggers a step away.

## 5. Deaths and farming at the edge

**Deaths:**
- mack died 16.6 times per game. 21% of those deaths were inside a khors tower's range.
  - Before minute 8 that was only 10 of 135 deaths, none killed by the tower.
  - After minute 8 it was 59 of 198, 22 killed by towers. That is the late dive into our base, paid for with buybacks.
- khors died 48.5 times per game. Only 3% of those deaths were inside a mack tower's range (12 killed by towers before minute 8).
  - So khors's deaths do not come from towers. They come from fights outside tower range.

**Last hits, by where the hero stood:**

| Margin | mack: share of last hits | mack: share of time | mack: last hits per minute there | khors: share of last hits | khors: share of time |
|---|---|---|---|---|---|
| 1 to 2 tiles outside | 35% | 13% | **15.2** | 3% | 1% |
| more than 8 tiles outside | 42% | 61% | 3.9 | 83% | 88% (4.7 per minute) |

- Overall last hits per alive minute: mack 5.6, khors 5.0. Totals: 6,846 vs 3,995.

## 6. Rules a BASIC bot could use

- **Tower range from `maxHp`:** 1900 means 9.0 tiles, 2600 means 9.5, 3900 means 10.0 (gate and guards). Set `line = range + 1.0`.
  - Use `hp > 0`, not `alive`, when deciding if a tower is dangerous. In BASIC, `alive` for a tower means "attackable", but unexposed towers still shoot.
- **Safe to be in range** when the tower's `targetId >= 1000` (a creep) and your own lane creeps inside the tower's range (not the line) number 2 or more. If there are exactly 2, also require their combined hp to be at least 3 tower shots: 108 / 144 / 180.
  - The tower shoots creeps first and keeps its current target while it can, so this is stable.
- **Decide every 6 ticks:**
  - If it is safe and there are 3 or more creeps: attack the tower with the existing stutter.
  - If it is not safe and `dx² + dy² < line²`: walk to your own spawn this decision.
  - Otherwise: attack-move to the enemy god's center, and attack or cast on creeps and heroes from where you stand.
- **When the tower shoots another hero:** treat it as unsafe unless that hero is nearer to the tower than you are.
- **Never attack a lane tower that is shooting a hero.** This is the main gap in khors: 30% of its tower-attack orders before minute 8, against mack's 0.3%.
  - Exception, as mack does: gate and guard towers when your level is 6+ or the tower is below about 70% hp. Then keep hitting even when it shoots you (mack retreats only 0–9% of orders there).

**Caveats:**
- These are 20 head-to-head games that macromackie won.
- The minute-8 split is my own cutoff. In this data it lines up with gate/guard towers and level 6+, so I cannot tell which of the three mack actually keys on.
- The rule for "tower shooting an ally" is a mixed pattern, not a clean threshold.
