# NMMO / Buyan audit (read-only)

2026-09-12. Grok audit, reviewed and corrected by the supervisor.
Scope: vendored sim `nmmo3.h`, protocol, daveey scripted FSM, Nim port
`buyan.nim`. No local scoring. No claimed XP gains. Source references
are under `sims/nmmo`, except `games/nmmo/buyan/buyan.nim`.

## Version check

- `sims/nmmo` was clean before and after `git fetch origin`.
- Checkout and fetched `origin/main` are both `96d4ce5` (2026-08-26).
  No newer main rules or example-policy updates were found.
- Main's mechanics-facing update `cb4a108` (2026-08-05) adds opt-in
  clean observations without changing physics or scoring.
- Parent's hosted registry inspection reports canonical coworld `0.1.5`,
  digest `sha256:c8d1b63796495d5136c8d19d87301051ecf3f5f3253b47d85c7f22f81e5f95eb`.
  Source support alone does not prove that hosted image supports clean obs.
- Fetched `origin/sol/nmmo-scripted-20260813` and
  `origin/daveey/main-local-2026-09-08` point to `a8453a2` and contain
  substantial Nim combat planner/executive examples. Their local score
  claims must not justify a keep or submission.

Replay is NMMO v1 (`replay.py`): seed + packed u8 actions; re-sim
recovers every obs byte. Hosted activation = player stdout + re-sim
counters, not mean score.

---

## Score (what actually ranks)

Seat score = per-agent `(cum_min_comb_prof + current min(comb,prof)) /
(deaths + 1)`, summed (`PROTOCOL.md:152-166`, `engine.py:440-454`,
`shim.c:nmmo_score`). Deaths = attack deaths + 500-tick stagnation
(`nmmo3.h:1926-1956`). Suicide farming is anti-scored.

- Comb XP: only `defender_lvl >= attacker_lvl` and `attacker_lvl < 40`
  (`nmmo3.h:1431-1435`). Weaker kills give gold + tool drop, not comb.
- Prof XP: harvest while `prof < tier_level(ground_tier)`
  (`nmmo3.h:1173-1176`). `tier_level(t) = 8 * 2^(t-1)` → T1 cap 8, T2 16.
- Tools drop at `level_tier(enemy_comb)` and despawn in 20 ticks
  (`nmmo3.h:1362-1385, 783`). T2 tools need ~L9+ kills.
- `hp_max` is 99 at spawn and never raised (`nmmo3.h:1056, 1790`).
  ideas.md “heal by % of S_HP_MAX” is a no-op.

Tick order: players (`pid < num_agents`) then NPCs (`c_step`
`nmmo3.h:1882`). Walking into cardinal adjacency to a melee NPC eats a hit
before we can attack; next tick `hp < 95` refuses the fight and flees.

---

## Baseline logic errors

1. **Flees beatable melee instead of fighting it.** Fight requires
   Manhattan 1 (`buyan.nim:672`). Disengage then RUNs from any live
   hint at Chebyshev ≤ 2 (`:712-735`). A delta-0 melee at distance 2
   is not attacked and is fled. Melee NPCs only strike at Manhattan 1
   (`enemy_ai` `:1610`); from distance 2 they walk. This starves comb
   XP and tool drops.

2. **`delta == 0` is not “XP fight”.** Obs byte 6 is
   `clamp((seen-my)/2, 0, 4)` (`nmmo3.h:963-970`). C truncates toward
   0, then negatives clamp: **every enemy at `comb <= mine+1` is
   delta 0**, including L1 trash that cannot raise comb once we are
   comb ≥ 2. Comments in both bots claim the opposite
   (`scripted_player.py:69-72`, `buyan.nim:663-665`).

3. **Fight is above harvest even when comb > prof.** Score is
   `min(comb,prof)`. Priority 4 fight vs 8 harvest (`buyan.nim:662-749`)
   spends ticks on comb that cannot raise the min.

