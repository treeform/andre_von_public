# Rumor rules

## Seats and roles

- **Ten seats.** `num_agents` is 10 in every variant and in the certification fixture.
- Two or three seats are **saboteurs**, drawn from the seed (a fair coin) unless the config
  pins `saboteurs`; the other seven or eight are **honest**. Role assignment is a seeded
  permutation - no policy can choose its role, and the same policy plays honest in one
  episode and saboteur in the next.
- Seats play under **anonymous cog aliases** (Sprocket, Gizmo, Ratchet, Widget, Bolt, Piston,
  Flywheel, Rivet, Tinker, Gasket). Policy display names are spectator-side only; results
  attribute by policy name.

## The scenario, drawn once from the seed

Everything random is drawn at episode start from one rng stream, in this fixed order -
proposition, truth, saboteur count, roles, topology family, node order, edges, clues - so a
replay re-derives the whole scenario from the seed alone. A pinned `topology` or `saboteurs`
overrides its draw *after* the draw happens, so pinning never shifts the stream.

1. **Proposition** - one of eight, each a question and two mutually exclusive one-word
   answers (`optionA` / `optionB`), e.g. "The relay tower on Ash Hill is BROKEN or SOUND?".
2. **Truth** - `A` or `B`, a fair coin. Nobody sees it before the tally, not even spectators.
3. **Saboteurs** - 2 or 3.
4. **Roles** - a shuffle; the first `saboteurs` seats in that order are the saboteurs.
   Placement ignores degree: a saboteur on a bridge is luck.
5. **Topology family** - uniform over four:
   - `ring` - the 10-cycle plus 3 random chords. 13 edges, degrees 2-5.
   - `smallworld` - the 10-cycle plus every 2-hop pair (4-regular), then 2 rewires that are
     rejected if they disconnect the graph. 20 edges.
   - `clusters` - two groups of five, each a 5-cycle plus one chord, joined by **exactly one
     bridge**: everything that crosses passes through one cog. 13 edges.
   - `hub` - three hubs in a triangle; each of the other seven attaches to one or two of
     them. 10-17 edges.
   Every graph is checked connected with no isolated seat before play starts.
6. **Clues** - each seat's clue equals the truth with probability 0.60, drawn i.i.d., and the
   whole vector is redrawn until the ten clues split **6-4, 7-3 or 8-2 in favour of the
   truth**. That makes one public rule true and tellable: *the ten clues together always
   point at the truth*. A seat's own clue is right about 67.6% of the time as a result.

## The turn order

An episode is `rounds` talk rounds (default 5, 3..6) followed by exactly one sealed ballot.
Decisions inside a turn are **simultaneous**: all ten prompts go out in one parallel batch and
nothing a seat sends in round *r* is visible to anyone before round *r+1*.

For each talk round:

1. Last round's messages are delivered along the graph: seat *j*'s inbox holds one entry per
   **neighbour** that spoke, and nothing else.
2. All ten seats decide at once. Each reply carries a public `claim` (`A`, `B` or `none`), a
   `confidence` (0-100), a private `belief` (0-100 = the chance the answer is option A), a
   `message` of at most **240 characters** (an empty message is legal - silence is a move) and
   optional private `notes` of at most 600 characters, fed back verbatim next round.
3. The replies are applied in ascending seat order, which cannot matter because nothing this
   round is visible to anyone else this round.

Then the **ballot**: all ten seats vote at once. Each reply carries a `vote` (required, `A` or
`B`), an optional final `belief` and a one-line `reason` (200 characters). **Votes are sealed** -
they never enter a prompt, never reach a player frame, and appear in the spectator snapshot as
ten nulls until the tally runs.

Then the **tally**: the honest seats' correct votes are counted, every seat is scored, and the
table is unmasked - every vote, every clue, every role and the truth appear for the first time.

## What each seat can see

Its alias, its own role, the round number, the proposition, its own clue, the public
reliability facts, the constants (10 cogs, 2 or 3 saboteurs, the edge count, its own degree),
its **neighbours' aliases**, its inbox, its own send history and its private notes. A saboteur
additionally sees its fellow saboteurs' aliases - but has no private channel: it talks along
the same links as everyone else.

Nobody sees, before the tally: the truth, another seat's clue or belief, who is honest and who
is not, any message between two non-neighbours, any vote, any score, the graph beyond its own
neighbourhood, or the seed. Spectators see the clues and the belief meters from the first
frame - but not the roles and not the truth.

## Caps and endings

Every recorded string is truncated on a **rune** boundary: messages 240, vote reasons 200,
notes 600, a delivered policy prompt 4000. `results.reason` has exactly two values:

- `complete` - the ballot resolved with all ten votes in.
- `deadline` - the play deadline (60% of `episodeTimeoutSeconds`) arrived first. The ballot is
  forced at once: seats that voted keep their votes, the rest are given the scripted `gossip`
  vote, and the tally, reveal and scores are produced normally. A short honest episode always
  beats a long one that never lands.
