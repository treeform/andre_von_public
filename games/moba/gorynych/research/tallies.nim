## Action-space tallies over a parsed MOBA replay.
## Replays store post-clamp actions only (docs/PROTOCOL.md). Positions
## are not present, so lane labels are direction votes, not occupancy.

import
  std/[json, math],
  replays

const
  DirectionNames = [
    "hold", "north", "south", "east", "west",
    "northeast", "northwest", "southeast", "southwest"
  ]
  AssignedLanes = [2, 1, 1, 0, 2]
  LaneNames = ["top", "mid", "bot"]

type
  Direction* = enum
    Hold, North, South, East, West,
    Northeast, Northwest, Southeast, Southwest
  HeroTally* = object
    pid*: int
    team*: int
    role*: string
    assignedLane*: string
    ticks*: int
    noops*: int
    holds*: int
    discreteVel*: int
    analogVel*: int
    targetAll*: int
    targetHeroTower*: int
    targetOther*: int
    skillQ*: int
    skillW*: int
    skillE*: int
    multiSkill*: int
    maxNoopRun*: int
    directions*: array[9, int]
    laneVotes*: array[4, int]
    thirds*: array[3, array[9, int]]
    primaryDirection*: string
    primaryLaneVote*: string
  GameTally* = object
    ticks*: int
    seed*: int
    wasmSha*: string
    endReason*: string
    winner*: string
    heroesPerSeat*: int
    playerNames*: seq[string]
    positionsRecoverable*: bool
    heroes*: array[NumHeroes, HeroTally]
    teamStack*: array[2, float]
    teamHoldTogether*: array[2, float]
    finalTickHeader*: int
    ancientHealths*: seq[float]
    agentStats*: JsonNode

proc classify*(velY, velX: int): Direction =
  ## Maps velocity bins to an 8-direction plus hold.
  let
    dy = velY - 3
    dx = velX - 3
  if dy == 0 and dx == 0:
    return Hold
  let
    south = dy > 0
    north = dy < 0
    east = dx > 0
    west = dx < 0
  if north and east: return Northeast
  if north and west: return Northwest
  if south and east: return Southeast
  if south and west: return Southwest
  if north: return North
  if south: return South
  if east: return East
  West

proc laneVote*(team: int, d: Direction): int =
  ## Votes 0 top, 1 mid, 2 bot, 3 retreat/hold from a direction.
  if d == Hold:
    return 3
  if team == 0:
    case d
    of North, Northwest: 0
    of Northeast: 1
    of East, Southeast: 2
    else: 3
  else:
    case d
    of South, Southeast: 0
    of Southwest: 1
    of West, Northwest: 2
    else: 3

proc isDiscreteVel(velY, velX: int): bool =
  ## Reports whether both velocity bins are scripted-like 0/3/6.
  (velY in [0, 3, 6]) and (velX in [0, 3, 6])

proc cosine(a, b: openArray[int]): float =
  ## Cosine similarity of two non-negative count vectors.
  var
    dot = 0.0
    na = 0.0
    nb = 0.0
  let n = min(a.len, b.len)
  for i in 0 ..< n:
    let
      x = float(a[i])
      y = float(b[i])
    dot += x * y
    na += x * x
    nb += y * y
  if na == 0.0 and nb == 0.0:
    return 1.0
  if na == 0.0 or nb == 0.0:
    return 0.0
  dot / (sqrt(na) * sqrt(nb))

proc primaryIndex(counts: openArray[int]): int =
  ## Returns the first index of the largest count.
  result = 0
  for i in 1 ..< counts.len:
    if counts[i] > counts[result]:
      result = i

proc initHero(pid: int): HeroTally =
  ## Builds an empty per-hero tally.
  result.pid = pid
  result.team = teamOf(pid)
  result.role = roleName(pid)
  result.assignedLane = LaneNames[AssignedLanes[roleOf(pid)]]

