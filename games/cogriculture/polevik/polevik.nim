## Polevik — Cogriculture policy for Andre von Auto.
## Cogriculture runs the upstream Kaggle Kaggriculture simulator unmodified;
## the player protocol (docs/protocol_player.md) is handshake ->
## observation (the raw Kaggle observation dict) -> {"action": ...} ->
## final. One reply per observation, within actTimeout (1s) — this scripted
## policy answers in microseconds.
##
## This is a faithful Nim port of the strongest example player, Melonrush
## (`bots/melonrush.py`, the manifest's `baseline`, ~20x the starter bot):
##  1. All-in melon opening (~60% of the start quadrant), harvested at age
##     10 so the whole dump SELLS ON DAY 11 at near-scarcity prices.
##  2. From day 12: eight cows + six sheep on pastures near the shed, fed
##     and cared daily on bought wheat (care banks +2/fed-day, paid on
##     production days). Extra animals also print 1 fertilizer/day each.
##  3. Land: buy quadrants once melon money lands, stop at three.
##  4. Strawberry-heavy replant, with a dedicated fertilizer courier
##     (FERTILIZE doubles a watered ongoing production; one charge covers
##     two strawberry productions).
##  5. Day-29 liquidation: extra hands, sell everything, and from hour 14
##     every carrying unit ferries goods to the shed and DROPs (harvests
##     only bank at the next dawn, and there is no next dawn).
## Port notes: Python's stable sorts / first-min semantics are reproduced
## (jobs keep an insertion index; min-by-distance takes the first minimum),
## `round()` uses Python's half-to-even, and dict-order-sensitive spots
## (seed iteration, mix order) follow the JSON/object insertion order the
## Python bot sees.
## No secret envs needed: fully scripted.

import std/[algorithm, json, math, sets, strutils, tables], coworld_client

type
  Pos = tuple[x, y: int]
  Job = object
    priority: int
    x, y: int
    action: seq[string]
    order: int

const
  seedCost = {"WHEAT": 10, "CARROT": 20, "TOMATO": 50, "STRAWBERRY": 100,
              "MELON": 80}.toTable
  firstYieldDay = {"WHEAT": 2, "CARROT": 2, "TOMATO": 8, "STRAWBERRY": 10,
                   "MELON": 10}.toTable
  maxYieldDay = {"WHEAT": 4, "CARROT": 3, "MELON": 12}.toTable
  ongoingCrops = ["TOMATO", "STRAWBERRY"]
  cycleDays = {"WHEAT": 5, "CARROT": 4, "TOMATO": 12, "STRAWBERRY": 14,
               "MELON": 13}.toTable

  animalKinds = ["GOOSE", "COW", "SHEEP"]
  animalCost = {"GOOSE": 300, "COW": 400, "SHEEP": 500}.toTable

  openingMix = [("MELON", 0.60), ("STRAWBERRY", 0.14), ("CARROT", 0.10),
                ("WHEAT", 0.08), ("TOMATO", 0.08)]
  mainMix = [("STRAWBERRY", 0.40), ("MELON", 0.25), ("WHEAT", 0.15),
             ("TOMATO", 0.10), ("CARROT", 0.10)]
  closingMix = [("CARROT", 0.6), ("WHEAT", 0.4)]

  openingDays = 11
  mainMixMinCash = 1200.0

  openingHands = 5
  targetHands = 10
  minHands = 3
  handCashPerDay = 150.0
  liquidationHands = 4

  ranchStartDay = 12
  # Top kaggle policies (mined 100k–158k replays) run 8 cows + 6 sheep;
  # fertilizer (1/animal/day) is the extra animals' main cash print.
  ranchBuildOrder = ["COW", "COW", "COW", "COW", "COW", "COW", "COW", "COW",
                     "SHEEP", "SHEEP", "SHEEP", "SHEEP", "SHEEP", "SHEEP"]
  animalCashReserve = 1500.0
  animalBuysPerDay = 3
  feedBuyCap = 16

  dailySellCap = {"WHEAT": 12, "CARROT": 12, "TOMATO": 12, "STRAWBERRY": 18,
                  "MELON": 999, "EGG": 16, "MILK": 10, "WOOL": 8,
                  "FERTILIZER": 10}.toTable
  minSellPriceFraction = 0.35
  basePrice = {"WHEAT": 25, "CARROT": 35, "TOMATO": 60, "STRAWBERRY": 120,
               "MELON": 250, "EGG": 50, "MILK": 160, "WOOL": 200,
               "FERTILIZER": 100}.toTable

  landPrices = [1000.0, 2000.0, 4000.0]
  landCashBuffer = 1200.0
  lastLandDay = 18
  earliestLandDay = 11
  maxQuadrants = 3

  seedBuffer = 6
  cashReserve = 400.0
  tilesPerUnit = 5
  maxMarketOrders = 10

  hireHour = 0
  seedHour = 1
  ranchHour = 2

  melonHarvestAge = 10
  melonMaxUnits = 6
  lastDaySweepHour = 14

  fertStockCap = 6
  fertCarry = 6
  fertPreload = 4
  fertLookahead = 1
  productionInterval = {"TOMATO": 1, "STRAWBERRY": 2}.toTable
  maxProductions = {"TOMATO": 4, "STRAWBERRY": 4}.toTable

  priorityWaterCritical = 100
  priorityHarvest = 80
  priorityWater = 60
  priorityBuild = 70
  priorityPlant = 45
  priorityWeed = 30

