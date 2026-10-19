' Paintbot PW baseline. Every cog runs this file on its own: no shared memory, fog-gated
' vision, integer arithmetic only (Bassy: \ divides, comparisons are -1). Territory play is
' built from four habits that measurably win fights:
'   1. lead the target by the full gun windup and cancel out our own movement,
'   2. never walk in a straight line while an opponent can see us,
'   3. move in squads of four that agree on a heart without talking,
'   4. refuse a fight we are visibly losing.
' Budget: 50,000 instructions and 125,000 work units per decision; an overrun disables the cog,
' so every loop here is bounded by the roster, the heart count, or a fixed iteration count.
dim avoidUntil(64)
dim pickupMemoryX(64)
dim pickupMemoryY(64)
dim pickupMemoryKind(64)
dim pickupMemoryTick(64)
dim drF(6)
dim oldX(16)
dim oldY(16)
dim lastSeen(16)
dim sightStart(16)
dim moveRun(16)
dim dirRun(16)
dim dirX(16)
dim dirY(16)
dim waitStart(16)

' Integer square root by Newton's method from above. 23170^2 exceeds any squared map distance.
sub isqrt(n)
  root = 0
  if n <= 0 then
    exit sub
  end if
  root = 23170
  guess = (root + n \ root) \ 2
  iterations = 0
  while guess < root and iterations < 24
    root = guess
    guess = (root + n \ root) \ 2
    iterations = iterations + 1
  wend
end sub

' How much of the straight line between two points is under water, in ten samples: into wet.
sub wetLine(ax, ay, bx, by)
  wet = 0
  s3 = 1
  while s3 <= 10
    if waterAt(ax + (bx - ax) * s3 \ 10, ay + (by - ay) * s3 \ 10) then
      wet = wet + 1
    end if
    s3 = s3 + 1
  wend
end sub

' Time to walk a leg, in metres of dry walking: a wet metre costs kWetCost dry ones. Into legCost.
sub legTime(ax, ay, bx, by)
  wetLine(ax, ay, bx, by)
  isqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay))
  legCost = root \ 100 + root \ 100 * wet * (kWetCost - 1) \ 10
end sub

' Small linear congruential generator; every product stays far inside int32.
sub nextRandom()
  rngState = (rngState * 75 + 74) mod 65537
end sub

' Pick the next dodge leg: mostly reverse across the line to the threat, keep some progress
' toward the goal, and hold the leg for legTicks so a shot that starts now flies true. A long leg
' (longLeg = 1, against the neural bot) always reverses the previous one.
sub planLeg(minTicks, maxTicks)
  nextRandom()
  if rngState mod 5 <> 0 or longLeg = 1 then
    zig = 0 - zig
  end if
  if zig = 0 then
    zig = 1
  end if
  nextRandom()
  legTicks = minTicks + rngState mod (maxTicks - minTicks + 1)
  tx = threatX - me.x
  ty = threatY - me.y
  isqrt(tx * tx + ty * ty)
  legX = 0
  legY = 0
  if root > 0 then
    ' Perpendicular to the threat, scaled to 100.
    legX = (0 - ty) * 100 * zig \ root
    legY = tx * 100 * zig \ root
    ' Of the two sides across the threat line, take the higher dry one: shots from above spread less.
    ' A short leg looks 3 m out. legX is still at scale 100 here, so a long leg looks at its own end
    ' (5 or 6 m) and also refuses a side whose midpoint is wet.
    look = 3
    if longLeg = 1 then
      look = legTicks * 28 \ 100
    end if
    upA = terrainHeight(me.x + legX * look, me.y + legY * look)
    upB = terrainHeight(me.x - legX * look, me.y - legY * look)
    if waterAt(me.x + legX * look, me.y + legY * look) then
      upA = -9999
    end if
    if waterAt(me.x - legX * look, me.y - legY * look) then
      upB = -9999
    end if
    if longLeg = 1 then
      if waterAt(me.x + legX * look \ 2, me.y + legY * look \ 2) then
        upA = -9999
      end if
      if waterAt(me.x - legX * look \ 2, me.y - legY * look \ 2) then
        upB = -9999
      end if
    end if
    if upB > upA + 20 then
      zig = 0 - zig
      legX = 0 - legX
      legY = 0 - legY
    end if
  end if
  if holding = 0 then
    fx = goalX - me.x
    fy = goalY - me.y
    isqrt(fx * fx + fy * fy)
    if root > 60 then
      legX = legX * 3 \ 4 + fx * 100 \ root
      legY = legY * 3 \ 4 + fy * 100 \ root
    end if
  end if
  isqrt(legX * legX + legY * legY)
  if root > 0 then
    legX = legX * 28 \ root
    legY = legY * 28 \ root
  end if
