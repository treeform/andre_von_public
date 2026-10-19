# hosted 0.3.110: zhar v53 vs xolod v12 (80 games)

80 replays re-simulated with the hosted engine rules (0 state-hash mismatches, 160 replays without a roster skipped). Columns are policy versions, ordered by glory per game. Replay rows are means over the policy's seat-games unless noted.

The first column is ours (zhar:v53). Gap = (ours - rivals' mean) / rivals' mean. A row is flagged when the gap is at least 25% (and, for % rows, at least 2 points).

## 1. Controlled directly: movement, footwork, aiming, shooting

| stat | unit | zhar:v53 | xolod:v12 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---|
| friendly damage | /cog | 0.75 | 0.62 | 0.62 | 19% |  |
| enemy in view | % | 51.6 | 51.3 | 51.3 | 1% |  |
| gun shots | /min | 21.1 | 18.1 | 18.1 | 16% |  |
| gun accuracy | % | 33.8 | 38.2 | 38.2 | -12% |  |
| first shot | s | 6.9 | 9.0 | 9.0 | -23% |  |
| shots with no enemy in view | % | 22.3 | 23.5 | 23.5 | -5% |  |
| accuracy with no enemy in view | % | 22.3 | 23.7 | 23.7 | -6% |  |
| range under 20 m | % | 8.9 | 8.5 | 8.5 | 5% |  |
| accuracy 0-10 m | % | 48.7 | 58.1 | 58.1 | -16% |  |
| accuracy 10-20 m | % | 46.4 | 51.5 | 51.5 | -10% |  |
| accuracy 20-30 m | % | 41.7 | 48.2 | 48.2 | -13% |  |
| accuracy 30-45 m | % | 40.4 | 46.1 | 46.1 | -12% |  |
| accuracy 45+ m | % | 32.7 | 38.3 | 38.3 | -15% |  |
| shots fired standing | % | 100.0 | 96.9 | 96.9 | 3% |  |
| accuracy standing | % | 37.0 | 43.1 | 43.1 | -14% |  |
| accuracy moving | % | — | 29.3 | 29.3 | — |  |
| shots from above | % | 43.3 | 40.4 | 40.4 | 7% |  |
| accuracy from above | % | 40.7 | 48.5 | 48.5 | -16% |  |
| accuracy level | % | 36.0 | 40.8 | 40.8 | -12% |  |
| accuracy from below | % | 32.8 | 37.2 | 37.2 | -12% |  |
| hits from high ground | % | 51.8 | 49.5 | 49.5 | 5% |  |
| hits from trench | % | 0.4 | 0.4 | 0.4 | 11% |  |
| miss: cover in the way | % | 15.6 | 21.1 | 21.1 | -26% | we are lower |
| miss: target moved off the line | % | 28.5 | 14.6 | 14.6 | 96% | we are higher |
| miss: aim off a still target | % | 5.6 | 6.3 | 6.3 | -11% |  |
| miss: in radius, no hit | % | 9.2 | 11.4 | 11.4 | -19% |  |
| miss: teammate in the way | % | 1.6 | 1.7 | 1.7 | -5% |  |
| miss: nobody near the line | % | 2.4 | 2.3 | 2.3 | 5% |  |
| speed | m/s | 5.36 | 5.50 | 5.50 | -3% |  |
| moving | % | 85.0 | 87.0 | 87.0 | -2% |  |
| wading | % | 0.8 | 0.8 | 0.8 | -2% |  |
| sneaking | % | 5.3 | 5.1 | 5.1 | 3% |  |
| in trench | % | 0.6 | 0.5 | 0.5 | 21% |  |
| high ground | % | 43.4 | 40.6 | 40.6 | 7% |  |
| exact compass steps | % | 6.9 | 7.0 | 7.0 | -1% |  |
| nearest teammate | m | 11.9 | 12.1 | 12.1 | -2% |  |
| lead on a moving target | ticks | 3.3 | 4.6 | 4.6 | -27% | we are lower |
| sight run length | ticks | 7.9 | 7.9 | 7.9 | 0% |  |
| new sightings | /min | 151.4 | 151.4 | 151.4 | 0% |  |
| shots at a target in view | % | 99.1 | 98.9 | 98.9 | 0% |  |
| shots at a tracked target | % | 76.3 | 98.8 | 98.8 | -23% |  |
| unled shots at movers | % | 32.6 | 6.1 | 6.1 | 436% | we are higher |
| standing with an enemy in sight | % | 19.8 | 17.3 | 17.3 | 15% |  |
| run length in sight | ticks | 6.3 | 6.3 | 6.3 | -1% |  |
| runs ended by reversing | % | 36.3 | 43.2 | 43.2 | -16% |  |
| direction changes in sight | /s | 1.34 | 1.41 | 1.41 | -5% |  |
| in a heart ring | % | 3.4 | 3.4 | 3.4 | 1% |  |
| walk orders | % | 100.0 | 100.0 | 100.0 | 0% |  |
| shoot orders | % | 1.5 | 1.3 | 1.3 | 14% |  |
| direct walks | % | 0.0 | 0.0 | 0.0 | — |  |
| grenade charging | % | 0.1 | 0.1 | 0.1 | -7% |  |

## 2. Controlled indirectly: items picked up and used

| stat | unit | zhar:v53 | xolod:v12 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---|
| grenades picked | /cog | 1.90 | 1.97 | 1.97 | -4% |  |
| grenades thrown | /cog | 0.35 | 0.36 | 0.36 | -4% |  |
| grenade hits | /throw | 0.29 | 0.26 | 0.26 | 11% |  |
| spray cans | /cog | 0.20 | 0.22 | 0.22 | -9% |  |
| spray bursts | /cog | 0.02 | 0.02 | 0.02 | 9% |  |
| armor | /cog | 0.10 | 0.13 | 0.13 | -27% | we are lower |
| medkits | /cog | 0.53 | 0.56 | 0.56 | -7% |  |
| glory hearts | /cog | 0.19 | 0.18 | 0.18 | 7% |  |
| uniforms | /cog | 0.04 | 0.02 | 0.02 | 71% | we are higher |

## 3. Outcomes: winning, killing, dying, territory

| stat | unit | zhar:v53 | xolod:v12 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---|
| games |  | 80 | 80 | 80 | 0% |  |
| win rate | % | 56.2 | 43.8 | 43.8 | 29% | we are higher |
| draw rate | % | 0.0 | 0.0 | 0.0 | — |  |
| glory per game |  | 321 | 254 | 254 | 26% | we are higher |
| glory per win |  | 570 | 581 | 581 | -2% |  |
| match length | s | 117 | 117 | 117 | 0% |  |
| deaths | /cog | 3.52 | 3.57 | 3.57 | -1% |  |
| lives left | /cog | 0.80 | 0.73 | 0.73 | 9% |  |
| first death | s | 33.9 | 33.0 | 33.0 | 3% |  |
| deaths in water | % | 2.5 | 2.5 | 2.5 | 1% |  |
| deaths in trench | % | 0.6 | 0.4 | 0.4 | 77% |  |
| damage taken | /cog | 10.42 | 10.75 | 10.75 | -3% |  |
| kills | /cog | 3.23 | 3.16 | 3.16 | 2% |  |
| kill/death |  | 0.92 | 0.89 | 0.89 | 4% |  |
| damage dealt | /cog | 10.75 | 10.42 | 10.42 | 3% |  |
| gun kills | % | 96.4 | 96.7 | 96.7 | 0% |  |
| grenade kills | % | 3.0 | 3.0 | 3.0 | 1% |  |
| spray kills | % | 0.6 | 0.3 | 0.3 | 68% |  |
| captures | /cog | 0.41 | 0.41 | 0.41 | 0% |  |

## Largest gaps in what we control (groups 1 and 2)

| stat | unit | ours | rivals' mean | gap | xolod:v12 |
|---|---|---:|---:|---:|---|
| unled shots at movers | % | 32.6 | 6.1 | 436% | 6.1 |
| miss: target moved off the line | % | 28.5 | 14.6 | 96% | 14.6 |
| uniforms | /cog | 0.04 | 0.02 | 71% | 0.02 |
| armor | /cog | 0.10 | 0.13 | -27% | 0.13 |
| lead on a moving target | ticks | 3.3 | 4.6 | -27% | 4.6 |
| miss: cover in the way | % | 15.6 | 21.1 | -26% | 21.1 |
