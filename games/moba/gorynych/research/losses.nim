## Summarise a directory of reconstruction JSON files (trajectories
## output) next to their .txt console logs: final tick, winner, tower
## deaths per side for the Andre von Auto seat. Reconstruction facts
## only. Not a score source.

import std/[algorithm, json, os, strutils, tables]

proc main() =
  if paramCount() != 1:
    quit("Usage: losses <directory of reconstruction json>", 1)
  var rows: seq[string]
  var perOpponent = initTable[string, (int, int, seq[int])]()
  for path in walkFiles(paramStr(1) / "*.json"):
    let logPath = path.changeFileExt("txt")
    if not fileExists(logPath):
      continue
    var ourSeat = -1
    var opponent = "?"
    for line in readFile(logPath).splitLines():
      let s = line.strip()
      if s.startsWith("radiant (") or s.startsWith("dire ("):
        let name = s[s.find('(') + 1 ..< s.find(')')]
        let seat = if s.startsWith("radiant"): 0 else: 1
        if name.contains("Andre"): ourSeat = seat else: opponent = name
    if ourSeat < 0:
      continue
    let j = parseFile(path)
    let ticks = j{"tick_count"}.getInt
    let winner = j{"sim_winner"}.getStr
    let weWon = (winner == "radiant" and ourSeat == 0) or
      (winner == "dire" and ourSeat == 1)
    var ourTowers = 0
    var theirTowers = 0
    var firstTheirs = -1
    for e in j{"tower_deaths"}.getElems():
      let pid = e{"pid"}.getInt
      if (pid < 5) == (ourSeat == 0):
        inc ourTowers
      else:
        inc theirTowers
        if firstTheirs < 0: firstTheirs = e{"tick"}.getInt
    rows.add(opponent & " seat=" & $ourSeat & " ticks=" & align($ticks, 6) &
      " won=" & $weWon & " heroTowerKills us/them=" & $ourTowers & "/" &
      $theirTowers & " theirFirstTowerKill=" & $firstTheirs)
    var entry = perOpponent.getOrDefault(opponent, (0, 0, @[]))
    inc entry[0]
    if weWon: inc entry[1]
    entry[2].add ticks
    perOpponent[opponent] = entry
  rows.sort()
  for r in rows: echo r
  for opponent, (games, wins, ticks) in perOpponent:
    var sorted = ticks
    sorted.sort()
    echo opponent, ": games=", games, " wins=", wins,
      " median ticks=", sorted[sorted.len div 2], " min=", sorted[0],
      " max=", sorted[^1]

main()