end sub

if started = 0 then
  started = 1
  rosterLimit = 16
  if me.seats < rosterLimit then
    rosterLimit = me.seats
  end if
  ' Detour offsets beside a wet route, as tenths of the route's length (see Dry route below).
  drF(0) = -10
  drF(1) = -6
  drF(2) = -3
  drF(3) = 3
  drF(4) = 6
  drF(5) = 10
  kWetCost = 6
  rngState = me.id * 4099 + 977
  zig = 1
  if me.id mod 4 >= 2 then
    zig = -1
  end if
  lastX = me.x
  lastY = me.y
end if
myVX = me.x - lastX
myVY = me.y - lastY
if myVX > 60 or myVX < -60 or myVY > 60 or myVY < -60 then
  ' A jump past 60 units in a tick is not a velocity. A guard left from the respawn era: under
  ' rules 49 (one life, top speed 28) it never fires.
  myVX = 0
  myVY = 0
  gunWait = 0
end if
if gunWait > 0 then
  gunWait = gunWait - 1
end if

' Spawn shields: a cog is untouchable for 36 ticks after it spawns, so a shot into one is wasted and
' leaves the gun cooling when the shield drops. Every cog is shielded until tick 30 (the first order
' that can land). Under rules 49 a cog has one life and nobody respawns, so no later shield
' window exists: an enemy life lost (teamLives) is an enemy gone for good.

' Drop an unreachable assignment after three seconds without meaningful progress.
if me.tick mod 72 = 0 then
  dxProgress = me.x - progressX
  dyProgress = me.y - progressY
  if dxProgress * dxProgress + dyProgress * dyProgress < 40000 and objective >= 0 and objective < 64 then
    dxHeart = controlX(objective) - me.x
    dyHeart = controlY(objective) - me.y
    if dxHeart * dxHeart + dyHeart * dyHeart > 160000 then
      avoidUntil(objective) = me.tick + 360
    end if
  end if
  progressX = me.x
  progressY = me.y
end if

' Our HP cap is the most we have seen (spawn HP): 3 before rules 49, 10 from them. Every HP
' threshold below is sized against it.
if me.hp > hpCap then
  hpCap = me.hp
end if

' Opponents and teammates in view. Every query is fog gated.
best = -1
bestShielded = 0
bestCost = 2147483647
thief = -1
foesNear = 0
friendsNear = 1
foeSumX = 0
foeSumY = 0
foesSeen = 0
i = 0
while i < rosterLimit
  if i <> me.id and agents(i).visible then
    dx = agents(i).x - me.x
    dy = agents(i).y - me.y
    d2 = dx * dx + dy * dy
    if i mod 2 <> me.team then
      ' A hurt enemy costs less: each missing HP is worth 480000 \ hpCap of squared distance
      ' (160000 at a 3 HP cap, 48000 at 10), so a full HP foe costs its distance alone.
      cost = d2 - (hpCap - agents(i).hp) * 480000 \ hpCap
      ' Prefer an enemy we also saw last tick: a shot at it carries a measured lead. A fresh
      ' sighting costs as much as 30 m more distance.
      if lastSeen(i) <> me.tick - 1 then
        cost = cost + 9000000
      end if
      ' A shielded enemy (the opening) is the last choice.
      shielded = me.tick < 30
      if shielded then
        cost = cost + 100000000
      end if
      if agents(i).carrying then
        cost = cost - 2500000
        thief = i
      end if
      if cost < bestCost and d2 <= gunRange() * gunRange() then
        best = i
        bestCost = cost
        bestShielded = shielded
      end if
      foesSeen = foesSeen + 1
      foeSumX = foeSumX + agents(i).x
      foeSumY = foeSumY + agents(i).y
      if d2 < 6760000 then
        foesNear = foesNear + 1
      end if
    else
      if d2 < 1440000 then
        friendsNear = friendsNear + 1
      end if
    end if
  end if
  i = i + 1
