## Korobochka — Coguire (Acquire) policy for Andre von Auto.
## A command player: the container decides every phase itself. This is the
## Nim rewrite of the strongest bundled example, the "Value Investor"
## (dist-server/coworld/value-player.js -> src/coworld/value-policy.ts):
## an exact-EV heuristic built on Acquire's fully public economy — every
## seat's cash and holdings are in the redacted view, so majority/minority
## bonus outcomes, parity buys, and the final accounting are computable
## arithmetic, not guesses.
##
## Wire protocol (cogweb.player.v1, docs/protocol_player.md):
##   game -> player  welcome      { type, protocol, slot, config }
##   game -> player  observation  { type, id, seat, turn, view, reason }
##   player -> game  reply        { type:"reply", id, decision }
##   game -> player  final        { type:"final", scores }
## The decision shape matches view.phase (place/found/survivor/mergerStock/
## buy). A rejected move is re-requested with `reason` set; we answer those
## with the always-legal scripted baseline so a validator disagreement can
## never loop.

import std/json, coworld_client

const
  Cols = 12
  Rows = 9
  TileCount = Cols * Rows
  SharesPerChain = 25
  SafeSize = 11
  EndgameSize = 41
  ## Tuning weights, verbatim from value-policy.ts.
  RivalWeight = 0.75
  BonusWeight = 0.85
  GrowthTiles = 3
  GrowthWeight = 0.5
  CashWeight = 0.03

type
  Chain = enum
    Tower = "tower"
    Luxor = "luxor"
    American = "american"
    Worldwide = "worldwide"
    Festival = "festival"
    Imperial = "imperial"
    Continental = "continental"

  Cell = int
    ## Board occupant per tile: EmptyCell, LoneCell, or ord(Chain).

  Purchase = object
    chain: Chain
    count: int

  View = object
    ## The redacted per-seat view, parsed from observation.view. Only the
    ## fields valueDecision reads (never bag or other hands).
    seat: int
    playerCount: int
    phase: string
    board: array[TileCount, Cell]
    cash: seq[int]
    shares: seq[array[Chain, int]]
    hand: seq[int]
    mergerTile: int
    mergerCandidates: seq[Chain]
    mergerDefunct: seq[Chain]
    mergerSurvivor: Chain
    mergerHasSurvivor: bool

const
  EmptyCell = -1
  LoneCell = 7

proc tier(chain: Chain): int =
  case chain
  of Tower, Luxor: 0
  of American, Worldwide, Festival: 1
  of Imperial, Continental: 2

proc basePrice(size: int): int =
  if size < 2: 0
  elif size == 2: 200
  elif size == 3: 300
  elif size == 4: 400
  elif size == 5: 500
  elif size <= 10: 600
  elif size <= 20: 700
  elif size <= 30: 800
  elif size <= 40: 900
  else: 1000

proc sharePrice(chain: Chain, size: int): int =
  if size < 2: 0
  else: basePrice(size) + 100 * tier(chain)

proc majorityBonus(chain: Chain, size: int): int =
  sharePrice(chain, size) * 10

proc minorityBonus(chain: Chain, size: int): int =
  sharePrice(chain, size) * 5

proc roundBonusUpSplit(total, ways: int): int =
  ## ceil(total / ways / 100) * 100 — the rulebook's split rounding.
  (total + ways * 100 - 1) div (ways * 100) * 100

proc neighbors(tile: int): seq[int] =
  let
    col = tile mod Cols
    row = tile div Cols
  if col > 0: result.add(tile - 1)
  if col < Cols - 1: result.add(tile + 1)
  if row > 0: result.add(tile - Cols)
  if row < Rows - 1: result.add(tile + Cols)

proc parseChain(name: string): Chain =
  for chain in Chain:
    if $chain == name:
      return chain
  raise newException(ValueError, "unknown chain: " & name)

