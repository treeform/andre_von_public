# zhar v50 vs xolod v11

60 replays re-simulated with the hosted engine rules (0 state-hash mismatches, 0 replays without a roster skipped). Columns are policy versions, ordered by glory per game. Replay rows are means over the policy's seat-games unless noted.

The first column is ours (zhar:v50). Gap = (ours - rivals' mean) / rivals' mean. A row is flagged when the gap is at least 25% (and, for % rows, at least 2 points).

## 1. Controlled directly: movement, footwork, aiming, shooting

| stat | unit | zhar:v50 | xolod:v11 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---|
| friendly damage | /cog | 0.80 | 0.80 | 0.80 | 0% |  |
| enemy in view | % | 54.2 | 50.6 | 50.6 | 7% |  |
| gun shots | /min | 22.5 | 18.2 | 18.2 | 24% |  |
| gun accuracy | % | 28.5 | 38.1 | 38.1 | -25% | we are lower |
| first shot | s | 7.6 | 8.2 | 8.2 | -8% |  |
| shots with no enemy in view | % | 20.6 | 25.3 | 25.3 | -19% |  |
| accuracy with no enemy in view | % | 17.0 | 24.0 | 24.0 | -29% | we are lower |
| range under 20 m | % | 10.3 | 9.4 | 9.4 | 9% |  |
| accuracy 0-10 m | % | 36.3 | 63.2 | 63.2 | -43% | we are lower |
| accuracy 10-20 m | % | 38.7 | 48.0 | 48.0 | -19% |  |
| accuracy 20-30 m | % | 34.1 | 49.0 | 49.0 | -30% | we are lower |
| accuracy 30-45 m | % | 33.7 | 48.2 | 48.2 | -30% | we are lower |
| accuracy 45+ m | % | 28.2 | 37.8 | 37.8 | -25% | we are lower |
| shots fired standing | % | 100.0 | 94.3 | 94.3 | 6% |  |
| accuracy standing | % | 31.5 | 43.7 | 43.7 | -28% | we are lower |
| accuracy moving | % | — | 30.2 | 30.2 | — |  |
| shots from above | % | 42.8 | 41.1 | 41.1 | 4% |  |
| accuracy from above | % | 33.3 | 48.1 | 48.1 | -31% | we are lower |
| accuracy level | % | 30.0 | 41.0 | 41.0 | -27% | we are lower |
| accuracy from below | % | 30.1 | 38.0 | 38.0 | -21% |  |
| hits from high ground | % | 52.5 | 49.1 | 49.1 | 7% |  |
| hits from trench | % | 0.4 | 0.5 | 0.5 | -15% |  |
| miss: cover in the way | % | 5.6 | 21.8 | 21.8 | -74% | we are lower |
| miss: target moved off the line | % | 49.0 | 13.7 | 13.7 | 258% | we are higher |
| miss: aim off a still target | % | 1.7 | 5.4 | 5.4 | -68% | we are lower |
| miss: in radius, no hit | % | 8.4 | 11.2 | 11.2 | -25% | we are lower |
| miss: teammate in the way | % | 1.8 | 1.9 | 1.9 | -6% |  |
| miss: nobody near the line | % | 2.0 | 3.1 | 3.1 | -34% |  |
| speed | m/s | 5.37 | 5.53 | 5.53 | -3% |  |
| moving | % | 84.5 | 87.6 | 87.6 | -4% |  |
| wading | % | 0.3 | 1.0 | 1.0 | -69% |  |
| sneaking | % | 4.9 | 5.1 | 5.1 | -5% |  |
| in trench | % | 0.6 | 0.5 | 0.5 | 10% |  |
| high ground | % | 44.2 | 40.6 | 40.6 | 9% |  |
| exact compass steps | % | 7.2 | 7.1 | 7.1 | 2% |  |
| nearest teammate | m | 12.3 | 11.8 | 11.8 | 4% |  |
| lead on a moving target | ticks | 1.1 | 4.8 | 4.8 | -77% | we are lower |
| sight run length | ticks | 7.9 | 7.9 | 7.9 | -1% |  |
| new sightings | /min | 164.3 | 147.1 | 147.1 | 12% |  |
| shots at a target in view | % | 99.7 | 99.1 | 99.1 | 1% |  |
| shots at a tracked target | % | 77.1 | 99.0 | 99.0 | -22% |  |
| unled shots at movers | % | 78.3 | 2.3 | 2.3 | 3365% | we are higher |
| standing with an enemy in sight | % | 20.2 | 17.0 | 17.0 | 19% |  |
| run length in sight | ticks | 6.3 | 6.3 | 6.3 | 0% |  |
| runs ended by reversing | % | 35.9 | 44.6 | 44.6 | -20% |  |
| direction changes in sight | /s | 1.36 | 1.45 | 1.45 | -6% |  |
| in a heart ring | % | 3.6 | 3.3 | 3.3 | 8% |  |
| walk orders | % | 100.0 | 100.0 | 100.0 | 0% |  |
| shoot orders | % | 1.6 | 1.3 | 1.3 | 22% |  |
| direct walks | % | 0.0 | 0.0 | 0.0 | — |  |
| grenade charging | % | 0.1 | 0.2 | 0.2 | -14% |  |

## 2. Controlled indirectly: items picked up and used

| stat | unit | zhar:v50 | xolod:v11 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---|
| grenades picked | /cog | 1.79 | 2.13 | 2.13 | -16% |  |
| grenades thrown | /cog | 0.36 | 0.51 | 0.51 | -28% | we are lower |
| grenade hits | /throw | 0.20 | 0.21 | 0.21 | -4% |  |
| spray cans | /cog | 0.18 | 0.20 | 0.20 | -10% |  |
| spray bursts | /cog | 0.04 | 0.05 | 0.05 | -35% | we are lower |
| armor | /cog | 0.10 | 0.15 | 0.15 | -36% | we are lower |
| medkits | /cog | 0.39 | 0.61 | 0.61 | -36% | we are lower |
| glory hearts | /cog | 0.15 | 0.21 | 0.21 | -26% | we are lower |
| uniforms | /cog | 0.01 | 0.06 | 0.06 | -75% | we are lower |

## 3. Outcomes: winning, killing, dying, territory

| stat | unit | zhar:v50 | xolod:v11 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---|
| games |  | 60 | 60 | 60 | 0% |  |
| win rate | % | 15.0 | 85.0 | 85.0 | -82% | we are lower |
| draw rate | % | 0.0 | 0.0 | 0.0 | — |  |
| glory per game |  | 91 | 477 | 477 | -81% | we are lower |
| glory per win |  | 606 | 561 | 561 | 8% |  |
| match length | s | 117 | 117 | 117 | 0% |  |
| deaths | /cog | 3.91 | 2.99 | 2.99 | 31% | we are higher |
| lives left | /cog | 0.15 | 1.62 | 1.62 | -91% | we are lower |
| first death | s | 32.0 | 35.0 | 35.0 | -9% |  |
| deaths in water | % | 1.7 | 3.4 | 3.4 | -50% |  |
| deaths in trench | % | 0.4 | 0.7 | 0.7 | -47% |  |
| damage taken | /cog | 11.22 | 8.98 | 8.98 | 25% |  |
| kills | /cog | 2.53 | 3.53 | 3.53 | -28% | we are lower |
| kill/death |  | 0.65 | 1.18 | 1.18 | -45% | we are lower |
| damage dealt | /cog | 8.98 | 11.22 | 11.22 | -20% |  |
| gun kills | % | 95.7 | 95.7 | 95.7 | 0% |  |
| grenade kills | % | 2.9 | 3.0 | 3.0 | -4% |  |
| spray kills | % | 1.4 | 1.3 | 1.3 | 8% |  |
| captures | /cog | 0.41 | 0.44 | 0.44 | -7% |  |

## Largest gaps in what we control (groups 1 and 2)

| stat | unit | ours | rivals' mean | gap | xolod:v11 |
|---|---|---:|---:|---:|---|
| unled shots at movers | % | 78.3 | 2.3 | 3365% | 2.3 |
| miss: target moved off the line | % | 49.0 | 13.7 | 258% | 13.7 |
| lead on a moving target | ticks | 1.1 | 4.8 | -77% | 4.8 |
| uniforms | /cog | 0.01 | 0.06 | -75% | 0.06 |
| miss: cover in the way | % | 5.6 | 21.8 | -74% | 21.8 |
| miss: aim off a still target | % | 1.7 | 5.4 | -68% | 5.4 |
| accuracy 0-10 m | % | 36.3 | 63.2 | -43% | 63.2 |
| armor | /cog | 0.10 | 0.15 | -36% | 0.15 |
| medkits | /cog | 0.39 | 0.61 | -36% | 0.61 |
| spray bursts | /cog | 0.04 | 0.05 | -35% | 0.05 |
| accuracy from above | % | 33.3 | 48.1 | -31% | 48.1 |
| accuracy 20-30 m | % | 34.1 | 49.0 | -30% | 49.0 |
| accuracy 30-45 m | % | 33.7 | 48.2 | -30% | 48.2 |
| accuracy with no enemy in view | % | 17.0 | 24.0 | -29% | 24.0 |
| grenades thrown | /cog | 0.36 | 0.51 | -28% | 0.51 |
| accuracy standing | % | 31.5 | 43.7 | -28% | 43.7 |
| accuracy level | % | 30.0 | 41.0 | -27% | 41.0 |
| glory hearts | /cog | 0.15 | 0.21 | -26% | 0.21 |
| accuracy 45+ m | % | 28.2 | 37.8 | -25% | 37.8 |
| gun accuracy | % | 28.5 | 38.1 | -25% | 38.1 |
| miss: in radius, no hit | % | 8.4 | 11.2 | -25% | 11.2 |
