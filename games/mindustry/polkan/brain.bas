' Polkan: a Mindustry economy that converts sand and coal into silicon,
' silicon and lead into Daggers, and Daggers into a dead enemy core.
' tools/mplan.nim plans the industry for each built-in map from its terrain
' (the API cannot see floors) and writes the orders where BLUEPRINT stands.
' Member 0 builds the blueprint: a silicon smelter against the core, a
' conveyor trunk out to a field of sand drills, combustion generators that
' touch what they power, and a ground factory. It hand-feeds coal to the
' smelter and generators and silicon and lead to the factory. Members 1-3
' mine copper, lead and coal into the core by hand; member 3 also sends
' the Daggers at the enemy core.
dim orderKind(159)
dim orderX(159)
dim orderY(159)
dim orderRotation(159)
dim orderAsked(159)
dim orderTries(159)
dim oreX(3)
dim oreY(3)
dim oreBest(3)
dim scanX(3)
dim scanY(3)
dim scanBest(3)
dim flankX(2)
dim flankY(2)
dim turretX(15)
dim turretY(15)
dim kin(3)

' The survival variant has no enemy core.
if enemyCoreX() < 0 then end

if ready = 0 then
  ready = 1
  cx = coreX()
  cy = coreY()
  ex = enemyCoreX()
  ey = enemyCoreY()
  me = member()
  width = mapWidth()
  height = mapHeight()
  copper = itemId("copper")
  lead = itemId("lead")
  coal = itemId("coal")
  sand = itemId("sand")
  silicon = itemId("silicon")
  dagger = unitTypeId("dagger")
  ' Kinds in the blueprint: 0 conveyor, 1 drill, 2 smelter, 3 generator,
  ' 4 ground factory, 5 guard Scatter, 6 guard Duo.
  conveyor = blockId("conveyor")
  drill = blockId("mechanical-drill")
  smelter = blockId("silicon-smelter")
  generator = blockId("combustion-generator")
  factory = blockId("ground-factory")
  scatter = blockId("scatter")
  duo = blockId("duo")
  hail = blockId("hail")
  orderCount = 0
  flankCount = 0
' BLUEPRINT
  ' Each order arrives packed in orderKind (see tools/mplan.nim):
  ' ((kind * 4 + rotation) * 512 + x offset + 256) * 512 + y offset + 256.
  for k = 0 to orderCount - 1
    v = orderKind(k)
    orderY(k) = cy + v - (v \ 512) * 512 - 256
    v = v \ 512
    orderX(k) = cx + v - (v \ 512) * 512 - 256
    v = v \ 512
    orderRotation(k) = v - (v \ 4) * 4
    orderKind(k) = v \ 4
  next k
  for k = 1 to 3
    oreBest(k) = 100000
    scanBest(k) = 100000
  next k
  scanRow = 0
  scanRadius = 80
  waveSize = 20
  role = me
end if

' Keep finding the nearest open copper, lead and coal ore within 80 tiles,
' eight rows a decision, so miners leave tiles our buildings cover. Ores
' vary by seed: some Glacier seeds put the nearest lead 80-105 tiles out,
' so a pass that misses an ore widens the next ones to 125 tiles. Players
' drop mined items into a core within 27.5 tiles; farther ore is carried
' home by hand.
for row = 0 to 7
  y = cy - scanRadius + scanRow
  for x = cx - scanRadius to cx + scanRadius
    k = oreAt(x, y)
    if k > 0 then
      if blockAt(x, y) = -1 then
        dx = x - cx
        dy = y - cy
        d2 = dx * dx + dy * dy
        if d2 < scanBest(k) and d2 <= scanRadius * scanRadius then
          scanBest(k) = d2
          scanX(k) = x
          scanY(k) = y
        end if
      end if
    end if
  next x
  scanRow = scanRow + 1
  if scanRow > 2 * scanRadius then
    scanRow = 0
    for k = 1 to 3
      oreBest(k) = scanBest(k)
      oreX(k) = scanX(k)
      oreY(k) = scanY(k)
      scanBest(k) = 100000
    next k
    for k = 1 to 3
      if oreBest(k) >= 100000 then scanRadius = 125
    next k
  end if
