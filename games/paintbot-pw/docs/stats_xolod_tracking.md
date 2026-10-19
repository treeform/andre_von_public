# zhar v48 vs xolod v2: tracking

60 replays re-simulated with the hosted engine rules (103 state-hash mismatches, 0 replays without a roster skipped). Columns are policy versions, ordered by glory per game. Replay rows are means over the policy's seat-games unless noted.

The first column is ours (zhar:v48). Gap = (ours - rivals' mean) / rivals' mean. A row is flagged when the gap is at least 25% (and, for % rows, at least 2 points).

## 1. Controlled directly: movement, footwork, aiming, shooting

| stat | unit | zhar:v48 | xolod:v2 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---|
| friendly damage | /cog | 0.74 | 0.62 | 0.62 | 20% |  |
| enemy in view | % | 53.1 | 50.8 | 50.8 | 5% |  |
| gun shots | /min | 23.3 | 18.3 | 18.3 | 27% | we are higher |
| gun accuracy | % | 32.1 | 42.3 | 42.3 | -24% |  |
| first shot | s | 5.3 | 6.4 | 6.4 | -17% |  |
| shots with no enemy in view | % | 23.2 | 23.6 | 23.6 | -2% |  |
| accuracy with no enemy in view | % | 20.0 | 26.6 | 26.6 | -25% |  |
| range under 20 m | % | 7.5 | 7.1 | 7.1 | 6% |  |
| accuracy 0-10 m | % | 49.7 | 55.5 | 55.5 | -10% |  |
| accuracy 10-20 m | % | 44.0 | 57.1 | 57.1 | -23% |  |
| accuracy 20-30 m | % | 40.5 | 54.5 | 54.5 | -26% | we are lower |
| accuracy 30-45 m | % | 39.7 | 55.1 | 55.1 | -28% | we are lower |
| accuracy 45+ m | % | 31.9 | 41.1 | 41.1 | -23% |  |
| shots fired standing | % | 100.0 | 100.0 | 100.0 | 0% |  |
| accuracy standing | % | 35.7 | 47.2 | 47.2 | -24% |  |
| accuracy moving | % | — | — | — | — |  |
| shots from above | % | 41.0 | 41.8 | 41.8 | -2% |  |
| accuracy from above | % | 39.7 | 54.4 | 54.4 | -27% | we are lower |
| accuracy level | % | 36.1 | 41.1 | 41.1 | -12% |  |
| accuracy from below | % | 30.8 | 42.6 | 42.6 | -28% | we are lower |
| hits from high ground | % | 49.2 | 50.3 | 50.3 | -2% |  |
| hits from trench | % | 0.4 | 0.4 | 0.4 | -7% |  |
| miss: cover in the way | % | 7.8 | 17.5 | 17.5 | -56% | we are lower |
| miss: target moved off the line | % | 37.4 | 12.4 | 12.4 | 201% | we are higher |
| miss: aim off a still target | % | 3.6 | 4.7 | 4.7 | -23% |  |
| miss: in radius, no hit | % | 11.3 | 13.8 | 13.8 | -18% |  |
| miss: teammate in the way | % | 1.9 | 1.8 | 1.8 | 4% |  |
| miss: nobody near the line | % | 2.2 | 2.5 | 2.5 | -11% |  |
| speed | m/s | 5.29 | 5.45 | 5.45 | -3% |  |
| moving | % | 83.8 | 86.5 | 86.5 | -3% |  |
| wading | % | 0.4 | 0.9 | 0.9 | -57% |  |
| sneaking | % | 5.7 | 5.6 | 5.6 | 2% |  |
| in trench | % | 0.5 | 0.5 | 0.5 | -2% |  |
| high ground | % | 41.7 | 40.8 | 40.8 | 2% |  |
| nearest teammate | m | 12.2 | 12.1 | 12.1 | 1% |  |
| lead on a moving target | ticks | 1.5 | 4.7 | 4.7 | -69% | we are lower |
| sight run length | ticks | 8.3 | 8.3 | 8.3 | 0% |  |
| new sightings | /min | 152.7 | 143.4 | 143.4 | 7% |  |
| shots at a target in view | % | 99.5 | 98.8 | 98.8 | 1% |  |
| shots at a tracked target | % | 39.8 | 98.7 | 98.7 | -60% | we are lower |
| unled shots at movers | % | 70.6 | 3.4 | 3.4 | 1995% | we are higher |
| standing with an enemy in sight | % | 20.6 | 18.5 | 18.5 | 11% |  |
| run length in sight | ticks | 6.5 | 6.4 | 6.4 | 1% |  |
| runs ended by reversing | % | 29.7 | 38.3 | 38.3 | -22% |  |
| direction changes in sight | /s | 1.28 | 1.36 | 1.36 | -5% |  |
| in a heart ring | % | 3.4 | 3.4 | 3.4 | -1% |  |
| walk orders | % | 100.0 | 100.0 | 100.0 | 0% |  |
| shoot orders | % | 1.6 | 1.3 | 1.3 | 24% |  |
| direct walks | % | 0.0 | 0.0 | 0.0 | — |  |
| grenade charging | % | 0.1 | 0.1 | 0.1 | -30% |  |

## 2. Controlled indirectly: items picked up and used

| stat | unit | zhar:v48 | xolod:v2 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---|
| grenades picked | /cog | 1.70 | 1.94 | 1.94 | -12% |  |
| grenades thrown | /cog | 0.23 | 0.33 | 0.33 | -30% | we are lower |
| grenade hits | /throw | 0.19 | 0.21 | 0.21 | -6% |  |
| spray cans | /cog | 0.18 | 0.21 | 0.21 | -14% |  |
| spray bursts | /cog | 0.01 | 0.05 | 0.05 | -88% | we are lower |
| armor | /cog | 0.09 | 0.14 | 0.14 | -37% | we are lower |
| medkits | /cog | 0.44 | 0.59 | 0.59 | -25% |  |
| glory hearts | /cog | 0.12 | 0.15 | 0.15 | -17% |  |
| uniforms | /cog | 0.03 | 0.05 | 0.05 | -42% | we are lower |

## 3. Outcomes: winning, killing, dying, territory

| stat | unit | zhar:v48 | xolod:v2 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---|
| games |  | 60 | 60 | 60 | 0% |  |
| win rate | % | 25.0 | 75.0 | 75.0 | -67% | we are lower |
| draw rate | % | 0.0 | 0.0 | 0.0 | — |  |
| glory per game |  | 145 | 411 | 411 | -65% | we are lower |
| glory per win |  | 580 | 548 | 548 | 6% |  |
| match length | s | 108 | 108 | 108 | 0% |  |
| deaths | /cog | 3.81 | 3.13 | 3.13 | 22% |  |
| lives left | /cog | 0.33 | 1.39 | 1.39 | -77% | we are lower |
| first death | s | 30.2 | 32.6 | 32.6 | -7% |  |
| deaths in water | % | 1.6 | 2.5 | 2.5 | -35% |  |
| deaths in trench | % | 0.5 | 0.7 | 0.7 | -18% |  |
| damage taken | /cog | 11.15 | 9.66 | 9.66 | 15% |  |
| kills | /cog | 2.83 | 3.51 | 3.51 | -19% |  |
| kill/death |  | 0.74 | 1.12 | 1.12 | -34% | we are lower |
| damage dealt | /cog | 9.66 | 11.15 | 11.15 | -13% |  |
| gun kills | % | 98.3 | 96.8 | 96.8 | 2% |  |
| grenade kills | % | 1.5 | 1.9 | 1.9 | -19% |  |
| spray kills | % | 0.1 | 1.3 | 1.3 | -89% |  |
| captures | /cog | 0.38 | 0.41 | 0.41 | -10% |  |

## Largest gaps in what we control (groups 1 and 2)

| stat | unit | ours | rivals' mean | gap | xolod:v2 |
|---|---|---:|---:|---:|---|
| unled shots at movers | % | 70.6 | 3.4 | 1995% | 3.4 |
| miss: target moved off the line | % | 37.4 | 12.4 | 201% | 12.4 |
| spray bursts | /cog | 0.01 | 0.05 | -88% | 0.05 |
| lead on a moving target | ticks | 1.5 | 4.7 | -69% | 4.7 |
| shots at a tracked target | % | 39.8 | 98.7 | -60% | 98.7 |
| miss: cover in the way | % | 7.8 | 17.5 | -56% | 17.5 |
| uniforms | /cog | 0.03 | 0.05 | -42% | 0.05 |
| armor | /cog | 0.09 | 0.14 | -37% | 0.14 |
| grenades thrown | /cog | 0.23 | 0.33 | -30% | 0.33 |
| accuracy 30-45 m | % | 39.7 | 55.1 | -28% | 55.1 |
| accuracy from below | % | 30.8 | 42.6 | -28% | 42.6 |
| gun shots | /min | 23.3 | 18.3 | 27% | 18.3 |
| accuracy from above | % | 39.7 | 54.4 | -27% | 54.4 |
| accuracy 20-30 m | % | 40.5 | 54.5 | -26% | 54.5 |
