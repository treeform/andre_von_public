## Plays one local match to catch runtime failures in a new-API policy.
##
##   smoke OURS.bas [SEED] [COPIES]
##
## Seats: COPIES of ours (default 1) plus reference players to five
## (AWM_SMOKE_OPP names one script for every other seat). This is a
## compile-and-run check, not a score.

import
  std/[os, strutils],
  sim, bots, match

const Reference = ["mage.bas", "archer.bas", "warrior.bas", "archer_warrior.bas"]

proc main() =
  ## Runs a single five-seat match and reports errors and the outcome.
  if paramCount() < 1:
    quit("Usage: smoke OURS.bas [SEED] [COPIES]", 1)
  let
    seed = if paramCount() >= 2: parseInt(paramStr(2)) else: 7
    copies = if paramCount() >= 3: parseInt(paramStr(3)) else: 1
    players = getHomeDir() / "p/polyworld/examples/awm/players"
  var sources: seq[string]
  for k in 0 ..< 5:
    if k < copies:
      sources.add readFile(paramStr(1))
    elif getEnv("AWM_SMOKE_OPP").len > 0:
      sources.add readFile(getEnv("AWM_SMOKE_OPP"))
    else:
      sources.add readFile(players / Reference[(k - copies) mod Reference.len])
  resetInboxes(sources.len)
  let vms = loadBots(sources)
  for i, vm in vms:
    if vm.failed:
      quit("seat " & $i & " compile error: " & vm.lastError, 1)
  var line = ""
  for k in 0 ..< copies:
    vms[k].output = proc(event: PrintEvent) =
      if event.kind == NewlinePrint:
        echo "    ", line
        line = ""
      elif event.text.len > 0:
        line.add event.text & " "
      else:
        line.add $event.value & " "
  let seats = setupBotSeats(vms, seed)
  var classes: seq[string]
  for i, seat in seats:
    classes.add $seat.heroClass & "/" & $seat.deck.len
    for problem in vms[i].deckProblems:
      echo "seat ", i, " illegal deck: ", problem
  echo "seats ", classes
  var played = initBotMatch(seats, seed, vms, 28_800)
  played.scriptError = proc(player: int, message: string) =
    echo "seat ", player, " FAILED: ", message
  played.run()
  var lives, dead, decks, deckOut: seq[int]
  for p in played.game.players:
    lives.add p.life
    dead.add (if p.dead: 1 else: 0)
    decks.add p.deck.len
    deckOut.add (if p.drewFromEmpty: 1 else: 0)
  echo "outcome ", played.outcomeLabel, " ticks ", played.tick,
    " turns ", played.game.turnNumber, " lives ", lives, " dead ", dead,
    " decks ", decks, " deckOut ", deckOut

main()
