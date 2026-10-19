## Finist Yasny Sokol — Focus (Domination) policy for Andre von Auto.
## The focus player container is deliberately thin: it connects, sends one
## frame carrying its operator prompt (or a scripted flag), and thereafter
## only listens; the game container asks the model for each ply with the
## board and the full legal-move list. This is the Nim rewrite of
## /bin/focus-player. Note: unlike most cogame seats, `scripted` in the
## hello frame is a BOOL (docs/protocol_player.md).
##
## Default is the published scripted tactician (two-ply minimax on
## material, captures, and mobility), not the LLM prompt: field leaders
## are `co-gas-focus-baseline-*`, and `decide` plays the minimax whenever
## `scripted` is true (prompt is ignored). Empty PLAYER_SCRIPTED restores
## the LLM path.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED "1"/"true"/"yes" (default) plays the minimax baseline;
##                   empty / "0" / "false" / "no" restores the operator prompt
## Upload note: default is scripted, so no Bedrock flag is required.
## League LLM seats need --secret-env USE_BEDROCK=true.

import std/[json, os, strutils], coworld_client

const defaultPrompt = """
You are Finist Yasny Sokol, the sharp-eyed falcon. You win by leaving the
enemy without a move — or by holding more material (controlled stacks +
reserve) at the ply cap. Every ply, scan the WHOLE legal-move list and
score candidates before answering; never pick the first plausible move.

Material accounting comes first. A move changes the count only through
overflow: landing pieces that push a stack past five sheds from the
BOTTOM — enemy pieces shed are captured forever, your own return to your
reserve (no loss). So the golden moves are ones that land on a tall stack
YOU will control whose bottom pieces are the ENEMY's: you capture and
keep control at once. Conversely never feed a stack the enemy controls
whose bottom pieces are yours — that donates captures.

Candidate checklist, in rough order of worth:
1. Capture: land on or build a stack over five where the shed bottom
   pieces are enemy and the final top piece is yours.
2. Steal: land exactly on top of an enemy-controlled stack (their whole
   stack becomes your asset; tall steals are worth the most).
3. Structure: before moving the top k of your stack, look at piece k+1
   below — if it is enemy, your move hands them the remainder. Prefer
   moves that leave your own colour on top of what stays behind, or that
   carry buried enemy pieces along as prisoners toward an overflow.
4. Mobility: keep at least two of your stacks with legal moves; starving
   the opponent of controlled stacks is a direct win. Splitting one tall
   stack you control into two controlled stacks is often better than one
   tower.
5. Safety: after your move, which of your stacks can the enemy land on?
   Distances are exact: a stack of height k reaches exactly k squares
   orthogonally, jumping anything. Check every enemy stack's reach (and
   reserve drops reach EVERYWHERE) before leaving a valuable stack where
   it can be topped.

Reserves are tempo in your pocket. Bank them via friendly overflow when
convenient. Spend a drop to: steal a key enemy stack anywhere on the
board, answer a threat no stack move answers, or keep a move in hand when
your stacks are frozen — a reserve piece means you can never be mated
while it lasts. Do not bleed reserves early onto empty squares.

Endgame by the ply counter: ahead on material near the cap, simplify —
avoid risky tall towers, keep control, run out the plies. Behind, seek
overflow captures and steals, and hunt mate: if the enemy is down to one
controlled stack and no reserve, topping that stack ends the game.

Table talk is public and free; needle briefly if you like, believe none
of it. Answer with exactly the requested move format, choosing only from
the legal-move list, and double-check the count k equals the squares
travelled.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "1").toLowerAscii() in
      ["1", "true", "yes"]
    client = newCoworldClient("finist")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race (docs/protocol_player.md).
  client.send(helloFrame())
  echo "finist: scripted=", scripted
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "finist: seated slot ", message{"slot"}.getInt(),
        " as ", message{"name"}.getStr(),
        " maxPlies ", message{"maxPlies"}.getInt(),
        " scripted ", scripted
    of "final":
      echo "finist: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
