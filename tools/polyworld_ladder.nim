## Local A/B ladder for the three Polyworld BASIC games.
##
## These games are `game-hosted`: the policy is a `.bas` file the game
## compiles itself, and the example repo ships headless binaries that take
## the same files. That makes a local ladder cheap - a full 20-minute
## Gods of the Arena match runs in about six seconds - so a candidate can
## be compared against the bundled baseline over many seeds before
## anything is uploaded.
##
## Local results are a design tool and nothing more. Hosted experience
## requests decide whether a change was real (see ../auto.md).
##
## Build the headless binaries first, from a polyworld checkout:
##
##   nim c -d:headless -d:release -o:/tmp/gota examples/gods_of_the_arena/gota.nim
##   nim c -d:headless -d:release -o:/tmp/lvd  examples/light_vs_dark/lvd.nim
##   nim c -d:headless -d:release -o:/tmp/cta  examples/call_to_adventure/cta.nim
##
## Then, for example:
##
##   nim r tools/polyworld_ladder.nim --game gota --binary /tmp/gota \
##     --candidate games/gods-of-the-arena/khors/khors.bas \
##     --baseline ~/p/polyworld/examples/gods_of_the_arena/players/base.bas \
##     --seeds 12
##
## The candidate plays both sides, because every one of these games has a
## structurally favoured seat: Red wins the Gods of the Arena baseline
## mirror about two thirds of the time, and Light wins the Light vs Dark
## mirror about three quarters.

import
  std/[os, osproc, strformat, strutils, math]

type
  Game = enum
    GodsOfTheArena, LightVsDark, CallToAdventure

  Side = enum
    FirstSeat, SecondSeat

  Tally = object
    candidate: int
    opponent: int
    undecided: int
    candidateScore: float
    opponentScore: float

proc seatCount(game: Game): int =
  ## Returns how many seats one side of a match owns.
  case game
  of GodsOfTheArena: 5
  of LightVsDark: 1
  of CallToAdventure: 1

proc parseGame(text: string): Game =
  ## Maps a short game name onto its enum.
  case text.toLowerAscii
  of "gota", "gods", "gods-of-the-arena": GodsOfTheArena
  of "lvd", "light", "light-vs-dark": LightVsDark
  of "cta", "call", "call-to-adventure": CallToAdventure
  else: quit("unknown --game " & text & " (gota, lvd or cta)")

proc godHp(output: string, side: string): int =
  ## Reads one god's remaining hit points from the new result line.
  for line in output.splitLines:
    if line.startsWith("gods:"):
      for part in line[5 .. ^1].split(','):
        let words = part.strip.split(' ')
        if words.len >= 2 and words[0] == side:
          return parseInt(words[1])
  -1

proc blueGodDead(output: string): bool = godHp(output, "blue") == 0

proc teamXp(output: string, side: string): float =
  ## Reads one team's total XP from "economy: red N XP / G gold, blue ...".
  for line in output.splitLines:
    if line.startsWith("economy:"):
      for part in line[8 .. ^1].split(','):
        let words = part.strip.split(' ')
        if words.len >= 3 and words[0] == side:
          return parseFloat(words[1])
  NaN

proc simulatedSeconds(output: string): float =
  ## Reads "simulated: S s in ..." (battle plus draft time).
  for line in output.splitLines:
    if line.startsWith("simulated:"):
      return parseFloat(line.split(' ')[1])
  NaN

proc heroXps(output: string, side: string): seq[float] =
  ## Reads per-hero lifetime XP from "xp: red a b c d e, blue ..." when the
  ## headless build prints it.
  for line in output.splitLines:
    if line.startsWith("xp:"):
      for part in line[3 .. ^1].split(','):
        let words = part.strip.split(' ')
        if words.len >= 2 and words[0] == side:
          for w in words[1 .. ^1]: result.add parseFloat(w)

proc gotaScore(output: string, side: string): float =
  ## The 2026-09-21 ladder score: each hero's lifetime XP minus 200 per
  ## simulated minute (draft included), floored at zero, team-averaged.
  let minutes = simulatedSeconds(output) / 60.0
  let xps = heroXps(output, side)
  if xps.len > 0:
    var total = 0.0
    for xp in xps: total += max(0.0, xp - 200.0 * minutes)
    return total / xps.len.float
  teamXp(output, side) / 5.0 - 200.0 * minutes
