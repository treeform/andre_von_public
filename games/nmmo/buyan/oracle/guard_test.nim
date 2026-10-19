## Isolation test for the early-life guard: synthetic observations only,
## no game, no score. Checks that the guard stays silent on a calm
## window, ignores static (stale) enemy imprints, fires a flee away from
## a live stronger enemy while fragile, and stays silent once the agent
## is past the fragile level.
##
##   nim r guard_test.nim

import ../guard

const
  WindowCols = 15
  TileBytes = 10
  CenterRow = 5
  CenterCol = 7
  ScalarsOffset = 1650

proc calmObservation(comb: int): seq[uint8] =
  result = newSeq[uint8](observationSize)
  result[ScalarsOffset + 1] = uint8(comb)   # combat level
  result[ScalarsOffset + 8] = 0             # play mode

proc putEnemy(obs: var seq[uint8], r, c, delta: int, anim = 0) =
  let base = (r * WindowCols + c) * TileBytes
  obs[base + 4] = 2            # enemy entity
  obs[base + 6] = uint8(delta) # (seen comb - ours) / 2 clamped
  obs[base + 8] = uint8(anim)

proc main() =
  var g = newGuard()
  # Tick 0 calm, tick 1 calm: nothing fires.
  doAssert g.decide(calmObservation(2), 4) == 4
  doAssert g.decide(calmObservation(2), 1) == 1
  doAssert g.overrides == 0
  # A stronger enemy imprint that was already there at tick 0 is static:
  # not live, no combat flag -> no override.
  var stale = newGuard()
  var obs = calmObservation(2)
  obs.putEnemy(CenterRow, CenterCol + 1, 2)
  doAssert stale.decide(obs, 1) == 1
  doAssert stale.decide(obs, 1) == 1
  doAssert stale.overrides == 0
  # The same imprint appearing fresh (changed cell) is live: flee left,
  # as a run because both tiles are grass.
  var fresh = newGuard()
  doAssert fresh.decide(calmObservation(2), 4) == 4
  let action = fresh.decide(obs, 2)      # net wants to walk right
  doAssert action == 3 + 22, "expected run left, got " & $action
  doAssert fresh.overrides == 1
  # Not fragile any more: the network keeps control.
  var strong = newGuard()
  var obsStrong = calmObservation(6)
  doAssert strong.decide(calmObservation(6), 4) == 4
  obsStrong.putEnemy(CenterRow, CenterCol + 1, 2)
  doAssert strong.decide(obsStrong, 2) == 2
  doAssert strong.overrides == 0
  # A dead imprint (death anim) never counts.
  var corpse = newGuard()
  var obsCorpse = calmObservation(2)
  doAssert corpse.decide(calmObservation(2), 4) == 4
  obsCorpse.putEnemy(CenterRow - 1, CenterCol, 3, anim = 5)
  doAssert corpse.decide(obsCorpse, 0) == 0
  doAssert corpse.overrides == 0
  echo "guard_test: OK"

main()
