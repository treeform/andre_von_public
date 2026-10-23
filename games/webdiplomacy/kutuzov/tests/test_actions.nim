import
  std/[json, strutils],
  ../[actions, common]

proc variant(): JsonNode =
  ## Supply synthetic exact identities, including separate parent and coast IDs.
  result = %*{"territories": []}
  for id in 1 .. 81:
    result["territories"].add %*{"id": id, "name": "Territory " & $id}
  result["territories"][75]["name"] = %"Spain (north coast)"
  result["territories"][75]["coastParentID"] = %75
  result["territories"][76]["name"] = %"Spain (south coast)"
  result["territories"][76]["coastParentID"] = %75

proc order(
  kind: string,
  origin: JsonNode,
  destination: JsonNode = nil,
  supported: JsonNode = nil,
  convoy = false,
  route: JsonNode = nil
): JsonNode =
  ## Construct explicitly complete test arguments without selecting any moves.
  %*{
    "type": kind,
    "origin": origin,
    "destination": (if destination.isNil: newJNull() else: destination),
    "supported_origin": (if supported.isNil: newJNull() else: supported),
    "via_convoy": convoy,
    "convoy_route": (if route.isNil: newJArray() else: route)
  }

proc commit(orders: JsonNode): JsonNode =
  ## Wrap a supplied batch with explicitly supplied assessment strings.
  %*{
    "orders": orders,
    "center_check": "Preserve exact chosen targets.",
    "support_check": "Review explicit chosen dependencies."
  }

template rejects(body: untyped) =
  ## Require the bot-specific exception at the parsing boundary.
  block:
    var failed = false
    try:
      body
    except KutuzovError:
      failed = true
    doAssert failed, "Expected KutuzovError"

echo "Testing complete named order translation and exact coast identities"
block:
  let
    map = variant()
    orders = newJArray()
  orders.add order("Hold", %"Territory 1")
  orders.add order("Move", %2, %15)
  orders.add order("Support hold", %3, %2)
  orders.add order("Support move", %4, %15, %2)
  orders.add order("Convoy", %5, %16, %6, route = %*[6, 5])
  orders.add order("Move", %6, %16, convoy = true,
    route = %*["Territory 6", "Territory 5"])
  orders.add order("Retreat", %7, %17)
  orders.add order("Disband", %8)
  orders.add order("Build Army", %9, %"Territory 9")
  orders.add order("Build Fleet", %"Spain (north coast)", %76)
  orders.add order("Destroy", %11, %11)
  orders.add order("Wait", newJNull(), %0, %0)
  orders.add order("Support move", %14, %16, %6, route = %*[6, 5])
  let
    input = commit(orders)
    before = $input
    translated = readCommit(map, input)
    expected = %*[
      {"type": "Hold", "terrID": 1, "toTerrID": 0,
        "fromTerrID": 0, "viaConvoy": "No"},
      {"type": "Move", "terrID": 2, "toTerrID": 15,
        "fromTerrID": 0, "viaConvoy": "No"},
      {"type": "Support hold", "terrID": 3, "toTerrID": 2,
        "fromTerrID": 0, "viaConvoy": "No"},
      {"type": "Support move", "terrID": 4, "toTerrID": 15,
        "fromTerrID": 2, "viaConvoy": "No"},
      {"type": "Convoy", "terrID": 5, "toTerrID": 16,
        "fromTerrID": 6, "viaConvoy": "No", "convoyPath": [6, 5]},
      {"type": "Move", "terrID": 6, "toTerrID": 16,
        "fromTerrID": 0, "viaConvoy": "Yes", "convoyPath": [6, 5]},
      {"type": "Retreat", "terrID": 7, "toTerrID": 17,
        "fromTerrID": 0, "viaConvoy": "No"},
      {"type": "Disband", "terrID": 8, "toTerrID": 0,
        "fromTerrID": 0, "viaConvoy": "No"},
      {"type": "Build Army", "terrID": 9, "toTerrID": 9,
        "fromTerrID": 0, "viaConvoy": "No"},
      {"type": "Build Fleet", "terrID": 76, "toTerrID": 76,
        "fromTerrID": 0, "viaConvoy": "No"},
      {"type": "Destroy", "terrID": 11, "toTerrID": 11,
        "fromTerrID": 0, "viaConvoy": "No"},
      {"type": "Wait", "terrID": 0, "toTerrID": 0,
        "fromTerrID": 0, "viaConvoy": "No"},
      {"type": "Support move", "terrID": 14, "toTerrID": 16,
        "fromTerrID": 6, "viaConvoy": "No", "convoyPath": [6, 5]}
    ]
  doAssert translated.orders == expected
  doAssert translated.centerCheck == input["center_check"].getStr()
  doAssert translated.supportCheck == input["support_check"].getStr()
  doAssert $input == before
  translated.orders[0]["terrID"] = %81
  doAssert $input == before
  let coastOrders = %*[
    order("Hold", %75), order("Hold", %76), order("Hold", %77)
  ]
  doAssert readCommit(map, commit(coastOrders)).orders.len == 3

