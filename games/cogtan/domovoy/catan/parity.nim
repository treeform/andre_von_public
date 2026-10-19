## Parity harness: replays a TypeScript-engine trajectory dump (JSONL of
## {pre, seat, decision, post} full states) through the Nim simulator and
## asserts identical resulting state at every step. Chance (dice, robber
## steals) is injected from the dump; the dev deck is parsed verbatim, so
## draws line up deterministically. Run:
##   nim r catan/parity.nim /path/to/cogtan_parity.jsonl

import std/[json, os, strutils], nodes, dumpstate

proc stealIndexFor(pre: GameState, victim: int, stolen: Resource): int =
  ## The engine draws idx in [0, victim hand size) over the cumulative
  ## resource order; any idx inside the stolen resource's run matches.
  for resource in Resource:
    if resource == stolen:
      return result
    result += int(pre.hands[victim][resource])

proc applyRecord(state: var GameState, record: JsonNode): bool =
  ## Applies the dumped decision with chance injected from the dump.
  let decision = record{"decision"}
  let post = record{"post"}
  case decision{"kind"}.getStr()
  of "setup":
    state.applyMoveInPlace(Move(kind: SetupMove,
      a: int8(decision{"vertex"}.getInt()),
      b: int8(decision{"edge"}.getInt())))
  of "roll":
    let dice = post{"dice"}
    state.applyRollWith(dice[0].getInt(), dice[1].getInt())
  of "discard":
    state.applyMoveInPlace(Move(kind: DiscardMove,
      give: parseBundle(decision{"give"})))
  of "robber":
    let hex = decision{"hex"}.getInt()
    let victimNode = decision{"victim"}
    if victimNode == nil or victimNode.kind == JNull:
      state.applyRobberWith(hex, NoSeat, 0)
    else:
      let victim = victimNode.getInt()
      # Recover the stolen resource from the victim's hand delta.
      let postHand = parseBundle(post{"hands"}[victim])
      var stolen = Brick
      for resource in Resource:
        if postHand[resource] < state.hands[victim][resource]:
          stolen = resource
      state.applyRobberWith(hex, victim,
        state.stealIndexFor(victim, stolen))
  of "buildRoad":
    state.applyMoveInPlace(Move(kind: BuildRoadMove,
      a: int8(decision{"edge"}.getInt())))
  of "buildSettlement":
    state.applyMoveInPlace(Move(kind: BuildSettlementMove,
      a: int8(decision{"vertex"}.getInt())))
  of "buildCity":
    state.applyMoveInPlace(Move(kind: BuildCityMove,
      a: int8(decision{"vertex"}.getInt())))
  of "buyDev":
    state.applyMoveInPlace(Move(kind: BuyDevMove))
  of "playKnight":
    state.applyMoveInPlace(Move(kind: PlayKnightMove))
  of "playRoadBuilding":
    let edges = decision{"edges"}
    state.applyMoveInPlace(Move(kind: PlayRoadBuildingMove,
      a: int8(edges[0].getInt()),
      b: if edges.len > 1: int8(edges[1].getInt()) else: int8(-1)))
  of "playYearOfPlenty":
    let take = decision{"take"}
    state.applyMoveInPlace(Move(kind: PlayYearOfPlentyMove,
      a: int8(ord(parseResource(take[0].getStr()))),
      b: int8(ord(parseResource(take[1].getStr())))))
  of "playMonopoly":
    state.applyMoveInPlace(Move(kind: PlayMonopolyMove,
      a: int8(ord(parseResource(decision{"resource"}.getStr())))))
  of "bankTrade":
    state.applyMoveInPlace(Move(kind: BankTradeMove,
      a: int8(ord(parseResource(decision{"give"}.getStr()))),
      b: int8(ord(parseResource(decision{"receive"}.getStr())))))
  of "offerTrade":
    state.applyOfferTrade(decision{"to"}.getInt(),
      parseBundle(decision{"give"}), parseBundle(decision{"receive"}))
  of "respondTrade":
    state.applyMoveInPlace(Move(kind: RespondTradeMove,
      a: if decision{"accept"}.getBool(): 1'i8 else: 0'i8))
  of "endTurn":
    state.applyMoveInPlace(Move(kind: EndTurnMove))
  else:
    return false
  true

proc main() =
  let path = paramStr(1)
  var
    step = 0
    mismatches = 0
  for line in lines(path):
    if line.len == 0:
      continue
    inc step
    let record = parseJson(line)
    var state = parseFullState(record{"pre"})
    if not state.applyRecord(record):
      echo "step ", step, ": unknown decision ", record{"decision"}
      inc mismatches
      continue
    let expected = parseFullState(record{"post"}).canonical()
    let got = state.canonical()
    if got != expected:
      inc mismatches
      echo "MISMATCH at step ", step, " decision=", record{"decision"}
      let expectedLines = expected.splitLines()
      let gotLines = got.splitLines()
      for i in 0 ..< max(expectedLines.len, gotLines.len):
        let want = if i < expectedLines.len: expectedLines[i] else: ""
        let have = if i < gotLines.len: gotLines[i] else: ""
        if want != have:
          echo "  want ", want
          echo "  have ", have
      if mismatches >= 5:
        echo "stopping after 5 mismatches"
        break
  echo "parity: ", step, " steps, ", mismatches, " mismatches"
  if mismatches > 0:
    quit(1)

main()
