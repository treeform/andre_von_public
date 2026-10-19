import
  std/[os, json],
  replays

proc main() =
  ## Print one JSON summary for each replay path on the command line.
  for path in commandLineParams():
    echo reportJson(loadReplay(path), path)

main()

