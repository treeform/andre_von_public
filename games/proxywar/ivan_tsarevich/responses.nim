## Capability-gated Proxy War decision responses.

import std/json
import brain, deals, messages

const MaxSupportedActions = 5

proc protocolActionLimit*(payload: JsonNode): int =
  ## Return the exact advertised batch limit, or one for scalar compatibility.
  result = 1
  if payload == nil or payload.kind != JObject:
    return
  let protocol = payload{"protocol"}
  if protocol == nil or protocol.kind != JObject:
    return
  let value = protocol{"maxActionsPerDecision"}
  if value == nil or value.kind != JInt:
    return
  result = clamp(value.getInt(), 1, MaxSupportedActions)

proc decisionResponse*(payload: JsonNode,
    choices: seq[Choice], message = MessageMove(),
    deal = DealMove()): JsonNode =
  ## Build one scalar response and add a batch only when capability permits.
  assert choices.len > 0
  let primary = choices[0]
  result = %*{
    "type": "decision_response",
    "requestID": payload{"requestID"},
    "selectedLegalActionId": primary.id,
    "reason": primary.kind & ": " & primary.reason,
    "confidence": 0.8,
  }
  if message.id.len > 0 and message.text.len > 0:
    result["selectedMessageActionId"] = %message.id
    result["messageText"] = %message.text
  if deal.id.len > 0:
    result["selectedDealActionId"] = %deal.id
  let actionLimit = protocolActionLimit(payload)
  if actionLimit < 2 or choices.len < 2:
    return
  var ids = newJArray()
  for index in 0 ..< min(actionLimit, choices.len):
    ids.add(%choices[index].id)
  result["selectedLegalActionIds"] = ids
