' Paintbot PW baseline. Every cog runs this file on its own: no shared memory, fog-gated
' vision, int32 only. Territory play is built from four habits that measurably win fights:
'   1. lead the target by the full gun windup and cancel out our own movement,
'   2. never walk in a straight line while an opponent can see us,
'   3. move in squads of four that agree on a heart without talking,
'   4. refuse a fight we are visibly losing.
' Budget: 20,000 instructions per decision; an overrun disables the cog, so every loop here
' is bounded by the 16 seats, the heart count, or a fixed iteration count.
dim avoidUntil(64)
dim pickupMemoryX(64)
dim pickupMemoryY(64)
dim pickupMemoryKind(64)
dim pickupMemoryTick(64)
dim drF(6)
dim oldX(16)
dim oldY(16)
dim lastSeen(16)
dim dropTick(8)
dim sightStart(16)
dim moveRun(16)
dim lastStepX(16)
dim lastStepY(16)

' Integer square root by Newton's method from above. 23170^2 exceeds any squared map distance.
sub isqrt(n)
  root = 0
  if n <= 0 then
    exit sub
  end if
  root = 23170
  guess = (root + n / root) / 2
  iterations = 0
  while guess < root and iterations < 24
    root = guess
    guess = (root + n / root) / 2
    iterations = iterations + 1
  wend
end sub

' How much of the straight line between two points is under water, in ten samples: into wet.
sub wetLine(ax, ay, bx, by)
  wet = 0
  s3 = 1
  while s3 <= 10
    if waterAt(ax + (bx - ax) * s3 / 10, ay + (by - ay) * s3 / 10) then
      wet = wet + 1
    end if
    s3 = s3 + 1
  wend
end sub

' Time to walk a leg, in metres of dry walking: a wet metre costs kWetCost dry ones. Into legCost.
sub legTime(ax, ay, bx, by)
  wetLine(ax, ay, bx, by)
  isqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay))
  legCost = root / 100 + root / 100 * wet * (kWetCost - 1) / 10
end sub

' Small linear congruential generator; every product stays far inside int32.
sub nextRandom()
  rngState = (rngState * 75 + 74) mod 65537
end sub

' Pick the next dodge leg: mostly reverse across the line to the threat, keep some progress
' toward the goal, and hold the leg for legTicks so a shot that starts now flies true.
sub planLeg(minTicks, maxTicks)
  nextRandom()
  if rngState mod 5 <> 0 then
    zig = 0 - zig
  end if
  if zig = 0 then
    zig = 1
  end if
  nextRandom()
  legTicks = minTicks + rngState mod (maxTicks - minTicks + 1)
  tx = threatX - selfX
  ty = threatY - selfY
  isqrt(tx * tx + ty * ty)
  legX = 0
  legY = 0
  if root > 0 then
    ' Perpendicular to the threat, scaled to 100.
    legX = (0 - ty) * 100 * zig / root
    legY = tx * 100 * zig / root
    ' Of the two sides across the threat line, take the higher dry one: shots from above spread less.
    upA = terrainHeight(selfX + legX * 3, selfY + legY * 3)
    upB = terrainHeight(selfX - legX * 3, selfY - legY * 3)
    if waterAt(selfX + legX * 3, selfY + legY * 3) then
      upA = -9999
    end if
    if waterAt(selfX - legX * 3, selfY - legY * 3) then
      upB = -9999
    end if
    if upB > upA + 20 then
      zig = 0 - zig
      legX = 0 - legX
      legY = 0 - legY
    end if
  end if
  if holding = 0 then
    fx = goalX - selfX
    fy = goalY - selfY
    isqrt(fx * fx + fy * fy)
    if root > 60 then
      legX = legX * 3 / 4 + fx * 100 / root
      legY = legY * 3 / 4 + fy * 100 / root
    end if
  end if
  isqrt(legX * legX + legY * legY)
  if root > 0 then
    legX = legX * 28 / root
    legY = legY * 28 / root
  end if
end sub

