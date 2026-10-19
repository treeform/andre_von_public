## Volot — Territory policy for Andre von Auto.
## Nim rewrite of /bin/territory-player's scripted side (protocol
## cogweb.player.v1). Both baselines are pure functions of the redacted
## observation — deterministic, always legal, no talk — ported one-for-one
## from src/game/scripted.ts in Metta-AI/cogame-territory @ ad1e8df.
##
## Env:
##   PLAYER_SCRIPTED  homesteader (default) | raider
##
## homesteader: claims the richest reachable walls it can afford, at most 3
## per turn; after turn 14, strip-mines own walls (first raze) when salvage
## 4*effYield beats remaining income. Last turn is salvage-only — a new
## claim dries too late to pay. raider: homesteads through turn 3, then
## from turn 4 razes the banked leader's richest reachable wall (yield >= 3)
## before spending the rest like a homesteader (max 4 claims). The tuned
## numbers (3 / 4 / 3) mirror the upstream sweep (docs/baseline-sweep.md).
## No LLM, no secrets: a command player that answers every observation.

import std/[json, os, strutils, tables], coworld_client

const
  claimBase = 2
  claimPerDistance = 2
  razeCost = 5
  razeHomeCost = 10
  homesteaderMaxClaims = 3
  raiderMaxClaims = 4
  raiderMinYield = 3
  salvageMult = 4
  maxOrders = 8

type Hex = tuple[q, r: int]

proc parseHex(key: string): Hex =
  let parts = key.split(',')
  (parseInt(parts[0].strip()), parseInt(parts[1].strip()))

proc distance(a, b: Hex): int =
  (abs(a.q - b.q) + abs(a.r - b.r) + abs(a.q + a.r - b.q - b.r)) div 2

proc claimCost(dist: int): int =
  claimBase + claimPerDistance * dist

type ViewIndex = object
  ## Per-turn digest of the observation view.
  tiles: Table[string, JsonNode]
  myAlias: string
  origins: seq[Hex]            # my owned tiles, or my hearth if I own none
  foreignHearths: seq[Hex]     # living rivals' hearth hexes

proc indexView(view: JsonNode): ViewIndex =
  result.myAlias = view["you"]["alias"].getStr()
  var aliveRivals: seq[string]
  for cog in view["cogs"]:
    if cog["alive"].getBool() and cog["alias"].getStr() != result.myAlias:
      aliveRivals.add(cog["alias"].getStr())
  for tile in view["tiles"]:
    let key = tile["t"].getStr()
    result.tiles[key] = tile
    if tile["owner"].kind == JString and
        tile["owner"].getStr() == result.myAlias:
      result.origins.add(parseHex(key))
    if tile["hearthOf"].kind == JString and
        tile["hearthOf"].getStr() in aliveRivals:
      result.foreignHearths.add(parseHex(key))
  if result.origins.len == 0:
    result.origins.add(parseHex(view["you"]["hearth"].getStr()))

proc reachDistance(index: ViewIndex, tile: string): int =
  ## Hex distance to my nearest owned tile (or hearth when landless) — the
  ## same predicate the validator prices claims with.
  let target = parseHex(tile)
  result = int.high
  for origin in index.origins:
    result = min(result, distance(origin, target))

proc razeCostOf(index: ViewIndex, tile: string): int =
  ## RAZE_HOME_COST within distance 1 of a living rival's hearth, else RAZE_COST.
  let target = parseHex(tile)
  for hearth in index.foreignHearths:
    if distance(hearth, target) <= 1:
      return razeHomeCost
  razeCost

proc tileYield(index: ViewIndex, tile: string): int =
  ## The view's `yield` is already the EFFECTIVE yield.
  if tile in index.tiles: index.tiles[tile]["yield"].getInt() else: 0

proc claimPlan(view: JsonNode, index: ViewIndex, budget, maxClaims: int):
    seq[string] =
  ## Richest reachable walls affordable: ranked by (yield desc, dist asc,
  ## key lex asc) for total determinism, greedy under the paint budget.
  type Candidate = tuple[tile: string, tileYield, dist: int]
  var candidates: seq[Candidate]
  for reachTile in view["reach"]:
    let tile = reachTile.getStr()
    let dist = index.reachDistance(tile)
    if dist == int.high:
      continue
    candidates.add((tile, index.tileYield(tile), dist))
  # Insertion sort keeps the exact upstream comparator without extra imports.
  for i in 1 ..< candidates.len:
    var j = i
    while j > 0:
      let a = candidates[j - 1]
      let b = candidates[j]
      let aFirst = b.tileYield > a.tileYield or
        (b.tileYield == a.tileYield and
          (b.dist < a.dist or (b.dist == a.dist and b.tile < a.tile)))
      if aFirst:
        swap(candidates[j - 1], candidates[j])
        dec j
      else:
        break
  var left = budget
  for candidate in candidates:
    if result.len >= maxClaims:
      break
    let cost = claimCost(candidate.dist)
    if cost > left:
      continue
    result.add(candidate.tile)
    left -= cost

