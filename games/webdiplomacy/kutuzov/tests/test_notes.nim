import
  std/[json, strutils],
  jsony,
  ../[common, notes]

const
  StpDefense = "French Barents threatens St Petersburg: consider a " &
    "northern fleet build there this winter."
  SolModel = "openai/gpt-6.1-sol"
  LunaModel = "openai/gpt-6-luna"

template expectNotesError(body: untyped) =
  ## Require a domain exception rather than silent coercion or data loss.
  block:
    var failed = false
    try:
      body
    except KutuzovError:
      failed = true
    doAssert failed, "Expected KutuzovError"

proc upsert(key, text: string): NoteUpdate =
  ## Construct an explicit model update without supplying host provenance.
  NoteUpdate(kind: Upsert, key: key, text: text)

echo "Testing retained model notes and explicit replacement"
block:
  var stored: seq[StrategicNote]
  stored.applyNoteUpdates(
    [upsert("north_defense", StpDefense)],
    "13:Diplomacy",
    "repair:7021",
    SolModel
  )
  let original = stored.notesView()
  # The v110 repeat lost this intention after a same-order Luna review.
  stored.applyNoteUpdates([], "13:Diplomacy", "review:7185", LunaModel)
  doAssert stored.notesView() == original
  stored.applyNoteUpdates([], "13:Builds", "plan:7413", LunaModel)
  doAssert stored.notesView() == original
  doAssert original["source"].getStr == "model_claims"
  doAssert original["notes"][0]["origin_phase"].getStr == "13:Diplomacy"
  doAssert original["notes"][0]["origin_decision"].getStr == "repair:7021"
  doAssert stored[0].originModel == SolModel
  stored.applyNoteUpdates(
    [upsert("southern_plan", "Keep the agreed border this autumn.")],
    "13:Diplomacy",
    "update:1",
    SolModel
  )
  doAssert stored[0].text == StpDefense
  doAssert stored[0].originDecision == "repair:7021"
  stored.applyNoteUpdates(
    [upsert("north_defense", "Build decision changed explicitly.")],
    "13:Builds",
    "notes:2",
    LunaModel
  )
  doAssert stored.len == 2
  doAssert stored[0].text == "Build decision changed explicitly."
  doAssert stored[0].originPhase == "13:Builds"
  doAssert stored[0].originModel == LunaModel
  stored.applyNoteUpdates(
    [NoteUpdate(kind: Delete, key: "north_defense")],
    "14:Diplomacy",
    "notes:3",
    SolModel
  )
  doAssert stored.len == 1 and stored[0].key == "southern_plan"
  let retained = stored.notesView()
  stored.applyNoteUpdates(
    [NoteUpdate(kind: Delete, key: "missing")],
    "14:Diplomacy",
    "notes:4",
    SolModel
  )
  doAssert stored.notesView() == retained

echo "Testing strict model update parsing"
block:
  let parsed = parseNoteUpdates("""[
    {"op":"upsert","key":"north_defense","text":"Keep STP safe."},
    {"op":"delete","key":"expired_deal"}
  ]""")
  doAssert parsed.len == 2
  doAssert parsed[0] == upsert("north_defense", "Keep STP safe.")
  doAssert parsed[1].kind == Delete
  doAssert parseNoteUpdates(newJArray()).len == 0
  doAssert parseNoteUpdates(JsonNode(nil)).len == 0
  var nilItem = newJArray()
  nilItem.add JsonNode(nil)
  expectNotesError:
    discard parseNoteUpdates(nilItem)
  for malformed in [
    "{", "null", "{}", "[1]",
    """[{"op":"replace","key":"a","text":"x"}]""",
    """[{"op":"upsert","key":1,"text":"x"}]""",
    """[{"op":"upsert","key":"a","text":false}]""",
    """[{"op":"upsert","key":"a"}]""",
    """[{"op":"delete","key":"a","text":"x"}]""",
    """[{"op":"upsert","key":"a","text":"x","origin_phase":"0:Diplomacy"}]""",
    """[{"op":"delete","key":"a"},{"op":"upsert","key":"a","text":"x"}]"""
  ]:
    expectNotesError:
      discard parseNoteUpdates(malformed)

