' Radogost: Andre von Auto's AWM policy for the explicit-action engine.
'
' Every decision selects exactly one action. The policy picks Mage, keeps
' its Primordial through discards, attacks first with every ready minion,
' and from nine energy runs the lock each turn: the Primordial attacks, a
' Bouncer returns it to hand, and the replay bounces every other card on
' every board. Only Oozification or an enemy Primordial breaks the lock.

dim picks(255)
dim worth(255)

if selectingClass then
  pickClass(2)
  END
end if

if tossCount > 0 then
  bouncersSeen = 0
  i = 0
  while i < handSize
    cardWorth(i)
    if handKind(i) = 0 and handCost(i) = 1 then
      bouncersSeen = bouncersSeen + 1
      if bouncersSeen > 3 then worth(i) = 1
    end if
    i = i + 1
  wend
  k = 0
  while k < tossCount
    best = -1
    i = 0
    while i < handSize
      taken = 0
      m = 0
      while m < k
        if picks(m) = i then taken = 1
        m = m + 1
      wend
      if taken = 0 then
        if best < 0 then
          best = i
        elseif worth(i) < worth(best) then
          best = i
        end if
      end if
      i = i + 1
    wend
    picks(k) = best
    k = k + 1
  wend
  discardCards("picks")
  END
end if

if triggerTargets > 0 then
  s = 0
  while s < triggerTargets
    n = nextChoiceCount(-1, "picks", s)
    picks(s) = 0
    c = 0
    while c < n
      kind = nextChoiceKind(-1, "picks", s, c)
      owner = nextChoiceOwner(-1, "picks", s, c)
      if triggerHelpsTarget(s) = 1 then
        if kind = 3 and owner = selfPlayer then picks(s) = c
      else
        if kind = 3 and owner <> selfPlayer then picks(s) = c
      end if
      c = c + 1
    wend
    s = s + 1
  wend
  resolveTrigger("picks")
  END
end if

' Hand: the Primordial, Bouncers, and the draw and removal cards.
primHand = -1
prim2Hand = -1
bouncerHand = -1
bouncers = 0
planHand = -1
studyHand = -1
shieldHand = -1
oozeHand = -1
freeHand = -1
i = 0
while i < handSize
  if handKind(i) = 0 and handCost(i) = 8 then
    if primHand < 0 then
      primHand = i
    else
      prim2Hand = i
    end if
  end if
  if handKind(i) = 0 and handCost(i) = 1 then
    if bouncerHand < 0 then bouncerHand = i
    bouncers = bouncers + 1
  end if
  if handKind(i) = 2 and handCost(i) = 3 then planHand = i
  if handKind(i) = 1 and handCost(i) = 2 then
    if handName$(i) = "Study" then
      studyHand = i
    else
      shieldHand = i
    end if
  end if
  if handKind(i) = 1 and handCost(i) = 4 then oozeHand = i
  if handCost(i) = 0 and needsChoice(i) = 0 then freeHand = i
  i = i + 1
wend

' Our Primordial on the board: its slot, stable id, and whether it has
' already attacked this turn.
primBoard = -1
primId = 0
primAttacked = 0
b = 0
while b < boardCount(selfPlayer)
  if boardPower(selfPlayer, b) >= 6 then
    primBoard = b
    primId = boardId(selfPlayer, b)
    primAttacked = boardAttacked(selfPlayer, b)
  end if
  b = b + 1
wend

' Attacks first, so a reset never costs the Primordial's hit. A hero at
' ten life or less dies to the Primordial; otherwise the lowest-life hero
' takes the damage, since kills remove attackers.
b = 0
while b < boardCount(selfPlayer)
  id = boardId(selfPlayer, b)
  if boardReady(selfPlayer, b) = 1 and boardPower(selfPlayer, b) > 0 then
    n = attackChoiceCount(id)
    best = -1
    bestLife = 999
    power = boardPower(selfPlayer, b)
    c = 0
    while c < n
      if attackChoiceKind(id, c) = 2 then
        owner = attackChoiceOwner(id, c)
        life = playerLife(owner)
        if life <= power then life = life - 100
        if life < bestLife then
          bestLife = life
          best = c
        end if
      end if
      c = c + 1
    wend
    if best >= 0 then
      if attack(id, best) then END
    end if
  end if
  b = b + 1
wend

' An enemy Primordial on a living board dies to Oozification before our
' own replay would bounce it back to its owner's hand.
if oozeHand >= 0 and canPlay(oozeHand) then
  n = choiceCount(oozeHand)
  c = 0
  while c < n
    if choiceKind(oozeHand, c) = 3 and choiceOwner(oozeHand, c) <> selfPlayer then
      targetId = choiceId(oozeHand, c)
      p = choiceOwner(oozeHand, c)
      if playerDead(p) = 0 then
        j = 0
        while j < boardCount(p)
          if boardId(p, j) = targetId and boardPower(p, j) >= 8 then
            PRINT "turn", turnNumber, "oozify enemy primordial"
            if playCardChoice(oozeHand, c) then END
          end if
          j = j + 1
        wend
      end if
    end if
    c = c + 1
  wend
end if