if started = 0 then
  started = 1
  ' Detour offsets beside a wet route, as tenths of the route's length (see Dry route below).
  drF(0) = -10
  drF(1) = -6
  drF(2) = -3
  drF(3) = 3
  drF(4) = 6
  drF(5) = 10
  kWetCost = 6
  rngState = selfId * 4099 + 977
  zig = 1
  if selfId mod 4 >= 2 then
    zig = -1
  end if
  lastX = selfX
  lastY = selfY
  prevFoeLives = teamLives(1 - selfTeam)
end if
myVX = selfX - lastX
myVY = selfY - lastY
if myVX > 60 or myVX < -60 or myVY > 60 or myVY < -60 then
  ' A respawn teleports us; that is not a velocity.
  myVX = 0
  myVY = 0
  gunWait = 0
  prevFoeLives = teamLives(1 - selfTeam)
end if
if gunWait > 0 then
  gunWait = gunWait - 1
end if
' Count the ticks the gun has been ready: a shot held for an unpredictable target waits at most 12.
if gunWait = 0 then
  readyTicks = readyTicks + 1
else
  readyTicks = 0
end if

' Spawn shields: a cog is untouchable for 36 ticks after it spawns, so a shot into one is wasted and
' leaves the gun cooling when the shield drops. Every cog is shielded until tick 30 (the first order
' that can land); an enemy life lost at tick D respawns at D+72 near one of its hearts and can be hit
' by an order from D+102 on. Dead cogs do not run, so the count is resynced on our respawn.
foeLives = teamLives(1 - selfTeam)
if foeLives < prevFoeLives then
  dropTick(dropCount mod 8) = worldTick
  dropCount = dropCount + 1
end if
prevFoeLives = foeLives
shieldEnd = 30
k = 0
while k < 8
  if dropTick(k) > 0 and worldTick - dropTick(k) >= 72 and dropTick(k) + 102 > shieldEnd then
    shieldEnd = dropTick(k) + 102
  end if
  k = k + 1
wend

' Drop an unreachable assignment after three seconds without meaningful progress.
if worldTick mod 72 = 0 then
  dxProgress = selfX - progressX
  dyProgress = selfY - progressY
  if dxProgress * dxProgress + dyProgress * dyProgress < 40000 and objective >= 0 and objective < 64 then
    dxHeart = controlX(objective) - selfX
    dyHeart = controlY(objective) - selfY
    if dxHeart * dxHeart + dyHeart * dyHeart > 160000 then
      avoidUntil(objective) = worldTick + 360
    end if
  end if
  progressX = selfX
  progressY = selfY
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
while i < 16
  if i <> selfId and visible(i) then
    dx = playerX(i) - selfX
    dy = playerY(i) - selfY
    d2 = dx * dx + dy * dy
    if i mod 2 <> selfTeam then
      cost = d2 - (3 - playerHp(i)) * 160000
      ' A shielded enemy (the opening, or a fresh sighting beside its own heart during a respawn
      ' window) is the last choice.
      shielded = worldTick < 30
      if shielded = 0 and worldTick < shieldEnd then
        fresh = 1
        if lastSeen(i) = worldTick - 1 then
          fresh = worldTick - sightStart(i) < 30
        end if
        if fresh then
          j = 0
          while j < heartCount() and j < 64
            if controlOwner(j) = 1 - selfTeam then
              qx = controlX(j) - playerX(i)
              qy = controlY(j) - playerY(i)
              if qx * qx + qy * qy < 360000 then
                shielded = 1
              end if
            end if
            j = j + 1
          wend
        end if
      end if
      if shielded then
        cost = cost + 100000000
      end if
      if playerCarrying(i) then
        cost = cost - 2500000
        thief = i
      end if
      if cost < bestCost and d2 <= 27562500 then
        best = i
        bestCost = cost
        bestShielded = shielded
      end if
      foesSeen = foesSeen + 1
      foeSumX = foeSumX + playerX(i)
      foeSumY = foeSumY + playerY(i)
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
  lastFoeX = foeSumX / foesSeen
  lastFoeY = foeSumY / foesSeen
  lastFoeTick = worldTick
end if

' Where we want to be. Later rules override earlier ones; one walkTo is issued at the end.
goalX = selfX
goalY = selfY
holding = 0
if carrying then
  if ownHeartStolen and thief >= 0 then
    goalX = playerX(thief)
    goalY = playerY(thief)
  else
    goalX = homeX
    goalY = homeY
  end if
