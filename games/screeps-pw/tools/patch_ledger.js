// Adds an energy ledger to a mokosh source file (diagnostic only):
// harvested, delivered to spawn, dropped on piles, spent on bodies and
// upgraded, printed every LogEvery ticks.
// Usage: node tools/patch_ledger.js <in.js> <out.js>
const fs = require("fs")
let s = fs.readFileSync(process.argv[2], "utf8")

function rep(from, to) {
  // Replaces one exact snippet or fails loudly.
  if (!s.includes(from)) throw new Error("missing: " + from.slice(0, 80))
  s = s.split(from).join(to)
}

rep(`  if (source && source.energy > 0) creep.harvest(source)`,
`  if (source && source.energy > 0 && creep.harvest(source) == OK) {
    const got = Math.min(source.energy, countParts(creep, WORK) * 2)
    heap.ledger.harvest += got
    if (src.remote) heap.ledger.remote += got
  }`)
rep(`        if (amount > 0) creep.transfer(spawn, RESOURCE_ENERGY, amount)`,
`        if (amount > 0 && creep.transfer(spawn, RESOURCE_ENERGY, amount) == OK) {
          heap.ledger.spawn += amount
        }`)
rep(`      creep.drop(RESOURCE_ENERGY)`,
`      if (creep.drop(RESOURCE_ENERGY) == OK) heap.ledger.pile += creep.store.energy`)
rep(`  if (spawn.spawnCreep(next.body, name, { memory: next.memory }) == OK) {`,
`  if (spawn.spawnCreep(next.body, name, { memory: next.memory }) == OK) {
    heap.ledger.bodies += cost`)
rep(`function report(room, c) {
  // Logs a one line status to the private seat log.`,
`function report(room, c) {
  // Logs a one line status to the private seat log.
  const l = heap.ledger
  const gcl = Math.floor(Game.gcl.progress)
  console.log("[ledger] harvest=" + l.harvest + " remote=" + l.remote +
    " spawn=" + l.spawn + " pile=" + l.pile + " bodies=" + l.bodies +
    " upgraded=" + (gcl - (l.gcl || 0)))
  heap.ledger = { harvest: 0, remote: 0, spawn: 0, pile: 0, bodies: 0, gcl }`)
rep(`  if (Memory.start === undefined) Memory.start = Game.time`,
`  if (Memory.start === undefined) Memory.start = Game.time
  if (!heap.ledger) heap.ledger = { harvest: 0, remote: 0, spawn: 0, pile: 0, bodies: 0, gcl: 0 }`)
fs.writeFileSync(process.argv[3], s)

// Decay and tombstone accounting, measured every tick.
s = fs.readFileSync(process.argv[3], "utf8")
rep(`  cleanMemory()
  scanDrops(room, plan)`,
`  cleanMemory()
  scanDrops(room, plan)
  for (const name of [room.name, ...plan.remoteRooms]) {
    const r = Game.rooms[name]
    if (!r) continue
    for (const d of r.find(FIND_DROPPED_RESOURCES)) {
      const loss = Math.ceil(d.amount / 1000)
      const onPile = name == plan.room && plan.piles.some(p => p.x == d.pos.x && p.y == d.pos.y)
      if (onPile) heap.ledger.pileDecay += loss
      else heap.ledger.looseDecay += loss
    }
    for (const t of r.find(FIND_TOMBSTONES)) {
      if (t.deathTime == Game.time - 1) heap.ledger.tomb += t.store.energy
    }
  }`)
rep(`  heap.ledger = { harvest: 0, remote: 0, spawn: 0, pile: 0, bodies: 0, gcl }`,
`  heap.ledger = { harvest: 0, remote: 0, spawn: 0, pile: 0, bodies: 0, gcl,
    pileDecay: 0, looseDecay: 0, tomb: 0 }`)
rep(`    " upgraded=" + (gcl - (l.gcl || 0)))`,
`    " upgraded=" + (gcl - (l.gcl || 0)) + " pileDecay=" + l.pileDecay +
    " looseDecay=" + l.looseDecay + " tomb=" + l.tomb)`)
rep(`  if (!heap.ledger) heap.ledger = { harvest: 0, remote: 0, spawn: 0, pile: 0, bodies: 0, gcl: 0 }`,
`  if (!heap.ledger) {
    heap.ledger = { harvest: 0, remote: 0, spawn: 0, pile: 0, bodies: 0, gcl: 0,
      pileDecay: 0, looseDecay: 0, tomb: 0 }
  }`)
fs.writeFileSync(process.argv[3], s)

// The six biggest loose piles at each report, for locating leaks.
s = fs.readFileSync(process.argv[3], "utf8")
rep(`    " looseDecay=" + l.looseDecay + " tomb=" + l.tomb)`,
`    " looseDecay=" + l.looseDecay + " tomb=" + l.tomb)
  const drops = []
  for (const name of [heap.plan.room, ...heap.plan.remoteRooms]) {
    const r = Game.rooms[name]
    if (r) drops.push(...r.find(FIND_DROPPED_RESOURCES))
  }
  drops.sort((p, q) => q.amount - p.amount)
  console.log("[drops] " + drops.slice(0, 6).map(d =>
    d.pos.roomName + ":" + d.pos.x + "," + d.pos.y + "=" + d.amount).join(" "))`)
fs.writeFileSync(process.argv[3], s)
