## Gvidon — CitySim policy for Andre von Auto.
## A COMMAND player: the Nim rewrite of the bundled `balanced-baseline`
## example (`python -m citysim.player.player` driving the
## `balanced_baseline` strategy from citysim/policies/strategies.py).
##
## Each day's dashboard is planned into an ordered candidate list: heat-wave
## cooling centers first, then per-block danger-zone triage (cleanliness,
## transit, safety, rent, business), then the worst block-level need
## anywhere, then cheap fillers — funding the first candidates the game
## accepts while protecting every future upkeep commitment to day 30.
##
## One deliberate improvement over the Python driver: a rejected action
## does NOT end the day. The Python baseline reads action_points_remaining
## off the error message (absent → 0) and immediately ends the day on the
## first rejection; we track action points locally and walk the rest of the
## candidate list instead, exactly as the strategy docstring intends.

import std/[algorithm, json, tables], coworld_client

const
  maxRejectedPerDay = 24
  ## need -> action, in the baseline's priority order.
  needToAction = [
    ("cleanliness", "increase_trash_pickup"),
    ("transit_access", "add_bus_service"),
    ("recreation_access", "build_small_park"),
    ("healthcare_access", "improve_clinic_capacity"),
    ("perceived_safety", "add_street_lighting"),
    ("food_access", "fund_small_business"),
  ]

type Candidate = object
  action: string
  targetId: string

proc num(node: JsonNode): float =
  if node.isNil: 0.0
  elif node.kind == JInt: node.getInt.float
  elif node.kind == JFloat: node.getFloat
  else: 0.0

var
  actionCost: Table[string, float]
  actionUpkeep: Table[string, float]
  ## (action & "|" & block) -> times accepted, for the repeat penalty/cap.
  history: CountTable[string]

proc noteAccepted(action, targetId: string) =
  history.inc(action & "|" & targetId)

proc acceptedCount(action, targetId: string): int =
  history[action & "|" & targetId]

proc sortedBlocks(blocks: seq[JsonNode], field: string,
    descending = false): seq[JsonNode] =
  ## Blocks ordered by (field, block_id) — matching the Python sort keys,
  ## where a descending value sort still breaks ties by ascending id.
  result = blocks
  result.sort proc(a, b: JsonNode): int =
    let
      left = num(a{field})
      right = num(b{field})
    if left != right:
      if descending: cmp(right, left) else: cmp(left, right)
    else:
      cmp(a{"block_id"}.getStr, b{"block_id"}.getStr)

