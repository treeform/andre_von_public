import
  std/[json, os, strutils],
  ../[budgets, common, engines, logs, prompts, protocols, requests]
from std/unicode import validateUtf8

const Fixture = staticRead("fixtures/italy_repair.json")

proc requestConfig(): RequestConfig =
  ## Prepare local serialized requests without a provider endpoint.
  RequestConfig(
    api: ChatApi, model: DefaultHostedModel,
    reasoningEffort: "low", maxOutputTokens: 3000
  )

proc initial(fixture: JsonNode): BotState =
  ## Retain the exact last verified Italy state before the failed final review.
  let verified = fixture["verified_state"]
  BotState(
    gameId: 1, countryId: 3,
    memory: verified["memory"].getStr,
    memoryStamp: verified["memory_phase"].getStr,
    memoryDelivery: verified["memory_delivery"].copy(),
    phase: PhaseState(
      stamp: "15:Diplomacy", calls: 2,
      savedOrders: verified["saved_orders"].copy(),
      transcript: newJArray()
    )
  )

proc exactOrders(attempt, orders: JsonNode) =
  ## Compare every present semantic field and distinguish missing from null.
  doAssert attempt["orders_complete"].getBool
  doAssert attempt["order_fields"] == %RepairOrderFields
  doAssert attempt["orders"].len == orders.len
  doAssert attempt["original_order_count"].getInt == orders.len
  var absent = newJArray()
  for i in 0 ..< orders.len:
    for j, name in RepairOrderFields:
      if orders[i].hasKey(name):
        doAssert attempt["orders"][i][j] == orders[i][name]
      else:
        doAssert attempt["orders"][i][j].kind == JNull
        absent.add %*[i, j]
  if absent.len > 0:
    doAssert attempt["order_absent"] == absent
  else:
    doAssert not attempt.hasKey("order_absent")

proc unchanged(input, original: JsonNode) =
  ## Protect current board truth and last verified strategic facts.
  for field in [
    "board", "order_slots", "saved_orders", "memory", "memory_phase",
    "memory_delivery", "outgoing_press"
  ]:
    doAssert input[field] == original[field], "Changed " & field

proc current(fixture: JsonNode, phase: PhaseState): JsonNode =
  ## Add only the production repair projection to the captured full input.
  result = fixture["current_input"].copy()
  result["repair_attempt"] = phase.repairView()

proc cleanup(path: string) =
  ## Remove only the persistence files belonging to this fixture.
  for name in [path, path & ".tmp"]:
    if fileExists(name):
      removeFile(name)

echo "Testing Italy rejected review across restart and full rebase"
block:
  let
    fixture = parseJson(Fixture)
    decision = readDecision($fixture["rejected_decision"])
    failure = newException(
      KutuzovOrderError, fixture["failure"]["error"].getStr
    )
    original = fixture["current_input"]
    path = getTempDir() / ("kutuzov-repair-state-" &
      $getCurrentProcessId() & ".json")
    game = GameConfig(gameId: 1, countryId: 3)
    config = requestConfig()
    limits = defaultBudgetConfig()
    instructions = Policy & "\nMAP JSON:\n" & fixture["map_text"].getStr
  var state = initial(fixture)
  state.phase.captureRepairAttempt(decision, "review", failure)
  let attempt = state.phase.repairView()
  doAssert attempt["phase"].getStr == "15:Diplomacy"
  doAssert attempt["call"].getInt == 2
  doAssert attempt["source_task"].getStr == "review"
  doAssert attempt["outcome"].getStr == "rejected"
  doAssert attempt["needs_repair"].getBool
  doAssert attempt["candidate_memory"]["unverified"].getBool
  doAssert attempt["candidate_memory"]["text"].getStr == decision.memory
  exactOrders(attempt, decision.orders)
  doAssert state.memory == original["memory"].getStr
  doAssert state.memory != decision.memory
  doAssert state.phase.savedOrders == original["saved_orders"]
  doAssert state.phase.savedOrders != original["order_slots"]
  doAssert state.memoryDelivery == original["memory_delivery"]
  defer:
    cleanup(path)
  state.persist(path)
  var restarted = restore(game, path)
  doAssert restarted.phase.repairView() == attempt
  let
    input = fixture.current(restarted.phase)
    full = prepareInput(config, instructions, input, restarted.phase, limits)
  doAssert full.requestBytes <= 60_000
  unchanged(parseJson(full.text), original)
  exactOrders(parseJson(full.text)["repair_attempt"], decision.orders)
  restarted.phase.transcript = %*[
    {"role": "user", "content": full.text},
    {"role": "assistant", "content": repeat("X", 60_001)}
  ]
  let
    rebased = prepareInput(
      config, instructions, input, restarted.phase, limits
    )
    fresh = parseJson(rebased.text)
  doAssert rebased.rebased and rebased.transcript.len == 0
  doAssert rebased.requestBytes <= 60_000
  unchanged(fresh, original)
  doAssert fresh["repair_attempt"] == attempt
  doAssert restarted.phase.repairView() == attempt
  restarted.phase.transcript = %*[
    {"role": "user", "content": full.text}
  ]
  let
    delta = prepareInput(config, "rules", input, restarted.phase, limits)
    update = parseJson(delta.text)
  doAssert not delta.rebased and update["phase_update"].getBool
  doAssert update["repair_attempt"] == attempt
  doAssert update["memory_delivery"] == original["memory_delivery"]
  doAssert update["order_slots"] == original["order_slots"]
  doAssert update["saved_orders"] == original["saved_orders"]

