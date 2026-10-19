## Structured deal selection and treaty compliance.
##
## Deals use an independent response slot. The gameplay brain receives a
## filtered menu only when this candidate is enabled, so an accepted pact is
## honored and no side-slot action can accidentally become the primary move.

import std/[json, tables]
import observation

const
  MaxProposalsPerRival = 2
  DealKinds = [
    "deal_propose",
    "deal_accept",
    "deal_reject",
    "deal_withdraw"
  ]
  AbstentionTemplates = [
    "non_aggression_pact",
    "trade_security_pact"
  ]
  AbstentionObligations = [
    "non_aggression",
    "trade_security"
  ]

type
  DealMove* = object
    ## One exact currently offered structured-deal action.
    id*: string
    kind*: string

  DealMemory* = object
    ## Match-scoped proposal limits and reachability counts.
    proposals*: Table[string, int]
    selected*: int
    proposed*: int
    accepted*: int
    rejected*: int

  TreatyPartners = object
    partners: Table[string, bool]
    tradePartners: Table[string, bool]

proc ownPlayerID(world: Observation): string =
  ## Return our server-owned episode player identifier.
  observation.getStr(world.raw{"ownState"}, "playerID")

proc playerAlive(world: Observation, playerID: string): bool =
  ## Report whether a visible counterparty is still alive.
  if world.rivalByID.hasKey(playerID):
    return world.rivals[world.rivalByID[playerID]].isAlive

proc actionMeta(action: Action, key: string): string =
  ## Read one structured-deal action metadata string.
  observation.getStr(action.meta, key)

proc incomingProposal(world: Observation): JsonNode =
  ## Return the incoming proposal with the nearest answer deadline.
  let incoming = world.raw{"deals"}{"incomingProposals"}
  if incoming == nil or incoming.kind != JArray:
    return nil
  var nearest = high(int)
  for proposal in incoming:
    let deadline = observation.getInt(
      proposal,
      "answerableThroughStep",
      high(int)
    )
    if result == nil or deadline < nearest:
      result = proposal
      nearest = deadline

proc answerAction(actions: seq[Action], dealID: string,
    kind: string): Action =
  ## Find the exact offered answer action for one proposal.
  for action in actions:
    if action.kind == kind and actionMeta(action, "dealID") == dealID:
      return action

proc acceptTemplate(templateName: string): bool =
  ## Accept only pacts the compliance guard can honor or costless joint asks.
  templateName in AbstentionTemplates or templateName == "joint_attack"

proc hostileTarget(actions: seq[Action], selectedActionID: string): string =
  ## Return the target of a newly selected non-expansion hostile move.
  if selectedActionID.len == 0:
    return
  for action in actions:
    if action.id != selectedActionID:
      continue
    let targetID = actionMeta(action, "targetID")
    case action.kind
    of "attack":
      if not observation.getBool(action.meta, "expansion"):
        return targetID
    of "nuke":
      return targetID
    of "boat":
      if observation.getBool(action.meta, "navalInvasion") and
        not observation.getBool(action.meta, "expansion"):
          return targetID
    else:
      discard
    return

proc openCounterparties(world: Observation): Table[string, bool] =
  ## Collect every counterparty with an outgoing or active deal.
  let ownID = ownPlayerID(world)
  for field in ["outgoingProposals", "activeDeals"]:
    let views = world.raw{"deals"}{field}
    if views == nil or views.kind != JArray:
      continue
    for view in views:
      let
        proposerID = observation.getStr(view, "proposerPlayerID")
        recipientID = observation.getStr(view, "recipientPlayerID")
      if proposerID.len > 0 and proposerID != ownID:
        result[proposerID] = true
      if recipientID.len > 0 and recipientID != ownID:
        result[recipientID] = true

