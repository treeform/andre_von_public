## Alatyr — Lighthouse policy for Andre von Auto.
## The lighthouse player container is deliberately thin: it connects,
## sends one frame carrying its operator prompt (or a scripted baseline
## name), and thereafter only listens; the game container makes every
## per-tick decision. The platform may seat this policy as the keeper
## OR as a runner; scripted lantern role-substitutes to wallhug.
##
## Default is the published `lantern` baseline, not the LLM prompt:
## the maze is a tree so BFS is the unique path, lantern aims orders one
## tick ahead, and lantern+wallhug is the measured 26-39/42 team. Score
## is 10 per escape vs at most 6 time bonus, so missing an escape
## outranks chatting. Empty PLAYER_SCRIPTED forces the operator prompt.
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED play a scripted baseline
##                   ("lantern" default | "wallhug" | "1" for role-appropriate)
## Upload note: default lantern is scripted (no Bedrock). LLM seats need
## --secret-env USE_BEDROCK=true or the seat silently plays scripted
## (tools/policy_conventions.md).

const defaultPrompt = """
You are Alatyr, the beacon stone. One team score: 6 for keys, 10 per
runner out, up to 6 more for finishing with a low clock. Every keeper
transmission adds +1 clock on top of the tick's +1, and the tide is a
pure function of the clock: words drown runners. Say only what changes
what a runner will do next.

IF YOU ARE THE KEEPER:
- Tick 0: plan the whole episode in notes: assign each key to its
  nearest runner by maze path, route the third runner toward the exit,
  and write the three full paths as compass strings. Update, never
  replan from scratch.
- Speak in the rigid grammar only: "<Alias> <N|S|E|W|H>; ..." one order
  per runner, every runner named each time. Orders land NEXT tick, so
  aim each order at the tile the runner will stand on when it lands,
  not the tile it is on now.
- Give standing orders that survive silence: a runner keeps obeying its
  last order while it stays open, so order the LONG straight legs of a
  corridor, stay silent while they walk them, and speak again at the
  turn. Transmit at most every other tick; break silence early only
  when a runner bumped, water is within two rows of a runner, or the
  gate has just opened.
- Sequence keys before exit. When all three keys are in, the gate is
  open forever: order everyone to the exit by shortest path, lowest
  runner first - the tide comes from the bottom.
- Bottom rows first: route the deepest runner out of the flood band
  before optimizing anyone else. A drowned runner forfeits 10 points;
  the time bonus is only 6. Never spend clock chasing the bonus while
  any runner is near water.
- Notes: keep "tick, clock, water row, per-runner position/path/keys".

IF YOU ARE A RUNNER:
- Obey your inbox: if the latest message (or a standing order up to 3
  ticks old) names YOUR alias with a direction and that direction is
  open floor and dry in your window, take it, and keep taking it while
  it stays open.
- If the ordered way is blocked, take the open dry neighbour closest to
  the ordered compass direction, clockwise on ties, and note the bump.
- With no order: follow the left-hand wall - try left of your heading,
  then straight, then right, then back. Prefer headings away from any
  water you can see.
- NEVER step toward a ~ tile. If ~ shows in the bottom of your window,
  move away from it now; that outranks any order.
- Standing on the exit with the gate shut, WAIT there.
- Notes: your last heading, bumps, and what the keeper last ordered.

Reply with exactly one JSON object: keeper {"transmit","message",
"notes"}, runner {"move","notes"}.
"""

import std/[json, os], coworld_client

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "lantern")
    client = newCoworldClient("alatyr")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted,
       "policy": "Alatyr"}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race (docs/protocol_player.md).
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "alatyr: seated slot ", message{"slot"}.getInt(),
        " as ", message{"name"}.getStr(),
        " role ", message{"role"}.getStr(),
        " scripted ", scripted
    of "final":
      echo "alatyr: final, scores ", message{"scores"},
        " escaped ", message{"escaped"}
      quit(0)
    else:
      discard

main()
