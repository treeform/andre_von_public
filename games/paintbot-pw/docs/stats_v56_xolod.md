# hosted: zhar v56 vs xolod v13 (48 games)

48 replays re-simulated with the hosted engine rules (0 state-hash mismatches, 96 replays without a roster skipped). Columns are policy versions, ordered by glory per game. Replay rows are means over the policy's seat-games unless noted.

The first column is ours (zhar:v56). Gap = (ours - rivals' mean) / rivals' mean. A row is flagged when the gap is at least 25% (and, for % rows, at least 2 points).

## 1. Controlled directly: movement, footwork, aiming, shooting

| stat | unit | zhar:v56 | xolod:v13 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---|
| friendly damage | /cog | 0.88 | 0.63 | 0.63 | 40% | we are higher |
| enemy in view | % | 52.4 | 52.4 | 52.4 | 0% |  |
| gun shots | /min | 21.5 | 19.0 | 19.0 | 13% |  |
| gun accuracy | % | 32.4 | 36.0 | 36.0 | -10% |  |
| first shot | s | 6.6 | 9.5 | 9.5 | -30% | we are lower |
| shots with no enemy in view | % | 21.4 | 21.4 | 21.4 | 0% |  |
| accuracy with no enemy in view | % | 20.9 | 23.2 | 23.2 | -10% |  |
| range under 20 m | % | 8.6 | 8.7 | 8.7 | -1% |  |
| accuracy 0-10 m | % | 41.6 | 54.3 | 54.3 | -23% |  |
| accuracy 10-20 m | % | 40.3 | 46.4 | 46.4 | -13% |  |
| accuracy 20-30 m | % | 39.9 | 42.9 | 42.9 | -7% |  |
| accuracy 30-45 m | % | 38.7 | 43.1 | 43.1 | -10% |  |
| accuracy 45+ m | % | 32.0 | 35.3 | 35.3 | -9% |  |
| shots fired standing | % | 100.0 | 95.9 | 95.9 | 4% |  |
| accuracy standing | % | 35.5 | 39.6 | 39.6 | -10% |  |
| accuracy moving | % | — | 35.5 | 35.5 | — |  |
| shots from above | % | 40.5 | 43.9 | 43.9 | -8% |  |
| accuracy from above | % | 39.6 | 43.7 | 43.7 | -9% |  |
| accuracy level | % | 35.3 | 38.1 | 38.1 | -7% |  |
| accuracy from below | % | 31.0 | 34.8 | 34.8 | -11% |  |
| hits from high ground | % | 46.9 | 50.2 | 50.2 | -7% |  |
| hits from trench | % | 0.5 | 0.5 | 0.5 | -3% |  |
| miss: cover in the way | % | 15.2 | 20.3 | 20.3 | -25% | we are lower |
| miss: target moved off the line | % | 30.9 | 19.4 | 19.4 | 59% | we are higher |
| miss: aim off a still target | % | 5.1 | 7.0 | 7.0 | -27% |  |
| miss: in radius, no hit | % | 9.4 | 9.9 | 9.9 | -5% |  |
| miss: teammate in the way | % | 1.9 | 1.7 | 1.7 | 11% |  |
| miss: nobody near the line | % | 2.1 | 2.3 | 2.3 | -10% |  |
| speed | m/s | 5.38 | 5.47 | 5.47 | -2% |  |
| moving | % | 85.7 | 86.6 | 86.6 | -1% |  |
| wading | % | 1.2 | 0.5 | 0.5 | 136% |  |
| sneaking | % | 5.3 | 6.4 | 6.4 | -17% |  |
| in trench | % | 0.6 | 0.4 | 0.4 | 29% |  |
| high ground | % | 38.2 | 43.1 | 43.1 | -11% |  |
| exact compass steps | % | 6.5 | 6.7 | 6.7 | -3% |  |
| nearest teammate | m | 12.7 | 11.8 | 11.8 | 7% |  |
| lead on a moving target | ticks | 3.2 | 4.5 | 4.5 | -30% | we are lower |
| sight run length | ticks | 8.0 | 8.0 | 8.0 | 0% |  |
| new sightings | /min | 154.2 | 154.5 | 154.5 | 0% |  |
| shots at a target in view | % | 99.2 | 98.8 | 98.8 | 0% |  |
| shots at a tracked target | % | 73.6 | 98.7 | 98.7 | -25% | we are lower |
| unled shots at movers | % | 36.0 | 3.9 | 3.9 | 826% | we are higher |
| standing with an enemy in sight | % | 19.4 | 17.5 | 17.5 | 11% |  |
| run length in sight | ticks | 5.5 | 6.5 | 6.5 | -16% |  |
| runs ended by reversing | % | 51.0 | 42.7 | 42.7 | 19% |  |
| direction changes in sight | /s | 1.73 | 1.44 | 1.44 | 20% |  |
| in a heart ring | % | 3.2 | 3.6 | 3.6 | -9% |  |
| walk orders | % | 100.0 | 100.0 | 100.0 | 0% |  |
| shoot orders | % | 1.5 | 1.4 | 1.4 | 11% |  |
| direct walks | % | 0.0 | 0.0 | 0.0 | — |  |
| grenade charging | % | 0.2 | 0.1 | 0.1 | 31% |  |

## 2. Controlled indirectly: items picked up and used

| stat | unit | zhar:v56 | xolod:v13 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---|
| grenades picked | /cog | 2.18 | 1.82 | 1.82 | 19% |  |
| grenades thrown | /cog | 0.49 | 0.38 | 0.38 | 29% | we are higher |
| grenade hits | /throw | 0.27 | 0.26 | 0.26 | 4% |  |
| spray cans | /cog | 0.19 | 0.19 | 0.19 | -3% |  |
| spray bursts | /cog | 0.03 | 0.02 | 0.02 | 50% | we are higher |
| armor | /cog | 0.10 | 0.09 | 0.09 | 6% |  |
| medkits | /cog | 0.59 | 0.46 | 0.46 | 29% | we are higher |
| glory hearts | /cog | 0.17 | 0.16 | 0.16 | 5% |  |
| uniforms | /cog | 0.03 | 0.03 | 0.03 | 30% | we are higher |

## 3. Outcomes: winning, killing, dying, territory

| stat | unit | zhar:v56 | xolod:v13 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---|
| games |  | 48 | 48 | 48 | 0% |  |
| win rate | % | 54.2 | 45.8 | 45.8 | 18% |  |
| draw rate | % | 0.0 | 0.0 | 0.0 | — |  |
| glory per game |  | 313 | 251 | 251 | 25% |  |
| glory per win |  | 578 | 548 | 548 | 6% |  |
| match length | s | 115 | 115 | 115 | 0% |  |
| deaths | /cog | 3.50 | 3.60 | 3.60 | -3% |  |
| lives left | /cog | 0.86 | 0.67 | 0.67 | 29% | we are higher |
| first death | s | 33.4 | 34.4 | 34.4 | -3% |  |
| deaths in water | % | 2.5 | 2.2 | 2.2 | 13% |  |
| deaths in trench | % | 0.4 | 0.6 | 0.6 | -36% |  |
| damage taken | /cog | 10.14 | 10.58 | 10.58 | -4% |  |
| kills | /cog | 3.23 | 2.97 | 2.97 | 9% |  |
| kill/death |  | 0.92 | 0.82 | 0.82 | 12% |  |
| damage dealt | /cog | 10.58 | 10.14 | 10.14 | 4% |  |
| gun kills | % | 95.5 | 96.1 | 96.1 | -1% |  |
| grenade kills | % | 4.0 | 3.2 | 3.2 | 27% |  |
| spray kills | % | 0.5 | 0.7 | 0.7 | -31% |  |
| captures | /cog | 0.42 | 0.40 | 0.40 | 3% |  |

## Largest gaps in what we control (groups 1 and 2)

| stat | unit | ours | rivals' mean | gap | xolod:v13 |
|---|---|---:|---:|---:|---|
| unled shots at movers | % | 36.0 | 3.9 | 826% | 3.9 |
| miss: target moved off the line | % | 30.9 | 19.4 | 59% | 19.4 |
| spray bursts | /cog | 0.03 | 0.02 | 50% | 0.02 |
| friendly damage | /cog | 0.88 | 0.63 | 40% | 0.63 |
| first shot | s | 6.6 | 9.5 | -30% | 9.5 |
| lead on a moving target | ticks | 3.2 | 4.5 | -30% | 4.5 |
| uniforms | /cog | 0.03 | 0.03 | 30% | 0.03 |
| grenades thrown | /cog | 0.49 | 0.38 | 29% | 0.38 |
| medkits | /cog | 0.59 | 0.46 | 29% | 0.46 |
| shots at a tracked target | % | 73.6 | 98.7 | -25% | 98.7 |
| miss: cover in the way | % | 15.2 | 20.3 | -25% | 20.3 |
