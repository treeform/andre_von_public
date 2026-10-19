## Scores live-roster experience requests paired by roster, by team wins.
##
##   gota_live_score <dir> <tag> <base version> <cand version>
##
## Reads <dir>/<tag>_v<version>_<round>_<game>.json episode lists (saved
## `coworld xp-request episodes <id> --json`, entries format) and fetches each
## completed game from the observatory. Our team won when any hero on khors's
## side scored. For every roster present for both versions it compares the
## candidate's Elo points share (a win 1, a draw 0.5) with the base's, then
## reports totals and the paired t statistic over rosters. KEEP needs t >= 2
## in the candidate's favour on points; the win-share t is shown as well.

import std/[httpclient, json, math, os, strformat, strutils]

proc userToken(): string =
  ## Returns the user (not player) bearer token from the credentials file.
  var inTokens = false
  for line in readFile(getHomeDir() / ".softmax/credentials.yaml").splitLines:
    if line.startsWith("tokens:"):
      inTokens = true
    elif inTokens and "https" in line:
      return line.split(": ")[^1].strip(chars = {'"', ' '})
  quit("no user token in credentials.yaml")

proc wins(client: HttpClient, path: string): (int, int, int) =
  ## Returns (games, wins, losses of khors's team) for one saved episode list.
  for entry in parseJson(readFile(path))["entries"]:
    if entry{"status"}.getStr != "completed":
      continue
    let episode = parseJson(client.getContent(
      "https://softmax.com/api/observatory/v2/episode-requests/" & entry["id"].getStr))
    var side = -1
    for p in episode{"participants"}:
      if p{"policy_name"}.getStr == "khors":
        side = p["position"].getInt div 5
    if side < 0:
      continue
    var ours, theirs = 0.0
    for s in episode{"participant_scores"}:
      if s["position"].getInt div 5 == side:
        ours += s["score"].getFloat
      else:
        theirs += s["score"].getFloat
    inc result[0]
    if ours > 0:
      inc result[1]
    elif theirs > 0:
      inc result[2]

proc main() =
  if paramCount() < 4:
    quit("usage: gota_live_score <dir> <tag> <base version> <cand version>")
  let
    dir = paramStr(1)
    tag = paramStr(2)
    base = paramStr(3)
    cand = paramStr(4)
    prefix = &"{tag}_v{base}_"
    client = newHttpClient(timeout = 60_000)
  client.headers = newHttpHeaders({"Authorization": "Bearer " & userToken()})
  var
    diffs, pointDiffs: seq[float]
    baseGames, baseWins, baseLosses, candGames, candWins, candLosses = 0
  for path in walkFiles(dir / prefix & "*.json"):
    let
      key = path.extractFilename[prefix.len .. ^6]
      other = dir / &"{tag}_v{cand}_{key}.json"
    if not fileExists(other):
      continue
    let
      (bg, bw, bl) = wins(client, path)
      (cg, cw, cl) = wins(client, other)
    if bg == 0 or cg == 0:
      continue
    baseGames += bg
    baseWins += bw
    candGames += cg
    candWins += cw
    baseLosses += bl
    candLosses += cl
    diffs.add cw / cg - bw / bg
    pointDiffs.add (cw.float + 0.5 * (cg - cw - cl).float) / cg.float -
      (bw.float + 0.5 * (bg - bw - bl).float) / bg.float
  let n = diffs.len
  if n < 2:
    quit("fewer than two paired rosters")
  proc paired(xs: seq[float]): (float, float) =
    ## Returns the mean difference and its paired t statistic.
    var mean, variance = 0.0
    for d in xs:
      mean += d
    mean /= xs.len.float
    for d in xs:
      variance += (d - mean) * (d - mean)
    variance /= (xs.len - 1).float
    (mean, (if variance > 0: mean / sqrt(variance / xs.len.float) else: 0.0))
  let
    (mean, t) = paired(diffs)
    (pointMean, pointT) = paired(pointDiffs)
  echo &"rosters {n}: v{base} W{baseWins} D{baseGames - baseWins - baseLosses} L{baseLosses} of {baseGames}, " &
    &"v{cand} W{candWins} D{candGames - candWins - candLosses} L{candLosses} of {candGames}"
  echo &"paired win-share diff {mean * 100:+.1f} per roster, t = {t:.2f}; " &
    &"Elo points diff {pointMean * 100:+.1f} per roster, t = {pointT:.2f}"
  echo "verdict: ", (if pointT >= 2.0: "KEEP" elif pointT <= -2.0: "REVERT (significant loss)" else: "inconclusive")

main()
