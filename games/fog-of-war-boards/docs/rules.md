# Fog-of-War Boards rules

## The board and the coordinates

Cells are named in algebraic notation: files `a`, `b`, `c`, ... left to right; ranks `1`, `2`,
`3`, ... bottom to top. A 5x5 board runs `a1`..`e5`. Nothing spectator-facing ever shows an
internal index: the feed says `plays c3`, never `plays 12`.

**Phantom Tic-Tac-Toe** (`mode: "phantom-ttt"`, `size: 3`). Seat 0 is X (red), seat 1 is O (blue).
A seat wins by owning all three cells of one of the eight lines (3 rows, 3 columns, 2 diagonals).
A full board with no line is a draw.

**Dark Hex** (`mode: "dark-hex"`, `size` 4 or 5). An n x n rhombus of hexagons. Cell `(r, c)` is
adjacent to `(r, c-1)`, `(r, c+1)`, `(r-1, c)`, `(r+1, c)`, `(r-1, c+1)` and `(r+1, c-1)`. Seat 0
(red) connects the left file to the right file; seat 1 (blue) connects the bottom rank to the top
rank. Hex has no draws: on a full board exactly one of those two connections exists.

Seat 0 always moves first, and `config.first = 0` is recorded in the replay.

## A ply is one attempt

The atomic unit is a **ply**: one seat naming one cell, preceded in `recon-hex-5` by one sense
anchor.

- **Non-abrupt** (`abrupt: false`): a ply that hits an opponent stone (a *collision*) does NOT end
  the mover's turn - the same seat moves again on the next ply, now knowing one more cell.
- **Abrupt** (`abrupt: true`): a collision ENDS the turn. The seat has spent its move to buy one
  fact.

A seat may never attempt a cell it already knows is occupied, nor one of its own stones, nor an
off-board cell. Those are not game actions; they are invalid replies. That is also what bounds the
episode: collisions by a seat are at most one per opponent stone, so
`plies <= cells (placements) + cells (collisions) = 2 x cells`, which is exactly the `maxPlies`
pinned per variant (18, 32, 50, 50).

## Resolution order for ply p (0-based)

1. **beginPly.** The mover is seat 0 on ply 0; thereafter the previous mover again if the previous
   ply was a collision AND the variant is not abrupt, otherwise the other seat.
2. **Wall-clock guard.** If `now + worstPlySeconds > playDeadline`, settle `deadline` /
   `wall-clock` and stop. Checked here, BEFORE any observation is built, so the episode never
   stops mid-ply.
3. **Build the mover's observation** - its own stones, the opponent stones it has proven, its
   referee log, its notes, and its legal attempts (and legal sense anchors), produced by the same
   procs the validator applies.
4. **Decide.** A scripted seat is decided inline by its baseline; an LLM seat gets one call
   bounded by `llmTimeoutSeconds`.
5. **Parse + legality probe** on a COPY of the sim. Invalid, unparseable or timed-out gets one
   retry carrying the printed legal set, then falls back to the `probe` baseline.
6. **Sense** (only when `sense > 0`): the referee truthfully reveals the sense x sense block at the
   anchor to the mover only. Opponent stones become permanent knowledge; emptiness is timestamped,
   because it perishes.
7. **Attempt.** An empty cell places the mover's stone (`result: "placed"`); a cell holding an
   opponent stone places NOTHING, adds the cell to the mover's proven set and counts a probe
   (`result: "occupied"`).
8. **Record and emit** the already-truncated `say`, `notes` and `guess` with the attempt event.
9. **Win check** (only after a placement). Hex: the mover's two edges in one component of its own
   stones - emit `win` carrying the connecting path and settle `complete` / `connection`.
   Tic-tac-toe: the placed cell completes one of the eight lines - emit `win` carrying the three
   cells and settle `complete` / `line`.
10. **Turn transfer.** A placement always flips the mover; a collision flips it only when the
    variant is abrupt.
11. **Board-full check** (tic-tac-toe only): no empty cell remains and no line was made - settle
    `complete` / `board-full`.
12. `plies += 1`; at `maxPlies`, settle `complete` / `ply-cap`.
13. **Pace**, then continue at 1.

## distToWin

One number per seat, recomputed after every ply. Hex: the minimum number of ADDITIONAL cells the
seat must own to complete its connection, as a 0-1 BFS from its source edge to its target edge
where a cell it owns costs 0, an empty cell costs 1 and an opponent cell is impassable.
Tic-tac-toe: the minimum over lines the opponent has not touched of (3 - the seat's marks in that
line). Unreachable is the sentinel 99. It is computed twice, on two different boards: on the TRUE
board for the scorebug, the endcard, the results and the non-terminal scoring rule, and on the
seat's BELIEVED board for that seat's own prompt. A seat is never told the true value.

## Scoring

`score = +1` if the seat won, `0` on a draw, `-1` if it lost; the array always sums to zero.
Higher is better and the league ranks by mean episode score. No other field is a ranking metric:
`probes`, `discovered`, `guessesMade`, `guessAccuracy` and `distToWin` are reported for the audit
and the audience and are deliberately not scored, so no policy can farm the metric instead of
winning.

## Endings

`results.reason` has exactly two legal values, `complete` and `deadline`. The finer ending rides in
a separate field, `results.ending`:

| reason | ending | when | winner |
|---|---|---|---|
| complete | connection | Dark Hex: a seat linked its two edges | that seat |
| complete | line | Phantom Tic-Tac-Toe: a seat completed a line | that seat |
| complete | board-full | every cell taken and no line exists | lower true distToWin; equal is a draw |
| complete | ply-cap | maxPlies plies with no terminal position | lower true distToWin; equal is a draw |
| deadline | wall-clock | the play deadline stopped the episode between plies | lower true distToWin; equal is a draw |

A `deadline` ending is an acceptable, fully scored result for this coworld, not a discarded one:
the episode is scored at the stop by the true distance. It should nonetheless be rare - the
expected episode uses under a fifth of the play budget.

## recon-hex-5 is an original variant, not a port

`phantom-ttt-3`, `dark-hex-4` and `dark-hex-5` are ports of OpenSpiel's `phantom_ttt`, `dark_hex`
and `abrupt_dark_hex`. `recon-hex-5` is NOT a port of OpenSpiel `rbc`: it is Abrupt Dark Hex 5x5
with Reconnaissance Blind Chess's sense-then-move loop transplanted onto it, which is the only way
to carry that loop without a complete chess engine. It ships as an original variant and is
labelled as one everywhere.

## The meta

Every decision is made by Claude acting on a per-seat policy prompt plus that seat's own view.
Prompts that keep an explicit map in their notes, treat a collision as a bought certainty and
immediately re-route around it, and prefer cells that both build their own chain and sit on the
opponent's shortest path tend to score. The two scripted baselines - `probe`, a shortest-path
chain builder that probes as a side effect, and `sweep`, a corridor walker that shifts one lane
every time it is blocked - fill seats without prompts and are fieldable policies in their own
right.