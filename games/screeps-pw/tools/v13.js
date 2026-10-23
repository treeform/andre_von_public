// Mokosh: a 6000 tick GCL race colony for Screeps PW.
// Every energy unit should end up in upgradeController.

const MatchTicks = 6000
const LogEvery = 250
const PileCount = 3
const RemoteStart = 2000
const UseRemotes = true

// Neutral sources near each start room, nearest first (tools/remote.js).
// W3N3 and W2N2 are the 0.1.3 starts in the 4x4 world; the colony example
// never remote mines before RCL 3, so shared rooms are free in practice.
const Remotes = {
  W3N3: [
    { room: "W3N4", x: 13, y: 42, id: "b357077426772ba" },
    { room: "W4N2", x: 45, y: 23, id: "fa060773e1dacfc" },
    { room: "W2N3", x: 30, y: 7, id: "cdb3077498b3316" },
    { room: "W4N3", x: 46, y: 4, id: "8b320773ce4b827" },
    { room: "W4N3", x: 29, y: 5, id: "77930773ce4f30e" },
    { room: "W3N4", x: 40, y: 20, id: "a80c077426766aa" },
    { room: "W3N2", x: 12, y: 45, id: "1a5f077434777e6" }
  ],
  W2N2: [
    { room: "W2N1", x: 17, y: 18, id: "491f0774ad7dec8" },
    { room: "W3N1", x: 45, y: 16, id: "14b10774411436b" },
    { room: "W2N3", x: 30, y: 7, id: "cdb3077498b3316" },
    { room: "W1N2", x: 9, y: 46, id: "89b807750b171d8" },
    { room: "W1N3", x: 14, y: 44, id: "1aba07750418579" },
    { room: "W3N2", x: 12, y: 45, id: "1a5f077434777e6" }
  ],
  W1N1: [
    { room: "W1N2", x: 9, y: 46, id: "89b807750b171d8" },
    { room: "W1N3", x: 46, y: 32, id: "cc6707750413cc9" },
    { room: "W2N1", x: 17, y: 18, id: "491f0774ad7dec8" }
  ],
  W9N9: [
    { room: "W8N9", x: 8, y: 13, id: "a64f07720376ad7" },
    { room: "W8N9", x: 32, y: 8, id: "dcc70772037c9b1" },
    { room: "W8N8", x: 5, y: 43, id: "30d007720e8ef7b" },
    { room: "W8N8", x: 33, y: 22, id: "fd3d07720e87b83" }
  ]
}

// Heap state survives between ticks until a global reset.
let heap = { plan: null, paths: {}, costs: {}, tickCosts: {}, intents: new Map() }

function posKey(p) {
  // Returns a compact key for a position.
  return p.roomName + ":" + p.x + ":" + p.y
}

function bodyCost(body) {
  // Returns the energy cost of a body.
  let sum = 0
  for (const p of body) sum += BODYPART_COST[p]
  return sum
}

function countParts(creep, type) {
  // Counts parts of one type.
  let n = 0
  for (const p of creep.body) if (p.type == type) n++
  return n
}

function chebyshev(a, b) {
  // Returns the tile range between two points in one room.
  return Math.max(Math.abs(a.x - b.x), Math.abs(a.y - b.y))
}