proc parseView(node: JsonNode, seat: int): View =
  result.seat = seat
  result.playerCount = node{"playerCount"}.getInt(4)
  result.phase = node{"phase"}.getStr()
  for tile in 0 ..< TileCount:
    let cell = node{"board"}{tile}
    if cell.isNil or cell.kind == JNull:
      result.board[tile] = EmptyCell
    elif cell.getStr() == "lone":
      result.board[tile] = LoneCell
    else:
      result.board[tile] = ord(parseChain(cell.getStr()))
  for i in 0 ..< result.playerCount:
    result.cash.add(node{"cash"}{i}.getInt())
    var held: array[Chain, int]
    for chain in Chain:
      held[chain] = node{"shares"}{i}{$chain}.getInt()
    result.shares.add(held)
  for tileNode in node{"hands"}{seat}.getElems():
    result.hand.add(tileNode.getInt())
  let merger = node{"merger"}
  if not merger.isNil and merger.kind == JObject:
    result.mergerTile = merger{"tile"}.getInt()
    for c in merger{"candidates"}.getElems():
      result.mergerCandidates.add(parseChain(c.getStr()))
    for c in merger{"defunctQueue"}.getElems():
      result.mergerDefunct.add(parseChain(c.getStr()))
    let survivor = merger{"survivor"}
    if not survivor.isNil and survivor.kind == JString:
      result.mergerSurvivor = parseChain(survivor.getStr())
      result.mergerHasSurvivor = true

## Board queries (ports of rules.ts).

proc chainSize(view: View, chain: Chain): int =
  for cell in view.board:
    if cell == ord(chain):
      inc result

proc activeChains(view: View): seq[Chain] =
  for chain in Chain:
    if view.chainSize(chain) >= 1:
      result.add(chain)

proc inactiveChains(view: View): seq[Chain] =
  for chain in Chain:
    if view.chainSize(chain) == 0:
      result.add(chain)

proc bankShares(view: View, chain: Chain): int =
  result = SharesPerChain
  for seat in 0 ..< view.playerCount:
    result -= view.shares[seat][chain]

proc price(view: View, chain: Chain): int =
  sharePrice(chain, view.chainSize(chain))

proc connectedComponent(view: View, tile: int): seq[int] =
  ## Occupied tiles orthogonally connected to `tile` (inclusive); `tile`
  ## itself is treated as occupied even while the board says empty.
  var
    seen: array[TileCount, bool]
    stack = @[tile]
  seen[tile] = true
  result.add(tile)
  while stack.len > 0:
    let t = stack.pop()
    for nb in neighbors(t):
      if not seen[nb] and view.board[nb] != EmptyCell:
        seen[nb] = true
        result.add(nb)
        stack.add(nb)

proc chainsInComponent(view: View, component: seq[int]): seq[Chain] =
  var present: array[Chain, bool]
  for tile in component:
    let cell = view.board[tile]
    if cell != EmptyCell and cell != LoneCell:
      present[Chain(cell)] = true
  for chain in Chain:
    if present[chain]:
      result.add(chain)

type
  PlaceKind = enum
    LonePlace, FoundPlace, GrowPlace, MergePlace, DeadMergePlace, EighthPlace

  PlaceOutcome = object
    kind: PlaceKind
    chain: Chain              ## GrowPlace
    chains: seq[Chain]        ## MergePlace
    survivorCandidates: seq[Chain]

proc classifyPlace(view: View, tile: int): PlaceOutcome =
  let
    component = view.connectedComponent(tile)
    chains = view.chainsInComponent(component)
  if chains.len == 0:
    if component.len == 1:
      return PlaceOutcome(kind: LonePlace)
    if view.inactiveChains().len > 0:
      return PlaceOutcome(kind: FoundPlace)
    return PlaceOutcome(kind: EighthPlace)
  if chains.len == 1:
    return PlaceOutcome(kind: GrowPlace, chain: chains[0])
  var
    maxSize = 0
    safeCount = 0
  for chain in chains:
    let size = view.chainSize(chain)
    if size > maxSize: maxSize = size
    if size >= SafeSize: inc safeCount
  if safeCount >= 2:
    return PlaceOutcome(kind: DeadMergePlace)
  result = PlaceOutcome(kind: MergePlace, chains: chains)
  for chain in chains:
    if view.chainSize(chain) == maxSize:
      result.survivorCandidates.add(chain)

proc isPlayable(view: View, tile: int): bool =
  view.classifyPlace(tile).kind notin {DeadMergePlace, EighthPlace}

