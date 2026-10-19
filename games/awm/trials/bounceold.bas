' Radogost: Andre von Auto's AWM policy.
'
' Defensive targeting: removal and bounces go to the minions of the living
' player before us, because only that player's minions attack our hero.
' Living seats are tracked from hero lists, the turn counter and minion
' counts. Mage draws first, spends Bouncers, and keeps Oozification for
' spare energy. Logic ported from the league leader's published behaviour.
'
' Each decision runs from the top of this file. The bot plays at most one
' card per invocation; the game calls it repeatedly until no card is played,
' then ends the turn. Globals and arrays survive between decisions.
'
' READ-ONLY VALUES
'   selfPlayer enemyPlayer turnNumber
'   selfLife enemyLife energy totalEnergy
'   handSize selfBoardSize enemyBoardSize selfDeckSize enemyDeckSize
'
' HAND QUERIES (index 0 to handSize - 1)
'   handCost(i)       energy cost
'   handKind(i)       0 = minion, 1 = spell, 2 = trinket
'   handPower(i)      attack (minions only)
'   handToughness(i)  toughness (minions only)
'   canPlay(i)        1 if affordable
'   needsChoice(i)    1 if the card needs a target
'
' CHOICE QUERIES
'   choiceCount(handIndex)              number of valid targets
'   choiceKind(handIndex, choiceIndex)  0=canceled 1=noTarget 2=hero 3=creature
'   choiceOwner(handIndex, choiceIndex) player who owns the target (-1 if n/a)
'   (these cover a card's first target; for cards with several targets:)
'   targetCount(handIndex)                         targets the card asks for
'   helpsTarget(handIndex, step)                   1 if that target should be yours
'   targetChoiceCount(handIndex, step)             valid choices for that target
'   targetChoiceKind(handIndex, step, choiceIndex)
'   targetChoiceOwner(handIndex, step, choiceIndex)
'
' BOARD QUERIES (index 0 to selfBoardSize/enemyBoardSize - 1)
'   selfBoardPower(i)  selfBoardHp(i)
'   enemyBoardPower(i) enemyBoardHp(i)
'
' COMMANDS (at most one per decision)
'   playCard(handIndex)                    play without a target, returns 1 on success
'   playCardChoice(handIndex, choiceIndex) play with a specific target
'   playCardChoices(handIndex, first, second) play a two-target card

'   mailboxPlayers()                       seats in the match

dim alive(7)
dim view(7)
dim lastView(7)
dim lastGrow(7)

if initialized = 0 then
  initialized = 1
  seats = mailboxPlayers()
  for p = 0 to seats - 1
    alive(p) = 1
  next p
end if

' Seats skipped between us and the next living player are dead.
p = (selfPlayer + 1) mod seats
while p <> enemyPlayer
  alive(p) = 0
  p = (p + 1) mod seats
wend

' A hero-target card lists every living hero: trust it over memory.
i = 0
while i < handSize
  heroes = 0
  nChoices = choiceCount(i)
  j = 0
  while j < nChoices
    if choiceKind(i, j) = 2 then
      heroes = heroes + 1
    end if
    j = j + 1
  wend
  if heroes > 0 then
    for p = 0 to seats - 1
      alive(p) = 0
    next p
    j = 0
    while j < nChoices
      if choiceKind(i, j) = 2 then
        alive(choiceOwner(i, j)) = 1
      end if
      j = j + 1
    wend
    i = handSize
  end if
  i = i + 1
wend

' Count each player's minions in the first minion-target list in hand.
for p = 0 to seats - 1
  view(p) = 0
next p
viewOk = 0
i = 0
while i < handSize
  if viewOk = 0 and needsChoice(i) then
    nChoices = choiceCount(i)
    j = 0
    while j < nChoices
      if choiceKind(i, j) = 3 then
        viewOk = 1
        view(choiceOwner(i, j)) = view(choiceOwner(i, j)) + 1
      end if
      j = j + 1
    wend
  end if
  i = i + 1
wend

