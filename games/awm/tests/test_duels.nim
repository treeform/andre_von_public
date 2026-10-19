import
  std/os,
  bassy,
  sim, bots

const
  Submitted = currentSourcePath().parentDir / "../radogost/radogost.bas"
  Candidate = currentSourcePath().parentDir / "../experiments/duels.bas"
  Limit = 500_000

proc fixture(names: openArray[string], energy: int): GameState =
  ## Creates a four-seat Warrior decision with an explicit hand and energy.
  result = newGame([Warrior, Mage, Archer, Mage], 42)
  result.currentPlayer = 0
  result.turnNumber = 1
  result.players[0].hand.setLen(0)
  result.players[0].energy = energy
  result.players[0].totalEnergy = energy
  for name in names:
    result.players[0].hand.add baseCardNamed(name)
  for player in result.players.mitems:
    player.board.setLen(0)
    player.life = 100

proc army(game: var GameState, seat, count: int, name: string) =
  ## Adds ready minions with their actual printed stats to a seat's board.
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

proc load(game: GameState, path = Candidate): BotVm =
  ## Loads the policy against the real host for the fixture's player count.
  resetInboxes(game.playerCount)
  result = loadBot(readFile(path), 0)
  doAssert not result.failed, result.lastError

proc decide(vm: BotVm, game: var GameState): BotDecision =
  ## Runs a real BASIC decision and checks the production VM limits.
  result = vm.runDecision(game)
  doAssert result != BotFailed, vm.lastError
  doAssert vm.runtime.instructionsUsed < Limit
  doAssert vm.runtime.workUsed < Limit
  echo "Work ", vm.runtime.workUsed, ", instructions ",
    vm.runtime.instructionsUsed, ", selected hand ", vm.playedHand

echo "Testing an enemy-only Primordial Duel with no own fighter"
block:
  var
    original = fixture(["Duel"], 2)
    changed: GameState
  original.army(1, 1, "Primordial")
  changed = original.copyGameState()
  let
    target = creatureChoice(1, 1)
    oldVm = original.load(Submitted)
    newVm = changed.load()
  doAssert target in changed.availableChoices(0)
  doAssert target in changed.availableChoices(0, @[target])
  doAssert oldVm.decide(original) == BotEndedTurn
  doAssert newVm.decide(changed) == BotPlayedCard
  doAssert newVm.playedChoices == @[target, target]
  doAssert changed.players[0].board.len == 0
  doAssert changed.players[1].board.len == 0
  doAssert changed.players[1].discardPile.len == 1
  doAssert changed.players[0].energy == 0
  doAssert newVm.runtime.getGlobal("statePower") == 0
  doAssert newVm.runtime.getGlobal("stateReady") == 0
  doAssert newVm.runtime.getGlobal("stateHealth") == 0
  doAssert newVm.runtime.getGlobal("forcedHand") == -1

echo "Testing self-Duel only accepts enemies whose power reaches HP"
for name in ["Bear", "Sniper", "Sharpshooter", "Bouncer",
    "Footsoldier", "Tactician", "Commander", "Ooze"]:
  var game = fixture(["Duel"], 2)
  game.army(1, 1, name)
  let
    card = baseCardNamed(name)
    vm = game.load()
    kills = card.power >= card.toughness
  if kills:
    doAssert vm.decide(game) == BotPlayedCard
    doAssert vm.playedChoices[0] == vm.playedChoices[1]
    doAssert game.players[1].board.len == 0
  else:
    doAssert vm.decide(game) == BotEndedTurn
    doAssert game.players[1].board.len == 1
    doAssert game.players[1].board[0].power == card.power
    doAssert game.players[1].board[0].currentToughness == card.toughness
    doAssert game.players[0].hand.len == 1
    doAssert game.players[0].energy == 2

