## Isolation tests for assassin push-E haste.
## v1 assassin E: RetreatMode and mana>=100, including stand/CD/buff.
## Candidate adds E only for a moving PushMode assassin when ready.

import
  std/json,
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

proc moving(a: array[6, int]): bool =
  ## True when velocity is not the zero action (vy,vx == 3,3).
  a[0] != 3 or a[1] != 3

proc skills(a: array[6, int]): (int, int, int) =
  ## (use_q, use_w, use_e) from a 6-int action row.
  (a[3], a[4], a[5])

proc act(obs: string): (GorynychPolicy, array[6, int]) =
  ## One heroAction on a fresh policy, returning both for telemetry.
  let policy = newGorynychPolicy()
  (policy, policy.heroAction(0, obs))

proc baselineAssassinE(retreat, manaOk: bool): int =
  ## Frozen gorynych:v1 assassin E: retreat only, mana gate only.
  if retreat and manaOk: 1 else: 0

echo "push moving assassin uses E (the one new flag vs v1)"
block:
  let (policy, a) = act(makeObs())
  doAssert moving(a), "spawn assassin should walk toward mid"
  doAssert skills(a) == (0, 0, 1)
  doAssert a[5] != baselineAssassinE(false, true)
  doAssert policy.trial.heroCalls == 1
  doAssert policy.trial.pushEIntents == 1
  doAssert policy.trial.changedActions == 1
  doAssert policy.trial.triggers == 0, "intent is not activation"

echo "following obs confirms push E only with CD near 100 and buff"
block:
  let policy = newGorynychPolicy()
  let first = policy.heroAction(0, makeObs())
  doAssert first[5] == 1
  doAssert policy.trial.triggers == 0
  let second = policy.heroAction(0, makeObs(
    moveModifier = 2, eTimer = 100
  ))
  doAssert policy.trial.triggers == 1
  doAssert policy.trial.pushEIntents == 1
  doAssert policy.trial.changedActions == 1
  doAssert second[5] == 0, "already buffed push must not recast"

echo "Q/W preemption: next obs without buff is not a trigger"
block:
  let policy = newGorynychPolicy()
  let first = policy.heroAction(0, makeObs(
    tiles = @[(0, 1, DireCreep), (0, -1, DireHero0)]
  ))
  doAssert first[3] == 1 and first[4] == 1 and first[5] == 1
  doAssert policy.trial.pushEIntents == 1
  doAssert policy.trial.triggers == 0
  # Engine Q else W else E: Q lands, E does not. CD stays idle.
  discard policy.heroAction(0, makeObs(eTimer = 40, moveModifier = 1))
  doAssert policy.trial.triggers == 0
  doAssert policy.trial.pushEIntents == 1
  doAssert policy.trial.changedActions == 1

echo "retreat flags match v1 exactly, including stand/CD/buff"
block:
  let stand = act(makeObs(health10 = 3))
  doAssert not moving(stand[1]), "already at spawn, retreat should hold"
  doAssert stand[1][5] == 1
  doAssert stand[1][5] == baselineAssassinE(true, true)
  doAssert stand[0].trial.pushEIntents == 0
  doAssert stand[0].trial.changedActions == 0
  doAssert stand[0].trial.triggers == 0
  let walk = act(makeObs(x = 99, y = 26, health10 = 3))
  doAssert moving(walk[1])
  doAssert walk[1][5] == 1
  doAssert walk[0].trial.changedActions == 0
  let cd = act(makeObs(health10 = 3, eTimer = 40))
  doAssert cd[1][5] == 1, "v1 retreat E ignores cooldown"
  doAssert cd[0].trial.changedActions == 0
  let buffed = act(makeObs(health10 = 3, moveModifier = 2, eTimer = 0))
  doAssert buffed[1][5] == 1, "v1 retreat E ignores active buff"
  doAssert buffed[0].trial.changedActions == 0
  let dry = act(makeObs(health10 = 3, mana10 = 3))
  doAssert dry[1][5] == 0
  doAssert dry[0].trial.changedActions == 0

echo "push cooldown and already-buffed do not add E"
block:
  let a2 = act(makeObs(eTimer = 2))[1]
  let a1 = act(makeObs(eTimer = 1))[1]
  let a0 = act(makeObs(eTimer = 0))[1]
  doAssert moving(a2) and moving(a1) and moving(a0)
  doAssert a2[5] == 0
  doAssert a1[5] == 1
  doAssert a0[5] == 1
  let hasted = act(makeObs(moveModifier = 2, eTimer = 0))[1]
  doAssert moving(hasted)
  doAssert hasted[5] == 0

