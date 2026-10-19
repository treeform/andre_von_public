## Scores live-roster experience requests paired by roster.
##
##   nim r games/gods-of-the-arena/tools/gota_paired.nim <dir> <tag> <base> <cand>
##
## Reads <dir>/<tag>_v<version>_<round>_<game>.json episode lists (from
## `coworld xp-request episodes <id> --json`). For every roster present for
## both versions it takes khors's mean glory per arm, then reports the
## paired difference over rosters with its t statistic, plus the pooled
## per-game means and win counts. KEEP needs t >= 2 in the candidate's favour.

import std/[json, os, math, strformat, strutils, tables]

type
  Arm = object
    scores: seq[float]

proc armOf(path: string): Arm =
  ## Collects khors's score from every completed episode in one file.
  let data = parseJson(readFile(path))
  for episode in data:
    if episode{"status"}.getStr != "completed":
      continue
    var position = -1
    for p in episode["participants"]:
      if p{"policy_name"}.getStr == "khors":
        position = p["position"].getInt
    if position < 0:
      continue
    for s in episode["participant_scores"]:
      if s["position"].getInt == position:
        result.scores.add s["score"].getFloat

proc mean(xs: seq[float]): float =
  ## Returns the mean, or 0 for an empty sample.
  if xs.len == 0:
    return 0.0
  for x in xs:
    result += x
  result / xs.len.float

proc stdev(xs: seq[float]): float =
  ## Returns the sample standard deviation.
  if xs.len < 2:
    return 0.0
  let m = mean(xs)
  for x in xs:
    result += (x - m) * (x - m)
  sqrt(result / (xs.len - 1).float)

proc wins(xs: seq[float]): int =
  ## Counts games our hero scored in (glory is paid only to winners).
  for x in xs:
    if x > 0:
      inc result

proc main() =
  if paramCount() < 4:
    quit("usage: gota_paired.nim <dir> <tag> <base version> <cand version>")
  let
    dir = paramStr(1)
    tag = paramStr(2)
    base = paramStr(3)
    cand = paramStr(4)
    basePrefix = &"{tag}_v{base}_"
  var
    diffs: seq[float]
    allBase, allCand: seq[float]
    rosters = initTable[string, (float, float)]()
  for path in walkFiles(dir / basePrefix & "*.json"):
    let
      key = path.extractFilename[basePrefix.len .. ^6]
      other = dir / &"{tag}_v{cand}_{key}.json"
    if not fileExists(other):
      continue
    let
      a = armOf(path)
      b = armOf(other)
    if a.scores.len == 0 or b.scores.len == 0:
      continue
    allBase.add a.scores
    allCand.add b.scores
    diffs.add mean(b.scores) - mean(a.scores)
    rosters[key] = (mean(a.scores), mean(b.scores))
  let
    n = diffs.len
    d = mean(diffs)
    t =
      if n > 1 and stdev(diffs) > 0:
        d / (stdev(diffs) / sqrt(n.float))
      else:
        0.0
  echo &"rosters {n}: v{base} {mean(allBase):.1f} ({wins(allBase)} wins of {allBase.len}) " &
    &"v{cand} {mean(allCand):.1f} ({wins(allCand)} wins of {allCand.len})"
  echo &"paired diff {d:+.1f} per roster, t = {t:.2f}"
  echo "verdict: ", (if t >= 2.0: "KEEP" elif t <= -2.0: "REVERT (significant loss)" else: "inconclusive")

main()
