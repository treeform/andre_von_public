# trackpick vs eider v7

40 replays re-simulated with the hosted engine rules (0 state-hash mismatches, 0 replays without a roster skipped). Columns are policy versions, ordered by glory per game. Replay rows are means over the policy's seat-games unless noted.

The first column is ours (trackpick). Gap = (ours - rivals' mean) / rivals' mean. A row is flagged when the gap is at least 25% (and, for % rows, at least 2 points).

## 1. Controlled directly: movement, footwork, aiming, shooting

| stat | unit | trackpick | eider:v7 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---|
| friendly damage | /cog | 0.89 | 0.66 | 0.66 | 36% | we are higher |
| enemy in view | % | 51.8 | 37.0 | 37.0 | 40% | we are higher |
| gun shots | /min | 20.5 | 22.3 | 22.3 | -8% |  |
| gun accuracy | % | 35.0 | 29.3 | 29.3 | 20% |  |
| first shot | s | 9.9 | 2.9 | 2.9 | 238% | we are higher |
| shots with no enemy in view | % | 14.8 | 27.9 | 27.9 | -47% | we are lower |
| accuracy with no enemy in view | % | 32.6 | 17.7 | 17.7 | 84% | we are higher |
| range under 20 m | % | 5.6 | 6.1 | 6.1 | -8% |  |
| accuracy 0-10 m | % | 36.1 | 47.8 | 47.8 | -24% |  |
| accuracy 10-20 m | % | 36.8 | 32.8 | 32.8 | 12% |  |
| accuracy 20-30 m | % | 35.5 | 36.0 | 36.0 | -2% |  |
| accuracy 30-45 m | % | 37.2 | 33.9 | 33.9 | 10% |  |
| accuracy 45+ m | % | 34.4 | 32.8 | 32.8 | 5% |  |
| shots fired standing | % | 100.0 | 82.4 | 82.4 | 21% |  |
| accuracy standing | % | 35.5 | 38.5 | 38.5 | -8% |  |
| accuracy moving | % | — | 11.6 | 11.6 | — |  |
| shots from above | % | 55.6 | 21.8 | 21.8 | 154% | we are higher |
| accuracy from above | % | 37.2 | 42.4 | 42.4 | -12% |  |
| accuracy level | % | 36.0 | 33.8 | 33.8 | 7% |  |
| accuracy from below | % | 30.7 | 30.2 | 30.2 | 2% |  |
| hits from high ground | % | 55.3 | 29.5 | 29.5 | 88% | we are higher |
| hits from trench | % | 0.4 | 0.4 | 0.4 | 11% |  |
| miss: cover in the way | % | 14.8 | 21.1 | 21.1 | -30% | we are lower |
| miss: target moved off the line | % | 26.1 | 28.1 | 28.1 | -7% |  |
| miss: aim off a still target | % | 10.3 | 3.2 | 3.2 | 225% | we are higher |
| miss: in radius, no hit | % | 9.0 | 10.5 | 10.5 | -14% |  |
| miss: teammate in the way | % | 1.7 | 2.0 | 2.0 | -18% |  |
| miss: nobody near the line | % | 2.7 | 1.4 | 1.4 | 97% |  |
| speed | m/s | 5.38 | 5.72 | 5.72 | -6% |  |
| moving | % | 85.3 | 90.1 | 90.1 | -5% |  |
| wading | % | 0.9 | 0.6 | 0.6 | 59% |  |
| sneaking | % | 4.7 | 3.8 | 3.8 | 24% |  |
| in trench | % | 0.6 | 0.7 | 0.7 | -3% |  |
| high ground | % | 43.8 | 28.6 | 28.6 | 53% | we are higher |
| nearest teammate | m | 12.4 | 11.0 | 11.0 | 13% |  |
| lead on a moving target | ticks | 3.8 | 2.2 | 2.2 | 75% | we are higher |
| sight run length | ticks | 8.3 | 2.8 | 2.8 | 197% | we are higher |
| new sightings | /min | 159.0 | 310.4 | 310.4 | -49% | we are lower |
| shots at a target in view | % | 98.9 | 98.7 | 98.7 | 0% |  |
| shots at a tracked target | % | 75.8 | 38.6 | 38.6 | 96% | we are higher |
| unled shots at movers | % | 21.7 | 63.0 | 63.0 | -66% | we are lower |
| standing with an enemy in sight | % | 19.9 | 17.7 | 17.7 | 12% |  |
| run length in sight | ticks | 6.8 | 2.0 | 2.0 | 239% | we are higher |
| runs ended by reversing | % | 33.6 | 81.6 | 81.6 | -59% | we are lower |
| direction changes in sight | /s | 1.28 | 5.12 | 5.12 | -75% | we are lower |
| in a heart ring | % | 3.2 | 2.3 | 2.3 | 40% |  |
| walk orders | % | 100.0 | 100.0 | 100.0 | 0% |  |
| shoot orders | % | 1.5 | 1.6 | 1.6 | -8% |  |
| direct walks | % | 0.0 | 0.0 | 0.0 | — |  |
| grenade charging | % | 0.1 | 0.1 | 0.1 | -22% |  |

## 2. Controlled indirectly: items picked up and used

| stat | unit | trackpick | eider:v7 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---|
| grenades picked | /cog | 2.27 | 2.37 | 2.37 | -4% |  |
| grenades thrown | /cog | 0.28 | 0.29 | 0.29 | -5% |  |
| grenade hits | /throw | 0.31 | 0.23 | 0.23 | 36% | we are higher |
| spray cans | /cog | 0.19 | 0.21 | 0.21 | -8% |  |
| spray bursts | /cog | 0.02 | 0.00 | 0.00 | 500% | we are higher |
| armor | /cog | 0.07 | 0.39 | 0.39 | -81% | we are lower |
| medkits | /cog | 0.57 | 0.58 | 0.58 | -1% |  |
| glory hearts | /cog | 0.23 | 0.64 | 0.64 | -65% | we are lower |
| uniforms | /cog | 0.06 | 0.04 | 0.04 | 29% | we are higher |

## 3. Outcomes: winning, killing, dying, territory

| stat | unit | trackpick | eider:v7 | rivals' mean | gap | flag |
|---|---|---:|---:|---:|---:|---|
| games |  | 40 | 40 | 40 | 0% |  |
| win rate | % | 62.5 | 37.5 | 37.5 | 67% | we are higher |
| draw rate | % | 0.0 | 0.0 | 0.0 | — |  |
| glory per game |  | 355 | 252 | 252 | 41% | we are higher |
| glory per win |  | 567 | 673 | 673 | -16% |  |
| match length | s | 129 | 129 | 129 | 0% |  |
| deaths | /cog | 3.48 | 3.79 | 3.79 | -8% |  |
| lives left | /cog | 0.92 | 0.37 | 0.37 | 149% | we are higher |
| first death | s | 34.8 | 37.3 | 37.3 | -7% |  |
| deaths in water | % | 1.9 | 1.4 | 1.4 | 35% |  |
| deaths in trench | % | 0.3 | 0.5 | 0.5 | -45% |  |
| damage taken | /cog | 10.36 | 11.46 | 11.46 | -10% |  |
| kills | /cog | 3.54 | 3.04 | 3.04 | 17% |  |
| kill/death |  | 1.02 | 0.80 | 0.80 | 27% | we are higher |
| damage dealt | /cog | 11.46 | 10.36 | 10.36 | 11% |  |
| gun kills | % | 97.4 | 97.8 | 97.8 | 0% |  |
| grenade kills | % | 2.2 | 2.2 | 2.2 | 2% |  |
| spray kills | % | 0.4 | 0.0 | 0.0 | — |  |
| captures | /cog | 0.47 | 0.38 | 0.38 | 21% |  |

## Largest gaps in what we control (groups 1 and 2)

| stat | unit | ours | rivals' mean | gap | eider:v7 |
|---|---|---:|---:|---:|---|
| spray bursts | /cog | 0.02 | 0.00 | 500% | 0.00 |
| run length in sight | ticks | 6.8 | 2.0 | 239% | 2.0 |
| first shot | s | 9.9 | 2.9 | 238% | 2.9 |
| miss: aim off a still target | % | 10.3 | 3.2 | 225% | 3.2 |
| sight run length | ticks | 8.3 | 2.8 | 197% | 2.8 |
| shots from above | % | 55.6 | 21.8 | 154% | 21.8 |
| shots at a tracked target | % | 75.8 | 38.6 | 96% | 38.6 |
| hits from high ground | % | 55.3 | 29.5 | 88% | 29.5 |
| accuracy with no enemy in view | % | 32.6 | 17.7 | 84% | 17.7 |
| armor | /cog | 0.07 | 0.39 | -81% | 0.39 |
| lead on a moving target | ticks | 3.8 | 2.2 | 75% | 2.2 |
| direction changes in sight | /s | 1.28 | 5.12 | -75% | 5.12 |
| unled shots at movers | % | 21.7 | 63.0 | -66% | 63.0 |
| glory hearts | /cog | 0.23 | 0.64 | -65% | 0.64 |
| runs ended by reversing | % | 33.6 | 81.6 | -59% | 81.6 |
| high ground | % | 43.8 | 28.6 | 53% | 28.6 |
| new sightings | /min | 159.0 | 310.4 | -49% | 310.4 |
| shots with no enemy in view | % | 14.8 | 27.9 | -47% | 27.9 |
| enemy in view | % | 51.8 | 37.0 | 40% | 37.0 |
| grenade hits | /throw | 0.31 | 0.23 | 36% | 0.23 |
| friendly damage | /cog | 0.89 | 0.66 | 36% | 0.66 |
| miss: cover in the way | % | 14.8 | 21.1 | -30% | 21.1 |
| uniforms | /cog | 0.06 | 0.04 | 29% | 0.04 |
