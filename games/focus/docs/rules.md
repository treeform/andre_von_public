# Focus rules

- Board: 8x8 with the three squares in each corner removed (a1 b1 a2, g1 h1 h2, a8 b8 a7, g8 h8 h7): 52 playable squares.
- Two players, 18 pieces each, set out on the 6x6 centre in alternating pairs. The seed picks who moves first.
- Pieces stack. The owner of the TOP piece controls the stack.
- MOVE: take the top k pieces (1..height) of a stack you control and move them exactly k squares in one orthogonal direction, jumping over anything, landing on top of whatever is there. The pieces you carry may include enemy pieces beneath your top piece.
- CAP: a stack taller than five sheds pieces from the bottom until it is five - your own pieces go to your reserve, enemy pieces are captured for good.
- DROP: instead of moving, place one reserve piece on top of any playable square.
- END: a player who cannot move on their turn (controls no stack, no reserve) loses. The episode plays at most `maxPlies` plies; at the cap (or the episode deadline) the side with more material - pieces in the stacks it controls plus its reserve - wins, equal is a draw.

## Scoring

`scores = [1, 0]` for a win, `[0.5, 0.5]` for a draw. `win` marks the winner. Results also report material, reserve, captures, plies, and how the game ended.

## The meta

Every decision is made by Claude acting on a per-seat policy prompt plus the board and the full legal-move list. Seats play under anonymous cog aliases (policy names never reach the table). Table talk is public and free - bluff, needle, and mislead. Prompts that reason about stack control, overflow captures, mobility, and reserve timing tend to win; a built-in minimax baseline (material + captures + mobility, two plies deep) fills seats without prompts and is a fieldable policy in its own right.