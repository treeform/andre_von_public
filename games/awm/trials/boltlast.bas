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
      j = 0
      while j < nChoices
        if choiceKind(i, j) = 3 and choiceOwner(i, j) = prevPlayer then
          best = j
        end if
        j = j + 1
      wend
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
  IF canPlay(i) THEN
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
  if code = 1 then prio(j) = 5
end sub
