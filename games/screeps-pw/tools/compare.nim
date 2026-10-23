## Compares policies across many Screeps PW replays in one table: a stat
## per row, a policy per column (ours first), grouped into stats we
## control directly, stats we control indirectly, and outcomes. Writes
## an HTML table where rows out of line with the rivals are tinted red.
## Usage: nim r tools/compare.nim <out.html> <name=replay:seat> ...
## Several entries may share a name; their stats are averaged.

import
  std/[algorithm, json, os, strformat, strutils, tables, times],
  replays

type
  Creep = object
    body: string
    born: int
    died: int
    harvest: int
    upgrade: int
    firstHarvest: int
    firstUpgrade: int
    moved: int
  Stats = OrderedTable[string, float]

proc bodyCode(entity: JsonNode): string =
  ## Compresses a body into letters, W for work, C carry, M move.
  for part in entity["body"]:
    result.add toUpperAscii(part["type"].getStr[0])

proc isObject(node: JsonNode): bool =
  ## True for a present JSON object.
  not node.isNil and node.kind == JObject

proc extract(path: string, seat: int): Stats =
  ## Reads one seat of a replay into named stats.
  var replay = openReplay(readFile(path))
  let user = replay.header["metadata"]["accounts"][seat]["user"].getStr
  var creeps: OrderedTable[string, Creep]
  var home = ""
  var spawnPos = (-1, -1)
  var controllerPos = (-1, -1)
  var sourcePos: seq[(int, int)]
  var previous: Table[string, int]
  var lastPos: Table[string, (int, int)]
  var lastStore: Table[string, int]
  var harvested, leftAtRegen, decaySource, decayPile = 0
  var spawnFullTicks = 0
  var tenWorkTick = -1
  var gcl500, gcl1000 = 0.0
  var hauler = {"moveLoaded": 0, "moveEmpty": 0, "waitStation": 0,
    "waitPile": 0, "waitRoad": 0, "waitSpawn": 0}.toTable
  var finalInventory = 0
  var upgraderPosted = 0
  var upgraderIdle = 0
  for tick in 0 .. replay.lastTick:
    let state = replay.stateAt(tick)
    var spawnEnergy = 0
    var standing: Table[(int, int), string]
    for id, entity in state.objects:
      let kind = entity.getOrDefault("type").getStr
      if kind == "spawn" and entity.getOrDefault("user").getStr == user:
        home = entity["room"].getStr
        spawnPos = (entity["x"].getInt, entity["y"].getInt)
        spawnEnergy = entity["store"].getOrDefault("energy").getInt
      if kind == "creep" and entity.getOrDefault("room").getStr == home:
        standing[(entity["x"].getInt, entity["y"].getInt)] = entity["name"].getStr
    if spawnEnergy >= 300: inc spawnFullTicks
    var carried = 0
    var drops = 0
    var sourceWork = 0
    for id, entity in state.objects:
      let kind = entity.getOrDefault("type").getStr
      let room = entity.getOrDefault("room").getStr
      case kind
      of "creep":
        if entity.getOrDefault("user").getStr != user: continue
        let name = entity["name"].getStr
        if not creeps.hasKey(name):
          creeps[name] = Creep(body: bodyCode(entity), born: tick)
        creeps[name].died = tick
        if entity.getOrDefault("spawning").getBool: continue
        let store = entity.getOrDefault("store")
        let energy = if store.isObject: store.getOrDefault("energy").getInt else: 0
        carried += energy
        let log = entity.getOrDefault("actionLog")
        if log.isObject:
          if log.getOrDefault("harvest").isObject:
            if creeps[name].harvest == 0: creeps[name].firstHarvest = tick
            inc creeps[name].harvest
            sourceWork += creeps[name].body.count('W')
          if log.getOrDefault("upgradeController").isObject:
            if creeps[name].upgrade == 0: creeps[name].firstUpgrade = tick
            inc creeps[name].upgrade
        if 'W' notin creeps[name].body:
          # Hauler accounting: energy received and where its ticks go.
          if energy > lastStore.getOrDefault(name, 0):
            creeps[name].moved += energy - lastStore.getOrDefault(name, 0)
          lastStore[name] = energy
          let x = entity["x"].getInt
          let y = entity["y"].getInt
          let moved = lastPos.hasKey(name) and lastPos[name] != (x, y)
          lastPos[name] = (x, y)
          if moved:
            if energy > 0: inc hauler["moveLoaded"] else: inc hauler["moveEmpty"]
          else:
            var place = "waitRoad"
            for sp in sourcePos:
              if max(abs(sp[0] - x), abs(sp[1] - y)) <= 2: place = "waitStation"
            if max(abs(controllerPos[0] - x), abs(controllerPos[1] - y)) <= 4:
              place = "waitPile"
            if max(abs(spawnPos[0] - x), abs(spawnPos[1] - y)) <= 1:
              place = "waitSpawn"
            inc hauler[place]
        elif creeps[name].upgrade > 0:
          inc upgraderPosted
          if not (log.isObject and log.getOrDefault("upgradeController").isObject):
            inc upgraderIdle
      of "source":
        if room == home:
          let energy = entity["energy"].getInt
          if tick == 0: sourcePos.add (entity["x"].getInt, entity["y"].getInt)
          if previous.hasKey(id):
            if energy < previous[id]: harvested += previous[id] - energy
            elif energy > previous[id]: leftAtRegen += previous[id]
          previous[id] = energy
      of "energy":
        if room == home:
          let amount = entity["energy"].getInt
          drops += amount
          let d = (amount + 999) div 1000
          let x = entity["x"].getInt
          let y = entity["y"].getInt
          if max(abs(controllerPos[0] - x), abs(controllerPos[1] - y)) <= 4:
            decayPile += d
          else:
            decaySource += d
      of "controller":
        if room == home: controllerPos = (entity["x"].getInt, entity["y"].getInt)
      else:
        discard
    if sourceWork >= 10 and tenWorkTick < 0: tenWorkTick = tick
    if tick == 500: gcl500 = state.scores[seat].getFloat
    if tick == 1000: gcl1000 = state.scores[seat].getFloat
    if tick == replay.lastTick:
      finalInventory = carried + drops + spawnEnergy
  var miners, haulers, upgraders, minerWork, upgradeWork, haulCarry = 0
  var bodies, hauled = 0
  var towMiner, towUpgrader = 0
  var firstMiner, firstHauler, firstUpgrader = -1
  for name, creep in creeps:
    for part in creep.body:
      bodies += (if part == 'W': 100 else: 50)
    if creep.harvest > 0:
      inc miners
      minerWork += creep.body.count('W')
      towMiner += creep.firstHarvest - creep.born
      if firstMiner < 0: firstMiner = creep.born
    elif creep.upgrade > 0:
      inc upgraders
      upgradeWork += creep.body.count('W')
      towUpgrader += creep.firstUpgrade - creep.born
      if firstUpgrader < 0: firstUpgrader = creep.born
    else:
      inc haulers
      haulCarry += creep.body.count('C') * 50
      hauled += creep.moved
      if firstHauler < 0: firstHauler = creep.born
  let final = replay.header["results"]["scores"][seat].getFloat
  result = initOrderedTable[string, float]()
  # Direct control: what the script decides.
  result["first miner spawn tick"] = firstMiner.float
  result["first hauler spawn tick"] = firstHauler.float
  result["first upgrader spawn tick"] = firstUpgrader.float
  result["tick reaching 10 harvest WORK"] = tenWorkTick.float
  result["miners spawned"] = miners.float
  result["haulers spawned"] = haulers.float
  result["upgraders spawned"] = upgraders.float
  result["miner WORK parts"] = minerWork.float
  result["upgrader WORK parts"] = upgradeWork.float
  result["hauler CARRY capacity"] = haulCarry.float
  result["creeps with CARRY among miners"] = 0.0
  for name, creep in creeps:
    if creep.harvest > 0 and 'C' in creep.body:
      result["creeps with CARRY among miners"] += 1
  result["miner spawn to first harvest ticks"] =
    (if miners > 0: towMiner / miners else: 0.0)
  result["upgrader spawn to first upgrade ticks"] =
    (if upgraders > 0: towUpgrader / upgraders else: 0.0)
  result["hauler ticks moving loaded"] = hauler["moveLoaded"].float
  result["hauler ticks moving empty"] = hauler["moveEmpty"].float
  result["hauler ticks waiting at stations"] = hauler["waitStation"].float
  result["hauler ticks waiting at the controller"] = hauler["waitPile"].float
  result["hauler ticks waiting on the road"] = hauler["waitRoad"].float
  result["hauler ticks waiting at the spawn"] = hauler["waitSpawn"].float
  # Semi-indirect: what the economy yields given those decisions.
  result["energy harvested"] = harvested.float
  result["energy hauled"] = hauled.float
  result["hauled per CARRY per tick"] =
    (if haulCarry > 0: hauled.float / haulCarry.float / replay.lastTick.float * 100 else: 0.0)
  result["energy spent on bodies"] = bodies.float
  result["energy left at source regen"] = leftAtRegen.float
  result["decay at sources"] = decaySource.float
  result["decay at the controller"] = decayPile.float
  result["spawn full ticks (regen lost)"] = spawnFullTicks.float
  result["upgrader idle share (percent)"] =
    (if upgraderPosted > 0: upgraderIdle.float / upgraderPosted.float * 100 else: 0.0)
  result["energy left at the end"] = finalInventory.float
  # Indirect: outcomes.
  result["GCL at tick 500"] = gcl500
  result["GCL at tick 1000"] = gcl1000
  result["GCL final"] = final

