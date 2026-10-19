import std/[os, strutils]

const Experiments = [
  "occupancy", "topstack", "soak", "haste", "recovery",
  "routes", "sieging", "sustain", "casting", "targets"
]

type MobaError = object of CatchableError

proc main() =
  ## Specialize the existing policy container for one isolated candidate.
  if paramCount() != 1 or paramStr(1) notin Experiments:
    raise newException(MobaError, "Supply a known experiment name")
  let
    experiment = paramStr(1)
    directory = "games/moba/gorynych/experiments" / experiment
    original = readFile("games/moba/gorynych/Dockerfile")
    generated = original.replace(
      "COPY games/moba/gorynych/ .",
      "COPY " & directory & "/candidate.nim ./gorynych.nim"
    )
  if generated == original:
    raise newException(MobaError, "Container template changed")
  writeFile(directory / "Dockerfile", generated)
  echo directory / "Dockerfile"

main()
