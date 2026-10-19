' Drills: one survival flyer that builds a drill-and-belt economy for any
' campaign sector. At its first decision it reads the sector (terrain,
' ruins, spawns, objectives) and plans the whole base (the planner is at the
' end): pairs of mechanical drill rows on each ore patch with a conveyor
' spine between them, a trunk from every spine to its own face of the core
' or into another line, the blocks the objectives ask for, Duos on the
' enemy's approach and graphite presses by the core. The flyer builds the
' orders in turn whenever the core can pay for them, mines by hand meanwhile,
' keeps the Duos loaded and the presses fed, calls waves early when the base
' can take the next one and shoots.
dim orderKind(11999)
' The planner's maps, one cell a tile, sized for the largest sectors.
dim tRes(359999)
dim tOpen(359999)
dim tTaken(359999)
dim tUsed(359999)
dim tLane(359999)
dim tFlow(359999)
dim tLine(359999)
dim tCross(359999)
dim tRef(359999)
dim tNear(359999)
dim tDist(359999)
dim tMark(359999)
dim tDead(359999)
dim qBuf(359999)
' The trunk search: one cell a tile and heading, and its heap.
dim dCost(1439999)
dim dPrev(1439999)
dim dStamp(1439999)
dim hKey(1999999)
dim hVal(1999999)
dim pathX(3999)
dim pathY(3999)
dim spawnX(15)
dim spawnY(15)
dim patKind(1999)
dim patX0(1999)
dim patY0(1999)
dim patX1(1999)
dim patY1(1999)
dim patDist(1999)
dim patOrder(1999)
dim cfgTX(19999)
dim cfgTY(19999)
dim cfgDX(9999)
dim cfgDY(9999)
dim cfgTileStart(999)
dim cfgTileLen(999)
dim cfgDrillStart(999)
dim cfgDrillLen(999)
dim bstTX(19999)
dim bstTY(19999)
dim bstDX(9999)
dim bstDY(9999)
dim bstTileStart(999)
dim bstTileLen(999)
dim bstDrillStart(999)
dim bstDrillLen(999)
dim spKind(1999)
dim spTileStart(1999)
dim spTileLen(1999)
dim spDrillStart(1999)
dim spDrillLen(1999)
dim spEndDist(1999)
dim spOrder(1999)
dim stX(99999)
dim stY(99999)
dim sdX(49999)
dim sdY(49999)
dim rtX(99999)
dim rtY(99999)
dim rcT(99999)
dim brX(99999)
dim brY(99999)
dim brC(99999)
dim lnX(99999)
dim lnY(99999)
dim lbKind(99999)
dim lbRot(99999)
dim lbHop(99999)
dim drOrder(999)
dim drKey(999)
dim lnLoad(1999)
dim lnKind(1999)
dim poKind(199999)
dim poX(199999)
dim poY(199999)
dim poRot(199999)
dim plStart(1999)
dim plLen(1999)
dim plCost(1999)
dim plKind(1999)
dim plTrunk(1999)
dim plJoin(1999)
dim plParent(1999)
dim plQueued(1999)
dim plLineNo(1999)
dim plDrills(1999)
dim wgBegin(63)
dim wgEnd(63)
dim wgAmount(63)
dim wgScaling(63)
dim wgMax(63)
dim wgShields(63)
dim wgShieldScaling(63)
dim wgSpacing(63)
dim wgHealth(63)
dim wgArmor(63)
dim cpX(3)
dim cpY(3)
dim cpBx(3)
dim cpBy(3)
dim seqList(1999)
dim exPlan(19999)
dim exKind(19999)
dim exX(19999)
dim exY(19999)
dim exRot(19999)
dim fwKind(63)
dim fwX(63)
dim fwY(63)
dim fwDx(7)
dim fwDy(7)
dim cdKey(9999)
dim cdX(9999)
dim cdY(9999)
dim fdKind(63)
dim fdX(63)
dim fdY(63)
dim fdRot(63)
dim zwX(127)
dim zwY(127)
dim bwX(127)
dim bwY(127)
dim cgX2(7)
dim cgY2(7)
dim duoX(15)
dim duoY(15)
dim askKind(63)
dim askX(63)
dim askY(63)
' Steps east, north, west and south; the ore kinds in planning order
' (copper, lead, scrap, coal); the spots around a forward drill; the eight
' tiles touching a 2x2 drill; the side offsets home defenses try.
data dirX = 1, 0, -1, 0
data dirY = 0, 1, 0, -1
data oreOrder = 1, 2, 4, 3
data offX = 0, 2, -2, 0, 0, 2, -2, 2, -2
data offY = 0, 0, 0, 2, -2, 2, -2, -2, 2
data edgeX = -1, -1, 2, 2, 0, 1, 0, 1
data edgeY = 0, 1, 0, 1, -1, -1, 2, 2
data sideList = 0, 2, -2, 4, -4, 6, -6
data sideList2 = 0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6
dim orderTries(11999)
dim lineOk(255)
dim lineOre(255)
dim oreX(3)
dim oreY(3)
dim oreBest(3)
dim scanX(3)
dim scanY(3)
dim scanBest(3)
dim hotX(15)
dim hotY(15)
dim hotWeight(15)
dim hotDuos(15)

if ready = 0 then
  ready = 1
  cx = coreX()
  cy = coreY()
  copper = itemId("copper")
  lead = itemId("lead")
  graphite = itemId("graphite")
  coal = itemId("coal")
  scrap = itemId("scrap")
  conveyor = blockId("conveyor")
  drill = blockId("mechanical-drill")
  duo = blockId("duo")
  router = blockId("router")
  junction = blockId("junction")
  press = blockId("graphite-press")
  generator = blockId("combustion-generator")
  node = blockId("power-node")
  battery = blockId("battery")
  arc = blockId("arc")
  wall = blockId("copper-wall")
  scatter = blockId("scatter")
  orderCount = 0
  ' Switches for the plan's parts.
  useKillZone = 0
  useWalls = 1
  deadEpoch = 1
  planBase()
  readWaves()
  print "plan: core", cx, cy, "size", coreSize, "patches", patchN, "spines", spineN, "lines", linesKept, "of", planN, "no outlet", noOutlet, "orders", orderCount, "forward", fwN, "walls", zwN, "duos", duoN, "asked", askN
  ' Orders stay packed in orderKind (written by the planner below) and
  ' unpack as the build scan reaches them: ((kind * 4 + rotation) * 512 +
  ' x offset + 256) * 512 + y offset + 256. Kinds: 0 conveyor, 1 mechanical
  ' drill, 2 Duo, 3 router, 4 junction, 5 graphite press, 6 combustion
  ' generator, 7 power node, 8 battery, 9 Arc, 10 copper wall, 11 Scatter,
  ' 12 line header (x offset: its line, y offset: the line it feeds + 1).
  scanStart = 0
  rollFrom = -1
  for k = 1 to 3
    oreBest(k) = 100000
    scanBest(k) = 100000
  next k
  scanRow = 0
end if

' The bot may be asked every tick (sectors) or every sixth (the league):
' aiming, shooting and steering run every call, the heavy scans every
' sixth tick.

' Keep finding the nearest open copper and lead ore within 40 tiles, ten
' rows every sixth tick, so the flyer leaves tiles that drills now cover.
if tick() mod 6 = 0 then
for row = 0 to 9
  y = cy - 40 + scanRow
  for x = cx - 40 to cx + 40
    k = oreAt(x, y)
    if k = 1 or k = 2 then
      if blockAt(x, y) = -1 then
        dx = x - cx
        dy = y - cy
        d2 = dx * dx + dy * dy
        if d2 < scanBest(k) then
          scanBest(k) = d2
          scanX(k) = x
          scanY(k) = y
        end if
      end if
    end if
  next x
  scanRow = scanRow + 1
  if scanRow > 80 then
    scanRow = 0
    for k = 1 to 2
      oreBest(k) = scanBest(k)
      oreX(k) = scanX(k)
      oreY(k) = scanY(k)
      scanBest(k) = 100000
    next k
  end if
next row
end if

if flyerHealth() <= 0 then end
fx = flyerX()
fy = flyerY()
dx = fx - cx
dy = fy - cy
home = 0
if dx > -20 and dx < 20 and dy > -20 and dy < 20 then home = 1

' Alarm: an enemy within thirty tiles of the core calls the flyer home to
' fight beside the Duos and keep them loaded; building waits.
alarm = 0
threatX = cx
threatY = cy
nearest = 900
for i = 0 to unitCount() - 1
  if unit(i, 6) <> team() and unit(i, 5) > 0 then
    dx = unit(i, 2) - cx
    dy = unit(i, 3) - cy
    if dx > -30 and dx < 30 and dy > -30 and dy < 30 then
      d2 = dx * dx + dy * dy
      if d2 < nearest then
        nearest = d2
        alarm = 1
        threatX = unit(i, 2)
        threatY = unit(i, 3)
      end if
    end if
  end if
next i
if alarm = 1 and planCount() > 0 then
  clearPlans()
  holdUntil = tick() + 120
end if

' Build: with no plans left, queue the next orders the core can pay for,
' in plan order and stopping at the first it cannot. A flyer with live
' plans cannot mine, so nothing is ever queued on credit. The scan starts
' at the first line not yet finished and reads at most 150 orders a
' decision, carrying on from there next time, so orders that keep failing
' (outside a sector's open area, an enemy in the way) cannot hide the
' rest. Every ten seconds it starts over, so destroyed parts come back. An
' order that keeps failing is skipped after five tries, and every half
' minute all get another five.
if tick() mod 1800 = 0 then
  for k = 0 to orderCount - 1
    orderTries(k) = (orderTries(k) \ 1000) * 1000
  next k
end if
if tick() mod 600 = 0 then
  scanStart = 0
  rollFrom = -1
end if
' A plan the core cannot pay for stalls the flyer, which cannot mine while
' it has plans: after ten seconds of an empty core, drop the plans.
if planCount() > 0 and stock(copper) < 5 then
  if stallStart = 0 then stallStart = tick()
  if tick() - stallStart > 600 then
    clearPlans()
    holdUntil = tick() + 120
    stallStart = 0
  end if
else
  stallStart = 0
end if
busy = 0
if planCount() > 0 then busy = 1
if busy = 0 and alarm = 0 and hungry = 0 and tick() mod 6 = 0 then
  ' Thirty copper stay in the core for the Duos' ammo.
  budget = stock(copper) - 30
  leadBudget = stock(lead)
  queued = 0
  looked = 0
  stopped = 0
  needLead = 0
  prefix = 1
  ' Each line opens with a header (kind 12) naming the line it feeds, and
  ' comes after that line. A drill waits until every belt of its own line
  ' stands and the line it feeds is whole down to the core: a drill
  ' without a path to the core produces nothing. Dropped plans can leave
  ' half-built belts that read as finished, so drills also wait a while
  ' after any drop.
  if rollFrom >= 0 then
    k = rollFrom
    line = rollLine
    feedOk = rollFeedOk
    beltsMissing = rollMissing
  else
    k = scanStart
    line = -1
    feedOk = 1
    beltsMissing = 0
  end if
  while k < orderCount and looked < 150 and queued < 8 and stopped = 0
    v = orderKind(k)
    oy = cy + v - (v \ 512) * 512 - 256
    v = v \ 512
    ox = cx + v - (v \ 512) * 512 - 256
    v = v \ 512
    turn = v - (v \ 4) * 4
    kind = v \ 4
    if kind = 12 then
      ' A new line: settle the last one, then look up the one this feeds.
      if line >= 0 then
        lineOk(line) = 0
        if beltsMissing = 0 and feedOk = 1 then lineOk(line) = 1
      end if
      line = ox - cx
      feeds = oy - cy - 1
      feedOk = 1
      if feeds >= 0 then feedOk = lineOk(feeds)
      ' With plenty of a side ore in the core its lines wait, so the copper
      ' goes to Duos and copper lines instead.
      full = 0
      if lineOre(line) = 2 and wantLead = 0 and stock(lead) >= 400 then full = 1
      if (lineOre(line) = 3 or lineOre(line) = 10) and stock(coal) >= 300 then full = 1
      if lineOre(line) = 4 and stock(scrap) >= 200 then full = 1
      beltsMissing = 0
      if prefix = 1 then scanStart = k
    else
      id = conveyor
      cost = 1
      leadCost = 0
      if kind = 1 then
        id = drill
        cost = 12
      end if
      if kind = 2 then
        id = duo
        cost = 35
      end if
      if kind = 3 then
        id = router
        cost = 3
      end if
      if kind = 4 then
        id = junction
        cost = 3
      end if
      if kind = 5 then
        id = press
        cost = 75
        leadCost = 30
      end if
      if kind = 6 then
        id = generator
        cost = 28
        leadCost = 15
      end if
      if kind = 7 then
        id = node
        cost = 2
        leadCost = 6
      end if
      if kind = 8 then
        id = battery
        cost = 5
        leadCost = 20
      end if
      if kind = 9 then
        id = arc
        cost = 50
        leadCost = 50
      end if
      if kind = 10 then
        id = wall
        cost = 6
      end if
      if kind = 11 then
        id = scatter
        cost = 85
        leadCost = 45
      end if
      if full = 1 and (kind < 2 or kind = 3 or kind = 4 or kind = 5) then
        ' A waiting line: its belts count as missing, so what it feeds waits.
        prefix = 0
        if kind <> 1 then beltsMissing = 1
      elseif kind = 1 and (beltsMissing = 1 or feedOk = 0 or tick() < holdUntil) then
        ' Skip this drill for now; later lines and Duos still get built.
        prefix = 0
      else
        if contentAt(ox, oy) <> id then
          prefix = 0
          if kind = 0 or kind = 3 or kind = 4 then beltsMissing = 1
          if orderTries(k) >= 1000 then
            ' A part we had built is gone: the enemy hit here. Count it on
            ' the nearest hot spot within eight tiles, or open a new one.
            orderTries(k) = orderTries(k) - 1000
            slot = -1
            for h = 0 to 15
              if slot < 0 and hotWeight(h) > 0 then
                dx = hotX(h) - ox
                dy = hotY(h) - oy
                if dx > -9 and dx < 9 and dy > -9 and dy < 9 then slot = h
              end if
            next h
            if slot < 0 then
              slot = 0
              for h = 1 to 15
                if hotWeight(h) < hotWeight(slot) then slot = h
              next h
              hotX(slot) = ox
              hotY(slot) = oy
              hotWeight(slot) = 0
              hotDuos(slot) = 0
            end if
            hotWeight(slot) = hotWeight(slot) + 1
          end if
          if orderTries(k) < 5 then
            if cost > budget then
              ' Stop at the first order the core cannot pay for yet.
              stopped = 1
              if leadCost > leadBudget then needLead = 1
            elseif leadCost > leadBudget then
              ' Short only of lead: the flyer mines lead for it while copper
              ' keeps building what comes after.
              needLead = 1
            else
              if buildBlock(id, ox, oy, turn) = 1 then
                budget = budget - cost
                leadBudget = leadBudget - leadCost
                queued = queued + 1
              end if
              orderTries(k) = orderTries(k) + 1
            end if
          end if
        else
          ' Mark it built (plus 1000) so its loss is noticed later.
          if orderTries(k) < 1000 then orderTries(k) = orderTries(k) + 1000
        end if
      end if
    end if
    k = k + 1
    looked = looked + 1
  wend
  ' A window that ran out of orders to read carries on there next time; a
  ' pass that reached the end or the core's purse starts over.
  rollFrom = -1
  if stopped = 0 and queued < 8 and k < orderCount then
    rollFrom = k
    rollLine = line
    rollFeedOk = feedOk
    rollMissing = beltsMissing
  end if
  if queued > 0 then busy = 1
