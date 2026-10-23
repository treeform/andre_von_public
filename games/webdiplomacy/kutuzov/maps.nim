import
  std/[json, strutils],
  common

const
  MaximumConnectionQueries* = 16
  MaximumConnectionBytes* = 24_000
  CatalogFields* = ["id", "name", "type", "supply", "homeCountryID",
    "coast", "coastParentID"]
  EdgeFields* = ["id", "army", "fleet"]

proc identifier(value: JsonNode): int {.raises: [KutuzovError].} =
  ## Read a positive native ID without coercing booleans or floating values.
  if value.isNil:
    raise newException(KutuzovError, "Map territory ID is absent")
  case value.kind
  of JInt:
    result = value.getInt
  of JString:
    let text = value.getStr
    if text.len == 0:
      raise newException(KutuzovError, "Map territory ID is empty")
    for character in text:
      if character notin {'0' .. '9'}:
        raise newException(KutuzovError, "Invalid map territory ID")
    try:
      result = parseInt(text)
    except ValueError:
      raise newException(KutuzovError, "Map territory ID is too large")
  else:
    raise newException(KutuzovError, "Map territory ID must be an integer")
  if result <= 0:
    raise newException(KutuzovError, "Map territory ID must be positive")

proc territories(variant: JsonNode): JsonNode {.raises: [KutuzovError].} =
  ## Validate native identities while retaining the original geometry in place.
  if variant.isNil or variant.kind != JObject or
    variant{"territories"}.isNil or
    variant{"territories"}.kind != JArray:
      raise newException(KutuzovError, "Variant needs a territory array")
  result = variant{"territories"}
  var seen: seq[int]
  for territory in result:
    if territory.kind != JObject:
      raise newException(KutuzovError, "Map territory must be an object")
    let id = identifier(territory{"id"})
    if id in seen:
      raise newException(KutuzovError, "Map contains duplicate territory IDs")
    seen.add id

proc indexFor(values, reference: JsonNode): int
    {.raises: [KutuzovError].} =
  ## Require one exact numeric identity or case-sensitive native name.
  if reference.isNil or reference.kind notin {JInt, JString}:
    raise newException(KutuzovError,
      "Territory reference must be an integer ID or exact name")
  let id =
    if reference.kind == JInt:
      identifier(reference)
    else:
      0
  if reference.kind == JString and reference.getStr.len == 0:
    raise newException(KutuzovError, "Territory name must not be empty")
  result = -1
  for index in 0 ..< values.len:
    let
      territory = values[index]
      name = territory{"name"}
      matches =
        if reference.kind == JInt:
          identifier(territory{"id"}) == id
        else:
          not name.isNil and name.kind == JString and
            name.getStr == reference.getStr
    if matches:
      if result >= 0:
        raise newException(KutuzovError, "Territory name is ambiguous")
      result = index
  if result < 0:
    raise newException(KutuzovError, "Territory ID or exact name was not found")

proc fields(
  source: JsonNode,
  names: openArray[string],
  absent: JsonNode,
  row: int
): JsonNode =
  ## Copy declared values while recording absent keys separately from null.
  result = newJArray()
  for column, name in names:
    let value = source{name}
    if value.isNil:
      result.add newJNull()
      absent.add %*[row, column]
    else:
      result.add value.copy()

proc catalog*(variant: JsonNode): JsonNode {.raises: [KutuzovError].} =
  ## Return the complete identity and coast catalog without adjacency lists.
  let
    values = territories(variant)
    absent = newJArray()
    rows = newJArray()
  result = newJObject()
  for name in ["name", "countries", "rules", "supplyCenterCount",
    "supplyCenterTarget"]:
      let value = variant{name}
      if not value.isNil:
        result[name] = value.copy()
  for index in 0 ..< values.len:
    rows.add fields(values[index], CatalogFields, absent, index)
  result["territory_fields"] = %CatalogFields
  result["territories"] = rows
  if absent.len > 0:
    result["territories_absent"] = absent

proc resolveTerritory*(variant, reference: JsonNode): int
    {.raises: [KutuzovError].} =
  ## Resolve a numeric ID or exact name without aliases or coast correction.
  let values = territories(variant)
  identifier(values[indexFor(values, reference)]{"id"})

proc edgeRows(values, borders, absent: JsonNode): JsonNode
    {.raises: [KutuzovError].} =
  ## Retain every edge in order with a validated destination in the catalog.
  if borders.kind != JArray:
    raise newException(KutuzovError, "Map borders must be an array or null")
  result = newJArray()
  for edge in borders:
    if edge.kind != JObject:
      raise newException(KutuzovError, "Map edge must be an object")
    let
      id = identifier(edge{"id"})
      source = newJObject()
    discard indexFor(values, %id)
    source["id"] = edge{"id"}.copy()
    for name in ["army", "fleet"]:
      let value = edge{name}
      if not value.isNil:
        if value.kind notin {JBool, JNull}:
          raise newException(KutuzovError,
            "Map army and fleet flags must be booleans or null")
        source[name] = value.copy()
    result.add fields(source, EdgeFields, absent, result.len)
    if ($result).len > MaximumConnectionBytes:
      raise newException(KutuzovError,
        "Connection facts exceed the byte limit; request fewer territories")

proc connections*(variant, references: JsonNode): JsonNode
    {.raises: [KutuzovError].} =
  ## Return bounded requested geometry without filtering, merging, or ranking.
  if references.isNil or references.kind != JArray:
    raise newException(KutuzovError, "Connections needs a reference array")
  if references.len == 0 or references.len > MaximumConnectionQueries:
    raise newException(KutuzovError,
      "Connections needs 1 to " & $MaximumConnectionQueries & " references")
  let values = territories(variant)
  result = %*{
    "territory_fields": CatalogFields,
    "edge_fields": EdgeFields,
    "territories": []
  }
  for reference in references:
    let
      territory = values[indexFor(values, reference)]
      absent = newJArray()
      unavailable = newJObject()
      item = %*{
        "territory": fields(territory, CatalogFields, absent, 0)
      }
    if absent.len > 0:
      item["territory_absent"] = absent
    for name in ["borders", "coastalBorders"]:
      let borders = territory{name}
      if borders.isNil:
        unavailable[name] = %"absent"
      elif borders.kind == JNull:
        item[name] = newJNull()
        unavailable[name] = %"null"
      else:
        let edgeAbsent = newJArray()
        item[name] = edgeRows(values, borders, edgeAbsent)
        if edgeAbsent.len > 0:
          item[name & "_absent"] = edgeAbsent
    if unavailable.len > 0:
      item["unavailable"] = unavailable
    result{"territories"}.add item
    if ($result).len > MaximumConnectionBytes:
      raise newException(KutuzovError,
        "Connection facts exceed the byte limit; request fewer territories")
