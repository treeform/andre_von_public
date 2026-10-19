# Babel rules

- Four seats. Every round the seats split into two pairs, each with a SPEAKER and a LISTENER. Round r (0-based) uses the matching M[r mod 3] of {(0,1),(2,3)}, {(0,2),(1,3)}, {(0,3),(1,2)}; within a pair the first seat speaks when (r div 3) mod 2 == 0, otherwise the second. Every ordered speaker->listener relation occurs once per six rounds.
- A scene is a shape (circle, square, triangle, star), a colour (red, blue, green, yellow), and a count (1-4); scene id = shape*16 + colour*4 + (count-1).
- Per pair per round the seed draws a target and a lineup of four scenes: the target, a near miss (shares two attributes), a partial (shares one), and a clear miss (shares none), shuffled and labelled A-D. The speaker sees only the target; the listener sees the message and the lineup.
- The message is 1 to 8 tokens from a 16-token alphabet. Each seat sees the tokens under its own seeded symbols in its own order; glyph identity never survives the channel, only token identity does. Nothing else crosses between seats.
- After the pick both pair members learn the target, the pick, and the verdict. Each seat's prompt carries its own history (never the other pair's) and its latest private notes (up to 600 characters, overwritten when a reply carries notes, kept when it does not). Notes are recorded in the event log for spectators.
- The episode runs `rounds` rounds (default 24, capped to 60 by the model-call budget); the episode clock may end it early after the current round.

## Scoring

A round-pair succeeds when the listener picks the target. A seat's `correct` is its successes in the rounds it was in (either role); `score = correct / rounds played`. Results also report `asSpeaker` and `asListener` successes. Fully cooperative; the league ranks seats by mean episode score.

## The meta

Every decision is made by Claude acting on a per-seat policy prompt plus the seat's alphabet, notes, history, and target (speaker) or message and lineup (listener). Prompts that invent a consistent compositional code (one glyph per attribute value), keep a per-partner dictionary in their notes, and prefer the near-miss reading when unsure tend to score; the built-in scripted baseline (fixed three-token code as speaker, count-based association decoder as listener) fills seats without prompts, is a fieldable policy in its own right, and is the consistent-convention partner a prompt has to adapt to.