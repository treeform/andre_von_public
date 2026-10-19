## Isolation tests for combat focus filter 2.
## v1 filter: 0 if hostile creeps in crop, else 2.
## Candidate uses 2 whenever an enemy hero is visible.

from candidate as focus import nil
from baseline as frozen import nil

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
  DireHero0 = 11

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

proc v1Filter(hasCreep: bool): int =
  ## Frozen gorynych:v1 attack filter.
  if hasCreep: 0 else: 2

proc pair(obs: string): (array[6, int], array[6, int], focus.GorynychPolicy) =
  ## Same obs through candidate and frozen v1, hosted-order index 0.
  let
    cand = focus.newGorynychPolicy()
    base = frozen.newGorynychPolicy()
  (focus.heroAction(cand, 0, obs), frozen.heroAction(base, 0, obs), cand)

echo "hero+creep issues filter 2 vs v1 0; movement and skills match v1"
block:
  let obs = makeObs(tiles = @[(0, 1, DireCreep), (0, -1, DireHero0)])
  let (a, b, policy) = pair(obs)
  doAssert a[2] == 2
  doAssert b[2] == 0
  doAssert b[2] == v1Filter(true)
  doAssert a[0] == b[0] and a[1] == b[1], "combat filter must not steer"
  doAssert a[3] == b[3] and a[4] == b[4] and a[5] == b[5]
  doAssert a != b
  doAssert policy.trial.heroCalls == 1
  doAssert policy.trial.changedActions == 1
  doAssert policy.trial.triggers == 1
  doAssert policy.trial.focusFilters == 1

echo "creep-only filter and full action match v1"
block:
  let obs = makeObs(tiles = @[(0, 1, DireCreep)])
  let (a, b, policy) = pair(obs)
  doAssert a[2] == 0
  doAssert a == b
  doAssert a[2] == v1Filter(true)
  doAssert policy.trial.changedActions == 0
  doAssert policy.trial.triggers == 0
  doAssert policy.trial.focusFilters == 0

echo "hero-only filter 2 matches v1; no changedAction"
block:
  let obs = makeObs(tiles = @[(0, -1, DireHero0)])
  let (a, b, policy) = pair(obs)
  doAssert a[2] == 2
  doAssert a == b
  doAssert a[2] == v1Filter(false)
  doAssert policy.trial.changedActions == 0

echo "empty crop filter 2 matches v1"
block:
  let (a, b, policy) = pair(makeObs())
  doAssert a[2] == 2
  doAssert a == b
  doAssert policy.trial.changedActions == 0

echo "support / burst / tank / carry also focus when both visible"
block:
  for hero in [SupportHero, BurstHero, TankHero, CarryHero]:
    let obs = makeObs(
      heroType = hero,
      tiles = @[(1, 0, DireCreep), (0, 1, DireHero0)]
    )
    let (a, b, policy) = pair(obs)
    doAssert a[2] == 2, "role " & $hero & " should focus"
    doAssert b[2] == 0
    doAssert a[0] == b[0] and a[1] == b[1]
    doAssert a[3] == b[3] and a[4] == b[4] and a[5] == b[5]
    doAssert policy.trial.changedActions == 1

echo "retreat hp still only changes the filter, not the retreat step"
block:
  let obs = makeObs(
    x = 99, y = 26, health10 = 3,
    tiles = @[(0, 1, DireCreep), (0, -1, DireHero0)]
  )
  let (a, b, policy) = pair(obs)
  doAssert a[2] == 2
  doAssert b[2] == 0
  doAssert a[0] == b[0] and a[1] == b[1]
  doAssert a[3] == b[3] and a[4] == b[4] and a[5] == b[5]
  doAssert policy.trial.changedActions == 1

echo "siege hold movement matches v1; filter 2 only if a hero is in crop"
block:
  # Chebyshev 6 from dire T1 at (18.723, 29.062) -> hold, not back off.
  let hold = makeObs(x = 29, y = 24)
  let (a, b, policy) = pair(hold)
  doAssert a[0] == 3 and a[1] == 3, "standoff should hold"
  doAssert a == b
  doAssert policy.trial.changedActions == 0
  let fight = makeObs(
    x = 29, y = 24,
    tiles = @[(0, 1, DireCreep), (1, 0, DireHero0)]
  )
  let (c, d, p2) = pair(fight)
  doAssert c[0] == d[0] and c[1] == d[1], "siege steering unchanged"
  doAssert c[2] == 2 and d[2] == 0
  doAssert p2.trial.changedActions == 1

echo "two candidate policies on the same obs match"
block:
  let obs = makeObs(tiles = @[(0, 1, DireCreep), (0, -1, DireHero0)])
  let a = focus.heroAction(focus.newGorynychPolicy(), 0, obs)
  let b = focus.heroAction(focus.newGorynychPolicy(), 0, obs)
  doAssert a == b

echo "1000 empty calls never change the filter; counters stay 0"
block:
  let policy = focus.newGorynychPolicy()
  for i in 1 .. 1000:
    let a = focus.heroAction(policy, 0, makeObs())
    doAssert a[2] == 2
  doAssert policy.trial.heroCalls == 1000
  doAssert policy.trial.triggers == 0
  doAssert policy.trial.changedActions == 0
  doAssert policy.trial.focusFilters == 0

echo "friendly creep plus enemy hero matches v1 filter 2"
block:
  const RadiantCreep = 3
  let obs = makeObs(tiles = @[(0, 1, RadiantCreep), (0, -1, DireHero0)])
  let (a, b, policy) = pair(obs)
  doAssert a[2] == 2 and b[2] == 2
  doAssert a == b
  doAssert policy.trial.changedActions == 0

echo "hosted-order tower memory: five obs, only the mixed row changes"
block:
  let
    cand = focus.newGorynychPolicy()
    base = frozen.newGorynychPolicy()
    empty = makeObs(heroType = SupportHero)
    mixed = makeObs(
      heroType = AssassinHero,
      tiles = @[(0, 1, DireCreep), (0, -1, DireHero0)]
    )
    creep = makeObs(
      heroType = BurstHero,
      tiles = @[(0, 1, DireCreep)]
    )
  let rows = [empty, mixed, creep, empty, empty]
  var changed = 0
  for i, obs in rows:
    let a = focus.heroAction(cand, i, obs)
    let b = frozen.heroAction(base, i, obs)
    if a != b:
      inc changed
      doAssert a[2] == 2 and b[2] == 0
      doAssert a[0] == b[0] and a[1] == b[1]
  doAssert changed == 1
  doAssert cand.trial.changedActions == 1
  doAssert cand.trial.focusFilters == 1

echo "all targets isolation tests passed"
