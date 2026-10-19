# Cogchemists rules

## The eight ingredients

| # | Ingredient | # | Ingredient |
|---|---|---|---|
| 0 | Nightcap | 4 | Copper Fern |
| 1 | Emberroot | 5 | Gravebloom |
| 2 | Fen Lily | 6 | Sunmoss |
| 3 | Widow's Salt | 7 | Rime Thistle |

Ingredient identity is never hidden: a card in a hand, on the bench or in a demonstration is always
named. What is hidden is what it *is*.

## Signatures and the hidden chemistry

A **signature** is a triple of signs over RED, GREEN and BLUE, written `R+G-B+` (ASCII
hyphen-minus). There are exactly 8. The episode's **chemistry** is a **bijection** ingredient ->
signature: a seeded permutation, so every signature is used exactly once and two ingredients never
share one. 8! = 40,320 chemistries are possible and one is drawn fresh from the episode seed. No
seat ever sees it; spectators see it only at the exhibition.

## The mixing rule

Mixing two ingredient cards `a` and `b` with signatures `sa` and `sb`:

1. Look at the aspects where `sa` and `sb` **disagree**.
2. If they disagree on **exactly one** aspect, the potion takes that aspect's **colour**, and its
   **sign** is the **product of the two aspects they agree on**: `+` when those two point the same
   way, `-` when they point opposite ways. The rule is symmetric, so mix order never matters.
3. If they disagree on two or three aspects - or on none, i.e. the same ingredient twice, which is
   legal - the potion is **MUD**.

| `sa` | `sb` | disagree on | agree on | potion |
|---|---|---|---|---|
| `R+G+B+` | `R+G+B-` | BLUE | `R+`,`G+` -> `+` | **BLUE+** |
| `R+G+B+` | `R+G-B+` | GREEN | `R+`,`B+` -> `+` | **GREEN+** |
| `R+G-B+` | `R-G-B+` | RED | `G-`,`B+` -> `-` | **RED-** |
| `R+G-B-` | `R-G-B-` | RED | `G-`,`B-` -> `+` | **RED+** |
| `R+G+B+` | `R-G-B-` | all three | - | **MUD** |

The whole outcome vocabulary is seven values: `RED+`, `RED-`, `GREEN+`, `GREEN-`, `BLUE+`, `BLUE-`,
`MUD`. Over the 28 unordered signature pairs each coloured potion is produced by exactly **2** pairs
and MUD by the other **16**, so a coloured result is a very strong constraint and MUD a weak one.

## Rounds, phases and resolution order

The episode is `rounds` rounds (default 6, 3..10). Each round has two simultaneous-decision phases,
**LAB** then **MARKET**. Both take exactly one action per seat and resolve in initiative order
`order[i] = (i + round) mod 4`, so the lead rotates.

1. **Round open.** The adventurer's demand for this round is drawn from the seed and published (one
   of the six coloured potions, never MUD). Royalties are paid: every standing seal earns its author
   +1 coin (+2 with the Printing Press). The initiative order is published.
2. **LAB opens.** Every seat's deduction grid is recomputed; all four decisions are taken
   simultaneously.
3. **LAB resolves** in initiative order, one action at a time.
4. **MARKET opens.** Grids are recomputed - a seat sees this round's lab consequences before it
   commits its public move.
5. **MARKET resolves** in the same order. This is where contention lives: an action that was legal
   when the phase opened may be **rejected** by an earlier seat in the same phase, is recorded
   `rejected:<reason>`, and degrades to `pass` (the actor still takes the +1 coin stipend).
6. Next round, or the exhibition.
7. **The exhibition.** Every standing seal is opened against the truth: a true theory pays its
   author **+5 reputation** and each endorser **+2**; a false one costs the author **-6** and each
   endorser **-3**. Seals already burned by a debunk are not re-scored - they settled at the burn.

## The LAB menu (private science; the cards you burn are public)

| action | cost | effect | who learns what |
|---|---|---|---|
| `forage` | 0 | Draw 2 cards (hand cap 6; a draw into a full hand is discarded and recorded). | The drawn cards are public. |
| `test_student a b` | -1 coin | Consume both cards (only `a` with the Magic Mortar). You learn the potion. | The two ingredients are public; the potion is private to you. |
| `test_self a b` | 0 | Consume both cards (Mortar: only `a`). You learn the potion and drink it: negative poisons you (-2 reputation), positive is a triumph (+1), MUD does nothing. | The ingredients and the potion's **sign class** are public; the colour stays private. |
| `transmute a` | 0 | Consume one card, receive +2 coin. | Public. |
| `pass` | 0 | The academy stipend, +1 coin. | Public. |

## The MARKET menu (public career)

| action | cost | effect |
|---|---|---|
| `sell a b` | 0 | Consume both cards and sell the potion to this round's adventurer. Hit: +6 coin, +1 reputation. Miss (MUD included): +2 coin, -1 reputation. The potion is public either way. |
| `publish a SIG` | -1 coin | Pin a wax seal claiming ingredient `a` has signature `SIG`. Immediate +2 reputation (+3 with the Printing Press). Legal only where no seal stands. Earns royalties from the next round open. |
| `endorse a` | -1 coin, paid to the author | Co-sign a rival's standing seal (never your own, never twice). At the exhibition +2 if true, -3 if false; -1 if it burns first. |
| `debunk a b` | -1 coin, consumes card `b` | A public demonstration against the standing seal on `a`. The academy supplies `a`, you supply `b`, and the real potion `p` is revealed publicly. The claim predicts `q`. If `p != q` the seal **BURNS**: author -4, you +3, each endorser -1, and `a` becomes publishable again. If `p == q` the attack **fails**: you -2, the author +1, and the seal stands. |
| `buy mortar` / `buy press` | -4 / -5 coin | Once each. **Magic Mortar**: your tests consume only the first card. **Printing Press**: publish pays +3 and royalties 2. |
| `pass` | 0 | +1 coin. |

Coin never goes negative: an action a seat cannot afford is simply not in its legal set, and `pass`
is always legal.

## What a seat sees

Visible: itself (alias, coin, reputation, score, artifacts, its exact hand, its own notes); the
round, phase, this round's demand and the initiative order; every rival's alias, coin, reputation,
score, artifacts and **hand count**; the whole board of seals with authors, endorsers and status;
the public record of every action with its publicly revealed outcome; its own private `mixFull`
results; its own deduction grid; and the exact list of `LEGAL MOVES` for this phase.

Hidden: the chemistry; any rival's private results (only the sign class leaks, and only from
`test_self`); any rival's hand contents, notes, grid or chemistries-left; the draw stream ahead;
future demands; and this phase's undelivered actions by other seats.

## The two endings

- `complete` - all rounds resolved and the exhibition held.
- `deadline` - the episode clock (60% of `episodeTimeoutSeconds`, checked only between phases)
  stopped play. The exhibition **still runs** on the board as it stands, so a truncated episode
  never pays unearned publication credit. `results.rounds` reports the rounds actually played.
