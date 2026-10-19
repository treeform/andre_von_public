## Svyatogor — Terran macro-war policy for the Bw league.
## Ported from ~/p/coworld-bw players/sleepyterran (marine-rush branch,
## the strongest local bot: 12/12 kill-or-win at 43200 ticks). Parses
## the sprite protocol to see the world, mines minerals, builds Depots
## and Barracks, breaks the neutral Psi Disrupter gate with SCV helpers
## and camera-click targeting, then sends Marine waves at enemy bases.
## Connects to COWORLD_PLAYER_WS_URL like all coworld player bots.

import
  std/[nativesockets, net, os, strutils, tables],
  bitworld/spriteprotocol, whisky,
  bwprotocol, profiles

const
  DefaultUrl = "ws://127.0.0.1:8080/player"
  ViewWidth = 640
  ViewHeight = 400
  ## Take one macro action per this many server ticks.
  ActInterval = 6
  ## Economy-only build: no army at all. At the league's 14400 ticks a
  ## victory is unreachable (the neutral walls cost more time than the
  ## episode has), so every mineral spent on Marines is score thrown
  ## away. Long episodes want the opposite; both live in this file.
  EconomyOnly {.booldefine.} = false
  MaxWorkers {.intdefine.} = 14
  ## Send an attack wave this often once enough Marines are visible.
  ## Frequent waves keep constant pressure on one dying base.
  AttackInterval = 180
  ## Marines required on screen before a wave leaves home. League
  ## opponents defend with SCVs only, so eight is already lethal.
  WaveSize = 4
  ## Barracks to build. Three keep Marines flowing fast enough to
  ## finish three enemy bases inside the ten-minute limit.
  MaxBarracks = 3
  ## Every Nth action is reserved for mining, so construction and
  ## training can never starve the mineral line — the economy is
  ## what the episode score actually measures.
  MiningShare = 2
  ## Longest the economy may be frozen while banking for the opening
  ## depot. Roughly two worker-build times.
  SaveUpTicks = 900
  ## Workers sent to help break our own gate. The Psi Disrupter has no
  ## weapon (units.dat ground_weapon = 130 = None), so SCVs chip at it
  ## in complete safety. Breakout time decides victories: winning games
  ## broke out at t=10194, single-kill games at t=14154.
  GateHelpers = 9
  ## A worker this far from both the CC and the mineral patches is a
  ## dispatched gate helper (they walk inward, opposite the line). The
  ## mining loop must not re-order them: a gather cancels the walk, and
  ## gateHelpersSent counts sends not arrivals, so a stolen helper is
  ## never replaced. Not the idle-mining skip (that one skipped workers
  ## AT a patch and was null).
  HelperHomeCc = 176
  HelperHomeMineral = 112
  ## Tick the expansion worker walks out. Early enough that the second
  ## Command Center pays for itself inside the episode.
  ## Place the expansion Command Center on a server-vetted spot when
  ## one is offered, instead of guessing. The guess built it in 2 games
  ## of 9 and the dense sweep in 0 of 12; vetted spots are what made
  ## the same problem tractable for the Zerg bot's expansion Hatchery.
  ## Requires a game version that vets Command Center spots.
  ExpansionVetting {.booldefine.} = false
  ## Place the expansion Command Center by sweeping a dense grid around
  ## the corner minerals, instead of one guess off the mineral line.
  ## The ordinary sweep already exists but is useless here: it rejects
  ## any spot within 72px of a mineral, and an expansion IS a mineral
  ## cluster, so it found nothing (0 of 12 games built one). A Command
  ## Center must sit CLOSE to the patch to mine it, so the expansion
  ## needs its own, much tighter clearance.
  ExpansionSweep {.booldefine.} = false
  ## Keep the footprint off the patches without pushing the hall away
  ## from them. A Command Center is 128x96 and a patch sprite ~32, so
  ## this clears both halves with a little slack.
  ExpansionMineralClearance = 88
  ## Beyond this from the mineral centroid a hall is too far to be
  ## worth building — the walk would eat the gain.
  ExpansionMaxRange = 208
  ## Gather vespene. The episode score is
  ## `unit_score + building_score + current_minerals + current_gas`
  ## (openbw_sim.cpp), so gas is worth exactly as much as minerals and
  ## this bot has never gathered a single unit of it. The mineral line
  ## is already saturated at 20 workers (measured, t=0.14), which means
  ## a worker moved to a fresh geyser gives up almost nothing and
  ## returns full rate. Nothing in an economy build ever spends gas, so
  ## every unit gathered banks straight into the score.
  Gas {.booldefine.} = false
  ## Workers assigned to the Refinery. Three saturates one geyser in
  ## Brood War; a fourth would idle.
  GasWorkers = 3
  ## How often gas workers are re-sent to the Refinery. Rare on
  ## purpose: a gather order restarts the cycle, so this only needs to
  ## catch workers that finished or drifted, not run continuously.
  GasOrderInterval = 240
  ## Workers within this distance of a Refinery are treated as the gas
  ## crew and skipped by the mineral loop. A Refinery is 64px wide and
  ## workers queue just outside it.
  GasHoldRadius = 72
  ## How often the dispatched-crew count is forgotten so losses are
  ## replaced. A gas round trip is roughly 150 ticks, so this is many
  ## trips — long enough never to disturb a working crew.
  GasCrewForgetTicks = 3000
  ## Stop trying to build the Refinery after this many attempts. An
  ## unbounded retry pulls a worker off minerals every 60 ticks for the
  ## whole episode when the geyser is unreachable or placement keeps
  ## failing — and one such game is exactly what the score shows: the
  ## gas build had a single episode at 2418 where the worst game of the
  ## baseline was 5110, and that one game is the whole -62 deficit.
  ## Gas is worth ~150; an open-ended retry can cost 3000.
  RefineryGiveUp = 8
  ExpandTick = 1500
  ## How often the camera goes to the expansion to build or manage it.
  ExpansionVisitInterval = 240
  BuildRetryTicks = 60
  ## Re-send a worker to an in-progress construction this often, so a
  ## building whose SCV was pulled away always gets finished.
  ResumeInterval = 240
  ## Workers this close to an active construction site are left alone
  ## by the mining loop; the builder must not be reassigned mid-build.
  SiteRadius = 80
  ## A construction site with no building yet is a failed placement;
  ## drop it quickly so it stops stealing workers.
  PhantomLifetime = 300
  ## A site with a confirmed building stays protected this long.
  SiteLifetime = 1500
  MaxDepots = 8
  ## Ticks of sustained attack budgeted per enemy base before moving
  ## on. A Command Center plus a dozen SCVs is about 2200 HP, which a
  ## wave of eight Marines removes in well under a minute.
  BaseAssaultTicks = 9000
  ## Tick the army first goes out. Earlier is better: killing three
  ## bases needs most of the second half of the episode.
  ## Tick the army first goes out. An intdefine so it can be pushed past
  ## the episode length, which turns the army build into a TURTLE: it
  ## trains Marines and never risks them.
  ##
  ## Why that might win. The engine does
  ## `unit_score += build_score` when a unit is built and
  ## `unit_score -= build_score` when it dies (bwgame.h:16760, :2350).
  ## So an army is banked score while it lives and refunded to nothing
  ## when it dies — which is exactly why the attacking army build ties
  ## the economy build on the mean (+40, t=0.17) while ranging 1270 to
  ## 9706: the good games are the ones where the army survived. If a
  ## Marine's build_score exceeds its 50 minerals, minerals spent on
  ## Marines that never die are worth MORE than minerals in the bank,
  ## and the whole economy-vs-army framing has been asking the wrong
  ## question all along.
  FirstAttackTick {.intdefine.} = 2400
  ## How often each Barracks has its rally point re-pointed at the
  ## current objective. Cheap, and it does the job that wave-gathering
  ## was doing badly: most of the army used to idle at home.
  RallyInterval = 300
  ## How often the camera leaves home to drive the fight at the front.
  ## Frequent enough to keep Marines shooting the gate, rare enough
  ## that the base keeps building and mining.
  FrontVisitInterval = 120
  ## Terran footprints in pixels, used to grid new buildings next to
  ## a confirmed one, where the ground is known to be buildable.
  DepotWidth = 96
  DepotHeight = 64
  BarracksWidth = 128
  BarracksHeight = 96
  ## A Command Center is 4x3 tiles.
  CommandCenterWidth = 128
  CommandCenterHeight = 96
  ## The minimap fills the viewport's bottom-left corner. A left
  ## click there with no pending order PANS THE CAMERA — after which
  ## the bot never sees its base again. Ordinary clicks must stay out.
  MinimapLeft = 4
  MinimapTop = 332
  MinimapRight = 68
  MinimapBottom = 396
  ForbiddenX = MinimapRight + 12
  ForbiddenY = MinimapTop - 12
  ProfileBotSlot {.intdefine.} = -1

