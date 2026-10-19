## Lisa Patrikeevna — Liars Cog policy for Andre von Auto.
## Command player: the Nim rewrite of the reference player (/bin/lc-player,
## players/nim/player.nim in Metta-AI/coworld-liars-cog) playing its
## scripted "balanced" core. Every opponent bid updates an exact per-slot
## Bayesian posterior over how many copies of each face they hold, under a
## semi-honest bidding model with an adaptive per-opponent bluff rate. From
## the posteriors it computes exact tail probabilities, leave-one-out bid
## credibility (a bid may not vouch for itself), the EV of challenging vs
## every legal raise (including the chance the next seat challenges us),
## and bluffs exactly when a lie the next seat will not call is +EV.
## Episodes are series of games: learned per-opponent bluff rates carry
## across games keyed by player name (protocol_player.md).
##
## The reference's optional Bedrock LLM delegation is NOT ported: the
## scripted Bayesian core is the strategy and the LLM path is best-effort
## sugar on top of these same statistics. No secret-envs needed.
##
## Env (all optional, defaults are the reference's "balanced" style):
##   LISA_BLUFF_RATE, LISA_CHALLENGE_BELIEF, LISA_CONTINUATION_VALUE,
##   LISA_CREDIBLE_LINE_BELIEF, LISA_CHALLENGE_STAND_DOWN_MARGIN,
##   LISA_LINE_CONTINUATION_EV_SLACK

import std/[json, math, os, strutils, tables], coworld_client

const
  DefaultBluffRate = 0.15      ## P(a bid is a bluff regardless of hand)
  DefaultChallengeBelief = 0.30 ## perceived-truth threshold for challenging
  DefaultContinuationValue = 0.5 ## value of the game continuing past a raise
  MinChallengeProb = 0.05      ## opponents are never fully predictable
  MaxChallengeProb = 0.95
  DefaultCredibleLineBelief = 0.45
  DefaultChallengeStandDownMargin = 0.15
  DefaultLineContinuationEvSlack = 0.25
  CredibilityTarget = 0.35
  BluffRateLearning = 0.35
  MinAdaptiveBluffRate = 0.05
  MaxAdaptiveBluffRate = 0.65

type
  Bid = object
    slot, quantity, face: int

  ActionKind = enum
    NoAction, BidAction, ChallengeAction

  Action = object
    kind: ActionKind
    quantity, face: int

  Model = object
    slot: int
    hand: seq[int]
    numPlayers, handSize, numFaces, unknownDice: int
    baseRate: float
    bluffRate, challengeBelief, continuationValue: float
    credibleLineBelief, challengeStandDownMargin: float
    lineContinuationEvSlack: float
    ## Per-slot inferred bluffiness, learned from how credible that slot's
    ## previous bids looked before they updated our posterior.
    slotBluffPrior, slotBluffRate: seq[float]
    ## posterior[slot][face] is a pmf over 0..handSize copies of `face` in
    ## that slot's hand. Our own slot holds a point mass at the true count.
    posterior: seq[seq[seq[float]]]

  RaiseOption = object
    quantity, face: int
    truthProb: float      ## P(our bid is true) under the posterior
    challengeProb: float  ## P(the next player challenges it)
    ev: float             ## win-probability estimate for making this raise

proc rank(bid: Bid): (int, int) =
  ## Strict bid ordering: higher quantity wins; ties broken by higher face.
  (bid.quantity, bid.face)

proc envFloat(name: string, defaultValue: float): float =
  let raw = getEnv(name)
  if raw.len == 0: defaultValue else: raw.parseFloat()

## Exact binomial helpers

proc binomialPmf(n, k: int, p: float): float =
  if k < 0 or k > n: return 0.0
  if p <= 0.0: return (if k == 0: 1.0 else: 0.0)
  if p >= 1.0: return (if k == n: 1.0 else: 0.0)
  var logProb = 0.0
  for i in 0 ..< k:
    logProb += ln((n - i).float / (i + 1).float)
  logProb += k.float * ln(p) + (n - k).float * ln(1.0 - p)
  exp(logProb)

