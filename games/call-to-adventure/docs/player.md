# Call to Adventure player surface

`player_runtime` is `game-hosted`: upload one `.bas` file, no container.
Four seats, one hero each - fighter, wizard, rogue, cleric - descending
six stacked 128x128 floors and climbing back out.

One VM per hero with 100000 instructions and 200000 work units per
decision. Movement and combat are high-level commands; the game owns
pathfinding and records only accepted actions in the replay.

## Read-only host data

    selfId selfClass worldTick currentLevel x y hp maxHp mana maxMana
    objectiveLevel objectiveX objectiveY

`objective*` is the game's own guidance: the way down while the vault
still holds monsters, and the way home afterwards.

## Queries

    nearestEnemy()   nearest hostile inside the aggro radius, else 0.
                     While the party is descending this widens to the
                     whole floor around the party anchor.
    nearestLoot()    nearest pile or item on the floor, else 0.
    woundedAlly()    only ever non-zero for a cleric with Healing Bloom
                     off cooldown, enough mana, and an ally under 70
                     percent within range. Refused outright for everyone
                     else, so it is safe to call from a shared script.

## Commands

All return 1 when accepted and 0 when refused.

    walkTo(level, x, y)   attackTarget(id)   pickupTarget(id)
    healTarget(id)        useItem(slot)      dropItem(slot)

There are two item slots, 0 and 1, and **no way to read what is in them** -
`useItem` on an empty or unusable slot simply returns 0.

Only `stop` after a command that actually started. A failed attack or
pickup that halts the tick leaves the hero standing still.

## Scoring

Gold is personal, not shared, and only counts once that hero has walked
it onto the surface. Living heroes who returned with the **highest
personal banked gold** score 1, tied leaders share it, and dead or
unreturned heroes score 0. If nobody returns there is no winner.

Every kill drops a gold pile (12 plus 8 a floor). Deeper floors and golems
can also drop an item; the purse-only drops are gemstone 60, chalice 140,
idol 300, crown 900. On the climb out, monsters respawn on the floors
above the party every 15 seconds.
