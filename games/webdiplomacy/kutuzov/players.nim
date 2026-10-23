import
  std/[json, os, strutils, times],
  actions, briefings, budgets, common, engines, logs, maps, notes,
  prompts, protocols, requests, tools, wakes

type
  ToolBatch* = object
    receipt*: JsonNode
    finished*, phaseChanged*, rebase*: bool

proc boundedText(text: string, maximum: int): string =
  ## Bound diagnostics without splitting a multibyte UTF-8 character.
  if text.len <= maximum:
    return text
  var ending = maximum
  while ending > 0 and (ord(text[ending]) and 0xC0) == 0x80:
    dec ending
  text[0 ..< ending]

proc hasOrders(phase: PhaseState): bool =
  ## Recognize only a complete previously verified model order set.
  not phase.savedOrders.isNil and phase.savedOrders.kind == JArray and
    phase.savedOrders.len > 0

proc wakeTask(phase: PhaseState): string =
  ## Describe the active wake without changing its model-selected actions.
  if phase.repairView(){"needs_repair"}.getBool or phase.feedback.len > 0:
    return "repair"
  case phase.wake.kind
  of ReviewWake:
    "review"
  of PressWake:
    "update"
  of RepairWake:
    "repair"
  else:
    "plan"

proc latestContext(
  game: GameConfig,
  stamp: string
): JsonNode =
  ## Recheck phase and deadline before each model-requested mutation.
  result = game.fetchContext()
  if phaseStamp(result) != stamp:
    logEvent("tool_phase_changed", %*{
      "phase": stamp, "current_phase": phaseStamp(result)
    })
    return nil
  if integer(result{"game", "processTime"}) <= int(epochTime()):
    logEvent("tool_deadline", %*{"phase": stamp})
    return nil

proc readyVerified*(
  game: GameConfig,
  state: var BotState,
  path, reason: string,
  allowDefault = false
): bool =
  ## Ready only an accepted current set, restoring the last verified plan.
  var context = game.latestContext(state.phase.stamp)
  if context.isNil:
    return false
  let
    slots = context{"orders", "orders"}
    planned = state.phase.hasOrders()
  if not planned and slots.len > 0 and not allowDefault:
    raise newException(KutuzovError,
      "finish requires a complete verified model order set")
  var acting = game
  acting.timeoutSeconds = actionTimeout(
    game.timeoutSeconds,
    integer(context{"game", "processTime"}),
    int(epochTime()),
    calls = 6
  )
  let accepted = acting.finishOrdersVerified(
    context, state.phase.savedOrders, allowDefault
  )
  if accepted.isNil:
    return false
  state.phase.ready = true
  state.persist(path)
  logEvent("phase_ready", %*{
    "phase": state.phase.stamp, "reason": reason,
    "calls": state.phase.calls, "wake": state.phase.wake.count,
    "remaining_seconds": integer(context{"game", "processTime"}) -
      int(epochTime()),
    "orders_verified": planned, "default_orders": not planned and slots.len > 0,
    "slots": slots.len, "orders": accepted
  })
  true

proc endWake(
  state: var BotState,
  path: string,
  reason: WakeEnd
) =
  ## Persist a wake boundary independently from the current Ready status.
  state.phase.wake.finishWake(reason)
  state.persist(path)
  logEvent("wake_end", %*{
    "phase": state.phase.stamp, "wake": state.phase.wake.count,
    "kind": $state.phase.wake.kind, "reason": $reason,
    "calls": state.phase.wake.calls, "phase_calls": state.phase.calls,
    "ready": state.phase.ready, "orders_verified": state.phase.hasOrders()
  })

proc boundedResult(output: JsonNode, remaining: int): JsonNode =
  ## Retain truthful action facts if a tool batch cannot fit verbose details.
  if ($output).len <= remaining:
    return output
  result = %*{
    "status": output{"status"}.getStr("error"),
    "details_omitted": true, "reason": "tool_result_context_limit"
  }
  for name in ["orders_verified", "ready", "stop_spending"]:
    if not output{name}.isNil:
      result[name] = output[name].copy()
  let diagnostic = output{"error"}.getStr
  if diagnostic.len > 0:
    result["error"] = %boundedText(diagnostic, 192)
    result["error_truncated"] = %(diagnostic.len > 192)

