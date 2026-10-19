// Applies the "sweep drops" change: haulers walk to sizable loose energy
// near their source before waiting at the station.
// Usage: node tools/patch_sweep.js <in.js> <out.js>
const fs = require("fs")
let s = fs.readFileSync(process.argv[2], "utf8")

function rep(from, to) {
  // Replaces one exact snippet or fails loudly.
  if (!s.includes(from)) throw new Error("missing: " + from.slice(0, 80))
  s = s.split(from).join(to)
}

rep(`      // Grab loose energy in reach, then wait at the station.
      for (const d of heap.drops[src.id] || []) {
        if (creep.pos.isNearTo(d)) {
          creep.pickup(d)
          break
        }
      }
      const station = new RoomPosition(src.station.x, src.station.y, src.room)`,
`      // Grab loose energy in reach; walk to the biggest pile another
      // hauler is not already on; otherwise wait at the station.
      let sweep = null
      for (const d of heap.drops[src.id] || []) {
        if (creep.pos.isNearTo(d)) {
          creep.pickup(d)
          sweep = null
          break
        }
        if (d.amount < 40 || heap.swept.has(d.id)) continue
        if (!sweep || d.amount > sweep.amount) sweep = d
      }
      if (sweep && free >= 40) {
        heap.swept.add(sweep.id)
        go(creep, sweep.pos, 1)
        return
      }
      const station = new RoomPosition(src.station.x, src.station.y, src.room)`)
rep(`  heap.spawnPromised = 0
  heap.intents = new Map()`,
`  heap.spawnPromised = 0
  heap.swept = new Set()
  heap.intents = new Map()`)
fs.writeFileSync(process.argv[3], s)
