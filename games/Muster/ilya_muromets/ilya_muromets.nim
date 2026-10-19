## Ilya Muromets — Muster policy for Andre von Auto.
## A GENERAL-shape command player: a Nim rewrite of the bundled default
## general (`coworld_pkg.player.player`, the strongest scripted example).
## It answers `observation` frames with a single Muster action dict (no
## envelope) and never replies to `soldier_obs`, so the engine's built-in
## micro drives every unit (protocol: docs/protocol_player.md → the
## muster.player.v1 spec).
##
## Priorities mirror the strong scripted general: mine-first economy on
## explicit coords, concentrate fire on the lowest-HP enemy only when the
## local fight is favorable, then the full naval chain — dock → shipyard →
## escorted transport → launch inward toward the cogosseum — plus the
## bounded recovery/finale verbs (emergency_commission, beachhead_extract,
## beachhead_regroup, last_signal, apex_last_stand) whenever their
## authoritative observation status offers them.
##
## Env tunables (same names and defaults as the Python baseline):
##   MUSTER_DEFAULT_NAVAL_AT, MUSTER_DEFAULT_FIGHTERS, MUSTER_DEFAULT_MIN_CREW,
##   MUSTER_CRUMBLE_PREP_WINDOW, MUSTER_CRUMBLE_LAUNCH_WINDOW,
##   MUSTER_COGOSSEUM_BATTLE_HONORS_MIN, MUSTER_DEFAULT_RACE_INWARD,
##   MUSTER_PROVISION_FOOD_PER_UNIT, MUSTER_PROVISION_IRON_PER_UNIT

import std/[json, os, sets, strutils, tables], coworld_client

## Tunables

let
  navalAt = getEnv("MUSTER_DEFAULT_NAVAL_AT", "3").parseInt
  fighterTarget = getEnv("MUSTER_DEFAULT_FIGHTERS", "1").parseInt
  minCrew = getEnv("MUSTER_DEFAULT_MIN_CREW", "4").parseInt
  crumblePrepWindow = getEnv("MUSTER_CRUMBLE_PREP_WINDOW", "200").parseInt
  crumbleLaunchWindow = getEnv("MUSTER_CRUMBLE_LAUNCH_WINDOW", "90").parseInt
  # Engine apex-ticket docstring: ring2→cogosseum launch is gated at
  # battle_honors >= 4. The Python baseline hunts with honors < 3, so it
  # marks the ticket complete, stops fighting, and spams a refused launch.
  honorsMin = getEnv("MUSTER_COGOSSEUM_BATTLE_HONORS_MIN", "4").parseInt
  raceInward = getEnv("MUSTER_DEFAULT_RACE_INWARD", "1") == "1"
  provisionFoodPerUnit = getEnv("MUSTER_PROVISION_FOOD_PER_UNIT", "8").parseFloat
  provisionIronPerUnit = getEnv("MUSTER_PROVISION_IRON_PER_UNIT", "5").parseFloat

const
  buildOrder = ["refinery", "mine", "farm", "barracks"]
  militaryUnits = ["grunt", "grunt", "archer", "cavalry", "heavy"]

## Costs: building -> (iron, crystal); unit -> (iron, crystal, food, building).
proc buildingCost(building: string): (float, float) =
  case building
  of "mine": (12.0, 0.0)
  of "farm": (10.0, 0.0)
  of "barracks": (25.0, 0.0)
  of "refinery": (20.0, 8.0)
  of "armory": (55.0, 0.0)
  of "dock": (25.0, 3.0)
  of "shipyard": (60.0, 6.0)
  else: (0.0, 0.0)

proc unitCost(unitType: string): (float, float, float, string) =
  case unitType
  of "worker": (10.0, 0.0, 5.0, "")
  of "grunt": (15.0, 0.0, 10.0, "barracks")
  of "archer": (18.0, 8.0, 10.0, "barracks")
  of "cavalry": (30.0, 5.0, 18.0, "barracks")
  of "heavy": (45.0, 0.0, 20.0, "armory")
  of "fighter": (35.0, 20.0, 10.0, "shipyard")
  else: (0.0, 0.0, 0.0, "")