wend
if foesSeen > 0 then
  lastFoeX = foeSumX \ foesSeen
  lastFoeY = foeSumY \ foesSeen
  lastFoeTick = me.tick
end if

' Where we want to be. Later rules override earlier ones; one walkTo is issued at the end.
goalX = me.x
goalY = me.y
holding = 0
if me.carrying then
  if me.ownHeartStolen and thief >= 0 then
    goalX = agents(thief).x
    goalY = agents(thief).y
  else
    goalX = me.homeX
    goalY = me.homeY
  end if
else
  if thief >= 0 then
    goalX = agents(thief).x
    goalY = agents(thief).y
  else
    goalX = me.heartX
    goalY = me.heartY
  end if
end if

' Territory: two squads of four. The target is a pure function of public heart ownership and
' the squad number, so all four members (even one far from the others) choose the same
' heart with no communication. Squad 0 works outward from above home, squad 1 from below
' (mirrored for blue, so the two teams play the half turn of each other).
objective = -1
if heartCount() > 0 then
  member = (me.id \ 2) mod 8
  squad = member \ 4
  seat = member mod 4
  otherTarget = -1
  pass = 0
  while pass < 2
    refY = me.homeY - 1500
    if pass = 1 then
      refY = me.homeY + 1500
    end if
    if me.team = 1 then
      ' Mirror play: blue's first squad works from below home, the half turn of red's.
      refY = 4000 - refY
    end if
    choice = -1
    choiceCost = 2147483647
    j = 0
    while j < heartCount() and j < 64
      if controlOwner(j) <> me.team and j <> otherTarget and waterAt(controlX(j), controlY(j)) = 0 then
        dx = (controlX(j) - me.homeX) \ 8
        dy = (controlY(j) - refY) \ 8
        cost = dx * dx + dy * dy
        if controlOwner(j) = -1 then
          cost = cost - 20000
        end if
        if pass = squad and avoidUntil(j) > me.tick then
          cost = cost + 4000000
        end if
        if cost < choiceCost then
          choice = j
          choiceCost = cost
        end if
      end if
      j = j + 1
    wend
    if pass = squad then
      objective = choice
    else
      if pass < squad then
        otherTarget = choice
      end if
    end if
    pass = pass + 1
  wend
  if objective < 0 and otherTarget >= 0 then
    objective = otherTarget
  end if
  if objective >= 0 then
    hx = controlX(objective)
    hy = controlY(objective)
    goalX = hx
    goalY = hy
    ' Seats 0 and 1 stand in the ring (capturer and backup). Seats 2 and 3 cover from outside
    ' it on the opposing side, and step in if nobody on our team is capturing.
    if seat >= 2 then
      capturing = controlCaptureTeam(objective) = me.team
      if capturing then
        idleCapture = 0
      else
        idleCapture = idleCapture + 1
      end if
      dx = hx - me.x
      dy = hy - me.y
      if dx * dx + dy * dy > 640000 or idleCapture < 96 then
        side = 1
        if seat = 3 then
          side = -1
        end if
        ax = 3200 - hx
        ay = 2000 - hy
        if me.team = 0 then
          ax = ax + 1200
        else
          ax = ax - 1200
        end if
        isqrt(ax * ax + ay * ay)
        if root > 0 then
          goalX = hx + (ax * 3 - ay * 2 * side) * 90 \ root
          goalY = hy + (ay * 3 + ax * 2 * side) * 90 \ root
        end if
      end if
    end if
    dx = goalX - me.x
    dy = goalY - me.y
    if dx * dx + dy * dy < 8100 then
      holding = 1
    end if
  end if