function makePlan(room) {
  // Computes the static room layout once per global reset.
  const terrain = room.getTerrain()
  const spawn = room.find(FIND_MY_SPAWNS)[0]
  const controller = room.controller
  const blocked = new Set()
  for (const s of room.find(FIND_SOURCES)) blocked.add(s.pos.x + ":" + s.pos.y)
  for (const m of room.find(FIND_MINERALS)) blocked.add(m.pos.x + ":" + m.pos.y)
  blocked.add(controller.pos.x + ":" + controller.pos.y)
  blocked.add(spawn.pos.x + ":" + spawn.pos.y)
  const free = (x, y) => {
    if (x < 1 || y < 1 || x > 48 || y > 48) return false
    if (terrain.get(x, y) == TERRAIN_MASK_WALL) return false
    return !blocked.has(x + ":" + y)
  }
  const searchOpts = { plainCost: 2, swampCost: 10, maxRooms: 1 }

  // Piles: tiles near the controller ringed by upgrade slots. Every
  // pile must stay reachable from the spawn with all slots occupied.
  const used = new Set()
  const walls = new Set()
  const piles = []
  const blockedMatrix = (extra) => {
    const m = new PathFinder.CostMatrix()
    for (const k of walls) {
      const [x, y] = k.split(":").map(Number)
      m.set(x, y, 0xff)
    }
    for (const s of extra) m.set(s.x, s.y, 0xff)
    for (const k of blocked) {
      const [x, y] = k.split(":").map(Number)
      m.set(x, y, 0xff)
    }
    return m
  }
  const reach = (target, matrix) => {
    const r = PathFinder.search(spawn.pos,
      { pos: new RoomPosition(target.x, target.y, room.name), range: 0 },
      Object.assign({ roomCallback: () => matrix }, searchOpts))
    return r.incomplete ? null : r.path
  }
  const doors = new Set()
  for (let n = 0; n < PileCount; n++) {
    const candidates = []
    for (let dx = -2; dx <= 2; dx++) {
      for (let dy = -2; dy <= 2; dy++) {
        const x = controller.pos.x + dx, y = controller.pos.y + dy
        const key = x + ":" + y
        if (!free(x, y) || used.has(key) || doors.has(key)) continue
        const slots = []
        for (let ax = -1; ax <= 1; ax++) {
          for (let ay = -1; ay <= 1; ay++) {
            if (ax == 0 && ay == 0) continue
            const sx = x + ax, sy = y + ay
            const skey = sx + ":" + sy
            if (!free(sx, sy) || used.has(skey) || doors.has(skey)) continue
            if (chebyshev({ x: sx, y: sy }, controller.pos) > 3) continue
            slots.push({ x: sx, y: sy })
          }
        }
        const score = slots.length * 100 - chebyshev({ x, y }, spawn.pos)
        candidates.push({ x, y, slots, score })
      }
    }
    candidates.sort((a, b) => b.score - a.score)
    let chosen = null
    for (const cand of candidates) {
      if (cand.slots.length < 3) break
      const path = reach(cand, blockedMatrix([]))
      if (!path || path.length < 2) continue
      // The last step before the pile stays free as the hauler door.
      const door = path[path.length - 2]
      const slots = cand.slots.filter(s => !(s.x == door.x && s.y == door.y))
      const matrix = blockedMatrix(slots)
      if (piles.every(p => reach(p, matrix)) && reach(cand, matrix)) {
        chosen = { x: cand.x, y: cand.y, slots, door: { x: door.x, y: door.y } }
        break
      }
    }
    if (!chosen) break
    used.add(chosen.x + ":" + chosen.y)
    doors.add(chosen.door.x + ":" + chosen.door.y)
    for (const s of chosen.slots) {
      used.add(s.x + ":" + s.y)
      walls.add(s.x + ":" + s.y)
    }
    piles.push(chosen)
  }
  if (piles.length == 0) {
    // Fallback: any tile next to the controller, no reach check.
    for (let dx = -1; dx <= 1 && piles.length == 0; dx++) {
      for (let dy = -1; dy <= 1 && piles.length == 0; dy++) {
        const x = controller.pos.x + dx, y = controller.pos.y + dy
        if (free(x, y)) piles.push({ x, y, slots: [], door: { x, y } })
      }
    }
  }

  const pile = new RoomPosition(piles[0].x, piles[0].y, room.name)
  const planSource = (id, roomName, sx, sy, cap) => {
    const t = Game.map.getRoomTerrain(roomName)
    const ok = (x, y) => {
      if (x < 1 || y < 1 || x > 48 || y > 48) return false
      if (t.get(x, y) == TERRAIN_MASK_WALL) return false
      return roomName != room.name || free(x, y)
    }
    const spots = []
    for (let dx = -1; dx <= 1; dx++) {
      for (let dy = -1; dy <= 1; dy++) {
        if ((dx || dy) && ok(sx + dx, sy + dy)) spots.push({ x: sx + dx, y: sy + dy })
      }
    }
    // Station: where haulers wait, next to as many spots as possible.
    const toward = roomName == room.name ? pile : new RoomPosition(25, 25, roomName)
    let station = null
    for (let dx = -2; dx <= 2; dx++) {
      for (let dy = -2; dy <= 2; dy++) {
        const x = sx + dx, y = sy + dy
        if (!ok(x, y) || (dx == 0 && dy == 0)) continue
        const isSpot = spots.some(p => p.x == x && p.y == y)
        let near = 0
        for (const p of spots) {
          if (p.x == x && p.y == y) continue
          if (chebyshev(p, { x, y }) <= 1) near++
        }
        const score = Math.min(near, 3) * 100 - (isSpot ? 150 : 0) -
          chebyshev({ x, y }, toward)
        if (!station || score > station.score) station = { x, y, score }
      }
    }
    const minerSpots = spots.filter(p => !(p.x == station.x && p.y == station.y))
    minerSpots.sort((p, q) => chebyshev(p, station) - chebyshev(q, station))
    const from = new RoomPosition(station.x, station.y, roomName)
    const opts = { plainCost: 2, swampCost: 10, maxRooms: 6, maxOps: 20000 }
    const route = PathFinder.search(from, { pos: pile, range: 0 }, opts)
    const home = PathFinder.search(from, { pos: spawn.pos, range: 1 }, opts)
    return {
      id,
      room: roomName,
      x: sx,
      y: sy,
      cap,
      remote: roomName != room.name,
      spots: minerSpots,
      station: { x: station.x, y: station.y },
      distance: route.path.length,
      spawnDistance: home.path.length
    }
  }
  const sources = []
  for (const s of room.find(FIND_SOURCES)) {
    sources.push(planSource(s.id, room.name, s.pos.x, s.pos.y, 10))
  }
  return {
    room: room.name,
    spawn: spawn.id,
    piles,
    slotCount: piles.reduce((n, p) => n + p.slots.length, 0),
    remoteRooms: [...new Set((Remotes[room.name] || []).map(r => r.room))],
    pendingRemotes: UseRemotes ? (Remotes[room.name] || []).slice() : [],
    planSource,
    sources
  }
}

