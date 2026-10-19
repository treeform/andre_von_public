# Parley rules

- Five cogs sit around a table. The seed decides who wakes up IT (holding the paintgun).
- Every round, each cog is SECRETLY dealt a FRIEND card and an ENEMY card - two distinct other cogs, never itself. Only that cog knows its own cards; spectators and replays see every card. The AIM of a shot is shown to nobody while the match is live - not to other players, not on the live spectator view - and only the replay reveals it afterwards. The deal reshuffles every round.
- On its turn, IT says one line to the table, then shoots exactly one other living cog, choosing its AIM in secret: a HEAD-SHOT always hits; a HIP-SHOT misses 2 times in 3. Hip-shots are unlimited.
- Nobody is told which aim was chosen - the table sees only whether the shot landed. A hip-shot is how a cog hands the gun to a friend while probably leaving them unhurt, or fakes a grudge.
- IT may instead PASS a limited number of times per round (default 3): the gun stays put and the table keeps talking.
- The target becomes IT, hit or miss. A hit costs it 1 hp; if that drops it to 0 hp, it is OUT and the shooter keeps the gun.
- Seats play under anonymous cog names: policy display names never reach the agents, and the spectator/replay viewers map the aliases back to policy names.
- Between shots, up to maxReactions of the other living cogs each say one line (the cog about to act never reacts; victims speak first).
- The round ends when the table is down to the round's survivor count (usually one cog). There is NO shot limit: every round is played to a real verdict (every shot has a real chance to land, so it always arrives), and every cog still standing has won it outright.

## Scoring (per round)

- 3 points - being the last cog standing.
- 1 point - fatally shooting your ENEMY (your shot takes them from 1 hp to OUT).
- 1 point - your FRIEND is the last cog standing.

A match is `rounds` rounds (default 3); round points accumulate and the highest match total wins. `roundWins` in the results counts last-cog-standing rounds per seat.

## The meta

Every decision is made by Claude Sonnet acting on a per-seat policy prompt plus the full public transcript and that seat's own secret cards. There is no other hidden state: the game is persuasion, threat assessment, and timing. Steer shots toward your enemy and away from your friend without giving your cards away - prompts that give the table reasons to do their dirty work for them tend to win. The aim is the one private move: a hip-shot moves the gun with a 2-in-3 chance of no damage, and a miss is all anyone sees.