proc executeTools*(
  game: GameConfig,
  state: var BotState,
  variant: JsonNode,
  calls: openArray[ToolCall],
  path, model, task: string
): ToolBatch =
  ## Execute each validated call once and return exactly one factual receipt.
  var
    outputs: seq[ToolResult]
    remaining = 11_000
    failedCommit = false
  for index, call in calls:
    var output: JsonNode
    logEvent("tool_start", %*{
      "phase": state.phase.stamp, "call": state.phase.calls,
      "wake": state.phase.wake.count, "tool_id": call.id,
      "tool": call.name, "arguments": call.arguments
    })
    if result.phaseChanged or result.finished:
      output = %*{
        "status": "skipped",
        "reason": (if result.phaseChanged: "phase_changed" else: "wake_finished")
      }
    else:
      try:
        let context = game.latestContext(state.phase.stamp)
        if context.isNil:
          result.phaseChanged = true
          output = %*{"status": "skipped", "reason": "phase_or_deadline_changed"}
        else:
          var acting = game
          acting.timeoutSeconds = actionTimeout(
            game.timeoutSeconds,
            integer(context{"game", "processTime"}),
            int(epochTime())
          )
          case call.name
          of "board":
            readBoard(call.arguments)
            output = %*{
              "status": "ok", "board": compactBoard(
                acting.fetchBoard(context), variant
              ),
              "order_slots": context{"orders", "orders"},
              "saved_orders": state.phase.savedOrders
            }
          of "connections":
            let facts = maps.connections(
              variant, readConnections(variant, call.arguments)
            )
            state.phase.lookupFacts = %*{
              "source": "latest_connections_lookup", "connections": facts
            }
            state.persist(path)
            output = %*{"status": "ok", "connections": facts}
          of "notes":
            let updates = parseNoteUpdates(readNotes(call.arguments))
            state.notes.applyNoteUpdates(
              updates,
              state.phase.stamp,
              $state.gameId & ":" & $state.countryId & ":" &
                $state.phase.calls & ":" & call.id,
              model
            )
            state.persist(path)
            output = %*{"status": "ok", "notes": notesView(state.notes)}
          of "send_press":
            let
              messages = readPress(call.arguments)
              decisionId = $state.gameId & ":" & $state.countryId & ":" &
                $state.phase.calls & ":" & call.id
            state.toolDelivery = %*{
              "decision_id": decisionId, "phase": state.phase.stamp,
              "outcomes": pressOutcomes(messages)
            }
            state.persist(path)
            let delivery = acting.dispatchPress(
              context, messages, state, path, decisionId, toolDelivery = true
            )
            output = %*{
              "status": "ok", "confirmed_press": delivery.confirmed,
              "press_outcomes": delivery.outcomes
            }
          of "commit_orders":
            if integer(context{"game", "processTime"}) - int(epochTime()) < 10:
              raise newException(KutuzovError,
                "Too little time remains to commit and recover verified orders")
            acting.timeoutSeconds = actionTimeout(
              game.timeoutSeconds,
              integer(context{"game", "processTime"}),
              int(epochTime()),
              calls = 6
            )
            let
              action = readCommit(variant, call.arguments)
              turn = integer(context{"game", "turn"})
              checked = requiresCenterCheck(
                1901 + turn div 2 == game.endYear, turn mod 2 == 1
              )
            if checked and (action.centerCheck.strip.len == 0 or
                action.supportCheck.strip.len == 0):
              raise newException(KutuzovError,
                "Autumn and final-year commits require center and support checks")
            try:
              state.phase.rejectRepeatedOrders(action.orders)
              let saved = acting.saveOrdersVerified(
                context, action.orders, ready = false
              )
              state.phase.savedOrders = saved
              state.phase.repairAttempt = nil
              state.phase.feedback = ""
              failedCommit = false
              state.phase.ready = false
              if state.phase.wake.kind == ReviewWake:
                state.phase.reviewed = true
              state.persist(path)
              logEvent("orders_verified", %*{
                "phase": state.phase.stamp, "orders": saved,
                "ready": false, "task": task,
                "tool_id": call.id, "model": model,
                "center_check": action.centerCheck,
                "support_check": action.supportCheck
              })
              output = %*{
                "status": "ok", "orders_verified": true,
                "ready": false, "saved_orders": saved
              }
            except KutuzovError as error:
              state.phase.ready = false
              state.phase.captureRepairAttempt(
                Decision(orders: action.orders), task, error
              )
              state.persist(path)
              raise
          of "finish":
            if failedCommit or state.phase.feedback.len > 0 or
              not state.phase.repairView().isNil and
              state.phase.repairView().kind != JNull:
                raise newException(KutuzovError,
                  "finish requires a successful commit after the failed attempt")
            let
              action = readFinish(call.arguments)
              turn = integer(context{"game", "turn"})
            if state.phase.wake.kind == ReviewWake and
              requiresCenterCheck(1901 + turn div 2 == game.endYear,
                turn mod 2 == 1) and not state.phase.reviewed:
                raise newException(KutuzovError,
                  "Review finish requires a verified commit with center and support checks")
            if not acting.readyVerified(state, path, "model_finish"):
              result.phaseChanged = true
              output = %*{"status": "skipped", "reason": "phase_changed"}
            else:
              if action.stopSpending:
                state.stopped = true
                state.stopReason = action.reason
                logEvent("inference_stopped", %*{"reason": action.reason})
              state.endWake(path, ModelFinished)
              result.finished = true
              output = %*{
                "status": "ok", "ready": true,
                "orders_verified": state.phase.hasOrders(),
                "stop_spending": state.stopped
              }
          else:
            raise newException(KutuzovError, "Unknown tool: " & call.name)
      except KutuzovError as error:
        logError("tool_execution", error)
        let diagnostic = redactText(error.msg)
        if call.name == "commit_orders":
          failedCommit = true
          if state.phase.repairView().kind == JNull:
            state.phase.feedback = boundedText(diagnostic, 1600)
          state.persist(path)
        output = %*{
          "status": "error", "error": boundedText(diagnostic, 1600),
          "repair_attempt": state.phase.repairView()
        }
    logEvent("tool_result", %*{
      "phase": state.phase.stamp, "call": state.phase.calls,
      "tool_id": call.id, "tool": call.name, "output": output
    })
    let bounded = boundedResult(
      output, max(512, remaining - (calls.len - index - 1) * 512)
    )
    if bounded != output:
      result.rebase = true
    output = bounded
    remaining -= ($output).len
    outputs.add ToolResult(id: call.id, output: output)
  result.receipt = toolResultView(calls, outputs)

