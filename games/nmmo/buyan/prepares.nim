import std/[os, strutils]

type BuyanError = object of CatchableError

proc main() =
  ## Reuse the checked deployment recipe for an isolated candidate.
  let
    directory = currentSourcePath().parentDir()
    original = readFile(directory / "Dockerfile")
    oldCopy = "COPY games/nmmo/buyan/ ."
    newCopy = "ARG TRIAL\n" &
      "COPY games/nmmo/buyan/experiments/${TRIAL}/candidate.nim ./buyan.nim"
  if original.count(oldCopy) != 1:
    raise newException(BuyanError, "Deployment recipe changed.")
  writeFile(directory / "Dockerfile.experiment", original.replace(
    oldCopy,
    newCopy
  ))

main()