function baseCosts(roomName) {
  // Returns a cached cost matrix with structures marked as walls.
  const room = Game.rooms[roomName]
  if (!room) return null
  let cached = heap.costs[roomName]
  if (cached && cached.time + 50 > Game.time) return cached.matrix
  const matrix = new PathFinder.CostMatrix()
  for (const s of room.find(FIND_STRUCTURES)) {
    if (s.structureType == STRUCTURE_ROAD) {
      matrix.set(s.pos.x, s.pos.y, 1)
    } else if (s.structureType == STRUCTURE_CONTAINER ||
      (s.structureType == STRUCTURE_RAMPART && s.my)) {
        continue
    } else {
      matrix.set(s.pos.x, s.pos.y, 0xff)
    }
  }
  heap.costs[roomName] = { time: Game.time, matrix }
  return matrix
}

function tickCosts(roomName) {
  // Returns this tick's matrix: posted and foreign creeps are walls.
  const cached = heap.tickCosts[roomName]
  if (cached && cached.time == Game.time) return cached.matrix
  const base = baseCosts(roomName)
  if (!base) return undefined
  const matrix = base.clone()
  for (const c of Game.rooms[roomName].find(FIND_CREEPS)) {
    if (!c.my || c.memory.posted) matrix.set(c.pos.x, c.pos.y, 0xff)
  }
  heap.tickCosts[roomName] = { time: Game.time, matrix }
  return matrix
}

function findPath(from, to, range, crowded) {
  // Returns a path around walls, posted creeps and, when crowded,
  // every creep near the start.
  const result = PathFinder.search(from, { pos: to, range }, {
    plainCost: 2,
    swampCost: 10,
    maxOps: 6000,
    roomCallback: (roomName) => {
      const costs = tickCosts(roomName)
      if (!costs || !crowded || roomName != from.roomName) return costs
      const near = costs.clone()
      for (const c of Game.rooms[roomName].find(FIND_CREEPS)) {
        if (c.pos.getRangeTo(from) <= 3) near.set(c.pos.x, c.pos.y, 0xff)
      }
      return near
    }
  })
  return result.path
}

