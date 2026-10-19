// Applies the "two extensions" change to a mokosh source file: 400
// energy bodies (3 WORK miners and upgraders), extensions built by
// upgraders from their slots, haulers fill spawn then extensions.
// Usage: node tools/patch_ext.js <in.js> <out.js>
const fs = require("fs")
let s = fs.readFileSync(process.argv[2], "utf8")

function rep(from, to) {
  // Replaces one exact snippet or fails loudly.
  if (!s.includes(from)) throw new Error("missing: " + from.slice(0, 80))
  s = s.split(from).join(to)
}

rep(`const UseRemotes = true`, `const UseRemotes = true
const ExtensionCount = 2`)

// Plan extension tiles: in build range of an upgrade slot, near the
// spawn, never blocking a pile.
rep(`  const pile = new RoomPosition(piles[0].x, piles[0].y, room.name)
  const planSource = (id, roomName, sx, sy, cap) => {`,
`  const extensions = []
  {
    const slotList = piles.flatMap(p => p.slots)
    const taken = new Set([...used, ...doors])
    const cands = []
    for (let x = 2; x < 48; x++) {
      for (let y = 2; y < 48; y++) {
        const key = x + ":" + y
        if (!free(x, y) || taken.has(key)) continue
        if (!slotList.some(sl => chebyshev(sl, { x, y }) <= 3)) continue
        let open = 0
        for (let dx = -1; dx <= 1; dx++) {
          for (let dy = -1; dy <= 1; dy++) {
            if ((dx || dy) && free(x + dx, y + dy)) open++
          }
        }
        if (open < 6) continue
        cands.push({ x, y, d: chebyshev({ x, y }, spawn.pos) })
      }
    }
    cands.sort((a, b) => a.d - b.d)
    for (const cand of cands) {
      if (extensions.length >= ExtensionCount) break
      const matrix = blockedMatrix([...extensions, cand])
      if (piles.every(p => reach(p, matrix))) extensions.push({ x: cand.x, y: cand.y })
    }
  }
  const pile = new RoomPosition(piles[0].x, piles[0].y, room.name)
  const planSource = (id, roomName, sx, sy, cap) => {`)
rep(`    remoteRooms: [...new Set((Remotes[room.name] || []).map(r => r.room))],`,
`    extensions,
    remoteRooms: [...new Set((Remotes[room.name] || []).map(r => r.room))],`)

// Place the sites once the controller allows extensions.
rep(`  cleanMemory()
  scanDrops(room, plan)`,
`  if (room.controller.level >= 2 && Game.time % 20 == 0) {
    for (const e of plan.extensions) {
      const pos = new RoomPosition(e.x, e.y, room.name)
      if (pos.lookFor(LOOK_STRUCTURES).length == 0 &&
        pos.lookFor(LOOK_CONSTRUCTION_SITES).length == 0) {
          room.createConstructionSite(pos, STRUCTURE_EXTENSION)
      }
    }
  }
  heap.sites = room.find(FIND_MY_CONSTRUCTION_SITES)
  cleanMemory()
  scanDrops(room, plan)`)

// Upgraders build sites in range before upgrading.
rep(`  const drop = heap.pileDrops[creep.memory.pile]
  if (drop && creep.store.getFreeCapacity() > 0) creep.pickup(drop)
  if (creep.store.energy > 0) creep.upgradeController(room.controller)
}`,
`  const drop = heap.pileDrops[creep.memory.pile]
  if (drop && creep.store.getFreeCapacity() > 0) creep.pickup(drop)
  if (creep.store.energy == 0) return
  const site = heap.sites.find(c => creep.pos.inRangeTo(c, 3))
  if (site) {
    creep.build(site)
  } else {
    creep.upgradeController(room.controller)
  }
}`)

// Haulers fill the spawn first, then extensions.
rep(`      if (go(creep, spawn.pos, 1)) {
        const amount = Math.min(need, creep.store.energy,
          spawn.store.getFreeCapacity(RESOURCE_ENERGY))
        if (amount > 0) creep.transfer(spawn, RESOURCE_ENERGY, amount)
        creep.memory.target = undefined
      }
      return`,
`      let sink = spawn
      if (spawn.store.getFreeCapacity(RESOURCE_ENERGY) == 0) {
        sink = room.find(FIND_MY_STRUCTURES, { filter: x =>
          x.structureType == STRUCTURE_EXTENSION &&
          x.store.getFreeCapacity(RESOURCE_ENERGY) > 0 })[0] || spawn
      }
      if (go(creep, sink.pos, 1)) {
        const amount = Math.min(need, creep.store.energy,
          sink.store.getFreeCapacity(RESOURCE_ENERGY))
        if (amount > 0) creep.transfer(sink, RESOURCE_ENERGY, amount)
        creep.memory.target = undefined
      }
      return`)

// Bodies: haulers may use the full capacity.
rep(`    return { body: haulerBody(Math.min(budget, 300)), memory: { role: "h" } }
  }
  for (const s of home) {`,
`    return { body: haulerBody(budget), memory: { role: "h" } }
  }
  for (const s of home) {`)
fs.writeFileSync(process.argv[3], s)

// Miners at spot limited sources and remote miners use the full capacity.
s = fs.readFileSync(process.argv[3], "utf8")
rep(`    if (b.work + 1 + (spotsLeft - 1) * 2 < 5) size = Math.max(size, 300)`,
`    if (b.work + 1 + (spotsLeft - 1) * 2 < 5) size = Math.max(size, cap)`)
rep(`    return { body: minerBody(300), memory: { role: "m", src: s.id } }`,
`    return { body: minerBody(Math.min(cap, 400)), memory: { role: "m", src: s.id } }`)
fs.writeFileSync(process.argv[3], s)
