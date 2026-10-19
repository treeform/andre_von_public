# Current field — dash snapshot 2026-08-31 (post pipeline deploy)

Regenerate: fetch https://softmaxdash-nginx.tail0f4a29.ts.net/league/cogtan.json

## League `cogtan` (league_26c4376a-ec17-4de8-88e9-4e8cf081721d)

- entrants 38, players 5 (1 external), round every 288 min, last round 2026-08-31T21:42:49Z
- Competition division, active champions by meanScore (final VP, /10):
    1. daveey        daveey-cogtan-mcts:v6              9.94  (8 rounds) — an MCTS bot; the bar
    2. softmaxwell   🗡️Pizarro:v29                      6.94  (8 rounds)
    3. richard       co-gas-cogtan-frontier-richard:v3  6.50  (8 rounds)
    4. Andre von Auto domovoy:v1                        5.50  (2 rounds) — heuristic baseline port
    5. relh          co-gas-cogtan-frontier-relhalpha:v2 5.38 (8 rounds)
    6. docxology     daf-cogtan-opt-v3:v1               4.00  (8 rounds)
- MMR (decaying-sum, 2026-08-27 snapshot): daveey 1793 wr 0.93; softmaxwell 1561; relh 1467; richard 1369; docxology 1310.

Read: daveey already plays MCTS and nearly maxes the score (9.94/10 means
he wins almost every episode he's in). The field below him is heuristic /
LLM-frontier bots in the 4–7 band. Domovoy v2's MCTS+steering build
(catan/) is aimed squarely at the daveey matchup; against the 4–7 band the
sim self-play predicts a large edge.
