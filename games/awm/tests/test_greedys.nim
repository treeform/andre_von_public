import
  std/os,
  bassy,
  sim, bots

const
  Candidate = currentSourcePath().parentDir / "../experiments/greedy.bas"
  Submitted = currentSourcePath().parentDir / "../radogost/radogost.bas"
  Limit = 5_000_000

proc fixture(heroClass: HeroClass, names: openArray[string],
    energy: int): GameState =
  ## Creates a deterministic released host decision with an empty board.
  result = newGame([heroClass, Archer, Warrior, Mage], 42)
  result.currentPlayer = 0
  result.turnNumber = 1
  result.players[0].hand.setLen(0)
  result.players[0].energy = energy
  result.players[0].totalEnergy = energy
  for player in result.players.mitems:
    player.board.setLen(0)
  for name in names:
    result.players[0].hand.add baseCardNamed(name)

proc decide(game: var GameState, path = Candidate): BotVm =
  ## Executes a real decision and checks both released hard VM limits.
  resetInboxes(4)
  result = loadBot(readFile(path), 0)
  doAssert not result.failed, result.lastError
  doAssert result.runDecision(game) != BotFailed, result.lastError
  doAssert result.runtime.instructionsUsed < Limit
  doAssert result.runtime.workUsed < Limit
  echo "Decision work ", result.runtime.workUsed,
    ", instructions ", result.runtime.instructionsUsed

echo "Testing steering chooses Commander instead of an MCTS sequence"
block:
  var before = fixture(Warrior,
    ["Commander", "Swords", "Footsoldier", "Bear"], 5)
  var game = before.copyGameState()
  let
    old = before.decide(Submitted)
    vm = game.decide()
  doAssert old.playedHand in [2, 3]
  doAssert vm.playedHand == 0
  doAssert vm.runtime.getGlobal("nodes") == 0
  doAssert vm.runtime.workUsed < old.runtime.workUsed

echo "Testing forced immediate lethal and free protection are retained"
block:
  var game = fixture(Archer, ["Sniper", "Bolt"], 2)
  game.players[1].life = 2
  let vm = game.decide()
  doAssert vm.playedHand == 1
  doAssert game.players[1].dead
  doAssert vm.runtime.getGlobal("forcedHand") == 1
block:
  var game = fixture(Mage, ["Plan", "Bubble"], 3)
  game.players[0].deck.setLen(0)
  let vm = game.decide()
  doAssert vm.playedHand == 1
  doAssert vm.runtime.getGlobal("forcedHand") == 1

echo "Testing empty buffs remain pruned"
block:
  var game = fixture(Warrior, ["Swords", "Shields"], 3)
  let vm = game.decide()
  doAssert vm.playedHand == -1
  doAssert game.players[0].hand.len == 2

echo "Testing visible bounce target selection is retained"
block:
  var game = fixture(Mage, ["Bouncer", "Plan"], 3)
  game.players[1].board = @[
    MinionState(id: 1, owner: 1, card: baseCardNamed("Sniper"),
      currentToughness: 1),
    MinionState(id: 2, owner: 1, card: baseCardNamed("Primordial"),
      currentToughness: 10)
  ]
  game.nextMinionId = 3
  let vm = game.decide()
  doAssert vm.playedHand == 0
  doAssert vm.playedChoices[0].creatureId == 2
  doAssert game.players[1].board.len == 1

echo "Greedy steering checks passed"