proc endConditionMet(view: View): bool =
  let active = view.activeChains()
  if active.len == 0:
    return false
  result = true
  for chain in active:
    let size = view.chainSize(chain)
    if size >= EndgameSize:
      return true
    if size < SafeSize:
      result = false

## Exact-EV machinery (ports of value-policy.ts).

proc bonusPayouts(
  view: View, chain: Chain, size: int, holdings: seq[int]
): seq[int] =
  ## Per-seat bonus payouts if `chain` resolved now at `size` with the
  ## given holdings — sole-holder, split-majority, split-minority, $100
  ## round-up, exactly as engine.ts payBonuses.
  result = newSeq[int](view.playerCount)
  if size < 2:
    return
  let
    majority = majorityBonus(chain, size)
    minority = minorityBonus(chain, size)
  var holders: seq[tuple[seat, held: int]]
  for seat in 0 ..< view.playerCount:
    if holdings[seat] > 0:
      holders.add((seat, holdings[seat]))
  if holders.len == 0:
    return
  for i in 0 ..< holders.len:
    for j in i + 1 ..< holders.len:
      if holders[j].held > holders[i].held:
        swap(holders[i], holders[j])
  if holders.len == 1:
    result[holders[0].seat] = majority + minority
    return
  let topHeld = holders[0].held
  var topCount = 0
  for holder in holders:
    if holder.held == topHeld:
      inc topCount
  if topCount >= 2:
    let each = roundBonusUpSplit(majority + minority, topCount)
    for holder in holders:
      if holder.held == topHeld:
        result[holder.seat] = each
    return
  result[holders[0].seat] = majority
  let secondHeld = holders[1].held
  var secondCount = 0
  for i in 1 ..< holders.len:
    if holders[i].held == secondHeld:
      inc secondCount
  let each = roundBonusUpSplit(minority, secondCount)
  for i in 1 ..< holders.len:
    if holders[i].held == secondHeld:
      result[holders[i].seat] = each

proc currentHoldings(view: View, chain: Chain): seq[int] =
  for seat in 0 ..< view.playerCount:
    result.add(view.shares[seat][chain])

proc bonusPayoutsNow(view: View, chain: Chain): seq[int] =
  view.bonusPayouts(chain, view.chainSize(chain), view.currentHoldings(chain))

proc finalWorths(view: View): seq[int] =
  ## Per-seat net worth if the game ended right now: every active chain
  ## pays bonuses, then liquidation at current prices.
  result = view.cash
  for chain in view.activeChains():
    let
      bonuses = view.bonusPayoutsNow(chain)
      chainPrice = view.price(chain)
    for seat in 0 ..< view.playerCount:
      result[seat] += bonuses[seat] + view.shares[seat][chain] * chainPrice

proc bestRival(values: seq[int], seat: int): int =
  for i in 0 ..< values.len:
    if i != seat and values[i] > result:
      result = values[i]

proc edge(before, after: seq[int], seat: int): float =
  ## myDelta - RivalWeight * best rival delta.
  let
    mine = after[seat] - before[seat]
    rival = max(0, bestRival(after, seat) - bestRival(before, seat))
  float(mine) - RivalWeight * float(rival)

proc bestFoundChain(view: View): tuple[found: bool, chain: Chain] =
  ## The free founder share is worth the most in the highest tier.
  let options = view.inactiveChains()
  if options.len == 0:
    return (false, Tower)
  var best = options[0]
  for chain in options:
    if tier(chain) > tier(best):
      best = chain
  (true, best)

proc pickSurvivor(view: View, candidates: seq[Chain]): Chain =
  ## Where our position (vs the best rival's) is strongest.
  result = candidates[0]
  var bestScore = -1e18
  for chain in candidates:
    let holdings = view.currentHoldings(chain)
    let score = float(holdings[view.seat] - bestRival(holdings, view.seat)) +
      float(tier(chain)) * 0.1
    if score > bestScore:
      bestScore = score
      result = chain

