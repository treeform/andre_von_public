# Gods of the Arena player surface

`player_runtime` is `game-hosted`. There is no container and no socket:
you upload one `.bas` file and the game compiles it into a VM per hero.
Slots 0-4 are Red, slots 5-9 are Blue.

One VM per hero, run **every tick** (24 ticks a second, 28800 tick match)
with 20000 instructions and 50000 work units per decision. Globals survive
between decisions. Blowing a limit disables that VM for the rest of the
match; a syntax error fails the whole episode with a player failure.

## Read-only host data

    selfId selfTeam selfClass selfX selfY selfHp selfMaxHp
    selfMana selfMaxMana selfGold selfLevel worldTick

`selfId` starts at 100 for the first hero. Positions are map tiles on a
128x128 grid, so the centre of the arena is 64, 64.

## World queries

Indices run 0 to `objectCount() - 1`, over everything the hero's **team**
can currently see (own objects are always visible):

    objectId(i) objectKind(i) objectTeam(i) objectClass(i)
    objectX(i) objectY(i) objectHp(i) objectAlive(i)

The list is ordered forts, towers, heroes, footmen.

Object kinds are 1 fort, 2 hero, 3 footman, 4 tower. Hero classes are
stable integers 0-9; everything else reports -1. There is no
`objectMaxHp`, so an enemy hero's health can only be read absolutely.

**`objectAlive` means "attackable right now"** for structures, which is
the single most useful thing in the API:

- a tower reports alive only once every earlier tower in its lane (outer,
  then inner, then gate) is down;
- a fort reports alive only once one of its three lanes is completely
  cleared.

## Actions

    walkTo(x, y)            800 work units, server-side pathfinding
    attackTarget(objectId)   20 work units, persistent chase
    buyItem(itemId)          20 work units
    useItem(slot)            20 work units

`attackTarget` is validated against team and attackability and returns 0
when refused. `walkTo` returns 0 even when it is accepted, so never gate
on its result. `attackTarget(0)` clears the current target.

Gold read inside one decision is a snapshot taken before the decision
ran, so several `buyItem` calls can be attempted in a row; the ones that
cannot be paid for are refused by the simulation.

## Combat the script does not control

Heroes auto-acquire anything inside their acquire radius and auto-cast
their whole Q/W/E/R kit. The script chooses targets, movement and
shopping; it cannot aim an ability.

Towers target footmen before heroes, so a hero diving a tower with
friendly footmen alongside takes far less damage than one diving alone.

**Nothing regenerates health.** Mana ticks back at 4 a second; health only
comes from potions, class heal abilities, and respawning.

## Shop

Six slots, consumables stack to 8, heroes start with 150 gold. Item ids:

    1 ration (30)     2 elixir (50)      3 mana potion (45)  4 poison (40)
    5 helmet (80)     6 buckler (90)     7 gauntlets (70)    8 boots (100)
    9 amulet (120)   10 ring (120)      11 dagger (110)     12 wand (140)
   13 sword (150)    14 bow (150)       15 pauldrons (140)  16 armor (160)
   17 staff (170)    18 axe (180)       19 crossbow (180)   20 spellbook (190)

No item has a class restriction; the baseline's per-class ladder is a
convention, not a rule. Bounties: footman 15 gold / 25 XP, tower 75 / 100,
hero 100 / 150.

## Scoring

Every hero on the team that destroys the enemy fort scores 1. **A match
that reaches the tick limit scores 0 for all ten heroes**, which is why an
exposed fort is worth more than any amount of farming.
