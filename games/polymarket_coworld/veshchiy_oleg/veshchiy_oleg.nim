## Veshchiy Oleg — Polymarket Coworld policy for Andre von Auto.
## Command player: a Nim rewrite of the strongest non-scripted example,
## `starter` (Starter Trader, players/starter.py in coworld-polymarket).
## Each turn it spends one private query on price history, estimates a
## fair YES probability per market from the book midpoint, the price
## trend, keyword public signals and the BTC stream-vs-threshold gap,
## then sells overpriced holdings and buys the best-edge outcome with
## conviction-scaled sizing (docs/protocol_player.md).

import std/[math, sets, strutils], coworld_client

const
  ## Engine default `max_order_quantity` (manifest/GameConfig). Starter's 80
  ## left size on the table: fills have no book-depth limit, score is P&L.
  MaxOrderQuantity = 250.0
  MinEdge = 0.04
  MinQuantity = 1.0

  YesSignalPatterns = [
    "yes likely", "toward yes", "yes nearly certain",
    "converging toward yes", "crossed", "above", "stayed above",
    "positive", "improves"]
  NoSignalPatterns = [
    "no likely", "toward no", "no nearly certain",
    "converging toward no", "compress", "cut", "changed",
    "away team leads", "away team won", "negative"]

proc num(node: JsonNode): float =
  ## Tolerant numeric read: the fixture feeds mix numbers and strings.
  if node == nil:
    return 0.0
  case node.kind
  of JInt, JFloat:
    node.getFloat()
  of JString:
    try:
      parseFloat(node.getStr())
    except ValueError:
      0.0
  else:
    0.0

proc round4(value: float): float =
  round(value * 10000.0) / 10000.0

proc midpoint(snapshot: JsonNode, outcome: string): float =
  (num(snapshot{outcome & "_bid"}) + num(snapshot{outcome & "_ask"})) / 2.0

proc clampProbability(value: float): float =
  min(0.97, max(0.03, value))

proc publicSignalAdjustment(market: JsonNode): float =
  let snapshot = market{"snapshot"}
  var text = market{"question"}.getStr() & " " &
    market{"description"}.getStr() & " " &
    snapshot{"public_signal"}.getStr()
  if market{"tags"} != nil and market{"tags"}.kind == JArray:
    for tag in market{"tags"}:
      text.add(" " & tag.getStr())
  text = text.toLowerAscii()
  var yesHits, noHits = 0
  for pattern in YesSignalPatterns:
    if pattern in text:
      inc yesHits
  for pattern in NoSignalPatterns:
    if pattern in text:
      inc noHits
  0.08 * float(yesHits - noHits)

proc thresholdAfterAbove(question: string): float =
  ## Parses the dollar threshold following the word "above" in the market
  ## question, e.g. "close above $65,000.50?". Returns -1.0 when absent.
  let at = question.find("above")
  if at < 0:
    return -1.0
  var i = at + "above".len
  while i < question.len and question[i] == ' ':
    inc i
  if i < question.len and question[i] == '$':
    inc i
  var digits = ""
  while i < question.len and (question[i] in Digits or question[i] in {',', '.'}):
    if question[i] != ',':
      digits.add(question[i])
    inc i
  if digits.len == 0 or digits[0] notin Digits:
    return -1.0
  try:
    parseFloat(digits.strip(chars = {'.'}))
  except ValueError:
    -1.0

proc thresholdSignalAdjustment(market: JsonNode): float =
  let
    question = market{"question"}.getStr().toLowerAscii()
    snapshot = market{"snapshot"}
    streamPrices = snapshot{"stream_prices"}
  if "bitcoin" notin question and "btc" notin question:
    return 0.0
  let threshold = thresholdAfterAbove(question)
  if threshold < 0.0 or streamPrices == nil or streamPrices{"btcusdt"} == nil:
    return 0.0
  let
    current = num(streamPrices{"btcusdt"})
    distance = (current - threshold) / max(threshold, 1.0)
  if distance >= 0.0:
    return min(0.24, 0.12 + distance * 20.0)
  let recent = market{"recent_prices"}
  if recent != nil and recent.len >= 2:
    let firstStream = recent[0]{"stream_prices"}{"btcusdt"}
    if firstStream != nil and current > num(firstStream):
      return max(-0.04, distance * 6.0)
  max(-0.16, distance * 10.0)