echo "Testing actionable order type errors without aliases or coercion"
block:
  let map = variant()
  for kind in ["Support", "support hold", "Support Hold", "Support move ",
    "Attack"]:
      let
        input = commit(%*[order(kind, %1, %2)])
        before = $input
      var message = ""
      try:
        discard readCommit(map, input)
      except KutuzovError as error:
        message = error.msg
      doAssert message.startsWith("Unknown order type " & $(%kind) & ".")
      for accepted in ["Hold", "Move", "Support hold", "Support move",
        "Convoy", "Retreat", "Disband", "Build Army", "Build Fleet",
        "Destroy", "Wait"]:
          doAssert $(%accepted) in message
          doAssert $(%accepted) in ActionsProtocol
      doAssert $input == before
  doAssert "\"Support\" is invalid" in ActionsProtocol

echo "Testing strict types, completeness, duplicate origins and bounds"
block:
  let
    map = variant()
    one = order("Hold", %1)
    input = commit(%*[one])
  for bad in [JsonNode(nil), newJNull(), %false, %1, %"{}", newJArray()]:
    rejects:
      discard readCommit(map, bad)
  for field in ["orders", "center_check", "support_check"]:
    let missing = input.copy()
    missing.delete(field)
    rejects:
      discard readCommit(map, missing)
  let extra = input.copy()
  extra["memory"] = %"Unrecognized field"
  rejects:
    discard readCommit(map, extra)
  for field in ["type", "origin", "destination", "supported_origin",
    "via_convoy", "convoy_route"]:
      let missing = one.copy()
      missing.delete(field)
      rejects:
        discard readCommit(map, commit(%*[missing]))
  let extraOrder = one.copy()
  extraOrder["unit_type"] = %"Army"
  rejects:
    discard readCommit(map, commit(%*[extraOrder]))
  let
    rejectedBatch = commit(%*[one, order("Move", %2, %"Unknown")])
    beforeRejected = $rejectedBatch
  rejects:
    discard readCommit(map, rejectedBatch)
  doAssert $rejectedBatch == beforeRejected
  for bad in [%0, %(-1), %1.0, %true, newJNull(), %"1",
    %"territory 1", %"Territory 1 ", %"Missing", %82]:
      rejects:
        discard readCommit(map, commit(%*[order("Hold", bad)]))
  for bad in [%"Yes", %0, newJNull()]:
    let item = one.copy()
    item["via_convoy"] = bad
    rejects:
      discard readCommit(map, commit(%*[item]))
  for bad in [%"hold", %"Attack", newJNull(), %4]:
    let item = one.copy()
    item["type"] = bad
    rejects:
      discard readCommit(map, commit(%*[item]))
  for bad in [%2, %false, %"0"]:
    rejects:
      discard readCommit(map, commit(%*[order("Hold", %1, bad)]))
  rejects:
    discard readCommit(map, commit(%*[one, one.copy()]))
  rejects:
    discard readCommit(map, commit(%*[
      order("Hold", %1), order("Move", %"Territory 1", %2)
    ]))
  rejects:
    discard readCommit(map, commit(%*[
      order("Wait", %0), order("Wait", newJNull())
    ]))
  rejects:
    discard readCommit(map, commit(newJArray()))
  let many = newJArray()
  for id in 1 .. MaximumOrders:
    many.add order("Hold", %id)
  doAssert readCommit(map, commit(many)).orders.len == MaximumOrders
  many.add order("Hold", %65)
  rejects:
    discard readCommit(map, commit(many))
  for field in ["center_check", "support_check"]:
    let report = input.copy()
    report[field] = %repeat("x", MaximumActionCheckBytes)
    discard readCommit(map, report)
    report[field] = %repeat("x", MaximumActionCheckBytes + 1)
    rejects:
      discard readCommit(map, report)
    report[field] = %"\xff"
    rejects:
      discard readCommit(map, report)
    report[field] = newJNull()
    rejects:
      discard readCommit(map, report)