proc chooseDealMove*(enabled: bool, world: Observation,
    actions: seq[Action], memory: var DealMemory,
    selectedActionID = ""): DealMove =
  ## Answer one deal first, otherwise propose one bounded border pact.
  if not enabled or not world.hasSpawned:
    return
  let deals = world.raw{"deals"}
  if deals == nil or deals.kind != JObject:
    return
  let
    selectedTargetID = hostileTarget(actions, selectedActionID)
    proposal = incomingProposal(world)
  if proposal != nil:
    let
      dealID = observation.getStr(proposal, "dealID")
      proposerID = observation.getStr(proposal, "proposerPlayerID")
      templateName = observation.getStr(proposal{"terms"}, "template")
      rival =
        if world.rivalByID.hasKey(proposerID):
          world.rivals[world.rivalByID[proposerID]]
        else:
          Rival()
      accept = playerAlive(world, proposerID) and
        acceptTemplate(templateName) and selectedTargetID != proposerID and
        not rival.incomingAttack and not rival.outgoingAttack
      wanted = if accept: "deal_accept" else: "deal_reject"
      action = answerAction(actions, dealID, wanted)
    if action.id.len == 0:
      return
    result = DealMove(id: action.id, kind: action.kind)
    inc memory.selected
    if accept:
      inc memory.accepted
    else:
      inc memory.rejected
    return

  let open = openCounterparties(world)
  for action in actions:
    if action.kind != "deal_propose" or
      actionMeta(action, "template") != "non_aggression_pact":
        continue
    let recipientID = actionMeta(action, "recipientID")
    if recipientID.len == 0 or open.hasKey(recipientID) or
      memory.proposals.getOrDefault(recipientID) >= MaxProposalsPerRival:
        continue
    if not world.rivalByID.hasKey(recipientID):
      continue
    let rival = world.rivals[world.rivalByID[recipientID]]
    if not rival.isAlive or not rival.sharesBorder or rival.isAllied or
      rival.incomingAttack or rival.outgoingAttack or
      selectedTargetID == recipientID:
      continue
    memory.proposals[recipientID] =
      memory.proposals.getOrDefault(recipientID) + 1
    inc memory.selected
    inc memory.proposed
    return DealMove(id: action.id, kind: action.kind)

proc treatyPartners(world: Observation): TreatyPartners =
  ## Find active partners plus counterparties awaiting our own pact answer.
  let
    ownID = ownPlayerID(world)
    active = world.raw{"deals"}{"activeDeals"}
  if ownID.len == 0:
    return
  let outgoing = world.raw{"deals"}{"outgoingProposals"}
  if outgoing != nil and outgoing.kind == JArray:
    for proposal in outgoing:
      let
        partnerID = observation.getStr(proposal, "recipientPlayerID")
        templateName = observation.getStr(proposal{"terms"}, "template")
      if partnerID.len == 0 or templateName notin AbstentionTemplates:
        continue
      result.partners[partnerID] = true
      if templateName == "trade_security_pact":
        result.tradePartners[partnerID] = true
  if active == nil or active.kind != JArray:
    return
  for deal in active:
    let
      proposerID = observation.getStr(deal, "proposerPlayerID")
      recipientID = observation.getStr(deal, "recipientPlayerID")
      partnerID = if proposerID == ownID: recipientID else: proposerID
      obligations = deal{"obligations"}
    if partnerID.len == 0 or obligations == nil or
      obligations.kind != JArray:
        continue
    for obligation in obligations:
      if observation.getStr(obligation, "obligorPlayerID") != ownID or
        observation.getStr(obligation, "status") != "pending":
          continue
      let kind = observation.getStr(obligation, "kind")
      if kind in AbstentionObligations:
        result.partners[partnerID] = true
      if kind == "trade_security":
        result.tradePartners[partnerID] = true

proc breachesTreaty(action: Action, treaties: TreatyPartners): bool =
  ## Mirror the referee's targeted hostility and voluntary embargo rules.
  let
    targetID = actionMeta(action, "targetID")
    aimedAtPartner = targetID.len > 0 and
      treaties.partners.hasKey(targetID)
    expansion = observation.getBool(action.meta, "expansion")
  case action.kind
  of "attack":
    aimedAtPartner and not expansion
  of "nuke":
    aimedAtPartner
  of "boat":
    aimedAtPartner and
      observation.getBool(action.meta, "navalInvasion") and not expansion
  of "embargo":
    targetID.len > 0 and treaties.tradePartners.hasKey(targetID) and
      actionMeta(action, "action") == "start"
  of "embargo_all":
    treaties.tradePartners.len > 0 and actionMeta(action, "action") == "start"
  else:
    false

proc dealGameplayActions*(enabled: bool, world: Observation,
    actions: seq[Action]): seq[Action] =
  ## Remove side-slot actions and any move that would violate an active pact.
  if not enabled:
    return actions
  let treaties = treatyPartners(world)
  for action in actions:
    if action.kind in DealKinds or action.kind == "message":
      continue
    if breachesTreaty(action, treaties):
      continue
    result.add(action)
  if result.len == 0:
    result = actions
