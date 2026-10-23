## Fetch a hosted experience request's episodes and replays.
## The episode list comes from the coworld CLI (it owns the softmax
## session, so no token handling here); the replays are public S3
## objects and are downloaded directly, gzipped, and named by episode
## request id so games/<game>/tools/replay_stats.nim can consume them.
## Run: nim r --hints:off -d:ssl tools/xp_fetch.nim <xreq_id> <eps.json> [replay_dir]

import std/[httpclient, json, os, osproc, strutils], zippy

proc episodesJson(requestId: string): JsonNode =
  let (output, code) = execCmdEx(
    "uvx --from " & quoteShell(getHomeDir() / "p/metta-coworld-cli/packages/coworld[auth]") &
    " coworld xp-request episodes " & requestId & " --json",
    options = {poUsePath, poStdErrToStdOut})
  var start = output.find('{')
  let arrayStart = output.find('[')
  if start < 0 or (arrayStart >= 0 and arrayStart < start):
    start = arrayStart
  if code != 0 or start < 0:
    quit("coworld xp-request episodes failed:\n" & output, 1)
  let parsed = parseJson(output[start .. ^1])
  if parsed.kind == JArray: parsed
  elif parsed.hasKey("entries"): parsed["entries"]
  else: parsed["episodes"]

proc main() =
  if paramCount() < 2:
    quit("usage: xp_fetch <xreq_id> <eps.json> [replay_dir]", 2)
  let
    requestId = paramStr(1)
    episodesPath = paramStr(2)
    replayDir = if paramCount() >= 3: paramStr(3) else: ""
    episodes = episodesJson(requestId)
  writeFile(episodesPath, $episodes)
  var complete = 0
  for episode in episodes:
    if episode{"status"}.getStr == "completed": inc complete
  echo requestId, ": ", episodes.len, " episodes, ", complete, " completed -> ", episodesPath
  if replayDir == "":
    return
  createDir(replayDir)
  let client = newHttpClient(timeout = 120_000)
  var saved = 0
  for episode in episodes:
    let url = episode{"replay_url"}.getStr
    if url == "":
      continue
    let target = replayDir / episode{"id"}.getStr & ".replay.gz"
    if fileExists(target):
      inc saved
      continue
    var body = client.getContent(url)
    if body.len < 2 or body[0] != '\x1f' or body[1] != '\x8b':
      body = compress(body, dataFormat = dfGzip)
    writeFile(target, body)
    inc saved
  echo saved, " replays in ", replayDir

main()
