import
  std/[json, strutils],
  ../prompts,
  boards

proc expand(fields, row: JsonNode): JsonNode =
  ## Restore a compact row to check every field against the upstream fixture.
  doAssert fields.len == row.len
  result = newJObject()
  for i in 0 ..< fields.len:
    result[fields[i].getStr] = row[i]

echo "Testing lossless map and history compaction"
block:
  let
    border = %*{"id": 79, "army": false, "fleet": true}
    territory = %*{
      "id": 78, "name": "St. Petersburg (North Coast)", "type": "Coast",
      "supply": false, "homeCountryID": 7, "coast": "Child",
      "coastParentID": 20, "borders": [border], "coastalBorders": []
    }
    variant = %*{
      "name": "Classic", "countries": [{"countryID": 7, "name": "Russia"}],
      "rules": {}, "supplyCenterCount": 34, "supplyCenterTarget": 18,
      "territories": [territory]
    }
    compact = compactMap(variant)
  var restored = expand(compact["territory_fields"], compact["territories"][0])
  doAssert restored["borders"] == %*[[79, false, true]]
  restored["borders"] = %*[border]
  doAssert restored == territory
  for field in ["name", "countries", "rules", "supplyCenterCount",
    "supplyCenterTarget"]:
      doAssert compact[field] == variant[field]
  let order = %*{
    "countryID": 7, "terrID": 78, "unitType": "Fleet", "type": "Move",
    "toTerrID": 79, "fromTerrID": newJNull(), "viaConvoy": false,
    "success": false, "dislodged": true
  }
  var history = %*{"phases": []}
  for i in 0 ..< 6:
    history["phases"].add %*{
      "turn": i, "phase": "Diplomacy", "orders": [order]
    }
  let recent = recentHistory(history)
  doAssert recent.len == 4
  doAssert recent[0]["turn"].getInt == 2
  doAssert recent[3]["turn"].getInt == 5
  for phase in recent:
    doAssert expand(phase["order_fields"], phase["orders"][0]) == order
  doAssert recentHistory(nil).len == 0

echo "Testing complete retreat observations without unrelated metadata"
block:
  let
    territory = %*{
      "terrID": 6, "ownerCountryID": 1, "unitID": 9912,
      "retreatingUnitID": 9913, "standoff": true, "occupiedFromTerrID": 5
    }
    unit = %*{
      "id": 9912, "countryID": 1, "type": "Fleet", "terrID": 6,
      "retreating": true
    }
    member = %*{
      "countryID": 1, "country": "England", "status": "Playing",
      "supplyCenterNo": 5, "unitNo": 5
    }
  var rawMember = parseJson($member)
  rawMember["user"] = %*{"username": "irrelevant identity"}
  let board = compactBoard(%*{
    "turn": 7, "phase": "Retreats", "units": [unit],
    "territories": [territory], "members": [rawMember],
    "files": {"private": "do-not-copy"}, "apiKey": "do-not-copy"
  })
  assertPosition(
    %*{"turn": 7, "phase": "Retreats", "units": [unit],
      "territories": [territory], "members": [member]},
    board
  )
  for field in ["units_absent", "territories_absent", "members_absent"]:
    doAssert not board.hasKey(field)
  doAssert not board.hasKey("files")
  doAssert not board.hasKey("apiKey")
  doAssert "BOTH terrID and toTerrID" in Policy

echo "Testing recorded positions, ownership, retreats, and exact coast names"
block:
  let
    fixture = boardFixture()
    variant = fixture["variant"]
  var
    coast = false
    retreat = false
    standoff = false
    owner = false
    occupied = false
    unoccupied = false
  for sample in fixture["boards"]:
    let
      original = sample["board"]
      compact = compactBoard(original, variant)
      restored = restoredBoard(compact)
    assertPosition(original, compact, variant)
    assertPosition(original, compactBoard(original))
    for i in 0 ..< restored["units"].len:
      let unit = restored["units"][i]
      if unit["terrID"].getInt == 79:
        coast = true
        doAssert compact["units"][i][6].getStr ==
          "St. Petersburg (South Coast)"
        doAssert unit["terrID"].getInt != 32
      retreat = retreat or unit["retreating"].getBool
    for territory in restored["territories"]:
      standoff = standoff or territory["standoff"].getBool
      owner = owner or territory["ownerCountryID"].getInt > 0
      occupied = occupied or territory["occupiedFromTerrID"].kind == JInt
      unoccupied = unoccupied or
        territory["occupiedFromTerrID"].kind == JNull
  doAssert coast and retreat and standoff and owner and occupied and unoccupied

echo "Testing absent keys, explicit nulls, unknown labels, and both coasts"
block:
  let
    fixture = boardFixture()
    variant = fixture["variant"]
    original = %*{
      "turn": 9, "phase": "Retreats", "gameOver": newJNull(),
      "units": [
        {"id": 1, "countryID": 7, "type": "Fleet", "terrID": 78,
          "retreating": newJNull()},
        {"id": 2, "countryID": 999, "type": "Army", "terrID": 999},
        {"id": 3, "countryID": 7, "type": "Fleet", "terrID": 79,
          "retreating": false}
      ],
      "territories": [
        {"terrID": 78, "ownerCountryID": 7, "unitID": 1,
          "retreatingUnitID": newJNull(), "standoff": false,
          "occupiedFromTerrID": newJNull()},
        {"terrID": 79, "ownerCountryID": 7, "unitID": 3,
          "standoff": true, "occupiedFromTerrID": 51}
      ],
      "members": [
        {"countryID": 7, "country": newJNull(), "status": "Playing",
          "supplyCenterNo": 4, "unitNo": 3},
        {"countryID": 999, "status": "Playing", "supplyCenterNo": 0,
          "unitNo": 0}
      ]
    }
    compact = compactBoard(original, variant)
  assertPosition(original, compact, variant)
  doAssert compact["units_absent"] == %*[[1, 4]]
  doAssert compact["territories_absent"] == %*[[1, 3]]
  doAssert compact["members_absent"] == %*[[1, 1]]
  doAssert compact["units"][0][6].getStr == "St. Petersburg (North Coast)"
  doAssert compact["units"][2][6].getStr == "St. Petersburg (South Coast)"
  doAssert compact["units"][1][5].kind == JNull
  doAssert compact["units"][1][6].kind == JNull
  doAssert compact["gameOver"].kind == JNull
  doAssert not compact.hasKey("turnText")
  let empty = compactBoard(%*{})
  assertPosition(%*{}, empty)
  for collection in ["units", "territories", "members"]:
    doAssert empty[collection].len == 0
    doAssert not empty.hasKey(collection & "_absent")

echo "Testing string identifiers retain their original representation"
block:
  let
    variant = boardFixture()["variant"]
    original = %*{
      "units": [{"id": "20", "countryID": "7", "type": "Fleet",
        "terrID": "79", "retreating": false}],
      "territories": [], "members": []
    }
    compact = compactBoard(original, variant)
  doAssert restoredBoard(compact) == objectBoard(original)
  doAssert compact["units"][0][0] == %"20"
  doAssert compact["units"][0][1] == %"7"
  doAssert compact["units"][0][3] == %"79"
  doAssert compact["units"][0][5] == %"Russia"
  doAssert compact["units"][0][6] == %"St. Petersburg (South Coast)"

echo "Prompt compaction tests passed"
