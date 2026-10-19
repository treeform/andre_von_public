# Board Gauntlet rules

Two cogs, one board, no dice and nothing hidden. Both seats see the whole
position, the whole move history and the whole legal-move set. What varies
is the board itself.

## The rotation

`config.game` is one of `rotate`, `connect-four`, `breakthrough`, `hex`,
`quoridor`. The rotation order is the fixed list
`["connect-four", "breakthrough", "hex", "quoridor"]`, indices 0..3. With
`game: "rotate"` the server resolves `game = RotationOrder[((seed mod 4) + 4) mod 4]`
before the first move and records the resolved id in the replay, in
`results.game`, in the player `welcome` frame and in the first line of both
seats' prompts. If `seed` is 0 (unpinned) the server draws one, echoes it and
writes it into the config, so every replay carries a concrete seed and
re-derives exactly. Nothing about the rotation is hidden from a seat, and
because the draw is a pure function of the recorded seed nobody can be
steered into a game either.

## Coordinates

Cells are algebraic: files `a`, `b`, `c`, ... left to right; ranks `1`, `2`,
`3`, ... bottom to top. `a1` is bottom-left. Nothing spectator-facing ever
shows an internal index. Seat 0 always moves first; the league's round robin
seats each policy in both slots, which balances the opening advantage without
a swap rule.

## connect-four (7 files x 6 ranks)

Seat 0 plays red discs, seat 1 blue.

1. A move is a file letter `a`..`g`. It is legal iff that file has at least
   one empty cell.
2. Applying it drops the mover's disc into the lowest empty cell of that file.
3. The mover wins immediately if the placed disc completes a line of four of
   its own discs horizontally, vertically or on either diagonal.
4. If after the move every cell is occupied and nobody has four in a row, the
   game is a draw (`ending = "board-full"`).
5. There is no other way for this game to end other than the ply cap or the
   wall clock.

## breakthrough (6 x 6)

Seat 0 is red, with 12 pieces filling ranks 1 and 2; seat 1 is blue, with 12
filling ranks 5 and 6. Red advances toward rank 6, blue toward rank 1.

1. A move is `<from><to>`, e.g. `b2-c3`. `from` must hold one of the mover's
   pieces; `to` must be one rank forward of `from` and on the same file or one
   file to either side.
2. A straight-forward move is legal only onto an empty cell. There is no
   straight capture.
3. A diagonal-forward move is legal onto an empty cell or onto a cell holding
   an opponent piece, which is then removed.
4. The mover wins immediately if the moved piece lands on the opponent's home
   rank (`ending = "home-rank"`).
5. The mover wins immediately if that move removed the opponent's last piece
   (`ending = "no-pieces"`).
6. If the seat now to move has no legal move, it loses (`ending = "no-moves"`).
7. There are no draws by rule; the ply cap and the wall clock adjudicate.

## hex (7 x 7 rhombus)

Seat 0 is red, seat 1 blue.

1. Cell (r, c) is adjacent to (r, c-1), (r, c+1), (r-1, c), (r+1, c),
   (r-1, c+1) and (r+1, c-1). So `c4` touches `b4, d4, c3, c5, b5, d3`, and the
   corner `a1` touches only `b1, a2`.
2. A move is a cell name. It is legal iff the cell is empty.
3. Applying it places the mover's stone there; stones never move and are never
   removed.
4. Seat 0 connects the left file (`a`) to the right file (`g`); seat 1 connects
   the bottom rank (`1`) to the top rank (`7`). The mover wins immediately when
   its own stones form an unbroken adjacency chain between its two edges
   (`ending = "connection"`).
5. Hex has no draws: a full board contains exactly one winning connection.
   There is no swap (pie) rule.

## quoridor (9 x 9, 10 walls a side)

Seat 0's pawn starts on `e1` and must reach rank 9; seat 1's pawn starts on
`e9` and must reach rank 1. Each seat holds 10 walls.

1. A move is either a pawn move (the destination cell, e.g. `e2`) or a wall
   placement, `<anchor><h|v>` with `anchor` in `a1`..`h8`, e.g. `e3h`.
2. A wall's anchor names the lattice point at the top-right corner of the
   anchor cell: `xNh` blocks the two vertical steps (x,N)<->(x,N+1) and
   (x+1,N)<->(x+1,N+1); `xNv` blocks the two horizontal steps (x,N)<->(x+1,N)
   and (x,N+1)<->(x+1,N+1).
