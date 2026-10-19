import
  std/os,
  bassy,
  sim, bots

const
  Candidate = currentSourcePath().parentDir / "../experiments/oozes.bas"
  Submitted = currentSourcePath().parentDir / "../radogost/radogost.bas"
  Limit = 500_000

proc fixture(names: openArray[string], energy: int): GameState =
  ## Creates an actual four-seat Mage host decision with an empty next seat.
  result = newGame([Mage, Archer, Warrior, Warrior], 42)
  result.currentPlayer = 0
  result.turnNumber = 1
  result.players[0].hand.setLen(0)
  result.players[0].energy = energy
  result.players[0].totalEnergy = energy
  result.players[0].life = 3
  for player in result.players.mitems:
    player.board.setLen(0)
  for name in names:
    result.players[0].hand.add baseCardNamed(name)

proc army(game: var GameState, seat, count: int, name = "Bear") =
  ## Adds public minions whose real destruction and tokens can be checked.
  for i in 0 ..< count:
    let card = baseCardNamed(name)
    game.players[seat].board.add MinionState(
      id: game.nextMinionId,
      owner: seat,
      card: card,
      currentToughness: card.toughness
    )
    inc game.nextMinionId

proc power(game: GameState, seat: int): int =
  ## Sums actual attack power without estimating hidden toughness.
  for minion in game.players[seat].board:
    result += minion.power

proc load(path = Candidate): BotVm =
  ## Compiles one policy under the actual released BASIC host.
  resetInboxes(4)
  result = loadBot(readFile(path), 0)
  doAssert not result.failed, result.lastError

proc decide(vm: BotVm, game: var GameState): BotDecision =
  ## Runs one real decision with both hard host budget checks.
  result = vm.runDecision(game)
  doAssert result != BotFailed, vm.lastError
  doAssert vm.runtime.instructionsUsed < Limit
  doAssert vm.runtime.workUsed < Limit
  echo "Decision work ", vm.runtime.workUsed,
    ", instructions ", vm.runtime.instructionsUsed

echo "Testing incoming Oozification destroys real threats held by v2"
for name in ["Bear", "Primordial"]:
  var before = fixture(["Oozification"], 4)
  before.army(3, 3, name)
  var game = before.copyGameState()
  let old = load(Submitted)
  doAssert old.decide(before) == BotEndedTurn
  let
    vm = load()
    threat = game.power(3)
    victim = game.players[3].board[^1]
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.playedChoices[0].owner == 3
  doAssert vm.playedChoices[0].creatureId == victim.id
  doAssert game.power(3) == threat - victim.power
  doAssert game.players[3].discardPile.len == 1
  var tokens = 0
  for minion in game.players[3].board:
    if minion.card.name == "Ooze":
      inc tokens
      doAssert minion.power == 0
  doAssert tokens == victim.currentToughness
  doAssert vm.runtime.getGlobal("stateThreat") == 0
  doAssert vm.runtime.getGlobal("defense") == 2
  doAssert vm.runtime.getArray("targetHealths", 0) == 0

echo "Testing two root Oozifications cannot destroy the same hidden key"
block:
  var game = fixture(["Oozification", "Oozification"], 8)
  game.army(3, 1)
  let vm = load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.runtime.getGlobal("nodes") == 2
  doAssert vm.runtime.getGlobalValue("bestScore").asFixed < 0.41'fx
  doAssert vm.decide(game) == BotEndedTurn
  doAssert game.players[0].hand.len == 1
  doAssert game.power(3) == 0
  doAssert vm.runtime.getGlobal("oozePrefix") == 0

echo "Testing actual replanning destroys distinct incoming original minions"
block:
  var game = fixture(["Oozification", "Oozification"], 8)
  game.army(3, 2)
  let vm = load()
  doAssert vm.decide(game) == BotPlayedCard
  let first = vm.playedChoices[0].creatureId
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.playedChoices[0].creatureId != first
  doAssert game.players[3].discardPile.len == 2
  doAssert game.players[3].board.len == 4
  doAssert game.power(3) == 0

echo "Testing known generated zero-power suffix is held within our turn"
block:
  var game = fixture([
    "Oozification", "Oozification", "Oozification"
  ], 12)
  game.army(3, 2)
  let vm = load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.decide(game) == BotEndedTurn
  doAssert game.players[0].hand.len == 1
  doAssert game.players[0].energy == 4
  doAssert game.players[3].discardPile.len == 2
  doAssert vm.runtime.getGlobal("oozePrefixValid") == 1
  doAssert vm.runtime.getGlobal("oozePrefix") == 0

