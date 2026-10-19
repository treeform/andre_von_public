import
  std/os,
  bassy,
  sim, bots

const
  Submitted = currentSourcePath().parentDir / "../radogost/radogost.bas"
  Candidate = currentSourcePath().parentDir / "../experiments/bubbles.bas"

proc fixture(life: int): GameState =
  ## Creates a Mage decision facing an attacking Bear.
  result = newGame([Mage, Warrior], 42)
  result.currentPlayer = 0
  result.turnNumber = 1
  result.players[0].hand = @[baseCardNamed("Bubble Shield")]
  result.players[0].energy = 2
  result.players[0].totalEnergy = 2
  result.players[0].life = life
  result.players[0].board.setLen(0)
  result.players[1].board = @[MinionState(
    id: 1,
    owner: 1,
    card: baseCardNamed("Bear"),
    currentToughness: 2,
    canAttack: true
  )]
  result.nextMinionId = 2

proc decide(game: var GameState, path: string): BotVm =
  ## Executes a real host decision and rejects policy failures.
  resetInboxes(game.playerCount)
  result = loadBot(readFile(path), 0)
  doAssert not result.failed, result.lastError
  result.runtime.setGlobal("heroClass", 3)
  doAssert result.runDecision(game) != BotFailed, result.lastError
  doAssert result.runtime.workUsed < botLimits().maxWorkUnits
  doAssert result.runtime.instructionsUsed < botLimits().maxInstructions
  echo "Work ", result.runtime.workUsed, ", instructions ",
    result.runtime.instructionsUsed

echo "Testing Shield retains its existing utility and loses defense credit"
for life in [3, 20]:
  var
    original = fixture(life)
    changed = original.copyGameState()
  let
    oldVm = original.decide(Submitted)
    newVm = changed.decide(Candidate)
  doAssert oldVm.playedHand == 0
  doAssert newVm.playedHand == 0
  doAssert oldVm.runtime.getArray("kinds", 0) == 11
  doAssert newVm.runtime.getArray("kinds", 0) == 11
  doAssert oldVm.runtime.getGlobalValue("utility") ==
    newVm.runtime.getGlobalValue("utility")
  doAssert oldVm.runtime.getGlobal("defense") == 1
  doAssert newVm.runtime.getGlobal("defense") == 0
  doAssert changed.players[0].board.len == 2
  doAssert changed.players[0].life == life
  changed.finishTurn()
  doAssert changed.currentPlayer == 1
  doAssert changed.attack(1, heroChoice(0))
  doAssert changed.players[0].life == life - 3
  if life == 3:
    doAssert changed.gameOver
    doAssert changed.winner == 1
  else:
    doAssert not changed.minionLocation(1).found
    doAssert changed.players[1].hand[^1].name == "Bear"

echo "Testing Study shares Shield's observable classification"
block:
  var game = fixture(20)
  game.players[0].hand = @[baseCardNamed("Study")]
  let vm = game.decide(Candidate)
  doAssert vm.playedHand == 0
  doAssert vm.runtime.getArray("kinds", 0) == 11
  doAssert vm.runtime.getGlobal("defense") == 0

echo "Bubble Shield isolation checks passed"