echo "Testing convoy shape without inventing routes or adjudicating legality"
block:
  let map = variant()
  for item in [
    order("Build Army", %1, %2),
    order("Build Fleet", %75, %76),
    order("Destroy", %1, %2),
    order("Wait", %1),
    order("Hold", %1, supported = %2),
    order("Move", %1, %2, supported = %3),
    order("Move", %1),
    order("Support move", %1, %2),
    order("Support hold", %1, %2, %3),
    order("Retreat", %1, %2, convoy = true),
    order("Convoy", %3, %2, %1, convoy = true, route = %*[1, 3]),
    order("Move", %1, %2, convoy = true),
    order("Convoy", %3, %2, %1),
    order("Move", %1, %2, route = %*[1, 3]),
    order("Hold", %1, route = %*[1, 3]),
    order("Support hold", %1, %2, route = %*[1, 3]),
    order("Move", %1, %2, convoy = true, route = %*[1]),
    order("Move", %1, %2, convoy = true, route = %*[3, 1]),
    order("Move", %1, %2, convoy = true, route = %*[1, 3, 2]),
    order("Move", %1, %2, convoy = true, route = %*[1, 3, 3]),
    order("Move", %1, %2, convoy = true, route = %*[1, "Missing"]),
    order("Convoy", %4, %2, %1, route = %*[1, 3]),
    order("Support move", %3, %2, %1, route = %*[1, 3])
  ]:
    rejects:
      discard readCommit(map, commit(%*[item]))
  for bad in [newJNull(), %"[]", %false]:
    let item = order("Hold", %1)
    item["convoy_route"] = bad
    rejects:
      discard readCommit(map, commit(%*[item]))
  let path = newJArray()
  for id in 1 .. MaximumConvoyRoute:
    path.add %id
  doAssert readCommit(map, commit(%*[
    order("Move", %1, %81, convoy = true, route = path)
  ])).orders[0]["convoyPath"] == path
  path.add %65
  rejects:
    discard readCommit(map, commit(%*[
      order("Move", %1, %81, convoy = true, route = path)
    ]))
  # No geometry, unit type, own support matching, or route invention is added.
  let unjudged = readCommit(map, commit(%*[
    order("Move", %1, %81), order("Support move", %2, %50, %1)
  ]))
  doAssert unjudged.orders[0]["toTerrID"].getInt() == 81
  doAssert unjudged.orders[1]["toTerrID"].getInt() == 50

echo "Testing strict board, connections, press, notes and finish arguments"
block:
  let map = variant()
  readBoard(newJObject())
  for bad in [JsonNode(nil), newJNull(), newJArray(), %*{"extra": 1}]:
    rejects:
      readBoard(bad)
  doAssert readConnections(map, %*{
    "territories": [1, "Spain (north coast)", 77]
  }) == %*[1, 76, 77]
  for bad in [newJNull(), newJObject(), %*{"territories": []},
    %*{"territories": [0]}, %*{"territories": ["spain (north coast)"]},
    %*{"territories": [1], "extra": false}]:
      rejects:
        discard readConnections(map, bad)
  let references = newJArray()
  for id in 1 .. 16:
    references.add %id
  doAssert readConnections(map, %*{"territories": references}).len == 16
  references.add %17
  rejects:
    discard readConnections(map, %*{"territories": references})
  let drafts = %*{"messages": [{"to": 0, "text": repeat("é", 300)}]}
  let press = readPress(drafts)
  doAssert press == drafts["messages"]
  press[0]["text"] = %"Changed returned copy"
  doAssert drafts["messages"][0]["text"].getStr() == repeat("é", 300)
  doAssert readPress(%*{"messages": []}).len == 0
  let messages = newJArray()
  for recipient in 1 .. 7:
    messages.add %*{"to": recipient, "text": ""}
  doAssert readPress(%*{"messages": messages}).len == 7
  messages.add %*{"to": 0, "text": ""}
  rejects:
    discard readPress(%*{"messages": messages})
  for bad in [newJNull(), newJObject(), %*{"messages": newJNull()},
    %*{"messages": [{"to": "1", "text": "Hi"}]},
    %*{"messages": [{"to": 8, "text": "Hi"}]},
    %*{"messages": [{"to": -1, "text": "Hi"}]},
    %*{"messages": [{"to": 1, "text": repeat("é", 301)}]},
    %*{"messages": [{"to": 1, "text": "\xff"}]},
    %*{"messages": [{"to": 1, "text": "Hi", "language": "English"}]}]:
      rejects:
        discard readPress(bad)
  let notes = %*{"updates": [{"op": "delete", "key": "old_plan"}]}
  let updates = readNotes(notes)
  doAssert updates == notes["updates"]
  updates[0]["key"] = %"changed"
  doAssert notes["updates"][0]["key"].getStr() == "old_plan"
  for bad in [newJNull(), newJObject(), %*{"updates": newJNull()},
    %*{"updates": [], "clear": true}]:
      rejects:
        discard readNotes(bad)
  let ongoing = readFinish(%*{"stop_spending": false, "reason": ""})
  doAssert not ongoing.stopSpending and ongoing.reason.len == 0
  let stopped = readFinish(%*{"stop_spending": true, "reason": "No units"})
  doAssert stopped.stopSpending and stopped.reason == "No units"
  discard readFinish(%*{
    "stop_spending": false,
    "reason": repeat("x", MaximumActionReasonBytes)
  })
  for bad in [newJNull(), newJObject(),
    %*{"stop_spending": "false", "reason": ""},
    %*{"stop_spending": false, "reason": newJNull()},
    %*{"stop_spending": true, "reason": " \t\n"},
    %*{"stop_spending": false, "reason": "\xff"},
    %*{"stop_spending": false,
      "reason": repeat("x", MaximumActionReasonBytes + 1)},
    %*{"stop_spending": false, "reason": "", "ready": true}]:
      rejects:
        discard readFinish(bad)

echo "Action argument checks passed"
