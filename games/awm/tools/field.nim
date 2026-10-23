## Local five-seat field for the deckbuilding release: a design tool only,
## never the score (hosted XP decides what is kept).
##
##   field GAMES SEED A.bas B.bas [C.bas ...]
##
## Every game seats five scripts. By default the scripts fill the seats in
## rotation so each one plays about equally often and may sit twice. With
## AWM_FIELD_ONE=1 the first script takes exactly one seat (rotating round
## the ring) and the others fill the rest, which measures one candidate
## against a fixed field. AWM_FIELD_RANDOM=1 instead draws the other four
## seats from the rest with replacement, as league rounds draw their
## fillers. Wins, failures and game lengths are tallied per script file.

import
  std/[os, random, strformat, strutils, tables],
  sim, bots, match, replays, sessions

type
  Tally = object
    games, wins, failures, turns: int
    seatWins, seatGames: array[7, int]

proc main() =
  ## Plays the field and prints the tallies.
  if paramCount() < 3:
    quit("Usage: field GAMES SEED A.bas B.bas [C.bas ...]", 1)
  let
    games = parseInt(paramStr(1))
    seed = parseInt(paramStr(2))
    one = getEnv("AWM_FIELD_ONE") == "1"
    randomField = getEnv("AWM_FIELD_RANDOM") == "1"
    seatCount = if getEnv("AWM_FIELD_SEATS").len > 0: parseInt(getEnv("AWM_FIELD_SEATS")) else: 5
    record = getEnv("AWM_FIELD_RECORD")
  var index = ""
  if record.len > 0:
    createDir(record)
  var rng = initRand(seed)
  var names, sources: seq[string]
  for k in 3 .. paramCount():
    names.add paramStr(k).extractFilename
    sources.add readFile(paramStr(k))
  var tallies = initOrderedTable[string, Tally]()
  for name in names:
    tallies[name] = Tally()
  var lengths = 0
  for g in 0 ..< games:
    var picks: seq[int]
    if randomField:
      let ourSeat = g mod seatCount
      for seat in 0 ..< seatCount:
        if seat == ourSeat:
          picks.add 0
        else:
          picks.add 1 + rng.rand(names.len - 2)
    elif one:
      let ourSeat = g mod seatCount
      var k = 0
      for seat in 0 ..< seatCount:
        if seat == ourSeat:
          picks.add 0
        else:
          picks.add 1 + (g + k) mod (names.len - 1)
          inc k
    else:
      for seat in 0 ..< seatCount:
        picks.add (g * seatCount + seat) mod names.len
    var seated: seq[string]
    for p in picks:
      seated.add sources[p]
    resetInboxes(seatCount)
    let vms = loadBots(seated)
    for i, vm in vms:
      if vm.failed:
        quit(names[picks[i]] & " compile error: " & vm.lastError, 1)
    let gameSeed = seed + g
    let seats = setupBotSeats(vms, gameSeed)
    for i, vm in vms:
      if vm.deckProblems.len > 0:
        quit(names[picks[i]] & " illegal deck: " & $vm.deckProblems, 1)
    var recorder: ReplayRecorder
    if record.len > 0:
      var config = GameConfig(seed: gameSeed.int32, maxTicks: 28_800)
      for p in picks:
        config.players.add PlayerConfig(name: names[p])
      recorder = initReplayRecorder(matchSetup(seats, gameSeed.int32, 28_800),
        config)
    var played = initBotMatch(seats, gameSeed, vms, 28_800, recorder)
    var failedSeat = -1
    played.scriptError = proc(player: int, message: string) =
      failedSeat = player
      echo "game ", g, " seat ", player, " ", names[picks[player]],
        " FAILED: ", message
    played.run()
    lengths += played.game.turnNumber
    if record.len > 0:
      saveReplay(record / "g" & $g & ".raw", recorder.data)
      var seatLabels, seatScores: seq[string]
      for seat, p in picks:
        seatLabels.add names[p]
        seatScores.add (if played.outcome == MatchWon and played.game.winner == seat: "1.0" else: "0.0")
      index.add "g" & $g & "\t-\t" & seatLabels.join("|") & "\t" & seatScores.join("|") & "\n"
    for seat, p in picks:
      tallies[names[p]].games += 1
      tallies[names[p]].seatGames[seat] += 1
      tallies[names[p]].turns += played.game.turnNumber
      if played.outcome == MatchWon and played.game.winner == seat:
        tallies[names[p]].wins += 1
        tallies[names[p]].seatWins[seat] += 1
      if seat == failedSeat:
        tallies[names[p]].failures += 1
  if record.len > 0:
    writeFile(record / "index.tsv", index)
  echo &"{games} games, mean turns {lengths.float / games.float:.1f}"
  for name, t in tallies:
    var seatText = ""
    for s in 0 ..< seatCount:
      seatText.add &" {t.seatWins[s]}/{t.seatGames[s]}"
    echo &"  {name}: {t.wins}/{t.games} ({100.0 * t.wins.float / max(t.games, 1).float:.1f}%)",
      &" failures {t.failures} seats{seatText}"

main()
