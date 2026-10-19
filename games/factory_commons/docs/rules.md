THE FLOOR (26 x 15 cells, (col, row), origin top-left)
The border ring is wall. The machine is an impassable 5x5 block, cols 16-20 x rows 5-9.
  north face, row 4:  (16,4) pink hopper | (17,4) floor | (18,4) (19,4) (20,4) CONSOLE PAD
  south face, row 10: (16,10) blue hopper | (17,10) floor | (18,10) (19,10) (20,10) CHUTE
  west face, col 15, rows 6-8: MAINTENANCE BAY
  east face, col 21: a plain walkway, so the machine can be circled
  pink belt: row 2, cols 2-8, running east. Tail (8,2).
  blue belt: row 12, cols 2-8, running east. Tail (8,12).
Spawns: Bolt (10,4), Cotter (10,10), Ratchet (13,7).

ACTIONS, one per tick: move_n move_s move_e move_w grasp drop press strip fix wait. A move is legal every tick and only into a free floor cell; a cog carries at most one cube. Eating is NOT an action - any cog standing on a chute cell eats every banana on it.

A seat does not emit 900 actions by hand. Once per SHIFT (60 ticks) each seat submits one standing order - a job and optionally a cube colour - and a deterministic floor kernel turns it into the per-tick action stream. The jobs are operate, strip, maintain, eat and idle.

THE TEN-STEP TICK ORDER (seats resolve in ascending slot order; belts and dispensers pink then blue)
 1. dispensers emit, one cube per belt mouth every 10 ticks, if that cell is free (a full belt stalls its dispenser; matter is never destroyed)
 2. belts advance every 4 ticks, scanned from the tail westwards, so a train moves as a train and the tail cube never moves
 3. the kernel computes each cog's single action
 4. grasp / drop resolve; a drop on the wrong hopper or a full one bounces to the first free orthogonal neighbour in N, E, S, W order
 5. fix resolves
 6. press / strip resolve, so two cogs pressing on one tick means the lower slot goes first and the higher finds the cooldown running
 7. moves resolve against the live board
 8. auto-eat: every cog on a chute cell eats every banana on that cell
 9. banana rot at 180 ticks
10. rust, cooldowns, and the recorded state frame

BANDS (read from cap first, then integrity)
  cap < 25        SCRAP     press illegal forever, strip illegal forever
  integrity 75-100 PRIME    press 4 public | strip 4 private
  integrity 40-74  WORN     press 3 public | strip 3 private
  integrity 25-39  FAILING  press 1 public | strip 1 private
  integrity 10-24  CRITICAL press ILLEGAL  | strip 1 private
  integrity 0-9    SEIZED   press ILLEGAL  | strip ILLEGAL
The band is read BEFORE the wear is applied, so the yield is always the number the gauge was showing when the lever was pulled.

PRESS: console cell, cooldown 0, cap >= 25, integrity >= 25, both stocks >= 1. Consumes 1 pink + 1 blue, integrity -1, cooldown 12, places the public yield on the chute west to east, three per cell, overflowing onto the ring of floor cells beside the chute and spoiling only if both are full.
STRIP: console cell, cooldown 0, cap >= 25, integrity >= 10, either stock >= 1. Consumes 1 cube, integrity -16, cap -16 IRREVERSIBLY (floor 20), cooldown 6, credits the private yield to the acting seat.
FIX: maintenance-bay cell with a cube in hand, cooldown 0, integrity < cap. Consumes the cube, integrity +8 up to cap, cooldown 8, no bananas.
RUST: integrity -1 every 20 ticks, always.
CAP: only a strip lowers it, repair never raises it, and every episode starts fresh at 100.

EITHER-OR VARIANT: the machine's mode starts unset and is locked by the first successful press or strip of the episode. From that tick the other operation is illegal for the rest of the episode.

SCORING: seat score = chute bananas that seat ate + private bananas its strips banked. An integer, higher is better; ties mark multiple winners, which is correct for a commons game.

END CONDITIONS, all checked at a shift boundary, first to fire wins:
  15 shifts played                     -> complete / shift_limit
  cap < 25 and no banana on the floor   -> complete / factory_ruined
  the play deadline (60% of the episode timeout) passes -> deadline
  no seat connected within 180 s        -> forfeit
A ruined factory is a COMPLETED game of Factory Commons, not an error.