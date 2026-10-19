include telemetry

const
  Focal = "gorynych-occupancy-20260912:v1"
  Opponent = "moba-example:v1"
  Idea = "occupancy-aware navigation"
  OtherIdea = "topstack"
  FocalVersion = "policy-focal"
  OtherVersion = "policy-other"

proc bytesRepr(inner: string): string =
  ## Python bytes repr with literal backslash-n, not real line breaks.
  result = "b'"
  for c in inner:
    case c
    of '\n': result.add "\\n"
    of '\'': result.add "\\'"
    of '\\': result.add "\\\\"
    else: result.add c
  result.add "'"

proc trialLine(
  idea: string, calls, triggers, changed: int, event = ""
): string =
  ## One compact MOBA_TRIAL object, matching candidate stdout.
  var node = %*{
    "idea": idea,
    "heroCalls": calls,
    "triggers": triggers,
    "changedActions": changed
  }
  if event.len > 0:
    node["event"] = %event
  TrialMark & " " & $node

proc logBody(idea: string, calls, triggers, changed: int): string =
  ## Connected, first trial, done trial, episode-done trailer.
  let
    firstTriggers = min(triggers, 1)
    firstChanged = min(changed, 1)
  "gorynych: connected\n" &
    trialLine(idea, min(calls, 1000), firstTriggers, firstChanged) & "\n" &
    trialLine(idea, calls, triggers, changed, "done") & "\n" &
    "gorynych: episode done, result {}\n"

proc sampleHeader(seat, noopTicks: int, dead: bool): JsonNode =
  ## Minimal valid v1 header with per-seat noop and dead-agent fields.
  var
    noops = newJArray()
    deadSeats = newJArray()
  for i in 0 .. 1:
    noops.add %(if i == seat: noopTicks else: 0)
    deadSeats.add %(dead and i == seat)
  result = %*{
    "format_version": 1,
    "sim_wasm_sha256": "ab".repeat(32),
    "config": {
      "seed": 77,
      "heroes_per_seat": 5,
      "players": [{"name": "alpha"}, {"name": "beta"}]
    },
    "result": {
      "end_reason": "ancient",
      "final_tick": 1,
      "noop_ticks": noops,
      "dead_seats": deadSeats,
      "noop_causes": [
        {"timeout": 0, "malformed": 0, "wrong_tick": 0,
          "disconnected": 0, "host_error": 0},
        {"timeout": 0, "malformed": 0, "wrong_tick": 0,
          "disconnected": 0, "host_error": 0}
      ]
    },
    "tick_count": 1
  }

