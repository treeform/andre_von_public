## Isolation tests for assassin early return (exit 6 vs v1 exit 8).
## Crafted observations only; no sim scores.

import
  std/tables,
  candidate

const
  ObsSize = 510
  SelfOff = 484
  CropW = 11
  Vis = 5
  SupportHero = 0
  AssassinHero = 1
  BurstHero = 2
  TankHero = 3
  CarryHero = 4
  DireCreep = 4
  RadiantHero0 = 6

proc makeObs(
    x = 12, y = 113, level = 0, health10 = 10, mana10 = 10,
    team = 0, heroType = AssassinHero, moveModifier = 1, eTimer = 0,
    tiles: seq[(int, int, int)] = @[]
): string =
  ## Synthetic 510-byte obs matching compute_observations (moba.h:460).
  result = newString(ObsSize)
  result[SelfOff + 0] = chr(x)
  result[SelfOff + 1] = chr(y)
  result[SelfOff + 2] = chr(level)
  result[SelfOff + 3] = chr(health10)
  result[SelfOff + 4] = chr(mana10)
  result[SelfOff + 5] = chr(1)
  result[SelfOff + 6] = chr(1)
  result[SelfOff + 7] = chr(moveModifier)
  result[SelfOff + 12] = chr(eTimer)
  result[SelfOff + 16] = chr(team)
  result[SelfOff + 17 + heroType] = chr(1)
  let selfTile = RadiantHero0 + heroType + 5 * team
  result[Vis * CropW + Vis] = chr(selfTile)
  for (dy, dx, tile) in tiles:
    result[(dy + Vis) * CropW + (dx + Vis)] = chr(tile)

proc vel(a: array[6, int]): (int, int) =
  ((a[0] - 3) div 3, (a[1] - 3) div 3)

proc moving(a: array[6, int]): bool =
  a[0] != 3 or a[1] != 3

echo "full-health assassin push matches v1 (walks off spawn)"
block:
  let policy = newGorynychPolicy()
  let a = policy.heroAction(0, makeObs())
  doAssert moving(a)
  doAssert policy.heroes[0].mode == PushMode
  doAssert policy.trial.triggers == 0
  doAssert policy.trial.changedActions == 0
  doAssert a[5] == 0, "push assassin must not gain haste E"

echo "assassin enters retreat at health 3, same as v1"
block:
  let policy = newGorynychPolicy()
  let a = policy.heroAction(0, makeObs(x = 26, y = 99, health10 = 3))
  doAssert policy.heroes[0].mode == RetreatMode
  doAssert moving(a), "from mid, retreat walks toward fountain"
  let (dy, dx) = vel(a)
  doAssert dy > 0 or dx < 0, "fountain is south-west of mid"
  doAssert a[5] == 1, "retreat assassin still flags E"
  doAssert policy.trial.triggers == 0
  doAssert policy.trial.changedActions == 0

echo "assassin health 5 stays retreat (below new exit 6)"
block:
  let policy = newGorynychPolicy()
  discard policy.heroAction(0, makeObs(x = 26, y = 99, health10 = 3))
  let a = policy.heroAction(0, makeObs(x = 26, y = 99, health10 = 5))
  doAssert policy.heroes[0].mode == RetreatMode
  doAssert policy.trial.triggers == 0
  doAssert policy.trial.changedActions == 0
  doAssert a[5] == 1

echo "assassin health 6 after retreat returns to PUSH; issued vel differs"
block:
  let policy = newGorynychPolicy()
  let low = policy.heroAction(0, makeObs(x = 26, y = 99, health10 = 3))
  let (rdy, rdx) = vel(low)
  let a = policy.heroAction(0, makeObs(x = 26, y = 99, health10 = 6))
  doAssert policy.heroes[0].mode == PushMode
  doAssert policy.trial.triggers == 1
  doAssert policy.trial.earlyExits == 1
  doAssert policy.trial.changedActions == 1
  doAssert policy.trial.actualMoves == 1
  let (pdy, pdx) = vel(a)
  doAssert (pdy, pdx) != (rdy, rdx)
  doAssert moving(a)
  doAssert a[5] == 0, "mode is PUSH so E is v1-off, not haste"