function go(creep, target, range) {
  // Moves a creep toward target along a heap cached path.
  if (creep.pos.roomName == target.roomName &&
    creep.pos.inRangeTo(target, range)) {
      return true
  }
  if (creep.fatigue > 0) return false
  const key = posKey(target) + ":" + range
  let m = heap.paths[creep.name]
  let crowded = false
  if (m && m.key == key) {
    // Find the creep on its path, allowing for exit tile jumps.
    for (let j = m.i; j < Math.min(m.i + 3, m.path.length); j++) {
      if (creep.pos.isEqualTo(m.path[j])) {
        m.i = j + 1
        break
      }
    }
    if (m.last == posKey(creep.pos)) {
      m.stuck++
    } else {
      m.stuck = 0
    }
    if (m.stuck >= 4) crowded = true
    if (crowded || m.i >= m.path.length || !creep.pos.isNearTo(m.path[m.i])) {
      m = null
    }
  } else {
    m = null
  }
  if (!m) {
    m = { key, path: findPath(creep.pos, target, range, crowded), i: 0, stuck: 0 }
    heap.paths[creep.name] = m
    if (m.path.length == 0) {
      creep.moveTo(target, { range, reusePath: 0 })
      return false
    }
  }
  m.last = posKey(creep.pos)
  const next = m.path[m.i]
  creep.move(creep.pos.getDirectionTo(next))
  heap.intents.set(creep.name, next)
  return false
}

function resolveTraffic() {
  // Swaps idle creeps out of the way of moving ones.
  const occupants = new Map()
  for (const name in Game.creeps) {
    const c = Game.creeps[name]
    if (!c.spawning) occupants.set(posKey(c.pos), c)
  }
  for (const [name, next] of heap.intents) {
    const creep = Game.creeps[name]
    const other = occupants.get(posKey(next))
    if (!other || other == creep || heap.intents.has(other.name)) continue
    if (other.memory.posted || other.fatigue > 0) continue
    other.move(other.pos.getDirectionTo(creep.pos))
    heap.intents.set(other.name, creep.pos)
  }
}

function census(plan) {
  // Groups creeps by role and source for this tick.
  const c = { m: [], h: [], u: [], bySource: {}, haulCarry: 0 }
  for (const s of plan.sources) c.bySource[s.id] = { work: 0, miners: [] }
  for (const name in Game.creeps) {
    const creep = Game.creeps[name]
    const role = creep.memory.role
    if (!c[role]) continue
    c[role].push(creep)
    // Creeps about to die no longer count for spawning.
    const aging = creep.ticksToLive !== undefined && creep.ticksToLive < 50
    if (role == "m" && c.bySource[creep.memory.src]) {
      const b = c.bySource[creep.memory.src]
      b.miners.push(creep)
      if (!aging) b.work += countParts(creep, WORK)
    }
    if (role == "h" && !aging) c.haulCarry += countParts(creep, CARRY) * 50
  }
  return c
}

function minerBody(budget) {
  // Builds a miner body that hands its harvest to haulers.
  if (budget >= 600) return [WORK, WORK, WORK, WORK, WORK, CARRY, MOVE]
  if (budget >= 400) return [WORK, WORK, WORK, CARRY, MOVE]
  if (budget >= 300) return [WORK, WORK, CARRY, MOVE]
  return [WORK, CARRY, MOVE]
}

function haulerBody(budget) {
  // Builds a hauler body with one MOVE per CARRY.
  const body = []
  const pairs = Math.max(1, Math.min(16, Math.floor(budget / 100)))
  for (let i = 0; i < pairs; i++) body.push(CARRY)
  for (let i = 0; i < pairs; i++) body.push(MOVE)
  return body
}

function upgraderBody(budget) {
  // Builds an upgrader body that walks once and then stays.
  const work = Math.max(1, Math.min(10, Math.floor((budget - 100) / 100)))
  const body = []
  for (let i = 0; i < work; i++) body.push(WORK)
  body.push(CARRY, MOVE)
  return body
}

