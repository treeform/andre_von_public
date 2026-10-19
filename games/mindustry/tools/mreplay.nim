## Reads Mindustry MDR1 replays: core health, seat commands and turret life.
##
## nim r -d:release tools/mreplay.nim <replay> summary
## nim r -d:release tools/mreplay.nim <replay> seat <slot> [fromTick] [toTick]
## nim r -d:release tools/mreplay.nim <replay> turrets

import
  std/[json, math, os, strutils, tables],
  zippy

type
  ReplayError = object of CatchableError
  Replay = object
    header: JsonNode
    frames: seq[JsonNode]

proc fail(message: string) =
  ## Raises a replay error with a readable message.
  raise newException(ReplayError, message)

proc readReplay(path: string): Replay =
  ## Loads the header and every decompressed frame in tick order.
  let data = readFile(path)
  if data.len < 8 or data[0 ..< 4] != "MDR1":
    fail("Not an MDR1 replay: " & path)
  var size = 0
  for i in 0 ..< 4:
    size = size or (ord(data[4 + i]) shl (i * 8))
  result.header = parseJson(data[8 ..< 8 + size])
  let base = 8 + size
  for chunk in result.header["chunks"]:
    let
      offset = base + chunk["offset"].getInt
      length = chunk["length"].getInt
      text = uncompress(data[offset ..< offset + length], dataFormat = dfGzip)
    for frame in parseJson(text):
      result.frames.add frame

proc value(node: JsonNode): float =
  ## Reads a JSON number of either kind.
  if node.kind == JInt:
    return node.getInt.float
  if node.kind == JFloat:
    return node.getFloat
  0.0

proc itemName(replay: Replay, id: int): string =
  ## Names an item from the replay catalog.
  let items = replay.header["catalog"]["items"]
  if id < 0 or id >= items.len:
    return "none"
  let entry = items[id]
  if entry.kind == JString:
    return entry.getStr
  entry["name"].getStr

proc itemIndex(replay: Replay, name: string): int =
  ## Finds an item's inventory index in the replay catalog.
  let items = replay.header["catalog"]["items"]
  for i in 0 ..< items.len:
    if replay.itemName(i) == name:
      return i
  -1

proc printSummary(replay: Replay) =
  ## Prints the result, core health, stock and building counts over time.
  echo "names: ", replay.header["names"]
  let last = replay.frames[^1]
  echo "ticks: ", last["tick"].value.int, " outcome: ", last["outcome"]
  if last.hasKey("scores"):
    echo "scores: ", last["scores"]
  var
    buildings = initTable[int, JsonNode]()
    nextReport = 0
  let stocks = [replay.itemIndex("copper"), replay.itemIndex("lead"),
    replay.itemIndex("coal"), replay.itemIndex("sand"), replay.itemIndex("silicon")]
  echo "tick  blueCore  redCore  blueDuos  redDuos  blueUnits  redUnits",
    "  | blue cu/pb/coal/sand/si | red cu/pb/coal/sand/si | blue drill/press/hail"
  for frame in replay.frames:
    if frame["keyframe"].getBool:
      buildings.clear()
    for building in frame["buildings"]:
      buildings[building[0].value.int] = building
    for id in frame["removed"]:
      buildings.del(id.value.int)
    let tick = frame["tick"].value.int
    if tick >= nextReport or frame == last:
      var
        cores: array[3, float]
        duos: array[3, int]
        units: array[3, int]
        industry: array[3, int]
      for building in buildings.values:
        let team = building[5].value.int
        if team in 1 .. 2:
          let name = building[1].getStr
          if name.startsWith("core"):
            cores[team] = building[6].value
          elif name == "duo":
            inc duos[team]
          elif team == 1 and name == "mechanical-drill":
            inc industry[0]
          elif team == 1 and name == "graphite-press":
            inc industry[1]
          elif team == 1 and name == "hail":
            inc industry[2]
      var stockText = ""
      for slot in [0, 4]:
        stockText.add " |"
        for index in stocks:
          let inventory = frame["players"][slot]["inventory"]
          let amount = if index >= 0 and index < inventory.len:
              inventory[index].value.int else: 0
          stockText.add " " & $amount
      for unit in frame["units"]:
        let team = unit[6].value.int
        if team in 1 .. 2 and unit[1].getStr != "alpha":
          inc units[team]
      echo align($tick, 5), align($cores[1].int, 10), align($cores[2].int, 9),
        align($duos[1], 10), align($duos[2], 9), align($units[1], 11),
        align($units[2], 10), stockText, " | ", industry[0], "/",
        industry[1], "/", industry[2]
      nextReport = tick + 300

