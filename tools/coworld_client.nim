## Shared Coworld player websocket client.
## Every policy connects to COWORLD_PLAYER_WS_URL and speaks the game's
## JSON-over-websocket player protocol. This module owns the connection,
## ping/pong, and the receive loop; policies supply an onMessage callback.

import std/[json, options, os], whisky

export json

type CoworldClient* = ref object
  ws*: WebSocket
  name*: string

proc newCoworldClient*(name: string): CoworldClient =
  let url = getEnv("COWORLD_PLAYER_WS_URL")
  if url == "":
    quit(name & ": COWORLD_PLAYER_WS_URL is not set", 1)
  echo name, ": connecting to ", url
  CoworldClient(ws: newWebSocket(url), name: name)

proc send*(client: CoworldClient, message: JsonNode) =
  client.ws.send($message)

proc run*(client: CoworldClient, onMessage: proc(m: JsonNode)) =
  ## Receive loop: handles pings, parses JSON text messages, and hands
  ## them to onMessage. Returns when the socket closes.
  while true:
    var received: Option[Message]
    try:
      received = client.ws.receiveMessage()
    except CatchableError:
      echo client.name, ": websocket closed (", getCurrentExceptionMsg(), ")"
      break
    if received.isNone:
      continue
    let message = received.get()
    if message.kind == Ping:
      client.ws.send(message.data, Pong)
      continue
    if message.kind != TextMessage:
      continue
    var parsed: JsonNode
    try:
      parsed = parseJson(message.data)
    except CatchableError:
      echo client.name, ": bad JSON from server, ignoring"
      continue
    onMessage(parsed)
