' Routes copper to the core, builds defenses, and explicitly controls the flyer.
' The two grid arrays and blueprint stay below the 4096-cell policy limit.
dim routes(1088)
dim frontier(1088)
dim sitesX(3)
dim sitesY(3)
dim ordersX(219)
dim ordersY(219)
dim ordersType(219)
dim ordersRotation(219)
sub measure(a, b)
  measureX = a
  measureY = b
  if measureX < 0 then measureX = -measureX
  if measureY < 0 then measureY = -measureY
  measureSize = measureX + measureY
end sub

' The default policy uses squad roles when an opposing core is present.
if enemyCoreX() >= 0 then
  ' One engineer advances turrets, one produces units, and two lead the attack.
  if tick() = 0 then
    cx = coreX()
    cy = coreY()
    ex = enemyCoreX()
    ey = enemyCoreY()
    side = 1
    if team() = 2 then side = -1
    role = member()
    copper = itemId("copper")
    lead = itemId("lead")
    silicon = itemId("silicon")
    dagger = unitTypeId("dagger")
    flare = unitTypeId("flare")
    factory = blockId("ground-factory")
    airFactory = blockId("air-factory")
    solar = blockId("solar-panel-large")
    panel = blockId("solar-panel")
    node = blockId("power-node")
    factoryX = cx + side * 3
    factoryY = cy + 7
    airY = cy - 7
    drill = blockId("mechanical-drill")
    belt = blockId("conveyor")
    turret = blockId("duo")
    wall = blockId("copper-wall")
    direction = 0
    if side = -1 then direction = 2
    lane = -4
    vertical = 1
    if role = 1 then
      lane = 4
      vertical = 3
    end if
    dx = cx - side * 3
    if side = -1 then dx = dx - 1
    by = cy + lane
    tx = cx + side * 5
    ty = cy + lane
    frontX = cx + side * 13
    frontY = cy - 3
    frontReady = -1
  end if
  fx = flyerX()
  fy = flyerY()
  if flyerHealth() <= 0 then end
  if role < 2 then
    ' Keep both conveyor lanes and the initial pair of defensive turrets.
    if tick() mod 120 = 0 and planCount() < 6 then
      if contentAt(dx, by) <> drill then buildBlock(drill, dx, by, 0)
      if contentAt(cx - side, by) <> belt then buildBlock(belt, cx - side, by, direction)
      if contentAt(cx, by) <> belt then buildBlock(belt, cx, by, vertical)
      for offset = 2 to 3
        y = cy - offset
        if lane > 0 then y = cy + offset
        if contentAt(cx, y) <> belt then buildBlock(belt, cx, y, vertical)
      next offset
      if contentAt(tx, ty) <> turret then buildBlock(turret, tx, ty, 0)
      if contentAt(tx + side * 2, ty) <> wall then buildBlock(wall, tx + side * 2, ty, 0)
    end if
    targetX = cx + side * 2
    targetY = cy + lane
    if role = 1 then
      ' A shared solar grid powers ground and air production without free resources.
      if tick() mod 120 = 0 and planCount() < 6 then
        if contentAt(factoryX, factoryY) <> factory then buildBlock(factory, factoryX, factoryY, direction)
        if contentAt(cx - side, factoryY) <> solar then buildBlock(solar, cx - side, factoryY, 0)
        for relay = 0 to 3
          offset = -7
          if relay = 1 then offset = -3
          if relay = 2 then offset = 3
          if relay = 3 then offset = 7
          if contentAt(cx + side, cy + offset) <> node then buildBlock(node, cx + side, cy + offset, 0)
        next relay
        if contentAt(factoryX, airY) <> airFactory then buildBlock(airFactory, factoryX, airY, direction)
        for offset = -3 to -1
          if contentAt(cx + side * offset, cy + 3) <> panel then buildBlock(panel, cx + side * offset, cy + 3, 0)
          if contentAt(cx + side * offset, airY) <> panel then buildBlock(panel, cx + side * offset, airY, 0)
        next offset
        if contentAt(cx + side * 2, cy + 3) <> panel then buildBlock(panel, cx + side * 2, cy + 3, 0)
        configure(factoryX, factoryY, 0, 0)
        configure(factoryX, airY, 0, 0)
        commandBuilding(factoryX, factoryY, ex, ey)
        commandBuilding(factoryX, airY, ex, ey)
      end if
      groundIndex = -1
      airIndex = -1
      baseAmmo = 0
      for i = 0 to buildingCount() - 1
        if building(i, 9) = 1 and building(i, 5) = team() then
          if building(i, 2) = factoryX and building(i, 3) = factoryY then groundIndex = i
          if building(i, 2) = factoryX and building(i, 3) = airY then airIndex = i
          if building(i, 2) = tx and building(i, 3) = ty then baseAmmo = building(i, 11)
        end if
      next i
      supply = -1
      if groundIndex >= 0 then
        if buildingItem(groundIndex, lead) < 20 then supply = lead
        if buildingItem(groundIndex, silicon) < 20 then supply = silicon
        supplyY = factoryY
      end if
      if airIndex >= 0 then
        if buildingItem(airIndex, silicon) < 15 then
          supply = silicon
          supplyY = airY
        end if
      end if
      ' Retain each delivery destination until the carried stack is deposited.
      if carried() > 0 then
        if carriedItem() = copper then
          if baseAmmo < 15 then
            deposit(tx, ty)
          else
            deposit(cx, cy)
          end if
        else
          stopMine()
          deposit(factoryX, deliveryY)
        end if
      else
        if supply >= 0 and stock(supply) > 0 then
          stopMine()
          deliveryY = supplyY
          take(cx, cy, supply, 20)
        else
          take(cx, cy, copper, 20)
          deposit(tx, ty)
          mine(dx - 1, by)
        end if
      end if
    else
      ' Advance only after the latest outpost is constructed and armed.
      frontAmmo = 0
      frontBuilt = 0
      for i = 0 to buildingCount() - 1
        if building(i, 2) = frontX and building(i, 3) = frontY and building(i, 5) = team() then
          if contentAt(frontX, frontY) = turret and building(i, 9) = 1 then
            frontBuilt = 1
            frontAmmo = building(i, 11)
          end if
        end if
      next i
      if frontBuilt = 1 and frontAmmo >= 15 then
        if frontReady < 0 then frontReady = tick()
        if tick() - frontReady >= 180 and (ex - frontX) * side > 18 then
          frontX = frontX + side * 8
          frontReady = -1
        end if
      else
        frontReady = -1
      end if
      if tick() >= 1200 and tick() mod 60 = 0 and planCount() < 3 and stock(copper) >= 45 then
        if contentAt(frontX, frontY) <> turret then buildBlock(turret, frontX, frontY, 0)
        if contentAt(frontX + side * 2, frontY) <> wall then buildBlock(wall, frontX + side * 2, frontY, 0)
      end if
      refill = -1
      best = -1
      for i = 0 to buildingCount() - 1
        if building(i, 5) = team() and building(i, 9) = 1 then
          if contentAt(building(i, 2), building(i, 3)) = turret and building(i, 11) < 15 then
            advance = (building(i, 2) - cx) * side
            if advance > best then
              best = advance
              refill = i
            end if
          end if
        end if
      next i
      if carried() > 0 then
        if refill >= 0 then
          targetX = building(refill, 2)
          targetY = building(refill, 3)
          deposit(targetX, targetY)
        else
          deposit(cx, cy)
        end if
      else
        if refill >= 0 then
          targetX = cx
          targetY = cy
          take(cx, cy, copper, 30)
        else
          mine(dx - 1, by)
        end if
      end if
      if planCount() > 0 and (carried() > 0 or refill < 0) then
        targetX = plan(0, 0)
        targetY = plan(0, 1)
      end if
    end if
    distance = (targetX - fx) * (targetX - fx) + (targetY - fy) * (targetY - fy)
    if distance > 36 then move(targetX - fx, targetY - fy)
  else
    ' Each raider claims its own kind of combat unit through player possession.
    preferred = dagger
    if role = 3 then preferred = flare
    bodyType = -1
    for i = 0 to unitCount() - 1
      if unit(i, 0) = controlled() then bodyType = unit(i, 11)
    next i
    claimedUnit = -1
    if bodyType <> preferred and (role = 2 or tick() >= nextSortie) then
      claimed = 0
      for i = 0 to unitCount() - 1
        if unit(i, 6) = team() and unit(i, 11) = preferred and unit(i, 13) = -1 and claimed = 0 then
          controlUnit(unit(i, 0))
          claimed = 1
          claimedUnit = unit(i, 0)
          nextSortie = tick() + 1800
        end if
      next i
    end if
    if role = 3 and tick() mod 120 = 0 then
      ' Human RTS attack orders send unclaimed production into the same assault.
      ' Regroup between fighter sorties so replacements can form an AI wing.
      issued = 0
      for i = 0 to unitCount() - 1
        if unit(i, 6) = team() and unit(i, 13) = -1 and unit(i, 0) <> claimedUnit and issued < 16 then
          if unit(i, 11) = dagger or unit(i, 11) = flare then
            commandAttackBuilding(unit(i, 0), ex, ey, 0)
            issued = issued + 1
          end if
        end if
      next i
    end if
    if bodyType = preferred then
      targetX = ex
      targetY = ey
      best = 256
      for i = 0 to buildingCount() - 1
        if building(i, 5) <> team() and building(i, 6) > 0 then
          distance = (building(i, 2) - fx) * (building(i, 2) - fx) + (building(i, 3) - fy) * (building(i, 3) - fy)
          if distance < best then
            best = distance
            targetX = building(i, 2)
            targetY = building(i, 3)
          end if
        end if
      next i
      for i = 0 to unitCount() - 1
        if unit(i, 6) <> team() and unit(i, 5) > 0 then
          distance = (unit(i, 2) - fx) * (unit(i, 2) - fx) + (unit(i, 3) - fy) * (unit(i, 3) - fy)
          if distance < best and distance < 100 then
            best = distance
            targetX = unit(i, 2)
            targetY = unit(i, 3)
          end if
        end if
      next i
      aim(targetX, targetY)
      shoot(1)
      distance = (targetX - fx) * (targetX - fx) + (targetY - fy) * (targetY - fy)
      if bodyType = flare and distance <= 64 then
        ' Flares need continuous flight to fire, so circle their attack target.
        move(fy - targetY, targetX - fx)
      else
        if distance > 64 then move(targetX - fx, targetY - fy)
      end if
    else
      ' Keep the fragile builder flyer behind the army until a combat body exists.
      move(cx + side * 8 - fx, cy + role - 2 - fy)
    end if
  end if
  if role < 2 or bodyType <> preferred then
    ' Builder flyers only fire when the policy explicitly finds a nearby enemy.
    best = 144
    for i = 0 to unitCount() - 1
      if unit(i, 6) <> team() and unit(i, 5) > 0 then
        distance = (unit(i, 2) - fx) * (unit(i, 2) - fx) + (unit(i, 3) - fy) * (unit(i, 3) - fy)
        if distance < best then
          best = distance
          aim(unit(i, 2), unit(i, 3))
          shoot(1)
        end if
      end if
    next i
  end if
  end
