## BASIC VM player for the hosted Pudge Wars league. Runs a polyworld
## .bas script (the same interpreter the local engine uses, basic.nim)
## against the coworld websocket observation instead of the in-process
## World: every observation becomes the script's host data and object /
## hook / rune lists, and the script's action calls become the action
## JSON the league expects.
##
## Hosted protocol (0.3.8): observation {type, tick, self, visible
## {pudges, hooks, runes, props}, river_west, river_east, ally_ping,
## rune_next {soon, kind, x, y}, ...};
## reply {walk_to, hook_to, blink_to, attack_target, rot_toggle,
## place_wall, place_mine, halt, ping}. Shop calls have no hosted
## action and return 0.

import std/[json, math], basic
when not defined(basvmTest):
  import coworld_client

const
  Source = staticRead("policy.bas")
  DataNames = [
    "selfId", "selfTeam", "selfX", "selfY", "selfHp", "selfMaxHp",
    "selfKills", "selfPoints", "selfLayer", "selfHooked", "selfShield",
    "selfBuff", "selfRot", "hookReady", "blinkReady", "worldTick",
    "riverWest", "riverEast", "homeX", "homeY", "allyPingX", "allyPingY",
    "allyPingAge", "allyPingBy", "selfGold", "selfInShop",
    "runeSoon", "runeNextKind", "runeNextX", "runeNextY"]

type
  Obj = object
    id, kind, team, layer, x, y, hp: int32
    alive, hooked, shielded, rot: bool
  Hook = object
    team, x, y, victim, owner: int32
    flying: bool
  Rune = object
    x, y, kind: int32
  Snapshot = object
    objects: seq[Obj]
    hooks: seq[Hook]
    runes: seq[Rune]
    hookReady, blinkReady, rotOn, inShop: bool
    points, gold: int32
    upgrades, itemRanks: seq[int32]
    action: JsonNode

var snap: Snapshot

proc num(node: JsonNode, default = 0.0): float =
  if node == nil: default
  elif node.kind == JInt: float(node.getInt)
  elif node.kind == JFloat: node.getFloat
  else: default

proc flag(node: JsonNode): bool =
  if node == nil: false
  elif node.kind == JBool: node.getBool
  elif node.kind == JInt: node.getInt != 0
  else: false

proc tile(v: float): int32 = int32(clamp(floor(v), 0.0, 127.0))

iterator elems(node: JsonNode): JsonNode =
  ## Nil-safe walk over a JSON array.
  if node != nil and node.kind == JArray:
    for item in node.items:
      yield item

proc bodyId(node: JsonNode): int32 =
  ## Sim ids are 1-based per butcher; the hosted body carries a slot.
  if node{"id"} != nil: int32(node{"id"}.getInt)
  else: int32(node{"slot"}.getInt + 1)

proc bodyLayer(node: JsonNode, riverWest, riverEast: float): int32 =
  if node{"layer"} != nil: return int32(node{"layer"}.getInt)
  if flag(node{"in_river"}): return 2
  if num(node{"x"}) < riverWest: 0 else: 1

proc arg(a: openArray[int32], i: int): int =
  if i < a.len: int(a[i]) else: 0

proc objAt(i: int): Obj =
  if i >= 0 and i < snap.objects.len: snap.objects[i] else: Obj()

proc hookAt(i: int): Hook =
  if i >= 0 and i < snap.hooks.len: snap.hooks[i] else: Hook()

proc runeAt(i: int): Rune =
  if i >= 0 and i < snap.runes.len: snap.runes[i] else: Rune()

