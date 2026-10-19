import
  std/os,
  bassy,
  sim, bots

const
  Candidate = currentSourcePath().parentDir / "../experiments/plans.bas"
  Submitted = currentSourcePath().parentDir / "../radogost/radogost.bas"
  Limit = 5_000_000

proc fixture(names: openArray[string], energy: int): GameState =
  ## Creates a real released Mage decision with a deterministic draw pile.
  result = newGame([Mage, Archer, Warrior, Mage], 42)
  result.currentPlayer = 0
  result.turnNumber = 1
  result.players[0].hand.setLen(0)
  result.players[0].deck.setLen(0)
  result.players[0].energy = energy
  result.players[0].totalEnergy = energy
  for player in result.players.mitems:
    player.board.setLen(0)
  for i in 0 ..< 10:
    result.players[0].deck.add baseCardNamed("Bouncer")
  for name in names:
    result.players[0].hand.add baseCardNamed(name)

proc decide(game: var GameState, path = Candidate): BotVm =
  ## Executes one actual host decision and checks both hard budgets.
  resetInboxes(4)
  result = loadBot(readFile(path), 0)
  doAssert not result.failed, result.lastError
  let decision = result.runDecision(game)
  doAssert decision != BotFailed, result.lastError
  doAssert result.runtime.instructionsUsed < Limit
  doAssert result.runtime.workUsed < Limit
  echo "Decision work ", result.runtime.workUsed,
    ", instructions ", result.runtime.instructionsUsed

echo "Testing Plan receives its stronger isolated draw value"
block:
  var before = fixture(["Plan", "Study"], 3)
  var game = before.copyGameState()
  let
    old = decide(before, Submitted)
    vm = decide(game)
  doAssert old.playedHand == 1
  doAssert vm.playedHand == 0
  doAssert game.players[0].deck.len == 9
  doAssert game.players[0].hand.len == 2
  doAssert game.players[0].hand[0].name == "Study"
  doAssert game.players[0].hand[1].name == "Bouncer"
  doAssert game.players[0].board.len == 1
  doAssert game.players[0].board[0].card.name == "Plan"
  for i in 0 ..< 4:
    game.finishTurn()
  doAssert game.currentPlayer == 0
  doAssert game.players[0].deck.len == 7
  doAssert game.players[0].hand.len == 4
  doAssert game.players[0].board.len == 0

echo "Testing Plan remains held near deck exhaustion"
for cards in 0 .. 2:
  var game = fixture(["Plan"], 3)
  game.players[0].deck.setLen(cards)
  let vm = decide(game)
  doAssert vm.playedHand == -1
  doAssert game.players[0].hand.len == 1
  doAssert game.players[0].deck.len == cards

echo "Plan draw-value checks passed"
