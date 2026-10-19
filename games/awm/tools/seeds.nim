## Lists the seeds of saved league replays and counts repeats.

import
  std/[json, os, tables],
  zippy, replays

let root = currentSourcePath().parentDir.parentDir / "eps" / "league"
var seen: CountTable[int32]
for e in parseJson(readFile(root / "status_rounds.json"))["episodes"]:
  let path = root / "replays" / e["job_id"].getStr & ".replay"
  if not fileExists(path):
    continue
  var raw = readFile(path)
  if raw.len > 2 and raw[0] == '\x1f':
    raw = uncompress(raw, dfGzip)
  let data = decodeReplayFile(ReplayGame, ReplayGameVersion, raw, ReplayData)
  seen.inc data.header.setup.seed
var repeats = 0
for seed, n in seen:
  if n > 1:
    inc repeats
echo "games ", seen.len, " distinct seeds, repeated seeds ", repeats
