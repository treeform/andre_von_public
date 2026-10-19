// Builds the 0.1.3 fixture world (4x4 rooms, carved entrances, sealed
// border) from the official default db, as src/worldFixture.nim does.
// Usage: node tools/world.js  (writes maps/world.json)
const fs = require("fs")
const path = require("path")

const WorldRooms = []
for (const w of [1, 2, 3, 4]) {
  for (const n of [1, 2, 3, 4]) WorldRooms.push("W" + w + "N" + n)
}

function connectExit(terrain, x, y, dx, dy) {
  // Carves a three wide entrance from an edge until open ground.
  for (let step = 0; step < 50; step++) {
    const index = (y + dy * step) * 50 + x + dx * step
    const connected = step >= 2 && terrain[index] != "1" && terrain[index] != "3"
    for (let offset = -1; offset <= 1; offset++) {
      terrain[index + offset * (dx == 0 ? 1 : 50)] = "0"
    }
    if (connected) break
  }
}

const db = JSON.parse(fs.readFileSync(path.join(__dirname, "../maps/db.json")))
const objects = db.collections.find(c => c.name == "rooms.objects").data
  .filter(o => WorldRooms.includes(o.room) && (o.type == "controller" || !o.user))
const terrains = {}
for (const t of db.collections.find(c => c.name == "rooms.terrain").data) {
  const room = t.room
  if (!WorldRooms.includes(room)) continue
  const terrain = t.terrain.split("")
  if (room[1] != "1") connectExit(terrain, 49, 25, -1, 0)
  if (room[1] != "4") connectExit(terrain, 0, 25, 1, 0)
  if (room[3] != "1") connectExit(terrain, 25, 49, 0, -1)
  if (room[3] != "4") connectExit(terrain, 25, 0, 0, 1)
  for (let tile = 0; tile < 50; tile++) {
    if (room[1] == "1") terrain[tile * 50 + 49] = "1"
    if (room[1] == "4") terrain[tile * 50] = "1"
    if (room[3] == "1") terrain[49 * 50 + tile] = "1"
    if (room[3] == "4") terrain[tile] = "1"
  }
  terrains[room] = terrain.join("")
}
const out = {
  starts: { W3N3: [37, 31], W2N2: [17, 40] },
  objects: objects.map(o => ({ room: o.room, type: o.type, x: o.x, y: o.y, id: o._id,
    mineralType: o.mineralType })),
  terrain: terrains
}
fs.writeFileSync(path.join(__dirname, "../maps/world.json"), JSON.stringify(out))
for (const room of WorldRooms) {
  const objs = objects.filter(o => o.room == room)
  console.log(room, objs.map(o => o.type[0] + "@" + o.x + "," + o.y).join(" "))
}
