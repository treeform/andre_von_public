# fast 0.3.124: zhar v64 vs jb-pw-opt v29 / bassy-richard v1 / relay-bassy-relh v1 (300 games)

300 replays re-simulated with the hosted engine rules (0 state-hash mismatches, 0 replays without a roster skipped). Columns are policy versions, ordered by glory per game. Replay rows are means over the policy's seat-games unless noted.

The first column is ours (c_nade). Gap = (ours - rivals' mean) / rivals' mean. A row is flagged when the gap is at least 25% (and, for % rows, at least 2 points).

## 1. Controlled directly: movement, footwork, aiming, shooting

| stat | unit | c_nade | co-gas-paintbot-relay-bassy-relh:v1 | jb-pw-opt:v29 | co-gas-paintbot-bassy-richard:v1 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| friendly damage | /cog | 1.37 | 1.33 | 1.41 | 1.46 | 1.40 | -2% |  |
| enemy in view | % | 58.5 | 69.0 | 55.4 | 64.9 | 63.1 | -7% |  |
| gun shots | /min | 12.7 | 23.6 | 10.0 | 21.9 | 18.5 | -31% | we are lower |
| gun accuracy | % | 30.7 | 9.5 | 20.9 | 10.4 | 13.6 | 125% | we are higher |
| first shot | s | 26.0 | 2.4 | 27.6 | 3.8 | 11.2 | 131% | we are higher |
| shots with no enemy in view | % | 6.5 | 9.2 | 9.9 | 9.4 | 9.5 | -31% | we are lower |
| accuracy with no enemy in view | % | 16.2 | 2.6 | 6.7 | 2.3 | 3.9 | 320% | we are higher |
| range under 20 m | % | 67.5 | 39.7 | 70.7 | 41.6 | 50.7 | 33% | we are higher |
| accuracy 0-10 m | % | 52.1 | 33.3 | 37.9 | 32.9 | 34.7 | 50% | we are higher |
| accuracy 10-20 m | % | 31.1 | 18.0 | 21.6 | 18.8 | 19.5 | 60% | we are higher |
| accuracy 20-30 m | % | 22.1 | 4.3 | 14.4 | 4.9 | 7.9 | 180% | we are higher |
| accuracy 30-45 m | % | 44.2 | 2.1 | 22.8 | 2.4 | 9.1 | 387% | we are higher |
| accuracy 45+ m | % | 29.4 | 1.1 | 12.5 | 0.6 | 4.7 | 520% | we are higher |
| shots fired standing | % | 100.0 | 3.7 | 3.6 | 3.8 | 3.7 | 2593% | we are higher |
| accuracy standing | % | 31.7 | 8.2 | 19.0 | 10.0 | 12.4 | 156% | we are higher |
| accuracy moving | % | — | 10.3 | 22.6 | 11.3 | 14.7 | — |  |
| shots from above | % | 49.7 | 20.3 | 18.1 | 20.9 | 19.7 | 152% | we are higher |
| accuracy from above | % | 35.8 | 10.7 | 27.4 | 12.2 | 16.7 | 114% | we are higher |
| accuracy level | % | 30.6 | 13.2 | 25.2 | 13.8 | 17.4 | 76% | we are higher |
| accuracy from below | % | 21.2 | 7.9 | 19.2 | 8.7 | 11.9 | 78% | we are higher |
| hits from high ground | % | 22.6 | 13.8 | 8.9 | 15.1 | 12.6 | 79% | we are higher |
| hits from trench | % | 0.6 | 1.9 | 1.1 | 1.2 | 1.4 | -60% |  |
| miss: cover in the way | % | 3.8 | 13.0 | 9.6 | 13.1 | 11.9 | -68% | we are lower |
| miss: target moved off the line | % | 23.3 | 29.9 | 31.1 | 29.6 | 30.2 | -23% |  |
| miss: aim off a still target | % | 2.2 | 6.3 | 8.3 | 6.6 | 7.1 | -70% | we are lower |
| miss: in radius, no hit | % | 33.6 | 34.4 | 22.8 | 33.1 | 30.1 | 12% |  |
| miss: teammate in the way | % | 5.1 | 5.5 | 4.2 | 5.3 | 5.0 | 2% |  |
| miss: nobody near the line | % | 0.4 | 0.8 | 1.5 | 1.0 | 1.1 | -66% |  |
| speed | m/s | 4.75 | 4.80 | 4.34 | 4.82 | 4.65 | 2% |  |
| moving | % | 82.6 | 90.1 | 82.9 | 90.0 | 87.7 | -6% |  |
| wading | % | 8.7 | 18.8 | 22.8 | 17.1 | 19.5 | -55% | we are lower |
| sneaking | % | 12.8 | 6.2 | 3.5 | 7.1 | 5.6 | 129% | we are higher |
| in trench | % | 0.9 | 2.1 | 1.4 | 1.9 | 1.8 | -51% |  |
| high ground | % | 25.1 | 18.6 | 10.6 | 19.1 | 16.1 | 55% | we are higher |
| exact compass steps | % | 5.1 | 4.5 | 4.0 | 4.6 | 4.3 | 17% |  |
| nearest teammate | m | 9.0 | 9.5 | 9.5 | 9.0 | 9.3 | -4% |  |
| lead on a moving target | ticks | 4.2 | 4.3 | 4.1 | 4.3 | 4.2 | -1% |  |
| sight run length | ticks | 19.5 | 17.2 | 13.1 | 17.3 | 15.9 | 23% |  |
| new sightings | /min | 96.2 | 125.9 | 125.2 | 117.8 | 122.9 | -22% |  |
| shots at a target in view | % | 99.5 | 96.0 | 97.5 | 96.2 | 96.6 | 3% |  |
| shots at a tracked target | % | 91.9 | 79.2 | 74.0 | 79.0 | 77.4 | 19% |  |
| unled shots at movers | % | 15.3 | 17.8 | 19.8 | 17.5 | 18.4 | -17% |  |
| standing with an enemy in sight | % | 21.4 | 21.4 | 33.0 | 19.3 | 24.5 | -13% |  |
| run length in sight | ticks | 5.6 | 6.5 | 6.1 | 6.5 | 6.3 | -12% |  |
| runs ended by reversing | % | 74.4 | 81.1 | 80.7 | 80.5 | 80.8 | -8% |  |
| direction changes in sight | /s | 2.40 | 2.22 | 1.68 | 2.22 | 2.04 | 18% |  |
| in a heart ring | % | 5.9 | 10.1 | 14.3 | 10.6 | 11.7 | -50% | we are lower |
| walk orders | % | 100.0 | 100.1 | 100.0 | 100.1 | 100.1 | 0% |  |
| shoot orders | % | 0.9 | 2.1 | 1.2 | 2.0 | 1.8 | -48% |  |
| direct walks | % | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | — |  |
| grenade charging | % | 1.3 | 6.5 | 1.0 | 6.3 | 4.6 | -72% | we are lower |

## 2. Controlled indirectly: items picked up and used

| stat | unit | c_nade | co-gas-paintbot-relay-bassy-relh:v1 | jb-pw-opt:v29 | co-gas-paintbot-bassy-richard:v1 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| grenades picked | /cog | 1.42 | 1.13 | 1.28 | 1.07 | 1.16 | 22% |  |
| grenades thrown | /cog | 0.96 | 0.78 | 1.03 | 0.79 | 0.87 | 11% |  |
| self-destructs | /cog | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | — |  |
| grenade hits | /throw | 0.99 | 1.01 | 0.87 | 0.96 | 0.95 | 5% |  |
| spray cans | /cog | 0.25 | 0.20 | 0.20 | 0.18 | 0.19 | 28% | we are higher |
| spray bursts | /cog | 0.53 | 0.10 | 0.58 | 0.12 | 0.27 | 95% | we are higher |
| armor | /cog | 0.08 | 0.27 | 0.41 | 0.25 | 0.31 | -73% | we are lower |
| medkits | /cog | 0.65 | 0.23 | 0.61 | 0.20 | 0.34 | 90% | we are higher |
| mister heals | /cog | 0.16 | 0.42 | 0.26 | 0.34 | 0.34 | -52% | we are lower |
| glory hearts | /cog | 0.11 | 0.07 | 0.11 | 0.07 | 0.09 | 30% | we are higher |
| uniforms | /cog | 0.15 | 0.24 | 0.24 | 0.23 | 0.24 | -35% | we are lower |
| sniper rifles | /cog | 0.17 | 0.14 | 0.19 | 0.14 | 0.16 | 7% |  |
| windex-misters | /cog | 0.11 | 0.16 | 0.16 | 0.16 | 0.16 | -31% | we are lower |
| radars | /cog | 0.18 | 0.11 | 0.28 | 0.10 | 0.17 | 6% |  |

## 3. Outcomes: winning, killing, dying, territory

| stat | unit | c_nade | co-gas-paintbot-relay-bassy-relh:v1 | jb-pw-opt:v29 | co-gas-paintbot-bassy-richard:v1 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| games |  | 300 | 100 | 100 | 100 | 100 | 200% | we are higher |
| win rate | % | 81.3 | 23.0 | 18.0 | 15.0 | 18.7 | 336% | we are higher |
| draw rate | % | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | — |  |
| glory per game |  | 420 | 228 | 145 | 122 | 165 | 154% | we are higher |
| glory per win |  | 516 | 992 | 806 | 815 | 871 | -41% | we are lower |
| match length | s | 119 | 113 | 139 | 104 | 119 | 0% |  |
| deaths | /cog | 0.36 | 0.93 | 0.89 | 0.96 | 0.93 | -62% | we are lower |
| lives left | /cog | 1.29 | 0.13 | 0.22 | 0.09 | 0.15 | 778% | we are higher |
| first death | s | 73.7 | 62.5 | 64.2 | 61.2 | 62.6 | 18% |  |
| deaths in water | % | 15.0 | 16.1 | 31.9 | 14.1 | 20.7 | -28% | we are lower |
| deaths in trench | % | 1.8 | 2.0 | 0.6 | 1.6 | 1.4 | 27% |  |
| damage taken | /cog | 5.77 | 9.87 | 10.25 | 9.71 | 9.94 | -42% | we are lower |
| kills | /cog | 0.86 | 0.23 | 0.40 | 0.26 | 0.30 | 190% | we are higher |
| kill/death |  | 2.42 | 0.25 | 0.45 | 0.27 | 0.32 | 651% | we are higher |
| damage dealt | /cog | 9.94 | 5.20 | 6.96 | 5.15 | 5.77 | 72% | we are higher |
| gun kills | % | 56.6 | 42.6 | 32.8 | 38.9 | 38.1 | 49% | we are higher |
| grenade kills | % | 23.2 | 34.6 | 36.6 | 37.0 | 36.1 | -36% | we are lower |
| spray kills | % | 20.2 | 22.9 | 30.6 | 24.0 | 25.8 | -22% |  |
| captures | /cog | 0.89 | 1.17 | 0.82 | 1.14 | 1.04 | -15% |  |

## Largest gaps in what we control (groups 1 and 2)

| stat | unit | ours | rivals' mean | gap | co-gas-paintbot-relay-bassy-relh:v1 / jb-pw-opt:v29 / co-gas-paintbot-bassy-richard:v1 |
|---|---|---:|---:|---:|---|
| shots fired standing | % | 100.0 | 3.7 | 2593% | 3.7 / 3.6 / 3.8 |
| accuracy 45+ m | % | 29.4 | 4.7 | 520% | 1.1 / 12.5 / 0.6 |
| accuracy 30-45 m | % | 44.2 | 9.1 | 387% | 2.1 / 22.8 / 2.4 |
| accuracy with no enemy in view | % | 16.2 | 3.9 | 320% | 2.6 / 6.7 / 2.3 |
| accuracy 20-30 m | % | 22.1 | 7.9 | 180% | 4.3 / 14.4 / 4.9 |
| accuracy standing | % | 31.7 | 12.4 | 156% | 8.2 / 19.0 / 10.0 |
| shots from above | % | 49.7 | 19.7 | 152% | 20.3 / 18.1 / 20.9 |
| first shot | s | 26.0 | 11.2 | 131% | 2.4 / 27.6 / 3.8 |
| sneaking | % | 12.8 | 5.6 | 129% | 6.2 / 3.5 / 7.1 |
| gun accuracy | % | 30.7 | 13.6 | 125% | 9.5 / 20.9 / 10.4 |
| accuracy from above | % | 35.8 | 16.7 | 114% | 10.7 / 27.4 / 12.2 |
| spray bursts | /cog | 0.53 | 0.27 | 95% | 0.10 / 0.58 / 0.12 |
| medkits | /cog | 0.65 | 0.34 | 90% | 0.23 / 0.61 / 0.20 |
| hits from high ground | % | 22.6 | 12.6 | 79% | 13.8 / 8.9 / 15.1 |
| accuracy from below | % | 21.2 | 11.9 | 78% | 7.9 / 19.2 / 8.7 |
| accuracy level | % | 30.6 | 17.4 | 76% | 13.2 / 25.2 / 13.8 |
| armor | /cog | 0.08 | 0.31 | -73% | 0.27 / 0.41 / 0.25 |
| grenade charging | % | 1.3 | 4.6 | -72% | 6.5 / 1.0 / 6.3 |
| miss: aim off a still target | % | 2.2 | 7.1 | -70% | 6.3 / 8.3 / 6.6 |
| miss: cover in the way | % | 3.8 | 11.9 | -68% | 13.0 / 9.6 / 13.1 |
| accuracy 10-20 m | % | 31.1 | 19.5 | 60% | 18.0 / 21.6 / 18.8 |
| high ground | % | 25.1 | 16.1 | 55% | 18.6 / 10.6 / 19.1 |
| wading | % | 8.7 | 19.5 | -55% | 18.8 / 22.8 / 17.1 |
| mister heals | /cog | 0.16 | 0.34 | -52% | 0.42 / 0.26 / 0.34 |
| accuracy 0-10 m | % | 52.1 | 34.7 | 50% | 33.3 / 37.9 / 32.9 |
| in a heart ring | % | 5.9 | 11.7 | -50% | 10.1 / 14.3 / 10.6 |
| uniforms | /cog | 0.15 | 0.24 | -35% | 0.24 / 0.24 / 0.23 |
| range under 20 m | % | 67.5 | 50.7 | 33% | 39.7 / 70.7 / 41.6 |
| windex-misters | /cog | 0.11 | 0.16 | -31% | 0.16 / 0.16 / 0.16 |
| shots with no enemy in view | % | 6.5 | 9.5 | -31% | 9.2 / 9.9 / 9.4 |
| gun shots | /min | 12.7 | 18.5 | -31% | 23.6 / 10.0 / 21.9 |
| glory hearts | /cog | 0.11 | 0.09 | 30% | 0.07 / 0.11 / 0.07 |
| spray cans | /cog | 0.25 | 0.19 | 28% | 0.20 / 0.20 / 0.18 |
