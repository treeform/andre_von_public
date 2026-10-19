import
  std/os,
  bassy,
  sim, bots

const
  Submitted = currentSourcePath().parentDir / "../radogost/radogost.bas"
  Candidate = currentSourcePath().parentDir / "../experiments/phases.bas"
  Limit = 5_000_000

type AwmError = object of CatchableError

proc fixture(turn = 1): GameState =
  ## Creates three living heroes in the real four-slot host.
  result = newGame([Mage, Mage, Warrior, Archer], 42)
  result.currentPlayer = 0
  result.turnNumber = turn
  for player in result.players.mitems:
    player.board.setLen(0)
    player.life = 100
  result.players[0].hand.setLen(0)
  result.players[3].life = 0
  result.checkWinCondition()

proc hand(game: var GameState, name = "") =
  ## Sets only our real hand and enough energy for the fixture card.
  game.players[0].hand.setLen(0)
  game.players[0].energy = 8
  game.players[0].totalEnergy = 8
  if name.len > 0:
    game.players[0].hand.add baseCardNamed(name)

proc army(game: var GameState, seat: int, name: string): int =
  ## Adds a ready minion using its actual printed statistics.
  let card = baseCardNamed(name)
  result = game.nextMinionId
  game.players[seat].board.add MinionState(
    id: result,
    owner: seat,
    card: card,
    currentToughness: card.toughness,
    enteredTurn: game.turnNumber - 1,
    canAttack: true
  )
  inc game.nextMinionId

proc load(game: GameState, path = Candidate): BotVm =
  ## Loads a policy with the deployed release-three five-million limits.
  doAssert botLimits().maxInstructions == Limit
  doAssert botLimits().maxWorkUnits == Limit
  resetInboxes(game.playerCount)
  var source: string
  try:
    source = readFile(path)
  except IOError as error:
    raise newException(AwmError, "Cannot read phase policy: " & error.msg)
  result = loadBot(source, 0)
  doAssert not result.failed, result.lastError

proc decide(vm: BotVm, game: var GameState): BotDecision =
  ## Executes the actual host card decision and checks both VM budgets.
  result = vm.runDecision(game)
  doAssert result != BotFailed, vm.lastError
  doAssert vm.runtime.instructionsUsed < Limit
  doAssert vm.runtime.workUsed < Limit
  echo "Turn ", game.turnNumber, ", incoming ",
    vm.runtime.getGlobal("incomingPlayer"), ", work ",
    vm.runtime.workUsed, ", instructions ", vm.runtime.instructionsUsed

proc finalPhase(game: var GameState): BotVm =
  ## Observes a real three-player cycle before the two-player transition.
  result = game.load()
  doAssert result.decide(game) == BotEndedTurn
  doAssert result.runtime.getGlobal("duelKnown") == 0
  for i in 0 ..< 3:
    game.finishTurn()
  doAssert game.currentPlayer == 0
  doAssert game.turnNumber == 4
  game.hand()
  doAssert result.decide(game) == BotEndedTurn
  doAssert result.runtime.getGlobal("duelKnown") == 0
  doAssert result.runtime.getGlobal("savedTurn") == 4
  game.players[2].life = 0
  game.checkWinCondition()
  for i in 0 ..< 2:
    game.finishTurn()
  doAssert game.currentPlayer == 0
  doAssert game.turnNumber == 6
  game.hand()
  doAssert result.decide(game) == BotEndedTurn
  doAssert result.runtime.getGlobal("duelKnown") == 1
  doAssert result.runtime.getGlobal("incomingPlayer") == 1

echo "Testing first observation at turn two does not infer a duel"
block:
  var game = fixture(2)
  game.players[2].life = 0
  game.checkWinCondition()
  let vm = game.load()
  doAssert vm.decide(game) == BotEndedTurn
  doAssert vm.runtime.getGlobal("duelKnown") == 0
  doAssert vm.runtime.getGlobal("savedTurn") == 2
  doAssert vm.runtime.getGlobal("incomingPlayer") == 3

echo "Testing three-to-two transition and persistent real Bouncer target"
block:
  var game = fixture()
  let vm = game.finalPhase()
  let
    target = game.army(1, "Primordial")
    deadTarget = game.army(3, "Sniper")
  game.players[1].board[0].bonusPower = -2
  doAssert game.players[1].board[0].power == 8
  game.hand("Bouncer")
  var original = game.copyGameState()
  let oldVm = original.load(Submitted)
  doAssert creatureChoice(1, target) in game.availableChoices(0)
  doAssert creatureChoice(3, deadTarget) in game.availableChoices(0)
  doAssert oldVm.decide(original) == BotPlayedCard
  doAssert oldVm.playedChoices == @[creatureChoice(3, deadTarget)]
  doAssert original.minionLocation(target).found
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.playedChoices == @[creatureChoice(1, target)]
  doAssert not game.minionLocation(target).found
  doAssert game.minionLocation(deadTarget).found
  doAssert game.players[1].hand[^1].name == "Primordial"
  doAssert vm.decide(game) == BotEndedTurn
  doAssert vm.runtime.getGlobal("duelKnown") == 1
  doAssert vm.runtime.getGlobal("incomingPlayer") == 1

echo "Testing Tactician uses the same living incoming target"
block:
  var game = fixture()
  let vm = game.finalPhase()
  let
    target = game.army(1, "Primordial")
    deadTarget = game.army(3, "Sniper")
  game.players[1].board[0].bonusPower = -2
  game.hand("Tactician")
  var original = game.copyGameState()
  let oldVm = original.load(Submitted)
  doAssert oldVm.decide(original) == BotPlayedCard
  doAssert oldVm.playedChoices == @[creatureChoice(3, deadTarget)]
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.playedChoices == @[creatureChoice(1, target)]
  doAssert game.players[1].board[0].power == 7
  doAssert game.players[3].board[0].power == 2

echo "All phase fixtures passed."