4. **Herb mid-fight drops the commit.** Heal (hp < 45) is priority 3
   and is not `ATN_ATTACK`, so `attackStreak` zeros (`:777-781`).
   Resume needs commitment, hp ≥ 95, or a wounded-enemy cheap-kill gate.
   T1 herb restores 60
   (`use_item` `:1462-1470`): eating at hp 25–34 lands at 85–94, then
   disengage can RUN from the enemy if its health bucket is still >2.
   `in_combat`
   (fresh scalar, 5-tick) still true.

5. **Armor: fill-empty only, then sell the upgrade.** `equipAction`
   only equips armor into slot == 0 (`:557-561`). `junkSlot` protects
   armor only if that slot is empty (`:584-586`). T2 helm while T1 is
   worn is junked. Tools *do* unequip-then-upgrade (`:542-549`).
   Defense is `tier_level(tier)` per piece (`:1483-1491`); 3×T1 armor
   (def 24) zeros L1 NPC damage (`calc_damage` `:1289-1307`).

6. **Slots 9–11 are a trap.** Pickup fills 0..11
   (`get_free_inventory_idx` `:1112-1122`). Keys only address 0–8
   (`ATN_ONE..NINE`). `inventoryFull` waits for all 12 (`buyan.nim:244`).
   Items in 9–11 cannot be eaten, equipped, or sold.

7. **Failed-run recovery never fires.** `maybeRun` returns 22–25.
   `stepTowards` demotes `lastAction` only if it is in walk prefs 0–3
   (`:498-505`). `dest_check` is all-or-nothing (`:1195-1220`): a run
   with tile-2 occupied/blocked does not walk one tile; anim stays
   IDLE. Next tick still prefers the same axis.

8. **`maybeRun` checks terrain, not occupancy.** `passable` is
   grass/dirt only (`:259-264`). `dest_check` also requires
   `pids[adr]==-1`. Tile-1 clear + tile-2 occupied → walk would
   succeed, run is a full no-op. Flee scores the 1-tile dest then
   maybeRuns 2 (`:719-735`).

9. **Sell does not pay.** Listing removes the item
   (`nmmo3.h:2100`); gold is credited only when another seat buys
   (`:2034-2041`). Price-9 dumps free slots; they are not income.
   Buyan never reads gold (scalar 11) and never `ATN_BUY`.

10. **No `obs=clean`.** Connect uses the env URL as-is
    (`buyan.nim:790-809`). Patch 0003 is per-seat, physics-neutral
    (`PROTOCOL.md:16-25`, `server.py:377-382`). Legacy empty cells
    never write entity bytes (`nmmo3.h:958-974`); ghosts follow the
    window. Liveness is a workaround; first-obs enemies are ignored
    until bytes change (`updateLiveness` early return `:363-369`) —
    spawn `safe_tile(..., 5)` hides this at life start.

There is **no craft action**. Harvest converts ore→random armor,
hilt→sword, wood→bow (`nmmo3.h:1180-1189`). Buyan never holds a sword
(ATTACK_SWORD 3-wide cone, `:870-875`) or bow (4-tile axis,
`:877-882`). Held tool/bare is ATTACK_BASIC, one adjacent tile
(`:1318-1321`). Gems set element; EFFECT_MATRIX has 0× matchups
(`:848-854`). Counter-gems are a separate promising trial, with a
crossfire risk when different bow elements overlap.

Do not copy the fetched branch's `gemSlotFor` mapping directly: item
order Earth7/Fire8/Air9/Water10 (`:136`) differs from element order
Fire1/Water2/Earth3/Air4 (`:78`). Explicit mapping is required.

---

## Single-change candidates

Each is one FSM/URL change. Isolation tests + hosted replay/log
activation; parent scores with hosted XP. Do not combine.

### C1 — Hunt: stage beatable melee at distance 2, wait, then fight

**Change.** Before disengage: if exactly one live delta-0 melee
(entity element 0; L<15 are melee+neutral, `:1819-1833`), not in
combat, rested as today, Chebyshev 2–3: walk (never run) to Manhattan
2, then NOOP ≤2 ticks so the NPC closes. Adjacent fights stay the
existing branch.

