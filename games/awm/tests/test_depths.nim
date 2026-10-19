import
  std/os,
  bassy,
  sim, bots

const
  Submitted = currentSourcePath().parentDir / "../radogost/radogost.bas"
  Candidate = currentSourcePath().parentDir / "../experiments/depths.bas"

proc fixture(names: openArray[string], energy: int): GameState =
  ## Creates a legal Warrior decision with the supplied affordable cards.
  result = newGame([Warrior, Mage], 42)
  result.currentPlayer = 0
  result.turnNumber = 1
  result.players[0].hand.setLen(0)
  result.players[0].energy = energy
  result.players[0].totalEnergy = energy
  for player in result.players.mitems:
    player.life = 100
    player.board.setLen(0)
  for name in names:
    result.players[0].hand.add baseCardNamed(name)

proc decide(game: var GameState, path: string): BotVm =
  ## Runs the policy under the real frozen game's resource limits.
  resetInboxes(game.playerCount)
  result = loadBot(readFile(path), 0)
  doAssert not result.failed, result.lastError
  doAssert result.runDecision(game) != BotFailed, result.lastError
  doAssert result.runtime.workUsed < botLimits().maxWorkUnits
  doAssert result.runtime.instructionsUsed < botLimits().maxInstructions
  echo "Work ", result.runtime.workUsed, ", instructions ",
    result.runtime.instructionsUsed, ", depth ",
    result.runtime.getGlobal("depth"), ", best score ",
    result.runtime.getGlobalValue("bestScore"), ", selected ",
    result.playedHand

echo "Testing seven affordable creatures extend the modeled sequence"
block:
  var
    original = fixture([
      "Footsoldier", "Footsoldier", "Footsoldier", "Footsoldier",
      "Footsoldier", "Footsoldier", "Footsoldier"
    ], 7)
    changed = original.copyGameState()
  let
    oldVm = original.decide(Submitted)
    newVm = changed.decide(Candidate)
  doAssert oldVm.runtime.getGlobal("depth") == 5
  doAssert newVm.runtime.getGlobal("depth") == 7
  doAssert oldVm.runtime.getGlobalValue("bestScore").asFixed <
    newVm.runtime.getGlobalValue("bestScore").asFixed
  doAssert original.players[0].board.len == 1
  doAssert changed.players[0].board.len == 1
  doAssert changed.players[0].board[0].power == 1
  doAssert changed.players[0].board[0].currentToughness == 2
  for i in 1 ..< 7:
    doAssert newVm.runDecision(changed) == BotPlayedCard
  doAssert changed.players[0].energy == 0
  doAssert changed.players[0].board.len == 7
  for minion in changed.players[0].board:
    doAssert minion.power == 1
    doAssert minion.currentToughness == 2

echo "Testing an existing creature-before-empty-buff decision"
block:
  var game = fixture(["Swords", "Bear"], 4)
  let vm = game.decide(Candidate)
  doAssert vm.playedHand == 1
  doAssert game.players[0].board[0].power == 3

echo "Testing an existing empty-buff decision"
block:
  var game = fixture(["Swords", "Shields"], 3)
  let vm = game.decide(Candidate)
  doAssert vm.playedHand == -1
  doAssert game.players[0].hand.len == 2

echo "Depth horizon isolation checks passed"
