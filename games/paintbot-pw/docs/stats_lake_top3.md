# fast: lake variant vs the three leaders (60 games)

60 replays re-simulated with the hosted engine rules (0 state-hash mismatches, 0 replays without a roster skipped). Columns are policy versions, ordered by glory per game. Replay rows are means over the policy's seat-games unless noted.

The first column is ours (flake_jb,flake_relh,flake_bassy-richard). Gap = (ours - rivals' mean) / rivals' mean. A row is flagged when the gap is at least 25% (and, for % rows, at least 2 points).

## 1. Controlled directly: movement, footwork, aiming, shooting

| stat | unit | flake_jb,flake_relh,flake_bassy-richard | co-gas-paintbot-bassy-richard:v1 | jb-pw-opt:v29 | co-gas-paintbot-relay-bassy-relh:v1 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| friendly damage | /cog | 1.44 | 1.68 | 1.37 | 1.77 | 1.60 | -11% |  |
| enemy in view | % | 67.8 | 71.1 | 58.4 | 74.6 | 68.0 | 0% |  |
| gun shots | /min | 14.3 | 25.0 | 10.4 | 25.1 | 20.2 | -29% | we are lower |
| gun accuracy | % | 32.2 | 11.1 | 22.9 | 11.8 | 15.3 | 111% | we are higher |
| first shot | s | 20.5 | 2.2 | 18.5 | 1.5 | 7.4 | 178% | we are higher |
| shots with no enemy in view | % | 6.4 | 9.5 | 9.9 | 8.6 | 9.3 | -31% | we are lower |
| accuracy with no enemy in view | % | 13.5 | 3.5 | 8.6 | 4.2 | 5.4 | 151% | we are higher |
| range under 20 m | % | 70.2 | 43.0 | 70.1 | 41.0 | 51.4 | 37% | we are higher |
| accuracy 0-10 m | % | 57.3 | 36.8 | 40.1 | 38.7 | 38.5 | 49% | we are higher |
| accuracy 10-20 m | % | 32.6 | 20.0 | 22.5 | 22.9 | 21.8 | 50% | we are higher |
| accuracy 20-30 m | % | 23.2 | 4.6 | 17.8 | 3.9 | 8.8 | 165% | we are higher |
| accuracy 30-45 m | % | 39.5 | 0.6 | 37.7 | 1.3 | 13.2 | 199% | we are higher |
| accuracy 45+ m | % | 25.6 | 1.5 | 14.6 | 2.1 | 6.1 | 321% | we are higher |
| shots fired standing | % | 100.0 | 5.2 | 4.0 | 4.8 | 4.7 | 2047% | we are higher |
| accuracy standing | % | 33.5 | 10.9 | 16.3 | 10.2 | 12.5 | 168% | we are higher |
| accuracy moving | % | — | 12.0 | 24.9 | 12.6 | 16.5 | — |  |
| shots from above | % | 53.6 | 30.3 | 17.4 | 31.1 | 26.3 | 104% | we are higher |
| accuracy from above | % | 38.2 | 10.7 | 31.4 | 11.7 | 17.9 | 113% | we are higher |
| accuracy level | % | 33.5 | 16.9 | 27.5 | 17.3 | 20.6 | 63% | we are higher |
| accuracy from below | % | 20.4 | 9.7 | 20.6 | 9.5 | 13.3 | 54% | we are higher |
| hits from high ground | % | 24.0 | 14.6 | 7.5 | 15.9 | 12.7 | 89% | we are higher |
| hits from trench | % | 1.0 | 2.9 | 1.6 | 1.8 | 2.1 | -53% |  |
| miss: cover in the way | % | 3.6 | 12.9 | 7.7 | 13.1 | 11.3 | -68% | we are lower |
| miss: target moved off the line | % | 19.9 | 26.2 | 30.0 | 25.9 | 27.3 | -27% | we are lower |
| miss: aim off a still target | % | 1.8 | 6.3 | 7.8 | 6.6 | 6.9 | -73% | we are lower |
| miss: in radius, no hit | % | 35.3 | 36.5 | 24.9 | 35.9 | 32.4 | 9% |  |
| miss: teammate in the way | % | 5.5 | 5.5 | 3.8 | 5.5 | 4.9 | 13% |  |
| miss: nobody near the line | % | 0.4 | 0.7 | 1.3 | 0.6 | 0.9 | -52% |  |
| speed | m/s | 4.54 | 4.52 | 4.72 | 4.77 | 4.67 | -3% |  |
| moving | % | 82.5 | 88.9 | 87.1 | 90.7 | 88.9 | -7% |  |
| wading | % | 14.3 | 22.3 | 16.1 | 19.1 | 19.2 | -26% | we are lower |
| sneaking | % | 12.9 | 5.5 | 8.7 | 5.4 | 6.6 | 97% | we are higher |
| in trench | % | 1.5 | 2.6 | 1.8 | 2.4 | 2.3 | -33% |  |
| high ground | % | 22.7 | 19.5 | 13.3 | 20.3 | 17.7 | 28% | we are higher |
| exact compass steps | % | 4.7 | 4.6 | 4.5 | 5.2 | 4.7 | -2% |  |
| nearest teammate | m | 11.1 | 8.8 | 8.9 | 9.3 | 9.0 | 24% |  |
| lead on a moving target | ticks | 4.0 | 4.4 | 4.1 | 4.3 | 4.3 | -5% |  |
| sight run length | ticks | 20.8 | 18.9 | 13.6 | 19.2 | 17.3 | 20% |  |
| new sightings | /min | 112.1 | 107.5 | 117.4 | 111.7 | 112.2 | 0% |  |
| shots at a target in view | % | 99.5 | 95.5 | 98.3 | 95.7 | 96.5 | 3% |  |
| shots at a tracked target | % | 92.3 | 77.6 | 72.4 | 79.7 | 76.6 | 21% |  |
| unled shots at movers | % | 17.9 | 18.8 | 20.8 | 18.0 | 19.2 | -7% |  |
| standing with an enemy in sight | % | 26.9 | 33.3 | 28.4 | 29.1 | 30.3 | -11% |  |
| run length in sight | ticks | 5.8 | 5.6 | 5.7 | 5.9 | 5.8 | 1% |  |
| runs ended by reversing | % | 72.8 | 78.4 | 75.5 | 79.0 | 77.6 | -6% |  |
| direction changes in sight | /s | 2.26 | 2.10 | 1.74 | 2.13 | 1.99 | 14% |  |
| in a heart ring | % | 6.5 | 12.4 | 12.1 | 11.6 | 12.0 | -46% | we are lower |
| walk orders | % | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 0% |  |
| shoot orders | % | 1.0 | 2.1 | 1.2 | 2.2 | 1.8 | -44% |  |
| direct walks | % | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | — |  |
| grenade charging | % | 0.8 | 7.4 | 1.2 | 7.9 | 5.5 | -85% | we are lower |

## 2. Controlled indirectly: items picked up and used

| stat | unit | flake_jb,flake_relh,flake_bassy-richard | co-gas-paintbot-bassy-richard:v1 | jb-pw-opt:v29 | co-gas-paintbot-relay-bassy-relh:v1 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| grenades picked | /cog | 1.01 | 1.36 | 1.92 | 1.40 | 1.56 | -35% | we are lower |
| grenades thrown | /cog | 0.76 | 1.00 | 1.49 | 1.08 | 1.19 | -37% | we are lower |
| self-destructs | /cog | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | — |  |
| grenade hits | /throw | 0.56 | 1.06 | 0.90 | 0.98 | 0.98 | -43% | we are lower |
| spray cans | /cog | 0.21 | 0.24 | 0.28 | 0.25 | 0.25 | -18% |  |
| spray bursts | /cog | 0.50 | 0.18 | 0.66 | 0.24 | 0.36 | 38% | we are higher |
| armor | /cog | 0.07 | 0.33 | 0.54 | 0.33 | 0.40 | -82% | we are lower |
| medkits | /cog | 0.74 | 0.42 | 0.85 | 0.35 | 0.54 | 37% | we are higher |
| mister heals | /cog | 0.55 | 0.65 | 0.28 | 0.66 | 0.53 | 4% |  |
| glory hearts | /cog | 0.10 | 0.07 | 0.14 | 0.08 | 0.10 | 6% |  |
| uniforms | /cog | 0.17 | 0.22 | 0.21 | 0.26 | 0.23 | -25% | we are lower |
| sniper rifles | /cog | 0.15 | 0.09 | 0.26 | 0.09 | 0.15 | -1% |  |
| windex-misters | /cog | 0.21 | 0.19 | 0.20 | 0.23 | 0.20 | 3% |  |
| radars | /cog | 0.23 | 0.11 | 0.26 | 0.07 | 0.15 | 54% | we are higher |

## 3. Outcomes: winning, killing, dying, territory

| stat | unit | flake_jb,flake_relh,flake_bassy-richard | co-gas-paintbot-bassy-richard:v1 | jb-pw-opt:v29 | co-gas-paintbot-relay-bassy-relh:v1 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| games |  | 60 | 20 | 20 | 20 | 20 | 200% | we are higher |
| win rate | % | 35.0 | 55.0 | 85.0 | 55.0 | 65.0 | -46% | we are lower |
| draw rate | % | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | — |  |
| glory per game |  | 181 | 478 | 462 | 394 | 445 | -59% | we are lower |
| glory per win |  | 518 | 870 | 544 | 716 | 710 | -27% | we are lower |
| match length | s | 139 | 136 | 145 | 136 | 139 | 0% |  |
| deaths | /cog | 0.65 | 0.83 | 0.53 | 0.84 | 0.73 | -11% |  |
| lives left | /cog | 0.69 | 0.34 | 0.94 | 0.33 | 0.53 | 30% | we are higher |
| first death | s | 67.9 | 70.3 | 69.5 | 73.1 | 71.0 | -4% |  |
| deaths in water | % | 21.7 | 32.3 | 32.9 | 29.9 | 31.7 | -32% | we are lower |
| deaths in trench | % | 1.0 | 3.0 | 0.0 | 2.2 | 1.7 | -45% |  |
| damage taken | /cog | 8.50 | 10.08 | 8.00 | 9.61 | 9.23 | -8% |  |
| kills | /cog | 0.66 | 0.43 | 0.76 | 0.51 | 0.56 | 17% |  |
| kill/death |  | 1.01 | 0.52 | 1.42 | 0.60 | 0.85 | 19% |  |
| damage dealt | /cog | 9.23 | 7.56 | 9.77 | 8.16 | 8.50 | 9% |  |
| gun kills | % | 61.8 | 43.5 | 33.9 | 48.1 | 41.8 | 48% | we are higher |
| grenade kills | % | 15.1 | 27.5 | 36.4 | 24.7 | 29.5 | -49% | we are lower |
| spray kills | % | 23.0 | 29.0 | 29.8 | 27.2 | 28.6 | -20% |  |
| captures | /cog | 0.77 | 1.34 | 1.30 | 1.37 | 1.34 | -43% | we are lower |

## Largest gaps in what we control (groups 1 and 2)

| stat | unit | ours | rivals' mean | gap | co-gas-paintbot-bassy-richard:v1 / jb-pw-opt:v29 / co-gas-paintbot-relay-bassy-relh:v1 |
|---|---|---:|---:|---:|---|
| shots fired standing | % | 100.0 | 4.7 | 2047% | 5.2 / 4.0 / 4.8 |
| accuracy 45+ m | % | 25.6 | 6.1 | 321% | 1.5 / 14.6 / 2.1 |
| accuracy 30-45 m | % | 39.5 | 13.2 | 199% | 0.6 / 37.7 / 1.3 |
| first shot | s | 20.5 | 7.4 | 178% | 2.2 / 18.5 / 1.5 |
| accuracy standing | % | 33.5 | 12.5 | 168% | 10.9 / 16.3 / 10.2 |
| accuracy 20-30 m | % | 23.2 | 8.8 | 165% | 4.6 / 17.8 / 3.9 |
| accuracy with no enemy in view | % | 13.5 | 5.4 | 151% | 3.5 / 8.6 / 4.2 |
| accuracy from above | % | 38.2 | 17.9 | 113% | 10.7 / 31.4 / 11.7 |
| gun accuracy | % | 32.2 | 15.3 | 111% | 11.1 / 22.9 / 11.8 |
| shots from above | % | 53.6 | 26.3 | 104% | 30.3 / 17.4 / 31.1 |
| sneaking | % | 12.9 | 6.6 | 97% | 5.5 / 8.7 / 5.4 |
| hits from high ground | % | 24.0 | 12.7 | 89% | 14.6 / 7.5 / 15.9 |
| grenade charging | % | 0.8 | 5.5 | -85% | 7.4 / 1.2 / 7.9 |
| armor | /cog | 0.07 | 0.40 | -82% | 0.33 / 0.54 / 0.33 |
| miss: aim off a still target | % | 1.8 | 6.9 | -73% | 6.3 / 7.8 / 6.6 |
| miss: cover in the way | % | 3.6 | 11.3 | -68% | 12.9 / 7.7 / 13.1 |
| accuracy level | % | 33.5 | 20.6 | 63% | 16.9 / 27.5 / 17.3 |
| radars | /cog | 0.23 | 0.15 | 54% | 0.11 / 0.26 / 0.07 |
| accuracy from below | % | 20.4 | 13.3 | 54% | 9.7 / 20.6 / 9.5 |
| accuracy 10-20 m | % | 32.6 | 21.8 | 50% | 20.0 / 22.5 / 22.9 |
| accuracy 0-10 m | % | 57.3 | 38.5 | 49% | 36.8 / 40.1 / 38.7 |
| in a heart ring | % | 6.5 | 12.0 | -46% | 12.4 / 12.1 / 11.6 |
| grenade hits | /throw | 0.56 | 0.98 | -43% | 1.06 / 0.90 / 0.98 |
| spray bursts | /cog | 0.50 | 0.36 | 38% | 0.18 / 0.66 / 0.24 |
| range under 20 m | % | 70.2 | 51.4 | 37% | 43.0 / 70.1 / 41.0 |
| medkits | /cog | 0.74 | 0.54 | 37% | 0.42 / 0.85 / 0.35 |
| grenades thrown | /cog | 0.76 | 1.19 | -37% | 1.00 / 1.49 / 1.08 |
| grenades picked | /cog | 1.01 | 1.56 | -35% | 1.36 / 1.92 / 1.40 |
| shots with no enemy in view | % | 6.4 | 9.3 | -31% | 9.5 / 9.9 / 8.6 |
| gun shots | /min | 14.3 | 20.2 | -29% | 25.0 / 10.4 / 25.1 |
| high ground | % | 22.7 | 17.7 | 28% | 19.5 / 13.3 / 20.3 |
| miss: target moved off the line | % | 19.9 | 27.3 | -27% | 26.2 / 30.0 / 25.9 |
| wading | % | 14.3 | 19.2 | -26% | 22.3 / 16.1 / 19.1 |
| uniforms | /cog | 0.17 | 0.23 | -25% | 0.22 / 0.21 / 0.26 |
