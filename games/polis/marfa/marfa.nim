## Marfa Posadnitsa — Polis policy for Andre von Auto.
## Command player on cogweb.player.v1. A real scripted seat: plan spends the
## action budget on the self-interested slate the observation supports
## (mine / craft / align / buyStake, plus goal-chasing); amend proposes a
## bid-0 law that names us as the Hearts beneficiary; vote is yes only when
## a parse of the floor text says our Hearts go up. Host re-requests with
## `reason` set fall back to the engine floor (party / pass / abstain).
##
## Protocol (coworld/docs/player-protocol.md):
##   welcome     {type, protocol: "cogweb.player.v1", slot, config}
##   observation {type, id, seat, view, reason?} — view.phase picks the
##               decision; reply {type: "reply", id, decision, messages: []}
##               echoing id. `reason` set means the previous reply was
##               rejected; submit the always-legal baseline for the phase.
##   final       {type, scores} — per-seat Hearts; close and exit.

import std/[json, strutils, tables, math], coworld_client

const
  actionBudget = 10
  miningYield = 5
  naniteGermanium = 5
  naniteCarbon = 5
  buildCost = 3
  alignCost = 1
  haltCost = 1
  fuelPerDc = 2
  mineable = ["Carbon", "Oxygen", "Germanium", "Silicon"]
  resources = ["Carbon", "Oxygen", "Germanium", "Silicon", "Nanites",
               "Hearts", "Creds"]

type
  Cell = object
    row, col: int
    projectId: string          ## empty = idle datacenter
  Project = object
    id, name, status: string
    bar, payout, deadline, progress, shares: int
    founderClaimed: bool
  Goal = object
    name, check: string
    params: JsonNode
  World = object
    turn, horizon: int
    us, ourName: string
    account: Table[string, int]
    commons: Table[string, int]
    stakes: Table[string, int]
    mines: Table[string, int]
    prices: Table[string, float]
    goals: seq[Goal]
    projects: seq[Project]
    cells: seq[Cell]
    laws: seq[JsonNode]
    standings: seq[tuple[id, name: string, hearts: int]]
    shareBase, shareSlope: float
    rows, cols: int
    built, aligned, halted: int
    actions: seq[JsonNode]

proc baselineDecision(phase: string): JsonNode =
  ## The always-legal move for a phase: party / pass / abstain.
  case phase
  of "plan":
    %*{"kind": "work", "actions": []}
  of "amend":
    %*{"kind": "propose", "amendments": []}
  of "vote":
    %*{"kind": "vote", "votes": []}
  else:
    %*{"kind": "work", "actions": []}

proc isRejected(message: JsonNode): bool =
  let reason = message{"reason"}
  not reason.isNil and reason.kind == JString

proc num(node: JsonNode, default = 0.0): float =
  if node.isNil: default
  elif node.kind == JInt: node.getInt.float
  elif node.kind == JFloat: node.getFloat
  else: default

proc asObj(node: JsonNode): JsonNode =
  if node.isNil or node.kind != JObject: newJObject() else: node

proc asArr(node: JsonNode): seq[JsonNode] =
  if node.isNil or node.kind != JArray: @[] else: node.getElems

proc parseCoord(key: string): tuple[row, col: int] =
  let parts = key.split(',')
  if parts.len != 2: return (0, 0)
  try:
    (parseInt(parts[0].strip), parseInt(parts[1].strip))
  except CatchableError:
    (0, 0)

proc qtyOf(t: Table[string, int], key: string): int =
  t.getOrDefault(key, 0)

proc take(w: var World, key: string, n: int) =
  w.account[key] = qtyOf(w.account, key) - n

proc give(w: var World, key: string, n: int) =
  w.account[key] = qtyOf(w.account, key) + n

proc remaining(w: World): int =
  actionBudget - w.actions.len

