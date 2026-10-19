## Danila Master — Factorio policy for Andre von Auto.
## Command player: the Nim rewrite of the strongest scripted example, the
## burner baseline (`python -m players.burner_player` in
## Metta-AI/cogame-factorio). Each step it sends one Python program for the
## seat's FLE namespace (cogame.factorio.v1, docs/protocol_player.md):
##
## Build order, each phase one program, gated on what the observation
## already shows standing so a failed step is simply retried:
##   1. iron patch:   up to 5 burner drills dropping into stone furnaces;
##   2. copper patch: up to 3 drill+furnace pairs;
##   3. coal + stone: drills dropping into wooden chests (coal for
##      refuelling, stone for score);
## then maintenance every step: extract plates, refuel anything low on
## coal (topping up from the coal chests), hand-craft iron gear wheels,
## and let the factory run (`sleep`). Sleep length is the leftover
## program-timeout budget at `game_speed` (not a fixed 30 s): production
## score integrates output over game time, and 30 s left most of the
## 45 s timeout / 3000 s wall-clock unused.
##
## Programs never rely on variables from earlier programs: every step
## re-queries the world with `get_entities` and wraps every action in
## try/except so a failing call is a printed game outcome, not an aborted
## step. (FLE quirk: names starting with `_` are not persisted between
## programs, so programs use plain `bp_` names.)
##
## No LLM, no secret-envs. Scores are absolute per seat (each seat gets
## its own Factorio server), so the baseline's score carries regardless
## of opponents.

import std/[json, os, sets, strutils, tables], coworld_client

const
  Drill = "burner-mining-drill"
  Furnace = "stone-furnace"
  Chest = "wooden-chest"
  MaxPlacementSteps = 8  ## give up building after this many attempts
  ## Real seconds reserved for extract/refuel/craft so `sleep` cannot
  ## eat the whole `program_timeout_seconds` (default 45).
  SleepReserveSeconds = 15.0
  DefaultGameSpeed = 10.0
  DefaultProgramTimeout = 45.0
  ## Burner drill 150 kW, furnace 90 kW, coal 4 MJ → ~0.0375 / 0.0225
  ## coal per game-second. A ~330 s sleep needs ~13 / 8 coal; load more
  ## so a machine that starts the sleep already low still finishes it.
  PlaceDrillCoal = 20
  PlaceFurnaceCoal = 15
  LowFuel = 20
  RefillCoal = 25
  ExtractQty = 100
  RestockQty = 100
  RestockWhenCoalBelow = 200
  MaxCraftGears = 200

## (resource, sink prototype, pairs wanted) in build order
const BuildPhases = [
  ("IronOre", "StoneFurnace", 5),
  ("CopperOre", "StoneFurnace", 3),
  ("Coal", "WoodenChest", 2),
  ("Stone", "WoodenChest", 1),
]

## Drill+sink pairs marching along the patch edge in 2-tile steps (both
## are 2x2), towards the patch centre so we stay on ore. Each pair is
## independent; failures are printed and skipped. Fuel goes in immediately
## so the pair works while we move on. `nearest` is measured from the
## character and can be fooled by items lying around a factory, so we walk
## back to the origin first.
const PlacePairsProgram = """
move_to(Position(x=0, y=0))
bp_ore = nearest(Resource.$resource)
bp_dx = 2
try:
    bp_patch = get_resource_patch(Resource.$resource, bp_ore)
    if bp_patch.bounding_box.center.x < bp_ore.x:
        bp_dx = -2
except Exception as bp_e:
    print("no patch info:", bp_e)
move_to(bp_ore)
bp_ok = 0
for bp_i in range($slots):
    if bp_ok >= $want:
        break
    try:
        bp_p = Position(x=bp_ore.x + bp_dx * bp_i, y=bp_ore.y)
        bp_d = place_entity(Prototype.BurnerMiningDrill, direction=Direction.DOWN, position=bp_p)
        bp_s = place_entity(Prototype.$sink, position=bp_d.drop_position)
        insert_item(Prototype.Coal, bp_d, quantity=$drillFuel)
$fuelSink
        bp_ok += 1
        print("placed", bp_d.name, "at", bp_d.position, "->", bp_s.name, "at", bp_s.position)
    except Exception as bp_e:
        print("placement", bp_i, "failed:", bp_e)
print("pairs placed:", bp_ok)
sleep($sleep)
"""
const FuelSinkLine = "        insert_item(Prototype.Coal, bp_s, quantity=$furnaceFuel)"

