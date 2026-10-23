import
  std/[json, strutils],
  ../[common, maps]

const Fixture = staticRead("fixtures/italy_repair.json")

proc classic(): JsonNode =
  ## Restore the captured Classic geometry independently from the new module.
  let compact = parseJson(parseJson(Fixture)["map_text"].getStr)
  result = newJObject()
  for name, value in compact:
    if name notin ["territory_fields", "territories"]:
      result[name] = value.copy()
  result["territories"] = newJArray()
  for row in compact["territories"]:
    let territory = newJObject()
    for column in 0 ..< row.len:
      let name = compact["territory_fields"][column].getStr
      if name in ["borders", "coastalBorders"]:
        territory[name] = newJArray()
        for edge in row[column]:
          territory[name].add %*{
            "id": edge[0], "army": edge[1], "fleet": edge[2]
          }
      else:
        territory[name] = row[column].copy()
    result["territories"].add territory

proc selected(value: JsonNode, names: openArray[string]): JsonNode =
  ## Select expected source fields without filling missing keys.
  result = newJObject()
  for name in names:
    if value.hasKey(name):
      result[name] = value[name].copy()

proc expanded(fields, row: JsonNode, absent: JsonNode = nil,
    rowIndex = 0): JsonNode =
  ## Decode rows and their explicit missing-field coordinates independently.
  doAssert fields.len == row.len
  result = newJObject()
  for column in 0 ..< fields.len:
    var missing = false
    if not absent.isNil:
      for pair in absent:
        if pair[0].getInt == rowIndex and pair[1].getInt == column:
          missing = true
    if not missing:
      result[fields[column].getStr] = row[column].copy()

proc destination(variant: JsonNode, id: int): JsonNode =
  ## Locate an oracle destination without calling the production resolver.
  for territory in variant["territories"]:
    let native = territory["id"]
    let candidate =
      if native.kind == JString:
        parseInt(native.getStr)
      else:
        native.getInt
    if candidate == id:
      return territory
  doAssert false, "Missing Classic oracle destination"

proc joinedEdge(
  identities, edgeFields, row: JsonNode,
  absent: JsonNode = nil,
  rowIndex = 0
): JsonNode =
  ## Reconstruct exact destination facts from the public catalog and one edge.
  let
    edge = expanded(edgeFields, row, absent, rowIndex)
    native = edge["id"]
    id =
      if native.kind == JString:
        parseInt(native.getStr)
      else:
        native.getInt
  for index in 0 ..< identities["territories"].len:
    let
      target = expanded(identities["territory_fields"],
        identities["territories"][index],
        identities{"territories_absent"}, index)
      targetId = target["id"]
      candidate =
        if targetId.kind == JString:
          parseInt(targetId.getStr)
        else:
          targetId.getInt
    if candidate == id:
      result = selected(target, ["name", "type", "coast", "coastParentID"])
      for name, value in edge:
        result[name] = value.copy()
      return
  doAssert false, "Edge destination is absent from the public catalog"

template rejects(expression: untyped) =
  ## Require boundary failures to remain Kutuzov-specific exceptions.
  block:
    var rejected = false
    try:
      discard expression
    except KutuzovError:
      rejected = true
    doAssert rejected

echo "Testing complete Classic catalog without global adjacency"
block:
  let
    variant = classic()
    original = $variant
    result = catalog(variant)
  doAssert result["territories"].len == 81
  doAssert result["territory_fields"] == %CatalogFields
  doAssert "borders" notin $result
  doAssert "coastalBorders" notin $result
  doAssert ($result).len < 5_000
  for name in ["name", "countries", "rules", "supplyCenterCount",
    "supplyCenterTarget"]:
      doAssert result[name] == variant[name]
  for index in 0 ..< variant["territories"].len:
    let expected = selected(variant["territories"][index], CatalogFields)
    doAssert expanded(result["territory_fields"],
      result["territories"][index]) == expected
    doAssert resolveTerritory(variant, expected["id"]) ==
      expected["id"].getInt
    doAssert resolveTerritory(variant, expected["name"]) ==
      expected["id"].getInt
  result["rules"]["changed_local_copy"] = %true
  result["territories"][0].elems[1] = %"Changed local copy"
  doAssert $variant == original

