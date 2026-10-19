The decisive gap is finishing the god. The macromackie seat does 61% of its team's damage to the two god-guard towers and the god (4103 of 6692 per game); ours does 99, about 1%. 9 of the 10 pairs that flip toward macromackie end with fewer enemy guards down for us, and our seat dealt 0 guard damage in all 10. Most of the score gap (3.0 of 4.0 game-points) comes from seats 0 and 5, where khors drafts Crossbowman, not from the Warlock.

The extractor is written and ran on all 48 replays: 3 at a time, every hash check passed, no errors. All numbers below are means over the 24 pairs, macromackie vs ours, unless marked otherwise.

## Where the 4.0-point gap comes from (0.875 vs 0.708)

| Our seat drafted | Pairs | macromackie | ours | Points lost |
|---|---|---|---|---|
| Crossbowman (seats 0 and 5) | 10 | 8.0 (W7 D2 L1) | 5.0 (W2 D6 L2) | **3.0** |
| Warlock | 14 | 13.0 (W13 L1) | 12.0 (W10 D4) | **1.0** |

## Causes, ranked by effect

**1. It finishes the god.**
- The match result tracks enemy guards down most closely (r = 0.90 on the paired differences). Team damage to guards and god is next (r = 0.85).
- In the 10 pairs that flip toward macromackie:
  - Guards down: 1.8 vs 0.2.
  - Enemy god HP at the end: 40 vs 400.
  - Team damage to guards and god: 6947 vs 1746. The macromackie seat alone dealt 4443 of it; ours dealt 0.
  - Teammates did not make up the difference: 2504 for macromackie's teammates, 1746 for ours.
- When the result is the same, our teammates do make it up (+3651), because they reach the guards with time to spare.
- Speed once a lane is cleared (first enemy gate tower down), counting only games where the god died:
  - Gate to god: 3.4 min vs 4.9 min.
  - First guard to god: 1.5 min vs 2.6 min.
  - The god died in 20 of 24 macromackie games and 12 of 24 of ours.
  - We never cleared a lane in 4 games; macromackie always did.
- In the 8 games we turned from win to draw, the guards still had 5077 HP on average at the 20-minute limit. The macromackie seat's own guard damage in those same pairs averaged 4870.
- After 15 minutes the macromackie seat spends 29% of its alive time in the enemy base; ours spends 4%.

**2. Our seat in seats 0 and 5 (Crossbowman) leaves the team 4 against 5.**
- Ours as Crossbowman:
  - 29.4 jungle-camp kills vs 5.8.
  - Near an ally 30% of the time vs 44%.
  - Home 17% vs 9%.
  - In 10–20 min it farms its own edge lane (30% of the time) instead of going mid or into the enemy base.
  - Dies 3.1 times a game in the first 5 minutes, and 3.1 times a game to creeps.
- The team pays for it:
  - Team deaths 45.5 vs 36.9.
  - Own structures lost 7.7 vs 5.4.
  - Enemy damage to our structures 15.7k vs 10.5k.
  - Enemy structures destroyed by 20 min: 8.1 vs 10.7.
  - First enemy gate falls 1–3 minutes later, or never.
- 7 of the 10 flips are these seats.

**3. It is a second lane-pushing force.**
- Its damage to towers and barracks is 9321 vs 2831 per game: 48% of its team's hero structure damage, against our 14%.
- Its route, by game phase:
  - 0:20–5:00: the short edge lane 63–73% of the time (the edge where its own towers sit close to home), 33% of the time just outside an enemy tower's range. It kills the first enemy outer tower at 2.7 min vs our 3.4.
  - 6:00–11:00: mid, 72–81% of the time.
  - From 12:00: the enemy base.
- Ours as Warlock goes mid in the first 5 minutes, then splits between lanes following carries.

**4. It survives and farms, which is what lets it tank the guards.**

| | macromackie | ours |
|---|---|---|
| Time dead per game | 1.3 min | 3.9 min |
| Deaths in first 5 min | ~0.7 | 2.7 |
| Buybacks | 4.25 | 0.67 (Warlock 0.07) |
| Lane last hits | 137 | 77 (Warlock 37) |
| Gold earned | 4170 | 2263 (Warlock 1123) |
| Hero level at end | 13.1 | 9.8 (Warlock 7.2 at 20 min) |
| Items bought | 55 | 19 |

macromackie's purchases are mostly 23 poison and 16 healing potions a game; its gear is knight armor, rune crossbow and boots. These seat-level stats on their own barely separate flipped pairs from unflipped ones (seat level, deaths and dead time give r from −0.24 to 0.11, buybacks 0.05). They are the enabler, not the deciding factor.

**5. Not a cause: hero kills and joining fights.**
- Its 16.7 kills (vs 4.8) mostly replace teammates' kills: team kills are 39.3 vs 41.3, r = 0.21.
- Time near an ally is equal: 44% vs 46%.

## What our Warlock does and fails to do (14 pairs)

It does help the mid-game:
- It heals 5163 a game.
- Its teammates deal twice the structure damage (20.8k vs 10.0k) and get more kills (31.6 vs 14.7).
- Enemy structures down: 4.9 vs 4.0 at 10 min, 11.6 vs 10.9 at the end.

It fails at the finish:
- Its own guard and god damage is 124 vs 4504.
- Team damage to guards and god by 16 min: 3719 vs 6532.
- After 15 minutes it is in the enemy base 3% of the time vs 36%.
- It is dead 20–37% of every 2-minute stretch after minute 6.
- Games end 1.8 minutes later (17.1 vs 15.3), and 3 of 14 wins become draws at the time limit.

Caveats: 12 rosters and 24 pairs only, and the r values are correlations, not proof of cause. "Flipped" means macromackie's result was better; the correlation table also counts the 2 pairs where ours was better.

## Files

- Extractor: `/private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad/recon/polyworld_108/tmp/gota_timeline/seat_diff.nim`, built to `/tmp/claude-501/seat_diff`.
  - `seat_diff REPLAY SEAT` writes one `<replay>.seat` file per replay with:
    - the seat's position every 10 s;
    - its deaths (where, killer, minute), kills, items, buybacks and per-minute snapshots;
    - the team's and enemy's structure kills;
    - the game end;
    - a `seat` summary line: assists, last hits, damage by target, gold, heals, time dead, time near allies, own creeps and enemy towers;
    - `mate` and `team` lines.
  - `seat_diff collate LIST` pairs the files by roster and seed and writes the comparison.
- Comparison: `/private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad/seatdiff_tool/collate.md`. It holds the per-pair table, subset tables (all, Warlock, Crossbowman, flipped, same), the correlation table, the guard-siege timings per pair and the per-minute curves.
- Per-replay outputs: `/private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad/seatdiff/<key>/<mack|ours>/games/00N/replay.replay.seat`
- Helper tables in `/private/tmp/claude-501/-Users-me-p/d08480cb-a763-4e49-b256-28456bd5f8e5/scratchpad/seatdiff_tool/`:
  - `route_minutes.txt`: where the seat was, per 2-minute bin.
  - `deaths.txt`: seat deaths with killer and phase.