type
  HomeBase = enum
    UnknownBase, NorthBase, EastBase, SouthBase, WestBase

const
  ## The minimap draws one pixel per map tile starting at its top-left
  ## corner, so tile (tx, ty) is at (MinimapLeft + tx, MinimapTop + ty).
  ## Weave is 64x64 tiles with the four starts on the cardinal edges.
  BaseSpots: array[NorthBase .. WestBase, tuple[x, y: int]] = [
    (x: MinimapLeft + 32, y: MinimapTop + 6),
    (x: MinimapLeft + 55, y: MinimapTop + 32),
    (x: MinimapLeft + 32, y: MinimapTop + 56),
    (x: MinimapLeft + 7, y: MinimapTop + 31)
  ]
  ## Each base reaches the rest of the map through one gate, and every
  ## gate is walled shut by a pair of neutral Psi Disrupters. Until
  ## those are destroyed an army simply cannot leave home.
  ## Each base can reach exactly one corner expansion WITHOUT passing a
  ## gate — verified by flood-filling walkable terrain with the neutral
  ## buildings blocked (experiments/check_reach.nim). The main mineral
  ## line saturates around 20 workers, so a second line is the only way
  ## past the score ceiling, and it costs no fighting at all.
  ExpansionSpots: array[NorthBase .. WestBase, tuple[x, y: int]] = [
    (x: MinimapLeft + 1, y: MinimapTop + 4),
    (x: MinimapLeft + 61, y: MinimapTop + 4),
    (x: MinimapLeft + 61, y: MinimapTop + 59),
    (x: MinimapLeft + 1, y: MinimapTop + 59)
  ]
  GateSpots: array[NorthBase .. WestBase, tuple[x, y: int]] = [
    (x: MinimapLeft + 30, y: MinimapTop + 21),
    (x: MinimapLeft + 40, y: MinimapTop + 31),
    (x: MinimapLeft + 30, y: MinimapTop + 40),
    (x: MinimapLeft + 21, y: MinimapTop + 31)
  ]

type
  SpriteDef = object
    width, height: int
    label: string

  Seen = object
    x, y: int
    spriteId: int
    label: string

  UnitCenters = object
    ccs: seq[tuple[x, y: int]]
    scvs: seq[tuple[x, y: int]]
    depots: seq[tuple[x, y: int]]
    barracks: seq[tuple[x, y: int]]
    marines: seq[tuple[x, y: int]]
    minerals: seq[tuple[x, y: int]]
    ## Vespene geysers, and the Refineries built on top of them. Gas
    ## counts toward the episode score exactly like minerals, and this
    ## bot has never gathered any.
    geysers: seq[tuple[x, y: int]]
    refineries: seq[tuple[x, y: int]]
    depotSpots: seq[tuple[x, y: int]]
    raxSpots: seq[tuple[x, y: int]]
    ## Server-vetted Command Center spots, offered while the player
    ## owns fewer than the expansion vet limit. This is what makes
    ## planting the second base reliable instead of a guess.
    ccSpots: seq[tuple[x, y: int]]
    ## Neutral gate buildings currently on screen.
    disrupters: seq[tuple[x, y: int]]
    ## True when a Marine selection ring is visible — proof that the
    ## previous double-click actually grabbed Marines.
    marineSelected: bool

proc needsGate(home, victim: HomeBase): bool =
  ## North and South are connected by walkable ground that bypasses
  ## every neutral wall (verified in experiments/check_reach.nim), so
  ## that pairing needs no gate broken at all. East and West are
  ## sealed and must break out. Attacking a gate-free victim first is
  ## a free early kill, and breakout time is what decides these games.
  not ((home == NorthBase and victim == SouthBase) or
       (home == SouthBase and victim == NorthBase))

proc inForbiddenZone(x, y: int): bool =
  ## True for viewport points over or near the minimap. Clicking
  ## there by accident pans the camera or misroutes orders.
  x < ForbiddenX and y > ForbiddenY

var
  sprites: Table[int, SpriteDef]
  objects: Table[int, Seen]

proc movePacket(x, y: int): seq[uint8] =
  ## Builds a mouse move to viewport coordinates on layer 0.
  result.addU8(SpriteClientMouseMove)
  result.addI16(x)
  result.addI16(y)
  result.addU8(0)

proc clickPacket(x, y: int, button: uint8): seq[uint8] =
  ## Builds a move plus button down and up at one point.
  result = movePacket(x, y)
  result.addU8(SpriteClientMouseButton)
  result.addU8(button)
  result.addU8(1)
  result.addU8(SpriteClientMouseButton)
  result.addU8(button)
  result.addU8(0)

proc doubleClickPacket(x, y: int): seq[uint8] =
  ## Builds a left-button double click to select matching visible units.
  result = movePacket(x, y)
  result.addU8(SpriteClientMouseButton)
  result.addU8(1)
  result.addU8(2)
  result.addU8(SpriteClientMouseButton)
  result.addU8(1)
  result.addU8(0)

proc keyPacket(ch: char): seq[uint8] =
  ## Builds a printable key press packet.
  result.addU8(SpriteClientChat)
  result.addU16(1)
  result.addU8(uint8(ord(ch)))

proc append(packet: var seq[uint8], part: seq[uint8]) =
  ## Appends one ordered input fragment to an atomic action packet.
  packet.add(part)

