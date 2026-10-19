## Buyan — nmmo policy for Andre von Auto.
## A command player speaking wire protocol v2 (docs/protocol_player.md):
##   server -> {"tick": t, "obs": ["<base64 1707B>", ...], "resets": [...]}
##   player -> {"tick": t, "actions": [[a], ... one int per agent]}
##   server -> {"done": true, "result": {...}} then close.
##
## Decision engine: the upstream PufferLib pretrained MMONet, ported to
## pure Nim in mmonet.nim and run on the unchanged public weights
## (nmmo3_weights.bin, the exact network the sim was trained with). One
## recurrent brain per agent the seat controls; a resets[j] flag zeroes
## that brain's MinGRU state before it sees the new life's first obs,
## exactly like the demo forward() handles env terminals. Actions are
## sampled from the softmax like the demo, from a per-brain splitmix64
## stream seeded by COGAME_PLAYER_SEED and the agent index.
##
## Observation encoding follows the weights: the legacy 512 x 4 network was
## trained on the window-relative stale entity bytes, so it never asks for
## obs=clean; the PufferLib 5.0 1024 x 4 network was trained with
## clear_stale_entities=1, which is exactly obs=clean, so it always does.

import
  std/[base64, json, os, strutils],
  whisky,
  mmonet, guard, scripted

## Wire constants

const
  noopAction = 4
  connectAttempts = 240    ## initial dial: 240 x 500 ms = 2 minutes
  connectRetryMs = 500
  reconnectAttempts = 5
  statusEveryTicks = 1000
  defaultWeightsPath = "nmmo3_weights.bin"

type Seat = object
  weights: Weights
  seed: uint64
  temperature: float32    ## BUYAN_TEMPERATURE: 1 = reference, <= 0 argmax
  guardEarly: bool        ## BUYAN_GUARD=early: fragile-life flee override
  stallTicks: int         ## BUYAN_STALL: sample once a window stalls this long
  scriptedEngine: bool    ## BUYAN_ENGINE=scripted: rules instead of the net
  brains: seq[Brain]
  guards: seq[Guard]
  minds: seq[Mind]
  resets: seq[int]        ## per-agent reset count, for hosted log proof
  lifeTicks: seq[int]     ## ticks since the agent's last reset
  windowMins: seq[int]    ## min(comb, prof) at the current 500-tick window start
  stalls: seq[int]        ## per-agent count of sampled (stall) ticks
  ticks: int

## Stagnation window (nmmo3.h:1926-1940): every 500 ticks of a life the sim
## compares min(comb, prof) with its value at the window start and resets
## the agent in place when it has not risen. Window index starts at 0 on
## spawn.

const
  stagnationWindow = 500
  scalarCombat = 1650 + 1
  scalarProfession = 1650 + 7

proc ensureAgent(seat: var Seat, index: int) =
  while seat.brains.len <= index:
    if not seat.scriptedEngine:
      seat.brains.add(newBrain(seat.weights,
        seat.seed * 1_000_003'u64 + uint64(seat.brains.len) * 7919'u64 + 1))
    else:
      seat.brains.add(Brain())
    seat.minds.add(newMind(seat.seed, seat.minds.len))
    seat.guards.add(newGuard())
    seat.resets.add(0)
    seat.lifeTicks.add(0)
    seat.windowMins.add(1)
    seat.stalls.add(0)

proc act(seat: var Seat, index: int, observation: string,
         reset: bool): int =
  ## One agent's action for this tick; malformed rows play no-op.
  if observation.len != mmonet.ObservationSize:
    return noopAction
  var bytes = newSeq[uint8](mmonet.ObservationSize)
  for i in 0 ..< mmonet.ObservationSize:
    bytes[i] = uint8(observation[i])
  seat.ensureAgent(index)
  if reset:
    if not seat.scriptedEngine:
      seat.brains[index].reset()
    if seat.scriptedEngine and seat.minds[index].trace.len > 0:
      echo "buyan: death agent ", index, " trace ", seat.minds[index].trace.join(" | ")
    seat.minds[index].reset()
    seat.guards[index].reset()
    inc seat.resets[index]
    seat.lifeTicks[index] = 0
  if seat.scriptedEngine:
    inc seat.lifeTicks[index]
    return seat.minds[index].decide(bytes, seat.ticks)
  let currentMin = min(int(bytes[scalarCombat]), int(bytes[scalarProfession]))
  let phase = seat.lifeTicks[index] mod stagnationWindow
  if phase == 0:
    seat.windowMins[index] = currentMin
  var temperature = seat.temperature
  if seat.stallTicks > 0 and phase >= seat.stallTicks and
      currentMin <= seat.windowMins[index]:
    temperature = 1'f32       # the window is stalling: break the loop
    inc seat.stalls[index]
  inc seat.lifeTicks[index]
  result = seat.brains[index].act(bytes, temperature)
  if seat.guardEarly:
    result = seat.guards[index].decide(bytes, result)

proc overrides(seat: Seat): seq[int] =
  for g in seat.guards:
    result.add(g.overrides)

