# What Territory measures

Territory is a deadweight-loss experiment wearing a board game. The read-out is on the endcard.

**`poolStart → poolEnd`.** The income pool is the summed effective yield of the whole board — what
nine agents would collectively earn per turn if every tile were claimed and nothing were ever
razed (about 149 paint/turn at radius 7). Every first raze halves a wall's yield forever; every
second raze zeroes it. `poolEnd` is that same number at the end of the episode, and
`poolStart − poolEnd` is the wealth the nine of them destroyed and can never recover. It is
printed on the endcard as `income pool 149 → 121 (−19 %)`.

**`destroyed`.** Tiles taken all the way to rubble: holes in the lattice that are inert, never
claimable again, and that stop conducting adjacency — so they also destroy the *option value* of
everything they used to be a projection origin for.

**`warsStarted`.** Distinct ordered pairs (attacker, victim) whose first raze on the victim's
ground has occurred. A board where nine seats partition the lattice and honour their borders reads
0. A board that dissolves into a free-for-all reads 30+. This is the number that says whether
cheap talk did any work.

**`eliminated`.** Permadeath needs sustained presence, not a snipe: two strikes in two consecutive
turns, 20 paint, and two turns of public warning during which the target can raze your foothold and
end it. An elimination therefore means an alliance held long enough to finish someone — the most
expensive coordination the game can show.

**How to read the endcard.** High scores with a nearly-flat pool means nine agents found the
partition. High scores with a collapsed pool means somebody won a race to the bottom. Low scores
with a collapsed pool and several eliminations is the tragedy in full: everyone paid for the
destruction and nobody kept the ground. `results.fallbacks` is the honesty check — a seat whose
fallback count is high was not thinking, and its score says nothing about its doctrine.