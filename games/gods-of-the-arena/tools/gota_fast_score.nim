## Compares two khors versions from fast head-to-heads, paired by start.
##
##   gota_fast_score <prefix> <candidate version> <base version> [keys]
##
## keys is a comma list of opponent keys (default mack,pres,bewel); use
## "live" for gota_fast_live league-roster runs.
##
## Reads eps/fast/<prefix>_v<version>_<opponent>.tsv for every opponent key
## (mack, pres, bewel) written by gota_h2h. Each line is: side, seed, result
## (W, D or L), our kills, our deaths. A game scores W 1, D 0.5, L 0. Games of
## the two versions that share opponent, side and seed started the same, so
## the verdict uses the paired difference: KEEP needs t >= 2.

import std/[math, os, strformat, strutils, tables]

const
  Dir = "games/gods-of-the-arena/eps/fast"
  DefaultOpponents = ["mack", "pres", "bewel"]

proc points(outcome: string): float =
  ## Converts one game result to points.
  case outcome
  of "W": 1.0
  of "D": 0.5
  else: 0.0

proc load(path: string): Table[string, float] =
  ## Reads one tsv into points keyed by side and seed.
  if not fileExists(path):
    return
  for line in readFile(path).splitLines:
    let parts = line.split('\t')
    if parts.len < 3:
      continue
    result[parts[0] & " " & parts[1]] = points(parts[2])

proc record(games: Table[string, float]): string =
  ## Formats W, D and L counts.
  var wins, draws, losses = 0
  for value in games.values:
    if value == 1.0: inc wins
    elif value == 0.5: inc draws
    else: inc losses
  &"W{wins} D{draws} L{losses}"

proc mean(values: seq[float]): float =
  ## Returns the mean, or zero for no values.
  if values.len == 0: 0.0 else: sum(values) / values.len.float

proc main() =
  let arguments = commandLineParams()
  if arguments.len < 3:
    quit("usage: gota_fast_score <prefix> <candidate version> <base version> [keys]")
  let
    prefix = arguments[0]
    candidate = arguments[1]
    base = arguments[2]
  var
    diffs: seq[float]
    candidateAll, baseAll: seq[float]
  var opponents = @DefaultOpponents
  if arguments.len >= 4:
    opponents = arguments[3].split(',')
  for opponent in opponents:
    let
      ours = load(Dir / &"{prefix}_v{candidate}_{opponent}.tsv")
      theirs = load(Dir / &"{prefix}_v{base}_{opponent}.tsv")
    var
      candidatePoints, basePoints: seq[float]
    for key, value in ours:
      candidatePoints.add value
      candidateAll.add value
      if key in theirs:
        diffs.add value - theirs[key]
    for value in theirs.values:
      basePoints.add value
      baseAll.add value
    echo &"{opponent:6} v{candidate} {record(ours):16} {mean(candidatePoints):.3f} | " &
      &"v{base} {record(theirs):16} {mean(basePoints):.3f}"
  let
    n = diffs.len
    average = mean(diffs)
  var variance = 0.0
  for d in diffs:
    variance += (d - average) * (d - average)
  if n > 1:
    variance /= float(n - 1)
  let t = if variance > 0: average / sqrt(variance / n.float) else: 0.0
  echo &"all    v{candidate} {mean(candidateAll):.3f} over {candidateAll.len} | " &
    &"v{base} {mean(baseAll):.3f} over {baseAll.len}"
  let verdict =
    if t >= 2: "KEEP"
    elif t <= -2: "REVERT (worse)"
    else: "inconclusive"
  echo &"paired over {n} starts: diff {average:+.3f} points per game, t = {t:.2f}: {verdict}"

main()