**Evidence.** Error 1; player-first tick order; melee strike range 1
vs ranged 4 (`:1591-1630`). Current disengage treats distance-2
beatables as threats.

**Risk.** Mis-tagging ranged (element 0 is the melee test, not anim).
Crowds. Walking to adj anyway (eats a hit, then hp gate refuses).
Stale liveness without C6.

**Replay / logs.** Count: hunt-walk issued, hunt-wait issued, next
obs Manhattan==1, subsequent `ATN_ATTACK`, `comb_lvl` +1 or new tool
in inventory. Require at least one decision changed by hunt or wait.
Re-sim: action 0–3
toward a live delta-0 at dist 2, not run 22–25.

### C2 — Score-gate fights: start only when `comb <= prof`

**Change.** In the fight start condition, require
`combatLevel() <= professionLevel()`. Keep wounded/commit rules.

**Evidence.** Score is min (`PROTOCOL.md:152`). Comb XP cannot raise
the min when comb > prof. Priority 4 vs 8 (`buyan.nim:662-749`).
At comb=prof=1 a kill is still allowed (tool + first comb).

**Risk.** Delays T2 tools (need L9+ at higher comb). If harvest is
stuck (no tool, full inv), comb sits unused. Do not also change hunt
in the same candidate.

**Replay / logs.** Count `ATN_ATTACK` with `comb > prof` → 0.
Count harvest/move while `comb > prof`. Per life, `abs(comb-prof)`
histogram from re-sim scalars (offsets 1 and 7 at byte 1650).

### C3 — Armor upgrades (unequip then equip, like tools)

**Change.** For helm/chest/legs: if best unequipped key-slot armor
has strictly higher tier than the worn piece, press the worn item’s
key. Next tick empty-slot path equips. Do not junk higher-tier armor
once it is equipped (equipped already skipped). Optional same-change
junk protect: skip armor with tier > worn.

**Evidence.** Error 5. `use_item` refuses swap if slot occupied
(`:1542-1545`). Defense = `tier_level` (`:1483-1491`).

**Risk.** Two-tick unequip while a fight starts (in_combat blocks
equip, `:1473-1476`). Brief defense hole. Missing inventory key for
the worn piece (slots 9–11) must no-op.

**Replay / logs.** Issued unequip key while that armor slot nonempty;
next obs `equipment[slot]` tier increased. Count T2+ worn pieces.
Baseline should be ~0 upgrades of occupied slots.

### C4 — Keep fight commit across a herb

**Change.** Preserve an existing fight commitment across a herb action.
Keep `attackStreak` as the ghost cap. A separate bounded commitment
flag is preferable to treating every `inCombat` observation as a commitment.

**Evidence.** Error 4. `attack()` sets `in_combat = 5` on a connected
hit (`:1398`). Herb is legal in combat (`:1462-1476` checks combat
after herb). c_step decrements in_combat before the action
(`:1966-1968`), so a herb still leaves in_combat ≥ 1.

**Risk.** Using in_combat alone is too broad: being hit also sets it;
a delta-0 adjacent while
fleeing a stronger NPC could re-engage (gang-up). Ghost + being
hit already trusts adjacent imprints (`liveHints` `:397-405`).

**Replay / logs.** Sequence: `ATN_ATTACK`, then `ATN_ONE..NINE` herb,
hp 45–94, then `ATN_ATTACK` again vs `ATN_DOWN_SHIFT..` flee.
Baseline: flee after herb-at-25–34. Count post-herb attacks with
`in_combat>0`.

### C5 — Key-slot inventory cap

**Change.** Treat inventory full as “slots 0–8 all occupied”. Stop
harvest/tool-grab into 9–11. Dump when 0–8 are full.

**Evidence.** Error 6. `numKeySlots = 9` vs `inventorySlots = 12`.
Pickup index 0..11 (`nmmo3.h:1116`).

**Risk.** Slightly earlier dumps (3-tick sell). Incidental movement onto
resources can still fill slots 9–11, so merely capping intentional
harvest targets does not guarantee those slots stay empty.

