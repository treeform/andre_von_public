import
  std/json

const
  Fixture = staticRead("fixtures/columnar-board.json")
  TopFields = ["turn", "phase", "turnText", "pressType", "gameOver"]
  UnitFields = ["id", "countryID", "type", "terrID", "retreating"]
  TerritoryFields = ["terrID", "ownerCountryID", "unitID",
    "retreatingUnitID", "standoff", "occupiedFromTerrID"]
  MemberFields = ["countryID", "country", "status", "supplyCenterNo",
    "unitNo"]

proc boardFixture*(): JsonNode =
  ## Load selected public positions from the recorded seven-power game.
  parseJson(Fixture)

proc copyFields(value: JsonNode, fields: openArray[string]): JsonNode =
  ## Preserve selected source keys including explicit null values.
  result = newJObject()
  for field in fields:
    if value.hasKey(field):
      result[field] = value[field]

proc objectBoard*(board: JsonNode): JsonNode =
  ## Reproduce the previous object representation independently of compaction.
  result = copyFields(board, TopFields)
  for collection in ["units", "territories", "members"]:
    result[collection] = newJArray()
    let values = board{collection}
    if values.isNil or values.kind != JArray:
      continue
    for value in values:
      case collection
      of "units":
        result[collection].add copyFields(value, UnitFields)
      of "territories":
        result[collection].add copyFields(value, TerritoryFields)
      of "members":
        result[collection].add copyFields(value, MemberFields)
      else:
        doAssert false

proc absent(board: JsonNode, collection: string, row, column: int): bool =
  ## Find a missing source key in the sparse coordinate list.
  let coordinates = board{collection & "_absent"}
  if coordinates.isNil:
    return false
  for coordinate in coordinates:
    if coordinate[0].getInt == row and coordinate[1].getInt == column:
      return true

proc restoreRows(
  board: JsonNode,
  collection: string,
  selected: openArray[string]
): JsonNode =
  ## Restore original fields while dropping derived display labels.
  let fields = board[collection & "_fields"]
  result = newJArray()
  for i in 0 ..< board[collection].len:
    let row = board[collection][i]
    doAssert row.len == fields.len
    var value = newJObject()
    for j in 0 ..< selected.len:
      doAssert fields[j].getStr == selected[j]
      if board.absent(collection, i, j):
        doAssert row[j].kind == JNull
      else:
        value[selected[j]] = row[j]
    result.add value

proc restoredBoard*(board: JsonNode): JsonNode =
  ## Decode each original semantic field and its precise key presence.
  result = copyFields(board, TopFields)
  result["units"] = restoreRows(board, "units", UnitFields)
  result["territories"] = restoreRows(board, "territories", TerritoryFields)
  result["members"] = restoreRows(board, "members", MemberFields)

proc named(variant: JsonNode, collection, field: string,
    id: JsonNode): JsonNode =
  ## Resolve a display name by exact source ID without folding coasts.
  result = newJNull()
  if variant.isNil or id.isNil:
    return
  let values = variant{collection}
  if values.isNil:
    return
  for value in values:
    if value{field} == id:
      return value["name"]

proc assertPosition*(original, compact: JsonNode, variant: JsonNode = nil) =
  ## Verify all original fields, source presence and optional display names.
  doAssert restoredBoard(compact) == objectBoard(original)
  doAssert compact["units_fields"] == %*[
    "id", "countryID", "type", "terrID", "retreating", "countryName",
    "territoryName"
  ]
  doAssert compact["territories_fields"] == %*[
    "terrID", "ownerCountryID", "unitID", "retreatingUnitID", "standoff",
    "occupiedFromTerrID", "territoryName"
  ]
  doAssert compact["members_fields"] == %MemberFields
  for collection in ["units", "territories", "members"]:
    let coordinates = compact{collection & "_absent"}
    if not coordinates.isNil:
      doAssert coordinates.kind == JArray and coordinates.len > 0
      var seen: seq[string]
      for coordinate in coordinates:
        doAssert coordinate.kind == JArray and coordinate.len == 2
        let
          row = coordinate[0].getInt
          column = coordinate[1].getInt
        doAssert row >= 0 and row < compact[collection].len
        doAssert column >= 0
        doAssert column < (if collection == "territories": 6 else: 5)
        doAssert $coordinate notin seen
        seen.add $coordinate
        let field = compact[collection & "_fields"][column].getStr
        doAssert not original[collection][row].hasKey(field)
        doAssert compact[collection][row][column].kind == JNull
    for i in 0 ..< compact[collection].len:
      let row = original[collection][i]
      case collection
      of "units":
        doAssert compact[collection][i][5] ==
          named(variant, "countries", "countryID", row{"countryID"})
        doAssert compact[collection][i][6] ==
          named(variant, "territories", "id", row{"terrID"})
      of "territories":
        doAssert compact[collection][i][6] ==
          named(variant, "territories", "id", row{"terrID"})
      else:
        discard
