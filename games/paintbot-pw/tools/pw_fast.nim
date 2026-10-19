## Paintbot PW games on the fast-XP server (Softmax tailnet only): fast-xp-k8s-staging,
## which runs the league engine; the old request/staging servers are offline (2026-10-08).
##
##   nim c -d:release -d:ssl -d:pwTraining --hints:off --warnings:off \
##     --path:$HOME/p/paintbot-pw-0124/examples/paintbot --path:$HOME/p/paintbot-pw-0124/src \
##     -o:tools/pw_fast tools/pw_fast.nim
##   tools/pw_fast run <tag> <our.bas | our:vN> <rival:vN> <side red|blue> <games> [seed]
##   tools/pw_fast score <tag> [<baseline tag>]
##
## `run` sends our BASIC source for the eight seats of one side and the rival's
## submitted policy for the other eight, in batches of at most 10 games, saves
## each response ZIP under eps/fast/<tag>/, re-simulates every replay to read the
## winner and glory, and appends one line per game to eps/fast/<tag>.tsv
## (rival, side, seed, our glory, their glory, ticks, request seconds). `score`
## prints wins and glory per rival and side, and against a baseline tag the
## win-rate z and glory Welch t, like pw_score.

import
  std/[algorithm, hashes, httpclient, json, math, monotimes, os, osproc, sequtils, strformat,
    strutils, tables, times],
  game, sim

const
  Servers = [
    "https://fast-xp-k8s-staging.tail0f4a29.ts.net"
  ]
  BatchLimit = 10

type
  Result = object
    rival, side: string
    seed: int
    ours, theirs: float
    ticks: int
    seconds: float

proc resimulate(path: string, ourParity: int): (float, float, int) =
  ## Re-simulates one replay and returns our glory, their glory and the ticks.
  let recording = loadRecording(path)
  var w = newWorld(recording.seed, recording.endTick)
  for frame in recording.frames:
    w.step(frame.commands, replayRulesVersion)
  let scores = w.scores()
  (scores[ourParity], scores[1 - ourParity], w.tick.int)

proc serverLoad(server: string): float =
  ## Returns the queued plus running paintbot games, or a large number when unreachable.
  try:
    let client = newHttpClient(timeout = 15_000)
    defer: client.close()
    let metrics = parseJson(client.getContent(server & "/v1/metrics?minutes=15"))
    for entry in metrics{"by_game"}:
      if entry{"game"}.getStr() == "paintbot-pw":
        return (entry{"queued"}.getInt(0) + entry{"running"}.getInt(0)).float
    0.0
  except CatchableError:
    1e9

proc serverOrder(): seq[string] =
  ## Lists the servers from least to most loaded.
  var loads: seq[(float, string)]
  for server in Servers:
    loads.add((serverLoad(server), server))
  loads.sort(proc(a, b: (float, string)): int = cmp(a[0], b[0]))
  loads.mapIt(it[1])

proc runBatch(tag, source, rival, side: string, seed, games: int): seq[Result] =
  ## Runs one batch, saves the ZIP, and scores its replays.
  let
    ourParity =
      if side == "red":
        0
      else:
        1
    directory = "eps/fast" / tag
  var roster = newJArray()
  for slot in 0 ..< 16:
    if slot mod 2 == ourParity:
      # A submitted policy (name:vN, e.g. a neural bundle) instead of source.
      if source.startsWith("policy_ref:"):
        roster.add %*{"slot": slot, "player": {"policy_ref": source["policy_ref:".len .. ^1]}}
      else:
        roster.add %*{"slot": slot, "player": {"source": source}}
    else:
      roster.add %*{"slot": slot, "player": {"policy_ref": rival}}
  let body = %*{"seed": seed, "roster": roster, "num_episodes": games}
  createDir(directory)
  let
    client = newHttpClient(timeout = 1_800_000)
    started = getMonoTime()
  client.headers = newHttpHeaders({"Content-Type": "application/json"})
  var
    response: Response
    used = ""
    failure = ""
  block send:
    for attempt in 0 ..< 20:
      # Least loaded server first; on a 429 or a failure try the other one.
      var wait = 30
      for server in serverOrder():
        try:
          response = client.post(server & "/v1/games/paintbot-pw/run", $body)
        except CatchableError as e:
          failure = server & ": " & e.msg
          continue
        used = server
        if response.code.int != 429:
          break send
        let retry = $response.headers.getOrDefault("Retry-After")
        if retry.len > 0:
          wait = min(wait, parseInt(retry))
      sleep(wait * 1000)
  let seconds = (getMonoTime() - started).inMilliseconds.float / 1000
  if used.len == 0:
    echo &"{rival} {side} seed {seed}: no server reachable ({failure})"
    return
  if not response.code.is2xx:
    echo &"{rival} {side} seed {seed}: HTTP {response.code} from {used} {response.body[0 ..< min(300, response.body.len)]}"
    return
  let
    name = &"{rival.replace(':', '_')}_{side}_{seed}"
    zipPath = directory / name & ".zip"
    unpacked = directory / name
  writeFile(zipPath, response.body)
  createDir(unpacked)
  discard execCmd("unzip -o -q " & quoteShell(zipPath) & " -d " & quoteShell(unpacked))
  echo &"{rival} {side} seed {seed}: {games} games in {seconds:.1f} s on {used}, server-timing: " &
    response.headers.getOrDefault("Server-Timing")
  var replays: seq[(int, string)]
  if fileExists(unpacked / "replay.replay"):
    replays.add((seed, unpacked / "replay.replay"))
  else:
    let manifest = parseJson(readFile(unpacked / "manifest.json"))
    var index = 0
    for g in manifest{"games"}.getElems:
      let status = g{"status"}.getStr("ok")
      let folder = unpacked / "games" / align($index, 3, '0')
      if status notin ["ok", "completed", "success"] or not fileExists(folder / "replay.replay"):
        echo &"  game {index}: status {status}"
      else:
        replays.add((seed + index, folder / "replay.replay"))
      inc index
  for (gameSeed, path) in replays:
    let (ours, theirs, ticks) = resimulate(path, ourParity)
    result.add Result(rival: rival, side: side, seed: gameSeed, ours: ours,
      theirs: theirs, ticks: ticks, seconds: seconds / max(replays.len, 1).float)

