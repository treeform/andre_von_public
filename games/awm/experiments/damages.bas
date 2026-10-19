' Radogost searches card sequences with bounded Monte Carlo tree search.
' Steering chooses safe targets and filters empty buffs and wasteful removal.
' The model uses public observations only, and replans after every real card.
DIM cards(23)
DIM costs(23)
DIM kinds(23)
DIM powers(23)
DIM healths(23)
DIM firsts(23)
DIM seconds(23)
DIM targets(23)
DIM targetPowers(23)
DIM targetHealths(23)
DIM bits(23)
DIM parents(255)
DIM children(255)
DIM siblings(255)
DIM actions(255)
DIM visits(255)
DIM rewards(255)
DIM ownPowers(127)
DIM ownHealths(127)
DIM foePowers(127)
DIM foeHealths(127)
DIM weights(23)
DIM edgePriors(255)
DIM rootSamples(23)

budgetUsed = 4000 + handSize * 180 + selfBoardSize * 60 + enemyBoardSize * 60

IF savedTurn <> turnNumber THEN
  ' Recent life loss includes spells and only estimates incoming pressure.
  recentDamage = 0
  IF savedPassTurn > 0 AND savedPassTurn = savedTurn THEN recentDamage = savedPassLife - selfLife
  IF recentDamage < 0 THEN recentDamage = 0
  savedTurn = turnNumber
  freshPower = 0
  freshCount = 0
END IF
IF randomState = 0 THEN randomState = 17 + selfPlayer * 137
incomingPlayer = (selfPlayer + mailboxPlayers() - 1) MOD mailboxPlayers()

' Infer class from observable card signatures; the host has no card names.
FOR i = 0 TO handSize - 1
  IF handKind(i) = 0 THEN
    IF handPower(i) = 2 AND handToughness(i) = 1 THEN heroClass = 1
    IF handPower(i) = 3 AND handToughness(i) = 1 THEN heroClass = 1
    IF handToughness(i) = 2 THEN heroClass = 2
    IF handPower(i) = 2 AND handCost(i) = 5 THEN heroClass = 2
    IF handPower(i) = 1 AND handToughness(i) = 1 THEN heroClass = 3
    IF handPower(i) = 10 THEN heroClass = 3
  ELSE
    IF handKind(i) = 2 THEN heroClass = 3
    IF handCost(i) = 1 AND needsChoice(i) THEN heroClass = 1
    IF handCost(i) = 1 AND needsChoice(i) = 0 THEN heroClass = 2
    IF targetCount(i) = 2 OR handCost(i) = 5 THEN heroClass = 2
    IF handCost(i) = 4 THEN heroClass = 3
  END IF
NEXT

rootPower = 0
rootCount = 0
rootHealth = 0
ownSize = 0
FOR i = 0 TO selfBoardSize - 1
  IF selfBoardHp(i) > 0 THEN
    IF ownSize < 128 THEN
      ownPowers(ownSize) = selfBoardPower(i)
      ownHealths(ownSize) = selfBoardHp(i)
      ownSize = ownSize + 1
    END IF
    rootPower = rootPower + selfBoardPower(i)
    rootCount = rootCount + 1
    rootHealth = rootHealth + selfBoardHp(i)
  END IF
NEXT
rootReady = rootPower - freshPower
IF rootReady < 0 THEN rootReady = 0
rootReadyCount = rootCount - freshCount
IF rootReadyCount < 0 THEN rootReadyCount = 0
rootThreat = 0
foeSize = 0
hailPower = 0
hailCount = 0
FOR i = 0 TO enemyBoardSize - 1
  IF enemyBoardHp(i) > 0 THEN
    IF foeSize < 128 THEN
      foePowers(foeSize) = enemyBoardPower(i)
      foeHealths(foeSize) = enemyBoardHp(i)
      foeSize = foeSize + 1
    END IF
    rootThreat = rootThreat + enemyBoardPower(i)
    IF enemyBoardHp(i) = 1 THEN
      hailPower = hailPower + enemyBoardPower(i)
      hailCount = hailCount + 1
    END IF
  END IF
NEXT

