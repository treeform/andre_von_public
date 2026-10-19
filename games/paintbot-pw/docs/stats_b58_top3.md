# fast 0.3.124: zhar v58 vs jb-pw-opt v29 / bassy-richard v1 / relay-bassy-relh v1 (300 games, five seed blocks)

180 replays re-simulated with the hosted engine rules (0 state-hash mismatches, 0 replays without a roster skipped). Columns are policy versions, ordered by glory per game. Replay rows are means over the policy's seat-games unless noted.

The first column is ours (b58). Gap = (ours - rivals' mean) / rivals' mean. A row is flagged when the gap is at least 25% (and, for % rows, at least 2 points).

## 1. Controlled directly: movement, footwork, aiming, shooting

| stat | unit | b58 | co-gas-paintbot-relay-bassy-relh:v1 | co-gas-paintbot-bassy-richard:v1 | jb-pw-opt:v29 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| friendly damage | /cog | 1.83 | 1.81 | 1.88 | 1.56 | 1.75 | 5% |  |
| enemy in view | % | 61.3 | 67.3 | 65.5 | 54.5 | 62.4 | -2% |  |
| gun shots | /min | 13.8 | 23.2 | 22.1 | 9.7 | 18.3 | -25% |  |
| gun accuracy | % | 29.1 | 9.0 | 9.0 | 18.4 | 12.1 | 139% | we are higher |
| first shot | s | 26.1 | 2.3 | 3.5 | 29.2 | 11.7 | 124% | we are higher |
| shots with no enemy in view | % | 5.8 | 9.8 | 10.2 | 10.0 | 10.0 | -43% | we are lower |
| accuracy with no enemy in view | % | 13.7 | 3.4 | 2.3 | 5.2 | 3.7 | 274% | we are higher |
| range under 20 m | % | 67.1 | 38.1 | 37.2 | 70.1 | 48.4 | 39% | we are higher |
| accuracy 0-10 m | % | 47.3 | 32.3 | 31.1 | 31.5 | 31.6 | 49% | we are higher |
| accuracy 10-20 m | % | 30.4 | 17.9 | 18.4 | 18.7 | 18.3 | 66% | we are higher |
| accuracy 20-30 m | % | 21.4 | 4.0 | 4.4 | 14.7 | 7.7 | 176% | we are higher |
| accuracy 30-45 m | % | 39.7 | 2.1 | 1.8 | 24.0 | 9.3 | 327% | we are higher |
| accuracy 45+ m | % | 24.0 | 0.8 | 1.0 | 16.8 | 6.2 | 287% | we are higher |
| shots fired standing | % | 100.0 | 4.7 | 4.1 | 2.8 | 3.9 | 2483% | we are higher |
| accuracy standing | % | 30.0 | 5.5 | 7.4 | 15.6 | 9.5 | 216% | we are higher |
| accuracy moving | % | — | 9.9 | 9.8 | 20.0 | 13.2 | — |  |
| shots from above | % | 51.1 | 18.7 | 20.7 | 16.3 | 18.6 | 175% | we are higher |
| accuracy from above | % | 33.3 | 9.9 | 11.1 | 20.3 | 13.8 | 142% | we are higher |
| accuracy level | % | 28.7 | 11.9 | 11.7 | 23.8 | 15.8 | 82% | we are higher |
| accuracy from below | % | 21.6 | 7.8 | 7.7 | 17.8 | 11.1 | 95% | we are higher |
| hits from high ground | % | 27.0 | 14.9 | 18.2 | 12.3 | 15.1 | 78% | we are higher |
| hits from trench | % | 0.4 | 1.8 | 1.2 | 1.3 | 1.4 | -71% |  |
| miss: cover in the way | % | 4.3 | 12.3 | 13.1 | 9.8 | 11.7 | -63% | we are lower |
| miss: target moved off the line | % | 24.4 | 30.3 | 29.8 | 34.7 | 31.6 | -23% |  |
| miss: aim off a still target | % | 2.3 | 6.9 | 6.5 | 7.7 | 7.0 | -68% | we are lower |
| miss: in radius, no hit | % | 33.5 | 33.9 | 33.9 | 22.2 | 30.0 | 12% |  |
| miss: teammate in the way | % | 5.3 | 6.0 | 5.9 | 4.5 | 5.5 | -4% |  |
| miss: nobody near the line | % | 0.3 | 0.9 | 1.0 | 1.2 | 1.0 | -74% |  |
| speed | m/s | 4.99 | 4.87 | 4.92 | 4.49 | 4.76 | 5% |  |
| moving | % | 84.1 | 89.2 | 89.8 | 83.5 | 87.5 | -4% |  |
| wading | % | 3.1 | 15.0 | 14.3 | 18.7 | 16.0 | -80% | we are lower |
| sneaking | % | 9.9 | 6.6 | 6.6 | 3.9 | 5.7 | 74% | we are higher |
| in trench | % | 0.7 | 1.9 | 1.7 | 1.3 | 1.6 | -56% |  |
| high ground | % | 30.0 | 19.6 | 20.0 | 14.2 | 17.9 | 67% | we are higher |
| exact compass steps | % | 5.1 | 4.8 | 5.0 | 4.2 | 4.6 | 10% |  |
| nearest teammate | m | 9.8 | 9.0 | 9.7 | 10.7 | 9.8 | 0% |  |
| lead on a moving target | ticks | 4.1 | 4.1 | 4.2 | 4.0 | 4.1 | 1% |  |
| sight run length | ticks | 18.5 | 17.6 | 17.6 | 12.7 | 16.0 | 16% |  |
| new sightings | /min | 112.9 | 115.2 | 114.3 | 123.3 | 117.6 | -4% |  |
| shots at a target in view | % | 99.3 | 96.0 | 95.9 | 97.8 | 96.6 | 3% |  |
| shots at a tracked target | % | 91.8 | 78.1 | 78.2 | 72.3 | 76.2 | 21% |  |
| unled shots at movers | % | 15.8 | 19.4 | 18.0 | 20.2 | 19.2 | -18% |  |
| standing with an enemy in sight | % | 17.7 | 18.6 | 17.1 | 28.6 | 21.4 | -17% |  |
| run length in sight | ticks | 5.6 | 6.2 | 6.1 | 6.3 | 6.2 | -9% |  |
| runs ended by reversing | % | 73.4 | 79.7 | 80.5 | 80.9 | 80.4 | -9% |  |
| direction changes in sight | /s | 2.48 | 2.35 | 2.42 | 1.67 | 2.15 | 15% |  |
| in a heart ring | % | 6.1 | 12.8 | 11.5 | 14.2 | 12.8 | -52% | we are lower |
| walk orders | % | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 0% |  |
| shoot orders | % | 1.0 | 2.0 | 2.0 | 1.1 | 1.7 | -43% |  |
| direct walks | % | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | — |  |
| grenade charging | % | 1.0 | 7.8 | 7.3 | 1.0 | 5.4 | -82% | we are lower |

## 2. Controlled indirectly: items picked up and used

| stat | unit | b58 | co-gas-paintbot-relay-bassy-relh:v1 | co-gas-paintbot-bassy-richard:v1 | jb-pw-opt:v29 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| grenades picked | /cog | 1.39 | 1.36 | 1.27 | 1.55 | 1.40 | 0% |  |
| grenades thrown | /cog | 1.00 | 0.95 | 0.87 | 1.23 | 1.02 | -1% |  |
| self-destructs | /cog | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | — |  |
| grenade hits | /throw | 0.60 | 1.00 | 0.99 | 0.87 | 0.95 | -37% | we are lower |
| spray cans | /cog | 0.25 | 0.24 | 0.22 | 0.24 | 0.23 | 7% |  |
| spray bursts | /cog | 0.58 | 0.21 | 0.16 | 0.62 | 0.33 | 73% | we are higher |
| armor | /cog | 0.09 | 0.32 | 0.28 | 0.50 | 0.37 | -76% | we are lower |
| medkits | /cog | 0.68 | 0.23 | 0.19 | 0.74 | 0.39 | 76% | we are higher |
| mister heals | /cog | 0.13 | 0.51 | 0.49 | 0.29 | 0.43 | -69% | we are lower |
| glory hearts | /cog | 0.13 | 0.11 | 0.08 | 0.17 | 0.12 | 6% |  |
| uniforms | /cog | 0.13 | 0.28 | 0.28 | 0.26 | 0.27 | -52% | we are lower |
| sniper rifles | /cog | 0.16 | 0.12 | 0.13 | 0.19 | 0.15 | 6% |  |
| windex-misters | /cog | 0.09 | 0.17 | 0.18 | 0.20 | 0.18 | -48% | we are lower |
| radars | /cog | 0.14 | 0.10 | 0.14 | 0.31 | 0.18 | -23% |  |

## 3. Outcomes: winning, killing, dying, territory

| stat | unit | b58 | co-gas-paintbot-relay-bassy-relh:v1 | co-gas-paintbot-bassy-richard:v1 | jb-pw-opt:v29 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| games |  | 180 | 60 | 60 | 60 | 60 | 200% | we are higher |
| win rate | % | 46.7 | 60.0 | 46.7 | 53.3 | 53.3 | -13% |  |
| draw rate | % | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | — |  |
| glory per game |  | 244 | 515 | 443 | 378 | 445 | -45% | we are lower |
| glory per win |  | 523 | 858 | 950 | 708 | 839 | -38% | we are lower |
| match length | s | 131 | 125 | 114 | 153 | 131 | 0% |  |
| deaths | /cog | 0.53 | 0.79 | 0.86 | 0.78 | 0.81 | -34% | we are lower |
| lives left | /cog | 0.94 | 0.42 | 0.29 | 0.45 | 0.39 | 144% | we are higher |
| first death | s | 76.0 | 65.6 | 63.3 | 70.7 | 66.6 | 14% |  |
| deaths in water | % | 5.0 | 10.0 | 11.9 | 22.3 | 14.8 | -66% | we are lower |
| deaths in trench | % | 1.0 | 0.8 | 0.2 | 0.5 | 0.5 | 100% |  |
| damage taken | /cog | 6.40 | 8.51 | 8.88 | 10.10 | 9.17 | -30% | we are lower |
| kills | /cog | 0.72 | 0.45 | 0.31 | 0.51 | 0.42 | 71% | we are higher |
| kill/death |  | 1.37 | 0.57 | 0.36 | 0.66 | 0.53 | 158% | we are higher |
| damage dealt | /cog | 9.17 | 6.31 | 5.39 | 7.51 | 6.40 | 43% | we are higher |
| gun kills | % | 60.9 | 44.7 | 36.9 | 27.9 | 36.5 | 67% | we are higher |
| grenade kills | % | 16.8 | 26.5 | 38.9 | 41.0 | 35.5 | -53% | we are lower |
| spray kills | % | 22.3 | 28.8 | 24.2 | 31.1 | 28.0 | -21% |  |
| captures | /cog | 0.83 | 1.37 | 1.26 | 1.09 | 1.24 | -33% | we are lower |

## Largest gaps in what we control (groups 1 and 2)

| stat | unit | ours | rivals' mean | gap | co-gas-paintbot-relay-bassy-relh:v1 / co-gas-paintbot-bassy-richard:v1 / jb-pw-opt:v29 |
|---|---|---:|---:|---:|---|
| shots fired standing | % | 100.0 | 3.9 | 2483% | 4.7 / 4.1 / 2.8 |
| accuracy 30-45 m | % | 39.7 | 9.3 | 327% | 2.1 / 1.8 / 24.0 |
| accuracy 45+ m | % | 24.0 | 6.2 | 287% | 0.8 / 1.0 / 16.8 |
| accuracy with no enemy in view | % | 13.7 | 3.7 | 274% | 3.4 / 2.3 / 5.2 |
| accuracy standing | % | 30.0 | 9.5 | 216% | 5.5 / 7.4 / 15.6 |
| accuracy 20-30 m | % | 21.4 | 7.7 | 176% | 4.0 / 4.4 / 14.7 |
| shots from above | % | 51.1 | 18.6 | 175% | 18.7 / 20.7 / 16.3 |
| accuracy from above | % | 33.3 | 13.8 | 142% | 9.9 / 11.1 / 20.3 |
| gun accuracy | % | 29.1 | 12.1 | 139% | 9.0 / 9.0 / 18.4 |
| first shot | s | 26.1 | 11.7 | 124% | 2.3 / 3.5 / 29.2 |
| accuracy from below | % | 21.6 | 11.1 | 95% | 7.8 / 7.7 / 17.8 |
| grenade charging | % | 1.0 | 5.4 | -82% | 7.8 / 7.3 / 1.0 |
| accuracy level | % | 28.7 | 15.8 | 82% | 11.9 / 11.7 / 23.8 |
| wading | % | 3.1 | 16.0 | -80% | 15.0 / 14.3 / 18.7 |
| hits from high ground | % | 27.0 | 15.1 | 78% | 14.9 / 18.2 / 12.3 |
| armor | /cog | 0.09 | 0.37 | -76% | 0.32 / 0.28 / 0.50 |
| medkits | /cog | 0.68 | 0.39 | 76% | 0.23 / 0.19 / 0.74 |
| sneaking | % | 9.9 | 5.7 | 74% | 6.6 / 6.6 / 3.9 |
| spray bursts | /cog | 0.58 | 0.33 | 73% | 0.21 / 0.16 / 0.62 |
| mister heals | /cog | 0.13 | 0.43 | -69% | 0.51 / 0.49 / 0.29 |
| miss: aim off a still target | % | 2.3 | 7.0 | -68% | 6.9 / 6.5 / 7.7 |
| high ground | % | 30.0 | 17.9 | 67% | 19.6 / 20.0 / 14.2 |
| accuracy 10-20 m | % | 30.4 | 18.3 | 66% | 17.9 / 18.4 / 18.7 |
| miss: cover in the way | % | 4.3 | 11.7 | -63% | 12.3 / 13.1 / 9.8 |
| in a heart ring | % | 6.1 | 12.8 | -52% | 12.8 / 11.5 / 14.2 |
| uniforms | /cog | 0.13 | 0.27 | -52% | 0.28 / 0.28 / 0.26 |
| accuracy 0-10 m | % | 47.3 | 31.6 | 49% | 32.3 / 31.1 / 31.5 |
| windex-misters | /cog | 0.09 | 0.18 | -48% | 0.17 / 0.18 / 0.20 |
| shots with no enemy in view | % | 5.8 | 10.0 | -43% | 9.8 / 10.2 / 10.0 |
| range under 20 m | % | 67.1 | 48.4 | 39% | 38.1 / 37.2 / 70.1 |
| grenade hits | /throw | 0.60 | 0.95 | -37% | 1.00 / 0.99 / 0.87 |
