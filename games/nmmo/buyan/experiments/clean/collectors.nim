import std/[json, os, osproc, streams, strutils]

type BuyanError = object of CatchableError

proc capture(arguments: seq[string], destination: string) =
  ## Run one authorized read-only CLI command without shell interpretation.
  let process = startProcess(
    "uv",
    args = arguments,
    options = {poUsePath, poStdErrToStdOut}
  )
  defer: process.close()
  let
    output = process.outputStream.readAll()
    code = process.waitForExit()
  writeFile(destination, output)
  if code != 0:
    raise newException(BuyanError, "Artifact command failed; see " &
      destination & ".")

proc collect(path, directory, reference: string): int =
  ## Save complete episode metadata and our logs for a hosted request.
  let
    document = parseJson(readFile(path))
    episodes =
      if document.kind == JArray:
        document
      else:
        document["episodes"]
    colon = reference.rfind(':')
    name =
      if colon >= 0:
        reference[0 ..< colon]
      else:
        reference
  for episode in episodes:
    if episode{"status"}.getStr() != "completed":
      continue
    let
      id = episode["id"].getStr()
      target = directory / id
    createDir(target)
    writeFile(target / "episode.json", pretty(episode))
    for participant in episode["participants"]:
      if participant{"policy_name"}.getStr() notin ["buyan", name]:
        continue
      let
        position = participant["position"].getInt()
        log = target / ("agent_" & $position & ".log")
      if not fileExists(log):
        capture(
          @["--project", "/Users/me/p/metta", "run", "coworld",
            "episode-logs", id, "--agent", $position, "--output", log],
          log
        )
    if not fileExists(target / "game.log"):
      capture(
        @["--project", "/Users/me/p/metta", "run", "coworld",
          "episode-logs", id, "--game", "--output", target / "game.log"],
        target / "game.log"
      )
    inc result

proc main() =
  ## Collect completed XP artifacts from two saved request snapshots.
  if paramCount() notin [3, 4]:
    raise newException(BuyanError,
      "Expected two snapshots, output dir, and optional candidate ref.")
  try:
    let
      directory = paramStr(3)
      reference =
        if paramCount() == 4:
          paramStr(4)
        else:
          "buyan-clean:v1"
    createDir(directory)
    let count = collect(paramStr(1), directory, reference) +
      collect(paramStr(2), directory, reference)
    echo "Collected ", count, " completed episode metadata/log sets."
    if count > 0:
      capture(
        @["--project", "/Users/me/p/metta", "run", "coworld", "replays",
          "--policy", reference, "--download-dir", directory,
          "--limit", "30", "--json"],
        directory / "replays.json"
      )
  except BuyanError:
    raise
  except CatchableError:
    raise newException(BuyanError, "Cannot collect hosted clean artifacts.")

main()
