## Root-parallel, time-budgeted MCTS over determinized hidden
## information, with protect gates against the heuristic plan — the
## cogtan analogue of the terra champion's solver loop. Each worker owns
## one determinization (sampled opponent dev cards + deck order + its
## own dice stream) and one UCB tree; root statistics merge by move key,
## the most-visited move wins, and the plan is kept unless the searched
## move clearly beats it.

import
  std/[math, monotimes, os, strutils, threadpool, times],
  nodes, policy

const
  DefaultIterations = 200_000
  DefaultThreads = 8
  SolverMaxThreads = 16
  SolverMaxTreeNodes = 60_000
  SolverExplore = 1.4
  SolverScoreScale = 4.0
  SolverRootWarmupVisits = 4
  PlayoutMoveLimit = 1_600
  MinSearchMs* = 250
  ## Protect gates: the MCTS move must beat the heuristic plan by these
  ## edges (average final-VP margin / win-rate points) or the plan wins.
  ## Direct-VP plans (city/settlement) are protected hardest.
  ScoreProtectAvgEdge = 0.8
  ScoreProtectWinEdge = 6.0
  PlanProtectAvgEdge = 0.35
  PlanProtectWinEdge = 3.0
  MinBestVisits = 24

type
  Observation* = object
    state*: GameState     ## devDeck/opponent devHands NOT yet filled in
    you*: int
    devCounts*: array[MaxSeats, int]
    parsedOk*: bool

var solverLog* = true

proc log(parts: varargs[string, `$`]) =
  if solverLog:
    var line = ""
    for part in parts:
      line.add(part)
    echo line

## Determinization: sample the hidden zones (opponents' held dev cards +
## the deck order) from the unseen pool, and seed the chance stream.

proc determinize*(observation: Observation, seed: int): GameState =
  result = observation.state
  result.rng = initRng(seed)
  var rng = initRng(seed xor 0x5DEECE66D)
  # Unseen pool: the 25-card deck minus our own held cards and every
  # played knight. (Played progress cards are not in the view; the pool
  # slightly over-represents progress cards, which is the best available
  # approximation.)
  var pool: seq[DevCard]
  var deckCounts: array[DevCard, int] = [14, 2, 2, 2, 5]
  let you = observation.you
  for i in 0 ..< int(result.devHandLen[you]):
    dec deckCounts[result.devHandCards[you][i].card]
  for seat in 0 ..< int(result.playerCount):
    deckCounts[Knight] -= int(result.playedKnights[seat])
  for card in DevCard:
    for _ in 0 ..< max(0, deckCounts[card]):
      pool.add(card)
  for i in countdown(pool.high, 1):
    let j = rng.randInt(i + 1)
    swap(pool[i], pool[j])
  var cursor = 0

  proc draw(pool: seq[DevCard], cursor: var int): DevCard =
    if cursor < pool.len:
      result = pool[cursor]
      inc cursor
    else:
      result = Knight
  for seat in 0 ..< int(result.playerCount):
    if seat == you:
      continue
    result.devHandLen[seat] = 0
    for _ in 0 ..< observation.devCounts[seat]:
      result.devHandCards[seat][result.devHandLen[seat]] =
        DevCardInHand(card: pool.draw(cursor), bought: -1000)
      inc result.devHandLen[seat]
  # The remaining pool becomes the deck, drawn from the top (end).
  let deckLen = int(result.devDeckLen)
  for i in 0 ..< min(deckLen, DevDeckSize):
    result.devDeck[i] = pool.draw(cursor)

type
  SearchNode = object
    state: GameState
    parent: int32
    move: Move
    children: seq[int32]
    untried: seq[Move]
    visits: int32
    wins, ties, losses: int32
    totalMargins: array[MaxSeats, float32]

  RootSummary* = object
    key*: uint64
    move*: Move
    visits*, wins*, ties*, losses*: int
    marginSum*: float

  WorkerResult = object
    ok: bool
    error: string
    sampled: int
    nodes: int
    summaries: seq[RootSummary]

proc solverAverage(node: SearchNode, seat: int): float =
  if node.visits == 0: 0.0
  else: float(node.totalMargins[seat]) / float(node.visits)

proc ucbScore(tree: seq[SearchNode], parentIdx, childIdx: int): float =
  if tree[childIdx].visits == 0:
    return Inf
  var mover = tree[parentIdx].state.playerToMove()
  if mover == NoSeat:
    mover = 0
  let exploit = tree[childIdx].solverAverage(mover) / SolverScoreScale
  exploit + SolverExplore * sqrt(
    ln(float(max(1, tree[parentIdx].visits))) / float(tree[childIdx].visits))

