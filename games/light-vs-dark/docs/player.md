# Light vs Dark player surface

`player_runtime` is `game-hosted`: upload one `.bas` file, no container.
Two seats, Light and Dark, on a 128-tile map where Dark's half is Light's
half rotated 180 degrees.

You command a **player**, not a unit. The script runs from the top five
times a second with 300000 instructions and 400000 work units. Globals and
arrays survive between decisions, registers do not. A loop over every unit
nested inside another loop over every unit will blow the budget, mark the
script failed, and leave the player standing still for the rest of the
match.

## Read-only host data

    selfPlayer enemyPlayer worldTick gold wood foodUsed foodCap
    obsCount ownUnits ownBuildings homeX homeY mapSize decisionPeriod

## Observations

Index 0 to `obsCount - 1`, ordered: own buildings, own units, whatever of
the enemy's is currently visible, gold mines, nearest tree tiles. Fog of
war is real - anything unseen is simply absent from the list.

    obsId(i) obsKind(i) obsOwner(i) obsSub(i) obsX(i) obsY(i)
    obsHp(i) obsMaxHp(i) obsState(i) obsResource(i) obsIndexOf(id)
    obsIdle(i) obsUnderConstruction(i) obsFailed(i) obsDropOff(i)
    obsCarrying(i)

`obsKind`: 1 building, 2 unit, 3 gold mine, 4 tree.
`obsSub` for units: 0 peon, 1 soldier, 2 archer, 3 mage, 4 knight,
5 catapult, 6 cleric, 7 summon.
`obsSub` for buildings: 0 hall, 1 farm, 2 barracks, 3 lumber mill,
4 tower, 5 stables, 6 church, 7 blacksmith.

`and`, `or` and `not` are **logical**, not bitwise: `16 and 1` is 1.

## Queries

    distance(x1, y1, x2, y2)   nearestEnemy(unitId)
    nearestOwnIdle(kind, x, y) nearestMine(x, y)   nearestTree(x, y)
    nearestDropOff(x, y, wantWood)                 canPlace(kind, x, y)
    tilePassable(x, y) tileVisible(x, y) tileExplored(x, y)
    unitCostGold(k) unitCostWood(k) unitFood(k) unitTrainTicks(k)
    unitRange(k) unitHp(k)
    buildCostGold(k) buildCostWood(k) buildTicks(k) buildFootprint(k)
    buildFood(k) canBuild(k) canTrain(buildingId, unitKind)

The `nearest*` calls search inside the host, which is far cheaper than
scanning the observation list yourself.

## Commands

All return 1 when accepted and 0 when refused.

    moveUnit(id, x, y)          attackMove(id, x, y)
    attackUnit(id, targetId)
    harvest(id, target, isTree) build(peonId, kind, x, y)
    train(buildingId, kind)     setRally(buildingId, x, y)
    cancel(id)                  orderFailed(id)

`harvest` wants a mine id with `isTree` 0, or a tile index with 1.
`attackMove` marches to a tile but stops to fight whatever it sees;
`moveUnit` walks through everyone.

## Victory and scoring

A player is defeated once it has no standing buildings and no peon left
to raise one. If the 20-minute clock lands first, the higher score wins:

    buildings * 1000 + army * 100 + (gold + wood ever gathered) / 100

A construction site counts as a standing building from the moment it is
placed - `buildingCount` only excludes buildings that are dying. A farm is
400 gold and 200 wood for a flat 1000; a knight is 850 gold for 100.
