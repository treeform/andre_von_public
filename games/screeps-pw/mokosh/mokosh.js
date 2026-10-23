// Mokosh: a 1500 tick GCL race colony for Screeps PW (0.1.11 matched homes).
// Immobile WORK miners and WORK/CARRY upgraders are towed into place by
// haulers; haulers carry source drops to the spawn while ramping and to
// controller piles afterwards, where upgraders pick up and upgrade.

const MatchTicks = 1500
const LogEvery = 100
const PileCount = 2
const Tune = {
  // Scripted opening: role prefix and body letters, built in order as
  // energy allows; miners go to the source missing the most WORK.
  order: ["m:WW", "h:CM", "h:CCCMMM", "m:WWC", "h:CCCMMM", "h:CCMM", "m:WWC",
    "h:CCMM", "m:WWC", "h:CCCMMM", "h:CCMM", "m:WC", "m:WC", "h:CCCMMM",
    "h:CCCMMM", "h:CCMM"],
  // Per-room openings (the homes are rotated copies but paths tie-break
  // differently); null falls back to order.
  orderW3N3: ["m:WW", "h:CM", "h:CCCMMM", "m:WWC", "h:CCMM", "h:CCMM",
    "m:WWC", "h:CCMM", "m:WWC", "h:CCCMMM", "h:CCMM", "m:WC", "h:CCCMMM",
    "m:WC", "h:CCCMMM", "h:CCMM", "h:CCMM", "h:CCCMMM"],
  orderW2N2: ["m:WW", "h:CM", "h:CCCMMM", "m:WWC", "h:CCCMMM", "h:CCMM",
    "m:WWC", "h:CCMM", "m:WWC", "h:CCCMMM", "h:CCMM", "m:WC", "h:CCCMMM",
    "m:WC", "h:CCCMMM", "h:CCMM"],
  maxUpgraders: 12,    // upgrader cap
  upgrader: "WWC",     // upgrader body
  replaceAt: 100000,   // tick to replace the dropping opener miner with WWC
  miners: ["WW", "WWC", "WC"], // miner bodies per source, in spawn order
  handOver: 3,         // ticks a hauler may spend handing energy to upgraders
  fillDone: 10,        // free capacity at which a hauler leaves to deliver
  spareTarget: 0,      // extra upgrade WORK beyond the harvest rate
  earlyPairs: 1,       // size of the first hauler
  minPairs: 3,         // smallest later hauler (pairs of CARRY, MOVE)
  maxPairs: 3,         // hauler size cap
  backlog: 150,        // source drops that justify a hauler before miners
  haulMax: 1.15,       // extra haulers stop at this multiple of the need
  pileBuffer: 120,     // pile energy kept per upgrader
  pileBase: 100,       // pile energy kept with no upgraders posted
  upgraderStop: 180,   // no upgraders with fewer ticks left
  freeStop: 250,       // free spawn energy still buys upgraders until here
  haulerStop: 250,     // no haulers with fewer ticks left
  minerStop: 350,      // no miners with fewer ticks left
  tripSlack: 12,       // extra ticks per hauler trip
  pileUpgrader: 300,   // idle pile energy that pulls an upgrader forward
  pileToward: "sources", // piles sit on the controller side facing this
  sweepMin: 1000,      // smallest drop a hauler walks to at its source
  waitTiles: 1,        // wait tiles per source for queued haulers
  jitter: 0,           // tug tie-break noise, for robustness samples
  slowWeight: 25,      // ticks of range a slow tow is worth avoiding
  stuckLimit: 2,       // ticks without progress before a crowded repath
  leaveIdle: 0,        // load at which a hauler leaves an idle station
  handWalk: true,      // haulers also hand energy to neighbours while walking
  drainAfter: 700,     // tick after which idle-spawn energy is hauled out
  drainers: 1,         // smallest haulers that drain the spawn
  remoteAt: 700,       // tick from which remote miners may be built
  remoteStop: 500,     // no remote miners with fewer ticks left
  remoteMiner: "WWCM", // remote miner body (walks; tows break at room edges)
  remoteW3N3: [{ room: "W3N4", x: 13, y: 42 }],
  remoteW2N2: []       // W2N1 (17,18) at 51 steps loses 240-380
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
        let toward = chebyshev({ x, y }, spawn.pos)
        if (Tune.pileToward == "sources") {
          toward = 0
          for (const s of room.find(FIND_SOURCES)) toward += chebyshev({ x, y }, s.pos)
        }
        const score = slots.length * 100 - toward
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
    const remote = roomName != room.name
    const remoteTerrain = remote ? Game.map.getRoomTerrain(roomName) : null
    const open = (x, y) => {
      if (!remote) return free(x, y)
      if (x < 1 || y < 1 || x > 48 || y > 48) return false
      return remoteTerrain.get(x, y) != TERRAIN_MASK_WALL
    }
    // Remote stations face the edge toward home.
    let toward = pile
    if (remote) {
      const [hw, hn] = room.name.match(/\d+/g).map(Number)
      const [rw, rn] = roomName.match(/\d+/g).map(Number)
      toward = { x: rw > hw ? 49 : rw < hw ? 0 : 25, y: rn > hn ? 49 : rn < hn ? 0 : 25 }
    }
    const spots = []
    for (let dx = -1; dx <= 1; dx++) {
      for (let dy = -1; dy <= 1; dy++) {
        if ((dx || dy) && open(sx + dx, sy + dy)) spots.push({ x: sx + dx, y: sy + dy })
      }
    }
    // Station: where haulers wait, next to as many spots as possible.
    let station = null
    for (let dx = -2; dx <= 2; dx++) {
      for (let dy = -2; dy <= 2; dy++) {
        const x = sx + dx, y = sy + dy
        if (!open(x, y) || (dx == 0 && dy == 0)) continue
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
    // Wait tiles: where filling haulers queue, each next to a miner spot,
    // the station first, then by how many spots they touch.
    const waits = [{ x: station.x, y: station.y, near: 9 }]
    for (let dx = -2; dx <= 2; dx++) {
      for (let dy = -2; dy <= 2; dy++) {
        const x = sx + dx, y = sy + dy
        if (!open(x, y) || (x == station.x && y == station.y)) continue
        if (minerSpots.some(p => p.x == x && p.y == y)) continue
        let near = 0
        for (const p of minerSpots) if (chebyshev(p, { x, y }) <= 1) near++
        if (near > 0) waits.push({ x, y, near })
      }
    }
    waits.sort((a, b) => b.near - a.near)
    const from = new RoomPosition(station.x, station.y, roomName)
    const opts = { plainCost: 2, swampCost: 10, maxRooms: remote ? 3 : 1, maxOps: 20000 }
    const route = PathFinder.search(from, { pos: pile, range: 0 }, opts)
    const home = PathFinder.search(from, { pos: spawn.pos, range: 1 }, opts)
    return {
      id,
      room: roomName,
      remote,
      x: sx,
      y: sy,
      cap,
      spots: minerSpots,
      station: { x: station.x, y: station.y },
      waits: waits.slice(0, Tune.waitTiles),
      distance: route.path.length,
      spawnDistance: home.path.length
    }
  }
  const sources = room.find(FIND_SOURCES).map(s =>
    planSource(s.id, room.name, s.pos.x, s.pos.y, 10))
  sources.sort((a, b) => a.spawnDistance - b.spawnDistance)
  if (Tune.remoteAt < MatchTicks) {
    for (const r of Tune["remote" + room.name] || []) {
      sources.push(planSource("R" + r.room + ":" + r.x + ":" + r.y, r.room, r.x, r.y, 5))
    }
  }
  return {
    room: room.name,
    spawn: spawn.id,
    piles,
    slotCount: piles.reduce((n, p) => n + p.slots.length, 0),
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
    maxOps: 4000,
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
    if (m.stuck >= Tune.stuckLimit) crowded = true
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
  // Swaps idle mobile creeps out of the way of moving ones.
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
    if (other.memory.role != "h" || heap.towed.has(other.name)) continue
    other.move(other.pos.getDirectionTo(creep.pos))
    heap.intents.set(other.name, creep.pos)
  }
}

function census(plan) {
  // Groups creeps by role and source for this tick.
  const c = { m: [], h: [], u: [], b: [], bySource: {}, haulCarry: 0, upgradeWork: 0 }
  for (const s of plan.sources) {
    c.bySource[s.id] = { work: 0, postedWork: 0, miners: [], buffer: null }
  }
  for (const name in Game.creeps) {
    const creep = Game.creeps[name]
    const role = creep.memory.role
    if (!c[role]) continue
    c[role].push(creep)
    if (role == "m" && c.bySource[creep.memory.src]) {
      const b = c.bySource[creep.memory.src]
      b.miners.push(creep)
      b.work += countParts(creep, WORK)
      if (creep.memory.posted) b.postedWork += countParts(creep, WORK)
    }
    if (role == "h") c.haulCarry += countParts(creep, CARRY) * 50
    if (role == "b" && c.bySource[creep.memory.src]) {
      c.bySource[creep.memory.src].buffer = creep
    }
    if (role == "u") c.upgradeWork += countParts(creep, WORK)
  }
  return c
}

function minerBody(code) {
  // Builds an immobile miner body from a letter code.
  const body = []
  for (const letter of code) {
    body.push(letter == "W" ? WORK : letter == "M" ? MOVE : CARRY)
  }
  return body
}

function haulerBody(pairs) {
  // Builds a hauler body with one MOVE per CARRY.
  const body = []
  for (let i = 0; i < pairs; i++) body.push(CARRY)
  for (let i = 0; i < pairs; i++) body.push(MOVE)
  return body
}

function bodyOf(code) {
  // Builds a body from W, C and M letters.
  const body = []
  for (const letter of code) {
    body.push(letter == "W" ? WORK : letter == "C" ? CARRY : MOVE)
  }
  return body
}

function fits(source, c, work) {
  // True when a miner of this WORK leaves the source able to reach five.
  const b = c.bySource[source.id]
  const spotsLeft = source.spots.length - b.miners.length
  const missing = 5 - b.work
  if (spotsLeft <= 0 || missing <= 0 || work > missing) return false
  return work >= missing - 2 * (spotsLeft - 1)
}

function emptiestSource(plan, c, work) {
  // Returns the source where a miner of this WORK fits, lowest WORK first.
  let pick = null
  for (const s of plan.sources) {
    if (s.remote || !fits(s, c, work)) continue
    if (!pick || c.bySource[s.id].work < c.bySource[pick.id].work) pick = s
  }
  return pick
}

function spawnNext(room, plan, c, left) {
  // Picks the next creep to build, or null.
  const energy = room.energyAvailable
  const built = Memory.built || 0
  const order = Tune["order" + room.name] || Tune.order
  if (built < order.length) {
    const entry = order[built]
    const role = entry[0]
    const at = entry.indexOf("@")
    const code = at < 0 ? entry.slice(2) : entry.slice(2, at)
    if (role == "m") {
      const work = code.split("W").length - 1
      const pick = at < 0 ? emptiestSource(plan, c, work) :
        plan.sources[Number(entry.slice(at + 1))]
      if (pick) return { body: bodyOf(code), memory: { role: "m", src: pick.id } }
    } else if (role == "b") {
      const pick = plan.sources[Number(entry.slice(at + 1))]
      return { body: bodyOf(code), memory: { role: "b", src: pick.id } }
    } else {
      return { body: bodyOf(code), memory: { role } }
    }
  }
  // Opening: a small miner and a small hauler right away.
  if (c.m.length == 0) {
    return { body: minerBody(Tune.miners[0]), memory: { role: "m", src: plan.sources[0].id } }
  }
  if (c.h.length == 0) {
    return { body: haulerBody(Tune.earlyPairs), memory: { role: "h" } }
  }
  // Haul demand follows the current sink: the spawn while ramping.
  const toPile = c.u.length > 0
  let harvest = 0
  let haulNeed = 0
  for (const s of plan.sources) {
    const b0 = c.bySource[s.id]
    const rate = Math.min(s.cap, (s.remote ? b0.postedWork : b0.work) * 2)
    const d = toPile ? s.distance : s.spawnDistance
    harvest += rate
    haulNeed += rate * (d * 2 + Tune.tripSlack)
  }
  const pairs = Math.max(Tune.minPairs, Math.min(Tune.maxPairs, Math.floor(energy / 100)))
  const hauler = { body: haulerBody(pairs), memory: { role: "h" } }
  // Haulers only once drops wait at the sources: miners compound first.
  if (c.haulCarry < haulNeed && heap.backlog >= Tune.backlog && left > Tune.haulerStop) {
    return hauler
  }
  // Replace the dropping opener with a CARRY miner that takes its spot.
  if (MatchTicks - left >= Tune.replaceAt && left > Tune.minerStop) {
    for (const m of c.m) {
      if (m.store.getCapacity() > 0 || m.memory.retiring) continue
      if (c.m.some(n => n.memory.replaces == m.name)) continue
      return { body: minerBody("WWC"), memory: { role: "m", src: m.memory.src,
        spot: m.memory.spot, replaces: m.name } }
    }
  }
  // Miners until every source has five WORK: the biggest body that fits.
  if (left > Tune.minerStop) {
    for (const code of ["WWC", "WC"]) {
      const pick = emptiestSource(plan, c, code.split("W").length - 1)
      if (pick) return { body: minerBody(code), memory: { role: "m", src: pick.id } }
    }
  }
  if (c.haulCarry < haulNeed && left > Tune.haulerStop) return hauler
  // Drops backing up at the sources mean the trip estimate is short.
  if (heap.backlog >= Tune.backlog * 2 && c.haulCarry < haulNeed * Tune.haulMax &&
    left > Tune.haulerStop) {
      return hauler
  }
  // Remote miners once the opening is done, one per remote source.
  if (MatchTicks - left >= Tune.remoteAt && left > Tune.remoteStop) {
    for (const s of plan.sources) {
      if (!s.remote || c.bySource[s.id].miners.length > 0) continue
      return { body: minerBody(Tune.remoteMiner), memory: { role: "m", src: s.id } }
    }
  }
  // Upgraders: as many WORK as the income feeds, two per creep.
  const target = Math.min(plan.slotCount * 2, Math.floor(harvest) + Tune.spareTarget +
    (heap.pileEnergy > Tune.pileUpgrader ? 2 : 0))
  const upgrader = { body: bodyOf(Tune.upgrader), memory: { role: "u" } }
  const slots = Math.min(plan.slotCount, Tune.maxUpgraders)
  if (c.upgradeWork < target && c.u.length < slots && left > Tune.upgraderStop) {
    return upgrader
  }
  // A full spawn is free energy: one more upgrader while slots remain.
  if (energy >= 300 && c.u.length < plan.slotCount && left > Tune.freeStop) {
    return upgrader
  }
  return null
}

function runSpawn(room, plan, c, left) {
  // Spawns the next creep when energy allows.
  const spawn = Game.getObjectById(plan.spawn)
  heap.nextCost = 0
  if (!spawn) return
  const next = spawnNext(room, plan, c, left)
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
  if (next.memory.role == "m" && next.memory.spot === undefined) {
    // Give each miner a free spot at its source.
    const b = c.bySource[next.memory.src]
    const s = plan.sources.find(s => s.id == next.memory.src)
    const taken = new Set(b.miners.map(m => m.memory.spot))
    for (let i = 0; i < s.spots.length; i++) {
      if (!taken.has(i)) {
        next.memory.spot = i
        break
      }
    }
    if (next.memory.spot === undefined) return
  }
  const name = next.memory.role + Game.time
  if (spawn.spawnCreep(next.body, name, { memory: next.memory }) == OK) {
    heap.nextCost = 0
    Memory.built = (Memory.built || 0) + 1
  }
}

function postOf(creep, plan) {
  // Returns the tile an immobile creep must stand on.
  if (creep.memory.role == "b") {
    const src = plan.sources.find(s => s.id == creep.memory.src)
    return src ? new RoomPosition(src.station.x, src.station.y, src.room) : null
  }
  if (creep.memory.role == "m") {
    const src = plan.sources.find(s => s.id == creep.memory.src)
    const spot = src && src.spots[creep.memory.spot]
    return spot ? new RoomPosition(spot.x, spot.y, src.room) : null
  }
  const pile = plan.piles[creep.memory.pile]
  const slot = pile && pile.slots[creep.memory.slot]
  return slot ? new RoomPosition(slot.x, slot.y, plan.room) : null
}

function assignTugs(plan, c) {
  // Pairs every waiting immobile creep with the nearest free hauler.
  heap.towed = new Set()
  heap.tugs = new Map()
  const busy = new Set()
  for (const h of c.h) {
    const p = h.memory.tug && Game.creeps[h.memory.tug]
    if (p && !p.memory.posted) {
      busy.add(h.name)
      heap.tugs.set(h.name, p)
      heap.towed.add(p.name)
    } else {
      h.memory.tug = undefined
    }
  }
  for (const p of [...c.b, ...c.m, ...c.u]) {
    if (p.spawning || p.memory.posted || heap.towed.has(p.name)) continue
    if (countParts(p, MOVE) > 0) continue
    let best = null
    const parts = p.body.length
    for (const h of c.h) {
      if (h.spawning || busy.has(h.name)) continue
      // Ticks per tile while towing: the passenger's fatigue over the MOVEs.
      const slow = Math.ceil((parts + Math.ceil(h.store.energy / 50)) / countParts(h, MOVE))
      let score = h.pos.getRangeTo(p) + Tune.slowWeight * (slow - 1)
      if (Tune.jitter > 0) {
        let hash = Tune.jitter
        for (let i = 0; i < h.name.length; i++) hash = (hash * 31 + h.name.charCodeAt(i)) % 1009
        score += hash % 3
      }
      if (!best || score < best.score) best = { h, score }
    }
    if (!best) break
    busy.add(best.h.name)
    best.h.memory.tug = p.name
    heap.tugs.set(best.h.name, p)
    heap.towed.add(p.name)
  }
}

function runTug(h, p, plan) {
  // Tows passenger p to its post; returns true while towing.
  const post = postOf(p, plan)
  if (!post) {
    h.memory.tug = undefined
    return false
  }
  if (p.pos.isEqualTo(post)) {
    p.memory.posted = true
    h.memory.tug = undefined
    return false
  }
  if (!h.pos.isNearTo(p)) {
    go(h, p.pos, 1)
    return true
  }
  const old = p.memory.replaces && Game.creeps[p.memory.replaces]
  if (old && p.pos.inRangeTo(post, 3)) {
    // The old miner frees the spot one tick before the newcomer steps in.
    old.memory.retiring = true
    old.suicide()
    p.memory.replaces = undefined
    return true
  }
  h.pull(p)
  p.move(h)
  if (h.pos.isEqualTo(post)) {
    // Swap: the hauler steps onto the passenger, the passenger onto the post.
    h.move(h.pos.getDirectionTo(p.pos))
    heap.intents.set(h.name, p.pos)
    return true
  }
  if (h.fatigue > 0) return true
  go(h, post, 0)
  return true
}

function runMiner(creep, plan, c) {
  // Harvests from its post and hands energy to a waiting hauler.
  if (!creep.memory.posted && countParts(creep, MOVE) > 0) {
    const post = postOf(creep, plan)
    if (post && go(creep, post, 0)) creep.memory.posted = true
  }
  if (!creep.memory.posted) return
  let source = Game.getObjectById(creep.memory.src)
  if (!source) {
    const s = plan.sources.find(s => s.id == creep.memory.src)
    if (s && Game.rooms[s.room]) {
      source = new RoomPosition(s.x, s.y, s.room).lookFor(LOOK_SOURCES)[0]
    }
  }
  if (source && source.energy > 0) creep.harvest(source)
  if (creep.store.energy == 0 || creep.store.getCapacity() == 0) return
  for (const h of c.h) {
    if (h.memory.state != "fill" || h.store.getFreeCapacity() == 0) continue
    if (heap.towed.size > 0 && heap.tugs.has(h.name)) continue
    if (!creep.pos.isNearTo(h)) continue
    creep.transfer(h, RESOURCE_ENERGY)
    return
  }
  const src = plan.sources.find(s => s.id == creep.memory.src)
  const buffer = c.bySource[src.id].buffer
  if (buffer && buffer.memory.posted && creep.pos.isNearTo(buffer) &&
    buffer.store.getFreeCapacity() > 0) {
      creep.transfer(buffer, RESOURCE_ENERGY)
      return
  }
  // Far miners relay to a miner next to the station.
  const spot = src.spots[creep.memory.spot]
  if (chebyshev(spot, src.station) <= 1) return
  for (const m of c.bySource[src.id].miners) {
    if (m == creep || !m.memory.posted) continue
    const s = src.spots[m.memory.spot]
    if (chebyshev(s, src.station) > 1) continue
    if (!creep.pos.isNearTo(m) || m.store.getFreeCapacity() < 10) continue
    creep.transfer(m, RESOURCE_ENERGY)
    return
  }
}

function runBuffer(creep, c) {
  // Hands stored energy to the adjacent filling hauler with the most room.
  if (!creep.memory.posted || creep.store.energy == 0) return
  let best = null
  for (const h of c.h) {
    if (h.memory.state != "fill" || heap.tugs.has(h.name)) continue
    const free = h.store.getFreeCapacity()
    if (free == 0 || !creep.pos.isNearTo(h)) continue
    if (!best || free > best.free) best = { h, free }
  }
  if (best) creep.transfer(best.h, RESOURCE_ENERGY)
}

function assignSource(creep, plan, c) {
  // Sends a hauler to the source with the least haul capacity per need.
  let best = null
  for (const s of plan.sources) {
    const b0 = c.bySource[s.id]
    const rate = Math.min(s.cap, (s.remote ? b0.postedWork : b0.work) * 2)
    if (rate == 0) continue
    let carry = 0
    for (const h of c.h) {
      if (h.memory.src == s.id && h != creep) carry += h.store.getCapacity()
    }
    const ratio = (carry + 1) / (rate * (s.distance * 2 + 6))
    if (!best || ratio < best.ratio) best = { id: s.id, ratio }
  }
  return best ? best.id : plan.sources[0].id
}

function pickPile(plan, c) {
  // Returns the pile whose upgraders need energy the most, counting
  // loads already promised to it.
  let best = 0, bestNeed = -Infinity
  for (let p = 0; p < plan.piles.length; p++) {
    let need = -(heap.pileEnergies[p] || 0) - (heap.pilePromisedBy[p] || 0)
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

function pickDrainers(c, left) {
  // Names the haulers that empty the spawn while it has nothing to build.
  heap.drainers = new Set()
  if (MatchTicks - left < Tune.drainAfter || heap.nextCost > 0) return
  const haulers = c.h.filter(h => !h.spawning && !heap.tugs.has(h.name))
  haulers.sort((a, b) => countParts(a, CARRY) - countParts(b, CARRY) ||
    (a.name < b.name ? -1 : 1))
  for (const h of haulers.slice(0, Tune.drainers)) heap.drainers.add(h.name)
}

function runDrainer(creep, plan, c, left) {
  // Withdraws spawn energy and hauls it to a pile; true while draining.
  if (creep.memory.state != "fill") return false
  const spawn = Game.getObjectById(plan.spawn)
  if (!spawn) return false
  const stock = spawn.store.energy
  const free = creep.store.getFreeCapacity()
  if (free == 0 || (creep.store.energy > 0 && (stock == 0 || left < 40))) {
    creep.memory.state = "deliver"
    creep.memory.target = "pile"
    creep.memory.pile = pickPile(plan, c)
    return false
  }
  if (go(creep, spawn.pos, 1)) {
    // Wait for a full load unless the match is ending.
    if (stock >= free || (left < 40 && stock > 0)) {
      creep.withdraw(spawn, RESOURCE_ENERGY, Math.min(free, stock))
    }
  }
  return true
}

function runHauler(creep, plan, c, room, left) {
  // Moves energy from source drops to the spawn or an upgrade pile.
  if (!creep.memory.state) creep.memory.state = "fill"
  if (heap.drainers.has(creep.name) && runDrainer(creep, plan, c, left)) return
  if (creep.memory.state == "fill") {
    if (!creep.memory.src || !c.bySource[creep.memory.src]) {
      creep.memory.src = assignSource(creep, plan, c)
    }
    const src = plan.sources.find(s => s.id == creep.memory.src)
    const b = c.bySource[src.id]
    const free = creep.store.getFreeCapacity()
    const ending = left < src.distance + 15 && creep.store.energy > 0
    // Idle station: no adjacent miner holds energy and no drop is in reach.
    let idle = Tune.leaveIdle > 0 && creep.store.energy >= Tune.leaveIdle
    if (idle) {
      for (const m of b.miners) {
        if (m.memory.posted && creep.pos.isNearTo(m) && m.store.energy > 0) idle = false
      }
      for (const d of heap.drops[src.id] || []) if (creep.pos.isNearTo(d)) idle = false
    }
    if (free < Tune.fillDone || ending || idle || (b.work == 0 && creep.store.energy > 0)) {
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
        if (d.amount < Tune.sweepMin || heap.swept.has(d.id)) continue
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
      // Take the first wait tile nobody else holds; else queue by the station.
      for (const w of src.waits) {
        const tile = new RoomPosition(w.x, w.y, src.room)
        if (creep.pos.isEqualTo(tile)) return
        if (Game.rooms[src.room] && tile.lookFor(LOOK_CREEPS).length > 0) continue
        go(creep, tile, 0)
        return
      }
      const station = new RoomPosition(src.station.x, src.station.y, src.room)
      go(creep, station, 1)
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
    const spawnFree = spawn ? spawn.store.getFreeCapacity(RESOURCE_ENERGY) : 0
    let need = Math.min(spawnFree, heap.nextCost - room.energyAvailable) - heap.spawnPromised
    // With no upgraders yet, park energy in the spawn instead of a pile.
    if (c.u.length == 0) need = spawnFree - heap.spawnPromised
    const pileCap = Tune.pileBase + Tune.pileBuffer * c.u.length
    const pileRoom = pileCap - heap.pileEnergy - heap.pilePromised
    if (creep.memory.target === undefined) {
      if (need > 0 && left > 60) creep.memory.target = "spawn"
      else if (c.u.length > 0 && (pileRoom > 0 || left <= 60)) creep.memory.target = "pile"
      else creep.memory.target = "hold"
    }
    if (creep.memory.target == "spawn") {
      heap.spawnPromised += Math.min(Math.max(need, 0), creep.store.energy)
      if (go(creep, spawn.pos, 1)) {
        const amount = Math.min(creep.store.energy, spawnFree)
        if (amount > 0) creep.transfer(spawn, RESOURCE_ENERGY, amount)
        creep.memory.target = undefined
        if (creep.store.energy - amount < 50) {
          creep.memory.state = "fill"
          creep.memory.src = assignSource(creep, plan, c)
        }
      }
      return
    }
    if (creep.memory.target == "hold") {
      // Nothing wants energy yet: wait by the spawn and top it up.
      creep.memory.target = undefined
      if (go(creep, spawn.pos, 1)) {
        const amount = Math.min(creep.store.energy, spawnFree)
        if (amount > 0) creep.transfer(spawn, RESOURCE_ENERGY, amount)
      }
      return
    }
    if (!creep.memory.promised) {
      heap.pilePromisedBy[creep.memory.pile || 0] =
        (heap.pilePromisedBy[creep.memory.pile || 0] || 0) + creep.store.energy
    }
    creep.memory.promised = true
    heap.pilePromised += creep.store.energy
    creep.memory.target = "pile"
    const p = plan.piles[creep.memory.pile || 0]
    const pilePos = new RoomPosition(p.x, p.y, plan.room)
    if (Tune.handWalk && !creep.pos.isEqualTo(pilePos)) {
      // On the way in, feed the hungriest adjacent upgrader of any pile.
      let hungry = null
      for (const u of c.u) {
        if (!u.memory.posted || !creep.pos.isNearTo(u)) continue
        const burn = countParts(u, WORK) * left - u.store.energy
        const free = Math.min(u.store.getFreeCapacity(), burn) - (heap.handed[u.name] || 0)
        if (free >= 20 && (!hungry || free > hungry.free)) hungry = { u, free }
      }
      if (hungry) {
        const amount = Math.min(creep.store.energy, hungry.free)
        creep.transfer(hungry.u, RESOURCE_ENERGY, amount)
        heap.handed[hungry.u.name] = (heap.handed[hungry.u.name] || 0) + amount
        if (creep.store.energy - amount <= 0) {
          creep.memory.target = undefined
          creep.memory.promised = undefined
          creep.memory.state = "fill"
          creep.memory.src = assignSource(creep, plan, c)
          return
        }
      }
    }
    if (go(creep, pilePos, 0)) {
      // Hand energy to the hungriest adjacent upgrader; drop the rest when
      // another hauler waits at the door or the hand over takes too long.
      creep.memory.handing = (creep.memory.handing || 0) + 1
      let hungry = null
      for (const u of c.u) {
        if (!u.memory.posted || u.memory.pile != (creep.memory.pile || 0)) continue
        const burn = countParts(u, WORK) * left - u.store.energy
        const free = Math.min(u.store.getFreeCapacity(), burn) - (heap.handed[u.name] || 0)
        if (free <= 0 || !creep.pos.isNearTo(u)) continue
        if (!hungry || free > hungry.free) hungry = { u, free }
      }
      const door = new RoomPosition(p.door.x, p.door.y, plan.room)
      const queued = door.lookFor(LOOK_CREEPS).some(o => o.my && o.memory.role == "h")
      const energy = creep.store.energy
      if (hungry && !(queued && creep.memory.handing > 1) &&
        creep.memory.handing <= Tune.handOver) {
          const amount = Math.min(energy, hungry.free)
          creep.transfer(hungry.u, RESOURCE_ENERGY, amount)
          heap.handed[hungry.u.name] = (heap.handed[hungry.u.name] || 0) + amount
          if (energy - amount > 0) return
      } else if (energy > 0) {
        creep.drop(RESOURCE_ENERGY)
      }
      creep.memory.handing = undefined
      creep.memory.target = undefined
      creep.memory.promised = undefined
      creep.memory.state = "fill"
      creep.memory.src = assignSource(creep, plan, c)
    }
  }
}

function runUpgrader(creep, plan, room, left) {
  // Picks up from its pile and upgrades from its post.
  if (!creep.memory.posted) {
    if (countParts(creep, MOVE) > 0) {
      // Mobile upgraders walk to their post on their own.
      const post = postOf(creep, plan)
      if (post && go(creep, post, 0)) creep.memory.posted = true
    }
    if (creep.store.energy > 0 && creep.pos.inRangeTo(room.controller, 3)) {
      creep.upgradeController(room.controller)
    }
    return
  }
  const drop = heap.pileDrops[creep.memory.pile]
  const burn = countParts(creep, WORK) * left
  if (drop && creep.store.getFreeCapacity() > 0 && creep.store.energy < burn) {
    creep.pickup(drop)
  }
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
  for (const s of plan.sources) {
    if (s.remote && Game.rooms[s.room]) drops.push(...Game.rooms[s.room].find(FIND_DROPPED_RESOURCES))
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
  const srcs = heap.plan.sources.map(s => {
    const o = Game.getObjectById(s.id)
    return (o ? o.energy + "/" + (o.ticksToRegeneration || 0) : "?") +
      ":w" + c.bySource[s.id].work
  })
  const carried = c.h.reduce((n, h) => n + h.store.energy, 0)
  const posted = c.u.filter(u => u.memory.posted).length
  console.log("[mokosh] t=" + (Game.time - Memory.start) +
    " gcl=" + Math.floor(Game.gcl.progress) +
    " energy=" + room.energyAvailable + " next=" + heap.nextCost +
    " m=" + c.m.length + " h=" + c.h.length + " u=" + c.u.length +
    "/" + posted + " pile=" + heap.pileEnergy + " backlog=" + heap.backlog +
    " carried=" + carried + " src=" + srcs.join(" ") +
    " cpu=" + Game.cpu.getUsed().toFixed(1) + " bucket=" + Game.cpu.bucket)
}

module.exports.loop = function () {
  if (Memory.start === undefined) Memory.start = Game.time
  if (!Memory.creeps) Memory.creeps = {}
  const spawn = Object.values(Game.spawns)[0]
  if (!spawn) return
  const room = spawn.room
  if (!heap.plan || heap.plan.room != room.name) heap.plan = makePlan(room)
  const plan = heap.plan
  const left = MatchTicks - (Game.time - Memory.start)
  cleanMemory()
  scanDrops(room, plan)
  const c = census(plan)
  heap.spawnPromised = 0
  heap.pilePromised = 0
  heap.pilePromisedBy = []
  heap.handed = {}
  heap.swept = new Set()
  heap.intents = new Map()
  for (const h of c.h) {
    if (h.memory.state == "deliver" && h.memory.target == "pile") {
      heap.pilePromisedBy[h.memory.pile || 0] =
        (heap.pilePromisedBy[h.memory.pile || 0] || 0) + h.store.energy
    }
  }
  safely("spawn", () => runSpawn(room, plan, c, left))
  safely("tugs", () => assignTugs(plan, c))
  heap.drainers = new Set()
  safely("drainers", () => pickDrainers(c, left))
  for (const creep of c.m) {
    if (!creep.spawning) safely(creep.name, () => runMiner(creep, plan, c))
  }
  for (const creep of c.b) {
    if (!creep.spawning) safely(creep.name, () => runBuffer(creep, c))
  }
  for (const creep of c.h) {
    if (creep.spawning) continue
    const passenger = heap.tugs.get(creep.name)
    if (passenger && !passenger.spawning) {
      let towing = false
      safely(creep.name, () => { towing = runTug(creep, passenger, plan) })
      if (towing) continue
    }
    safely(creep.name, () => runHauler(creep, plan, c, room, left))
  }
  for (const creep of c.u) {
    if (!creep.spawning) safely(creep.name, () => runUpgrader(creep, plan, room, left))
  }
  safely("traffic", resolveTraffic)
  if ((Game.time - Memory.start) % LogEvery == 0) report(room, c)
}
