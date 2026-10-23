import
  std/[json, net, os, strutils, times],
  jsony,
  ../[budgets, common, engines, protocols, requests]
from std/unicode import runeLenAt, validateUtf8

const
  SeatSecret = "local-delivery-fixture-seat"
  ContextRoute = "/api.php?route=game/playercontext&gameID=704" &
    "&orders=1&messages=1"
  Correction = "Correction: Serbia supports Rumania-Bulgaria."

type
  DeliveryCase = enum
    ConfirmedSend, AmbiguousSend, MalformedSend, ChangedPhase,
    ExpiredDeadline, ContextFailure, PersistenceFailure,
    ConfirmationPersistenceFailure

  Scenario = tuple[
    server: Socket, path, decisionId: string, kind: DeliveryCase
  ]

proc context(
  turn = 11,
  phase = "Diplomacy",
  pressType = "Regular",
  remaining = 300
): JsonNode =
  ## Supply a private context with a live deadline and explicit press mode.
  %*{
    "game": {"turn": turn, "phase": phase, "pressType": pressType,
      "processTime": int(epochTime()) + remaining},
    "orders": {"orders": []}
  }

proc config(country = 3, endpoint = "http://127.0.0.1:1"): GameConfig =
  ## Use a local endpoint that cannot accidentally contact a game service.
  GameConfig(
    url: endpoint, apiKey: SeatSecret, gameId: 704, countryId: country,
    endYear: 1908, scoring: "sum_of_squares", timeoutSeconds: 2
  )

proc initial(country = 3): BotState =
  ## Keep existing decisions and call counts visible through press handling.
  BotState(
    gameId: 704, countryId: country,
    phase: PhaseState(
      stamp: "11:Diplomacy", calls: 3, pressCalls: 1,
      reviewed: true, updatesStopped: true,
      savedOrders: %*[{"type": "Hold", "terrID": 1,
        "toTerrID": 0, "fromTerrID": 0, "viaConvoy": "No"}]
    )
  )

proc statePath(name: string): string =
  ## Give each delivery case an independent temporary persistence file.
  getTempDir() / ("kutuzov-deliveries-" & name & "-" &
    $getCurrentProcessId() & ".json")

proc cleanup(path: string) =
  ## Remove only the state files created by the current local fixture.
  for candidate in [path, path & ".tmp"]:
    if fileExists(candidate):
      removeFile(candidate)
    elif dirExists(candidate):
      removeDir(candidate)

proc draft(recipient = 5, text = Correction): JsonNode =
  ## Return one bounded model draft without claiming it was sent.
  %*[{"to": recipient, "text": text}]

proc outcome(
  outcomes: JsonNode,
  index, recipient: int,
  text, status, reason: string
) =
  ## Require an indexed delivery fact for the exact recipient and draft.
  let value = outcomes[index]
  doAssert value["index"].getInt == index
  doAssert value["to"].getInt == recipient
  doAssert value["text"].getStr == text
  doAssert value["status"].getStr == status
  doAssert value["reason"].getStr == reason

proc recipient(availability: JsonNode, country: int): JsonNode =
  ## Find an explicit destination without depending on presentation order.
  for entry in availability["recipients"]:
    if entry["to"].getInt == country:
      return entry
  doAssert false, "Missing destination " & $country

proc observed(state: BotState, current: JsonNode): JsonNode =
  ## Exercise the production observation with a compact complete board.
  let board = %*{
    "turn": current["game"]["turn"],
    "phase": current["game"]["phase"],
    "units": [], "territories": [], "members": []
  }
  observation(
    config(state.countryId),
    current,
    board,
    %*{"phases": []},
    PressContext(messages: newJArray()),
    state,
    defaultBudgetConfig(),
    "review"
  )

proc refuseReplay(
  game: GameConfig,
  state: var BotState,
  current, messages: JsonNode,
  path, decisionId: string
) =
  ## Reject an already attempted decision before any network or file change.
  let
    before = state.memoryDelivery.copy()
    saved = readFile(path)
    attempts = state.phase.sent
  var refused = false
  try:
    discard game.dispatchPress(current, messages, state, path, decisionId)
  except KutuzovError as error:
    doAssert error.msg ==
      "Press facts do not belong to this pending movement decision"
    refused = true
  doAssert refused
  doAssert state.memoryDelivery == before
  doAssert state.phase.sent == attempts
  doAssert readFile(path) == saved