proc load(tag: string): seq[Result] =
  ## Reads a tag's results file.
  let path = "eps/fast" / tag & ".tsv"
  if not fileExists(path):
    return
  for line in lines(path):
    let f = line.split('\t')
    if f.len < 7:
      continue
    result.add Result(rival: f[0], side: f[1], seed: parseInt(f[2]),
      ours: parseFloat(f[3]), theirs: parseFloat(f[4]), ticks: parseInt(f[5]),
      seconds: parseFloat(f[6]))

proc mean(values: seq[float]): float =
  ## Returns the mean, 0 for none.
  if values.len == 0: 0.0 else: values.sum / values.len.float

proc variance(values: seq[float]): float =
  ## Returns the sample variance.
  if values.len < 2:
    return 0
  let m = mean(values)
  values.mapIt((it - m) ^ 2).sum / float(values.len - 1)

proc report(tag: string, results: seq[Result]) =
  ## Prints wins and glory per rival and side.
  echo &"## {tag}"
  echo "| rival | side | n | W | L | win % | glory/ep | seconds/game |"
  echo "|---|---|---:|---:|---:|---:|---:|---:|"
  var keys: seq[(string, string)]
  for r in results:
    if (r.rival, r.side) notin keys:
      keys.add((r.rival, r.side))
  proc row(label, side: string, group: seq[Result]) =
    let wins = group.countIt(it.ours > 0)
    let losses = group.countIt(it.theirs > 0)
    echo &"| {label} | {side} | {group.len} | {wins} | {losses} | " &
      &"{100.0 * wins.float / max(group.len, 1).float:.1f} | {mean(group.mapIt(it.ours)):.1f} | " &
      &"{mean(group.mapIt(it.seconds)):.1f} |"
  for (rival, side) in keys:
    row(rival, side, results.filterIt(it.rival == rival and it.side == side))
  row("**pooled**", "both", results)
  echo ""

proc compare(a, b: seq[Result]) =
  ## Prints the win-rate z and the glory Welch t, a minus b.
  let
    n1 = a.len.float
    n2 = b.len.float
    w1 = a.countIt(it.ours > 0).float
    w2 = b.countIt(it.ours > 0).float
    p = (w1 + w2) / max(n1 + n2, 1)
    se = sqrt(max(p * (1 - p) * (1 / max(n1, 1) + 1 / max(n2, 1)), 1e-12))
    g1 = a.mapIt(it.ours)
    g2 = b.mapIt(it.ours)
    t = (mean(g1) - mean(g2)) / sqrt(max(variance(g1) / max(n1, 1) + variance(g2) / max(n2, 1), 1e-12))
  echo &"win rate {100 * w1 / max(n1, 1):.1f}% vs {100 * w2 / max(n2, 1):.1f}%: z {(w1 / max(n1, 1) - w2 / max(n2, 1)) / se:.2f}"
  echo &"glory/ep {mean(g1):.1f} vs {mean(g2):.1f}: Welch t {t:.2f}"

proc main() =
  let arguments = commandLineParams()
  if arguments.len < 2:
    quit("usage: pw_fast run <tag> <our.bas | our:vN> <rival:vN> <red|blue> <games> [seed] | score <tag> [<baseline>]", 2)
  case arguments[0]
  of "run":
    let
      tag = arguments[1]
      source =
        if not fileExists(arguments[2]) and ":v" in arguments[2]:
          "policy_ref:" & arguments[2]
        else:
          readFile(arguments[2])
      rival = arguments[3]
      side = arguments[4]
      games = parseInt(arguments[5])
    var seed =
      if arguments.len > 6:
        parseInt(arguments[6])
      else:
        int(abs(hash(tag & rival & side)) mod 1_000_000_000)
    var remaining = games
    while remaining > 0:
      let batch = min(remaining, BatchLimit)
      let results = runBatch(tag, source, rival, side, seed, batch)
      var file = open("eps/fast" / tag & ".tsv", fmAppend)
      for r in results:
        file.writeLine(&"{r.rival}\t{r.side}\t{r.seed}\t{r.ours}\t{r.theirs}\t{r.ticks}\t{r.seconds:.2f}")
      file.close()
      remaining -= batch
      seed += batch
  of "score":
    let a = load(arguments[1])
    report(arguments[1], a)
    if arguments.len > 2:
      let b = load(arguments[2])
      report(arguments[2], b)
      compare(a, b)
  else:
    quit("unknown command " & arguments[0], 2)

main()