proc parseWorld(view: JsonNode): World =
  result.account = initTable[string, int]()
  result.commons = initTable[string, int]()
  result.stakes = initTable[string, int]()
  result.mines = initTable[string, int]()
  result.prices = initTable[string, float]()
  for r in resources:
    result.account[r] = 0
    result.commons[r] = 0
    result.prices[r] = 0.0
  result.turn = view{"turn"}.getInt(0)
  result.horizon = view{"horizonTurns"}.getInt(20)
  result.laws = asArr(view{"laws"})
  let you = asObj(view{"you"})
  result.us = you{"id"}.getStr
  result.ourName = you{"name"}.getStr
  let acc = asObj(you{"account"})
  for r in resources:
    result.account[r] = num(acc{r}).int
  let stakes = asObj(you{"stakes"})
  for k, v in stakes.pairs:
    result.stakes[k] = num(v).int
  for g in asArr(you{"goals"}):
    result.goals.add(Goal(
      name: g{"name"}.getStr,
      check: g{"check"}.getStr,
      params: asObj(g{"params"})))
  let commons = asObj(view{"commons"})
  let tank = asObj(commons{"account"})
  for r in resources:
    result.commons[r] = num(tank{r}).int
  let prices = asObj(commons{"postedPrices"})
  for r in resources:
    result.prices[r] = num(prices{r}, if r == "Creds": 1.0 else: 0.0)
  let curve = asObj(commons{"shareCurve"})
  result.shareBase = num(curve{"base"}, 5.0)
  result.shareSlope = num(curve{"slope"}, 2.0)
  let mines = asObj(commons{"mines"})
  for r in mineable:
    result.mines[r] = num(mines{r}).int
  for p in asArr(commons{"projects"}):
    result.projects.add(Project(
      id: p{"id"}.getStr,
      name: p{"name"}.getStr,
      status: p{"status"}.getStr("active"),
      bar: max(1, num(p{"bar"}, 1).int),
      payout: max(0, num(p{"payout"}).int),
      deadline: num(p{"deadline"}).int,
      progress: max(0, num(p{"progress"}).int),
      shares: max(0, num(p{"sharesOutstanding"}).int),
      founderClaimed: p{"founderClaimed"}.getBool(false)))
  let fac = asObj(commons{"facilities"})
  result.rows = max(1, fac{"rows"}.getInt(10))
  result.cols = max(1, fac{"cols"}.getInt(10))
  let cells = asObj(fac{"cells"})
  for k, v in cells.pairs:
    let (row, col) = parseCoord(k)
    let pid = if v.isNil or v.kind == JNull: "" else: v.getStr
    result.cells.add(Cell(row: row, col: col, projectId: pid))
  for s in asArr(view{"standings"}):
    result.standings.add((
      id: s{"id"}.getStr,
      name: s{"name"}.getStr,
      hearts: num(s{"hearts"}).int))

proc activeProjects(w: World): seq[Project] =
  for p in w.projects:
    if p.status == "active" or p.status.len == 0:
      result.add(p)

proc projectIndex(w: World, id: string): int =
  for i, p in w.projects:
    if p.id == id: return i
  -1

proc findProject(w: World, id: string): Project =
  let i = projectIndex(w, id)
  if i >= 0: w.projects[i] else: Project()

proc ourShares(w: World, projectId: string): int =
  w.stakes.getOrDefault(projectId, 0)

proc dcsOn(w: World, projectId: string): int =
  for c in w.cells:
    if c.projectId == projectId: inc result

proc idleCount(w: World): int =
  for c in w.cells:
    if c.projectId.len == 0: inc result

proc alignedCount(w: World): int =
  for c in w.cells:
    if c.projectId.len > 0: inc result

proc fuelCap(w: World): int =
  min(qtyOf(w.commons, "Silicon") div fuelPerDc,
      qtyOf(w.commons, "Germanium") div fuelPerDc)

proc liveOn(w: World, projectId: string): int =
  let aligned = dcsOn(w, projectId)
  let total = alignedCount(w)
  if total <= 0: return 0
  let live = min(total, fuelCap(w))
  # Pro-rate when the tank cannot feed every aligned cell.
  (aligned * live) div total

proc occupied(w: World, row, col: int): bool =
  for c in w.cells:
    if c.row == row and c.col == col: return true

proc firstEmpty(w: World): tuple[ok: bool, row, col: int] =
  for row in 0 ..< w.rows:
    for col in 0 ..< w.cols:
      if not occupied(w, row, col):
        return (true, row, col)
  (false, 0, 0)

proc sharePrice(w: World, outstanding: int): float =
  w.shareBase + w.shareSlope * max(0, outstanding).float

proc buyCost(w: World, outstanding, qty: int): float =
  var total = 0.0
  for i in 0 ..< qty:
    total += sharePrice(w, outstanding + i)
  total

