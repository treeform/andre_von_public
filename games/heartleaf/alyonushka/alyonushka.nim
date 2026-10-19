## Alyonushka — Heartleaf policy for Andre von Auto.
##
## Heartleaf players are soul files: since heartleaf 0.2.0 the game itself
## plays every gnome from the soul its player uploads (the platform runs
## the LLM harness in the game pod). This player container is therefore a
## thin soul uploader, a trimmed Nim port of coworld-heartleaf's shared
## players/soul_player/soul_player.nim: connect to the /player websocket,
## send the soul file as one text frame, wait for "soul accepted", ask for
## the model log with log-ready, then idle answering pings while the game
## streams the gnome's transcript (printed to stdout for log collectors).
##
## The strategy IS the soul: soul.md here is our coolbot v10 champion soul
## plus the 8-food host gate (jolly host-in-chief — gather hard all morning,
## host only with eight or more foods and a confirmed yes, else guest for
## unseen foods, never repeat a line). It is embedded at compile time and
## can be overridden with --soul or HEARTLEAF_SOUL_PATH.
##
## Env:
##   COGAMES_ENGINE_WS_URL / COWORLD_PLAYER_WS_URL   player websocket url
##   HEARTLEAF_SOUL_PATH                             soul file override

import std/[json, os, parseopt, strutils, times, unicode], whisky

const
  embeddedSoul = staticRead("soul.md")
  soulShebang = "#!"
  soulMaxBytes = 32_768
  soulModelIdMaxChars = 128
  soulModelIdChars = {'a'..'z', 'A'..'Z', '0'..'9', '.', '-', '_', ':', '/'}
  acceptedPrefix = "soul accepted"
  rejectedPrefix = "soul rejected:"
  connectRetryMs = 1000
  replyTimeoutMs = 60_000
  replyPollMs = 1000
  reconnectGiveUpSeconds = 8.0
  defaultConnectTimeoutSeconds = 120.0

  exitUsage = 1
  exitNoConnection = 2
  exitRejected = 3

type
  PlayerOptions = object
    url: string
    soulPath: string
    connectTimeoutSeconds: float
    once: bool

  SoulError = object of CatchableError

proc validateSoul(raw: string): string =
  ## Checks the soul the way the game's parseSoul does and returns the
  ## model id from the shebang line. Raises SoulError with the reason.
  if raw.len == 0:
    raise newException(SoulError, "soul is empty")
  if raw.len > soulMaxBytes:
    raise newException(SoulError,
      "soul is " & $raw.len & " bytes, the limit is " & $soulMaxBytes)
  if '\0' in raw:
    raise newException(SoulError, "soul contains a NUL byte")
  if validateUtf8(raw) != -1:
    raise newException(SoulError, "soul is not valid UTF-8")
  let text = raw.replace("\r\n", "\n").replace('\r', '\n')
  let lineEnd = text.find('\n')
  let firstLine = if lineEnd < 0: text else: text[0 ..< lineEnd]
  if not firstLine.startsWith(soulShebang):
    raise newException(SoulError,
      "first line must be " & soulShebang & "<bedrock model id>")
  let modelId = firstLine[soulShebang.len .. ^1].strip()
  if modelId.len == 0:
    raise newException(SoulError, "shebang line names no model")
  if modelId.len > soulModelIdMaxChars:
    raise newException(SoulError, "model id is longer than " &
      $soulModelIdMaxChars & " characters")
  for c in modelId:
    if c notin soulModelIdChars:
      raise newException(SoulError,
        "model id has an unexpected character: " & $c)
  let body = if lineEnd < 0: "" else: text[lineEnd + 1 .. ^1]
  if body.strip().len == 0:
    raise newException(SoulError, "soul has no text after the shebang line")
  modelId

proc parseOptions(): PlayerOptions =
  ## Reads options from the environment and the command line.
  result = PlayerOptions(
    url: getEnv("COGAMES_ENGINE_WS_URL"),
    soulPath: getEnv("HEARTLEAF_SOUL_PATH"),
    connectTimeoutSeconds: defaultConnectTimeoutSeconds
  )
  if result.url.len == 0:
    result.url = getEnv("COWORLD_PLAYER_WS_URL")
  for kind, key, value in getopt():
    case kind
    of cmdLongOption, cmdShortOption:
      case key
      of "url": result.url = value
      of "soul": result.soulPath = value
      of "connect-timeout-seconds":
        result.connectTimeoutSeconds = parseFloat(value)
      of "once": result.once = true
      else:
        echo "alyonushka unknown option --", key
        quit(exitUsage)
    else:
      discard