## Small helpers

proc isAnimal(item: string): bool =
  item in animalKinds

proc structureOf(animal: string): string =
  if animal == "GOOSE": "COOP" else: "PASTURE"

proc getCount(obj: JsonNode, key: string): int =
  ## dict.get(key, 0) over a possibly-nil JSON object.
  obj{key}.getInt(0)

proc passAction(): JsonNode =
  %*["PASS"]

proc isPass(action: JsonNode): bool =
  action.kind == JArray and action.len == 1 and action[0].getStr() == "PASS"

proc configInt(config: JsonNode, key: string, default: int): int =
  ## Port of _config_int: `int(value) or default` (0 falls back too).
  let value = config{key}
  var parsed = default
  if value != nil:
    case value.kind
    of JInt: parsed = int(value.getInt())
    of JFloat: parsed = int(value.getFloat())
    of JString:
      try:
        parsed = parseInt(value.getStr())
      except ValueError:
        parsed = default
    else:
      parsed = default
  if parsed == 0: default else: parsed

proc pyRound(value: float): int =
  ## Python round(): half to even. Inputs here are nonnegative.
  let base = floor(value)
  let diff = value - base
  if diff > 0.5: int(base) + 1
  elif diff < 0.5: int(base)
  else:
    let n = int(base)
    if n mod 2 == 0: n else: n + 1

proc distance(a, b: Pos): int =
  abs(a.x - b.x) + abs(a.y - b.y)

proc stepToward(origin, target: Pos): string =
  if origin.x != target.x:
    (if target.x > origin.x: "EAST" else: "WEST")
  else:
    (if target.y > origin.y: "SOUTH" else: "NORTH")

const shedAccess = [(4, 4), (5, 4), (4, 5), (5, 5)]

proc shedDist(pos: Pos): int =
  result = high(int)
  for tile in shedAccess:
    result = min(result, distance(pos, tile))

proc nearestShedTile(pos: Pos): Pos =
  result = shedAccess[0]
  var best = distance(pos, result)
  for tile in shedAccess:
    let d = distance(pos, tile)
    if d < best:
      best = d
      result = tile

## Farm scan helpers

proc scanFarm(farm, private: JsonNode):
    tuple[animalTiles: seq[tuple[x, y: int, tile: JsonNode]],
          freeStructures: Table[string, seq[Pos]],
          empties: seq[Pos], herd: int] =
  ## One pass over tiles: animal tiles, free structures, empties, herd size.
  result.freeStructures = {"COOP": newSeq[Pos](),
                           "PASTURE": newSeq[Pos]()}.toTable
  var y = 0
  for row in farm{"tiles"}:
    var x = 0
    for tile in row:
      if tile.kind == JString and tile.getStr() == "LOCKED":
        discard
      elif tile.kind == JNull:
        result.empties.add((x, y))
      elif tile.kind == JObject:
        if tile{"animal"}.getStr("") != "":
          result.animalTiles.add((x, y, tile))
        elif tile{"kind"}.getStr() in ["COOP", "PASTURE"]:
          result.freeStructures[tile{"kind"}.getStr()].add((x, y))
      x.inc()
    y.inc()
  let shed = private{"shed"}
  let inventories = private{"inventories"}
  result.herd = result.animalTiles.len
  for animal in animalKinds:
    result.herd += shed.getCount(animal)
    if inventories != nil:
      for inv in inventories:
        result.herd += inv.getCount(animal)

proc isProductionDay(tile: JsonNode, crop: string, day: int): bool =
  ## True if the sim will score a scheduled production for this ongoing
  ## tile at the END of `day` (it evaluates next_day = day + 1).
  let k = (day + 1) - tile{"planted_day"}.getInt() - firstYieldDay[crop]
  if k < 0:
    return false
  let interval = productionInterval[crop]
  if k mod interval != 0:
    return false
  k div interval + 1 <= maxProductions[crop]