proc printSeat(replay: Replay, slot, first, final: int) =
  ## Prints one seat's body, cargo and non-movement command results.
  for i, frame in replay.frames:
    let tick = frame["tick"].value.int
    if tick < first or tick > final:
      continue
    let player = if frame.hasKey("players"): frame["players"][slot] else: frame
    var line = align($tick, 6) & " pos " &
      formatFloat(player["flyerX"].value, ffDecimal, 1) & "," &
      formatFloat(player["flyerY"].value, ffDecimal, 1) &
      " hp " & $player["flyerHealth"].value.int &
      " carry " & $player["carried"].value.int & " " &
      replay.itemName(player["carriedItem"].value.int) &
      " plans " & $player["pending"].value.int
    if i + 1 < replay.frames.len:
      let commands = replay.frames[i + 1]{"commands"}
      # PvP frames list commands per seat; survival frames are one seat.
      var mine: seq[JsonNode]
      if commands != nil:
        if frame.hasKey("players"):
          if slot < commands.len:
            for command in commands[slot]:
              mine.add command
        else:
          for command in commands:
            mine.add command
      if mine.len > 0:
        for command in mine:
          let name = command[0].getStr
          if name in ["move", "aim", "shoot"] and
            command[^1].getStr == "accepted":
              continue
          var text = name & "("
          for j in 1 ..< command.len - 1:
            if j > 1:
              text.add ","
            text.add $command[j].value.int
          text.add ")=" & command[^1].getStr
          line.add " " & text
    echo line

proc printTurrets(replay: Replay) =
  ## Prints each turret's first sight, ammo peak and removal.
  var
    seen = initTable[int, JsonNode]()
    born = initTable[int, int]()
    peak = initTable[int, int]()
    current = initTable[int, JsonNode]()
  for frame in replay.frames:
    let tick = frame["tick"].value.int
    if frame["keyframe"].getBool:
      # A keyframe lists every building, so missing turrets died at the seam.
      var listed = initTable[int, bool]()
      for building in frame["buildings"]:
        listed[building[0].value.int] = true
      var gone: seq[int]
      for id in seen.keys:
        if not listed.hasKey(id):
          gone.add id
      for id in gone:
        let building = seen[id]
        echo "team ", building[5].value.int, " ", building[1].getStr, " at ",
          building[2].value.int, ",", building[3].value.int, " born ", born[id],
          " gone ", tick, " peak ammo ", peak[id]
        seen.del(id)
      current.clear()
    for building in frame["buildings"]:
      let id = building[0].value.int
      current[id] = building
      let name = building[1].getStr
      if name in ["duo", "hail", "scatter", "arc", "lancer"]:
        if not seen.hasKey(id):
          seen[id] = building
          born[id] = tick
          peak[id] = 0
        peak[id] = max(peak[id], building[11].value.int)
        seen[id] = building
    for removed in frame["removed"]:
      let id = removed.value.int
      if seen.hasKey(id) and current.hasKey(id):
        let building = seen[id]
        echo "team ", building[5].value.int, " ", building[1].getStr, " at ",
          building[2].value.int, ",", building[3].value.int, " born ", born[id],
          " gone ", tick, " peak ammo ", peak[id]
        seen.del(id)
      current.del(id)
  for id, building in seen:
    echo "team ", building[5].value.int, " ", building[1].getStr, " at ",
      building[2].value.int, ",", building[3].value.int, " born ", born[id],
      " alive, ammo ", building[11].value.int, " peak ", peak[id],
      " hp ", building[6].value.int

