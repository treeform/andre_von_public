# fast: avoid variant vs the three leaders (60 games)

60 replays re-simulated with the hosted engine rules (0 state-hash mismatches, 0 replays without a roster skipped). Columns are policy versions, ordered by glory per game. Replay rows are means over the policy's seat-games unless noted.

The first column is ours (favoid_jb,favoid_relh,favoid_bassy-richard). Gap = (ours - rivals' mean) / rivals' mean. A row is flagged when the gap is at least 25% (and, for % rows, at least 2 points).

## 1. Controlled directly: movement, footwork, aiming, shooting

| stat | unit | favoid_jb,favoid_relh,favoid_bassy-richard | co-gas-paintbot-bassy-richard:v1 | jb-pw-opt:v29 | co-gas-paintbot-relay-bassy-relh:v1 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| friendly damage | /cog | 1.98 | 1.24 | 1.57 | 1.77 | 1.53 | 29% | we are higher |
| enemy in view | % | 61.3 | 63.2 | 55.1 | 66.6 | 61.7 | -1% |  |
| gun shots | /min | 13.7 | 20.8 | 10.2 | 22.3 | 17.8 | -23% |  |
| gun accuracy | % | 28.5 | 9.3 | 20.0 | 9.7 | 13.0 | 119% | we are higher |
| first shot | s | 26.6 | 4.1 | 28.5 | 2.9 | 11.8 | 125% | we are higher |
| shots with no enemy in view | % | 6.6 | 9.7 | 9.5 | 9.9 | 9.7 | -32% | we are lower |
| accuracy with no enemy in view | % | 14.1 | 1.6 | 7.4 | 2.1 | 3.7 | 282% | we are higher |
| range under 20 m | % | 67.0 | 38.4 | 70.1 | 36.9 | 48.4 | 38% | we are higher |
| accuracy 0-10 m | % | 49.3 | 29.2 | 36.2 | 33.5 | 33.0 | 49% | we are higher |
| accuracy 10-20 m | % | 29.3 | 17.3 | 19.7 | 18.9 | 18.7 | 57% | we are higher |
| accuracy 20-30 m | % | 21.0 | 5.2 | 16.5 | 5.9 | 9.2 | 128% | we are higher |
| accuracy 30-45 m | % | 38.8 | 3.1 | 24.4 | 2.1 | 9.9 | 294% | we are higher |
| accuracy 45+ m | % | 24.8 | 1.2 | 19.4 | 1.9 | 7.5 | 231% | we are higher |
| shots fired standing | % | 100.0 | 4.1 | 3.1 | 3.7 | 3.6 | 2656% | we are higher |
| accuracy standing | % | 29.5 | 10.3 | 12.3 | 7.7 | 10.1 | 192% | we are higher |
| accuracy moving | % | — | 10.1 | 21.7 | 10.7 | 14.1 | — |  |
| shots from above | % | 49.9 | 18.7 | 18.1 | 18.3 | 18.3 | 172% | we are higher |
| accuracy from above | % | 33.7 | 10.1 | 21.1 | 12.1 | 14.4 | 133% | we are higher |
| accuracy level | % | 26.8 | 12.4 | 27.7 | 12.6 | 17.6 | 53% | we are higher |
| accuracy from below | % | 22.0 | 8.5 | 18.0 | 8.5 | 11.7 | 88% | we are higher |
| hits from high ground | % | 29.7 | 17.4 | 15.5 | 14.3 | 15.7 | 89% | we are higher |
| hits from trench | % | 0.3 | 0.8 | 1.3 | 1.4 | 1.2 | -72% |  |
| miss: cover in the way | % | 4.1 | 13.9 | 10.4 | 11.9 | 12.1 | -66% | we are lower |
| miss: target moved off the line | % | 23.8 | 30.2 | 34.1 | 29.2 | 31.1 | -23% |  |
| miss: aim off a still target | % | 2.4 | 6.2 | 8.2 | 6.8 | 7.1 | -66% | we are lower |
| miss: in radius, no hit | % | 34.4 | 33.0 | 19.7 | 34.6 | 29.1 | 18% |  |
| miss: teammate in the way | % | 5.4 | 5.9 | 4.9 | 6.3 | 5.7 | -4% |  |
| miss: nobody near the line | % | 0.3 | 0.7 | 1.4 | 0.8 | 1.0 | -65% |  |
| speed | m/s | 5.05 | 4.83 | 4.65 | 4.89 | 4.79 | 5% |  |
| moving | % | 84.1 | 89.8 | 84.9 | 90.0 | 88.2 | -5% |  |
| wading | % | 2.8 | 15.6 | 16.8 | 15.1 | 15.8 | -82% | we are lower |
| sneaking | % | 10.4 | 7.6 | 3.3 | 6.5 | 5.8 | 80% | we are higher |
| in trench | % | 0.9 | 1.6 | 1.2 | 1.7 | 1.5 | -38% |  |
| high ground | % | 30.4 | 21.2 | 15.1 | 18.4 | 18.2 | 67% | we are higher |
| exact compass steps | % | 5.4 | 5.1 | 4.5 | 4.5 | 4.7 | 15% |  |
| nearest teammate | m | 10.1 | 9.8 | 10.8 | 9.5 | 10.0 | 1% |  |
| lead on a moving target | ticks | 4.1 | 4.1 | 4.0 | 4.2 | 4.1 | 1% |  |
| sight run length | ticks | 18.2 | 17.1 | 12.7 | 17.4 | 15.8 | 16% |  |
| new sightings | /min | 113.1 | 114.6 | 125.7 | 115.5 | 118.6 | -5% |  |
| shots at a target in view | % | 99.4 | 95.6 | 97.5 | 96.0 | 96.4 | 3% |  |
| shots at a tracked target | % | 91.3 | 77.2 | 71.6 | 77.4 | 75.4 | 21% |  |
| unled shots at movers | % | 16.6 | 18.7 | 20.8 | 18.3 | 19.3 | -14% |  |
| standing with an enemy in sight | % | 17.9 | 18.8 | 26.2 | 17.4 | 20.8 | -14% |  |
| run length in sight | ticks | 5.7 | 6.1 | 5.9 | 6.3 | 6.1 | -8% |  |
| runs ended by reversing | % | 72.9 | 79.9 | 82.0 | 80.6 | 80.8 | -10% |  |
| direction changes in sight | /s | 2.41 | 2.34 | 1.88 | 2.25 | 2.16 | 12% |  |
| in a heart ring | % | 5.7 | 10.7 | 12.8 | 11.4 | 11.6 | -51% | we are lower |
| walk orders | % | 100.0 | 100.1 | 100.0 | 100.1 | 100.0 | 0% |  |
| shoot orders | % | 1.0 | 1.9 | 1.2 | 2.0 | 1.7 | -42% |  |
| direct walks | % | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | — |  |
| grenade charging | % | 0.6 | 7.8 | 1.0 | 5.8 | 4.9 | -87% | we are lower |

## 2. Controlled indirectly: items picked up and used

| stat | unit | favoid_jb,favoid_relh,favoid_bassy-richard | co-gas-paintbot-bassy-richard:v1 | jb-pw-opt:v29 | co-gas-paintbot-relay-bassy-relh:v1 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| grenades picked | /cog | 1.44 | 1.09 | 1.60 | 1.31 | 1.34 | 8% |  |
| grenades thrown | /cog | 1.04 | 0.72 | 1.27 | 0.94 | 0.98 | 6% |  |
| grenade hits | /throw | 0.60 | 0.95 | 0.79 | 0.95 | 0.90 | -33% | we are lower |
| spray cans | /cog | 0.24 | 0.23 | 0.23 | 0.24 | 0.23 | 5% |  |
| spray bursts | /cog | 0.66 | 0.15 | 0.51 | 0.14 | 0.27 | 148% | we are higher |
| armor | /cog | 0.08 | 0.29 | 0.54 | 0.32 | 0.38 | -79% | we are lower |
| medkits | /cog | 0.69 | 0.16 | 0.86 | 0.13 | 0.38 | 80% | we are higher |
| mister heals | /cog | 0.08 | 0.53 | 0.33 | 0.29 | 0.38 | -79% | we are lower |
| glory hearts | /cog | 0.15 | 0.09 | 0.15 | 0.11 | 0.11 | 27% | we are higher |
| uniforms | /cog | 0.13 | 0.22 | 0.35 | 0.23 | 0.27 | -51% | we are lower |
| sniper rifles | /cog | 0.16 | 0.14 | 0.24 | 0.14 | 0.17 | -8% |  |
| windex-misters | /cog | 0.05 | 0.19 | 0.17 | 0.14 | 0.17 | -73% | we are lower |
| radars | /cog | 0.09 | 0.14 | 0.32 | 0.14 | 0.20 | -55% | we are lower |

## 3. Outcomes: winning, killing, dying, territory

| stat | unit | favoid_jb,favoid_relh,favoid_bassy-richard | co-gas-paintbot-bassy-richard:v1 | jb-pw-opt:v29 | co-gas-paintbot-relay-bassy-relh:v1 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| games |  | 60 | 20 | 20 | 20 | 20 | 200% | we are higher |
| win rate | % | 48.3 | 50.0 | 65.0 | 40.0 | 51.7 | -6% |  |
| draw rate | % | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | — |  |
| glory per game |  | 253 | 525 | 514 | 297 | 445 | -43% | we are lower |
| glory per win |  | 523 | 1049 | 791 | 743 | 861 | -39% | we are lower |
| match length | s | 132 | 119 | 164 | 112 | 132 | 0% |  |
| deaths | /cog | 0.53 | 0.89 | 0.75 | 0.88 | 0.84 | -36% | we are lower |
| lives left | /cog | 0.93 | 0.23 | 0.50 | 0.24 | 0.32 | 191% | we are higher |
| first death | s | 78.8 | 63.7 | 71.2 | 65.7 | 66.9 | 18% |  |
| deaths in water | % | 5.5 | 12.0 | 17.5 | 12.1 | 13.8 | -60% | we are lower |
| deaths in trench | % | 0.0 | 1.4 | 0.0 | 2.1 | 1.2 | -100% |  |
| damage taken | /cog | 6.07 | 9.57 | 9.91 | 8.40 | 9.29 | -35% | we are lower |
| kills | /cog | 0.77 | 0.30 | 0.54 | 0.34 | 0.40 | 95% | we are higher |
| kill/death |  | 1.45 | 0.34 | 0.72 | 0.39 | 0.48 | 199% | we are higher |
| damage dealt | /cog | 9.29 | 4.86 | 7.56 | 5.78 | 6.07 | 53% | we are higher |
| gun kills | % | 59.6 | 22.9 | 32.2 | 30.9 | 28.7 | 108% | we are higher |
| grenade kills | % | 16.7 | 43.8 | 40.2 | 43.6 | 42.5 | -61% | we are lower |
| spray kills | % | 23.7 | 33.3 | 27.6 | 25.5 | 28.8 | -18% |  |
| captures | /cog | 0.85 | 1.33 | 1.06 | 1.24 | 1.21 | -30% | we are lower |

## Largest gaps in what we control (groups 1 and 2)

| stat | unit | ours | rivals' mean | gap | co-gas-paintbot-bassy-richard:v1 / jb-pw-opt:v29 / co-gas-paintbot-relay-bassy-relh:v1 |
|---|---|---:|---:|---:|---|
| shots fired standing | % | 100.0 | 3.6 | 2656% | 4.1 / 3.1 / 3.7 |
| accuracy 30-45 m | % | 38.8 | 9.9 | 294% | 3.1 / 24.4 / 2.1 |
| accuracy with no enemy in view | % | 14.1 | 3.7 | 282% | 1.6 / 7.4 / 2.1 |
| accuracy 45+ m | % | 24.8 | 7.5 | 231% | 1.2 / 19.4 / 1.9 |
| accuracy standing | % | 29.5 | 10.1 | 192% | 10.3 / 12.3 / 7.7 |
| shots from above | % | 49.9 | 18.3 | 172% | 18.7 / 18.1 / 18.3 |
| spray bursts | /cog | 0.66 | 0.27 | 148% | 0.15 / 0.51 / 0.14 |
| accuracy from above | % | 33.7 | 14.4 | 133% | 10.1 / 21.1 / 12.1 |
| accuracy 20-30 m | % | 21.0 | 9.2 | 128% | 5.2 / 16.5 / 5.9 |
| first shot | s | 26.6 | 11.8 | 125% | 4.1 / 28.5 / 2.9 |
| gun accuracy | % | 28.5 | 13.0 | 119% | 9.3 / 20.0 / 9.7 |
| hits from high ground | % | 29.7 | 15.7 | 89% | 17.4 / 15.5 / 14.3 |
| accuracy from below | % | 22.0 | 11.7 | 88% | 8.5 / 18.0 / 8.5 |
| grenade charging | % | 0.6 | 4.9 | -87% | 7.8 / 1.0 / 5.8 |
| wading | % | 2.8 | 15.8 | -82% | 15.6 / 16.8 / 15.1 |
| medkits | /cog | 0.69 | 0.38 | 80% | 0.16 / 0.86 / 0.13 |
| sneaking | % | 10.4 | 5.8 | 80% | 7.6 / 3.3 / 6.5 |
| mister heals | /cog | 0.08 | 0.38 | -79% | 0.53 / 0.33 / 0.29 |
| armor | /cog | 0.08 | 0.38 | -79% | 0.29 / 0.54 / 0.32 |
| windex-misters | /cog | 0.05 | 0.17 | -73% | 0.19 / 0.17 / 0.14 |
| high ground | % | 30.4 | 18.2 | 67% | 21.2 / 15.1 / 18.4 |
| miss: aim off a still target | % | 2.4 | 7.1 | -66% | 6.2 / 8.2 / 6.8 |
| miss: cover in the way | % | 4.1 | 12.1 | -66% | 13.9 / 10.4 / 11.9 |
| accuracy 10-20 m | % | 29.3 | 18.7 | 57% | 17.3 / 19.7 / 18.9 |
| radars | /cog | 0.09 | 0.20 | -55% | 0.14 / 0.32 / 0.14 |
| accuracy level | % | 26.8 | 17.6 | 53% | 12.4 / 27.7 / 12.6 |
| in a heart ring | % | 5.7 | 11.6 | -51% | 10.7 / 12.8 / 11.4 |
| uniforms | /cog | 0.13 | 0.27 | -51% | 0.22 / 0.35 / 0.23 |
| accuracy 0-10 m | % | 49.3 | 33.0 | 49% | 29.2 / 36.2 / 33.5 |
| range under 20 m | % | 67.0 | 48.4 | 38% | 38.4 / 70.1 / 36.9 |
| grenade hits | /throw | 0.60 | 0.90 | -33% | 0.95 / 0.79 / 0.95 |
| shots with no enemy in view | % | 6.6 | 9.7 | -32% | 9.7 / 9.5 / 9.9 |
| friendly damage | /cog | 1.98 | 1.53 | 29% | 1.24 / 1.57 / 1.77 |
| glory hearts | /cog | 0.15 | 0.11 | 27% | 0.09 / 0.15 / 0.11 |
