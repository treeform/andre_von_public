# zhar vs the top three, hosted XP (h17_v64)

Win test: binomial z of wins against losses (draws left out), two-sided p. Score test: paired t on our glory minus theirs per episode (a loss scores 0).

| rival | n | W-D-L | win % | 95% Wilson | win z | p | our glory | their glory | diff | paired t | p | verdict |
|---|---:|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---|
| jb-pw-opt:v29 | 32 | 25-0-7 | 78.1 | [0.61, 0.89] | 3.18 | 0.001 | 385. | 144. | +241. | 2.76 | 0.006 | win ahead, score ahead |
| co-gas-paintbot-bassy-richard:v1 | 32 | 24-0-8 | 75.0 | [0.58, 0.87] | 2.83 | 0.005 | 394. | 210. | +184. | 1.64 | 0.102 | win ahead, score not significant |
| co-gas-paintbot-relay-bassy-relh:v1 | 32 | 19-0-13 | 59.4 | [0.42, 0.74] | 1.06 | 0.289 | 309. | 523. | -213. | -1.26 | 0.206 | win not significant, score not significant |
| all three | 96 | 68-0-28 | 70.8 | [0.61, 0.79] | 4.08 | 0.000 | 363. | 292. | +70. | 0.93 | 0.352 | win ahead, score not significant |
