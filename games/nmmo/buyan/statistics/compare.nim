## CLI for hosted XP paired comparison. No flags alter the experiment design.
## Usage: nim r compare.nim <plan.json> <activations.json> <episodes.json>...

import
  std/[os, json],
  comparisons

proc main() =
  ## Reads pinned plan, activations, and episode files and prints JSON.
  if paramCount() < 3:
    raise newException(BuyanError,
      "Usage: nim r compare.nim <plan.json> <activations.json> " &
      "<episodes.json>...")
  var paths: seq[string]
  for i in 3 .. paramCount():
    paths.add(paramStr(i))
  echo compareFiles(paramStr(1), paramStr(2), paths).pretty

main()