proc binomialTailAtLeast(n, k: int, p: float): float =
  ## Exact P(X >= k) for X ~ Binomial(n, p); n is small so this is cheap.
  if k <= 0: return 1.0
  if k > n: return 0.0
  if p <= 0.0: return 0.0
  if p >= 1.0: return 1.0
  var
    cumulative = 0.0
    term = pow(1.0 - p, n.float)
  for i in 0 ..< k:
    cumulative += term
    term *= (n - i).float / (i + 1).float * (p / (1.0 - p))
  result = max(0.0, min(1.0, 1.0 - cumulative))

proc convolve(a, b: seq[float]): seq[float] =
  ## PMF of the sum of two independent counts.
  result = newSeq[float](a.len + b.len - 1)
  for i, pa in a:
    if pa == 0.0: continue
    for j, pb in b:
      result[i + j] += pa * pb

## Model setup

proc ownCount(m: Model, face: int): int =
  for die in m.hand:
    if die == face:
      inc result

proc priorPmf(m: Model): seq[float] =
  ## Prior over copies of one face in one unseen hand.
  for k in 0 .. m.handSize:
    result.add binomialPmf(m.handSize, k, m.baseRate)

proc resetPosteriors(m: var Model) =
  m.posterior = newSeq[seq[seq[float]]](m.numPlayers)
  let prior = m.priorPmf()
  for slot in 0 ..< m.numPlayers:
    m.posterior[slot] = newSeq[seq[float]](m.numFaces + 1)
    for face in 1 .. m.numFaces:
      if slot == m.slot:
        var pmf = newSeq[float](m.handSize + 1)
        pmf[m.ownCount(face)] = 1.0
        m.posterior[slot][face] = pmf
      else:
        m.posterior[slot][face] = prior

proc clampBluffRate(value: float): float =
  max(MinAdaptiveBluffRate, min(MaxAdaptiveBluffRate, value))

proc resetSlotProfiles(m: var Model) =
  m.slotBluffRate = newSeq[float](m.numPlayers)
  for slot in 0 ..< m.numPlayers:
    m.slotBluffRate[slot] = clampBluffRate(m.slotBluffPrior[slot])

proc initModel(slot: int, hand: seq[int],
               numPlayers, handSize, numFaces: int): Model =
  result.slot = slot
  result.hand = hand
  result.numPlayers = numPlayers
  result.handSize = handSize
  result.numFaces = numFaces
  result.unknownDice = (numPlayers - 1) * handSize
  result.baseRate = 1.0 / numFaces.float
  result.bluffRate = envFloat("LISA_BLUFF_RATE", DefaultBluffRate)
  result.challengeBelief =
    envFloat("LISA_CHALLENGE_BELIEF", DefaultChallengeBelief)
  result.continuationValue =
    envFloat("LISA_CONTINUATION_VALUE", DefaultContinuationValue)
  result.credibleLineBelief =
    envFloat("LISA_CREDIBLE_LINE_BELIEF", DefaultCredibleLineBelief)
  result.challengeStandDownMargin = envFloat(
    "LISA_CHALLENGE_STAND_DOWN_MARGIN", DefaultChallengeStandDownMargin)
  result.lineContinuationEvSlack = envFloat(
    "LISA_LINE_CONTINUATION_EV_SLACK", DefaultLineContinuationEvSlack)
  result.slotBluffPrior = newSeq[float](numPlayers)
  for i in 0 ..< numPlayers:
    result.slotBluffPrior[i] = result.bluffRate
  result.resetPosteriors()
  result.resetSlotProfiles()

## Bayesian update from the bid history

proc probabilityAtLeast(m: Model, face, quantity: int): float

proc bidLikelihood(m: Model, quantity, held: int, bluffRate: float): float =
  ## P(a player makes this bid | they hold `held` copies). Semi-honest:
  ## with probability bluffRate the bid says nothing about their hand;
  ## otherwise they bid in proportion to how much they believe it.
  let believed =
    binomialTailAtLeast(m.unknownDice, quantity - held, m.baseRate)
  bluffRate + (1.0 - bluffRate) * believed

