import
  std/os,
  bassy,
  sim, bots

const
  Submitted = currentSourcePath().parentDir / "../radogost/radogost.bas"
  Candidate = currentSourcePath().parentDir / "../experiments/primordial.bas"

proc fixture(ownCount, enemyCount: int, ready: bool): GameState =
  ## Builds a legal reset decision with explicit readiness and army sizes.
  result = newGame([Mage, Warrior], 42)
  result.currentPlayer = 0
  result.turnNumber = 1
  result.players[0].hand = @[baseCardNamed("Primordial")]
  result.players[0].energy = 8
  result.players[0].totalEnergy = 8
  result.players[1].life = 100
  for i in 0 ..< ownCount:
    result.players[0].board.add MinionState(
      id: i + 1,
      owner: 0,
      card: baseCardNamed("Primordial"),
      currentToughness: 10,
      enteredTurn: 1,
      canAttack: ready
    )
  for i in 0 ..< enemyCount:
    result.players[1].board.add MinionState(
      id: ownCount + i + 1,
      owner: 1,
      card: baseCardNamed("Primordial"),
      currentToughness: 10,
      canAttack: true
    )
  result.nextMinionId = ownCount + enemyCount + 1

proc decide(game: var GameState, path: string, freshCount: int): BotVm =
  ## Runs one policy under production limits with explicit same-turn memory.
  resetInboxes(2)
  result = loadBot(readFile(path), 0)
  result.runtime.setGlobal("savedTurn", game.turnNumber)
  result.runtime.setGlobal("freshPower", freshCount * 10)
  result.runtime.setGlobal("freshCount", freshCount)
  let decision = result.runDecision(game)
  doAssert decision != BotFailed, result.lastError
  doAssert result.runtime.instructionsUsed < 500_000
  doAssert result.runtime.workUsed < 500_000
  echo path.extractFilename, ": work ", result.runtime.workUsed,
    ", instructions ", result.runtime.instructionsUsed,
    ", selected hand ", result.playedHand

echo "Testing defensive Primordial previously rejected by steering"
block:
  var
    original = fixture(1, 3, false)
    changed = original.copyGameState()
  let
    oldVm = decide(original, Submitted, 1)
    newVm = decide(changed, Candidate, 1)
  doAssert oldVm.playedHand == -1
  doAssert original.players[0].board.len == 1
  doAssert original.players[1].board.len == 3
  doAssert newVm.playedHand == 0
  doAssert changed.players[0].board.len == 1
  doAssert changed.players[0].board[0].card.name == "Primordial"
  doAssert changed.players[0].board[0].id == 5
  doAssert not changed.players[0].board[0].canAttack
  doAssert changed.players[0].hand.len == 1
  doAssert changed.players[0].hand[0].name == "Primordial"
  doAssert changed.players[1].board.len == 0
  doAssert changed.players[1].hand.len ==
    original.players[1].hand.len + 3
  doAssert changed.players[0].energy == 0
  doAssert newVm.runtime.getGlobal("rootReady") == 0
  doAssert newVm.runtime.getGlobal("boardReset") == 1

echo "Testing detrimental Primordial is held with a dominant ready army"
block:
  var
    original = fixture(3, 1, true)
    changed = original.copyGameState()
  let
    oldVm = decide(original, Submitted, 0)
    newVm = decide(changed, Candidate, 0)
  doAssert oldVm.playedHand == -1
  doAssert newVm.playedHand == -1
  doAssert changed.players[0].board.len == 3
  doAssert changed.players[1].board.len == 1
  doAssert changed.players[0].hand.len == 1
  doAssert changed.players[0].energy == 8
  doAssert newVm.runtime.getGlobal("rootReady") == 30

echo "Testing a target-heavy wide hand under production VM limits"
block:
  var game = fixture(0, 0, true)
  game.players[0].hand.setLen(0)
  game.players[0].energy = 20
  game.players[0].totalEnergy = 20
  for i in 0 ..< 24:
    game.players[0].hand.add baseCardNamed(
      ["Bouncer", "Oozification", "Primordial", "Plan"][i mod 4]
    )
  for i in 0 ..< 12:
    game.players[0].board.add MinionState(
      id: i + 1,
      owner: 0,
      card: baseCardNamed("Footsoldier"),
      currentToughness: 2,
      canAttack: true
    )
    game.players[1].board.add MinionState(
      id: i + 13,
      owner: 1,
      card: baseCardNamed("Bear"),
      currentToughness: 2,
      canAttack: true
    )
  game.nextMinionId = 25
  let vm = decide(game, Candidate, 0)
  doAssert vm.playedHand >= 0

echo "Primordial gate isolation checks passed"