proc fertTargets(tiles: JsonNode, day: int): seq[Pos] =
  ## Ongoing-crop tiles where one FERTILIZE pays TODAY: watered, uncovered,
  ## and producing at the end of this day.
  var y = 0
  for row in tiles:
    var x = 0
    for tile in row:
      if tile.kind == JObject and tile{"kind"}.getStr() == "PLANT":
        let crop = tile{"crop"}.getStr()
        if crop in ongoingCrops and tile{"watered_today"}.getBool() and
            tile{"fertilized_until_day"}.getInt(-1) < day and
            isProductionDay(tile, crop, day):
          result.add((x, y))
      x.inc()
    y.inc()

proc fertStillUseful(tiles: JsonNode, day, totalDays: int): bool =
  ## Any ongoing crop with a scheduled production left in the season.
  for row in tiles:
    for tile in row:
      if tile.kind == JObject and tile{"kind"}.getStr() == "PLANT":
        let crop = tile{"crop"}.getStr()
        if crop in ongoingCrops:
          for d in day ..< totalDays - 1:
            if isProductionDay(tile, crop, d):
              return true
  false

proc fertSoon(tiles: JsonNode, day, totalDays: int): bool =
  ## A production day lands within the next fertLookahead days.
  let horizon = min(totalDays - 1, day + fertLookahead)
  for row in tiles:
    for tile in row:
      if tile.kind == JObject and tile{"kind"}.getStr() == "PLANT":
        let crop = tile{"crop"}.getStr()
        if crop in ongoingCrops:
          for d in day .. horizon:
            if isProductionDay(tile, crop, d):
              return true
  false

## Jobs (crop side)

proc mixShare(mix: openArray[(string, float)], crop: string): float =
  for (name, share) in mix:
    if name == crop:
      return share
  0.0

proc cropMix(day: int, money: float): seq[(string, float)] =
  if day < openingDays:
    return @openingMix
  if money < mainMixMinCash:
    return @closingMix
  @mainMix

proc nextCrop(seeds: OrderedTable[string, int], daysLeft: int,
              mix: openArray[(string, float)]): string =
  ## Python max() semantics: first maximal element by (share, cycle days).
  result = ""
  var bestShare = -1.0
  var bestCycle = -1
  for crop, count in seeds:
    if count > 0 and cycleDays.getOrDefault(crop, 99) <= daysLeft:
      let share = mixShare(mix, crop)
      let cycle = cycleDays.getOrDefault(crop, 0)
      if share > bestShare or (share == bestShare and cycle > bestCycle):
        bestShare = share
        bestCycle = cycle
        result = crop

proc plantJobs(tile: JsonNode, x, y, day: int): seq[Job] =
  let crop = tile{"crop"}.getStr()
  let age = day - tile{"planted_day"}.getInt()

  if not tile{"watered_today"}.getBool():
    let critical = tile{"consecutive_unwatered"}.getInt() >= 1
    result.add(Job(priority: (if critical: priorityWaterCritical
                              else: priorityWater),
                   x: x, y: y, action: @["WATER"]))

  if tile{"yield_units"}.getInt() > 0 and
      age >= firstYieldDay.getOrDefault(crop, 99):
    let harvestAge = (if crop == "MELON": melonHarvestAge
                      else: maxYieldDay.getOrDefault(crop, 99))
    var ripe = crop in ongoingCrops or age >= harvestAge
    # Water-first gate: never pick a ripe melon before today's watering
    # (except on its final living day) — the water bonus is +1/day.
    if crop == "MELON" and ripe and
        tile{"yield_units"}.getInt() < melonMaxUnits and
        not tile{"watered_today"}.getBool() and
        age < maxYieldDay["MELON"]:
      ripe = false
    if ripe:
      result.add(Job(priority: priorityHarvest, x: x, y: y,
                     action: @["HARVEST"]))

proc plantingJobs(empty: seq[Pos], seeds: var OrderedTable[string, int],
                  day, totalDays: int, money: float): seq[Job] =
  let daysLeft = totalDays - day
  let mix = cropMix(day, money)
  for (x, y) in empty:
    let crop = nextCrop(seeds, daysLeft, mix)
    if crop == "":
      break
    seeds[crop] = seeds[crop] - 1
    result.add(Job(priority: priorityPlant, x: x, y: y,
                   action: @["PLANT", crop]))