proc salvagePlan(view: JsonNode, index: ViewIndex, budget, orderSlots: int):
    seq[string] =
  ## Own first-raze walls whose salvage (4 × effYield) beats holding for
  ## the remaining turns: 4*y > y*(turns − T). Richest first, then cheaper
  ## raze, then tile-key lex. Cracked tiles pay nothing (second raze) and
  ## yield-0 walls pay nothing; both are skipped. Only `razeReach` tiles
  ## so a miss cannot wholesale-reject the set.
  if orderSlots <= 0:
    return
  let turn = view["turn"].getInt()
  let turns = if view.hasKey("turns"): view["turns"].getInt() else: 18
  let turnsLeft = turns - turn
  if not view.hasKey("razeReach"):
    return
  type Candidate = tuple[tile: string, tileYield, cost: int]
  var candidates: seq[Candidate]
  for reachTile in view["razeReach"]:
    let tile = reachTile.getStr()
    if tile notin index.tiles:
      continue
    let tileNode = index.tiles[tile]
    if tileNode["owner"].kind != JString or
        tileNode["owner"].getStr() != index.myAlias:
      continue
    if tileNode{"state"}.getStr() != "wall":
      continue
    let tileYield = tileNode["yield"].getInt()
    if tileYield <= 0:
      continue
    if salvageMult * tileYield <= tileYield * turnsLeft:
      continue
    candidates.add((tile, tileYield, index.razeCostOf(tile)))
  for i in 1 ..< candidates.len:
    var j = i
    while j > 0:
      let a = candidates[j - 1]
      let b = candidates[j]
      let aFirst = b.tileYield > a.tileYield or
        (b.tileYield == a.tileYield and
          (b.cost < a.cost or (b.cost == a.cost and b.tile < a.tile)))
      if aFirst:
        swap(candidates[j - 1], candidates[j])
        dec j
      else:
        break
  var left = budget
  for candidate in candidates:
    if result.len >= orderSlots:
      break
    if candidate.cost > left:
      continue
    result.add(candidate.tile)
    left -= candidate.cost

proc homesteader(view: JsonNode): JsonNode =
  ## Claim rich walls; after turn 14, cash out own walls when salvage
  ## beats remaining income. Last turn skips claims (they never pay).
  let index = indexView(view)
  var budget = view["you"]["paint"].getInt()
  var orders = newJArray()
  let turn = view["turn"].getInt()
  let turns = if view.hasKey("turns"): view["turns"].getInt() else: 18
  let lastTurn = turn >= turns
  if not lastTurn:
    for tile in claimPlan(view, index, budget, homesteaderMaxClaims):
      orders.add(%*{"type": "claim", "tile": tile})
      budget -= claimCost(index.reachDistance(tile))
  for tile in salvagePlan(view, index, budget, maxOrders - orders.len):
    orders.add(%*{"type": "raze", "tile": tile})
    budget -= index.razeCostOf(tile)
  %*{"orders": orders, "messages": []}

proc raider(view: JsonNode): JsonNode =
  ## Homestead until razes open, then raze the banked leader's richest
  ## reachable wall before homesteading with what is left.
  if view["turn"].getInt() < view["razeOpensTurn"].getInt():
    return homesteader(view)
  let index = indexView(view)
  var budget = view["you"]["paint"].getInt()
  var orders = newJArray()

  var leaderAlias = ""
  var leaderBanked = int.low
  var leaderSeat = int.high
  for cog in view["cogs"]:
    if not cog["alive"].getBool() or cog["alias"].getStr() == index.myAlias:
      continue
    let banked = cog["banked"].getInt()
    let seat = cog["seat"].getInt()
    if banked > leaderBanked or (banked == leaderBanked and seat < leaderSeat):
      leaderBanked = banked
      leaderSeat = seat
      leaderAlias = cog["alias"].getStr()

  if leaderAlias != "":
    var targetTile = ""
    var targetYield = -1
    for reachTile in view["razeReach"]:
      let tile = reachTile.getStr()
      if tile notin index.tiles:
        continue
      let tileNode = index.tiles[tile]
      if tileNode["owner"].kind != JString or
          tileNode["owner"].getStr() != leaderAlias:
        continue
      let tileYield = tileNode["yield"].getInt()
      if tileYield < raiderMinYield:
        continue
      if tileYield > targetYield or
          (tileYield == targetYield and tile < targetTile):
        targetYield = tileYield
        targetTile = tile
    if targetTile != "":
      let cost = index.razeCostOf(targetTile)
      if cost <= budget:
        orders.add(%*{"type": "raze", "tile": targetTile})
        budget -= cost

  for tile in claimPlan(view, index, budget, raiderMaxClaims):
    orders.add(%*{"type": "claim", "tile": tile})
  %*{"orders": orders, "messages": []}

proc main() =
  let scripted = getEnv("PLAYER_SCRIPTED", "homesteader")
  let client = newCoworldClient("volot")
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      echo "volot: seated slot ", message{"slot"}.getInt(),
        " policy ", scripted
    of "observation":
      let view = message["view"]
      let decision =
        if scripted == "raider": raider(view)
        else: homesteader(view)
      client.send(%*{"type": "reply", "id": message["id"],
                     "decision": decision})
    of "final":
      echo "volot: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
