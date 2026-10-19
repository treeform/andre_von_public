// Applies the "fill the spawn, skip the detour" change: a hauler sent to
// the spawn unloads all the spawn can take and, with under 50 energy
// left, goes back to its source instead of on to the upgrade pile.
// Usage: node tools/patch_spawnfill.js <in.js> <out.js>
const fs = require("fs")
let s = fs.readFileSync(process.argv[2], "utf8")

function rep(from, to) {
  // Replaces one exact snippet or fails loudly.
  if (!s.includes(from)) throw new Error("missing: " + from.slice(0, 80))
  s = s.split(from).join(to)
}

rep(`      if (go(creep, spawn.pos, 1)) {
        const amount = Math.min(need, creep.store.energy,
          spawn.store.getFreeCapacity(RESOURCE_ENERGY))
        if (amount > 0) creep.transfer(spawn, RESOURCE_ENERGY, amount)
        creep.memory.target = undefined
      }
      return`,
`      if (go(creep, spawn.pos, 1)) {
        const amount = Math.min(creep.store.energy,
          spawn.store.getFreeCapacity(RESOURCE_ENERGY))
        if (amount > 0) creep.transfer(spawn, RESOURCE_ENERGY, amount)
        creep.memory.target = undefined
        if (creep.store.energy - amount < 50) {
          creep.memory.state = "fill"
          creep.memory.src = assignSource(creep, plan, c)
        }
      }
      return`)
fs.writeFileSync(process.argv[3], s)
