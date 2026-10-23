' Radogost p2: p1 planner with a sim budget scaled by board size (BASIC work limit) and no swings at 0-power minions.
'
' Each decision selects one explicit action, then runs again for the next.
' The engine never attacks, chooses targets, discards, or ends turns for you.
' Globals and arrays survive between decisions.
' random(n) returns a seeded integer in 0 to n - 1.
' The script chooses its own class, card order, attacks, targets and discards.
'
' READ-ONLY VALUES
'   selfPlayer enemyPlayer turnNumber
'   selfLife enemyLife energy totalEnergy
'   handSize selfBoardSize enemyBoardSize selfDeckSize enemyDeckSize
'   playerCount currentPlayer tossCount triggerTargets
'   selectingClass selfClass enemyClass
'   Setup: call pickClass(0=Archer, 1=Warrior, 2=Mage), list a deck with
'   deckCard(name$, copies), then END. A deck holds exactly 40 cards, 1 to 4
'   copies of each but the class cards (Archer, Warrior, Mage), which take
'   any number. Cards of another class cost 3 more energy, 1 less for each
'   class card of that class in play. An illegal deck is out before the
'   first turn. deckCard returns 0 for a name that is no card.
'   playerClass(p) returns any seat's class.
'
' HAND QUERIES (index 0 to handSize - 1)
'   handCost(i)       energy to play it now, off-class surcharge included
'   handKind(i)       0 = minion, 1 = spell, 2 = trinket
'   handPower(i)      attack (minions only)
'   handToughness(i)  toughness (minions only)
'   canPlay(i)        1 if affordable
'   needsChoice(i)    1 if the card needs a target
'
' CHOICE QUERIES
'   A choice kind of 4 is an option: the card offers branches to choose
'   between, and the choice index is the branch. Its value is in
'   optionDamage/optionSelfDamage below. Later targets only appear once an
'   option is picked, so ask the next* queries with the picks so far.
'   nextTargetCount(handIndex, "picks", pickedCount)
'   nextHelpsTarget(handIndex, "picks", pickedCount)
'   nextIntent(handIndex, "picks", pickedCount)
'   nextAmount(handIndex, "picks", pickedCount)
'   optionDamage(handIndex, "picks", pickedCount, option)
'   optionSelfDamage(handIndex, "picks", pickedCount, option)
'   targetIntent(handIndex, step)  what the card does to that target:
'                                  0 = nothing to judge, 1 = damage,
'                                  2 = buff, 3 = weaken, 4 = bounce,
'                                  5 = destroy, 6 = loses a keyword,
'                                  7 = steal
'   targetAmount(handIndex, step)  how much: damage dealt, stats changed
'   choiceCount(handIndex)              number of valid targets
'   choiceKind(handIndex, choiceIndex)  0=canceled 1=noTarget 2=hero 3=creature
'   choiceOwner(handIndex, choiceIndex) player who owns the target (-1 if n/a)
'   choiceId(handIndex, choiceIndex)    stable minion ID (0 for a hero)
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

' EXPLICIT ACTIONS AND VISIBLE BOARD QUERIES
'   handName$(i), boardCount(player), boardId(player, index)
'   boardName$(player, index), boardCard$(player, index)
'   handId$(i) returns the unique printed card name.
'   cardName$(id$), cardRules$(id$), cardKind(id$), cardClass(id$)
'   cardCost(id$), cardPower(id$), cardToughness(id$)
'   cardHasKeyword(id$, k), boardHasKeyword(p, i, k): k=0 is Ranged.
'   boardPower(p, i), boardHp(p, i), boardKind(p, i)
'   boardReady(p, i), boardAttacked(p, i)
'   playerLife(p), playerEnergy(p), playerTotalEnergy(p)
'   playerHandSize(p), playerDeckSize(p), playerDead(p)
'   attackChoiceCount(id), attackChoiceKind(id, choice)
'   attackChoiceOwner(id, choice), attackChoiceId(id, choice)
'   attack(id, choice)                 attack one chosen hero or minion
'   endTurn()                         finish without any automatic attacks
'   discardCards("picks")              discard tossCount indexes in picks()
'   resolveTrigger("picks")            answer triggerTargets in picks()
'   triggerChoiceCount(step), triggerChoiceKind(step, choice)
'   triggerChoiceOwner(step, choice), triggerChoiceId(step, choice)
'   triggerHelpsTarget(step)
'   playCardTargets(handIndex, "picks") choose any number of card targets
'   nextChoiceCount(handIndex, "picks", pickedCount)
'   nextChoiceKind(handIndex, "picks", pickedCount, choice)
'   nextChoiceOwner(handIndex, "picks", pickedCount, choice)
'   nextChoiceId(handIndex, "picks", pickedCount, choice)
' Use handIndex = -1 for trigger queries. Prefix queries include earlier picks.
' Successful commands return 1; refused commands return 0 and do nothing.
' Exactly one successful command is allowed per decision. END alone is not
' an action. A decision with no action stops the match with a player error.

