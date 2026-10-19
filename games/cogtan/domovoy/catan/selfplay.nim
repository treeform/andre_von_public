## Self-play strength test: the MCTS solver seat vs three heuristic
## (improved-baseline) seats, on real boards dealt by the TypeScript
## engine. This is a SIM-ONLY sanity check of the solver before any
## hosted XP verification — it never touches coworld. Run:
##   nim c -r -d:release --threads:on catan/selfplay.nim boards.jsonl [games] [budgetMs]

import
  std/[json, os, strutils],
  nodes, policy, solver, dumpstate

proc observe(state: GameState, you: int): Observation =
  ## What the real wire would show `you`: opponents' dev cards and the
  ## deck masked to counts (determinize resamples them per worker).
  result.you = you
  result.parsedOk = true
  result.state = state
  for seat in 0 ..< int(state.playerCount):
    result.devCounts[seat] = int(state.devHandLen[seat])
    if seat != you:
      result.state.devHandLen[seat] = 0

proc main() =
  let path = paramStr(1)
  let games = if paramCount() >= 2: parseInt(paramStr(2)) else: 12
  let budgetMs = if paramCount() >= 3: parseInt(paramStr(3)) else: 300
  var boards: seq[GameState]
  for line in lines(path):
    if line.len > 0:
      boards.add(parseFullState(parseJson(line)))
  solverLog = false
  var solverWins = 0
  var played = 0
  var vpSum = 0
  var rivalVpSum = 0.0
  for game in 0 ..< games:
    var state = boards[game mod boards.len]
    state.rng = initRng(0xBEEF + game * 7919)
    let solverSeat = game mod 4
    var safety = 0
    var buffer: MoveBuffer
    while state.phase != Finished and safety < 6000:
      inc safety
      let mover = state.playerToMove()
      if mover == NoSeat:
        break
      var move: Move
      if mover == solverSeat:
        move = state.observe(mover).chooseMove(budgetMs)
      else:
        let plan = state.policyChoice(mover)
        if plan.ok:
          move = plan.move
        else:
          state.legalMoves(buffer)
          if buffer.len == 0:
            break
          move = buffer.moves[0]
      state.applyMoveInPlace(move)
    inc played
    let won = int(state.winner) == solverSeat
    if won:
      inc solverWins
    vpSum += int(state.finalVp[solverSeat])
    for seat in 0 ..< 4:
      if seat != solverSeat:
        rivalVpSum += float(state.finalVp[seat]) / 3.0
    echo "game ", game, " seat=", solverSeat, " winner=", state.winner,
      " vp=[", state.finalVp[0], ",", state.finalVp[1], ",",
      state.finalVp[2], ",", state.finalVp[3], "]",
      (if won: "  <- solver" else: ""), " moves=", safety
  echo "selfplay: ", solverWins, "/", played, " solver wins (",
    (100.0 * float(solverWins) / float(played)).formatFloat(ffDecimal, 1),
    "% vs 25% par), solver avgVp=",
    (float(vpSum) / float(played)).formatFloat(ffDecimal, 2),
    " rival avgVp=",
    (rivalVpSum / float(played)).formatFloat(ffDecimal, 2)

main()
