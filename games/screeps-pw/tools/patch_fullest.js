// Applies the "serve the fullest miner" change: a filling hauler with
// nothing to sweep walks next to the miner holding the most energy
// (store plus the pile under it) instead of waiting at one station.
// Usage: node tools/patch_fullest.js <in.js> <out.js>
const fs = require("fs")
let s = fs.readFileSync(process.argv[2], "utf8")

function rep(from, to) {
  // Replaces one exact snippet or fails loudly.
  if (!s.includes(from)) throw new Error("missing: " + from.slice(0, 80))
  s = s.split(from).join(to)
}

rep(`      const station = new RoomPosition(src.station.x, src.station.y, src.room)
      const busy = Game.rooms[src.room] !== undefined &&
        station.lookFor(LOOK_CREEPS).length > 0 && !creep.pos.isEqualTo(station)
      go(creep, station, busy ? 1 : 0)
      return`,
`      // Serve the miner holding the most energy, if it is not next to us.
      let best = null, bestEnergy = 0
      for (const m of b.miners) {
        if (!m.memory.posted) continue
        let energy = m.store.energy
        for (const d of heap.drops[src.id] || []) {
          if (d.pos.isEqualTo(m.pos)) energy += d.amount
        }
        if (energy > bestEnergy) {
          best = m
          bestEnergy = energy
        }
      }
      if (best && bestEnergy >= 40 && !creep.pos.isNearTo(best) &&
        b.miners.every(m => !m.memory.posted || !creep.pos.isNearTo(m) ||
          m.store.energy < 20)) {
            go(creep, best.pos, 1)
            return
      }
      const station = new RoomPosition(src.station.x, src.station.y, src.room)
      const busy = Game.rooms[src.room] !== undefined &&
        station.lookFor(LOOK_CREEPS).length > 0 && !creep.pos.isEqualTo(station)
      if (b.miners.some(m => m.memory.posted && creep.pos.isNearTo(m))) return
      go(creep, station, busy ? 1 : 0)
      return`)
fs.writeFileSync(process.argv[3], s)
