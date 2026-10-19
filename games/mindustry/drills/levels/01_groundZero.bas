' Drills: one survival flyer for any campaign sector, planning as it goes.
' At its first decision it reads the sector (terrain, ruins, spawns,
' objectives), lays out the drill rows each ore patch could hold and marks
' how dangerous each tile is (near a spawn's drop zone or the enemy's
' path). Then it plans just in time: whenever an ore runs short it routes
' one new line to the core around what stands (belts from the core
' outward, then drills), safe ground first and dangerous ground last; far
' ground that keeps getting hit is given up. Presses and a mending cell go
' up by the core once coal arrives. Forts (a block of turrets wrapped in
' walls: Duos, a Scatter against bombers, Hails against armor) go up in
' front of the base toward the enemy as the waves grow, each ordered whole
' once the core can pay for it. Copper trunks near the enemy's path feed
' Duos through routers. The flyer builds, mines by hand meanwhile, keeps
' the turrets and generators fed, calls waves early when the base can take
' the next one and shoots.
dim orderKind(11999)
' The planner's maps, one cell a tile, sized for the largest sectors.
dim tRes(359999)
dim tOpen(359999)
dim tTaken(359999)
' The tile a ruin (a derelict building) on this tile stands at, else -1.
dim tRuin(359999)
dim tUsed(359999)
dim tLane(359999)
' The spine a planned tile was claimed for, else -1.
dim tSpine(359999)
dim tFlow(359999)
dim tLine(359999)
dim tCross(359999)
dim tRef(359999)
dim tNear(359999)
dim tDist(359999)
' Enemy turrets that can hit ground within twelve tiles of a tile.
dim tThreat(359999)
dim tMark(359999)
dim tOrd(359999)
dim tDanger(359999)
dim tFar(359999)
dim heat(9999)
dim farX(127)
dim farY(127)
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
dim ecX(7)
dim ecY(7)
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
dim spRouted(1999)
dim kindDrills(9)
dim kindTarget(9)
dim kindBuilt(9)
dim kindCount(9)
dim spLeft(9)
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
dim mcX(11)
' An attack sector's production cell: kind (1 generator, 3 smelter, 4
' ground factory, 6 power node, 7 additive reconstructor), place, rotation.
dim acKind(31)
dim acX(31)
dim acY(31)
dim acRot(31)
' The cell's power links: node part, then the part it lasers to.
' Items the flyer hands one cell part in a feeding.
dim feedItem(3)
dim feedAmount(3)
dim alFrom(63)
dim alTo(63)
' A march: its members' unit ids, and the way to its goal (goal first).
dim marchId(47)
dim marchX(3999)
dim marchY(3999)
dim mcY(11)
dim mcKind(11)
dim cpX(15)
dim cpY(15)
dim cpBx(15)
dim cpBy(15)
dim cpTries(15)
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
' (copper, lead, scrap, coal, and an attack sector's sand); the spots around a forward drill; the eight
' tiles touching a 2x2 drill; the side offsets home defenses try.
data dirX = 1, 0, -1, 0
data dirY = 0, 1, 0, -1
data oreOrder = 1, 2, 4, 3, 5, 6
data offX = 0, 2, -2, 0, 0, 2, -2, 2, -2
data offY = 0, 0, 0, 2, -2, 2, -2, -2, 2
data edgeX = -1, -1, 2, 2, 0, 1, 0, 1
data edgeY = 0, 1, 0, 1, -1, -1, 2, 2
data sideList = 0, 2, -2, 4, -4, 6, -6
data sideList2 = 0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6, -6
data cellKinds = 1, 2, 2, 2, 2, 2, 2, 2, 1, 1
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
  coreShard = blockId("core-shard")
  coreFoundation = blockId("core-foundation")
  coreNucleus = blockId("core-nucleus")
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
  hail = blockId("hail")
  pneumatic = blockId("pneumatic-drill")
  salvo = blockId("salvo")
  scorch = blockId("scorch")
  lancer = blockId("lancer")
  ripple = blockId("ripple")
  tiBelt = blockId("titanium-conveyor")
  beltCap = 45
  mender = blockId("mender")
  sand = itemId("sand")
  silicon = itemId("silicon")
  smelter = blockId("silicon-smelter")
  steam = blockId("steam-generator")
  factory = blockId("ground-factory")
  recon = blockId("additive-reconstructor")
  daggerType = unitTypeId("dagger")
  maceType = unitTypeId("mace")
  airFactory = blockId("air-factory")
  solar = blockId("solar-panel")
  titanium = itemId("titanium")
  crawlerType = unitTypeId("crawler")
  novaType = unitTypeId("nova")
  flareType = unitTypeId("flare")
  monoType = unitTypeId("mono")
  atraxType = unitTypeId("atrax")
  pulsarType = unitTypeId("pulsar")
  horizonType = unitTypeId("horizon")
  polyType = unitTypeId("poly")
  enterCommand = commandId("enterPayload")
  ' An attack sector (enemy cores to destroy, not waves to outlast) builds
  ' an army.
  attackMode = 0
  if sector(7) = 1 then attackMode = 1
  orderCount = 0
  ' Switches for the plan's parts.
  useKillZone = 0
  useWalls = 0
  deadEpoch = 1
  planBase()
  readWaves()
  ' Against armor from the first waves coal matters more than a belt running
  ' a little over: lines take sixty ore tiles.
  if armorEarly = 1 then beltCap = 60
  ' A fort's price: six Duos and the walls round them, a Scatter more when
  ' the waves fly.
  fortCost = 6 * 35 + 14 * 6
  if airWaves = 1 then fortCost = 85 + 6 * 35 + 16 * 6
  heatW = mapW \ 8 + 1
  print "plan: core", cx, cy, "size", coreSize, "patches", patchN, "spines", spineN, "lines", linesKept, "of", planN, "no outlet", noOutlet, "orders", orderCount, "forward", fwN, "walls", zwN, "duos", duoN, "asked", askN
  ' Orders stay packed in orderKind (written by the planner below) and
  ' unpack as the build scan reaches them: ((kind * 4 + rotation) * 512 +
  ' x offset + 256) * 512 + y offset + 256. Kinds: 0 conveyor, 1 mechanical
  ' drill, 2 Duo, 3 router, 4 junction, 5 graphite press, 6 combustion
  ' generator, 7 power node, 8 battery, 9 Arc, 10 copper wall, 11 Scatter,
  ' 12 line header (x offset: its line, y offset: the line it feeds + 1),
  ' 13 Hail.
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
      ' Not under a building or a ruin, any tile of it (blockAt sees only
      ' a building's own tile).
      if blockAt(x, y) = -1 and tTaken(y * mapW + x) = 0 then
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

' No flyer, nothing to do. Its health reads in whole points, so a flyer
' left with less than one still flies and must keep working.
if flyerX() < 0 then end
fx = flyerX()
fy = flyerY()
dx = fx - cx
dy = fy - cy
home = 0
if dx > -20 and dx < 20 and dy > -20 and dy < 20 then home = 1

' Alarm: an enemy within thirty tiles of the core calls the flyer home to
' fight beside the Duos and keep them loaded; only parts by the core go up
' then. With an enemy within twelve tiles (close) building waits.
alarm = 0
close = 0
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
      if d2 < 144 then close = 1
    end if
  end if
next i
if alarm = 1 and planCount() > 0 then
  ' Building by the core goes on mid-fight; far sites wait.
  dx = plan(0, 0) - cx
  dy = plan(0, 1) - cy
  if dx < -25 or dx > 25 or dy < -25 or dy > 25 then
    clearPlans()
    holdUntil = tick() + 120
  end if
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
if busy = 0 and close = 0 and hungry = 0 and tick() mod 6 = 0 then
  ' Thirty copper stay in the core for the Duos' ammo, and what a wanted
  ' fort saves.
  budget = stock(copper) - 30 - fortSave
  ' Against armor from the first waves, once the waves grow, two hundred
  ' copper stay in the core as salvo shells: a turret that runs dry mid-fight
  ' lets the wave through.
  if armorEarly = 1 and wave() >= 8 then budget = budget - 200
  leadBudget = stock(lead)
  graphBudget = stock(graphite)
  tiBudget = stock(titanium)
  queued = 0
  upQueued = 0
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
      if lineOre(line) = 6 and stock(titanium) >= 1500 then full = 1
      if lineOre(line) = 4 and stock(scrap) >= 200 then full = 1
      beltsMissing = 0
      if prefix = 1 then scanStart = k
    else
      id = conveyor
      cost = 1
      leadCost = 0
      graphCost = 0
      tiCost = 0
      ' With titanium to spare, belts go titanium (twice as fast): built over
      ' the copper ones, they upgrade them where they stand.
      if kind = 0 and tiBelts = 1 then
        id = tiBelt
        leadCost = 1
        tiCost = 1
      end if
      if kind = 1 then
        id = drill
        cost = 12
        ' Titanium takes a pneumatic drill, and with graphite to spare every
        ' ore gets one (half as fast again), built over the old drills. A
        ' pneumatic drill already standing stays, graphite or not.
        if lineOre(line) = 6 or (pneuDrills = 1 and graphBudget >= 160) or contentAt(ox, oy) = pneumatic then
          id = pneumatic
          cost = 18
          graphCost = 10
        end if
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
      if kind = 13 then
        id = hail
        cost = 40
      end if
      if kind = 15 then
        id = salvo
        cost = 100
        graphCost = 80
        tiCost = 50
      end if
      if kind = 16 then
        id = ripple
        cost = 150
        graphCost = 135
        tiCost = 60
      end if
      if full = 1 and (kind < 2 or kind = 3 or kind = 4 or kind = 5) then
        ' A waiting line: its belts count as missing, so what it feeds waits.
        prefix = 0
        if kind <> 1 then beltsMissing = 1
      elseif kind = 1 and (beltsMissing = 1 or feedOk = 0 or tick() < holdUntil) then
        ' Skip this drill for now; later lines and Duos still get built.
        prefix = 0
      else
        ' A ruin still standing on the spot is not ours, whatever it is.
        ruinHere = 0
        if tTaken(oy * mapW + ox) = 2 then
          k2 = tRuin(oy * mapW + ox)
          if k2 >= 0 then
            if contentAt(k2 mod mapW, k2 \ mapW) <> -1 then ruinHere = 1
          end if
          if ruinHere = 0 then dropRuin(oy * mapW + ox)
        end if
        if ((id = tiBelt and contentAt(ox, oy) = conveyor) or (id = pneumatic and contentAt(ox, oy) = drill)) and ruinHere = 0 then
          ' An old copper belt or drill still does its job: it is upgraded
          ' when titanium or graphite allows (belts only with lead to spare
          ' for the Scatters), a few per look so forts keep the flyer too.
          if upQueued < 3 and budget >= cost and leadBudget >= 400 * leadCost and tiBudget >= tiCost and graphBudget >= graphCost * 16 then
            if buildBlock(id, ox, oy, turn) = 1 then
              budget = budget - cost
              leadBudget = leadBudget - leadCost
              tiBudget = tiBudget - tiCost
              graphBudget = graphBudget - graphCost
              queued = queued + 1
              upQueued = upQueued + 1
            end if
          end if
        elseif contentAt(ox, oy) <> id or ruinHere = 1 then
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
          ' Far ground that keeps losing parts (two losses or more, twenty
          ' tiles or more from the core) is given up rather than rebuilt over
          ' and over: a fort out there could not be kept loaded, and the
          ' economy grows lines on safer ground instead. Near the core the
          ' forts cover it, and a core with a thousand copper rebuilds all.
          hold = 0
          if orderTries(k) > 0 then
            for h = 0 to 15
              if hotWeight(h) >= 2 then
                dx = hotX(h) - ox
                dy = hotY(h) - oy
                if dx > -9 and dx < 9 and dy > -9 and dy < 9 then
                  dx = hotX(h) - cx
                  dy = hotY(h) - cy
                  if (dx <= -20 or dx >= 20 or dy <= -20 or dy >= 20) and stock(copper) < 1000 then hold = 1
                end if
              end if
            next h
          end if
          ' Mid-fight only parts by the core go up; far ones wait.
          if alarm = 1 then
            dx = ox - cx
            dy = oy - cy
            if dx <= -25 or dx >= 25 or dy <= -25 or dy >= 25 then hold = 1
          end if
          if orderTries(k) < 5 and hold = 0 then
            ' Belts and drills may spend what a fort saves: lines pay for
            ' everything, the fort too.
            spend = budget
            if kind <= 1 or kind = 3 or kind = 4 then spend = budget + fortSave
            if cost > spend then
              ' Stop at the first order the core cannot pay for yet.
              stopped = 1
              if leadCost > leadBudget then needLead = 1
            elseif leadCost > leadBudget then
              ' Short only of lead: the flyer mines lead for it while copper
              ' keeps building what comes after.
              needLead = 1
            elseif graphCost > graphBudget or tiCost > tiBudget then
              ' Short of graphite or titanium: what comes after goes on.
              graphShort = 1
            else
              ' A ruin under it comes down first.
              clearRuins(id, ox, oy)
              if gRuin = 1 then
                queued = queued + 1
                orderTries(k) = orderTries(k) + 1
              elseif buildBlock(id, ox, oy, turn) = 1 then
                budget = budget - cost
                leadBudget = leadBudget - leadCost
                graphBudget = graphBudget - graphCost
                tiBudget = tiBudget - tiCost
                queued = queued + 1
                orderTries(k) = orderTries(k) + 1
              else
                orderTries(k) = orderTries(k) + 1
              end if
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