3. A wall placement is legal iff all of: the mover has walls left; no wall of
   either orientation already sits on that anchor; neither of the two steps it
   blocks is already blocked; and, after the placement, both pawns still have
   some path to their own goal rank.
4. A pawn moves to an orthogonally adjacent cell when that step is not
   wall-blocked and the cell is empty. If the adjacent cell in direction d
   holds the opponent pawn, the mover may jump straight over to the next cell
   in direction d when that cell is on the board and the step from the
   opponent's cell in direction d is not wall-blocked; if and only if that
   straight jump is unavailable, the mover may instead move to either cell
   diagonally adjacent to the opponent pawn, perpendicular to d, provided that
   step is not wall-blocked and the cell is on the board.
5. The mover wins immediately on moving its pawn onto any cell of its own goal
   rank (`ending = "goal-row"`).
6. Rule 3's path invariant guarantees a pawn always has a legal move, so
   `no-moves` is unreachable here.

## Move notation, tolerantly read

A reply's `move` is lower-cased, trimmed and stripped of every character
outside `a-z0-9`, then read per game: `connect-four` takes a file letter
`a`..`g` or a digit `1`..`7` mapping to `a`..`g`; `hex` takes `^[a-g][1-7]$`;
`breakthrough` takes `^[a-f][1-6][a-f][1-6]$` and writes `b2-c3`; `quoridor`
takes `^[a-i][1-9]$` for a pawn move and `^[a-h][1-8][hv]$` for a wall.
Anything else is an invalid reply: the seat gets ONE retry carrying the
printed legal-move list, and then falls back to the `tactician` baseline.

## `standing`, and the eval bar

`standing(sim, seat)` is an integer, higher is better for that seat, computed
from the true board and recomputed after every ply. It drives the viewer's
eval bar, it adjudicates the `ply-cap` and `wall-clock` endings, and the
`tactician` baseline maximises it.

- `connect-four`: over all 69 four-cell windows, sum `w[k]` for every window
  that contains no opponent disc, where `k` is the mover's disc count in that
  window and `w = [0, 1, 4, 16, 10000]`.
- `breakthrough`: `100 x pieces + 10 x sum(advance) + 40 x max(advance)`.
- `hex`: `1000 - 10 x distToWin`, where `distToWin` is a 0-1 BFS from the
  seat's source edge to its target edge in which a cell the seat owns costs 0,
  an empty cell costs 1 and an opponent cell is impassable; unreachable is 99.
- `quoridor`: `1000 - 10 x dist + 2 x wallsLeft`, where `dist` is the BFS
  pawn-step distance to the nearest cell of the goal rank over the
  wall-blocked graph.

**The eval bar is THIS repository's own heuristic, not an engine
evaluation**, and the viewer labels it `HEURISTIC` in the bar's own caption.
No OpenSpiel, no external engine and no reference bot is used anywhere.

## Scoring

    score_i = +1  if seat i won
               0  on a draw
              -1  if seat i lost          score_0 + score_1 = 0, always

Higher is better and the league ranks by mean episode `score`. Everything
richer - captures, walls used, final `standing`, plies, fallbacks - is
reported for the audience and the audit and is deliberately NOT scored, so no
policy can farm the metric instead of winning.

## Who won, by ending

| `ending` | Winner |
|---|---|
| `line` | the seat that completed four in a row |
| `connection` | the seat that linked its two edges |
| `home-rank` | the seat whose piece reached the opponent's home rank |
| `no-pieces` | the seat that took the last enemy piece |
| `no-moves` | the seat NOT to move (the starved seat loses) |
| `goal-row` | the seat whose pawn reached its goal rank |
| `board-full` | draw (Connect Four only) |
| `ply-cap` | higher final `standing`; equal -> draw |
| `wall-clock` | higher final `standing`; equal -> draw |

`results.reason` has exactly two legal values, `"complete"` and
`"deadline"`; the finer ending rides in `results.ending`. A `deadline` result
is a REAL result: the position is fully scored by `standing` at the stop.

## Anti-collusion

Two seats, zero-sum, so there is no coalition to form. The rotation is
announced to both seats before move one and is a pure function of the recorded
seed. Seats play under anonymous cog aliases; no prompt, no player frame and
no in-game text ever contains a policy display name. `say` is
spectator-facing only and is never shown to the opponent; `notes` are private
and fed back only to their author; every decision is made inside the game
server from a view the server builds, so there is no wire on which two seats
could coordinate.
