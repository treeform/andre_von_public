import
  std/os,
  bassy,
  sim, bots

const
  Candidate = currentSourcePath().parentDir / "../experiments/reserves.bas"
  Submitted = currentSourcePath().parentDir / "../radogost/radogost.bas"
  Limit = 5_000_000

proc fixture(draw: string, energy = 6): GameState =
  ## Creates a legal Mage Plan whose actual draw supplies another card.
  result = newGame([Mage, Archer, Warrior, Mage], 42)
  result.currentPlayer = 0
  result.turnNumber = 1
  result.players[0].hand = @[baseCardNamed("Plan")]
  result.players[0].deck = @[
    baseCardNamed("Bouncer"),
    baseCardNamed("Bouncer"),
    baseCardNamed("Bouncer"),
    baseCardNamed(draw)
  ]
  result.players[0].energy = energy
  result.players[0].totalEnergy = energy
  for player in result.players.mitems:
    player.board.setLen(0)

proc load(path = Candidate): BotVm =
  ## Compiles a candidate under the actual released host.
  resetInboxes(4)
  result = loadBot(readFile(path), 0)
  doAssert not result.failed, result.lastError

proc decide(vm: BotVm, game: var GameState): BotDecision =
  ## Executes one decision and verifies both hard host budgets.
  result = vm.runDecision(game)
  doAssert result != BotFailed, vm.lastError
  doAssert vm.runtime.instructionsUsed < Limit
  doAssert vm.runtime.workUsed < Limit
  echo "Decision work ", vm.runtime.workUsed,
    ", instructions ", vm.runtime.instructionsUsed

proc nextRound(game: var GameState) =
  ## Resolves the actual next-turn draw and each existing Plan trigger.
  if game.waitingToss:
    doAssert game.resolvePendingToss(@[0])
  for i in 0 ..< 4:
    game.finishTurn()

echo "Testing an existing Plan reserves its guaranteed next-turn draw"
for name in ["Study", "Plan"]:
  var before = fixture(name)
  var game = before.copyGameState()
  let
    old = load(Submitted)
    vm = load()
  doAssert old.decide(before) == BotPlayedCard
  doAssert vm.decide(game) == BotPlayedCard
  doAssert game.players[0].deck.len == 3
  doAssert vm.runtime.getGlobal("planReserve") == 1
  doAssert old.decide(before) == BotPlayedCard
  doAssert vm.decide(game) == BotEndedTurn
  before.nextRound()
  game.nextRound()
  doAssert before.dead(0)
  doAssert not game.dead(0)
  doAssert game.currentPlayer == 0
  doAssert game.players[0].deck.len == 1

echo "Testing the indistinguishable Shield is conservatively held"
block:
  var game = fixture("Bubble Shield")
  let vm = load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.decide(game) == BotEndedTurn
  doAssert game.players[0].hand[0].name == "Bubble Shield"

echo "Testing actual Primordial bounce cancels the tracked Plan draw"
block:
  var game = fixture("Primordial", 11)
  let vm = load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.runtime.getGlobal("planReserve") == 1
  doAssert vm.decide(game) == BotPlayedCard
  doAssert game.players[0].board.len == 1
  doAssert game.players[0].board[0].card.name == "Primordial"
  doAssert vm.runtime.getGlobal("planReserve") == 0

echo "Testing no Plan obligation preserves the original admission gate"
block:
  var game = fixture("Bouncer")
  game.players[0].hand = @[
    baseCardNamed("Study"), baseCardNamed("Bouncer")
  ]
  game.players[0].deck.setLen(3)
  let vm = load()
  doAssert vm.decide(game) == BotPlayedCard
  doAssert vm.runtime.getGlobal("count") == 2
  doAssert vm.runtime.getArray("kinds", 0) == 11
  doAssert vm.runtime.getGlobal("planReserve") == 0

echo "Plan draw-reservation checks passed"
