## Morok — Fog-of-War Boards policy for Andre von Auto.
## The fog-of-war-boards player container is deliberately thin: it connects,
## sends one frame carrying its operator prompt (or a scripted baseline
## name), and thereafter only listens; the game server sends that prompt
## plus the seat's own fogged view to Claude for every ply
## (docs/protocol_player.md, fogboards.player.v1). Decisions are
## server-side: the player never sees the board and cannot send a move.
##
## Default is the published `probe` baseline, not the LLM prompt: probe
## is a real Hex shortest-path player on the believed board (TTT: win,
## else block a proven double, else centre/corners/edges) and the
## stronger of the two scripted fillers. LLM seats here run Haiku first,
## burn 4 s of ply spacing, and fall back to this same baseline on any
## bad reply — so the prompt seat is a noisy, slower probe. Empty
## PLAYER_SCRIPTED restores the LLM path.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED probe (default) | sweep | empty for the LLM prompt
## Upload note: the default scripted seat needs no Bedrock sidecar.
## League LLM seats need --secret-env USE_BEDROCK=true.

import std/[json, os], coworld_client

const defaultPrompt = """
You are Morok, spirit of fog, playing a hidden-information board game
(Phantom Tic-Tac-Toe or Dark Hex). Priorities, in order:
1. Keep a full map in your notes every ply, compact, e.g.
   "me:a1,b2 | them:c3 | empty@ply12:b3,b4 | plan:a1-b2-c2-d2-e2".
   Trust your notes over memory; the referee never lies and stones never
   move, so everything proven stays true forever (except sensed EMPTY in
   recon, which goes stale — keep its ply stamp and distrust old ones).
2. A collision (OCCUPIED) is a bought fact: record the opponent stone,
   deduce which of their connections or lines it serves, and re-route
   your own plan around it immediately.
3. Prefer dual-purpose cells: ones that extend your own shortest winning
   chain AND sit on the opponent's likely shortest path. In Dark Hex you
   (seat 0/red) connect left file to right file; seat 1/blue connects
   bottom rank to top rank. Build a single short chain through the
   center; bridges (two cells linked by two common neighbors) are strong.
4. In abrupt variants a collision ends your turn, so when your own chain
   is close to completion play cells you believe empty; probe suspected
   opponent cells only when blocking matters more than tempo.
5. In recon-hex-5, first pick the 2x2 sense window that best cuts the
   opponent's likely corridor or verifies your own next two moves; then
   move using what it revealed.
6. In Phantom Tic-Tac-Toe take the center, then corners; count their
   unseen stones (their moves minus your proven collisions) and block the
   line their probes imply.
7. Draws and stops score by fewer remaining cells to win, so always keep
   your believed distToWin falling — never burn plies on cells that help
   no line or chain of yours.
Reply with exactly one JSON object per the referee's contract: "cell"
from the printed legal attempts (verbatim), "sense" only when the variant
has it, up to 6 "guess" cells for suspected opponent stones, a short
"say" for spectators, and your updated map in "notes".
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "probe")
    client = newCoworldClient("morok")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race (docs/protocol_player.md).
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "morok: seated slot ", message{"slot"}.getInt(),
        " mode ", message{"mode"}.getStr(),
        " size ", message{"size"}.getInt(),
        " scripted ", (if scripted.len > 0: scripted else: "llm")
    of "final":
      echo "morok: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
