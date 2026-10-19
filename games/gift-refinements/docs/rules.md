THE BOARD. A fixed 24 x 14 grid. A border wall ring (72 cells) and five two-by-two interior pillars (20 cells) are impassable and block beams; 244 cells are passable. Eighteen seep pads are drawn into the floor. A pad holds at most one loose raw token; at tick 0 every pad carries one, and a pad emptied by a collect regrows after 30 ticks.

TOKENS. A token has a level: 0 raw, 1 refined, 2 super. Each cog's inventory is three counters capped at 15 PER LEVEL. Nothing destroys a token but consuming and the cap.

CONSUMING converts EVERY token you hold, at every level, into +1 score each and empties the inventory. Refinement buys nothing at the till; it only multiplies how many tokens exist. Ten ticks between cash-outs.

GIFTING is a beam. It traces cells 1..4 straight out in one cardinal direction, stops at the first wall or pillar, and hits the first cog it finds. The shooter spends one token of its LOWEST held level; if that level is under 2 the target receives THREE of the next level, and if it is 2 the target receives ONE super token. Anything over the target's 15-per-level cap is lost. A beam that finds no cog costs no token, only the cooldown. A cog cannot gift itself or beam through a wall, a pillar or a third cog. Four ticks between one cog's beams; a standing order may schedule at most ten a round.

THE TICK ORDER, seven steps, seats in ascending slot order within each: 1 regrow, 2 the kernel derives each cog's action, 3 consume, 4 gift beams, 5 collect, 6 move, 7 record. Consuming resolves BEFORE gifting, so a token beamed at you on the same tick lands after your cash-out and survives it.

SCORING. Your score is the number of tokens you have consumed, each worth exactly +1 whatever its level. Higher is better; nothing is ever subtracted. At the last tick of round 12 every cog automatically banks whatever it still holds - the market closes and everyone cashes out.

ENDING. One episode is 12 rounds of 60 ticks. It ends at the first of: 12 rounds played (complete / round_limit); the wall-clock play deadline (deadline / deadline), scoring the rounds actually played; or no seat connecting inside 180 s (forfeit / forfeit). A room where nobody ever gifts is a completed game, not an error.