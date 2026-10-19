## Paintbot PW game endings: how each pw_fast game ended, from its replay.
##
##   nim c -d:release -d:ssl -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw-0124/examples/paintbot --path:$HOME/p/paintbot-pw-0124/src \
##     --path:tools -o:tools/pw_ends tools/pw_ends.nim
##   tools/pw_ends <pw_fast dirs eps/fast/<tag>>...
##
## One line per game (our side from the directory name): ticks, our and their living cogs and
## hearts at the end, who won, and the ending: elimination, meter, or the time limit. Then a
## summary of our losses and wins by ending.

import
  std/[os, strformat, strutils, tables],
  game, sim

proc ending(w: World, ours, theirs: int): string =
  ## Names how the match ended from the final state.
  if ours == 0 or theirs == 0:
    "elimination"
  elif w.tick >= w.endTick:
    "time"
  else:
    "meter"

proc main() =
  var
    lossEnds = initCountTable[string]()
    winEnds = initCountTable[string]()
    lossTicks, winTicks: int
  echo "| game | ticks | ours alive | theirs alive | ours hearts | theirs hearts | result | ending |"
  echo "|---|---:|---:|---:|---:|---:|---|---|"
  for input in commandLineParams():
    for path in walkDirRec(input):
      if not path.endsWith(".replay"):
        continue
      let parts = path.split(DirSep)
      if parts.len < 4 or parts[^3] != "games":
        continue
      let batch = parts[^4].split('_')
      if batch.len != 4:
        continue
      let side = if batch[2] == "red": 0 else: 1
      let recording = loadRecording(path)
      var w = newWorld(recording.seed, recording.endTick)
      for frame in recording.frames:
        w.step(frame.commands, replayRulesVersion)
      var alive: array[2, int]
      for i in 0 ..< Seats:
        if w.cogs[i].hp > 0:
          inc alive[team(i)]
      var hearts: array[2, int]
      for h in w.controlHearts:
        if h.owner >= 0:
          inc hearts[h.owner]
      let
        scores = w.scores()
        won = scores[side] > scores[1 - side]
        kind = ending(w, alive[side], alive[1 - side])
        label = parts[^4] & "/" & parts[^2]
      if won:
        winEnds.inc kind
        winTicks += w.tick.int
      else:
        lossEnds.inc kind
        lossTicks += w.tick.int
      echo &"| {label} | {w.tick} | {alive[side]} | {alive[1 - side]} | {hearts[side]} | {hearts[1 - side]} | {(if won: \"win\" else: \"loss\")} | {kind} |"
  var wins, losses: int
  for k, n in winEnds:
    wins += n
  for k, n in lossEnds:
    losses += n
  echo ""
  echo &"wins {wins} (mean {(if wins > 0: winTicks div wins else: 0)} ticks): " & $winEnds
  echo &"losses {losses} (mean {(if losses > 0: lossTicks div losses else: 0)} ticks): " & $lossEnds

main()
