import
  std/os,
  bassy,
  sim, bots

const
  Submitted = currentSourcePath().parentDir / "../radogost/radogost.bas"
  Candidate = currentSourcePath().parentDir / "../experiments/shots.bas"
  Limit = 500_000

type AwmError = object of CatchableError

proc fixture(
    names: openArray[string],
    energy, enemyLife: int,
    enemyClass = Archer,
    ownClass = Archer
): GameState =
  ## Creates a card phase using real hand, board and target rules.
  result = newGame([ownClass, enemyClass, Mage, Warrior], 42)
  result.currentPlayer = 0
  result.turnNumber = 18
  result.players[0].hand.setLen(0)
  result.players[0].energy = energy
  result.players[0].totalEnergy = energy
  for name in names:
    result.players[0].hand.add baseCardNamed(name)
  for player in result.players.mitems:
    player.board.setLen(0)
    player.life = 100
  result.players[1].life = enemyLife

proc army(
    game: var GameState,
    seat: int,
    names: openArray[string]
) =
  ## Adds prior-turn ready permanents with their actual printed stats.
  for name in names:
    let card = baseCardNamed(name)
    game.players[seat].board.add MinionState(
      id: game.nextMinionId,
      owner: seat,
      card: card,
      currentToughness: if card.kind == Minion: card.toughness else: 0,
      enteredTurn: game.turnNumber - 1,
      canAttack: card.kind == Minion
    )
    inc game.nextMinionId

proc readyPower(game: GameState): int =
  ## Sums only minions the real host allows to attack in this card phase.
  for minion in game.players[0].board:
    if minion.card.kind == Minion and minion.canAttack and
      not minion.hasAttacked and minion.currentToughness > 0:
        result += minion.power

proc load(game: GameState, path = Candidate): BotVm =
  ## Loads a policy against the pinned production 500k BASIC host.
  doAssert botLimits().maxInstructions == Limit
  doAssert botLimits().maxWorkUnits == Limit
  resetInboxes(game.playerCount)
  var source: string
  try:
    source = readFile(path)
  except IOError as error:
    raise newException(AwmError, "Cannot read shot policy: " & error.msg)
  result = loadBot(source, 0)
  doAssert not result.failed, result.lastError

proc decide(vm: BotVm, game: var GameState): BotDecision =
  ## Runs one actual host decision and checks both deployed VM budgets.
  result = vm.runDecision(game)
  doAssert result != BotFailed, vm.lastError
  doAssert vm.runtime.instructionsUsed < Limit
  doAssert vm.runtime.workUsed < Limit
  echo "Work ", vm.runtime.workUsed, ", instructions ",
    vm.runtime.instructionsUsed, ", root ready ",
    vm.runtime.getGlobal("rootReady"), ", targets ", vm.playedChoices

proc attackTurn(game: var GameState): int =
  ## Applies the host's ready attackers to its one fixed next-living hero.
  let
    target = game.nextPlayer(0)
    attackers = game.eligibleAttackers()
  for id in attackers:
    let life = game.players[target].life
    if game.attackHero(id, target):
      result += life - game.players[target].life
    discard game.takeVisualEvents()

echo "Testing ready-nine plus the shot kills a ten-life hero"
block:
  var
    original = fixture(["Sharpshooter"], 3, 10)
    changed: GameState
  original.army(0, ["Sniper", "Sharpshooter", "Sniper", "Sniper"])
  original.army(1, ["Sniper"])
  changed = original.copyGameState()
  let
    oldVm = original.load(Submitted)
    newVm = changed.load()
  doAssert original.readyPower == 9
  doAssert heroChoice(1) in changed.availableChoices(0)
  doAssert oldVm.decide(original) == BotPlayedCard
  doAssert oldVm.playedChoices == @[creatureChoice(1, 5)]
  doAssert original.players[1].life == 10
  doAssert original.attackTurn == 9
  doAssert original.players[1].life == 1
  doAssert newVm.decide(changed) == BotPlayedCard
  doAssert newVm.runtime.getGlobal("rootReady") == 9
  doAssert newVm.playedChoices == @[heroChoice(1)]
  doAssert changed.players[1].life == 9
  doAssert changed.players[1].board.len == 1
  doAssert changed.attackTurn == 9
  doAssert changed.players[1].dead

echo "Testing a direct one-life shot with no ready army"
block:
  var
    original = fixture(["Sharpshooter"], 3, 1)
    changed: GameState
  original.turnNumber = 21
  original.army(1, ["Sniper"])
  changed = original.copyGameState()
  let
    oldVm = original.load(Submitted)
    newVm = changed.load()
  doAssert original.readyPower == 0
  doAssert oldVm.decide(original) == BotPlayedCard
  doAssert oldVm.playedChoices == @[creatureChoice(1, 1)]
  doAssert original.players[1].life == 1
  doAssert newVm.decide(changed) == BotPlayedCard
  doAssert newVm.playedChoices == @[heroChoice(1)]
  doAssert newVm.runtime.getGlobal("forcedHand") == 0
  doAssert changed.players[1].dead
  doAssert changed.readyPower == 0

