## Alkonost — Cogherence policy for Andre von Auto.
## A COMMAND player on the shared `cogweb.player.v1` wire protocol: each
## `observation` carries the seat's redacted board snapshot and a
## correlation id; the reply is `{type:"reply", id, decision:{orders:[..]},
## messages:[]}`. The bundled `cogherence-baseline` example always HOLDS
## (empty order set); Alkonost is that always-legal skeleton plus the
## scripted line the engine source makes obvious:
##
## - Hearts are the ONLY win condition, one heart is auctioned per turn
##   (sealed second-price, 1e reserve), and ONLY COGS HOLDING GROUND MAY
##   BID — so the home tile is a bidding license: never abandon the last
##   tile, and defend it with a cheap self-align when rivals drain it.
## - Under the coworld seam there is NO mineral→energy conversion order
##   (auto-conversion is a live-server behavior the seam deliberately
##   omits), so stored energy (100 to start) is nearly the whole game
##   budget: spend it on bids, not on expansion whose upkeep
##   (floor(sqrt(tiles)) per tile per turn) eats the war chest.
## - Extra tiles (never expected, but captures happen) are abandoned:
##   the standing coherence comes home as energy and the upkeep stops.
## - Second-price means we pay the runner-up's price: against passive
##   fields every heart costs the 1e reserve. The seam has no conversion
##   and no first-commit bonus, so 100e is the whole budget and a 1-tile
##   keeper is forced to pay 1e upkeep whenever it has energy. Winning at
##   price p therefore costs p+1 per heart; bid 2 is the unexploitable
##   default (beats 0–1 bidders 50–25, ties any bid≥2 at 33–33, and still
##   only pays the 1e reserve against a silent field). All-in when behind
##   late; nothing once uncatchable.

import std/json, coworld_client

const
  maxTurns = 100      # engine MAX_TURNS; the view carries only `turn`
  coherenceMax = 10   # engine COHERENCE_MAX (also in view.coherenceMax)

proc num(node: JsonNode): float =
  if node.isNil: 0.0
  elif node.kind == JInt: node.getInt.float
  elif node.kind == JFloat: node.getFloat
  else: 0.0

proc tileKey(tile: JsonNode): string =
  ## The engine's HexKey: "q,r".
  $tile{"q"}.getInt & "," & $tile{"r"}.getInt

proc decideOrders(view: JsonNode, seat: int): JsonNode =
  ## The turn's Order[] for the sealed simultaneous commit.
  result = newJArray()

  # My cog: the snapshot's cogs ride in seat (cogOrder) order.
  var me: JsonNode = nil
  for cog in view{"cogs"}.getElems:
    if cog{"index"}.getInt == seat:
      me = cog
  if me.isNil:
    return
  let
    myId = me{"id"}.getStr
    myEnergy = int(num(me{"energy"}))
    myHearts = me{"hearts"}.getInt

  var rivalBestHearts = 0
  for cog in view{"cogs"}.getElems:
    if cog{"id"}.getStr != myId and cog{"hearts"}.getInt > rivalBestHearts:
      rivalBestHearts = cog{"hearts"}.getInt

  var myTiles: seq[JsonNode]
  for tile in view{"tiles"}.getElems:
    if tile{"alignment"}.getStr == myId:
      myTiles.add tile
  if myTiles.len == 0:
    # Wiped off the board: no ground to bid or align from — hold.
    return

  # Keep the sturdiest tile as the bidding license; abandon the rest
  # (refund = standing coherence, and their upkeep stops).
  var keeper = myTiles[0]
  for tile in myTiles:
    if tile{"coherence"}.getInt > keeper{"coherence"}.getInt or
        (tile{"coherence"}.getInt == keeper{"coherence"}.getInt and
         num(tile{"density"}) > num(keeper{"density"})):
      keeper = tile
  for tile in myTiles:
    if tileKey(tile) != tileKey(keeper):
      result.add %*{"type": "abandon", "tile": tileKey(tile)}

  # Defense: a drained keeper is a lost auction seat. A self-align costs
  # force^2 (distance 0) and adds force to the tug-of-war incumbent.
  var alignSpend = 0
  let keeperCoherence = keeper{"coherence"}.getInt
  if keeperCoherence <= 6 and myEnergy > 20:
    let force = min(if keeperCoherence <= 3: 3 else: 2,
                    coherenceMax - keeperCoherence)
    if force >= 1:
      alignSpend = force * force
      result.add %*{"type": "align", "tile": tileKey(keeper), "force": force}

  # Bid: sized by the heart race. The whole order set must be affordable
  # (align energy + bid <= stored energy) or it is rejected wholesale.
  let
    turnsLeft = max(1, maxTurns - view{"turn"}.getInt + 1)
    lead = myHearts - rivalBestHearts
    available = myEnergy - alignSpend - 1
  if lead <= turnsLeft and available >= 1:
    let bid =
      if turnsLeft <= 12 and lead <= 0:
        available                       # late and not ahead: all-in; we
                                        # only ever pay the second price
      else:
        min(available, 2)               # 2e is unexploitable: vs a silent
                                        # field we still pay the 1e reserve;
                                        # vs a 1-bidder we win 50–25; vs any
                                        # bid ≥2 the 3e/heart drain ties 33–33.
                                        # energy/6 wins early auctions we
                                        # should lose and bankrupts us.
    result.add %*{"type": "bid", "energy": bid}

proc main() =
  let client = newCoworldClient("alkonost")
  var slot = -1
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr
    of "welcome":
      slot = message{"slot"}.getInt
      echo "alkonost: seated slot ", slot
    of "observation":
      let
        id = message{"id"}
        seat = message{"seat"}.getInt(slot)
        reason = message{"reason"}
      var orders: JsonNode
      if not reason.isNil and reason.kind != JNull:
        # Our previous order set was rejected (whole-set semantics):
        # fall back to the always-legal hold rather than loop.
        echo "alkonost: orders rejected (", reason.getStr, "), holding"
        orders = newJArray()
      else:
        try:
          orders = decideOrders(message{"view"}, seat)
        except CatchableError:
          orders = newJArray()
      client.send %*{"type": "reply", "id": id,
                     "decision": {"orders": orders}, "messages": []}
    of "final":
      echo "alkonost: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