IF selectingClass THEN
  pickClass(2)          ' Mage
  deckCard("Bouncer", 4)
  deckCard("Spirit", 4)
  deckCard("Plan", 4)
  deckCard("Primordial", 4)
  deckCard("Summon Primordial", 4)
  deckCard("Bubble Shield", 4)
  deckCard("Hail of Arrows", 4)
  deckCard("Study", 4)
  deckCard("Bubble", 4)
  deckCard("Control", 4)
  END
END IF

DIM picks(1023)
DIM junk(1023)
DIM shields(7)
' Bubbles per seat, counted once so string use stays under the limit.
p = 0
WHILE p < playerCount
  shields(p) = 0
  b = 0
  WHILE b < boardCount(p)
    IF boardKind(p, b) = 2 THEN
      IF boardName$(p, b) = "Bubble" THEN shields(p) = shields(p) + 1
    END IF
    b = b + 1
  WEND
  p = p + 1
WEND
IF tossCount > 0 THEN
  ' Rank the hand by what it is worth to you: a card you are still far from
  ' affording is dead weight, a minion is worth its body, and a spell about
  ' its price. Discard from the top of that ranking, ties at random.
  i = 0
  WHILE i < handSize
    picks(i) = i
    worth = 3 + handCost(i)
    IF handKind(i) = 0 THEN worth = handPower(i) + handToughness(i)
    over = handCost(i) - totalEnergy
    IF over < 0 THEN over = 0
    junk(i) = over * 4 - worth
    i = i + 1
  WEND
  i = 0
  WHILE i < tossCount
    best = i
    j = i + 1
    WHILE j < handSize
      take = 0
      IF junk(picks(j)) > junk(picks(best)) THEN take = 1
      IF junk(picks(j)) = junk(picks(best)) THEN take = random(2)
      IF take THEN best = j
      j = j + 1
    WEND
    swap = picks(i)
    picks(i) = picks(best)
    picks(best) = swap
    i = i + 1
  WEND
  discardCards("picks")
  END
END IF
IF triggerTargets > 0 THEN
  ' A trigger aims like a card: hand index -1 asks about the waiting one.
  ' With nothing worth aiming at, every legal choice stays eligible,
  ' including declining the target.
  s = 0
  count = nextTargetCount(-1, "picks", 0)
  WHILE s < count
    n = nextChoiceCount(-1, "picks", s)
    IF n = 0 THEN STOP
    i = -1
    branch = -1
    IF nextChoiceKind(-1, "picks", s, 0) = 4 THEN
      ' Morphosis Chamber: hide the big minion (branch 1), else Ranged (0).
      bigPower = 0
      b = 0
      WHILE b < boardCount(selfPlayer)
        IF boardKind(selfPlayer, b) = 0 AND boardPower(selfPlayer, b) > bigPower THEN bigPower = boardPower(selfPlayer, b)
        b = b + 1
      WEND
      branch = 0
      IF bigPower >= 5 THEN branch = 1
      IF branch >= n THEN branch = 0
    END IF
    IF branch >= 0 THEN
      picks(s) = branch
    ELSE
      GOSUB aim
    END IF
    ' A trigger that offers a choice reveals more targets once it is made.
    count = nextTargetCount(-1, "picks", s + 1)
    s = s + 1
  WEND
  resolveTrigger("picks")
  END
END IF