end if

if tick() = 0 then
  cx = coreX()
  cy = coreY()
  left = cx - 16
  bottom = cy - 16
  stage = 0
  copper = itemId("copper")
  duo = blockId("duo")
  bestMine = 1000
end if
if stage = 0 then
  y = bottom + scanRow
  for x = left to left + 32
    cell = (y - bottom) * 33 + x - left
    routes(cell) = 0
    if blockAt(x, y) <> -1 then
      routes(cell) = -1
    end if
    if oreAt(x, y) = 1 and blockAt(x, y) = -1 then
      measure(x - cx, y - cy)
      distance = measureSize
      if distance < bestMine then
        bestMine = distance
        mineX = x
        mineY = y
      end if
    end if
  next x
  scanRow = scanRow + 1
  if scanRow = 33 then
    if bestMine < 1000 then
      cell = (mineY - bottom) * 33 + mineX - left
      routes(cell) = -1
    end if
    stage = 1
  end if
end if
' Seed the four core entrances, then grow a reverse conveyor routing tree.
if stage = 1 or stage = 4 then
  head = 0
  tail = 0
  for direction = 0 to 3
    x = cx
    y = cy
    if direction = 0 then x = cx - 2
    if direction = 1 then y = cy - 2
    if direction = 2 then x = cx + 2
    if direction = 3 then y = cy + 2
    cell = (y - bottom) * 33 + x - left
    if routes(cell) = 0 then
      routes(cell) = 8 + direction + 1
      frontier(tail) = cell
      tail = tail + 1
    end if
  next direction
  stage = stage + 1
