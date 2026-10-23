import
  std/[json, strutils, unicode],
  common, maps

const
  MaximumOrders* = 64
  MaximumConvoyRoute* = 64
  MaximumActionCheckBytes* = 800
  MaximumActionReasonBytes* = 1600
  AcceptedOrderTypes = [
    "Hold", "Move", "Support hold", "Support move", "Convoy", "Retreat",
    "Disband", "Build Army", "Build Fleet", "Destroy", "Wait"
  ]
  AcceptedOrderTypeNames = "\"" & AcceptedOrderTypes.join("\", \"") & "\""
  ActionsProtocol* = """
Tool arguments are strict JSON objects: include every named field, with no
extra fields. Territory references are positive integer IDs or exact,
case-sensitive names from the map catalog. No aliases or coast guesses.
board: {}.
connections: {"territories":["Vienna",21]} with 1..16 references.
commit_orders: {"orders":[{"type":"Hold","origin":"Vienna",
"destination":null,"supported_origin":null,"via_convoy":false,
"convoy_route":[]}],"center_check":"brief center assessment",
"support_check":"brief support/convoy consistency assessment"}.
Examples illustrate syntax, not recommended moves. Submit the complete
1..64-order set, not a patch. Both checks are strings of at most 800 UTF-8
bytes. Every order has all six fields. Unused locations must be null or 0;
unused convoy_route is []. via_convoy is a boolean, true only for a Move.
The exact case-sensitive accepted order types are:
""" & AcceptedOrderTypeNames & """.
"Support" is invalid. Choose "Support hold" or "Support move" explicitly.
Hold/Disband: origin only. Move/Retreat: origin and destination.
Support hold: origin is supporter; destination is the supported unit.
Support move/Convoy: origin is supporter/fleet, supported_origin is the moving
unit, destination is its destination. Build Army/Build Fleet/Destroy: origin
and destination must identify the same exact territory. Wait: all locations
null or 0; one Wait waives all unused build slots. No repeated origin IDs.
A convoyed Move and every Convoy require the complete explicitly chosen
convoy_route: [army origin, first fleet sea, ..., last fleet sea], excluding
destination. A Support move may supply that route when supporting a convoyed
army. Routes contain 2..64 distinct references; Convoy must include its own
fleet origin, while Support move must exclude its supporter. Every other
order has an empty route. Use the same route for the army and its fleets.
The server decides unit, coast, adjacency and other order legality. Missing
orders are never filled with Hold and invalid choices are never corrected.
send_press: {"messages":[{"to":2,"text":"short English or DAIDE"}]}.
Use 0..7 messages; each has exactly to (integer 0..7) and text (string of at
most 600 UTF-8 bytes). Recipient 0 is public. Runtime delivery caps still apply.
notes: {"updates":[{"op":"upsert","key":"north_defense","text":"..."},
{"op":"delete","key":"old_plan"}]}. Notes use the separate notes limits.
finish: {"stop_spending":false,"reason":""}. reason is a string of at most
1600 UTF-8 bytes, nonempty when stop_spending is true. Stopping ends future
model spending for the whole game, not just this phase.
"""

type
  CommitAction* = object
    orders*: JsonNode
    centerCheck*, supportCheck*: string

  FinishAction* = object
    stopSpending*: bool
    reason*: string

proc fields(
  value: JsonNode,
  expected: openArray[string],
  label: string
) {.raises: [KutuzovError].} =
  ## Require an exact object shape before reading any of its fields.
  if value.isNil or value.kind != JObject:
    raise newException(KutuzovError, label & " must be an object")
  if value.len != expected.len:
    raise newException(KutuzovError,
      label & " has missing or unknown fields")
  for field in expected:
    if not value.hasKey(field) or value{field}.isNil:
      raise newException(KutuzovError, label & " is missing " & field)

