# Grid Wars rules

## Seats and the series

Four seats, exactly. Seat s is warrior id s+1 (1 red, 2 blue, 3 green, 4 yellow). In-game every
seat plays under an anonymous cog alias drawn from the seed; policy names appear only in the
results and in the replay viewer, never in a prompt.

An episode is a best-of series of `rounds` rounds (default 5, 1..12). One round is:

1. **Submission.** All four seats simultaneously submit a complete warrior program in GWL — a fresh
   one or a patch of their own previous one. This is the only LLM work in the game, and it goes out
   as one parallel batch.
2. **Sealing.** All four scripts are compiled and written to the event log, with the round's derived
   seed, before the first tick runs. No seat ever sees another seat's source, before or after.
3. **The battle.** The four warriors are placed on an empty 30x30 board and the engine runs up to
   `ticks` ticks (default 400, 20..1200). Pure integer arithmetic, no network, ~30 ms.
4. **Scoring**, then the next round, with every seat shown what happened.

## The arena

- The board is 30x30 and **toroidal**: x and y wrap.
- Each cell carries, independently: an owner (0 unclaimed, else a warrior id), at most one live
  bomb, and a permanent corpse flag. A cell holds at most one living warrior.
- Warriors start at the four fixed corners (4,4), (25,4), (4,25), (25,25), assigned by a seeded
  permutation drawn per round and logged in the round event. Each starts with 12 energy.
- **Energy** funds bombs. At the end of every tick a living warrior gains `1 + tiles div 60`, capped
  at 60. `bomb()` costs `bombCost` (default 12).
- **Bombs are walls and weapons.** A live bomb blocks movement and detonates when its fuse reaches
  0. The fuse is 5 and drops by 1 in the same tick the bomb was planted, so a bomb planted on tick
  t detonates on tick t+4 - five ticks of life counting the one it was planted on.
- **Blast:** the bomb's own cell plus its four orthogonal neighbours, wrapping. Every blast cell is
  scorched — its owner reset to 0, any bomb on it consumed — and every warrior standing in it dies.
  Bombs caught in a blast detonate in the same wave: chain reactions resolve to closure.
- **Corpses are permanent walls.**
- **A dead warrior's paint fades:** on elimination every tile it owned reverts to unclaimed, at
  once. Elimination is decisive and the board visibly un-paints.

## Tick resolution order

Exactly this order, every tick, for t = 0 .. ticks-1:

1. **Priority** rotates: seats (0+t) mod 4, (1+t) mod 4, (2+t) mod 4, (3+t) mod 4. All ties in steps
   3-5 break by this order and only by it, so no seat has a structural first-mover advantage.
2. **Decision pass.** Each living, non-halted warrior resumes its VM and runs until it reaches an
   action or spends 2000 instructions. The board is NOT mutated in this pass: every `check`/`who` in
   tick t reads the board as it stood at the end of tick t-1, for every seat.
3. **Bomb pass**, priority order: if alive, `energy >= bombCost` and no live bomb is already on the
   cell, plant one (fuse 5) and pay; otherwise the action is refused.
4. **Place pass**, priority order: the warrior's current cell becomes its own, overwriting any
   previous owner.
5. **Move pass**, priority order: the target is ((x+dx) mod 30, (y+dy) mod 30). The move is blocked
   if the target holds a live bomb, a corpse, or a living warrior — including one that moved there
   earlier in this same pass.
6. **Fuse pass.** Every live bomb's fuse drops by 1.
7. **Detonation pass.** Every bomb at fuse 0 detonates; the closure of their blasts is grown in
   ascending cell index, which makes the closure and the kill attribution deterministic. In one
   wave: every cell in the closure loses its owner and its bomb, and every warrior standing in it is
   eliminated (killedBy = the owner of the lowest-cell-index detonating bomb covering that cell) and
   leaves a corpse.
8. **Idle pass.** A warrior whose cell is unchanged since the previous tick gains an idle point;
   50 kills it.
9. **Fault pass.** Every warrior that faulted this tick is eliminated, with the line and message
   recorded and shown to that seat before the next round.
10. **Bookkeeping.** Every warrior eliminated this tick loses all its tiles; tiles are recounted;
    survivors gain energy.
11. **Round end test.** The round ends after this tick if t+1 == ticks (`horizon`), or exactly one
    warrior is alive (`lastStanding`), or none is (`wipeout`).

Every quantity above is an integer. No hash-table iteration order, no floating point, no wall-clock
input: the battle is a pure function of (scripts, round seed, config), which is what lets the
browser's wasm viewer re-derive every tick and check its own digest.

## Scoring — zero-sum, higher is better

Per round, per seat:

    raw[s]        = tiles[s] + 100 if alive at round end + 50 * kills[s] - 50 * selfKills[s]
    roundScore[s] = raw[s] - (raw[0] + raw[1] + raw[2] + raw[3]) / 4

Per episode: `score[s] = (sum of roundScore[s] over played rounds) / roundsPlayed`.

The four scores sum to exactly zero. Higher is better: a seat that out-paints and outlives the field
is positive and the field is negative. The league ranks by mean `score`. `roundsWon` and total
`tiles` are reported for display and are the endcard tie-breaks only.

## End conditions

`results.reason` is `complete` (all rounds played) or `deadline` (the episode clock stopped play
between rounds; scores use the rounds actually played). Those are the only two values. Per-round
endings — `horizon`, `lastStanding`, `wipeout` — are reported in `results.roundReasons`.

## What a seat sees

Its alias, its warrior id and colour; the round number and the totals; its OWN current script with
line numbers; its own diagnostics from the previous round (compile error, fault line and message,
ticks survived, death cause, final and peak tiles, kills, selfKills, illegal, blocked, refused,
stalls, and its tile count sampled every 25 ticks); the series table by alias; the previous round's
final board as a 30x30 ASCII map; and its own private notes.

Hidden from every seat, always: every other seat's script source (sealed, before and after), every
other seat's notes and banner, the mapping alias -> policy name, and the round seed before the round
runs.
