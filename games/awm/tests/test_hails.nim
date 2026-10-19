import
  std/os,
  bassy,
  sim, bots

const
  Policy = currentSourcePath().parentDir / "../experiments/global_hail.bas"
  Limit = 500_000

proc fixture(names: openArray[string], energy: int): GameState =
  ## Creates an actual four-seat host decision with an Archer candidate.
  result = newGame([Archer, Mage, Warrior, Archer], 42)
  result.currentPlayer = 0
  result.turnNumber = 1
  result.players[0].hand.setLen(0)
  result.players[0].energy = energy
  result.players[0].totalEnergy = energy
  for name in names:
    result.players[0].hand.add baseCardNamed(name)
  for player in result.players.mitems:
    player.board.setLen(0)

proc army(game: var GameState, seat, count: int, name = "Sniper") =
  ## Adds public minions so effects and queries use the real simulator.
  for i in 0 ..< count:
    let card = baseCardNamed(name)
    game.players[seat].board.add MinionState(
      id: game.nextMinionId,
      owner: seat,
      card: card,
      currentToughness: card.toughness
    )
    inc game.nextMinionId

proc load(): BotVm =
  ## Compiles the isolated candidate using the released BASIC host.
  resetInboxes(4)
  result = loadBot(readFile(Policy), 0)
  doAssert not result.failed, result.lastError

proc decide(vm: BotVm, game: var GameState): BotDecision =
  ## Runs one real host decision and checks both hard VM limits.
  result = vm.runDecision(game)
  doAssert result != BotFailed, vm.lastError
  doAssert vm.runtime.instructionsUsed < Limit
  doAssert vm.runtime.workUsed < Limit
  echo "Decision work ", vm.runtime.workUsed,
    ", instructions ", vm.runtime.instructionsUsed,
    ", hidden Hail gain ", vm.runtime.getGlobalValue("hailHiddenGain")

echo "Testing global Hail queries an unaffordable Sharpshooter"
block:
  var game = fixture(["Hail of Arrows", "Sharpshooter"], 3)
  game.players[0].hand[1].energyCost = 4
  game.army(3, 3)
  let vm = load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.playedHand == 0
  doAssert game.players[1].board.len == 0
  doAssert game.players[3].board.len == 0
  doAssert game.players[3].discardPile.len == 3
  doAssert vm.runtime.getGlobal("forcedHand") == -1

echo "Testing native cards preserve their probe after the last Sharpshooter"
block:
  var shotFirst = false
  for randomState in [17, 1349, 3002, 28983]:
    var game = fixture(["Sharpshooter", "Hail of Arrows"], 6)
    game.army(3, 3)
    let vm = load()
    vm.runtime.setGlobal("randomState", randomState)
    doAssert vm.decide(game) == BotPlayedCard
    let first = vm.playedHand
    echo "First native card ", first, ", random state ", randomState
    if first == 0:
      shotFirst = true
      doAssert vm.runtime.getGlobal("hailProbeValid") == 1
      doAssert vm.runtime.getArray("hailMinions", 3) == 3
      doAssert game.players[0].energy == 3
    doAssert vm.decide(game) == BotPlayedCard
    doAssert game.players[0].hand.len == 0
    doAssert game.players[3].board.len == 0
    doAssert game.players[0].board.len == 1
  doAssert shotFirst, "The real-card fixture must exercise a saved probe"

echo "Testing a known empty global Hail is held after its last probe"
block:
  var game = fixture(["Sharpshooter", "Hail of Arrows"], 6)
  let vm = load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.playedHand == 0
  doAssert vm.runtime.getGlobal("hailProbeValid") == 1
  doAssert vm.decide(game) == BotEndedTurn
  doAssert game.players[0].hand.len == 1
  doAssert game.players[0].hand[0].name == "Hail of Arrows"
  doAssert vm.runtime.getGlobal("hailHiddenGain") == 0
  game.turnNumber += 4
  game.players[0].energy = 3
  doAssert vm.decide(game) == BotEndedTurn
  doAssert vm.runtime.getGlobal("hailProbeValid") == 0

echo "Testing minions on dead seats do not become Hail observations"
block:
  var game = fixture(["Hail of Arrows", "Sharpshooter"], 3)
  game.players[0].hand[1].energyCost = 4
  game.players[3].dead = true
  game.army(3, 4)
  let vm = load()
  doAssert vm.decide(game) == BotEndedTurn
  doAssert vm.runtime.getArray("hailLiving", 3) == 0
  doAssert vm.runtime.getArray("hailMinions", 3) == 0
  doAssert game.players[3].board.len == 4

echo "Testing uncertain empty Hail is not forced without a probe"
block:
  var game = fixture(["Sniper", "Hail of Arrows"], 5)
  let vm = load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.playedHand == 0
  doAssert vm.decide(game) == BotEndedTurn
  doAssert vm.runtime.getGlobal("forcedHand") == -1
  doAssert game.players[0].hand.len == 1

echo "Testing wide global Hail queries stay within both VM budgets"
block:
  var game = fixture([], 20)
  for player in game.players.mitems:
    player.life = 100
  for i in 0 ..< 24:
    game.players[0].hand.add baseCardNamed(
      ["Bolt", "Sharpshooter", "Hail of Arrows", "Sniper"][i mod 4]
    )
  game.army(0, 12, "Footsoldier")
  game.army(1, 12, "Bear")
  game.army(2, 12)
  game.army(3, 12)
  let vm = load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.runtime.getGlobalValue("hailHiddenGain").asFixed > FixedZero

echo "Global Hail strategy checks passed"
