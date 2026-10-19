# macromackie economy and life cycle, from 20 replays (khors v270 vs macromackie)

Every macromackie (mack) life follows the same loop. It drinks a potion whenever it is missing at least the potion's full heal. It goes home only when it has no heal potions left and its HP is under 25%. At home it buys the next gear item and stocks up to 5 heals and 1 portal. It leaves 1.7 s after reaching full HP, alone, without waiting for allies. When it dies it buys back on the very next tick every time it can afford to.

The result: mack spends 89% of the battle in the field and 0% dead (medians). We spend 40% in the field and 40% dead.

## Method and reproduction

- **Extractor:** `/private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad/recon/polyworld_108/tmp/gota_timeline/mack_economy.nim`, binary `/tmp/claude-501/mack_economy`.
- **Build** (from the worktree root):
  `POLYWORLD_DEPS=/private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad/recon/deps108 nim c --hints:off --path:examples/gods_of_the_arena -d:headless -d:release -d:replayEvents --nimcache:/private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad/recon/nimcache_mack_economy -o:/tmp/claude-501/mack_economy tmp/gota_timeline/mack_economy.nim`
- **Run** (one process, one replay at a time, about 60 s):
  `/tmp/claude-501/mack_economy /private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad/hmack/h2h.txt /private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad/econ/records.txt > /private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad/econ/summary.md`
- **Outputs:**
  - `.../scratchpad/econ/summary.md` holds every distribution (n, mean, p10, p25, median, p75, p90).
  - `.../scratchpad/econ/records.txt` has one line per purchase, use, portal, death, stay and trip home.
- **Scope:** the 20 local replays only, so 100 hero-games per side. Mack won all 20. Nothing was fetched, uploaded or simulated beyond these replays.
- **How the extractor works:** it steps the sim with hash checks and records each hero's state every tick, then reads the events and the order stream.
  - Orders take effect in the tick they are stamped with (3056 of 3056 purchases matched the same tick). So the "state at a decision" is the snapshot from the tick before.
- **Definitions:**
  - "Home" means the hero's own keep or spawn room, the areas where buying is allowed.
  - A walk into the keep counts as a trip home only if the hero reaches the spawn room or buys something. Otherwise it is a fight at our god.
  - The recall decision is the first order of the last unbroken run of walk orders aimed at the own keep or spawn. For 29 mack and 17 khors trips there was no such order, so the farthest point of the final approach is used instead.
  - "In combat" means the hero took enemy damage in the last 3 s (72 ticks).
  - "Hazard" tables count how often a field state is followed by the action on the next tick, per eligible minute.

## Where the time goes (share of battle time, median)

| place | mack | khors |
|---|---|---|
| field | 0.89 | 0.40 |
| dead | 0.00 | 0.40 |
| keep | 0.07 | 0.18 |
| spawn room | 0.02 | 0.03 |

- Deaths per alive minute: mack 0.23, khors 1.31 (medians). Deaths inside our own keep: mack 0.01 per hero-game, khors 2.78.
- Time in the field before a death: mack median 74 s, khors 16.8 s. Before a trip home: mack 153 s, khors 105 s.

## Income and the XP question (per alive minute, median)

| source | mack gold | khors gold | mack XP | khors XP |
|---|---|---|---|---|
| total | 168 | 106 | 330 | 149 |
| lane last hits | 81 | 64 | 60 | 45 |
| hero kills | 58 | 22 | 87 | 34 |
| buildings | 10.4 | 0 | 27.6 | 0 |
| neutrals | 10.9 | 7.4 | 14.3 | 9.6 |
| god kill | - | - | 82.5 | 0 |

- XP per hero-game: mack mean 4039 (3039 without the 1000 god-kill bonus), khors mean 1516.
- About jungling: against macromackie our neutral XP is small. It is 173 per hero-game (mean, median 68), about 11% of our XP. Mack actually gets slightly more, 214 (median 172).
- Time near camps (within 6 tiles) is 13% of our field time against 8% for mack.
- So in these games the XP gap comes from being dead 40% of the time and spending 18% of it in the keep, not from the jungle. The 935.95 neutral XP you quoted must come from league games against other opponents; this data can't check it.

## Purchases

**Opening:** all 100 mack hero-games and all 100 khors hero-games buy dagger + heal (140 of 150 gold), 4.6 s into the stay. Both teams leave at about 18 s.

**Gear chain** (mack, 98 of 100 hero-games): dagger, then armor (item 16, 160), then Rune Crossbow (item 19, 180), then boots (item 8, 100). Nothing after that, because the 6 slots are dagger, armor, crossbow, boots, heal stack and portal.

| gear | median battle minute | median gold before |
|---|---|---|
| armor | 3.87 | 350 |
| crossbow | 5.35 | 455 |
| boots | 5.60 | 350 |