next row

if flyerHealth() <= 0 then end
fx = flyerX()
fy = flyerY()

' Kin: league rounds deal six entrants into eight seats, so a team mixes
' Polkan seats with strangers. For half a second every Polkan seat drifts
' to its signature tile, three east of its spawn (core y - 3 + 2 * member),
' and counts the teammates seen on theirs at ticks 24 and 30. Four
' Polkans keep the member roles; a mixed team gets a Duo guardian (the
' lowest Polkan) and miners, and never spends the shared core on industry.
if tick() <= 30 then
  buildEnable(0)
  move((cx + 3 - fx) / 6, (cy - 3 + 2 * me - fy) / 6)
  if tick() >= 24 then
    mySeat = -1
    for i = 0 to unitCount() - 1
      if unit(i, 0) = controlled() then mySeat = unit(i, 13)
    next i
    base = mySeat - me
    for i = 0 to unitCount() - 1
      if unit(i, 6) = team() and unit(i, 13) >= 0 then
        m = unit(i, 13) - base
        if m >= 0 and m <= 3 and m <> me then
          dx = unit(i, 2) - (cx + 3)
          dy = unit(i, 3) - (cy - 3 + 2 * m)
          seen = 0
          if dx > -1.5 and dx < 1.5 and dy > -1.5 and dy < 1.5 then seen = 1
          if tick() < 30 then
            kin(m) = seen
          else
            kin(m) = kin(m) * seen
          end if
        end if
      end if
    next i
  end if
  if tick() < 30 then end
  kinCount = 1
  rank = 0
  for m = 0 to 3
    if m <> me and kin(m) = 1 then
      kinCount = kinCount + 1
      if m < me then rank = rank + 1
    end if
  next m
  role = me
  if kinCount < 4 then role = 10 + rank
  ' A second Polkan on a mixed team runs our industry while the first
  ' guards: one seat doing both lost its core four times sooner.
  if kinCount < 4 and rank = 1 then role = 20
end if

' An alpha or gamma with live build plans cannot mine: pause building while
' the core is out of copper so a stalled plan never stops all income.
if stock(copper) < 12 then paused = 1
if stock(copper) >= 40 then paused = 0
if paused = 1 then
  buildEnable(0)
else
  buildEnable(1)
end if

' Pick what to mine by member preference and stock targets. A new choice
' holds for 300 ticks: when a stock hovers at a threshold, flipping between
' ores on opposite sides of the core every decision mines nothing.
want = 1
if role = 1 then
  want = 3
  if stock(coal) >= 300 then want = 1
  if stock(copper) < 150 then want = 1
end if
if role = 2 then
  want = 2
  if stock(lead) >= 400 then want = 1
  if stock(copper) < 150 then want = 1
end if
if role = 3 then
  want = 1
  if stock(copper) >= 600 then want = 2
  ' Two smelters and their generators outrun one coal miner.
  if stock(copper) >= 300 and stock(coal) < 100 then want = 3
end if
if role >= 10 then
  ' Mixed-team seats bank whatever the shared core holds least of, against
  ' goals of 300 copper, 200 lead and 100 coal. The guardian only counts
  ' ore within 19 tiles, where it can still feed every Duo.
  want = 1
  short = stock(copper) / 300
  if stock(lead) / 200 < short and (role >= 11 or oreBest(2) <= 361) then
    want = 2
    short = stock(lead) / 200
  end if
  if stock(coal) / 100 < short and (role >= 11 or oreBest(3) <= 361) then want = 3