proc buildHost(): Host =
  result = initHost()
  for name in DataNames:
    discard result.addData(name)
  discard result.addFunction("objectCount", 0, proc(a: openArray[int32]): int32 = int32(snap.objects.len), 2)
  discard result.addFunction("objectId", 1, proc(a: openArray[int32]): int32 = objAt(arg(a, 0)).id, 4)
  discard result.addFunction("objectKind", 1, proc(a: openArray[int32]): int32 = objAt(arg(a, 0)).kind, 4)
  discard result.addFunction("objectTeam", 1, proc(a: openArray[int32]): int32 = objAt(arg(a, 0)).team, 4)
  discard result.addFunction("objectX", 1, proc(a: openArray[int32]): int32 = objAt(arg(a, 0)).x, 4)
  discard result.addFunction("objectY", 1, proc(a: openArray[int32]): int32 = objAt(arg(a, 0)).y, 4)
  discard result.addFunction("objectHp", 1, proc(a: openArray[int32]): int32 = objAt(arg(a, 0)).hp, 4)
  discard result.addFunction("objectAlive", 1, proc(a: openArray[int32]): int32 = int32(objAt(arg(a, 0)).alive), 4)
  discard result.addFunction("objectLayer", 1, proc(a: openArray[int32]): int32 = objAt(arg(a, 0)).layer, 4)
  discard result.addFunction("objectHooked", 1, proc(a: openArray[int32]): int32 = int32(objAt(arg(a, 0)).hooked), 4)
  discard result.addFunction("objectShielded", 1, proc(a: openArray[int32]): int32 = int32(objAt(arg(a, 0)).shielded), 4)
  discard result.addFunction("objectRot", 1, proc(a: openArray[int32]): int32 = int32(objAt(arg(a, 0)).rot), 4)
  discard result.addFunction("hookCount", 0, proc(a: openArray[int32]): int32 = int32(snap.hooks.len), 2)
  discard result.addFunction("hookTeam", 1, proc(a: openArray[int32]): int32 = hookAt(arg(a, 0)).team, 4)
  discard result.addFunction("hookX", 1, proc(a: openArray[int32]): int32 = hookAt(arg(a, 0)).x, 4)
  discard result.addFunction("hookY", 1, proc(a: openArray[int32]): int32 = hookAt(arg(a, 0)).y, 4)
  discard result.addFunction("hookFlying", 1, proc(a: openArray[int32]): int32 = int32(hookAt(arg(a, 0)).flying), 4)
  discard result.addFunction("hookVictim", 1, proc(a: openArray[int32]): int32 = hookAt(arg(a, 0)).victim, 4)
  discard result.addFunction("hookOwner", 1, proc(a: openArray[int32]): int32 = hookAt(arg(a, 0)).owner, 4)
  discard result.addFunction("runeCount", 0, proc(a: openArray[int32]): int32 = int32(snap.runes.len), 2)
  discard result.addFunction("runeX", 1, proc(a: openArray[int32]): int32 = runeAt(arg(a, 0)).x, 4)
  discard result.addFunction("runeY", 1, proc(a: openArray[int32]): int32 = runeAt(arg(a, 0)).y, 4)
  discard result.addFunction("runeKind", 1, proc(a: openArray[int32]): int32 = runeAt(arg(a, 0)).kind, 4)
  discard result.addFunction("walkTo", 2, proc(a: openArray[int32]): int32 =
    snap.action["walk_to"] = %*[arg(a, 0), arg(a, 1)]
    if snap.action.hasKey("halt"): snap.action.delete("halt")
    1, 400)
  discard result.addFunction("hookTo", 2, proc(a: openArray[int32]): int32 =
    if not snap.hookReady: return 0
    snap.hookReady = false
    snap.action["hook_to"] = %*[arg(a, 0), arg(a, 1)]
    1, 400)
  discard result.addFunction("attackTarget", 1, proc(a: openArray[int32]): int32 =
    snap.action["attack_target"] = %arg(a, 0)
    1, 20)
  discard result.addFunction("buyUpgrade", 1, proc(a: openArray[int32]): int32 =
    ## hosted shop (host 0a0140f): one buy per tick per kind is enough for
    ## the scripts' spend loops; the echo next tick says if it took.
    if snap.points <= 0: return 0
    snap.action["buy_upgrade"] = %arg(a, 0)
    dec snap.points
    1, 20)
  discard result.addFunction("buyPower", 1, proc(a: openArray[int32]): int32 =
    if not snap.inShop or snap.gold <= 0: return 0
    snap.action["buy_power"] = %arg(a, 0)
    snap.gold = 0
    1, 20)
  discard result.addFunction("itemRank", 1, proc(a: openArray[int32]): int32 =
    let k = arg(a, 0)
    if k >= 0 and k < snap.itemRanks.len: snap.itemRanks[k] else: 0, 4)
  discard result.addFunction("upgradeLevel", 1, proc(a: openArray[int32]): int32 =
    let k = arg(a, 0)
    if k >= 0 and k < snap.upgrades.len: snap.upgrades[k] else: 0, 4)
  discard result.addFunction("halt", 0, proc(a: openArray[int32]): int32 =
    snap.action["halt"] = %true
    if snap.action.hasKey("walk_to"): snap.action.delete("walk_to")
    1, 20)
  discard result.addFunction("ping", 2, proc(a: openArray[int32]): int32 =
    snap.action["ping"] = %*[arg(a, 0), arg(a, 1)]
    1, 20)
  discard result.addFunction("blinkTo", 2, proc(a: openArray[int32]): int32 =
    if not snap.blinkReady: return 0
    snap.blinkReady = false
    snap.action["blink_to"] = %*[arg(a, 0), arg(a, 1)]
    1, 400)
  discard result.addFunction("rotToggle", 0, proc(a: openArray[int32]): int32 =
    ## v2: hosted rot is off. The script keys the toggle on selfRot; if the
    ## observation does not report our rot state the toggle flickers and
    ## burns us (v1: ~5 self-inflicted deaths per seat-game).
    ## host 0a0140f accepts "rot": bool (a set, not a toggle), which
    ## cannot flicker; the script means "flip", so send the opposite of
    ## the reported state.
    snap.action["rot"] = %(not snap.rotOn)
    1, 20)
  discard result.addFunction("placeWall", 2, proc(a: openArray[int32]): int32 =
    snap.action["place_wall"] = %*[arg(a, 0), arg(a, 1)]
    1, 20)
  discard result.addFunction("placeMine", 2, proc(a: openArray[int32]): int32 =
    snap.action["place_mine"] = %*[arg(a, 0), arg(a, 1)]
    1, 20)

