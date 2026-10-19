# Winning playbook

How to actually break a game, in priority order. Applies on top of the
scoring rules in ../auto.md (hosted XP only, one change per experiment).
The source notes for this playbook live in ../howtowin.md.


## 0. Hunt big ideas, not tweaks

Wins come from big ideas, not small optimizations (howtowin.md). The
canonical example: the bot never used the flamethrower; code to use it
won 95% of games. Triage data agrees — 22 small fleet tweaks all lost
their A/Bs, while every win was structural (a real policy replacing a
floor, a dead seat fixed, a dominant stat build, an MCTS rewrite). When
reading the sim (step 2), the first question is: WHICH MECHANIC IS
NOBODY USING? An unused verb, item, or ability in the action space is
the most likely flamethrower.

## 1. Look for published winning policies

Before writing strategy from scratch, search GitHub (and the wider web)
for the game's name plus "policy", "bot", "coworld", the league leaders'
usernames, and the example-policy repo's forks. Players sometimes publish
their winning policy — on purpose or by accident (a public fork, a
leftover branch, a pastebin in an issue). A readable winning policy is
worth more than a week of blind experiments. Check `field.md` for who is
on top, then hunt for their code.

Found policies get recorded in `others/others.json` (repo, player,
notes) and checked out under `others/<coworld>/<bot>/` via
`nim r tools/sync_others.nim`; game sim sources live in `sims/<game>/`
via `nim r tools/sync_sims.nim` — grep those before fetching anything
from the network.


## 2. Read the simulation source for exploitable mechanics

The game's own sim (often public, or vendorable from the manifest's
pinned commit) is the ground truth. Read it looking for:

- **Crackable randomness**: a 32-bit (or smaller) seed can be brute
  forced from a few observed draws — then you know every shuffle, every
  hand, every spawn before it happens.
- **Mathematically OP moves**: one action whose expected value dominates
  everything else in the payoff code. If it exists, spam it.
- **Information leaks**: an observation field that reveals more than the
  rules imply, or a move that lets you influence another player's
  action or read their hidden state.
- **State-dependent vision**: e.g. fog of war that lifts while dead or
  spectating — die once, memorize the map.

Some of these "bugs" are intentional and are simply how the game is won.
Verify any candidate exploit in a replay or isolation test before
building on it, then confirm on hosted XP.

## 3. Re-check the sim on every version bump

The coworld version we originally wrote the player against drifts. On
every game update (watch `manifest.json`'s version / the coworld's
pinned commit): diff the sim source between our vendored/reference
commit and current, and read the changelog. New moves, rebalances, and
new observation fields are free strength we are otherwise not using —
and mirrors/ports desync outright (tribal_village's sim-mirror bot plays
garbage on any version bump). Record the checked version in ideas.md.

## 4. Board games: MCTS with a steering loop

Most of the board-game category (see ../GAMES.md) falls to Monte Carlo
Tree Search plus distillation, iterated:

1. Run MCTS over the ported rules.
2. Extract the moves it reliably prefers.
3. Distill those into a steering policy — guard rails whose job is to
   never make an obviously terrible move, not to be optimal.
4. Run MCTS again with the steering policy pruning/ordering the tree
   (better rollouts, deeper search in the same budget). Loop.

This needs the game rules ported into the policy (a fast Nim sim of the
game), which is also step 2's reading done properly. The full-Nim
command seats can run this directly; for prompt seats, the distilled
steering rules become the operator prompt's explicit move-ordering
checklist.

## 5. Behavioral-clone the top players from replays

Even without their source, top players leak their strategy through their
moves. Build replay extractors (each game's `tools/` dir) that:

1. Record the top player's moves across many replays — not one situation,
   the full move distribution.
2. Tabulate what percentage of their moves our policy would also make in
   the same states.
3. Feed our player the same inputs the top player saw and diff the
   outputs; drive the match percentage up experiment by experiment.

Matching the distribution over many simulations, rather than imitating
single flashy moves, is what recovers the actual strategy.