' Reset: after the Primordial has attacked, a Bouncer returns it to hand
' and the replay follows on the next decision. A second Primordial in
' hand replays without a Bouncer.
if primBoard >= 0 and primAttacked = 1 then
  if primHand >= 0 and energy >= 8 then
    PRINT "turn", turnNumber, "reset with second copy"
    if playCard(primHand) then END
  end if
  if bouncerHand >= 0 and energy >= 9 then
    n = choiceCount(bouncerHand)
    c = 0
    while c < n
      if choiceKind(bouncerHand, c) = 3 and choiceId(bouncerHand, c) = primId then
        PRINT "turn", turnNumber, "reset"
        if playCardChoice(bouncerHand, c) then END
      end if
      c = c + 1
    wend
  end if
end if

' Land the Primordial when none is on the board.
if primBoard < 0 and primHand >= 0 and energy >= 8 then
  PRINT "turn", turnNumber, "primordial"
  if playCard(primHand) then END
end if

' Free cards: a returned Bubble, or an Ooze body.
if freeHand >= 0 then
  if playCard(freeHand) then END
end if

' Oozification destroys the strongest enemy minion of four or more power.
if oozeHand >= 0 and canPlay(oozeHand) then
  n = choiceCount(oozeHand)
  best = -1
  bestPower = 3
  c = 0
  while c < n
    if choiceKind(oozeHand, c) = 3 and choiceOwner(oozeHand, c) <> selfPlayer then
      targetId = choiceId(oozeHand, c)
      p = choiceOwner(oozeHand, c)
      if playerDead(p) = 0 then
        j = 0
        while j < boardCount(p)
          if boardId(p, j) = targetId and boardPower(p, j) > bestPower then
            bestPower = boardPower(p, j)
            best = c
          end if
          j = j + 1
        wend
      end if
    end if
    c = c + 1
  wend
  if best >= 0 then
    PRINT "turn", turnNumber, "oozify power", bestPower
    if playCardChoice(oozeHand, best) then END
  end if
end if

' A Bubble on our board makes rival Primordials prefer other heroes.
ownBubbles = 0
b = 0
while b < boardCount(selfPlayer)
  if boardKind(selfPlayer, b) = 2 and boardHp(selfPlayer, b) = 0 then
    if boardName$(selfPlayer, b) = "Bubble" then ownBubbles = ownBubbles + 1
  end if
  b = b + 1
wend
if shieldHand >= 0 and canPlay(shieldHand) and ownBubbles = 0 then
  if playCard(shieldHand) then END
end if

' Bouncers on the strongest living enemy minion of two or more power,
' keeping one in hand for the next reset whenever we hold or field a
' Primordial.
reserve = 0
if primBoard >= 0 or primHand >= 0 then reserve = 1
before = selfPlayer
k = 1
while k < playerCount
  q = (selfPlayer - k + playerCount) mod playerCount
  if playerDead(q) = 0 and before = selfPlayer then before = q
  k = k + 1
wend
if bouncerHand >= 0 and canPlay(bouncerHand) and bouncers > reserve then
  n = choiceCount(bouncerHand)
  best = -1
  bestPower = 1
  c = 0
  while c < n
    if choiceKind(bouncerHand, c) = 3 and choiceOwner(bouncerHand, c) <> selfPlayer then
      targetId = choiceId(bouncerHand, c)
      p = choiceOwner(bouncerHand, c)
      if playerDead(p) = 0 then
        j = 0
        while j < boardCount(p)
          if boardId(p, j) = targetId then
            score = boardPower(p, j)
            if p = before and primBoard < 0 then score = score + 2
            if score > bestPower then
              bestPower = score
              best = c
            end if
          end if
          j = j + 1
        wend
      end if
    end if
    c = c + 1
  wend
  if best >= 0 then
    if playCardChoice(bouncerHand, best) then END
  end if
end if

' Draws are a resource: drawing from an empty deck kills. Dig for the
' Primordial while we have none, and later only for Bouncers, never
' below a safe deck.
dig = 0
if dig = 1 then
  if planHand >= 0 and canPlay(planHand) then
    if playCard(planHand) then END
  end if
  if studyHand >= 0 and canPlay(studyHand) then
    if playCard(studyHand) then END
  end if
end if

' Bubble Shield: two Bubbles that each bounce a minion that hits us.
if shieldHand >= 0 and canPlay(shieldHand) then
  if playCard(shieldHand) then END
end if

' In the lock, spare Bouncers are bodies that return to hand on the next
' replay.
if primBoard >= 0 and bouncerHand >= 0 and canPlay(bouncerHand) and bouncers > 1 then
  n = choiceCount(bouncerHand)
  c = 0
  while c < n
    if choiceKind(bouncerHand, c) = 1 then
      if playCardChoice(bouncerHand, c) then END
    end if
    c = c + 1
  wend
end if

endTurn()
END

' A card's worth when a discard is forced, lowest first, from the card's
' cost and kind; only the two-cost spells need their name.
sub cardWorth(i)
  worth(i) = 2
  if handCost(i) = 0 then worth(i) = 0
  if handKind(i) = 1 and handCost(i) = 2 then
    worth(i) = 1
    if handName$(i) = "Study" then worth(i) = 0
  end if
  if handKind(i) = 2 and handCost(i) = 3 then worth(i) = 3
  if handKind(i) = 0 and handCost(i) = 1 then worth(i) = 4
  if handKind(i) = 1 and handCost(i) = 4 then worth(i) = 6
  if handKind(i) = 0 and handCost(i) = 8 then worth(i) = 9
end sub
