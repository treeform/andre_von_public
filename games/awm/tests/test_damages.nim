import
  std/os,
  bassy,
  sim, bots

const
  Submitted = currentSourcePath().parentDir / "../radogost/radogost.bas"
  Candidate = currentSourcePath().parentDir / "../experiments/damages.bas"
  Limit = 5_000_000

type AwmError = object of CatchableError

proc army(
    game: var GameState,
    seat: int,
    name: string,
    count: int
) =
  ## Adds actual prior-turn ready minions without hidden policy queries.
  let card = baseCardNamed(name)
  for i in 0 ..< count:
    game.players[seat].board.add MinionState(
      id: game.nextMinionId,
      owner: seat,
      card: card,
      currentToughness: card.toughness,
      enteredTurn: game.turnNumber - 1,
      canAttack: true
    )
    inc game.nextMinionId

proc fixture(incoming = 4, enemyLife = 20): GameState =
  ## Creates a real public pass before the incoming Archer attacks us.
  result = newGame([Mage, Mage, Warrior, Archer], 42)
  result.currentPlayer = 0
  result.turnNumber = 18
  for player in result.players.mitems:
    player.board.setLen(0)
    player.hand.setLen(0)
    player.life = 20
  result.players[1].life = enemyLife
  result.army(0, "Bouncer", 7)
  result.army(1, "Bouncer", 1)
  result.army(3, "Sharpshooter", incoming)

proc load(game: GameState, path = Candidate): BotVm =
  ## Loads a policy under the frozen release-three five-million limits.
  doAssert botLimits().maxInstructions == Limit
  doAssert botLimits().maxWorkUnits == Limit
  resetInboxes(game.playerCount)
  var source: string
  try:
    source = readFile(path)
  except IOError as error:
    raise newException(AwmError, "Cannot read damage policy: " & error.msg)
  result = loadBot(source, 0)
  doAssert not result.failed, result.lastError

proc decide(vm: BotVm, game: var GameState): BotDecision =
  ## Executes one actual card decision within both deployed VM budgets.
  result = vm.runDecision(game)
  doAssert result != BotFailed, vm.lastError
  doAssert vm.runtime.workUsed < Limit
  doAssert vm.runtime.instructionsUsed < Limit
  echo "Turn ", game.turnNumber, ", life ", game.players[0].life,
    ", targets ", vm.playedChoices, ", work ", vm.runtime.workUsed,
    ", instructions ", vm.runtime.instructionsUsed

proc attackTurn(game: var GameState) =
  ## Applies the host's ready attackers to its fixed next-living hero.
  let
    target = game.nextPlayer(game.currentPlayer)
    attackers = game.eligibleAttackers()
  for id in attackers:
    if game.gameOver:
      break
    doAssert game.attackHero(id, target)
    discard game.takeVisualEvents()

proc cycle(game: var GameState) =
  ## Runs real attack and turn transitions until our next card phase.
  for i in 0 ..< 4:
    game.attackTurn()
    game.finishTurn()
    if game.gameOver or game.dead(0):
      return
  doAssert game.currentPlayer == 0

proc prepare(game: var GameState) =
  ## Sets the controlled next-turn alternatives after actual life loss.
  game.players[0].hand = @[
    baseCardNamed("Primordial"), baseCardNamed("Bouncer")
  ]
  game.players[0].energy = 8
  game.players[0].totalEnergy = 8

echo "Testing observed fatal pressure activates a global reset"
block:
  var game = fixture()
  let vm = game.load()
  doAssert vm.decide(game) == BotEndedTurn
  doAssert vm.runtime.getGlobal("savedPassLife") == 20
  doAssert vm.runtime.getGlobal("savedPassTurn") == 18
  game.cycle()
  doAssert game.players[0].life == 8
  doAssert game.turnNumber == 22
  game.prepare()
  var original = game.copyGameState()
  let oldVm = original.load(Submitted)
  doAssert oldVm.decide(original) == BotPlayedCard
  doAssert original.players[0].hand[0].name == "Primordial"
  doAssert original.players[3].board.len == 3
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.runtime.getGlobal("forcedHand") == 0
  doAssert vm.runtime.getGlobal("rootThreat") == 1
  doAssert vm.runtime.getGlobal("recentDamage") == 0
  doAssert game.players[0].board.len == 1
  doAssert game.players[0].board[0].card.name == "Primordial"
  doAssert game.players[3].board.len == 0
  doAssert vm.decide(game) == BotEndedTurn
  doAssert vm.runtime.getGlobal("savedPassLife") == 8
  original.cycle()
  doAssert original.players[0].dead
  game.cycle()
  doAssert not game.players[0].dead
  doAssert game.players[0].life == 8

echo "Testing ordinary low pressure and ready lethal preserve v2 choices"
for settings in [(1, 20), (4, 11)]:
  var game = fixture(settings[0], settings[1])
  let vm = game.load()
  doAssert vm.decide(game) == BotEndedTurn
  game.cycle()
  game.prepare()
  var original = game.copyGameState()
  let oldVm = original.load(Submitted)
  doAssert oldVm.decide(original) == BotPlayedCard
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.playedHand == oldVm.playedHand
  doAssert vm.playedChoices == oldVm.playedChoices
  doAssert game.players[0].hand[0].name == "Primordial"
  doAssert vm.runtime.getGlobal("forcedHand") == -1

echo "Testing first observation does not invent previous life loss"
block:
  var game = fixture()
  game.players[0].life = 8
  game.prepare()
  let vm = game.load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.runtime.getGlobal("recentDamage") == 0
  doAssert vm.runtime.getGlobal("forcedHand") == -1
  doAssert vm.runtime.getGlobal("savedPassTurn") == 0

echo "Testing observed pressure with a wide real hand and board"
block:
  var game = fixture()
  game.army(2, "Ooze", 36)
  let vm = game.load()
  doAssert vm.decide(game) == BotEndedTurn
  game.cycle()
  game.prepare()
  for i in 0 ..< 22:
    game.players[0].hand.add baseCardNamed("Ooze")
  doAssert game.players[0].hand.len == 24
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.runtime.getGlobal("forcedHand") == 0
  doAssert game.players[0].board.len == 1
  doAssert game.players[0].board[0].card.name == "Primordial"
  doAssert game.players[2].board.len == 0

echo "All recent-damage fixtures passed."