' The turn counter advances once per living player's turn, so the gap
' since our last turn counts the living. Deaths on the far side (after the
' next player, before us) are otherwise invisible without a hero list. A
' dead player's board is frozen, so the far seats whose minions grew least
' recently are the ones presumed dead; a later growth revives a seat.
newTurn = 0
if turnNumber <> lastTurn then
  newTurn = 1
  if lastTurn > 0 and lastViewOk = 1 and viewOk = 1 then
    p = (enemyPlayer + 1) mod seats
    while p <> selfPlayer
      if view(p) > lastView(p) then
        lastGrow(p) = turnNumber
        alive(p) = 1
      end if
      p = (p + 1) mod seats
    wend
  end if
  if lastTurn > 0 then
    living = turnNumber - lastTurn
    believed = 0
    for p = 0 to seats - 1
      believed = believed + alive(p)
    next p
    while believed > living
      c = -1
      p = (enemyPlayer + 1) mod seats
      while p <> selfPlayer
        if alive(p) = 1 then
          if c < 0 then
            c = p
          else
            if lastGrow(p) < lastGrow(c) then
              c = p
            end if
          end if
        end if
        p = (p + 1) mod seats
      wend
      if c < 0 then
        believed = living
      else
        alive(c) = 0
        believed = believed - 1
        PRINT "turn", turnNumber, "infer dead", c
      end if
    wend
  end if
  lastTurn = turnNumber
end if
lastViewOk = viewOk
for p = 0 to seats - 1
  lastView(p) = view(p)
next p

' The previous living player's ready minions attack our hero.
prevPlayer = enemyPlayer
for s = 1 to seats - 1
  p = (selfPlayer - s + seats) mod seats
  if alive(p) = 1 and prevPlayer = enemyPlayer and p <> enemyPlayer then
    prevPlayer = p
  end if
next s
if newTurn = 1 then
  PRINT "turn", turnNumber, "belief prev", prevPlayer
end if
' In the final duel the attacker is the next player, whose board is
' visible: record its minions' stats in choice order.
dim ePow(63)
dim eHp(63)
eCount = 0
if prevPlayer = enemyPlayer then
  for b = 0 to enemyBoardSize - 1
    if enemyBoardHp(b) > 0 and eCount < 64 then
      ePow(eCount) = enemyBoardPower(b)
      eHp(eCount) = enemyBoardHp(b)
      eCount = eCount + 1
    end if
  next b
end if
duelPhase = 0
if prevPlayer = enemyPlayer and eCount > 0 then
  duelPhase = 1
end if

' With two players left the next player is also our attacker, which is the
' world the tree search models: a Warrior lets it choose final-duel cards.
' Warrior decks hold the only 1/2 one-cost, 3/2 two-cost and five-cost
' minions and the two-target Duel.
for i = 0 to handSize - 1
  if handKind(i) = 0 and handCost(i) = 1 and handToughness(i) = 2 then isWarrior = 1
  if handKind(i) = 0 and handCost(i) = 2 and handPower(i) = 3 then isWarrior = 1
  if handKind(i) = 0 and handCost(i) = 5 then isWarrior = 1
  if targetCount(i) = 2 then isWarrior = 1
next i
if prevPlayer = enemyPlayer and isWarrior = 1 then
  goto duelSearch
end if


' Only Mage decks hold trinkets, 1-cost 1/1 minions and 8-cost minions.
i = 0
while i < handSize
  if handKind(i) = 2 then
    isMage = 1
  end if
  if handKind(i) = 0 and handCost(i) = 1 and handPower(i) = 1 and handToughness(i) = 1 then
    isMage = 1
  end if
  if handKind(i) = 0 and handCost(i) = 8 then
    isMage = 1
  end if
  i = i + 1
wend

