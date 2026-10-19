## Konyok-Gorbunok — Flatland policy for Andre von Auto.
## The flatland player container is deliberately thin: it dials its seat,
## sends one Sprite v1 chat frame (0x81) carrying its registration
## ({"type":"register","policy","prompt","scripted"} — the server skips
## any blob whose type is not "register"), then only acknowledges frames
## with the Ready packet (0x85). The GAME server runs every decision.
##
## Default is the published `yielder` baseline, not the LLM prompt: the
## server sets isLlm from prompt.len > 0 (src/flatland/server.nim), so a
## non-empty prompt would ignore the baseline. Yielder is the sweep-tuned
## published default and the mixed-table convention (yieldAfter=12,
## lowerIdYields=false). Score is 1000*fleetOnTime for every seat; a
## yield-convention mismatch deadlocks the network.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED play a scripted baseline (yielder | timetable).
##                   Defaults to yielder. Empty string forces the prompt.
## Upload note: default is scripted, so no Bedrock flag is required. The
## anthropic key is injected into the GAME pod; the player pod makes no
## LLM call (docs/protocol_player.md, "Where the LLM call happens").

import std/[json, options, os, strutils], whisky

const
  connectAttempts = 240      ## 240 x 500 ms = 2 minutes of dialling.
  connectRetryMs = 500
  registrationResends = 10   ## re-sends after the first, spread over ~10 s.
  resendEveryFrames = 4
  reconnectAttempts = 6

const defaultPrompt = """
You are Konyok-Gorbunok, a tireless little magic horse dispatching six of
the network's twenty-four trains. THE SCORE IS SHARED: 1000 points per
ON-TIME train anywhere on the network, 10 per arrival, and your own
on-time trains are worth at most 6 as a tie-break. Never win 6 by costing
anyone 1000 — the only way to score is to make the WHOLE network run.
Rules of thumb, in priority order:
1. Deadlocks are permanent and are the only real way to lose. Before
   letting any train commit to a single-track section, check
   block_occupancy for an opposing train already inside it or about to
   enter from the far end. If there is one, order siding before the
   section or hold — never enter and hope.
2. Commit early. A siding order after a train has entered a section does
   nothing. Act while next_decision.eta_ticks is still more than two
   turns (32+ ticks) away; when in doubt, side one turn earlier than you
   think you must.
3. Stagger departures. Release a waiting train only when the first two
   sections of route_next are clear or lightly used; otherwise hold it.
   A train waiting at its platform occupies nothing and risks nothing.
4. Yield deterministically. When two trains face off over a section, the
   LOWER train id has priority: if yours has the higher id, side it at
   the nearest siding; if yours has the lower id, keep it running and say
   so on the radio. One yielder per pair clears every queue.
5. A malfunctioning train is a temporary wall, never a deadlock. Do not
   queue more trains behind it: hold followers, or "route via" a
   junction on a parallel road around the blockage. Watch
   malfunction_left to time the release.
6. If network_status.deadlock ever names one of your trains, it is gone
   forever. Spend nothing on it; reroute your other trains away from the
   deadlock_cells and shepherd the remaining five home.
7. Slack is only 24 ticks, but a siding wait of a turn or two still
   usually arrives on time. Late beats stranded, always.
8. Use the radio EVERY turn: claim sections ("T13 has J4-J5 westbound,
   hold opposing until clear"), announce sidings and releases, and honor
   other dispatchers' claims — they can see your trains but not your
   plans. Silence causes head-on meets.
9. Keep notes: your section claims, promised holds, and the release
   order for your waiting trains. Trust your notes over memory.
Reply with exactly one JSON object: orders (train, verb run|hold|siding|
route, with at/via when required), say (<= 120 chars, the radio), notes
(<= 240 chars, private). Copy train ids, siding ids, junction ids and
station letters verbatim from the view. An empty orders list means every
train keeps its order — reply with only say/notes when nothing changes.
"""