echo "Testing Bubble does not prevent the shot or current attack damage"
block:
  var game = fixture(["Sharpshooter"], 3, 10, Mage)
  game.army(0, ["Sniper", "Sharpshooter", "Sniper", "Sniper"])
  game.army(1, ["Bouncer", "Bubble"])
  let vm = game.load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.playedChoices == @[heroChoice(1)]
  doAssert game.players[1].life == 9
  doAssert game.players[1].board.len == 2
  doAssert game.attackTurn == 9
  doAssert game.players[1].dead
  doAssert game.players[0].hand.len == 1
  doAssert game.players[0].hand[0].name == "Sniper"
  doAssert not game.minionLocation(1).found

echo "Testing nonlethal target preference remains unchanged"
for life in [11, 100]:
  var
    original = fixture(["Sharpshooter"], 3, life)
    changed: GameState
  original.army(0, ["Sniper", "Sharpshooter", "Sniper", "Sniper"])
  original.army(1, ["Sniper"])
  changed = original.copyGameState()
  let
    oldVm = original.load(Submitted)
    newVm = changed.load()
  doAssert oldVm.decide(original) == BotPlayedCard
  doAssert newVm.decide(changed) == BotPlayedCard
  doAssert newVm.playedChoices == oldVm.playedChoices
  doAssert newVm.playedChoices == @[creatureChoice(1, 5)]
  doAssert changed.players[1].life == life
  doAssert changed.players[1].board.len == 0

echo "Testing consecutive real Sharpshooters preserve exact fresh power"
block:
  var game = fixture(["Sharpshooter", "Sharpshooter"], 6, 4)
  game.army(0, ["Sniper"])
  game.army(1, ["Sniper", "Sniper"])
  let vm = game.load()
  doAssert game.readyPower == 2
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.playedChoices[0].kind == CreatureChoice
  doAssert vm.runtime.getGlobal("freshPower") == 3
  doAssert game.readyPower == 2
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.runtime.getGlobal("rootReady") == game.readyPower
  doAssert vm.runtime.getGlobal("rootReady") == 2
  doAssert vm.playedChoices[0].kind == CreatureChoice
  doAssert vm.runtime.getGlobal("freshPower") == 6
  doAssert game.players[1].life == 4
  doAssert game.players[0].board.len == 3
  doAssert not game.players[0].board[1].canAttack
  doAssert not game.players[0].board[2].canAttack

echo "Testing first-turn lethal chooses the next living hero"
block:
  var game = fixture(["Sharpshooter"], 3, 100)
  game.turnNumber = 1
  game.players[1].dead = true
  game.players[1].life = 0
  game.players[2].life = 1
  game.army(1, ["Sniper"])
  game.army(2, ["Bouncer"])
  let vm = game.load()
  doAssert heroChoice(1) notin game.availableChoices(0)
  doAssert heroChoice(2) in game.availableChoices(0)
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.playedChoices == @[heroChoice(2)]
  doAssert game.players[2].dead
  doAssert game.readyPower == 0
  doAssert game.players[1].board.len == 1

echo "Testing wide nonlethal choices under both 500k VM limits"
block:
  var game = fixture([], 20, 100)
  for i in 0 ..< 24:
    game.players[0].hand.add baseCardNamed(
      ["Bolt", "Sharpshooter", "Hail of Arrows", "Sniper"][i mod 4]
    )
  for i in 0 ..< 12:
    game.army(0, ["Sniper"])
    game.army(1, ["Bear"])
    game.army(2, ["Bouncer"])
    game.army(3, ["Footsoldier"])
  let vm = game.load()
  doAssert vm.decide(game) == BotPlayedCard

echo "Testing Mage minion-only choices incur no added condition work"
block:
  var
    original = fixture(["Bouncer"], 1, 100, Mage, Mage)
    changed: GameState
  original.army(1, ["Bear", "Bear"])
  original.army(3, ["Footsoldier", "Footsoldier"])
  changed = original.copyGameState()
  let
    oldVm = original.load(Submitted)
    newVm = changed.load()
  doAssert oldVm.decide(original) == BotPlayedCard
  doAssert newVm.decide(changed) == BotPlayedCard
  doAssert newVm.playedChoices == oldVm.playedChoices
  doAssert newVm.runtime.workUsed == oldVm.runtime.workUsed
  doAssert newVm.runtime.instructionsUsed == oldVm.runtime.instructionsUsed

echo "Lethal Sharpshooter isolation checks passed."