end if
if stage = 2 or stage = 5 then
  for work = 1 to 32
    if head < tail then
      cell = frontier(head)
      head = head + 1
      gx = cell mod 33
      gy = cell \ 33
      depth = routes(cell) \ 8
      for direction = 0 to 3
        nx = gx
        ny = gy
        if direction = 0 then nx = gx - 1
        if direction = 1 then ny = gy - 1
        if direction = 2 then nx = gx + 1
        if direction = 3 then ny = gy + 1
        if nx >= 0 and nx < 33 and ny >= 0 and ny < 33 then
          neighbor = ny * 33 + nx
          if routes(neighbor) = 0 then
            routes(neighbor) = (depth + 1) * 8 + direction + 1
            frontier(tail) = neighbor
            tail = tail + 1
          end if
        end if
      next direction
    end if
  next work
  if head = tail then stage = stage + 1
end if
' Pick four productive, separate drill footprints using distance to the core.
if stage = 3 then
  site = siteCount
  if site < 4 then
    if searchRow = 0 then best = -1000
    y = bottom + 1 + searchRow
    for x = left + 1 to left + 30
      cell = (y - bottom) * 33 + x - left
      if routes(cell) > 0 and routes(cell + 1) > 0 then
        if routes(cell + 33) > 0 and routes(cell + 34) > 0 then
          ore = 0
          for j = 0 to 1
            for i = 0 to 1
              if oreAt(x + i, y + j) = 1 then ore = ore + 1
              if oreAt(x + i, y + j) = 2 then ore = ore - 10
            next i
          next j
          score = ore * 15 - routes(cell) \ 8
          if ore > 0 and score > best then
            best = score
            sitesX(site) = x
            sitesY(site) = y
          end if
        end if
      end if
    next x
    searchRow = searchRow + 1
    if searchRow = 30 then
      if best > -1000 then
        x = sitesX(site)
        y = sitesY(site)
        cell = (y - bottom) * 33 + x - left
        routes(cell) = -1
        routes(cell + 1) = -1
        routes(cell + 33) = -1
        routes(cell + 34) = -1
        ordersX(orderCount) = x
        ordersY(orderCount) = y
        ordersType(orderCount) = 0
        orderCount = orderCount + 1
        siteCount = siteCount + 1
      end if
      if best = -1000 then stage = 4
      searchRow = 0
    end if
  end if
  if siteCount = 4 or stage = 4 then
    for cell = 0 to 1088
      if routes(cell) > 0 then routes(cell) = 0
    next cell
    stage = 4
  end if
