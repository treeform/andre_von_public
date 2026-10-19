## Ovinnik — Rware Warehouse policy for Andre von Auto.
## The rware-warehouse seat is a Sprite v1 client and deliberately thin:
## it dials COWORLD_PLAYER_WS_URL, sends ONE Sprite v1 chat frame (0x81)
## carrying its registration {"policy","prompt","scripted"} (this game's
## registration carries no "type" field - docs/PROTOCOL.md), re-sends it
## over the first ~10 s of frames (joins are slot-sequential and the
## lobby sends frames before a seat is admitted), and then only receives;
## every decision is made inside the game server. The prompt IS the
## strategy. Ported from coworld-ctf's paintball_player pattern.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (shuttle | courteous)
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays scripted.

import std/[json, options, os, strutils], whisky

const
  ConnectAttempts = 240      ## 240 x 500 ms = 2 minutes of dialling.
  ConnectRetryMs = 500
  RegistrationResends = 10   ## re-sends after the first, ~1 s apart.
  ResendEveryFrames = 24     ## ~1 s of frames at 24 Hz.
  ReconnectAttempts = 6

const defaultPrompt = """
You are Ovinnik, the barn spirit. The league reads FLEET deliveries; your
own count is a tie-break epsilon. Jams are the only way to lose, and the
one-wide aisles plus the workstation queue lane are where they happen.
Order of decision every turn:
1. Read the radio first and honour every claim in it.
2. Loaded with an UNREQUESTED shelf: stow it now. Pick a free slot OFF
   the station approach columns and off the middle lane; say the cell.
3. Loaded with a REQUESTED shelf: deliver. If the radio shows another
   robot heading to one station, take the other; otherwise the nearer.
   Enter the queue lane only when actually delivering, and leave it by
   stowing immediately after.
4. Otherwise fetch the nearest request-board shelf that no radio claim
   covers and no visible robot is closer to. Claim it by id and route:
   say like "taking S12 down col 3".
5. Claim collisions: the alphabetically earlier alias keeps the shelf,
   the later switches on the spot and says so.
JAMS: if you are named in the jam or blocked_ticks_last_turn is 8 or
more, someone must yield NOW. Yield when the robot facing you is loaded
and you are not; if both or neither, yield when your alias is
alphabetically later. After yielding one turn, re-issue your order.
Never hold while blocked - hold is how a jam becomes permanent.
If your last_order_result is shelf_gone, no_path or no_free_slot, do not
repeat the order: pick a different shelf, station or slot.
RADIO every turn (under 120 runes): your order, your next column, and
any lane you need kept clear. notes: your claim and your planned stow
slot for next turn.
"""

proc registrationBlob(prompt, scripted, policy: string): string =
  ## One Sprite v1 chat frame: 0x81, u16 little-endian length, ASCII
  ## payload (the chat parser drops bytes outside 32..126, so the JSON
  ## and the prompt stay pure ASCII).
  var node = %*{"policy": policy, "prompt": prompt}
  if scripted.len > 0:
    node["scripted"] = %scripted
  else:
    node["scripted"] = newJNull()
  let text = $node
  result = newString(3 + text.len)
  result[0] = char(0x81)
  result[1] = char(text.len and 0xff)
  result[2] = char((text.len shr 8) and 0xff)
  for i in 0 ..< text.len:
    result[3 + i] = text[i]

when isMainModule:
  let url = getEnv("COWORLD_PLAYER_WS_URL")
  if url.len == 0:
    quit("ovinnik: COWORLD_PLAYER_WS_URL is not set", 1)
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED").strip()
    label = "Ovinnik"
  echo "ovinnik: kind=", (if scripted.len > 0: "scripted" else: "llm"),
    " baseline=", (if scripted.len > 0: scripted else: "none")

  proc dial(attempts: int): WebSocket =
    ## Bounded dialling: the first dial routinely lands on a closed port.
    for attempt in 0 ..< attempts:
      try:
        return newWebSocket(url)
      except CatchableError as error:
        if attempt == 0:
          echo "ovinnik: game not listening yet (", error.msg, "); retrying"
        sleep(ConnectRetryMs)
    nil

  var socket = dial(ConnectAttempts)
  if socket == nil:
    quit("ovinnik: game never accepted a connection", 1)
  echo "ovinnik: connected"

  # whisky's receiveMessage raises on a close frame, and the game's own
  # quit(0) can outrun its last flushed frame - a dead socket after frames
  # were seen is a normal episode end, so exit 0 there (docs/PROTOCOL.md
  # names this exact race).
  var reconnects = 0
  while true:
    var sessionFrames = 0
    try:
      socket.send(registrationBlob(prompt, scripted, label), BinaryMessage)
      var resends = 0
      while true:
        let received = socket.receiveMessage()
        if received.isNone:
          continue                    ## a read timeout, not a closed socket
        inc sessionFrames
        if resends < RegistrationResends and
            sessionFrames mod ResendEveryFrames == 1:
          inc resends
          socket.send(registrationBlob(prompt, scripted, label),
            BinaryMessage)
    except CatchableError as error:
      echo "ovinnik: socket closed (", error.msg, ")"
    # A dropped seat's robot falls back to courteous until reconnect; a
    # session that never received a frame means the game is winding down.
    if sessionFrames == 0 or reconnects >= ReconnectAttempts:
      break
    inc reconnects
    echo "ovinnik: re-dialling the seat (attempt ", reconnects, ")"
    socket = dial(ReconnectAttempts)
    if socket == nil:
      echo "ovinnik: game is no longer listening, exiting cleanly"
      break
    echo "ovinnik: reconnected, re-registering"
  quit(0)
