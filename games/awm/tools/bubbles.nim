## Measures Bubble uptime per seat in one or more replays: the share of
## other players' turn starts at which the seat had a Bubble on board,
## plus Bubble Shields cast, to compare shield timing policies.
##
##   bubbles REPLAY_OR_DIR...

import
  std/[os, strutils],
  zippy, sim, replays

type
  Tally = object
    checks, bubbled, shields, ownTurns: int

proc bubbled(game: GameState, seat: int): bool =
  ## True when the seat has a Bubble trinket on its board.
  for minion in game.players[seat].board:
    if minion.card.name == "Bubble":
      return true

proc tally(path: string, tallies: var seq[Tally]) =
  ## Adds one replay's turn starts and shield casts to the tallies.
  var raw = readFile(path)
  if raw.len > 2 and raw[0] == '\x1f':
    raw = uncompress(raw, dfGzip)
  let data = decodeReplayFile(ReplayGame, ReplayGameVersion, raw, ReplayData)
  var game = newGame(data.header.setup.heroClasses, data.header.setup.seed)
  if tallies.len < game.playerCount:
    tallies.setLen(game.playerCount)
  var lastTurn = -1
  for action in data.actions:
    if game.turnNumber != lastTurn:
      lastTurn = game.turnNumber
      let mover = game.currentPlayer
      inc tallies[mover].ownTurns
      for seat in 0 ..< game.playerCount:
        if seat != mover and not game.dead(seat):
          inc tallies[seat].checks
          if game.bubbled(seat):
            inc tallies[seat].bubbled
    if action.kind == ActionPlayCard:
      let seat = action.playerId.int
      let hand = game.players[seat].hand
      if action.handIndex.int in 0 ..< hand.len and
          hand[action.handIndex].name == "Bubble Shield":
        inc tallies[seat].shields
    discard game.applyAction(action)

proc main() =
  ## Prints one line per seat over all given replays.
  var tallies: seq[Tally]
  var games = 0
  for i in 1 .. paramCount():
    let arg = paramStr(i)
    if dirExists(arg):
      for path in walkFiles(arg / "*.replay"):
        tally(path, tallies)
        inc games
    else:
      tally(arg, tallies)
      inc games
  echo games, " games"
  for seat, t in tallies:
    let share =
      if t.checks > 0: 100 * t.bubbled div t.checks else: 0
    echo "seat ", seat, ": bubbled at others' turn starts ", t.bubbled,
      "/", t.checks, " (", share, "%) shields ", t.shields, " own turns ",
      t.ownTurns
main()