end if

' contentAt reports a started site as its finished block, so finish any
' site of ours left half built before going back to mining.
if busy = 0 and stock(copper) >= 12 and tick() mod 120 = 60 then
  ' A rolling window of 300 buildings keeps big bases in budget.
  if siteFrom >= buildingCount() then siteFrom = 0
  last = siteFrom + 299
  if last > buildingCount() - 1 then last = buildingCount() - 1
  for i = siteFrom to last
    if building(i, 5) = team() then
      if building(i, 9) < 1 then
        sx = building(i, 2)
        sy = building(i, 3)
        buildBlock(contentAt(sx, sy), sx, sy, building(i, 7))
        busy = 1
        exit for
      end if
    end if
  next i
  siteFrom = last + 1
end if

' Reinforce: a hot spot wants two Duos for every part lost there (at most
' ten). Every thirty ticks, with copper to spare, the flyer adds one to the
' spot short the most, searching rings two to six tiles out for an open
' tile off the ore that touches a copper drill, which keeps it loaded. Near
' home, where the flyer feeds Duos by hand, any open tile will do.
if tick() mod 30 = 24 and stock(copper) >= 100 then
  best = -1
  short = 0
  for h = 0 to 15
    want = hotWeight(h) * 2
    if want > 10 then want = 10
    if want - hotDuos(h) > short then
      short = want - hotDuos(h)
      best = h
    end if
  next h
  if best >= 0 then
    hx = hotX(best)
    hy = hotY(best)
    spotX = -1
    spareX = -1
    for r = 2 to 6
      for dy = -r to r
        for dx = -r to r
          if spotX < 0 and (dx = -r or dx = r or dy = -r or dy = r) then
            tx = hx + dx
            ty = hy + dy
            if blockAt(tx, ty) = -1 and oreAt(tx, ty) = 0 then
              loaded = 0
              if contentAt(tx + 1, ty) = drill and oreAt(tx + 1, ty) = 1 then loaded = 1
              if contentAt(tx - 1, ty) = drill and oreAt(tx - 1, ty) = 1 then loaded = 1
              if contentAt(tx, ty + 1) = drill and oreAt(tx, ty + 1) = 1 then loaded = 1
              if contentAt(tx, ty - 1) = drill and oreAt(tx, ty - 1) = 1 then loaded = 1
              if loaded = 1 then
                spotX = tx
                spotY = ty
              end if
              if spareX < 0 then
                spareX = tx
                spareY = ty
              end if
            end if
          end if
        next dx
      next dy
    next r
    if spotX < 0 and spareX >= 0 then
      dx = spareX - cx
      dy = spareY - cy
      if dx > -20 and dx < 20 and dy > -20 and dy < 20 then
        spotX = spareX
        spotY = spareY
      end if
    end if
    ' Count the try even when nothing fits, so one spot cannot stall.
    hotDuos(best) = hotDuos(best) + 1
    if spotX >= 0 then
      if buildBlock(duo, spotX, spotY, 0) = 1 then busy = 1
    end if
  end if
end if

' Count the Duos that hold ammo, and the empty ones near the core, a
' hundred buildings every sixth tick, so a big base stays in budget; the
' totals settle once a pass is done. Four empty Duos make the flyer go home
' and load them before it builds anything more.
if tick() mod 6 = 0 then
  if armFrom >= buildingCount() then
    armFrom = 0
    armed = arming
    arming = 0
    emptyDuos = starving
    starving = 0
  end if
  last = armFrom + 99
  if last > buildingCount() - 1 then last = buildingCount() - 1
  for i = armFrom to last
    if building(i, 5) = team() then
      if contentAt(building(i, 2), building(i, 3)) = duo then
        if building(i, 11) > 0 then
          arming = arming + 1
        else
          dx = building(i, 2) - cx
          dy = building(i, 3) - cy
          if dx > -25 and dx < 25 and dy > -25 and dy < 25 then starving = starving + 1
        end if
      end if
    end if
  next i
  armFrom = last + 1
end if
hungry = 0
if emptyDuos >= 4 then hungry = 1
' Cores do not heal, so an old scar must not stop the wave calls: the core
' counts as safe once it has lost no health for ten seconds.
if coreHealth() < lastCore then hurtUntil = tick() + 600
lastCore = coreHealth()

' The next wave's strength, from the sector's wave script: the Duos it
' takes to kill it in about eight seconds. Read every sixtieth tick.
if tick() mod 60 = 30 then
  graphiteAmmo = 0
  if stock(graphite) >= 50 then graphiteAmmo = 1
  waveThreat(wave() - 1)
  needDuos = threatDuos
end if

' Call the next wave early, like the campaign's skip-wave button, so the
' sector is won sooner; the engine only allows it with no enemy alive.
' Only a ready base calls: the core unhurt for ten seconds, enough loaded
' Duos for the next wave and copper in the core. Otherwise the wave timer
' runs while the base grows.
if tick() mod 30 = 18 and alarm = 0 and armed >= needDuos and armed >= 3 and tick() >= hurtUntil and stock(copper) >= 100 then nextWave()

' Short of Duos for the next wave, spare copper buys more on the enemy's
' approach: a ring four to ten tiles out from the core toward it, off ore,
' where the flyer keeps them loaded.
if tick() mod 30 = 6 and alarm = 0 and armed + placed < needDuos + 2 and stock(copper) >= 150 then
  rdLx = apX - cx
  rdLy = apY - cy
  isqrt(rdLx * rdLx + rdLy * rdLy)
  if gRoot < 1 then gRoot = 1
  rdDone = 0
  for rdReach = 4 to 10
    for rdS = 0 to 12
      if rdDone = 0 then
        rdX = cx + (rdLx * rdReach - rdLy * sideList2(rdS)) \ gRoot
        rdY = cy + (rdLy * rdReach + rdLx * sideList2(rdS)) \ gRoot
        if blockAt(rdX, rdY) = -1 and oreAt(rdX, rdY) = 0 then
          if buildBlock(duo, rdX, rdY, 0) = 1 then
            rdDone = 1
            placed = placed + 1
          end if
        end if
      end if
    next rdS
  next rdReach
end if
' What was placed shows up in the armed count once loaded.
if tick() mod 600 = 0 then placed = 0

' Once coal reaches the core, build the presses by it, one at a time, with
' copper and lead to spare and the belt that takes their graphite in place.
if tick() mod 60 = 42 and alarm = 0 and stock(coal) >= 30 and stock(copper) >= 200 and stock(lead) >= 60 then
  for i = 0 to cpN - 1
    if contentAt(cpX(i), cpY(i)) <> press then
      if cpBx(i) < 0 or contentAt(cpBx(i), cpBy(i)) = conveyor then
        if buildBlock(press, cpX(i), cpY(i), 0) = 1 then busy = 1
        exit for
      end if
    end if
  next i
end if

' Move: to the first plan while building, otherwise onto the nearest free
' copper (lead once copper is plentiful) and mine it. Mined items drop
' into the core within 27.5 tiles of it.
targetX = cx
targetY = cy
if alarm = 1 then
  ' Halfway to the threat: in its range and still home to feed the Duos.
  targetX = (cx + threatX) / 2
  targetY = (cy + threatY) / 2
elseif hungry = 1 then
  ' Empty Duos near the core: stay home and load them.
  targetX = cx
  targetY = cy
elseif busy = 1 and planCount() > 0 then
  targetX = plan(0, 0)
  targetY = plan(0, 1)
else
  want = 1
  if stock(copper) >= 400 and oreBest(2) < 100000 then want = 2
  ' The tech blocks cost lead too: keep a little on hand.
  if stock(lead) < 120 and stock(copper) >= 100 and oreBest(2) < 100000 then want = 2
  ' The order the scan is saving for needs lead: mine that.
  if needLead = 1 and oreBest(2) < 100000 then want = 2
  if oreBest(want) < 100000 then
    targetX = oreX(want)
    targetY = oreY(want)
    mine(oreX(want), oreY(want))
  end if
end if

' Keep the Duos loaded by hand, with graphite once the press has made
' some (twice the damage) and copper before that, only from near the core: a
' deposit out of reach would leave the copper in hand. Six at most every
' fifteen ticks: a big base has too many buildings to walk each decision.
if home = 1 and tick() mod 15 = 12 then
  ' Empty the hand first: a deposit that failed leaves the stack there.
  if carried() > 0 then deposit(cx, cy)
  fed = 0
  ammo = copper
  if stock(graphite) >= 10 then ammo = graphite
  if feedFrom >= buildingCount() then feedFrom = 0
  last = feedFrom + 299
  if last > buildingCount() - 1 then last = buildingCount() - 1
  for i = feedFrom to last
    if fed < 6 and building(i, 5) = team() and building(i, 9) >= 1 then
      bx = building(i, 2)
      by = building(i, 3)
      ' Only Duos the flyer can reach; far guards load from drills.
      reach = 0
      dx = bx - fx
      dy = by - fy
      if dx > -25 and dx < 25 and dy > -25 and dy < 25 then reach = 1
      if reach = 1 and contentAt(bx, by) = duo and building(i, 11) < 8 and stock(ammo) >= 10 then
        take(cx, cy, ammo, 8)
        deposit(bx, by)
        fed = fed + 1
      end if
      ' A Scatter (anti-air) fires lead.
      if reach = 1 and contentAt(bx, by) = scatter and building(i, 11) < 8 and stock(lead) >= 10 then
        take(cx, cy, lead, 8)
        deposit(bx, by)
        fed = fed + 1
      end if
    end if
  next i
  feedFrom = last + 1
  ' Top up the presses by the core with coal every ninety ticks (they burn
  ' two each one and a half seconds), handing back what they leave.
  if tick() mod 90 = 57 and stock(coal) >= 10 then
    for i = 0 to cpN - 1
      if contentAt(cpX(i), cpY(i)) = press then
        deposit(cx, cy)
        take(cx, cy, coal, 10)
        deposit(cpX(i), cpY(i))
      end if
    next i
    deposit(cx, cy)
  end if
end if

' Steer with a short brake near the target; builders stay in reach.
dx = targetX - fx
dy = targetY - fy
d2 = 100
if dx > -50 and dx < 50 and dy > -50 and dy < 50 then d2 = dx * dx + dy * dy
if d2 > 4 then
  move(dx, dy)
else
  move(dx / 4, dy / 4)
end if

' Shoot the closest enemy unit in reach.
best = 300
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
  aim(unit(target, 2), unit(target, 3))
  shoot(1)
end if

' The planner: at the first decision the bot reads the sector (terrain,
' ruins, spawns, objectives) and lays out its whole base as a list of
' orders, which the rest of the program builds in turn. Tiles are numbered
' t = y * mapW + x; every per-tile array is sized for the largest maps.

' Reads the terrain, the buildings already standing and the spawns.
sub readMap()
  mapW = mapWidth()
  mapH = mapHeight()
  for rmT = 0 to mapW * mapH - 1
    rmX = rmT mod mapW
    rmY = rmT \ mapW
    rmR = terrainAt(rmX, rmY, 0)
    if rmR > 4 then rmR = 0
    tRes(rmT) = rmR
    tOpen(rmT) = terrainAt(rmX, rmY, 1)
    if terrainAt(rmX, rmY, 2) = 1 then tOpen(rmT) = 2
    tTaken(rmT) = 0
    tUsed(rmT) = 0
    tLane(rmT) = 0
    tFlow(rmT) = -1
    tLine(rmT) = -1
    tCross(rmT) = 0
    tRef(rmT) = -1
    tMark(rmT) = 0
  next rmT
  coreSize = 3
  for rmI = 0 to buildingCount() - 1
    rmS = building(rmI, 4)
    rmO = -((rmS - 1) \ 2)
    for rmJ = 0 to rmS - 1
      for rmK = 0 to rmS - 1
        rmX = building(rmI, 2) + rmO + rmK
        rmY = building(rmI, 3) + rmO + rmJ
        if rmX >= 0 and rmY >= 0 and rmX < mapW and rmY < mapH then tTaken(rmY * mapW + rmX) = 1
      next rmK
    next rmJ
    if building(rmI, 2) = cx and building(rmI, 3) = cy then coreSize = rmS
  next rmI
  ' The core spans coreLo tiles below and left of its center and coreHi
  ' above and right (a size 4 core sits one tile off center).
  coreLo = (coreSize - 1) \ 2
  coreHi = coreSize - 1 - coreLo
  spawnN = spawnCount()
  if spawnN > 15 then spawnN = 15
  for rmI = 0 to spawnN - 1
    spawnX(rmI) = spawn(rmI, 0)
    spawnY(rmI) = spawn(rmI, 1)
  next rmI
  dropZone = sector(6)
  if dropZone < 1 then dropZone = 37
  areaX = sector(8)
  areaY = sector(9)
  areaW = sector(10)
  areaH = sector(11)
  if areaX < 0 then areaW = 0