echo "Testing repair bounds, exact convoys, UTF-8, and detached views"
block:
  let fixture = parseJson(Fixture)
  var
    phase = initial(fixture).phase
    decision = readDecision($fixture["rejected_decision"])
  decision.orders[0]["convoyPath"] = %*[16, 63, 68]
  decision.orders[1]["convoyPath"] = newJNull()
  decision.orders[2]["ignored_metadata"] = %"Not an order field."
  for text in [repeat("é船", 150), repeat("\"\\\x01", 400)]:
    decision.memory = text
    phase.captureRepairAttempt(
      decision, "repair", newException(KutuzovOrderError, text)
    )
    let attempt = phase.repairView()
    exactOrders(attempt, decision.orders)
    doAssert repairBytes(attempt) <= RepairAttemptWireLimit
    for name in ["candidate_memory", "error"]:
      let excerpt = attempt[name]["text"].getStr
      doAssert validateUtf8(excerpt) == -1
      doAssert text.startsWith(excerpt)
      doAssert ($(%($(%excerpt)))).len <= RepairTextWireLimit
      doAssert attempt[name]["text_truncated"].getBool
      doAssert attempt[name]["original_text_bytes"].getInt == text.len
    let detached = phase.repairView()
    detached["orders"][0].elems[0] = %"Changed local view."
    doAssert phase.repairView()["orders"][0][0] == decision.orders[0]["type"]
  registerSecret("repair-fixture-secret")
  decision.memory = "repair-fixture-secret https://example.invalid/private"
  phase.captureRepairAttempt(decision, "repair", newException(
    KutuzovOrderError, "Authorization: Bearer repair-fixture-secret"
  ))
  doAssert "repair-fixture-secret" notin $phase.repairView()
  doAssert "example.invalid" notin $phase.repairView()
  decision.orders[0]["convoyPath"] = newJArray()
  for i in 0 ..< 5000:
    decision.orders[0]["convoyPath"].add %i
  phase.captureRepairAttempt(
    decision, "repair", newException(KutuzovOrderError, "Invalid route.")
  )
  let unavailable = phase.repairView()
  doAssert not unavailable["orders_complete"].getBool
  doAssert not unavailable.hasKey("orders")
  doAssert not unavailable.hasKey("order_fields")
  doAssert not unavailable.hasKey("order_absent")
  doAssert unavailable["orders_unavailable_reason"].getStr ==
    "representation_limit"
  doAssert unavailable["original_order_count"].getInt == 7
  doAssert repairBytes(unavailable) <= RepairAttemptWireLimit
  decision.orders = nil
  phase.captureRepairAttempt(
    decision, "repair", newException(KutuzovOrderError, "No array.")
  )
  doAssert phase.repairView()["original_order_count"].getInt == 0
  doAssert not phase.repairView()["orders_complete"].getBool