end if
if lastWant > 0 and tick() < wantUntil then want = lastWant
if want <> lastWant then wantUntil = tick() + 300
lastWant = want
if oreBest(want) >= 100000 then want = 1
targetX = cx
targetY = cy
if oreBest(want) < 100000 then
  if oreBest(want) <= 756 or role = 0 or role = 10 then
    targetX = oreX(want)
    targetY = oreY(want)
    mine(oreX(want), oreY(want))
  else
    ' Far ore: fill our own hold, then fly home and hand it to the core.
    wantItem = copper
    if want = 2 then wantItem = lead
    if want = 3 then wantItem = coal
    if carried() = 0 then hauling = 0
    if carried() >= 60 then hauling = 1
    if carried() > 0 and carriedItem() <> wantItem then hauling = 1
    if hauling = 1 then
      dx = fx - cx
      dy = fy - cy
      if dx * dx + dy * dy <= 500 then deposit(cx, cy)
    else
      targetX = oreX(want)
      targetY = oreY(want)
      mine(oreX(want), oreY(want))
    end if
  end if
end if

' Member 3 keeps far Scatters (the route chain) loaded with lead; it beats
' building, mining and hauling while one runs low.
supplying = 0
if role = 3 then
  supply = -1
  for i = 0 to buildingCount() - 1
    if supply < 0 and building(i, 5) = team() and building(i, 9) >= 1 then
      sx = building(i, 2)
      sy = building(i, 3)
      if contentAt(sx, sy) = scatter and building(i, 11) < 12 then
        dx = sx - cx
        dy = sy - cy
        if dx * dx + dy * dy > 484 then supply = i
      end if
    end if
  next i
  if supply >= 0 and stock(lead) >= 40 then
    supplying = 1
    sx = building(supply, 2)
    sy = building(supply, 3)
    if carried() > 0 and carriedItem() <> lead then
      targetX = cx
      targetY = cy
      deposit(cx, cy)
    else
      if carried() = 0 then
        targetX = cx
        targetY = cy
        if homeDistance <= 500 then take(cx, cy, lead, 60)
      else
        targetX = sx
        targetY = sy
        deposit(sx, sy)
      end if
    end if
  end if
end if

' Member 0 builds every order within 22 tiles of the core and stays home
' for the hand logistics; member 3 flies out to build the rest.
builder = 0
if role = 0 or role = 10 then builder = 1
if role = 3 then builder = 2
if role = 20 then builder = 3
if builder > 0 then
  queued = 0
  far = -1
  for k = 0 to orderCount - 1
    kind = orderKind(k)
    dx = orderX(k) - cx
    dy = orderY(k) - cy
    mine2 = 1
    if dx * dx + dy * dy > 484 then mine2 = 2
    ' A skipped order gets another round of tries after 30 seconds; sites
    ' started while the core ran dry would otherwise stay unfinished.
    if orderTries(k) >= 6 and tick() - orderAsked(k) >= 1800 then orderTries(k) = 0
    if (mine2 <> builder and builder <> 3) or orderTries(k) >= 6 then kind = -1
    ' The mixed-team guardian builds only the Duo ring.
    if role = 10 and kind <> 6 then kind = -1
    id = conveyor
    if kind = 1 then id = drill
    if kind = 2 then id = smelter
    if kind = 3 then id = generator
    if kind = 4 then id = factory
    if kind = 5 then id = scatter
    if kind = 6 then id = duo
    x = orderX(k)
    y = orderY(k)
    skip = 0
    if kind < 0 then skip = 1
    if kind = 1 then
      ' A drill on copper, lead or coal would jam the sand trunk.
      if oreAt(x, y) + oreAt(x + 1, y) + oreAt(x, y + 1) + oreAt(x + 1, y + 1) > 0 then skip = 1
    end if
    if skip = 0 and contentAt(x, y) <> id then
      affordable = 1
      if kind = 1 and stock(copper) < 20 then affordable = 0
      if kind = 2 and (stock(copper) < 40 or stock(lead) < 30) then affordable = 0
      if kind = 3 and (stock(copper) < 35 or stock(lead) < 20) then affordable = 0
      if kind = 4 and (stock(copper) < 60 or stock(lead) < 130 or stock(silicon) < 80) then affordable = 0
      if kind = 5 and (stock(copper) < 120 or stock(lead) < 80) then affordable = 0
      if kind = 6 and stock(copper) < 60 then affordable = 0
      if affordable = 1 and queued < 4 then
        if orderAsked(k) = 0 or tick() - orderAsked(k) >= 120 then
          if buildBlock(id, x, y, orderRotation(k)) = 1 then
            orderAsked(k) = tick()
            ' Count a try only when we stand in build range of it.
            dx = x - fx
            dy = y - fy
            if dx * dx + dy * dy <= 600 then orderTries(k) = orderTries(k) + 1
            queued = queued + 1
          end if
        end if
      end if
      if far < 0 and affordable = 1 then far = k
    end if
  next k
  ' The outer builder flies to the first affordable unbuilt far order.
  buildTrip = 0
  if builder >= 2 and far >= 0 and supplying = 0 then
    buildTrip = 1
    targetX = orderX(far)
    targetY = orderY(far)
  end if
  ' contentAt reports a started site as its finished block, so the order
  ' loop skips it; resume our first unfinished site and fly to it.
  site = -1
  for i = 0 to buildingCount() - 1
    if site < 0 and building(i, 5) = team() and building(i, 9) < 1 then
      dx = building(i, 2) - cx
      dy = building(i, 3) - cy
      mine2 = 2
      if dx > -23 and dx < 23 and dy > -23 and dy < 23 then
        if dx * dx + dy * dy <= 484 then mine2 = 1
      end if
      if mine2 = builder or builder = 3 then site = i
    end if
  next i
  if site >= 0 then
    sx = building(site, 2)
    sy = building(site, 3)
    if tick() - siteAsked >= 120 then
      buildBlock(contentAt(sx, sy), sx, sy, building(site, 7))
      siteAsked = tick()
    end if
    ' A site with nothing to build from would hold member 3 off mining.
    if builder >= 2 and supplying = 0 and stock(copper) >= 100 and stock(lead) >= 50 then
      buildTrip = 1
      targetX = sx
      targetY = sy
    end if
  end if
