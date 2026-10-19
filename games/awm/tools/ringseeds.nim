## Lists the seed and first mover of every replay in a directory and counts
## repeated seeds, to check that ring requests sample independent games.
##
##   ringseeds REPLAY_DIR

import
  std/[os, strutils, tables],
  zippy, sim, replays

proc main() =
  ## Prints one line per replay and a seed summary.
  let directory = paramStr(1)
  var seen: CountTable[int32]
  var firsts: CountTable[int]
  for path in walkFiles(directory / "*.replay"):
    var raw = readFile(path)
    if raw.len > 2 and raw[0] == '\x1f':
      raw = uncompress(raw, dfGzip)
    let data = decodeReplayFile(ReplayGame, ReplayGameVersion, raw, ReplayData)
    let game = newGame(data.header.setup.heroClasses, data.header.setup.seed)
    seen.inc data.header.setup.seed
    firsts.inc game.currentPlayer
    echo path.extractFilename.split('.')[0], " seed ", data.header.setup.seed,
      " first ", game.currentPlayer
  var repeats = 0
  for seed, n in seen:
    if n > 1:
      inc repeats
  echo "games ", seen.len, " distinct seeds, repeated seeds ", repeats
  for seat in 0 .. 4:
    echo "first mover seat ", seat, ": ", firsts[seat]

main()
