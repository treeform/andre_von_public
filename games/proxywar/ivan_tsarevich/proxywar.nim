## proxywar — a Coworld Proxy War policy written in Nim.
##
## Speaks the coworld player protocol: connect to COWORLD_PLAYER_WS_URL, answer
## every decision_request with one offered LegalAction.id, exit on final.

import std/[json, net, options, os, strutils, sysrand, times]
import whisky
import observation, brain, deals, messages, responses

const captureEnv = "PROXYWAR_CAPTURE_DIR"

proc logLine(message: string) =
  echo message
  flushFile(stdout)

proc choiceIDs(choices: seq[Choice]): string =
  ## Join every selected action identifier for batch reachability audits.
  var ids = newSeqOfCap[string](choices.len)
  for choice in choices:
    ids.add(choice.id)
  ids.join(" + ")

proc captureRequest(directory: string, index: int, payload: string) =
  if directory.len == 0: return
  try:
    createDir(directory)
    writeFile(directory / ("request_" & align($index, 5, '0') & ".json"), payload)
  except CatchableError as error:
    logLine "capture failed: " & error.msg

proc closeGracefully(socket: WebSocket) =
  ## Send a real WebSocket close frame before dropping the connection.
  ##
  ## `whisky.close` only does `ws.socket.close()` — it slams the TCP socket
  ## shut without ever sending opcode 0x8. The game server is Node's `ws`,
  ## which reports that as "no close frame received or sent", and that is
  ## exactly how Competition round 1227 failed. Since a failed round scores
  ## zero for all nineteen entrants, and 8 of the last 13 rounds failed, this
  ## is worth getting right.
  ##
  ## RFC 6455: a client frame must be masked. FIN + opcode 8, mask bit set,
  ## two-byte payload carrying status 1000 (normal closure).
  try:
    var mask = newString(4)
    if not urandom(mask.toOpenArrayByte(0, 3)):
      socket.close()
      return
    socket.socket.send(closeFrame(mask))
  except CatchableError as error:
    logLine "close frame failed: " & error.msg
  socket.close()

proc lingerForPlatform() =
  ## The bundled starter player holds its process open briefly after `final`
  ## inside a pod: the platform's terminal reconciliation failed whole episodes
  ## with "pod ... not found" when player pods self-exited and were cleaned up
  ## before the reconciler looked (its own comment cites league rounds
  ## 1127/1128/1130). Armed only in Kubernetes so `coworld run-episode`, which
  ## waits for the container to exit, is not delayed locally.
  if getEnv("KUBERNETES_SERVICE_HOST").len == 0 and
      getEnv("PROXYWAR_FORCE_LINGER") != "1":
    return
  var milliseconds = 20_000
  let configured = getEnv("PROXYWAR_PLAYER_POST_FINAL_LINGER_MS")
  if configured.len > 0:
    try: milliseconds = parseInt(configured) except ValueError: discard
  if milliseconds <= 0: return
  logLine "lingering " & $milliseconds & "ms after final for reconciliation"
  sleep(milliseconds)