proc buildJobs(freeStructures: Table[string, seq[Pos]], empties: seq[Pos],
               shed, inventories: JsonNode,
               herd, day: int): seq[Job] =
  ## Build the whole remaining barn as soon as the ranch phase opens, on
  ## the tiles nearest the shed.
  var need = {"COOP": 0, "PASTURE": 0}.toTable
  for animal in animalKinds:
    var owned = shed.getCount(animal)
    if inventories != nil:
      for inv in inventories:
        owned += inv.getCount(animal)
    need[structureOf(animal)] = need[structureOf(animal)] + owned
  if ranchStartDay - 1 <= day and day <= 24:
    for i in herd ..< ranchBuildOrder.len:
      let structure = structureOf(ranchBuildOrder[i])
      need[structure] = need[structure] + 1
  for kind in ["COOP", "PASTURE"]:
    need[kind] = max(0, need[kind] - freeStructures[kind].len)
  if need["COOP"] == 0 and need["PASTURE"] == 0:
    return @[]
  # Stable sort by shed distance (Python sorted() is stable).
  var sites: seq[tuple[dist, order: int, pos: Pos]]
  for i, pos in empties:
    sites.add((shedDist(pos), i, pos))
  sites.sort()
  var next = 0
  for (kind, op) in [("COOP", "BUILD_COOP"), ("PASTURE", "BUILD_PASTURE")]:
    for _ in 0 ..< need[kind]:
      if next >= sites.len:
        break
      result.add(Job(priority: priorityBuild, x: sites[next].pos.x,
                     y: sites[next].pos.y, action: @[op]))
      next.inc()

proc rankJobs(farm, private: JsonNode, day, totalDays: int,
              builds: seq[Job]): seq[Job] =
  var seeds = initOrderedTable[string, int]()
  let seedsNode = private{"seeds"}
  if seedsNode != nil and seedsNode.kind == JObject:
    for key, value in seedsNode:
      seeds[key] = value.getInt()
  var jobs = builds
  var empty: seq[Pos]
  var buildSites = initHashSet[Pos]()
  for job in builds:
    buildSites.incl((job.x, job.y))

  var y = 0
  for row in farm{"tiles"}:
    var x = 0
    for tile in row:
      if tile.kind == JString and tile.getStr() == "LOCKED":
        discard
      elif tile.kind == JNull:
        if (x, y) notin buildSites:
          empty.add((x, y))
      elif tile.kind == JObject:
        let kind = tile{"kind"}.getStr()
        if kind == "WEED":
          jobs.add(Job(priority: priorityWeed, x: x, y: y, action: @["DIG"]))
        elif kind == "PLANT":
          jobs.add(plantJobs(tile, x, y, day))
        # animal tiles are the ranchers' problem, not the field crews'
      x.inc()
    y.inc()

  jobs.add(plantingJobs(empty, seeds, day, totalDays,
                        farm{"money"}.getFloat()))
  for i in 0 ..< jobs.len:
    jobs[i].order = i
  jobs.sort(proc(a, b: Job): int =
    if a.priority != b.priority: cmp(b.priority, a.priority)
    else: cmp(a.order, b.order))
  jobs

## Unit assignment

proc bestJob(jobs: seq[Job], claimed: HashSet[Pos],
             useZone: bool, zone: HashSet[Pos],
             useNear: bool = false, near: Pos = (0, 0)): tuple[found: bool, job: Job] =
  var candidates: seq[Job]
  for job in jobs:
    if (job.x, job.y) notin claimed and
        (not useZone or (job.x, job.y) in zone):
      candidates.add(job)
  if candidates.len == 0:
    return (false, Job())
  if not useNear:
    return (true, candidates[0])
  let top = candidates[0].priority
  var best = candidates[0]
  var bestDist = high(int)
  for job in candidates:
    if job.priority == top:
      let d = distance(near, (job.x, job.y))
      if d < bestDist:
        bestDist = d
        best = job
  (true, best)

proc actOrStep(position: Pos, job: Job): JsonNode =
  if position == (job.x, job.y):
    result = newJArray()
    for part in job.action:
      result.add(%part)
  else:
    result = %*[stepToward(position, (job.x, job.y))]

proc makeZones(tiles: JsonNode, numUnits: int,
               exclude: HashSet[Pos]): seq[HashSet[Pos]] =
  var unlocked: seq[Pos]
  var y = 0
  for row in tiles:
    var x = 0
    for tile in row:
      if not (tile.kind == JString and tile.getStr() == "LOCKED") and
          (x, y) notin exclude:
        unlocked.add((x, y))
      x.inc()
    y.inc()
  if unlocked.len == 0 or numUnits <= 0:
    for _ in 0 ..< max(0, numUnits):
      result.add(initHashSet[Pos]())
    return
  let perUnit = max(1, (unlocked.len + numUnits - 1) div numUnits)
  for i in 0 ..< numUnits:
    var zone = initHashSet[Pos]()
    for j in i * perUnit ..< min((i + 1) * perUnit, unlocked.len):
      zone.incl(unlocked[j])
    result.add(zone)

