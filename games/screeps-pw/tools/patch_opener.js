// Applies the "replace small miners" change to a mokosh source file.
// Usage: node tools/patch_opener.js <in.js> <out.js>
const fs = require("fs")
let s = fs.readFileSync(process.argv[2], "utf8")

function rep(from, to) {
  // Replaces one exact snippet or fails loudly.
  if (!s.includes(from)) throw new Error("missing: " + from.slice(0, 80))
  s = s.split(from).join(to)
}

// Spawn: when a source's spots are full of young miners but its WORK is
// short, build a full miner to replace the smallest one.
rep(`    if (b.work >= 5 || spotsLeft <= 0 || left <= 200) continue
    // A one WORK miner only when the spots can still reach five WORK.`,
`    if (b.work < 5 && spotsLeft <= 0 && left > 200 && budget >= 300) {
      const small = b.miners.find(m => countParts(m, WORK) < 2 &&
        !b.miners.some(n => n.memory.replaces == m.name))
      if (small) {
        return { body: minerBody(300), memory: { role: "m", src: s.id, replaces: small.name } }
      }
    }
    if (b.work >= 5 || spotsLeft <= 0 || left <= 200) continue
    // A one WORK miner only when the spots can still reach five WORK.`)

// Miner: a replacement waiting by the source retires the small miner.
rep(`    if (creep.memory.spot === undefined) {
      // Wait near the source until an old miner frees a spot.`,
`    const old = creep.memory.replaces && Game.creeps[creep.memory.replaces]
    if (creep.memory.spot === undefined && old &&
      creep.pos.inRangeTo(new RoomPosition(src.x, src.y, src.room), 4)) {
        old.suicide()
        creep.memory.replaces = undefined
    }
    if (creep.memory.spot === undefined) {
      // Wait near the source until an old miner frees a spot.`)
fs.writeFileSync(process.argv[3], s)