proc awaitReply(ws: WebSocket): string =
  ## Waits for the game's accepted or rejected reply, answering pings.
  let deadline = epochTime() + replyTimeoutMs / 1000
  while epochTime() < deadline:
    let message = ws.receiveMessage(replyPollMs)
    if message.isNone:
      continue
    case message.get().kind
    of Ping:
      ws.send(message.get().data, Pong)
    of TextMessage:
      let text = message.get().data
      if text.startsWith(acceptedPrefix) or text.startsWith(rejectedPrefix):
        return text
    of BinaryMessage, Pong:
      discard
  raise newException(CatchableError, "no reply to the soul within " &
    $(replyTimeoutMs div 1000) & "s")

type
  LogCursor = ref object
    ## Last (game, sequence) log frame seen, so a reconnect resumes the
    ## model log stream instead of downloading the backlog again.
    game: int
    sequence: int

proc readyText(cursor: LogCursor): string =
  ## The handshake that starts the log stream.
  if cursor.sequence >= 0:
    "log-cursor game=" & $cursor.game & " sequence=" & $cursor.sequence
  else:
    "log-ready"

proc record(cursor: LogCursor, line: string) =
  ## Prints one model log frame, skipping records already seen.
  var game = 0
  var sequence = -1
  try:
    let node = parseJson(line)
    game = node{"game"}.getInt(0)
    sequence = node{"sequence"}.getInt(-1)
  except CatchableError:
    discard
  if sequence >= 0:
    if game == cursor.game and sequence <= cursor.sequence:
      return
    cursor.game = game
    cursor.sequence = sequence
  echo line

proc idle(ws: WebSocket, cursor: LogCursor) =
  ## Keeps the socket open until the game closes it, answering pings and
  ## recording every model log frame the game streams.
  while true:
    let message = ws.receiveMessage(-1)
    if message.isNone:
      continue
    case message.get().kind
    of Ping:
      ws.send(message.get().data, Pong)
    of TextMessage:
      cursor.record(message.get().data)
    of BinaryMessage, Pong:
      discard

proc run(options: PlayerOptions, soul: string) =
  ## Uploads the soul, then idles and reconnects until the game is gone.
  let startedAt = epochTime()
  let cursor = LogCursor(sequence: -1)
  var
    accepted = false
    disconnectedAt = 0.0
  while true:
    try:
      let ws = newWebSocket(options.url)
      echo "alyonushka connected ", options.url
      disconnectedAt = 0.0
      ws.send(soul, TextMessage)
      let reply = ws.awaitReply()
      echo "alyonushka ", reply
      if reply.startsWith(rejectedPrefix):
        ws.close()
        quit(exitRejected)
      accepted = true
      if options.once:
        ws.close()
        quit(0)
      ws.send(cursor.readyText(), TextMessage)
      ws.idle(cursor)
    except CatchableError as e:
      echo "alyonushka reconnecting: ", e.msg
      if not accepted and
          epochTime() - startedAt > options.connectTimeoutSeconds:
        echo "alyonushka could not connect within ",
          options.connectTimeoutSeconds, "s, exiting"
        quit(exitNoConnection)
      if accepted:
        if disconnectedAt == 0.0:
          disconnectedAt = epochTime()
        elif epochTime() - disconnectedAt > reconnectGiveUpSeconds:
          echo "alyonushka server gone for ", reconnectGiveUpSeconds,
            "s, exiting"
          quit(0)
      sleep(connectRetryMs)

proc main() =
  let options = parseOptions()
  if options.url.len == 0:
    echo "alyonushka needs --url or COGAMES_ENGINE_WS_URL / " &
      "COWORLD_PLAYER_WS_URL"
    quit(exitUsage)
  var soul = embeddedSoul
  var source = "embedded soul.md"
  if options.soulPath.len > 0 and fileExists(options.soulPath):
    soul = readFile(options.soulPath)
    source = options.soulPath
  var modelId: string
  try:
    modelId = validateSoul(soul)
  except SoulError as e:
    echo "alyonushka invalid soul ", source, ": ", e.msg
    quit(exitUsage)
  echo "alyonushka soul ", source, " model=", modelId,
    " bytes=", soul.len
  run(options, soul)

when isMainModule:
  main()
