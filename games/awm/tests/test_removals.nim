import
  std/os,
  bassy,
  sim, bots

const
  Submitted = currentSourcePath().parentDir / "../radogost/radogost.bas"
  Candidate = currentSourcePath().parentDir / "../experiments/removals.bas"
  Limit = 5_000_000

type AwmError = object of CatchableError

proc fixture(name = "Primordial", enemyLife = 20): GameState =
  ## Creates competing bounce and permanent removal against a visible foe.
  result = newGame([Mage, Mage, Warrior, Archer], 42)
  result.currentPlayer = 0
  result.turnNumber = 18
  for player in result.players.mitems:
    player.board.setLen(0)
    player.hand.setLen(0)
    player.life = 20
  result.players[1].life = enemyLife
  result.players[0].hand = @[
    baseCardNamed("Bouncer"), baseCardNamed("Oozification")
  ]
  result.players[0].energy = 4
  result.players[0].totalEnergy = 4
  for seat in 0 .. 1:
    let card = baseCardNamed(if seat == 0: "Bouncer" else: name)
    for i in 0 ..< (if seat == 0: 3 else: 1):
      result.players[seat].board.add MinionState(
        id: result.nextMinionId,
        owner: seat,
        card: card,
        currentToughness: card.toughness,
        enteredTurn: result.turnNumber - 1,
        canAttack: true
      )
      inc result.nextMinionId

proc load(game: GameState, path = Candidate): BotVm =
  ## Loads the frozen release-three host with five-million VM limits.
  doAssert botLimits().maxInstructions == Limit
  doAssert botLimits().maxWorkUnits == Limit
  resetInboxes(game.playerCount)
  var source: string
  try:
    source = readFile(path)
  except IOError as error:
    raise newException(AwmError, "Cannot read removal policy: " & error.msg)
  result = loadBot(source, 0)
  doAssert not result.failed, result.lastError

proc decide(vm: BotVm, game: var GameState): BotDecision =
  ## Runs an actual card decision and checks both deployed budgets.
  result = vm.runDecision(game)
  doAssert result != BotFailed, vm.lastError
  doAssert vm.runtime.instructionsUsed < Limit
  doAssert vm.runtime.workUsed < Limit
  echo "Targets ", vm.playedChoices, ", work ", vm.runtime.workUsed,
    ", instructions ", vm.runtime.instructionsUsed

echo "Testing permanent removal interrupts the opponent's Prime reset loop"
block:
  var game = fixture()
  var original = game.copyGameState()
  let
    oldVm = original.load(Submitted)
    newVm = game.load()
  doAssert oldVm.decide(original) == BotPlayedCard
  doAssert original.players[0].hand[0].name == "Oozification"
  doAssert original.players[1].hand[0].name == "Primordial"
  doAssert original.players[0].board.len == 4
  doAssert newVm.decide(game) == BotPlayedCard
  doAssert newVm.runtime.getGlobal("forcedHand") == 1
  doAssert game.players[0].hand[0].name == "Bouncer"
  doAssert game.players[1].hand.len == 0
  doAssert game.players[1].board.len == 10
  for minion in game.players[1].board:
    doAssert minion.card.name == "Ooze"
    doAssert minion.power == 0
  doAssert game.players[0].board.len == 3
  original.currentPlayer = 1
  original.players[1].energy = 8
  doAssert original.playCard(0)
  doAssert original.players[0].board.len == 0
  doAssert original.players[1].board[0].card.name == "Primordial"
  doAssert game.players[0].board.len == 3

echo "Testing ordinary bounce and ready lethal choices remain unchanged"
for settings in [("Bear", 20), ("Primordial", 3)]:
  var game = fixture(settings[0], settings[1])
  var original = game.copyGameState()
  let
    oldVm = original.load(Submitted)
    newVm = game.load()
  doAssert oldVm.decide(original) == BotPlayedCard
  doAssert newVm.decide(game) == BotPlayedCard
  doAssert newVm.playedHand == oldVm.playedHand
  doAssert newVm.playedChoices == oldVm.playedChoices
  doAssert newVm.runtime.getGlobal("forcedHand") == -1

echo "Testing permanent removal needs a competing affordable bounce"
block:
  var game = fixture()
  game.players[0].hand.delete(0)
  let vm = game.load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.runtime.getGlobal("forcedHand") == -1
  doAssert game.players[1].board.len == 10

echo "All permanent-removal fixtures passed."
