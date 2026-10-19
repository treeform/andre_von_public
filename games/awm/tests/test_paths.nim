import
  std/os,
  bassy,
  sim, bots

const
  Candidate = currentSourcePath().parentDir / "../experiments/paths.bas"
  Submitted = currentSourcePath().parentDir / "../radogost/radogost.bas"
  Limit = 5_000_000

proc fixture(heroClass: HeroClass, names: openArray[string],
    energy, ownCount, enemyCount: int): GameState =
  ## Creates a released four-seat decision with ready public armies.
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
  for seat in 0 .. 1:
    let count = if seat == 0: ownCount else: enemyCount
    for i in 0 ..< count:
      let card = baseCardNamed("Bear")
      result.players[seat].board.add MinionState(
        id: result.nextMinionId,
        owner: seat,
        card: card,
        currentToughness: card.toughness,
        canAttack: true
      )
      inc result.nextMinionId

proc decide(game: var GameState, path: string): BotVm =
  ## Executes a real decision and checks both released hard VM limits.
  resetInboxes(4)
  result = loadBot(readFile(path), 0)
  doAssert not result.failed, result.lastError
  doAssert result.runDecision(game) != BotFailed, result.lastError
  doAssert result.runtime.instructionsUsed < Limit
  doAssert result.runtime.workUsed < Limit

proc attackPower(game: GameState): int =
  ## Counts damage the actual ready army can deal at the end of this turn.
  for minion in game.players[0].board:
    if minion.canAttack and not minion.hasAttacked:
      result += minion.power

proc finishCards(vm: BotVm, game: var GameState) =
  ## Replans subsequent cards until the real policy ends its turn safely.
  for i in 0 ..< 10:
    let decision = vm.runDecision(game)
    doAssert decision != BotFailed, vm.lastError
    doAssert vm.runtime.instructionsUsed < Limit
    doAssert vm.runtime.workUsed < Limit
    if decision == BotEndedTurn:
      return
  doAssert false, "Fixture did not end its card phase"

echo "Testing a best found buff sequence beats noisy mean backup"
block:
  var before = fixture(Warrior,
    ["Commander", "Swords", "Footsoldier", "Bear", "Rally",
    "Shields", "Tactician"], 3, 2, 0)
  var game = before.copyGameState()
  let
    old = before.decide(Submitted)
    vm = game.decide(Candidate)
    oldWork = old.runtime.workUsed
    newWork = vm.runtime.workUsed
  doAssert old.playedHand == 3
  doAssert vm.playedHand == 2
  doAssert old.runtime.getGlobal("nodes") > 1
  doAssert vm.runtime.getGlobal("nodes") > 1
  old.finishCards(before)
  vm.finishCards(game)
  doAssert before.attackPower() == 6
  doAssert game.attackPower() == 8
  doAssert before.players[0].energy == 0
  doAssert game.players[0].energy == 0
  let oldLife = before.players[1].life
  let newLife = game.players[1].life
  for id in before.eligibleAttackers():
    doAssert before.attackHero(id, 1)
  for id in game.eligibleAttackers():
    doAssert game.attackHero(id, 1)
  doAssert before.players[1].life == oldLife - 6
  doAssert game.players[1].life == newLife - 8
  echo "Actual first card Bear -> Footsoldier; end-turn damage 6 -> 8"
  echo "First-decision work ", oldWork, "/", newWork

echo "Testing immediate lethal remains forced"
block:
  var game = fixture(Archer, ["Sniper", "Bolt"], 2, 0, 0)
  game.players[1].life = 2
  let vm = game.decide(Candidate)
  doAssert vm.playedHand == 1
  doAssert vm.runtime.getGlobal("forcedHand") == 1
  doAssert game.players[1].dead

echo "Testing safe free cards and empty-buff pruning remain intact"
block:
  var game = fixture(Mage, ["Plan", "Bubble"], 3, 0, 0)
  game.players[0].deck.setLen(0)
  let vm = game.decide(Candidate)
  doAssert vm.playedHand == 1
  doAssert vm.runtime.getGlobal("forcedHand") == 1
block:
  var game = fixture(Warrior, ["Swords", "Shields"], 3, 0, 0)
  let vm = game.decide(Candidate)
  doAssert vm.playedHand == -1
  doAssert game.players[0].hand.len == 2

echo "Deterministic best-path checks passed"