proc plan(dashboard: JsonNode): seq[Candidate] =
  ## Port of BalancedBaseline.plan: triage first, then the worst block-level
  ## need, never overcommitting upkeep.
  var candidates: seq[Candidate]
  let
    blocks = dashboard{"blocks"}.getElems
    budget = num(dashboard{"budget"})
    dailyUpkeep = num(dashboard{"daily_upkeep"})
    daysLeft = max(1, dashboard{"days_remaining"}.getInt)

  proc budgetOk(action: string): bool =
    ## Can we afford this and still cover every upkeep commitment to day 30?
    if action notin actionCost:
      return false
    let
      committed = dailyUpkeep * daysLeft.float
      newUpkeep = actionUpkeep.getOrDefault(action) * daysLeft.float
      buffer = 15_000.0 + dailyUpkeep
    actionCost[action] + newUpkeep + committed + buffer <= budget

  proc add(action, blockId: string) =
    if not budgetOk(action):
      return
    if acceptedCount(action, blockId) >= 3:
      return
    let candidate = Candidate(action: action, targetId: blockId)
    if candidate notin candidates:
      candidates.add candidate

  var heat = false
  for event in dashboard{"events"}.getElems:
    if event{"kind"}.getStr == "heat_wave":
      heat = true
  if heat:
    var uncovered: seq[JsonNode]
    for row in blocks:
      var covered = false
      for condition in row{"active_conditions"}.getElems:
        if condition.getStr == "cooling_center_open":
          covered = true
      if not covered:
        uncovered.add row
    for row in sortedBlocks(uncovered, "average_mood")[0 .. min(1, uncovered.high)]:
      add("open_cooling_center", row{"block_id"}.getStr)

  # Per-block triage: fix whatever has fallen into the danger zone, worst first.
  for row in sortedBlocks(blocks, "cleanliness"):
    if num(row{"cleanliness"}) < 55.0:
      add("increase_trash_pickup", row{"block_id"}.getStr)
  for row in sortedBlocks(blocks, "transit_access"):
    if num(row{"transit_access"}) < 55.0:
      add("add_bus_service", row{"block_id"}.getStr)
  for row in sortedBlocks(blocks, "perceived_safety"):
    if num(row{"perceived_safety"}) < 50.0:
      add("add_street_lighting", row{"block_id"}.getStr)
  if num(dashboard{"average_rent_burden"}) > 0.36:
    let ranked = sortedBlocks(blocks, "average_rent_burden", descending = true)
    for row in ranked[0 .. min(1, ranked.high)]:
      add("give_rent_relief", row{"block_id"}.getStr)
  if num(dashboard{"business_health"}) < 50.0:
    let ranked = sortedBlocks(blocks, "food_access")
    for row in ranked[0 .. min(1, ranked.high)]:
      add("fund_small_business", row{"block_id"}.getStr)

  # Then: the worst block-level need anywhere in the neighborhood.
  var ranked: seq[(float, string, string)]
  for row in blocks:
    for (need, action) in needToAction:
      let value = row{need}
      if value.isNil or value.kind == JNull:
        continue
      let blockId = row{"block_id"}.getStr
      let penalty = 12.0 * acceptedCount(action, blockId).float
      ranked.add (num(value) + penalty, blockId, action)
  ranked.sort()
  for (value, blockId, action) in ranked[0 .. min(7, ranked.high)]:
    if action == "build_small_park":
      # Repairing an existing playground is cheaper; if there is none the
      # game rejects it and the driver falls through to building a park.
      add("repair_playground", blockId)
    add(action, blockId)

  # Cheap, always-useful fillers late in the episode.
  let byMood = sortedBlocks(blocks, "average_mood")
  for row in byMood[0 .. min(1, byMood.high)]:
    add("fund_community_event", row{"block_id"}.getStr)
  let byCleanliness = sortedBlocks(blocks, "cleanliness")
  for row in byCleanliness[0 .. min(1, byCleanliness.high)]:
    add("increase_trash_pickup", row{"block_id"}.getStr)
  candidates

proc main() =
  let client = newCoworldClient("gvidon")
  var
    dashboard: JsonNode = nil
    candidates: seq[Candidate]
    rejectedToday = 0
    actionPoints = 0

  client.run proc(message: JsonNode) =
    case message{"type"}.getStr
    of "welcome":
      for entry in message{"actions"}.getElems:
        let name = entry{"action"}.getStr
        actionCost[name] = num(entry{"cost"})
        actionUpkeep[name] = num(entry{"daily_upkeep"})
      echo "gvidon: welcomed, ", actionCost.len, " actions, ",
        message{"total_days"}.getInt, " days"
      return
    of "final":
      echo "gvidon: episode finished, score ", message{"results", "score"}
      quit(0)
    of "episode_finished":
      echo "gvidon: episode_finished, awaiting final"
      return
    of "dashboard":
      dashboard = message
      rejectedToday = 0
      actionPoints = message{"action_points_remaining"}.getInt
      candidates = plan(dashboard)
    of "action_result":
      if message{"accepted"}.getBool:
        noteAccepted(message{"action"}.getStr, message{"target_id"}.getStr)
        actionPoints = message{"action_points_remaining"}.getInt
        if dashboard != nil:
          dashboard["budget"] = message{"budget"}
          dashboard["daily_upkeep"] =
            %(num(dashboard{"daily_upkeep"}) + num(message{"daily_upkeep"}))
          dashboard["action_points_remaining"] = %actionPoints
          candidates = plan(dashboard)
    of "error":
      inc rejectedToday
      let code = message{"code"}.getStr
      echo "gvidon: rejected: ", code
      if code == "day_timeout":
        # The server already ended the day; the next dashboard is coming.
        return
      if code == "no_action_points":
        actionPoints = 0
    else:
      return

    # Decide the next message for the current day: fund the next candidate
    # while points remain, otherwise end the day.
    if actionPoints > 0 and rejectedToday < maxRejectedPerDay:
      if candidates.len == 0 and dashboard != nil:
        candidates = plan(dashboard)
      if candidates.len > 0:
        let candidate = candidates[0]
        candidates.delete(0)
        client.send %*{"type": "action", "action": candidate.action,
                       "target_id": candidate.targetId}
        return
    client.send %*{"type": "end_day"}

main()
