# zhar v48 vs the current top three

140 replays re-simulated with the hosted engine rules (103 state-hash mismatches, 0 replays without a roster skipped). Columns are policy versions, ordered by glory per game. Replay rows are means over the policy's seat-games unless noted.

The first column is ours (zhar:v48). Gap = (ours - rivals' mean) / rivals' mean. A row is flagged when the gap is at least 25% (and, for % rows, at least 2 points).

## 1. Controlled directly: movement, footwork, aiming, shooting

| stat | unit | zhar:v48 | xolod:v2 | daveey-pw-neural:v36 | eider:v7 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| friendly damage | /cog | 0.88 | 0.62 | 0.48 | 0.52 | 0.54 | 63% | we are higher |
| enemy in view | % | 49.0 | 50.8 | 47.1 | 38.9 | 45.6 | 8% |  |
| gun shots | /min | 21.8 | 18.3 | 28.9 | 23.2 | 23.5 | -7% |  |
| gun accuracy | % | 35.7 | 42.3 | 24.4 | 27.5 | 31.4 | 13% |  |
| first shot | s | 6.5 | 6.4 | 3.4 | 3.2 | 4.3 | 50% | we are higher |
| shots with no enemy in view | % | 23.0 | 23.6 | 25.6 | 27.0 | 25.4 | -9% |  |
| accuracy with no enemy in view | % | 25.9 | 26.6 | 20.9 | 15.9 | 21.1 | 22% |  |
| range under 20 m | % | 7.7 | 7.1 | 12.4 | 8.1 | 9.2 | -16% |  |
| accuracy 0-10 m | % | 43.5 | 55.5 | 30.0 | 51.3 | 45.6 | -5% |  |
| accuracy 10-20 m | % | 45.9 | 57.1 | 26.8 | 37.1 | 40.3 | 14% |  |
| accuracy 20-30 m | % | 42.9 | 54.5 | 25.5 | 34.5 | 38.2 | 12% |  |
| accuracy 30-45 m | % | 42.5 | 55.1 | 27.0 | 32.3 | 38.1 | 11% |  |
| accuracy 45+ m | % | 34.5 | 41.1 | 24.3 | 29.4 | 31.6 | 9% |  |
| shots fired standing | % | 100.0 | 100.0 | 100.0 | 81.4 | 93.8 | 7% |  |
| accuracy standing | % | 38.6 | 47.2 | 25.6 | 36.4 | 36.4 | 6% |  |
| accuracy moving | % | — | — | 0.0 | 12.0 | 6.0 | — |  |
| shots from above | % | 42.5 | 41.8 | 41.5 | 23.4 | 35.5 | 20% |  |
| accuracy from above | % | 42.2 | 54.4 | 26.9 | 36.7 | 39.3 | 7% |  |
| accuracy level | % | 38.8 | 41.1 | 24.4 | 31.0 | 32.1 | 21% |  |
| accuracy from below | % | 33.6 | 42.6 | 25.1 | 30.0 | 32.6 | 3% |  |
| hits from high ground | % | 49.7 | 50.3 | 45.6 | 33.6 | 43.1 | 15% |  |
| hits from trench | % | 0.8 | 0.4 | 2.4 | 0.4 | 1.1 | -22% |  |
| miss: cover in the way | % | 7.6 | 17.5 | 3.9 | 21.3 | 14.2 | -46% | we are lower |
| miss: target moved off the line | % | 31.7 | 12.4 | 49.6 | 30.1 | 30.7 | 3% |  |
| miss: aim off a still target | % | 3.3 | 4.7 | 0.8 | 2.4 | 2.7 | 26% |  |
| miss: in radius, no hit | % | 14.2 | 13.8 | 11.8 | 11.0 | 12.2 | 16% |  |
| miss: teammate in the way | % | 2.2 | 1.8 | 1.6 | 2.0 | 1.8 | 21% |  |
| miss: nobody near the line | % | 2.4 | 2.5 | 6.7 | 1.4 | 3.5 | -33% |  |
| speed | m/s | 5.28 | 5.45 | 5.01 | 5.54 | 5.34 | -1% |  |
| moving | % | 84.6 | 86.5 | 78.5 | 87.2 | 84.1 | 1% |  |
| wading | % | 1.1 | 0.9 | 0.0 | 0.0 | 0.3 | 240% |  |
| sneaking | % | 6.4 | 5.6 | 0.3 | 5.4 | 3.8 | 70% | we are higher |
| in trench | % | 1.0 | 0.5 | 2.8 | 0.3 | 1.2 | -15% |  |
| high ground | % | 40.4 | 40.8 | 41.4 | 33.3 | 38.5 | 5% |  |
| exact compass steps | % | 6.5 | 6.6 | 58.7 | 6.1 | 23.8 | -73% | we are lower |
| nearest teammate | m | 12.2 | 12.1 | 7.8 | 10.5 | 10.1 | 20% |  |
| lead on a moving target | ticks | 1.5 | 4.7 | 0.0 | 2.2 | 2.3 | -37% | we are lower |
| sight run length | ticks | 7.9 | 8.3 | 5.2 | 2.8 | 5.4 | 47% | we are higher |
| new sightings | /min | 149.8 | 143.4 | 203.7 | 342.5 | 229.8 | -35% | we are lower |
| shots at a target in view | % | 99.5 | 98.8 | 99.9 | 98.7 | 99.1 | 0% |  |
| shots at a tracked target | % | 40.7 | 98.7 | 37.4 | 38.6 | 58.3 | -30% | we are lower |
| unled shots at movers | % | 70.6 | 3.4 | 99.9 | 62.2 | 55.2 | 28% | we are higher |
| standing with an enemy in sight | % | 21.5 | 18.5 | 29.8 | 18.9 | 22.4 | -4% |  |
| run length in sight | ticks | 6.4 | 6.4 | 2.6 | 2.0 | 3.7 | 74% | we are higher |
| runs ended by reversing | % | 29.5 | 38.3 | 62.1 | 80.4 | 60.3 | -51% | we are lower |
| direction changes in sight | /s | 1.27 | 1.36 | 3.39 | 5.00 | 3.25 | -61% | we are lower |
| in a heart ring | % | 3.8 | 3.4 | 2.0 | 2.6 | 2.7 | 44% |  |
| walk orders | % | 100.0 | 100.0 | 100.1 | 100.1 | 100.0 | 0% |  |
| shoot orders | % | 1.5 | 1.3 | 3.8 | 1.7 | 2.3 | -32% |  |
| direct walks | % | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | — |  |
| grenade charging | % | 0.1 | 0.1 | 0.0 | 0.1 | 0.1 | 71% |  |

## 2. Controlled indirectly: items picked up and used

| stat | unit | zhar:v48 | xolod:v2 | daveey-pw-neural:v36 | eider:v7 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| grenades picked | /cog | 1.83 | 1.94 | 0.12 | 1.68 | 1.24 | 47% | we are higher |
| grenades thrown | /cog | 0.28 | 0.33 | 0.00 | 0.14 | 0.15 | 79% | we are higher |
| grenade hits | /throw | 0.25 | 0.21 | — | 0.20 | 0.20 | 22% |  |
| spray cans | /cog | 0.18 | 0.21 | 0.02 | 0.15 | 0.13 | 43% | we are higher |
| spray bursts | /cog | 0.04 | 0.05 | 0.00 | 0.01 | 0.02 | 85% | we are higher |
| armor | /cog | 0.07 | 0.14 | 0.23 | 0.25 | 0.21 | -64% | we are lower |
| medkits | /cog | 0.55 | 0.59 | 0.00 | 0.30 | 0.30 | 88% | we are higher |
| glory hearts | /cog | 0.16 | 0.15 | 0.09 | 0.38 | 0.20 | -19% |  |
| uniforms | /cog | 0.07 | 0.05 | 0.00 | 0.01 | 0.02 | 233% | we are higher |

## 3. Outcomes: winning, killing, dying, territory

| stat | unit | zhar:v48 | xolod:v2 | daveey-pw-neural:v36 | eider:v7 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| games |  | 140 | 60 | 40 | 40 | 47 | 200% | we are higher |
| win rate | % | 67.1 | 75.0 | 2.5 | 0.0 | 25.8 | 160% | we are higher |
| draw rate | % | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | — |  |
| glory per game |  | 369 | 411 | 20 | 0 | 144 | 157% | we are higher |
| glory per win |  | 550 | 548 | 794 | — | 671 | -18% |  |
| match length | s | 106 | 108 | 111 | 99 | 106 | 0% |  |
| deaths | /cog | 3.14 | 3.13 | 3.98 | 4.00 | 3.71 | -15% |  |
| lives left | /cog | 1.36 | 1.39 | 0.03 | 0.00 | 0.47 | 188% | we are higher |
| first death | s | 31.6 | 32.6 | 20.7 | 32.2 | 28.5 | 11% |  |
| deaths in water | % | 3.6 | 2.5 | 0.2 | 0.2 | 0.9 | 284% | we are higher |
| deaths in trench | % | 1.6 | 0.7 | 0.4 | 0.5 | 0.5 | 213% |  |
| damage taken | /cog | 9.34 | 9.66 | 11.48 | 11.78 | 10.98 | -15% |  |
| kills | /cog | 3.40 | 3.51 | 2.51 | 2.02 | 2.68 | 27% | we are higher |
| kill/death |  | 1.08 | 1.12 | 0.63 | 0.51 | 0.75 | 44% | we are higher |
| damage dealt | /cog | 10.79 | 11.15 | 8.48 | 7.47 | 9.03 | 19% |  |
| gun kills | % | 97.0 | 96.8 | 100.0 | 98.0 | 98.3 | -1% |  |
| grenade kills | % | 2.0 | 1.9 | 0.0 | 1.4 | 1.1 | 85% |  |
| spray kills | % | 0.9 | 1.3 | 0.0 | 0.6 | 0.6 | 48% |  |
| captures | /cog | 0.44 | 0.41 | 0.07 | 0.33 | 0.27 | 59% | we are higher |

## Largest gaps in what we control (groups 1 and 2)

| stat | unit | ours | rivals' mean | gap | xolod:v2 / daveey-pw-neural:v36 / eider:v7 |
|---|---|---:|---:|---:|---|
| uniforms | /cog | 0.07 | 0.02 | 233% | 0.05 / 0.00 / 0.01 |
| medkits | /cog | 0.55 | 0.30 | 88% | 0.59 / 0.00 / 0.30 |
| spray bursts | /cog | 0.04 | 0.02 | 85% | 0.05 / 0.00 / 0.01 |
| grenades thrown | /cog | 0.28 | 0.15 | 79% | 0.33 / 0.00 / 0.14 |
| run length in sight | ticks | 6.4 | 3.7 | 74% | 6.4 / 2.6 / 2.0 |
| exact compass steps | % | 6.5 | 23.8 | -73% | 6.6 / 58.7 / 6.1 |
| sneaking | % | 6.4 | 3.8 | 70% | 5.6 / 0.3 / 5.4 |
| armor | /cog | 0.07 | 0.21 | -64% | 0.14 / 0.23 / 0.25 |
| friendly damage | /cog | 0.88 | 0.54 | 63% | 0.62 / 0.48 / 0.52 |
| direction changes in sight | /s | 1.27 | 3.25 | -61% | 1.36 / 3.39 / 5.00 |
| runs ended by reversing | % | 29.5 | 60.3 | -51% | 38.3 / 62.1 / 80.4 |
| first shot | s | 6.5 | 4.3 | 50% | 6.4 / 3.4 / 3.2 |
| grenades picked | /cog | 1.83 | 1.24 | 47% | 1.94 / 0.12 / 1.68 |
| sight run length | ticks | 7.9 | 5.4 | 47% | 8.3 / 5.2 / 2.8 |
| miss: cover in the way | % | 7.6 | 14.2 | -46% | 17.5 / 3.9 / 21.3 |
| spray cans | /cog | 0.18 | 0.13 | 43% | 0.21 / 0.02 / 0.15 |
| lead on a moving target | ticks | 1.5 | 2.3 | -37% | 4.7 / 0.0 / 2.2 |
| new sightings | /min | 149.8 | 229.8 | -35% | 143.4 / 203.7 / 342.5 |
| shots at a tracked target | % | 40.7 | 58.3 | -30% | 98.7 / 37.4 / 38.6 |
| unled shots at movers | % | 70.6 | 55.2 | 28% | 3.4 / 99.9 / 62.2 |
