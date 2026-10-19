## Tallies every Bouncer cast in one or more replays by the target's power
## and by whether the target could attack on its owner's next turn, per
## seat, to measure wasted bounces.
##
##   bounces REPLAY_OR_DIR...

import
  std/[os, strutils],
  zippy, sim, replays

type
  Tally = object
    none, zero, one, big, body: int

proc tally(path: string, tallies: var seq[Tally]) =
  ## Adds one replay's Bouncer casts to the per-seat tallies.
  var raw = readFile(path)
  if raw.len > 2 and raw[0] == '\x1f':
    raw = uncompress(raw, dfGzip)
  let data = decodeReplayFile(ReplayGame, ReplayGameVersion, raw, ReplayData)
  var game = newGame(data.header.setup.heroClasses, data.header.setup.seed)
  if tallies.len < game.playerCount:
    tallies.setLen(game.playerCount)
  for action in data.actions:
    if action.kind == ActionPlayCard:
      let seat = action.playerId.int
      let hand = game.players[seat].hand
      if action.handIndex.int in 0 ..< hand.len and
          hand[action.handIndex].name == "Bouncer":
        if action.choices.len == 0:
          inc tallies[seat].body
        else:
          let target = action.choices[0].toChoice
          if target.kind != CreatureChoice:
            inc tallies[seat].none
          else:
            let location = game.minionLocation(target.creatureId)
            if not location.found:
              inc tallies[seat].none
            else:
              let power =
                game.players[location.player].board[location.index].power
              if power == 0:
                inc tallies[seat].zero
              elif power == 1:
                inc tallies[seat].one
              else:
                inc tallies[seat].big
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
    echo "seat ", seat, ": Bouncer targets power0 ", t.zero, " power1 ",
      t.one, " power2+ ", t.big, " none ", t.none, " body ", t.body
main()
