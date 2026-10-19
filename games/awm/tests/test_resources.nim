import
  std/os,
  bassy,
  sim, bots

const
  Source = currentSourcePath().parentDir / "../experiments/resources.bas"
  Limit = 5_000_000

proc fixture(hero: HeroClass, names: openArray[string]): GameState =
  ## Creates an actual host decision with large survival margins.
  result = newGame([hero, Archer, Warrior, Mage], 42)
  result.currentPlayer = 0
  result.turnNumber = 1
  for player in result.players.mitems:
    player.board.setLen(0)
    player.life = 1000
  result.players[0].hand.setLen(0)
  result.players[0].energy = 20
  result.players[0].totalEnergy = 20
  for name in names:
    result.players[0].hand.add baseCardNamed(name)

proc army(game: var GameState, seat, count: int, name: string) =
  ## Adds real named board cards for budget and numerical boundaries.
  for i in 0 ..< count:
    let card = baseCardNamed(name)
    game.players[seat].board.add MinionState(
      id: game.nextMinionId,
      owner: seat,
      card: card,
      currentToughness: (if card.kind == Minion: card.toughness else: 0),
      canAttack: true
    )
    inc game.nextMinionId

proc decide(game: var GameState): BotVm =
  ## Executes the candidate under both released five-million limits.
  resetInboxes(game.playerCount)
  result = loadBot(readFile(Source), game.currentPlayer.int32)
  doAssert not result.failed, result.lastError
  doAssert result.runDecision(game) == BotPlayedCard, result.lastError
  doAssert result.runtime.workUsed < Limit
  doAssert result.runtime.instructionsUsed < Limit
  doAssert result.runtime.memoryBytes < 64 * 1024 * 1024
  echo "Decision work ", result.runtime.workUsed,
    ", instructions ", result.runtime.instructionsUsed,
    ", iterations ", result.runtime.getGlobal("iterations"),
    ", nodes ", result.runtime.getGlobal("nodes")

doAssert botLimits().maxWorkUnits == Limit
doAssert botLimits().maxInstructions == Limit

echo "Testing resource search exceeds the old iteration limit"
block:
  var game = fixture(Archer, ["Sniper", "Sniper"])
  let vm = game.decide()
  doAssert vm.runtime.getGlobal("iterations") > 512

echo "Testing ambiguous search expands beyond the old node limit"
block:
  var game = fixture(Archer, [])
  for i in 0 ..< 6:
    game.players[0].hand.add baseCardNamed("Sniper")
  let vm = game.decide()
  doAssert vm.runtime.getGlobal("nodes") > 255

echo "Testing large rewards remain valid means instead of wrapping sums"
block:
  var game = fixture(Archer, ["Sniper", "Sniper"])
  game.army(0, 64, "Sniper")
  let
    vm = game.decide()
    stop = vm.runtime.getGlobalValue("stopValue").asFixed
    score = vm.runtime.getGlobalValue("bestScore").asFixed
  doAssert vm.runtime.getGlobal("iterations") > 512
  doAssert score > stop
  doAssert score < stop + 2.0'fx

echo "Testing the historical twenty-three-card Mage pathology"
block:
  var game = fixture(Mage, [
    "Plan", "Plan", "Plan", "Bouncer", "Bouncer", "Bouncer",
    "Plan", "Oozification", "Plan", "Bouncer", "Plan", "Bouncer",
    "Bouncer", "Bouncer", "Bouncer", "Bouncer", "Bouncer", "Bouncer",
    "Bouncer", "Bouncer", "Bouncer", "Bouncer", "Oozification"
  ])
  game.turnNumber = 66
  game.players[0].life = 18
  game.players[0].energy = 19
  game.players[0].deck.setLen(2)
  game.players[1].life = 15
  game.players[2].dead = true
  game.players[3].dead = true
  game.army(0, 1, "Ooze")
  game.army(0, 6, "Bubble")
  game.army(1, 1, "Primordial")
  game.army(1, 11, "Bouncer")
  discard game.decide()

echo "Testing all classes with full visible-board buffers and twenty-four cards"
for hero in HeroClass:
  let names =
    case hero
    of Archer: @["Sniper", "Sharpshooter", "Bolt", "Hail of Arrows"]
    of Warrior: @["Bear", "Duel", "Swords", "Shields", "Tactician"]
    of Mage: @["Bouncer", "Oozification", "Primordial", "Plan"]
  var game = fixture(hero, [])
  for i in 0 ..< 24:
    game.players[0].hand.add baseCardNamed(names[i mod names.len])
  game.army(0, 128, if hero == Mage: "Bouncer" else: "Bear")
  game.army(1, 128, "Sniper")
  game.army(2, 128, "Bear")
  game.army(3, 128, "Bear")
  discard game.decide()

echo "Resource checks passed"