else
  if thief >= 0 then
    goalX = playerX(thief)
    goalY = playerY(thief)
  else
    goalX = heartX
    goalY = heartY
  end if
end if

' Territory: two squads of four. The target is a pure function of public heart ownership and
' the squad number, so all four members (even one that has just respawned) choose the same
' heart with no communication. Squad 0 works outward from above home, squad 1 from below
' (mirrored for blue, so the two teams play the half turn of each other).
objective = -1
if heartCount() > 0 then
  member = (selfId / 2) mod 8
  squad = member / 4
  seat = member mod 4
  otherTarget = -1
  pass = 0
  while pass < 2
    refY = homeY - 1500
    if pass = 1 then
      refY = homeY + 1500
    end if
    if selfTeam = 1 then
      ' Mirror play: blue's first squad works from below home, the half turn of red's.
      refY = 4000 - refY
    end if
    choice = -1
    choiceCost = 2147483647
    j = 0
    while j < heartCount() and j < 64
      if controlOwner(j) <> selfTeam and j <> otherTarget and waterAt(controlX(j), controlY(j)) = 0 then
        dx = (controlX(j) - homeX) / 8
        dy = (controlY(j) - refY) / 8
        cost = dx * dx + dy * dy
        if controlOwner(j) = -1 then
          cost = cost - 20000
        end if
        if pass = squad and avoidUntil(j) > worldTick then
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
      capturing = controlCaptureTeam(objective) = selfTeam
      if capturing then
        idleCapture = 0
      else
        idleCapture = idleCapture + 1
      end if
      dx = hx - selfX
      dy = hy - selfY
      if dx * dx + dy * dy > 640000 or idleCapture < 96 then
        side = 1
        if seat = 3 then
          side = -1
        end if
        ax = 3200 - hx
        ay = 2000 - hy
        if selfTeam = 0 then
          ax = ax + 1200
        else
          ax = ax - 1200
        end if
        isqrt(ax * ax + ay * ay)
        if root > 0 then
          goalX = hx + (ax * 3 - ay * 2 * side) * 90 / root
          goalY = hy + (ay * 3 + ax * 2 * side) * 90 / root
        end if
      end if
    end if
    dx = goalX - selfX
    dy = goalY - selfY
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
    pickupMemoryTick(i) = worldTick + 1
  end if
  i = i + 1
wend
if not carrying and thief < 0 then
  nearest = -1
  nearestCost = 4840000
  j = 0
  while j < pickupCount() and j < 64
    if pickupMemoryTick(j) > 0 and worldTick - pickupMemoryTick(j) < 240 then
      kind = pickupMemoryKind(j)
      wanted = (kind = 0 and not hasGrenade) or (kind = 2 and selfHp < 3)
      if wanted then
        dx = pickupMemoryX(j) - selfX
        dy = pickupMemoryY(j) - selfY
        cost = dx * dx + dy * dy
        if kind = 2 and selfHp = 1 then
          ' A medkit is worth a whole life to a cog on one hit point.
          cost = cost / 4
        end if
        if cost < 10000 and not pickupVisible(j) then
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
  if nearest >= 0 and (best < 0 or bestCost > 1440000 or selfHp = 1) then
    goalX = pickupMemoryX(nearest)
    goalY = pickupMemoryY(nearest)
    holding = 0
  end if
end if

' Refuse a fight we are visibly losing: head for the heart that is far from them and near us.
if foesNear - friendsNear >= 1 and not carrying then
  cx = foeSumX / foesSeen
  cy = foeSumY / foesSeen
  away = -1
  awayScore = -2147483647
  j = 0
  while j < heartCount() and j < 64
    ' Never fall back to a lake heart: wading is where fleeing cogs die.
    if waterAt(controlX(j), controlY(j)) = 0 then
      ex = (controlX(j) - cx) / 16
      ey = (controlY(j) - cy) / 16
      mx = (controlX(j) - selfX) / 16
      my = (controlY(j) - selfY) / 16
      score = ex * ex + ey * ey - (mx * mx + my * my) / 2
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
  lookX = 6400 - homeX
  lookY = 4000 - homeY
  recentFoe = lastFoeTick > 0 and worldTick - lastFoeTick < 120
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
      lookX = selfX + dxSound
      lookY = selfY + dySound
    end if
  end if
  lookAt(lookX, lookY)