end sub

' Sets gFree to whether a tile can take a new block (and, with a trial
' running, is not claimed by it).
sub isFree(ifX, ifY)
  gFree = 0
  if ifX < 0 or ifY < 0 or ifX >= mapW or ifY >= mapH then exit sub
  ft = ifY * mapW + ifX
  if tOpen(ft) <> 1 or tUsed(ft) <> 0 or tTaken(ft) <> 0 then exit sub
  if ifX - cx <= coreHi and cx - ifX <= coreLo and ifY - cy <= coreHi and cy - ifY <= coreLo then exit sub
  if trial <> 0 and tMark(ft) = trial then exit sub
  gFree = 1
end sub

' Sets gIn to whether a tile is in the sector's buildable area.
sub inArea(ax, ay)
  gIn = 1
  if areaW > 0 then
    if ax < areaX or ay < areaY or ax >= areaX + areaW or ay >= areaY + areaH then gIn = 0
  end if
end sub

' Sets gSafe to whether a tile lies at least radius tiles from every spawn.
sub spawnSafe(ssX, ssY, radius)
  gSafe = 1
  for ssI = 0 to spawnN - 1
    ssDx = ssX - spawnX(ssI)
    ssDy = ssY - spawnY(ssI)
    if ssDx * ssDx + ssDy * ssDy < radius * radius then gSafe = 0
  next ssI
end sub

' Walks the enemy's path from its first spawn to the core (spawn first)
' into pathX and pathY: a breadth-first search out from the core over
' open ground, then downhill from the spawn.
sub findPath()
  pathLen = 0
  if spawnN = 0 then exit sub
  for fpT = 0 to mapW * mapH - 1
    tDist(fpT) = -1
  next fpT
  fpHead = 0
  fpTail = 0
  fpT = cy * mapW + cx
  tDist(fpT) = 0
  qBuf(fpTail) = fpT
  fpTail = fpTail + 1
  while fpHead < fpTail
    fpT = qBuf(fpHead)
    fpHead = fpHead + 1
    for fpD = 0 to 3
      fpX = fpT mod mapW + dirX(fpD)
      fpY = fpT \ mapW + dirY(fpD)
      if fpX >= 0 and fpY >= 0 and fpX < mapW and fpY < mapH then
        fpN = fpY * mapW + fpX
        if tDist(fpN) < 0 then
          fpOk = 0
          if tOpen(fpN) >= 1 then fpOk = 1
          if fpX - cx <= coreHi and cx - fpX <= coreLo and fpY - cy <= coreHi and cy - fpY <= coreLo then fpOk = 1
          if fpOk = 1 then
            tDist(fpN) = tDist(fpT) + 1
            qBuf(fpTail) = fpN
            fpTail = fpTail + 1
          end if
        end if
      end if
    next fpD
  wend
  fpX = spawnX(0)
  fpY = spawnY(0)
  if tDist(fpY * mapW + fpX) < 0 then exit sub
  pathX(0) = fpX
  pathY(0) = fpY
  pathLen = 1
  do while tDist(fpY * mapW + fpX) > 0 and pathLen < 3999
    fpMoved = 0
    for fpD = 0 to 3
      if fpMoved = 0 then
        fpNx = fpX + dirX(fpD)
        fpNy = fpY + dirY(fpD)
        if fpNx >= 0 and fpNy >= 0 and fpNx < mapW and fpNy < mapH then
          fpN = fpNy * mapW + fpNx
          if tDist(fpN) >= 0 and tDist(fpN) < tDist(fpY * mapW + fpX) then
            fpX = fpNx
            fpY = fpNy
            fpMoved = 1
          end if
        end if
      end if
    next fpD
    if fpMoved = 0 then exit do
    pathX(pathLen) = fpX
    pathY(pathLen) = fpY
    pathLen = pathLen + 1
  loop
end sub

' Fills tNear with the steps from every tile to the enemy's path beyond
' fifteen tiles of the core (walls ignored), and keeps a lane three tiles
' wide along it clear: nothing but guards stands there.
sub findCorridor()
  for fcT = 0 to mapW * mapH - 1
    tNear(fcT) = 99999
  next fcT
  fcHead = 0
  fcTail = 0
  for fcI = 0 to pathLen - 1
    fcDx = pathX(fcI) - cx
    if fcDx < 0 then fcDx = -fcDx
    fcDy = pathY(fcI) - cy
    if fcDy < 0 then fcDy = -fcDy
    if fcDx > 15 or fcDy > 15 then
      fcT = pathY(fcI) * mapW + pathX(fcI)
      if tNear(fcT) <> 0 then
        tNear(fcT) = 0
        qBuf(fcTail) = fcT
        fcTail = fcTail + 1
      end if
    end if
  next fcI
  while fcHead < fcTail
    fcT = qBuf(fcHead)
    fcHead = fcHead + 1
    for fcD = 0 to 3
      fcX = fcT mod mapW + dirX(fcD)
      fcY = fcT \ mapW + dirY(fcD)
      if fcX >= 0 and fcY >= 0 and fcX < mapW and fcY < mapH then
        fcN = fcY * mapW + fcX
        if tNear(fcN) = 99999 then
          tNear(fcN) = tNear(fcT) + 1
          qBuf(fcTail) = fcN
          fcTail = fcTail + 1
        end if
      end if
    next fcD
  wend
  for fcT = 0 to mapW * mapH - 1
    if tNear(fcT) <= 3 and tUsed(fcT) = 0 then
      tUsed(fcT) = 1
      tLane(fcT) = 1
    end if
  next fcT
end sub

' Finds the connected ore patches of eight tiles or more, copper, lead,
' scrap and coal in that order, then sorts them nearest the core first.
sub findPatches()
  patchN = 0
  for fpk = 0 to 3
    fpKind = oreOrder(fpk)
    markId = markId + 1
    for fpS = 0 to mapW * mapH - 1
      if tRes(fpS) = fpKind and tMark(fpS) <> markId then
        fpHead = 0
        fpTail = 1
        qBuf(0) = fpS
        tMark(fpS) = markId
        fpX0 = fpS mod mapW
        fpX1 = fpX0
        fpY0 = fpS \ mapW
        fpY1 = fpY0
        while fpHead < fpTail
          fpT = qBuf(fpHead)
          fpHead = fpHead + 1
          fpX = fpT mod mapW
          fpY = fpT \ mapW
          if fpX < fpX0 then fpX0 = fpX
          if fpX > fpX1 then fpX1 = fpX
          if fpY < fpY0 then fpY0 = fpY
          if fpY > fpY1 then fpY1 = fpY
          for fpD = 0 to 3
            fpNx = fpX + dirX(fpD)
            fpNy = fpY + dirY(fpD)
            if fpNx >= 0 and fpNy >= 0 and fpNx < mapW and fpNy < mapH then
              fpN = fpNy * mapW + fpNx
              if tRes(fpN) = fpKind and tMark(fpN) <> markId then
                tMark(fpN) = markId
                qBuf(fpTail) = fpN
                fpTail = fpTail + 1
              end if
            end if
          next fpD
        wend
        if fpTail >= 8 and patchN < 1999 then
          patKind(patchN) = fpKind
          patX0(patchN) = fpX0
          patY0(patchN) = fpY0
          patX1(patchN) = fpX1
          patY1(patchN) = fpY1
          fpDx = (fpX0 + fpX1) \ 2 - cx
          if fpDx < 0 then fpDx = -fpDx
          fpDy = (fpY0 + fpY1) \ 2 - cy
          if fpDy < 0 then fpDy = -fpDy
          patDist(patchN) = fpDx + fpDy
          patchN = patchN + 1
        end if
      end if
    next fpS
  next fpk
  ' Nearest first; ties keep the ore order.
  for fpI = 0 to patchN - 1
    patOrder(fpI) = fpI
  next fpI
  for fpI = 1 to patchN - 1
    fpV = patOrder(fpI)
    fpJ = fpI - 1
    do while fpJ >= 0
      if patDist(patOrder(fpJ)) <= patDist(fpV) then exit do
      patOrder(fpJ + 1) = patOrder(fpJ)
      fpJ = fpJ - 1
    loop
    patOrder(fpJ + 1) = fpV
  next fpI
end sub

' Sets gCover to the ore tiles of a kind under a 2x2 drill anchored at its
' lower-left tile, or 0 when it does not fit or another ore would rule it.
sub drillCover(dcX, dcY, dcKind)
  gCover = 0
  dcMine = 0
  dcOther = 0
  for dcJ = 0 to 1
    for dcI = 0 to 1
      isFree(dcX + dcI, dcY + dcJ)
      if gFree = 0 then exit sub
      dcR = tRes((dcY + dcJ) * mapW + dcX + dcI)
      if dcR = dcKind then
        dcMine = dcMine + 1
      elseif dcR > 0 then
        dcOther = dcOther + 1
      end if
    next dcI
  next dcJ
  if dcMine >= 2 and dcOther < dcMine then gCover = dcMine
end sub

' Lays out one patch: pairs of drill rows with a spine belt between them,
' spines five tiles apart, trying both directions, every offset and both
' phases, scored by ore covered (twice) less belts laid on ore. The best
' layout's spines join the spine list and claim their tiles.
sub layoutPatch(lpKind, lpX0, lpY0, lpX1, lpY1)
  lpBest = 0
  bstSpineN = 0
  for lpVertical = 0 to 1
    for lpOffset = 0 to 4
      for lpPhase = 0 to 1
        markId = markId + 1
        trial = markId
        cfgSpineN = 0
        cfgTiles = 0
        cfgDrills = 0
        lpTotal = 0
        if lpVertical = 1 then
          lpA0 = lpY0 - 1
          lpA1 = lpY1 + 1
          lpC0 = lpX0 - 2
          lpC1 = lpX1 + 2
        else
          lpA0 = lpX0 - 1
          lpA1 = lpX1 + 1
          lpC0 = lpY0 - 2
          lpC1 = lpY1 + 2
        end if
        for lpAcross = lpC0 to lpC1
          if ((lpAcross - lpOffset) mod 5 + 5) mod 5 = 0 then
            lpDrillStart = cfgDrills
            lpScore = 0
            lpLo = 999999
            lpHi = -999999
            lpAlong = lpA0 + lpPhase
            while lpAlong <= lpA1
              for lpSide = 0 to 1
                lpOff = 1
                if lpSide = 1 then lpOff = -2
                if lpVertical = 1 then
                  lpDx = lpAcross + lpOff
                  lpDy = lpAlong
                else
                  lpDx = lpAlong
                  lpDy = lpAcross + lpOff
                end if
                drillCover(lpDx, lpDy, lpKind)
                if gCover > 0 then
                  cfgDX(cfgDrills) = lpDx
                  cfgDY(cfgDrills) = lpDy
                  cfgDrills = cfgDrills + 1
                  lpScore = lpScore + gCover * 2
                  for lpJ = 0 to 1
                    for lpI = 0 to 1
                      tMark((lpDy + lpJ) * mapW + lpDx + lpI) = trial
                    next lpI
                  next lpJ
                  lpAt = lpDx
                  if lpVertical = 1 then lpAt = lpDy
                  if lpAt < lpLo then lpLo = lpAt
                  if lpAt + 1 > lpHi then lpHi = lpAt + 1
                end if
              next lpSide
              lpAlong = lpAlong + 2
            wend
            if cfgDrills > lpDrillStart then
              ' The spine covers the drills' span and must be clear all along.
              lpTileStart = cfgTiles
              lpClear = 1
              for lpAt = lpLo to lpHi
                if lpVertical = 1 then
                  lpTx = lpAcross
                  lpTy = lpAt
                else
                  lpTx = lpAt
                  lpTy = lpAcross
                end if
                isFree(lpTx, lpTy)
                if gFree = 0 then
                  lpClear = 0
                  exit for
                end if
                cfgTX(cfgTiles) = lpTx
                cfgTY(cfgTiles) = lpTy
                cfgTiles = cfgTiles + 1
                if tRes(lpTy * mapW + lpTx) > 0 then lpScore = lpScore - 1
              next lpAt
              if lpClear = 0 then
                ' Undo this spine's drills: a blocked spine strands them.
                for lpK = lpDrillStart to cfgDrills - 1
                  for lpJ = 0 to 1
                    for lpI = 0 to 1
                      tMark((cfgDY(lpK) + lpJ) * mapW + cfgDX(lpK) + lpI) = 0
                    next lpI
                  next lpJ
                next lpK
                cfgDrills = lpDrillStart
                cfgTiles = lpTileStart
              else
                for lpK = lpTileStart to cfgTiles - 1
                  tMark(cfgTY(lpK) * mapW + cfgTX(lpK)) = trial
                next lpK
                cfgTileStart(cfgSpineN) = lpTileStart
                cfgTileLen(cfgSpineN) = cfgTiles - lpTileStart
                cfgDrillStart(cfgSpineN) = lpDrillStart
                cfgDrillLen(cfgSpineN) = cfgDrills - lpDrillStart
                cfgSpineN = cfgSpineN + 1
                lpTotal = lpTotal + lpScore
              end if
            end if
          end if
        next lpAcross
        if lpTotal > lpBest then
          lpBest = lpTotal
          bstSpineN = cfgSpineN
          for lpK = 0 to cfgSpineN - 1
            bstTileStart(lpK) = cfgTileStart(lpK)
            bstTileLen(lpK) = cfgTileLen(lpK)
            bstDrillStart(lpK) = cfgDrillStart(lpK)
            bstDrillLen(lpK) = cfgDrillLen(lpK)
          next lpK
          for lpK = 0 to cfgTiles - 1
            bstTX(lpK) = cfgTX(lpK)
            bstTY(lpK) = cfgTY(lpK)
          next lpK
          for lpK = 0 to cfgDrills - 1
            bstDX(lpK) = cfgDX(lpK)
            bstDY(lpK) = cfgDY(lpK)
          next lpK
        end if
      next lpPhase
    next lpOffset
  next lpVertical
  trial = 0
  ' Keep the best layout: its spines join the list and claim their tiles.
  for lpK = 0 to bstSpineN - 1
    if spineN < 1999 then
      spKind(spineN) = lpKind
      spTileStart(spineN) = stN
      spTileLen(spineN) = bstTileLen(lpK)
      for lpI = 0 to bstTileLen(lpK) - 1
        stX(stN) = bstTX(bstTileStart(lpK) + lpI)
        stY(stN) = bstTY(bstTileStart(lpK) + lpI)
        tUsed(stY(stN) * mapW + stX(stN)) = 1
        stN = stN + 1
      next lpI
      spDrillStart(spineN) = sdN
      spDrillLen(spineN) = bstDrillLen(lpK)
      for lpI = 0 to bstDrillLen(lpK) - 1
        sdX(sdN) = bstDX(bstDrillStart(lpK) + lpI)
        sdY(sdN) = bstDY(bstDrillStart(lpK) + lpI)
        for lpJ = 0 to 1
          for lpM = 0 to 1
            tUsed((sdY(sdN) + lpJ) * mapW + sdX(sdN) + lpM) = 1
          next lpM
        next lpJ
        sdN = sdN + 1
      next lpI
      spineN = spineN + 1
    end if
  next lpK