echo "Testing explicit last-resort repair table omission and request guard"
block:
  let
    fixture = parseJson(Fixture)
    decision = readDecision($fixture["rejected_decision"])
    config = requestConfig()
  var
    phase = initial(fixture).phase
    limits = defaultBudgetConfig()
  phase.captureRepairAttempt(
    decision, "review", newException(KutuzovOrderError, "Rejected route.")
  )
  let
    input = fixture.current(phase)
    exact = input.copy()
    minimal = input.copy()
    attempt = minimal["repair_attempt"]
  input["recent_history"] = %*[{"source": repeat("H", 1500)}]
  input["press"] = %*[{"text": repeat("P", 1500)}]
  minimal["recent_history"] = newJArray()
  minimal["history_trimmed"] = %true
  minimal["press"] = newJArray()
  minimal["omitted_messages"] = %(input["omitted_messages"].getInt + 1)
  for name in ["candidate_memory", "error"]:
    attempt[name]["original_text_bytes"] = %attempt[name]["text"].getStr.len
    attempt[name]["text"] = %""
    attempt[name]["text_truncated"] = %true
  for name in ["order_fields", "orders", "order_absent"]:
    if attempt.hasKey(name):
      attempt.delete(name)
  attempt["orders_complete"] = %false
  attempt["orders_unavailable_reason"] = %"request_context_limit"
  limits.maxContextBytes = ($config.buildRequest("rules", $minimal)).len + 512
  let
    prepared = prepareInput(config, "rules", input, phase, limits)
    fresh = parseJson(prepared.text)
  doAssert prepared.requestBytes <= limits.maxContextBytes
  doAssert fresh == minimal
  doAssert input["repair_attempt"] == exact["repair_attempt"]
  doAssert phase.repairView() == exact["repair_attempt"]
  unchanged(fresh, exact)
  let oversized = input.copy()
  oversized["board"]["required_fixture_context"] = %repeat("B", 60_001)
  limits.maxContextBytes = 60_000
  let
    rejected = prepareInput(config, "rules", oversized, phase, limits)
    rejectedInput = parseJson(rejected.text)
    admission = chooseCall(
      config, Budget(), limits, "rules", rejected.text,
      transcript = rejected.transcript
    )
  doAssert rejected.requestBytes > 60_000
  doAssert not admission.allowed
  doAssert rejectedInput["board"] == oversized["board"]
  doAssert rejectedInput.hasKey("repair_attempt")

echo "Testing repair routing, limits, legacy state, and phase replacement"
block:
  let
    fixture = parseJson(Fixture)
    decision = readDecision($fixture["rejected_decision"])
    limits = defaultBudgetConfig()
    press = PressContext(messages: newJArray())
    path = getTempDir() / ("kutuzov-repair-legacy-" &
      $getCurrentProcessId() & ".json")
    config = GameConfig(gameId: 1, countryId: 3)
  var phase = initial(fixture).phase
  let rejected = newException(KutuzovHttpError, "Game HTTP 400.")
  rejected.source = GameAction
  rejected.status = 400
  rejected.orderSubmission = true
  rejected.reason = "Unknown territory ID `14` for country `3`."
  phase.captureRepairAttempt(decision, "plan", rejected)
  phase.feedback = ""
  doAssert phase.nextTask("Diplomacy", press, limits, 300, 60, 100) == "repair"
  doAssert phase.repairView()["error"]["text"].getStr == rejected.reason
  doAssert phase.nextTask("Diplomacy", press, limits, 40, 60, 100) == "ready"
  phase.calls = limits.maxPhaseCalls
  doAssert phase.nextTask("Diplomacy", press, limits, 300, 60, 100) == "ready"
  phase.calls = 2
  for source in [GameAction, PlayerContext, PublicAsset]:
    for status in [400, 500]:
      for actualOrders in [false, true]:
        let failure = newException(KutuzovHttpError, "Game HTTP error.")
        failure.source = source
        failure.status = status
        failure.orderSubmission = actualOrders
        phase.captureRepairAttempt(decision, "review", failure)
        let needsRepair = source == GameAction and status == 400 and
          actualOrders
        doAssert phase.repairView()["needs_repair"].getBool == needsRepair
        doAssert phase.repairView()["outcome"].getStr ==
          (if needsRepair: "rejected" else: "unconfirmed")
        if not needsRepair:
          doAssert phase.feedback.len == 0
          doAssert phase.nextTask(
            "Diplomacy", press, limits, 300, 60, 100
          ) == "wait"
  phase.captureRepairAttempt(
    decision, "repair", newException(KutuzovError, "Game transport failed.")
  )
  doAssert not phase.repairView()["needs_repair"].getBool
  doAssert phase.repairView()["source_task"].getStr == "repair"
  phase.stamp = "15:Retreats"
  doAssert phase.repairView().kind == JNull
  phase = PhaseState(stamp: "15:Retreats")
  doAssert phase.repairAttempt.isNil
  defer:
    cleanup(path)
  writeFile(path, $(%*{
    "gameId": 1, "countryId": 3,
    "phase": {"stamp": "15:Diplomacy", "savedOrders": []}
  }))
  let legacy = restore(config, path)
  doAssert legacy.phase.repairAttempt.isNil
  doAssert legacy.phase.repairView().kind == JNull

echo "Repair context tests passed"