proc text(
  value: JsonNode,
  label: string,
  maximum: int
): string {.raises: [KutuzovError].} =
  ## Read bounded valid UTF-8 text without modifying the model's content.
  if value.isNil or value.kind != JString:
    raise newException(KutuzovError, label & " must be a string")
  result = value.getStr()
  if result.len > maximum or validateUtf8(result) >= 0:
    raise newException(KutuzovError,
      label & " exceeds its byte limit or is not valid UTF-8")

proc unused(value: JsonNode, label: string) {.raises: [KutuzovError].} =
  ## Require an explicit empty location instead of ignoring a supplied target.
  if value.isNil or not (value.kind == JNull or
      (value.kind == JInt and value.getInt() == 0)):
    raise newException(KutuzovError, label & " must be null or integer 0")

proc reference(
  variant, value: JsonNode,
  required: bool,
  label: string
): int {.raises: [KutuzovError].} =
  ## Resolve a used reference exactly and encode explicit unused values as zero.
  if required:
    result = resolveTerritory(variant, value)
  else:
    unused(value, label)

proc route(
  variant, value: JsonNode,
  origin, destination: int
): JsonNode {.raises: [KutuzovError].} =
  ## Translate an explicit convoy route without searching or altering it.
  if value.isNil or value.kind != JArray or
    value.len < 2 or value.len > MaximumConvoyRoute:
      raise newException(KutuzovError,
        "convoy_route needs 2 to 64 explicit territories")
  result = newJArray()
  var seen: seq[int]
  for item in value:
    let id = resolveTerritory(variant, item)
    if id in seen:
      raise newException(KutuzovError,
        "convoy_route repeats a territory")
    if id == destination:
      raise newException(KutuzovError,
        "convoy_route must exclude the destination")
    seen.add id
    result.add %id
  if seen[0] != origin:
    raise newException(KutuzovError,
      "convoy_route must start with the moving unit's origin")

proc readOrder(variant, value: JsonNode): JsonNode
    {.raises: [KutuzovError].} =
  ## Translate one complete named order without choosing or correcting moves.
  fields(value, ["type", "origin", "destination", "supported_origin",
    "via_convoy", "convoy_route"], "Order")
  let kind = text(value{"type"}, "Order type", 32)
  if kind notin AcceptedOrderTypes:
    raise newException(
      KutuzovError,
      "Unknown order type " & $(%kind) & ". Accepted values: " &
        AcceptedOrderTypeNames & "."
    )
  if value{"via_convoy"}.kind != JBool:
    raise newException(KutuzovError, "via_convoy must be a boolean")
  let
    via = value{"via_convoy"}.getBool()
    origin = reference(variant, value{"origin"}, kind != "Wait", "origin")
    destination = reference(
      variant,
      value{"destination"},
      kind notin ["Hold", "Disband", "Wait"],
      "destination"
    )
    supported = reference(
      variant,
      value{"supported_origin"},
      kind in ["Support move", "Convoy"],
      "supported_origin"
    )
    suppliedRoute = value{"convoy_route"}
  if via and kind != "Move":
    raise newException(KutuzovError, "via_convoy is true only for Move")
  if kind in ["Build Army", "Build Fleet", "Destroy"] and
    origin != destination:
      raise newException(KutuzovError,
        "Build and Destroy origin and destination must match exactly")
  if suppliedRoute.kind != JArray:
    raise newException(KutuzovError, "convoy_route must be an array")
  let routed = (kind == "Move" and via) or kind == "Convoy" or
    (kind == "Support move" and suppliedRoute.len > 0)
  if not routed and suppliedRoute.len > 0:
    raise newException(KutuzovError,
      "This order must have an empty convoy_route")
  result = %*{
    "type": kind, "terrID": origin, "toTerrID": destination,
    "fromTerrID": supported, "viaConvoy": (if via: "Yes" else: "No")
  }
  if routed:
    let path = route(
      variant,
      suppliedRoute,
      (if kind == "Move": origin else: supported),
      destination
    )
    var containsOrigin = false
    for item in path:
      if item.getInt() == origin:
        containsOrigin = true
    if kind == "Convoy" and not containsOrigin:
      raise newException(KutuzovError,
        "Convoy route must contain the issuing fleet's origin")
    if kind == "Support move" and containsOrigin:
      raise newException(KutuzovError,
        "Support move route must exclude the supporting unit")
    result["convoyPath"] = path