const MaintainProgram = """
bp_plates = 0
for bp_f in get_entities({Prototype.StoneFurnace}):
    for bp_proto in (Prototype.IronPlate, Prototype.CopperPlate):
        try:
            bp_plates += extract_item(bp_proto, bp_f.position, quantity=$extractQty)
        except Exception:
            pass
print("extracted plates:", bp_plates)
$restock
bp_refuelled = 0
for bp_e in get_entities({Prototype.BurnerMiningDrill, Prototype.StoneFurnace}):
    try:
        if bp_e.fuel.get(Prototype.Coal, 0) < $lowFuel:
            insert_item(Prototype.Coal, bp_e, quantity=$refill)
            bp_refuelled += 1
    except Exception as bp_x:
        print("refuel failed at", bp_e.position, ":", bp_x)
print("refuelled:", bp_refuelled)
$craft
sleep($sleep)
"""

const RestockCoalBlock = """
bp_coal = 0
for bp_c in get_entities({Prototype.WoodenChest}):
    try:
        bp_coal += extract_item(Prototype.Coal, bp_c.position, quantity=$restockQty)
    except Exception:
        pass
print("restocked coal:", bp_coal)
"""

const CraftGearsBlock = """
try:
    print("crafted gears:", craft_item(Prototype.IronGearWheel, quantity=$n))
except Exception as bp_e:
    print("craft failed:", bp_e)
"""

## Observation helpers (all tolerate missing fields)

proc jsonFloat(node: JsonNode, default: float): float =
  if node.isNil:
    return default
  case node.kind
  of JInt: node.getInt().float
  of JFloat: node.getFloat()
  of JString:
    try: parseFloat(node.getStr())
    except ValueError: default
  else: default

proc inventory(observation: JsonNode): Table[string, int] =
  let node = observation{"inventory"}
  if node.isNil or node.kind != JObject:
    return
  for key, value in node:
    if value.kind in {JInt, JFloat}:
      result[key] = value.getInt()

proc entityCount(observation: JsonNode, name: string): int =
  let node = observation{"entities"}
  if node.isNil or node.kind != JArray:
    return
  for entity in node:
    if entity{"name"}.getStr() == name:
      inc result

## Policy state (persists across reconnects)

var
  startingInventory: Table[string, int]
  placementSteps = 0
  givenUp: HashSet[string]
  lastAttemptResource = ""
  lastAttemptDrills = -1
  gameSpeed = DefaultGameSpeed
  programTimeout = DefaultProgramTimeout

proc maintainSleep(): int =
  ## Game-seconds of factory runtime that still fit in the program timeout.
  let budget = max(programTimeout - SleepReserveSeconds, 5.0)
  max(int(budget * gameSpeed + 0.5), 1)

proc placementSleep(): int =
  max(maintainSleep() div 2, 1)

proc onWelcome(message: JsonNode) =
  ## welcome.episode.starting_inventory states what we begin with; never
  ## hardcode counts. Kept as the fallback when an observation carries no
  ## inventory. Sleep length is derived from episode game_speed and
  ## program_timeout_seconds so we fill the timeout with factory ticks.
  let node = message{"episode"}{"starting_inventory"}
  if not node.isNil and node.kind == JObject:
    startingInventory.clear()
    for key, value in node:
      if value.kind in {JInt, JFloat}:
        startingInventory[key] = value.getInt()
  let episode = message{"episode"}
  if not episode.isNil and episode.kind == JObject:
    gameSpeed = jsonFloat(episode{"game_speed"}, gameSpeed)
    programTimeout = jsonFloat(episode{"program_timeout_seconds"}, programTimeout)
  programTimeout = jsonFloat(message{"program_timeout_seconds"}, programTimeout)

