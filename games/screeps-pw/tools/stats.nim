## Extracts one seat's economy from a Screeps PW replay: score curve,
## creep roster with bodies and spawn ticks, and keyframe snapshots of
## sources, drops, spawn energy and controller progress.
## Usage: nim r tools/stats.nim FILE [seat] [every]

import
  std/[algorithm, json, os, strutils, tables],
  replays

type
  CreepInfo = object
    name: string
    body: string
    born: int
    died: int
    harvest: int
    upgrade: int
    moved: int
    first: int
    room: string

proc bodyCode(entity: JsonNode): string =
  ## Compresses a body into letters, W for work, C carry, M move.
  for part in entity["body"]:
    let kind = part["type"].getStr
    result.add toUpperAscii(kind[0])

proc main() =
  var replay = openReplay(readFile(paramStr(1)))
  let seat = if paramCount() >= 2: parseInt(paramStr(2)) else: 0
  let every = if paramCount() >= 3: parseInt(paramStr(3)) else: 100
  var detail = -1
  var track = ""
  if paramCount() >= 4:
    if paramStr(4)[0].isDigit: detail = parseInt(paramStr(4))
    else: track = paramStr(4)
  let user = replay.header["metadata"]["accounts"][seat]["user"].getStr
  let name = replay.header["metadata"]["config"]["players"][seat]["name"].getStr
  echo "seat ", seat, " ", name, " final ",
    replay.header["results"]["scores"][seat]
  var creeps: OrderedTable[string, CreepInfo]
  var home = ""
  var harvested = 0
  var wasted = 0
  var regen = 0
  var previous: Table[string, int]
  var decayTotal = 0
  var decayAt = {"source": 0, "pile": 0, "other": 0}.toTable
  var sourcePos: seq[(int, int)]
  var controllerPos = (-1, -1)
  var spawnPos = (-1, -1)
  var budget: Table[string, Table[string, int]]
  var decayBy: Table[string, int]
  var standing: Table[(int, int), string]
  var lastPos: Table[string, (int, int)]
  var window = (harvest: 0, bodies: 0, decay: 0, gcl: 0, inventory: 0)
  var lastGcl = 0
  var lastInventory = 0
  var known: Table[string, bool]
  echo "ledger: harvest bodies gcl decay inventoryDelta (per window)"
  for tick in 0 .. replay.lastTick:
    let state = replay.stateAt(tick)
    var
      sources: seq[string]
      drops = 0
      dropCount = 0
      spawnEnergy = 0
      spawning = ""
      level = 0
      progress = 0
      alive = 0
      carried = 0
      harvesting = 0
      upgrading = 0
    for id, entity in state.objects:
      let kind = entity.getOrDefault("type").getStr
      if kind == "spawn" and entity.getOrDefault("user").getStr == user:
        home = entity["room"].getStr
        spawnPos = (entity["x"].getInt, entity["y"].getInt)
        spawnEnergy = entity["store"].getOrDefault("energy").getInt
        if entity.hasKey("spawning") and entity["spawning"].kind == JObject:
          spawning = entity["spawning"].getOrDefault("name").getStr
    standing.clear()
    for id, entity in state.objects:
      if entity.getOrDefault("type").getStr == "creep" and
          entity.getOrDefault("room").getStr == home:
        standing[(entity["x"].getInt, entity["y"].getInt)] = entity["name"].getStr
    for id, entity in state.objects:
      let kind = entity.getOrDefault("type").getStr
      let room = entity.getOrDefault("room").getStr
      case kind
      of "creep":
        if entity.getOrDefault("user").getStr != user:
          continue
        inc alive
        let creepName = entity["name"].getStr
        if not creeps.hasKey(creepName):
          creeps[creepName] = CreepInfo(name: creepName, body: bodyCode(entity),
            born: tick, room: room)
          for part in creeps[creepName].body:
            window.bodies += (if part == 'W': 100 else: 50)
        creeps[creepName].died = tick
        if entity.getOrDefault("spawning").getBool:
          continue
        let stored = entity["store"].getOrDefault("energy").getInt
        carried += stored
        if 'W' notin creeps[creepName].body:
          let x = entity["x"].getInt
          let y = entity["y"].getInt
          let moved = lastPos.hasKey(creepName) and lastPos[creepName] != (x, y)
          lastPos[creepName] = (x, y)
          var place = "road"
          for sp in sourcePos:
            if max(abs(sp[0] - x), abs(sp[1] - y)) <= 2: place = "station"
          if max(abs(controllerPos[0] - x), abs(controllerPos[1] - y)) <= 4: place = "pile"
          if max(abs(spawnPos[0] - x), abs(spawnPos[1] - y)) <= 1: place = "spawn"
          let state = (if moved: "move" else: "wait") & "-" & place &
            (if stored > 0: "-loaded" else: "-empty")
          if not budget.hasKey(creepName): budget[creepName] = initTable[string, int]()
          budget[creepName][state] = budget[creepName].getOrDefault(state) + 1
        if stored > creeps[creepName].harvest and 'W' notin creeps[creepName].body:
          creeps[creepName].moved += stored - creeps[creepName].harvest
        if 'W' notin creeps[creepName].body: creeps[creepName].harvest = stored
        let log = entity.getOrDefault("actionLog")
        if not log.isNil and log.kind == JObject:
          if not log.getOrDefault("harvest").isNil and log.getOrDefault("harvest").kind == JObject:
            inc harvesting
            if creeps[creepName].harvest == 0: creeps[creepName].first = tick
            inc creeps[creepName].harvest
          if not log.getOrDefault("upgradeController").isNil and log.getOrDefault("upgradeController").kind == JObject:
            inc upgrading
            if creeps[creepName].upgrade == 0: creeps[creepName].first = tick
            inc creeps[creepName].upgrade
      of "source":
        if room == home:
          let energy = entity["energy"].getInt
          if previous.hasKey(id):
            if energy < previous[id]:
              harvested += previous[id] - energy
              window.harvest += previous[id] - energy
            elif energy > previous[id]:
              wasted += previous[id]
              inc regen
          previous[id] = energy
          sources.add $energy & "/" &
            $entity.getOrDefault("ticksToRegeneration").getInt
          if tick == 0: sourcePos.add (entity["x"].getInt, entity["y"].getInt)
      of "energy":
        if room == home:
          drops += entity["energy"].getInt
          inc dropCount
          let d = (entity["energy"].getInt + 999) div 1000
          window.decay += d
          let x = entity["x"].getInt
          let y = entity["y"].getInt
          var place = "other"
          for sp in sourcePos:
            if max(abs(sp[0] - x), abs(sp[1] - y)) <= 2: place = "source"
          if max(abs(controllerPos[0] - x), abs(controllerPos[1] - y)) <= 4:
            place = "pile"
          decayAt[place] += d
          let who = standing.getOrDefault((x, y), place)
          decayBy[who] = decayBy.getOrDefault(who) + d
      of "controller":
        if room == home:
          level = entity.getOrDefault("level").getInt
          progress = entity.getOrDefault("progress").getInt
          controllerPos = (entity["x"].getInt, entity["y"].getInt)
      else:
        discard
    if track != "":
      for id, entity in state.objects:
        if entity.getOrDefault("type").getStr == "creep" and
            entity.getOrDefault("name").getStr == track:
          let log = entity.getOrDefault("actionLog")
          var acts = ""
          if not log.isNil and log.kind == JObject:
            for key, value in log:
              if not value.isNil and value.kind == JObject: acts.add key & " "
          let store = entity.getOrDefault("store")
          let energy = if not store.isNil and store.kind == JObject: store.getOrDefault("energy").getInt else: 0
          echo "t=", tick, " ", entity.getOrDefault("x").getInt, ",",
            entity.getOrDefault("y").getInt, " store=", energy,
            " fatigue=", entity.getOrDefault("fatigue").getInt, " ", acts
    if tick == detail:
      for id, entity in state.objects:
        let kind = entity.getOrDefault("type").getStr
        if entity.getOrDefault("room").getStr != home: continue
        if kind == "creep" and entity.getOrDefault("user").getStr == user:
          let log = entity.getOrDefault("actionLog")
          var acts = ""
          if not log.isNil and log.kind == JObject:
            for key, value in log:
              if not value.isNil and value.kind == JObject: acts.add key & " "
          let store = entity.getOrDefault("store")
          let energy = if not store.isNil and store.kind == JObject: store.getOrDefault("energy").getInt else: 0
          echo "  creep ", entity["name"].getStr, " ", bodyCode(entity), " at ",
            entity.getOrDefault("x").getInt, ",", entity.getOrDefault("y").getInt, " store=",
            energy, " fatigue=",
            entity.getOrDefault("fatigue").getInt, " ", acts
        elif kind == "energy":
          echo "  drop ", entity["x"].getInt, ",", entity["y"].getInt, " ",
            entity["energy"].getInt
    if tick mod every == 0 or tick == replay.lastTick:
      let gcl = state.scores[seat].getFloat.int
      let inventory = carried + drops + spawnEnergy
      if tick > 0:
        echo "ledger t=", tick, " harvest=", window.harvest, " bodies=",
          window.bodies, " gcl=", gcl - lastGcl, " decay=", window.decay,
          " inventory=", inventory - lastInventory, " unexplained=",
          window.harvest - window.bodies - (gcl - lastGcl) - window.decay -
          (inventory - lastInventory)
      decayTotal += window.decay
      window = (harvest: 0, bodies: 0, decay: 0, gcl: 0, inventory: 0)
      lastGcl = gcl
      lastInventory = inventory
      sources.sort()
      echo "t=", tick, " gcl=", state.scores[seat].getFloat.int,
        " rcl=", level, "+", progress, " spawn=", spawnEnergy,
        (if spawning != "": "(" & spawning & ")" else: ""),
        " creeps=", alive, " carried=", carried,
        " harvesting=", harvesting, " upgrading=", upgrading,
        " drops=", drops, "x", dropCount, " sources=", sources.join(" ")
  var spent = 0
  for name, info in creeps:
    for part in info.body:
      spent += (if part == 'W': 100 elif part == 'C': 50 elif part == 'M': 50 else: 100)
  echo "harvested=", harvested, " regens=", regen, " leftAtRegen=", wasted,
    " bodies=", spent, " creeps=", creeps.len, " decay=", decayTotal
  echo "roster (born-died body harvestTicks upgradeTicks name):"
  var moved = 0
  for name, info in creeps:
    if 'W' notin info.body:
      moved += info.moved
      echo "  ", info.born, "-", info.died, " ", info.body, " moved", info.moved,
        " perTick", (info.moved.float / max(1, info.died - info.born).float).formatFloat(ffDecimal, 2),
        " ", info.name
    else:
      echo "  ", info.born, "-", info.died, " ", info.body, " h", info.harvest,
        " first", info.first, " u", info.upgrade, " ", info.name, " ", info.room
  var idle = 0
  var towing = 0
  for name, info in creeps:
    if info.upgrade > 0:
      idle += info.died - info.first - info.upgrade
      towing += info.first - info.born
  echo "upgraderIdleTicks=", idle, " upgraderTowTicks=", towing
  echo "hauled=", moved
  echo "decayAt=", decayAt
  echo "decayBy=", decayBy
  var total: Table[string, int]
  for name, states in budget:
    for state, n in states: total[state] = total.getOrDefault(state) + n
  var keys: seq[string]
  for k in total.keys: keys.add k
  keys.sort()
  var line = "haulerTicks:"
  for k in keys: line.add " " & k & "=" & $total[k]
  echo line

main()
