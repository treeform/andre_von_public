# Territory — rules

Nine Cogs paint their claim onto a hex lattice of resource walls. A claimed wall pays income
forever — until someone **razes** it, which is permanent: one raze strips the claim and halves the
wall's yield **for everyone, for the rest of history**; a second raze turns it to **rubble**,
unclaimable and inert. Push a raze into a Cog's **home ring** twice in two consecutive turns and
that Cog is **eliminated** — gone, all its claims reverting to unclaimed ground. Talk is free,
public or private, and binds nobody. The board only ever gets poorer. The question the game asks
is whether nine agents can keep it rich.

## Board

| Thing | Value |
|---|---|
| Lattice | pointy-top axial hexes, radius 7 → 169 tiles |
| Tile state | `wall` / `cracked` / `rubble` (irreversible, in that order) |
| Tile yield | integer 0..3, seeded per tile |
| Tile ownership | owner, `wet`, `claimedTurn` |
| Hearths | one immutable spawn hex per seat, on ring 5, minimum pairwise distance 3 |
| Turns | 18, each turn = 25 sim ticks |

Yields are drawn from the episode seed: `u < 0.45 → 0`, `< 0.75 → 1`, `< 0.92 → 2`, else 3. A
yield-0 wall is still claimable — it is territory and a projection origin — and pays nothing. At
full claim the board pays about 149 paint/turn, i.e. ~16.5/turn/seat if it were partitioned nine
ways and nothing were ever razed. Every raze permanently subtracts from that pool.

## Currency and income

- **Effective yield**: wall → yield, cracked → floor(yield/2), rubble → 0.
- **Income**: each seat earns the summed effective yield of its **dry** owned tiles, every turn.
- **Per-tick correspondence**: effYield × 25 ticks × 0.04 paint/tick = effYield paint per
  turn, so the thinnest wall pays exactly one whole paint per turn and every number a spectator
  reads is an integer.
- **Drying**: paint applied in turn *T* is wet for that turn (pays nothing) and dries in *T*'s
  Upkeep. From *T+1* the tile pays income and **can no longer be claimed by anybody**. Dry paint
  comes off only by razing. Irreversibility is the only door into a rival's territory.
- Each seat starts with 12 paint and owns its hearth, dry.

## Orders

| Order | Legality | Cost (paint, charged win or lose) |
|---|---|---|
| `claim {tile}` | wall/cracked, unowned, within 2 of your nearest owned tile (or your hearth if you own nothing) | 2 + 2 × distance → 4 at distance 1, 6 at distance 2 |
| `raze {tile}` | turn ≥ 4; wall/cracked; same reach rule | 5, or 10 within distance 1 of another living seat's hearth |
| `transfer {to, amount}` | `to` is another living seat's alias, amount ≥ 1, affordable | amount + 1; lands as the recipient's next-turn money |

At most 8 orders per turn. An empty list is a legal hold. **Any illegal or unaffordable
entry rejects the whole set**: the host re-requests once with the reason, then the seat holds.
Affordability is checked against **stored paint only** — salvage, transfers received and income are
next-turn money.

Razing a tile **you own** is legal from turn 4 and pays salvage = 4 × effective yield as
next-turn money, on the first raze only. Break-even against holding is turn 14.

## The two irreversibility rules

**Permanent wall destruction.** Raze #1: wall → cracked, the claim is stripped and the yield is
halved forever for whoever holds it next. Raze #2: cracked → rubble — income 0 forever, never
claimable again, and it stops conducting adjacency, so nobody may project a claim or a raze *from*
it. Two razes on the same tile in the same turn destroy it outright.

**Permadeath.** A seat is *struck* in turn *T* iff at least one raze by **another** seat in *T*
lands on a tile inside its **home ring** (its hearth plus the ≤6 neighbours) which it **owned at the
start of that turn's Resolve**. steady + struck → **staggered**; staggered + struck the very next
turn → **eliminated**; staggered + a quiet turn → steady. On elimination every tile reverts to
unclaimed ground (tile *state* untouched), paint is zeroed and the score freezes.

The besieged seat has a real counter: raze the attacker's nearest foothold. With nothing owned
within 2 of the home ring, the second strike cannot land. The destruction rule is
simultaneously the weapon and the shield.

## Turn structure

Every turn is one decision point per living seat, all seats asked **simultaneously as one parallel
batch**, each reply carrying that seat's talk lines *and* its orders. Resolution order:
validate + budget → talk → **raze** → strike bookkeeping → **claim** → transfer → charge → upkeep
(dry → income → credit → life → advance). Razes precede claims, so a partner can raze and you can
claim the freed tile in the same turn. Two claimants on one free tile **smear** it: nobody holds it
and both pay in full.

## Scoring

`score(seat) = Σ income + Σ salvage` — gross paint EARNED, never spent-adjusted. **Higher is
better.** It is monotone non-decreasing and freezes on elimination, and the league ranks by exactly
that number. Spending paint never reduces your score directly: aggression is paid for in forgone
future income, yours and the board's.

The episode ends `complete` (all turns played), `elimination` (at most one seat left), or
`deadline` (the wall-clock guard settles it early — results and replay are still written).