proc selectChild(tree: seq[SearchNode], parentIdx: int,
    rng: var Rng): int =
  if parentIdx == 0:
    var cold = 0
    for childIdx in tree[parentIdx].children:
      if tree[childIdx].visits < SolverRootWarmupVisits:
        inc cold
    if cold > 0:
      var pick = rng.randInt(cold)
      for childIdx in tree[parentIdx].children:
        if tree[childIdx].visits < SolverRootWarmupVisits:
          if pick == 0:
            return int(childIdx)
          dec pick
  result = -1
  var bestScore = -Inf
  for childIdx in tree[parentIdx].children:
    let score = tree.ucbScore(parentIdx, int(childIdx))
    if score > bestScore:
      bestScore = score
      result = int(childIdx)

proc playout(start: GameState, rng: var Rng,
    perspective: int): SolverMargins =
  var state = start
  var options: MoveBuffer
  var moves = 0
  while state.phase != Finished and moves < PlayoutMoveLimit:
    state.legalMoves(options)
    if options.len == 0:
      break
    let move = state.biasedPlayoutMove(options, perspective, rng)
    state.applyMoveInPlace(move)
    inc moves
  state.solverMargins()

proc recordResult(node: var SearchNode, margins: SolverMargins) =
  inc node.visits
  for seat in 0 ..< margins.count:
    node.totalMargins[seat] += float32(margins.values[seat])

proc recordOutcome(node: var SearchNode, margin: int) =
  if margin > 0: inc node.wins
  elif margin == 0: inc node.ties
  else: inc node.losses

proc runIteration(tree: var seq[SearchNode], rng: var Rng,
    perspective: int) =
  var nodeIdx = 0
  var path: seq[int] = @[0]
  while tree[nodeIdx].untried.len == 0 and tree[nodeIdx].children.len > 0:
    nodeIdx = tree.selectChild(nodeIdx, rng)
    if nodeIdx < 0:
      return
    path.add(nodeIdx)
  if tree[nodeIdx].untried.len > 0 and tree.len < SolverMaxTreeNodes:
    let pick = rng.randInt(tree[nodeIdx].untried.len)
    let move = tree[nodeIdx].untried[pick]
    tree[nodeIdx].untried.del(pick)
    var childState = tree[nodeIdx].state
    childState.applyMoveInPlace(move)
    var untried: seq[Move]
    if childState.phase != Finished:
      var buffer: MoveBuffer
      childState.legalMoves(buffer)
      untried = buffer.toSeq()
    tree.add(SearchNode(state: childState, parent: int32(nodeIdx),
      move: move, untried: untried))
    let childIdx = tree.len - 1
    tree[nodeIdx].children.add(int32(childIdx))
    nodeIdx = childIdx
    path.add(nodeIdx)
  let margins = tree[nodeIdx].state.playout(rng, perspective)
  let margin =
    if perspective < margins.count: margins.values[perspective] else: 0
  for idx in path:
    tree[idx].recordResult(margins)
    tree[idx].recordOutcome(margin)

proc runWorker(worker: int, observation: Observation,
    rootMoves: seq[Move], perspective, iterations, seed,
    timeMs: int): WorkerResult =
  let deadline = getMonoTime() + initDuration(milliseconds = timeMs)
  try:
    var rng = initRng(seed)
    var tree = newSeqOfCap[SearchNode](min(iterations + 1,
      SolverMaxTreeNodes))
    tree.add(SearchNode(state: observation.determinize(seed),
      parent: -1, untried: rootMoves))
    for _ in 0 ..< iterations:
      if result.sampled > 0 and getMonoTime() >= deadline:
        break
      if tree.len >= SolverMaxTreeNodes:
        break
      tree.runIteration(rng, perspective)
      inc result.sampled
    result.nodes = tree.len
    for childIdx in tree[0].children:
      let node = tree[childIdx]
      result.summaries.add(RootSummary(
        key: node.move.moveKey(),
        move: node.move,
        visits: int(node.visits),
        wins: int(node.wins),
        ties: int(node.ties),
        losses: int(node.losses),
        marginSum: float(node.totalMargins[perspective])))
    result.ok = true
  except CatchableError as e:
    result.ok = false
    result.error = e.msg