function spawnNext(room, plan, c) {
  // Picks the next creep to build, or null.
  const cap = room.energyCapacityAvailable
  const left = MatchTicks - (Game.time - Memory.start)
  if (left < 60) return null
  const home = plan.sources.filter(s => !s.remote).sort((a, b) =>
    a.spawnDistance - b.spawnDistance)
  const remote = plan.sources.filter(s => s.remote)
  // Opening: a small miner and a small hauler right away.
  if (c.m.length == 0) {
    return { body: [WORK, CARRY, MOVE], memory: { role: "m", src: home[0].id } }
  }
  if (c.h.length == 0) {
    return { body: [CARRY, MOVE], memory: { role: "h" } }
  }
  // Haul demand follows the current sink: the spawn while ramping.
  const toPile = c.u.length > 0
  let harvest = 0
  let homeNeed = 0
  let haulNeed = 0
  for (const s of plan.sources) {
    const rate = Math.min(s.cap, c.bySource[s.id].work * 2)
    const d = toPile ? s.distance : s.spawnDistance
    harvest += rate
    haulNeed += rate * (d * 2 + 6)
    if (!s.remote) homeNeed += rate * (d * 2 + 6)
  }
  // Size bodies to what the colony can pay for soon.
  const budget = Math.max(200, Math.min(cap, 30 * (harvest + 1)))
  // Upgrader WORK alive now, and the WORK the income and pile can feed.
  let work = 0
  for (const u of c.u) {
    if (u.ticksToLive === undefined || u.ticksToLive > 30) work += countParts(u, WORK)
  }
  const upkeep = (c.m.length * 300 + c.h.length * 300) / 1500
  const slotWork = plan.slotCount * 2
  const target = Math.min(slotWork,
    Math.floor(harvest + 1 - upkeep) + (heap.pileEnergy > 300 ? 2 : 0))
  const upgrader = { body: upgraderBody(cap), memory: { role: "u" } }
  if (c.haulCarry < homeNeed && left > 200) {
    return { body: haulerBody(Math.min(budget, 300)), memory: { role: "h" } }
  }
  for (const s of home) {
    const b = c.bySource[s.id]
    const young = b.miners.filter(m =>
      m.ticksToLive === undefined || m.ticksToLive >= 50).length
    const spotsLeft = s.spots.length - young
    if (b.work < 5 && spotsLeft <= 0 && left > 200 && budget >= 300) {
      const small = b.miners.find(m => countParts(m, WORK) < 2 &&
        !b.miners.some(n => n.memory.replaces == m.name))
      if (small) {
        return { body: minerBody(300), memory: { role: "m", src: s.id, replaces: small.name } }
      }
    }
    if (b.work >= 5 || spotsLeft <= 0 || left <= 200) continue
    // A one WORK miner only when the spots can still reach five WORK.
    let size = budget
    if (b.work + 1 + (spotsLeft - 1) * 2 < 5) size = Math.max(size, 300)
    return { body: minerBody(size), memory: { role: "m", src: s.id } }
  }
  // Once home is saturated, idle pile energy goes to upgraders before
  // remote haulers, so remotes never starve the controller.
  if (heap.pileEnergy > 300 && work < target && c.u.length < plan.slotCount) {
    return upgrader
  }
  if (c.haulCarry < haulNeed && left > 200) {
    return { body: haulerBody(Math.min(budget, 300)), memory: { role: "h" } }
  }
  // Remote miners before topping up upgraders once upgraders hold three
  // quarters of their target: income compounds, and idle pile energy
  // already pulls upgraders forward above. A new remote opens only with
  // drained piles and upgrade slots to spare.
  if (work < target * 0.75 && c.u.length < plan.slotCount) return upgrader
  for (const s of remote) {
    const b = c.bySource[s.id]
    const young = b.miners.filter(m =>
      m.ticksToLive === undefined || m.ticksToLive >= 50).length
    if (b.work >= 3 || s.spots.length - young <= 0 || left <= 300) continue
    if (b.work == 0 && (left < RemoteStart || heap.pileEnergy > 300 ||
      slotWork - target < 5)) {
        break
    }
    return { body: minerBody(300), memory: { role: "m", src: s.id } }
  }
  if (work < target && c.u.length < plan.slotCount) return upgrader
  return null
}

function runSpawn(room, plan, c) {
  // Spawns the next creep when energy allows.
  const spawn = Game.getObjectById(plan.spawn)
  heap.nextCost = 0
  if (!spawn) return
  const next = spawnNext(room, plan, c)
  if (!next) return
  const cost = bodyCost(next.body)
  heap.nextCost = cost
  if (spawn.spawning || room.energyAvailable < cost) return
  if (next.memory.role == "u") {
    // Give each upgrader a free slot next to a pile.
    const taken = new Set(c.u.map(u => u.memory.pile + ":" + u.memory.slot))
    for (let p = 0; p < plan.piles.length && next.memory.slot === undefined; p++) {
      for (let i = 0; i < plan.piles[p].slots.length; i++) {
        if (!taken.has(p + ":" + i)) {
          next.memory.pile = p
          next.memory.slot = i
          break
        }
      }
    }
    if (next.memory.slot === undefined) return
  }
  const name = next.memory.role + Game.time
  if (spawn.spawnCreep(next.body, name, { memory: next.memory }) == OK) {
    heap.nextCost = 0
  }
}

