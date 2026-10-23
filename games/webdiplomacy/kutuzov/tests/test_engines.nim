import
  std/[json, net, os, strutils, times],
  jsony,
  ../[budgets, common, engines, prompts, protocols, requests],
  boards

const
  SeatSecret = "kutuzov-fixture-seat-secret"
  DirectSecret = "kutuzov-fixture-direct-secret"
  PriorMemory = "Prior verified movement decision."
  EnvironmentNames = [
    "WEBDIP_URL", "WEBDIP_API_KEY", "WEBDIP_GAME_ID", "WEBDIP_COUNTRY_ID",
    "WEBDIP_END_YEAR", "WEBDIP_SCORING", "OPENAI_API_KEY", "OPENAI_BASE_URL",
    "COWORLD_LLM_ENDPOINT", "COWORLD_LLM_MODEL",
    "AWS_ENDPOINT_URL_BEDROCK_RUNTIME", "BEDROCK_MODEL", "KUTUZOV_MODEL",
    "KUTUZOV_REASONING", "KUTUZOV_TIMEOUT_SECONDS",
    "KUTUZOV_MAX_OUTPUT_TOKENS", "KUTUZOV_GAME_TIMEOUT_SECONDS",
    "KUTUZOV_STATE_PATH", "KUTUZOV_BUDGET_USD", "KUTUZOV_RESERVE_USD",
    "KUTUZOV_BUDGET_MODE",
    "KUTUZOV_PRESS_MODEL", "KUTUZOV_ECONOMY_MODEL", "KUTUZOV_MAX_PHASE_CALLS",
    "KUTUZOV_MAX_PRESS_CALLS", "KUTUZOV_MAX_PRESS_CHARACTERS",
    "KUTUZOV_MAX_OPPONENT_CHARACTERS", "KUTUZOV_MAX_MESSAGE_CHARACTERS",
    "KUTUZOV_MAX_MESSAGES_PER_OPPONENT", "KUTUZOV_MAX_CONTEXT_BYTES"
  ]

proc order(kind = "Hold"): JsonNode =
  ## Build one fixture order on a two-province map.
  %*{
    "type": kind,
    "terrID": 1,
    "toTerrID": (if kind == "Move": 2 else: 0),
    "fromTerrID": 0,
    "viaConvoy": "No"
  }

proc decision(kind = "Hold"): JsonNode =
  ## Offer duplicate press so the runtime must enforce its delivery cap.
  %*{
    "orders": [order(kind)],
    "press": [
      {"to": 2, "text": "PRP (PCE (ENG FRA))"},
      {"to": 2, "text": "PRP (PCE (ENG FRA))"}
    ],
    "memory": "Take the neutral center in the final autumn.",
    "stop_spending": false,
    "stop_reason": ""
  }

proc context(turn, deadline: int, orders: JsonNode): JsonNode =
  ## Supply private credentials in fields that observations must omit.
  %*{
    "game": {
      "turn": turn,
      "phase": "Diplomacy",
      "processTime": deadline,
      "pressType": "Regular",
      "apiKey": SeatSecret
    },
    "member": {"status": "Playing", "apiKey": SeatSecret},
    "orders": {"orders": orders},
    "messages": {"messages": [{
      "turn": turn,
      "fromCountryID": 2,
      "toCountryID": 1,
      "message": "PRP (PCE (ENG FRA))",
      "apiKey": SeatSecret
    }]},
    "files": {
      "game": {"url": "board.json", "version": $turn},
      "variant": {"url": "variant.json", "version": "1"},
      "history": {"url": "history.json", "version": $turn},
      "messages": {"url": "messages.json", "version": $turn}
    },
    "apiKey": SeatSecret
  }

