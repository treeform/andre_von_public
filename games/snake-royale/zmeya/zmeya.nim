## Zmeya — Snake Royale policy for Andre von Auto.
## The snake-royale player container is deliberately thin: it connects,
## sends ONE registration message carrying its operator prompt (or a
## scripted baseline name), and thereafter only listens; the GAME server
## makes every per-turn decision, because it is the only container the
## platform injects the anthropic_api_key secret into (docs/protocol.md,
## upstream src/snake_royale_player.nim). The registration is a raw JSON
## blob sent as a BINARY websocket frame, re-sent for the first ~10 s of
## frames because joins are slot-sequential.
##
## Default is the published `coil` baseline, not the LLM prompt: the
## server sets isLlm from prompt.len > 0 (src/snake/server.nim), so a
## non-empty prompt would ignore the baseline. League leader is
## snake-royale-example (Andrew Brower, mean +0.50, 18-3 vs our prompt
## seat); it is this same image with PLAYER_SCRIPTED=coil. Coil is the
## sweep-tuned survival heuristic (spaceWeight 100, spaceCap 2,
## hungerThreshold 12, +0.1805 vs forager on the mirrored ladder).
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED play a scripted baseline (coil | forager).
##                   Defaults to coil. Empty string forces the prompt.

import std/[json, options, os, strutils, unicode], whisky

const
  ConnectAttempts = 240      ## 240 x 500 ms = 2 minutes of dialling.
  ConnectRetryMs = 500
  RegistrationResends = 10   ## re-sends after the first, ~1 s apart.
  ResendEveryFrames = 24
  ReconnectAttempts = 6
  MaxPromptRunes = 4000

const defaultPrompt = """
You are Zmeya, the cunning serpent, playing four-snake simultaneous royale.
Survival ranks first, then length, then food eaten — the last snake alive
takes the round, so a move that risks death is worth less than any move
that does not. Every turn, in order:
1. Read moves[] — it is the resolver's own truth. Discard illegal moves.
   Discard any legal move with head_risk lose or both_die unless every
   legal move has it. Treat a move whose free_space is under your own
   length as a trap you may never escape; prefer free_space at or above
   your length, and among safe moves take the LARGEST free_space.
2. Eat with judgment, not greed. Take food when it sits on a safe move,
   or when health is under 12 (royale) — starving is a real death. Never
   cross the board for food through a tight corridor; the greedy snakes
   die trapped, and outliving them is the whole game.
3. Head-to-heads: under longer_wins, take a head_risk win when its
   free_space is also safe — a free kill removes a rival. Under both_die
   (geese, tron) treat every contested head cell as lethal.
4. Block, do not chase. When a rival's head is nearer a wall or corner
   than yours, steer along the lane that seals it in while keeping your
   own free_space high; cutting one rival usually gifts the third snake,
   so prefer cuts that keep YOU on the roomy side of the wall you build.
5. Late game (two snakes left): control the larger region. Mirror the
   rival across the open space, shrink its side lane by lane, and only
   enter a head-on you win by length.
6. Module shifts: on the geese torus there are no walls — think in wrap
   distances, eat before each 20-turn shrink so length never hits zero,
   and avoid all head-risk. In tron nothing ever clears — hug your own
   trail tight, spiral outward, and spend every turn stealing area.
7. Set alt every turn to your second-safest direction — it is your typo
   insurance. Use say to claim a lane ("north lane is mine") when the
   claim deters, and bluff only when cornered. Keep notes on each rival:
   length, habits, which one chases food, which one blocks.
Reply with one JSON object: dir, alt, say (24 runes), notes (160 runes).
"""

proc truncateRunes(text: string, limit: int): string =
  if limit <= 0: return ""
  if text.runeLen <= limit: return text
  text.runeSubStr(0, limit)

proc registrationBlob(prompt, scripted, policy: string): string =
  ## The one registration message. `scripted` is JSON null when the seat
  ## is an LLM seat, so the server can tell "no baseline named" from
  ## "coil named explicitly".
  var node = %*{
    "type": "register",
    "prompt": prompt.truncateRunes(MaxPromptRunes),
    "policy": policy
  }
  if scripted.len > 0:
    node["scripted"] = %scripted
  else:
    node["scripted"] = newJNull()
  $node

proc main() =
  let url = getEnv("COWORLD_PLAYER_WS_URL", getEnv("COGAMES_ENGINE_WS_URL"))
  if url.len == 0:
    quit("zmeya: COWORLD_PLAYER_WS_URL is not set", 1)
  let
    scripted = getEnv("PLAYER_SCRIPTED", "coil").strip()
    ## Server: isLlm = prompt.len > 0, even when scripted is named. Empty
    ## the prompt whenever a baseline is set so the seat actually plays it.
    prompt =
      if scripted.len > 0: ""
      else: getEnv("PLAYER_PROMPT", defaultPrompt)
  echo "zmeya: kind=", (if scripted.len > 0: "scripted" else: "llm"),
    " baseline=", (if scripted.len > 0: scripted else: "none")

  proc dial(attempts: int): WebSocket =
    ## Bounded dialling: the players start at the same instant as the
    ## game, so the first dial always lands on a closed port.
    for attempt in 0 ..< attempts:
      try:
        return newWebSocket(url)
      except CatchableError as error:
        if attempt == 0:
          echo "zmeya: game not listening yet (", error.msg, "); retrying"
        sleep(ConnectRetryMs)
    nil

  var socket = dial(ConnectAttempts)
  if socket == nil:
    quit("zmeya: game never accepted a connection", 1)
  echo "zmeya: connected"

  # Registration is RE-SENT, not sent once: a seat whose slot is not the
  # next open one may register before it has an index. The player exits 0
  # on a dead socket — the game's quit can outrun the flushed final frame.
  var reconnects = 0
  var done = false
  while not done:
    var sessionFrames = 0
    try:
      socket.send(registrationBlob(prompt, scripted, "Zmeya"), BinaryMessage)
      var resends = 0
      while true:
        let received = socket.receiveMessage()
        if received.isNone:
          continue                    ## a read timeout, not a closed socket
        if received.get.kind == Ping:
          socket.send(received.get.data, Pong)
          continue
        inc sessionFrames
        if "\"final\"" in received.get.data:
          done = true
          break
        if resends < RegistrationResends and
            sessionFrames mod ResendEveryFrames == 1:
          inc resends
          socket.send(registrationBlob(prompt, scripted, "Zmeya"),
            BinaryMessage)
    except CatchableError as error:
      echo "zmeya: socket closed (", error.msg, ")"
    if done:
      break
    if sessionFrames == 0 or reconnects >= ReconnectAttempts:
      break
    inc reconnects
    echo "zmeya: re-dialling the seat (attempt ", reconnects, ")"
    socket = dial(ReconnectAttempts)
    if socket == nil:
      break
  quit(0)

main()