' Each root action is a real hand index and a legal, steered target pair.
count = 0
FOR hand = 0 TO handSize - 1
  IF canPlay(hand) AND count < 24 THEN
    cost = handCost(hand)
    kind = handKind(hand)
    power = handPower(hand)
    health = handToughness(hand)
    effect = 0
    IF kind = 0 THEN
      IF power = 3 AND health = 1 THEN effect = 1
      IF power = 1 AND health = 2 AND cost = 2 THEN effect = 7
      IF cost = 5 THEN effect = 8
      IF power = 1 AND health = 1 THEN effect = 10
      IF power = 10 THEN effect = 13
    ELSE
      IF heroClass = 1 THEN
        IF cost = 1 THEN effect = 2 ELSE effect = 3
      END IF
      IF heroClass = 2 THEN
        IF cost = 1 THEN effect = 5
        IF cost = 2 THEN effect = 4
        IF targetCount(hand) = 2 THEN effect = 6
        IF cost = 5 THEN effect = 9
      END IF
      IF heroClass = 3 THEN
        IF kind = 2 THEN effect = 12
        IF kind = 2 AND cost = 0 THEN effect = 15
        IF cost = 2 THEN effect = 11
        IF cost = 4 THEN effect = 14
      END IF
    END IF
    pick0 = -1
    pick1 = -1
    targetIndex = -1
    targetPower = 0
    targetHealth = 0
    bestTarget = -10000
    valid = 1
    IF targetCount(hand) = 2 THEN
      ' Duel buffs our strongest fighter and removes a dangerous enemy.
      bestOwn = -1
      ownIndex = 0
      FOR j = 0 TO targetChoiceCount(hand, 0) - 1
        budgetUsed = budgetUsed + 100
        IF targetChoiceKind(hand, 0, j) = 3 AND targetChoiceOwner(hand, 0, j) = selfPlayer THEN
          IF ownIndex < ownSize THEN
            score = ownPowers(ownIndex) * 3 + ownHealths(ownIndex)
            IF score > bestOwn THEN
              bestOwn = score
              pick0 = j
              fighterPower = ownPowers(ownIndex) + 1
              fighterHealth = ownHealths(ownIndex) + 1
            END IF
          END IF
          ownIndex = ownIndex + 1
        END IF
      NEXT
      foeIndex = 0
      FOR j = 0 TO targetChoiceCount(hand, 1) - 1
        budgetUsed = budgetUsed + 100
        IF targetChoiceKind(hand, 1, j) = 3 AND targetChoiceOwner(hand, 1, j) = enemyPlayer THEN
          IF foeIndex < foeSize AND pick0 >= 0 THEN
            score = -100
            IF fighterPower >= foeHealths(foeIndex) AND foePowers(foeIndex) < fighterHealth THEN score = foePowers(foeIndex) * 3 + 2
            IF score > bestTarget THEN
              bestTarget = score
              pick1 = j
              targetIndex = foeIndex
              targetPower = foePowers(foeIndex)
              targetHealth = foeHealths(foeIndex)
            END IF
          END IF
          foeIndex = foeIndex + 1
        END IF
      NEXT
      IF pick0 < 0 OR pick1 < 0 OR bestTarget < 0 THEN valid = 0
    ELSE
      IF needsChoice(hand) THEN
        foeIndex = 0
        FOR j = 0 TO choiceCount(hand) - 1
          budgetUsed = budgetUsed + 100
          choiceType = choiceKind(hand, j)
          owner = choiceOwner(hand, j)
          score = -10000
          candidatePower = 0
          candidateHealth = 0
          candidateIndex = -1
          IF choiceType = 1 THEN score = 0
          IF choiceType = 2 AND owner = enemyPlayer THEN score = 2
          IF choiceType = 3 AND owner = enemyPlayer THEN
            IF foeIndex < foeSize THEN
              candidatePower = foePowers(foeIndex)
              candidateHealth = foeHealths(foeIndex)
              candidateIndex = foeIndex
              IF effect = 1 AND candidateHealth = 1 THEN score = candidatePower * 3 + 3
              IF effect = 7 THEN score = candidatePower * 2
              IF effect = 10 THEN score = candidatePower * 2 + candidateHealth * .25
              IF effect = 14 THEN score = candidatePower * 3 - candidateHealth * .2
            END IF
            foeIndex = foeIndex + 1
          END IF
          ' The preceding seat attacks us; its hidden minions use a prior.
          IF choiceType = 3 AND owner = incomingPlayer AND owner <> enemyPlayer THEN
            IF effect = 10 OR effect = 7 THEN
              score = 20 + j * .01
              candidatePower = 2
              candidateHealth = 2
            END IF
          END IF
          IF score > bestTarget THEN
            bestTarget = score
            pick0 = j
            targetIndex = candidateIndex
            targetPower = candidatePower
            targetHealth = candidateHealth
          END IF
        NEXT
        IF pick0 < 0 THEN valid = 0
        IF effect = 14 AND targetPower = 0 THEN valid = 0
      END IF
    END IF
    IF effect = 3 AND hailCount = 0 THEN valid = 0
    IF effect = 12 AND selfDeckSize <= 2 THEN valid = 0
    IF effect = 11 AND selfDeckSize <= 2 THEN valid = 0
    IF valid THEN
      cards(count) = hand
      costs(count) = cost
      kinds(count) = effect
      powers(count) = power
      healths(count) = health
      firsts(count) = pick0
      seconds(count) = pick1
      targets(count) = targetIndex
      targetPowers(count) = targetPower
      targetHealths(count) = targetHealth
      bit = 1
      FOR j = 1 TO count
        bit = bit * 2
      NEXT
      bits(count) = bit
      count = count + 1
    END IF
  END IF