proc board(turn: int): JsonNode =
  ## Expose a complete small public board with a legal neutral-center move.
  %*{
    "turn": turn,
    "phase": "Diplomacy",
    "turnText": "Final year",
    "pressType": "Regular",
    "units": [{"id": 1, "type": "Army", "terrID": 1, "countryID": 1}],
    "territories": [
      {"id": 1, "ownerCountryID": 1, "occupiedBy": 1},
      {"id": 2, "ownerCountryID": 0, "occupiedBy": 0}
    ],
    "members": [
      {"countryID": 1, "status": "Playing", "supplyCenterNo": 1},
      {"countryID": 2, "status": "Playing", "supplyCenterNo": 1}
    ],
    "apiKey": SeatSecret
  }

proc variant(): JsonNode =
  ## Describe matching army borders and a capturable neutral supply center.
  %*{
    "name": "Fixture map",
    "countries": [{"id": 1, "name": "England"},
      {"id": 2, "name": "France"}],
    "rules": "Classic Diplomacy movement rules.",
    "supplyCenterCount": 2,
    "supplyCenterTarget": 2,
    "territories": [
      {
        "id": 1, "name": "Home", "type": "Land", "supply": "Yes",
        "homeCountryID": 1, "coast": "No", "coastParentID": 0,
        "borders": [{"id": 2, "army": true, "fleet": false}],
        "coastalBorders": []
      },
      {
        "id": 2, "name": "Neutral", "type": "Land", "supply": "Yes",
        "homeCountryID": 0, "coast": "No", "coastParentID": 0,
        "borders": [{"id": 1, "army": true, "fleet": false}],
        "coastalBorders": []
      }
    ],
    "apiKey": SeatSecret
  }

