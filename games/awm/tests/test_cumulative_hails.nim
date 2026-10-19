import
  std/os,
  bassy,
  sim, bots

const
  Directory = currentSourcePath().parentDir / ".."
  Source = Directory / "experiments/cumulative_hail.bas"
  Original = Directory / "radogost/radogost.bas"

proc decide(vm: BotVm, game: var GameState): BotDecision =
  ## Executes one actual released-host decision within both hard limits.
  result = vm.runDecision(game)
  doAssert result != BotFailed, vm.lastError
  doAssert vm.runtime.workUsed < botLimits().maxWorkUnits
  doAssert vm.runtime.instructionsUsed < botLimits().maxInstructions

proc fixture(
    source: string,
    hails, energy: int
): tuple[game: GameState, vm: BotVm] =
  ## Carries class inference from a real Sniper play into the next own turn.
  result.game = newGame([Archer, Warrior, Mage, Archer], 42)
  result.game.currentPlayer = 0
  for player in result.game.players.mitems:
    player.board.setLen(0)
    player.life = 100
  result.game.players[0].hand = @[baseCardNamed("Sniper")]
  result.game.players[0].energy = 2
  resetInboxes(4)
  result.vm = loadBot(source, 0)
  doAssert not result.vm.failed, result.vm.lastError
  doAssert result.vm.decide(result.game) == BotPlayedCard
  doAssert result.vm.runtime.getGlobal("heroClass") == 1
  result.game.turnNumber += 4
  result.game.players[0].energy = energy
  result.game.players[0].totalEnergy = energy
  for i in 0 ..< hails:
    result.game.players[0].hand.add baseCardNamed("Hail of Arrows")

proc army(game: var GameState, count: int, name: string) =
  ## Adds exact next-enemy minions using their real printed health.
  for i in 0 ..< count:
    let card = baseCardNamed(name)
    game.players[1].board.add MinionState(
      id: game.nextMinionId,
      owner: 1,
      card: card,
      currentToughness: card.toughness
    )
    inc game.nextMinionId

echo "Testing the original policy holds both Hails against two-HP Bears"
block:
  var state = fixture(readFile(Original), 2, 6)
  state.game.army(2, "Bear")
  doAssert state.vm.decide(state.game) == BotEndedTurn
  doAssert state.game.players[1].board.len == 2

echo "Testing two real Hails clear an exact visible two-HP army"
block:
  var state = fixture(readFile(Source), 2, 6)
  state.game.army(2, "Bear")
  doAssert state.vm.decide(state.game) == BotPlayedCard
  doAssert state.game.players[1].board.len == 2
  for minion in state.game.players[1].board:
    doAssert minion.currentToughness == 1
  doAssert state.vm.decide(state.game) == BotPlayedCard
  doAssert state.game.players[1].board.len == 0
  doAssert state.game.players[0].hand.len == 0
  doAssert state.game.players[0].energy == 0
  echo "Two Hails removed six actual enemy power"

echo "Testing redundant Hails stay held after the visible army is cleared"
block:
  var state = fixture(readFile(Source), 3, 9)
  state.game.army(1, "Bear")
  state.game.army(1, "Sniper")
  doAssert state.vm.decide(state.game) == BotPlayedCard
  doAssert state.game.players[1].board.len == 1
  doAssert state.game.players[1].board[0].currentToughness == 1
  doAssert state.vm.decide(state.game) == BotPlayedCard
  doAssert state.game.players[1].board.len == 0
  doAssert state.vm.runtime.getGlobal("stateThreat") == 0
  doAssert state.vm.decide(state.game) == BotEndedTurn
  doAssert state.game.players[0].hand.len == 1
  doAssert state.game.players[0].energy == 3

echo "Testing partial damage without an affordable clear remains pruned"
for boundary in [(1, 6), (2, 5)]:
  var state = fixture(readFile(Source), boundary[0], boundary[1])
  state.game.army(2, "Bear")
  doAssert state.vm.decide(state.game) == BotEndedTurn
  doAssert state.game.players[1].board[0].currentToughness == 2

echo "Testing exact visible empty boards do not infer hidden Hail value"
block:
  var state = fixture(readFile(Source), 3, 9)
  doAssert state.vm.decide(state.game) == BotEndedTurn
  doAssert state.game.players[0].hand.len == 3

echo "Testing single-Hail coverage past the target-model buffer"
block:
  var state = fixture(readFile(Source), 1, 3)
  state.game.army(128, "Bear")
  state.game.army(1, "Sniper")
  doAssert state.vm.decide(state.game) == BotPlayedCard
  doAssert state.game.players[1].board.len == 128

echo "Testing cumulative-Hail coverage past the target-model buffer"
block:
  var state = fixture(readFile(Source), 2, 6)
  state.game.army(128, "Primordial")
  state.game.army(1, "Bear")
  doAssert state.vm.decide(state.game) == BotPlayedCard
  doAssert state.vm.decide(state.game) == BotPlayedCard
  doAssert state.game.players[1].board.len == 128
  for minion in state.game.players[1].board:
    doAssert minion.currentToughness == 8

echo "Testing Hail and a targeted kill credit a twenty-fifth minion once"
block:
  var state = fixture(readFile(Source), 1, 6)
  state.game.players[0].hand.add baseCardNamed("Sharpshooter")
  state.game.army(24, "Ooze")
  state.game.army(1, "Sharpshooter")
  doAssert state.vm.decide(state.game) == BotPlayedCard
  doAssert state.vm.runtime.getArray("hailCounts", 1) >= 0
  doAssert state.vm.runtime.getArray("hailPowers", 1) >= 0
  doAssert state.vm.decide(state.game) == BotPlayedCard
  doAssert state.game.players[1].board.len == 0
  doAssert state.vm.runtime.getGlobal("stateThreat") == 0

echo "Cumulative visible Hail checks passed"