end sub

' Turns every spine to flow toward its end nearer the core and sorts the
' spines by that end's distance, nearest first, into spOrder.
sub orderSpines()
  for osI = 0 to spineN - 1
    osA = spTileStart(osI)
    osB = osA + spTileLen(osI) - 1
    osDa = stX(osA) - cx
    if osDa < 0 then osDa = -osDa
    osE = stY(osA) - cy
    if osE < 0 then osE = -osE
    osDa = osDa + osE
    osDb = stX(osB) - cx
    if osDb < 0 then osDb = -osDb
    osE = stY(osB) - cy
    if osE < 0 then osE = -osE
    osDb = osDb + osE
    if osDb > osDa then
      while osA < osB
        osE = stX(osA)
        stX(osA) = stX(osB)
        stX(osB) = osE
        osE = stY(osA)
        stY(osA) = stY(osB)
        stY(osB) = osE
        osA = osA + 1
        osB = osB - 1
      wend
      spEndDist(osI) = osDa
    else
      spEndDist(osI) = osDb
    end if
    spOrder(osI) = osI
  next osI
  for osI = 1 to spineN - 1
    osV = spOrder(osI)
    osJ = osI - 1
    do while osJ >= 0
      if spEndDist(spOrder(osJ)) <= spEndDist(osV) then exit do
      spOrder(osJ + 1) = spOrder(osJ)
      osJ = osJ - 1
    loop
    spOrder(osJ + 1) = osV
  next osI
end sub

' A binary heap of (key, value) pairs, smallest key on top.
sub heapPush(hpKey, hpVal)
  hpI = heapN
  heapN = heapN + 1
  do while hpI > 0
    hpP = (hpI - 1) \ 2
    if hKey(hpP) <= hpKey then exit do
    hKey(hpI) = hKey(hpP)
    hVal(hpI) = hVal(hpP)
    hpI = hpP
  loop
  hKey(hpI) = hpKey
  hVal(hpI) = hpVal
end sub

' Takes the smallest pair off the heap into gKey and gVal.
sub heapPop()
  gKey = hKey(0)
  gVal = hVal(0)
  heapN = heapN - 1
  if heapN = 0 then exit sub
  hpKey = hKey(heapN)
  hpVal = hVal(heapN)
  hpI = 0
  do
    hpC = hpI * 2 + 1
    if hpC >= heapN then exit do
    if hpC + 1 < heapN then
      if hKey(hpC + 1) < hKey(hpC) then hpC = hpC + 1
    end if
    if hKey(hpC) >= hpKey then exit do
    hKey(hpI) = hKey(hpC)
    hVal(hpI) = hVal(hpC)
    hpI = hpC
  loop
  hKey(hpI) = hpKey
  hVal(hpI) = hpVal
end sub

' Sets gEnds when a belt on a tile can end there, beside the core (gInto
' -1) or feeding the side or back of a line of the same ore (curKind) with
' room for this line's ore (gInto the belt it feeds). Only the same ore:
' a line is built after the line it feeds, so a copper line feeding a long
' coal trunk would wait for all of it.
sub outlet(otX, otY, otWeight)
  gEnds = 0
  gInto = -1
  for otD = 0 to 3
    otNx = otX + dirX(otD)
    otNy = otY + dirY(otD)
    if otNx - cx <= coreHi and cx - otNx <= coreLo and otNy - cy <= coreHi and cy - otNy <= coreLo then
      gEnds = 1
      exit sub
    end if
  next otD
  for otD = 0 to 3
    otNx = otX + dirX(otD)
    otNy = otY + dirY(otD)
    if otNx >= 0 and otNy >= 0 and otNx < mapW and otNy < mapH then
      otJ = otNy * mapW + otNx
      if tFlow(otJ) >= 0 then
        if lnLoad(tLine(otJ)) + otWeight <= 45 and lnKind(tLine(otJ)) = curKind then
          ' Never feed a belt from its front.
          if otNx + dirX(tFlow(otJ)) <> otX or otNy + dirY(tFlow(otJ)) <> otY then
            gEnds = 1
            gInto = otJ
            exit sub
          end if
        end if
      end if
    end if
  next otD
end sub

' The cheapest conveyor path from a free tile beside (tsX, tsY) to an outlet,
' into rtX and rtY
' (rtLen tiles, hopped belts included) with the belt it joins in rtJoined
' (-1 for the core) and the hopped tiles in rcT (rcN). A step costs one, an
' ore tile four more and a turn two more, so trunks run straight and go
' around ore; a path may hop straight across a crossable belt for four
' more, leaving a junction there. rtLen is 0 when there is no path.
sub trunkSearch(tsX, tsY, tsWeight)
  rtLen = 0
  rcN = 0
  rtJoined = -1
  searchId = searchId + 1
  heapN = 0
  for tsD = 0 to 3
    isFree(tsX + dirX(tsD), tsY + dirY(tsD))
    if gFree = 1 then
      tsStart = (tsY + dirY(tsD)) * mapW + tsX + dirX(tsD)
      for tsH = 0 to 3
        tsS = tsStart * 4 + tsH
        dStamp(tsS) = searchId
        dCost(tsS) = 0
        dPrev(tsS) = -1
        heapPush(0, tsS)
      next tsH
    end if
  next tsD
  tsGoal = -1
  tsPopped = 0
  do while heapN > 0
    heapPop()
    tsState = gVal
    tsPopped = tsPopped + 1
    if tsPopped > 400000 or heapN > 1900000 then exit do
    tsHere = gKey
    if tsHere <= dCost(tsState) then
      tsI = tsState \ 4
      tsHeading = tsState mod 4
      tsX0 = tsI mod mapW
      tsY0 = tsI \ mapW
      outlet(tsX0, tsY0, tsWeight)
      if gEnds = 1 then
        tsGoal = tsState
        rtJoined = gInto
        exit do
      end if
      for tsNext = 0 to 3
        tsNx = tsX0 + dirX(tsNext)
        tsNy = tsY0 + dirY(tsNext)
        tsStep = 1
        tsHop = 0
        isFree(tsNx, tsNy)
        tsOk = gFree
        if tsOk = 0 then
          ' Hop a perpendicular straight trunk belt onto the free tile past it.
          if tsNx >= 0 and tsNy >= 0 and tsNx < mapW and tsNy < mapH then
            tsB = tsNy * mapW + tsNx
            if tCross(tsB) = 1 and tFlow(tsB) >= 0 then
              if tFlow(tsB) mod 2 <> tsNext mod 2 then
                tsNx = tsNx + dirX(tsNext)
                tsNy = tsNy + dirY(tsNext)
                isFree(tsNx, tsNy)
                if gFree = 1 then
                  tsOk = 1
                  tsStep = 6
                  tsHop = 1
                end if
              end if
            end if
          end if
        end if
        if tsOk = 1 then
          if tRes(tsNy * mapW + tsNx) > 0 then tsStep = tsStep + 4
          if tsNext <> tsHeading then tsStep = tsStep + 2
          tsJ = (tsNy * mapW + tsNx) * 4 + tsNext
          tsNew = tsHere + tsStep
          if dStamp(tsJ) <> searchId or tsNew < dCost(tsJ) then
            dStamp(tsJ) = searchId
            dCost(tsJ) = tsNew
            dPrev(tsJ) = tsState * 2 + tsHop
            heapPush(tsNew, tsJ)
          end if
        end if
      next tsNext
    end if
  loop
  if tsGoal < 0 then exit sub
  tsAt = tsGoal
  do while tsAt >= 0
    tsI = tsAt \ 4
    rtX(rtLen) = tsI mod mapW
    rtY(rtLen) = tsI \ mapW
    rtLen = rtLen + 1
    if dPrev(tsAt) < 0 then exit do
    if dPrev(tsAt) mod 2 = 1 then
      ' The tile hopped lies one step back the way the path came.
      tsH = tsAt mod 4
      rtX(rtLen) = tsI mod mapW - dirX(tsH)
      rtY(rtLen) = tsI \ mapW - dirY(tsH)
      rcT(rcN) = rtY(rtLen) * mapW + rtX(rtLen)
      rcN = rcN + 1
      rtLen = rtLen + 1
    end if
    tsAt = dPrev(tsAt) \ 2
  loop
  ' Start first.
  tsA = 0
  tsB = rtLen - 1
  while tsA < tsB
    tsH = rtX(tsA)
    rtX(tsA) = rtX(tsB)
    rtX(tsB) = tsH
    tsH = rtY(tsA)
    rtY(tsA) = rtY(tsB)
    rtY(tsB) = tsH
    tsA = tsA + 1
    tsB = tsB - 1
  wend
end sub

' Sets gReach to whether any outlet can be reached from beside a tile, by a
' cheap breadth-first search over free tiles (and straight trunk belts it
' could hop). An area found closed off is remembered until another line is
' laid, since only a new line opens new ways out.
sub canReach(crX, crY, crWeight)
  gReach = 0
  crHead = 0
  crTail = 0
  searchId = searchId + 1
  for crD = 0 to 3
    isFree(crX + dirX(crD), crY + dirY(crD))
    if gFree = 1 then
      crT = (crY + dirY(crD)) * mapW + crX + dirX(crD)
      if tDead(crT) <> deadEpoch then
        dStamp(crT * 4) = searchId
        qBuf(crTail) = crT
        crTail = crTail + 1
      end if
    end if
  next crD
  do while crHead < crTail
    crT = qBuf(crHead)
    crHead = crHead + 1
    crX0 = crT mod mapW
    crY0 = crT \ mapW
    outlet(crX0, crY0, crWeight)
    if gEnds = 1 then
      gReach = 1
      exit sub
    end if
    for crD = 0 to 3
      crNx = crX0 + dirX(crD)
      crNy = crY0 + dirY(crD)
      isFree(crNx, crNy)
      if gFree = 0 and crNx >= 0 and crNy >= 0 and crNx < mapW and crNy < mapH then
        crB = crNy * mapW + crNx
        if tCross(crB) = 1 then
          crNx = crNx + dirX(crD)
          crNy = crNy + dirY(crD)
          isFree(crNx, crNy)
        end if
      end if
      if gFree = 1 then
        crN = crNy * mapW + crNx
        if dStamp(crN * 4) <> searchId then
          dStamp(crN * 4) = searchId
          qBuf(crTail) = crN
          crTail = crTail + 1
        end if
      end if
    next crD
  loop
  for crI = 0 to crTail - 1
    tDead(qBuf(crI)) = deadEpoch
  next crI
end sub

' Sets gRot to the conveyor rotation that points from one tile to an
' adjacent one.
sub rotationTo(rfX, rfY, rtoX, rtoY)
  gRot = 0
  for rfD = 0 to 3
    if rfX + dirX(rfD) = rtoX and rfY + dirY(rfD) = rtoY then gRot = rfD
  next rfD
end sub