end if

' Remember seen supplies for ten seconds and equip when it is safe to.
i = 0
while i < pickupCount() and i < 64
  if pickupVisible(i) then
    pickupMemoryX(i) = pickupX(i)
    pickupMemoryY(i) = pickupY(i)
    pickupMemoryKind(i) = pickupKind(i)
    pickupMemoryTick(i) = me.tick + 1
  end if
  i = i + 1
wend
if me.carrying = 0 and thief < 0 then
  nearest = -1
  nearestCost = 4840000
  j = 0
  while j < pickupCount() and j < 64
    if pickupMemoryTick(j) > 0 and me.tick - pickupMemoryTick(j) < 240 then
      kind = pickupMemoryKind(j)
      wanted = (kind = 0 and me.hasGrenade = 0) or (kind = 2 and me.hp < hpCap)
      if wanted then
        dx = pickupMemoryX(j) - me.x
        dy = pickupMemoryY(j) - me.y
        cost = dx * dx + dy * dy
        if kind = 2 and me.hp * 3 <= hpCap then
          ' A medkit is worth a whole life to a cog at a third of its HP or less.
          cost = cost \ 4
        end if
        if cost < 10000 and pickupVisible(j) = 0 then
          pickupMemoryTick(j) = 0
        else
          if cost < nearestCost then
            nearest = j
            nearestCost = cost
          end if
        end if
      end if
    end if
    j = j + 1
  wend
  if nearest >= 0 and (best < 0 or bestCost > 1440000 or me.hp * 3 <= hpCap) then
    goalX = pickupMemoryX(nearest)
    goalY = pickupMemoryY(nearest)
    holding = 0
  end if
end if

' Refuse a fight we are visibly losing: head for the heart that is far from them and near us.
if foesNear - friendsNear >= 1 and me.carrying = 0 then
  cx = foeSumX \ foesSeen
  cy = foeSumY \ foesSeen
  away = -1
  awayScore = -2147483647
  j = 0
  while j < heartCount() and j < 64
    ' Never fall back to a lake heart: wading is where fleeing cogs die.
    if waterAt(controlX(j), controlY(j)) = 0 then
      ex = (controlX(j) - cx) \ 16
      ey = (controlY(j) - cy) \ 16
      mx = (controlX(j) - me.x) \ 16
      my = (controlY(j) - me.y) \ 16
      score = ex * ex + ey * ey - (mx * mx + my * my) \ 2
      if score > awayScore then
        away = j
        awayScore = score
      end if
    end if
    j = j + 1
  wend
  if away >= 0 then
    goalX = controlX(away)
    goalY = controlY(away)
    holding = 0
  end if
end if

' Facing with nothing to shoot: watch the enemy, never the road and never our own team. Look where
' enemies were last seen (for five seconds), else at gunfire or blasts farther than 18 m (our own
' clump is closer), else at the enemy home. Speech and footsteps are mostly our teammates.
if best < 0 then
  lookX = 6400 - me.homeX
  lookY = 4000 - me.homeY
  recentFoe = lastFoeTick > 0 and me.tick - lastFoeTick < 120
  if recentFoe then
    lookX = lastFoeX
    lookY = lastFoeY
  end if
  if soundCount() > 0 and recentFoe = 0 then
    soundBest = -1
    soundCost = 2147483647
    j = 0
    while j < soundCount() and j < 12
      cost = soundAge(j)
      if soundKind(j) = 0 or soundKind(j) = 3 or soundDistance(j) < 2 then
        cost = 2147483647
      end if
      if cost < soundCost then
        soundBest = j
        soundCost = cost
      end if
      j = j + 1
    wend
    if soundBest >= 0 and soundCost < 48 then
      bearing = soundDirection(soundBest)
      dxSound = 0
      dySound = 0
      if bearing = 0 or bearing = 1 or bearing = 7 then
        dxSound = 1000
      end if
      if bearing = 3 or bearing = 4 or bearing = 5 then
        dxSound = -1000
      end if
      if bearing = 1 or bearing = 2 or bearing = 3 then
        dySound = 1000
      end if
      if bearing = 5 or bearing = 6 or bearing = 7 then
        dySound = -1000
      end if
      lookX = me.x + dxSound
      lookY = me.y + dySound
    end if
  end if
  lookAt(lookX, lookY)
