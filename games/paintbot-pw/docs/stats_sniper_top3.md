# fast: sniper variant vs the three leaders (60 games)

60 replays re-simulated with the hosted engine rules (0 state-hash mismatches, 0 replays without a roster skipped). Columns are policy versions, ordered by glory per game. Replay rows are means over the policy's seat-games unless noted.

The first column is ours (fsnip_jb,fsnip_relh,fsnip_bassy-richard). Gap = (ours - rivals' mean) / rivals' mean. A row is flagged when the gap is at least 25% (and, for % rows, at least 2 points).

## 1. Controlled directly: movement, footwork, aiming, shooting

| stat | unit | fsnip_jb,fsnip_relh,fsnip_bassy-richard | co-gas-paintbot-relay-bassy-relh:v1 | co-gas-paintbot-bassy-richard:v1 | jb-pw-opt:v29 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| friendly damage | /cog | 1.54 | 2.06 | 1.61 | 1.96 | 1.88 | -18% |  |
| enemy in view | % | 63.9 | 68.4 | 67.4 | 52.3 | 62.7 | 2% |  |
| gun shots | /min | 13.3 | 24.0 | 20.8 | 9.5 | 18.1 | -27% | we are lower |
| gun accuracy | % | 31.7 | 8.5 | 10.2 | 19.2 | 12.6 | 151% | we are higher |
| first shot | s | 24.3 | 2.0 | 3.3 | 30.0 | 11.8 | 107% | we are higher |
| shots with no enemy in view | % | 5.3 | 9.5 | 8.2 | 11.1 | 9.6 | -44% | we are lower |
| accuracy with no enemy in view | % | 19.4 | 1.8 | 2.1 | 5.0 | 2.9 | 558% | we are higher |
| range under 20 m | % | 63.3 | 38.1 | 40.2 | 68.8 | 49.0 | 29% | we are higher |
| accuracy 0-10 m | % | 49.1 | 31.8 | 30.4 | 34.5 | 32.2 | 52% | we are higher |
| accuracy 10-20 m | % | 30.8 | 17.3 | 18.8 | 18.4 | 18.1 | 70% | we are higher |
| accuracy 20-30 m | % | 24.9 | 3.8 | 5.2 | 16.7 | 8.5 | 192% | we are higher |
| accuracy 30-45 m | % | 53.4 | 1.8 | 1.9 | 31.1 | 11.6 | 360% | we are higher |
| accuracy 45+ m | % | 37.8 | 1.4 | 2.7 | 11.1 | 5.1 | 646% | we are higher |
| shots fired standing | % | 100.0 | 5.3 | 4.2 | 3.3 | 4.2 | 2253% | we are higher |
| accuracy standing | % | 32.4 | 8.3 | 11.2 | 22.1 | 13.8 | 134% | we are higher |
| accuracy moving | % | — | 9.3 | 10.9 | 20.9 | 13.7 | — |  |
| shots from above | % | 49.5 | 15.5 | 16.0 | 18.2 | 16.6 | 199% | we are higher |
| accuracy from above | % | 35.9 | 9.9 | 13.9 | 22.3 | 15.4 | 134% | we are higher |
| accuracy level | % | 30.2 | 11.5 | 12.7 | 23.3 | 15.8 | 91% | we are higher |
| accuracy from below | % | 25.5 | 7.5 | 8.1 | 19.2 | 11.6 | 119% | we are higher |
| hits from high ground | % | 26.0 | 13.0 | 12.8 | 14.4 | 13.4 | 94% | we are higher |
| hits from trench | % | 0.3 | 1.4 | 1.2 | 0.7 | 1.1 | -75% |  |
| miss: cover in the way | % | 4.0 | 11.4 | 12.5 | 10.2 | 11.4 | -65% | we are lower |
| miss: target moved off the line | % | 24.6 | 34.3 | 31.8 | 35.8 | 34.0 | -28% | we are lower |
| miss: aim off a still target | % | 2.3 | 6.9 | 7.6 | 7.1 | 7.2 | -68% | we are lower |
| miss: in radius, no hit | % | 31.6 | 31.4 | 29.9 | 20.9 | 27.4 | 15% |  |
| miss: teammate in the way | % | 4.9 | 6.2 | 6.5 | 4.1 | 5.6 | -13% |  |
| miss: nobody near the line | % | 0.2 | 0.6 | 0.8 | 1.0 | 0.8 | -75% |  |
| speed | m/s | 5.13 | 4.94 | 4.99 | 4.56 | 4.83 | 6% |  |
| moving | % | 85.5 | 89.4 | 90.4 | 83.1 | 87.6 | -2% |  |
| wading | % | 2.4 | 13.2 | 12.5 | 17.1 | 14.2 | -83% | we are lower |
| sneaking | % | 9.2 | 5.7 | 6.4 | 3.6 | 5.3 | 75% | we are higher |
| in trench | % | 0.7 | 1.6 | 1.9 | 1.2 | 1.6 | -54% |  |
| high ground | % | 31.3 | 16.9 | 17.8 | 15.3 | 16.7 | 87% | we are higher |
| exact compass steps | % | 5.7 | 5.2 | 4.9 | 4.2 | 4.8 | 20% |  |
| nearest teammate | m | 10.1 | 8.5 | 9.0 | 9.8 | 9.1 | 12% |  |
| lead on a moving target | ticks | 4.2 | 4.2 | 4.3 | 4.1 | 4.2 | 0% |  |
| sight run length | ticks | 18.6 | 18.4 | 18.5 | 12.2 | 16.4 | 14% |  |
| new sightings | /min | 119.1 | 119.3 | 117.3 | 124.4 | 120.3 | -1% |  |
| shots at a target in view | % | 99.3 | 96.4 | 96.7 | 98.1 | 97.1 | 2% |  |
| shots at a tracked target | % | 91.5 | 79.0 | 80.0 | 73.1 | 77.4 | 18% |  |
| unled shots at movers | % | 15.1 | 18.6 | 17.7 | 19.4 | 18.6 | -18% |  |
| standing with an enemy in sight | % | 15.5 | 17.9 | 15.2 | 28.0 | 20.4 | -24% |  |
| run length in sight | ticks | 5.8 | 6.2 | 6.3 | 6.0 | 6.2 | -7% |  |
| runs ended by reversing | % | 77.2 | 81.3 | 81.5 | 80.1 | 81.0 | -5% |  |
| direction changes in sight | /s | 2.60 | 2.42 | 2.49 | 1.77 | 2.22 | 17% |  |
| in a heart ring | % | 5.1 | 12.9 | 11.5 | 13.5 | 12.6 | -60% | we are lower |
| walk orders | % | 100.0 | 100.0 | 100.1 | 100.0 | 100.0 | 0% |  |
| shoot orders | % | 0.9 | 2.1 | 2.0 | 1.2 | 1.8 | -46% |  |
| direct walks | % | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | — |  |
| grenade charging | % | 0.7 | 6.1 | 6.2 | 1.1 | 4.5 | -84% | we are lower |

## 2. Controlled indirectly: items picked up and used

| stat | unit | fsnip_jb,fsnip_relh,fsnip_bassy-richard | co-gas-paintbot-relay-bassy-relh:v1 | co-gas-paintbot-bassy-richard:v1 | jb-pw-opt:v29 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| grenades picked | /cog | 1.34 | 1.22 | 1.19 | 1.64 | 1.35 | -1% |  |
| grenades thrown | /cog | 0.95 | 0.79 | 0.79 | 1.31 | 0.97 | -2% |  |
| grenade hits | /throw | 0.59 | 1.07 | 0.91 | 0.84 | 0.94 | -38% | we are lower |
| spray cans | /cog | 0.18 | 0.23 | 0.23 | 0.24 | 0.24 | -23% |  |
| spray bursts | /cog | 0.51 | 0.14 | 0.16 | 0.46 | 0.25 | 103% | we are higher |
| armor | /cog | 0.18 | 0.28 | 0.28 | 0.51 | 0.35 | -48% | we are lower |
| medkits | /cog | 0.61 | 0.27 | 0.21 | 0.83 | 0.44 | 40% | we are higher |
| mister heals | /cog | 0.11 | 0.53 | 0.61 | 0.38 | 0.50 | -79% | we are lower |
| glory hearts | /cog | 0.13 | 0.10 | 0.05 | 0.11 | 0.09 | 54% | we are higher |
| uniforms | /cog | 0.13 | 0.26 | 0.22 | 0.33 | 0.27 | -50% | we are lower |
| sniper rifles | /cog | 0.40 | 0.13 | 0.13 | 0.18 | 0.15 | 168% | we are higher |
| windex-misters | /cog | 0.08 | 0.17 | 0.17 | 0.19 | 0.18 | -52% | we are lower |
| radars | /cog | 0.13 | 0.14 | 0.16 | 0.36 | 0.22 | -39% | we are lower |

## 3. Outcomes: winning, killing, dying, territory

| stat | unit | fsnip_jb,fsnip_relh,fsnip_bassy-richard | co-gas-paintbot-relay-bassy-relh:v1 | co-gas-paintbot-bassy-richard:v1 | jb-pw-opt:v29 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| games |  | 60 | 20 | 20 | 20 | 20 | 200% | we are higher |
| win rate | % | 63.3 | 40.0 | 35.0 | 35.0 | 36.7 | 73% | we are higher |
| draw rate | % | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | — |  |
| glory per game |  | 323 | 337 | 214 | 187 | 246 | 32% | we are higher |
| glory per win |  | 511 | 841 | 610 | 533 | 662 | -23% |  |
| match length | s | 126 | 116 | 114 | 149 | 126 | 0% |  |
| deaths | /cog | 0.45 | 0.84 | 0.93 | 0.79 | 0.85 | -48% | we are lower |
| lives left | /cog | 1.11 | 0.31 | 0.15 | 0.42 | 0.30 | 275% | we are higher |
| first death | s | 70.0 | 66.1 | 71.1 | 73.6 | 70.3 | 0% |  |
| deaths in water | % | 4.2 | 11.9 | 6.1 | 13.5 | 10.5 | -60% | we are lower |
| deaths in trench | % | 1.4 | 1.5 | 2.0 | 0.8 | 1.4 | -2% |  |
| damage taken | /cog | 5.83 | 9.04 | 9.49 | 9.75 | 9.43 | -38% | we are lower |
| kills | /cog | 0.76 | 0.34 | 0.30 | 0.49 | 0.38 | 103% | we are higher |
| kill/death |  | 1.71 | 0.40 | 0.32 | 0.62 | 0.45 | 281% | we are higher |
| damage dealt | /cog | 9.43 | 5.24 | 5.11 | 7.14 | 5.83 | 62% | we are higher |
| gun kills | % | 63.6 | 27.8 | 45.8 | 28.2 | 33.9 | 87% | we are higher |
| grenade kills | % | 14.2 | 53.7 | 29.2 | 47.4 | 43.4 | -67% | we are lower |
| spray kills | % | 22.2 | 18.5 | 25.0 | 24.4 | 22.6 | -2% |  |
| captures | /cog | 0.68 | 1.16 | 1.21 | 0.97 | 1.12 | -39% | we are lower |

## Largest gaps in what we control (groups 1 and 2)

| stat | unit | ours | rivals' mean | gap | co-gas-paintbot-relay-bassy-relh:v1 / co-gas-paintbot-bassy-richard:v1 / jb-pw-opt:v29 |
|---|---|---:|---:|---:|---|
| shots fired standing | % | 100.0 | 4.2 | 2253% | 5.3 / 4.2 / 3.3 |
| accuracy 45+ m | % | 37.8 | 5.1 | 646% | 1.4 / 2.7 / 11.1 |
| accuracy with no enemy in view | % | 19.4 | 2.9 | 558% | 1.8 / 2.1 / 5.0 |
| accuracy 30-45 m | % | 53.4 | 11.6 | 360% | 1.8 / 1.9 / 31.1 |
| shots from above | % | 49.5 | 16.6 | 199% | 15.5 / 16.0 / 18.2 |
| accuracy 20-30 m | % | 24.9 | 8.5 | 192% | 3.8 / 5.2 / 16.7 |
| sniper rifles | /cog | 0.40 | 0.15 | 168% | 0.13 / 0.13 / 0.18 |
| gun accuracy | % | 31.7 | 12.6 | 151% | 8.5 / 10.2 / 19.2 |
| accuracy standing | % | 32.4 | 13.8 | 134% | 8.3 / 11.2 / 22.1 |
| accuracy from above | % | 35.9 | 15.4 | 134% | 9.9 / 13.9 / 22.3 |
| accuracy from below | % | 25.5 | 11.6 | 119% | 7.5 / 8.1 / 19.2 |
| first shot | s | 24.3 | 11.8 | 107% | 2.0 / 3.3 / 30.0 |
| spray bursts | /cog | 0.51 | 0.25 | 103% | 0.14 / 0.16 / 0.46 |
| hits from high ground | % | 26.0 | 13.4 | 94% | 13.0 / 12.8 / 14.4 |
| accuracy level | % | 30.2 | 15.8 | 91% | 11.5 / 12.7 / 23.3 |
| high ground | % | 31.3 | 16.7 | 87% | 16.9 / 17.8 / 15.3 |
| grenade charging | % | 0.7 | 4.5 | -84% | 6.1 / 6.2 / 1.1 |
| wading | % | 2.4 | 14.2 | -83% | 13.2 / 12.5 / 17.1 |
| mister heals | /cog | 0.11 | 0.50 | -79% | 0.53 / 0.61 / 0.38 |
| sneaking | % | 9.2 | 5.3 | 75% | 5.7 / 6.4 / 3.6 |
| accuracy 10-20 m | % | 30.8 | 18.1 | 70% | 17.3 / 18.8 / 18.4 |
| miss: aim off a still target | % | 2.3 | 7.2 | -68% | 6.9 / 7.6 / 7.1 |
| miss: cover in the way | % | 4.0 | 11.4 | -65% | 11.4 / 12.5 / 10.2 |
| in a heart ring | % | 5.1 | 12.6 | -60% | 12.9 / 11.5 / 13.5 |
| glory hearts | /cog | 0.13 | 0.09 | 54% | 0.10 / 0.05 / 0.11 |
| windex-misters | /cog | 0.08 | 0.18 | -52% | 0.17 / 0.17 / 0.19 |
| accuracy 0-10 m | % | 49.1 | 32.2 | 52% | 31.8 / 30.4 / 34.5 |
| uniforms | /cog | 0.13 | 0.27 | -50% | 0.26 / 0.22 / 0.33 |
| armor | /cog | 0.18 | 0.35 | -48% | 0.28 / 0.28 / 0.51 |
| shots with no enemy in view | % | 5.3 | 9.6 | -44% | 9.5 / 8.2 / 11.1 |
| medkits | /cog | 0.61 | 0.44 | 40% | 0.27 / 0.21 / 0.83 |
| radars | /cog | 0.13 | 0.22 | -39% | 0.14 / 0.16 / 0.36 |
| grenade hits | /throw | 0.59 | 0.94 | -38% | 1.07 / 0.91 / 0.84 |
| range under 20 m | % | 63.3 | 49.0 | 29% | 38.1 / 40.2 / 68.8 |
| miss: target moved off the line | % | 24.6 | 34.0 | -28% | 34.3 / 31.8 / 35.8 |
| gun shots | /min | 13.3 | 18.1 | -27% | 24.0 / 20.8 / 9.5 |