proc boundedView(view, durable: JsonNode) =
  ## Check encoded limits and intact facts without assuming an ASCII boundary.
  doAssert view["decision_id"] == durable["decision_id"]
  doAssert view["phase"] == durable["phase"]
  doAssert view["outcomes"].len == durable["outcomes"].len
  for i in 0 ..< view["outcomes"].len:
    let
      fact = view["outcomes"][i]
      original = durable["outcomes"][i]["text"].getStr
      excerpt = fact["text"].getStr
      encoded = $(%($(%excerpt)))
    doAssert original.startsWith(excerpt)
    doAssert validateUtf8(excerpt) == -1
    doAssert encoded.len <= 640
    doAssert parseJson(parseJson(encoded).getStr).getStr == excerpt
    for key in ["index", "to", "status", "reason"]:
      doAssert fact[key] == durable["outcomes"][i][key]
    if excerpt.len < original.len:
      doAssert fact["text_truncated"].getBool
      doAssert fact["original_text_bytes"].getInt == original.len
      let nextEnd = excerpt.len + original.runeLenAt(excerpt.len)
      doAssert ($(%($(%original[0 ..< nextEnd])))).len > 640
    else:
      doAssert not fact.hasKey("text_truncated")
      doAssert not fact.hasKey("original_text_bytes")

proc serve(args: Scenario) {.thread.} =
  ## Inspect durable attempts before returning a bounded local HTTP result.
  defer:
    args.server.close()
  let expected =
    if args.kind in [ChangedPhase, ExpiredDeadline]:
      1
    elif args.kind in [ContextFailure, ConfirmationPersistenceFailure]:
      3
    else:
      2
  for i in 0 ..< expected:
    var client: Socket
    args.server.accept(client)
    defer:
      client.close()
    let line = client.recvLine(timeout = 2000)
    var
      length = 0
      authorization = ""
    while true:
      let header = client.recvLine(timeout = 2000)
      if header.len == 0 or header == "\r\n":
        break
      if header.toLowerAscii.startsWith("authorization:"):
        authorization = header.split(':', 1)[1].strip()
      if header.toLowerAscii.startsWith("content-length:"):
        length = parseInt(header.split(':', 1)[1].strip())
    var body = ""
    while body.len < length:
      let chunk = client.recv(length - body.len, timeout = 2000)
      doAssert chunk.len > 0
      body.add(chunk)
    let done = (args.kind == PersistenceFailure and i == 1) or
      (args.kind == ConfirmationPersistenceFailure and i == 2)
    if done:
      doAssert line == "GET /fixture-done HTTP/1.1"
      doAssert authorization.len == 0
    else:
      doAssert authorization == "Bearer " & SeatSecret
    var
      response: JsonNode
      status = 200
    if i == 0:
      doAssert line == "GET " & ContextRoute & " HTTP/1.1"
      case args.kind
      of ChangedPhase:
        response = context(12)
      of ExpiredDeadline:
        response = context(remaining = 10)
      of PersistenceFailure:
        createDir(args.path & ".tmp")
        response = context()
      else:
        response = context()
    elif done:
      response = %*{"done": true}
    elif i == 2:
      doAssert args.kind == ContextFailure
      doAssert line == "GET " & ContextRoute & " HTTP/1.1"
      let saved = readFile(args.path).fromJson(BotState)
      saved.memoryDelivery["outcomes"].outcome(
        0, 5, Correction, "confirmed", "confirmed"
      )
      doAssert saved.phase.sent == @["5:" & Correction]
      status = 500
      response = %*{"error": "Fixture context unavailable."}
    else:
      doAssert line == "POST /api.php?route=game/sendmessage HTTP/1.1"
      let
        payload = body.fromJson(JsonNode)
        saved = readFile(args.path).fromJson(BotState)
      doAssert payload["gameID"].getInt == 704
      doAssert payload["countryID"].getInt == 3
      doAssert payload["toCountryID"].getInt == 5
      doAssert payload["message"].getStr == Correction
      doAssert saved.phase.sent == @["5:" & Correction]
      doAssert saved.phase.calls == 3 and saved.phase.pressCalls == 1
      doAssert saved.memoryDelivery["decision_id"].getStr == args.decisionId
      saved.memoryDelivery["outcomes"].outcome(
        0, 5, Correction, "unconfirmed", "send_outcome_unknown"
      )
      let
        game = config(endpoint = "http://127.0.0.1:" &
          $args.server.getLocalAddr()[1])
        messages = newJArray()
      var recovered = restore(game, args.path)
      for fact in recovered.memoryDelivery["outcomes"]:
        messages.add %*{"to": fact["to"], "text": fact["text"]}
      doAssert recovered.memoryDelivery == saved.memoryDelivery
      # The refusal guard exits before shared logging or network code.
      {.cast(gcsafe).}:
        refuseReplay(
          game, recovered, context(), messages, args.path, args.decisionId
        )
      recovered.memoryDelivery["outcomes"].outcome(
        0, 5, Correction, "unconfirmed", "send_outcome_unknown"
      )
      if args.kind == AmbiguousSend:
        status = 500
        response = %*{"error": "Fixture send outcome is unknown."}
      else:
        if args.kind == ConfirmationPersistenceFailure:
          createDir(args.path & ".tmp")
        response = %*{"success": true}
    let encoded =
      if args.kind == MalformedSend and i == 1:
        "{invalid-send-response"
      else:
        $response
    client.send(
      "HTTP/1.1 " & $status & " Fixture\r\n" &
      "Content-Type: application/json\r\nConnection: close\r\n" &
      "Content-Length: " & $encoded.len & "\r\n\r\n" & encoded
    )

