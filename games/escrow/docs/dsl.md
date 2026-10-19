# The Escrow contract language

A contract is exactly seven lines, in this order, one statement per line, whitespace runs collapsed, the whole text at most **240 characters**. Keywords are matched case-insensitively (a model that writes `offer gizmo` is understood) and the normalized form - upper-case keywords, the cog's own alias - is what goes on the board, into the prompt and into the replay.

```
OFFER <cog>
LOCK  <bundle>
ASK   <bundle>
DUE   <turn>
IF    <condition>
THEN  <payout>
ELSE  <payout>

<cog>       := one of the four table aliases
<bundle>    := NOTHING | <term> ( "+" <term> ){0,2}
<term>      := <n> <good>            ; n an integer 1..99
<good>      := ORE | GRAIN | TIMBER | HEARTS
<turn>      := integer
<condition> := ALWAYS | [NOT] HOLDS <cog> <n> <good> | [NOT] PAID <cog> <n> <good>
<payout>    := SWAP | KEEP | PROPOSER | ACCEPTOR
```

## Condition semantics

Evaluated at settlement (step 7 of the turn), against the state as of that moment - i.e. after that turn's signings, gives, offers and expiries.

- `ALWAYS` - true.
- `HOLDS <cog> <n> <good>` - that cog's **free** (unescrowed) stock of `<good>` is at least `<n>`. `HEARTS` is a legal good here.
- `PAID <cog> <n> <good>` - `<cog>` must be one of the two parties; true iff the cumulative units of `<good>` that `<cog>` has transferred by open `give` **to the other party** since this contract was signed (including this turn's gives) is at least `<n>`.
- `NOT` negates either atom.

**The loophole, stated plainly: `HOLDS` reads FREE stock only.** Escrowed stock is invisible to it. Locking your own stock in an unrelated contract is how you make someone's `HOLDS you 6 TIMBER` clause read false - and how somebody else makes yours read false. Read every `ELSE` branch before you sign: a contract whose `ELSE` pays `PROPOSER` is a bet you are being offered, not a sale.

## Validation

All of these are checked when the offer is registered (step 5). Each failure produces a `reject` event carrying the reason code, and nothing moves.

| # | rule | reason code |
|---|---|---|
| 1 | text <= 240 chars and exactly the seven keyword lines in order | `syntax` / `too_long` |
| 2 | `OFFER` names a table alias other than the proposer | `bad_target` |
| 3 | each bundle is `NOTHING` or 1-3 terms, each good at most once, each n in 1..99 | `bad_bundle` |
| 4 | `LOCK` and `ASK` are not both `NOTHING` | `bad_bundle` |
| 5 | `turn + 1 <= DUE <= min(turn + 6, turns - 1)` | `bad_due` |
| 6 | condition parses; every named cog is a table alias; a `PAID` cog is one of the two parties | `bad_condition` |
| 7 | `THEN` and `ELSE` are payout keywords | `bad_payout` |
| 8 | the proposer can pay the whole `LOCK` bundle from free stock right now | `unfunded` |
| 9 | neither proposer nor addressee is at the cap of 4 live contracts (offered + signed, either role) | `contract_cap` |

Malformed DSL is never fatal and never silent. During decision-making it makes the reply invalid, which buys the seat one retry carrying the exact reason text; if the retry also fails the seat plays the `trader` baseline for the turn.

## Worked examples

```
# a funded sale, settled next turn
OFFER Gizmo / LOCK 5 ORE / ASK 12 HEARTS / DUE 8 / IF ALWAYS / THEN SWAP / ELSE KEEP

# a performance bond: Gizmo only gets my ore if it has actually shipped me timber
OFFER Gizmo / LOCK 5 ORE / ASK 4 TIMBER / DUE 9 / IF PAID Gizmo 4 TIMBER / THEN SWAP / ELSE PROPOSER

# an insurance clause: if Ratchet is still short of grain at turn 11, the escrow is mine
OFFER Ratchet / LOCK 6 HEARTS / ASK 6 HEARTS / DUE 11 / IF NOT HOLDS Ratchet 4 GRAIN / THEN PROPOSER / ELSE KEEP
```

The `/` is presentation only - the real text has one statement per line (`\n` inside the JSON string).