echo "Testing Bouncer and Oozification share stable minion ordinals"
block:
  var game = fixture(["Bouncer", "Oozification"], 5)
  game.army(0, 2, "Bouncer")
  game.army(1, 2, "Sniper")
  game.army(3, 3)
  let
    bounce = game.availableChoices(0)
    destroy = game.availableChoices(1)
  doAssert bounce.len == destroy.len + 1
  for i in 0 ..< destroy.len:
    doAssert bounce[i] == destroy[i]
  doAssert bounce[^1].isNoTarget

echo "Testing Bouncer removal blocks stale root Oozification credit"
block:
  var game = fixture(["Bouncer", "Oozification"], 5)
  game.army(3, 1)
  let vm = load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.runtime.getGlobal("nodes") == 3
  doAssert vm.runtime.getGlobalValue("bestScore").asFixed < 0.68'fx

echo "Testing Bouncer-only search keeps the submitted policy values"
block:
  var before = fixture(["Bouncer", "Bouncer"], 2)
  before.army(3, 1)
  var game = before.copyGameState()
  let
    old = load(Submitted)
    vm = load()
  doAssert old.decide(before) == BotPlayedCard
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.runtime.getGlobal("trackHidden") == 0
  doAssert vm.runtime.getGlobalValue("bestScore").asFixed ==
    old.runtime.getGlobalValue("bestScore").asFixed
  doAssert vm.playedChoices == old.playedChoices

echo "Testing Bouncer does not erase the remembered zero-power suffix"
block:
  var game = fixture([
    "Oozification", "Bouncer", "Oozification"
  ], 9)
  game.army(3, 1)
  let vm = load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert game.players[3].discardPile.len == 1
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.decide(game) == BotEndedTurn
  doAssert game.players[0].hand.len == 1
  doAssert game.players[0].hand[0].name == "Oozification"
  doAssert game.power(3) == 0
  doAssert vm.runtime.getGlobal("oozePrefix") == 0

echo "Testing known zero-power next minions and empty boards stay pruned"
for count in [0, 2]:
  var game = fixture(["Oozification"], 4)
  game.army(1, count, "Ooze")
  let vm = load()
  doAssert vm.decide(game) == BotEndedTurn
  doAssert game.players[0].hand.len == 1

echo "Testing token certainty expires before the incoming player's next turn"
block:
  var game = fixture(["Oozification", "Oozification"], 8)
  game.army(3, 1)
  let vm = load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.decide(game) == BotEndedTurn
  game.turnNumber += 4
  game.players[0].energy = 4
  for minion in game.players[3].board.mitems:
    minion.bonusPower = 1
  doAssert vm.decide(game) == BotPlayedCard

echo "Testing observed final duel rejects the original dead predecessor"
block:
  var game = fixture(["Oozification"], 4)
  game.turnNumber = 8
  game.players[0].energy = 0
  game.players[2].life = 0
  game.players[3].life = 0
  game.army(3, 3)
  game.checkWinCondition()
  doAssert game.players[2].dead and game.players[3].dead
  let vm = load()
  doAssert vm.decide(game) == BotEndedTurn
  doAssert vm.runtime.getGlobal("oozeDuelKnown") == 0
  game.finishTurn()
  game.finishTurn()
  doAssert game.currentPlayer == 0
  doAssert game.turnNumber == 10
  doAssert game.players[0].energy >= 4
  game.players[0].hand = @[baseCardNamed("Oozification")]
  doAssert vm.decide(game) == BotEndedTurn
  doAssert vm.runtime.getGlobal("oozeDuelKnown") == 1
  doAssert game.players[3].board.len == 3
  doAssert game.players[0].hand.len == 1
  game.turnNumber += 2
  doAssert vm.decide(game) == BotEndedTurn
  doAssert vm.runtime.getGlobal("oozeDuelKnown") == 1

echo "Testing first invocation on turn two does not infer a final duel"
block:
  var game = fixture(["Oozification"], 4)
  game.turnNumber = 2
  game.army(3, 1)
  let vm = load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.runtime.getGlobal("oozeDuelKnown") == 0

echo "Testing wide Mage targeting under both hard VM limits"
block:
  var game = fixture([], 20)
  for player in game.players.mitems:
    player.life = 100
  for i in 0 ..< 24:
    game.players[0].hand.add baseCardNamed(
      ["Bouncer", "Oozification", "Primordial", "Plan"][i mod 4]
    )
  game.army(0, 12, "Bouncer")
  game.army(1, 12)
  game.army(2, 12)
  game.army(3, 12)
  let vm = load()
  doAssert vm.decide(game) == BotPlayedCard

echo "Incoming Oozification checks passed"
