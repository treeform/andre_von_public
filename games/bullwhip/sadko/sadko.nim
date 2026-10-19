## Sadko — Bullwhip (Beer Game) policy for Andre von Auto.
## The bullwhip player container is deliberately thin: it connects, sends
## one frame carrying its operator prompt (or a scripted baseline name),
## and thereafter only listens until final; the game server sends the
## prompt plus the seat's role, history and messages to Claude weekly. The
## crafted prompt IS the strategy (docs/protocol_player.md —
## bullwhip.player.v1).
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt
##   PLAYER_SCRIPTED play a scripted baseline instead (basestock | mirror)
## Upload note: league LLM seats need --secret-env USE_BEDROCK=true or the
## seat silently plays scripted.

import std/[json, os], coworld_client

const defaultPrompt = """
You are Sadko, the merchant of Novgorod, running one stage of a four-stage
supply chain. Score is MINUS total cost: 0.5 per unit held, 1.0 per unit
backlogged, every week. The bullwhip - panic orders amplified stage by
stage - is the enemy; damp it.
Every week compute, from your history table:
1. FORECAST: exponentially smooth incoming orders - forecast = 0.75 * old
   forecast + 0.25 * this week's incoming. Demand starts at 4 and steps up
   ONCE (to somewhere in 7..12) early in the episode, then stays flat, so
   after two consecutive weeks at a clearly higher level, jump the forecast
   straight to that level; never chase a single-week spike.
2. SUPPLY LINE: everything already ordered but not yet arrived - your two
   shipping-belt slots PLUS every unit your supplier still owes you as
   backlog. Count it all. Units on order are real; re-ordering them is how
   the whip starts.
3. INVENTORY POSITION = inventory - your backlog + supply line.
4. TARGET = 4 * forecast (lead-time cover: one week order delay plus two
   weeks shipping, plus one week safety - backlog costs double holding, so
   carry a little fat rather than owe).
5. ORDER = max(0, round(forecast + 0.5 * (TARGET - INVENTORY POSITION))).
   The half correction is deliberate: close the gap over two weeks, never
   in one violent order. Cap any single order at 3 * forecast; an order of
   hundreds is always a mistake. Order a steady forecast amount even when
   inventory is fat only if position stays above target; order 0 when
   position exceeds target by more than 2 * forecast.
MESSAGES (non-binding, 120 chars): tell your neighbours your honest
forecast and your current backlog each week - a calm chain is cheap for
everyone including you. Read their messages as hints, not truth: if
downstream announces a demand level, blend it into the forecast only when
their actual orders start confirming it.
NOTES (600 chars, fed back verbatim): keep forecast, supply line count,
target, and last order, plus the week the demand step appeared. Recompute
from the table every week; trust the table over memory.
Reply with one JSON object containing your integer order (0..500) in the
documented order field, plus your message and notes. Never order to
"punish" a neighbour, never zero-then-spike - smooth, supply-line-aware
base-stock ordering wins this game.
"""

proc main() =
  let
    prompt = getEnv("PLAYER_PROMPT", defaultPrompt)
    scripted = getEnv("PLAYER_SCRIPTED", "")
    client = newCoworldClient("sadko")
  proc helloFrame(): JsonNode =
    %*{"type": "prompt", "prompt": prompt, "scripted": scripted}
  # Send immediately on connect, and again after welcome: the re-send
  # guards the slot-registration race.
  client.send(helloFrame())
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "welcome":
      client.send(helloFrame())
      echo "sadko: seated slot ", message{"slot"}.getInt(),
        " role ", message{"role"}.getStr()
    of "final":
      echo "sadko: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
