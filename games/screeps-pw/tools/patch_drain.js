// Applies the "drain source piles" change on top of the backlog patch:
// a miner standing on its own overflow pile stops handing energy over,
// haulers pick up the biggest adjacent pile first, extra haulers up to
// 1.3 times the computed need.
// Usage: node tools/patch_drain.js <in.js> <out.js>
const fs = require("fs")
let s = fs.readFileSync(process.argv[2], "utf8")

function rep(from, to) {
  // Replaces one exact snippet or fails loudly.
  if (!s.includes(from)) throw new Error("missing: " + from.slice(0, 80))
  s = s.split(from).join(to)
}

rep(`  if (creep.store.energy < 20) return
  // Hand energy to an adjacent filling hauler.`,
`  if (creep.store.energy < 20) return
  // A pile under the miner goes first: haulers pick it up, so it drains.
  if ((heap.drops[src.id] || []).some(d => d.pos.isEqualTo(creep.pos) && d.amount >= 20)) {
    return
  }
  // Hand energy to an adjacent filling hauler.`)
rep(`      for (const d of heap.drops[src.id] || []) {
        if (creep.pos.isNearTo(d)) {
          creep.pickup(d)
          sweep = null
          break
        }
        if (d.amount < 40 || heap.swept.has(d.id)) continue
        if (!sweep || d.amount > sweep.amount) sweep = d
      }`,
`      let reach = null
      for (const d of heap.drops[src.id] || []) {
        if (creep.pos.isNearTo(d)) {
          if (!reach || d.amount > reach.amount) reach = d
          continue
        }
        if (d.amount < 40 || heap.swept.has(d.id)) continue
        if (!sweep || d.amount > sweep.amount) sweep = d
      }
      if (reach) {
        creep.pickup(reach)
        sweep = null
      }`)
rep(`  if (heap.backlog > 300 && c.haulCarry < haulNeed * 1.6 && left > 200) {`,
`  if (heap.backlog > 300 && c.haulCarry < haulNeed * 1.3 && left > 200) {`)
fs.writeFileSync(process.argv[3], s)
