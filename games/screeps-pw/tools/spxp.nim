## Hosted experience requests for Screeps PW.
## launch: one request per opponent and seat order (fixed slots).
## score: per-episode GCL for our policy, split by start room.
## compare: Welch t on our GCL per seat between two request sets.
## Usage:
##   nim r tools/spxp.nim launch <policy:vN> <episodes> <tag> <opp:vN>...
##   nim r tools/spxp.nim score <policy> <xreq>...
##   nim r tools/spxp.nim compare <policy> <base xreqs,> <cand xreqs,>
##   nim r tools/spxp.nim log <xreq> [episode index]

import
  std/[json, math, os, osproc, strformat, strutils]

const
  League = "league_ac545b38-4caa-4873-a202-769697261f26"
  Rooms = ["W3N3", "W2N2"]

type
  SpxpError = object of CatchableError
  Game = object
    request: string
    seat: int
    ours: float
    theirs: float
    opponent: string

proc cli(args: string): string =
  ## Runs the coworld CLI, retrying transient server errors.
  let command = "uvx --from \"" & getHomeDir() /
    "p/metta-coworld-cli/packages/coworld[auth]\" coworld " & args
  for attempt in 0 ..< 4:
    let (output, code) = execCmdEx(command, options = {poUsePath,
      poEvalCommand, poStdErrToStdOut})
    if code == 0:
      return output
    let transient = "HTTP 50" in output or "timed out" in output
    if not transient or attempt == 3:
      raise newException(SpxpError, "coworld " & args & " failed:\n" & output)
    sleep(5_000 * (attempt + 1))

proc launch(policy: string, episodes: int, tag: string, opponents: seq[string]) =
  ## Creates two fixed-slot requests per opponent and logs their ids.
  let dir = currentSourcePath().parentDir.parentDir / "xps"
  createDir(dir)
  var lines: seq[string]
  for opponent in opponents:
    for seat in 0 .. 1:
      var roster = newJArray()
      roster.add %*{"slot": seat, "player": {"policy_ref": policy}}
      roster.add %*{"slot": 1 - seat, "player": {"policy_ref": opponent}}
      let body = %*{
        "idempotency_key": "spxp-" & tag & "-" & policy & "-" & opponent &
          "-s" & $seat & "-" & $episodes,
        "target": {"league_id": League},
        "num_episodes": episodes,
        "roster": roster,
        "notes": &"{policy} in {Rooms[seat]} vs {opponent} ({tag})"
      }
      let path = getTempDir() / &"spxp_{tag}_{seat}.json"
      writeFile(path, $body)
      var output = ""
      for attempt in 0 ..< 6:
        try:
          output = cli("xp-request create " & quoteShell(path) & " --json")
          break
        except SpxpError as error:
          if "429" notin error.msg or attempt == 5:
            raise
          sleep(60_000)
      let start = output.find('{')
      let id = parseJson(output[start .. ^1])["id"].getStr
      let line = &"{tag} {policy} seat{seat} {Rooms[seat]} vs {opponent} {id}"
      echo line
      lines.add line
  let log = dir / "requests.txt"
  let old = if fileExists(log): readFile(log) else: ""
  writeFile(log, old & lines.join("\n") & "\n")

proc jsonOf(output: string): JsonNode =
  ## Parses the first JSON value in CLI output.
  let start = output.find({'{', '['})
  if start < 0:
    raise newException(SpxpError, "no JSON in output:\n" & output)
  parseJson(output[start .. ^1])

proc resultOf(episode: string): JsonNode =
  ## Returns an episode's results, cached on disk once final.
  let dir = currentSourcePath().parentDir.parentDir / "xps" / "eps"
  createDir(dir)
  let path = dir / episode & ".json"
  if fileExists(path):
    return parseJson(readFile(path))
  result = jsonOf(cli("episode-results " & episode))
  writeFile(path, $result)

