# Gods of the Arena diagnostics, 2026-09-24

Engine: polyworld 2ff0fc0 (hosted build cow_3936705e) with bassy b25e0ef.
Tool: tools/gota_diag.nim (build and flags in tools/readme.md). HTML version with stage definitions: diagnostics_2026-09-24.html.
Each stage cell is the mean of 9 runs (Arcanist, Crossbowman, Berserker by 3 seeds); each hero cell 3 runs.
Columns are the ten kept khors versions, newest first, then one-trick (a separate tiny script per row from diag/tricks).

## Stages

| stage | v189 | v180 | v177 | v114 | v102 | v92 | v90 | v62 | v56 | v47 | one-trick |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **total** | **69** | **69** | **69** | **69** | **70** | **70** | **73** | **71** | **75** | **69** | **93** |
| creep clear, no damage | 91 | 91 | 91 | 91 | 91 | 91 | 91 | 91 | 91 | 83 | 92 |
| last hits in a lane clash | 94 | 94 | 94 | 94 | 94 | 94 | 94 | 96 | 96 | 76 | 92 |
| creep pull into a wave stack | 25 | 25 | 25 | 25 | 25 | 25 | 25 | 25 | 25 | 56 | 61 |
| tower kill with creep support | 69 | 69 | 69 | 69 | 69 | 69 | 69 | 16 | 68 | 48 | 100 |
| no tower tanking | 82 | 82 | 82 | 82 | 82 | 82 | 82 | 100 | 100 | 85 | 100 |
| jungle camp clear | 96 | 96 | 96 | 96 | 96 | 96 | 96 | 96 | 96 | 69 | 94 |
| potion survival under creeps | 62 | 62 | 62 | 62 | 62 | 62 | 89 | 98 | 98 | 97 | 100 |
| escape a two-hero gank | 20 | 20 | 20 | 20 | 20 | 20 | 29 | 22 | 22 | 88 | 100 |
| 1v1 duel vs base.bas | 78 | 78 | 78 | 78 | 100 | 100 | 89 | 100 | 100 | 39 | 44 |
| execute a fleeing hero | 92 | 92 | 92 | 92 | 94 | 94 | 94 | 90 | 90 | 89 | 91 |
| track a hero into fog | 38 | 38 | 38 | 38 | 38 | 38 | 38 | 21 | 38 | 21 | 100 |
| avoid a hidden group | 50 | 50 | 50 | 50 | 50 | 50 | 80 | 80 | 80 | 94 | 100 |
| dodge telegraphed meteors | 22 | 22 | 22 | 22 | 22 | 22 | 23 | 23 | 23 | 85 | 100 |
| burst an idle hero | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 |
| kill an exposed god | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 0 | 100 |
| defend a pushed tower | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 100 |
| recall and heal | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 |
| spend gold in the keep | 89 | 89 | 89 | 89 | 89 | 89 | 89 | 89 | 89 | 78 | 100 |
| spend ability points | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 | 100 |


## Heroes: abilities used correctly

Level 7, 60% health, full mana, 4 tiles from an unkillable Vanguard that holds its tile, 20 s. Per ability: correct casts per cast (a hit, a heal of missing health, or a restore of missing mana), 0 if never cast; the row is the mean of Q, W, E and R.

| hero | v189 | v180 | v177 | v114 | v102 | v92 | v90 | v62 | v56 | v47 | one-trick |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Vanguard Knight | 50 | 50 | 50 | 50 | 75 | 75 | 75 | 75 | 75 | 83 | 100 |
| Ranger | 75 | 75 | 75 | 75 | 75 | 75 | 75 | 75 | 75 | 100 | 100 |
| Arcanist | 75 | 75 | 75 | 75 | 75 | 75 | 75 | 75 | 75 | 100 | 100 |
| Druid Warden | 50 | 50 | 50 | 50 | 50 | 50 | 50 | 50 | 50 | 75 | 100 |
| Demon Hunter | 50 | 50 | 50 | 50 | 75 | 75 | 75 | 75 | 75 | 100 | 100 |
| Death Knight | 44 | 44 | 44 | 44 | 75 | 75 | 75 | 75 | 75 | 100 | 100 |
| Crossbowman | 50 | 50 | 50 | 50 | 50 | 50 | 50 | 50 | 50 | 75 | 100 |
| Lich | 75 | 75 | 75 | 75 | 75 | 75 | 75 | 75 | 75 | 75 | 100 |
| Warlock | 58 | 58 | 58 | 58 | 58 | 58 | 58 | 58 | 58 | 58 | 100 |
| Berserker | 50 | 50 | 50 | 50 | 75 | 75 | 75 | 75 | 75 | 97 | 100 |

## What the tables say

- The fighter line (v56 on) is a strong attacker: last hits, camps, bursts, god kills and duels are at or near the top.
- Every khors version since v56 fails the survival instincts: it charges a visible three-hero group, fights a two-hero gank instead of leaving, and stands in telegraphed meteors. khors has no warning-dodge code.
- khors never defends a pushed tower (0 for every version) and never pulls a camp into its wave.
- Heroes table: no khors version since v56 ever casts Q (the "passive" slot is castable for every class), so each hero caps at 75.
- Heroes table: from v114 on, the melee heroes (Vanguard, Demon Hunter, Death Knight, Berserker) never cast W. The order-hygiene range gate added in v114 blocks their melee-range ability, which is why v114 also lost duels.
- Heroes table: the Druid's Golem Seed and the Crossbowman's Clockwork Charge ultimates are never cast by any khors version.
- v92's retreat at 15% (from 24%) shows in potion survival and the hidden group.
- v177, v180 and v189 are identical here: their changes (heroes over creeps, scan radius, draft) do not touch these stages.
- The one-trick column runs a separate tiny script per row, written only to pass that row. It reaches 100 on 13 of 19 stages and on all 10 heroes. Still short: the mirror duel against base.bas (a coin flip for a simple script), the creep pull (a high camp kills half the held wave), and a few points of unavoidable damage or contested kills in creep clear, camp clear, last hits and the Berserker execute.
