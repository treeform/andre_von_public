## Match timeline from a GotA replay: structure kills, hero deaths, levels
## per minute, and the end. Usage: nim r tmp/gota_timeline/timeline.nim PATH
import std/[os, strformat, strutils, tables]
import polyworld/tapes
import maps, replays, sim, events

let path = paramStr(1)
let trackId = if paramCount() >= 2: parseInt(paramStr(2)) else: -1
let interval = if paramCount() >= 3: parseInt(paramStr(3)) else: 720
let replay = loadReplay(path)
let game = newGame(
  generateMap(replay.config.seed, replay.config.mapPreset),
  replay.config.spawnIntervalTicks, 0, true, replay)
game.replayPlayer = initReplayPlayer(replay)
game.historyPlayback = true

proc side(team: int32): string = (if team == 0: "red" else: "blue")
for b in game.world.buildings:
  echo &"building id {b.id} {side(b.team.ord.int32)} kind {b.kind} lane {b.lane} tier {b.tier} guard {b.guardsGod} at {b.position.x div 60000},{b.position.z div 60000}"
for f in game.world.forts:
  echo &"god {side(f.team.ord.int32)} at {f.center.x div 60000},{f.center.z div 60000}"
for h in game.world.heroes:
  echo &"hero {h.id} {side(h.team.ord.int32)} lane {h.lane} at {h.position.x div 60000},{h.position.z div 60000}"
var deaths: array[2, int]
var xpBy: Table[(int32, string), int]
var heroDeaths: array[10, int]
var lastMinute = -1
for tick in 0 .. replay.hashes.len:
  if tick > 0:
    game.tickWorld(nil)
    game.hashCheck.requireReplayComplete(uint32(game.world.tick), tick)
  let t = game.world.tick
  for event in game.world.events:
    case event.kind
    of Death:
      let k = event.target.kind
      if k == 2:
        inc deaths[event.target.team]
        if event.target.id >= 100 and event.target.id < 110: inc heroDeaths[event.target.id - 100]
        echo &"{t:6} {t div 1440:3}m hero {side(event.target.team)} class {event.target.class} killed by kind {event.actor.kind} id {event.actor.id} {side(event.actor.team)} at {event.target.x div 60000},{event.target.z div 60000}"
      elif k >= 4:
        echo &"{t:6} {t div 1440:3}m BUILDING kind {k} {side(event.target.team)} id {event.target.id} down (killer kind {event.actor.kind})"
      elif k == 1:
        echo &"{t:6} {t div 1440:3}m GOD {side(event.target.team)} slain"
    of XpGained:
      let victimKind = event.actor.kind
      let source = (if event.cause == NearbyKill: "shared" elif victimKind == 2: "herokill" elif victimKind == 3: "lasthit" elif victimKind >= 4: "building" elif victimKind == 1: "god" else: "other")
      xpBy[(event.target.id, source)] = xpBy.getOrDefault((event.target.id, source)) + int(event.amount)
    of HeroDrafted:
      echo &"{t:6} draft {side(event.actor.team)} slot {event.actor.player} picks class {event.detail}"
    of SpellReleased:
      xpBy[(event.actor.id, "casts")] = xpBy.getOrDefault((event.actor.id, "casts")) + 1
    of ItemConsumed:
      xpBy[(event.actor.id, "items")] = xpBy.getOrDefault((event.actor.id, "items")) + 1
    of MatchEnded:
      echo &"{t:6} {t div 1440:3}m MATCH ENDED winner {event.amount}"
    else: discard
  if trackId >= 0 and int(t) mod interval == 0:
    for hero in game.world.heroes:
      if hero.id.int == trackId:
        var goal = "-"
        if hero.movePath.len > 0:
          goal = $(hero.movePath[^1].x div 60000) & "," & $(hero.movePath[^1].z div 60000)
        echo &"track {t:6} {t div 1440:3}m id {hero.id} at {hero.position.x div 60000},{hero.position.z div 60000} hp {hero.hp}/{hero.maxHp} L{hero.level} xp {hero.totalXp} state {hero.state} atk {hero.attackObjectId} am {hero.attackMoving} tgt h{hero.targetHeroId} c{hero.targetFootmanId} b{hero.targetBuildingId} goal {goal}"
  let minute = int(t) div 1440
  if minute != lastMinute and minute mod 2 == 0:
    lastMinute = minute
    var levels: array[2, seq[string]]
    var gold: array[2, int]
    for hero in game.world.heroes:
      levels[hero.team.ord].add $hero.level
      gold[hero.team.ord] += hero.gold
    var standing: array[2, int]
    for b in game.world.buildings:
      if b.hp > 0: inc standing[b.team.ord]
    echo &"--- {minute:3}m red L{levels[0].join(\"/\")} gold {gold[0]} bld {standing[0]} deaths {deaths[0]} | blue L{levels[1].join(\"/\")} gold {gold[1]} bld {standing[1]} deaths {deaths[1]}"

var final: array[2, seq[string]]
for hero in game.world.heroes:
  final[hero.team.ord].add &"{hero.totalXp}/{heroDeaths[hero.id - 100]}/L{hero.level}/c{hero.class.ord}"
echo &"final xp/deaths/level/class: red {final[0].join(\" \")} | blue {final[1].join(\" \")}"

## Optional raw order dump: PATH heroId interval fromTick toTick
if trackId >= 0 and paramCount() >= 5:
  let fromTick = parseInt(paramStr(4))
  let toTick = parseInt(paramStr(5))
  var last = ""
  var run = 0
  for action in replay.actions:
    if action.heroId == trackId and int(action.tick) >= fromTick and int(action.tick) <= toTick:
      let line = &"kind {action.kind} slot {action.slot} first {action.first} second {action.second}"
      if line == last:
        inc run
      else:
        if run > 0: echo &"      (repeated {run} more)"
        echo &"order {action.tick:6} {line}"
        last = line
        run = 0
  if run > 0: echo &"      (repeated {run} more)"

## XP by source per hero: how each hero earned its lifetime XP.
for hero in game.world.heroes:
  var parts: seq[string]
  for source in ["lasthit", "shared", "herokill", "building", "god", "other", "casts", "items"]:
    let v = xpBy.getOrDefault((hero.id, source))
    if v > 0: parts.add &"{source} {v}"
  echo &"xpsrc {hero.id} {side(hero.team.ord.int32)} c{hero.class.ord} total {hero.totalXp}: {parts.join(\", \")}"

## CPU budget use per slot from the replay's own metrics (percent of the
## instruction allowance over the whole match; -1 when unavailable).
var cpuLine = "cpu"
for i, row in replay.metrics.final:
  cpuLine.add &" s{i}={row.cpu}%"
echo cpuLine