proc printMap(replay: Replay) =
  ## Prints the blue half of the terrain with ores, sand and walls marked.
  let
    map = replay.header["map"]
    width = map["width"].value.int
    height = map["height"].value.int
  var cells: seq[string]
  for i in countup(0, map["runs"].len - 2, 2):
    let cell = map["palette"][map["runs"][i + 1].value.int].getStr
    for j in 0 ..< map["runs"][i].value.int:
      cells.add cell
  echo "C copper, L lead, K coal, T titanium, S scrap, s sand floor, ",
    "~ water, # wall, o blue core"
  for y in countdown(height - 1, 0):
    var line = align($y, 3) & " "
    for x in 0 ..< width div 2:
      let
        parts = cells[y * width + x].split(':')
        floor = parts[0]
        overlay = parts[1]
        wall = parts[2]
      var c = '.'
      if floor.contains("water"):
        c = '~'
      elif floor.contains("sand"):
        c = 's'
      if overlay == "ore-copper": c = 'C'
      elif overlay == "ore-lead": c = 'L'
      elif overlay == "ore-coal": c = 'K'
      elif overlay == "ore-titanium": c = 'T'
      elif overlay == "ore-scrap": c = 'S'
      if wall != "air":
        c = '#'
      if abs(x - 18) <= 1 and abs(y - height div 2) <= 1:
        c = 'o'
      line.add c
    echo line

proc printOres(replay: Replay) =
  ## Prints each core and the nearest ore of every kind around it.
  let
    map = replay.header["map"]
    width = map["width"].value.int
    height = map["height"].value.int
  var cells: seq[string]
  for i in countup(0, map["runs"].len - 2, 2):
    let cell = map["palette"][map["runs"][i + 1].value.int].getStr
    for j in 0 ..< map["runs"][i].value.int:
      cells.add cell
  echo "map ", map{"name"}.getStr, " ", width, "x", height
  for building in replay.frames[0]["buildings"]:
    if building[1].getStr.startsWith("core"):
      let
        x = building[2].value.int
        y = building[3].value.int
      echo "core team ", building[5].value.int, " ", building[1].getStr,
        " at ", x, ",", y, " hp ", building[6].value.int
      for kind in ["ore-copper", "ore-lead", "ore-coal", "ore-titanium",
          "ore-scrap", "sand"]:
        var
          best = 1_000_000
          bestX, bestY = -1
          near20, near40 = 0
        for j in 0 ..< height:
          for i in 0 ..< width:
            let parts = cells[j * width + i].split(':')
            let hit =
              if kind == "sand": parts[0].contains("sand") and
                not parts[0].contains("water") and parts[2] == "air"
              else: parts[1] == kind and parts[2] == "air"
            if hit:
              let d = (i - x) * (i - x) + (j - y) * (j - y)
              if d < best:
                best = d
                bestX = i
                bestY = j
              if d <= 400: inc near20
              if d <= 1600: inc near40
        echo "  ", align(kind, 12), " nearest ",
          formatFloat(sqrt(best.float), ffDecimal, 1), " at ", bestX, ",",
          bestY, "  tiles within 20: ", near20, "  within 40: ", near40

