import std/[json, os, tables]

proc main() =
  ## Print concise metadata from a hosted XP response.
  for path in commandLineParams():
    let node = parseFile(path)
    echo path
    for key in ["id", "status", "episode_count", "completed_count",
      "pending_count", "running_count", "failed_count", "error"]:
      if node.hasKey(key):
        echo "  ", key, ": ", node[key]
    var seats = initCountTable[string]()
    for episode in node{"episodes"}:
      for player in episode{"participants"}:
        seats.inc(player{"label"}.getStr & " seat " &
          $player{"position"}.getInt & " player " &
          player{"player_id"}.getStr)
    for key, count in seats:
      echo "  ", key, ": ", count

main()
