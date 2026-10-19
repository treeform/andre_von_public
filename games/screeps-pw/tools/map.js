// Prints start rooms, their sources and path distances from the spawn.
// Usage: node tools/map.js [room ...]
const fs = require("fs")
const path = require("path")

const Db = JSON.parse(fs.readFileSync(path.join(__dirname, "../maps/db.json")))
const Objects = Db.collections.find(c => c.name == "rooms.objects").data
const Terrains = Db.collections.find(c => c.name == "rooms.terrain").data
const Starts = { W1N1: [37, 31], W9N9: [17, 40] }

function terrainOf(room) {
  // Returns the 2500 char terrain string for a room.
  return Terrains.find(t => t.room == room).terrain
}

function parseRoom(name) {
  // Splits W3N7 into numeric x, y.
  const m = /^([WE])(\d+)([NS])(\d+)$/.exec(name)
  return { x: Number(m[2]), y: Number(m[4]) }
}

function roomName(x, y) {
  // Joins numeric x, y into a W/N room name.
  return "W" + x + "N" + y
}

function walkCost(t) {
  // Returns tick cost for a 1:1 MOVE creep on plain/swamp.
  if (t == "0") return 1
  if (t == "2") return 5
  return Infinity
}

function blocked(room) {
  // Returns a set of tiles occupied by non-walkable objects.
  const s = new Set()
  for (const o of Objects) {
    if (o.room != room) continue
    if (o.type == "source" || o.type == "controller" ||
      o.type == "mineral" || o.type == "keeperLair" ||
      o.type == "spawn") {
        s.add(o.x + o.y * 50)
    }
  }
  return s
}

function dijkstra(room, sx, sy) {
  // Returns per-tile path costs inside one room from (sx, sy).
  const ter = terrainOf(room)
  const block = blocked(room)
  const dist = new Array(2500).fill(Infinity)
  dist[sx + sy * 50] = 0
  const open = [[0, sx, sy]]
  while (open.length > 0) {
    open.sort((a, b) => a[0] - b[0])
    const [d, x, y] = open.shift()
    if (d > dist[x + y * 50]) continue
    for (let dx = -1; dx <= 1; dx++) {
      for (let dy = -1; dy <= 1; dy++) {
        const nx = x + dx, ny = y + dy
        if (nx < 0 || ny < 0 || nx > 49 || ny > 49) continue
        const i = nx + ny * 50
        if (block.has(i)) continue
        const c = walkCost(ter[i])
        if (c == Infinity) continue
        if (d + c < dist[i]) {
          dist[i] = d + c
          open.push([d + c, nx, ny])
        }
      }
    }
  }
  return dist
}

function nearCost(dist, x, y, range) {
  // Returns the cheapest tile cost within range of (x, y).
  let best = Infinity
  for (let dx = -range; dx <= range; dx++) {
    for (let dy = -range; dy <= range; dy++) {
      const nx = x + dx, ny = y + dy
      if (nx < 0 || ny < 0 || nx > 49 || ny > 49) continue
      best = Math.min(best, dist[nx + ny * 50])
    }
  }
  return best
}

function openSpots(room, x, y) {
  // Counts walkable tiles adjacent to (x, y).
  const ter = terrainOf(room)
  let n = 0
  for (let dx = -1; dx <= 1; dx++) {
    for (let dy = -1; dy <= 1; dy++) {
      if (dx == 0 && dy == 0) continue
      if (walkCost(ter[(x + dx) + (y + dy) * 50]) != Infinity) n++
    }
  }
  return n
}

function draw(room, mark) {
  // Prints the room terrain with objects overlaid.
  const ter = terrainOf(room)
  const glyph = { source: "S", controller: "C", mineral: "M", keeperLair: "K" }
  const over = {}
  for (const o of Objects) {
    if (o.room == room && glyph[o.type]) over[o.x + o.y * 50] = glyph[o.type]
  }
  if (mark) over[mark[0] + mark[1] * 50] = "@"
  for (let y = 0; y < 50; y++) {
    let line = ""
    for (let x = 0; x < 50; x++) {
      const i = x + y * 50
      line += over[i] || (ter[i] == "1" ? "#" : ter[i] == "2" ? "~" : ".")
    }
    console.log(line)
  }
}

function report(room, start) {
  // Prints source and controller distances for one room.
  const objs = Objects.filter(o => o.room == room)
  console.log("==", room, "start", start)
  const dist = start ? dijkstra(room, start[0], start[1]) : null
  for (const o of objs) {
    if (o.type == "spawn") continue
    let line = "  " + o.type + " " + o.x + "," + o.y
    if (o.type == "source") line += " spots " + openSpots(room, o.x, o.y)
    if (o.type == "mineral") line += " " + o.mineralType
    if (dist) {
      const r = o.type == "controller" ? 3 : 1
      line += " cost " + nearCost(dist, o.x, o.y, r)
    }
    console.log(line)
  }
  draw(room, start)
}

function neighbors(room) {
  // Prints exits and source counts of the rooms around a start.
  const p = parseRoom(room)
  for (let dy = -2; dy <= 2; dy++) {
    let line = ""
    for (let dx = -2; dx <= 2; dx++) {
      const n = roomName(p.x - dx, p.y - dy)
      const objs = Objects.filter(o => o.room == n)
      const s = objs.filter(o => o.type == "source").length
      const k = objs.filter(o => o.type == "keeperLair").length
      const c = objs.filter(o => o.type == "controller").length
      line += (n + " s" + s + (c ? "c" : "-") + (k ? "K" + k : "  ")).padEnd(13)
    }
    console.log(line)
  }
}

const rooms = process.argv.slice(2)
if (rooms.length == 0) {
  for (const r of Object.keys(Starts)) {
    report(r, Starts[r])
    neighbors(r)
  }
} else {
  for (const r of rooms) report(r, Starts[r])
}