end if

if worldTick mod 360 = selfId * 21 then
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
if best >= 0 and not carrying then
  goalX = selfX
  goalY = selfY
  holding = 1
end if
inContact = best >= 0 and trenchId < 0
if inContact then
  threatX = playerX(best)
  threatY = playerY(best)
  ' Blocked for three ticks: let the engine's pathing take over for a second.
  if legTicks > 0 and (legX <> 0 or legY <> 0) and myVX * myVX + myVY * myVY < 64 then
    stalled = stalled + 1
  else
    stalled = 0
  end if
  if stalled >= 3 then
    pathUntil = worldTick + 24
    stalled = 0
    legTicks = 0
  end if
  ' A line blocked by a teammate last tick means step aside, not plant: planting again only waits.
  wantShot = gunWait = 0 and (hasSpray = 0 or bestCost < 640000) and lineBlocked = 0 and bestShielded = 0
  if worldTick >= pathUntil then
    if legTicks <= 0 or (wantShot and legTicks < 6) or (lineBlocked and legX = 0 and legY = 0) then
      if wantShot then
        ' The zero leg ends with the plant timer, so we move the tick after the ray leaves.
        planLeg(6, 6)
        legX = 0
        legY = 0
      else
        planLeg(3, 6)
      end if
    end if
    legTicks = legTicks - 1
    moveX = selfX + legX * 4
    moveY = selfY + legY * 4
    if holding then
      ' Stay inside the ring: turn back toward its centre when the leg would leave it.
      dx = selfX + legX * 2 - goalX
      dy = selfY + legY * 2 - goalY
      if dx * dx + dy * dy > 9000 then
        moveX = goalX
        moveY = goalY
        legTicks = 0
      end if
    end if
  end if
else
  legTicks = 0
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
drDx = drTx - selfX
drDy = drTy - selfY
if drDx * drDx + drDy * drDy > 640000 then
  if drActive then
    drEx = drTx - drGx
    drEy = drTy - drGy
    if drEx * drEx + drEy * drEy > 1000000 then
      drActive = 0
    end if
    drEx = drWx - selfX
    drEy = drWy - selfY
    if drEx * drEx + drEy * drEy < 90000 then
      drActive = 0
    end if
    if worldTick - drTick > 240 then
      drActive = 0
    end if
  end if
  if drActive = 0 and worldTick - drTick >= 12 then
    drTick = worldTick
    legTime(selfX, selfY, drTx, drTy)
    if wet > 0 then
      drBest = legCost
      drBestK = -1
      drMx = selfX + drDx / 2
      drMy = selfY + drDy / 2
      drK = 0
      while drK < 6
        drCx = drMx - drDy * drF(drK) / 10
        drCy = drMy + drDx * drF(drK) / 10
        if drCx > mapMinX() + 200 and drCx < mapMaxX() - 200 and drCy > mapMinY() + 200 and drCy < mapMaxY() - 200 then
          if waterAt(drCx, drCy) = 0 then
            legTime(selfX, selfY, drCx, drCy)
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
  tx = playerX(best)
  ty = playerY(best)
  ' Lead only a target that kept moving: planted shooters stop, and a lead on a stopped cog misses.
  stepX = tx - oldX(best)
  stepY = ty - oldY(best)
  if lastSeen(best) = worldTick - 1 and moveRun(best) >= 1 and stepX * stepX + stepY * stepY > 64 then
    tx = tx + stepX * 5
    ty = ty + stepY * 5
  end if
  ' Fire only at predictable targets: a step that turned more than 90 degrees since last tick is a
  ' reversal, and neither the lead nor the plain aim knows where that cog goes next. Hold the shot
  ' unless it is within 15 m or the gun has been ready for more than 12 ticks.
  reversed = 0
  prevStep2 = lastStepX(best) * lastStepX(best) + lastStepY(best) * lastStepY(best)
  if lastSeen(best) = worldTick - 1 and stepX * stepX + stepY * stepY > 64 and prevStep2 > 64 then
    if stepX * lastStepX(best) + stepY * lastStepY(best) < 0 then
      rx = playerX(best) - selfX
      ry = playerY(best) - selfY
      if rx * rx + ry * ry >= 2250000 and readyTicks <= 12 then
        reversed = 1
      end if
    end if
  end if
  ' No self-motion correction: the plant timer holds every shot still through the windup, so the ray
  ' leaves from where we stand now and the aim is the target plus its lead.
  ' Hold fire when a visible teammate stands in the line.
  clear = 1
  sx = tx - selfX
  sy = ty - selfY
  isqrt(sx * sx + sy * sy)
  reach = root
  if reach > 0 then
    i = 0
    while i < 16
      if i <> selfId and i mod 2 = selfTeam and visible(i) then
        ox = playerX(i) - selfX
        oy = playerY(i) - selfY
        along = (ox * sx + oy * sy) / reach
        across = (ox * sy - oy * sx) / reach
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
  if hasSpray = 0 or bestCost < 640000 then
    if clear = 0 and gunWait = 0 then
      lineBlocked = 1
    end if
    if clear and gunWait = 0 and bestShielded = 0 and reversed = 0 then
      shootAt(tx, ty)
      ' Plant through the windup: the ray leaves five ticks from now from wherever we stand then.
      plantUntil = worldTick + 6
      gunWait = 25
      if armorHp > 0 or trenchId >= 0 or carrying then
        gunWait = 73
      end if
      if hasSpray then
        gunWait = 25
      end if
    else
      lookAt(tx, ty)
      if reversed and clear and gunWait = 0 and bestShielded = 0 then
        ' A held shot keeps the plant, so the shot that follows starts from standing still.
        plantUntil = worldTick + 1
      end if
    end if
  else
    lookAt(tx, ty)
  end if