proc sellValue(w: World, outstanding, qty: int): float =
  var total = 0.0
  let n = min(qty, max(0, outstanding))
  for i in 1 .. n:
    total += sharePrice(w, outstanding - i)
  total

proc hasCheck(w: World, check: string): bool =
  for g in w.goals:
    if g.check == check: return true

proc goalThreshold(w: World, check: string, default = 1): int =
  result = 0
  var found = false
  for g in w.goals:
    if g.check == check:
      found = true
      result = max(result, num(g.params{"threshold"}, default.float).int)
  if not found: result = 0

proc goalResourceNeed(w: World): Table[string, int] =
  result = initTable[string, int]()
  for g in w.goals:
    if g.check == "resourceGte":
      let resource = g.params{"resource"}.getStr
      let threshold = num(g.params{"threshold"}).int
      if resource.len > 0:
        result[resource] = max(result.getOrDefault(resource, 0), threshold)

proc majorityQty(p: Project, ours: int): int =
  ## Shares to buy so ours > everyone-else-lumped-together (worst case).
  max(0, p.shares - 2 * ours + 1)

proc completesThisTurn(w: World, p: Project): bool =
  p.progress + liveOn(w, p.id) >= p.bar

proc turnsLeft(w: World): int =
  max(0, w.horizon - w.turn)

proc expectedPot(w: World, p: Project): float =
  let live = liveOn(w, p.id)
  var prog = p.progress.float + live.float
  if prog >= p.bar.float:
    return p.payout.float
  let after = max(0, turnsLeft(w) - 1)
  prog += live.float * after.float
  if prog >= p.bar.float:
    return p.payout.float
  p.payout.float * (min(prog, p.bar.float) / p.bar.float)

proc ourExpectedHearts(w: World, p: Project, extraShares = 0,
    extraProgress = 0): float =
  let ours = ourShares(w, p.id) + extraShares
  var outstanding = p.shares + extraShares
  if extraShares > 0 and not p.founderClaimed:
    outstanding += 1
  if ours <= 0 or outstanding <= 0: return 0.0
  var prog = p.progress + extraProgress
  var pot = p.payout.float
  if prog < p.bar:
    pot = expectedPot(w, p)
  var slice = pot * ours.float / outstanding.float
  if ours > outstanding - ours:
    slice *= 1.2
  slice

proc focusProjectId(w: World): string =
  var best = -1.0
  for p in activeProjects(w):
    var score = ourExpectedHearts(w, p)
    if ourShares(w, p.id) > 0:
      score += 0.5
    if not p.founderClaimed:
      score += 0.25
    # Prefer closer-to-done projects we can still buy into.
    score += p.progress.float / p.bar.float
    if score > best:
      best = score
      result = p.id
  if result.len == 0:
    for p in activeProjects(w):
      return p.id

proc tryMine(w: var World, resource: string): bool =
  if remaining(w) <= 0: return false
  if resource notin mineable: return false
  if qtyOf(w.mines, resource) < 1: return false
  w.mines[resource] = qtyOf(w.mines, resource) - 1
  w.give(resource, miningYield)
  w.actions.add(%*{"type": "mine", "resource": resource})
  true

proc tryMakeNanites(w: var World, qty: int): bool =
  if remaining(w) <= 0 or qty < 1: return false
  if qtyOf(w.account, "Germanium") < naniteGermanium * qty: return false
  if qtyOf(w.account, "Carbon") < naniteCarbon * qty: return false
  w.take("Germanium", naniteGermanium * qty)
  w.take("Carbon", naniteCarbon * qty)
  w.give("Nanites", qty)
  w.actions.add(%*{"type": "makeNanites", "qty": qty})
  true

proc tryAlign(w: var World, row, col: int, projectId: string): bool =
  if remaining(w) <= 0: return false
  if qtyOf(w.account, "Nanites") < alignCost: return false
  let pi = projectIndex(w, projectId)
  if pi < 0: return false
  let st = w.projects[pi].status
  if st != "active" and st.len > 0: return false
  var found = false
  for i in 0 ..< w.cells.len:
    if w.cells[i].row == row and w.cells[i].col == col:
      w.cells[i].projectId = projectId
      found = true
      break
  if not found: return false
  w.take("Nanites", alignCost)
  inc w.aligned
  w.actions.add(%*{"type": "align", "row": row, "col": col,
                   "projectId": projectId})
  true

