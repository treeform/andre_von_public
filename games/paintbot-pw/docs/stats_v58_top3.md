# fast 0.3.124: zhar v58 vs jb-pw-opt v29 / relay-bassy-relh v1 / bassy-richard v1 (60 games)

60 replays re-simulated with the hosted engine rules (0 state-hash mismatches, 0 replays without a roster skipped). Columns are policy versions, ordered by glory per game. Replay rows are means over the policy's seat-games unless noted.

The first column is ours (f58_jb,f58_relh,f58_bassy-richard). Gap = (ours - rivals' mean) / rivals' mean. A row is flagged when the gap is at least 25% (and, for % rows, at least 2 points).

## 1. Controlled directly: movement, footwork, aiming, shooting

| stat | unit | f58_jb,f58_relh,f58_bassy-richard | jb-pw-opt:v29 | co-gas-paintbot-bassy-richard:v1 | co-gas-paintbot-relay-bassy-relh:v1 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| friendly damage | /cog | 1.76 | 1.18 | 1.43 | 1.64 | 1.41 | 25% |  |
| enemy in view | % | 62.3 | 55.5 | 62.3 | 64.2 | 60.7 | 3% |  |
| gun shots | /min | 13.8 | 9.3 | 19.9 | 21.7 | 17.0 | -19% |  |
| gun accuracy | % | 30.5 | 20.4 | 9.5 | 9.5 | 13.1 | 132% | we are higher |
| first shot | s | 26.3 | 29.8 | 4.3 | 2.4 | 12.2 | 117% | we are higher |
| shots with no enemy in view | % | 5.9 | 9.7 | 9.5 | 10.0 | 9.8 | -39% | we are lower |
| accuracy with no enemy in view | % | 13.9 | 6.8 | 1.5 | 3.0 | 3.8 | 268% | we are higher |
| range under 20 m | % | 66.7 | 66.3 | 37.7 | 37.4 | 47.1 | 42% | we are higher |
| accuracy 0-10 m | % | 52.0 | 40.3 | 33.2 | 32.1 | 35.2 | 48% | we are higher |
| accuracy 10-20 m | % | 31.0 | 20.4 | 18.2 | 16.9 | 18.5 | 67% | we are higher |
| accuracy 20-30 m | % | 22.7 | 15.6 | 4.9 | 5.9 | 8.8 | 158% | we are higher |
| accuracy 30-45 m | % | 44.1 | 30.3 | 2.7 | 2.6 | 11.9 | 271% | we are higher |
| accuracy 45+ m | % | 22.7 | 17.6 | 1.2 | 1.6 | 6.8 | 234% | we are higher |
| shots fired standing | % | 100.0 | 3.0 | 3.7 | 3.8 | 3.5 | 2724% | we are higher |
| accuracy standing | % | 31.5 | 17.7 | 9.4 | 7.3 | 11.5 | 175% | we are higher |
| accuracy moving | % | — | 22.0 | 10.3 | 10.4 | 14.2 | — |  |
| shots from above | % | 53.3 | 16.6 | 20.5 | 19.1 | 18.7 | 185% | we are higher |
| accuracy from above | % | 34.2 | 24.8 | 10.0 | 10.0 | 14.9 | 129% | we are higher |
| accuracy level | % | 30.6 | 25.6 | 12.1 | 12.3 | 16.7 | 83% | we are higher |
| accuracy from below | % | 23.3 | 18.9 | 9.1 | 8.9 | 12.3 | 90% | we are higher |
| hits from high ground | % | 29.0 | 12.9 | 19.0 | 14.4 | 15.4 | 88% | we are higher |
| hits from trench | % | 0.4 | 0.9 | 0.9 | 0.5 | 0.8 | -52% |  |
| miss: cover in the way | % | 3.9 | 10.3 | 13.5 | 12.7 | 12.1 | -68% | we are lower |
| miss: target moved off the line | % | 23.7 | 33.8 | 29.5 | 30.5 | 31.3 | -24% |  |
| miss: aim off a still target | % | 2.3 | 7.5 | 5.9 | 6.3 | 6.6 | -66% | we are lower |
| miss: in radius, no hit | % | 33.4 | 21.1 | 34.0 | 33.5 | 29.5 | 13% |  |
| miss: teammate in the way | % | 5.0 | 4.2 | 5.9 | 5.8 | 5.3 | -6% |  |
| miss: nobody near the line | % | 0.2 | 1.3 | 0.9 | 1.0 | 1.1 | -77% |  |
| speed | m/s | 5.08 | 4.56 | 4.87 | 4.81 | 4.75 | 7% |  |
| moving | % | 85.2 | 84.0 | 89.4 | 88.7 | 87.4 | -3% |  |
| wading | % | 2.9 | 17.8 | 13.9 | 14.6 | 15.4 | -81% | we are lower |
| sneaking | % | 9.9 | 3.3 | 7.8 | 6.0 | 5.7 | 73% | we are higher |
| in trench | % | 0.9 | 1.4 | 1.4 | 1.5 | 1.4 | -36% |  |
| high ground | % | 30.3 | 13.5 | 21.8 | 18.7 | 18.0 | 68% | we are higher |
| exact compass steps | % | 5.3 | 4.7 | 4.9 | 4.8 | 4.8 | 10% |  |
| nearest teammate | m | 10.4 | 11.0 | 9.7 | 9.4 | 10.0 | 3% |  |
| lead on a moving target | ticks | 4.1 | 3.9 | 4.1 | 4.1 | 4.0 | 1% |  |
| sight run length | ticks | 18.4 | 12.8 | 17.7 | 17.4 | 16.0 | 15% |  |
| new sightings | /min | 114.8 | 128.3 | 105.9 | 109.0 | 114.4 | 0% |  |
| shots at a target in view | % | 99.3 | 97.6 | 95.9 | 96.2 | 96.6 | 3% |  |
| shots at a tracked target | % | 91.5 | 72.5 | 77.9 | 76.6 | 75.7 | 21% |  |
| unled shots at movers | % | 17.2 | 20.9 | 19.2 | 19.2 | 19.8 | -13% |  |
| standing with an enemy in sight | % | 17.1 | 28.2 | 17.0 | 18.1 | 21.1 | -19% |  |
| run length in sight | ticks | 5.7 | 5.5 | 6.4 | 5.8 | 5.9 | -3% |  |
| runs ended by reversing | % | 73.8 | 81.8 | 79.9 | 80.3 | 80.6 | -9% |  |
| direction changes in sight | /s | 2.44 | 2.00 | 2.23 | 2.43 | 2.22 | 10% |  |
| in a heart ring | % | 4.7 | 13.2 | 10.5 | 14.9 | 12.9 | -64% | we are lower |
| walk orders | % | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 0% |  |
| shoot orders | % | 1.0 | 1.2 | 1.9 | 1.9 | 1.7 | -40% |  |
| direct walks | % | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | — |  |
| grenade charging | % | 1.0 | 1.0 | 8.1 | 7.3 | 5.5 | -81% | we are lower |

## 2. Controlled indirectly: items picked up and used

| stat | unit | f58_jb,f58_relh,f58_bassy-richard | jb-pw-opt:v29 | co-gas-paintbot-bassy-richard:v1 | co-gas-paintbot-relay-bassy-relh:v1 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| grenades picked | /cog | 1.39 | 1.62 | 1.28 | 1.32 | 1.41 | -1% |  |
| grenades thrown | /cog | 1.03 | 1.28 | 0.91 | 0.91 | 1.03 | 0% |  |
| grenade hits | /throw | 0.63 | 0.89 | 1.03 | 0.92 | 0.95 | -33% | we are lower |
| spray cans | /cog | 0.22 | 0.26 | 0.24 | 0.26 | 0.25 | -14% |  |
| spray bursts | /cog | 0.62 | 0.57 | 0.22 | 0.17 | 0.32 | 93% | we are higher |
| armor | /cog | 0.08 | 0.54 | 0.31 | 0.28 | 0.38 | -79% | we are lower |
| medkits | /cog | 0.66 | 0.75 | 0.19 | 0.17 | 0.37 | 77% | we are higher |
| mister heals | /cog | 0.16 | 0.34 | 0.54 | 0.57 | 0.49 | -68% | we are lower |
| glory hearts | /cog | 0.12 | 0.17 | 0.11 | 0.10 | 0.13 | -3% |  |
| uniforms | /cog | 0.13 | 0.24 | 0.27 | 0.22 | 0.24 | -48% | we are lower |
| sniper rifles | /cog | 0.17 | 0.21 | 0.16 | 0.12 | 0.16 | 3% |  |
| windex-misters | /cog | 0.09 | 0.19 | 0.16 | 0.15 | 0.17 | -44% | we are lower |
| radars | /cog | 0.15 | 0.32 | 0.16 | 0.15 | 0.21 | -29% | we are lower |

## 3. Outcomes: winning, killing, dying, territory

| stat | unit | f58_jb,f58_relh,f58_bassy-richard | jb-pw-opt:v29 | co-gas-paintbot-bassy-richard:v1 | co-gas-paintbot-relay-bassy-relh:v1 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| games |  | 60 | 20 | 20 | 20 | 20 | 200% | we are higher |
| win rate | % | 43.3 | 65.0 | 60.0 | 45.0 | 56.7 | -24% |  |
| draw rate | % | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | — |  |
| glory per game |  | 222 | 521 | 518 | 262 | 434 | -49% | we are lower |
| glory per win |  | 512 | 801 | 863 | 583 | 749 | -32% | we are lower |
| match length | s | 129 | 155 | 120 | 113 | 129 | 0% |  |
| deaths | /cog | 0.57 | 0.76 | 0.82 | 0.84 | 0.81 | -29% | we are lower |
| lives left | /cog | 0.86 | 0.47 | 0.36 | 0.33 | 0.39 | 123% | we are higher |
| first death | s | 77.2 | 71.0 | 65.5 | 65.3 | 67.3 | 15% |  |
| deaths in water | % | 4.8 | 19.7 | 9.2 | 10.4 | 13.1 | -64% | we are lower |
| deaths in trench | % | 1.1 | 0.0 | 0.8 | 2.2 | 1.0 | 10% |  |
| damage taken | /cog | 6.52 | 10.38 | 9.16 | 8.89 | 9.48 | -31% | we are lower |
| kills | /cog | 0.74 | 0.58 | 0.44 | 0.38 | 0.47 | 59% | we are higher |
| kill/death |  | 1.31 | 0.76 | 0.54 | 0.45 | 0.58 | 124% | we are higher |
| damage dealt | /cog | 9.48 | 7.85 | 5.89 | 5.83 | 6.52 | 45% | we are higher |
| gun kills | % | 56.6 | 33.3 | 31.0 | 38.3 | 34.2 | 65% | we are higher |
| grenade kills | % | 20.4 | 34.4 | 38.0 | 38.3 | 36.9 | -45% | we are lower |
| spray kills | % | 23.0 | 32.3 | 31.0 | 23.3 | 28.9 | -20% |  |
| captures | /cog | 0.77 | 1.14 | 1.41 | 1.28 | 1.28 | -39% | we are lower |

## Largest gaps in what we control (groups 1 and 2)

| stat | unit | ours | rivals' mean | gap | jb-pw-opt:v29 / co-gas-paintbot-bassy-richard:v1 / co-gas-paintbot-relay-bassy-relh:v1 |
|---|---|---:|---:|---:|---|
| shots fired standing | % | 100.0 | 3.5 | 2724% | 3.0 / 3.7 / 3.8 |
| accuracy 30-45 m | % | 44.1 | 11.9 | 271% | 30.3 / 2.7 / 2.6 |
| accuracy with no enemy in view | % | 13.9 | 3.8 | 268% | 6.8 / 1.5 / 3.0 |
| accuracy 45+ m | % | 22.7 | 6.8 | 234% | 17.6 / 1.2 / 1.6 |
| shots from above | % | 53.3 | 18.7 | 185% | 16.6 / 20.5 / 19.1 |
| accuracy standing | % | 31.5 | 11.5 | 175% | 17.7 / 9.4 / 7.3 |
| accuracy 20-30 m | % | 22.7 | 8.8 | 158% | 15.6 / 4.9 / 5.9 |
| gun accuracy | % | 30.5 | 13.1 | 132% | 20.4 / 9.5 / 9.5 |
| accuracy from above | % | 34.2 | 14.9 | 129% | 24.8 / 10.0 / 10.0 |
| first shot | s | 26.3 | 12.2 | 117% | 29.8 / 4.3 / 2.4 |
| spray bursts | /cog | 0.62 | 0.32 | 93% | 0.57 / 0.22 / 0.17 |
| accuracy from below | % | 23.3 | 12.3 | 90% | 18.9 / 9.1 / 8.9 |
| hits from high ground | % | 29.0 | 15.4 | 88% | 12.9 / 19.0 / 14.4 |
| accuracy level | % | 30.6 | 16.7 | 83% | 25.6 / 12.1 / 12.3 |
| grenade charging | % | 1.0 | 5.5 | -81% | 1.0 / 8.1 / 7.3 |
| wading | % | 2.9 | 15.4 | -81% | 17.8 / 13.9 / 14.6 |
| armor | /cog | 0.08 | 0.38 | -79% | 0.54 / 0.31 / 0.28 |
| medkits | /cog | 0.66 | 0.37 | 77% | 0.75 / 0.19 / 0.17 |
| sneaking | % | 9.9 | 5.7 | 73% | 3.3 / 7.8 / 6.0 |
| high ground | % | 30.3 | 18.0 | 68% | 13.5 / 21.8 / 18.7 |
| miss: cover in the way | % | 3.9 | 12.1 | -68% | 10.3 / 13.5 / 12.7 |
| mister heals | /cog | 0.16 | 0.49 | -68% | 0.34 / 0.54 / 0.57 |
| accuracy 10-20 m | % | 31.0 | 18.5 | 67% | 20.4 / 18.2 / 16.9 |
| miss: aim off a still target | % | 2.3 | 6.6 | -66% | 7.5 / 5.9 / 6.3 |
| in a heart ring | % | 4.7 | 12.9 | -64% | 13.2 / 10.5 / 14.9 |
| accuracy 0-10 m | % | 52.0 | 35.2 | 48% | 40.3 / 33.2 / 32.1 |
| uniforms | /cog | 0.13 | 0.24 | -48% | 0.24 / 0.27 / 0.22 |
| windex-misters | /cog | 0.09 | 0.17 | -44% | 0.19 / 0.16 / 0.15 |
| range under 20 m | % | 66.7 | 47.1 | 42% | 66.3 / 37.7 / 37.4 |
| shots with no enemy in view | % | 5.9 | 9.8 | -39% | 9.7 / 9.5 / 10.0 |
| grenade hits | /throw | 0.63 | 0.95 | -33% | 0.89 / 1.03 / 0.92 |
| radars | /cog | 0.15 | 0.21 | -29% | 0.32 / 0.16 / 0.15 |
