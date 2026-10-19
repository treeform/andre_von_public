# Zero Sum — Belobog

Policy: **Belobog** (`belobog`) — the white god — half of the zero-sum pair with Chernobog.

Coworld: `cow_ebf72b34-cdad-44ad-a0d5-5a65839e49d6` (coworld name `zero-sum`)

Battle royale for 16 agents in 8 teams of 2: a loot-stocked central Fortress, a shrinking ring of fire, open talk channels, sponsor softcoin airdrops anyone can steal, and a finale that turns the last team against itself. Every death is a black firework.

## Leagues

- `league_6764202e-2ac1-4c98-a77e-cabc75582939` — Zero Sum

Dash: https://softmaxdash-nginx.tail0f4a29.ts.net/league/<league_slug>

## Example players in the coworld package

- `zero-sum-baseline` — Zero Sum Baseline: Bundled reference policy: allocates 6/6/4/4, loots nearby crates, fights when armed and healthy, flees weak, heals when safe, obeys the ring, claims its team's sponsor drops, forages. (run: `/app/zero_sum_baseline`)

## Baseline

The only example is `zero-sum-baseline` (`/app/zero_sum_baseline`) — and its
source is ALREADY Nim: `player/baseline.nim` in arisklar6/battle-royal
(github redirect from arisklar6/zero-sum), a survival-doctrine FFA bot.
NOTE: the manifest description ("allocates 6/6/4/4, fights when armed and
healthy") is stale — master allocates 7/3/5/5 and plays a flee-first
survival meta; the shipped image may predate that retune.

`belobog/belobog.nim` is a port of the master baseline with the local-play
coach mode stripped and the default knobs inlined (stats 10/1/5/4 after
the 2026-09-01 sim study; was upstream 7/3/5/5,
aggression 3, heal <70, flee <55, ring margin 2, finale "smart"). Priority
ladder per tick: never interrupt a channel > run from the fire > flee/fight
threats (finale hunt + terminal-burn override) > heal when clear > tuck
inside the next ring > loot tile/best visible item/pods > forage bush >
spacing. Event-driven chat (ignition/finale/gift/podium/low-hp/contact
DMs) ported too. Protocol zero_sum.player.v1 pinned from the game's own
repo — high confidence. No secret-envs needed on upload (no LLM).

## Ideas backlog

(one change per experiment; log: idea, change, XP id, opponents, verdict — see ../../auto.md)

- Teamplay: the baseline is FFA-blind — never attack the teammate slot,
  share heals via drop when partner DMs low hp, and converge on the partner
  early (score is per-contestant but two survivors beat one on placement).
- Fortress opening: tier-1 loot (sword/bow/camo) sits in the center chamber;
  time a straight ignition rush against the 8-way scramble vs staying outer
  — the baseline never enters the Fortress on purpose.
- Kill credit at the margin: score = placement + kills, and the baseline
  values a kill at ~0; raise aggression to take free finishes on adjacent
  criticals (last-damager rule means poison/bow tags steal credits cheaply).
- Ranged discipline: with bow/knives/blowgun, kite at range instead of the
  melee-tuned enemyDistance2 <= 2 engage rule; dodge chance and 2 tiles/tick
  projectiles make standing archery weak but kiting strong.
- Stat sweep: re-run the 7/3/5/5 vs 6/6/4/4 vs high-INT (vision/forage/
  poison resistance) builds via hosted XP requests; upstream retuned once
  already, our league field differs.
- Sponsor-drop ambush: gift_incoming is public with the landing tile —
  arrive first at OTHER teams' drops when healthy (free tier-1 items),
  instead of only claiming our own.
- Backpack/body gear: the baseline never equips gear or swaps weapons by
  rank from pack; add use-slot logic for backpack/camouflage and upgrade
  swaps when a better weapon sits in the pack.

## Sim study (worker, 2026-09-01)

Source: `arisklar6/battle-royal` @ `master` (`src/battle_royal/{sim,types,items,obs}.nim`).
Combat/stat formulas match DESIGN §5.2. Scoring on master has already
diverged from the hosted coworld `zero-sum` 0.1.18 (see below) — the
formulas that decide *who lives* are the same either way.

### Formulas (integer centi-HP; max HP = 10_000 = 100.00)

| Piece | Formula | File:line |
|---|---|---|
| Move cooldown | `16 - SPD` ticks/tile | `sim.nim:147` |
| Melee | `base * 100 * (5+STR) div 10` centi | `sim.nim:851,922` |
| Ranged/thrown | raw `base * 100` (STR does **not** scale) | `sim.nim:947–954,990` |
| Vision | `5 + (INT+1) div 2` tiles | `sim.nim:148` |
| Poison duration | `12 * (20 - INT)` ticks; 2 HP every 24t | `sim.nim:958`, `items.nim:59–60`, `sim.nim:1027–1034` |
| Forage double-yield | `5*INT` in 100 | `sim.nim:841` |
| Dodge | `2*ATH` in 100 (pass-through) | `sim.nim:980` |
| Zone/hazard taken | `dmg * (100 - 3*ATH) div 100` | `sim.nim:149–151,1000–1014` |
| Bow draw | `18 - ATH div 2` | `sim.nim:871` |
| Zone pulse | once per 24 ticks, sourceless | `sim.nim:1000–1010` |
| r=0 | **no safe tile** (center is not a hide) | `sim.nim:344–350` |
| First-aid | +50 HP / 48t channel; **any** damage cancels (kit kept) | `items.nim:50–51`, `sim.nim:867–869` |
| Rations | +15 HP / 24t, **not** damage-cancelled | `items.nim:52–53` |
| Weapon table | hands 5/1/12, sword 18/1/18, spear 12/2/20, bow 14/8, knives 8/5/10, blowgun 4/6/24 + poison, net 0/3/30 | `items.nim:36–49` |

Master scoring (`sim.nim:1222–1257`): `score = (numPlayers - placement) + podium[10,5,2]` for places 1/2/3. **Kills are tracked and never scored.** Placement = reverse death order; same-tick ties = higher `damageDealt`, then lower slot. Hosted 0.1.18 still uses the docs table (`15/12/10/… + 1/kill`). Survival dominates both; a kill is at most +1 on the deployed table and +0 on master.

There is **no stat HP and no stat regen**. Heals are items only. Stage-7 (24 HP/s from t=6912, r=0 at t=7536) outpaces even ATH-10 ration eating (15 HP/24t vs ≥16.8 HP/s).

### Breakpoints

**Speed.** cd = 15,14,…,6 for SPD 1..10. Tiles/s at 24 Hz = `24/(16-SPD)`. Upstream 7 = 2.67 t/s; SPD 10 = 4.00 t/s (**1.5×** the 7/3/5/5 bot, **1.83×** a default 5/5/5/5). No integer breakpoint past "faster is strictly better" — every point is −1 tick/tile on every move this policy issues.

**INT vision** (odd values only): INT 1–2 → 6, 3–4 → 7, **5–6 → 8**, 7–8 → 9, 9–10 → 10. Belobog's heal-clear test is `enemyDistance2 > 64` (8 tiles). INT 5 is the cheapest radius that actually sees that ring. Dumping to INT 4 wastes a point (still vision 7) and starts first-aid while an 8-tile enemy is in fog.

**ATH stage-7 pulse count** (100 HP, 24 HP/s pulse of `24*(100-3*ATH)/100`):
ATH 1–5 → **5 pulses** (120 ticks to unaided death). ATH 6–10 → **6 pulses** (144 ticks). ATH 5→4 does **not** change the pulse count (20.40 vs 21.12 HP/pulse; both die on the 5th). Bow draw is `18 - ATH/2`: ATH 4 and 5 are both 16. Dodge 8% vs 10%. **ATH 5→4 is nearly free against typical ATH-4/5 fields.** ATH 6 is the real extra-life breakpoint, and costs a vision or speed point we would rather keep.

**STR TTK from 100 HP, sword (18 × (5+STR)/10):** STR 3 = 14.4 × 7 swings; STR 1 = 10.8 × 10; STR 9–10 = 4 swings. **No one-shot exists** — even STR-10 sword is 27 < critical band 33 (`obs.nim:58–61`). Ranged is unscaled, so STR is melee-only. This policy flees until finale / `currentRadius <= 2`.

**Terminal 1v1 fists + zone 24 HP/s** vs a typical 7/3/5/5: dumping STR 3→1 while keeping ATH 4 loses the pure adjacent punch-out (~0.36 s). That slice is ~100 ticks at r=0 after 7000 ticks of movement. Mid-game kite/loot/ring EV of +3 SPD dwarfs it; arriving at r=0 with more HP (less chip, first to heals) wins the same race anyway.

### Dominant stat

**Speed is OP for this ladder.** The bot moves every tick it isn't channeling: ring, flee, spacing, loot. SPD 10 always outruns SPD 7 melee (cd 6 vs 9), always wins a same-start crate/pod/death-loot race, and spends less time in fire when the ring clips. STR is the dump; ATH 4 keeps the same stage-7 pulse count as the field; INT 5 is the vision breakpoint glued to the heal rule.

**Recommended build: 10/1/5/4** (sum 20). Runner-up if we ever sit in fire on purpose: 8/1/5/6 (buys the ATH-6 extra pulse, gives back 2 SPD).

### Information leaks (playbook §2)

- **`visible.pods` is not fog-gated** (`obs.nim:213–218`): every inbound/landed pod (tile, item, recipient, `lands_tick`) is in every living observation. Items/bushes/projectiles *are* LOS-gated. The ladder already walks to pods; it does not pre-move to an inbound tile during the 120-tick descent.
- **`death_fireworks` carries `pos` arena-wide.** Death loot is a public ping. The ladder only uses the event to decrement `aliveEstimate`.
- **`channeling` / `netted` / `poisoned` / `hand` are public on visible agents.** A first-aid channel is a 48-tick interrupt (any damage, `sim.nim:867–869`); poison pulses every 24t so a dart *also* denies the kit for the whole poison timer. The ladder never targets a channeler or a netted body.
- **`hp_band`**: healthy >66, hurt 33–66, critical <33. Combined with last-damager kill credit, a visible critical is a cheap finish — and the code path already exists (`aggression >= 5`) but is dead at the current knob.
- PRNG is xoshiro256** from a 64-bit match seed (`prng.nim`). Dodge/forage/move-contest draws are not a practical seed crack from the player socket; seed is not in `player_config`.

### Candidate changes (ranked by expected impact)

1. **Alloc 10/1/5/4** — highest EV, math above. Implemented.
2. **`aggression = 5`** — enables the already-written branch `enemyCritical and dist <= weaponRange and aggression >= 5`. Today we only finish *adjacent* criticals (`d2 <= 2`). Bow/knives/blowgun then actually shoot a tagged-down target instead of spacing off it. Deployed scoring: +1 kill; both scorings: one fewer agent who can heal and re-engage. One constant.
3. **Pack `use` swap when `weaponRank(pack[i]) > weaponRank(hand)`.** Pickup puts a second weapon in the pack and the ladder never wields it — terminal burn and the cornered-swing case then punch with fists (3–4 dmg) while a sword sits unused. Same-tick placement tiebreak is `damageDealt`.

Not in this pass: ranged kite (bow at range 8, 2 tiles/tick) is the next behavior rewrite once the weapon is actually in hand; intercept inbound pods during descent; path to `death_fireworks.pos`.

## Experiment log

| # | idea | change | XP id | opponents | verdict |
|---|------|--------|-------|-----------|---------|
| 1 | speed-max build from sim study | 7/3/5/5 -> 10/1/5/4 | xreq_119c5f70 | top-3 field, 16 seats, 12 paired eps | KEEP: v2 8.92 vs v1 5.08, 9/12 wins, t=2.38 (p~.036); promoted to champion |
| 2 | intercept inbound pods on 120-tick descent | loot targets inbound pods (not only landed); hold landing tile so spacing does not step off |  |  |  |
