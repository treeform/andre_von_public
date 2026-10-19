## Tallies every hero attack in one or more replays by the target's seat
## relation to the attacker (the living seat before it, the next living
## seat, or another) and counts 5+ power hits dealt and taken per seat,
## to prove a targeting change fired and to size Primordial damage.
##
##   attacks REPLAY_OR_DIR...

import
  std/[os, strutils],
  zippy, sim, replays

type
  Tally = object
    prev, next, other, damage: int
    bigHits, bigTaken, bigDamageTaken: int

proc previousPlayer(game: GameState, player: int): int =
  ## The living player before `player`.
  result = player
  for step in 1 ..< game.playerCount:
    let candidate = (player - step + game.playerCount) mod game.playerCount
    if not game.dead(candidate):
      return candidate

proc tally(path: string, tallies: var seq[Tally]) =
  ## Adds one replay's hero attacks to the per-seat tallies.
  var raw = readFile(path)
  if raw.len > 2 and raw[0] == '\x1f':
    raw = uncompress(raw, dfGzip)
  let data = decodeReplayFile(ReplayGame, ReplayGameVersion, raw, ReplayData)
  var game = newGame(data.header.setup.heroClasses, data.header.setup.seed)
  if tallies.len < game.playerCount:
    tallies.setLen(game.playerCount)
  for action in data.actions:
    if action.kind == ActionAttack and action.choices.len == 1:
      let target = action.choices[0].toChoice
      if target.kind == HeroChoice:
        let
          seat = action.playerId.int
          location = game.minionLocation(action.attacker.int)
        var power = 0
        if location.found:
          power = game.players[location.player].board[location.index].power
        if target.owner == game.previousPlayer(seat) and
            target.owner != game.nextPlayer(seat):
          inc tallies[seat].prev
        elif target.owner == game.nextPlayer(seat):
          inc tallies[seat].next
        else:
          inc tallies[seat].other
        tallies[seat].damage += power
        if power >= 5:
          inc tallies[seat].bigHits
          inc tallies[target.owner].bigTaken
          tallies[target.owner].bigDamageTaken += power
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
    echo "seat ", seat, ": hero attacks prev ", t.prev, " next ", t.next,
      " other ", t.other, " damage ", t.damage, " big hits dealt ",
      t.bigHits, " taken ", t.bigTaken, " (", t.bigDamageTaken, " damage)"
main()