if isMage = 1 then
  ' Primordial bounces every other minion, so it goes first.
  i = 0
  while i < handSize
    if canPlay(i) and handKind(i) = 0 and handCost(i) = 8 and needsChoice(i) = 0 then
      PRINT "turn", turnNumber, "mage primordial"
      playCard(i)
      END
    end if
    i = i + 1
  wend

  ' Free cards: a Bubble bounces the next minion that attacks us; an Ooze is a body.
  i = 0
  while i < handSize
    if canPlay(i) and handCost(i) = 0 and needsChoice(i) = 0 then
      if handKind(i) = 2 or handKind(i) = 0 then
        PRINT "turn", turnNumber, "mage free kind", handKind(i)
        playCard(i)
        END
      end if
    end if
    i = i + 1
  wend

  ' Study draws before the turn's energy is spent, while the deck lasts.
  i = 0
  while i < handSize
    if canPlay(i) and handKind(i) = 1 and handCost(i) = 2 and needsChoice(i) = 0 then
      if selfDeckSize > 5 and energy > 2 then
        PRINT "turn", turnNumber, "mage study first"
        playCard(i)
        END
      end if
    end if
    i = i + 1
  wend

  ' Bouncers: an attacker's minion, else the next player's, else a plain body.
  i = 0
  while i < handSize
    if canPlay(i) and handKind(i) = 0 and handCost(i) = 1 then
      if needsChoice(i) = 0 then
        playCard(i)
        END
      end if
      nChoices = choiceCount(i)
      best = -1
      j = 0
      while j < nChoices
        if best < 0 and choiceKind(i, j) = 1 then
          best = j
        end if
        j = j + 1
      wend
      j = 0
      while j < nChoices
        if choiceKind(i, j) = 3 and choiceOwner(i, j) = enemyPlayer then
          best = j
        end if
        j = j + 1
      wend
      ' Hold Bouncers for the attacker's minions.
      best = -1
      j = 0
      while j < nChoices
        if best < 0 and choiceKind(i, j) = 3 and choiceOwner(i, j) = prevPlayer then
          best = j
        end if
        j = j + 1
      wend
      if duelPhase = 1 and best >= 0 then
        pickVisible(i, -1, 2, 0)
        if pick >= 0 then
          best = pick
        end if
      end if
      if best >= 0 then
        PRINT "turn", turnNumber, "mage bouncer owner", choiceOwner(i, best)
        playCardChoice(i, best)
        END
      end if
    end if
    i = i + 1
  wend

  ' Draw and shield spells (Study, Bubble Shield, Plan) while the deck lasts.
  i = 0
  while i < handSize
    if canPlay(i) and needsChoice(i) = 0 and selfDeckSize > 5 then
      if handKind(i) = 2 or (handKind(i) = 1 and handCost(i) = 2) then
        playCard(i)
        END
      end if
    end if
    i = i + 1
  wend

  ' Spare energy: Oozification on a minion that attacks us.
  i = 0
  while i < handSize
    if canPlay(i) and handKind(i) = 1 and handCost(i) = 4 and needsChoice(i) then
      nChoices = choiceCount(i)
      if duelPhase = 1 then
        pickVisible(i, -1, 2, 0)
        if pick >= 0 then
          playCardChoice(i, pick)
          END
        end if
      end if
      j = 0
      while j < nChoices
        if choiceKind(i, j) = 3 and choiceOwner(i, j) = prevPlayer then
          PRINT "turn", turnNumber, "mage oozify prev", prevPlayer
          playCardChoice(i, j)
          END
        end if
        j = j + 1
      wend
    end if
    i = i + 1
  wend
  END
end if
' Card codes from the visible signature: cost, kind, stats and targets.
' Archer 1-4, Warrior 11-18, Mage 21-27.

dim order(255)
dim prio(255)
for j = 0 to handSize - 1
  cardPriority(j)
next j
orderSize = 0
for pr = 30 to 0 step -1
  for j = 0 to handSize - 1
    if prio(j) = pr then
      order(orderSize) = j
      orderSize = orderSize + 1
    end if
  next j
next pr

