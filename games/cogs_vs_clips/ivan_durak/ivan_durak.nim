## Ivan Durak — Cogs vs Clips policy for Andre von Auto.
## Command player: connects to COWORLD_PLAYER_WS_URL and speaks
## coworld.player.v1 — receives player_config + per-step token
## observations as JSON and replies with action names every step.
## The strategy is the dinky agent (copied from ~/p/dinky), a scripted
## mining / junction / drafting bot that reads MettaGrid token
## observations directly.

import std/[json, options, os], whisky, dinky_agents

proc buildEnvironmentConfig(policyEnv: JsonNode): string =
  ## Rebuild the PolicyEnvInterface.to_json() shape that parseConfig expects
  ## from the player_config message's policy_env dump.
  var actions = newJArray()
  for action in policyEnv["action_names"]:
    actions.add(action)
  if policyEnv.hasKey("vibe_action_names"):
    for action in policyEnv["vibe_action_names"]:
      actions.add(action)
  let egocentricShape = policyEnv["egocentric_shape"]
  $(%*{
    "num_agents": policyEnv["num_agents"],
    "obs_height": egocentricShape[0],
    "obs_width": egocentricShape[1],
    "actions": actions,
    "tags": policyEnv["tags"],
    "obs_features": policyEnv["obs_features"]
  })

proc main() =
  let url = getEnv("COWORLD_PLAYER_WS_URL")
  if url == "":
    quit("COWORLD_PLAYER_WS_URL is not set", 1)
  echo "ivan_durak: connecting to ", url
  let ws = newWebSocket(url)
  var
    agent: DinkyAgent
    actionNames: seq[string]
    numAgents = 0

  while true:
    var received: Option[Message]
    try:
      received = ws.receiveMessage()
    except CatchableError:
      echo "ivan_durak: websocket closed (", getCurrentExceptionMsg(),
        "), exiting"
      break
    if received.isNone:
      continue
    let message = received.get()
    if message.kind == Ping:
      ws.send(message.data, Pong)
      continue
    if message.kind != TextMessage:
      continue

    let m = parseJson(message.data)
    case m["type"].getStr()
    of "player_config":
      let
        policyEnv = m["policy_env"]
        slot = m["slot"].getInt()
      numAgents = policyEnv["num_agents"].getInt()
      actionNames = @[]
      for action in policyEnv["action_names"]:
        actionNames.add(action.getStr())
      if policyEnv.hasKey("vibe_action_names"):
        for action in policyEnv["vibe_action_names"]:
          actionNames.add(action.getStr())
      agent = newDinkyAgent(slot, buildEnvironmentConfig(policyEnv))
      echo "ivan_durak: configured slot ", slot,
        " numAgents=", numAgents, " numActions=", actionNames.len
    of "observation":
      if agent == nil:
        continue
      let tokens = m["observation"]
      let numTokens = tokens.len
      var observation = newSeq[uint8](max(numTokens, 1) * 3)
      for i, token in tokens.getElems():
        observation[i * 3 + 0] = uint8(token[0].getInt())
        observation[i * 3 + 1] = uint8(token[1].getInt())
        observation[i * 3 + 2] = uint8(token[2].getInt())
      var action: int32 = 0
      step(
        agent, numAgents, numTokens, 3,
        observation[0].addr, actionNames.len, action.addr
      )
      if action < 0 or action >= actionNames.len.int32:
        action = 0
      let reply = %*{
        "type": "action",
        "action_name": actionNames[action],
        "policy_infos": parseJson(agent.infosJson),
        "request_id": "step-" & $m["step"].getInt()
      }
      ws.send($reply)
    of "final":
      echo "ivan_durak: final message received, exiting"
      break
    else:
      discard

main()