end if
' Trace each drill's shortest surviving route and deduplicate shared belts.
if stage = 6 then
  for site = 0 to siteCount - 1
    x = sitesX(site)
    y = sitesY(site)
    best = 1000
    start = -1
    for j = -1 to 2
      for i = -1 to 2
        if (i = -1 or i = 2) and (j = 0 or j = 1) or (j = -1 or j = 2) and (i = 0 or i = 1) then
          cell = (y + j - bottom) * 33 + x + i - left
          if routes(cell) > 0 and routes(cell) < best then
            best = routes(cell)
            start = cell
          end if
        end if
      next i
    next j
    cell = start
    for hop = 0 to 64
      if cell >= 0 then
        x = left + cell mod 33
        y = bottom + cell \ 33
        direction = routes(cell) mod 8 - 1
        duplicate = 0
        for i = 0 to orderCount - 1
          if ordersX(i) = x and ordersY(i) = y then duplicate = 1
        next i
        if duplicate = 0 and orderCount < 120 then
          ordersX(orderCount) = x
          ordersY(orderCount) = y
          ordersType(orderCount) = 1
          ordersRotation(orderCount) = direction
          orderCount = orderCount + 1
        end if
        if routes(cell) \ 8 = 1 then
          cell = -1
        else
          if direction = 0 then cell = cell + 1
          if direction = 1 then cell = cell + 33
          if direction = 2 then cell = cell - 1
          if direction = 3 then cell = cell - 33
        end if
      end if
    next hop
  next site
  ' A spaced ring leaves access to the core and room for conveyor entrances.
  for side = 0 to 3
    for offset = -6 to 6 step 3
      x = cx + offset
      y = cy + 6
      if side = 1 then
        x = cx + 6
        y = cy + offset
      end if
      if side = 2 then y = cy - 6
      if side = 3 then
        x = cx - 6
        y = cy + offset
      end if
      duplicate = 0
      if x = mineX and y = mineY then duplicate = 1
      for i = 0 to orderCount - 1
        measure(ordersX(i) - x, ordersY(i) - y)
        if measureX < 2 and measureY < 2 then duplicate = 1
      next i
      if blockAt(x, y) = -1 and duplicate = 0 then
        ordersX(orderCount) = x
        ordersY(orderCount) = y
        ordersType(orderCount) = 5
        orderCount = orderCount + 1
      end if
    next offset
  next side
  ' A front wall absorbs hits while the northern turrets fire over it.
  for offset = -7 to 7
    x = cx + offset
    y = cy + 8
    if blockAt(x, y) = -1 then
      ordersX(orderCount) = x
      ordersY(orderCount) = y
      ordersType(orderCount) = 4
      orderCount = orderCount + 1
    end if
  next offset
  stage = 7