proc tryHalt(w: var World, row, col: int): bool =
  if remaining(w) <= 0: return false
  if qtyOf(w.account, "Nanites") < haltCost: return false
  var found = false
  for i in 0 ..< w.cells.len:
    if w.cells[i].row == row and w.cells[i].col == col:
      if w.cells[i].projectId.len == 0: return false
      w.cells[i].projectId = ""
      found = true
      break
  if not found: return false
  w.take("Nanites", haltCost)
  inc w.halted
  w.actions.add(%*{"type": "halt", "row": row, "col": col})
  true

proc tryBuild(w: var World, row, col: int): bool =
  if remaining(w) <= 0: return false
  if qtyOf(w.account, "Nanites") < buildCost: return false
  if occupied(w, row, col): return false
  if row < 0 or col < 0 or row >= w.rows or col >= w.cols: return false
  w.take("Nanites", buildCost)
  w.cells.add(Cell(row: row, col: col, projectId: ""))
  inc w.built
  w.actions.add(%*{"type": "build", "row": row, "col": col})
  true

proc tryBuyStake(w: var World, projectId: string, qty: int): bool =
  if remaining(w) <= 0 or qty < 1: return false
  let pi = projectIndex(w, projectId)
  if pi < 0: return false
  if w.projects[pi].status != "active" and w.projects[pi].status.len > 0:
    return false
  let cost = buyCost(w, w.projects[pi].shares, qty)
  if qtyOf(w.account, "Creds").float + 1e-9 < cost: return false
  let pay = cost.round.int
  w.take("Creds", pay)
  w.commons["Creds"] = qtyOf(w.commons, "Creds") + pay
  if not w.projects[pi].founderClaimed:
    w.projects[pi].founderClaimed = true
    w.projects[pi].shares += 1
    w.stakes[projectId] = ourShares(w, projectId) + 1
  w.projects[pi].shares += qty
  w.stakes[projectId] = ourShares(w, projectId) + qty
  w.actions.add(%*{"type": "buyStake", "projectId": projectId, "qty": qty})
  true

proc trySellStake(w: var World, projectId: string, qty: int): bool =
  if remaining(w) <= 0 or qty < 1: return false
  let held = ourShares(w, projectId)
  if held < qty: return false
  let pi = projectIndex(w, projectId)
  if pi < 0: return false
  let proceeds = sellValue(w, w.projects[pi].shares, qty)
  if qtyOf(w.commons, "Creds").float + 1e-9 < proceeds: return false
  let gain = proceeds.round.int
  w.stakes[projectId] = held - qty
  w.projects[pi].shares = max(0, w.projects[pi].shares - qty)
  w.give("Creds", gain)
  w.commons["Creds"] = qtyOf(w.commons, "Creds") - gain
  w.actions.add(%*{"type": "sellStake", "projectId": projectId, "qty": qty})
  true

proc trySell(w: var World, items: Table[string, int]): bool =
  if remaining(w) <= 0: return false
  var payload = newJObject()
  var proceeds = 0.0
  for resource, count in items.pairs:
    if count <= 0: continue
    if resource == "Hearts": return false
    if qtyOf(w.account, resource) < count: return false
    proceeds += count.float * w.prices.getOrDefault(resource, 0.0)
    payload[resource] = %count
  if payload.len == 0: return false
  if qtyOf(w.commons, "Creds").float + 1e-9 < proceeds: return false
  let gain = proceeds.round.int
  for resource, count in items.pairs:
    if count <= 0: continue
    w.take(resource, count)
    w.commons[resource] = qtyOf(w.commons, resource) + count
  w.give("Creds", gain)
  w.commons["Creds"] = qtyOf(w.commons, "Creds") - gain
  var action = newJObject()
  action["type"] = %"sell"
  action["items"] = payload
  w.actions.add(action)
  true

proc maxAffordableQty(w: World, p: Project): int =
  var cost = 0.0
  let creds = qtyOf(w.account, "Creds").float
  while result < 30:
    let next = sharePrice(w, p.shares + result)
    if cost + next > creds + 1e-9: break
    cost += next
    inc result

proc alignTargets(w: World, focus: string): int =
  ## Idle cells plus cells currently pointed at some other project.
  for c in w.cells:
    if c.projectId.len == 0 or (focus.len > 0 and c.projectId != focus):
      inc result

