## Zmey Gorynych — moba policy for Andre von Auto (wire entry).
## A command player: one JSON text message per tick each way
## (docs/protocol_player.md):
##   server -> {"tick": t, "obs": ["<base64 510B>", ... per hero]}
##   player -> {"tick": t, "actions": [[vy, vx, filter, q, w, e], ...]}
##   server -> {"done": true, "result": {...}} then close.
## All decisions live in brain.nim (ancient snipe). This file only
## speaks the lockstep protocol with bounded reconnects mirroring the
## upstream players/client.py: 403-style hard failures quit, drops are
## retried, progress resets the budget.

import
  std/[base64, json, options, os],
  whisky, brain

const
  connectAttempts = 240    ## initial dial: 240 x 500 ms = 2 minutes
  connectRetryMs = 500
  reconnectAttempts = 5    ## consecutive failures after first contact

proc main() =
  let url = getEnv("COWORLD_PLAYER_WS_URL",
                   getEnv("COGAMES_ENGINE_WS_URL"))
  if url == "":
    quit("gorynych: COWORLD_PLAYER_WS_URL is not set", 1)
  let policy = newBrain()

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
          quit("gorynych: game never accepted a connection", 1)
      else:
        inc failures
        if failures >= reconnectAttempts:
          quit("gorynych: reconnect budget exhausted", 1)
      sleep(connectRetryMs)
      continue
    if not everConnected:
      echo "gorynych: connected"
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
          echo "gorynych: episode done, result ", parsed{"result"}
          quit(0)
        if not parsed.hasKey("tick") or not parsed.hasKey("obs"):
          continue
        var rows: seq[string]
        for row in parsed["obs"].getElems():
          rows.add decode(row.getStr())
        var actions = newJArray()
        for action in policy.act(parsed["tick"].getInt(0), rows):
          var actionRow = newJArray()
          for v in action:
            actionRow.add(%v)
          actions.add(actionRow)
        socket.send($(%*{"tick": parsed["tick"], "actions": actions}))
        inc answered
    except CatchableError:
      echo "gorynych: socket closed (", getCurrentExceptionMsg(), ")"
    if answered > 0:
      failures = 0     # made progress: fresh reconnect budget
    inc failures
    if failures >= reconnectAttempts:
      quit("gorynych: connection closed before done, budget exhausted", 1)
    sleep(connectRetryMs)

main()