echo "Testing every captured Classic edge and coast in bounded batches"
block:
  let
    variant = classic()
    original = $variant
    values = variant["territories"]
    identities = catalog(variant)
  var
    start = 0
    edgeCount = 0
    maximumBytes = 0
  while start < values.len:
    let references = newJArray()
    for index in start ..< min(values.len, start + MaximumConnectionQueries):
      references.add values[index]["id"].copy()
    let response = connections(variant, references)
    maximumBytes = max(maximumBytes, ($response).len)
    doAssert response["territories"].len == references.len
    doAssert response["edge_fields"] == %*["id", "army", "fleet"]
    for index in 0 ..< references.len:
      let
        expected = values[start + index]
        observed = response["territories"][index]
      doAssert expanded(response["territory_fields"],
        observed["territory"]) == selected(expected, CatalogFields)
      doAssert not observed.hasKey("unavailable")
      for name in ["borders", "coastalBorders"]:
        doAssert observed[name].len == expected[name].len
        for edgeIndex in 0 ..< expected[name].len:
          inc edgeCount
          let
            edge = expected[name][edgeIndex]
            target = destination(variant, edge["id"].getInt)
            facts = selected(target,
              ["name", "type", "coast", "coastParentID"])
          facts["id"] = edge["id"].copy()
          facts["army"] = edge["army"].copy()
          facts["fleet"] = edge["fleet"].copy()
          doAssert joinedEdge(identities, response["edge_fields"],
            observed[name][edgeIndex], observed{name & "_absent"},
            edgeIndex) == facts
    start += references.len
  doAssert edgeCount == 867
  doAssert maximumBytes <= MaximumConnectionBytes
  doAssert $variant == original
  let coasts = connections(variant, %*[8, "Spain (South Coast)", 8, 76])
  doAssert coasts["territories"].len == 4
  doAssert coasts["territories"][0]["territory"][0].getInt == 8
  doAssert coasts["territories"][1]["territory"][0].getInt == 77
  doAssert coasts["territories"][2] == coasts["territories"][0]
  doAssert coasts["territories"][3]["territory"][0].getInt == 76
  doAssert coasts["territories"][0]["borders"] !=
    coasts["territories"][0]["coastalBorders"]
  doAssert coasts["territories"][1]["borders"] !=
    coasts["territories"][3]["borders"]
  coasts["territories"][0]["borders"][0].elems[1] = %false
  doAssert $variant == original
  echo "Classic map: 81 territories, 867 exact edges, maximum batch bytes " &
    $maximumBytes