proc games(policy: string, requests: seq[string]): seq[Game] =
  ## Returns our completed games across requests.
  let name = policy.split(':')[0]
  for request in requests:
    let info = jsonOf(cli("xp-request get " & request & " --json"))
    var
      seat = -1
      opponent = ""
    for r in info["requested"]["roster"]:
      if r["policy"].getStr.split(':')[0] == name:
        seat = r["slot"].getInt
      else:
        opponent = r["policy"].getStr
    if seat < 0:
      continue
    for episode in info["episodes"]:
      if episode{"status"}.getStr != "completed":
        continue
      let scores = resultOf(episode["id"].getStr){"scores"}
      if scores.isNil or scores.len < 2:
        continue
      result.add Game(request: request, seat: seat,
        ours: scores[seat].getFloat, theirs: scores[1 - seat].getFloat,
        opponent: opponent)

proc stats(values: seq[float]): (float, float) =
  ## Returns mean and sample standard deviation.
  if values.len == 0:
    return (NaN, NaN)
  let mean = values.sum / values.len.float
  var squares = 0.0
  for v in values:
    squares += (v - mean) ^ 2
  let sd = if values.len > 1: sqrt(squares / float(values.len - 1)) else: 0.0
  (mean, sd)

proc score(policy: string, requests: seq[string]) =
  ## Prints per-episode GCL and a per-seat summary.
  let all = games(policy, requests)
  for g in all:
    let outcome =
      if g.ours > g.theirs: "win"
      elif g.ours < g.theirs: "loss"
      else: "draw"
    echo &"{g.request[0 .. 12]} {Rooms[g.seat]} ours {g.ours:8.0f} " &
      &"{g.opponent} {g.theirs:8.0f} {outcome}"
  for seat in 0 .. 1:
    var values: seq[float]
    var wins = 0
    for g in all:
      if g.seat == seat:
        values.add g.ours
        if g.ours > g.theirs: inc wins
    let (mean, sd) = stats(values)
    echo &"{Rooms[seat]}: n {values.len} mean {mean:.0f} sd {sd:.0f} " &
      &"wins {wins}/{values.len}"

proc welch(a, b: seq[float]): (float, float) =
  ## Returns the difference of means and the Welch t statistic.
  let (ma, sa) = stats(a)
  let (mb, sb) = stats(b)
  let se = sqrt(sa ^ 2 / a.len.float + sb ^ 2 / b.len.float)
  let t = if se > 0: (mb - ma) / se else: (if mb > ma: Inf else: -Inf)
  (mb - ma, t)

proc compare(policy: string, base, candidate: seq[string]) =
  ## Compares our GCL per seat between two sets of requests.
  let
    a = games(policy, base)
    b = games(policy, candidate)
  for seat in 0 .. 1:
    var x, y: seq[float]
    for g in a:
      if g.seat == seat: x.add g.ours
    for g in b:
      if g.seat == seat: y.add g.ours
    let (diff, t) = welch(x, y)
    echo &"{Rooms[seat]}: base n {x.len} cand n {y.len} diff {diff:+.0f} t {t:.2f}"

proc showLog(request: string, index: int) =
  ## Prints our private seat log lines for one episode of a request.
  let info = jsonOf(cli("xp-request get " & request & " --json"))
  var seat = -1
  for r in info["requested"]["roster"]:
    if r["policy"].getStr.startsWith("mokosh"):
      seat = r["slot"].getInt
  var done: seq[string]
  for episode in info["episodes"]:
    if episode{"status"}.getStr == "completed":
      done.add episode["id"].getStr
  if index >= done.len:
    quit(&"only {done.len} completed episodes", 1)
  let output = cli("episode-logs " & done[index] & " --agent " & $seat)
  echo done[index], " seat ", seat
  for line in output.splitLines:
    let start = line.find("\"message\":\"")
    if start < 0:
      continue
    let rest = line[start + 11 .. ^1]
    echo rest[0 ..< rest.find('"')]

proc main() =
  ## Dispatches the subcommand.
  let args = commandLineParams()
  if args.len < 2:
    quit("usage: spxp launch|score|compare ...", 2)
  case args[0]
  of "launch":
    launch(args[1], parseInt(args[2]), args[3], args[4 .. ^1])
  of "score":
    score(args[1], args[2 .. ^1])
  of "compare":
    compare(args[1], args[2].split(','), args[3].split(','))
  of "log":
    showLog(args[1], if args.len > 2: parseInt(args[2]) else: 0)
  else:
    quit("unknown command " & args[0], 2)

main()
