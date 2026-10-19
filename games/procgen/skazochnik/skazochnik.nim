## Skazochnik — Procgen policy for Andre von Auto.
## The procgen player container is deliberately thin: it dials its seat,
## sends one registration message — RAW JSON on a binary websocket frame,
## no Sprite framing and no Ready byte, unlike the other cogame seats —
## then only receives, exiting when a frame carries "final". The game
## server runs every decision (docs/protocol.md, docs/rules.md).
##
## Default is the published `pathfinder` baseline, not the LLM prompt:
## the server sets isLlm from prompt.len > 0 (src/procgen/server.nim), so a
## non-empty prompt would ignore the baseline. League leader is
## procgen-example (Andrew Brower, mean 0.69 vs our prompt's 0.33); it is
## this same image with PLAYER_SCRIPTED=pathfinder. Pathfinder is the
## sweep-tuned careful router (lookahead 6, digCost 1, +0.038 vs scavenger
## on the recorded ladder, 16/16 unseen clears).
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED play a scripted baseline (pathfinder | scavenger).
##                   Defaults to pathfinder. Empty string forces the prompt.
## Upload note: default is scripted, so no Bedrock flag is required. LLM
## override still needs the game-pod anthropic_api_key (already injected).

import std/[json, options, os, strutils], whisky

const
  connectAttempts = 240      ## 240 x 500 ms = 2 minutes of dialling.
  connectRetryMs = 500
  registrationResends = 10   ## re-sends after the first, ~1 s apart.
  resendEveryFrames = 24
  reconnectAttempts = 6

const defaultPrompt = """
You are Skazochnik, the storyteller, playing an eight-level procgen
gauntlet. Per level: 700 for collectibles, 200 for closing distance to the
exit, 100 for finishing; the exit opens only when every gem or pellet is
taken. Ten turns of up to six moves (L R U D X .) per level, executed one
per frame. Rules of the road:
1. actions[] is the resolver's own truth for your NEXT step: never begin a
   plan with an illegal move, never any move with kills true. Walk your
   whole plan mentally tile by tile on the map before you commit it.
2. MAZE: no hazards, plans always run all six moves. Head for nearest_gem;
   record junction choices in notes so you never re-walk a dead end. Gems
   sit on the lattice cells farthest from the start - expect long routes.
3. CHASER: you take 3 steps for the hunters' 2, so you outrun them in a
   straight line - always. Keep 2+ tiles from every hunter, plan only 2-3
   moves when any hunter is within 4 tiles, and collect pellets along the
   edges pulling hunters into pillar loops. X dashes 2 tiles in last_dir
   then cools 4 frames - use it to break a closing pincer, never at a wall.
4. CLIMBER: U and D work only on ladders; gravity is real. To cross a gap:
   step to face the direction, X to jump, then the horizontals - jump_fuel
   2 carries you across. Never step off an edge with more than 4 tiles of
   fall below, and never plan past a spike tile.
5. MINER: anything with empty below it falls - never dig the tile under a
   boulder, and check falling[] every turn; a falling boulder within 3
   tiles of your column interrupts the plan and can crush you. Approach
   gems from the side, push boulders horizontally into dead space early.
6. Take every collectible before walking to the exit, but track
   exit_distance: with 3 turns left on the level and the exit still
   locked, grab only gems on the way and spend the last turns closing
   distance - approach pays 200 even when you cannot finish.
7. Death forfeits the level's remaining turns: between a fast route and a
   safe route, take the safe one. A cleared level is 1000; a dead cog
   keeps only what it banked.
Use notes (160 runes) as your memory: the route, the next gem, the tile
that nearly killed you. Reply with exactly one JSON object:
{"moves":"<up to 6 of L R U D X .>","say":"<short>","notes":"<plan>"}.
"""

proc registrationBlob(prompt, scripted: string): string =
  ## The one registration message: raw JSON, no Sprite framing — this
  ## game's registrar sends the object bytes directly (src/procgen_player).
  ## scripted is JSON null for an LLM seat so the server can tell "no
  ## baseline named" from "pathfinder named".
  var frame = %*{"type": "register", "prompt": prompt,
                 "policy": "Skazochnik"}
  if scripted.len > 0:
    frame["scripted"] = %scripted
  else:
    frame["scripted"] = newJNull()
  $frame

proc main() =
  let url = getEnv("COWORLD_PLAYER_WS_URL")
  if url == "":
    quit("skazochnik: COWORLD_PLAYER_WS_URL is not set", 1)
  let
    scripted = getEnv("PLAYER_SCRIPTED", "pathfinder").strip()
    ## Server: isLlm = prompt.len > 0, even when scripted is named. Empty
    ## the prompt whenever a baseline is set so the seat actually plays it.
    prompt =
      if scripted.len > 0: ""
      else: getEnv("PLAYER_PROMPT", defaultPrompt)
  echo "skazochnik: kind=", (if scripted.len > 0: "scripted" else: "llm"),
    " baseline=", (if scripted.len > 0: scripted else: "none")

  proc dial(attempts: int): WebSocket =
    ## Bounded dialling: the episode runner starts the players at the same
    ## instant as the game, so the first dial usually lands closed.
    for attempt in 0 ..< attempts:
      try:
        return newWebSocket(url)
      except CatchableError:
        if attempt == 0:
          echo "skazochnik: game not listening yet, retrying"
        sleep(connectRetryMs)
    nil

  var socket = dial(connectAttempts)
  if socket == nil:
    quit("skazochnik: game never accepted a connection", 1)
  echo "skazochnik: connected"

  # Registration is re-sent for the first ~10 s of frames because a seat's
  # slot may not be admissible yet; the socket can also die on the game's
  # own quit(0) racing its last flush, so a dead socket after a played
  # session exits 0.
  var reconnects = 0
  var done = false
  while not done:
    var sessionFrames = 0
    try:
      socket.send(registrationBlob(prompt, scripted), BinaryMessage)
      var resends = 0
      while true:
        let received = socket.receiveMessage()
        if received.isNone:
          continue                  ## a read timeout, not a closed socket
        inc sessionFrames
        if "\"final\"" in received.get.data:
          done = true
          break
        if resends < registrationResends and
            sessionFrames mod resendEveryFrames == 1:
          inc resends
          socket.send(registrationBlob(prompt, scripted), BinaryMessage)
    except CatchableError:
      echo "skazochnik: socket closed (", getCurrentExceptionMsg(), ")"
    if done:
      break
    if sessionFrames == 0 or reconnects >= reconnectAttempts:
      break
    inc reconnects
    echo "skazochnik: re-dialling the seat (attempt ", reconnects, ")"
    socket = dial(reconnectAttempts)
    if socket == nil:
      echo "skazochnik: game is no longer listening, exiting cleanly"
      break
    echo "skazochnik: reconnected, re-registering"
  quit(0)

main()