proc serveGame(args: tuple[server: Socket, deadline: int, fallback: bool])
    {.thread.} =
  ## Run the game and hosted LLM on loopback with assertions at each boundary.
  let server = args.server
  defer:
    server.close()
  var
    stage = 0
    requests = 0
    calls: array[2, int]
    sends: array[2, int]
    saves: array[2, int]
    stored = %*[order()]
    prefix = ""
  while true:
    inc requests
    doAssert requests <= 80, "The runtime failed to reach the final phase."
    var client: Socket
    server.accept(client)
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
      let lower = header.toLowerAscii()
      if lower.startsWith("content-length:"):
        length = parseInt(header.split(':', 1)[1].strip())
      elif lower.startsWith("authorization:"):
        authorization = header.split(':', 1)[1].strip()
    var body = ""
    while body.len < length:
      let part = client.recv(length - body.len, timeout = 2000)
      doAssert part.len > 0
      body.add(part)
    let turn = 14 + min(stage, 1)
    var
      response: JsonNode
      headers = ""
      finished = false
    if line.startsWith("GET /api.php?route=game/playercontext&"):
      doAssert authorization == "Bearer " & SeatSecret
      response = context(turn, args.deadline, stored)
      if stage < 2 and calls[stage] >= (if stage == 0: 4 else: 2):
        response["game"]["processTime"] = %(int(epochTime()) + 35)
      if stage == 2:
        response["game"]["phase"] = %"Finished"
        finished = true
    elif line.startsWith("GET /board.json?"):
      doAssert authorization.len == 0
      response = board(turn)
    elif line.startsWith("GET /variant.json?"):
      doAssert authorization.len == 0
      response = variant()
      if args.fallback:
        response["rules"] = %repeat("X", 35_000)
    elif line.startsWith("GET /history.json?"):
      doAssert authorization.len == 0
      response = %*{"phases": []}
    elif line.startsWith("GET /messages.json?"):
      doAssert authorization.len == 0
      response = %*{"messages": []}
    elif line.startsWith("GET /spend "):
      doAssert authorization.len == 0
      response = %*{
        "spend_usd": (calls[0] + calls[1]).float * 0.01 +
          (if args.fallback: 0.40 else: 0.0),
        "spend_limit_usd": (if args.fallback: 0.50 else: 2.0)
      }
    elif line.startsWith("POST /v1/chat/completions "):
      doAssert stage < 2
      doAssert authorization == "Bearer coworld"
      doAssert not body.contains(SeatSecret)
      doAssert not body.contains(DirectSecret)
      let
        payload = body.fromJson(JsonNode)
        developer = payload["messages"][0]["content"].getStr()
        initial = payload["messages"][1]["content"].getStr().fromJson(JsonNode)
        input = payload["messages"][^1]["content"].getStr().fromJson(JsonNode)
      if prefix.len == 0:
        prefix = developer
      doAssert developer == prefix
      doAssert developer.contains("MAP JSON:")
      doAssert restoredBoard(initial["board"]) == objectBoard(board(turn))
      doAssert initial["board"]["units"][0][5].getStr == "England"
      doAssert initial["board"]["units"][0][6].getStr == "Home"
      doAssert payload["model"].getStr() ==
        (if args.fallback: "openai/gpt-6-luna" else: DefaultHostedModel)
      if args.fallback:
        doAssert developer.contains(repeat("X", 35_000))
        doAssert initial["board"]["territories"].len == 2
        doAssert initial["board"]["units"].len == 1
      doAssert payload["reasoning"]["effort"].getStr() == "low"
      doAssert payload["max_completion_tokens"].getInt() ==
        (if args.fallback: 3000 else: 1000)
      doAssert initial["country_id"].getInt() == 1
      doAssert initial["year"].getInt() == 1908
      doAssert initial["end_year"].getInt() == 1908
      doAssert initial["final_year"].getBool()
      doAssert initial["season"].getStr() ==
        (if stage == 0: "spring" else: "autumn")
      let expectedTask =
        if calls[stage] == 0:
          "plan"
        elif stage == 0 and calls[stage] < 3:
          "repair"
        else:
          "review"
      doAssert input["task"].getStr() == expectedTask
      if stage == 0 and expectedTask != "review":
        doAssert input["memory_phase"].getStr == "13:Diplomacy"
        doAssert input["memory"].getStr == PriorMemory
        doAssert input["memory_delivery"]["decision_id"].getStr == "101:1:1"
        doAssert input["memory_delivery"]["outcomes"].len == 0
      else:
        doAssert input["memory_phase"].getStr ==
          (if expectedTask == "review": $turn else: "14") & ":Diplomacy"
      if expectedTask == "repair":
        doAssert input["repair_feedback"].getStr().len > 0
      elif expectedTask == "review":
        doAssert input["saved_orders"][0]["type"].getStr() == "Hold"
        let outcomes = input["memory_delivery"]["outcomes"]
        doAssert outcomes[0]["status"].getStr == "confirmed"
        doAssert outcomes[1]["reason"].getStr == "duplicate"
        doAssert not body.contains("{ malformed decision")
        if input{"phase_update"}.getBool:
          doAssert input{"board"}.isNil
          doAssert payload["messages"].len == (if stage == 0: 8 else: 5)
          let receipt = payload["messages"][^2]["content"].getStr().fromJson(
            JsonNode
          )
          doAssert receipt["orders_verified"].getBool()
          doAssert receipt["confirmed_press"].len == 1
          doAssert outcomes == receipt["press_outcomes"]
          if stage == 0:
            let rejected = payload["messages"][3]["content"].getStr().fromJson(
              JsonNode
            )
            doAssert not rejected["orders_verified"].getBool()
            doAssert rejected["outcome"].getStr() == "rejected"
            doAssert rejected["confirmed_press"].len == 0
            doAssert rejected["press_outcomes"][0]["reason"].getStr ==
              "orders_unverified"
        else:
          doAssert args.fallback
          doAssert payload["messages"].len == 2
          doAssert restoredBoard(input["board"]) == objectBoard(board(turn))
      doAssert body.len + 512 <= MaximumRequestBytes
      inc calls[stage]
      doAssert calls[stage] <= 4
      let text =
        if stage == 0 and calls[stage] == 1:
          "{ malformed decision"
        elif expectedTask == "review":
          $decision("Move")
        else:
          $decision()
      response = %*{
        "choices": [{"finish_reason": "stop", "message": {
          "role": "assistant", "content": text
        }}],
        "usage": {
          "prompt_tokens": 1500,
          "completion_tokens": 100,
          "prompt_tokens_details": {"cached_tokens": 1024}
        }
      }
      headers = "X-Coworld-Spend-Usd: " &
        $((calls[0] + calls[1]).float * 0.01 +
          (if args.fallback: 0.40 else: 0.0)) & "\r\n" &
        "X-Coworld-Spend-Limit-Usd: " &
        (if args.fallback: "0.50" else: "2.0") & "\r\n"
    elif line.startsWith("POST /api.php?route=game/orders "):
      doAssert authorization == "Bearer " & SeatSecret
      doAssert stage < 2
      let payload = body.fromJson(JsonNode)
      doAssert payload["gameID"].getInt() == 101
      doAssert payload["countryID"].getInt() == 1
      doAssert payload["turn"].getInt() == turn
      doAssert payload["phase"].getStr() == "Diplomacy"
      if payload["ready"].getStr() == "No":
        stored = payload["orders"]
        inc saves[stage]
        doAssert stored.len == 1
        doAssert stored[0]["terrID"].getInt() == 1
        let expected =
          if saves[stage] == (if stage == 0: 3 else: 2):
            "Move"
          else:
            "Hold"
        doAssert stored[0]["type"].getStr() == expected
        if expected == "Move":
          doAssert stored[0]["toTerrID"].getInt() == 2
        if stage == 0 and saves[stage] == 1:
          stored = %*[order("Move")]
        response = stored
      else:
        doAssert payload["ready"].getStr() == "Yes"
        doAssert payload["orders"].len == 0
        doAssert saves[stage] == (if stage == 0: 3 else: 2)
        doAssert calls[stage] == (if stage == 0: 4 else: 2)
        doAssert sends[stage] == 1
        response = stored
        inc stage
        stored = %*[order()]
    elif line.startsWith("POST /api.php?route=game/sendmessage "):
      doAssert authorization == "Bearer " & SeatSecret
      doAssert stage < 2
      let payload = body.fromJson(JsonNode)
      doAssert payload["toCountryID"].getInt() == 2
      doAssert payload["message"].getStr() == "PRP (PCE (ENG FRA))"
      inc sends[stage]
      doAssert sends[stage] == 1
      response = %*{"sent": true}
    else:
      doAssert false, "Unexpected fixture request: " & line
    let encoded = $response
    client.send(
      "HTTP/1.1 200 OK\r\n" &
      "Content-Type: application/json\r\n" &
      "Connection: close\r\n" & headers &
      "Content-Length: " & $encoded.len & "\r\n\r\n" & encoded
    )
    if finished:
      doAssert calls == [4, 2]
      doAssert saves == [3, 2]
      doAssert sends == [1, 1]
      return

