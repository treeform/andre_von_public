include candidate

proc observation(): string =
  ## Construct a full-health observation on passable terrain.
  result = newString(observationSize)
  result[scalarsOffset + scalarHealth] = char(100)
  result[scalarsOffset + scalarCombatLevel] = char(1)
  result[scalarsOffset + scalarProfessionLevel] = char(1)

proc enemy(data: var string, row, col: int, present = true) =
  ## Write or clear one enemy cell in a synthetic observation.
  let base = (row * windowCols + col) * tileBytes
  for b in entityTypeByte ..< tileBytes:
    data[base + b] = char(0)
  if present:
    data[base + entityTypeByte] = char(enemyEntity)
    data[base + entityHealthByte] = char(5)

echo "Testing clean observation URL handling"
doAssert withObsClean("ws://game/player") ==
  "ws://game/player?obs=clean"
doAssert withObsClean("ws://game/player?slot=2&token=a%2Bb%26c#x") ==
  "ws://game/player?slot=2&token=a%2Bb%26c&obs=clean#x"
doAssert withObsClean("ws://game/player?obs=old&slot=3&obs=other") ==
  "ws://game/player?obs=clean&slot=3"

echo "Testing unsupported observations preserve legacy decisions"
block:
  var data = observation()
  data.enemy(centerRow, centerCol + 1)
  let
    candidate = newMind(37, 0)
    legacy = newMind(37, 0)
  legacy.shadowLegacy = true
  for tick in 0 ..< 32:
    doAssert candidate.chooseAction(data) == legacy.chooseAction(data)
    doAssert not candidate.verifiedClean
    doAssert candidate.rng.state == legacy.rng.state
  doAssert candidate.clearedCells == 0

echo "Testing support witness and reset boundaries"
block:
  var
    before = observation()
    after = observation()
  before.enemy(1, 1)
  let
    previous = perceptFrom(before)
    current = perceptFrom(after)
    mind = newMind(8, 0)
  doAssert countClearedEntityCells(previous.data, current.data) == 1
  after[(windowCols + 1) * tileBytes + entityHealthByte] = char(1)
  doAssert countClearedEntityCells(previous.data, perceptFrom(after).data) == 0
  discard mind.chooseAction(before)
  mind.reset()
  discard mind.chooseAction(observation())
  doAssert not mind.verifiedClean
  doAssert mind.clearedCells == 0

echo "Testing confirmed static target and unchanged health gates"
block:
  var data = observation()
  data.enemy(1, 1)
  data.enemy(centerRow, centerCol + 1)
  let mind = newMind(19, 0)
  discard mind.chooseAction(data)
  data.enemy(1, 1, false)
  doAssert mind.chooseAction(data) == attackAction
  doAssert mind.verifiedClean
  doAssert mind.clearedCells == 1
  for tick in 0 ..< attackStreakMax + liveTtl + 2:
    doAssert mind.chooseAction(data) == attackAction
  let legacy = copyMind(mind)
  legacy.shadowLegacy = true
  doAssert legacy.chooseAction(data) != attackAction
  data[scalarsOffset + scalarHealth] = char(fightKeepHealth - 1)
  doAssert mind.chooseAction(data) != attackAction
  mind.reset()
  doAssert mind.verifiedClean
  doAssert not mind.hasPrev
  data[scalarsOffset + scalarHealth] = char(fightStartHealth - 1)
  doAssert mind.chooseAction(data) != attackAction
  data[scalarsOffset + scalarHealth] = char(fightStartHealth)
  let base = (centerRow * windowCols + centerCol + 1) * tileBytes
  data[base + entityAnimByte] = char(deathAnim)
  doAssert mind.liveHints(perceptFrom(data)).len == 0
  doAssert mind.chooseAction(data) != attackAction

echo "Testing activation and telemetry do not mutate policy twice"
block:
  resetCleanStats()
  var data = observation()
  data.enemy(1, 1)
  data.enemy(centerRow, centerCol + 1)
  let mind = newMind(71, 0)
  discard mind.act(data, 0)
  data.enemy(1, 1, false)
  let direct = copyMind(mind)
  doAssert mind.act(data, 1) == direct.chooseAction(data)
  doAssert mind.rng.state == direct.rng.state
  doAssert mind.lastAction == direct.lastAction
  doAssert mind.attackStreak == direct.attackStreak
  doAssert mind.live == direct.live
  doAssert cleanStats.clearedCells == 1
  doAssert cleanStats.actionChanges == 1
  doAssert cleanStats.activationsLogged == 1
  doAssert cleanStats.extraHints > 0
  let copy = copyMind(mind)
  copy.live[0] = 88
  doAssert mind.live[0] != 88
  emitCleanSummary(1)

echo "Clean isolation tests passed"
