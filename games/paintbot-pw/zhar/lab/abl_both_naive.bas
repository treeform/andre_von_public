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
    ' A short leg looks 3 m out. legX is still at scale 100 here, so a long leg looks at its own end
    ' (5 or 6 m) and also refuses a side whose midpoint is wet.
    look = 3
    if longLeg = 1 then
      look = legTicks * 28 / 100
    end if
    upA = terrainHeight(selfX + legX * look, selfY + legY * look)
    upB = terrainHeight(selfX - legX * look, selfY - legY * look)
    if waterAt(selfX + legX * look, selfY + legY * look) then
      upA = -9999
    end if
    if waterAt(selfX - legX * look, selfY - legY * look) then
      upB = -9999
    end if
    if longLeg = 1 then
      if waterAt(selfX + legX * look / 2, selfY + legY * look / 2) then
        upA = -9999
      end if
      if waterAt(selfX - legX * look / 2, selfY - legY * look / 2) then
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
      cost = d2
      ' ABLATION shields: no enemy is ever treated as spawn-shielded.
      shielded = 0
      if playerCarrying(i) then
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

' ABLATION squads_hearts + dry_route: no squads and no seat roles. Every cog walks on its own
' to the nearest heart not owned by us, lake hearts included; avoidUntil is kept.
objective = -1
if heartCount() > 0 then
  choiceCost = 2147483647
  j = 0
  while j < heartCount() and j < 64
    if controlOwner(j) <> selfTeam then
      dx = (controlX(j) - selfX) / 8
      dy = (controlY(j) - selfY) / 8
      cost = dx * dx + dy * dy
      if avoidUntil(j) > worldTick then
        cost = cost + 4000000
      end if
      if cost < choiceCost then
        objective = j
        choiceCost = cost
      end if
    end if
    j = j + 1
  wend
  if objective >= 0 then
    goalX = controlX(objective)
    goalY = controlY(objective)
    dx = goalX - selfX
    dy = goalY - selfY
    if dx * dx + dy * dy < 8100 then
      holding = 1
    end if
  end if
end if

' ABLATION pickups: supplies are never remembered or fetched.

' ABLATION retreat: never fall back from a fight we are losing.

' ABLATION facing: no idle facing; with no aim order the engine faces the walk goal.

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
' ABLATION hold: in contact we keep walking to the objective; the dodge legs carry us there.
inContact = best >= 0 and trenchId < 0
if inContact then
  threatX = playerX(best)
  threatY = playerY(best)
  contactTick = worldTick
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
    ' Against the neural bot (neuralFoe, set at the end of the tick) a ready shot plants at once from
    ' a zero leg and leaves zig alone, and every other leg is a 19 to 22 tick one that reverses the
    ' last. That bot aims at where we stand, so one 5 m sideways leg per gun cycle (the gun is ready
    ' 19 ticks after the plant), turning around only inside our own plant, leaves every windup
    ' outside the plant aimed at an empty spot.
    if legTicks <= 0 or (wantShot and (legTicks < 6 or neuralFoe)) or (lineBlocked and legX = 0 and legY = 0) then
      if wantShot then
        ' ABLATION plant: the shot starts an ordinary moving leg that outlasts the windup (base.bas).
        if neuralFoe then
          longLeg = 1
          planLeg(19, 22)
          longLeg = 0
        else
          planLeg(6, 9)
        end if
      else
        if neuralFoe then
          longLeg = 1
          planLeg(19, 22)
          longLeg = 0
        else
          planLeg(3, 6)
        end if
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
  ' Against the neural bot, sight flickers for a tick or two at a time: finish the long leg through
  ' a gap of up to 12 ticks instead of planning a fresh, reversed one on the next contact.
  if neuralFoe and legTicks > 0 and worldTick - contactTick <= 12 then
    legTicks = legTicks - 1
    moveX = selfX + legX * 4
    moveY = selfY + legY * 4
  else
    legTicks = 0
  end if
  stalled = 0
end if
' ABLATION dry_route: no lake detour, walk straight at the move target.
walkTo(moveX, moveY)

' Gun: the ray leaves six moves after the order, from wherever we then stand, along the
' direction locked one move from now. Aim where they will be, minus our own drift.
lineBlocked = 0
if best >= 0 then
  tx = playerX(best)
  ty = playerY(best)
  ' ABLATION lead: aim at the target's current position.
  ' ABLATION plant: we keep moving through the windup, so cancel our own motion as base.bas does.
  if inContact and worldTick >= pathUntil then
    tx = tx - legX * 5
    ty = ty - legY * 5
  else
    tx = tx - myVX * 5
    ty = ty - myVY * 5
  end if
  ' ABLATION teamline: never hold fire for a teammate in the line.
  clear = 1
  if hasSpray = 0 or bestCost < 640000 then
    if clear = 0 and gunWait = 0 then
      lineBlocked = 1
    end if
    if clear and gunWait = 0 and bestShielded = 0 then
      shootAt(tx, ty)
      gunWait = 25
      if armorHp > 0 or trenchId >= 0 or carrying then
        gunWait = 73
      end if
      if hasSpray then
        gunWait = 25
      end if
    else
      lookAt(tx, ty)
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
    ' Neural fingerprint: the reference decoder walks 2 m compass steps, and the engine moves a cog
    ' 28 units toward such a goal, which is exactly (28, 0), (0, 28) or (19, 19) in size. BASIC bots
    ' walk at any angle. Count an enemy's moving steps seen on consecutive ticks and the exact ones.
    if i mod 2 <> selfTeam and lastSeen(i) = worldTick - 1 then
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
    if lastSeen(i) = worldTick - 1 and stepX * stepX + stepY * stepY > 64 then
      moveRun(i) = moveRun(i) + 1
    else
      moveRun(i) = 0
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
' ABLATION longlegs: the long-leg footwork is off for every opponent (v46 footwork).
neuralFoe = 0

' ABLATION grenades: never charge or throw a grenade.

' Quiet approach to the objective when nothing is in sight but something was heard.
if best < 0 and soundCount() > 0 and objective >= 0 then
  dx = controlX(objective) - selfX
  dy = controlY(objective) - selfY
  if dx * dx + dy * dy < 810000 then
    sneak(1)
  end if
end if

lastX = selfX
lastY = selfY
