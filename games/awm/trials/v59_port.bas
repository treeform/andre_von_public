' Radogost: Andre von Auto's AWM policy for the reworked Primordial.
' Built on the explicit-ping line (attack first, Study engine, Bouncer
' swarms) plus Summon Primordial: wipe the board of the seat that attacks
' us, else the strongest enemy board, and keep a 10/10.
'
' Each decision selects exactly one action; globals survive between them.

dim alive(7)
dim picks(63)
dim used(63)

IF selectingClass THEN
  pickClass(2)
  END
END IF

' Discard the most expensive cards; among equals, the last in hand.
IF tossCount > 0 THEN
  FOR i = 0 TO handSize - 1
    used(i) = 0
  NEXT i
  FOR k = 0 TO tossCount - 1
    best = -1
    FOR i = 0 TO handSize - 1
      IF used(i) = 0 THEN
        IF best < 0 THEN
          best = i
        ELSE
          IF handCost(i) >= handCost(best) AND NOT (handKind(i) = 1 AND handCost(i) = 8) THEN
            best = i
          END IF
          IF handKind(best) = 1 AND handCost(best) = 8 THEN best = i
        END IF
      END IF
    NEXT i
    used(best) = 1
    picks(k) = best
  NEXT k
  discardCards("picks")
  END
END IF

' Answer a waiting trigger target by target as the old built-in bot did.
IF triggerTargets > 0 THEN
  FOR s = 0 TO triggerTargets - 1
    n = nextChoiceCount(-1, "picks", s)
    best = -1
    IF triggerHelpsTarget(s) = 1 THEN
      FOR j = 0 TO n - 1
        IF best < 0 AND nextChoiceKind(-1, "picks", s, j) = 3 AND nextChoiceOwner(-1, "picks", s, j) = selfPlayer THEN
          best = j
        END IF
      NEXT j
    ELSE
      FOR j = 0 TO n - 1
        IF best < 0 AND nextChoiceKind(-1, "picks", s, j) = 2 AND nextChoiceOwner(-1, "picks", s, j) = enemyPlayer THEN
          best = j
        END IF
      NEXT j
      FOR j = 0 TO n - 1
        IF best < 0 AND nextChoiceKind(-1, "picks", s, j) = 3 AND nextChoiceOwner(-1, "picks", s, j) = enemyPlayer THEN
          best = j
        END IF
      NEXT j
    END IF
    FOR j = 0 TO n - 1
      IF best < 0 AND nextChoiceKind(-1, "picks", s, j) = 1 THEN
        best = j
      END IF
    NEXT j
    IF best < 0 THEN
      best = 0
    END IF
    picks(s) = best
  NEXT s
  IF resolveTrigger("picks") THEN END
  ' Refused: take the first legal target at every step.
  FOR s = 0 TO triggerTargets - 1
    picks(s) = 0
  NEXT s
  resolveTrigger("picks")
  END
END IF

seats = playerCount
for p = 0 to seats - 1
  alive(p) = 1 - playerDead(p)
next p

' Ready minions attack the next living player's hero before any card is
' played (a Primordial would otherwise bounce them first).
n = boardCount(selfPlayer)
FOR i = 0 TO n - 1
  id = boardId(selfPlayer, i)
  m = attackChoiceCount(id)
  FOR j = 0 TO m - 1
    IF attackChoiceKind(id, j) = 2 AND attackChoiceOwner(id, j) = enemyPlayer THEN
      IF attack(id, j) THEN END
    END IF
  NEXT j
NEXT i

' The previous living player's ready minions attack our hero.
prevPlayer = enemyPlayer
for s = 1 to seats - 1
  p = (selfPlayer - s + seats) mod seats
  if alive(p) = 1 and prevPlayer = enemyPlayer and p <> enemyPlayer then
    prevPlayer = p
  end if
next s

isMage = 0
if selfClass = 2 then
  isMage = 1
end if

