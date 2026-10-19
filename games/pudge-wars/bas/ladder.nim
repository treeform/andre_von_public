## Local BASIC-bot ladder for Pudge Wars. Runs the headless engine
## (sims/pudge-wars/pwheadless) for a candidate .bas against one or more
## reference .bas scripts across seeds and both banks, and prints wins,
## losses, draws, kill margins, and VM failures. Duel (1v1) by default;
## --three plays 3v3 clone teams (the league format); --pairs plays 2v2
## (two copies a side, --team-size 2). --first N starts at seed N.
## --log DIR keeps the engine's duel logs under DIR/<ref>/s<seed>_<side>.
##
##   nim r --hints:off games/pudge-wars/bas/ladder.nim CAND.bas REF.bas [REF2.bas ...]
##     [--seeds N] [--three] [--goal K] [--minutes M] [--json OUT]
##
## Every seed runs twice (candidate west, then east) so side bias
## cancels. A "VM FAILURE" means a script died or blew its 20k budget.

import std/[os, osproc, strutils, strformat, json, times]

type
  Outcome = object
    seed: int
    candWest: bool
    west, east: int
    result: string
    active: bool

proc engineDir(): string =
  getCurrentDir() / "sims" / "pudge-wars"

proc runMatch(engine, cand, reference: string, seed: int, candWest, three, pairs: bool,
    goal, minutes: int, logDir: string): Outcome =
  let
    a = if candWest: cand else: reference
    b = if candWest: reference else: cand
    per = if three: "3" elif pairs: "2" else: "1"
    mode = if three: "" elif pairs: " --team-size 2" else: " --duel"
    logFlag =
      if logDir.len == 0: ""
      else: &" --duellog \"{logDir / reference.extractFilename.changeFileExt(\"\") / (\"s\" & $seed & (if candWest: \"_west\" else: \"_east\"))}\""
    command = &"./pwheadless{mode} --bot \"{a}:{per}\" --bot \"{b}:{per}\" " &
      &"--seed {seed} --killGoal {goal} --minutes {minutes}{logFlag}"
  let (output, _) = execCmdEx(command, workingDir = engine, options = {poUsePath, poStdErrToStdOut})
  result = Outcome(seed: seed, candWest: candWest, result: "vmfail")
  let want = if three: "6/6" elif pairs: "4/4" else: "2/2"
  for line in output.splitLines:
    if line.startsWith("score: west"):
      let parts = line.split(' ')
      result.west = parseInt(parts[2])
      result.east = parseInt(parts[5])
    elif line.startsWith("scripts: ") and (want & " active") in line:
      result.active = true
  if not result.active:
    return
  let candKills = if candWest: result.west else: result.east
  let refKills = if candWest: result.east else: result.west
  result.result =
    if candKills > refKills: "win"
    elif candKills < refKills: "loss"
    else: "draw"

proc main() =
  var
    cand = ""
    refs: seq[string]
    seeds = 6
    three = false
    pairs = false
    engineOverride = ""
    first = 1
    logDir = ""
    goal = 10
    minutes = 10
    jsonOut = ""
  var i = 1
  while i <= paramCount():
    let arg = paramStr(i)
    case arg
    of "--seeds":
      inc i
      seeds = parseInt(paramStr(i))
    of "--three": three = true
    of "--pairs": pairs = true
    of "--engine":
      inc i
      engineOverride = paramStr(i).absolutePath
    of "--first":
      inc i
      first = parseInt(paramStr(i))
    of "--log":
      inc i
      logDir = paramStr(i).absolutePath
    of "--goal":
      inc i
      goal = parseInt(paramStr(i))
    of "--minutes":
      inc i
      minutes = parseInt(paramStr(i))
    of "--json":
      inc i
      jsonOut = paramStr(i)
    else:
      if cand == "": cand = arg.absolutePath
      else: refs.add arg.absolutePath
    inc i
  if cand == "" or refs.len == 0:
    quit("usage: ladder CAND.bas REF.bas [REF2.bas ...] [--seeds N] [--first N] [--three|--pairs] [--engine DIR] [--log DIR] [--goal K] [--minutes M] [--json OUT]", 2)
  let engine = if engineOverride.len > 0: engineOverride else: engineDir()
  if not fileExists(engine / "pwheadless"):
    quit("missing " & engine / "pwheadless" & " (build it: see games/pudge-wars/bas/readme.md)", 1)
  var report = newJObject()
  report["candidate"] = %cand
  report["mode"] = %(if three: "3v3" elif pairs: "2v2" else: "duel")
  var perRef = newJArray()
  let started = epochTime()
  var totalWins, totalLosses, totalDraws, totalFails = 0
  for reference in refs:
    var wins, losses, draws, fails, margin = 0
    var gamesOut = newJArray()
    for seed in first ..< first + seeds:
      for candWest in [true, false]:
        let outcome = runMatch(engine, cand, reference, seed, candWest, three, pairs, goal, minutes, logDir)
        gamesOut.add %*{"seed": seed, "candWest": candWest, "result": outcome.result,
          "margin": (if candWest: outcome.west - outcome.east else: outcome.east - outcome.west)}
        case outcome.result
        of "win": inc wins
        of "loss": inc losses
        of "draw": inc draws
        else: inc fails
        if outcome.active:
          margin += (if candWest: outcome.west - outcome.east else: outcome.east - outcome.west)
    let games = wins + losses + draws
    let name = reference.extractFilename
    echo &"{cand.extractFilename} vs {name}: {wins}W {losses}L {draws}D  vmfails {fails}  " &
      &"kill margin {(if games > 0: margin.float / games.float else: 0.0):+.2f}/game  (n={games})"
    perRef.add %*{"reference": reference, "wins": wins, "losses": losses,
      "draws": draws, "vmfails": fails, "games": games,
      "meanKillMargin": (if games > 0: margin.float / games.float else: 0.0),
      "games": gamesOut}
    totalWins += wins
    totalLosses += losses
    totalDraws += draws
    totalFails += fails
  echo &"TOTAL {totalWins}W {totalLosses}L {totalDraws}D vmfails {totalFails} in {epochTime() - started:.1f}s"
  report["perReference"] = perRef
  report["wins"] = %totalWins
  report["losses"] = %totalLosses
  report["draws"] = %totalDraws
  report["vmfails"] = %totalFails
  if jsonOut != "":
    writeFile(jsonOut, report.pretty)

main()