proc vmLimits(): Limits =
  result = defaultLimits()
  result.maxSourceBytes = 64 * 1024
  result.maxCodeInstructions = 20_000
  result.maxArrays = 32
  result.maxArrayElements = 4096
  result.maxGlobals = 256
  result.maxHostData = 32
  result.maxHostFunctions = 40
  result.maxRoutines = 64
  result.maxParameters = 16
  result.maxRegisters = 256
  result.maxSyntaxDepth = 32
  result.maxCallDepth = 16
  result.maxMemoryBytes = 2 * 1024 * 1024
  result.maxInstructions = 20_000
  result.maxWorkUnits = 50_000
  result.maxPrintBytes = 1024
  result.maxPrintEvents = 128

type Player = ref object
  runtime: Runtime
  ids: seq[int32]
  failed: bool
  ticks: int

proc newPlayer(): Player =
  let limits = vmLimits()
  var host = buildHost()
  let program = compile(Source, host, limits)
  result = Player(runtime: initRuntime(program, host, limits))
  for name in DataNames:
    let id = program.hostDataIndex(name)
    doAssert id >= 0, "missing host data " & name
    result.ids.add id

proc decide(player: Player, obs: JsonNode): JsonNode =
  ## Loads one observation into the VM and runs the script once.
  let me = obs{"self"}
  if me == nil or player.failed:
    return %*{}
  let
    riverWestWater = num(obs{"river_west"}, 53.0)
    riverEastWater = num(obs{"river_east"}, 75.0)
    myTeam = int32(me{"team"}.getInt)
    myId = bodyId(me)
  snap = Snapshot(action: newJObject())
  snap.hookReady = flag(me{"hook_ready"})
  snap.blinkReady = flag(me{"blink_ready"})
  snap.rotOn = flag(me{"rot"})
  snap.inShop = flag(me{"in_shop"})
  snap.points = int32(num(me{"points"}))
  snap.gold = int32(num(me{"gold"}))
  for node in elems(me{"upgrades"}): snap.upgrades.add int32(node.getInt)
  for node in elems(if me{"item_ranks"} != nil: me{"item_ranks"} else: me{"items"}): snap.itemRanks.add int32(node.getInt)
  let visible = obs{"visible"}
  var sawSelf = false
  if visible != nil:
    for node in elems(visible{"pudges"}):
      var o = Obj(
        id: bodyId(node), kind: 1, team: int32(node{"team"}.getInt),
        layer: bodyLayer(node, riverWestWater, riverEastWater),
        x: tile(num(node{"x"})), y: tile(num(node{"y"})),
        hp: int32(num(node{"hp"})),
        alive: (if node{"alive"} == nil: true else: flag(node{"alive"})),
        hooked: flag(node{"hooked"}), shielded: flag(node{"shield"}),
        rot: flag(node{"rot"}))
      if o.id == myId: sawSelf = true
      snap.objects.add o
    for node in elems(visible{"props"}):
      snap.objects.add Obj(
        id: int32(node{"id"}.getInt), kind: int32(node{"kind"}.getInt(2)),
        team: int32(node{"team"}.getInt),
        layer: bodyLayer(node, riverWestWater, riverEastWater),
        x: tile(num(node{"x"})), y: tile(num(node{"y"})),
        hp: int32(num(node{"hp"})), alive: true)
    for node in elems(visible{"hooks"}):
      let victim = node{"victim"}.getInt(-1)
      var flying = victim <= 0
      if node{"flying"} != nil: flying = flag(node{"flying"})
      elif node{"phase"} != nil: flying = node{"phase"}.getStr == "flying"
      snap.hooks.add Hook(
        team: int32(node{"team"}.getInt), x: tile(num(node{"x"})),
        y: tile(num(node{"y"})), victim: int32(max(victim, 0)),
        owner: int32(node{"owner"}.getInt), flying: flying)
    for node in elems(visible{"runes"}):
      snap.runes.add Rune(
        x: tile(num(node{"x"})), y: tile(num(node{"y"})),
        kind: int32(node{"kind"}.getInt))
  if not sawSelf:
    snap.objects.insert(Obj(
      id: myId, kind: 1, team: myTeam,
      layer: bodyLayer(me, riverWestWater, riverEastWater),
      x: tile(num(me{"x"})), y: tile(num(me{"y"})), hp: int32(num(me{"hp"})),
      alive: true, hooked: flag(me{"hooked"}), shielded: flag(me{"shield"}),
      rot: flag(me{"rot"})), 0)
  # spawn pads by team and lane rank when the observation has no home
  var homeX = int32(num(me{"home_x"}, -1))
  var homeY = int32(num(me{"home_y"}, -1))
  if homeX < 0:
    var rank = 0
    for o in snap.objects:
      if o.kind == 1 and o.team == myTeam and o.alive and o.id < myId: inc rank
    if myTeam == 0:
      homeX = (if rank == 0: 25 else: 35)
    else:
      homeX = (if rank == 0: 103 else: 94)
    homeY = (if rank == 0: 30 else: 105)
  let inRiver = flag(me{"in_river"}) or me{"layer"}.getInt(-1) == 2
  var rt = player.runtime
  rt.restart()
  let ping = obs{"ally_ping"}
  template put(i: int, v: int32) = rt.setData(player.ids[i], v)
  put(0, myId)
  put(1, myTeam)
  put(2, tile(num(me{"x"})))
  put(3, tile(num(me{"y"})))
  put(4, int32(max(num(me{"hp"}), 0.0)))
  put(5, int32(num(me{"max_hp"}, 840.0)))
  put(6, int32(num(me{"kills"})))
  put(7, int32(num(me{"points"})))
  put(8, (if inRiver: 2'i32 else: int32(me{"layer"}.getInt(int(myTeam)))))
  put(9, int32(flag(me{"hooked"})))
  put(10, (if me{"shield"} != nil and me{"shield"}.kind == JInt: int32(me{"shield"}.getInt) else: int32(flag(me{"shield"}))))
  put(11, int32(num(me{"buff"})))
  put(12, int32(flag(me{"rot"})))
  put(13, int32(snap.hookReady))
  put(14, int32(snap.blinkReady))
  put(15, int32(num(obs{"tick"})))
  put(16, int32(riverWestWater) - 1)
  put(17, int32(riverEastWater) + 1)
  put(18, homeX)
  put(19, homeY)
  if ping != nil and ping.kind == JObject:
    put(20, tile(num(ping{"x"})))
    put(21, tile(num(ping{"y"})))
    put(22, int32(max(num(obs{"tick"}) - num(ping{"tick"}), 0.0)))
    put(23, int32(ping{"by"}.getInt(ping{"slot"}.getInt(0))))
  else:
    put(20, 0); put(21, 0); put(22, 0); put(23, 0)
  put(24, int32(num(me{"gold"})))
  put(25, int32(flag(me{"in_shop"})))
  # 0.3.8: the public rune clock (rune_next {soon, kind, x, y})
  let rn = obs{"rune_next"}
  if rn != nil and rn.kind == JObject and num(rn{"soon"}) > 0:
    put(26, int32(num(rn{"soon"})))
    put(27, int32(rn{"kind"}.getInt(-1)))
    put(28, int32(num(rn{"x"}, -1)))
    put(29, int32(num(rn{"y"}, -1)))
  else:
    put(26, 0); put(27, -1); put(28, -1); put(29, -1)
  try:
    discard rt.run()
  except BasicError as e:
    stderr.writeLine "basvm: script error: " & e.msg
    player.failed = true
    return %*{"halt": true}
  player.runtime = rt
  inc player.ticks
  snap.action

when defined(basvmTest):
  let player = newPlayer()
  let obs = %*{"type": "observation", "tick": 40, "river_west": 53, "river_east": 75,
    "self": {"slot": 0, "team": 0, "x": 25.3, "y": 30.8, "hp": 840, "max_hp": 840,
      "hook_ready": true, "blink_ready": true, "alive": true, "hooked": false, "in_river": false},
    "visible": {"pudges": [
      {"slot": 0, "team": 0, "x": 25.3, "y": 30.8, "hp": 840, "alive": true},
      {"slot": 1, "team": 0, "x": 35.0, "y": 105.0, "hp": 840, "alive": true},
      {"slot": 3, "team": 1, "x": 90.0, "y": 60.0, "hp": 840, "alive": true}],
      "hooks": [], "runes": []}}
  for t in 0 ..< 3:
    obs["tick"] = %(40 + t)
    echo $player.decide(obs)
  let obs2 = %*{"type": "observation", "tick": 800, "river_west": 53, "river_east": 75,
    "self": {"slot": 3, "team": 1, "x": 92.0, "y": 64.0, "hp": 640, "max_hp": 840,
      "hook_ready": true, "blink_ready": false, "alive": true, "hooked": false, "in_river": false},
    "visible": {"pudges": [
      {"slot": 3, "team": 1, "x": 92.0, "y": 64.0, "hp": 640, "alive": true},
      {"slot": 4, "team": 1, "x": 94.0, "y": 105.0, "hp": 840, "alive": true},
      {"slot": 0, "team": 0, "x": 84.0, "y": 62.0, "hp": 400, "alive": true, "hooked": false}],
      "hooks": [{"owner": 1, "team": 0, "victim": -1, "x": 70.0, "y": 64.0}], "runes": [{"x": 64, "y": 20, "kind": 0}]}}
  echo $player.decide(obs2)
else:
  proc main() =
    let
      client = newCoworldClient("myasnik-bas")
      player = newPlayer()
    client.run proc(message: JsonNode) =
      case message{"type"}.getStr()
      of "observation":
        client.send(player.decide(message))
      of "final":
        echo "basvm: final, score ", message{"score"}
        quit(0)
      else:
        if flag(message{"done"}):
          echo "basvm: done"
          quit(0)
        if message{"type"}.getStr() == "" and message{"self"} != nil:
          client.send(player.decide(message))
  main()