' Routes every spine, nearest first, to its own face of the core or into a
' line with room, and turns each into a plan: belts from the core end
' outward, then the drills nearest the spine's end first. Spines with no
' way out give their tiles back.
sub routeSpines()
  for rsK = 0 to spineN - 1
    rsS = spOrder(rsK)
    if rsS <> zoneSpine then
      rsA = spTileStart(rsS)
      rsLen = spTileLen(rsS)
      rsEx = stX(rsA + rsLen - 1)
      rsEy = stY(rsA + rsLen - 1)
      rsKind = spKind(rsS)
      curKind = rsKind
      ' A line's load is the ore tiles its drills stand on.
      rsWeight = 0
      for rsI = spDrillStart(rsS) to spDrillStart(rsS) + spDrillLen(rsS) - 1
        for rsJ = 0 to 1
          for rsM = 0 to 1
            if tRes((sdY(rsI) + rsJ) * mapW + sdX(rsI) + rsM) = rsKind then rsWeight = rsWeight + 1
          next rsM
        next rsJ
      next rsI
      brLen = 0
      brN = 0
      outlet(rsEx, rsEy, rsWeight)
      rsEnds = gEnds
      rsJoined = gInto
      if rsEnds = 0 then
        canReach(rsEx, rsEy, rsWeight)
        rtLen = 0
        if gReach = 1 then trunkSearch(rsEx, rsEy, rsWeight)
        if rtLen > 0 then
          brLen = rtLen
          for rsI = 0 to rtLen - 1
            brX(rsI) = rtX(rsI)
            brY(rsI) = rtY(rsI)
          next rsI
          brN = rcN
          for rsI = 0 to rcN - 1
            brC(rsI) = rcT(rsI)
          next rsI
          rsJoined = rtJoined
          rsEnds = 1
        end if
      end if
      if rsEnds = 0 then
        for rsI = spDrillStart(rsS) to spDrillStart(rsS) + spDrillLen(rsS) - 1
          for rsJ = 0 to 1
            for rsM = 0 to 1
              tUsed((sdY(rsI) + rsJ) * mapW + sdX(rsI) + rsM) = 0
            next rsM
          next rsJ
        next rsI
        for rsI = rsA to rsA + rsLen - 1
          tUsed(stY(rsI) * mapW + stX(rsI)) = 0
        next rsI
        noOutlet = noOutlet + 1
      else
        ' The line: the spine's tiles, then the trunk.
        lnN = 0
        for rsI = rsA to rsA + rsLen - 1
          lnX(lnN) = stX(rsI)
          lnY(lnN) = stY(rsI)
          lnN = lnN + 1
        next rsI
        for rsI = 0 to brLen - 1
          lnX(lnN) = brX(rsI)
          lnY(lnN) = brY(rsI)
          lnN = lnN + 1
        next rsI
        ' A new line may open ways out of areas found closed before.
        deadEpoch = deadEpoch + 1
        if rsJoined < 0 then
          rsLine = lineN
          lnLoad(lineN) = rsWeight
          lnKind(lineN) = rsKind
          lineN = lineN + 1
        else
          rsLine = tLine(rsJoined)
          lnLoad(rsLine) = lnLoad(rsLine) + rsWeight
          ' A merge point takes side input: never cross it.
          tCross(rsJoined) = 0
        end if
        rsPrev = -1
        for rsI = 0 to lnN - 1
          rsT = lnY(rsI) * mapW + lnX(rsI)
          rsHopped = 0
          for rsJ = 0 to brN - 1
            if brC(rsJ) = rsT then rsHopped = 1
          next rsJ
          if rsHopped = 1 then
            ' The belt hopped becomes a junction; both lines carry the order.
            poKind(tRef(rsT)) = 4
            lbKind(rsI) = 4
            lbRot(rsI) = 0
            tCross(rsT) = 0
            tFlow(rsT) = -2
            rsPrev = -1
          else
            if rsI + 1 < lnN then
              rotationTo(lnX(rsI), lnY(rsI), lnX(rsI + 1), lnY(rsI + 1))
            elseif rsJoined < 0 then
              gRot = 0
              for rsD = 0 to 3
                rsNx = lnX(rsI) + dirX(rsD)
                rsNy = lnY(rsI) + dirY(rsD)
                if rsNx - cx <= coreHi and cx - rsNx <= coreLo and rsNy - cy <= coreHi and cy - rsNy <= coreLo then gRot = rsD
              next rsD
            else
              rotationTo(lnX(rsI), lnY(rsI), rsJoined mod mapW, rsJoined \ mapW)
            end if
            lbKind(rsI) = 0
            lbRot(rsI) = gRot
            tUsed(rsT) = 1
            tFlow(rsT) = gRot
            tLine(rsT) = rsLine
            ' Straight trunk belts (not spines, not ends) may be hopped later.
            tCross(rsT) = 0
            if rsI >= rsLen and rsI + 1 < lnN and gRot = rsPrev then tCross(rsT) = 1
            rsPrev = gRot
          end if
        next rsI
        ' Belts go down from the core outward, so every belt placed extends a
        ' line that already reaches the core; the drills follow.
        plStart(planN) = orderN
        for rsI = lnN - 1 to 0 step -1
          poKind(orderN) = lbKind(rsI)
          poX(orderN) = lnX(rsI)
          poY(orderN) = lnY(rsI)
          poRot(orderN) = lbRot(rsI)
          if lbKind(rsI) = 0 then tRef(lnY(rsI) * mapW + lnX(rsI)) = orderN
          orderN = orderN + 1
        next rsI
        rsDs = spDrillStart(rsS)
        rsDn = spDrillLen(rsS)
        for rsI = 0 to rsDn - 1
          drOrder(rsI) = rsDs + rsI
          rsDx = sdX(rsDs + rsI) - rsEx
          if rsDx < 0 then rsDx = -rsDx
          rsDy = sdY(rsDs + rsI) - rsEy
          if rsDy < 0 then rsDy = -rsDy
          drKey(rsI) = rsDx + rsDy
        next rsI
        for rsI = 1 to rsDn - 1
          rsV = drOrder(rsI)
          rsW = drKey(rsI)
          rsJ = rsI - 1
          do while rsJ >= 0
            if drKey(rsJ) <= rsW then exit do
            drOrder(rsJ + 1) = drOrder(rsJ)
            drKey(rsJ + 1) = drKey(rsJ)
            rsJ = rsJ - 1
          loop
          drOrder(rsJ + 1) = rsV
          drKey(rsJ + 1) = rsW
        next rsI
        for rsI = 0 to rsDn - 1
          poKind(orderN) = 1
          poX(orderN) = sdX(drOrder(rsI))
          poY(orderN) = sdY(drOrder(rsI))
          poRot(orderN) = 0
          orderN = orderN + 1
        next rsI
        plLen(planN) = orderN - plStart(planN)
        ' Copper spent per drill ranks the lines: the best value builds first.
        plCost(planN) = (lnN + 12 * rsDn) * 100 \ rsDn
        plKind(planN) = rsKind
        plTrunk(planN) = lnN - rsLen
        plJoin(planN) = rsJoined
        planN = planN + 1
      end if
    end if
  next rsK
end sub

' Reads what the sector's objectives ask for: walls and a Scatter to build,
' power blocks or a press (Frozen Forest's tutorial), lead to deliver.
sub readObjectives()
  wantWalls = 0
  wantScatter = 0
  powerWanted = 0
  pressWanted = 0
  wantLead = 0
  for roI = 0 to objectiveCount() - 1
    roType = objective(roI, 0)
    roContent = objective(roI, 2)
    roAmount = objective(roI, 3)
    if roType = 1 then
      if roContent = wall then wantWalls = roAmount
      if roContent = scatter then wantScatter = roAmount
      if roContent = generator or roContent = node or roContent = battery or roContent = arc then powerWanted = 1
      if roContent = press then pressWanted = 1
    end if
    if (roType = 2 or roType = 3) and roContent = lead then wantLead = 1
  next roI
  if powerWanted = 1 then pressWanted = 1
end sub

' Sets gRoot to the integer square root of a number.
sub isqrt(sqN)
  gRoot = 0
  if sqN <= 0 then exit sub
  gRoot = sqN
  sqY = (gRoot + 1) \ 2
  do while sqY < gRoot
    gRoot = sqY
    sqY = (gRoot + sqN \ gRoot) \ 2
  loop
end sub

' Sets gTouch to whether two square blocks, anchored at their lower-left
' tiles, share an edge.
sub touches(tax, tay, tas, tbx, tby, tbs)
  gTouch = 0
  tOverX = 0
  tOverY = 0
  if tax < tbx + tbs and tbx < tax + tas then tOverX = 1
  if tay < tby + tbs and tby < tay + tas then tOverY = 1
  if tOverX = 1 and (tay + tas = tby or tby + tbs = tay) then gTouch = 1
  if tOverY = 1 and (tax + tas = tbx or tbx + tbs = tax) then gTouch = 1
end sub

' The tile twelve steps from the core along the enemy's path, where home
' defenses face, into apX and apY.
sub findApproach()
  apX = cx
  apY = cy + 12
  for faI = 0 to pathLen - 1
    faDx = pathX(faI) - cx
    if faDx < 0 then faDx = -faDx
    faDy = pathY(faI) - cy
    if faDy < 0 then faDy = -faDy
    if faDx <= 12 and faDy <= 12 then
      apX = pathX(faI)
      apY = pathY(faI)
      exit for
    end if
  next faI
end sub

' Forward guard: Duos fed by copper drills beside the enemy's path just
' outside the spawn's drop zone (a wave spawning wipes everything inside),
' so waves die after a short walk. Sets zoneStep, the path step it guards.
sub forwardGuard()
  zoneStep = -1
  if spawnN = 0 or pathLen = 0 then exit sub
  ' The earliest path step within twelve tiles of each tile.
  for fgT = 0 to mapW * mapH - 1
    tDist(fgT) = 999999
  next fgT
  for fgI = pathLen - 1 to 0 step -1
    for fgY = pathY(fgI) - 12 to pathY(fgI) + 12
      for fgX = pathX(fgI) - 12 to pathX(fgI) + 12
        if fgX >= 0 and fgY >= 0 and fgX < mapW and fgY < mapH then tDist(fgY * mapW + fgX) = fgI
      next fgX
    next fgY
  next fgI
  fgBest = 999999
  fgBx = -1
  for fgY = 0 to mapH - 2
    for fgX = 0 to mapW - 2
      if tRes(fgY * mapW + fgX) = 1 or tRes(fgY * mapW + fgX + 1) = 1 then
        if tDist(fgY * mapW + fgX) < fgBest then
          drillCover(fgX, fgY, 1)
          if gCover > 0 then
            spawnSafe(fgX, fgY, dropZone + 3)
            fgOk = gSafe
            spawnSafe(fgX + 1, fgY + 1, dropZone + 3)
            if fgOk = 1 and gSafe = 1 then
              fgBest = tDist(fgY * mapW + fgX)
              fgBx = fgX
              fgBy = fgY
            end if
          end if
        end if
      end if
    next fgX
  next fgY
  if fgBx < 0 then exit sub
  fwN = 0
  fwDrills = 0
  postX = fgBx + 1
  postY = fgBy + 1
  for fgK = 0 to 8
    if fgK = 0 then
      fgX = fgBx
      fgY = fgBy
    else
      fgX = fgBx + offX(fgK)
      fgY = fgBy + offY(fgK)
    end if
    if fwDrills < 3 then
      drillCover(fgX, fgY, 1)
      spawnSafe(fgX, fgY, dropZone + 3)
      fgOk = gSafe
      spawnSafe(fgX + 1, fgY + 1, dropZone + 3)
      if gCover > 0 and fgOk = 1 and gSafe = 1 then
        fwDx(fwDrills) = fgX
        fwDy(fwDrills) = fgY
        fwDrills = fwDrills + 1
        for fgJ = 0 to 1
          for fgM = 0 to 1
            tUsed((fgY + fgJ) * mapW + fgX + fgM) = 1
          next fgM
        next fgJ
      end if
    end if
  next fgK
  ' Duos on open tiles touching a drill, off ore, nearest the path.
  fgC = 0
  for fgK = 0 to fwDrills - 1
    for fgE = 0 to 7
      fgX = fwDx(fgK) + edgeX(fgE)
      fgY = fwDy(fgK) + edgeY(fgE)
      isFree(fgX, fgY)
      if gFree = 1 then
        if tRes(fgY * mapW + fgX) = 0 then
          spawnSafe(fgX, fgY, dropZone + 3)
          if gSafe = 1 then
            cdKey(fgC) = tNear(fgY * mapW + fgX)
            cdX(fgC) = fgX
            cdY(fgC) = fgY
            fgC = fgC + 1
          end if
        end if
      end if
    next fgE
  next fgK
  sortCandidates(fgC)
  for fgK = 0 to fwDrills - 1
    fwKind(fwN) = 1
    fwX(fwN) = fwDx(fgK)
    fwY(fwN) = fwDy(fgK)
    fwN = fwN + 1
  next fgK
  fgDuos = 0
  for fgK = 0 to fgC - 1
    isFree(cdX(fgK), cdY(fgK))
    if fgDuos < 6 and gFree = 1 then
      tUsed(cdY(fgK) * mapW + cdX(fgK)) = 1
      fwKind(fwN) = 2
      fwX(fwN) = cdX(fgK)
      fwY(fwN) = cdY(fgK)
      fwN = fwN + 1
      fgDuos = fgDuos + 1
    end if
  next fgK
  zoneStep = fgBest
end sub

' Sorts the candidate tiles cdX and cdY by cdKey, smallest first.
sub sortCandidates(scN)
  for scI = 1 to scN - 1
    scK = cdKey(scI)
    scX = cdX(scI)
    scY = cdY(scI)
    scJ = scI - 1
    do while scJ >= 0
      if cdKey(scJ) <= scK then exit do
      cdKey(scJ + 1) = cdKey(scJ)
      cdX(scJ + 1) = cdX(scJ)
      cdY(scJ + 1) = cdY(scJ)
      scJ = scJ - 1
    loop
    cdKey(scJ + 1) = scK
    cdX(scJ + 1) = scX
    cdY(scJ + 1) = scY
  next scI
end sub