proc firstMinByDistance(candidates: seq[Pos], pos: Pos): tuple[found: bool, target: Pos] =
  ## Python min(key=distance): the FIRST minimal element.
  if candidates.len == 0:
    return (false, (0, 0))
  var best = candidates[0]
  var bestDist = distance(pos, best)
  for candidate in candidates:
    let d = distance(pos, candidate)
    if d < bestDist:
      bestDist = d
      best = candidate
  (true, best)

proc rancherAction(k, nRanchers: int, pos: Pos, inv: JsonNode,
                   animalTiles: seq[tuple[x, y: int, tile: JsonNode]],
                   freeStructures: Table[string, seq[Pos]],
                   shed, inventories: JsonNode, day: int,
                   claimed: var HashSet[Pos]): JsonNode =
  ## Stateless ranch logic for rancher k of n. Returns nil for "no ranch
  ## work; join the field crews".
  let liquidation = day >= 29

  # 1. Carrying an animal: place it on a free matching structure.
  for animal in animalKinds:
    if inv.getCount(animal) > 0:
      var slots: seq[Pos]
      for slot in freeStructures[structureOf(animal)]:
        if slot notin claimed:
          slots.add(slot)
      if slots.len == 0:
        return nil  # builders will make one; help the fields meanwhile
      let (_, target) = firstMinByDistance(slots, pos)
      claimed.incl(target)
      if pos == target:
        return %*["PLACE", animal]
      return %*[stepToward(pos, target)]

  # 2. Animal waiting in the shed with a slot ready: fetch it (rancher 0).
  if k == 0 and not liquidation:
    var carried = 0
    if inventories != nil:
      for unitInv in inventories:
        for animal in animalKinds:
          carried += unitInv.getCount(animal)
    for animal in animalKinds:
      if shed.getCount(animal) > carried and
          freeStructures[structureOf(animal)].len > 0:
        if shedDist(pos) == 0:
          return %*["PICKUP", animal, 1]
        return %*[stepToward(pos, nearestShedTile(pos))]

  # My share of the herd.
  var mine: seq[tuple[x, y: int, tile: JsonNode]]
  for (x, y, tile) in animalTiles:
    if (x + 10 * y) mod max(1, nRanchers) == k:
      mine.add((x, y, tile))

  # 3. Feeding (skipped on liquidation day — sell the wheat instead).
  if not liquidation:
    var unfed: seq[Pos]
    for (x, y, tile) in mine:
      if not tile{"fed_today"}.getBool():
        unfed.add((x, y))
    if unfed.len > 0:
      if inv.getCount("WHEAT") > 0:
        var unclaimed: seq[Pos]
        for u in unfed:
          if u notin claimed:
            unclaimed.add(u)
        let (found, target) = firstMinByDistance(unclaimed, pos)
        if found:
          claimed.incl(target)
          if pos == target:
            return %*["FEED"]
          return %*[stepToward(pos, target)]
      elif shed.getCount("WHEAT") > 0:
        if shedDist(pos) == 0:
          return %*["PICKUP", "WHEAT",
                    min(unfed.len, min(shed.getCount("WHEAT"), 8))]
        return %*[stepToward(pos, nearestShedTile(pos))]

  # 4. Harvest ready product.
  var ready: seq[Pos]
  for (x, y, tile) in mine:
    if tile{"yield_units"}.getInt() > 0 and (x, y) notin claimed:
      ready.add((x, y))
  if ready.len > 0:
    let (_, target) = firstMinByDistance(ready, pos)
    claimed.incl(target)
    if pos == target:
      return %*["HARVEST"]
    return %*[stepToward(pos, target)]

  # 5. Care (banks +1 yield on the next fed production).
  if not liquidation:
    var uncared: seq[Pos]
    for (x, y, tile) in mine:
      if not tile{"cared_today"}.getBool() and tile{"fed_today"}.getBool() and
          (x, y) notin claimed:
        uncared.add((x, y))
    if uncared.len > 0:
      let (_, target) = firstMinByDistance(uncared, pos)
      claimed.incl(target)
      if pos == target:
        return %*["CARE"]
      return %*[stepToward(pos, target)]

  # 6. Free fertilizer.
  var fert: seq[Pos]
  for (x, y, tile) in mine:
    if tile{"fertilizer_available"}.getBool() and (x, y) notin claimed:
      fert.add((x, y))
  if fert.len > 0:
    let (_, target) = firstMinByDistance(fert, pos)
    claimed.incl(target)
    if pos == target:
      return %*["COLLECT_FERTILIZER"]
    return %*[stepToward(pos, target)]

  nil  # nothing ranch-side; join the field crews