proc testEngine(path: string, fallback = false) =
  ## Run the real bot through its final spring and autumn with no paid calls.
  var saved: seq[tuple[name, value: string, present: bool]]
  for name in EnvironmentNames:
    saved.add((name, getEnv(name), existsEnv(name)))
    delEnv(name)
  defer:
    for entry in saved:
      if entry.present:
        putEnv(entry.name, entry.value)
      else:
        delEnv(entry.name)
  let server = newSocket()
  server.bindAddr(Port(0), "127.0.0.1")
  server.listen()
  let endpoint = "http://127.0.0.1:" & $server.getLocalAddr()[1]
  putEnv("WEBDIP_URL", endpoint)
  putEnv("WEBDIP_API_KEY", SeatSecret)
  putEnv("WEBDIP_GAME_ID", "101")
  putEnv("WEBDIP_COUNTRY_ID", "1")
  putEnv("WEBDIP_END_YEAR", "1908")
  putEnv("COWORLD_LLM_ENDPOINT", endpoint)
  putEnv("COWORLD_LLM_MODEL", DefaultHostedModel)
  putEnv("OPENAI_API_KEY", DirectSecret)
  putEnv("KUTUZOV_STATE_PATH", path)
  putEnv("KUTUZOV_MAX_OUTPUT_TOKENS", if fallback: "3000" else: "1000")
  var prior = BotState(gameId: 101, countryId: 1)
  prior.rememberMovement(
    context(13, int(epochTime()) + 60, newJArray()),
    PriorMemory,
    newJArray()
  )
  prior.persist(path)
  var worker: Thread[tuple[server: Socket, deadline: int, fallback: bool]]
  createThread(worker, serveGame, (server, int(epochTime()) + 60, fallback))
  runBot()
  joinThread(worker)
  let state = restore(loadGameConfig(), path)
  doAssert state.phase.stamp == "15:Diplomacy"
  doAssert state.phase.ready
  doAssert state.phase.reviewed
  doAssert state.phase.calls == 2
  doAssert state.phase.sent.len == 1
  doAssert state.phase.savedOrders[0]["type"].getStr() == "Move"
  doAssert state.budget.reservedUsd == 0.0
  let expectedSpend = if fallback: 0.46 else: 0.06
  doAssert abs(state.budget.authoritativeSpentUsd - expectedSpend) < 0.000000001
  if fallback:
    doAssert state.phase.transcript.len in [3, 6]
    if state.phase.transcript.len == 3:
      let latest = state.phase.transcript[0]["content"].getStr.fromJson(
        JsonNode
      )
      doAssert latest["task"].getStr == "review"
      doAssert latest.hasKey("board")
  else:
    doAssert state.phase.transcript.len == 6
  doAssert state.memorySerial == 5
  doAssert state.memoryDelivery["decision_id"].getStr == "101:1:5"
  doAssert state.memoryDelivery["phase"].getStr == "15:Diplomacy"
  for outcome in state.memoryDelivery["outcomes"]:
    doAssert outcome["status"].getStr == "skipped"
    doAssert outcome["reason"].getStr == "duplicate"