end if

if role = 0 or role = 10 or role = 20 then
  ' Stay near the core: hover on it while inner orders remain, and only
  ' mine ore within 12 tiles of it. The guardian's only job at home is the
  ' Duo ring 4-8 tiles out, and transfers reach 27.5 tiles, so it mines
  ' anything within 19 tiles: a mixed team's core is usually broke.
  reach = 144
  if role = 10 then reach = 361
  if (oreBest(want) > reach or (far >= 0 and role = 0)) and buildTrip = 0 then
    targetX = cx
    targetY = cy
  end if
  ' Hand logistics: empty our hands into the core first, then feed.
  if carried() > 0 then deposit(cx, cy)
  if carried() = 0 then
    fed = 0
    for i = 0 to buildingCount() - 1
      if building(i, 5) = team() and building(i, 9) >= 1 then
        bx = building(i, 2)
        bxy = building(i, 3)
        b = contentAt(bx, bxy)
        ' The mixed-team guardian feeds only the Duos; the industry is not ours.
        if role = 10 and b <> duo then b = -1
        if b = smelter or b = generator then
          have = buildingItem(i, coal)
          if have < 6 and stock(coal) >= 10 then
            take(cx, cy, coal, 10 - have)
            deposit(bx, bxy)
          end if
        end if
        if b = scatter then
          ' Guard Scatters burn lead, which piles up in the thousands. Route
          ' Scatters are member 3's: a deposit out of reach leaves the lead
          ' in hand and every later take fails.
          near = 0
          dx = bx - cx
          dy = bxy - cy
          if dx > -23 and dx < 23 and dy > -23 and dy < 23 then
            if dx * dx + dy * dy <= 484 then near = 1
          end if
          if near = 1 and building(i, 11) < 12 and stock(lead) >= 60 then
            take(cx, cy, lead, 6)
            deposit(bx, bxy)
          end if
        end if
        if b = duo then
          ' Copper is Duo ammo and piles up too; four refills per decision
          ' keep a fresh ring under the 32-command limit.
          if building(i, 11) < 10 and stock(copper) >= 60 and fed < 4 then
            take(cx, cy, copper, 6)
            deposit(bx, bxy)
            fed = fed + 1
          end if
        end if
        if b = factory then
          have = buildingItem(i, silicon)
          if have < 10 and stock(silicon) >= 20 then
            take(cx, cy, silicon, 20 - have)
            deposit(bx, bxy)
          end if
          have = buildingItem(i, lead)
          if have < 10 and stock(lead) >= 20 then
            take(cx, cy, lead, 20 - have)
            deposit(bx, bxy)
          end if
          if tick() mod 300 = 0 then
            configure(bx, bxy, 0, 0)
            ' Gather near the factory until the first wave, then send every
            ' new Dagger straight at the enemy core (unit ids above 32767
            ' cannot be commanded through the BASIC host).
            rallyX = bx + (ex - bx) / 20
            rallyY = bxy + (ey - bxy) / 20
            commandBuilding(bx, bxy, rallyX, rallyY)
          end if
        end if
      end if
    next i
  end if