proc courierAction(pos: Pos, inv, shed, tiles: JsonNode,
                   day, totalDays: int,
                   claimed: var HashSet[Pos]): JsonNode =
  ## Keep FERTILIZER moving from the shed onto ongoing-crop tiles that
  ## score a production tonight (one charge = two strawberry productions).
  if day >= totalDays - 1:
    return nil
  var targets: seq[Pos]
  for target in fertTargets(tiles, day):
    if target notin claimed:
      targets.add(target)
  let carried = inv.getCount("FERTILIZER")

  if targets.len > 0 and carried > 0:
    let (_, target) = firstMinByDistance(targets, pos)
    claimed.incl(target)
    if pos == target:
      return %*["FERTILIZE"]
    return %*[stepToward(pos, target)]

  var want = targets.len
  if want == 0 and fertSoon(tiles, day, totalDays):
    want = fertPreload
  if want > 0 and carried < fertCarry and shed.getCount("FERTILIZER") > 0:
    if shedDist(pos) == 0:
      return %*["PICKUP", "FERTILIZER",
                min(fertCarry - carried, shed.getCount("FERTILIZER"))]
    return %*[stepToward(pos, nearestShedTile(pos))]

  nil  # nothing to ferry; join the field crews

proc assignUnits(farm, private: JsonNode, day, totalDays,
                 hour: int): seq[JsonNode] =
  var positions: seq[Pos]
  positions.add((farm{"farmer"}[0].getInt(), farm{"farmer"}[1].getInt()))
  let handsNode = farm{"hands"}
  if handsNode != nil and handsNode.kind == JArray:
    for hand in handsNode:
      positions.add((hand[0].getInt(), hand[1].getInt()))
  var actions = newSeq[JsonNode](positions.len)
  for i in 0 ..< actions.len:
    actions[i] = passAction()
  let inventories = private{"inventories"}
  let shed = private{"shed"}

  let (animalTiles, freeStructures, empties, herd) = scanFarm(farm, private)

  # Rancher pool: hands 1..r own all animal work. Scale with the herd.
  var nRanchers = 0
  if herd > 0:
    nRanchers = 1 + (if herd >= 6: 1 else: 0) + (if herd >= 11: 1 else: 0)
    nRanchers = min(nRanchers, max(0, positions.len - 1))
  var rancherIdx: seq[int]
  for i in 1 .. nRanchers:
    rancherIdx.add(i)

  let builds = buildJobs(freeStructures, empties, shed, inventories,
                         herd, day)
  let jobs = rankJobs(farm, private, day, totalDays, builds)

  var claimed = initHashSet[Pos]()

  # Ranchers first (they may claim shed-access squares implicitly).
  for k, unit in rancherIdx:
    var inv: JsonNode = nil
    if inventories != nil and unit < inventories.len:
      inv = inventories[unit]
    let action = rancherAction(k, nRanchers, positions[unit], inv,
                               animalTiles, freeStructures, shed,
                               inventories, day, claimed)
    if action != nil:
      actions[unit] = action

  let courier = positions.len - 1
  let maxRancher = (if rancherIdx.len > 0: rancherIdx[^1] else: 0)
  if courier > maxRancher and isPass(actions[courier]):
    var inv: JsonNode = nil
    if inventories != nil and courier < inventories.len:
      inv = inventories[courier]
    let action = courierAction(positions[courier], inv, shed,
                               farm{"tiles"}, day, totalDays, claimed)
    if action != nil:
      actions[courier] = action

  var fieldUnits: seq[int]
  for u in 0 ..< positions.len:
    if u notin rancherIdx or isPass(actions[u]):
      fieldUnits.add(u)
  var exclude = initHashSet[Pos]()
  for (x, y, _) in animalTiles:
    exclude.incl((x, y))
  let zones = makeZones(farm{"tiles"}, fieldUnits.len, exclude)
  for zi, unit in fieldUnits:
    if not isPass(actions[unit]):
      continue
    let useZone = zi < zones.len
    let zone = (if useZone: zones[zi] else: initHashSet[Pos]())
    let (found, job) = bestJob(jobs, claimed, useZone, zone)
    if not found:
      continue
    claimed.incl((job.x, job.y))
    actions[unit] = actOrStep(positions[unit], job)

  for unit in 0 ..< actions.len:
    if not isPass(actions[unit]):
      continue
    let (found, job) = bestJob(jobs, claimed, false, initHashSet[Pos](),
                               true, positions[unit])
    if not found:
      continue
    claimed.incl((job.x, job.y))
    actions[unit] = actOrStep(positions[unit], job)

  # Last-day sweep: carrying units ferry goods to the shed and DROP.
  if day >= totalDays - 1 and hour >= lastDaySweepHour:
    for unit, pos in positions:
      var inv: JsonNode = nil
      if inventories != nil and unit < inventories.len:
        inv = inventories[unit]
      var carrying = false
      if inv != nil and inv.kind == JObject:
        for item, count in inv:
          if not isAnimal(item) and count.getInt() > 0:
            carrying = true
            break
      if not carrying:
        continue
      actions[unit] = (if shedDist(pos) == 0: %*["DROP"]
                       else: %*[stepToward(pos, nearestShedTile(pos))])

  actions

