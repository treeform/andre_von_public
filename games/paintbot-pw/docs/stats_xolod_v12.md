# zhar v51 vs xolod v12 (fast, 60 games)

60 replays re-simulated with the hosted engine rules (0 state-hash mismatches, 0 replays without a roster skipped). Columns are policy versions, ordered by glory per game. Replay rows are means over the policy's seat-games unless noted.

The first column is ours (zhar:v51). Gap = (ours - rivals' mean) / rivals' mean. A row is flagged when the gap is at least 25% (and, for % rows, at least 2 points).

## 1. Controlled directly: movement, footwork, aiming, shooting

| stat | unit | zhar:v51 | xolod:v12 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---|
| friendly damage | /cog | 0.78 | 0.72 | 0.72 | 9% |  |
| enemy in view | % | 51.6 | 51.1 | 51.1 | 1% |  |
| gun shots | /min | 21.6 | 18.2 | 18.2 | 19% |  |
| gun accuracy | % | 32.7 | 38.2 | 38.2 | -15% |  |
| first shot | s | 8.1 | 9.3 | 9.3 | -13% |  |
| shots with no enemy in view | % | 22.6 | 23.3 | 23.3 | -3% |  |
| accuracy with no enemy in view | % | 20.9 | 24.0 | 24.0 | -13% |  |
| range under 20 m | % | 8.3 | 8.4 | 8.4 | -1% |  |
| accuracy 0-10 m | % | 50.2 | 56.2 | 56.2 | -11% |  |
| accuracy 10-20 m | % | 42.2 | 52.7 | 52.7 | -20% |  |
| accuracy 20-30 m | % | 42.2 | 48.1 | 48.1 | -12% |  |
| accuracy 30-45 m | % | 39.6 | 47.9 | 47.9 | -17% |  |
| accuracy 45+ m | % | 31.8 | 37.2 | 37.2 | -15% |  |
| shots fired standing | % | 100.0 | 96.0 | 96.0 | 4% |  |
| accuracy standing | % | 36.1 | 43.1 | 43.1 | -16% |  |
| accuracy moving | % | — | 29.3 | 29.3 | — |  |
| shots from above | % | 40.5 | 42.4 | 42.4 | -4% |  |
| accuracy from above | % | 40.5 | 47.6 | 47.6 | -15% |  |
| accuracy level | % | 32.9 | 40.2 | 40.2 | -18% |  |
| accuracy from below | % | 33.3 | 38.0 | 38.0 | -12% |  |
| hits from high ground | % | 50.9 | 51.0 | 51.0 | 0% |  |
| hits from trench | % | 0.4 | 0.5 | 0.5 | -17% |  |
| miss: cover in the way | % | 16.2 | 20.5 | 20.5 | -21% |  |
| miss: target moved off the line | % | 30.1 | 14.3 | 14.3 | 110% | we are higher |
| miss: aim off a still target | % | 4.9 | 6.3 | 6.3 | -22% |  |
| miss: in radius, no hit | % | 8.9 | 11.6 | 11.6 | -23% |  |
| miss: teammate in the way | % | 1.8 | 1.9 | 1.9 | -5% |  |
| miss: nobody near the line | % | 2.0 | 2.8 | 2.8 | -27% |  |
| speed | m/s | 5.35 | 5.53 | 5.53 | -3% |  |
| moving | % | 84.9 | 87.5 | 87.5 | -3% |  |
| wading | % | 0.8 | 0.9 | 0.9 | -16% |  |
| sneaking | % | 5.4 | 4.9 | 4.9 | 10% |  |
| in trench | % | 0.6 | 0.5 | 0.5 | 26% |  |
| high ground | % | 41.8 | 40.9 | 40.9 | 2% |  |
| exact compass steps | % | 7.1 | 7.0 | 7.0 | 0% |  |
| nearest teammate | m | 11.9 | 12.3 | 12.3 | -4% |  |
| lead on a moving target | ticks | 3.2 | 4.6 | 4.6 | -30% | we are lower |
| sight run length | ticks | 8.0 | 8.0 | 8.0 | 0% |  |
| new sightings | /min | 152.3 | 149.3 | 149.3 | 2% |  |
| shots at a target in view | % | 99.1 | 98.8 | 98.8 | 0% |  |
| shots at a tracked target | % | 75.6 | 98.8 | 98.8 | -23% |  |
| unled shots at movers | % | 35.5 | 5.9 | 5.9 | 504% | we are higher |
| standing with an enemy in sight | % | 19.8 | 16.8 | 16.8 | 18% |  |
| run length in sight | ticks | 6.2 | 6.4 | 6.4 | -3% |  |
| runs ended by reversing | % | 37.4 | 43.6 | 43.6 | -14% |  |
| direction changes in sight | /s | 1.38 | 1.43 | 1.43 | -3% |  |
| in a heart ring | % | 3.4 | 3.3 | 3.3 | 2% |  |
| walk orders | % | 100.0 | 100.0 | 100.0 | 0% |  |
| shoot orders | % | 1.5 | 1.3 | 1.3 | 17% |  |
| direct walks | % | 0.0 | 0.0 | 0.0 | — |  |
| grenade charging | % | 0.1 | 0.1 | 0.1 | -14% |  |

## 2. Controlled indirectly: items picked up and used

| stat | unit | zhar:v51 | xolod:v12 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---|
| grenades picked | /cog | 1.87 | 2.03 | 2.03 | -8% |  |
| grenades thrown | /cog | 0.33 | 0.37 | 0.37 | -13% |  |
| grenade hits | /throw | 0.21 | 0.22 | 0.22 | -6% |  |
| spray cans | /cog | 0.19 | 0.23 | 0.23 | -18% |  |
| spray bursts | /cog | 0.01 | 0.02 | 0.02 | -30% | we are lower |
| armor | /cog | 0.09 | 0.13 | 0.13 | -32% | we are lower |
| medkits | /cog | 0.48 | 0.56 | 0.56 | -13% |  |
| glory hearts | /cog | 0.18 | 0.18 | 0.18 | 4% |  |
| uniforms | /cog | 0.04 | 0.06 | 0.06 | -37% | we are lower |

## 3. Outcomes: winning, killing, dying, territory

| stat | unit | zhar:v51 | xolod:v12 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---|
| games |  | 60 | 60 | 60 | 0% |  |
| win rate | % | 33.3 | 66.7 | 66.7 | -50% | we are lower |
| draw rate | % | 0.0 | 0.0 | 0.0 | — |  |
| glory per game |  | 187 | 384 | 384 | -51% | we are lower |
| glory per win |  | 560 | 576 | 576 | -3% |  |
| match length | s | 118 | 118 | 118 | 0% |  |
| deaths | /cog | 3.61 | 3.45 | 3.45 | 5% |  |
| lives left | /cog | 0.62 | 0.92 | 0.92 | -32% | we are lower |
| first death | s | 33.0 | 34.3 | 34.3 | -4% |  |
| deaths in water | % | 2.5 | 2.7 | 2.7 | -9% |  |
| deaths in trench | % | 0.9 | 0.4 | 0.4 | 105% |  |
| damage taken | /cog | 10.58 | 10.34 | 10.34 | 2% |  |
| kills | /cog | 3.08 | 3.23 | 3.23 | -5% |  |
| kill/death |  | 0.85 | 0.93 | 0.93 | -9% |  |
| damage dealt | /cog | 10.34 | 10.58 | 10.58 | -2% |  |
| gun kills | % | 97.6 | 97.0 | 97.0 | 1% |  |
| grenade kills | % | 2.1 | 2.5 | 2.5 | -17% |  |
| spray kills | % | 0.3 | 0.5 | 0.5 | -25% |  |
| captures | /cog | 0.40 | 0.43 | 0.43 | -9% |  |

## Largest gaps in what we control (groups 1 and 2)

| stat | unit | ours | rivals' mean | gap | xolod:v12 |
|---|---|---:|---:|---:|---|
| unled shots at movers | % | 35.5 | 5.9 | 504% | 5.9 |
| miss: target moved off the line | % | 30.1 | 14.3 | 110% | 14.3 |
| uniforms | /cog | 0.04 | 0.06 | -37% | 0.06 |
| armor | /cog | 0.09 | 0.13 | -32% | 0.13 |
| lead on a moving target | ticks | 3.2 | 4.6 | -30% | 4.6 |
| spray bursts | /cog | 0.01 | 0.02 | -30% | 0.02 |