proc solverThreads(): int =
  let env = getEnv("DOMOVOY_SOLVER_THREADS")
  var count = DefaultThreads
  if env.len > 0:
    try:
      count = parseInt(env)
    except ValueError:
      discard
  max(1, min(count, SolverMaxThreads))

proc searchRoot(observation: Observation, rootMoves: seq[Move],
    timeMs: int): seq[RootSummary] =
  ## Root-parallel scan: independent determinized workers, merged root
  ## statistics.
  var iterations = DefaultIterations
  let envIterations = getEnv("DOMOVOY_SOLVER_ITERATIONS")
  if envIterations.len > 0:
    try:
      iterations = max(100, parseInt(envIterations))
    except ValueError:
      discard
  let workers = solverThreads()
  setMaxPoolSize(workers)
  var flows: seq[FlowVar[WorkerResult]]
  for i in 0 ..< workers:
    flows.add spawn runWorker(i, observation, rootMoves, observation.you,
      iterations, 0x5EED + i * 7919 + int(observation.state.rolls) * 104729,
      timeMs)
  var totals: seq[RootSummary]
  for move in rootMoves:
    totals.add(RootSummary(key: move.moveKey(), move: move))
  var sampled = 0
  var failed = 0
  for flow in flows:
    let outcome = ^flow
    if not outcome.ok:
      inc failed
      log "domovoy: worker failed: ", outcome.error
      continue
    sampled += outcome.sampled
    for summary in outcome.summaries:
      for total in totals.mitems:
        if total.key == summary.key:
          total.visits += summary.visits
          total.wins += summary.wins
          total.ties += summary.ties
          total.losses += summary.losses
          total.marginSum += summary.marginSum
  log "domovoy: search sampled=", sampled, " workers=", workers,
    " failed=", failed, " rootMoves=", rootMoves.len
  totals

proc summaryAverage(summary: RootSummary): float =
  if summary.visits == 0: -1e9 else: summary.marginSum / float(summary.visits)

proc summaryWinRate(summary: RootSummary): float =
  if summary.visits == 0: 0.0
  else: 100.0 * float(summary.wins) / float(summary.visits)

proc chooseMove*(observation: Observation, timeMs: int): Move =
  ## MCTS choice behind the protect gates; falls back to the plan.
  let plan = observation.state.policyChoice(observation.you)
  var buffer: MoveBuffer
  observation.state.legalMoves(buffer)
  let rootMoves = buffer.toSeq()
  if rootMoves.len == 0:
    raise newException(SolverError, "No legal root moves.")
  if rootMoves.len == 1:
    return rootMoves[0]
  if timeMs < MinSearchMs or getEnv("DOMOVOY_SOLVER_ENABLED") in
      ["0", "false", "off"]:
    if plan.ok:
      return plan.move
    return rootMoves[0]
  let totals = observation.searchRoot(rootMoves, timeMs)
  var best = -1
  for i, total in totals:
    if best < 0 or total.visits > totals[best].visits or
        (total.visits == totals[best].visits and
         total.summaryAverage() > totals[best].summaryAverage()):
      best = i
  if best < 0 or totals[best].visits < MinBestVisits:
    if plan.ok:
      return plan.move
    return rootMoves[0]
  if not plan.ok:
    return totals[best].move
  # Protect gate: find the plan's summary and require a real edge.
  var planIdx = -1
  let planKey = plan.move.moveKey()
  for i, total in totals:
    if total.key == planKey:
      planIdx = i
  if planIdx < 0 or planIdx == best:
    return totals[best].move
  let avgEdge = totals[best].summaryAverage() -
    totals[planIdx].summaryAverage()
  let winEdge = totals[best].summaryWinRate() -
    totals[planIdx].summaryWinRate()
  let (needAvg, needWin) =
    if plan.reason in [PolicyCity, PolicySettlement]:
      (ScoreProtectAvgEdge, ScoreProtectWinEdge)
    else:
      (PlanProtectAvgEdge, PlanProtectWinEdge)
  if avgEdge >= needAvg or winEdge >= needWin:
    log "domovoy: mcts overrides plan ", plan.move.moveText(), " -> ",
      totals[best].move.moveText(), " avgEdge=",
      avgEdge.formatFloat(ffDecimal, 2), " winEdge=",
      winEdge.formatFloat(ffDecimal, 1)
    return totals[best].move
  log "domovoy: protect keeps plan ", plan.move.moveText(),
    " over ", totals[best].move.moveText(), " avgEdge=",
    avgEdge.formatFloat(ffDecimal, 2)
  plan.move
