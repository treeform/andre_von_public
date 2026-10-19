# Pudge Wars field report: myasnik v3 vs the league leaders

Twelve hosted-XP replays (League 3v3, kill goal 10, 15360 max ticks,
fog on) with `myasnik:v3` seated with and against
`co-gas-pudge-blind-hook-{richard,relhalpha}:v1` ("blind-hook"),
`pudge-wars-camper:v3` ("camper", Aaron's Optimizer Jr) and
`pudge-wars-idle:v3` ("idle"). Every tape was re-simulated with the
vendored engine (`sims/pudge-wars`, physics v25) by
`games/pudge-wars/tools/replay_stats.nim`; all twelve replays check
out with **zero hash mismatches**, so every number below is exact
engine state, not an estimate.

Regenerate:

    nim r --hints:off games/pudge-wars/tools/replay_stats.nim \
      --eps <scratch>/eps/myasnik_v3.json --out <scratch>/pudge_stats.json \
      --table <scratch>/replays/pudge/*.replay.gz

## How to read the stats

Score per seat is `0.5 + 0.5 * (team kills - enemy kills) / 10`, so it
is a *team* number. Individual contribution is kill minus death. Three
engine facts drive most of what follows (all from `sim.nim` /
`replays.nim` v18+):

- **Walking never crosses the waterline.** A butcher dumped in the
  river (or reeled onto the far bank) stays there until a hook moves
  it. River time and enemy-bank time are therefore *stranded* time,
  not a choice. The river drowns 10 HP every half second.
- **A reeled victim is dropped one tile in front of the hooker, along
  the chain.** A hooker standing at the bank edge drops victims into
  the water (stuck, drowning, lit for both teams); a hooker 12 tiles
  inland drops them on dry home land where they walk freely.
- **Any hook on a butcher that is already on a chain is an instant
  kill ("headshot") regardless of who holds the chain.** A rescue hook
  from an ally makes the rescued ally executable for the whole reel.
- Sight: your whole bank plus the river are always lit; the enemy bank
  needs a living teammate within 20 tiles. Hook range is 56 tiles, the
  river is 23 wide, so a hook from either waterline reaches every tile
  of the far bank; depth buys no range safety, only fog.

## Per-game outcomes

| episode | ticks | west | east | winner | myasnik seat | myasnik score | myasnik K/D |
|---|---:|---:|---:|---|---:|---:|---|
| ereq_1d8f466b | 7013 | 10 | 9 | west | 2 | 0.55 | 5/5 |
| ereq_320465f7 | 6327 | 6 | 10 | east | 1 | 0.30 | 2/4 |
| ereq_3820535c | 8462 | 10 | 9 | west | 1 | 0.55 | 3/3 |
| ereq_39e604c5 | 5161 | 7 | 10 | east | 4 | 0.65 | 3/3 |
| ereq_3e193006 | 6673 | 5 | 10 | east | 5 | 0.75 | 1/3 |
| ereq_3e5789cb | 5803 | 6 | 10 | east | 5 | 0.70 | 2/2 |
| ereq_593003b8 | 4899 | 7 | 10 | east | 0 | 0.35 | 2/2 |
| ereq_5b0adfd7 | 3832 | 10 | 6 | west | 2 | 0.70 | 4/3 |
| ereq_7bb631a3 | 6941 | 10 | 9 | west | 3 | 0.45 | 1/2 |
| ereq_80361683 | 7439 | 10 | 9 | west | 0 | 0.55 | 6/2 |
| ereq_dcbd352e | 6589 | 10 | 8 | west | 3 | 0.40 | 0/4 |
| ereq_f6f46844 | 6668 | 10 | 9 | west | 4 | 0.45 | 2/3 |

Every game ended on the kill goal (2.0-4.4 minutes). Myasnik's score
in these twelve (0.533) is its league mean, but note the team effect:
in the same games the blind-hook seats averaged 0.516 and the campers
0.477, because scoring is shared with idle teammates. The honest
per-seat comparison is the kill/death ledger below.

## Group comparison (mean per seat-game)

| stat | myasnik | blind-hook | camper | idle |
|---|---:|---:|---:|---:|
| seat-games | 12 | 29 | 15 | 16 |
| mean league score | 0.533 | 0.516 | 0.477 | 0.469 |
| kills / game | 2.58 | 3.34 | 2.93 | 2.38 |
| deaths / game | 3.00 | 3.52 | 2.13 | 2.50 |
| **kill - death / game** | **-0.42** | **-0.17** | **+0.80** | -0.12 |
| deaths by headshot | 2.00 (67%) | 1.90 (54%) | 1.67 (78%) | 2.12 (85%) |
| ... while enemy-held | 1.50 | 1.21 | 0.87 | 1.00 |
| ... while ally-held (rescue chain) | 0.50 | 0.69 | 0.80 | 1.12 |
| deaths by hook damage | 0.83 (28%) | 1.14 (32%) | 0.40 (19%) | 0.25 (10%) |
| deaths by drown | 0.17 (6%) | 0.45 (13%) | 0.07 (3%) | 0.06 (2%) |
| deaths by melee / rot / other | 0 | 0.03 / 0 / 0 | 0 | 0.06 / 0 / 0 |
| deaths in river | 53% | 56% | 53% | 55% |
| deaths on enemy bank | 31% | 30% | 28% | 30% |
| kills by headshot | 1.33 (52%) | 2.34 (70%) | 1.73 (59%) | 1.75 (74%) |
| ... on victims held by their own ally | 0.50 | 1.07 | 0.53 | 0.69 |
| ... on victims held by our team | 0.83 | 1.28 | 1.20 | 1.06 |
| kills by hook damage | 0.75 (29%) | 0.59 (18%) | 1.07 (36%) | 0.69 (29%) |
| kills by drown | 0.17 (6%) | 0.34 (10%) | 0.13 (5%) | 0.19 (8%) |
| kills by melee | 0.17 (6%) | 0 | 0 | 0 |
| hooks thrown / game | 82.5 | 88.6 | 91.4 | 87.9 |
| hooks thrown / min | 25.1 | 26.6 | 27.4 | 27.6 |
| enemy latches / game (rate) | 22.7 (27%) | 28.0 (32%) | 26.5 (29%) | 23.4 (27%) |
| headshots landed / game | 1.58 | 2.45 | 2.00 | 1.75 |
| ally latches / game | 27.9 | 19.6 | 33.3 | 36.1 |
| ally rescues / game (ally was chained or swimming) | 8.25 | 10.45 | 11.47 | 11.25 |
| **blind hooks / game** | **44.3** | **24.1** | **19.9** | 21.4 |
| blind hooks / min | 13.5 | 7.2 | 6.0 | 6.7 |
| blind fraction of throws | 54% | 27% | 22% | 24% |
| blind -> enemy latch rate | 16% | 15% | 13% | 8% |
| **blind -> ally latch rate** | **38%** | **12%** | 38% | 49% |
| targeted -> enemy latch rate | 41% | 37% | 33% | 32% |
| targeted -> ally latch rate | 29% | 26% | 36% | 38% |
| mean aim distance (tiles) | 27.2 | 23.5 | 27.8 | 29.6 |
| mean targeted enemy distance (tiles) | 20.5 | 20.8 | 19.4 | 20.3 |
| mean blind aim distance (tiles) | 31.7 | 27.5 | 57.2 | 57.6 |
| blind aim point vs own waterline (tiles, negative = across) | -16.0 | -23.7 | -45.2 | -46.1 |
| water distance at throw (tiles, + = inland) | -0.1 | -1.7 | +0.6 | +0.6 |
| **hooked by enemy / game** | **28.2** | 26.9 | **21.2** | 17.1 |
| nearest enemy when hooked (tiles) | 16.1 | 12.2 | 11.3 | 11.8 |
| hooker distance when hooked (tiles) | 18.4 | 15.2 | 14.7 | 14.8 |
| hooked by ally / game | 18.9 | 25.5 | 33.9 | 31.4 |
| time on a chain (alive ticks) | 8% | 9% | 9% | 8% |
| alive fraction | 94% | 93% | 96% | 95% |
| **deep post (> 6 tiles inland)** | **55%** | **7%** | **17%** | 17% |
| **bank edge (0-6 tiles inland)** | **8%** | **43%** | **44%** | 43% |
| river (alive ticks) / while unchained | 22% / 18% | 42% / 37% | 34% / 30% | 34% / 30% |
| **enemy bank / while unchained** | **15% / 14%** | 8% / 7% | 6% / 4% | 5% / 4% |
| below 40% HP | 8% | 10% | 5% | 6% |
| mean water distance (tiles) | -1.1 | -2.0 | +0.4 | +0.3 |
| damage dealt / taken per game | 4052 / 4266 | 4677 / 5108 | 4254 / 4067 | 3588 / 4109 |

Myasnik per game (seat, K/D, thrown, blind, blind-on-ally, ally
latches, rescues, hooked by enemy, deep / edge / stranded-on-enemy-bank
fractions):

| episode | seat | K/D | thrown | blind | blind->ally | ally latches | rescues | hooked | deep | edge | enemy bank |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1d8f466b | 2 | 5/5 | 92 | 39 | 20 | 40 | 13 | 27 | 70% | 14% | 1% |
| 320465f7 | 1 | 2/4 | 84 | 49 | 23 | 36 | 5 | 35 | 70% | 7% | 3% |
| 3820535c | 1 | 3/3 | 103 | 42 | 17 | 31 | 8 | 33 | 41% | 4% | 40% |
| 39e604c5 | 4 | 3/3 | 67 | 40 | 17 | 28 | 8 | 16 | 59% | 9% | 13% |
| 3e193006 | 5 | 1/3 | 92 | 49 | 19 | 34 | 8 | 33 | 62% | 6% | 7% |
| 3e5789cb | 5 | 2/2 | 79 | 44 | 15 | 24 | 9 | 25 | 49% | 6% | 18% |
| 593003b8 | 0 | 2/2 | 65 | 43 | 13 | 20 | 5 | 23 | 44% | 10% | 20% |
| 5b0adfd7 | 2 | 4/3 | 50 | 29 | 11 | 19 | 4 | 10 | 66% | 12% | 12% |
| 7bb631a3 | 3 | 1/2 | 91 | 59 | 24 | 38 | 12 | 23 | 41% | 8% | 19% |
| 80361683 | 0 | 6/2 | 91 | 55 | 8 | 10 | 2 | 38 | 65% | 3% | 22% |
| dcbd352e | 3 | 0/4 | 86 | 42 | 22 | 34 | 18 | 26 | 41% | 7% | 0% |
| f6f46844 | 4 | 2/3 | 90 | 41 | 11 | 21 | 7 | 36 | 60% | 14% | 1% |

## The three biggest behavioural gaps

### 1. We post 12 tiles inland; the leaders live on the waterline

Myasnik spends 55% of its life more than 6 tiles inland and 8% on
the bank strip. The camper (best ledger, +0.80/game) is the mirror
image: 17% deep, 44% on the edge; blind-hook is 7% / 43%. Depth buys
nothing against hooks (56-tile range covers the whole map from
either waterline) and costs four things the stats show directly:

- **Fewer executions.** From x=41 our 20-tile sight ends at x=61, the
  near third of the river. Chained enemies being reeled or rescued
  through the far river are invisible to us. Kills by headshot: 1.33
  vs 2.34 (blind-hook) and 1.73 (camper); on enemies held by their own
  rescuer 0.50 vs 1.07.
- **Our victims land on dry land.** Our landing point is 12 tiles
  inland, so a latched enemy is dropped on our bank, free to walk and
  easy for his allies to pull home. Edge hookers drop victims in the
  water: kills by drown 0.17 vs 0.34, hook-finish kills 0.75 vs 1.07
  (camper).
- **Our hook corridor crosses our own team.** Every throw from the deep
  post flies over the bank and river where our allies stand or are
  stranded: 38% of blind throws and 29% of targeted throws latch an
  ally (blind-hook: 12% / 26%). Only 8.25 of our 27.9 ally latches are
  rescues; the other 19.7 drag a healthy ally to our post and make him
  executable for the reel.
- **Stranded teammates are invisible to us.** A deep teammate cannot
  see (and so cannot rescue) an ally dumped in the far river or on the
  enemy bank. Myasnik itself spends 14% of its unchained life stranded
  on the enemy bank (leaders 4-7%), where its own code kites *away*
  from the water, and 31% of its deaths happen there.

Leaders throw from the water's edge: water distance at throw is -1.7
(blind-hook, standing in the shallows) and +0.6 (camper); ours is
-0.1 only because we throw mostly after being dragged off the post.

### 2. We throw twice as many blind hooks, and aim them at the river

Blind throws (no visible living enemy within 4 tiles of the flight
line): myasnik 44.3 per game, 13.5 per minute, 54% of all throws.
Leaders: 24.1 / 7.2 / 27% (blind-hook), 19.9 / 6.0 / 22% (camper).
The enemy latch rate of a blind throw is the same for everyone
(13-16%), so our extra 20 blind hooks buy ~3 enemy latches per game
but also ~8 ally grabs, each a 2-second cooldown spent and an ally
put on a chain.

Where they aim differs too. Our blind aim point sits on average 16
tiles past our own waterline, i.e. the far half of the river, where
stranded allies drift. Blind-hook aims at -23.7 (the enemy waterline,
where campers stand) and the campers at -45 (a full-range lane sweep
of the enemy bank from the edge). Blind hooks from the edge sweep the
enemy bank; blind hooks from a deep post sweep our own bank first.

### 3. We get hooked more, from farther away, and die on the chain

Hooked by an enemy 28.2 times per game (camper 21.2, idle 17.1) with
the nearest enemy 16 tiles away and the hooker 18.4 tiles away
(leaders ~12 and ~15). Those are long blind throws landing on a
predictable, fixed post: `riverWest - 12` on the spawn lane. Once
chained, 1.50 of our 3.00 deaths per game are the second enemy chain
(camper 0.87), and hook-damage finishes take another 0.83 (camper
0.40) because we sit below 40% HP 8% of the time (camper 5%). The
camper stands more exposed yet is hooked less: it is not depth that
avoids chains, it is movement and not standing on the lane line.

## Ranked single-change experiments for myasnik

1. **Post on the bank edge instead of 12 tiles deep** (`standoff` 12
   -> ~1.5, keep the lane assignment and juke, keep the no-water
   rule). Expected moves: deep fraction 55% -> <=20%, bank edge 8% ->
   >=40%; kills by headshot 1.33 -> >=1.9 (full-river sight of chained
   enemies); kills by drown 0.17 -> ~0.35 and hook-finish kills 0.75 ->
   ~1.0 (victims dumped in the water); ally rescues 8.25 -> ~11 (we can
   see stranded allies); blind -> ally latch rate 38% -> <=20% (fewer
   allies inside the corridor); enemy-bank stranded time 14% -> <=7%.
   Guard rail: hooked-by-enemy per game must not exceed the current 28.

2. **Reel-aware execution shots.** Treat any enemy with `hooked` true
   (held by our team *or* by his own rescuer) as the top target, and
   lead him along the reel: the victim moves in a straight line to the
   holder at the chain's peak speed (up to 1.8 tiles/tick) and is
   dropped one tile in front of the holder. Fire only when our chain's
   windup (9 ticks) plus flight beats the remaining reel; otherwise aim
   at the drop point for the immediate follow-up. Expected moves:
   headshots landed 1.58 -> ~2.4 per game, headshot kills on
   rescuer-held victims 0.50 -> ~1.0, kills by headshot share 52% ->
   ~65%. Mostly independent of (1) but sees far more targets with it.

3. **Blind-throw discipline: corridor must be ally-free, aim at the
   enemy waterline, cap the cadence.** Skip a blind throw whenever a
   living ally lies within 4 tiles of the flight line; aim blind
   throws at the mirrored bank edge (about 24 tiles past our waterline,
   where the campers stand) rather than last-seen river points; hold
   blind throws to ~7 per minute so the cooldown is free when a real
   target appears. Expected moves: blind hooks 44 -> <=25 per game,
   blind -> ally latch rate 38% -> <=15%, ally latches 28 -> <=15 with
   rescues held at >=8, teammates' headshot deaths while ally-held
   trending down; enemy latches per game should hold at ~22 as
   targeted throws take over the cooldown budget.

Run each as its own version and judge only on hosted XP requests
(never local games), reading the per-seat kill-death ledger and the
target stats above out of `replay_stats.nim`, not the team score.

## Caveats

- Twelve seat-games for myasnik is a small sample; per-game K/D swings
  from 0/4 to 6/2. Group means for the leaders rest on 29 and 15
  seat-games. Treat gaps under ~20% as noise; the position, blind-hook
  and headshot gaps are 2-8x and consistent in every game.
- "Blind" is a geometric definition (no visible enemy within 4 tiles
  of the aim ray, using the host's exact fog rule at the throw tick).
  A throw led far ahead of a fast-moving visible enemy can be
  classified blind; a throw at a last-seen position that happens to
  line up with a visible enemy counts as targeted.
- Death causes come from state transitions, not an engine log:
  headshot = victim was chained last tick and an enemy has
  `justHeadshot`; hook = victim's grab flag this tick; melee = an
  enemy landed a swing on it; drown = died in (or just out of) the
  water with no other hit. Rot and "other" never occurred. 3.9% of
  engine latches could not be attributed to a victim (a second hook
  re-latched the same butcher in the same tick) and are reported as
  `unattributedLatches`; `hooksThrown` and `headshots` match the
  engine counters exactly (asserted).
- Ally latches include intentional rescues; only latches on an ally
  who was chained or swimming the previous tick are counted as
  rescues.
- Scores are team scores; the 0.60 league means for the leaders come
  from a different opponent mix than these twelve requests, and in
  these games idle teammates dragged the leaders' scores below ours.
  Per-seat kill minus death is the comparison that carries over.
- The tool re-simulates with the vendored engine at physics v25, the
  same version stamped in the tapes; if the league image moves on,
  `hashMismatches` in the JSON will say so and stats after the first
  mismatch tick become approximate.
