import
  std/os,
  bassy,
  sim, bots

const Policy = currentSourcePath().parentDir / "../radogost/radogost.bas"

proc fixture(heroClass: HeroClass, names: openArray[string],
    energy: int): GameState =
  ## Creates a deterministic legal decision with the supplied hand.
  result = newGame([heroClass, Archer], 42)
  result.currentPlayer = 0
  result.turnNumber = 1
  result.players[0].hand.setLen(0)
  result.players[0].energy = energy
  result.players[0].totalEnergy = energy
  for name in names:
    result.players[0].hand.add baseCardNamed(name)

proc decide(game: var GameState): BotVm =
  ## Executes the production policy under the real host's VM limits.
  resetInboxes(2)
  result = loadBot(readFile(Policy), 0)
  let decision = result.runDecision(game)
  doAssert decision != BotFailed, result.lastError
  doAssert result.runtime.instructionsUsed < 500_000
  doAssert result.runtime.workUsed < 500_000
  echo "Decision work ", result.runtime.workUsed, ", estimate ",
    result.runtime.getGlobal("budgetUsed")

echo "Testing minions before empty buffs"
block:
  var game = fixture(Warrior, ["Swords", "Bear"], 4)
  let vm = decide(game)
  doAssert vm.playedHand == 1
  doAssert game.players[0].board[0].power == 3
  doAssert vm.runDecision(game) == BotPlayedCard
  doAssert game.players[0].board[0].power == 4

echo "Testing harmful empty buffs are held"
block:
  var game = fixture(Warrior, ["Swords", "Shields"], 3)
  let vm = decide(game)
  doAssert vm.playedHand == -1
  doAssert game.players[0].hand.len == 2

echo "Testing bounce targets the strongest visible enemy"
block:
  var game = fixture(Mage, ["Bouncer"], 1)
  game.players[1].board = @[
    MinionState(id: 1, owner: 1, card: baseCardNamed("Sniper"),
      currentToughness: 1),
    MinionState(id: 2, owner: 1, card: baseCardNamed("Primordial"),
      currentToughness: 10)
  ]
  game.nextMinionId = 3
  let vm = decide(game)
  doAssert vm.playedChoices[0].creatureId == 2
  doAssert game.players[1].board.len == 1

echo "Testing draw cards are held near deck exhaustion"
block:
  var game = fixture(Mage, ["Plan"], 3)
  game.players[0].deck.setLen(1)
  let vm = decide(game)
  doAssert vm.playedHand == -1

echo "Testing an immediate lethal Bolt"
block:
  var game = fixture(Archer, ["Sniper", "Bolt"], 2)
  game.players[1].life = 2
  let vm = decide(game)
  doAssert vm.playedHand == 1
  doAssert game.gameOver and game.winner == 0
  doAssert vm.runtime.getGlobal("forcedHand") == 1
  doAssert vm.runtime.getGlobal("nodes") == 0

echo "Testing free protective cards bypass search even at an empty deck"
block:
  var game = fixture(Mage, ["Plan", "Bubble"], 3)
  game.players[0].deck.setLen(0)
  let vm = decide(game)
  doAssert vm.playedHand == 1
  doAssert vm.runtime.getGlobal("forcedHand") == 1
  doAssert vm.runtime.getGlobal("nodes") == 0

echo "Testing weighted expansion spends little on weak moves"
block:
  var game = fixture(Warrior, ["Shields", "Bear"], 2)
  game.players[0].board = @[
    MinionState(id: 1, owner: 0, card: baseCardNamed("Footsoldier"),
      currentToughness: 2)
  ]
  game.nextMinionId = 2
  let vm = decide(game)
  doAssert vm.playedHand == 1
  doAssert vm.runtime.getArray("rootSamples", 1) >
    vm.runtime.getArray("rootSamples", 0) * 3

echo "Testing branching search finds a productive mana sequence"
block:
  var game = fixture(Warrior,
    ["Commander", "Swords", "Footsoldier", "Bear"], 5)
  let vm = decide(game)
  doAssert vm.runtime.getGlobal("nodes") > 1
  doAssert vm.playedHand in [2, 3]
  doAssert vm.runDecision(game) == BotPlayedCard
  doAssert vm.runDecision(game) == BotPlayedCard
  doAssert game.players[0].board.len == 2
  doAssert game.players[0].board[0].power +
    game.players[0].board[1].power == 6

echo "Testing a wide late-game hand stays within the VM budget"
block:
  var game = fixture(Warrior, [], 20)
  for i in 0 ..< 24:
    game.players[0].hand.add baseCardNamed(
      ["Bear", "Swords", "Commander", "Rally"][i mod 4])
  let vm = decide(game)
  doAssert vm.playedHand >= 0
  echo "Peak fixture work: ", vm.runtime.workUsed
  echo "Estimated fixture work: ", vm.runtime.getGlobal("budgetUsed")
  echo "Simulations: ", vm.runtime.getGlobal("iterations")
  doAssert vm.runtime.workUsed > 375_000


echo "Testing target-heavy wide hands under the VM budget"
for heroClass in [Archer, Mage, Warrior]:
  var game = fixture(heroClass, [], 20)
  game.players[1].life = 100
  let names =
    case heroClass
    of Archer:
      ["Bolt", "Sharpshooter", "Hail of Arrows", "Sniper"]
    of Mage:
      ["Bouncer", "Oozification", "Primordial", "Plan"]
    of Warrior:
      ["Duel", "Tactician", "Bear", "Swords"]
  for i in 0 ..< 24:
    game.players[0].hand.add baseCardNamed(names[i mod 4])
  for i in 0 ..< 12:
    game.players[0].board.add MinionState(id: i + 1, owner: 0,
      card: baseCardNamed("Footsoldier"), currentToughness: 2)
    game.players[1].board.add MinionState(id: i + 13, owner: 1,
      card: baseCardNamed("Bear"), currentToughness: 2)
  game.nextMinionId = 25
  discard decide(game)

echo "AWM steering and search checks passed"