' Kill zone: where no copper lies by the path, a feeder beside it just
' outside the drop zone (router, belt, router, belt, router, belt from the
' spawn end), a Duo on each side of every router, fed later by a copper
' line of its own.
sub killZone()
  fdN = 0
  feedX = -1
  if spawnN = 0 or pathLen = 0 then exit sub
  kzAnchor = -1
  for kzI = 0 to pathLen - 1
    spawnSafe(pathX(kzI), pathY(kzI), dropZone + 7)
    if gSafe = 1 then
      kzAnchor = kzI
      exit for
    end if
  next kzI
  if kzAnchor < 0 then exit sub
  kzAhead = kzAnchor + 4
  if kzAhead > pathLen - 1 then kzAhead = pathLen - 1
  kzAx = pathX(kzAnchor)
  kzAy = pathY(kzAnchor)
  kzVx = pathX(kzAhead) - kzAx
  kzVy = pathY(kzAhead) - kzAy
  kzAbsX = kzVx
  if kzAbsX < 0 then kzAbsX = -kzAbsX
  kzAbsY = kzVy
  if kzAbsY < 0 then kzAbsY = -kzAbsY
  kzDx = 0
  kzDy = 0
  if kzAbsX >= kzAbsY then
    if kzVx > 0 then kzDx = 1 else kzDx = -1
  else
    if kzVy > 0 then kzDy = 1 else kzDy = -1
  end if
  kzPx = -kzDy
  kzPy = kzDx
  for kzS = 0 to 5
    kzSide = 3 + kzS \ 2
    if kzS mod 2 = 1 then kzSide = -kzSide
    kzFits = 1
    kzC = 0
    for kzK = 0 to 5
      kzX = kzAx + kzPx * kzSide + kzDx * kzK
      kzY = kzAy + kzPy * kzSide + kzDy * kzK
      if kzK mod 2 = 0 then
        cdX(kzC) = kzX
        cdY(kzC) = kzY
        cdKey(kzC) = 3
        cdX(kzC + 1) = kzX + kzPx
        cdY(kzC + 1) = kzY + kzPy
        cdKey(kzC + 1) = 2
        cdX(kzC + 2) = kzX - kzPx
        cdY(kzC + 2) = kzY - kzPy
        cdKey(kzC + 2) = 2
        kzC = kzC + 3
      else
        cdX(kzC) = kzX
        cdY(kzC) = kzY
        cdKey(kzC) = 0
        kzC = kzC + 1
      end if
    next kzK
    for kzK = 0 to kzC - 1
      isFree(cdX(kzK), cdY(kzK))
      spawnSafe(cdX(kzK), cdY(kzK), dropZone + 3)
      if gFree = 0 or gSafe = 0 then kzFits = 0
    next kzK
    if kzFits = 1 then
      for kzK = 0 to kzC - 1
        tUsed(cdY(kzK) * mapW + cdX(kzK)) = 1
        fdKind(fdN) = cdKey(kzK)
        fdX(fdN) = cdX(kzK)
        fdY(fdN) = cdY(kzK)
        rotationTo(cdX(kzK), cdY(kzK), cdX(kzK) - kzDx, cdY(kzK) - kzDy)
        fdRot(fdN) = gRot
        fdN = fdN + 1
      next kzK
      feedX = kzAx + kzPx * kzSide + kzDx * 5
      feedY = kzAy + kzPy * kzSide + kzDy * 5
      frontX = feedX - kzDx
      frontY = feedY - kzDy
      postX = kzAx + kzPx * kzSide + kzDx * 2
      postY = kzAy + kzPy * kzSide + kzDy * 2
      zoneStep = kzAnchor
      exit for
    end if
  next kzS
end sub

' Copper walls across the enemy's route near a guard, rock to rock, with a
' three-tile gap on the route: ground units path around our buildings at
' a cost that grows with their health, so waves file through the gap past
' the guns. Takes the narrowest crossing from four steps before the guard
' to twelve after; open ground gets none.
sub barrier(baStep)
  zwN = 0
  if baStep < 0 or pathLen < 4 then exit sub
  baBest = 999999
  baFrom = baStep - 4
  if baFrom < 1 then baFrom = 1
  baTo = baStep + 12
  if baTo > pathLen - 2 then baTo = pathLen - 2
  for baAt = baFrom to baTo
    baAhead = baAt + 3
    if baAhead > pathLen - 1 then baAhead = pathLen - 1
    baBehind = baAt - 3
    if baBehind < 0 then baBehind = 0
    baVx = pathX(baAhead) - pathX(baBehind)
    baVy = pathY(baAhead) - pathY(baBehind)
    baAx = baVx
    if baAx < 0 then baAx = -baAx
    baAy = baVy
    if baAy < 0 then baAy = -baAy
    baDx = 0
    baDy = 0
    if baAx >= baAy then
      if baVx > 0 then baDx = 1 else baDx = -1
    else
      if baVy > 0 then baDy = 1 else baDy = -1
    end if
    baPx = -baDy
    baPy = baDx
    baClosed = 0
    baN = 0
    for baSide = 0 to 1
      baSign = 1
      if baSide = 1 then baSign = -1
      for baT = 2 to 30
        baX = pathX(baAt) + baPx * baT * baSign
        baY = pathY(baAt) + baPy * baT * baSign
        baEdge = 0
        if baX < 0 or baY < 0 or baX >= mapW or baY >= mapH then
          baEdge = 1
        elseif tOpen(baY * mapW + baX) <> 1 or tTaken(baY * mapW + baX) = 1 then
          baEdge = 1
        end if
        if baEdge = 1 then
          baClosed = baClosed + 1
          exit for
        end if
        bwX(baN) = baX
        bwY(baN) = baY
        baN = baN + 1
      next baT
    next baSide
    if baClosed = 2 and baN < baBest then
      baBest = baN
      for baK = 0 to baN - 1
        zwX(baK) = bwX(baK)
        zwY(baK) = bwY(baK)
      next baK
      zwN = baN
    end if
  next baAt
  ' Claim the wall tiles that are free, or in the lane kept for the enemy.
  baK2 = 0
  for baK = 0 to zwN - 1
    baT2 = zwY(baK) * mapW + zwX(baK)
    baCore = 0
    if zwX(baK) - cx <= coreHi and cx - zwX(baK) <= coreLo and zwY(baK) - cy <= coreHi and cy - zwY(baK) <= coreLo then baCore = 1
    spawnSafe(zwX(baK), zwY(baK), dropZone + 3)
    if baCore = 0 and gSafe = 1 and (tUsed(baT2) = 0 or tLane(baT2) = 1) then
      tUsed(baT2) = 1
      tLane(baT2) = 0
      zwX(baK2) = zwX(baK)
      zwY(baK2) = zwY(baK)
      baK2 = baK2 + 1
    end if
  next baK
  zwN = baK2
end sub

' Picks the copper spine best placed to feed the kill zone (most drills for
' the distance) into zoneSpine, turned to flow toward the feeder.
sub chooseZoneSpine()
  zoneSpine = -1
  if feedX < 0 then exit sub
  czBest = 999999
  for czS = 0 to spineN - 1
    if spKind(czS) = 1 and spDrillLen(czS) >= 2 then
      for czEnd = 0 to 1
        czI = spTileStart(czS)
        if czEnd = 1 then czI = czI + spTileLen(czS) - 1
        czD = stX(czI) - feedX
        if czD < 0 then czD = -czD
        czE = stY(czI) - feedY
        if czE < 0 then czE = -czE
        czScore = czD + czE - 8 * spDrillLen(czS)
        if czScore < czBest then
          czBest = czScore
          zoneSpine = czS
          zoneEnd = czEnd
        end if
      next czEnd
    end if
  next czS
  if zoneSpine < 0 then exit sub
  if zoneEnd = 0 then
    ' Its start is nearer the feeder: flow that way.
    czA = spTileStart(zoneSpine)
    czB = czA + spTileLen(zoneSpine) - 1
    while czA < czB
      czE = stX(czA)
      stX(czA) = stX(czB)
      stX(czB) = czE
      czE = stY(czA)
      stY(czA) = stY(czB)
      stY(czB) = czE
      czA = czA + 1
      czB = czB - 1
    wend
  end if
end sub

' The kill zone's own line, laid after every core trunk: its spine's belt
' runs to the feeder's entry, hopping trunks with junctions, and its plan
' holds the feeder and its Duos, the belts and then the drills.
sub zoneRoute()
  if zoneSpine < 0 then exit sub
  zrA = spTileStart(zoneSpine)
  zrLen = spTileLen(zoneSpine)
  zrEx = stX(zrA + zrLen - 1)
  zrEy = stY(zrA + zrLen - 1)
  ' Breadth-first over free tiles; dCost holds the trunk belt hopped to
  ' reach a tile, or -1.
  searchId = searchId + 1
  zrHead = 0
  zrTail = 0
  for zrD = 0 to 3
    isFree(zrEx + dirX(zrD), zrEy + dirY(zrD))
    if gFree = 1 then
      zrT = (zrEy + dirY(zrD)) * mapW + zrEx + dirX(zrD)
      if dStamp(zrT) <> searchId then
        dStamp(zrT) = searchId
        dPrev(zrT) = -1
        dCost(zrT) = -1
        qBuf(zrTail) = zrT
        zrTail = zrTail + 1
      end if
    end if
  next zrD
  zrGoal = -1
  do while zrHead < zrTail
    zrT = qBuf(zrHead)
    zrHead = zrHead + 1
    zrX = zrT mod mapW
    zrY = zrT \ mapW
    zrDx = zrX - feedX
    zrDy = zrY - feedY
    if zrDx * zrDx + zrDy * zrDy = 1 and (zrX <> frontX or zrY <> frontY) then
      zrGoal = zrT
      exit do
    end if
    for zrD = 0 to 3
      zrNx = zrX + dirX(zrD)
      zrNy = zrY + dirY(zrD)
      isFree(zrNx, zrNy)
      if gFree = 1 then
        zrN = zrNy * mapW + zrNx
        if dStamp(zrN) <> searchId then
          dStamp(zrN) = searchId
          dPrev(zrN) = zrT
          dCost(zrN) = -1
          qBuf(zrTail) = zrN
          zrTail = zrTail + 1
        end if
      elseif zrNx >= 0 and zrNy >= 0 and zrNx < mapW and zrNy < mapH then
        zrB = zrNy * mapW + zrNx
        if tCross(zrB) = 1 and tFlow(zrB) >= 0 then
          if tFlow(zrB) mod 2 <> zrD mod 2 then
            zrFx = zrNx + dirX(zrD)
            zrFy = zrNy + dirY(zrD)
            isFree(zrFx, zrFy)
            if gFree = 1 then
              zrN = zrFy * mapW + zrFx
              if dStamp(zrN) <> searchId then
                dStamp(zrN) = searchId
                dPrev(zrN) = zrT
                dCost(zrN) = zrB
                qBuf(zrTail) = zrN
                zrTail = zrTail + 1
              end if
            end if
          end if
        end if
      end if
    next zrD
  loop
  if zrGoal < 0 then
    zoneSpine = -1
    exit sub
  end if
  ' The line: the spine's tiles, then the route (hopped belts included).
  lnN = 0
  for zrI = zrA to zrA + zrLen - 1
    lnX(lnN) = stX(zrI)
    lnY(lnN) = stY(zrI)
    lbHop(lnN) = 0
    lnN = lnN + 1
  next zrI
  zrRoute = 0
  zrT = zrGoal
  do while zrT >= 0
    rtX(zrRoute) = zrT mod mapW
    rtY(zrRoute) = zrT \ mapW
    rcT(zrRoute) = 0
    zrRoute = zrRoute + 1
    if dCost(zrT) >= 0 then
      rtX(zrRoute) = dCost(zrT) mod mapW
      rtY(zrRoute) = dCost(zrT) \ mapW
      rcT(zrRoute) = 1
      zrRoute = zrRoute + 1
    end if
    zrT = dPrev(zrT)
  loop
  for zrI = zrRoute - 1 to 0 step -1
    lnX(lnN) = rtX(zrI)
    lnY(lnN) = rtY(zrI)
    lbHop(lnN) = rcT(zrI)
    lnN = lnN + 1
  next zrI
  plStart(planN) = orderN
  for zrI = 0 to fdN - 1
    poKind(orderN) = fdKind(zrI)
    poX(orderN) = fdX(zrI)
    poY(orderN) = fdY(zrI)
    poRot(orderN) = fdRot(zrI)
    orderN = orderN + 1
  next zrI
  ' Belts from the feeder back to the spine.
  for zrI = lnN - 1 to 0 step -1
    zrT = lnY(zrI) * mapW + lnX(zrI)
    if lbHop(zrI) = 1 then
      ' Both lines pass straight through a junction here.
      poKind(tRef(zrT)) = 4
      tCross(zrT) = 0
      tFlow(zrT) = -2
      poKind(orderN) = 4
      poRot(orderN) = 0
    else
      if zrI + 1 < lnN then
        rotationTo(lnX(zrI), lnY(zrI), lnX(zrI + 1), lnY(zrI + 1))
      else
        rotationTo(lnX(zrI), lnY(zrI), feedX, feedY)
      end if
      tUsed(zrT) = 1
      poKind(orderN) = 0
      poRot(orderN) = gRot
    end if
    poX(orderN) = lnX(zrI)
    poY(orderN) = lnY(zrI)
    orderN = orderN + 1
  next zrI
  for zrI = spDrillStart(zoneSpine) to spDrillStart(zoneSpine) + spDrillLen(zoneSpine) - 1
    poKind(orderN) = 1
    poX(orderN) = sdX(zrI)
    poY(orderN) = sdY(zrI)
    poRot(orderN) = 0
    orderN = orderN + 1
  next zrI
  plLen(planN) = orderN - plStart(planN)
  plCost(planN) = 0
  plKind(planN) = 11
  plTrunk(planN) = 0
  plJoin(planN) = -1
  planN = planN + 1
end sub

' Adds an order to a plan's extras, built after its own orders.
sub addExtra(aePlan, aeKind, aeX, aeY, aeRot)
  exPlan(extraN) = aePlan
  exKind(extraN) = aeKind
  exX(extraN) = aeX
  exY(extraN) = aeY
  exRot(extraN) = aeRot
  extraN = extraN + 1
end sub