k = 0
WHILE k < orderSize
  i = order(k)
  ' Hold Sharpshooters until the attacker has a minion.
  holdCard = 0
  IF prevPlayer <> enemyPlayer THEN
    cardCode(i)
    prevMinions = 0
    FOR b = 0 TO choiceCount(i) - 1
      IF choiceKind(i, b) = 3 AND choiceOwner(i, b) = prevPlayer THEN prevMinions = prevMinions + 1
    NEXT b
    IF code = 3 AND prevMinions = 0 THEN holdCard = 1
  END IF
  IF canPlay(i) AND holdCard = 0 THEN
    IF targetCount(i) = 2 THEN
      ' Two targets (Duel): each goes on one of our minions if its rule
      ' helps the target, else on an attacker of ours, else the next player's.
      pick0 = -1
      pick1 = -1
      s = 0
      WHILE s < 2
        nChoices = targetChoiceCount(i, s)
        found = -1
        IF helpsTarget(i, s) = 1 THEN
          j = 0
          WHILE j < nChoices
            IF found < 0 AND targetChoiceKind(i, s, j) = 3 AND targetChoiceOwner(i, s, j) = selfPlayer THEN
              found = j
            END IF
            j = j + 1
          WEND
        ELSE
          j = 0
          WHILE j < nChoices
            IF targetChoiceKind(i, s, j) = 3 AND targetChoiceOwner(i, s, j) = prevPlayer THEN
              found = j
            END IF
            j = j + 1
          WEND
          IF found < 0 THEN
            j = 0
            WHILE j < nChoices
              IF found < 0 AND targetChoiceKind(i, s, j) = 3 AND targetChoiceOwner(i, s, j) = enemyPlayer THEN
                found = j
              END IF
              j = j + 1
            WEND
          END IF
        END IF
        IF s = 0 THEN
          pick0 = found
        ELSE
          pick1 = found
        END IF
        s = s + 1
      WEND
      IF duelPhase = 1 AND pick0 >= 0 THEN
        ' Our fighter gains +1/+1, so it kills a minion with toughness up
        ' to its power plus one.
        ownIndex = 0
        FOR c = 0 TO pick0 - 1
          IF targetChoiceKind(i, 0, c) = 3 AND targetChoiceOwner(i, 0, c) = selfPlayer THEN ownIndex = ownIndex + 1
        NEXT c
        fighterPower = 0
        seen = 0
        FOR c = 0 TO selfBoardSize - 1
          IF selfBoardHp(c) > 0 THEN
            IF seen = ownIndex THEN fighterPower = selfBoardPower(c)
            seen = seen + 1
          END IF
        NEXT c
        pickVisible(i, 1, 1, fighterPower + 1)
        IF pick < 0 THEN pickVisible(i, 1, 2, 0)
        IF pick >= 0 THEN pick1 = pick
      END IF
      IF pick0 >= 0 AND pick1 >= 0 THEN
        PRINT "turn", turnNumber, "duel prev", prevPlayer, "owner", targetChoiceOwner(i, 1, pick1)
        playCardChoices(i, pick0, pick1)
        END
      END IF
    ELSE
    IF needsChoice(i) THEN
      nChoices = choiceCount(i)
      best = -1

      ' Sharpshooter pings a minion that attacks us.
      IF handKind(i) = 0 THEN
        j = 0
        WHILE j < nChoices
          IF choiceKind(i, j) = 3 AND choiceOwner(i, j) = prevPlayer THEN
            best = j
          END IF
          j = j + 1
        WEND
      END IF

      ' Prefer the enemy hero.
      j = 0
      WHILE best < 0 AND j < nChoices
        IF choiceKind(i, j) = 2 AND choiceOwner(i, j) = enemyPlayer THEN
          best = j
        END IF
        j = j + 1
      WEND

      ' Then a minion that attacks us, when the card harms its target.
      IF best < 0 AND helpsTarget(i, 0) = 0 THEN
        j = 0
        WHILE j < nChoices
          IF choiceKind(i, j) = 3 AND choiceOwner(i, j) = prevPlayer THEN
            best = j
          END IF
          j = j + 1
        WEND
      END IF

      ' Then an enemy minion.
      IF best < 0 THEN
        j = 0
        WHILE j < nChoices
          IF choiceKind(i, j) = 3 AND choiceOwner(i, j) = enemyPlayer THEN
            best = j
          END IF
          j = j + 1
        WEND
      END IF

      ' Then no-target if allowed.
      IF best < 0 THEN
        j = 0
        WHILE j < nChoices
          IF choiceKind(i, j) = 1 THEN
            best = j
          END IF
          j = j + 1
        WEND
      END IF

      IF duelPhase = 1 AND best >= 0 AND handKind(i) = 0 THEN
        IF choiceKind(i, best) = 3 OR handCost(i) = 3 THEN
          IF handCost(i) = 3 THEN
            ' Sharpshooter: kill the strongest one-toughness minion, else
            ' hit the hero.
            pickVisible(i, -1, 1, 1)
            IF pick < 0 THEN
              FOR c = 0 TO nChoices - 1
                IF choiceKind(i, c) = 2 AND choiceOwner(i, c) = enemyPlayer THEN pick = c
              NEXT c
            END IF
          ELSE
            pickVisible(i, -1, 2, 0)
          END IF
          IF pick >= 0 THEN best = pick
        END IF
      END IF
      IF best >= 0 THEN
        IF choiceKind(i, best) = 3 THEN
          PRINT "turn", turnNumber, "target prev", prevPlayer, "owner", choiceOwner(i, best)
        END IF
        playCardChoice(i, best)
        END
      END IF
    ELSE
      playCard(i)
      END
    END IF
    END IF
  END IF
  k = k + 1
