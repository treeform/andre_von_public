import
  std/os,
  bassy,
  sim, bots

const
  Submitted = currentSourcePath().parentDir / "../radogost/radogost.bas"
  Candidate = currentSourcePath().parentDir / "../experiments/fighters.bas"
  Limit = 5_000_000

type AwmError = object of CatchableError

proc fixture(): GameState =
  ## Creates a real Warrior Duel hand with one visible enemy board.
  result = newGame([Warrior, Warrior, Mage, Archer], 42)
  result.currentPlayer = 0
  result.turnNumber = 18
  for player in result.players.mitems:
    player.board.setLen(0)
    player.life = 100
  result.players[0].hand = @[baseCardNamed("Duel")]
  result.players[0].energy = 2
  result.players[0].totalEnergy = 2

proc army(
    game: var GameState,
    seat: int,
    name: string,
    health: int
): int =
  ## Adds a ready fighter with legal damage or prior Shields applied.
  let card = baseCardNamed(name)
  result = game.nextMinionId
  game.players[seat].board.add MinionState(
    id: result,
    owner: seat,
    card: card,
    currentToughness: health,
    enteredTurn: game.turnNumber - 1,
    canAttack: true
  )
  inc game.nextMinionId

proc load(game: GameState, path = Candidate): BotVm =
  ## Loads the policy with the frozen release-three five-million limits.
  doAssert botLimits().maxInstructions == Limit
  doAssert botLimits().maxWorkUnits == Limit
  resetInboxes(game.playerCount)
  var source: string
  try:
    source = readFile(path)
  except IOError as error:
    raise newException(AwmError, "Cannot read fighter policy: " & error.msg)
  result = loadBot(source, 0)
  doAssert not result.failed, result.lastError

proc decide(vm: BotVm, game: var GameState): BotDecision =
  ## Runs the actual host card decision and checks both deployed budgets.
  result = vm.runDecision(game)
  doAssert result != BotFailed, vm.lastError
  doAssert vm.runtime.instructionsUsed < Limit
  doAssert vm.runtime.workUsed < Limit
  echo "Targets ", vm.playedChoices, ", work ", vm.runtime.workUsed,
    ", instructions ", vm.runtime.instructionsUsed

echo "Testing a weaker healthy fighter unlocks a safe Duel"
block:
  var game = fixture()
  let
    wounded = game.army(0, "Bear", 1)
    survivor = game.army(0, "Footsoldier", 4)
    target = game.army(1, "Bear", 2)
  var original = game.copyGameState()
  let
    oldVm = original.load(Submitted)
    newVm = game.load()
  doAssert creatureChoice(0, survivor) in game.availableChoices(0)
  doAssert creatureChoice(1, target) in game.availableChoices(
    0, @[creatureChoice(0, survivor)]
  )
  doAssert oldVm.decide(original) == BotEndedTurn
  doAssert original.players[0].hand.len == 1
  doAssert original.minionLocation(target).found
  doAssert newVm.decide(game) == BotPlayedCard
  doAssert newVm.playedChoices == @[
    creatureChoice(0, survivor), creatureChoice(1, target)
  ]
  doAssert game.minionLocation(wounded).found
  doAssert not game.minionLocation(target).found
  doAssert game.players[0].board[1].power == 2
  doAssert game.players[0].board[1].currentToughness == 2
  doAssert game.players[0].board[1].canAttack
  doAssert game.players[0].energy == 0

echo "Testing the stronger safe fighter remains preferred"
block:
  var game = fixture()
  let
    strongest = game.army(0, "Bear", 4)
    weaker = game.army(0, "Footsoldier", 4)
    target = game.army(1, "Bear", 2)
  var original = game.copyGameState()
  let
    oldVm = original.load(Submitted)
    newVm = game.load()
  doAssert oldVm.decide(original) == BotPlayedCard
  doAssert newVm.decide(game) == BotPlayedCard
  doAssert newVm.playedChoices == oldVm.playedChoices
  doAssert newVm.playedChoices == @[
    creatureChoice(0, strongest), creatureChoice(1, target)
  ]
  doAssert game.minionLocation(weaker).found
  doAssert not game.minionLocation(target).found

echo "Testing a fight without a surviving own fighter stays pruned"
block:
  var game = fixture()
  discard game.army(0, "Bear", 1)
  discard game.army(0, "Footsoldier", 2)
  let target = game.army(1, "Bear", 2)
  let vm = game.load()
  doAssert vm.decide(game) == BotEndedTurn
  doAssert game.players[0].hand.len == 1
  doAssert game.minionLocation(target).found

echo "Testing the Duel safety scan is cached across a wide real hand"
block:
  var game = fixture()
  game.players[0].hand.setLen(0)
  game.players[0].energy = 48
  game.players[0].totalEnergy = 48
  for i in 0 ..< 24:
    game.players[0].hand.add baseCardNamed("Duel")
    discard game.army(0, "Footsoldier", 4)
    discard game.army(1, "Bear", 2)
  let vm = game.load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert game.players[0].hand.len == 23
  doAssert game.players[1].board.len == 23
  doAssert vm.runtime.getGlobal("fightersCached") == 1
  doAssert vm.decide(game) == BotPlayedCard
  doAssert game.players[1].board.len == 22

echo "All fighter fixtures passed."