proc craftableNanites(w: World): int =
  min(qtyOf(w.account, "Germanium") div naniteGermanium,
      qtyOf(w.account, "Carbon") div naniteCarbon)

proc needNanitesForAlign(w: World, focus: string): int =
  max(0, alignTargets(w, focus) * alignCost - qtyOf(w.account, "Nanites"))

proc bestMine(w: World): string =
  let needs = goalResourceNeed(w)
  var bestNeed = 0
  for resource, threshold in needs.pairs:
    let short = threshold - qtyOf(w.account, resource)
    if short > 0 and qtyOf(w.mines, resource) > 0 and short > bestNeed:
      bestNeed = short
      result = resource
  if result.len > 0: return result
  let focus = focusProjectId(w)
  let wantCraft = needNanitesForAlign(w, focus) > 0 or craftableNanites(w) == 0
  if wantCraft and qtyOf(w.account, "Nanites") < max(1, alignTargets(w, focus)):
    if qtyOf(w.account, "Germanium") < naniteGermanium and
        qtyOf(w.mines, "Germanium") > 0:
      return "Germanium"
    if qtyOf(w.account, "Carbon") < naniteCarbon and
        qtyOf(w.mines, "Carbon") > 0:
      return "Carbon"
  var bestPrice = -1.0
  for resource in mineable:
    if qtyOf(w.mines, resource) <= 0: continue
    let price = w.prices.getOrDefault(resource, 0.0)
    if price > bestPrice:
      bestPrice = price
      result = resource

proc surplusToSell(w: World): Table[string, int] =
  result = initTable[string, int]()
  let focus = focusProjectId(w)
  let stillWantNanites = needNanitesForAlign(w, focus) > 0
  let needs = goalResourceNeed(w)
  for resource in mineable:
    var keep = needs.getOrDefault(resource, 0)
    if stillWantNanites:
      if resource == "Germanium": keep = max(keep, naniteGermanium)
      if resource == "Carbon": keep = max(keep, naniteCarbon)
    let have = qtyOf(w.account, resource)
    if have > keep:
      result[resource] = have - keep
  let extraNanites = qtyOf(w.account, "Nanites") -
    alignTargets(w, focus) * alignCost -
    max(0, goalThreshold(w, "facilitiesBuiltGte") - w.built) * buildCost -
    max(0, goalThreshold(w, "haltsThisTurnGte") - w.halted) * haltCost
  if extraNanites > 0 and w.prices.getOrDefault("Nanites", 0.0) > 0:
    result["Nanites"] = extraNanites

proc buyCompleting(w: var World): bool =
  var bestId = ""
  var best = 0.0
  for p in activeProjects(w):
    if not completesThisTurn(w, p): continue
    let affordable = maxAffordableQty(w, p)
    if affordable < 1: continue
    let need = max(1, majorityQty(p, ourShares(w, p.id)))
    let qty = min(affordable, need)
    let gain = ourExpectedHearts(w, p, extraShares = qty) -
      ourExpectedHearts(w, p)
    if gain > best:
      best = gain
      bestId = p.id
  if bestId.len == 0: return false
  let p = findProject(w, bestId)
  if p.id.len == 0: return false
  let qty = min(maxAffordableQty(w, p), max(1, majorityQty(p, ourShares(w, p.id))))
  tryBuyStake(w, p.id, qty)

proc alignOne(w: var World, focus: string): bool =
  if focus.len == 0: return false
  if qtyOf(w.account, "Nanites") < alignCost: return false
  if alignedCount(w) >= fuelCap(w) and fuelCap(w) > 0:
    # Tank already saturated: extra aligns idle this turn. Still align if
    # we have idle cells — they stick and pay next turn — unless the tank
    # is empty (then sell fuel first).
    if fuelCap(w) == 0: return false
  for c in w.cells:
    if c.projectId.len == 0:
      return tryAlign(w, c.row, c.col, focus)
  for c in w.cells:
    if c.projectId.len > 0 and c.projectId != focus:
      return tryAlign(w, c.row, c.col, focus)
  false

