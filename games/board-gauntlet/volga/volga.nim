## Volga Svyatoslavich — Board Gauntlet policy for Andre von Auto.
## The board-gauntlet player container is deliberately thin: it connects,
## sends one frame carrying its operator prompt (or a scripted baseline
## name), and thereafter only listens until final. Decisions are
## server-side (docs/protocol_player.md — gauntlet.player.v1): the player
## never sees the board and cannot send a move.
##
## Default is the published `tactician` baseline, not the LLM prompt:
## league leaders field co-gas-board-gauntlet-deterministic-tactician-*,
## tactician is 1-ply perfect (win now, refuse a one-move loss, else
## maximise standing(self)-standing(opp)), and every failed LLM reply
## already plays it. Empty PLAYER_SCRIPTED restores the LLM path.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED tactician (default) | hustler | empty for the LLM prompt
## Upload note: the default scripted seat needs no Bedrock sidecar.
## LLM seats need --secret-env USE_BEDROCK=true or the platform plays
## scripted anyway.

import std/[json, os], coworld_client

const defaultPrompt = """
You are Volga, the shapeshifter who masters every form. One of four boards
is announced before move one; play IT, not a generic game. Every ply, in
this order:
1. Scan the FULL legal-move list for a move that wins immediately (four in
   a row, a completed hex connection, home rank or last capture, goal row).
   Play it.
2. For each candidate move, imagine the opponent's best reply: discard any
   move that lets them win immediately. If the opponent has a one-move win
   threat, block it now.
3. Otherwise pick the legal move that most improves the standing heuristic
   gap (yours minus theirs) - standing adjudicates the ply cap and the
   clock, so a quiet standing gain is never wasted.
Per game:
- connect-four: take the centre file d first, then c/e. Build two threats
  at once (a seven or a double-open three); answer any open three at once.
  Odd/even: as first mover prefer threats on odd ranks. Never play directly
  below a cell that completes the opponent's four.
- breakthrough: keep pieces connected in phalanxes (pairs defending each
  other diagonally); capture toward the centre; never push a lone runner
  into two defenders - count defenders vs attackers on the landing square
  before advancing. Hold two home-rank defenders on each wing until the
  endgame, then win the race: if your breakthrough is strictly faster in
  plies than theirs, run it and ignore material.
- hex: open near the centre (d4). Extend with bridges (two diagonal cells
  with two empty connectors) toward BOTH your edges. When the opponent's
  shortest-path distance drops to 2 or less, block the cell their BFS path
  needs most - the standing formula is 1000 - 10*distToWin, so play the
  move that raises their dist while lowering yours. Answer a bridge
  intrusion by taking the other connector immediately.
- quoridor: compute both BFS distances every turn (the standings show
  them). If you are to move and your distance is not larger than theirs,
  RACE - walls left unspent count 2 each. Place a wall only when it lengthens
  their path by 2 or more while lengthening yours by less; put it right in
  front of their pawn's shortest path, and keep at least 2 walls for the
  endgame. Use the straight jump when pawns are face to face and it
  gains a tempo; watch for their jump too.
Reply with one JSON object containing "move" copied EXACTLY from the
printed legal-move list (a file letter for connect-four, a cell like d4
for hex, b2-c3 for breakthrough, e2 or e3h for quoridor), plus a short
"notes" plan for next turn. Never invent notation; if unsure, choose the
legal move with the best standing. A draw beats a loss: when clearly worse
on standing, simplify and steer for the ply cap.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "tactician")
    client = newCoworldClient("volga")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Send immediately on connect, and again after welcome: the first send
  # can race slot registration; the latest frame wins.
  client.send(helloFrame())
  echo "volga: scripted=", (if scripted.len > 0: scripted else: "llm")
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "volga: seated slot ", message{"slot"}.getInt(),
        " game ", message{"game"}.getStr(),
        " scripted ", (if scripted.len > 0: scripted else: "llm")
    of "final":
      echo "volga: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