- **Rule:** buy the next gear item at any shop visit where gold ≥ its cost. This held in 161 of 161 affordable stays, and mack never bought gear when short (45 stays).
- **Comparison:**
  - khors: 35 hero-games dagger, armor, axe, crossbow; 26 dagger only; 20 stop at armor.
  - khors buys the crossbow at minute 7.9 (median), mack at 5.4.
  - khors never buys boots.

**Order within one tick:** gear first, then heal, then portal. Typical batch: `armor crossbow boots heal portal`. More heals follow over the next few ticks.

**Heal stock cap:**
- mack buys heals only while holding 0 to 4, so it keeps 5 (counts of purchases at 0/1/2/3/4 held: 360/206/142/135/132; never at 5). It leaves a trip home with a median of 5 heals and 1 portal.
- khors only buys heals while holding 0 or 1, so it caps at 2. It leaves with a median of 1 heal.

**Where and when it buys:**
- mack buys on the first tick it is in the keep, before reaching the spawn room: median 0.33 s after keep entry. 925 of its purchases happened in the keep and 907 in the spawn room.
- Median gold before a heal purchase: mack 260, khors 55.

**Consumables per hero-game (mean):**

| item | mack | khors |
|---|---|---|
| heal | 9.75 | 6.26 |
| portal | 3.69 | 3.35 |
| mana potion (item 22) | 0.54 | 0 |
| vitality elixir (item 2) | 0.37 | 0 |
| mana elixir (3), poison (4) | 0 | 0 |

- Mana potions are bought only when a slot is free.
- Elixirs are bought only in buyback stays, from minute 9.4 on, with 0 heals held and gold of 587 or more (median 1050). They are used at a deficit of 91 HP or more.

**Gold:**
- Gold left after a trip home: mack median 85, khors 20.
- Gold at death: mack median 380, khors 45. Gold at match end: mack 365, khors 80.
- Mack keeps no buyback reserve early on. It has gold at death because it earns more, dies less and has a full inventory late.

## Potions

**Rule: drink only when the missing amount is at least the full restore.**

| item | restore | smallest deficit at use (mack) |
|---|---|---|
| heal (item 1) | 120 over 10 s | 120 HP (n=704) |
| elixir (item 2) | 90 instant | 91 HP (n=15) |
| mana potion (item 22) | 90 over 10 s | 90 mana (n=52) |

**Heal potion hazard** (mack, holding a heal that is off cooldown, in the field):
- Missing less than 120 HP: 0 uses in 35,500 eligible seconds.
- Missing 120 or more and HP under 50%: 11 to 14 per minute, so it drinks within about 5 s.
- Missing 120 or more and HP 50% to 90%: 3.7 to 5.5 per minute.
- 344 of 704 mack drinks happen in the same tick as a walk order, the retreat step of its kiting.

**Heal use context:**

| | mack | khors |
|---|---|---|
| HP fraction at use (p25 / median / p75) | 0.31 / 0.47 / 0.63 | 0.15 / 0.46 / 0.66 |
| missing HP at use (median) | 295 | 204 |
| took damage in last 3 s | 42% | 57% |
| fighting a hero in last 3 s | 34% | 23% |
| used inside the keep | 1 of 704 | 157 of 458 |
| interrupted by damage | 25% | 27% |

- khors drinks as early as 70 missing HP: 60 uses in the 60 to 119 bin, about half of each potion wasted.

**Mana potion hazard** (mack): mana under 30% gives 4.3 to 6.6 uses per minute; 30% to 50% gives 0.6 to 1.2; 50% or more gives 0. Median mana at use is 0.16.

## Portal scrolls (item 21)

Mack has three distinct uses for a portal:

1. **Back out to the lane, from the spawn room at full HP** (173 times).
   - The target is always the most forward own tower, the tier-0 outer tower of an edge lane.
   - Its aim is that tower's tile: Red (-38,-47) or (50,11), Blue (-51,-12) or (37,46), in world tiles.
   - In 150 of 189 lane portals, most allies in the field were nearer the chosen outer tower than the other edge lane's outer tower. All heroes of a team pick the same lane at the same time.
2. **Shortcut home from the keep entrance** (76 times).
   - At HP 0.14 (median), about 28 tiles from spawn, usually with a portal bought that same tick.
   - Aim is the spawn tile, which lands at a guard tower next to the spawn.
3. **Escape home from the field** (30 times), at HP 0.03 to 0.23, aimed at the spawn tile.

- **Rule:** if it decides to go home while holding a portal that is off cooldown, it always uses it (28 of 28).
- **khors:** 140 of its 288 portals go from spawn to a tower behind the front of its lane (an inner or gate tower while a lower tier still stands). Only 36 go to the forward tower, and only 47 of 122 lane portals go toward the side where its allies are.

## Going home

**Trigger (mack): no heals held and HP under 25% of max.**
- 131 of 141 order-based decisions were at 0 heals and HP under 25%. 164 of 171 trips started with 0 heals.