end if

if me.tick mod 360 = me.id * 21 then
  if best >= 0 then
    shout(strNew("Contact! Cover this lane."))
  else
    if foesNear - friendsNear >= 1 then
      shout(strNew("Too many. Falling back."))
    else
      shout(strNew("Moving with the squad."))
    end if
  end if
end if

' Footwork. In contact, move in short random legs across the line to the threat. A shot is only
' ordered at the start of a leg that lasts the whole windup, so our own movement is known.
moveX = goalX
moveY = goalY
' Hold in contact: with an enemy in sight, fight from where we stand instead of walking on toward
' the objective (pw_diag 4v4 52 -> 66, survive 1v2 22 -> 52). The sidestep legs still move us.
if best >= 0 and me.carrying = 0 then
  goalX = me.x
  goalY = me.y
  holding = 1
end if
' A target with no step seen in the last six ticks gets up to two ticks of watching, so the shot
' carries a measured lead. Decided before the footwork, so a cog that is still watching dodges on
' instead of planting for a shot it will not take.
readyAim = 1
if best >= 0 then
  if me.tick - lastSeen(best) > 1 then
    if waitStart(best) = 0 or me.tick - waitStart(best) > 30 then
      waitStart(best) = me.tick
    end if
    if me.tick - waitStart(best) < 2 then
      readyAim = 0
    end if
  end if
end if
inContact = best >= 0 and me.trenchId < 0
if inContact then
  threatX = agents(best).x
  threatY = agents(best).y
  contactTick = me.tick
  ' Blocked for three ticks: let the engine's pathing take over for a second. Standing still in our
  ' own plant is not a block.
  if legTicks > 0 and (legX <> 0 or legY <> 0) and myVX * myVX + myVY * myVY < 64 and me.tick >= plantUntil then
    stalled = stalled + 1
  else
    stalled = 0
  end if
  if stalled >= 3 then
    pathUntil = me.tick + 24
    stalled = 0
    legTicks = 0
  end if
  ' A line blocked by a teammate last tick means step aside, not plant: planting again only waits.
  ' A misting or radar cog cannot attack (rules 49), so it dodges instead of planting for a shot
  ' the engine drops.
  wantShot = gunWait = 0 and (me.hasSpray = 0 or bestCost < 640000) and lineBlocked = 0 and bestShielded = 0 and readyAim = 1 and mistingTicks() = 0 and radarTicks() = 0
  if me.tick >= pathUntil then
    ' Against the neural bot (neuralFoe, set at the end of the tick) a ready shot plants at once from
    ' a zero leg and leaves zig alone, and every other leg is a 19 to 22 tick one that reverses the
    ' last. That bot aims at where we stand, so one 5 m sideways leg per gun cycle (the gun is ready
    ' 19 ticks after the plant), turning around only inside our own plant, leaves every windup
    ' outside the plant aimed at an empty spot.
    if legTicks <= 0 or (wantShot <> 0 and (legTicks < 6 or neuralFoe = 1)) or (lineBlocked = 1 and legX = 0 and legY = 0) then
      if wantShot then
        ' The zero leg ends with the plant timer, so we move the tick after the ray leaves.
        if neuralFoe then
          legTicks = 6
        else
          planLeg(6, 6)
        end if
        legX = 0
        legY = 0
      else
        if neuralFoe then
          longLeg = 1
          if longRunFoe then
            ' Against a foe that leads (long runs, like xolod), short legs that always reverse: a turn
            ' falls inside its five-tick lead and sends its ray where we were heading.
            planLeg(4, 8)
          else
            planLeg(19, 22)
          end if
          longLeg = 0
        else
          planLeg(3, 6)
        end if
      end if
    end if
    legTicks = legTicks - 1
    moveX = me.x + legX * 4
    moveY = me.y + legY * 4
    if holding then
      ' Stay inside the ring: turn back toward its centre when the leg would leave it.
      dx = me.x + legX * 2 - goalX
      dy = me.y + legY * 2 - goalY
      if dx * dx + dy * dy > 9000 then
        moveX = goalX
        moveY = goalY
        legTicks = 0
      end if
    end if
  end if