proc testRouting() =
  ## Keep affordable Sol calls and fall back before any paid request.
  let
    config = RequestConfig(
      api: ChatApi,
      model: DefaultHostedModel,
      reasoningEffort: "low",
      maxOutputTokens: 3000
    )
    longInput = $ %*{"board": {"complete_position": repeat("B", 35_000)}}
    hugeInput = $ %*{"board": {"complete_position": repeat("B", 45_000)}}
  var limits = defaultBudgetConfig()
  limits.limitUsd = 0.20
  limits.reserveUsd = 0.05
  let
    spring = chooseCall(config, Budget(), limits, "rules", longInput, true, 2)
    autumn = chooseCall(config, Budget(), limits, "rules", longInput, true, 1)
    huge = chooseCall(
      config, Budget(spentUsd: 0.10), limits, "rules", hugeInput, true, 1
    )
    rich = chooseCall(config, Budget(), limits, "rules", "{}", true, 2)
    early = chooseCall(
      config,
      Budget(spentUsd: 0.10),
      limits,
      "rules",
      longInput
    )
    empty = chooseCall(
      config,
      Budget(spentUsd: 0.1999),
      limits,
      "rules",
      hugeInput,
      true
    )
  doAssert spring.allowed and spring.fallback
  doAssert spring.config.model == "openai/gpt-6-luna"
  doAssert spring.reservedUsd <= 0.10
  doAssert autumn.allowed and not autumn.fallback
  doAssert autumn.config.model == DefaultHostedModel
  doAssert huge.allowed and huge.fallback
  doAssert huge.config.model == "openai/gpt-6-luna"
  doAssert huge.requestBytes > 45_000
  doAssert rich.allowed and not rich.fallback
  doAssert early.allowed and early.fallback
  doAssert early.reservedUsd <= 0.05
  doAssert not empty.allowed
  var direct = config
  direct.api = ResponsesApi
  direct.model = DefaultModel
  let directPlan = chooseCall(
    direct, Budget(spentUsd: 0.10), limits, "rules", hugeInput, true
  )
  doAssert directPlan.allowed and directPlan.fallback
  doAssert directPlan.config.model == "gpt-6-luna"