WEND

END


' Final-duel tree search: Radogost v2's MCTS over card sequences.
duelSearch:
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
IF count = 0 THEN END
nodes = 0
forcedHand = -1
FOR i = 0 TO 23
  rootSamples(i) = 0
NEXT
GOSUB resetState
GOSUB chooseMove
IF move < 0 THEN END
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
  END
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
IF best < 0 THEN END
GOSUB resetState
GOSUB evaluate
stopValue = value
IF bestScore <= stopValue THEN END
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
END IF
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


sub cardCode(j)
  code = 0
  kind = handKind(j)
  cost = handCost(j)
  if kind = 0 then
    pw = handPower(j)
    tg = handToughness(j)
    if cost = 1 and tg = 1 then code = 21
    if cost = 1 and tg = 2 then code = 12
    if cost = 2 and pw = 2 and tg = 1 then code = 2
    if cost = 2 and pw = 3 then code = 11
    if cost = 2 and pw = 1 then code = 13
    if cost = 3 then code = 3
    if cost = 5 then code = 14
    if cost = 8 then code = 22
    if cost = 0 then code = 23
  elseif kind = 1 then
    if cost = 1 and needsChoice(j) then code = 1
    if cost = 1 and needsChoice(j) = 0 then code = 16
    if cost = 2 and targetCount(j) = 2 then code = 17
    if cost = 2 and targetCount(j) <> 2 then
      if isMage = 1 then
        code = 24
      else
        code = 15
      end if
    end if
    if cost = 3 then code = 4
    if cost = 4 then code = 27
    if cost = 5 then code = 18
  else
    if cost = 3 then code = 25
    if cost = 0 then code = 26
  end if
end sub

' Play priority: higher first, ties keep hand order.
sub cardPriority(j)
  cardCode(j)
  prio(j) = 10
  if code = 3 or code = 4 or code = 13 or code = 17 then prio(j) = 15
  if code = 15 or code = 16 or code = 18 then prio(j) = 5
end sub

' Picks the visible enemy minion among card i's choices for target step
' stepIndex (-1: the first-target list). Mode 1 takes the strongest with
' toughness at most dmg, mode 2 the strongest. Sets pick, or -1.
sub pickVisible(i, stepIndex, mode, dmg)
  pick = -1
  pvBest = -1
  pvSeen = 0
  if stepIndex < 0 then
    pvCount = choiceCount(i)
  else
    pvCount = targetChoiceCount(i, stepIndex)
  end if
  for pvC = 0 to pvCount - 1
    if stepIndex < 0 then
      pvKind = choiceKind(i, pvC)
      pvOwner = choiceOwner(i, pvC)
    else
      pvKind = targetChoiceKind(i, stepIndex, pvC)
      pvOwner = targetChoiceOwner(i, stepIndex, pvC)
    end if
    if pvKind = 3 and pvOwner = enemyPlayer then
      if pvSeen < eCount then
        pvOk = 1
        if mode = 1 and eHp(pvSeen) > dmg then
          pvOk = 0
        end if
        if pvOk = 1 and ePow(pvSeen) > pvBest then
          pvBest = ePow(pvSeen)
          pick = pvC
        end if
      end if
      pvSeen = pvSeen + 1
    end if
  next pvC
end sub