' Count the Duos that hold ammo, the empty ones near the core and the
' drills, a hundred buildings every sixth tick, so a big base stays in
' budget; the totals settle once a pass is done. Four empty Duos make the
' flyer go home and load them before it builds anything more.
if tick() mod 6 = 0 then
  if armFrom >= buildingCount() then
    armFrom = 0
    armed = arming
    arming = 0
    emptyDuos = starving
    starving = 0
    drills = drilling
    drilling = 0
    salvoBuilt = salvoing
    salvoing = 0
    rippleBuilt = rippling
    rippling = 0
    for k = 1 to 6
      kindBuilt(k) = kindCount(k)
      kindCount(k) = 0
    next k
  end if
  last = armFrom + 99
  if last > buildingCount() - 1 then last = buildingCount() - 1
  for i = armFrom to last
    if building(i, 5) = team() then
      if contentAt(building(i, 2), building(i, 3)) = salvo then salvoing = salvoing + 1
      if contentAt(building(i, 2), building(i, 3)) = ripple then rippling = rippling + 1
      if contentAt(building(i, 2), building(i, 3)) = duo then
        if building(i, 11) > 0 then
          arming = arming + 1
        else
          dx = building(i, 2) - cx
          dy = building(i, 3) - cy
          if dx > -25 and dx < 25 and dy > -25 and dy < 25 then starving = starving + 1
        end if
      end if
      dk = contentAt(building(i, 2), building(i, 3))
      if dk = drill or dk = pneumatic then
        drilling = drilling + 1
        ' Its ore: the most common under its four tiles.
        dk = tRes(building(i, 3) * mapW + building(i, 2))
        if dk = 0 then dk = tRes((building(i, 3) + 1) * mapW + building(i, 2) + 1)
        if dk >= 1 and dk <= 6 then kindCount(dk) = kindCount(dk) + 1
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
' Duos for the next wave, copper in the core and no fort waiting to be
' paid for. Otherwise the wave timer runs while the base grows. Against
' armor from the first waves every second of income counts: no early calls.
if tick() mod 30 = 18 and alarm = 0 and armed >= needDuos and armed >= 3 and tick() >= hurtUntil and stock(copper) >= 100 and fortN >= fortWant and attackMode = 0 and armorEarly = 0 then nextWave()

' Where the enemy spends its time within forty tiles of the core: a heat
' map of eight-tile cells, counted every thirtieth tick, and its hottest
' cell's center in heatX and heatY.
if tick() mod 30 = 3 then
  for i = 0 to unitCount() - 1
    if unit(i, 6) <> team() and unit(i, 5) > 0 then
      ' A logical AND rounds the fractional position to a whole tile.
      hx = unit(i, 2) and -1
      hy = unit(i, 3) and -1
      dx = hx - cx
      dy = hy - cy
      if dx > -40 and dx < 40 and dy > -40 and dy < 40 and hx >= 0 and hy >= 0 then
        h = (hy \ 8) * heatW + hx \ 8
        heat(h) = heat(h) + 1
        if heat(h) > heatBest then
          heatBest = heat(h)
          heatX = (hx \ 8) * 8 + 4
          heatY = (hy \ 8) * 8 + 4
        end if
      end if
    end if
  next i
end if

' Forts go up as the waves need them, in front of the base rather than in
' it: the first once eight drills stand, one more for every six Duos the
' next wave calls for, and one more whenever the core holds six hundred
' copper past a fort's price (twenty-four at most): copper in the core
' does not shoot.
' Each stands fourteen tiles out toward where the enemy gathers (its
' approach before any fight), the later ones fanned out to the sides and in
' rings further out (to twenty-six tiles), every fourth close in by the
' core; a spot with no room is passed
' over, and only forts placed count. Each waits until the core can pay for
' all of it (the whole fort is ordered at once). With copper to spare and
' three forts home, a forward fort holds the enemy's path near its spawn,
' where the forward guard was planned.
if tick() mod 60 = 18 and close = 0 and drills >= 8 then
  fortWant = 1 + needDuos \ 6
  if stock(copper) >= 600 + fortCost and fortN >= fortWant then fortWant = fortN + 1
  if fortWant > 24 and armorEarly = 0 then fortWant = 24
  if fortWant > 40 then fortWant = 40
  ' An attack sector spends on its army: three forts hold the base, and one
  ' more every two waves once the enemy sends them (its army needs silicon
  ' and graphite, the forts copper).
  if attackMode = 1 and fortWant > 3 + wave() \ 2 then fortWant = 3 + wave() \ 2
  ' Short of turrets for the next wave, the build list leaves the fort's
  ' copper in the core.
  fortSave = 0
  if fortN < fortWant and armed < needDuos + 2 then fortSave = fortCost
  if fortN < fortWant and stock(copper) >= fortCost + 50 and (airWaves = 0 or stock(lead) >= 60) then
    rdLx = apX - cx
    rdLy = apY - cy
    if heatBest > 0 then
      rdLx = heatX - cx
      rdLy = heatY - cy
    end if
    isqrt(rdLx * rdLx + rdLy * rdLy)
    if gRoot < 1 then gRoot = 1
    rdS = sideList(fortTry mod 7) * 3
    rdR = 14 + ((fortTry \ 7) mod 4) * 4
    ' Every fourth stands close in, seven tiles out: bombers and gunboats
    ' fire on the core itself from past the outer forts.
    if fortTry mod 4 = 3 then
      rdR = 7
      rdS = rdS \ 3
    end if
    rdX = cx + (rdLx * rdR - rdLy * rdS) \ gRoot
    rdY = cy + (rdLy * rdR + rdLx * rdS) \ gRoot
    planFort(rdX, rdY)
    fortTry = fortTry + 1
    ' After two rounds of every spot, failures count too, so a base with
    ' no room left stops trying.
    if gFort = 0 and fortTry >= 56 then fortN = fortN + 1
  elseif forwardDone = 0 and fortN >= 3 and postX >= 0 and stock(copper) >= fortCost + 600 then
    planFort(postX, postY)
    forwardDone = 1
  end if
end if
' Against armor from the first waves, with graphite and titanium banked,
' Ripples stand by the core (planRipple), one at a time once the last one
' stands, eight at most: their shells splash whole packs of maces.
if tick() mod 300 = 118 and armorEarly = 1 and rippleN < 8 and rippleBuilt >= rippleN and stock(titanium) >= 80 and stock(graphite) >= 300 and stock(copper) >= 300 then
  planRipple()
end if

' Bombers fly straight at the core, past the forts: with fliers in the
' waves, Scatters wrapped in walls stand within eight tiles of the core,
' toward the nearest spawn (air guards): two, and one more every ten waves.
if tick() mod 60 = 48 and airWaves = 1 and close = 0 and drills >= 8 and spawnN > 0 then
  if guardN < 2 + wave() \ 10 and guardTry < 40 and stock(copper) >= 85 + 12 * 6 + 50 and stock(lead) >= 60 then
    agBest = 2147483647
    for i = 0 to spawnN - 1
      dx = spawnX(i) - cx
      dy = spawnY(i) - cy
      if dx * dx + dy * dy < agBest then
        agBest = dx * dx + dy * dy
        agLx = dx
        agLy = dy
      end if
    next i
    isqrt(agBest)
    if gRoot < 1 then gRoot = 1
    rdS = sideList(guardTry mod 7) * 2
    agX = cx + (agLx * 5 - agLy * rdS) \ gRoot
    agY = cy + (agLy * 5 + agLx * rdS) \ gRoot
    pfGuard = 1
    planFort(agX, agY)
    pfGuard = 0
    guardTry = guardTry + 1
    if gFort = 1 then guardN = guardN + 1
  end if
end if
' What was placed shows up in the armed count once loaded.
if tick() mod 600 = 0 then placed = 0

' A part given up on (five tries) gets another chance every minute: a belt
' lost while the flyer was away must come back, or its whole line starves.
if tick() mod 3600 = 1800 then
  for i = 0 to orderCount - 1
    if orderTries(i) >= 5 and orderTries(i) < 1000 then orderTries(i) = 0
  next i
end if

' Titanium belts once the core holds eight hundred titanium: lines then
' carry twice as much, so new lines may join fuller ones.
if tiBelts = 0 and stock(titanium) >= 800 then
  tiBelts = 1
  beltCap = 90
  deadEpoch = deadEpoch + 1
end if
' Pneumatic drills once the core holds three hundred graphite: lines and
' new drills go half as fast again for ten graphite a drill. An attack
' sector's graphite makes maces instead.
if pneuDrills = 0 and attackMode = 0 and stock(graphite) >= 300 then pneuDrills = 1

' A spine that found no way out gets another try every minute: the lines
' laid since may have opened one (a survival sector's: an attack sector's
' spines that failed lead toward the enemy base).
if tick() mod 3600 = 2400 and attackMode = 0 then
  ' Areas found closed are looked at afresh too: parts lost or rebuilt
  ' since change the ways out.
  deadEpoch = deadEpoch + 1
  for i = 0 to spineN - 1
    if spRouted(i) = 2 then spRouted(i) = 0
  next i
  for k = 1 to 6
    spLeft(k) = 1
  next k
end if

' The economy keeps growing by need: every two seconds, once the newest
' line stands (four in five of its parts built) or waits on a full ore, the
' shortest ore gets a new line: drills pay for everything else, so they come
' before spare turrets.
if tick() mod 120 = 90 then
  lastBuilt = 0
  lastAll = 0
  for i = lastFrom to lastTo - 1
    v = orderKind(i)
    oy = cy + v - (v \ 512) * 512 - 256
    v = v \ 512
    ox = cx + v - (v \ 512) * 512 - 256
    if v \ 512 \ 4 < 12 then
      lastAll = lastAll + 1
      if blockAt(ox, oy) <> -1 then lastBuilt = lastBuilt + 1
    end if
  next i
  ' A line of an ore the core is full of waits, so it counts as standing.
  lastWaits = 0
  if linesKept > 0 then
    k = lineOre(linesKept - 1)
    if k = 2 and wantLead = 0 and stock(lead) >= 400 then lastWaits = 1
    if k = 3 and stock(coal) >= 300 then lastWaits = 1
    if k = 4 and stock(scrap) >= 200 then lastWaits = 1
    if k = 5 and stock(sand) >= 300 then lastWaits = 1
  end if
  if lastBuilt * 5 >= lastAll * 4 or lastWaits = 1 then growEconomy()
end if

' Once coal reaches the core and twelve drills stand (drills come first:
' copper spent on menders early starves the base), place the presses and
' the mending cell by it, around the belts that stand by then.
' A survival sector walls off the enemy's narrowest way in once the core
' has copper to spare.
if chokeDone = 0 and attackMode = 0 and wave() >= 3 and stock(copper) >= 800 and tick() mod 600 = 300 then
  chokeWalls()
  chokeDone = 1
end if

if cellsPlanned = 0 and stock(coal) >= 30 and drills >= 12 then
  if attackMode = 1 then attackCell()
  corePresses()
  coreCell()
  cellsPlanned = 1
end if

' With coal in the core, build the mending cell, one part every second:
' the generators, the menders, then the node, which links them as it lands
' (a part rebuilt later links to the standing node by itself).
if tick() mod 60 = 12 and stock(coal) >= 20 and stock(copper) >= 100 and stock(lead) >= 60 then
  for i = 0 to mcN - 1
    j = i + 1
    if j = mcN then j = 0
    id = mender
    if mcKind(j) = 0 then id = node
    if mcKind(j) = 1 then id = generator
    ' A spot something else has taken is passed over.
    if contentAt(mcX(j), mcY(j)) <> id and blockAt(mcX(j), mcY(j)) = -1 then
      if buildBlock(id, mcX(j), mcY(j), 0) = 1 then
        busy = 1
        exit for
      end if
    end if
  next i
end if

' An attack sector's production cell, one part every second, in plan
' order: the generators, the smelter, the nodes, the factory once the core
' holds its silicon, then the reconstructor in front of it (each links to a
' standing node as it lands).
if attackMode = 1 and acN > 0 and tick() mod 60 = 36 and stock(copper) >= 80 and stock(lead) >= 40 then
  for i = 0 to acN - 1
    id = generator
    if acKind(i) = 3 then id = smelter
    if acKind(i) = 4 then id = factory
    if acKind(i) = 6 then id = node
    if acKind(i) = 7 then id = recon
    if acKind(i) = 9 then id = airFactory
    if acKind(i) = 10 then id = solar
    if acKind(i) <> 8 and contentAt(acX(i), acY(i)) <> id then
      ok = 1
      if acKind(i) = 4 and (stock(silicon) < 80 or stock(lead) < 120) then ok = 0
      if acKind(i) = 7 and (stock(silicon) < 90 or stock(lead) < 120 or stock(copper) < 200) then ok = 0
      if acKind(i) = 10 and (stock(silicon) < 40 or stock(lead) < 40) then ok = 0
      if acKind(i) = 10 and (stock(silicon) < 40 or stock(lead) < 40) then ok = 0
      if ok = 1 and blockAt(acX(i), acY(i)) = -1 then
        if buildBlock(id, acX(i), acY(i), acRot(i)) = 1 then
          busy = 1
          exit for
        end if
      end if
    end if
  next i