end if

' Waves: Daggers gather at home and go 20 at a time (the cap is 24). The
' gathered army guards home while a rival trickles tens into our Duos, and
' a trickle of our own dies to enemy Gammas one Dagger at a time.
if (role = 3 or role = 20) and tick() mod 60 = 0 then
  waiting = 0
  for i = 0 to unitCount() - 1
    if unit(i, 6) = team() and unit(i, 11) = dagger and unit(i, 13) = -1 then
      dx = unit(i, 2) - cx
      dy = unit(i, 3) - cy
      if dx > -31 and dx < 31 and dy > -31 and dy < 31 then
        if dx * dx + dy * dy <= 900 then waiting = waiting + 1
      end if
    end if
  next i
  ' A home army that has not grown for a minute (silicon short, Gammas
  ' picking it off) goes anyway once it holds twelve: waiting for twenty
  ' would never attack.
  if waiting > peakWaiting then
    peakWaiting = waiting
    peakTick = tick()
  end if
  stalled = 0
  if waiting >= 12 and tick() - peakTick >= 3600 then stalled = 1
  if waiting >= waveSize or stalled = 1 then
    peakWaiting = 0
    peakTick = tick()
    issued = 0
    for i = 0 to unitCount() - 1
      if issued < 30 and unit(i, 6) = team() and unit(i, 11) = dagger and unit(i, 13) = -1 then
        dx = unit(i, 2) - cx
        dy = unit(i, 3) - cy
        near = 0
        if dx > -31 and dx < 31 and dy > -31 and dy < 31 then
          if dx * dx + dy * dy <= 900 then near = 1
        end if
        if near = 1 then
          if flankCount > 0 then
            commandMove(unit(i, 0), flankX(0), flankY(0), 0)
          else
            commandAttackBuilding(unit(i, 0), ex, ey, 0)
          end if
          issued = issued + 1
        end if
      end if
    next i
  end if
end if

' Flank: on Glacier the centre corridor runs under the enemy Gammas' flight
' line, so a wave walks the planner's flank waypoints with move orders and
' attacks the core from the last one. Daggers within seven tiles of a
' waypoint move on to the next.
if (role = 3 or role = 20) and flankCount > 0 and tick() mod 60 = 12 then
  issued = 0
  for i = 0 to unitCount() - 1
    if issued < 20 and unit(i, 6) = team() and unit(i, 11) = dagger and unit(i, 13) = -1 then
      ux = unit(i, 2)
      uy = unit(i, 3)
      for k = 0 to flankCount - 1
        dx = ux - flankX(k)
        dy = uy - flankY(k)
        if dx > -7 and dx < 7 and dy > -7 and dy < 7 then
          if k + 1 < flankCount then
            commandMove(unit(i, 0), flankX(k + 1), flankY(k + 1), 0)
          else
            commandAttackBuilding(unit(i, 0), ex, ey, 0)
          end if
          issued = issued + 1
        end if
      next k
    end if
  next i
end if

