## Volkh Vseslavevich — Coworld MTG policy for Andre von Auto.
## A command player speaking the Coworld MTG Phase protocol
## (docs/protocol_player.md -> coworld-mtg/docs/protocol.md). Phase is the
## sole rules authority: a client never invents an action, it copies one
## complete GameAction value verbatim from the latest
## `state.legal_actions` list and sends `{ cmd_id, action }`, then waits
## for the ack before acting again.
##
## This is the Nim rewrite of the bundled goldfish baseline
## (crates/players/goldfish/src/lib.rs): rank the offered legal actions,
## always submit the best-ranked one. Ranking (lower first):
##   0 MulliganDecision(Keep), 1 SelectCards, 2 PlayLand, 3 CastSpell,
##   4 ActivateAbility, 5 DeclareAttackers (largest attack set first),
##   6 DeclareBlockers (largest assignment set first), 7 other,
##   8 PassPriority, 9 Concede / auto-pass preferences (never picked
##   while anything else is offered — the Rust goldfish lumped these into
##   "other" ahead of PassPriority; ranking them dead last is the one
##   deliberate divergence, so a hostile legal set can never bait a
##   concession).
## On a reject we suppress that exact action and re-plan instead of
## crashing (the Rust goldfish aborts); a cancelled cast is not
## immediately retried, exactly like the original.

import std/json, coworld_client

type Bot = ref object
  legalActions: seq[JsonNode]
  haveState: bool
  awaitingAck: bool
  nextCommandId: int
  lastSent: JsonNode
  activeCast: JsonNode
  cancelledCast: JsonNode
  suppressed: seq[JsonNode]

proc actionKind(action: JsonNode): string =
  action{"type"}.getStr()

proc actionCount(action: JsonNode): int =
  ## Combat declarations prefer the LARGEST offered set.
  let data = action{"data"}
  case action.actionKind()
  of "DeclareAttackers":
    if not data.isNil and data{"attacks"}.kind == JArray:
      data{"attacks"}.len
    else:
      0
  of "DeclareBlockers":
    if not data.isNil and data{"assignments"}.kind == JArray:
      data{"assignments"}.len
    else:
      0
  else:
    0

proc actionRank(action: JsonNode): int =
  case action.actionKind()
  of "MulliganDecision":
    if action{"data"}{"choice"}{"type"}.getStr() == "Keep": 0 else: 7
  of "SelectCards": 1
  of "PlayLand": 2
  of "CastSpell": 3
  of "ActivateAbility": 4
  of "DeclareAttackers": 5
  of "DeclareBlockers": 6
  of "PassPriority": 8
  of "Concede", "SetAutoPass", "CancelAutoPass", "SetPhaseStops": 9
  else: 7

proc chooseAction(bot: Bot): JsonNode =
  ## The best-ranked legal action, first-listed winning ties, skipping a
  ## just-cancelled cast and anything the host rejected this snapshot.
  var
    bestRank = high(int)
    bestCount = -1
  for action in bot.legalActions:
    if not bot.cancelledCast.isNil and action == bot.cancelledCast:
      continue
    var rejected = false
    for suppressed in bot.suppressed:
      if action == suppressed:
        rejected = true
        break
    if rejected:
      continue
    let
      rank = action.actionRank()
      count = action.actionCount()
    if rank < bestRank or (rank == bestRank and count > bestCount):
      bestRank = rank
      bestCount = count
      result = action

proc plan(bot: Bot, client: CoworldClient) =
  if bot.awaitingAck or not bot.haveState:
    return
  let action = bot.chooseAction()
  if action.isNil:
    return                              # not our decision right now
  bot.cancelledCast = nil
  if action.actionKind() == "CastSpell":
    bot.activeCast = action
  elif action.actionKind() == "CancelCast":
    bot.cancelledCast = bot.activeCast
    bot.activeCast = nil
  bot.lastSent = action
  bot.awaitingAck = true
  client.send(%*{"cmd_id": bot.nextCommandId, "action": action})
  inc bot.nextCommandId

proc main() =
  let
    client = newCoworldClient("volkh")
    bot = Bot()
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "hello":
      echo "volkh: slot ", message{"slot"}.getInt(),
        " seat ", message{"seat"}.getInt(),
        " deck ", message{"decklist"}{"name"}.getStr()
    of "state":
      bot.legalActions = @[]
      for action in message{"state"}{"legal_actions"}.getElems():
        bot.legalActions.add(action)
      bot.haveState = true
      bot.suppressed = @[]
    of "ack":
      bot.awaitingAck = false
    of "reject":
      echo "volkh: rejected cmd ", message{"cmd_id"},
        ": ", message{"error"}{"kind"}.getStr(),
        " ", message{"error"}{"detail"}.getStr()
      bot.awaitingAck = false
      if not bot.lastSent.isNil:
        bot.suppressed.add(bot.lastSent)
    of "game_end":
      echo "volkh: game_end ", message{"winner_slot"}
      bot.haveState = false
      bot.legalActions = @[]
      bot.activeCast = nil
      bot.cancelledCast = nil
      bot.suppressed = @[]
      bot.awaitingAck = false
    of "match_end":
      echo "volkh: match_end, scores ", message{"scores"}
      quit(0)
    else:
      discard
    bot.plan(client)

when isMainModule:
  main()