proc testCachePrefix() =
  ## Preserve stable board context before changing plan and review fields.
  let
    config = GameConfig(gameId: 101, countryId: 1, endYear: 1908)
    current = context(15, int(epochTime()) + 60, %*[order()])
    position = board(15)
    history = %*{"phases": []}
    press = PressContext(messages: newJArray())
    limits = defaultBudgetConfig()
  var state = BotState(phase: PhaseState(savedOrders: newJArray()))
  let plan = $observation(
    config, current, position, history, press, state, limits, "plan"
  )
  state.phase.savedOrders = %*[order()]
  state.phase.calls = 1
  let
    review = $observation(
      config, current, position, history, press, state, limits, "review"
    )
    prefixEnd = plan.find(",\"task\":")
  doAssert prefixEnd > 0
  doAssert plan[0 ..< prefixEnd] == review[0 ..< prefixEnd]
  doAssert plan[0 ..< prefixEnd].contains("\"board\":")
  doAssert plan[0 ..< prefixEnd].contains("\"recent_history\":")

proc testConversation() =
  ## Keep exact successful exchanges and rebase a full board before overflow.
  let
    game = GameConfig(gameId: 101, countryId: 1, endYear: 1908)
    config = RequestConfig(
      api: ChatApi,
      model: DefaultHostedModel,
      reasoningEffort: "low",
      maxOutputTokens: 3000
    )
    current = context(15, 200, %*[order()])
    position = board(15)
    history = %*{"phases": []}
    messages = %*[
      {"fromCountryID": 2, "toCountryID": 1, "message": "Offer A"}
    ]
    press = PressContext(messages: messages)
    limits = defaultBudgetConfig()
  var state = BotState(phase: PhaseState(savedOrders: newJArray()))
  let
    initial = observation(
      game, current, position, history, press, state, limits, "plan"
    )
    prepared = prepareInput(config, "rules", initial, state.phase, limits)
    firstRequest = config.buildRequest("rules", prepared.text)
    reply = $decision()
    receipt = %*{
      "orders_verified": true,
      "saved_orders": [order()],
      "confirmed_press": []
    }
  doAssert prepared.transcript.len == 0
  state.phase.recordExchange(prepared.text, reply, receipt, limits)
  state.phase.savedOrders = %*[order()]
  messages.add %*{
    "fromCountryID": 3, "toCountryID": 1, "message": "Offer B"
  }
  let
    update = observation(
      game, current, position, history, press, state, limits, "update"
    )
    following = prepareInput(config, "rules", update, state.phase, limits)
    delta = following.text.fromJson(JsonNode)
    nextRequest = config.buildRequest(
      "rules", following.text, following.transcript
    )
  doAssert following.transcript.len == 3
  doAssert delta["new_press"].len == 1
  doAssert delta["new_press"][0]["message"].getStr() == "Offer B"
  doAssert delta{"board"}.isNil
  doAssert firstRequest["messages"][0] == nextRequest["messages"][0]
  doAssert firstRequest["messages"][1] == nextRequest["messages"][1]
  doAssert nextRequest["messages"][2]["content"].getStr() == reply
  doAssert nextRequest["messages"][3]["content"].getStr() == $receipt
  state.phase.transcript.add %*{
    "role": "assistant", "content": repeat("X", 55_000)
  }
  let
    rebased = prepareInput(
      config, repeat("R", 8_000), update, state.phase, limits
    )
    full = rebased.text.fromJson(JsonNode)
  doAssert rebased.rebased
  doAssert rebased.transcript.len == 0
  doAssert full["board"] == compactBoard(position)
  doAssert rebased.requestBytes <= MaximumRequestBytes
  var oversized = ($update).fromJson(JsonNode)
  oversized["board"]["turnText"] = %repeat("Z", 65_000)
  let rejected = prepareInput(
    config, "rules", oversized, PhaseState(), limits
  )
  doAssert rejected.requestBytes > MaximumRequestBytes
  doAssert rejected.text.fromJson(JsonNode)["board"]["turnText"].getStr.len ==
    65_000