function runMiner(creep, plan, c) {
  // Harvests from a fixed spot and hands energy toward haulers.
  const src = plan.sources.find(s => s.id == creep.memory.src)
  if (!src) return
  const b = c.bySource[src.id]
  if (creep.memory.spot === undefined) {
    const taken = new Set()
    for (const m of b.miners) {
      if (m.memory.spot !== undefined) taken.add(m.memory.spot)
    }
    for (let i = 0; i < src.spots.length; i++) {
      if (!taken.has(i)) {
        creep.memory.spot = i
        break
      }
    }
    const old = creep.memory.replaces && Game.creeps[creep.memory.replaces]
    if (creep.memory.spot === undefined && old &&
      creep.pos.inRangeTo(new RoomPosition(src.x, src.y, src.room), 4)) {
        old.suicide()
        creep.memory.replaces = undefined
    }
    if (creep.memory.spot === undefined) {
      // Wait near the source until an old miner frees a spot.
      go(creep, new RoomPosition(src.station.x, src.station.y, src.room), 2)
      return
    }
  }
  const spot = src.spots[creep.memory.spot]
  creep.memory.posted = go(creep, new RoomPosition(spot.x, spot.y, src.room), 0)
  if (!creep.memory.posted) return
  const source = Game.getObjectById(src.id)
  if (source && source.energy > 0) creep.harvest(source)
  if (creep.store.energy < 20) return
  // A pile under the miner goes first: haulers pick it up, so it drains.
  if ((heap.drops[src.id] || []).some(d => d.pos.isEqualTo(creep.pos) && d.amount >= 20)) {
    return
  }
  // Hand energy to an adjacent filling hauler.
  for (const h of c.h) {
    if (h.memory.state != "fill" || h.store.getFreeCapacity() == 0) continue
    if (!creep.pos.isNearTo(h)) continue
    creep.transfer(h, RESOURCE_ENERGY)
    return
  }
  // Far miners relay to a miner nearer the station.
  if (chebyshev(spot, src.station) <= 1) return
  for (const m of b.miners) {
    if (m == creep || m.memory.spot === undefined) continue
    const s = src.spots[m.memory.spot]
    if (chebyshev(s, src.station) > 1) continue
    if (!creep.pos.isNearTo(m) || m.store.getFreeCapacity() < 20) continue
    creep.transfer(m, RESOURCE_ENERGY)
    return
  }
}

function assignSource(creep, plan, c) {
  // Sends a hauler to the source with the least haul capacity per need.
  let best = null
  for (const s of plan.sources) {
    const rate = Math.min(s.cap, c.bySource[s.id].work * 2)
    if (rate == 0) continue
    let carry = 0
    for (const h of c.h) {
      if (h.memory.src == s.id && h != creep) carry += h.store.getCapacity()
    }
    const ratio = carry / (rate * (s.distance * 2 + 6))
    if (!best || ratio < best.ratio) best = { id: s.id, ratio }
  }
  return best ? best.id : plan.sources[0].id
}

function pickPile(plan, c) {
  // Returns the pile whose upgraders need energy the most.
  let best = 0, bestNeed = -Infinity
  for (let p = 0; p < plan.piles.length; p++) {
    let need = -(heap.pileEnergies[p] || 0)
    for (const u of c.u) {
      if (u.memory.pile == p) need += u.store.getFreeCapacity() + 20
    }
    if (need > bestNeed) {
      bestNeed = need
      best = p
    }
  }
  return best
}