proc printAt(replay: Replay, x, y, every: int) =
  ## Prints the building anchored at a tile: items, health, progress.
  var
    current = initTable[int, JsonNode]()
    nextReport = 0
  for frame in replay.frames:
    if frame["keyframe"].getBool:
      current.clear()
    for building in frame["buildings"]:
      current[building[0].value.int] = building
    for id in frame["removed"]:
      current.del(id.value.int)
    let tick = frame["tick"].value.int
    if tick >= nextReport:
      nextReport = tick + every
      var line = align($tick, 6) & " "
      var found = false
      for building in current.values:
        if building[2].value.int == x and building[3].value.int == y:
          found = true
          line.add building[1].getStr & " hp " & $building[6].value.int &
            " progress " & formatFloat(building[9].value, ffDecimal, 2) &
            " enabled " & $building[13].value.int & " items"
          let items = building[10]
          for i in 0 ..< items.len:
            if items[i].value > 0:
              line.add " " & replay.itemName(i) & "=" & $items[i].value.int
      if not found:
        line.add "nothing"
      echo line

proc printUnits(replay: Replay, team, tick: int) =
  ## Prints one team's units at the first frame at or after a tick.
  for frame in replay.frames:
    if frame["tick"].value.int >= tick:
      echo "tick ", frame["tick"].value.int
      for unit in frame["units"]:
        if unit[6].value.int == team:
          echo "  ", unit[1].getStr, " id ", unit[0].value.int, " at ",
            formatFloat(unit[2].value, ffDecimal, 1), ",",
            formatFloat(unit[3].value, ffDecimal, 1), " hp ",
            unit[5].value.int, " shooting ", unit[12].value.int,
            " seat ", unit[13].value.int
      return

proc printNear(replay: Replay, x, y, radius, tick: int) =
  ## Prints every building within a radius of a tile at a tick.
  var current = initTable[int, JsonNode]()
  for frame in replay.frames:
    if frame["keyframe"].getBool:
      current.clear()
    for building in frame["buildings"]:
      current[building[0].value.int] = building
    for id in frame["removed"]:
      current.del(id.value.int)
    if frame["tick"].value.int >= tick:
      for building in current.values:
        let
          bx = building[2].value.int
          by = building[3].value.int
        if abs(bx - x) <= radius and abs(by - y) <= radius:
          echo building[1].getStr, " team ", building[5].value.int, " at ",
            bx, ",", by, " hp ", building[6].value.int, " ammo ",
            building[11].value.int
      return

proc printLosses(replay: Replay) =
  ## Lists our buildings that disappear (the bot never deconstructs, so a
  ## missing building was destroyed): tick, block and tile, then totals.
  var
    known = initTable[int, (string, int, int, int, float)]()
    counts = initCountTable[string]()
    lastTick = 0
  for frame in replay.frames:
    let tick = frame["tick"].value.int
    # The replay holds every seat's world in turn; read the first only.
    if tick < lastTick:
      break
    lastTick = tick
    var gone: seq[int]
    if frame["keyframe"].getBool:
      var present = initTable[int, bool]()
      for building in frame["buildings"]:
        present[building[0].value.int] = true
      for id in known.keys:
        if id notin present:
          gone.add id
    else:
      for id in frame["removed"]:
        gone.add id.value.int
    # A site that finishes is removed and its building added on the same
    # tile in the same frame: that is a replacement, not a loss.
    var added = initTable[(string, int, int), bool]()
    for building in frame["buildings"]:
      if building[0].value.int notin known:
        added[(building[1].getStr, building[2].value.int,
          building[3].value.int)] = true
    for id in gone:
      if id in known and (known[id][0], known[id][1], known[id][2]) in added:
        known.del(id)
        continue
      if id in known:
        let (name, x, y, team, progress) = known[id]
        # A finished construction site is replaced, not lost.
        if team == 1 and progress >= 1:
          echo align($tick, 6), " ", name, " at ", x, ",", y
          counts.inc name
        known.del(id)
    for building in frame["buildings"]:
      known[building[0].value.int] = (building[1].getStr,
        building[2].value.int, building[3].value.int, building[5].value.int,
        building[9].value)
  for name, count in counts:
    echo "lost ", count, " ", name