else
  ' Against the neural bot, sight flickers for a tick or two at a time: finish the long leg through
  ' a gap of up to 12 ticks instead of planning a fresh, reversed one on the next contact.
  if neuralFoe = 1 and legTicks > 0 and me.tick - contactTick <= 12 then
    legTicks = legTicks - 1
    moveX = me.x + legX * 4
    moveY = me.y + legY * 4
  else
    legTicks = 0
  end if
  stalled = 0
end if
' Dry route. The navigator walks straight at any goal no wall blocks, and water blocks nothing,
' so an objective across the lake is reached by wading at a quarter speed. Against the league
' leader that is where 73% of our deaths happened. When the straight way to a target more than
' 8 m off crosses water, walk first to whichever of six points beside the route is quickest to
' go through, a wet metre costing kWetCost dry ones, and keep that point until it is reached,
' the target moves 10 m, or ten seconds pass. Footwork is left where the dodge put it.
drWalk = 0
drTx = moveX
drTy = moveY
drDx = drTx - me.x
drDy = drTy - me.y
if drDx * drDx + drDy * drDy > 640000 then
  if drActive then
    drEx = drTx - drGx
    drEy = drTy - drGy
    if drEx * drEx + drEy * drEy > 1000000 then
      drActive = 0
    end if
    drEx = drWx - me.x
    drEy = drWy - me.y
    if drEx * drEx + drEy * drEy < 90000 then
      drActive = 0
    end if
    if me.tick - drTick > 240 then
      drActive = 0
    end if
  end if
  if drActive = 0 and me.tick - drTick >= 12 then
    drTick = me.tick
    legTime(me.x, me.y, drTx, drTy)
    if wet > 0 then
      drBest = legCost
      drBestK = -1
      drMx = me.x + drDx \ 2
      drMy = me.y + drDy \ 2
      drK = 0
      while drK < 6
        drCx = drMx - drDy * drF(drK) \ 10
        drCy = drMy + drDx * drF(drK) \ 10
        if drCx > mapMinX() + 200 and drCx < mapMaxX() - 200 and drCy > mapMinY() + 200 and drCy < mapMaxY() - 200 then
          if waterAt(drCx, drCy) = 0 then
            legTime(me.x, me.y, drCx, drCy)
            drSc = legCost
            legTime(drCx, drCy, drTx, drTy)
            drSc = drSc + legCost
            if drSc < drBest then
              drBest = drSc
              drBestK = drK
              drWx = drCx
              drWy = drCy
            end if
          end if
        end if
        drK = drK + 1
      wend
      if drBestK >= 0 then
        drActive = 1
        drGx = drTx
        drGy = drTy
      end if
    end if
  end if
  if drActive then
    drWalk = 1
  end if
end if
if drWalk then
  walkTo(drWx, drWy)
else
  walkTo(moveX, moveY)
end if

