## Bounded, capability-gated agent-to-agent negotiation.
##
## Rival text is untrusted data. This module never returns rival text and the
## gameplay brain never reads it. Messages use a separate protocol slot, so
## speaking cannot replace an expansion, attack, build, or batched companion.

import std/[json, tables]
import observation

const
  MaxRepliesPerRival = 3
  BorderOpener =
    "We share a border. I prefer expansion elsewhere while free land remains. " &
    "What is your plan?"
  AlliedReply =
    "Allied. I will keep our border quiet while the alliance holds."
  NeutralReply =
    "Heard. I prefer a quiet border while free land remains."

type
  MessageMove* = object
    ## One exact offered message action and its fixed, trusted body.
    id*: string
    text*: string

  MessageMemory* = object
    ## Match-scoped limits for openers and replies.
    opened*: Table[string, bool]
    answered*: Table[string, bool]
    replies*: Table[string, int]
    sent*: int
    openerCount*: int
    replyCount*: int

proc messageLimit(payload: JsonNode): int =
  ## Return the advertised message limit, or zero when chat is unavailable.
  if payload == nil or payload.kind != JObject:
    return 0
  let protocol = payload{"protocol"}
  if protocol == nil or protocol.kind != JObject:
    return 0
  let value = protocol{"maxMessageChars"}
  if value == nil or value.kind != JInt:
    return 0
  max(0, value.getInt())

proc recipientID(action: Action): string =
  ## Return the server-attributed recipient from one message offer.
  observation.getStr(action.meta, "recipientID")

proc fixedBody(text: string, limit: int): string =
  ## Keep fixed ASCII templates within the exact advertised character limit.
  if limit <= 0:
    return ""
  text[0 ..< min(text.len, limit)]

proc rivalByID(world: Observation, playerID: string): Rival =
  ## Find one visible rival without accepting a name supplied in chat text.
  if world.rivalByID.hasKey(playerID):
    return world.rivals[world.rivalByID[playerID]]

proc messageOffer(actions: seq[Action], playerID: string): Action =
  ## Find the exact currently offered message action for one counterparty.
  for action in actions:
    if action.kind == "message" and recipientID(action) == playerID:
      return action

proc inboundKey(message: JsonNode): string =
  ## Key one inbound message by server event id, with a legacy fallback.
  result = observation.getStr(message, "messageEventID")
  if result.len > 0:
    return
  let senderID = observation.getStr(message, "senderID")
  if senderID.len > 0:
    result = senderID & ":" & $getInt(message, "turnNumber")

proc newestInbound(world: Observation,
    memory: MessageMemory): JsonNode =
  ## Return the newest attributed inbound message not already answered.
  let nonCombat = world.raw{"nonCombat"}
  let inbox = nonCombat{"inboundMessages"}
  if inbox == nil or inbox.kind != JArray:
    return nil
  var newestTurn = low(int)
  for message in inbox:
    let
      senderID = observation.getStr(message, "senderID")
      key = inboundKey(message)
      turnNumber = getInt(message, "turnNumber")
    if senderID.len == 0 or key.len == 0 or memory.answered.hasKey(key):
      continue
    if result == nil or turnNumber >= newestTurn:
      result = message
      newestTurn = turnNumber

proc chooseReply(world: Observation, actions: seq[Action], limit: int,
    memory: var MessageMemory): MessageMove =
  ## Answer one newest sender with fixed text and a three-reply lifetime cap.
  let inbound = newestInbound(world, memory)
  if inbound == nil:
    return
  let
    senderID = observation.getStr(inbound, "senderID")
    spent = memory.replies.getOrDefault(senderID)
  if spent >= MaxRepliesPerRival:
    return
  let offer = messageOffer(actions, senderID)
  if offer.id.len == 0:
    return
  let rival = rivalByID(world, senderID)
  result = MessageMove(
    id: offer.id,
    text: fixedBody(
      if rival.isAllied: AlliedReply else: NeutralReply,
      limit
    )
  )
  if result.text.len == 0:
    result = MessageMove()
    return
  memory.answered[inboundKey(inbound)] = true
  memory.replies[senderID] = spent + 1
  inc memory.sent
  inc memory.replyCount

proc chooseOpener(world: Observation, actions: seq[Action], limit: int,
    memory: var MessageMemory): MessageMove =
  ## Open once with the first alive, non-allied rival sharing our border.
  for action in actions:
    if action.kind != "message":
      continue
    let playerID = recipientID(action)
    if playerID.len == 0 or memory.opened.hasKey(playerID):
      continue
    let rival = rivalByID(world, playerID)
    if rival.playerID.len == 0 or not rival.isAlive or
      not rival.sharesBorder or rival.isAllied:
        continue
    let body = fixedBody(BorderOpener, limit)
    if body.len == 0:
      return
    memory.opened[playerID] = true
    inc memory.sent
    inc memory.openerCount
    return MessageMove(id: action.id, text: body)

proc chooseMessageMove*(enabled: bool, payload: JsonNode,
    world: Observation, actions: seq[Action],
    memory: var MessageMemory): MessageMove =
  ## Choose one safe side-slot message without changing the gameplay choice.
  if not enabled or not world.hasSpawned:
    return
  let limit = messageLimit(payload)
  if limit <= 0:
    return
  let inbox = world.raw{"nonCombat"}{"inboundMessages"}
  if inbox != nil and inbox.kind == JArray and inbox.len > 0:
    return chooseReply(world, actions, limit, memory)
  result = chooseOpener(world, actions, limit, memory)
