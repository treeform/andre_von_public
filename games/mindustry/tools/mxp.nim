## Scores hosted XP requests for one of our Mindustry policies.
##
## nim r -d:release --hints:off tools/mxp.nim <label> <xreq,...> [<xreq,...>]
##
## Prints win, draw and loss counts for the seats that ran <label> (for
## example polkan:v2) and the mean seat score. A second comma-separated
## group is compared with the first by Welch t on per-episode scores.

import
  std/[json, math, os, osproc, strutils]

type
  Group = object
    scores: seq[float]
    wins, draws, losses, unfinished: int

proc cli(arguments: string): JsonNode =
  ## Runs one coworld CLI command and parses its JSON, or returns nil.
  let
    command = "uvx --from \"" & getHomeDir() /
      "p/metta-coworld-cli/packages/coworld[auth]\" coworld " & arguments
    (output, code) = execCmdEx(command,
      options = {poUsePath, poStdErrToStdOut, poEvalCommand})
  if code != 0:
    return nil
  var start = -1
  for i, c in output:
    if c in {'[', '{'}:
      start = i
      break
  if start < 0:
    return nil
  try:
    result = parseJson(output[start .. ^1])
  except CatchableError:
    result = nil

proc scoreGroup(label, requests: string): Group =
  ## Collects our seat score from every completed episode of the requests.
  for request in requests.split(','):
    let episodes = cli("xp-request episodes " & request & " --json")
    if episodes == nil:
      echo request, ": no episode list"
      continue
    for episode in episodes["entries"]:
      let id = episode["id"].getStr
      if episode["status"].getStr != "completed":
        inc result.unfinished
        continue
      let
        results = cli("episode-results " & id)
        detail = cli("episodes " & id & " --json")
      if results == nil or detail == nil:
        inc result.unfinished
        continue
      var score = -1.0
      for participant in detail["participants"]:
        if participant["label"].getStr == label:
          let slot = participant["position"].getInt
          score = results["scores"][slot].getFloat
      if score < 0:
        continue
      result.scores.add score
      if score >= 100:
        inc result.wins
      elif score <= 0:
        inc result.losses
      else:
        inc result.draws
      echo request[0 ..< 13], " ", id[0 ..< 13], " ",
        results["outcome"].getStr, " ticks ", results["ticks"].getInt,
        " score ", score.int

proc mean(values: seq[float]): float =
  ## Returns the mean, or zero for an empty list.
  if values.len == 0:
    return 0.0
  sum(values) / values.len.float

proc variance(values: seq[float]): float =
  ## Returns the sample variance, or zero below two values.
  if values.len < 2:
    return 0.0
  let m = mean(values)
  for value in values:
    result += (value - m) * (value - m)
  result /= (values.len - 1).float

proc report(name: string, group: Group) =
  ## Prints one group's tally.
  echo name, ": n ", group.scores.len, " wins ", group.wins, " draws ",
    group.draws, " losses ", group.losses, " unfinished ", group.unfinished,
    " mean ", formatFloat(mean(group.scores), ffDecimal, 1)

proc main() =
  ## Scores one group, or compares two groups.
  let args = commandLineParams()
  if args.len < 2:
    quit("Usage: mxp <label> <xreq,...> [<xreq,...>]", 2)
  let first = scoreGroup(args[0], args[1])
  report("A", first)
  if args.len > 2:
    let
      label = if args.len > 3: args[3] else: args[0]
      second = scoreGroup(label, args[2])
    report("B", second)
    let error = sqrt(variance(first.scores) / max(first.scores.len, 1).float +
      variance(second.scores) / max(second.scores.len, 1).float)
    if error > 0:
      echo "Welch t (A - B): ", formatFloat(
        (mean(first.scores) - mean(second.scores)) / error, ffDecimal, 2)
    else:
      echo "Welch t: no variance (means ",
        formatFloat(mean(first.scores), ffDecimal, 1), " vs ",
        formatFloat(mean(second.scores), ffDecimal, 1), ")"

main()