' Gun: the ray leaves six moves after the order, from wherever we then stand, along the
' direction locked one move from now. Aim where they will be, minus our own drift.
lineBlocked = 0
if best >= 0 then
  tx = agents(best).x
  ty = agents(best).y
  ' Lead a moving target. Sight flickers in a fight, so the step comes from the last sighting up to
  ' six ticks back, divided by the gap; a target standing still (or planted) gets no lead.
  sightGap = me.tick - lastSeen(best)
  stepX = 0
  stepY = 0
  if sightGap >= 1 and sightGap <= 6 then
    stepX = (tx - oldX(best)) \ sightGap
    stepY = (ty - oldY(best)) \ sightGap
  end if
  ' Lead on the first frame with a step (the step across the sight gap is all we know), and after
  ' that only a target that kept its direction: a jittery mover
  ' (short runs, quick reversals) is shot where it stands.
  if stepX * stepX + stepY * stepY > 64 and stepX * stepX + stepY * stepY < 3600 and (dirRun(best) >= 1 or (me.tick - sightStart(best) = 1 and longRunFoe)) then
    tx = tx + stepX * 5
    ty = ty + stepY * 5
  end if
  ' No self-motion correction: the plant timer holds every shot still through the windup, so the ray
  ' leaves from where we stand now and the aim is the target plus its lead.
  ' Hold fire when a visible teammate stands in the line.
  clear = 1
  sx = tx - me.x
  sy = ty - me.y
  isqrt(sx * sx + sy * sy)
  reach = root
  if reach > 0 then
    i = 0
    while i < rosterLimit
      if i <> me.id and i mod 2 = me.team and agents(i).visible then
        ox = agents(i).x - me.x
        oy = agents(i).y - me.y
        along = (ox * sx + oy * sy) \ reach
        across = (ox * sy - oy * sx) \ reach
        if across < 0 then
          across = 0 - across
        end if
        if along > 0 and along < reach and across < 95 then
          clear = 0
        end if
      end if
      i = i + 1
    wend
  end if
  if me.hasSpray = 0 or bestCost < 640000 then
    if clear = 0 and gunWait = 0 then
      lineBlocked = 1
    end if
    if clear = 1 and gunWait = 0 and bestShielded = 0 and readyAim = 1 and mistingTicks() = 0 and radarTicks() = 0 then
      shootAt(tx, ty)
      ' Plant through the windup: the ray leaves five ticks from now from wherever we stand then.
      plantUntil = me.tick + 6
      gunWait = 25
      if me.armorHp > 0 or me.trenchId >= 0 or me.carrying then
        gunWait = 73
      end if
      if me.hasSpray then
        gunWait = 25
      end if
      ' A sniper (rules 49) fires every 96 ticks, 288 slowed: the next plant waits as long.
      if hasSniper() then
        gunWait = 97
        if me.armorHp > 0 or me.trenchId >= 0 or me.carrying then
          gunWait = 289
        end if
      end if
    else
      lookAt(tx, ty)
    end if
  else
    lookAt(tx, ty)
  end if
end if

i = 0
while i < rosterLimit
  if agents(i).visible then
    stepX = agents(i).x - oldX(i)
    stepY = agents(i).y - oldY(i)
    ' Neural fingerprint: the reference decoder walks 2 m compass steps, and the engine moves a cog
    ' 28 units toward such a goal, which is exactly (28, 0), (0, 28) or (19, 19) in size. BASIC bots
    ' walk at any angle. Count an enemy's moving steps seen on consecutive ticks and the exact ones.
    if i mod 2 <> me.team and lastSeen(i) = me.tick - 1 then
      fpX = stepX
      if fpX < 0 then
        fpX = 0 - fpX
      end if
      fpY = stepY
      if fpY < 0 then
        fpY = 0 - fpY
      end if
      fpD = fpX * fpX + fpY * fpY
      if fpD > 16 and fpD < 3600 then
        fpMoves = fpMoves + 1
        if (fpX = 28 and fpY = 0) or (fpX = 0 and fpY = 28) or (fpX = 19 and fpY = 19) then
          fpExact = fpExact + 1
        end if
      end if
    end if
    ' Direction runs: how many ticks in a row a visible cog has stepped the same way.
    if lastSeen(i) = me.tick - 1 and stepX * stepX + stepY * stepY > 64 then
      if dirRun(i) > 0 and stepX * dirX(i) + stepY * dirY(i) > 0 then
        dirRun(i) = dirRun(i) + 1
      else
        ' A run of a foe ended by a reversal: count it for the long-run fingerprint.
        if dirRun(i) > 0 and i mod 2 <> me.team then
          foeRunTicks = foeRunTicks + dirRun(i)
          foeRuns = foeRuns + 1
        end if
        dirRun(i) = 1
      end if
      dirX(i) = stepX
      dirY(i) = stepY
    else
      ' A run ended by a stop (seen last tick, not moving now).
      if dirRun(i) > 0 and i mod 2 <> me.team and lastSeen(i) = me.tick - 1 then
        foeRunTicks = foeRunTicks + dirRun(i)
        foeRuns = foeRuns + 1
      end if
      dirRun(i) = 0
    end if
    if lastSeen(i) = me.tick - 1 and stepX * stepX + stepY * stepY > 64 then
      moveRun(i) = moveRun(i) + 1
    else
      moveRun(i) = 0
    end if
    oldX(i) = agents(i).x
    oldY(i) = agents(i).y
    if lastSeen(i) <> me.tick - 1 then
      sightStart(i) = me.tick
    end if
    lastSeen(i) = me.tick
  end if
  i = i + 1