end if
' Revisit the blueprint to rebuild destroyed structures, with a short queue.
if stage = 7 and pending() = 0 and stock(copper) > 45 then
  queued = 0
  for i = 0 to orderCount - 1
    if queued < 4 then
      x = ordersX(i)
      y = ordersY(i)
      if blockAt(x, y) = -1 then
        accepted = build(ordersType(i), x, y, ordersRotation(i))
        queued = queued + 1
      end if
    end if
  next i
end if
if flyerHealth() > 0 then
  ' Supply the emptiest turret by hand, using the same inventory transfers as a human.
  ammo = 30
  refill = -1
  for i = 0 to buildingCount() - 1
    if building(i, 5) = 1 and building(i, 9) = 1 then
      if contentAt(building(i, 2), building(i, 3)) = duo then
        if building(i, 11) < ammo then
          ammo = building(i, 11)
          refill = i
        end if
      end if
    end if
  next i
  targetX = cx
  targetY = cy + 2
  if refill >= 0 and ammo < 20 then
    if carried() = 0 and stock(copper) > 20 then
      accepted = take(cx, cy, copper, 30)
    end if
    if carried() > 0 then
      targetX = building(refill, 2)
      targetY = building(refill, 3)
      accepted = deposit(targetX, targetY)
    end if
  else
    if carried() > 0 then accepted = deposit(cx, cy)
  end if
  if planCount() > 0 then
    targetX = plan(0, 0)
    targetY = plan(0, 1)
  else
    if carried() = 0 and bestMine < 1000 then
      if blockAt(mineX, mineY) = -1 then
        targetX = mineX
        targetY = mineY
        accepted = mine(mineX, mineY)
      end if
    end if
  end if
  ' Stay close enough to build and mine, while leading nearby attackers explicitly.
  dx = targetX - flyerX()
  dy = targetY - flyerY()
  measure(dx, dy)
  if measureSize > 5 then
    scale = measureX
    if measureY > scale then scale = measureY
    if scale < 1 then scale = 1
    accepted = move(dx / scale, dy / scale)
  end if
  enemy = -1
  distance = 1000
  for i = 0 to unitCount() - 1
    if unit(i, 6) = 2 then
      measure(unit(i, 2) - flyerX(), unit(i, 3) - flyerY())
      candidate = measureSize
      if candidate < distance then
        distance = candidate
        enemy = i
      end if
    end if
  next i
  if enemy >= 0 and distance < 21 then
    tx = unit(enemy, 2) + unit(enemy, 9) * 6
    ty = unit(enemy, 3) + unit(enemy, 10) * 6
    accepted = aim(tx, ty)
    dx = tx - flyerX()
    dy = ty - flyerY()
    if dx * dx + dy * dy < 225 then accepted = shoot(1)
  end if
end if