proc currentBidCredibility(m: Model, bid: Bid): float =
  ## Expected truth probability from the bidder's own seat under the
  ## current posterior, before this bid updates that posterior.
  if bid.slot == m.slot:
    return m.probabilityAtLeast(bid.face, bid.quantity)
  let pmf = m.posterior[bid.slot][bid.face]
  for held in 0 .. m.handSize:
    result += pmf[held] *
      binomialTailAtLeast(m.unknownDice, bid.quantity - held, m.baseRate)

proc updateSlotProfile(m: var Model, bid: Bid, credibility: float) =
  if bid.slot == m.slot:
    return
  let
    old = m.slotBluffRate[bid.slot]
    target =
      if credibility < CredibilityTarget:
        let pressure = (CredibilityTarget - credibility) / CredibilityTarget
        m.bluffRate + pressure * (MaxAdaptiveBluffRate - m.bluffRate)
      else:
        let trust = min(1.0, (credibility - CredibilityTarget) /
          max(0.0001, 1.0 - CredibilityTarget))
        m.bluffRate - trust * (m.bluffRate - MinAdaptiveBluffRate)
  m.slotBluffRate[bid.slot] = clampBluffRate(
    old * (1.0 - BluffRateLearning) + target * BluffRateLearning)

proc observeBid(m: var Model, bid: Bid, effectiveBluffRate: float) =
  if bid.slot == m.slot or bid.face < 1 or bid.face > m.numFaces:
    return
  var pmf = m.posterior[bid.slot][bid.face]
  var total = 0.0
  for k in 0 .. m.handSize:
    pmf[k] *= m.bidLikelihood(bid.quantity, k, effectiveBluffRate)
    total += pmf[k]
  if total <= 0.0:
    return
  for k in 0 .. m.handSize:
    pmf[k] /= total
  m.posterior[bid.slot][bid.face] = pmf

proc ingest(m: var Model, history: seq[Bid], exclude = -1) =
  ## Rebuilds all posteriors from the bid history. `exclude` skips one bid
  ## by index — used to judge a bid without letting it vouch for itself.
  m.resetPosteriors()
  m.resetSlotProfiles()
  for i, bid in history:
    if i == exclude:
      continue
    if bid.slot < 0 or bid.slot >= m.numPlayers:
      continue
    let
      credibility = m.currentBidCredibility(bid)
      effectiveBluffRate = m.slotBluffRate[bid.slot]
    m.observeBid(bid, effectiveBluffRate)
    m.updateSlotProfile(bid, credibility)

## Posterior tails and expectations

proc faceTotalPmf(m: Model, face: int): seq[float] =
  ## Exact pmf of the combined count of `face` across all hands.
  if face < 1 or face > m.numFaces:
    return @[1.0]
  result = @[1.0]
  for slot in 0 ..< m.numPlayers:
    result = convolve(result, m.posterior[slot][face])

proc probabilityAtLeast(m: Model, face, quantity: int): float =
  ## P(true combined count of `face` >= `quantity`) under the posterior.
  if quantity <= 0: return 1.0
  let pmf = m.faceTotalPmf(face)
  for total in quantity ..< pmf.len:
    result += pmf[total]
  result = max(0.0, min(1.0, result))

proc expectedCount(m: Model, face: int): float =
  let pmf = m.faceTotalPmf(face)
  for total, p in pmf:
    result += total.float * p

## Bluff detection

proc bidCredibility(m: Model, history: seq[Bid], index: int): float =
  ## How much the bidder plausibly believes their own bid, judged
  ## leave-one-out. Low credibility = likely bluff.
  let bid = history[index]
  if bid.slot == m.slot:
    return m.probabilityAtLeast(bid.face, bid.quantity)
  var leaveOneOut = m
  leaveOneOut.ingest(history, exclude = index)
  leaveOneOut.currentBidCredibility(bid)

proc challengeWinProb(m: Model, history: seq[Bid]): float =
  ## P(the standing bid is false), judged leave-one-out so the bid cannot
  ## vouch for itself. This is the exact EV of challenging.
  var leaveOneOut = m
  leaveOneOut.ingest(history, exclude = history.len - 1)
  let last = history[^1]
  1.0 - leaveOneOut.probabilityAtLeast(last.face, last.quantity)

