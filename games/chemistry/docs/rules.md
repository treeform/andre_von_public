# Rules

## The room
A fixed 32x18 grid, 48 board pixels a cell. Walls are the border ring plus two 2x2 pillars. Three vats sit on 3x3 pads: amber (16,4) takes resin+spark, beryl (23,11) takes spark+brine, cobalt (9,11) takes resin+brine. Feedstock vents: resin (4,3), spark (28,3), brine (16,15). Distractor vents (variants 2 and 4): glitter (9,3), quartz (23,3).

## The reaction graph
| species | kind | source | used by |
|---|---|---|---|
| resin | feedstock | (4,3) | amber, cobalt |
| spark | feedstock | (28,3) | amber, beryl |
| brine | feedstock | (16,15) | beryl, cobalt |
| glitter | INERT | (9,3) | nothing |
| quartz | INERT | (23,3) | nothing |

## The nine-step tick order
Every tick runs these nine steps in order; within a step seats resolve in ascending slot order and reactors in the order amber, beryl, cobalt.
1. Vents emit (resin, spark, brine, glitter, quartz), one unit onto the first free orthogonal neighbour in N,E,S,W order, gated by the ground cap.
2. The courier kernel computes each cog's action from its standing order.
3. take / drop resolve. A drop on a pad enters that vat's stock, or is a MISDROP: absorbed and destroyed.
4. Moves resolve against the live board; a cell another cog already took is a failed move that degrades to wait.
5. Auto-eat: every cog standing on a food token eats it (+1 score).
6. Reactions: cold start first at charge 0, else a reaction. Food lands on free spill-ring cells ordered by distance to the delivering cog.
7. Charge decay, once per chargeDecayPeriod ticks.
8. Food rot at foodLifetime ticks.
9. Record the state frame, the events and the charge row.

## Charge, decay and the cold start
A reaction sets charge = min(chargeMax, charge + 1) and yields 1 + charge div 3 food. Charge decays by 1 every chargeDecayPeriod ticks; reaching 0 emits a `cold` event. A vat at charge 0 returns to charge 1 only by consuming coldStartCost of EACH feedstock, and makes no food doing it.

## Scoring and the end conditions
Seat score = food tokens eaten, higher is better; `win` marks every seat holding the maximum. The episode ends at the FIRST of: all shifts played (`complete` / `shift_limit`); every vat cold for three consecutive shift boundaries with no food on the floor (`complete` / `famine` -- a famine is a completed game of Chemistry, not an error); the play deadline at 60% of episodeTimeoutSeconds (`deadline`); or no seat connected within playerConnectTimeoutSeconds (`forfeit`).