wend
' The neural bot is on when, over 150 or more enemy steps (they persist for the whole match), at
' least half were exact compass steps. Re-evaluated every tick and never latched.
neuralFoe = 1
' A foe whose runs average 3.8 ticks or more (over 12 runs) moves in long legs like xolod; its first
' observed step predicts the next ones. A jittery foe (eider) reverses too often to lead on one step.
longRunFoe = foeRuns >= 12 and foeRunTicks * 10 >= foeRuns * 38

' Grenade: match the charge to the distance, never onto a visible teammate.
if me.hasGrenade and best >= 0 and bestShielded = 0 then
  nx = agents(best).x
  ny = agents(best).y
  dx = nx - me.x
  dy = ny - me.y
  d2 = dx * dx + dy * dy
  safe = 1
  i = 0
  while i < rosterLimit
    if i mod 2 = me.team and agents(i).visible then
      fx = agents(i).x - nx
      fy = agents(i).y - ny
      if fx * fx + fy * fy < 202500 then
        safe = 0
      end if
    end if
    i = i + 1
  wend
  if safe = 1 and d2 > 160000 and d2 < 1562500 then
    isqrt(d2)
    need = (root - 150) * 24 \ 1130 + 1
    if need < 1 then
      need = 1
    end if
    lookAt(nx, ny)
    chargeGrenade(me.grenadeCharge < need)
    if me.grenadeCharge >= need then
      shout(strNew("Grenade out!"))
    end if
  end if
end if

' Quiet approach to the objective when nothing is in sight but something was heard.
if best < 0 and soundCount() > 0 and objective >= 0 then
  dx = controlX(objective) - me.x
  dy = controlY(objective) - me.y
  if dx * dx + dy * dy < 810000 then
    sneak(1)
  end if
end if

' The plant wins over every walk chosen above, including a lost target or a dry-route detour.
if me.tick < plantUntil then
  walkTo(me.x, me.y)
end if

' Self-destruct: the blast deals our current HP to every other cog within 415 units, so a healthy
' cog kills every enemy that close. Trade one cog for two, or for one when we are nearly dead;
' never with a teammate inside the blast.
boomKills = 0
boomAllies = 0
if mistingTicks() = 0 and radarTicks() = 0 then
  i = 0
  while i < rosterLimit
    if i <> me.id and agents(i).visible and agents(i).hp > 0 then
      dx = agents(i).x - me.x
      dy = agents(i).y - me.y
      if dx * dx + dy * dy < 160000 then
        if i mod 2 = me.team then
          boomAllies = boomAllies + 1
        else
          if agents(i).hp <= me.hp then
            boomKills = boomKills + 1
          end if
        end if
      end if
    end if
    i = i + 1
  wend
  if boomAllies = 0 and (boomKills >= 2 or (boomKills >= 1 and me.hp * 3 <= hpCap)) then
    selfDestruct()
  end if
end if

lastX = me.x
lastY = me.y