proc tallyReplay*(replay: Replay): GameTally {.raises: [ReplayError].} =
  ## Accumulates action distributions for every hero.
  result.ticks = replay.tickCount
  result.seed = seedOf(replay)
  result.wasmSha = replay.header{"sim_wasm_sha256"}.getStr("")
  result.heroesPerSeat = replay.heroesPerSeat()
  result.playerNames = replay.playerNames()
  result.positionsRecoverable = false
  let outcome = resultOf(replay)
  result.endReason =
    if outcome{"end_reason"}.isNil: ""
    else: outcome{"end_reason"}.getStr("")
  result.finalTickHeader =
    if outcome{"final_tick"}.isNil: -1
    else: outcome{"final_tick"}.getInt(-1)
  let winnerNode = outcome{"winner"}
  if winnerNode.isNil:
    result.winner = ""
  elif winnerNode.kind == JInt:
    let winner = winnerNode.getInt(-1)
    result.winner =
      if winner == 0: "radiant"
      elif winner == 1: "dire"
      else: $winner
  elif winnerNode.kind == JNull:
    result.winner = "draw"
  else:
    result.winner = winnerNode.getStr("")
  let healths = outcome{"ancient_healths"}
  result.ancientHealths = @[]
  if not healths.isNil and healths.kind == JArray:
    for value in healths:
      result.ancientHealths.add value.getFloat()
  result.agentStats = outcome{"agent_stats"}
  if result.agentStats.isNil:
    result.agentStats = newJArray()
  for pid in 0 ..< NumHeroes:
    result.heroes[pid] = initHero(pid)
  var
    noopRun: array[NumHeroes, int]
    holdMask: seq[array[NumHeroes, bool]]
  holdMask.setLen(replay.tickCount)
  let third = max(1, replay.tickCount div 3)
  for tick in 0 ..< replay.tickCount:
    let thirdIndex =
      if tick < third: 0
      elif tick < third * 2: 1
      else: 2
    for pid in 0 ..< NumHeroes:
      let row = replay.rowAt(tick, pid)
      var hero = result.heroes[pid]
      inc hero.ticks
      let
        velY = int(row[0])
        velX = int(row[1])
        target = int(row[2])
        useQ = int(row[3])
        useW = int(row[4])
        useE = int(row[5])
      if isNoop(row):
        inc hero.noops
        inc noopRun[pid]
        if noopRun[pid] > hero.maxNoopRun:
          hero.maxNoopRun = noopRun[pid]
      else:
        noopRun[pid] = 0
      if isDiscreteVel(velY, velX):
        inc hero.discreteVel
      else:
        inc hero.analogVel
      case target
      of 0, 1:
        inc hero.targetAll
      of 2:
        inc hero.targetHeroTower
      else:
        inc hero.targetOther
      if useQ == 1: inc hero.skillQ
      if useW == 1: inc hero.skillW
      if useE == 1: inc hero.skillE
      if useQ + useW + useE >= 2:
        inc hero.multiSkill
      let d = classify(velY, velX)
      inc hero.directions[ord(d)]
      inc hero.thirds[thirdIndex][ord(d)]
      inc hero.laneVotes[laneVote(hero.team, d)]
      if d == Hold:
        inc hero.holds
        holdMask[tick][pid] = true
      result.heroes[pid] = hero
  for pid in 0 ..< NumHeroes:
    var hero = result.heroes[pid]
    hero.primaryDirection = DirectionNames[primaryIndex(hero.directions)]
    const VoteNames = ["top", "mid", "bot", "retreat_or_hold"]
    hero.primaryLaneVote = VoteNames[primaryIndex(hero.laneVotes)]
    result.heroes[pid] = hero
  for team in 0 .. 1:
    var similar = 0.0
    var pairs = 0
    let base = team * 5
    for i in 0 ..< 5:
      for j in i + 1 ..< 5:
        similar += cosine(
          result.heroes[base + i].directions,
          result.heroes[base + j].directions
        )
        inc pairs
    result.teamStack[team] =
      if pairs == 0: 0.0 else: similar / float(pairs)
    var together = 0
    for tick in 0 ..< replay.tickCount:
      var holds = 0
      for i in 0 ..< 5:
        if holdMask[tick][base + i]:
          inc holds
      if holds >= 4:
        inc together
    result.teamHoldTogether[team] =
      if replay.tickCount == 0: 0.0
      else: float(together) / float(replay.tickCount)

proc rate(count, ticks: int): float =
  ## Returns count / ticks, or 0.
  if ticks <= 0: 0.0 else: float(count) / float(ticks)

proc heroJson(hero: HeroTally): JsonNode =
  ## Serializes one hero tally.
  result = %*{
    "pid": hero.pid,
    "team": TeamNames[hero.team],
    "role": hero.role,
    "assigned_lane": hero.assignedLane,
    "ticks": hero.ticks,
    "noop_rate": rate(hero.noops, hero.ticks),
    "hold_rate": rate(hero.holds, hero.ticks),
    "discrete_vel_rate": rate(hero.discreteVel, hero.ticks),
    "analog_vel_rate": rate(hero.analogVel, hero.ticks),
    "target_all_rate": rate(hero.targetAll, hero.ticks),
    "target_heroes_towers_rate": rate(hero.targetHeroTower, hero.ticks),
    "skill_q_rate": rate(hero.skillQ, hero.ticks),
    "skill_w_rate": rate(hero.skillW, hero.ticks),
    "skill_e_rate": rate(hero.skillE, hero.ticks),
    "multi_skill_rate": rate(hero.multiSkill, hero.ticks),
    "max_noop_run": hero.maxNoopRun,
    "primary_direction": hero.primaryDirection,
    "primary_lane_vote": hero.primaryLaneVote
  }
  var dirs = newJObject()
  for i, name in DirectionNames:
    dirs[name] = %rate(hero.directions[i], hero.ticks)
  result["directions"] = dirs
  var votes = newJObject()
  votes["top"] = %rate(hero.laneVotes[0], hero.ticks)
  votes["mid"] = %rate(hero.laneVotes[1], hero.ticks)
  votes["bot"] = %rate(hero.laneVotes[2], hero.ticks)
  votes["retreat_or_hold"] = %rate(hero.laneVotes[3], hero.ticks)
  result["lane_votes"] = votes
  var thirds = newJArray()
  for t in 0 .. 2:
    var row = newJObject()
    var sum = 0
    for i in 0 .. 8:
      sum += hero.thirds[t][i]
    for i, name in DirectionNames:
      row[name] = %rate(hero.thirds[t][i], sum)
    thirds.add row
  result["direction_thirds"] = thirds

proc tallyJson*(tally: GameTally): JsonNode =
  ## Serializes one game tally.
  result = %*{
    "ticks": tally.ticks,
    "seed": tally.seed,
    "sim_wasm_sha256": tally.wasmSha,
    "end_reason": tally.endReason,
    "winner": tally.winner,
    "heroes_per_seat": tally.heroesPerSeat,
    "player_names": tally.playerNames,
    "positions_recoverable": tally.positionsRecoverable,
    "final_tick_header": tally.finalTickHeader,
    "ancient_healths": tally.ancientHealths,
    "radiant_stack_cosine": tally.teamStack[0],
    "dire_stack_cosine": tally.teamStack[1],
    "radiant_hold_together": tally.teamHoldTogether[0],
    "dire_hold_together": tally.teamHoldTogether[1],
    "agent_stats": tally.agentStats
  }
  var heroes = newJArray()
  for hero in tally.heroes:
    heroes.add heroJson(hero)
  result["heroes"] = heroes