' The planner. Each decision reads the public state, scores every
' affordable set of cards and every attack assignment by a one-round
' simulation (our cards and swings, then each living rival's minions
' aimed by its known rule), and takes the first action of the best plan.
dbg = 0
me = selfPlayer
pc = playerCount
DIM bOwn(63)
DIM bPow(63)
DIM bHp(63)
DIM bRng(63)
DIM bId(63)
DIM bAl(63)
DIM cOwn(63)
DIM cPow(63)
DIM cHp(63)
DIM cAl(63)
DIM wOwn(63)
DIM wPow(63)
DIM wHp(63)
DIM wAl(63)
DIM bLife(7)
DIM bDead(7)
DIM bBub(7)
DIM cLife(7)
DIM cDead(7)
DIM cBub(7)
DIM wLife(7)
DIM wDead(7)
DIM wBub(7)
DIM rule(7)
DIM drawer(7)
DIM deckLast(7)
DIM rM(9)
DIM nOpt(9)
DIM optK(399)
DIM optT(399)
DIM optC(399)
DIM asg(9)
DIM bestAsg(9)
DIM cnt(11)
DIM ccost(11)
DIM cIdx(11)
DIM tk(11)
DIM bestTk(11)
DIM remList(63)
DIM remV(63)
DIM order(9)

' A new game (the turn counter fell) forgets what the last one learned.
IF turnNumber < lastTurn THEN
  p = 0
  WHILE p < 8
    drawer(p) = 0
    deckLast(p) = 0
    p = p + 1
  WEND
  seenTurns = 0
END IF
' Once per turn: a rival whose deck fell by two or more since our last
' turn draws extra cards (Study, Plan), so it is a pinger, not a warden.
IF turnNumber <> lastTurn THEN
  lastTurn = turnNumber
  seenTurns = seenTurns + 1
  p = 0
  WHILE p < pc
    d = playerDeckSize(p)
    IF deckLast(p) > 0 THEN
      IF deckLast(p) - d >= 2 THEN drawer(p) = 1
    END IF
    deckLast(p) = d
    p = p + 1
  WEND
END IF
' Attack rules: 0 hits the next seat, 1 the lowest-life unbubbled hero,
' 2 a pinger (mostly the next seat), 3 a Mage not yet read (half each).
p = 0
WHILE p < pc
  rule(p) = 0
  IF playerClass(p) = 2 THEN
    rule(p) = 3
    IF drawer(p) THEN
      rule(p) = 2
    ELSE
      IF seenTurns >= 4 THEN rule(p) = 1
    END IF
  END IF
  p = p + 1
WEND

' Public state: every minion, life and Bubble count.
nM = 0
p = 0
WHILE p < pc
  bLife(p) = playerLife(p) * 10
  bDead(p) = 0
  IF playerDead(p) THEN bDead(p) = 1
  bBub(p) = shields(p)
  b = 0
  WHILE b < boardCount(p)
    IF boardKind(p, b) = 0 THEN
      IF nM < 48 THEN
        bOwn(nM) = p
        bPow(nM) = boardPower(p, b)
        bHp(nM) = boardHp(p, b)
        bRng(nM) = 0
        IF boardHasKeyword(p, b, 0) THEN bRng(nM) = 1
        bId(nM) = boardId(p, b)
        bAl(nM) = 1
        nM = nM + 1
      END IF
    END IF
    b = b + 1
  WEND
  p = p + 1
WEND
prevSeat = me
q = 1
WHILE q < pc
  c2 = (me - q + pc) MOD pc
  IF prevSeat = me THEN
    IF playerDead(c2) = 0 THEN prevSeat = c2
  END IF
  q = q + 1
WEND

' Our ready minions, weakest first (they swing in this order, so a small
' one pops a Bubble before a big one lands), and their legal targets.
nR = 0
m = 0
WHILE m < nM
  IF bOwn(m) = me THEN
    IF nR < 8 THEN
      IF attackChoiceCount(bId(m)) > 0 THEN
        rM(nR) = m
        nR = nR + 1
      END IF
    END IF
  END IF
  m = m + 1
WEND
r = 0
WHILE r < nR
  j = r + 1
  WHILE j < nR
    IF bPow(rM(j)) < bPow(rM(r)) THEN
      x = rM(r)
      rM(r) = rM(j)
      rM(j) = x
    END IF
    j = j + 1
  WEND
  r = r + 1