proc testRecordedBoards() =
  ## Preserve real positions through compaction, serialization, and rebasing.
  let
    fixture = boardFixture()
    map = fixture["variant"]
    game = GameConfig(gameId: 101, countryId: 1, endYear: 1908)
    config = RequestConfig(
      api: ChatApi,
      model: DefaultHostedModel,
      reasoningEffort: "low",
      maxOutputTokens: 3000
    )
    prefix = Policy & "\n\nMAP JSON:\n" & $compactMap(map)
    history = %*{"phases": []}
    press = PressContext(messages: newJArray())
    limits = defaultBudgetConfig()
  for sample in fixture["boards"]:
    let position = sample["board"]
    var
      current = context(position["turn"].getInt, 200, %*[order()])
      state = BotState(phase: PhaseState(savedOrders: newJArray()))
    current["game"]["phase"] = position["phase"]
    let
      input = observation(
        game, current, position, history, press, state, limits, "plan", map
      )
      compact = input["board"]
      original = objectBoard(position)
    assertPosition(position, compact, map)
    var oldInput = parseJson($input)
    oldInput["board"] = original
    let
      compactBytes = ($compact).len
      originalBytes = ($original).len
      requestBytes = ($config.buildRequest(prefix, $input)).len
      oldRequestBytes = ($config.buildRequest(prefix, $oldInput)).len
    doAssert compactBytes < originalBytes
    doAssert requestBytes < oldRequestBytes
    echo "Recorded ", sample["name"].getStr, ": board ", originalBytes,
      " -> ", compactBytes, "; request ", oldRequestBytes, " -> ", requestBytes
    let prepared = prepareInput(config, prefix, input, state.phase, limits)
    state.phase.recordExchange(
      prepared.text,
      $decision(),
      %*{"orders_verified": true, "saved_orders": [order()],
        "confirmed_press": []},
      limits
    )
    let
      update = observation(
        game, current, position, history, press, state, limits, "update", map
      )
      following = prepareInput(config, prefix, update, state.phase, limits)
    doAssert following.transcript.len == 3
    doAssert following.text.fromJson(JsonNode){"board"}.isNil
    state.phase.transcript.add %*{
      "role": "assistant", "content": repeat("X", 55_000)
    }
    let
      rebased = prepareInput(config, prefix, update, state.phase, limits)
      full = rebased.text.fromJson(JsonNode)
    doAssert rebased.rebased
    doAssert rebased.transcript.len == 0
    doAssert rebased.requestBytes <= MaximumRequestBytes
    doAssert full["board"] == compact
    assertPosition(position, full["board"], map)