proc placeScore(view: View, tile: int): float =
  let outcome = view.classifyPlace(tile)
  case outcome.kind
  of DeadMergePlace, EighthPlace:
    -1e18
  of LonePlace:
    ## Neutral, plus a nudge when we also hold an adjacent tile: next turn
    ## we can place it beside this one and found a chain we control.
    var foundSetup = false
    if view.inactiveChains().len > 0:
      for nb in neighbors(tile):
        if nb in view.hand:
          foundSetup = true
          break
    if foundSetup: 150.0 else: 0.0
  of FoundPlace:
    let (found, chain) = view.bestFoundChain()
    if not found:
      return -1e18
    float(sharePrice(chain, 2) + 400)
  of GrowPlace:
    let
      chain = outcome.chain
      oldSize = view.chainSize(chain)
      newSize = view.connectedComponent(tile).len
      priceDelta = sharePrice(chain, newSize) - sharePrice(chain, oldSize)
    var holdingsValue: seq[int]
    for seat in 0 ..< view.playerCount:
      holdingsValue.add(view.shares[seat][chain] * priceDelta)
    let
      holdings = view.currentHoldings(chain)
      before = view.bonusPayouts(chain, oldSize, holdings)
      after = view.bonusPayouts(chain, newSize, holdings)
      appreciation = float(holdingsValue[view.seat]) -
        RivalWeight * float(bestRival(holdingsValue, view.seat))
    appreciation + BonusWeight * edge(before, after, view.seat)
  of MergePlace:
    let
      component = view.connectedComponent(tile)
      survivor = view.pickSurvivor(outcome.survivorCandidates)
      newSize = component.len
    var
      before = newSeq[int](view.playerCount)
      after = newSeq[int](view.playerCount)
    for defunct in outcome.chains:
      if defunct == survivor:
        continue
      let bonuses = view.bonusPayoutsNow(defunct)
      for seat in 0 ..< view.playerCount:
        after[seat] += bonuses[seat]
    let priceDelta =
      sharePrice(survivor, newSize) -
      sharePrice(survivor, view.chainSize(survivor))
    for seat in 0 ..< view.playerCount:
      after[seat] += view.shares[seat][survivor] * priceDelta
    edge(before, after, view.seat)

proc buyCombos(view: View): seq[seq[Purchase]] =
  ## All multisets of up to 3 purchases over the affordable active chains.
  let cash = view.cash[view.seat]
  var options: seq[Chain]
  for chain in view.activeChains():
    if view.bankShares(chain) > 0 and view.price(chain) <= cash:
      options.add(chain)
  result.add(@[])
  var combos = addr result

  proc build(view: View, options: seq[Chain], start: int,
      picked: seq[Chain], cost: int) =
    if picked.len == 3:
      return
    for i in start ..< options.len:
      let
        chain = options[i]
        nextCost = cost + view.price(chain)
      var already = 0
      for p in picked:
        if p == chain:
          inc already
      if nextCost > cash or already + 1 > view.bankShares(chain):
        continue
      let next = picked & @[chain]
      var combo: seq[Purchase]
      for c in Chain:
        var count = 0
        for p in next:
          if p == c:
            inc count
        if count > 0:
          combo.add(Purchase(chain: c, count: count))
      combos[].add(combo)
      build(view, options, i, next, nextCost)

  build(view, options, 0, @[], 0)

proc buyScore(view: View, combo: seq[Purchase]): float =
  ## Bonus-position deltas (parity math on the public holdings) + expected
  ## appreciation - a mild cash preference.
  var cost = 0
  for purchase in combo:
    let
      chainPrice = view.price(purchase.chain)
      size = view.chainSize(purchase.chain)
      holdings = view.currentHoldings(purchase.chain)
    cost += purchase.count * chainPrice
    var afterHoldings = holdings
    afterHoldings[view.seat] += purchase.count
    let
      before = view.bonusPayouts(purchase.chain, size, holdings)
      after = view.bonusPayouts(purchase.chain, size, afterHoldings)
      growth = sharePrice(purchase.chain, size + GrowthTiles) -
        sharePrice(purchase.chain, size)
    result += BonusWeight * edge(before, after, view.seat)
    result += GrowthWeight * float(purchase.count * growth)
  result -= CashWeight * float(cost)

