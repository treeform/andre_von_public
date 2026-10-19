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
  ' Primordial loop. Variant: reset alternate, dig plan, ooze any, second copy reset, reserve 1.
  ' The Primordial attacks only at the end of a turn it has sat through,
  ' so a cycle is one attack turn and one reset turn: a Bouncer returns
  ' it to hand and the replay wipes every other board and heals it, and
  ' our played Bouncers come back to hand with that wipe.
  primHand = -1
  prim2Hand = -1
  bouncerHand = -1
  bouncers = 0
  planHand = -1
  shieldHand = -1
  oozeHand = -1
  i = 0
  while i < handSize
    if handKind(i) = 0 and handCost(i) = 8 then
      if primHand < 0 then
        primHand = i
      else
        prim2Hand = i
      end if
    end if
    if handKind(i) = 0 and handCost(i) = 1 and handToughness(i) = 1 then
      if bouncerHand < 0 then bouncerHand = i
      bouncers = bouncers + 1
    end if
    if handKind(i) = 2 and handCost(i) = 3 then planHand = i
    if handKind(i) = 1 and handCost(i) = 2 and needsChoice(i) = 0 then shieldHand = i
    if handKind(i) = 1 and handCost(i) = 4 then oozeHand = i
    i = i + 1
  wend

  ' Our Primordial on the board and its ordinal among our minions.
  primBoard = -1
  primOrdinal = -1
  ownCount = 0
  b = 0
  while b < selfBoardSize
    if selfBoardHp(b) > 0 then
      if selfBoardPower(b) >= 6 and primBoard < 0 then
        primBoard = b
        primOrdinal = ownCount
      end if
      ownCount = ownCount + 1
    end if
    b = b + 1
  wend

  ' The attacker's minions from a Bouncer's choice list, damage taken
  ' since our last turn, own turns since the Primordial was played, and
  ' whether our board was emptied on the opponents' turns.
  attackerMinions = 0
  if bouncerHand >= 0 then
    nChoices = choiceCount(bouncerHand)
    j = 0
    while j < nChoices
      if choiceKind(bouncerHand, j) = 3 and choiceOwner(bouncerHand, j) = prevPlayer then attackerMinions = attackerMinions + 1
      j = j + 1
    wend
  elseif viewOk = 1 then
    attackerMinions = view(prevPlayer)
  end if
  if turnNumber <> lockTurn then
    incoming = 0
    if lifeSeen = 1 then incoming = lastLife - selfLife
    wipeSeen = 0
    if selfBoardSize = 0 and lastSelfBoard >= 2 then wipeSeen = 1
    turnsSince = turnsSince + 1
    lockTurn = turnNumber
  end if
  lastLife = selfLife
  lifeSeen = 1
  lastSelfBoard = selfBoardSize
  bigVisible = 0
  if duelPhase = 1 then
    for b = 0 to eCount - 1
      if ePow(b) >= 10 then bigVisible = 1
    next b
  end if

  wantReset = 0
  if primBoard >= 0 then
    if turnsSince >= 2 then wantReset = 1
  end if

  ' Land the Primordial when none is on the board, or as the reset.
  if primHand >= 0 and energy >= 8 and (primBoard < 0 or wantReset = 1) then
    PRINT "turn", turnNumber, "mage primordial"
    turnsSince = 0
    playCard(primHand)
    END
  end if

  ' Reset: a Bouncer returns our own Primordial to hand; the replay
  ' follows on the next decision.
  if wantReset = 1 and primBoard >= 0 and primHand < 0 and bouncerHand >= 0 and energy >= 9 then
    seen = 0
    pick = -1
    nChoices = choiceCount(bouncerHand)
    j = 0
    while j < nChoices
      if choiceKind(bouncerHand, j) = 3 and choiceOwner(bouncerHand, j) = selfPlayer then
        if seen = primOrdinal then pick = j
        seen = seen + 1
      end if
      j = j + 1
    wend
    if pick >= 0 then
      PRINT "turn", turnNumber, "mage reset"
      playCardChoice(bouncerHand, pick)
      END
    end if
  end if

  ' Locked: Bouncers on the attacker's minions beyond the reserve kept
  ' for the next reset, Oozification, then draw.
  if primBoard >= 0 then
    i = 0
    while i < handSize
      if canPlay(i) and handKind(i) = 0 and handCost(i) = 1 and handToughness(i) = 1 and bouncers > 1 then
        nChoices = choiceCount(i)
        best = -1
        j = 0
        while j < nChoices
          if choiceKind(i, j) = 3 and choiceOwner(i, j) = prevPlayer then best = j
          j = j + 1
        wend
        if best >= 0 then
          playCardChoice(i, best)
          END
        end if
      end if
      i = i + 1
    wend
    if oozeHand >= 0 and canPlay(oozeHand) and 1 then
      nChoices = choiceCount(oozeHand)
      if duelPhase = 1 then
        pickVisible(oozeHand, -1, 2, 0)
        if pick >= 0 then
          playCardChoice(oozeHand, pick)
          END
        end if
      end if
      j = 0
      while j < nChoices
        if choiceKind(oozeHand, j) = 3 and choiceOwner(oozeHand, j) = prevPlayer then
          playCardChoice(oozeHand, j)
          END
        end if
        j = j + 1
      wend
    end if
    if planHand >= 0 and canPlay(planHand) and selfDeckSize > 2 then
      playCard(planHand)
      END
    end if
    END
  end if

  ' No lock yet: survive and dig. Free cards first.
  i = 0
  while i < handSize
    if canPlay(i) and handCost(i) = 0 and needsChoice(i) = 0 then
      if handKind(i) = 2 or handKind(i) = 0 then
        playCard(i)
        END
      end if
    end if
    i = i + 1
  wend
  ' Plan first: it draws without discarding.
  if planHand >= 0 and canPlay(planHand) and selfDeckSize > 5 then
    playCard(planHand)
    END
  end if
  ' Bouncers only on the attacker's minions; in a final duel the next
  ' player's strongest visible minion.
  i = 0
  while i < handSize
    if canPlay(i) and handKind(i) = 0 and handCost(i) = 1 and handToughness(i) = 1 then
      nChoices = choiceCount(i)
      best = -1
      j = 0
      while j < nChoices
        if choiceKind(i, j) = 3 and choiceOwner(i, j) = prevPlayer then best = j
        j = j + 1
      wend
      if duelPhase = 1 and best >= 0 then
        pickVisible(i, -1, 2, 0)
        if pick >= 0 then best = pick
      end if
      if best >= 0 then
        playCardChoice(i, best)
        END
      end if
    end if
    i = i + 1
  wend
  ' Draws while the deck lasts.
  if planHand >= 0 and canPlay(planHand) and selfDeckSize > 5 then
    playCard(planHand)
    END
  end if
  if shieldHand >= 0 and canPlay(shieldHand) and selfDeckSize > 5 and 1 then
    playCard(shieldHand)
    END
  end if
  ' Oozification on an attacker's minion with spare energy.
  if oozeHand >= 0 and canPlay(oozeHand) and 1 then
    nChoices = choiceCount(oozeHand)
    if duelPhase = 1 then
      pickVisible(oozeHand, -1, 2, 0)
      if pick >= 0 then
        playCardChoice(oozeHand, pick)
        END
      end if
    end if
    j = 0
    while j < nChoices
      if choiceKind(oozeHand, j) = 3 and choiceOwner(oozeHand, j) = prevPlayer then
        playCardChoice(oozeHand, j)
        END
      end if
      j = j + 1
    wend
  end if
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
