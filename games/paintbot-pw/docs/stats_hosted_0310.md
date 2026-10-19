# hosted 0.3.110: zhar v50 and v48 vs the top three

60 replays re-simulated with the hosted engine rules (0 state-hash mismatches, 0 replays without a roster skipped). Columns are policy versions, ordered by glory per game. Replay rows are means over the policy's seat-games unless noted.

The first column is ours (zhar:v50). Gap = (ours - rivals' mean) / rivals' mean. A row is flagged when the gap is at least 25% (and, for % rows, at least 2 points).

## 1. Controlled directly: movement, footwork, aiming, shooting

| stat | unit | zhar:v50 | zhar:v48 | xolod:v11 | aaron-paintbot-pw-aaron:v2 | eider:v9 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| friendly damage | /cog | 0.81 | 0.95 | 0.71 | 0.14 | 0.57 | 0.59 | 37% | we are higher |
| enemy in view | % | 50.6 | 49.5 | 49.8 | 48.4 | 39.0 | 46.7 | 8% |  |
| gun shots | /min | 21.0 | 22.9 | 18.1 | 24.3 | 23.7 | 22.2 | -5% |  |
| gun accuracy | % | 39.4 | 35.0 | 37.8 | 28.9 | 27.0 | 32.2 | 23% |  |
| first shot | s | 7.1 | 5.4 | 8.9 | 2.6 | 1.8 | 4.7 | 52% | we are higher |
| shots with no enemy in view | % | 18.4 | 20.6 | 26.4 | 27.0 | 29.0 | 25.7 | -29% | we are lower |
| accuracy with no enemy in view | % | 31.9 | 26.8 | 24.3 | 19.6 | 15.2 | 21.5 | 49% | we are higher |
| range under 20 m | % | 5.7 | 4.6 | 9.6 | 5.0 | 3.4 | 5.6 | 1% |  |
| accuracy 0-10 m | % | 36.7 | 49.3 | 58.0 | 55.1 | 48.1 | 52.6 | -30% | we are lower |
| accuracy 10-20 m | % | 41.1 | 37.7 | 50.0 | 36.6 | 40.5 | 41.2 | 0% |  |
| accuracy 20-30 m | % | 38.7 | 40.3 | 49.4 | 36.1 | 35.8 | 40.4 | -4% |  |
| accuracy 30-45 m | % | 44.1 | 39.7 | 48.1 | 31.7 | 30.0 | 37.4 | 18% |  |
| accuracy 45+ m | % | 39.8 | 34.5 | 37.0 | 30.6 | 31.4 | 33.4 | 19% |  |
| shots fired standing | % | 100.0 | 100.0 | 90.3 | 100.0 | 81.3 | 92.9 | 8% |  |
| accuracy standing | % | 41.1 | 37.1 | 44.0 | 32.3 | 37.0 | 37.6 | 9% |  |
| accuracy moving | % | — | — | 30.2 | — | 9.1 | 19.6 | — |  |
| shots from above | % | 51.9 | 52.9 | 42.3 | 17.5 | 26.3 | 34.7 | 49% | we are higher |
| accuracy from above | % | 43.4 | 40.2 | 46.8 | 42.3 | 39.3 | 42.2 | 3% |  |
| accuracy level | % | 41.0 | 34.9 | 42.1 | 29.9 | 29.5 | 34.1 | 20% |  |
| accuracy from below | % | 36.4 | 32.4 | 37.9 | 30.3 | 29.0 | 32.4 | 12% |  |
| hits from high ground | % | 51.5 | 53.9 | 49.7 | 24.2 | 34.4 | 40.5 | 27% | we are higher |
| hits from trench | % | 0.3 | 0.3 | 0.5 | 1.5 | 0.0 | 0.6 | -39% |  |
| miss: cover in the way | % | 4.5 | 7.3 | 20.0 | 10.8 | 22.2 | 15.1 | -70% | we are lower |
| miss: target moved off the line | % | 37.6 | 35.2 | 16.0 | 37.4 | 30.1 | 29.7 | 27% | we are higher |
| miss: aim off a still target | % | 2.2 | 3.8 | 5.3 | 2.8 | 2.1 | 3.5 | -36% |  |
| miss: in radius, no hit | % | 9.9 | 11.9 | 11.0 | 14.5 | 10.2 | 11.9 | -17% |  |
| miss: teammate in the way | % | 2.2 | 2.1 | 1.6 | 0.5 | 2.2 | 1.6 | 38% |  |
| miss: nobody near the line | % | 2.5 | 2.5 | 3.3 | 1.8 | 1.4 | 2.2 | 10% |  |
| speed | m/s | 5.28 | 5.27 | 5.53 | 5.08 | 5.16 | 5.26 | 0% |  |
| moving | % | 84.3 | 84.2 | 87.6 | 80.1 | 80.8 | 83.2 | 1% |  |
| wading | % | 1.1 | 1.1 | 0.8 | 1.4 | 0.0 | 0.8 | 25% |  |
| sneaking | % | 5.9 | 6.0 | 5.4 | 0.0 | 4.8 | 4.0 | 47% |  |
| in trench | % | 0.6 | 0.7 | 0.6 | 1.9 | 0.2 | 0.8 | -32% |  |
| high ground | % | 42.9 | 42.8 | 40.3 | 23.9 | 38.2 | 36.3 | 18% |  |
| exact compass steps | % | 6.4 | 6.1 | 6.8 | 5.9 | 6.6 | 6.4 | 0% |  |
| nearest teammate | m | 11.7 | 12.1 | 12.4 | 11.9 | 10.4 | 11.7 | 0% |  |
| lead on a moving target | ticks | 1.0 | 1.6 | 4.7 | 1.9 | 2.1 | 2.6 | -61% | we are lower |
| sight run length | ticks | 8.5 | 8.5 | 8.0 | 8.3 | 2.7 | 6.9 | 24% |  |
| new sightings | /min | 144.5 | 142.6 | 142.5 | 138.7 | 344.7 | 192.1 | -25% |  |
| shots at a target in view | % | 99.8 | 99.6 | 99.3 | 99.3 | 98.8 | 99.3 | 1% |  |
| shots at a tracked target | % | 78.0 | 42.3 | 99.3 | 49.6 | 38.3 | 57.4 | 36% | we are higher |
| unled shots at movers | % | 79.2 | 67.0 | 2.9 | 56.4 | 63.5 | 47.5 | 67% | we are higher |
| standing with an enemy in sight | % | 20.8 | 21.2 | 16.1 | 24.7 | 21.3 | 20.9 | 0% |  |
| run length in sight | ticks | 6.2 | 6.7 | 6.4 | 3.7 | 2.1 | 4.7 | 32% | we are higher |
| runs ended by reversing | % | 35.9 | 28.1 | 46.2 | 66.2 | 79.2 | 55.0 | -35% | we are lower |
| direction changes in sight | /s | 1.40 | 1.29 | 1.44 | 2.85 | 4.69 | 2.56 | -46% | we are lower |
| in a heart ring | % | 3.8 | 3.7 | 3.1 | 3.2 | 2.5 | 3.1 | 20% |  |
| walk orders | % | 100.0 | 100.0 | 100.0 | 100.1 | 100.1 | 100.0 | 0% |  |
| shoot orders | % | 1.5 | 1.6 | 1.3 | 1.7 | 1.7 | 1.6 | -6% |  |
| direct walks | % | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | — |  |
| grenade charging | % | 0.1 | 0.1 | 0.1 | 0.0 | 0.1 | 0.1 | 0% |  |

## 2. Controlled indirectly: items picked up and used

| stat | unit | zhar:v50 | zhar:v48 | xolod:v11 | aaron-paintbot-pw-aaron:v2 | eider:v9 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| grenades picked | /cog | 1.77 | 1.97 | 2.19 | 1.90 | 1.21 | 1.82 | -2% |  |
| grenades thrown | /cog | 0.24 | 0.26 | 0.42 | 0.07 | 0.11 | 0.22 | 10% |  |
| grenade hits | /throw | 0.23 | 0.33 | 0.15 | 0.09 | 0.28 | 0.21 | 7% |  |
| spray cans | /cog | 0.17 | 0.18 | 0.22 | 0.22 | 0.09 | 0.18 | -1% |  |
| spray bursts | /cog | 0.00 | 0.01 | 0.04 | 0.00 | 0.00 | 0.01 | -68% | we are lower |
| armor | /cog | 0.05 | 0.12 | 0.14 | 0.36 | 0.28 | 0.23 | -80% | we are lower |
| medkits | /cog | 0.47 | 0.55 | 0.65 | 0.36 | 0.36 | 0.48 | -2% |  |
| glory hearts | /cog | 0.16 | 0.16 | 0.17 | 0.09 | 0.33 | 0.19 | -13% |  |
| uniforms | /cog | 0.03 | 0.07 | 0.05 | 0.12 | 0.00 | 0.06 | -52% | we are lower |

## 3. Outcomes: winning, killing, dying, territory

| stat | unit | zhar:v50 | zhar:v48 | xolod:v11 | aaron-paintbot-pw-aaron:v2 | eider:v9 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---:|---|
| games |  | 30 | 30 | 20 | 20 | 20 | 23 | 33% | we are higher |
| win rate | % | 73.3 | 76.7 | 75.0 | 0.0 | 0.0 | 37.9 | 93% | we are higher |
| draw rate | % | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | — |  |
| glory per game |  | 393 | 412 | 433 | 0 | 0 | 211 | 86% | we are higher |
| glory per win |  | 536 | 538 | 577 | — | — | 557 | -4% |  |
| match length | s | 105 | 107 | 125 | 93 | 100 | 106 | -1% |  |
| deaths | /cog | 2.90 | 2.93 | 3.24 | 4.00 | 4.00 | 3.54 | -18% |  |
| lives left | /cog | 1.70 | 1.69 | 1.29 | 0.00 | 0.00 | 0.75 | 128% | we are higher |
| first death | s | 31.9 | 30.3 | 34.6 | 22.2 | 27.4 | 28.6 | 11% |  |
| deaths in water | % | 2.2 | 2.6 | 1.7 | 5.2 | 0.3 | 2.4 | -12% |  |
| deaths in trench | % | 1.0 | 0.6 | 0.4 | 0.8 | 0.2 | 0.5 | 113% |  |
| damage taken | /cog | 8.62 | 8.79 | 9.90 | 12.23 | 11.87 | 10.70 | -19% |  |
| kills | /cog | 3.46 | 3.55 | 3.55 | 2.08 | 2.19 | 2.84 | 22% |  |
| kill/death |  | 1.19 | 1.21 | 1.10 | 0.52 | 0.55 | 0.84 | 42% | we are higher |
| damage dealt | /cog | 11.24 | 11.43 | 11.15 | 7.29 | 7.68 | 9.39 | 20% |  |
| gun kills | % | 98.4 | 97.5 | 97.0 | 99.7 | 98.6 | 98.2 | 0% |  |
| grenade kills | % | 1.4 | 2.4 | 1.8 | 0.3 | 1.4 | 1.5 | -1% |  |
| spray kills | % | 0.1 | 0.1 | 1.2 | 0.0 | 0.0 | 0.3 | -64% |  |
| captures | /cog | 0.39 | 0.42 | 0.42 | 0.39 | 0.31 | 0.39 | 0% |  |

## Largest gaps in what we control (groups 1 and 2)

| stat | unit | ours | rivals' mean | gap | zhar:v48 / xolod:v11 / aaron-paintbot-pw-aaron:v2 / eider:v9 |
|---|---|---:|---:|---:|---|
| armor | /cog | 0.05 | 0.23 | -80% | 0.12 / 0.14 / 0.36 / 0.28 |
| miss: cover in the way | % | 4.5 | 15.1 | -70% | 7.3 / 20.0 / 10.8 / 22.2 |
| spray bursts | /cog | 0.00 | 0.01 | -68% | 0.01 / 0.04 / 0.00 / 0.00 |
| unled shots at movers | % | 79.2 | 47.5 | 67% | 67.0 / 2.9 / 56.4 / 63.5 |
| lead on a moving target | ticks | 1.0 | 2.6 | -61% | 1.6 / 4.7 / 1.9 / 2.1 |
| first shot | s | 7.1 | 4.7 | 52% | 5.4 / 8.9 / 2.6 / 1.8 |
| uniforms | /cog | 0.03 | 0.06 | -52% | 0.07 / 0.05 / 0.12 / 0.00 |
| shots from above | % | 51.9 | 34.7 | 49% | 52.9 / 42.3 / 17.5 / 26.3 |
| accuracy with no enemy in view | % | 31.9 | 21.5 | 49% | 26.8 / 24.3 / 19.6 / 15.2 |
| direction changes in sight | /s | 1.40 | 2.56 | -46% | 1.29 / 1.44 / 2.85 / 4.69 |
| friendly damage | /cog | 0.81 | 0.59 | 37% | 0.95 / 0.71 / 0.14 / 0.57 |
| shots at a tracked target | % | 78.0 | 57.4 | 36% | 42.3 / 99.3 / 49.6 / 38.3 |
| runs ended by reversing | % | 35.9 | 55.0 | -35% | 28.1 / 46.2 / 66.2 / 79.2 |
| run length in sight | ticks | 6.2 | 4.7 | 32% | 6.7 / 6.4 / 3.7 / 2.1 |
| accuracy 0-10 m | % | 36.7 | 52.6 | -30% | 49.3 / 58.0 / 55.1 / 48.1 |
| shots with no enemy in view | % | 18.4 | 25.7 | -29% | 20.6 / 26.4 / 27.0 / 29.0 |
| hits from high ground | % | 51.5 | 40.5 | 27% | 53.9 / 49.7 / 24.2 / 34.4 |
| miss: target moved off the line | % | 37.6 | 29.7 | 27% | 35.2 / 16.0 / 37.4 / 30.1 |
