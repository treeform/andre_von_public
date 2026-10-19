## Tallies, per seat, the cards still affordable when a turn ended, by
## card name, with the energy left, to find wasted energy in a policy.
##
##   held REPLAY_OR_DIR...

import
  std/[os, strutils, tables],
  zippy, sim, replays

type
  Tally = object
    turns, energyLeft: int
    held: CountTable[string]

proc tally(path: string, tallies: var seq[Tally]) =
  ## Adds one replay's turn ends to the per-seat tallies.
  var raw = readFile(path)
  if raw.len > 2 and raw[0] == '\x1f':
    raw = uncompress(raw, dfGzip)
  let data = decodeReplayFile(ReplayGame, ReplayGameVersion, raw, ReplayData)
  var game = newGame(data.header.setup.heroClasses, data.header.setup.seed)
  if tallies.len < game.playerCount:
    tallies.setLen(game.playerCount)
  for action in data.actions:
    if action.kind == ActionEndTurn:
      let seat = action.playerId.int
      let player = game.players[seat]
      inc tallies[seat].turns
      tallies[seat].energyLeft += player.energy
      for card in player.hand:
        if card.energyCost <= player.energy:
          tallies[seat].held.inc card.name
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
    var names: seq[string]
    for name, n in t.held:
      names.add name & " " & $n
    echo "seat ", seat, ": turns ", t.turns, " energy left ", t.energyLeft,
      " affordable at end: ", names.join(", ")
main()
