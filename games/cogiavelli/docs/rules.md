# Cogiavelli rules

## The calendar

An episode plays `years` years starting at 1499 (default 4, minimum 1, maximum 10). Each year is
three seasons - Spring, Summer, Autumn - and then Winter. Every season is one whole turn: a press
window, a simultaneous orders-and-expenditure submission, and a resolution. Winter takes no decision
from anybody: it executes the plans already written on the Autumn expenditure sheet.

## The resolution order, numbered and complete

1. FAMINE DRAW (Spring only). The server draws 2 distinct land provinces and announces them to
   everyone at once. A famine province is marked for the whole year.
2. PRESS WINDOW. All six powers write simultaneously, in one batch: one public broadcast, up to five
   private letters (at most one per other power), up to four pledges, and private notes. Nothing said
   here binds anything. A power paralysed by an assassination last season writes nothing this window;
   letters addressed to it are still delivered. Skipped entirely when `press` is false.
3. ORDERS AND EXPENDITURE. All six powers write simultaneously, in one batch: one order per unit they
   own, a `spend` sheet of up to 6 entries, and (Autumn only) a `builds` list of up to 6 entries that
   Winter will execute. Nobody sees anybody else's submission before it resolves.
4. PAYMENT. For each power in power-index order, its spend entries are validated IN THE ORDER IT
   LISTED THEM against its live treasury: an entry it cannot afford is dropped (`insufficient`); one
   naming a nonexistent unit or power is dropped (`notarget`); a bribe on one's own unit or an
   assassination on oneself is dropped (`illegal`). Every surviving entry is paid immediately - the
   ducats leave the vault whether or not the entry works. A gift credits the recipient at this moment
   and is irrevocable.
5. ASSASSINATION. For each surviving attempt, in power-index order of the payer, the server draws two
   dice: roll = 6*(d1-1)+d2, uniform on 1..36. The attempt succeeds iff roll <= amount, where amount
   is the ducats paid, clamped to 6..30 - so 18 ducats is an even chance and 30 is the 30/36 ceiling.
   On success the target is PARALYSED: every one of its units holds this season, and it writes no
   press next season. Its treasury is untouched.
6. BRIBES. All bribes resolve at once against the amounts paid in step 4. For a targeted unit U owned
   by P, let `defence` be the total defend ducats P paid on U this season. A bribe of `amount` takes
   effect iff amount >= Cost + defence, where Cost is 9 to disband and 15 to buy. If two or more
   bribes on the same unit qualify, the strictly largest wins; an exact tie means ALL of them fail and
   none of the money comes back. A bought unit changes sides where it stands and is forced to hold.
7. ORDER REPAIR. Drop orders naming a unit the power no longer owns after step 6; where one unit is
   ordered twice keep the first; replace every order of a paralysed power with a hold; give any
   unordered unit a hold. Then check legality - a fleet ordered inland, an army into a sea, a move to
   a non-adjacent area with no possible convoy path, a support whose destination is not adjacent to
   the supporter, a support or convoy naming a unit that is not there, an army ordering a convoy, a
   convoying fleet not at sea. EVERY ILLEGAL ORDER BECOMES A HOLD, with a one-word reason (parse,
   nonadjacent, wrongunit, notthere, noconvoy, notowned). An illegal order never invalidates the rest
   of a reply.
8. MOVEMENT ADJUDICATION. The Diplomacy core, unchanged: void unmatched supports and convoys; find
   convoy paths; resolve with the four standard strengths (hold, attack, defend, prevent) by the
   recursive resolver of Kruijswijk's *The Math of Adjudication*; cut supports; two backup rules only
   - circular movement and the Szykman rule for convoy paradoxes. Self-dislodgement is banned, and no
   power may support a foreign attack that dislodges its own unit.
9. RETREATS, decided by rule and not by a decision call. Each dislodged unit retreats to the legal
   destination (adjacent on its own graph, empty after movement, not the attacker's origin, not a
   standoff province) with the smallest hop distance to the nearest city its owner holds, ties broken
   by ascending province code; if there is none it disbands. Two dislodged units contesting one
   province: the lower province code takes it, the other re-picks or disbands.
10. CITY OWNERSHIP. Every city occupied by a unit becomes that unit's power's, immediately, EVERY
    SEASON - this is Machiavelli, not Diplomacy. Unoccupied cities keep their owner. The conquest
    condition is checked here.