proc testDispatch(kind: DeliveryCase) =
  ## Exercise delivery, fresh context guards, and restart without providers.
  let
    path = statePath($kind)
    server = newSocket()
    current = context()
    messages = draft()
  if kind == ContextFailure:
    messages.add %*{"to": 7, "text": "Keep the reciprocal defense."}
    messages.add %*{"to": 1, "text": "No new commitment."}
  cleanup(path)
  defer:
    cleanup(path)
  server.bindAddr(Port(0), "127.0.0.1")
  server.listen()
  let game = config(endpoint = "http://127.0.0.1:" &
    $server.getLocalAddr()[1])
  var state = initial()
  state.rememberMovement(current, "Preserve the final plan.", messages)
  let decisionId = state.memoryDelivery["decision_id"].getStr
  state.persist(path)
  let before = readFile(path)
  var worker: Thread[Scenario]
  createThread(worker, serve, (server, path, decisionId, kind))
  var
    delivered: PressDelivery
    failed = false
  try:
    delivered = game.dispatchPress(current, messages, state, path, decisionId)
  except KutuzovHttpError as error:
    doAssert kind == ContextFailure
    doAssert error.status == 500 and error.source == PlayerContext
    failed = true
  except KutuzovError as error:
    doAssert kind in [PersistenceFailure, ConfirmationPersistenceFailure]
    doAssert error.msg == "Cannot persist Kutuzov state"
    failed = true
  if kind == ConfirmationPersistenceFailure:
    doAssert failed
    state.memoryDelivery["outcomes"].outcome(
      0, 5, Correction, "confirmed", "confirmed"
    )
    doAssert state.phase.sent == @["5:" & Correction]
    var recovered = restore(game, path)
    recovered.memoryDelivery["outcomes"].outcome(
      0, 5, Correction, "unconfirmed", "send_outcome_unknown"
    )
    doAssert recovered.phase.sent == @["5:" & Correction]
    doAssert recovered.phase.calls == 3 and recovered.phase.pressCalls == 1
    removeDir(path & ".tmp")
    refuseReplay(game, recovered, current, messages, path, decisionId)
    recovered.rememberMovement(current, "Restarted verified plan.", messages)
    let nextId = recovered.memoryDelivery["decision_id"].getStr
    doAssert nextId != decisionId
    recovered.persist(path)
    let duplicate = game.dispatchPress(
      current, messages, recovered, path, nextId
    )
    duplicate.outcomes.outcome(0, 5, Correction, "skipped", "duplicate")
    doAssert duplicate.confirmed.len == 0
    doAssert recovered.phase.sent == @["5:" & Correction]
    doAssert restore(game, path).memoryDelivery == recovered.memoryDelivery
    state.memoryDelivery["outcomes"].outcome(
      0, 5, Correction, "confirmed", "confirmed"
    )
  if kind in [PersistenceFailure, ConfirmationPersistenceFailure]:
    let client = newSocket()
    defer:
      client.close()
    client.connect("127.0.0.1", server.getLocalAddr()[1])
    client.send(
      "GET /fixture-done HTTP/1.1\r\nHost: localhost\r\n" &
      "Connection: close\r\n\r\n"
    )
    doAssert client.recvLine(timeout = 2000).startsWith("HTTP/1.1 200")
  joinThread(worker)
  if kind == ConfirmationPersistenceFailure:
    return
  if kind == PersistenceFailure:
    doAssert failed
    doAssert readFile(path) == before
    let recovered = restore(game, path)
    doAssert recovered.phase.sent.len == 0
    recovered.memoryDelivery["outcomes"].outcome(
      0, 5, Correction, "pending", "not_attempted"
    )
    return
  if kind == ContextFailure:
    doAssert failed
    let recovered = restore(game, path)
    doAssert recovered.phase.sent == @["5:" & Correction]
    doAssert recovered.memoryDelivery == state.memoryDelivery
    recovered.memoryDelivery["outcomes"].outcome(
      0, 5, Correction, "confirmed", "confirmed"
    )
    recovered.memoryDelivery["outcomes"].outcome(
      1, 7, "Keep the reciprocal defense.", "pending", "context_unavailable"
    )
    recovered.memoryDelivery["outcomes"].outcome(
      2, 1, "No new commitment.", "pending", "context_unavailable"
    )
    doAssert recovered.phase.calls == 3 and recovered.phase.pressCalls == 1
    doAssert recovered.phase.reviewed and recovered.phase.updatesStopped
    return
  doAssert not failed
  let
    status =
      case kind
      of ConfirmedSend: "confirmed"
      of AmbiguousSend, MalformedSend: "unconfirmed"
      else: "skipped"
    reason =
      case kind
      of ConfirmedSend: "confirmed"
      of AmbiguousSend, MalformedSend: "send_error"
      of ChangedPhase: "phase_changed"
      of ExpiredDeadline: "deadline"
      else: ""
  delivered.outcomes.outcome(0, 5, Correction, status, reason)
  doAssert delivered.confirmed.len == ord(kind == ConfirmedSend)
  doAssert state.memoryDelivery["outcomes"] == delivered.outcomes
  doAssert state.phase.calls == 3 and state.phase.pressCalls == 1
  doAssert state.phase.reviewed and state.phase.updatesStopped
  doAssert state.phase.savedOrders == initial().phase.savedOrders
  var recovered = restore(game, path)
  doAssert recovered.memoryDelivery == state.memoryDelivery
  doAssert recovered.phase.sent == state.phase.sent
  let saved = readFile(path)
  var refused = false
  try:
    discard game.dispatchPress(
      current, messages, recovered, path, decisionId
    )
  except KutuzovError:
    refused = true
  doAssert refused
  doAssert readFile(path) == saved
  doAssert recovered.memoryDelivery == state.memoryDelivery
  if kind in [ConfirmedSend, AmbiguousSend, MalformedSend]:
    doAssert recovered.phase.sent == @["5:" & Correction]
    recovered.rememberMovement(current, "A later verified plan.", messages)
    let nextId = recovered.memoryDelivery["decision_id"].getStr
    doAssert nextId != decisionId
    recovered.persist(path)
    let duplicate = game.dispatchPress(
      current, messages, recovered, path, nextId
    )
    doAssert duplicate.confirmed.len == 0
    duplicate.outcomes.outcome(0, 5, Correction, "skipped", "duplicate")
    doAssert recovered.phase.sent.len == 1
    doAssert restore(game, path).memoryDelivery["outcomes"] ==
      duplicate.outcomes
  else:
    doAssert recovered.phase.sent.len == 0

