import std/[os, strutils]

type BuyanError = object of CatchableError

proc main() =
  ## Restore hosted log stdout saved under the collector receipt extension.
  let root = currentSourcePath().parentDir() / "experiments"
  var restored = 0
  for trial in ["armor", "clean", "escape", "sword", "hunt"]:
    let directory = root / trial / "hosted"
    if not dirExists(directory):
      continue
    for path in walkDirRec(directory):
      if not path.extractFilename().startsWith("agent_") or
        not path.endsWith(".receipt"):
          continue
      let destination = path.changeFileExt("log")
      if fileExists(destination):
        continue
      let content = readFile(path)
      if not content.startsWith("b'") and
        not content.startsWith("b\"") and
        not content.startsWith("buyan:"):
          raise newException(BuyanError, "Unexpected log wrapper: " & path)
      copyFile(path, destination)
      inc restored
  echo "Restored ", restored, " exact hosted logs."

main()
