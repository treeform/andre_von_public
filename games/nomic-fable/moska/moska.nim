## Moska — Nomic Fable policy for Andre von Auto.
## Command player: three seats take turns proposing rule changes; the two
## non-proposers debate, all three vote, and a judge LLM executes the
## rulebook. This is a Nim rewrite of the deterministic `scribe` baseline
## (templated proposals, formulaic debates, deterministic votes) with
## the upgrades the scoring math actually pays: proposals are unambiguous
## judge-executable rule text, we always back our own bills, we vote nay
## on anything that singles out another seat, and we pick the template
## by standing so the bill can pass. A victory-threshold cut while
## leading is a free -1 under rule 202 — the other two seats will not
## vote to let us win — so we never table one.
##
## Protocol (docs/protocol_player.md): every request carries `rid` and the
## reply must echo it; missing/late/malformed replies become the phase
## default (nay for votes), so we always answer inside the window.
## Zero model calls — no secret-envs needed at upload time.

import std/[json, strutils], coworld_client

type Moska = ref object
  seat: int
  turn: int
  points: seq[int]
  victoryPoints: int
  lastProposer: int

proc readState(policy: Moska, state: JsonNode) =
  if state.kind != JObject: return
  let players = state{"players"}
  if players != nil and players.kind == JArray:
    policy.points = @[]
    for player in players:
      policy.points.add player{"points"}.getInt(0)
  let victory = state{"common", "victory_points"}
  if victory != nil and victory.kind == JInt:
    policy.victoryPoints = victory.getInt()

proc myPoints(policy: Moska): int =
  if policy.seat >= 0 and policy.seat < policy.points.len:
    policy.points[policy.seat]
  else:
    0

proc strictlyLeading(policy: Moska): bool =
  if policy.seat < 0 or policy.seat >= policy.points.len: return false
  for seat, points in policy.points:
    if seat != policy.seat and points >= policy.points[policy.seat]:
      return false
  true

proc minPoints(policy: Moska): int =
  if policy.points.len == 0: return 0
  result = policy.points[0]
  for points in policy.points:
    if points < result: result = points

proc lastPlaceCount(policy: Moska): int =
  if policy.points.len == 0: return 0
  let low = policy.minPoints()
  for points in policy.points:
    if points == low: inc result

proc isLast(policy: Moska): bool =
  policy.points.len > 0 and policy.myPoints() <= policy.minPoints()

proc chooseProposal(policy: Moska): string =
  ## Position-aware, passable rule text. Catch-up when last (the other
  ## trailer is the swing vote); universal +2/turn when leading or
  ## 3-way tied so we race to the threshold. Never move victory_points —
  ## the other two seats nay and rule 202 docks the failed proposer.
  let ruleId = 300 + policy.turn
  if policy.strictlyLeading() or policy.lastPlaceCount() >= 3:
    "Enact rule " & $ruleId & ": at the end of each turn, every player " &
    "gains 2 points."
  elif policy.isLast():
    "Enact rule " & $ruleId & ": at the end of each turn, the player with " &
    "the fewest points gains 3 points; if several players tie for fewest, " &
    "each tied player gains 3 points."
  else:
    "Enact rule " & $ruleId & ": when a proposal passes, its proposer " &
    "gains 2 points in addition to any other award."

proc favors(text: string, seat: int): bool =
  ## Does the proposal text name this seat directly?
  let lowered = text.toLowerAscii()
  ("seat " & $seat) in lowered or ("seat-" & $seat) in lowered or
    ("player " & $seat) in lowered

proc voteAye(policy: Moska, text: string, proposer: int): bool =
  ## Own bills always; symmetric point gains usually; targeted or
  ## threshold-moving bills from others never.
  if proposer == policy.seat: return true
  let lowered = text.toLowerAscii()
  if favors(text, policy.seat) and not favors(text, (policy.seat + 1) mod 3) and
      not favors(text, (policy.seat + 2) mod 3):
    return true
  for seat in 0 ..< 3:
    if seat != policy.seat and favors(text, seat):
      return false
  if "victory_points" in lowered or "victory threshold" in lowered or
      "victory point" in lowered:
    return false
  let symmetric = "every player" in lowered or "all players" in lowered or
    "each player" in lowered
  let harmful = "lose" in lowered or "loses" in lowered or "pays" in lowered or
    "pay " in lowered or "deduct" in lowered or "forfeit" in lowered
  symmetric and not harmful

proc proposalText(request: JsonNode): string =
  ## vote/debate requests carry `proposal`; tolerate string or object form.
  let proposal = request{"proposal"}
  if proposal == nil: return ""
  if proposal.kind == JString: return proposal.getStr()
  if proposal.kind == JObject: return proposal{"text"}.getStr()
  ""

proc proposalProposer(policy: Moska, request: JsonNode): int =
  let proposal = request{"proposal"}
  if proposal != nil and proposal.kind == JObject and
      proposal.hasKey("proposer"):
    return proposal{"proposer"}.getInt(policy.lastProposer)
  policy.lastProposer

proc main() =
  let client = newCoworldClient("moska")
  let policy = Moska(seat: -1, victoryPoints: 30, lastProposer: -1)
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr()
    of "game_start":
      policy.seat = message{"you", "seat"}.getInt(-1)
      policy.readState(message{"state"})
      echo "moska: seated seat ", policy.seat
    of "turn_start":
      policy.turn = message{"turn"}.getInt(policy.turn + 1)
      policy.lastProposer = message{"proposer"}.getInt(-1)
      policy.readState(message{"state"})
    of "proposal_made":
      policy.lastProposer = message{"proposer"}.getInt(policy.lastProposer)
    of "judge_ruling":
      policy.readState(message{"state"})
    of "proposal_request":
      client.send(%*{"rid": message{"rid"}, "text": policy.chooseProposal()})
    of "debate_request":
      let text = proposalText(message)
      let proposer = policy.proposalProposer(message)
      let stance =
        if policy.voteAye(text, proposer):
          "I will vote aye: the text is clear, executable as written, and " &
          "does not single anyone out. Pass it and move on."
        else:
          "I will vote nay: this bill favors its author more than the " &
          "table, or moves the finish line. We can do better next turn."
      client.send(%*{"rid": message{"rid"}, "text": stance})
    of "vote_request":
      let text = proposalText(message)
      let proposer = policy.proposalProposer(message)
      let vote = if policy.voteAye(text, proposer): "aye" else: "nay"
      client.send(%*{"rid": message{"rid"}, "vote": vote})
    of "game_over":
      echo "moska: game over, scores ", message{"scores"}
    of "final":
      echo "moska: final, scores ", message{"scores"}
      quit(0)
    else:
      discard

main()