echo "Testing movement delivery identity and bounded companion facts"
block:
  let
    current = context()
    messages = draft()
  var state = initial()
  state.rememberMovement(current, "Verified memory.", messages)
  let first = state.memoryDelivery.copy()
  doAssert first["decision_id"].getStr.len > 0
  doAssert first["phase"].getStr == "11:Diplomacy"
  doAssert first["outcomes"].len == 1
  first["outcomes"].outcome(0, 5, Correction, "pending", "not_attempted")
  state.rememberMovement(context(11, "Retreats"), "Retreat memory.", draft(7))
  state.rememberMovement(context(11, "Builds"), "Build memory.", draft(7))
  doAssert state.memory == "Verified memory."
  doAssert state.memoryStamp == "11:Diplomacy"
  doAssert state.memoryDelivery == first
  state.rememberMovement(current, "Verified memory.", messages)
  doAssert state.memoryDelivery["decision_id"] != first["decision_id"]
  state.rememberMovement(current, "Verified without drafts.", newJArray())
  doAssert state.memoryDelivery["outcomes"].len == 0
  state.rememberMovement(current, "Legacy provenance is unknown.")
  doAssert state.memoryDelivery.isNil
  let before = state
  for invalid in [%*[{"to": 5, "text": repeat("x", 601)}],
    %*[{"to": 0, "text": "a"}, {"to": 1, "text": "a"},
      {"to": 2, "text": "a"}, {"to": 3, "text": "a"},
      {"to": 4, "text": "a"}, {"to": 5, "text": "a"},
      {"to": 6, "text": "a"}, {"to": 7, "text": "a"}]]:
      var rejected = false
      try:
        state.rememberMovement(current, "Invalid replacement.", invalid)
      except KutuzovError:
        rejected = true
      doAssert rejected
      doAssert state.memory == before.memory
      doAssert state.memoryStamp == before.memoryStamp
      doAssert state.memoryDelivery.isNil
      doAssert state.memorySerial == before.memorySerial