WEND
r = 0
WHILE r < nR
  id = bId(rM(r))
  n = attackChoiceCount(id)
  no = 0
  c = 0
  WHILE c < n
    IF no < 40 THEN
      k = attackChoiceKind(id, c)
      o = attackChoiceOwner(id, c)
      t = -1
      IF k = 2 THEN
        t = o
      ELSE
        IF k = 3 THEN
          IF bDead(o) = 0 THEN
            d = attackChoiceId(id, c)
            x = 0
            WHILE x < nM
              IF bId(x) = d THEN
                IF bOwn(x) = o THEN
                  IF bPow(x) > 0 THEN t = x
                END IF
              END IF
              x = x + 1
            WEND
          END IF
        END IF
      END IF
      IF t >= 0 THEN
        optK(r * 40 + no) = k
        optT(r * 40 + no) = t
        optC(r * 40 + no) = c
        no = no + 1
      END IF
    END IF
    c = c + 1
  WEND
  nOpt(r) = no
  r = r + 1
WEND

' The hand: playable cards by name, counted once (string budget).
k = 0
WHILE k <= 11
  cnt(k) = 0
  tk(k) = 0
  bestTk(k) = 0
  cIdx(k) = -1
  k = k + 1
WEND
i = 0
WHILE i < handSize
  IF canPlay(i) THEN
    hc = 0
    name$ = handName$(i)
    IF name$ = "Bouncer" THEN hc = 1
    IF name$ = "Spirit" THEN hc = 2
    IF name$ = "Plan" THEN hc = 3
    IF name$ = "Primordial" THEN hc = 4
    IF name$ = "Summon Primordial" THEN hc = 5
    IF name$ = "Bubble Shield" THEN hc = 6
    IF name$ = "Hail of Arrows" THEN hc = 7
    IF name$ = "Study" THEN hc = 8
    IF name$ = "Control" THEN hc = 9
    IF name$ = "Bubble" THEN hc = 10
    IF hc > 0 THEN
      cnt(hc) = cnt(hc) + 1
      ccost(hc) = handCost(i)
      IF cIdx(hc) < 0 THEN cIdx(hc) = i
    END IF
  END IF
  i = i + 1
WEND
' A free Bubble always goes down first.
IF cnt(10) > 0 THEN
  IF playCard(cIdx(10)) THEN END
END IF
' Draws are dead once the deck runs low.
drawBonus = 40
IF selfDeckSize <= 5 THEN drawBonus = -50

' 1. The best attack assignment with no cards played.
sims = 0
' Each simulation costs about 1000 + 250 work per minion; stay near 3M of
' the 5M work budget per decision.
maxSims = 3000000 \ (1000 + 250 * nM)
GOSUB applyCards
GOSUB planAttacks
v0 = bestV
' 2. Removal targets ranked by what taking each one away is worth, and
' the hero whose whole board Summon Primordial should bounce.
nRem = 0
IF cnt(1) + cnt(9) > 0 THEN GOSUB rankRemoval
sumHero = -1
IF cnt(5) > 0 THEN GOSUB rankSummon
' 3. Every affordable card set, scored with those attacks.
nSets = 0
bestSet = v0
done = 0
WHILE done = 0
  k = 1
  carry = 1
  WHILE carry
    IF k > 9 THEN
      carry = 0
      done = 1
    ELSE
      IF tk(k) < cnt(k) THEN
        tk(k) = tk(k) + 1
        carry = 0
      ELSE
        tk(k) = 0
        k = k + 1
      END IF
    END IF
  WEND
  IF done = 0 THEN
    cost = 0
    k = 1
    WHILE k <= 9
      cost = cost + tk(k) * ccost(k)
      k = k + 1
    WEND
    IF cost <= energy THEN
      GOSUB applyCards
      IF valid THEN
        r = 0
        WHILE r < nR
          asg(r) = bestAsg(r)
          r = r + 1
        WEND
        GOSUB simulate
        value = value + bonus
        nSets = nSets + 1
        IF value > bestSet THEN
          bestSet = value
          k = 1
          WHILE k <= 9
            bestTk(k) = tk(k)
            k = k + 1
          WEND
        END IF
      END IF
    END IF
    IF sims > maxSims THEN done = 1
  END IF
WEND
IF dbg THEN
  PRINT "plan turn", turnNumber, "energy", energy, "sets", nSets, "sims", sims, "v0", v0, "best", bestSet, "take", bestTk(1), bestTk(2), bestTk(3), bestTk(4), bestTk(5), bestTk(6), bestTk(7), bestTk(8), bestTk(9), "rules", rule(0), rule(1), rule(2), rule(3), rule(4)
END IF