proc idleDrills(live: Table[int, JsonNode], width: int): int =
  ## Counts our finished drills whose output cannot reach the core: no
  ## finished belt chain (conveyors, junctions, routers) from a neighbour
  ## into the core, and no press or generator beside them to feed.
  const Steps = [(1, 0), (0, 1), (-1, 0), (0, -1)]
  var at = initTable[int, JsonNode]()
  for _, building in live:
    if building[5].value.int != 1 or building[9].value < 1.0:
      continue
    let
      size = building[4].value.int
      offset = -(size - 1) div 2
    for j in 0 ..< size:
      for i in 0 ..< size:
        at[(building[3].value.int + offset + j) * width +
          building[2].value.int + offset + i] = building
  proc name(x, y: int): string =
    let key = y * width + x
    if key in at: at[key][1].getStr else: ""
  # Whether items entering a tile, heading one way, reach the core.
  var memo = initTable[(int, int), bool]()
  proc reaches(x, y, heading, depth: int): bool =
    if depth > 4000:
      return false
    let here = name(x, y)
    if here.startsWith("core"):
      return true
    let key = (y * width + x, heading)
    if key in memo:
      return memo[key]
    memo[key] = false
    var ok = false
    case here
    of "conveyor", "titanium-conveyor":
      let rotation = at[y * width + x][7].value.int
      # A belt takes items from behind and from its sides, not its front.
      if rotation != (heading + 2) mod 4:
        let (sx, sy) = Steps[rotation]
        ok = reaches(x + sx, y + sy, rotation, depth + 1)
    of "junction":
      let (sx, sy) = Steps[heading]
      ok = reaches(x + sx, y + sy, heading, depth + 1)
    of "router":
      for rotation, (sx, sy) in Steps:
        if not ok and rotation != (heading + 2) mod 4:
          ok = reaches(x + sx, y + sy, rotation, depth + 1)
    else:
      discard
    memo[key] = ok
    ok
  for _, building in live:
    if building[5].value.int != 1 or building[9].value < 1.0 or
      not building[1].getStr.endsWith("drill"):
        continue
    let
      bx = building[2].value.int
      by = building[3].value.int
      size = building[4].value.int
      offset = -(size - 1) div 2
    var fed = false
    for j in -1 .. size:
      for i in -1 .. size:
        let edge = (i == -1 or i == size) != (j == -1 or j == size)
        if fed or not edge:
          continue
        let
          x = bx + offset + i
          y = by + offset + j
          heading =
            if i == -1: 2
            elif i == size: 0
            elif j == -1: 3
            else: 1
          neighbour = name(x, y)
        if neighbour in ["graphite-press", "combustion-generator",
          "silicon-smelter"] or neighbour.startsWith("core"):
            fed = true
        elif reaches(x, y, heading, 0):
          fed = true
    if not fed:
      inc result