' Siege: a Duo ring shreds a wave that shoots the core first, and Daggers
' outrange Duos, so Daggers near the enemy core take the nearest turret
' within 20 tiles first and the core once none is left. A separate tick
' from the launch keeps both under the 32-command limit.
if (role = 3 or role = 20) and tick() mod 60 = 30 then
  turrets = 0
  for i = 0 to buildingCount() - 1
    if turrets < 16 and building(i, 5) <> team() and building(i, 5) > 0 and building(i, 9) >= 1 then
      bx = building(i, 2)
      bxy = building(i, 3)
      dx = bx - ex
      dy = bxy - ey
      if dx > -21 and dx < 21 and dy > -21 and dy < 21 then
        b = contentAt(bx, bxy)
        if b = duo or b = hail then
          turretX(turrets) = bx
          turretY(turrets) = bxy
          turrets = turrets + 1
        end if
      end if
    end if
  next i
  issued = 0
  for i = 0 to unitCount() - 1
    if issued < 20 and unit(i, 6) = team() and unit(i, 11) = dagger and unit(i, 13) = -1 then
      ux = unit(i, 2)
      uy = unit(i, 3)
      dx = ux - ex
      dy = uy - ey
      if dx > -36 and dx < 36 and dy > -36 and dy < 36 then
        tx = ex
        ty = ey
        best = 400
        for k = 0 to turrets - 1
          dx = turretX(k) - ux
          dy = turretY(k) - uy
          if dx > -21 and dx < 21 and dy > -21 and dy < 21 then
            if dx * dx + dy * dy < best then
              best = dx * dx + dy * dy
              tx = turretX(k)
              ty = turretY(k)
            end if
          end if
        next k
        commandAttackBuilding(unit(i, 0), tx, ty, 0)
        issued = issued + 1
      end if
    end if
  next i
end if

' Escort: while five or more Daggers march, members 2 and 3 fly over the
' column and shoot. Daggers cannot hit kiting Gammas; Gammas with aim-lead can.
marching = 0
marchX = 0
marchY = 0
for i = 0 to unitCount() - 1
  if unit(i, 6) = team() and unit(i, 11) = dagger then
    dx = unit(i, 2) - cx
    dy = unit(i, 3) - cy
    out = 1
    if dx > -31 and dx < 31 and dy > -31 and dy < 31 then
      if dx * dx + dy * dy <= 900 then out = 0
    end if
    if out = 1 then
      marching = marching + 1
      marchX = marchX + unit(i, 2)
      marchY = marchY + unit(i, 3)
    end if
  end if
next i
' Only a rich core spares its copper and lead miners; the coal miner stays.
escorting = 0
rich = 0
if stock(copper) >= 500 and stock(lead) >= 200 then rich = 1
if rich = 1 and role >= 2 and role <= 3 and marching >= 5 and supplying = 0 then
  escorting = 1
  targetX = marchX / marching
  targetY = marchY / marching
end if

' Steer with a short brake near the target.
dx = targetX - fx
dy = targetY - fy
d2 = 100
if dx > -50 and dx < 50 and dy > -50 and dy < 50 then d2 = dx * dx + dy * dy
if d2 > 4 then
  move(dx, dy)
else
  move(dx / 4, dy / 4)
end if

' Shoot the closest enemy unit in weapon range (wider while escorting).
' Gamma bolts fly 3.5 units a tick, as fast as a Gamma, so aim where the
' target will be: its velocity (tiles a tick) times the flight time, which
' is the distance (three Newton steps from 10) times 8 / 3.5 ticks.
best = 300
if escorting = 1 then best = 400
target = -1
for i = 0 to unitCount() - 1
  if unit(i, 6) <> team() and unit(i, 5) > 0 then
    dx = unit(i, 2) - fx
    dy = unit(i, 3) - fy
    d2 = 100000
    if dx > -25 and dx < 25 and dy > -25 and dy < 25 then d2 = dx * dx + dy * dy
    if d2 < best then
      best = d2
      target = i
    end if
  end if
next i
if target >= 0 then
  g = 10
  g = (g + best / g) / 2
  g = (g + best / g) / 2
  g = (g + best / g) / 2
  flight = g * 2.2857
  aim(unit(target, 2) + unit(target, 9) * flight, unit(target, 3) + unit(target, 10) * flight)
  shoot(1)
end if
