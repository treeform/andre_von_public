import
  std/os,
  bassy,
  sim, bots

const
  Submitted = currentSourcePath().parentDir / "../radogost/radogost.bas"
  Candidate = currentSourcePath().parentDir / "../experiments/shields.bas"

proc fixture(health: int): GameState =
  ## Recreates the public damaged-army Shield-versus-Swords decision.
  result = newGame([Warrior, Archer, Mage, Warrior], 42)
  result.currentPlayer = 0
  result.turnNumber = 13
  result.players[0].hand = @[
    baseCardNamed("Shields"), baseCardNamed("Swords")
  ]
  result.players[0].energy = 2
  result.players[0].totalEnergy = 4
  for player in result.players.mitems:
    player.board.setLen(0)
  result.players[0].board = @[MinionState(
    id: 1,
    owner: 0,
    card: baseCardNamed("Bear"),
    currentToughness: health,
    bonusPower: 1,
    canAttack: true
  )]
  for i in 2 .. 3:
    result.players[0].board.add MinionState(
      id: i,
      owner: 0,
      card: baseCardNamed("Footsoldier"),
      currentToughness: 2
    )
  result.nextMinionId = 4

proc decide(game: var GameState, path: string): BotVm =
  ## Runs the real BASIC host while retaining the two fresh Footsoldiers.
  resetInboxes(4)
  result = loadBot(readFile(path), 0)
  doAssert not result.failed, result.lastError
  result.runtime.setGlobal("savedTurn", game.turnNumber)
  result.runtime.setGlobal("freshPower", 2)
  result.runtime.setGlobal("freshCount", 2)
  doAssert result.runDecision(game) != BotFailed, result.lastError
  doAssert result.runtime.workUsed < botLimits().maxWorkUnits
  doAssert result.runtime.instructionsUsed < botLimits().maxInstructions
  echo "Work ", result.runtime.workUsed,
    ", instructions ", result.runtime.instructionsUsed

proc hail(game: var GameState) =
  ## Applies the real global damage spell on the next opposing turn.
  game.currentPlayer = 1
  inc game.turnNumber
  game.players[1].hand = @[baseCardNamed("Hail of Arrows")]
  game.players[1].energy = 3
  doAssert game.playCard(0)

echo "Testing Shields protects the damaged army that Swords exposes"
block:
  var
    original = fixture(1)
    changed = original.copyGameState()
  let
    old = original.decide(Submitted)
    candidate = changed.decide(Candidate)
  doAssert old.playedHand == 1
  doAssert candidate.playedHand == 0
  doAssert candidate.runtime.getGlobal("rootFragilePower") == 4
  doAssert candidate.runtime.getGlobal("stateFragilePower") == 0
  doAssert candidate.runtime.getGlobalValue("utility").asFixed == 10'fx
  original.hail()
  changed.hail()
  doAssert not original.minionLocation(1).found
  doAssert changed.minionLocation(1).found
  doAssert changed.players[0].board[0].currentToughness == 1
  doAssert changed.players[0].board[0].power == 4

echo "Testing healthy armies retain the submitted choice"
block:
  var
    original = fixture(2)
    changed = original.copyGameState()
  let
    old = original.decide(Submitted)
    candidate = changed.decide(Candidate)
  doAssert old.playedHand == candidate.playedHand
  doAssert old.playedChoices == candidate.playedChoices
  doAssert candidate.runtime.getGlobal("rootFragilePower") == 0
  doAssert old.runtime.getGlobalValue("bestScore") ==
    candidate.runtime.getGlobalValue("bestScore")

echo "Testing repeated Shields cannot claim the same protection twice"
block:
  var game = fixture(1)
  game.players[0].hand = @[
    baseCardNamed("Shields"), baseCardNamed("Shields")
  ]
  let candidate = game.decide(Candidate)
  doAssert candidate.playedHand >= 0
  doAssert candidate.runtime.getGlobalValue("bestScore").asFixed < 3.2'fx

echo "Shields isolation checks passed"
