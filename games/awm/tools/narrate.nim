## Narrates one hosted AWM replay turn by turn: every card played with its
## targets, every attack, and the life totals, so a rival's logic can be
## read off the record.
##
##   narrate GAME.raw LABEL0|LABEL1|... [SEAT_FILTER]

import
  std/[os, strformat, strutils],
  sim, replays

proc minionName(game: GameState, owner, id: int): string =
  ## The printed name and stats of a minion on a board.
  for m in game.players[owner].board:
    if m.id == id:
      return &"{m.card.name}({m.power}/{m.currentToughness})"
  "?"

proc lives(game: GameState): string =
  for p in 0 ..< game.playerCount:
    result.add &" {p}:{game.players[p].life}"
    if game.dead(p):
      result.add "x"

proc main() =
  ## Prints the narrative.
  let data = loadReplay(paramStr(1))
  let labels = paramStr(2).split('|')
  let filterSeat = if paramCount() >= 3: parseInt(paramStr(3)) else: -1
  let setup = data.header.setup
  var game = newGame(setup)
  for seat, label in labels:
    echo "seat ", seat, " ", label, " ", setup.heroClasses[seat]
  var lastTurn = -1
  for action in data.actions:
    let acting = action.playerId.int
    if game.turnNumber != lastTurn:
      lastTurn = game.turnNumber
      echo &"-- turn {game.turnNumber} seat {game.currentPlayer} energy {game.players[game.currentPlayer].energy} hand {game.players[game.currentPlayer].hand.len} lives{game.lives}"
    var text = ""
    case action.kind
    of ActionPlayCard:
      let hand = game.players[acting].hand
      if action.handIndex.int in 0 ..< hand.len:
        text = "plays " & hand[action.handIndex].name
      for c in action.choices:
        case c.kind
        of 2: text.add &" -> hero {c.owner}"
        of 3: text.add &" -> {c.owner}:{game.minionName(c.owner.int, c.creatureId.int)}"
        of 4: text.add &" -> option {c.option}"
        else: text.add " -> none"
    of ActionAttack:
      text = "attack " & game.minionName(acting, action.attacker.int)
      for c in action.choices:
        if c.kind == 2:
          text.add &" -> hero {c.owner}"
        else:
          text.add &" -> {c.owner}:{game.minionName(c.owner.int, c.creatureId.int)}"
    of ActionEndTurn:
      text = "end turn, energy left " & $game.players[acting].energy
    of ActionResolveTrigger:
      text = "trigger"
      for c in action.choices:
        case c.kind
        of 2: text.add &" -> hero {c.owner}"
        of 3: text.add &" -> {c.owner}:{game.minionName(c.owner.int, c.creatureId.int)}"
        of 4: text.add &" -> option {c.option}"
        else: text.add " -> none"
    of ActionToss:
      text = "discards " & $action.indices.len
    else:
      text = "?"
    if filterSeat < 0 or acting == filterSeat:
      echo &"  [{acting}] {text}"
    if not game.applyAction(action):
      echo "refused at tick ", action.tick
      break
  echo &"winner {game.winner} turn {game.turnNumber} lives{game.lives}"

main()