echo "Testing a favorable own fighter is retained"
block:
  var game = fixture(["Duel"], 2)
  game.army(0, 1, "Bear")
  game.army(1, 1, "Sniper")
  let vm = game.load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.playedChoices == @[
    creatureChoice(0, 1), creatureChoice(1, 2)]
  doAssert vm.runtime.getArray("duelOwns", 0) == 1
  doAssert game.players[0].board[0].power == 4
  doAssert game.players[0].board[0].currentToughness == 1
  doAssert vm.runtime.getGlobal("statePower") == 4
  doAssert vm.runtime.getGlobal("stateReady") == 4
  doAssert game.players[1].board.len == 0

echo "Testing an enemy-only Duel never buffs an unrelated own minion"
block:
  var game = fixture(["Duel"], 2)
  game.army(0, 1, "Bear")
  game.army(1, 1, "Primordial")
  let vm = game.load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.playedChoices == @[
    creatureChoice(1, 2), creatureChoice(1, 2)]
  doAssert vm.runtime.getArray("duelOwns", 0) == 0
  doAssert game.players[0].board[0].power == 3
  doAssert game.players[0].board[0].currentToughness == 2
  doAssert vm.runtime.getGlobal("statePower") == 3
  doAssert vm.runtime.getGlobal("stateReady") == 3
  doAssert vm.runtime.getGlobal("stateHealth") == 2

echo "Testing hidden enemy minions are excluded from self-Duel inference"
block:
  var game = fixture(["Duel"], 2)
  game.army(1, 1, "Footsoldier")
  game.army(3, 1, "Primordial")
  let vm = game.load()
  doAssert vm.decide(game) == BotEndedTurn
  doAssert game.players[1].board.len == 1
  doAssert game.players[3].board.len == 1

echo "Testing a removed self-fighter is pruned from repeated Duel branches"
block:
  var game = fixture(["Duel", "Duel"], 4)
  game.army(1, 1, "Primordial")
  let vm = game.load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.runtime.getGlobal("nodes") == 2
  doAssert vm.runtime.getArray("children", 1) == 0
  doAssert vm.runtime.getArray("children", 2) == 0
  doAssert vm.runtime.getGlobal("removed") == 1
  doAssert game.players[0].hand.len == 1
  doAssert vm.decide(game) == BotEndedTurn
  doAssert game.players[0].hand.len == 1

echo "Testing Tactician cannot precede a now-invalid self-Duel"
block:
  var game = fixture(["Duel", "Tactician"], 4)
  game.army(1, 1, "Primordial")
  let vm = game.load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.playedHand == 0
  var
    child = vm.runtime.getArray("children", 0)
    checked = false
  while child > 0:
    if vm.runtime.getArray("actions", child) == 1:
      doAssert vm.runtime.getArray("children", child) == 0
      checked = true
    child = vm.runtime.getArray("siblings", child)
  doAssert checked, "Search must exercise the power-reduction branch"

echo "Testing repeated Duels beyond the existing removal bitmask"
block:
  var game = fixture(["Duel", "Duel"], 4)
  game.army(1, 25, "Footsoldier")
  game.army(1, 1, "Primordial")
  let vm = game.load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.playedChoices == @[
    creatureChoice(1, 26), creatureChoice(1, 26)]
  doAssert vm.runtime.getGlobal("nodes") == 2
  doAssert vm.runtime.getArray("children", 1) == 0
  doAssert vm.runtime.getArray("children", 2) == 0
  doAssert vm.runtime.getGlobal("duelGone") == 1
  doAssert game.players[1].board.len == 25

echo "Testing wide enemy-only Duel hands under both VM budgets"
block:
  var game = fixture([], 20)
  for i in 0 ..< 24:
    game.players[0].hand.add baseCardNamed(
      ["Duel", "Tactician", "Bear", "Swords"][i mod 4]
    )
  game.army(0, 12, "Footsoldier")
  game.army(1, 12, "Bear")
  let vm = game.load()
  doAssert vm.decide(game) == BotPlayedCard

echo "Enemy-only Duel isolation checks passed"