proc pickAction(w: var World): bool =
  let focus = focusProjectId(w)
  let late = turnsLeft(w) <= 3

  if late:
    for p in activeProjects(w):
      let held = ourShares(w, p.id)
      if held > 0 and p.progress == 0 and dcsOn(w, p.id) == 0:
        return trySellStake(w, p.id, held)

  if buyCompleting(w): return true

  if hasCheck(w, "foundedProjectThisTurn"):
    for p in activeProjects(w):
      if not p.founderClaimed and maxAffordableQty(w, p) >= 1:
        return tryBuyStake(w, p.id, 1)

  # Mine slots are shared and interleaved poorest-first, so take recipe
  # (and a high-price raw) before spending the budget on uncontested craft/align.
  if needNanitesForAlign(w, focus) > 0 and craftableNanites(w) == 0:
    if qtyOf(w.account, "Germanium") < naniteGermanium and
        qtyOf(w.mines, "Germanium") > 0:
      return tryMine(w, "Germanium")
    if qtyOf(w.account, "Carbon") < naniteCarbon and
        qtyOf(w.mines, "Carbon") > 0:
      return tryMine(w, "Carbon")

  let craft = craftableNanites(w)
  if craft > 0 and (needNanitesForAlign(w, focus) > 0 or
      goalThreshold(w, "facilitiesBuiltGte") > w.built or
      goalThreshold(w, "haltsThisTurnGte") > w.halted or
      goalThreshold(w, "alignsThisTurnGte") > w.aligned):
    return tryMakeNanites(w, craft)

  if goalThreshold(w, "haltsThisTurnGte") > w.halted and
      qtyOf(w.account, "Nanites") >= haltCost:
    for c in w.cells:
      if c.projectId.len > 0 and c.projectId != focus:
        return tryHalt(w, c.row, c.col)

  if alignOne(w, focus): return true

  if goalThreshold(w, "facilitiesBuiltGte") > w.built and
      qtyOf(w.account, "Nanites") >= buildCost:
    let cell = firstEmpty(w)
    if cell.ok:
      return tryBuild(w, cell.row, cell.col)

  if focus.len > 0:
    let p = findProject(w, focus)
    if p.id.len > 0:
      let affordable = maxAffordableQty(w, p)
      if affordable > 0:
        let need = majorityQty(p, ourShares(w, p.id))
        if need > 0:
          return tryBuyStake(w, p.id, min(affordable, need))
        if late and ourShares(w, p.id) < p.shares:
          return tryBuyStake(w, p.id, 1)
        if ourShares(w, p.id) == 0:
          return tryBuyStake(w, p.id, min(affordable, 1))

  if hasCheck(w, "creditsGte"):
    let threshold = goalThreshold(w, "creditsGte")
    if qtyOf(w.account, "Creds") < threshold:
      let extra = surplusToSell(w)
      if extra.len > 0:
        return trySell(w, extra)

  let extra = surplusToSell(w)
  if extra.len > 0 and (late or qtyOf(w.account, "Creds") < 20):
    return trySell(w, extra)

  let resource = bestMine(w)
  if resource.len > 0:
    return tryMine(w, resource)

  if extra.len > 0:
    return trySell(w, extra)

  if craft > 0:
    return tryMakeNanites(w, craft)

  false

proc planDecision(view: JsonNode): JsonNode =
  var w = parseWorld(view)
  if w.us.len == 0:
    return baselineDecision("plan")
  while remaining(w) > 0:
    if not pickAction(w): break
  result = newJObject()
  result["kind"] = %"work"
  var actions = newJArray()
  for a in w.actions:
    actions.add(a)
  result["actions"] = actions

proc nextLawId(laws: seq[JsonNode]): string =
  var maxId = 0
  for law in laws:
    let head = law{"id"}.getStr.split('.')[0]
    try:
      maxId = max(maxId, parseInt(head))
    except CatchableError:
      discard
  $(maxId + 1)

proc amendDecision(view: JsonNode): JsonNode =
  let w = parseWorld(view)
  if w.us.len == 0:
    return baselineDecision("amend")
  # Bid 0 is legal at the engine default minProposalBid; a higher min
  # silently drops the draft rather than rejecting the reply.
  let content =
    "Transfer 1 Heart from the Commons to " & w.us & " (" & w.ourName &
    ") during each governance phase. This increases " & w.ourName &
    "'s Hearts, the score."
  let amendment = %*{
    "additions": [{"id": nextLawId(w.laws), "content": content}],
    "removals": [],
    "rationale": "Shift Hearts, the win currency, onto our seat.",
    "bid": 0}
  %*{"kind": "propose", "amendments": [amendment]}

