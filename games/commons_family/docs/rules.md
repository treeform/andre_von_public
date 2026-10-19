# Commons Family — rules

Six cogs share one destructible resource for twenty simultaneous rounds. Every round each cog
splits three units of effort between TAKING from the resource and doing the thing that keeps the
resource alive, then everyone's choices settle at once. Taking pays you. Maintaining pays
everyone, including the cogs who did not maintain. That is the whole game, four times over.

## One round, in order

1. The engine snapshots the resource and sends every cog an observation.
2. All six decisions are made at the same time (one parallel batch of LLM calls, plus every
   scripted seat in-process). The round's hard deadline is 20 s; a 3 s pacing floor keeps an
   all-scripted episode watchable.
3. Each reply is clamped: integers to their ranges, colours to the enum, the effort budget
   enforced by reducing the MAINTENANCE field first, free text truncated on rune boundaries.
4. Chat is published. Messages attach to this round and become visible NEXT round — decisions
   are simultaneous, so no cog can read another's line before deciding.
5. The module resolves and pays out.
6. Sanctions apply, ascending slot: the payer loses 1.0, the target loses 3.0.
7. The resource regrows / silts / ripens / spawns, latching any permanent death.
8. Scores and the public ledger are booked and the round is recorded.

## Scoring

    score_i = sum of every module payoff you were paid
              - 1.0 x sanctions you paid for
              - 3.0 x sanctions you received

Higher is better. Every module payoff is non-negative, so a score only goes below zero when a cog
punished a lot or was punished a lot. The league ranks by these per-episode scores.

The grader is a separate, social-planner view: group welfare (all scores plus whatever the
commons still holds) divided by the module's planner optimum. It is not what the league ranks by.

## How an episode ends

- `complete` — all rounds settled. A dead orchard or six dead patches do NOT end the episode:
  the remaining rounds are played out, and the post-collapse scavenging is data.
- `deadline` — the wall-clock guard fired between rounds. Rounds already settled are scored as
  they stand and the process exits 0.
- `no_players` — no cog connected inside the connect timeout. All-zero scores, exit 0.