NEXT
IF count = 0 THEN GOTO savePass
nodes = 0
forcedHand = -1
FOR i = 0 TO 23
  rootSamples(i) = 0
NEXT
GOSUB resetState
GOSUB chooseMove
IF move < 0 THEN GOTO savePass
IF forced >= 0 THEN
  best = forced
  forcedHand = cards(best)
  GOTO commitAction
END IF
IF legalMoves = 1 THEN
  best = move
  GOSUB evaluate
  stopValue = value
  GOSUB applyMove
  GOSUB evaluate
  IF value > stopValue THEN GOTO commitAction
  GOTO savePass
END IF

' Nodes use flat linked child lists, visit counts, and mean value backup.
FOR i = 0 TO 255
  children(i) = 0
  visits(i) = 0
  rewards(i) = 0
NEXT
nodes = 0
' Calibrated work accounting reserves the next simulation and final action.
iteration = 0
largestIteration = 5000 + count * 1000
nextReserve = largestIteration * 5 \ 4 + 6000 + count * 300
WHILE iteration < 512 AND budgetUsed + nextReserve < 750000
  iteration = iteration + 1
  beforeIteration = budgetUsed
  GOSUB resetState
  node = 0
  depth = 0
  searching = 1
  budgetUsed = budgetUsed + 250
  WHILE searching AND depth < 5
    GOSUB chooseMove
    expand = move
    existing = 0
    IF node = 0 AND move >= 0 THEN rootSamples(move) = rootSamples(move) + 1
    child = children(node)
    WHILE child > 0
      budgetUsed = budgetUsed + 30
      IF actions(child) = expand THEN existing = child
      child = siblings(child)
    WEND
    IF expand < 0 THEN
      searching = 0
    ELSE
    IF existing = 0 AND nodes < 255 THEN
      nodes = nodes + 1
      parents(nodes) = node
      actions(nodes) = expand
      edgePriors(nodes) = weights(expand) / weightSum
      siblings(nodes) = children(node)
      children(node) = nodes
      node = nodes
      move = expand
      GOSUB applyMove
      searching = 0
    ELSE
      child = children(node)
      bestChild = 0
      bestUcb = -10000
      ' PUCT combines backed-up value with the steered action probability.
      square = visits(node) + 1
      root = 1 + square / 4
      FOR k = 1 TO 3
        root = (root + square / root) / 2
      NEXT
      WHILE child > 0
        budgetUsed = budgetUsed + 200
        IF forced < 0 OR actions(child) = forced THEN
          ucb = rewards(child) / visits(child) + 2 * root * edgePriors(child) / (visits(child) + 1)
          IF ucb > bestUcb THEN
            bestUcb = ucb
            bestChild = child
          END IF
        END IF
        child = siblings(child)
      WEND
      IF bestChild = 0 THEN
        searching = 0
      ELSE
        node = bestChild
        move = actions(node)
        GOSUB applyMove
      END IF
    END IF
    END IF
    depth = depth + 1
  WEND
  ' Stochastic steered rollouts complete the affordable card sequence.
  rolling = 1
  WHILE depth < 5 AND rolling
    GOSUB chooseMove
    IF moveScore <= 0 THEN
      rolling = 0
    ELSE
      GOSUB applyMove
      depth = depth + 1
    END IF
  WEND
  GOSUB evaluate
  WHILE node > 0
    budgetUsed = budgetUsed + 50
    visits(node) = visits(node) + 1
    rewards(node) = rewards(node) + value
    node = parents(node)
  WEND
  visits(0) = visits(0) + 1
  iterationCost = budgetUsed - beforeIteration
  IF iterationCost > largestIteration THEN largestIteration = iterationCost
  nextReserve = largestIteration * 5 \ 4 + 6000 + count * 300