proc applyMessage(data: string): bool =
  ## Updates the seen world; returns true at a frame boundary.
  var bytes: seq[uint8]
  blobToBytes(data, bytes)
  if bytes.len > 0 and bytes[0] in [
      BwMessageResources,
      BwMessageFrame,
      BwMessageObject,
      BwMessageClear,
      BwMessageDelete,
      BwMessageVision
  ]:
    proc readU16(offset: int): int =
      bytes[offset].int or (bytes[offset + 1].int shl 8)
    proc readI16(offset: int): int =
      cast[int16](readU16(offset).uint16).int
    proc readU32(offset: int): int =
      bytes[offset].int or
        (bytes[offset + 1].int shl 8) or
        (bytes[offset + 2].int shl 16) or
        (bytes[offset + 3].int shl 24)
    proc unitLabel(nameIndex, mode: int): string =
      result =
        case nameIndex
        of 0: "marine"
        of 7: "scv"
        of 106: "command center"
        of 109: "supply depot"
        of 110: "refinery"
        of 111: "barracks"
        of 176 .. 178: "mineral"
        # The map carries one geyser per start, 166-249px from the
        # Command Center (experiments/find_geysers) — well inside the
        # 640x400 viewport. It was invisible to the bot only because
        # this table is a whitelist and 188 was missing from it.
        of 188: "vespene geyser"
        of 190: "psi disrupter"
        else: ""
      case mode
      of 10:
        result.add(" shadow")
      of 200:
        result.add(" selection")
      of 202:
        result.add(" ghost")
      of 203:
        result.add(" footprint")
      of 204:
        # Server-computed valid placement points for the first depot
        # and barracks; their x,y are footprint centers, not corners.
        result = "buildable " & result
      else:
        discard
    var offset = 0
    while offset < bytes.len:
      let kind = bytes[offset]
      inc offset
      case kind
      of BwMessageResources:
        let compressed = readU32(offset + 5)
        offset += 9 + compressed
      of BwMessageFrame:
        let
          id = readU32(offset)
          width = readU16(offset + 4)
          height = readU16(offset + 6)
          compressed = readU32(offset + 12)
        sprites[id] = SpriteDef(width: width, height: height)
        offset += 16 + compressed
      of BwMessageObject:
        let
          id = readU32(offset)
          frameId = readU32(offset + 4)
          mode = bytes[offset + 16].int
          nameIndex = readI16(offset + 25)
        objects[id] = Seen(
          x: readI16(offset + 8),
          y: readI16(offset + 10),
          spriteId: frameId,
          label: unitLabel(nameIndex, mode)
        )
        offset += 27
      of BwMessageClear:
        objects.clear()
        result = true
      of BwMessageDelete:
        objects.del(readU32(offset))
        offset += 4
      of BwMessageVision:
        objects.clear()
        let count = readU16(offset)
        offset += 2
        for id in 0 ..< count:
          let
            nameIndex = readI16(offset)
            mode = bytes[offset + 10].int
            frameId = -id - 1
          sprites[frameId] = SpriteDef(
            width: readU16(offset + 6),
            height: readU16(offset + 8)
          )
          objects[id] = Seen(
            x: readI16(offset + 2),
            y: readI16(offset + 4),
            spriteId: frameId,
            label: unitLabel(nameIndex, mode)
          )
          offset += 11
        result = true
      else:
        raise newException(
          SpriteProtocolError,
          "unknown BW protocol message " & $kind
        )
    return
  for msg in parseSpritePacket(bytes):
    case msg.kind
    of spkSprite:
      sprites[msg.sprite.id] = SpriteDef(
        width: msg.sprite.width,
        height: msg.sprite.height,
        label: msg.sprite.label
      )
    of spkObject:
      objects[msg.objectDef.id] = Seen(
        x: msg.objectDef.x,
        y: msg.objectDef.y,
        spriteId: msg.objectDef.spriteId,
        label:
          if msg.objectDef.spriteId in sprites:
            sprites[msg.objectDef.spriteId].label
          else:
            ""
      )
    of spkDeleteObject:
      objects.del(msg.objectId)
    of spkClearObjects:
      objects.clear()
      result = true
    else:
      discard

proc addUnique(
  spots: var seq[tuple[x, y: int]],
  center: tuple[x, y: int],
  radius: int
) =
  ## Adds a center unless one already sits within radius. Sprites emit
  ## one entry per image, so an SCV hauling minerals or a damaged
  ## building shows up twice at nearly the same point.
  for s in spots:
    let
      dx = s.x - center.x
      dy = s.y - center.y
    if dx * dx + dy * dy <= radius * radius:
      return
  spots.add(center)

proc findUnitCenters(): UnitCenters =
  ## Classifies all visible unit centers in one object-table pass.
  for id, o in objects:
    if o.spriteId notin sprites:
      continue
    let s = sprites[o.spriteId]
    let label = o.label.toLowerAscii
    if label == "marine selection":
      result.marineSelected = true
    if "shadow" in label or
        "selection" in label or
        "ghost" in label or
        "footprint" in label:
      continue
    # Buildable placement spots arrive center-anchored; everything
    # else is a sprite whose x,y is its top-left corner.
    let buildable = "buildable" in label
    let
      x = if buildable: o.x else: o.x + s.width div 2
      y = if buildable: o.y else: o.y + s.height div 2
      center = (x: x, y: y)
    if x < 0 or x >= ViewWidth or y < 0 or y >= ViewHeight:
      continue
    if buildable and "command center" in label:
      result.ccSpots.add(center)
    elif buildable and "supply depot" in label:
      result.depotSpots.add(center)
    elif buildable and "barracks" in label:
      result.raxSpots.add(center)
    elif "command center" in label:
      result.ccs.addUnique(center, 32)
    elif "supply depot" in label:
      result.depots.addUnique(center, 24)
    elif "barracks" in label:
      result.barracks.addUnique(center, 24)
    elif "marine" in label:
      result.marines.addUnique(center, 4)
    elif "scv" in label:
      result.scvs.addUnique(center, 10)
    elif "refinery" in label:
      # Must precede the geyser test: once a Refinery is built the
      # geyser sits underneath it and both can be on screen.
      result.refineries.addUnique(center, 24)
    elif "vespene" in label or "geyser" in label:
      result.geysers.addUnique(center, 24)
    elif "mineral" in label:
      result.minerals.add(center)
    elif "psi disrupter" in label:
      result.disrupters.addUnique(center, 48)

proc nearest(
  spots: seq[tuple[x, y: int]],
  x, y: int
): tuple[found: bool, x, y: int] =
  ## Picks the spot closest to a point.
  var best = int.high
  for s in spots:
    let d = (s.x - x) * (s.x - x) + (s.y - y) * (s.y - y)
    if d < best:
      best = d
      result = (true, s.x, s.y)

proc buildSpot(
  cc: tuple[x, y: int],
  minerals: seq[tuple[x, y: int]],
  distance, spacing, attempt: int
): tuple[x, y: int] =
  ## Picks a visible build position opposite the local mineral line.
  var
    mineralX = cc.x
    mineralY = cc.y
  if minerals.len > 0:
    mineralX = 0
    mineralY = 0
    for mineral in minerals:
      mineralX += mineral.x
      mineralY += mineral.y
    mineralX = mineralX div minerals.len
    mineralY = mineralY div minerals.len
  let
    dx = mineralX - cc.x
    dy = mineralY - cc.y
    sides = [-1, 1, -2, 2, 0, -3, 3, -4]
    side = sides[attempt mod sides.len] * spacing
    away = distance + 72 * ((attempt div sides.len) mod 3)
  if abs(dx) >= abs(dy):
    result.x = cc.x + (if dx >= 0: -away else: away)
    result.y = cc.y + side
  else:
    result.x = cc.x + side
    result.y = cc.y + (if dy >= 0: -away else: away)
  result.x = clamp(result.x, 48, ViewWidth - 48)
  result.y = clamp(result.y, 48, ViewHeight - 48)

