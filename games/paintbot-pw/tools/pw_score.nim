## Scores Paintbot PW experience requests for one of our policies.
##
##   nim r tools/pw_score.nim <tag> [<baseline tag>] [--replays]
##
## Reads eps/<tag>.txt (lines "<xreq id> <side> <rival ref>" from pw_xp),
## caches each request as eps/xp/<xreq>.json and prints, per rival and
## pooled, our wins, draws, losses and mean glory per episode (a loss or a
## draw scores 0). With a baseline tag it also prints a two-proportion z on
## the win rate and a Welch t on glory per episode, candidate minus
## baseline. --replays downloads each episode's replay into
## eps/replays/<tag>/ for pw_stats. Every call appends the policy version
## ids it saw to eps/names.txt.

import
  std/[httpclient, json, math, os, osproc, sequtils, strformat, strutils, tables]

type
  Episode = object
    id, rival, side, replay: string
    ours, theirs: float

proc cli(): string =
  ## Returns the coworld CLI command backed by the stable metta checkout.
  "uvx --from " & quoteShell(getHomeDir() / "p/metta-coworld-cli/packages/coworld[auth]") &
    " coworld"

proc request(id: string): JsonNode =
  ## Returns one request's JSON, from the cache once it has completed.
  let path = "eps/xp" / id & ".json"
  if fileExists(path):
    return parseJson(readFile(path))
  let (output, code) = execCmdEx(
    cli() & " xp-request get " & id & " --json",
    options = {poUsePath, poEvalCommand}
  )
  let start = output.find('{')
  if code != 0 or start < 0:
    quit("pw_score: xp-request get failed for " & id & "\n" & output, 1)
  result = parseJson(output[start .. ^1])
  if result["status"].getStr in ["completed", "failed"]:
    createDir("eps/xp")
    writeFile(path, $result)

proc rememberNames(node: JsonNode, names: var Table[string, string]) =
  ## Records policy version id to label for every participant.
  for p in node{"participants"}.getElems:
    names[p["policy_version_id"].getStr] = p["policy_name"].getStr & ":v" & $p["version"].getInt

proc load(tag: string, names: var Table[string, string]): seq[Episode] =
  ## Loads every completed episode listed under one tag.
  var pending = 0
  for line in lines("eps" / tag & ".txt"):
    let parts = line.splitWhitespace
    if parts.len < 3:
      continue
    let
      data = request(parts[0])
      side = parts[1]
      ourParity =
        if side == "red":
          0
        else:
          1
    for e in data["episodes"]:
      if e["status"].getStr != "completed":
        if e["status"].getStr notin ["failed", "cancelled"]:
          inc pending
        continue
      rememberNames(e, names)
      var
        ours = NaN
        theirs = NaN
      for s in e["participant_scores"]:
        let position = s["position"].getInt
        if position mod 2 == ourParity:
          ours = s["score"].getFloat
        else:
          theirs = s["score"].getFloat
      result.add Episode(
        id: e["id"].getStr,
        rival: parts[2],
        side: side,
        replay: e{"replay_url"}.getStr,
        ours: ours,
        theirs: theirs
      )
  if pending > 0:
    echo &"({tag}: {pending} episodes still running)"

proc wins(episodes: seq[Episode]): int =
  ## Counts episodes our side won.
  episodes.countIt(it.ours > 0)

proc losses(episodes: seq[Episode]): int =
  ## Counts episodes the rival won.
  episodes.countIt(it.theirs > 0)

proc mean(values: seq[float]): float =
  ## Returns the arithmetic mean, 0 for no values.
  if values.len == 0:
    return 0
  values.sum / values.len.float

proc variance(values: seq[float]): float =
  ## Returns the sample variance.
  if values.len < 2:
    return 0
  let m = mean(values)
  values.mapIt((it - m) * (it - m)).sum / float(values.len - 1)

proc wilson(k, n: int): (float, float) =
  ## Returns the 95% Wilson interval of k successes in n.
  if n == 0:
    return (0.0, 1.0)
  let
    z = 1.96
    p = k / n
    d = 1 + z * z / n.float
    c = (p + z * z / (2 * n.float)) / d
    h = z * sqrt(p * (1 - p) / n.float + z * z / (4 * n.float * n.float)) / d
  (c - h, c + h)