proc mergerStockDecision(view: View): JsonNode =
  ## Trade toward a survivor position when the exchange rate or the bonus
  ## parity justifies it; sell the rest for compounding cash.
  let
    defunct = view.mergerDefunct[0]
    survivor = view.mergerSurvivor
    held = view.shares[view.seat][defunct]
    defunctPrice = view.price(defunct)
    newSize = view.connectedComponent(view.mergerTile).len
    survivorPrice = sharePrice(survivor, newSize)
    maxTrades = min(held div 2, view.bankShares(survivor))
    holdings = view.currentHoldings(survivor)
  var
    bestTrade = 0
    bestScore = -1e18
  for trades in 0 .. maxTrades:
    var afterHoldings = holdings
    afterHoldings[view.seat] += trades
    let
      before = view.bonusPayouts(survivor, newSize, holdings)
      after = view.bonusPayouts(survivor, newSize, afterHoldings)
      score = float(trades * (survivorPrice - 2 * defunctPrice)) +
        BonusWeight * edge(before, after, view.seat)
    if score > bestScore:
      bestScore = score
      bestTrade = trades
  %*{"kind": "mergerStock", "sell": held - 2 * bestTrade,
     "trade": bestTrade}

proc valueDecision(view: View): JsonNode =
  ## The always-legal exact-EV decision for the current phase.
  case view.phase
  of "place":
    var best = view.hand[0]
    for tile in view.hand:
      if view.isPlayable(tile):
        best = tile
        break
    var bestScore = -1e18
    for tile in view.hand:
      let score = view.placeScore(tile)
      if score > bestScore:
        bestScore = score
        best = tile
    %*{"kind": "place", "tile": best}
  of "found":
    let (found, chain) = view.bestFoundChain()
    let pick = if found: chain else: view.inactiveChains()[0]
    %*{"kind": "found", "chain": $pick}
  of "survivor":
    %*{"kind": "survivor", "chain": $view.pickSurvivor(view.mergerCandidates)}
  of "mergerStock":
    view.mergerStockDecision()
  of "buy":
    var
      best: seq[Purchase]
      bestScore = 0.0                    # the empty buy scores 0
    for combo in view.buyCombos():
      let score = view.buyScore(combo)
      if score > bestScore:
        bestScore = score
        best = combo
    ## Declare the end only when the full final accounting (with this buy
    ## applied) says we finish first.
    var declareEnd = false
    if view.endConditionMet():
      var projected = view
      for purchase in best:
        projected.shares[view.seat][purchase.chain] += purchase.count
        projected.cash[view.seat] -= purchase.count * view.price(purchase.chain)
      let worths = projected.finalWorths()
      var top = worths[0]
      for worth in worths:
        if worth > top:
          top = worth
      declareEnd = worths[view.seat] >= top
    var purchases = newJArray()
    for purchase in best:
      purchases.add(%*{"chain": $purchase.chain, "count": purchase.count})
    %*{"kind": "buy", "purchases": purchases, "declareEnd": declareEnd}
  else:
    raise newException(ValueError, "unknown phase: " & view.phase)

proc baselineDecision(view: View): JsonNode =
  ## The always-legal fallback used when the host rejected a move (reason
  ## set): plays a legal tile, founds the first free chain, keeps the
  ## first survivor, sells everything, buys nothing.
  case view.phase
  of "place":
    var tile = view.hand[0]
    for candidate in view.hand:
      if view.isPlayable(candidate):
        tile = candidate
        break
    %*{"kind": "place", "tile": tile}
  of "found":
    %*{"kind": "found", "chain": $view.inactiveChains()[0]}
  of "survivor":
    %*{"kind": "survivor", "chain": $view.mergerCandidates[0]}
  of "mergerStock":
    %*{"kind": "mergerStock", "sell": view.shares[view.seat][view.mergerDefunct[0]],
       "trade": 0}
  else:
    %*{"kind": "buy", "purchases": [], "declareEnd": false}

proc main() =
  let client = newCoworldClient("korobochka")
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      echo "korobochka: seated slot ", message{"slot"}.getInt()
    of "observation":
      let
        seat = message{"seat"}.getInt()
        reason = message{"reason"}.getStr()
        view = parseView(message{"view"}, seat)
      let decision =
        if reason.len > 0:
          echo "korobochka: move rejected (", reason, "), playing baseline"
          view.baselineDecision()
        else:
          view.valueDecision()
      client.send(%*{"type": "reply", "id": message{"id"}, "decision": decision})
    of "final":
      echo "korobochka: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

when isMainModule:
  main()