| mack recall hazard, 0 heals | recalls per min |
|---|---|
| HP 10–15% | 10.7 |
| HP 15–20% | 11.3 |
| HP 20–25% | 15.3 |
| HP 25–30% | 0.39 |
| HP 30–40% | under 0.7 |
| holding 1 or more heals, any HP | at most 0.22 |

- **khors** goes home holding potions in 88 of 147 trips. Its recall rate at HP under 20% with heals held is 16 to 21 per minute.

**State at the decision:**

| | mack | khors |
|---|---|---|
| HP fraction (p25 / median / p75) | 0.15 / 0.21 / 0.25 | median 0.12 |
| HP (median) | 98 | 33 |
| mana fraction (median) | 0.22 | 0.39 |
| gold (median) | 530 | 155 |
| tiles from spawn (median) | 108 | 102 |
| enemy hero within 10 tiles (mean) | 0.63 | 0.19 |

- Gold does not trigger the trip (p10 is 160).
- **The trip:** mack walks to its spawn tile with one walk order (median 35 s), using a portal if it holds a ready one. It enters the keep at HP 0.15 (median). Trips per hero-game: mack 1.71, khors 1.47.
- **Alone, not as a pack:** allies who also start home within 10 s: median 0 for both (mean mack 0.23, khors 0.33). Allies dead at the decision: mack 0.04, khors 1.03.

## Stays at home and leaving

| stay type | mack median length | khors median length | mack spent | mack gold in → out |
|---|---|---|---|---|
| trip home | 19.3 s | 23.1 s | 350 | 530 → 85 |
| buyback | 4.7 s | 10.3 s | 160 | 295 → 135 |
| natural respawn | 3.0 s | 12.5 s | 100 | 175 → 120 |
| start | 18.1 s | 17.4 s | 140 | 150 → 10 |

- **When it leaves:** it does not wait for allies.
  - First outbound order comes 1.67 s after reaching full HP and mana (p10 1.54, p90 1.75).
  - It leaves the spawn room 0.75 s after full HP (khors 1.46 s).
  - Regen in the spawn room takes 5 s.
- **How it leaves:**
  - After a trip home: attack-move in 162 of 171, because the portal is still on cooldown from the trip home.
  - After a respawn or buyback: portal to the forward outer tower in 158 of 311. When it doesn't portal, gear and heals took the gold (mostly before minute 6) or the portal was on cooldown.
  - khors walks out of the keep after 465 of 609 respawns, which is why it spends 18% of the game in the keep.
- **Nobody waits:**

| at exit, median | mack | khors |
|---|---|---|
| allies leaving within 5 s | 0 | 0 |
| allies within 8 tiles 20 s later | 0 | 0 |
| nearest ally exit | 9.7 s | 5.8 s |
| distance from spawn 30 s after a respawn | 101 tiles | 53 tiles |

## Buyback

**Rule: buy back on the first tick after death whenever gold ≥ 100 × deaths so far.**
- Mack bought back 233 times. It skipped 0 of its affordable deaths. Every buyback came 1 tick after the death event.
- It buys back even when the respawn wait is only 9 s.

| mack buybacks | p25 | median | p75 |
|---|---|---|---|
| respawn time left | 9 s | 14 s | 19 s |
| price | 100 | 200 | 300 |
| gold before | 325 | 575 | 870 |
| gold after | 140 | 295 | 660 |

- Mack averages 2.33 buybacks per hero-game. The median buyback is its 2nd death, at minute 7.35, with 4 allies alive and no enemy near its god.
- It shops right away: the first purchase comes 0.21 s after the buyback.
- **khors:** 15 buybacks in 969 deaths. It skipped 73 affordable deaths (median wait only 9 s, median gold 285, minute 3.4). Its buybacks come late (minute 11.1) at 600+ gold.

## Rules for a BASIC rewrite

1. **Opening:** buy dagger (11) and heal (1), then attack-move out at about 18 s.
2. **On the first tick in the own keep or spawn:**
   - Buy the next gear item in the chain armor (16) → crossbow (19) → boots (8) whenever gold ≥ its cost (160 / 180 / 100).
   - Then buy heals until 5 are held.
   - Then buy 1 portal (21) if none is held.
   - Mana potion (22) only if a slot is free. Late and rich (gold of about 600 or more) with no heals: elixirs (2).
3. **Potions:** drink a heal when maxHp − hp ≥ 120, an elixir when it is ≥ 90, a mana potion when maxMana − mana ≥ 90. Never earlier.
4. **Go home** when heals = 0 and hp < 0.25 × maxHp:
   - Use the portal at the spawn tile if one is held and off cooldown. Otherwise walk to the spawn tile.
   - On entering the keep, buy and then portal to the spawn tile if the portal is ready.
   - Never go home while holding a heal.
5. **Leave home** as soon as HP and mana are full (within 2 s), alone:
   - After a respawn or buyback, portal to the own outer tower of the edge lane where most allies in the field are.
   - Otherwise attack-move out.
6. **Buyback:** on the first tick dead, if gold ≥ 100 × deaths, buy back. No reserve and no minimum respawn wait.