proc main*() =
  let url = getEnv("COWORLD_PLAYER_WS_URL")
  if url.len == 0:
    quit("COWORLD_PLAYER_WS_URL is required", 1)
  let captureDir = getEnv(captureEnv)
  let dumpRequests = getEnv("PROXYWAR_DUMP") == "1"

  let weights = weightsFromEnvironment()

  ## Connect with retries inside the platform's 120 s player-connect window.
  ##
  ## `newWebSocket` raises if the server is not listening yet, and a single
  ## attempt means the process dies on the spot — which the platform reports as
  ## `player_never_started` and which fails the round for all twelve seats.
  ## That is the dominant failure mode in this league (rounds 1215, 1216, 1222,
  ## 1223 and 1226), and round 1226 was ours.
  var socket: WebSocket
  var attempt = 0
  let deadline = epochTime() + 110.0
  while true:
    inc attempt
    try:
      socket = newWebSocket(url)
      break
    except CatchableError as error:
      if epochTime() >= deadline:
        logLine "giving up connecting after " & $attempt & " attempts: " &
          error.msg
        raise
      logLine "connect attempt " & $attempt & " failed (" & error.msg &
        "); retrying"
      sleep(1000)
  logLine "proxywar connected profile=" & weights.name & " after " &
    $attempt & " attempt(s)"

  var memory = Memory()
  var dealMemory = DealMemory()
  var messageMemory = MessageMemory()
  var requestCount = 0
  var lastPhase = ""

  while true:
    let message = socket.receiveMessage()
    if message.isNone:
      logLine "socket closed"
      break
    let frame = message.get()
    if frame.kind == BinaryMessage:
      continue

    var payload: JsonNode
    try:
      payload = parseJson(frame.data)
    except CatchableError as error:
      logLine "bad json: " & error.msg
      continue

    let kind = observation.getStr(payload, "type")
    if kind == "final":
      logLine "episode final after " & $requestCount & " decisions" &
        " (expansions=" & $memory.expansions & " attacks=" & $memory.attacks &
        " builds=" & $memory.builds & " messages=" & $messageMemory.sent &
        " deals=" & $dealMemory.selected & ")"
      closeGracefully(socket)
      lingerForPlatform()
      break
    if kind != "decision_request":
      continue

    inc requestCount
    if captureDir.len > 0 and requestCount <= 400:
      captureRequest(captureDir, requestCount, frame.data)
    if dumpRequests and requestCount <= 400:
      ## One raw request per line so the saved player log doubles as a corpus
      ## for tools/replay_decisions.nim.
      logLine "RAWREQ " & frame.data

    let request = payload{"request"}
    var world: Observation
    var actions: seq[Action]
    try:
      world = parseObservation(request{"observation"})
      actions = parseActions(request{"legalActions"})
    except CatchableError as error:
      logLine "observation parse failed: " & error.msg
      actions = @[]
    if actions.len == 0:
      logLine "decision " & $requestCount & " had no legal actions"
      continue

    let gameplayActions = dealGameplayActions(
      weights.structuredDeals,
      world,
      actions
    )
    let started = epochTime()
    ## A throw here would kill the episode for every seat and, after three
    ## consecutive failed rounds, disqualify the membership — so a broken
    ## decision degrades to a legal one instead of taking the process down.
    var choice: Choice
    try:
      choice = decide(weights, world, memory, gameplayActions)
    except CatchableError as error:
      logLine "decision failed, falling back: " & error.msg
      choice = Choice(
        id: gameplayActions[0].id,
        kind: gameplayActions[0].kind,
        reason: "fallback after error")
      for action in gameplayActions:
        if action.kind == "hold":
          choice = Choice(id: action.id, kind: action.kind,
            reason: "hold fallback after error")
          break
    let elapsed = epochTime() - started

    if world.phase != lastPhase:
      lastPhase = world.phase
      logLine "phase -> " & world.phase
    let underPressure = world.incomingAttacks > 0 or
      world.strategicPriority == "build_defense"
    if requestCount <= 5 or requestCount mod 25 == 0 or underPressure:
      logLine "d" & $requestCount & " turn=" & $world.turnNumber &
        " tiles=" & $int(world.ownTiles) & " share=" &
        formatFloat(world.ownTileShare, ffDecimal, 3) &
        " troops=" & $int(world.troops) &
        " ratio=" & formatFloat(world.troopRatio, ffDecimal, 2) &
        " gold=" & $int(world.gold) &
        " rivals=" & $world.aliveRivals &
        " spawn=" & $world.spawnTile &
        " danger=" & world.homeDanger &
        " strategy=" & world.strategicPriority & "/" &
        world.strategicUrgency &
        " incoming=" & $world.incomingAttacks &
        " landFronts=" & $world.landFrontAttacks &
        " spatial=" & $world.spatialTrusted &
        " outgoing=" & $world.outgoingAttacks &
        " losses=" & $memory.losingStreak &
        " digIn=" & $collapseDefenseActive(weights, world, memory) &
        " -> " & choice.kind & " (" & choice.id & ") score=" &
        formatFloat(choice.score, ffDecimal, 1) &
        " in " & formatFloat(elapsed * 1000.0, ffDecimal, 1) & "ms"

    var choices = @[choice]
    try:
      choices = batchedChoices(
        weights,
        world,
        memory,
        gameplayActions,
        choice,
        protocolActionLimit(payload)
      )
    except CatchableError as error:
      logLine "batch selection failed, using scalar: " & error.msg
    if choices.len > 1:
      logLine "batching " & choiceIDs(choices)
    let messageMove = chooseMessageMove(
      weights.borderChat,
      payload,
      world,
      actions,
      messageMemory
    )
    if messageMove.id.len > 0:
      logLine "messaging " & messageMove.id
    let dealMove = chooseDealMove(
      weights.structuredDeals,
      world,
      actions,
      dealMemory,
      choice.id
    )
    if dealMove.id.len > 0:
      logLine "dealing " & dealMove.id
    let response = decisionResponse(payload, choices, messageMove, dealMove)
    socket.send($response)

when isMainModule:
  main()