proc nextPhase(observation: JsonNode): (bool, string, string, int) =
  ## The first phase whose drills are not all standing yet, or none.
  let drillsStanding = observation.entityCount(Drill)
  var stock = observation.inventory()
  if stock.len == 0:
    stock = startingInventory
  if stock.len == 0:
    # Neither observation nor welcome told us: assume plenty and let the
    # in-program try/except report the failures.
    stock = {Drill: 50, Furnace: 10, Chest: 10}.toTable()
  let
    drillsLeft = stock.getOrDefault(Drill)
    furnacesLeft = stock.getOrDefault(Furnace)
    chestsLeft = stock.getOrDefault(Chest)

  # A phase we tried last step that added no drills is abandoned so a
  # patch we cannot build on does not eat the whole episode.
  if lastAttemptResource.len > 0:
    if drillsStanding <= lastAttemptDrills:
      givenUp.incl(lastAttemptResource)
    lastAttemptResource = ""

  var cumulative = 0
  for (resource, sink, want) in BuildPhases:
    if resource in givenUp:
      continue
    cumulative += want
    if drillsStanding < cumulative:
      if drillsLeft <= 0:
        return (false, "", "", 0)
      if sink == "StoneFurnace" and furnacesLeft <= 0:
        continue
      if sink == "WoodenChest" and chestsLeft <= 0:
        continue
      lastAttemptResource = resource
      lastAttemptDrills = drillsStanding
      return (true, resource, sink, cumulative - drillsStanding)
  (false, "", "", 0)

proc program(observation: JsonNode): string =
  ## The Python program for this step: build the next phase while there
  ## is one, then maintain the running factory.
  if placementSteps < MaxPlacementSteps:
    let (building, resource, sink, want) = nextPhase(observation)
    if building:
      inc placementSteps
      let fuelSink =
        if sink == "StoneFurnace":
          FuelSinkLine % ["furnaceFuel", $PlaceFurnaceCoal]
        else:
          ""
      return PlacePairsProgram % [
        "resource", resource, "sink", sink,
        "want", $want, "slots", $(want + 4),
        "drillFuel", $PlaceDrillCoal, "fuelSink", fuelSink,
        "sleep", $placementSleep()]

  let
    stock = observation.inventory()
    coal = stock.getOrDefault("coal")
    plates = stock.getOrDefault("iron-plate")
    restock =
      if coal < RestockWhenCoalBelow:
        RestockCoalBlock % ["restockQty", $RestockQty]
      else:
        ""
    craft =
      if plates >= 20:
        CraftGearsBlock % ["n", $min(plates div 2, MaxCraftGears)]
      else:
        ""
  MaintainProgram % [
    "extractQty", $ExtractQty, "restock", restock,
    "lowFuel", $LowFuel, "refill", $RefillCoal,
    "craft", craft, "sleep", $maintainSleep()]

proc main() =
  ## The server allows reconnects (it re-sends welcome plus the current
  ## step's observation), so a dropped socket is retried on a bounded
  ## budget instead of striking the seat out.
  var
    finished = false
    attempts = 0
  while not finished and attempts < 5:
    var client: CoworldClient
    try:
      client = newCoworldClient("danila")
    except CatchableError:
      echo "danila: connect failed (", getCurrentExceptionMsg(), ")"
      inc attempts
      sleep(2000)
      continue
    client.run proc(message: JsonNode) =
      case message{"type"}.getStr()
      of "welcome":
        onWelcome(message)
        echo "danila: seated slot ", message{"slot"}.getInt(),
          " task ", message{"task"}{"key"}.getStr(),
          " max_steps ", message{"max_steps"}.getInt()
      of "observation":
        let
          step = message{"step"}.getInt()
          observation = message{"observation"}
        echo "danila: step ", step, " score ",
          observation{"score"}.getFloat()
        client.send(%*{"type": "program", "step": step,
                       "code": program(observation)})
      of "done":
        echo "danila: done, result ", message{"result"}
        finished = true
        quit(0)
      else:
        discard
    if not finished:
      echo "danila: socket closed, reconnecting"
      inc attempts
      sleep(2000)

main()