proc main() =
  let url = getEnv("COWORLD_PLAYER_WS_URL", DefaultUrl)
  let profileThisBot =
    ProfileBotSlot >= 0 and
    ("?slot=" & $ProfileBotSlot & "&") in url
  echo "sleepyterran connecting: ", url
  let ws = newWebSocket(url)
  defer: ws.close()
  ws.socket.setSockOpt(
    OptNoDelay,
    true,
    level = IPPROTO_TCP.cint
  )
  if profileThisBot:
    startProfileTrace()
  var capability: seq[uint8]
  capability.addBwSpritesOff()
  ws.send(blobFromBytes(capability), BinaryMessage)
  # Declare the race this bot is built to play. The server holds a
  # short pre-game lobby and creates the slot with the requested race;
  # the player's choice wins over the episode config.
  var raceRequest: seq[uint8]
  raceRequest.addBwRaceRequest("terran")
  ws.send(blobFromBytes(raceRequest), BinaryMessage)

  var
    ticks = 0
    step = 0
    scvCursor = 0
    depotAttempt = 0
    barracksAttempt = 0
    attackTarget = 0
    marineCursor = 0
    lastDepotAttempt = -BuildRetryTicks
    lastBarracksAttempt = -BuildRetryTicks
    lastRefineryAttempt = -BuildRetryTicks
    refineryAttempt = 0
    lastGasOrder = -GasOrderInterval
    ## Gas workers dispatched, counted rather than observed — a worker
    ## inside a Refinery has no sprite to see.
    gasCrew = 0
    gasCrewSince = 0
    gasCursor = 0
    lastResume = 0
    buildSites: seq[tuple[x, y, tick: int]]
    ## Spots where a placement was ordered but no building ever
    ## appeared — unbuildable terrain. The server only offers vetted
    ## spots while a building type is absent, so after the first one
    ## the bot guesses; without this it retries dead ground forever
    ## and stays supply blocked for the whole episode.
    failedSpots: seq[tuple[x, y: int]]
    homeBase = UnknownBase
    ## Highest worker count ever seen at home. The live count dips
    ## whenever the camera is at the front, and build triggers must
    ## not read that dip as a collapsed economy.
    peakScvs = 0
    ## Enemy starts in kill order, nearest first.
    enemyOrder: seq[HomeBase]
    ## How far the army has fought: 0 our gate, 1 the victim's gate,
    ## 2 the victim itself. Advancing needs POSITIVE evidence — our
    ## own Marines standing there with no Disrupter left in sight.
    ## "I see no Disrupter" alone means nothing: the camera may simply
    ## be looking somewhere else.
    frontIndex = 0
    ## Front visit state: -1 idle, otherwise the step in the
    ## look-at-the-front, act, look-back-home cycle.
    frontStep = -1
    lastFrontVisit = 0
    ## Last tick a wave was launched. A plain timer, not a modulo
    ## window: the old one-tick window lost every race with mining.
    lastWave = -10000
    ## Barracks rally points are re-pointed at the front on this
    ## timer, so every Marine walks to the fight the moment it pops
    ## instead of waiting at home for a wave to collect it.
    lastRally = -10000
    rallyCursor = 0
    ## Tick the current victim's assault window opened.
    assaultStarted = -1
    ## True once this victim's Command Center has actually been seen.
    ## Enemy buildings ARE hidden by fog (unlike the neutral gates),
    ## so "no Command Center in sight" means "not explored yet" just
    ## as often as "destroyed" — without this the bot declares a
    ## living base dead and wanders off to the next one.
    sawVictimCc = false
    ## Tick of a pending, not yet confirmed wave double-click.
    waveArmedTick = -1
    ccMissing = 0
    lastRecovery = 0
    ## Tick the first depot became due. The save-up freeze is measured
    ## from here so it can never last the whole episode.
    depotWantedAt = -1
    ## Expansion state: a worker walks to the corner patch, then the
    ## camera visits periodically to plant a Command Center and keep
    ## its workers mining. -1 idle, otherwise the visit step.
    expandStep = -1
    lastExpandVisit = 0
    expandWorkerSent = false
    expandCcSeen = false
    expandAttempt = 0
    gateHelpersSent = 0

  proc send(packet: seq[uint8]) =
    ws.send(blobFromBytes(packet), BinaryMessage)

  while true:
    let msg =
      try:
        ws.receiveMessage(60_000)
      except:
        if profileThisBot:
          finishProfileTrace()
        echo "sleepyterran done after ", ticks, " ticks"
        return
    if msg.isNone:
      if profileThisBot:
        finishProfileTrace()
      echo "sleepyterran timed out after ", ticks, " ticks"
      return
    if msg.get.kind != BinaryMessage:
      continue
    var frameReady: bool
    profileBlock "parse vision":
      frameReady = applyMessage(msg.get.data)
    if not frameReady:
      continue

    inc ticks
    if ticks mod ActInterval != 0:
      profileBlock "send ready":
        ws.send(blobFromSpriteReady(), BinaryMessage)
      if profileThisBot and profileShouldDump(ticks):
        finishProfileTrace()
      continue

    pushProfile("find units")
    let units = findUnitCenters()
    popProfile()
    let
      ccs = units.ccs
      scvs = units.scvs
      depots = units.depots
      barracks = units.barracks
      marines = units.marines
      minerals = units.minerals
      geysers = units.geysers
      refineries = units.refineries
      depotSpots = units.depotSpots
      raxSpots = units.raxSpots
      ccSpots = units.ccSpots

    # Forget construction sites old enough that the building either
    # finished long ago or the placement never took. Sites with no
    # building nearby are failed placements and expire fast.
    var liveSites: seq[tuple[x, y, tick: int]]
    for site in buildSites:
      var confirmed = false
      for building in units.depots & units.barracks:
        let
          dx = building.x - site.x
          dy = building.y - site.y
        if dx * dx + dy * dy < 48 * 48:
          confirmed = true
          break
      let lifetime = if confirmed: SiteLifetime else: PhantomLifetime
      if ticks - site.tick < lifetime:
        liveSites.add(site)
      elif not confirmed:
        # Expired with nothing built: remember the ground is dead.
        if failedSpots.len < 64:
          failedSpots.add((site.x, site.y))
    buildSites = liveSites

    proc spotFailed(x, y: int): bool =
      ## True near a placement that never produced a building.
      for f in failedSpots:
        let
          dx = f.x - x
          dy = f.y - y
        if dx * dx + dy * dy < 56 * 56:
          return true

    proc nearAny(
      spots: seq[tuple[x, y: int]],
      x, y, radius: int
    ): bool =
      ## True when a point sits within radius of any of the spots.
      for s in spots:
        let
          dx = s.x - x
          dy = s.y - y
        if dx * dx + dy * dy < radius * radius:
          return true

    proc nearSite(x, y: int): bool =
      ## True when a point sits inside a protected construction site.
      for site in buildSites:
        let
          dx = site.x - x
          dy = site.y - y
        if dx * dx + dy * dy < SiteRadius * SiteRadius:
          return true

    proc onMineralLine(x, y: int): bool =
      ## True for workers still in the home economy. Gate helpers walk
      ## the other way, off this radius.
      nearAny(ccs, x, y, HelperHomeCc) or
        nearAny(minerals, x, y, HelperHomeMineral)

    proc freeWorker(spotX, spotY: int): tuple[found: bool, x, y: int] =
      ## Picks the worker closest to a spot, skipping active builders,
      ## dispatched gate helpers, and workers over the minimap.
      var best = int.high
      for scv in scvs:
        if nearSite(scv.x, scv.y) or inForbiddenZone(scv.x, scv.y) or
            not onMineralLine(scv.x, scv.y):
          continue
        let d = (scv.x - spotX) * (scv.x - spotX) +
          (scv.y - spotY) * (scv.y - spotY)
        if d < best:
          best = d
          result = (true, scv.x, scv.y)

    proc gridSpot(
      anchors: seq[tuple[x, y: int]],
      stepX, stepY, attempt: int
    ): tuple[found: bool, x, y: int] =
      ## Sweeps a dense tile-aligned grid around the base, nearest
      ## first, and returns the attempt-th free position. The engine
      ## says ~125 of the tiles around home take a depot, but the old
      ## eight-direction pattern only ever tested 24 points and found
      ## eight of them — so a couple of bad guesses stalled the build
      ## for the rest of the episode.
      if anchors.len == 0:
        return
      let anchor = anchors[0]
      var candidates: seq[tuple[x, y, dist: int]]
      for ty in -8 .. 8:
        for tx in -8 .. 8:
          let
            x = anchor.x + tx * 32
            y = anchor.y + ty * 32
          if x < 64 or x > ViewWidth - 64 or y < 48 or y > ViewHeight - 48:
            continue
          if inForbiddenZone(x, y):
            continue
          if nearSite(x, y) or spotFailed(x, y):
            continue
          var blocked = false
          for group in [ccs, depots, barracks, minerals]:
            for u in group:
              let
                dx = u.x - x
                dy = u.y - y
              if dx * dx + dy * dy < 72 * 72:
                blocked = true
                break
            if blocked:
              break
          if blocked:
            continue
          candidates.add((x, y, tx * tx * stepX + ty * ty * stepY))
      if candidates.len == 0:
        return
      # Nearest first keeps the base compact and the walk short.
      for i in 0 ..< candidates.len:
        for j in i + 1 ..< candidates.len:
          if candidates[j].dist < candidates[i].dist:
            swap(candidates[i], candidates[j])
      let pick = candidates[attempt mod candidates.len]
      return (true, pick.x, pick.y)

    # Peak worker count: the live count dips whenever the camera is
    # at the front, and the build triggers must not read that dip as
    # a collapsed economy.
    if frontStep < 0 and expandStep < 0 and ccs.len > 0:
      peakScvs = max(peakScvs, scvs.len)

    # Learn which start location is ours from the mineral line: on
    # Weave the minerals sit on the outward side of each base.
    if homeBase == UnknownBase and ccs.len > 0 and minerals.len >= 4:
      var
        mineralX = 0
        mineralY = 0
      for mineral in minerals:
        mineralX += mineral.x
        mineralY += mineral.y
      let
        dx = mineralX div minerals.len - ccs[0].x
        dy = mineralY div minerals.len - ccs[0].y
      homeBase =
        if abs(dx) >= abs(dy):
          if dx >= 0: EastBase else: WestBase
        else:
          if dy >= 0: SouthBase else: NorthBase
      # Kill order: the two adjacent bases first, the diagonal one
      # last, so early waves spend the least time walking.
      let home = BaseSpots[homeBase]
      var spots: seq[tuple[base: HomeBase, dist: int]]
      for base in NorthBase .. WestBase:
        if base == homeBase:
          continue
        let
          spot = BaseSpots[base]
          dx2 = spot.x - home.x
          dy2 = spot.y - home.y
        spots.add((base, dx2 * dx2 + dy2 * dy2))
      for i in 0 ..< spots.len:
        for j in i + 1 ..< spots.len:
          if spots[j].dist < spots[i].dist:
            swap(spots[i], spots[j])
      # A victim we can reach without breaking anything comes first.
      for spot in spots:
        if not needsGate(homeBase, spot.base):
          enemyOrder.add(spot.base)
      for spot in spots:
        if needsGate(homeBase, spot.base):
          enemyOrder.add(spot.base)
      echo "home base: ", homeBase, " kill order: ", enemyOrder

    # Camera recovery: if the command center vanished from view the
    # camera got panned; click home to return.
    if ccs.len == 0:
      inc ccMissing
    else:
      ccMissing = 0
    if homeBase != UnknownBase and ccMissing >= 3 and
        frontStep < 0 and expandStep < 0 and ticks - lastRecovery >= 60:
      let spot = BaseSpots[homeBase]
      send(clickPacket(spot.x, spot.y, 1))
      lastRecovery = ticks
      echo "camera recovery at t=", ticks

    # Fallback only: evidence normally advances the victim first.
    if assaultStarted >= 0 and
        ticks - assaultStarted >= BaseAssaultTicks and
        attackTarget < enemyOrder.high:
      inc attackTarget
      assaultStarted = ticks
      echo "switching to victim ", attackTarget, " at t=", ticks

    # Supply plan: the first depot lands at 8 workers, then another
    # every 1500 ticks keeps Marine production ahead of the cap.
    let
      desiredDepots =
        if peakScvs >= 8 or depots.len > 0 or barracks.len > 0:
          min(MaxDepots, 1 + max(0, ticks - 3600) div 2400)
        else:
          0
      desiredBarracks =
        if EconomyOnly: 0
        # Barracks BEFORE the first depot. A Barracks needs no supply,
        # and the Command Center's own 10 covers the opening workers
        # plus the first Marines. Waiting for a depot pushed the first
        # Marine to t~6000 and breakout to t~12000; breakout under
        # t=10000 is what wins games.
        # Two Barracks as soon as we have six workers, three by t=3000.
        # Breakout is decided by how fast 4000 HP of wall comes down,
        # and that is production rate. Games breaking out under t=10000
        # win; v37 managed that in 6 of 14, all of which are the wins.
        elif peakScvs >= 6: (if ticks > 3000: MaxBarracks else: 2)
        else: 0
      # Hold Marine spending only until the opening depot stands, so
      # the 100 minerals for it can accumulate. SCV training is never
      # frozen: workers out-earn everything they cost.
      # Freeze worker training only long enough to bank 100 minerals.
      # An open-ended freeze is catastrophic: if placement stalls the
      # economy stays frozen for the rest of the game (measured: one
      # game froze from t=2400 to t=9600 and scored 2190 against a
      # 6378 best). Workers out-earn a perfectly timed depot.
      # The economy build time-boxes this freeze: an open-ended one
      # stalls mining for half the episode when placement fails.
      # The ARMY build must NOT time-box it. Resuming worker training
      # before the depot stands fills the supply cap with SCVs, and
      # then no Marine can ever be trained — which is how the army
      # fell from 58 to 43 and every outright victory disappeared.
      savingHard =
        desiredDepots > 0 and depots.len == 0 and
        depotWantedAt >= 0 and ticks - depotWantedAt < SaveUpTicks


    # Every MiningShare-th action belongs to the mineral line no
    # matter what else is owed; gathered minerals are most of the score.
    let miningTurn = step mod MiningShare == 0 and waveArmedTick < 0

    let waveDue =
      not EconomyOnly and
      marines.len >= WaveSize and homeBase != UnknownBase and
      ticks >= FirstAttackTick and enemyOrder.len > 0 and
      waveArmedTick < 0 and ticks - lastWave >= AttackInterval

    # Open a front visit: neutral gate buildings are never picked up
    # by attack-move, so the only way to break one is to look at it
    # and click it. The camera goes to the front, attacks, comes back.
    let attacking =
      not EconomyOnly and
      homeBase != UnknownBase and enemyOrder.len > 0 and
      ticks >= FirstAttackTick
    if attacking and frontStep < 0 and
        ticks - lastFrontVisit >= FrontVisitInterval:
      frontStep = 0

    if desiredDepots > 0 and depots.len == 0 and depotWantedAt < 0:
      depotWantedAt = ticks

    # Walking the worker out is free, so do it early; but only start
    # visiting (and trying to afford a 400-mineral Command Center)
    # once the economy stands, or the build-up is disrupted for
    # nothing. v28 conflated the two and lost 400 points a game.
    # Expansion belongs to the economy build only. In the army build
    # its camera visits compete with the front visits and the diverted
    # worker slows the opening: breakout slipped from t~12000 to
    # t=15606 and no game was won outright.
    if EconomyOnly and homeBase != UnknownBase and not expandWorkerSent and
        ticks >= ExpandTick and peakScvs >= 8 and ccs.len > 0:
      let worker = freeWorker(ccs[0].x, ccs[0].y)
      if worker.found:
        var packet = clickPacket(worker.x, worker.y, 1)
        packet.append(clickPacket(
          ExpansionSpots[homeBase].x, ExpansionSpots[homeBase].y, 2))
        send(packet)
        expandWorkerSent = true
        echo "expansion worker sent at t=", ticks

    if not EconomyOnly and homeBase != UnknownBase and frontIndex == 0 and
        ticks >= FirstAttackTick and barracks.len > 0 and
        gateHelpersSent < GateHelpers and ccs.len > 0 and
        ticks mod 120 < ActInterval:
      let helper = freeWorker(ccs[0].x, ccs[0].y)
      if helper.found:
        var packet = clickPacket(helper.x, helper.y, 1)
        packet.append(clickPacket(
          GateSpots[homeBase].x, GateSpots[homeBase].y, 2))
        send(packet)
        inc gateHelpersSent
        if gateHelpersSent == GateHelpers:
          echo "gate helpers dispatched at t=", ticks

    # Against a gate-free victim there is no wall to break: go
    # straight for the base.
    if homeBase != UnknownBase and enemyOrder.len > 0 and frontIndex < 2 and
        not needsGate(homeBase, enemyOrder[min(attackTarget, enemyOrder.high)]):
      frontIndex = 2

    let expanding =
      EconomyOnly and homeBase != UnknownBase and depots.len > 0 and
      expandWorkerSent
    if expanding and expandStep < 0 and
        ticks - lastExpandVisit >= ExpansionVisitInterval:
      expandStep = 0

    pushProfile("choose action")
    if expandStep == 0:
      # Look at the corner; the worker was dispatched from home earlier
      # and should already be walking or waiting there.
      send(clickPacket(
        ExpansionSpots[homeBase].x, ExpansionSpots[homeBase].y, 1))
      expandStep = 1
    elif expandStep == 1:
      # Looking at the corner. Plant the Command Center if the worker
      # has arrived, otherwise keep its workers on the patch.
      if ccs.len > 0:
        if not expandCcSeen:
          expandCcSeen = true
          echo "expansion command center up at t=", ticks
        # Train a worker here and put the locals on the new patch.
        var packet = clickPacket(ccs[0].x, ccs[0].y, 1)
        packet.append(keyPacket('s'))
        send(packet)
        for scv in scvs:
          if inForbiddenZone(scv.x, scv.y):
            continue
          let mineral = minerals.nearest(scv.x, scv.y)
          if mineral.found and not inForbiddenZone(mineral.x, mineral.y):
            var order = clickPacket(scv.x, scv.y, 1)
            order.append(clickPacket(mineral.x, mineral.y, 2))
            send(order)
          break
      elif scvs.len > 0 and minerals.len > 0:
        # Worker is here and there is no Command Center yet. Placement
        # must use the dense sweep: the server only vets spots for a
        # building type you own NONE of, and we already have a Command
        # Center at home, so this is guesswork. A single guessed point
        # succeeded in only 2 of 9 games.
        # NOTE: the dense sweep is wrong here. It rejects anything
        # within 72px of a mineral, and an expansion is nothing but
        # clustered minerals, so it found no spot at all — 0/12 games
        # built a Command Center against 2/9 with this simpler guess.
        # Sweep for a spot that is clear of the patches but still
        # beside them, nearest to the cluster first.
        proc expansionSpot(attempt: int): tuple[found: bool, x, y: int] =
          if minerals.len == 0:
            return
          var cx, cy = 0
          for mineral in minerals:
            cx += mineral.x
            cy += mineral.y
          cx = cx div minerals.len
          cy = cy div minerals.len
          var candidates: seq[tuple[x, y, dist: int]]
          for ty in -6 .. 6:
            for tx in -6 .. 6:
              let
                x = cx + tx * 32
                y = cy + ty * 32
              if x < 64 or x > ViewWidth - 64 or
                  y < 48 or y > ViewHeight - 48:
                continue
              if inForbiddenZone(x, y):
                continue
              let
                rx = x - cx
                ry = y - cy
                range2 = rx * rx + ry * ry
              if range2 > ExpansionMaxRange * ExpansionMaxRange:
                continue
              var blocked = false
              for mineral in minerals:
                let
                  dx = mineral.x - x
                  dy = mineral.y - y
                if dx * dx + dy * dy <
                    ExpansionMineralClearance * ExpansionMineralClearance:
                  blocked = true
                  break
              if blocked:
                continue
              candidates.add((x, y, range2))
          if candidates.len == 0:
            return
          for i in 0 ..< candidates.len:
            for j in i + 1 ..< candidates.len:
              if candidates[j].dist < candidates[i].dist:
                swap(candidates[i], candidates[j])
          let pick = candidates[attempt mod candidates.len]
          return (true, pick.x, pick.y)

        let
          worker = scvs[0]
          guess = buildSpot((x: worker.x, y: worker.y), minerals,
                            128, 64, expandAttempt)
          swept =
            if ExpansionSweep: expansionSpot(expandAttempt)
            else: (found: false, x: 0, y: 0)
          exact = ccSpots.nearest(guess.x, guess.y)
          spot =
            if ExpansionVetting and exact.found:
              (x: exact.x, y: exact.y)
            elif swept.found:
              (x: swept.x, y: swept.y)
            else:
              guess
        inc expandAttempt
        if not inForbiddenZone(spot.x, spot.y):
          var packet = clickPacket(worker.x, worker.y, 1)
          packet.append(keyPacket('b'))
          packet.append(keyPacket('c'))
          packet.append(clickPacket(spot.x, spot.y, 1))
          send(packet)
          echo "expansion cc ordered at t=", ticks, " spot=", spot,
            " vetted=", exact.found, " swept=", swept.found
      expandStep = 2
    elif expandStep == 2:
      send(clickPacket(BaseSpots[homeBase].x, BaseSpots[homeBase].y, 1))
      expandStep = -1
      lastExpandVisit = ticks
    elif frontStep == 0:
      # Look at whichever barrier is currently in the way.
      let
        victim = enemyOrder[min(attackTarget, enemyOrder.high)]
        front =
          if frontIndex == 0: GateSpots[homeBase]
          elif frontIndex == 1: GateSpots[victim]
          else: BaseSpots[victim]
      send(clickPacket(front.x, front.y, 1))
      frontStep = 1
    elif frontStep == 1:
      # Now seeing the front. Break the gate if it still stands,
      # otherwise push the survivors onward.
      let victim = enemyOrder[min(attackTarget, enemyOrder.high)]
      echo "front t=", ticks, " idx=", frontIndex,
        " marines=", marines.len,
        " disrupters=", units.disrupters.len,
        " ccs=", ccs.len
      # Only our own Marines standing on an empty gate prove it fell.
      if marines.len > 0 and units.disrupters.len == 0 and frontIndex < 2:
        inc frontIndex
        echo "front advanced to ", frontIndex, " at t=", ticks
      elif frontIndex == 2 and marines.len > 0 and ccs.len > 0:
        # Their base is in sight and still standing.
        sawVictimCc = true
      elif frontIndex == 2 and marines.len > 0 and ccs.len == 0 and
          scvs.len == 0 and
          sawVictimCc and attackTarget < enemyOrder.high:
        # Standing in the victim's base with its Command Center gone:
        # move to the next one and break that gate. Evidence, not a
        # clock — the bot cannot see how long the episode runs.
        inc attackTarget
        frontIndex = 1
        assaultStarted = ticks
        sawVictimCc = false
        # The camera is standing in the base we just killed, so the
        # surviving army is on screen RIGHT NOW — send it straight to
        # the next gate. Otherwise it idles here while only newly
        # trained Marines walk to the new objective, which is why the
        # third kill arrived at t=37914 when the second landed at
        # t=21810.
        let nextVictim = enemyOrder[min(attackTarget, enemyOrder.high)]
        # A double-click grabs at most twelve units — BW's selection
        # cap — so ONE order moves twelve Marines and strands the rest.
        # Issue several from well-separated Marines so most of a
        # forty-strong army actually marches to the next victim.
        var ordered: seq[tuple[x, y: int]]
        for marine in marines:
          if inForbiddenZone(marine.x, marine.y):
            continue
          var tooClose = false
          for o in ordered:
            let
              dx = o.x - marine.x
              dy = o.y - marine.y
            if dx * dx + dy * dy < 96 * 96:
              tooClose = true
              break
          if tooClose:
            continue
          var packet = doubleClickPacket(marine.x, marine.y)
          packet.append(keyPacket('a'))
          packet.append(clickPacket(
            GateSpots[nextVictim].x, GateSpots[nextVictim].y, 1))
          send(packet)
          ordered.add(marine)
          if ordered.len >= 4:
            break
        echo "victim down, next=", attackTarget, " at t=", ticks,
          " army regrouped toward ", nextVictim
      # Workers already at the wall shoot it too — free damage.
      if units.disrupters.len > 0:
        for scv in scvs:
          if inForbiddenZone(scv.x, scv.y):
            continue
          let barrier = units.disrupters.nearest(scv.x, scv.y)
          if barrier.found and not inForbiddenZone(barrier.x, barrier.y):
            var packet = doubleClickPacket(scv.x, scv.y)
            packet.append(keyPacket('a'))
            packet.append(clickPacket(barrier.x, barrier.y, 1))
            send(packet)
          break

      var acted = false
      var attackers: seq[tuple[x, y: int]]
      for marine in marines:
        if inForbiddenZone(marine.x, marine.y):
          continue
        var tooClose = false
        for a in attackers:
          let
            dx = a.x - marine.x
            dy = a.y - marine.y
          if dx * dx + dy * dy < 96 * 96:
            tooClose = true
            break
        if tooClose:
          continue
        attackers.add(marine)
        if units.disrupters.len > 0:
          let barrier = units.disrupters.nearest(marine.x, marine.y)
          if barrier.found and not inForbiddenZone(barrier.x, barrier.y):
            var packet = doubleClickPacket(marine.x, marine.y)
            packet.append(keyPacket('a'))
            packet.append(clickPacket(barrier.x, barrier.y, 1))
            send(packet)
            acted = true
        elif frontIndex == 2 and ccs.len == 0 and scvs.len > 0:
          # Base razed but workers still alive — hunt them down, or
          # the player is never eliminated and the game is never won.
          let prey = scvs.nearest(marine.x, marine.y)
          if prey.found and not inForbiddenZone(prey.x, prey.y):
            var packet = doubleClickPacket(marine.x, marine.y)
            packet.append(keyPacket('a'))
            packet.append(clickPacket(prey.x, prey.y, 1))
            send(packet)
            acted = true
        else:
          var packet = doubleClickPacket(marine.x, marine.y)
          packet.append(keyPacket('a'))
          packet.append(clickPacket(BaseSpots[victim].x, BaseSpots[victim].y, 1))
          send(packet)
          acted = true
        if attackers.len >= 3:
          break
      if not acted:
        discard
      frontStep = 2
    elif frontStep == 2:
      # Camera back home so the macro loop can see its own base.
      send(clickPacket(BaseSpots[homeBase].x, BaseSpots[homeBase].y, 1))
      frontStep = -1
      lastFrontVisit = ticks
    elif waveDue:
      # Wave phase 1: double-click a Marine to select the group. The
      # attack itself waits until the selection ring confirms it.
      for marine in marines:
        if not inForbiddenZone(marine.x, marine.y):
          send(doubleClickPacket(marine.x, marine.y))
          waveArmedTick = ticks
          lastWave = ticks
          break
    elif barracks.len > 0 and homeBase != UnknownBase and
        enemyOrder.len > 0 and ticks >= FirstAttackTick and
        ticks - lastRally >= RallyInterval:
      # Select a Barracks and right-click the objective on the
      # minimap: for a building that is a rally point, so every
      # Marine trained afterwards walks to the front unattended.
      let
        victim = enemyOrder[min(attackTarget, enemyOrder.high)]
        front =
          if frontIndex == 0: GateSpots[homeBase]
          elif frontIndex == 1: GateSpots[victim]
          else: BaseSpots[victim]
        rax = barracks[rallyCursor mod barracks.len]
      inc rallyCursor
      var packet = clickPacket(rax.x, rax.y, 1)
      packet.append(clickPacket(front.x, front.y, 2))
      send(packet)
      lastRally = ticks
    elif miningTurn and scvs.len > 0 and minerals.len > 0:
      var safeMinerals: seq[tuple[x, y: int]]
      for mineral in minerals:
        if not inForbiddenZone(mineral.x, mineral.y):
          safeMinerals.add(mineral)
      for offset in 0 ..< scvs.len:
        let worker = scvs[(scvCursor + offset) mod scvs.len]
        if nearSite(worker.x, worker.y) or
            inForbiddenZone(worker.x, worker.y) or
            not onMineralLine(worker.x, worker.y):
          continue
        let mineral = safeMinerals.nearest(worker.x, worker.y)
        if mineral.found:
          var packet = clickPacket(worker.x, worker.y, 1)
          packet.append(clickPacket(mineral.x, mineral.y, 2))
          send(packet)
        scvCursor = (scvCursor + offset + 1) mod max(1, scvs.len)
        break
    elif waveArmedTick >= 0:
      # Wave phase 2: fire only once the selection ring proves the
      # double-click grabbed Marines. An unconfirmed minimap click
      # would pan the camera instead of attacking.
      if units.marineSelected and homeBase != UnknownBase:
        # Every wave goes to the SAME objective until it falls.
        # Rotating targets splits the army three ways and nothing ever
        # dies. The objective is the first barrier still standing:
        # our own gate, then the victim's gate, then the victim.
        let
          victim = enemyOrder[min(attackTarget, enemyOrder.high)]
          target =
            if frontIndex == 0: GateSpots[homeBase]
            elif frontIndex == 1: GateSpots[victim]
            else: BaseSpots[victim]
          home = BaseSpots[homeBase]
        var packet = keyPacket('a')
        packet.append(clickPacket(target.x, target.y, 1))
        packet.append(clickPacket(home.x, home.y, 1))
        send(packet)
        waveArmedTick = -1
        # The victim clock only starts once the army is actually out
        # of its own base; breaking our gate is not an assault.
        if assaultStarted < 0 and frontIndex >= 1:
          assaultStarted = ticks
        echo "wave fired at t=", ticks,
          " target=", target, " victim=", attackTarget
      elif ticks - waveArmedTick > 3 * ActInterval:
        waveArmedTick = -1
    elif depots.len < desiredDepots and ccs.len > 0 and
        ticks - lastDepotAttempt >= BuildRetryTicks:
      # Select a free SCV, open Basic Build, choose Supply Depot, and
      # place it. The server offers exact valid spots until the first
      # depot exists; later depots grid off a confirmed building.
      let
        guess = buildSpot(ccs[0], minerals, 144, 48, depotAttempt)
        exact = depotSpots.nearest(guess.x, guess.y)
        grid =
          if depots.len > 0:
            gridSpot(
              depots & barracks & ccs,
              BarracksWidth,
              BarracksHeight,
              depotAttempt
            )
          else:
            (found: false, x: 0, y: 0)
        desired =
          if exact.found:
            (x: exact.x, y: exact.y)
          elif grid.found:
            (x: grid.x, y: grid.y)
          else:
            guess
        worker = freeWorker(desired.x, desired.y)
      if worker.found and not inForbiddenZone(desired.x, desired.y):
        var packet = clickPacket(worker.x, worker.y, 1)
        packet.append(keyPacket('b'))
        packet.append(keyPacket('s'))
        packet.append(clickPacket(desired.x, desired.y, 1))
        send(packet)
        buildSites.add((desired.x, desired.y, ticks))
        inc depotAttempt
        lastDepotAttempt = ticks
      else:
        inc depotAttempt
    elif barracks.len < desiredBarracks and ccs.len > 0 and
        ticks - lastBarracksAttempt >= BuildRetryTicks:
      # Barracks follow the depot; a second one doubles Marine flow.
      let
        guess = buildSpot(ccs[0], minerals, 128, 112, barracksAttempt)
        exact = raxSpots.nearest(guess.x, guess.y)
        grid =
          if barracks.len > 0 or depots.len > 0:
            gridSpot(
              barracks & depots & ccs,
              BarracksWidth,
              BarracksHeight,
              barracksAttempt
            )
          else:
            (found: false, x: 0, y: 0)
        desired =
          if exact.found:
            (x: exact.x, y: exact.y)
          elif grid.found:
            (x: grid.x, y: grid.y)
          else:
            guess
        worker = freeWorker(desired.x, desired.y)
      if worker.found and not inForbiddenZone(desired.x, desired.y):
        var packet = clickPacket(worker.x, worker.y, 1)
        packet.append(keyPacket('b'))
        packet.append(keyPacket('b'))
        packet.append(clickPacket(desired.x, desired.y, 1))
        send(packet)
        buildSites.add((desired.x, desired.y, ticks))
        inc barracksAttempt
        lastBarracksAttempt = ticks
      else:
        inc barracksAttempt
    elif Gas and refineries.len == 0 and geysers.len > 0 and
        depots.len > 0 and ccs.len > 0 and
        refineryAttempt < RefineryGiveUp and
        ticks - lastRefineryAttempt >= BuildRetryTicks:
      # A Refinery needs no placement search at all: the only legal
      # spot is the geyser itself, so the sprite position IS the
      # answer. This is why gas is cheap to add and the expansion
      # Command Center was not. Gated behind the first depot so it
      # never competes with opening supply.
      let
        geyser = geysers.nearest(ccs[0].x, ccs[0].y)
        worker = freeWorker(geyser.x, geyser.y)
      if geyser.found and worker.found and
          not inForbiddenZone(geyser.x, geyser.y):
        var packet = clickPacket(worker.x, worker.y, 1)
        packet.append(keyPacket('b'))
        packet.append(keyPacket('r'))
        packet.append(clickPacket(geyser.x, geyser.y, 1))
        send(packet)
        buildSites.add((geyser.x, geyser.y, ticks))
        echo "refinery ordered at t=", ticks, " geyser=", geyser
      inc refineryAttempt
      lastRefineryAttempt = ticks
    elif Gas and refineries.len > 0 and scvs.len > GasWorkers and
        ticks - lastGasOrder >= GasOrderInterval:
      # Send a few workers to the Refinery. Right-clicking a Refinery
      # is the gather order, exactly as for a mineral patch.
      let refinery = refineries[0]
      # Only top the crew back up to strength. Re-ordering a worker
      # that is already on gas restarts its cycle and throws away the
      # trip it was on, so workers inside the hold radius are counted,
      # not re-sent. Blindly re-sending all three every interval let
      # the yield decay from 0.11 to 0.02 gas per frame.
      # Count what we SENT, not what we can see. A worker gathering gas
      # is INSIDE the Refinery and emits no sprite, so a screen count
      # reads zero while three workers are mining perfectly — and the
      # top-up then re-sends every interval, restarting the cycle of
      # the very workers that were working. That is the decay measured
      # locally: 0.111 gas/frame early, 0.022 late. Visible workers are
      # still counted, since one walking to the Refinery is real.
      var onGas = gasCrew
      for worker in scvs:
        if nearAny(refineries, worker.x, worker.y, GasHoldRadius):
          inc onGas
      var sent = 0
      for offset in 0 ..< scvs.len:
        if onGas + sent >= GasWorkers: break
        let worker = scvs[(gasCursor + offset) mod scvs.len]
        if nearSite(worker.x, worker.y) or
            inForbiddenZone(worker.x, worker.y) or
            nearAny(refineries, worker.x, worker.y, GasHoldRadius):
          continue
        var packet = clickPacket(worker.x, worker.y, 1)
        packet.append(clickPacket(refinery.x, refinery.y, 2))
        send(packet)
        inc sent
      gasCursor = (gasCursor + sent + 1) mod max(1, scvs.len)
      inc gasCrew, sent
      # Forget the crew periodically so a worker that died, or drifted
      # off, gets replaced. Long enough that a healthy crew is never
      # disturbed; short enough that a lost one is not left lost.
      if ticks - gasCrewSince >= GasCrewForgetTicks:
        gasCrew = 0
        gasCrewSince = ticks
      lastGasOrder = ticks
    elif buildSites.len > 0 and ticks - lastResume >= ResumeInterval:
      # Construction watchdog: order the nearest worker back onto a
      # rotating site. Right-click resumes a paused Terran
      # construction and is harmless on a finished building.
      let
        site = buildSites[(ticks div ResumeInterval) mod buildSites.len]
        worker = freeWorker(site.x, site.y)
      if worker.found:
        var packet = clickPacket(worker.x, worker.y, 1)
        packet.append(clickPacket(site.x, site.y, 2))
        send(packet)
      lastResume = ticks
    elif ccs.len > 0 and scvs.len < MaxWorkers and step mod 3 == 0 and
        not savingHard:
      # Workers first — but not while the opening depot or Barracks
      # is unpaid. An SCV every 50 minerals never lets 100 pile up.
      var packet = clickPacket(ccs[0].x, ccs[0].y, 1)
      packet.append(keyPacket('s'))
      send(packet)
    elif barracks.len > 0 and step mod 2 == 1 and not savingHard:
      # Keep every Barracks producing; a failed order is free.
      # This MUST NOT share a step with the mining turn: mining is
      # earlier in the chain, so an even-step condition here meant
      # Marines were never trained at all.

      let rax = barracks[marineCursor mod barracks.len]
      inc marineCursor
      var packet = clickPacket(rax.x, rax.y, 1)
      packet.append(keyPacket('m'))
      send(packet)

    elif scvs.len > 0 and minerals.len > 0:
      # Reissue mining orders so newly trained and displaced workers
      # return to the mineral line — but never touch active builders,
      # and never click anything sitting over the minimap.
      var safeMinerals: seq[tuple[x, y: int]]
      for mineral in minerals:
        if not inForbiddenZone(mineral.x, mineral.y):
          safeMinerals.add(mineral)
      var issued = false
      for offset in 0 ..< scvs.len:
        let worker = scvs[(scvCursor + offset) mod scvs.len]
        if nearSite(worker.x, worker.y) or
            inForbiddenZone(worker.x, worker.y) or
            not onMineralLine(worker.x, worker.y):
          continue
        # Leave the gas crew alone. Without this the mining loop drags
        # them back to the minerals within a few actions and the
        # Refinery yields almost nothing: measured at 16 gas per 2400
        # ticks before this check, i.e. ~96 over a whole episode.
        if Gas and refineries.len > 0 and
            nearAny(refineries, worker.x, worker.y, GasHoldRadius):
          continue
        let mineral = safeMinerals.nearest(worker.x, worker.y)
        if mineral.found:
          var packet = clickPacket(worker.x, worker.y, 1)
          packet.append(clickPacket(mineral.x, mineral.y, 2))
          send(packet)
          scvCursor = (scvCursor + offset + 1) mod max(1, scvs.len)
          issued = true
        break
      if not issued:
        inc scvCursor
    if ticks mod 600 < ActInterval:
      echo "state t=", ticks,
        " scvs=", scvs.len,
        " depots=", depots.len,
        " barracks=", barracks.len,
        " marines=", marines.len,
        " geysers=", geysers.len,
        " refineries=", refineries.len
    popProfile()
    inc step
    profileBlock "send ready":
      ws.send(blobFromSpriteReady(), BinaryMessage)
    if profileThisBot and profileShouldDump(ticks):
      finishProfileTrace()

main()