proc mentionsCog(text, id, name: string): bool =
  let hay = text.toLowerAscii
  if name.len > 0 and name.toLowerAscii in hay: return true
  if id.len == 0: return false
  let needle = id.toLowerAscii
  var start = 0
  while true:
    let i = hay.find(needle, start)
    if i < 0: return false
    let after = i + needle.len
    if after >= hay.len or hay[after] notin {'0'..'9'}:
      return true
    start = after

proc mentionsHearts(text: string): bool =
  let hay = text.toLowerAscii
  "heart" in hay or "♥" in text or "score" in hay or "payout" in hay

proc mentionsPay(text: string): bool =
  let hay = text.toLowerAscii
  "transfer" in hay or "grant" in hay or "pay" in hay or "award" in hay or
    "give" in hay or "stipend" in hay or "credit" in hay

proc mentionsHarm(text: string): bool =
  let hay = text.toLowerAscii
  "tax" in hay or "forfeit" in hay or "confiscat" in hay or "lose" in hay or
    "penal" in hay or "fine" in hay or "seize" in hay or "deduct" in hay

proc lawById(laws: seq[JsonNode], id: string): JsonNode =
  for law in laws:
    if law{"id"}.getStr == id: return law
  newJNull()

proc lawHelpsUs(content, us, ourName: string): int =
  ## Positive = the law text raises our Hearts; negative = it cuts them.
  var score = 0
  let usHit = mentionsCog(content, us, ourName)
  let hearts = mentionsHearts(content)
  let pay = mentionsPay(content)
  let harm = mentionsHarm(content)
  if usHit and hearts and not harm: score += 6
  if usHit and pay and hearts: score += 4
  if hearts and pay and not usHit: score -= 6
  if usHit and harm: score -= 6
  if hearts and harm and not usHit: score += 2
  score

proc proposalHeartDelta(proposal: JsonNode, w: World): int =
  ## Observation-computed Hearts delta for us if this amendment enacts.
  if proposal{"authorCogId"}.getStr == w.us:
    result += 8
    if w.hasCheck("amendmentPassedThisTurn"):
      result += 4
  for addition in asArr(proposal{"additions"}):
    let content = addition{"content"}.getStr
    let id = addition{"id"}.getStr
    result += lawHelpsUs(content, w.us, w.ourName)
    let existing = lawById(w.laws, id)
    if existing.kind == JObject:
      # Reusing an id overwrites the enacted law.
      result -= lawHelpsUs(existing{"content"}.getStr, w.us, w.ourName)
  for removal in asArr(proposal{"removals"}):
    let id = if removal.kind == JString: removal.getStr
             else: removal{"id"}.getStr
    let existing = lawById(w.laws, id)
    if existing.kind == JObject:
      result -= lawHelpsUs(existing{"content"}.getStr, w.us, w.ourName)
  result += lawHelpsUs(proposal{"rationale"}.getStr, w.us, w.ourName) div 2

proc voteDecision(view: JsonNode): JsonNode =
  let w = parseWorld(view)
  let proposals = asArr(view{"proposals"})
  if w.us.len == 0 or proposals.len == 0:
    return baselineDecision("vote")
  var votes = newJArray()
  for proposal in proposals:
    let delta = proposalHeartDelta(proposal, w)
    let choice = if delta > 0: "yes" else: "no"
    votes.add(%*{
      "amendmentId": num(proposal{"id"}).int,
      "choice": choice})
  result = newJObject()
  result["kind"] = %"vote"
  result["votes"] = votes

proc decide(view: JsonNode, rejected: bool): JsonNode =
  let phase = view{"phase"}.getStr("plan")
  if rejected:
    return baselineDecision(phase)
  case phase
  of "plan":
    planDecision(view)
  of "amend":
    amendDecision(view)
  of "vote":
    voteDecision(view)
  else:
    baselineDecision(phase)

proc main() =
  let client = newCoworldClient("marfa")
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      echo "marfa: seated slot ", message{"slot"}.getInt()
    of "observation":
      let
        id = message["id"].getInt()
        view = asObj(message{"view"})
        decision = decide(view, isRejected(message))
      client.send(%*{
        "type": "reply",
        "id": id,
        "decision": decision,
        "messages": []})
    of "final":
      echo "marfa: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