proc report(tag: string, episodes: seq[Episode]) =
  ## Prints the per-rival and pooled table for one arm.
  echo &"## {tag}"
  echo "| rival | side | n | W | D | L | win % | 95% Wilson | glory/ep | glory/win |"
  echo "|---|---|---:|---:|---:|---:|---:|---|---:|---:|"
  var groups: seq[(string, string)]
  for e in episodes:
    if (e.rival, e.side) notin groups:
      groups.add((e.rival, e.side))
  proc row(label, side: string, group: seq[Episode]) =
    let
      n = group.len
      w = wins(group)
      l = losses(group)
      (lo, hi) = wilson(w, n)
      winGlory = group.filterIt(it.ours > 0).mapIt(it.ours)
    echo &"| {label} | {side} | {n} | {w} | {n - w - l} | {l} | " &
      &"{100.0 * w.float / max(n, 1).float:.1f} | [{lo:.2f}, {hi:.2f}] | " &
      &"{mean(group.mapIt(it.ours)):.1f} | {mean(winGlory):.1f} |"
  for (rival, side) in groups:
    row(rival, side, episodes.filterIt(it.rival == rival and it.side == side))
  row("**pooled**", "both", episodes)
  echo ""

proc compare(candidate, baseline: seq[Episode]) =
  ## Prints the win-rate z and the glory Welch t, candidate minus baseline.
  let
    n1 = candidate.len.float
    n2 = baseline.len.float
    p1 = wins(candidate).float / max(n1, 1)
    p2 = wins(baseline).float / max(n2, 1)
    pooled = (wins(candidate) + wins(baseline)).float / max(n1 + n2, 1)
    se = sqrt(max(pooled * (1 - pooled) * (1 / max(n1, 1) + 1 / max(n2, 1)), 1e-12))
    g1 = candidate.mapIt(it.ours)
    g2 = baseline.mapIt(it.ours)
    t = (mean(g1) - mean(g2)) /
      sqrt(max(variance(g1) / max(n1, 1) + variance(g2) / max(n2, 1), 1e-12))
  echo &"win rate {p1 * 100:.1f}% vs {p2 * 100:.1f}%: z {(p1 - p2) / se:.2f}"
  echo &"glory/ep {mean(g1):.1f} vs {mean(g2):.1f}: Welch t {t:.2f}"

proc download(tag: string, episodes: seq[Episode]) =
  ## Downloads every episode's replay, gunzipped when needed.
  let directory = "eps/replays" / tag
  createDir(directory)
  let client = newHttpClient(timeout = 120_000)
  for e in episodes:
    let path = directory / e.id & ".replay"
    if fileExists(path) or e.replay == "":
      continue
    let body = client.getContent(e.replay)
    if body.len > 2 and body[0] == '\x1f' and body[1] == '\x8b':
      writeFile(path & ".gz", body)
      discard execCmd("gunzip -f " & quoteShell(path & ".gz"))
    else:
      writeFile(path, body)
  echo &"replays in {directory}"

proc main() =
  var
    tags: seq[string]
    replays = false
  for argument in commandLineParams():
    if argument == "--replays":
      replays = true
    else:
      tags.add argument
  if tags.len == 0:
    quit("usage: pw_score <tag> [<baseline tag>] [--replays]", 2)
  var names = initTable[string, string]()
  if fileExists("eps/names.txt"):
    for line in lines("eps/names.txt"):
      let parts = line.splitWhitespace
      if parts.len == 2:
        names[parts[0]] = parts[1]
  let candidate = load(tags[0], names)
  report(tags[0], candidate)
  if tags.len > 1:
    let baseline = load(tags[1], names)
    report(tags[1], baseline)
    compare(candidate, baseline)
  if replays:
    download(tags[0], candidate)
  var text = ""
  for id, label in names:
    text.add id & " " & label & "\n"
  writeFile("eps/names.txt", text)

main()