end if

i = 0
while i < 16
  if visible(i) then
    stepX = playerX(i) - oldX(i)
    stepY = playerY(i) - oldY(i)
    if lastSeen(i) = worldTick - 1 and stepX * stepX + stepY * stepY > 64 then
      moveRun(i) = moveRun(i) + 1
    else
      moveRun(i) = 0
    end if
    ' Keep this tick's step for the reversal test next tick; a step across a gap in sight is none.
    lastStepX(i) = 0
    lastStepY(i) = 0
    if lastSeen(i) = worldTick - 1 then
      lastStepX(i) = stepX
      lastStepY(i) = stepY
    end if
    oldX(i) = playerX(i)
    oldY(i) = playerY(i)
    if lastSeen(i) <> worldTick - 1 then
      sightStart(i) = worldTick
    end if
    lastSeen(i) = worldTick
  end if
  i = i + 1
wend

' Grenade: match the charge to the distance, never onto a visible teammate.
if hasGrenade and best >= 0 and bestShielded = 0 then
  nx = playerX(best)
  ny = playerY(best)
  dx = nx - selfX
  dy = ny - selfY
  d2 = dx * dx + dy * dy
  safe = 1
  i = 0
  while i < 16
    if i mod 2 = selfTeam and visible(i) then
      fx = playerX(i) - nx
      fy = playerY(i) - ny
      if fx * fx + fy * fy < 202500 then
        safe = 0
      end if
    end if
    i = i + 1
  wend
  if safe and d2 > 160000 and d2 < 1562500 then
    isqrt(d2)
    need = (root - 150) * 24 / 1130 + 1
    if need < 1 then
      need = 1
    end if
    lookAt(nx, ny)
    chargeGrenade(grenadeCharge < need)
    if grenadeCharge >= need then
      shout(strNew("Grenade out!"))
    end if
  end if
end if

' Quiet approach to the objective when nothing is in sight but something was heard.
if best < 0 and soundCount() > 0 and objective >= 0 then
  dx = controlX(objective) - selfX
  dy = controlY(objective) - selfY
  if dx * dx + dy * dy < 810000 then
    sneak(1)
  end if
end if

' The plant wins over every walk chosen above, including a lost target or a dry-route detour.
if worldTick < plantUntil then
  walkTo(selfX, selfY)
end if

lastX = selfX
lastY = selfY