echo "Testing T11 limits, exact duplicates, and explicit press restrictions"
block:
  let path = statePath("skips")
  cleanup(path)
  defer:
    cleanup(path)
  for pair in [(sender: 3, recipient: 5), (sender: 5, recipient: 3),
    (sender: 5, recipient: 7)]:
      let
        game = config(pair.sender)
        current = context()
        messages = draft(pair.recipient)
      var state = initial(pair.sender)
      state.phase.sent = @[$pair.recipient & ":Earlier proposal.",
        $pair.recipient & ":Earlier update."]
      state.rememberMovement(current, "Final correction drafted.", messages)
      let decisionId = state.memoryDelivery["decision_id"].getStr
      state.persist(path)
      let delivery = game.dispatchPress(
        current, messages, state, path, decisionId
      )
      doAssert delivery.confirmed.len == 0
      delivery.outcomes.outcome(
        0, pair.recipient, Correction, "skipped", "recipient_limit"
      )
      doAssert state.phase.sent.len == 2
      doAssert restore(game, path).memoryDelivery["outcomes"] ==
        delivery.outcomes
  for reason in ["duplicate", "self_recipient", "no_press", "public_only"]:
    let
      game = config()
      target = (if reason == "self_recipient": 3 else: 5)
      pressType =
        case reason
        of "no_press": "NoPress"
        of "public_only": "PublicPressOnly"
        else: "Regular"
      current = context(pressType = pressType)
      messages = draft(target)
    var state = initial()
    if reason == "duplicate":
      state.phase.sent = @["5:" & Correction]
    let count = state.phase.sent.len
    state.rememberMovement(current, "Verified decision.", messages)
    state.persist(path)
    let delivery = game.dispatchPress(
      current, messages, state, path,
      state.memoryDelivery["decision_id"].getStr
    )
    delivery.outcomes.outcome(0, target, Correction, "skipped", reason)
    doAssert delivery.confirmed.len == 0
    doAssert state.phase.sent.len == count
    doAssert restore(game, path).memoryDelivery["outcomes"] ==
      delivery.outcomes

echo "Testing stale decision identities cannot change another memory"
block:
  let
    path = statePath("stale")
    game = config()
    current = context()
    messages = draft()
  cleanup(path)
  defer:
    cleanup(path)
  var state = initial()
  state.rememberMovement(current, "Earlier verified decision.", messages)
  let oldId = state.memoryDelivery["decision_id"].getStr
  state.rememberMovement(current, "Newer verified decision.", messages)
  state.persist(path)
  let
    before = state.memoryDelivery.copy()
    saved = readFile(path)
  var rejected = false
  try:
    discard game.dispatchPress(current, messages, state, path, oldId)
  except KutuzovError:
    rejected = true
  doAssert rejected
  doAssert state.memoryDelivery == before
  doAssert state.phase.sent.len == 0
  doAssert readFile(path) == saved

