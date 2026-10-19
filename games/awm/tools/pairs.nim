## Lists paired fast-XP games where candidate B won and candidate A lost,
## or the reverse, from two status files run on the same seeds and seats.
##
##   pairs REPLAY_DIR STATUS_A.json STATUS_B.json [b|a]
##
## Prints one line per discordant game: A job, B job, our class, winner
## labels. The optional last argument keeps only games B won (b) or A won.

import
  std/[json, os, strutils],
  zippy, sim, match, replays

proc winner(path: string): tuple[seat: int, classes: seq[HeroClass]] =
  ## Applies a replay's actions and returns the winning seat, or -1.
  var raw = readFile(path)
  if raw.len > 2 and raw[0] == '\x1f' and raw[1] == '\x8b':
    raw = uncompress(raw, dfGzip)
  let data = decodeReplayFile(ReplayGame, ReplayGameVersion, raw, ReplayData)
  var game = newGame(data.header.setup.heroClasses, data.header.setup.seed)
  for action in data.actions:
    discard game.applyAction(action)
  result.classes = data.header.setup.heroClasses
  result.seat = if game.gameOver: game.winner else: -1

proc main() =
  ## Walks both status files in episode order and prints discordant games.
  if paramCount() < 3:
    quit("Usage: pairs REPLAY_DIR STATUS_A STATUS_B [b|a]", 1)
  let
    directory = paramStr(1)
    a = parseJson(readFile(paramStr(2)))["episodes"]
    b = parseJson(readFile(paramStr(3)))["episodes"]
    keep = if paramCount() >= 4: paramStr(4) else: ""
  if a.len != b.len:
    quit("pairs: status files differ in length", 1)
  var gained, lost = 0
  for g in 0 ..< a.len:
    var oursA, oursB = -1
    var labelsA, labelsB: seq[string]
    for p in a[g]["participants"]:
      labelsA.add p["label"].getStr
      if p["label"].getStr.startsWith("radogost:"):
        oursA = p["position"].getInt
    for p in b[g]["participants"]:
      labelsB.add p["label"].getStr
      if p["label"].getStr.startsWith("radogost:"):
        oursB = p["position"].getInt
    let
      jobA = a[g]["job_id"].getStr
      jobB = b[g]["job_id"].getStr
      wa = winner(directory / jobA & ".replay")
      wb = winner(directory / jobB & ".replay")
      wonA = wa.seat == oursA
      wonB = wb.seat == oursB
    if wonA == wonB:
      continue
    if wonB:
      inc gained
    else:
      inc lost
    if (keep == "b" and not wonB) or (keep == "a" and not wonA):
      continue
    echo jobA, " ", jobB, " ", wa.classes[oursA], " A=",
      (if wa.seat >= 0: labelsA[wa.seat] else: "-"), " B=",
      (if wb.seat >= 0: labelsB[wb.seat] else: "-")
  echo "B gained ", gained, ", lost ", lost

main()
