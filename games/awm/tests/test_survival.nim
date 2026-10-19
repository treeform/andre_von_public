import
  std/os,
  bassy,
  sim, bots

const
  Submitted = currentSourcePath().parentDir / "../radogost/radogost.bas"
  Candidate = currentSourcePath().parentDir / "../experiments/survival.bas"
  Limit = 5_000_000

type AwmError = object of CatchableError

proc fixture(players = 4): GameState =
  ## Creates an empty host card phase before observing the final duel.
  var classes: seq[HeroClass]
  for i in 0 ..< players:
    classes.add Warrior
  result = newGame(classes, 42)
  result.currentPlayer = 0
  result.turnNumber = 1
  for player in result.players.mitems:
    player.board.setLen(0)
    player.hand.setLen(0)
    player.life = 100
  if players == 4:
    result.players[3].life = 0
    result.checkWinCondition()

proc load(game: GameState, path = Candidate): BotVm =
  ## Loads a policy under the frozen release-three five-million limits.
  doAssert botLimits().maxInstructions == Limit
  doAssert botLimits().maxWorkUnits == Limit
  resetInboxes(game.playerCount)
  var source: string
  try:
    source = readFile(path)
  except IOError as error:
    raise newException(AwmError, "Cannot read survival policy: " & error.msg)
  result = loadBot(source, 0)
  doAssert not result.failed, result.lastError

proc decide(vm: BotVm, game: var GameState): BotDecision =
  ## Runs one real card decision and checks both deployed VM budgets.
  result = vm.runDecision(game)
  doAssert result != BotFailed, vm.lastError
  doAssert vm.runtime.workUsed < Limit
  doAssert vm.runtime.instructionsUsed < Limit
  echo "Work ", vm.runtime.workUsed, ", instructions ",
    vm.runtime.instructionsUsed, ", targets ", vm.playedChoices

proc finalPhase(game: var GameState): BotVm =
  ## Confirms a two-turn gap after an earlier three-living-player cycle.
  result = game.load()
  doAssert result.decide(game) == BotEndedTurn
  doAssert result.runtime.getGlobal("duelKnown") == 0
  for i in 0 ..< 3:
    game.finishTurn()
  game.players[0].hand.setLen(0)
  doAssert game.currentPlayer == 0
  doAssert result.decide(game) == BotEndedTurn
  doAssert result.runtime.getGlobal("duelKnown") == 0
  game.players[2].life = 0
  game.checkWinCondition()
  for i in 0 ..< 2:
    game.finishTurn()
  game.players[0].hand.setLen(0)
  doAssert game.currentPlayer == 0
  doAssert result.decide(game) == BotEndedTurn
  doAssert result.runtime.getGlobal("duelKnown") == 1
  doAssert result.runtime.getGlobal("incomingPlayer") == 3

proc tactical(game: var GameState, enemyLife = 100) =
  ## Adds a fatal Bear and a Shielded army with competing two-cost cards.
  game.players[0].life = 3
  game.players[1].life = enemyLife
  game.players[0].hand = @[
    baseCardNamed("Swords"), baseCardNamed("Duel")
  ]
  game.players[0].energy = 2
  game.players[0].totalEnergy = 2
  for seat in 0 .. 1:
    let card = baseCardNamed(if seat == 0: "Footsoldier" else: "Bear")
    for i in 0 ..< (if seat == 0: 3 else: 1):
      game.players[seat].board.add MinionState(
        id: game.nextMinionId,
        owner: seat,
        card: card,
        currentToughness: if seat == 0: 3 else: 2,
        enteredTurn: game.turnNumber - 1,
        canAttack: true
      )
      inc game.nextMinionId

proc attackTurn(game: var GameState) =
  ## Applies every actual ready attack to the next living hero.
  let
    enemy = game.nextPlayer(game.currentPlayer)
    attackers = game.eligibleAttackers()
  for id in attackers:
    doAssert game.attackHero(id, enemy)
    discard game.takeVisualEvents()

echo "Testing the confirmed final-duel gate avoids a fatal incoming Bear"
block:
  var game = fixture()
  let vm = game.finalPhase()
  game.tactical()
  var original = game.copyGameState()
  let oldVm = original.load(Submitted)
  doAssert oldVm.decide(original) == BotPlayedCard
  doAssert original.players[0].hand[0].name == "Duel"
  doAssert oldVm.playedChoices == @[NoTarget]
  doAssert original.players[1].board.len == 1
  doAssert vm.decide(game) == BotPlayedCard
  doAssert game.players[0].hand[0].name == "Swords"
  doAssert vm.playedChoices.len == 2
  doAssert game.players[1].board.len == 0
  doAssert game.players[0].board[0].power == 2
  doAssert game.players[0].board[0].currentToughness == 1
  doAssert vm.runtime.getGlobal("incomingPlayer") == 3
  original.finishTurn()
  original.attackTurn()
  doAssert original.players[0].dead
  game.finishTurn()
  game.attackTurn()
  doAssert not game.players[0].dead
  doAssert game.players[0].life == 3

echo "Testing the original two-slot fatal gate still chooses the same Duel"
block:
  var game = fixture(2)
  game.tactical()
  var original = game.copyGameState()
  let
    oldVm = original.load(Submitted)
    newVm = game.load()
  doAssert oldVm.decide(original) == BotPlayedCard
  doAssert newVm.decide(game) == BotPlayedCard
  doAssert game.players[0].hand[0].name == "Swords"
  doAssert newVm.playedChoices == oldVm.playedChoices
  doAssert newVm.runtime.getGlobal("duelKnown") == 0

echo "Testing an immediate Swords lethal remains preferred"
block:
  var game = fixture()
  let vm = game.finalPhase()
  game.tactical(5)
  doAssert vm.decide(game) == BotPlayedCard
  doAssert game.players[0].hand[0].name == "Duel"
  doAssert vm.playedChoices == @[NoTarget]
  game.attackTurn()
  doAssert game.players[1].dead
  doAssert game.gameOver
  doAssert game.winner == 0

echo "All survival fixtures passed."