echo "slowed assassin still gets the new push E"
block:
  let a = act(makeObs(moveModifier = 0, eTimer = 0))[1]
  doAssert moving(a)
  doAssert a[5] == 1

echo "siege hold does not add push E"
block:
  # Chebyshev 6 from dire T1 at (18.723, 29.062) -> hold, not back off.
  let a = act(makeObs(x = 29, y = 24))[1]
  doAssert not moving(a), "standoff should hold"
  doAssert a[5] == 0

echo "mana threshold preserved: level-0 mana10=3 cannot pay 100"
block:
  let a = act(makeObs(mana10 = 3))[1]
  doAssert moving(a)
  doAssert a[5] == 0
  let ok = act(makeObs(mana10 = 4))[1]
  doAssert ok[5] == 1

echo "assassin Q/W unchanged with creeps and an enemy hero"
block:
  let a = act(makeObs(
    tiles = @[(0, 1, DireCreep), (0, -1, DireHero0)]
  ))[1]
  doAssert a[3] == 1, "Q still fires on hostile creeps"
  doAssert a[4] == 1, "W still fires on an enemy hero at hp>=5"
  doAssert a[5] == 1, "push E still requested beside Q/W"

echo "other roles: E matches baseline, including cooldown-irrelevant E"
block:
  let enemy = @[(0, 1, DireHero0)]
  let creep = @[(0, 1, DireCreep)]
  proc roleE(heroType: int, tiles: seq[(int, int, int)],
             health10 = 10, eTimer = 40): int =
    act(makeObs(heroType = heroType, health10 = health10,
                eTimer = eTimer, tiles = tiles))[1][5]
  doAssert roleE(SupportHero, enemy) == 1
  doAssert roleE(SupportHero, @[]) == 0
  doAssert roleE(BurstHero, enemy) == 1
  doAssert roleE(BurstHero, @[]) == 0
  doAssert roleE(TankHero, enemy) == 1
  doAssert roleE(TankHero, @[]) == 0
  doAssert roleE(CarryHero, creep) == 1
  doAssert roleE(CarryHero, @[]) == 0
  doAssert roleE(SupportHero, enemy, eTimer = 40) == 1

echo "other roles do not increment assassin counters"
block:
  let (policy, a) = act(makeObs(
    heroType = SupportHero, tiles = @[(0, 1, DireHero0)]
  ))
  doAssert a[5] == 1
  doAssert policy.trial.pushEIntents == 0
  doAssert policy.trial.triggers == 0
  doAssert policy.trial.changedActions == 0
  doAssert policy.trial.heroCalls == 1

echo "Q/W/movement identity vs a second identical call (telemetry-safe)"
block:
  let obs = makeObs()
  let (p1, a1) = act(obs)
  let a2 = p1.heroAction(0, obs)
  doAssert a1 == a2
  let (_, b1) = act(obs)
  doAssert a1 == b1
  doAssert p1.trial.heroCalls == 2
  doAssert p1.trial.pushEIntents == 2
  doAssert p1.trial.changedActions == 2
  doAssert p1.trial.triggers == 0

echo "MOBA_TRIAL JSON fields"
block:
  let (policy, _) = act(makeObs())
  let node = policy.trialSummary()
  doAssert node["idea"].getStr() == "assassin-haste-movement-uptime"
  doAssert node["heroCalls"].getInt() == 1
  doAssert node["pushEIntents"].getInt() == 1
  doAssert node["triggers"].getInt() == 0
  doAssert node["changedActions"].getInt() == 1
  doAssert node.hasKey("idea") and node.hasKey("heroCalls")
  doAssert node.hasKey("pushEIntents") and node.hasKey("triggers")
  doAssert node.hasKey("changedActions")

echo "every 1000 hero calls still counts (progress emit path)"
block:
  let policy = newGorynychPolicy()
  let obs = makeObs()
  for i in 1 .. 1000:
    discard policy.heroAction(0, obs)
  doAssert policy.trial.heroCalls == 1000
  doAssert policy.trial.pushEIntents == 1000
  doAssert policy.trial.changedActions == 1000
  doAssert policy.trial.triggers == 0, "same obs never confirms a cast"

echo "malformed obs is a no-op and is not a trigger"
block:
  let (policy, a) = act("short")
  doAssert a == [3, 3, 0, 0, 0, 0]
  doAssert policy.trial.heroCalls == 1
  doAssert policy.trial.pushEIntents == 0
  doAssert policy.trial.triggers == 0
  doAssert policy.trial.changedActions == 0

echo "all haste isolation tests passed"