## Expected value of raising

proc opponentChallengeProb(m: Model, oppSlot, face, quantity: int): float =
  ## P(the next seat challenges our bid): they challenge when it looks
  ## implausible from their own seat, averaged over our posterior of
  ## their holding of `face`.
  let pmf = m.posterior[oppSlot][face]
  for held in 0 .. m.handSize:
    let perceived =
      binomialTailAtLeast(m.unknownDice, quantity - held, m.baseRate)
    if perceived < m.challengeBelief:
      result += pmf[held]
  result = max(MinChallengeProb, min(MaxChallengeProb, result))

proc raiseOption(m: Model, oppSlot, face, quantity: int): RaiseOption =
  ## EV of bidding (quantity, face): if the next player challenges we win
  ## iff the bid is true; otherwise the game goes on at the continuation
  ## value. Truth and challenge probabilities are decoupled, so a lie the
  ## opponent is unlikely to challenge — a bluff — can be the best move.
  result.quantity = quantity
  result.face = face
  result.truthProb = m.probabilityAtLeast(face, quantity)
  result.challengeProb = m.opponentChallengeProb(oppSlot, face, quantity)
  result.ev = result.challengeProb * result.truthProb +
    (1.0 - result.challengeProb) * m.continuationValue

proc bestRaise(m: Model, oppSlot: int, hasLast: bool, last: Bid):
    (bool, RaiseOption) =
  let
    lastRank = if hasLast: last.rank() else: (0, -1)
    maxTotal = m.numPlayers * m.handSize
  var
    found = false
    best: RaiseOption
  for face in 1 .. m.numFaces:
    for quantity in 1 .. maxTotal:
      if (quantity, face) <= lastRank:
        continue
      let option = m.raiseOption(oppSlot, face, quantity)
      if not found or option.ev > best.ev:
        found = true
        best = option
  (found, best)

proc lineContinuation(m: Model, oppSlot: int, hasLast: bool, last: Bid):
    (bool, RaiseOption) =
  if not hasLast or last.quantity + 1 > m.numPlayers * m.handSize:
    return (false, RaiseOption())
  (true, m.raiseOption(oppSlot, last.face, last.quantity + 1))

## Decision

proc nextSlot(m: Model): int =
  (m.slot + 1) mod m.numPlayers

proc openingBid(m: Model): Action =
  ## Open on the face we hold most of — truthful and hard to challenge.
  var bestFace = 1
  for face in 2 .. m.numFaces:
    if (m.ownCount(face), -face) > (m.ownCount(bestFace), -bestFace):
      bestFace = face
  let quantity = max(max(round(m.expectedCount(bestFace)).int,
                         m.ownCount(bestFace)), 1)
  Action(kind: BidAction, quantity: quantity, face: bestFace)

proc decide(m: var Model, history: seq[Bid],
            hasLast: bool, last: Bid): Action =
  m.ingest(history)
  if not hasLast:
    return m.openingBid()
  let
    challengeEv = m.challengeWinProb(history)
    (haveRaise, best) = m.bestRaise(m.nextSlot(), hasLast, last)
  if not haveRaise:
    return Action(kind: ChallengeAction)
  # Ride a credible line: keep raising the standing face when the bidder
  # plausibly believes it and neither challenging nor jumping is much
  # better — this keeps pressure on without opening a new flank.
  let
    credibility = m.bidCredibility(history, history.len - 1)
    (haveLine, line) = m.lineContinuation(m.nextSlot(), hasLast, last)
  if haveLine and credibility >= m.credibleLineBelief and
      challengeEv <= best.ev + m.challengeStandDownMargin and
      line.ev >= best.ev - m.lineContinuationEvSlack:
    return Action(kind: BidAction, quantity: line.quantity, face: line.face)
  if challengeEv > best.ev:
    return Action(kind: ChallengeAction)
  Action(kind: BidAction, quantity: best.quantity, face: best.face)

## Wire protocol (docs/protocol_player.md)

