# fast: lake0 variant vs the three leaders (60 games)

60 replays re-simulated with the hosted engine rules (0 state-hash mismatches, 0 replays without a roster skipped). Columns are policy versions, ordered by glory per game. Replay rows are means over the policy's seat-games unless noted.

The first column is ours (flake0_jb,flake0_relh,flake0_bassy-richard). Gap = (ours - rivals' mean) / rivals' mean. A row is flagged when the gap is at least 25% (and, for % rows, at least 2 points).

## 1. Controlled directly: movement, footwork, aiming, shooting

| stat | unit | flake0_jb,flake0_relh,flake0_bassy-richard | co-gas-paintbot-bassy-richard:v1 | jb-pw-opt:v29 | co-gas-paintbot-relay-bassy-relh:v1 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| friendly damage | /cog | 1.71 | 1.59 | 1.51 | 1.28 | 1.46 | 17% |  |
| enemy in view | % | 64.7 | 68.6 | 61.6 | 73.9 | 68.0 | -5% |  |
| gun shots | /min | 15.6 | 22.1 | 11.7 | 23.5 | 19.1 | -19% |  |
| gun accuracy | % | 29.7 | 10.8 | 19.3 | 10.1 | 13.4 | 121% | we are higher |
| first shot | s | 19.8 | 3.5 | 20.6 | 2.4 | 8.8 | 124% | we are higher |
| shots with no enemy in view | % | 6.1 | 8.5 | 8.2 | 7.1 | 7.9 | -23% |  |
| accuracy with no enemy in view | % | 15.4 | 4.4 | 8.1 | 3.4 | 5.3 | 191% | we are higher |
| range under 20 m | % | 67.6 | 38.3 | 68.1 | 39.9 | 48.8 | 39% | we are higher |
| accuracy 0-10 m | % | 51.2 | 36.2 | 28.9 | 36.4 | 33.8 | 51% | we are higher |
| accuracy 10-20 m | % | 30.7 | 19.6 | 21.1 | 18.8 | 19.9 | 55% | we are higher |
| accuracy 20-30 m | % | 21.8 | 4.9 | 14.6 | 4.3 | 8.0 | 173% | we are higher |
| accuracy 30-45 m | % | 41.3 | 4.0 | 24.5 | 2.1 | 10.2 | 305% | we are higher |
| accuracy 45+ m | % | 36.2 | 1.6 | 0.0 | 1.5 | 1.0 | 3427% | we are higher |
| shots fired standing | % | 100.0 | 5.0 | 3.7 | 4.0 | 4.3 | 2245% | we are higher |
| accuracy standing | % | 30.6 | 6.6 | 19.3 | 5.8 | 10.6 | 190% | we are higher |
| accuracy moving | % | — | 11.7 | 20.4 | 10.9 | 14.3 | — |  |
| shots from above | % | 55.4 | 19.1 | 18.9 | 16.8 | 18.2 | 203% | we are higher |
| accuracy from above | % | 33.8 | 11.5 | 29.0 | 12.4 | 17.6 | 92% | we are higher |
| accuracy level | % | 29.0 | 13.1 | 22.9 | 12.6 | 16.2 | 79% | we are higher |
| accuracy from below | % | 21.5 | 10.1 | 16.4 | 8.8 | 11.8 | 83% | we are higher |
| hits from high ground | % | 24.8 | 10.3 | 11.0 | 8.6 | 9.9 | 149% | we are higher |
| hits from trench | % | 0.4 | 1.1 | 1.1 | 2.2 | 1.5 | -70% |  |
| miss: cover in the way | % | 3.9 | 12.3 | 9.2 | 12.4 | 11.3 | -66% | we are lower |
| miss: target moved off the line | % | 21.8 | 31.2 | 31.9 | 28.2 | 30.4 | -28% | we are lower |
| miss: aim off a still target | % | 1.9 | 6.9 | 8.3 | 5.3 | 6.8 | -72% | we are lower |
| miss: in radius, no hit | % | 35.2 | 31.6 | 24.6 | 36.9 | 31.0 | 13% |  |
| miss: teammate in the way | % | 6.3 | 6.0 | 4.5 | 5.9 | 5.5 | 15% |  |
| miss: nobody near the line | % | 0.3 | 0.6 | 1.1 | 0.6 | 0.8 | -65% |  |
| speed | m/s | 4.80 | 4.77 | 4.70 | 4.73 | 4.74 | 1% |  |
| moving | % | 83.4 | 89.5 | 86.5 | 91.0 | 89.0 | -6% |  |
| wading | % | 8.5 | 16.4 | 17.4 | 19.8 | 17.8 | -53% | we are lower |
| sneaking | % | 9.0 | 7.2 | 3.1 | 5.1 | 5.1 | 76% | we are higher |
| in trench | % | 1.2 | 1.9 | 1.6 | 2.2 | 1.9 | -39% |  |
| high ground | % | 24.8 | 18.9 | 12.8 | 16.0 | 15.9 | 56% | we are higher |
| exact compass steps | % | 4.9 | 4.8 | 4.4 | 4.3 | 4.5 | 9% |  |
| nearest teammate | m | 10.6 | 9.0 | 10.1 | 10.0 | 9.7 | 9% |  |
| lead on a moving target | ticks | 4.1 | 4.3 | 3.9 | 4.2 | 4.1 | -2% |  |
| sight run length | ticks | 21.2 | 19.9 | 13.8 | 19.8 | 17.8 | 19% |  |
| new sightings | /min | 106.4 | 102.9 | 135.8 | 116.4 | 118.3 | -10% |  |
| shots at a target in view | % | 99.4 | 96.6 | 97.5 | 95.7 | 96.6 | 3% |  |
| shots at a tracked target | % | 91.9 | 79.9 | 72.9 | 79.8 | 77.5 | 19% |  |
| unled shots at movers | % | 17.3 | 18.0 | 20.7 | 18.0 | 18.9 | -8% |  |
| standing with an enemy in sight | % | 22.7 | 24.1 | 30.0 | 26.6 | 26.9 | -16% |  |
| run length in sight | ticks | 5.8 | 6.3 | 5.5 | 6.6 | 6.1 | -5% |  |
| runs ended by reversing | % | 72.0 | 78.6 | 80.5 | 78.3 | 79.1 | -9% |  |
| direction changes in sight | /s | 2.39 | 2.13 | 2.04 | 2.00 | 2.05 | 16% |  |
| in a heart ring | % | 4.5 | 11.7 | 11.6 | 9.7 | 11.0 | -59% | we are lower |
| walk orders | % | 100.0 | 100.1 | 100.0 | 100.1 | 100.1 | 0% |  |
| shoot orders | % | 1.1 | 2.0 | 1.4 | 2.1 | 1.8 | -39% |  |
| direct walks | % | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | — |  |
| grenade charging | % | 1.0 | 8.5 | 1.0 | 6.2 | 5.2 | -82% | we are lower |

## 2. Controlled indirectly: items picked up and used

| stat | unit | flake0_jb,flake0_relh,flake0_bassy-richard | co-gas-paintbot-bassy-richard:v1 | jb-pw-opt:v29 | co-gas-paintbot-relay-bassy-relh:v1 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| grenades picked | /cog | 1.25 | 1.28 | 1.38 | 1.08 | 1.25 | 0% |  |
| grenades thrown | /cog | 0.92 | 0.95 | 1.08 | 0.81 | 0.95 | -3% |  |
| self-destructs | /cog | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | — |  |
| grenade hits | /throw | 0.65 | 1.02 | 0.87 | 0.98 | 0.96 | -32% | we are lower |
| spray cans | /cog | 0.23 | 0.25 | 0.22 | 0.23 | 0.23 | -3% |  |
| spray bursts | /cog | 0.52 | 0.14 | 0.73 | 0.08 | 0.32 | 62% | we are higher |
| armor | /cog | 0.09 | 0.25 | 0.42 | 0.29 | 0.32 | -74% | we are lower |
| medkits | /cog | 0.72 | 0.22 | 0.61 | 0.22 | 0.35 | 108% | we are higher |
| mister heals | /cog | 0.14 | 0.35 | 0.37 | 0.33 | 0.35 | -61% | we are lower |
| glory hearts | /cog | 0.14 | 0.08 | 0.12 | 0.06 | 0.09 | 55% | we are higher |
| uniforms | /cog | 0.19 | 0.23 | 0.25 | 0.17 | 0.22 | -13% |  |
| sniper rifles | /cog | 0.14 | 0.17 | 0.17 | 0.14 | 0.16 | -12% |  |
| windex-misters | /cog | 0.10 | 0.12 | 0.15 | 0.13 | 0.14 | -29% | we are lower |
| radars | /cog | 0.23 | 0.11 | 0.20 | 0.10 | 0.14 | 67% | we are higher |

## 3. Outcomes: winning, killing, dying, territory

| stat | unit | flake0_jb,flake0_relh,flake0_bassy-richard | co-gas-paintbot-bassy-richard:v1 | jb-pw-opt:v29 | co-gas-paintbot-relay-bassy-relh:v1 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| games |  | 60 | 20 | 20 | 20 | 20 | 200% | we are higher |
| win rate | % | 55.0 | 55.0 | 45.0 | 35.0 | 45.0 | 22% |  |
| draw rate | % | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | — |  |
| glory per game |  | 285 | 486 | 396 | 394 | 425 | -33% | we are lower |
| glory per win |  | 519 | 883 | 880 | 1125 | 963 | -46% | we are lower |
| match length | s | 122 | 113 | 145 | 107 | 122 | 0% |  |
| deaths | /cog | 0.50 | 0.88 | 0.85 | 0.93 | 0.89 | -44% | we are lower |
| lives left | /cog | 1.00 | 0.24 | 0.30 | 0.15 | 0.23 | 338% | we are higher |
| first death | s | 71.2 | 64.3 | 63.5 | 60.3 | 62.7 | 14% |  |
| deaths in water | % | 15.5 | 19.1 | 29.4 | 14.9 | 21.1 | -27% | we are lower |
| deaths in trench | % | 0.8 | 0.7 | 1.5 | 2.7 | 1.6 | -49% |  |
| damage taken | /cog | 6.35 | 9.16 | 10.04 | 9.82 | 9.68 | -34% | we are lower |
| kills | /cog | 0.82 | 0.39 | 0.53 | 0.28 | 0.40 | 105% | we are higher |
| kill/death |  | 1.64 | 0.44 | 0.62 | 0.30 | 0.45 | 261% | we are higher |
| damage dealt | /cog | 9.68 | 6.06 | 7.60 | 5.38 | 6.35 | 52% | we are higher |
| gun kills | % | 66.1 | 38.7 | 34.1 | 40.9 | 37.9 | 74% | we are higher |
| grenade kills | % | 16.3 | 37.1 | 25.9 | 43.2 | 35.4 | -54% | we are lower |
| spray kills | % | 17.6 | 24.2 | 40.0 | 15.9 | 26.7 | -34% | we are lower |
| captures | /cog | 0.63 | 1.23 | 0.94 | 1.24 | 1.13 | -44% | we are lower |

## Largest gaps in what we control (groups 1 and 2)

| stat | unit | ours | rivals' mean | gap | co-gas-paintbot-bassy-richard:v1 / jb-pw-opt:v29 / co-gas-paintbot-relay-bassy-relh:v1 |
|---|---|---:|---:|---:|---|
| accuracy 45+ m | % | 36.2 | 1.0 | 3427% | 1.6 / 0.0 / 1.5 |
| shots fired standing | % | 100.0 | 4.3 | 2245% | 5.0 / 3.7 / 4.0 |
| accuracy 30-45 m | % | 41.3 | 10.2 | 305% | 4.0 / 24.5 / 2.1 |
| shots from above | % | 55.4 | 18.2 | 203% | 19.1 / 18.9 / 16.8 |
| accuracy with no enemy in view | % | 15.4 | 5.3 | 191% | 4.4 / 8.1 / 3.4 |
| accuracy standing | % | 30.6 | 10.6 | 190% | 6.6 / 19.3 / 5.8 |
| accuracy 20-30 m | % | 21.8 | 8.0 | 173% | 4.9 / 14.6 / 4.3 |
| hits from high ground | % | 24.8 | 9.9 | 149% | 10.3 / 11.0 / 8.6 |
| first shot | s | 19.8 | 8.8 | 124% | 3.5 / 20.6 / 2.4 |
| gun accuracy | % | 29.7 | 13.4 | 121% | 10.8 / 19.3 / 10.1 |
| medkits | /cog | 0.72 | 0.35 | 108% | 0.22 / 0.61 / 0.22 |
| accuracy from above | % | 33.8 | 17.6 | 92% | 11.5 / 29.0 / 12.4 |
| accuracy from below | % | 21.5 | 11.8 | 83% | 10.1 / 16.4 / 8.8 |
| grenade charging | % | 1.0 | 5.2 | -82% | 8.5 / 1.0 / 6.2 |
| accuracy level | % | 29.0 | 16.2 | 79% | 13.1 / 22.9 / 12.6 |
| sneaking | % | 9.0 | 5.1 | 76% | 7.2 / 3.1 / 5.1 |
| armor | /cog | 0.09 | 0.32 | -74% | 0.25 / 0.42 / 0.29 |
| miss: aim off a still target | % | 1.9 | 6.8 | -72% | 6.9 / 8.3 / 5.3 |
| radars | /cog | 0.23 | 0.14 | 67% | 0.11 / 0.20 / 0.10 |
| miss: cover in the way | % | 3.9 | 11.3 | -66% | 12.3 / 9.2 / 12.4 |
| spray bursts | /cog | 0.52 | 0.32 | 62% | 0.14 / 0.73 / 0.08 |
| mister heals | /cog | 0.14 | 0.35 | -61% | 0.35 / 0.37 / 0.33 |
| in a heart ring | % | 4.5 | 11.0 | -59% | 11.7 / 11.6 / 9.7 |
| high ground | % | 24.8 | 15.9 | 56% | 18.9 / 12.8 / 16.0 |
| glory hearts | /cog | 0.14 | 0.09 | 55% | 0.08 / 0.12 / 0.06 |
| accuracy 10-20 m | % | 30.7 | 19.9 | 55% | 19.6 / 21.1 / 18.8 |
| wading | % | 8.5 | 17.8 | -53% | 16.4 / 17.4 / 19.8 |
| accuracy 0-10 m | % | 51.2 | 33.8 | 51% | 36.2 / 28.9 / 36.4 |
| range under 20 m | % | 67.6 | 48.8 | 39% | 38.3 / 68.1 / 39.9 |
| grenade hits | /throw | 0.65 | 0.96 | -32% | 1.02 / 0.87 / 0.98 |
| windex-misters | /cog | 0.10 | 0.14 | -29% | 0.12 / 0.15 / 0.13 |
| miss: target moved off the line | % | 21.8 | 30.4 | -28% | 31.2 / 31.9 / 28.2 |
