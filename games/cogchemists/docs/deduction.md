# Deduction, and who leaks what

## A fact

Every fact is a hard constraint on the chemistry. There are three kinds:

| fact | meaning | who holds it |
|---|---|---|
| `mixFull(a, b, potion)` | mixing `a` and `b` gives exactly this potion | private to the tester; **public** for `sell` and `debunk` results |
| `mixSign(a, b, class)` | mixing `a` and `b` gives a potion of this class (`positive` / `negative` / `mud`) | **public**, from every `test_self` |
| `notSig(x, v)` | ingredient `x` is **not** signature `v` | **public**, minted when a seal burns |

Seat `s` knows every public fact, plus its own private `mixFull` facts, plus the standing rule that
the chemistry is a bijection.

## The grid

A seat's grid is computed by **exact enumeration of all 40,320 bijections**, keeping those
consistent with every fact it knows:

- `grid[x]` is the set of signatures `v` such that some consistent bijection maps `x -> v`;
- `chemistries` is how many bijections survive.

There is no heuristic propagation, so the grid never over- or under-claims. An ingredient whose set
is a **singleton** is **SOLVED** - that is when a seat may publish without gambling. The grid is
recomputed once per seat per phase open, and the wasm replay viewer runs the same code, which is why
spectators can watch all four grids narrow like a hole-cam instead of taking anybody's word for it.

The prompt receives the grid as a table, not as prose:

```
YOUR DEDUCTION GRID (12 chemistries still possible)
Nightcap      SOLVED  R+G-B+
Emberroot     2       R-G+B+ | R-G+B-
Fen Lily      3       R+G+B+ | R+G+B- | R-G-B+
```

## The information economics

- **forage** leaks the two cards you drew, and nothing else.
- **test_student** leaks the two ingredients you burned. The potion is yours alone. It costs a coin
  precisely because the silence is worth paying for.
- **test_self** leaks the two ingredients *and* the sign class - everybody sees you glow or retch -
  but the colour stays yours. It is free because you are the one who suffers.
- **sell** leaks the whole potion. Selling is how you make coin and how you hand the table a fact.
- **debunk** leaks the whole potion of `x` with `y` to everyone, whether the attack works or not, so
  every demonstration is a free public experiment paid for by the attacker.
- **publish** leaks what you claim, which need not be what you know.
- A **burn** mints `notSig(x, claim)` for everyone: a false seal, once exposed, narrows every seat's
  grid.

Because a coloured potion is produced by only 2 of the 28 signature pairs, a coloured result cuts
the hypothesis space by roughly fourteen; MUD, produced by 16 of 28, barely moves it. Choosing which
pair to burn a phase on is the whole science: prefer the pair whose worst-case outcome would leave
the fewest chemistries standing.

## Attacking well

A false seal burns **only** when the attacker brings a reagent that exposes it. `p == q` happens
often against a wrong claim whose error this particular pairing cannot see - the attack fails, the
attacker pays 2 reputation, and the fraud is *strengthened* by a recorded vindication. A safe attack
is one where every chemistry still consistent with the attacker's own grid predicts a different
potion from the seal's claim. Attacking well therefore requires knowing more than the author.