' Sets gFits to whether a size x size block anchored at a tile has room.
sub fits(fbX, fbY, fbSize)
  gFits = 1
  for fbJ = 0 to fbSize - 1
    for fbI = 0 to fbSize - 1
      isFree(fbX + fbI, fbY + fbJ)
      if gFree = 0 then gFits = 0
    next fbI
  next fbJ
end sub

' Sets gUnder to the ore tiles under a size x size block.
sub oreUnder(ouX, ouY, ouSize)
  gUnder = 0
  for ouJ = 0 to ouSize - 1
    for ouI = 0 to ouSize - 1
      if tRes((ouY + ouJ) * mapW + ouX + ouI) > 0 then gUnder = gUnder + 1
    next ouI
  next ouJ
end sub

' Claims a size x size block's tiles.
sub claim(clX, clY, clSize)
  for clJ = 0 to clSize - 1
    for clI = 0 to clSize - 1
      tUsed((clY + clJ) * mapW + clX + clI) = 1
    next clI
  next clJ
end sub

' Tech: the first coal line gets a graphite press touching one of its
' drills and its belt (or taking a drill's place), so graphite rides the
' line to the core. When the objectives ask for power, a combustion
' generator on a drill, a power node, a battery and an Arc follow, and
' that line builds first.
sub techCell()
  tcPlan = -1
  for tcP = 0 to planN - 1
    if plKind(tcP) = 3 then
      if tcPlan < 0 then
        tcPlan = tcP
      elseif plCost(tcP) < plCost(tcPlan) then
        tcPlan = tcP
      end if
    end if
  next tcP
  if tcPlan < 0 then exit sub
  tcA = plStart(tcPlan)
  tcB = tcA + plLen(tcPlan) - 1
  ' The press: touching a drill and a belt, or a free tile from a belt.
  tcPress = -1
  tcLink = -1
  tcBest = 999999
  for tcD = tcA to tcB
    if poKind(tcD) = 1 then
      for tcPy = poY(tcD) - 2 to poY(tcD) + 2
        for tcPx = poX(tcD) - 2 to poX(tcD) + 2
          touches(tcPx, tcPy, 2, poX(tcD), poY(tcD), 2)
          if gTouch = 1 then
            fits(tcPx, tcPy, 2)
            if gFits = 1 then
              tcBelted = 0
              tcLx = -1
              for tcE = tcA to tcB
                if poKind(tcE) = 0 then
                  touches(tcPx, tcPy, 2, poX(tcE), poY(tcE), 1)
                  if gTouch = 1 then tcBelted = 1
                end if
              next tcE
              if tcBelted = 0 then
                for tcCy = tcPy - 1 to tcPy + 2
                  for tcCx = tcPx - 1 to tcPx + 2
                    if tcLx < 0 then
                      touches(tcPx, tcPy, 2, tcCx, tcCy, 1)
                      if gTouch = 1 then
                        isFree(tcCx, tcCy)
                        if gFree = 1 then
                          for tcE = tcA to tcB
                            if tcLx < 0 and poKind(tcE) = 0 then
                              touches(tcCx, tcCy, 1, poX(tcE), poY(tcE), 1)
                              if gTouch = 1 then
                                tcLx = tcCx
                                tcLy = tcCy
                                rotationTo(tcCx, tcCy, poX(tcE), poY(tcE))
                                tcLr = gRot
                              end if
                            end if
                          next tcE
                        end if
                      end if
                    end if
                  next tcCx
                next tcCy
              end if
              if tcBelted = 1 or tcLx >= 0 then
                oreUnder(tcPx, tcPy, 2)
                tcDx = tcPx - cx
                if tcDx < 0 then tcDx = -tcDx
                tcDy = tcPy - cy
                if tcDy < 0 then tcDy = -tcDy
                tcScore = gUnder * 100 + tcDx + tcDy
                if tcBelted = 0 then tcScore = tcScore + 5
                if tcScore < tcBest then
                  tcBest = tcScore
                  tcPress = 1
                  tcX = tcPx
                  tcY = tcPy
                  tcLink = -1
                  if tcBelted = 0 then
                    tcLink = 1
                    tcLinkX = tcLx
                    tcLinkY = tcLy
                    tcLinkR = tcLr
                  end if
                end if
              end if
            end if
          end if
        next tcPx
      next tcPy
    end if
  next tcD
  if tcPress >= 0 then
    claim(tcX, tcY, 2)
    if tcLink >= 0 then claim(tcLinkX, tcLinkY, 1)
  else
    ' A packed field: the press takes the place of the drill with the least
    ' ore among those with a drill beside them, which feed it.
    tcBest = 999999
    for tcD = tcA to tcB
      if poKind(tcD) = 1 then
        tcFed = 0
        for tcE = tcA to tcB
          if tcE <> tcD and poKind(tcE) = 1 then
            touches(poX(tcD), poY(tcD), 2, poX(tcE), poY(tcE), 2)
            if gTouch = 1 then tcFed = 1
          end if
        next tcE
        if tcFed = 1 then
          oreUnder(poX(tcD), poY(tcD), 2)
          tcDx = poX(tcD) - cx
          if tcDx < 0 then tcDx = -tcDx
          tcDy = poY(tcD) - cy
          if tcDy < 0 then tcDy = -tcDy
          tcScore = gUnder * 100 + tcDx + tcDy
          if tcScore < tcBest then
            tcBest = tcScore
            tcPress = tcD
          end if
        end if
      end if
    next tcD
    if tcPress < 0 then exit sub
    tcX = poX(tcPress)
    tcY = poY(tcPress)
    poKind(tcPress) = -1
  end if
  if tcLink >= 0 then addExtra(tcPlan, 0, tcLinkX, tcLinkY, tcLinkR)
  addExtra(tcPlan, 5, tcX, tcY, 0)
  if powerWanted = 1 then
    ' The generator: an open tile touching a drill, else a drill's corner.
    tcGx = -1
    tcBest = 999999
    for tcD = tcA to tcB
      if poKind(tcD) = 1 then
        for tcCy = poY(tcD) - 1 to poY(tcD) + 2
          for tcCx = poX(tcD) - 1 to poX(tcD) + 2
            touches(tcCx, tcCy, 1, poX(tcD), poY(tcD), 2)
            if gTouch = 1 then
              isFree(tcCx, tcCy)
              if gFree = 1 then
                oreUnder(tcCx, tcCy, 1)
                tcDx = tcCx - cx
                if tcDx < 0 then tcDx = -tcDx
                tcDy = tcCy - cy
                if tcDy < 0 then tcDy = -tcDy
                if gUnder * 100 + tcDx + tcDy < tcBest then
                  tcBest = gUnder * 100 + tcDx + tcDy
                  tcGx = tcCx
                  tcGy = tcCy
                end if
              end if
            end if
          next tcCx
        next tcCy
      end if
    next tcD
    if tcGx < 0 then
      for tcD = tcA to tcB
        if tcGx < 0 and poKind(tcD) = 1 then
          for tcE = tcA to tcB
            if tcGx < 0 and tcE <> tcD and poKind(tcE) = 1 then
              touches(poX(tcD), poY(tcD), 2, poX(tcE), poY(tcE), 2)
              if gTouch = 1 then
                for tcK = 0 to 3
                  tcCx = poX(tcD) + tcK mod 2
                  tcCy = poY(tcD) + tcK \ 2
                  if tcGx < 0 then
                    touches(tcCx, tcCy, 1, poX(tcE), poY(tcE), 2)
                    if gTouch = 1 then
                      tcGx = tcCx
                      tcGy = tcCy
                      poKind(tcD) = -1
                    end if
                  end if
                next tcK
              end if
            end if
          next tcE
        end if
      next tcD
    end if
    if tcGx >= 0 then
      tUsed(tcGy * mapW + tcGx) = 1
      addExtra(tcPlan, 6, tcGx, tcGy, 0)
      ' Node within four tiles of the generator, battery and Arc within
      ' three of the node; the Arc leans toward the enemy's path.
      spotNear(tcGx, tcGy, 4, 0)
      if gSpotX >= 0 then
        tcNx = gSpotX
        tcNy = gSpotY
        tUsed(tcNy * mapW + tcNx) = 1
        addExtra(tcPlan, 7, tcNx, tcNy, 0)
        spotNear(tcNx, tcNy, 3, 0)
        if gSpotX >= 0 then
          tUsed(gSpotY * mapW + gSpotX) = 1
          addExtra(tcPlan, 8, gSpotX, gSpotY, 0)
        end if
        spotNear(tcNx, tcNy, 3, 1)
        if gSpotX >= 0 then
          tUsed(gSpotY * mapW + gSpotX) = 1
          addExtra(tcPlan, 9, gSpotX, gSpotY, 0)
        end if
      end if
    end if
  end if
  if pressWanted = 1 then
    plCost(tcPlan) = -1
  else
    plKind(tcPlan) = 10
  end if
end sub

' The best open tile within reach of a tile into gSpotX and gSpotY (-1 when
' none): off ore, then near it, then (when toward is set) near the enemy.
sub spotNear(snX, snY, snReach, snToward)
  gSpotX = -1
  snBest = 999999
  for snY2 = snY - snReach to snY + snReach
    for snX2 = snX - snReach to snX + snReach
      if snX2 <> snX or snY2 <> snY then
        isFree(snX2, snY2)
        if gFree = 1 then
          oreUnder(snX2, snY2, 1)
          snD = snX2 - snX
          if snD < 0 then snD = -snD
          snE = snY2 - snY
          if snE < 0 then snE = -snE
          snScore = gUnder * 1000 + snD + snE
          if snToward = 1 then snScore = snScore + tNear(snY2 * mapW + snX2) * 10
          if snScore < snBest then
            snBest = snScore
            gSpotX = snX2
            gSpotY = snY2
          end if
        end if
      end if
    next snX2
  next snY2
end sub

' Guards: copper fields near the enemy's path get up to three Duos on their
' outer edge, each touching a copper drill (which loads it); copper trunks
' there get a router every sixteen belts with a Duo beside it that the
' passing copper keeps loaded.
sub corridorGuards()
  for cgP = 0 to planN - 1
    if plKind(cgP) = 1 then
      cgC = 0
      for cgD = plStart(cgP) to plStart(cgP) + plLen(cgP) - 1
        if poKind(cgD) = 1 and tNear(poY(cgD) * mapW + poX(cgD)) <= 14 then
          for cgE = 0 to 7
            cgX = poX(cgD) + edgeX(cgE)
            cgY = poY(cgD) + edgeY(cgE)
            isFree(cgX, cgY)
            if gFree = 1 then
              if tRes(cgY * mapW + cgX) = 0 then
                cdKey(cgC) = tNear(cgY * mapW + cgX)
                cdX(cgC) = cgX
                cdY(cgC) = cgY
                cgC = cgC + 1
              end if
            end if
          next cgE
        end if
      next cgD
      sortCandidates(cgC)
      cgN = 0
      for cgK = 0 to cgC - 1
        if cgN < 3 then
          isFree(cdX(cgK), cdY(cgK))
          cgSpaced = gFree
          for cgJ = 0 to cgN - 1
            cgDx = cgX2(cgJ) - cdX(cgK)
            if cgDx < 0 then cgDx = -cgDx
            cgDy = cgY2(cgJ) - cdY(cgK)
            if cgDy < 0 then cgDy = -cgDy
            if cgDx < 4 and cgDy < 4 then cgSpaced = 0
          next cgJ
          if cgSpaced = 1 then
            tUsed(cdY(cgK) * mapW + cdX(cgK)) = 1
            cgX2(cgN) = cdX(cgK)
            cgY2(cgN) = cdY(cgK)
            cgN = cgN + 1
            addExtra(cgP, 2, cdX(cgK), cdY(cgK), 0)
          end if
        end if
      next cgK
      cgCount = 0
      for cgI = plStart(cgP) to plStart(cgP) + plTrunk(cgP) - 1
        if poKind(cgI) = 0 then
          cgDx = poX(cgI) - cx
          if cgDx < 0 then cgDx = -cgDx
          cgDy = poY(cgI) - cy
          if cgDy < 0 then cgDy = -cgDy
          if tNear(poY(cgI) * mapW + poX(cgI)) <= 14 and (cgDx > 12 or cgDy > 12) then
            cgCount = cgCount + 1
            if cgCount mod 16 = 8 then
              cgDone = 0
              for cgSide = 0 to 1
                cgSx = -dirY(poRot(cgI))
                cgSy = dirX(poRot(cgI))
                if cgSide = 1 then
                  cgSx = -cgSx
                  cgSy = -cgSy
                end if
                if cgDone = 0 then
                  isFree(poX(cgI) + cgSx, poY(cgI) + cgSy)
                  if gFree = 1 then
                    if tRes((poY(cgI) + cgSy) * mapW + poX(cgI) + cgSx) = 0 then
                      tUsed((poY(cgI) + cgSy) * mapW + poX(cgI) + cgSx) = 1
                      poKind(cgI) = 3
                      addExtra(cgP, 2, poX(cgI) + cgSx, poY(cgI) + cgSy, 0)
                      cgDone = 1
                    end if
                  end if
                end if
              next cgSide
            end if
          end if
        end if
      next cgI
    end if
  next cgP
end sub