proc testCadence() =
  ## Wake on debounced new press and preserve the final review and save buffer.
  let
    limits = defaultBudgetConfig()
    initial = %*[
      {"fromCountryID": 2, "toCountryID": 1, "message": "Offer A"}
    ]
    press = PressContext(messages: initial, signature: "offer-a")
  var phase = PhaseState(calls: 1, savedOrders: %*[order()])
  doAssert phase.nextTask("Diplomacy", press, limits, 150, 45, 100) == "wait"
  doAssert phase.nextTask("Diplomacy", press, limits, 141, 45, 109) == "wait"
  doAssert phase.nextTask("Diplomacy", press, limits, 140, 45, 110) == "update"
  phase.calls = 3
  doAssert phase.nextTask("Diplomacy", press, limits, 130, 45, 120) == "wait"
  doAssert phase.nextTask("Diplomacy", press, limits, 70, 45, 180) == "review"
  phase.reviewed = true
  phase.pressCalls = 1
  doAssert phase.nextTask("Diplomacy", press, limits, 65, 45, 185) == "update"
  phase.seenPress = @[$initial[0]]
  doAssert phase.nextTask("Diplomacy", press, limits, 65, 45, 185) == "wait"
  doAssert phase.nextTask("Diplomacy", press, limits, 40, 45, 210) == "ready"
  doAssert phase.nextTask("Retreats", press, limits, 60, 45, 190) == "ready"
  phase = PhaseState(savedOrders: newJArray())
  doAssert phase.nextTask("Retreats", press, limits, 60, 45, 190) == "plan"
  phase.feedback = "The server rejected an order."
  doAssert phase.nextTask("Diplomacy", press, limits, 60, 45, 190) == "repair"
  doAssert requestTimeout(45, 200, 100) == 45
  doAssert requestTimeout(45, 200, 140) == 30
  doAssert requestTimeout(45, 200, 175) == 0
  doAssert actionTimeout(10, 200, 170) == 6
  doAssert actionTimeout(10, 200, 175) == 5
  doAssert actionTimeout(10, 200, 100) == 10
  doAssert actionTimeout(10, 200, 190, 1) == 5

proc testBoundaries(path: string) =
  ## Verify the horizon and conservative recovery of an interrupted call.
  doAssert not horizonReached(14, "Diplomacy", 1908)
  doAssert not horizonReached(15, "Diplomacy", 1908)
  doAssert not horizonReached(15, "Retreats", 1908)
  doAssert horizonReached(15, "Builds", 1908)
  doAssert horizonReached(16, "Diplomacy", 1908)
  doAssert readDecision($decision()).orders[0]["type"].getStr() == "Hold"
  doAssertRaises KutuzovError:
    discard readDecision("[]")
  var invalid = decision()
  invalid["stop_spending"] = %true
  doAssertRaises KutuzovError:
    discard readDecision($invalid)
  invalid["stop_reason"] = %"No remaining units or possible center gains."
  doAssert readDecision($invalid).stopSpending
  let
    config = GameConfig(gameId: 101, countryId: 1)
    pending = BotState(
      gameId: 101,
      countryId: 1,
      budget: Budget(spentUsd: 0.10, authoritativeSpentUsd: 0.20,
        reservedUsd: 0.03),
      phase: PhaseState(stamp: "15:Diplomacy", calls: 2,
        savedOrders: %*[order("Move")])
    )
  persist(pending, path)
  let recovered = restore(config, path)
  doAssert recovered.budget.reservedUsd == 0.0
  doAssert abs(recovered.budget.spentUsd - 0.23) < 0.000000001
  doAssert recovered.phase.calls == 2
  doAssert recovered.phase.savedOrders[0]["type"].getStr() == "Move"
  let another = restore(GameConfig(gameId: 102, countryId: 1), path)
  doAssert another.gameId == 102
  doAssert another.phase.calls == 0

echo "Testing final-year engine, repairs, review, press caps, and persistence"
block:
  let path = getTempDir() / ("kutuzov-engine-test-" &
    $getCurrentProcessId() & ".json")
  if fileExists(path):
    removeFile(path)
  defer:
    if fileExists(path):
      removeFile(path)
    if fileExists(path & ".tmp"):
      removeFile(path & ".tmp")
  testEngine(path)
  removeFile(path)
  testEngine(path, fallback = true)
  testRouting()
  testCachePrefix()
  testConversation()
  testRecordedBoards()
  testCadence()
  testBoundaries(path)