' 4. The first card of the best set: draws, removal, then bodies.
order(0) = 8
order(1) = 3
order(2) = 5
order(3) = 9
order(4) = 1
order(5) = 7
order(6) = 4
order(7) = 2
order(8) = 6
e = 0
WHILE e < 9
  k = order(e)
  IF bestTk(k) > 0 THEN
    i = cIdx(k)
    GOSUB playPlanned
  END IF
  e = e + 1
WEND

' 5. The attacks, weakest minion first.
r = 0
WHILE r < nR
  j = bestAsg(r)
  IF j >= 0 THEN
    IF dbg THEN PRINT "swing", bPow(rM(r)), "kind", optK(r * 40 + j), "at", optT(r * 40 + j), "v", v0
    IF attack(bId(rM(r)), optC(r * 40 + j)) THEN END
  END IF
  r = r + 1
WEND
endTurn()
END

playPlanned:
' Plays hand card i of code k at its planned target; returns on failure.
count = targetCount(i)
IF count = 0 THEN
  IF playCard(i) THEN END
  RETURN
END IF
want = -1
IF k = 1 OR k = 9 THEN
  x = 0
  WHILE x < nRem AND want < 0
    want = remList(x)
    x = x + 1
  WEND
END IF
s = 0
valid = 1
WHILE s < count AND valid
  n = nextChoiceCount(i, "picks", s)
  IF n = 0 THEN
    valid = 0
  ELSE
    best = -1
    IF s = 0 THEN
      c = 0
      WHILE c < n
        kk = nextChoiceKind(i, "picks", s, c)
        o = nextChoiceOwner(i, "picks", s, c)
        IF k = 5 THEN
          IF kk = 2 AND o = sumHero THEN best = c
        END IF
        IF want >= 0 THEN
          IF kk = 3 AND o = bOwn(want) THEN
            IF nextChoiceId(i, "picks", s, c) = bId(want) THEN best = c
          END IF
        END IF
        c = c + 1
      WEND
    END IF
    IF best >= 0 THEN
      picks(s) = best
    ELSE
      GOSUB aim
    END IF
    count = nextTargetCount(i, "picks", s + 1)
  END IF
  s = s + 1
WEND
IF valid THEN
  IF playCardTargets(i, "picks") THEN END
END IF
RETURN

planAttacks:
' Best assignment of our ready minions (option index, -1 holds) on the
' card state: every combination when there are few, else two rounds of
' one-minion improvements from all holding.
combos = 1
ra = 0
WHILE ra < nR
  asg(ra) = -1
  combos = combos * (nOpt(ra) + 1)
  IF combos > maxSims \ 2 THEN combos = maxSims \ 2 + 1
  ra = ra + 1
WEND
GOSUB simulate
bestV = value
ra = 0
WHILE ra < nR
  bestAsg(ra) = -1
  ra = ra + 1
WEND
IF nR = 0 THEN RETURN
IF combos <= maxSims \ 2 THEN
  fin = 0
  WHILE fin = 0
    ra = 0
    carry = 1
    WHILE carry
      IF ra >= nR THEN
        carry = 0
        fin = 1
      ELSE
        IF asg(ra) < nOpt(ra) - 1 THEN
          asg(ra) = asg(ra) + 1
          carry = 0
        ELSE
          asg(ra) = -1
          ra = ra + 1
        END IF
      END IF
    WEND
    IF fin = 0 THEN
      GOSUB simulate
      IF value > bestV THEN
        bestV = value
        xa = 0
        WHILE xa < nR
          bestAsg(xa) = asg(xa)
          xa = xa + 1
        WEND
      END IF
    END IF
  WEND
  RETURN
END IF
pass = 0
WHILE pass < 2
  ra = 0
  WHILE ra < nR
    xa = 0
    WHILE xa < nR
      asg(xa) = bestAsg(xa)
      xa = xa + 1
    WEND
    ja = -1
    WHILE ja < nOpt(ra) AND sims < maxSims \ 2
      asg(ra) = ja
      GOSUB simulate
      IF value > bestV THEN
        bestV = value
        bestAsg(ra) = ja
      END IF
      ja = ja + 1
    WEND
    ra = ra + 1
  WEND
  pass = pass + 1
WEND
RETURN

rankRemoval:
' Each living rival's minion, by the plan value of it leaving the board.
k = 0
WHILE k <= 9
  tk(k) = 0
  k = k + 1
