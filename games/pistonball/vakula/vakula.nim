## Vakula — Pistonball policy for Andre von Auto.
## The pistonball seat is a Sprite v1 client and deliberately thin: it
## dials COWORLD_PLAYER_WS_URL, sends ONE Sprite v1 chat frame (0x81)
## carrying its registration {"type":"register","prompt","scripted",
## "policy"}, re-sends it over the first ~10 s of frames (joins are
## slot-sequential and the lobby sends frames before a seat is admitted),
## answers every received frame with the Ready packet (0x85), and sends
## nothing else; the game server makes every model call.
##
## Default is the published `wavebot` baseline, not the LLM prompt: the
## server sets isLlm from prompt.len > 0 (src/pistonball/server.nim), so a
## non-empty prompt would ignore the baseline. Wavebot is the grid-swept
## certification player (lead 6, up 1.45 m, idle 0.25 m; tools/ci/
## baseline_tuning.json) and the per-turn fallback. League leaders
## relh/richard field wavebot.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED play a scripted baseline (wavebot | metronome).
##                   Defaults to wavebot. Empty string forces the prompt.
## Upload note: default is scripted, so no Bedrock flag is required. LLM
## override needs --secret-env USE_BEDROCK=true.

import std/[json, options, os, strutils], whisky

const
  ConnectAttempts = 240      ## 240 x 500 ms = 2 minutes of dialling.
  ConnectRetryMs = 500
  RegistrationResends = 10   ## re-sends after the first, ~1 s apart.
  ResendEveryFrames = 24     ## ~1 s of frames at 24 Hz.
  ReconnectAttempts = 6

const defaultPrompt = """
You are Vakula the smith, one piston of twenty rolling the ball LEFT.
Choose your program by where you are and what you last saw. goal
direction is left; your_distance_to_goal_m small means you are near the
left wall.
1. Default program: mode wave, trigger_m 1.0, lead_ticks 8, up_m 1.45,
   down_m 0.05, idle_m 0.15, speed 1.0, blind idle.
2. Tune lead_ticks to the last seen ball speed: |vx| above 2 m/s use 11;
   below 1 m/s use 5; else 8.
3. If the ball is in your window now, keep mode wave with those values -
   it lifts behind the ball and clears in front of it. Set trigger_m 1.0
   and speed 1.0 always.
4. THE BALL HAS PASSED YOU (your sightings show it left of you moving
   left, dx negative and vx negative, or it exited your window leftward):
   become the high floor behind it - mode hold, idle_m 1.45. Never chase.
5. THE BALL HAS NOT REACHED YOU YET (all sightings to your right, or you
   have never seen it and your_distance_to_goal_m is small, i.e. you are
   in the LEFT half): stay out of its way - keep idle_m 0.05 and
   blind idle. A raised piston ahead of the ball is a wall the whole
   bank must fight.
6. If a sighting shows the ball rolling the WRONG way (vx above +0.2)
   and it is at or left of you: mode catch, trigger_m 1.0, up_m 1.5,
   down_m 0.05, idle_m 0.10 - be the wall it runs into, then next turn
   go back to wave.
7. Never mode ripple; never blind hold when you are left of the ball.
8. note: one short clause on what you saw and chose.
"""

proc registrationBlob(prompt, scripted, policy: string): string =
  ## One Sprite v1 chat frame: 0x81, u16 little-endian length, ASCII
  ## payload (the chat parser drops bytes outside 32..126, so the JSON
  ## and the prompt stay pure ASCII).
  var node = %*{"type": "register", "prompt": prompt, "policy": policy}
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

proc readyBlob(): string =
  ## The Sprite v1 player-ready packet (0x85). Legitimate for this seat:
  ## it sends no inputs at all, so a fastMode server may advance as soon
  ## as every seat has acknowledged the frame.
  result = newString(1)
  result[0] = char(0x85)

when isMainModule:
  let url = getEnv("COWORLD_PLAYER_WS_URL")
  if url.len == 0:
    quit("vakula: COWORLD_PLAYER_WS_URL is not set", 1)
  let
    scripted = getEnv("PLAYER_SCRIPTED", "wavebot").strip()
    ## Server: isLlm = prompt.len > 0, even when scripted is named. Empty
    ## the prompt whenever a baseline is set so the seat actually plays it.
    prompt =
      if scripted.len > 0: ""
      else: getEnv("PLAYER_PROMPT", defaultPrompt)
    label = "Vakula"
  echo "vakula: kind=", (if scripted.len > 0: "scripted" else: "llm"),
    " baseline=", (if scripted.len > 0: scripted else: "none")

  proc dial(attempts: int): WebSocket =
    ## Bounded dialling: the first dial routinely lands on a closed port.
    for attempt in 0 ..< attempts:
      try:
        return newWebSocket(url)
      except CatchableError as error:
        if attempt == 0:
          echo "vakula: game not listening yet (", error.msg, "); retrying"
        sleep(ConnectRetryMs)
    nil

  var socket = dial(ConnectAttempts)
  if socket == nil:
    quit("vakula: game never accepted a connection", 1)
  echo "vakula: connected"

  # whisky's receiveMessage raises on a close frame, and the game's own
  # quit(0) can outrun its last flushed frame - a dead socket after frames
  # were seen is a normal episode end, so exit 0 there.
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
        socket.send(readyBlob(), BinaryMessage)
    except CatchableError as error:
      echo "vakula: socket closed (", error.msg, ")"
    # A seat that drops mid-episode revives on reconnect; a session that
    # never received a frame means the game is winding down.
    if sessionFrames == 0 or reconnects >= ReconnectAttempts:
      break
    inc reconnects
    echo "vakula: re-dialling the seat (attempt ", reconnects, ")"
    socket = dial(ReconnectAttempts)
    if socket == nil:
      echo "vakula: game is no longer listening, exiting cleanly"
      break
    echo "vakula: reconnected, re-registering"
  quit(0)
