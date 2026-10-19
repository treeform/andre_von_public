## Summarizes a hosted AWM replay and, given one script per seat, replays
## the same seats and seed locally to check hosted and local play agree.
##
##   replaysum GAME.replay [SEAT0.bas SEAT1.bas ...]
##
## Prints the setup (classes and decks), the winner, each seat's death
## turn and what killed it, and per-seat action counts. With scripts it
## reports the first tick where the local match's state hash differs.

import
  std/[os, strformat, strutils],
  sim, bots, match, replays

proc main() =
  ## Reads the replay, walks its actions, and optionally replays locally.
  if paramCount() < 1:
    quit("Usage: replaysum GAME.replay [SEAT.bas ...]", 1)
  let data = loadReplay(paramStr(1))
  let setup = data.header.setup
  echo "seed ", setup.seed, " seats ", setup.classes.len, " ticks ",
    data.actions.len
  for seat, cls in setup.heroClasses:
    var deck: seq[string]
    for card in setup.decks[seat]:
      deck.add card.name & "x" & $card.copies
    echo "  seat ", seat, " ", cls, " deck ", deck.join(",")
  var game = newGame(setup)
  var
    plays, attacks: seq[int]
    deadAt: seq[int]
    killer: seq[string]
  for _ in 0 ..< setup.classes.len:
    plays.add 0
    attacks.add 0
    deadAt.add -1
    killer.add ""
  var tick = 0
  for action in data.actions:
    inc tick
    let acting = action.playerId.int
    if action.kind == ActionPlayCard:
      inc plays[acting]
    elif action.kind == ActionAttack:
      inc attacks[acting]
    if not game.applyAction(action):
      echo "tick ", tick, " refused action kind ", action.kind
      break
    for p in 0 ..< game.playerCount:
      if game.dead(p) and deadAt[p] < 0:
        deadAt[p] = game.turnNumber
        killer[p] = "seat " & $acting & " kind " & $action.kind
  echo "winner ", game.winner, " turn ", game.turnNumber, " over ", game.gameOver
  for p in 0 ..< game.playerCount:
    echo &"  seat {p} life {game.players[p].life} deck {game.players[p].deck.len}",
      &" dead at turn {deadAt[p]} by {killer[p]} plays {plays[p]} attacks {attacks[p]}",
      &" board {game.players[p].board.len}"
  if paramCount() >= 1 + setup.classes.len:
    var sources: seq[string]
    for seat in 0 ..< setup.classes.len:
      sources.add readFile(paramStr(2 + seat))
    resetInboxes(sources.len)
    let vms = loadBots(sources)
    for i, vm in vms:
      if vm.failed:
        quit("seat " & $i & " compile error: " & vm.lastError, 1)
    let seats = setupBotSeats(vms, setup.seed.int64)
    for i, seat in seats:
      if seat.heroClass != setup.heroClasses[i] or
          seat.deck.len != setup.decks[i].len:
        echo "seat ", i, " local setup differs: ", seat.heroClass, "/",
          seat.deck.len
    let recorder = initReplayRecorder(matchSetup(seats, setup.seed,
      setup.maximumTicks), data.config)
    var played = initBotMatch(seats, setup.seed.int64, vms,
      setup.maximumTicks, recorder)
    played.scriptError = proc(player: int, message: string) =
      echo "local seat ", player, " FAILED: ", message
    played.run()
    var first = -1
    let n = min(recorder.data.hashes.len, data.hashes.len)
    for i in 0 ..< n:
      if recorder.data.hashes[i] != data.hashes[i]:
        first = i + 1
        break
    echo "local ", played.outcomeLabel, " ticks ", played.tick,
      " hosted ticks ", data.hashes.len, " first differing tick ", first
    if first > 0:
      let a = data.actions[first - 1]
      let b = recorder.data.actions[first - 1]
      echo "  hosted seat ", a.playerId, " kind ", a.kind, " hand ", a.handIndex,
        " attacker ", a.attacker, " choices ", a.choices.len
      echo "  local  seat ", b.playerId, " kind ", b.kind, " hand ", b.handIndex,
        " attacker ", b.attacker, " choices ", b.choices.len

main()