echo "Testing outgoing capacity and delivery facts survive prompt rebasing"
block:
  let
    current = context()
    game = config()
    request = RequestConfig(
      api: ChatApi, model: DefaultHostedModel,
      reasoningEffort: "low", maxOutputTokens: 3000
    )
  var
    state = initial()
    limits = defaultBudgetConfig()
  state.phase.sent = @["5:Earlier proposal.", "5:Earlier update."]
  state.rememberMovement(current, "Final correction drafted.", draft())
  let availability = game.pressAvailability(current, state.phase)
  doAssert availability["limit_per_recipient"].getInt == 2
  doAssert availability["press_type"].getStr == "Regular"
  doAssert availability["recipients"].len == 8
  doAssert not availability.recipient(3)["allowed"].getBool
  doAssert availability.recipient(5)["attempts"].getInt == 2
  doAssert availability.recipient(5)["remaining_attempts"].getInt == 0
  doAssert availability.recipient(7)["remaining_attempts"].getInt == 2
  doAssert availability.recipient(0)["allowed"].getBool
  for mode in ["NoPress", "PublicPressOnly"]:
    let restricted = game.pressAvailability(
      context(pressType = mode), state.phase
    )
    doAssert not restricted.recipient(5)["allowed"].getBool
    doAssert restricted.recipient(0)["allowed"].getBool ==
      (mode == "PublicPressOnly")
  limits.maxContextBytes = 12_000
  let
    input = state.observed(current)
    first = prepareInput(request, "rules", input, state.phase, limits)
    full = parseJson(first.text)
  doAssert full["memory_delivery"] == state.memoryDelivery
  doAssert full["outgoing_press"] == availability
  doAssert full["reviewed"].getBool and full["updates_stopped"].getBool
  doAssert full["remaining_updates"].getInt == 1
  state.phase.recordExchange(
    first.text,
    "{}",
    %*{"orders_verified": true, "confirmed_press": [], "press_outcomes": []},
    limits
  )
  let
    following = prepareInput(request, "rules", input, state.phase, limits)
    delta = parseJson(following.text)
  doAssert delta["phase_update"].getBool
  doAssert not delta.hasKey("board")
  for key in ["memory_delivery", "outgoing_press", "reviewed",
    "updates_stopped", "remaining_updates"]:
      doAssert delta[key] == full[key]
  state.phase.transcript.add %*{
    "role": "assistant", "content": repeat("X", 13_000)
  }
  let
    rebased = prepareInput(request, "rules", input, state.phase, limits)
    fresh = parseJson(rebased.text)
  doAssert rebased.rebased and rebased.transcript.len == 0
  doAssert fresh.hasKey("board")
  for key in ["memory_delivery", "outgoing_press", "reviewed",
    "updates_stopped", "remaining_updates"]:
      doAssert fresh[key] == full[key]

echo "Testing legacy persistence and unchanged optional-update stop"
block:
  let
    path = statePath("legacy")
    game = config()
    current = context()
    press = PressContext(
      messages: %*[{"message": "Please reconsider the support."}],
      signature: "unread-offer"
    )
    now = int(epochTime())
  cleanup(path)
  defer:
    cleanup(path)
  writeFile(path, $(%*{
    "gameId": 704, "countryId": 3, "memory": "Historical plan."
  }))
  var state = restore(game, path)
  doAssert state.memoryDelivery.isNil and state.memorySerial == 0
  doAssert state.observed(current)["memory_delivery"].kind == JNull
  state.rememberMovement(current, "Verified with no drafts.", newJArray())
  state.persist(path)
  doAssert restore(game, path).memoryDelivery == state.memoryDelivery
  state.phase = initial().phase
  state.phase.pendingSignature = press.signature
  state.phase.pressFirstAt = now - 30
  state.phase.pressChangedAt = now - 30
  let limits = defaultBudgetConfig()
  doAssert state.phase.nextTask(
    "Diplomacy", press, limits, 60, 45, now
  ) == "wait"
  state.phase.updatesStopped = false
  doAssert state.phase.nextTask(
    "Diplomacy", press, limits, 60, 45, now
  ) == "update"
  state.phase.calls = 4
  doAssert state.phase.nextTask(
    "Diplomacy", press, limits, 60, 45, now
  ) == "ready"