echo "Testing atomic rejection and byte bounds"
block:
  var stored: seq[StrategicNote]
  stored.applyNoteUpdates(
    [upsert("north_defense", StpDefense)],
    "13:Diplomacy",
    "repair:7021",
    SolModel
  )
  let original = stored.notesView()
  expectNotesError:
    stored.applyNoteUpdates(
      [NoteUpdate(kind: Delete, key: "north_defense"),
        upsert("new_plan", repeat("x", MaxNoteTextBytes + 1))],
      "14:Diplomacy",
      "bad:1",
      SolModel
    )
  doAssert stored.notesView() == original
  expectNotesError:
    stored.applyNoteUpdates(
      [upsert("north_defense", "Changed"), upsert("north_defense", "Again")],
      "14:Diplomacy",
      "bad:2",
      SolModel
    )
  doAssert stored.notesView() == original
  for badKey in ["", "North", "north defense", "2north", repeat("a", 33)]:
    expectNotesError:
      stored.applyNoteUpdates(
        [upsert(badKey, "Changed")], "14:Diplomacy", "bad:3", SolModel
      )
    doAssert stored.notesView() == original
  for badText in ["", " \n\t", "\xff", repeat("é", 257)]:
    expectNotesError:
      stored.applyNoteUpdates(
        [upsert("north_defense", badText)],
        "14:Diplomacy",
        "bad:4",
        SolModel
      )
    doAssert stored.notesView() == original
  expectNotesError:
    stored.applyNoteUpdates(
      [upsert("north_defense", "Changed")], "", "bad:5", SolModel
    )
  expectNotesError:
    stored.applyNoteUpdates(
      [upsert("north_defense", "Changed")], "14:Diplomacy", "", SolModel
    )
  expectNotesError:
    stored.applyNoteUpdates(
      [upsert("north_defense", "Changed")], "14:Diplomacy", "bad:6", ""
    )
  expectNotesError:
    stored.applyNoteUpdates(
      [upsert("north_defense", "Changed")],
      repeat("x", MaxNotePhaseBytes + 1),
      "bad:6",
      SolModel
    )
  expectNotesError:
    stored.applyNoteUpdates(
      [upsert("north_defense", "Changed")],
      "14:Diplomacy",
      repeat("x", MaxNoteDecisionBytes + 1),
      SolModel
    )
  expectNotesError:
    stored.applyNoteUpdates(
      [upsert("north_defense", "Changed")],
      "14:Diplomacy",
      "bad:6",
      repeat("x", MaxNoteModelBytes + 1)
    )
  expectNotesError:
    stored.applyNoteUpdates(
      [NoteUpdate(kind: Delete, key: "north_defense", text: "unexpected")],
      "14:Diplomacy",
      "bad:6",
      SolModel
    )
  doAssert stored.notesView() == original
  var tooMany: seq[NoteUpdate]
  for i in 0 ..< MaxNotes:
    tooMany.add upsert("extra_" & $i, "Another model claim.")
  expectNotesError:
    stored.applyNoteUpdates(tooMany, "14:Diplomacy", "bad:7", SolModel)
  doAssert stored.notesView() == original
  var escaped: seq[NoteUpdate]
  for i in 0 ..< MaxNotes:
    escaped.add upsert("note_" & $i, "x" & repeat("\n", MaxNoteTextBytes - 1))
  var empty: seq[StrategicNote]
  expectNotesError:
    empty.applyNoteUpdates(escaped, "14:Diplomacy", "bad:8", SolModel)
  doAssert empty.len == 0
  empty.applyNoteUpdates(
    [upsert(repeat("a", MaxNoteKeyBytes), repeat("é", 256))],
    "14:Diplomacy",
    "good:1",
    SolModel
  )
  doAssert empty[0].text.len == MaxNoteTextBytes
  doAssert ($empty.notesView()).len <= MaxNotesEncodedBytes

echo "Testing full-capacity replacement without intermediate data loss"
block:
  var
    stored: seq[StrategicNote]
    initial: seq[NoteUpdate]
  for i in 0 ..< MaxNotes:
    initial.add upsert("note_" & $i, repeat("x", MaxNoteTextBytes))
  stored.applyNoteUpdates(initial, "13:Diplomacy", "notes:1", SolModel)
  doAssert stored.len == MaxNotes
  doAssert ($stored.notesView()).len <= MaxNotesEncodedBytes
  stored.applyNoteUpdates(
    [upsert("replacement", "An explicitly chosen new claim."),
      NoteUpdate(kind: Delete, key: "note_0")],
    "14:Diplomacy",
    "notes:2",
    SolModel
  )
  doAssert stored.len == MaxNotes
  doAssert stored[0].key == "note_1"
  doAssert stored[^1].key == "replacement"
  let original = stored.notesView()
  var updates: seq[NoteUpdate]
  for i in 0 .. MaxNoteUpdates:
    updates.add NoteUpdate(kind: Delete, key: "note_" & $i)
  expectNotesError:
    stored.applyNoteUpdates(updates, "14:Diplomacy", "bad:1", SolModel)
  doAssert stored.notesView() == original
  expectNotesError:
    discard parseNoteUpdates(repeat(" ", MaxNoteUpdateBytes) & "[]")
  expectNotesError:
    discard parseNotes(repeat(" ", MaxNotesEncodedBytes) & "[]")

echo "Testing strict persistence and visible historical provenance"
block:
  var stored: seq[StrategicNote]
  stored.applyNoteUpdates(
    [upsert("north_defense", StpDefense)],
    "13:Diplomacy",
    "repair:7021",
    SolModel
  )
  doAssert parseNotes(stored.notesView()) == stored
  doAssert parseNotes($stored.notesView()) == stored
  doAssert parseNotes(stored.toJson()) == stored
  doAssert parseNotes(JsonNode(nil)).len == 0
  doAssert parseNotes(newJNull()).len == 0
  doAssert parseNotes("[]").len == 0
  expectNotesError:
    discard parseNotes("{")
  expectNotesError:
    discard parseNotes(%*{"source": "host_verified", "notes": []})
  expectNotesError:
    discard parseNotes(%*{"source": "model_claims", "notes": {}})
  expectNotesError:
    discard parseNotes(%*[{"key": "north_defense", "text": StpDefense}])
  var duplicate = stored
  duplicate.add stored[0]
  expectNotesError:
    validateNotes(duplicate)
  var corrupt = stored
  corrupt[0].originDecision = ""
  expectNotesError:
    discard corrupt.notesView()
  doAssert stored[0].originDecision == "repair:7021"

echo "Strategic note tests passed"