WEND
iterations = iteration

best = -1
bestScore = -10000
child = children(0)
WHILE child > 0
  score = rewards(child) / visits(child)
  IF score > bestScore THEN
    bestScore = score
    best = actions(child)
  END IF
  child = siblings(child)
WEND
IF best < 0 THEN GOTO savePass
GOSUB resetState
GOSUB evaluate
stopValue = value
IF bestScore <= stopValue THEN GOTO savePass
commitAction:
GOSUB resetState
move = best
GOSUB applyMove
IF seconds(best) >= 0 THEN
  success = playCardChoices(cards(best), firsts(best), seconds(best))
ELSE
  IF firsts(best) >= 0 THEN
    success = playCardChoice(cards(best), firsts(best))
  ELSE
    success = playCard(cards(best))
  END IF
END IF
IF success THEN
  freshPower = statePower - stateReady
  freshCount = stateCount - stateReadyCount
  IF kinds(best) = 13 THEN recentDamage = 0
ELSE
  GOTO savePass
END IF
END

savePass:
savedPassTurn = turnNumber
savedPassLife = selfLife
END

resetState:
  budgetUsed = budgetUsed + 60
  remaining = energy
  used = 0
  removed = 0
  hailed = 0
  statePower = rootPower
  stateCount = rootCount
  stateHealth = rootHealth
  stateReady = rootReady
  stateReadyCount = rootReadyCount
  stateThreat = rootThreat
  damage = 0
  utility = 0
  defense = 0
  boardReset = 0
  stateDeck = selfDeckSize
RETURN

movePriority:
  budgetUsed = budgetUsed + 45
  priority = -10000
  IF used \ bits(move) MOD 2 = 0 AND costs(move) <= remaining THEN
    budgetUsed = budgetUsed + 200
    effect = kinds(move)
    priority = 2
    SELECT CASE effect
    CASE 0, 1, 7
      priority = powers(move) * 3 + healths(move) * .3
    CASE 2
      priority = 2
      IF enemyLife - damage <= stateReady + 2 THEN priority = 100
    CASE 3
      priority = hailPower * 2 + hailCount
      IF hailed OR boardReset THEN priority = -10000
    CASE 4
      priority = stateCount * 3
      IF stateCount = 0 THEN priority = -10000
    CASE 5
      priority = stateCount * .4
      IF stateCount = 0 THEN priority = -10000
    CASE 6
      priority = targetPowers(move) * 2 + 1
    CASE 8
      priority = 15
    CASE 9
      priority = 12 + stateCount * 3
    CASE 10
      priority = 3 + targetPowers(move)
    CASE 11
      priority = 4
    CASE 12
      priority = 5
      IF stateDeck <= 2 THEN priority = -10000
    CASE 13
      priority = 30 - statePower * 3 - stateReady * 2
      IF recentDamage >= selfLife AND rootThreat < selfLife AND damage + stateReady < enemyLife AND boardReset = 0 THEN priority = 100
    CASE 14
      priority = targetPowers(move) * 2
    CASE 15
      priority = 3
    END SELECT
    IF targets(move) >= 0 AND targets(move) < 24 THEN
      targetBit = 1
      FOR k = 1 TO targets(move)
        budgetUsed = budgetUsed + 30
        targetBit = targetBit * 2
      NEXT
      IF removed \ targetBit MOD 2 = 1 THEN
        IF effect = 6 OR effect = 14 THEN priority = -10000
      END IF
    END IF
    IF boardReset AND targets(move) >= 0 THEN priority = -10000
  END IF
RETURN