proc scriptedCounters(seat: Seat): string =
  ## fights/flees/hunts/harvests/buys/sells/heals/equips per agent.
  for m in seat.minds:
    if result.len > 0:
      result.add(" ")
    result.add($m.fights & "/" & $m.flees & "/" & $m.hunts & "/" &
      $m.harvests & "/" & $m.buys & "/" & $m.sells & "/" & $m.heals & "/" &
      $m.equips)

proc temperatureFromEnv(): float32 =
  ## BUYAN_TEMPERATURE, default 1 (the reference sampler).
  let raw = getEnv("BUYAN_TEMPERATURE")
  if raw.len == 0:
    return 1'f32
  try:
    result = float32(parseFloat(raw.strip()))
  except CatchableError:
    result = 1'f32

proc playerSeed(): uint64 =
  ## COGAME_PLAYER_SEED as an unsigned stream seed; 0 when unset or odd.
  let raw = getEnv("COGAME_PLAYER_SEED")
  if raw.len == 0:
    return 0
  try:
    result = uint64(parseBiggestInt(raw.strip()))
  except CatchableError:
    result = 0

proc main() =
  var url = getEnv("COWORLD_PLAYER_WS_URL",
                   getEnv("COGAMES_ENGINE_WS_URL"))
  if url == "":
    quit("buyan: COWORLD_PLAYER_WS_URL is not set", 1)
  let weightsPath = getEnv("BUYAN_WEIGHTS", defaultWeightsPath)
  var seat = Seat(seed: playerSeed(), temperature: temperatureFromEnv(),
                  guardEarly: getEnv("BUYAN_GUARD") == "early",
                  scriptedEngine: getEnv("BUYAN_ENGINE") == "scripted")
  try:
    seat.stallTicks = parseInt(getEnv("BUYAN_STALL", "0").strip())
  except CatchableError:
    seat.stallTicks = 0
  if seat.scriptedEngine:
    # The rules want truthful entity bytes (patch 0003, per-seat opt-in).
    url.add(if url.contains('?'): "&obs=clean" else: "?obs=clean")
    echo "buyan: scripted engine, obs=clean, seed=", seat.seed
  else:
    try:
      seat.weights = loadWeights(weightsPath)
    except MmonetError as error:
      quit("buyan: " & error.msg, 1)
    if seat.weights.cleanObservations:
      url.add(if url.contains('?'): "&obs=clean" else: "?obs=clean")
    echo "buyan: mmonet weights loaded params=", seat.weights.layout.total,
      " hidden=", seat.weights.layout.hidden,
      " layers=", seat.weights.layout.gruLayers,
      " obs=", (if seat.weights.cleanObservations: "clean" else: "legacy"),
      " seed=", seat.seed, " temperature=", seat.temperature,
      " guard=", (if seat.guardEarly: "early" else: "off"),
      " stall=", seat.stallTicks

  var attemptsLeft = connectAttempts
  var failures = 0
  var everConnected = false
  while true:
    var socket: WebSocket
    try:
      socket = newWebSocket(url)
    except CatchableError:
      if not everConnected:
        dec attemptsLeft
        if attemptsLeft <= 0:
          quit("buyan: game never accepted a connection", 1)
      else:
        inc failures
        if failures >= reconnectAttempts:
          quit("buyan: reconnect budget exhausted", 1)
      sleep(connectRetryMs)
      continue
    if not everConnected:
      echo "buyan: connected"
    everConnected = true

    var answered = 0
    try:
      while true:
        let received = socket.receiveMessage()
        if received.isNone:
          continue
        let message = received.get()
        if message.kind == Ping:
          socket.send(message.data, Pong)
          continue
        if message.kind != TextMessage:
          continue
        var parsed: JsonNode
        try:
          parsed = parseJson(message.data)
        except CatchableError:
          continue
        if parsed{"done"}.getBool(false):
          echo "buyan: episode done, resets=", seat.resets,
            " overrides=", seat.overrides, " stalls=", seat.stalls,
            " scripted=", seat.scriptedCounters, " result ", parsed{"result"}
          quit(0)
        if not parsed.hasKey("tick") or not parsed.hasKey("obs"):
          continue
        let rows = parsed["obs"].getElems()
        let resets = parsed{"resets"}.getElems()
        var actions = newJArray()
        for i, row in rows:
          let reset = i < resets.len and resets[i].getBool(false)
          var actionRow = newJArray()
          actionRow.add(%seat.act(i, decode(row.getStr()), reset))
          actions.add(actionRow)
        socket.send($(%*{"tick": parsed["tick"], "actions": actions}))
        inc answered
        inc seat.ticks
        if seat.ticks mod statusEveryTicks == 0:
          echo "buyan: tick ", parsed["tick"], " agents ", rows.len,
            " resets=", seat.resets, " overrides=", seat.overrides,
            " stalls=", seat.stalls, " scripted=", seat.scriptedCounters
    except CatchableError:
      echo "buyan: socket closed (", getCurrentExceptionMsg(), ")"
    if answered > 0:
      failures = 0     # made progress: fresh reconnect budget
    inc failures
    if failures >= reconnectAttempts:
      quit("buyan: connection closed before done, budget exhausted", 1)
    sleep(connectRetryMs)

main()
