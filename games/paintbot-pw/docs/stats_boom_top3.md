# fast: boom variant vs the three leaders (60 games)

60 replays re-simulated with the hosted engine rules (0 state-hash mismatches, 0 replays without a roster skipped). Columns are policy versions, ordered by glory per game. Replay rows are means over the policy's seat-games unless noted.

The first column is ours (fboom_jb,fboom_relh,fboom_bassy-richard). Gap = (ours - rivals' mean) / rivals' mean. A row is flagged when the gap is at least 25% (and, for % rows, at least 2 points).

## 1. Controlled directly: movement, footwork, aiming, shooting

| stat | unit | fboom_jb,fboom_relh,fboom_bassy-richard | jb-pw-opt:v29 | co-gas-paintbot-bassy-richard:v1 | co-gas-paintbot-relay-bassy-relh:v1 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| friendly damage | /cog | 1.67 | 1.17 | 1.32 | 1.59 | 1.36 | 22% |  |
| enemy in view | % | 61.7 | 55.3 | 61.0 | 64.9 | 60.4 | 2% |  |
| gun shots | /min | 13.6 | 9.5 | 19.4 | 21.5 | 16.8 | -19% |  |
| gun accuracy | % | 30.5 | 20.1 | 9.1 | 9.5 | 12.9 | 136% | we are higher |
| first shot | s | 26.3 | 29.8 | 4.3 | 2.4 | 12.2 | 117% | we are higher |
| shots with no enemy in view | % | 5.3 | 9.6 | 9.8 | 9.7 | 9.7 | -46% | we are lower |
| accuracy with no enemy in view | % | 14.4 | 7.1 | 1.8 | 2.9 | 3.9 | 266% | we are higher |
| range under 20 m | % | 66.7 | 65.9 | 36.0 | 37.3 | 46.4 | 44% | we are higher |
| accuracy 0-10 m | % | 52.4 | 40.3 | 32.7 | 31.8 | 35.0 | 50% | we are higher |
| accuracy 10-20 m | % | 31.0 | 19.8 | 18.8 | 17.1 | 18.5 | 67% | we are higher |
| accuracy 20-30 m | % | 22.3 | 15.8 | 4.9 | 5.9 | 8.8 | 152% | we are higher |
| accuracy 30-45 m | % | 47.1 | 29.6 | 2.6 | 2.6 | 11.6 | 306% | we are higher |
| accuracy 45+ m | % | 20.8 | 20.6 | 0.9 | 1.8 | 7.8 | 167% | we are higher |
| shots fired standing | % | 100.0 | 3.3 | 3.9 | 3.9 | 3.7 | 2625% | we are higher |
| accuracy standing | % | 31.4 | 18.8 | 6.6 | 7.3 | 10.9 | 187% | we are higher |
| accuracy moving | % | — | 21.6 | 10.0 | 10.4 | 14.0 | — |  |
| shots from above | % | 53.3 | 16.2 | 20.4 | 19.6 | 18.7 | 185% | we are higher |
| accuracy from above | % | 34.2 | 25.1 | 10.1 | 10.5 | 15.3 | 124% | we are higher |
| accuracy level | % | 30.3 | 23.9 | 11.9 | 11.9 | 15.9 | 91% | we are higher |
| accuracy from below | % | 22.7 | 19.0 | 8.3 | 8.9 | 12.1 | 89% | we are higher |
| hits from high ground | % | 28.7 | 13.2 | 19.4 | 14.7 | 15.8 | 82% | we are higher |
| hits from trench | % | 0.4 | 1.0 | 0.8 | 0.9 | 0.9 | -57% |  |
| miss: cover in the way | % | 3.9 | 10.0 | 13.8 | 12.8 | 12.2 | -68% | we are lower |
| miss: target moved off the line | % | 23.7 | 35.1 | 29.5 | 30.8 | 31.8 | -26% | we are lower |
| miss: aim off a still target | % | 2.4 | 7.5 | 5.8 | 6.5 | 6.6 | -64% | we are lower |
| miss: in radius, no hit | % | 33.8 | 20.5 | 34.5 | 32.9 | 29.3 | 15% |  |
| miss: teammate in the way | % | 4.9 | 4.0 | 5.7 | 5.7 | 5.1 | -5% |  |
| miss: nobody near the line | % | 0.1 | 1.3 | 0.9 | 1.0 | 1.1 | -87% |  |
| speed | m/s | 5.03 | 4.58 | 4.89 | 4.84 | 4.77 | 5% |  |
| moving | % | 84.4 | 84.2 | 89.7 | 88.8 | 87.5 | -4% |  |
| wading | % | 2.7 | 17.8 | 14.1 | 14.4 | 15.4 | -82% | we are lower |
| sneaking | % | 9.8 | 3.3 | 8.0 | 5.9 | 5.7 | 71% | we are higher |
| in trench | % | 0.9 | 1.4 | 1.3 | 1.4 | 1.4 | -33% |  |
| high ground | % | 30.6 | 13.8 | 22.5 | 19.1 | 18.5 | 65% | we are higher |
| exact compass steps | % | 5.3 | 4.6 | 4.9 | 4.9 | 4.8 | 10% |  |
| nearest teammate | m | 10.6 | 11.1 | 9.5 | 9.8 | 10.1 | 5% |  |
| lead on a moving target | ticks | 4.1 | 3.8 | 4.0 | 4.1 | 4.0 | 3% |  |
| sight run length | ticks | 18.4 | 12.8 | 17.8 | 17.8 | 16.1 | 14% |  |
| new sightings | /min | 112.7 | 127.3 | 103.9 | 108.6 | 113.3 | 0% |  |
| shots at a target in view | % | 99.3 | 97.6 | 95.7 | 96.0 | 96.5 | 3% |  |
| shots at a tracked target | % | 91.6 | 72.0 | 76.9 | 76.8 | 75.2 | 22% |  |
| unled shots at movers | % | 17.1 | 21.8 | 19.7 | 19.4 | 20.3 | -16% |  |
| standing with an enemy in sight | % | 17.4 | 28.2 | 17.3 | 18.0 | 21.2 | -18% |  |
| run length in sight | ticks | 5.7 | 5.4 | 6.4 | 6.0 | 5.9 | -4% |  |
| runs ended by reversing | % | 73.8 | 81.8 | 80.0 | 80.7 | 80.8 | -9% |  |
| direction changes in sight | /s | 2.46 | 2.03 | 2.24 | 2.36 | 2.21 | 11% |  |
| in a heart ring | % | 5.1 | 13.1 | 10.6 | 13.9 | 12.6 | -60% | we are lower |
| walk orders | % | 100.0 | 100.0 | 100.0 | 100.0 | 100.0 | 0% |  |
| shoot orders | % | 1.0 | 1.2 | 1.8 | 1.9 | 1.6 | -41% |  |
| direct walks | % | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | — |  |
| grenade charging | % | 0.9 | 1.0 | 7.2 | 7.4 | 5.2 | -82% | we are lower |

## 2. Controlled indirectly: items picked up and used

| stat | unit | fboom_jb,fboom_relh,fboom_bassy-richard | jb-pw-opt:v29 | co-gas-paintbot-bassy-richard:v1 | co-gas-paintbot-relay-bassy-relh:v1 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| grenades picked | /cog | 1.33 | 1.62 | 1.27 | 1.26 | 1.39 | -4% |  |
| grenades thrown | /cog | 0.96 | 1.29 | 0.85 | 0.88 | 1.01 | -4% |  |
| self-destructs | /cog | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | — |  |
| grenade hits | /throw | 0.71 | 0.88 | 1.01 | 0.95 | 0.95 | -24% |  |
| spray cans | /cog | 0.22 | 0.26 | 0.27 | 0.27 | 0.27 | -19% |  |
| spray bursts | /cog | 0.59 | 0.50 | 0.18 | 0.16 | 0.28 | 111% | we are higher |
| armor | /cog | 0.08 | 0.56 | 0.28 | 0.28 | 0.37 | -79% | we are lower |
| medkits | /cog | 0.64 | 0.79 | 0.16 | 0.17 | 0.37 | 70% | we are higher |
| mister heals | /cog | 0.16 | 0.33 | 0.45 | 0.52 | 0.43 | -62% | we are lower |
| glory hearts | /cog | 0.11 | 0.18 | 0.14 | 0.10 | 0.14 | -19% |  |
| uniforms | /cog | 0.12 | 0.26 | 0.27 | 0.23 | 0.25 | -52% | we are lower |
| sniper rifles | /cog | 0.17 | 0.22 | 0.14 | 0.14 | 0.17 | 0% |  |
| windex-misters | /cog | 0.10 | 0.19 | 0.16 | 0.17 | 0.18 | -41% | we are lower |
| radars | /cog | 0.16 | 0.31 | 0.14 | 0.16 | 0.20 | -22% |  |

## 3. Outcomes: winning, killing, dying, territory

| stat | unit | fboom_jb,fboom_relh,fboom_bassy-richard | jb-pw-opt:v29 | co-gas-paintbot-bassy-richard:v1 | co-gas-paintbot-relay-bassy-relh:v1 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---:|---:|---|
| games |  | 60 | 20 | 20 | 20 | 20 | 200% | we are higher |
| win rate | % | 36.7 | 75.0 | 60.0 | 55.0 | 63.3 | -42% | we are lower |
| draw rate | % | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | — |  |
| glory per game |  | 187 | 584 | 518 | 441 | 514 | -64% | we are lower |
| glory per win |  | 509 | 778 | 863 | 801 | 814 | -37% | we are lower |
| match length | s | 134 | 161 | 122 | 120 | 134 | 0% |  |
| deaths | /cog | 0.57 | 0.75 | 0.87 | 0.85 | 0.82 | -31% | we are lower |
| lives left | /cog | 0.86 | 0.50 | 0.26 | 0.30 | 0.35 | 142% | we are higher |
| first death | s | 75.1 | 71.2 | 66.3 | 65.6 | 67.7 | 11% |  |
| deaths in water | % | 4.7 | 20.8 | 11.5 | 9.6 | 14.0 | -66% | we are lower |
| deaths in trench | % | 0.7 | 0.0 | 0.7 | 2.2 | 1.0 | -25% |  |
| damage taken | /cog | 6.30 | 10.38 | 9.11 | 9.06 | 9.52 | -34% | we are lower |
| kills | /cog | 0.76 | 0.56 | 0.36 | 0.35 | 0.42 | 78% | we are higher |
| kill/death |  | 1.33 | 0.75 | 0.42 | 0.41 | 0.53 | 152% | we are higher |
| damage dealt | /cog | 9.52 | 7.73 | 5.42 | 5.73 | 6.30 | 51% | we are higher |
| gun kills | % | 52.7 | 34.4 | 29.3 | 33.9 | 32.6 | 62% | we are higher |
| grenade kills | % | 26.6 | 34.4 | 37.9 | 41.1 | 37.8 | -30% | we are lower |
| spray kills | % | 20.6 | 31.1 | 32.8 | 25.0 | 29.6 | -30% | we are lower |
| captures | /cog | 0.77 | 1.16 | 1.39 | 1.36 | 1.30 | -41% | we are lower |

## Largest gaps in what we control (groups 1 and 2)

| stat | unit | ours | rivals' mean | gap | jb-pw-opt:v29 / co-gas-paintbot-bassy-richard:v1 / co-gas-paintbot-relay-bassy-relh:v1 |
|---|---|---:|---:|---:|---|
| shots fired standing | % | 100.0 | 3.7 | 2625% | 3.3 / 3.9 / 3.9 |
| accuracy 30-45 m | % | 47.1 | 11.6 | 306% | 29.6 / 2.6 / 2.6 |
| accuracy with no enemy in view | % | 14.4 | 3.9 | 266% | 7.1 / 1.8 / 2.9 |
| accuracy standing | % | 31.4 | 10.9 | 187% | 18.8 / 6.6 / 7.3 |
| shots from above | % | 53.3 | 18.7 | 185% | 16.2 / 20.4 / 19.6 |
| accuracy 45+ m | % | 20.8 | 7.8 | 167% | 20.6 / 0.9 / 1.8 |
| accuracy 20-30 m | % | 22.3 | 8.8 | 152% | 15.8 / 4.9 / 5.9 |
| gun accuracy | % | 30.5 | 12.9 | 136% | 20.1 / 9.1 / 9.5 |
| accuracy from above | % | 34.2 | 15.3 | 124% | 25.1 / 10.1 / 10.5 |
| first shot | s | 26.3 | 12.2 | 117% | 29.8 / 4.3 / 2.4 |
| spray bursts | /cog | 0.59 | 0.28 | 111% | 0.50 / 0.18 / 0.16 |
| accuracy level | % | 30.3 | 15.9 | 91% | 23.9 / 11.9 / 11.9 |
| accuracy from below | % | 22.7 | 12.1 | 89% | 19.0 / 8.3 / 8.9 |
| wading | % | 2.7 | 15.4 | -82% | 17.8 / 14.1 / 14.4 |
| hits from high ground | % | 28.7 | 15.8 | 82% | 13.2 / 19.4 / 14.7 |
| grenade charging | % | 0.9 | 5.2 | -82% | 1.0 / 7.2 / 7.4 |
| armor | /cog | 0.08 | 0.37 | -79% | 0.56 / 0.28 / 0.28 |
| sneaking | % | 9.8 | 5.7 | 71% | 3.3 / 8.0 / 5.9 |
| medkits | /cog | 0.64 | 0.37 | 70% | 0.79 / 0.16 / 0.17 |
| miss: cover in the way | % | 3.9 | 12.2 | -68% | 10.0 / 13.8 / 12.8 |
| accuracy 10-20 m | % | 31.0 | 18.5 | 67% | 19.8 / 18.8 / 17.1 |
| high ground | % | 30.6 | 18.5 | 65% | 13.8 / 22.5 / 19.1 |
| miss: aim off a still target | % | 2.4 | 6.6 | -64% | 7.5 / 5.8 / 6.5 |
| mister heals | /cog | 0.16 | 0.43 | -62% | 0.33 / 0.45 / 0.52 |
| in a heart ring | % | 5.1 | 12.6 | -60% | 13.1 / 10.6 / 13.9 |
| uniforms | /cog | 0.12 | 0.25 | -52% | 0.26 / 0.27 / 0.23 |
| accuracy 0-10 m | % | 52.4 | 35.0 | 50% | 40.3 / 32.7 / 31.8 |
| shots with no enemy in view | % | 5.3 | 9.7 | -46% | 9.6 / 9.8 / 9.7 |
| range under 20 m | % | 66.7 | 46.4 | 44% | 65.9 / 36.0 / 37.3 |
| windex-misters | /cog | 0.10 | 0.18 | -41% | 0.19 / 0.16 / 0.17 |
| miss: target moved off the line | % | 23.7 | 31.8 | -26% | 35.1 / 29.5 / 30.8 |
