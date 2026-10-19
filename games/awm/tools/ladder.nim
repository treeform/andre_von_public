import
  std/[os, strformat, strutils],
  bassy,
  sim, bots, match

type
  AwmError = object of CatchableError
  Tally = object
    games, wins, failures: int
    instructions, work: int64
    ratio: float
    classGames, classWins: array[HeroClass, int]

proc parseSeeds(text: string): int =
  ## Parses a positive seed count with a game-specific diagnostic.
  try:
    result = parseInt(text)
  except ValueError as error:
    raise newException(AwmError, "Invalid seed count: " & error.msg)
  if result <= 0:
    raise newException(AwmError, "Seed count must be positive")

proc evaluate(source, baseline: string, seeds: int): Tally =
  ## Rotates one candidate through every seat against four base policies.
  for seed in 0 ..< seeds:
    for seat in 0 ..< 5:
      let
        gameSeed = 1000 + seed * 37
        classes = [HeroClass(seed mod 3), HeroClass((seed + 1) mod 3),
          HeroClass((seed + 2) mod 3), HeroClass(seed mod 3),
          HeroClass((seed + 1) mod 3)]
      var sources = @[baseline, baseline, baseline, baseline, baseline]
      sources[seat] = source
      let vms = loadBots(sources)
      for vm in vms:
        if vm.failed:
          raise newException(AwmError, vm.lastError)
      var
        failures = 0
        played = initBotMatch(classes, gameSeed, vms, 5000)
      played.scriptError = proc(player: int, message: string) =
        ## Records script failures and disables the failed policy.
        inc failures
        vms[player].failed = true
        echo "Failure: ", message, "; seed ", gameSeed, "; seat ", player
        if player == seat and "budgetUsed" in source:
          for name in ["budgetUsed", "iteration", "count", "depth",
              "nextReserve", "rootPower", "rootThreat"]:
            echo name, ": ", vms[player].runtime.getGlobal(name)
      while played.step():
        result.instructions = max(result.instructions,
          vms[seat].runtime.instructionsUsed)
        result.work = max(result.work, vms[seat].runtime.workUsed)
        if "budgetUsed" in source:
          let estimate = vms[seat].runtime.getGlobal("budgetUsed")
          if estimate > 0 and vms[seat].runtime.workUsed > 100_000:
            result.ratio = max(result.ratio,
              vms[seat].runtime.workUsed.float / estimate.float)
      result.failures += failures
      inc result.games
      inc result.classGames[classes[seat]]
      if played.game.winner == seat:
        inc result.wins
        inc result.classWins[classes[seat]]
  echo &"Games {result.games}, wins {result.wins}, " &
    &"failures {result.failures}, peak instructions {result.instructions}, " &
    &"peak work {result.work}"
  echo &"Maximum work / estimate: {result.ratio:.3f}"
  for heroClass in HeroClass:
    echo heroClass, " wins ", result.classWins[heroClass], " / ",
      result.classGames[heroClass]

proc main() =
  ## Runs a local diagnostic ladder with explicit source and seed inputs.
  if paramCount() < 2:
    raise newException(AwmError,
      "Usage: ladder candidate.bas baseline.bas [seeds]")
  let
    candidate = readFile(paramStr(1))
    baseline = readFile(paramStr(2))
    seeds = if paramCount() > 2: parseSeeds(paramStr(3)) else: 12
    tally = evaluate(candidate, baseline, seeds)
  doAssert tally.failures == 0

main()