const
  Groups = [
    ("Direct control (what the script decides)", @[
      "first miner spawn tick", "first hauler spawn tick",
      "first upgrader spawn tick", "tick reaching 10 harvest WORK",
      "miners spawned", "haulers spawned", "upgraders spawned",
      "miner WORK parts", "upgrader WORK parts", "hauler CARRY capacity",
      "creeps with CARRY among miners", "miner spawn to first harvest ticks",
      "upgrader spawn to first upgrade ticks", "hauler ticks moving loaded",
      "hauler ticks moving empty", "hauler ticks waiting at stations",
      "hauler ticks waiting at the controller",
      "hauler ticks waiting on the road", "hauler ticks waiting at the spawn"]),
    ("Semi-indirect (what the economy yields)", @[
      "energy harvested", "energy hauled", "hauled per CARRY per tick",
      "energy spent on bodies", "energy left at source regen",
      "decay at sources", "decay at the controller",
      "spawn full ticks (regen lost)", "upgrader idle share (percent)",
      "energy left at the end"]),
    ("Indirect (outcomes)", @["GCL at tick 500", "GCL at tick 1000", "GCL final"])
  ]

proc main() =
  let output = paramStr(1)
  var names: seq[string]
  var sums: Table[string, Stats]
  var counts: Table[string, int]
  for i in 2 .. paramCount():
    let arg = paramStr(i)
    let name = arg[0 ..< arg.find('=')]
    let spec = arg[arg.find('=') + 1 .. ^1]
    let path = spec[0 ..< spec.rfind(':')]
    let seat = parseInt(spec[spec.rfind(':') + 1 .. ^1])
    stderr.writeLine &"extracting {name} seat {seat} from {path}"
    let stats = extract(path, seat)
    if name notin names: names.add name
    if not sums.hasKey(name):
      sums[name] = initOrderedTable[string, float]()
      counts[name] = 0
    for key, value in stats:
      sums[name][key] = sums[name].getOrDefault(key) + value
    inc counts[name]
  var html = """<!doctype html>
<html><head><meta charset="utf-8"><title>Screeps PW stats</title>
<style>
body { font: 14px/1.4 -apple-system, Helvetica, sans-serif; margin: 24px; color: #222; }
table { border-collapse: collapse; }
th, td { padding: 4px 12px; text-align: right; border-bottom: 1px solid #ddd; }
th:first-child, td:first-child { text-align: left; }
th.group { text-align: left; background: #eee; padding-top: 14px; }
tr.off td { background: #f8e0e0; }
tr.off td:first-child { color: #a00; }
td.ours { font-weight: 600; }
</style></head><body>
"""
  html.add &"<h2>Screeps PW: {names[0]} vs {names[1 .. ^1].join(\", \")}</h2>\n"
  html.add "<p>Averages over each policy's seats. Red rows: ours is below 0.67x or above 1.5x the rivals' mean.</p>\n"
  html.add "<table>\n<tr><th>stat</th>"
  for name in names: html.add &"<th>{name}</th>"
  html.add "</tr>\n"
  var text = ""
  for (title, keys) in Groups:
    html.add &"<tr><th class=\"group\" colspan=\"{names.len + 1}\">{title}</th></tr>\n"
    text.add "\n" & title & "\n"
    for key in keys:
      var values: seq[float]
      for name in names:
        values.add sums[name].getOrDefault(key) / max(1, counts[name]).float
      var rivals = 0.0
      for v in values[1 .. ^1]: rivals += v
      rivals /= max(1, values.len - 1).float
      let ours = values[0]
      let off = rivals != 0 and (ours < 0.67 * rivals or ours > 1.5 * rivals) or
        rivals == 0 and ours != 0
      html.add (if off: "<tr class=\"off\">" else: "<tr>")
      html.add &"<td>{key}</td>"
      for i, v in values:
        let cell = v.formatFloat(ffDecimal, if v == v.int.float: 0 else: 1)
        html.add (if i == 0: &"<td class=\"ours\">{cell}</td>" else: &"<td>{cell}</td>")
      html.add "</tr>\n"
      var line = (if off: "! " else: "  ") & key.alignLeft(42)
      for v in values: line.add v.formatFloat(ffDecimal, 1).align(10)
      text.add line & "\n"
  html.add "</table>\n"
  html.add &"<p>Generated {now().format(\"yyyy-MM-dd HH:mm\")}.</p>\n</body></html>\n"
  writeFile(output, html)
  echo text
  echo "wrote ", output

main()