function runHauler(creep, plan, c, room) {
  // Moves energy from miners to the spawn or an upgrade pile.
  if (!creep.memory.state) creep.memory.state = "fill"
  if (creep.memory.state == "fill") {
    if (!creep.memory.src || !c.bySource[creep.memory.src]) {
      creep.memory.src = assignSource(creep, plan, c)
    }
    const src = plan.sources.find(s => s.id == creep.memory.src)
    const b = c.bySource[src.id]
    const free = creep.store.getFreeCapacity()
    if (free == 0 || (b.miners.length == 0 && creep.store.energy > 0)) {
      creep.memory.state = "deliver"
      creep.memory.pile = pickPile(plan, c)
    } else {
      // Grab loose energy in reach; walk to the biggest pile another
      // hauler is not already on; otherwise wait at the station.
      let sweep = null
      let reach = null
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
      }
      if (sweep && free >= 40) {
        heap.swept.add(sweep.id)
        go(creep, sweep.pos, 1)
        return
      }
      const station = new RoomPosition(src.station.x, src.station.y, src.room)
      const busy = Game.rooms[src.room] !== undefined &&
        station.lookFor(LOOK_CREEPS).length > 0 && !creep.pos.isEqualTo(station)
      go(creep, station, busy ? 1 : 0)
      return
    }
  }
  if (creep.memory.state == "deliver") {
    if (creep.store.energy == 0) {
      creep.memory.state = "fill"
      creep.memory.src = assignSource(creep, plan, c)
      return
    }
    const spawn = Game.getObjectById(plan.spawn)
    let need = heap.nextCost - room.energyAvailable - heap.spawnPromised
    // With no upgraders yet, park energy in the spawn instead of a pile.
    if (c.u.length == 0 && spawn) {
      need = Math.max(need, spawn.store.getFreeCapacity(RESOURCE_ENERGY) -
        heap.spawnPromised)
    }
    if (spawn && need > 0 && creep.memory.target != "pile") {
      creep.memory.target = "spawn"
      heap.spawnPromised += Math.min(need, creep.store.energy)
      if (go(creep, spawn.pos, 1)) {
        const amount = Math.min(creep.store.energy,
          spawn.store.getFreeCapacity(RESOURCE_ENERGY))
        if (amount > 0) creep.transfer(spawn, RESOURCE_ENERGY, amount)
        creep.memory.target = undefined
        if (creep.store.energy - amount < 50) {
          creep.memory.state = "fill"
          creep.memory.src = assignSource(creep, plan, c)
        }
      }
      return
    }
    creep.memory.target = "pile"
    const p = plan.piles[creep.memory.pile || 0]
    if (go(creep, new RoomPosition(p.x, p.y, plan.room), 0)) {
      creep.drop(RESOURCE_ENERGY)
      creep.memory.target = undefined
      creep.memory.state = "fill"
      creep.memory.src = assignSource(creep, plan, c)
    }
  }
}

function runUpgrader(creep, plan, room) {
  // Walks to a slot next to its pile, then picks up and upgrades.
  const pile = plan.piles[creep.memory.pile]
  const slot = pile && pile.slots[creep.memory.slot]
  if (!slot) return
  creep.memory.posted = go(creep, new RoomPosition(slot.x, slot.y, plan.room), 0)
  if (!creep.memory.posted) {
    if (creep.store.energy > 0 && creep.pos.inRangeTo(room.controller, 3)) {
      creep.upgradeController(room.controller)
    }
    return
  }
  const drop = heap.pileDrops[creep.memory.pile]
  if (drop && creep.store.getFreeCapacity() > 0) creep.pickup(drop)
  if (creep.store.energy > 0) creep.upgradeController(room.controller)
}

function scanDrops(room, plan) {
  // Records dropped energy near sources and on the piles.
  heap.drops = {}
  heap.backlog = 0
  heap.pileDrops = []
  heap.pileEnergies = []
  heap.pileEnergy = 0
  const drops = room.find(FIND_DROPPED_RESOURCES)
  for (const name of plan.remoteRooms) {
    if (Game.rooms[name]) drops.push(...Game.rooms[name].find(FIND_DROPPED_RESOURCES))
  }
  for (const d of drops) {
    if (d.resourceType != RESOURCE_ENERGY) continue
    const p = d.pos.roomName != plan.room ? -1 :
      plan.piles.findIndex(p => p.x == d.pos.x && p.y == d.pos.y)
    if (p >= 0) {
      heap.pileDrops[p] = d
      heap.pileEnergies[p] = d.amount
      heap.pileEnergy += d.amount
      continue
    }
    for (const s of plan.sources) {
      if (s.room == d.pos.roomName && chebyshev(d.pos, s) <= 2) {
        heap.backlog += d.amount
        if (!heap.drops[s.id]) heap.drops[s.id] = []
        heap.drops[s.id].push(d)
      }
    }
  }
}