if isMage = 1 then
  ' Summon Primordial wipes one hero's board and leaves us a 10/10: the
  ' seat that attacks us when it fields minions, else the strongest board.
  i = 0
  while i < handSize
    if canPlay(i) and handKind(i) = 1 and handCost(i) = 8 then
      nChoices = choiceCount(i)
      best = -1
      bestScore = -1
      j = 0
      while j < nChoices
        if choiceKind(i, j) = 2 then
          owner = choiceOwner(i, j)
          if owner <> selfPlayer and playerDead(owner) = 0 then
            score = 0
            b = 0
            while b < boardCount(owner)
              score = score + boardPower(owner, b)
              b = b + 1
            wend
            if owner = prevPlayer and score > 0 then score = score + 100
            if score > bestScore then
              bestScore = score
              best = j
            end if
          end if
        end if
        j = j + 1
      wend
      if best >= 0 then
        PRINT "turn", turnNumber, "summon primordial at", choiceOwner(i, best)
        IF playCardChoice(i, best) THEN END
      end if
    end if
    i = i + 1
  wend

  ' A bounced Primordial card returns only with energy to spare.
  i = 0
  while i < handSize
    if canPlay(i) and handKind(i) = 0 and handCost(i) = 8 and energy >= 14 then
      IF playCard(i) THEN END
    end if
    i = i + 1
  wend

  ' Free cards: a Bubble bounces the next minion that attacks us; an Ooze is a body.
  i = 0
  while i < handSize
    if canPlay(i) and handCost(i) = 0 and needsChoice(i) = 0 then
      if handKind(i) = 2 or handKind(i) = 0 then
        PRINT "turn", turnNumber, "mage free kind", handKind(i)
        IF playCard(i) THEN END
      end if
    end if
    i = i + 1
  wend

  ' In a duel the next player's k-th minion choice is its k-th board minion
  ' (trinkets have no toughness): Oozify its strongest, oldest on ties.
  if prevPlayer = enemyPlayer then
    i = 0
    while i < handSize
      if canPlay(i) and handKind(i) = 1 and handCost(i) = 4 and needsChoice(i) then
        nChoices = choiceCount(i)
        best = -1
        vtop = 1
        vs = 0
        j = 0
        while j < nChoices
          if choiceKind(i, j) = 3 and choiceOwner(i, j) = enemyPlayer then
            while vs < enemyBoardSize and enemyBoardHp(vs) <= 0
              vs = vs + 1
            wend
            if vs < enemyBoardSize then
              if enemyBoardPower(vs) > vtop then
                vtop = enemyBoardPower(vs)
                best = j
              end if
            end if
            vs = vs + 1
          end if
          j = j + 1
        wend
        if best >= 0 then
          PRINT "turn", turnNumber, "duel oozify power", vtop
          IF playCardChoice(i, best) THEN END
        end if
      end if
      i = i + 1
    wend
  end if

  ' Study draws before the turn's energy is spent, while the deck lasts.
  i = 0
  while i < handSize
    if canPlay(i) and handKind(i) = 1 and handCost(i) = 2 and needsChoice(i) = 0 then
      if selfDeckSize > 5 and energy > 2 then
        PRINT "turn", turnNumber, "mage study first"
        IF playCard(i) THEN END
      end if
    end if
    i = i + 1
  wend

  ' Bouncers: an attacker's minion, else a plain body (in a duel the attacker
  ' is the next player).
  i = 0
  while i < handSize
    if canPlay(i) and handKind(i) = 0 and handCost(i) = 1 then
      if needsChoice(i) = 0 then
        IF playCard(i) THEN END
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
        if choiceKind(i, j) = 3 and choiceOwner(i, j) = prevPlayer then
          best = j
        end if
        j = j + 1
      wend
      ' The next player's k-th minion choice is its k-th board minion
      ' (trinkets have no toughness): bounce the strongest, oldest on ties.
      if best >= 0 and choiceOwner(i, best) = enemyPlayer then
        vtop = -1
        vs = 0
        j = 0
        while j < nChoices
          if choiceKind(i, j) = 3 and choiceOwner(i, j) = enemyPlayer then
            while vs < enemyBoardSize and enemyBoardHp(vs) <= 0
              vs = vs + 1
            wend
            vscore = enemyBoardPower(vs) * 16 + enemyBoardHp(vs)
            if vscore > vtop then
              vtop = vscore
              vpower = enemyBoardPower(vs)
              best = j
            end if
            vs = vs + 1
          end if
          j = j + 1
        wend
        PRINT "turn", turnNumber, "sight bouncer power", vpower
      end if
      if best >= 0 then
        PRINT "turn", turnNumber, "mage bouncer owner", choiceOwner(i, best)
        IF playCardChoice(i, best) THEN END
      end if
    end if
    i = i + 1
  wend

  ' Draw and shield spells (Study, Bubble Shield, Plan) while the deck lasts.
  i = 0
  while i < handSize
    if canPlay(i) and needsChoice(i) = 0 and selfDeckSize > 5 then
      if handKind(i) = 2 or (handKind(i) = 1 and handCost(i) = 2) then
        IF playCard(i) THEN END
      end if
    end if
    i = i + 1
  wend

  ' Spare energy: Oozification on a minion that attacks us (not in a duel).
  i = 0
  while i < handSize
    if prevPlayer <> enemyPlayer and canPlay(i) and handKind(i) = 1 and handCost(i) = 4 and needsChoice(i) then
      nChoices = choiceCount(i)
      j = 0
      while j < nChoices
        if choiceKind(i, j) = 3 and choiceOwner(i, j) = prevPlayer then
          PRINT "turn", turnNumber, "mage oozify prev", prevPlayer
          IF playCardChoice(i, j) THEN END
        end if
        j = j + 1
      wend
    end if
    i = i + 1
  wend
  GOTO finish
end if

' In a duel the race decides: a Warrior with two or more minions plays
' Rally (5-cost untargeted spell), then Swords (2-cost untargeted spell),
' before removal. Past the Mage branch only Warrior hands hold them.
if prevPlayer = enemyPlayer and selfBoardSize >= 2 then
  wantCost = 5
  while wantCost >= 2
    i = 0
    while i < handSize
      if canPlay(i) and handKind(i) = 1 and handCost(i) = wantCost and needsChoice(i) = 0 then
        PRINT "turn", turnNumber, "duel buff cost", wantCost
        IF playCard(i) THEN END
      end if
      i = i + 1
    wend
    wantCost = wantCost - 3
  wend
end if

' A Warrior shrinks or fights an attacker's minion before playing anything
' else: Duel (two targets) or Tactician (2-cost 1/2 minion with a target).
i = 0
WHILE i < handSize
  IF canPlay(i) AND targetCount(i) = 2 THEN
    pick0 = -1
    nChoices = targetChoiceCount(i, 0)
    j = 0
    WHILE j < nChoices
      IF pick0 < 0 AND targetChoiceKind(i, 0, j) = 3 AND targetChoiceOwner(i, 0, j) = selfPlayer THEN
        pick0 = j
      END IF
      j = j + 1
    WEND
    pick1 = -1
    nChoices = targetChoiceCount(i, 1)
    j = 0
    WHILE j < nChoices
      IF targetChoiceKind(i, 1, j) = 3 AND targetChoiceOwner(i, 1, j) = prevPlayer THEN
        pick1 = j
      END IF
      j = j + 1
    WEND
    IF helpsTarget(i, 0) = 1 AND pick0 >= 0 AND pick1 >= 0 THEN
      PRINT "turn", turnNumber, "removal duel prev", prevPlayer
      IF playCardChoices(i, pick0, pick1) THEN END
    END IF
  END IF
  IF canPlay(i) AND handKind(i) = 0 AND handCost(i) = 2 AND handPower(i) = 1 AND handToughness(i) = 2 AND needsChoice(i) THEN
    best = -1
    nChoices = choiceCount(i)
    j = 0
    WHILE j < nChoices
      IF choiceKind(i, j) = 3 AND choiceOwner(i, j) = prevPlayer THEN
        best = j
      END IF
      j = j + 1
    WEND
    IF best >= 0 THEN
      PRINT "turn", turnNumber, "removal tactician prev", prevPlayer
      IF playCardChoice(i, best) THEN END
    END IF
  END IF
  i = i + 1
WEND

isArcher = 0
if selfClass = 0 then
  isArcher = 1
end if

' An Archer takes the costliest affordable card first; others go in hand order.
passes = 1
if isArcher = 1 then
  passes = 4
end if
FOR pass = 0 TO passes - 1
i = 0
WHILE i < handSize
  IF canPlay(i) AND (isArcher = 0 OR handCost(i) = 3 - pass) THEN
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
      IF pick0 >= 0 AND pick1 >= 0 THEN
        PRINT "turn", turnNumber, "duel prev", prevPlayer, "owner", targetChoiceOwner(i, 1, pick1)
        IF playCardChoices(i, pick0, pick1) THEN END
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

      ' A Sharpshooter aimed at the next player's minions reads their stats:
      ' kill a 1-toughness minion if it can, the strongest first.
      IF best >= 0 AND handKind(i) = 0 AND handCost(i) = 3 THEN
        IF choiceOwner(i, best) = enemyPlayer THEN
          vtop = -1
          vs = 0
          j = 0
          WHILE j < nChoices
            IF choiceKind(i, j) = 3 AND choiceOwner(i, j) = enemyPlayer THEN
              WHILE vs < enemyBoardSize AND enemyBoardHp(vs) <= 0
                vs = vs + 1
              WEND
              vscore = enemyBoardPower(vs) * 16
              IF enemyBoardHp(vs) <= 1 THEN
                vscore = vscore + 1000
              END IF
              IF vscore > vtop THEN
                vtop = vscore
                best = j
              END IF
              vs = vs + 1
            END IF
            j = j + 1
          WEND
          PRINT "turn", turnNumber, "sight sharpshooter score", vtop
          ' In a duel a ping that kills nothing goes to the hero instead.
          IF prevPlayer = enemyPlayer AND vtop < 1000 THEN
            PRINT "turn", turnNumber, "duel ping hero"
            best = -1
          END IF
        END IF
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

      IF best >= 0 THEN
        IF choiceKind(i, best) = 3 THEN
          PRINT "turn", turnNumber, "target prev", prevPlayer, "owner", choiceOwner(i, best)
        END IF
        IF playCardChoice(i, best) THEN END
      END IF
    ELSE
      ' Outside a duel a Warrior keeps Rally (5-cost untargeted spell) below
      ' four minions, Swords (2-cost untargeted spell) below three and Shields
      ' (1-cost untargeted spell) on an empty board.
      hold = 0
      IF isArcher = 0 AND prevPlayer <> enemyPlayer AND handKind(i) = 1 THEN
        IF handCost(i) = 5 AND selfBoardSize < 4 THEN
          hold = 1
        END IF
        IF handCost(i) = 2 AND selfBoardSize < 3 THEN
          hold = 1
        END IF
        IF handCost(i) = 1 AND selfBoardSize < 1 THEN
          hold = 1
        END IF
      END IF
      IF hold = 1 THEN
        PRINT "turn", turnNumber, "hold buff cost", handCost(i), "board", selfBoardSize
      ELSE
        IF playCard(i) THEN END
      END IF
    END IF
    END IF
  END IF
  i = i + 1
WEND
NEXT pass

' No card was played: every ready minion attacks the next living player's
' hero, one attack per decision, then the turn ends.
finish:
n = boardCount(selfPlayer)
FOR i = 0 TO n - 1
  id = boardId(selfPlayer, i)
  m = attackChoiceCount(id)
  FOR j = 0 TO m - 1
    IF attackChoiceKind(id, j) = 2 AND attackChoiceOwner(id, j) = enemyPlayer THEN
      IF attack(id, j) THEN END
    END IF
  NEXT j
NEXT i
endTurn()
END
