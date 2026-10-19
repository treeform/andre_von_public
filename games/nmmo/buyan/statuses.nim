import std/[json, os, strutils]

const Trials = ["armor", "clean", "escape", "sword", "hunt"]

type BuyanError = object of CatchableError

proc show(path: string) =
  ## Print request progress and candidate ownership without account details.
  if not fileExists(path):
    echo path.extractFilename(), ": absent"
    return
  try:
    let data = parseJson(readFile(path))
    echo data{"id"}.getStr(), " ", data{"status"}.getStr(), " ",
      data{"completed_count"}.getInt(), "/",
      data{"episode_count"}.getInt(), " failed=",
      data{"failed_count"}.getInt()
    let episodes = data{"episodes"}
    if episodes.kind == JArray and episodes.len > 0:
      for participant in episodes[0]{"participants"}:
        let name = participant{"policy_name"}.getStr()
        if name.startsWith("buyan"):
          echo "  ", participant{"label"}.getStr(), " ",
            participant{"player_name"}.getStr(), " ",
            participant{"policy_version_id"}.getStr()
  except CatchableError as error:
    raise newException(BuyanError, "Cannot read " & path & ": " &
      error.msg)

proc main() =
  ## Inspect every receipt for the requested immutable batch names.
  let directory = currentSourcePath().parentDir() / "experiments"
  for trial in Trials:
    echo trial
    for batch in commandLineParams():
      show(directory / trial / (batch & ".json"))

main()
