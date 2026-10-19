## Opt-in Fluffy profiling for deterministic server workloads.

const
  ProfileTracePath* {.strdefine.} = ""
  ProfileFrames* {.intdefine.} = 1440

when ProfileTracePath.len > 0:
  import
    std/os,
    fluffy/measure

  export measure

  var
    profileStarted = false
    profileDumped = false

  proc ensureProfileDir() =
    ## Creates the parent directory for the profile trace.
    let dir = ProfileTracePath.parentDir()
    if dir.len > 0:
      createDir(dir)

  proc startProfileTrace*() =
    ## Starts the Fluffy trace capture once.
    if profileStarted:
      return
    profileStarted = true
    ensureProfileDir()
    echo "Profile trace enabled: ", ProfileTracePath
    echo "Profile frames: ", ProfileFrames
    startTrace()

  proc finishProfileTrace*() =
    ## Stops and writes the Fluffy trace capture once.
    if not profileStarted or profileDumped:
      return
    profileDumped = true
    endTrace()
    ensureProfileDir()
    dumpMeasures(ProfileTracePath)

  proc profileShouldDump*(frames: int): bool =
    ## Returns true when the profile frame budget has elapsed.
    ProfileFrames > 0 and frames >= ProfileFrames and not profileDumped

  proc pushProfile*(name: string) =
    ## Starts one explicitly bounded profile region.
    measurePush(name)

  proc popProfile*() =
    ## Ends one explicitly bounded profile region.
    measurePop()

  template profileBlock*(name: string, body: untyped) =
    ## Measures a named block while profiling is enabled.
    measurePush(name)
    try:
      body
    finally:
      measurePop()
else:
  macro measure*(fn: untyped): untyped =
    ## Leaves a measured procedure unchanged when profiling is disabled.
    fn

  proc startProfileTrace*() =
    ## Leaves profiling disabled.
    discard

  proc finishProfileTrace*() =
    ## Leaves profiling disabled.
    discard

  proc profileShouldDump*(frames: int): bool =
    ## Returns false when profiling is disabled.
    false

  proc pushProfile*(name: string) =
    ## Leaves an explicit profile region disabled.
    discard

  proc popProfile*() =
    ## Leaves an explicit profile region disabled.
    discard

  template profileBlock*(name: string, body: untyped) =
    ## Runs a block without profiling.
    body
