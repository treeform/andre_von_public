// Sums the [ledger] lines of a seat log (from tools/patch_ledger.js builds).
// Usage: node tools/ledger.js <policy_agent_N.log>...
const fs = require("fs")
for (const file of process.argv.slice(2)) {
  const total = {}
  for (const line of fs.readFileSync(file, "utf8").split("\n")) {
    const i = line.indexOf("{")
    if (i < 0) continue
    let entry
    try {
      entry = JSON.parse(line.slice(i))
    } catch (error) {
      continue
    }
    for (const m of (entry.console && entry.console.log) || []) {
      if (!m.message.startsWith("[ledger]")) continue
      for (const kv of m.message.matchAll(/(\w+)=(-?\d+)/g)) {
        total[kv[1]] = (total[kv[1]] || 0) + Number(kv[2])
      }
    }
  }
  console.log(file, JSON.stringify(total))
  console.log("  lost before delivery", total.harvest - total.spawn - total.pile,
    " lost at piles", total.pile - total.upgraded)
}