WEND
tr = 0
WHILE tr < nM
  ot = bOwn(tr)
  IF ot <> me THEN
    IF bDead(ot) = 0 THEN
      GOSUB applyCards
      cAl(tr) = 0
      ra = 0
      WHILE ra < nR
        asg(ra) = bestAsg(ra)
        ra = ra + 1
      WEND
      GOSUB simulate
      ' Insert t by value, best first.
      xa = nRem
      moving = 1
      WHILE moving
        IF xa = 0 THEN
          moving = 0
        ELSE
          IF remV(xa - 1) < value THEN
            remList(xa) = remList(xa - 1)
            remV(xa) = remV(xa - 1)
            xa = xa - 1
          ELSE
            moving = 0
          END IF
        END IF
      WEND
      remList(xa) = tr
      remV(xa) = value
      nRem = nRem + 1
    END IF
  END IF
  tr = tr + 1
WEND
RETURN

rankSummon:
' The rival hero whose cards are worth most to bounce.
best = -1
hs = 0
WHILE hs < pc
  IF hs <> me THEN
    IF bDead(hs) = 0 THEN
      tk(5) = 0
      GOSUB applyCards
      ms = 0
      WHILE ms < nC
        IF cOwn(ms) = hs THEN cAl(ms) = 0
        ms = ms + 1
      WEND
      cBub(hs) = 0
      ra = 0
      WHILE ra < nR
        asg(ra) = bestAsg(ra)
        ra = ra + 1
      WEND
      GOSUB simulate
      IF best < 0 OR value > bestH THEN
        best = hs
        bestH = value
      END IF
    END IF
  END IF
  hs = hs + 1
WEND
sumHero = best
RETURN

applyCards:
' The card state: the board after playing tk(k) cards of each code.
m = 0
WHILE m < nM
  cOwn(m) = bOwn(m)
  cPow(m) = bPow(m)
  cHp(m) = bHp(m)
  cAl(m) = bAl(m)
  m = m + 1
WEND
nC = nM
p = 0
WHILE p < pc
  cLife(p) = bLife(p)
  cDead(p) = bDead(p)
  cBub(p) = bBub(p)
  p = p + 1
WEND
valid = 1
bonus = 0
IF tk(5) > 0 THEN
  IF sumHero < 0 THEN
    valid = 0
  ELSE
    m = 0
    WHILE m < nC
      IF cOwn(m) = sumHero THEN cAl(m) = 0
      m = m + 1
    WEND
    cBub(sumHero) = 0
    x = 0
    WHILE x < tk(5)
      np = 10
      nh = 10
      GOSUB addOurs
      x = x + 1
    WEND
  END IF
END IF
rp = 0
x = 0
WHILE x < tk(9)
  GOSUB nextRemoval
  IF t < 0 THEN
    valid = 0
  ELSE
    cOwn(t) = me
  END IF
  x = x + 1
WEND
x = 0
WHILE x < tk(1)
  GOSUB nextRemoval
  IF t < 0 THEN
    valid = 0
  ELSE
    cAl(t) = 0
  END IF
  np = 1
  nh = 1
  GOSUB addOurs
  x = x + 1
WEND
IF tk(7) > 0 THEN
  m = 0
  WHILE m < nC
    IF cOwn(m) <> me THEN
      IF cAl(m) THEN
        cHp(m) = cHp(m) - tk(7)
        IF cHp(m) <= 0 THEN cAl(m) = 0
      END IF
    END IF
    m = m + 1
  WEND
END IF
x = 0
WHILE x < tk(4)
  np = 10
  nh = 10
  GOSUB addOurs
  x = x + 1
WEND
x = 0
WHILE x < tk(2)
  np = 1
  nh = 3
  GOSUB addOurs
  x = x + 1
WEND
cBub(me) = cBub(me) + tk(6) * 2
bonus = tk(2) * 20 + (tk(3) + tk(8)) * drawBonus
RETURN

addOurs:
' A new minion of ours, np/nh, that cannot attack this turn.
IF nC < 63 THEN
  cOwn(nC) = me
  cPow(nC) = np
  cHp(nC) = nh
  cAl(nC) = 1
  nC = nC + 1
END IF
RETURN

nextRemoval:
' The best-ranked removal target still on a rival's board, from rp on.
t = -1
WHILE rp < nRem AND t < 0
  x2 = remList(rp)
  rp = rp + 1
  IF cAl(x2) THEN
    IF cOwn(x2) <> me THEN t = x2
  END IF