proc readBoard*(arguments: JsonNode) {.raises: [KutuzovError].} =
  ## Accept only the empty board-query argument object.
  fields(arguments, [], "board arguments")

proc readConnections*(variant, arguments: JsonNode): JsonNode
    {.raises: [KutuzovError].} =
  ## Resolve the complete bounded connection query to exact native IDs.
  fields(arguments, ["territories"], "connections arguments")
  let values = arguments{"territories"}
  if values.kind != JArray or values.len == 0 or
    values.len > MaximumConnectionQueries:
      raise newException(KutuzovError,
        "connections needs 1 to 16 territory references")
  result = newJArray()
  for value in values:
    result.add %resolveTerritory(variant, value)

proc readCommit*(variant, arguments: JsonNode): CommitAction
    {.raises: [KutuzovError].} =
  ## Translate one whole explicit order set or reject it without side effects.
  fields(arguments, ["orders", "center_check", "support_check"],
    "commit_orders arguments")
  result.centerCheck = text(arguments{"center_check"}, "center_check",
    MaximumActionCheckBytes)
  result.supportCheck = text(arguments{"support_check"}, "support_check",
    MaximumActionCheckBytes)
  let orders = arguments{"orders"}
  if orders.kind != JArray or orders.len == 0 or orders.len > MaximumOrders:
    raise newException(KutuzovError, "commit_orders needs 1 to 64 orders")
  result.orders = newJArray()
  var origins: seq[int]
  for value in orders:
    let
      order = readOrder(variant, value)
      origin = order{"terrID"}.getInt()
    if origin in origins:
      raise newException(KutuzovError,
        "Order origins must be distinct, including at most one Wait")
    origins.add origin
    result.orders.add order

proc readPress*(arguments: JsonNode): JsonNode
    {.raises: [KutuzovError].} =
  ## Validate the entire outgoing press batch before returning detached drafts.
  fields(arguments, ["messages"], "send_press arguments")
  let messages = arguments{"messages"}
  if messages.kind != JArray or messages.len > 7:
    raise newException(KutuzovError, "send_press accepts at most 7 messages")
  result = newJArray()
  for message in messages:
    fields(message, ["to", "text"], "Press message")
    if message{"to"}.kind != JInt or message{"to"}.getInt() notin 0 .. 7:
      raise newException(KutuzovError, "Press recipient must be integer 0..7")
    discard text(message{"text"}, "Press text", 600)
    result.add message.copy()

proc readNotes*(arguments: JsonNode): JsonNode
    {.raises: [KutuzovError].} =
  ## Read the exact notes wrapper for the separate bounded notes parser.
  fields(arguments, ["updates"], "notes arguments")
  if arguments{"updates"}.kind != JArray:
    raise newException(KutuzovError, "Note updates must be an array")
  arguments{"updates"}.copy()

proc readFinish*(arguments: JsonNode): FinishAction
    {.raises: [KutuzovError].} =
  ## Require an explicit stop decision with a bounded reason when stopping.
  fields(arguments, ["stop_spending", "reason"], "finish arguments")
  if arguments{"stop_spending"}.kind != JBool:
    raise newException(KutuzovError, "stop_spending must be a boolean")
  result.stopSpending = arguments{"stop_spending"}.getBool()
  result.reason = text(arguments{"reason"}, "Finish reason",
    MaximumActionReasonBytes)
  if result.stopSpending and strutils.strip(result.reason).len == 0:
    raise newException(KutuzovError, "Stopping requires a concrete reason")
