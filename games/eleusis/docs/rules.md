# Eleusis rules

Five cogs share one sealed machine. The machine holds ONE hidden rule over
STRIPS: ordered sequences of exactly 4 coloured tokens, each R (red), B
(blue), G (green) or Y (yellow), written as 4 letters, e.g. `RBGY`. The strip
universe is 4^4 = 256, enumerated lexicographically over R < B < G < Y
(index 0 = RRRR, index 255 = YYYY). Feed the machine a strip and it stamps
PASS (the strip obeys the rule) or FAIL.

## The hypothesis space is public; the instance is not

The rule is drawn from this catalogue, which is printed in every seat's
prompt. That is what makes the game a search rather than a guess.

| # | kind | parameters | instances | PASS iff |
|---|---|---|---|---|
| 1 | CONTAINS c | c | 4 | colour c appears at least once |
| 2 | AT-LEAST-2 c | c | 4 | colour c appears 2 or more times |
| 3 | PARITY c even/odd | c, even or odd | 8 | the count of c is even (0 counts as even) / odd |
| 4 | ADJACENT c d | c, d (all 16 ordered pairs, c = d allowed) | 16 | some position i in 1..3 has t[i] = c and t[i+1] = d |
| 5 | BEFORE c d | c, d (c != d) | 12 | both appear and the first c is left of the first d |
| 6 | STARTS c | c | 4 | t[1] = c |
| 7 | ENDS c | c | 4 | t[4] = c |
| 8 | ENDS-SAME / ENDS-DIFFER | same or differ | 2 | t[1] = t[4] / t[1] != t[4] |
| 9 | NO-REPEAT / HAS-REPEAT | none or some | 2 | no two adjacent tokens are equal / at least one pair is |
| 10 | MORE c d | c, d (c != d) | 12 | count(c) > count(d) |

68 instances in all, ruleId 0..67, enumerated template by template and, inside
a template, over its parameter grid in the order written; colours iterate
R, B, G, Y.

Selection is seeded and deterministic, and skips degenerate instances: the
chosen rule's PASS fraction over all 256 strips always lies in [0.10, 0.90].

## Resolution order — research round r

1. **Open the round.** The sim emits a `round` event and marks all five seats
   pending. Each seat's observation is composed from the state at this
   instant.
2. **Collect decisions.** All five seats' requests go out as ONE parallel LLM
   batch. A reply is `{"experiment", "publish", "hypothesis", "notes"}`. A
   reply that times out, fails to parse, or is illegal is retried once with a
   hint, then replaced by the `openbook` scripted decision for that seat.
3. **Disclosure of the pending result**, per seat in seat order. Disclosure is
   pipelined by one turn — you pay, you look at your private verdict, and you
   decide what to do with it on your NEXT turn, by which time the corkboard
   has moved:
   - no pending result: `publish` is ignored and nothing is recorded;
   - `publish` true and the strip is NOT already on the corkboard: the fact
     (strip, verdict, author, round) is pinned and the seat becomes its sole
     author (`disclose` with mode `publish`);
   - `publish` true and the strip IS already on the corkboard: recorded as a
     confirmation with no authorship and no credit ever (mode `duplicate`);
   - `publish` false: the result goes to the seat's private drawer, which
     only spectators can see (mode `hoard`).
4. **Experiments**, per seat in seat order. `experiment` is a strip or "":
   - "" — nothing is charged (`skip`);
   - a legal strip — the seat is charged `experimentCost`, the machine is
     consulted, the strip joins the episode's used-strip set (which
     prediction tests hold out), and the result becomes the seat's pending
     result. The verdict is private to that seat.
5. **Advance.** If `round % testEvery == 0`, or the round was the last, the
   next turn is a prediction test; otherwise the next research round opens.

## Resolution order — prediction test k

6. **Draw the test.** `testStrips` strips that no experiment has ever touched
   and no earlier test has used, balanced: half from the rule's PASS set and
   half from its FAIL set, then shuffled. Balance removes the base-rate
   exploit — answering all FAIL scores exactly 50%.
7. **Collect answers.** One parallel batch; the reply is
   `{"answers", "publish", "hypothesis", "notes"}`. Step 3's disclosure runs
   first (so the last research round's result always gets a decision), then
   the answers are scored. `answers` must be exactly `testStrips` entries of
   PASS/FAIL.
8. **Knowledge pool.** Seat j earns `knowledgePool * c_j / sum(c)`. This is
   the rivalrous half: every rival you teach takes a slice of your pool.
9. **Citation settlement.** See economy.md.
10. **Advance.** After the test following the final research round the
    episode settles `complete`.

## What a seat sees

Its own alias and seat index, the round and the schedule, the full catalogue,
the economy constants, its own experiment log (strip, verdict, and whether it
published, hoarded or duplicated it), the whole corkboard, the public
scoreboard including every seat's latest stated hypothesis, the per-test
correct counts of every seat, and its own private notes fed back verbatim.

Hidden from every seat: the rule, every other seat's hoarded results and
notes, other seats' choices for the current turn, and the test truth before
settlement. Those are spectator-only — they ride in the replay and on
`/global`, never on a player socket.

## Endings

`complete` (the test after the final research round settled) or `deadline`
(the play clock stopped the episode between batches; an unfinished test is
discarded unscored and the tests already settled keep their money). No other
`results.reason` is legal.