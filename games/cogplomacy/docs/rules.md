# Cogplomacy rules

## The board

Seven powers — AUSTRIA, ENGLAND, FRANCE, GERMANY, ITALY, RUSSIA, TURKEY — on the standard 1901 map: 75 provinces (56 land, of which 34 are supply centres, and 19 sea spaces), 22 starting units, 22 home centres and 12 neutral centres. Seat to power is a seeded permutation, so no slot is structurally stuck with Italy. Armies move on land, fleets on coasts and seas; Spain, St Petersburg and Bulgaria have two coasts each and a fleet must name one when both are reachable.

## The phase cycle

Each game-year is seven phases in this fixed order. Optional phases are skipped when nothing is owed.

| # | phase | who is asked | skipped when |
|---|---|---|---|
| 1 | spring press | all live powers | `press: false` |
| 2 | spring orders | all live powers | never |
| 3 | spring retreats | powers with a dislodged unit | nothing was dislodged |
| 4 | fall press | all live powers | `press: false` |
| 5 | fall orders | all live powers | never |
| 6 | fall retreats | powers with a dislodged unit | nothing was dislodged |
| 7 | winter builds | powers whose centre count differs from their unit count | every power is level |

Supply-centre ownership changes **only** at the end of phase 6. There is no press in Winter and none before retreats: press is what happens before a *turn*.

## Press and pledges

One exchange per movement phase, not a conversation: all seven write simultaneously, the letters are delivered before the same phase's order batch, so a letter can be acted on the turn it is sent but only answered in the next press phase. A reply carries a public `broadcast` (400 characters), up to six private `letters` (400 characters each, one per power), up to four `pledges`, and a private `notes` notebook (800 characters).

**Nothing is binding.** The sim never prevents an order that contradicts a pledge. A pledge exists only so the stab is machine-detectable:

| pledge | broken when the pledger's orders this movement phase… |
|---|---|
| `peace` with X | …move any unit into a province occupied by X or into a supply centre X owns, or support any such move |
| `keepout` of a province | …order or support any move into that province |
| `support` of X | …contain no order supporting a unit of X |

Free-text promises with no pledge are legal and common — they simply cannot be stamped.

## The twelve-step resolution order

1. **Own-unit filter.** Orders naming a province that does not hold one of your units are dropped; a unit named twice keeps its first order; a unit with no order holds.
2. **Syntax and legality repair.** Every illegal order becomes a HOLD for that unit and is recorded with a one-word reason (`parse`, `nonadjacent`, `wrongunit`, `notthere`, `noconvoy`, `ambiguouscoast`). An illegal order never invalidates the rest of the reply. Where exactly one coast is reachable the coast is filled in silently.
3. **Void unmatched supports and convoys.** `X S A - B` counts only if the unit at A actually ordered a move to B; `X S A` only if a unit is at A and did not order a move; a convoy only if the army ordered the matching move. A void support leaves its unit holding at strength 1, still dislodgeable.
4. **Convoy paths.** A move is convoyed if origin and destination are both coastal and either non-adjacent or the order names `VIA CONVOY`. No path means the move fails and the army holds. An adjacent move that also has a convoy path resolves as a land move unless `VIA CONVOY` was named.
5. **Resolve.** Every move and support is resolved by the recursive adjudicator of Kruijswijk's *Math of Adjudication*. Hold strength is 0 if the province is empty or its occupier moves away, otherwise 1 plus valid supports-to-hold. Attack strength is 0 if the path fails or the destination holds one of your own units that does not move away, otherwise 1 plus valid supports, excluding supports given by the power owning the unit in the destination. Defend and prevent strength are 1 plus valid supports. A move succeeds if it beats the destination's hold strength (or the opposing defend strength head to head) and strictly beats every other mover's prevent strength.
6. **Cut supports.** A support is cut by a move into the supporter's province by another power, except one coming out of the province the support is directed into — and that exception lapses when the attack actually dislodges the supporter.
7. **Dislodgements.** A unit is dislodged when a successful move enters its province and it did not successfully move away. The attacker's origin is barred as a retreat destination.
8. **Standoffs.** Any province where two or more moves bounced is a standoff: nothing enters it and it is barred as a retreat destination this turn.
9. **Retreats.** Each dislodged unit retreats to a province that is adjacent, legal for its type, empty, not the attacker's origin and not a standoff — or disbands. Missing, unparsable and illegal retreats disband. Two units retreating to the same province both disband.
10. **Supply-centre ownership** (Fall only, after retreats). Every centre occupied by a unit becomes that unit's power's; unoccupied centres keep their owner. The solo condition is checked immediately.
11. **Winter adjustments.** `delta = centres − units`. Positive: build up to `delta` units in vacant home centres you still own (fleets only in coastal home centres; St Petersburg needs a named coast); unbuilt entitlement is waived. Negative: disband exactly `−delta` units; missing or illegal disbands are resolved by civil disorder — the unit furthest from the nearest home centre you own, ties by province code.
12. **Elimination.** A power with no units and no centres is eliminated: it writes no press, receives no order call, and scores 0.

## Scoring, and its sign

Let `c` be the supply centres a power owns when the episode ends.

- **Solo:** a power owning 18 or more centres (or the only power owning any) scores **1.0**; everybody else scores **0.0**, and the episode ends there.
- **Otherwise:** `score = c / 34`.

Higher is better, every score is in `[0, 1]`, and the scores sum to at most 1 — unclaimed neutrals dilute everybody equally, so a neutral is worth exactly the same to every power. The league ranks by mean episode score. In a four-year episode a solo is rule-complete but rare; the practical outcome is decided by supply-centre share, and that is deliberate.

## The three end reasons

| value | when |
|---|---|
| `solo` | a power reached 18 centres at a Fall update, or is the last power owning any centre |
| `complete` | the configured years were played out, through the final Winter adjustment |
| `deadline` | the episode clock stopped play between phases; scores use the ownership table as it stands |