echo "Testing explicit unknown geometry, flags, and missing catalog fields"
block:
  let variant = %*{
    "name": "Nullable", "rules": newJNull(), "territories": [
      {"id": 1, "name": "Absent", "supply": newJNull(),
        "coastalBorders": newJNull()},
      {"id": "2", "name": "Empty", "coast": newJNull(),
        "borders": [], "coastalBorders": []},
      {"id": 3, "name": "Flags", "borders": [
        {"id": 2, "army": newJNull()},
        {"id": "2", "army": false, "fleet": false},
        {"id": 2, "army": true, "fleet": false},
        {"id": 2, "army": false, "fleet": true},
        {"id": 2, "army": true, "fleet": true}]}]
  }
  let
    original = $variant
    result = catalog(variant)
    response = connections(variant, %*[1, 2, 3])
    absent = response["territories"][0]
    empty = response["territories"][1]
    flags = response["territories"][2]
  doAssert result["rules"].kind == JNull
  doAssert not result.hasKey("countries")
  for index in 0 ..< 3:
    doAssert expanded(result["territory_fields"],
      result["territories"][index], result["territories_absent"], index) ==
      selected(variant["territories"][index], CatalogFields)
  doAssert not absent.hasKey("borders")
  doAssert absent["coastalBorders"].kind == JNull
  doAssert absent["unavailable"] == %*{
    "borders": "absent", "coastalBorders": "null"
  }
  doAssert empty["borders"].len == 0 and empty["coastalBorders"].len == 0
  doAssert not empty.hasKey("unavailable")
  for index in 0 ..< 5:
    let
      edge = variant["territories"][2]["borders"][index]
      facts = joinedEdge(result, response["edge_fields"],
        flags["borders"][index], flags["borders_absent"], index)
      expected = selected(destination(variant, 2),
        ["name", "type", "coast", "coastParentID"])
    for name, value in edge:
      expected[name] = value.copy()
    doAssert facts == expected
    doAssert facts["id"] == edge["id"]
    doAssert facts["coast"].kind == JNull
    doAssert not facts.hasKey("coastParentID")
    doAssert not facts.hasKey("type")
    doAssert facts["army"] == variant["territories"][2]["borders"][index]["army"]
    if index == 0:
      doAssert facts["army"].kind == JNull
      doAssert not facts.hasKey("fleet")
    else:
      doAssert facts["fleet"] ==
        variant["territories"][2]["borders"][index]["fleet"]
  doAssert $variant == original

echo "Testing exact reference errors, invalid geometry, and result limits"
block:
  let variant = classic()
  for reference in [newJNull(), %true, %1.5, %0, %(-1), %900,
    %"", %"spain", %"SPA", %"STP/NC", %"8"]:
      rejects(resolveTerritory(variant, reference))
      rejects(connections(variant, %*[reference]))
  for invalid in [nil, newJNull(), newJArray(), %*{},
    %*{"territories": newJNull()}, %*{"territories": [newJNull()]},
    %*{"territories": [{"id": newJNull()}]}]:
      rejects(catalog(invalid))
      rejects(resolveTerritory(invalid, %1))
  let
    duplicate = classic()
    ambiguous = classic()
    unknown = classic()
    unknownCoast = classic()
    malformed = classic()
    oversized = classic()
    numeric = classic()
  duplicate["territories"][1]["id"] = %1
  rejects(catalog(duplicate))
  ambiguous["territories"][1]["name"] = %"Clyde"
  rejects(resolveTerritory(ambiguous, %"Clyde"))
  doAssert resolveTerritory(ambiguous, %2) == 2
  unknown["territories"][0]["borders"][0]["id"] = %900
  rejects(connections(unknown, %*[1]))
  unknownCoast["territories"][0]["coastalBorders"][0]["id"] = %900
  rejects(connections(unknownCoast, %*[1]))
  malformed["territories"][0]["borders"][0]["army"] = %1
  rejects(connections(malformed, %*[1]))
  oversized["territories"][0]["name"] = %repeat("X", 24_001)
  rejects(connections(oversized, %*[1]))
  numeric["territories"][1]["id"] = %"2"
  numeric["territories"][0]["borders"][0]["id"] = %"2"
  doAssert resolveTerritory(numeric, %2) == 2
  let
    numericCatalog = catalog(numeric)
    numericLookup = connections(numeric, %*[1])
    numericEdge = numericLookup["territories"][0]["borders"][0]
  doAssert numericEdge[0] == %"2"
  doAssert joinedEdge(numericCatalog, numericLookup["edge_fields"],
    numericEdge)["id"] == %"2"
  rejects(connections(variant, nil))
  rejects(connections(variant, newJArray()))
  let tooMany = newJArray()
  for index in 0 .. MaximumConnectionQueries:
    tooMany.add %1
  rejects(connections(variant, tooMany))

echo "Map facts tests passed"