proc bidFace(item: JsonNode): int =
  if item.hasKey("face"): item{"face"}.getInt()
  elif item.hasKey("digit"): item{"digit"}.getInt()
  else: 0

proc toBidHistory(node: JsonNode): seq[Bid] =
  if node.isNil or node.kind != JArray:
    return
  for item in node:
    let face = bidFace(item)
    if face < 1:
      continue
    result.add Bid(slot: item{"slot"}.getInt(),
                   quantity: item{"quantity"}.getInt(), face: face)

proc lastBidOf(node: JsonNode): (bool, Bid) =
  if node.isNil or node.kind != JObject:
    return (false, Bid())
  let face = bidFace(node)
  if face < 1:
    return (false, Bid())
  (true, Bid(slot: node{"slot"}.getInt(),
             quantity: node{"quantity"}.getInt(), face: face))

proc actionJson(action: Action): JsonNode =
  case action.kind
  of ChallengeAction: %*{"type": "challenge"}
  of BidAction:
    %*{"type": "bid", "quantity": action.quantity, "face": action.face}
  of NoAction: %*{"type": "none"}

proc opponentKey(name: string): string =
  name.strip().toLowerAscii()

proc main() =
  let client = newCoworldClient("lisa")
  var
    model: Model
    haveModel = false
    modelGameIndex = -1
    ## Learned per-opponent bluff rates keyed by player name, carried
    ## across the episode's games (fresh deals, same seats).
    opponentMemory = initTable[string, float]()

  proc rememberOpponents(message: JsonNode) =
    if not message.hasKey("player_names"):
      return
    for slot in 0 ..< min(model.numPlayers, message["player_names"].len):
      if slot == model.slot:
        continue
      let key = opponentKey(message["player_names"][slot].getStr())
      if key.len > 0 and slot < model.slotBluffRate.len:
        opponentMemory[key] = clampBluffRate(model.slotBluffRate[slot])

  proc applyOpponentMemory(message: JsonNode) =
    if opponentMemory.len == 0 or not message.hasKey("player_names"):
      return
    for slot in 0 ..< min(model.numPlayers, message["player_names"].len):
      if slot == model.slot:
        continue
      let key = opponentKey(message["player_names"][slot].getStr())
      if opponentMemory.hasKey(key):
        model.slotBluffPrior[slot] = clampBluffRate(opponentMemory[key])
        model.slotBluffRate[slot] = model.slotBluffPrior[slot]

  proc ensureModel(message: JsonNode) =
    ## Build (or rebuild) the model for the current game. When game_index
    ## advances the hand has been re-dealt, so the posterior must be
    ## rebuilt from the new `your_hand` — but stable opponent traits are
    ## remembered first and seeded into the fresh model.
    let gameIndex = message{"game_index"}.getInt(0)
    if haveModel and gameIndex == modelGameIndex:
      return
    if haveModel:
      rememberOpponents(message)
    if message{"your_hand"}.isNil:
      return
    var hand: seq[int]
    for die in message["your_hand"]:
      hand.add die.getInt()
    let
      numPlayers = message{"num_players"}.getInt()
      handSize = message{"hand_size"}.getInt()
      numFaces =
        if message.hasKey("num_faces"): message{"num_faces"}.getInt()
        elif message.hasKey("num_digits"): message{"num_digits"}.getInt()
        else: 6
    if hand.len == 0 or numPlayers < 1 or handSize < 1 or numFaces < 1:
      echo "lisa: waiting for valid game state"
      return
    model = initModel(message{"slot"}.getInt(), hand,
                      numPlayers, handSize, numFaces)
    applyOpponentMemory(message)
    haveModel = true
    modelGameIndex = gameIndex

  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "final":
      echo "lisa: final, game_wins ", message{"game_wins"}
      quit(0)
    of "observation":
      ensureModel(message)
    of "your_turn":
      ensureModel(message)
      if not haveModel:
        return
      let
        history = toBidHistory(message{"bid_history"})
        (hasLast, last) = lastBidOf(message{"last_bid"})
      client.send(actionJson(model.decide(history, hasLast, last)))
    else:
      discard

main()
