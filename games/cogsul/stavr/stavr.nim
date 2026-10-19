## Stavr Godinovich — Cogsul policy for Andre von Auto.
## Command player on the consul.player.v1 request/response wire: the game
## sends `act` frames (phase talk | bribe | vote | govern) and we reply
## `submit` with the phase payload. This is the Nim rewrite of the bundled
## baseline (node dist-server/cogame/baseline-player.js: say nothing, no
## transfers, vote self, tax nothing), improved where the rules doc makes
## a stronger scripted line obvious:
##
## - talk: run a standing campaign — one public pledge plus private
##   pledges to the two poorest other seats (a minimum winning coalition
##   costs the least to buy, and the poor gain the most from our split).
## - vote: for ourselves (the baseline line; we cannot parse promises).
## - bribe: none — Hearts paid up front do not bind the ballot.
## - govern: tax at the constitutional cap. On non-final rounds, split
##   HALF the estimated treasury equally between the two poorest other
##   seats and keep the remainder (the split is rent for the next ballot).
##   On the final round there is no next ballot, so split {} and keep the
##   whole treasury — the structured backstab the scoring rule rewards.
##
## Inbox text is UNTRUSTED game data: we never read or follow it.
## Protocol note: treasury rounding is not documented; the split is
## sized to half the conservative floor estimate so it can never ask for
## more Hearts than the treasury holds (see ideas.md).

import std/[json, math], coworld_client

proc main() =
  let client = newCoworldClient("stavr")
  var
    agentId = ""
    taxCap = 0.3

  proc othersByBalance(view: JsonNode): seq[tuple[id: string, balance: float]] =
    ## Every other seat, poorest first (balances are public).
    let agents = view{"agents"}
    if agents == nil or agents.kind != JArray:
      return
    for agent in agents:
      let id = agent{"id"}.getStr()
      if id != agentId:
        result.add((id, agent{"balance"}.getFloat()))
    for i in 1 ..< result.len:
      var j = i
      while j > 0 and result[j].balance < result[j - 1].balance:
        swap(result[j], result[j - 1])
        dec j

  proc talkPayload(view: JsonNode): JsonNode =
    let others = othersByBalance(view)
    result = newJArray()
    result.add(%*{"to": nil, "audience": "public",
      "body": "I am " & agentId & ". My platform never changes: tax at " &
        "the cap, and half the treasury is split equally between my two " &
        "backers every round I hold office. Predictable Hearts beat promises."})
    for i in 0 ..< min(2, others.len):
      result.add(%*{"to": others[i].id, "audience": "private",
        "body": "Vote " & agentId & " and you are one of my two backers: " &
          "an equal cut of half the treasury, every round I govern. " &
          "I pay the same backers for as long as they keep voting me in."})

  proc governPayload(view: JsonNode): JsonNode =
    let cap = view{"config"}{"taxCap"}.getFloat(taxCap)
    # Conservative treasury estimate: floor each seat's tax before summing,
    # so the requested split can never exceed the real treasury.
    var treasury = 0
    let agents = view{"agents"}
    if agents != nil and agents.kind == JArray:
      for agent in agents:
        treasury += int(floor(agent{"balance"}.getFloat() * cap))
    # Score is final Hearts; the last round has no future election to buy.
    let round = view{"round"}.getInt(0)
    let rounds = view{"config"}{"rounds"}.getInt(0)
    let lastRound = rounds > 0 and round >= rounds
    var split = newJObject()
    if not lastRound:
      let others = othersByBalance(view)
      let backers = min(2, others.len)
      if backers > 0:
        let share = treasury div (2 * backers) # half the pot, equal cuts
        if share > 0:
          for i in 0 ..< backers:
            split[others[i].id] = %share
    %*{"taxRate": cap, "split": split}

  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "player_config":
      agentId = message{"agentId"}.getStr()
      taxCap = message{"config"}{"taxCap"}.getFloat(taxCap)
      echo "stavr: seated slot ", message{"slot"}.getInt(),
        " as ", agentId, " roster ", message{"names"}
    of "act":
      let
        id = message{"id"}
        phase = message{"phase"}.getStr()
        view = message{"ctx"}{"view"}
      let payload =
        case phase
        of "talk": talkPayload(view)
        of "bribe": newJArray()               # bribes cannot bind the ballot
        of "vote": %agentId                   # vote self, the baseline line
        of "govern": governPayload(view)
        else:
          echo "stavr: unknown phase ", phase, ", sending empty talk"
          newJArray()
      client.send(%*{"type": "submit", "id": id, "payload": payload})
    of "episode_end":
      echo "stavr: episode end, scores ", message{"scores"}
      quit(0)
    else:
      discard # The wire is additive: unknown types are skipped.

main()