WEND
RETURN

simulate:
' Value of the card state plus attacks asg(): our swings, then one round
' of rival attacks, scored in tenths of life.
sims = sims + 1
m = 0
WHILE m < nC
  wOwn(m) = cOwn(m)
  wPow(m) = cPow(m)
  wHp(m) = cHp(m)
  wAl(m) = cAl(m)
  m = m + 1
WEND
p = 0
WHILE p < pc
  wLife(p) = cLife(p)
  wDead(p) = cDead(p)
  wBub(p) = cBub(p)
  p = p + 1
WEND
handBack = 0
r = 0
WHILE r < nR
  j = asg(r)
  IF j >= 0 THEN
    m = rM(r)
    IF wAl(m) THEN
      IF wOwn(m) = me THEN
        x = r * 40 + j
        h = -1
        t = -1
        IF optK(x) = 2 THEN
          h = optT(x)
        ELSE
          t = optT(x)
          IF wAl(t) = 0 OR wOwn(t) = me THEN
            ' Gone before the swing: it goes at that owner's hero instead.
            h = bOwn(t)
            t = -1
          END IF
        END IF
        IF h >= 0 THEN
          IF h <> me THEN
            IF wDead(h) = 0 THEN
              wLife(h) = wLife(h) - wPow(m) * 10
              IF wLife(h) <= 0 THEN wDead(h) = 1
              IF wBub(h) > 0 THEN
                ' The hit lands, then the Bubble bounces the attacker home.
                wBub(h) = wBub(h) - 1
                wAl(m) = 0
                IF wPow(m) <= 1 AND wHp(m) <= 1 THEN
                  ' A Bouncer back in hand is another bounce for 1.
                  handBack = handBack + 40
                ELSE
                  handBack = handBack + (3 * wPow(m) + wHp(m)) * 2
                END IF
              END IF
            END IF
          END IF
        END IF
        IF t >= 0 THEN
          IF bRng(t) = 0 OR bRng(m) = 1 THEN wHp(t) = wHp(t) - wPow(m)
          IF bRng(m) = 0 OR bRng(t) = 1 THEN wHp(m) = wHp(m) - wPow(t)
          IF wHp(t) <= 0 THEN wAl(t) = 0
          IF wHp(m) <= 0 THEN wAl(m) = 0
        END IF
      END IF
    END IF
  END IF
  r = r + 1
WEND
' The rivals' turns, in seat order after ours.
off = 1
WHILE off < pc
  r2 = (me + off) MOD pc
  IF wDead(r2) = 0 THEN
    pw = 0
    m = 0
    WHILE m < nC
      IF wOwn(m) = r2 THEN
        IF wAl(m) THEN pw = pw + wPow(m)
      END IF
      m = m + 1
    WEND
    IF pw > 0 THEN
      tn = -1
      q = 1
      WHILE q < pc
        IF tn < 0 THEN
          c2 = (r2 + q) MOD pc
          IF wDead(c2) = 0 THEN tn = c2
        END IF
        q = q + 1
      WEND
      IF tn >= 0 THEN
        share = 10
        IF rule(r2) = 1 THEN share = 0
        IF rule(r2) = 2 THEN share = 8
        IF rule(r2) = 3 THEN share = 5
        tl = tn
        IF share < 10 THEN
          tl = -1
          low = 999999
          q = 0
          WHILE q < pc
            IF q <> r2 THEN
              IF wDead(q) = 0 THEN
                IF wBub(q) = 0 THEN
                  IF wLife(q) < low THEN
                    low = wLife(q)
                    tl = q
                  END IF
                END IF
              END IF
            END IF
            q = q + 1
          WEND
          IF tl < 0 THEN tl = tn
        END IF
        wLife(tn) = wLife(tn) - pw * share
        wLife(tl) = wLife(tl) - pw * (10 - share)
        IF wLife(tn) <= 0 THEN wDead(tn) = 1
        IF wLife(tl) <= 0 THEN wDead(tl) = 1
      END IF
    END IF
  END IF
  off = off + 1
WEND
IF wDead(me) THEN
  value = -100000 + wLife(me)
  RETURN
