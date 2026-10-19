# Test stages (local, ~2 s a game)

Small scripts that isolate one behaviour, plus the tools to judge them.
All run from `sims/pudge-wars` with `./pwheadless --team-size 2 --duellog DIR`.

- `treedump.nim` — prints the seeded bank trees for a seed and answers
  line-of-sight questions (`--los x0 z0 x1 z1`, trees + fountain).
  Build: `nim c -d:release --path:examples/pudge_wars -o:stages/treedump stages/treedump.nim`
  from `sims/pudge-wars` (copy this file into `sims/pudge-wars/stages/`).
- T1 `treeprobe.bas` — throw detection: cycles blind pokes through a fan of
  aims from a fixed post and flags, from its own head, which ones bounced
  (`attackTarget(900+i)` at the throw, `950+i` on a bounce; read the action
  log). Seed 3 result: mid-path trees and the fountain are detected; an
  obstacle in the last 6 tiles of flight is not (and does not matter).
- T2 `stand.bas` + `poker.bas` — cover: a stand at (32, y) vs a poker at
  (92, y) throwing every cooldown. Seed 3: y 40 (open row) 18 latches in
  23 pokes; y 46 (behind the tree at 38,45) 5 latches in 296 pokes.
- R1 `runeclock2.bas` — rune clock: command the shot at runeSoon = flight + 9
  from a post; vs the new base.bas takes 26-28 of 30 drops, 13-26 at spawn+1.

- T4 `pokerdiag.bas` — dodge band: poker pair vs the v75 pair, 4 games each;
  straight pokes down the lane band catch 2.3 per 100, pokes from 24 tiles
  off the row 3.2 per 100.
- T5 `windup.bas` — windup punish: pokes timed to reach v75's post 3-5
  ticks after a drop (rooted in its rune-throw windup): 2 latches in 547.
  Its first-sight dodge fires ~26 ticks out (river lit), before the windup.
- T6 `combo.bas` — committed-dodge combo (A fixes the dodge side, B fires
  8 ticks later at the predicted body): 1-3 per 100 at every ROW/OFF/SGN.
  Snapshots show v75 in perpetual dodge under two pokers, walking both
  ways equally, and its seat rows move with ours (16-24 when we stand at
  40/52, 36-52 when we stand at 14/26). Blind far pokes are a lottery.
- T7 `bighook.bas` — Big Hook reach (selfBuff = 4: +50% range/head): deep
  pokes at lip+32 land 3.8 per 100 vs 1.7 unbuffed (3 of 79, 8 games);
  the micro-bot took runes 180-70 and still lost every game on kills.

Fill the `coverY` placeholder in stand/poker with sed for each post.
