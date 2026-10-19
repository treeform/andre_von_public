## Attributes the damage a side takes in a Mindustry replay to its shooters.
##
## nim r -d:release tools/mdamage.nim <replay> <fromTick> <toTick> [targets] [team]
##
## Every bullet is traced back to where it was first seen, and the turret or
## unit of the other side standing within six tiles of that spot is its
## shooter (walls and other blocks do not shoot). A health drop is charged to
## the bullets of the other side that vanished within four tiles of the
## victim in that frame (split evenly), else to the nearest enemy turret or
## unit within eight tiles ("near:" a flame or laser leaves no bullet).
## Targets are unit types separated by commas (all units by default) or
## "buildings"; the team is the victim (1, ours, by default; 2 is the
## enemy). It prints damage and kills by shooter and where each kill was.

import
  std/[json, math, os, strutils, tables],
  zippy

const
  Turrets = ["duo", "hail", "lancer", "scatter", "salvo", "ripple", "arc",
    "scorch", "wave", "fuse", "segment", "parallax", "swarmer", "cyclone",
    "tsunami", "spectre", "meltdown", "foreshadow"]

type
  DamageError = object of CatchableError
  Shot = object
    x, y: float
    shooter: string
  Life = object
    health, x, y: float
    kind: string

proc fail(message: string) =
  ## Raises a damage error with a readable message.
  raise newException(DamageError, message)

proc shooterNear(
  x, y, radius: float,
  victim: int,
  buildings: Table[int, JsonNode],
  units: JsonNode
): string =
  ## Names the turret or unit not of the victim's side nearest a point.
  var best = radius
  result = "unknown"
  for _, b in buildings:
    let team = b[5].getFloat.int
    if team != 0 and team != victim and b[1].getStr in Turrets:
      let d = hypot(b[2].getFloat - x, b[3].getFloat - y) -
        b[4].getFloat / 2
      if d < best:
        best = d
        result = b[1].getStr
  for u in units:
    let team = u[6].getFloat.int
    if team != 0 and team != victim:
      let d = hypot(u[2].getFloat - x, u[3].getFloat - y)
      if d < best:
        best = d
        result = u[1].getStr

proc main() =
  ## Reads the replay chunk by chunk and prints the attribution.
  if paramCount() < 3:
    fail("Usage: mdamage <replay> <fromTick> <toTick> [targets] [team]")
  let
    data = readFile(paramStr(1))
    fromTick = paramStr(2).parseInt
    toTick = paramStr(3).parseInt
    targets =
      if paramCount() >= 4: paramStr(4).split(',')
      else: @[]
    buildingsMode = targets == @["buildings"]
    victim =
      if paramCount() >= 5: paramStr(5).parseInt
      else: 1
  if data.len < 8 or data[0 ..< 4] != "MDR1":
    fail("Not an MDR1 replay: " & paramStr(1))
  var size = 0
  for i in 0 ..< 4:
    size = size or (ord(data[4 + i]) shl (i * 8))
  let header = parseJson(data[8 ..< 8 + size])
  var
    live = initTable[int, JsonNode]()
    shots = initTable[int, Shot]()
    lives = initTable[int, Life]()
    damage = initCountTable[string]()
    kills = initCountTable[string]()
    places: seq[string]
  block scan:
    for chunk in header["chunks"]:
      let start = 8 + size + chunk["offset"].getInt
      var text = ""
      try:
        text = uncompress(
          data[start ..< start + chunk["length"].getInt],
          dataFormat = dfGzip
        )
      except ZippyError:
        continue
      for frame in parseJson(text):
        let
          tick = frame["tick"].getFloat.int
          keyframe = frame["keyframe"].getBool
        if tick > toTick:
          break scan
        if keyframe:
          live.clear()
        var
          changed: seq[(JsonNode, JsonNode)]
          lost: seq[JsonNode]
        for b in frame["buildings"]:
          let id = b[0].getFloat.int
          if id in live and not keyframe:
            changed.add (live[id], b)
          live[id] = b
        for id in frame["removed"]:
          let key = id.getFloat.int
          if key in live:
            lost.add live[key]
          live.del(key)
        let units = frame["units"]
        # The other side's bullets: a new one gets its shooter.
        var now = initTable[int, Shot]()
        for b in frame["bullets"]:
          let team = b[4].getFloat.int
          if team != 0 and team != victim:
            let id = b[0].getFloat.int
            if id in shots:
              var shot = shots[id]
              shot.x = b[1].getFloat
              shot.y = b[2].getFloat
              now[id] = shot
            else:
              now[id] = Shot(
                x: b[1].getFloat,
                y: b[2].getFloat,
                shooter: shooterNear(b[1].getFloat, b[2].getFloat, 6,
                  victim, live, units)
              )
        var gone: seq[Shot]
        for id, shot in shots:
          if id notin now:
            gone.add shot
        shots = now
        if tick < fromTick:
          lives.clear()
          for u in units:
            if u[6].getFloat.int == victim:
              lives[u[0].getFloat.int] = Life(health: u[5].getFloat,
                x: u[2].getFloat, y: u[3].getFloat, kind: u[1].getStr)
          continue

        proc charge(amount, x, y, reach: float, died: bool) =
          ## Splits a health loss over the bullets that ended near it.
          var near: seq[string]
          for shot in gone:
            if hypot(shot.x - x, shot.y - y) <= reach:
              near.add shot.shooter
          if near.len == 0:
            near.add "near:" & shooterNear(x, y, 8, victim, live, units)
          # A removal with nobody near is our own (an upgrade or a clear).
          if died and near == @["near:unknown"]:
            return
          for name in near:
            damage.inc(name, max(1, int(amount / near.len.float)))
          if died:
            var counts = initCountTable[string]()
            for name in near:
              counts.inc name
            counts.sort()
            var killer = ""
            for name in counts.keys:
              killer = name
              break
            kills.inc killer
            places.add $tick & " " & $x.int & "," & $y.int & " " & killer

        if buildingsMode:
          for (old, b) in changed:
            if b[5].getFloat.int == victim and
                b[6].getFloat < old[6].getFloat - 0.5:
              charge(old[6].getFloat - b[6].getFloat, b[2].getFloat,
                b[3].getFloat, 4 + b[4].getFloat / 2, false)
          for old in lost:
            if old[5].getFloat.int == victim:
              charge(old[6].getFloat, old[2].getFloat, old[3].getFloat,
                4 + old[4].getFloat / 2, true)
          continue
        var seen = initTable[int, bool]()
        for u in units:
          if u[6].getFloat.int != victim:
            continue
          let
            id = u[0].getFloat.int
            kind = u[1].getStr
            health = u[5].getFloat
          seen[id] = true
          if id in lives and (targets.len == 0 or kind in targets):
            let before = lives[id].health
            if health < before - 0.5:
              charge(before - health, u[2].getFloat, u[3].getFloat, 4,
                false)
          lives[id] = Life(health: health, x: u[2].getFloat,
            y: u[3].getFloat, kind: kind)
        var dead: seq[int]
        for id, life in lives:
          if id notin seen:
            dead.add id
            if targets.len == 0 or life.kind in targets:
              charge(life.health, life.x, life.y, 4, true)
        for id in dead:
          lives.del id
  damage.sort()
  kills.sort()
  echo "damage by shooter: ", damage
  echo "kills by shooter: ", kills
  for place in places:
    echo "  kill ", place

main()