**Replay / logs.** Count reduced occupation of inaccessible slots and
which decision changed because key slots were full.
Count `ATN_SELL` with slots 0–8 full and 9–11 empty. Baseline: any
nonzero 9–11 occupancy.

### C6 — `obs=clean` (URL only, keep liveness until witnessed)

**Change.** Append `obs=clean` via URI query (preserve slot/token).
Do not trust entity bytes as live until a same-window cell goes from
nonzero type to six zero entity bytes within one life (legacy never
writes type 0 on empty tiles). Then empty cells are truthful; keep
corpse filter.

**Evidence.** `PROTOCOL.md:16-25`, patch 0003, `server.py:377`.
`sim.py:123` no-ops if wasm lacks export — `[obs=clean]` in server
logs is not proof. Witness above is.

**Risk.** Hosted wasm without 0003 → request ignored, behavior must
match baseline aside from the query. Trusting clean too early
reintroduces ghosts.

**Replay / logs.** Witness count of type→0 clears; server log
`[obs=clean]`; action-delta vs liveness-only shadow on the *same*
obs (diagnostic, not a baseline replay). Require >0 witnesses and
>0 decision deltas. Physics/digest unchanged.

### C7 — Failed-run axis recovery

**Change.** In `stepTowards`, map run ids 22–25 to walk 0–3 before
the existing “blocked last move, drop that pref” branch.

**Evidence.** Error 7. `is_run` `:840-842`; `move(..., true)` aborts
if either tile fails `dest_check` (`:1215-1220`). Anim IDLE after a
run is a full miss (`c_step` `:1959` then no MOVE/RUN).

**Risk.** Tiny, local. Does not fix maybeRun occupancy (separate).
Low ceiling if C1 also cuts failed harvest runs.

**Replay / logs.** Only log when the normalize *changes* the chosen
action. Next obs: anim MOVE/RUN vs IDLE. Count issued ≠ 0.

---

## Other missed capabilities (not in the five-plus above)

- **Sword when `prof >= comb`:** T1 sword is +24 attack
  (`:1492-1494`) vs tool +0. Must unequip before harvest; FSM already
  skips resources when `heldToolTier==0` (`:615-616`). Two-tick swap;
  in_combat blocks it. Do not combine with C2.
- **Gang-up skip:** two live enemies within 2 of a delta-0 target.
- **Stagnation burst:** `min_comb_prof[500]` wrap resets the life
  (`:1933-1954`). Force long wander if min flat ~400 ticks.
- **Center-tile re-pickup:** `itemTiles` skips center (`:295-296`);
  after a dump on a resource tile, pickup never re-runs without
  stepping off (`pickup_item` only inside `move`, `:1240`).
- **Buy tools:** `ATN_BUY` → tier key → item key (`:2017-2054`).
  Liquidity depends on other seats listing; our dump is price 9.
  Weak until market evidence exists in hosted replays.

---

## Replay activation (common)

Format: magic `NMMO`, u8 ver=1, u32le header, JSON (seed, names,
tick_count), then `tick_count * num_agents` action bytes (`replay.py:1-22`).
`num_agents = len(config.players) * config.heroes_per_seat`.
Re-sim with the pinned wasm reproduces obs/scalars/`state_digest`.

Per episode, require the candidate’s counter > 0 before counting it
toward XP. Suggested Nim extractor (when implemented later): decode
header, step wasm, read scalars at 1650 (comb, hp, prof, in_combat,
equipment[5], inventory[12], anim) and window entity/item bytes.

Do not use local games as score. ideas.md “heal vs hp_max” is invalid
mechanics. Existing experiment dirs (clean/armor/escape/hunt/sword)
overlap C6/C3/C7/C1/sword-stance; this audit does not keep any of them.
Compare candidate and submitted baseline against identical opponent
policy IDs. Require at least 10 hosted activated episodes and dashboard
significance; inconclusive means more hosted XP or reversion. Activation
logs or replay extraction prove mechanisms, not policy score.
