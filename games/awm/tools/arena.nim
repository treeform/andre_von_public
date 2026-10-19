## Local screening arena that mirrors hosted XP seating: the roster order
## is rotated one seat per episode and classes are drawn from each seed.
## It is a design tool only; hosted XP decides what is kept.
##
##   nim r -d:release games/awm/tools/arena.nim GAMES SEED A.bas [B.bas...]
##
## Each candidate plays the same seeds against the current champions in
## `others/`. With two candidates, paired win differences are reported.
## Set AWM_LEAGUE=1 for league-like games: five seats with a baseline filler
## in a seeded random order, as competition rounds are played.

import
  std/[math, os, random, strformat, strutils],
  sim, bots, match

const
  Opponents = ["stilt_v3.bas", "greenshank_v6.bas", "AWM_Baseline_v1.bas"]

type
  Tally = object
    wins, games, failures: int
    classWins, classGames: array[HeroClass, int]
    opponentWins: array[3, int]

proc seatClasses(seats: int, seed: int32): seq[HeroClass] =
  ## Matches the hosted server's seeded class draw.
  var rng = initRand(seed.int64)
  for _ in 0 ..< seats:
    result.add rng.rand(HeroClass)

var errors: int

proc play(sources: seq[string], seed: int32, failures: var int): int =
  ## Plays one match and returns the winning seat, or -1.
  let
    classes = seatClasses(sources.len, seed)
    vms = loadBots(sources)
  for vm in vms:
    if vm.failed:
      quit("compile error: " & vm.lastError, 1)
  var played = initBotMatch(classes, seed.int64, vms, 200_000)
  errors = 0
  played.scriptError = proc(player: int, message: string) =
    inc errors
    if errors <= 2:
      echo "seat ", player, " error: ", message
  played.run()
  failures += errors
  if played.outcome == MatchWon:
    played.game.winner
  else:
    -1

proc signTest(gained, lost: int): float =
  ## Exact one-sided sign test that gains exceed losses by chance.
  let n = gained + lost
  if n == 0:
    return 1.0
  var
    logs = newSeq[float](n + 1)
  for k in 1 .. n:
    logs[k] = logs[k - 1] + ln(k.float)
  for k in gained .. n:
    result += exp(logs[n] - logs[k] - logs[n - k] - n.float * ln(2.0))

proc main() =
  ## Runs every candidate over the same rotated seeds.
  if paramCount() < 3:
    quit("Usage: arena GAMES SEED A.bas [B.bas...]", 1)
  let
    games = parseInt(paramStr(1))
    firstSeed = parseInt(paramStr(2))
    others = currentSourcePath().parentDir / "../others"
  var opponents: seq[string]
  for name in Opponents:
    opponents.add readFile(others / name)
  var
    candidates: seq[string]
    names: seq[string]
  for k in 3 .. paramCount():
    candidates.add readFile(paramStr(k))
    names.add paramStr(k).extractFilename
  var
    tallies = newSeq[Tally](candidates.len)
    outcomes = newSeq[seq[bool]](candidates.len)
  let league = getEnv("AWM_LEAGUE") == "1"
  if league:
    opponents.add readFile(others / "AWM_Baseline_v1.bas")
  let seats = opponents.len + 1
  for g in 0 ..< games:
    let seed = int32(firstSeed + g)
    # Seat k holds roster entry order[k]; entry 0 is the candidate.
    var order = newSeq[int](seats)
    for i in 0 ..< seats:
      order[i] = (i - g mod seats + seats) mod seats
    if league:
      var rng = initRand(seed.int64 * 7919 + 17)
      rng.shuffle(order)
    for c in 0 ..< candidates.len:
      let roster = @[candidates[c]] & opponents
      var sources = newSeq[string](seats)
      var ours = 0
      for k in 0 ..< seats:
        sources[k] = roster[order[k]]
        if order[k] == 0:
          ours = k
      let
        winner = play(sources, seed, tallies[c].failures)
        classes = seatClasses(seats, seed)
      inc tallies[c].games
      inc tallies[c].classGames[classes[ours]]
      let won = winner == ours
      outcomes[c].add won
      if won:
        inc tallies[c].wins
        inc tallies[c].classWins[classes[ours]]
      elif winner >= 0:
        let opponent = min(order[winner] - 1, 2)
        inc tallies[c].opponentWins[opponent]
  for c in 0 ..< candidates.len:
    let t = tallies[c]
    var line = &"{names[c]}: {t.wins}/{t.games} " &
      &"({100.0 * t.wins.float / t.games.float:.1f}%) failures {t.failures}"
    for heroClass in HeroClass:
      line.add &" {heroClass} {t.classWins[heroClass]}/{t.classGames[heroClass]}"
    line.add &" | stilt {t.opponentWins[0]} green {t.opponentWins[1]}" &
      &" base {t.opponentWins[2]}"
    echo line
  for c in 1 ..< candidates.len:
    var gained, lost: int
    for g in 0 ..< games:
      if outcomes[c][g] and not outcomes[0][g]:
        inc gained
      if outcomes[0][g] and not outcomes[c][g]:
        inc lost
    echo &"paired {names[c]} vs {names[0]}: gained {gained}, lost {lost}, " &
      &"one-sided p {signTest(gained, lost):.4f}"

main()