## Market

proc herdSize(farm, private: JsonNode): int =
  for row in farm{"tiles"}:
    for tile in row:
      if tile.kind == JObject and tile{"animal"}.getStr("") != "":
        result.inc()
  let shed = private{"shed"}
  let inventories = private{"inventories"}
  for animal in animalKinds:
    result += shed.getCount(animal)
    if inventories != nil:
      for inv in inventories:
        result += inv.getCount(animal)

proc handTarget(money: float, day: int): int =
  var target: int
  if day >= 29:
    target = liquidationHands
  elif day < openingDays:
    target = openingHands
  else:
    target = targetHands
  if money >= handCashPerDay * 6:
    return target
  let affordable = int(floor(money / handCashPerDay)) + minHands
  max(minHands, min(target, affordable))

proc ranchOrders(farm, private: JsonNode, startMoney: float,
                 day: int): seq[JsonNode] =
  ## Up to animalBuysPerDay animal purchases per day (cash-gated) plus
  ## feed wheat.
  var money = startMoney
  var herd = herdSize(farm, private)
  var free = {"COOP": 0, "PASTURE": 0}.toTable
  for row in farm{"tiles"}:
    for tile in row:
      if tile.kind == JObject and tile{"kind"}.getStr() in ["COOP", "PASTURE"] and
          tile{"animal"}.getStr("") == "":
        free[tile{"kind"}.getStr()] = free[tile{"kind"}.getStr()] + 1
  if ranchStartDay <= day and day <= 24:
    for _ in 0 ..< animalBuysPerDay:
      if herd >= ranchBuildOrder.len:
        break
      let animal = ranchBuildOrder[herd]
      let structure = structureOf(animal)
      if free.getOrDefault(structure, 0) < 1:
        break
      if money < float(animalCost[animal]) + animalCashReserve:
        break
      result.add(%*["BUY_ANIMAL", animal, 1])
      free[structure] = free[structure] - 1
      money -= float(animalCost[animal])
      herd.inc()
    herd = herdSize(farm, private)  # feed sizing: pre-buy herd

  let placed = herd  # close enough for feed sizing
  if placed > 0 and day < 29:
    let shedWheat = private{"shed"}.getCount("WHEAT")
    let need = placed + 2 - shedWheat
    if need > 0 and money > cashReserve:
      result.add(%*["BUY_PRODUCT", "WHEAT", min(need, feedBuyCap)])

proc seedOrders(farm: JsonNode, seeds: JsonNode, money: float,
                day, totalDays: int): seq[JsonNode] =
  let daysLeft = totalDays - day
  var empty = 0
  var planted = 0
  for row in farm{"tiles"}:
    for tile in row:
      if tile.kind == JNull:
        empty.inc()
      elif tile.kind == JObject and tile{"kind"}.getStr() == "PLANT":
        planted.inc()
  var units = 1
  let handsNode = farm{"hands"}
  if handsNode != nil and handsNode.kind == JArray:
    units += handsNode.len
  let workable = max(0, units * tilesPerUnit - planted)

  let wantTotal = min(empty, workable) + seedBuffer
  var heldTotal = 0
  if seeds != nil and seeds.kind == JObject:
    for _, count in seeds:
      heldTotal += count.getInt()
  if heldTotal >= wantTotal:
    return @[]

  var budget = max(0.0, money - cashReserve)
  var mix = cropMix(day, money)
  var longestCycle = 0
  for (crop, _) in mix:
    longestCycle = max(longestCycle, cycleDays[crop])
  if daysLeft <= longestCycle:
    mix = @closingMix
  # Python: sorted(mix.items(), key=-share) — stable; every mix is already
  # declared in descending share order, so iterate as-is.
  for (crop, share) in mix:
    if cycleDays.getOrDefault(crop, 99) > daysLeft:
      continue
    let target = pyRound(float(wantTotal) * share)
    let shortfall = target - seeds.getCount(crop)
    let cost = seedCost[crop]
    let quantity = min(shortfall, int(floor(budget / float(cost))))
    if quantity > 0:
      result.add(%*["BUY_SEED", crop, quantity])
      budget -= float(quantity * cost)