proc sampleBody(): string =
  ## One tick of engine no-op rows.
  result = newString(BytesPerTick)
  var offset = 0
  for pid in 0 ..< NumHeroes:
    for value in [3'u8, 3, 0, 0, 0, 0]:
      result[offset] = char(value)
      inc offset

proc writeReplay(path: string, seat, noopTicks: int, dead: bool) =
  ## Pack a one-tick replay beside an episode log.
  writeFile(path, packReplay(sampleHeader(seat, noopTicks, dead), sampleBody()))

proc episodeNode(id: string, seat: int): JsonNode =
  ## Two distinct real policies and one focal seat.
  let
    focal = %*{
      "position": seat,
      "kind": "policy",
      "policy_version_id": FocalVersion,
      "is_filler": false,
      "label": Focal
    }
    other = %*{
      "position": 1 - seat,
      "kind": "policy",
      "policy_version_id": OtherVersion,
      "is_filler": false,
      "label": Opponent
    }
  result = %*{"id": id, "status": "completed", "participants": []}
  if seat == 0:
    result["participants"].add focal
    result["participants"].add other
  else:
    result["participants"].add other
    result["participants"].add focal

proc writeRequest(
  root, requestId: string,
  n, triggers, changed: int,
  idea = Idea,
  reprLog = true,
  skipLog = false,
  deadFirst = false
): string =
  ## Write current.json plus n episode files under root/requestId.
  let directory = root / requestId
  createDir(directory)
  var episodes = newJArray()
  for i in 0 ..< n:
    let
      id = "ereq_" & requestId & "_" & $i
      seat = i mod 2
      calls = 1000 + i
    writeReplay(
      directory / (id & ".replay"),
      seat, i, deadFirst and i == 0
    )
    if not skipLog:
      let body = logBody(idea, calls, triggers, changed)
      writeFile(
        directory / (id & ".log"),
        if reprLog: bytesRepr(body) else: body
      )
    episodes.add episodeNode(id, seat)
  result = root / (requestId & ".current.json")
  writeFile(result, pretty(%*{
    "id": requestId,
    "status": "completed",
    "episode_count": n,
    "episodes": episodes
  }))

let root = getTempDir() / "gorynych-telemetry-test"
if dirExists(root):
  removeDir(root)
createDir(root)

echo "Bytes repr logs"
let raw = bytesRepr(logBody(Idea, 2500, 4, 3))
doAssert '\n' notin raw.strip()[0 .. ^2]
doAssert "\\n" in raw
let trials = extractTrials(raw)
doAssert trials.len == 2
doAssert trials[0]["idea"].getStr == Idea
doAssert trials[0]["heroCalls"].getInt == 1000
doAssert trials[1]["event"].getStr == "done"
doAssert trials[1]["triggers"].getInt == 4
doAssert trials[1]["changedActions"].getInt == 3
let prettyLog = """
MOBA_TRIAL {
  "idea": "occupancy-aware navigation",
  "heroCalls": 8,
  "triggers": 2,
  "changedActions": 1
}
"""
doAssert extractTrials(prettyLog).len == 1
doAssert extractTrials(prettyLog)[0]["heroCalls"].getInt == 8

echo "Ten qualifying games open the trigger gate"
let passPath = writeRequest(root, "xreq_pass", 10, 5, 4, deadFirst = true)
let passed = verifyFiles(Focal, Idea, [passPath])
doAssert passed["triggerGate"].getBool
doAssert passed["notProofOfImprovement"].getBool
doAssert passed["episodes"].getInt == 10
doAssert passed["triggeredGames"].getInt == 10
doAssert passed["qualifyGames"].getInt == 10
doAssert passed["changedActions"].getInt == 40
doAssert passed["totalCalls"].getInt == 1000 * 10 + 45
doAssert passed["noopTicks"].getInt == 45
doAssert passed["deadSeats"].getInt == 1
doAssert passed["perEpisode"].len == 10
doAssert passed["perEpisode"][0]["trials"].getInt == 2
doAssert passed["perEpisode"][0]["activated"].getBool
doAssert passed["perEpisode"][0]["changed"].getBool

echo "Nine games cannot open the trigger gate"
let ninePath = writeRequest(root, "xreq_nine", 9, 2, 2)
let nine = verifyFiles(Focal, Idea, [ninePath])
doAssert not nine["triggerGate"].getBool
doAssert nine["qualifyGames"].getInt == 9

echo "Zero triggers leave the gate closed"
let zeroPath = writeRequest(root, "xreq_zero", 10, 0, 0)
let zero = verifyFiles(Focal, Idea, [zeroPath])
doAssert not zero["triggerGate"].getBool
doAssert zero["triggeredGames"].getInt == 0
doAssert zero["changedActions"].getInt == 0
doAssert zero["qualifyGames"].getInt == 0
doAssert zero["perEpisode"][0]["trials"].getInt == 2

echo "Missing logs fail closed"
let missingPath = writeRequest(
  root, "xreq_missing", 1, 3, 3, skipLog = true
)
var missing = false
try:
  discard verifyFiles(Focal, Idea, [missingPath])
except MobaError as error:
  missing = true
  doAssert "Missing log" in error.msg
doAssert missing

echo "Mismatched idea fails closed"
let mismatchPath = writeRequest(
  root, "xreq_mismatch", 1, 3, 3, idea = OtherIdea
)
var mismatched = false
try:
  discard verifyFiles(Focal, Idea, [mismatchPath])
except MobaError as error:
  mismatched = true
  doAssert "Idea mismatch" in error.msg
doAssert mismatched

echo "Real-newline logs still parse"
let plainPath = writeRequest(
  root, "xreq_plain", 10, 1, 1, reprLog = false
)
doAssert verifyFiles(Focal, Idea, [plainPath])["triggerGate"].getBool

removeDir(root)
echo "Telemetry checks passed"