proc startPhaseWake*(
  phase: var PhaseState,
  cadence: WakeConfig,
  kind: WakeKind,
  now, deadline, reviewWindow: int
): bool =
  ## Keep optional press inference outside the reserved review time window.
  if kind == PressWake and deadline - now <= reviewWindow + 5:
    return false
  let boundary =
    if kind == PressWake:
      deadline - reviewWindow + cadence.saveSeconds
    else:
      deadline
  phase.wake.startWake(cadence, kind, now, boundary)

proc protectReviewTime*(
  phase: var PhaseState,
  deadline, reviewWindow: int
): bool =
  ## Bound optional initial continuations after a complete plan is verified.
  if phase.wake.kind == InitialWake and phase.hasOrders() and
    phase.wakeTask() == "plan":
      let boundary = min(phase.wake.deadline, deadline - reviewWindow)
      if boundary < phase.wake.deadline:
        phase.wake.deadline = boundary
        return true

proc runToolBot*() =
  ## Run explicit bounded tool wakes while the launcher owns the websocket.
  let
    game = loadGameConfig()
    model = loadRequestConfig()
    economy = getEnv("KUTUZOV_ECONOMY_MODEL")
    path = getEnv("KUTUZOV_STATE_PATH", getTempDir() / "kutuzov-state.json")
    cadence = defaultWakeConfig()
  var
    limits = loadBudgetConfig()
    state = restore(game, path, limits.mode, limits.toolLoop)
    instructions = ""
    board, history, publicMessages, variant: JsonNode
    publicVersion = ""
    failures = 0
  if not limits.toolLoop:
    raise newException(KutuzovError, "Tool runtime requires tool-loop mode")
  validateNotes(state.notes)
  cadence.validate()
  discard modelRates(model.model)
  if economy.len > 0:
    discard modelRates(economy)
  if model.api == ResponsesApi and model.apiKey.len == 0:
    raise newException(KutuzovError,
      "OPENAI_API_KEY is required outside hosting")
  logEvent("bot_start", %*{
    "game_id": game.gameId, "country_id": game.countryId,
    "end_year": game.endYear, "scoring": game.scoring,
    "model": model.model, "economy_model": economy,
    "budget_usd": limits.limitUsd, "budget_mode": $limits.mode,
    "tool_loop": true, "max_phase_calls": limits.maxPhaseCalls,
    "state_restored": fileExists(path), "stopped": state.stopped
  })
  while true:
    try:
      let
        context = game.fetchContext()
        phase = context{"game", "phase"}.getStr
        turn = integer(context{"game", "turn"})
        stamp = phaseStamp(context)
        year = 1901 + turn div 2
      if phase == "Finished" or horizonReached(turn, phase, game.endYear) or
        context{"member", "status"}.getStr in ["Defeated", "Resigned", "Left"]:
          logEvent("bot_return", %*{
            "reason": "finished_horizon_or_defeated", "phase": stamp,
            "spent_usd": state.budget.budgetSpent
          })
          return
      if phase notin ["Diplomacy", "Retreats", "Builds"] or
        context{"game", "processStatus"}.getStr == "Paused" or
        integer(context{"game", "processTime"}) <= 0:
          sleep(1000)
          continue
      if stamp != state.phase.stamp:
        if state.phase.wake.active:
          state.endWake(path, PhaseChanged)
        state.phase = PhaseState(
          stamp: stamp, savedOrders: newJArray(), transcript: newJArray()
        )
        state.persist(path)
        board = nil
        logEvent("phase_start", %*{
          "phase": stamp, "year": year,
          "deadline": context{"game", "processTime"},
          "order_slots": context{"orders", "orders"}.len
        })
      if board.isNil:
        let
          currentBoard = game.fetchBoard(context)
          currentHistory = game.fetchFile(context{"files", "history"})
        board = currentBoard
        history = currentHistory
      if instructions.len == 0:
        variant = game.fetchVariant(context)
        instructions = ToolPolicy & "\nMAP CATALOG JSON:\n" & $catalog(variant)
      let version = $context{"files", "messages"}
      if publicMessages.isNil or version != publicVersion:
        publicMessages = game.fetchFile(context{"files", "messages"})
        publicVersion = version
      let
        deadline = integer(context{"game", "processTime"})
        now = int(epochTime())
        remaining = deadline - now
        reviewWindow = min(cadence.durationSeconds, model.timeoutSeconds + 45)
        slots = context{"orders", "orders"}
        press = trimPress(
          visiblePress(context, publicMessages, turn), game.countryId, limits
        )
        unread = state.phase.unreadPress(press.messages)
        exhausted = state.stopped or state.phase.calls >= limits.maxPhaseCalls or
          state.phase.wake.count >= cadence.maxWakes and
          not state.phase.wake.active
      if slots.len == 0 or exhausted or remaining <= cadence.saveSeconds:
        if state.phase.wake.active:
          state.endWake(path, if remaining <= cadence.saveSeconds:
            TimeLimit else: RequestLimit)
        if not state.phase.ready:
          discard game.readyVerified(
            state, path, "resource_end_or_no_slots", allowDefault = true
          )
        sleep(1000)
        continue
      if not state.phase.wake.active:
        let kind = state.phase.wake.nextWake(
          cadence, now, deadline, state.phase.hasOrders(),
          state.phase.repairView(){"needs_repair"}.getBool or
            state.phase.feedback.len > 0,
          (if phase == "Diplomacy" and unread.len > 0 and
            state.phase.pressCalls < limits.maxPressCalls:
              press.signature else: ""),
          phase == "Diplomacy" and remaining <= reviewWindow
        )
        if kind == NoWake:
          sleep(1000)
          continue
        if not state.phase.startPhaseWake(
          cadence, kind, now, deadline, reviewWindow
        ):
          sleep(1000)
          continue
        if kind == PressWake:
          inc state.phase.pressCalls
        state.persist(path)
        logEvent("wake_start", %*{
          "phase": stamp, "wake": state.phase.wake.count,
          "kind": $kind, "deadline": state.phase.wake.deadline,
          "remaining_seconds": remaining
        })
      if state.phase.protectReviewTime(deadline, reviewWindow):
        state.persist(path)
      if state.phase.wake.calls >= cadence.maxRequests or
        state.phase.wake.remainingSeconds(cadence, now, deadline) < 5:
          let ending = if state.phase.wake.calls >= cadence.maxRequests:
            RequestLimit else: TimeLimit
          state.endWake(path, ending)
          if state.phase.hasOrders():
            discard game.readyVerified(state, path, "wake_resource_end")
          continue
      let task = state.phase.wakeTask()
      var selected = phaseModel(
        model, economy, limits.mode, task, year == game.endYear, year, phase
      )
      selected.timeoutSeconds = min(
        requestTimeout(model.timeoutSeconds, deadline, now),
        state.phase.wake.remainingSeconds(cadence, now, deadline)
      )
      let
        input = observation(
          game, context, board, history, press, state, limits, task, variant
        )
        reply = state.infer(
          limits, selected, instructions, input, year == game.endYear,
          path, economy, toolStep = true, reviewModelName = model.model
        )
      if reply.text.len == 0:
        state.endWake(path, BudgetLimit)
        if state.phase.hasOrders() or not reply.deferred:
          discard game.readyVerified(
            state, path, "inference_unavailable", allowDefault = true
          )
        sleep(1000)
        continue
      var
        receipt: JsonNode
        rebase = false
      try:
        let calls = parseToolCalls(reply.text)
        if calls.len == 0:
          raise newException(KutuzovError,
            "A reply must request a tool, including finish when done")
        let batch = executeTools(
          game, state, variant, calls, path, reply.model, task
        )
        receipt = batch.receipt
        rebase = batch.rebase
        if batch.phaseChanged:
          state.endWake(path, PhaseChanged)
      except KutuzovError as error:
        logError("tool_reply", error)
        receipt = %*{"error": redactText(error.msg), "executed": false}
      state.phase.recordExchange(reply.input, reply.text, receipt, limits)
      if rebase:
        state.phase.transcript = newJArray()
        state.phase.clearContinuation()
        logEvent("conversation_reset", %*{"reason": "tool_result_size_limit"})
      state.persist(path)
      failures = 0
    except KutuzovHttpError as error:
      logError("game_http", error)
      if error.status in [404, 410] and error.source == PlayerContext:
        logEvent("bot_return", %*{
          "reason": "game_unavailable", "http_status": error.status,
          "request_source": $error.source
        })
        return
      if error.status in [404, 410] and error.source == PublicAsset:
        board = nil
        history = nil
        publicMessages = nil
        publicVersion = ""
      inc failures
    except KutuzovRequestError as error:
      logError("inference_request", error)
      state.persist(path)
      inc failures
    except KutuzovError as error:
      logError("tool_tick", error)
      state.persist(path)
      inc failures
    if failures > 0:
      logEvent("retry_wait", %*{
        "failures": failures, "milliseconds": min(5000, 500 * failures),
        "phase": state.phase.stamp
      })
      sleep(min(5000, 500 * failures))
