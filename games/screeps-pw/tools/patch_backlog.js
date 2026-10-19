// Applies the "hauler backlog" change: loose energy piling up near
// sources asks for extra haulers, up to 1.6 times the computed need.
// Usage: node tools/patch_backlog.js <in.js> <out.js>
const fs = require("fs")
let s = fs.readFileSync(process.argv[2], "utf8")

function rep(from, to) {
  // Replaces one exact snippet or fails loudly.
  if (!s.includes(from)) throw new Error("missing: " + from.slice(0, 80))
  s = s.split(from).join(to)
}

rep(`  if (c.haulCarry < haulNeed && left > 200) {
    return { body: haulerBody(Math.min(budget, 300)), memory: { role: "h" } }
  }`,
`  if (c.haulCarry < haulNeed && left > 200) {
    return { body: haulerBody(Math.min(budget, 300)), memory: { role: "h" } }
  }
  // Energy left lying at the sources means the haulers fall behind.
  if (heap.backlog > 300 && c.haulCarry < haulNeed * 1.6 && left > 200) {
    return { body: haulerBody(Math.min(budget, 300)), memory: { role: "h" } }
  }`)
rep(`function scanDrops(room, plan) {
  // Records dropped energy near sources and on the piles.
  heap.drops = {}`,
`function scanDrops(room, plan) {
  // Records dropped energy near sources and on the piles.
  heap.drops = {}
  heap.backlog = 0`)
rep(`      if (s.room == d.pos.roomName && chebyshev(d.pos, s) <= 2) {`,
`      if (s.room == d.pos.roomName && chebyshev(d.pos, s) <= 2) {
        heap.backlog += d.amount`)
fs.writeFileSync(process.argv[3], s)