proc sellOrders(shed, prices: JsonNode, hour, turnsPerDay, day, totalDays,
                herd: int, holdFertilizer: bool): seq[JsonNode] =
  let liquidation = day >= totalDays - 1

  let window = max(1, turnsPerDay div 6)
  if hour mod window != 0:
    return @[]
  let slicesPerDay = max(1, turnsPerDay div window)

  var items: seq[string]
  if shed != nil and shed.kind == JObject:
    for item, _ in shed:
      items.add(item)
  items.sort()

  for item in items:
    if isAnimal(item):
      continue  # animals are placed, not sold
    var count = shed.getCount(item)
    if item == "WHEAT" and not liquidation:
      count -= herd + 2  # tomorrow's feed is not for sale
    if item == "FERTILIZER" and holdFertilizer and not liquidation:
      count -= fertStockCap  # worth ~2 strawberries placed, ~$91 sold
      if count <= 0:
        continue
    if count <= 0:
      continue
    let price = prices{item}.getFloat(0.0)
    if liquidation:
      result.add(%*["SELL", item, count])
      continue
    if price <= max(1.0, float(basePrice.getOrDefault(item, 0)) *
                    minSellPriceFraction):
      continue
    let cap = dailySellCap.getOrDefault(item, 10)
    let allowance = (if item == "MELON": count  # the dump
                     else: max(1, (cap + slicesPerDay - 1) div slicesPerDay))
    result.add(%*["SELL", item, min(count, allowance)])
    if result.len >= maxMarketOrders:
      break

proc shouldBuyLand(farm: JsonNode, money: float, day: int): bool =
  if day < earliestLandDay or day > lastLandDay:
    return false
  let quadrants = farm{"unlocked_quadrants"}
  let owned = (if quadrants != nil and quadrants.kind == JArray:
                 quadrants.len else: 0)
  if owned >= maxQuadrants or owned <= 0 or owned > landPrices.len:
    return false
  money >= landPrices[owned - 1] + landCashBuffer

proc marketOrders(obs, farm, private: JsonNode, day, hour, turnsPerDay,
                  totalDays: int): seq[JsonNode] =
  let shed = private{"shed"}
  let seeds = private{"seeds"}
  let prices = obs{"market"}{"prices"}
  let money = farm{"money"}.getFloat()

  if hour == hireHour:
    let missing = handTarget(money, day) - farm{"hires_today"}.getInt(0)
    for _ in 0 ..< max(0, missing):
      result.add(%*["HIRE"])
    if result.len > maxMarketOrders:
      result.setLen(maxMarketOrders)
    return

  if hour == seedHour:
    result.add(seedOrders(farm, seeds, money, day, totalDays))
    if shouldBuyLand(farm, money, day):
      result.add(%*["BUY_LAND"])
    if result.len > maxMarketOrders:
      result.setLen(maxMarketOrders)
    return

  if hour == ranchHour and day < totalDays - 1:
    result.add(ranchOrders(farm, private, money, day))
    if result.len > 0:
      if result.len > maxMarketOrders:
        result.setLen(maxMarketOrders)
      return

  result.add(sellOrders(shed, prices, hour, turnsPerDay, day, totalDays,
                        herdSize(farm, private),
                        fertStillUseful(farm{"tiles"}, day, totalDays)))

## Agent

proc agent(obs, config: JsonNode): JsonNode =
  let farms = obs{"farms"}
  let player = obs{"player"}.getInt(0)
  if farms == nil or farms.kind != JArray or player >= farms.len:
    return %*{"farmer": ["PASS"], "hands": [], "market": []}

  let farm = farms[player]
  let private = obs{"private"}
  let day = obs{"day"}.getInt(0)
  let hour = obs{"hour"}.getInt(0)
  let turnsPerDay = configInt(config, "turnsPerDay", 24)
  let totalDays = max(1, configInt(config, "episodeSteps", 720) div turnsPerDay)

  let unitActions = assignUnits(farm, private, day, totalDays, hour)
  var market = marketOrders(obs, farm, private, day, hour, turnsPerDay,
                            totalDays)
  if market.len > maxMarketOrders:
    market.setLen(maxMarketOrders)

  var hands = newJArray()
  for i in 1 ..< unitActions.len:
    hands.add(unitActions[i])
  var marketNode = newJArray()
  for order in market:
    marketNode.add(order)
  %*{"farmer": unitActions[0], "hands": hands, "market": marketNode}

## Wire protocol

proc main() =
  let client = newCoworldClient("polevik")
  var config = newJObject()
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "handshake":
      config = message{"configuration"}
      if config == nil:
        config = newJObject()
      echo "polevik: seated slot ", message{"slot"}.getInt(),
        " upstream ", message{"upstream_version"}.getStr()
    of "observation":
      let action = agent(message{"observation"}, config)
      client.send(%*{"action": action})
    of "final":
      echo "polevik: final"
      quit(0)
    else:
      discard

main()