proc redGodDead(output: string): bool = godHp(output, "red") == 0

proc winner(game: Game, output: string): Side =
  ## Reads the headless result line. `SecondSeat` doubles as "nobody",
  ## which the caller separates using `decided`.
  case game
  of GodsOfTheArena:
    ## Since 2026-09-21 the headless binary prints
    ## "gods: red N hp, blue M hp"; the side whose god still stands won.
    if "red won" in output or blueGodDead(output): FirstSeat
    else: SecondSeat
  of LightVsDark:
    if "Light wins" in output: FirstSeat else: SecondSeat
  of CallToAdventure:
    ## Call to Adventure scores every hero separately, so there is no
    ## single winner line to read; the caller reports raw output instead.
    if "escaped" in output: FirstSeat else: SecondSeat

proc decided(game: Game, output: string): bool =
  ## Returns whether the match produced a winner at all.
  case game
  of GodsOfTheArena:
    "red won" in output or "blue won" in output or
      redGodDead(output) or blueGodDead(output)
  of LightVsDark: "wins" in output
  of CallToAdventure: true

proc runMatch(
    binary: string,
    game: Game,
    first, second: string,
    seed: int
): string =
  ## Runs one headless episode and returns its output.
  let seats = game.seatCount
  var command = &"{binary.quoteShell} --bot {first.quoteShell}:{seats}" &
    &" --bot {second.quoteShell}:{seats} --seed {seed}"
  if game == GodsOfTheArena:
    command &= " --ticks 28800"
  let (output, code) = execCmdEx(command)
  if code != 0:
    quit("headless run failed:\n" & output)
  output

proc ladder(
    binary: string,
    game: Game,
    candidate, baseline: string,
    seeds: int
): tuple[first, second: Tally] =
  ## Plays the candidate on both sides of `seeds` matches each.
  for side in [FirstSeat, SecondSeat]:
    var candidateScores, opponentScores: seq[float]
    let sideTally =
      if side == FirstSeat: result.first.addr else: result.second.addr
    for i in 1 .. seeds:
      let
        seed = 1000 + i * 37
        output =
          if side == FirstSeat:
            runMatch(binary, game, candidate, baseline, seed)
          else:
            runMatch(binary, game, baseline, candidate, seed)
      var tally =
        if side == FirstSeat: result.first.addr else: result.second.addr
      if not game.decided(output):
        inc tally.undecided
      elif game.winner(output) == side:
        inc tally.candidate
      else:
        inc tally.opponent
      if game == GodsOfTheArena:
        let (mine, theirs) =
          if side == FirstSeat: ("red", "blue") else: ("blue", "red")
        candidateScores.add gotaScore(output, mine)
        opponentScores.add gotaScore(output, theirs)
    if game == GodsOfTheArena and candidateScores.len > 0:
      sideTally.candidateScore = candidateScores.sum / candidateScores.len.float
      sideTally.opponentScore = opponentScores.sum / opponentScores.len.float

proc report(name: string, tally: Tally) =
  ## Prints one side's record.
  echo &"  {name}: candidate {tally.candidate}" &
    &"  baseline {tally.opponent}  undecided {tally.undecided}" &
    &"  score {tally.candidateScore:.0f} vs {tally.opponentScore:.0f}"

when isMainModule:
  var
    binary = ""
    candidate = ""
    baseline = ""
    game = GodsOfTheArena
    seeds = 8
    index = 1
  while index <= paramCount():
    let flag = paramStr(index)
    if index == paramCount() and flag.startsWith("--"):
      quit(flag & " requires a value")
    case flag
    of "--binary": binary = paramStr(index + 1)
    of "--game": game = parseGame(paramStr(index + 1))
    of "--candidate": candidate = paramStr(index + 1)
    of "--baseline": baseline = paramStr(index + 1)
    of "--seeds": seeds = parseInt(paramStr(index + 1))
    else: quit("unknown flag " & flag)
    index += 2

  if binary.len == 0 or candidate.len == 0 or baseline.len == 0:
    quit("need --binary, --candidate and --baseline")

  let (first, second) = ladder(binary, game, candidate, baseline, seeds)
  echo &"{game} over {seeds} seeds a side"
  report("candidate first seat ", first)
  report("candidate second seat", second)
  echo &"  total: {first.candidate + second.candidate} of {seeds * 2}"