proc spriteChatBlob(text: string): string =
  ## Sprite v1 chat frame: type byte 0x81, u16 little-endian length,
  ## then the ASCII payload (bitworld spriteprotocol framing).
  result = newString(3 + text.len)
  result[0] = char(0x81)
  result[1] = char(text.len and 0xff)
  result[2] = char((text.len shr 8) and 0xff)
  for i, ch in text:
    result[3 + i] = ch

proc readyBlob(): string =
  ## The Sprite v1 player-ready packet (0x85). This seat sends no orders
  ## itself (the game compiles them), so acknowledging each frame is safe
  ## and lets the fastMode tick loop advance.
  result = newString(1)
  result[0] = char(0x85)

proc registrationBlob(prompt, scripted: string): string =
  ## The one registration message. The server only applies a blob whose
  ## `type` is "register" (src/flatland/server.nim readRegistrations);
  ## `isLlm` is prompt.len > 0, so a named baseline must send an empty
  ## prompt. `scripted` is JSON null for an LLM seat so the server can
  ## tell "no baseline named" from "yielder named". Registering twice is
  ## harmless; the server holds an unappliable registration.
  var frame = %*{
    "type": "register",
    "policy": "Konyok-Gorbunok",
    "prompt": prompt
  }
  if scripted.len > 0:
    frame["scripted"] = %scripted
  else:
    frame["scripted"] = newJNull()
  spriteChatBlob($frame)

proc main() =
  let url = getEnv("COWORLD_PLAYER_WS_URL")
  if url == "":
    quit("gorbunok: COWORLD_PLAYER_WS_URL is not set", 1)
  let
    scripted = getEnv("PLAYER_SCRIPTED", "yielder").strip()
    ## Server: isLlm = prompt.len > 0, even when scripted is named. Empty
    ## the prompt whenever a baseline is set so the seat actually plays it.
    prompt =
      if scripted.len > 0: ""
      else: getEnv("PLAYER_PROMPT", defaultPrompt)
  echo "gorbunok: kind=", (if scripted.len > 0: "scripted" else: "llm"),
    " baseline=", (if scripted.len > 0: scripted else: "none")

  proc dial(attempts: int): WebSocket =
    ## Bounded dialling: the game opens its listener after loading the
    ## rail network, so the first dial can land on a closed port.
    for attempt in 0 ..< attempts:
      try:
        return newWebSocket(url)
      except CatchableError:
        if attempt == 0:
          echo "gorbunok: game not listening yet, retrying"
        sleep(connectRetryMs)
    nil

  var socket = dial(connectAttempts)
  if socket == nil:
    quit("gorbunok: game never accepted a connection", 1)
  echo "gorbunok: connected"

  # The socket can die on the game's own quit(0) racing its last flush
  # (whisky raises on a close frame, mummy's send only queues), so
  # exiting 0 on a dead socket after a played session is correct.
  var reconnects = 0
  while true:
    var sessionFrames = 0
    try:
      socket.send(registrationBlob(prompt, scripted), BinaryMessage)
      var resends = 0
      while true:
        let received = socket.receiveMessage()
        if received.isNone:
          continue                  ## a read timeout, not a closed socket
        inc sessionFrames
        if resends < registrationResends and
            sessionFrames mod resendEveryFrames == 1:
          inc resends
          socket.send(registrationBlob(prompt, scripted), BinaryMessage)
        socket.send(readyBlob(), BinaryMessage)
    except CatchableError:
      echo "gorbunok: socket closed (", getCurrentExceptionMsg(), ")"
    if sessionFrames == 0 or reconnects >= reconnectAttempts:
      break
    inc reconnects
    echo "gorbunok: re-dialling the seat (attempt ", reconnects, ")"
    socket = dial(reconnectAttempts)
    if socket == nil:
      echo "gorbunok: game is no longer listening, exiting cleanly"
      break
    echo "gorbunok: reconnected, re-registering"
  quit(0)

main()