echo "Testing escaped and multibyte delivery views preserve durable facts"
block:
  let
    path = statePath("bounded-view")
    current = context()
    game = config()
    texts = [
      repeat("\"", 600),
      repeat("\\", 600),
      repeat("\x00", 600),
      repeat("\n\t\r\b\f", 120),
      repeat("\"\\\x00\n\t", 120),
      repeat("é\"\\\x00", 120),
      repeat("界🙂\"\x01", 66) & "é🙂"
    ]
    destinations = [0, 1, 2, 4, 5, 6, 7]
    messages = newJArray()
    request = RequestConfig(
      api: ChatApi, model: DefaultHostedModel,
      reasoningEffort: "low", maxOutputTokens: 3000
    )
  cleanup(path)
  defer:
    cleanup(path)
  for i in 0 ..< texts.len:
    doAssert texts[i].len == 600
    doAssert validateUtf8(texts[i]) == -1
    doAssert ($(%($(%texts[i])))).len > 640
    messages.add %*{"to": destinations[i], "text": texts[i]}
  var
    state = initial()
    limits = defaultBudgetConfig()
  state.rememberMovement(current, "Keep the exact verified drafts.", messages)
  state.persist(path)
  let
    durable = state.memoryDelivery.copy()
    saved = readFile(path)
    view = deliveryView(state.memoryDelivery)
  boundedView(view, durable)
  for fact in view["outcomes"]:
    doAssert fact["text_truncated"].getBool
    doAssert fact["original_text_bytes"].getInt == 600
  doAssert state.memoryDelivery == durable
  doAssert readFile(path) == saved
  doAssert restore(game, path).memoryDelivery == durable
  let independent = deliveryView(state.memoryDelivery)
  independent["outcomes"][0]["text"] = %"Only this detached view changes."
  independent["outcomes"][0]["status"] = %"fixture-only"
  doAssert state.memoryDelivery == durable
  limits.maxContextBytes = 32_000
  let
    input = state.observed(current)
    first = prepareInput(request, "rules", input, state.phase, limits)
    full = parseJson(first.text)
  doAssert full["memory_delivery"] == view
  boundedView(full["memory_delivery"], durable)
  state.phase.recordExchange(
    first.text,
    "{}",
    %*{"orders_verified": true, "confirmed_press": [], "press_outcomes": []},
    limits
  )
  let
    following = prepareInput(request, "rules", input, state.phase, limits)
    delta = parseJson(following.text)
  doAssert delta["phase_update"].getBool
  doAssert not delta.hasKey("board")
  doAssert delta["memory_delivery"] == view
  boundedView(delta["memory_delivery"], durable)
  state.phase.transcript.add %*{
    "role": "assistant", "content": repeat("X", 40_000)
  }
  let
    rebased = prepareInput(request, "rules", input, state.phase, limits)
    fresh = parseJson(rebased.text)
  doAssert rebased.rebased and rebased.transcript.len == 0
  doAssert fresh.hasKey("board")
  doAssert fresh["memory_delivery"] == view
  boundedView(fresh["memory_delivery"], durable)
  doAssert state.memoryDelivery == durable
  doAssert readFile(path) == saved
  doAssert restore(game, path).memoryDelivery == durable
  state.rememberMovement(current, "Plain text needs no truncation.",
    draft(text = repeat("a", 600)))
  let plain = deliveryView(state.memoryDelivery)
  boundedView(plain, state.memoryDelivery)
  doAssert plain == state.memoryDelivery

echo "Testing unknown delivery views survive null persistence round trips"
block:
  let
    path = statePath("unknown-view")
    game = config()
    current = context()
  cleanup(path)
  defer:
    cleanup(path)
  doAssert deliveryView(nil).kind == JNull
  doAssert deliveryView(newJNull()).kind == JNull
  for unknown in [JsonNode(nil), newJNull()]:
    var state = initial()
    state.memory = "Historical plan with unknown delivery."
    state.memoryStamp = "10:Diplomacy"
    state.memoryDelivery = unknown
    state.persist(path)
    let recovered = restore(game, path)
    doAssert recovered.memory == state.memory
    doAssert recovered.memoryStamp == "10:Diplomacy"
    doAssert deliveryView(recovered.memoryDelivery).kind == JNull
    doAssert recovered.observed(current)["memory_delivery"].kind == JNull
    recovered.persist(path)
    let restored = restore(game, path)
    doAssert deliveryView(restored.memoryDelivery).kind == JNull
    doAssert restored.observed(current)["memory_delivery"].kind == JNull
  var known = initial()
  known.rememberMovement(current, "No outgoing drafts.", newJArray())
  known.persist(path)
  let restored = restore(game, path)
  doAssert deliveryView(restored.memoryDelivery).kind == JObject
  doAssert deliveryView(restored.memoryDelivery)["outcomes"].len == 0

for kind in DeliveryCase:
  echo "Testing local press delivery: ", kind
  testDispatch(kind)