function cleanMemory() {
  // Drops memory and heap entries of dead creeps.
  for (const name in Memory.creeps) {
    if (!Game.creeps[name]) {
      delete Memory.creeps[name]
      delete heap.paths[name]
    }
  }
}

function safely(label, fn) {
  // Runs fn and logs, at most once per 100 ticks, what it throws.
  try {
    fn()
  } catch (error) {
    if (!heap.errorAt || Game.time - heap.errorAt >= 100) {
      heap.errorAt = Game.time
      console.log("[mokosh] error " + label + ": " + (error && error.stack || error))
    }
  }
}

function report(room, c) {
  // Logs a one line status to the private seat log.
  if (Game.time == Memory.start) {
    console.log("[mokosh] plan " + JSON.stringify(heap.plan.piles.map(p =>
      [p.x, p.y, p.door.x, p.door.y, p.slots.length])) + " sources " +
      JSON.stringify(heap.plan.sources.map(s => [s.x, s.y, s.station.x,
        s.station.y, s.spots.length, s.distance, s.spawnDistance])))
  }
  console.log("[mokosh] t=" + (Game.time - Memory.start) +
    " rcl=" + room.controller.level +
    " gcl=" + Math.floor(Game.gcl.progress) +
    " energy=" + room.energyAvailable +
    " m=" + c.m.length + " h=" + c.h.length + " u=" + c.u.length +
    " pile=" + heap.pileEnergy +
    " cpu=" + Game.cpu.getUsed().toFixed(2) +
    " bucket=" + Game.cpu.bucket)
  // Diagnostics: source leftovers, hauler states, stuck and idle creeps.
  const srcs = heap.plan.sources.map(s => {
    const o = Game.getObjectById(s.id)
    return s.room.slice(-2) + ":" + (o ? o.energy + "/" + (o.ticksToRegeneration || 0) : "?") +
      ":w" + c.bySource[s.id].work
  })
  const fill = c.h.filter(h => h.memory.state == "fill")
  const carried = c.h.reduce((n, h) => n + h.store.energy, 0)
  let stuck = 0
  for (const name in heap.paths) if (heap.paths[name].stuck >= 2) stuck++
  const posted = c.u.filter(u => u.memory.posted).length
  const empty = c.u.filter(u => u.memory.posted && u.store.energy == 0).length
  console.log("[diag] src " + srcs.join(" ") + " fill=" + fill.length +
    " carried=" + carried + " stuck=" + stuck + " posted=" + posted +
    " dry=" + empty)
}

module.exports.loop = function () {
  if (Memory.start === undefined) Memory.start = Game.time
  if (!Memory.creeps) Memory.creeps = {}
  const spawn = Object.values(Game.spawns)[0]
  if (!spawn) return
  const room = spawn.room
  if (!heap.plan || heap.plan.room != room.name) heap.plan = makePlan(room)
  const plan = heap.plan
  // Remote sources are planned later, one per tick, to spare the CPU.
  if (plan.pendingRemotes.length > 0 && Game.time - Memory.start > 30 &&
    Game.cpu.bucket > 300) {
      const r = plan.pendingRemotes.shift()
      safely("plan " + r.room, () =>
        plan.sources.push(plan.planSource(r.id, r.room, r.x, r.y, 5)))
  }
  cleanMemory()
  scanDrops(room, plan)
  const c = census(plan)
  heap.spawnPromised = 0
  heap.swept = new Set()
  heap.intents = new Map()
  safely("spawn", () => runSpawn(room, plan, c))
  for (const creep of c.m) {
    if (!creep.spawning) safely(creep.name, () => runMiner(creep, plan, c))
  }
  for (const creep of c.h) {
    if (!creep.spawning) safely(creep.name, () => runHauler(creep, plan, c, room))
  }
  for (const creep of c.u) {
    if (!creep.spawning) safely(creep.name, () => runUpgrader(creep, plan, room))
  }
  safely("traffic", resolveTraffic)
  if ((Game.time - Memory.start) % LogEvery == 0) report(room, c)
}