' Home defenses on the enemy's approach: a ring of up to eight Duos five to
' nine tiles out, then the blocks the objectives ask for (copper walls in a
' row ahead of the ring, a Scatter inside it).
sub homeDefense()
  hdLx = apX - cx
  hdLy = apY - cy
  isqrt(hdLx * hdLx + hdLy * hdLy)
  hdLen = gRoot
  if hdLen < 1 then hdLen = 1
  duoN = 0
  for hdReach = 5 to 9
    for hdS = 0 to 6
      if duoN < 8 then
        hdSide = sideList(hdS)
        hdX = cx + (hdLx * hdReach - hdLy * hdSide) \ hdLen
        hdY = cy + (hdLy * hdReach + hdLx * hdSide) \ hdLen
        isFree(hdX, hdY)
        inArea(hdX, hdY)
        if gFree = 1 and gIn = 1 then
          if tRes(hdY * mapW + hdX) = 0 then
            tUsed(hdY * mapW + hdX) = 1
            duoX(duoN) = hdX
            duoY(duoN) = hdY
            duoN = duoN + 1
          end if
        end if
      end if
    next hdS
  next hdReach
  askN = 0
  for hdKind = 0 to 1
    hdWant = wantWalls
    hdSize = 1
    hdFrom = 11
    hdTo = 14
    hdOrder = 10
    if hdKind = 1 then
      hdWant = wantScatter
      hdSize = 2
      hdFrom = 3
      hdTo = 9
      hdOrder = 11
    end if
    hdPlaced = 0
    for hdReach = hdFrom to hdTo
      for hdS = 0 to 12
        if hdPlaced < hdWant then
          hdSide = sideList2(hdS)
          hdX = cx + (hdLx * hdReach - hdLy * hdSide) \ hdLen
          hdY = cy + (hdLy * hdReach + hdLx * hdSide) \ hdLen
          hdOk = 1
          for hdJ = 0 to hdSize - 1
            for hdI = 0 to hdSize - 1
              isFree(hdX + hdI, hdY + hdJ)
              inArea(hdX + hdI, hdY + hdJ)
              if gFree = 0 or gIn = 0 then
                hdOk = 0
              elseif tRes((hdY + hdJ) * mapW + hdX + hdI) > 0 then
                hdOk = 0
              end if
            next hdI
          next hdJ
          if hdOk = 1 then
            claim(hdX, hdY, hdSize)
            askKind(askN) = hdOrder
            askX(askN) = hdX
            askY(askN) = hdY
            askN = askN + 1
            hdPlaced = hdPlaced + 1
          end if
        end if
      next hdS
    next hdReach
  next hdKind
end sub

' Appends one order to the bot's list, packed: ((kind * 4 + rotation) *
' 512 + x offset + 256) * 512 + y offset + 256, offsets from the core.
sub emit(emKind, emX, emY, emRot)
  if orderCount > 11999 then exit sub
  orderKind(orderCount) = ((emKind * 4 + emRot) * 512 + emX - cx + 256) * 512 + emY - cy + 256
  orderCount = orderCount + 1
end sub

' Orders the plans (see below) and writes the bot's order list; each line
' opens with a header naming the line it feeds. Home Duos, objective
' blocks, the forward guard and barrier walls go in between.
sub writeOrders()
  ' Each plan's parent (the plan owning the belt it joins) and its drills.
  for woP = 0 to planN - 1
    plParent(woP) = -1
    if plJoin(woP) >= 0 then
      woRef = tRef(plJoin(woP))
      for woQ = 0 to planN - 1
        if woRef >= plStart(woQ) and woRef < plStart(woQ) + plLen(woQ) then plParent(woP) = woQ
      next woQ
    end if
    plDrills(woP) = 0
    for woE = plStart(woP) to plStart(woP) + plLen(woP) - 1
      if poKind(woE) = 1 then plDrills(woP) = plDrills(woP) + 1
    next woE
    plQueued(woP) = 0
    plLineNo(woP) = -1
  next woP
  ' Greedy order: each time, the line whose copper (belts at one, drills at
  ' twelve), with that of the lines it feeds not yet queued, costs least per
  ' drill they bring, weighted by how useful its ore is: copper, the
  ' currency, at par; lead and coal at twice (lead at par when objectives
  ' ask for it); scrap at four times. A line the objectives ask for goes
  ' first. Its unqueued parents go in ahead of it.
  seqN = 0
  do while seqN < planN
    woBest = -1
    woBestKey = 2147483647
    for woP = 0 to planN - 1
      if plQueued(woP) = 0 then
        woCopper = 0
        woDrills = 0
        woQ = woP
        woDepth = 0
        do while woQ >= 0 and woDepth <= planN
          if plQueued(woQ) = 1 then exit do
          woCopper = woCopper + plLen(woQ) + 11 * plDrills(woQ)
          woDrills = woDrills + plDrills(woQ)
          woQ = plParent(woQ)
          woDepth = woDepth + 1
        loop
        if woDrills < 1 then woDrills = 1
        woWeight = 1
        if plKind(woP) = 2 and wantLead = 0 then woWeight = 2
        if plKind(woP) = 3 or plKind(woP) = 10 then woWeight = 2
        if plKind(woP) = 4 then woWeight = 4
        woKey = (woCopper * 100 \ woDrills) * woWeight
        if plCost(woP) < 0 then woKey = -1
        if woKey < woBestKey then
          woBestKey = woKey
          woBest = woP
        end if
      end if
    next woP
    if woBest < 0 then exit do
    woDepth = 0
    do while plQueued(woBest) = 0 and woDepth <= planN
      ' Walk up to the highest parent not yet queued.
      woTop = woBest
      do while plParent(woTop) >= 0
        if plQueued(plParent(woTop)) = 1 then exit do
        woTop = plParent(woTop)
      loop
      plQueued(woTop) = 1
      seqList(seqN) = woTop
      seqN = seqN + 1
      woDepth = woDepth + 1
    loop
  loop
  orderCount = 0
  for woI = 0 to duoN - 1
    if woI < 2 then emit(2, duoX(woI), duoY(woI), 0)
  next woI
  woKept = 0
  for woI = 0 to seqN - 1
    woP = seqList(woI)
    woParentLine = -1
    if plParent(woP) >= 0 then woParentLine = plLineNo(plParent(woP))
    woSkip = 0
    if plParent(woP) >= 0 and woParentLine < 0 then woSkip = 1
    if woKept >= 255 or orderCount + plLen(woP) + 64 > 11999 then woSkip = 1
    if woSkip = 0 then
      plLineNo(woP) = woKept
      lineOre(woKept) = plKind(woP)
      if plCost(woP) < 0 then lineOre(woKept) = 0
      emit(12, cx + woKept, cy + woParentLine + 1, 0)
      for woE = plStart(woP) to plStart(woP) + plLen(woP) - 1
        if poKind(woE) >= 0 then emit(poKind(woE), poX(woE), poY(woE), poRot(woE))
      next woE
      for woE = 0 to extraN - 1
        if exPlan(woE) = woP then emit(exKind(woE), exX(woE), exY(woE), exRot(woE))
      next woE
      woKept = woKept + 1
      if woKept = 2 then writeAsked()
      if woKept = 3 then writeFront()
    end if
  next woI
  if woKept < 2 then writeAsked()
  if woKept < 3 then writeFront()
  linesKept = woKept
end sub

' The objectives' blocks.
sub writeAsked()
  for waI = 0 to askN - 1
    emit(askKind(waI), askX(waI), askY(waI), 0)
  next waI
end sub

' The rest of the home ring, the forward guard and the barrier walls.
sub writeFront()
  for wfI = 2 to duoN - 1
    emit(2, duoX(wfI), duoY(wfI), 0)
  next wfI
  for wfI = 0 to fwN - 1
    emit(fwKind(wfI), fwX(wfI), fwY(wfI), 0)
  next wfI
  for wfI = 0 to zwN - 1
    emit(10, zwX(wfI), zwY(wfI), 0)
  next wfI
end sub

' Plans the whole base from the sector, once, at the first decision.
sub planBase()
  readMap()
  readObjectives()
  findPath()
  findApproach()
  findCorridor()
  postX = -1
  feedX = -1
  zoneStep = -1
  fwN = 0
  zwN = 0
  forwardGuard()
  if zoneStep < 0 and useKillZone = 1 then killZone()
  if useWalls = 1 then barrier(zoneStep)
  findPatches()
  for pbI = 0 to patchN - 1
    pbP = patOrder(pbI)
    layoutPatch(patKind(pbP), patX0(pbP), patY0(pbP), patX1(pbP), patY1(pbP))
  next pbI
  orderSpines()
  chooseZoneSpine()
  routeSpines()
  zoneRoute()
  techCell()
  corePresses()
  ' Guards may stand in the lane kept clear for the enemy.
  for pbT = 0 to mapW * mapH - 1
    if tLane(pbT) = 1 and tFlow(pbT) = -1 then tUsed(pbT) = 0
  next pbT
  corridorGuards()
  homeDefense()
  writeOrders()
  postDx = 9999
  postDy = 9999
  if postX >= 0 then
    postDx = postX - cx
    postDy = postY - cy
  end if
end sub

' Reads the sector's wave groups and the stats of their units.
sub readWaves()
  wgN = waveGroupCount()
  if wgN > 63 then wgN = 63
  for rwI = 0 to wgN - 1
    wgBegin(rwI) = waveGroup(rwI, 1)
    wgEnd(rwI) = waveGroup(rwI, 2)
    wgAmount(rwI) = waveGroup(rwI, 3)
    wgScaling(rwI) = waveGroup(rwI, 4)
    wgMax(rwI) = waveGroup(rwI, 5)
    wgShields(rwI) = waveGroup(rwI, 6)
    wgShieldScaling(rwI) = waveGroup(rwI, 7)
    wgSpacing(rwI) = waveGroup(rwI, 9)
    if wgSpacing(rwI) < 1 then wgSpacing(rwI) = 1
    rwType = waveGroup(rwI, 0)
    wgHealth(rwI) = unitStat(rwType, 0)
    wgArmor(rwI) = unitStat(rwType, 1)
  next rwI
end sub

' Sets threatDuos to the Duos that kill wave index wtWave (the engine's
' count from zero) in about eight seconds (Duos stand spread out, and
' legged units walk over walls): each group's units (as the
' engine spawns them, at every spawn) times their health and shields,
' over what a Duo deals through their armor each second (three copper
' shots of 9, or 2.4 graphite shots of 18; armor takes its value off each
' shot, down to a tenth).
sub waveThreat(wtWave)
  threatDuos = 0
  wtSum = 0
  for wtI = 0 to wgN - 1
    if wtWave >= wgBegin(wtI) and wtWave <= wgEnd(wtI) then
      if (wtWave - wgBegin(wtI)) mod wgSpacing(wtI) = 0 then
        wtCount = wgAmount(wtI)
        if wgScaling(wtI) > 0 and wgScaling(wtI) < 100000 then
          wtCount = wgAmount(wtI) + (wtWave - wgBegin(wtI)) * 100 \ wgScaling(wtI)
        end if
        if wtCount > wgMax(wtI) then wtCount = wgMax(wtI)
        wtCount = wtCount * spawnN
        if spawnN < 1 then wtCount = wtCount + wtCount
        wtHealth = wgHealth(wtI) + wgShields(wtI) + wgShieldScaling(wtI) * (wtWave - wgBegin(wtI))
        if graphiteAmmo = 1 then
          wtShot = 18 - wgArmor(wtI)
          if wtShot < 2 then wtShot = 2
          wtDps = wtShot * 24 \ 10
        else
          wtShot = 9 - wgArmor(wtI)
          if wtShot < 1 then wtShot = 1
          wtDps = wtShot * 3
        end if
        wtSum = wtSum + wtCount * wtHealth \ wtDps
      end if
    end if
  next wtI
  threatDuos = wtSum \ 8 + 1
end sub

' Graphite presses near the core, up to three: the flyer fills them with
' coal from the core and they hand graphite (Duo shots that go through
' armor) to the core or to a belt beside them that runs there, whose tile
' goes in cpBx and cpBy (-1 for the core). Touching the core comes first,
' then nearer the core, then farther from the enemy's approach.
sub corePresses()
  cpN = 0
  cpCx = cx - (coreSize - 1) \ 2
  cpCy = cy - (coreSize - 1) \ 2
  for cpK = 0 to 2
    cpBest = 999999999
    for cpPy = cy - 8 to cy + 8
      for cpPx = cx - 8 to cx + 8
        fits(cpPx, cpPy, 2)
        if gFits = 1 then
          cpScore = -1
          touches(cpPx, cpPy, 2, cpCx, cpCy, coreSize)
          if gTouch = 1 then
            cpScore = 0
            cpSx = -1
            cpSy = -1
          end if
          ' A belt beside it must take the graphite from the side or the
          ' back; a belt or junction that would push into it rules it out.
          cpBad = 0
          for cpE = 0 to 7
            cpNx = cpPx + edgeX(cpE)
            cpNy = cpPy + edgeY(cpE)
            if cpNx >= 0 and cpNy >= 0 and cpNx < mapW and cpNy < mapH then
              cpT = cpNy * mapW + cpNx
              if tFlow(cpT) = -2 then cpBad = 1
              if tFlow(cpT) >= 0 then
                cpFx = cpNx + dirX(tFlow(cpT)) - cpPx
                cpFy = cpNy + dirY(tFlow(cpT)) - cpPy
                if cpFx >= 0 and cpFx <= 1 and cpFy >= 0 and cpFy <= 1 then
                  cpBad = 1
                elseif cpScore < 0 then
                  cpDx = cpPx - cx
                  if cpDx < 0 then cpDx = -cpDx
                  cpDy = cpPy - cy
                  if cpDy < 0 then cpDy = -cpDy
                  cpScore = (cpDx + cpDy) * 1000
                  cpSx = cpNx
                  cpSy = cpNy
                end if
              end if
            end if
          next cpE
          if cpBad = 0 and cpScore >= 0 then
            cpDx = cpPx - apX
            cpDy = cpPy - apY
            cpDist = cpDx * cpDx + cpDy * cpDy
            if cpDist > 999 then cpDist = 999
            cpScore = cpScore - cpDist
            if cpScore < cpBest then
              cpBest = cpScore
              cpX(cpN) = cpPx
              cpY(cpN) = cpPy
              cpBx(cpN) = cpSx
              cpBy(cpN) = cpSy
            end if
          end if
        end if
      next cpPx
    next cpPy
    if cpBest < 999999999 then
      claim(cpX(cpN), cpY(cpN), 2)
      cpN = cpN + 1
    end if
  next cpK
end sub