chooseMove:
  budgetUsed = budgetUsed + 150
  ' Clear wins and safe free cards bypass sampling; bad moves get zero mass.
  move = -1
  moveScore = 0
  forced = -1
  forceRank = -1
  weightSum = 0
  legalMoves = 0
  IF damage >= enemyLife THEN RETURN
  FOR candidate = 0 TO count - 1
    budgetUsed = budgetUsed + 110
    move = candidate
    GOSUB movePriority
    weights(candidate) = 0
    IF priority > 0 THEN
      legalMoves = legalMoves + 1
      rank = -1
      IF costs(candidate) = 0 AND firsts(candidate) < 0 THEN rank = 1
      IF kinds(candidate) = 13 AND recentDamage >= selfLife AND rootThreat < selfLife AND damage + stateReady < enemyLife AND boardReset = 0 THEN rank = 90
      IF kinds(candidate) = 2 AND enemyLife - damage <= 2 THEN rank = 100
      IF kinds(candidate) = 1 AND targets(candidate) < 0 AND enemyLife - damage <= 1 THEN rank = 100
      IF rank > forceRank THEN
        forceRank = rank
        forced = candidate
      END IF
      ' Squared positive scores give better moves more probability.
      IF priority > 20 THEN priority = 20
      weights(candidate) = priority * priority
      weightSum = weightSum + weights(candidate)
    END IF
  NEXT
  IF forced >= 0 THEN
    move = forced
    moveScore = 100
    weights(forced) = 1
    weightSum = 1
    RETURN
  END IF
  move = -1
  IF weightSum <= 0 THEN RETURN
  randomState = (randomState * 75 + 74) MOD 32749
  draw = (randomState / 32749) * weightSum
  accumulated = 0
  FOR candidate = 0 TO count - 1
    budgetUsed = budgetUsed + 50
    accumulated = accumulated + weights(candidate)
    IF move < 0 AND weights(candidate) > 0 AND accumulated >= draw THEN
      move = candidate
      moveScore = weights(candidate)
    END IF
  NEXT
RETURN

applyMove:
  budgetUsed = budgetUsed + 200
  used = used + bits(move)
  remaining = remaining - costs(move)
  effect = kinds(move)
  reduction = targetPowers(move)
  IF targets(move) >= 0 AND targets(move) < 24 THEN
    targetBit = 1
    FOR k = 1 TO targets(move)
      budgetUsed = budgetUsed + 30
      targetBit = targetBit * 2
    NEXT
    IF removed \ targetBit MOD 2 = 1 THEN reduction = 0
  END IF
  SELECT CASE effect
  CASE 0, 1, 7, 10
    stateCount = stateCount + 1
    statePower = statePower + powers(move)
    stateHealth = stateHealth + healths(move)
    IF effect = 1 THEN
      IF targets(move) < 0 THEN
        damage = damage + 1
      ELSE
        IF targetHealths(move) = 1 THEN GOSUB removeTarget
      END IF
    END IF
    IF effect = 7 AND reduction > 0 THEN stateThreat = stateThreat - 1
    IF effect = 10 THEN
      GOSUB removeTarget
      utility = utility + reduction * .7
    END IF
  CASE 2
    damage = damage + 2
  CASE 3
    IF hailed = 0 THEN
      stateThreat = stateThreat - hailPower
      utility = utility + hailCount * .5
      hailed = 1
    END IF
  CASE 4
    statePower = statePower + stateCount
    stateReady = stateReady + stateReadyCount
  CASE 5
    stateHealth = stateHealth + stateCount
  CASE 6
    GOSUB removeTarget
    statePower = statePower + 1
    stateHealth = stateHealth + 1
    stateReady = stateReady + 1
  CASE 8
    statePower = statePower + 4
    stateCount = stateCount + 3
    stateHealth = stateHealth + 7
  CASE 9
    stateCount = stateCount + 2
    statePower = statePower + 2 + stateCount
    stateReady = stateReady + stateReadyCount
    stateHealth = stateHealth + 4
  CASE 11
    ' Study and Bubble Shield share a signature, so use a mixture value.
    utility = utility + 1.5
    defense = defense + 1
  CASE 12
    utility = utility + 2
    stateDeck = stateDeck - 2
  CASE 13
    statePower = 10
    stateCount = 1
    stateHealth = 10
    stateReady = 0
    stateReadyCount = 0
    utility = utility + stateThreat * 1.2
    stateThreat = 0
    boardReset = 1
  CASE 14
    GOSUB removeTarget
    utility = utility + reduction * .5
  CASE 15
    defense = defense + 1
  END SELECT
  IF stateThreat < 0 THEN stateThreat = 0
RETURN

removeTarget:
  stateThreat = stateThreat - reduction
  IF reduction > 0 AND targets(move) >= 0 AND targets(move) < 24 THEN
    removed = removed + targetBit
  END IF
RETURN

evaluate:
  budgetUsed = budgetUsed + 100
  ' Value immediate damage, continuing pressure, card flow, and survival.
  value = statePower * 2.5 + stateReady * 1.2 + stateHealth * .15
  value = value + damage * 2 + utility + defense * 1.5 - stateThreat * .65
  IF damage + stateReady >= enemyLife THEN value = value + 60
  IF mailboxPlayers() = 2 AND stateThreat - defense * 2 >= selfLife THEN value = value - 50
  value = value / 10
RETURN