proc estimateYesProbability(market: JsonNode): float =
  let history = market{"recent_prices"}
  var first, last: JsonNode
  if history != nil and history.len > 0:
    first = history[0]
    last = history[history.len - 1]
  else:
    first = market{"snapshot"}
    last = first
  let
    yesMid = midpoint(last, "yes")
    noMid = midpoint(last, "no")
    marketProbability = yesMid / max(yesMid + noMid, 0.01)
    fullTrend = midpoint(last, "yes") - midpoint(first, "yes")
  var recentTrend = 0.0
  if history != nil and history.len >= 2:
    recentTrend = midpoint(history[history.len - 1], "yes") -
      midpoint(history[history.len - 2], "yes")
  let signal = publicSignalAdjustment(market) + thresholdSignalAdjustment(market)
  clampProbability(
    marketProbability + 0.55 * fullTrend + 0.25 * recentTrend + signal)

proc orderQuantity(cash, price, edge: float, marketCount: int): float =
  let
    perMarketBudget = cash * 0.45 / float(max(marketCount, 1))
    conviction = min(1.0, max(0.0, edge / 0.25))
    quantity = min(MaxOrderQuantity,
      perMarketBudget * conviction / max(price, 0.01))
  if quantity < MinQuantity:
    return 0.0
  round4(quantity)

proc chooseOrders(state: JsonNode): JsonNode =
  result = newJArray()
  let
    positions = state{"portfolio"}{"positions"}
    markets = state{"markets"}
    marketCount = markets.len
  var availableCash = num(state{"portfolio"}{"cash"})
  for market in markets:
    let
      marketId = market{"id"}.getStr()
      snapshot = market{"snapshot"}
      yesProbability = estimateYesProbability(market)
      noProbability = 1.0 - yesProbability
    let candidates = [
      ("yes", yesProbability, num(snapshot{"yes_ask"}), num(snapshot{"yes_bid"})),
      ("no", noProbability, num(snapshot{"no_ask"}), num(snapshot{"no_bid"}))]
    ## Take profits on holdings whose bid is above our fair value.
    for (outcome, estimatedProbability, ask, bid) in candidates:
      let held = num(positions{marketId}{outcome})
      if held > 0.0 and bid - estimatedProbability > MinEdge:
        let quantity = round4(min(held * 0.999, MaxOrderQuantity))
        if quantity >= MinQuantity:
          result.add(%*{"market_id": marketId, "outcome": outcome,
            "side": "sell", "quantity": quantity})
    ## Buy the outcome with the best probability-vs-ask edge.
    var best = candidates[0]
    if candidates[1][1] - candidates[1][2] > best[1] - best[2]:
      best = candidates[1]
    let
      (bestOutcome, bestProbability, bestAsk, _) = best
      edge = bestProbability - bestAsk
    if edge <= MinEdge:
      continue
    var quantity = orderQuantity(availableCash, bestAsk, edge, marketCount)
    if quantity * bestAsk * 1.01 > availableCash:
      quantity = round4(max(0.0, availableCash / max(bestAsk * 1.01, 0.01)))
    if quantity > 0.0:
      result.add(%*{"market_id": marketId, "outcome": bestOutcome,
        "side": "buy", "quantity": quantity})
      availableCash -= quantity * bestAsk * 1.01

proc main() =
  let client = newCoworldClient("veshchiy_oleg")
  var queriedTurns = initHashSet[int]()
  client.run proc(message: JsonNode) =
    if message{"type"}.getStr() == "action_result":
      ## A rejected action would deadlock the turn: pass instead.
      if message{"result"}{"kind"}.getStr() == "rejected":
        echo "veshchiy_oleg: action rejected, submitting empty orders"
        client.send(%*{"type": "submit_orders", "orders": []})
      return
    let state =
      if message{"type"}.getStr() == "query_result":
        message{"state"}
      else:
        message
    if state == nil or state{"type"}.getStr() != "state":
      return
    if state{"phase"}.getStr() == "complete":
      echo "veshchiy_oleg: complete, results ", state{"results"}
      quit(0)
    if state{"has_submitted"}.getBool():
      return
    let turn = state{"turn"}.getInt()
    let markets = state{"markets"}
    if turn notin queriedTurns and
        state{"query_budget_remaining"}.getInt() > 0 and markets.len > 0:
      queriedTurns.incl(turn)
      let market = markets[turn mod markets.len]
      client.send(%*{"type": "query", "query": {
        "type": "price_history", "market_id": market{"id"}.getStr()}})
      return
    client.send(%*{"type": "submit_orders", "orders": chooseOrders(state)})

main()
