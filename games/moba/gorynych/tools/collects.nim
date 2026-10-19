import std/[httpclient, json, os, osproc, streams, strutils]

type MobaError = object of CatchableError

proc command(arguments: seq[string]): string =
  ## Run the installed Coworld CLI with explicit arguments.
  let process = startProcess(
    "uv",
    args = @["--project", "/Users/me/p/metta", "run", "coworld"] & arguments,
    options = {poUsePath, poStdErrToStdOut}
  )
  defer:
    process.close()
  result = process.outputStream.readAll()
  if process.waitForExit() != 0:
    raise newException(MobaError, "Coworld request failed: " & result)

proc main() =
  ## Refresh hosted XP and collect each focal player's replay and log.
  if paramCount() < 2:
    raise newException(MobaError, "Usage: collects policy requestFiles")
  let
    label = paramStr(1)
    client = newHttpClient(timeout = 60_000)
  defer:
    client.close()
  for path in commandLineParams()[1 .. ^1]:
    let
      original = parseFile(path)
      id = original["id"].getStr
      output = command(@["xp-request", "get", id, "--json"])
      request = parseJson(output)
      directory = parentDir(path) / id
    writeFile(path.changeFileExt("current.json"), request.pretty & "\n")
    createDir(directory)
    echo id, " ", request["status"].getStr, " ",
      request["completed_count"].getInt, "/", request["episode_count"].getInt
    for episode in request["episodes"]:
      if episode["status"].getStr != "completed":
        continue
      let
        episodeId = episode["id"].getStr
        replayPath = directory / (episodeId & ".replay")
        logPath = directory / (episodeId & ".log")
      var seat = -1
      for participant in episode["participants"]:
        if participant["label"].getStr == label:
          seat = participant["position"].getInt
      if seat < 0:
        raise newException(MobaError, "Focal policy absent: " & episodeId)
      if not fileExists(replayPath):
        writeFile(replayPath, client.getContent(episode["replay_url"].getStr))
      if not fileExists(logPath):
        let log = command(@["episode-logs", episodeId, "--agent", $seat])
        writeFile(logPath, log)
      echo "  collected ", episodeId, " seat ", seat

main()