proc printEco(replay: Replay, every: int) =
  ## Survival economy over time: core health, wave, copper, lead and scrap in
  ## stock, gross extraction (stock plus the copper our buildings cost) and
  ## our drill, conveyor and Duo counts.
  var
    live = initTable[int, JsonNode]()
    nextReport = 0
  # Ore under every tile, to report how much of the map the drills cover.
  let map = replay.header["map"]
  let mapWidth = map["width"].value.int
  var ores: seq[bool]
  for i in countup(0, map["runs"].len - 2, 2):
    let overlay = map["palette"][map["runs"][i + 1].value.int].getStr.split(':')[1]
    for j in 0 ..< map["runs"][i].value.int:
      ores.add overlay.startsWith("ore-")
  var oreTotal = 0
  for ore in ores:
    if ore: inc oreTotal
  echo "  tick wave clr   core  copper  lead scrap   gross drills idle belts duos enemies  ore%"
  for frame in replay.frames:
    if frame["keyframe"].getBool:
      live.clear()
    for building in frame["buildings"]:
      live[building[0].value.int] = building
    for id in frame["removed"]:
      live.del(id.value.int)
    let tick = frame["tick"].value.int
    if tick < nextReport or not frame.hasKey("inventory"):
      continue
    nextReport = tick + every
    var drills, belts, duos, invested, enemies, covered: int
    for _, building in live:
      if building[5].value.int != 1:
        continue
      case building[1].getStr
      of "mechanical-drill":
        inc drills
        invested += 12
        for j in 0 .. 1:
          for i in 0 .. 1:
            if ores[(building[3].value.int + j) * mapWidth + building[2].value.int + i]:
              inc covered
      of "conveyor":
        inc belts
        invested += 1
      of "duo":
        inc duos
        invested += 35
      else:
        discard
    for unit in frame["units"]:
      if unit[6].value.int != 1:
        inc enemies
    let inventory = frame["inventory"]
    proc stock(index: int): int =
      if index < inventory.len: inventory[index].value.int else: 0
    echo align($tick, 6), align($frame["wave"].value.int, 5),
      align($frame["cleared"].value.int, 4),
      align($frame["coreHealth"].value.int, 7), align($stock(0), 8),
      align($stock(1), 6), align($stock(8), 6),
      align($(stock(0) + stock(1) + stock(8) + invested), 8),
      align($drills, 7), align($idleDrills(live, mapWidth), 5), align($belts, 6), align($duos, 5),
      align($enemies, 8), align($(covered * 100 div max(1, oreTotal)), 6)

proc printWalls(replay: Replay, step: int) =
  ## Prints the whole map downsampled: # where a step x step block holds a
  ## wall, ~ for deep water, . otherwise; north is up.
  let
    map = replay.header["map"]
    width = map["width"].value.int
    height = map["height"].value.int
  var cells: seq[string]
  for i in countup(0, map["runs"].len - 2, 2):
    let cell = map["palette"][map["runs"][i + 1].value.int].getStr
    for j in 0 ..< map["runs"][i].value.int:
      cells.add cell
  for by in countdown((height - 1) div step, 0):
    var line = align($(by * step), 4) & " "
    for bx in 0 .. (width - 1) div step:
      var c = '.'
      for y in by * step ..< min(height, by * step + step):
        for x in bx * step ..< min(width, bx * step + step):
          let parts = cells[y * width + x].split(':')
          if parts[2].len > 0 and parts[2] != "air":
            c = '#'
          elif c == '.' and parts[0].contains("deep"):
            c = '~'
      line.add c
    echo line

proc main() =
  ## Dispatches one inspection mode.
  let args = commandLineParams()
  if args.len < 2:
    fail("Usage: mreplay <replay> summary|seat <slot> [from] [to]|turrets")
  let replay = readReplay(args[0])
  case args[1]
  of "summary":
    replay.printSummary()
  of "seat":
    let
      slot = args[2].parseInt
      first = if args.len > 3: args[3].parseInt else: 0
      final = if args.len > 4: args[4].parseInt else: 1_000_000
    replay.printSeat(slot, first, final)
  of "turrets":
    replay.printTurrets()
  of "map":
    replay.printMap()
  of "ores":
    replay.printOres()
  of "near":
    replay.printNear(args[2].parseInt, args[3].parseInt, args[4].parseInt,
      args[5].parseInt)
  of "units":
    replay.printUnits(args[2].parseInt, args[3].parseInt)
  of "at":
    replay.printAt(args[2].parseInt, args[3].parseInt,
      if args.len > 4: args[4].parseInt else: 600)
  of "losses":
    replay.printLosses()
  of "eco":
    replay.printEco(if args.len > 2: args[2].parseInt else: 1800)
  of "walls":
    replay.printWalls(if args.len > 2: args[2].parseInt else: 3)
  of "catalog":
    for section, entries in replay.header["catalog"]:
      if entries.kind == JArray:
        for entry in entries:
          if args[2] in $entry:
            echo section, ": ", entry
  else:
    fail("Unknown mode: " & args[1])

main()