END IF
value = wLife(me) * 3 + wBub(me) * 25 + handBack
p = 0
WHILE p < pc
  IF p <> me THEN
    IF wDead(p) THEN
      IF bDead(p) = 0 THEN
        value = value + 150
        IF p = prevSeat THEN value = value + 100
      END IF
    ELSE
      value = value - wLife(p)
    END IF
  END IF
  p = p + 1
WEND
' Whoever attacks us after the round.
att = -1
q = 1
WHILE q < pc
  IF att < 0 THEN
    c2 = (me - q + pc) MOD pc
    IF wDead(c2) = 0 THEN att = c2
  END IF
  q = q + 1
WEND
m = 0
WHILE m < nC
  IF wAl(m) THEN
    o = wOwn(m)
    IF o = me THEN
      value = value + (3 * wPow(m) + wHp(m)) * 5
    ELSE
      IF wDead(o) = 0 THEN
        IF o = att THEN
          value = value - wPow(m) * 15
        ELSE
          value = value - wPow(m) * 2
        END IF
      END IF
    END IF
  END IF
  m = m + 1
WEND
RETURN

aim:
' Choose the s'th target of hand card i (-1 for a waiting trigger) by what
' the card does to it. A target that helps goes on your best body; damage
' goes where it kills, otherwise at a hero; removal takes their biggest
' threat; a keyword only comes off a minion that has one. Ties break at
' random, and when nothing scores every choice stays eligible, so a lone
' minion still bounces itself and declining stays possible.
mine = nextHelpsTarget(i, "picks", s)
what = nextIntent(i, "picks", s)
size = nextAmount(i, "picks", s)
best = -1
bestScore = 0
c = 0
WHILE c < n
  k = nextChoiceKind(i, "picks", s, c)
  o = nextChoiceOwner(i, "picks", s, c)
  d = nextChoiceId(i, "picks", s, c)
  GOSUB score
  IF value > 0 THEN
    IF best < 0 THEN
      take = 1
    ELSE
      take = 0
      IF value > bestScore THEN take = 1
      IF value = bestScore THEN take = random(2)
    END IF
    IF take THEN
      best = c
      bestScore = value
    END IF
  END IF
  c = c + 1
WEND
IF best < 0 THEN
  picks(s) = random(n)
  RETURN
END IF
picks(s) = best
RETURN

score:
' What choice c is worth for this target: 0 means do not aim here. Scores
' stay small and positive so that equals can break at random.
value = 0
IF k = 4 THEN
  ' An option: worth what it deals, less twice what it costs your own hero,
  ' and never one that would finish you off.
  cost = optionSelfDamage(i, "picks", s, c)
  IF cost >= selfLife THEN RETURN
  value = 20 + optionDamage(i, "picks", s, c) - cost * 2
  IF value < 1 THEN value = 1
  RETURN
END IF
IF o < 0 THEN RETURN
IF mine THEN
  IF o <> selfPlayer THEN RETURN
ELSE
  IF o = selfPlayer THEN RETURN
END IF
IF k = 2 THEN
  ' A hero. Damage always lands, and a card that only offers heroes, like
  ' Summon Primordial, still has to pick one.
  value = 3
  IF mine THEN value = 0
ELSE
  GOSUB stats
  IF mine THEN
    value = 4 + power * 2 + hp
  ELSE
    IF what = 1 THEN
      ' Damage: a kill is worth their whole body, else soften the biggest.
      value = 1 + power
      IF hp <= size THEN value = 10 + power * 2 + hp
    ELSE
      IF what = 6 THEN
        ' Taking a keyword away only matters to a minion that has one.
        IF ranged THEN value = 10 + power * 2 + hp
      ELSE
        ' Bounce, destroy or weaken: take their biggest threat.
        value = 4 + power * 2 + hp
      END IF
    END IF
  END IF
END IF
IF value > 0 THEN
  IF o = enemyPlayer THEN value = value + 1
  IF o = prevSeat AND mine = 0 AND k = 3 THEN value = value + 12
END IF
RETURN

bubbled:
' How many Bubbles stand on player o's board (counted once per decision).
shielded = shields(o)
RETURN

stats:
' power, hp and ranged for the minion with id d on player o's board.
power = 0
hp = 0
ranged = 0
b = 0
WHILE b < boardCount(o)
  IF boardId(o, b) = d THEN
    power = boardPower(o, b)
    hp = boardHp(o, b)
    ranged = boardHasKeyword(o, b, 0)
    b = boardCount(o)
  END IF
  b = b + 1
WEND
RETURN

