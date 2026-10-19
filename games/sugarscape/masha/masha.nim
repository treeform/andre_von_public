## Masha — Sugarscape v3 policy for Andre von Auto.
## Command player, one decision per episode: the game sends a single
## `observation` carrying this seat's target, the policy submits ONE
## declarative SugarLang ruleset, and the simulation runs with no further
## player I/O (docs/protocol_player.md, protocol "sugarscape-v3/1").
## This is a Nim rewrite of the bundled default (and only) example,
## `players/baseline/player.py` — the target-aware canned-ruleset picker.
## Stay connected through `result` (platform player contract: exit when
## the episode ends). On an invalid ack, retry once with the minimal
## welfare-chaser before giving up.

import std/os, coworld_client

const
  Protocol = "sugarscape-v3/1"
  WelfareGet = ["get", "cell.welfare"]
  OccupiedGet = ["get", "cell.occupied"]

proc welfareChaser*(): JsonNode =
  ## Minimal legal movement list: rank candidates by stock DTL welfare.
  %*{"version": 1, "movement": [{"score": WelfareGet}]}

proc targetFromObservation*(message: JsonNode): JsonNode =
  ## Pull this seat's target out of a sugarscape-v3 observation.
  ## The wire puts `target` on the observation object itself (PROTOCOL.md).
  ## A nested `observation` wrapper (other coworlds) is accepted too, as is
  ## a bare target-id string.
  var target = message{"target"}
  if target.isNil or target.kind notin {JObject, JString}:
    let nested = message{"observation"}
    if nested != nil and nested.kind == JObject:
      target = nested{"target"}
  if target.isNil:
    return newJObject()
  if target.kind == JString:
    return %*{"id": target.getStr()}
  if target.kind == JObject:
    return target
  newJObject()

proc chooseRuleset*(target: JsonNode): JsonNode =
  ## Select a readable canned ruleset from the assigned target.
  ## Commonwealth (`kind == "maximize"` / `wellness.max`) returns a fixed
  ## constitution so multi-seat qualifier rounds hash identical
  ## (`result.rulesets_identical`). Distribution targets (Solo / Duos)
  ## generate per `id` / `variable`. Duos seats share a world but keep
  ## independent scores, so they must NOT force identical rulesets.
  let
    targetId = target{"id"}.getStr()
    kind = target{"kind"}.getStr()
    variable = target{"variable"}.getStr()
    welfare = %*WelfareGet
    occupied = %*OccupiedGet
  if kind == "maximize" or targetId == "wellness.max":
    ## Commonwealth: peaceful, trading, lending, reproducing settlers
    ## maximize summed survivor happiness. Byte-stable: no randomness.
    return %*{
      "version": 1,
      "traits": {"aggression": 0, "trade": 1, "lending": 1, "fertility": 1},
      "movement": [{"score": welfare}]}
  if targetId == "wealth.egalitarian":
    ## Flatten the wealth distribution: avoid piling onto rich prey cells.
    return %*{
      "version": 1,
      "traits": {"aggression": 0, "trade": 1, "lending": 1},
      "movement": [
        {"score": %*["-", welfare, ["*", 0.5, ["get", "cell.preyWealth"]]]}]}
  if variable == "population" or variable == "age_at_death":
    return %*{
      "version": 1,
      "traits": {"fertility": 1, "aggression": 0},
      "movement": [{"score": welfare}]}
  if variable == "majority_tribe_share":
    ## Convergence herds together (+occupied), diversity spreads out.
    let direction = if targetId == "tribe.convergence": 1 else: -1
    return %*{
      "version": 1,
      "movement": [{"score": %*["+", welfare, ["*", direction, occupied]]}]}
  if variable == "sick_fraction":
    ## Endemic disease wants mixing, eradication wants distancing.
    let direction = if targetId == "disease.endemic": 1 else: -2
    return %*{
      "version": 1,
      "movement": [{"score": %*["+", welfare, ["*", direction, occupied]]}]}
  if variable == "mean_trade_price":
    return %*{
      "version": 1,
      "traits": {"trade": 1, "aggression": 0},
      "movement": [{"score": welfare}]}
  welfareChaser()

proc actionFromObservation*(message: JsonNode): JsonNode =
  ## Action the seat would submit for this observation.
  %*{"type": "action", "ruleset": chooseRuleset(targetFromObservation(message))}

proc connectClient(): CoworldClient =
  ## The runner often hands us COWORLD_PLAYER_WS_URL before the game
  ## socket accepts. One failed dial used to kill the seat (dead-seat
  ## signature). Retry until the game is up.
  while true:
    try:
      return newCoworldClient("masha")
    except CatchableError:
      echo "masha: connect retry: ", getCurrentExceptionMsg()
      sleep(250)

proc main() =
  let client = connectClient()
  var fellBack = false
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "observation":
      let protocol = message{"protocol"}.getStr()
      if protocol.len > 0 and protocol != Protocol:
        echo "masha: unexpected protocol ", protocol
      let
        target = targetFromObservation(message)
        action = actionFromObservation(message)
      echo "masha: seat ", message{"seat"}.getInt(),
        " target ", target{"id"}.getStr(),
        " kind ", target{"kind"}.getStr()
      client.send(action)
    of "ack":
      if message{"valid"}.getBool():
        ## Submission is recorded before this ack; stay connected until
        ## `result` so the player pod outlives the 1,000-tick run.
        echo "masha: ruleset accepted"
      else:
        echo "masha: ruleset rejected: ", message{"errors"}
        if fellBack:
          echo "masha: fallback rejected too, giving up"
          quit(1)
        fellBack = true
        client.send(%*{"type": "action", "ruleset": welfareChaser()})
    of "result":
      echo "masha: result ", message{"scores"}
      quit(0)
    else:
      discard

when isMainModule and not declared(mashaOfflineHarness):
  main()
