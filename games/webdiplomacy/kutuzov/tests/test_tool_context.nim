import
  std/[json, os, strutils],
  ../[briefings, budgets, common, engines, maps, notes, protocols, requests]

const Fixture = staticRead("fixtures/italy_repair.json")

proc classic(): JsonNode =
  ## Expand the archived map so real catalog and lookup producers are tested.
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

proc snapshot(state: BotState, limits: BudgetConfig): JsonNode =
  ## Combine a captured complete position with production tool-state fields.
  let
    fixture = parseJson(Fixture)
    context = %*{
      "game": {"turn": 15, "phase": "Diplomacy", "processTime": 1000},
      "orders": {"orders": fixture["current_input"]["order_slots"]}
    }
    projected = observation(
      GameConfig(gameId: 1, countryId: 3, endYear: 1908),
      context,
      %*{"units": [], "territories": [], "members": []},
      %*{"phases": []},
      PressContext(messages: newJArray()),
      state,
      limits,
      "review"
    )
  result = fixture["current_input"].copy()
  for field in ["strategic_notes", "tool_delivery", "known_connections",
      "tool_wake"]:
    result[field] = projected[field].copy()

echo "Testing tool notes and geometry through delta and full rebase"
block:
  let
    variant = classic()
    config = RequestConfig(
      api: ChatApi, model: DefaultHostedModel,
      reasoningEffort: "low", maxOutputTokens: 3000
    )
    instructions = ToolPolicy & "\nMAP CATALOG JSON:\n" & $catalog(variant)
  var
    limits = defaultBudgetConfig()
    state = BotState(
      gameId: 1, countryId: 3, toolLoop: true,
      phase: PhaseState(stamp: "15:Diplomacy", transcript: newJArray())
    )
    references = newJArray()
    updates: seq[NoteUpdate]
  limits.toolLoop = true
  limits.maxPhaseCalls = 12
  limits.maxPressCalls = 1
  for i in 0 ..< 5:
    references.add variant["territories"][i]["id"]
  state.phase.lookupFacts = %*{
    "source": "latest_connections_lookup",
    "connections": connections(variant, references)
  }
  for i in 0 ..< 1:
    updates.add NoteUpdate(
      kind: Upsert, key: "note_" & $i,
      text: (if i == 0: "Build a fleet in St. Petersburg to defend BAR."
        else: repeat("x", MaxNoteTextBytes))
    )
  state.notes.applyNoteUpdates(updates, "13:Diplomacy", "repair:7021",
    "gpt-6.1-sol")
  let
    input = state.snapshot(limits)
    full = prepareInput(config, instructions, input, state.phase, limits)
    original = parseJson(full.text)
  doAssert full.requestBytes <= 60_000, $full.requestBytes
  doAssert original["strategic_notes"] == notesView(state.notes)
  doAssert original["known_connections"]["facts"] == state.phase.lookupFacts
  state.phase.recordExchange(full.text, "{\"calls\":[]}",
    %*{"results": []}, limits)
  let
    delta = prepareInput(config, instructions, input, state.phase, limits)
    update = parseJson(delta.text)
  doAssert not delta.rebased
  doAssert update["phase_update"].getBool
  doAssert update["strategic_notes"] == original["strategic_notes"]
  doAssert not update.hasKey("known_connections")
  state.phase.transcript = %*[
    {"role": "user", "content": repeat("X", 60_001)}
  ]
  let
    rebased = prepareInput(config, instructions, input, state.phase, limits)
    rebasedInput = parseJson(rebased.text)
  doAssert rebased.rebased and rebased.transcript.len == 0
  doAssert rebased.requestBytes <= 60_000
  for field in ["board", "order_slots", "saved_orders", "strategic_notes",
      "known_connections", "tool_delivery", "tool_wake"]:
    doAssert rebasedInput[field] == original[field], field
  state.notes.applyNoteUpdates([], "15:Diplomacy", "review:7185", "gpt-6-luna")
  doAssert notesView(state.notes) == original["strategic_notes"]
  for i in 5 ..< 16:
    references.add variant["territories"][i]["id"]
  state.phase.lookupFacts["connections"] = connections(variant, references)
  updates.setLen(0)
  for i in 1 ..< MaxNotes:
    updates.add NoteUpdate(kind: Upsert, key: "note_" & $i,
      text: repeat("x", MaxNoteTextBytes))
  state.notes.applyNoteUpdates(updates, "15:Diplomacy", "review:2",
    "gpt-6.1-sol")
  let
    stressInput = state.snapshot(limits)
    stress = prepareInput(config, instructions, stressInput, state.phase, limits)
  doAssert stress.rebased and stress.requestBytes <= 60_000
  doAssert parseJson(stress.text)["strategic_notes"] == notesView(state.notes)
  doAssert parseJson(stress.text)["known_connections"]["facts"] ==
    state.phase.lookupFacts
  echo "Tool context guarded bytes: full=", full.requestBytes,
    ", delta=", delta.requestBytes, ", maximum notes/lookup=", stress.requestBytes

echo "Testing persistent tool mode and note provenance after restart"
block:
  let
    path = getTempDir() / ("kutuzov-tool-context-" &
      $getCurrentProcessId() & ".json")
    game = GameConfig(gameId: 1, countryId: 7)
  defer:
    for name in [path, path & ".tmp"]:
      if fileExists(name):
        removeFile(name)
  var state = restore(game, path, EmpiricalBudget, true)
  state.notes.applyNoteUpdates(
    [NoteUpdate(kind: Upsert, key: "winter_defense", text: "Defend STP.")],
    "13:Diplomacy", "repair:7021", "gpt-6.1-sol"
  )
  state.phase = PhaseState(stamp: "13:Builds", transcript: newJArray())
  state.persist(path)
  let restored = restore(game, path, EmpiricalBudget, true)
  doAssert restored.toolLoop
  doAssert restored.notes == state.notes
  doAssert restored.notes[0].originPhase == "13:Diplomacy"
  var rejected = false
  try:
    discard restore(game, path, EmpiricalBudget, false)
  except KutuzovError:
    rejected = true
  doAssert rejected, "Same-game restoration must not mix protocols"

echo "Tool context checks passed"