end if

' The cell's power links, four a second: a planned link whose two ends
' stand and that the node's link list (configuration fields after its tag,
' as offset pairs) does not hold yet is made by configuring the node with
' the other end's place (configuring an existing link would cut it).
if attackMode = 1 and alN > 0 and tick() mod 60 = 26 then
  made = 0
  for i = 0 to alN - 1
    a = alFrom(i)
    b = alTo(i)
    if made < 4 and contentAt(acX(a), acY(a)) = node then
      partBlock(b)
      if contentAt(acX(b), acY(b)) = gPart then
        dx = acX(b) - acX(a)
        dy = acY(b) - acY(a)
        linked = 0
        for k = 1 to 19 step 2
          if configAt(acX(a), acY(a), k) = dx and configAt(acX(a), acY(a), k + 1) = dy then linked = 1
        next k
        if linked = 0 then
          configure(acX(a), acY(a), 0, acX(b) * 65536 + acY(b))
          made = made + 1
        end if
      end if
    end if
  next i
end if

' The cell by hand, every ninety ticks at home, on three ticks of their
' own (thirty-two commands a decision): coal to the generators, coal and
' sand to the smelter; then each ground factory what its unit takes
' (dagger: silicon and lead; crawler: silicon and coal; nova: silicon,
' lead and titanium); then each air factory (flare: silicon; mono: silicon
' and lead) and reconstructor (forty silicon and forty graphite an
' upgrade). Each hand goes back to the core so the next item can be taken.
if attackMode = 1 and home = 1 and acN > 0 and (tick() mod 90 = 74 or tick() mod 90 = 79 or tick() mod 90 = 82) then
  deposit(cx, cy)
  acBuilt = 0
  for i = 0 to acN - 1
    k = acKind(i)
    partBlock(i)
    if contentAt(acX(i), acY(i)) = gPart then
      acBuilt = acBuilt + 1
      feedN = 0
      if tick() mod 90 = 74 then
        if (k = 1 or k = 8) and stock(coal) >= 10 then
          feedItem(feedN) = coal
          feedAmount(feedN) = 10
          feedN = 1
        end if
        if k = 3 then
          ' Its silicon in, when it does not touch the core.
          take(acX(i), acY(i), silicon, 30)
          deposit(cx, cy)
          ' With silicon banked the coal goes to the presses: graphite is
          ' what turns daggers into maces.
          if stock(coal) >= 10 and stock(sand) >= 20 and stock(silicon) < 600 then
            feedItem(0) = coal
            feedAmount(0) = 10
            feedItem(1) = sand
            feedAmount(1) = 20
            feedN = 2
          end if
        end if
      end if
      if tick() mod 90 = 79 and k = 4 then
        if groundPlan = 0 and stock(silicon) >= 20 and stock(lead) >= 20 then
          feedItem(0) = silicon
          feedAmount(0) = 20
          feedItem(1) = lead
          feedAmount(1) = 20
          feedN = 2
        end if
        if groundPlan = 1 and stock(silicon) >= 16 and stock(coal) >= 20 then
          feedItem(0) = silicon
          feedAmount(0) = 16
          feedItem(1) = coal
          feedAmount(1) = 20
          feedN = 2
        end if
        if groundPlan = 2 and stock(silicon) >= 30 and stock(lead) >= 20 and stock(titanium) >= 20 then
          feedItem(0) = silicon
          feedAmount(0) = 30
          feedItem(1) = lead
          feedAmount(1) = 20
          feedItem(2) = titanium
          feedAmount(2) = 20
          feedN = 3
        end if
      end if
      if tick() mod 90 = 82 then
        if k = 9 and stock(silicon) >= 30 then
          feedItem(0) = silicon
          feedAmount(0) = 30
          feedN = 1
          if airPlan = 1 and stock(lead) >= 15 then
            feedItem(1) = lead
            feedAmount(1) = 15
            feedN = 2
          end if
        end if
        if k = 7 and stock(silicon) >= 60 and stock(graphite) >= 50 then
          feedItem(0) = silicon
          feedAmount(0) = 40
          feedItem(1) = graphite
          feedAmount(1) = 40
          feedN = 2
        end if
      end if
      for j = 0 to feedN - 1
        take(cx, cy, feedItem(j), feedAmount(j))
        deposit(acX(i), acY(i))
        deposit(cx, cy)
      next j
    end if
  next i
end if

' What the factories make: a unit the sector's objectives still ask for
' (its base type; the reconstructor in front of the factory upgrades it),
' the first one asked first, else daggers (maces) and flares (horizons).
if attackMode = 1 and tick() mod 300 = 33 then
  groundPlan = 0
  airPlan = 0
  wantBase = -1
  wantTitanium = 0
  for i = objectiveCount() - 1 to 0 step -1
    if objective(i, 0) = 9 and objective(i, 1) = 0 then
      t = objective(i, 2)
      ' The base type of the first wanted upgrade, for a unit to send in.
      if t = maceType then wantBase = daggerType
      if t = atraxType then wantBase = crawlerType
      if t = pulsarType then wantBase = novaType
      if t = pulsarType or t = novaType then wantTitanium = 1
      if t = horizonType then wantBase = flareType
      if t = polyType then wantBase = monoType
      if t = atraxType or t = crawlerType then groundPlan = 1
      if (t = pulsarType or t = novaType) and stock(titanium) >= 20 then groundPlan = 2
      if t = maceType or t = daggerType then groundPlan = 0
      if t = polyType or t = monoType then airPlan = 1
      if t = horizonType or t = flareType then airPlan = 0
    end if
  next i
  ' With the objectives met and the maces at their cap (eight a type), the
  ' factory makes crawlers, which come out atrax: a second eight to march.
  if wantBase < 0 then
    maceN = 0
    atraxN = 0
    for i = 0 to unitCount() - 1
      if unit(i, 6) = team() then
        if unit(i, 11) = maceType then maceN = maceN + 1
        if unit(i, 11) = atraxType or unit(i, 11) = crawlerType then atraxN = atraxN + 1
      end if
    next i
    if maceN >= 8 and atraxN < 8 then groundPlan = 1
  end if
end if

' At the unit cap a factory stops, and its units wait as they are: an idle
' base unit (not marching) is sent into a stocked reconstructor (the
' enter-payload command, then a move onto it) and comes out upgraded, one
' a reconstructor every ten seconds, the type an objective asks for first.
if attackMode = 1 and tick() mod 600 = 154 and stock(silicon) >= 60 and stock(graphite) >= 50 then
  for i = 0 to acN - 1
    if acKind(i) = 7 and contentAt(acX(i), acY(i)) = recon then
      best = -1
      bestScore = 0
      for u = 0 to unitCount() - 1
        if unit(u, 6) = team() then
          t = unit(u, 11)
          score = 0
          if t = daggerType or t = flareType or t = monoType or t = crawlerType or t = novaType then score = 1
          if t = wantBase then score = 10
          for k = 0 to marchN - 1
            if marchId(k) = unit(u, 0) then score = 0
          next k
          if unit(u, 0) = lastPick then score = 0
          if score > bestScore then
            bestScore = score
            best = u
          end if
        end if
      next u
      if best >= 0 then
        lastPick = unit(best, 0)
        unitCommand(unit(best, 0), enterCommand)
        commandMove(unit(best, 0), acX(i), acY(i), 0)
      end if
    end if
  next i
end if

' The army: the factory makes daggers (the reconstructor in front of it
' turns them into maces) and rallies them behind the core, away from the
' enemy's approach. A full army (twenty, or eight once it stops growing for
' half a minute) marches together on the nearest enemy core still
' standing: small groups die one by one in its defenses. A move order (not
' an attack on the core) lets them fight the walls and turrets on the way.
if attackMode = 1 and acN > 0 and tick() mod 60 = 54 then
  rallyX = cx - (apX - cx) \ 3
  rallyY = cy - (apY - cy) \ 3
  for i = 0 to acN - 1
    partBlock(i)
    k = acKind(i)
    if (k = 4 or k = 7 or k = 9) and contentAt(acX(i), acY(i)) = gPart then
      ' A factory switches only when its plan (configuration field one)
      ' differs: a switch starts its unit over.
      if k = 4 and configAt(acX(i), acY(i), 1) <> groundPlan then configure(acX(i), acY(i), 0, groundPlan)
      if k = 9 and configAt(acX(i), acY(i), 1) <> airPlan then configure(acX(i), acY(i), 0, airPlan)
      commandBuilding(acX(i), acY(i), rallyX, rallyY)
    end if
  next i
  goal = -1
  goalD = 2147483647
  for i = 0 to ecN - 1
    b = contentAt(ecX(i), ecY(i))
    if b = coreShard or b = coreFoundation or b = coreNucleus then
      dx = ecX(i) - cx
      dy = ecY(i) - cy
      if dx * dx + dy * dy < goalD then
        goalD = dx * dx + dy * dy
        goal = i
      end if
    end if
  next i
  if goal >= 0 then
    waiting = 0
    for i = 0 to unitCount() - 1
      if unit(i, 6) = team() and (unit(i, 11) = daggerType or unit(i, 11) = maceType or unit(i, 11) = atraxType) then
        dx = unit(i, 2) - rallyX
        dy = unit(i, 3) - rallyY
        if dx > -15 and dx < 15 and dy > -15 and dy < 15 then waiting = waiting + 1
      end if
    next i
    if waiting > lastWaiting then grewAt = tick()
    lastWaiting = waiting
    ' The way there, walked once for each goal (open ground from the core
    ' out, then downhill from the goal): one long move order finds no way
    ' on a winding map, so the army walks it in steps.
    if goal <> marchGoal or marchLen = 0 then
      marchPath(ecX(goal), ecY(goal))
      marchGoal = goal
    end if
    if marchN = 0 and (waiting >= 20 or (waiting >= 8 and tick() - grewAt > 1800)) then
      ' The march's members: the army at the rally.
      marchN = 0
      for i = 0 to unitCount() - 1
        if marchN < 48 and unit(i, 6) = team() and (unit(i, 11) = daggerType or unit(i, 11) = maceType or unit(i, 11) = atraxType) then
          dx = unit(i, 2) - rallyX
          dy = unit(i, 3) - rallyY
          if dx > -15 and dx < 15 and dy > -15 and dy < 15 then
            marchId(marchN) = unit(i, 0)
            marchN = marchN + 1
          end if
        end if
      next i
      marchAt = marchLen - 26
      if marchAt < 0 then marchAt = 0
      marchSince = tick()
      marchFrom = 0
      marchSent = -1
      grewAt = tick()
    end if
    if marchN > 0 then
      ' A waypoint twenty-five steps on at a time: the next once half the
      ' members still alive stand within ten tiles of it (or after half a
      ' minute); the last is the goal itself.
      wx = ecX(goal)
      wy = ecY(goal)
      if marchLen > 0 then
        freeWaypoint(marchAt)
        wx = gWx
        wy = gWy
      end if
      alive = 0
      near = 0
      for i = 0 to unitCount() - 1
        if unit(i, 6) = team() then
          for k = 0 to marchN - 1
            if marchId(k) = unit(i, 0) then
              alive = alive + 1
              dx = unit(i, 2) - wx
              dy = unit(i, 3) - wy
              if dx > -10 and dx < 10 and dy > -10 and dy < 10 then near = near + 1
            end if
          next k
        end if
      next i
      if alive = 0 then
        marchN = 0
      else
        ' At the last waypoint with nobody there for a minute (the way is
        ' shut: a sector's open area may end short of the goal), the march
        ' ends and its members wait at home again.
        if marchAt = 0 and near = 0 and tick() - marchSince > 3600 then marchN = 0
        if (near * 2 >= alive or tick() - marchSince > 1800) and marchAt > 0 then
          marchAt = marchAt - 25
          if marchAt < 0 then marchAt = 0
          marchSince = tick()
          if marchLen > 0 then
            freeWaypoint(marchAt)
            wx = gWx
            wy = gWy
          end if
        end if
        ' Each waypoint is ordered once (fifteen orders a decision until every
        ' member has it) and again every ten seconds: a fresh order restarts
        ' the unit's path search, and a long one never finishes if it is
        ' renewed every second.
        if marchAt <> marchSent or tick() - marchSentAt > 600 then
          marchSent = marchAt
          marchSentAt = tick()
          marchFrom = 0
        end if
        if marchFrom < marchN then
          for k = 0 to 14
            if marchFrom + k < marchN then commandMove(marchId(marchFrom + k), wx, wy, 0)
          next k
          marchFrom = marchFrom + 15
        end if
      end if
    end if
  end if
end if

' Once coal reaches the core, build the presses by it, one at a time, with
' copper and lead to spare and the belt that takes their graphite in place.
if tick() mod 60 = 42 and stock(coal) >= 30 and stock(copper) >= 150 and stock(lead) >= 60 then
  for i = 0 to cpN - 1
    if contentAt(cpX(i), cpY(i)) <> press then
      cpTries(i) = cpTries(i) + 1
      ' Against armor from the first waves, a belt that never comes leaves
      ' the press standing alone: the flyer carries its graphite home.
      if armorEarly = 1 and cpBx(i) >= 0 and cpTries(i) >= 30 then cpBx(i) = -2
      if cpBx(i) < 0 or contentAt(cpBx(i), cpBy(i)) = conveyor or contentAt(cpBx(i), cpBy(i)) = tiBelt then
        ' Against armor from the first waves a ruin on the spot comes down
        ' first (that map is strewn with them).
        gRuin = 0
        if armorEarly = 1 then clearRuins(press, cpX(i), cpY(i))
        if gRuin = 0 then
          if buildBlock(press, cpX(i), cpY(i), 0) = 1 then busy = 1
        end if
        exit for
      end if
    end if
  next i
end if

' Coal piling up in the core means the presses cannot keep up: once all
' stand, one more goes up by the core every twenty seconds (eight at most),
' since graphite is what Hails fire and what Duos need against armor. An
' attack sector's coal feeds its cell's smelter and generators instead.
' Against armor from the first waves coal keeps coming: sixteen at most.
cpMax = 8
if armorEarly = 1 then cpMax = 16
if tick() mod 1200 = 642 and attackMode = 0 and cellsPlanned = 1 and cpN < cpMax and stock(coal) >= 300 and stock(copper) >= 150 and stock(lead) >= 100 then
  ' (A spot tried two minutes in vain does not hold the next one back.)
  cpAll = 1
  for i = 0 to cpN - 1
    if contentAt(cpX(i), cpY(i)) <> press and (armorEarly = 0 or cpTries(i) < 120) then cpAll = 0
  next i
  if cpAll = 1 then addPress()
end if

' Supply runs: far Duos stand beyond the flyer's reach from home. Every five
' seconds, with home quiet, count the empty ones; with two or more the flyer
' loads a full hand of ammo at the core (graphite, else copper), flies out,
' drops it into the far Duos within reach and comes home. States: 0 home,
' 1 loading, 2 out.
if tick() mod 300 = 150 and supplying = 0 and alarm = 0 and farN > 0 then
  supHungry = 0
  supSx = 0
  supSy = 0
  for i = 0 to buildingCount() - 1
    if building(i, 5) = team() and building(i, 11) < 8 then
      bx = building(i, 2)
      by = building(i, 3)
      if tFar(by * mapW + bx) = 1 then
        if contentAt(bx, by) = duo then
          supHungry = supHungry + 1
          supSx = supSx + bx
          supSy = supSy + by
        end if
      end if
    end if
  next i
  supItem = -1
  if stock(copper) >= 100 then supItem = copper
  if stock(graphite) >= 40 then supItem = graphite
  if supHungry >= 2 and supItem >= 0 then
    supplying = 1
    supX = supSx \ supHungry
    supY = supSy \ supHungry
    supStart = tick()
  end if
end if
if supplying > 0 then
  if alarm = 1 or tick() - supStart > 2400 then supplying = 0
end if
if supplying = 1 and home = 1 then
  deposit(cx, cy)
  take(cx, cy, supItem, 70)
  supplying = 2
end if
if supplying = 2 and tick() mod 6 = 3 then
  dx = supX - fx
  dy = supY - fy
  if dx > -15 and dx < 15 and dy > -15 and dy < 15 then
    if carried() = 0 then
      supplying = 0
    else
      ' Eight drops a decision at most, round the far Duos in turn.
      supDrops = 0
      for sk = 0 to farN - 1
        sj = (supFrom + sk) mod farN
        if supDrops < 8 then
          dx = farX(sj) - fx
          dy = farY(sj) - fy
          if dx > -25 and dx < 25 and dy > -25 and dy < 25 then
            if contentAt(farX(sj), farY(sj)) = duo or contentAt(farX(sj), farY(sj)) = hail or contentAt(farX(sj), farY(sj)) = salvo then
              deposit(farX(sj), farY(sj))
              supDrops = supDrops + 1
            end if
          end if
        end if
      next sk
      supFrom = supFrom + 8
      if supFrom >= farN then supFrom = 0
    end if
  end if
end if

' Move: to the first plan while building, otherwise onto the nearest free
' copper (lead once copper is plentiful) and mine it. Mined items drop
' into the core within 27.5 tiles of it.
targetX = cx
targetY = cy
if alarm = 1 and busy = 1 and planCount() > 0 then
  ' Mid-fight plans are by the core: build them.
  targetX = plan(0, 0)
  targetY = plan(0, 1)
elseif alarm = 1 then
  ' Halfway to the threat: in its range and still home to feed the Duos.
  targetX = (cx + threatX) / 2
  targetY = (cy + threatY) / 2
elseif hungry = 1 then
  ' Empty Duos near the core: stay home and load them.
  targetX = cx
  targetY = cy
elseif coalDue = 1 then
  ' Coal for the presses and generators: home to hand it over.
  targetX = cx
  targetY = cy
elseif supplying = 1 then
  ' Home to load ammo for the far Duos.
  targetX = cx
  targetY = cy
elseif supplying = 2 then
  targetX = supX
  targetY = supY
elseif busy = 1 and planCount() > 0 then
  targetX = plan(0, 0)
  targetY = plan(0, 1)
else
  want = 1
  if stock(copper) >= 400 and stock(copper) >= fortSave + 80 and oreBest(2) < 100000 then want = 2
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
' fifteen ticks (twelve mid-fight, when Duos empty in seconds): a big base
' has too many buildings to walk each decision. On ticks the build list
' never uses (it runs every sixth), so the commands fit in a decision.
if home = 1 and tick() mod 15 = 13 then
  feedMax = 6
  if alarm = 1 or hungry = 1 then feedMax = 12
  ' Empty the hand first: a deposit that failed leaves the stack there.
  if carried() > 0 then deposit(cx, cy)
  fed = 0
  ammo = copper
  if stock(graphite) >= 10 then ammo = graphite
  ' An attack sector keeps its graphite for maces.
  if attackMode = 1 and stock(graphite) < 200 then ammo = copper
  ' Against armor from the first waves, copper in a Duo does a fifth of what
  ' it does in a salvo, and graphite builds salvos: Duos get graphite only
  ' past two hundred and copper only past a hundred, the salvos the rest.
  duoAmmo = ammo
  duoKeep = 10
  if armorEarly = 1 then
    duoAmmo = copper
    if stock(graphite) >= 210 then duoAmmo = graphite
    if duoAmmo = copper then duoKeep = 100
  end if
  if feedFrom >= buildingCount() then feedFrom = 0
  last = feedFrom + 299
  if last > buildingCount() - 1 then last = buildingCount() - 1
  for i = feedFrom to last
    if fed < feedMax and building(i, 5) = team() and building(i, 9) >= 1 then
      bx = building(i, 2)
      by = building(i, 3)
      ' Only Duos the flyer can reach; far guards load from drills.
      reach = 0
      dx = bx - fx
      dy = by - fy
      if dx > -25 and dx < 25 and dy > -25 and dy < 25 then reach = 1
      if reach = 1 and contentAt(bx, by) = duo and building(i, 11) < 8 and stock(duoAmmo) >= duoKeep then
        take(cx, cy, duoAmmo, 8)
        deposit(bx, by)
        fed = fed + 1
      end if
      ' A Scatter (anti-air) fires lead.
      if reach = 1 and contentAt(bx, by) = scatter and building(i, 11) < 8 and stock(lead) >= 10 then
        take(cx, cy, lead, 8)
        deposit(bx, by)
        fed = fed + 1
      end if
      ' A Hail fires graphite.
      if reach = 1 and contentAt(bx, by) = hail and building(i, 11) < 8 and stock(graphite) >= 10 then
        take(cx, cy, graphite, 8)
        deposit(bx, by)
        fed = fed + 1
      end if
      ' A Ripple fires graphite.
      if reach = 1 and contentAt(bx, by) = ripple and building(i, 11) < 10 and stock(graphite) >= 10 then
        take(cx, cy, graphite, 10)
        deposit(bx, by)
        fed = fed + 1
      end if
      ' A salvo fires graphite, copper when none is left.
      if reach = 1 and contentAt(bx, by) = salvo and building(i, 11) < 10 then
        if stock(graphite) >= 10 then
          take(cx, cy, graphite, 10)
        else
          take(cx, cy, copper, 10)
        end if
        deposit(bx, by)
        fed = fed + 1
      end if
    end if
  next i
  feedFrom = last + 1
end if

' Coal by hand, every ninety ticks at home: the presses by the core (they
' burn two each one and a half seconds) and the mending cell's generators
' (one every two seconds), handing back what they leave. On a tick of
' their own: the Duos' feeding and the build list share theirs, and a
' decision past thirty-two commands loses the rest. Coal waiting and no
' feeding for seven and a half seconds calls the flyer home (coalDue).
if tick() mod 30 = 5 then
  coalUsers = 0
  for i = 0 to cpN - 1
    if contentAt(cpX(i), cpY(i)) = press then coalUsers = coalUsers + 1
  next i
  for i = 1 to mcN - 1
    if mcKind(i) = 1 then
      if contentAt(mcX(i), mcY(i)) = generator then coalUsers = coalUsers + 1
    end if
  next i
end if
coalDue = 0
if stock(coal) >= 20 and coalUsers > 0 and tick() - coalFed > 450 then coalDue = 1
if home = 1 and tick() mod 90 = 44 and stock(coal) >= 10 then
  deposit(cx, cy)
  cpTo = cpN - 1
  if cpTo > 7 then cpTo = 7
  for i = 0 to cpTo
    if contentAt(cpX(i), cpY(i)) = press then
      take(cx, cy, coal, 10)
      deposit(cpX(i), cpY(i))
      coalFed = tick()
    end if
  next i
  for i = 1 to mcN - 1
    if mcKind(i) = 1 then
      if contentAt(mcX(i), mcY(i)) = generator then
        take(cx, cy, coal, 10)
        deposit(mcX(i), mcY(i))
        coalFed = tick()
      end if
    end if
  next i
  deposit(cx, cy)
end if

' A press off the core hands its graphite to a belt; with that belt gone or
' full it holds it and stops: every ninety ticks at home, on a tick of its
' own, the flyer carries such graphite to the core.
if home = 1 and tick() mod 90 = 46 then
  cpTo = cpN - 1
  if cpTo > 7 then cpTo = 7
  for i = 0 to cpTo
    if (cpBx(i) >= 0 or cpBx(i) = -2) and contentAt(cpX(i), cpY(i)) = press then
      take(cpX(i), cpY(i), graphite, 10)
      deposit(cx, cy)
    end if
  next i
end if

' Presses past the eighth: coal on a tick of their own, and their graphite
' carried home on another (thirty-two commands a decision).
if home = 1 and tick() mod 90 = 49 and stock(coal) >= 10 and cpN > 8 then
  deposit(cx, cy)
  for i = 8 to cpN - 1
    if contentAt(cpX(i), cpY(i)) = press then
      take(cx, cy, coal, 10)
      deposit(cpX(i), cpY(i))
    end if
  next i
  deposit(cx, cy)
end if
if home = 1 and tick() mod 90 = 51 and cpN > 8 then
  for i = 8 to cpN - 1
    if (cpBx(i) >= 0 or cpBx(i) = -2) and contentAt(cpX(i), cpY(i)) = press then
      take(cpX(i), cpY(i), graphite, 10)
      deposit(cx, cy)
    end if
  next i
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
    if rmR = 7 and attackMode = 1 then
      ' Sand (kind 5) feeds an attack sector's silicon smelter: only the
      ' sand within thirty-five tiles of the core is mined.
      rmR = 0
      if rmX - cx < 35 and cx - rmX < 35 and rmY - cy < 35 and cy - rmY < 35 then rmR = 5
    elseif rmR = 5 then
      ' Titanium (kind 6) takes pneumatic drills.
      rmR = 6
    elseif rmR > 4 then
      rmR = 0
    end if
    tRes(rmT) = rmR
    tOpen(rmT) = terrainAt(rmX, rmY, 1)
    if terrainAt(rmX, rmY, 2) = 1 then tOpen(rmT) = 2
    tTaken(rmT) = 0
    tRuin(rmT) = -1
    tUsed(rmT) = 0
    tSpine(rmT) = -1
    tLane(rmT) = 0
    tFlow(rmT) = -1
    tLine(rmT) = -1
    tCross(rmT) = 0
    tRef(rmT) = -1
    tMark(rmT) = 0
    tOrd(rmT) = -1
  next rmT
  coreSize = 3
  for rmI = 0 to buildingCount() - 1
    rmS = building(rmI, 4)
    rmO = -((rmS - 1) \ 2)
    for rmJ = 0 to rmS - 1
      for rmK = 0 to rmS - 1
        rmX = building(rmI, 2) + rmO + rmK
        rmY = building(rmI, 3) + rmO + rmJ
        if rmX >= 0 and rmY >= 0 and rmX < mapW and rmY < mapH then
          ' Ruins (derelict buildings) can be torn down: they count as
          ' open ground, cleared when something of ours goes there.
          if building(rmI, 5) = 0 and tTaken(rmY * mapW + rmX) = 0 then
            tTaken(rmY * mapW + rmX) = 2
            tRuin(rmY * mapW + rmX) = building(rmI, 3) * mapW + building(rmI, 2)
          elseif building(rmI, 5) <> 0 then
            tTaken(rmY * mapW + rmX) = 1
            tRuin(rmY * mapW + rmX) = -1
          end if
        end if
      next rmK
    next rmJ
    if building(rmI, 2) = cx and building(rmI, 3) = cy then coreSize = rmS
    ' The enemy's cores (another team's, not the ruins').
    rmB = contentAt(building(rmI, 2), building(rmI, 3))
    if building(rmI, 5) <> team() and building(rmI, 5) > 0 and ecN < 8 then
      if rmB = coreShard or rmB = coreFoundation or rmB = coreNucleus then
        ecX(ecN) = building(rmI, 2)
        ecY(ecN) = building(rmI, 3)
        ecN = ecN + 1
      end if
    end if
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
  ' Without wave spawns (an attack sector, a match against other players)
  ' the enemy's cores are where the enemy comes from, and nothing can be
  ' built within fifty tiles of them.
  if spawnN = 0 and ecN > 0 then
    for rmI = 0 to ecN - 1
      if spawnN < 15 then
        spawnX(spawnN) = ecX(rmI)
        spawnY(spawnN) = ecY(rmI)
        spawnN = spawnN + 1
      end if
    next rmI
    dropZone = 50
  end if
  areaX = sector(8)
  areaY = sector(9)
  areaW = sector(10)
  areaH = sector(11)
  if areaX < 0 then areaW = 0
end sub

' Sets gFree to whether a tile can take a new block (and, with a trial
' running, is not claimed by it). A survival sector's trunk being routed
' (routing 1) may cross the claimed tiles of a spine not laid yet, other
' than its own (curSpine): side-by-side spines of one patch otherwise wall
' each other in.
sub isFree(ifX, ifY)
  gFree = 0
  if ifX < 0 or ifY < 0 or ifX >= mapW or ifY >= mapH then exit sub
  ft = ifY * mapW + ifX
  if tOpen(ft) <> 1 or tTaken(ft) = 1 then exit sub
  if tUsed(ft) <> 0 then
    if routing = 0 or attackMode = 1 or tSpine(ft) < 0 or tSpine(ft) = curSpine then exit sub
    if spRouted(tSpine(ft)) = 1 then exit sub
  end if
  if ifX - cx <= coreHi and cx - ifX <= coreLo and ifY - cy <= coreHi and cy - ifY <= coreLo then exit sub
  ' In a survival sector the inner tiles along each side of the core stay
  ' free for belts (against armor from the first waves, a lane three tiles
  ' straight out from them too): a press or mender there would leave a line
  ' no way in. The end tiles of a side still take blocks that hand goods to
  ' the core.
  if routing = 0 and attackMode = 0 then
    ifDx = ifX - cx
    ifDy = ifY - cy
    ifL = 1
    if armorEarly = 1 then ifL = 3
    if ifDx > -coreLo and ifDx < coreHi and ((ifDy > coreHi and ifDy <= coreHi + ifL) or (ifDy < -coreLo and ifDy >= -coreLo - ifL)) then exit sub
    if ifDy > -coreLo and ifDy < coreHi and ((ifDx > coreHi and ifDx <= coreHi + ifL) or (ifDx < -coreLo and ifDx >= -coreLo - ifL)) then exit sub
  end if
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
  for fpk = 0 to 5
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
        tSpine(stY(stN) * mapW + stX(stN)) = spineN
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
            tSpine((sdY(sdN) + lpJ) * mapW + sdX(sdN) + lpM) = spineN
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
' coal trunk would wait for all of it. Sand (an attack sector's smelter
' ore, kind 5) joins copper and coal lines too, and so do coal and titanium
' (6) in a survival sector (never lead, which waits whenever the core is
' full of it): the core's sides are long gone by then. An attack sector
' keeps its coal lines apart.
sub outlet(otX, otY, otWeight)
  gEnds = 0
  gInto = -1
  otMix = 0
  if curKind = 5 then otMix = 1
  if attackMode = 0 and (curKind = 3 or curKind = 6) then otMix = 1
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
        if lnLoad(tLine(otJ)) + otWeight <= beltCap and (lnKind(tLine(otJ)) = curKind or (otMix = 1 and (lnKind(tLine(otJ)) = 1 or lnKind(tLine(otJ)) = 3))) then
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
          ' Hop up to three side-by-side perpendicular straight trunk belts
          ' onto the free tile past them (each becomes a junction).
          tsGo = 1
          do while tsGo = 1 and tsHop < 3
            tsGo = 0
            if tsNx >= 0 and tsNy >= 0 and tsNx < mapW and tsNy < mapH then
              tsB = tsNy * mapW + tsNx
              if tCross(tsB) = 1 and tFlow(tsB) >= 0 then
                if tFlow(tsB) mod 2 <> tsNext mod 2 then
                  tsHop = tsHop + 1
                  tsNx = tsNx + dirX(tsNext)
                  tsNy = tsNy + dirY(tsNext)
                  isFree(tsNx, tsNy)
                  if gFree = 1 then
                    tsOk = 1
                    tsStep = 1 + 5 * tsHop
                  else
                    tsGo = 1
                  end if
                end if
              end if
            end if
          loop
          if tsOk = 0 then tsHop = 0
        end if
        if tsOk = 1 then
          if tRes(tsNy * mapW + tsNx) > 0 then tsStep = tsStep + 4
          ' A ruin must come down first: go round it when that is cheap.
          if tTaken(tsNy * mapW + tsNx) = 2 then tsStep = tsStep + 6
          tsStep = tsStep + tDanger(tsNy * mapW + tsNx) \ 4
          if tsNext <> tsHeading then tsStep = tsStep + 2
          tsJ = (tsNy * mapW + tsNx) * 4 + tsNext
          tsNew = tsHere + tsStep
          if dStamp(tsJ) <> searchId or tsNew < dCost(tsJ) then
            dStamp(tsJ) = searchId
            dCost(tsJ) = tsNew
            dPrev(tsJ) = tsState * 4 + tsHop
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
    ' The tiles hopped lie one step back and more the way the path came.
    tsH = tsAt mod 4
    if dPrev(tsAt) mod 4 >= 1 then
      for tsK = 1 to dPrev(tsAt) mod 4
        rtX(rtLen) = tsI mod mapW - dirX(tsH) * tsK
        rtY(rtLen) = tsI \ mapW - dirY(tsH) * tsK
        rcT(rcN) = rtY(rtLen) * mapW + rtX(rtLen)
        rcN = rcN + 1
        rtLen = rtLen + 1
      next tsK
    end if
    tsAt = dPrev(tsAt) \ 4
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
' cheap breadth-first search over free tiles (and up to three side-by-side
' straight trunk belts it could hop). An area found closed off for an ore
' is remembered (for that ore: lead joins only lead lines, coal more) until
' another line is laid, since only a new line opens new ways out.
sub canReach(crX, crY, crWeight)
  gReach = 0
  crHead = 0
  crTail = 0
  searchId = searchId + 1
  for crD = 0 to 3
    isFree(crX + dirX(crD), crY + dirY(crD))
    if gFree = 1 then
      crT = (crY + dirY(crD)) * mapW + crX + dirX(crD)
      if tDead(crT) <> deadEpoch * 16 + curKind then
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
      crK = 0
      do while gFree = 0 and crK < 3 and crNx >= 0 and crNy >= 0 and crNx < mapW and crNy < mapH
        crB = crNy * mapW + crNx
        if tCross(crB) = 1 then
          crNx = crNx + dirX(crD)
          crNy = crNy + dirY(crD)
          isFree(crNx, crNy)
          crK = crK + 1
        else
          crK = 3
        end if
      loop
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
    tDead(qBuf(crI)) = deadEpoch * 16 + curKind
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

' Routes one spine to its own face of the core or into a line of its ore
' with room, given what stands and is planned now, and turns it into a plan
' (its index in gPlan, else -1): belts from the core end outward, then the
' drills nearest the spine's end first. A spine with no way out gives its
' tiles back. spRouted marks it 1 routed, 2 tried and failed.
sub routeOne(rsS)
  gPlan = -1
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
    routing = 1
    curSpine = rsS
    canReach(rsEx, rsEy, rsWeight)
    rtLen = 0
    if gReach = 1 then trunkSearch(rsEx, rsEy, rsWeight)
    routing = 0
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
    spRouted(rsS) = 2
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
    ' A spine the trunk crossed has lost its way out: it is never laid.
    for rsI = 0 to brLen - 1
      rsT = brY(rsI) * mapW + brX(rsI)
      if tSpine(rsT) >= 0 and tSpine(rsT) <> rsS then
        if spRouted(tSpine(rsT)) <> 1 then spRouted(tSpine(rsT)) = 3
      end if
      tSpine(rsT) = -1
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
        ' Already ordered: the order there turns into the junction too.
        if tOrd(rsT) >= 0 then
          orderKind(tOrd(rsT)) = ((4 * 4) * 512 + lnX(rsI) - cx + 256) * 512 + lnY(rsI) - cy + 256
          orderTries(tOrd(rsT)) = 0
        end if
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
    plDrills(planN) = rsDn
    spRouted(rsS) = 1
    gPlan = planN
    planN = planN + 1
  end if
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
  for cgP = cgFrom to planN - 1
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
  if emKind = 0 then tOrd(emY * mapW + emX) = orderCount
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
  dangerMap()
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
  zoneSpine = -1
  for pbI = 1 to 9
    spLeft(pbI) = 1
  next pbI
  homeDefense()
  writeStart()
  postDx = 9999
  postDy = 9999
  if postX >= 0 then
    postDx = postX - cx
    postDy = postY - cy
  end if
end sub

' Reads the sector's wave groups and the stats of their units, and whether
' fliers worth a Scatter come (airWaves).
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
    ' Fliers worth a Scatter: bombers and up (flares fall to Duos).
    if unitStat(rwType, 2) = 1 and wgHealth(rwI) >= 300 then airWaves = 1
    ' Armored walker groups before the capture wave, and whether one comes
    ' in the first three waves.
    if unitStat(rwType, 2) = 0 and wgArmor(rwI) >= 4 and (wgBegin(rwI) < sector(0) or sector(0) <= 0) then
      rwArmored = rwArmored + 1
      if wgBegin(rwI) <= 2 then rwFirst = 1
    end if
  next rwI
  ' Waves of armor from the start (four armored groups or more, one in the
  ' first three waves): ammo goes where it hurts most, and no wave is
  ' called early.
  armorEarly = 0
  if rwFirst = 1 and rwArmored >= 4 then armorEarly = 1
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

' Graphite presses near the core, three at first: the flyer fills them with
' coal from the core and they hand graphite (Duo shots that go through
' armor) to the core or to a belt beside them that runs there, whose tile
' goes in cpBx and cpBy (-1 for the core). Touching the core comes first,
' then nearer the core, then farther from the enemy's approach.
sub corePresses()
  cpN = 0
  for cpK = 0 to 2
    addPress()
  next cpK
end sub

' Places one more press by the core where corePresses would (cpN grows by
' one when a spot fits).
sub addPress()
  cpCx = cx - (coreSize - 1) \ 2
  cpCy = cy - (coreSize - 1) \ 2
  cpBest = 999999999
  cpR = 8
  if armorEarly = 1 then cpR = 10
  for cpPy = cy - cpR to cy + cpR
    for cpPx = cx - cpR to cx + cpR
      fits(cpPx, cpPy, 2)
      if gFits = 1 then
        cpScore = -1
        ' Against armor from the first waves a press may also stand alone
        ' (cpBx -2): the flyer carries its graphite home.
        if armorEarly = 1 then
          cpDx = cpPx - cx
          if cpDx < 0 then cpDx = -cpDx
          cpDy = cpPy - cy
          if cpDy < 0 then cpDy = -cpDy
          cpScore = 50000 + (cpDx + cpDy) * 1000
          cpSx = -2
          cpSy = -2
        end if
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
              elseif cpScore < 0 or cpScore >= 50000 then
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
end sub

' A mending cell by the core: a power node, a combustion generator, seven
' menders and two more generators (each powers three menders; the node
' links ten), menders nearest the core, all within five tiles of the node
' and six of the core's center. Powered menders heal four percent of every
' block within five tiles (plus its half size) each 200 ticks; the flyer
' feeds the generators coal from the core. Kinds in mcKind: 0 node,
' 1 generator, 2 mender.
sub coreCell()
  mcN = 0
  cellSpot(cx, cy, 6)
  if gSpotX < 0 then exit sub
  mcAx = gSpotX
  mcAy = gSpotY
  mcKind(0) = 0
  mcX(0) = mcAx
  mcY(0) = mcAy
  claim(mcAx, mcAy, 1)
  mcN = 1
  for mcI = 0 to 9
    ' Generators need not stand by the core: they leave it the near tiles.
    cellFar = 0
    if cellKinds(mcI) = 1 then cellFar = 1
    cellSpot(mcAx, mcAy, 5)
    if gSpotX >= 0 then
      mcKind(mcN) = cellKinds(mcI)
      mcX(mcN) = gSpotX
      mcY(mcN) = gSpotY
      claim(gSpotX, gSpotY, 1)
      mcN = mcN + 1
    end if
  next mcI
end sub

' The open tile within reach of an anchor (counted in whole steps either
' way) and six of the core's center (anywhere in reach when cellFar is set)
' that lies nearest the core, off ore first, into gSpotX and gSpotY (-1 when
' none).
sub cellSpot(csAx, csAy, csReach)
  gSpotX = -1
  gSpotY = -1
  csBest = 999999
  for csY = csAy - csReach to csAy + csReach
    for csX = csAx - csReach to csAx + csReach
      csDx = csX - cx
      if csDx < 0 then csDx = -csDx
      csDy = csY - cy
      if csDy < 0 then csDy = -csDy
      if csDx * csDx + csDy * csDy <= 36 or cellFar = 1 then
        isFree(csX, csY)
        if gFree = 1 then
          csScore = (csDx + csDy) * 10
          if csDx > csDy then
            csScore = csScore + csDx * 100
          else
            csScore = csScore + csDy * 100
          end if
          ' Generators take the far tiles, leaving the near ones to menders.
          if cellFar = 1 then csScore = 4000 - csScore
          if tRes(csY * mapW + csX) > 0 then csScore = csScore + 5000
          if csScore < csBest then
            csBest = csScore
            gSpotX = csX
            gSpotY = csY
          end if
        end if
      end if
    next csX
  next csY
end sub

' The opening build list: two Duos by the core, the first lines the
' economy asks for, what the objectives ask for, then the front.
sub writeStart()
  orderCount = 0
  linesKept = 0
  for wsI = 0 to duoN - 1
    if wsI < 2 then emit(2, duoX(wsI), duoY(wsI), 0)
  next wsI
  for wsI = 0 to 2
    growEconomy()
    if wsI = 1 then writeAsked()
  next wsI
  writeFront()
end sub

' Appends a plan to the build list: a header naming its line and the line
' it feeds, then its belts (core end first), drills and extras.
sub emitPlan(epP)
  if linesKept >= 255 or orderCount + plLen(epP) + 64 > 11999 then exit sub
  epParent = -1
  if plJoin(epP) >= 0 then
    epRef = tRef(plJoin(epP))
    for epQ = 0 to planN - 1
      if epRef >= plStart(epQ) and epRef < plStart(epQ) + plLen(epQ) then epParent = plLineNo(epQ)
    next epQ
  end if
  plLineNo(epP) = linesKept
  lineOre(linesKept) = plKind(epP)
  emit(12, cx + linesKept, cy + epParent + 1, 0)
  lastFrom = orderCount
  for epE = plStart(epP) to plStart(epP) + plLen(epP) - 1
    if poKind(epE) >= 0 then emit(poKind(epE), poX(epE), poY(epE), poRot(epE))
  next epE
  for epE = 0 to extraN - 1
    if exPlan(epE) = epP then emit(exKind(epE), exX(epE), exY(epE), exRot(epE))
  next epE
  linesKept = linesKept + 1
  lastTo = orderCount
  epK = plKind(epP)
  if epK = 10 then epK = 3
  kindDrills(epK) = kindDrills(epK) + plDrills(epP)
end sub

' Grows the economy by one line where it is shortest: each ore has a drill
' target (copper twelve and four more a wave; lead four and one a wave,
' eight while the objectives ask for it; coal four once presses or power
' are wanted, then more with the waves; sand for an attack sector's
' smelter; every ore once copper is plentiful), and copper comes first while
' the core is nearly out of it. The line is that ore's spine cheapest per
' drill to bring in (belts at one copper, drills at twelve), routed now
' against what stands and is planned, kept off the enemy's path while it
' can be.
sub growEconomy()
  kindTarget(1) = 12 + 4 * wave()
  kindTarget(2) = 4 + wave()
  if wantLead = 1 and kindTarget(2) < 8 then kindTarget(2) = 8
  kindTarget(3) = 0
  if pressWanted = 1 or powerWanted = 1 or wave() >= 2 then kindTarget(3) = 4 + wave() \ 2
  ' Presses and generators by the core burning the coal faster than it
  ' comes: eight drills more.
  if cellsPlanned = 1 and stock(coal) < 60 then kindTarget(3) = kindBuilt(3) + 8
  kindTarget(4) = 0
  kindTarget(5) = 0
  if attackMode = 1 then
    kindTarget(5) = 6 + wave()
    ' The cell's generators and smelter burn coal too.
    kindTarget(3) = kindTarget(3) + 10
  end if
  ' Copper to spare: every ore with spots left grows (coal makes graphite,
  ' the best ammo), as far as it routes.
  if stock(copper) >= 500 then
    kindTarget(1) = kindTarget(1) + 1000
    kindTarget(2) = kindTarget(2) + 1000
    kindTarget(3) = kindTarget(3) + 1000
  end if
  ' Lead in the core and nothing asking for it: no lead lines, which would
  ' take the core's sides from copper (a core has only twelve).
  if stock(lead) >= 800 and wantLead = 0 then kindTarget(2) = 0
  ' Against armor from the first waves the core's few ways in are precious: a
  ' line of an ore the core holds enough of waits unbuilt (lead past four
  ' hundred, coal past three hundred), and routing one then would only take
  ' tiles and a way in for nothing.
  if armorEarly = 1 and stock(lead) >= 400 and wantLead = 0 then kindTarget(2) = 0
  ' Against armor from the first waves the core's few ways in are for copper
  ' and coal: one small lead line at most.
  if armorEarly = 1 and kindTarget(2) > 4 and wantLead = 0 then kindTarget(2) = 4
  ' Titanium for salvos once the base stands and graphite comes in.
  kindTarget(6) = 0
  if wave() >= 3 and stock(copper) >= 400 and stock(graphite) >= 50 then kindTarget(6) = 4 + wave() \ 3
  ' An attack sector's graphite goes to its army: titanium only while an
  ' objective asks for novas or pulsars.
  if attackMode = 1 then kindTarget(6) = 0
  if attackMode = 1 and wantTitanium = 1 and stock(titanium) < 200 and stock(copper) >= 400 then kindTarget(6) = 2
  if stock(titanium) >= 1500 then kindTarget(6) = 0
  ' A core near full of an ore needs no more of it: more lines would only
  ' be more belts for the flyer to keep standing.
  if stock(copper) >= 2500 then kindTarget(1) = 0
  if stock(lead) >= 2500 then kindTarget(2) = 0
  if stock(coal) >= 1000 then kindTarget(3) = 0
  if armorEarly = 1 and stock(coal) >= 300 then kindTarget(3) = 0
  for geTry = 0 to 4
    geKind = -1
    geBest = -1
    for geK = 1 to 6
      ' Drills standing count (lost lines do not), or those planned before
      ' the first scan has counted.
      geHave = kindBuilt(geK)
      if tick() < 600 then geHave = kindDrills(geK)
      if kindTarget(geK) > geHave and spLeft(geK) = 0 then
        ' Ore whose spines all failed to route stays out.
      elseif kindTarget(geK) > geHave then
        geShort = (kindTarget(geK) - geHave) * 100 \ kindTarget(geK)
        if geK = 1 and stock(copper) < 100 then geShort = geShort + 1000
        if geK = 2 and wantLead = 1 then geShort = geShort + 500
        if geK = 3 and pressWanted = 1 then geShort = geShort + 500
        if geShort > geBest then
          geBest = geShort
          geKind = geK
        end if
      end if
    next geK
    if geKind < 0 then exit sub
    geSpine = -1
    geKey = 2147483647
    geWaits = 0
    for geS = 0 to spineN - 1
      if spKind(geS) = geKind and spRouted(geS) = 0 and spDrillLen(geS) > 0 then
        geEnd = spTileStart(geS) + spTileLen(geS) - 1
        geCost = (spEndDist(geS) + spTileLen(geS) + 12 * spDrillLen(geS)) * 100 \ spDrillLen(geS)
        ' Danger puts a spine behind every safe one of its ore.
        geDanger = 0
        for geT = spTileStart(geS) to geEnd
          if tDanger(stY(geT) * mapW + stX(geT)) > geDanger then geDanger = tDanger(stY(geT) * mapW + stX(geT))
        next geT
        geCost = geCost + geDanger * 100000
        ' Dangerous ground waits until the core can pay for its fort too.
        ' (An attack sector needs its sand and coal: it waits for less.)
        geWait = 600
        if attackMode = 1 then geWait = 150
        if geDanger > 0 and stock(copper) < geWait then
          geWaits = 1
        elseif geCost < geKey then
          geKey = geCost
          geSpine = geS
          geRisk = geDanger
        end if
      end if
    next geS
    if geSpine < 0 then
      ' Out of this ore's spines: for good, or (when some only wait for
      ' copper) for this call, so another ore gets the line.
      if geWaits = 0 then
        spLeft(geKind) = 0
      else
        kindTarget(geKind) = 0
      end if
    else
      routeOne(geSpine)
      if gPlan >= 0 then
        if plKind(gPlan) = 3 and (pressWanted = 1 or powerWanted = 1) and techDone = 0 then
          techCell()
          techDone = 1
        end if
        if plKind(gPlan) = 1 then
          cgFrom = gPlan
          corridorGuards()
        end if
        emitPlan(gPlan)
        exit sub
      end if
    end if
  next geTry
end sub

' The danger of each tile: how far inside the ring forty-five tiles past a
' spawn's drop zone it lies (0 outside), more beside the enemy's path.
' Safe ground is built first and lightly; dangerous ground last, behind
' turrets.
sub dangerMap()
  dmRange = dropZone + 45
  ' An attack sector's cores send small waves: danger reaches only
  ' sixty-five tiles from them.
  if attackMode = 1 then dmRange = 65
  for dmT = 0 to mapW * mapH - 1
    dmX = dmT mod mapW
    dmY = dmT \ mapW
    dmBest = 0
    for dmS = 0 to spawnN - 1
      dmDx = dmX - spawnX(dmS)
      if dmDx < 0 then dmDx = -dmDx
      dmDy = dmY - spawnY(dmS)
      if dmDy < 0 then dmDy = -dmDy
      ' Octagonal distance, near enough to round.
      if dmDx > dmDy then
        dmD = dmDx + dmDy \ 2
      else
        dmD = dmDy + dmDx \ 2
      end if
      if dmRange - dmD > dmBest then dmBest = dmRange - dmD
    next dmS
    if tNear(dmT) < 6 then dmBest = dmBest + 15
    tDanger(dmT) = dmBest
  next dmT
end sub

' A fort: turrets packed in a block, the block wrapped in copper walls,
' on open ground as near a target point as fits (within eight tiles). A
' Scatter (anti-air) leads it when the waves fly, two Hails (artillery
' against armored ground) join once graphite piles up, Duos fill the rest:
' three by two turrets, four by two with the Scatter. The parts become
' orders, turrets first, so the scan builds them and rebuilds what is lost.
' Sets gFort to 1 when one was placed. Turrets beyond the flyer's hand reach
' from home join the far Duos it supplies by runs.
sub planFort(pfTx, pfTy)
  gFort = 0
  pfW = 3
  ' Against fliers every third fort leads with a Scatter: the air guards by
  ' the core and the Duos (which shoot fliers too) do the rest.
  pfAir = 0
  if airWaves = 1 and fortN mod 3 = 0 then pfAir = 1
  if pfAir = 1 then pfW = 4
  ' With titanium and graphite banked, a survival sector's fort is two
  ' salvos (or a Scatter and a salvo when the fort leads against fliers):
  ' armor-piercing bursts the copper tier lacks. An attack sector's graphite
  ' makes maces.
  ' The core must also cover the salvos ordered and not yet standing
  ' (salvoPlanned less salvoBuilt): a fort whose salvos never come is a
  ' fort slot lost.
  pfSalvo = 0
  pfWait = salvoPlanned - salvoBuilt
  if pfWait < 0 or armorEarly = 0 then pfWait = 0
  if pfGuard = 0 and attackMode = 0 and stock(titanium) >= 100 + 50 * pfWait and stock(graphite) >= 160 + 80 * pfWait then
    pfSalvo = 1
    pfW = 4
  end if
  ' An air guard (pfGuard 1) is a Scatter alone in its walls, near its spot.
  if pfGuard = 1 then pfW = 2
  pfH = 2
  pfBest = 999999
  ' Within eight tiles of the target, or sixteen when nothing fits nearer.
  for pfRad = 8 to 16 step 8
  if pfBest = 999999 and (pfGuard = 0 or pfRad = 8) then
  for pfY = pfTy - pfRad - pfH to pfTy + pfRad
    for pfX = pfTx - pfRad - pfW to pfTx + pfRad
      pfOk = 1
      pfOre = 0
      for pfJ = 0 to pfH + 1
        for pfI = 0 to pfW + 1
          if pfOk = 1 then
            isFree(pfX + pfI, pfY + pfJ)
            if gFree = 0 then
              pfOk = 0
            elseif tRes((pfY + pfJ) * mapW + pfX + pfI) > 0 then
              pfOre = pfOre + 1
            end if
          end if
        next pfI
      next pfJ
      if pfOk = 1 then
        pfDx = pfX + (pfW + 2) \ 2 - pfTx
        if pfDx < 0 then pfDx = -pfDx
        pfDy = pfY + (pfH + 2) \ 2 - pfTy
        if pfDy < 0 then pfDy = -pfDy
        pfScore = pfDx + pfDy + pfOre * 3
        if pfScore < pfBest then
          pfBest = pfScore
          pfBx = pfX
          pfBy = pfY
        end if
      end if
    next pfX
  next pfY
  end if
  next pfRad
  if pfBest = 999999 then exit sub
  for pfJ = 0 to pfH + 1
    for pfI = 0 to pfW + 1
      tUsed((pfBy + pfJ) * mapW + pfBx + pfI) = 1
    next pfI
  next pfJ
  pfHails = 0
  ' Hails only with coal coming in: without graphite they cannot fire.
  if stock(graphite) >= 100 and kindBuilt(3) >= 3 then pfHails = 2
  if stock(graphite) >= 400 and kindBuilt(3) >= 3 then pfHails = 3
  ' An attack sector's graphite makes maces: its forts are Duos until the
  ' core holds four hundred graphite.
  if attackMode = 1 and stock(graphite) < 400 then pfHails = 0
  pfFrom = 0
  if pfAir = 1 or pfGuard = 1 then
    emit(11, pfBx + 1, pfBy + 1, 0)
    pfFrom = 2
  end if
  if pfSalvo = 1 then
    if pfFrom = 0 then
      emit(15, pfBx + 1, pfBy + 1, 0)
      salvoPlanned = salvoPlanned + 1
    end if
    emit(15, pfBx + 3, pfBy + 1, 0)
    salvoPlanned = salvoPlanned + 1
    pfFrom = pfW
    for pfI = 0 to 1
      pfX = pfBx + 1 + pfI * 2
      pfY = pfBy + 1
      pfDx = pfX - cx
      pfDy = pfY - cy
      if (pfDx <= -20 or pfDx >= 20 or pfDy <= -20 or pfDy >= 20) and farN < 127 then
        farX(farN) = pfX
        farY(farN) = pfY
        farN = farN + 1
        tFar(pfY * mapW + pfX) = 1
      end if
    next pfI
  end if
  if pfFrom < pfW then
  for pfJ = 0 to pfH - 1
    for pfI = pfFrom to pfW - 1
      pfX = pfBx + 1 + pfI
      pfY = pfBy + 1 + pfJ
      if pfHails > 0 then
        emit(13, pfX, pfY, 0)
        pfHails = pfHails - 1
      else
        emit(2, pfX, pfY, 0)
      end if
      pfDx = pfX - cx
      pfDy = pfY - cy
      if (pfDx <= -20 or pfDx >= 20 or pfDy <= -20 or pfDy >= 20) and farN < 127 then
        farX(farN) = pfX
        farY(farN) = pfY
        farN = farN + 1
        tFar(pfY * mapW + pfX) = 1
      end if
    next pfI
  next pfJ
  end if
  for pfJ = 0 to pfH + 1
    for pfI = 0 to pfW + 1
      if pfJ = 0 or pfJ = pfH + 1 or pfI = 0 or pfI = pfW + 1 then emit(10, pfBx + pfI, pfBy + pfJ, 0)
    next pfI
  next pfJ
  if pfGuard = 0 then fortN = fortN + 1
  gFort = 1
end sub

' A Ripple (artillery: four shells of seventy splash a shot, thirty-six
' tiles out, graphite) on open ground six to sixteen tiles from the core,
' nearest the enemy's approach and off ore; its order is its center tile.
sub planRipple()
  prBest = 999999
  for prY = cy - 16 to cy + 16
    for prX = cx - 16 to cx + 16
      prDx = prX - cx
      if prDx < 0 then prDx = -prDx
      prDy = prY - cy
      if prDy < 0 then prDy = -prDy
      if prDx + prDy >= 6 and prDx + prDy <= 16 then
        fits(prX - 1, prY - 1, 3)
        if gFits = 1 then
          oreUnder(prX - 1, prY - 1, 3)
          prDx = prX - apX
          if prDx < 0 then prDx = -prDx
          prDy = prY - apY
          if prDy < 0 then prDy = -prDy
          prScore = prDx + prDy + gUnder * 50
          if prScore < prBest then
            prBest = prScore
            prBx = prX
            prBy = prY
          end if
        end if
      end if
    next prX
  next prY
  if prBest = 999999 then exit sub
  claim(prBx - 1, prBy - 1, 3)
  emit(16, prBx, prBy, 0)
  rippleN = rippleN + 1
end sub


' Tears down the ruins (derelict buildings) under a block about to go up
' at (crX, crY): sets gRuin to 1 when one was ordered down (build next
' time), 0 when the ground is clear. Two-tile blocks cover the tile and
' the three above and right of it.
sub clearRuins(crId, crX, crY)
  gRuin = 0
  crS = 1
  if crId = drill or crId = scatter or crId = press or crId = pneumatic or crId = salvo then crS = 2
  ' A Ripple is three by three round its center tile.
  if crId = ripple then
    crS = 3
    crX = crX - 1
    crY = crY - 1
  end if
  for crJ = 0 to crS - 1
    for crI = 0 to crS - 1
      crT = (crY + crJ) * mapW + crX + crI
      if crT >= 0 and crT < mapW * mapH then
        if tTaken(crT) = 2 then
          crR = tRuin(crT)
          if crR >= 0 then
            if contentAt(crR mod mapW, crR \ mapW) <> -1 then
              if gRuin = 0 then
                if breakBlock(crR mod mapW, crR \ mapW) = 1 then gRuin = 1
              end if
            else
              dropRuin(crT)
            end if
          else
            tTaken(crT) = 0
          end if
        end if
      end if
    next crI
  next crJ
end sub

' A ruin seen gone: every tile it covered (up to two by two) is open ground
' again, so nothing later mistakes our block on its spot for the ruin.
sub dropRuin(drT)
  drR = tRuin(drT)
  tTaken(drT) = 0
  tRuin(drT) = -1
  if drR < 0 then exit sub
  for drJ = -1 to 2
    for drI = -1 to 2
      drU = drR + drJ * mapW + drI
      if drU >= 0 and drU < mapW * mapH then
        if tRuin(drU) = drR then
          tRuin(drU) = -1
          if tTaken(drU) = 2 then tTaken(drU) = 0
        end if
      end if
    next drI
  next drJ
end sub

' An attack sector's production cell by the core: five combustion
' generators by a power node, a silicon smelter touching the core (its
' silicon goes straight in) with a node beside it and nodes between the
' two, a ground factory facing an additive reconstructor (daggers come out
' maces). Kept in build order in acKind, acX, acY and acRot (a smelter's
' lower-left tile, a factory's or reconstructor's center).
sub attackCell()
  acN = 0
  acCx = cx - coreLo
  acCy = cy - coreLo
  ' The smelter: one already standing (some sectors start with one), else
  ' one touching the core (its silicon goes straight in), else one within
  ' six tiles (the flyer carries its silicon in), off ore.
  acBest = 999999
  for acI = 0 to buildingCount() - 1
    if building(acI, 5) = team() and contentAt(building(acI, 2), building(acI, 3)) = smelter then
      acBest = 0
      acSx = building(acI, 2)
      acSy = building(acI, 3)
    end if
  next acI
  if acBest = 999999 then
    for acPy = acCy - 8 to acCy + coreSize + 6
      for acPx = acCx - 8 to acCx + coreSize + 6
        fits(acPx, acPy, 2)
        if gFits = 1 then
          touches(acPx, acPy, 2, acCx, acCy, coreSize)
          oreUnder(acPx, acPy, 2)
          acDx = acPx - cx
          if acDx < 0 then acDx = -acDx
          acDy = acPy - cy
          if acDy < 0 then acDy = -acDy
          acScore = acDx + acDy + gUnder * 10
          if gTouch = 0 then acScore = acScore + 100
          if acScore < acBest then
            acBest = acScore
            acSx = acPx
            acSy = acPy
          end if
        end if
      next acPx
    next acPy
    if acBest = 999999 then exit sub
    claim(acSx, acSy, 2)
  end if
  ' The factory and the reconstructor: two three by three blocks in a row
  ' nearest the core, the factory facing the reconstructor, with the three
  ' by three ahead of the reconstructor kept clear: a unit it finishes walks
  ' out there, and a block in the way jams it and the factory behind it.
  acBest = 999999
  for acPy = cy - 16 to cy + 16
    for acPx = cx - 16 to cx + 16
      for acR = 0 to 3
        acQx = acPx + dirX(acR) * 3
        acQy = acPy + dirY(acR) * 3
        fits(acPx, acPy, 3)
        if gFits = 1 then
          fits(acQx, acQy, 3)
          if gFits = 1 then fits(acQx + dirX(acR) * 3, acQy + dirY(acR) * 3, 3)
          if gFits = 1 then
            oreUnder(acPx, acPy, 3)
            acOre = gUnder
            oreUnder(acQx, acQy, 3)
            acOre = acOre + gUnder
            acDx = acPx + 1 - cx
            if acDx < 0 then acDx = -acDx
            acDy = acPy + 1 - cy
            if acDy < 0 then acDy = -acDy
            acScore = acDx + acDy + acOre * 10
            if acScore < acBest then
              acBest = acScore
              acFx = acPx
              acFy = acPy
              acFr = acR
              acRx = acQx
              acRy = acQy
            end if
          end if
        end if
      next acR
    next acPx
  next acPy
  if acBest = 999999 then exit sub
  claim(acFx, acFy, 3)
  claim(acRx, acRy, 3)
  claim(acRx + dirX(acFr) * 3, acRy + dirY(acFr) * 3, 3)
  ' The generators round a node between the factory and the reconstructor.
  freeSpot((acFx + acRx) \ 2 + 1, (acFy + acRy) \ 2 + 1, 4)
  if gSpotX < 0 then exit sub
  acNx = gSpotX
  acNy = gSpotY
  claim(acNx, acNy, 1)
  ' Generators the sector starts with are fed too (kind 8); only the power
  ' still missing (the cell burns 4.7 a tick: five combustion generators,
  ' or one steam generator's 5.5) is built. The nearest standing power
  ' node is where the cell's nodes lead.
  acPower = 0
  acHasNode = 0
  acBest = 999999
  for acI = 0 to buildingCount() - 1
    if building(acI, 5) = team() then
      acB = contentAt(building(acI, 2), building(acI, 3))
      if (acB = steam or acB = generator) and acN < 8 then
        acKind(acN) = 8
        acX(acN) = building(acI, 2)
        acY(acN) = building(acI, 3)
        acRot(acN) = 0
        acN = acN + 1
        acPower = acPower + 1
        if acB = steam then acPower = acPower + 5
      end if
      if acB = node then
        acDx = building(acI, 2) - acNx
        acDy = building(acI, 3) - acNy
        if acDx * acDx + acDy * acDy < acBest then
          acBest = acDx * acDx + acDy * acDy
          acEx = building(acI, 2)
          acEy = building(acI, 3)
          acHasNode = 1
        end if
      end if
    end if
  next acI
  acNew = 5 - acPower
  if acNew < 0 then acNew = 0
  for acI = 0 to acNew - 1
    freeSpot(acNx, acNy, 4)
    if gSpotX >= 0 then
      acKind(acN) = 1
      acX(acN) = gSpotX
      acY(acN) = gSpotY
      acRot(acN) = 0
      claim(gSpotX, gSpotY, 1)
      acN = acN + 1
    end if
  next acI
  acKind(acN) = 3
  acX(acN) = acSx
  acY(acN) = acSy
  acRot(acN) = 0
  acN = acN + 1
  ' Nodes: the generators' node, then every five tiles toward the smelter,
  ' then one beside the smelter (a node reaches six).
  acKind(acN) = 6
  acX(acN) = acNx
  acY(acN) = acNy
  acRot(acN) = 0
  acN = acN + 1
  acLx = acNx
  acLy = acNy
  acTx = acSx
  acTy = acSy
  if acHasNode = 1 then
    acTx = acEx
    acTy = acEy
  end if
  for acI = 0 to 7
    acDx = acTx - acLx
    acDy = acTy - acLy
    isqrt(acDx * acDx + acDy * acDy)
    if gRoot > 5 and acN < 30 then
      freeSpot(acLx + acDx * 5 \ gRoot, acLy + acDy * 5 \ gRoot, 2)
      if gSpotX >= 0 then
        acKind(acN) = 6
        acX(acN) = gSpotX
        acY(acN) = gSpotY
        acRot(acN) = 0
        claim(gSpotX, gSpotY, 1)
        acN = acN + 1
        acLx = gSpotX
        acLy = gSpotY
      end if
    end if
  next acI
  ' The reconstructor first: a factory without one in front lets its
  ' first units out as they are.
  acKind(acN) = 7
  acX(acN) = acRx + 1
  acY(acN) = acRy + 1
  acRot(acN) = acFr
  acN = acN + 1
  acKind(acN) = 4
  acX(acN) = acFx + 1
  acY(acN) = acFy + 1
  acRot(acN) = acFr
  acN = acN + 1
  ' A solar field: three clusters of nine panels (0.12 power a tick each,
  ' for lead and silicon, no fuel to carry), each round a node within five
  ' tiles of the cell's node, so the clusters link up.
  for acC = 0 to 2
    freeSpot(acNx + dirX(acC) * 5, acNy + dirY(acC) * 5, 3)
    if gSpotX >= 0 and acN < 20 then
      acPx = gSpotX
      acPy = gSpotY
      claim(acPx, acPy, 1)
      for acI = 0 to 8
        freeSpot(acPx, acPy, 3)
        if gSpotX >= 0 and acN < 28 then
          acKind(acN) = 10
          acX(acN) = gSpotX
          acY(acN) = gSpotY
          acRot(acN) = 0
          claim(gSpotX, gSpotY, 1)
          acN = acN + 1
        end if
      next acI
      acKind(acN) = 6
      acX(acN) = acPx
      acY(acN) = acPy
      acRot(acN) = 0
      acN = acN + 1
    end if
  next acC
  ' Factories and reconstructors the sector starts with work too.
  for acI = 0 to buildingCount() - 1
    if building(acI, 5) = team() and acN < 30 then
      acB = contentAt(building(acI, 2), building(acI, 3))
      acK = 0
      if acB = factory then acK = 4
      if acB = recon then acK = 7
      if acB = airFactory then acK = 9
      if acK > 0 then
        acKind(acN) = acK
        acX(acN) = building(acI, 2)
        acY(acN) = building(acI, 3)
        acRot(acN) = building(acI, 7)
        acN = acN + 1
      end if
    end if
  next acI
  linkCell()
  print "attack cell: parts", acN, "links", alN, "smelter", acSx, acSy, "factory", acFx + 1, acFy + 1, "turn", acFr
end sub

' The open tile nearest an anchor within reach of it (counted in whole
' steps either way), off ore first, into gSpotX and gSpotY (-1 when none).
sub freeSpot(fsAx, fsAy, fsReach)
  gSpotX = -1
  gSpotY = -1
  fsBest = 999999
  for fsY = fsAy - fsReach to fsAy + fsReach
    for fsX = fsAx - fsReach to fsAx + fsReach
      isFree(fsX, fsY)
      if gFree = 1 then
        fsDx = fsX - fsAx
        if fsDx < 0 then fsDx = -fsDx
        fsDy = fsY - fsAy
        if fsDy < 0 then fsDy = -fsDy
        fsScore = fsDx + fsDy
        if tRes(fsY * mapW + fsX) > 0 then fsScore = fsScore + 50
        if fsScore < fsBest then
          fsBest = fsScore
          gSpotX = fsX
          gSpotY = fsY
        end if
      end if
    next fsX
  next fsY
end sub

' The cell's power links, planned once its parts are: every node lasers to
' each part within its reach (six tiles to the part's nearest tile, ten
' links at most), each pair once. Explicit links: a block placed by a node
' does not always link itself.
sub linkCell()
  alN = 0
  for lcA = 0 to acN - 1
    if acKind(lcA) = 6 then
      lcCount = 0
      for lcB = 0 to acN - 1
        if lcB <> lcA and lcCount < 10 and alN < 64 then
          partBox(lcB)
          lcDx = 0
          if pbX0 > acX(lcA) then lcDx = pbX0 - acX(lcA)
          if acX(lcA) > pbX1 then lcDx = acX(lcA) - pbX1
          lcDy = 0
          if pbY0 > acY(lcA) then lcDy = pbY0 - acY(lcA)
          if acY(lcA) > pbY1 then lcDy = acY(lcA) - pbY1
          lcNew = 1
          for lcK = 0 to alN - 1
            if alFrom(lcK) = lcB and alTo(lcK) = lcA then lcNew = 0
          next lcK
          if lcDx * lcDx + lcDy * lcDy <= 30 and lcNew = 1 then
            alFrom(alN) = lcA
            alTo(alN) = lcB
            alN = alN + 1
            lcCount = lcCount + 1
          end if
        end if
      next lcB
    end if
  next lcA
end sub

' A cell part's tiles, into pbX0, pbX1, pbY0 and pbY1: generators and
' nodes one tile, a smelter two by two from its lower-left tile, a factory
' or reconstructor three by three round its center, a sector's own
' generator two by two when it is a steam generator.
sub partBox(pbI)
  pbX0 = acX(pbI)
  pbY0 = acY(pbI)
  pbS = 1
  if acKind(pbI) = 3 then pbS = 2
  if acKind(pbI) = 8 and contentAt(acX(pbI), acY(pbI)) = steam then pbS = 2
  if acKind(pbI) = 4 or acKind(pbI) = 7 then
    pbX0 = acX(pbI) - 1
    pbY0 = acY(pbI) - 1
    pbS = 3
  end if
  pbX1 = pbX0 + pbS - 1
  pbY1 = pbY0 + pbS - 1
end sub

' Sets gPart to the block id that belongs at a cell part (a sector's own
' generator: whatever generator stands there).
sub partBlock(ptI)
  gPart = generator
  if acKind(ptI) = 3 then gPart = smelter
  if acKind(ptI) = 4 then gPart = factory
  if acKind(ptI) = 6 then gPart = node
  if acKind(ptI) = 7 then gPart = recon
  if acKind(ptI) = 9 then gPart = airFactory
  if acKind(ptI) = 10 then gPart = solar
  if acKind(ptI) = 8 and contentAt(acX(ptI), acY(ptI)) = steam then gPart = steam
end sub

' Walks the way from the core to a goal into marchX and marchY (goal
' first, marchLen tiles): the cheapest way over open ground out from the
' core, a step costing one plus eight for every enemy turret that can hit
' ground within twelve tiles of it (the march goes round defended ground
' where it can), then downhill from the goal. marchLen is 0 without a way.
sub marchPath(mpGx, mpGy)
  marchLen = 0
  for mpT = 0 to mapW * mapH - 1
    tDist(mpT) = -1
    tThreat(mpT) = 0
  next mpT
  for mpI = 0 to buildingCount() - 1
    if building(mpI, 5) <> team() and building(mpI, 5) > 0 then
      mpB = contentAt(building(mpI, 2), building(mpI, 3))
      if mpB = duo or mpB = hail or mpB = arc or mpB = scorch or mpB = lancer or mpB = salvo or mpB = ripple then
        mpBx = building(mpI, 2)
        mpBy = building(mpI, 3)
        for mpY = mpBy - 12 to mpBy + 12
          for mpX = mpBx - 12 to mpBx + 12
            if mpX >= 0 and mpY >= 0 and mpX < mapW and mpY < mapH then
              if (mpX - mpBx) * (mpX - mpBx) + (mpY - mpBy) * (mpY - mpBy) <= 144 then
                tThreat(mpY * mapW + mpX) = tThreat(mpY * mapW + mpX) + 1
              end if
            end if
          next mpX
        next mpY
      end if
    end if
  next mpI
  heapN = 0
  mpT = cy * mapW + cx
  tDist(mpT) = 0
  heapPush(0, mpT)
  do while heapN > 0
    heapPop()
    mpT = gVal
    if gKey <= tDist(mpT) then
      for mpD = 0 to 3
        mpX = mpT mod mapW + dirX(mpD)
        mpY = mpT \ mapW + dirY(mpD)
        if mpX >= 0 and mpY >= 0 and mpX < mapW and mpY < mapH then
          mpN = mpY * mapW + mpX
          mpOk = 0
          if tOpen(mpN) >= 1 then mpOk = 1
          if mpX - cx <= coreHi and cx - mpX <= coreLo and mpY - cy <= coreHi and cy - mpY <= coreLo then mpOk = 1
          if mpOk = 1 then
            mpC = gKey + 1 + 8 * tThreat(mpN)
            if tDist(mpN) < 0 or mpC < tDist(mpN) then
              tDist(mpN) = mpC
              heapPush(mpC, mpN)
            end if
          end if
        end if
      next mpD
    end if
  loop
  mpX = mpGx
  mpY = mpGy
  if tDist(mpY * mapW + mpX) < 0 then exit sub
  marchX(0) = mpX
  marchY(0) = mpY
  marchLen = 1
  do while tDist(mpY * mapW + mpX) > 0 and marchLen < 3999
    mpBest = tDist(mpY * mapW + mpX)
    mpBx = -1
    for mpD = 0 to 3
      mpNx = mpX + dirX(mpD)
      mpNy = mpY + dirY(mpD)
      if mpNx >= 0 and mpNy >= 0 and mpNx < mapW and mpNy < mapH then
        mpN = mpNy * mapW + mpNx
        if tDist(mpN) >= 0 and tDist(mpN) < mpBest then
          mpBest = tDist(mpN)
          mpBx = mpNx
          mpBy = mpNy
        end if
      end if
    next mpD
    if mpBx < 0 then exit do
    mpX = mpBx
    mpY = mpBy
    marchX(marchLen) = mpX
    marchY(marchLen) = mpY
    marchLen = marchLen + 1
  loop
end sub

' The march's waypoint for a step of its way, into gWx and gWy: that tile
' or, when a building stands on it (a move order cannot end on one), the
' first open tile of the way back toward the core.
sub freeWaypoint(fwAt)
  fwI = fwAt
  do while fwI < marchLen - 1 and (contentAt(marchX(fwI), marchY(fwI)) <> -1 or blockAt(marchX(fwI), marchY(fwI)) <> -1)
    fwI = fwI + 1
  loop
  gWx = marchX(fwI)
  gWy = marchY(fwI)
end sub

' A wall across the enemy's way where it runs narrowest, twelve to forty
' steps out from the core: two rows of copper walls from cliff to cliff
' (fourteen tiles at most), so ground units stop and chew through them under
' the forts' fire. The walls are orders: lost ones come back. Our belts
' crossing the pass are left as gaps.
sub chokeWalls()
  if pathLen < 50 then exit sub
  cwBest = 999
  for cwI = pathLen - 13 to pathLen - 41 step -1
    cwVx = pathX(cwI - 4) - pathX(cwI + 4)
    cwVy = pathY(cwI - 4) - pathY(cwI + 4)
    cwAx = cwVx
    if cwAx < 0 then cwAx = -cwAx
    cwAy = cwVy
    if cwAy < 0 then cwAy = -cwAy
    cwDx = 0
    cwDy = 0
    if cwAx >= cwAy then
      if cwVx > 0 then cwDx = 1 else cwDx = -1
    else
      if cwVy > 0 then cwDy = 1 else cwDy = -1
    end if
    cwPx = -cwDy
    cwPy = cwDx
    cwA = 0
    cwGo = 1
    do while cwA < 15 and cwGo = 1
      openTile(pathX(cwI) + cwPx * (cwA + 1), pathY(cwI) + cwPy * (cwA + 1))
      if gOpen = 1 then
        cwA = cwA + 1
      else
        cwGo = 0
      end if
    loop
    cwB = 0
    cwGo = 1
    do while cwB < 15 and cwGo = 1
      openTile(pathX(cwI) - cwPx * (cwB + 1), pathY(cwI) - cwPy * (cwB + 1))
      if gOpen = 1 then
        cwB = cwB + 1
      else
        cwGo = 0
      end if
    loop
    if cwA < 15 and cwB < 15 and cwA + cwB + 1 < cwBest then
      cwBest = cwA + cwB + 1
      cwAt = cwI
      cwWa = cwA
      cwWb = cwB
      cwSx = cwDx
      cwSy = cwDy
      cwQx = cwPx
      cwQy = cwPy
    end if
  next cwI
  if cwBest > 14 then exit sub
  for cwL = 0 to 1
    for cwO = -cwWb to cwWa
      cwX = pathX(cwAt) + cwQx * cwO + cwSx * cwL
      cwY = pathY(cwAt) + cwQy * cwO + cwSy * cwL
      isFree(cwX, cwY)
      if gFree = 1 then
        emit(10, cwX, cwY, 0)
        tUsed(cwY * mapW + cwX) = 1
      end if
    next cwO
  next cwL
  print "choke: walls at", pathX(cwAt), pathY(cwAt), "width", cwBest
end sub

' Sets gOpen to 1 when a tile is open ground on the map (no cliff, deep
' water or edge), whatever stands on it.
sub openTile(otTx, otTy)
  gOpen = 0
  if otTx >= 0 and otTy >= 0 and otTx < mapW and otTy < mapH then
    if tOpen(otTy * mapW + otTx) >= 1 then gOpen = 1
  end if
end sub