## JSON helpers

proc num(node: JsonNode): float =
  ## Safe numeric read: JSON ints and floats both come back as float.
  if node.isNil: 0.0
  elif node.kind == JInt: node.getInt.float
  elif node.kind == JFloat: node.getFloat
  else: 0.0

proc has(node: JsonNode): bool =
  not node.isNil and node.kind != JNull

proc unitOrdersAction(orders: JsonNode, formationId, intent,
    trigger: string): JsonNode =
  ## A unit-order action with the observability-only formation provenance
  ## the baseline attaches (the engine ignores it while applying movement).
  %*{
    "type": "unit_orders",
    "orders": orders,
    "formation": {
      "formation_id": formationId,
      "intent": intent,
      "trigger": trigger,
      "provenance": "policy_authored",
    },
  }

proc pointOf(node: JsonNode): JsonNode =
  %*[num(node{"x"}), num(node{"y"})]

## The decision

proc decideInner(obs: JsonNode): JsonNode =
  let army = obs{"my_army"}
  if army{"leaderless"}.getBool:
    return %*{"type": "wait"}

  let
    resources = army{"resources"}
    iron = num(resources{"iron"})
    crystal = num(resources{"crystal"})
    food = num(resources{"food"})

  var built, present: HashSet[string]
  for building in army{"buildings"}.getElems:
    present.incl building{"type"}.getStr
    if building{"built"}.getBool:
      built.incl building{"type"}.getStr

  # Planning field: exact q,r coords for each placeable building, so a
  # build is never refused for placement (coord-free builds silently fail).
  let positions = obs{"available_building_positions"}
  var resourceSpots: Table[string, (JsonNode, JsonNode)]
  for spot in positions{"resource"}.getElems:
    resourceSpots[spot{"type"}.getStr] = (spot{"q"}, spot{"r"})
  let
    militarySpots = positions{"military"}.getElems
    shorelineSpots = positions{"shoreline"}.getElems

  proc buildAction(building: string): JsonNode =
    ## A build action with explicit coords; nil when no legal site is known
    ## (the caller skips it instead of looping a refused build).
    case building
    of "mine", "refinery", "farm":
      let kind = {"mine": "iron", "refinery": "crystal",
                  "farm": "food"}.toTable[building]
      if kind in resourceSpots and has(resourceSpots[kind][0]):
        let (q, r) = resourceSpots[kind]
        return %*{"type": "build", "building": building, "q": q, "r": r}
      return nil
    of "barracks", "armory", "academy", "tower":
      if militarySpots.len > 0:
        let spot = militarySpots[0]
        return %*{"type": "build", "building": building,
                  "q": spot{"q"}, "r": spot{"r"}}
      return nil
    of "dock", "shipyard":
      if shorelineSpots.len > 0:
        let spot = shorelineSpots[0]
        return %*{"type": "build", "building": building,
                  "q": spot{"q"}, "r": spot{"r"}}
      return nil
    else:
      return %*{"type": "build", "building": building}

  let
    units = army{"units"}.getElems
    military = army{"military_count"}.getInt
    workers = army{"worker_count"}.getInt
    enemies = obs{"visible_enemies"}.getElems
    naval = obs{"naval"}
    world = obs{"world"}
    ring = world{"current_ring"}.getInt(3)
    honors = obs{"battle_honors"}.getInt
    gatesOpen = obs{"cogosseum_gates_open"}.getBool(true)
    inCogosseum = ring <= 1 or world{"arena_id"}.getStr == "cogosseum"
    crumble = world{"crumble_countdown"}
    rushNaval = has(crumble) and num(crumble) <= crumblePrepWindow.float
    launchNow = has(crumble) and num(crumble) <= crumbleLaunchWindow.float
    stance = army{"general_stance"}.getStr("guarded")

  var generals: seq[JsonNode]
  var generalIds, fighterIds, groundIds: seq[int]
  for unit in units:
    let kind = unit{"type"}.getStr
    if not has(unit{"id"}):
      continue
    case kind
    of "general":
      generals.add unit
      generalIds.add unit{"id"}.getInt
    of "fighter":
      fighterIds.add unit{"id"}.getInt
    of "worker":
      discard
    else:
      groundIds.add unit{"id"}.getInt

  # Last Signal is a real movement/combat episode: accept once, route the
  # surviving general to the nearest unlit relay, then hold the pickup.
  let lastSignal = obs{"last_signal"}
  if lastSignal{"available"}.getBool:
    return %*{"type": "last_signal"}
  if lastSignal{"state"}.getStr in ["gauntlet", "pickup"]:
    if generals.len == 0:
      return %*{"type": "wait"}
    let general = generals[0]
    var target: JsonNode = nil
    if lastSignal{"state"}.getStr == "pickup" and has(lastSignal{"pickup_position"}):
      target = lastSignal{"pickup_position"}
    if target.isNil:
      var bestDistance = 0.0
      for node in lastSignal{"nodes"}.getElems:
        if node{"state"}.getStr != "ready":
          continue
        let
          dx = num(node{"x"}) - num(general{"x"})
          dy = num(node{"y"}) - num(general{"y"})
          distance = dx * dx + dy * dy
        if target.isNil or distance < bestDistance:
          target = pointOf(node)
          bestDistance = distance
    if not target.isNil:
      return unitOrdersAction(
        %*[{"unit_ids": [generals[0]{"id"}.getInt], "target": target}],
        "last_signal_relay_route",
        "activate two reachable relays, then hold the vulnerable pickup",
        "last_signal:" & lastSignal{"state"}.getStr)
    return %*{"type": "wait"}

  let apexFinale = obs{"apex_finale"}
  if apexFinale{"state"}.getStr in ["pending_offer", "offered"]:
    return %*{"type": "apex_last_stand"}
  if apexFinale{"state"}.getStr == "last_stand":
    var enemyGenerals: seq[JsonNode]
    for enemy in enemies:
      if enemy{"type"}.getStr == "general":
        enemyGenerals.add enemy
    if generals.len > 0 and enemyGenerals.len > 0:
      var target = enemyGenerals[0]
      for enemy in enemyGenerals:
        if num(enemy{"hp"}) < num(target{"hp"}):
          target = enemy
      return unitOrdersAction(
        %*[{"unit_ids": [generalIds[0]], "target": pointOf(target),
            "focus_target_id": target{"id"}}],
        "apex_general_hunt",
        "send the surviving general directly after the rival commander",
        "bounded last stand with a visible enemy general")
    if generals.len > 0:
      return unitOrdersAction(
        %*[{"unit_ids": [generalIds[0]], "target": [0, 0]}],
        "apex_center_search",
        "move the surviving general toward the arena center to find a rival",
        "bounded last stand with no visible enemy general")
    return %*{"type": "apex_concede"}

  # The engine owns the eligibility, manifest, and one-use latch of these
  # bounded recovery verbs; the policy only accepts before the window burns.
  if naval{"emergency_commission", "available"}.getBool:
    return %*{"type": "emergency_commission"}
  let extraction = obs{"beachhead_extract"}
  if extraction{"available"}.getBool:
    return %*{"type": "beachhead_extract"}
  if extraction{"state"}.getStr == "winding_up":
    return %*{"type": "wait"}
  if obs{"beachhead_regroup", "available"}.getBool:
    return %*{"type": "beachhead_regroup"}

  var pendingWorkers, pendingFighters, pendingGround = 0
  for entry in army{"recruit_queue"}.getElems:
    let kind = if entry.kind == JObject: entry{"type"}.getStr else: entry.getStr
    case kind
    of "worker": inc pendingWorkers
    of "fighter": inc pendingFighters
    of "", "general": discard
    else: inc pendingGround

  proc canRecruit(unitType: string): bool =
    let (needIron, needCrystal, needFood, needBuilding) = unitCost(unitType)
    iron >= needIron and crystal >= needCrystal and food >= needFood and
      (needBuilding == "" or needBuilding in built)

  # 1. COMBAT REACTION — concentrate fire on the lowest-HP enemy, but ONLY
  #    when we hold a local force advantage; the general never walks into
  #    melee, and the fleet build preempts optional fights.
  var militaryEnemies: seq[JsonNode]
  for enemy in enemies:
    if enemy{"type"}.getStr notin ["worker", "general"]:
      militaryEnemies.add enemy
  let
    enemyForce = militaryEnemies.len
    ground = groundIds.len
    favorable = ground >= max(2, enemyForce) or
      (enemyForce <= 1 and ground >= 2)
    hasShipyardNow = naval{"has_shipyard"}.getBool or "shipyard" in built
    boats = naval{"boats"}.getElems
    fleet = naval{"fleet"}

  var docked: seq[JsonNode]
  for boat in boats:
    if not has(boat{"state"}) or boat{"state"}.getStr in ["docked", "idle"]:
      docked.add boat
  var hasExpeditionTransport = false
  for boat in docked:
    let kind = boat{"type"}
    if (not has(kind) or kind.getStr in ["transport_boat", "transport_airship"]) and
        boat{"recovered_expedition"}.getBool:
      hasExpeditionTransport = true
  let committingToFleet = raceInward and not inCogosseum and
    ground >= navalAt and not hasShipyardNow and not hasExpeditionTransport

  var nearbyEnemyForce = enemyForce
  if generals.len > 0:
    let
      generalX = num(generals[0]{"x"})
      generalY = num(generals[0]{"y"})
    nearbyEnemyForce = 0
    for enemy in militaryEnemies:
      let
        dx = num(enemy{"x"}) - generalX
        dy = num(enemy{"y"}) - generalY
      if dx * dx + dy * dy <= 100.0:
        inc nearbyEnemyForce
  let
    directlyThreatened = nearbyEnemyForce >= max(2, ground)
    honorHunt = ring == 2 and hasExpeditionTransport and ground >= 2 and
      militaryEnemies.len > 0
    honorCampaign = ring == 2 and hasExpeditionTransport and
      honors < honorsMin and military >= 3
    wantStance =
      if (inCogosseum and military >= 3) or honorCampaign: "frontline"
      else: "guarded"
  if wantStance != stance:
    let focus = if inCogosseum: "enemy_general" else: "weakest"
    return %*{"type": "general_stance", "stance": wantStance, "focus": focus}

  let
    plannedCombatPhase = inCogosseum or hasExpeditionTransport or
      directlyThreatened
    ticketComplete = ring == 2 and hasExpeditionTransport and
      honors >= honorsMin
    fightNow = not ticketComplete and ground >= 2 and
      militaryEnemies.len > 0 and plannedCombatPhase and
      (favorable or inCogosseum or directlyThreatened or honorHunt) and
      (not committingToFleet or directlyThreatened) and
      (not rushNaval or directlyThreatened or inCogosseum)
  if fightNow:
    var target = militaryEnemies[0]
    for enemy in militaryEnemies:
      if num(enemy{"hp"}) < num(target{"hp"}):
        target = enemy
    if groundIds.len > 0:
      return unitOrdersAction(
        %*[{"unit_ids": groundIds, "target": pointOf(target),
            "focus_target_id": target{"id"}}],
        "company_focus_fire",
        "concentrate the ground company on the weakest eligible military target",
        "planned combat phase with a favorable, urgent, honor, or apex engagement")
    return %*{"type": "command",
              "content": "Engage that " & target{"type"}.getStr("enemy") & "!",
              "target": pointOf(target)}

  # 2. ECONOMY (mine-first) with explicit coords — the next missing core
  #    building on a real site; no legal site means skip, never loop.
  if not hasExpeditionTransport:
    for building in buildOrder:
      if rushNaval and building == "armory":
        continue
      if building notin present:
        let (needIron, needCrystal) = buildingCost(building)
        if iron >= needIron and crystal >= needCrystal:
          let action = buildAction(building)
          if action != nil:
            return action
          continue
        break

  # 3. A few workers early for income.
  if not hasExpeditionTransport and not rushNaval and
      workers + pendingWorkers < 3 and canRecruit("worker"):
    return %*{"type": "recruit", "unit_type": "worker"}

  # 4. Build a military once the barracks is up; stop gating the fleet on
  #    more recruits at the naval threshold.
  let groundTarget = if rushNaval: 2 else: navalAt
  let mustReserveEscapeHull = launchNow and hasShipyardNow and
    fleet{"total_boats"}.getInt < 1
  if not hasExpeditionTransport and "barracks" in built and
      ground + pendingGround < groundTarget and not mustReserveEscapeHull:
    let index = min(ground + pendingGround, militaryUnits.high)
    var unitType =
      if raceInward and not inCogosseum: "grunt"
      else: militaryUnits[index]
    if unitType == "heavy" and "armory" notin built:
      unitType = "grunt"
    if not canRecruit(unitType):
      unitType = "grunt"
    if canRecruit(unitType):
      return %*{"type": "recruit", "unit_type": unitType}

  # 5. ESCORTED FULL-ARMY RACE INWARD — dock → shipyard → fighters →
  #    transport → embark a full escorted company → launch inward.
  if raceInward and not inCogosseum:
    let
      hasDock = naval{"has_dock"}.getBool or "dock" in built
      hasShipyard = naval{"has_shipyard"}.getBool or "shipyard" in built

    if ground >= groundTarget and not hasExpeditionTransport:
      if not hasDock and "dock" notin present and iron >= 25 and crystal >= 3:
        let action = buildAction("dock")
        if action != nil:
          return action
      if hasDock and not hasShipyard and "shipyard" notin present and
          iron >= 60 and crystal >= 6:
        let action = buildAction("shipyard")
        if action != nil:
          return action

    if hasShipyard or hasExpeditionTransport:
      # Hull before an optional interceptor: newly trained cover can board
      # on the next decision.
      if hasShipyard and fleet{"total_boats"}.getInt < 1 and
          iron >= 30 and crystal >= 2:
        return %*{"type": "build_boat", "boat_type": "transport_boat"}
      if hasShipyard and fighterIds.len + pendingFighters < fighterTarget and
          canRecruit("fighter"):
        return %*{"type": "recruit", "unit_type": "fighter"}
      let
        escortFeasible = hasShipyard and crystal >= unitCost("fighter")[1]
        readyEscort = fighterIds.len >= fighterTarget or not escortFeasible or
          hasExpeditionTransport or launchNow
        ringOk = ring >= 3 or (ring == 2 and honors >= honorsMin and gatesOpen)
      if readyEscort and docked.len > 0 and ringOk:
        let
          boat = docked[0]
          capacity = boat{"capacity"}.getInt(6)
          aboard = boat{"units_aboard"}.getInt
          chest = naval{"honor_war_chest"}
          chestFood = num(chest{"food"})
          chestIron = num(chest{"iron"})
        if aboard < capacity:
          # The commander is part of the company: a detachment without its
          # general is intentionally leaderless and gets absorbed.
          var want: seq[int]
          if generalIds.len > 0:
            want.add generalIds[0]
          let escortSlots = max(1, min(fighterTarget, capacity - want.len))
          for index, id in fighterIds:
            if index >= escortSlots: break
            want.add id
          for id in groundIds:
            if want.len >= capacity: break
            want.add id
          if ring == 2:
            # The ticket's sealed chest funds a blooded vanguard (minimum 3),
            # not necessarily every survivor.
            let affordable = min(capacity, min(
              int((food + chestFood) / provisionFoodPerUnit),
              int((iron + chestIron) / provisionIronPerUnit)))
            if want.len > max(3, affordable):
              want.setLen(max(3, affordable))
          if want.len > capacity:
            want.setLen(capacity)
          if want.len > 0 and want.len > aboard:
            return %*{"type": "embark", "boat_id": boat{"id"},
                      "unit_ids": want}
        let
          crew = aboard
          provisioned = food + chestFood >= crew.float * provisionFoodPerUnit and
            iron + chestIron >= crew.float * provisionIronPerUnit
          enoughCompany = crew >= minCrew or
            (hasExpeditionTransport and crew >= 3) or (launchNow and crew >= 2)
        if enoughCompany and readyEscort and ringOk and provisioned:
          return %*{"type": "launch_boat", "boat_id": boat{"id"},
                    "destination": "inward"}

  # 6. SEARCH FOR THE INNER-RING FIGHT: march the veteran company toward
  #    remembered rivals (or a deterministic patrol) until contact.
  if ring == 2 and hasExpeditionTransport and honors < honorsMin and
      ground >= 2 and militaryEnemies.len == 0:
    var remembered: seq[JsonNode]
    for opponent in obs{"opponents"}.getElems:
      let position = opponent{"last_seen_position"}
      if has(position) and position.kind == JArray and position.len >= 2:
        remembered.add position
    var searchTarget: JsonNode
    var searchTrigger: string
    if remembered.len > 0 and generals.len > 0:
      let
        generalX = num(generals[0]{"x"})
        generalY = num(generals[0]{"y"})
      var
        nearest = remembered[0]
        bestDistance = Inf
      for position in remembered:
        let
          dx = num(position[0]) - generalX
          dy = num(position[1]) - generalY
          distance = dx * dx + dy * dy
        if distance < bestDistance:
          nearest = position
          bestDistance = distance
      searchTarget = %*[num(nearest[0]), num(nearest[1])]
      searchTrigger = "ring-2 honor motive is pursuing the nearest last-seen rival"
    else:
      const patrol = [[0, 0], [12, 0], [0, -12], [-12, 0], [0, 12]]
      let leg = patrol[(obs{"tick"}.getInt div 16) mod patrol.len]
      searchTarget = %*[leg[0], leg[1]]
      searchTrigger = "ring-2 honor motive has no rival intel, so the company is sweeping for contact"
    var searchers = generalIds[0 .. min(0, generalIds.high)]
    searchers.add groundIds
    return unitOrdersAction(
      %*[{"unit_ids": searchers, "target": searchTarget}],
      "company_honor_search",
      "lead the veteran company on a fog-safe pursuit to find the battle that earns its apex ticket",
      searchTrigger)

  # 7. Hold the expedition base while its fleet is being built.
  if groundIds.len > 0:
    var target = %*[0, 0]
    if raceInward and not inCogosseum and generals.len > 0:
      target = pointOf(generals[0])
    return unitOrdersAction(
      %*[{"unit_ids": groundIds, "target": target}],
      "company_guard_rally",
      "keep the ground company assembled at its expedition rally point",
      "no higher-priority combat, economy, recovery, or travel action is ready")

  %*{"type": "wait"}

proc decide(obs: JsonNode): JsonNode =
  ## Pure observation → action. Never throws: a thrown action would forfeit
  ## the tick to the scripted fallback (an off-distribution decision).
  try:
    decideInner(obs)
  except CatchableError:
    %*{"type": "wait",
       "_reasoning": "planner failed safely; preserve the company"}

proc main() =
  let client = newCoworldClient("ilya_muromets")
  client.run proc(message: JsonNode) =
    case message{"type"}.getStr
    of "connected":
      echo "ilya_muromets: connected as slot ", message{"slot"}.getInt
    of "observation":
      client.send(decide(message{"data"}))
    of "soldier_obs":
      # General-only shape: never send soldier_actions, so the engine's
      # built-in micro drives every unit.
      discard
    of "final":
      echo "ilya_muromets: final, results received"
      quit(0)
    else:
      discard

main()
