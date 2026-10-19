// Ranks sources of the 4x4 world by walking cost from each start.
// Usage: node tools/remote.js  (needs maps/world.json from tools/world.js)
const fs = require("fs")
const path = require("path")

const World = JSON.parse(fs.readFileSync(path.join(__dirname, "../maps/world.json")))
const Size = 200

function global(room, x, y) {
  // Converts a room position to world grid coordinates (W4N4 top left).
  const m = /^W(\d+)N(\d+)$/.exec(room)
  return [(4 - Number(m[1])) * 50 + x, (4 - Number(m[2])) * 50 + y]
}

function cost(gx, gy) {
  // Returns the move cost of a world tile for a 1:1 MOVE creep.
  if (gx < 0 || gy < 0 || gx >= Size || gy >= Size) return Infinity
  const room = "W" + (4 - Math.floor(gx / 50)) + "N" + (4 - Math.floor(gy / 50))
  const c = World.terrain[room][(gx % 50) + (gy % 50) * 50]
  if (c == "1" || c == "3") return Infinity
  return c == "2" ? 5 : 1
}

function dijkstra(gx, gy) {
  // Returns world tile costs from a start tile.
  const dist = new Float64Array(Size * Size).fill(Infinity)
  const blocked = new Set()
  for (const o of World.objects) {
    if (["source", "controller", "mineral", "keeperLair"].includes(o.type)) {
      const [ox, oy] = global(o.room, o.x, o.y)
      blocked.add(ox + oy * Size)
    }
  }
  dist[gx + gy * Size] = 0
  const buckets = [[gx + gy * Size]]
  for (let d = 0; d < buckets.length; d++) {
    for (const i of buckets[d] || []) {
      if (dist[i] != d) continue
      const x = i % Size, y = Math.floor(i / Size)
      for (let dx = -1; dx <= 1; dx++) {
        for (let dy = -1; dy <= 1; dy++) {
          const nx = x + dx, ny = y + dy
          const c = cost(nx, ny)
          if (c == Infinity) continue
          const j = nx + ny * Size
          if (blocked.has(j)) continue
          if (d + c < dist[j]) {
            dist[j] = d + c
            ;(buckets[d + c] = buckets[d + c] || []).push(j)
          }
        }
      }
    }
  }
  return dist
}

function near(dist, gx, gy, r) {
  // Returns the cheapest cost within range r of (gx, gy).
  let best = Infinity
  for (let dx = -r; dx <= r; dx++) {
    for (let dy = -r; dy <= r; dy++) {
      const x = gx + dx, y = gy + dy
      if (x < 0 || y < 0 || x >= Size || y >= Size) continue
      best = Math.min(best, dist[x + y * Size])
    }
  }
  return best
}

const starts = Object.keys(World.starts)
const fromSpawn = {}, fromCtrl = {}
for (const room of starts) {
  const [sx, sy] = World.starts[room]
  fromSpawn[room] = dijkstra(...global(room, sx, sy))
  const c = World.objects.find(o => o.room == room && o.type == "controller")
  fromCtrl[room] = dijkstra(...global(room, c.x, c.y))
}
console.log("source            " + starts.map(r => (r + " ctrl/spawn").padEnd(18)).join(""))
const rows = []
for (const o of World.objects) {
  if (o.type != "source") continue
  const [ox, oy] = global(o.room, o.x, o.y)
  const keeper = World.objects.some(k => k.room == o.room && k.type == "keeperLair")
  const cols = starts.map(r => near(fromCtrl[r], ox, oy, 1) + "/" + near(fromSpawn[r], ox, oy, 1))
  rows.push([near(fromCtrl[starts[0]], ox, oy, 1),
    (o.room + " " + o.x + "," + o.y + (keeper ? " K" : "")).padEnd(18) +
    cols.map(c => c.padEnd(18)).join("") + o.id])
}
rows.sort((a, b) => a[0] - b[0])
for (const r of rows) console.log(r[1])
for (const room of starts) {
  const other = starts.find(r => r != room)
  const [ox, oy] = global(other, ...World.starts[other])
  console.log(room, "spawn to", other, "spawn:", near(fromSpawn[room], ox, oy, 1))
}