11. PLAGUE (Summer only). The server draws 1 city province uniformly from the 24: every unit standing
    in it is destroyed (no retreat, no compensation) and that city yields no income this year.
12. SEASON ADVANCE.

Winter, once per year after Autumn:

- W1 REBELLIONS. For each power, for each non-home city it owns with no unit standing in it, a d6: on
  a 1 the city rebels and reverts to unowned. Every roll is recorded.
- W2 FAMINE STRIKES. Every unit standing in one of this year's two famine provinces disbands.
- W3 INCOME. 3 ducats per city owned, excluding this year's famine and plague cities, plus a variable
  draw of 0..3 ducats per power.
- W4 UPKEEP. 1 ducat per unit. A power that cannot pay for all of them disbands units until it can -
  the one furthest from the nearest city it owns first, ties by ascending province code.
- W5 BUILDS. The Autumn `builds` list executes in order: 3 ducats each, into a VACANT CITY THE POWER
  OWNS (any owned city, not only a home city); a fleet only in a coastal city.

A power with zero units and zero cities after W5 is eliminated. It writes no press, receives no
orders call, and keeps whatever ducats it has - they still count for score.

## Press and pledges

Press is one exchange per season, not a conversation: all six write at once and letters are delivered
before the same season's orders batch, so a letter can be acted on the season it is sent but only
answered the next one. Nothing said in press binds anything - only the expenditure sheet binds. A
pledge exists so that a betrayal is machine-detectable and therefore drawable:

- peace, to a power: broken if your orders this season move any unit into a province that power
  occupies or into a city it owns, or support any such move, or bribe or assassinate it.
- keepout, over a province: broken if you order any unit into that province or support any move into
  it.
- support, to a power: broken if your orders contain no support of one of that power's units.

A broken pledge is recorded as a `stab` inside the battle event and the viewer stamps STAB over the
offender. Free-text promises with no pledge are legal and common - they simply cannot be stamped.

## The shocks and their exact probabilities

Every random draw comes from ONE seeded server-side stream, advanced in exactly this order and
nowhere else: Spring famine (2 draws), each season's assassination rolls (ascending payer index),
Summer plague (1 draw), Winter rebellion rolls (ascending power index then ascending province code),
Winter income draws (ascending power index). Every draw is written into the event that consumed it,
so a spectator can check the dice against the outcome, and the replay re-derives the same stream from
the seed and raises if a recorded draw disagrees.

- Famine: 2 of the 36 land provinces per year, uniform without replacement.
- Assassination: two dice, 1..36 uniform; success iff roll <= ducats paid (6..30). 18 ducats is 50%.
- Plague: 1 of the 24 cities per year, uniform.
- Rebellion: a d6 per empty non-home owned city per Winter; the city is lost on a 1 (1 in 6).
- Income draw: 0..3 ducats per power per Winter, uniform.

## Money, with every cost

- Starting treasury: 12 ducats. City income: 3 ducats per owned city per Winter. Unit upkeep: 1 ducat
  per unit per Winter. New unit: 3 ducats.
- Gift: any amount, arrives instantly, cannot be reversed.
- Bribe to disband: 9 ducats + the target's defence. Bribe to buy: 15 + defence.
- Defend: any amount; every ducat raises what a briber must beat.
- Assassinate: 6..30 ducats for a roll of two dice.

## Scoring, and its sign

Let c be the cities a power owns when the episode ends and d its ducats.

- CONQUEST: if any power owns 12 or more cities at a step-10 ownership update, or is the only power
  still owning a city, it scores 1.0, every other seat scores 0.0, and the episode ends there.
- OTHERWISE: score = (c + min(d, 24) / 24) / 24.

Higher is better and every score is in [0, 1]. The denominator is the constant 24, so an unclaimed
neutral dilutes everybody equally and taking a city is worth the same to every power. The treasury
term is worth at most one city, which is city-share-plus-treasury without letting a miser out-score a
conqueror. The league ranks by mean episode score.

## The three end reasons

- `conquest` - a power reached 12 cities, or is the last power owning any city. `conqueror` names it.
- `complete` - the configured years were played out through the final Winter.
- `deadline` - the episode clock stopped play between batches. Scores use the board as it stands. A
  deadline result is a legitimate, scoreable episode: the platform keeps nothing from an episode that
  overruns, so a short honest episode always beats a long one that never lands.

A four-year episode is usually decided on city share plus treasury rather than by a 12-city conquest.
That is deliberate.
