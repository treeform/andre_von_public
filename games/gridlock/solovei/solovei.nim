## Solovei Razboinik — Gridlock policy for Andre von Auto.
## The gridlock player container is deliberately thin: it registers once on
## connect with an operator prompt (or a scripted baseline name), then only
## listens; the game server makes every per-turn routing decision
## (docs/protocol_player.md).
##
## Default is the published `dispatcher` baseline, not the LLM prompt:
## roster.effectiveScript honours a named scripted kind even with a prompt,
## and an empty prompt also plays dispatcher. Relh/richard field
## `co-gas-gridlock-baseline-*` (dispatcher) at ~971-994 vs our LLM seat at
## 815.5. Dispatcher is sweep-tuned (src/gridlock/baselines.nim) and the
## per-turn fallback; LLM seats also pay minTurnSpacingSeconds and can
## deadline-cut the episode (score is raw deliveries).
##
## Env:
##   PLAYER_PROMPT   override the built-in operator prompt (LLM seats)
##   PLAYER_SCRIPTED play a scripted baseline (dispatcher | beeline);
##                   default dispatcher. Empty string forces the prompt.
## Upload note: default is scripted, so no Bedrock flag is required.
## League LLM seats need --secret-env USE_BEDROCK=true.

import std/[json, os, strutils], coworld_client

const defaultPrompt = """
You are Solovei Razboinik routing fifty parcel vans in a shared city. Your
score is YOUR deliveries only. The city is a commons: the greedy plan builds
the jam it then sits in. Steady metering beats greed.
Each turn set the plan from the view, in this order:
1. Throughput basics: priority "near" always (short trips = fast van
   turnaround = more deliveries). corridor = your own depot district; never
   avoid your own depot district.
2. Meter the fleet - the only self-restraint that exists. Baseline
   dispatch 70, spread 40. If your stalled_pct is over 15 or jam_index is
   climbing two turns running, cut dispatch to 55 and raise spread to 60
   (release slower). When roads clear (stalled_pct under 5, jam_index low),
   push dispatch back to 80, spread 30.
3. Routing around queues: congestion_weight 70 baseline. Raise to 90-100
   when hot_lanes or districts_heat show 7+ anywhere on your side of the
   map; drop to 40 only when the whole city is quiet. Never 0: pure greedy
   shortest path is how fleets strangle themselves.
4. avoid: the single hottest district (heat 8-9), usually CENTRE at
   mid-game - but only if it is not your depot district and your next
   orders do not all sit inside it.
5. patience 50 baseline. In a jam turn drop it to 30 so stuck vans replan
   eagerly; when your mean_trip_seconds is good, raise to 60 and stop
   churning routes.
6. Do not copy the leader. Watch fleets[]: rivals that surge early usually
   gridlock the arterials by turn 8-12; hold your metering discipline and
   collect during their collapse.
7. note: keep a running memo - what you changed, jam_index trend, which
   district you are avoiding, own stalled_pct last turn. Trust the memo
   over memory. say: one short word of intent.
Reply with exactly one JSON plan object each turn; copy district and block
names verbatim from the view.
"""

proc main() =
  let
    scripted = getEnv("PLAYER_SCRIPTED", "dispatcher").strip()
    ## Server: effectiveScript uses scripted if named, else empty prompt
    ## => dispatcher, else LLM. Empty the prompt whenever a baseline is
    ## set so the seat actually plays it.
    prompt =
      if scripted.len > 0: ""
      else: getEnv("PLAYER_PROMPT", defaultPrompt)
    client = newCoworldClient("solovei")
  var register = %*{"type": "register", "prompt": prompt,
    "policy": "Solovei Razboinik"}
  register["scripted"] = if scripted.len > 0: %scripted else: newJNull()
  # Gridlock registers exactly once on connect (docs/protocol_player.md);
  # there is no re-send-after-welcome dance in this protocol.
  client.send(register)
  echo "solovei: kind=", (if scripted.len > 0: "scripted" else: "llm"),
    " baseline=", (if scripted.len > 0: scripted else: "none")
  client.run proc(message: JsonNode) =
    if message{"done"}.getBool():
      echo "solovei: done, result ", message{"result"}
      quit(0)
    case message{"type"}.getStr()
    of "welcome":
      echo "solovei: seated slot ", message{"slot"}.getInt(),
        " fleet ", message{"fleet"}.getStr()
    else:
      discard

main()