echo "assassin at fountain health 6 walks to lane; v1 would hold"
block:
  let policy = newGorynychPolicy()
  let held = policy.heroAction(0, makeObs(health10 = 3))
  doAssert not moving(held), "already at spawn"
  let a = policy.heroAction(0, makeObs(health10 = 6))
  doAssert policy.heroes[0].mode == PushMode
  doAssert moving(a), "early return must leave fountain"
  doAssert policy.trial.changedActions == 1
  doAssert policy.trial.actualMoves == 1

echo "burst keeps v1 exit 8: health 6 after retreat still retreats"
block:
  let policy = newGorynychPolicy()
  discard policy.heroAction(0, makeObs(
    x = 26, y = 99, health10 = 3, heroType = BurstHero
  ))
  let a = policy.heroAction(0, makeObs(
    x = 26, y = 99, health10 = 6, heroType = BurstHero
  ))
  doAssert policy.heroes[0].mode == RetreatMode
  doAssert policy.trial.triggers == 0
  doAssert policy.trial.changedActions == 0
  let (dy, dx) = vel(a)
  doAssert dy > 0 or dx < 0

echo "burst health 8 exits, assassin would too; no extra trigger vs v1"
block:
  let policy = newGorynychPolicy()
  discard policy.heroAction(0, makeObs(
    x = 26, y = 99, health10 = 3, heroType = BurstHero
  ))
  let a = policy.heroAction(0, makeObs(
    x = 26, y = 99, health10 = 8, heroType = BurstHero
  ))
  doAssert policy.heroes[0].mode == PushMode
  doAssert policy.trial.triggers == 0, "v1 also exits at 8"
  doAssert policy.trial.changedActions == 0

echo "support, tank, carry stay in retreat at health 6-7"
block:
  for heroType in [SupportHero, TankHero, CarryHero]:
    let policy = newGorynychPolicy()
    discard policy.heroAction(0, makeObs(
      x = 26, y = 99, health10 = 3, heroType = heroType
    ))
    let a = policy.heroAction(0, makeObs(
      x = 26, y = 99, health10 = 7, heroType = heroType
    ))
    doAssert policy.heroes[0].mode == RetreatMode, $heroType
    doAssert policy.trial.changedActions == 0, $heroType
    doAssert moving(a)

echo "health 4 never enters; unchanged enter threshold"
block:
  let policy = newGorynychPolicy()
  discard policy.heroAction(0, makeObs(x = 26, y = 99, health10 = 4))
  doAssert policy.heroes[0].mode == PushMode
  doAssert policy.trial.triggers == 0

echo "siege hold at full health unchanged"
block:
  # Chebyshev 6 from dire T1 at (18.723, 29.062) -> hold.
  let policy = newGorynychPolicy()
  let a = policy.heroAction(0, makeObs(x = 29, y = 24))
  doAssert not moving(a)
  doAssert policy.trial.changedActions == 0

echo "Q/W flags unchanged for assassin in the new push-at-6"
block:
  let policy = newGorynychPolicy()
  discard policy.heroAction(0, makeObs(x = 26, y = 99, health10 = 3))
  let a = policy.heroAction(0, makeObs(
    x = 26, y = 99, health10 = 6,
    tiles = @[(0, 1, DireCreep)]
  ))
  doAssert a[3] == 1, "creep-in-crop still flags Q"
  doAssert a[4] == 0
  doAssert a[5] == 0

echo "two policies on the same obs return the same action"
block:
  let o1 = makeObs(x = 26, y = 99, health10 = 3)
  let o2 = makeObs(x = 26, y = 99, health10 = 6)
  let p1 = newGorynychPolicy()
  let p2 = newGorynychPolicy()
  doAssert p1.heroAction(0, o1) == p2.heroAction(0, o1)
  doAssert p1.heroAction(0, o2) == p2.heroAction(0, o2)

echo "malformed obs is a no-op and counts a heroCall"
block:
  let policy = newGorynychPolicy()
  let a = policy.heroAction(0, "short")
  doAssert a == [3, 3, 0, 0, 0, 0]
  doAssert policy.trial.heroCalls == 1

echo "all sustain isolation tests passed"
