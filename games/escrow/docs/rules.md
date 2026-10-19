# Escrow rules

## The floor

Four seats, four profiles, dealt as a seeded permutation so no slot is structurally stuck with one role. Seats trade under anonymous cog aliases (Sprocket, Gizmo, Ratchet, Widget, ...) drawn from the same seed; policy display names never enter a prompt.

| Profile | produces per turn (ore/grain/timber) | commission (consumes -> pays) |
|---|---|---|
| Mason | 6 / 1 / 1 | 2 GRAIN + 2 TIMBER -> 10 hearts |
| Farmer | 1 / 6 / 1 | 2 TIMBER + 2 ORE -> 10 hearts |
| Forester | 1 / 1 / 6 | 2 ORE + 2 GRAIN -> 10 hearts |
| Factor | 2 / 2 / 2 | 2 ORE + 2 GRAIN + 2 TIMBER -> 12 hearts |

Production and commission-filling are automatic - no seat decides them. A seat may fill at most 2 copies of its commission per turn, greedily, from free stock. **That is the only source of new hearts in the game**; every other heart movement is a transfer between seats and is zero-sum. Every seat starts turn 0 (before the first production) with 3 ore, 3 grain, 3 timber and 20 hearts.

Comparative advantage falls straight out of the table: under autarky a Mason fills half a commission a turn (5 hearts/turn) while a well-traded Mason fills two (20 hearts/turn, minus what it paid). The implied price band is 2.0-2.5 hearts per unit, which is what makes pricing a clause a real skill rather than a guess.

## The turn

Decisions within a turn are **simultaneous**: every seat sees the same public floor and answers before anyone's answer is applied. A decision is `{give (<=2), offer (<=1), sign (<=2), say, notes}`. Turn `t` resolves in exactly this order:

1. **Production.** Each seat's profile yield is added to its free stock.
2. **Observation and decision.** The post-production floor is snapshotted and every seat's decision is obtained - one parallel LLM batch, or the scripted baseline.
3. **Signings**, in seat order, then reply order. `SIGN Cn` is legal iff `Cn` is still `offered`, was posted on turn `t-1`, is addressed to this seat, and this seat can pay the whole `ASK` bundle out of free stock. On success the ASK moves into escrow and the contract becomes `signed`; on failure nothing moves and the contract stays `offered` (and expires at step 6).
4. **Gives**, in seat order, then reply order. A give moves 1..99 units of one good (or hearts) from the giver's free stock to another seat's free stock, immediately and with no strings. Illegal or unaffordable gives are rejected and logged; the rest of the seat's decision still applies.
5. **Offer registration**, in seat order. The DSL is parsed and validated (see dsl.md); on success the contract is created and **the proposer's LOCK bundle moves into escrow immediately** - an offer on the board is always funded.
6. **Expiry.** Every contract still `offered` that was posted on turn `t-1` expires and its proposer's escrow is returned. An offer therefore lives exactly one turn: posted on `t`, signable only on `t+1`.
7. **Settlement.** Every `signed` contract with `DUE == t`, in ascending contract id: the condition is evaluated against the state as it now stands, the THEN branch is taken if true and the ELSE branch if false, and the two escrows are paid out per the branch.
8. **Commissions.** Each seat fills up to 2 copies of its commission from free stock.
9. **Tally.** The turn record is appended and the turn advances.

## Payouts - the only four

| Payout | effect |
|---|---|
| `SWAP` | proposer's escrow -> acceptor; acceptor's escrow -> proposer |
| `KEEP` | each side's escrow returns to its owner |
| `PROPOSER` | both escrows -> proposer |
| `ACCEPTOR` | both escrows -> acceptor |

**This is what "breach is impossible" means mechanically.** A contract never creates an obligation to hand something over later; it is pre-funded at signature. Settlement only redistributes what is already locked, so non-performance cannot be a refusal to pay - it is simply the ELSE branch firing and the escrow forfeiting. Escrowed goods and hearts are visible on the board but unusable: they cannot be given away, cannot fill a commission, and do not count toward a HOLDS condition.

## Scoring

`score(seat) = free hearts after the horizon closure` - an integer, higher is better. When the episode ends, for either reason, every contract still `offered` is expired (proposer refunded) and every contract still `signed` is closed as `KEEP`, so nothing is stranded. Leftover goods are worth **zero** hearts, so the last turns are a genuine scramble to convert. The league ranks by mean episode score. Results also report per seat: `hearts`, `fills`, `signed`, `forfeits` and `profiles`, plus the episode's `heartsMinted`.

End conditions: `complete` (all `turns` turns resolved) or `deadline` (the episode clock stopped play between turns; scores use the turns actually played, after the same horizon closure). Those are the only two values of `reason`.

## What is public

The floor is **open outcry**. Every seat sees, every turn: every cog's alias, profile, production vector, commission bundle and payout, free stock of each good, free hearts and escrowed totals; every live contract on the escrow board with its LOCK and ASK bundles, DUE turn, condition and both branches; contracts settled or expired in the last 3 turns with their outcomes; the last 6 turns of public events; and the message every seat sent last turn (`say` is public - all three others read it). **The only hidden information is the other seats' private notes.** There is deliberately no hidden inventory and no hidden price: this game is about commitment and clause-drafting, not concealment, and a public floor is what lets a spectator judge whether a contract was a good deal.

## The meta

Every decision is made by Claude acting on a per-seat policy prompt. Prompts that count their shortfall against two commission fills, price at 2-2.5 hearts a unit, put a PAID or HOLDS condition on anything they cannot verify at signature, and read the other side's ELSE branch first tend to score. The built-in `trader` baseline barters one-for-one at a flat house price and is the partner a prompt has to beat; the `hoarder` baseline never trades at all and is the autarky floor that makes "what is a contract worth?" measurable.