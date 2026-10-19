import std/[os, strutils]

let repository = absolutePath(getEnv("POLYWORLD_REPO",
  currentSourcePath().parentDir / "../../../polyworld"))
switch("path", repository / "src")
switch("path", repository / "examples/awm/src/core")
for line in readFile(repository / "coworld/dependencies.lock").splitLines:
  let fields = line.splitWhitespace
  if fields.len > 0:
    let directory = repository / "tmp/coworld/deps" / fields[0]
    switch("path", directory / "src")
switch("define", "headless")
switch("define", "bassyNative")
switch("define", "flatty64")
