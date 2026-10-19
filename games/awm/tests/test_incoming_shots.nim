import
  std/os,
  bassy,
  sim, bots

const
  Directory = currentSourcePath().parentDir / ".."
  Source = Directory / "experiments/incoming_shots.bas"
  Original = Directory / "radogost/radogost.bas"

proc decide(vm: BotVm, game: var GameState): BotDecision =
  ## Runs an actual released-host decision with both resource limits checked.
  result = vm.runDecision(game)
  doAssert result != BotFailed, vm.lastError
  doAssert vm.runtime.workUsed < botLimits().maxWorkUnits
  doAssert vm.runtime.instructionsUsed < botLimits().maxInstructions

proc fixture(source: string, count = 1): tuple[game: GameState, vm: BotVm] =
  ## Retains class inference from a real Sniper play into a subsequent turn.
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
  result.game.turnNumber += 4
  result.game.players[0].energy = count * 3
  result.game.players[0].totalEnergy = count * 3
  for i in 0 ..< count:
    result.game.players[0].hand.add baseCardNamed("Sharpshooter")

proc army(game: var GameState, seat, count: int, name: string) =
  ## Adds real minions for exact simulator effects, without exposing hidden HP.
  for i in 0 ..< count:
    let card = baseCardNamed(name)
    game.players[seat].board.add MinionState(
      id: game.nextMinionId,
      owner: seat,
      card: card,
      currentToughness: card.toughness,
      canAttack: true
    )
    inc game.nextMinionId

echo "Testing original Sharpshooter ignores a lethal incoming Sniper"
block:
  var state = fixture(readFile(Original))
  state.game.players[0].life = 1
  state.game.army(3, 1, "Sniper")
  doAssert state.vm.decide(state.game) == BotPlayedCard
  doAssert state.vm.playedChoices[0].kind == HeroChoice
  doAssert state.vm.playedChoices[0].owner == 1
  doAssert state.game.players[3].board.len == 1

echo "Testing incoming Sharpshooter removes the actual threatening Sniper"
block:
  var state = fixture(readFile(Source))
  state.game.players[0].life = 1
  state.game.army(3, 1, "Sniper")
  doAssert state.vm.decide(state.game) == BotPlayedCard
  doAssert state.vm.playedChoices[0].kind == CreatureChoice
  doAssert state.vm.playedChoices[0].owner == 3
  doAssert state.game.players[3].board.len == 0
  doAssert state.vm.runtime.getGlobal("damage") == 0
  doAssert state.vm.runtime.getGlobal("stateThreat") == 0
  doAssert state.vm.runtime.getGlobalValue("defense").asFixed == 1.5'fx

echo "Testing the hidden-health prior can encounter a surviving Bear"
block:
  var state = fixture(readFile(Source))
  state.game.army(3, 1, "Bear")
  doAssert state.vm.decide(state.game) == BotPlayedCard
  doAssert state.game.players[3].board.len == 1
  doAssert state.game.players[3].board[0].currentToughness == 1
  doAssert state.vm.runtime.getGlobalValue("defense").asFixed == 1.5'fx

echo "Testing exact visible removals retain their original target preference"
block:
  var state = fixture(readFile(Source))
  state.game.army(1, 1, "Sniper")
  state.game.army(3, 1, "Sniper")
  doAssert state.vm.decide(state.game) == BotPlayedCard
  doAssert state.vm.playedChoices[0].owner == 1
  doAssert state.game.players[1].board.len == 0
  doAssert state.vm.runtime.getArray("incomingShots", 0) == 0

echo "Testing public hero choices skip a dead predecessor's remaining army"
block:
  var state = fixture(readFile(Source))
  state.game.players[3].dead = true
  state.game.army(3, 3, "Sniper")
  state.game.army(2, 1, "Bouncer")
  doAssert state.vm.decide(state.game) == BotPlayedCard
  doAssert state.vm.playedChoices[0].owner == 2
  doAssert state.game.players[2].board.len == 0
  doAssert state.game.players[3].board.len == 3

echo "Testing a final duel keeps visible targeting instead of hidden priors"
block:
  var state = fixture(readFile(Source))
  state.game.players[2].dead = true
  state.game.players[3].dead = true
  state.game.army(3, 3, "Sniper")
  doAssert state.vm.decide(state.game) == BotPlayedCard
  doAssert state.vm.playedChoices[0].kind == HeroChoice
  doAssert state.vm.playedChoices[0].owner == 1
  doAssert state.vm.runtime.getArray("incomingShots", 0) == 0

echo "Testing original immediate hero lethals remain unchanged"
block:
  var state = fixture(readFile(Source))
  state.game.players[1].life = 1
  state.game.army(3, 3, "Sniper")
  doAssert state.vm.decide(state.game) == BotPlayedCard
  doAssert state.vm.playedChoices[0].kind == HeroChoice
  doAssert state.vm.playedChoices[0].owner == 1
  doAssert state.game.players[1].dead

echo "Testing repeated modeled shots cannot double-credit one unknown target"
block:
  var state = fixture(readFile(Source), 2)
  state.game.army(3, 2, "Bear")
  doAssert state.vm.decide(state.game) == BotPlayedCard
  let
    stop = state.vm.runtime.getGlobalValue("stopValue").asFixed
    score = state.vm.runtime.getGlobalValue("bestScore").asFixed
  doAssert state.vm.runtime.getArray("incomingKeys", 0) ==
    state.vm.runtime.getArray("incomingKeys", 1)
  doAssert score <= stop + 1.76'fx
  doAssert state.vm.runtime.getGlobal("removedShotCount") == 1
  doAssert state.vm.decide(state.game) == BotPlayedCard
  doAssert state.game.players[3].board.len == 1

echo "Incoming Sharpshooter checks passed"
